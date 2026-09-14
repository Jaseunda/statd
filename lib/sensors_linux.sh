#!/usr/bin/env bash
# sensors_linux.sh — sensor implementations for Linux (x86, ARM, and other kernels)
# Part of statd: https://github.com/Jaseunda/statd
#
# Performance notes:
#   All functions use read builtins or direct file access where possible.
#   awk is retained only for multi-file glob operations (cpuidle).
#   No unnecessary subshells in the hot path.

_linux_get_temp() {
    local max=0 temp c type f
    for f in /sys/class/thermal/thermal_zone*/temp; do
        [ -r "$f" ] || continue
        local typefile="${f%temp}type"
        [ -r "$typefile" ] || continue
        { read -r type < "$typefile"; } 2>/dev/null
        case "$type" in
            cpu-0-*-usr|cpu-0-*-step|cpu-1-*-usr|cpu-1-*-step|\
            x86_pkg_temp|acpitz|coretemp|cpu_thermal|soc_thermal|\
            tsens_tz_sensor*|thermal)
                { read -r temp < "$f"; } 2>/dev/null
                [[ "$temp" =~ ^[0-9]+$ ]] || continue
                c=$(( temp / 1000 ))
                (( c >= 0 && c <= 120 && c > max )) && max=$c
                ;;
        esac
    done
    (( max > 0 )) && printf '%d' "$max" || printf '%s' '--'
}

_linux_get_cpu_freq() {
    local max=0 value f i frac
    for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
        [ -r "$f" ] || continue
        { read -r value < "$f"; } 2>/dev/null
        [[ "$value" =~ ^[0-9]+$ ]] || continue
        (( value > max )) && max=$value
    done
    if (( max >= 1000000 )); then
        i=$(( max / 1000000 ))
        frac=$(( (max % 1000000) * 100 / 1000000 ))
        printf '%d.%02dGHz' "$i" "$frac"
    elif (( max > 0 )); then
        printf '%dMHz' "$(( max / 1000 ))"
    else
        printf '%s' '--'
    fi
}

# Returns: <total_jiffies> <idle_jiffies>
# Uses read builtin directly on /proc/stat — zero forks.
_linux_get_cpu_raw() {
    local tag u n s i io irq sirq _
    { read -r tag u n s i io irq sirq _ < /proc/stat; } 2>/dev/null || return 1
    [[ "$tag" == "cpu" ]] || return 1
    printf '%d %d' $(( u + n + s + i + io + irq + sirq )) $(( i + io ))
}

# Returns total CPU idle microseconds (sum across all cores and idle states).
# awk retained here — glob expands to many files, single awk pass is faster
# than a bash loop calling read on each file individually.
_linux_get_idle_us() {
    awk '{s+=$1} END{print s+0}' \
        /sys/devices/system/cpu/cpu*/cpuidle/state*/time 2>/dev/null
}

# Returns "core_index idle_us" lines for per-core residency.
_linux_get_core_idle() {
    awk '
        FNR==1 {
            cpu=FILENAME
            sub(/.*\/cpu/, "", cpu)
            sub(/\/cpuidle.*/, "", cpu)
        }
        { idle[cpu] += $1 }
        END { for (c in idle) printf "%d %d\n", c, idle[c]+0 }
    ' /sys/devices/system/cpu/cpu*/cpuidle/state*/time 2>/dev/null
}

# Returns: <total_kB> <used_kB> <swap_total_kB> <swap_used_kB>
# Uses while+read on /proc/meminfo — zero forks.
_linux_get_memory() {
    local key val unit
    local total=0 available=0 swap_total=0 swap_free=0
    {
        while read -r key val unit; do
            case "$key" in
                MemTotal:)     total=$val ;;
                MemAvailable:) available=$val ;;
                SwapTotal:)    swap_total=$val ;;
                SwapFree:)     swap_free=$val ;;
            esac
        done < /proc/meminfo
    } 2>/dev/null
    printf '%d %d %d %d\n' \
        "$total" \
        "$(( total - available ))" \
        "$swap_total" \
        "$(( swap_total - swap_free ))"
}

# Returns: <pct> <status-string>  or empty if no battery.
_linux_get_battery() {
    # upower (desktop Linux, most distributions)
    if command -v upower >/dev/null 2>&1; then
        local bat
        bat=$(upower -e 2>/dev/null | grep -i battery | head -1)
        if [ -n "$bat" ]; then
            upower -i "$bat" 2>/dev/null | awk '
                /percentage/ { gsub(/[^0-9]/,"",$2); pct=$2 }
                /state/      { st=$2 }
                END          { if (pct != "") printf "%s %s", pct, st }
            '
            return
        fi
    fi

    # sysfs power_supply (embedded Linux ARM, single-board computers, etc.)
    local ps_dir
    for ps_dir in /sys/class/power_supply/BAT* \
                  /sys/class/power_supply/battery \
                  /sys/class/power_supply/bms; do
        [ -r "$ps_dir/capacity" ] || continue
        local pct status
        { read -r pct    < "$ps_dir/capacity"; } 2>/dev/null
        { read -r status < "$ps_dir/status"; }   2>/dev/null
        [[ "$pct" =~ ^[0-9]+$ ]] && printf '%s %s' "$pct" "$status" && return
    done

    printf '%s' ''
}

# Returns: <L1> <L5> <L15> <running/total>
# Uses read builtin directly — zero forks.
_linux_get_loadavg() {
    local l1 l5 l15 rt rest
    if { read -r l1 l5 l15 rt rest < /proc/loadavg; } 2>/dev/null && [ -n "$l1" ]; then
        printf '%s %s %s %s\n' "$l1" "$l5" "$l15" "$rt"
        return
    fi
    local up_str
    up_str=$(uptime 2>/dev/null)
    if [[ "$up_str" =~ load\ average[s]?:\ *([0-9.]+),?\ *([0-9.]+),?\ *([0-9.]+) ]]; then
        printf '%.2f %.2f %.2f --\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" 2>/dev/null && return
    fi
    printf '%s %s %s %s\n' "--" "--" "--" "--"
}

# Uses read builtin + pure bash math — zero forks.
_linux_get_uptime() {
    local raw _
    if { read -r raw _ < /proc/uptime; } 2>/dev/null; then
        if [[ "$raw" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            local s=${raw%%.*}   # integer seconds, no awk needed
            local d=$(( s / 86400 ))
            local h=$(( (s % 86400) / 3600 ))
            local m=$(( (s % 3600) / 60 ))
            if   (( d > 0 )); then printf '%dd %dh %dm' "$d" "$h" "$m"
            elif (( h > 0 )); then printf '%dh %dm' "$h" "$m"
            else                   printf '%dm' "$m"
            fi
            return
        fi
    fi
    _fallback_uptime
}

_linux_find_llama_pid() {
    local d
    for d in /proc/[0-9]*; do
        [ -r "$d/cmdline" ] || continue
        grep -aqE 'llama-(server|cli|run|bench)' "$d/cmdline" 2>/dev/null || continue
        printf '%s' "${d##*/}"
        return 0
    done
    return 1
}

# Returns: <ticks> <rss-pages>
_linux_get_llama_proc_stats() {
    local pid=$1
    [ -r "/proc/$pid/stat" ] || return 1
    local lstat rest L_UT L_ST L_RSS
    { read -r lstat < "/proc/$pid/stat"; } 2>/dev/null || return 1
    rest="${lstat#*) }"
    [[ "$rest" == "$lstat" ]] && return 1
    read -r _ _ _ _ _ _ _ _ _ _ L_UT L_ST _ _ _ _ _ _ _ _ L_RSS <<< "$rest"
    [[ "$L_UT" =~ ^[0-9]+$ && "$L_ST" =~ ^[0-9]+$ ]] || return 1
    printf '%d %d' $(( L_UT + L_ST )) "$L_RSS"
}

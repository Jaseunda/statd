#!/usr/bin/env bash
# sensors_linux.sh — sensor implementations for Linux (x86, ARM, and other kernels)
# Part of statd: https://github.com/Jaseunda/statd

_linux_get_temp() {
    local max=0 temp c type
    for z in /sys/class/thermal/thermal_zone*; do
        [ -r "$z/temp" ] || continue
        [ -r "$z/type" ] || continue
        type=$(cat "$z/type" 2>/dev/null)
        case "$type" in
            cpu-0-*-usr|cpu-0-*-step|cpu-1-*-usr|cpu-1-*-step|\
            x86_pkg_temp|acpitz|coretemp|cpu_thermal|soc_thermal|\
            tsens_tz_sensor*|thermal)
                temp=$(cat "$z/temp" 2>/dev/null)
                [[ "$temp" =~ ^[0-9]+$ ]] || continue
                c=$(( temp / 1000 ))
                (( c >= 0 && c <= 120 && c > max )) && max=$c
                ;;
        esac
    done
    (( max > 0 )) && printf '%d' "$max" || printf '%s' '--'
}

_linux_get_cpu_freq() {
    local max=0 f value
    for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
        [ -r "$f" ] || continue
        value=$(cat "$f" 2>/dev/null)
        [[ "$value" =~ ^[0-9]+$ ]] || continue
        (( value > max )) && max=$value
    done
    if (( max > 0 )); then
        awk -v f="$max" 'BEGIN {
            if (f >= 1000000) printf "%.2fGHz", f/1000000
            else              printf "%.0fMHz",  f/1000
        }'
    else
        printf '%s' '--'
    fi
}

# Returns two integers: <total-jiffies> <idle-jiffies>
_linux_get_cpu_raw() {
    awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8+$9, $5+$6; exit}' /proc/stat 2>/dev/null
}

# Returns total CPU idle microseconds (sum across all cores and idle states).
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
_linux_get_memory() {
    awk '
        /MemTotal:/     { total=$2 }
        /MemAvailable:/ { available=$2 }
        /SwapTotal:/    { swap_total=$2 }
        /SwapFree:/     { swap_free=$2 }
        END {
            used      = total - available
            swap_used = swap_total - swap_free
            printf "%d %d %d %d\n", total, used, swap_total, swap_used
        }
    ' /proc/meminfo
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
        pct=$(cat "$ps_dir/capacity" 2>/dev/null)
        status=$(cat "$ps_dir/status"  2>/dev/null)
        [[ "$pct" =~ ^[0-9]+$ ]] && printf '%s %s' "$pct" "$status" && return
    done

    printf '%s' ''
}

# Returns "L1 L5 L15 running/total"
_linux_get_loadavg() {
    awk '{print $1, $2, $3, $4}' /proc/loadavg 2>/dev/null
}

_linux_get_uptime() {
    if [ -r /proc/uptime ]; then
        local raw
        raw=$(awk '{print $1}' /proc/uptime 2>/dev/null)
        if [[ "$raw" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            awk -v s="$raw" 'BEGIN {
                s=int(s)
                d=int(s/86400); h=int((s%86400)/3600); m=int((s%3600)/60)
                if      (d>0) printf "%dd %dh %dm", d, h, m
                else if (h>0) printf "%dh %dm", h, m
                else          printf "%dm", m
            }'
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
    lstat=$(cat "/proc/$pid/stat" 2>/dev/null)
    rest="${lstat#*) }"
    [[ "$rest" == "$lstat" ]] && return 1
    read -r _ _ _ _ _ _ _ _ _ _ L_UT L_ST _ _ _ _ _ _ _ _ L_RSS <<< "$rest"
    [[ "$L_UT" =~ ^[0-9]+$ && "$L_ST" =~ ^[0-9]+$ ]] || return 1
    printf '%d %d' $(( L_UT + L_ST )) "$L_RSS"
}

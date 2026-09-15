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
    awk '{s+=$1} END{printf "%.0f\n", s}' \
        /sys/devices/system/cpu/cpu*/cpuidle/state*/time 2>/dev/null
}

# Returns "core_index idle_us" lines for per-core residency.
_linux_get_core_idle() {
    awk '
        FNR==1 {
            cpu=FILENAME
            sub(/^.*\/cpu\/cpu/, "", cpu)
            sub(/\/cpuidle.*/, "", cpu)
        }
        { idle[cpu] += $1 }
        END { for (c in idle) printf "%d %.0f\n", c, idle[c] }
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

# Returns: <used_bytes> <total_bytes> for the workload backing pool.
# The pool is a disk-backed directory whose size represents additional
# capacity for background workloads — never conflated with physical RAM
# or kernel swap in the UI.
# Configurable via WORKLOAD_POOL_DIR (local path) or WORKLOAD_POOL_HOST +
# WORKLOAD_POOL_SSH_PORT (remote SSH fetch). WORKLOAD_POOL_CAP_GB sets
# the hard cap (default 32). Returns "0 0" if no pool is configured/available.
_linux_get_workload_pool() {
    local dir="${WORKLOAD_POOL_DIR:-}"
    local cap_gb="${WORKLOAD_POOL_CAP_GB:-32}"
    local cap_bytes=$(( cap_gb * 1024 * 1024 * 1024 ))
    local used_bytes=0

    # --- 1. Local directory path ---
    if [ -n "$dir" ] && [ -d "$dir" ]; then
        used_bytes=$(du -sb "$dir" 2>/dev/null | awk '{print $1}')
        [ -z "$used_bytes" ] && used_bytes=0
    fi

    # --- 2. Remote SSH fetch (fallback when no local dir configured) ---
    if [ -z "$dir" ] || [ ! -d "$dir" ]; then
        local host="${WORKLOAD_POOL_HOST:-}"
        local port="${WORKLOAD_POOL_SSH_PORT:-22}"
        if [ -n "$host" ] && command -v ssh >/dev/null 2>&1; then
            # Fetch pool path and cap from the remote f3s-memmgr.conf,
            # then measure du -sb on the remote pool directory.
            local remote_out
            remote_out=$(ssh -o BatchMode=yes -o ConnectTimeout=5 -p "$port" \
                "$host" '
                POOL="${WORKLOAD_POOL_DIR:-$HOME/storage/shared/workload-pool}"
                CAP_GB="${WORKLOAD_POOL_CAP_GB:-32}"
                echo "$CAP_GB $(du -sb \"$POOL\" 2>/dev/null | awk "{print \$1}")"
                ' 2>/dev/null || true)
            if [ -n "$remote_out" ]; then
                cap_gb=$(echo "$remote_out" | awk '{print $1}')
                used_bytes=$(echo "$remote_out" | awk '{print $2}')
                cap_bytes=$(( cap_gb * 1024 * 1024 * 1024 ))
                [ -z "$used_bytes" ] && used_bytes=0
            fi
        fi
    fi

    printf '%d %d\n' "$used_bytes" "$cap_bytes"
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
    local d comm prog
    for d in /proc/[0-9]*; do
        [ -r "$d/cmdline" ] || continue
        # 1. Check comm (kernel process name) if available
        if [ -r "$d/comm" ]; then
            { read -r comm < "$d/comm"; } 2>/dev/null
            case "$comm" in
                llama-server*|llama-cli*|llama-run*|llama-bench*|llama-simple*)
                    printf '%s' "${d##*/}"
                    return 0
                    ;;
            esac
        fi
        # 2. Check argv[0] from cmdline (first null-terminated token only)
        { read -r -d '' prog < "$d/cmdline"; } 2>/dev/null || continue
        prog="${prog##*/}"
        case "$prog" in
            llama-server*|llama-cli*|llama-run*|llama-bench*|llama-simple*)
                printf '%s' "${d##*/}"
                return 0
                ;;
        esac
    done
    return 1
}

# Returns: <ticks> <rss-pages>
_linux_get_llama_proc_stats() {
    local pid=$1
    [ -r "/proc/$pid/stat" ] || return 1
    local lstat rest L_UT L_ST L_RSS _junk
    { read -r lstat < "/proc/$pid/stat"; } 2>/dev/null || return 1
    rest="${lstat#*) }"
    [[ "$rest" == "$lstat" ]] && return 1
    read -r _ _ _ _ _ _ _ _ _ _ _ L_UT L_ST _ _ _ _ _ _ _ _ L_RSS _junk <<< "$rest"
    [[ "$L_UT" =~ ^[0-9]+$ && "$L_ST" =~ ^[0-9]+$ && "$L_RSS" =~ ^[0-9]+$ ]] || return 1
    printf '%d %d\n' "$(( L_UT + L_ST ))" "$L_RSS" 2>/dev/null
}

# Returns: <util_pct> <mem_used_bytes> <mem_total_bytes> <temp_celsius> <model_name>
_linux_get_gpu() {
    # 1. NVIDIA via nvidia-smi
    if command -v nvidia-smi >/dev/null 2>&1; then
        local n_out
        n_out=$(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,name --format=csv,noheader,nounits 2>/dev/null | head -1)
        if [ -n "$n_out" ]; then
            local u mu mt tp nm
            IFS=',' read -r u mu mt tp nm <<< "$n_out"
            u="${u// /}"
            mu="${mu// /}"
            mt="${mt// /}"
            tp="${tp// /}"
            nm="${nm#"${nm%%[![:space:]]*}"}"
            nm="${nm%"${nm##*[![:space:]]}"}"
            if [[ "$u" =~ ^[0-9]+$ ]]; then
                local b_used=$(( mu * 1048576 ))
                local b_tot=$(( mt * 1048576 ))
                printf '%d %s %s %s %s\n' "$u" "$b_used" "$b_tot" "${tp:---}" "${nm:-NVIDIA}"
                return 0
            fi
        fi
    fi

    # 2. AMD via sysfs (zero forks)
    local card
    for card in /sys/class/drm/card[0-9]/device; do
        if [ -f "$card/gpu_busy_percent" ]; then
            local u b_used=0 b_tot=0 tp="--" nm="AMD GPU"
            if { read -r u < "$card/gpu_busy_percent"; } 2>/dev/null && [[ "$u" =~ ^[0-9]+$ ]]; then
                [ -f "$card/mem_info_vram_used" ] && { read -r b_used < "$card/mem_info_vram_used"; } 2>/dev/null
                [ -f "$card/mem_info_vram_total" ] && { read -r b_tot < "$card/mem_info_vram_total"; } 2>/dev/null
                local tfile raw_t
                for tfile in "$card"/hwmon/hwmon*/temp1_input; do
                    if [ -f "$tfile" ] && { read -r raw_t < "$tfile"; } 2>/dev/null && [[ "$raw_t" =~ ^[0-9]+$ ]]; then
                        tp=$(( raw_t / 1000 ))
                        break
                    fi
                done
                [ -f "$card/product_name" ] && { read -r nm < "$card/product_name"; } 2>/dev/null
                printf '%d %s %s %s %s\n' "$u" "${b_used:-0}" "${b_tot:-0}" "$tp" "$nm"
                return 0
            fi
        fi
    done

    return 1
}

# Returns: <rx_bytes> <tx_bytes> <interface>
_linux_net_iface=""
_linux_get_net() {
    # 1. Detect primary interface
    if [ -z "$_linux_net_iface" ]; then
        if [ -r /proc/net/route ]; then
            _linux_net_iface=$(awk '$2 == "00000000" { print $1; exit }' /proc/net/route 2>/dev/null)
        fi
        if [ -z "$_linux_net_iface" ]; then
            _linux_net_iface=$(ip route show default 2>/dev/null | awk '/default via/{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1); exit}')
        fi
        if [ -z "$_linux_net_iface" ]; then
            _linux_net_iface=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1); exit}')
        fi
        if [ -z "$_linux_net_iface" ]; then
            for _cand in wlan0 rmnet_data0 rmnet0 tun0 eth0 enp0s3; do
                if [ -d "/sys/class/net/$_cand" ]; then
                    _linux_net_iface="$_cand"
                    break
                fi
            done
        fi
    fi

    local line iface rx tx

    # Method A: Direct /proc/net/dev (fastest, zero-fork)
    if [ -r /proc/net/dev ]; then
        if [ -n "$_linux_net_iface" ]; then
            while IFS= read -r line; do
                if [[ "$line" =~ ^[[:space:]]*(${_linux_net_iface}):[[:space:]]*([0-9]+)[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+([0-9]+) ]]; then
                    printf '%s %s %s\n' "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "$_linux_net_iface"
                    return 0
                fi
            done < /proc/net/dev
        fi

        # Fallback in /proc/net/dev: scan first active non-virtual interface
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_-]+):[[:space:]]*([0-9]+)[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]+([0-9]+) ]]; then
                iface="${BASH_REMATCH[1]}"
                [[ "$iface" == "lo" || "$iface" == "docker0" || "$iface" =~ ^veth ]] && continue
                rx="${BASH_REMATCH[2]}"
                tx="${BASH_REMATCH[3]}"
                if (( rx > 0 || tx > 0 )); then
                    _linux_net_iface="$iface"
                    printf '%s %s %s\n' "$rx" "$tx" "$iface"
                    return 0
                fi
            fi
        done < /proc/net/dev
    fi

    # Method B: Sysfs network statistics (/sys/class/net/$iface/statistics)
    if [ -n "$_linux_net_iface" ] && [ -r "/sys/class/net/$_linux_net_iface/statistics/rx_bytes" ]; then
        { read -r rx < "/sys/class/net/$_linux_net_iface/statistics/rx_bytes"; } 2>/dev/null
        { read -r tx < "/sys/class/net/$_linux_net_iface/statistics/tx_bytes"; } 2>/dev/null
        if [[ "$rx" =~ ^[0-9]+$ ]] && [[ "$tx" =~ ^[0-9]+$ ]]; then
            printf '%s %s %s\n' "$rx" "$tx" "$_linux_net_iface"
            return 0
        fi
    fi

    # Method C: Netlink socket via ip -s link (bypasses /proc/net permissions on restricted kernels)
    if [ -n "$_linux_net_iface" ] && command -v ip >/dev/null 2>&1; then
        local ip_stats
        ip_stats=$(ip -s link show "$_linux_net_iface" 2>/dev/null | awk '/RX:/{getline; print $1} /TX:/{getline; print $1}')
        if [ -n "$ip_stats" ]; then
            read -r rx tx <<< "$ip_stats"
            if [[ "$rx" =~ ^[0-9]+$ ]] && [[ "$tx" =~ ^[0-9]+$ ]]; then
                printf '%s %s %s\n' "$rx" "$tx" "$_linux_net_iface"
                return 0
            fi
        fi
    fi

    return 1
}



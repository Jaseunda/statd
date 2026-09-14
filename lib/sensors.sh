#!/usr/bin/env bash
# sensors.sh — OS detection, core count, sensor dispatchers
# Part of statd: https://github.com/Jaseunda/statd
#
# This file must be sourced AFTER sensors_linux.sh and sensors_macos.sh.

# ---- OS detection ----
OS_TYPE="linux"
case "$(uname -s)" in
    Darwin) OS_TYPE="macos" ;;
esac

# ---- Logical CPU count ----
if [ "$OS_TYPE" = "macos" ]; then
    NCPU=$(sysctl -n hw.logicalcpu 2>/dev/null)
else
    NCPU=$(ls -d /sys/devices/system/cpu/cpu[0-9]* 2>/dev/null | wc -l)
fi
[[ "$NCPU" =~ ^[0-9]+$ ]] || NCPU=1
(( NCPU < 1 )) && NCPU=1

# ---- Uptime fallback (parses `uptime` command output) ----
_fallback_uptime() {
    local ut mins
    ut=$(uptime 2>/dev/null)
    if [[ "$ut" =~ up[[:space:]]+([0-9]+)[[:space:]]+day[s]?,[[:space:]]*([0-9]+):([0-9]+) ]]; then
        printf '%dd %dh %dm' \
            "${BASH_REMATCH[1]}" \
            "$((10#${BASH_REMATCH[2]}))" \
            "$((10#${BASH_REMATCH[3]}))"
    elif [[ "$ut" =~ up[[:space:]]+([0-9]+):([0-9]+) ]]; then
        printf '%dh %dm' \
            "$((10#${BASH_REMATCH[1]}))" \
            "$((10#${BASH_REMATCH[2]}))"
    elif [[ "$ut" =~ up[[:space:]]+([0-9]+)[[:space:]]+min ]]; then
        mins=${BASH_REMATCH[1]}
        printf '%dh %dm' $(( mins / 60 )) $(( mins % 60 ))
    else
        printf '%s' '--'
    fi
}

# ---- Dispatchers ----

get_temp() {
    [ "$OS_TYPE" = "macos" ] && _macos_get_temp || _linux_get_temp
}

get_cpu_freq() {
    [ "$OS_TYPE" = "macos" ] && _macos_get_cpu_freq || _linux_get_cpu_freq
}

# Returns: <total> <idle>  (jiffies on Linux, tenths-of-percent on macOS)
get_cpu_raw() {
    [ "$OS_TYPE" = "macos" ] && _macos_get_cpu_raw || _linux_get_cpu_raw
}

# Returns total idle microseconds across all cores (Linux only).
get_idle_us() {
    [ "$OS_TYPE" = "linux" ] && _linux_get_idle_us || printf '0'
}

# Returns "core idle_us" lines (Linux only; macOS yields nothing).
get_core_idle() {
    [ "$OS_TYPE" = "linux" ] && _linux_get_core_idle || true
}

# Returns: <total_kB> <used_kB> <swap_total_kB> <swap_used_kB>
get_memory() {
    [ "$OS_TYPE" = "macos" ] && _macos_get_memory || _linux_get_memory
}

# Returns: <pct> <status>  or empty string if no battery detected.
get_battery() {
    [ "$OS_TYPE" = "macos" ] && _macos_get_battery || _linux_get_battery
}

# Returns: <L1> <L5> <L15> <running/total>
get_loadavg() {
    [ "$OS_TYPE" = "macos" ] && _macos_get_loadavg || _linux_get_loadavg
}

get_uptime() {
    [ "$OS_TYPE" = "macos" ] && _macos_get_uptime || _linux_get_uptime
}

# Returns: <total_bytes> <used_bytes>  for $HOME filesystem.
get_disk() {
    df -k "$HOME" 2>/dev/null | awk 'NR==2 { printf "%.0f %.0f\n", $2*1024, $3*1024 }'
}

# find_llama_pid — returns PID of a running llama process, or empty.
find_llama_pid() {
    [ "$OS_TYPE" = "macos" ] && _macos_find_llama_pid || _linux_find_llama_pid
}

# get_llama_proc_stats <pid>
# Returns: <ticks_or_cpu_pct> <rss>
# Linux: ticks (from /proc/pid/stat), rss in pages
# macOS: cpu_pct (integer), rss in kB
get_llama_proc_stats() {
    local pid=$1
    [ "$OS_TYPE" = "macos" ] && _macos_get_llama_proc_stats "$pid" \
                              || _linux_get_llama_proc_stats "$pid"
}

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
    if [ "$OS_TYPE" = "macos" ]; then _macos_get_temp; else _linux_get_temp; fi
}

get_cpu_freq() {
    if [ "$OS_TYPE" = "macos" ]; then _macos_get_cpu_freq; else _linux_get_cpu_freq; fi
}

# Returns: <util_pct> <mem_used_bytes> <mem_total_bytes> <temp_celsius> <model_name>
get_gpu() {
    if [ "$OS_TYPE" = "macos" ]; then _macos_get_gpu; else _linux_get_gpu; fi
}

# Returns: <total> <idle> (or PCT <val>)
get_cpu_raw() {
    if [ "$OS_TYPE" = "macos" ]; then _macos_get_cpu_raw; else _linux_get_cpu_raw; fi
}

# Returns total idle microseconds across all cores (Linux only).
get_idle_us() {
    if [ "$OS_TYPE" = "linux" ]; then _linux_get_idle_us; else printf '0'; fi
}

# Returns "core idle_us" lines (Linux only; macOS yields nothing).
get_core_idle() {
    if [ "$OS_TYPE" = "linux" ]; then _linux_get_core_idle; else true; fi
}

# Returns: <total_kB> <used_kB> <swap_total_kB> <swap_used_kB>
get_memory() {
    if [ "$OS_TYPE" = "macos" ]; then _macos_get_memory; else _linux_get_memory; fi
}

# Returns: <pct> <status>  or empty string if no battery detected.
get_battery() {
    if [ "$OS_TYPE" = "macos" ]; then _macos_get_battery; else _linux_get_battery; fi
}

# Returns: <L1> <L5> <L15> <running/total>
get_loadavg() {
    if [ "$OS_TYPE" = "macos" ]; then _macos_get_loadavg; else _linux_get_loadavg; fi
}

get_uptime() {
    if [ "$OS_TYPE" = "macos" ]; then _macos_get_uptime; else _linux_get_uptime; fi
}

# Returns: <total_bytes> <used_bytes>  for $HOME filesystem.
get_disk() {
    df -k "$HOME" 2>/dev/null | awk 'NR==2 { printf "%.0f %.0f\n", $2*1024, $3*1024 }'
}

# find_llama_pid — returns PID of a running llama process, or empty.
find_llama_pid() {
    if [ "$OS_TYPE" = "macos" ]; then _macos_find_llama_pid; else _linux_find_llama_pid; fi
}

# get_llama_proc_stats <pid>
# Returns: <ticks_or_cpu_pct> <rss>
# Linux: ticks (from /proc/pid/stat), rss in pages
# macOS: cpu_pct (integer), rss in kB
get_llama_proc_stats() {
    local pid=$1
    if [ "$OS_TYPE" = "macos" ]; then
        _macos_get_llama_proc_stats "$pid"
    else
        _linux_get_llama_proc_stats "$pid"
    fi
}

# Returns: <rx_bytes> <tx_bytes> <interface>
get_network() {
    if [ "$OS_TYPE" = "macos" ]; then
        _macos_get_net
    else
        _linux_get_net
    fi
}


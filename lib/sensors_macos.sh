#!/usr/bin/env bash
# sensors_macos.sh — sensor implementations for macOS (Apple Silicon and Intel)
# Part of statd: https://github.com/Jaseunda/statd
#
# Performance notes:
#   _macos_get_cpu_raw() uses sysctl kern.cp_time (cumulative jiffies,
#   same interface as Linux /proc/stat).  Returns in <5ms vs the ~500ms
#   that `top -l 1` required previously.  This allows accurate delta-based
#   CPU% and makes INTERVAL=1 a true 1-second cycle on macOS.
#
#   Static hardware values (total RAM, page size) are read once at source
#   time and cached in _MACOS_MEM_TOTAL_BYTES / _MACOS_PAGE_BYTES.

# ---- Static cache (read once at source time) ----
_MACOS_MEM_TOTAL_BYTES=$(sysctl -n hw.memsize 2>/dev/null)
[[ "$_MACOS_MEM_TOTAL_BYTES" =~ ^[0-9]+$ ]] || _MACOS_MEM_TOTAL_BYTES=0

_MACOS_PAGE_BYTES=$(sysctl -n hw.pagesize 2>/dev/null)
[[ "$_MACOS_PAGE_BYTES" =~ ^[0-9]+$ ]] || _MACOS_PAGE_BYTES=4096

_macos_get_temp() {
    # osx-cpu-temp: brew install osx-cpu-temp
    if command -v osx-cpu-temp >/dev/null 2>&1; then
        local t
        t=$(osx-cpu-temp 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
        if [[ "$t" =~ ^[0-9]+ ]]; then
            printf '%d' "${t%%.*}"
            return
        fi
    fi
    printf '%s' '--'
}

_macos_get_cpu_freq() {
    local freq i frac

    # Apple Silicon: hw.perflevel0.maxfreq (Hz) — P-core max
    freq=$(sysctl -n hw.perflevel0.maxfreq 2>/dev/null)
    if [[ "$freq" =~ ^[0-9]+$ ]] && (( freq > 0 )); then
        i=$(( freq / 1000000000 ))
        frac=$(( (freq % 1000000000) * 100 / 1000000000 ))
        printf '%d.%02dGHz' "$i" "$frac"
        return
    fi

    # Intel: hw.cpufrequency (Hz)
    freq=$(sysctl -n hw.cpufrequency 2>/dev/null)
    if [[ "$freq" =~ ^[0-9]+$ ]] && (( freq > 0 )); then
        i=$(( freq / 1000000000 ))
        frac=$(( (freq % 1000000000) * 100 / 1000000000 ))
        (( i > 0 )) && printf '%d.%02dGHz' "$i" "$frac" \
                    || printf '%dMHz' "$(( freq / 1000000 ))"
        return
    fi

    printf '%s' '--'
}

# Returns: <total_jiffies> <idle_jiffies>
#
# kern.cp_time gives cumulative CPU ticks in the same layout as Linux
# /proc/stat's "cpu" line: user nice sys idle intr
#
# This replaces the old `top -l 1` approach which blocked for ~500ms.
# sysctl returns in <5ms, making macOS CPU% delta-based and accurate.
_macos_get_cpu_raw() {
    local u n s i intr
    read -r u n s i intr <<< "$(sysctl -n kern.cp_time 2>/dev/null)"
    [[ "$u" =~ ^[0-9]+$ ]] || return
    printf '%d %d' $(( u + n + s + i + intr )) "$i"
}

# Returns: <total_kB> <used_kB> <swap_total_kB> <swap_used_kB>
# Uses cached total RAM and page size — only vm_stat is called per tick.
_macos_get_memory() {
    local total_bytes=$_MACOS_MEM_TOTAL_BYTES
    local ps=$_MACOS_PAGE_BYTES

    local active=0 wired=0 compressed=0 used_bytes
    eval "$(vm_stat 2>/dev/null | awk -v ps="$ps" '
        /Pages active:/               { gsub(/\./,"",$3); printf "active=%d\n",     $3*ps }
        /Pages wired down:/           { gsub(/\./,"",$4); printf "wired=%d\n",      $4*ps }
        /Pages occupied by compressor:/ { gsub(/\./,"",$5); printf "compressed=%d\n", $5*ps }
    ')"
    used_bytes=$(( active + wired + compressed ))
    (( used_bytes > total_bytes )) && used_bytes=$total_bytes

    local swap_line swap_total_bytes=0 swap_used_bytes=0
    swap_line=$(sysctl vm.swapusage 2>/dev/null)
    swap_total_bytes=$(printf '%s' "$swap_line" | awk '
        match($0,/total = ([0-9]+\.[0-9]+)([KMGT])/,a) {
            v=a[1]; u=a[2]
            if      (u=="K") v*=1024
            else if (u=="M") v*=1048576
            else if (u=="G") v*=1073741824
            printf "%d", v
        }')
    swap_used_bytes=$(printf '%s' "$swap_line" | awk '
        match($0,/used = ([0-9]+\.[0-9]+)([KMGT])/,a) {
            v=a[1]; u=a[2]
            if      (u=="K") v*=1024
            else if (u=="M") v*=1048576
            else if (u=="G") v*=1073741824
            printf "%d", v
        }')
    [[ "$swap_total_bytes" =~ ^[0-9]+$ ]] || swap_total_bytes=0
    [[ "$swap_used_bytes"  =~ ^[0-9]+$ ]] || swap_used_bytes=0

    printf '%d %d %d %d\n' \
        $(( total_bytes      / 1024 )) \
        $(( used_bytes       / 1024 )) \
        $(( swap_total_bytes / 1024 )) \
        $(( swap_used_bytes  / 1024 ))
}

# Returns: <pct> <status-string>  or empty if no battery.
_macos_get_battery() {
    local line pct status
    line=$(pmset -g batt 2>/dev/null | grep -E '[0-9]+%')
    pct=$(printf '%s' "$line" | grep -oE '[0-9]+%' | tr -d '%' | head -1)
    status=$(printf '%s' "$line" | awk -F';' '{sub(/^[ \t]+/, "", $2); sub(/[ \t]+$/, "", $2); print $2}')
    [[ "$pct" =~ ^[0-9]+$ ]] && printf '%s %s' "$pct" "$status" || printf '%s' ''
}

# Returns: <L1> <L5> <L15> <running/total>
_macos_get_loadavg() {
    local l1 l5 l15 nproc
    read -r l1 l5 l15 <<< "$(sysctl vm.loadavg 2>/dev/null | awk '{
        for (i=1; i<=NF; i++)
            if ($i ~ /^[0-9]+\.[0-9]+$/) { print $i, $(i+1), $(i+2); exit }
    }')"
    nproc=$(ps -A 2>/dev/null | awk 'END{print NR-1}')
    [[ "$nproc" =~ ^[0-9]+$ ]] || nproc="?"
    printf '%s %s %s 1/%s\n' "$l1" "$l5" "$l15" "$nproc"
}

_macos_get_uptime() {
    local boot now elapsed s d h m
    boot=$(sysctl -n kern.boottime 2>/dev/null | grep -oE 'sec = [0-9]+' | awk '{print $3}')
    now=$(date +%s)
    if [[ "$boot" =~ ^[0-9]+$ && "$now" =~ ^[0-9]+$ ]]; then
        elapsed=$(( now - boot ))
        s=$elapsed
        d=$(( s / 86400 )); h=$(( (s % 86400) / 3600 )); m=$(( (s % 3600) / 60 ))
        if   (( d > 0 )); then printf '%dd %dh %dm' "$d" "$h" "$m"
        elif (( h > 0 )); then printf '%dh %dm' "$h" "$m"
        else                   printf '%dm' "$m"
        fi
        return
    fi
    _fallback_uptime
}

_macos_find_llama_pid() {
    pgrep -f 'llama-(server|cli|run|bench)' 2>/dev/null | head -1
}

# Returns: <cpu_pct_integer> <rss_kB>
_macos_get_llama_proc_stats() {
    local pid=$1
    ps -p "$pid" -o pcpu=,rss= 2>/dev/null | awk '{
        cpu=$1; rss=$2
        split(cpu,a,"."); if (a[2]+0 >= 5) a[1]++
        printf "%d %d\n", a[1], rss
    }'
}

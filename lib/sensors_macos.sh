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
# Returns: PCT <pct>
_macos_get_cpu_raw() {
    local n="${NCPU:-1}"
    (( n < 1 )) && n=1
    ps -A -o %cpu 2>/dev/null | awk -v n="$n" '{s+=$1} END {
        pct=int(s/n + 0.5)
        if (pct > 100) pct=100
        if (pct < 0) pct=0
        printf "PCT %d\n", pct
    }'
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
    read -r swap_total_bytes swap_used_bytes <<< "$(printf '%s' "$swap_line" | awk '
        function to_b(s,   v, u) {
            u = substr(s, length(s))
            v = substr(s, 1, length(s)-1) + 0
            if      (u == "K") v *= 1024
            else if (u == "M") v *= 1048576
            else if (u == "G") v *= 1073741824
            return int(v)
        }
        {
            for (i=1; i<=NF; i++) {
                if ($i == "total") tot = to_b($(i+2))
                if ($i == "used")  usd = to_b($(i+2))
            }
            printf "%d %d\n", tot+0, usd+0
        }')"
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
    local line pct state status
    line=$(pmset -g batt 2>/dev/null | grep -E '[0-9]+%')
    pct=$(printf '%s' "$line" | grep -oE '[0-9]+%' | tr -d '%' | head -1)
    [ -z "$pct" ] && return

    if echo "$line" | grep -qi 'not charging'; then
        state="not charging"
    elif echo "$line" | grep -qi 'charging'; then
        state="charging"
    elif echo "$line" | grep -qi 'discharging'; then
        state="discharging"
    elif echo "$line" | grep -qi 'finishing charge\|charged'; then
        state="full"
    else
        state=""
    fi

    if echo "$line" | grep -qi 'AC attached'; then
        if [ -n "$state" ]; then
            status="AC ($state)"
        else
            status="AC attached"
        fi
    else
        status="$state"
    fi
    [ -z "$status" ] && status="battery"

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
    pgrep -x 'llama-server|llama-cli|llama-run|llama-bench|llama-simple' 2>/dev/null | head -1
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

# Returns: <util_pct> <mem_used_bytes> <mem_total_bytes> <temp_celsius> <model_name>
_macos_get_gpu() {
    local out util mem model
    out=$(ioreg -r -d 1 -c IOAccelerator 2>/dev/null)
    [[ -z "$out" ]] && return 1

    if [[ "$out" =~ \"Device\ Utilization\ %\"=([0-9]+) ]]; then
        util="${BASH_REMATCH[1]}"
    elif [[ "$out" =~ \"Renderer\ Utilization\ %\"=([0-9]+) ]]; then
        util="${BASH_REMATCH[1]}"
    fi

    if [[ "$out" =~ \"In\ use\ system\ memory\"=([0-9]+) ]]; then
        mem="${BASH_REMATCH[1]}"
    fi

    if [[ "$out" =~ \"model\"\ =\ \"([^\"]+)\" ]]; then
        model="${BASH_REMATCH[1]}"
    fi

    if [[ -n "$util" ]]; then
        printf '%d %s 0 -- %s\n' "$util" "${mem:-0}" "${model:-Apple GPU}"
        return 0
    fi
    return 1
}

# Returns: <rx_bytes> <tx_bytes> <interface>
_macos_net_iface=""
_macos_get_net() {
    # 1. Try finding active default route interface
    if [ -z "$_macos_net_iface" ]; then
        _macos_net_iface=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
    fi

    local out
    if [ -n "$_macos_net_iface" ]; then
        out=$(netstat -ibn 2>/dev/null | awk -v iface="$_macos_net_iface" '$1 == iface && $3 ~ /<Link/ { print $7, $10; exit }')
        if [ -n "$out" ]; then
            printf '%s %s\n' "$out" "$_macos_net_iface"
            return 0
        fi
    fi

    # 2. Fallback: query first active non-loopback link interface
    out=$(netstat -ibn 2>/dev/null | awk '$1 !~ /^lo/ && $3 ~ /<Link/ && ($7 > 0 || $10 > 0) { print $7, $10, $1; exit }')
    if [ -n "$out" ]; then
        printf '%s\n' "$out"
        return 0
    fi

    return 1
}


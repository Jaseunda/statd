#!/usr/bin/env bash
# sensors_macos.sh — sensor implementations for macOS (Apple Silicon and Intel)
# Part of statd: https://github.com/Jaseunda/statd

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
    # powermetrics requires root; skip silently and show '--'
    printf '%s' '--'
}

_macos_get_cpu_freq() {
    local freq

    # Apple Silicon: hw.perflevel0.maxfreq (Hz)
    freq=$(sysctl -n hw.perflevel0.maxfreq 2>/dev/null)
    if [[ "$freq" =~ ^[0-9]+$ ]] && (( freq > 0 )); then
        awk -v f="$freq" 'BEGIN {
            if (f >= 1000000000) printf "%.2fGHz", f/1000000000
            else                 printf "%.0fMHz",  f/1000000
        }'
        return
    fi

    # Intel: hw.cpufrequency (Hz)
    freq=$(sysctl -n hw.cpufrequency 2>/dev/null)
    if [[ "$freq" =~ ^[0-9]+$ ]] && (( freq > 0 )); then
        awk -v f="$freq" 'BEGIN {
            if (f >= 1000000000) printf "%.2fGHz", f/1000000000
            else                 printf "%.0fMHz",  f/1000000
        }'
        return
    fi

    printf '%s' '--'
}

# Returns: <total-tenths> <idle-tenths>
# Parses the instantaneous CPU usage line from top.
_macos_get_cpu_raw() {
    local line user sys idle u10 s10 i10
    line=$(top -l 1 -n 0 -s 0 2>/dev/null | grep -i "^CPU usage")
    user=$(printf '%s' "$line" | grep -oE '[0-9]+\.[0-9]+% user' | grep -oE '[0-9]+\.[0-9]+')
    sys=$(printf  '%s' "$line" | grep -oE '[0-9]+\.[0-9]+% sys'  | grep -oE '[0-9]+\.[0-9]+')
    idle=$(printf '%s' "$line" | grep -oE '[0-9]+\.[0-9]+% idle' | grep -oE '[0-9]+\.[0-9]+')
    if [[ "$user" =~ ^[0-9] && "$idle" =~ ^[0-9] ]]; then
        u10=$(awk -v v="$user" 'BEGIN{printf "%.0f", v*10}')
        s10=$(awk -v v="$sys"  'BEGIN{printf "%.0f", v*10}')
        i10=$(awk -v v="$idle" 'BEGIN{printf "%.0f", v*10}')
        printf '%d %d' $(( u10 + s10 + i10 )) "$i10"
    fi
}

# Returns: <total_kB> <used_kB> <swap_total_kB> <swap_used_kB>
_macos_get_memory() {
    local total_bytes ps
    total_bytes=$(sysctl -n hw.memsize 2>/dev/null)
    [[ "$total_bytes" =~ ^[0-9]+$ ]] || total_bytes=0
    ps=$(sysctl -n hw.pagesize 2>/dev/null)
    [[ "$ps" =~ ^[0-9]+$ ]] || ps=4096

    local active wired compressed used_bytes
    eval "$(vm_stat 2>/dev/null | awk -v ps="$ps" '
        /Pages active:/               { gsub(/\./,"",$3); printf "active=%d\n",     $3*ps }
        /Pages wired down:/           { gsub(/\./,"",$4); printf "wired=%d\n",      $4*ps }
        /Pages occupied by compressor:/ { gsub(/\./,"",$5); printf "compressed=%d\n", $5*ps }
    ')"
    active=${active:-0}; wired=${wired:-0}; compressed=${compressed:-0}
    used_bytes=$(( active + wired + compressed ))
    (( used_bytes > total_bytes )) && used_bytes=$total_bytes

    local swap_line swap_total_bytes swap_used_bytes
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
    status=$(printf '%s' "$line" | awk -F';' '{gsub(/ /,"",$2); print $2}')
    [[ "$pct" =~ ^[0-9]+$ ]] && printf '%s %s' "$pct" "$status" || printf '%s' ''
}

# Returns "L1 L5 L15 running/total"
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
    local boot now elapsed
    boot=$(sysctl -n kern.boottime 2>/dev/null | grep -oE 'sec = [0-9]+' | awk '{print $3}')
    now=$(date +%s)
    if [[ "$boot" =~ ^[0-9]+$ && "$now" =~ ^[0-9]+$ ]]; then
        elapsed=$(( now - boot ))
        awk -v s="$elapsed" 'BEGIN {
            d=int(s/86400); h=int((s%86400)/3600); m=int((s%3600)/60)
            if      (d>0) printf "%dd %dh %dm", d, h, m
            else if (h>0) printf "%dh %dm", h, m
            else          printf "%dm", m
        }'
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
        # round pcpu to nearest integer
        split(cpu,a,"."); if (a[2]+0 >= 5) a[1]++
        printf "%d %d\n", a[1], rss
    }'
}

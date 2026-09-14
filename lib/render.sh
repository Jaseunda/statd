#!/usr/bin/env bash
# render.sh — gradient bars, row builder, human-readable sizes
# Part of statd: https://github.com/Jaseunda/statd
#
# Performance notes:
#   human()        — pure bash integer math, zero forks
#   bar_gradient() — pure bash loop, no seq fork
#   All other functions are fork-free

# Pre-built empty-bar string (enough for any realistic BAR_WIDTH).
# Substring slice is faster than any loop or seq call.
_STATD_EMPTY='░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░'

# Internal: map a 0-255 color channel to a 0-5 xterm-256 cube index.
bar_grad_level() {
    printf '%d' $(( (${1:-0} * 5 + 127) / 255 ))
}

# bar_gradient <pct> [width] [mode]
# Prints a filled gradient bar. No external process forks.
# mode: "load" (green->yellow->red)   "mag" (purple->blue)
bar_gradient() {
    local pct=$1 width=${2:-$BAR_WIDTH} mode=${3:-load}
    [[ "$pct" =~ ^[0-9]+$ ]] || pct=0
    (( pct <   0 )) && pct=0
    (( pct > 100 )) && pct=100
    (( width < 1 )) && width=1

    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local denom=$(( width > 1 ? width - 1 : 1 ))

    local i t r g b rl gl bl idx tt
    for (( i=0; i<filled; i++ )); do
        t=$(( i * 1000 / denom ))
        if [ "$mode" = "mag" ]; then
            r=$(( 220 + (140 - 220) * t / 1000 ))
            g=$(( 130 + (0   - 130) * t / 1000 ))
            b=$(( 255 + (180 - 255) * t / 1000 ))
        else
            if (( t <= 500 )); then
                tt=$(( t * 2 ))
                r=$(( (225 * tt) / 1000 ))
                g=200
                b=0
            else
                tt=$(( (t - 500) * 2 ))
                r=225
                g=$(( 200 + (40 - 200) * tt / 1000 ))
                b=0
            fi
        fi
        rl=$(bar_grad_level "$r")
        gl=$(bar_grad_level "$g")
        bl=$(bar_grad_level "$b")
        idx=$(( 16 + 36*rl + 6*gl + bl ))
        printf '\033[38;5;%dm\xe2\x96\x88' "$idx"
    done

    # Empty portion — substring of pre-built string, no fork
    printf '%s' "$C_GREY"
    (( empty > 0 )) && printf '%s' "${_STATD_EMPTY:0:$empty}"
    printf '%s' "$C_RESET"
}

# core_cell <core-index> <pct>
core_cell() {
    local c=$1 pct=$2 bar col
    bar=$(bar_gradient "$pct" "$CORE_BAR_W" load)
    col=$(pct_color "$pct")
    printf '%sc%d %s%s%3s%%%s' "$C_GREY" "$c" "$bar" "$col" "$pct" "$C_RESET"
}

row_start() { ROW_PLAIN=""; ROW_COLORED=""; }

seg() {
    local text="$1" color="$2"
    ROW_PLAIN+="$text"
    if [ -n "$color" ]; then
        ROW_COLORED+="${color}${text}${C_RESET}"
    else
        ROW_COLORED+="$text"
    fi
}

# human <bytes>
# Pure bash integer arithmetic — no awk fork.
# Matches original output format: %.2fG / %.1fM / %.1fK / B
human() {
    local n=${1:-0} i f
    if   (( n >= 1073741824 )); then
        i=$(( n / 1073741824 ))
        f=$(( (n % 1073741824) * 100 / 1073741824 ))
        printf '%d.%02dG' "$i" "$f"
    elif (( n >= 1048576 )); then
        i=$(( n / 1048576 ))
        f=$(( (n % 1048576) * 10 / 1048576 ))
        printf '%d.%dM' "$i" "$f"
    elif (( n >= 1024 )); then
        i=$(( n / 1024 ))
        f=$(( (n % 1024) * 10 / 1024 ))
        printf '%d.%dK' "$i" "$f"
    else
        printf '%dB' "$n"
    fi
}

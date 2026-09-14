#!/usr/bin/env bash
# render.sh — gradient bars, row builder, human-readable sizes
# Part of statd: https://github.com/Jaseunda/statd
#
# Performance notes:
#   human()        — pure bash integer math, zero forks
#   bar_gradient() — pure bash loop, no seq fork
#   All other functions are fork-free

_STATD_EMPTY='░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░'
_STATD_EMPTY="${_STATD_EMPTY}${_STATD_EMPTY}${_STATD_EMPTY}${_STATD_EMPTY}"

# Internal: map a 0-255 color channel to a 0-5 xterm-256 cube index.
bar_grad_level() {
    printf '%d' $(( (${1:-0} * 5 + 127) / 255 ))
}

# bar_gradient <pct> [width] [mode]
# Prints a filled gradient bar. No external process forks.
# mode: "load", "cyan", "mag", "amber", "purple", "matrix", "nord", or "R1,G1,B1:R2,G2,B2"
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
    # Pre-parse custom RGB gradient if format R1,G1,B1:R2,G2,B2
    local custom=0 cr1=0 cg1=0 cb1=0 cr2=0 cg2=0 cb2=0
    if [[ "$mode" =~ ^([0-9]+),([0-9]+),([0-9]+):([0-9]+),([0-9]+),([0-9]+)$ ]]; then
        custom=1
        cr1="${BASH_REMATCH[1]}"; cg1="${BASH_REMATCH[2]}"; cb1="${BASH_REMATCH[3]}"
        cr2="${BASH_REMATCH[4]}"; cg2="${BASH_REMATCH[5]}"; cb2="${BASH_REMATCH[6]}"
    fi

    for (( i=0; i<filled; i++ )); do
        t=$(( i * 1000 / denom ))
        if (( custom )); then
            r=$(( cr1 + (cr2 - cr1) * t / 1000 ))
            g=$(( cg1 + (cg2 - cg1) * t / 1000 ))
            b=$(( cb1 + (cb2 - cb1) * t / 1000 ))
        else
            case "$mode" in
                cyan)
                    r=$(( 0   + (30  - 0)   * t / 1000 ))
                    g=$(( 240 + (110 - 240) * t / 1000 ))
                    b=$(( 255 + (220 - 255) * t / 1000 ))
                    ;;
                mag)
                    r=$(( 220 + (140 - 220) * t / 1000 ))
                    g=$(( 130 + (0   - 130) * t / 1000 ))
                    b=$(( 255 + (180 - 255) * t / 1000 ))
                    ;;
                amber)
                    r=$(( 255 + (220 - 255) * t / 1000 ))
                    g=$(( 180 + (40  - 180) * t / 1000 ))
                    b=$(( 20  + (0   - 20)  * t / 1000 ))
                    ;;
                purple|pink)
                    r=$(( 235 + (140 - 235) * t / 1000 ))
                    g=$(( 80  + (0   - 80)  * t / 1000 ))
                    b=$(( 255 + (200 - 255) * t / 1000 ))
                    ;;
                matrix)
                    r=$(( 40  + (0   - 40)  * t / 1000 ))
                    g=$(( 255 + (130 - 255) * t / 1000 ))
                    b=$(( 60  + (20  - 60)  * t / 1000 ))
                    ;;
                nord)
                    r=$(( 143 + (94  - 143) * t / 1000 ))
                    g=$(( 188 + (129 - 188) * t / 1000 ))
                    b=$(( 187 + (172 - 187) * t / 1000 ))
                    ;;
                tokyo)
                    r=$(( 122 + (65  - 122) * t / 1000 ))
                    g=$(( 162 + (80  - 162) * t / 1000 ))
                    b=$(( 247 + (160 - 247) * t / 1000 ))
                    ;;
                gruvbox)
                    r=$(( 214 + (157 - 214) * t / 1000 ))
                    g=$(( 93  + (30  - 93)  * t / 1000 ))
                    b=$(( 14  + (5   - 14)  * t / 1000 ))
                    ;;
                forest)
                    r=$(( 142 + (60  - 142) * t / 1000 ))
                    g=$(( 192 + (110 - 192) * t / 1000 ))
                    b=$(( 124 + (45  - 124) * t / 1000 ))
                    ;;
                rose)
                    r=$(( 235 + (180 - 235) * t / 1000 ))
                    g=$(( 110 + (40  - 110) * t / 1000 ))
                    b=$(( 150 + (90  - 150) * t / 1000 ))
                    ;;
                ocean|blue)
                    r=$(( 0   + (0   - 0)   * t / 1000 ))
                    g=$(( 180 + (70  - 180) * t / 1000 ))
                    b=$(( 255 + (160 - 255) * t / 1000 ))
                    ;;
                emerald)
                    r=$(( 0   + (0   - 0)   * t / 1000 ))
                    g=$(( 230 + (120 - 230) * t / 1000 ))
                    b=$(( 140 + (60  - 140) * t / 1000 ))
                    ;;
                lava|red|crimson)
                    r=$(( 255 + (180 - 255) * t / 1000 ))
                    g=$(( 60  + (10  - 60)  * t / 1000 ))
                    b=$(( 30  + (0   - 30)  * t / 1000 ))
                    ;;
                gold|yellow)
                    r=$(( 255 + (218 - 255) * t / 1000 ))
                    g=$(( 215 + (140 - 215) * t / 1000 ))
                    b=0
                    ;;
                sakura)
                    r=$(( 255 + (220 - 255) * t / 1000 ))
                    g=$(( 180 + (110 - 180) * t / 1000 ))
                    b=$(( 200 + (140 - 200) * t / 1000 ))
                    ;;
                stealth)
                    r=$(( 225 + (120 - 225) * t / 1000 ))
                    g=$(( 230 + (125 - 230) * t / 1000 ))
                    b=$(( 235 + (130 - 235) * t / 1000 ))
                    ;;
                glacier|ice)
                    r=$(( 160 + (30  - 160) * t / 1000 ))
                    g=$(( 240 + (130 - 240) * t / 1000 ))
                    b=$(( 255 + (240 - 255) * t / 1000 ))
                    ;;
                mocha|coffee)
                    r=$(( 215 + (115 - 215) * t / 1000 ))
                    g=$(( 160 + (65  - 160) * t / 1000 ))
                    b=$(( 110 + (30  - 110) * t / 1000 ))
                    ;;
                amethyst|violet)
                    r=$(( 210 + (110 - 210) * t / 1000 ))
                    g=$(( 120 + (30  - 120) * t / 1000 ))
                    b=$(( 255 + (210 - 255) * t / 1000 ))
                    ;;
                flame|blaze)
                    r=$(( 255 + (240 - 255) * t / 1000 ))
                    g=$(( 215 + (70  - 215) * t / 1000 ))
                    b=0
                    ;;
                load|*)
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
                    ;;
            esac
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
    if   (( n >= 1099511627776 )); then
        i=$(( n / 1099511627776 ))
        f=$(( (n % 1099511627776) * 100 / 1099511627776 ))
        printf '%d.%02dT' "$i" "$f"
    elif (( n >= 1073741824 )); then
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

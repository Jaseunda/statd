#!/usr/bin/env bash
# colors.sh — terminal color variables and percentage colorizer
# Part of statd: https://github.com/Jaseunda/statd

if [ -t 1 ]; then
    C_RESET=$'\033[0m'
    C_DIM=$'\033[2m'
    C_BOLD=$'\033[1m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_RED=$'\033[31m'
    C_CYAN=$'\033[36m'
    C_BLUE=$'\033[34m'
    C_MAG=$'\033[35m'
    C_GREY=$'\033[90m'
else
    C_RESET=""
    C_DIM=""
    C_BOLD=""
    C_GREEN=""
    C_YELLOW=""
    C_RED=""
    C_CYAN=""
    C_BLUE=""
    C_MAG=""
    C_GREY=""
fi

# pct_color <integer-percent>
# Prints the ANSI escape for green/yellow/red based on load level.
pct_color() {
    local pct=${1:-0}
    if [[ ! "$pct" =~ ^[0-9]+$ ]]; then
        printf '%s' "$C_GREY"
        return
    fi
    if   (( pct < 60 )); then printf '%s' "$C_GREEN"
    elif (( pct < 85 )); then printf '%s' "$C_YELLOW"
    else                       printf '%s' "$C_RED"
    fi
}

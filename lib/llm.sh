#!/usr/bin/env bash
# llm.sh — llama.cpp process and metrics monitoring helpers
# Part of statd: https://github.com/Jaseunda/statd

# get_llama_metrics
# Fetches the Prometheus /metrics endpoint from a running llama-server.
# Returns the raw text body, or nothing on failure.
get_llama_metrics() {
    command -v curl >/dev/null 2>&1 || return 1
    curl -s --max-time 0.5 "http://127.0.0.1:${LLM_PORT}/metrics" 2>/dev/null
}

# llama_pid_alive <pid>
# Returns 0 if the given PID is still a llama process, 1 otherwise.
llama_pid_alive() {
    local pid=$1
    [ -z "$pid" ] && return 1
    if [ "$OS_TYPE" = "linux" ]; then
        [ -d "/proc/$pid" ] || return 1
        local comm prog
        if [ -r "/proc/$pid/comm" ]; then
            { read -r comm < "/proc/$pid/comm"; } 2>/dev/null
            case "$comm" in
                llama-server*|llama-cli*|llama-run*|llama-bench*|llama-simple*) return 0 ;;
            esac
        fi
        if [ -r "/proc/$pid/cmdline" ]; then
            { read -r -d '' prog < "/proc/$pid/cmdline"; } 2>/dev/null
            prog="${prog##*/}"
            case "$prog" in
                llama-server*|llama-cli*|llama-run*|llama-bench*|llama-simple*) return 0 ;;
            esac
        fi
        return 1
    else
        kill -0 "$pid" 2>/dev/null
    fi
}

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
        [ -r "/proc/$pid/cmdline" ] || return 1
        grep -aqE 'llama-(server|cli|run|bench)' "/proc/$pid/cmdline" 2>/dev/null
    else
        kill -0 "$pid" 2>/dev/null
    fi
}

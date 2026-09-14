#!/usr/bin/env bash
# install.sh — automated installer for statd
# https://github.com/Jaseunda/statd
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Jaseunda/statd/main/install.sh | bash
#   wget -qO- https://raw.githubusercontent.com/Jaseunda/statd/main/install.sh | bash
#
# Options (environment variables):
#   PREFIX    Installation prefix  (default: ~/.local if non-root, /usr/local if root)
#   BRANCH    Git branch to install (default: main)

set -euo pipefail

REPO="https://github.com/Jaseunda/statd"
BRANCH="${BRANCH:-main}"
ARCHIVE="${REPO}/archive/refs/heads/${BRANCH}.tar.gz"

# ---- Determine install prefix ----
if [ -z "${PREFIX:-}" ]; then
    if [ "$(id -u)" = "0" ]; then
        PREFIX="/usr/local"
    else
        PREFIX="$HOME/.local"
    fi
fi

BINDIR="$PREFIX/bin"
LIBDIR="$PREFIX/lib/statd"

# ---- Helpers ----
info()  { printf '  \033[32m+\033[0m  %s\n' "$*"; }
warn()  { printf '  \033[33m!\033[0m  %s\n' "$*"; }
error() { printf '  \033[31mx\033[0m  %s\n' "$*" >&2; exit 1; }
step()  { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ---- Check for required tools ----
step "Checking requirements"

for cmd in bash awk grep; do
    command -v "$cmd" >/dev/null 2>&1 || error "Required tool not found: $cmd"
    info "found $cmd"
done

# Prefer curl, fall back to wget
FETCH=""
if command -v curl >/dev/null 2>&1; then
    FETCH="curl"
    info "found curl"
elif command -v wget >/dev/null 2>&1; then
    FETCH="wget"
    info "found wget"
else
    error "Neither curl nor wget found. Install one and retry."
fi

# ---- Check Bash version ----
# curl | bash on macOS will invoke /bin/bash 3.2 (the system default),
# even if a newer Homebrew bash is installed.  We detect that case, re-exec
# with the newer bash when possible, and only warn (not abort) when none is
# found — the installer itself is 3.2-safe; the warning is for statd at
# runtime.
step "Checking Bash version"
BASH_MAJOR="${BASH_VERSINFO[0]:-0}"
BREW_BASH=""

if (( BASH_MAJOR < 4 )); then
    # Look for a Homebrew-managed bash 4+ before giving up.
    for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        if [ -x "$_b" ] && (( $("$_b" -c 'echo ${BASH_VERSINFO[0]}' 2>/dev/null) >= 4 )); then
            BREW_BASH="$_b"
            break
        fi
    done

    if [ -n "$BREW_BASH" ]; then
        # Re-exec the entire installer under the newer bash.
        # Works for both  curl | bash  and  bash install.sh  invocations.
        info "Re-running installer under $BREW_BASH"
        exec "$BREW_BASH" -s -- "$@" < "$0"
    fi

    # No bash 4+ found anywhere — install the files but warn the user.
    warn "Running under Bash $BASH_VERSION (macOS system shell)."
    warn "statd itself requires Bash 4.0+. Install it, then run statd:"
    warn "  brew install bash"
    BASH_OK=0
else
    info "Bash $BASH_VERSION OK"
    BASH_OK=1
fi

# ---- Download ----
step "Downloading statd ($BRANCH)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

ARCHIVE_FILE="$TMPDIR/statd.tar.gz"
EXTRACT_DIR="$TMPDIR/src"

if [ "$FETCH" = "curl" ]; then
    curl -fsSL "$ARCHIVE" -o "$ARCHIVE_FILE"
else
    wget -qO "$ARCHIVE_FILE" "$ARCHIVE"
fi
info "Downloaded archive"

mkdir -p "$EXTRACT_DIR"
tar -xzf "$ARCHIVE_FILE" -C "$EXTRACT_DIR" --strip-components=1
info "Extracted"

# ---- Syntax check ----
step "Verifying files"
for f in "$EXTRACT_DIR/statd" \
          "$EXTRACT_DIR/lib/colors.sh" \
          "$EXTRACT_DIR/lib/render.sh" \
          "$EXTRACT_DIR/lib/sensors_linux.sh" \
          "$EXTRACT_DIR/lib/sensors_macos.sh" \
          "$EXTRACT_DIR/lib/sensors.sh" \
          "$EXTRACT_DIR/lib/llm.sh"; do
    bash -n "$f" || error "Syntax error in $f — aborting."
    info "OK $(basename "$f")"
done

# ---- Install ----
step "Installing to $PREFIX"

mkdir -p "$BINDIR" "$LIBDIR"

install -m 755 "$EXTRACT_DIR/statd"          "$BINDIR/statd"
install -m 644 "$EXTRACT_DIR/lib/colors.sh"       "$LIBDIR/"
install -m 644 "$EXTRACT_DIR/lib/render.sh"        "$LIBDIR/"
install -m 644 "$EXTRACT_DIR/lib/sensors_linux.sh" "$LIBDIR/"
install -m 644 "$EXTRACT_DIR/lib/sensors_macos.sh" "$LIBDIR/"
install -m 644 "$EXTRACT_DIR/lib/sensors.sh"       "$LIBDIR/"
install -m 644 "$EXTRACT_DIR/lib/llm.sh"           "$LIBDIR/"

info "statd installed to $BINDIR/statd"
info "Libraries installed to $LIBDIR/"

# ---- PATH check ----
step "Checking PATH"
if ! echo ":$PATH:" | grep -q ":$BINDIR:"; then
    warn "$BINDIR is not in your PATH."
    warn "Add the following to your shell profile:"
    warn "  export PATH=\"$BINDIR:\$PATH\""
fi

# ---- Done ----
printf '\n\033[1mInstalled.\033[0m\n\n'
if [ "${BASH_OK:-1}" = "0" ]; then
    printf 'statd requires Bash 4.0+. Install it first:\n\n'
    printf '  brew install bash\n\n'
    printf 'Then run:\n\n'
    printf '  statd\n\n'
else
    printf 'Run:  statd\n\n'
fi

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
step "Checking Bash version"
BASH_MAJOR="${BASH_VERSINFO[0]:-0}"
if (( BASH_MAJOR < 4 )); then
    warn "Bash $BASH_VERSION detected — statd requires Bash 4.0 or later."
    if [ "$(uname -s)" = "Darwin" ]; then
        warn "Install a current Bash via Homebrew:  brew install bash"
        warn "Then re-run this installer."
    fi
    error "Bash 4.0+ required."
fi
info "Bash $BASH_VERSION OK"

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
printf '\n\033[1mDone.\033[0m Run: statd\n\n'

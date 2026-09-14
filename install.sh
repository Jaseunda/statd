#!/usr/bin/env bash
# install.sh — guided installer for statd
# https://github.com/Jaseunda/statd
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Jaseunda/statd/main/install.sh | bash
#   wget -qO- https://raw.githubusercontent.com/Jaseunda/statd/main/install.sh | bash
#   bash install.sh
#
# Environment overrides:
#   PREFIX=~/.local   Installation prefix (default: ~/.local or /usr/local if root)
#   BRANCH=main       Branch to install from

BRANCH="${BRANCH:-main}"
REPO_RAW="https://raw.githubusercontent.com/Jaseunda/statd/${BRANCH}"
INSTALLER_URL="${REPO_RAW}/install.sh"
ARCHIVE_URL="https://github.com/Jaseunda/statd/archive/refs/heads/${BRANCH}.tar.gz"

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

# ---- Terminal output helpers ----
_tty()  { printf '%s' "$*" > /dev/tty; }
_ttyn() { printf '%s\n' "$*" > /dev/tty; }

_header() {
    _ttyn ""
    _ttyn "  \033[1mstatd\033[0m — terminal system stats HUD"
    _ttyn "  https://github.com/Jaseunda/statd"
    _ttyn ""
}

step()  { _ttyn "\n\033[1m  $*\033[0m"; }
info()  { _ttyn "  \033[32m+\033[0m  $*"; }
warn()  { _ttyn "  \033[33m!\033[0m  $*"; }
error() { _ttyn "  \033[31mx\033[0m  $*"; exit 1; }

# Ask a yes/no question. Reads from /dev/tty so it works with curl | bash.
# Returns 0 for yes, 1 for no.
ask() {
    local prompt="$1" default="${2:-y}" response
    if [ "$default" = "y" ]; then
        printf '  \033[1m?\033[0m  %s [Y/n] ' "$prompt" > /dev/tty
    else
        printf '  \033[1m?\033[0m  %s [y/N] ' "$prompt" > /dev/tty
    fi
    read -r response < /dev/tty || response="$default"
    response="${response:-$default}"
    case "$response" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        *) return 1 ;;
    esac
}

# ---- Re-exec with a better bash ----
# When invoked via curl | bash, $0 is the bash binary itself, not a script
# file. We download install.sh to a tmpfile and re-exec from there.
_reexec_with() {
    local new_bash="$1"
    local script_file

    # Direct invocation (bash install.sh): $0 is a real path
    if [ -f "$0" ] && [ "$0" != "bash" ] && [ "$0" != "-bash" ] && [ "$0" != "-sh" ]; then
        script_file="$0"
    else
        # Piped invocation (curl | bash): download ourselves to a temp file
        script_file=$(mktemp "${TMPDIR:-/tmp}/statd_install_XXXXXX.sh")
        # shellcheck disable=SC2064
        trap "rm -f '$script_file'" EXIT

        info "Downloading installer to run under $new_bash ..."
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "$INSTALLER_URL" -o "$script_file" 2>/dev/null \
                || error "Failed to download installer. Try: bash <(curl -fsSL $INSTALLER_URL)"
        elif command -v wget >/dev/null 2>&1; then
            wget -qO "$script_file" "$INSTALLER_URL" 2>/dev/null \
                || error "Failed to download installer."
        else
            error "No curl or wget found."
        fi
    fi

    exec env PREFIX="$PREFIX" BRANCH="$BRANCH" "$new_bash" "$script_file"
}

# ---- Main ----

_header

# ============================================================
# Step 1 — Check for required tools
# ============================================================
step "Checking requirements"

FETCH=""
for cmd in bash awk grep; do
    command -v "$cmd" >/dev/null 2>&1 \
        && info "found $cmd" \
        || error "Required tool not found: $cmd"
done

if command -v curl >/dev/null 2>&1; then
    FETCH="curl"; info "found curl"
elif command -v wget >/dev/null 2>&1; then
    FETCH="wget"; info "found wget"
else
    error "curl or wget is required. Install one and retry."
fi

# ============================================================
# Step 2 — Bash version check with guided fix
# ============================================================
step "Checking Bash version"

BASH_MAJOR="${BASH_VERSINFO[0]:-0}"

if (( BASH_MAJOR >= 4 )); then
    info "Bash $BASH_VERSION — OK"
else
    warn "Running under Bash $BASH_VERSION (macOS system shell — too old for statd)"
    _ttyn ""

    # 2a. Look for an already-installed newer bash
    BREW_BASH=""
    for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        if [ -x "$_b" ]; then
            _bv=$("$_b" -c 'echo ${BASH_VERSINFO[0]}' 2>/dev/null)
            if (( _bv >= 4 )); then
                BREW_BASH="$_b"
                break
            fi
        fi
    done

    if [ -n "$BREW_BASH" ]; then
        _bver=$("$BREW_BASH" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        info "Found Bash $BVER at $BREW_BASH — re-running installer"
        _reexec_with "$BREW_BASH"
        # exec above never returns
    fi

    # 2b. No newer bash found — offer to install via Homebrew
    _ttyn ""
    if command -v brew >/dev/null 2>&1; then
        warn "Bash 4.0+ is required. Homebrew is available."
        if ask "Install Bash via Homebrew now?"; then
            _ttyn ""
            info "Running: brew install bash"
            brew install bash > /dev/tty 2>&1 || error "brew install bash failed."
            _ttyn ""

            # Find the newly installed bash
            for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
                if [ -x "$_b" ]; then
                    _bv=$("$_b" -c 'echo ${BASH_VERSINFO[0]}' 2>/dev/null)
                    if (( _bv >= 4 )); then
                        BREW_BASH="$_b"
                        break
                    fi
                fi
            done

            if [ -n "$BREW_BASH" ]; then
                info "Bash installed at $BREW_BASH — re-running installer"
                _reexec_with "$BREW_BASH"
            else
                error "Could not locate new bash after install. Try: $BREW_BASH install.sh"
            fi
        else
            _ttyn ""
            warn "Skipped. You can install manually:"
            warn "  brew install bash"
            warn "Then re-run:  curl -fsSL $INSTALLER_URL | bash"
            _ttyn ""
            exit 0
        fi
    else
        # No brew either — show manual options
        _ttyn ""
        warn "Bash 4.0+ is required and Homebrew was not found."
        _ttyn ""
        _ttyn "  Options:"
        _ttyn ""
        _ttyn "  1. Install Homebrew, then Bash:"
        _ttyn "       /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        _ttyn "       brew install bash"
        _ttyn ""
        _ttyn "  2. Run statd without installing (requires bash 4+):"
        _ttyn "       git clone https://github.com/Jaseunda/statd.git && cd statd && ./statd"
        _ttyn ""
        exit 1
    fi
fi

# ============================================================
# Step 3 — Download
# ============================================================
step "Downloading statd (branch: $BRANCH)"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

ARCHIVE_FILE="$WORK_DIR/statd.tar.gz"
EXTRACT_DIR="$WORK_DIR/src"

if [ "$FETCH" = "curl" ]; then
    curl -fsSL "$ARCHIVE_URL" -o "$ARCHIVE_FILE" \
        || error "Download failed. Check your internet connection."
else
    wget -qO "$ARCHIVE_FILE" "$ARCHIVE_URL" \
        || error "Download failed. Check your internet connection."
fi
info "Downloaded"

mkdir -p "$EXTRACT_DIR"
tar -xzf "$ARCHIVE_FILE" -C "$EXTRACT_DIR" --strip-components=1 \
    || error "Failed to extract archive."
info "Extracted"

# ============================================================
# Step 4 — Verify
# ============================================================
step "Verifying files"

for f in \
    "$EXTRACT_DIR/statd" \
    "$EXTRACT_DIR/lib/colors.sh" \
    "$EXTRACT_DIR/lib/render.sh" \
    "$EXTRACT_DIR/lib/sensors_linux.sh" \
    "$EXTRACT_DIR/lib/sensors_macos.sh" \
    "$EXTRACT_DIR/lib/sensors.sh" \
    "$EXTRACT_DIR/lib/llm.sh"
do
    bash -n "$f" || error "Syntax error in $(basename "$f") — aborting."
    info "OK  $(basename "$f")"
done

# ============================================================
# Step 5 — Install
# ============================================================
step "Installing to $PREFIX"

mkdir -p "$BINDIR" "$LIBDIR" \
    || error "Cannot create $BINDIR or $LIBDIR. Try: PREFIX=~/.local bash install.sh"

install -m 755 "$EXTRACT_DIR/statd"                    "$BINDIR/statd"
install -m 644 "$EXTRACT_DIR/lib/colors.sh"            "$LIBDIR/"
install -m 644 "$EXTRACT_DIR/lib/render.sh"            "$LIBDIR/"
install -m 644 "$EXTRACT_DIR/lib/sensors_linux.sh"     "$LIBDIR/"
install -m 644 "$EXTRACT_DIR/lib/sensors_macos.sh"     "$LIBDIR/"
install -m 644 "$EXTRACT_DIR/lib/sensors.sh"           "$LIBDIR/"
install -m 644 "$EXTRACT_DIR/lib/llm.sh"               "$LIBDIR/"

info "Binary  → $BINDIR/statd"
info "Library → $LIBDIR/"

# ============================================================
# Step 6 — PATH
# ============================================================
step "Checking PATH"

IN_PATH=0
if echo ":$PATH:" | grep -q ":$BINDIR:"; then
    info "$BINDIR is in your PATH"
    IN_PATH=1
else
    warn "$BINDIR is not in your PATH"
fi

# ============================================================
# Done
# ============================================================
_ttyn ""
_ttyn "  \033[1;32mInstalled.\033[0m"
_ttyn ""

if [ "$IN_PATH" = "0" ]; then
    SHELL_NAME="${SHELL##*/}"
    case "$SHELL_NAME" in
        zsh)   PROFILE="~/.zshrc" ;;
        fish)  PROFILE="~/.config/fish/config.fish" ;;
        *)     PROFILE="~/.bashrc" ;;
    esac
    _ttyn "  Add statd to your PATH — paste this into your terminal:"
    _ttyn ""
    _ttyn "    echo 'export PATH=\"$BINDIR:\$PATH\"' >> $PROFILE"
    _ttyn "    source $PROFILE"
    _ttyn ""
fi

_ttyn "  Run statd:"
_ttyn ""
_ttyn "    statd"
_ttyn ""
_ttyn "  Keys:  c = toggle per-core panel   q = quit"
_ttyn ""

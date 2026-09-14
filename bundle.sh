#!/usr/bin/env bash
# bundle.sh — bundle statd and all libraries into a single standalone file
# Produces: dist/statd
# Useful for minimal Linux containers, microVMs, and light setups with zero install.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
OUTPUT="$DIST_DIR/statd"

mkdir -p "$DIST_DIR"

LIB_FILES=(
    "$SCRIPT_DIR/lib/colors.sh"
    "$SCRIPT_DIR/lib/render.sh"
    "$SCRIPT_DIR/lib/sensors_linux.sh"
    "$SCRIPT_DIR/lib/sensors_macos.sh"
    "$SCRIPT_DIR/lib/sensors.sh"
    "$SCRIPT_DIR/lib/llm.sh"
)

# Verify all parts exist and pass syntax check
bash -n "$SCRIPT_DIR/statd"
for f in "${LIB_FILES[@]}"; do
    bash -n "$f"
done

TMP_BUNDLE="$(mktemp "${TMPDIR:-/tmp}/statd_bundle_XXXXXX.sh")"
trap 'rm -f "$TMP_BUNDLE"' EXIT

# Combine statd with inlined libraries
awk -v lib1="${LIB_FILES[0]}" \
    -v lib2="${LIB_FILES[1]}" \
    -v lib3="${LIB_FILES[2]}" \
    -v lib4="${LIB_FILES[3]}" \
    -v lib5="${LIB_FILES[4]}" \
    -v lib6="${LIB_FILES[5]}" '
    /# BEGIN LIB LOADER/ {
        in_loader = 1
        print "# --- Standalone Inlined Libraries ---"
        while ((getline line < lib1) > 0) { if (line !~ /^#!\/usr\/bin\/env bash/) print line } close(lib1)
        while ((getline line < lib2) > 0) { if (line !~ /^#!\/usr\/bin\/env bash/) print line } close(lib2)
        while ((getline line < lib3) > 0) { if (line !~ /^#!\/usr\/bin\/env bash/) print line } close(lib3)
        while ((getline line < lib4) > 0) { if (line !~ /^#!\/usr\/bin\/env bash/) print line } close(lib4)
        while ((getline line < lib5) > 0) { if (line !~ /^#!\/usr\/bin\/env bash/) print line } close(lib5)
        while ((getline line < lib6) > 0) { if (line !~ /^#!\/usr\/bin\/env bash/) print line } close(lib6)
        print "# --- End of Inlined Libraries ---"
        next
    }
    /# END LIB LOADER/ {
        in_loader = 0
        next
    }
    !in_loader { print }
' "$SCRIPT_DIR/statd" > "$TMP_BUNDLE"

bash -n "$TMP_BUNDLE"
mv "$TMP_BUNDLE" "$OUTPUT"
chmod +x "$OUTPUT"

printf 'Bundled standalone script -> %s (%d bytes)\n' "$OUTPUT" "$(wc -c < "$OUTPUT" | tr -d ' ')"

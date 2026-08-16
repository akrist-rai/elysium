#!/usr/bin/env bash
# Copies the fonts the game renders with into assets/fonts/.
# DejaVu ships with essentially every desktop Linux and is Bitstream Vera
# licensed, so vendoring it here is fine.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/assets/fonts"
mkdir -p "$DEST"

copy_font() {
    local want="$1" dest="$2"
    if [ -f "$DEST/$dest" ]; then
        return
    fi
    for dir in /usr/share/fonts/truetype/dejavu /usr/share/fonts/TTF /usr/share/fonts; do
        local found
        found="$(find "$dir" -name "$want" -type f 2>/dev/null | head -1 || true)"
        if [ -n "$found" ]; then
            cp "$found" "$DEST/$dest"
            echo "font: $dest <- $found"
            return
        fi
    done
    echo "font: WARNING could not find $want (falling back to raylib's builtin)" >&2
}

copy_font DejaVuSerif.ttf          body.ttf
copy_font DejaVuSerif-Bold.ttf     title.ttf
copy_font DejaVuSerifCondensed.ttf body-condensed.ttf
copy_font DejaVuSansMono.ttf       mono.ttf

echo "assets ready in $DEST"

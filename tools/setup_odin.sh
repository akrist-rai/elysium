#!/usr/bin/env bash
# Installs the Odin compiler and the clang shim it needs to link on Linux.
# Idempotent: safe to re-run.
set -euo pipefail

ODIN_VERSION="${ODIN_VERSION:-dev-2026-08}"
ODIN_HOME="${ODIN_HOME:-$HOME/.local/odin}"
BIN_DIR="$HOME/.local/bin"
TARBALL="odin-linux-amd64-${ODIN_VERSION}.tar.gz"
URL="https://github.com/odin-lang/Odin/releases/download/${ODIN_VERSION}/${TARBALL}"

mkdir -p "$BIN_DIR"

# --- Odin ------------------------------------------------------------------
if [ -x "$ODIN_HOME/odin" ]; then
    echo "odin: already installed at $ODIN_HOME"
else
    echo "odin: fetching $ODIN_VERSION"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    curl -fL --progress-bar -o "$tmp/$TARBALL" "$URL"

    mkdir -p "$ODIN_HOME"
    # The release tarball wraps everything in a single top-level directory.
    tar -xzf "$tmp/$TARBALL" -C "$tmp"
    inner="$(find "$tmp" -maxdepth 2 -name odin -type f -printf '%h\n' | head -1)"
    if [ -z "$inner" ]; then
        echo "odin: could not locate the compiler inside $TARBALL" >&2
        exit 1
    fi
    cp -r "$inner"/. "$ODIN_HOME"/
    chmod +x "$ODIN_HOME/odin"
    echo "odin: installed to $ODIN_HOME"
fi

ln -sfn "$ODIN_HOME/odin" "$BIN_DIR/odin"

# --- clang shim ------------------------------------------------------------
# Odin shells out to `clang` to link. Ubuntu 25.10 ships versioned binaries
# only, so point a bare `clang` at whichever version is present.
if command -v clang >/dev/null 2>&1; then
    echo "clang: found $(command -v clang)"
else
    real_clang="$(ls -1 /usr/bin/clang-[0-9]* 2>/dev/null | sort -V | tail -1 || true)"
    if [ -z "$real_clang" ]; then
        echo "clang: none found. Install one with: sudo apt install clang" >&2
        exit 1
    fi
    ln -sfn "$real_clang" "$BIN_DIR/clang"
    echo "clang: shimmed $BIN_DIR/clang -> $real_clang"
fi

# --- raylib sanity ---------------------------------------------------------
# No system raylib needed: Odin vendors prebuilt binaries.
if ls "$ODIN_HOME"/vendor/raylib/linux/libraylib.* >/dev/null 2>&1; then
    echo "raylib: vendored binaries present"
else
    echo "raylib: WARNING - $ODIN_HOME/vendor/raylib/linux is missing" >&2
fi

# --- PATH ------------------------------------------------------------------
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        echo
        echo "Add this to your shell profile, then restart the shell:"
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
        ;;
esac

echo
echo "Setup complete. Version:"
PATH="$BIN_DIR:$PATH" "$ODIN_HOME/odin" version

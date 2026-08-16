#!/usr/bin/env bash
# Debug build and run. Pass --test to run the headless logic and content checks.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.local/bin:$PATH"

if ! command -v odin >/dev/null 2>&1; then
    echo "odin not found - run ./tools/setup_odin.sh first" >&2
    exit 1
fi

"$ROOT/tools/prepare_assets.sh" >/dev/null

# Odin vendors raylib but does not always bake the rpath in; make sure the
# loader can find it either way.
ODIN_ROOT="${ODIN_ROOT:-$HOME/.local/odin}"
export LD_LIBRARY_PATH="$ODIN_ROOT/vendor/raylib/linux:${LD_LIBRARY_PATH:-}"

mkdir -p "$ROOT/build"
odin build "$ROOT/src" -out:"$ROOT/build/hacktheplot" -debug
exec "$ROOT/build/hacktheplot" "$@"

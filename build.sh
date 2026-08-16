#!/usr/bin/env bash
# Optimised build. Use ./run.sh for the debug build with hot reload.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$HOME/.local/bin:$PATH"

if ! command -v odin >/dev/null 2>&1; then
    echo "odin not found - run ./tools/setup_odin.sh first" >&2
    exit 1
fi

"$ROOT/tools/prepare_assets.sh" >/dev/null

mkdir -p "$ROOT/build"
odin build "$ROOT/src" -out:"$ROOT/build/hacktheplot" -o:speed "$@"
echo "built $ROOT/build/hacktheplot"

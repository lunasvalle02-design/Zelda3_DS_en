#!/usr/bin/env bash
# Generates zelda3_assets.dat from your US ROM (never included or distributed).
# Usage: scripts/extract-assets.sh [path/to/zelda3.sfc]   (defaults to rom/zelda3.sfc)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROM="${1:-$ROOT/rom/zelda3.sfc}"
UP="$ROOT/external/zelda3-upstream"
EXPECTED_SHA256=66871d66be19ad2c34c927d6b14cd8eb6fc3181965b6e517cb361f7316009cfb

[ -f "$ROM" ] || { echo "ROM not found at $ROM (copy it as rom/zelda3.sfc)." >&2; exit 1; }
[ -d "$UP/assets" ] || { echo "Sources are missing: run 'make fetch'." >&2; exit 1; }

sha=$(sha256sum "$ROM" | cut -d' ' -f1)
if [ "$sha" != "$EXPECTED_SHA256" ]; then
  echo "Warning: the ROM SHA-256 ($sha) does not match the expected US version." >&2
  echo "         restool.py may fail or generate incorrect assets." >&2
fi

ROM="$(cd "$(dirname "$ROM")" && pwd)/$(basename "$ROM")"
python3 "$UP/assets/restool.py" --extract-from-rom -r "$ROM"
mkdir -p "$ROOT/build"
mv "$UP/zelda3_assets.dat" "$ROOT/build/zelda3_assets.dat"
echo ">> OK: build/zelda3_assets.dat"

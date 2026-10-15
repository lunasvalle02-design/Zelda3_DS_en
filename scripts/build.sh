#!/usr/bin/env bash
# Compiles zelda3 for aarch64 (runs inside the container, or on a host with the toolchain).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
. "$ROOT/config/versions.env"

SRC="$ROOT/external/zelda3-ds/$ZELDA3_DS_SUBDIR"
OUT="$ROOT/build"
[ -f "$SRC/Makefile" ] || { echo "Sources are missing: run 'make fetch'." >&2; exit 1; }

CC="${CC:-${TARGET_TRIPLE}-gcc}"
STRIP="${STRIP:-${TARGET_TRIPLE}-strip}"
CFLAGS="${CFLAGS:-$TARGET_CFLAGS}"
JOBS="${JOBS:-$(nproc)}"

echo ">> CC=$CC  CFLAGS=$CFLAGS  SDL2 $(sdl2-config --version)"
# Binary only: the assets are generated separately (scripts/extract-assets.sh) because they need the ROM.
# CFLAGS is passed through the environment, not as a make argument, so that the zelda3 Makefile
# can append "-I ." and the sdl2-config flags (a make argument would override them).
CC="$CC" CFLAGS="$CFLAGS" make -C "$SRC" -j"$JOBS" zelda3

mkdir -p "$OUT"
cp "$SRC/zelda3" "$OUT/zelda3.aarch64"
"$STRIP" "$OUT/zelda3.aarch64" 2>/dev/null || true
file "$OUT/zelda3.aarch64" 2>/dev/null || true
echo ">> OK: build/zelda3.aarch64"

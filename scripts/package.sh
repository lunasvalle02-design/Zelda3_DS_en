#!/usr/bin/env bash
# Assembles dist/ports/ (ready to copy to /storage/roms/ports/) and dist/zelda3.zip (PortMaster format).
# zelda3_assets.dat is NOT added to the zip (it is derived from the ROM): it is only copied to dist/
# when it exists in build/.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/build/zelda3.aarch64"
DIST="$ROOT/dist"
PORTS="$DIST/ports"
[ -f "$BIN" ] || { echo "$BIN is missing: run 'make build'." >&2; exit 1; }

rm -rf "$DIST"
mkdir -p "$PORTS/zelda3"
install -m 755 "$ROOT/port/Zelda3.sh" "$PORTS/Zelda3.sh"
install -m 755 "$BIN" "$PORTS/zelda3/zelda3.aarch64"
install -m 644 "$ROOT/port/zelda3/zelda3.ini" "$PORTS/zelda3/zelda3.ini"
install -m 644 "$ROOT/port/port.json" "$PORTS/zelda3/port.json"
install -m 644 "$ROOT/port/gameinfo.xml" "$PORTS/zelda3/gameinfo.xml"
for img in cover.png screenshot.png; do
  if [ -f "$ROOT/port/zelda3/$img" ]; then install -m 644 "$ROOT/port/zelda3/$img" "$PORTS/zelda3/$img"; fi
done
LICENSE_SRC="$ROOT/external/zelda3-ds/app/jni/src/LICENSE.txt"
if [ -f "$LICENSE_SRC" ]; then install -m 644 "$LICENSE_SRC" "$PORTS/zelda3/LICENSE.txt"; fi

( cd "$PORTS" && zip -qr "$DIST/zelda3.zip" Zelda3.sh zelda3 )

if [ -f "$ROOT/build/zelda3_assets.dat" ]; then
  install -m 644 "$ROOT/build/zelda3_assets.dat" "$PORTS/zelda3/zelda3_assets.dat"
  echo ">> Included zelda3_assets.dat in dist/ports (not in the zip)."
fi
echo ">> OK: dist/ports/ and dist/zelda3.zip"

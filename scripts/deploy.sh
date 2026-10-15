#!/usr/bin/env bash
# Copies dist/ports/ to the device over SSH (enable SSH in ROCKNIX: Network Settings > Enable SSH).
# Usage: DEVICE_IP=192.168.1.50 [DEVICE_PASS=...] scripts/deploy.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${DEVICE_IP:?Set DEVICE_IP to the device IP address}"
DEVICE_USER="${DEVICE_USER:-root}"
PORTS_DIR="${PORTS_DIR:-/storage/roms/ports}"
[ -d "$ROOT/dist/ports" ] || { echo "Run 'make package' first." >&2; exit 1; }

SSH_OPTS=(-o StrictHostKeyChecking=accept-new)
run() { if [ -n "${DEVICE_PASS:-}" ]; then sshpass -p "$DEVICE_PASS" "$@"; else "$@"; fi; }

run scp "${SSH_OPTS[@]}" -r "$ROOT/dist/ports/." "$DEVICE_USER@$DEVICE_IP:$PORTS_DIR/"
run ssh "${SSH_OPTS[@]}" "$DEVICE_USER@$DEVICE_IP" "chmod +x '$PORTS_DIR/Zelda3.sh' '$PORTS_DIR/zelda3/zelda3.aarch64'"
echo ">> Deployed to $DEVICE_IP:$PORTS_DIR (refresh the game list in EmulationStation)."

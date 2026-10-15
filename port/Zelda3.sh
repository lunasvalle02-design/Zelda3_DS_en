#!/bin/bash
# Zelda3 DS — launcher for ROCKNIX (Anbernic RG DS / RG DS Plus).
# Lives in /storage/roms/ports/ next to the zelda3/ folder.
#
# Top screen: the game. Bottom screen: map, touch inventory and settings.
# ROCKNIX (sway) moves to the second screen, and powers on, any window whose title
# contains "Bottom", "Secondary", "Screen 2"... (see 111-sway-init), hence the fixed title.

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

# PortMaster is optional: if installed, use its control.txt (SDL controller mapping).
for d in /opt/system/Tools/PortMaster /opt/tools/PortMaster "$XDG_DATA_HOME/PortMaster" /storage/roms/ports/PortMaster /roms/ports/PortMaster; do
  [ -f "$d/control.txt" ] && { controlfolder="$d"; break; }
done
if [ -n "$controlfolder" ]; then
  # shellcheck disable=SC1091
  source "$controlfolder/control.txt"
  [ -f "$controlfolder/mod_${CFW_NAME}.txt" ] && source "$controlfolder/mod_${CFW_NAME}.txt"
  get_controls
  export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"
fi

GAMEDIR="$(cd "$(dirname "$0")" && pwd)/zelda3"
cd "$GAMEDIR" || exit 1
exec > "$GAMEDIR/log.txt" 2>&1
echo "Zelda3 DS — $(date)"

if [ ! -f zelda3_assets.dat ]; then
  echo "ERROR: zelda3_assets.dat is missing from $GAMEDIR"
  echo "Generate it on your PC with 'make assets' (requires your US ROM) and copy it here."
  exit 1
fi

mkdir -p saves

# Second screen (second_screen_sdl.c from zelda3-android, dual-screen branch)
export ZELDA3_SECOND_SCREEN=1
export ZELDA3_SECOND_SCREEN_TITLE="Zelda3 Bottom Screen"
# Wayland app_id, for sway rules
export SDL_VIDEO_WAYLAND_WMCLASS=zelda3

# Touch diagnostics: logs every bottom-screen touch to log.txt and draws a magenta
# cross where SDL receives it. Touch input verified on 2026-10-15.
# export ZELDA3_TOUCH_DEBUG=1

# Performance metrics every ~5 s in log.txt (fps, emulation ms, PPU, presentation
# and bottom screen). Measured on 2026-10-15: locked 60 fps, ~8.5 ms per frame.
# export ZELDA3_PERF_LOG=1

# Bottom screen renderer: GPU by default when the game uses OutputMethod = SDL.
# Uncomment to force software rendering (to compare performance or if the bottom screen fails).
# export ZELDA3_SECOND_SCREEN_RENDERER=software

# Uncomment for debugging
# export SDL_LOGGING=all

./zelda3.aarch64
rc=$?
echo "zelda3 exited with code $rc"

[ -n "$controlfolder" ] && unset SDL_GAMECONTROLLERCONFIG
exit $rc

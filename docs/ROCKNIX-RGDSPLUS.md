# Technical Notes: ROCKNIX on the Anbernic RG DS Plus

> Information gathered on 2026-10-15 from the official `ROCKNIX/distribution` repository (`next`
> branch), RocknixDS (JorreFog), zelda3-android (`dual-screen` branch) and snesrev/zelda3.

## Contents

- [Hardware](#hardware)
- [How ROCKNIX handles dual screens (sway)](#how-rocknix-handles-dual-screens-sway)
- [Ports on ROCKNIX](#ports-on-rocknix)
- [Why not use the ROCKNIX build system](#why-not-use-the-rocknix-build-system)
- [Code base](#code-base)
- [Port changes (`patches/`)](#port-changes-patches)
- [Measured performance](#measured-performance)
- [CPU governor](#cpu-governor)
- [World map objective stages](#world-map-objective-stages)
- [Pending on-device verification](#pending-on-device-verification)

## Hardware

| | RG DS Plus |
|:--|:--|
| **SoC** | Rockchip **RK3568**, 4× Cortex-A55 → `-march=armv8.2-a -mtune=cortex-a55` |
| **GPU** | Mali-G52 2EE (Panfrost/Mesa or libmali, depending on the ROCKNIX configuration) |
| **RAM** | 1 GB |
| **Displays** | 2× 4.3" **1024×768** (4:3), Goodix touch panel on the bottom screen |
| **ROCKNIX** | Officially supported under the **RK3566** build device (`rk3568-anbernic-rg-ds-plus.dts`, quirks in `packages/hardware/quirks/devices/Anbernic RG DS Plus/`) |

> [!NOTE]
> The original RG DS (640×480 per panel) shares almost all of the integration, so the port should
> work on both as long as no resolutions are hard-coded.

## How ROCKNIX handles dual screens (sway)

Source: `projects/ROCKNIX/packages/wayland/compositor/sway/autostart/111-sway-init`

- `080-dual_screen_mode` sets `DEVICE_HAS_DUAL_SCREEN=true` when `modetest` reports two connectors.
- It exports `SDL_VIDEO_DISPLAY_PRIORITY=<primary>,<secondary>`.
- **Key rule:** any window whose title contains
  `Secondary|[w2]|Sub|Bottom|Screen 2|GamePad` is moved to the secondary output. On the RG DS and
  RG DS Plus that output is also powered on (`output … power on`). When EmulationStation regains
  focus, the secondary output is turned off again.
- Touch: `1046:911:Goodix_Capacitive_TouchScreen` (EmulationStation binds it to `seat1`).

As a result, the port **does not need to touch sway at all**: zelda3-android's
`second_screen_sdl.c` opens its window with the title `Zelda3 Bottom Screen` (configurable through
`ZELDA3_SECOND_SCREEN_TITLE`), which already matches the rule.

## Ports on ROCKNIX

- Ports are `.sh` scripts in `/storage/roms/ports/` (the `ports` platform in EmulationStation).
- ROCKNIX bundles PortMaster (`packages/apps/portmaster`, `mod_ROCKNIX.txt`); its `control.txt`
  provides `SDL_GAMECONTROLLERCONFIG`. zelda3 uses the SDL2 GameController API, so `gptokeyb` is not
  needed.
- ROCKNIX does not package games that depend on a commercial ROM. This port is therefore distributed
  as a PortMaster-style port rather than as a `package.mk` inside the distribution.

> [!NOTE]
> Should upstream integration ever be desired, the `rocknix.org/contribute/packages` guide and the
> repository's `AGENTS.md` state that it would belong in `projects/ROCKNIX/packages/...`.

## Why not use the ROCKNIX build system

`make docker-RK3566` builds the complete OS image: roughly **200 GB of disk and ~10 hours** for the
first run. A user-space binary only needs an aarch64 toolchain with a glibc equal to or older than
ROCKNIX's, plus SDL2 2.26.x — exactly what PortMaster recommends in its build-environment guide.
That is what [`docker/Dockerfile`](../docker/Dockerfile) provides (Debian bookworm +
`crossbuild-essential-arm64` + `libsdl2-dev:arm64`).

PortMaster's official alternative, the QEMU-emulated `portmaster-builder:aarch64-latest` container,
works as well but is considerably slower.

## Code base

| Repository | Usage |
|:--|:--|
| `samyost1/zelda3-android`, branch `dual-screen`, subfolder `app/jni/src` | snesrev/zelda3 plus `second_screen.c` (state reading and graphics generation from the assets) and `platform/linux/second_screen_sdl.c` (SDL UI: map, dungeon, touch inventory and settings). MIT licensed. |
| `snesrev/zelda3` | Only `assets/restool.py` is used. The `kAssets_Sig` signature has been verified to be identical in both repositories, so the generated `zelda3_assets.dat` is compatible. |

## Port changes (`patches/`)

### `0001` — Exit combo

<kbd>L1</kbd> + <kbd>Start</kbd> + <kbd>Select</kbd> sends `SDL_QUIT`. SRAM is saved and, when
enabled, so is the autosave state.

### `0002` — Engine

- **Top screen aspect modes:** `TopScreenAspect` = `original`, `stretch`, `wide` or `pixel`.
  *wide* uses zelda3's extra PPU columns: 21 px per side at 224 lines, so 298×224 fills 4:3 with
  square pixels.
- **`WorldMap_GetObjectiveMarkers()`** mirrors `WorldMap_HandleSprites`. It uses
  `savegame_map_icons_indicator` (SRAM `$3C7`, stages 0–8), the `kOwMapCrystal*` tables and the
  pendants and crystals already collected.

### `0003` — Bottom screen

- Complete settings menu.
- Integer-scaled pixel art: the map goes from ×2.77 to ×3 and text from ×3.2 to ×3.
- The tab bar accepts touches across the entire bottom strip.
- Displays, window and touches are logged to `log.txt`.

### `0004` — Larger HUD elements

Hearts at ×3, a taller magic meter and floor plates with ×3 text; 256u side column.

### `0005` — Performance

- With `OutputMethod = SDL` the bottom screen uses an accelerated (GPU) SDL renderer without vsync
  instead of software rendering. With OpenGL or OpenGL ES it falls back to software, because the
  game owns its own GL context. Override with `ZELDA3_SECOND_SCREEN_RENDERER=software|accelerated`.
- `ZELDA3_PERF_LOG=1` writes a `perf:` line to `log.txt` every ~5 s: fps, emulation ms, PPU,
  presentation (including the vsync wait), bottom screen, worst frame and frames over 20 ms.
- `log.txt` reports which SDL renderer each screen is using.

### `0006` — Suspend integration

`src/platform/linux/rocknix_sleep.c` loads `libdbus-1` through `dlopen`, just like SDL2 does, so the
binary has no hard dependency on it.

1. Takes a logind *delay* inhibitor (`Inhibit("sleep", …, "delay")`) and listens for `PrepareForSleep`.
2. On `true`: pauses audio, saves state to slot 0 if *Autosave* is enabled and releases the
   inhibitor; logind then proceeds and `sleep.sh` freezes `games.slice`.
3. On `false` (resume): resumes audio, resets the frame clock and takes the inhibitor again.
4. Without D-Bus or logind it disables itself.

Tested against a mock logind on a private bus: the lock is released about 40 ms after the
notification and taken again on resume.

### `0007` — Languages

- `src/i18n.c` lists the languages compiled into `zelda3_assets.dat` (`kDialogueMap`) and loads
  the interface texts of the selected one from `lang/<code>.ini`. `I18n_SetLanguage` can run
  between frames: `messaging.c` keeps the encoding and font each message was decoded with, so a
  box already on screen is not garbled.
- Translations use the EU text encoding (127 character codes), so a language can add up to 28
  glyphs (codes 99–126) to the US font. `tools/lang/build_assets.py` draws them from the US
  letters of the ROM, wraps the dialogue to the 168 px text box and validates it.
- Pause menu: item names, "DO" ability words and box headers are rebuilt from the HUD letter
  tiles (A–Z). The small graphic labels `ITEM`, `DO` and `-LIFE-` stay as they are.
- File select: `nmi.c` and `select_file.c` pass their stripe lists through
  `I18n_TranslateStripes`, which rewrites rows drawn with the 8×16 font by matching their English
  text.
- Bottom screen: all texts go through `I18n_Get`; `draw_text` decodes UTF-8 and draws accented
  capitals with their diacritic.
- Not translated: the title logo, the staff credits of the ending and other text that exists
  only as graphics.

See [`lang/README.md`](../lang/README.md) for the translation format.

## Measured performance

*2026-10-15 · RG DS Plus · `OutputMethod = SDL` · GPU-rendered bottom screen*

Locked **60 fps** over roughly 7 minutes of play.

| Stage | Time per frame |
|:--|--:|
| Emulation | ~0.1 ms |
| PPU | ~3.5 ms |
| Presentation (incl. vsync wait) | ~3.0 ms |
| Bottom screen | ~1.7 ms |
| **Total** | **~8.5 ms** of 16.7 ms |

Only two isolated 85 ms spikes were observed (startup and one transition). The default governor is
sufficient; *performance* is not required.

## CPU governor

ROCKNIX applies the governor configured in EmulationStation to ports (`runemu.sh` reads
`cpugovernor` per system or per game), so the port does not force one. It can be changed in
EmulationStation through the game's advanced options under *Ports*.

## World map objective stages

Verified with a test linked against the engine:

| `$3C7` | Markers |
|:-:|:--|
| 0 | X on Hyrule Castle |
| 1 | X on Kakariko Village |
| 2 | X on Sahasrahla's house |
| 3 | Pendants at the Eastern Palace, Tower of Hera and Desert Palace (hidden once collected) + Master Sword |
| 4 | Master Sword (Lost Woods) |
| 5 | Agahnim's Tower |
| 6 | Palace of Darkness (Dark World) |
| 7 | Any of the 7 crystals still missing |
| 8 | Ganon's Tower |

## Pending on-device verification

- [x] **Touch** — verified on 2026-10-15. The bottom window is 1024×768 and touches land where tapped.
- [x] **Performance** — measured, see [above](#measured-performance).
- [ ] **Real suspend on the device** — `log.txt` should contain `suspend: logind integration on`,
  `suspend: going to sleep` and `suspend: resumed`.

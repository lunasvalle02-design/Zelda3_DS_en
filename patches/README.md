# Patches on top of zelda3-android (`dual-screen` branch)

All changes this port makes to upstream live here as `git format-patch` files.
[`scripts/fetch-sources.sh`](../scripts/fetch-sources.sh) applies them in order on top of
`external/zelda3-ds`. This follows the same approach as ROCKNIX itself: **pinned upstream source +
patches**.

| Patch | Summary |
|:--|:--|
| `0001` | Exit with <kbd>L1</kbd> + <kbd>Start</kbd> + <kbd>Select</kbd> |
| `0002` | Top screen aspect modes and in-game map objective markers |
| `0003` | Bottom screen with full settings, integer scaling, in-game markers and touch diagnostics |
| `0004` | Larger hearts, magic meter and dungeon floor plates |
| `0005` | GPU-rendered bottom screen with `OutputMethod = SDL` and performance logging |
| `0006` | ROCKNIX suspend integration (logind `PrepareForSleep` + delay inhibitor) |
| `0007` | Multi-language support with runtime language selection (`src/i18n.c`) |

See [`docs/ROCKNIX-RGDSPLUS.md`](../docs/ROCKNIX-RGDSPLUS.md#port-changes-patches) for details.

## Workflow

```bash
make -f zelda3ds.mk fetch          # clean external/zelda3-ds with all patches applied
cd external/zelda3-ds
# ...edit, build with `make -f zelda3ds.mk build`, test on the device...
git commit -am "rgds: short description of the change"
git format-patch -o ../../patches <base-commit>..HEAD   # base = ZELDA3_DS_COMMIT
```

## Conventions

- Name patches `NNNN-topic.patch` so they apply in a fixed order.
- Prefix commit subjects with `rgds:`.
- If the patch set grows substantially, consider moving to a dedicated fork and pointing
  `ZELDA3_DS_REPO` at it in [`config/versions.env`](../config/versions.env).

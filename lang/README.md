# Translations

Zelda3 DS can carry any number of languages. Each one is a folder here:

```text
lang/<code>/
├── language.ini   language code, display name and the extra font glyphs
├── dialogue.txt   the 397 game messages
└── strings.ini    pause menu, file select screens and bottom-screen interface
```

| Code | Language | Status |
|:--|:--|:--|
| `us` | English | Original game (built in, no folder) |
| `es` | Español | Complete: dialogue, pause menu, file select, bottom screen |

## How it works

Nothing copyrighted is stored here: the US font and script are extracted from
your ROM when the assets are built.

1. `scripts/extract-assets.sh` runs `restool.py --extract-from-rom`, then
   [`tools/lang/build_assets.py`](../tools/lang/build_assets.py).
2. For every `lang/<code>/` the builder:
   - draws the extra glyphs listed in `language.ini` (á, ñ, ¿…) on top of the
     US font of your ROM and saves `font_<code>.png`,
   - lays out and checks `dialogue.txt` (line width, characters, commands),
   - compiles it into `zelda3_assets.dat` next to the English text.
3. `scripts/package.sh` installs `strings.ini` as `zelda3/lang/<code>.ini`.
4. In the game, *Settings → LANGUAGE* on the bottom screen cycles through the
   languages in the asset file and saves `Language = <code>` in `zelda3.ini`.
   The switch is immediate; a message box already on screen finishes in the
   previous language.

Build only some languages with `LANGUAGES=es scripts/extract-assets.sh`.

## Adding a language

1. Copy `lang/es/` to `lang/<code>/` (`<code>`: lower case, e.g. `fr`, `pt-br`).
2. Edit `language.ini`: `code`, `name` and the glyphs your language needs.
   Glyphs are generated from a US letter plus an operation:
   `acute`, `grave`, `circumflex`, `tilde`, `diaeresis`, `cedilla`,
   `flip` (upside down) or `rotate` (180°). Up to 28 extra glyphs.
3. Translate `dialogue.txt` and `strings.ini`.
4. Check your work without building the whole asset file:

   ```bash
   python3 tools/lang/build_assets.py --assets external/zelda3-upstream/assets \
       --rom rom/zelda3.sfc --languages <code> --check --dump-layout /tmp/layout
   ```

   `/tmp/layout/dialogue_<code>.txt` shows every message exactly as the game
   will display it.

## `dialogue.txt`

One message per line, `<number>: <text>`, numbered like the `dialogue.txt` that
restool extracts from the US ROM (open it next to your translation). Missing
messages fall back to English.

**Automatic layout (recommended).** Write the message as plain text. The
builder wraps it to the 168-pixel text box, fills the three lines and then
waits for a key every three new lines, like the original script:

```text
23: Busca al anciano de la aldea y consigue la Espada Maestra.
```

| Tag | Effect |
|:--|:--|
| `[Waitkey]` | End the line and wait for a key (use it between sentences or paragraphs). |
| `[/]` | End the line. If the next line starts with spaces it is kept as written. |
| `[Name]` | Player name (budgeted as 36 px). |

Choices keep the original indentation so the cursor lines up:

```text
45: …¿Entiendes la leyenda?[/]    > Sí[/]       No del todo[Choose]
```

**Manual layout.** A message that contains `[2]`, `[3]` or `[Scroll]` is used
as written. Use it for signs, menus, the intro (`275`–`278`) and the ending
(`372`), where timing and positions matter.

Every other command (`[Speed xx]`, `[Window 02]`, `[Sound 45]`, `[Choose]`,
`[Item]`, `[Number xx]`, `[Wait xx]`, `[NextPic]`…) must appear exactly as in
the original message; the builder reports any difference. Button and symbol
glyphs (`[A]`, `[B]`, `[X]`, `[Y]`, `[Up]`, `[LinkL]`, `[...]`…) can be used
freely.

## `strings.ini`

| Section | Used for | Characters |
|:--|:--|:--|
| `[language]` | `name` shown in the settings | |
| `[ui]` | Bottom screen: tabs, settings, remap panel, floor labels (`floor = P%d`) | Upper case A–Z, digits, space, `.` `,` `-`, accented capitals |
| `[dungeons]` | Dungeon names on the bottom-screen map | same as `[ui]` |
| `[hud]` | Pause menu item names (`TOP\|BOTTOM`, 8 letters per row), box headers (8 letters), ability words (5 letters, 4 for `lift`) | A–Z (accents are dropped) |
| `[fileselect]` | File select screens: `<English text> = <translation>` | US font, accents dropped; no longer than the English row |

Any missing key keeps its English text. Run the game with
`ZELDA3_I18N_DEBUG=1` to print every file select text and whether it was
translated.

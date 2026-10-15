#!/usr/bin/env python3
"""Builds zelda3_assets.dat with every language found in lang/.

Run after `restool.py --extract-from-rom --no-build` (scripts/extract-assets.sh
does both). For each lang/<code>/:
  1. generates font_<code>.png: the US font from your ROM + the extra glyphs
     listed in language.ini,
  2. lays out and validates lang/<code>/dialogue.txt (line widths, characters,
     commands) and writes dialogue_<code>.txt next to restool.py,
  3. registers the language in restool's tables and compiles the asset file.

Usage:
  build_assets.py --assets external/zelda3-upstream/assets --rom rom/zelda3.sfc
                  [--lang-dir lang] [--languages es,fr] [--check] [--strict]
                  [--dump-layout out_dir]

--check only validates (no asset file); --dump-layout writes the final
wrapped text of each language for review.
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import zlang  # noqa: E402


def main():
  ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
  ap.add_argument('--assets', required=True, help='snesrev/zelda3 assets/ folder (restool.py)')
  ap.add_argument('--rom', required=True, help='US ROM')
  ap.add_argument('--lang-dir', default=os.path.join(HERE, '..', '..', 'lang'))
  ap.add_argument('--languages', help='comma separated codes (default: all in --lang-dir)')
  ap.add_argument('--check', action='store_true', help='validate only, do not build')
  ap.add_argument('--strict', action='store_true', help='fail on any warning')
  ap.add_argument('--dump-layout', metavar='DIR', help='write the laid-out dialogue of each language')
  args = ap.parse_args()

  lang_dir = os.path.abspath(args.lang_dir)
  rom = os.path.abspath(args.rom)
  dump_dir = os.path.abspath(args.dump_layout) if args.dump_layout else None
  wanted = set(args.languages.split(',')) if args.languages else None
  langs = zlang.find_languages(lang_dir, wanted)
  if wanted and {l.code for l in langs} != wanted:
    sys.exit(f'Languages not found in {lang_dir}: {sorted(wanted - {l.code for l in langs})}')

  assets = os.path.abspath(args.assets)
  os.chdir(assets)
  sys.path.insert(0, assets)
  for f in ('font.png', 'dialogue.txt'):
    if not os.path.exists(f):
      sys.exit(f'{assets}/{f} is missing: run restool.py --extract-from-rom first.')

  import util
  util.load_rom(rom)
  import text_compression
  import sprite_sheets

  us = text_compression.kLanguages['us']
  us_msgs = zlang.read_dialogue('dialogue.txt')
  errors = 0
  codes = []
  for lang in langs:
    font_png = 'font_%s.png' % lang.code.replace('-', '_')
    alphabet, widths = zlang.build_font('font.png', font_png, lang, us.alphabet)
    alphabet_set = set(alphabet)

    msgs = zlang.read_dialogue(lang.dialogue_path)
    missing = sorted(set(us_msgs) - set(msgs))
    extra = sorted(set(msgs) - set(us_msgs))
    if extra:
      print(f'[{lang.code}] unknown message numbers: {extra}')
      errors += 1
    if missing:
      print(f'[{lang.code}] {len(missing)} messages not translated (English is used): {missing[:20]}'
            + (' ...' if len(missing) > 20 else ''))
      if args.strict:
        errors += 1

    final = []
    lang_errors = 0
    for n in sorted(us_msgs):
      text = msgs.get(n)
      if text is None:
        final.append(us_msgs[n])
        continue
      if not zlang.is_manual(text):
        text = zlang.wrap(text, widths)
      for p in zlang.check_message(n, text, us_msgs[n], widths, alphabet_set):
        print(f'[{lang.code}] message {n}: {p}')
        print(f'    {text}')
        lang_errors += 1
      final.append(text)
    errors += lang_errors
    if dump_dir:
      os.makedirs(dump_dir, exist_ok=True)
      with open(os.path.join(dump_dir, f'dialogue_{lang.code}.txt'), 'w', encoding='utf-8') as f:
        for i, t in enumerate(final, 1):
          f.write(f'{i}: {t}\n')
    print(f'[{lang.code}] {lang.name}: {len(msgs)}/{len(us_msgs)} messages, '
          f'{len(lang.glyphs)} extra glyphs, {lang_errors} problems')

    # Register the language in restool's tables.
    class Lang(text_compression.LangUS):
      pass
    Lang.alphabet = alphabet
    Lang.dictionary = []
    Lang.encoder = 'new'   # EU command encoding: 127 character codes
    text_compression.kLanguages[lang.code] = Lang()
    sprite_sheets.kFontTypes[lang.code] = (0, 256, font_png, (0, len(alphabet)))
    with open(text_compression.dialogue_filename(lang.code), 'w', encoding='utf-8') as f:
      for i, t in enumerate(final, 1):
        f.write(f'{i}: {t}\n')
    codes.append(lang.code)

  if errors:
    sys.exit(f'{errors} problem(s) found.')
  if args.check:
    return

  import compile_resources

  class Args:
    sprites_from_png = False
    languages = ','.join(codes) if codes else None
    print_assets_header = False
  compile_resources.main(Args())
  print('Languages in zelda3_assets.dat: us' + ''.join(',' + c for c in codes))


if __name__ == '__main__':
  main()

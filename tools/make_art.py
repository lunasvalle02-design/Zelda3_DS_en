#!/usr/bin/env python3
"""Generates the port's screenshots and cover art from a photo of the device.

ROCKNIX has no convenient way to capture both panels, so the starting point is a
photo: the perspective of each screen is corrected and its real pixel grid is rebuilt
(256x224 for the game, 3 px cells for the bottom UI), producing crisp screenshots
instead of a distorted photo.

Usage:    python3 tools/make_art.py docs/screenshots/source/rgds-plus-photo.jpg
Requires: opencv-python, numpy, Pillow.

The coordinates below belong to that specific photo. For a different photo they must
be measured again (top panel corners and 4 points of the bottom UI).
"""
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOTS = os.path.join(ROOT, "docs", "screenshots")
PORT = os.path.join(ROOT, "port", "zelda3")

# Top panel: TL, TR, BR, BL corners in the photo (ORIGINAL mode, with side bars).
TOP_QUAD = [[239, 287], [686, 281], [674, 624], [225, 616]]
# Bottom panel: the bezel hides part of the panel in an angled photo, so it is fitted
# using 4 UI points whose exact position is known from the code: the map corner, the
# bottom-left corner of GEAR, the bottom-right corner of the cog and the top-right
# corner of the rupee box (200u column of v1).
BOTTOM_PHOTO_PTS = [[221, 750], [180, 1082], [660, 1114], [670, 763]]

W, H = 1024, 768
U = H / 720.0


def bottom_ui_pts():
    tab_h = 84 * U
    y_bottom = H - tab_h + 4 * U + (tab_h - 16 * U)
    return [[10 * U, 10 * U], [8 * U, y_bottom], [W - 8 * U, y_bottom],
            [W - 200 * U + 4 * U + (200 * U - 14 * U), 10 * U]]


def levels(img, lo, hi, gamma, sat):
    out = np.empty_like(img)
    for c in range(3):
        a, b = np.percentile(img[..., c], [lo, hi])
        out[..., c] = np.clip((img[..., c] - a) / max(b - a, 1e-3), 0, 1)
    out = (out ** gamma * 255).astype(np.uint8)
    hsv = cv2.cvtColor(out, cv2.COLOR_BGR2HSV).astype(np.float32)
    hsv[..., 1] = np.clip(hsv[..., 1] * sat, 0, 255)
    return cv2.cvtColor(hsv.astype(np.uint8), cv2.COLOR_HSV2BGR)


def warp(photo, M, w, h):
    return cv2.warpPerspective(photo, M, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)


def top_native(photo):
    """The SNES picture (256x224) from the top panel."""
    src = np.float32(TOP_QUAD)
    dst = np.float32([[0, 0], [2 * W, 0], [2 * W, 2 * H], [0, 2 * H]])
    big = warp(photo, cv2.getPerspectiveTransform(src, dst), 2 * W, 2 * H)
    bar = round((W - H * 8 / 7) / 2 / W * 2 * W)   # black side bars of ORIGINAL mode
    game = big[:, bar:2 * W - bar]
    return levels(cv2.resize(game, (256, 224), interpolation=cv2.INTER_AREA), 1, 99.5, 0.9, 1.25)


def bottom_cells(photo):
    """The bottom UI in 3 px cells (341x256)."""
    M = cv2.getPerspectiveTransform(np.float32(BOTTOM_PHOTO_PTS), np.float32(bottom_ui_pts()))
    big = warp(photo, np.diag([2, 2, 1]) @ M, 2 * W, 2 * H)
    return levels(cv2.resize(big, (341, 256), interpolation=cv2.INTER_AREA), 0.5, 99.7, 0.95, 1.2)


def to_pil(bgr):
    return Image.fromarray(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB))


def top_panel(native):
    """1024x768 top panel exactly as ORIGINAL mode displays it."""
    game = to_pil(native).resize((round(H * 8 / 7), H), Image.NEAREST)
    panel = Image.new("RGB", (W, H), (0, 0, 0))
    panel.paste(game, ((W - game.width) // 2, 0))
    return panel


def bottom_panel(cells):
    img = to_pil(cells).resize((1023, H), Image.NEAREST)
    panel = Image.new("RGB", (W, H))
    panel.paste(img, (0, 0))
    panel.paste(img.crop((1022, 0, 1023, H)), (1023, 0))
    return panel


def dual(top, bottom, gap=24, gap_col=(22, 22, 26)):
    out = Image.new("RGB", (W, 2 * H + gap), gap_col)
    out.paste(top, (0, 0))
    out.paste(bottom, (0, H + gap))
    return out


def font(name, size):
    for path in (f"/usr/share/fonts/opentype/inter/{name}.otf",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def rounded(draw, box, r, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)


def cover(top, bottom, size=(600, 900)):
    """Original cover art: a generic dual-screen handheld showing the screenshots."""
    cw, ch = size
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(ch):   # green night-time gradient
        t = y / ch
        c = (int(14 + 18 * t), int(28 + 30 * t), int(22 + 16 * t))
        for x in range(cw):
            px[x, y] = c
    rain = Image.new("RGBA", size, (0, 0, 0, 0))
    rd = ImageDraw.Draw(rain)
    rng = np.random.default_rng(3)
    for _ in range(140):   # rain, as in the game's opening scene
        x, y = rng.integers(-60, cw), rng.integers(-40, ch)
        ln = rng.integers(14, 34)
        rd.line([(x, y), (x + ln * 0.35, y + ln)], fill=(150, 200, 230, 46), width=2)
    img = Image.alpha_composite(img.convert("RGBA"), rain)
    d = ImageDraw.Draw(img)

    # title
    title, sub = "ZELDA3 DS", "A Link to the Past · dual screen"
    ft, fs = font("Inter-ExtraBold", 74), font("Inter-SemiBold", 24)
    tw = d.textlength(title, font=ft)
    for dx, dy in ((0, 5), (3, 5), (-3, 5)):
        d.text(((cw - tw) / 2 + dx, 40 + dy), title, font=ft, fill=(40, 24, 8, 255))
    d.text(((cw - tw) / 2, 40), title, font=ft, fill=(236, 196, 98, 255),
           stroke_width=2, stroke_fill=(92, 60, 18, 255))
    sw = d.textlength(sub, font=fs)
    d.text(((cw - sw) / 2, 128), sub, font=fs, fill=(236, 228, 208, 255))

    # generic handheld (does not imitate any commercial model)
    scr_w, scr_h = 352, 264
    shell_w, pad = scr_w + 56, 26
    sx = (cw - shell_w) // 2
    y_top = 182
    shell = (233, 214, 207, 255)
    edge = (178, 152, 146, 255)
    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.rounded_rectangle((sx - 10, y_top - 6, sx + shell_w + 10, y_top + 2 * (scr_h + 2 * pad) + 34),
                         radius=40, fill=(0, 0, 0, 140))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(14)))
    d = ImageDraw.Draw(img)
    top_shell = (sx, y_top, sx + shell_w, y_top + scr_h + 2 * pad)
    hinge_y = top_shell[3] + 4
    bot_shell = (sx, hinge_y + 22, sx + shell_w, hinge_y + 22 + scr_h + 2 * pad)
    for box in (top_shell, bot_shell):
        rounded(d, box, 26, shell, edge, 2)
    rounded(d, (sx + 18, hinge_y - 2, sx + shell_w - 18, hinge_y + 24), 12, (214, 192, 185, 255), edge, 2)
    for box, shot in ((top_shell, top), (bot_shell, bottom)):
        x0, y0 = box[0] + 28, box[1] + pad
        rounded(d, (x0 - 8, y0 - 8, x0 + scr_w + 8, y0 + scr_h + 8), 8, (205, 182, 176, 255))
        img.paste(shot.resize((scr_w, scr_h), Image.LANCZOS), (x0, y0))
        d = ImageDraw.Draw(img)
        d.rectangle((x0 - 1, y0 - 1, x0 + scr_w, y0 + scr_h), outline=(60, 50, 50, 255), width=1)

    foot = "Native port for ROCKNIX · RG DS Plus"
    ff = font("Inter-Medium", 20)
    fw = d.textlength(foot, font=ff)
    d.text(((cw - fw) / 2, ch - 42), foot, font=ff, fill=(200, 214, 196, 255))
    return img.convert("RGB")


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    photo = cv2.imread(sys.argv[1]).astype(np.float32)
    os.makedirs(SHOTS, exist_ok=True)
    top = top_panel(top_native(photo))
    bottom = bottom_panel(bottom_cells(photo))
    both = dual(top, bottom)
    top.save(os.path.join(SHOTS, "top-screen.png"))
    bottom.save(os.path.join(SHOTS, "bottom-screen.png"))
    both.save(os.path.join(SHOTS, "dual-screen.png"))
    # ES / PortMaster: screenshot with both screens and a portrait cover
    both.resize((480, 744), Image.LANCZOS).save(os.path.join(PORT, "screenshot.png"))
    cov = cover(top, bottom)
    cov.save(os.path.join(PORT, "cover.png"))
    cov.save(os.path.join(SHOTS, "cover.png"))
    print("OK:", ", ".join(["docs/screenshots/*.png", "port/zelda3/cover.png", "port/zelda3/screenshot.png"]))


if __name__ == "__main__":
    main()

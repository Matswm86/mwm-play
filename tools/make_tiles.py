#!/usr/bin/env python3
"""Launcher tile art (DESIGN 2a): 440x318, radius 32, cut from each game's own
1080x1920 capture-bot screenshots. Usage: tools/make_tiles.py <slug> <png> <left> <top> <width>"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw

W, H, R, SS = 440, 318, 32, 4
slug, src, left, top, width = sys.argv[1], sys.argv[2], *map(int, sys.argv[3:6])
height = round(width * H / W)
art = Image.open(src).convert("RGB").crop((left, top, left + width, top + height))
art = art.resize((W, H), Image.LANCZOS).convert("RGBA")
mask = Image.new("L", (W * SS, H * SS), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, W * SS - 1, H * SS - 1), R * SS, fill=255)
art.putalpha(mask.resize((W, H), Image.LANCZOS))
out = Path(__file__).resolve().parent.parent / "app/shell/tiles" / f"{slug}.png"
art.save(out)
print(f"{out} from {src} box {left},{top},{width}x{height}")

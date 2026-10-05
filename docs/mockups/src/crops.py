"""Tile art for the launcher, cropped from each game's own screenshots (our own art)."""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
P = ROOT.parent  # the game repos sit next to mwm-play
OUT = ROOT / "docs/mockups/src/tiles"
OUT.mkdir(parents=True, exist_ok=True)
W, H = 468, 340  # tile art box in px at 1080x1920
CROPS = {  # slug: (file, (left, top, right, bottom)) in source px
    "ball-connect": ("ball-connect/screenshots/level_1_3d.jpeg", (20, 120, 520, 484)),
    "water-sort": ("water-sort/screenshots/pouring.jpeg", (20, 260, 520, 624)),
    "tile-explorer": ("tile-explorer/screenshots/3d-level5.png", (20, 270, 520, 634)),
    "spotless": ("spotless/screenshots/03.jpg", (20, 330, 520, 694)),
    "timber-valley": ("timber-valley/screenshots/01_start.jpg", (20, 175, 520, 539)),
}


def make():
    for slug, (f, box) in CROPS.items():
        im = Image.open(P / f).convert("RGB").crop(box).resize((W * 2, H * 2), Image.LANCZOS)
        im.save(OUT / f"{slug}.png")


if __name__ == "__main__":
    make()
    sheet = Image.new("RGB", (W * 5 + 40, H), "white")
    for i, s in enumerate(CROPS):
        sheet.paste(Image.open(OUT / f"{s}.png").resize((W, H)), (i * (W + 10), 0))
    sheet.save(OUT.parent.parent.parent.parent / "docs/mockups/src/tiles_preview.png")

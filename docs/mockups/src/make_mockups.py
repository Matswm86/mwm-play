"""MWM Play shell mockups at 1080x1920. Drawn at 2x and downsampled.

Run: python3 make_mockups.py   (needs Pillow; run crops.py first)
Outputs go to docs/mockups/*.png. Sizes in this file are in 1080x1920 design px.
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "docs/mockups"
TILES = OUT / "src/tiles"
FONTS = ROOT / "assets/fonts"
P = ROOT.parent  # the game repos sit next to mwm-play
S = 2  # supersample
W, H = 1080, 1920

# palette tokens (see docs/DESIGN.md section 1)
PAPER = "#fbf8f2"
CARD = "#ffffff"
INK = "#24211d"
INK_SOFT = "#5c5449"
LINE = "#e6dfd2"
EDGE = "#8f8371"
GREEN = "#1f7a5a"
GREEN_SOFT = "#e3f0ea"
PLUM = "#5b3f8c"
DUSK = "#2e2b4f"
MOON = "#c9c3e6"
HILL_1 = "#e4ecd8"
HILL_2 = "#d5e3c6"
SAND = "#f1e7d6"
BANDS = {
    "ball-connect": "#e6ddf3",
    "water-sort": "#d3e8f5",
    "tile-explorer": "#f0dcc4",
    "spotless": "#cdeeed",
    "timber-valley": "#d8eccb",
}
NAMES = {
    "ball-connect": "Ball Connect",
    "water-sort": "Water Sort",
    "tile-explorer": "Tile Explorer",
    "spotless": "Spotless",
    "timber-valley": "Timber Valley",
}


def f_andika(px, bold=False):
    return ImageFont.truetype(
        str(FONTS / ("Andika-Bold.ttf" if bold else "Andika-Regular.ttf")), px * S
    )


def f_fredoka(px, weight=b"SemiBold"):
    f = ImageFont.truetype(str(FONTS / "Fredoka.ttf"), px * S)
    f.set_variation_by_name(weight)
    return f


def s(v):
    return [int(round(x * S)) for x in v] if isinstance(v, (list, tuple)) else int(round(v * S))


def canvas(bg=PAPER):
    im = Image.new("RGB", (W * S, H * S), bg)
    return im, ImageDraw.Draw(im)


def rr(d, box, r, fill=None, outline=None, width=0):
    d.rounded_rectangle(
        s(box), radius=s(r), fill=fill, outline=outline, width=s(width) if width else 0
    )


def shadow(im, box, r, off=8, blur=18, alpha=40):
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(
        s((box[0], box[1] + off, box[2], box[3] + off)), radius=s(r), fill=(60, 45, 30, alpha)
    )
    layer = layer.filter(ImageFilter.GaussianBlur(s(blur)))
    im.paste(layer, (0, 0), layer)


def text_c(d, cx, cy, t, font, fill):
    d.text((s(cx), s(cy)), t, font=font, fill=fill, anchor="mm")


def text_l(d, x, y, t, font, fill, anchor="lm"):
    d.text((s(x), s(y)), t, font=font, fill=fill, anchor=anchor)


def wrap(d, x, y, t, font, fill, max_w, lh):
    words, line, yy = t.split(), "", y
    for w_ in words:
        test = (line + " " + w_).strip()
        if d.textlength(test, font=font) > s(max_w) and line:
            d.text((s(x), s(yy)), line, font=font, fill=fill, anchor="ls")
            yy += lh
            line = w_
        else:
            line = test
    d.text((s(x), s(yy)), line, font=font, fill=fill, anchor="ls")
    return yy


# ---------- icons ----------
def icon_house(d, cx, cy, size, color, door=CARD):
    h = size / 2
    d.polygon(s([cx - h, cy - 0.02 * size, cx, cy - h, cx + h, cy - 0.02 * size]), fill=color)
    rr(d, (cx - 0.36 * size, cy - 0.12 * size, cx + 0.36 * size, cy + h), 0.06 * size, fill=color)
    rr(d, (cx - 0.1 * size, cy + 0.14 * size, cx + 0.1 * size, cy + h), 0.04 * size, fill=door)


def icon_gear(d, cx, cy, size, color, hole):
    r_out, r_in, teeth = size * 0.5, size * 0.36, 8
    pts = []
    for i in range(teeth * 2):
        a0 = math.pi * 2 * i / (teeth * 2)
        r = r_out if i % 2 == 0 else r_in
        for da in (-0.17, 0.17):
            pts += [cx + r * math.cos(a0 + da), cy + r * math.sin(a0 + da)]
    d.polygon(s(pts), fill=color)
    d.ellipse(
        s((cx - r_in * 0.95, cy - r_in * 0.95, cx + r_in * 0.95, cy + r_in * 0.95)), fill=color
    )
    d.ellipse(
        s((cx - size * 0.15, cy - size * 0.15, cx + size * 0.15, cy + size * 0.15)), fill=hole
    )


def icon_backspace(d, cx, cy, size, color):
    w2, h2 = size * 0.5, size * 0.34
    pts = [
        cx - w2,
        cy,
        cx - w2 + h2,
        cy - h2,
        cx + w2,
        cy - h2,
        cx + w2,
        cy + h2,
        cx - w2 + h2,
        cy + h2,
    ]
    d.polygon(s(pts), outline=color, width=s(6))
    k = size * 0.14
    ox = cx + size * 0.1
    d.line(s((ox - k, cy - k, ox + k, cy + k)), fill=color, width=s(7))
    d.line(s((ox - k, cy + k, ox + k, cy - k)), fill=color, width=s(7))


def icon_chevron(d, cx, cy, size, color):
    d.line(
        s(
            (
                cx - size * 0.2,
                cy - size * 0.4,
                cx + size * 0.2,
                cy,
                cx - size * 0.2,
                cy + size * 0.4,
            )
        ),
        fill=color,
        width=s(6),
        joint="curve",
    )


def icon_check(d, cx, cy, size, color, w=14):
    d.line(
        s(
            (
                cx - size * 0.38,
                cy,
                cx - size * 0.1,
                cy + size * 0.3,
                cx + size * 0.4,
                cy - size * 0.3,
            )
        ),
        fill=color,
        width=s(w),
        joint="curve",
    )


def home_button(im, d, ring=0.0):
    """Shell home button, top-left. Visual disc r=68 at (104,104); hit area (0,0)-(216,216)."""
    cx, cy, r = 104, 104, 68
    if ring > 0:  # guard state: pops to 1.2x, ring fills over 2 s
        r = 82
        d.ellipse(
            s((cx - r - 22, cy - r - 22, cx + r + 22, cy + r + 22)),
            fill=CARD,
            outline=INK,
            width=s(3),
        )
        d.arc(
            s((cx - r - 10, cy - r - 10, cx + r + 10, cy + r + 10)),
            -90,
            -90 + 360 * ring,
            fill=GREEN,
            width=s(12),
        )
    sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse(s((cx - r, cy - r + 6, cx + r, cy + r + 6)), fill=(0, 0, 0, 70))
    sh = sh.filter(ImageFilter.GaussianBlur(s(8)))
    im.paste(sh, (0, 0), sh)
    d.ellipse(s((cx - r, cy - r, cx + r, cy + r)), fill=CARD, outline=INK, width=s(5))
    icon_house(d, cx, cy + 2, r * 1.0, INK)


def hills(d, top=1660):
    d.ellipse(s((-260, top + 40, 700, top + 560)), fill=HILL_1)
    d.ellipse(s((420, top + 10, 1400, top + 600)), fill=HILL_2)
    d.ellipse(s((120, top + 150, 980, top + 700)), fill=SAND)


def finish(im, name):
    out = im.resize((W, H), Image.LANCZOS)
    out.save(OUT / name)
    return out


def hit_overlay(img, boxes, name):
    """Second copy with hit areas drawn as dashed-look translucent boxes, for the builder."""
    ov = img.convert("RGBA")
    layer = Image.new("RGBA", ov.size, (0, 0, 0, 0))
    dl = ImageDraw.Draw(layer)
    for b, col in boxes:
        dl.rectangle(b, fill=col + (55,), outline=col + (230,), width=3)
    Image.alpha_composite(ov, layer).convert("RGB").save(OUT / name)


# ---------- 1. start screen ----------
TILE_W, TILE_H = 468, 440
TILE_POS = {
    "ball-connect": (48, 232),
    "water-sort": (564, 232),
    "tile-explorer": (48, 720),
    "spotless": (564, 720),
    "timber-valley": (306, 1208),
}


def start_screen():
    im, d = canvas()
    hills(d)
    text_l(d, 56, 104, "MWM Play", f_fredoka(56), GREEN)
    # adult entry: top-right, quiet, 104 px disc, hit area 150x150 to the corner
    cx, cy = 1080 - 88, 96
    d.ellipse(s((cx - 52, cy - 52, cx + 52, cy + 52)), fill=PAPER, outline=EDGE, width=s(4))
    icon_gear(d, cx, cy, 46, INK_SOFT, PAPER)
    text_c(d, cx, cy + 82, "Voksne", f_andika(30), INK_SOFT)
    for slug, (x, y) in TILE_POS.items():
        box = (x, y, x + TILE_W, y + TILE_H)
        shadow(im, box, 44)
        rr(d, box, 44, fill=BANDS[slug], outline=EDGE, width=3)
        art = Image.open(TILES / f"{slug}.png").convert("RGB")
        aw, ah = TILE_W - 28, 318
        art = ImageOps.fit(art, s((aw, ah)), Image.LANCZOS)
        mask = Image.new("L", art.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, art.size[0] - 1, art.size[1] - 1), radius=s(32), fill=255
        )
        im.paste(art, s((x + 14, y + 14)), mask)
        text_c(d, x + TILE_W / 2, y + 14 + ah + 52, NAMES[slug], f_andika(50, bold=True), INK)
    img = finish(im, "start_screen.png")
    boxes = [
        ((x - 8, y - 8, x + TILE_W + 8, y + TILE_H + 8), (31, 122, 90))
        for x, y in TILE_POS.values()
    ]
    boxes.append(((1080 - 160, 0, 1080, 160), (91, 63, 140)))
    boxes.append(((0, 1664, 1080, 1920), (200, 60, 40)))
    hit_overlay(img, boxes, "start_screen_hitareas.png")


# ---------- 2. parent gate ----------
def parent_gate():
    im, d = canvas()
    home_button(im, d)
    # adult + child figure
    for fx, fy, sc, col in ((470, 300, 1.0, PLUM), (610, 340, 0.7, GREEN)):
        d.ellipse(s((fx - 34 * sc, fy - 120 * sc, fx + 34 * sc, fy - 52 * sc)), fill=col)
        rr(d, (fx - 56 * sc, fy - 40 * sc, fx + 56 * sc, fy + 90 * sc), 50 * sc, fill=col)
    text_c(d, 540, 500, "Hent en voksen", f_fredoka(76), INK)
    text_c(d, 540, 580, "Voksne: skriv tallene med sifre", f_andika(40), INK_SOFT)
    rr(d, (120, 630, 960, 780), 40, fill=CARD, outline=LINE, width=3)
    text_c(d, 540, 702, "sju  ·  fire  ·  to", f_andika(84, bold=True), INK)
    for i, val in enumerate(["7", "", ""]):
        x = 540 - 255 + i * 180
        rr(
            d,
            (x, 820, x + 150, 960),
            28,
            fill=CARD,
            outline=INK if val else EDGE,
            width=4 if val else 3,
        )
        if val:
            text_c(d, x + 75, 890, val, f_fredoka(72, b"Medium"), INK)
    kw, kh, gap, x0, y0 = 290, 150, 28, 77, 1010
    keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "<"]
    for i, k in enumerate(keys):
        if not k:
            continue
        x = x0 + (i % 3) * (kw + gap)
        y = y0 + (i // 3) * (kh + gap)
        rr(d, (x, y, x + kw, y + kh), 32, fill=CARD, outline=EDGE, width=3)
        if k == "<":
            icon_backspace(d, x + kw / 2, y + kh / 2, 84, INK)
        else:
            text_c(d, x + kw / 2, y + kh / 2, k, f_fredoka(64, b"Medium"), INK)
    finish(im, "parent_gate.png")


# ---------- 3. parent area ----------
def toggle(d, x, cy, on):
    """Toggle 128x72 at right edge x; state shown by knob side + På/Av word, not colour only."""
    tx = x - 128
    if on:
        rr(d, (tx, cy - 36, x, cy + 36), 36, fill=GREEN)
        d.ellipse(s((x - 66, cy - 30, x - 6, cy + 30)), fill=CARD)
        icon_check(d, x - 36, cy, 30, GREEN, w=6)
    else:
        rr(d, (tx, cy - 36, x, cy + 36), 36, fill=CARD, outline=EDGE, width=4)
        d.ellipse(s((tx + 8, cy - 28, tx + 64, cy + 28)), fill=EDGE)
    text_l(
        d,
        tx - 20,
        cy,
        "På" if on else "Av",
        f_andika(34, bold=True),
        GREEN if on else INK_SOFT,
        anchor="rm",
    )


def parent_area():
    im, d = canvas()
    home_button(im, d)
    text_l(d, 210, 104, "For voksne", f_fredoka(60), INK)
    L, R = 48, 1032
    # unlock card
    y = 224
    rr(d, (L, y, R, y + 500), 36, fill=CARD, outline=LINE, width=3)
    text_l(d, L + 44, y + 70, "Lås opp alle spillene", f_andika(46, bold=True), INK, anchor="ls")
    wrap(
        d,
        L + 44,
        y + 130,
        "Prøveversjonen har de første banene i hvert spill. Én betaling låser opp alle "
        "baner i alle spill, også spill som kommer senere. Ingen abonnement og ingen reklame.",
        f_andika(34),
        INK_SOFT,
        R - L - 88,
        48,
    )
    rr(d, (L + 44, y + 290, R - 44, y + 400), 56, fill=GREEN)
    text_c(d, 540, y + 345, "Lås opp for 79 kr", f_andika(44, bold=True), CARD)
    text_c(d, 540, y + 452, "Gjenopprett kjøp", f_andika(34, bold=True), GREEN)
    # sound + motion card
    y = 748
    rr(d, (L, y, R, y + 560), 36, fill=CARD, outline=LINE, width=3)
    text_l(d, L + 44, y + 70, "Lyd og bevegelse", f_andika(46, bold=True), INK, anchor="ls")
    rows = [
        ("Lydeffekter", None, True),
        ("Musikk", None, True),
        ("Vibrasjon", None, False),
        ("Mindre bevegelse", "Ingen risting, parallakse eller partikler", False),
    ]
    ry = y + 150
    for i, (lab, sub, on) in enumerate(rows):
        if sub:
            text_l(d, L + 44, ry - 20, lab, f_andika(38), INK)
            text_l(d, L + 44, ry + 26, sub, f_andika(30), INK_SOFT)
        else:
            text_l(d, L + 44, ry, lab, f_andika(38), INK)
        toggle(d, R - 44, ry, on)
        if i < len(rows) - 1:
            d.line(s((L + 44, ry + 55, R - 44, ry + 55)), fill=LINE, width=s(2))
        ry += 112
    # play limit card
    y = 1332
    rr(d, (L, y, R, y + 330), 36, fill=CARD, outline=LINE, width=3)
    text_l(d, L + 44, y + 70, "Grense for spilletid", f_andika(46, bold=True), INK, anchor="ls")
    segs = ["Av", "15 min", "30 min", "45 min", "60 min"]
    sw = (R - L - 88 - 4 * 12) / 5
    for i, sg in enumerate(segs):
        x = L + 44 + i * (sw + 12)
        sel = i == 2
        rr(
            d,
            (x, y + 110, x + sw, y + 220),
            28,
            fill=GREEN if sel else CARD,
            outline=GREEN if sel else EDGE,
            width=3,
        )
        text_c(d, x + sw / 2, y + 165, sg, f_andika(32, bold=True), CARD if sel else INK)
    wrap(
        d,
        L + 44,
        y + 280,
        "Spillet stopper ved neste naturlige pause. Ingen nedtelling.",
        f_andika(30),
        INK_SOFT,
        R - L - 88,
        42,
    )
    # play together card, cut by the screen edge = it scrolls
    y = 1686
    rr(d, (L, y, R, y + 600), 36, fill=CARD, outline=LINE, width=3)
    text_l(d, L + 44, y + 70, "Spill sammen", f_andika(46, bold=True), INK, anchor="ls")
    for i, slug in enumerate(["ball-connect", "water-sort"]):
        ry = y + 110 + i * 120
        art = ImageOps.fit(
            Image.open(TILES / f"{slug}.png").convert("RGB"), s((96, 96)), Image.LANCZOS
        )
        m = Image.new("L", art.size, 0)
        ImageDraw.Draw(m).rounded_rectangle(
            (0, 0, art.size[0] - 1, art.size[1] - 1), radius=s(20), fill=255
        )
        im.paste(art, s((L + 44, ry)), m)
        text_l(d, L + 170, ry + 30, NAMES[slug], f_andika(38), INK)
        text_l(d, L + 170, ry + 74, "Tips til å spille sammen", f_andika(30), INK_SOFT)
        icon_chevron(d, R - 70, ry + 48, 50, INK_SOFT)
    # scroll fade at the bottom edge
    fade = Image.new("RGBA", (W * S, s(120)), (0, 0, 0, 0))
    for yy in range(fade.size[1]):
        a = int(230 * yy / fade.size[1])
        ImageDraw.Draw(fade).line((0, yy, W * S, yy), fill=(251, 248, 242, a))
    im.paste(fade, (0, (H - 120) * S), fade)
    finish(im, "parent_area.png")


# ---------- 4. in-game home guard (over a real Timber Valley capture) ----------
def ingame_home():
    shot = (
        Image.open(P / "timber-valley/screenshots/01_start.jpg")
        .convert("RGB")
        .resize((W * S, H * S), Image.LANCZOS)
    )
    d = ImageDraw.Draw(shot)
    home_button(shot, d, ring=0.55)
    img = finish(shot, "ingame_home_guard.png")
    hit_overlay(img, [((0, 0, 216, 216), (31, 122, 90))], "ingame_home_hitarea.png")


# ---------- 5. done-for-now ----------
def done_screen():
    im, d = canvas(DUSK)
    d.ellipse(s((380, 300, 700, 620)), fill=MOON)
    d.ellipse(s((470, 260, 790, 580)), fill=DUSK)  # crescent
    for sx, sy, r in ((250, 420, 8), (820, 330, 10), (300, 700, 6), (860, 640, 7), (180, 260, 6)):
        d.ellipse(s((sx - r, sy - r, sx + r, sy + r)), fill=MOON)
    text_c(d, 540, 860, "Ferdig for nå", f_fredoka(96), PAPER)
    text_c(d, 540, 960, "Alt er lagret.", f_andika(44), MOON)
    d.ellipse(s((420, 1180, 660, 1420)), fill=PAPER)
    icon_check(d, 540, 1300, 120, DUSK, w=18)
    d.ellipse(s((1080 - 140, 44, 1080 - 36, 148)), outline="#6f6a99", width=s(4))
    icon_gear(d, 1080 - 88, 96, 58, MOON, DUSK)
    finish(im, "done_for_now.png")


# ---------- 6. app icon ----------
def icon_art(d, N, k, mono=None):
    """Rounded play triangle whose corners are three balls. k = scale of the art inside the N canvas."""
    c = N / 2
    pts = [
        (c - 0.20 * N * k, c - 0.25 * N * k),
        (c - 0.20 * N * k, c + 0.25 * N * k),
        (c + 0.27 * N * k, c),
    ]
    d.polygon(pts, fill=mono or PAPER)
    for (px, py), col in zip(pts, ("#e8573f", "#2f8fd6", "#f2b632")):
        r = 0.105 * N * k
        if mono:
            d.ellipse((px - r * 1.2, py - r * 1.2, px + r * 1.2, py + r * 1.2), fill=mono)
        else:
            d.ellipse(
                (px - r, py - r, px + r, py + r), fill=col, outline=PAPER, width=int(0.022 * N * k)
            )


def app_icon():
    N = 2048
    im = Image.new("RGBA", (N, N), GREEN)  # full-bleed square; Play applies its own corner mask
    icon_art(ImageDraw.Draw(im), N, 0.92)
    icon = im.resize((512, 512), Image.LANCZOS)
    icon.save(OUT / "app_icon_512.png")
    # adaptive layers, 432x432 = 108 dp at xxxhdpi; art kept inside the 66 dp safe circle (264 px)
    A = 432 * 4
    fg = Image.new("RGBA", (A, A), (0, 0, 0, 0))
    icon_art(ImageDraw.Draw(fg), A, 0.68)
    fg.resize((432, 432), Image.LANCZOS).save(OUT / "icon_adaptive_foreground.png")
    Image.new("RGB", (432, 432), GREEN).save(OUT / "icon_adaptive_background.png")
    mo = Image.new("RGBA", (A, A), (0, 0, 0, 0))
    icon_art(ImageDraw.Draw(mo), A, 0.68, mono=(255, 255, 255, 255))
    mo.resize((432, 432), Image.LANCZOS).save(OUT / "icon_adaptive_monochrome.png")
    # preview: Play icon with its corner mask, launcher circle mask, 96 and 48 px
    prev = Image.new("RGB", (1180, 540), PAPER)
    m = Image.new("L", (512, 512), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, 511, 511), radius=102, fill=255)
    prev.paste(icon, (14, 14), m)
    lay = Image.open(OUT / "icon_adaptive_background.png").convert("RGBA")
    lay.alpha_composite(Image.open(OUT / "icon_adaptive_foreground.png"))
    circ = Image.new("L", (432, 432), 0)
    ImageDraw.Draw(circ).ellipse((36, 36, 396, 396), fill=255)
    prev.paste(lay, (560, 54), circ)
    d = ImageDraw.Draw(prev)
    d.ellipse(
        (560 + 216 - 132, 54 + 216 - 132, 560 + 216 + 132, 54 + 216 + 132),
        outline="#c03030",
        width=2,
    )
    small = lay.crop((36, 36, 396, 396))
    for size, y in ((96, 60), (48, 200)):
        sm = small.resize((size, size), Image.LANCZOS)
        mk = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mk).ellipse((0, 0, size - 1, size - 1), fill=255)
        prev.paste(sm, (1040, y), mk)
    prev.save(OUT / "src/app_icon_preview.png")


if __name__ == "__main__":
    start_screen()
    parent_gate()
    parent_area()
    ingame_home()
    done_screen()
    app_icon()
    print("ok")

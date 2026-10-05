"""WCAG 2.x contrast + Machado 2009 colour-blind simulation for the MWM Play shell palette."""

import itertools
import math


def lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def lum(h):
    r, g, b = (lin(v) for v in rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def cr(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


PAIRS = [
    ("ink on paper", "#24211d", "#fbf8f2", 4.5),
    ("ink-soft on paper", "#5c5449", "#fbf8f2", 4.5),
    ("ink-soft on card white", "#5c5449", "#ffffff", 4.5),
    ("green on paper (text)", "#1f7a5a", "#fbf8f2", 4.5),
    ("white on green button", "#ffffff", "#1f7a5a", 4.5),
    ("tile outline vs paper", "#8f8371", "#fbf8f2", 3.0),
    ("toggle off track vs card", "#8f8371", "#ffffff", 3.0),
    ("ink on BC band (plum)", "#24211d", "#e6ddf3", 4.5),
    ("ink on WS band (water)", "#24211d", "#d3e8f5", 4.5),
    ("ink on TE band (wood)", "#24211d", "#f0dcc4", 4.5),
    ("ink on SP band (aqua)", "#24211d", "#cdeeed", 4.5),
    ("ink on TV band (grass)", "#24211d", "#d8eccb", 4.5),
    ("cream on dusk (done screen)", "#fbf8f2", "#2e2b4f", 4.5),
    ("moon-soft on dusk", "#c9c3e6", "#2e2b4f", 4.5),
    ("ok button cream vs dusk", "#fbf8f2", "#2e2b4f", 3.0),
    ("home ring ink vs Tile Explorer bg", "#24211d", "#ebf2ff", 3.0),
    ("home disc white vs Ball Connect bg", "#ffffff", "#000000", 3.0),
    ("home disc white vs Water Sort bg", "#ffffff", "#0f2133", 3.0),
    ("home ring ink vs Spotless bg", "#24211d", "#e6e0d9", 3.0),
    ("home ring ink vs Timber grass", "#24211d", "#8cc63f", 3.0),
    ("key face vs paper (gate)", "#8f8371", "#fbf8f2", 3.0),
    ("plum adult accent on paper", "#5b3f8c", "#fbf8f2", 4.5),
]
for name, fg, bg, need in PAIRS:
    v = cr(fg, bg)
    print(f"{name:38s} {fg} on {bg}: {v:5.2f}:1  need {need}  {'PASS' if v >= need else 'FAIL'}")

# Machado et al. 2009, severity 1.0
M = {
    "protan": [
        [0.152286, 1.052583, -0.204868],
        [0.114503, 0.786281, 0.099216],
        [-0.003882, -0.048116, 1.051998],
    ],
    "deutan": [
        [0.367322, 0.860646, -0.227968],
        [0.280085, 0.672501, 0.047413],
        [-0.011820, 0.042940, 0.968881],
    ],
    "tritan": [
        [1.255528, -0.076749, -0.178779],
        [-0.078411, 0.930809, 0.147602],
        [0.004733, 0.691367, 0.303900],
    ],
}


def sim(h, m):
    l = [lin(v) for v in rgb(h)]
    o = [max(0, min(1, sum(m[i][j] * l[j] for j in range(3)))) for i in range(3)]
    return o


def to_lab(l):
    r, g, b = l
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
    f = lambda t: t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    return (116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)))


def de(a, b):
    return math.dist(to_lab(a), to_lab(b))


GROUPS = {
    "toggle on vs off": ["#1f7a5a", "#8f8371"],
    "tile bands": ["#e6ddf3", "#d3e8f5", "#f0dcc4", "#cdeeed", "#d8eccb"],
    "icon balls": ["#e8573f", "#f2b632", "#2f8fd6"],
}
print("\nColour-blind check (min CIELAB dE between group members; <10 = hard to tell apart)")
for g, cols in GROUPS.items():
    row = []
    for kind in ["normal"] + list(M):
        ls = [[lin(v) for v in rgb(c)] if kind == "normal" else sim(c, M[kind]) for c in cols]
        row.append(f"{kind} {min(de(a, b) for a, b in itertools.combinations(ls, 2)):5.1f}")
    print(f"{g:18s}", " | ".join(row))

"""v2 UI kit: dark navy panels with thin gold trim, angular corners, slanted bars.

Everything is drawn at the 960x540 base resolution (the game scales it x2 to 1080p).
"""

import img
import pal

TYPE_COLOURS = {  # card type: (dark, mid, light)
    "terrain": ("grass1", "grass3", "grass5"),
    "encounter": ("red1", "red2", "red4"),
    "building": ("gold1", "gold2", "gold4"),
    "special": ("violet1", "violet3", "violet4"),
    "skill": ("blue1", "blue3", "blue5"),
}

DIGITS = {  # 3x5
    "0": ["###", "#.#", "#.#", "#.#", "###"],
    "1": [".#.", "##.", ".#.", ".#.", "###"],
    "2": ["###", "..#", "###", "#..", "###"],
    "3": ["###", "..#", ".##", "..#", "###"],
    "4": ["#.#", "#.#", "###", "..#", "..#"],
    "5": ["###", "#..", "###", "..#", "###"],
    "6": ["###", "#..", "###", "#.#", "###"],
    "7": ["###", "..#", ".#.", ".#.", ".#."],
    "8": ["###", "#.#", "###", "#.#", "###"],
    "9": ["###", "#.#", "###", "..#", "###"],
}


def chamfer(c, x0, y0, x1, y1, k=1):
    """Clear k px off each corner of a rectangle already drawn on canvas c."""
    for i in range(k):
        for j in range(k - i):
            for x, y in ((x0 + i, y0 + j), (x1 - i, y0 + j), (x0 + i, y1 - j), (x1 - i, y1 - j)):
                c.set(x, y, None)


def frame_box(c, x0, y0, x1, y1, fill="cool0", line="ink0", hi="cool2", k=2):
    """Outlined box with chamfered corners and a soft top-left inner highlight."""
    c.rect(x0, y0, x1, y1, line)
    c.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, fill)
    c.hline(x0 + k, x1 - k, y0 + 1, hi)
    c.vline(x0 + 1, y0 + k, y1 - k, hi)
    chamfer(c, x0, y0, x1, y1, k)
    # re-draw the diagonal outline across the clipped corners
    for i in range(k):
        c.set(x0 + i, y0 + k - 1 - i + 0, line) if k > 1 else None
        c.set(x1 - i, y0 + k - 1 - i, line) if k > 1 else None
        c.set(x0 + i, y1 - k + 1 + i, line) if k > 1 else None
        c.set(x1 - i, y1 - k + 1 + i, line) if k > 1 else None


def gold_corners(c, x0, y0, x1, y1, n=4):
    """Small gold L-brackets with a bright tip at each corner of a rectangle."""
    for sx, sy, cx, cy in ((1, 1, x0, y0), (-1, 1, x1, y0), (1, -1, x0, y1), (-1, -1, x1, y1)):
        for i in range(n):
            c.set(cx + sx * i, cy, "gold3")
            c.set(cx, cy + sy * i, "gold3")
        c.set(cx, cy, "gold5")
        c.set(cx + sx, cy + sy, "gold2")


def panel(w, h, ornate=True, fill="cool0"):
    c = img.Canvas(w, h)
    frame_box(c, 0, 0, w - 1, h - 1, fill=fill, line="ink0", hi="cool2", k=3)
    if ornate:
        c.hline(4, w - 5, 2, "cool1")
        gold_corners(c, 2, 2, w - 3, h - 3, n=5)
    return c.im


def header(w, h=12):
    """Title strip: deep blue band with a gold underline and a diamond at each end."""
    c = img.Canvas(w, h)
    c.rect(0, 0, w - 1, h - 1, "blue0")
    c.rect(0, 1, w - 1, h - 4, "blue1")
    c.hline(0, w - 1, 1, "blue2")
    c.hline(0, w - 1, h - 2, "gold2")
    c.hline(0, w - 1, h - 1, "ink0")
    for x in (2, w - 3):
        c.set(x, h // 2 - 1, "gold4")
        c.set(x - 1, h // 2 - 1, "gold2")
        c.set(x + 1, h // 2 - 1, "gold2")
        c.set(x, h // 2 - 2, "gold2")
        c.set(x, h // 2, "gold2")
    return c.im


BARS = {
    "hp": ("red1", "red2", "red3", "red4"),
    "mana": ("blue1", "blue2", "blue3", "blue5"),
    "xp": ("gold1", "gold2", "gold3", "gold4"),
    "rp": ("roof1", "roof2", "roof3", "roof5"),
}


def bar(w, h, frac, kind="hp", ticks=0):
    """Slanted gauge: the left end leans, the fill has a lit top edge."""
    c = img.Canvas(w, h)
    for y in range(h):
        s = h - 1 - y  # slant: lower rows start further left
        c.hline(s // 2, w - 1 - (y // 2), y, "ink0")
    for y in range(1, h - 1):
        s = (h - 1 - y) // 2
        c.hline(s + 1, w - 2 - y // 2, y, "cool0")
    dark, mid, base, light = BARS[kind]
    fill_w = int(round((w - 3) * max(0.0, min(1.0, frac))))
    for y in range(1, h - 1):
        s = (h - 1 - y) // 2 + 1
        end = min(s + fill_w - 1, w - 2 - y // 2)
        if end < s:
            continue
        col = light if y == 1 else dark if y == h - 2 else base if y < h // 2 + 1 else mid
        c.hline(s, end, y, col)
    if ticks:
        for k in range(1, ticks):
            x = 1 + (w - 3) * k // ticks
            for y in range(1, h - 1):
                c.set(x + (h - 1 - y) // 2, y, "ink0" if c.get(x + (h - 1 - y) // 2, y) != pal.c("cool0") else "cool1")
    return c.im


def button(w, h, state="normal"):
    """Angular button. state: normal / active / pressed."""
    c = img.Canvas(w, h)
    fill, hi, line = {"normal": ("cool2", "cool4", "ink0"), "active": ("blue2", "blue4", "ink0"), "pressed": ("blue1", "blue2", "ink0")}[state]
    frame_box(c, 0, 0, w - 1, h - 1, fill=fill, line=line, hi=hi, k=2)
    c.hline(2, w - 3, h - 2, "cool1" if state == "normal" else "blue0")
    if state == "active":
        c.hline(2, w - 3, 0, "gold3")
        c.hline(2, w - 3, h - 1, "gold2")
    return c.im


RARITY = {"common": "cool5", "rare": "blue4", "epic": "pink3", None: None}


def slot(size=28, rarity=None, skill=False):
    """Inset item slot; rarity tints the inner border and adds a corner gem."""
    c = img.Canvas(size, size)
    c.rect(0, 0, size - 1, size - 1, "ink0")
    c.rect(1, 1, size - 2, size - 2, "blue0" if skill else "cool0")
    c.hline(1, size - 2, 1, "ink1")
    c.vline(1, 1, size - 2, "ink1")
    c.hline(2, size - 2, size - 2, "cool2")
    c.vline(size - 2, 2, size - 2, "cool2")
    chamfer(c, 0, 0, size - 1, size - 1, 1)
    col = RARITY[rarity]
    if col:
        c.hline(2, size - 3, size - 2, col)
        c.vline(size - 2, 2, size - 3, col)
        c.set(size - 3, size - 3, "white")
    return c.im


def digits(s, color="ink0", outline=None):
    w = 4 * len(s) - 1
    c = img.Canvas(w + (2 if outline else 0), 5 + (2 if outline else 0))
    o = 1 if outline else 0
    for i, ch in enumerate(s):
        for y, row in enumerate(DIGITS[ch]):
            for x, v in enumerate(row):
                if v == "#":
                    c.set(o + i * 4 + x, o + y, color)
    if outline:
        c.outline(outline)
    return c.im


# --------------------------------------------------------------------------- cards

CARD_W, CARD_H = 64, 88
ART = (5, 5, 54, 54)  # x, y, w, h of the illustration window
PLATE = (5, 61, 54, 16)  # name plate; the game writes the name centred here


def backdrop(kind):
    """54x54 scene behind a card's art: banded sky, soft hills, ground for the object."""
    import math

    w, h = ART[2], ART[3]
    c = img.Canvas(w, h)
    skies = {
        "terrain": ["blue4", "blue5", "blue6", "sea7"],
        "encounter": ["violet1", "violet2", "pink1", "roof3"],
        "building": ["blue4", "blue5", "blue6", "gold5"],
        "special": ["violet0", "violet1", "violet2", "violet3"],
        "skill": ["blue0", "blue1", "blue1", "blue2"],
    }[kind]
    bands = [0, 14, 24, 30, h]
    for i in range(4):
        for y in range(bands[i], bands[i + 1]):
            for x in range(w):
                col = skies[i]
                if i and y == bands[i] and x % 2 == 0:
                    col = skies[i - 1]  # one dithered row softens each band edge
                c.set(x, y, col)
    if kind == "skill":
        for (x, y) in ((6, 8), (44, 12), (12, 30), (48, 40), (30, 6), (22, 46), (38, 26)):
            c.set(x, y, "blue5")
            c.set(x + 1, y, "blue3")
            c.set(x, y + 1, "blue3")
        return c.im
    if kind in ("terrain", "building"):
        for cx, cy, r in ((12, 9, 4), (16, 8, 3), (40, 13, 3), (44, 12, 4)):  # clouds
            for y in range(cy - r, cy + 2):
                for x in range(cx - r - 2, cx + r + 3):
                    if ((x - cx) / (r + 2)) ** 2 + ((y - cy) / r) ** 2 <= 1:
                        c.set(x, y, "white" if y < cy else "blue6")
    if kind == "special":
        for (x, y) in ((5, 5), (20, 9), (33, 4), (47, 8), (10, 18), (41, 19), (27, 15)):
            c.set(x, y, "violet5")
    far = {"terrain": "grass1", "encounter": "violet0", "building": "grass1", "special": "violet0"}[kind]
    near = {"terrain": ("grass2", "grass3", "grass4"), "encounter": ("grass0", "grass1", "grass2"),
            "building": ("grass2", "grass3", "grass4"), "special": ("violet1", "violet2", "violet3")}[kind]
    for x in range(w):
        top = int(round(33 - 3.0 * math.sin(x * 0.13 + 0.6) - 1.6 * math.sin(x * 0.37 + 2.0)))
        for y in range(top, h):
            c.set(x, y, far)
        mid = int(round(38 - 1.5 * math.sin(x * 0.09 + 2.5)))
        for y in range(mid, h):
            c.set(x, y, near[0] if y == mid else near[1])
        for y in range(43, h):
            c.set(x, y, near[2] if y > 43 else near[1])
    return c.im


def card_frame(kind, level=1):
    dark, mid, light = TYPE_COLOURS[kind]
    c = img.Canvas(CARD_W, CARD_H)
    frame_box(c, 0, 0, CARD_W - 1, CARD_H - 1, fill="cool1", line="ink0", hi="cool3", k=3)
    c.hline(3, CARD_W - 4, CARD_H - 2, "cool0")
    c.vline(CARD_W - 2, 3, CARD_H - 4, "cool0")
    # thin gold trim around art and plate
    for (x, y, w, h) in (ART, PLATE):
        c.rect(x - 1, y - 1, x + w, y + h, "gold2")
        c.hline(x - 1, x + w // 2, y - 1, "gold3")
        c.rect(x, y, x + w - 1, y + h - 1, None)
    # name plate in the type colour
    x, y, w, h = PLATE
    c.rect(x, y, x + w - 1, y + h - 1, dark)
    c.hline(x, x + w - 1, y, mid)
    c.hline(x, x + w - 1, y + h - 1, "ink0")
    # bottom gem and trim
    gy = CARD_H - 8
    c.hline(8, CARD_W - 9, gy + 2, "gold2")
    for dy, half in ((0, 1), (1, 2), (2, 3), (3, 2), (4, 1)):
        c.hline(31 - half + 1, 32 + half - 1, gy + dy, "ink0")
    for dy, half in ((1, 1), (2, 2), (3, 1)):
        c.hline(31 - half + 1, 32 + half - 1, gy + dy, mid)
    c.set(31, gy + 1, light)
    c.set(31, gy + 2, light)
    # level badge: a gold shield with the digit
    badge = img.Canvas(11, 13)
    badge.rect(0, 0, 10, 9, "ink0")
    badge.rect(1, 1, 9, 8, "gold3")
    badge.hline(1, 9, 1, "gold5")
    badge.vline(1, 1, 8, "gold4")
    badge.hline(1, 9, 8, "gold2")
    for dy, x0, x1 in ((10, 1, 9), (11, 3, 7), (12, 5, 5)):
        badge.hline(x0, x1, dy, "ink0")
    badge.hline(2, 8, 9, "gold2")
    badge.hline(4, 6, 10, "gold2")
    badge.set(5, 11, "gold2")
    badge.set(0, 0, None)
    badge.set(10, 0, None)
    img.paste(badge.im, digits(str(level), "ink0"), 4, 2)
    img.paste(c.im, badge.im, 1, 1)
    # type disc, top right
    disc = img.Canvas(12, 12)
    for yy in range(12):
        for xx in range(12):
            d = ((xx - 5.5) ** 2 + (yy - 5.5) ** 2) ** 0.5
            if d <= 6.0:
                disc.set(xx, yy, "ink0")
            if d <= 4.9:
                disc.set(xx, yy, mid if (xx + yy) > 9 else light)
    img.paste(disc.im, type_glyph(kind), 2, 2)
    img.paste(c.im, disc.im, CARD_W - 14, 2)
    return c.im


GLYPHS = {  # 8x8, drawn in white on the type disc
    "terrain": ["........", ".....##.", "...####.", "..#####.", ".####...", ".##.....", "#.......", "........"],
    "encounter": ["..####..", ".######.", ".#.##.#.", ".######.", "..####..", "..#..#..", "........", "........"],
    "building": ["...##...", "..####..", ".######.", "########", ".#.##.#.", ".#.##.#.", ".######.", "........"],
    "special": ["...#....", "...#....", ".#####..", "..###...", ".##.##..", "........", "........", "........"],
    "skill": [".....#..", "....#...", "...##...", "..####..", "...##...", "...#....", "..#.....", "........"],
}


def type_glyph(kind):
    c = img.Canvas(8, 8)
    for y, row in enumerate(GLYPHS[kind]):
        for x, v in enumerate(row):
            if v == "#":
                c.set(x, y, "white")
    return c.im


def card(kind, level, art):
    """Full card: frame, backdrop and the object sprite standing in the window."""
    frame = card_frame(kind, level)
    out = img.new(CARD_W, CARD_H)
    win = backdrop(kind)
    ax = (ART[2] - art.width) // 2
    ay = ART[3] - art.height + (2 if kind != "skill" else -3)
    img.paste(win, art, ax, ay)
    img.paste(out, win, ART[0], ART[1])
    img.paste(out, frame, 0, 0)
    return out

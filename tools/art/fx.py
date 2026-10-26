"""Battle and map effects. Hard-edged, palette only, short loops (see manifest for fps).

All frames are 16x16 except levelup (16x24, anchored like map objects) and the
fireball projectile (8x8). Effects are drawn centred on the unit / cell.
"""
import math

import px

T = 16


def _canvas(w=T, h=T):
    return px.Canvas(w, h)


def _ang(x, y, cx, cy):
    return math.degrees(math.atan2(y + 0.5 - cy, x + 0.5 - cx)) % 360


def _in_range(a, a0, a1):
    return a0 <= a <= a1 if a0 <= a1 else (a >= a0 or a <= a1)


def slash():
    """Sword swing from the upper right down to the lower left, bulging towards the
    viewer (mirror it for a swing to the other side)."""
    frames = []
    cx, cy, r = 1.5, 1.5, 12.5
    for (a0, a1, thick, core) in ((0, 45, 2.4, "w"), (0, 90, 3.6, "w"), (45, 90, 1.6, "l")):
        c = _canvas()
        span = a1 - a0
        for y in range(T):
            for x in range(T):
                a = _ang(x, y, cx, cy)
                if not (a0 - 2 <= a <= a1 + 2):
                    continue
                t = min(1.0, max(0.0, (a - a0) / span))
                w = thick * math.sin(math.pi * (0.15 + 0.7 * t)) + 0.3
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                off = d - r
                if -w / 2 - 0.4 <= off <= w / 2 + 0.2:
                    c.set(x, y, core if off > -w / 2 + 0.6 else "a")
        frames.append(c.image())
    return frames


def hit():
    frames = []
    c = _canvas()
    for (x, y) in ((8, 6), (8, 7), (8, 8), (8, 9), (8, 10), (6, 8), (7, 8), (9, 8), (10, 8)):
        c.set(x, y, "w")
    c.set(8, 8, "Y")
    frames.append(px.outline(c.image(), "k"))
    c = _canvas()
    for i in range(1, 6):
        for (x, y) in ((8, 8 - i), (8, 8 + i), (8 - i, 8), (8 + i, 8)):
            c.set(x, y, "Y" if i > 2 else "w")
    for i in range(1, 3):
        for (x, y) in ((8 - i, 8 - i), (8 + i, 8 - i), (8 - i, 8 + i), (8 + i, 8 + i)):
            c.set(x, y, "w")
    c.set(8, 8, "w")
    frames.append(px.outline(c.image(), "k"))
    c = _canvas()
    for (x, y) in ((8, 1), (8, 15), (1, 8), (15, 8), (3, 3), (13, 3), (3, 13), (13, 13)):
        c.set(x, y, "y")
    frames.append(c.image())
    return frames


PLUS = ["..g..", ".gwg.", "gwwwg", ".gwg.", "..g.."]


def _plus(c, x, y, fade):
    for j, row in enumerate(PLUS):
        for i, k in enumerate(row):
            if k != ".":
                c.set(x + i, y + j, ("G" if k == "g" else "g") if fade else k)


def heal():
    frames = []
    spots = [(2, 9), (9, 6), (6, 11)]
    for f in range(4):
        c = _canvas()
        for n, (x, y) in enumerate(spots):
            age = f - n * 0.5
            if 0 <= age <= 3:
                _plus(c, x, int(y - age * 2), age >= 2.5)
        frames.append(px.outline(c.image(), "h"))
    return frames


def levelup():
    """16x24, bottom 16 = the hero's cell. Beams rise and a ring opens at the feet."""
    frames = []
    for f in range(4):
        c = _canvas(T, 24)
        # ring at the feet
        rx, ry = 3 + f * 1.3, 1.2 + f * 0.4
        for y in range(24):
            for x in range(T):
                d = ((x + 0.5 - 8) / rx) ** 2 + ((y + 0.5 - 21) / ry) ** 2
                if 0.55 < d <= 1.15 and f < 3:
                    c.set(x, y, "Y" if y <= 21 else "y")
        # beams
        for bx, delay in ((3, 0), (8, 1), (12, 0)):
            top = 22 - (f - delay + 1) * 6
            for y in range(max(0, top), 21):
                if f - delay >= 0 and y > 22 - (f - delay + 1) * 6:
                    k = "w" if y < top + 3 else ("Y" if bx == 8 else "y")
                    if f == 3 and y > 12:
                        continue
                    c.set(bx, y, k)
        # sparkles
        for (sx, sy, sf) in ((5, 6, 2), (11, 9, 1), (2, 3, 3), (13, 2, 3)):
            if f >= sf:
                for (dx, dy) in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                    c.set(sx + dx, sy + dy - (f - sf), "w" if (dx, dy) == (0, 0) else "Y")
        frames.append(c.image())
    return frames


def poof():
    """Death puff: a cloud that swells and breaks into drifting wisps."""
    frames = []
    puffs = [
        [(8, 10, 3.2)],
        [(6, 10, 3.4), (10, 9, 3.4), (8, 7, 3.0)],
        [(4, 10, 3.0), (12, 9, 3.0), (8, 5, 2.8), (8, 11, 2.4)],
        [(3, 9, 1.8), (13, 7, 1.8), (8, 3, 1.6), (9, 12, 1.4)],
    ]
    for f, group in enumerate(puffs):
        c = _canvas()
        for y in range(T):
            for x in range(T):
                for (cx, cy, r) in group:
                    d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                    if d <= r:
                        shade = (y + 0.5 - cy) > r * 0.35 or (x + 0.5 - cx) > r * 0.45
                        c.set(x, y, "l" if shade else "w")
                        break
        im = c.image()
        frames.append(px.outline(im, "s") if f < 3 else im)
    return frames


def merge():
    """Flash when two cards merge on a cell: an expanding gold ring with sparks."""
    frames = []
    for f, r in enumerate((2.5, 4.5, 6.5, 7.5)):
        c = _canvas()
        for y in range(T):
            for x in range(T):
                d = math.hypot(x + 0.5 - 8, y + 0.5 - 8)
                if abs(d - r) < (0.9 if f < 3 else 0.6):
                    c.set(x, y, "Y" if f < 2 else ("y" if f == 2 else "O"))
                elif f == 0 and d < r - 0.9:
                    c.set(x, y, "w")
        if f in (1, 2):
            for (x, y) in ((8, 0), (8, 15), (0, 8), (15, 8)):
                c.set(x, y, "w")
        frames.append(c.image())
    return frames


def fireball():
    """8x8 projectile, flies left to right (flip for the other way)."""
    frames = []
    for f in range(2):
        im = px.S([
            """
........
..eO....
.eOYYk..
eOYwwYk.
.eOYYk..
..eO....
........
........
""",
            """
........
...eO...
.eOOYYk.
eeOYwwYk
.eOOYYk.
...eO...
........
........
"""][f])
        frames.append(im)
    return frames


def shield():
    """Mana shield bubble around a unit (2-frame shimmer)."""
    frames = []
    for f in range(2):
        c = _canvas()
        for y in range(T):
            for x in range(T):
                d = math.hypot(x + 0.5 - 8, y + 0.5 - 8.5)
                if 6.4 < d <= 7.5:
                    a = _ang(x, y, 8, 8.5)
                    hl = _in_range(a, 190 + f * 30, 250 + f * 30)
                    c.set(x, y, "w" if hl else "a")
        frames.append(c.image())
    return frames


def haste():
    """Speed lines trailing behind a unit that faces right (flip for left)."""
    frames = []
    for f in range(2):
        c = _canvas()
        for (y, x0, ln) in ((5, 1 + f, 4), (9, 0 + f * 2, 5), (13, 2 + f, 3)):
            for x in range(x0, min(T, x0 + ln)):
                c.set(x, y, "w" if x == x0 + ln - 1 else "a")
        frames.append(c.image())
    return frames


FX = {
    # name: (frames_fn, fps, loop)
    "slash": (slash, 15, False),
    "hit": (hit, 15, False),
    "heal": (heal, 8, False),
    "levelup": (levelup, 8, False),
    "poof": (poof, 10, False),
    "merge": (merge, 12, False),
    "fireball": (fireball, 10, True),
    "shield": (shield, 4, True),
    "haste": (haste, 10, True),
}

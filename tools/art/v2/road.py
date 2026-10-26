"""v2 dirt road: one 32 px tile per connection mask (N1 E2 S4 W8), drawn over the ground.

The path is 14 px wide and always crosses a tile edge at the same place, so any two
connected road tiles meet cleanly. Pixels outside the path stay clear.
"""

import math

import numpy as np
from PIL import Image

import pal
from terrain import T, _hash, wave

HALF = 7.0
U, V = np.meshgrid(np.arange(T) + 0.5, np.arange(T) + 0.5)
ENDS = {1: (16.0, -6.0), 2: (38.0, 16.0), 4: (16.0, 38.0), 8: (-6.0, 16.0)}
EDGE_NOISE = [(0.7, 1, 0, 0.8), (0.6, 0, 1, 2.1), (0.5, 2, 1, 3.7), (0.4, 1, 2, 5.2)]


def _seg(ax, ay, bx, by):
    px, py = U - ax, V - ay
    dx, dy = bx - ax, by - ay
    t = np.clip((px * dx + py * dy) / (dx * dx + dy * dy), 0.0, 1.0)
    return np.hypot(px - t * dx, py - t * dy)


def _smin(a, b, k=6.0):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)


def road_distance(mask):
    """Signed distance inside the path (positive inside)."""
    d = None
    for bit, (ex, ey) in ENDS.items():
        if mask & bit:
            s = _seg(16.0, 16.0, ex, ey)
            d = s if d is None else _smin(d, s)
    if d is None:
        d = np.hypot(U - 16.0, V - 16.0)
    return HALF - d + wave(EDGE_NOISE)


def road_tile(mask):
    d = road_distance(mask)
    gy, gx = np.gradient(d)
    out = np.zeros((T, T, 4), dtype=np.uint8)
    for y in range(T):
        for x in range(T):
            v = d[y, x]
            if v <= 0:
                continue
            # gradient points inward; the side facing the top-left light sits in shade
            shade_side = gx[y, x] + gy[y, x] > 0.25
            h = _hash(x, y, 51)
            if v <= 1.0:
                c = "dirt1" if shade_side else "dirt2"
                if h < 0.18:
                    c = "grass4" if h < 0.09 else "grass3"  # grass creeping over the edge
            elif v <= 2.2:
                c = "dirt2" if shade_side else "dirt3"
            else:
                c = "dirt3"
                if h < 0.06:
                    c = "dirt2"
                elif h > 0.95:
                    c = "dirt4"
            out[y, x] = pal.c(c)
    im = Image.fromarray(out, "RGBA").copy()
    _pebbles(im, mask)
    return im


def _pebbles(im, mask):
    px = im.load()
    for k in range(3):
        x = 9 + int(_hash(mask, k, 61) * 14)
        y = 9 + int(_hash(mask, k, 62) * 14)
        if px[x, y][3] and px[x + 1, y][3] and px[x, y + 1][3]:
            px[x, y] = pal.c("stone5")
            px[x + 1, y] = pal.c("stone4")
            px[x, y + 1] = pal.c("dirt1")
            px[x + 1, y + 1] = pal.c("dirt2")


def strip():
    sheet = Image.new("RGBA", (T * 16, T), (0, 0, 0, 0))
    for m in range(16):
        sheet.paste(road_tile(m), (m * T, 0))
    return sheet

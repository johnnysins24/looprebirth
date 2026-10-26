"""v2 island-in-the-sea ground: 32 px dual-grid tiles, 4 water frames.

A tile sits on the corners of four map cells (index TL1 + TR2 + BL4 + BR8). Each land
cell is a 32 px square; blurring those squares with a narrow gaussian and reading the
result back as a distance gives a rounded coastline that lines up across tiles. All
textures repeat every 32 px, so neighbouring tiles always meet cleanly.
"""

import math

import numpy as np
from PIL import Image

import pal

T = 32
SIGMA = 6.5
FRAMES = 4

U, V = np.meshgrid(np.arange(T) + 0.5, np.arange(T) + 0.5)
TAU = 2 * math.pi


def _phi(x):
    return 0.5 * (1.0 + np.vectorize(math.erf)(x / math.sqrt(2.0)))


def _phi_inv(p):
    # Acklam's rational approximation of the inverse normal CDF
    p = np.clip(p, 1e-9, 1 - 1e-9)
    a = [-3.969683028665376e01, 2.209460984245205e02, -2.759285104469687e02, 1.383577518672690e02, -3.066479806614716e01, 2.506628277459239e00]
    b = [-5.447609879822406e01, 1.615858368580409e02, -1.556989798598866e02, 6.680131188771972e01, -1.328068155288572e01]
    c = [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e00, -2.549732539343734e00, 4.374664141464968e00, 2.938163982698783e00]
    d = [7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e00, 3.754408661907416e00]
    out = np.zeros_like(p)
    lo = p < 0.02425
    hi = p > 1 - 0.02425
    mid = ~(lo | hi)
    q = np.sqrt(-2 * np.log(p[lo]))
    out[lo] = (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
    q = np.sqrt(-2 * np.log(1 - p[hi]))
    out[hi] = -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
    q = p[mid] - 0.5
    r = q * q
    out[mid] = (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q / (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1)
    return out


CORNERS = ((0, 0), (T, 0), (0, T), (T, T))  # TL TR BL BR


def land_distance(index, u=None, v=None):
    """Signed distance to the coast in px (positive on land) for a dual-grid tile."""
    u = U if u is None else u
    v = V if v is None else v
    f = np.zeros_like(u)
    for bit, (cx, cy) in enumerate(CORNERS):
        if index & (1 << bit):
            gx = _phi((u - cx + T / 2) / SIGMA) - _phi((u - cx - T / 2) / SIGMA)
            gy = _phi((v - cy + T / 2) / SIGMA) - _phi((v - cy - T / 2) / SIGMA)
            f += gx * gy
    return SIGMA * _phi_inv(np.clip(f, 0.0, 1.0))


# one pixel of margin so gradients at the tile edge match the neighbour's
UE, VE = np.meshgrid(np.arange(-1, T + 1) + 0.5, np.arange(-1, T + 1) + 0.5)


def coast(index):
    """Distance with the coastline wobble and the outward normal (toward the water),
    on the tile plus one pixel of margin."""
    de = land_distance(index, UE, VE) + wave(COAST_NOISE, UE, VE)
    gy, gx = np.gradient(de)
    gl = np.sqrt(gx**2 + gy**2) + 1e-9
    return de, -gx / gl, -gy / gl


def wave(terms, u=None, v=None):
    """Sum of sines that repeat every 32 px: terms are (amp, kx, ky, phase)."""
    u = U if u is None else u
    v = V if v is None else v
    out = np.zeros_like(u)
    for amp, kx, ky, ph in terms:
        out += amp * np.sin(TAU * (kx * u + ky * v) / T + ph)
    return out


COAST_NOISE = [(0.9, 1, 0, 0.3), (0.8, 0, 1, 1.9), (0.9, 2, 1, 4.0), (0.7, 1, -2, 2.2)]
SAND_NOISE = [(0.8, 1, 1, 1.0), (0.6, 2, 0, 2.5), (0.5, 0, 2, 0.4)]


def _hash(x, y, seed=0):
    h = (x * 374761393 + y * 668265263 + seed * 2246822519) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return (h ^ (h >> 16)) / 0xFFFFFFFF


# --- textures (all repeat every 32 px) ---------------------------------------------

GRASS_VARIANTS = 8
WATER_VARIANTS = 4


def grass(px, frame=0, variant=0):
    for y in range(T):
        for x in range(T):
            h = _hash(x, y, 7)
            px[y][x] = pal.c("grass3") if h < 0.03 else pal.c("grass5") if h > 0.982 else pal.c("grass4")
    if not variant:
        return
    # extra detail kept 3 px away from the tile edges, so variants never break a seam
    rnd = lambda k, s: _hash(variant, k, s)
    kind = variant % 4
    at = lambda k, lo=5, span=19: (lo + int(rnd(k, 1) * span), lo + int(rnd(k, 2) * span))
    if kind == 1:  # a few flowers
        for k in range(1 + variant // 4 * 2):
            _flower(px, *at(k), ("white", "pink3", "gold4")[k % 3])
        _tuft(px, *at(7))
    elif kind == 2:  # a clump of tall grass
        cx, cy = at(0, 9, 12)
        for dx, dy in ((-3, 0), (0, -2), (3, 1), (-1, 3), (2, 4)):
            _tuft(px, cx + dx, cy + dy)
    elif kind == 3:  # clover patch
        cx, cy = at(1, 9, 14)
        for dy in range(-3, 4):
            for dx in range(-4, 5):
                if dx * dx / 16 + dy * dy / 9 <= 1 and _hash(cx + dx, cy + dy, 9) < 0.7:
                    _put(px, cx + dx, cy + dy, "grass5" if _hash(cx + dx, cy + dy, 10) < 0.6 else "grass6")
    else:  # two tufts and maybe a pebble
        _tuft(px, *at(3))
        _tuft(px, *at(4))
        if variant > 4:
            cx, cy = at(2, 8, 16)
            for dx, dy, c in ((0, 0, "stone4"), (1, 0, "stone5"), (2, 0, "stone4"), (0, 1, "stone3"), (1, 1, "stone3"), (2, 1, "stone2"), (0, 2, "grass2"), (1, 2, "grass2"), (2, 2, "grass3")):
                _put(px, cx + dx, cy + dy, c)


def _put(px, x, y, name):
    px[y % T][x % T] = pal.c(name)


def _tuft(px, x, y):
    _put(px, x, y, "grass6")
    _put(px, x + 2, y, "grass6")
    _put(px, x + 1, y + 1, "grass5")
    _put(px, x, y + 1, "grass5")
    _put(px, x + 2, y + 1, "grass5")
    _put(px, x, y + 2, "grass3")
    _put(px, x + 1, y + 2, "grass2")
    _put(px, x + 2, y + 2, "grass3")


def _flower(px, x, y, petal):
    for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
        _put(px, x + dx, y + dy, petal)
    _put(px, x, y, "gold3" if petal != "gold4" else "roof3")
    _put(px, x, y + 2, "grass2")


def sand(px):
    for y in range(T):
        for x in range(T):
            h = _hash(x, y, 21)
            px[y][x] = pal.c("sand2") if h < 0.08 else pal.c("sand4") if h > 0.95 else pal.c("sand3")


SPARKLES = [((5, 9), 0), ((21, 4), 1), ((14, 22), 2), ((27, 18), 3), ((9, 29), 1)]
CRESTS = [(2, 4, 5), (17, 2, 4), (10, 11, 6), (25, 10, 4), (3, 18, 4), (18, 19, 5), (11, 26, 4), (26, 27, 5)]


def deep(px, frame, variant=0):
    for y in range(T):
        for x in range(T):
            px[y][x] = pal.c("sea3")
    crests = CRESTS
    if variant:
        crests = [(3 + int(_hash(variant, k, 31) * 26), 3 + int(_hash(variant, k, 32) * 26), 3 + int(_hash(variant, k, 33) * 3)) for k in range(5)]
    for i, (cx, cy, ln) in enumerate(crests):
        phase = (frame + i) % FRAMES
        shift = (0, 1, 1, 0)[phase]
        size = (ln, ln + 1, ln, ln - 1)[phase]
        for k in range(size):
            _put(px, cx + k + shift, cy, "sea4")
            if 0 < k < size - 1:
                _put(px, cx + k + shift, cy + 1, "sea2")
        if phase == 1:
            _put(px, cx + shift + size // 2, cy - 1, "sea5")
    for (sx, sy), f in SPARKLES:
        if variant:
            sx, sy = (sx + 7 * variant) % 26 + 3, (sy + 11 * variant) % 26 + 3
        if f == frame:
            _put(px, sx, sy, "white")
            _put(px, sx - 1, sy, "sea6")
            _put(px, sx + 1, sy, "sea6")


# --- tiles ----------------------------------------------------------------------------


def _blank():
    return [[(0, 0, 0, 0)] * T for _ in range(T)]


GRASS, BANK_TOP, BANK, SAND, WET, FOAM, FOAM2, SHALLOW, RING, MID, RING2, DEEP = range(12)


def classify(index, frame):
    de, nx, ny = coast(index)
    sw = 7.5 + wave(SAND_NOISE, UE, VE)
    off = (0.0, 0.6, 1.0, 0.6)[frame]
    ring = (-3.5, -4.5, -5.5, -6.5)[frame]
    cls = np.full(de.shape, DEEP)
    cls[de > -13.0] = MID
    cls[(de > -13.0) & (de > ring - 0.6) & (de <= ring + 0.4) & (de <= -7.0)] = RING2
    cls[de > -7.0] = SHALLOW
    cls[(de > -7.0) & (de > ring - 0.6) & (de <= ring + 0.4)] = RING
    cls[de > -0.6 - off] = FOAM2
    cls[de > -0.2 - off] = FOAM
    cls[de > 0.4] = WET
    cls[de > 1.5] = SAND
    bank = (ny > 0.35) & (de > sw - 2.0) & (de <= sw)
    cls[bank] = BANK
    cls[bank & (de > sw - 1.0)] = BANK_TOP
    cls[de > sw] = GRASS
    return cls


def land_tile(index, frame=0, variant=0):
    cls = classify(index, frame)
    grass_px, sand_px, deep_px = _blank(), _blank(), _blank()
    grass(grass_px, frame, variant if index == 15 else 0)
    sand(sand_px)
    deep(deep_px, frame, variant if index == 0 else 0)
    flat = {BANK_TOP: "dirt2", BANK: "dirt1", WET: "sand2", FOAM: "white", FOAM2: "sea7",
            SHALLOW: "sea5", RING: "sea6", MID: "sea4", RING2: "sea5"}
    out = np.zeros((T, T, 4), dtype=np.uint8)
    for y in range(T):
        for x in range(T):
            k = cls[y + 1, x + 1]
            up, down = cls[y, x + 1], cls[y + 2, x + 1]
            left, right = cls[y + 1, x], cls[y + 1, x + 2]
            if k == GRASS:
                c = grass_px[y][x]
                if down in (BANK_TOP, BANK):
                    c = pal.c("grass5")  # lit lip above the earth bank
                elif GRASS not in (up, down, left, right) or min(up, down, left, right) != GRASS or max(up, down, left, right) != GRASS:
                    c = pal.c("grass3")
            elif k == SAND:
                c = pal.c("sand2") if GRASS in (up, left) else sand_px[y][x]
            elif k == DEEP:
                c = deep_px[y][x]
            else:
                c = pal.c(flat[k])
            out[y, x] = c
    return Image.fromarray(out, "RGBA").copy()


def atlas():
    """16 tiles x 4 frames: tile i, frame f at column i % 4 + 4 f, row i // 4.
    Rows 4-5: grass variants 1-8 of tile 15. Row 6: open-water variants 1-4 of tile 0."""
    sheet = Image.new("RGBA", (T * 4 * FRAMES, T * 7), (0, 0, 0, 0))
    for f in range(FRAMES):
        for i in range(16):
            sheet.paste(land_tile(i, f), ((i % 4 + 4 * f) * T, (i // 4) * T))
        for k in range(GRASS_VARIANTS):
            sheet.paste(land_tile(15, f, variant=k + 1), ((k % 4 + 4 * f) * T, (4 + k // 4) * T))
        for k in range(WATER_VARIANTS):
            sheet.paste(land_tile(0, f, variant=k + 1), ((k + 4 * f) * T, 6 * T))
    return sheet


def pick_variant(i, j, index):
    """Which variant a map position uses (0 = plain)."""
    if index == 15:
        h = _hash(i, j, 41)
        return 0 if h < 0.45 else 1 + int(_hash(i, j, 42) * GRASS_VARIANTS) % GRASS_VARIANTS
    if index == 0:
        return int(_hash(i, j, 43) * (WATER_VARIANTS + 1)) % (WATER_VARIANTS + 1)
    return 0


if __name__ == "__main__":
    import sys

    import img

    out = sys.argv[1] if len(sys.argv) > 1 else "terrain.png"
    sh = atlas()
    print(img.bad_pixels(sh)[:3])
    img.zoom(sh, 2).save(out)

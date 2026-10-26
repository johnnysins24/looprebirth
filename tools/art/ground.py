"""Ground layer: grass, sea and the dual-grid edge tiles between them.

Dual grid: the ground TileMapLayer is offset by (-8, -8). Display tile (i, j)
covers the corners of four board cells TL=(i-1, j-1), TR=(i, j-1),
BL=(i-1, j), BR=(i, j). index = TL*1 + TR*2 + BL*4 + BR*8 (bit = land).
Each style renders all 16 indices by drawing the 2x2 cells as one 32x32 patch
and cutting out the centre, so neighbouring tiles always line up.
"""
import math

import pal
import px

T = 16
FRAMES = 4  # water animation frames

# ---------------------------------------------------------------- textures

GRASS_TUFTS = [
    # (x, y) of a 3-pixel "v" tuft: (x,y) (x+2,y) (x+1,y+1). Variant 0 is clean
    # and is used on coast tiles; 1-3 are picked at random for full-land tiles.
    [],
    [(4, 6)],
    [(11, 10), (2, 13)],
    [(9, 3)],
]


def grass_pixel(x, y, variant=0):
    """Tileable 16x16 grass texture in display-tile space."""
    x %= T
    y %= T
    for tx, ty in GRASS_TUFTS[variant]:
        if (x, y) in ((tx, ty), ((tx + 2) % T, ty), ((tx + 1) % T, (ty + 1) % T)):
            return "G"
    return "g"


# Wave crests per open-sea variant: (x, y, phase). A crest shimmers through the
# 4 frames: 2 px, 3 px (with a white glint), 2 px, gone.
WAVES = [
    [(3, 4, 0), (11, 11, 2)],
    [(9, 2, 1), (2, 12, 3)],
    [(6, 8, 2)],
    [(12, 5, 3), (5, 13, 1)],
]
CREST = {0: [0, 1], 1: [0, 1, 2], 2: [1, 2], 3: []}


def water_pixel(x, y, frame, variant=0):
    x %= T
    y %= T
    for wx, wy, ph in WAVES[variant]:
        f = (frame + ph) % FRAMES
        for dx in CREST[f]:
            if (x, y) == ((wx + dx) % T, wy):
                return "w" if (f == 1 and dx == 1) else "a"
    return "u"


# ---------------------------------------------------------------- dual grid


def cells_of(index):
    return [(index >> b) & 1 for b in range(4)]  # TL, TR, BL, BR


def land_patch(index, r_convex=4, r_concave=3):
    """32x32 boolean land mask for the 2x2 cells with the centre corner rounded."""
    tl, tr, bl, br = cells_of(index)
    cell = {(0, 0): tl, (1, 0): tr, (0, 1): bl, (1, 1): br}
    land = [[bool(cell[(x // T, y // T)]) for x in range(2 * T)] for y in range(2 * T)]
    n = tl + tr + bl + br
    C = T  # centre corner at (16, 16)

    def round_cell(cx, cy, r, make):
        # cx, cy: which cell (0/1); the r x r square of that cell touching C.
        sx = 1 if cx == 1 else -1
        sy = 1 if cy == 1 else -1
        ax, ay = C + sx * r, C + sy * r  # arc centre inside the cell
        for j in range(r):
            for i in range(r):
                x = C + (i if sx > 0 else -1 - i)
                y = C + (j if sy > 0 else -1 - j)
                d = math.hypot(x + 0.5 - ax, y + 0.5 - ay)
                if d > r - 0.15:
                    land[y][x] = make

    diag = (tl and br and not tr and not bl) or (tr and bl and not tl and not br)
    if n == 1 or diag:
        for (cx, cy), v in cell.items():
            if v:
                round_cell(cx, cy, r_convex, False)
    elif n == 3:
        for (cx, cy), v in cell.items():
            if not v:
                round_cell(cx, cy, r_concave, True)
    return land


def render_dual(index, style, frame=0, variant=0):
    """variant picks the grass texture (index 15) or the open-sea texture (index 0)."""
    land = land_patch(index)
    c = px.Canvas(T, T)
    for y in range(T):
        for x in range(T):
            key = style(land, x + T // 2, y + T // 2, frame, variant if index in (0, 15) else 0)
            if key:
                c.set(x, y, key)
    return c.image()


def is_land(land, x, y):
    if 0 <= x < 2 * T and 0 <= y < 2 * T:
        return land[y][x]
    return False


def depth_below_land(land, x, y, max_k):
    """k >= 1 if the pixel k rows above is land (pixel itself is not)."""
    for k in range(1, max_k + 1):
        if is_land(land, x, y - k):
            return k
    return 0


def dist_to_land(land, x, y, rmax=3):
    best = 99
    for dy in range(-rmax, rmax + 1):
        for dx in range(-rmax, rmax + 1):
            if is_land(land, x + dx, y + dy):
                best = min(best, max(abs(dx), abs(dy)))
    return best


# ---------------------------------------------------------------- styles

CLIFF = 4  # height of the south-facing cliff in pixels


def style_sea(land, x, y, frame, gv):
    """A: island in a bright sea."""
    if land[y][x]:
        return grass_pixel(x, y, gv)
    k = depth_below_land(land, x, y, CLIFF + 1)
    if 1 <= k <= CLIFF:
        # cliff face under a land edge
        if k == 1:
            return "G"
        if k == CLIFF:
            return "d"
        # tiny vertical streaks for texture
        return "d" if ((x * 3 + k) % 7 == 0 and k == 3) else "b"
    d = dist_to_land(land, x, y, 2)
    if k == CLIFF + 1 or d == 1:
        # waterline: foam that moves along the shore
        if (x + y * 3 + frame) % 4 == 0:
            return "w"
        return "a"
    if d == 2 and k != CLIFF + 2:
        return "a" if (x + y + frame) % 2 == 0 else "u"
    return water_pixel(x, y, frame, gv)


def style_forest(land, x, y, frame, gv):
    """B: clearing in a forest (grass outside, tree canopy edge)."""
    if land[y][x]:
        g = grass_pixel(x, y, gv)
        # shadow cast by the canopy onto the grass, south side only
        if is_land(land, x, y) and not is_land(land, x, y - 1) and False:
            return "G"
        return g
    d = dist_to_land(land, x, y, 2)
    k = depth_below_land(land, x, y, 3)
    # canopy with round bumps
    bx, by = x % 8, y % 8
    bump = (bx - 3.5) ** 2 + (by - 3.5) ** 2
    if d == 1:
        return "H" if k == 0 else "h"
    if bump < 6:
        return "G" if (bx < 3 and by < 3) else "h"
    return "h" if bump < 13 else "H"


def style_parchment(land, x, y, frame, gv):
    """C: grass island drawn on a parchment map."""
    if land[y][x]:
        return grass_pixel(x, y, gv)
    d = dist_to_land(land, x, y, 3)
    if d == 1:
        return "d"
    if d == 3:
        return "t" if (x + y) % 3 else "c"
    if (x * 7 + y * 13) % 29 == 0:
        return "t"
    return "c"


def style_navy(land, x, y, frame, gv):
    """D: floating island over a dark navy void."""
    if land[y][x]:
        return grass_pixel(x, y, gv)
    k = depth_below_land(land, x, y, 7)
    if 1 <= k <= 7:
        if k == 1:
            return "G"
        if k <= 3:
            return "b"
        if k <= 5:
            return "d"
        return "D" if (x + k) % 2 == 0 else "N"
    if (x * 5 + y * 11) % 37 == 0:
        return "S"
    return "N"


STYLES = {
    "sea": style_sea,
    "forest": style_forest,
    "parchment": style_parchment,
    "navy": style_navy,
}


def dual_atlas(style, frame=0):
    """4x4 atlas of the 16 dual-grid tiles for one animation frame."""
    out = px.blank(4 * T, 4 * T)
    for idx in range(16):
        tile = render_dual(idx, STYLES[style], frame)
        px.paste(out, tile, (idx % 4) * T, (idx // 4) * T)
    return out


def grass_variants():
    return [render_dual(15, style_sea, 0, v) for v in range(len(GRASS_TUFTS))]

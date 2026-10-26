"""Road tiles: 4-bit connection mask per road cell (N=1, E=2, S=4, W=8).
A loop never branches, so only 5 (N-S), 10 (E-W), 3, 6, 12, 9 (corners) occur;
the other masks still render so the strip can be indexed by mask directly."""
import math

import ground
import px

T = 16
P0, P1 = 4, 11  # the path covers columns/rows P0..P1 (8 px) of the cell
R_OUT = 4       # radius of the outside of a bend
R_IN = 2        # fillet on the inside of a bend

PEBBLES = [(6, 6), (9, 9), (5, 10), (10, 5), (7, 13), (13, 7), (7, 2), (2, 7)]


def on_path(mask, x, y):
    """Path membership in cell coordinates; x, y may be -1..16 (just outside the
    cell) so rims are not drawn where the road continues into the next cell."""
    n, e, s, w = (mask >> 0) & 1, (mask >> 1) & 1, (mask >> 2) & 1, (mask >> 3) & 1
    inx = P0 <= x <= P1
    iny = P0 <= y <= P1
    if inx and iny:
        # outer corners of a bend / dead end are rounded
        for (cx, cy, sx, sy, active) in ((P0, P0, 1, 1, not n and not w), (P1, P0, -1, 1, not n and not e),
                                         (P0, P1, 1, -1, not s and not w), (P1, P1, -1, -1, not s and not e)):
            if not active:
                continue
            ax, ay = cx + sx * (R_OUT - 1), cy + sy * (R_OUT - 1)
            if (x - cx) * sx < R_OUT and (y - cy) * sy < R_OUT and math.hypot(x - ax, y - ay) > R_OUT - 0.5:
                return False
        return True
    if inx and ((n and y < P0) or (s and y > P1)):
        return True
    if iny and ((w and x < P0) or (e and x > P1)):
        return True
    # inner fillet where two arms meet
    for (cx, cy, sx, sy, active) in ((P0 - 1, P0 - 1, -1, -1, n and w), (P1 + 1, P0 - 1, 1, -1, n and e),
                                     (P0 - 1, P1 + 1, -1, 1, s and w), (P1 + 1, P1 + 1, 1, 1, s and e)):
        if not active:
            continue
        dx, dy = (x - cx) * sx, (y - cy) * sy
        if 0 <= dx < R_IN and 0 <= dy < R_IN:
            ax, ay = cx + sx * R_IN, cy + sy * R_IN
            if math.hypot(x - ax, y - ay) > R_IN - 0.2:
                return True
    return False


def road_tile(mask):
    c = px.Canvas(T, T)
    for y in range(T):
        for x in range(T):
            if not on_path(mask, x, y):
                # grass; the bank just above/left of the path is a little darker
                if on_path(mask, x, y + 1) or on_path(mask, x + 1, y):
                    c.set(x, y, "G")
                else:
                    c.set(x, y, ground.grass_pixel(x + 8, y + 8, 3))
                continue
            if not on_path(mask, x, y - 1) or not on_path(mask, x - 1, y):
                c.set(x, y, "o")   # shade under the top/left bank
            elif not on_path(mask, x, y + 1) or not on_path(mask, x + 1, y):
                c.set(x, y, "c")   # lit lower/right edge
            else:
                c.set(x, y, "t")
    for (x, y) in PEBBLES:
        if c.get(x, y) == "t" and c.get(x, y + 1) == "t" and c.get(x + 1, y) == "t":
            c.set(x, y, "c")
            c.set(x, y + 1, "b")
    return c.image()


def road_strip():
    return [road_tile(m) for m in range(16)]

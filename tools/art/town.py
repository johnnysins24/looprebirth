"""Town overlays: dual-grid tiles over the cells of the biggest building group.

Same index rule as tiles/land.png, but a bit is set when that cell belongs to the
town (TL=1, TR=2, BL=4, BR=8; atlas 4x4, tile (index % 4, index // 4)).

- town_ground: cobblestones under a tier-2 town. Ground pass, after the road.
- town_fence:  wooden fence on the border of a tier-1 village.
- town_wall:   stone wall on the border of a tier-2 town, a tower on every outer corner.

Fence and wall stand on the border line and hang down (their south face), so a
tile only depends on its own 4 cells. Draw them in the y-sorted pass with the
sort key = y of the tile centre + 1: a house in the cell above the line is drawn
first, a house below it later.
"""
import ground
import px
from px import S

T = 16


def halves(index):
    """Which half-segments of the border meet at the tile centre."""
    tl, tr, bl, br = ground.cells_of(index)
    return {
        "N": tl != tr,
        "S": bl != br,
        "W": tl != bl,
        "E": tr != br,
    }


def _extent(h):
    """x range of the horizontal border and y range of the vertical border, in a
    48x48 canvas whose middle 16x16 is the tile (segments run off the tile so
    the outline is the same on both sides of a tile edge)."""
    xs = [x for x in range(48) if (h["W"] and x <= 24) or (h["E"] and x >= 24)]
    ys = [y for y in range(48) if (h["N"] and y <= 24) or (h["S"] and y >= 24)]
    return xs, ys


# ---------------------------------------------------------------- fence

def fence_tile(index):
    h = halves(index)
    if not any(h.values()):
        return px.blank(T, T)
    c = px.Canvas(48, 48)
    xs, ys = _extent(h)
    by = 24  # border line (tile y = 8)
    # horizontal fence: two rails, a post every 4 px
    for x in xs:
        c.set(x, by + 1, "b")
        c.set(x, by + 3, "b")
        if x % 4 == 0:
            c.set(x, by - 1, "c")
            for y in range(by, by + 4):
                c.set(x, y, "b")
            c.set(x, by + 4, "d")
    # vertical fence seen from the south: a rail with post caps
    for y in ys:
        c.set(24, y, "b" if y % 4 else "c")
    corner = (h["N"] or h["S"]) and (h["W"] or h["E"])
    if corner:
        for y in range(by - 1, by + 5):
            c.set(24, y, "b")
        c.set(24, by - 1, "c")
        c.set(24, by + 4, "d")
    im = px.outline(c.image(), "D")
    return px.crop(im, 16, 16, T, T)


# ---------------------------------------------------------------- wall

WALL_FACE = 4  # rows of south face under the top of the wall

TOWER = S("""
...kkkkk...
..kwkwkwk..
.klwlwlwlk.
.kllllllsk.
.kNlllllNk.
.ksssssSSk.
.ksskkkSSk.
.kssk.kSSk.
.kSSSSSSSk.
.kSSSSSSnk.
..knnnnnk..
...kkkkk...
""")

PENNANT = S("""
kk..
kxek
kek.
k...
""")


def wall_tile(index):
    h = halves(index)
    if not any(h.values()):
        return px.blank(T, T)
    c = px.Canvas(48, 48)
    xs, ys = _extent(h)
    by = 24
    horiz = h["W"] or h["E"]
    vert = h["N"] or h["S"]
    hx = list(xs)
    if horiz and vert:
        hx = sorted(set(hx) | {22, 23, 24, 25})
    # top of a horizontal wall (2 rows) with merlons, then the brick face
    for x in hx:
        if x % 4 in (0, 1):
            c.set(x, by - 2, "w" if x % 4 == 0 else "l")
        c.set(x, by - 1, "l")
        c.set(x, by, "s")
        for k in range(1, WALL_FACE + 1):
            y = by + k
            mortar = (k == 2) or (k < 2 and x % 4 == 0) or (k > 2 and x % 4 == 2)
            c.set(x, y, "S" if mortar else ("s" if k < WALL_FACE else "S"))
    # vertical wall seen from above: walkway between two rows of merlons
    for y in ys:
        if horiz and by - 2 <= y <= by + WALL_FACE:
            continue
        up = y % 4 in (0, 1)
        c.set(22, y, "w" if up else "S")
        c.set(23, y, "l")
        c.set(24, y, "s")
        c.set(25, y, "l" if up else "S")
    im = px.outline(c.image(), "N")
    tl, tr, bl, br = ground.cells_of(index)
    n = tl + tr + bl + br
    diag = index in (6, 9)
    if n == 1 or diag:
        px.paste(im, TOWER, 24 - 5, by - 5)
        px.paste(im, PENNANT, 24, by - 8)
    return px.crop(im, 16, 16, T, T)


# ---------------------------------------------------------------- ground

def cobble_pixel(x, y):
    """Cobblestones in 4x3 bricks, every other row offset by 2."""
    row, ry = divmod(y, 3)
    cx = (x + (2 if row % 2 else 0)) % 4
    if ry == 2 or cx == 3:
        return "S"
    if ry == 0 and cx == 0:
        return "l"
    return "s"


def ground_tile(index):
    land = ground.land_patch(index, r_convex=3, r_concave=2)
    c = px.Canvas(T, T)
    for y in range(T):
        for x in range(T):
            X, Y = x + T // 2, y + T // 2
            if not land[Y][X]:
                continue
            # one px of grass-shadow rim inside the town edge
            edge = any(not ground.is_land(land, X + dx, Y + dy) and 0 <= X + dx < 32 and 0 <= Y + dy < 32
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            c.set(x, y, "G" if edge else cobble_pixel(X, Y))
    return c.image()


def atlas(fn):
    out = px.blank(4 * T, 4 * T)
    for idx in range(16):
        px.paste(out, fn(idx), (idx % 4) * T, (idx // 4) * T)
    return out


ATLASES = {
    "town_ground": lambda: atlas(ground_tile),
    "town_fence": lambda: atlas(fence_tile),
    "town_wall": lambda: atlas(wall_tile),
}

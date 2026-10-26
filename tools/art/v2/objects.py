"""v2 map objects: 32x48 frames standing on a 32 px cell (bottom centre on y=45)."""

import numpy as np

import img
import pal
from sculpt import Scene
from terrain import _hash

W, H = 32, 48
GROUND = 45

LEAF = ["grass0", "grass1", "grass2", "grass3", "grass4", "grass5"]
BARK = ["wood1", "wood2", "wood3", "wood4"]
STONE = ["stone0", "stone1", "stone2", "stone3", "stone4", "stone5"]


def _notch(sc, mats, prob, seed):
    """Nibble the silhouette of the given materials for a leafy edge."""
    solid = sc.mat >= 0
    h, w = solid.shape
    edge = np.zeros_like(solid)
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        edge |= ~np.roll(np.roll(solid, dy, 0), dx, 1)
    edge &= solid & np.isin(sc.mat, mats)
    ys, xs = np.nonzero(edge)
    for x, y in zip(xs, ys):
        if _hash(int(x), int(y), seed) < prob:
            sc.mat[y, x] = -1
            sc.z[y, x] = -np.inf


def tree(seed=0, scale=1.0, dx=0.0):
    """Round broadleaf tree. The canopy is a cluster of shaded leaf clumps."""
    sc = Scene(W, H)
    bark = sc.material(BARK, contrast=1.4, line="wood0", edge="wood0")
    clumps = [  # x, y, z, r, light bias
        (16, 12, -2, 6.0, 0.18), (10, 16, 0, 5.5, 0.14), (22, 15.5, -1, 5.5, 0.0),
        (7, 22.5, 1, 5.0, 0.06), (16, 20, 2, 6.5, 0.08), (25, 22, 0, 5.0, -0.14),
        (10.5, 27.5, 3, 5.0, -0.06), (16.5, 28.5, 4, 5.5, -0.12), (22.5, 27, 3, 5.0, -0.22),
    ]
    sc.capsule((16, 44, 0), (15.5, 30, 0), 2.6, 2.0, bark)
    sc.capsule((16, 43, 1), (12.5, 45, 1), 1.6, 0.8, bark)
    sc.capsule((16, 43, 1), (19.5, 45, 1), 1.6, 0.8, bark)
    leaf_mats = []
    for i, (x, y, z, r, b) in enumerate(clumps):
        jx = (_hash(seed, i, 1) - 0.5) * 1.5
        jy = (_hash(seed, i, 2) - 0.5) * 1.5
        m = sc.material(LEAF, bias=b - 0.02, contrast=1.9, line="grass0", edge="ink1", spec="grass6", spec_at=0.975)
        leaf_mats.append(m)
        cx = 16 + (x - 16) * scale + dx + jx
        cy = 33 - (33 - y) * scale + jy
        sc.sphere(cx, cy, z, r * scale, m)
    _notch(sc, leaf_mats, 0.22, seed + 5)
    im = sc.render(outline="ink1", edge=1.1)
    px = im.load()
    leaf = [pal.c(c) for c in LEAF]
    for y in range(H):
        for x in range(W):
            c = px[x, y]
            if sc.mat[y, x] in leaf_mats and c in leaf:
                i = leaf.index(c)
                h = _hash(x, y, seed + 9)
                if h < 0.12 and i > 1:
                    px[x, y] = leaf[i - 1]  # leafy grain
                elif h > 0.94 and 1 < i < len(leaf) - 1:
                    px[x, y] = leaf[i + 1]
            elif sc.mat[y, x] == bark and c[3]:
                if (x + (y // 3)) % 3 == 0 and _hash(x, y, 77) < 0.7:
                    px[x, y] = pal.c("wood1")  # bark grooves
    # shade where the canopy meets the trunk
    for y in range(29, 34):
        for x in range(12, 21):
            if sc.mat[y, x] == bark:
                px[x, y] = pal.c("wood0" if y < 32 else "wood1")
    return im


def rock():
    """A mossy boulder with a smaller stone beside it."""
    sc = Scene(W, H)
    flat = lambda px, py: py < GROUND
    big = sc.material(STONE[:5], bias=-0.12, contrast=2.0, line="stone0", edge="ink1", facets=7, spec="stone5", spec_at=0.97)
    small = sc.material(STONE[:5], bias=-0.16, contrast=2.0, line="stone0", edge="ink1", facets=6)
    sc.ellipsoid(14.0, 36.5, 0.0, 9.5, 8.5, 9.0, big, clip=flat, rot=-8)
    sc.ellipsoid(24.5, 41.0, 2.0, 4.6, 3.6, 4.0, small, clip=flat)
    sc.ellipsoid(6.5, 43.0, 3.0, 2.4, 1.8, 2.0, small, clip=flat)
    im = sc.render(outline="ink1", edge=2.0)
    # moss where the stone faces up
    px = im.load()
    for y in range(H):
        for x in range(W):
            if sc.mat[y, x] < 0 or px[x, y][3] == 0:
                continue
            ny = sc.n[y, x, 1]
            if ny < -0.62 and _hash(x, y, 71) < 0.75:
                s = sc.n[y, x, 0]
                px[x, y] = pal.c("grass5" if s < -0.25 else "grass4" if s < 0.15 else "grass3")
    return im


def house():
    """Half-timbered cottage with a terracotta hip roof and a stone chimney."""
    c = img.Canvas(W, H)
    # --- walls and foundation
    c.rect(5, 30, 26, 41, "sand4")
    c.rect(16, 30, 26, 41, "sand4")
    for x in range(19, 27):
        for y in range(30, 42):
            if (x + y) % 7 == 0:
                c.set(x, y, "sand3")  # faint plaster texture on the side away from the light
    c.hline(5, 26, 30, "stone3")  # shadow under the eaves
    c.hline(5, 26, 31, "sand3")
    c.rect(5, 30, 6, 41, "wood2")  # corner posts
    c.rect(25, 30, 26, 41, "wood1")
    c.vline(5, 30, 41, "wood3")
    c.hline(5, 26, 32, "wood2")  # top plate
    c.hline(5, 26, 37, "wood2")  # mid rail
    c.hline(5, 26, 38, "wood1")
    c.rect(4, 42, 27, 44, "stone3")  # foundation stones
    for x in range(4, 28):
        c.set(x, 42, "stone4")
        if x % 4 == 1:
            c.set(x, 43, "stone2")
        if x % 4 == 3:
            c.set(x, 44, "stone2")
    c.hline(4, 27, 44, "stone2")
    # --- windows with flower boxes
    for wx in (8, 20):
        c.rect(wx - 1, 33, wx + 4, 37, "wood1")
        c.rect(wx, 34, wx + 3, 36, "blue2")
        c.set(wx, 34, "blue4")
        c.set(wx + 1, 34, "blue5")
        c.set(wx, 35, "blue4")
        c.vline(wx + 2, 34, 36, "wood1")
        c.hline(wx, wx + 3, 35, "wood1")
        c.set(wx + 3, 36, "blue1")
        c.rect(wx - 1, 38, wx + 4, 39, "wood3")
        c.hline(wx - 1, wx + 4, 39, "wood2")
        for k, col in enumerate(("grass4", "red4", "grass5", "pink3", "grass4", "red3")):
            c.set(wx - 1 + k, 37 if k % 2 else 38, col)
    # --- door, arched, with a step
    c.rect(12, 33, 19, 43, "wood1")
    c.rect(13, 35, 18, 43, "wood3")
    c.hline(14, 17, 34, "wood3")
    for x in (14, 16, 18):
        c.vline(x, 35, 43, "wood2")
    c.vline(13, 35, 43, "wood4")
    c.set(17, 39, "gold4")
    c.set(17, 40, "gold2")
    c.rect(11, 44, 20, 45, "stone4")
    c.hline(11, 20, 44, "stone5")
    # --- hip roof: front slope, lit west slope, shaded east slope
    c.poly([(2, 17), (9, 10), (9, 29), (2, 29)], "roof4")
    c.poly([(29, 17), (22, 10), (22, 29), (29, 29)], "roof2")
    c.poly([(9, 10), (22, 10), (29, 29), (2, 29)], "roof3")
    for y in range(12, 29, 3):  # tile courses
        for x in range(2, 30):
            if c.get(x, y)[3]:
                c.set(x, y, "roof1" if x > 22 else "roof2")
                if c.get(x, y - 1) == pal.c("roof3"):
                    c.set(x, y - 1, "roof3")
        for x in range(2 + (y // 3) % 2 * 2, 30, 4):  # joints, staggered
            for yy in (y + 1, y + 2):
                col = c.get(x, yy)
                if col == pal.c("roof3"):
                    c.set(x, yy, "roof2")
                elif col == pal.c("roof4"):
                    c.set(x, yy, "roof3")
            if c.get(x + 1, y + 1) == pal.c("roof3") and x < 16:
                c.set(x + 1, y + 1, "roof4")  # sunlit tile edge
    c.line(9, 10, 2, 17, "roof5")  # hips
    c.line(9, 10, 2, 28, "roof5")
    c.line(22, 10, 29, 28, "roof1")
    c.hline(9, 22, 10, "roof5")  # ridge cap
    c.hline(10, 21, 9, "roof4")
    c.hline(2, 29, 29, "roof1")  # fascia
    # --- chimney
    c.rect(20, 5, 23, 15, "stone3")
    c.vline(20, 5, 15, "stone4")
    c.vline(23, 5, 15, "stone2")
    c.hline(19, 24, 4, "stone5")
    c.hline(19, 24, 5, "stone4")
    c.set(21, 4, "ink0")
    c.set(22, 4, "ink0")
    for y in (8, 11, 14):
        c.hline(20, 23, y, "stone2")
    c.outline("ink1")
    return c.im


def _ellipse(cx, cy, rx, ry):
    """Pixels inside an axis-aligned ellipse, with their normalised distance."""
    out = []
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if d <= 1.0:
                out.append((x, y, d ** 0.5))
    return out


def campfire():
    """The hero's camp: crossed logs in a ring of stones, flames drawn separately so the game can animate them."""
    import math

    base = img.Canvas(W, H)
    # ring of stones around the fire pit
    for k in range(9):
        a = math.radians(200 + k * 40)
        sx, sy = 16 + 10.5 * math.cos(a), 40.5 + 4.2 * math.sin(a)
        front = math.sin(a) > 0.2
        rx, ry = (2.4, 1.8) if front else (1.9, 1.4)
        for x, y, d in _ellipse(sx, sy, rx, ry):
            lit = (x + 0.5 - sx) / rx + (y + 0.5 - sy) / ry
            base.set(x, y, "stone5" if lit < -0.9 else "stone4" if lit < 0.2 else "stone3" if lit < 1.0 else "stone2")
    # ash bed
    for x, y, d in _ellipse(16, 40.5, 7.5, 2.6):
        base.set(x, y, "dirt0" if d < 0.6 else "stone1")
    # two crossed logs
    for (x0, y0, x1, y1) in ((9, 42, 22, 37), (23, 42, 10, 37)):
        n = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(n + 1):
            t = i / n
            x, y = round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t)
            base.set(x, y - 1, "wood4")
            base.set(x, y, "wood3")
            base.set(x, y + 1, "wood2")
        base.set(x0, y0 - 1, "sand3")  # cut end of the log
        base.set(x0, y0, "sand2")
        base.set(x1, y1, "ink0")  # charred tip in the fire
    base.outline("ink1")
    fire = img.Canvas(W, H)
    fire.poly([(9.5, 39), (10.5, 34), (12.5, 31), (13.5, 27), (15.5, 21.5), (17.5, 27), (19, 29.5), (20.5, 25), (22.5, 31), (22.5, 39)], "red3")
    fire.poly([(11.5, 39), (12.5, 34), (14.5, 30), (15.5, 25.5), (17, 30), (19, 32), (20, 29), (21, 34), (20.5, 39)], "roof4")
    fire.poly([(13, 39), (14, 35), (15.5, 31), (17, 34), (18.5, 33.5), (19, 39)], "gold4")
    fire.poly([(14.5, 39), (15.5, 35.5), (16.5, 34.5), (17.5, 39)], "gold5")
    for x in range(9, 24):  # the bottom of the flames sits inside the logs
        for y in (38, 39):
            if fire.get(x, y)[3] and fire.get(x, y) == pal.c("red3"):
                fire.set(x, y, "red2")
    fire.outline("red1")
    for (x, y, col) in ((12, 22, "gold4"), (19, 19, "roof4"), (16, 16, "gold5"), (21, 23, "gold3")):
        fire.set(x, y, col)  # embers
    img.paste(base.im, fire.im, 0, 0)
    return base.im


def _tuft(c, cx, base, half, h, seed):
    """A solid clump of grass: jagged blade tips on top, lit from the left, dark at the roots."""
    ramp = ["grass2", "grass3", "grass4", "grass5", "grass6"]
    for x in range(int(cx - half), int(cx + half) + 1):
        u = (x + 0.5 - cx) / half
        if abs(u) > 1:
            continue
        tip = [1.0, 0.72, 0.9, 0.62, 0.95, 0.7][(x + seed) % 6]
        top = base - h * (1 - u * u) ** 0.5 * tip
        for y in range(int(top), base + 1):
            t = (base - y) / h  # 0 at the roots, ~1 at the tips
            k = 0 if t < 0.2 else 1 if t < 0.45 else 2 if t < 0.75 else 3
            if u < -0.35 and k < 4:
                k += 1  # the light comes from the left
            elif u > 0.45 and k > 0:
                k -= 1
            if y == int(top) and k < 4:
                k += 1  # bright blade tip
            c.set(x, y, ramp[min(k, 4)])


def meadow():
    """Wildflower patch: three overlapping clumps of tall grass with flowers on top."""
    c = img.Canvas(W, H)
    _tuft(c, 9, 44, 6.5, 10, 1)
    _tuft(c, 23, 44, 6.5, 9, 4)
    _tuft(c, 16, 44, 7.5, 14, 2)
    c.outline("ink1")
    flowers = [(8, 35, "pink"), (13, 37, "white"), (16, 31, "gold"), (20, 35, "pink"), (24, 36, "blue"),
               (11, 40, "gold"), (18, 40, "blue"), (26, 40, "white"), (5, 40, "white")]
    petals = {"pink": ("pink4", "pink3"), "white": ("white", "cool6"), "gold": ("gold5", "gold4"), "blue": ("blue5", "blue4")}
    for (x, y, kind) in flowers:
        lit, dark = petals[kind]
        for (dx, dy) in ((1, 0), (-1, 0), (0, -1), (0, 1)):
            c.set(x + dx, y + dy, lit)
        c.set(x + 1, y + 1, dark)
        c.set(x, y, "gold3" if kind != "gold" else "roof3")
    return c.im


def spring():
    """Small pond ringed with stones, a lily pad and reeds."""
    import math

    c = img.Canvas(W, H)
    cx, cy, rx, ry = 16, 39.5, 12.5, 5.5
    for x, y, d in _ellipse(cx, cy, rx, ry):
        c.set(x, y, "sea4")
    # water: shadowed far edge, light near edge, glints
    for x, y, d in _ellipse(cx, cy, rx - 2.5, ry - 1.8):
        top = y + 0.5 < cy - (ry - 2.6) * 0.25
        c.set(x, y, "sea3" if top else "sea4")
    for x, y, d in _ellipse(cx, cy, rx, ry):
        if d >= 0.78:
            a = math.atan2((y + 0.5 - cy) / ry, (x + 0.5 - cx) / rx)
            seg = int((math.degrees(a) + 360 + 12) // 30)
            gap = abs(((math.degrees(a) + 360 + 12) % 30) - 15) > 13.5
            front = math.sin(a) > 0.25
            col = "stone4" if (y + 0.5) < cy else "stone3"
            if d > 0.93 and front:
                col = "stone2"
            elif d < 0.86 and not front:
                col = "stone5"
            if gap:
                col = "stone1"
            if seg % 3 == 0 and col == "stone4":
                col = "stone5"
            c.set(x, y, col)
    for (x0, x1, y, col) in ((10, 14, 40, "sea5"), (17, 22, 41, "sea5"), (12, 13, 38, "sea6")):
        c.hline(x0, x1, y, col)
    c.set(20, 38, "white")
    c.set(21, 38, "sea7")
    # lily pad with a flower
    for x, y, d in _ellipse(21.5, 41.5, 2.6, 1.3):
        c.set(x, y, "grass5" if y < 41 else "grass4")
    c.set(23, 41, "sea4")
    c.set(20, 41, "pink4")
    # reeds at the back left
    for (x, top) in ((6, 31), (8, 29), (10, 32)):
        c.vline(x, top + 2, 37, "grass4")
        c.set(x, 36, "grass3")
        c.vline(x, top, top + 2, "wood2")
        c.set(x, top, "wood3")
    c.outline("ink1")
    return c.im


def shrine():
    """Small roadside shrine: stone plinth, red pillars, slate roof with gold ridge, a glow inside."""
    c = img.Canvas(W, H)
    # plinth and step
    c.rect(6, 40, 25, 44, "stone3")
    c.hline(6, 25, 40, "stone5")
    c.hline(6, 25, 41, "stone4")
    for x in range(7, 25, 4):
        c.vline(x, 42, 44, "stone2")
    c.rect(12, 43, 19, 45, "stone4")
    c.hline(12, 19, 43, "stone5")
    # back wall, altar, golden idol glowing
    c.rect(10, 29, 21, 39, "wood1")
    c.rect(11, 31, 20, 39, "wood0")
    for x, y, d in _ellipse(15.5, 35, 4.2, 4.2):
        if d > 0.55 and (x + y) % 2 == 0:
            c.set(x, y, "roof2")
    c.rect(14, 33, 17, 37, "gold3")
    c.rect(14, 33, 15, 35, "gold4")
    c.set(14, 33, "gold5")
    c.rect(15, 31, 16, 32, "gold4")
    c.set(15, 31, "gold5")
    c.hline(12, 19, 38, "wood3")
    c.hline(12, 19, 39, "wood2")
    # pillars
    for x in (8, 21):
        c.rect(x, 28, x + 2, 39, "red3")
        c.vline(x, 28, 39, "red4")
        c.vline(x + 2, 28, 39, "red2")
        c.hline(x - 1, x + 3, 39, "stone4")
    # beam
    c.rect(7, 27, 24, 28, "red2")
    c.hline(7, 24, 27, "gold3")
    # roof with upturned eaves
    c.poly([(2.5, 24), (6, 26.5), (26, 26.5), (29.5, 24), (27, 23), (21.5, 16.5), (10.5, 16.5), (5, 23)], "cool3")
    c.poly([(2.5, 24), (6, 26.5), (16, 26.5), (16, 16.5), (10.5, 16.5), (5, 23)], "cool4")
    for y in (19, 22, 25):
        for x in range(3, 30):
            if c.get(x, y) == pal.c("cool4"):
                c.set(x, y, "cool3")
            elif c.get(x, y) == pal.c("cool3"):
                c.set(x, y, "cool2")
    c.hline(5, 27, 26, "cool2")  # eave shadow line
    c.hline(10, 21, 16, "gold3")  # ridge
    c.hline(11, 20, 15, "gold4")
    for x in (9, 22):
        c.set(x, 15, "gold4")
        c.set(x, 14, "gold3")
    c.set(15, 14, "red4")
    c.set(16, 14, "red3")
    c.set(15, 13, "gold4")
    c.set(16, 13, "gold4")
    c.set(2, 23, "gold4")  # eave tips
    c.set(29, 23, "gold3")
    c.outline("ink1")
    return c.im


def fireball_art():
    """Card art for the Fireball skill: a 40 px comet."""
    import icons

    tmp = {}
    icons._orb(tmp, "fb", 40, 11.5, ("gold5", "gold4", "roof3", "red2"),
               spikes=[(27, 6, 3), (29, 8, 3), (26, 8, 2), (31, 11, 3), (23, 4, 3), (24, 6, 2), (33, 14, 3),
                       (20, 5, 3), (29, 11, 2), (27, 9, 2), (25, 7, 3), (32, 13, 2), (30, 9, 3), (22, 6, 2)],
               core=[(15, 15), (16, 15), (15, 16), (16, 16), (17, 15)])
    return tmp["fb"]


if __name__ == "__main__":
    import sys

    out = sys.argv[1] if len(sys.argv) > 1 else "objects.png"
    ims = [tree(), tree(3, 0.8, -1), rock(), house(), campfire(), meadow(), spring(), shrine()]
    small = img.row([img.under(i, img.checker(W, H, "grass4", "grass4")) for i in ims], gap=0)
    img.zoom(small, 2).save(out.replace(".png", "_2x.png"))
    for i in ims:
        print(img.bad_pixels(i)[:3])
    sheet = img.row([img.under(i, img.checker(W, H, "grass4", "grass5")) for i in ims], gap=2, pad=2, bg="cool2")
    img.zoom(sheet, 6).save(out)

"""Board helpers used only to render mockups: a loop generator that follows
docs/design/01-run.md and the island land mask agreed with the Godot side
(outer ring is sea, road >= 2 cells from the edge, land = road + inside of the
loop + Chebyshev distance <= ISLAND_RADIUS from the road)."""
import random

W, H = 22, 13
ISLAND_RADIUS = 3
DIRS4 = [(0, -1), (1, 0), (0, 1), (-1, 0)]


def rectangle_loop(x0, y0, w, h):
    cells = []
    for x in range(x0, x0 + w):
        cells.append((x, y0))
    for y in range(y0 + 1, y0 + h):
        cells.append((x0 + w - 1, y))
    for x in range(x0 + w - 2, x0 - 1, -1):
        cells.append((x, y0 + h - 1))
    for y in range(y0 + h - 2, y0, -1):
        cells.append((x0, y))
    return cells


def valid(loop):
    n = len(loop)
    if len(set(loop)) != n:
        return False
    index = {c: i for i, c in enumerate(loop)}
    for i, (x, y) in enumerate(loop):
        if not (2 <= x < W - 2 and 2 <= y < H - 2):
            return False
        nx, ny = loop[(i + 1) % n]
        if abs(nx - x) + abs(ny - y) != 1:
            return False
        for dx, dy in DIRS4:
            j = index.get((x + dx, y + dy))
            if j is not None and j not in ((i + 1) % n, (i - 1) % n):
                return False
    return True


def push(loop, rng):
    n = len(loop)
    i = rng.randrange(n)
    L = rng.randint(3, 7)
    seg = [loop[(i + t) % n] for t in range(L)]
    vx, vy = seg[1][0] - seg[0][0], seg[1][1] - seg[0][1]
    for a, b in zip(seg, seg[1:]):
        if (b[0] - a[0], b[1] - a[1]) != (vx, vy):
            return None
    d = rng.choice([(-vy, vx), (vy, -vx)])
    k = rng.choice([1, 1, 2])
    s0, s1 = seg[0], seg[-1]
    new = [s0]
    for t in range(1, k + 1):
        new.append((s0[0] + d[0] * t, s0[1] + d[1] * t))
    for c in seg[1:-1]:
        new.append((c[0] + d[0] * k, c[1] + d[1] * k))
    new.append((s1[0] + d[0] * k, s1[1] + d[1] * k))
    for t in range(k - 1, 0, -1):
        new.append((s1[0] + d[0] * t, s1[1] + d[1] * t))
    new.append(s1)
    rest = [loop[(i + L + t) % n] for t in range(n - L)]
    cand = new + rest
    # remove back-and-forth spurs a,b,a
    changed = True
    while changed:
        changed = False
        m = len(cand)
        for t in range(m):
            if cand[(t - 1) % m] == cand[(t + 1) % m]:
                cand = [c for u, c in enumerate(cand) if u not in (t, (t + 1) % m)]
                changed = True
                break
    return cand


def generate(seed, pushes=None):
    rng = random.Random(seed)
    loop = rectangle_loop(5, 3, 12, 6)
    target = pushes or rng.randint(30, 60)
    done = tries = 0
    while done < target and tries < 5000:
        tries += 1
        cand = push(loop, rng)
        if cand and valid(cand) and roadside_ok(cand):
            loop = cand
            done += 1
    # start the loop at the camp: the top-left-most cell
    camp = min(loop, key=lambda c: (c[1], c[0]))
    k = loop.index(camp)
    loop = loop[k:] + loop[:k]
    if not clockwise(loop):
        loop = [loop[0]] + loop[1:][::-1]
    return loop


def clockwise(loop):
    s = 0
    n = len(loop)
    for i in range(n):
        x0, y0 = loop[i]
        x1, y1 = loop[(i + 1) % n]
        s += (x1 - x0) * (y1 + y0)
    return s < 0


def roadside_ok(loop):
    road = set(loop)
    side = set()
    for (x, y) in loop:
        found = False
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                c = (x + dx, y + dy)
                if c not in road and 0 <= c[0] < W and 0 <= c[1] < H:
                    side.add(c)
                    found = True
        if not found:
            return False
    return len(side) >= 40


def interior(loop):
    road = set(loop)
    seen = set()
    stack = [(x, y) for x in range(W) for y in range(H) if x in (0, W - 1) or y in (0, H - 1)]
    while stack:
        c = stack.pop()
        if c in seen or c in road:
            continue
        if not (0 <= c[0] < W and 0 <= c[1] < H):
            continue
        seen.add(c)
        for dx, dy in DIRS4:
            stack.append((c[0] + dx, c[1] + dy))
    return {(x, y) for x in range(W) for y in range(H)} - seen - road


def cheb(loop):
    """Chebyshev distance from every board cell to the nearest road cell."""
    return {(x, y): min(max(abs(x - a), abs(y - b)) for a, b in loop)
            for x in range(W) for y in range(H)}


def noise(seed, x, y):
    h = (x * 374761393 + y * 668265263 + seed * 2246822519) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def land_mask(loop, radius=ISLAND_RADIUS, seed=0, organic=True):
    """Land = road + inside of the loop + cells near the road. With organic=True
    the outermost ring (distance == radius) is kept only where a seeded noise
    says so, then smoothed, which gives an irregular coastline."""
    inside = interior(loop)
    dist = cheb(loop)
    land = set()
    for c, d in dist.items():
        if c in inside or d < radius or (d == radius and (not organic or noise(seed, *c) < 0.6)):
            land.add(c)
    land = {(x, y) for (x, y) in land if 1 <= x < W - 1 and 1 <= y < H - 1}
    if organic:
        for _ in range(2):
            new = set(land)
            for x in range(1, W - 1):
                for y in range(1, H - 1):
                    if dist[(x, y)] < radius:
                        continue
                    n = sum((x + dx, y + dy) in land for dx, dy in DIRS4)
                    if (x, y) in land and n <= 1:
                        new.discard((x, y))
                    elif (x, y) not in land and n >= 3:
                        new.add((x, y))
            land = new
    return land


def road_mask(loop, i):
    """4-bit mask N=1 E=2 S=4 W=8 of the connections of loop cell i."""
    n = len(loop)
    x, y = loop[i]
    m = 0
    for (px, py) in (loop[(i - 1) % n], loop[(i + 1) % n]):
        dx, dy = px - x, py - y
        m |= {(0, -1): 1, (1, 0): 2, (0, 1): 4, (-1, 0): 8}[(dx, dy)]
    return m


if __name__ == "__main__":
    for seed in range(6):
        lp = generate(seed)
        land = land_mask(lp)
        print(seed, len(lp), "land", len(land), "sea", W * H - len(land))
        road = set(lp)
        for y in range(H):
            print("".join("#" if (x, y) in road else ("." if (x, y) in land else "~") for x in range(W)))

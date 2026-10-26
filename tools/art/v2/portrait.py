"""v2 hero portrait: 56x56 anime bust, turned a little to the left (toward the map)."""

import img
import pal

S = 56


DY = 2


def _d(pts):
    return [(x, y + DY) for x, y in pts]


def portrait():
    c = img.Canvas(S, S)
    # --- body: coat, shirt collar, scarf
    c.poly([(4, 56), (8, 49), (18, 45), (38, 45), (48, 49), (52, 56)], "blue3")
    c.poly([(30, 46), (38, 45), (48, 49), (52, 56), (36, 56)], "blue2")
    c.poly([(4, 56), (8, 49), (14, 47), (12, 56)], "blue4")
    c.poly([(20, 49), (28, 47), (36, 49), (30, 56), (24, 56)], "cool7")  # shirt
    c.poly([(28, 47), (36, 49), (30, 56)], "cool6")
    c.line(20, 49, 25, 56, "gold3")  # coat trims
    c.line(36, 49, 30, 56, "gold2")
    # neck
    c.poly([(22, 38), (33, 36), (34, 46), (23, 47)], "skin2")
    c.poly([(22, 38), (33, 36), (33, 40), (23, 42)], "skin1")
    # scarf wraps
    c.poly([(14, 44), (20, 41), (36, 40), (42, 43), (41, 48), (34, 50), (20, 50), (13, 48)], "red3")
    c.poly([(14, 44), (20, 41), (30, 41), (24, 44), (16, 46)], "red4")
    c.poly([(30, 45), (42, 43), (41, 48), (34, 50), (26, 50)], "red2")
    c.line(19, 47, 33, 46, "red2")  # fold
    c.line(36, 45, 40, 47, "red1")
    c.poly([(34, 49), (40, 48), (44, 54), (38, 56), (35, 52)], "red3")  # hanging end
    c.poly([(38, 49), (40, 48), (44, 54), (41, 55)], "red2")
    # --- hair behind the head
    c.poly(_d([(9, 30), (7, 18), (12, 8), (22, 3), (34, 3), (43, 9), (47, 19), (46, 31), (42, 38), (14, 38)]), "hair1")
    # --- face
    face = [(13, 20), (38, 18), (41, 26), (40, 33), (36, 38), (29, 43), (24, 45), (20, 43), (15, 37), (13, 30)]
    c.poly(_d(face), "skin3")
    c.poly(_d([(34, 20), (38, 18), (41, 26), (40, 33), (36, 38), (30, 42), (35, 33), (36, 26)]), "skin2")  # far cheek in shade
    c.poly(_d([(15, 37), (20, 43), (24, 45), (21, 45), (17, 42)]), "skin2")  # under the jaw
    # ear
    c.poly(_d([(39, 26), (43, 25), (44, 30), (41, 34), (39, 33)]), "skin2")
    c.line(41, 27 + DY, 41, 31 + DY, "skin1")
    # --- eyes, looking left toward the map
    eye_legend = {"O": "ink0", "V": "blue1", "b": "blue3", "B": "blue4", "L": "blue5", "w": "white", "W": "white", "x": "cool7", "D": "skin1"}
    near = [
        "...OOOOO..",
        ".OOOOOOOOO",
        "OVVVVVVxxO",
        ".VwwOOVWWO",
        ".bwOOObWx.",
        ".bbOOObW..",
        ".BbbbBBx..",
        "..LBBLw...",
        "..DDDD....",
    ]
    far = [
        "..OOOO.",
        "OOOOOOO",
        "OVVVVxO",
        ".VwOOWO",
        ".bOOObW",
        ".bbObbx",
        ".BbbBB.",
        "..LBL..",
        "..DDD..",
    ]
    c.stamp(14, 26 + DY, far, eye_legend)
    c.stamp(26, 26 + DY, near, eye_legend)
    # brow peeking under the bangs (near side)
    c.line(28, 23 + DY, 35, 22 + DY, "hair1")
    # nose and mouth
    c.set(23, 36 + DY, "skin1")
    c.set(22, 37 + DY, "skin1")
    c.set(23, 37 + DY, "skin2")
    c.line(22, 41 + DY, 25, 41 + DY, "skin1")
    c.set(23, 42 + DY, "skin4")
    # --- bangs and side locks over the face
    bangs = [
        [(11, 10), (22, 6), (20, 18), (17, 27), (14, 21)],
        [(16, 8), (27, 6), (25, 17), (23, 26), (19, 18)],
        [(22, 6), (33, 7), (30, 18), (27, 25), (25, 16)],
        [(28, 6), (40, 9), (36, 18), (33, 24), (31, 16)],
        [(34, 8), (45, 15), (42, 22), (38, 26), (37, 17)],
        [(9, 16), (15, 14), (15, 28), (13, 36), (10, 40), (10, 30)],  # front side lock
        [(40, 16), (46, 20), (46, 32), (44, 37), (42, 28)],  # back side lock
    ]
    bangs = [_d(b) for b in bangs]
    for i, b in enumerate(bangs):
        c.poly(b, "hair2")
    # light: top-left of each lock, shadow on the right edges
    for b in bangs:
        (ax, ay), (bx, by) = b[0], b[1]
        c.line(ax + 1, ay + 1, (ax + bx) // 2, (ay + by) // 2 + 1, "hair3")
    c.poly(_d([(12, 9), (22, 4), (34, 4), (43, 9), (38, 8), (28, 6), (18, 8)]), "hair3")  # crown
    c.line(13, 10 + DY, 21, 7 + DY, "hair4")  # shine band
    c.line(22, 7 + DY, 30, 6 + DY, "hair4")
    c.line(14, 12 + DY, 18, 10 + DY, "hair4")
    for b in bangs[:5]:  # a highlight strand down each lock
        (ax, ay), (tx, ty) = b[0], b[3]
        mx, my = (ax + b[1][0]) // 2, (ay + b[1][1]) // 2 + 2
        c.line(mx, my, (mx + tx) // 2, (my + ty) // 2, "hair3")
    for (x, y) in ((17, 27), (23, 26), (27, 25), (33, 24), (38, 26), (10, 40), (44, 37)):
        c.set(x, y + DY, "hair1")  # dark lock tips
    # spikes on top
    for tip in ([(14, 9), (13, 2), (19, 6)], [(21, 5), (27, 1), (28, 5)], [(30, 5), (38, 2), (36, 7)], [(38, 7), (46, 6), (43, 11)]):
        tip = _d(tip)
        c.poly(tip, "hair2")
        c.line(tip[0][0] + 1, tip[0][1] - 1, tip[1][0], tip[1][1] + 1, "hair3")
    # shadow the forehead under the bangs
    for x in range(12, 42):
        for y in range(14 + DY, 32 + DY):
            if c.get(x, y) == pal.c("skin3") and c.get(x, y - 1) in (pal.c("hair2"), pal.c("hair3"), pal.c("hair1")):
                c.set(x, y, "skin2")
    c.outline("ink1")
    return c.im


def framed(size=60):
    """Portrait in a slot-style frame with a soft blue backdrop."""
    import ui

    c = img.Canvas(size, size)
    ui.frame_box(c, 0, 0, size - 1, size - 1, fill="blue1", line="ink0", hi="blue2", k=2)
    for y in range(2, size - 2):
        for x in range(2, size - 2):
            d = ((x - size * 0.45) ** 2 + (y - size * 0.4) ** 2) ** 0.5
            if d < size * 0.36:
                c.set(x, y, "blue2")
            elif d < size * 0.42 and (x + y) % 2:
                c.set(x, y, "blue2")
    p = portrait()
    img.paste(c.im, p, (size - S) // 2, size - S - 2)
    ui.gold_corners(c, 1, 1, size - 2, size - 2, n=4)
    return c.im


if __name__ == "__main__":
    import sys

    out = sys.argv[1] if len(sys.argv) > 1 else "portrait.png"
    p = framed()
    print(img.bad_pixels(p)[:3])
    img.zoom(p, 8).save(out)

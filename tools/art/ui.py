"""UI kit: cards, panels, buttons, bars, slots, map overlays, cursor, portrait.

Style: warm dark-wood frames (D/d/b) holding cream paper (c/t) insets, so the
bright map stays the brightest thing on screen. Text on paper is D (#3e2731).
9-slice margins are listed in the manifest.
"""
import ground
import icons
import objects
import px
import road
from px import S

# ---------------------------------------------------------------- digits
# 3x5 pixel digits for level numbers and small counters drawn into sprites.
DIGITS = {
    "0": "www\nw.w\nw.w\nw.w\nwww",
    "1": ".w.\nww.\n.w.\n.w.\nwww",
    "2": "ww.\n..w\n.w.\nw..\nwww",
    "3": "ww.\n..w\n.w.\n..w\nww.",
    "4": "w.w\nw.w\nwww\n..w\n..w",
    "5": "www\nw..\nww.\n..w\nww.",
    "6": ".ww\nw..\nwww\nw.w\nwww",
    "7": "www\n..w\n.w.\n.w.\n.w.",
    "8": "www\nw.w\nwww\nw.w\nwww",
    "9": "www\nw.w\nwww\n..w\nww.",
    "x": "...\nw.w\n.w.\nw.w\n...",
    "+": "...\n.w.\nwww\n.w.\n...",
    "-": "...\n...\nwww\n...\n...",
    "/": "..w\n..w\n.w.\nw..\nw..",
    "%": "w.w\n..w\n.w.\nw..\nw.w",
}


def digit(ch, key="w", outline=None):
    im = S(DIGITS[ch].replace("w", key))
    if outline:
        big = px.blank(5, 7)
        px.paste(big, im, 1, 1)
        im = px.outline(big, outline, diagonal=True)
    return im


def text_digits(s, key="w", outline="k"):
    parts = [digit(c, key, outline) for c in s]
    if not parts:
        return px.blank(1, 1)
    step = 4
    im = px.blank(step * (len(parts) - 1) + parts[0].width, parts[0].height)
    for i, p in enumerate(parts):
        px.paste(im, p, i * step, 0)
    return im


# ---------------------------------------------------------------- cards

CARD_W, CARD_H = 32, 44

TYPE_COLORS = {
    # dark, mid, light
    "terrain": ("h", "G", "g"),
    "encounter": ("R", "e", "P"),
    "building": ("O", "y", "Y"),
    "special": ("p", "m", "P"),
    "skill": ("B", "u", "a"),
}

CARD_TYPES = {
    "rock": "terrain", "grove": "terrain", "meadow": "terrain", "spring": "terrain",
    "slime_nest": "encounter", "wolf_den": "encounter", "graveyard": "encounter", "bandit_camp": "encounter",
    "house": "building", "smithy": "building", "shrine": "special", "clear": "special",
}

SKILLS = ["fireball", "cleave", "heal", "haste", "mana_shield"]


def rounded_mask(w, h, r=2):
    m = [[True] * w for _ in range(h)]
    cut = {2: [(0, 0), (1, 0), (0, 1)], 1: [(0, 0)]}[r]
    for (x, y) in cut:
        for (X, Y) in ((x, y), (w - 1 - x, y), (x, h - 1 - y), (w - 1 - x, h - 1 - y)):
            m[Y][X] = False
    return m


def card_frame(ctype):
    dk, md, lt = TYPE_COLORS[ctype]
    c = px.Canvas(CARD_W, CARD_H)
    mask = rounded_mask(CARD_W, CARD_H)
    for y in range(CARD_H):
        for x in range(CARD_W):
            if mask[y][x]:
                c.set(x, y, md)
    # bevel: light top-left, dark bottom-right
    c.hline(2, CARD_W - 3, 1, lt)
    c.vline(1, 2, CARD_H - 3, lt)
    c.hline(2, CARD_W - 3, CARD_H - 2, dk)
    c.vline(CARD_W - 2, 2, CARD_H - 3, dk)
    # outline
    out = px.outline(c.image(), "k")
    c = px.Canvas(CARD_W, CARD_H)
    c.paste(out)
    for y in range(CARD_H):
        for x in range(CARD_W):
            edge = (x in (0, CARD_W - 1) or y in (0, CARD_H - 1))
            if edge and mask[y][x]:
                c.set(x, y, "k")
    for (x, y) in ((1, 1), (CARD_W - 2, 1), (1, CARD_H - 2), (CARD_W - 2, CARD_H - 2)):
        c.set(x, y, "k")
    # art window
    c.rect(3, 3, 26, 26, "k")
    # name plate
    # name plate: 24x9 inside, tall enough for a 6 px Thai font with tone marks
    c.rect(3, 30, 26, 11, "k")
    c.rect(4, 31, 24, 9, "c")
    return c.image()


def art_window(kind, sprite):
    """24x24 art window (inside the 1px border) for a card."""
    w, h = 24, 24
    c = px.Canvas(w, h)
    if kind == "road":
        tile = road.road_tile(5)
        for y in range(h):
            for x in range(w):
                c.set(x, y, "g")
        # a vertical piece of road behind the object
        for y in range(h):
            px.paste(c.im, px.crop(tile, 0, 0, 16, 1), 4, y)
    elif kind == "skill":
        for y in range(h):
            for x in range(w):
                c.set(x, y, "B" if y < 3 or y > 20 else "u")
    else:
        for y in range(h):
            for x in range(w):
                c.set(x, y, ground.grass_pixel(x, y, 1 if (y > 14) else 0))
    if sprite is not None:
        sx = (w - sprite.width) // 2
        sy = max(0, h - sprite.height - (1 if kind != "skill" else (h - sprite.height) // 2))
        c.paste(sprite, sx, sy)
    return c.image()


def level_badge(level, ctype=None):
    """7x9 amber tag with a dark 3x5 digit; pasted at (1, 0) on the card."""
    b = S("""
kkkkkkk
kYYYYYk
kyyyyyk
kyyyyyk
kyyyyyk
kyyyyyk
kyyyyyk
kOyyyOk
kk.k.kk
""")
    b = px.put(b, [(2, 8), (4, 8)], ".")
    b = px.put(b, [(3, 8)], "k")
    px.paste(b, digit(str(level), "k"), 2, 2)
    return b


CLEAR_ART = S("""
.......kk.......
......kllk......
.....klllsk.....
....klllsSk.....
...kllllsSk.....
..kkkkkkkkkk....
.....kdbk.......
.....kdbk.......
.....kdbk.......
.....kdbk.......
.....kddk.......
.....kkkk.......
................
..k.k.k.k.......
..s.l.s.l.......
................
""")


def card(card_id, level=1):
    ctype = CARD_TYPES.get(card_id, "skill")
    im = card_frame(ctype)
    if ctype == "skill":
        art = art_window("skill", icons.BIG["skill_" + card_id])
    elif card_id == "clear":
        art = art_window("grass", CLEAR_ART)
    else:
        spr = objects.CARD_OBJECTS[card_id](level)
        art = art_window("road" if ctype == "encounter" else "grass", spr)
    px.paste(im, art, 4, 4)
    px.paste(im, level_badge(level), 2, 0)
    t = icons.SMALL["type_" + ctype]
    px.paste(im, t, CARD_W - 11, 3)
    return im


def card_back():
    c = px.Canvas(CARD_W, CARD_H)
    mask = rounded_mask(CARD_W, CARD_H)
    for y in range(CARD_H):
        for x in range(CARD_W):
            if mask[y][x]:
                edge = x in (0, CARD_W - 1) or y in (0, CARD_H - 1)
                c.set(x, y, "k" if edge else ("N" if (x // 4 + y // 4) % 2 else "n"))
    for (x, y) in ((1, 1), (CARD_W - 2, 1), (1, CARD_H - 2), (CARD_W - 2, CARD_H - 2)):
        c.set(x, y, "k")
    c.frame(2, 2, CARD_W - 4, CARD_H - 4, "y")
    ring = S("""
....kkkk....
..kkyYYykk..
.kyykkkkyyk.
.kyk....kyk.
kyk......kyk
kyk......kyk
kyk......kyk
kyk......kyk
.kyk....kyk.
.kyykkkkyyk.
..kkyyyykk..
....kkkk....
""")
    c.paste(ring, 10, 16)
    c.paste(S("..Y..\n.YwY.\n..Y.."), 14, 8)
    return c.image()


# ---------------------------------------------------------------- panels

def nine(w, h, border, fill_fn):
    """Generic panel painter: border(x, y, w, h) -> key or None, then fill."""
    c = px.Canvas(w, h)
    for y in range(h):
        for x in range(w):
            k = border(x, y, w, h)
            if k is None:
                k = fill_fn(x, y)
            if k:
                c.set(x, y, k)
    return c.image()


def wood_border(x, y, w, h):
    corner = (x in (0, w - 1) and y in (0, h - 1))
    if corner:
        return "."
    if x == 0 or y == 0 or x == w - 1 or y == h - 1:
        return "k"
    if x == 1 or y == 1:
        return "b"
    if x == w - 2 or y == h - 2:
        return "D"
    return None


WOOD_BOARD = 6      # board height incl. seam; the 9-slice centre tiles every 32x30 px


def wood_fill(x, y):
    """Horizontal planks: dark seam, a lit top edge, sparse grain dashes."""
    board, r = divmod(y, WOOD_BOARD)
    if r == WOOD_BOARD - 1:
        return "D"
    joint = (board * 13) % 32
    if (x - joint) % 32 == 0:
        return "D"
    if r == 0 and (x - joint) % 32 in range(1, 4):
        return "b"
    seed = (board * 7 + x // 5) % 9
    if r == 1 + seed % 3 and (x + board * 3) % 5 < 3 and seed in (1, 4, 6):
        return "D"
    return "d"


def paper_border(x, y, w, h):
    corner = (x in (0, w - 1) and y in (0, h - 1))
    if corner:
        return "."
    if x == 0 or y == 0 or x == w - 1 or y == h - 1:
        return "D"
    if y == h - 2 or x == w - 2:
        return "t"
    return None


def panel_wood(w=24, h=24):
    return nine(w, h, wood_border, wood_fill)


def panel_paper(w=24, h=24):
    return nine(w, h, paper_border, lambda x, y: "c")


def panel_dark(w=24, h=24):
    """Tooltip / modal backing."""
    def border(x, y, w, h):
        if x in (0, w - 1) and y in (0, h - 1):
            return "."
        if x in (0, w - 1) or y in (0, h - 1):
            return "k"
        if x == 1 or y == 1:
            return "n"
        return None
    return nine(w, h, border, lambda x, y: "N")


def button(state):
    fill, top, bot = {
        "normal": ("y", "Y", "O"),
        "hover": ("Y", "w", "y"),
        "pressed": ("O", "y", "r"),
        "disabled": ("s", "l", "S"),
    }[state]

    def border(x, y, w, h):
        if x in (0, w - 1) and y in (0, h - 1):
            return "."
        if x in (0, w - 1) or y in (0, h - 1):
            return "k"
        if y == 1:
            return top
        if y == h - 2:
            return bot
        return None
    im = nine(16, 16, border, lambda x, y: fill)
    if state == "pressed":
        im = px.shift(px.crop(im, 0, 0, 16, 15), 0, 1, 16, 16)
        im = px.put(im, [(x, 0) for x in range(1, 15)], "k")
    return im


def bar_frame(w=48):
    """Bar background with frame; fill area is x 2..w-3, y 2..5."""
    c = px.Canvas(w, 8)
    for y in range(8):
        for x in range(w):
            if x in (0, w - 1) and y in (0, 7):
                continue
            c.set(x, y, "k" if x in (0, w - 1) or y in (0, 7) else ("D" if y < 2 or y > 5 or x < 2 or x > w - 3 else "D"))
    c.hline(1, w - 2, 1, "d")
    return c.image()


def bar_fill(kind, w=44):
    top, mid, low = {"hp": ("P", "e", "R"), "mana": ("a", "u", "B"), "xp": ("Y", "y", "O"),
                     "enemy": ("P", "e", "R"), "shield": ("w", "a", "u")}[kind]
    c = px.Canvas(w, 4)
    c.hline(0, w - 1, 0, top)
    c.hline(0, w - 1, 1, mid)
    c.hline(0, w - 1, 2, mid)
    c.hline(0, w - 1, 3, low)
    return c.image()


def slot(kind="normal"):
    edge, fill = {"normal": ("k", "t"), "hover": ("y", "t"), "common": ("s", "t"), "rare": ("u", "t"),
                  "epic": ("m", "t"), "skill": ("B", "t")}[kind]
    c = px.Canvas(20, 20)
    for y in range(20):
        for x in range(20):
            if x in (0, 19) and y in (0, 19):
                continue
            if x in (0, 19) or y in (0, 19):
                c.set(x, y, "D")
            elif x in (1, 18) or y in (1, 18):
                c.set(x, y, edge)
            elif y == 2 or x == 2:
                c.set(x, y, "b")
            else:
                c.set(x, y, fill)
    return c.image()


def notif_row(w=120, h=20):
    def border(x, y, w, h):
        if x in (0, w - 1) and y in (0, h - 1):
            return "."
        if x in (0, w - 1) or y in (0, h - 1):
            return "D"
        if y == h - 2:
            return "t"
        return None
    return nine(w, h, border, lambda x, y: "c")


# ---------------------------------------------------------------- map overlays

def corners(key, length=4):
    c = px.Canvas(16, 16)
    for i in range(length):
        for (x, y) in ((i, 0), (0, i), (15 - i, 0), (15, i), (i, 15), (0, 15 - i), (15 - i, 15), (15, 15 - i)):
            c.set(x, y, key)
    return c.image()


def cell_overlays():
    valid = corners("w")
    invalid = corners("x")
    merge = corners("Y", 6)
    px.paste(merge, S("""
..k..
.kYk.
kYYYk
.kYk.
.kYk.
.kkk.
"""), 11, 1)
    combo = corners("a", 5)
    px.paste(combo, S("""
.kk.kk.
kaakaak
kakkkak
.kk.kk.
"""), 9, 1)
    warn = corners("x", 6)
    px.paste(warn, S("""
.kkk.
kxxxk
kxwxk
kxwxk
kxxxk
kxwxk
.kkk.
"""), 11, 0)
    return [valid, invalid, merge, combo, warn]


def level_pips():
    """Overlay drawn on a placed card's cell to show its level (frame 0 = L1)."""
    pip = S(".k.\nkYk\n.k.")
    frames = []
    for level in (1, 2, 3):
        im = px.blank(16, 16)
        for i in range(level):
            px.paste(im, pip, 0 + i * 3, 13)
        frames.append(im)
    return frames


CURSOR = S("""
k...........
kk..........
kwk.........
kwwk........
kwwwk.......
kwwwwk......
kwwwwwk.....
kwwwwwwk....
kwwwwwwwk...
kwwwwkkkkk..
kwwkwk......
kwk.kwk.....
kk..kwk.....
.....kwk....
.....kkk....
""")

CURSOR_GRAB = S("""
..kk.kk.....
.kwwkwwkk...
.kwwkwwkwk..
kkwwwwwwwk..
kwkwwwwwwk..
kwwwwwwwwk..
.kwwwwwwwk..
..kwwwwwk...
...kwwwwk...
...kkkkkk...
""")

PORTRAIT = S("""
................................
................................
...........kkkkkkkk.............
.........kkyYYYYYyykk...........
........kyYYYYyyyyyyyk..........
.......kyYYyyyyyyyyyyyk.........
......kyYYyyyyyyyyyyyyOk........
......kyYyyyyyyyyyyyyyOk........
.....kyYyyyyyyyyyyyyyyOOk.......
.....kyyyyyyOyyyyyyOyyOOk.......
.....kOyyyyOffyyyyOffyyOk.......
.....kOyyyOffffyyOffffyOk.......
....kOOyyffffffffffffffyOk......
....kOyyfffffffffffffffyOk......
....kOyfffkkfffffffkkffyOk......
....kOyfffkkfffffffkkffyOk......
....kOyfffwkfffffffwkfffOk......
.....kOffffffffffffffffOk.......
.....kOfPPffffffffffPPfOk.......
......kffffffffFffffffFk........
.......kffffffkkkffffFk.........
........kFfffffffffFFk..........
.........kkFFFFFFFFkk...........
.......kkkeekkkkkkeeekkk........
.....kkeeeeeeeeeeeeeeeeekk......
....keeeReeeeeeeeeeeReeeeek.....
...kuuukReeeeeeeeeeeRkuuuuk.....
..kuuuuukRRRRRRRRRRRkuuuuuuk....
..kuuBuuukuuuuuuuuuukuuuBuuk....
..kuuBuuuukuuuuuuuukuuuuBuuk....
..kuuBuuuuukuuuuuukuuuuuBuuk....
..kkkkkkkkkkkkkkkkkkkkkkkkkk....
""")

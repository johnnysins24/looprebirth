"""v2 main-screen mockup and the v1/v2 comparison.

    python3 tools/art/v2/mockup.py [--fonts DIR] [--out DIR]

The screen is drawn at the v2 base resolution (960x540) and scaled x2 to 1920x1080; text
is drawn afterwards at x2 with Sarabun, the way Godot draws fonts over a scaled canvas.
Layout: top bar 960x32, map 704x416 (22x13 cells of 32) at (0, 32), side panel 256x416
at (704, 32), hand bar 960x92 at (0, 448).
"""

import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import enemies  # noqa: E402
import hero  # noqa: E402
import icons  # noqa: E402
import img  # noqa: E402
import objects  # noqa: E402
import pal  # noqa: E402
import portrait  # noqa: E402
import road  # noqa: E402
import terrain  # noqa: E402
import ui  # noqa: E402
from layout import board, island  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
Z = 2
VIEW = (960, 540)
T = 32
MAP = (0, 32, 704, 416)
SIDE = (704, 32, 256, 416)
HAND = (0, 448, 960, 92)
SHADOW = (18, 14, 28, 96)  # ink0 at ~38 %, drawn by the engine under everything that stands


# ---------------------------------------------------------------- map

def ground(loop, land, frame=0):
    out = img.new(board.W * T, board.H * T)
    cache = {}
    for j in range(board.H + 1):
        for i in range(board.W + 1):
            def L(cx, cy):
                return 1 if (cx, cy) in land else 0
            idx = L(i - 1, j - 1) | (L(i, j - 1) << 1) | (L(i - 1, j) << 2) | (L(i, j) << 3)
            v = terrain.pick_variant(i, j, idx)
            if (idx, v) not in cache:
                cache[(idx, v)] = terrain.land_tile(idx, frame, v)
            img.paste(out, cache[(idx, v)], i * T - T // 2, j * T - T // 2)
    for k, c in enumerate(loop):
        img.paste(out, road.road_tile(board.road_mask(loop, k)), c[0] * T, c[1] * T)
    return out


def shadow(im, cx, cy, rx, ry):
    layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
    px = layer.load()
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if 0 <= x < im.width and 0 <= y < im.height:
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                    px[x, y] = SHADOW
    im.alpha_composite(layer)


def slash():
    """A crescent sword trail for the hit, 28x28."""
    c = img.Canvas(28, 28)
    for y in range(28):
        for x in range(28):
            d1 = math.hypot(x + 0.5 - 6, y + 0.5 - 22)
            d2 = math.hypot(x + 0.5 - 2, y + 0.5 - 26)
            if d1 <= 19 and d2 > 19.5 and x > 4 and y < 24:
                c.set(x, y, "white" if d2 < 21 else "blue6" if d2 < 22.5 else "blue5")
    return c.im


SCENE = {
    # (sprite factory, cell); the frame's ground line (y=45) lands 3 px above the cell's bottom edge
    "objects": [
        (objects.campfire, (6, 3)),
        (lambda: objects.tree(0), (4, 6)), (lambda: objects.tree(3, 0.8, -1), (3, 7)),
        (lambda: objects.tree(5), (4, 8)), (lambda: objects.tree(7, 0.85), (3, 9)),
        (objects.rock, (8, 2)), (objects.rock, (17, 3)),
        (objects.house, (7, 4)), (objects.house, (8, 4)), (objects.house, (7, 5)),
        (objects.meadow, (11, 3)), (objects.shrine, (12, 3)), (objects.spring, (17, 7)),
        (objects.meadow, (13, 11)), (objects.meadow, (9, 8)),
        (lambda: objects.tree(11, 0.9), (2, 5)), (lambda: objects.tree(2), (15, 10)),
        (lambda: objects.tree(9, 0.8, 1), (17, 9)), (lambda: objects.tree(4, 0.9), (16, 10)),
        (objects.rock, (14, 2)), (objects.rock, (5, 10)), (objects.meadow, (10, 6)),
    ],
    "units": [
        (hero.side, (15, 4)),
        (enemies.wolf, (16, 4)), (lambda: enemies.wolf(True), (16, 5)),
        (enemies.slime, (12, 8)), (lambda: enemies.slime(True), (12, 9)),
    ],
}


def map_layer(frame=0):
    loop, land = island()
    base = ground(loop, land, frame)
    draw = []
    for kind in ("objects", "units"):
        for make, (i, j) in SCENE[kind]:
            draw.append((j, i, kind, make()))
    draw.sort(key=lambda d: (d[0], d[1]))
    for j, i, kind, spr in draw:
        foot = j * T + T - 3
        big = kind == "objects" and spr.getbbox()[3] - spr.getbbox()[1] > 30
        if kind == "units" or big:
            shadow(base, i * T + 17, foot - 1, 11 if big else 9, 3.5 if big else 3)
        img.paste(base, spr, i * T, foot - 45)
    # the hero's hit landing on the wolf
    img.paste(base, slash(), 16 * T - 2, 4 * T - 4)
    dmg = ui.digits("12", "gold5", "ink0")
    img.paste(base, img.zoom(dmg, 2), 16 * T + 10, 4 * T - 14)
    return base


# ---------------------------------------------------------------- screen

class Screen:
    def __init__(self, fonts):
        self.im = Image.new("RGBA", VIEW, pal.c("ink0"))
        self.texts = []
        self.fonts = fonts

    def paste(self, spr, x, y):
        img.paste(self.im, spr, x, y)

    def text(self, x, y, s, size=12, colour="cool7", bold=False, anchor="la", fit=None, shadow=True):
        self.texts.append((x, y, s, size, colour, bold, anchor, fit, shadow))

    def font(self, size, bold):
        key = (size, bold)
        if key not in self.fonts:
            path = os.path.join(self.fonts["dir"], "Sarabun-Bold.ttf" if bold else "Sarabun-Regular.ttf")
            self.fonts[key] = ImageFont.truetype(path, round(size * Z), layout_engine=ImageFont.Layout.RAQM)
        return self.fonts[key]

    def render(self):
        big = img.zoom(self.im, Z)
        d = ImageDraw.Draw(big)
        for (x, y, s, size, colour, bold, anchor, fit, shadow) in self.texts:
            f = self.font(size, bold)
            while fit and d.textlength(s, font=f) > fit * Z and size > 6:
                size -= 0.5
                f = self.font(size, bold)
            if shadow:
                d.text((x * Z + 2, y * Z + 2), s, font=f, fill=pal.c("ink0"), anchor=anchor)
            d.text((x * Z, y * Z), s, font=f, fill=pal.c(colour), anchor=anchor)
        return big


def top_bar(sc):
    c = img.Canvas(960, 32)
    c.rect(0, 0, 959, 31, "cool1")
    c.hline(0, 959, 0, "cool2")
    c.hline(0, 959, 29, "gold2")
    c.hline(0, 959, 30, "ink0")
    c.hline(0, 959, 31, "ink0")
    for x in range(0, 960, 2):
        c.set(x, 28, "cool0")
    sc.paste(c.im, 0, 0)
    x = 10
    for kind, ic, w, label in (("hp", "hp", 120, "86/120"), ("mana", "mana", 84, "18/30"), ("xp", "xp", 100, "Lv 4")):
        frac = {"hp": 86 / 120, "mana": 0.6, "xp": 0.45}[kind]
        sc.paste(icons.SMALL[ic], x, 7)
        sc.paste(ui.bar(w, 12, frac, kind, ticks=4 if kind == "hp" else 0), x + 20, 9)
        sc.text(x + 20 + w + 6, 14.5, label, 12, "cool7", True, anchor="lm")
        x += 20 + w + 6 + 58
    sc.paste(icons.SMALL["loop"], x + 6, 7)
    sc.text(x + 28, 14.5, "รอบ 3/10", 12, "cool7", True, anchor="lm")
    x += 104
    sc.paste(icons.SMALL["rp"], x, 7)
    sc.text(x + 22, 14.5, "12", 13, "gold4", True, anchor="lm")
    bx = 960 - 10 - 4 * 40 + 4
    for n, (label, state) in enumerate((("pause", "normal"), ("x1", "active"), ("x2", "normal"), ("x4", "normal"))):
        sc.paste(ui.button(36, 22, state), bx + n * 40, 4)
        if label == "pause":
            sc.paste(icons.SMALL["pause"], bx + n * 40 + 10, 7)
        else:
            sc.text(bx + n * 40 + 18, 14.5, label, 12, "white" if state == "active" else "cool6", True, anchor="mm")


def section(sc, x, y, w, title):
    sc.paste(ui.header(w, 16), x, y)
    sc.text(x + 10, y + 7, title, 11, "gold4", True, anchor="lm")


def side_panel(sc):
    x0, y0, w, h = SIDE
    sc.paste(ui.panel(w, h), x0, y0)
    # hero
    sc.paste(portrait.framed(60), x0 + 10, y0 + 10)
    sc.text(x0 + 80, y0 + 20, "ฮีโร่", 16, "white", True, anchor="lm")
    sc.text(x0 + w - 12, y0 + 20, "Lv 4", 14, "gold4", True, anchor="rm")
    for row, stats in enumerate(((("str", "8"), ("agi", "5"), ("int", "3")), (("atk", "14"), ("def", "3"), ("eva", "6%")))):
        for n, (st, val) in enumerate(stats):
            sx, sy = x0 + 80 + n * 56, y0 + 36 + row * 20
            sc.paste(icons.SMALL[st], sx, sy)
            sc.text(sx + 20, sy + 8, val, 12, "cool7" if row == 0 else "cool6", row == 0, anchor="lm")
    # skills
    y = y0 + 80
    section(sc, x0 + 8, y, w - 16, "สกิล")
    y += 22
    for n, sk in enumerate(("fireball", "cleave", None)):
        s = ui.slot(32, None, skill=True)
        img.paste(s, icons.BIG[sk] if sk else icons.SMALL["lock"], 4 if sk else 8, 4 if sk else 8)
        sc.paste(s, x0 + 12 + n * 38, y)
    sc.paste(icons.SMALL["ap"], x0 + 136, y + 8)
    sc.text(x0 + 158, y + 16, "AP 4", 12, "violet5", True, anchor="lm")
    # equipment
    y += 42
    section(sc, x0 + 8, y, w - 16, "ของสวมใส่")
    y += 22
    for n, (it, rar) in enumerate((("sword", "rare"), ("armor", "common"), ("amulet", "epic"), (None, None), (None, None))):
        s = ui.slot(32, rar)
        if it:
            img.paste(s, icons.BIG[it], 4, 4)
        sc.paste(s, x0 + 12 + n * 38, y)
    # notifications
    y += 44
    section(sc, x0 + 8, y, w - 16, "แจ้งเตือน (4)")
    y += 22
    rows = (("stat_up", "แต้มสถานะ", "+3 แต้ม ยังไม่ได้ลง"),
            ("card", "การ์ดรอบ", "เลือก 1 จาก 3"),
            ("chest", "ดาบเหล็ก", "หายาก · ATK +4"),
            ("village", "หมู่บ้านขึ้นขั้น", "เลือก perk 1 จาก 3"))
    for n, (ic, title, sub) in enumerate(rows):
        c = img.Canvas(w - 16, 36)
        ui.frame_box(c, 0, 0, w - 17, 35, fill="cool1", line="ink0", hi="cool2", k=2)
        if n == 0:
            c.vline(1, 3, 32, "gold4")  # unread marker
        box = c.im
        s = ui.slot(30)
        img.paste(s, icons.BIG[ic], 3, 3)
        img.paste(box, s, 4, 3)
        ry = y + n * 40
        sc.paste(box, x0 + 8, ry)
        sc.text(x0 + 48, ry + 11, title, 12, "white", True, anchor="lm")
        sc.text(x0 + 48, ry + 26, sub, 11, "cool6", anchor="lm")


HAND_CARDS = [
    ("ป่า", "terrain", 1, lambda: objects.tree(0)),
    ("หิน", "terrain", 1, objects.rock),
    ("ทุ่งดอกไม้", "terrain", 2, objects.meadow),
    ("รังสไลม์", "encounter", 1, enemies.slime),
    ("บ้าน", "building", 1, objects.house),
    ("ลูกไฟ", "skill", 1, objects.fireball_art),
    ("ถ้ำหมาป่า", "encounter", 1, enemies.wolf),
    ("บ่อน้ำ", "terrain", 1, objects.spring),
    ("ศาลเจ้า", "special", 1, objects.shrine),
]


def glow(card, colour="gold4"):
    """Selection ring: a 1 px outline in gold around the card."""
    out = img.new(card.width + 2, card.height + 2)
    img.paste(out, card, 1, 1)
    return img.outline(out, colour)


def hand_bar(sc):
    x0, y0, w, h = HAND
    c = img.Canvas(w, h)
    c.rect(0, 0, w - 1, h - 1, "cool1")
    c.hline(0, w - 1, 0, "ink0")
    c.hline(0, w - 1, 1, "gold2")
    c.hline(0, w - 1, 2, "cool2")
    sc.paste(c.im, x0, y0)
    hover = 2
    for n, (name, kind, lv, art) in enumerate(HAND_CARDS):
        cx = x0 + 8 + n * 68
        cy = y0 + 3 - (8 if n == hover else 0)
        card = ui.card(kind, lv, art())
        if n == hover:
            sc.paste(glow(card), cx - 1, cy - 1)
        else:
            sc.paste(card, cx, cy)
        px, py, pw, ph = ui.PLATE
        sc.text(cx + px + pw / 2, cy + py + ph / 2, name, 11, "white", True, anchor="mm", fit=pw - 4)
    # info box for the hovered card
    bx, by, bw, bh = x0 + 628, y0 + 8, 324, 78
    sc.paste(ui.panel(bw, bh, fill="cool0"), bx, by)
    name, kind, lv, _ = HAND_CARDS[hover]
    sc.text(bx + 12, by + 15, "%s  L%d" % (name, lv), 15, "white", True, anchor="lm")
    disc = ui.card_frame(kind).crop((ui.CARD_W - 14, 2, ui.CARD_W - 2, 14))
    sc.paste(disc, bx + bw - 24, by + 9)
    sc.text(bx + 12, by + 36, "เดินผ่านถนนข้างๆ ฟื้น 4 HP", 12, "cool7", anchor="lm")
    sc.text(bx + 12, by + 53, "วางข้างถนน · ลากทับใบเดิม = L3", 12, "cool6", anchor="lm")
    sc.text(bx + bw - 12, by + 66, "มือ 9/10", 11, "blue5", True, anchor="rm")


def screen(fonts):
    sc = Screen(fonts)
    sc.paste(map_layer(), MAP[0], MAP[1])
    top_bar(sc)
    side_panel(sc)
    hand_bar(sc)
    return sc.render()


# ---------------------------------------------------------------- comparison

def label_bar(w, h, text, font, colour="cool7", bg="cool1"):
    im = Image.new("RGBA", (w, h), pal.c(bg))
    ImageDraw.Draw(im).text((24, h / 2), text, font=font, fill=pal.c(colour), anchor="lm")
    return im


def compare(v1, v2, fonts):
    """Full screens side by side at half size, then the same battle corner at full size."""
    f = ImageFont.truetype(os.path.join(fonts["dir"], "Sarabun-Bold.ttf"), 30, layout_engine=ImageFont.Layout.RAQM)
    half1 = v1.resize((960, 540), Image.LANCZOS)
    half2 = v2.resize((960, 540), Image.LANCZOS)
    box = (760, 140, 1720, 680)  # the hero fighting the wolves and the top of the side panel
    crop1, crop2 = v1.crop(box), v2.crop(box)
    out = Image.new("RGBA", (1920, 60 + 540 + 60 + 540), pal.c("ink0"))
    out.paste(label_bar(960, 60, "v1 (เดิม)", f), (0, 0))
    out.paste(label_bar(960, 60, "v2 (ใหม่) · ละเอียด 2 เท่า แนว anime", f, "gold4"), (960, 0))
    out.paste(half1, (0, 60))
    out.paste(half2, (960, 60))
    out.paste(label_bar(1920, 60, "ซูมจุดเดียวกัน 100%", f), (0, 600))
    out.paste(crop1, (0, 660))
    out.paste(crop2, (960, 660))
    return out


def main():
    font_dir = os.path.join(ROOT, "assets", "art", "fonts")
    out_dir = os.path.join(ROOT, "docs", "art", "v2")
    if "--fonts" in sys.argv:
        font_dir = sys.argv[sys.argv.index("--fonts") + 1]
    if "--out" in sys.argv:
        out_dir = sys.argv[sys.argv.index("--out") + 1]
    fonts = {"dir": font_dir}
    os.makedirs(out_dir, exist_ok=True)
    v2 = screen(fonts)
    v2.save(os.path.join(out_dir, "mockup_v2.png"), optimize=True)
    v1_path = os.path.join(ROOT, "docs", "art", "mockup_sea.png")
    if os.path.exists(v1_path):
        v1 = Image.open(v1_path).convert("RGBA")
        compare(v1, v2, fonts).save(os.path.join(out_dir, "compare_v1_v2.png"), optimize=True)
    print("ok")


if __name__ == "__main__":
    main()

"""Full-screen mockups of the main screen, built only from the exported sprites' sources.

    python3 tools/art/mockup.py [--fonts DIR]

Writes docs/art/mockup_<background>.png (1920x1080, the 480x270 screen at x4 with
text drawn at x4 the way Godot's canvas_items stretch draws it) and
docs/art/town_growth.png. The layout follows src/ui/ui_theme.gd of the prototype:
top bar 16 px, map 352x208 at (0, 16), side panel 128x208, hand bar 480x46.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import board  # noqa: E402
import fx  # noqa: E402
import ground  # noqa: E402
import icons  # noqa: E402
import objects  # noqa: E402
import pal  # noqa: E402
import px  # noqa: E402
import road  # noqa: E402
import town  # noqa: E402
import ui  # noqa: E402
import units  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DOCS = os.path.join(ROOT, "docs", "art")
Z = 4
VIEW = (480, 270)
MAP = (0, 16, 352, 208)
SIDE = (352, 16, 128, 208)
HAND = (0, 224, 480, 46)
SEED = 13

STYLE_OF = {"sea": "sea", "grass": "forest", "parchment": "parchment", "navy": "navy"}


# ---------------------------------------------------------------- map

def ground_layer(loop, land, style, frame=0):
    W, H = board.W, board.H
    out = px.blank(W * 16, H * 16)
    st = ground.STYLES[style]
    cache = {}
    for j in range(H + 1):
        for i in range(W + 1):
            def L(cx, cy):
                return 1 if (cx, cy) in land else 0
            idx = L(i - 1, j - 1) | (L(i, j - 1) << 1) | (L(i - 1, j) << 2) | (L(i, j) << 3)
            v = (i * 7 + j * 13) % 4 if idx in (0, 15) else 0
            if (idx, v) not in cache:
                cache[(idx, v)] = ground.render_dual(idx, st, frame, v)
            px.paste(out, cache[(idx, v)], i * 16 - 8, j * 16 - 8)
    for k, c in enumerate(loop):
        px.paste(out, road.road_tile(board.road_mask(loop, k)), c[0] * 16, c[1] * 16)
    return out


def town_tiles(cells):
    tiles = []
    for j in range(board.H + 1):
        for i in range(board.W + 1):
            b = [(i - 1, j - 1) in cells, (i, j - 1) in cells, (i - 1, j) in cells, (i, j) in cells]
            idx = b[0] | b[1] << 1 | b[2] << 2 | b[3] << 3
            if idx:
                tiles.append((i, j, idx))
    return tiles


def unit_frame(sheet_anims, anim, n=0):
    sheet, anims = sheet_anims
    a = anims[anim]
    fw = 32 if sheet.width == 96 else 16
    return px.crop(sheet, (a["start"] + n) * fw, a["row"] * fw, fw, fw)


SCENE = {
    "camp": (6, 3),
    "objects": [  # (card, level, cell)
        ("rock", 1, (8, 2)), ("rock", 2, (17, 3)), ("grove", 2, (4, 6)), ("grove", 3, (4, 7)),
        ("grove", 1, (3, 8)), ("meadow", 2, (11, 3)), ("shrine", 1, (12, 3)), ("spring", 1, (17, 7)),
        ("meadow", 1, (13, 11)), ("slime_nest", 2, (13, 4)), ("wolf_den", 1, (16, 6)),
        ("graveyard", 3, (12, 9)), ("bandit_camp", 1, (8, 10)),
    ],
    "town": {(7, 4): ("house", 1), (8, 4): ("house", 2), (7, 5): ("house", 1), (8, 5): ("smithy", 1)},
    "event": (10, 10),
}


def map_layer(style, tier=1, town_cells=None, frame=0):
    loop = board.generate(SEED, pushes=6)
    land = board.land_mask(loop, 3, seed=SEED)
    base = ground_layer(loop, land, style, frame)
    town_map = town_cells if town_cells is not None else SCENE["town"]
    cells = set(town_map)
    tiles = town_tiles(cells) if tier else []
    if tier >= 2:
        for i, j, idx in tiles:
            px.paste(base, town.ground_tile(idx), i * 16 - 8, j * 16 - 8)
    camp = objects.camp_frames()[frame % 4]
    cx, cy = SCENE["camp"]
    px.paste(base, camp, cx * 16, cy * 16 - 8)
    draw = []  # (sort_y, order, sprite, x, y)

    def obj(spr, cell, order=0):
        draw.append(((cell[1] + 1) * 16, order, spr, cell[0] * 16, cell[1] * 16 - 8))

    for cid, level, cell in SCENE["objects"]:
        obj(objects.CARD_OBJECTS[cid](level), cell)
    for cell, (cid, level) in town_map.items():
        if cid == "house" and tier >= 2:
            spr = objects.house_town(level)
        else:
            spr = objects.CARD_OBJECTS[cid](level)
        obj(spr, cell)
    ex, ey = SCENE["event"]
    obj(objects.event_frames()[frame % 4], (ex, ey))
    if tier:
        fn = town.wall_tile if tier >= 2 else town.fence_tile
        for i, j, idx in tiles:
            draw.append((j * 16 + 1, 1, fn(idx), i * 16 - 8, j * 16 - 8))

    hero = units.hero()

    def unit(spr, cell, dx=0, order=2):
        x = cell[0] * 16 + (16 - spr.width) // 2 + dx
        y = cell[1] * 16 + 16 - spr.height
        draw.append(((cell[1] + 1) * 16, order - 1, units.SHADOW, cell[0] * 16 + dx, cell[1] * 16))
        draw.append(((cell[1] + 1) * 16, order, spr, x, y))

    unit(unit_frame(hero, "attack_right", 1), (15, 4))
    wolf = units.enemy("wolf")
    unit(px.flip_h(unit_frame(wolf, "hurt")), (16, 4))
    unit(px.flip_h(unit_frame(wolf, "idle", 1)), (16, 5))
    slime = units.enemy("slime")
    unit(unit_frame(slime, "idle", 0), (13, 4))
    unit(unit_frame(slime, "idle", 1), (14, 4))
    skel = units.enemy("skeleton")
    skel_e = units.enemy("skeleton", elite=True)
    unit(unit_frame(skel, "idle", 0), (12, 8))
    unit(unit_frame(skel_e, "idle", 1), (12, 9))
    draw.append((10 * 16 - 1, 5, units.CROWN, 12 * 16 + 5, 9 * 16 - 4))
    bandit = units.enemy("bandit")
    unit(unit_frame(bandit, "idle", 0), (9, 10))
    draw.sort(key=lambda d: (d[0], d[1]))
    for _, _, spr, x, y in draw:
        px.paste(base, spr, x, y)
    # battle fx over the wolf being hit
    px.paste(base, fx.slash()[1], 16 * 16 - 2, 4 * 16 - 2)
    px.paste(base, fx.hit()[1], 16 * 16 + 2, 4 * 16 + 1)
    px.paste(base, ui.text_digits("12", "w", "k"), 16 * 16 + 4, 4 * 16 - 8)
    return base


# ---------------------------------------------------------------- ui

def nine_slice(im, m, w, h):
    """Stretch a 9-slice sprite with margins m (left, top, right, bottom) by repeating."""
    l, t, r, b = m
    out = px.blank(w, h)
    sw, sh = im.width, im.height
    cw, ch = sw - l - r, sh - t - b

    def src_x(x):
        if x < l:
            return x
        if x >= w - r:
            return sw - (w - x)
        return l + (x - l) % cw

    def src_y(y):
        if y < t:
            return y
        if y >= h - b:
            return sh - (h - y)
        return t + (y - t) % ch

    sp = im.load()
    op = out.load()
    for y in range(h):
        for x in range(w):
            op[x, y] = sp[src_x(x), src_y(y)]
    return out


class Screen:
    def __init__(self, fonts):
        self.im = px.blank(*VIEW, "k")
        self.texts = []  # (x, y, text, size, key, bold, anchor)
        self.fonts = fonts

    def paste(self, spr, x, y):
        px.paste(self.im, spr, x, y)

    def text(self, x, y, s, size=7, key="w", bold=False, anchor="la"):
        self.texts.append((x, y, s, size, key, bold, anchor))

    def render(self):
        big = self.im.resize((VIEW[0] * Z, VIEW[1] * Z), Image.NEAREST)
        d = ImageDraw.Draw(big)
        for (x, y, s, size, key, bold, anchor) in self.texts:
            f = self.fonts.get((size, bold))
            if f is None:
                path = os.path.join(self.fonts["dir"], "Sarabun-Bold.ttf" if bold else "Sarabun-Regular.ttf")
                f = ImageFont.truetype(path, size * Z, layout_engine=ImageFont.Layout.RAQM)
                self.fonts[(size, bold)] = f
            d.text((x * Z, y * Z), s, font=f, fill=pal.KEY[key], anchor=anchor)
        return big


def top_bar(sc):
    sc.paste(ui.panel_wood(480, 16), 0, 0)
    x = 4
    for kind, w, label, frac in (("hp", 64, "86/120", 0.72), ("mana", 40, "18/30", 0.6), ("xp", 52, "Lv 4", 0.45)):
        sc.paste(icons.SMALL[{"hp": "hp", "mana": "mana", "xp": "xp"}[kind]], x, 4)
        bar = ui.bar_frame(w)
        px.paste(bar, ui.bar_fill(kind, int((w - 4) * frac)), 2, 2)
        sc.paste(bar, x + 10, 4)
        sc.text(x + 10 + w + 3, 8, label, 6, "c", anchor="lm")
        x += 10 + w + 3 + (22 if kind != "xp" else 16)
    sc.paste(icons.SMALL["lap"], x, 4)
    sc.text(x + 10, 8, "รอบ 3/10", 6, "c", anchor="lm")
    x += 46
    sc.paste(icons.SMALL["rp"], x, 4)
    sc.text(x + 10, 8, "12", 6, "Y", True, anchor="lm")
    bx = 480 - 4 * 20 - 3
    for n, (label, state) in enumerate((("pause", "normal"), ("x1", "pressed"), ("x2", "normal"), ("x4", "normal"))):
        btn = nine_slice(ui.button(state), (3, 3, 3, 3), 19, 13)
        sc.paste(btn, bx + n * 20, 1 + (1 if state == "pressed" else 0) - (1 if state == "pressed" else 0))
        if label == "pause":
            sc.paste(icons.SMALL["pause"], bx + n * 20 + 6, 3 + 0)
        else:
            sc.text(bx + n * 20 + 9.5, 7.5 + (1 if state == "pressed" else 0), label, 6, "D", True, anchor="mm")


def side_panel(sc):
    x0, y0, w, h = SIDE
    sc.paste(ui.panel_wood(w, h), x0, y0)
    # hero card
    paper = ui.panel_paper(w - 8, 44)
    sc.paste(paper, x0 + 4, y0 + 4)
    portrait = px.blank(34, 34, "D")
    px.paste(portrait, px.blank(32, 32, "u"), 1, 1)
    px.paste(portrait, ui.PORTRAIT, 1, 1)
    sc.paste(portrait, x0 + 7, y0 + 7)
    sc.text(x0 + 45, y0 + 7, "ฮีโร่", 7, "D", True)
    sc.text(x0 + w - 8, y0 + 7, "Lv 4", 7, "R", True, anchor="ra")
    for n, (st, val) in enumerate((("str", "8"), ("agi", "5"), ("int", "3"))):
        sx = x0 + 45 + n * 25
        sc.paste(icons.SMALL[st], sx, y0 + 21)
        sc.text(sx + 10, y0 + 25, val, 7, "D", True, anchor="lm")
    for n, (st, val) in enumerate((("atk", "14"), ("def", "3"), ("evasion", "6%"))):
        sx = x0 + 45 + n * 25
        sc.paste(icons.SMALL[st], sx, y0 + 33)
        sc.text(sx + 10, y0 + 37, val, 6, "d", anchor="lm")
    # skills and equipment
    y = y0 + 52
    sc.text(x0 + 6, y, "สกิล", 6, "c", True)
    sc.text(x0 + 66, y, "ของสวมใส่", 6, "c", True)
    y += 9
    for n, sk in enumerate(("skill_fireball", "skill_cleave", None)):
        s = ui.slot("skill" if sk else "normal")
        if sk:
            px.paste(s, icons.BIG[sk], 2, 2)
        else:
            px.paste(s, icons.SMALL["lock"], 6, 6)
        sc.paste(s, x0 + 5 + n * 20, y)
    eq = (("item_weapon", "rare"), ("item_armor", "common"), ("item_amulet", "epic"))
    for n, (it, rar) in enumerate(eq):
        s = ui.slot(rar)
        px.paste(s, icons.BIG[it], 2, 2)
        sc.paste(s, x0 + 65 + n * 20, y)
    y += 20
    for n, it in enumerate((None, None)):
        s = ui.slot("normal")
        sc.paste(s, x0 + 65 + n * 20, y)
    sc.paste(icons.SMALL["ap"], x0 + 7, y + 6)
    sc.text(x0 + 17, y + 10, "AP 4", 6, "c", anchor="lm")
    # notifications
    y += 25
    sc.text(x0 + 6, y, "แจ้งเตือน (4)", 6, "c", True)
    y += 9
    rows = (("notif_stat_point", "แต้มสถานะ", "+3 แต้ม ยังไม่ได้ลง"),
            ("notif_lap_card", "การ์ดรอบ", "เลือก 1 จาก 3"),
            ("notif_item", "ดาบเหล็ก", "หายาก · ATK +4"),
            ("notif_town_perk", "หมู่บ้านขึ้นขั้น", "เลือก perk 1 จาก 3"))
    for n, (ic, title, sub) in enumerate(rows):
        r = ui.notif_row(w - 8, 20)
        px.paste(r, icons.BIG[ic], 2, 2)
        sc.paste(r, x0 + 4, y + n * 21)
        sc.text(x0 + 24, y + n * 21 + 2, title, 6, "D", True)
        sc.text(x0 + 24, y + n * 21 + 10, sub, 5, "d")


def hand_bar(sc):
    x0, y0, w, h = HAND
    sc.paste(ui.panel_wood(w, h), x0, y0)
    hand = [("grove", 1), ("rock", 1), ("meadow", 2), ("slime_nest", 1), ("house", 1), ("fireball", 1),
            ("wolf_den", 1), ("spring", 1), ("shrine", 1)]
    names = {"grove": "ป่า", "rock": "หิน", "meadow": "ทุ่งดอกไม้", "slime_nest": "รังสไลม์", "house": "บ้าน",
             "fireball": "ลูกไฟ", "wolf_den": "ถ้ำหมาป่า", "spring": "บ่อน้ำ", "shrine": "ศาลเจ้า"}
    hover = 2
    for n, (cid, lv) in enumerate(hand):
        cx = x0 + 3 + n * 34
        cy = y0 + 1 - (3 if n == hover else 0)
        sc.paste(ui.card(cid, lv), cx, cy)
        sc.text(cx + 16, cy + 37, names[cid], 4, "D", True, anchor="mm")
    box = ui.panel_paper(w - 346 - 3, h - 6)
    sc.paste(box, x0 + 346, y0 + 3)
    bx = x0 + 350
    sc.text(bx, y0 + 5, "ทุ่งดอกไม้ L2", 7, "D", True)
    sc.paste(icons.SMALL["type_terrain"], x0 + w - 14, y0 + 6)
    sc.text(bx, y0 + 16, "เดินผ่านถนนข้างๆ ฟื้น 4 HP", 6, "d")
    sc.text(bx, y0 + 24, "วางข้างถนน · ลากทับใบเดิม = L3", 6, "d")
    sc.text(bx, y0 + 33, "มือ 9/10", 6, "b", True)


def screen(style, fonts):
    sc = Screen(fonts)
    m = map_layer(style)
    sc.paste(m, MAP[0], MAP[1])
    top_bar(sc)
    side_panel(sc)
    hand_bar(sc)
    return sc


def town_growth(fonts):
    """Same village at tier 0, 1 and 2, cropped around the town."""
    cells = {(7, 4): ("house", 1), (8, 4): ("house", 2), (9, 4): ("house", 1), (7, 5): ("house", 1),
             (8, 5): ("smithy", 1), (7, 6): ("house", 2)}
    tiers = []
    for tier in (0, 1, 2):
        m = map_layer("sea", tier, cells)
        tiers.append(px.crop(m, 4 * 16, 1 * 16, 8 * 16, 7 * 16))
    w, h = tiers[0].size
    out = px.blank(w * 3 + 8, h + 14, "k")
    for n, t in enumerate(tiers):
        px.paste(out, t, n * (w + 4), 14)
    big = out.resize((out.width * Z, out.height * Z), Image.NEAREST)
    d = ImageDraw.Draw(big)
    f = ImageFont.truetype(os.path.join(fonts["dir"], "Sarabun-Bold.ttf"), 8 * Z, layout_engine=ImageFont.Layout.RAQM)
    for n, label in enumerate(("บ้านเดี่ยว (ขั้น 0)", "หมู่บ้าน มีรั้ว (ขั้น 1)", "เมือง กำแพง + หอ (ขั้น 2)")):
        d.text(((n * (w + 4) + w / 2) * Z, 7 * Z), label, font=f, fill=pal.KEY["c"], anchor="mm")
    return big


def main():
    font_dir = os.path.join(ROOT, "assets", "art", "fonts")
    if "--fonts" in sys.argv:
        font_dir = sys.argv[sys.argv.index("--fonts") + 1]
    fonts = {"dir": font_dir}
    os.makedirs(DOCS, exist_ok=True)
    for bg, style in STYLE_OF.items():
        out = screen(style, fonts).render()
        out.save(os.path.join(DOCS, "mockup_%s.png" % bg), optimize=True)
    town_growth(fonts).save(os.path.join(DOCS, "town_growth.png"), optimize=True)
    print("ok")


if __name__ == "__main__":
    main()

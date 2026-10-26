"""Units: the hero, the four wild enemies (+ elite palette swaps) and the boss.

Frames are 16x16 (boss 32x32), anchored bottom-centre: the feet sit on the
last pixel row. Enemies face LEFT (towards the hero walking into them); flip
them when they stand to the hero's left.
"""
import px
from px import S

# ---------------------------------------------------------------- hero parts
# Upper bodies are rows 0-13; legs (rows 14-15) are added per frame.

HERO_DOWN = S("""
................
......kkkkk.....
....kkyYYyykk...
...kyYYyyyyyyk..
..kyYyyyyyyyyOk.
..kOyyyyOyyyOOk.
.kOOyffffffyOOk.
.kOyfkffffkfyOk.
..kOfkffffkfOk..
...kkffffffkk...
..kkeeeeeeeekk..
.kuukReeeeRkuuk.
.kuBkuuuuuukBuk.
.kfkkdddyddkkfk.
""")

HERO_UP = S("""
................
.....kkkkkk.....
....kyYYYyyk....
...kyYYyyyyyk...
..kyYyyyyyyyOk..
..kyyyyyyyyyOk..
.kOyyyyyyyyyOOk.
.kOyyyyyyyyyyOk.
..kOyyyyyyyyOk..
...kkOOOOOOkk...
..kkeeeeeeeekk..
.kuukeeeeeekuuk.
.kuBkuuReuukBuk.
.kfkkddddddkkfk.
""")

HERO_RIGHT = S("""
................
....kkkkkk......
...kyYYYyykk....
..kyYYyyyyyyk...
.kyYyyyyyyyyyk..
.kOyyyyyyOyyOk..
.kOyyyyyyffOfk..
.kOOyyyyfkffk...
..kOOyyyfkffk...
...kkOyfffFk....
..kkeeeekkk.....
.kReekuuuuk.....
.kRk.kuuufk.....
.kk..kdddyk.....
""")

# second scarf pose, used on stride frames so the scarf flutters
HERO_RIGHT_B = S("""
................
....kkkkkk......
...kyYYYyykk....
..kyYYyyyyyyk...
.kyYyyyyyyyyyk..
.kOyyyyyyOyyOk..
.kOyyyyyyffOfk..
.kOOyyyyfkffk...
..kOOyyyfkffk...
...kkOyfffFk....
.kkeeeeekkk.....
kReekkuuuuk.....
kkk..kuuufk.....
.....kdddyk.....
""")

LEGS_FRONT = {
    "stand": S("""
....knnkknnk....
....kddkkddk....
"""),
    "a": S("""
....knnkkddk....
....kddk.kk.....
"""),
    "b": S("""
....kddkknnk....
.....kk.kddk....
"""),
}

LEGS_SIDE = {
    "stand": S("""
.....knkknk.....
.....kdkkdk.....
"""),
    "a": S("""
....knkknnk.....
...kddk.kddk....
"""),
    "b": S("""
.....kknnk......
......kddk......
"""),
}

# sword pointing right: grip, guard, blade, tip (outlined)
SWORD_R = S("""
.ykkkkk.
dyllllwk
.ykkkkk.
""")
SWORD_L = px.flip_h(SWORD_R)
SWORD_UP = px.rot90(SWORD_R, 1)
SWORD_DOWN = px.rot90(SWORD_R, 3)

SPARK = S("""
..Y..
.YwY.
YwwwY
.YwY.
..Y..
""")


def hero_body(upper, legs):
    im = px.blank(16, 16)
    px.paste(im, upper, 0, 0)
    px.paste(im, legs, 0, 14)
    return im


def closed_eyes_front(im, dy=0):
    im = px.put(im, [(5, 7 + dy), (10, 7 + dy)], "f")
    return px.put(im, [(4, 8 + dy), (5, 8 + dy), (10, 8 + dy), (11, 8 + dy)], "k")


def closed_eye_side(im):
    im = px.put(im, [(9, 7)], "f")
    return px.put(im, [(8, 8), (9, 8)], "k")


def hero():
    d_stand = hero_body(HERO_DOWN, LEGS_FRONT["stand"])
    u_stand = hero_body(HERO_UP, LEGS_FRONT["stand"])
    r_stand = hero_body(HERO_RIGHT, LEGS_SIDE["stand"])

    walk_down = [d_stand, hero_body(HERO_DOWN, LEGS_FRONT["a"]), d_stand, hero_body(HERO_DOWN, LEGS_FRONT["b"])]
    walk_up = [u_stand, hero_body(HERO_UP, LEGS_FRONT["b"]), u_stand, hero_body(HERO_UP, LEGS_FRONT["a"])]
    walk_right = [r_stand, hero_body(HERO_RIGHT_B, LEGS_SIDE["a"]),
                  hero_body(HERO_RIGHT, LEGS_SIDE["b"]), hero_body(HERO_RIGHT_B, LEGS_SIDE["a"])]

    # attacks: windup, strike, recover
    def with_sword(base, sword, x, y, behind=False):
        im = base.copy()
        if behind:
            px.under(im, sword, x, y)
        else:
            px.paste(im, sword, x, y)
        return im

    atk_right = [
        with_sword(px.shift(r_stand, -1, 0), SWORD_UP, 11, 3),
        with_sword(px.shift(hero_body(HERO_RIGHT_B, LEGS_SIDE["a"]), 1, 0), SWORD_R, 8, 10),
        with_sword(r_stand, SWORD_R, 7, 12),
    ]
    atk_down = [
        with_sword(px.shift(d_stand, 0, -1), SWORD_UP, 12, 1),
        with_sword(px.shift(d_stand, 0, 1), SWORD_DOWN, 9, 8),
        with_sword(d_stand, SWORD_R, 9, 12),
    ]
    atk_up = [
        with_sword(px.shift(u_stand, 0, 1), SWORD_DOWN, 12, 7, behind=True),
        with_sword(px.shift(u_stand, 0, -1), SWORD_UP, 12, 0, behind=True),
        with_sword(u_stand, SWORD_R, 9, 12, behind=True),
    ]

    hurt_down = closed_eyes_front(px.shift(d_stand, 0, 1), 1)
    hurt_right = closed_eye_side(r_stand)
    hurt_right = px.shift(hurt_right, -1, 0)
    hurt_up = px.shift(u_stand, 0, 1)

    def cast(base, hand, spark):
        im = px.put(base, [hand], "f")
        px.paste(im, SPARK, *spark)
        return im

    cast_down = cast(d_stand, (13, 9), (11, 4))
    cast_right = cast(r_stand, (12, 10), (11, 6))
    cast_up = cast(u_stand, (13, 9), (11, 4))

    ko_a = closed_eyes_front(px.band(d_stand, 0, 13, 0, 2), 2)
    ko_a = px.band(ko_a, 15, 15, 0, 0)  # keep boots
    stars = S("""
.Y.....Y.
YwY...YwY
.Y.....Y.
""")
    ko_b = ko_a.copy()
    px.paste(ko_a, stars, 3, 0)
    px.paste(ko_b, px.flip_h(stars), 4, 1)
    victory = with_sword(d_stand, SWORD_UP, 12, 0)
    victory = px.put(victory, [(13, 9), (13, 10)], "f")

    left = lambda seq: [px.flip_h(f) for f in seq]
    rows = [
        ("walk_down", walk_down, 8, True),
        ("walk_left", left(walk_right), 8, True),
        ("walk_right", walk_right, 8, True),
        ("walk_up", walk_up, 8, True),
        ("attack_down", atk_down + [hurt_down], 10, False),
        ("attack_left", left(atk_right) + [px.flip_h(hurt_right)], 10, False),
        ("attack_right", atk_right + [hurt_right], 10, False),
        ("attack_up", atk_up + [hurt_up], 10, False),
        ("cast", [cast_down, px.flip_h(cast_right), cast_right, cast_up], 1, False),
        ("ko", [ko_a, ko_b, victory], 4, True),
    ]
    anims = {}
    sheet_rows = []
    for r, (name, frames, fps, loop) in enumerate(rows):
        sheet_rows.append(frames)
        if name.startswith("attack"):
            d = name.split("_")[1]
            anims[name] = dict(row=r, start=0, frames=3, fps=fps, loop=False)
            anims["hurt_" + d] = dict(row=r, start=3, frames=1, fps=1, loop=False)
        elif name == "cast":
            for i, d in enumerate(["down", "left", "right", "up"]):
                anims["cast_" + d] = dict(row=r, start=i, frames=1, fps=1, loop=False)
        elif name == "ko":
            anims["ko"] = dict(row=r, start=0, frames=2, fps=fps, loop=True)
            anims["victory"] = dict(row=r, start=2, frames=1, fps=1, loop=False)
        else:
            anims[name] = dict(row=r, start=0, frames=4, fps=fps, loop=loop)
    return px.sheet(sheet_rows, fw=16, fh=16), anims


# ---------------------------------------------------------------- enemies

SLIME = S("""
................
................
................
................
................
.......kkkk.....
.....kkauuukk...
....kauwauuuuk..
...kaaauuuuuuuk.
...kauuuuuuuuuk.
..kakkuukkuuuuBk
..kukwuukwuuuuBk
..kukkuukkuuuBBk
..kuuuuuuuuuuBBk
...kBuuuuuuuBBk.
....kkkkkkkkkk..
""")

WOLF = S("""
................
................
................
...k.k..........
..kSkSk.......k.
..kssSk......ksk
.klsYssk....kssk
kllsksssk..ksslk
kklsssssskkksssk
.kkllssssssssSk.
..kkllsssSSSSSk.
...kllsSSSSSSnk.
...kSnkkkkkSnnk.
...kSnk...kSnk..
..kSnk....kSnk..
..kkk.....kkk...
""")

WOLF_BITE = S("""
................
................
................
..kk.kk.........
.kSskSsk......k.
.kssssSk.....ksk
klsYssssk...kslk
lllssssssk.kssk.
kkllssssssksssk.
.kkllssssssssk..
..klllssssSSSk..
..kllsSSSSSSnk..
..kSnkkkkkkSnk..
..kSnk...kSnnk..
.kSnk.....kSnk..
.kkk......kkkk..
""")

SKELETON = S("""
................
.....kkkkk......
....kcwccck.....
...kcwccccck....
...kckkckkck....
...kckkckkck....
....kcccccck....
.....kckckk.....
..kk..kcck......
.kbbkkcwcckk....
kbyobkcckcktk...
kbobkkcwcckctk..
.kbbkkcckckkctk.
..kk.kcckck..kk.
....kck.kck.....
...kkk..kkkk....
""")

SKELETON_RAISE = S("""
................
.....kkkkk......
....kcwccck.....
...kcwccccck....
...kckkckkck....
...kckkckkck....
....kcccccck....
.....kckckk..kk.
..kk..kcck..kok.
.kbbkkcwckk.kok.
kbyobkcckckkcok.
kbobkkcwcckcckk.
.kbbkkcckcckkk..
..kk.kcckck.....
....kck.kck.....
...kkk..kkkk....
""")

BANDIT = S("""
................
.....kkkkk......
....kRRRRRk.....
...kReeeeeRk....
...kRRRRRRRk....
...kFfkfkfFk....
...kRRRRRRRk....
....kRReRRk.....
...kkdbbbbdkk...
..kFkdbbbbdkFk..
.klkkdbyybdkkk..
.kk.kddddddk....
....kdddkddk....
....knnk.knnk...
....knnk.knnk...
...kkkk..kkkk...
""")

DAGGER_L = S("""
kkkk.
wllyd
kkkk.
""")


def enemy_frames(kind):
    if kind == "slime":
        base = SLIME
        idle = [base, px.band(base, 0, 9, 0, 1)]
        atk = [px.shift(px.band(base, 0, 9, 0, -1, keep=True), 1, 0), px.shift(px.band(base, 0, 10, 0, 1), -2, 0)]
        hurt = px.put(px.shift(base, 1, 0), [(5, 11), (5, 12), (9, 11), (9, 12)], "k")
        hurt = px.put(hurt, [(5, 11), (9, 11)], "w")
    elif kind == "wolf":
        idle = [WOLF, px.band(WOLF, 0, 9, 0, 1, 0, 8)]
        atk = [px.shift(WOLF, 1, 0), px.shift(WOLF_BITE, -2, 0)]
        hurt = px.put(px.shift(WOLF, 1, 0), [(5, 6)], "k")
    elif kind == "skeleton":
        idle = [SKELETON, px.band(SKELETON, 0, 6, 0, 1, 3, 11)]
        swing = px.shift(SKELETON, -1, 0)
        px.paste(swing, px.flip_h(S("""
.ykkkk.
dyooook
.ykkkk.
""")), 0, 9)
        atk = [SKELETON_RAISE, swing]
        hurt = px.band(px.shift(SKELETON, 1, 0), 1, 7, 1, 0)
    elif kind == "bandit":
        idle = [BANDIT, px.band(BANDIT, 0, 10, 0, 1)]
        raise_ = px.put(BANDIT, [(13, 7), (13, 8)], "l")
        raise_ = px.put(raise_, [(13, 9)], "y")
        lunge = px.shift(BANDIT, -2, 0)
        px.paste(lunge, DAGGER_L, 0, 9)
        atk = [raise_, lunge]
        hurt = px.put(px.shift(BANDIT, 1, 0), [(7, 5), (9, 5)], "F")
    else:
        raise ValueError(kind)
    return [idle, atk, [hurt]]


ELITE_SWAPS = {
    "slime": {"u": "m", "a": "P", "B": "p", "w": "w"},
    "wolf": {"s": "S", "S": "n", "n": "N", "l": "s", "Y": "x"},
    "skeleton": {"c": "t", "w": "c", "b": "p", "o": "m"},
    "bandit": {"R": "p", "e": "m", "d": "N", "b": "n"},
}

CROWN = S("""
k.kk.k.
kykyky.
kyyyyyk
.kkkkk.
""")


def enemy(kind, elite=False):
    rows = enemy_frames(kind)
    if elite:
        rows = [[px.recolor(f, ELITE_SWAPS[kind]) for f in r] for r in rows]
    anims = {
        "idle": dict(row=0, start=0, frames=2, fps=3, loop=True),
        "attack": dict(row=1, start=0, frames=2, fps=8, loop=False),
        "hurt": dict(row=2, start=0, frames=1, fps=1, loop=False),
    }
    return px.sheet(rows, fw=16, fh=16), anims


# ---------------------------------------------------------------- boss

BOSS = S("""
................................
...........kkkkkkkkkk...........
.........kkyYYYYYYYYykk.........
........kyYkkkkkkkkkkYyk........
.......kyYk..........kYyk.......
......kyyk..kkkkkkkk..kyyk......
......kyk..klllllllsk..kyk......
.....kyyk.kllwwlllllsk.kyyk.....
.....kyk.kllwlllllllssk.kyk.....
.....kyk.klkkkkkkkkkssk.kyk.....
.....kyk.klkaaakaaaksSk.kyk.....
.....kyk.klkkkkkkkkkSSk.kyk.....
.....kyyk.klllyylllSSk.kyyk.....
......kyk.kkssyyssSSkk.kyk......
...kkkkyykkyyyYYyyyykkyykkkk....
..klllkkyyyyyOOOOOyyyyykklllk...
.kllwlskkkkyOOyyOOykkkkslllsSk..
.klwllsSkpkkyyyyyykkpkSsllsSSk..
.klllsSSkppkkyyyyykkppkSSssSSk..
.kslsSSkmppmkkkkkkkmppmkSSSSnk..
..kSSSkpmppmmkaaakmmppmmkSSnk...
...kkkkpmmpmkaaaaakmpmmpkkkk....
......kppmmpkkaaakkpmmppk.......
......kpppmkksyyskkmpppk........
.......kpmkslssssslkmpk.........
.......kkkksllsSSsslkkk.........
........kllssSkkSssllk..........
........kssSSk..kSSssk..........
.......knSSSnk..knSSSnk.........
......kkknnnkk..kknnnkkk........
......kkkkkkk....kkkkkkk........
................................
""")


def boss():
    idle_b = px.recolor(px.band(BOSS, 1, 13, 0, 1), {"Y": "y", "y": "O"})
    idle = [BOSS, idle_b]
    # slam: fists up, fists down (body dips), recover
    up = px.band(BOSS, 14, 21, 0, -3, 0, 7)
    up = px.band(up, 14, 21, 0, -3, 22, 31)
    down = px.band(BOSS, 0, 27, 0, 2)
    down = px.band(down, 16, 23, -1, 5, 0, 8)
    down = px.band(down, 16, 23, 1, 5, 21, 31)
    hurt = px.recolor(px.shift(BOSS, 1, 0), {"a": "w", "y": "Y"})
    rows = [idle, [up, down, BOSS], [hurt]]
    anims = {
        "idle": dict(row=0, start=0, frames=2, fps=2, loop=True),
        "attack": dict(row=1, start=0, frames=3, fps=6, loop=False),
        "hurt": dict(row=2, start=0, frames=1, fps=1, loop=False),
    }
    return px.sheet(rows, fw=32, fh=32), anims


SHADOW = S("""
................
................
................
................
................
................
................
................
................
................
................
................
................
................
....bbbbbbbb....
.....bbbbbb.....
""")

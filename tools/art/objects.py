"""Map objects: what each card looks like once placed on the board.

Frames are 16x24 (3 per strip: L1, L2, L3). The bottom 16x16 is the cell;
up to 8 px may overhang into the cell above, so draw them y-sorted with the
anchor at the bottom-centre of the frame. Terrain and buildings stand on grass
(their small shadows are baked in dark green); encounters stand on the road.
"""
import px
from px import S

FW, FH = 16, 24


def frame(*layers):
    """layers: (sprite, x, y) pasted in order onto a 16x24 frame."""
    im = px.blank(FW, FH)
    for spr, x, y in layers:
        px.paste(im, spr, x, y)
    return im


# ---------------------------------------------------------------- trees

TREE = S("""
...HHHHH....
..HgggGGHH..
.HggggGGGGH.
HgggGGGGGGhH
HggGGGGGGhhH
HgGGGGGGhhhH
.HGGGGGhhhH.
.HhGGhhhhhH.
..HHhhhhHH..
....HdbH....
....HdbH....
...HHHHHH...
""")

TREE_S = S("""
..HHHH..
.HggGGH.
HggGGGhH
HgGGGhhH
.HGhhhH.
..HHHH..
...Hd...
..HHHH..
""")

GRASS_SHADOW = S("""
.GGGGGG.
GGGGGGGG
.GGGGGG.
""")


TREE_M = S("""
..HHHHH...
.HggGGGH..
HggGGGGhH.
HgGGGGhhH.
HGGGGhhhH.
.HhGhhhH..
..HHHHH...
...HdbH...
...HdbH...
..HHHHHH..
""")


def grove(level):
    if level == 1:
        return frame((GRASS_SHADOW, 5, 20), (TREE, 2, 10))
    if level == 2:
        return frame((GRASS_SHADOW, 7, 21), (TREE_M, 6, 9), (TREE, 0, 11))
    return frame((GRASS_SHADOW, 6, 21), (TREE_M, 0, 5), (TREE_M, 7, 4), (TREE, 3, 12))


# ---------------------------------------------------------------- rocks

ROCK_S = S("""
..nnnn..
.nlllsn.
nlllssSn
nlssSSSn
.nnSSnn.
""")

ROCK_M = S("""
...nnnnn...
..nllllsnn.
.nlllssssSn
nllssssSSSn
nlsssSSSSnn
nsSSSSSSnn.
.nnnnnnnn..
""")

ROCK_L = S("""
.....nnnnn......
...nnllllsnn....
..nlllwlssssn...
.nllllssssSSn...
.nllsssssSSSnn..
nlsssssSSSSSSSn.
nlssssSSSSSSSSn.
nssSSSSSSSSSnnn.
.nnnnnnnnnnnn...
""")

MOSS = S("""
gGG
.G.
""")

CRYSTAL = S("""
..k..
.kPk.
.kPek
kPeek
kPeRk
.kRk.
""")
CRYSTAL_S = S("""
.k.
kPk
kek
kRk
""")


def rock(level):
    if level == 1:
        return frame((GRASS_SHADOW, 6, 21), (ROCK_S, 4, 16), (S("nn\nSn"), 11, 20))
    if level == 2:
        return frame((GRASS_SHADOW, 5, 21), (ROCK_M, 2, 15), (ROCK_S, 9, 18))
    big = frame((GRASS_SHADOW, 5, 21), (ROCK_L, 0, 13), (MOSS, 5, 13))
    px.paste(big, CRYSTAL, 9, 9)
    px.paste(big, CRYSTAL_S, 13, 12)
    return big


# ---------------------------------------------------------------- meadow

def flower(key, stem=True):
    if stem:
        return S(f".{key}.\n{key}Y{key}\n.{key}.\n.G.") if key != "Y" else S(".Y.\nYOY\n.Y.\n.G.")
    return S(f".{key}.\n{key}Y{key}\n.{key}.")


TALL = S("""
G.G
GgG
.G.
""")


def meadow(level):
    im = frame()
    spots = {
        1: [("P", 3, 14), ("w", 9, 17), ("Y", 5, 19), ("P", 11, 12)],
        2: [("P", 2, 12), ("w", 8, 14), ("Y", 5, 18), ("P", 11, 18), ("w", 12, 10), ("e", 6, 9)],
        3: [("P", 1, 11), ("w", 6, 12), ("Y", 3, 17), ("P", 9, 17), ("w", 12, 13), ("e", 10, 8),
            ("Y", 7, 7), ("P", 13, 19), ("w", 0, 19)],
    }[level]
    tufts = {1: [(7, 11), (1, 18)], 2: [(0, 15), (10, 11), (13, 15)], 3: [(4, 14), (12, 9), (8, 19), (1, 7)]}[level]
    for x, y in tufts:
        px.paste(im, TALL, x, y)
    for key, x, y in spots:
        px.paste(im, flower(key), x, y)
    if level == 3:
        px.paste(im, S("a.a\n.k.\n"), 12, 3)   # butterfly
        px.paste(im, S("P.P\n.k."), 3, 4)
    return im


# ---------------------------------------------------------------- spring

POND_S = S("""
...ssss...
.sslllsss.
slBBBBBBls
sBuuuauuBs
sBuauuuuBs
.sBBuuBBs.
..ssssss..
""")

POND_M = S("""
....sssss....
..sslllllsss.
.slBBBBBBBBls
slBuuuuauuuBs
sBuuauuuuguBs
sBuuuuuuggPBs
.sBBuuuuuuBs.
..sssBBBBss..
....ssssss...
""")

POND_L = S("""
....ssssssss....
..sslllllllsss..
.slBBBBBBBBBBls.
slBuuuauuuuuuBls
sBuuauuuuauuuuBs
sBuguuuuuuuuauBs
sBggPuuuuuauuuBs
.sBuuuuuuuuuuBs.
..ssBBBBBBBBss..
....ssssssss....
""")

FOUNT = S("""
.a.a.
a.w.a
..a..
..a..
.lls.
nlssn
.nnn.
""")


def spring(level):
    if level == 1:
        return frame((POND_S, 3, 14))
    if level == 2:
        return frame((POND_M, 1, 13))
    im = frame((POND_L, 0, 12))
    px.paste(im, FOUNT, 9, 8)
    return im


# ---------------------------------------------------------------- buildings
# Village style (straw roofs) is used while the town is tier 0-1; once the
# town reaches tier 2 the code swaps to the *_town strips (terracotta roofs).

HOUSE_1 = S("""
....DDDDDD....
...DYYYYYyD...
..DYyyyyyyOD..
.DYyyyyyyyyOD.
DOOOOOOOOOOOOD
DDDDDDDDDDDDDD
.DccccccccttD.
.DcaacDDctttD.
.DcBacDdctttD.
.DccccDdctttD.
.DDDDDDDDDDDD.
""")

HOUSE_2 = S("""
.........DD...
....DDDDDDdD..
...DYYYYYDdD..
..DYyyyyyDdOD.
.DYyyyyyyyyyOD
DYyyyyyyyyyyyD
DOOOOOOOOOOOOD
DDDDDDDDDDDDDD
.DccccccccctD.
.DcaacDDcaatD.
.DcBacDdcBatD.
.DccccDdccttD.
.DDDDDDDDDDDD.
""")

HOUSE_3 = S("""
....DDDDDDDD....
...DYYYYYYYyD...
..DYyyyyyyyyOD..
.DYyyyyyyyyyyOD.
DOOOOOOOOOOOOOOD
DDDDDDDDDDDDDDDD
.DccccccccccctD.
.DcaacccccaactD.
.DcBacPgPcBactD.
.DDDDDDDDDDDDDD.
.DccccccccccctD.
.DcaacDDDcaactD.
.DcBacDddcBactD.
.DccccDddccctD..
.DDDDDDDDDDDDDD.
""")

TOWN_SWAP = {"Y": "o", "y": "r", "O": "R", "c": "c", "t": "t"}


def house(level, town=False):
    spr = {1: HOUSE_1, 2: HOUSE_2, 3: HOUSE_3}[level]
    if town:
        spr = px.recolor(spr, TOWN_SWAP)
        # timber frame and stone base for the town look
        spr = stone_base(spr)
    x = (FW - spr.width) // 2
    return frame((GRASS_SHADOW, 7, 21), (spr, x, FH - 1 - spr.height + 1 - 1))


def stone_base(spr):
    im = spr.copy()
    p = im.load()
    w, h = im.size
    # repaint the bottom wall row with stones
    for x in range(w):
        c = px.pal.RGBA_TO_KEY.get(p[x, h - 2])
        if c in ("c", "t"):
            p[x, h - 2] = px.pal.KEY["s" if x % 3 else "l"]
    return im


def house_town(level):
    return house(level, town=True)


SMITHY_1 = S("""
..........nn..
.........nSSn.
....nnnnnnSSn.
...nSSSSSSssn.
..nSssssssssSn
.nnnnnnnnnnnnn
.nssslslslssn.
.nslnOyOnslsn.
.nslnyYynlssn.
.nssnnnnnsssn.
.nnnnnnnnnnnn.
""")

SMITHY_2 = S("""
...........nn...
..........nSSn..
...nnnnnnnnSSn..
..nSSSSSSSSssn..
.nSssssssssssSn.
nSsssssssssssSSn
nnnnnnnnnnnnnnnn
.nssslslslslssn.
.nslnOyOnslnaan.
.nslnyYynlsnBan.
.nssnnnnnssssn..
.nnnnnnnnnnnnn..
""")

ANVIL = S("""
nnnnnn.
nlllsSn
.nnsnn.
..nSn..
.nnnnn.
""")

SMOKE = S("""
.ll.
lwwl
.ll.
""")


def smithy(level):
    if level == 1:
        return frame((GRASS_SHADOW, 7, 21), (SMITHY_1, 1, 12), (ANVIL, 10, 19))
    if level == 2:
        return frame((GRASS_SHADOW, 7, 21), (SMITHY_2, 0, 11), (SMOKE, 10, 8))
    im = frame((GRASS_SHADOW, 7, 21), (SMITHY_2, 0, 11), (SMOKE, 10, 8), (S(".l.\nlwl\n.l."), 12, 5))
    px.paste(im, ANVIL, 0, 19)
    px.paste(im, S("Y.Y\n.Y."), 2, 16)
    return im


SPIRIT_HOUSE = S("""
.....Y.....
....kyk....
...kyeyk...
..kyeeeyk..
.kyeeeeeyk.
kyyyyyyyyyk
.kRyyDyyRk.
.kRyDDDyRk.
.kRyDDDyRk.
kkkkkkkkkkk
.kccccccck.
....kck....
....kck....
....kck....
....kck....
...kkcckk..
..kttttttk.
..kkkkkkkk.
""")

def shrine(level):
    """Thai-style spirit house (san phra phum) on a pillar."""
    im = frame((GRASS_SHADOW, 6, 21), (SPIRIT_HOUSE, 2, 5))
    if level >= 2:
        # flower garlands under the eave and drink offerings at the foot
        px.paste(im, S("P.w.w.P"), 4, 11)
        px.paste(im, S("kk\nOk\nOk"), 1, 20)
        px.paste(im, S("kk\nek\nek"), 13, 20)
    if level == 3:
        im = px.recolor(im, {"c": "Y", "y": "Y"})
        px.paste(im, S("..w..\n.wYw.\n..w.."), 5, 0)
        px.paste(im, S(".Y.\nYwY\n.Y."), 0, 7)
        px.paste(im, S(".Y.\nYwY\n.Y."), 13, 10)
    return im


# ---------------------------------------------------------------- encounters
# These stand on road cells. They are drawn as a lair on the path; the enemies
# themselves spawn on the same cell.

GOO_1 = S("""
...aaaa......
.aauuuuaa....
auuuBuuuuaa..
.auuuuuuuuua.
..aaauuuuaa..
.....aaaa....
""")

GOO_2 = S("""
....aaaaa.....
..aauuuuuaa...
.auuuuBuuuuaa.
auuuBuuuuuuuua
auuuuuuuuBuuua
.aauuuuuuuuaa.
...aaaaaaaa...
""")

EGG = S("""
..kkk..
.kawak.
kaauuuk
kauBuuk
kauuuBk
.kkkkk.
""")

BUBBLE = S("""
.a.
awa
.a.
""")


def slime_nest(level):
    if level == 1:
        return frame((GOO_1, 2, 16), (BUBBLE, 4, 14), (S("a"), 11, 15))
    if level == 2:
        return frame((GOO_2, 1, 15), (EGG, 8, 11), (BUBBLE, 2, 13))
    # the elite egg sits at the back, two plain eggs overlap in front (no face-like symmetry)
    im = frame((GOO_2, 1, 15), (px.recolor(EGG, {"a": "P", "u": "m", "B": "p"}), 7, 9), (BUBBLE, 13, 8))
    px.paste(im, EGG, 1, 13)
    px.paste(im, EGG, 5, 14)
    px.paste(im, BUBBLE, 3, 9)
    return im


DEN = S("""
....nnnnnn....
..nnSSssSSnn..
.nSsslssssSSn.
nSsslkkkksSSSn
nSslkkkkkkSSSn
nSskkkkkkkkSnn
nnnkkkkkkkknn.
""")

BONES = S("""
c.....c
.cllll.
c.....c
""")

SKULL = S("""
.kkk.
kcwck
kkcck
.kck.
""")


def wolf_den(level):
    if level == 1:
        return frame((DEN, 1, 12), (BONES, 4, 20))
    im = frame((DEN, 1, 12), (BONES, 0, 20), (S("Y.Y"), 5, 15))
    if level == 3:
        px.paste(im, S("Y.Y"), 9, 16)
        px.paste(im, SKULL, 10, 19)
        px.paste(im, S("..nn\n.nSn\nnSSn"), 12, 9)
    return im


TOMB = S("""
.nnnn.
nllssn
nlsssn
nlnnsn
nlsssn
nnnnnn
dddddd
""")

CROSS = S("""
.nn.
nssn
.ns.
.ns.
dddd
""")

CANDLE = S("""
.y.
.Y.
kck
kck
""")

CRYPT = S("""
...nnnnnnn...
..nsssssssn..
.nlllllllssn.
nnnnnnnnnnnnn
.nlsnkkknlsn.
.nlsnkmknlsn.
.nlsnkkknssn.
nnnnnnnnnnnnn
""")


def graveyard(level):
    if level == 1:
        return frame((TOMB, 2, 15), (CROSS, 10, 17))
    if level == 2:
        return frame((TOMB, 1, 15), (TOMB, 9, 14), (CANDLE, 7, 19))
    im = frame((CRYPT, 2, 8), (TOMB, 0, 16), (CROSS, 12, 18), (CANDLE, 8, 19))
    px.paste(im, S(".m.\nmPm\n.m."), 12, 5)
    return im


TENT = S("""
.....k.....
....kek....
...keeRk...
..keeRRRk..
.keeRkkRRk.
keeeRkkRRRk
kkkkkkkkkkk
""")

FLAG = S("""
kee.
keee
kee.
k...
k...
k...
k...
""")

FIRE = S("""
..Y..
.YyY.
.yOy.
kdOdk
.kdk.
""")

STAKES = S("""
.k.k.k.k.k.k
kbkbkbkbkbkb
kbkbkbkbkbkb
kdkdkdkdkdkd
""")


def bandit_camp(level):
    if level == 1:
        return frame((TENT, 1, 14), (FLAG, 12, 13))
    if level == 2:
        return frame((TENT, 0, 13), (FLAG, 12, 9), (FIRE, 10, 18))
    im = frame((TENT, 5, 9), (TENT, 0, 13), (FLAG, 13, 6), (FIRE, 11, 16))
    px.paste(im, STAKES, 2, 20)
    return im


# ---------------------------------------------------------------- camp, event

CAMP_TENT = S("""
.....k.....
....kuk....
...kuuBk...
..kuuBBBk..
.kuuBkkBBk.
kuuuBkkBBBk
kkkkkkkkkkk
""")

BANNER = S("""
kyyy.
kyYy.
kyyy.
k.y..
k....
k....
k....
k....
""")

FLAMES = [
    S("..Y..\n.YyY.\n.yOy.\nkdOdk\n.kdk."),
    S(".Y...\n.YyY.\nYyOy.\nkdOdk\n.kdk."),
    S("...Y.\n.YyY.\n.yOyY\nkdOdk\n.kdk."),
    S("..Y..\n.yYy.\n.yOy.\nkdOdk\n.kdk."),
]


def camp_frames():
    frames = []
    for f in FLAMES:
        im = frame((CAMP_TENT, 0, 12), (BANNER, 11, 9), (f, 10, 18))
        frames.append(im)
    return frames


QMARK = S("""
.kkkk.
kyYYyk
kykkyk
.kkyyk
..kyk.
..kkk.
..kyk.
..kkk.
""")


def event_frames():
    out = []
    for dy in (0, -1, -2, -1):
        im = frame((S(".tt.\ntttt\n.tt."), 6, 20))
        px.paste(im, QMARK, 5, 10 + dy)
        out.append(im)
    return out


# ---------------------------------------------------------------- strips

CARD_OBJECTS = {
    "rock": rock, "grove": grove, "meadow": meadow, "spring": spring,
    "slime_nest": slime_nest, "wolf_den": wolf_den, "graveyard": graveyard, "bandit_camp": bandit_camp,
    "house": house, "smithy": smithy, "shrine": shrine,
}

EXTRA_STRIPS = {
    "house_town": house_town,
}

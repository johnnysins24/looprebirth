"""v2 icons: 16x16 for the HUD and stats, 24x24 for slots and notifications.

Each icon is a hand-placed grid with its own legend: an ink outline, three or four
shades lit from the top left, and one bright highlight pixel.
"""

import math

import img
import pal

O = {"o": "ink1", "O": "ink0", "w": "white"}

SMALL = {}
BIG = {}


def icon(table, name, legend, rows, size):
    for i, r in enumerate(rows):
        assert len(r) == size, (name, i, len(r))
    assert len(rows) == size, (name, len(rows))
    table[name] = img.grid(rows, {**O, **legend})


# ----------------------------------------------------------------------- 16 x 16

icon(SMALL, "hp", {"R": "red4", "r": "red3", "q": "red2"}, [
    "................",
    "..oooo....oooo..",
    ".oRRrro..orrrqo.",
    "oRwRrrrooorrrrqo",
    "oRRrrrrrrrrrrrqo",
    "orrrrrrrrrrrrrqo",
    "orrrrrrrrrrrrqqo",
    ".orrrrrrrrrrrqo.",
    "..orrrrrrrrqqo..",
    "...orrrrrrrqo...",
    "....orrrrrqo....",
    ".....orrrqo.....",
    "......orqo......",
    ".......oo.......",
    "................",
    "................",
], 16)

icon(SMALL, "mana", {"B": "blue5", "b": "blue3", "v": "blue2"}, [
    "................",
    ".......oo.......",
    "......obbo......",
    "......obbo......",
    ".....obbbbo.....",
    ".....oBbbbo.....",
    "....oBwbbbvo....",
    "....oBBbbbvo....",
    "...oBBbbbbbvo...",
    "...oBbbbbbbvo...",
    "...obbbbbbvvo...",
    "...obbbbbbvvo...",
    "....obbbbvvo....",
    ".....ovvvvo.....",
    "......oooo......",
    "................",
], 16)

icon(SMALL, "xp", {"4": "gold4", "3": "gold3", "2": "gold2"}, [
    "................",
    ".......oo.......",
    "......o44o......",
    "......o43o......",
    ".....o4433o.....",
    "oooooo4w33oooooo",
    "o44444433333322o",
    ".o444443333332o.",
    "..o4443333332o..",
    "...o43333332o...",
    "..o4333oo3332o..",
    "..o433o..o332o..",
    ".o43o......o32o.",
    ".oo..........oo.",
    "................",
    "................",
], 16)

icon(SMALL, "rp", {"P": "roof5", "p": "roof4", "q": "roof3", "Q": "roof2", "s": "gold4"}, [
    "................",
    "...........ooo..",
    ".........ooPPpo.",
    "........oPPppqo.",
    ".......oPpppqqo.",
    "......oPppqqQo..",
    ".....oPpqqqQo...",
    "....oPpqqQQo....",
    "....oppqQQo.....",
    "...opqqQoo......",
    "...oqQoo........",
    "..oQoo..........",
    ".oso............",
    "oso.............",
    "oo..............",
    "................",
], 16)

icon(SMALL, "str", {"S": "skin4", "s": "skin3", "d": "skin2", "D": "skin1", "R": "red4", "r": "red3", "q": "red2", "Q": "red1"}, [
    "................",
    "................",
    "...oo.oo.oo.oo..",
    "..oSsoSsoSsoSso.",
    "..oSsoSsoSsoSdo.",
    "..osdosdosdosdo.",
    "..oddoddoddoddo.",
    ".oSSSSSSsdoddDo.",
    ".osssssssDdddDo.",
    ".odddddddDdddDo.",
    "..odddddddddDo..",
    "...ossssssdDo...",
    "...oRRrrrrrqo...",
    "...oQqqqqqqQo...",
    "....oooooooo....",
    "................",
], 16)

icon(SMALL, "agi", {"G": "grass6", "g": "grass5", "h": "grass4", "H": "grass3", "W": "cool7", "x": "cool6", "X": "cool5"}, [
    "................",
    "................",
    ".oo...oooooo....",
    "oWxoo.oGGGgo....",
    ".oWxxooGggHo....",
    "oWWxxXoGggHo....",
    ".oWxXXoGggHo....",
    "..oooooGggHo....",
    "......oGggHo....",
    "......oGgggHo...",
    "......oGgggghHo.",
    ".....oGggggghHo.",
    ".....oHHHHHHHHo.",
    "......oooooooo..",
    "................",
    "................",
], 16)

icon(SMALL, "int", {"B": "blue5", "b": "blue3", "v": "blue2", "W": "cool7", "x": "cool6", "X": "cool5", "c": "teal4"}, [
    "................",
    "................",
    ".oooooo..oooooo.",
    "oWWWWxxooxxWWWxo",
    "oWxxxxxooxcxxxxo",
    "oWxXXxxooxccxXxo",
    "oWxxxxxooxxcxxxo",
    "oWxXXXxooxcxxXxo",
    "oWxxxxxooxxxxxxo",
    "oWxXXxxooxXXXxxo",
    "obbbbbboobbbbbvo",
    "ovvvvvbobbvvvvvo",
    ".oooooooooooooo.",
    "................",
    "................",
    "................",
], 16)

icon(SMALL, "atk", {"A": "cool7", "a": "cool6", "z": "cool5", "g": "gold4", "G": "gold3", "u": "wood3"}, [
    "................",
    "............ooo.",
    "...........oAAo.",
    "..........oAazo.",
    ".........oAazo..",
    "........oAazo...",
    ".......oAazo....",
    "..oo..oAazo.....",
    "..ogooAazo......",
    "...oGgazo.......",
    "....oGgo........",
    "...ouoGgo.......",
    "..ouo.oGo.......",
    ".ouo...oo.......",
    ".oo.............",
    "................",
], 16)

icon(SMALL, "def", {"B": "blue4", "b": "blue3", "v": "blue2", "A": "cool6", "a": "cool5", "z": "cool4", "g": "gold4"}, [
    "................",
    "..oooooooooooo..",
    ".oAAAAAAAAAAazo.",
    ".oAbBBBggbbbvzo.",
    ".oAbBBBggbbbvzo.",
    ".oAbBggggggbvzo.",
    ".oAbBggggggbvzo.",
    ".oabBBBggbbbvzo.",
    "..oabBBggbbvzo..",
    "..oabbbggbbvzo..",
    "...oabbggbvzo...",
    "....oabbbvzo....",
    ".....oavvzo.....",
    "......oaao......",
    ".......oo.......",
    "................",
], 16)

icon(SMALL, "eva", {"T": "teal5", "t": "teal4", "s": "teal3", "S": "teal2"}, [
    "................",
    "................",
    "....oooooooo....",
    "...oTTttttsso...",
    "....oooooossoo..",
    ".oooooooo..ooo..",
    "oTTtttttsso.....",
    ".ooooooossSo....",
    "..oooooo.oSo....",
    ".oTttttsoooo....",
    "..oooossSo......",
    ".......oo.......",
    "................",
    "................",
    "................",
    "................",
], 16)

icon(SMALL, "ap", {"V": "violet5", "v": "violet4", "u": "violet3", "U": "violet2"}, [
    "................",
    "................",
    ".......oo.......",
    "......oVvo......",
    ".....oVVvuo.....",
    "....oVwVvuuo....",
    "...oVVVvvuuUo...",
    "..ovvvvvuuuUUo..",
    "...ouuuuuuUUo...",
    "....ouuuuUUo....",
    ".....ouuUUo.....",
    "......oUUo......",
    ".......oo.......",
    "................",
    "................",
    "................",
], 16)

icon(SMALL, "pause", {"W": "white", "x": "cool6"}, [
    "................",
    "................",
    "................",
    "....oooo.oooo...",
    "....oWxo.oWxo...",
    "....oWxo.oWxo...",
    "....oWxo.oWxo...",
    "....oWxo.oWxo...",
    "....oWxo.oWxo...",
    "....oWxo.oWxo...",
    "....oWxo.oWxo...",
    "....oxxo.oxxo...",
    "....oooo.oooo...",
    "................",
    "................",
    "................",
], 16)

icon(SMALL, "lock", {"A": "cool6", "a": "cool5", "z": "cool4", "g": "gold4", "G": "gold3", "y": "gold2"}, [
    "................",
    "................",
    ".....oooooo.....",
    "....oAaaaazo....",
    "....oao..ozo....",
    "....oao..ozo....",
    "...oooooooooo...",
    "...ogggGGGGyo...",
    "...ogGGoOGGyo...",
    "...oGGGoOGyyo...",
    "...oGGGGOGyyo...",
    "...oGGyyyyyyo...",
    "...oyyyyyyyyo...",
    "....oooooooo....",
    "................",
    "................",
], 16)


def _ring_icon(name, outer, inner, cols, gap, head):
    """Clockwise loop arrow drawn from geometry, outlined in ink."""
    c = img.Canvas(16, 16)
    cx = cy = 7.5
    for y in range(16):
        for x in range(16):
            d = math.hypot(x + 0.5 - 8, y + 0.5 - 8)
            a = math.degrees(math.atan2(y + 0.5 - 8, x + 0.5 - 8)) % 360
            if inner <= d <= outer and not (gap[0] <= a <= gap[1]):
                shade = cols[0] if y < 6 or x < 5 else cols[1] if y < 11 else cols[2]
                c.set(x, y, shade)
    for (x, y) in head:
        c.set(x, y, cols[0])
    c.outline("ink1")
    SMALL[name] = c.im


_ring_icon("loop", 6.6, 3.9, ("gold4", "gold3", "gold2"), (300, 345),
           [(11, 1), (11, 2), (12, 2), (11, 3), (12, 3), (13, 3), (11, 4), (12, 4), (11, 5)])


# ----------------------------------------------------------------------- 24 x 24

icon(BIG, "sword", {"A": "cool7", "a": "cool6", "z": "cool5", "Z": "cool4", "g": "gold4", "G": "gold3", "y": "gold2", "u": "wood3", "U": "wood2", "r": "red3"}, [
    "........................",
    "....................ooo.",
    "...................oAAo.",
    "..................oAaao.",
    ".................oAazZo.",
    "................oAazZo..",
    "...............oAazZo...",
    "..............oAazZo....",
    ".............oAazZo.....",
    "............oAazZo......",
    "...........oAazZo.......",
    "....oo....oAazZo........",
    "....ogo..oAazZo.........",
    ".....oGooAazZo..........",
    "......oGgazZo...........",
    "......ooGgZo............",
    ".....ouooGgo............",
    "....ouUo.oGgo...........",
    "...ouUo...oyGo..........",
    "..orUo.....ooo..........",
    ".orro...................",
    ".ooo....................",
    "........................",
    "........................",
], 24)

icon(BIG, "armor", {"A": "cool7", "a": "cool6", "z": "cool5", "Z": "cool4", "x": "cool3", "g": "gold4", "G": "gold3", "y": "gold2", "b": "blue3", "v": "blue2"}, [
    "........................",
    "........................",
    "....ooooo....ooooo......",
    "...oAaaazooooozzZxo.....",
    "..oAaaazZgggggZzZZxo....",
    "..oAaazZgGGGGGgZzZxo....",
    "..oaaazZoGbbbGoZZZxo....",
    "...oazZo.oGbGo.oZxo.....",
    "...oaaZo..oGo..oZxo.....",
    "...oAazZo.....oZZxo.....",
    "...oAaazZoooooZZZxo.....",
    "...oAaazzZZZZZZZZxo.....",
    "...oAaazzzZZZZZZZxo.....",
    "...oAaazzzZZZZZZxxo.....",
    "...ogGGGGGGGGGGGGyo.....",
    "...oAaazzzZZZZZZxxo.....",
    "...oAaazzzZZZZZZxxo.....",
    "....oAazzzZZZZZxxo......",
    ".....oaazzZZZZxxo.......",
    "......ooooooooooo.......",
    "........................",
    "........................",
    "........................",
    "........................",
], 24)

icon(BIG, "amulet", {"g": "gold4", "G": "gold3", "y": "gold2", "P": "pink4", "p": "pink3", "q": "pink2", "Q": "pink1"}, [
    "........................",
    "....oo............oo....",
    "....oGo..........oGo....",
    ".....oGo........oGo.....",
    ".....oGyo......oyGo.....",
    "......oGyo....oyGo......",
    ".......oGyo..oyGo.......",
    "........oGyooyGo........",
    ".........oGGGGo.........",
    "........ooggggoo........",
    ".......oggGyyGggo.......",
    "......oggoooooooggo.....",
    ".....ogGoPPppqQoGgo.....",
    ".....oGoPwPppqqQoGo.....",
    ".....oGoPPpppqqQoGo.....",
    ".....oGoppppqqQQoGo.....",
    ".....oGoqpppqqQQoyo.....",
    "......oGoqqqqQQoyo......",
    ".......oGoQQQQoyo.......",
    "........oyoooooyo.......",
    ".........oyyyyyo........",
    "..........ooooo.........",
    "........................",
    "........................",
], 24)


def _orb(table, name, size, r, cols, spikes=None, core=None):
    """Glowing orb (fireball, magic): radial bands, outlined."""
    c = img.Canvas(size, size)
    cx = cy = size / 2
    for y in range(size):
        for x in range(size):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            lit = d - 0.35 * (-(dx + dy) / max(d, 0.01)) * r * 0.3
            if d <= r:
                k = 0 if lit < r * 0.35 else 1 if lit < r * 0.6 else 2 if lit < r * 0.85 else 3
                c.set(x, y, cols[k])
    if spikes:
        for (x, y, k) in spikes:
            c.set(x, y, cols[k])
    if core:
        for (x, y) in core:
            c.set(x, y, "white")
    c.outline("ink1")
    table[name] = c.im


_orb(BIG, "fireball", 24, 7.2, ("gold5", "gold4", "roof3", "red2"),
     spikes=[(17, 3, 3), (18, 4, 3), (16, 4, 2), (19, 6, 3), (14, 2, 3), (15, 3, 2), (20, 8, 3), (12, 3, 3), (18, 6, 2), (17, 5, 2)],
     core=[(9, 9), (10, 9), (9, 10)])

icon(BIG, "cleave", {"A": "cool7", "a": "cool6", "z": "cool5", "B": "blue5", "b": "blue4", "v": "blue3"}, [
    "........................",
    "........................",
    "..........oooooo........",
    ".......oooBBBBBBooo.....",
    ".....ooBBbbbbbbbBBBoo...",
    "....oBBbbvvvvvvbbbBBo...",
    "...oBbbvvoooooovvbbbBo..",
    "..oBbvvoo......oovvbbBo.",
    "..oBbvo..........ovvbbo.",
    ".oBbvo............ovbbo.",
    ".oBbvo.............ovbo.",
    ".oBbo..............ovbo.",
    ".oBvo...............obo.",
    ".oBo................ovo.",
    ".oBo.......oo.......oo..",
    "..oo......oAAo..........",
    "..........oAao..........",
    ".........oAazo..........",
    "........oAazo...........",
    ".......oAazo............",
    "......oAazo.............",
    ".....ooazo..............",
    ".....oooo...............",
    "........................",
], 24)

icon(BIG, "stat_up", {"G": "gold5", "g": "gold4", "y": "gold3", "Y": "gold2", "c": "cool4"}, [
    "........................",
    "...........oo...........",
    "..........oGgo..........",
    ".........oGggyo.........",
    "........oGgggyyo........",
    ".......oGggggyyYo.......",
    "......oGgggggyyyYo......",
    ".....oGggggggyyyyYo.....",
    "....oooooGggyyYooooo....",
    "........oGggyyYo........",
    "........oGggyyYo........",
    "........oGggyyYo........",
    "........oGggyyYo........",
    "........oggyyyYo........",
    "........ooooooo.........",
    "........................",
    "....oooo..oooo..oooo....",
    "....oGgo..oGgo..occo....",
    "....oyYo..oyYo..occo....",
    "....oooo..oooo..oooo....",
    "........................",
    "........................",
    "........................",
    "........................",
], 24)

icon(BIG, "chest", {"u": "wood3", "U": "wood2", "t": "wood4", "T": "wood1", "g": "gold4", "G": "gold3", "y": "gold2"}, [
    "........................",
    "........................",
    "........................",
    "....oooooooooooooooo....",
    "...ottttttttttttttUUo...",
    "..ottuuuuuuuuuuuuuuUUo..",
    "..otuuuuuuuuuuuuuuuuUo..",
    "..ogggggggggggggggggyo..",
    "..ouuuuuuuoGGouuuuuuUo..",
    "..ooooooooogGoooooooooo.",
    "..ottttttttoGotttttttUo.",
    "..otuuuuuuuuouuuuuuuuUo.",
    "..otuuuuuuuuuuuuuuuuUUo.",
    "..ogggggggggggggggggyyo.",
    "..otuuuuuuuuuuuuuuuUUUo.",
    "..otuuuuuuuuuuuuuuuUUTo.",
    "..oTTTTTTTTTTTTTTTTTTTo.",
    "...oooooooooooooooooooo.",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
    "........................",
], 24)


def card_icon():
    """Small card back for the 'pick a lap card' notification."""
    c = img.Canvas(24, 24)
    c.rect(5, 2, 18, 21, "ink1")
    c.rect(6, 3, 17, 20, "blue1")
    c.rect(7, 4, 16, 19, "blue2")
    c.hline(7, 16, 4, "blue3")
    for y in range(6, 18, 2):
        c.hline(9, 14, y, "gold3" if y in (6, 16) else "blue1")
    c.set(11, 11, "gold4")
    c.set(12, 11, "gold4")
    c.set(11, 10, "gold3")
    c.set(12, 12, "gold3")
    BIG["card"] = c.im


card_icon()


def village_icon():
    c = img.Canvas(24, 24)
    c.poly([(3, 12), (11, 4), (19, 12)], "roof3")
    c.poly([(11, 4), (19, 12), (11, 12)], "roof2")
    c.line(3, 12, 11, 4, "roof5")
    c.rect(5, 12, 17, 20, "sand4")
    c.rect(12, 12, 17, 20, "sand3")
    c.rect(9, 15, 12, 20, "wood2")
    c.vline(9, 15, 20, "wood3")
    c.rect(14, 14, 16, 16, "blue3")
    c.set(14, 14, "blue5")
    c.hline(4, 18, 21, "stone3")
    c.outline("ink1")
    BIG["village"] = c.im


village_icon()


if __name__ == "__main__":
    import sys

    out = sys.argv[1] if len(sys.argv) > 1 else "icons.png"
    for t in (SMALL, BIG):
        for k, v in t.items():
            assert not img.bad_pixels(v), k
    a = img.row(list(SMALL.values()), gap=4, pad=4, bg="cool1")
    b = img.row(list(BIG.values()), gap=4, pad=4, bg="cool1")
    sheet = img.new(max(a.width, b.width), a.height + b.height)
    img.paste(sheet, a, 0, 0)
    img.paste(sheet, b, 0, a.height)
    img.zoom(sheet, 6).save(out)

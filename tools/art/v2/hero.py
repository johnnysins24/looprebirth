"""v2 hero: 32x48 frames, about 3 heads tall, light from the top left."""

import img

LEGEND = {
    "o": "ink1",  # silhouette outline
    "O": "ink0",  # eye lash / pupil
    "1": "hair0",
    "2": "hair1",
    "3": "hair2",
    "4": "hair3",
    "5": "hair4",
    "l": "skin0",
    "D": "skin1",
    "d": "skin2",
    "s": "skin3",
    "S": "skin4",
    "w": "white",
    "i": "blue2",
    "I": "blue4",
    "Q": "red1",
    "q": "red2",
    "r": "red3",
    "R": "red4",
    "W": "cool7",
    "x": "cool6",
    "X": "cool5",
    "V": "blue1",
    "v": "blue2",
    "b": "blue3",
    "B": "blue4",
    "g": "gold3",
    "G": "gold4",
    "y": "gold2",
    "U": "wood1",
    "u": "wood2",
    "t": "wood3",
    "T": "wood4",
    "m": "cool1",
    "p": "cool2",
    "P": "cool3",
    "z": "cool4",
    "a": "cool5",
    "A": "cool6",
    "Z": "cool7",
}

FRONT = [
    "................................",  # 0
    "................................",
    "................................",
    "..............o.oo..............",  # 3
    "...........ooo4o45oooo..........",
    "..........o34455454433o.........",  # 5
    "........o23455544433332o........",
    ".......o1234444443333221o.......",
    ".......o2343444334332221o.......",
    ".......o23334d4333d32221o.......",
    ".......o2323ddd32ddd2221o.......",  # 10
    ".......o2322OOs22sOO2221o.......",
    ".......o232OwOssssOwO221o.......",
    ".......o232iIissssiIi221o.......",
    "........o32sSsssdsssd21o........",
    ".........o22sssssssd21o.........",  # 15
    "..........o2ldssdsdl2o..........",
    "...........oQldssdlQo...........",
    "..........orRRrrrrRrqo..........",
    ".........oqRrrrqrrrrqqo.........",
    "........oBqQrrqQrrrQqqvo........",  # 20
    ".......oBbVbbgWWxxgvvVvVo.......",
    ".......oBbVbbgWxxXgvvVvVo.......",
    ".......oBbVbbbgxXgvvvVvVo.......",
    ".......oBbVbbbgxXgvvvVvVo.......",
    ".......oBbVbbbbgGvvvvVvVo.......",  # 25
    ".......oBbVobbbgvvvVoVvVo.......",
    ".......oBbVobbbbvvvVoVvVo.......",
    ".......oBbVotuuGguuUoVvVo.......",
    ".......oBbVobbbbvvvvoVvVo.......",
    ".......oGgyobbgppgvvogyyo.......",  # 30
    ".......oSsdbbbgppgvvVsdDo.......",
    ".......osdDbbgpPPpgvVdDDo.......",
    "........ooogGypPPpyggooo........",
    "..........ommmmmmmmmmo..........",
    "..........oPpmo..opmmo..........",  # 35
    "..........oPpmo..opmmo..........",
    "..........oPPmo..oPpmo..........",
    "..........oPpmo..opmmo..........",
    ".........oTTTto..oTttuo.........",
    ".........otttuo..outtUo.........",  # 40
    ".........otuuUo..ouuUUo.........",
    "........otuuuUo..ouuuUUo........",
    "........oTuuuUo..ouuuUUo........",
    "........oUUUUUo..oUUUUUo........",
    ".........ooooo....ooooo.........",  # 45
    "................................",
    "................................",
]


# facing right
SIDE = [
    "................................",  # 0
    "................................",
    "................................",
    "...........oo...o...............",  # 3
    ".........o34543443o.............",
    "........o23455434432o...........",  # 5
    ".......o2345554444332o..........",
    "......o123444444333322o.........",
    "......o122333444433332o.........",
    "......o1223334432d3332o.........",
    "......o122333432dsd322o.........",  # 10
    "......o12233332sssOOsso.........",
    "......o12233322dssOwsso.........",
    "......o12233322DssiIssso........",
    ".......o1223322dsSsssdo.........",
    "........o12221Ddsssslo..........",  # 15
    ".........o121oDdssddo...........",
    "..........oooQDDldlo............",
    ".....oooooorRRrrrRrqo...........",
    "....orRRrrqRrrrqrrrrqo..........",
    "...oqrrRrqqQrrqqrrQqo...........",  # 20
    "..oqqrro.ovVBBbVbgWo............",
    "..oQqo...ovVBbbVbgWo............",
    "...oo....ovVBbbVbgxo............",
    ".........ovVBbbVbbgo............",
    ".........ovVBbbVbbvo............",  # 25
    ".........ovVBbbVbbvo............",
    ".........ovVBbbVbbvo............",
    ".........ouVBbbVtuGo............",
    ".........ovVBbbVbbvo............",
    "........ovvVGgyVbbvo............",  # 30
    "........ovvoSsdobbVo............",
    "........ovVosdDovvVo............",
    ".......oggyooooyggyo............",
    "...........ommmmmmo.............",
    "...........oPppmpmo.............",  # 35
    "...........oPppmpmo.............",
    "...........oPPpmpmo.............",
    "...........oPppmpmo.............",
    "..........oTTTtUutuo............",
    "..........otttuUuuUo............",  # 40
    "..........otuuuUuuUo............",
    "..........otuuuUuuuUo...........",
    "..........oTuuuUuuuUUo..........",
    "..........oUUUUUUUUUUo..........",
    "...........oooooooooo...........",  # 45
    "................................",
    "................................",
]

# sword in the far hand: drawn behind the body, the blade shows in front of the legs
SIDE_BEHIND = {
    32: (16, "oGgo"),
    33: (16, "oggyo"),
    34: (17, "oAao"),
    35: (18, "oAao"),
    36: (19, "oAzo"),
    37: (20, "oAzo"),
    38: (21, "oZzo"),
    39: (22, "oAzo"),
    40: (23, "oAo"),
    41: (24, "oo"),
}

BACK = [
    "................................",  # 0
    "................................",
    "................................",
    "..............o.oo..............",  # 3
    "...........ooo4o45oooo..........",
    "..........o34455454433o.........",  # 5
    "........o23455544433332o........",
    ".......o1234444443333221o.......",
    ".......o1234444443333221o.......",
    ".......o1233444433332221o.......",
    ".......o1223344333322211o.......",  # 10
    ".......o1223334333322211o.......",
    ".......o1232333232332211o.......",
    ".......o1232332232322211o.......",
    "........o12322322322221o........",
    ".........o232232232221o.........",  # 15
    "..........o2321232121o..........",
    "...........o2oDDDDo2o...........",
    "..........orRRrrrrRrqo..........",
    ".........oqRrrrqrrrrqqo.........",
    "........oBqQrrqQrrrQqqvo........",  # 20
    ".......oBbVBbbbbvvvvVVvVo.......",
    ".......oBbVBbbbbvvvvVVvVo.......",
    ".......oBbVBbbbbbvvvVVvVo.......",
    ".......oBbVBbbbbbvvvVVvVo.......",
    ".......oBbVBbbbbbvvvVVvVo.......",  # 25
    ".......oBbVobbbbvvvVoVvVo.......",
    ".......oBbVobbbbvvvVoVvVo.......",
    ".......oBbVotuuuuuuUoVvVo.......",
    ".......oBbVobbbbvvvvoVvVo.......",
    ".......oGgyobbbVVvvvogyyo.......",  # 30
    ".......oSsdbbbbVVvvvVsdDo.......",
    ".......osdDbbbbVVvvvVdDDo.......",
    "........ooogGggyygggyooo........",
    "..........ommmmmmmmmmo..........",
    "..........oPpmo..opmmo..........",  # 35
    "..........oPpmo..opmmo..........",
    "..........oPPmo..oPpmo..........",
    "..........oPpmo..opmmo..........",
    ".........oTTTto..oTttuo.........",
    ".........otttuo..outtUo.........",  # 40
    ".........otuuUo..ouuUUo.........",
    "........otuuuUo..ouuuUUo........",
    "........otuuuUo..ouuuUUo........",
    "........oUUUUUo..oUUUUUo........",
    ".........ooooo....ooooo.........",  # 45
    "................................",
    "................................",
]

# scarf tail, drawn behind the body
FRONT_BEHIND = {
    18: (23, "ooo"),
    19: (23, "rRro"),
    20: (23, "qrRro"),
    21: (24, "qqrRo"),
    22: (25, "oQqro"),
    23: (26, "ooqo"),
    24: (28, "o"),
}

# sword held low in the right hand, drawn over the body
FRONT_OVER = {
    33: (6, "oGggyo"),
    34: (7, "oAao"),
    35: (7, "oAzo"),
    36: (6, "oAao"),
    37: (6, "oAzo"),
    38: (6, "oZzo"),
    39: (5, "oAao"),
    40: (5, "oAzo"),
    41: (5, "oAzo"),
    42: (5, "oAo"),
    43: (5, "oo"),
}


def layer(spec, h=48, w=32):
    rows = ["." * w for _ in range(h)]
    for y, (x, s) in spec.items():
        r = rows[y]
        rows[y] = r[:x] + s + r[x + len(s):]
    return img.grid(rows, LEGEND)


def front():
    body = img.grid(FRONT, LEGEND)
    body = img.under(body, layer(FRONT_BEHIND))
    return img.paste(body, layer(FRONT_OVER), 0, 0)


def side():
    return img.under(img.grid(SIDE, LEGEND), layer(SIDE_BEHIND))


def back():
    body = img.grid(BACK, LEGEND)
    body = img.paste(body, img.flip_h(layer(FRONT_BEHIND)), 0, 0)
    return img.under(body, img.flip_h(layer(FRONT_OVER)))


if __name__ == "__main__":
    import sys

    for name, g in (("front", FRONT), ("side", SIDE), ("back", BACK)):
        for i, r in enumerate(g):
            if len(r) != 32:
                print(name, "row", i, "len", len(r))
    out = sys.argv[1] if len(sys.argv) > 1 else "hero_front.png"
    im = front()
    print(img.bad_pixels(im)[:5])
    big = img.zoom(img.under(im, img.checker(32, 48, "cool7", "white")), 10)
    big.save(out)

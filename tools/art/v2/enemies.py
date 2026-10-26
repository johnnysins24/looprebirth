"""v2 enemies, sculpted then hand-finished. Frames are 32x48, feet on y=45, facing left."""

import numpy as np

import img
import pal
from sculpt import Scene

W, H = 32, 48
GROUND = 45


def _shift(im, mask_fn, steps, ramps):
    """Move pixels inside mask_fn(x, y) by `steps` along whichever ramp they belong to."""
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if not mask_fn(x + 0.5, y + 0.5):
                continue
            c = px[x, y]
            if c[3] == 0:
                continue
            for r in ramps:
                cols = pal.ramp(r)
                if c in cols:
                    i = cols.index(c)
                    j = max(0, min(len(cols) - 1, i + steps))
                    px[x, y] = cols[j]
                    break
    return im


def slime(elite=False):
    gel = "pink" if elite else "teal"
    ramp = [f"{gel}{i}" for i in range(len(pal.RAMPS[gel]))]
    sc = Scene(W, H)
    body = sc.material(ramp[1:5], bias=-0.04, contrast=1.25, line=ramp[0], spec="white", spec_at=0.965)
    flat = lambda px, py: py < GROUND  # sits flat on the ground
    sc.ellipsoid(15.5, 37.0, 0, 10.5, 8.0, 9.0, body, clip=flat)
    sc.capsule((15.5, 32.0, 2.0), (17.0, 28.5, 1.0), 4.2, 2.2, body)
    sc.capsule((17.0, 28.5, 1.0), (18.6, 26.6, 0.0), 2.2, 0.9, body)
    im = sc.render(outline="ink1")
    # the darker core seen through the gel
    _shift(im, lambda x, y: ((x - 16.5) / 6.0) ** 2 + ((y - 40.0) / 3.6) ** 2 <= 1, -1, [gel])
    p = im.load()
    dark, glint = pal.c("ink0"), pal.c("white")
    for x, y in ((11, 35), (12, 35), (11, 36), (12, 36), (11, 37), (12, 37), (17, 35), (18, 35), (17, 36), (18, 36), (17, 37), (18, 37)):
        p[x, y] = dark
    p[11, 35] = glint
    p[17, 35] = glint
    # mouth with one fang
    for x in (13, 14, 15, 16):
        p[x, 39] = pal.c(f"{gel}0")
    p[14, 40] = glint
    # bubbles inside
    for x, y in ((21, 34), (20, 40), (9, 40)):
        p[x, y] = pal.c(ramp[4])
    if elite:
        img.paste(im, crown(), 12, 19)
    return im


CROWN = [
    "o.o.o..",
    "oGoGo.o",
    "oGGGGoGo",
    "ogggggyo",
    ".ooooooo",
]


def crown():
    rows = [r.ljust(8, ".") for r in CROWN]
    return img.grid(rows, {"o": "ink1", "G": "gold4", "g": "gold3", "y": "gold2"})


WOLF_LEGEND = {
    "n": "ink0", "K": "ink2", "1": "cool1", "2": "cool2", "3": "cool3", "4": "cool4", "5": "cool5",
    "b": "stone4", "c": "stone5", "C": "stone6", "e": "gold4", "E": "gold5", "w": "white", "r": "red2",
}

# Grey wolf in a snarling walk, facing left: dark saddle, pale legs and ruff, far legs in shadow.
# Fill only; the outline is added around the whole frame. Pasted at (1, 21) so the paws sit on y=44.
WOLF = [
    "........3.....................",
    ".....3.53.....................",
    ".....425K3..4.4...............",
    "....4345234554544.............",
    "....55443334333354444544......",
    "...55K244333233332333334454...",
    "n4544Ee4434433333333333333543.",
    "n444c3cc4455444444444444434543",
    ".wrrnccCc45445444444544443.443",
    "..wbbcCcc44544544344544443.443",
    "...bbcCcCc4443444344444443.342",
    "......cCcccbbbbbbbbb444333.332",
    ".......cCccbbbbb..22344332.231",
    "........ccbbbb....22bccb32.21.",
    "........Ccb.22....23.cc43..1..",
    "........Ccb.22.....23.c433....",
    "........Ccb.22.....23..c43....",
    "........Ccb.22.....22...43....",
    "........Ccb.22....23...c3.....",
    "........cb..22....23...c3.....",
    "........cb..22....23...c3.....",
    "........cb..22....23...c3.....",
    ".......Cccb221...221.Cccb.....",
    "......ccKcb121..2121.cKcb.....",
]

ELITE_FUR = {"cool1": "violet0", "cool2": "violet1", "cool3": "violet2", "cool4": "violet3", "cool5": "violet4",
             "stone4": "violet4", "stone5": "violet5", "stone6": "white", "gold4": "red4", "gold5": "red5"}


def wolf(elite=False):
    im = img.new(W, H)
    img.paste(im, img.grid(WOLF, WOLF_LEGEND), 1, 21)
    if elite:
        im = img.recolor(im, ELITE_FUR)
    im = img.outline(im, "ink1")
    if elite:
        img.paste(im, crown(), 6, 15)
    return im


if __name__ == "__main__":
    import sys

    ims = [slime(), slime(True), wolf(), wolf(True)]
    for i in ims:
        print(img.bad_pixels(i)[:3])
    out = sys.argv[1] if len(sys.argv) > 1 else "enemies.png"
    sheet = img.row([img.under(i, img.checker(W, H, "grass4", "grass5")) for i in ims], gap=2, pad=2, bg="cool2")
    img.zoom(sheet, 6).save(out)

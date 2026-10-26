"""Build every game sprite into assets/art/ plus manifest.json and preview sheets.

    python3 tools/art/build.py            # writes assets/art/** and docs/art/*.png

Sprites are drawn as text grids in the modules next to this file (one char per
Endesga 32 color, see pal.py). The build fails if any pixel is off-palette or
semi-transparent. assets/art/fonts/ is never touched.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

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
OUT = os.path.join(ROOT, "assets", "art")
DOCS = os.path.join(ROOT, "docs", "art")

T = 16
WATER_FPS = 3

# background name in the game -> ground style here
LAND_FILES = {
    "sea": ("land", "sea"),
    "grass": ("land_grass", "forest"),
    "parchment": ("land_parchment", "parchment"),
    "navy": ("land_navy", "navy"),
}

written = []
problems = []


def save(im, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bad = px.bad_pixels(im)
    if bad:
        problems.append("%s: %d off-palette pixels, first %r" % (rel, len(bad), bad[0]))
    im.save(path)
    written.append(rel)
    return rel


def strip(frames, fw=None, fh=None):
    return px.sheet([list(frames)], fw=fw, fh=fh)


# ---------------------------------------------------------------- tiles

def land_sheet(style):
    """256x96: rows 0-3 = dual-grid atlas, frame f at columns 4f..4f+3;
    row 4 = grass variants of tile 15, row 5 = open-water variants of tile 0
    (variant v of frame f at column 4f+v)."""
    st = ground.STYLES[style]
    out = px.blank(16 * T, 6 * T)
    for f in range(ground.FRAMES):
        px.paste(out, ground.dual_atlas(style, f), 4 * T * f, 0)
        for v in range(4):
            px.paste(out, ground.render_dual(15, st, f, v), (4 * f + v) * T, 4 * T)
            px.paste(out, ground.render_dual(0, st, f, v), (4 * f + v) * T, 5 * T)
    return out


def build_tiles(man):
    files = {}
    for bg, (name, style) in LAND_FILES.items():
        files[bg] = save(land_sheet(style), "tiles/%s.png" % name)
    man["tiles"]["land"] = {
        "files": files,
        "tile": [T, T],
        "layout": "dual_grid",
        "offset": [-8, -8],
        "grid": "(board_w + 1) x (board_h + 1) tiles; tile (i, j) is drawn at cell (i, j) * 16 - (8, 8)",
        "index": "TL*1 + TR*2 + BL*4 + BR*8, TL = cell (i-1, j-1), TR = (i, j-1), BL = (i-1, j), BR = (i, j); bit = land; off-board cells are sea",
        "atlas": "tile index at column index % 4 + 4 * frame, row index // 4",
        "frames": ground.FRAMES,
        "fps": WATER_FPS,
        "variants": {
            "15": {"row": 4, "count": 4, "pick": "column 4 * frame + v, v = hash(i, j) % 4 (grass tufts)"},
            "0": {"row": 5, "count": 4, "pick": "column 4 * frame + v, v = hash(i, j) % 4 (open water)"},
        },
    }
    man["tiles"]["road"] = {
        "file": save(strip(road.road_strip()), "tiles/road.png"),
        "tile": [T, T],
        "layout": "mask_strip",
        "index": "N=1 E=2 S=4 W=8: neighbours that are the previous or next loop cell; frame = mask",
    }
    camp = [px.crop(f, 0, 8, T, T) for f in objects.camp_frames()]
    man["tiles"]["camp"] = {
        "file": save(strip(camp), "tiles/camp.png"),
        "tile": [T, T], "frames": 4, "fps": 6, "loop": True,
        "note": "start cell; the fire flickers",
    }
    town_rule = "same dual grid and index as land, bit = cell belongs to the town (largest building group)"
    man["tiles"]["town_ground"] = {
        "file": save(town.ATLASES["town_ground"](), "tiles/town_ground.png"),
        "tile": [T, T], "layout": "dual_grid", "offset": [-8, -8], "index": town_rule,
        "tier": 2, "pass": "ground, after the road",
    }
    for name, tier in (("town_fence", 1), ("town_wall", 2)):
        man["tiles"][name] = {
            "file": save(town.ATLASES[name](), "tiles/%s.png" % name),
            "tile": [T, T], "layout": "dual_grid", "offset": [-8, -8], "index": town_rule,
            "tier": tier,
            "pass": "y-sorted with map objects and units, sort y = y of the tile centre + 1",
        }


# ---------------------------------------------------------------- map objects

def build_map(man):
    for cid, fn in objects.CARD_OBJECTS.items():
        man["map"][cid] = {"file": save(strip([fn(l) for l in (1, 2, 3)]), "map/%s.png" % cid),
                           "frames": "level 1, 2, 3"}
    clear = objects.frame((ui.CLEAR_ART, 0, 8))
    man["map"]["clear"] = {"file": save(strip([clear] * 3), "map/clear.png"),
                           "frames": "card art only, never placed on the map"}
    man["map"]["house_town"] = {"file": save(strip([objects.house_town(l) for l in (1, 2, 3)]), "map/house_town.png"),
                                "frames": "level 1, 2, 3", "note": "use for houses inside a tier-2 town"}
    man["map"]["event"] = {"file": save(strip(objects.event_frames()), "map/event.png"),
                           "frames": 4, "fps": 4, "loop": True, "note": "'?' marker of an event cell"}


# ---------------------------------------------------------------- units

def build_units(man):
    sheet, anims = units.hero()
    man["units"]["hero"] = {"file": save(sheet, "units/hero.png"), "frame": [16, 16], "anchor": [8, 16],
                            "anims": anims}
    for kind in units.ELITE_SWAPS:
        for elite in (False, True):
            sheet, anims = units.enemy(kind, elite)
            name = kind + ("_elite" if elite else "")
            man["units"][name] = {"file": save(sheet, "units/%s.png" % name), "frame": [16, 16],
                                  "anchor": [8, 16], "anims": anims}
    sheet, anims = units.boss()
    man["units"]["boss_warden"] = {"file": save(sheet, "units/boss_warden.png"), "frame": [32, 32],
                                   "anchor": [16, 32], "anims": anims}
    man["units"]["shadow"] = {"file": save(units.SHADOW, "units/shadow.png"), "frame": [16, 16],
                              "anchor": [8, 16], "note": "drawn under every unit before the unit"}
    man["units"]["crown"] = {"file": save(units.CROWN, "units/crown.png"), "frame": list(units.CROWN.size),
                             "note": "elite marker, drawn above the head"}


# ---------------------------------------------------------------- icons

def build_icons(man):
    for name, im in sorted(icons.all_big().items()):
        man["icons"][name] = save(im, "icons/%s.png" % name)
    for name, im in sorted(icons.all_small().items()):
        man["icons"]["small/" + name] = save(im, "icons/small/%s.png" % name)


# ---------------------------------------------------------------- cards

CARD_IDS = ["rock", "grove", "meadow", "spring", "slime_nest", "wolf_den", "graveyard", "bandit_camp",
            "house", "smithy", "shrine", "clear"]


def build_cards(man):
    c = man["cards"]
    c["size"] = [ui.CARD_W, ui.CARD_H]
    c["name_plate"] = {"rect": [4, 34, 24, 6], "text_color": pal.HEX["D"]}
    c["art_window"] = {"rect": [4, 4, 24, 27]}
    c["level_badge"] = {"pos": [2, 0], "size": [7, 9]}
    c["type_icon"] = {"pos": [ui.CARD_W - 11, 3], "size": [8, 8]}
    for ctype in ui.TYPE_COLORS:
        c["frame_" + ctype] = save(ui.card_frame(ctype), "cards/frame_%s.png" % ctype)
    c["back"] = save(ui.card_back(), "cards/back.png")
    c["badge"] = save(strip([ui.level_badge(l) for l in (1, 2, 3)]), "cards/badge.png")
    for cid in CARD_IDS:
        c[cid] = {"file": save(strip([ui.card(cid, l) for l in (1, 2, 3)]), "cards/%s.png" % cid),
                  "type": ui.CARD_TYPES[cid], "frames": "level 1, 2, 3"}
    for sk in ui.SKILLS:
        c["skill_" + sk] = {"file": save(strip([ui.card(sk, l) for l in (1, 2, 3)]), "cards/skill_%s.png" % sk),
                            "type": "skill", "frames": "level 1, 2, 3"}


# ---------------------------------------------------------------- ui

def build_ui(man):
    u = man["ui"]
    wood = ui.panel_wood(32 + 6, 30 + 6)
    u["panel_wood"] = {"file": save(wood, "ui/panel_wood.png"), "nine_slice": [3, 3, 3, 3], "center": "tile"}
    u["panel_paper"] = {"file": save(ui.panel_paper(24, 24), "ui/panel_paper.png"), "nine_slice": [3, 3, 3, 3],
                        "center": "stretch"}
    u["panel_dark"] = {"file": save(ui.panel_dark(24, 24), "ui/panel_dark.png"), "nine_slice": [2, 2, 2, 2],
                       "center": "stretch", "note": "tooltips and modal backing"}
    u["notif_row"] = {"file": save(ui.notif_row(24, 20), "ui/notif_row.png"), "nine_slice": [3, 3, 3, 3],
                      "center": "stretch"}
    states = ["normal", "hover", "pressed", "disabled"]
    u["button"] = {"file": save(strip([ui.button(s) for s in states]), "ui/button.png"), "frame": [16, 16],
                   "frames": states, "nine_slice": [3, 3, 3, 3]}
    kinds = ["normal", "hover", "common", "rare", "epic", "skill"]
    u["slot"] = {"file": save(strip([ui.slot(k) for k in kinds]), "ui/slot.png"), "frame": [20, 20],
                 "frames": kinds}
    u["bar_frame"] = {"file": save(ui.bar_frame(48), "ui/bar_frame.png"), "nine_slice": [3, 2, 3, 2],
                      "fill_rect": [2, 2, 44, 4]}
    bars = ["hp", "mana", "xp", "enemy", "shield"]
    u["bar_fill"] = {"file": save(px.sheet([[ui.bar_fill(b, 8)] for b in bars]), "ui/bar_fill.png"),
                     "frame": [8, 4], "rows": bars, "note": "stretch or tile horizontally"}
    u["cursor"] = {"file": save(ui.CURSOR, "ui/cursor.png"), "hotspot": [0, 0]}
    u["cursor_grab"] = {"file": save(ui.CURSOR_GRAB, "ui/cursor_grab.png"), "hotspot": [5, 4]}
    u["portrait_hero"] = save(ui.PORTRAIT, "ui/portrait_hero.png")
    ov = ["valid", "invalid", "merge", "combo", "warn"]
    u["cell_overlay"] = {"file": save(strip(ui.cell_overlays()), "ui/cell_overlay.png"), "frame": [16, 16],
                         "frames": ov}
    u["level_pips"] = {"file": save(strip(ui.level_pips()), "ui/level_pips.png"), "frame": [16, 16],
                       "frames": "level 1, 2, 3"}
    glyphs = "0123456789x+-/%"
    plain = strip([px.S(ui.DIGITS[g].replace("w", "w")) for g in glyphs], fw=3, fh=5)
    outlined = strip([ui.digit(g, "w", "k") for g in glyphs], fw=5, fh=7)
    u["digits"] = {"file": save(plain, "ui/digits.png"), "frame": [3, 5], "glyphs": glyphs,
                   "advance": 4, "note": "white, recolor with modulate"}
    u["digits_outline"] = {"file": save(outlined, "ui/digits_outline.png"), "frame": [5, 7], "glyphs": glyphs,
                           "advance": 4, "note": "for numbers over the map"}


# ---------------------------------------------------------------- fx

def build_fx(man):
    for name, (fn, fps, loop) in fx.FX.items():
        frames = fn()
        w, h = frames[0].size
        anchor = [w // 2, h] if name == "levelup" else [w // 2, h // 2]
        man["fx"][name] = {"file": save(strip(frames), "fx/%s.png" % name), "frame": [w, h],
                           "frames": len(frames), "fps": fps, "loop": loop, "anchor": anchor}


# ---------------------------------------------------------------- palette

def build_palette(man):
    strip_im = px.blank(32, 1)
    for i, (k, h, n) in enumerate(pal.COLORS):
        strip_im.putpixel((i, 0), pal.KEY[k])
    save(strip_im, "palette/endesga32.png")
    os.makedirs(os.path.join(OUT, "palette"), exist_ok=True)
    with open(os.path.join(OUT, "palette", "endesga32.hex"), "w") as f:
        f.write("".join(h + "\n" for _, h, _ in pal.COLORS))
    with open(os.path.join(OUT, "palette", "endesga32.gpl"), "w") as f:
        f.write("GIMP Palette\nName: Endesga 32\nColumns: 8\n#\n")
        for k, h, n in pal.COLORS:
            r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
            f.write("%3d %3d %3d\t%s (%s)\n" % (r, g, b, n, k))
    written.extend(["palette/endesga32.hex", "palette/endesga32.gpl"])
    man["palette"] = {"name": "Endesga 32", "files": ["palette/endesga32.png", "palette/endesga32.hex",
                                                      "palette/endesga32.gpl"],
                      "colors": [{"key": k, "hex": "#" + h, "name": n} for k, h, n in pal.COLORS]}


# ---------------------------------------------------------------- previews

def previews():
    os.makedirs(DOCS, exist_ok=True)
    from PIL import Image

    def sheet_of(rels, cols, gap=4, bg="c", zoom=3):
        ims = [Image.open(os.path.join(OUT, r)).convert("RGBA") for r in rels]
        cw = max(i.width for i in ims) + gap
        ch = max(i.height for i in ims) + gap
        rows = (len(ims) + cols - 1) // cols
        out = px.blank(cols * cw + gap, rows * ch + gap, bg)
        for n, im in enumerate(ims):
            px.paste(out, im, gap + (n % cols) * cw, gap + (n // cols) * ch)
        return px.zoom(out, zoom)

    groups = {
        "tiles": ([r for r in written if r.startswith("tiles/")], 2, 4),
        "map": ([r for r in written if r.startswith("map/")], 5, 4),
        "units": ([r for r in written if r.startswith("units/")], 6, 4),
        "cards": ([r for r in written if r.startswith("cards/") and r.count("/") == 1], 6, 4),
        "icons": ([r for r in written if r.startswith("icons/")], 16, 4),
        "ui": ([r for r in written if r.startswith("ui/")], 6, 4),
        "fx": ([r for r in written if r.startswith("fx/")], 3, 4),
    }
    for name, (rels, cols, z) in groups.items():
        sheet_of(rels, cols, zoom=z).save(os.path.join(DOCS, "sheet_%s.png" % name))


def main():
    man = {
        "version": 1,
        "generator": "tools/art/build.py",
        "cell": T,
        "rules": {
            "filter": "nearest, no mipmaps",
            "anchor": "units and map objects: bottom-centre of the cell; map objects are 16x24 with 8 px overhang",
            "draw_order": ["land", "road", "camp", "town_ground", "y-sorted: map objects, units, town_fence/town_wall",
                           "cell overlays", "fx", "ui"],
        },
        "tiles": {}, "map": {}, "units": {}, "icons": {}, "cards": {}, "ui": {}, "fx": {},
    }
    build_palette(man)
    build_tiles(man)
    build_map(man)
    build_units(man)
    build_icons(man)
    build_cards(man)
    build_ui(man)
    build_fx(man)
    with open(os.path.join(OUT, "manifest.json"), "w") as f:
        json.dump(man, f, indent=1, ensure_ascii=False)
        f.write("\n")
    if "--no-preview" not in sys.argv:
        previews()
    if problems:
        print("\n".join(problems))
        sys.exit(1)
    print("wrote %d files to %s" % (len(written) + 1, os.path.relpath(OUT, ROOT)))


if __name__ == "__main__":
    main()

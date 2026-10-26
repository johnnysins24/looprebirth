extends Node
## Every picture in the game comes from here (autoload "Art").
##
## Real art lives in res://assets/art/<category>/<id>.png (see docs/dev/art-contract.md).
## When a file is missing, a placeholder is drawn from code with the Endesga 32 palette, in
## the same size and layout as the real thing, so the game never has to know the
## difference and art can be dropped in one file at a time.
##
## Sizes: tiles 16x16, map objects 16x24 (bottom 16 = the cell, bottom-centre anchor),
## units 16x16 (boss 32x32), cards 32x44, icons 16x16.
##
## The real sheets are richer than the placeholders (animated water, walk/attack/hurt frames,
## shadows, elite crowns, finished card faces). Every draw_* call below checks has_real() or
## the sheet size and falls back to the placeholder layout, so both look right.

const ART_DIR := "res://assets/art/"
const CELL := 16
const OBJ_H := 24  ## map object frame height; 8 px may overhang upwards

## Endesga 32.
const C := {
	"rust": Color("be4a2f"), "clay": Color("d77643"), "cream": Color("ead4aa"), "tan": Color("e4a672"),
	"brown": Color("b86f50"), "dark_brown": Color("733e39"), "wine": Color("3e2731"), "crimson": Color("a22633"),
	"red": Color("e43b44"), "orange": Color("f77622"), "gold": Color("feae34"), "yellow": Color("fee761"),
	"lime": Color("63c74d"), "green": Color("3e8948"), "dark_green": Color("265c42"), "pine": Color("193c3e"),
	"deep_blue": Color("124e89"), "blue": Color("0099db"), "cyan": Color("2ce8f5"), "white": Color("ffffff"),
	"silver": Color("c0cbdc"), "slate": Color("8b9bb4"), "dark_slate": Color("5a6988"), "navy_light": Color("3a4466"),
	"navy": Color("262b44"), "black": Color("181425"), "hot_red": Color("ff0044"), "purple": Color("68386c"),
	"magenta": Color("b55088"), "pink": Color("f6757a"), "skin_light": Color("e8b796"), "skin": Color("c28569"),
}

## Background choices to compare during phase 1 (analysis doc: sea / grass / parchment / navy).
const BACKGROUNDS := [
	{"name": "ทะเล", "bg": "blue", "land": "lime", "edge": "green", "land_id": "land"},
	{"name": "ทุ่งหญ้า", "bg": "green", "land": "lime", "edge": "dark_green", "land_id": "land_grass"},
	{"name": "กระดาษเก่า", "bg": "cream", "land": "tan", "edge": "brown", "land_id": "land_parchment"},
	{"name": "น้ำเงินเข้ม", "bg": "navy", "land": "green", "edge": "dark_green", "land_id": "land_navy"},
]

## Animations of the real unit sheets: [row, first column, frames, fps, loops]. Same numbers as
## assets/art/manifest.json. Hero rows 0-3 walk (down, left, right, up), 4-7 attack (cols 0-2)
## and hurt (col 3), 8 cast (one column per facing), 9 ko (cols 0-1) and victory (col 2).
const ENEMY_ANIMS := {"idle": [0, 0, 2, 3.0, true], "attack": [1, 0, 2, 8.0, false], "hurt": [2, 0, 1, 1.0, false]}
const BOSS_ANIMS := {"idle": [0, 0, 2, 2.0, true], "attack": [1, 0, 3, 6.0, false], "hurt": [2, 0, 1, 1.0, false]}
const WATER_FPS := 3.0
const CAMP_FPS := 6.0

var bg_index := 0
var time := 0.0  ## drives the animated tiles (water, camp fire)

var _cache: Dictionary = {}  # "category/id" -> Texture2D
var _font: Font
var _font_bold: Font


func _ready() -> void:
	_font = _load_font("Sarabun-Regular.ttf")
	_font_bold = _load_font("Sarabun-Bold.ttf")


func _process(delta: float) -> void:
	time += delta


func font(bold: bool = false) -> Font:
	return _font_bold if bold else _font


func _load_font(file: String) -> Font:
	var path := ART_DIR + "fonts/" + file
	if FileAccess.file_exists(path):
		var f := FontFile.new()
		f.load_dynamic_font(path)
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		return f
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Leelawadee UI", "Tahoma", "Noto Sans Thai", "Sarabun", "sans-serif"])
	return sys


func color(name: String) -> Color:
	return C[name]


func background() -> Dictionary:
	return BACKGROUNDS[bg_index]


func cycle_background() -> void:
	bg_index = (bg_index + 1) % BACKGROUNDS.size()


# --- lookups ------------------------------------------------------------------------------------


## A texture sheet: real PNG when present, placeholder otherwise.
## category: tiles | map | units | cards | icons | ui | fx
func sheet(category: String, id: String) -> Texture2D:
	var key := category + "/" + id
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	var path := "%s%s/%s.png" % [ART_DIR, category, id]
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		tex = _placeholder(category, id)
	_cache[key] = tex
	return tex


## True when a real PNG (not a placeholder) exists for this picture.
func has_real(category: String, id: String) -> bool:
	return ResourceLoader.exists("%s%s/%s.png" % [ART_DIR, category, id])


## Draws frame (col, row) of a sheet whose frames are fw x fh, with its top-left at `pos`.
func draw_frame(ci: CanvasItem, category: String, id: String, pos: Vector2, fw: int, fh: int, col: int = 0, row: int = 0, modulate: Color = Color.WHITE) -> void:
	var tex := sheet(category, id)
	var cols := maxi(1, tex.get_width() / fw)
	var rows := maxi(1, tex.get_height() / fh)
	var src := Rect2((col % cols) * fw, (row % rows) * fh, fw, fh)
	ci.draw_texture_rect_region(tex, Rect2(pos.round(), Vector2(fw, fh)), src, modulate)


## A map object (card on the map): level 1..3 picks the frame; `cell_px` is the cell's top-left.
func draw_object(ci: CanvasItem, id: String, cell_px: Vector2, level: int = 1, modulate: Color = Color.WHITE) -> void:
	draw_frame(ci, "map", id, cell_px + Vector2(0, CELL - OBJ_H), CELL, OBJ_H, level - 1, 0, modulate)


## Row, first column, frame count, fps and looping of an animation. `dir` is the hero's
## facing: 0 down, 1 left, 2 right, 3 up. Placeholder sheets only have a walk cycle for the hero
## and an idle cycle for everyone else, so other animations fall back to those.
func anim_info(id: String, anim: String, dir: int = 0) -> Array:
	var real := has_real("units", id)
	if id == "hero":
		if not real:
			return [dir, 0, 2, 6.0, true] if anim == "walk" else [dir, 0, 1, 1.0, false]
		match anim:
			"walk":
				return [dir, 0, 4, 8.0, true]
			"attack":
				return [4 + dir, 0, 3, 10.0, false]
			"hurt":
				return [4 + dir, 3, 1, 1.0, false]
			"cast":
				return [8, dir, 1, 1.0, false]
			"ko":
				return [9, 0, 2, 4.0, true]
			"victory":
				return [9, 2, 1, 1.0, false]
		return [dir, 0, 1, 1.0, false]
	var table: Dictionary = BOSS_ANIMS if id == "boss_warden" else ENEMY_ANIMS
	if not real:
		return table["idle"]
	return table.get(anim, table["idle"])


## Seconds a non-looping animation takes (0 for loops), so callers know when it is over.
func anim_length(id: String, anim: String, dir: int = 0) -> float:
	var info := anim_info(id, anim, dir)
	return 0.0 if info[4] else float(info[2]) / float(info[3])


## A unit standing on a cell (bottom-centre anchored) `t` seconds into `anim`. Elites use the
## `<id>_elite` sheet and a crown when those exist.
func draw_unit_anim(ci: CanvasItem, id: String, cell_px: Vector2, anim: String, t: float, dir: int = 0, modulate: Color = Color.WHITE, elite: bool = false) -> void:
	var size := unit_size(id)
	var pos := cell_px + Vector2((CELL - size.x) / 2.0, CELL - size.y)
	if has_real("units", "shadow"):
		var sh := Vector2(size.x, size.x)  # the 16x16 shadow, doubled under the boss
		ci.draw_texture_rect(sheet("units", "shadow"), Rect2((cell_px + Vector2((CELL - sh.x) / 2.0, CELL - sh.y)).round(), sh), false, Color(1, 1, 1, modulate.a))
	var info := anim_info(id, anim, dir)
	var n: int = info[2]
	var step := int(maxf(t, 0.0) * float(info[3]))
	var frame: int = step % n if info[4] else mini(step, n - 1)
	var sheet_id := id + "_elite" if elite and has_real("units", id + "_elite") else id
	draw_frame(ci, "units", sheet_id, pos, int(size.x), int(size.y), int(info[1]) + frame, int(info[0]), modulate)
	if elite and has_real("units", "crown"):
		ci.draw_texture(sheet("units", "crown"), (Vector2(pos.x + (size.x - 7.0) / 2.0, pos.y - 1.0)).round(), modulate)


func unit_size(id: String) -> Vector2i:
	return Vector2i(32, 32) if id == "boss_warden" else Vector2i(16, 16)


func icon(id: String) -> Texture2D:
	return sheet("icons", id)


## Dual-grid land tile for the grid vertex (i, j). `index` (0..15): bit 1 = top-left cell is land,
## 2 = top-right, 4 = bottom-left, 8 = bottom-right. The real atlas is 256x96: frame f of the
## water animation sits in columns 4f..4f+3 (tile index at col index % 4, row index / 4), row 4
## holds grass variants of tile 15 and row 5 open-water variants of tile 0. The placeholder atlas
## is a single static 64x64 grid without variants.
func draw_land(ci: CanvasItem, pos: Vector2, index: int, vertex: Vector2i = Vector2i.ZERO) -> void:
	var tex := sheet("tiles", background()["land_id"])
	var col := index % 4
	var row := index / 4
	if tex.get_width() >= 256 and tex.get_height() >= 96:
		var frame := int(time * WATER_FPS) % 4
		var v := (vertex.x * 73856093 ^ vertex.y * 19349663) & 0x7fffffff
		if index == 15:
			row = 4
			col = v % 4
		elif index == 0:
			row = 5
			col = v % 4
		col += 4 * frame
	draw_frame(ci, "tiles", background()["land_id"], pos, CELL, CELL, col, row)


## True when the land atlas already paints open water, so the code-drawn sea pattern is not needed.
func land_has_water() -> bool:
	return sheet("tiles", background()["land_id"]).get_width() >= 256


## 4-bit road tile: N=1 E=2 S=4 W=8, a bit is set when that neighbour is the next or previous road cell.
func draw_road(ci: CanvasItem, pos: Vector2, mask: int) -> void:
	draw_frame(ci, "tiles", "road", pos, CELL, CELL, mask, 0)


## Town overlay tile (dual grid like the land, index bit = cell belongs to the town).
## layer: town_ground | town_fence | town_wall. Only the real sheets exist, see town_art().
func draw_town_tile(ci: CanvasItem, layer: String, pos: Vector2, index: int) -> void:
	draw_frame(ci, "tiles", layer, pos, CELL, CELL, index % 4, index / 4)


func town_art() -> bool:
	return has_real("tiles", "town_ground") and has_real("tiles", "town_fence") and has_real("tiles", "town_wall")


## The start cell; the real sheet is 4 frames of a flickering fire.
func draw_camp(ci: CanvasItem, pos: Vector2) -> void:
	draw_frame(ci, "tiles", "camp", pos, CELL, CELL, int(time * CAMP_FPS) % 4, 0)


# --- placeholders ---------------------------------------------------------------------------------


func _placeholder(category: String, id: String) -> Texture2D:
	var img: Image
	match category:
		"tiles":
			img = _ph_tiles(id)
		"map":
			img = _ph_object(id)
		"units":
			img = _ph_unit(id)
		"icons":
			img = _ph_icon(id)
		_:
			img = _new_image(16, 16)
			_rect(img, 0, 0, 16, 16, C["magenta"])  # obvious "missing"
	return ImageTexture.create_from_image(img)


static func _new_image(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for i in w:
		for j in h:
			_px(img, x + i, y + j, c)


static func _disc(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for x in range(int(cx - r) - 1, int(cx + r) + 2):
		for y in range(int(cy - r) - 1, int(cy + r) + 2):
			if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cy)) <= r:
				_px(img, x, y, c)


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
		for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
			var d := Vector2((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
			if d.length() <= 1.0:
				_px(img, x, y, c)


static func _tri(img: Image, x0: int, y0: int, w: int, h: int, c: Color) -> void:
	# isoceles triangle, apex at the top
	for j in h:
		var half := int(round((w / 2.0) * float(j + 1) / h))
		_rect(img, x0 + w / 2 - half, y0 + j, maxi(1, half * 2), 1, c)


func _ph_tiles(id: String) -> Image:
	if id.begins_with("land"):
		id = "land"
	match id:
		"land":
			# dual grid atlas, 4x4 tiles; each quadrant is land when its corner cell is land
			var img := _new_image(64, 64)
			var bg := background()
			for index in 16:
				var ox := (index % 4) * 16
				var oy := (index / 4) * 16
				var quads := [Vector2i(0, 0), Vector2i(8, 0), Vector2i(0, 8), Vector2i(8, 8)]
				for q in 4:
					if index & (1 << q):
						_rect(img, ox + quads[q].x, oy + quads[q].y, 8, 8, C[bg["land"]])
						if (q + index) % 3 == 0:
							_px(img, ox + quads[q].x + 3, oy + quads[q].y + 4, C[bg["edge"]])
			return img
		"road":
			var img := _new_image(16 * 16, 16)
			for mask in 16:
				var ox := mask * 16
				_rect(img, ox + 5, 5, 6, 6, C["tan"])
				if mask & 1:
					_rect(img, ox + 5, 0, 6, 6, C["tan"])
				if mask & 2:
					_rect(img, ox + 10, 5, 6, 6, C["tan"])
				if mask & 4:
					_rect(img, ox + 5, 10, 6, 6, C["tan"])
				if mask & 8:
					_rect(img, ox + 0, 5, 6, 6, C["tan"])
				_px(img, ox + 7, 7, C["brown"])
				_px(img, ox + 9, 9, C["brown"])
			return img
		"camp":
			var img := _new_image(16, 16)
			_rect(img, 0, 0, 16, 16, C["tan"])
			_tri(img, 2, 2, 12, 10, C["red"])
			_rect(img, 7, 8, 2, 4, C["wine"])
			_rect(img, 7, 0, 1, 3, C["white"])
			return img
	var img := _new_image(16, 16)
	_rect(img, 0, 0, 16, 16, C["magenta"])
	return img


## Map object strips: 3 frames (L1..L3) of 16x24. Row 8..23 of a frame is the cell.
func _ph_object(id: String) -> Image:
	var img := _new_image(CELL * 3, OBJ_H)
	for lv in 3:
		var o := lv * CELL
		var n := lv + 1
		match id:
			"rock":
				for k in n:
					_ellipse(img, o + 5 + k * 4, 19 - k, 4 + k * 0.6, 3.5 + k * 0.6, C["slate"])
					_ellipse(img, o + 5 + k * 4, 18 - k, 3 + k * 0.5, 2.5 + k * 0.5, C["silver"])
			"grove":
				for k in n:
					var x := o + 4 + k * 4
					_rect(img, x, 17 - k, 2, 6, C["dark_brown"])
					_disc(img, x + 1, 13 - k * 2, 3.5 + k * 0.5, C["green"])
					_disc(img, x, 12 - k * 2, 2.4, C["lime"])
			"meadow":
				_rect(img, o + 2, 14, 12, 8, C["green"])
				var cols := [C["pink"], C["yellow"], C["white"]]
				for k in n + 2:
					_rect(img, o + 3 + (k * 5) % 11, 15 + (k * 3) % 6, 2, 2, cols[k % 3])
			"spring":
				_ellipse(img, o + 8, 18, 6.5, 4, C["slate"])
				_ellipse(img, o + 8, 18, 5.5, 3.2, C["blue"])
				_ellipse(img, o + 7, 17, 2.5, 1.2, C["cyan"])
				for k in n - 1:
					_px(img, o + 8 + k * 2, 13 - k * 2, C["cyan"])
					_px(img, o + 8 + k * 2, 12 - k * 2, C["white"])
			"slime_nest":
				_ellipse(img, o + 8, 19, 7, 4, C["dark_green"])
				for k in n:
					_ellipse(img, o + 4 + k * 4, 16, 3, 3, C["lime"])
					_px(img, o + 3 + k * 4, 15, C["black"])
					_px(img, o + 5 + k * 4, 15, C["black"])
			"wolf_den":
				_ellipse(img, o + 8, 18, 7, 6, C["dark_slate"])
				_rect(img, o + 4, 17, 8, 6, C["black"])
				for k in n:
					_px(img, o + 5 + k * 2, 19, C["yellow"])
					_px(img, o + 6 + k * 2, 19, C["yellow"])
			"graveyard":
				for k in n:
					var x := o + 2 + k * 5
					_rect(img, x, 15 - k, 4, 8 + k, C["silver"])
					_disc(img, x + 2, 15 - k, 2, C["silver"])
					_rect(img, x + 1, 17 - k, 2, 1, C["dark_slate"])
				_rect(img, o + 1, 22, 14, 2, C["dark_green"])
			"bandit_camp":
				_tri(img, o + 1, 11, 14, 12, C["rust"])
				_rect(img, o + 7, 18, 2, 5, C["black"])
				_rect(img, o + 13 - n, 8, 1, 6, C["dark_brown"])
				_rect(img, o + 14 - n, 8, 3, 2, C["crimson"])
			"house", "house_town":
				_rect(img, o + 3, 14, 10, 9, C["cream"])
				_tri(img, o + 1, 5 - lv, 14, 10 + lv, C["deep_blue"] if id == "house_town" else C["red"])
				_rect(img, o + 7, 18, 3, 5, C["dark_brown"])
				_rect(img, o + 4, 16, 2, 2, C["blue"])
				for k in lv:
					_rect(img, o + 3 + k * 4, 13, 2, 1, C["white"])
			"smithy":
				_rect(img, o + 2, 13, 12, 10, C["dark_slate"])
				_rect(img, o + 2, 11, 12, 3, C["navy_light"])
				_rect(img, o + 10, 6, 3, 6, C["slate"])
				_disc(img, o + 6, 19, 2.5, C["orange"])
				_disc(img, o + 6, 19, 1.2, C["yellow"])
			"shrine":
				_rect(img, o + 3, 13, 2, 10, C["white"])
				_rect(img, o + 11, 13, 2, 10, C["white"])
				_rect(img, o + 1, 11, 14, 3, C["red"])
				_rect(img, o + 3, 8, 10, 2, C["red"])
				_disc(img, o + 8, 19, 1.5, C["gold"])
			"event":
				var bob := (lv % 2)
				_disc(img, o + 8, 14 - bob, 6, C["gold"])
				_disc(img, o + 8, 14 - bob, 4.5, C["yellow"])
				_rect(img, o + 7, 10 - bob, 3, 2, C["wine"])
				_rect(img, o + 9, 12 - bob, 2, 2, C["wine"])
				_rect(img, o + 7, 14 - bob, 2, 2, C["wine"])
				_rect(img, o + 7, 17 - bob, 2, 2, C["wine"])
			"clear":
				for k in 10:
					_rect(img, o + 3 + k, 12 + k, 2, 2, C["red"])
					_rect(img, o + 12 - k, 12 + k, 2, 2, C["red"])
			_:
				_rect(img, o + 2, 10, 12, 12, C["magenta"])
	return img


## Unit sheets: hero = 4 rows (down, left, right, up) x 2 frames; others 1 row x 2 frames.
func _ph_unit(id: String) -> Image:
	if id == "hero":
		var img := _new_image(32, 64)
		for row in 4:
			for f in 2:
				var frame := _new_image(16, 16)
				_draw_hero(frame, row, f)
				img.blit_rect(frame, Rect2i(0, 0, 16, 16), Vector2i(f * 16, row * 16))
		return img
	if id == "boss_warden":
		var img := _new_image(64, 32)
		for f in 2:
			var o := f * 32
			_ellipse(img, o + 16, 29, 11, 2.5, Color(0, 0, 0, 0.35))
			_rect(img, o + 8, 11 + f, 16, 17 - f, C["purple"])
			_disc(img, o + 16, 10 + f, 8, C["magenta"])
			_tri(img, o + 6, 0, 5, 7, C["silver"])
			_tri(img, o + 21, 0, 5, 7, C["silver"])
			_rect(img, o + 11, 9 + f, 3, 3, C["yellow"])
			_rect(img, o + 18, 9 + f, 3, 3, C["yellow"])
			_rect(img, o + 12, 15 + f, 8, 2, C["black"])
		return img
	var img := _new_image(32, 16)
	for f in 2:
		var o := f * 16
		_ellipse(img, o + 8, 14, 5.5, 1.6, Color(0, 0, 0, 0.3))
		match id:
			"slime":
				_ellipse(img, o + 8, 10 + f * 0.5, 6 + f * 0.4, 4.5 - f * 0.5, C["lime"])
				_ellipse(img, o + 8, 9, 3.5, 2, C["yellow"])
				_px(img, o + 6, 10, C["black"])
				_px(img, o + 10, 10, C["black"])
			"wolf":
				_rect(img, o + 3, 8, 10, 5, C["slate"])
				_rect(img, o + 11, 5 + f, 4, 4, C["silver"])
				_rect(img, o + 12, 3 + f, 1, 2, C["silver"])
				_rect(img, o + 14, 7 + f, 2, 1, C["black"])
				_px(img, o + 13, 6 + f, C["red"])
				_rect(img, o + 2, 7, 2, 3, C["dark_slate"])
				_rect(img, o + 4, 13, 2, 1 + f, C["dark_slate"])
				_rect(img, o + 10, 13, 2, 2 - f, C["dark_slate"])
			"skeleton":
				_disc(img, o + 8, 4 + f * 0.5, 3, C["white"])
				_rect(img, o + 6, 4, 1, 2, C["black"])
				_rect(img, o + 9, 4, 1, 2, C["black"])
				_rect(img, o + 7, 7, 2, 5, C["silver"])
				for k in 3:
					_rect(img, o + 5, 8 + k * 2, 6, 1, C["white"])
				_rect(img, o + 6, 12, 1, 3, C["silver"])
				_rect(img, o + 9, 12, 1, 3, C["silver"])
			"bandit":
				_rect(img, o + 5, 7, 6, 6, C["brown"])
				_disc(img, o + 8, 5, 3.2, C["dark_brown"])
				_rect(img, o + 6, 5, 4, 2, C["skin_light"])
				_rect(img, o + 6, 6, 4, 1, C["crimson"])
				_rect(img, o + 4, 8 + f, 1, 4, C["skin"])
				_rect(img, o + 12, 7, 1, 5, C["silver"])
				_rect(img, o + 5, 13, 2, 2, C["wine"])
				_rect(img, o + 9, 13, 2, 2, C["wine"])
			_:
				_rect(img, o + 3, 3, 10, 10, C["magenta"])
	return img


func _draw_hero(img: Image, dir: int, f: int) -> void:
	var ox := 0
	_ellipse(img, ox + 8, 14, 5, 1.6, Color(0, 0, 0, 0.3))
	var step := f
	_rect(img, ox + 5, 12, 2, 3 - step, C["dark_brown"])
	_rect(img, ox + 9, 12, 2, 2 + step, C["dark_brown"])
	_rect(img, ox + 4, 7, 8, 6, C["blue"])
	_rect(img, ox + 4, 11, 8, 1, C["deep_blue"])
	_disc(img, ox + 8, 5, 3.4, C["skin_light"])
	_rect(img, ox + 5, 2, 6, 2, C["brown"])
	match dir:
		0:  # down
			_px(img, ox + 6, 5, C["black"])
			_px(img, ox + 10, 5, C["black"])
			_rect(img, ox + 12, 8 + step, 1, 5, C["silver"])
		1:  # left
			_px(img, ox + 6, 5, C["black"])
			_rect(img, ox + 3, 8 + step, 1, 5, C["silver"])
			_rect(img, ox + 9, 2, 3, 3, C["brown"])
		2:  # right
			_px(img, ox + 10, 5, C["black"])
			_rect(img, ox + 12, 8 + step, 1, 5, C["silver"])
			_rect(img, ox + 4, 2, 3, 3, C["brown"])
		3:  # up
			_rect(img, ox + 5, 2, 6, 4, C["brown"])
			_rect(img, ox + 3, 8 + step, 1, 5, C["silver"])


## Small icons for the UI (16x16): stats, skills, enemies.
func _ph_icon(id: String) -> Image:
	var img := _new_image(16, 16)
	match id:
		"stat_str":
			_rect(img, 3, 9, 10, 3, C["silver"])
			_rect(img, 2, 7, 3, 7, C["slate"])
			_rect(img, 11, 7, 3, 7, C["slate"])
		"stat_agi":
			_tri(img, 3, 3, 10, 10, C["lime"])
			_rect(img, 7, 11, 2, 3, C["green"])
		"stat_int":
			_disc(img, 8, 8, 5, C["purple"])
			_disc(img, 6, 6, 2, C["magenta"])
			_px(img, 11, 4, C["cyan"])
		"skill_fireball":
			_disc(img, 8, 9, 5, C["orange"])
			_disc(img, 8, 9, 3, C["yellow"])
			_tri(img, 5, 1, 6, 6, C["red"])
		"skill_cleave":
			for k in 12:
				_rect(img, 2 + k, 12 - k, 2, 2, C["silver"])
			_rect(img, 2, 3, 12, 1, C["white"])
		_:
			_rect(img, 2, 2, 12, 12, C["slate"])
	return img

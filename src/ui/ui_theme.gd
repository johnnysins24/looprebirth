class_name UiTheme
extends RefCounted
## Layout numbers and drawing helpers shared by every view (docs/design/07-ux.md).
##
## The game draws on a 480x270 grid; the window scales it by whole numbers. All UI is drawn
## in code from this grid, so changing a rectangle here moves the whole screen.

const VIEW := Vector2(480, 270)
const TOP_H := 16.0
const MAP_RECT := Rect2(0, 16, 352, 208)  # 22 x 13 cells of 16 px
const SIDE_RECT := Rect2(352, 16, 128, 208)
const HAND_RECT := Rect2(0, 224, 480, 46)
const CELL := 16

const BG := Color("181425")
const PANEL := Color("262b44")
const PANEL_LIGHT := Color("3a4466")
const BORDER := Color("5a6988")
const TEXT := Color("ffffff")
const TEXT_DIM := Color("8b9bb4")
const GOLD := Color("feae34")
const GOOD := Color("63c74d")
const BAD := Color("e43b44")
const WARN := Color("f77622")
const HP_COL := Color("e43b44")
const MANA_COL := Color("0099db")
const XP_COL := Color("fee761")

const FS := 7  ## body font size
const FS_SMALL := 6
const FS_BIG := 9


static func make() -> Theme:
	var th := Theme.new()
	th.default_font = Art.font()
	th.default_font_size = FS
	return th


static func box(ci: CanvasItem, r: Rect2, fill: Color = PANEL, border: Color = BORDER) -> void:
	ci.draw_rect(r, fill)
	ci.draw_rect(r, border, false, 1.0)


## Draws text with its top-left at (x, y). Returns the width used.
static func text(
	ci: CanvasItem,
	x: float,
	y: float,
	s: String,
	size: int = FS,
	color: Color = TEXT,
	bold: bool = false,
	width: float = -1.0,
	align: int = HORIZONTAL_ALIGNMENT_LEFT
) -> float:
	var f := Art.font(bold)
	var base := Vector2(x, y + f.get_ascent(size)).round()
	ci.draw_string(f, base, s, align, width, size, color)
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func text_width(s: String, size: int = FS, bold: bool = false) -> float:
	return Art.font(bold).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Word-wrapped text (Thai has no spaces, so this wraps by measured width, per character).
## Returns the height used.
static func paragraph(
	ci: CanvasItem, x: float, y: float, w: float, s: String, size: int = FS, color: Color = TEXT, line_h: float = 0.0
) -> float:
	var f := Art.font()
	if line_h <= 0.0:
		line_h = f.get_height(size) + 1.0
	var lines := wrap_text(s, w, size)
	for i in lines.size():
		text(ci, x, y + i * line_h, lines[i], size, color)
	return lines.size() * line_h


static func wrap_text(s: String, w: float, size: int = FS) -> PackedStringArray:
	var f := Art.font()
	var out := PackedStringArray()
	for para in s.split("\n"):
		var cur := ""
		for i in para.length():
			var ch: String = para[i]
			var trial := cur + ch
			if cur != "" and f.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > w:
				out.append(cur)
				cur = ch.strip_edges() if ch == " " else ch
			else:
				cur = trial
		out.append(cur)
	return out


static func bar(ci: CanvasItem, r: Rect2, frac: float, fg: Color, bg: Color = Color(0, 0, 0, 0.55)) -> void:
	ci.draw_rect(r, bg)
	var w := floorf((r.size.x - 2.0) * clampf(frac, 0.0, 1.0))
	if w > 0.0:
		ci.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(w, r.size.y - 2.0)), fg)


static func fmt_time(sec: float) -> String:
	return "%d:%02d" % [int(sec) / 60, int(sec) % 60]


static func pct(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


## 1 decimal, trailing ".0" dropped.
static func num(v: float) -> String:
	var s := "%.1f" % v
	return s.trim_suffix(".0")

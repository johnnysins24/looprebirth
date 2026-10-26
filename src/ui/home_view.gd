class_name HomeView
extends Control
## The screen between runs: Rebirth points, the Rebirth tree (docs/design/06-meta.md), a sketch
## of the next loop when "แผนที่ร่าง" is bought, and the start button.

const COLS := [
	{"branch": "utility", "title": "ยูทิลิตี้"},
	{"branch": "card_unlock", "title": "ปลดล็อกการ์ด"},
	{"branch": "skill_unlock", "title": "ปลดล็อก skill"},
]
const COL_X := 6.0
const COL_W := 86.0
const ROW_H := 28.0
const TREE_Y := 30.0
const PREVIEW_CELL := 8

var game: Game

var _hits: Array[Dictionary] = []
var _flash := ""
var _flash_t := 0.0
var _board: Board = null
var _board_seed := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func setup(p_game: Game) -> void:
	game = p_game


func _process(delta: float) -> void:
	visible = game != null and game.screen == Game.Screen.HOME
	if visible:
		_flash_t = maxf(0.0, _flash_t - delta)
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if game.show_settings:
			return
		for h in _hits:
			if (h["rect"] as Rect2).has_point(event.position):
				_click(h)
				break
		accept_event()


func _click(h: Dictionary) -> void:
	match h["kind"]:
		"node":
			var res := game.meta.check_buy(h["id"])
			if game.meta.buy(h["id"]):
				_say("ซื้อ %s แล้ว" % game.db.nodes[h["id"]].name_th)
			else:
				_say(res["reason"])
		"start":
			game.start_run(game.preview_seed)
		"reroll":
			if game.preview_rerolls < game.meta.rank("map_sketch"):
				game.preview_rerolls += 1
				game.preview_seed = randi()


func _say(text: String) -> void:
	_flash = text
	_flash_t = 2.5


func _draw() -> void:
	if not visible:
		return
	_hits.clear()
	var db := game.db
	var meta := game.meta
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BG)
	UiTheme.text(self, 6, 3, "Rebirth tree", UiTheme.FS_BIG + 1, UiTheme.GOLD, true)
	draw_texture(Art.icon("small/rp"), Vector2(size.x - 190, 4))
	UiTheme.text(self, size.x - 179, 3, "Rebirth point %d" % meta.rp, UiTheme.FS_BIG, UiTheme.TEXT, true)
	var cost := meta.tree_cost()
	UiTheme.text(self, 100, 5, "ซื้อแล้ว %d/%d RP" % [cost[0], cost[1]], UiTheme.FS_SMALL, UiTheme.TEXT_DIM)

	var hover := ""
	for ci in COLS.size():
		var x: float = COL_X + ci * (COL_W + 4.0)
		UiTheme.text(self, x, 19, COLS[ci]["title"], UiTheme.FS_SMALL, UiTheme.TEXT_DIM, true)
		var row := 0
		for id in db.node_order:
			var n: GameDb.NodeDef = db.nodes[id]
			if n.branch != COLS[ci]["branch"]:
				continue
			var r := Rect2(x, TREE_Y + row * ROW_H, COL_W, ROW_H - 2.0)
			if r.has_point(get_local_mouse_position()):
				hover = id
			_draw_node(r, n)
			row += 1

	_draw_info(hover)
	_draw_right()
	if _flash_t > 0.0:
		var w := UiTheme.text_width(_flash, UiTheme.FS, true) + 12.0
		var fr := Rect2((size.x - w) / 2.0, 120, w, 14)
		UiTheme.box(self, fr, UiTheme.PANEL, UiTheme.GOLD)
		UiTheme.text(self, fr.position.x + 6, fr.position.y + 2.5, _flash, UiTheme.FS, UiTheme.GOLD, true)


func _draw_node(r: Rect2, n: GameDb.NodeDef) -> void:
	var meta := game.meta
	var have := meta.rank(n.id)
	var res := meta.check_buy(n.id)
	var maxed := have >= n.ranks
	var locked := not maxed and n.requires != "" and meta.rank(n.requires) < n.requires_rank
	var hov := r.has_point(get_local_mouse_position())
	var fill := Color("1f2237")
	var rim := UiTheme.BORDER
	if maxed:
		fill = Color("203a2a")
		rim = UiTheme.GOOD
	elif res["ok"]:
		rim = UiTheme.GOLD
		fill = Color("2e3150")
	if hov:
		fill = UiTheme.PANEL_LIGHT
	draw_rect(r, fill)
	draw_rect(r, rim, false, 1.0)
	var tint := Color(1, 1, 1, 0.4) if locked else Color.WHITE
	match n.branch:
		"utility":
			draw_texture(Art.icon("node_" + n.id), r.position + Vector2(2, 5), tint)
		"card_unlock":
			Art.draw_object(self, n.unlock_id(), r.position + Vector2(2, 8), 1, tint)
		_:
			draw_texture(Art.icon("skill_" + n.unlock_id()), r.position + Vector2(2, 5), tint)
	UiTheme.text(self, r.position.x + 20, r.position.y + 1, n.name_th, UiTheme.FS_SMALL, UiTheme.TEXT * tint, true, r.size.x - 22)
	# rank pips
	for k in n.ranks:
		var pr := Rect2(r.position.x + 21 + k * 6, r.position.y + 11, 5, 5)
		draw_rect(pr, UiTheme.GOLD if k < have else Color("181425"))
		draw_rect(pr, UiTheme.BORDER, false, 1.0)
	var label := ""
	var col := UiTheme.TEXT_DIM
	if maxed:
		label = "ครบ"
		col = UiTheme.GOOD
	elif locked:
		label = "ล็อก"
	else:
		label = "%d RP" % res["cost"]
		col = UiTheme.GOLD if res["ok"] else UiTheme.TEXT_DIM
	UiTheme.text(self, r.position.x + 20, r.position.y + 16, label, UiTheme.FS_SMALL, col, true)
	_hits.append({"rect": r, "kind": "node", "id": n.id})


func _draw_info(hover: String) -> void:
	var box := Rect2(6, 238, 268, 28)
	UiTheme.box(self, box, Color("181425"), UiTheme.BORDER)
	if hover == "":
		UiTheme.text(self, 10, 241, "ชี้ที่ node เพื่อดูรายละเอียด · คลิกเพื่อซื้อขั้นถัดไป", UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
		UiTheme.text(self, 10, 250, "RP ได้จากเป้าหมายใน run (ข้อละ 1) และฆ่าบอส (2) · เก็บไว้ข้าม run", UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
		return
	var n: GameDb.NodeDef = game.db.nodes[hover]
	var have := game.meta.rank(hover)
	var res := game.meta.check_buy(hover)
	UiTheme.text(self, 10, 241, "%s  (%d/%d)" % [n.name_th, have, n.ranks], UiTheme.FS_SMALL, UiTheme.GOLD, true)
	UiTheme.text(self, 10, 249, n.effect_th, UiTheme.FS_SMALL, UiTheme.TEXT)
	var note := ""
	if have >= n.ranks:
		note = "ซื้อครบแล้ว"
	elif res["ok"]:
		note = "ขั้นถัดไป %d RP" % res["cost"]
	else:
		note = res["reason"]
	UiTheme.text(self, 10, 257, note, UiTheme.FS_SMALL, UiTheme.GOOD if res["ok"] else UiTheme.BAD)


func _draw_right() -> void:
	var meta := game.meta
	var x := 284.0
	UiTheme.text(self, x, 19, "run ทั้งหมด %d · ชนะ %d · รอบสูงสุด %d" % [meta.runs, meta.wins, meta.best_lap], UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
	var box := Rect2(x + 4, 30, 22 * PREVIEW_CELL, 13 * PREVIEW_CELL)
	var sketch := meta.rank("map_sketch")
	UiTheme.box(self, Rect2(box.position - Vector2(1, 1), box.size + Vector2(2, 2)), Art.color(Art.background()["bg"]), UiTheme.BORDER)
	if sketch > 0:
		_draw_preview(box)
		var left := sketch - game.preview_rerolls
		var rr := Rect2(box.position.x, box.end.y + 4, 100, 13)
		_button(rr, "สุ่มแผนที่ใหม่ (เหลือ %d)" % left, "reroll", left > 0)
	else:
		UiTheme.paragraph(self, box.position.x + 14, box.position.y + 36, box.size.x - 28, "แผนที่ของ run หน้าจะสุ่มตอนเริ่ม\nซื้อ \"แผนที่ร่าง\" เพื่อดูตัวอย่างและสุ่มใหม่ได้", UiTheme.FS_SMALL, UiTheme.TEXT_DIM, 9.0)
	var sr := Rect2(box.position.x, 176, box.size.x, 24)
	_button(sr, "เริ่ม run  (Enter)", "start", true, true)
	var tips := [
		"ลากการ์ดจากมือไปวางบนแผนที่ · skill card ลากไปช่อง skill ของฮีโร่",
		"เมืองโต (บ้านติดกัน 3 และ 6 หลัง) ได้ perk แต่ดึงโจรมา",
		"ครบ 10 รอบ บอสจะมาที่ค่าย",
	]
	var ty := 206.0
	for t in tips:
		ty += UiTheme.paragraph(self, x + 4, ty, 176, t, UiTheme.FS_SMALL, UiTheme.TEXT_DIM, 7.5) + 1.0


func _button(r: Rect2, label: String, kind: String, enabled: bool = true, big: bool = false) -> void:
	var hov := r.has_point(get_local_mouse_position()) and enabled
	UiTheme.box(self, r, UiTheme.GOLD if hov else (UiTheme.PANEL_LIGHT if enabled else Color("1f2237")), UiTheme.GOLD if big else UiTheme.BORDER)
	var fs := UiTheme.FS_BIG if big else UiTheme.FS_SMALL
	var w := UiTheme.text_width(label, fs, true)
	UiTheme.text(self, r.position.x + (r.size.x - w) / 2.0, r.position.y + (r.size.y - (11.0 if big else 9.0)) / 2.0, label, fs, Color("181425") if hov else (UiTheme.TEXT if enabled else UiTheme.TEXT_DIM), true)
	if enabled:
		_hits.append({"rect": r, "kind": kind})


## The loop of the next run, 8 px per cell: sea, land, road, camp.
func _draw_preview(box: Rect2) -> void:
	if _board == null or _board_seed != game.preview_seed:
		_board = LoopGenerator.generate(game.db, game.preview_seed)
		_board_seed = game.preview_seed
	var bg := Art.background()
	draw_rect(box, Art.color(bg["bg"]))
	for x in _board.cols:
		for y in _board.rows:
			var c := Vector2i(x, y)
			var cr := Rect2(box.position + Vector2(x, y) * PREVIEW_CELL, Vector2(PREVIEW_CELL, PREVIEW_CELL))
			match _board.kind_at(c):
				Board.Kind.SEA:
					continue
				Board.Kind.ROAD:
					draw_rect(cr, Art.color("cream"))
				Board.Kind.CAMP:
					draw_rect(cr, Art.color("gold"))
				_:
					draw_rect(cr, Art.color(bg["land"]))
	var camp := box.position + Vector2(_board.camp()) * PREVIEW_CELL
	draw_rect(Rect2(camp, Vector2(PREVIEW_CELL, PREVIEW_CELL)), UiTheme.BAD, false, 1.0)
	UiTheme.text(self, box.position.x + 2, box.end.y - 8, "%d ช่องทาง" % _board.path.size(), UiTheme.FS_SMALL, UiTheme.TEXT)

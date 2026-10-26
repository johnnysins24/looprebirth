class_name ChoicePanel
extends Control
## The window a notification opens: spend stat points, or pick a lap card. Sits over the
## map; the game pauses while it is open unless the player turned that off.

var run: RunState
var game: Game

var _hits: Array[Dictionary] = []
var _hover := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func setup(p_run: RunState, p_game: Game) -> void:
	run = p_run
	game = p_game


func _process(_d: float) -> void:
	visible = game.open_notice != null
	if visible:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if game.open_notice == null:
		return
	if event is InputEventMouseMotion:
		_hover = -1
		for i in _hits.size():
			if (_hits[i]["rect"] as Rect2).has_point(event.position):
				_hover = i
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for h in _hits:
			if (h["rect"] as Rect2).has_point(event.position):
				_click(h)
				break
		accept_event()


func _click(h: Dictionary) -> void:
	var n := game.open_notice
	match h["kind"]:
		"close":
			game.close_notice_panel()
		"spend":
			run.spend_point(h["stat"])
			if not run.notices.has(n):
				game.after_notice_done(n)
		"offer":
			if run.choose_offer(n, h["index"]):
				game.after_notice_done(n)


func _draw() -> void:
	var n := game.open_notice
	if n == null or run == null:
		return
	_hits.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	match n.kind:
		"stat":
			_draw_stat(n)
		"lap_card":
			_draw_cards(n)


func _panel(w: float, h: float) -> Rect2:
	var r := Rect2((size.x - w) / 2.0, (size.y - h) / 2.0, w, h)
	UiTheme.box(self, r, UiTheme.PANEL, UiTheme.GOLD)
	return r


func _button(r: Rect2, label: String, kind: String, extra: Dictionary = {}, enabled: bool = true) -> void:
	var hov := r.has_point(get_local_mouse_position()) and enabled
	UiTheme.box(self, r, UiTheme.GOLD if hov else (UiTheme.PANEL_LIGHT if enabled else Color("1f2237")), UiTheme.BORDER)
	var w := UiTheme.text_width(label, UiTheme.FS_SMALL, true)
	UiTheme.text(self, r.position.x + (r.size.x - w) / 2.0, r.position.y + (r.size.y - 9.0) / 2.0, label, UiTheme.FS_SMALL, (Color("181425") if hov else (UiTheme.TEXT if enabled else UiTheme.TEXT_DIM)), true)
	if enabled:
		var h := {"rect": r, "kind": kind}
		h.merge(extra)
		_hits.append(h)


func _draw_stat(n: Notice) -> void:
	var h := run.hero
	var r := _panel(250, 164)
	UiTheme.text(self, r.position.x + 8, r.position.y + 6, n.title, UiTheme.FS_BIG, UiTheme.GOLD, true)
	var left := int(n.payload.get("remaining", 0))
	UiTheme.text(self, r.position.x + 8, r.position.y + 18, "แต้มที่ใช้ได้ %d  (แต้มรวม %d)  ·  แต้มรีเซ็ตเมื่อจบ run" % [left, h.unspent], UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
	var rows := [
		["str", "STR", "ATK +1, max HP +6"],
		["agi", "AGI", "ตีเร็ว +5%, หลบ +1.2%"],
		["int", "INT", "AP +2, mana +4, mana ฟื้น +0.15/วิ"],
	]
	var y := r.position.y + 30.0
	var hover_stat := ""
	for i in 3:
		var row: Array = rows[i]
		var rr := Rect2(r.position.x + 6, y, r.size.x - 12, 24)
		var hov := rr.has_point(get_local_mouse_position())
		if hov:
			hover_stat = row[0]
		draw_rect(rr, UiTheme.PANEL_LIGHT if hov else Color("1f2237"))
		draw_texture(Art.icon("stat_" + row[0]), rr.position + Vector2(3, 4))
		UiTheme.text(self, rr.position.x + 24, rr.position.y + 2, "%s  %d" % [row[1], h.pts[row[0]]], UiTheme.FS, UiTheme.TEXT, true)
		UiTheme.text(self, rr.position.x + 24, rr.position.y + 12, row[2], UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
		_button(Rect2(rr.end.x - 24, rr.position.y + 3, 20, 18), "+1", "spend", {"stat": row[0]}, h.unspent > 0)
		y += 26.0
	# what the hovered point would change
	var py := y + 3.0
	UiTheme.text(self, r.position.x + 8, py, "ผลต่อค่า (เมื่อกด +1 ที่แถวที่ชี้)", UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
	py += 9.0
	var shown := PackedStringArray()
	if hover_stat != "":
		var np: Dictionary = h.pts.duplicate()
		np[hover_stat] += 1
		var after := h.compute(np)
		var now := h.compute(h.pts)
		var labels := {"max_hp": "HP", "atk": "ATK", "aps": "ตี/วิ", "evasion": "หลบ", "ap": "AP", "max_mana": "MANA", "mana_regen": "mana/วิ"}
		for k in labels:
			if absf(after[k] - now[k]) > 0.0001:
				var fmt := "%s %s→%s"
				var a: String = UiTheme.pct(now[k]) if k == "evasion" else ("%.2f" % now[k] if k == "aps" or k == "mana_regen" else UiTheme.num(now[k]))
				var b: String = UiTheme.pct(after[k]) if k == "evasion" else ("%.2f" % after[k] if k == "aps" or k == "mana_regen" else UiTheme.num(after[k]))
				if k == "evasion":
					a = "%.1f%%" % (now[k] * 100.0)
					b = "%.1f%%" % (after[k] * 100.0)
				shown.append(fmt % [labels[k], a, b])
	if shown.is_empty():
		UiTheme.text(self, r.position.x + 8, py, "ชี้ที่ STR / AGI / INT เพื่อดูผล", UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
	else:
		UiTheme.paragraph(self, r.position.x + 8, py, r.size.x - 16, "  ".join(shown), UiTheme.FS_SMALL, UiTheme.GOOD, 8.0)
	_button(Rect2(r.end.x - 52, r.end.y - 18, 46, 13), "ปิด (Esc)", "close")


func _draw_cards(n: Notice) -> void:
	var offers: Array = n.payload["offers"]
	var r := _panel(300, 22 + offers.size() * 50 + 20)
	UiTheme.text(self, r.position.x + 8, r.position.y + 6, "%s  ·  %s" % [n.title, n.detail], UiTheme.FS, UiTheme.GOLD, true)
	var y := r.position.y + 20.0
	for i in offers.size():
		var card: CardInst = offers[i]
		var def: GameDb.CardDef = run.db.cards[card.id]
		var rr := Rect2(r.position.x + 6, y, r.size.x - 12, 48)
		var hov := rr.has_point(get_local_mouse_position())
		draw_rect(rr, UiTheme.PANEL_LIGHT if hov else Color("1f2237"))
		if hov:
			draw_rect(rr, UiTheme.GOLD, false, 1.0)
		CardView.draw_card(self, rr.position + Vector2(2, 2), run.db, card.id, 1)
		var tx := rr.position.x + 40
		UiTheme.text(self, tx, rr.position.y + 2, def.name_th, UiTheme.FS, UiTheme.TEXT, true)
		UiTheme.paragraph(self, tx, rr.position.y + 13, rr.size.x - 46, def.describe(1), UiTheme.FS_SMALL, UiTheme.TEXT, 7.5)
		UiTheme.text(self, tx, rr.position.y + 28, def.place_th, UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
		var have := _owned(card.id)
		if have != "":
			UiTheme.text(self, tx, rr.position.y + 37, have, UiTheme.FS_SMALL, UiTheme.GOLD, true)
		_hits.append({"rect": rr, "kind": "offer", "index": i})
		y += 50.0
	_button(Rect2(r.end.x - 52, r.end.y - 18, 46, 13), "ปิด (Esc)", "close")


## "มีบนแผนที่ x2 · ในมือ x1": a hint that this card merges with what the player has.
func _owned(card_id: String) -> String:
	var on_map := 0
	for c: Vector2i in run.placed:
		if run.placed[c].id == card_id:
			on_map += 1
	var in_hand := 0
	for c in run.hand:
		if c.id == card_id:
			in_hand += 1
	if on_map == 0 and in_hand == 0:
		return ""
	return "ใช้ merge ได้: บนแผนที่ x%d · ในมือ x%d" % [on_map, in_hand]

class_name EndPanel
extends Control
## Shown when the run is over: result, totals, goals and the Rebirth points they paid, and
## the way on (Rebirth tree, or another run straight away).

var run: RunState
var game: Game

var _hits: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func setup(p_run: RunState, p_game: Game) -> void:
	run = p_run
	game = p_game


func _process(_d: float) -> void:
	visible = run != null and run.phase == RunState.Phase.ENDED and game.screen == Game.Screen.RUN
	if visible:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for h in _hits:
			if (h["rect"] as Rect2).has_point(event.position):
				match h["kind"]:
					"home":
						game.open_home()
					"again":
						game.start_run(randi())
					"same":
						game.start_run(run.seed_value)
				break
		accept_event()


func _draw() -> void:
	if not visible:
		return
	_hits.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var s := run.summary()
	var goals: Array = s["goals"]
	var h := 150.0 + goals.size() * 9.0
	var r := Rect2((size.x - 270) / 2.0, (size.y - h) / 2.0, 270, h)
	UiTheme.box(self, r, UiTheme.PANEL, UiTheme.GOOD if s["won"] else UiTheme.BAD)
	var title := "ชนะบอส! จบ run" if s["won"] else "ฮีโร่ล้มลง จบ run"
	var tw := UiTheme.text_width(title, UiTheme.FS_BIG + 2, true)
	UiTheme.text(self, r.position.x + (r.size.x - tw) / 2.0, r.position.y + 8, title, UiTheme.FS_BIG + 2, UiTheme.GOOD if s["won"] else UiTheme.BAD, true)
	var left := [
		["รอบที่ถึง", "%d / %d" % [mini(s["lap"], run.db.ci("boss_lap")), run.db.ci("boss_lap")]],
		["level", str(s["level"])],
		["เวลา", UiTheme.fmt_time(s["time"])],
	]
	var right := [
		["ต่อสู้ / ฆ่า", "%d / %d" % [s["fights"], s["kills"]]],
		["การ์ด / combo", "%d / %d" % [s["cards_played"], s["combos"]]],
		["เมืองสูงสุด", Town.NAMES[clampi(s["town_tier"], 0, 2)]],
	]
	var y := r.position.y + 26.0
	for i in 3:
		UiTheme.text(self, r.position.x + 14, y, left[i][0], UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
		UiTheme.text(self, r.position.x + 62, y, left[i][1], UiTheme.FS_SMALL, UiTheme.TEXT, true)
		UiTheme.text(self, r.position.x + 140, y, right[i][0], UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
		UiTheme.text(self, r.position.x + 196, y, right[i][1], UiTheme.FS_SMALL, UiTheme.TEXT, true, 70)
		y += 9.5
	y += 3.0
	UiTheme.text(self, r.position.x + 14, y, "เป้าหมาย run", UiTheme.FS_SMALL, UiTheme.GOLD, true)
	y += 9.0
	for g: Dictionary in goals:
		var col: Color = UiTheme.GOOD if g["done"] else UiTheme.TEXT_DIM
		if g["done"]:
			draw_texture(Art.icon("small/check"), Vector2(r.position.x + 13, y - 1))
		else:
			draw_rect(Rect2(r.position.x + 14, y + 0.5, 6, 6), UiTheme.BORDER, false, 1.0)
		UiTheme.text(self, r.position.x + 24, y, g["text"], UiTheme.FS_SMALL, col, false, 200)
		UiTheme.text(self, r.end.x - 34, y, "+%d RP" % g["rp"] if g["done"] else "", UiTheme.FS_SMALL, UiTheme.GOLD, true)
		y += 9.0
	y += 3.0
	draw_texture(Art.icon("small/rp"), Vector2(r.position.x + 13, y - 1))
	UiTheme.text(self, r.position.x + 24, y, "Rebirth point ที่ได้ใน run นี้ +%d  (มีทั้งหมด %d)" % [s["rp"], game.meta.rp], UiTheme.FS_SMALL, UiTheme.GOLD, true)
	var by := r.end.y - 22.0
	_button(Rect2(r.position.x + 10, by, 84, 15), "Rebirth tree", "home")
	_button(Rect2(r.position.x + 98, by, 84, 15), "เล่นใหม่ (R)", "again")
	_button(Rect2(r.position.x + 186, by, 74, 15), "seed เดิม", "same")


func _button(r: Rect2, label: String, kind: String) -> void:
	var hov := r.has_point(get_local_mouse_position())
	UiTheme.box(self, r, UiTheme.GOLD if hov else UiTheme.PANEL_LIGHT, UiTheme.BORDER)
	var w := UiTheme.text_width(label, UiTheme.FS_SMALL, true)
	UiTheme.text(self, r.position.x + (r.size.x - w) / 2.0, r.position.y + 3, label, UiTheme.FS_SMALL, Color("181425") if hov else UiTheme.TEXT, true)
	_hits.append({"rect": r, "kind": kind})

class_name EndPanel
extends Control
## Shown when the run is over: result, totals, and how to go again.

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
	visible = run != null and run.phase == RunState.Phase.ENDED
	if visible:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for h in _hits:
			if (h["rect"] as Rect2).has_point(event.position):
				game.start_run(h["seed"])
				break
		accept_event()


func _draw() -> void:
	if not visible:
		return
	_hits.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var s := run.summary()
	var r := Rect2((size.x - 230) / 2.0, (size.y - 150) / 2.0, 230, 150)
	UiTheme.box(self, r, UiTheme.PANEL, UiTheme.GOOD if s["won"] else UiTheme.BAD)
	var title := "ชนะบอส! จบ run" if s["won"] else "ฮีโร่ล้มลง จบ run"
	var tw := UiTheme.text_width(title, UiTheme.FS_BIG + 2, true)
	UiTheme.text(self, r.position.x + (r.size.x - tw) / 2.0, r.position.y + 8, title, UiTheme.FS_BIG + 2, UiTheme.GOOD if s["won"] else UiTheme.BAD, true)
	var rows := [
		["รอบที่ถึง", "%d / %d" % [mini(s["lap"], run.db.ci("boss_lap")), run.db.ci("boss_lap")]],
		["level", str(s["level"])],
		["เวลา", UiTheme.fmt_time(s["time"])],
		["ต่อสู้ / ศัตรูที่ฆ่า", "%d / %d" % [s["fights"], s["kills"]]],
		["การ์ดที่วาง / combo", "%d / %d" % [s["cards_played"], s["combos"]]],
		["seed", str(s["seed"])],
	]
	var y := r.position.y + 28.0
	for row in rows:
		UiTheme.text(self, r.position.x + 20, y, row[0], UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
		UiTheme.text(self, r.position.x + 130, y, row[1], UiTheme.FS_SMALL, UiTheme.TEXT, true)
		y += 10.0
	UiTheme.text(self, r.position.x + 20, y + 2, "Rebirth point: ยังไม่เปิดใช้ (เฟส 5)", UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
	var b1 := Rect2(r.position.x + 14, r.end.y - 22, 100, 15)
	var b2 := Rect2(r.end.x - 114, r.end.y - 22, 100, 15)
	_button(b1, "เล่นใหม่ (R)", randi())
	_button(b2, "seed เดิม (Shift+R)", run.seed_value)


func _button(r: Rect2, label: String, seed_value: int) -> void:
	var hov := r.has_point(get_local_mouse_position())
	UiTheme.box(self, r, UiTheme.GOLD if hov else UiTheme.PANEL_LIGHT, UiTheme.BORDER)
	var w := UiTheme.text_width(label, UiTheme.FS_SMALL, true)
	UiTheme.text(self, r.position.x + (r.size.x - w) / 2.0, r.position.y + 3, label, UiTheme.FS_SMALL, Color("181425") if hov else UiTheme.TEXT, true)
	_hits.append({"rect": r, "seed": seed_value})

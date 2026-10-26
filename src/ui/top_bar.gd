class_name TopBar
extends Control
## 16 px strip: HP, mana, level and XP, lap, time, speed buttons.

var run: RunState
var game: Game

var _buttons: Array[Dictionary] = []  # {rect, speed}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(p_run: RunState, p_game: Game) -> void:
	run = p_run
	game = p_game


func _process(_d: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for b in _buttons:
			if (b["rect"] as Rect2).has_point(event.position):
				game.set_speed(b["speed"])
				accept_event()
				return


func _draw() -> void:
	if run == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.PANEL)
	draw_line(Vector2(0, size.y - 0.5), Vector2(size.x, size.y - 0.5), UiTheme.BORDER)
	var h := run.hero
	# HP
	UiTheme.bar(self, Rect2(2, 3, 70, 10), h.hp / h.max_hp, UiTheme.HP_COL)
	UiTheme.text(self, 5, 3, "HP %d/%d" % [ceili(h.hp), roundi(h.max_hp)], UiTheme.FS_SMALL, UiTheme.TEXT, true)
	# mana (only has meaning during a fight)
	var mana_frac := 0.0
	var mana_txt := "MP"
	if run.battle != null:
		mana_frac = run.battle.mana / h.max_mana
		mana_txt = "MP %d" % roundi(run.battle.mana)
	UiTheme.bar(self, Rect2(75, 3, 40, 10), mana_frac, UiTheme.MANA_COL)
	UiTheme.text(self, 78, 3, mana_txt, UiTheme.FS_SMALL, UiTheme.TEXT, true)
	# level and XP
	UiTheme.bar(self, Rect2(118, 3, 62, 10), float(h.xp) / h.xp_needed(), UiTheme.XP_COL)
	UiTheme.text(self, 121, 3, "Lv %d  %d/%d" % [h.level, h.xp, h.xp_needed()], UiTheme.FS_SMALL, UiTheme.TEXT, true)
	# lap and time
	var boss_lap := run.db.ci("boss_lap")
	var lap_txt := "รอบ %d/%d" % [mini(run.lap, boss_lap), boss_lap]
	UiTheme.text(self, 186, 3, lap_txt, UiTheme.FS, UiTheme.GOLD, true)
	UiTheme.text(self, 238, 3, UiTheme.fmt_time(run.time), UiTheme.FS, UiTheme.TEXT_DIM)
	# unspent stat points
	if h.unspent > 0:
		UiTheme.text(self, 266, 3, "แต้ม +%d" % h.unspent, UiTheme.FS_SMALL, UiTheme.GOOD, true)
	# speed buttons
	_buttons.clear()
	var labels := [["II", 0], ["x1", 1], ["x2", 2], ["x4", 4]]
	var x := size.x - 4.0 * 21.0 - 2.0
	for l in labels:
		var r := Rect2(x, 2, 19, 12)
		var on: bool = game.speed == l[1]
		UiTheme.box(self, r, UiTheme.GOLD if on else UiTheme.PANEL_LIGHT, UiTheme.BORDER)
		var w := UiTheme.text_width(l[0], UiTheme.FS_SMALL, true)
		UiTheme.text(self, r.position.x + (r.size.x - w) / 2.0, 3.5, l[0], UiTheme.FS_SMALL, Color("181425") if on else UiTheme.TEXT, true)
		_buttons.append({"rect": r, "speed": l[1]})
		x += 21.0

class_name SidePanel
extends Control
## Right column (docs/design/07-ux.md): the notification list on top, hero stats or the
## last fight's explanation below.

const ROW_H := 15.0
const LIST_TOP := 12.0
const LIST_ROWS := 6
const TABS_Y := 106.0

var run: RunState
var game: Game

var tab := 0  ## 0 hero, 1 last fight
var scroll := 0

var _hits: Array[Dictionary] = []  # {rect, kind, ...}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(p_run: RunState, p_game: Game) -> void:
	run = p_run
	game = p_game
	scroll = 0


func _process(_d: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll = mini(scroll + 1, maxi(0, run.notices.size() - LIST_ROWS))
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll = maxi(0, scroll - 1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			for h in _hits:
				if (h["rect"] as Rect2).has_point(event.position):
					match h["kind"]:
						"notice":
							game.open_notice_panel(h["notice"])
						"tab":
							tab = h["tab"]
						"auto":
							game.auto_open = not game.auto_open
						"pause":
							game.pause_on_panel = not game.pause_on_panel
					accept_event()
					return


func _draw() -> void:
	if run == null:
		return
	_hits.clear()
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.PANEL)
	draw_line(Vector2(0.5, 0), Vector2(0.5, size.y), UiTheme.BORDER)
	_draw_notices()
	_draw_tabs()
	if tab == 0:
		_draw_hero()
	else:
		_draw_last_fight()


func _checkbox(x: float, y: float, label: String, on: bool, kind: String) -> void:
	var r := Rect2(x, y, 7, 7)
	UiTheme.box(self, r, UiTheme.GOLD if on else Color("181425"), UiTheme.BORDER)
	var w := UiTheme.text(self, x + 9, y - 1.5, label, UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
	_hits.append({"rect": Rect2(x, y - 2, 9 + w, 11), "kind": kind})


func _draw_notices() -> void:
	var list := run.notices
	scroll = clampi(scroll, 0, maxi(0, list.size() - LIST_ROWS))
	var head := "แจ้งเตือน (%d)" % list.size()
	if list.size() > LIST_ROWS:  # the wheel scrolls; say which rows are showing
		head = "แจ้งเตือน %d-%d/%d" % [scroll + 1, mini(scroll + LIST_ROWS, list.size()), list.size()]
	UiTheme.text(self, 4, 1, head, UiTheme.FS_SMALL, UiTheme.GOLD, true)
	_checkbox(60, 3, "เปิดเองตอนครบรอบ", game.auto_open, "auto")
	for i in LIST_ROWS:
		var k := scroll + i
		var r := Rect2(2, LIST_TOP + i * ROW_H, size.x - 4, ROW_H - 1)
		if k >= list.size():
			draw_rect(r, Color(1, 1, 1, 0.03))
			continue
		var n: Notice = list[k]
		var hover := r.has_point(get_local_mouse_position())
		draw_rect(r, UiTheme.PANEL_LIGHT if hover else Color("1f2237"))
		var tag := UiTheme.GOOD if n.kind == "stat" else (UiTheme.GOLD if n.kind == "lap_card" else UiTheme.TEXT_DIM)
		draw_rect(Rect2(r.position, Vector2(3, r.size.y)), tag)
		UiTheme.text(self, r.position.x + 6, r.position.y + 0.5, n.title, UiTheme.FS_SMALL, UiTheme.TEXT, true, r.size.x - 8)
		UiTheme.text(self, r.position.x + 6, r.position.y + 7, n.detail, UiTheme.FS_SMALL, UiTheme.TEXT_DIM, false, r.size.x - 8)
		_hits.append({"rect": r, "kind": "notice", "notice": n})


func _draw_tabs() -> void:
	var names := ["ฮีโร่", "ต่อสู้ล่าสุด"]
	var x := 2.0
	for i in 2:
		var w := UiTheme.text_width(names[i], UiTheme.FS_SMALL, true) + 10.0
		var r := Rect2(x, TABS_Y, w, 11)
		UiTheme.box(self, r, UiTheme.BORDER if tab == i else Color("1f2237"), UiTheme.BORDER)
		UiTheme.text(self, x + 5, TABS_Y + 1.5, names[i], UiTheme.FS_SMALL, UiTheme.TEXT if tab == i else UiTheme.TEXT_DIM, true)
		_hits.append({"rect": r, "kind": "tab", "tab": i})
		x += w + 2.0
	_checkbox(size.x - 49, TABS_Y + 2, "หยุดเมื่อเปิดแผง", game.pause_on_panel, "pause")


func _draw_hero() -> void:
	var h := run.hero
	var y := TABS_Y + 14.0
	UiTheme.text(self, 4, y, "Lv %d" % h.level, UiTheme.FS, UiTheme.GOLD, true)
	UiTheme.text(self, 30, y, "STR %d  AGI %d  INT %d" % [h.pts["str"], h.pts["agi"], h.pts["int"]], UiTheme.FS_SMALL, UiTheme.TEXT)
	y += 10.0
	var rows := [
		["ATK", UiTheme.num(h.atk), "HP", "%d/%d" % [ceili(h.hp), roundi(h.max_hp)]],
		["ตี/วิ", "%.2f" % h.aps, "หลบ", UiTheme.pct(h.evasion)],
		["AP", UiTheme.num(h.ap), "MANA", "%d +%.1f/วิ" % [roundi(h.max_mana), h.mana_regen]],
		["คริ", UiTheme.pct(h.crit), "คริดาเมจ", "x%.1f" % h.crit_damage],
	]
	for r in rows:
		UiTheme.text(self, 4, y, r[0], UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
		UiTheme.text(self, 24, y, r[1], UiTheme.FS_SMALL, UiTheme.TEXT, true)
		UiTheme.text(self, 62, y, r[2], UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
		UiTheme.text(self, 84, y, r[3], UiTheme.FS_SMALL, UiTheme.TEXT, true)
		y += 8.5
	y += 2.0
	# skill slots
	for i in 2:
		var x := 4.0 + i * 62.0
		var slot: Dictionary = h.skills[i] if i < h.skills.size() else {}
		draw_rect(Rect2(x, y, 60, 18), Color("181425"))
		draw_rect(Rect2(x, y, 60, 18), UiTheme.BORDER, false, 1.0)
		if not slot.is_empty():
			var sd: GameDb.SkillDef = run.db.skills[slot["id"]]
			draw_texture(Art.icon("skill_" + slot["id"]), Vector2(x + 1, y + 1))
			UiTheme.text(self, x + 18, y + 1, sd.name_th, UiTheme.FS_SMALL, UiTheme.TEXT, true)
			UiTheme.text(self, x + 18, y + 9, "L%d  %d mana" % [slot["level"], roundi(sd.mana)], UiTheme.FS_SMALL, UiTheme.GOLD)
	y += 20.0
	var notes: Array[String] = []
	for source in h.mods:
		var m: Dictionary = h.mods[source]
		var parts := PackedStringArray()
		for k in m:
			parts.append("%s %s" % [_stat_name(k), UiTheme.num(m[k])])
		var label := "ของตัวแทน" if source == "gear_standin" else "ภูมิประเทศ"
		notes.append("%s: %s" % [label, ", ".join(parts)])
	for n in notes:
		UiTheme.paragraph(self, 4, y, size.x - 8, n, UiTheme.FS_SMALL, UiTheme.TEXT_DIM, 7.0)
		y += 8.0 * ceilf(UiTheme.text_width(n, UiTheme.FS_SMALL) / (size.x - 8.0))


func _stat_name(k: String) -> String:
	match k:
		"max_hp":
			return "HP"
		"atk":
			return "ATK"
		"ap":
			return "AP"
		"max_mana":
			return "MANA"
		"attack_speed":
			return "ตี%"
		"evasion":
			return "หลบ"
		"crit":
			return "คริ"
		"mana_regen":
			return "mana/วิ"
	return k


func _draw_last_fight() -> void:
	var y := TABS_Y + 14.0
	var lf := run.last_fight
	if lf.is_empty():
		UiTheme.paragraph(self, 4, y, size.x - 8, "ยังไม่มีการต่อสู้", UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
		return
	var head := "%s  %s (รอบ %d)" % ["ชนะ" if lf["won"] else "แพ้", lf["spawn"], lf["lap"]]
	UiTheme.text(self, 4, y, head, UiTheme.FS_SMALL, UiTheme.GOOD if lf["won"] else UiTheme.BAD, true)
	y += 9.0
	for line in lf["lines"]:
		y += UiTheme.paragraph(self, 4, y, size.x - 8, line, UiTheme.FS_SMALL, UiTheme.TEXT, 7.0)
		if y > size.y - 8:
			break
	UiTheme.text(self, 4, size.y - 8, "กด L ดูบันทึกเต็ม", UiTheme.FS_SMALL, UiTheme.TEXT_DIM)

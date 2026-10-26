class_name SettingsView
extends Control
## Settings window (button "ตั้งค่า" on the side panel). The game is paused while it is open.

var game: Game

var _hits: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func setup(p_game: Game) -> void:
	game = p_game


func _process(_d: float) -> void:
	visible = game != null and game.show_settings
	if visible:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for h in _hits:
			if (h["rect"] as Rect2).has_point(event.position):
				_click(h)
				break
		accept_event()


func _click(h: Dictionary) -> void:
	match h["kind"]:
		"auto_open":
			game.auto_open = not game.auto_open
		"pause":
			game.pause_on_panel = not game.pause_on_panel
		"auto_equip":
			game.set_auto_equip(not game.auto_equip)
		"bg":
			Art.cycle_background()
		"close":
			game.show_settings = false
		"leave":
			game.show_settings = false
			game.open_home()
	game._save_settings()


func _draw() -> void:
	if not visible:
		return
	_hits.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var r := Rect2((size.x - 250) / 2.0, (size.y - 150) / 2.0, 250, 150)
	UiTheme.box(self, r, UiTheme.PANEL, UiTheme.GOLD)
	UiTheme.text(self, r.position.x + 8, r.position.y + 6, "ตั้งค่า", UiTheme.FS_BIG, UiTheme.GOLD, true)
	var y := r.position.y + 24.0
	y = _check(r.position.x + 10, y, "เปิดแผงเลือกเองตอนครบรอบ", "ครบรอบแล้วเกมหยุดและเปิดตัวเลือกที่ค้างทีละอัน", game.auto_open, "auto_open")
	y = _check(r.position.x + 10, y, "หยุดเกมตอนเปิดแผงเลือก", "ปิดไว้ถ้าอยากให้ฮีโร่เดินต่อระหว่างเลือก", game.pause_on_panel, "pause")
	y = _check(r.position.x + 10, y, "ใส่ของที่ดีกว่าอัตโนมัติ", "ของที่ rarity หรือระดับสูงกว่าที่ใส่อยู่ จะถูกใส่ทันที", game.auto_equip, "auto_equip")
	var bg_label := "พื้นหลังแผนที่: %s  (กดเพื่อสลับ · ปุ่ม B)" % Art.background()["name"]
	var br := Rect2(r.position.x + 10, y + 2, 170, 13)
	_btn(br, bg_label, "bg")
	_btn(Rect2(r.position.x + 10, r.end.y - 20, 100, 13), "ออกจาก run ไปหน้าหลัก", "leave")
	_btn(Rect2(r.end.x - 60, r.end.y - 20, 52, 13), "ปิด (Esc)", "close")


func _check(x: float, y: float, label: String, hint: String, on: bool, kind: String) -> float:
	var box := Rect2(x, y + 1, 8, 8)
	UiTheme.box(self, box, UiTheme.GOLD if on else Color("181425"), UiTheme.BORDER)
	UiTheme.text(self, x + 12, y - 0.5, label, UiTheme.FS_SMALL, UiTheme.TEXT, true)
	UiTheme.text(self, x + 12, y + 7, hint, UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
	_hits.append({"rect": Rect2(x, y, 230, 16), "kind": kind})
	return y + 18.0


func _btn(r: Rect2, label: String, kind: String) -> void:
	var hov := r.has_point(get_local_mouse_position())
	UiTheme.box(self, r, UiTheme.GOLD if hov else UiTheme.PANEL_LIGHT, UiTheme.BORDER)
	var w := UiTheme.text_width(label, UiTheme.FS_SMALL, true)
	UiTheme.text(self, r.position.x + (r.size.x - w) / 2.0, r.position.y + 2.5, label, UiTheme.FS_SMALL, Color("181425") if hov else UiTheme.TEXT, true)
	_hits.append({"rect": r, "kind": kind})

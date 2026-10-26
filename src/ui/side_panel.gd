class_name SidePanel
extends Control
## Right column (docs/design/07-ux.md): the notification list on top, a tab with hero, town,
## goals or the last fight in the middle, and the hero's skill slots and gear at the bottom.

const ROW_H := 16.0
const LIST_TOP := 11.0
const LIST_ROWS := 5
const TABS_Y := 93.0
const BODY_Y := 106.0
const SKILL_Y := 169.0
const GEAR_Y := 189.0
const TAB_NAMES := ["ฮีโร่", "เมือง", "เป้าหมาย", "สู้ล่าสุด"]

var run: RunState
var game: Game

var tab := 0
var scroll := 0
var hover_skill := -1  ## skill slot under the mouse
var hover_gear := -1  ## gear slot under the mouse

var _hits: Array[Dictionary] = []  # {rect, kind, ...}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(p_run: RunState, p_game: Game) -> void:
	run = p_run
	game = p_game
	scroll = 0


func _process(_d: float) -> void:
	if run != null:
		var p := get_local_mouse_position()
		hover_skill = skill_slot_at(p)
		hover_gear = gear_slot_at(p)
	queue_redraw()


func next_tab() -> void:
	tab = (tab + 1) % TAB_NAMES.size()


# --- slots ------------------------------------------------------------------------------------


func skill_rect(i: int) -> Rect2:
	var n := run.skill_slots()
	var w := (size.x - 4.0 - (n - 1) * 2.0) / n
	return Rect2(2 + i * (w + 2.0), SKILL_Y, w, 18)


func gear_rect(i: int) -> Rect2:
	var w := (size.x - 4.0 - 4.0) / 3.0
	return Rect2(2 + i * (w + 2.0), GEAR_Y, w, 18)


## Skill slot under a point in this control's coordinates, or -1.
func skill_slot_at(p: Vector2) -> int:
	if run == null:
		return -1
	for i in run.skill_slots():
		if skill_rect(i).has_point(p):
			return i
	return -1


func gear_slot_at(p: Vector2) -> int:
	if run == null:
		return -1
	for i in Item.SLOTS.size():
		if gear_rect(i).has_point(p):
			return i
	return -1


# --- input ------------------------------------------------------------------------------------


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
						"settings":
							game.show_settings = true
					accept_event()
					return


# --- drawing ------------------------------------------------------------------------------------


func _draw() -> void:
	if run == null:
		return
	_hits.clear()
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.PANEL)
	draw_line(Vector2(0.5, 0), Vector2(0.5, size.y), UiTheme.BORDER)
	_draw_notices()
	_draw_tabs()
	match tab:
		0:
			_draw_hero()
		1:
			_draw_town()
		2:
			_draw_goals()
		_:
			_draw_last_fight()
	_draw_slots()


func _draw_notices() -> void:
	var list := run.notices
	scroll = clampi(scroll, 0, maxi(0, list.size() - LIST_ROWS))
	var head := "แจ้งเตือน (%d)" % list.size()
	if list.size() > LIST_ROWS:  # the wheel scrolls; say which rows are showing
		head = "แจ้งเตือน %d-%d/%d" % [scroll + 1, mini(scroll + LIST_ROWS, list.size()), list.size()]
	UiTheme.text(self, 4, 0, head, UiTheme.FS_SMALL, UiTheme.GOLD, true)
	var bw := UiTheme.text_width("ตั้งค่า", UiTheme.FS_SMALL, true) + 8.0
	var br := Rect2(size.x - bw - 2.0, 0, bw, 10)
	var bhov := br.has_point(get_local_mouse_position())
	UiTheme.box(self, br, UiTheme.PANEL_LIGHT if bhov else Color("1f2237"), UiTheme.BORDER)
	UiTheme.text(self, br.position.x + 4, -0.5, "ตั้งค่า", UiTheme.FS_SMALL, UiTheme.TEXT, true)
	_hits.append({"rect": br, "kind": "settings"})
	for i in LIST_ROWS:
		var k := scroll + i
		var r := Rect2(2, LIST_TOP + i * ROW_H, size.x - 4, ROW_H - 1)
		if k >= list.size():
			draw_rect(r, Color(1, 1, 1, 0.03))
			continue
		var n: Notice = list[k]
		var hover := r.has_point(get_local_mouse_position()) and RunState.is_actionable(n)
		draw_rect(r, UiTheme.PANEL_LIGHT if hover else Color("1f2237"))
		draw_rect(Rect2(r.position, Vector2(2, r.size.y)), UiTheme.notice_color(n.kind))
		draw_texture(Art.icon(UiTheme.notice_icon(n.kind)), r.position + Vector2(3, -0.5))
		UiTheme.text(self, r.position.x + 21, r.position.y + 0.5, n.title, UiTheme.FS_SMALL, UiTheme.TEXT, true, r.size.x - 23)
		UiTheme.text(self, r.position.x + 21, r.position.y + 7, n.detail, UiTheme.FS_SMALL, UiTheme.TEXT_DIM, false, r.size.x - 23)
		if RunState.is_actionable(n):
			_hits.append({"rect": r, "kind": "notice", "notice": n})


func _draw_tabs() -> void:
	var x := 2.0
	for i in TAB_NAMES.size():
		var w := UiTheme.text_width(TAB_NAMES[i], UiTheme.FS_SMALL, true) + 8.0
		var r := Rect2(x, TABS_Y, w, 11)
		UiTheme.box(self, r, UiTheme.BORDER if tab == i else Color("1f2237"), UiTheme.BORDER)
		UiTheme.text(self, x + 4, TABS_Y + 1.5, TAB_NAMES[i], UiTheme.FS_SMALL, UiTheme.TEXT if tab == i else UiTheme.TEXT_DIM, true)
		_hits.append({"rect": r, "kind": "tab", "tab": i})
		x += w + 1.0


func _draw_hero() -> void:
	var h := run.hero
	var y := BODY_Y
	UiTheme.text(self, 4, y, "Lv %d" % h.level, UiTheme.FS, UiTheme.GOLD, true)
	UiTheme.text(self, 32, y + 1, "STR %d  AGI %d  INT %d" % [h.pts["str"], h.pts["agi"], h.pts["int"]], UiTheme.FS_SMALL, UiTheme.TEXT)
	y += 10.0
	var rows := [
		["ATK", UiTheme.num(h.atk), "HP", "%d/%d" % [ceili(h.hp), roundi(h.max_hp)]],
		["ตี/วิ", "%.2f" % h.aps, "หลบ", UiTheme.pct(h.evasion)],
		["AP", UiTheme.num(h.ap), "MANA", "%d +%.1f/วิ" % [roundi(h.max_mana), h.mana_regen]],
		["คริ", UiTheme.pct(h.crit), "คริดาเมจ", "x%.1f" % h.crit_damage],
	]
	for r in rows:
		UiTheme.text(self, 4, y, r[0], UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
		UiTheme.text(self, 26, y, r[1], UiTheme.FS_SMALL, UiTheme.TEXT, true)
		UiTheme.text(self, 62, y, r[2], UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
		UiTheme.text(self, 86, y, r[3], UiTheme.FS_SMALL, UiTheme.TEXT, true)
		y += 8.5
	if h.luck > 0.0:
		UiTheme.text(self, 4, y, "luck", UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
		UiTheme.text(self, 26, y, UiTheme.num(h.luck), UiTheme.FS_SMALL, UiTheme.TEXT, true)
		y += 8.5
	var t := run.town
	if t.tier > 0 or t.count > 0:
		UiTheme.text(self, 4, y + 1, "%s · นับ %d หลัง" % [t.tier_name(), t.count], UiTheme.FS_SMALL, UiTheme.PERK_COL)


func _draw_town() -> void:
	var t := run.town
	var y := BODY_Y
	var head := t.tier_name() if t.tier > 0 else "ยังไม่เป็นหมู่บ้าน"
	UiTheme.text(self, 4, y, head, UiTheme.FS, UiTheme.PERK_COL, true)
	var next := ""
	if t.tier < 2:
		next = "ถัดไป %d/%d หลัง" % [t.count, run.db.ci("town_tier1") if t.tier == 0 else run.db.ci("town_tier2")]
	else:
		next = "นับ %d หลัง" % t.count
	UiTheme.text(self, 4, y + 9, next, UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
	if t.tier > 0:
		UiTheme.text(self, 70, y + 9, "โจรบุก %d กลุ่ม/รอบ" % t.tier, UiTheme.FS_SMALL, UiTheme.WARN)
	y += 20.0
	for tier: int in [1, 2]:
		var id: String = run.perk_for_tier.get(tier, "")
		var line := ""
		var col := UiTheme.TEXT_DIM
		if id != "":
			var active := run.perk_active(id)
			line = "ขั้น %d: %s%s" % [tier, run.db.perks[id].name_th, "" if active else " (หยุดชั่วคราว)"]
			col = UiTheme.TEXT if active else UiTheme.TEXT_DIM
			draw_texture(Art.icon("perk_" + id), Vector2(3, y - 4))
			UiTheme.text(self, 21, y - 3, line, UiTheme.FS_SMALL, col, true, size.x - 24)
			UiTheme.text(self, 21, y + 4, run.db.perks[id].effect, UiTheme.FS_SMALL, UiTheme.TEXT_DIM, false, size.x - 24)
			y += 16.0
		else:
			var reached := run.top_tier >= tier
			UiTheme.text(self, 4, y, "ขั้น %d: %s" % [tier, "รอเลือก perk (ดูแจ้งเตือน)" if reached else "ยังไม่ถึง"], UiTheme.FS_SMALL, UiTheme.PERK_COL if reached else UiTheme.TEXT_DIM)
			y += 9.0


func _draw_goals() -> void:
	var y := BODY_Y
	UiTheme.text(self, 4, y, "เป้าหมาย run (RP ที่ได้ %d)" % run.rp_earned, UiTheme.FS_SMALL, UiTheme.GOLD, true)
	y += 10.0
	for g in run.goals.list:
		var col := UiTheme.GOOD if g.done else UiTheme.TEXT
		draw_rect(Rect2(4, y + 0.5, 6, 6), Color("181425"))
		draw_rect(Rect2(4, y + 0.5, 6, 6), UiTheme.BORDER, false, 1.0)
		if g.done:
			draw_texture(Art.icon("small/check"), Vector2(3, y - 0.5))
		var prog := "" if g.done else RunGoals.progress(run, g.id)
		var pw := UiTheme.text_width(prog, UiTheme.FS_SMALL) + 2.0 if prog != "" else 0.0
		UiTheme.text(self, 13, y - 0.5, g.text, UiTheme.FS_SMALL, col, false, size.x - 16 - pw)
		if prog != "":
			UiTheme.text(self, size.x - pw - 2.0, y - 0.5, prog, UiTheme.FS_SMALL, UiTheme.GOLD, true)
		y += 9.0


func _draw_last_fight() -> void:
	var y := BODY_Y
	var lf := run.last_fight
	if lf.is_empty():
		UiTheme.text(self, 4, y, "ยังไม่มีการต่อสู้", UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
		return
	var head := "%s  %s (รอบ %d)" % ["ชนะ" if lf["won"] else "แพ้", lf["spawn"], lf["lap"]]
	UiTheme.text(self, 4, y, head, UiTheme.FS_SMALL, UiTheme.GOOD if lf["won"] else UiTheme.BAD, true)
	y += 9.0
	for line in lf["lines"]:
		y += UiTheme.paragraph(self, 4, y, size.x - 8, line, UiTheme.FS_SMALL, UiTheme.TEXT, 7.0)
		if y > SKILL_Y - 16:
			break
	UiTheme.text(self, size.x - 50, SKILL_Y - 9, "กด L ดูเต็ม", UiTheme.FS_SMALL, UiTheme.TEXT_DIM)


func _draw_slots() -> void:
	var holding := game.held >= 0 and game.held < run.hand.size() and run.hand[game.held].skill
	var n := run.skill_slots()
	for i in n:
		var r := skill_rect(i)
		var slot: Dictionary = run.hero.skills[i] if i < run.hero.skills.size() else {}
		var hov := r.has_point(get_local_mouse_position())
		var rim := UiTheme.BORDER
		if holding:
			var res := run.check_skill_card(run.hand[game.held], i)
			rim = (UiTheme.GOLD if res["action"] == "merge" else UiTheme.GOOD) if res["ok"] else UiTheme.BAD
		draw_rect(r, UiTheme.PANEL_LIGHT if hov else Color("181425"))
		draw_rect(r, rim, false, 1.0)
		if slot.is_empty():
			UiTheme.text(self, r.position.x + 4, r.position.y + 5, "ช่อง skill", UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
			continue
		var sd: GameDb.SkillDef = run.db.skills[slot["id"]]
		draw_texture(Art.icon("skill_" + slot["id"]), r.position + Vector2(1, 1))
		if n <= 2:
			UiTheme.text(self, r.position.x + 18, r.position.y + 0.5, sd.name_th, UiTheme.FS_SMALL, UiTheme.TEXT, true, r.size.x - 20)
			UiTheme.text(self, r.position.x + 18, r.position.y + 8.5, "L%d · mana %d" % [slot["level"], roundi(sd.mana)], UiTheme.FS_SMALL, UiTheme.GOLD, false, r.size.x - 20)
		else:
			UiTheme.text(self, r.position.x + 18, r.position.y + 1, "L%d" % slot["level"], UiTheme.FS_SMALL, UiTheme.GOLD, true)
			UiTheme.text(self, r.position.x + 18, r.position.y + 9, "%d" % roundi(sd.mana), UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
	for i in Item.SLOTS.size():
		var r := gear_rect(i)
		var it: Item = run.equipment.get(Item.SLOTS[i])
		var hov := r.has_point(get_local_mouse_position())
		draw_rect(r, UiTheme.PANEL_LIGHT if hov else Color("181425"))
		draw_rect(r, UiTheme.rarity_color(it.rarity) if it != null else UiTheme.BORDER, false, 1.0)
		if it == null:
			UiTheme.text(self, r.position.x + 3, r.position.y + 5, Item.SLOT_NAMES[Item.SLOTS[i]], UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
			continue
		draw_texture(Art.icon(it.icon), r.position + Vector2(1, 1))
		UiTheme.text(self, r.position.x + 18, r.position.y + 0.5, it.short_text(), UiTheme.FS_SMALL, UiTheme.TEXT, true, r.size.x - 19)
		UiTheme.text(self, r.position.x + 18, r.position.y + 8.5, "Lv%d%s" % [it.level, " +%d" % (it.stats.size() - 1) if it.stats.size() > 1 else ""], UiTheme.FS_SMALL, UiTheme.rarity_color(it.rarity), true, r.size.x - 19)

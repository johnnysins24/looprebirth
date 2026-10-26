class_name ChoicePanel
extends Control
## The window a notification opens: spend stat points, pick a card, a skill card, a town perk,
## an item or a ware, or answer an event. Sits over the map; the game pauses while it is
## open unless the player turned that off.

var run: RunState
var game: Game

var _hits: Array[Dictionary] = []
var _hover := -1
var _seen: Notice = null  ## the notice the trade state belongs to
var _trade := false  ## merchant: picking hand cards
var _sel: Array[int] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func setup(p_run: RunState, p_game: Game) -> void:
	run = p_run
	game = p_game
	_seen = null


func _process(_d: float) -> void:
	visible = game.open_notice != null
	if visible:
		if game.open_notice != _seen:
			_seen = game.open_notice
			_trade = false
			_sel.clear()
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
		"skill_offer":
			if run.choose_skill_offer(n, h["index"]):
				game.after_notice_done(n)
		"reroll":
			run.reroll_offers(n)
		"perk":
			if run.choose_perk(n, h["index"]):
				game.after_notice_done(n)
		"equip":
			if run.equip_item(n):
				game.after_notice_done(n)
		"discard":
			if run.discard_item(n):
				game.after_notice_done(n)
		"ware":
			if run.buy_ware(n, h["index"]):
				game.after_notice_done(n)
		"event":
			var opt: int = h["index"]
			var info := RunEvents.options(run, n)
			if int(info[opt]["cards"]) > 0:
				_trade = true
				_sel.clear()
			elif run.resolve_event(n, opt):
				game.after_notice_done(n)
		"trade_card":
			var i: int = h["index"]
			if _sel.has(i):
				_sel.erase(i)
			elif _sel.size() < run.db.ci("event_trade_cards"):
				_sel.append(i)
		"trade_go":
			if run.resolve_event(n, 0, {"cards": _sel.duplicate()}):
				game.after_notice_done(n)
		"trade_back":
			_trade = false


func _draw() -> void:
	var n := game.open_notice
	if n == null or run == null:
		return
	_hits.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	match n.kind:
		"stat":
			_draw_stat(n)
		"lap_card", "skill_card":
			_draw_cards(n)
		"town_perk":
			_draw_perks(n)
		"item":
			_draw_item(n)
		"shop":
			_draw_shop(n)
		"event":
			_draw_event(n)


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


func _close_button(r: Rect2) -> void:
	_button(Rect2(r.end.x - 52, r.end.y - 18, 46, 13), "ปิด (Esc)", "close")


## A clickable row; returns its rect. Draws the hover highlight.
func _row(rect: Rect2, kind: String, extra: Dictionary = {}) -> bool:
	var hov := rect.has_point(get_local_mouse_position())
	draw_rect(rect, UiTheme.PANEL_LIGHT if hov else Color("1f2237"))
	if hov:
		draw_rect(rect, UiTheme.GOLD, false, 1.0)
	var h := {"rect": rect, "kind": kind}
	h.merge(extra)
	_hits.append(h)
	return hov


# --- stat points --------------------------------------------------------------------------------


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
	_close_button(r)


# --- card choices (lap cards and skill cards) ---------------------------------------------------------


func _draw_cards(n: Notice) -> void:
	var offers: Array = n.payload["offers"]
	var r := _panel(310, 22 + offers.size() * 50 + 20)
	var head := "%s  ·  %s" % [n.title, n.detail]
	UiTheme.text(self, r.position.x + 8, r.position.y + 6, head, UiTheme.FS, UiTheme.SKILL_COL if n.kind == "skill_card" else UiTheme.GOLD, true)
	var y := r.position.y + 20.0
	for i in offers.size():
		var card: CardInst = offers[i]
		var rr := Rect2(r.position.x + 6, y, r.size.x - 12, 48)
		_row(rr, "skill_offer" if card.skill else "offer", {"index": i})
		CardView.draw_inst(self, rr.position + Vector2(2, 2), run.db, card)
		var tx := rr.position.x + 40
		if card.skill:
			var sd: GameDb.SkillDef = run.db.skills[card.id]
			UiTheme.text(self, tx, rr.position.y + 2, sd.name_th, UiTheme.FS, UiTheme.TEXT, true)
			UiTheme.paragraph(self, tx, rr.position.y + 13, rr.size.x - 46, sd.describe(1), UiTheme.FS_SMALL, UiTheme.TEXT, 7.5)
			UiTheme.text(self, tx, rr.position.y + 28, "mana %d · ลากจากมือไปช่อง skill ของฮีโร่" % roundi(sd.mana), UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
			var worn := _skill_hint(card.id)
			if worn != "":
				UiTheme.text(self, tx, rr.position.y + 37, worn, UiTheme.FS_SMALL, UiTheme.GOLD, true)
		else:
			var def: GameDb.CardDef = run.db.cards[card.id]
			UiTheme.text(self, tx, rr.position.y + 2, def.name_th, UiTheme.FS, UiTheme.TEXT, true)
			UiTheme.paragraph(self, tx, rr.position.y + 13, rr.size.x - 46, def.describe(1), UiTheme.FS_SMALL, UiTheme.TEXT, 7.5)
			UiTheme.text(self, tx, rr.position.y + 28, def.place_th, UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
			var have := _owned(card.id)
			if have != "":
				UiTheme.text(self, tx, rr.position.y + 37, have, UiTheme.FS_SMALL, UiTheme.GOLD, true)
		y += 50.0
	if n.kind == "lap_card":
		var label := "สุ่มใหม่ (เหลือ %d)" % run.rerolls_left
		_button(Rect2(r.position.x + 8, r.end.y - 18, 70, 13), label, "reroll", {}, run.rerolls_left > 0)
	_close_button(r)


## "มีบนแผนที่ x2 · ในมือ x1": a hint that this card merges with what the player has.
func _owned(card_id: String) -> String:
	var on_map := 0
	for c: Vector2i in run.placed:
		if run.placed[c].id == card_id:
			on_map += 1
	var in_hand := 0
	for c in run.hand:
		if c.id == card_id and not c.skill:
			in_hand += 1
	if on_map == 0 and in_hand == 0:
		return ""
	return "ใช้ merge ได้: บนแผนที่ x%d · ในมือ x%d" % [on_map, in_hand]


func _skill_hint(skill_id: String) -> String:
	for s in run.hero.skills:
		if not s.is_empty() and s["id"] == skill_id:
			return "ใส่อยู่ L%d · merge ได้ถ้า level เท่ากัน" % s["level"]
	var in_hand := 0
	for c in run.hand:
		if c.skill and c.id == skill_id:
			in_hand += 1
	return "ในมือ x%d" % in_hand if in_hand > 0 else ""


# --- town perks ------------------------------------------------------------------------------------------


func _draw_perks(n: Notice) -> void:
	var options: Array = n.payload["options"]
	var tier: int = n.payload["tier"]
	var r := _panel(300, 38 + options.size() * 38 + 18)
	UiTheme.text(self, r.position.x + 8, r.position.y + 6, "%s ขั้น %d: เลือก perk" % [Town.NAMES[tier], tier], UiTheme.FS, UiTheme.PERK_COL, true)
	UiTheme.text(self, r.position.x + 8, r.position.y + 17, "perk ทำงานตราบที่เมืองอยู่ขั้น %d ขึ้นไป · เมืองดึงดูดโจรมากขึ้นทุกขั้น" % tier, UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
	var y := r.position.y + 30.0
	for i in options.size():
		var pd: GameDb.PerkDef = run.db.perks[options[i]]
		var rr := Rect2(r.position.x + 6, y, r.size.x - 12, 36)
		_row(rr, "perk", {"index": i})
		draw_texture(Art.icon("perk_" + pd.id), rr.position + Vector2(3, 10))
		UiTheme.text(self, rr.position.x + 24, rr.position.y + 3, pd.name_th, UiTheme.FS, UiTheme.TEXT, true)
		UiTheme.paragraph(self, rr.position.x + 24, rr.position.y + 15, rr.size.x - 28, pd.effect, UiTheme.FS_SMALL, UiTheme.TEXT_DIM, 7.5)
		y += 38.0
	_close_button(r)


# --- items ---------------------------------------------------------------------------------------------------


## Item name, rarity, stat lines. With `other` (the worn item) each line shows the change.
## Returns the height used.
func _item_block(x: float, y: float, w: float, item: Item, other: Item) -> float:
	draw_texture(Art.icon(item.icon), Vector2(x, y))
	UiTheme.text(self, x + 19, y - 1, item.title(), UiTheme.FS, UiTheme.rarity_color(item.rarity), true, w - 19)
	UiTheme.text(self, x + 19, y + 8, "%s · %s" % [item.rarity_name(), Item.SLOT_NAMES[item.slot]], UiTheme.FS_SMALL, UiTheme.TEXT_DIM, false, w - 19)
	var ly := y + 19.0
	var keys: Array[String] = []
	keys.append(item.main)
	for k in item.stats:
		if not keys.has(k):
			keys.append(k)
	if other != null:
		for k in other.stats:
			if not keys.has(k):
				keys.append(k)
	for k in keys:
		var v: float = item.stats.get(k, 0.0)
		var line := Item.stat_text(k, v) if v != 0.0 else "%s —" % Item.STAT_NAMES.get(k, k)
		UiTheme.text(self, x + 2, ly, line, UiTheme.FS_SMALL, UiTheme.TEXT if v != 0.0 else UiTheme.TEXT_DIM, true)
		if other != null:
			var d := v - float(other.stats.get(k, 0.0))
			if absf(d) > 0.0001:
				var pct := Item.PERCENT.has(k)
				var txt := ("%s%d%%" % ["▲+" if d > 0.0 else "▼", roundi(d * 100.0)]) if pct else ("%s%d" % ["▲+" if d > 0.0 else "▼", roundi(d)])
				var tw := UiTheme.text_width(txt, UiTheme.FS_SMALL, true)
				UiTheme.text(self, x + w - tw - 2, ly, txt, UiTheme.FS_SMALL, UiTheme.GOOD if d > 0.0 else UiTheme.BAD, true)
		ly += 8.0
	return ly - y


func _draw_item(n: Notice) -> void:
	var item: Item = n.payload["item"]
	var worn: Item = run.equipment.get(item.slot)
	var r := _panel(300, 130)
	UiTheme.text(self, r.position.x + 8, r.position.y + 6, "ของใหม่: %s" % Item.SLOT_NAMES[item.slot], UiTheme.FS, UiTheme.GOLD, true)
	var col_w := (r.size.x - 24.0) / 2.0
	var lx := r.position.x + 8
	var rx := lx + col_w + 8.0
	UiTheme.text(self, lx, r.position.y + 18, "ของที่ได้ (▲▼ เทียบกับที่ใส่อยู่)", UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
	_item_block(lx, r.position.y + 28, col_w, item, worn)
	UiTheme.text(self, rx, r.position.y + 18, "ที่ใส่อยู่ตอนนี้", UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
	if worn != null:
		_item_block(rx, r.position.y + 28, col_w, worn, null)
	else:
		UiTheme.text(self, rx + 2, r.position.y + 32, "ช่องนี้ยังว่าง", UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
	_button(Rect2(r.position.x + 8, r.end.y - 20, 86, 14), "ใส่ (แทนของเดิม)" if worn != null else "ใส่", "equip")
	_button(Rect2(r.position.x + 98, r.end.y - 20, 50, 14), "ทิ้ง", "discard")
	_close_button(Rect2(r.position.x, r.position.y, r.size.x, r.size.y + 4))


func _draw_shop(n: Notice) -> void:
	var wares: Array = n.payload["items"]
	var r := _panel(310, 30 + wares.size() * 62 + 20)
	UiTheme.text(self, r.position.x + 8, r.position.y + 6, "%s  ·  %s" % [n.title, n.detail], UiTheme.FS, UiTheme.GOLD, true)
	var y := r.position.y + 20.0
	for i in wares.size():
		var item: Item = wares[i]
		var rr := Rect2(r.position.x + 6, y, r.size.x - 12, 60)
		_row(rr, "ware", {"index": i})
		_item_block(rr.position.x + 4, rr.position.y + 4, 140.0, item, run.equipment.get(item.slot))
		UiTheme.text(self, rr.position.x + 160, rr.position.y + 4, "ที่ใส่อยู่:", UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
		var worn: Item = run.equipment.get(item.slot)
		if worn != null:
			_item_block(rr.position.x + 160, rr.position.y + 14, 130.0, worn, null)
		else:
			UiTheme.text(self, rr.position.x + 160, rr.position.y + 14, "ว่าง", UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
		y += 62.0
	_close_button(r)


# --- events ----------------------------------------------------------------------------------------------------


func _draw_event(n: Notice) -> void:
	var def: GameDb.EventDef = run.db.events[n.payload["event"]]
	if _trade:
		_draw_trade(def)
		return
	var opts := RunEvents.options(run, n)
	var r := _panel(310, 34 + 2 * 46 + 22)
	UiTheme.text(self, r.position.x + 8, r.position.y + 6, "? " + def.name_th, UiTheme.FS_BIG, UiTheme.WARN, true)
	UiTheme.text(self, r.position.x + 8, r.position.y + 18, def.story_th, UiTheme.FS_SMALL, UiTheme.TEXT)
	var y := r.position.y + 32.0
	for i in 2:
		var o: Dictionary = opts[i]
		var rr := Rect2(r.position.x + 6, y, r.size.x - 12, 44)
		var enabled: bool = o["enabled"]
		if enabled:
			_row(rr, "event", {"index": i})
		else:
			draw_rect(rr, Color("1f2237"))
		UiTheme.text(self, rr.position.x + 6, rr.position.y + 3, "%d. %s" % [i + 1, o["label"]], UiTheme.FS, UiTheme.TEXT if enabled else UiTheme.TEXT_DIM, true)
		UiTheme.paragraph(self, rr.position.x + 6, rr.position.y + 15, rr.size.x - 12, o["detail"], UiTheme.FS_SMALL, UiTheme.TEXT_DIM, 7.5)
		if not enabled:
			UiTheme.text(self, rr.position.x + 6, rr.end.y - 10, o["reason"], UiTheme.FS_SMALL, UiTheme.BAD, true)
		y += 46.0
	UiTheme.text(self, r.position.x + 8, r.end.y - 16, "ตัวเลขคิดจากค่าตอนกดเลือก (เช่น HP ปัจจุบัน)", UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
	_close_button(r)


func _draw_trade(def: GameDb.EventDef) -> void:
	var need := run.db.ci("event_trade_cards")
	var per_row := 9
	var rows := ceili(run.hand.size() / float(per_row))
	var r := _panel(340, 50 + rows * 48 + 22)
	UiTheme.text(self, r.position.x + 8, r.position.y + 6, "? %s: เลือกการ์ดในมือ %d ใบ" % [def.name_th, need], UiTheme.FS, UiTheme.WARN, true)
	UiTheme.text(self, r.position.x + 8, r.position.y + 18, "เลือกแล้ว %d/%d · แลกแล้วได้ของระดับรอบ %d 1 ชิ้น" % [_sel.size(), need, run.lap], UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
	for i in run.hand.size():
		var pos := r.position + Vector2(8 + (i % per_row) * 36, 32 + (i / per_row) * 48)
		var cr := Rect2(pos, Vector2(CardView.W, CardView.H))
		var on := _sel.has(i)
		CardView.draw_inst(self, pos - Vector2(0, 3 if on else 0), run.db, run.hand[i], on)
		_hits.append({"rect": cr, "kind": "trade_card", "index": i})
	var by := r.end.y - 20.0
	_button(Rect2(r.position.x + 8, by, 80, 14), "ยืนยันแลก", "trade_go", {}, _sel.size() == need)
	_button(Rect2(r.position.x + 92, by, 50, 14), "ย้อนกลับ", "trade_back")
	_close_button(Rect2(r.position.x, r.position.y, r.size.x, r.size.y + 4))

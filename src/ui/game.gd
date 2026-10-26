class_name Game
extends Control
## The one screen of the prototype: builds the views, feeds RunState real time scaled by the
## game speed, and turns mouse and keys into the player's choices.
##
## Keys: Space pause, 1/2/3 speed x1/x2/x4, N open the next notification, L fight log,
## Tab side tab, B background colour, R new run (Shift+R same seed), Esc cancel/close,
## F1 debug text, F3 level up, F4 three cards, F9 bot plays.
##
## Two screens: HOME (Rebirth tree and the start button) and RUN. A run starts from HOME,
## or straight away when the command line gives --seed.
##
## Command line (after `--`): --seed N, --speed N, --bot str|agi|int|mix, --fast SECONDS,
## --open stat|card, --hold INDEX, --log, --shot PATH [--shot-frames N], --quit-after SECONDS,
## --demo (one notice of every kind), --home (start on the Rebirth tree), --profile PATH|none (save file; default user://profile.json,
## headless runs keep it in memory), --rp N (give Rebirth points, for screenshots).

enum Screen { HOME, RUN }

const SETTINGS_PATH := "user://settings.cfg"
const PROFILE_PATH := "user://profile.json"

class Overlay:
	extends Control
	var game: Game
	var toasts: Array[Dictionary] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		for t in toasts:
			t["age"] += delta
		toasts = toasts.filter(func(t): return t["age"] < 3.0)
		queue_redraw()

	func _draw() -> void:
		var y := UiTheme.MAP_RECT.position.y + 3.0
		for t in toasts:
			if game.open_notice != null or game.show_log:
				break
			var w := UiTheme.text_width(t["text"], UiTheme.FS, true) + 10.0
			var x := UiTheme.MAP_RECT.position.x + (UiTheme.MAP_RECT.size.x - w) / 2.0
			var a := clampf(3.0 - t["age"], 0.0, 1.0)
			draw_rect(Rect2(x, y, w, 12), Color(UiTheme.BG, 0.85 * a))
			UiTheme.text(self, x + 5, y + 1.5, t["text"], UiTheme.FS, Color(UiTheme.GOLD, a), true)
			y += 13.0
		game._draw_ghost(self)
		if game.debug_overlay:
			game._draw_debug(self)

var db: GameDb
var run: RunState
var meta: Meta
var screen := Screen.RUN
var show_settings := false
var auto_equip := false  ## put on a drop at once when it is better than what is worn
var preview_seed := 0  ## loop shown on the home screen
var preview_rerolls := 0
var speed := 1
var held := -1  ## hand index of the card being placed, -1 for none
var open_notice: Notice = null
var auto_open := false  ## open pending choices by themselves at the end of a lap
var pause_on_panel := true
var show_log := false
var debug_overlay := false
var bot: Bot = null
var bot_build := ""

var top_bar: TopBar
var map: MapView
var side: SidePanel
var hand_bar: HandBar
var battle_view: BattleView
var choice: ChoicePanel
var end_panel: EndPanel
var log_view: LogView
var overlay: Overlay
var home: HomeView
var settings_view: SettingsView

var _last_speed := 1
var _drag_origin := Vector2.ZERO
var _dragging := false
var _auto_pending := false
var _bot_clock := 0.0
var _cli := {}
var _frames := 0
var _elapsed := 0.0


func _ready() -> void:
	size = UiTheme.VIEW
	position = Vector2.ZERO
	theme = UiTheme.make()
	get_window().title = "Loop Rebirth"
	db = GameDb.load_default()
	_load_settings()
	_cli = _parse_cli()
	var profile := String(_cli.get("profile", "none" if DisplayServer.get_name() == "headless" else PROFILE_PATH))
	meta = Meta.new(db, "" if profile == "none" else profile)
	if _cli.has("rp"):
		meta.rp += int(_cli["rp"])
	_build_views()
	if _cli.has("speed"):
		speed = int(_cli["speed"])
	if _cli.has("bot"):
		bot_build = _cli["bot"]
	if _cli.has("home") or not (_cli.has("seed") or _cli.has("fast") or _cli.has("shot") or _cli.has("bot")):
		open_home()
		if _cli.has("seed"):
			preview_seed = int(_cli["seed"])
	else:
		start_run(int(_cli.get("seed", randi())))
	_apply_cli_after_start()


func _build_views() -> void:
	map = MapView.new()
	battle_view = BattleView.new()
	log_view = LogView.new()
	choice = ChoicePanel.new()
	end_panel = EndPanel.new()
	top_bar = TopBar.new()
	side = SidePanel.new()
	hand_bar = HandBar.new()
	overlay = Overlay.new()
	overlay.game = self
	home = HomeView.new()
	settings_view = SettingsView.new()
	for v in [map, battle_view, log_view, choice, end_panel]:
		_place(v, UiTheme.MAP_RECT)
	_place(top_bar, Rect2(0, 0, UiTheme.VIEW.x, UiTheme.TOP_H))
	_place(side, UiTheme.SIDE_RECT)
	_place(hand_bar, UiTheme.HAND_RECT)
	_place(settings_view, Rect2(Vector2.ZERO, UiTheme.VIEW))
	_place(home, Rect2(Vector2.ZERO, UiTheme.VIEW))
	_place(overlay, Rect2(Vector2.ZERO, UiTheme.VIEW))
	home.setup(self)
	settings_view.setup(self)


func _place(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = r.size
	add_child(c)


func open_home() -> void:
	screen = Screen.HOME
	show_settings = false
	preview_seed = randi()
	preview_rerolls = 0
	if run == null:
		run = RunState.new(db, preview_seed, meta)  # something for the hidden run views to hold
		_setup_views()


func start_run(seed_value: int) -> void:
	screen = Screen.RUN
	run = RunState.new(db, seed_value, meta)
	run.auto_equip = auto_equip
	held = -1
	open_notice = null
	show_log = false
	_auto_pending = false
	_dragging = false
	_bot_clock = 0.0
	bot = Bot.new(run, bot_build, seed_value) if bot_build != "" else null
	_setup_views()
	run.toast.connect(func(t): overlay.toasts.append({"text": t, "age": 0.0}))
	run.lap_completed.connect(func(_lap): _auto_pending = auto_open)
	run.hand_changed.connect(func(): held = clampi(held, -1, run.hand.size() - 1))


func _setup_views() -> void:
	for v in [map, top_bar, side, hand_bar, battle_view, choice, end_panel, log_view]:
		v.setup(run, self)


# --- time ------------------------------------------------------------------------------------


func is_paused() -> bool:
	return speed == 0 or (open_notice != null and pause_on_panel) or run.phase == RunState.Phase.ENDED or screen != Screen.RUN or show_settings


func _process(delta: float) -> void:
	_frames += 1
	_elapsed += delta
	if run == null:
		return
	if _auto_pending and open_notice == null:
		var n := _next_actionable()
		if n != null:
			open_notice_panel(n)
		else:
			_auto_pending = false
	if not is_paused():
		var dt := minf(delta, 0.1) * speed
		run.advance(dt)
		if bot != null:
			_bot_clock += dt
			if _bot_clock >= 0.25:
				_bot_clock = 0.0
				bot.act()
	_cli_tick()


func set_speed(v: int) -> void:
	speed = v
	if v > 0:
		_last_speed = v


func _next_actionable() -> Notice:
	for n in run.notices:
		if RunState.is_actionable(n):
			return n
	return null


# --- panels ------------------------------------------------------------------------------------


func open_notice_panel(n: Notice) -> void:
	if RunState.is_actionable(n):
		open_notice = n
		held = -1


func close_notice_panel() -> void:
	open_notice = null
	_auto_pending = false


## Called by the choice panel when it used up its notification.
func after_notice_done(n: Notice) -> void:
	open_notice = null
	var nxt := run.first_notice("stat") if n.kind == "stat" else null
	if nxt == null and _auto_pending:
		nxt = _next_actionable()
	if nxt != null:
		open_notice_panel(nxt)


# --- input ---------------------------------------------------------------------------------------


func _input(event: InputEvent) -> void:
	if run == null:
		return
	if screen == Screen.HOME or show_settings:
		if event is InputEventKey and event.pressed and not event.echo:
			if show_settings and event.keycode == KEY_ESCAPE:
				show_settings = false
				_save_settings()
			elif screen == Screen.HOME and not show_settings and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE):
				start_run(preview_seed)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_on_key(event)
	elif event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		if held >= 0 and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if event.position.distance_to(_drag_origin) > 4.0:
				_dragging = true


func _on_key(e: InputEventKey) -> void:
	match e.keycode:
		KEY_SPACE:
			if speed == 0:
				set_speed(_last_speed)
			else:
				speed = 0
		KEY_1:
			set_speed(1)
		KEY_2:
			set_speed(2)
		KEY_3, KEY_4:
			set_speed(4)
		KEY_N:
			var n := _next_actionable()
			if n != null:
				open_notice_panel(n)
		KEY_L:
			show_log = not show_log
		KEY_TAB:
			side.next_tab()
		KEY_B:
			Art.cycle_background()
			_save_settings()
			overlay.toasts.append({"text": "พื้นหลัง: " + Art.background()["name"], "age": 0.0})
		KEY_R:
			start_run(run.seed_value if e.shift_pressed else randi())
		KEY_ESCAPE:
			if show_log:
				show_log = false
			elif open_notice != null:
				close_notice_panel()
			else:
				held = -1
		KEY_F1:
			debug_overlay = not debug_overlay
		KEY_F3:
			run.debug_level_up()
		KEY_F4:
			var ids := db.unlocked_card_ids()
			for i in 3:
				run.give_card(CardInst.make(ids[randi() % ids.size()]))
		KEY_F9:
			if bot == null:
				bot_build = "mix"
				bot = Bot.new(run, bot_build, run.seed_value)
			else:
				bot = null
				bot_build = ""


func _local(p: Vector2, c: Control) -> Vector2:
	return p - c.position


## Board cell under a point of the 480x270 screen, or (-1,-1) outside the map.
func cell_at(p: Vector2) -> Vector2i:
	if not UiTheme.MAP_RECT.has_point(p):
		return Vector2i(-1, -1)
	var q := p - UiTheme.MAP_RECT.position
	return Vector2i(int(q.x) / UiTheme.CELL, int(q.y) / UiTheme.CELL)


## Hero skill slot under a point of the 480x270 screen, or -1.
func skill_slot_at(p: Vector2) -> int:
	if not UiTheme.SIDE_RECT.has_point(p):
		return -1
	return side.skill_slot_at(_local(p, side))


func _on_mouse_button(e: InputEventMouseButton) -> void:
	if open_notice != null or run.phase == RunState.Phase.ENDED:
		return
	var p := e.position
	if e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
		held = -1
		return
	if e.button_index != MOUSE_BUTTON_LEFT:
		return
	if e.pressed:
		var slot := hand_bar.slot_at(_local(p, hand_bar)) if UiTheme.HAND_RECT.has_point(p) else -1
		if slot >= 0:
			held = -1 if (held == slot and not _dragging) else slot
			_drag_origin = p
			_dragging = false
			get_viewport().set_input_as_handled()
		elif held >= 0 and UiTheme.MAP_RECT.has_point(p):
			_try_place(cell_at(p))
			get_viewport().set_input_as_handled()
		elif held >= 0 and skill_slot_at(p) >= 0:
			_try_equip(skill_slot_at(p))
			get_viewport().set_input_as_handled()
	else:
		if _dragging and held >= 0:
			if UiTheme.MAP_RECT.has_point(p):
				_try_place(cell_at(p))
			elif skill_slot_at(p) >= 0:
				_try_equip(skill_slot_at(p))
			else:
				held = -1
		_dragging = false


func _try_place(cell: Vector2i) -> void:
	if held < 0 or cell.x < 0:
		return
	if run.play_card(held, cell):
		held = -1
	else:
		var res := run.check_place(held, cell)
		if res.get("reason", "") != "":
			overlay.toasts.append({"text": res["reason"], "age": 1.6})


func set_auto_equip(on: bool) -> void:
	auto_equip = on
	if run != null:
		run.auto_equip = on


func _try_equip(slot: int) -> void:
	if held < 0 or held >= run.hand.size():
		return
	var res := run.check_skill_card(run.hand[held], slot)
	if run.play_skill_card(held, slot):
		held = -1
		var verb: String = {"equip": "ใส่", "merge": "merge เป็น L%d" % res["level"], "swap": "เปลี่ยน"}[res["action"]]
		if res.get("partial", false):
			verb = "นับครึ่ง (%d/2)" % int(res["progress"])
		overlay.toasts.append({"text": "ช่อง skill %d: %s" % [slot + 1, verb], "age": 1.6})
	elif res["reason"] != "":
		overlay.toasts.append({"text": res["reason"], "age": 1.6})


# --- hover text ------------------------------------------------------------------------------------


func info_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if held < 0 and screen == Screen.RUN:
		if side.hover_skill >= 0:
			var slot: Dictionary = run.hero.skills[side.hover_skill] if side.hover_skill < run.hero.skills.size() else {}
			if slot.is_empty():
				return [{"t": "ช่อง skill ว่าง", "c": UiTheme.TEXT}, {"t": "ลาก skill card จากมือมาวางที่นี่", "c": UiTheme.TEXT_DIM}]
			var sd: GameDb.SkillDef = db.skills[slot["id"]]
			out.append({"t": "%s L%d · mana %d" % [sd.name_th, slot["level"], roundi(sd.mana)], "c": UiTheme.SKILL_COL})
			out.append({"t": sd.describe(slot["level"]), "c": UiTheme.TEXT})
			out.append({"t": "merge: ลาก skill เดียวกันมาทับ (level เท่ากัน หรือ L1 สองใบเข้า L2 เป็น L3)", "c": UiTheme.TEXT_DIM})
			return out
		if side.hover_gear >= 0:
			var slot_id: String = Item.SLOTS[side.hover_gear]
			var it: Item = run.equipment.get(slot_id)
			if it == null:
				return [{"t": "%s: ยังไม่มีของ" % Item.SLOT_NAMES[slot_id], "c": UiTheme.TEXT}, {"t": "ศัตรูดรอปของใส่ช่องนี้ได้", "c": UiTheme.TEXT_DIM}]
			out.append({"t": "%s · %s" % [it.title(), it.rarity_name()], "c": UiTheme.rarity_color(it.rarity)})
			out.append({"t": "  ".join(it.lines()), "c": UiTheme.TEXT})
			return out
	var cell := map.hover_cell()
	var card: CardInst = null
	if held >= 0 and held < run.hand.size():
		card = run.hand[held]
	elif hand_bar.hover_slot >= 0 and hand_bar.hover_slot < run.hand.size():
		card = run.hand[hand_bar.hover_slot]
	if card != null and card.skill:
		var sd: GameDb.SkillDef = db.skills[card.id]
		out.append({"t": "skill card: %s L%d" % [sd.name_th, card.level], "c": UiTheme.SKILL_COL})
		out.append({"t": sd.describe(card.level), "c": UiTheme.TEXT})
		out.append({"t": "mana %d · ลากไปช่อง skill ที่แผงขวา" % roundi(sd.mana), "c": UiTheme.TEXT_DIM})
		if held >= 0 and held < run.hand.size() and run.hand[held] == card and skill_slot_at(get_local_mouse_position()) >= 0:
			var res := run.check_skill_card(card, skill_slot_at(get_local_mouse_position()))
			var word: String = {"equip": "ใส่ช่องว่าง", "merge": "merge เป็น L%d" % res["level"], "swap": "เปลี่ยนกับ skill เดิม (ใบเดิมกลับเข้ามือ)"}[res["action"]]
			if res.get("partial", false):
				word = "นับครึ่ง: ต้องมี L1 อีกใบถึงเป็น L3 (ตอนนี้ %d/2)" % int(res["progress"])
			out.append({"t": word if res["ok"] else res["reason"], "c": UiTheme.GOOD if res["ok"] else UiTheme.BAD})
		return out
	if card != null:
		var def: GameDb.CardDef = db.cards[card.id]
		out.append({"t": "%s L%d" % [def.name_th, card.level], "c": UiTheme.GOLD})
		out.append({"t": def.describe(card.level), "c": UiTheme.TEXT})
		if held >= 0 and cell.x >= 0 and run.board.in_bounds(cell):
			var res := run.check_card(card, cell)
			if res["ok"]:
				if res["action"] == "merge":
					var text := "วางทับ: merge เป็น L%d" % res["level"]
					if res.get("partial", false):
						text = "วางทับ: นับครึ่ง (L1 สองใบเป็น L3) ตอนนี้ %d/2" % int(res["progress"])
					out.append({"t": text, "c": UiTheme.GOLD})
				else:
					out.append({"t": "วางได้", "c": UiTheme.GOOD})
				for combo: GameDb.ComboDef in res["combos"]:
					var neg := combo.id == "haunted_village"
					out.append({"t": "combo %s: %s" % [combo.name_th, combo.description], "c": UiTheme.BAD if neg else UiTheme.GOLD})
			else:
				out.append({"t": res["reason"], "c": UiTheme.BAD})
		else:
			out.append({"t": def.place_th, "c": UiTheme.TEXT_DIM})
		return out
	if cell.x >= 0 and run.board.in_bounds(cell):
		out.append({"t": _kind_name(run.board.kind_at(cell)), "c": UiTheme.TEXT_DIM})
		var placed: CardInst = run.placed.get(cell)
		if placed != null:
			var def: GameDb.CardDef = db.cards[placed.id]
			var prog := " (สะสม %d/2 ใบ)" % placed.progress if placed.level == 2 and placed.progress > 0 else ""
			out.append({"t": "%s L%d%s: %s" % [def.name_th, placed.level, prog, def.describe(placed.level)], "c": UiTheme.TEXT})
			for id in run.flags.get(cell, {}):
				out.append({"t": "combo %s" % db.combos[id].name_th, "c": UiTheme.BAD if id == "haunted_village" else UiTheme.GOLD})
		var i := run.board.index_of(cell)
		var sp: RunState.Spawn = run.spawns.get(i)
		if sp != null:
			var e: GameDb.EnemyDef = db.enemies[sp.enemy_id]
			var f := Foe.make(db, e, run.lap, false, 1.0, RandomNumberGenerator.new())
			var state := "" if sp.alive else " (ถูกกำจัดแล้ว กลับมารอบหน้า)"
			out.append({"t": "%s x%d%s" % [e.name_th, sp.count, state], "c": UiTheme.WARN})
			out.append({"t": "ตัวละ HP %d ATK %s DEF %s XP %d" % [roundi(f.max_hp), UiTheme.num(f.atk), UiTheme.num(f.df), f.xp * 1], "c": UiTheme.TEXT_DIM})
		if out.size() > 0:
			return out
	out.append({"t": "คลิกหรือลากการ์ดในมือ แล้ววางบนแผนที่", "c": UiTheme.TEXT_DIM})
	out.append({"t": "ชี้ช่องบนแผนที่เพื่อดูข้อมูล", "c": UiTheme.TEXT_DIM})
	return out


func _kind_name(kind: int) -> String:
	match kind:
		Board.Kind.ROAD:
			return "ช่องทาง (วาง encounter)"
		Board.Kind.CAMP:
			return "ค่าย (ครบรอบ ฟื้น HP)"
		Board.Kind.ROADSIDE:
			return "ข้างทาง"
		Board.Kind.OPEN:
			return "ที่โล่ง"
	return "ทะเล"


# --- overlay drawing ----------------------------------------------------------------------------------


func _draw_ghost(ci: CanvasItem) -> void:
	if held < 0 or held >= run.hand.size():
		return
	var m := get_local_mouse_position()
	if UiTheme.HAND_RECT.has_point(m) and not _dragging:
		return
	var card := run.hand[held]
	CardView.draw_card(ci, m - Vector2(16, 40), db, card.id, card.level, true)


func _draw_debug(ci: CanvasItem) -> void:
	var lines := [
		"seed %d  fps %d  speed x%d%s" % [run.seed_value, Engine.get_frames_per_second(), speed, "  BOT " + bot_build if bot != null else ""],
		"tile %d/%d  phase %s  fights %d  kills %d" % [run.tile_index, run.board.path.size(), str(run.phase), run.fights, run.kills],
		"spawns %d  cards %d  hand %d  notices %d" % [run.spawns.size(), run.placed.size(), run.hand.size(), run.notices.size()],
	]
	for i in lines.size():
		UiTheme.text(ci, 4, 18 + i * 8, lines[i], UiTheme.FS_SMALL, UiTheme.TEXT)


# --- settings --------------------------------------------------------------------------------------------


func _load_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return  # tests must neither read nor overwrite the player's settings
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		Art.bg_index = clampi(int(cfg.get_value("view", "background", 0)), 0, Art.BACKGROUNDS.size() - 1)
		auto_open = bool(cfg.get_value("play", "auto_open", false))
		pause_on_panel = bool(cfg.get_value("play", "pause_on_panel", true))
		auto_equip = bool(cfg.get_value("play", "auto_equip", false))


func _save_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var cfg := ConfigFile.new()
	cfg.set_value("view", "background", Art.bg_index)
	cfg.set_value("play", "auto_open", auto_open)
	cfg.set_value("play", "pause_on_panel", pause_on_panel)
	cfg.set_value("play", "auto_equip", auto_equip)
	cfg.save(SETTINGS_PATH)


# --- command line (for screenshots and quick tests) --------------------------------------------------------


func _parse_cli() -> Dictionary:
	var out := {}
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var a: String = args[i]
		if a.begins_with("--"):
			var key := a.substr(2)
			if i + 1 < args.size() and not String(args[i + 1]).begins_with("--"):
				out[key] = args[i + 1]
				i += 1
			else:
				out[key] = "1"
		i += 1
	return out


func _apply_cli_after_start() -> void:
	if _cli.has("fast"):
		var secs := float(_cli["fast"])
		var local_bot := bot if bot != null else Bot.new(run, "mix", run.seed_value)
		var t := 0.0
		while t < secs and run.phase != RunState.Phase.ENDED:
			run.advance(0.25)
			t += 0.25
			if bot != null or _cli.has("fast-bot"):
				local_bot.act()
	if _cli.has("level-up"):
		run.debug_level_up()
	if _cli.has("demo"):
		run.debug_demo()
	if _cli.has("open"):
		var kind := String(_cli["open"])
		var n := run.first_notice("lap_card" if kind == "card" else kind)
		if n != null:
			open_notice_panel(n)
	if _cli.has("hold"):
		held = int(_cli["hold"])
	if _cli.has("log"):
		show_log = true
	if _cli.has("debug"):
		debug_overlay = true
	if _cli.has("pause"):
		speed = 0
	if _cli.has("bg"):
		Art.bg_index = int(_cli["bg"]) % Art.BACKGROUNDS.size()


func _cli_tick() -> void:
	if _cli.has("mouse") and _frames == 2:
		var xy: PackedStringArray = String(_cli["mouse"]).split(",")
		get_viewport().warp_mouse(Vector2(float(xy[0]), float(xy[1])))
	if _cli.has("shot") and _frames >= int(_cli.get("shot-frames", 12)):
		var img := get_viewport().get_texture().get_image()
		img.save_png(_cli["shot"])
		print("saved ", _cli["shot"], " ", img.get_size())
		get_tree().quit()
	if _cli.has("quit-after") and _elapsed >= float(_cli["quit-after"]):
		get_tree().quit()

extends SceneTree
## Loads the real main scene headless, drives it with synthetic mouse and key events, and
## checks the screen reacts. Catches draw-time errors and broken wiring that the pure
## logic tests cannot see.
##
##   godot --headless --path . --script tests/ui_smoke.gd
##
## Exit code 1 on any failed check. Input events are delivered on the next frame, so every
## check runs a couple of frames after the action it verifies.

# Everything UI is loaded at run time: this script is compiled before the Art autoload
# exists, so it must not name UI classes statically.
var game
var UiT
var frame = 0
var step = 0
var failures: Array[String] = []
var checks = 0
var target = Vector2i(-1, -1)


func _initialize() -> void:
	UiT = load("res://src/ui/ui_theme.gd")
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)
		print("  FAIL ", msg)


func _click(p: Vector2) -> void:
	for pressed in [true, false]:
		var e = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = p
		e.global_position = p
		Input.parse_input_event(e)


func _key(code: int) -> void:
	for pressed in [true, false]:
		var e = InputEventKey.new()
		e.keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)


func _process(_delta: float) -> bool:
	frame += 1
	if frame < 3 or frame % 3 != 0:
		return false
	step += 1
	var run = game.run
	match step:
		1:
			game.start_run(42)
			game.speed = 0
		2:
			_click(UiT.HAND_RECT.position + game.hand_bar.slot_rect(0).get_center())
		3:
			check(game.held == 0, "clicking a hand card selects it")
			run = game.run
			for c in run.board.roadside_cells():
				if run.check_place(0, c)["ok"]:
					target = c
					break
			check(target.x >= 0, "there is a legal cell for the first card")
			_click(UiT.MAP_RECT.position + Vector2(target) * 16.0 + Vector2(8, 8))
		4:
			check(run.hand.size() == 2, "playing a card takes it out of the hand")
			check(run.placed.has(target), "the card is on the map")
			check(game.held == -1, "selection clears after playing")
			_key(KEY_3)
		5:
			check(game.speed == 4, "key 3 is x4")
			_key(KEY_SPACE)
		6:
			check(game.speed == 0, "space pauses")
			game.speed = 1
			run.debug_level_up()
			_key(KEY_N)
		7:
			check(game.open_notice != null and game.open_notice.kind == "stat", "N opens the stat notice")
		8:
			var spend: Dictionary = {}
			for h in game.choice._hits:
				if h["kind"] == "spend" and h["stat"] == "str":
					spend = h
			check(not spend.is_empty(), "the stat panel has a +1 for STR")
			if not spend.is_empty():
				_click(UiT.MAP_RECT.position + (spend["rect"] as Rect2).get_center())
		9:
			check(run.hero.pts["str"] == 1, "clicking +1 spends a stat point")
			_key(KEY_ESCAPE)
		10:
			check(game.open_notice == null, "Esc closes the panel")
			_key(KEY_L)
		11:
			check(game.show_log, "L opens the fight log")
			game.show_log = false
			game.speed = 0
			_key(KEY_TAB)
		12:
			check(game.side.tab == 1, "Tab goes to the town tab")
			_key(KEY_TAB)
		13:
			check(game.side.tab == 2, "Tab goes on to the goals tab")
			_key(KEY_TAB)
		14:
			check(game.side.tab == 3, "Tab goes on to the last-fight tab")
			_key(KEY_TAB)
		15:
			check(game.side.tab == 0, "Tab wraps back to the hero tab")
			# a skill card offer: pick it, drag it onto a hero skill slot
			var n = run._add_notice("skill_card", "skill card", "เลือก 1", {"offers": run.make_skill_offers()})
			game.open_notice_panel(n)
		16:
			check(game.open_notice != null and game.open_notice.kind == "skill_card", "a skill card panel opens")
			var offer: Dictionary = {}
			for h in game.choice._hits:
				if h["kind"] == "skill_offer" and h["index"] == 0:
					offer = h
			check(not offer.is_empty(), "the skill panel lists offers")
			if not offer.is_empty():
				_click(UiT.MAP_RECT.position + (offer["rect"] as Rect2).get_center())
		17:
			check(game.open_notice == null, "choosing a skill card closes its panel")
			check(run.hand.size() == 3 and run.hand[2].skill, "the chosen skill card is in the hand")
			_click(UiT.HAND_RECT.position + game.hand_bar.slot_rect(2).get_center())
		18:
			check(game.held == 2, "the skill card can be selected")
			_click(UiT.SIDE_RECT.position + game.side.skill_rect(0).get_center())
		19:
			check(run.hero.skills[0].has("id"), "clicking a skill slot with a skill card equips it")
			check(run.hand.size() == 2 and game.held == -1, "the skill card left the hand")
			# the events: a "?" panel with a plain option closes after choosing it
			game.open_notice_panel(run._add_notice("event", "ศาลเจ้า", "เรื่องราว", {"event": "shrine"}))
		20:
			check(game.open_notice != null and game.open_notice.kind == "event", "an event panel opens")
			var opt: Dictionary = {}
			for h in game.choice._hits:
				if h["kind"] == "event" and h["index"] == 1:
					opt = h
			check(not opt.is_empty(), "the event panel has a way to walk past")
			if not opt.is_empty():
				_click(UiT.MAP_RECT.position + (opt["rect"] as Rect2).get_center())
		21:
			check(game.open_notice == null and run.first_notice("event") == null, "walking past an event ends it")
			# settings: open, flip a switch by clicking it, leave with Esc
			game.show_settings = true
		22:
			var sw: Dictionary = {}
			for h in game.settings_view._hits:
				if h["kind"] == "pause":
					sw = h
			check(not sw.is_empty(), "the settings window lists the pause switch")
			if not sw.is_empty():
				_click((sw["rect"] as Rect2).get_center())
		23:
			check(not game.pause_on_panel, "settings can switch off pause-on-panel")
			_key(KEY_ESCAPE)
		24:
			check(not game.show_settings, "Esc closes settings")
			game.pause_on_panel = true
			# home screen: back to it, then start a run with Enter
			game.open_home()
		25:
			check(game.screen == game.Screen.HOME, "open_home shows the home screen")
			_key(KEY_ENTER)
		26:
			check(game.screen == game.Screen.RUN, "Enter starts a run from the home screen")
			run = game.run
			run.debug_level_up()
			# let a bot play a whole run at x4 so every view draws real states
			game.speed = 4
			game.bot_build = "mix"
			game.bot = load("res://src/core/bot.gd").new(run, "mix", 1)
		_:
			if step > 400 or run.phase == 2:
				check(step > 27, "the bot-driven run played on")
				print("%d checks, %d failures, run ended: %s after %.0f s" % [checks, failures.size(), str(run.phase == 2), run.time])
				quit(1 if not failures.is_empty() else 0)
				return true
	return false

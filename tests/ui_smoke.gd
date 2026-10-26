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
			# let a bot play a whole run at x4 so every view draws real states
			game.speed = 4
			game.bot_build = "mix"
			game.bot = load("res://src/core/bot.gd").new(run, "mix", 1)
		_:
			if step > 400 or run.phase == 2:
				check(step > 12, "the bot-driven run played on")
				print("%d checks, %d failures, run ended: %s after %.0f s" % [checks, failures.size(), str(run.phase == 2), run.time])
				quit(1 if not failures.is_empty() else 0)
				return true
	return false

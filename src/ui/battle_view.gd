class_name BattleView
extends Control
## The fight, drawn over the map: both sides with HP bars, floating numbers, and the last
## few lines of the log. Fills the "why did I win or lose" gap while the fight is live.

const PANEL_H := 78.0
const LINES := 4

var run: RunState
var game: Game

var _battle: Battle = null
var _seen := 0
var _floaters: Array[Dictionary] = []
var _banner := ""
var _banner_t := 0.0
var _banner_ok := true
var _hit_flash := {}  # foe index -> time left
var _hero_flash := 0.0
var _hero_anim := ""  # "" = standing; attack / cast / hurt play once, ko / victory stay
var _hero_anim_t0 := 0.0
var _foe_anims := {}  # foe index -> {"anim", "t0"}
var _jit := 0
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(p_run: RunState, p_game: Game) -> void:
	run = p_run
	game = p_game
	_battle = null
	_floaters.clear()
	_banner_t = 0.0
	run.battle_started.connect(_on_started)
	run.battle_ended.connect(_on_ended)


func _on_started(b: Battle) -> void:
	_battle = b
	_seen = 0
	_floaters.clear()
	_hit_flash.clear()
	_foe_anims.clear()
	_hero_anim = ""
	_banner_t = 0.0


func _on_ended(b: Battle) -> void:
	_consume(b)
	_banner = "ชนะ! +%d XP" % b.stats["xp"] if b.hero_won else "พ่ายแพ้…"
	_banner_ok = b.hero_won
	_banner_t = 1.6
	_play_hero("victory" if b.hero_won else "ko")
	_battle = b  # keep drawing the final state while the banner shows


func _consume(b: Battle) -> void:
	while _seen < b.history.size():
		var e: Dictionary = b.history[_seen]
		_seen += 1
		match e["k"]:
			"hit":
				_float_on_foe(int(e["foe"]), str(roundi(e["dmg"])), UiTheme.GOLD if (e.get("crit", false) or e.get("via", "") != "") else UiTheme.TEXT)
				_hit_flash[int(e["foe"])] = 0.12
				_play_foe(int(e["foe"]), "hurt")
				if e.get("via", "") == "":  # a skill's damage comes with its own "cast" pose
					_play_hero("attack")
			"miss":
				_float_on_foe(int(e["foe"]), "พลาด", UiTheme.TEXT_DIM)
				_play_hero("attack")
			"foe_hit":
				_float_on_hero(str(roundi(e["dmg"])) + ("!" if e.get("slam", false) else ""), UiTheme.BAD)
				_hero_flash = 0.12
				_play_foe(int(e["foe"]), "attack")
				_play_hero("hurt")
			"foe_miss":
				_float_on_hero("หลบ", UiTheme.TEXT_DIM)
				_play_foe(int(e["foe"]), "attack")
			"heal":
				_float_on_hero("+%d" % roundi(e["amount"]), UiTheme.GOOD)
			"cast":
				_float_on_hero((b.db.skills[e["skill"]] as GameDb.SkillDef).name_th, Color("2ce8f5"))
				_play_hero("cast")


func _play_hero(anim: String) -> void:
	_hero_anim = anim
	_hero_anim_t0 = _t


func _play_foe(i: int, anim: String) -> void:
	_foe_anims[i] = {"anim": anim, "t0": _t}


## How long a one-shot pose is held before the unit goes back to standing.
func _hold(id: String, anim: String) -> float:
	match anim:
		"hurt":
			return 0.2
		"cast":
			return 0.35
	return Art.anim_length(id, anim)


## [anim, seconds into it] for the hero right now. Standing is the first walk frame.
func _hero_pose() -> Array:
	var age := _t - _hero_anim_t0
	if _hero_anim == "ko" or _hero_anim == "victory":
		return [_hero_anim, age]
	if _hero_anim != "" and age < _hold("hero", _hero_anim):
		return [_hero_anim, age]
	return ["walk", 0.0]


func _float_on_foe(i: int, s: String, c: Color) -> void:
	_floaters.append({"text": s, "color": c, "pos": _foe_pos(i) + Vector2(8 + _jitter(), -2), "age": 0.0})


func _float_on_hero(s: String, c: Color) -> void:
	_floaters.append({"text": s, "color": c, "pos": _hero_pos() + Vector2(8 + _jitter(), -2), "age": 0.0})


## Spreads numbers that appear together so they stay readable.
func _jitter() -> float:
	_jit = (_jit + 1) % 5
	return (_jit - 2) * 6.0


func _panel_rect() -> Rect2:
	var top := run.hero_cell_pos().y * 16.0 > size.y * 0.5
	return Rect2(6, 6 if top else size.y - PANEL_H - 6, size.x - 12, PANEL_H)


func _hero_pos() -> Vector2:
	var r := _panel_rect()
	return r.position + Vector2(12, 14)


func _foe_pos(i: int) -> Vector2:
	var r := _panel_rect()
	var n := _battle.foes.size() if _battle != null else 1
	var step := minf(34.0, (r.size.x - 140.0) / maxf(1.0, n))
	return Vector2(r.end.x - 20 - step * (i + 1) + step * 0.2, r.position.y + 14)


func _process(delta: float) -> void:
	_t += delta
	_banner_t = maxf(0.0, _banner_t - delta)
	_hero_flash = maxf(0.0, _hero_flash - delta)
	for k in _hit_flash.keys():
		_hit_flash[k] -= delta
	for f in _floaters:
		f["age"] += delta
	_floaters = _floaters.filter(func(f): return f["age"] < 0.9)
	if _battle != null:
		_consume(_battle)
		if _battle.finished and _banner_t <= 0.0 and _floaters.is_empty():
			_battle = null
	visible = _battle != null
	queue_redraw()


func _draw() -> void:
	if _battle == null or run == null:
		return
	var b := _battle
	var r := _panel_rect()
	draw_rect(r, Color(UiTheme.BG, 0.88))
	draw_rect(r, UiTheme.BORDER, false, 1.0)
	var h := run.hero
	# hero side
	var hp := _hero_pos()
	var pose := _hero_pose()
	Art.draw_unit_anim(self, "hero", hp, pose[0], pose[1], 2, Color(1, 0.6, 0.6) if _hero_flash > 0.0 else Color.WHITE)
	var bx := r.position.x + 32
	UiTheme.bar(self, Rect2(bx, r.position.y + 5, 76, 8), h.hp / h.max_hp, UiTheme.HP_COL)
	UiTheme.text(self, bx + 3, r.position.y + 5, "%d/%d" % [ceili(h.hp), roundi(h.max_hp)], UiTheme.FS_SMALL, UiTheme.TEXT, true)
	UiTheme.bar(self, Rect2(bx, r.position.y + 15, 76, 6), b.mana / h.max_mana, UiTheme.MANA_COL)
	if b.shield_left > 0.0:
		UiTheme.text(self, bx, r.position.y + 22, "โล่ %d (%.0f วิ)" % [roundi(b.shield), b.shield_left], UiTheme.FS_SMALL, Color("2ce8f5"))
	elif b.haste_left > 0.0:
		UiTheme.text(self, bx, r.position.y + 22, "เร่ง %.0f วิ" % b.haste_left, UiTheme.FS_SMALL, Color("2ce8f5"))
	else:
		UiTheme.text(self, bx, r.position.y + 22, "ตี %.2f/วิ  ATK %s" % [b.current_aps(), UiTheme.num(h.atk)], UiTheme.FS_SMALL, UiTheme.TEXT_DIM)
	# foes, front-most on the left of the group
	for i in b.foes.size():
		var f := b.foes[i]
		var p := _foe_pos(i)
		var tint := Color.WHITE
		if not f.alive:
			tint = Color(1, 1, 1, 0.25)
		elif _hit_flash.get(i, 0.0) > 0.0:
			tint = Color(1, 0.6, 0.6)
		var anim := "idle"
		var anim_t := _t + i * 0.37
		var st: Dictionary = _foe_anims.get(i, {})
		if not f.alive:
			anim = "hurt"
			anim_t = 0.0
		elif not st.is_empty() and _t - st["t0"] < _hold(f.def.id, st["anim"]):
			anim = st["anim"]
			anim_t = _t - st["t0"]
		Art.draw_unit_anim(self, f.def.id, p, anim, anim_t, 0, tint, f.elite)
		UiTheme.bar(self, Rect2(p + Vector2(1, 17), Vector2(14, 4)), maxf(0.0, f.hp) / f.max_hp, UiTheme.HP_COL)
		if f.elite and not Art.has_real("units", "crown"):
			UiTheme.text(self, p.x + 1, p.y - 9, "★", UiTheme.FS_SMALL, UiTheme.GOLD, true)
	# log
	var ly := r.position.y + 35.0
	var shown := 0
	var start := b.history.size() - 1
	var lines: Array[Dictionary] = []
	while start >= 0 and lines.size() < LINES:
		var e: Dictionary = b.history[start]
		var s := BattleText.describe(e, b)
		if s != "":
			lines.append({"t": s, "c": BattleText.color(e)})
		start -= 1
	for i in lines.size():
		var line: Dictionary = lines[lines.size() - 1 - i]
		UiTheme.text(self, r.position.x + 6, ly + shown * 9.0, line["t"], UiTheme.FS_SMALL, line["c"])
		shown += 1
	# floating numbers
	for f in _floaters:
		var pos: Vector2 = f["pos"] + Vector2(0, -10.0 * f["age"])
		var c: Color = f["color"]
		c.a = clampf(1.2 - f["age"], 0.0, 1.0)
		var w := UiTheme.text_width(f["text"], UiTheme.FS, true)
		UiTheme.text(self, pos.x - w / 2.0, pos.y, f["text"], UiTheme.FS, c, true)
	if _banner_t > 0.0:
		var w := UiTheme.text_width(_banner, UiTheme.FS_BIG, true)
		UiTheme.text(self, r.get_center().x - w / 2.0, r.position.y + 22, _banner, UiTheme.FS_BIG, UiTheme.GOOD if _banner_ok else UiTheme.BAD, true)

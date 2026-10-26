class_name Battle
extends RefCounted
## One auto battle: the hero against a group of foes (docs/design/04-hero-combat.md).
##
## Pure simulation with no nodes, stepped with step(dt). The numbers match
## tools/balance_sim.py; if you change a rule here, change it there too.
##
## Everything that happens is appended to `events` (drained by the view for floating
## numbers) and to `history` (kept for the log and the "why did I win/lose" summary).

const SHIELD_CAP_X := 10.0  # of max HP; effectively uncapped, same as balance_sim.py

var db: GameDb
var hero: Hero
var foes: Array[Foe] = []
var rng: RandomNumberGenerator

var time := 0.0
var finished := false
var hero_won := false
var mana := 0.0
var shield := 0.0
var shield_left := 0.0
var haste_left := 0.0

var events: Array[Dictionary] = []
var history: Array[Dictionary] = []
var kills: Array[Foe] = []
var stats := {}

var _haste_bonus := 0.0
var _attack_timer := 0.0
var _hp_start := 0.0
var _limit := 600.0


func _init(p_db: GameDb, p_hero: Hero, p_foes: Array[Foe], p_rng: RandomNumberGenerator) -> void:
	db = p_db
	hero = p_hero
	foes = p_foes
	rng = p_rng
	mana = db.c("hero_start_mana") * hero.max_mana
	_hp_start = hero.hp
	_limit = db.c("battle_time_limit")
	stats = {
		"hero_hits": 0,
		"hero_crits": 0,
		"hero_misses": 0,
		"dmg_normal": 0.0,
		"dmg_skill": 0.0,
		"dmg_taken": 0.0,
		"dmg_absorbed": 0.0,
		"foe_attacks": 0,
		"foe_dodged": 0,
		"healed": 0.0,
		"casts": {},
		"slams": 0,
	}


func alive_foes() -> Array[Foe]:
	var out: Array[Foe] = []
	for f in foes:
		if f.alive:
			out.append(f)
	return out


func foe_index(f: Foe) -> int:
	return foes.find(f)


func current_aps() -> float:
	if haste_left > 0.0:
		return hero.aps * (1.0 + _haste_bonus)
	return hero.aps


## Advances the fight by dt seconds. Safe to call after it finished (does nothing).
func step(dt: float) -> void:
	if finished:
		return
	time += dt
	var alive := alive_foes()
	if alive.is_empty():
		_finish(true)
		return

	# --- mana and skills: slot 1 is checked first, at most one cast per step ---
	mana = minf(hero.max_mana, mana + hero.mana_regen * dt)
	for slot in hero.skills:
		if slot.is_empty():
			continue
		var sdef: GameDb.SkillDef = db.skills[slot["id"]]
		if mana < sdef.mana:
			continue
		if slot["id"] == "heal" and hero.hp > 0.5 * hero.max_hp:
			continue
		if slot["id"] == "mana_shield" and shield_left > 0.0:
			continue
		mana -= sdef.mana
		_cast(slot["id"], int(slot["level"]), alive)
		break

	haste_left = maxf(0.0, haste_left - dt)
	shield_left = maxf(0.0, shield_left - dt)
	if shield_left == 0.0:
		shield = 0.0

	# --- hero's normal attack, always at the front-most foe ---
	_attack_timer += dt
	alive = alive_foes()
	var interval := 1.0 / current_aps()
	if not alive.is_empty() and _attack_timer >= interval:
		_attack_timer -= interval
		_hero_attack(alive[0])
		mana = minf(hero.max_mana, mana + db.c("hero_mana_per_hit"))

	# --- foes ---
	for f in alive_foes():
		f.timer += dt
		if f.timer >= 1.0 / f.aps:
			f.timer -= 1.0 / f.aps
			_foe_attack(f)
			if hero.hp <= 0.0:
				hero.hp = 0.0
				_finish(false)
				return

	if alive_foes().is_empty():
		_finish(true)
	elif time >= _limit:
		_finish(false)


## Runs the fight to the end. Used by the balance tests; the game steps it live instead.
func run_to_end(dt: float = 0.05) -> bool:
	while not finished:
		step(dt)
	return hero_won


# --- hero ---------------------------------------------------------------------------


func _hero_attack(target: Foe) -> void:
	var i := foe_index(target)
	if rng.randf() < target.evasion:
		stats["hero_misses"] += 1
		_emit({"k": "miss", "foe": i})
		return
	var is_crit := rng.randf() < hero.crit
	var raw := hero.atk * (hero.crit_damage if is_crit else 1.0)
	var dmg := maxf(1.0, raw - target.df)
	stats["hero_hits"] += 1
	if is_crit:
		stats["hero_crits"] += 1
	stats["dmg_normal"] += dmg
	_emit({"k": "hit", "foe": i, "dmg": dmg, "crit": is_crit, "via": ""})
	_damage_foe(target, dmg)


func _cast(skill_id: String, lv: int, alive: Array[Foe]) -> void:
	var p := (db.skills[skill_id] as GameDb.SkillDef).level_params(lv)
	stats["casts"][skill_id] = int(stats["casts"].get(skill_id, 0)) + 1
	_emit({"k": "cast", "skill": skill_id, "level": lv})
	match skill_id:
		"fireball":
			# front foe, ignores evasion and DEF
			var dmg: float = p["flat"] + p["ap_x"] * hero.ap
			_skill_hit(alive[0], dmg, skill_id)
		"cleave":
			for f in alive:
				var dmg: float = maxf(1.0, p["atk_x"] * hero.atk - f.df) + p["ap_x"] * hero.ap
				_skill_hit(f, dmg, skill_id)
		"heal":
			var amount: float = p["max_hp_pct"] * hero.max_hp + p["ap_x"] * hero.ap
			var got := hero.heal(amount)
			stats["healed"] += got
			_emit({"k": "heal", "amount": got})
		"haste":
			_haste_bonus = p["bonus_pct"]
			haste_left = p["seconds"]
			_emit({"k": "buff", "skill": skill_id, "seconds": haste_left})
		"mana_shield":
			shield = minf(SHIELD_CAP_X * hero.max_hp, p["flat"] + p["ap_x"] * hero.ap)
			shield_left = p["seconds"]
			_emit({"k": "buff", "skill": skill_id, "seconds": shield_left, "amount": shield})


func _skill_hit(target: Foe, dmg: float, skill_id: String) -> void:
	stats["dmg_skill"] += dmg
	_emit({"k": "hit", "foe": foe_index(target), "dmg": dmg, "crit": false, "via": skill_id})
	_damage_foe(target, dmg)


func _damage_foe(f: Foe, dmg: float) -> void:
	f.hp -= dmg
	if f.hp <= 0.0 and f.alive:
		f.alive = false
		kills.append(f)
		_emit({"k": "kill", "foe": foe_index(f), "xp": f.xp})


# --- foes ---------------------------------------------------------------------------


func _foe_attack(f: Foe) -> void:
	var i := foe_index(f)
	stats["foe_attacks"] += 1
	if rng.randf() < hero.evasion:
		stats["foe_dodged"] += 1
		_emit({"k": "foe_miss", "foe": i})
		return
	var dmg := f.atk
	var slam := f.slam_chance > 0.0 and rng.randf() < f.slam_chance
	if slam:
		dmg *= 2.0
		stats["slams"] += 1
	var absorbed := minf(shield, dmg)
	shield -= absorbed
	hero.hp -= dmg - absorbed
	stats["dmg_taken"] += dmg - absorbed
	stats["dmg_absorbed"] += absorbed
	_emit({"k": "foe_hit", "foe": i, "dmg": dmg, "absorbed": absorbed, "slam": slam})


# --- bookkeeping ---------------------------------------------------------------------


func _emit(e: Dictionary) -> void:
	e["t"] = time
	events.append(e)
	history.append(e)


## Hands the view everything new since the last call.
func drain_events() -> Array[Dictionary]:
	var out := events
	events = []
	return out


func _finish(won: bool) -> void:
	finished = true
	hero_won = won
	var xp := 0
	for f in kills:
		xp += f.xp
	stats["time"] = time
	stats["hp_start"] = _hp_start
	stats["hp_end"] = hero.hp
	stats["won"] = won
	stats["xp"] = xp
	stats["kills"] = kills.size()
	stats["foes"] = foes.size()
	_emit({"k": "end", "won": won})


## Plain-language reasons for the result, most important first. This is what answers
## "why did I win / lose" without reading the log.
func explain() -> Array[String]:
	var out: Array[String] = []
	var s := stats
	var dur: float = maxf(0.001, s.get("time", time))
	var hero_dps: float = (s["dmg_normal"] + s["dmg_skill"]) / dur
	var foe_dps: float = (s["dmg_taken"] + s["dmg_absorbed"]) / dur
	out.append(
		(
			"ฮีโร่ทำดาเมจ %.1f/วิ (ตีธรรมดา %d, skill %d)  ศัตรูทำ %.1f/วิ"
			% [hero_dps, roundi(s["dmg_normal"]), roundi(s["dmg_skill"]), foe_dps]
		)
	)
	var total_hp := 0.0
	for f in foes:
		total_hp += f.max_hp
	out.append("HP รวมศัตรู %d ใช้เวลา %.1f วิ" % [roundi(total_hp), dur])
	if s["foe_attacks"] > 0:
		out.append(
			"หลบได้ %d จาก %d ครั้ง, ดูดซับด้วยโล่ %d" % [s["foe_dodged"], s["foe_attacks"], roundi(s["dmg_absorbed"])]
		)
	if s["hero_hits"] + s["hero_misses"] > 0:
		out.append(
			(
				"ตีโดน %d พลาด %d (ศัตรูหลบ) คริติคอล %d"
				% [s["hero_hits"], s["hero_misses"], s["hero_crits"]]
			)
		)
	var casts: Dictionary = s["casts"]
	if not casts.is_empty():
		var parts: PackedStringArray = []
		for id in casts:
			parts.append("%s x%d" % [(db.skills[id] as GameDb.SkillDef).name_th, casts[id]])
		out.append("skill: " + ", ".join(parts))
	var hp_now: float = s.get("hp_end", hero.hp)
	var lost: float = s.get("hp_start", _hp_start) - hp_now
	if not finished:
		out.append("กำลังสู้อยู่ เสีย HP แล้ว %d (ศัตรูเหลือ %d ตัว)" % [roundi(lost), alive_foes().size()])
	elif s.get("won", false):
		out.append("ชนะ เสีย HP %d (เหลือ %d)" % [roundi(lost), roundi(hp_now)])
	else:
		out.append("แพ้: HP หมดก่อนศัตรูตาย (ศัตรูเหลือ %d ตัว)" % alive_foes().size())
	return out

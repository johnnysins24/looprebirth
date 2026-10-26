class_name Hero
extends RefCounted
## The hero: level, stat points, and every derived stat (docs/design/04-hero-combat.md).
##
## Anything that changes a stat (stat points, gear, terrain cards) goes through
## set_mods(source, {stat: value}); recalc() then rebuilds the derived values.

const STATS := ["str", "agi", "int"]

var db: GameDb
var level := 1
var xp := 0
var unspent := 0  ## stat points not spent yet
var pts := {"str": 0, "agi": 0, "int": 0}
var hp := 0.0
var skills: Array = []  ## equipped skill cards: [{id: String, level: int, progress: int}] ({} for an empty slot)

## source name -> {stat: value}. Keys: max_hp, atk, ap, max_mana, attack_speed, evasion,
## crit, crit_damage, luck, mana_regen
var mods: Dictionary = {}

# derived values, refreshed by recalc()
var max_hp := 100.0
var atk := 8.0
var aps := 0.8
var evasion := 0.05
var ap := 0.0
var max_mana := 30.0
var mana_regen := 2.0
var crit := 0.0
var crit_damage := 1.5
var luck := 0.0

var _ready_done := false


func _init(p_db: GameDb) -> void:
	db = p_db
	recalc()
	hp = max_hp
	_ready_done = true


## XP needed to go from `lv` to `lv + 1`.
func xp_needed(lv: int = -1) -> int:
	if lv < 0:
		lv = level
	return db.ci("xp_base") + db.ci("xp_step") * (lv - 1)


## Adds XP and returns how many levels were gained. Each level gives stat points.
func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		gained += 1
		unspent += db.ci("points_per_level")
	return gained


## Spends one stat point. Returns false when there is nothing to spend.
func spend(stat: String) -> bool:
	if unspent <= 0 or not pts.has(stat):
		return false
	unspent -= 1
	pts[stat] += 1
	recalc()
	return true


func set_mods(source: String, values: Dictionary) -> void:
	if values.is_empty():
		mods.erase(source)
	else:
		mods[source] = values
	recalc()


func mod_total(stat: String, p_mods: Dictionary = mods) -> float:
	var total := 0.0
	for source in p_mods:
		total += float(p_mods[source].get(stat, 0.0))
	return total


## Derived stats for the given stat points. Pure, so the stat panel can preview a
## point before it is spent.
func compute(p_pts: Dictionary, p_mods: Dictionary = mods) -> Dictionary:
	var s: float = p_pts["str"]
	var a: float = p_pts["agi"]
	var i: float = p_pts["int"]
	var out := {}
	out["max_hp"] = db.c("hero_hp") + db.c("str_hp") * s + mod_total("max_hp", p_mods)
	out["atk"] = db.c("hero_atk") + db.c("str_atk") * s + mod_total("atk", p_mods)
	out["aps"] = minf(
		db.c("aps_cap"),
		db.c("hero_aps") * (1.0 + db.c("agi_as") * a + mod_total("attack_speed", p_mods))
	)
	out["evasion"] = minf(
		db.c("eva_cap"), db.c("hero_eva") + db.c("agi_eva") * a + mod_total("evasion", p_mods)
	)
	out["ap"] = db.c("int_ap") * i + mod_total("ap", p_mods)
	out["max_mana"] = db.c("hero_mana") + db.c("int_mana") * i + mod_total("max_mana", p_mods)
	out["mana_regen"] = db.c("hero_mregen") + db.c("int_mregen") * i + mod_total("mana_regen", p_mods)
	out["crit"] = db.c("hero_crit") + mod_total("crit", p_mods)
	out["crit_damage"] = db.c("hero_critd") + mod_total("crit_damage", p_mods)
	out["luck"] = mod_total("luck", p_mods)
	return out


func recalc() -> void:
	var d := compute(pts)
	var old_max := max_hp
	max_hp = d["max_hp"]
	atk = d["atk"]
	aps = d["aps"]
	evasion = d["evasion"]
	ap = d["ap"]
	max_mana = d["max_mana"]
	mana_regen = d["mana_regen"]
	crit = d["crit"]
	crit_damage = d["crit_damage"]
	luck = d["luck"]
	if _ready_done:
		# More max HP also raises current HP by the same amount (otherwise a point in STR
		# would not help until the next heal); less max HP only clamps.
		if max_hp > old_max:
			hp += max_hp - old_max
		hp = minf(hp, max_hp)


func heal(amount: float) -> float:
	var before := hp
	hp = minf(max_hp, hp + amount)
	return hp - before


func equip_skill(slot: int, skill_id: String, skill_level: int = 1, progress: int = 0) -> void:
	while skills.size() <= slot:
		skills.append({})
	skills[slot] = {"id": skill_id, "level": skill_level, "progress": progress}


## One line per derived stat, for the stat panel and the tests.
func snapshot() -> Dictionary:
	return {
		"level": level,
		"xp": xp,
		"hp": hp,
		"max_hp": max_hp,
		"atk": atk,
		"aps": aps,
		"evasion": evasion,
		"ap": ap,
		"max_mana": max_mana,
		"mana_regen": mana_regen,
		"crit": crit,
		"crit_damage": crit_damage,
		"luck": luck,
		"pts": pts.duplicate(),
		"unspent": unspent,
	}

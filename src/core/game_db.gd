class_name GameDb
extends RefCounted
## Loads every CSV in res://data/ into typed lookups.
##
## The CSVs are the single source of truth for numbers (see docs/design). Nothing in
## src/ hardcodes a stat that also lives in a table; tune the CSV, not the code.

const DATA_DIR := "res://data/"


class EnemyDef:
	extends RefCounted
	var id := ""
	var name_th := ""
	var name_en := ""
	var hp := 1.0
	var atk := 0.0
	var aps := 1.0
	var df := 0.0
	var evasion := 0.0
	var xp := 0.0
	var item_drop := 0.0
	var scales := true  ## false for the boss: no growth per lap
	var slam_chance := 0.0
	var notes := ""

	func is_boss() -> bool:
		return not scales


class SkillDef:
	extends RefCounted
	var id := ""
	var name_th := ""
	var name_en := ""
	var mana := 0.0
	var trigger := ""
	var unlock := "start"
	var levels: Array = []  ## index 0..2 -> Dictionary of that level's numbers

	func level_params(level: int) -> Dictionary:
		return levels[clampi(level, 1, levels.size()) - 1]


class CardDef:
	extends RefCounted
	var id := ""
	var name_th := ""
	var name_en := ""
	var type := ""  ## terrain | encounter | building | special
	var placement := ""
	var unlock := "start"
	var enemy_id := ""  ## encounter cards: the enemy they spawn (last word of the L1 text)
	var desc_th := ""  ## effect text with {v} value, {p} value as %, {n} count, {e} elite note
	var place_th := ""  ## where it can be played
	var levels: Array = []  ## index 0..2 -> {value, count, elite, text}

	func level_params(level: int) -> Dictionary:
		return levels[clampi(level, 1, levels.size()) - 1]

	## Thai effect text for one level, numbers filled in from card_levels.csv.
	func describe(level: int) -> String:
		var p := level_params(level)
		var v: float = p.get("value", 0.0)
		var elite := int(p.get("elite", 0))
		var vs := ("%d" % roundi(v)) if absf(v - roundf(v)) < 0.001 else ("%.1f" % v)
		return (
			desc_th
			.replace("{v}", vs)
			.replace("{p}", "%d" % roundi(v * 100.0))
			.replace("{n}", str(int(p.get("count", 0))))
			.replace("{e}", (" (มี elite %d)" % elite) if elite > 0 else "")
		)

	func is_encounter() -> bool:
		return type == "encounter"


class ComboDef:
	extends RefCounted
	var id := ""
	var name_th := ""
	var a := ""
	var b := ""
	var value := 0.0
	var value2 := 0.0
	var description := ""


class PerkDef:
	extends RefCounted
	var id := ""
	var name_th := ""
	var effect := ""


class NodeDef:
	extends RefCounted
	var id := ""
	var branch := ""  ## utility | card_unlock | skill_unlock
	var name_th := ""
	var effect_th := ""
	var ranks := 1
	var costs: Array[int] = []  ## RP for each rank
	var requires := ""  ## node id that must have at least `requires_rank` ranks
	var requires_rank := 0

	func cost_of(rank: int) -> int:
		return costs[clampi(rank, 1, costs.size()) - 1]

	## The card or skill id an unlock node adds to the pool ("unlock_heal" -> "heal"), or "".
	func unlock_id() -> String:
		return id.trim_prefix("unlock_") if id.begins_with("unlock_") else ""


class GoalDef:
	extends RefCounted
	var id := ""
	var goal_th := ""
	var rp := 1


class ItemStatDef:
	extends RefCounted
	var stat := ""
	var name_th := ""
	var lo := 0.0
	var hi := 0.0
	var per_level := 0.0


class EventDef:
	extends RefCounted
	var id := ""
	var name_th := ""
	var story_th := ""
	var a_th := ""
	var b_th := ""


var consts: Dictionary = {}  # String -> float
var enemies: Dictionary = {}  # String -> EnemyDef
var skills: Dictionary = {}  # String -> SkillDef
var cards: Dictionary = {}  # String -> CardDef
var combos: Dictionary = {}  # String -> ComboDef
var perks: Dictionary = {}  # String -> PerkDef
var nodes: Dictionary = {}  # String -> NodeDef
var goals: Dictionary = {}  # String -> GoalDef
var events: Dictionary = {}  # String -> EventDef
var item_stats: Array[ItemStatDef] = []
var skill_order: Array[String] = []
var card_order: Array[String] = []
var perk_order: Array[String] = []
var node_order: Array[String] = []
var goal_order: Array[String] = []
var event_order: Array[String] = []


static func load_default() -> GameDb:
	var db := GameDb.new()
	db.load_all(DATA_DIR)
	return db


func load_all(dir: String) -> void:
	_load_constants(dir + "constants.csv")
	_load_enemies(dir + "enemies.csv")
	_load_skills(dir + "skills.csv", dir + "skill_levels.csv")
	_load_cards(dir + "cards.csv", dir + "card_levels.csv", dir + "card_text.csv")
	_load_combos(dir + "combos.csv")
	_load_perks(dir + "town_perks.csv")
	_load_tree(dir + "rebirth_tree.csv")
	_load_goals(dir + "run_goals.csv")
	_load_events(dir + "events.csv")
	_load_item_stats(dir + "item_stats.csv")


## Numeric constant from constants.csv. A missing key is a data bug, so it is loud.
func c(key: String) -> float:
	if not consts.has(key):
		push_error("constants.csv has no key '%s'" % key)
		return 0.0
	return consts[key]


func ci(key: String) -> int:
	return roundi(c(key))


func unlocked_card_ids(unlocked_flags: Array = []) -> Array[String]:
	var out: Array[String] = []
	for id in card_order:
		var d: CardDef = cards[id]
		if d.unlock == "start" or unlocked_flags.has(d.unlock) or unlocked_flags.has(id):
			out.append(id)
	return out


## Skills that can show up as skill cards: the starting ones plus what the Rebirth tree
## unlocked (`unlocked_flags` holds skill ids, like it holds card ids for cards).
func unlocked_skill_ids(unlocked_flags: Array = []) -> Array[String]:
	var out: Array[String] = []
	for id in skill_order:
		var d: SkillDef = skills[id]
		if d.unlock == "start" or unlocked_flags.has(id):
			out.append(id)
	return out


# --- CSV helpers -----------------------------------------------------------------

## Reads a CSV into an array of {header: value} dictionaries (all strings).
static func read_csv(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return rows
	var header := f.get_csv_line()
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() == 1 and line[0].strip_edges() == "":
			continue
		var row := {}
		for i in header.size():
			row[header[i].strip_edges()] = line[i].strip_edges() if i < line.size() else ""
		rows.append(row)
	return rows


## "12%" -> 0.12, "3.5" -> 3.5, "" -> 0.
static func num(s: String) -> float:
	s = s.strip_edges()
	if s == "":
		return 0.0
	if s.ends_with("%"):
		return s.trim_suffix("%").to_float() / 100.0
	return s.to_float()


# --- loaders ----------------------------------------------------------------------

func _load_constants(path: String) -> void:
	for r in read_csv(path):
		consts[r["key"]] = num(r["value"])


func _load_enemies(path: String) -> void:
	for r in read_csv(path):
		var e := EnemyDef.new()
		e.id = r["id"]
		e.name_th = r["name_th"]
		e.name_en = r["name_en"]
		e.hp = num(r["hp"])
		e.atk = num(r["atk"])
		e.aps = num(r["attacks_per_s"])
		e.df = num(r["def"])
		e.evasion = num(r["evasion"])
		e.xp = num(r["xp"])
		e.item_drop = num(r["item_drop"])
		e.scales = num(r.get("scales", "1")) != 0.0
		e.slam_chance = num(r.get("slam_chance", "0"))
		e.notes = r.get("notes", "")
		enemies[e.id] = e


func _load_skills(path: String, levels_path: String) -> void:
	for r in read_csv(path):
		var s := SkillDef.new()
		s.id = r["id"]
		s.name_th = r["name_th"]
		s.name_en = r["name_en"]
		s.mana = num(r["mana"])
		s.trigger = r["trigger"]
		s.unlock = r["unlock"]
		skills[s.id] = s
		skill_order.append(s.id)
	for r in read_csv(levels_path):
		var s: SkillDef = skills.get(r["skill"])
		if s == null:
			push_error("skill_levels.csv: unknown skill '%s'" % r["skill"])
			continue
		var lv := int(r["level"])
		while s.levels.size() < lv:
			s.levels.append({})
		var p := {}
		for k in ["flat", "atk_x", "ap_x", "max_hp_pct", "bonus_pct", "seconds"]:
			p[k] = num(r[k])
		s.levels[lv - 1] = p


func _load_cards(path: String, levels_path: String, text_path: String) -> void:
	for r in read_csv(path):
		var d := CardDef.new()
		d.id = r["id"]
		d.name_th = r["name_th"]
		d.name_en = r["name_en"]
		d.type = r["type"]
		d.placement = r["placement"]
		d.unlock = r["unlock"]
		d.levels = [
			{"text": r["l1"]},
			{"text": r["l2"]},
			{"text": r["l3"]},
		]
		if d.type == "encounter":
			d.enemy_id = String(r["l1"]).split(" ")[-1]
		cards[d.id] = d
		card_order.append(d.id)
	for r in read_csv(levels_path):
		var d: CardDef = cards.get(r["card"])
		if d == null:
			push_error("card_levels.csv: unknown card '%s'" % r["card"])
			continue
		var lv := int(r["level"])
		var p: Dictionary = d.levels[lv - 1]
		p["value"] = num(r["value"])
		p["count"] = int(num(r["count"]))
		p["elite"] = int(num(r["elite"]))
	for r in read_csv(text_path):
		var d: CardDef = cards.get(r["card"])
		if d != null:
			d.desc_th = r["desc_th"]
			d.place_th = r["place_th"]


func _load_combos(path: String) -> void:
	for r in read_csv(path):
		var k := ComboDef.new()
		k.id = r["id"]
		k.name_th = r["name_th"]
		k.a = r["a"]
		k.b = r["b"]
		k.value = num(r["value"])
		k.value2 = num(r["value2"])
		k.description = r["description"]
		combos[k.id] = k


func _load_perks(path: String) -> void:
	for r in read_csv(path):
		var p := PerkDef.new()
		p.id = r["id"]
		p.name_th = r["name_th"]
		p.effect = r["effect"]
		perks[p.id] = p
		perk_order.append(p.id)


func _load_tree(path: String) -> void:
	for r in read_csv(path):
		var n := NodeDef.new()
		n.id = r["id"]
		n.branch = r["branch"]
		n.name_th = r["name_th"]
		n.effect_th = r["effect_th"]
		n.ranks = int(num(r["ranks"]))
		for part in String(r["cost_per_rank"]).split("/"):
			n.costs.append(int(num(part)))
		var req := String(r["requires"])
		if req != "":
			var bits := req.split(":")
			n.requires = bits[0]
			n.requires_rank = int(bits[1]) if bits.size() > 1 else 1
		nodes[n.id] = n
		node_order.append(n.id)


func _load_goals(path: String) -> void:
	for r in read_csv(path):
		var g := GoalDef.new()
		g.id = r["id"]
		g.goal_th = r["goal_th"]
		g.rp = int(num(r["rebirth_points"]))
		goals[g.id] = g
		goal_order.append(g.id)


func _load_events(path: String) -> void:
	for r in read_csv(path):
		var e := EventDef.new()
		e.id = r["id"]
		e.name_th = r["name_th"]
		e.story_th = r["story_th"]
		e.a_th = r["a_th"]
		e.b_th = r["b_th"]
		events[e.id] = e
		event_order.append(e.id)


func _load_item_stats(path: String) -> void:
	for r in read_csv(path):
		var d := ItemStatDef.new()
		d.stat = r["stat"]
		d.name_th = r["name_th"]
		d.lo = num(r["lo"])
		d.hi = num(r["hi"])
		d.per_level = num(r["per_level"])
		item_stats.append(d)

class_name CardRules
extends RefCounted
## Pure rules for cards on the map: where they can go, merging, combos, and the numbers
## they feed into the hero. No state here; RunState owns the board of placed cards.
##
## `placed` is a Dictionary of Vector2i -> CardInst.


## Can `card` be played on `cell`? Returns
## {ok, reason (Thai, when not ok), action: "place" | "merge" | "clear", level}.
## `blocked_road` is the road index under the hero's feet; encounters cannot go there.
static func check_place(
	db: GameDb, board: Board, placed: Dictionary, card: CardInst, cell: Vector2i, blocked_road: int = -1
) -> Dictionary:
	var res := {"ok": false, "reason": "", "action": "place", "level": card.level}
	var def: GameDb.CardDef = db.cards[card.id]
	if not board.in_bounds(cell) or not board.is_land(cell):
		res["reason"] = "วางในทะเลไม่ได้"
		return res
	var kind := board.kind_at(cell)
	if kind == Board.Kind.CAMP:
		res["reason"] = "วางที่ค่ายไม่ได้"
		return res
	var existing: CardInst = placed.get(cell)
	if card.id == "clear":
		res["action"] = "clear"
		res["ok"] = existing != null
		if not res["ok"]:
			res["reason"] = "ไม่มีการ์ดให้รื้อ"
		return res
	if existing != null:
		if existing.id != card.id:
			res["reason"] = "ช่องนี้มีการ์ดอื่นอยู่"
		elif existing.level != card.level:
			res["reason"] = "ต้อง level เท่ากันถึง merge ได้"
		elif existing.level >= 3:
			res["reason"] = "level สูงสุดแล้ว"
		elif def.is_encounter() and board.index_of(cell) == blocked_road:
			res["reason"] = "ฮีโร่ยืนอยู่ช่องนี้"
		else:
			res["ok"] = true
			res["action"] = "merge"
			res["level"] = existing.level + 1
		return res
	if def.is_encounter() and board.index_of(cell) == blocked_road:
		res["reason"] = "ฮีโร่ยืนอยู่ช่องนี้"
		return res
	var why := _placement_reason(db, board, placed, def, cell, kind)
	res["ok"] = why == ""
	res["reason"] = why
	return res


static func _placement_reason(
	db: GameDb, board: Board, placed: Dictionary, def: GameDb.CardDef, cell: Vector2i, kind: int
) -> String:
	match def.placement:
		"road":
			return "" if kind == Board.Kind.ROAD else "วางบนช่องทางเท่านั้น"
		"roadside":
			return "" if kind == Board.Kind.ROADSIDE else "วางข้างทางเท่านั้น"
		"roadside_or_open":
			return "" if kind == Board.Kind.ROADSIDE or kind == Board.Kind.OPEN else "วางข้างทางหรือที่โล่ง"
		"roadside_or_next_to_building":
			if kind == Board.Kind.ROADSIDE:
				return ""
			if kind == Board.Kind.OPEN and _next_to_building(db, board, placed, cell):
				return ""
			return "วางข้างทางหรือติดอาคาร"
		"next_to_building":
			if (kind == Board.Kind.ROADSIDE or kind == Board.Kind.OPEN) and _next_to_building(db, board, placed, cell):
				return ""
			return "ต้องวางติดอาคาร"
	return "วางไม่ได้"


## Buildings join a town when they touch in 4 directions (03-town.md), so "next to a
## building" uses the same 4 directions.
static func _next_to_building(db: GameDb, board: Board, placed: Dictionary, cell: Vector2i) -> bool:
	for n in board.neighbors4(cell):
		var c: CardInst = placed.get(n)
		if c != null and db.cards[c.id].type == "building":
			return true
	return false


## Every combo currently formed: [{id, a: cell, b: cell}]. `b` is the cell the effect lands on.
static func active_combos(db: GameDb, board: Board, placed: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for combo: GameDb.ComboDef in db.combos.values():
		for cell: Vector2i in placed:
			if (placed[cell] as CardInst).id != combo.a:
				continue
			for n in board.neighbors8(cell):
				var other: CardInst = placed.get(n)
				if other != null and other.id == combo.b:
					out.append({"id": combo.id, "a": cell, "b": n})
	return out


## cell -> {combo_id: true} for the cell each combo's effect lands on.
static func combo_flags(db: GameDb, board: Board, placed: Dictionary) -> Dictionary:
	var flags := {}
	for c in active_combos(db, board, placed):
		var cell: Vector2i = c["b"]
		if not flags.has(cell):
			flags[cell] = {}
		flags[cell][c["id"]] = true
	return flags


## Combos that `placed_after` has and `placed_before` does not, as [{id, a, b}].
static func new_combos(db: GameDb, board: Board, placed_before: Dictionary, placed_after: Dictionary) -> Array[Dictionary]:
	var had := {}
	for c in active_combos(db, board, placed_before):
		had["%s|%s|%s" % [c["id"], c["a"], c["b"]]] = true
	var out: Array[Dictionary] = []
	for c in active_combos(db, board, placed_after):
		if not had.has("%s|%s|%s" % [c["id"], c["a"], c["b"]]):
			out.append(c)
	return out


## +X% from adjacent shrines for terrain on `cell` (02-cards.md). The strongest shrine wins.
static func terrain_factor(db: GameDb, board: Board, placed: Dictionary, cell: Vector2i) -> float:
	var best := 0.0
	for n in board.neighbors8(cell):
		var c: CardInst = placed.get(n)
		if c != null and c.id == "shrine":
			best = maxf(best, db.cards["shrine"].level_params(c.level)["value"])
	return 1.0 + best


## Hero stat bonuses from terrain cards. Keys match Hero.mods.
static func terrain_mods(db: GameDb, board: Board, placed: Dictionary) -> Dictionary:
	var mods := {}
	for cell: Vector2i in placed:
		var card: CardInst = placed[cell]
		var def: GameDb.CardDef = db.cards[card.id]
		if def.type != "terrain":
			continue
		var v: float = def.level_params(card.level)["value"] * terrain_factor(db, board, placed, cell)
		match card.id:
			"rock":
				mods["max_hp"] = float(mods.get("max_hp", 0.0)) + v
			"grove":
				mods["attack_speed"] = float(mods.get("attack_speed", 0.0)) + v
			"spring":
				mods["mana_regen"] = float(mods.get("mana_regen", 0.0)) + v
	return mods


## HP the card on `cell` gives when the hero walks onto an adjacent road cell.
static func pass_heal(
	db: GameDb, board: Board, placed: Dictionary, flags: Dictionary, cell: Vector2i, max_hp: float
) -> float:
	var card: CardInst = placed.get(cell)
	if card == null:
		return 0.0
	var f: Dictionary = flags.get(cell, {})
	var p := (db.cards[card.id] as GameDb.CardDef).level_params(card.level)
	match card.id:
		"meadow":
			return p["value"] * terrain_factor(db, board, placed, cell)
		"house":
			return 0.0 if f.has("haunted_village") else float(p["value"])
		"spring":
			if f.has("hot_spring"):
				return db.combos["hot_spring"].value * max_hp
	return 0.0


## How many buildings the card on `cell` counts as for the town (03-town.md).
static func building_count(db: GameDb, placed: Dictionary, flags: Dictionary, cell: Vector2i) -> int:
	var card: CardInst = placed.get(cell)
	if card == null:
		return 0
	var def: GameDb.CardDef = db.cards[card.id]
	if def.type != "building":
		return 0
	var f: Dictionary = flags.get(cell, {})
	if f.has("haunted_village"):
		return 0
	var n: int = def.level_params(card.level)["count"]
	if f.has("garden"):
		n += int(db.combos["garden"].value)
	return n


## Enemy group an encounter card on `cell` spawns: {enemy, count, elite, xp_mult, level}.
static func encounter_params(db: GameDb, placed: Dictionary, flags: Dictionary, cell: Vector2i) -> Dictionary:
	var card: CardInst = placed[cell]
	var def: GameDb.CardDef = db.cards[card.id]
	var p := def.level_params(card.level)
	var xp_mult := 1.0
	if card.level == 2:
		xp_mult = db.c("enc_xp_l2")
	elif card.level >= 3:
		xp_mult = db.c("enc_xp_l3")
	var count: int = p["count"]
	var f: Dictionary = flags.get(cell, {})
	if f.has("deep_forest"):
		var combo: GameDb.ComboDef = db.combos["deep_forest"]
		count += int(combo.value)
		xp_mult *= combo.value2
	return {"enemy": def.enemy_id, "count": count, "elite": int(p["elite"]), "xp_mult": xp_mult, "level": card.level}

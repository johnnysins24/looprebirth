class_name Bot
extends RefCounted
## A simple player for tests and the balance sweep: spends stat points on a build, takes
## cards, and plays them with a few sensible rules. Not meant to be good, just legal and
## consistent.

var run: RunState
var build := "str"  ## str | agi | int | mix
var rng := RandomNumberGenerator.new()
var _mix := 0


func _init(p_run: RunState, p_build: String = "str", p_seed: int = 1) -> void:
	run = p_run
	build = p_build
	rng.seed = p_seed


## Makes every pending decision once. Call it a few times per game second.
func act() -> void:
	_spend_points()
	_take_offers()
	_take_other_notices()
	_play_cards()


func _spend_points() -> void:
	while run.hero.unspent > 0:
		var stat := build
		if build == "mix":
			stat = Hero.STATS[_mix % 3]
			_mix += 1
		if not run.spend_point(stat):
			return


func _take_offers() -> void:
	for n in run.notices.duplicate():
		if n.kind != "lap_card":
			continue
		var offers: Array = n.payload["offers"]
		var best := 0
		var best_score := -1.0
		for i in offers.size():
			var s := _score(offers[i])
			if s > best_score:
				best_score = s
				best = i
		run.choose_offer(n, best)


const PERK_ORDER := ["training_yard", "school", "market", "field_hospital", "guard_post", "carpenter", "library", "bell_tower", "shop"]


## Skill cards, items, shop wares, town perks and events.
func _take_other_notices() -> void:
	for n in run.notices.duplicate():
		match n.kind:
			"skill_card":
				var offers: Array = n.payload["offers"]
				var pick := rng.randi() % offers.size()
				for i in offers.size():
					for s in run.hero.skills:
						if not s.is_empty() and s["id"] == offers[i].id:
							pick = i
				run.choose_skill_offer(n, pick)
			"item":
				var item: Item = n.payload["item"]
				if item.better_than(run.equipment.get(item.slot)):
					run.equip_item(n)
				else:
					run.discard_item(n)
			"shop":
				var best := 0
				var wares: Array = n.payload["items"]
				for i in wares.size():
					if (wares[i] as Item).rarity > (wares[best] as Item).rarity:
						best = i
				run.buy_ware(n, best)
			"town_perk":
				var options: Array = n.payload["options"]
				var best := 0
				for i in options.size():
					if PERK_ORDER.find(options[i]) < PERK_ORDER.find(options[best]):
						best = i
				run.choose_perk(n, best)
			"event":
				_event(n)


func _event(n: Notice) -> void:
	var hp := run.hero.hp / run.hero.max_hp
	var option := 1
	var extra := {}
	match n.payload["event"]:
		"shrine":
			option = 0 if hp >= 0.6 else 1
		"merchant":
			var idx: Array[int] = []
			for i in run.hand.size():
				if not run.hand[i].skill and idx.size() < 2:
					idx.append(i)
			if idx.size() == 2 and run.hand.size() >= 6:
				option = 0
				extra = {"cards": idx}
		"traveler":
			option = 0 if hp >= 0.7 else 1
		"fountain":
			option = 0 if hp >= 0.5 else 1
		"deserter":
			option = 0 if hp >= 0.85 else 1
	run.resolve_event(n, option, extra)


## Prefer cards that merge with something already out, then fighting and healing cards.
func _score(card: CardInst) -> float:
	var s := rng.randf()
	for cell: Vector2i in run.placed:
		if run.placed[cell].id == card.id:
			s += 2.0
	var type: String = run.db.cards[card.id].type
	if type == "encounter":
		s += 1.0
	elif card.id == "house" or card.id == "meadow":
		s += 0.5
	return s


func _play_cards() -> void:
	var i := 0
	while i < run.hand.size():
		if _try_play(i):
			i = 0  # hand shifted
		else:
			i += 1


func _try_play(hand_index: int) -> bool:
	var card := run.hand[hand_index]
	if card.skill:
		return _try_skill(hand_index)
	var cells: Array[Vector2i] = []
	# merging first
	for cell: Vector2i in run.placed:
		if run.placed[cell].id == card.id and run.check_place(hand_index, cell)["ok"]:
			return run.play_card(hand_index, cell)
	var def: GameDb.CardDef = run.db.cards[card.id]
	if def.is_encounter():
		cells.assign(run.board.path.slice(1))
	else:
		cells.assign(run.board.roadside_cells())
		if card.id == "house":
			# stack buildings next to each other to grow a town
			var near: Array[Vector2i] = []
			for c in cells:
				for n in run.board.neighbors4(c):
					if run.placed.has(n) and run.db.cards[run.placed[n].id].type == "building":
						near.append(c)
						break
			if not near.is_empty():
				cells = near
	# shuffle, then take the first legal cell
	for k in range(cells.size() - 1, 0, -1):
		var j := rng.randi() % (k + 1)
		var tmp := cells[k]
		cells[k] = cells[j]
		cells[j] = tmp
	for c in cells:
		if run.placed.has(c):
			continue
		if run.check_place(hand_index, c)["ok"]:
			return run.play_card(hand_index, c)
	return false


## Merge a skill card into the slot that holds it, fill an empty slot, or swap in a higher level.
func _try_skill(hand_index: int) -> bool:
	var card := run.hand[hand_index]
	var slots := run.skill_slots()
	for slot in slots:
		var res := run.check_skill_card(card, slot)
		if res["ok"] and res["action"] == "merge":
			return run.play_skill_card(hand_index, slot)
	for slot in slots:
		var res := run.check_skill_card(card, slot)
		if res["ok"] and res["action"] == "equip":
			return run.play_skill_card(hand_index, slot)
	for slot in slots:
		var res := run.check_skill_card(card, slot)
		if res["ok"] and res["action"] == "swap" and card.level > int(run.hero.skills[slot]["level"]):
			return run.play_skill_card(hand_index, slot)
	return false

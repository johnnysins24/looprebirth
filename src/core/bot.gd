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

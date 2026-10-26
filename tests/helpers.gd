extends RefCounted
## Shared helpers for the run tests (not a suite: the runner only loads test_*.gd).


static func new_run(seed_value: int = 1, meta: Meta = null) -> RunState:
	var run := RunState.new(GameDb.load_default(), seed_value, meta)
	run.spawns.clear()  # nothing interrupts a test that only checks rules
	return run


## Puts `card` into the hand and plays it on `cell`. Returns whether it worked.
static func play(run: RunState, card: CardInst, cell: Vector2i) -> bool:
	run.hand.append(card)
	var ok := run.play_card(run.hand.size() - 1, cell)
	if not ok:
		run.hand.pop_back()
	return ok


## Grows a connected cluster of `count` houses (level `level`) and returns their cells.
static func grow_houses(run: RunState, count: int, level: int = 1, start: Vector2i = Vector2i(-1, -1)) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if start.x < 0:
		start = first_roadside(run, [])
	while cells.size() < count:
		var cand: Array[Vector2i] = []
		if cells.is_empty():
			cand.append(start)
		else:
			for c in cells:
				for n in run.board.neighbors4(c):
					if not cells.has(n) and not run.placed.has(n) and not cand.has(n):
						cand.append(n)
			cand.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
		var done := false
		for c in cand:
			if play(run, CardInst.make("house", level), c):
				cells.append(c)
				done = true
				break
		if not done:
			break
	return cells


## First roadside cell (reading order) at least 3 cells away from the camp and from every cell in `avoid`.
static func first_roadside(run: RunState, avoid: Array) -> Vector2i:
	var all := run.board.roadside_cells()
	all.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for c in all:
		var camp := run.board.camp()
		if run.placed.has(c) or maxi(absi(camp.x - c.x), absi(camp.y - c.y)) < 3:
			continue
		var far := true
		for a: Vector2i in avoid:
			if maxi(absi(a.x - c.x), absi(a.y - c.y)) < 3:
				far = false
		if far:
			return c
	return Vector2i(-1, -1)


static func notices_of(run: RunState, kind: String) -> Array[Notice]:
	var out: Array[Notice] = []
	for n in run.notices:
		if n.kind == kind:
			out.append(n)
	return out


## Gives the run a perk for `tier` without going through the notice (enough town to be active).
static func give_perk(run: RunState, tier: int, id: String) -> void:
	run.perk_for_tier[tier] = id


static func finish_lap(run: RunState) -> void:
	run.spawns.clear()
	run.tile_index = run.board.path.size() - 1
	run.tile_progress = 0.99
	run.advance(0.2)

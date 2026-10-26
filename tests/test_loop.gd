extends RefCounted
## Loop generator: every seed must give a valid closed loop (docs/design/01-run.md).

const SEEDS := 300


func test_every_seed_is_valid(t) -> void:
	var db := GameDb.load_default()
	var lengths := {}
	var distinct := {}
	for s in SEEDS:
		var b := LoopGenerator.generate(db, s)
		var n := b.path.size()
		lengths[n] = int(lengths.get(n, 0)) + 1
		t.ok(n >= 28 and n <= 36, "seed %d: length %d" % [s, n])
		t.ok(LoopGenerator.path_ok(db, b.path, b.cols, b.rows), "seed %d violates the loop rules" % s)
		# closed: consecutive cells (and last -> first) are 4-neighbours
		for i in n:
			var d := b.path[(i + 1) % n] - b.path[i]
			t.eq(absi(d.x) + absi(d.y), 1, "seed %d: gap at %d" % [s, i])
		# camp rule
		var c := b.camp()
		t.ok(mini(mini(c.x, b.cols - 1 - c.x), mini(c.y, b.rows - 1 - c.y)) >= 2, "seed %d: camp too close to the edge" % s)
		# no duplicate cells
		var uniq := {}
		for p in b.path:
			uniq[p] = true
		t.eq(uniq.size(), n, "seed %d: repeated cell" % s)
		var sig := str(b.path.slice(0, 6)) + str(n)
		distinct[sig] = true
	t.ok(distinct.size() > SEEDS / 2, "loops should vary; only %d distinct of %d" % [distinct.size(), SEEDS])
	t.ok(lengths.size() >= 3, "lengths should vary: %s" % str(lengths))


func test_same_seed_same_loop(t) -> void:
	var db := GameDb.load_default()
	var a := LoopGenerator.generate(db, 12345)
	var b := LoopGenerator.generate(db, 12345)
	t.eq(a.path, b.path)
	var c := LoopGenerator.generate(db, 12346)
	t.ok(a.path != c.path, "different seeds should differ")


func test_walks_clockwise(t) -> void:
	var db := GameDb.load_default()
	for s in 30:
		var b := LoopGenerator.generate(db, s)
		var sum := 0
		for i in b.path.size():
			var p := b.path[i]
			var q := b.path[(i + 1) % b.path.size()]
			sum += p.x * q.y - q.x * p.y
		t.ok(sum > 0, "seed %d is not clockwise on screen" % s)


func test_board_kinds(t) -> void:
	var db := GameDb.load_default()
	var b := LoopGenerator.generate(db, 7)
	t.eq(b.kind_at(b.camp()), Board.Kind.CAMP)
	t.ok(b.roadside_cells().size() >= 40)
	for c in b.roadside_cells():
		t.ok(not b.is_road(c))
		t.ok(not b.adjacent_road_indices(c).is_empty())

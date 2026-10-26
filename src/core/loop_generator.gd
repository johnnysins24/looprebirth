class_name LoopGenerator
extends RefCounted
## Builds the loop for a run from a seed (docs/design/01-run.md "ตัวสร้าง loop").
##
## Idea: the loop is the outline of a blob of unit squares. Start from a rectangle blob,
## then randomly add or remove small rectangles of squares (the "pushes"). A push that
## breaks a rule is rolled back, so the loop is valid after every step. Road cells are the
## lattice points on the blob's outline. Each seed first rolls a target length so loops
## range from compact (28) to winding (36) instead of always filling up to the maximum.
##
## Rules checked after every push:
## - the outline is one simple closed curve (no holes, no pinch points)
## - 28..36 road cells
## - non-consecutive road cells are never next to each other in 4 directions
## - every road cell has a free roadside cell, and the map has at least 40 of them
## - the loop stays two cells away from the board edge (the outer ring is always sea)
## The camp is then picked among road cells at least 2 cells from the edge.

const ATTEMPTS := 40
const START_W := Vector2i(9, 14)  # range of the start rectangle's width, in road cells
const START_H := Vector2i(5, 8)
const EDGE_MARGIN := 2  # road cells keep this far from the board edge


static func generate(db: GameDb, seed_value: int) -> Board:
	var cols := db.ci("board_cols")
	var rows := db.ci("board_rows")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for attempt in ATTEMPTS:
		var target := 2 * rng.randi_range(db.ci("loop_len_min") / 2, db.ci("loop_len_max") / 2)
		var dims := _pick_start(db, rng, target)
		var squares := _blob(dims.x, dims.y, cols, rows)
		var pushes := rng.randi_range(db.ci("loop_push_min"), db.ci("loop_push_max"))
		for k in pushes:
			var cand := _push(squares, rng)
			if cand.is_empty():
				continue
			var outline := outline_of(cand)
			if not outline.is_empty() and outline.size() <= target and path_ok(db, outline, cols, rows):
				squares = cand
		var path := outline_of(squares)
		var camp := _pick_camp(db, path, cols, rows, rng)
		if not path.is_empty() and camp >= 0 and path_ok(db, path, cols, rows):
			return Board.new(cols, rows, _rotate(path, camp), seed_value)
	# Cannot happen with the shipped numbers (the plain rectangle is always valid), but a
	# broken constants.csv must not hang the game.
	var rect := outline_of(_blob(db.ci("loop_start_w"), db.ci("loop_start_h"), cols, rows))
	return Board.new(cols, rows, _rotate(rect, maxi(0, _pick_camp(db, rect, cols, rows, rng))), seed_value)


## Random start rectangle (in road cells) whose outline is at most `target` long.
static func _pick_start(db: GameDb, rng: RandomNumberGenerator, target: int) -> Vector2i:
	var options: Array[Vector2i] = []
	for w in range(START_W.x, START_W.y + 1):
		for h in range(START_H.x, START_H.y + 1):
			var perimeter := 2 * (w - 1 + h - 1)
			if perimeter >= db.ci("loop_len_min") and perimeter <= target:
				options.append(Vector2i(w, h))
	return options[rng.randi() % options.size()]


## Squares of a rectangle that is w x h road cells, centred on the board.
static func _blob(w: int, h: int, cols: int, rows: int) -> Dictionary:
	var ox := (cols - w) / 2
	var oy := (rows - h) / 2
	var squares := {}
	for i in w - 1:
		for j in h - 1:
			squares[Vector2i(ox + i, oy + j)] = true
	return squares


## Adds or removes a random rectangle of squares on the blob's border. Returns an empty
## dictionary when the random pick was not applicable.
static func _push(squares: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var border: Array[Vector2i] = []
	for s: Vector2i in squares:
		for d in Board.DIRS4:
			if not squares.has(s + d):
				border.append(s)
				break
	if border.is_empty():
		return {}
	var w := _rect_len(rng)
	var h := _rect_len(rng)
	var add := rng.randf() < 0.5
	var anchor: Vector2i = border[rng.randi() % border.size()]
	if add:
		var outs: Array[Vector2i] = []
		for d in Board.DIRS4:
			if not squares.has(anchor + d):
				outs.append(anchor + d)
		anchor = outs[rng.randi() % outs.size()]
	var rx := anchor.x - rng.randi_range(0, w - 1)
	var ry := anchor.y - rng.randi_range(0, h - 1)
	var out := squares.duplicate()
	for i in w:
		for j in h:
			var s := Vector2i(rx + i, ry + j)
			if add:
				if squares.has(s):
					return {}
				out[s] = true
			else:
				if not squares.has(s):
					return {}
				out.erase(s)
	return out


## Mostly small bumps and notches, sometimes a long strip that moves a whole side.
static func _rect_len(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(1, 3) if rng.randf() < 0.8 else rng.randi_range(4, 5)


## Road cells (lattice points) of the blob's outline, clockwise. Empty if the outline is
## not a single simple closed curve.
static func outline_of(squares: Dictionary) -> Array[Vector2i]:
	var adj := {}  # Vector2i -> Array[Vector2i]
	for s: Vector2i in squares:
		var x := s.x
		var y := s.y
		if not squares.has(Vector2i(x, y - 1)):
			_link(adj, Vector2i(x, y), Vector2i(x + 1, y))
		if not squares.has(Vector2i(x + 1, y)):
			_link(adj, Vector2i(x + 1, y), Vector2i(x + 1, y + 1))
		if not squares.has(Vector2i(x, y + 1)):
			_link(adj, Vector2i(x, y + 1), Vector2i(x + 1, y + 1))
		if not squares.has(Vector2i(x - 1, y)):
			_link(adj, Vector2i(x, y), Vector2i(x, y + 1))
	var out: Array[Vector2i] = []
	if adj.is_empty():
		return out
	for p: Vector2i in adj:
		if adj[p].size() != 2:
			return out  # pinch point
	var start: Vector2i = adj.keys()[0]
	var prev := Vector2i(-9999, -9999)
	var cur := start
	out.append(start)
	for guard in adj.size() + 1:
		var nbs: Array = adj[cur]
		var nxt: Vector2i = nbs[0] if nbs[0] != prev else nbs[1]
		if nxt == start:
			break
		out.append(nxt)
		prev = cur
		cur = nxt
	if out.size() != adj.size():
		out.clear()  # more than one closed curve (a hole or a split blob)
		return out
	if _signed_area(out) < 0:
		out.reverse()
	return out


static func _link(adj: Dictionary, a: Vector2i, b: Vector2i) -> void:
	if not adj.has(a):
		adj[a] = []
	if not adj.has(b):
		adj[b] = []
	adj[a].append(b)
	adj[b].append(a)


## Positive for clockwise on screen (y grows downward).
static func _signed_area(p: Array[Vector2i]) -> int:
	var sum := 0
	for i in p.size():
		var a := p[i]
		var b := p[(i + 1) % p.size()]
		sum += a.x * b.y - b.x * a.y
	return sum


static func path_ok(db: GameDb, path: Array[Vector2i], cols: int, rows: int) -> bool:
	var n := path.size()
	if n < db.ci("loop_len_min") or n > db.ci("loop_len_max"):
		return false
	var pos := {}
	for i in n:
		pos[path[i]] = i
	for c in path:
		if c.x < EDGE_MARGIN or c.y < EDGE_MARGIN or c.x > cols - 1 - EDGE_MARGIN or c.y > rows - 1 - EDGE_MARGIN:
			return false
	# no shortcuts: a road cell's only road neighbours (4 directions) are its two path neighbours
	for i in n:
		for d in Board.DIRS4:
			var nb: Vector2i = path[i] + d
			if pos.has(nb):
				var diff: int = (int(pos[nb]) - i + n) % n
				if diff != 1 and diff != n - 1:
					return false
	# roadside room for cards
	var side := {}
	for c in path:
		var free := 0
		for d in Board.DIRS8:
			var nb: Vector2i = c + d
			if nb.x >= 0 and nb.y >= 0 and nb.x < cols and nb.y < rows and not pos.has(nb):
				free += 1
				side[nb] = true
		if free == 0:
			return false
	return side.size() >= db.ci("loop_min_roadside")


## Index of a random road cell at least camp_edge_margin from the board edge, or -1.
static func _pick_camp(
	db: GameDb, path: Array[Vector2i], cols: int, rows: int, rng: RandomNumberGenerator
) -> int:
	var margin := db.ci("camp_edge_margin")
	var ok: Array[int] = []
	for i in path.size():
		var c := path[i]
		if mini(mini(c.x, cols - 1 - c.x), mini(c.y, rows - 1 - c.y)) >= margin:
			ok.append(i)
	if ok.is_empty():
		return -1
	return ok[rng.randi() % ok.size()]


static func _rotate(path: Array[Vector2i], start: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in path.size():
		out.append(path[(start + i) % path.size()])
	return out

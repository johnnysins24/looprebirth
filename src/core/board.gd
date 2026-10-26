class_name Board
extends RefCounted
## The map: a closed loop of road cells on a grid, plus what kind of ground every
## other cell is. Geometry only; cards and enemies live in RunState.

enum Kind { SEA, OPEN, ROADSIDE, ROAD, CAMP }

const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const DIRS8: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(1, -1),
]
## Land is the road, everything inside the loop, and cells within this Chebyshev distance of
## the road. The outer ring of the board is always sea. Everything else is sea.
const ISLAND_RADIUS := 3

var cols := 22
var rows := 13
var seed_value := 0
var path: Array[Vector2i] = []  ## clockwise; path[0] is the camp
var road_index: Dictionary = {}  # Vector2i -> int

var _kind: Dictionary = {}  # Vector2i -> Kind


func _init(p_cols: int, p_rows: int, p_path: Array[Vector2i], p_seed: int = 0) -> void:
	cols = p_cols
	rows = p_rows
	path = p_path
	seed_value = p_seed
	for i in path.size():
		road_index[path[i]] = i
	_classify()


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


func kind_at(c: Vector2i) -> int:
	return _kind.get(c, Kind.SEA)


func is_land(c: Vector2i) -> bool:
	return _kind.get(c, Kind.SEA) != Kind.SEA


func is_road(c: Vector2i) -> bool:
	return road_index.has(c)


func camp() -> Vector2i:
	return path[0]


## Road index of the cell, or -1.
func index_of(c: Vector2i) -> int:
	return road_index.get(c, -1)


func neighbors8(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS8:
		if in_bounds(c + d):
			out.append(c + d)
	return out


func neighbors4(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS4:
		if in_bounds(c + d):
			out.append(c + d)
	return out


## Road indices whose cell touches `c` (8 directions). A card on `c` acts on these.
func adjacent_road_indices(c: Vector2i) -> Array[int]:
	var out: Array[int] = []
	for n in neighbors8(c):
		if road_index.has(n):
			out.append(road_index[n])
	return out


## Cells next to the road that are free of road (8 directions).
func roadside_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in _kind:
		if _kind[c] == Kind.ROADSIDE:
			out.append(c)
	return out


func next_index(i: int) -> int:
	return (i + 1) % path.size()


func _classify() -> void:
	_kind.clear()
	for i in path.size():
		_kind[path[i]] = Kind.CAMP if i == 0 else Kind.ROAD
	# roadside: touches the road in any of 8 directions
	for c in path:
		for n in neighbors8(c):
			if not road_index.has(n):
				_kind[n] = Kind.ROADSIDE
	# enclosed cells (not reachable from the edge without crossing the road) are ground
	var outside := {}
	var stack: Array[Vector2i] = []
	for x in cols:
		for y in rows:
			if x == 0 or y == 0 or x == cols - 1 or y == rows - 1:
				var e := Vector2i(x, y)
				if not road_index.has(e):
					outside[e] = true
					stack.append(e)
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		for n in neighbors4(cur):
			if not road_index.has(n) and not outside.has(n):
				outside[n] = true
				stack.append(n)
	for x in cols:
		for y in rows:
			var c := Vector2i(x, y)
			if _kind.has(c) or x == 0 or y == 0 or x == cols - 1 or y == rows - 1:
				continue
			var near := false
			for p in path:
				if maxi(absi(p.x - x), absi(p.y - y)) <= ISLAND_RADIUS:
					near = true
					break
			if near or not outside.has(c):
				_kind[c] = Kind.OPEN

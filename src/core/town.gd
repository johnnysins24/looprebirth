class_name Town
extends RefCounted
## The town of a run (docs/design/03-town.md): the largest group of buildings that touch in
## 4 directions. Only that one group counts, so scattering villages earns nothing.

const NAMES := ["ยังไม่เป็นเมือง", "หมู่บ้าน", "เมือง"]

var cells: Array[Vector2i] = []  ## building cells of the largest group
var count := 0  ## buildings the group counts as (a L3 house is 3)
var tier := 0

var _set: Dictionary = {}


static func tier_for(db: GameDb, count: int) -> int:
	if count >= db.ci("town_tier2"):
		return 2
	if count >= db.ci("town_tier1"):
		return 1
	return 0


static func compute(db: GameDb, board: Board, placed: Dictionary, flags: Dictionary) -> Town:
	var t := Town.new()
	var seen := {}
	var best_count := -1
	for start: Vector2i in _sorted_cells(placed):
		if seen.has(start) or db.cards[placed[start].id].type != "building":
			continue
		var group: Array[Vector2i] = []
		var stack: Array[Vector2i] = [start]
		seen[start] = true
		var total := 0
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			group.append(c)
			total += CardRules.building_count(db, placed, flags, c)
			for n in board.neighbors4(c):
				var other: CardInst = placed.get(n)
				if other != null and not seen.has(n) and db.cards[other.id].type == "building":
					seen[n] = true
					stack.append(n)
		# ties go to the bigger footprint, then to the first group in reading order
		if total > best_count or (total == best_count and group.size() > t.cells.size()):
			best_count = total
			t.cells = group
			t.count = total
	t.tier = tier_for(db, t.count)
	for c in t.cells:
		t._set[c] = true
	return t


static func _sorted_cells(placed: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in placed:
		out.append(c)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


func has_cell(c: Vector2i) -> bool:
	return _set.has(c)


## True when `c` touches a town cell in any of 8 directions (a road cell "next to the town").
func touches(c: Vector2i) -> bool:
	for d in Board.DIRS8:
		if _set.has(c + d):
			return true
	return false


## True when `c` is within `dist` cells (Chebyshev) of the town.
func within(c: Vector2i, dist: int) -> bool:
	for t: Vector2i in cells:
		if maxi(absi(t.x - c.x), absi(t.y - c.y)) <= dist:
			return true
	return false


func tier_name() -> String:
	return NAMES[clampi(tier, 0, NAMES.size() - 1)]

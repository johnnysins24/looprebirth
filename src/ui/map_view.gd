class_name MapView
extends Control
## The board: land, road, cards on the map, enemy groups, the hero, and the highlights
## shown while a card is being placed. Draw order follows docs/dev/art-contract.md:
## ground, road, markers, y-sorted objects and units, overlays.

const CELL := 16

var run: RunState
var game: Game  ## for the held card and hover state

var _valid: Dictionary = {}  # Vector2i -> check result, for the held card
var _valid_key := ""
var _floaters: Array[Dictionary] = []
var _t := 0.0
var _town_key := ""
var _town_tiles: Array[Vector3i] = []  # (i, j, dual-grid index) of the town overlay tiles


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS


func setup(p_run: RunState, p_game: Game) -> void:
	run = p_run
	game = p_game
	_floaters.clear()
	_valid_key = ""
	_town_key = ""
	run.healed.connect(_on_healed)
	run.combo_formed.connect(_on_combo)


func hover_cell() -> Vector2i:
	var p := get_local_mouse_position()
	if p.x < 0 or p.y < 0 or p.x >= size.x or p.y >= size.y:
		return Vector2i(-1, -1)
	return Vector2i(int(p.x) / CELL, int(p.y) / CELL)


func cell_to_px(c: Vector2) -> Vector2:
	return c * CELL


func _process(delta: float) -> void:
	_t += delta
	for f in _floaters:
		f["age"] += delta
	_floaters = _floaters.filter(func(f): return f["age"] < 1.2)
	queue_redraw()


func _on_healed(amount: float, source: Vector2i) -> void:
	var at := run.hero_cell_pos() * CELL + Vector2(8, -2) if source.x < 0 else Vector2(source) * CELL + Vector2(8, 0)
	_floaters.append({"text": "+%d" % maxi(1, roundi(amount)), "color": UiTheme.GOOD, "pos": at, "age": 0.0})


func _on_combo(combo: GameDb.ComboDef, cell: Vector2i) -> void:
	var neg := combo.id == "haunted_village"
	_floaters.append({"text": combo.name_th, "color": UiTheme.BAD if neg else UiTheme.GOLD, "pos": Vector2(cell) * CELL + Vector2(8, -6), "age": 0.0})


## Cells where the held card could be played, recomputed only when something changed.
func _refresh_valid() -> void:
	var key := "%d|%d|%d|%d" % [game.held, run.placed.size(), run.hand.size(), run.tile_index]
	if key == _valid_key:
		return
	_valid_key = key
	_valid.clear()
	if game.held < 0 or game.held >= run.hand.size():
		return
	var card := run.hand[game.held]
	for x in run.board.cols:
		for y in run.board.rows:
			var c := Vector2i(x, y)
			if run.board.is_land(c):
				var res := run.check_card(card, c)
				if res["ok"]:
					_valid[c] = res


func _draw() -> void:
	if run == null:
		return
	var board := run.board
	var bg := Art.background()
	draw_rect(Rect2(Vector2.ZERO, size), Art.color(bg["bg"]))
	if not Art.land_has_water():
		_draw_sea_pattern()
	_draw_land(board)
	_draw_road(board)
	_refresh_town()
	_draw_town_ground()
	_refresh_valid()
	_draw_valid_cells()
	_draw_sorted(board)
	_draw_town_label()
	_draw_hover(board)
	_draw_floaters()


func _draw_sea_pattern() -> void:
	var bg := Art.background()
	var c: Color = Art.color(bg["bg"]).lightened(0.12)
	for i in 14:
		var x := fposmod(i * 53 + floorf(_t * 6.0) * 0.0, size.x)
		var y := fposmod(i * 37, size.y)
		draw_rect(Rect2(floorf(x), floorf(y), 3, 1), c)


func _draw_land(board: Board) -> void:
	for i in range(board.cols + 1):
		for j in range(board.rows + 1):
			var idx := 0
			if board.is_land(Vector2i(i - 1, j - 1)):
				idx |= 1
			if board.is_land(Vector2i(i, j - 1)):
				idx |= 2
			if board.is_land(Vector2i(i - 1, j)):
				idx |= 4
			if board.is_land(Vector2i(i, j)):
				idx |= 8
			# the real atlas paints the water too (tile 0); the placeholder leaves the background showing
			if idx != 0 or Art.land_has_water():
				Art.draw_land(self, Vector2(i * CELL - CELL / 2, j * CELL - CELL / 2), idx, Vector2i(i, j))


func _draw_road(board: Board) -> void:
	var n := board.path.size()
	for k in n:
		var c := board.path[k]
		var prev := board.path[(k - 1 + n) % n]
		var nxt := board.path[(k + 1) % n]
		var mask := 0
		for nb in [prev, nxt]:
			var d: Vector2i = nb - c
			if d == Vector2i(0, -1):
				mask |= 1
			elif d == Vector2i(1, 0):
				mask |= 2
			elif d == Vector2i(0, 1):
				mask |= 4
			elif d == Vector2i(-1, 0):
				mask |= 8
		Art.draw_road(self, Vector2(c) * CELL, mask)
	Art.draw_camp(self, Vector2(board.camp()) * CELL)


# --- town --------------------------------------------------------------------------------------


## Dual-grid overlay tiles for the town (the largest building group), rebuilt when it changes.
func _refresh_town() -> void:
	var t := run.town
	var key := "%d|%s" % [t.tier, str(t.cells)]
	if key == _town_key:
		return
	_town_key = key
	_town_tiles.clear()
	if t.tier <= 0:
		return
	for i in range(run.board.cols + 1):
		for j in range(run.board.rows + 1):
			var idx := 0
			if t.has_cell(Vector2i(i - 1, j - 1)):
				idx |= 1
			if t.has_cell(Vector2i(i, j - 1)):
				idx |= 2
			if t.has_cell(Vector2i(i - 1, j)):
				idx |= 4
			if t.has_cell(Vector2i(i, j)):
				idx |= 8
			if idx != 0:
				_town_tiles.append(Vector3i(i, j, idx))


## Cobblestones under a tier-2 town. Without the art sheets a tint and an outline stand in.
func _draw_town_ground() -> void:
	if run.town.tier < 2:
		return
	if Art.town_art():
		for tile in _town_tiles:
			Art.draw_town_tile(self, "town_ground", Vector2(tile.x * CELL - CELL / 2, tile.y * CELL - CELL / 2), tile.z)
	else:
		for c in run.town.cells:
			draw_rect(Rect2(Vector2(c) * CELL, Vector2(CELL, CELL)), Color(0.75, 0.75, 0.8, 0.35))


func _draw_town_edge(layer: String, tile: Vector3i) -> void:
	Art.draw_town_tile(self, layer, Vector2(tile.x * CELL - CELL / 2, tile.y * CELL - CELL / 2), tile.z)


## Without the art sheets: a fence (tier 1) or wall (tier 2) line on the border of the group.
func _draw_town_outline() -> void:
	var col := Art.color("dark_brown") if run.town.tier < 2 else Art.color("silver")
	var w := 1.0 if run.town.tier < 2 else 2.0
	for c in run.town.cells:
		var p := Vector2(c) * CELL
		if not run.town.has_cell(c + Vector2i(0, -1)):
			draw_line(p, p + Vector2(CELL, 0), col, w)
		if not run.town.has_cell(c + Vector2i(0, 1)):
			draw_line(p + Vector2(0, CELL), p + Vector2(CELL, CELL), col, w)
		if not run.town.has_cell(c + Vector2i(-1, 0)):
			draw_line(p, p + Vector2(0, CELL), col, w)
		if not run.town.has_cell(c + Vector2i(1, 0)):
			draw_line(p + Vector2(CELL, 0), p + Vector2(CELL, CELL), col, w)


func _draw_town_label() -> void:
	var t := run.town
	if t.tier <= 0:
		return
	var top := 99
	var left := 99
	var right := -1
	for c in t.cells:
		top = mini(top, c.y)
		left = mini(left, c.x)
		right = maxi(right, c.x)
	var label := "%s %d" % [t.tier_name(), t.count]
	var w := UiTheme.text_width(label, UiTheme.FS_SMALL, true) + 6.0
	var cx := (left + right + 1) * CELL / 2.0
	var y := maxf(0.0, top * CELL - 9.0)
	var x := clampf(cx - w / 2.0, 0.0, size.x - w)
	draw_rect(Rect2(x, y, w, 9), Color(UiTheme.BG, 0.8))
	UiTheme.text(self, x + 3, y - 0.5, label, UiTheme.FS_SMALL, UiTheme.PERK_COL, true)


func _draw_valid_cells() -> void:
	if _valid.is_empty():
		return
	var pulse := 0.18 + 0.08 * sin(_t * 6.0)
	for c: Vector2i in _valid:
		var res: Dictionary = _valid[c]
		var col := UiTheme.GOLD if res["action"] == "merge" else UiTheme.GOOD
		draw_rect(Rect2(Vector2(c) * CELL, Vector2(CELL, CELL)), Color(col, pulse))


## Everything that stands on the map, sorted by the y of its feet so taller things overlap
## correctly.
func _draw_sorted(board: Board) -> void:
	var items: Array[Dictionary] = []
	for c: Vector2i in run.placed:
		items.append({"y": c.y * CELL + CELL, "fn": _draw_card_object.bind(c)})
	for i in run.spawns:
		var sp: RunState.Spawn = run.spawns[i]
		if sp.source == "wild" or sp.source == "boss" or sp.source == "raid":
			var cell := board.path[sp.index]
			items.append({"y": cell.y * CELL + CELL, "fn": _draw_wild.bind(sp)})
	for i in run.event_cells:
		items.append({"y": board.path[i].y * CELL + CELL, "fn": _draw_event_marker.bind(i)})
	if run.town.tier > 0:
		if Art.town_art():
			var layer := "town_wall" if run.town.tier >= 2 else "town_fence"
			for tile in _town_tiles:
				items.append({"y": tile.y * CELL + 1, "fn": _draw_town_edge.bind(layer, tile)})
		else:
			items.append({"y": 0, "fn": _draw_town_outline})
	var hp := run.hero_cell_pos() * CELL
	items.append({"y": hp.y + CELL, "fn": _draw_hero.bind(hp)})
	items.sort_custom(func(a, b): return a["y"] < b["y"])
	for it in items:
		it["fn"].call()


func _draw_card_object(c: Vector2i) -> void:
	var card: CardInst = run.placed[c]
	var origin := Vector2(c) * CELL
	var mod := Color.WHITE
	var def := run.db.cards[card.id] as GameDb.CardDef
	var sp: RunState.Spawn = null
	if def.is_encounter():
		sp = run.spawns.get(run.board.index_of(c))
		if sp != null and not sp.alive:
			mod = Color(0.55, 0.55, 0.65, 0.8)  # cleared this lap, comes back at the next one
	var sprite := card.id
	if card.id == "house" and run.town.tier >= 2 and run.town.has_cell(c):
		sprite = "house_town"  # tiled roofs inside a tier-2 town
	Art.draw_object(self, sprite, origin, card.level, mod)
	# level pips (levels 2 and 3 only)
	if card.level > 1:
		for k in card.level:
			draw_rect(Rect2(origin + Vector2(1 + k * 3, 1), Vector2(2, 2)), UiTheme.GOLD)
	# flags of combos on this cell
	var f: Dictionary = run.flags.get(c, {})
	if f.has("haunted_village"):
		draw_rect(Rect2(origin + Vector2(CELL - 4, 1), Vector2(3, 3)), UiTheme.BAD)
	elif not f.is_empty():
		draw_rect(Rect2(origin + Vector2(CELL - 4, 1), Vector2(3, 3)), UiTheme.GOLD)
	if def.is_encounter() and sp != null and sp.alive:
		UiTheme.text(self, origin.x + 9, origin.y + 8, str(sp.count), UiTheme.FS_SMALL, UiTheme.TEXT, true)


func _draw_wild(sp: RunState.Spawn) -> void:
	if not sp.alive:
		return
	var origin := Vector2(run.board.path[sp.index]) * CELL
	Art.draw_unit_anim(self, sp.enemy_id, origin, "idle", _t + sp.index * 0.37)
	if sp.source == "wild" or sp.source == "raid":
		UiTheme.text(self, origin.x + 10, origin.y + 8, str(sp.count), UiTheme.FS_SMALL, UiTheme.WARN if sp.source == "raid" else UiTheme.TEXT, true)


func _draw_event_marker(i: int) -> void:
	var origin := Vector2(run.board.path[i]) * CELL
	Art.draw_frame(self, "map", "event", origin + Vector2(0, CELL - Art.OBJ_H), CELL, Art.OBJ_H, int(_t * 4.0) % 4, 0)


func _draw_hero(px: Vector2) -> void:
	var h := run.hero_heading()
	var dir := 0
	if h == Vector2i(-1, 0):
		dir = 1
	elif h == Vector2i(1, 0):
		dir = 2
	elif h == Vector2i(0, -1):
		dir = 3
	var walking := run.phase == RunState.Phase.WALKING
	Art.draw_unit_anim(self, "hero", px, "walk", _t if walking else 0.0, dir)
	var hero := run.hero
	if hero.hp < hero.max_hp or run.phase == RunState.Phase.FIGHTING:
		UiTheme.bar(self, Rect2(px + Vector2(2, -3), Vector2(12, 3)), hero.hp / hero.max_hp, UiTheme.HP_COL)


func _draw_hover(board: Board) -> void:
	var c := hover_cell()
	if c.x < 0:
		return
	var r := Rect2(Vector2(c) * CELL, Vector2(CELL, CELL))
	if game.held >= 0 and game.held < run.hand.size():
		var ok := _valid.has(c)
		draw_rect(r, UiTheme.GOLD if ok else UiTheme.BAD, false, 1.0)
		if ok:
			# preview combos that would form
			var res: Dictionary = _valid[c]
			for combo: GameDb.ComboDef in res["combos"]:
				var neg := combo.id == "haunted_village"
				for n in board.neighbors8(c):
					var other: CardInst = run.placed.get(n)
					if other != null and (other.id == combo.a or other.id == combo.b):
						draw_line(r.get_center(), Vector2(n) * CELL + Vector2(8, 8), UiTheme.BAD if neg else UiTheme.GOLD, 1.0)
	elif board.is_land(c):
		draw_rect(r, Color(1, 1, 1, 0.5), false, 1.0)


func _draw_floaters() -> void:
	for f in _floaters:
		var p: Vector2 = f["pos"] + Vector2(0, -12.0 * f["age"])
		var col: Color = f["color"]
		col.a = clampf(1.4 - f["age"], 0.0, 1.0)
		var w := UiTheme.text_width(f["text"], UiTheme.FS, true)
		UiTheme.text(self, p.x - w / 2.0, p.y, f["text"], UiTheme.FS, col, true)

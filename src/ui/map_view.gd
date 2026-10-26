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


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS


func setup(p_run: RunState, p_game: Game) -> void:
	run = p_run
	game = p_game
	_floaters.clear()
	_valid_key = ""
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
	_draw_sea_pattern()
	_draw_land(board)
	_draw_road(board)
	_refresh_valid()
	_draw_valid_cells()
	_draw_sorted(board)
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
			if idx != 0:
				Art.draw_land(self, Vector2(i * CELL - CELL / 2, j * CELL - CELL / 2), idx)


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
	Art.draw_frame(self, "tiles", "camp", Vector2(board.camp()) * CELL, CELL, CELL)


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
		if sp.source == "wild" or sp.source == "boss":
			var cell := board.path[sp.index]
			items.append({"y": cell.y * CELL + CELL, "fn": _draw_wild.bind(sp)})
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
	Art.draw_object(self, card.id, origin, card.level, mod)
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
	var frame := int(_t * 2.5) % 2
	Art.draw_unit(self, sp.enemy_id, origin, frame)
	if sp.source == "wild":
		UiTheme.text(self, origin.x + 10, origin.y + 8, str(sp.count), UiTheme.FS_SMALL, UiTheme.TEXT, true)


func _draw_hero(px: Vector2) -> void:
	var h := run.hero_heading()
	var row := 0
	if h == Vector2i(-1, 0):
		row = 1
	elif h == Vector2i(1, 0):
		row = 2
	elif h == Vector2i(0, -1):
		row = 3
	var frame := int(_t * 6.0) % 2 if run.phase == RunState.Phase.WALKING else 0
	Art.draw_unit(self, "hero", px, frame, row)
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

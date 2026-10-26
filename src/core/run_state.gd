class_name RunState
extends RefCounted
## One run from camp to boss: the whole game state and its rules, with no nodes in it.
##
## The view calls advance(dt) every frame (dt already multiplied by the game speed) and
## reads the public fields; the player's choices come back through the methods marked API.
## Time moves in fixed 0.05 s steps so a seed plays out identically at any speed.

signal notice_added(n: Notice)
signal notice_removed(n: Notice)
signal battle_started(b: Battle)
signal battle_ended(b: Battle)
signal lap_completed(lap: int)
signal leveled(level: int)
signal healed(amount: float, source: Vector2i)  ## source = card cell, or (-1,-1)
signal card_played(cell: Vector2i, card: CardInst, action: String)
signal combo_formed(combo: GameDb.ComboDef, cell: Vector2i)
signal hand_changed
signal toast(text: String)
signal ended(won: bool)

enum Phase { WALKING, FIGHTING, ENDED }

const STEP := 0.05


## A group of enemies waiting on a road cell.
class Spawn:
	extends RefCounted
	var index := 0  ## road index
	var enemy_id := "slime"
	var count := 1
	var elite := 0  ## how many of `count` are elites (the last ones)
	var level := 1  ## encounter card level
	var xp_mult := 1.0
	var source := "wild"  ## wild | card | boss
	var alive := true

	func label(db: GameDb) -> String:
		return "%s x%d" % [db.enemies[enemy_id].name_th, count]


var db: GameDb
var seed_value := 0
var board: Board
var hero: Hero

var lap := 1
var phase := Phase.WALKING
var won := false
var time := 0.0  ## seconds of game time
var tile_index := 0  ## road index the hero last reached (starts at camp)
var tile_progress := 0.0  ## 0..1 of the way to the next road cell

var spawns: Dictionary = {}  # road index -> Spawn
var placed: Dictionary = {}  # Vector2i -> CardInst
var flags: Dictionary = {}  # Vector2i -> {combo_id: true}, rebuilt when cards change
var hand: Array[CardInst] = []
var notices: Array[Notice] = []

var battle: Battle = null  ## the fight in progress
var last_battle: Battle = null  ## the most recent finished fight, for the log window
var last_fight: Dictionary = {}  ## {won, spawn, stats, lines} of the latest fight

# run totals, shown on the end screen
var fights := 0
var kills := 0
var laps_done := 0
var cards_played := 0
var combos_made := 0

var _fight_spawn: Spawn = null
var _kills_seen := 0
var _accum := 0.0
var _next_notice := 1
var _rng_cards := RandomNumberGenerator.new()
var _rng_spawn := RandomNumberGenerator.new()
var _rng_battle := RandomNumberGenerator.new()


func _init(p_db: GameDb, p_seed: int) -> void:
	db = p_db
	seed_value = p_seed
	_rng_cards.seed = hash("cards:%d" % p_seed)
	_rng_spawn.seed = hash("spawn:%d" % p_seed)
	_rng_battle.seed = hash("battle:%d" % p_seed)
	board = LoopGenerator.generate(db, p_seed)
	hero = Hero.new(db)
	hero.equip_skill(0, "fireball", 1)
	hero.equip_skill(1, "cleave", 1)
	_refresh_gear()
	hero.hp = hero.max_hp
	_roll_wild()
	_deal_start_hand()


# --- time -------------------------------------------------------------------------------


func advance(dt: float) -> void:
	if phase == Phase.ENDED:
		return
	_accum += dt
	while _accum >= STEP and phase != Phase.ENDED:
		_accum -= STEP
		_step(STEP)


func _step(dt: float) -> void:
	time += dt
	_expire_notices()
	if phase == Phase.WALKING:
		_walk(dt)
	elif phase == Phase.FIGHTING:
		_fight(dt)


func _walk(dt: float) -> void:
	tile_progress += dt / db.c("walk_seconds_per_tile")
	while tile_progress >= 1.0 and phase == Phase.WALKING:
		tile_progress -= 1.0
		tile_index = board.next_index(tile_index)
		_arrive(tile_index)


func _arrive(i: int) -> void:
	if i == 0:
		_complete_lap()
		if phase != Phase.WALKING:
			return
	_pass_effects(i)
	var sp: Spawn = spawns.get(i)
	if sp != null and sp.alive:
		_start_battle(sp)


## Hero position on the board in cell units (cell centre = +0.5), for drawing.
func hero_cell_pos() -> Vector2:
	var a := Vector2(board.path[tile_index])
	var b := Vector2(board.path[board.next_index(tile_index)])
	if phase != Phase.WALKING:
		return a
	return a.lerp(b, clampf(tile_progress, 0.0, 1.0))


func hero_heading() -> Vector2i:
	return board.path[board.next_index(tile_index)] - board.path[tile_index]


# --- laps -----------------------------------------------------------------------------------


func _complete_lap() -> void:
	laps_done += 1
	var got := hero.heal(hero.max_hp * db.c("lap_heal_pct"))
	if got > 0.0:
		healed.emit(got, Vector2i(-1, -1))
	lap_completed.emit(lap)
	if lap >= db.ci("boss_lap"):
		_spawn_boss()
		return
	lap += 1
	_refresh_gear()
	_respawn_all()
	var picks := db.ci("lap_card_picks")
	for k in picks:
		_add_notice("lap_card", "การ์ดรอบที่ %d (%d/%d)" % [lap - 1, k + 1, picks], "เลือก 1 จาก %d" % db.ci("lap_card_offers"), {"offers": make_offers()})
	toast.emit("ครบรอบ! เข้ารอบที่ %d" % lap)


func _spawn_boss() -> void:
	var sp := Spawn.new()
	sp.index = 0
	sp.enemy_id = "boss_warden"
	sp.count = 1
	sp.source = "boss"
	spawns[0] = sp
	toast.emit("บอสปรากฏที่ค่าย!")


## Card encounters come back and the wild groups are rolled again (01-run.md step 4).
func _respawn_all() -> void:
	for i in spawns.keys():
		if spawns[i].source == "wild":
			spawns.erase(i)
	for cell: Vector2i in placed:
		if db.cards[placed[cell].id].is_encounter():
			_sync_card_spawn(cell, true)
	_roll_wild()


func _roll_wild() -> void:
	var groups := db.ci("wild_groups_base") + int(floor(lap / db.c("wild_groups_per_laps")))
	var free: Array[int] = []
	for i in range(1, board.path.size()):
		if not spawns.has(i):
			free.append(i)
	for k in mini(groups, free.size()):
		var pick := _rng_spawn.randi() % free.size()
		var sp := Spawn.new()
		sp.index = free[pick]
		sp.enemy_id = "slime"
		sp.count = db.ci("wild_group_size")
		sp.source = "wild"
		spawns[sp.index] = sp
		free.remove_at(pick)


# --- fights ----------------------------------------------------------------------------------


func _start_battle(sp: Spawn) -> void:
	var def: GameDb.EnemyDef = db.enemies[sp.enemy_id]
	var foes: Array[Foe] = []
	for k in sp.count:
		var is_elite := k >= sp.count - sp.elite
		foes.append(Foe.make(db, def, lap, is_elite, sp.xp_mult, _rng_battle))
	battle = Battle.new(db, hero, foes, _rng_battle)
	_fight_spawn = sp
	_kills_seen = 0
	tile_progress = 0.0
	phase = Phase.FIGHTING
	battle_started.emit(battle)


func _fight(dt: float) -> void:
	battle.step(dt)
	while _kills_seen < battle.kills.size():
		var f: Foe = battle.kills[_kills_seen]
		_kills_seen += 1
		kills += 1
		_award_xp(f.xp)
	if not battle.finished:
		return
	fights += 1
	last_fight = {
		"won": battle.hero_won,
		"spawn": _fight_spawn.label(db),
		"stats": battle.stats.duplicate(true),
		"lines": battle.explain(),
		"lap": lap,
	}
	var finished := battle
	var boss_down: bool = finished.hero_won and _fight_spawn.source == "boss"
	if finished.hero_won:
		_fight_spawn.alive = false
	phase = Phase.WALKING
	battle = null
	last_battle = finished
	battle_ended.emit(finished)
	if not finished.hero_won:
		_end_run(false)
	elif boss_down:
		_end_run(true)


func _end_run(did_win: bool) -> void:
	phase = Phase.ENDED
	won = did_win
	ended.emit(did_win)


## Run totals for the end screen.
func summary() -> Dictionary:
	return {
		"won": won,
		"seed": seed_value,
		"lap": lap,
		"level": hero.level,
		"time": time,
		"fights": fights,
		"kills": kills,
		"cards_played": cards_played,
		"combos": combos_made,
	}


# --- XP, level, stat points ---------------------------------------------------------------


func _award_xp(amount: int) -> void:
	if amount <= 0:
		return
	var gained := hero.add_xp(amount)
	for k in gained:
		var lv := hero.level - gained + k + 1
		_add_notice("stat", "ขึ้น level %d" % lv, "แต้ม stat +%d" % db.ci("points_per_level"), {"remaining": db.ci("points_per_level")})
		leveled.emit(lv)
	if gained > 0:
		_refresh_gear()


## API: spend one stat point ("str" | "agi" | "int"). Uses up the oldest level-up notice.
func spend_point(stat: String) -> bool:
	if not hero.spend(stat):
		return false
	for n in notices:
		if n.kind == "stat":
			n.payload["remaining"] = int(n.payload["remaining"]) - 1
			if n.payload["remaining"] <= 0:
				remove_notice(n)
			break
	_refresh_gear()
	return true


## Stand-in for items and skill cards until phase 4: average gear and skill levels for the
## current lap, the same assumptions tools/balance_sim.py uses. Switch off with
## gear_standin = 0 in constants.csv.
func _refresh_gear() -> void:
	if db.c("gear_standin") == 0.0:
		hero.set_mods("gear_standin", {})
		return
	var p: Dictionary = hero.pts
	var caster: bool = p["int"] > 0 and p["int"] >= p["str"] and p["int"] >= p["agi"]
	var m := {
		"atk": db.c("gear_watk_base") + db.c("gear_watk_per_lap") * lap,
		"max_hp": db.c("gear_hp_base") + db.c("gear_hp_per_lap") * lap,
		"crit": db.c("gear_crit"),
	}
	if caster:
		m["ap"] = db.c("gear_ap_base") + db.c("gear_ap_per_lap") * lap
	hero.set_mods("gear_standin", m)
	var lv0 := 1
	var lv1 := 1
	if lap >= 8:
		lv0 = 3
		lv1 = 2
	elif lap >= 5:
		lv0 = 2
	if hero.skills.size() > 1:
		hero.skills[0]["level"] = lv0
		hero.skills[1]["level"] = lv1


# --- notices ------------------------------------------------------------------------------------


func _add_notice(kind: String, title: String, detail: String, payload: Dictionary = {}, ttl: float = -1.0) -> Notice:
	var n := Notice.new()
	n.id = _next_notice
	_next_notice += 1
	n.kind = kind
	n.title = title
	n.detail = detail
	n.payload = payload
	n.created = time
	n.expires = time + ttl if ttl >= 0.0 else -1.0
	notices.append(n)
	notice_added.emit(n)
	return n


func remove_notice(n: Notice) -> void:
	if notices.has(n):
		notices.erase(n)
		notice_removed.emit(n)


func _expire_notices() -> void:
	for n in notices.duplicate():
		if n.expires >= 0.0 and time >= n.expires:
			remove_notice(n)


## First notice of a kind, oldest first.
func first_notice(kind: String) -> Notice:
	for n in notices:
		if n.kind == kind:
			return n
	return null


# --- cards ----------------------------------------------------------------------------------------


func hand_limit() -> int:
	return db.ci("hand_size")


func _deal_start_hand() -> void:
	var pool := db.unlocked_card_ids()
	var terrain: Array[String] = []
	var enc: Array[String] = []
	for id in pool:
		var d: GameDb.CardDef = db.cards[id]
		if d.type == "terrain":
			terrain.append(id)
		elif d.type == "encounter":
			enc.append(id)
	give_card(CardInst.make(terrain[_rng_cards.randi() % terrain.size()]))
	give_card(CardInst.make(enc[_rng_cards.randi() % enc.size()]))
	give_card(CardInst.make("house"))


## Adds a card to the hand. A full hand pushes the oldest card out for a little XP.
func give_card(card: CardInst) -> void:
	if hand.size() >= hand_limit():
		var gone: CardInst = hand.pop_front()
		toast.emit("มือเต็ม: %s ถูกไล่ออก (+%d XP)" % [db.cards[gone.id].name_th, db.ci("discard_xp")])
		_award_xp(db.ci("discard_xp"))
	hand.append(card)
	hand_changed.emit()


## Cards to offer for one lap pick. At least one is a card the player already holds or has
## on the map (when there is one), so merging stays within reach (02-cards.md).
func make_offers() -> Array[CardInst]:
	var pool := db.unlocked_card_ids()
	var count := mini(db.ci("lap_card_offers"), pool.size())
	var owned: Array[String] = []
	for c in hand:
		if pool.has(c.id) and not owned.has(c.id):
			owned.append(c.id)
	for cell: Vector2i in placed:
		var id: String = placed[cell].id
		if pool.has(id) and not owned.has(id):
			owned.append(id)
	var picks: Array[String] = []
	if not owned.is_empty():
		picks.append(owned[_rng_cards.randi() % owned.size()])
	var rest: Array[String] = []
	for id in pool:
		if not picks.has(id):
			rest.append(id)
	while picks.size() < count and not rest.is_empty():
		var k := _rng_cards.randi() % rest.size()
		picks.append(rest[k])
		rest.remove_at(k)
	# shuffle so the helper card is not always first
	for i in range(picks.size() - 1, 0, -1):
		var j := _rng_cards.randi() % (i + 1)
		var tmp := picks[i]
		picks[i] = picks[j]
		picks[j] = tmp
	var out: Array[CardInst] = []
	for id in picks:
		out.append(CardInst.make(id))
	return out


## API: take offer `index` of a lap-card notice into the hand.
func choose_offer(n: Notice, index: int) -> bool:
	if n.kind != "lap_card" or not notices.has(n):
		return false
	var offers: Array = n.payload["offers"]
	if index < 0 or index >= offers.size():
		return false
	remove_notice(n)
	give_card(offers[index])
	return true


## What would happen if hand card `hand_index` were played on `cell`.
## {ok, reason, action, level, combos: [ComboDef] that would form}
func check_place(hand_index: int, cell: Vector2i) -> Dictionary:
	if hand_index < 0 or hand_index >= hand.size():
		return {"ok": false, "reason": "ไม่มีการ์ดใบนี้", "action": "place", "level": 1, "combos": []}
	return check_card(hand[hand_index], cell)


func check_card(card: CardInst, cell: Vector2i) -> Dictionary:
	var res := CardRules.check_place(db, board, placed, card, cell, tile_index)
	var combos: Array[GameDb.ComboDef] = []
	if res["ok"] and res["action"] == "place":
		var after := placed.duplicate()
		after[cell] = card.copy()
		for c in CardRules.new_combos(db, board, placed, after):
			combos.append(db.combos[c["id"]])
	res["combos"] = combos
	return res


## API: play hand card `hand_index` on `cell` (place, merge, or clear).
func play_card(hand_index: int, cell: Vector2i) -> bool:
	if hand_index < 0 or hand_index >= hand.size() or phase == Phase.ENDED:
		return false
	var card: CardInst = hand[hand_index]
	var res := check_card(card, cell)
	if not res["ok"]:
		return false
	hand.remove_at(hand_index)
	var before := placed.duplicate()
	var action: String = res["action"]
	match action:
		"merge":
			(placed[cell] as CardInst).level += 1
		"clear":
			var gone: CardInst = placed[cell]
			placed.erase(cell)
			spawns.erase(board.index_of(cell))
			hand.append(CardInst.make(gone.id))
		_:
			placed[cell] = card
	cards_played += 1
	_cards_changed(cell, before)
	card_played.emit(cell, placed.get(cell, card), action)
	hand_changed.emit()
	return true


func _cards_changed(cell: Vector2i, before: Dictionary) -> void:
	flags = CardRules.combo_flags(db, board, placed)
	hero.set_mods("terrain", CardRules.terrain_mods(db, board, placed))
	for c in CardRules.new_combos(db, board, before, placed):
		combos_made += 1
		combo_formed.emit(db.combos[c["id"]], c["b"])
		toast.emit("combo: %s" % db.combos[c["id"]].name_th)
	# encounter cards: (re)build the group on their road cell
	for c: Vector2i in placed:
		if db.cards[placed[c].id].is_encounter():
			_sync_card_spawn(c, c == cell)


## Makes the Spawn on an encounter card's road cell match the card. `revive` brings the
## group back (a freshly placed or merged card).
func _sync_card_spawn(cell: Vector2i, revive: bool) -> void:
	var i := board.index_of(cell)
	var params := CardRules.encounter_params(db, placed, flags, cell)
	var sp: Spawn = spawns.get(i)
	var was_alive := true
	if sp == null or sp.source != "card":
		sp = Spawn.new()
		sp.index = i
		sp.source = "card"
		spawns[i] = sp
	else:
		was_alive = sp.alive
	sp.enemy_id = params["enemy"]
	sp.count = params["count"]
	sp.elite = params["elite"]
	sp.xp_mult = params["xp_mult"]
	sp.level = params["level"]
	sp.alive = true if revive else was_alive


## Walking onto a road cell: cards touching it heal the hero (meadow, house, hot spring).
func _pass_effects(i: int) -> void:
	for n in board.neighbors8(board.path[i]):
		if not placed.has(n):
			continue
		var amount := CardRules.pass_heal(db, board, placed, flags, n, hero.max_hp)
		if amount > 0.0:
			var got := hero.heal(amount)
			if got > 0.0:
				healed.emit(got, n)


# --- debug --------------------------------------------------------------------------------------


func debug_level_up() -> void:
	_award_xp(hero.xp_needed() - hero.xp)


func debug_give_cards(ids: Array) -> void:
	for id in ids:
		give_card(CardInst.make(id))

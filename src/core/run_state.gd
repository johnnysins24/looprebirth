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
signal rp_gained(amount: int)
signal town_changed(town: Town)
signal item_equipped(item: Item)

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
	var source := "wild"  ## wild | card | boss | raid | duel
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

var meta: Meta  ## Rebirth tree ranks and unlocks (an empty Meta for tests)
var town: Town  ## largest building group, rebuilt whenever cards change
var top_tier := 0  ## highest town tier reached in this run
var perk_for_tier: Dictionary = {}  # tier -> perk id picked for it
var equipment: Dictionary = {}  # slot -> Item
var auto_equip := false  ## put on a drop at once when it beats what is worn
var event_cells: Dictionary = {}  # road index -> event id ("?" markers)
var goals: RunGoals
var rp_earned := 0
var rerolls_left := 0

var battle: Battle = null  ## the fight in progress
var last_battle: Battle = null  ## the most recent finished fight, for the log window
var last_fight: Dictionary = {}  ## {won, spawn, stats, lines} of the latest fight

# run totals, shown on the end screen
var fights := 0
var kills := 0
var laps_done := 0
var cards_played := 0
var combos_made := 0
var fights_won := 0
var elites_killed := 0
var combo_kinds: Dictionary = {}  # combo id -> true
var merged_tile_l3 := false
var merged_skill_l3 := false

var _fight_spawn: Spawn = null
var _kills_seen := 0
var _accum := 0.0
var _next_notice := 1
var _rng_cards := RandomNumberGenerator.new()
var _rng_spawn := RandomNumberGenerator.new()
var _rng_battle := RandomNumberGenerator.new()
var _rng_skill := RandomNumberGenerator.new()
var _rng_loot := RandomNumberGenerator.new()
var _rng_event := RandomNumberGenerator.new()
var _xp_carry := 0.0


func _init(p_db: GameDb, p_seed: int, p_meta: Meta = null) -> void:
	db = p_db
	seed_value = p_seed
	meta = p_meta if p_meta != null else Meta.new(db)
	_rng_cards.seed = hash("cards:%d" % p_seed)
	_rng_spawn.seed = hash("spawn:%d" % p_seed)
	_rng_battle.seed = hash("battle:%d" % p_seed)
	_rng_skill.seed = hash("skill:%d" % p_seed)
	_rng_loot.seed = hash("loot:%d" % p_seed)
	_rng_event.seed = hash("event:%d" % p_seed)
	var rng_goals := RandomNumberGenerator.new()
	rng_goals.seed = hash("goals:%d" % p_seed)
	board = LoopGenerator.generate(db, p_seed)
	hero = Hero.new(db)
	hero.equip_skill(0, "fireball", 1)
	hero.equip_skill(1, "cleave", 1)
	if skill_slots() > 2:
		hero.skills.append({})
	var rng_gear := RandomNumberGenerator.new()
	rng_gear.seed = hash("gear:%d" % p_seed)
	for slot: String in Item.SLOTS.slice(0, db.ci("start_gear")):
		equipment[slot] = Item.roll(db, rng_gear, 1, 0.0, 0.0, slot, Item.Rarity.COMMON, Item.Rarity.COMMON)
	town = Town.compute(db, board, placed, flags)
	goals = RunGoals.pick(db, rng_goals, db.ci("goals_base") + meta.rank("more_goals"))
	rerolls_left = meta.rank("reroll")
	_refresh_gear()
	hero.hp = hero.max_hp
	_roll_wild()
	_deal_start_hand()
	for k in meta.rank("quick_start"):
		_add_notice("lap_card", "การ์ดเริ่มต้น (%d/%d)" % [k + 1, meta.rank("quick_start")], "เลือก 1 จาก %d" % offer_count(), {"offers": make_offers()})


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
	if event_cells.has(i):
		_open_event(i)
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
		_check_goals()
		return
	lap += 1
	rerolls_left = meta.rank("reroll")
	_respawn_all()
	_roll_event()
	var picks := db.ci("lap_card_picks") + (1 if perk_active("market") else 0)
	for k in picks:
		_add_notice("lap_card", "การ์ดรอบที่ %d (%d/%d)" % [lap - 1, k + 1, picks], "เลือก 1 จาก %d" % offer_count(), {"offers": make_offers()})
	if perk_active("shop"):
		var wares: Array[Item] = []
		for k in db.ci("perk_shop_offers"):
			wares.append(Item.roll(db, _rng_loot, lap, hero.luck, smithy_bonus()))
		_add_notice("shop", "ร้านค้า รอบที่ %d" % lap, "เลือกของ 1 ชิ้นจาก %d" % wares.size(), {"items": wares})
	toast.emit("ครบรอบ! เข้ารอบที่ %d" % lap)
	_check_goals()


func _spawn_boss() -> void:
	var sp := Spawn.new()
	sp.index = 0
	sp.enemy_id = "boss_warden"
	sp.count = 1
	sp.source = "boss"
	spawns[0] = sp
	toast.emit("บอสปรากฏที่ค่าย!")


## Card encounters come back, town raids and wild groups are rolled again (01-run.md step 4).
func _respawn_all() -> void:
	for i in spawns.keys():
		if spawns[i].source == "wild" or spawns[i].source == "raid":
			spawns.erase(i)
	for cell: Vector2i in placed:
		if db.cards[placed[cell].id].is_encounter():
			_sync_card_spawn(cell, true)
	_spawn_raids()
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


## A town draws bandits (03-town.md): one group per tier, on the free road cells nearest to it.
func _spawn_raids() -> void:
	if town.tier <= 0:
		return
	var cands: Array[Dictionary] = []
	for i in range(1, board.path.size()):
		if spawns.has(i) or event_cells.has(i):
			continue
		var d := 99
		for t: Vector2i in town.cells:
			d = mini(d, maxi(absi(t.x - board.path[i].x), absi(t.y - board.path[i].y)))
		cands.append({"index": i, "d": d, "tie": _rng_spawn.randf()})
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["d"] < b["d"] or (a["d"] == b["d"] and a["tie"] < b["tie"]))
	for k in mini(town.tier, cands.size()):
		var sp := Spawn.new()
		sp.index = cands[k]["index"]
		sp.enemy_id = "bandit"
		sp.count = db.ci("raid_group_size")
		sp.source = "raid"
		spawns[sp.index] = sp


## 25% a "?" cell appears on an empty road cell (05-items-events.md).
func _roll_event() -> void:
	if _rng_event.randf() >= db.c("event_chance"):
		return
	var free: Array[int] = []
	for i in range(1, board.path.size()):
		if not spawns.has(i) and not event_cells.has(i):
			free.append(i)
	if free.is_empty():
		return
	var idx := free[_rng_event.randi() % free.size()]
	event_cells[idx] = db.event_order[_rng_event.randi() % db.event_order.size()]


func _open_event(i: int) -> void:
	var def: GameDb.EventDef = db.events[event_cells[i]]
	event_cells.erase(i)
	_add_notice("event", def.name_th, def.story_th, {"event": def.id})


# --- fights ----------------------------------------------------------------------------------


func _start_battle(sp: Spawn) -> void:
	var def: GameDb.EnemyDef = db.enemies[sp.enemy_id]
	var hp_mult := 1.0
	if sp.source != "boss" and perk_active("guard_post") and town.within(board.path[sp.index], db.ci("perk_guard_range")):
		hp_mult = db.c("perk_guard_hp")
	var foes: Array[Foe] = []
	for k in sp.count:
		var is_elite := k >= sp.count - sp.elite
		foes.append(Foe.make(db, def, lap, is_elite, sp.xp_mult, _rng_battle, hp_mult))
	battle = Battle.new(db, hero, foes, _rng_battle)
	_fight_spawn = sp
	_kills_seen = 0
	tile_progress = 0.0
	phase = Phase.FIGHTING
	battle_started.emit(battle)


## API: accept the deserter's duel (event). The elite bandit fights right here.
func start_duel() -> bool:
	if phase != Phase.WALKING:
		return false
	var sp := Spawn.new()
	sp.index = tile_index
	sp.enemy_id = "bandit"
	sp.count = 1
	sp.elite = 1
	sp.source = "duel"
	_start_battle(sp)
	return true


func _fight(dt: float) -> void:
	battle.step(dt)
	while _kills_seen < battle.kills.size():
		var f: Foe = battle.kills[_kills_seen]
		_kills_seen += 1
		kills += 1
		_kill_xp(f.xp)
		if f.elite:
			elites_killed += 1
		if _fight_spawn.source != "boss":
			_roll_drops(f)
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
		fights_won += 1
		if _fight_spawn.source == "duel":
			_add_skill_notice("ชนะการดวล")
	phase = Phase.WALKING
	battle = null
	last_battle = finished
	battle_ended.emit(finished)
	_check_goals()
	if not finished.hero_won:
		_end_run(false)
	elif boss_down:
		_end_run(true)


func _end_run(did_win: bool) -> void:
	if did_win:
		_gain_rp(db.ci("boss_rp"))
	phase = Phase.ENDED
	won = did_win
	meta.record_run(did_win, mini(lap, db.ci("boss_lap")), seed_value)
	ended.emit(did_win)


## Run totals for the end screen.
func summary() -> Dictionary:
	var goal_rows: Array[Dictionary] = []
	for g in goals.list:
		goal_rows.append({"text": g.text, "done": g.done, "rp": g.rp})
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
		"rp": rp_earned,
		"goals": goal_rows,
		"town_tier": top_tier,
	}


func _gain_rp(amount: int) -> void:
	rp_earned += amount
	meta.add_rp(amount)
	rp_gained.emit(amount)


# --- run goals ---------------------------------------------------------------------------------


func _check_goals() -> void:
	for g in goals.check(self):
		_gain_rp(g.rp)
		_add_notice("info", "เป้าหมายสำเร็จ +%d RP" % g.rp, g.text, {}, 5.0)
		toast.emit("เป้าหมายสำเร็จ: %s (+%d RP)" % [g.text, g.rp])


func encounter_count() -> int:
	var n := 0
	for c: Vector2i in placed:
		if db.cards[placed[c].id].is_encounter():
			n += 1
	return n


## Gear slots holding a rare or epic item.
func rare_slots() -> int:
	var n := 0
	for slot in equipment:
		if (equipment[slot] as Item).rarity >= Item.Rarity.RARE:
			n += 1
	return n


# --- XP, level, stat points ---------------------------------------------------------------


## XP from a kill, with the school's bonus; fractions carry over so nothing is lost.
func _kill_xp(base: int) -> void:
	var mult := db.c("perk_school_xp") if perk_active("school") else 1.0
	_xp_carry += base * mult
	var whole := int(_xp_carry)
	_xp_carry -= whole
	_award_xp(whole)


func _award_xp(amount: int) -> void:
	if amount <= 0:
		return
	var gained := hero.add_xp(amount)
	for k in gained:
		var lv := hero.level - gained + k + 1
		_add_notice("stat", "ขึ้น level %d" % lv, "แต้ม stat +%d" % db.ci("points_per_level"), {"remaining": db.ci("points_per_level")})
		_add_skill_notice("ขึ้น level %d" % lv)
		leveled.emit(lv)
	if gained > 0:
		_check_goals()


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
	return true


# --- town and perks (03-town.md) ----------------------------------------------------------------


func skill_slots() -> int:
	return db.ci("skill_slots") + meta.rank("third_skill_slot")


## A perk works while the town is at least at the tier it was picked for.
func perk_active(id: String) -> bool:
	for tier: int in perk_for_tier:
		if perk_for_tier[tier] == id and town.tier >= tier:
			return true
	return false


func perks_picked() -> Array[String]:
	var out: Array[String] = []
	for tier: int in perk_for_tier:
		out.append(perk_for_tier[tier])
	return out


func _update_town() -> void:
	var old_tier := town.tier
	var old_count := town.count
	town = Town.compute(db, board, placed, flags)
	while top_tier < town.tier:
		top_tier += 1
		_offer_perk(top_tier)
		toast.emit("%s ขั้น %d: เลือก perk" % [Town.NAMES[top_tier], top_tier])
	if old_tier != town.tier or old_count != town.count:
		town_changed.emit(town)


func _offer_perk(tier: int) -> void:
	var taken := {}
	for id in perks_picked():
		taken[id] = true
	for n in notices:
		if n.kind == "town_perk":
			for id in n.payload["options"]:
				taken[id] = true
	var pool: Array[String] = []
	for id in db.perk_order:
		if not taken.has(id):
			pool.append(id)
	var options: Array[String] = []
	while options.size() < 3 and not pool.is_empty():
		options.append(pool.pop_at(_rng_event.randi() % pool.size()))
	if options.is_empty():
		return
	_add_notice("town_perk", "%s: เลือก perk" % Town.NAMES[tier], "ขั้น %d · เลือก 1 จาก %d" % [tier, options.size()], {"tier": tier, "options": options})


## API: pick option `index` of a town perk notice.
func choose_perk(n: Notice, index: int) -> bool:
	if n.kind != "town_perk" or not notices.has(n):
		return false
	var options: Array = n.payload["options"]
	if index < 0 or index >= options.size():
		return false
	var id: String = options[index]
	perk_for_tier[int(n.payload["tier"])] = id
	remove_notice(n)
	toast.emit("perk: %s" % db.perks[id].name_th)
	if id == "training_yard":
		var pts := db.ci("perk_yard_points")
		hero.unspent += pts
		_add_notice("stat", "ลานฝึก", "แต้ม stat +%d" % pts, {"remaining": pts})
	elif id == "bell_tower":
		hand_changed.emit()
	_check_goals()
	return true


# --- items (05-items-events.md) --------------------------------------------------------------------


## +x to the rare chance from smithies on the map.
func smithy_bonus() -> float:
	var total := 0.0
	for c: Vector2i in placed:
		if placed[c].id == "smithy":
			total += db.cards["smithy"].level_params(placed[c].level)["value"]
	return total


func _roll_drops(f: Foe) -> void:
	var chance := 1.0 if f.elite else minf(1.0, f.drop_chance * _fight_spawn.xp_mult)
	if _rng_loot.randf() < chance:
		offer_item(Item.roll(db, _rng_loot, lap, hero.luck, smithy_bonus()))
	if f.elite and _rng_loot.randf() < db.c("skill_elite_drop"):
		_add_skill_notice("elite ดรอป")


## Puts a new item in the notice list, or wears it at once when auto-equip is on and it is better.
func offer_item(item: Item) -> void:
	if auto_equip and item.better_than(equipment.get(item.slot)):
		_wear(item)
		toast.emit("ใส่ %s อัตโนมัติ" % item.title())
		return
	var pending: Array[Notice] = []
	for n in notices:
		if n.kind == "item":
			pending.append(n)
	if pending.size() >= db.ci("item_max_pending"):
		var old: Item = pending[0].payload["item"]
		remove_notice(pending[0])
		var xp := db.ci("item_xp_per_level") * old.level
		toast.emit("ของเต็ม: %s กลายเป็น XP +%d" % [old.title(), xp])
		_award_xp(xp)
	_add_notice("item", item.title(), "%s · %s" % [item.rarity_name(), Item.SLOT_NAMES[item.slot]], {"item": item})


func _wear(item: Item) -> void:
	equipment[item.slot] = item
	_refresh_gear()
	item_equipped.emit(item)
	_check_goals()


## API: put on the item of an item notice (what it replaces is thrown away).
func equip_item(n: Notice) -> bool:
	if n.kind != "item" or not notices.has(n):
		return false
	remove_notice(n)
	_wear(n.payload["item"])
	return true


## API: throw the item of an item notice away.
func discard_item(n: Notice) -> bool:
	if n.kind != "item" or not notices.has(n):
		return false
	remove_notice(n)
	return true


## API: take ware `index` of a shop notice (it then follows the normal item rules).
func buy_ware(n: Notice, index: int) -> bool:
	if n.kind != "shop" or not notices.has(n):
		return false
	var wares: Array = n.payload["items"]
	if index < 0 or index >= wares.size():
		return false
	remove_notice(n)
	offer_item(wares[index])
	return true


## Gear stats are the sum of the worn items.
func _refresh_gear() -> void:
	var m := {}
	for slot in equipment:
		var it: Item = equipment[slot]
		for k in it.stats:
			m[k] = float(m.get(k, 0.0)) + float(it.stats[k])
	hero.set_mods("gear", m)


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


## Notices the player can open (everything except plain information).
static func is_actionable(n: Notice) -> bool:
	return n.kind != "info"


# --- cards ----------------------------------------------------------------------------------------


func hand_limit() -> int:
	var n := db.ci("hand_size") + meta.rank("bigger_hand")
	if perk_active("bell_tower"):
		n += db.ci("perk_bell_hand")
	return n


func card_name(card: CardInst) -> String:
	return db.skills[card.id].name_th if card.skill else db.cards[card.id].name_th


func _deal_start_hand() -> void:
	var pool := db.unlocked_card_ids(meta.unlocked_flags())
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
		var xp := db.ci("discard_xp") * (db.ci("perk_bell_discard") if perk_active("bell_tower") else 1)
		toast.emit("มือเต็ม: %s ถูกไล่ออก (+%d XP)" % [card_name(gone), xp])
		_award_xp(xp)
	hand.append(card)
	hand_changed.emit()


func offer_count() -> int:
	return db.ci("lap_card_offers") + (1 if meta.rank("sharp_eye") >= 1 else 0)


## Cards to offer for one lap pick. At least one is a card the player already holds or has
## on the map (when there is one), so merging stays within reach (02-cards.md).
func make_offers() -> Array[CardInst]:
	var pool := db.unlocked_card_ids(meta.unlocked_flags())
	var count := mini(offer_count(), pool.size())
	var owned: Array[String] = []
	for c in hand:
		if not c.skill and pool.has(c.id) and not owned.has(c.id):
			owned.append(c.id)
	for cell: Vector2i in placed:
		var id: String = placed[cell].id
		if pool.has(id) and not owned.has(id):
			owned.append(id)
	var picks := _pick_offers(_rng_cards, pool, owned, count)
	var out: Array[CardInst] = []
	for id in picks:
		out.append(CardInst.make(id))
	return out


## `count` distinct ids from `pool`, the first one drawn from `owned` when that is not empty,
## then shuffled so the helper card is not always first.
func _pick_offers(rng: RandomNumberGenerator, pool: Array[String], owned: Array[String], count: int) -> Array[String]:
	var picks: Array[String] = []
	if not owned.is_empty():
		picks.append(owned[rng.randi() % owned.size()])
	var rest: Array[String] = []
	for id in pool:
		if not picks.has(id):
			rest.append(id)
	while picks.size() < count and not rest.is_empty():
		var k := rng.randi() % rest.size()
		picks.append(rest[k])
		rest.remove_at(k)
	for i in range(picks.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp := picks[i]
		picks[i] = picks[j]
		picks[j] = tmp
	return picks


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


## API: draw the offered cards of a lap-card notice again (Rebirth tree "สุ่มใหม่").
func reroll_offers(n: Notice) -> bool:
	if n.kind != "lap_card" or not notices.has(n) or rerolls_left <= 0:
		return false
	rerolls_left -= 1
	n.payload["offers"] = make_offers()
	return true


## What would happen if hand card `hand_index` were played on `cell`.
## {ok, reason, action, level, combos: [ComboDef] that would form}
func check_place(hand_index: int, cell: Vector2i) -> Dictionary:
	if hand_index < 0 or hand_index >= hand.size():
		return {"ok": false, "reason": "ไม่มีการ์ดใบนี้", "action": "place", "level": 1, "combos": []}
	return check_card(hand[hand_index], cell)


func check_card(card: CardInst, cell: Vector2i) -> Dictionary:
	if card.skill:
		return {"ok": false, "reason": "skill card ลากไปช่อง skill ของฮีโร่", "action": "place", "level": card.level, "combos": []}
	var res := CardRules.check_place(db, board, placed, card, cell, tile_index)
	var combos: Array[GameDb.ComboDef] = []
	if res["ok"] and res["action"] == "place":
		if db.cards[card.id].is_encounter() and event_cells.has(board.index_of(cell)):
			res["ok"] = false
			res["reason"] = "มีจุด ? อยู่ช่องนี้"
		elif _carpenter_applies(card, cell):
			res["level"] = 2
		if res["ok"]:
			var after := placed.duplicate()
			var copy := card.copy()
			copy.level = res["level"]
			after[cell] = copy
			for c in CardRules.new_combos(db, board, placed, after):
				combos.append(db.combos[c["id"]])
	res["combos"] = combos
	return res


## Carpenter: a new house that touches the town starts at L2.
func _carpenter_applies(card: CardInst, cell: Vector2i) -> bool:
	if card.id != "house" or card.level != 1 or not perk_active("carpenter"):
		return false
	for n in board.neighbors4(cell):
		if town.has_cell(n):
			return true
	return false


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
			var target := placed[cell] as CardInst
			target.level = res["level"]
			target.progress = res["progress"]
			if target.level >= 3:
				merged_tile_l3 = true
		"clear":
			var gone: CardInst = placed[cell]
			placed.erase(cell)
			spawns.erase(board.index_of(cell))
			hand.append(CardInst.make(gone.id))
		_:
			card.level = res["level"]
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
		combo_kinds[c["id"]] = true
		combo_formed.emit(db.combos[c["id"]], c["b"])
		toast.emit("combo: %s" % db.combos[c["id"]].name_th)
	# encounter cards: (re)build the group on their road cell
	for c: Vector2i in placed:
		if db.cards[placed[c].id].is_encounter():
			_sync_card_spawn(c, c == cell)
	_update_town()
	_check_goals()


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


## Walking onto a road cell: cards touching it heal the hero (meadow, house, hot spring), and
## so does the field hospital when the cell touches the town.
func _pass_effects(i: int) -> void:
	for n in board.neighbors8(board.path[i]):
		if not placed.has(n):
			continue
		var amount := CardRules.pass_heal(db, board, placed, flags, n, hero.max_hp)
		if amount > 0.0:
			var got := hero.heal(amount)
			if got > 0.0:
				healed.emit(got, n)
	if perk_active("field_hospital") and town.touches(board.path[i]):
		var got := hero.heal(hero.max_hp * db.c("perk_hospital_pct"))
		if got > 0.0:
			healed.emit(got, Vector2i(-1, -1))


# --- skill cards (04-hero-combat.md) -------------------------------------------------------------------


func _add_skill_notice(why: String) -> void:
	var offers := make_skill_offers()
	if offers.is_empty():
		return
	_add_notice("skill_card", "skill card · %s" % why, "เลือก 1 จาก %d" % offers.size(), {"offers": offers})


## Skill cards to offer: the library gives 4, and at least one is a skill the hero wears or holds.
func make_skill_offers() -> Array[CardInst]:
	var pool := db.unlocked_skill_ids(meta.unlocked_flags())
	var count := mini(db.ci("perk_library_offers") if perk_active("library") else db.ci("lap_card_offers"), pool.size())
	var owned: Array[String] = []
	for s in hero.skills:
		if not s.is_empty() and not owned.has(s["id"]):
			owned.append(s["id"])
	for c in hand:
		if c.skill and not owned.has(c.id):
			owned.append(c.id)
	var out: Array[CardInst] = []
	for id in _pick_offers(_rng_skill, pool, owned, count):
		out.append(CardInst.make_skill(id))
	return out


## API: take offer `index` of a skill-card notice into the hand.
func choose_skill_offer(n: Notice, index: int) -> bool:
	if n.kind != "skill_card" or not notices.has(n):
		return false
	var offers: Array = n.payload["offers"]
	if index < 0 or index >= offers.size():
		return false
	remove_notice(n)
	give_card(offers[index])
	return true


## What dropping skill card `card` on hero skill slot `slot` would do:
## {ok, reason, action: "equip" | "merge" | "swap", level}.
func check_skill_card(card: CardInst, slot: int) -> Dictionary:
	var res := {"ok": false, "reason": "", "action": "equip", "level": card.level, "partial": false}
	if not card.skill:
		res["reason"] = "การ์ดใบนี้วางบนแผนที่"
		return res
	if slot < 0 or slot >= skill_slots():
		res["reason"] = "ไม่มีช่อง skill นี้"
		return res
	var cur: Dictionary = hero.skills[slot] if slot < hero.skills.size() else {}
	if cur.is_empty():
		res["ok"] = true
		return res
	if cur["id"] != card.id:
		res["ok"] = true
		res["action"] = "swap"
		return res
	var step := CardRules.merge_step(int(cur["level"]), int(cur.get("progress", 0)), card.level)
	res["ok"] = step["ok"]
	res["reason"] = step["reason"]
	if step["ok"]:
		res["action"] = "merge"
		res["level"] = step["level"]
		res["progress"] = step["progress"]
		res["partial"] = step["level"] == int(cur["level"])
	return res


## API: drop hand card `hand_index` on hero skill slot `slot` (equip, merge or swap).
func play_skill_card(hand_index: int, slot: int) -> bool:
	if hand_index < 0 or hand_index >= hand.size() or phase == Phase.ENDED:
		return false
	var card: CardInst = hand[hand_index]
	var res := check_skill_card(card, slot)
	if not res["ok"]:
		return false
	hand.remove_at(hand_index)
	match res["action"]:
		"merge":
			hero.skills[slot]["level"] = res["level"]
			hero.skills[slot]["progress"] = res["progress"]
			if int(res["level"]) >= 3:
				merged_skill_l3 = true
		"swap":
			var old: Dictionary = hero.skills[slot]
			hero.equip_skill(slot, card.id, card.level, card.progress)
			var back := CardInst.make_skill(old["id"], int(old["level"]))
			back.progress = int(old.get("progress", 0))
			hand.append(back)
		_:
			hero.equip_skill(slot, card.id, card.level, card.progress)
	hand_changed.emit()
	_check_goals()
	return true


# --- events ----------------------------------------------------------------------------------------------


## API: pick option 0 or 1 of an event notice. `extra` carries the merchant's chosen hand
## indexes: {"cards": [i, j]}.
func resolve_event(n: Notice, option: int, extra: Dictionary = {}) -> bool:
	if n.kind != "event" or not notices.has(n):
		return false
	var ok := RunEvents.resolve(self, n, option, extra)
	if ok:
		remove_notice(n)
	return ok


## HP the hero can give without dying: `share` of `base`, never taking the last point.
func hp_cost(base: float, share: float) -> float:
	return maxf(0.0, minf(base * share, hero.hp - 1.0))


func lose_hp(amount: float) -> void:
	hero.hp = maxf(1.0, hero.hp - amount)


func new_item(min_rarity: int = Item.Rarity.COMMON) -> Item:
	return Item.roll(db, _rng_loot, lap, hero.luck, smithy_bonus(), "", min_rarity)


func event_random() -> float:
	return _rng_event.randf()


func grant_stat_points(count: int, title: String) -> void:
	hero.unspent += count
	_add_notice("stat", title, "แต้ม stat +%d" % count, {"remaining": count})


# --- debug --------------------------------------------------------------------------------------


func debug_level_up() -> void:
	_award_xp(hero.xp_needed() - hero.xp)


## Fills the notice list with one of everything, for screenshots and manual checks (--demo).
func debug_demo() -> void:
	debug_level_up()
	for k in 3:
		offer_item(new_item())
	for id in db.event_order:
		_add_notice("event", db.events[id].name_th, db.events[id].story_th, {"event": id})
	_offer_perk(1)
	var wares: Array[Item] = [new_item(), new_item()]
	_add_notice("shop", "ร้านค้า รอบที่ %d" % lap, "เลือกของ 1 ชิ้นจาก 2", {"items": wares})
	_add_notice("lap_card", "การ์ดรอบที่ 1 (1/2)", "เลือก 1 จาก %d" % offer_count(), {"offers": make_offers()})
	_add_notice("info", "เป้าหมายสำเร็จ +1 RP", goals.list[0].text, {}, 600.0)


func debug_give_cards(ids: Array) -> void:
	for id in ids:
		give_card(CardInst.make(id))

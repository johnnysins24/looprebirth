extends RefCounted
## Whole-run behaviour: walking, laps, fights, cards, notices.


func _run(seed_value: int = 1) -> RunState:
	return RunState.new(GameDb.load_default(), seed_value)


## Plays a run to the end with the bot; returns the finished RunState.
func _play(seed_value: int, build: String, max_seconds: float = 4000.0) -> RunState:
	var run := _run(seed_value)
	var bot := Bot.new(run, build, seed_value)
	var t := 0.0
	while run.phase != RunState.Phase.ENDED and t < max_seconds:
		run.advance(0.25)
		t += 0.25
		bot.act()
	return run


func test_new_run(t) -> void:
	var run := _run(3)
	t.eq(run.lap, 1)
	t.eq(run.hero.level, 1)
	t.eq(run.hand.size(), 3, "opening hand: terrain, encounter, house")
	var types := []
	for c in run.hand:
		types.append(run.db.cards[c.id].type)
	t.eq(types, ["terrain", "encounter", "building"])
	t.eq(run.tile_index, 0)
	var wild := 0
	for i in run.spawns:
		if run.spawns[i].source == "wild":
			wild += 1
	t.eq(wild, 2, "2 + floor(1/3) wild groups on lap 1")
	t.ok(not run.spawns.has(0), "nothing at the camp")


func test_hero_walks_one_tile_per_080_seconds(t) -> void:
	var run := _run(4)
	# remove spawns so nothing interrupts
	run.spawns.clear()
	run.advance(0.8 * 5 + 0.01)
	t.eq(run.tile_index, 5)
	t.eq(run.phase, RunState.Phase.WALKING)


func test_lap_completes_and_pays(t) -> void:
	var run := _run(5)
	run.spawns.clear()
	var n := run.board.path.size()
	run.hero.hp = 50.0
	run.advance(0.8 * n + 0.05)
	t.eq(run.lap, 2, "back at camp: lap 2")
	t.eq(run.tile_index, 0)
	t.ok(run.hero.hp > 50.0, "healed at camp")
	var offers := 0
	for nt in run.notices:
		if nt.kind == "lap_card":
			offers += 1
			t.eq(nt.payload["offers"].size(), 3)
	t.eq(offers, 2, "two card picks per lap")


func test_offers_include_a_mergeable_card(t) -> void:
	var run := _run(6)
	var held := {}
	for c in run.hand:
		held[c.id] = true
	for k in 30:
		var ids := []
		for c in run.make_offers():
			ids.append(c.id)
		var hit := false
		for id in ids:
			hit = hit or held.has(id)
		t.ok(hit, "offers %s share nothing with the hand %s" % [str(ids), str(held.keys())])
		t.eq(ids.size(), 3)
		t.eq(ids.size(), ids.duplicate().size())


func test_stat_notice_flow(t) -> void:
	var run := _run(7)
	run.debug_level_up()
	var n := run.first_notice("stat")
	t.ok(n != null, "level up creates a stat notice")
	t.eq(n.payload["remaining"], 3)
	t.ok(run.spend_point("str"))
	t.ok(run.spend_point("str"))
	t.eq(run.first_notice("stat").payload["remaining"], 1)
	t.ok(run.spend_point("agi"))
	t.ok(run.first_notice("stat") == null, "notice is gone once the points are spent")
	t.ok(not run.spend_point("int"))


func test_fight_xp_and_notice(t) -> void:
	var run := _run(8)
	var xp0 := run.hero.xp
	# run until the first fight ends
	var guard := 0
	while run.fights == 0 and guard < 5000:
		run.advance(0.1)
		guard += 1
	t.ok(run.fights >= 1, "the first fight happens")
	t.ok(run.hero.xp > xp0 or run.hero.level > 1, "kills give XP")
	t.ok(not run.last_fight.is_empty())
	t.ok(run.last_fight["won"])


func test_speed_does_not_change_the_outcome(t) -> void:
	var a := _run(11)
	var b := _run(11)
	for i in 4000:
		a.advance(0.05)
	for i in 1000:
		b.advance(0.2)
	t.eq(a.time, b.time)
	t.eq(a.tile_index, b.tile_index)
	t.eq(a.hero.hp, b.hero.hp)
	t.eq(a.kills, b.kills)


func test_bot_finishes_runs(t) -> void:
	var outcomes := {}
	for build in ["str", "mix"]:
		var run := _play(21, build)
		t.ok(run.phase == RunState.Phase.ENDED, "%s run ends" % build)
		outcomes[build] = run.summary()
		t.ok(run.time > 30.0)
	print("    bot runs: ", outcomes)

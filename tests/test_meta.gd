extends RefCounted
## Run goals, Rebirth points and the Rebirth tree (docs/design/06-meta.md).

const H := preload("res://tests/helpers.gd")

const TMP := "user://test_profile.json"


func _meta(rp: int = 0) -> Meta:
	var m := Meta.new(GameDb.load_default())
	m.rp = rp
	return m


func test_tree_data_loads_with_costs_and_requirements(t) -> void:
	var db := GameDb.load_default()
	t.eq(db.node_order.size(), 14)
	var total := 0
	for id in db.node_order:
		var n: GameDb.NodeDef = db.nodes[id]
		t.eq(n.costs.size(), n.ranks, "%s has a price for every rank" % id)
		for r in range(1, n.ranks + 1):
			total += n.cost_of(r)
	t.eq(total, 36, "the whole tree costs 36 RP")
	t.eq(db.nodes["sharp_eye"].requires, "bigger_hand")
	t.eq(db.nodes["unlock_heal"].unlock_id(), "heal")
	t.eq(db.nodes["bigger_hand"].unlock_id(), "")


func test_buying_needs_rp_and_requirements(t) -> void:
	var m := _meta(0)
	t.ok(not m.buy("bigger_hand"), "no RP")
	m.rp = 1
	t.ok(m.buy("bigger_hand"))
	t.eq(m.rp, 0)
	t.eq(m.rank("bigger_hand"), 1)
	m.rp = 10
	t.ok(not m.buy("reroll"), "reroll needs sharp eye, which needs bigger hand")
	t.ok(m.buy("sharp_eye"), "sharp eye is open now")
	t.eq(m.rp, 8)
	t.ok(m.buy("reroll"))
	t.ok(m.buy("bigger_hand"), "rank 2 costs 2")
	t.ok(m.buy("bigger_hand"), "rank 3 costs 3")
	t.ok(not m.buy("bigger_hand"), "ranks are capped at 3")
	t.eq(m.rp, 8 - 2 - 2 - 3)
	t.ok(not m.check_buy("nope")["ok"])


func test_save_and_load_round_trip(t) -> void:
	var db := GameDb.load_default()
	var m := Meta.new(db, TMP)
	m.rp = 7
	m.ranks = {"bigger_hand": 2, "unlock_heal": 1}
	m.record_run(true, 10, 77)
	var m2 := Meta.new(db, TMP)
	t.eq(m2.rp, 7)
	t.eq(m2.rank("bigger_hand"), 2)
	t.eq(m2.rank("unlock_heal"), 1)
	t.eq(m2.runs, 1)
	t.eq(m2.wins, 1)
	t.eq(m2.best_lap, 10)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	var m3 := Meta.new(db, TMP)
	t.eq(m3.rp, 0, "a missing file starts fresh")


func test_unlocks_change_the_pools(t) -> void:
	var db := GameDb.load_default()
	var m := Meta.new(db)
	t.ok(not db.unlocked_card_ids(m.unlocked_flags()).has("bandit_camp"))
	t.ok(not db.unlocked_skill_ids(m.unlocked_flags()).has("heal"))
	m.ranks = {"unlock_bandit_camp": 1, "unlock_heal": 1, "unlock_smithy": 1}
	var cards := db.unlocked_card_ids(m.unlocked_flags())
	t.ok(cards.has("bandit_camp"))
	t.ok(cards.has("smithy"))
	t.ok(not cards.has("shrine"))
	t.ok(db.unlocked_skill_ids(m.unlocked_flags()).has("heal"))
	var run := H.new_run(31, m)
	run.debug_level_up()
	var seen_heal := false
	for i in 40:
		var offers := run.make_skill_offers()
		for o in offers:
			if o.id == "heal":
				seen_heal = true
	t.ok(seen_heal, "heal shows up in skill offers once unlocked")


func test_tree_utilities_change_the_run(t) -> void:
	var m := _meta()
	m.ranks = {"bigger_hand": 3, "sharp_eye": 1, "reroll": 2, "quick_start": 2, "more_goals": 2, "third_skill_slot": 1}
	var run := H.new_run(32, m)
	t.eq(run.hand_limit(), 10 + 3)
	t.eq(run.offer_count(), 4)
	t.eq(H.notices_of(run, "lap_card").size(), 2, "quick start: two extra card picks before the first step")
	t.eq(run.skill_slots(), 3)
	t.eq(run.hero.skills.size(), 3)
	t.eq(run.goals.list.size(), 3 + 2)
	var n: Notice = H.notices_of(run, "lap_card")[0]
	t.eq((n.payload["offers"] as Array).size(), 4)
	var before: Array = n.payload["offers"].duplicate()
	t.eq(run.rerolls_left, 2)
	t.ok(run.reroll_offers(n))
	t.eq(run.rerolls_left, 1)
	t.ok(run.reroll_offers(n))
	t.ok(not run.reroll_offers(n), "only two rerolls per lap")
	H.finish_lap(run)
	t.eq(run.rerolls_left, 2, "rerolls come back every lap")
	run.hand.append(CardInst.make_skill("fireball", 1))
	t.ok(run.check_skill_card(run.hand[-1], 2)["ok"], "the third slot takes a skill")
	t.ok(before.size() == 4)


func test_goals_pay_rp_once_even_if_the_run_is_lost(t) -> void:
	var m := _meta()
	var run := H.new_run(33, m)
	t.eq(run.goals.list.size(), 3)
	run.goals.list[0].id = "reach_level_7"
	run.goals.list[1].id = "kill_3_elites"
	run.goals.list[2].id = "reach_lap_8"
	for k in 7:
		run.debug_level_up()
	t.eq(run.hero.level, 8)
	t.eq(run.rp_earned, 1, "level 7 goal done")
	t.eq(m.rp, 1, "RP goes to the profile at once")
	var infos := H.notices_of(run, "info")
	t.eq(infos.size(), 1)
	t.ok(infos[0].expires > run.time, "the message vanishes by itself")
	run.debug_level_up()
	t.eq(run.rp_earned, 1, "a goal pays only once")
	run.elites_killed = 3
	run._check_goals()
	t.eq(m.rp, 2)
	# the hero dies: RP stays
	run._end_run(false)
	t.eq(m.rp, 2)
	t.eq(m.runs, 1)
	t.eq(m.wins, 0)


func test_boss_kill_pays_two_rp(t) -> void:
	var m := _meta()
	var run := H.new_run(34, m)
	run._end_run(true)
	t.eq(run.rp_earned, 2)
	t.eq(m.rp, 2)
	t.eq(m.wins, 1)
	var s := run.summary()
	t.eq(s["rp"], 2)
	t.eq((s["goals"] as Array).size(), 3)


func test_every_goal_condition_can_be_met(t) -> void:
	var run := H.new_run(35)
	var db := run.db
	for id in db.goal_order:
		t.ok(not RunGoals.met(run, id), "%s is not met at the start" % id)
	run.hero.level = 7
	run.top_tier = 2
	run.merged_tile_l3 = true
	run.merged_skill_l3 = true
	run.fights_won = 30
	run.combo_kinds = {"a": true, "b": true}
	run.laps_done = 8
	run.elites_killed = 3
	for slot in Item.SLOTS:
		var it := Item.new()
		it.slot = slot
		it.rarity = Item.Rarity.RARE
		run.equipment[slot] = it
	for k in 5:
		var cell := Vector2i(3 + k, 3)
		run.placed[cell] = CardInst.make("slime_nest")
	for id in db.goal_order:
		t.ok(RunGoals.met(run, id), "%s is met" % id)
		t.ok(RunGoals.progress(run, id) is String)

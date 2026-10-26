extends RefCounted
## The town (docs/design/03-town.md): groups, tiers, perks and the raids it draws.

const H := preload("res://tests/helpers.gd")


func test_tiers_follow_the_building_count(t) -> void:
	var run := H.new_run(2)
	t.eq(run.town.tier, 0)
	H.grow_houses(run, 2)
	t.eq(run.town.count, 2)
	t.eq(run.town.tier, 0, "2 buildings is not a village")
	t.eq(H.notices_of(run, "town_perk").size(), 0)
	var run2 := H.new_run(2)
	H.grow_houses(run2, 3)
	t.eq(run2.town.count, 3)
	t.eq(run2.town.tier, 1, "3 buildings: village")
	var perks := H.notices_of(run2, "town_perk")
	t.eq(perks.size(), 1, "reaching a tier offers one perk choice")
	t.eq((perks[0].payload["options"] as Array).size(), 3, "1 of 3")
	var run3 := H.new_run(2)
	H.grow_houses(run3, 6)
	t.eq(run3.town.tier, 2, "6 buildings: town")
	t.eq(H.notices_of(run3, "town_perk").size(), 2, "one perk per tier")


func test_house_levels_count_as_more_buildings(t) -> void:
	var run := H.new_run(3)
	H.grow_houses(run, 2, 2)  # two L2 houses = 4 buildings
	t.eq(run.town.count, 4)
	t.eq(run.town.tier, 1)
	var run2 := H.new_run(3)
	H.grow_houses(run2, 1, 3)
	t.eq(run2.town.count, 3, "one L3 house counts 3")
	t.eq(run2.town.tier, 1)


func test_only_the_largest_group_counts(t) -> void:
	var run := H.new_run(4)
	var big := H.grow_houses(run, 2)
	var far := H.first_roadside(run, big)
	t.ok(far.x >= 0, "a roadside cell away from the first group")
	var small := H.grow_houses(run, 2, 1, far)
	t.eq(small.size(), 2)
	t.eq(run.town.count, 2, "two groups of 2 are not a village of 4")
	t.eq(run.town.tier, 0)
	H.grow_houses(run, 1, 1, big[0])
	t.eq(run.town.count, 3, "a house next to the first group joins it")
	t.eq(run.town.tier, 1)


func test_perk_choice_applies_and_is_kept(t) -> void:
	var run := H.new_run(5)
	H.grow_houses(run, 3)
	var n: Notice = H.notices_of(run, "town_perk")[0]
	var first: String = n.payload["options"][0]
	t.ok(run.choose_perk(n, 0))
	t.eq(run.perk_for_tier[1], first)
	t.ok(run.perk_active(first))
	t.ok(not run.choose_perk(n, 0), "a notice can be used once")
	t.eq(H.notices_of(run, "town_perk").size(), 0)


func test_perks_stop_when_the_tier_drops(t) -> void:
	var run := H.new_run(6)
	var cells := H.grow_houses(run, 3)
	H.give_perk(run, 1, "school")
	t.ok(run.perk_active("school"))
	# a graveyard next to a house makes it a haunted village building: it stops counting
	var gy := CardInst.make("graveyard")
	var spot := Vector2i(-1, -1)
	for c in run.board.path.slice(1):
		for nb in run.board.neighbors8(c):
			if cells.has(nb) and not run.placed.has(c):
				spot = c
				break
		if spot.x >= 0:
			break
	t.ok(spot.x >= 0, "a road cell next to the town")
	t.ok(H.play(run, gy, spot))
	t.ok(run.town.count < 3, "haunted village lowers the count")
	t.eq(run.town.tier, 0)
	t.ok(not run.perk_active("school"), "perk of a lost tier stops")
	t.eq(run.top_tier, 1)
	# clearing the graveyard restores it; the perk is back without choosing again
	run.hand.append(CardInst.make("clear"))
	var ok := run.play_card(run.hand.size() - 1, spot)
	if ok:
		t.eq(run.town.tier, 1)
		t.ok(run.perk_active("school"))
		t.eq(H.notices_of(run, "town_perk").size(), 1, "no second choice for a tier already reached")


func test_market_adds_a_lap_card_pick(t) -> void:
	var run := H.new_run(7)
	H.grow_houses(run, 3)
	H.give_perk(run, 1, "market")
	H.finish_lap(run)
	t.eq(H.notices_of(run, "lap_card").size(), run.db.ci("lap_card_picks") + 1)


func test_shop_offers_two_items_each_lap(t) -> void:
	var run := H.new_run(8)
	H.grow_houses(run, 3)
	H.give_perk(run, 1, "shop")
	H.finish_lap(run)
	var shops := H.notices_of(run, "shop")
	t.eq(shops.size(), 1)
	t.eq((shops[0].payload["items"] as Array).size(), 2)
	t.eq((shops[0].payload["items"][0] as Item).level, run.lap, "items at the level of the new lap")
	t.ok(run.buy_ware(shops[0], 1))
	t.eq(H.notices_of(run, "item").size(), 1, "the ware becomes a normal item notice")


func test_school_training_yard_bell_tower_library(t) -> void:
	var run := H.new_run(9)
	H.grow_houses(run, 3)
	H.give_perk(run, 1, "school")
	run._kill_xp(10)
	t.eq(run.hero.xp, 11, "10 x 1.15 = 11.5 -> 11, the half carries over")
	run._kill_xp(10)
	t.eq(run.hero.level, 2, "the carried half is not lost: 11 + 12 = 23 XP")
	t.eq(run.hero.xp, 3)
	var run2 := H.new_run(9)
	H.grow_houses(run2, 3)
	var yard: Notice = H.notices_of(run2, "town_perk")[0]
	yard.payload["options"][0] = "training_yard"
	var before := run2.hero.unspent
	run2.choose_perk(yard, 0)
	t.eq(run2.hero.unspent, before + 3, "training yard: +3 stat points at once")
	t.eq(H.notices_of(run2, "stat").size(), 1)
	var run3 := H.new_run(9)
	H.grow_houses(run3, 3)
	var limit := run3.hand_limit()
	H.give_perk(run3, 1, "bell_tower")
	t.eq(run3.hand_limit(), limit + 2)
	var run4 := H.new_run(9)
	H.grow_houses(run4, 3)
	t.eq(run4.make_skill_offers().size(), 2, "only 2 skills are unlocked at the start")
	H.give_perk(run4, 1, "library")
	t.eq(run4.make_skill_offers().size(), 2, "library offers up to 4 of what is unlocked")


func test_carpenter_starts_new_houses_at_level_two(t) -> void:
	var run := H.new_run(10)
	var cells := H.grow_houses(run, 3)
	H.give_perk(run, 1, "carpenter")
	var spot := Vector2i(-1, -1)
	for c in cells:
		for nb in run.board.neighbors4(c):
			if not run.placed.has(nb) and run.check_card(CardInst.make("house"), nb)["ok"]:
				spot = nb
	t.ok(spot.x >= 0)
	t.ok(H.play(run, CardInst.make("house"), spot))
	t.eq(run.placed[spot].level, 2, "a house next to the town starts at L2")
	var far := H.first_roadside(run, cells)
	t.ok(H.play(run, CardInst.make("house"), far))
	t.eq(run.placed[far].level, 1, "away from the town it stays L1")


func test_field_hospital_and_guard_post(t) -> void:
	var run := H.new_run(11)
	var cells := H.grow_houses(run, 3)
	H.give_perk(run, 1, "field_hospital")
	# find a road index touching the town
	var idx := -1
	for i in range(1, run.board.path.size()):
		if run.town.touches(run.board.path[i]):
			idx = i
			break
	t.ok(idx > 0, "a road cell touches the town")
	run.hero.hp = 50.0
	var before := run.hero.hp
	run._pass_effects(idx)
	t.ok(run.hero.hp >= before + run.hero.max_hp * 0.1 - 0.01, "field hospital heals 10% max HP")
	# guard post: enemies near the town have less HP
	var run2 := H.new_run(11)
	H.grow_houses(run2, 3)
	H.give_perk(run2, 1, "guard_post")
	var near := -1
	for i in range(1, run2.board.path.size()):
		if run2.town.within(run2.board.path[i], 2):
			near = i
			break
	var sp := RunState.Spawn.new()
	sp.index = near
	sp.enemy_id = "slime"
	sp.count = 1
	run2._start_battle(sp)
	var foe: Foe = run2.battle.foes[0]
	t.near(foe.max_hp, run2.db.enemies["slime"].hp * 0.8, 0.01, "-20% HP near the town")


func test_town_draws_raids_every_lap(t) -> void:
	var run := H.new_run(12)
	H.grow_houses(run, 3)
	H.finish_lap(run)
	var raids := 0
	for i in run.spawns:
		if run.spawns[i].source == "raid":
			raids += 1
			t.eq(run.spawns[i].enemy_id, "bandit")
			t.eq(run.spawns[i].count, run.db.ci("raid_group_size"))
	t.eq(raids, 1, "one raid group per tier at tier 1")
	var run2 := H.new_run(12)
	H.grow_houses(run2, 6)
	H.finish_lap(run2)
	var raids2 := 0
	for i in run2.spawns:
		if run2.spawns[i].source == "raid":
			raids2 += 1
	t.eq(raids2, 2, "two groups at tier 2")
	var run3 := H.new_run(12)
	H.grow_houses(run3, 2)
	H.finish_lap(run3)
	for i in run3.spawns:
		t.ok(run3.spawns[i].source != "raid", "no raid without a village")

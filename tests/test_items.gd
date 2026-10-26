extends RefCounted
## Items, skill cards and the "?" events (docs/design/05-items-events.md, 04-hero-combat.md).

const H := preload("res://tests/helpers.gd")


func _rng(s: int = 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func test_item_main_stats_follow_the_spec(t) -> void:
	var db := GameDb.load_default()
	var rng := _rng()
	for lv in [1, 5, 10]:
		var w := Item.roll(db, rng, lv, 0.0, 0.0, "weapon")
		var mult: float = [1.0, 1.3, 1.6][w.rarity]
		t.near(w.stats["atk"], roundf((3 + 2 * lv) * mult), 0.01, "weapon ATK = (3 + 2 lv) x rarity")
		var a := Item.roll(db, rng, lv, 0.0, 0.0, "armor")
		mult = [1.0, 1.3, 1.6][a.rarity]
		t.near(a.stats["max_hp"], roundf((15 + 10 * lv) * mult), 0.01, "armor max HP = (15 + 10 lv) x rarity")
	var seen := {}
	for i in 200:
		var tr := Item.roll(db, rng, 4, 0.0, 0.0, "trinket")
		seen[tr.main] = true
		t.ok(tr.stats.has(tr.main))
	t.eq(seen.size(), 3, "a trinket's main stat is AP, crit or luck")


func test_rarity_decides_the_number_of_extra_stats(t) -> void:
	var db := GameDb.load_default()
	var rng := _rng(3)
	for i in 300:
		var it := Item.roll(db, rng, 6)
		t.eq(it.stats.size(), 1 + int(it.rarity), "common 0, rare 1, epic 2 extra stats")
		t.eq(Item.roll(db, rng, 6, 0.0, 0.0, "", Item.Rarity.RARE).rarity >= Item.Rarity.RARE, true)


func test_luck_and_smithy_move_the_odds(t) -> void:
	var db := GameDb.load_default()
	var share := func(luck: float, bonus: float) -> float:
		var rng := _rng(9)
		var rare := 0
		for i in 4000:
			if Item.roll_rarity(db, rng, luck, bonus) >= Item.Rarity.RARE:
				rare += 1
		return rare / 4000.0
	var base: float = share.call(0.0, 0.0)
	t.near(base, 0.30, 0.03, "25% rare + 5% epic")
	t.near(share.call(20.0, 0.0), 0.30 + 0.2 + 0.04, 0.03, "20 luck: +20% rare, +4% epic")
	t.near(share.call(0.0, 0.3), 0.60, 0.03, "smithy L3: +30% rare")


func test_wearing_items_changes_the_hero(t) -> void:
	var run := H.new_run(21)
	var atk := run.hero.atk
	var db := run.db
	var sword := Item.roll(db, _rng(), 4, 0.0, 0.0, "weapon")
	run.offer_item(sword)
	var n := H.notices_of(run, "item")[0]
	t.ok(run.equip_item(n))
	t.near(run.hero.atk, atk + sword.stats["atk"], 0.01)
	t.eq(run.equipment["weapon"], sword)
	t.ok(not run.equip_item(n), "a used notice does nothing")
	var better := Item.roll(db, _rng(2), 9, 0.0, 0.0, "weapon")
	run.offer_item(better)
	run.equip_item(H.notices_of(run, "item")[0])
	t.near(run.hero.atk, atk + better.stats["atk"], 0.01, "the old weapon is replaced, not added")
	var armor := Item.roll(db, _rng(5), 3, 0.0, 0.0, "armor")
	run.offer_item(armor)
	var hp := run.hero.max_hp
	run.discard_item(H.notices_of(run, "item")[0])
	t.eq(run.hero.max_hp, hp, "discarding changes nothing")


func test_auto_equip_only_takes_better_items(t) -> void:
	var run := H.new_run(22)
	run.auto_equip = true
	var db := run.db
	var low := Item.roll(db, _rng(), 2, 0.0, 0.0, "armor")
	low.rarity = Item.Rarity.COMMON
	run.offer_item(low)
	t.eq(run.equipment["armor"], low, "an empty slot takes anything")
	t.eq(H.notices_of(run, "item").size(), 0)
	var worse := Item.roll(db, _rng(2), 1, 0.0, 0.0, "armor")
	worse.rarity = Item.Rarity.COMMON
	run.offer_item(worse)
	t.eq(run.equipment["armor"], low, "a worse item is left in the list")
	t.eq(H.notices_of(run, "item").size(), 1)


func test_item_list_keeps_five_and_pays_xp_for_the_overflow(t) -> void:
	var run := H.new_run(23)
	var first: Item = null
	for i in 6:
		var it := Item.roll(run.db, _rng(i + 1), 4, 0.0, 0.0, "weapon")
		if first == null:
			first = it
		run.offer_item(it)
	t.eq(H.notices_of(run, "item").size(), 5)
	t.ok(run.hero.xp >= 12 or run.hero.level > 1, "the oldest item turned into 3 x level XP")


func test_elites_always_drop(t) -> void:
	var run := H.new_run(24)
	var def: GameDb.EnemyDef = run.db.enemies["slime"]
	var sp := RunState.Spawn.new()
	sp.index = 3
	sp.enemy_id = "slime"
	sp.count = 1
	sp.elite = 1
	run._start_battle(sp)
	run._fight_spawn = sp
	var f := Foe.make(run.db, def, 1, true, 1.0, _rng())
	var before := H.notices_of(run, "item").size()
	run._roll_drops(f)
	t.eq(H.notices_of(run, "item").size(), before + 1, "elite drops an item every time")


func test_level_up_offers_a_skill_card(t) -> void:
	var run := H.new_run(25)
	run.debug_level_up()
	var cards := H.notices_of(run, "skill_card")
	t.eq(cards.size(), 1)
	var offers: Array = cards[0].payload["offers"]
	t.ok(offers.size() >= 1)
	for o in offers:
		t.ok((o as CardInst).skill)
	var hand := run.hand.size()
	t.ok(run.choose_skill_offer(cards[0], 0))
	t.eq(run.hand.size(), hand + 1)
	t.ok(run.hand[-1].skill)


func test_skill_cards_equip_merge_and_swap(t) -> void:
	var run := H.new_run(26)
	var fb: Dictionary = run.hero.skills[0]
	t.eq(fb["id"], "fireball")
	# same skill, same level: merge to L2 then L3
	run.hand.append(CardInst.make_skill("fireball", 1))
	var chk := run.check_skill_card(run.hand[-1], 0)
	t.ok(chk["ok"])
	t.eq(chk["action"], "merge")
	t.ok(run.play_skill_card(run.hand.size() - 1, 0))
	t.eq(run.hero.skills[0]["level"], 2)
	run.hand.append(CardInst.make_skill("fireball", 1))
	t.ok(not run.check_skill_card(run.hand[-1], 0)["ok"], "levels must match")
	run.hand.pop_back()
	run.hand.append(CardInst.make_skill("fireball", 2))
	t.ok(run.play_skill_card(run.hand.size() - 1, 0))
	t.eq(run.hero.skills[0]["level"], 3)
	t.ok(run.merged_skill_l3)
	run.hand.append(CardInst.make_skill("fireball", 3))
	t.ok(not run.check_skill_card(run.hand[-1], 0)["ok"], "L3 is the top")
	run.hand.pop_back()
	# another skill: swap, the old one returns to the hand
	run.hand.append(CardInst.make_skill("cleave", 2))
	var n := run.hand.size()
	t.eq(run.check_skill_card(run.hand[-1], 0)["action"], "swap")
	t.ok(run.play_skill_card(n - 1, 0))
	t.eq(run.hero.skills[0]["id"], "cleave")
	t.eq(run.hero.skills[0]["level"], 2)
	t.eq(run.hand[-1].id, "fireball", "the replaced skill goes back to the hand")
	t.eq(run.hand[-1].level, 3)
	t.ok(not run.check_skill_card(CardInst.make_skill("heal"), 2)["ok"], "no third slot yet")
	t.ok(not run.check_card(CardInst.make_skill("heal"), Vector2i(3, 3))["ok"], "skill cards do not go on the map")


func test_events(t) -> void:
	var run := H.new_run(27)
	var db := run.db
	var mk := func(id: String) -> Notice:
		return run._add_notice("event", db.events[id].name_th, "", {"event": id})
	# old shrine: pay 20% of current HP for a rare item
	run.hero.hp = 80.0
	var n: Notice = mk.call("shrine")
	t.ok(run.resolve_event(n, 0))
	t.near(run.hero.hp, 64.0, 0.01)
	var items := H.notices_of(run, "item")
	t.eq(items.size(), 1)
	t.ok((items[0].payload["item"] as Item).rarity >= Item.Rarity.RARE)
	# the value is taken when chosen: HP changed while it waited
	n = mk.call("shrine")
	run.hero.hp = 10.0
	t.ok(run.resolve_event(n, 0))
	t.near(run.hero.hp, 8.0, 0.01)
	n = mk.call("shrine")
	run.hero.hp = 1.0
	t.ok(run.resolve_event(n, 0))
	t.near(run.hero.hp, 1.0, 0.001, "HP payments never kill")
	# walk past: nothing happens
	n = mk.call("shrine")
	var hp := run.hero.hp
	t.ok(run.resolve_event(n, 1))
	t.eq(run.hero.hp, hp)
	# wandering merchant: two hand cards for an item
	n = mk.call("merchant")
	var hand := run.hand.size()
	t.ok(not run.resolve_event(n, 0, {"cards": [0]}), "needs exactly 2 cards")
	t.ok(not run.resolve_event(n, 0, {"cards": [0, 0]}), "two different cards")
	t.eq(run.hand.size(), hand)
	var items_before := H.notices_of(run, "item").size()
	t.ok(run.resolve_event(n, 0, {"cards": [0, 2]}))
	t.eq(run.hand.size(), hand - 2)
	t.eq(H.notices_of(run, "item").size(), items_before + 1)
	# wounded traveller: 15% max HP for an L2 house
	n = mk.call("traveler")
	run.hero.hp = run.hero.max_hp
	hand = run.hand.size()
	t.ok(run.resolve_event(n, 0))
	t.near(run.hero.hp, run.hero.max_hp * 0.85, 0.01)
	t.eq(run.hand[-1].id, "house")
	t.eq(run.hand[-1].level, 2)
	# mysterious fountain: either outcome is one of the two
	var wins := 0
	for i in 40:
		var r := H.new_run(100 + i)
		r.hero.hp = 50.0
		var fn := r._add_notice("event", "", "", {"event": "fountain"})
		var pts := r.hero.unspent
		r.resolve_event(fn, 0)
		if r.hero.unspent == pts + 3:
			wins += 1
		else:
			t.near(r.hero.hp, 45.0, 0.01)
	t.ok(wins > 8 and wins < 32, "about half the drinks give stat points (%d/40)" % wins)
	# deserter: a duel against one elite bandit; winning gives a skill card choice
	var r2 := H.new_run(28)
	var dn := r2._add_notice("event", "", "", {"event": "deserter"})
	t.ok(r2.resolve_event(dn, 0))
	t.eq(r2.phase, RunState.Phase.FIGHTING)
	t.eq(r2.battle.foes.size(), 1)
	t.ok(r2.battle.foes[0].elite)
	r2.hero.hp = r2.hero.max_hp
	r2.hero.atk = 500.0
	var t_end := 0.0
	while r2.phase == RunState.Phase.FIGHTING and t_end < 120.0:
		r2.advance(0.25)
		t_end += 0.25
	t.eq(r2.won, false)
	t.ok(H.notices_of(r2, "skill_card").size() >= 1, "duel won: skill card")
	var dn2 := r2._add_notice("event", "", "", {"event": "deserter"})
	r2.phase = RunState.Phase.FIGHTING
	t.ok(not RunEvents.options(r2, dn2)[0]["enabled"], "no duel while already fighting")
	r2.phase = RunState.Phase.WALKING


func test_event_cell_blocks_encounters_and_opens_when_passed(t) -> void:
	var run := H.new_run(29)
	run.event_cells[4] = "fountain"
	var enc := CardInst.make("slime_nest")
	t.ok(not run.check_card(enc, run.board.path[4])["ok"], "a ? cell cannot take an encounter card")
	run.tile_index = 3
	run.tile_progress = 0.99
	run.advance(0.2)
	t.eq(run.tile_index, 4)
	t.ok(not run.event_cells.has(4))
	t.eq(H.notices_of(run, "event").size(), 1, "passing the cell opens the event")
	t.eq(run.phase, RunState.Phase.WALKING, "the hero keeps walking")

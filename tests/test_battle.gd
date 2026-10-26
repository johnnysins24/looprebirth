extends RefCounted
## Hero stats, XP, and the battle engine against the numbers in docs/design/04-hero-combat.md.


func _hero(db: GameDb) -> Hero:
	return Hero.new(db)


func test_base_stats(t) -> void:
	var db := GameDb.load_default()
	var h := _hero(db)
	t.near(h.max_hp, 100.0, 0.001)
	t.near(h.atk, 8.0, 0.001)
	t.near(h.aps, 0.8, 0.001)
	t.near(h.evasion, 0.05, 0.001)
	t.near(h.max_mana, 30.0, 0.001)
	t.near(h.mana_regen, 2.0, 0.001)
	t.near(h.crit, 0.0, 0.001)
	t.near(h.crit_damage, 1.5, 0.001)


func test_stat_points(t) -> void:
	var db := GameDb.load_default()
	var h := _hero(db)
	h.unspent = 6
	t.ok(h.spend("str"))
	t.near(h.atk, 9.0, 0.001, "STR +1 ATK")
	t.near(h.max_hp, 106.0, 0.001, "STR +6 HP")
	t.near(h.hp, 106.0, 0.001, "current HP follows max HP up")
	t.ok(h.spend("agi"))
	t.near(h.aps, 0.8 * 1.05, 0.0001, "AGI +5% attack speed")
	t.near(h.evasion, 0.062, 0.0001, "AGI +1.2% evasion")
	t.ok(h.spend("int"))
	t.near(h.ap, 2.0, 0.001)
	t.near(h.max_mana, 34.0, 0.001)
	t.near(h.mana_regen, 2.15, 0.001)
	t.eq(h.unspent, 3)
	h.unspent = 0
	t.ok(not h.spend("str"), "no points left")


func test_caps(t) -> void:
	var db := GameDb.load_default()
	var h := _hero(db)
	h.pts["agi"] = 500
	h.recalc()
	t.near(h.aps, 3.0, 0.0001, "attack speed cap")
	t.near(h.evasion, 0.6, 0.0001, "evasion cap")


func test_xp_and_levels(t) -> void:
	var db := GameDb.load_default()
	var h := _hero(db)
	t.eq(h.xp_needed(1), 20)
	t.eq(h.xp_needed(2), 35)
	t.eq(h.xp_needed(9), 140)
	t.eq(h.add_xp(19), 0)
	t.eq(h.add_xp(1), 1, "20 XP is level 2")
	t.eq(h.level, 2)
	t.eq(h.unspent, 3)
	t.eq(h.add_xp(35 + 50), 2, "two levels at once")
	t.eq(h.level, 4)
	t.eq(h.unspent, 9)
	# 720 XP in total is level 10 (04-hero-combat.md)
	var h2 := _hero(db)
	h2.add_xp(720)
	t.eq(h2.level, 10)


func test_foe_scaling(t) -> void:
	var db := GameDb.load_default()
	var rng := RandomNumberGenerator.new()
	var f1 := Foe.make(db, db.enemies["wolf"], 1, false, 1.0, rng)
	t.near(f1.max_hp, 26.0, 0.001)
	var f5 := Foe.make(db, db.enemies["wolf"], 5, false, 1.0, rng)
	t.near(f5.max_hp, 26.0 * 2.0, 0.001, "+25% HP per lap")
	t.near(f5.atk, 3.0 * 1.48, 0.001, "+12% ATK per lap")
	t.eq(f5.xp, roundi(7 * 1.4))
	var e := Foe.make(db, db.enemies["slime"], 1, true, 1.0, rng)
	t.near(e.max_hp, 36.0, 0.001)
	t.near(e.atk, 3.0, 0.001)
	t.eq(e.xp, 12, "elite gives x3 XP")
	t.near(e.drop_chance, 1.0, 0.001)
	var boss := Foe.make(db, db.enemies["boss_warden"], 10, false, 1.0, rng)
	t.near(boss.max_hp, 950.0, 0.001, "the boss does not scale")
	t.near(boss.slam_chance, 0.12, 0.0001)


func test_fight_is_deterministic(t) -> void:
	var db := GameDb.load_default()
	var out: Array[String] = []
	for k in 2:
		var h := _hero(db)
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		var foes: Array[Foe] = []
		for i in 3:
			foes.append(Foe.make(db, db.enemies["slime"], 1, false, 1.0, rng))
		h.equip_skill(0, "fireball", 1)
		var b := Battle.new(db, h, foes, rng)
		b.run_to_end()
		out.append("%s %.3f %.3f" % [b.hero_won, h.hp, b.time])
	t.eq(out[0], out[1])


func test_hero_beats_three_slimes_and_loses_to_nothing_yet(t) -> void:
	var db := GameDb.load_default()
	var h := _hero(db)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var foes: Array[Foe] = []
	for i in 3:
		foes.append(Foe.make(db, db.enemies["slime"], 1, false, 1.0, rng))
	var b := Battle.new(db, h, foes, rng)
	t.ok(b.run_to_end(), "a fresh hero wins against 3 slimes")
	t.eq(b.kills.size(), 3)
	t.ok(h.hp > 0.0 and h.hp < 100.0, "and takes some damage")
	t.ok(b.explain().size() >= 4, "the explanation has lines")


func test_explain_works_while_the_fight_is_still_running(t) -> void:
	# the log window (L) is allowed to open mid-fight
	var db := GameDb.load_default()
	var h := _hero(db)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var foes: Array[Foe] = [Foe.make(db, db.enemies["skeleton"], 1, false, 1.0, rng, 10.0)]
	var b := Battle.new(db, h, foes, rng)
	for i in 40:
		b.step(0.05)
	t.ok(not b.finished, "still fighting")
	var lines := b.explain()
	t.ok(lines.size() >= 4, "has lines")
	t.ok(lines[lines.size() - 1].begins_with("กำลังสู้อยู่"), "says it is still going: %s" % lines[lines.size() - 1])


func test_skills_fire_and_use_mana(t) -> void:
	var db := GameDb.load_default()
	var h := _hero(db)
	h.equip_skill(0, "fireball", 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var foes: Array[Foe] = []
	foes.append(Foe.make(db, db.enemies["skeleton"], 1, false, 1.0, rng, 10.0))  # a long fight
	var b := Battle.new(db, h, foes, rng)
	for i in 400:
		b.step(0.05)
	t.ok(int(b.stats["casts"].get("fireball", 0)) >= 2, "fireball is cast on mana: %s" % str(b.stats["casts"]))
	t.ok(b.stats["dmg_skill"] > 0.0)


func test_heal_only_below_half(t) -> void:
	var db := GameDb.load_default()
	var h := _hero(db)
	h.pts["int"] = 3  # heal costs 40 mana, more than the 30 a fresh hero can hold
	h.recalc()
	h.hp = h.max_hp
	h.equip_skill(0, "heal", 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var foes: Array[Foe] = []
	foes.append(Foe.make(db, db.enemies["skeleton"], 1, false, 1.0, rng, 20.0))
	var b := Battle.new(db, h, foes, rng)
	b.mana = 100.0
	b.step(0.05)
	t.eq(int(b.stats["casts"].get("heal", 0)), 0, "no heal at full HP")
	h.hp = 40.0
	b.mana = 100.0
	b.step(0.05)
	t.eq(int(b.stats["casts"].get("heal", 0)), 1, "heal below 50% HP")


func test_boss_has_slam(t) -> void:
	var db := GameDb.load_default()
	var h := _hero(db)
	h.pts["str"] = 40
	h.recalc()
	h.hp = h.max_hp
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var foes: Array[Foe] = [Foe.make(db, db.enemies["boss_warden"], 10, false, 1.0, rng)]
	var b := Battle.new(db, h, foes, rng)
	b.run_to_end()
	t.ok(b.stats["foe_attacks"] > 20)
	t.ok(b.stats["slams"] > 0, "12% of boss hits are slams")

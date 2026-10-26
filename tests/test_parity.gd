extends RefCounted
## The Godot battle engine must agree with tools/balance_sim.py (04-hero-combat.md says the
## two carry the same numbers). Expected values are the Python sim's output; the tolerance
## covers the random noise of ~100 fights per cell.

const BASE_COUNT := {"slime": 3, "wolf": 2, "skeleton": 2, "bandit": 2}
const LOADOUT := {
	"str": ["cleave", "haste"],
	"agi": ["cleave", "haste"],
	"int": ["mana_shield", "fireball"],
	"mix": ["fireball", "cleave"],
}


## A hero built the way balance_sim.make_hero does: all stat points of level `level` in one
## build, average gear for `lap`, skills by lap.
func _sim_hero(db: GameDb, build: String, level: int, lap: int) -> Hero:
	var h := Hero.new(db)
	var points := 3 * (level - 1)
	match build:
		"mix":
			h.pts = {"str": points / 3, "agi": points / 3, "int": points - 2 * (points / 3)}
		_:
			h.pts[build] = points
	var caster := build == "int" or build == "mix"
	var gear := {
		"atk": 3.0 + 2.0 * lap,
		"max_hp": 15.0 + 10.0 * lap,
		"crit": 0.05,
	}
	if caster:
		gear["ap"] = 2.0 + 2.0 * lap
	h.set_mods("gear", gear)
	h.hp = h.max_hp
	var levels := [1, 1]
	if lap >= 8:
		levels = [3, 2]
	elif lap >= 5:
		levels = [2, 1]
	for i in 2:
		h.equip_skill(i, LOADOUT[build][i], levels[i])
	return h


func _avg_hp_lost(db: GameDb, build: String, level: int, lap: int, enemy: String, elvl: int, runs: int) -> float:
	var total := 0.0
	for s in runs:
		var h := _sim_hero(db, build, level, lap)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7000 + s
		var foes: Array[Foe] = []
		for k in BASE_COUNT[enemy] + elvl - 1:
			foes.append(Foe.make(db, db.enemies[enemy], lap, false, 1.0, rng))
		var b := Battle.new(db, h, foes, rng)
		b.run_to_end()
		total += 1.0 - h.hp / h.max_hp
	return total / runs


func _boss_win_rate(db: GameDb, build: String, runs: int) -> float:
	var wins := 0
	for s in runs:
		var h := _sim_hero(db, build, 10, 10)
		h.hp = 0.8 * h.max_hp
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + s
		var foes: Array[Foe] = [Foe.make(db, db.enemies["boss_warden"], 10, false, 1.0, rng)]
		var b := Battle.new(db, h, foes, rng)
		if b.run_to_end():
			wins += 1
	return float(wins) / runs


func test_hp_lost_matches_python_sim(t) -> void:
	var db := GameDb.load_default()
	# [build, level, lap, enemy, encounter level, expected % from balance_sim.py]
	var cells := [
		["str", 1, 1, "slime", 1, 13.6],
		["str", 1, 1, "bandit", 1, 38.6],
		["int", 1, 1, "skeleton", 1, 33.1],
		["str", 5, 5, "slime", 1, 9.4],
		["agi", 5, 5, "wolf", 1, 20.5],
		["mix", 5, 5, "skeleton", 1, 20.8],
		["int", 5, 5, "bandit", 1, 31.4],
		["str", 10, 10, "wolf", 3, 30.8],
		["int", 10, 10, "bandit", 3, 72.0],
		["mix", 10, 10, "skeleton", 3, 29.6],
	]
	for c in cells:
		var got := _avg_hp_lost(db, c[0], c[1], c[2], c[3], c[4], 100) * 100.0
		print("    %-4s L%-2d lap%-2d %-8s enc L%d: godot %5.1f%%  python %5.1f%%" % [c[0], c[1], c[2], c[3], c[4], got, c[5]])
		t.near(got, c[5], 4.0, "%s L%d %s enc L%d" % [c[0], c[1], c[3], c[4]])


func test_boss_win_rate_matches_python_sim(t) -> void:
	var db := GameDb.load_default()
	var expected := {"str": 71.0, "agi": 48.0, "int": 46.0, "mix": 28.0}
	for build in expected:
		var got := _boss_win_rate(db, build, 150) * 100.0
		print("    boss %-4s godot %5.1f%%  python %5.1f%%" % [build, got, expected[build]])
		t.near(got, expected[build], 12.0, "boss win rate %s" % build)

class_name RunGoals
extends RefCounted
## The goals picked for one run (docs/design/06-meta.md). Each is worth Rebirth points the
## moment it is met, and stays met even if the run ends badly (assumption, see the doc).


class Goal:
	extends RefCounted
	var id := ""
	var text := ""
	var rp := 1
	var done := false


var list: Array[Goal] = []


static func pick(db: GameDb, rng: RandomNumberGenerator, count: int) -> RunGoals:
	var g := RunGoals.new()
	var pool: Array[String] = []
	pool.assign(db.goal_order)
	for k in mini(count, pool.size()):
		var def: GameDb.GoalDef = db.goals[pool.pop_at(rng.randi() % pool.size())]
		var goal := Goal.new()
		goal.id = def.id
		goal.text = def.goal_th
		goal.rp = def.rp
		g.list.append(goal)
	return g


## Marks goals that are met now and returns the ones that just became met.
func check(run: RunState) -> Array[Goal]:
	var out: Array[Goal] = []
	for goal in list:
		if not goal.done and met(run, goal.id):
			goal.done = true
			out.append(goal)
	return out


static func met(run: RunState, id: String) -> bool:
	match id:
		"reach_level_7":
			return run.hero.level >= 7
		"build_village":
			return run.top_tier >= 1
		"build_town":
			return run.top_tier >= 2
		"merge_l3":
			return run.merged_tile_l3
		"skill_l3":
			return run.merged_skill_l3
		"win_30_fights":
			return run.fights_won >= 30
		"five_encounters":
			return run.encounter_count() >= 5
		"three_rare_items":
			return run.rare_slots() >= Item.SLOTS.size()
		"two_combos":
			return run.combo_kinds.size() >= 2
		"reach_lap_8":
			return run.laps_done >= 8
		"kill_3_elites":
			return run.elites_killed >= 3
	return false


## "3/7" style progress for goals that count something, "" for the rest.
static func progress(run: RunState, id: String) -> String:
	match id:
		"reach_level_7":
			return "%d/7" % mini(run.hero.level, 7)
		"win_30_fights":
			return "%d/30" % mini(run.fights_won, 30)
		"five_encounters":
			return "%d/5" % mini(run.encounter_count(), 5)
		"three_rare_items":
			return "%d/3" % run.rare_slots()
		"two_combos":
			return "%d/2" % mini(run.combo_kinds.size(), 2)
		"reach_lap_8":
			return "%d/8" % mini(run.laps_done, 8)
		"kill_3_elites":
			return "%d/3" % mini(run.elites_killed, 3)
	return ""

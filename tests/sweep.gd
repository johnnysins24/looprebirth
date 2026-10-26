extends SceneTree
## Balance sweep: plays bot runs and prints how far each build gets.
##
##   godot --headless --path . --script tests/sweep.gd -- [runs] [build ...]
##
## Not a test (no test_ prefix); use it to see how a tuning change moves the win rate.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 20
	var builds: Array = args.slice(1) if args.size() > 1 else ["str", "agi", "int", "mix"]
	var db := GameDb.load_default()
	for build in builds:
		var wins := 0
		var laps := []
		var causes := {}
		var total_time := 0.0
		for s in runs:
			var run := RunState.new(db, 1000 + s)
			var bot := Bot.new(run, build, s)
			var t := 0.0
			while run.phase != RunState.Phase.ENDED and t < 4000.0:
				run.advance(0.25)
				t += 0.25
				bot.act()
			if run.won:
				wins += 1
			else:
				laps.append(run.lap)
				var key: String = run.last_fight.get("spawn", "?")
				causes[key] = int(causes.get(key, 0)) + 1
			total_time += run.time
		print(
			"%-4s wins %2d/%d  avg run %.0fs  deaths by lap %s  killed by %s"
			% [build, wins, runs, total_time / runs, str(laps), str(causes)]
		)
	quit()

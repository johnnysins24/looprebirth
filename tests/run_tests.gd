extends SceneTree
## Headless test runner.
##
##   godot --headless --path . --import          (once, builds the class cache)
##   godot --headless --path . --script tests/run_tests.gd
##   godot --headless --path . --script tests/run_tests.gd -- loop     (only suites matching "loop")
##
## Every tests/test_*.gd is a suite; every method named test_* in it runs. Exit code 1
## when anything fails.

const Ctx := preload("res://tests/ctx.gd")


func _init() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var ctx := Ctx.new()
	var suites := 0
	var tests := 0
	var started := Time.get_ticks_msec()
	for path in _suite_paths():
		if filter != "" and not path.contains(filter):
			continue
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			ctx.failures.append("%s: script does not compile" % path)
			continue
		var suite = script.new()
		suites += 1
		for m in suite.get_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			ctx.current = "%s::%s" % [path.get_file().trim_suffix(".gd"), name]
			var before := ctx.failures.size()
			suite.call(name, ctx)
			tests += 1
			print("%s  %s" % ["ok  " if ctx.failures.size() == before else "FAIL", ctx.current])
	print("")
	print(
		"%d suites, %d tests, %d checks, %d failures (%d ms)"
		% [suites, tests, ctx.checks, ctx.failures.size(), Time.get_ticks_msec() - started]
	)
	for f in ctx.failures:
		print("  FAIL ", f)
	quit(1 if not ctx.failures.is_empty() else 0)


func _suite_paths() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open("res://tests")
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append("res://tests/" + f)
	out.sort()
	return out

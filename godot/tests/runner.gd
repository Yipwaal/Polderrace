extends Node
## Test runner: godot --path godot res://tests/runner.tscn -- <test> [<test> ...]
## Each test is res://tests/test_<name>.gd with `func run(node: Node) -> TestReport` (may await).
## A script that does not compile counts as FOUT; a watchdog ends a run that hangs (exit code 1).

const WATCHDOG_S := 1500.0

func _ready() -> void:
	get_tree().create_timer(WATCHDOG_S, true, false, true).timeout.connect(func():
		print("FOUT watchdog: tests liepen langer dan ", WATCHDOG_S, " s")
		get_tree().quit(1))
	var names := OS.get_cmdline_user_args()
	var failed := 0
	for n in names:
		var path := "res://tests/test_%s.gd" % n
		if not ResourceLoader.exists(path):
			print("FOUT test bestaat niet: ", path)
			failed += 1
			continue
		var sc: GDScript = load(path)
		if sc == null or not sc.can_instantiate():
			print("FOUT test compileert niet: ", path)
			failed += 1
			continue
		# every test plays on a fresh save file of its own, never the player's: a garage that owns every car (stock), like
		# the HTML tests (tests/lib.py), since you only race cars you own
		var owned := {}
		for id in Cars.CARS: owned[id] = true
		G.use_store("user://test-%s.json" % n, {"polderrace3d-garage": {"owned": owned}})
		var t = sc.new()
		var rep: TestReport = await t.run(self)
		rep.finish()
		if not rep.bad.is_empty():
			failed += 1
	get_tree().quit(1 if failed else 0)

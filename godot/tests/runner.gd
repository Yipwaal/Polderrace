extends Node
## Test runner: godot --path godot res://tests/runner.tscn -- <test> [<test> ...]
## Each test is res://tests/test_<name>.gd with `func run(tree: SceneTree) -> TestReport` (may await).

func _ready() -> void:
	var names := OS.get_cmdline_user_args()
	var failed := 0
	for n in names:
		var path := "res://tests/test_%s.gd" % n
		if not ResourceLoader.exists(path):
			print("FOUT test bestaat niet: ", path)
			failed += 1
			continue
		var t = load(path).new()
		var rep: TestReport = await t.run(self)
		rep.finish()
		if not rep.bad.is_empty():
			failed += 1
	get_tree().quit(1 if failed else 0)

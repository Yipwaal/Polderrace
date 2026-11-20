class_name TestReport
## OK/FOUT lines like the HTML test suite. Exit code 1 when anything failed (see runner.gd).

var title := ""
var ok := 0
var bad: Array[String] = []

func _init(t: String) -> void:
	title = t
	print("== ", t)

func check(cond: bool, label: String, detail: String = "") -> bool:
	if cond:
		ok += 1
		print("OK   ", label, ("  " + detail) if detail != "" else "")
	else:
		bad.append(label)
		print("FOUT ", label, ("  " + detail) if detail != "" else "")
	return cond

func finish() -> void:
	var n := ok + bad.size()
	var tail := "" if bad.is_empty() else "  | mislukt: " + ", ".join(bad.slice(0, 10))
	print("-- ", title, ": ", ok, "/", n, " geslaagd", tail)

# ------------------------------------------------------------------ golden data (tests/golden/*.json)
## Since phase 2 (see PLAN.md) the Godot version leads: the golden files hold the *approved state of the Godot game*
## (they started as exports from the HTML version). A deliberate change to cars, tracks or handling is recorded with
##   python godot/tests/run.py --update cars        (or build, laps; TRACKS=polder / CARS=gt narrow it down)
## after looking at the result (screenshots!); the diff of the golden file then shows in the commit what changed.
static func updating() -> bool:
	return OS.get_environment("GOLDEN_UPDATE") == "1"

static func load_golden(name: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/%s.json" % name))
	return d if d is Dictionary else {}

static func save_golden(name: String, data: Dictionary) -> void:
	var f := FileAccess.open(ProjectSettings.globalize_path("res://tests/golden/%s.json" % name), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	print("--   golden/%s.json bijgewerkt (%d items)" % [name, data.size()])

static func r3(v: float) -> float:
	return snappedf(v, 0.001)

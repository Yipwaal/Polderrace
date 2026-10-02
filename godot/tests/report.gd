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

extends RefCounted
## computeTrack against the HTML game's own numbers (tests/golden/tracks.json, made by tools/export_golden.py)

func run(_node: Node) -> TestReport:
	var rep := TestReport.new("baanberekening gelijk aan de HTML-versie")
	var gold: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/tracks.json"))
	for key in gold:
		var g: Dictionary = gold[key]
		var parts: PackedStringArray = key.split("/")
		Trk.compute_track(parts[0], parts[1])
		var worst := 0.0
		var what := ""
		for row in g.S:
			var i := int(row[0])
			var mine := [Trk.P[i].x, Trk.P[i].y, Trk.P[i].z, Trk.T[i].x, Trk.T[i].z, Trk.R[i].x, Trk.R[i].z, Trk.HT[i], Trk.EMB[i], Trk.EDGE[i], Trk.CURV[i], Trk.LINE[i]]
			for k in mine.size():
				var d := absf(float(mine[k]) - float(row[k + 1]))
				if d > worst:
					worst = d; what = "sample %d veld %d: %f vs %f" % [i, k, mine[k], row[k + 1]]
		var same_cps: bool = Trk.cps == Array(g.cps).map(func(v): return int(v))
		rep.check(Trk.NS == int(g.NS) and absf(Trk.TRACK_LEN - float(g.LEN)) < 1e-6 and same_cps and worst < 0.01, key,
			"NS %d/%d, lengte %.4f/%.4f, cps %s, grootste afwijking %.6f %s" % [Trk.NS, g.NS, Trk.TRACK_LEN, g.LEN, same_cps, worst, what])
	return rep

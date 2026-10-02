extends RefCounted
## Builds every ported track (fwd and rev) and compares with the HTML game's own build (tests/golden/build.json,
## made by tools/export_build.py): the number of seeded rnd() calls per stage, every inst() call (count, first and
## last position) and the number of meshes. Equal numbers = the decor is the same as in the HTML version.

func _count_meshes(n: Node) -> int:
	var c := 0
	for ch in n.get_children():
		if ch is MeshInstance3D: c += 1
		c += _count_meshes(ch)
	return c

func run(host: Node) -> TestReport:
	var r := TestReport.new("banen bouwen zoals de HTML-versie")
	var gold: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/build.json"))
	World.root = Node3D.new()
	host.add_child(World.root)
	var only := OS.get_environment("TRACKS")
	for id in TrackLoader.ported():
		if only != "" and not id in only.split(","): continue
		for dir in ["fwd", "rev"]:
			var g: Dictionary = gold["%s/%s" % [id, dir]]
			var t0 := Time.get_ticks_msec()
			World.inst_log = []
			var counts := TrackLoader.build_world(id, dir)
			var ms := Time.get_ticks_msec() - t0
			for st in ["build", "details", "veluwe", "dress"]:
				r.check(int(counts[st]) == int(g.rnd[st]), "%s %s: rnd-aanroepen in %s" % [id, dir, st], "godot %d, html %d" % [counts[st], g.rnd[st]])
			var log: Array = World.inst_log
			var gi: Array = g.inst
			var bad := ""
			for k in maxi(log.size(), gi.size()):
				if k >= log.size() or k >= gi.size():
					bad = "inst-aanroep %d ontbreekt (godot %d, html %d)" % [k, log.size(), gi.size()]; break
				var a: Array = log[k]
				var b: Array = gi[k]
				var p0 := Vector3(b[1], b[2], b[3]); var p1 := Vector3(b[4], b[5], b[6])
				if int(a[0]) != int(b[0]) or a[1].distance_to(p0) > 0.01 or a[2].distance_to(p1) > 0.01:
					bad = "inst-aanroep %d: godot %d stuks %s..%s, html %d stuks %s..%s" % [k, a[0], a[1], a[2], b[0], p0, p1]; break
			r.check(bad == "", "%s %s: alle inst()-objecten op dezelfde plek" % [id, dir], bad if bad != "" else "%d aanroepen" % gi.size())
			var nm := _count_meshes(World.root)
			r.check(nm == int(g.meshes), "%s %s: aantal meshes" % [id, dir], "godot %d, html %d (%d ms)" % [nm, g.meshes, ms])
			World.inst_log = null
	return r

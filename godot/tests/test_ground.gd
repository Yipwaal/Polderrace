extends RefCounted
## Floating and buried decor. Every track, forwards and reversed (TRACKS=polder,dorp narrows it).
##
## zwevend   Everything in the world should stand on something. Objects that touch each other (their boxes, 6 cm slack)
##           form a group; a group is fine when one of its parts reaches the ground: the land (y = 0, or the terrain of
##           Veluwe / Limburg), the road and its dike, or one of the long strips and planes of the track (quays, water,
##           bridge decks). A group that reaches none of them hangs in the air: a lamp without a post, a roof beside its
##           house, a tree crown beside its trunk, a sign above the water.
## begraven  On the terrain tracks: an object whose top lies under the terrain (nobody sees it) or that stands for more
##           than half its height (and more than 1.5 m) in the hill.
## A finding gives the lowest part of the group (shape, size, colour), how many such groups, how high above the ground,
## and where (`tools/tour.py <track> --spot <s>,<lat>` shows it). Boxes are world-axis boxes, so a turned object counts as
## a bit bigger than it is: the test can miss a small gap, it does not invent one.

const SLACK := 0.06
const FLOAT := 0.3          ## a base this far above the ground still stands on it
const CELL := 12.0
const BIG := 150.0

var Scan = preload("res://tests/world_scan.gd")
var scan
var parent := PackedInt32Array()

func find(a: int) -> int:
	while parent[a] != a:
		parent[a] = parent[parent[a]]
		a = parent[a]
	return a

func run(host: Node) -> TestReport:
	var r := TestReport.new("decor staat op de grond: niets zweeft, niets is begraven")
	World.root = Node3D.new()
	host.add_child(World.root)
	var only := OS.get_environment("TRACKS")
	selftest(r)
	for id in TrackLoader.ported():
		if only != "" and not id in only.split(","): continue
		for dir in ["fwd", "rev"]:
			var t0 := Time.get_ticks_msec()
			Scan.build(id, dir)
			scan = Scan.new()
			scan.collect(World.root)
			var res := check()
			var ms := Time.get_ticks_msec() - t0
			for kind in ["zwevend", "begraven"]:
				var lines: Array = res[kind]
				r.check(lines.is_empty(), "%s/%s %s" % [id, dir, kind], ("%d objecten, %d ms" % [scan.items.size(), ms]) if lines.is_empty() else " | ".join(lines.slice(0, 3)))
				for k in range(3, mini(lines.size(), 14)):
					print("--     ", lines[k])
				if lines.size() > 14: print("--     ... en nog %d soorten" % (lines.size() - 14))
			await host.get_tree().process_frame
	World.clear()
	return r

func selftest(r: TestReport) -> void:
	Scan.build("polder", "fwd")
	World.box(1, 1, 1, Mats.M(0xff0000), 900, 2.0, 900)                 # a crate 1.5 m above the meadow
	World.box(0.2, 3, 0.2, Mats.M(0x00ff00), 920, 1.5, 900)             # a post ...
	World.box(1, 0.4, 1, Mats.M(0x00ff01), 920, 3.2, 900)               # ... with a head on it: fine
	scan = Scan.new()
	scan.collect(World.root)
	var all := " | ".join(check().zwevend)
	r.check("#ff0000" in all and not "#00ff0" in all, "zelftest: zwevend krat gevonden, paal met kop is goed", all.left(300))

## height of the ground under a point: the land or the terrain, and near the track the road and its dike
func ground(x: float, z: float) -> float:
	var g := 0.0
	if Trk.terrain_fn.is_valid(): g = Trk.terrain_fn.call(x, z).h
	var b := 1e18
	var bi := 0
	for k in Trk.TS.size():
		var p := Trk.TS[k]
		var d := (x - p.x) * (x - p.x) + (z - p.z) * (z - p.z)
		if d < b: b = d; bi = Trk.TSi[k]
	if b < 90.0 * 90.0:
		var q := Trk.P[bi]
		var lat := absf((x - q.x) * Trk.R[bi].x + (z - q.z) * Trk.R[bi].z)
		if lat < Trk.SHOULDER + Trk.EMB[bi] + 1.0: g = maxf(g, Trk.hAt(bi, lat))
	return g

func check() -> Dictionary:
	var items: Array = scan.items
	var n := items.size()
	parent.resize(n)
	for i in n: parent[i] = i
	var solid := PackedByteArray(); solid.resize(n)
	var grounded := PackedByteArray(); grounded.resize(n)
	var grid := {}
	var bigs := []
	for it in items:
		var surfs: Array = scan.surfaces(it.mesh)
		# a mesh of lines (a lattice pylon, a cable, a wire fence) has no triangles: it still holds things up
		if not surfs.is_empty() and surfs.all(func(s): return Scan.ghost(scan.material(it, s))): continue
		var b: AABB = it.box
		if maxf(b.size.x, b.size.z) > BIG:
			bigs.append(it)
			continue
		solid[it.id] = 1
		for cx in range(int(floor((b.position.x - SLACK) / CELL)), int(floor((b.end.x + SLACK) / CELL)) + 1):
			for cz in range(int(floor((b.position.z - SLACK) / CELL)), int(floor((b.end.z + SLACK) / CELL)) + 1):
				var key := Vector2i(cx, cz)
				if not grid.has(key): grid[key] = PackedInt32Array()
				grid[key].append(it.id)
	# ---- parts that touch are one group
	for key in grid:
		var l: PackedInt32Array = grid[key]
		for i in l.size():
			var a: AABB = items[l[i]].box.grow(SLACK)
			var ra := find(l[i])
			for j in range(i + 1, l.size()):
				var rb := find(l[j])
				if ra == rb: continue
				if a.intersects(items[l[j]].box):
					parent[rb] = ra
	# ---- standing on a strip / plane of the track: a triangle of it passes through the part's box
	for big in bigs:
		for surf in scan.surfaces(big.mesh):
			if Scan.ghost(scan.material(big, surf)): continue
			var lv: PackedVector3Array = surf.v
			var wv: PackedVector3Array = big.xf * lv
			for t in range(0, wv.size(), 3):
				var a := wv[t]; var b := wv[t + 1]; var c := wv[t + 2]
				var lo := Vector3(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y)), minf(a.z, minf(b.z, c.z)))
				var hi := Vector3(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y)), maxf(a.z, maxf(b.z, c.z)))
				var tb := AABB(lo, hi - lo).grow(FLOAT)
				for cx in range(int(floor(lo.x / CELL)), int(floor(hi.x / CELL)) + 1):
					for cz in range(int(floor(lo.z / CELL)), int(floor(hi.z / CELL)) + 1):
						var l = grid.get(Vector2i(cx, cz))
						if l == null: continue
						for id in l:
							if grounded[id] == 0 and tb.intersects(items[id].box) and on_tri(items[id].box, a, b, c):
								grounded[id] = 1
	# ---- reaching the land, the terrain, the road
	var terrain := Trk.terrain_fn.is_valid()
	var buried := {}
	for it in items:
		if solid[it.id] == 0: continue
		var b: AABB = it.box
		var c := b.get_center()
		var g := ground(c.x, c.z)
		if b.position.y <= g + FLOAT: grounded[it.id] = 1
		if terrain and it.k >= 0 or (terrain and it.node.get_parent() == World.root):
			# the lowest ground under its corners: on a slope one side always stands in the hill
			var gl := g
			for dx in [0.0, 1.0]:
				for dz in [0.0, 1.0]:
					gl = minf(gl, Trk.terrain_fn.call(b.position.x + b.size.x * dx, b.position.z + b.size.z * dz).h)
			var deep := gl - b.position.y
			if b.end.y < gl - 0.05 or (deep > 1.5 and deep > 0.5 * b.size.y):
				var key: String = scan.kind(it) if it.k < 0 else "inst %s %s" % [str(it.mesh.get_instance_id()), ""]
				var h = buried.get(key)
				if h == null:
					h = {"what": scan.kind(it), "n": 0, "deep": 0.0, "at": c, "under": 0}
					buried[key] = h
				h.n += 1
				if b.end.y < gl - 0.05: h.under += 1
				if deep > h.deep:
					h.deep = deep; h.at = c
	var ok := {}
	for i in n:
		if solid[i] == 1 and grounded[i] == 1: ok[find(i)] = true
	var groups := {}   # root -> lowest floating member
	for i in n:
		if solid[i] == 0: continue
		var rt := find(i)
		if ok.has(rt): continue
		var cur = groups.get(rt)
		if cur == null or items[i].box.position.y < items[cur[0]].box.position.y: groups[rt] = [i, 1 if cur == null else cur[1] + 1]
		else: cur[1] += 1
	var kinds := {}
	for rt in groups:
		var it = items[groups[rt][0]]
		var c: Vector3 = it.box.get_center()
		var up: float = it.box.position.y - ground(c.x, c.z)
		var key: String = str(it.mesh.get_instance_id()) if it.k >= 0 else scan.kind(it)
		var h = kinds.get(key)
		if h == null:
			h = {"what": scan.kind(it), "n": 0, "up": up, "at": c, "parts": groups[rt][1]}
			kinds[key] = h
		h.n += 1
		if up > h.up:
			h.up = up; h.at = c; h.parts = groups[rt][1]
	var out := {"zwevend": [], "begraven": []}
	var kl := kinds.values()
	kl.sort_custom(func(x, y): return x.up * x.n > y.up * y.n)
	for h in kl:
		var tp: Array = Scan.track_pos(h.at)
		out.zwevend.append("%dx %s (groep van %d): onderkant tot %.2f m boven de grond, bij %s y=%.1f (baan %.0f m, lat %.1f)" % [h.n, h.what, h.parts, h.up, Scan.xz(h.at), h.at.y, tp[0], tp[1]])
	var bl := buried.values()
	bl.sort_custom(func(x, y): return x.deep * x.n > y.deep * y.n)
	for h in bl:
		var tp: Array = Scan.track_pos(h.at)
		out.begraven.append("%dx %s: tot %.1f m in de grond (%d helemaal onder de grond), bij %s (baan %.0f m, lat %.1f)" % [h.n, h.what, h.deep, h.under, Scan.xz(h.at), tp[0], tp[1]])
	return out

## does the triangle pass through (or within FLOAT under) the box? Clip it to the box's footprint and compare heights
func on_tri(b: AABB, a: Vector3, c1: Vector3, c2: Vector3) -> bool:
	var poly := PackedVector3Array([a, c1, c2])
	poly = Scan.clip_range(poly, 0, b.position.x - SLACK, b.end.x + SLACK)
	if poly.size() < 3: return false
	poly = Scan.clip_range(poly, 2, b.position.z - SLACK, b.end.z + SLACK)
	if poly.size() < 3: return false
	var lo := 1e18; var hi := -1e18
	for p in poly:
		lo = minf(lo, p.y); hi = maxf(hi, p.y)
	return hi >= b.position.y - FLOAT and lo <= b.end.y + SLACK

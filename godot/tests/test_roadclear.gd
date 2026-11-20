extends RefCounted
## Road clearance: nothing solid on the driving surface. Every track, forwards and reversed (TRACKS=polder,dorp narrows it).
##
## Every triangle of every visible mesh and MultiMesh instance (real geometry, in world space) is cut against the space
## above the road, sample by sample (2 m slices in the track's own frame: metres along, metres right of the centre line,
## metres above the road surface). Three zones:
##   rijbaan  the asphalt, from 13 cm above the surface (road, kerbs, start line, grime lie below that) up to CLEAR
##            (4.6 m): anything at all in there is a fault. Gantries, banners and bridge decks above CLEAR are fine.
##   berm     the first 1.5 m of verge beside the asphalt (cars run wide there): only big things, at least 3 m across,
##            between 0.6 and 2 m above the road (a dune, a wall, a building). Posts, bollards, benches and flowers are fine.
##   uitloop  everywhere else the car can get: out to where its centre is stopped (Trk.EDGE: the wall, or the ditch)
##            plus REACH (0.6 m: most of the half width of a car). Anything at least 0.8 m across that rises 0.3 to 1.5 m above the
##            ground there (the dike slope followed) is something the car visibly drives through: tyre stacks, bushes,
##            boards, fences, parked cars. Thin posts, grass, flowers and reeds are fine; so are the gate posts.
## A finding says what (shape, size, colour; "inst" = one of many copies), how many, where along the lap (metres from
## sample 0, as tools/tour.py counts: `tour.py <track> --spot <s>,<lat>` shows it), how far right of the centre line,
## how high and how far inside the zone.
## The world is checked as TrackLoader.build_world makes it; World.batch only merges those same triangles afterwards.

const CLEAR := 4.6       ## free height above the road
const UP_ROAD := 0.13    ## the road's own layers end below this
const EDGE_IN := 0.15    ## the outer 15 cm of the asphalt may hold the kerb stones of a pavement
const VERGE := 1.5
const VERGE_H := 2.0     ## the verge is checked up to this height (tree crowns hang over it higher up)
const BIG := 3.0
const BIG_UP := 0.6
const REACH := 0.6       ## most of half a car's width (0.9 m): its side gets that far past Trk.EDGE; rails 0.7 m out are fine
const SOLID := 0.8
const SOLID_UP := 0.3
const CAR_H := 1.5
const MIN_IN := 0.1       ## less than this far into the verge / run-off zone is not worth a line
const CELL := 16.0

var Scan = preload("res://tests/world_scan.gd")

var slope := PackedFloat64Array()
var lmax := PackedFloat64Array()
var ymin := PackedFloat64Array()
var twist := PackedFloat64Array()   ## extra height the road's own surface can have in a sample's frame: a climbing bend is a twisted surface
var grid := {}
var hits := {}

func run(host: Node) -> TestReport:
	var r := TestReport.new("rijbaan vrij: niets op de weg, in de berm of waar de auto kan komen")
	World.root = Node3D.new()
	host.add_child(World.root)
	var only := OS.get_environment("TRACKS")
	selftest(r)
	for id in TrackLoader.ported():
		if only != "" and not id in only.split(","): continue
		for dir in ["fwd", "rev"]:
			var t0 := Time.get_ticks_msec()
			Scan.build(id, dir)
			var scan = Scan.new()
			scan.collect(World.root)
			var res := check(scan)
			var ms := Time.get_ticks_msec() - t0
			for zone in ["rijbaan", "berm", "uitloop"]:
				var lines: Array = res[zone]
				r.check(lines.is_empty(), "%s/%s %s" % [id, dir, zone], ("%d objecten, %d ms" % [scan.items.size(), ms]) if lines.is_empty() else " | ".join(lines.slice(0, 3)))
				for k in range(3, mini(lines.size(), 15)):
					print("--     ", lines[k])
				if lines.size() > 15: print("--     ... en nog %d soorten" % (lines.size() - 15))
			await host.get_tree().process_frame
	World.clear()
	return r

## the test must see what it is for: things planted on the polder's road, verge and run-off (and leave alone what is fine)
func selftest(r: TestReport) -> void:
	Scan.build("polder", "fwd")
	var red := Mats.M(0xff0000)
	var RH := Trk.ROAD_HALF
	var put := func(w: float, hh: float, d: float, i: int, lat: float, y: float, mat: Material) -> void:
		var g := Node3D.new()
		O3.mesh(Geo.box(w, hh, d), mat, 0, hh / 2.0, 0, g)
		World.place(g, i, lat, y)
	put.call(1.0, 1.0, 1.0, 100, 2.0, 0.0, red)                      # a crate in a lane
	put.call(0.1, 3.0, 0.1, 200, -3.0, 0.0, Mats.M(0xff0001))        # a thin post in a lane
	put.call(2.0 * RH + 6.0, 0.4, 0.3, 300, 0.0, 3.0, Mats.M(0xff0002))   # a beam across the road, 3 m up
	put.call(2.0 * RH + 6.0, 0.4, 0.3, 320, 0.0, 5.0, Mats.M(0x00ff00))   # the same beam at 5 m: fine
	put.call(4.0, 1.0, 4.0, 400, RH + 2.5, 0.0, Mats.M(0xff0003))    # something big half a metre into the verge
	put.call(0.3, 1.0, 0.3, 420, RH + 0.5, 0.0, Mats.M(0x00ff01))    # a post in the verge: fine
	put.call(1.0, 0.8, 1.0, 500, RH + 2.4, 0.0, Mats.M(0xff0004))    # a crate in the run-off
	put.call(1.0, 0.8, 1.0, 520, Trk.DIT[520] + 6.0, -Trk.HT[520], Mats.M(0x00ff02))   # a crate past the ditch: fine
	put.call(2.0, 0.03, 2.0, 30, 0.0, 0.07, Mats.M(0x00ff03))        # paint on the road: fine
	var scan = Scan.new()
	scan.collect(World.root)
	var res := check(scan)
	var all := " | ".join(res.rijbaan + res.berm + res.uitloop)
	var has := func(zone: String, col: String) -> bool:
		return res[zone].any(func(l): return col in l)
	r.check(has.call("rijbaan", "#ff0000") and has.call("rijbaan", "#ff0001") and has.call("rijbaan", "#ff0002"), "zelftest: krat, paaltje en lage balk op de rijbaan gevonden", all.left(300))
	r.check(has.call("berm", "#ff0003"), "zelftest: groot ding in de berm gevonden")
	r.check(has.call("uitloop", "#ff0004"), "zelftest: krat in de uitloop gevonden")
	r.check(not "#00ff0" in all, "zelftest: hoge balk, paaltje in de berm, krat voorbij de sloot en verf op de weg zijn goed", all.left(300))

func ground(x: float, z: float) -> float:
	return Trk.terrain_fn.call(x, z).h if Trk.terrain_fn.is_valid() else 0.0

## where the car's side can get at sample i (metres from the centre line)
func reach(i: int) -> float:
	return Trk.DIT[i] if Trk.TRK.edge == "ditch" else Trk.EDGE[i] + REACH

func prepare() -> void:
	var NS := Trk.NS
	slope.resize(NS); lmax.resize(NS); ymin.resize(NS); twist.resize(NS)
	grid = {}
	var terrain: bool = Trk.TRK.get("terrain", false)
	for i in NS:
		slope[i] = maxf(absf(Trk.HT[(i + 1) % NS] - Trk.HT[i]), absf(Trk.HT[i] - Trk.HT[(i - 1 + NS) % NS])) / Trk.SPC
		lmax[i] = maxf(reach(i), Trk.ROAD_HALF + VERGE)
		twist[i] = slope[i] * Trk.SPC * Trk.CURV[i] * 1.5
		var p := Trk.P[i]; var t := Trk.T[i]; var rr := Trk.R[i]
		var g0 := Trk.HT[i]
		if terrain:
			for sd in [-1.0, 1.0]:
				g0 = minf(g0, ground(p.x + rr.x * sd * lmax[i], p.z + rr.z * sd * lmax[i]))
		elif Trk.EMB[i] > 0.0 and lmax[i] > Trk.SHOULDER:
			g0 = 0.0 if lmax[i] >= Trk.SHOULDER + Trk.EMB[i] else Trk.hAt(i, lmax[i])
		ymin[i] = minf(Trk.HT[i] + UP_ROAD, g0 + SOLID_UP) - slope[i] * Trk.SPC * 0.8 - 0.01
		var x0 := 1e18; var x1 := -1e18; var z0 := 1e18; var z1 := -1e18
		for a in [-1.0, 1.0]:
			for b in [-1.0, 1.0]:
				var x: float = p.x + t.x * a * Trk.SPC * 0.5 + rr.x * b * lmax[i]
				var z: float = p.z + t.z * a * Trk.SPC * 0.5 + rr.z * b * lmax[i]
				x0 = minf(x0, x); x1 = maxf(x1, x); z0 = minf(z0, z); z1 = maxf(z1, z)
		for cx in range(int(floor(x0 / CELL)), int(floor(x1 / CELL)) + 1):
			for cz in range(int(floor(z0 / CELL)), int(floor(z1 / CELL)) + 1):
				var key := Vector2i(cx, cz)
				if not grid.has(key): grid[key] = PackedInt32Array()
				grid[key].append(i)

## the samples whose zone may touch the box x0..x1, z0..z1
func near(x0: float, x1: float, z0: float, z1: float, limit := 1 << 30) -> Dictionary:
	var out := {}
	for cx in range(int(floor(x0 / CELL)), int(floor(x1 / CELL)) + 1):
		for cz in range(int(floor(z0 / CELL)), int(floor(z1 / CELL)) + 1):
			var l = grid.get(Vector2i(cx, cz))
			if l == null: continue
			for i in l: out[i] = true
			if out.size() > limit: return out
	return out

func check(scan) -> Dictionary:
	prepare()
	hits = {}
	for it in scan.items:
		var b: AABB = it.box
		var cand := near(b.position.x, b.end.x, b.position.z, b.end.z, 40)
		if cand.is_empty(): continue
		var low := 1e18
		for i in cand: low = minf(low, ymin[i])
		if cand.size() <= 40 and b.end.y < low: continue
		var s3: Vector3 = scan.size(it)
		var foot := maxf(s3.x, s3.z) if absf(it.xf.basis.y.normalized().y) > 0.7 else maxf(b.size.x, b.size.z)
		var few: Array = cand.keys() if cand.size() <= 40 else []
		for surf in scan.surfaces(it.mesh):
			if Scan.ghost(scan.material(it, surf)): continue
			var lv: PackedVector3Array = surf.v
			var wv: PackedVector3Array = it.xf * lv
			for t in range(0, wv.size(), 3):
				var a := wv[t]; var b2 := wv[t + 1]; var c := wv[t + 2]
				var ty := maxf(a.y, maxf(b2.y, c.y))
				if not few.is_empty():
					for i in few:
						if ty >= ymin[i]: tri(it, foot, i, a, b2, c)
				else:
					var x0 := minf(a.x, minf(b2.x, c.x)); var x1 := maxf(a.x, maxf(b2.x, c.x))
					var z0 := minf(a.z, minf(b2.z, c.z)); var z1 := maxf(a.z, maxf(b2.z, c.z))
					for i in near(x0, x1, z0, z1):
						if ty >= ymin[i]: tri(it, foot, i, a, b2, c)
	return report(scan)

func hit(it, zone: String, i: int, poly: PackedVector3Array, side: float, inside: float) -> void:
	var la0 := 1e18; var la1 := -1e18; var up := -1e18
	for p in poly:
		la0 = minf(la0, p.x * side); la1 = maxf(la1, p.x * side); up = maxf(up, p.y)
	if poly.size() < 3: return
	var key := "%s|%d" % [zone, it.id]
	var h = hits.get(key)
	if h == null:
		h = {"zone": zone, "it": it, "i0": i, "i1": i, "n": {}, "la0": la0, "la1": la1, "up": up, "in": inside}
		hits[key] = h
	h.n[i] = true
	h.i0 = mini(h.i0, i); h.i1 = maxi(h.i1, i)
	h.la0 = minf(h.la0, la0); h.la1 = maxf(h.la1, la1); h.up = maxf(h.up, up); h["in"] = maxf(h["in"], inside)

static func thin(poly: PackedVector3Array) -> bool:
	if poly.size() < 3: return true
	var a0 := 1e18; var a1 := -1e18; var u0 := 1e18; var u1 := -1e18; var s0 := 1e18; var s1 := -1e18
	for p in poly:
		a0 = minf(a0, p.x); a1 = maxf(a1, p.x); u0 = minf(u0, p.y); u1 = maxf(u1, p.y); s0 = minf(s0, p.z); s1 = maxf(s1, p.z)
	return (a1 - a0) + (u1 - u0) + (s1 - s0) < 0.004

## one triangle against the zones of sample i
func tri(it, foot: float, i: int, a: Vector3, b: Vector3, c: Vector3) -> void:
	var P := Trk.P[i]; var T := Trk.T[i]; var R := Trk.R[i]
	var ht := Trk.HT[i]
	var h := Trk.SPC * 0.75   # slices overlap: on the outside of a bend they fan out
	var L := lmax[i]
	var poly := PackedVector3Array()
	var al0 := 1e18; var al1 := -1e18; var la0 := 1e18; var la1 := -1e18; var up0 := 1e18
	for v in [a, b, c]:
		var dx: float = v.x - P.x; var dz: float = v.z - P.z
		var al := dx * T.x + dz * T.z
		var la := dx * R.x + dz * R.z
		var up: float = v.y - ht
		poly.append(Vector3(la, up, al))
		al0 = minf(al0, al); al1 = maxf(al1, al); la0 = minf(la0, la); la1 = maxf(la1, la); up0 = minf(up0, up)
	if al0 > h or al1 < -h or la0 > L or la1 < -L or up0 > CLEAR + slope[i] * Trk.SPC + 0.5: return
	# the ground itself: the level or sloping faces of strips along the track, the land, the terrain (walls and rails stay)
	var ground_face := foot > 200.0 and absf((b - a).cross(c - a).normalized().y) > 0.5
	# the road runs straight from sample to sample: the half slice before and the half slice after sample i have their own slope
	var NS := Trk.NS
	for half in 2:
		var q: PackedVector3Array = Scan.clip_range(poly, 2, -h if half == 0 else 0.0, 0.0 if half == 0 else h)
		if q.size() < 3: continue
		var sl := (ht - Trk.HT[(i - 1 + NS) % NS]) / Trk.SPC if half == 0 else (Trk.HT[(i + 1) % NS] - ht) / Trk.SPC
		for k in q.size(): q[k].y -= sl * q[k].z
		zones(it, foot, i, q, sl, ground_face)

func zones(it, foot: float, i: int, poly: PackedVector3Array, sl: float, ground_face: bool) -> void:
	var P := Trk.P[i]; var T := Trk.T[i]; var R := Trk.R[i]
	var ht := Trk.HT[i]
	var RH := Trk.ROAD_HALF
	var la0 := 1e18; var la1 := -1e18; var up1 := -1e18
	for p in poly:
		la0 = minf(la0, p.x); la1 = maxf(la1, p.x); up1 = maxf(up1, p.y)
	# ---- the asphalt (the kerb stones of a pavement may stand EDGE_IN into it)
	var up_road := UP_ROAD + twist[i] * RH
	if up1 > up_road and la0 < RH and la1 > -RH:
		var q: PackedVector3Array = Scan.clip_range(Scan.clip_range(poly, 0, -RH + EDGE_IN, RH - EDGE_IN), 1, up_road, CLEAR)
		if not thin(q):
			var m := 1e18
			var both := 0
			for p in q:
				m = minf(m, absf(p.x))
				both |= 1 if p.x > 0 else 2
			hit(it, "rijbaan", i, q, 1.0, RH if both == 3 else RH - m)
	if it.gate or ground_face: return
	var SH := Trk.SHOULDER
	var E := Trk.EMB[i]
	var terrain: bool = Trk.TRK.get("terrain", false)
	for side in [1.0, -1.0]:
		if (la1 if side > 0 else -la0) < RH: continue
		var q := poly
		if side < 0:
			q = PackedVector3Array()
			for p in poly: q.append(Vector3(-p.x, p.y, p.z))
		# ---- the verge: big things only
		if foot >= BIG:
			var v: PackedVector3Array = Scan.clip_range(Scan.clip_range(q, 0, RH, minf(RH + VERGE, SH)), 1, BIG_UP, VERGE_H)
			if not thin(v):
				var m := 1e18
				for p in v: m = minf(m, p.x)
				if RH + VERGE - m >= MIN_IN: hit(it, "berm", i, v, side, RH + VERGE - m)
		# ---- as far as the car gets: nothing it would drive through
		if foot < SOLID: continue
		var lim := reach(i)
		var segs := []   # [from, to, kind]: 0 level with the road, 1 the dike slope, 2 the flat land below the dike, 3 terrain
		segs.append([RH, minf(SH, lim), 0])
		if lim > SH:
			if terrain: segs.append([SH, lim, 3])
			elif E > 0.0:
				segs.append([SH, minf(SH + E, lim), 1])
				if lim > SH + E: segs.append([SH + E, lim, 2])
			else: segs.append([SH, lim, 0])
		for sg in segs:
			if sg[1] - sg[0] < 0.02: continue
			var w: PackedVector3Array = Scan.clip_range(q, 0, sg[0] + 0.01, sg[1] - 0.01)
			if w.size() < 3: continue
			match sg[2]:
				1:
					for k in w.size(): w[k].y += ht * (w[k].x - SH) / E
				2:
					for k in w.size(): w[k].y += ht
				3:
					for k in w.size():
						var x: float = P.x + T.x * w[k].z + R.x * w[k].x * side
						var z: float = P.z + T.z * w[k].z + R.z * w[k].x * side
						w[k].y += ht + sl * w[k].z - maxf(ground(x, z), 0.0)
			w = Scan.clip_range(w, 1, SOLID_UP + twist[i] * sg[1], CAR_H)
			if not thin(w):
				var m := 1e18
				for p in w: m = minf(m, p.x)
				if lim - m >= MIN_IN: hit(it, "uitloop", i, w, side, lim - m)

func report(scan) -> Dictionary:
	var groups := {}
	for h in hits.values():
		# copies of one instanced shape are one finding, whatever their scale; loose meshes group by size and colour
		var key: String = h.zone + "|" + (str(h.it.mesh.get_instance_id()) if h.it.k >= 0 else scan.kind(h.it))
		var g = groups.get(key)
		if g == null:
			g = {"zone": h.zone, "what": scan.kind(h.it), "n": 0, "i0": h.i0, "i1": h.i1, "la0": h.la0, "la1": h.la1, "up": h.up, "in": h["in"], "at": h.it.box.get_center(), "strip": h.n.size() > 40}
			groups[key] = g
		g.n += 1
		if h.i0 < g.i0:
			g.i0 = h.i0; g.at = h.it.box.get_center()
		g.i1 = maxi(g.i1, h.i1)
		g.la0 = minf(g.la0, h.la0); g.la1 = maxf(g.la1, h.la1); g.up = maxf(g.up, h.up); g["in"] = maxf(g["in"], h["in"])
	var out := {"rijbaan": [], "berm": [], "uitloop": []}
	var list := groups.values()
	list.sort_custom(func(x, y): return x["in"] > y["in"])
	for g in list:
		var where := "%.0f m" % (g.i0 * Trk.SPC) if g.i0 == g.i1 else "%.0f-%.0f m" % [g.i0 * Trk.SPC, g.i1 * Trk.SPC]
		out[g.zone].append("%dx %s: %s, lat %.1f..%.1f, tot %.2f m hoog, %.2f m binnen de zone (%s%s)" % [g.n, g.what, where, g.la0, g.la1, g.up, g["in"],
			"eerste bij " if g.n > 1 else "bij ", Scan.xz(g.at)])
	return out

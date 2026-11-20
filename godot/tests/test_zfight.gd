extends RefCounted
## Z-fighting (flicker): two visible flat faces that lie in the same plane and overlap. Every track, forwards and
## reversed (TRACKS=polder,dorp narrows it; ZF_DIRS=fwd only forwards).
##
## Works on the real triangles of the world as TrackLoader.build_world makes it (every mesh and every MultiMesh copy):
## two triangles fight when they
##   - are flat faces (box sides, planes, strips, roofs: the vertex normals follow the face; round shapes are left out),
##   - point the same way (or opposite ways when one of them is drawn two-sided),
##   - lie within TOL (1.25 cm) of one plane where they overlap,
##   - overlap by more than MIN_AREA with a width of more than MIN_WIDTH, and
##   - look different (another colour or texture; the same paint on both cannot be seen flickering).
## Faces pointing down are skipped (undersides resting on something). Godot's depth buffer (near 0.5 m, 24 bit) tells
## faces 1.25 cm apart from each other out to about 320 m when seen square on; closer together they flicker.
## Fix a finding by moving one face 2 cm or more, or by letting one stop where the other begins.
## A finding gives both faces (shape, size, colour), how often, the overlapping area, and where: world x/y/z and the
## place along the lap (`tools/tour.py <track> --spot <s>,<lat>` shows it).

const TOL := 0.0125
const MIN_AREA := 0.02
const MIN_WIDTH := 0.04
const MIN_TRI := 0.01       ## triangles smaller than this (m2) or thinner than MIN_THIN are not worth looking at
const MIN_THIN := 0.05
const CELL := 12.0
const BIG := 150.0          ## items wider than this (strips along the track, the land, water) get their own triangle grid

var Scan = preload("res://tests/world_scan.gd")

var faces := {}             ## item id -> {v: PackedVector3Array (world, 3 per face), n: PackedVector3Array, lo, hi (boxes per face), mat}
var flat_cache := {}        ## mesh id -> Array per surface of PackedInt32Array (first vertex of every flat triangle)
var hits := {}
var scan

func run(host: Node) -> TestReport:
	var r := TestReport.new("z-fighting: flikkerende vlakken op de banen")
	World.root = Node3D.new()
	host.add_child(World.root)
	var only := OS.get_environment("TRACKS")
	var dirs := OS.get_environment("ZF_DIRS")
	selftest(r)
	for id in TrackLoader.ported():
		if only != "" and not id in only.split(","): continue
		for dir in ["fwd", "rev"]:
			if dirs != "" and not dir in dirs.split(","): continue
			var t0 := Time.get_ticks_msec()
			Scan.build(id, dir)
			scan = Scan.new()
			scan.collect(World.root)
			var lines := check()
			var ms := Time.get_ticks_msec() - t0
			r.check(lines.is_empty(), "%s/%s" % [id, dir], ("%d objecten, %d met vlakken, %d ms" % [scan.items.size(), faces.size(), ms]) if lines.is_empty() else " | ".join(lines.slice(0, 3)))
			for k in range(3, mini(lines.size(), 14)):
				print("--     ", lines[k])
			if lines.size() > 14: print("--     ... en nog %d soorten" % (lines.size() - 14))
			await host.get_tree().process_frame
	World.clear()
	return r

## the test must see what it is for: planted faces that flicker are found, faces that cannot flicker are left alone
func selftest(r: TestReport) -> void:
	World.clear()
	World.cpGates = []
	Trk.compute_track("polder", "fwd")
	var a := Mats.M(0xff0000); var b := Mats.M(0x0000ff)
	World.box(4, 2, 4, a, 0, 1, 0)
	World.box(2, 2, 2, b, 1, 1, 2 - 1 + 0.001)                       # a blue box whose top and side lie in the red one's
	World.box(2, 1, 2, Mats.M(0x00ff00), 30, 0.5, 0)
	World.box(2, 1, 2, Mats.M(0x00ff01), 30.5, 0.52, 0.5)            # 2 cm higher: fine
	World.box(2, 1, 2, Mats.M(0x00ff02), 60, 0.5, 0)
	World.box(2, 1, 2, Mats.M(0x00ff02), 61, 0.5, 0.5)               # the same colour: cannot be seen
	World.box(2, 1, 2, Mats.M(0x00ff04), 90, 0.5, 0)
	World.box(2, 1, 2, Mats.M(0x00ff05), 90, 1.5, 0)                 # stacked: top against bottom, never both seen
	var g := O3.mesh(Geo.plane(6, 6), Mats.M(0xff00ff), 120, 0.3, 0)
	O3.rot(g, -PI / 2, 0, 0.3)
	World.add(g)
	var g2 := O3.mesh(Geo.plane(6, 6), Mats.M(0xffff00), 123, 0.305, 1)   # two fields half a centimetre apart
	O3.rot(g2, -PI / 2, 0, 0)
	World.add(g2)
	scan = Scan.new()
	scan.collect(World.root)
	var lines := check()
	var all := " | ".join(lines)
	r.check(lines.any(func(l): return "#ff0000" in l and "#0000ff" in l) and lines.any(func(l): return "#ff00ff" in l and "#ffff00" in l), "zelftest: kast in kast en twee velden op elkaar gevonden", all.left(300))
	r.check(not "#00ff0" in all, "zelftest: 2 cm verschil, zelfde kleur en gestapeld zijn goed", all.left(300))

## the flat triangles of a mesh surface (local): vertex normals within ~8 degrees of the face normal (or no normals at all)
func flat_tris(mesh: Mesh) -> Array:
	var key := mesh.get_instance_id()
	if flat_cache.has(key): return flat_cache[key]
	var out := []
	for surf in scan.surfaces(mesh):
		var v: PackedVector3Array = surf.v
		var keep := PackedInt32Array()
		for t in range(0, v.size(), 3):
			var fn := (v[t + 2] - v[t]).cross(v[t + 1] - v[t])
			if fn.length_squared() < 1e-12: continue
			fn = fn.normalized()
			var ok := true
			if surf.n != null:
				var nn: PackedVector3Array = surf.n
				for k in 3:
					if absf(nn[t + k].normalized().dot(fn)) < 0.99: ok = false
			if ok: keep.append(t)
		out.append(keep)
	flat_cache[key] = out
	return out

## the world faces of an item worth checking (cached); null when it has none
func item_faces(it):
	if faces.has(it.id): return faces[it.id]
	var res = null
	var flats := flat_tris(it.mesh)
	var surfs: Array = scan.surfaces(it.mesh)
	var V := PackedVector3Array(); var N := PackedVector3Array(); var mats := []
	for s in surfs.size():
		var keep: PackedInt32Array = flats[s]
		if keep.is_empty(): continue
		var mat: Material = scan.material(it, surfs[s])
		if Scan.ghost(mat): continue
		var lv: PackedVector3Array = surfs[s].v
		for t in keep:
			var a: Vector3 = it.xf * lv[t]; var b: Vector3 = it.xf * lv[t + 1]; var c: Vector3 = it.xf * lv[t + 2]
			var cr := (c - a).cross(b - a)
			var area := cr.length() * 0.5
			if area < MIN_TRI: continue
			var e := maxf((b - a).length(), maxf((c - b).length(), (a - c).length()))
			if 2.0 * area / e < MIN_THIN: continue
			var n := cr.normalized()
			if n.y < -0.9 and not Scan.two_sided(mat): continue   # undersides
			V.append(a); V.append(b); V.append(c); N.append(n); mats.append(mat)
	if not N.is_empty():
		res = {"v": V, "n": N, "mat": mats, "it": it}
	faces[it.id] = res
	return res

func check() -> Array:
	faces = {}
	hits = {}
	# ---- items with flat faces, small ones in a grid by their box, big ones with a grid of their triangles
	var grid := {}
	var small := []
	var big := []
	for it in scan.items:
		var b: AABB = it.box
		if b.size.x < 0.05 and b.size.z < 0.05: continue
		var f = item_faces(it)
		if f == null: continue
		if maxf(b.size.x, b.size.z) > BIG:
			big.append(f)
			var tg := {}
			var v: PackedVector3Array = f.v
			for t in f.n.size():
				var a := v[t * 3]; var b2 := v[t * 3 + 1]; var c := v[t * 3 + 2]
				for cx in range(int(floor((minf(a.x, minf(b2.x, c.x)) - TOL) / CELL)), int(floor((maxf(a.x, maxf(b2.x, c.x)) + TOL) / CELL)) + 1):
					for cz in range(int(floor((minf(a.z, minf(b2.z, c.z)) - TOL) / CELL)), int(floor((maxf(a.z, maxf(b2.z, c.z)) + TOL) / CELL)) + 1):
						var key := Vector2i(cx, cz)
						if not tg.has(key): tg[key] = PackedInt32Array()
						tg[key].append(t)
			f["grid"] = tg
		else:
			small.append(f)
			for cx in range(int(floor((b.position.x - TOL) / CELL)), int(floor((b.end.x + TOL) / CELL)) + 1):
				for cz in range(int(floor((b.position.z - TOL) / CELL)), int(floor((b.end.z + TOL) / CELL)) + 1):
					var key := Vector2i(cx, cz)
					if not grid.has(key): grid[key] = []
					grid[key].append(f)
	# ---- small against small: boxes that touch
	var seen := {}
	for key in grid:
		var l: Array = grid[key]
		for i in l.size():
			var fa: Dictionary = l[i]
			var ba: AABB = fa.it.box.grow(TOL)
			for j in range(i + 1, l.size()):
				var fb: Dictionary = l[j]
				if not ba.intersects(fb.it.box): continue
				var pk: int = fa.it.id * 1000003 + fb.it.id if fa.it.id < fb.it.id else fb.it.id * 1000003 + fa.it.id
				if seen.has(pk): continue
				seen[pk] = true
				pair(fa, fb, null, null)
	# ---- big against small and big against big, through the big one's triangle grid
	for bi in big.size():
		var fb: Dictionary = big[bi]
		var tg: Dictionary = fb.grid
		for fa in small:
			var b: AABB = fa.it.box
			if not b.grow(TOL).intersects(fb.it.box): continue
			var tris := {}
			for cx in range(int(floor((b.position.x - TOL) / CELL)), int(floor((b.end.x + TOL) / CELL)) + 1):
				for cz in range(int(floor((b.position.z - TOL) / CELL)), int(floor((b.end.z + TOL) / CELL)) + 1):
					var tl = tg.get(Vector2i(cx, cz))
					if tl != null:
						for t in tl: tris[t] = true
			if not tris.is_empty(): pair(fa, fb, null, tris.keys())
		for bj in range(bi + 1, big.size()):
			var fc: Dictionary = big[bj]
			if not fc.it.box.grow(TOL).intersects(fb.it.box): continue
			var tg2: Dictionary = fc.grid
			var done := {}
			for key in tg:
				var l2 = tg2.get(key)
				if l2 == null: continue
				pair_lists(fb, fc, tg[key], l2, done)
	return report()

## faces of item a against faces of item b (ta / tb: only these faces, or null for all)
func pair(fa: Dictionary, fb: Dictionary, ta, tb) -> void:
	var la = ta if ta != null else range(fa.n.size())
	var lb = tb if tb != null else range(fb.n.size())
	pair_lists(fa, fb, la, lb, null)

func pair_lists(fa: Dictionary, fb: Dictionary, la, lb, done) -> void:
	var va: PackedVector3Array = fa.v; var na: PackedVector3Array = fa.n
	var vb: PackedVector3Array = fb.v; var nb: PackedVector3Array = fb.n
	for i in la:
		var n := na[i]
		var a0 := va[i * 3]; var a1 := va[i * 3 + 1]; var a2 := va[i * 3 + 2]
		var d := n.dot(a0)
		for j in lb:
			var dn := n.dot(nb[j])
			if dn < 0.9995 and dn > -0.9995: continue
			var b0 := vb[j * 3]; var b1 := vb[j * 3 + 1]; var b2 := vb[j * 3 + 2]
			var d0 := n.dot(b0) - d; var d1 := n.dot(b1) - d; var d2 := n.dot(b2) - d
			if (d0 > TOL and d1 > TOL and d2 > TOL) or (d0 < -TOL and d1 < -TOL and d2 < -TOL): continue
			if done != null:
				var k: int = i * 2000003 + j
				if done.has(k): continue
				done[k] = true
			var ma: Material = fa.mat[i]; var mb: Material = fb.mat[j]
			if dn < 0.0 and not (Scan.two_sided(ma) or Scan.two_sided(mb)): continue
			if same_look(fa, ma, fb, mb): continue
			# the part of triangle b inside triangle a (as seen along the normal)
			var poly := PackedVector3Array([b0, b1, b2])
			for e in [[a0, a1], [a1, a2], [a2, a0]]:
				var en: Vector3 = (e[1] - e[0]).cross(n)   # in the plane, pointing out of or into the triangle
				if en.dot(a0 + a1 + a2 - e[0] * 3.0) < 0.0: en = -en
				poly = clip_plane(poly, en, en.dot(e[0]))
				if poly.size() < 3: break
			if poly.size() < 3: continue
			var area := 0.0
			var per := 0.0
			var gap := 1e18
			var cen := Vector3.ZERO
			for k in poly.size():
				var p := poly[k]; var q := poly[(k + 1) % poly.size()]
				per += (q - p).length()
				if k >= 1 and k < poly.size() - 1: area += (p - poly[0]).cross(q - poly[0]).length() * 0.5
				gap = minf(gap, absf(n.dot(p) - d))
				cen += p
			if area < MIN_AREA or gap > TOL or 2.0 * area / per < MIN_WIDTH: continue
			hit(fa, ma, fb, mb, area, cen / poly.size(), gap)

static func clip_plane(poly: PackedVector3Array, n: Vector3, d: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var cnt := poly.size()
	var a := poly[cnt - 1]
	var da := n.dot(a) - d
	for i in cnt:
		var b := poly[i]
		var db := n.dot(b) - d
		if db >= 0.0:
			if da < 0.0: out.append(a + (b - a) * (da / (da - db)))
			out.append(b)
		elif da >= 0.0:
			out.append(a + (b - a) * (da / (da - db)))
		a = b; da = db
	return out

## the same paint on both faces: the flicker cannot be seen
func same_look(fa: Dictionary, ma: Material, fb: Dictionary, mb: Material) -> bool:
	var ia = fa.it; var ib = fb.it
	# copies with their own colour (World.inst with colours) always count as different
	if (ia.k >= 0 and ia.node.multimesh.use_colors) or (ib.k >= 0 and ib.node.multimesh.use_colors):
		return false
	if ma == mb: return true
	if ma is LMat and mb is LMat:
		if ma.albedo_texture != mb.albedo_texture: return false
		if ma.albedo_texture != null and (ma.uv1_scale != mb.uv1_scale or ia != ib): return false
		return ma.albedo_color.is_equal_approx(mb.albedo_color) and ma.kind == mb.kind and Scan.see_through(ma) == Scan.see_through(mb) \
			and ma.emission_enabled == mb.emission_enabled and (not ma.emission_enabled or ma.emission.is_equal_approx(mb.emission))
	return false

func hit(fa: Dictionary, ma: Material, fb: Dictionary, mb: Material, area: float, at: Vector3, gap: float) -> void:
	var ka: String = Scan.colour(ma) + " " + what(fa.it)
	var kb: String = Scan.colour(mb) + " " + what(fb.it)
	if kb < ka:
		var t := ka; ka = kb; kb = t
	var key := ka + " <-> " + kb
	var h = hits.get(key)
	if h == null:
		h = {"key": key, "n": 0, "area": 0.0, "at": at, "big": 0.0, "gap": gap, "pairs": {}}
		hits[key] = h
	h.n += 1
	h.area += area
	h.gap = minf(h.gap, gap)
	h.pairs["%d/%d" % [fa.it.id, fb.it.id]] = true
	if area > h.big:
		h.big = area; h.at = at

## shape and size of an item, sizes rounded so that copies at slightly different scales read as one kind
func what(it) -> String:
	var s: Vector3 = scan.size(it)
	var nv: int = scan.surfaces(it.mesh)[0].v.size()
	var shape := "kast" if nv == 36 else ("vlak" if nv == 6 else ("strook" if maxf(s.x, s.z) > BIG else "mesh"))
	if shape == "strook": return "%sstrook %.0f m" % ["inst " if it.k >= 0 else "", maxf(s.x, s.z)]
	return "%s%s %.1fx%.1fx%.1f" % ["inst " if it.k >= 0 else "", shape, s.x, s.y, s.z]

func report() -> Array:
	var list := hits.values()
	list.sort_custom(func(x, y): return x.area > y.area)
	var out := []
	for h in list:
		var tp: Array = Scan.track_pos(h.at)
		out.append("%dx (%d paren) opp %.2f m2, %.1f cm uit elkaar: %s bij x=%.1f y=%.2f z=%.1f (baan %.0f m, lat %.1f)" % [h.n, h.pairs.size(), h.area, h.gap * 100.0, h.key, h.at.x, h.at.y, h.at.z, tp[0], tp[1]])
	return out

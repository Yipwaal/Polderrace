class_name BKit
## Building kit of the tracks veluwe, grachten, limburg, rotterdam and zeeland (fase 2: richer scenery at a low cost):
## - merge(): several coloured parts as one Geo with vertex colours, so a whole tree or deer is one World.inst call
##   (one draw call per 300 m cell instead of one per part);
## - Acc: unique decor (a castle, a cafe, a pavilion) added box by box and drawn as one vertex-coloured mesh per cell;
## - things every track wants: arrow boards on the outside of the bends (the right way round in both driving
##   directions, because a track is built per direction), reflector posts, spectators, painted road text, trees.
## Everything random comes from the seeded World.rnd, so every player online sees the same world.

const CELL := 300.0

static func rnd() -> float:
	return World.rnd.next()

static func col(c) -> Color:
	return c if c is Color else MathX.col(int(c))

## terrain height on Veluwe and Limburg, 0 elsewhere
static func gy(x: float, z: float) -> float:
	return Dress.groundY(x, z)

## a vertex-coloured Lambert material (o: extra Mats options)
static func vmat(o: Dictionary = {}) -> LMat:
	var oo := o.duplicate()
	oo["vertexColors"] = true
	return Mats.M(0xffffff, oo)

static func _append(g: Geo, s: Geo, c: Color, xf = null) -> void:
	var off := g.pos.size()
	var n := s.pos.size()
	if xf == null:
		g.pos.append_array(s.pos)
		g.nrm.append_array(s.nrm)
	else:
		var t: Transform3D = xf
		g.pos.append_array(t * s.pos)
		var nb := t.basis.inverse().transposed()
		for k in n:
			g.nrm.append((nb * s.nrm[k]).normalized())
	if s.uv.size() == n:
		g.uv.append_array(s.uv)
	else:
		var u := PackedVector2Array(); u.resize(n); g.uv.append_array(u)
	var cc := PackedColorArray(); cc.resize(n); cc.fill(c)
	if s.col.size() == n:
		# a part that has its own vertex colours (a merged tree, a shaded dune) keeps them, tinted by c
		for k in n: cc[k] = s.col[k] * c
	g.col.append_array(cc)
	if s.idx.is_empty():
		for k in n: g.idx.append(off + k)
	else:
		for k in s.idx: g.idx.append(off + k)

## parts: [[Geo, colour (Color or 0xRRGGBB)], ...] -> one Geo with vertex colours
static func merge(parts: Array) -> Geo:
	var g := Geo.new()
	for p in parts:
		_append(g, p[0], col(p[1]))
	return g

static func xf(x: float, y: float, z: float, ry := 0.0, rx := 0.0, rz := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, ry) * Basis(Vector3.RIGHT, rx) * Basis(Vector3.BACK, rz), Vector3(x, y, z))

## Unique decor as one vertex-coloured mesh per 300 m cell. Positions are world coordinates, or local ones after
## at(x, y, z, ry) (a local frame: the object's own origin and heading).
class Acc:
	var cells := {}
	var frame := Transform3D.IDENTITY
	var mat: LMat
	var cast := true

	func _init(m: LMat = null, cast_shadow := true) -> void:
		mat = m if m != null else BKit.vmat()
		cast = cast_shadow

	func at(x: float, y: float, z: float, ry := 0.0) -> Acc:
		frame = Transform3D(Basis(Vector3.UP, ry), Vector3(x, y, z))
		return self

	func _cell() -> Geo:
		var o := frame.origin
		var k := "%d,%d" % [int(floor(o.x / BKit.CELL)), int(floor(o.z / BKit.CELL))]
		if not cells.has(k): cells[k] = Geo.new()
		return cells[k]

	func add(s: Geo, c, t: Transform3D = Transform3D.IDENTITY) -> Acc:
		BKit._append(_cell(), s, BKit.col(c), frame * t)
		return self

	func box(w: float, h: float, d: float, x: float, y: float, z: float, c, ry := 0.0, rx := 0.0, rz := 0.0) -> Acc:
		return add(Geo.box(w, h, d), c, BKit.xf(x, y, z, ry, rx, rz))

	func cyl(rt: float, rb: float, h: float, seg: int, x: float, y: float, z: float, c, rx := 0.0, rz := 0.0) -> Acc:
		return add(Geo.cylinder(rt, rb, h, seg), c, BKit.xf(x, y, z, 0.0, rx, rz))

	## a gable roof over w (x) by d (z), ridge along z, eaves at y, h high
	func roof(w: float, h: float, d: float, x: float, y: float, z: float, c, ry := 0.0) -> Acc:
		var g := TrackCommon.roofGeo()
		g.scale(w, h, d)
		return add(g, c, BKit.xf(x, y, z, ry))

	## a pyramid / spire: square base w by d
	func spire(w: float, h: float, d: float, x: float, y: float, z: float, c) -> Acc:
		var g := Geo.cone(0.7072, 1.0, 4).rotate_y(PI / 4)
		g.scale(w, h, d)
		return add(g, c, BKit.xf(x, y + h / 2.0, z))

	func commit() -> void:
		for k in cells:
			var g: Geo = cells[k]
			if g.pos.is_empty(): continue
			var mi := O3.mesh(g, mat, 0, 0, 0, null, cast)
			World.add(mi)
		cells = {}

# ---------------------------------------------------------------- trees (unit trees: scale with the instance)

## spruce: trunk and three cones, 12 m at scale 1 (tree colours are baked in; the instance colour is a light tint)
static func spruceGeo() -> Geo:
	return merge([
		[Geo.cylinder(0.22, 0.34, 3.0, 5, 1, true).translate(0, 1.5, 0), 0x4a3524],
		[Geo.cone(2.9, 5.0, 7).translate(0, 4.6, 0), 0x28482a],
		[Geo.cone(2.2, 4.4, 7, 1, true).translate(0, 7.4, 0), 0x2d502e],
		[Geo.cone(1.4, 3.6, 7, 1, true).translate(0, 10.2, 0), 0x345a33]])

## Scots pine (grove den): a tall bare reddish trunk with a flat, dark crown; 13 m
static func scotsGeo() -> Geo:
	return merge([
		[Geo.cylinder(0.2, 0.36, 9.0, 5, 1, true).translate(0, 4.5, 0), 0x8a5a3a],
		[Geo.icosahedron(1.0, 0).scale(3.2, 1.5, 3.0).translate(0.2, 10.2, 0), 0x2f4c2c],
		[Geo.icosahedron(1.0, 0).scale(2.2, 1.2, 2.3).translate(-0.9, 11.6, 0.5), 0x375733],
		[Geo.icosahedron(1.0, 0).scale(1.6, 0.9, 1.6).translate(1.6, 8.6, -0.8), 0x2a4528]])

## birch: white trunk with dark marks, light airy crown; 9 m
static func birchGeo() -> Geo:
	return merge([
		[Geo.cylinder(0.12, 0.2, 6.0, 5, 1, true).translate(0, 3.0, 0), 0xe8e4dc],
		[Geo.box(0.3, 0.12, 0.3).translate(0, 1.6, 0), 0x3a352e],
		[Geo.box(0.26, 0.1, 0.26).translate(0, 3.4, 0), 0x3a352e],
		[Geo.icosahedron(1.0, 0).scale(1.9, 2.6, 1.9).translate(0, 6.6, 0), 0x6f9440],
		[Geo.icosahedron(1.0, 0).scale(1.3, 1.5, 1.3).translate(0.8, 5.0, 0.4), 0x66893b]])

## oak / elm / lime: a broad round crown on a sturdy trunk; 9 m
static func oakGeo() -> Geo:
	return merge([
		[Geo.cylinder(0.3, 0.45, 4.0, 6, 1, true).translate(0, 2.0, 0), 0x4f3a28],
		[Geo.icosahedron(1.0, 0).scale(3.4, 2.7, 3.4).translate(0, 6.2, 0), 0x466e30],
		[Geo.icosahedron(1.0, 0).scale(2.2, 1.9, 2.2).translate(1.6, 4.9, 0.9), 0x3e642b],
		[Geo.icosahedron(1.0, 0).scale(2.0, 1.8, 2.0).translate(-1.5, 5.2, -0.9), 0x426a2e]])

## Lombardy poplar: a tall narrow column; 16 m
static func poplarGeo() -> Geo:
	return merge([
		[Geo.cylinder(0.18, 0.3, 3.0, 5, 1, true).translate(0, 1.5, 0), 0x5a4632],
		[Geo.icosahedron(1.0, 0).scale(1.5, 6.6, 1.5).translate(0, 9.0, 0), 0x4f7a36]])

## a street tree with a clear trunk (cars and people pass under it): crown r 1.6 at 5.2 m; 7 m
static func streetTreeGeo() -> Geo:
	return merge([
		[Geo.cylinder(0.14, 0.2, 4.0, 6, 1, true).translate(0, 2.0, 0), 0x4a3828],
		[Geo.icosahedron(1.0, 0).scale(1.7, 1.9, 1.7).translate(0, 5.2, 0), 0x4a7434],
		[Geo.icosahedron(1.0, 0).scale(1.2, 1.2, 1.2).translate(0.5, 4.2, 0.3), 0x426a2e]])

## a low fruit tree: the instance colour is the blossom / leaf colour; 4.5 m
static func fruitGeo() -> Geo:
	return merge([
		[Geo.cylinder(0.1, 0.16, 1.8, 5, 1, true).translate(0, 0.9, 0), 0x3f2e20],
		[Geo.icosahedron(1.0, 0).scale(1.7, 1.4, 1.7).translate(0, 2.9, 0), 0xffffff]])

## a bush / heather tuft (unit size 1)
static func bushGeo() -> Geo:
	return Geo.icosahedron(1.0, 0).scale(1.0, 0.62, 1.0).translate(0, 0.45, 0).set_color(Color.WHITE)

# ---------------------------------------------------------------- people and animals

## spectators at [[x, y, z, heading], ...]: a body in a bright colour, dark legs and a head (two draw calls per cell)
static func crowd(spots: Array) -> void:
	if spots.is_empty(): return
	var body := merge([
		[Geo.box(0.34, 0.8, 0.24).translate(0, 0.4, 0), 0x3a3f4a],
		[Geo.box(0.46, 0.62, 0.28).translate(0, 1.1, 0), 0xffffff],
		[Geo.box(0.12, 0.55, 0.14).translate(-0.3, 1.2, 0.02).rotate_z(-0.12), 0xffffff],
		[Geo.box(0.12, 0.55, 0.14).translate(0.3, 1.2, 0.02).rotate_z(0.12), 0xffffff]])
	var head := Geo.box(0.24, 0.26, 0.24).translate(0, 1.58, 0)
	var pal := [0xd62a2a, 0x1d4f9e, 0xf2c200, 0xecece8, 0x2f8f5b, 0xf36f21, 0x8a4fa0, 0x30343c, 0xf36f21]
	var skin := [0xe9c4a0, 0xd9a882, 0xf0d0b4, 0x9a6a48]
	var bm := []; var bc := []; var hm := []; var hc := []
	for s in spots:
		var hgt := 0.92 + rnd() * 0.16
		var m := World.mtx(s[0], s[1], s[2], s[3] + (rnd() - 0.5) * 0.5, 1.0, hgt, 1.0)
		bm.append(m); hm.append(m)
		bc.append(col(World.pick(pal))); hc.append(col(World.pick(skin)))
	World.inst(body, Mats.M(0xffffff), bm, bc, false)
	World.inst(head, Mats.M(0xffffff), hm, hc, false)

## a row of people along the track from sample i0, n people, at lateral offset lat (outside the wall), facing the road
static func crowdRow(i0: int, n: int, lat: float, step := 1.1, rows := 1) -> Array:
	var out := []
	for r in rows:
		for k in n:
			# between the samples too (two people on the same 2 m sample would stand in each other)
			var a := Trk.trackAt(i0 * Trk.SPC + k * step + rnd() * maxf(0.0, step - 0.85))
			var l := lat + signf(lat) * (r * 0.9 + rnd() * 0.4)
			var x: float = a.px + a.rx * l
			var z: float = a.pz + a.rz * l
			var hd := atan2(a.tx, a.tz) + (PI / 2 if lat > 0 else -PI / 2)
			var y := gy(x, z) if Trk.TRK.get("terrain", false) else lerpf(Trk.hAt(a.i, l), Trk.hAt(a.j, l), a.t)
			out.append([x, y, z, hd])
	return out

## deer: body, neck, head, legs, and antlers for the stags (two geometries, one draw call per cell each)
static func deerGeo(stag: bool) -> Geo:
	var c := 0x9a6a3e
	var parts := [
		[Geo.box(0.46, 0.56, 1.25).translate(0, 1.05, 0), c],
		[Geo.box(0.22, 0.6, 0.26).rotate_x(0.5).translate(0, 1.5, 0.66), c],
		[Geo.box(0.24, 0.26, 0.48).translate(0, 1.84, 0.92), 0x8a5c34],
		[Geo.box(0.3, 0.24, 0.1).translate(0, 1.2, -0.64), 0xf2ece0]]
	for lx in [-0.15, 0.15]:
		for lz in [-0.48, 0.48]:
			parts.append([Geo.box(0.1, 0.8, 0.1).translate(lx, 0.4, lz), 0x6a4628])
	if stag:
		for s in [-1.0, 1.0]:
			parts.append([Geo.box(0.05, 0.55, 0.05).rotate_z(-s * 0.5).translate(s * 0.2, 2.2, 0.8), 0xd8ccb0])
			parts.append([Geo.box(0.05, 0.3, 0.05).rotate_z(-s * 1.1).translate(s * 0.42, 2.38, 0.8), 0xd8ccb0])
			parts.append([Geo.box(0.05, 0.28, 0.05).rotate_x(0.7).translate(s * 0.3, 2.3, 0.92), 0xd8ccb0])
	return merge(parts)

## a sheep: woolly body, dark head and legs
static func sheepGeo() -> Geo:
	var parts := [
		[Geo.box(0.8, 0.7, 1.3).translate(0, 0.8, 0), 0xefece2],
		[Geo.box(0.35, 0.4, 0.45).translate(0, 0.98, 0.78), 0x1f1f1f]]
	for lx in [-0.25, 0.25]:
		for lz in [-0.45, 0.45]:
			parts.append([Geo.box(0.12, 0.5, 0.12).translate(lx, 0.25, lz), 0x1f1f1f])
	return merge(parts)

## trees keep a little distance from each other (two cone bases at the same height in the same place flicker):
## Spacing.new(3.2).free_at(x, z) is true once per spot
class Spacing:
	var r := 3.0
	var grid := {}
	func _init(radius: float) -> void:
		r = radius
	func free_at(x: float, z: float) -> bool:
		var cx := int(floor(x / r)); var cz := int(floor(z / r))
		for a in range(cx - 1, cx + 2):
			for b in range(cz - 1, cz + 2):
				for p in grid.get(Vector2i(a, b), []):
					if (p.x - x) * (p.x - x) + (p.y - z) * (p.y - z) < r * r: return false
		var key := Vector2i(cx, cz)
		if not grid.has(key): grid[key] = []
		grid[key].append(Vector2(x, z))
		return true

## building lots: turned rectangles that may not overlap (houses in rows that meet at corners and along canals).
## Lots.new().take(x, z, ry, hx, hz) is true when the rectangle (half sizes hx along its local x, hz along its local z)
## is free, and then keeps it. mx, mz: room kept round it along its own x and z (negative: it may touch or overlap that
## much): a row house touches its neighbours (mz < 0) but keeps clear of a house of a row that crosses its own (mx > 0),
## whose wall would otherwise lie in the plane of its front and flicker.
class Lots:
	var grid := {}
	const C := 16.0
	func take(x: float, z: float, ry: float, hx: float, hz: float, mx := -0.05, mz := -0.05) -> bool:
		var ax := Vector2(cos(ry), -sin(ry))      # local x in world (x, z)
		var az := Vector2(sin(ry), cos(ry))       # local z
		var me := [Vector2(x, z), ax, az, hx + mx, hz + mz]
		var r := sqrt(hx * hx + hz * hz)
		var c0 := Vector2i(int(floor((x - r) / C)), int(floor((z - r) / C)))
		var c1 := Vector2i(int(floor((x + r) / C)), int(floor((z + r) / C)))
		for a in range(c0.x, c1.x + 1):
			for b in range(c0.y, c1.y + 1):
				for o in grid.get(Vector2i(a, b), []):
					if _hit(me, o): return false
		for a in range(c0.x, c1.x + 1):
			for b in range(c0.y, c1.y + 1):
				var k := Vector2i(a, b)
				if not grid.has(k): grid[k] = []
				grid[k].append(me)
		return true
	## separating axes of two turned rectangles
	func _hit(p: Array, q: Array) -> bool:
		var d: Vector2 = q[0] - p[0]
		for ax in [p[1], p[2], q[1], q[2]]:
			var rp: float = absf(ax.dot(p[1])) * p[3] + absf(ax.dot(p[2])) * p[4]
			var rq: float = absf(ax.dot(q[1])) * q[3] + absf(ax.dot(q[2])) * q[4]
			if absf(ax.dot(d)) >= rp + rq: return false
		return true

## a cow: black-and-white (the instance colour tints the white patches: white or red-brown cattle)
static func cowGeo() -> Geo:
	var parts := [
		[Geo.box(0.7, 0.8, 1.7).translate(0, 1.0, 0), 0xf4f1ea],
		[Geo.box(0.72, 0.5, 0.6).translate(0, 1.16, -0.35), 0x24211e],
		[Geo.box(0.72, 0.45, 0.4).translate(0, 1.2, 0.62), 0x24211e],
		[Geo.box(0.36, 0.4, 0.6).translate(0, 1.2, 1.1), 0x24211e],
		[Geo.box(0.3, 0.2, 0.2).translate(0, 1.1, 1.42), 0xe8b8a8],
		[Geo.box(0.3, 0.16, 0.3).translate(0, 0.58, -0.3), 0xe8b8a8]]
	for lx in [-0.24, 0.24]:
		for lz in [-0.62, 0.62]:
			parts.append([Geo.box(0.16, 0.66, 0.16).translate(lx, 0.33, lz), 0xe9e4da])
	return merge(parts)

## a house for instancing: unit box (textured walls) and a unit gable roof; see houseXf / roofXf
static func houseXf(x: float, ground: float, z: float, ry: float, w: float, h: float, d: float, sink := 1.5) -> Transform3D:
	# the walls go `sink` m into the ground, so the house also stands on a slope
	return Transform3D(Basis(Vector3.UP, ry).scaled_local(Vector3(w, h + sink, d)), Vector3(x, ground + (h - sink) / 2.0, z))

static func roofXf(x: float, ground: float, z: float, ry: float, w: float, h: float, d: float, rh: float, over := 0.5) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, ry).scaled_local(Vector3(w + over * 2, rh, d + over * 2)), Vector3(x, ground + h - 0.03, z))

# ---------------------------------------------------------------- along the road

static var _chev := {}
## the red-and-white arrow board texture (dir 1 = arrows to the right)
static func chevronTex(dir: int) -> ImageTexture:
	if not _chev.has(dir):
		_chev[dir] = Canvas2D.tex(128, 64, func(g, w, h):
			g.fillStyle = "#c81e1e"; g.fillRect(0, 0, w, h)
			g.fillStyle = "#f4f4f0"
			for k in 3:
				var x0: float = 10 + k * 40
				g.beginPath()
				if dir > 0:
					g.moveTo(x0, 4); g.lineTo(x0 + 16, 4); g.lineTo(x0 + 34, h / 2.0); g.lineTo(x0 + 16, h - 4); g.lineTo(x0, h - 4); g.lineTo(x0 + 18, h / 2.0)
				else:
					g.moveTo(x0 + 34, 4); g.lineTo(x0 + 18, 4); g.lineTo(x0, h / 2.0); g.lineTo(x0 + 18, h - 4); g.lineTo(x0 + 34, h - 4); g.lineTo(x0 + 16, h / 2.0)
				g.closePath(); g.fill())
	return _chev[dir]

## the bends of the track: [{i0, i1, apex, dir (1 = the road turns right), kmax}], for bends tighter than curv
static func bends(curv := 0.016, minLen := 8) -> Array:
	var NS := Trk.NS
	var out := []
	var start := -1
	# begin the scan on a straight sample so a bend over the lap seam is not cut in two
	var off := 0
	while off < NS and Trk.CURV[off] >= curv: off += 1
	for q in NS + 1:
		var i := (q + off) % NS
		var inb: bool = q < NS and Trk.CURV[i] >= curv
		if inb and start < 0: start = q
		elif not inb and start >= 0:
			if q - start >= minLen:
				var apex := start
				for k in range(start, q):
					if Trk.CURV[(k + off) % NS] > Trk.CURV[(apex + off) % NS]: apex = k
				var m := (apex + off) % NS
				var a := Trk.T[(m - 3 + NS) % NS]; var b := Trk.T[(m + 3) % NS]
				var cy := a.z * b.x - a.x * b.z
				out.append({"i0": (start + off) % NS, "i1": (q - 1 + off) % NS, "n": q - start, "apex": m, "dir": -1 if cy > 0 else 1, "kmax": Trk.CURV[m]})
			start = -1
	return out

## arrow boards on the outside of every tight bend, facing the driver who comes up to it. lat: how far out they stand
## (outside the wall); onGround: stand on the terrain. Their faces glow softly when the lamps are on (reflective).
static func chevrons(lat: float, curv := 0.016, every := 9.0, h := 1.25, onGround := false) -> Array:
	var NS := Trk.NS
	var bl := bends(curv)
	var per := {1: [], -1: []}
	var posts := []
	for b in bl:
		var n: int = b.n
		var cnt := clampi(int(n * Trk.SPC * 0.75 / every), 3, 8)
		for k in cnt:
			# from just before the bend to a little past its apex: where the driver looks while braking and turning in
			var i: int = ((b.i0 - 2 + int(round(k * every / Trk.SPC))) % NS + NS) % NS
			var l: float = -b.dir * lat
			var xz := Trk.onTrack(i, l)
			var y: float = (gy(xz[0], xz[1]) if onGround else Trk.hAt(i, l))
			# face the traffic: turned a little towards the inside of the bend
			var hd: float = Trk.heading_of(Trk.T[i]) + PI + b.dir * 0.35
			per[b.dir].append(World.mtx(xz[0], y + h + 0.45, xz[1], hd))
			posts.append(World.mtx(xz[0], y, xz[1], hd))
			World.pavTaken.append([xz[0], xz[1], 1.3])   # the roadside dressing keeps clear of the board
	for d in [1, -1]:
		if per[d].is_empty(): continue
		var m := Mats.M(0xffffff, {"map": chevronTex(d), "emissive": 0x000000, "emissiveMap": chevronTex(d)})
		World.lampMats.append(m)
		World.inst(Geo.plane(1.9, 0.9), m, per[d], null, false)
	if not posts.is_empty():
		# two posts (half a metre into the ground: the terrain slopes) and a grey back plate
		var ph := h + 1.4
		var pg := merge([[Geo.box(0.1, ph, 0.1).translate(-0.75, ph / 2.0 - 0.5, -0.12), 0x6a6f74], [Geo.box(0.1, ph, 0.1).translate(0.75, ph / 2.0 - 0.5, -0.12), 0x6a6f74],
			[Geo.box(1.98, 0.98, 0.04).translate(0, h + 0.45, -0.05), 0x50555a]])
		World.inst(pg, vmat(), posts, null, false)
	return bl

## reflector posts: a white post with a reflector that lights up at night, every `every` m at lateral offset lat on both sides
static func reflectors(lat: float, every := 18.0, onGround := false, sides := [-1, 1], filter = null) -> void:
	var NS := Trk.NS
	var pm := []; var rm := []
	var d := every * 0.5
	while d < Trk.TRACK_LEN:
		var i := int(round(d / Trk.SPC)) % NS
		d += every
		if filter != null and not filter.call(i): continue
		for s in sides:
			var xz := Trk.onTrack(i, s * lat)
			var y: float = gy(xz[0], xz[1]) if onGround else Trk.hAt(i, s * lat)
			var hd := Trk.heading_of(Trk.T[i])
			pm.append(World.mtx(xz[0], y + 0.5, xz[1], hd))
			rm.append(World.mtx(xz[0], y + 0.78, xz[1], hd))
	World.inst(Geo.box(0.12, 1.0, 0.1), Mats.M(0xeeeeea), pm, null, false)
	var refl := Mats.M(0xc84a1a, {"emissive": 0x000000})
	World.reflMats.append(refl)
	World.inst(Geo.box(0.14, 0.2, 0.12), refl, rm, null, false)

## a strip painted on the road over samples i0 .. i0+n (the texture once over its length, top of the texture ahead)
static func decal(i0: int, n: int, latA: float, latB: float, mat: Material, yOff := 0.11) -> MeshInstance3D:
	var NS := Trk.NS
	var g := Geo.new()
	for k in n + 1:
		var i := ((i0 + k) % NS + NS) % NS
		var p := Trk.P[i]; var r := Trk.R[i]
		g.pos.append(Vector3(p.x + r.x * latA, Trk.HT[i] + yOff, p.z + r.z * latA))
		g.pos.append(Vector3(p.x + r.x * latB, Trk.HT[i] + yOff, p.z + r.z * latB))
		var v := float(k) / n
		g.uv.append(Vector2(0, v)); g.uv.append(Vector2(1, v))
		if k < n:
			var A := k * 2
			g.idx.append_array([A, A + 1, A + 2, A + 1, A + 3, A + 2])
	g.compute_vertex_normals()
	var m := O3.mesh(g, mat)
	O3.receive(m)
	World.add(m)
	return m

## white text painted on the road (fans' paint on a climb): see-through texture with the text, upright for the driver
## on a decal() (the top of the texture lies ahead)
static func paintTex(text: String, color := "#f4f4ee") -> ImageTexture:
	return Canvas2D.tex(256, 128, func(g, w, h):
		g.clearRect(0, 0, w, h)
		g.fillStyle = color; g.font = "800 104px Barlow Condensed"; g.textAlign = "center"; g.textBaseline = "middle"
		g.fillText(text, w / 2.0, h / 2.0 + 4, w - 12))

## a mottled detail texture for grass, sand or stone (grey around white, so vertex or material colours keep their hue):
## soft round blotches, wrapped round the edges so the tile repeats without seams
static func noiseTex(size := 128, dots := 1400, dark := 0.16, light := 0.1, streaks := false) -> ImageTexture:
	return Canvas2D.tex(size, size, func(g, w, h):
		g.fillStyle = "#e9e9e9"; g.fillRect(0, 0, w, h)
		for _i in dots:
			var r: float = randf()
			g.fillStyle = "rgba(0,0,0,%f)" % (randf() * dark) if r < 0.6 else "rgba(255,255,255,%f)" % (randf() * light * 2.0)
			var x: float = randf() * w; var y: float = randf() * h
			var rx: float = 1.5 + randf() * randf() * 7; var ry: float = (0.8 + randf() * 1.5) if streaks else rx * (0.6 + randf() * 0.8)
			for ox in [0.0, -w, w]:
				if x + ox + rx < 0 or x + ox - rx > w: continue
				for oy in [0.0, -h, h]:
					if y + oy + ry < 0 or y + oy - ry > h: continue
					g.beginPath(); g.ellipse(x + ox, y + oy, rx, ry, 0, 0, TAU); g.fill(), true)

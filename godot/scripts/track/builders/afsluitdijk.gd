class_name BuildAfsluitdijk
## Port of buildAfsluitdijk (+ turbine) and detailAfsluitdijk from polderrace-3d.html. Same numbers, same seeded random
## order (World.rnd), so the decor lands where it does in the HTML game.

static func M(c: int, o: Dictionary = {}) -> LMat:
	return Mats.M(c, o)

static func rnd() -> float:
	return World.rnd.next()

## JS Math.round (halves go up, also for negative numbers)
static func jround(v: float) -> int:
	return int(floor(v + 0.5))

## JS turbBeacon: the blinking red light on top of every turbine (set by build(), Env blinks it via World.beaconMats)
static var turbBeacon: LMat = null

static func turbine(x: float, z: float, rot: float) -> void:
	var g := O3.group(x, 0, z)
	O3.rot(g, 0, rot, 0)
	var white := M(0xeef0f2)
	O3.mesh(Geo.cylinder(3, 3.2, 4, 12), M(0xe8c21c), 0, 1.6, 0, g)
	O3.mesh(Geo.cylinder(1.3, 2.2, 72, 12), white, 0, 39, 0, g, true)
	World.box(3, 3, 8, white, 0, 75, 0, g)
	if turbBeacon != null:
		World.box(0.6, 0.5, 0.6, turbBeacon, 0, 76.8, -2.5, g, false)
	var bl := O3.group(0, 75, 4.4, g)
	O3.mesh(Geo.sphere(1.4, 10, 8), white, 0, 0, 0, bl)
	for k in 3:
		var a := O3.group(0, 0, 0, bl)
		O3.rot(a, 0, 0, k * PI * 2 / 3)
		World.box(1.6, 32, 0.35, white, 0, 16.5, 0, a)
	O3.rot(bl, 0, 0, randf() * 6)
	bl.set_meta("speed", 0.7 + randf() * 0.3)
	World.sailGroups.append(bl)
	World.add(g)

## the lock under the bridge at the top of the dike (Kornwerderzand): [x0, x1, z of its closed end]; the dike's samples
## [g0, g1] where the road is a bridge (no grass slopes under it)
static var lock: Array = []
static var gap: Array = []

## one material per colour for this build: the parts of one group that share a material are merged into one draw
## call by World.batch (boats, lock, sluices)
static var _mm := {}
static func mm(c: int) -> LMat:
	if not _mm.has(c): _mm[c] = M(c)
	return _mm[c]

## basalt blocks of the revetments, green with algae towards the water line (v = 0)
static func basaltTex() -> ImageTexture:
	return Canvas2D.tex(128, 128, func(g, w, h):
		g.fillStyle = "#2f3332"; g.fillRect(0, 0, w, h)
		for r in 9:
			for c in 9:
				var x := c * 16.0 + (8.0 if r % 2 else 0.0)
				var y := r * 15.0
				g.fillStyle = "rgba(%d,%d,%d,1)" % [70 + randi() % 26, 74 + randi() % 24, 72 + randi() % 20]
				g.beginPath()
				for k in 6:
					var a := k * PI / 3 + PI / 6
					if k == 0: g.moveTo(x + cos(a) * 7.5, y + sin(a) * 7.5)
					else: g.lineTo(x + cos(a) * 7.5, y + sin(a) * 7.5)
				g.closePath(); g.fill()
		g.fillStyle = "rgba(60,78,40,.55)"; g.fillRect(0, h * 0.72, w, h * 0.28)
		g.fillStyle = "rgba(40,52,30,.5)"; g.fillRect(0, h * 0.88, w, h * 0.12), true)

## a sloping basalt revetment from the edge of the land (y = 0) 9 m out and 1.5 m down into the sea.
## edges: [[x0, z0, x1, z1, outward x, outward z], ...]
static func revetment(edges: Array) -> void:
	var g := Geo.new()
	for e in edges:
		var a := Vector3(e[0], 0.0, e[1]); var b := Vector3(e[2], 0.0, e[3])
		var o := Vector3(e[4] * 9.0, -1.5, e[5] * 9.0)
		var n := g.pos.size()
		var L := a.distance_to(b)
		g.pos.append_array([a, b, b + o, a + o])
		g.uv.append_array([Vector2(0, 1), Vector2(L / 9.0, 1), Vector2(L / 9.0, 0), Vector2(0, 0)])
		# counter-clockwise seen from above (three.js): the slope must face up
		var up := (g.pos[n + 1] - g.pos[n]).cross(g.pos[n + 2] - g.pos[n]).y > 0
		if up: g.idx.append_array([n, n + 1, n + 2, n, n + 2, n + 3])
		else: g.idx.append_array([n, n + 2, n + 1, n, n + 3, n + 2])
	g.compute_vertex_normals()
	var m := O3.mesh(g, M(0xffffff, {"map": basaltTex()}))
	O3.receive(m)
	World.add(m)

## a boat on the water: kind 0 fishing cutter, 1 sailing yacht, 2 small coaster
static func boat(parent: Node3D, x: float, z: float, rot: float, kind: int) -> void:
	var g := O3.group(x, -0.35, z, parent)
	O3.rot(g, 0, rot, 0)
	var white := mm(0xf3efe4)
	match kind:
		0:
			World.box(10, 1.6, 3.4, mm(World.pick([0x1d4f9e, 0x7a2a2a, 0x2f6b4a])), 0, 0.3, 0, g)
			World.box(3, 2.2, 2.6, white, -2, 2.2, 0, g)
			World.box(0.15, 6, 0.15, mm(0x5a5f63), 2, 4, 0, g)
			World.box(0.1, 0.1, 5.2, mm(0x5a5f63), 2, 5.2, 0, g, false)
		1:
			World.box(7, 1.0, 2.2, white, 0, 0.3, 0, g)
			World.box(2.4, 0.6, 1.6, mm(0xc9b48a), -0.6, 1.1, 0, g)
			O3.mesh(Geo.cylinder(0.07, 0.09, 9, 5), mm(0xd8d8d8), 0.8, 5.3, 0, g, true)
			var sl := O3.mesh(Geo.extrude([Vector2(0, 0), Vector2(3.8, 0), Vector2(0, 7.8)], 0.05), M(0xf7f5ee, {"side": "double"}), 0.85, 1.0, 0, g, true)
			var jib := O3.mesh(Geo.extrude([Vector2(0, 0), Vector2(-2.6, 0), Vector2(0, 6.6)], 0.05), M(World.pick([0xf2c200, 0xc8302a, 0xf7f5ee]), {"side": "double"}), 0.75, 1.0, 0, g, true)
		_:
			World.box(46, 3.2, 8, mm(World.pick([0x2b3a4a, 0x7a2a2a, 0x2f4a3a])), 0, 0.9, 0, g)
			World.box(46.2, 0.7, 8.2, mm(0x8a2020), 0, -0.4, 0, g)
			World.box(7, 6, 7.4, white, -17, 5.5, 0, g)
			World.box(7.2, 1.0, 7.6, mm(0x2c3a48), -17, 7.6, 0, g, false)
			World.box(30, 2.2, 7.6, mm(0x6c4a2a), 4, 3.6, 0, g)

## the Vlieter monument where the dike was closed in 1932, with the footbridge over the road to it (Godot only)
static func monument(i: int) -> void:
	var h := Trk.HT[i]
	var th := Trk.heading_of(Trk.T[i])
	# local +x of a group placed at i points to world (cos, -sin): the side of the lap's inside (lower z) gets the monument
	var inner := 1.0 if -sin(th) < 0 else -1.0
	var g := Node3D.new()
	var stone := mm(0xd9d3c3); var con := mm(0xb9b6ae); var steel := mm(0x5a6066)
	# the footbridge: deck 6 m above the road, a stair tower on both sides
	World.box(36, 0.7, 3, con, 0, 6.35, 0, g)
	for zz in [-1.45, 1.45]:
		World.box(36, 0.08, 0.08, steel, 0, 7.75, zz, g, false)
		World.box(36, 0.06, 0.06, steel, 0, 7.2, zz, g, false)
	var x := -17.0
	while x <= 17.0:
		for zz in [-1.45, 1.45]: World.box(0.07, 1.1, 0.07, steel, x, 7.2, zz, g, false)
		x += 2.0
	for sd in [-1.0, 1.0]:
		var foot := Trk.hAt(i, 20.6) - h - 0.4
		var top := 9.4
		World.box(3.6, top - foot, 3.6, con, sd * 19.6, (top + foot) / 2, 0, g)
		World.box(4.2, 0.4, 4.2, steel, sd * 19.6, top + 0.2, 0, g)
		World.box(0.1, 2.0, 1.2, mm(0x2c3a48), sd * 19.6 - sd * 1.81, 7.6, 0, g, false)
	# the monument on the inside: a tall white tower with a glass lookout, a wall with the relief, the stone setter's statue
	var mx := inner * 42.0
	var y0 := -h
	World.box(7, 22, 7, stone, mx, y0 + 11, 0, g)
	World.box(8, 1.0, 8, mm(0xbdb6a6), mx, y0 + 22.5, 0, g)
	var glass := M(0x9fb3c6, {"emissive": 0x000000})
	World.winMats.append(glass)
	O3.mesh(Geo.cylinder(3.0, 3.0, 2.6, 12), glass, mx, y0 + 24.3, 0, g, false)
	O3.mesh(Geo.cylinder(3.6, 3.6, 0.5, 12), mm(0xbdb6a6), mx, y0 + 25.85, 0, g, true)
	for k in 3:
		World.box(0.9, 6.5, 0.2, mm(0x2c3a48), mx, y0 + 6 + k * 6.5, 3.52, g, false)
		World.box(0.9, 6.5, 0.2, mm(0x2c3a48), mx, y0 + 6 + k * 6.5, -3.52, g, false)
	World.box(1.2, 3.6, 18, stone, mx - inner * 6, y0 + 1.8, -2, g)
	World.box(0.2, 2.2, 12, mm(0xa89f8a), mx - inner * 5.32, y0 + 2.0, -2, g, false)
	World.box(1.6, 1.4, 1.6, mm(0x8a8478), mx - inner * 9, y0 + 0.7, 7, g)
	O3.mesh(Geo.cylinder(0.32, 0.4, 1.7, 6), mm(0x4a5048), mx - inner * 9, y0 + 2.25, 7, g, true)
	O3.mesh(Geo.sphere(0.26, 6, 5), mm(0x4a5048), mx - inner * 9, y0 + 3.3, 7, g, false)
	# a path from the stair tower to the tower
	World.box(18, 0.1, 2.6, mm(0xb8ab90), inner * 30.5, y0 + 0.03, 0, g, false)
	World.place(g, i, 0, 0)
	var c := Trk.onTrack(i, 0)
	var tx: float = c[0] + cos(th) * mx
	var tz: float = c[1] - sin(th) * mx
	World.noDress.append([minf(c[0], tx) - 14, minf(c[1], tz) - 14, maxf(c[0], tx) + 14, maxf(c[1], tz) + 14])

## is the point lat metres beside sample i nearer to its own piece of road than to any other (see BuildPolder.own)?
static func own(i: int, lat: float) -> bool:
	var xz := Trk.onTrack(i, lat)
	return Trk.distToTrack(xz[0], xz[1]) > absf(lat) - Trk.EMB[i] - 1.5

## several geometries as one (each keeps its vertex colours)
static func joinGeo(parts: Array) -> Geo:
	var g := Geo.new()
	for p in parts:
		var o := g.pos.size()
		g.pos.append_array(p.pos); g.nrm.append_array(p.nrm); g.uv.append_array(p.uv); g.col.append_array(p.col)
		for k in p.idx: g.idx.append(k + o)
	return g

## the sample nearest to a world point (on the dike: only samples higher than minH)
static func nearest(x: float, z: float, minH := -1.0) -> int:
	var b := 1e18; var bi := 0
	for i in Trk.NS:
		if Trk.HT[i] < minH: continue
		var d := (Trk.P[i].x - x) * (Trk.P[i].x - x) + (Trk.P[i].z - z) * (Trk.P[i].z - z)
		if d < b: b = d; bi = i
	return bi

## the lock under the bridge: quay walls with bollards, mitre gates towards the sea, a discharge sluice at its closed end
## and a cutter waiting in it
static func lockWorks() -> void:
	var x0: float = lock[0]; var x1: float = lock[1]; var ze: float = lock[2]
	var cx := (x0 + x1) / 2
	var con := mm(0x9c9b95); var dark := mm(0x2f3336); var steel := mm(0x5a6066)
	var g := World.add(Node3D.new())
	var zl := 34.0 - (ze - 1.0)
	for x in [x0 - 0.6, x1 + 0.6]:
		World.box(1.2, 2.5, zl, con, x, -1.0, (34.0 + ze - 1.0) / 2, g)
	World.box(x1 - x0 + 2.4, 2.5, 1.2, con, cx, -1.0, ze - 0.6, g)
	var bol := []
	var z := ze + 6
	while z < 32:
		for x in [x0 - 0.7, x1 + 0.7]: bol.append(World.mtx(x, 0.55, z))
		z += 12
	World.inst(Geo.cylinder(0.2, 0.24, 0.6, 8), M(0x2b2f36), bol, null, false)
	# the sluice at the closed end: four piers with their machine houses, three gates between them, a walkway on top
	for k in 4:
		var px := x0 + 1.5 + k * (x1 - x0 - 3) / 3.0
		World.box(3, 9.5, 6, con, px, 3.25, ze + 3, g)
		World.box(3.6, 3, 5, mm(0xd9d3c3), px, 9.5, ze + 3, g)
		World.box(3.7, 0.4, 5.4, steel, px, 11.2, ze + 3, g, false)
		if k < 3:
			World.box((x1 - x0 - 3) / 3.0 - 3 + 0.2, 4.2, 0.6, dark, px + (x1 - x0 - 3) / 6.0, 2.0, ze + 3, g)
	World.box(x1 - x0 + 1, 0.5, 2.4, steel, cx, 7.3, ze + 3 + 3.25, g, false)
	# mitre gates towards the sea, a little open
	for sd in [-1.0, 1.0]:
		var gt := World.box(14.6, 2.8, 0.7, dark, cx + sd * 7.0, -0.7, 27.5, g, false)
		O3.rot(gt, 0, sd * 0.18, 0)
	boat(g, cx + 2, -36, PI / 2 + 0.05, 0)

## the old sluices at the end of the dike (Den Oever): six piers in the water, a tower on every pier, gates between them
static func sluices() -> void:
	var con := mm(0x9c9c96); var dark := mm(0x2f3336); var tower := mm(0xcfc8b6)
	var g := World.add(Node3D.new())
	var win := M(0xf3efe4)
	World.winMats.append(win)
	for k in 6:
		var z := -150.0 + k * 20
		World.box(18, 9.5, 4, con, -158, 3.25, z, g)
		World.box(5, 7, 5, tower, -160, 11.5, z, g)
		var r := TrackCommon.roofMesh(5.6, 2.4, 5.6, mm(0x39404a))
		r.position = Vector3(-160, 15, z)
		g.add_child(r)
		World.box(0.2, 1.4, 1.0, win, -157.42, 12.5, z, g, false)
		if k < 5:
			World.box(0.7, 4.6, 16.2, dark, -156, 1.6, z + 10, g, false)
	World.box(4.2, 0.7, 104, mm(0x8d8a82), -151.5, 8.35, -100, g)

static func build() -> void:
	_mm = {}
	var NS := Trk.NS
	var T := Trk.T
	var HT := Trk.HT
	var EMB := Trk.EMB
	var RH := Trk.ROAD_HALF
	var SH := Trk.SHOULDER
	# ---- where the road crosses the lock: a bridge at the top of the dike (the track's "brug over de sluizen")
	var ib := 0
	for i in NS:
		if HT[i] > HT[ib]: ib = i
	var cx: float = Trk.P[ib].x
	lock = [cx - 14.0, cx + 14.0, -78.0]
	var g0 := ib; var g1 := ib
	while HT[(g0 - 1 + NS) % NS] > 3 and absf(Trk.P[(g0 - 1 + NS) % NS].x - cx) < 30: g0 -= 1
	while HT[(g1 + 1) % NS] > 3 and absf(Trk.P[(g1 + 1) % NS].x - cx) < 30: g1 += 1
	gap = [g0, g1]
	var onBridge := func(i): return i >= g0 and i <= g1
	var solid := func(i): return i < g0 or i > g1
	World.noDress.append([lock[0] - 2, lock[2] - 2, lock[1] + 2, 60.0])
	# and the sea round the land (where the dike at the bridge reaches past the edge of the land)
	World.noDress.append_array([[-400.0, 34.0, 2300.0, 400.0], [-400.0, -600.0, 2300.0, -247.0], [-400.0, -600.0, -142.0, 400.0]])
	TrackCommon.waterPlane(6000, 6000, 900, -100, -0.35, 0x4c7090)
	# the land between the two roads, in three pieces around the lock; it ends at x = -140, where the old sluices stand in the water
	var landTex := BuildPolder.grassTex("#69954a", "rgba(40,80,25,.18)", "rgba(205,225,140,.12)")
	TrackCommon.landPlane(landTex, -140, -245, lock[0], 32, 20, 40)
	TrackCommon.landPlane(landTex, lock[1], -245, 2080, 32, 20, 40)
	TrackCommon.landPlane(landTex, lock[0], -245, lock[1], lock[2], 20, 40)
	revetment([[-140, 32, lock[0], 32, 0, 1], [lock[1], 32, 2080, 32, 0, 1], [-140, -245, 2080, -245, 0, -1],
		[-140, -245, -140, 32, -1, 0], [2080, -245, 2080, 32, 1, 0]])
	var grass := M(0xffffff, {"map": BuildPolder.grassTex("#6e9a4a", "rgba(40,80,25,.16)", "rgba(205,225,140,.12)")})
	var slope := M(0xffffff, {"map": BuildPolder.grassTex("#66924a", "rgba(40,80,25,.2)", "rgba(205,225,140,.13)"), "repeat": Vector2(2, 1)})
	var rail := M(0xffffff, {"map": TrackCommon.railTex()})
	World.ribbon(-RH, RH, World.roadMat(World.roadTexture("#5d5f62", [1.0 / 3, 2.0 / 3], true, false, 0.25)), 12, 0.07)
	World.ribbon(-SH, -RH, grass, 10, 0.05)
	World.ribbon(RH, SH, grass, 10, 0.05)
	World.ribbon(func(i): return -(SH + EMB[i]), -SH, slope, 14, 0.05, solid)
	World.ribbon(SH, func(i): return SH + EMB[i], slope, 14, 0.05, solid)
	# the cycle path along the outside, at the foot of the dike (red asphalt, 3.5 cm above the land); it stops where the
	# inside of a tight bend would fold it over the road further on, and under the bridge
	World.ribbon(func(i): return SH + EMB[i] + 1, func(i): return SH + EMB[i] + 3.6, M(0x8e4438), 6, 0.065,
		func(i): return solid.call(i) and own(i, SH + EMB[i] + 3.6) and own((i + 1) % NS, SH + EMB[(i + 1) % NS] + 3.6))
	World.vribbon(-9.2, 0.15, 0.9, rail, 4)
	World.vribbon(9.2, 0.15, 0.9, M(0xffffff, {"map": TrackCommon.railTex()}), 4)
	# ---- the bridge: deck edges and underside, abutments where the dike stops, piers beside the lock
	var con := M(0xa8a7a1, {"side": "double"})
	World.ribbon(-9.35, 9.35, con, 8, -1.2, onBridge)
	World.vribbon(-9.35, -1.2, 0.1, con, 8, onBridge)
	World.vribbon(9.35, -1.2, 0.1, con, 8, onBridge)
	var br: Node3D = World.add(Node3D.new())
	for i in [g0, (g1 + 1) % NS]:
		var ab := Geo.new()
		var lats := [-(SH + EMB[i]) - 0.5, -SH, -RH, RH, SH, SH + EMB[i] + 0.5]
		for l in lats:
			var xz := Trk.onTrack(i, l)
			ab.pos.append(Vector3(xz[0], Trk.hAt(i, l) - 0.02, xz[1])); ab.pos.append(Vector3(xz[0], -0.8, xz[1]))
			ab.uv.append(Vector2(l / 6.0, 1)); ab.uv.append(Vector2(l / 6.0, 0))
		for k in lats.size() - 1:
			var A := k * 2
			ab.idx.append_array([A, A + 1, A + 2, A + 1, A + 3, A + 2])
		ab.compute_vertex_normals()
		O3.receive(O3.mesh(ab, con, 0, 0, 0, br))
	for i in range(g0, g1 + 1):
		var a := Trk.P[i].x - cx
		var b := Trk.P[(i + 1) % NS].x - cx
		for edge in [-14.5, 14.5]:
			if (a - edge) * (b - edge) <= 0:
				# from 1 m under the water line to just under the deck (its underside is 1.2 m under the road)
				var pier := World.box(17, HT[i] + 1.0 - 1.18, 2.2, mm(0x9c9b95), Trk.P[i].x, (HT[i] - 1.18 - 1.0) / 2, Trk.P[i].z, br)
				O3.rot(pier, 0, Trk.heading_of(T[i]), 0)
	lockWorks()
	World.startLine()
	World.gates(Trk.TRK)
	turbBeacon = M(0x551010, {"emissive": 0x220000})
	World.beaconMats.append(turbBeacon)
	var tx := -120
	while tx <= 1950:
		turbine(tx, 175 + randf() * 20, -PI / 2)
		tx += 230
	tx = -40
	while tx <= 1900:
		turbine(tx, -480 - randf() * 20, -PI / 2)
		tx += 270
	# a lighthouse-like tower on the dike
	if true:
		var g := O3.group(1745, 0, -105)
		var st := M(0x8d8a82)
		O3.mesh(Geo.cylinder(4, 4.6, 20, 16), st, 0, 10, 0, g, true)
		O3.mesh(Geo.cylinder(6, 6, 1.2, 16), M(0x5a5a58), 0, 20.6, 0, g)
		O3.mesh(Geo.cylinder(3, 3, 3, 16), M(0xb7c3cc, {"transparent": true, "opacity": 0.7}), 0, 22.7, 0, g)
		World.add(g)
	sluices()
	monument(nearest(450, 0, 3))
	# sheep: body, head and legs in one mesh with vertex colours (one draw call per cell instead of three)
	var sheep := []
	for _k in 90:
		var x := 40 + rnd() * 1600
		var z := -180 + rnd() * 160
		if Trk.distToTrack(x, z) < 12 + rnd() * 6: continue
		if Dress._kept(x, z): continue
		sheep.append(Transform3D(Basis(Vector3.UP, rnd() * 6.28), Vector3(x, 0, z)))
	var wool := Color("#efece2"); var black := Color("#232120")
	# head top 3 cm above the back, not in its plane
	var parts := [Geo.box(0.8, 0.8, 1.3).translate(0, 0.75, 0).set_color(wool), Geo.box(0.35, 0.4, 0.45).translate(0, 0.98, 0.75).set_color(black)]
	for lxz in [[-0.26, 0.42], [0.26, 0.42], [-0.26, -0.42], [0.26, -0.42]]:
		parts.append(Geo.box(0.13, 0.4, 0.13).translate(lxz[0], 0.19, lxz[1]).set_color(black))
	World.inst(joinGeo(parts), M(0xffffff, {"vertexColors": true}), sheep, null, true)
	# street lights along the dike
	if true:
		var pm := M(0x8d9398)
		var hm := M(0x333a40, {"emissive": 0x222222})
		World.lampMats.append(hm)
		var lp := []; var lh := []; var la := []
		var d := 30.0
		while d < Trk.TRACK_LEN:
			var i := jround(d / Trk.SPC) % NS
			var xz := Trk.onTrack(i, -8.9)
			var h := HT[i]
			lp.append(World.mtx(xz[0], h + 5, xz[1]))
			var hxz := Trk.onTrack(i, -7.4)
			lh.append(World.mtx(hxz[0], h + 10, hxz[1], Trk.heading_of(T[i])))
			var axz := Trk.onTrack(i, -8.2)
			la.append(World.mtx(axz[0], h + 10.1, axz[1], Trk.heading_of(T[i]), 1.7, 0.12, 0.12))
			var pxz := Trk.onTrack(i, -3)
			World.trackLights.append([pxz[0], h, pxz[1], 11])
			d += 90
		World.inst(Geo.cylinder(0.1, 0.14, 10, 6), pm, lp, null, true)
		World.inst(Geo.box(0.5, 0.25, 1.6), hm, lh, null, false)
		World.inst(Geo.box(1, 1, 1), pm, la, null, false)
	TrackCommon.signs([["Den Oever", "4"], ["Kornwerderzand", "28"], ["Harlingen", "41"], ["Leeuwarden", "66"]], 10.2)

## JS detailAfsluitdijk: the Kornwerderzand gate frames over the bridge, breakwater blocks and fishing boats
static func details() -> void:
	var NS := Trk.NS
	var HT := Trk.HT
	var ib := 0
	for i in NS:
		if HT[i] > HT[ib]: ib = i
	var con := M(0x9c9c96)
	var dark := M(0x2f3336)
	var h := HT[ib]
	for off in [-28, 28]:
		var i := (ib + jround(off / Trk.SPC) + NS) % NS
		var g := Node3D.new()
		for s in [-1, 1]:
			World.box(4, h + 14, 4, con, s * 12.5, (h + 14) / 2 - h, 0, g)
			World.box(4.4, 1, 4.4, M(0x5a5f63), s * 12.5, 14.5, 0, g)
			World.box(1.2, 2, 0.1, dark, s * 12.5, 9, 2.05, g, false)
		World.box(29, 1.6, 3, con, 0, 13.5, 0, g)
		var sg := Canvas2D.tex(512, 96, func(c, w, hh):
			c.fillStyle = "#1d4f9e"; c.fillRect(0, 0, w, hh); c.fillStyle = "#f7f7f2"
			c.font = "800 54px Barlow Condensed"; c.textAlign = "center"; c.textBaseline = "middle"
			c.fillText("KORNWERDERZAND", w / 2.0, hh / 2.0 + 2))
		var b := O3.mesh(Geo.box(12, 1.4, 0.1), M(0xffffff, {"map": sg}), 0, 13.5, 1.56 if off < 0 else -1.56, g)
		if off > 0: O3.rot(b, 0, PI, 0)
		World.place(g, i, 0, 0)
	var bm := []
	for k in 7:
		var i := jround(NS * (0.05 + k * 0.055)) % NS
		if HT[i] < 4: continue
		var xz := Trk.onTrack(i, 26)
		if Dress._kept(xz[0], xz[1]): continue
		bm.append(World.mtx(xz[0], 0.9, xz[1], Trk.heading_of(Trk.T[i])))
	World.inst(Geo.box(5, 1.8, 4), con, bm, null, true)
	var fleet: Node3D = World.add(Node3D.new())
	for k in 4:
		boat(fleet, 700 + k * 170, -330 - rnd() * 80, rnd() * 6, 0)
	# yachts on the IJsselmeer, coasters on the Wadden Sea
	for k in 7:
		boat(fleet, 120 + k * 250 + rnd() * 80, -280 - rnd() * 140, rnd() * 6, 1)
	for k in 3:
		boat(fleet, 200 + k * 620 + rnd() * 120, 75 + rnd() * 60, (rnd() - 0.5) * 0.4, 2)
	TrackCommon.chevrons(10.6)

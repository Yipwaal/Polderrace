class_name Vehicles
## The traffic vehicles: hatchback, delivery van, articulated truck, farm tractor.
## Each returns a rig like CarKit.buildCar: g, wheels ({pivot, spin, r, w, style, mesh}), len, wid, rc, off, beam, blob,
## tail + lights (CarKit.setLights works on them), paint.
## The hatchback and the van are body kits like the cars (Cars.CAR_SPECS "city" and "van"); truck and tractor are built here
## from a few accumulators: one mesh per material (paint, detail, glass, lamps, tail lamps, plate).
## makeTruck picks its colours with World.pick, i.e. the track's seeded random while a track is built (haven parks trucks).

const VAN_COLORS := [0xecece8, 0xecece8, 0xf2c200, 0x8a8f96, 0x2f6db3]

## plain vehicle materials take no shadows, like the cars (CarKit._M)
static func M(c: int, o: Dictionary = {}) -> LMat:
	return CarKit._M(c, o)

static func sc(hex: int, shine := 0.1) -> Color:
	return CarBody.sc(hex, shine)

static func buildHatchTraffic(color) -> Dictionary:
	return CarKit.buildCar("city", color, true)

static func makeVan(color = null) -> Dictionary:
	var m := CarKit.buildCar("van", color if color != null else VAN_COLORS[int(randf() * VAN_COLORS.size())], true)
	m.paint.finish = "satin"
	return m

## height of a rig (for cameras and tests)
static func heightOf(m: Dictionary) -> float:
	var h := 0.0
	for o in m.g.find_children("*", "MeshInstance3D", true, false):
		if o == m.get("beam") or o == m.get("blob"): continue
		var t: Transform3D = o.transform
		var p: Node = o.get_parent()
		while p != m.g and p is Node3D:
			t = p.transform * t
			p = p.get_parent()
		h = maxf(h, (t * o.get_aabb()).end.y)
	return h

## a flat face: corners counter-clockwise seen from outside (bottom-left, bottom-right, top-right, top-left); cell = atlas
static func face(A: CarAcc, a: Vector3, b: Vector3, c: Vector3, d: Vector3, cell := "") -> void:
	var n := (b - a).cross(d - a).normalized()
	var n0 := A.P.size()
	A.tri(a, b, c, n, n, n, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1))
	A.tri(a, c, d, n, n, n, Vector2(0, 0), Vector2(1, 1), Vector2(0, 1))
	if cell != "": CarKit.uvCell(A, n0, cell)

## an upright panel facing +x (sx = 1) or -x: z0..z1, y0..y1 at x
static func sidePanel(A: CarAcc, sx: float, x: float, z0: float, z1: float, y0: float, y1: float, cell := "") -> void:
	if sx > 0: face(A, Vector3(x, y0, z1), Vector3(x, y0, z0), Vector3(x, y1, z0), Vector3(x, y1, z1), cell)
	else: face(A, Vector3(-x, y0, z0), Vector3(-x, y0, z1), Vector3(-x, y1, z1), Vector3(-x, y1, z0), cell)

## a panel facing +z (front) or -z (rear) at z: x0..x1 (left to right as you look at it from outside), y0..y1
static func endPanel(A: CarAcc, front: bool, z: float, x0: float, x1: float, y0: float, y1: float, cell := "") -> void:
	if front: face(A, Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z), cell)
	else: face(A, Vector3(x1, y0, z), Vector3(x0, y0, z), Vector3(x0, y1, z), Vector3(x1, y1, z), cell)

## a body shape cut from a side outline [[z, y], ...] (clockwise seen from the car's right), `width` wide
static func slab(A: CarAcc, pts: Array, width: float) -> void:
	CarKit.finPlate(A, pts, 0, width)

## the rig of a hand-built vehicle from its accumulators
static func _rig(D: Dictionary, color, wheels_at: Array, length: float, wid: float, rc: float, off: float, beamZ: float, beamW: float) -> Dictionary:
	var g := Node3D.new()
	var shell := Node3D.new()
	shell.name = "shell"
	g.add_child(shell)
	var paint := CarPaint.paint(CarKit._col(color), "satin")
	var pm := CarKit.Mb.new()
	pm.acc(D.paint, Color(1, 1, 1, 0))
	var body := CarKit.mesh(shell, pm.build(), paint, true)
	var det := CarKit.mesh(shell, D.det.build(), CarKit.detailMat, true)
	var gm := CarKit.Mb.new()
	gm.acc(D.glass, Color.WHITE)
	var glass := CarKit.mesh(shell, gm.build(), CarKit.carGlass)
	var lamp := CarKit.mesh(shell, D.lamp.build(), CarKit.lampMat)
	var tail := CarKit.mesh(shell, D.tail.build(), CarKit.tailMat)
	var plate := CarKit.mesh(shell, D.plate.build(), CarKit.carPlate)
	if plate != null: plate.visibility_range_end = 120.0
	var wheels := []
	for w in wheels_at:
		wheels.append(CarKit.addWheel(g, w[0], w[2], w[1], w[2], w[3], w[4] if w.size() > 4 else "steel", null, w[5] if w.size() > 5 else null))
	return {"g": g, "shell": shell, "wheels": wheels, "len": length, "wid": wid, "rc": rc, "off": off, "beam": CarKit.addBeam(g, beamZ, beamW),
		"blob": CarKit.addBlob(g, length, wid, off), "paint": paint, "body": body, "detail": det, "glass": glass, "lamp": lamp, "tail": tail, "plate": plate,
		"lights": {"brake": false, "rev": false}}

static func _sets() -> Dictionary:
	var D := {}
	for k in ["paint", "det", "glass", "lamp", "tail", "plate"]:
		D[k] = CarAcc.new()
	return D

## cab-over tractor unit with a container trailer
static func makeTruck() -> Dictionary:
	var cabCol: int = World.pick([0xd62a2a, 0xecece8, 0x2f6db3, 0x2f8f5b])
	var contCol: int = World.pick([0xc4452a, 0x1d4f9e, 0x3f7d3a, 0xd9a21b, 0x8a8f96, 0xecece8])
	var D := _sets()
	var P: CarAcc = D.paint
	var T: CarAcc = D.det
	var cDark := sc(0x17191c, 0.2)
	var cFrame := sc(0x222428, 0.15)
	var cGlass := sc(0x0e141a, 0.9)
	# cab: slanted screen, roof deflector
	slab(P, [[6.4, 0.7], [6.42, 1.55], [6.36, 1.7], [6.12, 3.02], [5.95, 3.2], [4.1, 3.2], [4.06, 0.7]], 2.44)
	slab(P, [[5.9, 3.2], [5.55, 3.62], [4.2, 3.72], [4.12, 3.2]], 2.2)
	for sx in [1.0, -1.0]:
		CarKit.finPlate(P, [[5.75, 3.2], [4.3, 3.66], [4.15, 3.2]], sx * 1.1, 0.06)
	# bumper, steps, grille surround, sun visor
	T.color(cDark).box(2.5, 0.42, 0.3, 0, 0.62, 6.34)
	T.box(2.46, 0.1, 0.42, 0, 3.02, 6.2, 0.2)
	for sx in [1.0, -1.0]:
		T.color(cDark).box(0.08, 0.5, 0.3, sx * 1.2, 0.72, 4.3)
		# mirrors on arms
		T.color(cDark).box(0.3, 0.04, 0.04, sx * 1.36, 2.72, 6.12)
		T.box(0.07, 0.46, 0.2, sx * 1.5, 2.5, 6.1)
		T.color(sc(0x93a4b2, 0.95))
		endPanel(T, false, 5.995, sx * 1.5 - 0.03, sx * 1.5 + 0.03, 2.3, 2.7)
		# door seam and handle
		T.color(cDark).box(0.012, 1.9, 0.02, sx * 1.224, 1.9, 4.5)
		T.box(0.012, 0.02, 0.9, sx * 1.224, 0.98, 4.95)
		T.color(sc(0x2a2c30, 0.4)).box(0.03, 0.05, 0.16, sx * 1.23, 1.5, 4.66)
		# side glass (dark mirror glass: the cab is solid)
		T.color(cGlass)
		sidePanel(T, sx, 1.225, 4.75, 5.95, 1.85, 2.72)
	# windscreen on the slanted face, with a dark frame
	var n := Vector3(0, 0.18, 1).normalized()
	var a := Vector3(0, 1.74, 6.353) + n * 0.012
	var b := Vector3(0, 2.94, 6.134) + n * 0.012
	T.color(cGlass)
	face(T, a + Vector3(-1.1, 0, 0), a + Vector3(1.1, 0, 0), b + Vector3(1.1, 0, 0), b + Vector3(-1.1, 0, 0))
	T.color(cDark)
	for sx in [1.0, -1.0]:
		CarKit.bar(T, a + Vector3(sx * 0.5, 0, 0.01), a + Vector3(sx * 0.5 - 0.45, 0.55, -0.09), 0.03, 0.02)
	# grille and lamps from the atlas
	endPanel(D.lamp, true, 6.43, -0.85, 0.85, 0.9, 1.5, "g_truck")
	for sx in [1.0, -1.0]:
		endPanel(D.lamp, true, 6.495, minf(sx * 0.72, sx * 1.16), maxf(sx * 0.72, sx * 1.16), 0.5, 0.74, "h_van")
		endPanel(D.lamp, true, 6.43, minf(sx * 0.95, sx * 1.18), maxf(sx * 0.95, sx * 1.18), 1.0, 1.12, "amber")
	endPanel(D.plate, true, 6.5, -0.26, 0.26, 0.56, 0.68)
	# chassis, fuel tanks, fifth wheel, cab back wall
	T.color(cFrame).box(1.1, 0.3, 7.2, 0, 0.82, 3.0)
	T.box(2.3, 0.12, 1.3, 0, 1.05, 3.3)
	for sx in [1.0, -1.0]:
		var tank := Geo.cylinder(0.3, 0.3, 1.3, 14); tank.rotate_x(PI / 2); tank.translate(sx * 0.92, 0.72, 3.5)
		T.color(sc(0xb9bec4, 0.85)).geo(tank)
		T.color(cDark).box(0.5, 0.06, 0.9, sx * 1.02, 1.08, 5.1)     # front mudguards
	# trailer: container on a frame, ribs, rear doors with lock bars, landing legs, underride bar, mud flaps
	var cc := sc(contCol, 0.12)
	var cr := sc(contCol, 0.12).darkened(0.16)
	cr.a = 0.12
	T.color(cc).box(2.48, 2.65, 10.6, 0, 2.5, -1.5)
	T.color(cr)
	for k in 9:
		var z := 3.4 - k * 1.22
		for sx in [1.0, -1.0]:
			T.box(0.03, 2.5, 0.09, sx * 1.25, 2.5, z)
	T.box(2.52, 0.12, 10.64, 0, 3.86, -1.5)
	T.box(2.52, 0.14, 10.64, 0, 1.2, -1.5)
	T.color(cFrame).box(1.2, 0.26, 10.2, 0, 1.0, -1.7)
	for sx in [1.0, -1.0]:
		T.box(0.12, 0.75, 0.12, sx * 0.7, 0.5, 1.6)                  # landing legs
		T.color(cDark).box(0.62, 0.5, 0.03, sx * 0.98, 0.5, -6.55)   # mud flaps
		T.color(cFrame)
	T.color(cDark).box(2.4, 0.12, 0.1, 0, 0.6, -6.8)
	T.color(sc(0xc8ccd0, 0.8))
	for x in [-0.75, -0.25, 0.25, 0.75]:
		T.box(0.04, 2.5, 0.04, x, 2.5, -6.82)
	T.color(cr).box(0.02, 2.55, 0.03, 0, 2.5, -6.81)
	for sx in [1.0, -1.0]:
		endPanel(D.tail, false, -6.86, minf(sx * 0.72, sx * 1.14), maxf(sx * 0.72, sx * 1.14), 0.78, 0.96, "t_tri")
		# amber side markers
		for z in [-5.5, -2.5, 0.5, 3.0]:
			sidePanel(D.lamp, sx, 1.262, z - 0.08, z + 0.08, 1.16, 1.24, "amber")
	endPanel(D.plate, false, -6.86, 0.26, -0.26, 0.98, 1.1)
	var wh := []
	for xz in [[-1.05, 5.1], [1.05, 5.1], [-1.05, -4.8], [1.05, -4.8], [-1.05, -5.9], [1.05, -5.9], [-1.05, 3.3], [1.05, 3.3]]:
		wh.append([xz[0], xz[1], 0.5, 0.35])
	return _rig(D, cabCol, wh, 13.6, 2.5, 0.12, -0.2, 6.4, 2.5)

static func makeTractor() -> Dictionary:
	var D := _sets()
	var P: CarAcc = D.paint
	var T: CarAcc = D.det
	var cDark := sc(0x17191c, 0.2)
	var cYel := sc(0xe8c21c, 0.4)
	# bonnet (rounded on top), nose grille, frame, front weights
	slab(P, [[1.95, 0.9], [1.98, 1.5], [1.9, 1.66], [1.6, 1.74], [0.0, 1.8], [-0.2, 1.72], [-0.2, 0.9]], 0.96)
	for sx in [1.0, -1.0]:
		CarKit.finPlate(T.color(sc(0x17191c, 0.2)), [[1.9, 1.5], [1.9, 1.44], [-0.1, 1.44], [-0.1, 1.5]], sx * 0.47, 0.03)
	T.color(cDark).box(0.7, 0.5, 2.3, 0, 0.72, 0.8)
	T.color(sc(0x2a2c30, 0.3)).box(0.9, 0.3, 0.34, 0, 0.74, 2.16)
	endPanel(D.lamp, true, 1.99, -0.38, 0.38, 0.98, 1.5, "g_truck")
	for sx in [1.0, -1.0]:
		endPanel(D.lamp, true, 1.995, minf(sx * 0.2, sx * 0.44), maxf(sx * 0.2, sx * 0.44), 1.52, 1.64, "h_van")
		# yellow stripe along the bonnet
		T.color(cYel).box(0.012, 0.1, 1.7, sx * 0.486, 1.52, 0.9)
		# rear mudguards over the big wheels
		var fg := Geo.cylinder(1.08, 1.08, 0.56, 16, 1, true, -0.25, PI * 0.82); fg.rotate_z(PI / 2); fg.translate(sx * 1.02, 0.95, -0.9)
		P.geo(fg)
		var fg2 := fg.clone()
		for i in fg2.nrm.size(): fg2.nrm[i] = -fg2.nrm[i]
		fg2.idx = CarKit._flip(fg2.idx)
		T.color(cDark).geo(fg2)
		# tail lamps and reflectors on the mudguards
		endPanel(D.tail, false, -1.97, minf(sx * 0.82, sx * 1.2), maxf(sx * 0.82, sx * 1.2), 1.42, 1.56, "t_tri")
	# exhaust stack
	var ex := Geo.cylinder(0.045, 0.045, 1.0, 10); ex.translate(0.36, 2.25, 1.3)
	T.color(sc(0x2a2c30, 0.5)).geo(ex)
	# cab: floor, posts, roof, glass all round, seat and driver, steering wheel
	P.box(1.5, 0.5, 1.5, 0, 1.25, -0.9)
	T.color(cDark)
	for xz in [[-0.72, -0.2], [0.72, -0.2], [-0.72, -1.6], [0.72, -1.6]]:
		T.box(0.08, 1.75, 0.08, xz[0], 2.36, xz[1])
	P.box(1.72, 0.14, 1.62, 0, 3.3, -0.9)
	T.color(sc(0xecece8, 0.3)).box(1.6, 0.05, 1.5, 0, 3.21, -0.9)
	for sx in [1.0, -1.0]:
		sidePanel(D.glass, sx, 0.73, -1.56, -0.24, 1.52, 3.2)
	endPanel(D.glass, true, -0.19, -0.68, 0.68, 1.82, 3.2)
	endPanel(D.glass, false, -1.61, -0.68, 0.68, 1.52, 3.2)
	T.color(sc(0x2a2c31, 0.15)).box(0.5, 0.12, 0.48, 0, 1.6, -1.0)
	T.box(0.46, 0.6, 0.1, 0, 1.95, -1.26, -0.12)
	var tw := Geo.torus(0.19, 0.022, 6, 14); tw.rotate_x(-0.7); tw.translate(0, 2.05, -0.5)
	T.color(sc(0x0c0d0f, 0.2)).geo(tw)
	T.box(0.05, 0.5, 0.05, 0, 1.8, -0.42, 0.5)
	var hel := Geo.sphere(0.13, 10, 8); hel.translate(0, 2.42, -1.02)
	T.color(sc(0xd8b08c, 0.2)).geo(hel)                          # the farmer (no helmet), cap, overalls
	T.color(sc(0x2f6db3, 0.15)).box(0.24, 0.07, 0.3, 0, 2.53, -0.98)
	T.color(sc(0x35506e, 0.1)).box(0.42, 0.5, 0.22, 0, 2.05, -1.08, -0.1)
	for sd in [1.0, -1.0]:
		CarKit.bar(T, Vector3(sd * 0.2, 2.2, -1.0), Vector3(sd * 0.17, 2.08, -0.55), 0.09, 0.09)
	# beacon, plate, hitch, slow-vehicle triangle
	var bc := Geo.cylinder(0.1, 0.1, 0.16, 10); bc.translate(0.5, 3.45, -0.5)
	var n0: int = D.lamp.P.size()
	D.lamp.geo(bc); CarKit.uvCell(D.lamp, n0, "amber", true)
	endPanel(D.plate, false, -1.67, 0.26, -0.26, 1.2, 1.32)
	T.color(cDark).box(0.3, 0.12, 0.5, 0, 0.7, -1.8)
	T.color(sc(0xe8501e, 0.3))
	var tn := Vector3(0, 0, -1)
	T.tri(Vector3(0.3, 1.5, -1.672), Vector3(-0.3, 1.5, -1.672), Vector3(0, 2.0, -1.672), tn, tn, tn)
	var wh := [[-0.8, 1.35, 0.5, 0.3, "tractor", 0xe8c21c], [0.8, 1.35, 0.5, 0.3, "tractor", 0xe8c21c],
		[-1.05, -0.9, 0.95, 0.5, "tractor", 0xe8c21c], [1.05, -0.9, 0.95, 0.5, "tractor", 0xe8c21c]]
	return _rig(D, 0x3f7d3a, wh, 3.9, 2.6, 0.2, 0.0, 1.9, 2.2)

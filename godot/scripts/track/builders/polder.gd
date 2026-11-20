class_name BuildPolder
## Port of buildPolder (+ windmill, farm) and detailPolder from polderrace-3d.html. Same numbers, same seeded random
## order (World.rnd), so the decor lands where it does in the HTML game.

static func M(c: int, o: Dictionary = {}) -> LMat:
	return Mats.M(c, o)

static func rnd() -> float:
	return World.rnd.next()

## places kept for the landmarks beside the road ([x0, z0, x1, z1]): the scattered decor stays out of them
static var reserved: Array = []
static func spare(x: float, z: float, r := 0.0) -> bool:
	for q in reserved:
		if x > q[0] - r and x < q[2] + r and z > q[1] - r and z < q[3] + r: return false
	return true

## is the point lat metres beside sample i nearer to its own piece of road than to any other? On the inside of a tight
## bend on the dike the strips beside the road (ditch, cycle path) would otherwise fold over each other and the slope
static func own(i: int, lat: float) -> bool:
	var xz := Trk.onTrack(i, lat)
	return Trk.distToTrack(xz[0], xz[1]) > absf(lat) - Trk.EMB[i] - 1.5

## mottled meadow grass (verges, dike slopes): the flat colour made the big slopes look like plastic
static func grassTex(base: String, seed_dark: String, seed_light: String) -> ImageTexture:
	return Canvas2D.tex(256, 256, func(g, w, h):
		g.fillStyle = base; g.fillRect(0, 0, w, h)
		for _i in 260:
			g.fillStyle = seed_dark if randf() < 0.55 else seed_light
			var ex: float = randf() * w; var ey: float = randf() * h
			var rx := 6 + randf() * 22; var ry := 4 + randf() * 12; var ra := randf() * 3
			# also its copies one tile over where it crosses an edge: the texture repeats without a visible seam
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					var cx: float = ex + dx * w; var cy: float = ey + dy * h
					if cx + rx < 0 or cx - rx > w or cy + rx < 0 or cy - rx > h: continue
					g.beginPath(); g.ellipse(cx, cy, rx, ry, ra, 0, PI * 2); g.fill()
		for _i in 900:
			g.fillStyle = "rgba(20,50,10,.10)" if randf() < 0.5 else "rgba(235,245,170,.10)"
			g.fillRect(randf() * w, randf() * h, 2, 5), true)

static func windmill(x: float, z: float, rot: float) -> void:
	var g := O3.group(x, 0, z)
	O3.rot(g, 0, rot, 0)
	O3.mesh(Geo.cylinder(2.1, 3.6, 12, 8), M(0x3d4a3a), 0, 6, 0, g, true)
	O3.mesh(Geo.cylinder(4.0, 4.2, 0.8, 8), M(0x7a6a58), 0, 0.4, 0, g)
	O3.mesh(Geo.cone(2.7, 3.2, 8), M(0x2c2a26), 0, 13.5, 0, g, true)
	World.box(1.2, 2.2, 0.2, M(0x2d5a3a), 0, 1.9, 3.3, g, false)
	World.box(0.9, 1.1, 0.2, M(0xf3efe4), 0, 7.5, 2.6, g, false)
	var sails := O3.group(0, 12.6, 3.0, g)
	var stock := M(0x5b3f27)
	var cloth := M(0xefe7d4)
	for k in 4:
		var arm := O3.group(0, 0, 0, sails)
		O3.rot(arm, 0, 0, k * PI / 2)
		World.box(0.28, 11, 0.2, stock, 0, 5.5, 0, arm)
		World.box(1.9, 8, 0.08, cloth, 1.1, 6.6, 0, arm)
		var y := 3.0
		while y < 10.6:
			World.box(1.95, 0.07, 0.14, stock, 1.1, y, 0, arm, false)
			y += 1.1
	O3.mesh(Geo.sphere(0.45, 8, 6), M(0x222222), 0, 0, 0, sails)
	O3.rot(sails, 0, 0, rnd() * 6)
	sails.set_meta("speed", 0.6 + rnd() * 0.4)
	World.add(g)
	World.sailGroups.append(sails)

static func farm(x: float, z: float, rot: float) -> void:
	var g := O3.group(x, 0, z)
	O3.rot(g, 0, rot, 0)
	var brick := M(0x8c3f2c); var roofM := M(0x3b3530); var cream := M(0xf3efe4); var green := M(0x2e5d3e)
	World.winMats.append(cream)
	World.box(9, 4.5, 8, brick, 0, 2.25, 0, g)
	var r1 := TrackCommon.roofMesh(10.2, 5.8, 8.8, roofM); r1.position.y = 4.5; g.add_child(r1)
	World.box(1.2, 2.4, 1.2, M(0x5a3a2a), 2, 8.2, 1, g)
	for xx in [-2.6, 2.6]:
		World.box(1.8, 1.6, 0.15, cream, xx, 2.6, 4.05, g, false)
		World.box(0.5, 1.6, 0.16, green, xx - 1.2, 2.6, 4.06, g, false)
		World.box(0.5, 1.6, 0.16, green, xx + 1.2, 2.6, 4.06, g, false)
	World.box(1.2, 2.2, 0.15, green, 0, 1.1, 4.05, g, false)
	World.box(11, 5.5, 14, M(0x6b3a2c), 11, 2.75, -2, g)
	var r2 := TrackCommon.roofMesh(12.2, 4.6, 14.8, roofM); r2.position = Vector3(11, 5.5, -2); g.add_child(r2)
	World.box(4, 4, 0.15, green, 11, 2, 5.05, g, false)
	World.add(g)

## a flat-bottomed sailing barge on the canal (hull, cabin, mast, brown sail)
static func barge(x: float, z: float, rot: float, sail: int) -> void:
	var g := O3.group(x, 0, z)
	O3.rot(g, 0, rot, 0)
	var hull := M(0x2e2a26); var deck := M(0x8a6a4a)
	World.box(2.6, 0.9, 8.5, hull, 0, 0.4, 0, g)
	World.box(2.0, 0.5, 1.6, hull, 0, 0.4, 4.8, g)
	World.box(2.3, 0.12, 8.0, deck, 0, 0.9, 0, g, false)
	World.box(1.8, 0.9, 2.4, M(0xe8e2d0), 0, 1.4, -2.6, g)
	World.box(2.0, 0.12, 2.6, M(0x2d5a3a), 0, 1.9, -2.6, g, false)
	O3.mesh(Geo.cylinder(0.09, 0.12, 8.5, 6), M(0x6b4a2e), 0, 5.1, 1.2, g, true)
	var sl := O3.mesh(Geo.extrude([Vector2(0, 0), Vector2(4.6, 0), Vector2(0.5, 6.6)], 0.06), M(sail, {"side": "double"}), 0, 1.9, 1.0, g, true)
	O3.rot(sl, 0, PI / 2, 0)
	World.add(g)

## the village church: tower with a spire, nave with a steep roof
static func church(x: float, z: float, rot: float) -> void:
	var g := O3.group(x, 0, z)
	O3.rot(g, 0, rot, 0)
	var brick := M(0x8a5a40); var slate := M(0x39404a); var cream := M(0xf3efe4)
	World.winMats.append(cream)
	World.box(6, 22, 6, brick, 0, 11, 0, g)
	var sp := O3.mesh(Geo.cone(4.4, 11, 4), slate, 0, 27.5, 0, g, true)
	O3.rot(sp, 0, PI / 4, 0)
	World.box(1.6, 3.2, 0.2, cream, 0, 16.5, 3.02, g, false)
	World.box(1.6, 3.2, 0.2, cream, 0, 16.5, -3.02, g, false)
	World.box(0.2, 3.2, 1.6, cream, 3.02, 16.5, 0, g, false)
	World.box(0.2, 3.2, 1.6, cream, -3.02, 16.5, 0, g, false)
	World.box(1.5, 2.6, 0.2, M(0x3a2a1c), 0, 1.3, 3.02, g, false)
	World.box(9, 8, 20, brick, 0, 4, -13, g)
	var r := TrackCommon.roofMesh(9.8, 6.5, 20.6, slate); r.position = Vector3(0, 8, -13); g.add_child(r)
	for k in 4:
		World.box(0.2, 3.6, 1.5, cream, 4.52, 4.4, -6.5 - k * 4.4, g, false)
		World.box(0.2, 3.6, 1.5, cream, -4.52, 4.4, -6.5 - k * 4.4, g, false)
	World.add(g)

## Landmarks beside the road (Godot only): a canal with a row of windmills and barges next to the start, tulip fields along
## the first straight, the farm at the S-bend the track is named after, and a village with its church inside the lap.
static func landmarks(tulipTex: Array) -> void:
	var water := Mats.phong(0x55829f, {"specular": 0x9fb3c6, "shininess": 70, "receiveShadow": true})
	var bank := M(0x5d7f3a)
	# ---- the canal ("vaart") right of the start straight, three mills on its far bank
	var cz := 60.0
	for part in [[165.0, 0.03, 26.0, bank], [165.0, 0.06, 19.0, water]]:
		var m := O3.mesh(Geo.plane(340, part[2]), part[3])
		O3.rot(m, -PI / 2, 0, 0)
		m.position = Vector3(part[0], part[1], cz)
		O3.receive(m)
		World.add(m)
	for x in [70.0, 165.0, 260.0]:
		windmill(x, cz + 26, PI + (rnd() - 0.5) * 0.3)
	barge(120, cz - 2, PI / 2 + 0.05, 0x7a3b22)
	barge(232, cz + 3, -PI / 2 - 0.08, 0x8a4a2a)
	var reed := []
	for k in 150:
		var rx := -2 + rnd() * 334
		var side := -1.0 if rnd() < 0.5 else 1.0
		var rh := 1.1 + rnd() * 0.9
		reed.append(World.mtx(rx, rh / 2, cz + side * (9.7 + rnd() * 1.6), rnd() * 6, 0.12, rh, 0.12))
	World.inst(Geo.cone(1, 1, 4), M(0x8a9a4a, {"sway": 0.3}), reed, null, false)
	# ---- tulip fields in strips of colour left of the start straight
	for k in 5:
		var m := O3.mesh(Geo.plane(44, 30), M(0xffffff, {"map": tulipTex[k], "repeat": Vector2(4.4, 30 / 1.6), "receiveShadow": true}))
		O3.rot(m, -PI / 2, 0, 0)
		m.position = Vector3(46 + k * 47, 0.08, -44)
		O3.receive(m)
		World.add(m)
	# ---- the farm at the S-bend, with its yard
	farm(328, -556, 3.0)
	var bales := []
	for k in 7:
		bales.append(Transform3D(O3.euler(0, 0.4, PI / 2), Vector3(309 + (k % 4) * 1.5, 0.62 + (1.1 if k > 3 else 0.0), -574 - (k % 4) * 1.2 - (0.9 if k > 3 else 0.0))))
	World.inst(Geo.cylinder(0.62, 0.62, 1.2, 12), M(0xeeeee6), bales, null, true)
	# ---- the village inside the lap: a church and a handful of brick houses with lit windows at night
	var vx := 150.0; var vz := -522.0
	church(vx, vz, 0.5)
	var body := []; var bcol := []; var roof := []; var rcol := []; var win := []
	var bricks := [0x8c3f2c, 0x9a5a3a, 0xa0623f, 0x7c4a34, 0xb9a98a]
	var tiles := [0x7a3524, 0x3b3530, 0x8a4028, 0x4a4038]
	for k in 16:
		var a := k / 16.0 * PI * 2 + rnd() * 0.25
		var rad := 26 + rnd() * 26
		var hx := vx + cos(a) * rad
		var hz := vz - 8 + sin(a) * rad
		var yaw := a + PI / 2 + (rnd() - 0.5) * 0.5
		var w := 6.5 + rnd() * 2.5
		var d := 7.5 + rnd() * 3
		var hh := 3.2 + rnd() * 1.4
		if Trk.distToTrack(hx, hz) < 30: continue
		body.append(World.mtx(hx, hh / 2, hz, yaw, w, hh, d)); bcol.append(MathX.col(World.pick(bricks)))
		roof.append(World.mtx(hx, hh, hz, yaw, w + 0.6, 2.4 + rnd() * 1.2, d + 0.6)); rcol.append(MathX.col(World.pick(tiles)))
		for sd in [-1.0, 1.0]:
			for wx in [-0.26, 0.26]:
				win.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(hx, 1.9, hz)) * Transform3D(Basis().scaled(Vector3(1.1, 1.2, 0.12)), Vector3(wx * w, 0, sd * (d / 2 + 0.01))))
	World.inst(Geo.box(1, 1, 1), M(0xffffff), body, bcol, true)
	World.inst(TrackCommon.roofGeo(), M(0xffffff), roof, rcol, true)
	var wm := M(0xf3efe4)
	World.winMats.append(wm)
	World.inst(Geo.box(1, 1, 1), wm, win, null, false)

static func build() -> void:
	var NS := Trk.NS
	var T := Trk.T
	reserved = [[-10.0, 40.0, 350.0, 98.0], [20.0, -64.0, 262.0, -24.0], [80.0, -590.0, 215.0, -455.0], [296.0, -586.0, 362.0, -528.0]]
	# the land: long narrow meadows in slightly different greens, a ditch between every two, mowing lines and some mottling
	World.groundPlane(Canvas2D.tex(512, 512, func(g, w, h):
		var cols := ["#6c9a47", "#74a24c", "#659443", "#7aa651"]
		for p in 4:
			g.fillStyle = cols[p]; g.fillRect(p * 128, 0, 128, h); g.fillStyle = "rgba(0,0,0,.035)"
			var x := p * 128 + 4
			while x < (p + 1) * 128:
				g.fillRect(x, 0, 2, h); x += 7
		for _i in 420:
			g.fillStyle = "rgba(30,70,20,.07)" if randf() < 0.5 else "rgba(225,240,150,.07)"
			g.beginPath(); g.ellipse(randf() * w, randf() * h, 5 + randf() * 16, 3 + randf() * 8, randf() * 3, 0, PI * 2); g.fill()
		for p in 4:
			g.fillStyle = "#4f6f2f"; g.fillRect(p * 128 - 2, 0, 7, h)
			g.fillStyle = "#5f8aa8"; g.fillRect(p * 128, 0, 3, h)
		g.fillStyle = "#4f6f2f"; g.fillRect(0, 0, w, 6)
		g.fillStyle = "#5f8aa8"; g.fillRect(0, 1, w, 3), true), 36)
	var grassMat := M(0xffffff, {"map": grassTex("#73a24b", "rgba(40,90,25,.16)", "rgba(215,235,140,.14)")})
	var slopeMat := M(0xffffff, {"map": grassTex("#6d9c47", "rgba(40,90,25,.18)", "rgba(215,235,140,.16)"), "repeat": Vector2(2, 1)})
	var waterMat := Mats.phong(0x5a88ad, {"specular": 0x9fb3c6, "shininess": 70})
	var RH := Trk.ROAD_HALF
	var SH := Trk.SHOULDER
	World.ribbon(-RH, RH, World.roadMat(World.roadTexture("#636567", [1.0 / 3, 2.0 / 3], true, false, 0.25)), 12, 0.07)
	World.ribbon(-SH, -RH, grassMat, 10, 0.05)
	World.ribbon(RH, SH, grassMat, 10, 0.05)
	World.ribbon(func(i): return -(SH + Trk.EMB[i]), -SH, slopeMat, 14, 0.05)
	World.ribbon(SH, func(i): return SH + Trk.EMB[i], slopeMat, 14, 0.05)
	# ditch and cycle path stop where a tight bend on the dike would fold them over the slope of the road further on
	var NSr := Trk.NS
	World.ribbon(func(i): return -(Trk.DIT[i] + 2.6), func(i): return -Trk.DIT[i], waterMat, 10, 0.06,
		func(i): return own(i, -(Trk.DIT[i] + 2.6)) and own((i + 1) % NSr, -(Trk.DIT[(i + 1) % NSr] + 2.6)))
	World.ribbon(func(i): return Trk.DIT[i], func(i): return Trk.DIT[i] + 2.6, waterMat, 10, 0.06,
		func(i): return own(i, Trk.DIT[i] + 2.6) and own((i + 1) % NSr, Trk.DIT[(i + 1) % NSr] + 2.6))
	World.ribbon(func(i): return -(Trk.DIT[i] + 7.2), func(i): return -(Trk.DIT[i] + 4.6), M(0xa94d3d), 10, 0.06,
		func(i): return own(i, -(Trk.DIT[i] + 7.2)) and own((i + 1) % NSr, -(Trk.DIT[(i + 1) % NSr] + 7.2)))
	World.startLine()
	World.gates(Trk.TRK)

	var popTrunk := []; var popCrown := []; var popCol := []; var wilTrunk := []; var wilCrown := []; var wilCol := []
	var poplar := func(x: float, z: float) -> void:
		var s := 0.85 + rnd() * 0.35
		popTrunk.append(World.mtx(x, 2 * s, z, 0, s))
		popCrown.append(World.mtx(x, 12.5 * s, z, rnd() * 6, 2.1 * s, 9 * s, 2.1 * s))
		popCol.append(MathX.hsl(0.27 + rnd() * 0.04, 0.38, 0.24 + rnd() * 0.07))
	var willow := func(x: float, z: float) -> void:
		var s := 0.8 + rnd() * 0.5
		var hue := 0.24 + rnd() * 0.05
		wilTrunk.append(World.mtx(x, 1.3 * s, z, 0, s))
		wilCrown.append(World.mtx(x, 4.2 * s, z, rnd() * 6, 3.2 * s, 2.6 * s, 3.2 * s))
		wilCol.append(MathX.hsl(hue, 0.3, 0.42 + rnd() * 0.1))
		var a := rnd() * 6.28
		wilCrown.append(World.mtx(x + cos(a) * 1.6 * s, 3.3 * s, z + sin(a) * 1.6 * s, rnd() * 6, 2.1 * s, 1.8 * s, 2.1 * s))
		wilCol.append(MathX.hsl(hue + 0.02, 0.32, 0.36 + rnd() * 0.08))
	for _r in 34:
		var i0 := int(floor(60 + rnd() * (NS - 140)))
		var side := -1 if rnd() < 0.5 else 1
		var len := 80 + rnd() * 200
		var d := 0.0
		while d < len:
			var i := (i0 + int(round(d / Trk.SPC))) % NS
			var lat := side * (Trk.DIT[i] + (10 if side < 0 else 5) + rnd())
			var xz := Trk.onTrack(i, lat)
			if Trk.distToTrack(xz[0], xz[1]) > absf(lat) - 2:
				poplar.call(xz[0], xz[1])
			d += 11
	for _r in 18:
		var s = Trk.randPos(World.rnd, 40)
		if s == null: continue
		var a := rnd() * PI
		var n := 10 + int(floor(rnd() * 14))
		for k in n:
			var x: float = s[0] + cos(a) * k * 10
			var z: float = s[1] + sin(a) * k * 10
			if Trk.distToTrack(x, z) > 20 and spare(x, z, 4):
				poplar.call(x, z)
	for _k in 240:
		var s = Trk.randPos(World.rnd, 19)
		if s != null and spare(s[0], s[1], 5):
			willow.call(s[0], s[1])
	for _k in 90:
		var a := rnd() * PI * 2
		var rad := 1050 + rnd() * 250
		var x := (Trk.BX0 + Trk.BX1) / 2 + cos(a) * rad
		var z := (Trk.BZ0 + Trk.BZ1) / 2 + sin(a) * rad
		for _j in 5:
			poplar.call(x + (rnd() - .5) * 40, z + (rnd() - .5) * 40)
	World.inst(Geo.cylinder(0.22, 0.34, 4, 6), M(0x4a3a2a), popTrunk, null, true)
	World.inst(Geo.sphere(1, 9, 8), M(0xffffff, {"sway": 0.15, "swayBase": -1.0, "swaySpan": 2.0}), popCrown, popCol, true)
	World.inst(Geo.cylinder(0.55, 0.8, 2.6, 7), M(0x5b4a36), wilTrunk, null, true)
	World.inst(Geo.icosahedron(1, 1), M(0xffffff, {"sway": 0.15, "swayBase": -1.0, "swaySpan": 2.0}), wilCrown, wilCol, true)

	var postB := []; var postT := []
	var dd := 0.0
	while dd < Trk.TRACK_LEN:
		var i := int(round(dd / Trk.SPC)) % NS
		for lat in [-8.3, 8.3]:
			var xz := Trk.onTrack(i, lat)
			postB.append(World.mtx(xz[0], Trk.HT[i] + 0.55, xz[1], Trk.heading_of(T[i])))
			postT.append(World.mtx(xz[0], Trk.HT[i] + 1.02, xz[1], Trk.heading_of(T[i])))
		dd += 12.5
	World.inst(Geo.box(0.16, 1.1, 0.16), M(0xf2f2ec), postB, null, false)
	var rm := M(0x1b1b1b)
	World.reflMats.append(rm)
	World.inst(Geo.box(0.17, 0.2, 0.17), rm, postT, null, false)

	for _k in 16:
		var s = Trk.randPos(World.rnd, 35)
		if s != null:
			var wr := rnd() * PI * 2
			if spare(s[0], s[1], 14): windmill(s[0], s[1], wr)
	var w40 := Trk.onTrack(40, 34)
	windmill(w40[0], w40[1], Trk.heading_of(T[40]) + PI * 0.8)
	for _k in 12:
		var s = Trk.randPos(World.rnd, 40)
		if s != null:
			var fr := rnd() * PI * 2
			if spare(s[0], s[1], 24): farm(s[0], s[1], fr)

	var cowTex := Canvas2D.tex(128, 64, func(g, w, h):
		g.fillStyle = "#f4f2ec"; g.fillRect(0, 0, w, h); g.fillStyle = "#1f1f1f"
		for _i in 6:
			g.beginPath(); g.ellipse(rnd() * w, rnd() * h, 8 + rnd() * 14, 6 + rnd() * 10, rnd() * 3, 0, PI * 2); g.fill())
	var cowBody := []; var cowHead := []; var cowLeg := []
	for _gI in 16:
		var s = Trk.randPos(World.rnd, 24)
		if s == null: continue
		var n := 3 + int(floor(rnd() * 5))
		for _k in n:
			var x: float = s[0] + (rnd() - .5) * 22
			var z: float = s[1] + (rnd() - .5) * 22
			if Trk.distToTrack(x, z) < 20 or not spare(x, z, 3): continue
			var cm := Transform3D(Basis(Vector3.UP, rnd() * 6.28), Vector3(x, 0, z))
			cowBody.append(cm * Transform3D(Basis(), Vector3(0, 1.15, 0)))
			cowHead.append(cm * Transform3D(Basis(), Vector3(0, 1.35, 1.35)))
			for lxz in [[-0.35, 0.75], [0.35, 0.75], [-0.35, -0.75], [0.35, -0.75]]:
				cowLeg.append(cm * Transform3D(Basis(), Vector3(lxz[0], 0.35, lxz[1])))
	World.inst(Geo.box(1.0, 0.9, 2.1), M(0xffffff, {"map": cowTex}), cowBody, null, true)
	World.inst(Geo.box(0.55, 0.6, 0.7), M(0x1f1f1f), cowHead, null, true)
	World.inst(Geo.box(0.2, 0.7, 0.2), M(0x2a2a2a), cowLeg, null, false)

	var tulipTex := []
	for c in ["#d62a2a", "#f5c518", "#e85a9a", "#f07a1a", "#8e44ad"]:
		tulipTex.append(Canvas2D.tex(64, 64, func(g, w, h):
			g.fillStyle = "#3f6b2c"; g.fillRect(0, 0, w, h); g.fillStyle = c; g.fillRect(0, 4, w, 34)
			g.fillStyle = "rgba(255,255,255,.18)"
			for _i in 40:
				g.fillRect(randf() * w, 4 + randf() * 34, 2, 2), true))
	# a tulip field that overlaps an earlier one lies 2.5 cm higher (level on level), otherwise the two flicker
	var fields := []
	var fieldHit := func(a: Dictionary, b: Dictionary) -> bool:
		var ax := [[cos(a.r), -sin(a.r)], [-sin(a.r), -cos(a.r)]]
		var bx := [[cos(b.r), -sin(b.r)], [-sin(b.r), -cos(b.r)]]
		var dx: float = b.x - a.x
		var dz: float = b.z - a.z
		for u in ax + bx:
			var ux: float = u[0]; var uz: float = u[1]
			var lim: float = a.w / 2 * absf(ax[0][0] * ux + ax[0][1] * uz) + a.d / 2 * absf(ax[1][0] * ux + ax[1][1] * uz) + b.w / 2 * absf(bx[0][0] * ux + bx[0][1] * uz) + b.d / 2 * absf(bx[1][0] * ux + bx[1][1] * uz) + 0.5
			if not (absf(dx * ux + dz * uz) < lim):
				return false
		return true
	for _k in 22:
		var s = Trk.randPos(World.rnd, 55)
		if s == null: continue
		var w := 40 + rnd() * 50
		var d := 24 + rnd() * 30
		var t: Texture2D = World.pick(tulipTex)
		var f := {"x": s[0], "z": s[1], "w": w, "d": d, "r": rnd() * PI, "lv": 0}
		if not spare(s[0], s[1], 50): continue
		for o in fields:
			if fieldHit.call(o, f): f.lv = maxi(f.lv, o.lv + 1)
		fields.append(f)
		var m := O3.mesh(Geo.plane(w, d), M(0xffffff, {"map": t, "repeat": Vector2(w / 10, d / 1.6), "receiveShadow": true}))
		O3.rot(m, -PI / 2, 0, f.r)
		m.position = Vector3(s[0], 0.08 + f.lv * 0.025, s[1])
		O3.receive(m)
		World.add(m)

	landmarks(tulipTex)
	TrackCommon.chevrons(Trk.ROAD_HALF + 1.4)

	TrackCommon.signs([["Kinderdijk", "8"], ["Gouda", "23"], ["Edam", "61"], ["Lelystad", "34"], ["Zwolle", "88"], ["Delft", "17"], ["Urk", "52"], ["Giethoorn", "96"]], 10.2)

	# power line with lattice pylons across the polder
	var A := Vector2(Trk.BX0 + 40, -120)
	var B := Vector2(Trk.BX1 - 40, -460)
	var dir := B - A
	var L := dir.length()
	dir = dir.normalized()
	var rot := atan2(dir.x, dir.y) + PI / 2
	var arm := M(0x8a9194)
	var tops := []
	var dist := 0.0
	while dist <= L:
		var p := A + dir * dist
		if Trk.distToTrack(p.x, p.y) < 22:
			p += dir * 45
		var g := O3.group(p.x, 0, p.y)
		O3.rot(g, 0, rot, 0)
		var twg := Geo.cylinder(0.5, 2.6, 30, 4, 6, true)
		var tw := O3.wire(twg, 0x7d8588, g)
		tw.position.y = 15
		O3.rot(tw, 0, PI / 4, 0)
		World.box(12, 0.35, 0.35, arm, 0, 22, 0, g)
		World.box(8, 0.35, 0.35, arm, 0, 26.5, 0, g)
		World.add(g)
		var fv := Vector3(cos(rot), 0, -sin(rot))
		var row := []
		for oy in [[-6, 22], [6, 22], [-4, 26.5], [4, 26.5]]:
			row.append(Vector3(p.x + fv.x * oy[0], oy[1], p.y + fv.z * oy[0]))
		tops.append(row)
		dist += 190
	for k in tops.size() - 1:
		for w in 4:
			var a: Vector3 = tops[k][w]
			var b: Vector3 = tops[k + 1][w]
			var pts := []
			for st in 13:
				var t := st / 12.0
				var q := a.lerp(b, t)
				q.y -= sin(t * PI) * 4
				pts.append(q)
			World.add(O3.line(pts, 0x4a4f52))

## JS detailPolder: a high-voltage line on lattice pylons right across the polder, and hay bales
static func details() -> void:
	var steel := M(0x8d9398)
	var towers := []
	var ax := Trk.BX0 - 200
	var az := (Trk.BZ0 + Trk.BZ1) / 2 + 120
	var bx := Trk.BX1 + 200
	var bz := (Trk.BZ0 + Trk.BZ1) / 2 - 260
	var n := int(round(Vector2(bx - ax, bz - az).length() / 210))
	for k in n + 1:
		var x := ax + (bx - ax) * k / n
		var z := az + (bz - az) * k / n
		if Trk.distToTrack(x, z) < 22:
			towers.append(null); continue
		var g := O3.group(x, 0, z)
		O3.rot(g, 0, atan2(bx - ax, bz - az) + PI / 2, 0)
		for ab in [[-1.6, -1.6], [1.6, -1.6], [-1.6, 1.6], [1.6, 1.6]]:
			var l := World.box(0.35, 26, 0.35, steel, ab[0] * 0.55, 13, ab[1] * 0.55, g)
			O3.rot(l, ab[1] * 0.035, 0, -ab[0] * 0.035)
		var y := 4.0
		while y < 24:
			World.box(2.2, 0.18, 2.2, steel, 0, y, 0, g, false)
			y += 4.5
		World.box(15, 0.5, 0.6, steel, 0, 21, 0, g); World.box(10, 0.5, 0.6, steel, 0, 25.5, 0, g); World.box(0.8, 2.5, 0.8, steel, 0, 27.0, 0, g)
		World.add(g)
		towers.append(g)
	for k in towers.size() - 1:
		var A = towers[k]
		var B = towers[k + 1]
		if A == null or B == null: continue
		for o in [[-7, 20.6], [7, 20.6], [-4.8, 25.1], [4.8, 25.1]]:
			var p: Vector3 = A.transform * Vector3(o[0], o[1], 0)
			var q: Vector3 = B.transform * Vector3(o[0], o[1], 0)
			var pts := []
			for t in 13:
				var f := t / 12.0
				pts.append(Vector3(p.x + (q.x - p.x) * f, p.y + (q.y - p.y) * f - sin(f * PI) * 3.2, p.z + (q.z - p.z) * f))
			World.wire(pts, 0x2a2e34)
	var bales := []
	for _f in 14:
		var s = World.clearSpot(28)
		if s == null: continue
		var n2 := 5 + int(floor(rnd() * 7))
		var yaw := rnd() * 6
		if not spare(s[0], s[1], 14): continue
		for k in n2:
			bales.append(Transform3D(O3.euler(0, yaw, PI / 2), Vector3(s[0] + cos(yaw) * k * 1.9, 0.62, s[1] - sin(yaw) * k * 1.9)))
	World.inst(Geo.cylinder(0.62, 0.62, 1.2, 12), M(0xeeeee6), bales, null, true)

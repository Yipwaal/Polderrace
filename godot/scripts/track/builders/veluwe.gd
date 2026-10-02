class_name BuildVeluwe
## Port of buildVeluwe, detailVeluwe and finishVeluweDetails from polderrace-3d.html: heath and forest hills (terrain,
## see terrain.gd), pines and birches, an ecoduct over the road, a watchtower, mushroom signposts, deer, a sheepfold
## with sheep and picnic tables. Same numbers, same seeded random order (World.rnd) as the HTML game.

## JS veluweGround, veluweSheep, veluwePicnic: made in details(), put on the terrain in finish_details()
static var veluweGround: Array = []
static var veluweSheep: Array = []
static var veluwePicnic: Array = []

static func M(c: int, o: Dictionary = {}) -> LMat:
	return Mats.M(c, o)

static func rnd() -> float:
	return World.rnd.next()

## JS Math.round (halves round up, also below zero)
static func jround(v: float) -> int:
	return int(floor(v + 0.5))

static func heath(x: float, z: float) -> float:
	return sin(x / 97 + 2) * cos(z / 83) + 0.5 * sin((x + z) / 41)

static func sand(x: float, z: float) -> float:
	return sin(x / 150 - 1) * sin(z / 170 + 0.5) + 0.3 * cos(x / 37)

static func build() -> void:
	veluweGround = []; veluweSheep = []; veluwePicnic = []
	var NS := Trk.NS
	var HT := Trk.HT
	var TF := Terrain.terrainFn()
	Trk.terrain_fn = TF.fn()
	var size := 3400.0
	var seg := 272
	var pos := Terrain.planeXZ(size, seg)
	var cx := (Trk.BX0 + Trk.BX1) / 2
	var cz := (Trk.BZ0 + Trk.BZ1) / 2
	var cols := PackedColorArray()
	cols.resize(pos.size())
	var cg := MathX.col(0x6f8f45); var ch := MathX.col(0x8a5a8e); var cs := MathX.col(0xd9c897); var cd := MathX.col(0x587a3a)
	for k in pos.size():
		var x := pos[k].x + cx
		var z := pos[k].z + cz
		var h := TF.at(x, z)
		pos[k].y = h
		var tmp := cg.lerp(cd, 0.5 + 0.5 * sin(x / 23 + z / 31))
		var hv := heath(x, z)
		var sv := sand(x, z)
		if hv > 0.75: tmp = tmp.lerp(ch, clampf((hv - 0.75) * 3, 0, 0.9))
		if sv > 0.8: tmp = tmp.lerp(cs, clampf((sv - 0.8) * 4, 0, 1))
		if TF.d < 13: tmp = tmp.lerp(cs, clampf((13 - TF.d) / 4, 0, 0.35))
		cols[k] = tmp
	Terrain.groundMesh(pos, cols, seg, cx, cz)
	var RH := Trk.ROAD_HALF
	var SH := Trk.SHOULDER
	World.ribbon(-RH, RH, World.roadMat(World.roadTexture("#55575a", [0.5], true, false, 0.3)), 10, 0.07)
	var sandM := M(0xcdb98a); var bikeM := M(0x9a3b2e); var grassM := M(0x6f8f45)
	World.ribbon(-SH, -RH, sandM, 8, 0.05); World.ribbon(RH, 7.3, sandM, 8, 0.05); World.ribbon(7.3, 9.7, bikeM, 8, 0.06); World.ribbon(9.7, SH, grassM, 8, 0.05)
	World.startLine()
	World.gates(Trk.TRK)
	var post := []
	var dd := 0.0
	while dd < Trk.TRACK_LEN:
		var i := int(round(dd / Trk.SPC)) % NS
		for s in [-1, 1]:
			var xz := Trk.onTrack(i, s * 10.8)
			post.append(World.mtx(xz[0], HT[i] + 0.45, xz[1]))
		dd += 9
	World.inst(Geo.box(0.18, 0.9, 0.18), M(0x6b4a2e), post, null, false)

	# pines (trunk + two cones) and birches on the heath, in the forest and along the road
	var tr := []; var cn := []; var cn2 := []; var bt := []; var bc := []
	var spots := []
	for _k in 2600:
		var sx := Trk.BX0 - 450 + rnd() * (Trk.BX1 - Trk.BX0 + 900)
		var sz := Trk.BZ0 - 450 + rnd() * (Trk.BZ1 - Trk.BZ0 + 900)
		spots.append([sx, sz])
	for _k in 4200:
		var i := int(floor(rnd() * NS))
		var side := -1 if rnd() < 0.5 else 1
		spots.append(Trk.onTrack(i, side * (15 + pow(rnd(), 1.6) * 110)))
	for sp in spots:
		var x: float = sp[0]
		var z: float = sp[1]
		var th := TF.at(x, z)
		if TF.d < 14 or heath(x, z) > 0.9 or sand(x, z) > 0.9: continue
		var s := 0.8 + rnd() * 0.6
		if rnd() < 0.12:
			bt.append(World.mtx(x, th + 2.5 * s, z, 0, s)); bc.append(World.mtx(x, th + 6 * s, z, 0, s * 1.2))
		else:
			tr.append(World.mtx(x, th + 2 * s, z, 0, s)); cn.append(World.mtx(x, th + 6.5 * s, z, rnd() * 6, s)); cn2.append(World.mtx(x, th + 9.8 * s, z, rnd() * 6, s * 0.7))
	World.inst(Geo.cylinder(0.28, 0.4, 4, 5), M(0x5a3f2a), tr, null, true)
	World.inst(Geo.cone(2.6, 6.5, 7), M(0x2f4a2b), cn, null, true)
	World.inst(Geo.cone(2.1, 5, 7), M(0x365532), cn2, null, true)
	World.inst(Geo.cylinder(0.18, 0.24, 5, 5), M(0xe8e4dc), bt, null, true)
	World.inst(Geo.sphere(2.4, 7, 5), M(0x7aa24a), bc, null, true)

	ecoduct()
	watchtower(TF)
	mushrooms()
	deer(TF)
	startLamps()

## the ecoduct: a green bridge over the road, with pines on top
static func ecoduct() -> void:
	var NS := Trk.NS
	var i := int(round(NS * 0.36))
	var g := Node3D.new()
	var con := M(0x9a978f); var top := M(0x5e7f3a)
	var hh := 7.5
	World.box(24, 2, 34, con, 0, hh, 0, g); World.box(24, 0.6, 34, top, 0, hh + 1.3, 0, g)
	for s in [-1, 1]:
		World.box(19, hh + 4, 34, con, s * (11.2 + 9.5), (hh - 4) / 2 + 1, 0, g); World.box(0.5, 1.2, 34, con, s * 11.7, hh + 2.2, 0, g)
	var ep := []
	for _k in 14:
		var ex := (rnd() - .5) * 20
		var ez := (rnd() - .5) * 30
		ep.append(World.mtx(ex, hh + 2.2, ez, rnd() * 6, 0.55))
	World.place(g, i, 0, 0)
	var cm := []
	for m in ep:
		cm.append(g.transform * m)
	World.inst(Geo.cone(2.4, 6, 7), M(0x2f4a2b), cm, null, true)
	var sg := Node3D.new()
	World.box(5.2, 1.2, 0.2, M(0x1d4f9e), 0, hh + 0.2, 17.1, sg)
	World.place(sg, i, 0, 0)

## a wooden watchtower on the heath
static func watchtower(TF: Terrain) -> void:
	var NS := Trk.NS
	var i := int(round(NS * 0.62))
	var xz := Trk.onTrack(i, -55)
	var th := TF.at(xz[0], xz[1])
	var g := O3.group(xz[0], th, xz[1])
	var wood := M(0x6b4a2e)
	for ab in [[-2, -2], [2, -2], [-2, 2], [2, 2]]:
		World.box(0.4, 22, 0.4, wood, ab[0], 11, ab[1], g)
	var y := 4
	while y < 21:
		World.box(4.4, 0.25, 0.25, wood, 0, y, -2, g); World.box(4.4, 0.25, 0.25, wood, 0, y, 2, g)
		World.box(0.25, 0.25, 4.4, wood, -2, y, 0, g); World.box(0.25, 0.25, 4.4, wood, 2, y, 0, g)
		y += 5
	World.box(5.4, 2.6, 5.4, M(0x7b5a3a), 0, 23.3, 0, g); World.box(5, 1.2, 5.6, M(0x2c3a48), 0, 23.4, 0, g)
	var roof := O3.mesh(Geo.cone(4.6, 2.6, 4), M(0x3a2e26), 0, 26, 0, g)
	O3.rot(roof, 0, PI / 4, 0)
	World.add(g)

## white-red mushroom signposts (paddenstoelen) along the road
static func mushrooms() -> void:
	var NS := Trk.NS
	var HT := Trk.HT
	var pm := []; var dm := []
	for k in 9:
		var i := int(round(NS * (0.05 + k * 0.11))) % NS
		var s := 1 if k % 2 else -1
		var xz := Trk.onTrack(i, s * 12.2)
		pm.append(World.mtx(xz[0], HT[i] + 0.5, xz[1], 0, 1)); dm.append(World.mtx(xz[0], HT[i] + 1.15, xz[1], 0, 1))
	World.inst(Geo.cylinder(0.28, 0.3, 1, 10), M(0xf2f0ea), pm, null, true)
	World.inst(Geo.sphere(0.55, 12, 6, 0, PI * 2, 0, PI / 2), M(0xc8302a), dm, null, true)

## deer on the heath
static func deer(TF: Terrain) -> void:
	var bm := []; var hm := []
	for _k in 30:
		var x := Trk.BX0 + rnd() * (Trk.BX1 - Trk.BX0)
		var z := Trk.BZ0 + rnd() * (Trk.BZ1 - Trk.BZ0)
		var th := TF.at(x, z)
		if TF.d < 25 or heath(x, z) < 0.6: continue
		var r := rnd() * 6
		bm.append(World.mtx(x, th + 1.05, z, r, 1))
		hm.append(Transform3D(Basis(Vector3.UP, r), Vector3(x, th, z)) * Transform3D(Basis(), Vector3(0, 1.55, 0.85)))
	World.inst(Geo.box(0.5, 0.6, 1.3), M(0x8a5a36), bm, null, true)
	World.inst(Geo.box(0.3, 0.4, 0.45), M(0x7a4c2e), hm, null, false)

## street lamps at the start
static func startLamps() -> void:
	var NS := Trk.NS
	var HT := Trk.HT
	var T := Trk.T
	var pm := M(0x5a5f63)
	var hm := M(0x333a40, {"emissive": 0x222222})
	World.lampMats.append(hm)
	var lp := []; var lh := []
	var d := -60
	while d <= 60:
		var i := (jround((Trk.S_START + d) / Trk.SPC) % NS + NS) % NS
		var xz := Trk.onTrack(i, -9.2)
		var hxz := Trk.onTrack(i, -7.6)
		lp.append(World.mtx(xz[0], HT[i] + 4, xz[1])); lh.append(World.mtx(hxz[0], HT[i] + 8, hxz[1], Trk.heading_of(T[i])))
		var pxz := Trk.onTrack(i, -3)
		World.trackLights.append([pxz[0], HT[i], pxz[1], 10])
		d += 30
	World.inst(Geo.cylinder(0.1, 0.14, 8, 6), pm, lp, null, true)
	World.inst(Geo.box(0.5, 0.25, 1.6), hm, lh, null, false)

## JS detailVeluwe: a sheepfold (heather-roofed barn) with its flock, and picnic tables next to the start
static func details() -> void:
	var NS := Trk.NS
	var s = World.clearSpot(45, 200)
	if s != null:
		var g := O3.group(s[0], 0, s[1])
		World.box(15, 3.6, 8, M(0x5b4331), 0, 1.8, 0, g)
		var r := O3.mesh(Geo.cone(9.5, 6, 4), M(0x8a7446), 0, 6.4, 0, g)
		O3.rot(r, 0, PI / 4, 0)
		r.scale = Vector3(1.12, 1, 0.62)
		World.box(2.2, 2.6, 0.1, M(0x2b2017), 0, 1.3, 4.02, g, false)
		World.add(g)
		veluweGround.append(g)
		var sh := []
		for _k in 26:
			var a := rnd() * 6.28
			var d := 10 + rnd() * 22
			var x: float = s[0] + cos(a) * d
			var z: float = s[1] + sin(a) * d
			sh.append([x, z, rnd() * 6])
		veluweSheep = sh
	var pb := []
	for d in [-40, -20, 20, 40]:
		var i := ((Trk.START_I + jround(d / Trk.SPC)) % NS + NS) % NS
		var xz := Trk.onTrack(i, -13.5)
		pb.append([xz[0], Trk.HT[i] - 0.12, xz[1], Trk.heading_of(Trk.T[i])])
	veluwePicnic = pb

## JS finishVeluweDetails: the sheepfold, sheep and picnic tables onto the terrain
static func finish_details() -> void:
	if Trk.TRACK_ID != "veluwe" or not Trk.terrain_fn.is_valid():
		return
	var TF := Trk.terrain_fn
	for g in veluweGround:
		var t: Dictionary = TF.call(g.position.x, g.position.z)
		g.position.y = t.h - 0.2
	var sb := []; var shd := []
	for e in veluweSheep:
		var x: float = e[0]
		var z: float = e[1]
		var r: float = e[2]
		var t: Dictionary = TF.call(x, z)
		if t.d < 14: continue
		var m := Transform3D(Basis(Vector3.UP, r), Vector3(x, t.h, z))
		sb.append(m * Transform3D(Basis(), Vector3(0, 0.75, 0)))
		shd.append(m * Transform3D(Basis(), Vector3(0, 0.98, 0.75)))
	World.inst(Geo.box(0.8, 0.8, 1.3), M(0xefece2), sb, null, true)
	World.inst(Geo.box(0.35, 0.4, 0.45), M(0x1f1f1f), shd, null, false)
	var wood := M(0x7a5a3a)
	var tb := []; var bn := []
	for e in veluwePicnic:
		var x: float = e[0]
		var y: float = e[1]
		var z: float = e[2]
		var h: float = e[3]
		tb.append(World.mtx(x, y + 0.75, z, h, 0.8, 0.08, 2))
		for s in [-0.75, 0.75]:
			bn.append(World.mtx(x + cos(h) * s, y + 0.45, z - sin(h) * s, h, 0.3, 0.06, 2))
	World.inst(Geo.box(1, 1, 1), wood, tb, null, true)
	World.inst(Geo.box(1, 1, 1), wood, bn, null, true)

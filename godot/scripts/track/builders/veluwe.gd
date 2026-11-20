class_name BuildVeluwe
## The Veluwe: heath and forest hills (terrain, see terrain.gd). Started as a port of buildVeluwe, detailVeluwe and
## finishVeluweDetails from polderrace-3d.html; fase 2 made it a forest: woods of spruce, Scots pine, birch and oak with
## clearings, purple heath and sand drifts, an ecoduct with earth banks, a watchtower, a pancake house in the woods,
## hunting seats, deer in groups, a log rail and reflector posts along the road and arrow boards in the bends.
## Everything random comes from the seeded World.rnd.

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

## > 0: woods, < 0: open ground (meadow, heath, sand)
static func wood(x: float, z: float) -> float:
	return sin(x / 131 + 0.7) * cos(z / 117 - 0.3) + 0.55 * sin((x * 0.6 - z) / 67 + 1.1) + 0.25

## which trees grow where: > 0.3 broad-leaved, < -0.3 Scots pine, spruce in between
static func stand(x: float, z: float) -> float:
	return sin(x / 210 + 2.1) * sin(z / 190 + 0.4) + 0.35 * sin((x + z * 0.7) / 53)

## a cheap repeatable speckle in -1..1 for ground colours (not the seeded rnd: 75 000 vertices)
static func speck(x: float, z: float) -> float:
	var v := sin(x * 12.9898 + z * 78.233) * 43758.5453
	return (v - floor(v)) * 2.0 - 1.0

static func build() -> void:
	veluweGround = []; veluweSheep = []; veluwePicnic = []
	var TF := Terrain.terrainFn()
	Trk.terrain_fn = TF.fn()
	var size := 3400.0
	var seg := 272
	var pos := Terrain.planeXZ(size, seg)
	var cx := (Trk.BX0 + Trk.BX1) / 2
	var cz := (Trk.BZ0 + Trk.BZ1) / 2
	var cols := PackedColorArray()
	cols.resize(pos.size())
	# meadow greens, the brown-green needle floor of the woods, purple and russet heath, pale drift sand
	var cg := MathX.col(0x6a8a44); var cd := MathX.col(0x567a3a); var cw := MathX.col(0x4e5f33); var cw2 := MathX.col(0x5c5a36)
	var ch := MathX.col(0x86588c); var ch2 := MathX.col(0x7a6248); var cs := MathX.col(0xd2c294); var cs2 := MathX.col(0xc4b07e)
	for k in pos.size():
		var x := pos[k].x + cx
		var z := pos[k].z + cz
		var h := TF.at(x, z)
		pos[k].y = h
		var sp := speck(x, z)
		var tmp := cg.lerp(cd, 0.5 + 0.5 * sin(x / 23 + z / 31))
		var wv := wood(x, z)
		if wv > 0.0: tmp = tmp.lerp(cw.lerp(cw2, 0.5 + 0.5 * sp), clampf(wv * 2.2, 0, 0.85))
		var hv := heath(x, z)
		var sv := sand(x, z)
		if hv > 0.75: tmp = tmp.lerp(ch.lerp(ch2, 0.5 + 0.5 * sin(x / 9.0) * cos(z / 11.0)), clampf((hv - 0.75) * 3, 0, 0.9))
		if sv > 0.8: tmp = tmp.lerp(cs.lerp(cs2, 0.5 + 0.5 * sp), clampf((sv - 0.8) * 4, 0, 1))
		if TF.d < 13: tmp = tmp.lerp(cs2, clampf((13 - TF.d) / 4, 0, 0.35))
		var j := 1.0 + sp * 0.05
		cols[k] = Color(tmp.r * j, tmp.g * j, tmp.b * j)
	Terrain.groundMesh(pos, cols, seg, cx, cz, BKit.noiseTex(256, 2600, 0.2, 0.1), 23.0)
	var RH := Trk.ROAD_HALF
	var SH := Trk.SHOULDER
	World.ribbon(-RH, RH, World.roadMat(World.roadTexture("#55575a", [0.5], true, false, 0.3)), 10, 0.07)
	var nz := BKit.noiseTex(64, 600, 0.1, 0.05)
	var sandM := M(0xc2ae82, {"map": nz}); var bikeM := M(0x93392d, {"map": nz}); var grassM := M(0x66863f, {"map": nz})
	World.ribbon(-SH, -RH, sandM, 3.5, 0.05); World.ribbon(RH, 7.3, sandM, 1, 0.05); World.ribbon(7.3, 9.7, bikeM, 2.4, 0.06); World.ribbon(9.7, SH, grassM, 1, 0.05)
	World.startLine()
	World.gates(Trk.TRK)
	edgeRail()
	sites(TF)
	forest(TF)
	ecoduct()
	watchtower(TF)
	mushrooms()
	deer(TF)
	startLamps()
	pancakeHouse(TF)
	huntingSeats(TF)
	heathPlants(TF)
	BKit.chevrons(12.4, 0.016, 9.0, 1.2, true)
	fans(TF)

## the edge of the road: a post every 9 m (down to the ground, which lies 0.3 m below the road there), a log rail from
## post to post where the invisible wall stands (lat 10.6), and a reflector on every post for the night
static func edgeRail() -> void:
	var NS := Trk.NS
	var HT := Trk.HT
	var post := []; var refl := []
	var dd := 0.0
	while dd < Trk.TRACK_LEN:
		var i := int(round(dd / Trk.SPC)) % NS
		var hd := Trk.heading_of(Trk.T[i])
		for s in [-1, 1]:
			var xz := Trk.onTrack(i, s * 10.8)
			post.append(World.mtx(xz[0], HT[i] + 0.25, xz[1], hd))
			var rxz := Trk.onTrack(i, s * 10.72)
			refl.append(World.mtx(rxz[0], HT[i] + 0.74, rxz[1], hd))
		dd += 9
	World.inst(Geo.box(0.2, 1.4, 0.2), M(0x6b4a2e), post, null, false)
	var rm := M(0xd8d4c8, {"emissive": 0x000000})
	World.reflMats.append(rm)
	World.inst(Geo.box(0.05, 0.16, 0.14), rm, refl, null, false)
	var wd := M(0x7a5a3a)
	for s in [-1, 1]:
		World.vribbon(s * 10.8, 0.42, 0.62, wd, 3)

## where the buildings come, so that trees, deer, heather and the roadside bushes of the dressing keep out (World.pavTaken)
static var cafe: Array = []
static var stand_i := 0
static func sites(TF: Terrain) -> void:
	cafe = flatSpot(TF, [0.07, 0.11, 0.17, 0.23, 0.44, 0.5, 0.56, 0.74, 0.8, 0.9], 36.0, 12.0)
	if not cafe.is_empty(): World.pavTaken.append([cafe[0], cafe[1], 19.0])
	stand_i = (Trk.START_I + 22) % Trk.NS
	var sxz := Trk.onTrack(stand_i, 15.0)
	World.pavTaken.append([sxz[0], sxz[1], 10.5])
	var wxz := Trk.onTrack(int(round(Trk.NS * 0.62)), -55)
	World.pavTaken.append([wxz[0], wxz[1], 7.0])

## woods of spruce, Scots pine, birch and oak, each a single instanced tree; clearings stay open, a few loners in the open
static func forest(TF: Terrain) -> void:
	var NS := Trk.NS
	var spots := []
	for _k in 3000:
		var sx := Trk.BX0 - 450 + rnd() * (Trk.BX1 - Trk.BX0 + 900)
		var sz := Trk.BZ0 - 450 + rnd() * (Trk.BZ1 - Trk.BZ0 + 900)
		spots.append([sx, sz])
	for _k in 4200:
		var i := int(floor(rnd() * NS))
		var side := -1 if rnd() < 0.5 else 1
		spots.append(Trk.onTrack(i, side * (15 + pow(rnd(), 1.6) * 110)))
	var sm := []; var sc := []; var pm := []; var pc := []; var bm := []; var bc := []; var om := []; var oc := []
	for sp in spots:
		var x: float = sp[0]
		var z: float = sp[1]
		var th := TF.at(x, z)
		var d := TF.d
		var r := rnd()
		var s := 0.75 + rnd() * 0.6
		var ry := rnd() * 6
		var tint := 0.8 + rnd() * 0.4
		var r2 := rnd()
		if d < 14 or heath(x, z) > 0.8 or sand(x, z) > 0.85 or World.pavBusy(x, z, 3.0): continue
		var wv := wood(x, z)
		# open ground keeps one tree in seven: loners and small groups
		if wv < 0.0 and r > 0.14: continue
		var st := stand(x, z) + (r - 0.5) * 0.5
		if st > 0.3:
			if d < 17: continue   # broad crowns stay off the verge
			if r2 < 0.5:
				bm.append(World.mtx(x, th - 0.15, z, ry, s * 1.1)); bc.append(Color(tint, tint, tint * 0.9))
			else:
				om.append(World.mtx(x, th - 0.15, z, ry, s * 1.05)); oc.append(Color(tint, tint, tint * 0.92))
		elif st < -0.3:
			pm.append(World.mtx(x, th - 0.15, z, ry, s)); pc.append(Color(tint, tint, tint))
		else:
			sm.append(World.mtx(x, th - 0.15, z, ry, s)); sc.append(Color(tint * 0.96, tint, tint * 0.94))
	var tm := M(0xffffff)
	World.inst(BKit.spruceGeo(), tm, sm, sc, true)
	World.inst(BKit.scotsGeo(), tm, pm, pc, true)
	World.inst(BKit.birchGeo(), tm, bm, bc, true)
	World.inst(BKit.oakGeo(), tm, om, oc, true)

## the ecoduct: a green bridge over the road with earth banks, pines and a parapet on top. It keeps 60 m clear of every
## checkpoint (where it stood, the checkpoint gate was hidden inside its deck).
static func ecoduct() -> void:
	var NS := Trk.NS
	var i := int(round(NS * 0.36))
	for _try in 40:
		var near := false
		for c in Trk.cps:
			var dlt := absi(c - i)
			if mini(dlt, NS - dlt) < 30: near = true
		if not near: break
		i = (i + 5) % NS
	var hh := 7.5
	var ln := 34.0
	var g := Node3D.new()
	World.place(g, i, 0, 0)
	var A := BKit.Acc.new()
	A.frame = g.transform
	World.root.remove_child(g)
	g.free()
	var con := 0x9a978f; var grass := 0x56763a; var earth := 0x5f7038
	# deck: concrete slab, soil on top
	A.box(25, 2, ln, 0, hh, 0, con)
	A.box(24, 0.6, ln - 0.4, 0, hh + 1.3, 0, grass)
	for s in [-1.0, 1.0]:
		# abutment wall beside the road, and behind it an earth bank down to the forest floor
		A.box(1.4, hh + 3, ln, s * 12.1, (hh - 3) / 2 + 1, 0, con)
		var bank := Geo.extrude([Vector2(12.6, -4), Vector2(12.6, hh + 1.55), Vector2(17, hh + 1.55), Vector2(47, -4)], ln - 0.4)
		bank.translate(0, 0, -(ln - 0.4) / 2)
		if s < 0: bank.rotate_y(PI)
		A.add(bank, earth)
		# wing walls at both portals
		for e in [-1.0, 1.0]:
			A.box(7, hh + 2.4, 0.8, s * 15.6, (hh - 3.6) / 2 + 1, e * (ln / 2 - 0.4), con)
		A.box(0.5, 1.2, ln, s * 12.25, hh + 2.2, 0, con)
	for e in [-1.0, 1.0]:
		A.box(26, 1.1, 0.5, 0, hh + 2.15, e * (ln / 2 - 0.25), con)
	# the blue name board over the road, on the side the traffic comes from
	A.box(5.4, 1.3, 0.2, 0, hh + 0.1, -(ln / 2 + 0.11), 0x1d4f9e)
	A.box(5.0, 0.9, 0.06, 0, hh + 0.1, -(ln / 2 + 0.24), 0xf2f0ea)
	A.commit()
	var cm := []; var cc := []
	for _k in 16:
		var ex := (rnd() - .5) * 20
		var ez := (rnd() - .5) * 28
		cm.append(A.frame * World.mtx(ex, hh + 1.5, ez, rnd() * 6, 0.45 + rnd() * 0.2))
		var t := 0.85 + rnd() * 0.25
		cc.append(Color(t, t, t))
	World.inst(BKit.spruceGeo(), M(0xffffff), cm, cc, true)

## a wooden watchtower on the heath: four legs, cross braces, stairs, a covered platform and a flag
static func watchtower(TF: Terrain) -> void:
	var NS := Trk.NS
	var i := int(round(NS * 0.62))
	var xz := Trk.onTrack(i, -55)
	var th := TF.at(xz[0], xz[1])
	var A := BKit.Acc.new()
	A.at(xz[0], th, xz[1], Trk.heading_of(Trk.T[i]))
	var wd := 0x6b4a2e; var dark := 0x4a3524
	for ab in [[-2.2, -2.2], [2.2, -2.2], [-2.2, 2.2], [2.2, 2.2]]:
		A.box(0.42, 24, 0.42, ab[0], 11, ab[1], wd)
	var y := 4.0
	while y < 21:
		A.box(4.8, 0.26, 0.26, 0, y, -2.2, wd); A.box(4.8, 0.26, 0.26, 0, y, 2.2, wd)
		A.box(0.26, 0.26, 4.8, -2.2, y, 0, wd); A.box(0.26, 0.26, 4.8, 2.2, y, 0, wd)
		# a cross brace on two sides and a flight of stairs inside, turning round every floor
		A.box(0.16, 6.6, 0.16, 0, y - 2.5, -2.2, dark, 0, 0, 0.72); A.box(0.16, 6.6, 0.16, 0, y - 2.5, 2.2, dark, 0, 0, -0.72)
		var fl := int(y / 5.0)
		A.box(1.0, 0.12, 5.6, -1.2 if fl % 2 else 1.2, y - 2.5, 0, dark, 0, (0.98 if fl % 2 else -0.98), 0)
		y += 5
	A.box(6.2, 0.3, 6.2, 0, 21.2, 0, wd)
	for s in [-1.0, 1.0]:
		A.box(6.2, 1.0, 0.12, 0, 21.9, s * 3.05, 0x7b5a3a); A.box(0.12, 1.0, 6.2, s * 3.05, 21.9, 0, 0x7b5a3a)
		for t in [-1.0, 1.0]:
			A.box(0.22, 3.2, 0.22, s * 2.9, 22.9, t * 2.9, wd)
	A.spire(7.4, 2.8, 7.4, 0, 24.5, 0, 0x3a2e26)
	A.cyl(0.05, 0.05, 4, 5, 0, 29, 0, 0xd8d4c8)
	A.box(1.6, 0.9, 0.04, 0.82, 30.4, 0, 0xf36f21)
	A.commit()

## white-red mushroom signposts (paddenstoelen) along the road
static func mushrooms() -> void:
	var NS := Trk.NS
	var HT := Trk.HT
	var pm := []; var dm := []
	for k in 9:
		var i := int(round(NS * (0.05 + k * 0.11))) % NS
		var s := 1 if k % 2 else -1
		var xz := Trk.onTrack(i, s * 12.2)
		pm.append(World.mtx(xz[0], HT[i] + 0.2, xz[1], 0, 1)); dm.append(World.mtx(xz[0], HT[i] + 0.85, xz[1], 0, 1))
	World.inst(Geo.cylinder(0.28, 0.3, 1, 10), M(0xf2f0ea), pm, null, true)
	World.inst(Geo.sphere(0.55, 12, 6, 0, PI * 2, 0, PI / 2), M(0xc8302a), dm, null, true)

## deer in small groups on open ground and at the forest edge near the road; most groups have a stag
static func deer(TF: Terrain) -> void:
	var NS := Trk.NS
	var hm := []; var sm := []
	var groups := 0
	for _k in 90:
		var i := int(floor(rnd() * NS))
		var side := -1 if rnd() < 0.5 else 1
		var xz := Trk.onTrack(i, side * (20 + rnd() * 34))
		var n := 3 + int(floor(rnd() * 4))
		var turn := rnd() * 6
		if groups >= 16: continue
		TF.at(xz[0], xz[1])
		if TF.d < 19 or wood(xz[0], xz[1]) > 0.25 or World.pavBusy(xz[0], xz[1], 8.0): continue
		groups += 1
		for q in n:
			var x: float = xz[0] + (rnd() - .5) * 11
			var z: float = xz[1] + (rnd() - .5) * 11
			var r := turn + (rnd() - .5) * 1.6
			var sc := 0.85 + rnd() * 0.3
			var stag := rnd() < 0.6
			var th := TF.at(x, z)
			if TF.d < 16: continue
			if q == 0 and stag: sm.append(World.mtx(x, th, z, r, 1.12))
			else: hm.append(World.mtx(x, th, z, r, sc))
	World.inst(BKit.deerGeo(false), BKit.vmat(), hm, null, true)
	World.inst(BKit.deerGeo(true), BKit.vmat(), sm, null, true)

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

## the flattest of a few spots beside the road: [x, z, highest ground, sample index, side]
static func flatSpot(TF: Terrain, fracs: Array, lat: float, r: float) -> Array:
	var best := []
	var bs := 1e9
	for f in fracs:
		for side in [-1.0, 1.0]:
			var i := int(round(Trk.NS * f)) % Trk.NS
			var xz := Trk.onTrack(i, side * lat)
			var lo := 1e9; var hi := -1e9
			var clear := true
			for a in 8:
				var h := TF.at(xz[0] + cos(a * PI / 4) * r, xz[1] + sin(a * PI / 4) * r)
				if TF.d < 15: clear = false
				lo = minf(lo, h); hi = maxf(hi, h)
			if clear and hi - lo < bs:
				bs = hi - lo
				best = [xz[0], xz[1], hi, i, side]
	return best

## a pancake house in the woods (every Veluwe outing ends at one): a timber house with a red roof on a stone terrace,
## parasols, tables, guests, lit windows and lanterns at night
static func pancakeHouse(TF: Terrain) -> void:
	var sp := cafe
	if sp.is_empty(): return
	var i: int = sp[3]
	var side: float = sp[4]
	# the front (local +z) looks at the road
	var ry := Trk.heading_of(Trk.T[i]) + (PI / 2 if side > 0 else -PI / 2)
	var A := BKit.Acc.new()
	A.at(sp[0], sp[2] + 0.25, sp[1], ry)
	var stone := 0x9a9082; var timber := 0x7a4f2e; var darkw := 0x4f3524; var roof := 0xa3432c
	A.box(26, 5, 20, 0, -2.5, 0, stone)                    # terrace on a plinth (the ground slopes away under it)
	A.box(13, 3.6, 8, -3, 1.8, -4.5, timber)
	A.roof(9.4, 3.2, 14, -3, 3.6, -4.5, roof, PI / 2)
	A.box(1.0, 2.2, 1.0, -7.5, 6.0, -5.5, 0x8a8076)
	A.box(4.6, 3.0, 5, 6, 1.5, -5.5, darkw)                # the kitchen annex with a lean-to roof
	A.box(5.2, 0.3, 5.6, 6, 3.2, -5.5, roof, 0, 0.1, 0)
	A.box(1.3, 2.3, 0.12, -3, 1.15, -0.46, darkw)          # door
	for wx in [-7.6, -5.6, -0.4, 1.6]:
		A.box(1.5, 0.12, 0.2, wx, 2.75, -0.46, 0xe8e4dc)      # white lintels over the windows
	for px in [-9.0, -4.5, 0.0, 4.5, 9.0]:
		for pz in [3.0, 7.0]:
			if absf(px + 3) < 1.6 and pz < 4: continue          # keep the way to the door free
			A.box(1.5, 0.08, 0.9, px, 0.76, pz, 0xc8b08a)
			A.box(0.12, 0.74, 0.12, px, 0.37, pz, darkw)
			A.box(1.5, 0.06, 0.3, px, 0.46, pz - 0.75, timber); A.box(1.5, 0.06, 0.3, px, 0.46, pz + 0.75, timber)
	for px in [-9.0, 0.0, 9.0]:
		A.cyl(0.05, 0.05, 2.7, 5, px, 1.35, 5.0, 0xd8d4c8)
		A.add(Geo.cone(2.3, 0.9, 8), 0xc8302a if px == 0.0 else 0xf2efe6, BKit.xf(px, 2.9, 5.0))
	# a low fence round the terrace
	A.box(26, 0.12, 0.12, 0, 0.9, 9.9, darkw)
	for fx in range(-13, 14, 2):
		A.box(0.14, 1.0, 0.14, fx, 0.5, 9.9, darkw)
	A.commit()
	# lit windows (World.winMats) and the name board
	var win := BKit.Acc.new(BKit.vmat({"emissive": 0x000000}), false)
	World.winMats.append(win.mat)
	win.frame = A.frame
	for wx in [-7.6, -5.6, -0.4, 1.6]:
		win.box(1.3, 1.3, 0.1, wx, 1.95, -0.47, 0x2a3440)
	win.commit()
	var board := Canvas2D.tex(256, 64, func(g, w, h):
		g.fillStyle = "#f2e6c8"; g.fillRect(0, 0, w, h); g.strokeStyle = "#7a4f2e"; g.lineWidth = 6; g.strokeRect(4, 4, w - 8, h - 8)
		g.fillStyle = "#7a2a1c"; g.font = "800 38px Barlow Condensed"; g.textAlign = "center"; g.textBaseline = "middle"
		g.fillText("PANNENKOEKEN", w / 2.0, h / 2.0 + 2, w - 24))
	var bg := Node3D.new()
	bg.transform = A.frame
	var bw := M(0x7a4f2e)
	O3.mesh(Geo.box(5.2, 1.2, 0.1), [bw, bw, bw, bw, M(0xffffff, {"map": board}), bw], -3, 4.1, -0.38, bg)
	World.add(bg)
	# lanterns on the terrace
	var lm := M(0xfff2c0, {"emissive": 0x3a3220})
	World.lampMats.append(lm)
	var lp := []
	for px in [-12.5, -4.3, 4.3, 12.5]:
		lp.append(A.frame * World.mtx(px, 2.3, 9.9))
	World.inst(Geo.box(0.3, 0.4, 0.3), lm, lp, null, false)
	var ppl := []
	for _k in 14:
		var p := A.frame * Vector3((rnd() - .5) * 22, 0.0, 1.6 + rnd() * 7.2)
		ppl.append([p.x, p.y, p.z, ry + rnd() * 6])
	BKit.crowd(ppl)

## hunting seats (hoogzit) at the forest edge: a little cabin on stilts with a ladder
static func huntingSeats(TF: Terrain) -> void:
	var A := BKit.Acc.new()
	var n := 0
	for _k in 60:
		var i := int(floor(rnd() * Trk.NS))
		var side := -1 if rnd() < 0.5 else 1
		var xz := Trk.onTrack(i, side * (26 + rnd() * 30))
		var ry := rnd() * 6
		if n >= 5: continue
		var th := TF.at(xz[0], xz[1])
		var wv := wood(xz[0], xz[1])
		if TF.d < 22 or wv < -0.15 or wv > 0.2 or World.pavBusy(xz[0], xz[1], 3.0): continue
		n += 1
		A.at(xz[0], th, xz[1], ry)
		for ab in [[-0.8, -0.8], [0.8, -0.8], [-0.8, 0.8], [0.8, 0.8]]:
			A.box(0.14, 4.4, 0.14, ab[0], 2.0, ab[1], 0x5a4028)
		A.box(2.0, 0.14, 2.0, 0, 3.6, 0, 0x6b4a2e)
		A.box(2.0, 0.9, 0.1, 0, 4.1, -0.95, 0x6b4a2e); A.box(0.1, 0.9, 2.0, -0.95, 4.1, 0, 0x6b4a2e); A.box(0.1, 0.9, 2.0, 0.95, 4.1, 0, 0x6b4a2e)
		A.box(2.3, 0.1, 2.3, 0, 5.4, 0, 0x3a2e26, 0, 0.12, 0)
		A.box(0.5, 4.2, 0.08, 0, 1.8, 1.5, 0x5a4028, 0, 0.33, 0)
	A.commit()

## heather tufts on the heath, boulders and the odd dead tree on the drift sand, close enough to the road to be seen
static func heathPlants(TF: Terrain) -> void:
	var NS := Trk.NS
	var hm := []; var hc := []; var bo := []; var dt := []
	var pal := [Color(0.44, 0.25, 0.47), Color(0.5, 0.29, 0.5), Color(0.38, 0.23, 0.42), Color(0.42, 0.34, 0.22), Color(0.3, 0.36, 0.2)]
	for _k in 5200:
		var i := int(floor(rnd() * NS))
		var side := -1 if rnd() < 0.5 else 1
		var xz := Trk.onTrack(i, side * (12.5 + pow(rnd(), 1.5) * 70))
		var s := 0.5 + rnd() * 0.9
		var ry := rnd() * 6
		var c: Color = World.pick(pal)
		var q := rnd()
		var x: float = xz[0]; var z: float = xz[1]
		var hv := heath(x, z)
		var sv := sand(x, z)
		if hv < 0.72 and sv < 0.8: continue
		var th := TF.at(x, z)
		if TF.d < 12.2 or World.pavBusy(x, z, 1.5): continue
		if sv > 0.8:
			if q < 0.1: bo.append(World.mtx(x, th + 0.1, z, ry, 0.6 + s, 0.4 + s * 0.5, 0.5 + s))
			elif q < 0.13 and TF.d > 16: dt.append(World.mtx(x, th - 0.2, z, ry, 0.8 + s * 0.4))
			elif q < 0.3:
				hm.append(World.mtx(x, th - 0.05, z, ry, s * 0.8, s * 0.7, s * 0.8)); hc.append(Color(0.5, 0.5, 0.28))
		else:
			hm.append(World.mtx(x, th - 0.1, z, ry, s * 0.9, s * 0.75, s * 0.9)); hc.append(c)
	World.inst(BKit.bushGeo(), M(0xffffff), hm, hc, false)
	World.inst(Geo.icosahedron(1.0, 0).translate(0, 0.3, 0), M(0x8a8780), bo, null, true)
	var dead := BKit.merge([
		[Geo.cylinder(0.1, 0.24, 5.0, 5, 1, true).translate(0, 2.5, 0), 0x9a9288],
		[Geo.cylinder(0.05, 0.1, 2.4, 4, 1, true).rotate_z(0.9).translate(-0.9, 4.0, 0), 0x9a9288],
		[Geo.cylinder(0.04, 0.09, 1.9, 4, 1, true).rotate_z(-0.8).translate(0.7, 3.1, 0.1), 0x9a9288],
		[Geo.cylinder(0.04, 0.07, 1.4, 4, 1, true).rotate_x(0.8).translate(0, 4.8, 0.5), 0x9a9288]])
	World.inst(dead, BKit.vmat(), dt, null, true)

## spectators behind the rail on the outside of the two tightest bends, and a wooden stand with a crowd at the start
static func fans(TF: Terrain) -> void:
	var NS := Trk.NS
	var bl := BKit.bends(0.016)
	bl.sort_custom(func(a, b): return a.kmax > b.kmax)
	var ppl := []
	for k in mini(2, bl.size()):
		var b: Dictionary = bl[k]
		ppl.append_array(BKit.crowdRow(b.apex - 14, 26, -b.dir * 14.6, 1.1, 2))
	# the stand: three steps along the start straight, on the side without the picnic tables
	var i0 := stand_i
	var xz := Trk.onTrack(i0, 13.4)
	var th := TF.at(xz[0], xz[1])
	var hd := Trk.heading_of(Trk.T[i0])
	var A := BKit.Acc.new()
	A.at(xz[0], maxf(th, Trk.HT[i0] - 0.3), xz[1], hd + PI / 2)
	for st in 3:
		A.box(16, 0.8 + st * 0.6 + 3.0, 1.2, 0, (0.8 + st * 0.6 - 3.0) / 2, -st * 1.2, 0x7a5a3a)
	A.box(16.4, 1.0, 0.12, 0, 2.9, -3.0, 0x5a4028)
	for px in [-8.1, 8.1]:
		A.box(0.14, 5.2, 0.14, px, 2.6, -3.0, 0x5a4028); A.box(0.14, 4.4, 0.14, px, 2.2, 0.6, 0x5a4028)
	A.box(16.8, 0.14, 4.4, 0, 4.9, -1.2, 0x8a3a2a, 0, -0.16, 0)
	A.commit()
	for st in 3:
		for q in 13:
			var skip := rnd() < 0.2
			var jx := (rnd() - .5) * 0.4
			if skip: continue
			var p := A.frame * Vector3(-7.2 + q * 1.2 + jx, 0.8 + st * 0.6, -st * 1.2)
			ppl.append([p.x, p.y, p.z, hd + PI / 2])
	BKit.crowd(ppl)

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
		pb.append([xz[0], Trk.HT[i] - 0.3, xz[1], Trk.heading_of(Trk.T[i])])
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
	var wood_m := M(0x7a5a3a)
	var tb := []; var bn := []; var lg := []
	for e in veluwePicnic:
		var x: float = e[0]
		var y: float = e[1]
		var z: float = e[2]
		var h: float = e[3]
		tb.append(World.mtx(x, y + 0.75, z, h, 0.8, 0.08, 2))
		for o in [-0.7, 0.7]:
			lg.append(World.mtx(x + sin(h) * o, y + 0.36, z + cos(h) * o, h, 1.7, 0.72, 0.1))
		for s in [-0.75, 0.75]:
			bn.append(World.mtx(x + cos(h) * s, y + 0.45, z - sin(h) * s, h, 0.3, 0.06, 2))
	World.inst(Geo.box(1, 1, 1), wood_m, tb, null, true)
	World.inst(Geo.box(1, 1, 1), wood_m, bn, null, true)
	World.inst(Geo.box(1, 1, 1), M(0x5a4028), lg, null, false)

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

static func build() -> void:
	var NS := Trk.NS
	var T := Trk.T
	var HT := Trk.HT
	var EMB := Trk.EMB
	TrackCommon.waterPlane(6000, 6000, 900, -100, -0.35, 0x4c7090)
	TrackCommon.landPlane(Canvas2D.tex(128, 128, func(g, w, h):
		g.fillStyle = "#78a64e"; g.fillRect(0, 0, w, h)
		for _i in 300:
			g.fillStyle = "rgba(255,255,255,.05)" if randf() < .5 else "rgba(0,0,0,.06)"
			g.fillRect(randf() * w, randf() * h, 3, 3), true), -230, -245, 2080, 32, 20)
	var grass := M(0x77a64c)
	var stone := M(0x6d6a64)
	var rail := M(0xffffff, {"map": TrackCommon.railTex()})
	var RH := Trk.ROAD_HALF
	var SH := Trk.SHOULDER
	World.ribbon(-RH, RH, World.roadMat(World.roadTexture("#5d5f62", [1.0 / 3, 2.0 / 3], true, false, 0.25)), 12, 0.07)
	World.ribbon(-SH, -RH, grass, 10, 0.05)
	World.ribbon(RH, SH, grass, 10, 0.05)
	World.ribbon(func(i): return -(SH + EMB[i]), -SH, grass, 10, 0.05)
	World.ribbon(SH, func(i): return SH + EMB[i], grass, 10, 0.05)
	World.ribbon(func(i): return SH + EMB[i], func(i): return SH + EMB[i] + 4, stone, 6, 0.04, func(i): return HT[i] > 3)
	World.vribbon(-9.2, 0.15, 0.9, rail, 4)
	World.vribbon(9.2, 0.15, 0.9, M(0xffffff, {"map": TrackCommon.railTex()}), 4)
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
	# the sluices at the end of the dike
	if true:
		var g := O3.group(-150, 0, -100)
		var con := M(0x9c9c96)
		var dark := M(0x2f3336)
		for k in 5:
			World.box(10, 9, 16, con, 0, 4.5, -40 + k * 20, g)
			if k < 4:
				World.box(4, 6, 3, dark, 0, 3, -30 + k * 20, g)
		World.add(g)
	var sheepB := []; var sheepH := []
	for _k in 90:
		var x := 40 + rnd() * 1600
		var z := -180 + rnd() * 160
		if Trk.distToTrack(x, z) < 12 + rnd() * 6: continue
		var cm := Transform3D(Basis(Vector3.UP, rnd() * 6.28), Vector3(x, 0, z))
		sheepB.append(cm * Transform3D(Basis(), Vector3(0, 0.75, 0)))
		# head top 3 cm above the back, not in its plane
		sheepH.append(cm * Transform3D(Basis(), Vector3(0, 0.98, 0.75)))
	World.inst(Geo.box(0.8, 0.8, 1.3), M(0xefece2), sheepB, null, true)
	World.inst(Geo.box(0.35, 0.4, 0.45), M(0x1f1f1f), sheepH, null, false)
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
		bm.append(World.mtx(xz[0], 0.9, xz[1], Trk.heading_of(Trk.T[i])))
	World.inst(Geo.box(5, 1.8, 4), con, bm, null, true)
	for k in 4:
		var x := 700 + k * 170
		var z := -330 - rnd() * 80
		var g := O3.group(x, 0, z)
		O3.rot(g, 0, rnd() * 6, 0)
		World.box(10, 1.4, 3.4, M(0x1d4f9e if k % 2 else 0x7a2a2a), 0, 0.2, 0, g)
		World.box(3, 2.2, 2.6, M(0xf3efe4), -2, 1.9, 0, g)
		World.box(0.15, 6, 0.15, M(0x5a5f63), 2, 3.4, 0, g)
		World.add(g)

class_name BuildHaven
## Port of buildHaven and detailHaven from polderrace-3d.html: quays, container stacks, cranes, two container ships, a shed,
## tall lamps; details: a railway along the quay with flat wagons, yellow straddle carriers and parked trucks.
## Same numbers, same seeded random order (World.rnd) as the JS.

static func M(c: int, o: Dictionary = {}) -> LMat:
	return Mats.M(c, o)

static func Mc(c: Color) -> LMat:
	var m := Mats.M(0xffffff)
	m.albedo_color = c
	return m

static func rnd() -> float:
	return World.rnd.next()

static func build() -> void:
	TrackCommon.waterPlane(6000, 6000, 300, -300, -0.6, 0x3e5a6e)
	TrackCommon.landPlane(Canvas2D.tex(256, 256, func(g, w, h):
		g.fillStyle = "#8a8c8e"; g.fillRect(0, 0, w, h); g.strokeStyle = "rgba(40,40,40,.25)"; g.lineWidth = 2
		var i := 0
		while i <= w:
			g.beginPath(); g.moveTo(i, 0); g.lineTo(i, h); g.stroke(); g.beginPath(); g.moveTo(0, i); g.lineTo(w, i); g.stroke()
			i += 64
		for _i in 14:
			g.fillStyle = "rgba(30,30,30,.12)"; g.beginPath(); g.ellipse(randf() * w, randf() * h, 6 + randf() * 16, 4 + randf() * 9, 0, 0, PI * 2); g.fill()
		g.fillStyle = "rgba(242,194,0,.5)"; g.fillRect(0, w / 2.0 - 2, w, 4), true), -320, -700, 1000, 160, 24)
	World.box(1320, 3, 2, M(0x55575a), 340, -1.2, -700, World.root, false)
	var conc := M(0x9a9c9e)
	var fence := M(0xffffff, {"map": Canvas2D.tex(64, 64, func(g, w, h):
		g.clearRect(0, 0, w, h); g.strokeStyle = "rgba(200,205,210,.9)"; g.lineWidth = 2
		var i := -64
		while i < 128:
			g.beginPath(); g.moveTo(i, 0); g.lineTo(i + 64, h); g.stroke(); g.beginPath(); g.moveTo(i + 64, 0); g.lineTo(i, h); g.stroke()
			i += 10
		g.fillStyle = "#8d9398"; g.fillRect(0, 0, w, 4); g.fillRect(0, 0, 4, h), true), "transparent": true, "alphaTest": 0.4})
	var RH := Trk.ROAD_HALF
	var SH := Trk.SHOULDER
	World.ribbon(-RH, RH, World.roadMat(World.roadTexture("#4a4c4f", [0.5], true, false, 0.35)), 10, 0.07)
	World.ribbon(-SH, -RH, conc, 8, 0.06); World.ribbon(RH, SH, conc, 8, 0.06)
	World.ribbon(func(i): return -(SH + Trk.EMB[i]), -SH, conc, 8, 0.05); World.ribbon(SH, func(i): return SH + Trk.EMB[i], conc, 8, 0.05)
	World.vribbon(-9.3, 0.06, 2.4, fence, 3); World.vribbon(9.3, 0.06, 2.4, fence.clone(), 3)
	World.startLine()
	World.gates(Trk.TRK)
	var ctex := Canvas2D.tex(64, 32, func(g, w, h):
		g.fillStyle = "#ffffff"; g.fillRect(0, 0, w, h); g.fillStyle = "rgba(0,0,0,.18)"
		var x := 0
		while x < w:
			g.fillRect(x, 0, 2, h); x += 4
		g.fillStyle = "rgba(0,0,0,.35)"; g.fillRect(0, 0, w, 2); g.fillRect(0, h - 2, w, 2))
	var pal: Array = ["#c4452a", "#1d4f9e", "#3f7d3a", "#d9a21b", "#8a8f96", "#ecece8", "#7a2a5a", "#2d8a8f", "#e2742a"].map(func(c): return Color(c))
	var cm := []; var cc := []
	for _k in 95:
		var x0 := -280 + rnd() * 1260
		var z0 := -680 + rnd() * 820
		var alongX := rnd() < 0.5
		var rows := 3 + int(floor(rnd() * 6))
		var cols := 1 + int(floor(rnd() * 3))
		for r in rows:
			for c in cols:
				var x := x0 + (c * 12.6 if alongX else r * 2.6)
				var z := z0 + (r * 2.6 if alongX else c * 12.6)
				if Trk.distToTrack(x, z) < 16 or Trk.distToTrack(x + (6 if alongX else 0), z + (0 if alongX else 6)) < 15 or Trk.distToTrack(x - (6 if alongX else 0), z - (0 if alongX else 6)) < 15:
					continue
				if z < -690: continue
				var hgt := 1 + int(floor(rnd() * 4))
				for y in hgt:
					cm.append(World.mtx(x, 1.3 + y * 2.6, z, PI / 2 if alongX else 0.0, 2.44, 2.6, 12.2))
					cc.append(World.pick(pal))
	World.inst(Geo.box(1, 1, 1), M(0xffffff, {"map": ctex}), cm, cc, true)
	var craneM := M(0xc4452a); var craneW := M(0xecece8); var bcn := M(0x551010, {"emissive": 0x220000}); var cabW := M(0x2c3a48)
	World.beaconMats.append(bcn); World.winMats.append(cabW)
	var cx := 20
	while cx <= 860:
		var g := O3.group(cx, 0, -690)
		for lxz in [[-9, -8], [9, -8], [-9, 8], [9, 8]]:
			World.box(1.2, 42, 1.2, craneM, lxz[0], 21, lxz[1], g)
		World.box(20, 2, 18, craneM, 0, 42, 0, g); World.box(4, 3, 110, craneM, 0, 45, -20, g); World.box(8, 6, 10, craneW, 0, 48, 8, g); World.box(8.2, 1.2, 6, cabW, 0, 49, 8, g, false)
		World.box(0.8, 0.8, 0.8, bcn, 0, 47, -75, g, false); World.box(0.8, 0.8, 0.8, bcn, 0, 51.5, 8, g, false)
		for lz in [-8, 8]:
			World.box(20, 1, 1, craneM, 0, 12, lz, g)
		World.add(g)
		cx += 165
	for sl in [[180.0, 220.0], [640.0, 190.0]]:
		var sx: float = sl[0]
		var len: float = sl[1]
		var g := O3.group(sx, 0, -752)
		World.box(len, 6, 32, M(0x1c2a44), 0, 1.5, 0, g); World.box(len + 0.2, 2, 32.2, M(0x8a2020), 0, -1, 0, g); World.box(22, 16, 30, M(0xecece8), -len / 2 + 16, 12, 0, g)
		World.box(22.3, 2.2, 30.3, M(0x2c3a48), -len / 2 + 16, 17.4, 0, g, false)
		World.add(g)
		var dm := []; var dc := []
		var x := -len / 2 + 34
		while x < len / 2 - 12:
			var z := -13.0
			while z <= 13:
				var y := 0
				while y < 1 + int(floor(rnd() * 4)):   # the JS draws a new number at every check of the loop condition
					dm.append(World.mtx(sx + x, 5.8 + y * 2.6, -752 + z, PI / 2, 2.44, 2.6, 12.2))
					dc.append(World.pick(pal))
					y += 1
				z += 2.6
			x += 12.6
		World.inst(Geo.box(1, 1, 1), M(0xffffff, {"map": ctex}), dm, dc, false)
	var shed := O3.group(820, 0, 40)
	World.box(140, 14, 60, M(0xb5b9bd), 0, 7, 0, shed)
	World.add(shed)
	var pm := M(0x8d9398)
	var hm := M(0x333a40, {"emissive": 0x222222})
	World.lampMats.append(hm)
	var lp := []; var lh := []
	var sd := 1
	var d := 20.0
	while d < Trk.TRACK_LEN:
		var i := int(round(d / Trk.SPC)) % Trk.NS
		sd = -sd
		var xz := Trk.onTrack(i, sd * 11)
		var h := Trk.HT[i]
		lp.append(World.mtx(xz[0], h + 12.5, xz[1]))
		lh.append(World.mtx(xz[0], h + 25, xz[1], Trk.heading_of(Trk.T[i])))
		var pxz := Trk.onTrack(i, sd * 4)
		World.trackLights.append([pxz[0], h, pxz[1], 13])
		d += 85
	World.inst(Geo.cylinder(0.25, 0.4, 25, 6), pm, lp, null, true)
	World.inst(Geo.box(3, 1, 1.2), hm, lh, null, false)

## JS detailHaven: a railway along the quay with container wagons, straddle carriers and parked trucks
static func details() -> void:
	var steel := M(0x6c7277)
	var sl := []
	var x := -250.0
	while x < 950:
		var z := -652.0
		if not Trk.distToTrack(x, z) < 14:
			sl.append(World.mtx(x, 0.08, z, 0, 0.25, 0.12, 2.6))
		x += 1.2
	World.inst(Geo.box(1, 1, 1), M(0x5a4636), sl, null, false)
	for o in [-0.72, 0.72]:
		World.box(1200, 0.14, 0.12, steel, 350, 0.2, -652 + o, World.root, false)
	var cols := ["#c4452a", "#1d4f9e", "#3f7d3a", "#d9a21b", "#ecece8"]
	for k in 12:
		var wx0 := -150 + k * 15.2
		if Trk.distToTrack(wx0, -652) < 16: continue
		var g := O3.group(wx0, 0, -652)
		World.box(14.4, 0.5, 2.6, M(0x2b2f36), 0, 1.1, 0, g); World.box(12.2, 2.6, 2.44, Mc(Color(World.pick(cols))), 0, 2.65, 0, g)
		for wx in [-5, 5]:
			for s in [-0.72, 0.72]:
				var w := O3.mesh(Geo.cylinder(0.45, 0.45, 0.2, 10), M(0x1b1b1b), wx, 0.5, s, g)
				O3.rot(w, PI / 2, 0, 0)
		World.add(g)
	var yel := M(0xf2c200)
	for _k in 7:
		var s = World.clearSpot(20)
		if s == null: continue
		var g := O3.group(s[0], 0, s[1])
		O3.rot(g, 0, rnd() * 6, 0)
		World.box(3.2, 2.4, 7, yel, 0, 1.6, 0, g); World.box(2.4, 2, 2, CarKit.glassMat.clone(), 0, 3.6, 1.5, g)
		var arm := World.box(0.9, 0.9, 9, yel, 0, 4.2, -2, g)
		O3.rot(arm, -0.35, 0, 0)
		for wxz in [[-1.5, 2.4], [1.5, 2.4], [-1.5, -2.4], [1.5, -2.4]]:
			var w := O3.mesh(Geo.cylinder(0.8, 0.8, 0.6, 12), M(0x1b1b1b), wxz[0], 0.8, wxz[1], g)
			O3.rot(w, 0, 0, PI / 2)
		World.add(g)
	for _k in 9:
		var s = World.clearSpot(18)
		if s == null: continue
		var t := Vehicles.makeTruck()
		t.g.position = Vector3(s[0], 0, s[1])
		t.g.rotation.y = round(rnd() * 4) * PI / 2
		World.add(t.g)

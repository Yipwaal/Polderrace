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

## footprints already taken by the yards, tanks and buildings ([x0, z0, x1, z1]): later decor keeps out of them
static var taken: Array = []
static func room(x0: float, z0: float, x1: float, z1: float) -> bool:
	for q in taken:
		if x1 > q[0] and x0 < q[2] and z1 > q[1] and z0 < q[3]: return false
	return true

## one material per colour for this build, so World.batch merges the parts of a group into few draw calls
static var _mm := {}
static func mm(c: int) -> LMat:
	if not _mm.has(c): _mm[c] = M(c)
	return _mm[c]

static func ctex() -> ImageTexture:
	return Canvas2D.tex(64, 32, func(g, w, h):
		g.fillStyle = "#ffffff"; g.fillRect(0, 0, w, h); g.fillStyle = "rgba(0,0,0,.18)"
		var x := 0
		while x < w:
			g.fillRect(x, 0, 2, h); x += 4
		g.fillStyle = "rgba(0,0,0,.35)"; g.fillRect(0, 0, w, 2); g.fillRect(0, h - 2, w, 2))

## a container: a unit box without its bottom face (nobody sees it; thousands of them)
static func cbox() -> Geo:
	var g := Geo.box(1, 1, 1)
	var ix := g.idx.slice(0, 18)
	ix.append_array(g.idx.slice(24))
	g.idx = ix
	g.groups = []
	return g

const PAL := ["#c4452a", "#1d4f9e", "#3f7d3a", "#d9a21b", "#8a8f96", "#ecece8", "#7a2a5a", "#2d8a8f", "#e2742a"]

## The container yards (Godot: in blocks on a grid with lanes between them; the JS threw stacks anywhere, 343 pairs
## of them stood inside each other). A block is rows of stacks along x, 1 to 4 high; nothing within 16 m of the road.
static func yards(tex: Texture2D) -> void:
	var pal: Array = PAL.map(func(c): return Color(c))
	var cm := []; var cc := []
	var bx := -300.0
	while bx < 960:
		var bz := -600.0
		while bz < 140:
			var cols := 2 + int(floor(rnd() * 3))
			var rows := 4 + int(floor(rnd() * 4))
			var x1 := bx + cols * 12.8
			var z1 := bz + rows * 2.8
			if room(bx - 2, bz - 2, x1 + 2, z1 + 2) and rnd() < 0.62:
				var used := false
				for c in cols:
					for r in rows:
						var x := bx + 6.4 + c * 12.8
						var z := bz + 1.4 + r * 2.8
						if Trk.distToTrack(x, z) < 16 or Trk.distToTrack(x + 6, z) < 15 or Trk.distToTrack(x - 6, z) < 15: continue
						if rnd() < 0.07: continue
						used = true
						var hgt := 1 + int(floor(rnd() * 3.4))
						for y in hgt:
							cm.append(World.mtx(x, 1.3 + y * 2.6, z, PI / 2, 2.44, 2.6, 12.2))
							cc.append(World.pick(pal))
				if used: taken.append([bx, bz, x1, z1])
			bz += 44
		bx += 62
	World.inst(cbox(), M(0xffffff, {"map": tex}), cm, cc, true)

## a farm of storage tanks with a bund wall round it and a pipe bridge
static func tankFarm(x0: float, z0: float) -> void:
	var g: Node3D = World.add(Node3D.new())
	var white := mm(0xe4e6e8); var roof := mm(0xb9bec3); var steel := mm(0x6c7277); var bund := mm(0x9a9c9e)
	for c in 3:
		for r in 3:
			var x := x0 + 16 + c * 32
			var z := z0 + 16 + r * 32
			var rad := 10.0 + rnd() * 3
			var hh := 12.0 + rnd() * 8
			O3.mesh(Geo.cylinder(rad, rad, hh, 20), white, x, hh / 2, z, g, true)
			O3.mesh(Geo.cone(rad + 0.3, 2.2, 20), roof, x, hh + 1.1, z, g, true)
			# the stair winding up the side, as a dark band
			var st := O3.mesh(Geo.cylinder(rad + 0.08, rad + 0.08, 0.5, 20, 1, true, 0.0, 1.1), steel, x, hh * 0.5, z, g, false)
			O3.rot(st, 0.0, rnd() * 6, 0.18)
	var w := 96.0 + 2
	for side in [[x0 - 1, z0 + w / 2 - 1, 0.6, w], [x0 + w - 1, z0 + w / 2 - 1, 0.6, w], [x0 + w / 2 - 1, z0 - 1, w, 0.6], [x0 + w / 2 - 1, z0 + w - 1, w, 0.6]]:
		World.box(side[2], 1.4, side[3], bund, side[0], 0.7, side[1], g)
	# pipe bridge along the farm
	var px := x0 + w + 4
	var z := z0
	while z <= z0 + w:
		World.box(0.4, 5, 0.4, steel, px, 2.5, z, g)
		z += 12
	for k in 3:
		var p := O3.mesh(Geo.cylinder(0.35, 0.35, w, 8), mm([0xc8302a, 0xd9a21b, 0x8d9398][k]), px - 0.6 + k * 0.6, 5.35, z0 + w / 2, g, false)
		O3.rot(p, PI / 2, 0, 0)
	taken.append([x0 - 2, z0 - 2, x0 + w + 6, z0 + w])

## the warehouse (JS: one grey box): corrugated walls, loading doors with a canopy, an office at the end and its name
static func shed(x: float, z: float) -> void:
	var g := O3.group(x, 0, z)
	var wall := M(0xffffff, {"map": Canvas2D.tex(128, 64, func(c, w, h):
		c.fillStyle = "#aeb4b9"; c.fillRect(0, 0, w, h)
		var i := 0
		while i < w:
			c.fillStyle = "rgba(0,0,0,.12)"; c.fillRect(i, 0, 3, h)
			c.fillStyle = "rgba(255,255,255,.10)"; c.fillRect(i + 4, 0, 2, h)
			i += 8
		c.fillStyle = "#1d4f9e"; c.fillRect(0, 0, w, 6), true), "repeat": Vector2(14, 1)})
	World.box(140, 14, 60, wall, 0, 7, 0, g)
	World.box(141, 0.8, 61, mm(0x5f6468), 0, 14.4, 0, g)
	var dark := mm(0x2b2f36)
	for k in 8:
		World.box(6, 6, 0.3, dark, -56 + k * 16, 3, -30.1, g, false)
		World.box(7, 0.4, 3.2, mm(0x8d9398), -56 + k * 16, 6.8, -31.6, g, false)
	World.box(18, 9, 12, mm(0xd9d3c3), 79, 4.5, -12, g)
	var win := M(0x2c3a48)
	World.winMats.append(win)
	for f in 2:
		World.box(16, 1.6, 0.2, win, 79, 3 + f * 3.6, -18.05, g, false)
	var sign := M(0xffffff, {"map": Canvas2D.tex(512, 96, func(c, w, h):
		c.fillStyle = "#1d4f9e"; c.fillRect(0, 0, w, h); c.fillStyle = "#f7f7f2"
		c.font = "800 60px Barlow Condensed"; c.textAlign = "center"; c.textBaseline = "middle"
		c.fillText("LOODS 7  ·  OVERSLAG", w / 2.0, h / 2.0 + 2))})
	World.box(34, 6.4, 0.2, sign, 0, 10.2, -30.2, g, false)
	World.add(g)
	taken.append([x - 74, z - 36, x + 92, z + 32])

## the high viaduct: where the road is higher than VIA it stands on columns (the JS had a solid concrete ramp of up to
## 23 m wide on both sides); lower down the ramp stays. Returns a Callable(i) that says where the deck is.
const VIA := 2.6
static func viaduct(conc: Material) -> Callable:
	var NS := Trk.NS
	var HT := Trk.HT
	var on := func(i): return HT[i] > VIA and HT[(i + 1) % NS] > VIA
	var deck := M(0x9a9c9e, {"side": "double"})
	World.ribbon(-9.45, 9.45, deck, 8, -1.5, on)
	World.vribbon(-9.45, -1.5, 0.25, deck, 8, on)
	World.vribbon(9.45, -1.5, 0.25, deck, 8, on)
	var g: Node3D = World.add(Node3D.new())
	var col := mm(0xa3a5a7)
	var last := -100.0
	for i in NS:
		var s := i * Trk.SPC
		var was: bool = on.call((i - 1 + NS) % NS)
		var now: bool = on.call(i)
		# the ends of the ramp: a wall across its section
		if was != now:
			var ab := Geo.new()
			var lats := [-(Trk.SHOULDER + Trk.EMB[i]) - 0.3, -Trk.SHOULDER, Trk.SHOULDER, Trk.SHOULDER + Trk.EMB[i] + 0.3]
			for l in lats:
				var xz := Trk.onTrack(i, l)
				ab.pos.append(Vector3(xz[0], Trk.hAt(i, l) - 0.02, xz[1])); ab.pos.append(Vector3(xz[0], -0.3, xz[1]))
				ab.uv.append(Vector2(l / 6.0, 1)); ab.uv.append(Vector2(l / 6.0, 0))
			for k in lats.size() - 1:
				var A := k * 2
				ab.idx.append_array([A, A + 1, A + 2, A + 1, A + 3, A + 2])
			ab.compute_vertex_normals()
			O3.receive(O3.mesh(ab, deck, 0, 0, 0, g))
		# columns every 32 m: a pair with a cross head under the deck
		if now and HT[i] > VIA + 1 and s - last >= 32:
			last = s
			var h := HT[i] - 1.5
			for sd in [-5.0, 5.0]:
				var xz := Trk.onTrack(i, sd)
				O3.mesh(Geo.cylinder(0.9, 1.0, h - 1.0, 10), col, xz[0], (h - 1.0) / 2, xz[1], g, true)
			var c := World.box(15, 1.2, 2.4, col, Trk.P[i].x, h - 0.58, Trk.P[i].z, g)
			O3.rot(c, 0, Trk.heading_of(Trk.T[i]), 0)
	return on

## quay walls round the land (the south one was there), fenders and bollards along the berths
static func quays() -> void:
	var g: Node3D = World.add(Node3D.new())
	var q := mm(0x55575a)
	World.box(1320, 3, 2, q, 340, -1.2, -700, g, false)
	World.box(1320, 3, 2, q, 340, -1.2, 161, g, false)
	World.box(2, 3, 863, q, -321, -1.2, -270, g, false)
	World.box(2, 3, 863, q, 1001, -1.2, -270, g, false)
	var fend := []; var bol := []
	var x := -300.0
	while x < 990:
		fend.append(World.mtx(x, -0.9, -701.3, 0, 1.6, 1.6, 0.6))
		bol.append(World.mtx(x + 6, 0.3, -699.6))
		x += 12
	World.inst(Geo.box(1, 1, 1), mm(0x1b1b1b), fend, null, false)
	World.inst(Geo.cylinder(0.25, 0.3, 0.6, 8), mm(0x2b2f36), bol, null, false)

static func build() -> void:
	taken = []
	_mm = {}
	TrackCommon.waterPlane(6000, 6000, 300, -300, -0.6, 0x3e5a6e)
	# the land: concrete slabs, darker and calmer than the JS's (it glared white in the sun), a few oil stains
	TrackCommon.landPlane(Canvas2D.tex(256, 256, func(g, w, h):
		g.fillStyle = "#7c7f82"; g.fillRect(0, 0, w, h)
		for _i in 900:
			g.fillStyle = "rgba(255,255,255,.04)" if randf() < .5 else "rgba(0,0,0,.05)"
			g.fillRect(randf() * w, randf() * h, 3, 3)
		g.strokeStyle = "rgba(40,40,40,.22)"; g.lineWidth = 2
		var i := 0
		while i <= w:
			g.beginPath(); g.moveTo(i, 0); g.lineTo(i, h); g.stroke(); g.beginPath(); g.moveTo(0, i); g.lineTo(w, i); g.stroke()
			i += 64
		for _i in 6:
			g.fillStyle = "rgba(30,30,30,.10)"; g.beginPath(); g.ellipse(32 + randf() * (w - 64), 32 + randf() * (h - 64), 6 + randf() * 14, 4 + randf() * 8, 0, 0, PI * 2); g.fill(), true), -320, -700, 1000, 160, 24, 40)
	quays()
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
	var on := viaduct(conc)
	var ramp := func(i): return not on.call(i)
	World.ribbon(func(i): return -(SH + Trk.EMB[i]), -SH, conc, 8, 0.05, ramp); World.ribbon(SH, func(i): return SH + Trk.EMB[i], conc, 8, 0.05, ramp)
	World.vribbon(-9.3, 0.06, 2.4, fence, 3); World.vribbon(9.3, 0.06, 2.4, fence.clone(), 3)
	World.startLine()
	World.gates(Trk.TRK)
	var tex := ctex()
	tankFarm(-300, -330)
	shed(820, 40)
	# the quay strip (cranes, rail, trucks) stays free of stacks
	taken.append([-330.0, -700.0, 1010.0, -618.0])
	yards(tex)
	var craneM := mm(0xc4452a); var craneW := mm(0xecece8); var bcn := M(0x551010, {"emissive": 0x220000}); var cabW := M(0x2c3a48)
	World.beaconMats.append(bcn); World.winMats.append(cabW)
	var cx := 20
	while cx <= 860:
		var g := O3.group(cx, 0, -690)
		for lxz in [[-9, -8], [9, -8], [-9, 8], [9, 8]]:
			World.box(1.2, 42, 1.2, craneM, lxz[0], 21, lxz[1], g)
		# sill beams on the rails, the portal, the boom out over the water (on the portal: it floated 0.5 m above it)
		for lx in [-9, 9]:
			World.box(1.6, 1.4, 19, craneM, lx, 0.7, 0, g)
		World.box(20, 2, 18, craneM, 0, 42, 0, g); World.box(4, 3, 110, craneM, 0, 44.5, -20, g); World.box(8, 6, 10, craneW, 0, 48, 8, g); World.box(8.2, 1.2, 6, cabW, 0, 49, 8, g, false)
		World.box(0.8, 0.8, 0.8, bcn, 0, 46.4, -74.6, g, false); World.box(0.8, 0.8, 0.8, bcn, 0, 51.4, 8, g, false)
		for lz in [-8, 8]:
			World.box(20, 1, 1, craneM, 0, 12, lz, g)
		# the trolley somewhere on the boom with its spreader hanging on two cables
		var tz := -60.0 + rnd() * 46   # clear of the portal (to -9)
		World.box(4.6, 1.6, 5, craneW, 0, 42.2, tz, g)
		var drop := 12.0 + rnd() * 18
		for sx in [-1.2, 1.2]:
			World.box(0.08, drop, 0.08, mm(0x2b2f36), sx, 41.4 - drop / 2, tz, g, false)
		World.box(2.8, 0.5, 12.6, mm(0xd9a21b), 0, 41.15 - drop, tz, g)
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
					dc.append(Color(World.pick(PAL)))
					y += 1
				z += 2.6
			x += 12.6
		World.inst(cbox(), M(0xffffff, {"map": tex}), dm, dc, false)
	var pm := M(0x8d9398)
	var hm := M(0x333a40, {"emissive": 0x222222})
	World.lampMats.append(hm)
	var lp := []; var lh := []
	var sd := 1
	var d := 20.0
	while d < Trk.TRACK_LEN:
		var i := int(round(d / Trk.SPC)) % Trk.NS
		sd = -sd
		var h := Trk.HT[i]
		# on the viaduct the mast is fixed to the side of the deck, elsewhere it stands beside the ramp
		var lat := 9.95 if on.call(i) else 11.0
		var base := h - 1.5 if on.call(i) else Trk.hAt(i, lat) - 0.3
		var xz := Trk.onTrack(i, sd * lat)
		var L := h + 24.6 - base
		lp.append(World.mtx(xz[0], base + L / 2, xz[1], 0, 1, L / 25.0, 1))
		lh.append(World.mtx(xz[0], h + 25, xz[1], Trk.heading_of(Trk.T[i])))
		var pxz := Trk.onTrack(i, sd * 4)
		World.trackLights.append([pxz[0], h, pxz[1], 13])
		d += 85
	World.inst(Geo.cylinder(0.25, 0.4, 25, 6), pm, lp, null, true)
	World.inst(Geo.box(3, 1, 1.2), hm, lh, null, false)
	# floodlight masts in the yards (their heads glow at night)
	var fm := []; var fh := []
	for q in taken:
		if q[2] - q[0] > 300: continue
		if rnd() < 0.5: continue
		var x: float = q[2] + 4
		var z: float = (q[1] + q[3]) / 2
		if Trk.distToTrack(x, z) < 14: continue
		fm.append(World.mtx(x, 15, z))
		fh.append(World.mtx(x, 30.4, z, 0, 2.6, 0.8, 2.6))
	World.inst(Geo.cylinder(0.3, 0.45, 30, 6), pm, fm, null, true)
	var fhm := M(0x3a4048, {"emissive": 0x222222})
	World.lampMats.append(fhm)
	World.inst(Geo.box(1, 1, 1), fhm, fh, null, false)
	TrackCommon.chevrons(8.75, 1.6, 0.02)
	# the shared dressing (crates) keeps out of the yards too
	World.noDress.append_array(taken)

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
	# a locomotive in front of the wagons
	if Trk.distToTrack(-170, -652) >= 16:
		var lg := O3.group(-170, 0, -652)
		World.box(15, 0.6, 2.8, mm(0x2b2f36), 0, 1.1, 0, lg); World.box(10, 2.6, 2.6, mm(0xf2c200), -1.5, 2.7, 0, lg)
		World.box(3.2, 3.2, 2.8, mm(0xc4452a), 5.6, 3.0, 0, lg); World.box(0.1, 1.0, 2.0, CarKit.glassMat, 7.22, 3.6, 0, lg, false)
		for wx in [-5, -2.5, 2.5, 5]:
			for sz in [-0.72, 0.72]:
				var w := O3.mesh(Geo.cylinder(0.45, 0.45, 0.2, 10), mm(0x1b1b1b), wx, 0.5, sz, lg)
				O3.rot(w, PI / 2, 0, 0)
		World.add(lg)
	var yel := M(0xf2c200)
	for _k in 7:
		var s = World.clearSpot(20)
		if s == null or not room(s[0] - 5, s[1] - 5, s[0] + 5, s[1] + 5): continue
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
		if s == null or not room(s[0] - 8, s[1] - 8, s[0] + 8, s[1] + 8): continue
		var t := Vehicles.makeTruck()
		# one rigid thing for the map tests: its parts need not touch each other (that is the model's business)
		t.g.set_meta("vehicle", true)
		t.g.position = Vector3(s[0], 0, s[1])
		t.g.rotation.y = round(rnd() * 4) * PI / 2
		World.add(t.g)

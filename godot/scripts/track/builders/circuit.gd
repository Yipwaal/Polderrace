class_name BuildCircuit
## Port of buildCircuit and detailCircuit from polderrace-3d.html: the dune circuit with kerbs, gravel traps, tyre walls,
## floodlight masts, grandstands, pit building, flags, dunes with marram grass and pines, the start bridge and marshal
## booths. Same numbers, same seeded random order (World.rnd).

static func M(c: int, o: Dictionary = {}) -> LMat:
	return Mats.M(c, o)

static func rnd() -> float:
	return World.rnd.next()

static func build() -> void:
	var NS := Trk.NS
	var SPC := Trk.SPC
	var T := Trk.T
	var HT := Trk.HT
	var TRACK_LEN := Trk.TRACK_LEN
	var RH := Trk.ROAD_HALF
	var SH := Trk.SHOULDER
	var START_I := Trk.START_I
	World.groundPlane(Canvas2D.tex(256, 256, func(g, w, h):
		g.fillStyle = "#b9ad84"; g.fillRect(0, 0, w, h)
		for _i in 260:
			g.fillStyle = "rgba(%d,%d,60,.55)" % [int(90 + randf() * 40), int(120 + randf() * 30)]
			g.beginPath(); g.ellipse(randf() * w, randf() * h, 6 + randf() * 16, 4 + randf() * 10, 0, 0, PI * 2); g.fill(), true), 50)
	var kerbMask := PackedByteArray()
	kerbMask.resize(NS)
	for i in NS:
		var a := T[(i - 4 + NS) % NS]
		var b := T[(i + 4) % NS]
		if acos(clampf(a.x * b.x + a.z * b.z, -1, 1)) > 0.07:
			for k in range(-6, 7):
				kerbMask[(i + k + NS) % NS] = 1
	var kerbTex := Canvas2D.tex(64, 128, func(g, w, h):
		g.fillStyle = "#d42b22"; g.fillRect(0, 0, w, h / 2); g.fillStyle = "#f4f4f0"; g.fillRect(0, h / 2, w, h / 2), true)
	var gravel := Canvas2D.tex(128, 128, func(g, w, h):
		g.fillStyle = "#b39f76"; g.fillRect(0, 0, w, h)
		for _i in 1400:
			g.fillStyle = "rgba(255,255,255,.2)" if randf() < .5 else "rgba(80,60,30,.2)"
			g.fillRect(randf() * w, randf() * h, 2, 2), true)
	var tyre := Canvas2D.tex(64, 64, func(g, w, h):
		g.fillStyle = "#1c1c1c"; g.fillRect(0, 0, w, h); g.fillStyle = "#f0f0ec"
		var y := 0
		while y < h:
			g.fillRect(0, y, w, 4); y += 22
		g.strokeStyle = "#333"; g.lineWidth = 3; g.beginPath(); g.moveTo(w / 2, 0); g.lineTo(w / 2, h); g.stroke(), true)
	# mown grass in two tones (the stripes run across the verge)
	var grass := M(0xffffff, {"map": Canvas2D.tex(64, 128, func(g, w, h):
		g.fillStyle = "#789d4a"; g.fillRect(0, 0, w, h / 2); g.fillStyle = "#83a852"; g.fillRect(0, h / 2, w, h / 2)
		for _i in 300:
			g.fillStyle = "rgba(255,255,220,.06)" if randf() < .5 else "rgba(20,50,10,.07)"
			g.fillRect(randf() * w, randf() * h, 3, 3), true)})
	var kerbOn := func(i): return kerbMask[i] != 0
	# gravel traps only round the bends (and a little before and after); grass everywhere else
	var trapMask := PackedByteArray()
	trapMask.resize(NS)
	for i in NS:
		if kerbMask[i] != 0:
			for k in range(-14, 15): trapMask[(i + k + NS) % NS] = 1
	var trapOn := func(i): return trapMask[i] != 0
	var trapOff := func(i): return trapMask[i] == 0
	World.ribbon(-RH, RH, World.roadMat(World.roadTexture("#4e5053", [], true)), 20, 0.07)
	World.ribbon(-RH - 1.3, -RH, M(0xffffff, {"map": kerbTex}), 4, 0.09, kerbOn); World.ribbon(RH, RH + 1.3, M(0xffffff, {"map": kerbTex}), 4, 0.09, kerbOn)
	World.ribbon(-13, -RH, grass, 10, 0.05); World.ribbon(RH, 13, grass, 10, 0.05)
	var gm := M(0xffffff, {"map": gravel}); World.ribbon(-SH, -13, gm, 6, 0.05, trapOn); World.ribbon(13, SH, gm, 6, 0.05, trapOn)
	World.ribbon(-SH, -13, grass, 10, 0.05, trapOff); World.ribbon(13, SH, grass, 10, 0.05, trapOff)
	World.ribbon(func(i): return -(SH + Trk.EMB[i]), -SH, M(0xa89f78), 10, 0.05); World.ribbon(SH, func(i): return SH + Trk.EMB[i], M(0xa89f78), 10, 0.05)
	var tm := M(0xffffff, {"map": tyre}); World.vribbon(-20.5, 0.05, 1.2, tm, 0.9); World.vribbon(20.5, 0.05, 1.2, M(0xffffff, {"map": tyre}), 0.9)
	World.startLine(); World.gates(Trk.TRK)
	# floodlight masts on alternating sides
	var mastM := M(0x9aa3ab)
	var head := M(0x333a40, {"emissive": 0x222222}); World.lampMats.append(head)
	var mp := []; var mh := []
	var sd := 1
	var d := 20.0
	while d < TRACK_LEN:
		var i := int(round(d / SPC)) % NS
		sd = -sd
		var xz := Trk.onTrack(i, sd * 23.5)
		var h := HT[i]
		var hm := Trk.hAt(i, 23.5)   # the foot of the mast: on the slope where the track runs on its dune dike (it floated)
		mp.append(World.mtx(xz[0], hm + 9, xz[1])); mh.append(World.mtx(xz[0], hm + 18, xz[1], Trk.heading_of(T[i])))
		var pxz := Trk.onTrack(i, sd * 9); World.trackLights.append([pxz[0], h, pxz[1], 16])
		d += 110
	World.inst(Geo.cylinder(0.25, 0.35, 18, 6), mastM, mp, null, true); World.inst(Geo.box(3, 1.2, 0.6), head, mh, null, false)

	var crowd := Canvas2D.tex(256, 64, func(g, w, h):
		g.fillStyle = "#3b4450"; g.fillRect(0, 0, w, h)
		var cs := ["#f36f21", "#f7f7f2", "#1d4f9e", "#d62a2a", "#f2c200", "#222"]
		for _i in 700:
			g.fillStyle = cs[int(randf() * cs.size())]; g.fillRect(randf() * w, randf() * h, 3, 4), true)
	# JS: crowd.repeat.set(len/12,1) on the one shared texture, so every stand ends up with the last stand's repeat
	var seats := []
	var grandstand := func(i: int, lat: float, len: float) -> void:
		var g := Node3D.new()
		var seat := M(0xffffff, {"map": crowd})
		var frame := M(0x9aa3ab)
		seats.append(seat)
		for sm in seats: Mats.set_repeat(sm, Vector2(len / 12, 1))
		var out := -signf(lat)
		for k in 7:
			World.box(1.5, 0.9 + k * 1.2, len, seat, out * k * 1.5, (0.9 + k * 1.2) / 2, 0, g)
		for z in [-len / 2, -len / 6, len / 6, len / 2]:
			World.box(0.3, 11, 0.3, frame, out * 10.5, 5.5, z, g)
		World.box(12, 0.35, len + 2, M(0xe9e9e4), out * 5, 11, 0, g)
		World.place(g, i, lat, 0)
	grandstand.call(START_I + 45, 26, 70); grandstand.call(START_I + 110, 26, 60)
	var hp := int(floor(NS / 2.0))
	var cps := Trk.cps
	if cps.size() > 0 and cps[int(floor(cps.size() / 2.0))] != 0:
		hp = cps[int(floor(cps.size() / 2.0))]
	grandstand.call(hp, 26, 50)
	# two more at the corners where it happens (flat ground): outside the chicane and outside the last hairpin
	for sx in [445.0, 2950.0]:
		var gi := int(round((sx if Trk.TRACK_DIR != "rev" else TRACK_LEN - sx) / SPC)) % NS
		var ga := T[(gi - 4 + NS) % NS]; var gb := T[(gi + 4) % NS]
		var gs := MathX.sgn(ga.z * gb.x - ga.x * gb.z)
		grandstand.call(gi, (gs if gs != 0 else 1.0) * 27, 44)
	# pit building with garage doors and a control tower
	var pg := Node3D.new()
	var white := M(0xecece8)
	World.box(16, 8, 130, white, 0, 4, 0, pg)
	var doors := Canvas2D.tex(512, 64, func(c, w, h):
		c.fillStyle = "#ecece8"; c.fillRect(0, 0, w, h)
		var x := 6
		while x < w:
			c.fillStyle = "#39424c"; c.fillRect(x, 14, 24, 50); x += 32)
	var f := O3.mesh(Geo.plane(130, 8), M(0xffffff, {"map": doors}), -8.02, 4, 0, pg)
	O3.rot(f, 0, -PI / 2, 0)
	World.box(8, 20, 8, white, 0, 10, 50, pg); World.box(10, 3, 10, M(0x2c3a48), 0, 21.5, 50, pg)
	World.place(pg, START_I + 60, -31, 0)
	var flagTex := Canvas2D.tex(96, 64, func(g, _w, _h):
		g.fillStyle = "#ae1c28"; g.fillRect(0, 0, 96, 22); g.fillStyle = "#fff"; g.fillRect(0, 22, 96, 21); g.fillStyle = "#21468b"; g.fillRect(0, 43, 96, 21))
	for k in 8:
		var g := Node3D.new()
		World.box(0.12, 9, 0.12, M(0xd2d5d7), 0, 4.5, 0, g)
		O3.mesh(Geo.plane(2.4, 1.6), M(0xffffff, {"map": flagTex, "side": "double"}), 1.25, 8, 0, g)
		World.place(g, START_I + 20 + k * 18, 23, 0)

	var tufts := []; var tuftC := []; var dunes := []
	for _k in 70:
		var s = Trk.randPos(World.rnd, 42)
		if s == null: continue
		var r := 14 + rnd() * 26
		var h := 3 + rnd() * 7
		# the whole dune stays behind the tyre wall (its long side can be 1.3 r)
		r = minf(r, (Trk.distToTrack(s[0], s[1]) - 22.5) / 1.3)
		dunes.append(World.mtx(s[0], 0, s[1], rnd() * 6, r, h, r * (0.7 + rnd() * 0.6)))
		for _j in 22:
			var a := rnd() * 6.28
			var dd := sqrt(rnd()) * r * 0.9
			var x: float = s[0] + cos(a) * dd
			var z: float = s[1] + sin(a) * dd
			var y := h * sqrt(maxf(0, 1 - (dd * dd) / (r * r)))
			tufts.append(World.mtx(x, y + 0.5, z, rnd() * 6, 0.9 + rnd() * 0.6, 1.2 + rnd() * 0.8, 0.9 + rnd() * 0.6))
			tuftC.append(MathX.hsl(0.17 + rnd() * 0.05, 0.35, 0.45 + rnd() * 0.1))
	for _k in 700:
		var s = Trk.randPos(World.rnd, 24)
		if s == null: continue
		tufts.append(World.mtx(s[0], 0.5, s[1], rnd() * 6, 0.9, 1.1 + rnd() * 0.6, 0.9))
		tuftC.append(MathX.hsl(0.18 + rnd() * 0.05, 0.35, 0.45 + rnd() * 0.1))
	# ---- Godot only: a belt of smaller dunes close behind the tyre wall all round the lap, with marram grass, pines and
	# people on them at the bends; not on the start straight (stands, pit building) and never nearer than the wall
	var folk := []
	var pines2 := []
	var dd2 := 40.0 + rnd() * 20
	while dd2 < TRACK_LEN:
		var i := int(round(dd2 / SPC)) % NS
		var s0 := fposmod(i * SPC - Trk.S_START, TRACK_LEN)
		var near_start := s0 < 300 or s0 > TRACK_LEN - 60
		for sd3 in [-1.0, 1.0]:
			var r := 9 + rnd() * 12
			var h := 2.2 + rnd() * 4.5
			var lat: float = sd3 * (Trk.SHOULDER + Trk.EMB[i] + 6 + r * 1.3 + rnd() * 30)
			var yaw := rnd() * 6
			var rz := r * (0.7 + rnd() * 0.6)
			var xz := Trk.onTrack(i, lat)
			var np := 2 + int(floor(rnd() * 5))
			if near_start or Trk.distToTrack(xz[0], xz[1]) < 22.5 + maxf(r, rz): continue
			dunes.append(World.mtx(xz[0], 0, xz[1], yaw, r, h, rz))
			for _j in 9:
				var a := rnd() * 6.28
				var q := sqrt(rnd()) * 0.85
				var lx := cos(a) * q; var lz := sin(a) * q
				var wp := World.mtx(xz[0], 0, xz[1], yaw, r, h, rz) * Vector3(lx, sqrt(maxf(0, 1 - q * q)), lz)
				tufts.append(World.mtx(wp.x, wp.y + 0.4, wp.z, rnd() * 6, 0.9 + rnd() * 0.6, 1.2 + rnd() * 0.8, 0.9 + rnd() * 0.6))
				tuftC.append(MathX.hsl(0.17 + rnd() * 0.05, 0.35, 0.45 + rnd() * 0.1))
			if rnd() < 0.5:
				var pxz := Trk.onTrack(i, lat + sd3 * (r + 4 + rnd() * 10))
				if Trk.distToTrack(pxz[0], pxz[1]) > 30: pines2.append(World.mtx(pxz[0], 4, pxz[1], rnd() * 6, 1 + rnd() * 0.4))
			# spectators on the dune top where the track bends
			if trapMask[i] != 0:
				for k in np:
					var a2 := k * 2.4 + yaw
					var wp2 := World.mtx(xz[0], 0, xz[1], yaw, r, h, rz) * Vector3(cos(a2) * 0.22, sqrt(1 - 0.22 * 0.22), sin(a2) * 0.22)
					folk.append([wp2.x, wp2.y - 0.05, wp2.z, yaw + k])
		dd2 += 26 + rnd() * 22
	# and people behind the tyre wall on the outside of every bend
	var bi := 0
	while bi < NS:
		if kerbMask[bi] != 0 and Trk.EMB[bi] < 2.0:
			var a := T[(bi - 4 + NS) % NS]; var b := T[(bi + 4) % NS]
			var sg := MathX.sgn(a.z * b.x - a.x * b.z)
			if sg != 0 and rnd() < 0.8:
				for k in 1 + int(floor(rnd() * 3)):
					var xz := Trk.onTrack(bi, sg * (24.8 + k * 0.9 + rnd() * 0.4))
					folk.append([xz[0] + T[bi].x * (rnd() - 0.5), Trk.hAt(bi, 25.0), xz[1] + T[bi].z * (rnd() - 0.5), Trk.heading_of(T[bi]) + PI / 2])
		bi += 2
	TrackCommon.people(folk)
	World.inst(Geo.cone(2.2, 8, 7), M(0x35512f), pines2, null, true)
	World.inst(Geo.sphere(1, 20, 10, 0, PI * 2, 0, PI / 2), M(0xd9c99c), dunes, null, false)
	# bend boards on top of the tyre wall, big enough to read from the track
	TrackCommon.chevrons(20.75, 1.6, 0.02, 12.0, 1.9)
	World.inst(Geo.cone(0.5, 1, 5), M(0xffffff), tufts, tuftC, false)
	var pines := []
	for _k in 120:
		var s = Trk.randPos(World.rnd, 40)
		if s != null: pines.append(World.mtx(s[0], 4, s[1], rnd() * 6, 1 + rnd() * 0.4))
	World.inst(Geo.cone(2.2, 8, 7), M(0x35512f), pines, null, true)

## JS detailCircuit: a sponsor bridge over the track 280 m after the start, and orange marshal booths
static func details() -> void:
	var NS := Trk.NS
	var SPC := Trk.SPC
	var i := (Trk.START_I + int(round(280 / SPC))) % NS
	var g := Node3D.new()
	var h := Trk.HT[i]
	var sp := M(0x1d4f9e)
	var wht := M(0xf7f7f2)
	var ban := Canvas2D.tex(1024, 128, func(c, w, hh):
		c.fillStyle = "#1d4f9e"; c.fillRect(0, 0, w, hh); c.fillStyle = "#f2c200"; c.fillRect(0, hh - 14, w, 14)
		c.fillStyle = "#f7f7f2"; c.font = "italic 800 78px Barlow Condensed"; c.textAlign = "center"; c.textBaseline = "middle"
		c.fillText("POLDERRACE · DUINCIRCUIT", w / 2.0, hh / 2.0 - 4))
	for s in [-1, 1]:
		World.box(1.6, 9, 1.6, wht, s * 24, 4.5, 0, g); World.box(2.4, 0.6, 2.4, sp, s * 24, 0.3, 0, g)
	O3.mesh(Geo.box(50, 3, 2.4), [sp, sp, sp, sp, M(0xffffff, {"map": ban}), M(0xffffff, {"map": ban})], 0, 10.2, 0, g, true)
	World.box(49.8, 1.1, 0.12, M(0x9aa3ab), 0, 12.2, 1.1, g, false); World.box(49.8, 1.1, 0.12, M(0x9aa3ab), 0, 12.2, -1.1, g, false)
	World.place(g, i, 0, 0)
	g.position.y = h
	var booth := M(0xf36f21)
	var d := 150.0
	while d < Trk.TRACK_LEN:
		var k := int(round(d / SPC)) % NS
		var s := 1 if int(d / 320) % 2 else -1
		var b2 := Node3D.new()
		World.box(2, 2.4, 2, booth, 0, 1.2, 0, b2); World.box(2.3, 0.2, 2.3, wht, 0, 2.5, 0, b2)
		World.box(0.08, 3.4, 0.08, wht, 0.9, 4.2, 0.9, b2, false); World.box(0.9, 0.6, 0.03, M(0xf2c200), 1.35, 5.5, 0.9, b2, false)
		World.place(b2, k, s * 23.2, 0)
		d += 320

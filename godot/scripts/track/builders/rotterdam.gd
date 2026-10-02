class_name BuildRotterdam
## Port of buildRotterdam from polderrace-3d.html: the Maas, the Erasmusbrug (pylon + stays), the red Willemsbrug, the
## skyline, the Euromast and water taxis. Same numbers, same seeded random order (World.rnd).

static func M(c: int, o: Dictionary = {}) -> LMat:
	return Mats.M(c, o)

static func rnd() -> float:
	return World.rnd.next()

## JS Math.round (halves go up, also for negative numbers)
static func jround(v: float) -> int:
	return int(floor(v + 0.5))

static func build() -> void:
	var NS := Trk.NS
	var P := Trk.P
	var R := Trk.R
	var HT := Trk.HT
	var EMB := Trk.EMB
	var RH := Trk.ROAD_HALF
	var SH := Trk.SHOULDER
	var rz0 := -300.0
	var rz1 := -160.0
	var overRiver := func(x: float, z: float) -> bool: return z > rz0 and z < rz1
	TrackCommon.waterPlane(5000, rz1 - rz0, 400, (rz0 + rz1) / 2, -0.6, 0x44606e)
	var pave := Canvas2D.tex(128, 128, func(g, w, h):
		g.fillStyle = "#86898c"; g.fillRect(0, 0, w, h); g.strokeStyle = "rgba(40,40,40,.2)"
		var i := 0
		while i < w:
			g.beginPath(); g.moveTo(i, 0); g.lineTo(i, h); g.stroke()
			g.beginPath(); g.moveTo(0, i); g.lineTo(w, i); g.stroke()
			i += 32, true)
	TrackCommon.landPlane(pave, Trk.BX0 - 500, rz1, Trk.BX1 + 500, Trk.BZ1 + 500, 20)
	TrackCommon.landPlane(pave, Trk.BX0 - 500, Trk.BZ0 - 500, Trk.BX1 + 500, rz0, 20)
	for z in [rz0, rz1]:
		World.box(Trk.BX1 - Trk.BX0 + 1000, 3, 1.2, M(0x5a5f63), (Trk.BX0 + Trk.BX1) / 2, -1, z, null, false)
	var land := func(i: int) -> bool: return not overRiver.call(P[i].x, P[i].z)
	var conc := M(0xa3a6a9)
	World.ribbon(-RH, RH, World.roadMat(World.roadTexture("#4d4f52", [0.25, 0.5, 0.75], true, false, 0.3)), 12, 0.07)
	World.ribbon(-SH, -RH, conc, 8, 0.06)
	World.ribbon(RH, SH, conc, 8, 0.06)
	World.ribbon(func(i): return -(SH + EMB[i]), -SH, conc, 8, 0.05, land)
	World.ribbon(SH, func(i): return SH + EMB[i], conc, 8, 0.05, land)
	var deck := M(0x8d9398)
	var rail := M(0x5a5f63)
	for s: int in [-1, 1]:
		World.vribbon(s * SH, -3, 0.1, deck, 4, func(i): return not land.call(i) or HT[i] > 1)
		World.vribbon(s * (SH - 0.2), 0.1, 1.1, rail, 3)
	World.startLine()
	World.gates(Trk.TRK)
	var cables := 0xe8ecef
	# Erasmusbrug pylon: the two legs stand in the river beside the deck (outside the railing), rise straight up to 16 m above
	# the road, are tied by a cross beam there and only then lean in to one mast. The stays fan out from the mast to the deck edges.
	if true:
		var ib := 0
		for i in NS:
			if HT[i] > HT[ib]: ib = i
		var g := Node3D.new()
		var wht := M(0xf2f4f5)
		var h := HT[ib]
		var lx := SH + 3
		var kn := h + 16
		var mt := h + 44
		World.place(g, ib, 0, 0)
		g.position.y = 0
		# each arm runs from the top of its leg (lx,kn) to x=1 under the mast; it reaches 0.4 m into the leg and 1.2 m into the mast,
		# so its cross-section at the knee is exactly the top of the leg and no corner sticks out of the leg or the mast
		for s: int in [-1, 1]:
			World.box(2.4, kn + 2, 2.8, wht, s * lx, (kn - 2) / 2, 0, g)
			var dx := lx - 1
			var dy := mt - kn
			var L := sqrt(dx * dx + dy * dy)
			var ux := -s * dx / L
			var uy := dy / L
			var a := World.box(2.2, L + 1.6, 2.4, wht, (s * lx - ux * 0.4 + s + ux * 1.2) / 2, (kn - uy * 0.4 + mt + uy * 1.2) / 2, 0, g)
			O3.rot(a, 0, 0, s * atan2(dx, dy))
		World.box(lx * 2, 2.2, 2, wht, 0, kn - 1.4, 0, g)
		World.box(lx * 2, 1.8, 2, wht, 0, h - 3.8, 0, g, false)
		World.box(3.2, 40, 3.2, wht, 0, mt + 18, 0, g)
		# (the JS adds g to the world a second time here: it is already there)
		# on the curved approaches a stay to a far anchor cuts the corner over the inner lanes: only build stays that stay 8 m above the lanes
		for k in range(-12, 13):
			if k == 0: continue
			var j := (ib + k * 6 + NS) % NS
			for s: int in [-1, 1]:
				var axz := Trk.onTrack(ib, s * 1.7)
				var bxz := Trk.onTrack(j, s * (SH + 0.15))
				var ax: float = axz[0]
				var az: float = axz[1]
				var bx: float = bxz[0]
				var bz: float = bxz[1]
				var Ay := mt + 12 + absi(k) * 2
				var By := HT[j] + 0.05
				var low := false
				var q := 1
				while q < 120 and not low:
					var f := q / 120.0
					var x := ax + (bx - ax) * f
					var z := az + (bz - az) * f
					var bi := ib
					var bd := 1e9
					for m in range(-80, 81):
						var i := (ib + m + NS) % NS
						var ex := x - P[i].x
						var ez := z - P[i].z
						var d := ex * ex + ez * ez
						if d < bd:
							bd = d
							bi = i
					if absf((x - P[bi].x) * R[bi].x + (z - P[bi].z) * R[bi].z) <= RH and Ay + (By - Ay) * f - HT[bi] < 8:
						low = true
					q += 1
				if not low:
					World.wire([Vector3(ax, Ay, az), Vector3(bx, By, bz)], cables)
	# Willemsbrug: two red portal frames on the river bridge west of x=200
	if true:
		var best := -1.0
		var bi := 0
		for i in NS:
			if not land.call(i) and P[i].x < 200 and HT[i] > best:
				best = HT[i]
				bi = i
		var red := M(0xc8302a)
		for off: int in [-20, 20]:
			var j := (bi + jround(off / Trk.SPC) + NS) % NS
			var g := Node3D.new()
			for s: int in [-1, 1]:
				World.box(1.6, 26, 1.6, red, s * 11, HT[j] + 10, 0, g)
			World.box(24, 2, 1.8, red, 0, HT[j] + 22, 0, g)
			World.place(g, j, 0, 0)
			g.position.y = 0
	var tw := []; var tc := []
	var twm := M(0xffffff, {"map": TrackCommon.facadeTex(10), "emissive": 0x000000, "emissiveMap": Canvas2D.tex(128, 256, func(g, w, h):
		g.fillStyle = "#000"; g.fillRect(0, 0, w, h)
		var fh: float = h / 10.6
		for f in 10:
			for wx in [14, 52, 90]:
				if randf() < 0.55:
					g.fillStyle = "#ffe0a0"; g.fillRect(wx, h - fh * (f + 1) - 4, 24, fh * 0.62))})
	World.winMats.append(twm)
	var tcols := ["#8fa3b5", "#c9ced3", "#5a6a7a", "#e0ddd5", "#3f4a55", "#a88f6a"].map(func(c): return Color(c))
	for _k in 120:
		var x := Trk.BX0 - 300 + rnd() * (Trk.BX1 - Trk.BX0 + 600)
		var z := Trk.BZ0 - 300 + rnd() * (Trk.BZ1 - Trk.BZ0 + 600)
		if overRiver.call(x, z) or absf(z - rz0) < 30 or absf(z - rz1) < 30 or Trk.distToTrack(x, z) < 24: continue
		var h := (30.0 if z < rz0 else 40.0) + rnd() * (120.0 if z > rz1 else 60.0)
		var w := 14 + rnd() * 16
		var ry := 0.0 if rnd() < 0.5 else PI / 2
		var dz := w * (0.7 + rnd() * 0.6)
		tw.append(World.mtx(x, h / 2, z, ry, w, h, dz))
		tc.append(World.pick(tcols))
	World.inst(Geo.box(1, 1, 1), twm, tw, tc, true)
	# Euromast
	if true:
		var s = World.clearSpot(40)
		if s != null:
			var g := O3.group(s[0], 0, s[1])
			O3.mesh(Geo.cylinder(2.4, 3, 100, 14), M(0xe8e4dc), 0, 50, 0, g)
			O3.mesh(Geo.cylinder(7, 7, 4, 18), M(0x5a6a7a), 0, 90, 0, g)
			O3.mesh(Geo.cylinder(0.5, 1, 24, 8), M(0xc8302a), 0, 112, 0, g)
			World.add(g)
	# water taxis on the Maas
	for k in 5:
		var gx := -300 + k * 300 + rnd() * 80
		var gz := (rz0 + rz1) / 2 + (rnd() - .5) * 80
		var g := O3.group(gx, 0, gz)
		O3.rot(g, 0, PI / 2 + (rnd() - .5) * 0.3, 0)
		World.box(4, 1.6, 11, M(0xf2c200 if k % 2 else 0xecece8), 0, 0.3, 0, g)
		World.box(3.2, 1.8, 5, M(0x2b2f36), 0, 1.7, -1, g)
		World.add(g)
	TrackCommon.lampRow(9.2, 45, 9, {"both": true})

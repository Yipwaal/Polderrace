class_name BuildZeeland
## Port of buildZeeland from polderrace-3d.html: sand islands, the Oosterscheldekering (storm-surge barrier), dunes with
## marram grass, the lighthouse and fishing boats. Same numbers, same seeded random order (World.rnd).

static func M(c: int, o: Dictionary = {}) -> LMat:
	return Mats.M(c, o)

static func rnd() -> float:
	return World.rnd.next()

## JS Math.round (halves go up, also for negative numbers)
static func jround(v: float) -> int:
	return int(floor(v + 0.5))

## JS Math.hypot in doubles (Vector2 is single precision)
static func hyp(a: float, b: float) -> float:
	return sqrt(a * a + b * b)

## heading from point a to point b ([x, z] arrays)
static func hd(a: Array, b: Array) -> float:
	return atan2(b[0] - a[0], b[1] - a[1])

## the landhoofd spot: 8 m past barrier end k, in the barrier's direction
static func barrierEnd(Q: Array, k: int) -> Array:
	var q: Array = Q[k]
	var o: Array = Q[k - 1 if k else 1]
	var l := hyp(q[0] - o[0], q[1] - o[1])
	return [q[0] + (q[0] - o[0]) / l * 8, q[1] + (q[1] - o[1]) / l * 8]

static func build() -> void:
	var NS := Trk.NS
	var P := Trk.P
	var R := Trk.R
	var EMB := Trk.EMB
	var RH := Trk.ROAD_HALF
	var SH := Trk.SHOULDER
	TrackCommon.waterPlane(7000, 7000, 700, 150, -0.35, 0x3f6a86)
	var sand := Canvas2D.tex(128, 128, func(g, w, h):
		g.fillStyle = "#d8c898"; g.fillRect(0, 0, w, h)
		for _i in 400:
			g.fillStyle = "rgba(255,255,255,.08)" if randf() < .5 else "rgba(0,0,0,.06)"
			g.fillRect(randf() * w, randf() * h, 2, 2), true)
	var islands := [[-160, -60, 260, 420], [1250, 20, 1700, 460], [120, 180, 1300, 440]]
	for k in islands.size():
		var isl: Array = islands[k]
		TrackCommon.landPlane(sand, isl[0], isl[1], isl[2], isl[3], 16).position.y = 0.012 * k
	var grass := M(0x8aa65a)
	var stone := M(0x6d6a64)
	World.ribbon(-RH, RH, World.roadMat(World.roadTexture("#5b5d60", [1.0 / 3, 2.0 / 3], true, false, 0.25)), 12, 0.07)
	World.ribbon(-SH, -RH, grass, 10, 0.05)
	World.ribbon(RH, SH, grass, 10, 0.05)
	World.ribbon(func(i): return -(SH + EMB[i]), -SH, stone, 6, 0.05)
	World.ribbon(SH, func(i): return SH + EMB[i], stone, 6, 0.05)
	var rt := Canvas2D.tex(64, 32, func(g, w, h):
		g.fillStyle = "#b9bec3"; g.fillRect(0, 0, w, h); g.fillStyle = "#8d9398"; g.fillRect(0, 10, w, 3); g.fillRect(0, 20, w, 3), true)
	World.vribbon(-9.1, 0.15, 0.9, M(0xffffff, {"map": rt}), 4)
	World.vribbon(9.1, 0.15, 0.9, M(0xffffff, {"map": rt}), 4)
	World.startLine()
	World.gates(Trk.TRK)
	# Oosterscheldekering: one continuous barrier on its own gently curved line (a Bezier in world coordinates, so the same in both
	# driving directions) on the sea side of the dam. Piers stand at one fixed spacing; the road girder, the upper beam and the gates
	# run from pier centre to pier centre, so every joint lies inside a pier (the piers are wider and higher than what they carry).
	# A landhoofd closes both ends. Piers stay 4 m off the toe of the dike; should the track ever come closer, the line moves out to sea.
	if true:
		var con := M(0x9c9c96)
		var dark := M(0x2f3336)
		var pm := []; var sp := []; var gm := []; var hm := []
		var Q := []
		var off := 0
		while off <= 60:
			var A := [285.0, -62.0 - off]
			var B := [640.0, -145.0 - off]
			var C := [980.0, -180.0 - off]
			var D := [1238.0, -50.0 - off]
			var L := []
			var len := 0.0
			var pv = null
			for k in 401:
				var t := k / 400.0
				var u := 1 - t
				var a := u * u * u
				var b := 3 * u * u * t
				var c := 3 * u * t * t
				var e := t * t * t
				var p := [a * A[0] + b * B[0] + c * C[0] + e * D[0], a * A[1] + b * B[1] + c * C[1] + e * D[1]]
				if pv != null: len += hyp(p[0] - pv[0], p[1] - pv[1])
				L.append([len, p])
				pv = p
			var n := jround(len / 45)
			Q = []
			var j := 0
			for k in n + 1:
				var s := len * k / n
				while j < L.size() - 2 and L[j + 1][0] < s: j += 1
				var s0: float = L[j][0]
				var p0: Array = L[j][1]
				var s1: float = L[j + 1][0]
				var p1: Array = L[j + 1][1]
				var ds := s1 - s0
				var f := (s - s0) / (ds if ds != 0 else 1.0)
				Q.append([p0[0] + (p1[0] - p0[0]) * f, p0[1] + (p1[1] - p0[1]) * f])
			var ok := true
			for q in Q:
				if not (Trk.distToTrack(q[0], q[1]) - SH >= 9.5):
					ok = false
					break
			if ok:
				for k: int in [0, n]:
					var ep := barrierEnd(Q, k)
					if not (Trk.distToTrack(ep[0], ep[1]) - SH >= 14.3):
						ok = false
						break
			if ok: break
			off += 6
		var m := Q.size() - 1
		for k in m + 1:
			var x: float = Q[k][0]
			var z: float = Q[k][1]
			var ry := hd(Q[maxi(0, k - 1)], Q[mini(m, k + 1)])
			pm.append(World.mtx(x, 10.9, z, ry, 11, 27.8, 6))
			hm.append(World.mtx(x, 26.3, z, ry, 4.5, 3, 5))
			if k == 0: continue
			var x0: float = Q[k - 1][0]
			var z0: float = Q[k - 1][1]
			var l := hyp(x - x0, z - z0)
			var r := hd(Q[k - 1], Q[k])
			var mx := (x + x0) / 2
			var mz := (z + z0) / 2
			sp.append(World.mtx(mx, 23.2, mz, r, 10, 2.4, l))
			sp.append(World.mtx(mx, 18, mz, r, 4, 3, l))
			gm.append(World.mtx(mx, 11.95, mz, r, 1, 9.9, l))
		for k: int in [0, m]:
			var q: Array = Q[k]
			var o: Array = Q[k - 1 if k else 1]
			var ry := hd(o, q)
			var l := hyp(q[0] - o[0], q[1] - o[1])
			var ux: float = (q[0] - o[0]) / l
			var uz: float = (q[1] - o[1]) / l
			var cx: float = q[0] + ux * 8
			var cz: float = q[1] + uz * 8
			pm.append(World.mtx(cx, 11.1, cz, ry, 13, 28.2, 16))
			O3.rot(World.box(20, 3.2, 26, stone, cx, -0.4, cz), 0, ry, 0)
			# a low stone dam ties the landhoofd to the dike of the road: it runs into the dike slope, halfway up (buried there)
			var bi := 0
			var bd := 1e12
			for i in NS:
				var d := (P[i].x - cx) ** 2 + (P[i].z - cz) ** 2
				if d < bd:
					bd = d
					bi = i
			var sd := signf((cx - P[bi].x) * R[bi].x + (cz - P[bi].z) * R[bi].z)
			if sd == 0: sd = 1
			var dxz := Trk.onTrack(bi, sd * (SH + EMB[bi] * 0.5))
			var dx: float = dxz[0]
			var dz: float = dxz[1]
			O3.rot(World.box(14, 2.8, hyp(dx - cx, dz - cz), stone, (cx + dx) / 2, -0.5, (cz + dz) / 2), 0, atan2(dx - cx, dz - cz), 0)
		World.inst(Geo.box(1, 1, 1), con, pm, null, true)
		World.inst(Geo.box(1, 1, 1), con, sp, null, true)
		World.inst(Geo.box(1, 1, 1), dark, gm, null, false)
		World.inst(Geo.box(1, 1, 1), M(0xb4b2aa), hm, null, true)
	# a dune reaches 2s from its centre and distToTrack is measured from the dike toe: shrink dunes near the road so the whole
	# dune (and its grass) stays 4 m clear of the verge, skip the ones that would get too small. Same rnd() calls as before.
	var dn := []; var gr := []
	for _k in 160:
		var x := 120 + rnd() * 1200
		var z := 300 + rnd() * 140
		if Trk.distToTrack(x, z) < 14: continue
		var s := minf(4 + rnd() * 8, (Trk.distToTrack(x, z) - SH - 4) / 2)
		var d := World.mtx(x, -s * 0.25, z, rnd() * 6, s * 2, s, s * 1.6)
		var g := []
		for _q in 3:
			var gx := x + (rnd() - .5) * s
			var gz := z + (rnd() - .5) * s
			g.append(World.mtx(gx, s * 0.45, gz, rnd() * 6, 0.6, 0.9, 0.6))
		if s < 3: continue
		dn.append(d)
		gr.append_array(g)
	World.inst(Geo.sphere(1, 9, 6), M(0xd8c898), dn, null, true)
	World.inst(Geo.cone(0.6, 1.4, 5), M(0x9aa64a), gr, null, false)
	# lighthouse
	if true:
		var g := O3.group(-120, 0, 150)
		for k in 6:
			O3.mesh(Geo.cylinder(2.4 - k * 0.15, 2.55 - k * 0.15, 5, 14), M(0xecece8 if k % 2 else 0xc8302a), 0, 2.5 + k * 5, 0, g)
		var lamp := M(0xfff2c0, {"emissive": 0x807040})
		World.lampMats.append(lamp)
		O3.mesh(Geo.cylinder(1.6, 1.6, 2.4, 10), lamp, 0, 31.5, 0, g)
		World.box(3.8, 0.4, 3.8, M(0x2b2f36), 0, 33, 0, g)
		World.add(g)
	# fishing boats
	for k in 5:
		var g := O3.group(300 + k * 230, 0, -220 - rnd() * 120)
		O3.rot(g, 0, rnd() * 6, 0)
		World.box(18, 2, 5, M(0x1d4f9e if k % 2 else 0x2e5d3e), 0, 0.4, 0, g)
		World.box(5, 3, 4, M(0xecece8), -5, 2.8, 0, g)
		World.box(0.3, 10, 0.3, M(0x5a5f63), 3, 6, 0, g)
		World.add(g)
	TrackCommon.signs([["Neeltje Jans", "2"], ["Zierikzee", "12"], ["Middelburg", "24"]], 10.2)
	TrackCommon.lampRow(8.9, 90, 10, {})

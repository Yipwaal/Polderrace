class_name BuildZeeland
## Zeeland. Started as a port of buildZeeland from polderrace-3d.html (sand islands, the Oosterscheldekering, dunes with
## marram grass, the lighthouse, fishing boats); fase 2 made a delta of it: islands with a natural coastline, beaches and
## salt marsh (one ground mesh, no flat rectangles that overlap), polder fields and a village with a church, dunes with
## marram grass, a beach with groynes of wooden poles, beach huts, pavilions on piles, wind breaks, parasols and kites,
## surf that rolls up the beach, a wind farm at sea and turbines along the inner shore (the rotors turn), sailing boats,
## fishing cutters and a container ship far out, a red-and-white lighthouse with a turning beam at night, lamps on the
## barrier, arrow boards, reflector posts and fans in the loop. Everything random: seeded World.rnd.

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

## the islands [x0, z0, x1, z1]: Walcheren with the start and the lighthouse, the island of the loop in the east and the
## long island of the way back with the beach on its north side (the North Sea); the Oosterschelde lies between them
## and the dam. Their edges get a wavy coastline (coastN).
const ISL := [[-170.0, -70.0, 270.0, 430.0], [1240.0, 10.0, 1720.0, 520.0], [110.0, 170.0, 1310.0, 520.0]]
const GX0 := -330.0
const GZ0 := -190.0
const GC := 12.0         ## ground grid cell
const GNX := 187         ## cells along x (to x = 1914)
const GNZ := 74          ## cells along z (to z = 698)
const VX := 760.0        ## the village (its church)
const VZ := 248.0

static func coastN(x: float, z: float) -> float:
	return 8.0 * sin(x * 0.011 + z * 0.006) + 5.0 * sin(z * 0.019 - x * 0.008 + 1.3) + 3.0 * sin((x + z) * 0.043 + 0.7)

## how far (m) a point lies inside the islands (negative: out at sea)
static func islandL(x: float, z: float) -> float:
	var best := -1e9
	for r in ISL:
		best = maxf(best, minf(minf(x - r[0], r[2] - x), minf(z - r[1], r[3] - z)))
	return best + coastN(x, z)

## distance beyond the dike toe of the road, from the grid (nearD - shoulder), and the land value with the dike's foreshore
static var nearD := PackedFloat32Array()
static func gidx(ix: int, iz: int) -> int:
	return iz * (GNX + 1) + ix

## ground height of the grid at a point (bilinear), for decor on the beach
static func toe(x: float, z: float) -> float:
	var fx := clampf((x - GX0) / GC, 0, GNX - 0.001)
	var fz := clampf((z - GZ0) / GC, 0, GNZ - 0.001)
	return nearD[gidx(int(fx), int(fz))] - Trk.SHOULDER

static func landV(x: float, z: float, nd: float) -> float:
	# within 16 m of the dike toe there is always land: the salt marsh in front of the dam, where the reeds grow
	return maxf(islandL(x, z), 16.0 - (nd - Trk.SHOULDER))

static func heightOf(L: float) -> float:
	var y := 0.0 if L >= 0.0 else maxf(-2.2, L * 0.11)
	# no grid point near the water level (-0.35) or the surf (-0.32): a big beach triangle lying just above or under
	# the water would flicker with it; this way every triangle that meets the water crosses it at an angle
	if absf(y + 0.35) < 0.09: y = -0.26 if y > -0.35 else -0.44
	return y

## the north coast: z of the waterline at x (stepping out from the dunes), for the beach
static func coastZ(x: float) -> float:
	var z := 380.0
	while z < 680.0 and islandL(x, z) > -3.0: z += 1.0
	return z

static func dunes(x: float, z: float) -> bool:
	return x > 90 and z > 418 + 8 * sin(x * 0.013)

static func hash2(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 10007) / 10007.0

static func groundCol(x: float, z: float, L: float, iL: float, nd: float) -> Color:
	var n := 0.5 + 0.25 * sin(x * 0.07 + z * 0.05) + 0.25 * sin(x * 0.023 - z * 0.061)
	var sand := Color(0.83, 0.74, 0.55).lerp(Color(0.78, 0.69, 0.5), n)
	var wet := Color(0.64, 0.57, 0.42)
	var dike := Color(0.44, 0.57, 0.29).lerp(Color(0.5, 0.6, 0.32), n)
	var beyond := nd - Trk.SHOULDER
	if L < 0.0: return wet.darkened(clampf(-L * 0.05, 0, 0.4))
	if iL < -1.0:
		# the marsh in front of the dam: grass and mud, sand at its edge
		var marsh := Color(0.43, 0.5, 0.3).lerp(Color(0.5, 0.5, 0.36), n)
		return wet.lerp(marsh, clampf(L / 5.0, 0, 1))
	if L < 3.0: return wet.lerp(sand, L / 3.0)
	if beyond < 14.0: return dike
	if L < 30.0: return sand
	if dunes(x, z):
		return sand.lerp(Color(0.6, 0.6, 0.38), clampf((L - 30.0) / 30.0, 0, 0.55) * (0.6 + 0.4 * n))
	if L < 38.0: return sand.lerp(dike, (L - 30.0) / 8.0)
	if beyond < 26.0: return dike
	if absf(x - VX) < 175.0 and absf(z - VZ) < 72.0: return dike.lerp(Color(0.4, 0.52, 0.27), n)   # the village and its gardens
	# polder fields in parcels
	var px := int(floor((x + 30 * sin(z * 0.004)) / 72.0))
	var pz := int(floor(z / 96.0))
	var fields := [Color(0.42, 0.56, 0.27), Color(0.47, 0.6, 0.3), Color(0.76, 0.68, 0.37), Color(0.33, 0.47, 0.24), Color(0.46, 0.37, 0.27), Color(0.58, 0.6, 0.31), Color(0.4, 0.53, 0.26)]
	var f: Color = fields[int(hash2(px, pz) * fields.size()) % fields.size()]
	return f.lerp(f.darkened(0.12), n * 0.6)

## the whole ground: one grid with the coastline in it, drawn in pieces of 576 m; cells that lie deep under water are left out
static func ground() -> void:
	var NS := Trk.NS
	var P := Trk.P
	var EMB := Trk.EMB
	var SH := Trk.SHOULDER
	var W := GNX + 1
	nearD = PackedFloat32Array()
	nearD.resize(W * (GNZ + 1))
	nearD.fill(1e9)
	for i in range(0, NS, 2):
		var p := P[i]
		var reach: float = SH + EMB[i] + 30.0
		var ix0 := clampi(int(floor((p.x - reach - GX0) / GC)), 0, GNX)
		var ix1 := clampi(int(ceil((p.x + reach - GX0) / GC)), 0, GNX)
		var iz0 := clampi(int(floor((p.z - reach - GZ0) / GC)), 0, GNZ)
		var iz1 := clampi(int(ceil((p.z + reach - GZ0) / GC)), 0, GNZ)
		for iz in range(iz0, iz1 + 1):
			for ix in range(ix0, ix1 + 1):
				var d := hyp(GX0 + ix * GC - p.x, GZ0 + iz * GC - p.z) - EMB[i]
				var k := iz * W + ix
				if d < nearD[k]: nearD[k] = d
	var pos := PackedVector3Array(); pos.resize(W * (GNZ + 1))
	var cols := PackedColorArray(); cols.resize(pos.size())
	for iz in GNZ + 1:
		for ix in W:
			var x := GX0 + ix * GC
			var z := GZ0 + iz * GC
			var k := iz * W + ix
			var nd: float = nearD[k]
			var iL := islandL(x, z)
			var L := landV(x, z, nd)
			pos[k] = Vector3(x, heightOf(L), z)
			cols[k] = groundCol(x, z, L, iL, nd)
	var mat := M(0xffffff, {"vertexColors": true, "map": BKit.noiseTex(128, 1600, 0.16, 0.1), "receiveShadow": true})
	var CH := 48
	for cz in range(0, GNZ, CH):
		for cx in range(0, GNX, CH):
			var g := Geo.new()
			var nx := mini(CH, GNX - cx)
			var nz := mini(CH, GNZ - cz)
			for iz in nz + 1:
				for ix in nx + 1:
					var k := gidx(cx + ix, cz + iz)
					g.pos.append(pos[k]); g.col.append(cols[k])
					g.nrm.append(Vector3.UP)
					g.uv.append(Vector2(pos[k].x / 14.0, pos[k].z / 14.0))
			for iz in nz:
				for ix in nx:
					var a := gidx(cx + ix, cz + iz)
					var top := maxf(maxf(pos[a].y, pos[a + 1].y), maxf(pos[a + W].y, pos[a + W + 1].y))
					if top < -1.7: continue
					var A := iz * (nx + 1) + ix
					var B := A + nx + 1
					g.idx.append_array([A, B, A + 1, A + 1, B, B + 1])
			if g.idx.is_empty(): continue
			# the beach slopes: give those parts a real normal
			for iz in nz + 1:
				for ix in nx + 1:
					var k := gidx(cx + ix, cz + iz)
					var hx: float = pos[mini(k + 1, pos.size() - 1)].y - pos[maxi(k - 1, 0)].y
					var hz: float = pos[mini(k + W, pos.size() - 1)].y - pos[maxi(k - W, 0)].y
					g.nrm[iz * (nx + 1) + ix] = Vector3(-hx / (2 * GC), 1.0, -hz / (2 * GC)).normalized()
			var mi := O3.mesh(g, mat)
			O3.receive(mi)
			World.add(mi)

static func build() -> void:
	var NS := Trk.NS
	var P := Trk.P
	var EMB := Trk.EMB
	var RH := Trk.ROAD_HALF
	var SH := Trk.SHOULDER
	TrackCommon.waterPlane(7000, 7000, 700, 150, -0.35, 0x3f6a86)
	ground()
	var grassTex := BKit.noiseTex(64, 500, 0.14, 0.08)
	var grass := M(0x748e4e, {"map": grassTex})
	var dgrass := M(0x6a8446, {"map": grassTex})
	var stone := M(0x6a6660, {"map": BKit.noiseTex(64, 700, 0.22, 0.08)})
	World.ribbon(-RH, RH, World.roadMat(World.roadTexture("#5b5d60", [1.0 / 3, 2.0 / 3], true, false, 0.25)), 12, 0.07)
	World.ribbon(-SH, -RH, grass, 10, 0.05)
	World.ribbon(RH, SH, grass, 10, 0.05)
	# the dike: grass on top; over the water its lower half is a stone revetment (basalt)
	var wet := []
	wet.resize(NS)
	for i in NS:
		wet[i] = islandL(P[i].x, P[i].z) < -4.0
	var mid := func(i: int) -> float: return SH + EMB[i] * (0.5 if wet[i] else 1.0)
	World.ribbon(func(i): return -mid.call(i), -SH, dgrass, 6, 0.05)
	World.ribbon(SH, mid, dgrass, 6, 0.05)
	var wetF := func(i: int) -> bool: return wet[i]
	World.ribbon(func(i): return -(SH + EMB[i]), func(i): return -mid.call(i), stone, 6, 0.05, wetF)
	World.ribbon(mid, func(i): return SH + EMB[i], stone, 6, 0.05, wetF)
	var rt := Canvas2D.tex(64, 32, func(g, w, h):
		g.fillStyle = "#b9bec3"; g.fillRect(0, 0, w, h); g.fillStyle = "#8d9398"; g.fillRect(0, 10, w, 3); g.fillRect(0, 20, w, 3), true)
	World.vribbon(-9.1, 0.15, 0.9, M(0xffffff, {"map": rt}), 4)
	World.vribbon(9.1, 0.15, 0.9, M(0xffffff, {"map": rt}), 4)
	World.startLine()
	World.gates(Trk.TRK)
	barrier()
	deco = BKit.Acc.new(M(0xffffff, {"vertexColors": true, "map": BKit.noiseTex(64, 600, 0.12, 0.08)}))
	duneField()
	beach()
	deco.commit()
	lighthouse()
	village()
	turbines()
	boats()
	BKit.chevrons(10.0, 0.016, 9.0, 1.2, false)
	fans()
	TrackCommon.signs([["Neeltje Jans", "2"], ["Zierikzee", "12"], ["Middelburg", "24"]], 10.2)
	TrackCommon.lampRow(8.9, 90, 10, {})

## Oosterscheldekering: one continuous barrier on its own gently curved line (a Bezier in world coordinates, so the same in both
## driving directions) on the sea side of the dam. Piers stand at one fixed spacing; the road girder, the upper beam and the gates
## run from pier centre to pier centre, so every joint lies inside a pier (the piers are wider and higher than what they carry).
## A landhoofd closes both ends. Piers stay 4 m off the toe of the dike; should the track ever come closer, the line moves out to sea.
static func barrier() -> void:
	var NS := Trk.NS
	var P := Trk.P
	var R := Trk.R
	var EMB := Trk.EMB
	var SH := Trk.SHOULDER
	var con := M(0x9c9c96)
	var dark := M(0x2f3336)
	var stone := M(0x6d6a64)
	var pm := []; var sp := []; var gm := []; var hm := []; var lm := []
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
		# a lamp on every pier (it sits half in the upper beam)
		lm.append(World.mtx(x, 27.9, z, ry, 0.5, 0.4, 0.5))
		if k == 0: continue
		var x0: float = Q[k - 1][0]
		var z0: float = Q[k - 1][1]
		var l := hyp(x - x0, z - z0)
		var r := hd(Q[k - 1], Q[k])
		var mx := (x + x0) / 2
		var mz := (z + z0) / 2
		sp.append(World.mtx(mx, 23.2, mz, r, 10, 2.4, l))
		sp.append(World.mtx(mx, 18, mz, r, 4, 3, l))
		# the gate hangs just under the lower beam and ends inside the piers (no face shares a plane with the beam)
		gm.append(World.mtx(mx, 11.7, mz, r, 1, 9.4, l - 1.0))
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
	var lamp := M(0x333a40, {"emissive": 0x222222})
	World.lampMats.append(lamp)
	World.inst(Geo.box(1, 1, 1), lamp, lm, null, false)

## dunes behind the beach, long and low along the coast, with marram grass on and around them. A whole dune stays 4 m
## clear of the dike toe; tufts sit on the dune's surface. Dunes, grass and everything on the beach go into one
## vertex-coloured mesh per 300 m cell (deco), so the whole coast costs a draw call per cell.
static var deco: BKit.Acc
static func duneField() -> void:
	var SH := Trk.SHOULDER
	var sp := BKit.Spacing.new(9.0)
	var dg := Geo.sphere(1, 9, 4, 0, TAU, 0, PI / 2)
	var tuft := Geo.cone(0.6, 1.4, 3, 1, true)
	var grass := Color(0.56, 0.6, 0.3)
	for _k in 420:
		var x := 100 + rnd() * 1620
		var z := 400 + rnd() * 130
		var sx := 9 + rnd() * 14
		var sy := 2.5 + rnd() * 4.5
		var sz := 6 + rnd() * 6
		var ry := (rnd() - 0.5) * 0.6
		var L := islandL(x, z)
		if L < 38 or not dunes(x, z): continue
		if Trk.distToTrack(x, z) - maxf(sx, sz) < SH + 4: continue
		if not sp.free_at(x, z): continue
		var cy := -sy * 0.3
		# sand at the foot, marram green-grey towards the top
		var sand := Color(0.84, 0.76, 0.57).lerp(Color(0.76, 0.69, 0.5), rnd())
		var g := dg.clone()
		g.col.resize(g.pos.size())
		for k in g.pos.size():
			var w := smoothstep(0.45, 0.95, g.pos[k].y) * (0.55 + 0.45 * sin(g.pos[k].x * 5.0 + g.pos[k].z * 3.0 + x))
			g.col[k] = sand.lerp(Color(0.6, 0.64, 0.42), clampf(w, 0, 1))
		deco.at(x, cy, z, ry)
		deco.add(g.scale(sx, sy, sz), Color.WHITE)
		for _q in 7:
			var u := (rnd() - 0.5) * 1.5
			var v := (rnd() - 0.5) * 1.5
			if u * u + v * v > 0.6: continue
			var gy := sy * sqrt(1.0 - u * u - v * v)
			var ts := 0.7 + rnd() * 0.5
			deco.add(tuft, grass, Transform3D(Basis(Vector3.UP, rnd() * 6).scaled_local(Vector3(0.5 + rnd() * 0.3, ts, 0.5 + rnd() * 0.3)), Vector3(u * sx, gy + 0.7 * ts - 0.15, v * sz)))
	# loose tufts on the flat sand between the dunes
	for _k in 600:
		var x := 100 + rnd() * 1620
		var z := 400 + rnd() * 130
		var L := islandL(x, z)
		if L < 22 or not dunes(x, z) or Trk.distToTrack(x, z) < SH + 3: continue
		var ts := 0.6 + rnd() * 0.5
		deco.at(x, 0, z, rnd() * 6)
		deco.add(tuft, grass, Transform3D(Basis.from_scale(Vector3(0.45 + rnd() * 0.3, ts, 0.45 + rnd() * 0.3)), Vector3(0, 0.7 * ts - 0.1, 0)))

## the beach on the North Sea: groynes of wooden poles, pavilions on piles, beach huts, wind breaks, parasols, people,
## kites and the surf
static func beach() -> void:
	var SH := Trk.SHOULDER
	var cz := {}
	var x := 80.0
	while x <= 1760.0:
		cz[int(x)] = coastZ(x)
		x += 4.0
	var coast := func(px: float) -> float: return cz.get(int(clampf(floorf(px / 4.0) * 4.0, 80, 1760)), 520.0)
	var clear := func(px: float, pz: float, r: float) -> bool: return Trk.distToTrack(px, pz) - r >= SH + 6
	var A := deco
	# groynes (paalhoofden): rows of oak poles from the dune foot out into the sea, lower towards the sea
	var pole := Geo.cylinder(0.15, 0.17, 1.0, 5, 1, true)
	x = 150.0
	while x < 1720.0:
		var c: float = coast.call(x)
		var z := c - 14.0
		var k := 0
		A.at(x, 0, c)
		while z < c + 34.0:
			var hgt := lerpf(1.7, 0.5, clampf((z - c + 14.0) / 48.0, 0, 1)) + rnd() * 0.25
			A.add(pole, 0x4a3a2c, Transform3D(Basis.from_scale(Vector3(1, 2.6 + hgt, 1)), Vector3((k % 2) * 0.32, (-2.6 + hgt) / 2.0, z - c)))
			z += 1.05
			k += 1
		x += 160.0 + rnd() * 30
	# pavilions on piles
	var win := BKit.Acc.new(BKit.vmat({"emissive": 0x000000}), false)
	World.winMats.append(win.mat)
	var parasol := BKit.merge([[Geo.cylinder(0.04, 0.04, 2.3, 5).translate(0, 1.15, 0), 0xe0e0e0], [Geo.cone(1.25, 0.5, 8, 1, true).translate(0, 2.25, 0), 0xffffff]])
	var pcols := [0xffffff, 0xc8302a, 0x21468b, 0xf2c200, 0x2f8f5b, 0xf36f21]
	var pavX := []
	for px in [240.0, 640.0, 1010.0, 1480.0]:
		var c: float = coast.call(px)
		var pz := c - 20.0
		if not clear.call(px, pz, 14.0): continue
		pavX.append(px)
		A.at(px, 0, pz, PI)       # the terrace faces the sea (north): local -z is north after turning
		for a in [-8.0, -2.7, 2.7, 8.0]:
			for b in [-5.0, 0.0, 5.0]:
				A.box(0.3, 2.2, 0.3, a, 0.6, b, 0x5a4a3a)
		A.box(18, 0.3, 12, 0, 1.75, 0, 0x8a6a48)                 # deck
		A.box(12, 3.4, 7, 0, 3.58, 2.2, 0xd8c8a8)                 # the building (back half of the deck)
		A.box(13.4, 0.35, 8.4, 0, 5.45, 2.2, 0xf2f2ee)           # flat roof with overhang
		A.box(2.2, 0.15, 1.2, 0, 1.92, -6.4, 0x8a6a48)            # step to the beach
		for e in [-1.0, 1.0]:
			A.box(0.08, 0.9, 12, e * 8.95, 2.33, 0, 0xf2f2ee)    # railing
		A.box(18, 0.86, 0.08, 0, 2.31, -5.95, 0xf2f2ee)
		A.box(0.12, 9, 0.12, 7.5, 6.3, 4.5, 0xe8e4dc)            # flag pole
		A.box(1.6, 1.0, 0.05, 8.3, 10.2, 4.5, 0x21468b)
		for a in [-6.0, -2.0, 2.0, 6.0]:
			A.add(parasol, World.pick(pcols), BKit.xf(a, 1.85, -3.2))
		win.at(px, 0, pz, PI)
		win.box(10.4, 1.7, 0.1, 0, 3.9, -1.33, 0x2e3c48)        # glass front towards the terrace
	win.commit()
	# beach huts in rows beside the pavilions, parasols and wind breaks on the sand
	var ppl := []
	var hcols := [0x1d4f9e, 0xc8302a, 0xf2c200, 0x2f8f5b, 0xecece8, 0xf36f21, 0x6fb3d8]
	var hroof := TrackCommon.roofGeo()
	for px in pavX:
		for side in [-1.0, 1.0]:
			for k in 9:
				var hx: float = px + side * (16 + k * 3.6)
				var c: float = coast.call(hx)
				var hz := c - 27.0
				if not clear.call(hx, hz, 3.0) or islandL(hx, hz) < 8: continue
				A.at(hx, 0, hz)
				A.box(3.0, 2.2, 3.2, 0, 1.05, 0, World.pick(hcols))
				A.box(1.0, 1.7, 0.06, 0, 0.9, -1.61, 0xf4f4f0)        # the door (on the sea side)
				A.add(hroof, 0xecece8, Transform3D(Basis.from_scale(Vector3(3.3, 1.1, 3.5)), Vector3(0, 2.17, 0)))
	for _k in 70:
		var bx := 140 + rnd() * 1560
		var c: float = coast.call(bx)
		var bz := c - 6 - rnd() * 16
		if not clear.call(bx, bz, 3.0) or islandL(bx, bz) < 4: continue
		var r := rnd()
		if r < 0.4:
			A.at(bx, -0.05, bz)
			A.add(parasol, World.pick(pcols))
		elif r < 0.7:
			# a wind break: three cloths in a U
			var ry := rnd() * TAU
			var cc: int = World.pick(pcols)
			A.at(bx, 0, bz, ry)
			for q in 3:
				var a := (q - 1) * PI / 2
				A.box(2.6, 1.1, 0.04, sin(a) * 1.3, 0.5, cos(a) * 1.3, cc, a + PI / 2)
		else:
			ppl.append([bx, 0.0, bz, rnd() * TAU])
			if rnd() < 0.5: ppl.append([bx + 0.9, 0.0, bz + 0.4, rnd() * TAU])
	# kites over the beach: each turns slowly round the hand of the person flying it
	var kc := [[0xc8302a, 0xf2c200], [0x21468b, 0xecece8], [0x2f8f5b, 0xf36f21], [0x8a4fa0, 0xf2c200], [0xf36f21, 0x21468b], [0xc8302a, 0x21468b]]
	var km := BKit.vmat()
	for k in 6:
		var kx := 200.0 + k * 250 + rnd() * 80
		var c: float = coast.call(kx)
		var kz := c - 10 - rnd() * 8
		if not clear.call(kx, kz, 26.0): continue
		ppl.append([kx, 0.0, kz, PI])
		var g := O3.group(kx, 1.4, kz)
		O3.rot(g, 0, rnd() * TAU, 0)
		var hgt := 20.0 + rnd() * 8
		var out := 14.0 + rnd() * 5
		var cs: Array = kc[k]
		var diamond := [Vector2(0, 1.1), Vector2(0.8, 0), Vector2(0, -1.4), Vector2(-0.8, 0)]
		var half := [Vector2(0, 1.1), Vector2(0.8, 0), Vector2(0, -1.4)]
		var tilt := Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, hgt, out))
		var L := hyp(hgt, out)
		var kite := Geo.new()
		BKit._append(kite, Geo.extrude(diamond, 0.04), BKit.col(cs[0]), tilt)
		BKit._append(kite, Geo.extrude(half, 0.04).translate(0, 0, 0.03), BKit.col(cs[1]), tilt)
		BKit._append(kite, Geo.box(0.06, 3.2, 0.03).translate(0, -3.0, 0), BKit.col(cs[1]), tilt)
		BKit._append(kite, Geo.box(0.03, L, 0.03), Color(0.9, 0.89, 0.86), Transform3D(Basis(Vector3.RIGHT, atan2(out, hgt)), Vector3(0, hgt / 2.0, out / 2.0)))
		O3.mesh(kite, km, 0, 0, 0, g)
		World.add(AnimB.sway(g, 14.0, 9.0 + rnd() * 4, 0.0, rnd() * 9))
	BKit.crowd(ppl)
	# surf: three foam bands along the waterline that roll up the beach and back (they slide under the sand)
	var foam := M(0xffffff, {"map": foamTex(), "transparent": true, "depthWrite": false, "opacity": 0.8})
	var g := Geo.new()
	for b in 3:
		var px := 60.0
		var n := 0
		var o := g.pos.size()
		while px <= 1780.0:
			var c: float = coast.call(px) + 2.0 + b * 5.0 + 1.5 * sin(px * 0.05 + b)
			g.pos.append(Vector3(px, -0.32 + b * 0.005, c - 1.6)); g.pos.append(Vector3(px, -0.32 + b * 0.005, c + 1.6))
			g.uv.append(Vector2(px / 24.0 + b * 0.37, 0)); g.uv.append(Vector2(px / 24.0 + b * 0.37, 1))
			g.nrm.append(Vector3.UP); g.nrm.append(Vector3.UP)
			if n > 0:
				var a := o + (n - 1) * 2
				g.idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
			n += 1
			px += 8.0
	World.add(AnimB.bob(O3.mesh(g, foam), Vector3(0, 0, -3.5), 7.5))

static func foamTex() -> ImageTexture:
	return Canvas2D.tex(128, 32, func(g, w, h):
		g.clearRect(0, 0, w, h)
		for _i in 160:
			var x: float = randf() * w
			var y: float = h * 0.5 + (randf() - 0.5) * h * 0.6
			g.fillStyle = "rgba(255,255,255,%f)" % (0.25 + randf() * 0.5)
			g.beginPath(); g.ellipse(x, y, 3 + randf() * 9, 1 + randf() * 2.5, 0, 0, TAU); g.fill(), true)

## the lighthouse on Walcheren: a tapering tower in red and white bands, a gallery with a railing, the lamp room and a dome;
## at dusk and night two beams turn round
static func lighthouse() -> void:
	var lx := -120.0
	var lz := 150.0
	# keep the whole tower clear of the dike of the road (it curves round it on the east side)
	for _k in 60:
		if Trk.distToTrack(lx, lz) >= Trk.SHOULDER + 8: break
		lx -= 1.0
	var A := BKit.Acc.new()
	A.at(lx, 0, lz)
	var r0 := 2.7
	for k in 6:
		var rb := r0 - k * 0.17
		var rt := rb - 0.17
		A.add(Geo.cylinder(rt, rb, 5.0, 16, 1, true), 0xecece8 if k % 2 else 0xc8302a, BKit.xf(0, 2.5 + k * 5, 0))
	A.cyl(3.4, 3.4, 0.5, 16, 0, 30.15, 0, 0x2b2f36)          # gallery floor (the tower top lies inside it)
	A.box(1.2, 2.2, 0.3, 0, 1.1, -2.62, 0x3a2e24)              # door
	for k in 12:
		var a := k * TAU / 12.0
		A.box(0.06, 1.0, 0.06, sin(a) * 3.25, 30.85, cos(a) * 3.25, 0x2b2f36)
	A.add(Geo.cylinder(3.28, 3.28, 0.12, 16, 1, true), 0x2b2f36, BKit.xf(0, 31.35, 0))   # the rail (a band)
	A.cyl(1.9, 1.9, 0.6, 12, 0, 30.6, 0, 0x2b2f36)            # base of the lamp room
	A.cyl(0.2, 1.95, 1.4, 12, 0, 33.75, 0, 0xc8302a)          # dome
	A.cyl(0.25, 0.25, 0.7, 6, 0, 34.7, 0, 0x2b2f36)
	A.commit()
	var lamp := M(0xfff2c0, {"emissive": 0x807040})
	World.lampMats.append(lamp)
	World.add(O3.mesh(Geo.cylinder(1.7, 1.7, 2.3, 12), lamp, lx, 32.0, lz))
	# the beams: two long see-through cones from the lamp, turning (they only show when the lamps are on)
	var beam := M(0x000000, {"transparent": true, "opacity": 0.1, "blending": "add", "depthWrite": false, "emissive": 0x000000, "side": "double"})
	World.lampMats.append(beam)
	var bg := Geo.cone(6.0, 130.0, 10, 1, true).translate(0, -65.0, 0).rotate_z(PI / 2)
	var two := BKit.merge([[bg, 0xffffff], [bg.clone().rotate_y(PI), 0xffffff]])
	var holder := O3.group(lx, 32.0, lz)
	O3.rot(holder, -PI / 2, 0, 0)     # its z axis points up: spin turns it round the vertical
	O3.mesh(two, beam, 0, 0, 0, holder)
	World.add(AnimB.spin(holder, 0.9))

## a small Zeeland village on the long island, between its south shore and the road: two streets of brick houses with
## gable roofs round a church with a tall tower, trees round it; windows light up at night
static func village() -> void:
	var SH := Trk.SHOULDER
	var lots := BKit.Lots.new()
	var houses := []; var hcol := []; var roofs := []; var rcol := []
	var cx := VX
	var cz := VZ
	# the church first
	if Trk.distToTrack(cx, cz) - 30 < SH + 10: return
	lots.take(cx, cz, 0.0, 9, 20, 2, 2)
	var C := BKit.Acc.new()
	C.at(cx, 0, cz)
	C.box(14, 11, 28, 0, 5.5 - 0.5, 4, 0x8a4a36)
	C.roof(14.8, 8, 28.8, 0, 10.0, 4, 0x4a4440)
	C.box(8, 30, 8, 0, 14.5, -13.5, 0x7e4232)
	C.box(8.4, 0.6, 8.4, 0, 29.6, -13.5, 0xd8d0c0)
	C.spire(7.2, 14, 7.2, 0, 29.85, -13.5, 0x3a4a52)
	C.box(1.6, 3, 0.2, 0, 1.3, -17.58, 0x3a2e24)
	C.commit()
	# clock faces on three sides of the tower (5 cm out), lit at night
	var clock := Acc1(BKit.vmat({"emissive": 0x000000}))
	World.winMats.append(clock.mat)
	clock.at(cx, 0, cz)
	for e in [[0.0, -17.55, PI], [4.05, -13.5, PI / 2], [-4.05, -13.5, -PI / 2]]:
		clock.add(Geo.circle(1.3, 16), 0xffffff, BKit.xf(e[0], 22.0, e[1], e[2]))
	clock.commit()
	# streets along x on both sides of the church square, with houses on both sides of each street
	var bricks := [Color(0.62, 0.32, 0.24), Color(0.7, 0.4, 0.3), Color(0.55, 0.3, 0.25), Color(0.86, 0.84, 0.78), Color(0.74, 0.62, 0.5)]
	var rc := [Color(0.42, 0.22, 0.17), Color(0.3, 0.3, 0.32), Color(0.5, 0.26, 0.18)]
	for street in [-1.0, 1.0]:
		for row in [-1.0, 1.0]:
			var hx := cx - 150.0
			while hx < cx + 150.0:
				var w := 6.0 + rnd() * 3
				var d := 9.0 + rnd() * 3
				var h := 5.0 + rnd() * 2.5
				var hz: float = cz + street * 34.0 + row * (5.5 + d / 2)
				var x := hx + w / 2
				hx += w + (0.25 if rnd() < 0.7 else 3.0 + rnd() * 6)
				if Trk.distToTrack(x, hz) - d < SH + 10 or islandL(x, hz) < 20: continue
				if not lots.take(x, hz, 0.0, w / 2, d / 2, 0.1, 0.4): continue
				houses.append(BKit.houseXf(x, 0.0, hz, 0.0, w, h, d, 0.5)); hcol.append(World.pick(bricks))
				# ridge along the street: the roof's local z runs along x
				# (eaves 0.35 m over the street and the garden, 5 cm over the gables: neighbouring roofs do not cross)
				roofs.append(Transform3D(Basis(Vector3.UP, PI / 2).scaled_local(Vector3(d + 0.7, 3.0 + rnd() * 1.5, w + 0.1)), Vector3(x, h - 0.03, hz))); rcol.append(World.pick(rc))
	var hm := M(0xffffff, {"map": houseTex(false), "emissive": 0x000000, "emissiveMap": houseTex(true)})
	World.winMats.append(hm)
	World.inst(Geo.box(1, 1, 1), hm, houses, hcol, true)
	World.inst(TrackCommon.roofGeo(), M(0xffffff), roofs, rcol, true)
	# trees round the village and along the streets
	var tr := []; var tc := []
	var spc := BKit.Spacing.new(6.0)
	for _k in 90:
		var a := rnd() * TAU
		var r := 60 + rnd() * 120
		var x := cx + cos(a) * r * 1.4
		var z := cz + sin(a) * r * 0.5
		if Trk.distToTrack(x, z) < SH + 12 or islandL(x, z) < 12: continue
		if not lots.take(x, z, 0.0, 3.5, 3.5, 0, 0) or not spc.free_at(x, z): continue
		var s := 0.8 + rnd() * 0.5
		tr.append(World.mtx(x, 0, z, rnd() * 6, s)); tc.append(Color(1, 1, 1).darkened(rnd() * 0.2))
	World.inst(BKit.oakGeo(), BKit.vmat(), tr, tc, true)
	# sheep on the meadows round it
	var sh := []
	for _k in 50:
		var x := 300 + rnd() * 1000
		var z := 200 + rnd() * 110
		if Trk.distToTrack(x, z) < SH + 8 or islandL(x, z) < 15 or not lots.take(x, z, 0.0, 1.0, 1.0, 0, 0): continue
		for q in 3:
			var sx := x + (rnd() - 0.5) * 8
			var sz := z + (rnd() - 0.5) * 8
			if lots.take(sx, sz, 0.0, 0.7, 0.9, 0, 0): sh.append(World.mtx(sx, 0, sz, rnd() * 6))
	World.inst(BKit.sheepGeo(), BKit.vmat(), sh, null, false)

static func Acc1(m: LMat) -> BKit.Acc:
	return BKit.Acc.new(m, false)

static func houseTex(lit: bool) -> ImageTexture:
	return Canvas2D.tex(128, 128, func(g, w, h):
		g.fillStyle = "#000" if lit else "#ffffff"; g.fillRect(0, 0, w, h)
		for f in 2:
			for c in 3:
				var x := 14 + c * 40
				var y := 18 + f * 56
				if lit:
					if randf() < 0.55:
						g.fillStyle = "rgba(255,%d,120,%f)" % [190 + randi() % 50, 0.5 + randf() * 0.5]; g.fillRect(x, y, 22, 30)
				else:
					g.fillStyle = "#f2efe6"; g.fillRect(x - 3, y - 3, 28, 36)
					g.fillStyle = "#26323c"; g.fillRect(x, y, 22, 30)
					g.fillStyle = "#f2efe6"; g.fillRect(x + 10, y, 2, 30); g.fillRect(x, y + 14, 22, 2)
		if not lit:
			g.fillStyle = "#2f5a3a"; g.fillRect(56, 92, 18, 36))

## wind turbines: a farm far out at sea and a row along the inner shore of the long island. The farm is one mesh (its
## rotors stand still, it is far away); the rotors of the row by the road turn.
static func turbines() -> void:
	var blade := BKit.merge([
		[Geo.sphere(1.6, 8, 6).scale(1, 1, 1.4), 0xf2f2f0],
		[Geo.box(1.0, 36, 0.35).translate(0, 19, 0), 0xf2f2f0],
		[Geo.box(1.0, 36, 0.35).translate(0, 19, 0).rotate_z(TAU / 3), 0xf2f2f0],
		[Geo.box(1.0, 36, 0.35).translate(0, 19, 0).rotate_z(2 * TAU / 3), 0xf2f2f0]])
	var mast := BKit.merge([[Geo.cylinder(1.5, 2.6, 84, 10).translate(0, 42, 0), 0xeeeeec], [Geo.cylinder(3.4, 3.4, 4, 10).translate(0, 2, 0), 0xe8c21c],
		[Geo.box(3.2, 3.4, 10).translate(0, 84, 0.6), 0xeeeeec]])
	var beacon := M(0x601010, {"emissive": 0x220000})
	World.beaconMats.append(beacon)
	var bm := []
	var ry := 0.6      # the rotors face the south-west wind
	var rm := BKit.vmat()
	# (mast: tower from 2 m under the water or the ground up to the nacelle at 80.3..83.7 m; the hub 5.6 m in front of it)
	var farm := BKit.Acc.new(BKit.vmat(), false)
	var fx := 820.0
	var fz := 1160.0
	farm.at(fx, 0, fz)
	for a in 4:
		for b in 3:
			var x := 260.0 + a * 330 + b * 110
			var z := 900.0 + b * 260
			var t := Transform3D(Basis(Vector3.UP, ry), Vector3(x - fx, -2.0, z - fz))
			farm.add(mast, Color.WHITE, t)
			farm.add(blade, Color.WHITE, t * Transform3D(Basis(Vector3.BACK, (a * 3 + b) * 0.7), Vector3(0, 84.0, 5.6)))
			bm.append(World.mtx(x, 83.8, z, ry, 0.6))
	farm.commit()
	var row := []
	for k in 5:
		var x := 380.0 + k * 190
		var z := 150.0 + 10 * sin(k * 1.7)
		if Trk.distToTrack(x, z) < 60 or islandL(x, z) > 2: continue
		row.append(World.mtx(x, -2.0, z, ry))
		bm.append(World.mtx(x, 83.8, z, ry, 0.6))
		var rotor := O3.group(x, 82.0, z)
		O3.rot(rotor, 0, ry, 0)
		rotor.position += Basis(Vector3.UP, ry) * Vector3(0, 0, 5.6)
		O3.mesh(blade, rm, 0, 0, 0, rotor, false)
		World.add(AnimB.spin(rotor, 0.7 + rnd() * 0.2, rnd() * 10))
	World.inst(mast, BKit.vmat(), row, null, false)
	World.inst(Geo.box(1, 1, 1), beacon, bm, null, false)

## boats: fishing cutters with their booms up off the barrier, sailing boats on the Oosterschelde and a container ship
## far out on the North Sea; a few of them sail
static func boats() -> void:
	var F := BKit.Acc.new()
	var lights := []
	for k in 5:
		var x := 300 + k * 230.0
		var z := -230 - rnd() * 110
		var ry := rnd() * TAU
		var col := 0x1d4f9e if k % 2 else 0x2e5d3e
		if k == 2:
			var g := Node3D.new()
			var A := BKit.Acc.new()
			cutter(A, col)
			A.commit()
			# Acc meshes went to World.root: hang them under the boat
			for c in World.root.get_children().slice(-1):
				World.root.remove_child(c); g.add_child(c)
			World.add(AnimB.shuttle(g, Vector3(x - 200, -0.35, z - 60), Vector3(x + 260, -0.35, z - 140), 4.5, rnd()))
			continue
		F.at(x, -0.35, z, ry)
		cutter(F, col)
		lights.append(BKit.xf(x, -0.35, z, ry) * Transform3D(Basis.IDENTITY, Vector3(0, 10.45, -2.5)))
	F.commit()
	# sailing yachts on the Oosterschelde
	var S := BKit.Acc.new()
	var sails := [0xffffff, 0xffffff, 0xf2e8d0, 0xc8302a, 0xffffff, 0x21468b]
	for k in 7:
		var mover := k < 2
		var x := (480 + rnd() * 540) if mover else (340 + rnd() * 820)
		var z := 40 + rnd() * 70
		var ry := (PI / 2 + (rnd() - 0.5) * 0.3) if mover else rnd() * TAU
		if Trk.distToTrack(x, z) < 30 or islandL(x, z) > -6: continue
		if mover:
			var A := BKit.Acc.new()
			yacht(A, sails[k % sails.size()])
			A.commit()
			var g := Node3D.new()
			for c in World.root.get_children().slice(-1):
				World.root.remove_child(c); g.add_child(c)
			var d := Vector3(sin(ry), 0, cos(ry)) * 120
			World.add(AnimB.shuttle(g, Vector3(x, -0.35, z) - d, Vector3(x, -0.35, z) + d, 3.0, rnd()))
		else:
			S.at(x, -0.35, z, ry)
			yacht(S, sails[k % sails.size()])
	S.commit()
	# a container ship on the horizon, sailing along the coast
	var g := Node3D.new()
	var C := BKit.Acc.new()
	C.box(170, 10, 26, 0, 3.5, 0, 0x23364a); C.box(170.2, 1.4, 26.2, 0, 0.0, 0, 0x8a2a22)
	C.box(14, 18, 24, -70, 17, 0, 0xe8e4dc); C.box(6, 6, 6, -72, 28, 0, 0xc8302a)
	var cols := [0xc8302a, 0x1d4f9e, 0x2f8f5b, 0xf36f21, 0x8a8f96, 0xe8c21c]
	for a in 10:
		for b in 3:
			var hq := 1 + (a * 5 + b * 3) % 4
			for q in hq:
				C.box(12.2, 2.6, 7.4, -52 + a * 12.6, 9.8 + q * 2.6, (b - 1) * 7.8, cols[(a + b * 2 + q) % cols.size()])
	C.commit()
	for c in World.root.get_children().slice(-1):
		World.root.remove_child(c); g.add_child(c)
	O3.rot(g, 0, -PI / 2, 0)
	World.add(AnimB.shuttle(g, Vector3(-900, -0.6, 1350), Vector3(2600, -0.6, 1450), 5.0, rnd()))
	var lm := M(0x333a40, {"emissive": 0x222222})
	World.lampMats.append(lm)
	World.inst(Geo.box(0.4, 0.4, 0.4), lm, lights, null, false)

## a fishing cutter in the current Acc frame (bow towards +z, the way AnimB.shuttle sails it): hull with a pointed bow,
## wheelhouse forward, mast aft with two booms up
static func cutter(A: BKit.Acc, col: int) -> void:
	var hull := Geo.extrude([Vector2(-2.6, 0), Vector2(2.6, 0), Vector2(2.6, 7), Vector2(0, 10.5), Vector2(-2.6, 7)], 2.4)
	hull.rotate_x(-PI / 2).rotate_y(PI).translate(0, -0.6, -5.25)
	A.add(hull, col)
	A.box(3.4, 2.6, 3.6, 0, 3.0, 0.5, 0xecece8)
	A.box(3.6, 0.3, 3.8, 0, 4.4, 0.5, 0x2b2f36)
	A.box(0.3, 9.0, 0.3, 0, 6.0, -2.5, 0x5a5f63)
	for s in [-1.0, 1.0]:
		A.box(8.0, 0.2, 0.2, s * 3.6, 6.6, -2.5, 0x5a5f63, 0, 0, s * 0.6)

## a sailing yacht in the current Acc frame: white hull, mast, a main sail and a jib
static func yacht(A: BKit.Acc, sail: int) -> void:
	var hull := Geo.extrude([Vector2(-1.3, 0), Vector2(1.3, 0), Vector2(1.3, 6), Vector2(0, 8.5), Vector2(-1.3, 6)], 1.3)
	hull.rotate_x(-PI / 2).rotate_y(PI).translate(0, -0.5, -4.25)
	A.add(hull, 0xf4f4f0)
	A.box(1.8, 0.6, 2.4, 0, 1.0, -0.8, 0xd8d0c0)
	A.box(0.14, 11, 0.14, 0, 6.2, 0.8, 0xc0c4c8)
	var main := Geo.extrude([Vector2(0, 0), Vector2(0, 9.6), Vector2(-4.2, 0)], 0.05)
	main.rotate_y(-PI / 2).translate(0, 1.1, 0.75)
	A.add(main, sail)
	var jib := Geo.extrude([Vector2(0, 0), Vector2(0, 8.6), Vector2(3.4, 0)], 0.05)
	jib.rotate_y(-PI / 2).translate(0, 1.1, 0.95)
	A.add(jib, 0xffffff)

## fans in the loop on the eastern island (the tightest bends near the ground) and at the start
static func fans() -> void:
	var ppl := []
	var bl := BKit.bends(0.012)
	bl.sort_custom(func(a, b): return a.kmax > b.kmax)
	var n := 0
	for b in bl:
		if n >= 3 or Trk.HT[b.apex] > 2.5: continue
		n += 1
		ppl.append_array(BKit.crowdRow(b.apex - 10, 18, -b.dir * (Trk.SHOULDER + Trk.EMB[b.apex] + 3.0), 1.2, 2))
	BKit.crowd(ppl)

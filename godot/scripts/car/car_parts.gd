class_name CarParts
## Body-kit parts for the looks (Aanpassen, part 2): spoilers, splitter, canards, side skirts, diffuser, wide arches, mud
## flaps, bonnet scoop and vents, roof rack / light bar / roof scoop, tow hooks, a big exhaust, and the wheel size, track
## and ride height. Every part is fitted to the model from its body (CarKit.anchors / CarBody queries), built once per
## model and part, and all parts a car wears go into two meshes (detail colours and body paint), cached per model and
## combination, so a car with a full kit costs two draw calls more. Nothing here touches the hitbox or the driving.
##
## Car space: +z forward, +x the car's left, metres, road at y = 0. Parts keep >= 2 cm off the skin (against flicker),
## stay above y = 0.075 and inside the hitbox's plan (test_looks checks every part on every model it fits).

## the look keys (and their values) built here; wing/exhaust values that CarKit's own tuning builds are left to it
const WINGS := ["lip", "rally", "swan"]
const EXHAUSTS := ["big"]
## wheel size: the rim radius is r * (0.7 + this) in the same tyre; track: wheels this much further out; ride: body up/down
const WSIZE := {"std": 0.0, "m": 0.04, "l": 0.08}
const TRACK := {"std": 0.0, "m": 0.02, "l": 0.04}
const RIDE := {"std": 0.0, "low": -0.025, "high": 0.03}

const C_TRIM := 0x15171a
const C_CARBON := 0x23272c

static func sc(hex: int, shine := 0.1) -> Color:
	return CarKit.sc(hex, shine)

# ------------------------------------------------------------------ on a car
## before the standard styling (CarLook.pre): the rim size has to be on the wheels when CarKit builds the rims
static func pre(m: Dictionary, L: Dictionary) -> void:
	var big: float = WSIZE.get(L.get("wsize", "std"), 0.0)
	for wh in m.get("wheels", []):
		if wh.style == "steel" or wh.style == "tractor": continue
		wh["big"] = big

## after the standard styling (CarLook.post): ride height, track, and the parts as two meshes
static func post(m: Dictionary, L: Dictionary) -> void:
	var K = m.get("kit", null)
	var shell: Node3D = m.get("shell", m.g)
	# ride height (the shell; the wheels stay on the road; lowered no further than 6.5 cm above the road) and track (the
	# wheel pivots, inside the hitbox)
	var ride: float = RIDE.get(L.get("ride", "std"), 0.0) if K != null else 0.0
	if ride < 0: ride = maxf(ride, minf(0.0, 0.065 - lowY(K, L)))
	shell.position.y = ride
	var tr: float = TRACK.get(L.get("track", "std"), 0.0)
	for wh in m.get("wheels", []):
		var pv: Node3D = wh.pivot
		if not wh.has("x0"): wh["x0"] = pv.position.x
		var x0: float = wh.x0
		var room: float = float(m.wid) / 2.0 - (absf(x0) + float(wh.w) / 2.0) - 0.005
		pv.position.x = x0 + signf(x0) * clampf(tr, 0.0, maxf(room, 0.0))
	if K == null: return
	_hood(m, K, L)
	var key := comboKey(L)
	if key == "": return
	var w: String = L.get("wing", "std")
	if w in WINGS and m.has("stockWing"):
		for o in m.stockWing: o.visible = false
	if L.get("exhaust", "std") in EXHAUSTS:
		var exm = m.g.get_meta("exh", null)
		if exm != null:
			for o in exm.meshes: o.visible = false
	var G := combo(K, L)
	if G[0] != null:
		CarKit.mesh(shell, G[0], CarKit.detailMat, true).set_meta("parts", true)
	if G[1] != null:
		CarKit.mesh(shell, G[1], m.paint, true).set_meta("parts", true)

## the lowest point of a model's body with the parts of a look
static func lowY(K: CarBody, L: Dictionary) -> float:
	if not K.has_meta("lowY"):
		var lo := INF
		for k in ["paint", "detail", "glass", "lamp", "tail", "plate", "exh", "wingT", "wingP"]:
			var g = K.G.get(k)
			if g is Geo:
				for p in g.pos: lo = minf(lo, p.y)
		K.set_meta("lowY", lo)
	var low: float = K.get_meta("lowY")
	if comboKey(L) != "":
		for g in combo(K, L):
			if g != null:
				for p in g.pos: low = minf(low, p.y)
	return low

## the parts of a look that are built here, as a key ("" = none)
static func comboKey(L: Dictionary) -> String:
	var parts := []
	for k in PART_KEYS:
		var v = L.get(k, "")
		if v is String and v != "" and v != "std" and v != "none":
			if k == "wing" and not v in WINGS: continue
			if k == "exhaust" and not v in EXHAUSTS: continue
			parts.append(k + "=" + v)
	return ",".join(parts)

const PART_KEYS := ["wing", "splitter", "canard", "skirt", "diffuser", "arch", "flap", "scoop", "roofx", "tow", "exhaust"]

## [detail Geo, paint Geo] of all parts of a look on a model (built once per model and combination)
static func combo(K: CarBody, L: Dictionary) -> Array:
	var key := comboKey(L)
	var c: Dictionary = K.get_meta("partCombos", {})
	if c.has(key): return c[key]
	var dm := CarKit.Mb.new()
	var pm := CarKit.Mb.new()
	for kv in key.split(","):
		var p := kv.split("=")
		var P := part(K, p[0], p[1])
		dm.acc(P.d)
		pm.acc(P.p, Color(1, 1, 1, 0))
	var out := [dm.build(), pm.build()]
	c[key] = out
	K.set_meta("partCombos", c)
	return out

## one part of a model: {d: CarAcc (detail colours, shine in alpha), p: CarAcc (body paint)}; built once
static func part(K: CarBody, k: String, v: String) -> Dictionary:
	var c: Dictionary = K.get_meta("parts", {})
	var key := k + "=" + v
	if c.has(key): return c[key]
	var d := CarAcc.new()
	var p := CarAcc.new()
	match k:
		"wing": _wing(K, d, p, v)
		"splitter": _splitter(K, d, v)
		"canard": _canards(K, d)
		"skirt": _skirts(K, d, p, v)
		"diffuser": _diffuser(K, d)
		"arch": _arches(K, d if v == "black" else p, v)
		"flap": _flaps(K, d, v)
		"scoop": _scoop(K, d, p, v)
		"roofx": _roof(K, d, p, v)
		"tow": _tow(K, d)
		"exhaust": _bigExhaust(K, d)
	var o := {"d": d if not d.P.is_empty() else null, "p": p if not p.P.is_empty() else null}
	c[key] = o
	K.set_meta("parts", c)
	return o

## does the part build anything on this model (tests; the catalogue's fit rules say where it is offered)
static func builds(type: String, k: String, v: String) -> bool:
	var P := part(CarKit.carKit(type), k, v)
	return P.d != null or P.p != null

# ------------------------------------------------------------------ helpers
## a quad a-b-c-d facing n
static func _quad(A: CarAcc, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	CarKit._face(A, a, b, c, null, null, null, n, n, n)
	CarKit._face(A, a, c, d, null, null, null, n, n, n)

## a closed slab between two outlines at heights y0 (bottom) and y1 (top): pts = [Vector2(x, z), ...] round the outline
static func _slab(A: CarAcc, pts: Array, y0: float, y1: float) -> void:
	var cen := Vector2.ZERO
	for q in pts: cen += q
	cen /= pts.size()
	var n := pts.size()
	for i in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % n]
		var top := [Vector3(cen.x, y1, cen.y), Vector3(a.x, y1, a.y), Vector3(b.x, y1, b.y)]
		CarKit._face(A, top[0], top[1], top[2], null, null, null, Vector3.UP, Vector3.UP, Vector3.UP)
		CarKit._face(A, Vector3(cen.x, y0, cen.y), Vector3(b.x, y0, b.y), Vector3(a.x, y0, a.y), null, null, null, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN)
		var e := b - a
		var sn := Vector3(e.y, 0, -e.x).normalized()
		if sn.dot(Vector3(a.x - cen.x, 0, a.y - cen.y)) < 0: sn = -sn
		_quad(A, Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y), sn)

## is the deck between x0..x1, z0..z1 a smooth, fairly flat surface (no fender humps, fins or ends of the skin)
static func _flatDeck(K: CarBody, x0: float, x1: float, z0: float, z1: float, ny := 0.6) -> bool:
	for i in 6:
		for j in 4:
			var x: float = lerpf(x0, x1, i / 5.0)
			var z: float = lerpf(z0, z1, j / 3.0)
			if absf(x) > K.shoulderX(z) - 0.01: return false
			var s = K.on_top(x, z)
			if s == null or s[1].y < ny: return false
	return true

## the deck height where a wing stands (roof for hatchbacks)
static func _deck(K: CarBody, troof: bool, z: float, x: float) -> float:
	return K.cabY(z, x) if troof else K.topY(z, x)

## how wide the roof is (half) at z: where it has dropped `drop` below the middle
static func _roofHalf(K: CarBody, z: float, drop := 0.05) -> float:
	var y := K.cabY(z, 0)
	if y < 0: return 0.0
	var x := 0.0
	while x < 1.2 and K.cabY(z, x + 0.02) > y - drop: x += 0.02
	return x

# ------------------------------------------------------------------ spoilers
static func _wing(K: CarBody, d: CarAcc, p: CarAcc, v: String) -> void:
	var S := K.S
	var C = K.C
	var T: Dictionary = Cars.TUNE_FIT.get(S.type, {"z": K.wingZ, "h": 0.26, "span": S.wid - 0.2, "chord": 0.38})
	var troof: bool = T.get("roof", false) and C != null
	if v == "lip":
		if troof:
			# a short roof lip in body colour: a thin blade off the roof's rear edge
			var zl: float = C.rw + 0.1
			var y := K.cabY(zl, 0)
			var half := minf(T.span / 2, _roofHalf(K, zl, 0.06) + 0.01)
			CarKit.finPlate(p, CarKit.airfoil(zl, y + 0.01, 0.24, 0.09, 0.0, -0.18), 0, half * 2)
		else:
			# a lip that hugs the boot lid at its tail edge (CarKit.lipSpoiler's shape, a little smaller)
			var z0 := K.zR + 0.035
			var z1 := z0 + 0.24
			var xw := 9.0
			var q := z0
			while q <= z1 + 1e-4:
				xw = minf(xw, K.shoulderX(q) * 0.94)
				q += 0.02
			# narrower where the deck is not smooth (tail fins, humps)
			var x0: float = T.get("duckGap", 0.0) + 0.01 if T.get("duckGap", 0.0) else -xw
			while xw > 0.3 and not _flatDeck(K, x0 if x0 > 0 else -xw, xw, z0, z1, 0.45): xw -= 0.04
			if xw <= 0.3: return
			var shape := func(u: float, vv: float) -> float:
				return 0.03 + 0.045 * pow(1.0 - vv, 1.6) * (1.0 - 0.4 * pow(absf(u * 2.0 - 1.0), 6.0))
			if T.get("duckGap", 0.0):
				CarKit.patch(p, K.on_top, T.duckGap + 0.01, xw, z0, z1, 5, 4, func(u: float, vv: float) -> float: return 0.03 + 0.045 * pow(1.0 - vv, 1.6), true)
			else:
				CarKit.patch(p, K.on_top, -xw, xw, z0, z1, 12, 4, shape)
		return
	# a big wing on posts: rally (tall, wide, big end plates) or swan neck (hangs from posts that reach over the top)
	var swan := v == "swan"
	var span: float = minf(T.span + (0.08 if not troof else 0.04), 2.0 * K.W - 0.04)
	var c: float = T.chord + (0.06 if v == "rally" else 0.04)
	var h: float = T.h + (0.12 if v == "rally" else 0.1) * (0.6 if troof else 1.0)
	var zc: float = T.z
	# the trailing edge stays over the car
	var zLE: float = zc + c / 2
	if zLE - c < K.zR + 0.02: zLE = K.zR + 0.02 + c
	if troof: zLE = minf(zLE, C.rw + 0.2)
	var xu := span * (0.22 if swan else 0.3)
	var y0: float = _deck(K, troof, zLE - c / 2, xu) + h
	var aoa := 0.14
	var foil := CarKit.airfoil(zLE, y0, c, 0.12, 0.04, aoa)
	d.color(sc(C_CARBON, 0.62))
	CarKit.finPlate(d, foil, 0, span)
	var lo := INF
	var hi := -INF
	var zTE := INF
	for q in foil:
		lo = minf(lo, q[1]); hi = maxf(hi, q[1]); zTE = minf(zTE, q[0])
	var ep := 0.05 if v == "rally" else 0.035
	var plate := [[zTE - 0.03, hi + ep], [zTE - 0.05, lo - ep - 0.04], [zLE - 0.08, lo - ep - 0.02], [zLE + 0.05, lo - 0.02], [zLE + 0.05, hi + 0.02]]
	CarKit.finPlate(d, plate, span / 2, 0.025)
	CarKit.finPlate(d, plate, -span / 2, 0.025)
	var gf := Geo.box(span - 0.03, 0.03, 0.012); gf.rotate_x(aoa); gf.translate(0, foil[14][1] + 0.014, zTE + 0.006); d.geo(gf)
	d.color(sc(C_TRIM, 0.35))
	var zf: float = zLE - c * 0.3
	var zb: float = zLE - c * 0.62
	for s in [-1.0, 1.0]:
		var x: float = s * xu
		var yf := _deck(K, troof, zf + 0.04, x) - 0.04
		var yb := _deck(K, troof, zb - 0.04, x) - 0.04
		if swan:
			# a neck from the deck up past the leading edge, over the top of the wing and down onto it
			CarKit.finPlate(d, [[zf + 0.06, yf], [zf - 0.06, yb], [zf - 0.1, hi + 0.02], [zf - 0.16, hi - 0.01], [zf - 0.16, hi + 0.06], [zf + 0.02, hi + 0.09], [zf + 0.08, hi + 0.04]], x, 0.03)
		else:
			CarKit.finPlate(d, [[zf + 0.04, yf], [zb - 0.04, yb], [zb, lo + 0.015], [zf, lo + 0.015]], x, 0.035)

# ------------------------------------------------------------------ front: splitter, canards, tow hook
## the height of the splitter: the lower edge of the front bumper
static func _splitY(K: CarBody) -> float:
	return maxf(K.bot(K.zF - 0.3), 0.09)

static func _splitter(K: CarBody, d: CarAcc, v: String) -> void:
	var ys := _splitY(K)
	var yt := ys + 0.025
	var xw := K.W - 0.12
	var front := []
	var back: float = K.zF - 0.45
	var x := -xw
	var n := 16
	for i in n + 1:
		x = -xw + 2.0 * xw * i / n
		var z = K.endZ(x, yt + 0.02, true)
		if z == null: z = K.endZ(x * 0.9, yt + 0.06, true)
		if z == null: return
		front.append(Vector2(x, float(z) + (0.07 if v == "race" else 0.05)))
	var pts: Array = []
	pts.append(Vector2(xw, back))
	for q in front.duplicate(): pts.append(q)
	pts.reverse()
	pts.append(Vector2(-xw, back))
	# (the outline must go one way round: back right, the front edge from left to right... reversed is fine for _slab)
	d.color(sc(C_CARBON if v == "race" else C_TRIM, 0.5 if v == "race" else 0.3))
	_slab(d, pts, ys, yt)
	if v == "race":
		# little end fences at both ends
		for s in [-1.0, 1.0]:
			var zfr: float = front[0 if s < 0 else n].y
			CarKit.finPlate(d, [[zfr, ys], [zfr - 0.28, ys], [zfr - 0.28, yt + 0.09], [zfr - 0.04, yt + 0.05]], s * (xw - 0.015), 0.025)

static func _canards(K: CarBody, d: CarAcc) -> void:
	var ys := _splitY(K) + 0.1
	d.color(sc(C_CARBON, 0.6))
	for k in 2:
		var y := ys + k * 0.085
		var x := K.W - 0.08
		var s = null
		while x > K.W - 0.5 and s == null:
			s = K.on_front(x, y)
			if s == null: x -= 0.03
		if s == null: continue
		for sx in [1.0, -1.0]:
			var p: Vector3 = s[0]
			var nn: Vector3 = s[1]
			p.x *= sx
			nn.x *= sx
			nn = Vector3(nn.x, 0, nn.z).normalized()
			var up := Vector3(0, 1, 0).rotated(nn, sx * (0.32 - k * 0.12))
			d.boxOn(0.2 - k * 0.04, 0.014, 0.13, p, nn, 0.08, up)

static func _tow(K: CarBody, d: CarAcc) -> void:
	# red tow straps, front right and rear right (seen from the chase camera), lying flat on the bumper
	d.color(sc(0xc8202a, 0.25))
	for front in [true, false]:
		var y := _splitY(K) + 0.08 if front else maxf(K.bot(K.zR + 0.3), 0.1) + 0.1
		var x := -0.42 if front else -0.7   # (behind: clear of the exhaust tips)
		var s = K.on_front(x, y) if front else K.on_rear(x, y)
		if s == null: s = K.on_front(x * 0.6, y + 0.05) if front else K.on_rear(x * 0.6, y + 0.05)
		if s == null: continue
		d.boxOn(0.045, 0.13, 0.09, s[0], s[1], 0.035)
		d.color(sc(0x9a9ea4, 0.8))
		d.boxOn(0.07, 0.03, 0.06, s[0] - Vector3(0, 0.06, 0), s[1], 0.05)
		d.color(sc(0xc8202a, 0.25))

# ------------------------------------------------------------------ sides: skirts, arches, mud flaps
static func _sill(K: CarBody) -> Array:
	var A := CarKit.anchors(K.S.type) if Cars.CAR_SPECS.has(K.S.type) else {}
	var s = A.get("sill", null)
	if s == null:
		var b := K.bot((K.S.wz[0] + K.S.wz[1]) / 2)
		s = [b + 0.04, b + 0.11]
	return s

static func _skirts(K: CarBody, d: CarAcc, p: CarAcc, v: String) -> void:
	var S := K.S
	var za: float = S.wz[1] + K.ra + 0.05
	var zb: float = S.wz[0] - K.ra - 0.05
	var sl := _sill(K)
	var y0: float = maxf(float(sl[0]) - 0.015, 0.085)
	var y1: float = float(sl[1]) + 0.025
	# make sure the band lies on the flank all the way (shrink it where the skin ends)
	var ok := func() -> bool:
		for i in 11:
			for j in 3:
				if K.on_side(za + (zb - za) * i / 10.0, y0 + (y1 - y0) * j / 2.0) == null: return false
		return true
	var tries := 0
	while not ok.call() and tries < 8:
		y0 += 0.01; za += 0.02; zb -= 0.02
		tries += 1
	if tries >= 8: return
	var A := p if v == "paint" else d
	if A == d: d.color(sc(C_TRIM, 0.3))
	CarKit.patch(A, K.on_side, za, zb, y0, y1, 12, 2, func(_u: float, vv: float) -> float: return 0.045 - 0.02 * vv, true)

## wide arches round each wheel: a band round the arch from low in front to low behind, bulging out most at its inner edge
static func _arches(K: CarBody, A: CarAcc, v: String) -> void:
	var S := K.S
	var r: float = S.r
	if v == "black": A.color(sc(C_TRIM, 0.3))
	for wz in S.wz:
		var a0 := 0.25
		var a1 := PI - 0.25
		var f := func(u: float, vv: float):
			var a: float = lerpf(a1, a0, u)
			var rad: float = K.ra + 0.005 + vv * 0.085
			return K.on_side(wz + cos(a) * rad, r + sin(a) * rad)
		var valid := func() -> bool:
			for i in 13:
				for j in 3:
					if f.call(i / 12.0, j / 2.0) == null: return false
			return true
		var tries := 0
		while not valid.call() and tries < 6:
			a0 += 0.1; a1 -= 0.1
			tries += 1
		if tries >= 6: continue
		var shape := func(u: float, vv: float) -> float:
			return 0.022 + 0.045 * pow(1.0 - vv, 0.8) * (1.0 - pow(absf(u * 2.0 - 1.0), 4.0))
		CarKit.patch(A, f, 0.0, 1.0, 0.0, 1.0, 14, 3, shape, true)

static func _flaps(K: CarBody, d: CarAcc, v: String) -> void:
	var S := K.S
	d.color(sc(0xb8202a if v == "red" else 0x18191c, 0.15))
	for wz in S.wz:
		var z: float = wz - K.ra - 0.03
		var top := minf(K.bot(z) + 0.05, float(S.r) * 2.0 - 0.02)
		var y0 := 0.085
		if top - y0 < 0.12: continue
		for sx in [1.0, -1.0]:
			d.box(float(S.w) + 0.05, top - y0, 0.014, sx * float(S.wx), (top + y0) / 2, z)
		if v == "red":
			d.color(sc(0xf2f2ee, 0.2))
			for sx in [1.0, -1.0]:
				d.box(float(S.w) - 0.04, 0.04, 0.016, sx * float(S.wx), y0 + 0.07, z - 0.001)
			d.color(sc(0xb8202a, 0.15))

# ------------------------------------------------------------------ rear: diffuser, big exhaust
static func _diffuser(K: CarBody, d: CarAcc) -> void:
	if K.diff: return
	# like CarKit.diffuser (the stock one of the supercars), but it leaves the kit alone: a ramp rising to the tail, fins
	var zf := K.zR + 0.42
	var zb := K.zR + 0.05
	var yf := 0.095
	var yb := maxf(yf + 0.04, K.bot(zb + 0.02) - 0.015)
	var dz := zf - zb
	var dy := yb - yf
	var wd := minf(1.36, 2.0 * K.W - 0.5)
	d.color(sc(C_CARBON, 0.5))
	d.box(wd, 0.02, sqrt(dz * dz + dy * dy), 0, (yf + yb) / 2, (zf + zb) / 2, atan2(dy, dz))
	var x := -wd / 2 + 0.08
	while x <= wd / 2 - 0.07:
		CarKit.finPlate(d, [[zf, K.bot(zf) + 0.03], [zf, yf - 0.005], [zb, yb - 0.06], [zb, K.bot(zb) + 0.03]], x, 0.03)
		x += (wd - 0.16) / 4.0

static func _bigExhaust(K: CarBody, d: CarAcc) -> void:
	var S := K.S
	var ex: Array = S.get("exh", [0.5])
	var side: float = minf(maxf(0.45, absf(ex[0])), K.W - 0.3) * signf(ex[0] if ex[0] != 0 else 1.0)
	var r := 0.072
	var ty := CarKit.exhaustY(K, r, side)
	var zb := CarKit.exhaustZ(K, side, ty, r)
	d.color(sc(0x5a5d63, 0.95))
	var t := Geo.cylinder(r, r * 0.9, 0.22, 18, 1, true); t.rotate_x(PI / 2); t.translate(side, ty, zb + 0.06); d.geo(t)
	var lip := Geo.torus(r - 0.005, 0.008, 6, 18); lip.translate(side, ty, zb - 0.05); d.geo(lip)
	d.color(sc(0x08080a, 0.05))
	var dd := Geo.circle(r * 0.9, 16); dd.rotate_y(PI); dd.translate(side, ty, zb - 0.015); d.geo(dd)

# ------------------------------------------------------------------ top: bonnet scoop and vents, roof
## the middle of the bonnet (where a scoop goes) and how long it may be: [z centre, half length] or [] when nothing fits
static func _bonnet(K: CarBody, xw: float) -> Array:
	var S := K.S
	var C = K.C
	var zw: float = S.wz[0]
	var zs: float = C.z0 if C != null else zw - 0.7
	var zc: float = lerpf(zw, zs, 0.5)
	var hl := minf(0.22, (zs - zw) * 0.45 + 0.08)
	for k in 9:
		var z: float = zc + (1 if k % 2 else -1) * ceilf(k / 2.0) * 0.06
		var free := true
		for r in K.topRects:
			if r[1] > -xw - 0.02 and r[0] < xw + 0.02 and r[3] > z - hl - 0.02 and r[2] < z + hl + 0.02: free = false; break
		if free and z + hl < K.zF - 0.2 and K.shoulderX(z) > xw + 0.1: return [z, hl]
	return []

static func _scoop(K: CarBody, d: CarAcc, p: CarAcc, v: String) -> void:
	if v == "vents":
		var b := _bonnet(K, 0.56)
		if b.is_empty(): return
		var z: float = b[0]
		var hl: float = minf(b[1], 0.16)
		# beside the middle (clear of the stripes), as far out as the bonnet is flat
		var xs = null
		for xr in [[0.3, 0.54], [0.3, 0.46], [0.26, 0.4]]:
			if _flatDeck(K, xr[0], xr[1], z - hl, z + hl, 0.75): xs = xr; break
		if xs == null: return
		var x0: float = xs[0]
		var x1: float = xs[1]
		d.color(sc(0x0c0d0f, 0.2))
		CarKit.patch(d, K.on_top, x0, x1, z - hl, z + hl, 3, 4, 0.03, true)
		d.color(sc(C_TRIM, 0.5))
		for k in 4:
			var zz: float = z - hl + (k + 0.5) * hl * 2 / 4.0
			CarKit.patch(d, K.on_top, x0 + 0.01, x1 - 0.01, zz - 0.018, zz + 0.018, 3, 1, func(_u: float, vv: float) -> float: return 0.035 + 0.02 * vv, true)
		return
	var b := _bonnet(K, 0.24)
	if b.is_empty(): return
	var z: float = b[0]
	var hl: float = b[1]
	var z0 := z - hl
	var z1 := z + hl * 0.8
	var shape := func(u: float, vv: float) -> float:
		return 0.035 + 0.07 * pow(vv, 0.8) * (1.0 - pow(absf(u * 2.0 - 1.0), 6.0))
	CarKit.patch(p, K.on_top, -0.22, 0.22, z0, z1, 10, 5, shape)
	# the mouth: dark, in front of the raised front edge
	var yt := K.topY(z1, 0)
	d.color(sc(0x08080a, 0.1))
	d.box(0.34, 0.052, 0.012, 0, yt + 0.035 + 0.032, z1 + 0.006)

static func _roof(K: CarBody, d: CarAcc, p: CarAcc, v: String) -> void:
	var C = K.C
	if C == null: return
	var zA: float = C.rw + 0.06
	var zB: float = C.ws - 0.06
	if zB - zA < 0.3: return
	var zm := (zA + zB) / 2
	var xr := _roofHalf(K, zm, 0.04) - 0.06
	if xr < 0.25: return
	var y := func(z: float, x: float) -> float: return K.cabY(z, x)
	match v:
		"rack":
			d.color(sc(0x1b1c1f, 0.4))
			for s in [-1.0, 1.0]:
				var x: float = s * xr
				for z in [zA + 0.06, zB - 0.06]:
					d.box(0.05, 0.07, 0.06, x, y.call(z, x) + 0.02, z)
				var ya: float = y.call(zA + 0.06, x) + 0.06
				var yb: float = y.call(zB - 0.06, x) + 0.06
				var len := zB - zA
				d.box(0.04, 0.03, len, x, (ya + yb) / 2, zm, atan2(ya - yb, len))
			d.color(sc(0x8a8d92, 0.6))
			for k in 3:
				var z: float = lerpf(zA + 0.12, zB - 0.12, k / 2.0)
				d.box(xr * 2 + 0.06, 0.025, 0.035, 0, y.call(z, xr) + 0.09, z)
		"bar":
			var z: float = zB - 0.1
			var yb: float = y.call(z, 0) + 0.075
			d.color(sc(0x1b1c1f, 0.4))
			for s in [-1.0, 1.0]:
				d.box(0.05, 0.09, 0.07, s * (xr - 0.05), y.call(z, xr - 0.05) + 0.03, z)
			d.box(xr * 2, 0.08, 0.09, 0, yb, z)
			d.color(sc(0xfff6d8, 0.95))
			for k in 4:
				var x: float = lerpf(-xr + 0.16, xr - 0.16, k / 3.0)
				var g := Geo.cylinder(0.034, 0.034, 0.02, 14); g.rotate_x(PI / 2); g.translate(x, yb, z + 0.046); d.geo(g)
		"scoop":
			var z0: float = zB - 0.42
			var z1: float = zB - 0.1
			var shape := func(u: float, vv: float) -> float:
				return 0.03 + 0.06 * pow(vv, 0.8) * (1.0 - pow(absf(u * 2.0 - 1.0), 6.0))
			CarKit.patch(p, K.on_cab, -0.15, 0.15, z0, z1, 8, 4, shape)
			if p.P.is_empty(): return
			d.color(sc(0x08080a, 0.1))
			d.box(0.22, 0.045, 0.012, 0, y.call(z1, 0) + 0.03 + 0.028, z1 + 0.006)

# ------------------------------------------------------------------ the bonnet in carbon or matt black
const HOODS := {"carbon": [0x1d2024, 0.55], "black": [0x17181b, 0.12]}

static func _hood(m: Dictionary, K: CarBody, L: Dictionary) -> void:
	var v: String = L.get("hood", "none")
	var body = m.get("body", null)
	if not HOODS.has(v) or body == null: return
	var roof: bool = L.get("roof", "") != "" and K.cab != null
	var sp := hoodSplit(K, roof, v)
	if sp.is_empty(): return
	CarKit.set_geo(body, sp[0])
	CarKit.mesh(m.get("shell", m.g), sp[1], CarKit.detailMat, true).set_meta("hood", true)

## the paint of a model split at the bonnet: [paint Geo without the bonnet (and without the cabin when the roof has its own
## colour, see CarLook's two-tone roof), the bonnet in the detail colours of `v`]; built once per model. The bonnet: the
## skin's upward faces between the windscreen and the nose, inside the shoulders
static func hoodSplit(K: CarBody, roof: bool, v: String) -> Array:
	var c: Dictionary = K.get_meta("hoods", {})
	var key := "%s/%s" % [roof, v]
	if c.has(key): return c[key]
	var S := K.S
	var C = K.C
	var zA: float = (C.z0 + 0.02) if C != null else float(S.wz[0]) - 0.75
	var rg := Geo.new()
	var hg := Geo.new()
	var g: Geo = K.body
	var col := sc(HOODS[v][0], HOODS[v][1])
	# the front edge: where the bonnet starts to fall away to the nose (whole quads of the skin, so the edge is clean)
	var zCut: float = zA
	while zCut < K.zF - 0.05:
		var t = K.on_top(0.0, zCut + 0.02)
		if t == null or t[1].y < 0.6: break
		zCut += 0.02
	for gr in g.groups:
		if gr[2] != 0: continue
		for i in range(gr[0], gr[0] + gr[1], 3):
			var ids := [g.idx[i], g.idx[i + 1], g.idx[i + 2]]
			var on := true
			for k in ids:
				var q: Vector3 = g.pos[k]
				if q.z < zA or q.z > zCut or absf(q.x) > K.shoulderX(q.z) + 0.005 or g.nrm[k].y < 0.2: on = false; break
			var M: Geo = hg if on else rg
			for k in ids:
				M.pos.append(g.pos[k]); M.nrm.append(g.nrm[k]); M.uv.append(Vector2.ZERO)
				M.col.append(col if on else Color(1, 1, 1, 1))
	if hg.pos.size() < 60:
		c[key] = []
	else:
		var rest := CarKit.Mb.new()
		rest.acc(rg)
		if not roof and K.cab != null: rest.group(K.cab, 0, Color(1, 1, 1, 0))
		rest.acc(K.G.paintAcc, Color(1, 1, 1, 0))
		var hood := CarKit.Mb.new()
		hood.acc(hg)
		c[key] = [rest.build(), hood.build()]
	K.set_meta("hoods", c)
	return c[key]

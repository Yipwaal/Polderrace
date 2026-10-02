class_name CarBody
extends RefCounted
## Port of the HTML game's makeKit(S): one body kit per model. The skin is a loft through cross-sections (sec(z): the right
## half from the bottom centre round to the top centre, the left half mirrors it); the cabin (greenhouse) is a second loft.
## Queries (sideX, topY, endZ, cabY and the on_* surface functions) put parts on the skin. JS: K = makeKit(S), returned as
## {S, body, cab, on, sideX, topY, cabY, endZ, hw, top, bot, roof, sec, W, zF, zR, r, wx, ra, xa, arch}.
## Sections are kept in doubles (PackedFloat64Array [x0, y0, x1, y1, ...]) like the JS numbers.

var S: Dictionary
var body: Geo
var cab: Geo = null
var W: float
var zF: float
var zR: float
var r: float
var wx: float
var ra: float
var xa: float
var top_fn: Callable
var bot_fn: Callable
var roof_fn: Callable = Callable()
var C = null     ## S.cab (Dictionary) or null

# set while dressing / styling (JS adds them to K on the fly)
var topRects: Array = []
var sideRects: Array = []
var numBlock: Array = []
var plateR = null
var diff := false
var stripeW = null
var numSpot_done := false
var numSpot = null      ## {f: Callable, z, r} or null
var G: Dictionary = {}  ## built part geometries per set (paint, trim, lamp, ...)
var wingZ := 0.0
var wingY := 0.0
var tune: Dictionary = {}
var stripes: Geo = null
var stripeNum: Geo = null
var numGeo: Geo = null
var meshes: Dictionary = {}   ## Geo -> shared ArrayMesh (CarKit)

var _tF: float
var _tR: float
var _tzF: float
var _tzR: float
var _fb: Array
var _sh: float
var _memo := {}
var _H := 0.0

const E := 0.01

func _init(spec: Dictionary) -> void:
	S = spec
	W = S.W; zF = S.zF; zR = S.zR; r = S.r; wx = S.wx
	ra = r + 0.06
	xa = wx - S.w / 2.0 - 0.05
	top_fn = MathX.mono(S.top)
	bot_fn = MathX.mono(S.bot)
	_tF = S.taper[0]; _tR = S.taper[1]
	var axF: float = S.wz[0]
	var axR: float = S.wz[1]
	_tzF = axF + ra * 0.7
	_tzR = axR - ra * 0.7
	_fb = S.get("fb", [0.0, 0.0])
	_sh = S.get("shoulder", -0.025)
	# stations: dense at the nose and tail, around every wheel arch and at the zone edges the car asks for
	var ex: Array = []
	for az in S.wz:
		for s in [-1, 1]:
			ex.append(az + s * ra); ex.append(az + s * (ra - 0.002))
		for i in range(1, 10):
			ex.append(az + ra * cos(i / 10.0 * PI))
	var d := 0.02
	while d < 0.3:
		ex.append(zF - d); ex.append(zR + d)
		d += 0.05
	for z in S.get("zcuts", []):
		ex.append(z)
	var zs := stationsOf(zR, zF, 0.14, ex)
	body = loftGeo(zs, sec, _bodyMat, 0)
	# cabin (greenhouse): glass sides, windscreen and rear window; roof, pillars and rails in paint
	C = S.get("cab", null)
	if C != null:
		roof_fn = MathX.mono(C.roof)
		_H = 0.0
		var z: float = C.z1
		while z <= C.z0:
			_H = maxf(_H, roof_fn.call(z) - top(z))
			z += 0.05
		var extra: Array = [C.ws, C.rw, C.sg[0], C.sg[1]]
		extra.append_array(C.get("bp", []))
		var cz := stationsOf(C.z1, C.z0, 0.075, extra)
		cab = loftGeo(cz, csec, _cabMat, 0)

func top(z: float) -> float:
	return top_fn.call(z)

func bot(z: float) -> float:
	return bot_fn.call(z)

func roof(z: float) -> float:
	return roof_fn.call(z)

## half width at z (taper towards nose and tail, rounded ends)
func hw(z: float) -> float:
	var k := 1.0
	if z > _tzF: k -= _tF * pow((z - _tzF) / (zF - _tzF), 2.2)
	if z < _tzR: k -= _tR * pow((_tzR - z) / (_tzR - zR), 2.2)
	var e := 0.16
	var d := minf(zF - z, z - zR)
	if d < e: k *= sqrt(1 - pow(1 - d / e, 2) * 0.18)
	return W * k

## top of the wheel arch at z (-1 = no arch)
func arch(z: float) -> float:
	var y := -1.0
	for az in S.wz:
		var d := absf(z - az)
		if d < ra: y = maxf(y, r + sqrt(ra * ra - d * d))
	return y

## fender bulge over the wheels
func bump(z: float) -> float:
	var b := 0.0
	for i in S.wz.size():
		var az: float = S.wz[i]
		var w := ra * 1.75
		var d := absf(z - az)
		if d < w: b += float(_fb[i]) * pow(cos(d / w * PI / 2), 2)
	return b

## cross-section at z: 20 points [x, y] of the right half, bottom centre round to top centre (memoised per 0.1 mm like the JS)
func sec(z: float) -> PackedFloat64Array:
	var key := int(floor(z * 1e4 + 0.5))   # JS Math.round
	if _memo.has(key):
		return _memo[key]
	var h0 := hw(z)
	var yb := bot(z)
	var ar := arch(z)
	var yo := maxf(yb, ar)
	var yt := top(z)
	var ys := yt + _sh + bump(z)
	if ar > 0: ys = maxf(ys, ar + 0.085)
	var tuck: float = S.get("tuck", 0.03)
	var tumb: float = S.get("tumb", 0.05)
	var h := maxf(0.02, ys - yo)
	var rb := minf(S.get("rb", 0.06), h * 0.28)
	var rt := minf(minf(S.get("rt", 0.1), h * 0.4), h0 * 0.3)
	var xin := minf(xa, h0 - rb - tuck - 0.04)
	var xs0 := h0 - tuck
	var xs1 := h0 - tumb
	var xe := xs1 - rt
	var P := PackedFloat64Array()
	P.append_array([0.0, yb, xin * 0.5, yb, xin - 0.004, yb, xin + 0.004, yo])
	for i in 4:
		var a := i / 3.0 * PI / 2
		P.append(xs0 - rb + sin(a) * rb); P.append(yo + rb - cos(a) * rb)
	for f in [0.25, 0.5, 0.75]:
		var y: float = yo + rb + f * (ys - rt - yo - rb)
		P.append(h0 - tuck * (1 - f) * (1 - f) - tumb * f * f); P.append(y)
	for i in 4:
		var a := i / 3.0 * PI / 2
		P.append(xs1 - rt + cos(a) * rt); P.append(ys - rt + sin(a) * rt)
	var sharp := clampf(bump(z) / 0.05, 0.0, 1.0)
	for f in [0.78, 0.56, 0.36, 0.18, 0.0]:
		var x: float = xe * f
		var q: float = f * f
		var sm := MathX.sstep(xin - 0.36, xin - 0.02, x)
		var w := q + (sm - q) * sharp
		P.append(x); P.append(yt + (ys - yt) * w)
	_memo[key] = P
	return P

## cabin section at z: 12 points (not memoised, like the JS)
func csec(z: float) -> PackedFloat64Array:
	var yb := top(z) - 0.06
	var yr := maxf(yb + 0.002, roof(z))
	var gb: float = hw(z) - S.get("tumb", 0.05) - C.inset
	var f := clampf((yr - yb) / _H, 0.0, 1.0)
	var gt: float = gb - C.tumble * f
	var rc := minf(minf(C.get("rc", 0.08), (yr - yb) * 0.45), gt * 0.4)
	var P := PackedFloat64Array()
	P.append_array([0.0, yb, gb * 0.5, yb, gb, yb])
	for t in [0.33, 0.66]:
		P.append(gb + (gt - gb) * t); P.append(yb + t * (yr - rc - yb))
	for i in 4:
		var a := i / 3.0 * PI / 2
		P.append(gt - rc + cos(a) * rc); P.append(yr - rc + sin(a) * rc)
	var xe := gt - rc
	var crown: float = C.get("crown", 0.02)
	for t in [0.66, 0.33, 0.0]:
		P.append(xe * t); P.append(yr + crown * (1 - t * t))
	return P

# underside, wheel-arch walls and the arch lip are black liner; the rest is paint
func _archWall(zc: float) -> bool:
	for az in S.wz:
		if absf(absf(zc - az) - ra) < 0.003: return true
	return false

func _inArch(zc: float) -> bool:
	for az in S.wz:
		if absf(zc - az) < ra: return true
	return false

func _bodyMat(zc: float, s: int) -> int:
	if s <= 3 or _archWall(zc): return 1
	if s <= 6 and (S.get("sill", false) or _inArch(zc)): return 1
	return 0

func _inB(z: float) -> bool:
	return C.has("bp") and z > C.bp[0] and z < C.bp[1]

func _cabMat(zc: float, s: int) -> int:
	if s <= 1: return 0
	if s <= 4: return (2 if _inB(zc) else 1) if (zc > C.sg[0] and zc < C.sg[1]) else 0
	if s <= 7: return 2 if C.get("rail", false) else 0
	return 1 if (zc > C.ws or zc < C.rw) else 0

# ---------------------------------------------------------------- queries

## outermost x of the skin at (z, y) (-1 = none)
func sideX(z: float, y: float) -> float:
	var P := sec(z)
	var x := -1.0
	for j in range(3, 15):
		var x1 := P[j * 2]; var y1 := P[j * 2 + 1]; var x2 := P[j * 2 + 2]; var y2 := P[j * 2 + 3]
		if (y1 - y) * (y2 - y) <= 0 and y1 != y2:
			x = maxf(x, x1 + (x2 - x1) * (y - y1) / (y2 - y1))
	return x

## height of the top of the skin at (z, x)
func topY(z: float, x: float) -> float:
	var P := sec(z)
	x = absf(x)
	for j in range(11, 19):
		var x1 := P[j * 2]; var y1 := P[j * 2 + 1]; var x2 := P[j * 2 + 2]; var y2 := P[j * 2 + 3]
		if (x1 - x) * (x2 - x) <= 0 and x1 != x2:
			return y1 + (y2 - y1) * (x - x1) / (x2 - x1)
	return top(z)

## z of the nose (front) or tail skin at (x, y): first station inside the outline, then bisection (null = never inside)
func endZ(x: float, y: float, front: bool):
	var z0 := zF if front else zR
	var sg := -1.0 if front else 1.0
	if inRing(sec(z0), x, y): return z0
	var a := z0
	var b = null
	var d := 0.01
	while d < 1.2:
		var z := z0 + sg * d
		if inRing(sec(z), x, y):
			b = z
			break
		a = z0 + sg * d
		d += 0.01
	if b == null: return null
	var bb: float = b
	for _i in 14:
		var mz := (a + bb) / 2
		if inRing(sec(mz), x, y): bb = mz
		else: a = mz
	return bb

## height of the cabin roof at (z, x) (-1 = not on the cabin)
func cabY(z: float, x: float) -> float:
	if C == null or z < C.z1 or z > C.z0: return -1.0
	var P := csec(z)
	x = absf(x)
	var n := P.size() / 2
	var j := n - 1
	while j > 5:
		var x1 := P[j * 2]; var y1 := P[j * 2 + 1]; var x2 := P[j * 2 - 2]; var y2 := P[j * 2 - 1]
		if (x1 - x) * (x2 - x) <= 0 and x1 != x2:
			return y1 + (y2 - y1) * (x - x1) / (x2 - x1)
		j -= 1
	return -1.0

# surface point + outward normal for the four ways a part can sit on the body: [Vector3 p, Vector3 n] or null

func on_front(x: float, y: float):
	var z = endZ(x, y, true)
	if z == null: return null
	var zx = endZ(x + E, y, true)
	var zy = endZ(x, y + E, true)
	var nx: float = -((zx - z) if zx != null else 0.0) / E
	var ny: float = -((zy - z) if zy != null else 0.0) / E
	return [Vector3(x, y, z), _norm(nx, ny, 1.0)]

func on_rear(x: float, y: float):
	var z = endZ(x, y, false)
	if z == null: return null
	var zx = endZ(x + E, y, false)
	var zy = endZ(x, y + E, false)
	var nx: float = ((zx - z) if zx != null else 0.0) / E
	var ny: float = ((zy - z) if zy != null else 0.0) / E
	return [Vector3(x, y, z), _norm(nx, ny, -1.0)]

func on_side(z: float, y: float):
	var x := sideX(z, y)
	if x < 0: return null
	var xz := sideX(z + E, y)
	var xy := sideX(z, y + E)
	return [Vector3(x, y, z), _norm(1.0, -((x if xy < 0 else xy) - x) / E, -((x if xz < 0 else xz) - x) / E)]

func on_top(x: float, z: float):
	var y := topY(z, x)
	return [Vector3(x, y, z), _norm(-(topY(z, x + E) - y) / E, 1.0, -(topY(z + E, x) - y) / E)]

func on_cab(x: float, z: float):
	var y := cabY(z, x)
	if y < 0: return null
	var yx := cabY(z, x + E)
	var yz := cabY(z + E, x)
	return [Vector3(x, y, z), _norm(-((y if yx < 0 else yx) - y) / E, 1.0, -((y if yz < 0 else yz) - y) / E)]

## normalise in doubles, then hand over as a Vector3 (THREE.Vector3.normalize)
static func _norm(x: float, y: float, z: float) -> Vector3:
	var l := sqrt(x * x + y * y + z * z)
	if l == 0.0: return Vector3(x, y, z)
	return Vector3(x / l, y / l, z / l)

# ---------------------------------------------------------------- loft helpers (JS loftGeo, stationsOf, inRing)

## a skin through cross-sections: ring(z) gives the right half (flat [x, y, ...], same length at every station), the left half
## mirrors it. mat(zc, s) picks the material index for the band between two stations on right-half segment s. Both ends capped.
static func loftGeo(zs: Array, ring: Callable, mat: Callable, capMat: int) -> Geo:
	var R: Array = []
	for z in zs:
		R.append(ring.call(z))
	var n: int = R[0].size() / 2
	var m := 2 * n - 2
	var pos := PackedVector3Array()
	var Gm := {}
	for k in zs.size():
		var rr: PackedFloat64Array = R[k]
		var zk: float = zs[k]
		for j in n:
			pos.append(Vector3(rr[j * 2], rr[j * 2 + 1], zk))
		var j2 := n - 2
		while j2 >= 1:
			pos.append(Vector3(-rr[j2 * 2], rr[j2 * 2 + 1], zk))
			j2 -= 1
	var put := func(mi: int, a: int, b: int, c: int) -> void:
		if not Gm.has(mi): Gm[mi] = []
		Gm[mi].append_array([a, b, c])
	for k in zs.size() - 1:
		var zc: float = (zs[k] + zs[k + 1]) / 2.0
		for j in m:
			var s := j if j < n - 1 else m - 1 - j
			var mi: int = mat.call(zc, s)
			var a := k * m + j
			var b := k * m + (j + 1) % m
			var c := (k + 1) * m + j
			var d := (k + 1) * m + (j + 1) % m
			put.call(mi, a, b, c)
			put.call(mi, b, d, c)
	# caps: own vertices (sharp edge), a fan from the centre of the ring
	for ks in [[0, -1], [zs.size() - 1, 1]]:
		var k: int = ks[0]
		var sg: int = ks[1]
		var base := pos.size()
		var rr: PackedFloat64Array = R[k]
		var zk: float = zs[k]
		var cy := 0.0
		for j in n:
			cy += rr[j * 2 + 1]
		cy /= n
		pos.append(Vector3(0, cy, zk))
		for j in n:
			pos.append(Vector3(rr[j * 2], rr[j * 2 + 1], zk))
		var j2 := n - 2
		while j2 >= 1:
			pos.append(Vector3(-rr[j2 * 2], rr[j2 * 2 + 1], zk))
			j2 -= 1
		for j in m:
			var a := base + 1 + j
			var b := base + 1 + (j + 1) % m
			if sg > 0: put.call(capMat, base, a, b)
			else: put.call(capMat, base, b, a)
	var g := Geo.new()
	g.pos = pos
	var keys := Gm.keys()
	keys.sort()
	for mi in keys:
		var l: Array = Gm[mi]
		g.groups.append([g.idx.size(), l.size(), mi])
		g.idx.append_array(PackedInt32Array(l))
	g.compute_vertex_normals()
	return g

static func stationsOf(z0: float, z1: float, step: float, extra: Array) -> Array:
	var s: Array = []
	var z := z0
	while z < z1 - 1e-6:
		s.append(z)
		z += step
	s.append(z1)
	for e in extra:
		if e > z0 + 0.002 and e < z1 - 0.002: s.append(float(e))
	s.sort()
	var out: Array = []
	for i in s.size():
		if i == 0 or s[i] - s[i - 1] > 0.003: out.append(s[i])
	return out

## point (|x|, y) inside the closed right-half outline r (flat [x, y, ...])
static func inRing(r: PackedFloat64Array, x: float, y: float) -> bool:
	x = absf(x)
	var c := false
	var n := r.size() / 2
	var j := n - 1
	for i in n:
		var xi := r[i * 2]; var yi := r[i * 2 + 1]; var xj := r[j * 2]; var yj := r[j * 2 + 1]
		if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
			c = not c
		j = i
	return c

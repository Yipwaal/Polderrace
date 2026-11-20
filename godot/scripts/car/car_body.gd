class_name CarBody
extends RefCounted
## One body kit per model (started as a port of the HTML game's makeKit(S)). The skin is a loft through cross-sections
## (sec(z): the right half from the bottom centre round to the top centre, the left half mirrors it); the cabin (greenhouse)
## is a second loft. Queries (sideX, topY, endZ, cabY and the on_* surface functions) put parts on the skin.
## Sections are kept in doubles (PackedFloat64Array [x0, y0, x1, y1, ...]).
##
## Fase 2 (better than the browser version): a waist crease and wheel-arch flares in the skin, a real cabin (the body is open
## under the greenhouse: tub, dashboard, seats, steering wheel, driver; the glass is see-through), window frames and a belt
## moulding, panel lines (doors, bonnet, boot, fuel flap, bumper seams) as a map in car space (lines_image), and proj():
## a patch projected onto the skin from any direction (lamps that wrap round a corner).
##
## The skin's ring (right half, N points): 0-2 underside, 3 wheel-well top, 4-7 sill round, 8-12 flank (9-11 the waist crease),
## 13-16 shoulder round, 17-21 top (bonnet/deck) to the centre line. The cabin's ring (CN points): 0-1 inside the body,
## 2-3 belt moulding, 3-5 side glass, 5-6 top frame, 6-9 roof rail round, 9-10 roof edge (screen frame), 10-12 roof.
##
## Car space: +z forward, +y up, +x the car's LEFT (the driver sits at +x).

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

# set while dressing / styling
var dress: Dictionary = {}   ## the model's dress parameters (CarKit._dressStd: sill, rtrim, plateF/R, mz/my, ...)
var topRects: Array = []
var sideRects: Array = []
var numBlock: Array = []
var plateR = null
var diff := false
var stripeW = null
var numSpot_done := false
var numSpot = null      ## {f: Callable, z, r} or null
var G: Dictionary = {}  ## built part geometries per set (see CarKit.carKit)
var wingZ := 0.0
var wingY := 0.0
var tune: Dictionary = {}
var stripes: Geo = null
var stripeNum: Geo = null
var numGeo: Geo = null
var meshes: Dictionary = {}   ## Geo -> shared ArrayMesh (CarKit)
var lines_tex: Texture2D = null

var zs: Array = []          ## the skin's stations (z)
var cz: Array = []          ## the cabin's stations
var hz0 := 0.0              ## the body has no top skin between hz1 and hz0 inside hole(z): the cabin's floor is down there
var hz1 := 0.0
var has_hole := false
var seat := {}              ## where the driver sits (interior()): x, z, y (head centre), yc (cushion top), wheel (Vector3), dashY, dashZ, rear (z or null), floor

var _tF: float
var _tR: float
var _tzF: float
var _tzR: float
var _fb: Array
var _sh: float
var _cut := 0.0
var _fc := 0.6
var _flare := 0.0
var _memo := {}
var _H := 0.0

const E := 0.01
const N := 22            ## points in the skin's ring
const CN := 13           ## points in the cabin's ring
const I_SHOULDER := 16   ## ring point where the shoulder round meets the top
const I_TOP := 17        ## first ring point of the top
const FRAME := 0.03      ## width of the dark frame round a window

func _init(spec: Dictionary) -> void:
	S = spec
	W = S.W; zF = S.zF; zR = S.zR; r = S.r; wx = S.wx
	ra = r + S.get("gap", 0.05)
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
	_cut = S.get("cut", 0.012)
	_fc = S.get("crease", 0.6)
	_flare = S.get("flare", 0.015)
	C = S.get("cab", null)
	if C != null:
		roof_fn = MathX.mono(C.roof)
	_find_hole()
	# stations: dense at the nose and tail, around every wheel arch and at the zone edges the car asks for
	var ex: Array = []
	for az in S.wz:
		for s in [-1, 1]:
			ex.append(az + s * ra); ex.append(az + s * (ra - 0.002))
		for i in range(1, 12):
			ex.append(az + ra * cos(i / 12.0 * PI))
	var d := 0.02
	while d < 0.3:
		ex.append(zF - d); ex.append(zR + d)
		d += 0.05
	for z in S.get("zcuts", []):
		ex.append(z)
	if has_hole:
		ex.append(hz0); ex.append(hz1)
	zs = stationsOf(zR, zF, 0.14, ex)
	body = loftGeo(zs, sec, _bodyMat, 0)
	# cabin (greenhouse): glass sides, windscreen and rear window in frames; roof, pillars and rails in paint
	if C != null:
		_H = 0.0
		var z: float = C.z1
		while z <= C.z0:
			_H = maxf(_H, roof_fn.call(z) - top(z))
			z += 0.05
		var extra: Array = [C.ws, C.rw, C.sg[0], C.sg[1], C.sg[0] + FRAME, C.sg[1] - FRAME, C.ws + FRAME, C.rw - FRAME]
		for b in C.get("bp", []):
			extra.append(b)
		if has_hole:
			extra.append(hz0); extra.append(hz1)
		cz = stationsOf(C.z1, C.z0, 0.075, extra)
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

## the wheel arches stand a little proud of the flank (0..1 at z)
func flareK(z: float) -> float:
	var k := 0.0
	for az in S.wz:
		var d := absf(z - az)
		var w := ra * 1.35
		if d < w: k = maxf(k, pow(cos(d / w * PI / 2), 1.5))
	return k

## half width of the cabin's foot at z (where the glass meets the body)
func cabFoot(z: float) -> float:
	return hw(z) - S.get("tumb", 0.05) - C.inset

## where the body has no top skin (the cabin floor is down there): under the greenhouse where it stands at least 7 cm proud,
## or the cockpit of an open car (S.cockpit = {z0, z1, w})
func _find_hole() -> void:
	has_hole = false
	if C != null:
		var a := -1e9
		var b := 1e9
		var z: float = C.z1
		var first := true
		while z <= C.z0 + 1e-6:
			if roof(z) - top(z) >= 0.07:
				if first:
					b = z; first = false
				a = z
			z += 0.01
		if not first and a - b > 0.4:
			hz0 = a; hz1 = b; has_hole = true
	elif S.has("cockpit"):
		hz0 = S.cockpit.z0; hz1 = S.cockpit.z1; has_hole = true

## half width of the opening at z (-1 = closed)
func hole(z: float) -> float:
	if not has_hole or z < hz1 - 1e-6 or z > hz0 + 1e-6: return -1.0
	if C != null: return cabFoot(z) - 0.015
	return S.cockpit.w

## cross-section at z: N points [x, y] of the right half, bottom centre round to top centre (memoised per 0.1 mm)
func sec(z: float) -> PackedFloat64Array:
	var key := int(floor(z * 1e4 + 0.5))
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
	var fl := _flare * flareK(z)
	var xin := minf(xa, h0 - rb - tuck - 0.04)
	var xs0 := h0 - tuck + fl
	var xs1 := h0 - tumb
	var xe := xs1 - rt
	var P := PackedFloat64Array()
	P.append_array([0.0, yb, xin * 0.5, yb, xin - 0.004, yb, xin + 0.004, yo])
	for i in 4:
		var a := i / 3.0 * PI / 2
		P.append(xs0 - rb + sin(a) * rb); P.append(yo + rb - cos(a) * rb)
	# flank: tucked in at the sill, leaning in at the shoulder; below the waist crease the panel lies `cut` deeper
	var fc := _fc
	var cut := _cut * clampf((h - 0.2) / 0.2, 0.0, 1.0)
	for fq in [[fc * 0.5, 0.45], [fc - 0.05, 1.0], [fc, 0.4], [fc + 0.05, 0.0], [fc + (1 - fc) * 0.6, 0.0]]:
		var f: float = fq[0]
		var y: float = yo + rb + f * (ys - rt - yo - rb)
		P.append(h0 - tuck * (1 - f) * (1 - f) - tumb * f * f + fl * (1 - f) * (1 - f) - cut * float(fq[1])); P.append(y)
	for i in 4:
		var a := i / 3.0 * PI / 2
		P.append(xs1 - rt + cos(a) * rt); P.append(ys - rt + sin(a) * rt)
	var sharp := clampf(bump(z) / 0.05, 0.0, 1.0)
	var hx := hole(z)
	var fs := [0.78, 0.56, 0.36, 0.18, 0.0]
	if hx > 0:
		var f0 := minf(hx, xe - 0.004) / xe
		fs = [f0, f0 * 0.75, f0 * 0.5, f0 * 0.25, 0.0]
	for f in fs:
		var x: float = xe * f
		var q: float = f * f
		var sm := MathX.sstep(xin - 0.36, xin - 0.02, x)
		var w := q + (sm - q) * sharp
		P.append(x); P.append(yt + (ys - yt) * w)
	_memo[key] = P
	return P

## cabin section at z: CN points (not memoised)
func csec(z: float) -> PackedFloat64Array:
	var yt := top(z)
	var yb := yt - 0.06
	var yr := maxf(yb + 0.002, roof(z))
	var gb: float = cabFoot(z)
	var f := clampf((yr - yb) / _H, 0.0, 1.0)
	var gt: float = gb - C.tumble * f
	var rc := minf(minf(C.get("rc", 0.08), (yr - yb) * 0.45), gt * 0.4)
	var y1 := yr - rc                 # where the roof rail round starts
	var hh := maxf(1e-4, y1 - yb)
	var P := PackedFloat64Array()
	P.append_array([0.0, yb, gb, yb])
	# belt moulding (3 cm above the body), glass, top frame (3 cm under the rail)
	var ya := minf(yt + 0.004, y1)
	var yg := minf(yt + 0.034, y1)
	var yf := maxf(yg, y1 - 0.03)
	for y in [ya, yg, (yg + yf) / 2, yf]:
		var t: float = (y - yb) / hh
		P.append(gb + (gt - gb) * t); P.append(y)
	for i in 4:
		var a := i / 3.0 * PI / 2
		P.append(gt - rc + cos(a) * rc); P.append(yr - rc + sin(a) * rc)
	var xe := gt - rc
	var crown: float = C.get("crown", 0.02)
	for t in [maxf(0.6, 1.0 - 0.045 / maxf(xe, 0.05)), 0.5, 0.0]:
		P.append(xe * t); P.append(yr + crown * (1 - t * t))
	return P

# underside, wheel-arch walls and the arch lip are black liner; the rest is paint; -1 = no skin (the cabin's opening)
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
	if s >= I_TOP and has_hole and zc > hz1 and zc < hz0: return -1
	return 0

func _inB(z: float) -> bool:
	return C.has("bp") and z > C.bp[0] and z < C.bp[1]

## cabin materials: 0 paint, 1 glass, 2 trim (frames, pillars), 3 belt moulding, -1 none (inside the body).
## Glass only where the cabin floor is open under it (hz1..hz0): the rest is a dark frame (the foot of the screen, the corners)
func _cabMat(zc: float, s: int) -> int:
	if s <= 1: return -1
	var open: bool = has_hole and zc > hz1 and zc < hz0
	var inSg: bool = zc > C.sg[0] and zc < C.sg[1]
	var edge: bool = inSg and (zc < C.sg[0] + FRAME or zc > C.sg[1] - FRAME or not open)
	if s == 2: return 3 if inSg else 0
	if s <= 4: return (2 if (_inB(zc) or edge) else 1) if inSg else 0
	if s == 5: return 2 if inSg else 0
	if s <= 8: return 2 if C.get("rail", false) else 0
	var screen: bool = zc > C.ws
	var rear: bool = zc < C.rw
	if not (screen or rear): return 0
	if s == 9 or not open: return 2
	if screen: return 2 if zc < C.ws + FRAME else 1
	return 2 if zc > C.rw - FRAME else 1

# ---------------------------------------------------------------- queries

## outermost x of the skin at (z, y) (-1 = none)
func sideX(z: float, y: float) -> float:
	var P := sec(z)
	var x := -1.0
	for j in range(3, I_SHOULDER):
		var x1 := P[j * 2]; var y1 := P[j * 2 + 1]; var x2 := P[j * 2 + 2]; var y2 := P[j * 2 + 3]
		if (y1 - y) * (y2 - y) <= 0 and y1 != y2:
			x = maxf(x, x1 + (x2 - x1) * (y - y1) / (y2 - y1))
	return x

## height of the top of the skin at (z, x)
func topY(z: float, x: float) -> float:
	var P := sec(z)
	x = absf(x)
	for j in range(I_SHOULDER - 3, N - 1):
		var x1 := P[j * 2]; var y1 := P[j * 2 + 1]; var x2 := P[j * 2 + 2]; var y2 := P[j * 2 + 3]
		if (x1 - x) * (x2 - x) <= 0 and x1 != x2:
			return y1 + (y2 - y1) * (x - x1) / (x2 - x1)
	return top(z)

## x where the shoulder round meets the top at z (the widest a part lying on the deck can be)
func shoulderX(z: float) -> float:
	return sec(z)[I_SHOULDER * 2]

## height of the shoulder (the top edge of the flank) at z
func shoulderY(z: float) -> float:
	return sec(z)[I_SHOULDER * 2 + 1]

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
	while j > 6:
		var x1 := P[j * 2]; var y1 := P[j * 2 + 1]; var x2 := P[j * 2 - 2]; var y2 := P[j * 2 - 1]
		if (x1 - x) * (x2 - x) <= 0 and x1 != x2:
			return y1 + (y2 - y1) * (x - x1) / (x2 - x1)
		j -= 1
	return -1.0

## x of the cabin's side (glass) at (z, y) (-1 = not on the cabin side)
func cabX(z: float, y: float) -> float:
	if C == null or z < C.z1 or z > C.z0: return -1.0
	var P := csec(z)
	for j in range(1, 9):
		var x1 := P[j * 2]; var y1 := P[j * 2 + 1]; var x2 := P[j * 2 + 2]; var y2 := P[j * 2 + 3]
		if (y1 - y) * (y2 - y) <= 0 and y1 != y2:
			return x1 + (x2 - x1) * (y - y1) / (y2 - y1)
	return -1.0

# surface point + outward normal for the ways a part can sit on the body: [Vector3 p, Vector3 n] or null

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

## the cabin's side glass at (z, y)
func on_cabside(z: float, y: float):
	var x := cabX(z, y)
	if x < 0: return null
	var xz := cabX(z + E, y)
	var xy := cabX(z, y + E)
	return [Vector3(x, y, z), _norm(1.0, -((x if xy < 0 else xy) - x) / E, -((x if xz < 0 else xz) - x) / E)]

## normalise in doubles, then hand over as a Vector3
static func _norm(x: float, y: float, z: float) -> Vector3:
	var l := sqrt(x * x + y * y + z * z)
	if l == 0.0: return Vector3(x, y, z)
	return Vector3(x / l, y / l, z / l)

## is the point inside the skin?
func inside(p: Vector3) -> bool:
	if p.z <= zR or p.z >= zF: return false
	return inRing(sec(snappedf(p.z, 0.002)), p.x, p.y)

## where a ray from o along d (towards the car) meets the skin (null = misses within 2.5 m)
func ray(o: Vector3, d: Vector3):
	var st := 0.03
	var t := 0.0
	var a := -1.0
	while t < 2.5:
		if inside(o + d * t):
			break
		a = t
		t += st
	if t >= 2.5: return null
	if a < 0: return o
	var b := t
	for _i in 9:
		var m := (a + b) / 2
		if inside(o + d * m): b = m
		else: a = m
	return o + d * b

## a surface for CarKit.patch() projected onto the skin: a grid of (nu + 1) x (nv + 1) rays from the plane through o spanned
## by ux, vy (u in u0..u1, v in v0..v1, metres) along d. Use it for parts that wrap round a corner (headlights on the edge of
## bonnet and nose, tail lights round the rear corner). Returns a Callable f(u, v) -> [point, normal] (null = a ray missed);
## call patch() with exactly this u0, u1, v0, v1, nu, nv. The normals come from the grid itself.
func proj(o: Vector3, d: Vector3, ux: Vector3, vy: Vector3, u0: float, u1: float, v0: float, v1: float, nu: int, nv: int) -> Callable:
	d = d.normalized()
	var P: Array = []
	var ok := true
	for i in nu + 1:
		var row: Array = []
		for j in nv + 1:
			var p = ray(o + ux * (u0 + (u1 - u0) * i / nu) + vy * (v0 + (v1 - v0) * j / nv), d)
			if p == null: ok = false
			row.append(p)
		P.append(row)
	if not ok:
		return func(_u, _v): return null
	var Q: Array = []
	for i in nu + 1:
		var row: Array = []
		for j in nv + 1:
			var a: Vector3 = P[mini(i + 1, nu)][j] - P[maxi(i - 1, 0)][j]
			var b: Vector3 = P[i][mini(j + 1, nv)] - P[i][maxi(j - 1, 0)]
			var n := a.cross(b).normalized()
			if n.dot(d) > 0: n = -n
			if n.length_squared() < 0.5: n = -d
			row.append([P[i][j], n])
		Q.append(row)
	return func(u: float, v: float):
		var i := clampi(roundi((u - u0) / (u1 - u0) * nu), 0, nu)
		var j := clampi(roundi((v - v0) / (v1 - v0) * nv), 0, nv)
		return Q[i][j]

# ---------------------------------------------------------------- the inside of the cabin

static func _quad(A: CarAcc, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	var flip := (b - a).cross(c - a).dot(n) < 0
	for t in ([[a, c, b, ca, cc, cb], [a, d, c, ca, cd, cc]] if flip else [[a, b, c, ca, cb, cc], [a, c, d, ca, cc, cd]]):
		for k in 3:
			A.P.append(t[k]); A.N.append(n); A.C.append(t[k + 3]); A.U.append(Vector2.ZERO)

## colour with a shine in alpha (CarPaint DETAIL: 0 matte .. 1 chrome)
static func sc(hex: int, shine := 0.1) -> Color:
	var c := MathX.col(hex)
	c.a = shine
	return c

## the cabin's inside into A (vertex colours, alpha = shine): tub (walls and floor down from the opening), dashboard, seats,
## steering wheel; the driver (helmet, shoulders, arms) into Dv. Fills `seat`.
func interior(A: CarAcc, Dv: CarAcc) -> void:
	if not has_hole: return
	var st: Array = zs.filter(func(z): return z >= hz1 - 1e-6 and z <= hz0 + 1e-6)
	if st.size() < 2: return
	var zm := (hz0 + hz1) / 2
	var yf := bot(zm) + 0.1
	var cTop := sc(0x25272b)
	var cLow := sc(0x0d0e10)
	var rim := func(z: float, k: int) -> Vector3:
		var P := sec(z)
		return Vector3(P[(I_TOP + k) * 2], P[(I_TOP + k) * 2 + 1], z)
	for i in st.size() - 1:
		var a: Vector3 = rim.call(st[i], 0)
		var b: Vector3 = rim.call(st[i + 1], 0)
		for sx in [1.0, -1.0]:
			var m := Vector3(sx, 1, 1)
			_quad(A, a * m, b * m, Vector3(b.x - 0.03, yf, b.z) * m, Vector3(a.x - 0.03, yf, a.z) * m, Vector3(-sx, 0, 0), cTop, cTop, cLow, cLow)
		_quad(A, Vector3(a.x - 0.03, yf, a.z), Vector3(b.x - 0.03, yf, b.z), Vector3(-b.x + 0.03, yf, b.z), Vector3(-a.x + 0.03, yf, a.z), Vector3.UP, cLow, cLow, cLow, cLow)
	for e in [[hz0, -1.0], [hz1, 1.0]]:
		var z: float = e[0]
		for k in 4:
			var a: Vector3 = rim.call(z, k)
			var b: Vector3 = rim.call(z, k + 1)
			for sx in [1.0, -1.0]:
				var m := Vector3(sx, 1, 1)
				_quad(A, a * m, b * m, Vector3(b.x, yf, z) * m, Vector3(a.x, yf, z) * m, Vector3(0, 0, e[1]), cTop, cTop, cLow, cLow)
	# where people sit
	var hx := hole(zm)
	var zH: float
	var yH: float
	var rear = null
	var ws: float
	if C != null:
		ws = C.ws
		zH = ws - minf(0.45, (ws - C.rw) * 0.5)
		yH = roof(zH) - 0.18
	else:
		ws = hz0
		zH = hz1 + 0.3
		yH = top(zH) + S.cockpit.get("head", 0.34)
	var dashZ: float = (hz0 - clampf((hz0 - ws) * 0.55, 0.26, 0.7)) if C != null else hz0 - 0.3
	zH = minf(zH, dashZ - 0.5)
	if C != null: yH = minf(roof(zH) - 0.18, S.get("headY", 9.0))
	var sx0 := minf(hole(zH) * 0.52, 0.4)
	var bwid := 0.44     # width of a seat back: inside the glass at shoulder height
	if C != null:
		var xg := cabX(zH, yH)
		if xg > 0: sx0 = minf(sx0, xg - 0.17)
		var xs := cabX(zH - 0.16, yH - 0.1)
		if xs > 0: bwid = clampf((xs - 0.035 - sx0) * 2, 0.3, 0.44)
		# a rear bench: heads under the roof, at least 60 cm behind the front seats
		var rz := maxf(zH - 0.86, C.rw + 0.2)
		if ws - C.rw > 1.0 and zH - rz >= 0.6 and hz1 < rz - 0.25 and S.get("rearSeat", true): rear = rz
	var yc := maxf(yf + 0.07, yH - 0.66)
	var dashY: float = rim.call(hz0, 0).y - 0.012
	# dashboard: a shelf from the foot of the screen back to the wheel, with a cowl over the dials
	var cDash := sc(0x1a1b1f, 0.12)
	A.color(cDash)
	var dw := hole(dashZ) * 2 - 0.05
	A.box(dw, 0.34, hz0 - dashZ, 0, dashY - 0.17, (hz0 + dashZ) / 2)
	A.color(sc(0x121316, 0.1)).box(0.34, 0.07, 0.2, sx0, dashY + 0.02, dashZ + 0.11, -0.12)
	# centre tunnel
	A.color(sc(0x17181b, 0.1)).box(0.2, 0.2, dashZ - hz1 - 0.1, 0, yf + 0.1, (dashZ + hz1) / 2)
	# steering wheel
	var wp := Vector3(sx0, dashY - 0.05, dashZ - 0.07)
	var tw := Geo.torus(0.165, 0.02, 6, 14)
	tw.rotate_x(-0.38); tw.translate(wp.x, wp.y, wp.z)
	A.color(sc(0x0c0d0f, 0.2)).geo(tw)
	A.box(0.3, 0.03, 0.03, wp.x, wp.y, wp.z, -0.38)
	A.box(0.05, 0.05, 0.2, wp.x, wp.y - 0.03, wp.z + 0.1, -0.38)
	# seats: cushion, reclined backrest, headrest
	var cSeat := sc(S.get("trimCol", 0x3a3d44), 0.15)
	var cSeat2 := sc(0x2a2c31, 0.15)
	for sx in [sx0, -sx0]:
		A.color(cSeat2).box(0.46, 0.12, 0.48, sx, yc - 0.06, zH + 0.17)
		var bh := maxf(0.2, yH - 0.2 - yc)
		A.color(cSeat).box(bwid, bh, 0.1, sx, yc + bh / 2 - 0.02, zH - 0.11 - bh * 0.09, -0.2)
		A.color(cSeat2).box(minf(0.23, bwid - 0.08), 0.2, 0.075, sx, yH - 0.06, zH - 0.2, -0.1)
	if rear != null:
		var rz: float = rear
		var bw := maxf(0.6, hole(maxf(rz, hz1 + 0.05)) * 2 - 0.1)
		var ry: float = minf(yH, roof(rz - 0.2) - 0.2) if C != null else yH
		var xr := cabX(rz - 0.24, ry - 0.08) if C != null else -1.0
		var bt := minf(bw, (xr - 0.04) * 2) if xr > 0 else bw     # the back's width: inside the glass up there
		A.color(cSeat2).box(bw, 0.12, 0.46, 0, yc - 0.04, rz + 0.17)
		A.color(cSeat).box(bt, maxf(0.2, ry - 0.1 - yc), 0.1, 0, (yc + ry - 0.1) / 2, rz - 0.13, -0.24)
		for sx in [bt * 0.27, -bt * 0.27]:
			A.color(cSeat2).box(0.22, 0.14, 0.08, sx, ry - 0.04, rz - 0.2, -0.1)
		# parcel shelf behind the bench
		if hz1 < rz - 0.3:
			A.color(cDash).box(hole(rz - 0.2) * 2 - 0.04, 0.03, rz - 0.22 - hz1, 0, top(hz1) - 0.05, (rz - 0.22 + hz1) / 2)
	elif hz1 < zH - 0.45:
		# two-seater: a shelf behind the seats
		A.color(cDash).box(hole(maxf(zH - 0.4, hz1 + 0.02)) * 2 - 0.04, 0.03, zH - 0.3 - hz1, 0, top(hz1) - 0.06, (zH - 0.3 + hz1) / 2)
	# the driver: helmet with a dark visor, shoulders, arms to the wheel
	var hp := Vector3(sx0, yH, zH)
	var hel := Geo.sphere(0.125, 12, 9)
	hel.scale(1.0, 1.04, 1.12); hel.translate(hp.x, hp.y, hp.z + 0.01)
	Dv.color(sc(S.get("helmet", 0xe9eaec), 0.55)).geo(hel)
	Dv.color(sc(0x0c0e12, 0.8)).box(0.2, 0.075, 0.1, hp.x, hp.y + 0.012, hp.z + 0.098)
	var cSuit := sc(0x1c1e24, 0.1)
	Dv.color(cSuit).box(0.4, maxf(0.12, hp.y - 0.12 - yc), 0.2, hp.x, (hp.y - 0.12 + yc) / 2, hp.z - 0.03, -0.12)
	for sd in [1.0, -1.0]:
		var a := Vector3(hp.x + sd * 0.19, hp.y - 0.26, hp.z + 0.02)
		var b := Vector3(wp.x + sd * 0.15, wp.y + 0.03, wp.z - 0.03)
		var mid := (a + b) / 2
		var zb := (b - a).normalized()
		var xb := Vector3.UP.cross(zb).normalized()
		Dv.geo(Geo.box(0.08, 0.08, a.distance_to(b)), Transform3D(Basis(xb, zb.cross(xb), zb), mid))
	seat = {"x": sx0, "z": zH, "y": yH, "yc": yc, "wheel": wp, "dashY": dashY, "dashZ": dashZ, "rear": rear, "floor": yf}

# ---------------------------------------------------------------- panel lines

const LW := 1024
const LH := 512
const LY := 1.6    ## metres of height on the flank chart
const LX := 1.2    ## metres of half width on the top chart

## (zR, 1 / length, 1 / LY, 1 / LX) for CarPaint.set_lines
func lines_map() -> Vector4:
	return Vector4(zR, 1.0 / (zF - zR), 1.0 / LY, 1.0 / LX)

## the model's panel lines, drawn in car space: the flank (z, y) on the upper half of the map, the top (z, |x|) on the lower
## half. White = paint, dark = a shut line. S.doors = [front, rear] or [front, middle, rear] (z of the door's shut lines),
## S.lines = false: none. Built on the CPU (no canvas needed, so it is there at once and in headless runs).
func lines_image() -> Image:
	var px := PackedByteArray()
	px.resize(LW * LH)
	px.fill(255)
	var side := func(pts: Array) -> void:
		for i in pts.size() - 1:
			_seg(px, _u(pts[i][0]), (0.5 - pts[i][1] / LY * 0.5) * LH, _u(pts[i + 1][0]), (0.5 - pts[i + 1][1] / LY * 0.5) * LH)
	var topc := func(pts: Array) -> void:
		for i in pts.size() - 1:
			_seg(px, _u(pts[i][0]), (0.5 + pts[i][1] / LX * 0.5) * LH, _u(pts[i + 1][0]), (0.5 + pts[i + 1][1] / LX * 0.5) * LH)
	if S.get("lines", true):
		var axF: float = S.wz[0]
		var axR: float = S.wz[1]
		var zA := axF - ra - 0.05      # rear edge of the front arch
		var zB := axR + ra + 0.05      # front edge of the rear arch
		var sill := func(z: float) -> float: return bot(z) + S.get("rb", 0.06) + 0.035
		var belt := func(z: float) -> float: return shoulderY(z) - minf(S.get("rt", 0.1), 0.1) - 0.01
		# doors
		var doors: Array = S.get("doors", [])
		if doors.is_empty() and C != null:
			var f0: float = minf(zA - 0.1, C.sg[1] + 0.12)
			if C.has("bp"): doors = [f0, (C.bp[0] + C.bp[1]) / 2, maxf(zB - 0.02, C.sg[0] + 0.1)]
			else: doors = [f0, maxf(zB + 0.1, C.sg[0] + (C.sg[1] - C.sg[0]) * 0.28)]
		elif doors.is_empty() and S.has("cockpit"):
			doors = [minf(zA - 0.1, S.cockpit.z0 + 0.1), maxf(zB + 0.1, S.cockpit.z1 + 0.25)]
		for k in doors.size():
			var z: float = doors[k]
			var y0: float = sill.call(z)
			var pts: Array = []
			if k == doors.size() - 1 and z < zB + 0.04:
				# the last shut line runs into the rear wheel arch: follow the arch down
				var rr := ra + 0.045
				var a0 := acos(clampf((z - axR) / rr, -1.0, 1.0))
				pts.append([z, belt.call(z)])
				var a := a0
				while a > 0.0:
					pts.append([axR + rr * cos(a), r + rr * sin(a)])
					a -= 0.12
				pts = pts.filter(func(p): return p[1] >= y0)
			else:
				pts = [[z, y0], [z, belt.call(z)]]
			side.call(pts)
		if doors.size() >= 2:
			# the doors' bottom edge
			var a: float = doors[0]
			var b: float = maxf(doors[doors.size() - 1], zB)
			side.call([[a, sill.call(a)], [b, sill.call(b)]])
		# bumper seams: from the wheel arches to the nose and the tail
		for e in [[axF, 1.0, zF], [axR, -1.0, zR]]:
			var az: float = e[0]
			var sg: float = e[1]
			var y: float = r + ra * 0.5
			var z0: float = az + sg * sqrt(maxf(0.0, ra * ra * 1.1 - (y - r) * (y - r)))
			if absf(e[2] - z0) > 0.25 and sideX(z0, y) > 0:
				side.call([[z0, y], [e[2] - sg * 0.1, y + 0.02]])
		# fuel flap on the rear wing
		var fy: float = r + ra + 0.2
		var fz: float = axR + S.get("fuelZ", 0.0)
		if S.get("fuel", true) and shoulderY(fz) - fy > 0.13:
			var q := 0.065
			side.call([[fz - q, fy - q], [fz + q, fy - q], [fz + q, fy + q], [fz - q, fy + q], [fz - q, fy - q]])
		# bonnet and boot lid on the top chart
		var hood0: float = (C.z0 + 0.05) if C != null else ((S.cockpit.z0 + 0.3) if S.has("cockpit") else 0.6)
		var hood1: float = zF - S.get("hoodGap", 0.22)
		var xk: float = S.get("hoodW", 0.74)
		if hood1 - hood0 > 0.4 and S.get("hood", true):
			var pts: Array = []
			var z := hood0
			while z < hood1:
				pts.append([z, shoulderX(z) * xk])
				z += 0.1
			var xl: float = shoulderX(hood1) * xk
			pts.append([hood1, xl]); pts.append([hood1, 0.0])
			topc.call(pts)
		var deck0: float = (C.z1 - 0.04) if C != null else ((S.cockpit.z1 - 0.45) if S.has("cockpit") else -0.9)
		var deck1 := zR + 0.1
		if deck0 - deck1 > 0.3 and S.get("boot", true):
			var pts: Array = [[deck0, 0.0]]
			var z := deck0
			while z > deck1:
				pts.append([z, shoulderX(z) * 0.78])
				z -= 0.1
			pts.append([deck1, shoulderX(deck1) * 0.78])
			topc.call(pts)
		for l in S.get("sideLines", []): side.call(l)
		for l in S.get("topLines", []): topc.call(l)
	return Image.create_from_data(LW, LH, false, Image.FORMAT_L8, px)

func _u(z: float) -> float:
	return (z - zR) / (zF - zR) * LW

## a soft dark line of about 2 px
static func _seg(px: PackedByteArray, x0: float, y0: float, x1: float, y1: float) -> void:
	var n := maxi(1, ceili(maxf(absf(x1 - x0), absf(y1 - y0)) * 2.0))
	for i in n + 1:
		var t := float(i) / n
		var x := x0 + (x1 - x0) * t
		var y := y0 + (y1 - y0) * t
		var xi := floori(x)
		var yi := floori(y)
		for dy in range(-1, 3):
			var yy := yi + dy
			if yy < 0 or yy >= LH: continue
			for dx in range(-1, 3):
				var xx := xi + dx
				if xx < 0 or xx >= LW: continue
				var d := sqrt((xx + 0.5 - x) * (xx + 0.5 - x) + (yy + 0.5 - y) * (yy + 0.5 - y))
				var v := int(clampf(60.0 + (d - 0.7) * 190.0, 60.0, 255.0))
				var k := yy * LW + xx
				if v < px[k]: px[k] = v

# ---------------------------------------------------------------- loft helpers

## a skin through cross-sections: ring(z) gives the right half (flat [x, y, ...], same length at every station), the left half
## mirrors it. mat(zc, s) picks the material index for the band between two stations on right-half segment s (-1 = no skin).
## Both ends capped.
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
			if mi < 0: continue
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

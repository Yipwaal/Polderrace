class_name CRCurve
## Exact port of three.js r128 CatmullRomCurve3 (closed, centripetal) plus the Curve base class
## arc-length helpers (getLengths with 200 divisions, getUtoTmapping, getPointAt, getTangentAt),
## so computeTrack samples the very same points as the HTML game. Uses 64-bit floats throughout.

var px: PackedFloat64Array
var py: PackedFloat64Array
var pz: PackedFloat64Array
var closed := true
var _lengths: PackedFloat64Array = PackedFloat64Array()
const DIVS := 200

func _init(points: Array, is_closed := true) -> void:
	closed = is_closed
	for p in points:
		px.append(p[0]); py.append(p[1]); pz.append(p[2])

## [x,y,z] for t in [0,1]
func get_point(t: float) -> PackedFloat64Array:
	var l := px.size()
	var p := (l - (0 if closed else 1)) * t
	var int_point := int(floor(p))
	var weight := p - int_point
	if closed:
		int_point += 0 if int_point > 0 else (int(floor(absf(int_point) / l)) + 1) * l
	elif weight == 0.0 and int_point == l - 1:
		int_point = l - 2
		weight = 1.0
	var i0: int = (int_point - 1) % l
	var i1: int = int_point % l
	var i2: int = (int_point + 1) % l
	var i3: int = (int_point + 2) % l
	var dt0 := pow(_d2(i0, i1), 0.25)
	var dt1 := pow(_d2(i1, i2), 0.25)
	var dt2 := pow(_d2(i2, i3), 0.25)
	if dt1 < 1e-4: dt1 = 1.0
	if dt0 < 1e-4: dt0 = dt1
	if dt2 < 1e-4: dt2 = dt1
	return PackedFloat64Array([
		_calc(px[i0], px[i1], px[i2], px[i3], dt0, dt1, dt2, weight),
		_calc(py[i0], py[i1], py[i2], py[i3], dt0, dt1, dt2, weight),
		_calc(pz[i0], pz[i1], pz[i2], pz[i3], dt0, dt1, dt2, weight)])

func _d2(a: int, b: int) -> float:
	var dx := px[a] - px[b]; var dy := py[a] - py[b]; var dz := pz[a] - pz[b]
	return dx * dx + dy * dy + dz * dz

static func _calc(x0: float, x1: float, x2: float, x3: float, dt0: float, dt1: float, dt2: float, t: float) -> float:
	var t1 := (x1 - x0) / dt0 - (x2 - x0) / (dt0 + dt1) + (x2 - x1) / dt1
	var t2 := (x2 - x1) / dt1 - (x3 - x1) / (dt1 + dt2) + (x3 - x2) / dt2
	t1 *= dt1
	t2 *= dt1
	var c0 := x1
	var c1 := t1
	var c2 := -3.0 * x1 + 3.0 * x2 - 2.0 * t1 - t2
	var c3 := 2.0 * x1 - 2.0 * x2 + t1 + t2
	var tt := t * t
	return c0 + c1 * t + c2 * tt + c3 * tt * t

func get_lengths() -> PackedFloat64Array:
	if _lengths.size() == DIVS + 1:
		return _lengths
	var cache := PackedFloat64Array([0.0])
	var last := get_point(0.0)
	var sum := 0.0
	for p in range(1, DIVS + 1):
		var cur := get_point(float(p) / DIVS)
		var dx := cur[0] - last[0]; var dy := cur[1] - last[1]; var dz := cur[2] - last[2]
		sum += sqrt(dx * dx + dy * dy + dz * dz)
		cache.append(sum)
		last = cur
	_lengths = cache
	return cache

func get_length() -> float:
	var l := get_lengths()
	return l[l.size() - 1]

func u_to_t(u: float) -> float:
	var arc := get_lengths()
	var il := arc.size()
	var target := u * arc[il - 1]
	var low := 0
	var high := il - 1
	var i := 0
	while low <= high:
		i = int(floor(low + (high - low) / 2.0))
		var cmp := arc[i] - target
		if cmp < 0.0:
			low = i + 1
		elif cmp > 0.0:
			high = i - 1
		else:
			high = i
			break
	i = high
	if arc[i] == target:
		return float(i) / (il - 1)
	var before := arc[i]
	var after := arc[i + 1]
	return (i + (target - before) / (after - before)) / (il - 1)

func get_point_at(u: float) -> PackedFloat64Array:
	return get_point(u_to_t(u))

func get_tangent(t: float) -> PackedFloat64Array:
	var delta := 0.0001
	var t1 := maxf(0.0, t - delta)
	var t2 := minf(1.0, t + delta)
	var a := get_point(t1)
	var b := get_point(t2)
	var len := sqrt((b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2 + (b[2] - a[2]) ** 2)
	if len == 0.0:
		return PackedFloat64Array([0.0, 0.0, 0.0])
	return PackedFloat64Array([(b[0] - a[0]) / len, (b[1] - a[1]) / len, (b[2] - a[2]) / len])

func get_tangent_at(u: float) -> PackedFloat64Array:
	return get_tangent(u_to_t(u))

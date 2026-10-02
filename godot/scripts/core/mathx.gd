class_name MathX
## Small math helpers that mirror the HTML game (clamp, lerpAngle, mono, sstep).

static func clampf_(v: float, a: float, b: float) -> float:
	return max(a, min(b, v))

## shortest-way angle interpolation (JS lerpAngle)
static func lerp_angle_(a: float, b: float, t: float) -> float:
	var d := fposmod(b - a + PI, TAU) - PI
	return a + d * t

static func sstep(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

## JS: Math.sign
static func sgn(v: float) -> float:
	return 1.0 if v > 0.0 else (-1.0 if v < 0.0 else 0.0)

## monotone cubic through [[z,y],...] as a function of z (JS mono). Returns a Callable(z)->y.
static func mono(pts: Array) -> Callable:
	var p := pts.duplicate()
	p.sort_custom(func(a, b): return a[0] < b[0])
	var n := p.size()
	if n == 1:
		var y0: float = p[0][1]
		return func(_z): return y0
	var d: Array[float] = []
	var m: Array[float] = []
	for i in n - 1:
		d.append((p[i + 1][1] - p[i][1]) / (p[i + 1][0] - p[i][0]))
	m.resize(n)
	m[0] = d[0]
	m[n - 1] = d[n - 2]
	for i in range(1, n - 1):
		m[i] = 0.0 if d[i - 1] * d[i] <= 0.0 else (d[i - 1] + d[i]) / 2.0
	for i in n - 1:
		if absf(d[i]) < 1e-9:
			m[i] = 0.0
			m[i + 1] = 0.0
			continue
		var a: float = m[i] / d[i]
		var b: float = m[i + 1] / d[i]
		var s: float = a * a + b * b
		if s > 9.0:
			var t: float = 3.0 / sqrt(s)
			m[i] = t * a * d[i]
			m[i + 1] = t * b * d[i]
	return func(z: float) -> float:
		if z <= p[0][0]:
			return p[0][1]
		if z >= p[n - 1][0]:
			return p[n - 1][1]
		var i := 0
		while z > p[i + 1][0]:
			i += 1
		var h: float = p[i + 1][0] - p[i][0]
		var t: float = (z - p[i][0]) / h
		var t2 := t * t
		var t3 := t2 * t
		return (2 * t3 - 3 * t2 + 1) * p[i][1] + (t3 - 2 * t2 + t) * h * m[i] + (-2 * t3 + 3 * t2) * p[i + 1][1] + (t3 - t2) * h * m[i + 1]

## colour from a JS hex int (0xRRGGBB)
static func col(hex: int) -> Color:
	return Color8((hex >> 16) & 255, (hex >> 8) & 255, hex & 255)

## three Color.setHSL(h, s, l) (h wraps, s and l clamped)
static func hsl(h: float, s: float, l: float) -> Color:
	h = fposmod(h, 1.0)
	s = clampf(s, 0.0, 1.0)
	l = clampf(l, 0.0, 1.0)
	if s == 0.0:
		return Color(l, l, l)
	var p := l * (1.0 + s) if l <= 0.5 else l + s - l * s
	var q := 2.0 * l - p
	return Color(_hue2rgb(q, p, h + 1.0 / 3.0), _hue2rgb(q, p, h), _hue2rgb(q, p, h - 1.0 / 3.0))

static func _hue2rgb(p: float, q: float, t: float) -> float:
	if t < 0.0: t += 1.0
	if t > 1.0: t -= 1.0
	if t < 1.0 / 6.0: return p + (q - p) * 6.0 * t
	if t < 1.0 / 2.0: return q
	if t < 2.0 / 3.0: return p + (q - p) * 6.0 * (2.0 / 3.0 - t)
	return p

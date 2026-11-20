class_name CarDecal
## The pictures of a car's look, drawn with Canvas2D like every other texture of the game: side designs for the doors
## (flames, flag, tulips, ...), stickers, start numbers in every style, number plates, the windscreen band and tyre
## walls. CarLook asks for them and keeps the materials; nothing here is cached.

const INK := "#161a22"
const WHITE := "#f7f7f2"
const NL_RED := "#ae1c28"
const NL_BLUE := "#21468b"
const DELFT := "#1d4f9e"

# ------------------------------------------------------------------ side designs
## x runs from the front wheel arch (0) to the rear one (w), y from the shoulder (0) down to the sill (h)
const DOORS := {"side": true, "rally": true, "checker": true, "flames": true, "flag": true, "delft": true, "tulips": true, "lion": true}
const DW := 512
const DH := 144

static func door(d: String, c1: Color, c2: Color) -> ImageTexture:
	return Canvas2D.tex(DW, DH, func(c, w, h): _door(c, d, w, h, c1, c2))

static func _door(c: Canvas2D, d: String, w: float, h: float, c1: Color, c2: Color) -> void:
	match d:
		"side": _side(c, w, h, c1, c2)
		"rally": _rally(c, w, h, c1, c2)
		"checker": _checker(c, w, h, c1, c2)
		"flames": _flames(c, w, h, c1, c2)
		"flag": _flag(c, w, h)
		"delft": _delft(c, w, h)
		"tulips": _tulips(c, w, h)
		"lion": _lion(c, w, h, c1, c2)

static func _poly(c: Canvas2D, pts: Array, col) -> void:
	c.fillStyle = col
	c.beginPath()
	c.moveTo(pts[0][0], pts[0][1])
	for i in range(1, pts.size()): c.lineTo(pts[i][0], pts[i][1])
	c.closePath()
	c.fill()

static func _disc(c: Canvas2D, x: float, y: float, r: float, col) -> void:
	c.fillStyle = col
	c.beginPath(); c.arc(x, y, r, 0, TAU); c.fill()

## a band that starts as a point behind the front wheel and widens to the rear, a thin line above it
static func _side(c: Canvas2D, w: float, h: float, c1: Color, c2: Color) -> void:
	_poly(c, [[w * 0.03, h * 0.74], [w * 0.985, h * 0.5], [w * 0.955, h * 0.82], [w * 0.07, h * 0.82]], c1)
	_poly(c, [[w * 0.09, h * 0.625], [w * 0.99, h * 0.39], [w * 0.982, h * 0.45], [w * 0.09, h * 0.67]], c2)
	for i in 3:
		var x := w * (0.73 + i * 0.06)
		_poly(c, [[x, h * 0.33], [x + w * 0.03, h * 0.32], [x + w * 0.075, h * 0.12], [x + w * 0.045, h * 0.13]], c1)

## slanted blocks that grow towards the rear
static func _rally(c: Canvas2D, w: float, h: float, c1: Color, c2: Color) -> void:
	var x := w * 0.14
	for i in 6:
		var bw := w * (0.035 + i * 0.016)
		_poly(c, [[x, h * 0.9], [x + bw, h * 0.9], [x + bw + h * 0.62, h * 0.1], [x + h * 0.62, h * 0.1]], c1 if i % 2 == 0 else c2)
		x += bw + w * 0.022

## a chequered flag that falls apart towards the front
static func _checker(c: Canvas2D, w: float, h: float, c1: Color, c2: Color) -> void:
	var s := h / 6.0
	var n := int(ceil(w / s))
	for i in n:
		var t := (float(i) / n - 0.2) / 0.55
		if t <= 0.0: continue
		var k := clampf(t, 0.18, 1.0)
		for j in 6:
			if k < 0.5 and (i + j) % 2 == 1: continue
			c.fillStyle = c1 if (i + j) % 2 == 0 else c2
			var q := s * k
			c.fillRect(i * s + (s - q) / 2, j * s + (s - q) / 2, q, q)

static func _flame(c: Canvas2D, y: float, hgt: float, len: float, col) -> void:
	c.fillStyle = col
	c.beginPath()
	c.moveTo(-4, y)
	c.quadraticCurveTo(len * 0.45, y - hgt * 0.25, len * 0.62, y + hgt * 0.18)
	c.quadraticCurveTo(len * 0.8, y + hgt * 0.5, len, y + hgt * 0.22)
	c.quadraticCurveTo(len * 0.86, y + hgt * 0.78, len * 0.6, y + hgt * 0.7)
	c.quadraticCurveTo(len * 0.35, y + hgt * 0.62, -4, y + hgt)
	c.closePath()
	c.fill()

## flames from the front wheel backwards: c2 outside, c1 inside
static func _flames(c: Canvas2D, w: float, h: float, c1: Color, c2: Color) -> void:
	var T := [[0.0, 0.36, 0.74], [0.2, 0.34, 0.97], [0.44, 0.32, 0.68], [0.62, 0.38, 0.9]]
	c.fillStyle = c2
	c.fillRect(0, 0, w * 0.1, h)
	for t in T: _flame(c, h * t[0], h * t[1], w * t[2], c2)
	c.fillStyle = c1
	c.fillRect(0, h * 0.08, w * 0.07, h * 0.84)
	for t in T: _flame(c, h * (t[0] + t[1] * 0.2), h * t[1] * 0.6, w * t[2] * 0.8, c1)

## red, white and blue sweeping up from a point at the front
static func _flag(c: Canvas2D, w: float, h: float) -> void:
	var cols := [NL_RED, WHITE, NL_BLUE]
	var mid := func(x: float) -> float: return h * (0.56 - 0.1 * sin(x / w * PI * 1.4) - 0.1 * x / w)
	var th := func(x: float) -> float: return h * 0.24 * clampf((x / w - 0.04) / 0.5, 0.0, 1.0)
	for k in 3:
		var top: Array = []
		var bot: Array = []
		for i in 33:
			var x := w * (0.04 + 0.95 * i / 32.0)
			var m: float = mid.call(x)
			var t: float = th.call(x)
			top.append([x, m + (k - 1.5) * t])
			bot.append([x, m + (k - 0.5) * t + 0.5])
		bot.reverse()
		_poly(c, top + bot, cols[k])

static func _tulip(c: Canvas2D, x: float, y: float, r: float, col) -> void:
	c.fillStyle = col
	c.beginPath()
	c.moveTo(x - r, y - r * 0.9)
	c.lineTo(x - r * 0.45, y - r * 0.3)
	c.lineTo(x, y - r * 1.1)
	c.lineTo(x + r * 0.45, y - r * 0.3)
	c.lineTo(x + r, y - r * 0.9)
	c.quadraticCurveTo(x + r * 1.1, y + r * 1.2, x, y + r * 1.25)
	c.quadraticCurveTo(x - r * 1.1, y + r * 1.2, x - r, y - r * 0.9)
	c.closePath()
	c.fill()

static func _leaf(c: Canvas2D, x: float, y: float, dx: float, dy: float, col) -> void:
	c.fillStyle = col
	c.beginPath()
	c.moveTo(x, y)
	c.quadraticCurveTo(x + dx * 0.2, y - dy * 0.7, x + dx, y - dy)
	c.quadraticCurveTo(x + dx * 0.9, y - dy * 0.2, x, y)
	c.closePath()
	c.fill()

## a row of tulips growing from the sill
static func _tulips(c: Canvas2D, w: float, h: float) -> void:
	var cols := ["#d62a2a", "#f2c200", "#ff4f8b", "#f36f21", WHITE, "#7a2fbf"]
	var n := 11
	for i in n:
		var x := w * (0.06 + 0.88 * i / (n - 1.0))
		var top := h * (0.3 + 0.16 * ((i * 5) % 4) / 3.0)
		var r := h * 0.115
		c.fillStyle = "#2f8f5b"
		c.fillRect(x - 2.5, top, 5, h - top)
		_leaf(c, x, h * 0.98, -h * 0.2, h * 0.42, "#3fa066")
		_leaf(c, x, h * 0.98, h * 0.2, h * 0.36, "#2f8f5b")
		_tulip(c, x, top, r, cols[i % cols.size()])

## three Delft blue tiles: a tulip, a windmill and a sailing boat
static func _delft(c: Canvas2D, w: float, h: float) -> void:
	var T := h - 20.0
	var x0 := (w - 3 * T - 16.0) / 2
	for k in 3:
		var x := x0 + k * (T + 8.0)
		var y := 10.0
		c.fillStyle = WHITE
		c.fillRect(x, y, T, T)
		c.strokeStyle = DELFT; c.lineWidth = 3
		c.strokeRect(x + 4, y + 4, T - 8, T - 8)
		for cr in [[x + 4, y + 4, 0.0], [x + T - 4, y + 4, PI / 2], [x + T - 4, y + T - 4, PI], [x + 4, y + T - 4, PI * 1.5]]:
			c.fillStyle = DELFT
			c.beginPath(); c.moveTo(cr[0], cr[1]); c.arc(cr[0], cr[1], T * 0.16, cr[2], cr[2] + PI / 2); c.closePath(); c.fill()
		var cx := x + T / 2
		var by := y + T - 22
		c.fillStyle = DELFT
		c.fillRect(x + 22, by, T - 44, 3)
		if k == 0:
			c.fillRect(cx - 2, by - 52, 4, 52)
			_leaf(c, cx, by, -22, 40, DELFT)
			_leaf(c, cx, by, 22, 34, DELFT)
			_tulip(c, cx, by - 58, 15, DELFT)
		elif k == 1:
			_poly(c, [[cx - 15, by], [cx + 15, by], [cx + 8, by - 44], [cx - 8, by - 44]], DELFT)
			_poly(c, [[cx - 11, by - 44], [cx + 11, by - 44], [cx, by - 58]], DELFT)
			for a in 4:
				c.save()
				c.translate(cx, by - 50)
				c.rotate(0.5 + a * PI / 2)
				c.fillStyle = DELFT
				c.fillRect(-1.5, -40, 3, 40)
				c.fillRect(1.5, -40, 9, 26)
				c.restore()
		else:
			_poly(c, [[cx - 30, by - 16], [cx + 30, by - 16], [cx + 20, by - 2], [cx - 22, by - 2]], DELFT)
			c.fillRect(cx - 2, by - 74, 3, 58)
			_poly(c, [[cx + 4, by - 72], [cx + 4, by - 22], [cx + 30, by - 22]], DELFT)
			_poly(c, [[cx - 5, by - 64], [cx - 5, by - 22], [cx - 26, by - 22]], DELFT)

## a lion rampant in c1 (tongue and claws c2) between speed lines
static func _lion(c: Canvas2D, w: float, h: float, c1: Color, c2: Color) -> void:
	var cx := w * 0.5
	var cy := h * 0.52
	var s := h / 144.0
	for i in 3:
		var y := h * (0.3 + i * 0.2)
		_poly(c, [[w * 0.06 + i * 14, y], [cx - 70 * s, y], [cx - 70 * s, y + 9 * s], [w * 0.06 + i * 14 + 16, y + 9 * s]], c1)
		_poly(c, [[cx + 74 * s, y], [w * 0.95 - i * 14, y], [w * 0.95 - i * 14 - 16, y + 9 * s], [cx + 74 * s, y + 9 * s]], c1)
	c.save()
	c.translate(cx, cy)
	c.scale(s, s)
	# tail: an S behind the back with a tuft
	c.strokeStyle = c1; c.lineWidth = 6
	c.beginPath(); c.moveTo(30, 24); c.quadraticCurveTo(62, 14, 50, -14); c.quadraticCurveTo(40, -38, 58, -52); c.stroke()
	c.fillStyle = c1
	c.beginPath(); c.ellipse(60, -56, 8, 12, 0.5, 0, TAU); c.fill()
	# hind legs
	_poly(c, [[2, 26], [24, 20], [30, 44], [14, 60], [26, 64], [26, 70], [0, 70], [8, 48]], c1)
	_poly(c, [[20, 24], [38, 30], [46, 50], [40, 64], [52, 66], [52, 72], [28, 72], [32, 52], [22, 40]], c1)
	# body, leaning forward
	c.beginPath(); c.ellipse(8, 4, 20, 36, 0.42, 0, TAU); c.fill()
	# front legs, raised
	_poly(c, [[-14, -12], [-44, -22], [-56, -34], [-50, -40], [-38, -30], [-10, -24]], c1)
	_poly(c, [[-8, 2], [-40, 4], [-56, -6], [-52, -14], [-36, -6], [-6, -10]], c1)
	# mane and head
	for a in 9:
		var an := -0.4 + a * 0.62
		_poly(c, [[-12 + cos(an) * 14, -30 + sin(an) * 14], [-12 + cos(an + 0.5) * 14, -30 + sin(an + 0.5) * 14], [-12 + cos(an + 0.25) * 27, -30 + sin(an + 0.25) * 27]], c1)
	_disc(c, -12, -30, 19, c1)
	_disc(c, -26, -42, 13, c1)
	_poly(c, [[-36, -46], [-46, -40], [-44, -32], [-30, -32]], c1)
	_poly(c, [[-24, -56], [-18, -66], [-14, -52]], c1)
	# crown
	_poly(c, [[-38, -58], [-40, -72], [-33, -64], [-28, -74], [-23, -64], [-16, -70], [-17, -56]], c1)
	# tongue and claws
	_poly(c, [[-44, -36], [-54, -30], [-46, -31]], c2)
	for p in [[-56, -37], [-56, -10], [0, 70], [28, 72]]:
		_poly(c, [[p[0], p[1] - 3], [p[0] - 8, p[1]], [p[0], p[1] + 3]], c2)
	c.restore()

# ------------------------------------------------------------------ stickers (256 x 128, twice as wide as high)
static func sticker(id: String) -> ImageTexture:
	return Canvas2D.tex(256, 128, func(c, w, h): _sticker(c, id, w, h))

static func _sticker(c: Canvas2D, id: String, w: float, h: float) -> void:
	match id:
		"polder":
			_badge(c, w, h, DELFT, WHITE)
			_txt(c, "POLDERRACE", w / 2.0, h / 2.0 + 4, 'italic 800 56px "Barlow Condensed"', WHITE, 216)
		"delta":
			_badge(c, w, h, "#0f2a5c", "#f36f21")
			_poly(c, [[50, 96], [82, 30], [114, 96]], "#f36f21")
			_poly(c, [[66, 86], [82, 52], [98, 86]], "#0f2a5c")
			_txt(c, "TEAM", 176, 48, 'italic 800 38px "Barlow Condensed"', WHITE, 110)
			_txt(c, "DELTA", 176, 86, 'italic 800 44px "Barlow Condensed"', "#f36f21", 110)
		"tulp":
			_badge(c, w, h, WHITE, "#d62a2a")
			c.fillStyle = "#2f8f5b"; c.fillRect(126, 58, 5, 52)
			_leaf(c, 128, 108, -34, 44, "#3fa066"); _leaf(c, 128, 108, 34, 38, "#2f8f5b")
			_tulip(c, 128, 48, 24, "#d62a2a")
		"molen":
			_badge(c, w, h, "#8fc3ea", WHITE)
			c.fillStyle = "#2f8f5b"; c.fillRect(8, 98, w - 16, 22)
			_poly(c, [[108, 104], [148, 104], [140, 52], [116, 52]], "#7a3b20")
			_poly(c, [[112, 52], [144, 52], [128, 36]], INK)
			for a in 4:
				c.save(); c.translate(128, 46); c.rotate(0.45 + a * PI / 2)
				c.fillStyle = INK; c.fillRect(-2, -44, 4, 44)
				c.fillStyle = WHITE; c.fillRect(2, -44, 12, 30)
				c.restore()
		"kaas":
			_badge(c, w, h, "#d62a2a", "#f2c200")
			_poly(c, [[52, 92], [204, 92], [204, 62], [112, 34], [52, 70]], "#f2c200")
			_poly(c, [[52, 70], [204, 62], [204, 92], [52, 92]], "#f7d84a")
			for q in [[92, 80, 7], [128, 76, 9], [168, 80, 6], [150, 54, 5], [112, 54, 4]]: _disc(c, q[0], q[1], q[2], "#d9a21b")
		"vlag":
			_badge(c, w, h, WHITE, WHITE)
			c.fillStyle = NL_RED; c.fillRect(14, 14, w - 28, 34)
			c.fillStyle = WHITE; c.fillRect(14, 48, w - 28, 32)
			c.fillStyle = NL_BLUE; c.fillRect(14, 80, w - 28, 34)
		"hart":
			_badge(c, w, h, WHITE, INK)
			_txt(c, "I", 52, 70, '900 76px Nunito', INK, 40)
			_disc(c, 104, 54, 19, "#d62a2a"); _disc(c, 136, 54, 19, "#d62a2a")
			_poly(c, [[87, 63], [153, 63], [120, 104]], "#d62a2a")
			_txt(c, "NL", 198, 70, '900 62px Nunito', INK, 76)
		"wafel":
			_badge(c, w, h, "#5b3a1e", "#e0a858")
			_disc(c, 70, 64, 44, "#c98a3c"); _disc(c, 70, 64, 39, "#e0a858")
			c.strokeStyle = "#b9762c"; c.lineWidth = 2.5
			for i in range(-3, 4):
				var d := i * 11.0
				var e := sqrt(maxf(0.0, 37.0 * 37.0 - d * d)) * 0.7071
				c.beginPath(); c.moveTo(70 + d * 0.7071 - e, 64 + d * 0.7071 + e); c.lineTo(70 + d * 0.7071 + e, 64 + d * 0.7071 - e); c.stroke()
				c.beginPath(); c.moveTo(70 - d * 0.7071 - e, 64 + d * 0.7071 - e); c.lineTo(70 - d * 0.7071 + e, 64 + d * 0.7071 + e); c.stroke()
			_txt(c, "STROOP", 180, 46, 'italic 800 34px "Barlow Condensed"', "#e0a858", 116)
			_txt(c, "WAFEL", 180, 84, 'italic 800 40px "Barlow Condensed"', WHITE, 116)
		"turbo":
			_badge(c, w, h, INK, "#f2c200")
			_poly(c, [[66, 14], [34, 70], [56, 70], [44, 114], [86, 52], [62, 52], [78, 14]], "#f2c200")
			_txt(c, "TURBO", 166, 68, 'italic 800 60px "Barlow Condensed"', "#f2c200", 136)
		"kroon":
			_badge(c, w, h, "#f36f21", WHITE)
			_poly(c, [[38, 92], [30, 38], [54, 66], [72, 30], [90, 66], [114, 38], [106, 92]], WHITE)
			c.fillStyle = WHITE; c.fillRect(38, 96, 68, 10)
			_txt(c, "ORANJE", 182, 68, 'italic 800 46px "Barlow Condensed"', WHITE, 124)
		"finish":
			_badge(c, w, h, INK, WHITE)
			var s := 20.0
			for i in 11:
				for j in 5:
					if (i + j) % 2 == 0:
						c.fillStyle = WHITE; c.fillRect(18 + i * s, 14 + j * s, s, s)
		"cup":
			_badge(c, w, h, DELFT, "#f2c200")
			_poly(c, [[34, 26], [94, 26], [88, 62], [72, 76], [72, 92], [86, 92], [86, 102], [42, 102], [42, 92], [56, 92], [56, 76], [40, 62]], "#f2c200")
			_txt(c, "POLDER", 176, 48, 'italic 800 38px "Barlow Condensed"', WHITE, 124)
			_txt(c, "CUP", 176, 88, 'italic 800 50px "Barlow Condensed"', "#f2c200", 124)
		"patat":
			_badge(c, w, h, "#f2c200", "#d62a2a")
			for f in [[52, 20, -0.2], [64, 14, -0.05], [76, 18, 0.1], [88, 24, 0.24], [58, 30, 0.0], [72, 28, 0.05]]:
				c.save(); c.translate(f[0], f[1]); c.rotate(f[2])
				c.fillStyle = "#e9b93a"; c.fillRect(-4, 0, 9, 50)
				c.restore()
			_poly(c, [[40, 54], [102, 54], [80, 114], [62, 114]], WHITE)
			_poly(c, [[40, 54], [102, 54], [98, 66], [44, 66]], "#d62a2a")
			_txt(c, "PATAT", 180, 46, 'italic 800 42px "Barlow Condensed"', INK, 124)
			_txt(c, "MET!", 180, 88, 'italic 800 46px "Barlow Condensed"', "#d62a2a", 124)
		"legende":
			_badge(c, w, h, INK, "#c9a227")
			for sd in [-1.0, 1.0]:
				for i in 7:
					var a := 0.5 + i * 0.36
					c.save(); c.translate(128 + sd * cos(a) * 100, 70 - sin(a) * 38 + 8); c.rotate(-sd * (a + 0.6))
					c.fillStyle = "#c9a227"; c.beginPath(); c.ellipse(0, 0, 13, 5, 0, 0, TAU); c.fill()
					c.restore()
			_txt(c, "LEGENDE", w / 2.0, 66, 'italic 800 46px "Barlow Condensed"', "#c9a227", 150)

## a sticker's rounded plate with an edge
static func _badge(c: Canvas2D, w: float, h: float, bg, edge) -> void:
	_rrect(c, 2, 2, w - 4, h - 4, 18, edge)
	_rrect(c, 8, 8, w - 16, h - 16, 13, bg)

static func _rrect(c: Canvas2D, x: float, y: float, w: float, h: float, r: float, col) -> void:
	c.fillStyle = col
	c.beginPath()
	c.moveTo(x + r, y)
	c.lineTo(x + w - r, y); c.quadraticCurveTo(x + w, y, x + w, y + r)
	c.lineTo(x + w, y + h - r); c.quadraticCurveTo(x + w, y + h, x + w - r, y + h)
	c.lineTo(x + r, y + h); c.quadraticCurveTo(x, y + h, x, y + h - r)
	c.lineTo(x, y + r); c.quadraticCurveTo(x, y, x + r, y)
	c.closePath()
	c.fill()

static func _txt(c: Canvas2D, t: String, x: float, y: float, font: String, col, max_w := -1.0) -> void:
	c.fillStyle = col
	c.font = font
	c.textAlign = "center"
	c.textBaseline = "middle"
	c.fillText(t, x, y, max_w)

# ------------------------------------------------------------------ start numbers (256 x 256)
## style: disc, square, ring, plain. The number on the roof is a disc cut from the middle (90 %) of the picture.
static func number(n: int, style: String, font: String, bg: Color, fg: Color) -> ImageTexture:
	return Canvas2D.tex(256, 256, func(c, _w, _h): _number(c, n, style, font, bg, fg))

static func _number(c: Canvas2D, n: int, style: String, font: String, bg: Color, fg: Color) -> void:
	match style:
		"disc":
			_disc(c, 128, 128, 120, bg)
		"square":
			_rrect(c, 8, 8, 240, 240, 26, bg)
		"ring":
			_disc(c, 128, 128, 120, bg)
			c.cmds.append({"t": "clear", "polys": [_circle(128, 128, 102)]})
	var f := 'italic 800 156px "Barlow Condensed"'
	var y := 140.0
	if font == "block":
		f = '700 150px "Barlow Condensed"'; y = 138.0
	elif font == "round":
		f = '900 128px Nunito'; y = 132.0
	_txt(c, str(n), 128, y, f, fg, 176 if style != "plain" else 236)

static func _circle(x: float, y: float, r: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 48: p.append(Vector2(x + cos(i / 48.0 * TAU) * r, y + sin(i / 48.0 * TAU) * r))
	return p

# ------------------------------------------------------------------ number plates (256 x 64)
const PLATES := {"nl": ["#f2c200", INK, true], "old": ["#1c2c6b", WHITE, false], "black": ["#15171b", WHITE, false], "white": ["#f2f2ee", INK, true]}

static func plateWait(style: String) -> Color:
	return Color(PLATES.get(style, PLATES.nl)[0])

static func plate(text: String, style: String) -> ImageTexture:
	var p: Array = PLATES.get(style, PLATES.nl)
	return Canvas2D.tex(256, 64, func(c, w, h):
		c.fillStyle = p[0]; c.fillRect(0, 0, w, h)
		var strip := 28.0 if p[2] else 0.0
		if p[2]:
			c.fillStyle = "#1d3f9e"; c.fillRect(0, 0, strip, h)
		_txt(c, text, w / 2.0 + strip / 2, h / 2.0 + 2, '800 44px "Barlow Condensed"', p[1], w - strip - 20)
		c.strokeStyle = p[1]; c.lineWidth = 4
		c.strokeRect(2, 2, w - 4, h - 4))

# ------------------------------------------------------------------ the band across the windscreen (512 x 64)
static func banner(text: String, bg: Color) -> ImageTexture:
	return Canvas2D.tex(512, 64, func(c, w, h):
		c.fillStyle = bg; c.fillRect(0, 0, w, h)
		_txt(c, text, w / 2.0, h / 2.0 + 3, 'italic 800 54px "Barlow Condensed"', INK if bg.get_luminance() > 0.55 else WHITE, w - 40))

# ------------------------------------------------------------------ tyre walls
## the tyre is a lathe: u runs round the wheel, v across it. In the picture the outer wall is the top 29 % (row 0 at the
## rim, the shoulder below it), then the tread, then the inner wall. kind: white, red, letter, yellow.
## The lettering is a word that reads the same mirrored (the wheels on one side of the car are mirrored).
static func tyre(kind: String) -> ImageTexture:
	return Canvas2D.tex(1024, 256, func(c, w, h): _tyre(c, kind, w, h))

static func _tyre(c: Canvas2D, kind: String, w: float, h: float) -> void:
	c.fillStyle = "#1b1b1b"; c.fillRect(0, 0, w, h)
	match kind:
		"white":
			c.fillStyle = "#e9e6dc"; c.fillRect(0, 9, w, 30)
		"red":
			c.fillStyle = "#d62a2a"; c.fillRect(0, 26, w, 9)
		_:
			var col := "#f2c200" if kind == "yellow" else "#e9e6dc"
			for k in 4:
				c.save()
				c.translate(w * (k + 0.5) / 4.0, 37)
				c.rotate(PI)
				c.scale(1.5, 1.0)
				_txt(c, "OTTO", 0, 0, '700 58px "Barlow Condensed"', col)
				c.restore()
				c.fillStyle = col
				c.fillRect(w * k / 4.0 - 14, 30, 28, 7)

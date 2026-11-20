class_name CarLamps
## The lamps of every car and traffic vehicle: one canvas-drawn atlas (headlights, tail lights, grilles, indicators) with an
## emission map, and the shared materials that switch them on.
##
## A lamp is a patch on the skin (CarKit.patch) whose uv is moved into one cell of the atlas (CarKit.uvCell). All front lamps
## and grilles of a car are one mesh with `head`; all rear lamps one mesh that takes one of four materials:
##   tail (off by day, glowing at dusk/night), brake (bright), rev (tail + white reversing lamps), brakeRev.
## CarKit.setLights(m, brake, reverse) swaps the material: no extra meshes, no material per car.
## Env switches the lamps on at dusk, at night and in rain or fog through CarKit.applyEnv -> CarLamps.applyEnv.

const COLS := 4
const ROWS := 8
const CW := 128
const CH := 64
## cell name -> [column, row]
const CELLS := {
	"h_rect": [0, 0], "h_round": [1, 0], "h_slim": [2, 0], "h_quad": [3, 0],
	"h_fog": [0, 1], "h_pod": [1, 1], "h_led": [2, 1], "drl": [3, 1],
	"t_block": [0, 2], "t_bar": [1, 2], "t_round": [2, 2], "t_slats": [3, 2],
	"t_full": [0, 3], "t_wide": [1, 3], "amber": [2, 3], "white": [3, 3],
	"g_mesh": [0, 4], "g_slats": [1, 4], "g_vent": [2, 4], "dark": [3, 4],
	"red": [0, 5], "rev": [1, 5], "chmsl": [2, 5], "t_van": [3, 5],
	"h_van": [0, 6], "g_truck": [1, 6], "refl": [2, 6], "t_tri": [3, 6],
	"t_slats3": [0, 7],
}

## tail-lamp cells that hold a reversing lamp (white only in the reversing map); every car needs one (tests/test_cars.gd)
const REV_CELLS := ["t_block", "t_round", "t_wide", "t_van", "t_bar", "t_full", "t_slats3", "t_tri", "rev"]

static var head: LMat = null
static var tail: LMat = null
static var brake: LMat = null
static var rev: LMat = null
static var brakeRev: LMat = null
static var _tex: Array = []   ## albedo, emission, emission with the reversing lamps

## uv rectangle of a cell (a little inside its edge, so neighbours never bleed in)
static func cell(name: String) -> Rect2:
	var c: Array = CELLS.get(name, CELLS.dark)
	var w := 1.0 / COLS
	var h := 1.0 / ROWS
	return Rect2((c[0] + 0.04) * w, (c[1] + 0.06) * h, w * 0.92, h * 0.88)

## the atlas cell under a uv of a lamp mesh ("" = none)
static func cellAt(uv: Vector2) -> String:
	var c := Vector2i(int(floor(uv.x * COLS)), int(floor(uv.y * ROWS)))   # the mesh uv runs top-down like the canvas
	for k in CELLS:
		if CELLS[k][0] == c.x and CELLS[k][1] == c.y: return k
	return ""

static func ensure() -> void:
	if head != null: return
	for layer in 3:
		_tex.append(Canvas2D.tex(COLS * CW, ROWS * CH, func(c, _w, _h): _draw(c, layer)))
	var mk := func(emap: int, e: int, k: float) -> LMat:
		var m := Mats.M(0xffffff, {"map": _tex[0], "emissiveMap": _tex[emap], "emissive": e, "receiveShadow": false})
		m.emission_energy_multiplier = k
		return m
	head = mk.call(1, 0x807860, 1.0)
	tail = mk.call(1, 0xc81d1d, 1.0)
	brake = mk.call(1, 0xff4030, 3.4)
	rev = mk.call(2, 0xc8c8c8, 1.0)
	brakeRev = mk.call(2, 0xffffff, 3.4)

## lamps on at dusk/night/rain/fog (JS applyEnv, the car part)
static func applyEnv(t: String, lamps: bool) -> void:
	ensure()
	# the emission colours are the old game's (the garage sets them too); the atlas' emission map scales them per part
	head.emission_enabled = true
	head.emission = MathX.col(0xfff0c0 if t == "night" else (0xd8ccaa if lamps else 0x807860))
	tail.emission_enabled = true
	tail.emission = MathX.col(0xff3a30 if t == "night" else 0xc81d1d)
	rev.emission = MathX.col(0xffffff if t == "night" else 0xc8c8c8)

# ---------------------------------------------------------------- drawing

## fill for this layer: albedo a, glow e (emission map; "" = none), glow with the reversing lamps on r (default e)
static func _col(c, layer: int, a: String, e := "", r := "~") -> bool:
	var s: String = a if layer == 0 else (e if layer == 1 else (e if r == "~" else r))
	if s == "":
		return false
	c.fillStyle = s
	return true

static var _red := false

static func _rect(c, layer: int, x: float, y: float, w: float, h: float, a: String, e := "", r := "~") -> void:
	if _col(c, layer, a, e, r): c.fillRect(x, y, w, h)

static func _ell(c, layer: int, x: float, y: float, rx: float, ry: float, a: String, e := "", r := "~") -> void:
	if _col(c, layer, a, e, r):
		c.beginPath(); c.ellipse(x, y, rx, ry, 0, 0, TAU); c.fill()

## a round lamp: chrome ring, reflector, lens, hot centre
static func _lamp(c, layer: int, x: float, y: float, rx: float, ry: float, lens := "#e4ebef", glow := "#fff6dc") -> void:
	_ell(c, layer, x, y, rx, ry, "#c2c7cc", "#3a3833")
	_ell(c, layer, x, y, rx * 0.84, ry * 0.84, "#8f979e", "#8a8474")
	_ell(c, layer, x, y, rx * 0.66, ry * 0.66, lens, glow)
	_ell(c, layer, x - rx * 0.16, y - ry * 0.2, rx * 0.2, ry * 0.2, "#ffffff", "#ffffff")

static func _draw(c, layer: int) -> void:
	c.fillStyle = "#0b0c0e" if layer == 0 else "#000000"
	c.fillRect(0, 0, COLS * CW, ROWS * CH)
	var HOUSE := "#101216"
	var RED := "#b41a18"
	var REDG := "#ff3324"   # glow of a red lens (white in the emission map of tail/brake: their emission colour is red)
	var cellf := func(name: String, fn: Callable) -> void:
		var p: Array = CELLS[name]
		c.save(); c.translate(p[0] * CW, p[1] * CH)
		fn.call()
		c.restore()
	# the red glow: in the plain emission map the lens is white (the material's emission colour makes it red); in the
	# reversing map the material glows white, so there the lens carries the red itself
	var rg := "#666666" if layer == 1 else "#660f0f"
	# ---- headlights
	cellf.call("h_rect", func():
		_rect(c, layer, 0, 0, CW, CH, HOUSE)
		_lamp(c, layer, 30, 27, 22, 20)
		_lamp(c, layer, 72, 27, 18, 17)
		_rect(c, layer, 6, 51, 92, 7, "#eef2f4", "#ffffff")
		_rect(c, layer, 102, 8, 20, 50, "#d98a1c", "#3a2206"))
	cellf.call("h_round", func():
		_rect(c, layer, 0, 0, CW, CH, "#c2c7cc", "#2a2824")
		_lamp(c, layer, 64, 32, 62, 31)
		for k in 5:
			_rect(c, layer, 22 + k * 20, 6, 2, 52, "#aab2b8", ""))
	cellf.call("h_slim", func():
		_rect(c, layer, 0, 0, CW, CH, HOUSE)
		for k in 4:
			_rect(c, layer, 8 + k * 24, 10, 18, 26, "#8f979e", "#8a8474")
			_rect(c, layer, 11 + k * 24, 14, 12, 18, "#e8eef2", "#fff6dc")
		_rect(c, layer, 6, 46, 116, 8, "#eef2f4", "#ffffff"))
	cellf.call("h_quad", func():
		_rect(c, layer, 0, 0, CW, CH, HOUSE)
		_lamp(c, layer, 33, 32, 29, 29)
		_lamp(c, layer, 95, 32, 29, 29))
	cellf.call("h_fog", func():
		_rect(c, layer, 0, 0, CW, CH, HOUSE)
		_lamp(c, layer, 64, 32, 58, 29, "#f1ecd2", "#ffefb0"))
	cellf.call("h_pod", func():
		_rect(c, layer, 0, 0, CW, CH, "#1a1c20")
		_lamp(c, layer, 64, 32, 62, 31, "#eef3f5", "#ffffff")
		_rect(c, layer, 0, 30, CW, 4, "#30343a", ""); _rect(c, layer, 62, 0, 4, CH, "#30343a", ""))
	cellf.call("h_led", func():
		_rect(c, layer, 0, 0, CW, CH, HOUSE)
		for k in 3:
			_rect(c, layer, 10 + k * 38, 12, 30, 22, "#8f979e", "#8a8474")
			_rect(c, layer, 15 + k * 38, 16, 20, 14, "#eaf0f4", "#ffffff")
		_rect(c, layer, 8, 44, 112, 9, "#eef2f4", "#ffffff"))
	cellf.call("drl", func():
		_rect(c, layer, 0, 0, CW, CH, "#eef2f4", "#ffffff"))
	cellf.call("h_van", func():
		_rect(c, layer, 0, 0, CW, CH, "#2a2d33")
		_rect(c, layer, 6, 6, 84, 52, "#8f979e", "#6a665a")
		_rect(c, layer, 12, 11, 72, 42, "#e4ebef", "#fff6dc")
		_rect(c, layer, 96, 6, 26, 52, "#d98a1c", "#3a2206"))
	# ---- tail lights (the reversing lamp only glows in the reversing map)
	_red = true
	cellf.call("t_block", func():
		_rect(c, layer, 0, 0, CW, CH, "#3c0a0a")
		_rect(c, layer, 43, 5, 80, 54, RED, rg)
		for k in 4:
			_rect(c, layer, 43, 15 + k * 12, 80, 2, "#7a1010", "")
		_rect(c, layer, 23, 5, 17, 54, "#d98a1c", "#2a1804", "#2a1804")
		_rect(c, layer, 5, 5, 15, 54, "#dfe3e6", "", "#ffffff"))
	cellf.call("t_bar", func():
		_rect(c, layer, 0, 0, CW, CH, "#1c0606")
		_rect(c, layer, 0, 18, CW, 28, RED, rg)
		_rect(c, layer, 0, 28, CW, 8, "#e03a2c", rg)
		_rect(c, layer, 52, 20, 24, 24, "#dfe3e6", "#000000", "#ffffff"))   # reversing lamp in the middle of the bar
	cellf.call("t_round", func():
		_rect(c, layer, 0, 0, CW, CH, HOUSE)
		for q in [[34, 28], [94, 28]]:
			_ell(c, layer, q[0], 32, q[1], q[1], "#55585e", "")
			_ell(c, layer, q[0], 32, q[1] * 0.86, q[1] * 0.86, RED, rg)
			_ell(c, layer, q[0], 32, q[1] * 0.42, q[1] * 0.42, "#7a1010", "")
		_ell(c, layer, 94, 32, 9, 9, "#c9a7a4", "", "#ffffff"))
	cellf.call("t_slats", func():
		_rect(c, layer, 0, 0, CW, CH, "#c2c7cc", "")
		for k in 3:
			_rect(c, layer, 5 + k * 41, 5, 36, 54, RED, rg)
			_rect(c, layer, 5 + k * 41, 30, 36, 3, "#7a1010", ""))
	cellf.call("t_slats3", func():   # three slats, the reversing lamp in the lower half of the middle one
		_rect(c, layer, 0, 0, CW, CH, "#c2c7cc", "")
		for k in 3:
			_rect(c, layer, 5 + k * 41, 5, 36, 54, RED, rg)
			_rect(c, layer, 5 + k * 41, 30, 36, 3, "#7a1010", "")
		_rect(c, layer, 46, 36, 36, 23, "#dfe3e6", "#000000", "#ffffff"))
	cellf.call("t_full", func():
		_rect(c, layer, 0, 0, CW, CH, "#1c0606")
		_rect(c, layer, 0, 14, CW, 36, RED, rg)
		_rect(c, layer, 0, 26, CW, 12, "#e84434", rg)
		_rect(c, layer, 50, 16, 28, 32, "#dfe3e6", "#000000", "#ffffff"))
	cellf.call("t_wide", func():
		_rect(c, layer, 0, 0, CW, CH, "#3c0a0a")
		_rect(c, layer, 32, 6, 92, 52, RED, rg)
		_rect(c, layer, 32, 28, 92, 8, "#e03a2c", rg)
		_rect(c, layer, 4, 6, 24, 52, "#dfe3e6", "", "#ffffff"))
	cellf.call("t_van", func():
		_rect(c, layer, 0, 0, CW, CH, "#2a0808")
		_rect(c, layer, 6, 4, 116, 22, RED, rg)
		_rect(c, layer, 6, 28, 116, 14, "#d98a1c", "#2a1804", "#2a1804")
		_rect(c, layer, 6, 44, 116, 16, "#dfe3e6", "", "#ffffff"))
	cellf.call("t_tri", func():
		_rect(c, layer, 0, 0, CW, CH, "#2a0808")
		_rect(c, layer, 5, 5, 38, 54, RED, rg)
		_rect(c, layer, 46, 5, 38, 54, "#d98a1c", "#2a1804", "#2a1804")
		_rect(c, layer, 87, 5, 36, 54, "#dfe3e6", "#000000", "#ffffff"))   # red | amber | reversing lamp (lorry clusters)
	cellf.call("red", func():
		_rect(c, layer, 0, 0, CW, CH, RED, rg))
	cellf.call("chmsl", func():
		_rect(c, layer, 0, 0, CW, CH, "#7a1010", rg))
	cellf.call("refl", func():
		_rect(c, layer, 0, 0, CW, CH, "#c2281e", "#401008", "#401008"))
	_red = false
	cellf.call("rev", func():
		_rect(c, layer, 0, 0, CW, CH, "#dfe3e6", "", "#ffffff"))
	cellf.call("amber", func():
		_rect(c, layer, 0, 0, CW, CH, "#e08a1a", "#4a2a06", "#4a2a06"))
	cellf.call("white", func():
		_rect(c, layer, 0, 0, CW, CH, "#eef2f0", "#fff6dc", ""))
	# ---- grilles (never glow)
	if layer == 0:
		cellf.call("g_mesh", func():
			c.fillStyle = "#08090a"; c.fillRect(0, 0, CW, CH)
			c.strokeStyle = "#2c3036"; c.lineWidth = 2.0
			for k in range(-4, 12):
				c.beginPath(); c.moveTo(k * 16, 0); c.lineTo(k * 16 + 64, CH); c.stroke()
				c.beginPath(); c.moveTo(k * 16 + 64, 0); c.lineTo(k * 16, CH); c.stroke())
		cellf.call("g_slats", func():
			c.fillStyle = "#08090a"; c.fillRect(0, 0, CW, CH)
			c.fillStyle = "#2a2e34"
			for k in 4:
				c.fillRect(0, 6 + k * 15, CW, 6))
		cellf.call("g_vent", func():
			c.fillStyle = "#101216"; c.fillRect(0, 0, CW, CH)
			c.fillStyle = "#050506"
			for k in 5:
				c.fillRect(6, 5 + k * 12, CW - 12, 6))
		cellf.call("g_truck", func():
			c.fillStyle = "#1a1c20"; c.fillRect(0, 0, CW, CH)
			c.fillStyle = "#c2c7cc"
			for k in 5:
				c.fillRect(8, 6 + k * 11, CW - 16, 4))

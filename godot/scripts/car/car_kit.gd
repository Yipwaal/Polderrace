class_name CarKit
## The car builder (started as a port of polderrace-3d.html, "cars" section): shared car materials, wheels, the headlight
## beam, parts on the skin (patch, discPatch, dressStd and the per-model dress functions), stock and tuned spoilers and
## exhausts (tuneParts), stripes, race numbers, carKit(type) (one body kit per model, built once) and buildCar(type, color).
##
## buildCar returns the rig, a Dictionary:
##   g (Node3D: the car), shell (Node3D under g: everything that is body; put extra parts here), wheels (Array of
##   {pivot, spin, r, w, style, mesh}: pivot steers (rotation.y), spin rolls (rotation.x); they hang under g, not the shell),
##   len, wid, rc (hitbox corner radius), off (hitbox offset along the car), type, wingY, wingZ, stockWing (meshes),
##   beam (the headlight pool, hidden), blob (contact shadow), kit (CarBody), paint (the car's CarPaint),
##   body, detail, glass, lamp, tail, plate, driver (MeshInstance3D or null), lights ({brake, rev}).
##   g.get_meta("exh").meshes = the stock exhaust meshes (hidden when a tuned exhaust is fitted).
##
## A car is a handful of meshes, one per material: paint (CarPaint, the colour and finish), detail (one CarPaint.detail for
## all cars: vertex colour, vertex alpha = shine; underside, trim, chrome, interior), glass, lamps (front), tail lamps, plates,
## driver, and one mesh per wheel. Lights: setLights(m, brake, reverse); lamps on with the weather: applyEnv().

const X90 := PI / 2
const TRIM := 0x15171a        ## black plastic
const LINER := 0x0f1012       ## underside, wheel wells
const CHROME := 0xd6dade
const RIM_SILVER := 0xa1a4a8

## colour with a shine in alpha, for the detail material (0 rubber .. 0.3 plastic .. 0.6 gloss .. 0.8 polished .. 1 chrome)
static func sc(hex: int, shine := 0.1) -> Color:
	return CarBody.sc(hex, shine)

## plain car materials: like Mats.M / Mats.PM / Mats.phong, but no shadows fall on them (a car would darken itself)
static func _M(c: int, o: Dictionary = {}) -> LMat:
	return Mats.M(c, _nr(o))

static func _PM(c: int, o: Dictionary = {}) -> LMat:
	return Mats.PM(c, _nr(o))

static func _phong(c: int, o: Dictionary = {}) -> LMat:
	return Mats.phong(c, _nr(o))

static func _nr(o: Dictionary) -> Dictionary:
	var oo := o.duplicate()
	oo["receiveShadow"] = false
	return oo

# ---------------------------------------------------------------- shared materials (never disposed)
## everything on a car that is not paint, glass or a lamp: vertex colour, vertex alpha = shine
static var detailMat: CarPaint = CarPaint.detail()
## see-through tinted glass (cabin, windscreens)
static var carGlass: CarPaint = CarPaint.glass(0x10171e, 0.5)
## the lamps (CarLamps): front lamps and grilles; tail lamps off/on, braking, reversing
static var lampMat: LMat = _lamps(0)
static var tailMat: LMat = _lamps(1)
static var brakeMat: LMat = _lamps(2)
static var revMat: LMat = _lamps(3)
static var brakeRevMat: LMat = _lamps(4)
## plain materials other scripts use (decor, traffic)
static var glassMat: LMat = _M(0x2c3a48)
static var plateMat: LMat = _M(0xf2c200)
static var blk: LMat = _M(0x1d1f24)
## car plate: Dutch yellow plate with the blue EU strip
static var carPlate: LMat = plateFor("PR-3D-01")
## soft headlight pool on the road in front of an AI car (made with the first beam)
static var beamMat: LMat = null
static var blobMat: LMat = null
static var lampsOn := false
## carUp(id): the garage entry (upgrades and looks) of a car. Gameplay sets it once the garage exists; without it a car
## gets the factory looks (Cars.default_up()). styleCar also takes such a Dictionary directly instead of an id.
static var up_of: Callable = Callable()

static var KITS := {}
static var WGEO := {}
static var PLATES := {}
static var _beamGeo: Geo = null
static var _beamTex: ImageTexture = null
static var _blobGeo: Geo = null
static var _ph: Array = []

static func _lamps(k: int) -> LMat:
	CarLamps.ensure()
	return [CarLamps.head, CarLamps.tail, CarLamps.brake, CarLamps.rev, CarLamps.brakeRev][k]

## the plate material for a text (cached): yellow, blue EU strip, black letters
static func plateFor(text: String) -> LMat:
	if PLATES.has(text):
		return PLATES[text]
	var m := _M(0xffffff, {"map": Canvas2D.tex(128, 32, func(c, w, h):
		c.fillStyle = "#f2c200"; c.fillRect(0, 0, w, h); c.fillStyle = "#1d3f9e"; c.fillRect(0, 0, 14, h); c.fillStyle = "#161a22"
		c.font = "800 22px Barlow Condensed"; c.textAlign = "center"; c.textBaseline = "middle"; c.fillText(text, w / 2.0 + 7, h / 2.0 + 1)
		c.strokeStyle = "#161a22"; c.lineWidth = 2; c.strokeRect(1, 1, w - 2, h - 2))})
	PLATES[text] = m
	return m

## give a car its own plate text (the texture is drawn at the next Canvas2D.flush)
static func setPlate(m: Dictionary, text: String) -> void:
	var o = m.get("plate", null)
	if o != null: o.set_surface_override_material(0, plateFor(text))

## the car part of Env.apply: lamps on at dusk/night/rain/fog, brighter lamp glass, tail lights, beam strength
static func applyEnv(t: String, lamps: bool) -> void:
	lampsOn = lamps
	if beamMat != null:
		var c := beamMat.albedo_color
		c.a = 0.7 if t == "night" else 0.35
		beamMat.albedo_color = c
	CarLamps.applyEnv(t, lamps)

## brake lights and reversing lamps of a car (any rig from buildCar or Vehicles): swaps the tail lamps' material
static func setLights(m: Dictionary, brake: bool, reverse := false) -> void:
	var o = m.get("tail", null)
	if o == null or not (o is MeshInstance3D): return
	var st = m.get("lights", null)
	if st != null:
		if st.brake == brake and st.rev == reverse: return
		st.brake = brake; st.rev = reverse
	o.set_surface_override_material(0, (brakeRevMat if reverse else brakeMat) if brake else (revMat if reverse else tailMat))

## brake lights from how the car slows down (bots, traffic, online players, the replay): call every frame with its speed.
## Lights up above about 3 m/s2 and stays on a moment, so it does not flicker; reversing lamps when it rolls backwards.
static func autoBrake(m: Dictionary, speed: float, dt: float) -> void:
	var st = m.get("lights", null)
	if st == null or dt <= 0.0: return
	var a: float = (speed - st.get("v", speed)) / dt
	st.v = speed
	st.a = st.get("a", 0.0) + (a - st.get("a", 0.0)) * minf(1.0, dt * 9.0)
	var hold: float = st.get("hold", 0.0) - dt
	if st.a < -3.0 and speed > 0.5: hold = 0.25
	st.hold = hold
	setLights(m, hold > 0.0, speed < -0.5)

static func setBrake(m: Dictionary, on: bool) -> void:
	var st = m.get("lights", null)
	setLights(m, on, st.rev if st != null else false)

## show or hide the driver (the garage shows an empty car)
static func setDriver(m: Dictionary, on: bool) -> void:
	var o = m.get("driver", null)
	if o != null: o.visible = on

static func _col(c) -> Color:
	if c is Color: return c
	if c is String: return Color(c)
	return MathX.col(int(c))

# ---------------------------------------------------------------- meshes (a Geo is turned into one shared ArrayMesh)

## the ArrayMesh of a Geo, built once. multi (a material array, like a three.js mesh with groups): one surface per geometry
## group material, the material index of each surface in meta "mi"; else one surface for all of it. The surfaces keep
## placeholder materials: every car mesh sets its own (surface override).
static func _amesh(geo: Geo, multi := false) -> ArrayMesh:
	var key := "amN" if multi else "am1"
	if geo.has_meta(key):
		return geo.get_meta(key)
	if _ph.is_empty():
		for _i in 8: _ph.append(StandardMaterial3D.new())
	var m: ArrayMesh
	var mi: Array = []
	if not multi or geo.groups.is_empty():
		var g1 := geo
		if not geo.groups.is_empty():
			g1 = geo.clone()
			g1.groups = []
		m = g1.to_mesh(_ph[0])
		mi = [0]
	else:
		m = geo.to_mesh(_ph)
		for s in m.get_surface_count():
			mi.append(_ph.find(m.surface_get_material(s)))
	geo.set_meta(key, m)
	geo.set_meta(key + "_mi", mi)
	return m

static func _set_mats(o: MeshInstance3D, mats) -> void:
	var mi: Array = (o.get_meta("geo") as Geo).get_meta(("amN" if mats is Array else "am1") + "_mi")
	for s in o.mesh.get_surface_count():
		o.set_surface_override_material(s, mats[mi[s]] if mats is Array else mats)

## a MeshInstance3D of geo (+ castShadow) added to parent; mats: a material or an array per geometry group
static func mesh(parent: Node, geo: Geo, mats, cast := false) -> MeshInstance3D:
	if geo == null:
		return null
	var o := MeshInstance3D.new()
	o.mesh = _amesh(geo, mats is Array)
	o.set_meta("geo", geo)
	_set_mats(o, mats)
	o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if parent != null:
		parent.add_child(o)
	return o

## swap the geometry of a mesh made by mesh()
static func set_geo(o: MeshInstance3D, geo: Geo) -> void:
	var mats := []
	for s in o.mesh.get_surface_count():
		mats.append(o.get_surface_override_material(s))
	o.mesh = _amesh(geo, mats.size() > 1)
	o.set_meta("geo", geo)
	for s in o.mesh.get_surface_count():
		o.set_surface_override_material(s, mats[mini(s, mats.size() - 1)])

## collects geometry from lofts (indexed, per material group) and accumulators into one mesh with vertex colours
class Mb:
	var P := PackedVector3Array()
	var Nn := PackedVector3Array()
	var Cc := PackedColorArray()
	var U := PackedVector2Array()
	var I := PackedInt32Array()

	## the triangles of material group mi of a loft, in colour col; flip: seen from inside (reversed, normals turned)
	func group(g: Geo, mi: int, col: Color, flip := false) -> void:
		var map := {}
		for gr in g.groups:
			if gr[2] != mi: continue
			for i in range(gr[0], gr[0] + gr[1], 3):
				for k in ([g.idx[i], g.idx[i + 2], g.idx[i + 1]] if flip else [g.idx[i], g.idx[i + 1], g.idx[i + 2]]):
					if not map.has(k):
						map[k] = P.size()
						P.append(g.pos[k]); Nn.append(-g.nrm[k] if flip else g.nrm[k]); Cc.append(col); U.append(Vector2.ZERO)
					I.append(map[k])

	## an accumulator (or a non-indexed Geo): its own vertex colours, or all in col; alpha >= 0 overrides the colours' alpha
	func acc(a, col = null, alpha := -1.0) -> void:
		if a == null: return
		var p: PackedVector3Array = a.P if a is CarAcc else a.pos
		var n: PackedVector3Array = a.N if a is CarAcc else a.nrm
		var c: PackedColorArray = a.C if a is CarAcc else a.col
		var u: PackedVector2Array = a.U if a is CarAcc else a.uv
		var base := P.size()
		P.append_array(p); Nn.append_array(n)
		for i in p.size():
			var k: Color = col if col != null else (c[i] if i < c.size() else Color.WHITE)
			if alpha >= 0: k.a = alpha
			Cc.append(k)
			U.append(u[i] if i < u.size() else Vector2.ZERO)
			I.append(base + i)

	func build() -> Geo:
		if P.is_empty(): return null
		var g := Geo.new()
		g.pos = P; g.nrm = Nn; g.col = Cc; g.uv = U; g.idx = I
		return g

## move the uv of what was added to A since vertex n0 into a cell of the lamp atlas (flat: all of it one point of the cell)
static func uvCell(A: CarAcc, n0: int, name: String, flat := false) -> void:
	var r := CarLamps.cell(name)
	for i in range(n0, A.U.size()):
		var u := A.U[i]
		if flat: u = Vector2(0.5, 0.5)
		A.U[i] = Vector2(r.position.x + clampf(u.x, 0.0, 1.0) * r.size.x, 1.0 - (r.position.y + (1.0 - clampf(u.y, 0.0, 1.0)) * r.size.y))

# ---------------------------------------------------------------- wheels
# one mesh per wheel (detail material): tyre (lathe with rounded shoulders), rim face recessed inside the sidewall, barrel,
# brake disc; the caliper sits on the pivot so it does not roll

static func wheelGeos(r: float, w: float, style: String, rimCol = null, shine := 0.72) -> Dictionary:
	var rc: Color = sc(RIM_SILVER, shine) if rimCol == null else _col(rimCol)
	rc.a = shine
	var key := "%.3f/%.3f/%s/%s/%.2f" % [r, w, style, rc.to_html(false), shine]
	if WGEO.has(key):
		return WGEO[key]
	var hw := w / 2.0
	var rb := r * (0.64 if style == "steel" else (0.58 if style == "tractor" else 0.7))
	var ro := r - (0.04 if style == "tractor" else 0.0)   # lugs stand on a tractor tyre
	var tyre := Geo.lathe([Vector2(rb, -hw + 0.018), Vector2(rb + 0.012, -hw + 0.004), Vector2(ro - 0.075, -hw), Vector2(ro - 0.03, -hw + 0.012),
		Vector2(ro - 0.008, -hw + 0.04), Vector2(ro, -hw + 0.075), Vector2(ro, hw - 0.075), Vector2(ro - 0.008, hw - 0.04), Vector2(ro - 0.03, hw - 0.012),
		Vector2(ro - 0.075, hw), Vector2(rb + 0.012, hw - 0.004), Vector2(rb, hw - 0.018)], 26)
	tyre.rotate_z(-PI / 2)
	var A := CarAcc.new()
	A.color(sc(0x161617, 0.07)).geo(tyre)
	var disc := func(rad: float, th: float, x: float, seg: int) -> void:
		var g := Geo.cylinder(rad, rad, th, seg); g.rotate_z(X90); g.translate(x, 0, 0); A.geo(g)
	var ringG := func(r0: float, r1: float, x: float) -> void:
		var g := Geo.ring(r0, r1, 28); g.rotate_y(X90); g.translate(x, 0, 0); A.geo(g)
	var spoke := func(a: float, len: float, wid: float, th: float, x: float, r0: float) -> void:
		var g := Geo.box(th, len, wid); g.translate(0, r0 + len / 2, 0); g.rotate_x(a); g.translate(x, 0, 0); A.geo(g)
	var face := hw - 0.03
	# barrel and back plate (dark), brake disc (steel) behind the spokes
	A.color(sc(0x1b1c1f, 0.15))
	var bg := Geo.cylinder(rb * 0.985, rb * 0.985, w - 0.05, 24, 1, true); bg.rotate_z(X90)
	for i in bg.nrm.size(): bg.nrm[i] = -bg.nrm[i]   # seen from inside the rim
	bg.idx = _flip(bg.idx)
	A.geo(bg)
	var bp := Geo.circle(rb * 0.985, 24); bp.rotate_y(X90); bp.translate(-hw + 0.03, 0, 0); A.geo(bp)
	if style == "tractor":
		# chevron lugs round the tyre
		A.color(sc(0x161617, 0.07))
		var nl := 22 if r > 0.7 else 16
		for k in nl:
			for sd in [1.0, -1.0]:
				var lh := 0.07
				var lg := Geo.box(hw * 0.98, lh, 0.05 + r * 0.045); lg.rotate_y(sd * 0.5); lg.translate(sd * hw * 0.48, r - lh / 2 - 0.002, 0)
				lg.rotate_x((k + (0.5 if sd > 0 else 0.0)) / nl * TAU); A.geo(lg)
	if style != "steel" and style != "tractor":
		A.color(sc(0x8f9297, 0.62)); disc.call(rb * 0.8, 0.024, face - 0.085, 24)
		A.color(sc(0x2a2c30, 0.4)); disc.call(rb * 0.34, 0.03, face - 0.05, 16)
	A.color(rc)
	if style == "steel" or style == "tractor":
		ringG.call(rb * 0.86, rb, face + 0.012); disc.call(rb * 0.86, 0.02, face - 0.03, 24)
		A.color(sc(0x3a3d42, 0.4)); disc.call(rb * 0.28, 0.05, face - 0.005, 14)
	else:
		# rim lip with some depth, then the spokes
		var lip := Geo.lathe([Vector2(rb, face + 0.014), Vector2(rb * 0.93, face + 0.014), Vector2(rb * 0.9, face - 0.006), Vector2(rb * 0.9, face - 0.05)], 28)
		lip.rotate_z(-PI / 2)
		A.geo(lip)
		if style == "spoke":
			for k in 10:
				spoke.call(k / 10.0 * PI * 2, rb * 0.68, 0.028, 0.022, face - 0.012, rb * 0.22)
			ringG.call(rb * 0.82, rb * 0.9, face - 0.002)
		elif style == "dish":
			ringG.call(rb * 0.6, rb * 0.9, face + 0.004)
			for k in 6:
				spoke.call(k / 6.0 * PI * 2, rb * 0.42, 0.07, 0.03, face - 0.045, rb * 0.2)
		else:
			for k in 5:
				var a := k / 5.0 * PI * 2
				spoke.call(a + 0.09, rb * 0.7, 0.045, 0.026, face - 0.012, rb * 0.2)
				spoke.call(a - 0.09, rb * 0.7, 0.045, 0.026, face - 0.012, rb * 0.2)
		disc.call(rb * 0.24, 0.05, face - 0.02, 18)
		# wheel nuts
		A.color(sc(0x2a2c30, 0.5))
		for k in 5:
			var a := (k + 0.5) / 5.0 * PI * 2
			var nut := Geo.cylinder(0.012, 0.012, 0.012, 6); nut.rotate_z(X90); nut.translate(face + 0.008, cos(a) * rb * 0.14, sin(a) * rb * 0.14); A.geo(nut)
	var o := {"all": A.build(), "rb": rb, "face": face}
	WGEO[key] = o
	return o

static func _flip(idx: PackedInt32Array) -> PackedInt32Array:
	var o := PackedInt32Array()
	for i in range(0, idx.size(), 3):
		o.append(idx[i]); o.append(idx[i + 2]); o.append(idx[i + 1])
	return o

static func _calGeo(rb: float, col) -> Geo:
	var c: Color = sc(0xc8302a, 0.5) if (col == null or col is String) else _col(col.albedo_color if col is LMat else col)
	c.a = 0.5
	var key := "cal/%.3f/%s" % [rb, c.to_html(false)]
	if not WGEO.has(key):
		WGEO[key] = CarAcc.new().color(c).geo(Geo.box(0.07, 0.1, rb * 0.55)).build()
	return WGEO[key]

## pivot (steers) > spin (rolls). Built for the right side; the spin group is mirrored on the left. The caliper sits on the
## pivot so it does not roll. cal: "default" = the red caliper, null = none (traffic), or a colour / material
static func addWheel(parent: Node3D, x: float, y: float, z: float, r: float, w: float, style := "std", cal = "default", rimCol = null) -> Dictionary:
	if style == "": style = "std"
	var G := wheelGeos(r, w, style, rimCol)
	var pivot := Node3D.new()
	pivot.position = Vector3(x, y, z)
	parent.add_child(pivot)
	var spin := Node3D.new()
	var side := MathX.sgn(x)
	if side == 0: side = 1
	spin.scale = Vector3(side, 1, 1)
	pivot.add_child(spin)
	var wm := mesh(spin, G.all, detailMat, true)
	wm.set_meta("rim", true)
	if cal != null and style != "steel" and style != "tractor":
		var c := mesh(null, _calGeo(G.rb, cal), detailMat)
		var a := 2.3 if z > 0 else 0.85
		var rb: float = G.rb
		c.position = Vector3(side * (G.face - 0.085), sin(a) * rb * 0.72, cos(a) * rb * 0.72)
		O3.rot(c, -a + PI / 2, 0, 0)
		c.visibility_range_end = 45.0
		pivot.add_child(c)
	return {"pivot": pivot, "spin": spin, "r": r, "w": w, "style": style, "mesh": wm}

## rim style and colour of a car's wheels (col: Color, hex int, or a material whose colour is taken); shine 0..1
static func setRims(m: Dictionary, style: String, col = null, shine := 0.72) -> void:
	if col is LMat: col = col.albedo_color
	for wh in m.wheels:
		if wh.style == "steel" or wh.style == "tractor": continue
		var G := wheelGeos(wh.r, wh.w, style, col, shine)
		wh.style = style
		set_geo(wh.mesh, G.all)

# ---------------------------------------------------------------- headlight beam

static func beamTex() -> ImageTexture:
	if _beamTex == null:
		var w := 64
		var h := 64
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var t := y / float(h - 1)
				var sx := (x - w / 2.0) / (w / 2.0 * (0.35 + 0.65 * t))
				var a := pow(1 - t, 1.6) * maxf(0, 1 - sx * sx)
				img.set_pixel(x, y, Color8(255, 232, 180, int(clampf(roundf(a * 255), 0, 255))))
		img.generate_mipmaps()
		_beamTex = ImageTexture.create_from_image(img)
	return _beamTex

static func addBeam(g: Node3D, zf: float, w: float) -> MeshInstance3D:
	if beamMat == null:
		beamMat = Mats.basic(0xffe6b0, {"map": beamTex(), "transparent": true, "depthWrite": false, "blending": "add", "opacity": 0.7})
		_beamGeo = Geo.plane(1, 1)
		_beamGeo.rotate_x(-PI / 2)
	var b := mesh(g, _beamGeo, beamMat)
	b.scale = Vector3(w * 2.4, 1, 10)
	b.position = Vector3(0, 0.13, zf + 4.6)
	b.visible = false
	return b

# ---------------------------------------------------------------- parts on the skin

## a raised panel that follows the body (lamps, grilles, vents, plates, stickers): surface f(u,v) -> [point, normal]; `out`
## above the skin (>= 2 cm against flicker; a Callable out(u,v) = a shaped panel, shaded per face) with a skirt that dives
## into the body, so it never floats. mirror: also build the x-mirrored copy
static func patch(A: CarAcc, f: Callable, u0: float, u1: float, v0: float, v1: float, nu: int, nv: int, out, mirror := false, uvFlip := false) -> CarAcc:
	var G: Array = []
	for i in nu + 1:
		var row: Array = []
		for j in nv + 1:
			var s = f.call(u0 + (u1 - u0) * i / nu, v0 + (v1 - v0) * j / nv)
			if s == null:
				return A
			row.append(s)
		G.append(row)
	var shaped := out is Callable
	for mx in ([1.0, -1.0] if mirror else [1.0]):
		var Q: Array = []
		for i in nu + 1:
			var row: Array = []
			for j in nv + 1:
				var s: Array = G[i][j]
				var p: Vector3 = s[0]
				var n: Vector3 = s[1]
				var NN := Vector3(n.x * mx, n.y, n.z)
				var PP := Vector3(p.x * mx, p.y, p.z)
				var o: float = out.call(float(i) / nu, float(j) / nv) if shaped else float(out)
				row.append([PP + NN * o, NN, PP - NN * 0.03])
			Q.append(row)
		var flip: bool = uvFlip and mx < 0
		var uv := func(i: int, j: int) -> Vector2:
			return Vector2(1.0 - float(i) / nu if flip else float(i) / nu, float(j) / nv)
		for i in nu:
			for j in nv:
				var a: Array = Q[i][j]
				var b: Array = Q[i + 1][j]
				var c: Array = Q[i][j + 1]
				var d: Array = Q[i + 1][j + 1]
				_ptop(A, shaped, a[0], b[0], d[0], uv.call(i, j), uv.call(i + 1, j), uv.call(i + 1, j + 1), a[1], b[1], d[1])
				_ptop(A, shaped, a[0], d[0], c[0], uv.call(i, j), uv.call(i + 1, j + 1), uv.call(i, j + 1), a[1], d[1], c[1])
		# skirt round the edge
		var ring: Array = []
		for i in nu: ring.append(Q[i][0])
		for j in nv: ring.append(Q[nu][j])
		for i in range(nu, 0, -1): ring.append(Q[i][nv])
		for j in range(nv, 0, -1): ring.append(Q[0][j])
		var cen := Vector3.ZERO
		for q in ring: cen += q[0]
		cen /= ring.size()
		for k in ring.size():
			var a: Array = ring[k]
			var b: Array = ring[(k + 1) % ring.size()]
			var o: Vector3 = (a[0] + b[0]) * 0.5 - cen
			var nn: Vector3 = (b[0] - a[0]).cross(a[1]).normalized()
			if nn.dot(o) < 0: nn = -nn
			_face(A, a[0], b[0], b[2], null, null, null, nn, nn, nn)
			_face(A, a[0], b[2], a[2], null, null, null, nn, nn, nn)
	return A

static func _face(A: CarAcc, a: Vector3, b: Vector3, c: Vector3, ua, ub, uc, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var fn := (b - a).cross(c - a)
	if fn.dot(na) < 0:
		A.tri(a, c, b, na, nc, nb, ua, uc, ub)
	else:
		A.tri(a, b, c, na, nb, nc, ua, ub, uc)

static func _ptop(A: CarAcc, shaped: bool, a: Vector3, b: Vector3, c: Vector3, ua, ub, uc, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	if not shaped:
		_face(A, a, b, c, ua, ub, uc, na, nb, nc)
		return
	var fn := (b - a).cross(c - a).normalized()
	if fn.dot(na) < 0: fn = -fn
	_face(A, a, b, c, ua, ub, uc, fn, fn, fn)

## a round sticker (race number, frog-eye lamp) on the skin: rings round (0,zc) on surface f(x,z), `out` above it, uv inside the
## roundel's white edge. The skirt shows that edge down into the body, so it reads as a thin disc lying on the paint
static func discPatch(A: CarAcc, f: Callable, zc: float, r: float, out: float, nr: int, na: int) -> CarAcc:
	var G: Array = []
	for k in nr + 1:
		var row: Array = []
		for a in (na if k else 1):
			var t := float(k) / nr
			var an := float(a) / na * PI * 2
			var du := cos(an) * t
			var dv := sin(an) * t
			var s = f.call(-du * r, zc + dv * r)
			if s == null:
				return A
			var p: Vector3 = s[0]
			var n: Vector3 = s[1]
			row.append({"p": p + n * out, "n": n, "uv": Vector2(0.5 + du * 0.45, 0.5 + dv * 0.45), "q": p + n * -0.03})
		G.append(row)
	for k in nr:
		for a in na:
			var b := (a + 1) % na
			var c0: Dictionary = G[k][a if k else 0]
			var c1: Dictionary = G[k][b if k else 0]
			var d0: Dictionary = G[k + 1][a]
			var d1: Dictionary = G[k + 1][b]
			_face(A, c0.p, d0.p, d1.p, c0.uv, d0.uv, d1.uv, c0.n, d0.n, d1.n)
			if k: _face(A, c0.p, d1.p, c1.p, c0.uv, d1.uv, c1.uv, c0.n, d1.n, c1.n)
	var E: Array = G[nr]
	var cen: Vector3 = G[0][0].p
	for a in na:
		var e0: Dictionary = E[a]
		var e1: Dictionary = E[(a + 1) % na]
		var nn: Vector3 = (e1.p - e0.p).cross(e0.n).normalized()
		if nn.dot(e0.p - cen) < 0: nn = -nn
		_face(A, e0.p, e1.p, e1.q, e0.uv, e1.uv, e1.uv, nn, nn, nn)
		_face(A, e0.p, e1.q, e0.q, e0.uv, e1.uv, e0.uv, nn, nn, nn)
	return A

## parts on the roof (or on the bonnet of an open car) that the roof number has to stay clear of: [x0, x1, z0, z1]
static func noNum(K: CarBody, r: Array) -> void:
	K.numBlock.append(r)

## where the roof number goes (once per model): the biggest disc (30-62 cm) on a flat part of the painted roof (the bonnet on an
## open car), clear of scoops, snorkels, windscreens and the roof wings a tuned hatchback can carry; null when nothing fits
static func numSpot(K: CarBody):
	if K.numSpot_done:
		return K.numSpot
	var S := K.S
	var C = K.C
	var onRoof: bool = C != null and C.ws - C.rw > 0.5
	var f: Callable = K.on_cab if onRoof else K.on_top
	var T = Cars.TUNE_FIT.get(S.type, null)
	var lo: float = (C.rw + 0.03) if onRoof else ((C.z0 + 0.05) if C != null else K.zR + 0.2)
	var hi: float = (C.ws - 0.03) if onRoof else K.zF - 0.12
	var mid := (lo + hi) / 2
	var block: Array = K.numBlock.duplicate()
	if not onRoof: block.append_array(K.topRects)
	if onRoof and T != null and T.get("roof", false):
		block.append([-1.0, 1.0, T.z - T.chord / 2 - 0.06, maxf(T.z + T.chord / 2, C.rw + 0.12) + 0.03])
	var best = null
	var rMax: float = minf(0.31, (C.ws - C.rw) * 0.35) if onRoof else 0.25   # no bigger than before: 70 % of the roof length, 50 cm on a bonnet
	var n := 0
	while n <= 16 and best == null:
		var r := rMax - n * 0.01
		var k := -1
		while best == null:
			k += 1
			var zc := mid + (1 if k % 2 else -1) * ceilf(k / 2.0) * 0.01
			if absf(zc - mid) > (hi - lo) / 2: break
			if zc - r < lo or zc + r > hi: continue
			var hit := false
			for b in block:
				if b[1] > -r - 0.03 and b[0] < r + 0.03 and b[3] > zc - r - 0.03 and b[2] < zc + r + 0.03:
					hit = true
					break
			if hit: continue
			var ok := true
			for i in 7:
				if not ok: break
				for j in 7:
					if not ok: break
					var x := (i / 3.0 - 1) * r
					var dz := (j / 3.0 - 1) * r
					if x * x + dz * dz > r * r * 1.001: continue
					var s = f.call(x, zc + dz)
					if s == null or s[1].y < 0.93: ok = false
			if ok:
				best = {"f": f, "z": zc, "r": r}
		n += 1
	K.numSpot_done = true
	K.numSpot = best
	return best

# ---------------------------------------------------------------- panels on the skin

## front/rear panels end where the skin turns more than ~60 degrees to the side, so they never fold round a corner
static func _fits(f: Callable, x: float, y0: float, y1: float) -> bool:
	for y in [y0, (y0 + y1) / 2, y1]:
		var q = f.call(x, y)
		if not (q != null and absf(q[1].z) > 0.5): return false
	return true

static func _cl(f: Callable, x0: float, x1: float, y0: float, y1: float) -> Array:
	var a := minf(x0, x1)
	var b := maxf(x0, x1)
	var m := maxf(absf(a), absf(b))
	while m > 0.05 and not _fits(f, m, y0, y1):
		m -= 0.01
	var na := maxf(a, -m) if a < 0 else minf(a, m)
	var nb := minf(b, m)
	return [na, nb] if x0 <= x1 else [nb, na]

## a panel on the nose; a grid point every 8 cm across: coarser, and on a round nose the panel between two points dips into the paint
static func hF(K: CarBody, A: CarAcc, x0: float, x1: float, y0: float, y1: float, out := 0.0, nu := 0, nv := 0) -> CarAcc:
	var c := _cl(K.on_front, x0, x1, y0, y1)
	x0 = c[0]; x1 = c[1]
	if absf(x1 - x0) < 0.04: return A
	return patch(A, K.on_front, x0, x1, y0, y1, maxi(nu if nu else 6, ceili(absf(x1 - x0) / 0.08)), nv if nv else 2, out if out else 0.02, minf(x0, x1) > 0)

## a panel on the tail
static func hR(K: CarBody, A: CarAcc, x0: float, x1: float, y0: float, y1: float, out := 0.0, nu := 0, nv := 0) -> CarAcc:
	var c := _cl(K.on_rear, x0, x1, y0, y1)
	x0 = c[0]; x1 = c[1]
	if absf(x1 - x0) < 0.04: return A
	return patch(A, K.on_rear, x0, x1, y0, y1, maxi(nu if nu else 6, ceili(absf(x1 - x0) / 0.08)), nv if nv else 2, out if out else 0.02, minf(x0, x1) > 0)

## a panel on the flank (both sides)
static func hSd(K: CarBody, A: CarAcc, z0: float, z1: float, y0: float, y1: float, out := 0.0, nu := 0, nv := 0) -> CarAcc:
	K.sideRects.append([minf(z0, z1), maxf(z0, z1), y0, y1])
	return patch(A, K.on_side, z0, z1, y0, y1, nu if nu else 8, nv if nv else 2, out if out else 0.02, true)

## a panel on the bonnet/boot/deck
static func hTp(K: CarBody, A: CarAcc, x0: float, x1: float, z0: float, z1: float, out := 0.0, nu := 0, nv := 0) -> CarAcc:
	K.topRects.append([x0, x1, z0, z1])
	if x0 > 0: K.topRects.append([-x1, -x0, z0, z1])
	return patch(A, K.on_top, x0, x1, z0, z1, nu if nu else 3, nv if nv else 4, out if out else 0.02, x0 > 0)

## a panel on the cabin roof
static func hCb(K: CarBody, A: CarAcc, x0: float, x1: float, z0: float, z1: float, out := 0.0, nu := 0, nv := 0) -> CarAcc:
	return patch(A, K.on_cab, x0, x1, z0, z1, nu if nu else 3, nv if nv else 4, out if out else 0.02, x0 > 0)

# ---------------------------------------------------------------- lamps and grilles from the atlas (CarLamps)

## a lamp or grille on the nose face. tile > 0: the cell repeats every `tile` metres (grilles)
static func lampF(K: CarBody, A: CarAcc, x0: float, x1: float, y0: float, y1: float, cell: String, out := 0.022, tile := 0.0) -> void:
	_lampFR(K, A, K.on_front, x0, x1, y0, y1, cell, out, tile)

## the same on the tail
static func lampR(K: CarBody, A: CarAcc, x0: float, x1: float, y0: float, y1: float, cell: String, out := 0.022, tile := 0.0) -> void:
	_lampFR(K, A, K.on_rear, x0, x1, y0, y1, cell, out, tile)

static func _lampFR(K: CarBody, A: CarAcc, f: Callable, x0: float, x1: float, y0: float, y1: float, cell: String, out: float, tile: float) -> void:
	var c := _cl(f, x0, x1, y0, y1)
	x0 = c[0]; x1 = c[1]
	if absf(x1 - x0) < 0.04: return
	var both := minf(x0, x1) > 0
	var n := maxi(1, roundi(absf(x1 - x0) / tile)) if tile > 0 else 1
	for k in n:
		var a := x0 + (x1 - x0) * k / n
		var b := x0 + (x1 - x0) * (k + 1) / n
		var n0 := A.P.size()
		patch(A, f, a, b, y0, y1, maxi(2 if n > 1 else 6, ceili(absf(b - a) / 0.08)), 2, out, both)
		uvCell(A, n0, cell)

## a lamp lying on the bonnet/deck (z0 = the edge that is the bottom of the picture): projected from above, a little from
## outside and from the front, so it follows the wing down to the shoulder and the nose
static func lampT(K: CarBody, A: CarAcc, x0: float, x1: float, z0: float, z1: float, cell: String, out := 0.022) -> void:
	K.topRects.append([minf(x0, x1), maxf(x0, x1), minf(z0, z1), maxf(z0, z1)])
	if minf(x0, x1) > 0: K.topRects.append([-maxf(x0, x1), -minf(x0, x1), minf(z0, z1), maxf(z0, z1)])
	var d := Vector3(-0.3, -1.0, -0.3).normalized()
	var o := Vector3(0, K.topY((z0 + z1) / 2, (x0 + x1) / 2), 0) - d * 1.0
	var nu := maxi(4, ceili(absf(x1 - x0) / 0.07))
	var nv := maxi(3, ceili(absf(z1 - z0) / 0.07))
	var f := K.proj(o, d, Vector3(1, 0, 0), Vector3(0, 0, 1), x0, x1, z0, z1, nu, nv)
	var n0 := A.P.size()
	if f.call(x0, z0) == null:
		hTp(K, A, x0, x1, z0, z1, out, 5, 5)
	else:
		patch(A, f, x0, x1, z0, z1, nu, nv, out, minf(x0, x1) > 0)
	uvCell(A, n0, cell)

## a lamp projected onto the skin (CarBody.proj): x0..x1, y0..y1 is where the rays cross the plane of the nose (front) or
## the tail; dir is their direction for the +x side (the other side mirrors). It follows the skin round the corner of
## bonnet and nose, or round the rear corner. Returns false when a ray misses the body (then nothing is added).
static func lampP(K: CarBody, A: CarAcc, front: bool, x0: float, x1: float, y0: float, y1: float, dir: Vector3, cell: String, out := 0.022, nu := 6, nv := 3) -> bool:
	var d := dir.normalized()
	var o := Vector3(0, 0, K.zF if front else K.zR) - d * 1.2
	var f := K.proj(o, d, Vector3(1, 0, 0), Vector3(0, 1, 0), x0, x1, y0, y1, nu, nv)
	if f.call(x0, y0) == null: return false
	var n0 := A.P.size()
	patch(A, f, x0, x1, y0, y1, nu, nv, out, minf(x0, x1) > 0)
	uvCell(A, n0, cell)
	return true

## l: {x: [x0, x1], y: [y0, y1]} projected (dir: [dx, dy, dz] optional), "flat": true = on the nose/tail face,
## or {x, z: [z0, z1]} lying on top; kind = atlas cell
static func _lamp(K: CarBody, A: CarAcc, l: Dictionary, front: bool, kind0: String) -> void:
	var kind: String = l.get("kind", kind0)
	var out: float = l.get("out", 0.022)
	if l.has("z"):
		lampT(K, A, l.x[0], l.x[1], l.z[0], l.z[1], kind, out)
	elif l.get("flat", false):
		_lampFR(K, A, K.on_front if front else K.on_rear, l.x[0], l.x[1], l.y[0], l.y[1], kind, out, l.get("tile", 0.0))
	else:
		var dv: Array = l.get("dir", [-0.28, -0.3, -1.0] if front else [-0.3, -0.12, 1.0])
		var w: float = absf(l.x[1] - l.x[0])
		if not lampP(K, A, front, l.x[0], l.x[1], l.y[0], l.y[1], Vector3(dv[0], dv[1], dv[2]), kind, out, maxi(4, ceili(w / 0.07)), 3):
			_lampFR(K, A, K.on_front if front else K.on_rear, l.x[0], l.x[1], l.y[0], l.y[1], kind, out, 0.0)

## round lamps standing on the nose at x and -x: a chrome ring with a lens from the atlas
static func _roundLamps(K: CarBody, D: Dictionary, x: float, y: float, rad: float, kind := "h_round", dz := 0.0, ring := true) -> void:
	var s = K.on_front(x, y)
	if s == null: return
	var th := 0.06
	for sx in [1.0, -1.0]:
		var z: float = s[0].z + dz
		if ring:
			var c := Geo.cylinder(rad, rad, th, 18); c.rotate_x(PI / 2); c.translate(sx * x, y, z); D.chrome.geo(c)
		var n0: int = D.lamp.P.size()
		var l := Geo.circle(rad * (0.86 if ring else 1.0), 18); l.translate(sx * x, y, z + th / 2 + 0.003); D.lamp.geo(l)
		uvCell(D.lamp, n0, kind)

## a straight bar from a to b (wipers, struts)
static func bar(A: CarAcc, a: Vector3, b: Vector3, w: float, h: float) -> void:
	var zb := (b - a).normalized()
	var up := Vector3.UP if absf(zb.y) < 0.9 else Vector3.RIGHT
	var xb := up.cross(zb).normalized()
	A.geo(Geo.box(w, h, a.distance_to(b)), Transform3D(Basis(xb, zb.cross(xb), zb), (a + b) / 2))

# ---------------------------------------------------------------- dressStd: parts every car uses
# lamps, grilles, plates, mirrors, handles, sills, wipers, exhausts and a stock spoiler, placed on the skin by the kit.
# _dressStd() does the parts and _dressExh() the exhausts; each model's own extras run in between.

static func _dressStd(K: CarBody, D: Dictionary, o: Dictionary) -> void:
	var S := K.S
	for l in o.get("hl", []):
		_lamp(K, D.lamp, l, true, "h_rect")
	for l in o.get("tl", []):
		_lamp(K, D.tail, l, false, "t_block")
	for q in o.get("grille", []):
		lampF(K, D.lamp, q.x[0], q.x[1], q.y[0], q.y[1], q.get("kind", "g_mesh"), 0.02, q.get("tile", 0.3))
	for q in o.get("rtrim", []):
		hR(K, D.trim, q.x[0], q.x[1], q.y[0], q.y[1], 0.02)
	if o.has("plateF"):
		hF(K, D.plate, -0.26, 0.26, o.plateF - 0.06, o.plateF + 0.06, 0.04, 2, 1)
	K.plateR = o.get("plateR", null)
	if K.plateR != null:   # u runs right to left seen from behind, so the text reads
		hR(K, D.plate, 0.26, -0.26, K.plateR - 0.06, K.plateR + 0.06, 0.04, 2, 1)
	# door mirrors, just behind the A-pillar: a foot on the door, a painted shell (dome forward), mirror glass in the back
	if o.has("mz"):
		var mz: float = o.mz
		var y: float = o.my
		var x := K.sideX(mz, K.top(mz) - 0.12)
		if x > 0:
			for sx in [1.0, -1.0]:
				var arm := Geo.box(0.13, 0.04, 0.075); arm.rotate_z(sx * 0.3); arm.translate(sx * (x + 0.035), y - 0.04, mz - 0.03); D.trim.geo(arm)
				var h := Geo.sphere(1, 12, 7, 0, PI * 2, 0, PI / 2); h.rotate_x(PI / 2); h.scale(0.1, 0.064, 0.085); h.translate(sx * (x + 0.14), y, mz - 0.065); D.paint.geo(h)
				var rim := Geo.ring(0.8, 1, 14, 1); rim.rotate_y(PI); rim.scale(0.1, 0.064, 1); rim.translate(sx * (x + 0.14), y, mz - 0.065); D.paint.geo(rim)
				var gl := Geo.circle(1, 14); gl.rotate_y(PI); gl.scale(0.083, 0.052, 1); gl.translate(sx * (x + 0.14), y, mz - 0.055)
				D.det.color(sc(0x93a4b2, 0.95)).geo(gl)
	# door handles: chrome on the classics, else in the body colour over a dark recess
	var hk: String = S.get("handle", "paint")
	for z in o.get("handles", []):
		if hk == "chrome":
			hSd(K, D.chrome, z - 0.07, z + 0.07, o.hy - 0.016, o.hy + 0.016, 0.022, 2, 1)
		else:
			hSd(K, D.trim, z - 0.075, z + 0.075, o.hy - 0.03, o.hy - 0.004, 0.008, 2, 1)
			hSd(K, D.paint, z - 0.075, z + 0.075, o.hy - 0.008, o.hy + 0.026, 0.024, 2, 1)
	if o.has("sill"):
		hSd(K, D.trim, S.wz[1] + K.ra + 0.04, S.wz[0] - K.ra - 0.04, o.sill[0], o.sill[1], 0.02, 8, 1)
	# third brake light at the top of the rear window
	if K.C != null and K.has_hole and K.C.rw > K.C.z1 + 0.2 and o.get("chmsl", true):
		var n0: int = D.tail.P.size()
		patch(D.tail, K.on_cab, -0.2, 0.2, K.C.rw - 0.062, K.C.rw - 0.03, 4, 1, 0.012)
		uvCell(D.tail, n0, "chmsl")
	# wipers at the foot of the windscreen
	if K.C != null and K.has_hole and o.get("wipers", true):
		var zb := K.hz0 + 0.02
		for q in [[0.05, 0.5], [-0.42, 0.03]]:
			var a = K.on_cab(q[0], zb)
			var b = K.on_cab(q[1], zb - 0.015)
			if a == null or b == null: continue
			D.det.color(sc(0x0b0c0d, 0.2))
			bar(D.det, a[0] + a[1] * 0.016, b[0] + b[1] * 0.016, 0.022, 0.014)

## exhausts: short open pipes with a dark inside that poke out under the rear bumper (after the extras: a diffuser lifts them
## onto its top edge)
static func _dressExh(K: CarBody, D: Dictionary, o: Dictionary) -> void:
	for x in o.get("exh", []):
		var r: float = o.get("exR", 0.045)
		var y := exhaustY(K, r, x)
		var zb := exhaustZ(K, x, y, r)
		var t := Geo.cylinder(r, r, 0.22, 14, 1, true); t.rotate_x(PI / 2); t.translate(x, y, zb + 0.07); D.exh.geo(t)
		var lip := Geo.torus(r, 0.007, 6, 14); lip.translate(x, y, zb - 0.04); D.exh.geo(lip)
		var c := Geo.circle(r * 0.95, 12); c.rotate_y(PI); c.translate(x, y, zb - 0.015); D.exhD.geo(c)   # own set: hidden with the pipes

static func dressStd(K: CarBody, D: Dictionary, o: Dictionary) -> void:
	_dressStd(K, D, o)
	_dressExh(K, D, o)

## exhaust tip height: the centre just above the lower edge of the bumper 20 cm in from the tail, so the tip pokes out under the
## bumper like on a real car; on a car with a diffuser the tip sits on top of its fins. Clear of the rear plate; S.exhY overrides
static func exhaustY(K: CarBody, r: float, x: float) -> float:
	var S := K.S
	var y: float = S.exhY if S.has("exhY") else K.bot(K.zR + 0.2) + r * 0.25
	if K.diff: y = maxf(y, K.bot(K.zR + 0.24) + 0.03 + r + 0.012)
	if K.plateR != null and absf(x) < 0.26 + r: y = minf(y, K.plateR - 0.06 - r - 0.02)
	return y

## the rearmost skin round the rim of a tip: the pipe ends behind it (no skin there = under the body: the tail itself)
static func exhaustZ(K: CarBody, x: float, y: float, r: float) -> float:
	var best = null
	for qh in [[x - r, y], [x, y], [x + r, y], [x, y - r], [x, y + r]]:
		var q = K.endZ(qh[0], qh[1], false)
		if q != null and (best == null or q < best): best = q
	return best if best != null else K.zR

# stock spoilers: a lip on the boot, or a wing on two posts; they go into the wingP/wingT sets so a tuned wing can hide them
static func lipSpoiler(K: CarBody, D: Dictionary, z: float, span: float) -> void:
	var y := K.topY(z, 0)
	D.wingP.box(span, 0.05, 0.26, 0, y + 0.03, z - 0.02, -0.2)
	K.topRects.append([-span / 2, span / 2, z - 0.16, z + 0.12])

static func postWing(K: CarBody, D: Dictionary, z: float, span: float, h: float, chord: float, roof := false, ep := false) -> void:
	var xs := span * 0.3
	var y0 := K.cabY(z, xs) if roof else K.topY(z, xs)
	for s in [-1.0, 1.0]:
		D.wingT.box(0.05, h + 0.06, 0.16, s * xs, y0 + h / 2 - 0.02, z, 0.22)
	D.wingT.box(span, 0.045, chord, 0, y0 + h + 0.03, z - 0.04, -0.12)
	if ep:
		for s in [-1.0, 1.0]:
			D.wingT.box(0.03, 0.2, chord + 0.1, s * (span / 2 + 0.015), y0 + h + 0.05, z - 0.06)

static func postWingRoof(K: CarBody, D: Dictionary, z := -1.66, span := 1.5) -> void:
	var y := K.cabY(z + 0.06, 0)
	D.wingP.box(span, 0.05, 0.34, 0, y + 0.03, z - 0.06, -0.1)
	for s in [-1.0, 1.0]:
		D.wingP.box(0.04, 0.1, 0.34, s * (span / 2 - 0.01), y - 0.005, z - 0.06)

## twin stripes over bonnet, roof and boot (the glass is left free). hole: the roof number (numSpot); the stripe stops 3 cm short
## of it with an end that follows the disc
static func stripeGeo(K: CarBody, A: CarAcc, x0: float, x1: float, hole = null) -> CarAcc:
	var C = K.C
	var R: Array = K.topRects.filter(func(r): return r[1] > x0 - 0.02 and r[0] < x1 + 0.02)
	if K.stripeW == null: K.stripeW = [x0, x1]
	var piece := func(f: Callable, a: float, b: float, nv: int) -> void:
		var h = hole if (hole != null and hole.f == f and a < hole.z + hole.r + 0.03 and b > hole.z - hole.r - 0.03) else null
		if h == null:
			if b - a > 0.08: patch(A, f, x0, x1, a, b, 2, nv if nv else maxi(2, ceili((b - a) / 0.12)), 0.02, true)
			return
		var hz: float = h.z
		var hr: float = h.r
		var e := func(u: float) -> float: return sqrt(maxf(0.0, hr * hr - u * u)) + 0.03
		var nn := func(l: float) -> int: return maxi(2, ceili(l / 0.12))
		var ex0: float = e.call(x0)
		if hz - ex0 - a > 0.02:
			patch(A, func(u: float, v: float): return f.call(u, a + (hz - e.call(u) - a) * v), x0, x1, 0, 1, 4, nn.call(hz - ex0 - a), 0.02, true)
		if b - hz - ex0 > 0.02:
			patch(A, func(u: float, v: float): return f.call(u, hz + e.call(u) + (b - hz - e.call(u)) * v), x0, x1, 0, 1, 4, nn.call(b - hz - ex0), 0.02, true)
	var run := func(a: float, b: float) -> void:
		var cut: Array = R.filter(func(r): return r[3] > a and r[2] < b)
		_stable_sort(cut, 2)
		var z := a
		cut.append([0.0, 0.0, b + 0.02, b + 0.02])
		for r in cut:
			var e: float = r[2] - 0.02
			piece.call(K.on_top, z, e, 0)
			z = maxf(z, r[3] + 0.02)
	run.call((C.z0 + 0.04) if C != null else 0.45, K.zF - 0.1)
	run.call(K.zR + 0.1, (C.z1 - 0.04) if C != null else -0.9)
	if C != null and C.ws - C.rw > 0.1:
		piece.call(K.on_cab, C.rw + 0.03, C.ws - 0.03, 6)
	return A

## JS Array.sort((p,q)=>p[k]-q[k]) is stable: insertion sort on element k
static func _stable_sort(a: Array, k: int) -> void:
	for i in range(1, a.size()):
		var v = a[i]
		var j := i - 1
		while j >= 0 and a[j][k] > v[k]:
			a[j + 1] = a[j]
			j -= 1
		a[j + 1] = v

## the same stripes with a hole for the roof number, built once per model
static func stripeHoled(K: CarBody) -> Geo:
	if K.stripeNum == null:
		var w: Array = K.stripeW if K.stripeW != null else [0.1, 0.28]
		K.stripeNum = stripeGeo(K, CarAcc.new(), w[0], w[1], numSpot(K)).build()
	return K.stripeNum

## a flat plate cut from an outline [[z, y], ...], t thick, centred on x (fins, end plates, wing profiles)
static func finPlate(A: CarAcc, pts: Array, x: float, t: float) -> void:
	var sh: Array = []
	for p in pts:
		sh.append(Vector2(p[0], p[1]))
	var g := Geo.extrude(sh, t)
	g.rotate_y(-PI / 2)
	g.translate(x + t / 2, 0, 0)
	A.geo(g)

static func diffuser(K: CarBody, D: Dictionary) -> void:
	K.diff = true
	var z := K.zR + 0.24
	var x := -0.6
	while x <= 0.61:
		var top := K.bot(z) + 0.03
		var y0 := 0.08
		D.trim.box(0.035, top - y0, 0.42, x, (top + y0) / 2, z)
		x += 0.3

## airfoil outline [[z, y], ...] with the leading edge at (zLE, yLE), chord towards -z; camber bulges down (downforce), aoa lifts
## the trailing edge
static func airfoil(zLE: float, yLE: float, c: float, th: float, camber: float, aoa: float) -> Array:
	var up: Array = []
	var lo: Array = []
	var ca := cos(aoa)
	var sa := sin(aoa)
	for k in 15:
		var t := (1 - cos(k / 14.0 * PI)) / 2
		var yt := 5 * th * c * (0.2969 * sqrt(t) - 0.126 * t - 0.3516 * t * t + 0.2843 * t * t * t - 0.1036 * t * t * t * t)
		var yc := -camber * c * 4 * t * (1 - t)
		var s := t * c
		for ay in [[up, yc + yt], [lo, yc - yt]]:
			var y: float = ay[1]
			ay[0].append([zLE - (s * ca - y * sa), yLE + s * sa + y * ca])
	lo.reverse()
	return up + lo.slice(1, lo.size() - 1)

## tuning parts, fitted per model and built once (shared like the body). kind: gt (wing), duck (ducktail), or an exhaust
## (sport, dual, center). GT wing: TUNE_FIT z = chord centre, h = plane height above the deck (or roof), span, chord;
## roof: wing on the roof edge (hatchbacks). Returns {detail: Geo (vertex colours, for detailMat), paint: Geo (body colour)}
static func tuneParts(K: CarBody, kind: String) -> Dictionary:
	if K.tune.has(kind):
		return K.tune[kind]
	var S := K.S
	var C = K.C
	var T: Dictionary = Cars.TUNE_FIT.get(S.type, {"z": K.wingZ, "h": 0.26, "span": S.wid - 0.2, "chord": 0.38})
	var troof: bool = T.get("roof", false)
	var dt := CarAcc.new()
	var pt := CarAcc.new()
	var cCarbon := sc(0x23272c, 0.62)
	var cTrim := sc(TRIM, 0.3)
	var deckY := func(z: float, x: float) -> float: return K.cabY(z, x) if troof else K.topY(z, x)
	if kind == "gt":
		var span: float = T.span
		var c: float = T.chord
		var zLE: float = T.z + c / 2
		var xu := span * 0.3
		var feet := [deckY.call(T.z, xu), deckY.call(T.z, xu)]
		var y0: float = maxf(feet[0], feet[1]) + T.h
		var aoa := 0.1 if troof else 0.16
		var foil := airfoil(zLE, y0, c, 0.12, 0.035, aoa)
		dt.color(cCarbon)
		finPlate(dt, foil, 0, span)
		var lo := INF
		var hi := -INF
		var zTE := INF
		for p in foil:
			lo = minf(lo, p[1]); hi = maxf(hi, p[1]); zTE = minf(zTE, p[0])
		var plate := [[zTE + 0.02, hi + 0.045], [zTE - 0.04, hi + 0.015], [zTE - 0.04, lo - 0.07], [zLE - 0.06, lo - 0.06], [zLE + 0.04, lo - 0.015], [zLE + 0.04, hi + 0.015]]
		finPlate(dt, plate, span / 2, 0.025)   # end plates centred on the tips
		finPlate(dt, plate, -span / 2, 0.025)
		var gf := Geo.box(span - 0.03, 0.028, 0.012); gf.rotate_x(aoa); gf.translate(0, foil[14][1] + 0.012, zTE + 0.006); dt.geo(gf)   # gurney flap
		# raked posts: feet follow the deck and sink 4 cm into it, tops end 1.5 cm inside the plane
		var under: Array = foil.slice(14)
		under.append(foil[0])
		_stable_sort(under, 0)
		var yU := func(z: float) -> float:
			for i in under.size() - 1:
				var z1: float = under[i][0]; var y1: float = under[i][1]; var z2: float = under[i + 1][0]; var y2: float = under[i + 1][1]
				if z >= z1 and z <= z2:
					var dz := z2 - z1
					return y1 + (y2 - y1) * (z - z1) / (dz if dz != 0 else 1.0)
			return y0
		var zf: float = (zLE - 0.02) if troof else T.z + 0.1
		var zb: float = (zLE - 0.16) if troof else T.z - 0.08
		var rk := 0.04 if troof else 0.1
		dt.color(cTrim)
		for s in [-1.0, 1.0]:
			var x: float = s * xu
			finPlate(dt, [[zf, deckY.call(zf, x) - 0.04], [zb, deckY.call(zb, x) - 0.04], [zb - rk, yU.call(zb - rk) + 0.015], [zf - rk * 0.6, yU.call(zf - rk * 0.6) + 0.015]], x, 0.03)
	elif kind == "duck":
		if troof:
			# hatchbacks: a longer roof spoiler in body colour with side fins
			var zr: float = C.rw + 0.12
			var y := K.cabY(zr, 0) - 0.005
			var foil := airfoil(zr, y, 0.46, 0.1, 0.02, -0.12)
			finPlate(pt, foil, 0, 1.46)
			for s in [-1.0, 1.0]:
				finPlate(pt, [[zr - 0.02, y - 0.04], [zr - 0.46, y - 0.12], [zr - 0.48, y + 0.02], [zr - 0.1, y + 0.03]], s * 0.72, 0.03)
		else:
			# a lip that rises from the boot lid and curls up over the rounded tail: follows the skin, 4.5 cm up where it starts
			# (clear of stripes); front edge 3.5 cm off the end of any stripe (which stops at z1 - 0.04)
			var z2 := K.zR + 0.035
			var z1 := maxf(z2 + 0.2, minf((C.z1 - 0.075) if C != null else z2 + 0.5, z2 + 0.5))
			var xw := 9.0
			var z := z2
			while z <= z1:
				xw = minf(xw, K.shoulderX(z))
				z += 0.02
			xw *= 0.94
			var shape := func(_u: float, v: float) -> float: return 0.045 + 0.11 * pow(1 - v, 2.2)
			if T.get("duckGap", 0.0):   # two halves either side of the fin
				patch(pt, K.on_top, T.duckGap, xw, z2, z1, 5, 6, shape, true)
			else:
				patch(pt, K.on_top, -xw, xw, z2, z1, 10, 6, shape)
	else:
		# exhausts: tips that end 4-5 cm behind the bumper, with a dark inside, at the stock height (exhaustY: under the bumper,
		# clear of the plate)
		var ex: Array = S.get("exh", [0.5])
		var side: float = minf(maxf(0.45, absf(ex[0])), K.W - 0.3)
		var tips: Array
		if kind == "sport": tips = [[side, 0.058], [-side, 0.058]]
		elif kind == "dual": tips = [[side + 0.065, 0.042], [side - 0.065, 0.042], [-side + 0.065, 0.042], [-side - 0.065, 0.042]]
		else: tips = [[0.075, 0.05], [-0.075, 0.05]]
		var cTip := sc(0x3c3f45, 0.9) if kind == "center" else sc(CHROME, 1.0)
		for xr in tips:
			var x: float = xr[0]
			var r: float = xr[1]
			var ty := exhaustY(K, r, x)
			var zb := exhaustZ(K, x, ty, r)
			dt.color(cTip)
			var t := Geo.cylinder(r, r * 0.94, 0.2, 16, 1, true); t.rotate_x(PI / 2); t.translate(x, ty, zb + 0.055); dt.geo(t)
			var lip := Geo.torus(r - 0.004, 0.006, 6, 16); lip.translate(x, ty, zb - 0.045); dt.geo(lip)
			dt.color(sc(0x08080a, 0.05))
			var d := Geo.circle(r * 0.9, 14); d.rotate_y(PI); d.translate(x, ty, zb - 0.01); dt.geo(d)
	var o := {"detail": dt.build(), "paint": pt.build()}
	K.tune[kind] = o
	return o

# ---------------------------------------------------------------- the models

static func _dress(type: String, K: CarBody, D: Dictionary) -> void:
	match type:
		"hatch": _dress_hatch(K, D)
		"rally": _dress_rally(K, D)
		"coupe": _dress_coupe(K, D)
		"roadster": _dress_roadster(K, D)
		"gt": _dress_gt(K, D)
		"muscle": _dress_muscle(K, D)
		"fastback": _dress_fastback(K, D)
		"sedan": _dress_sedan(K, D)
		"super": _dress_super(K, D)
		"hyper": _dress_hyper(K, D)
		"longtail": _dress_longtail(K, D)
		"proto": _dress_proto(K, D)
		"mini": _dress_mini(K, D)
		"retro": _dress_retro(K, D)
		"wagon": _dress_wagon(K, D)
		"evo": _dress_evo(K, D)
		"v12": _dress_v12(K, D)
		"speedster": _dress_speedster(K, D)
		"city": _dress_city(K, D)
		"van": _dress_van(K, D)
		_: _dress_gt(K, D)

## amber indicator in the bumper (front)
static func _indF(K: CarBody, D: Dictionary, x0: float, x1: float, y0: float, y1: float) -> void:
	lampF(K, D.lamp, x0, x1, y0, y1, "amber", 0.02)

static func _dress_hatch(K: CarBody, D: Dictionary) -> void:
	var o := {"hl": [{"x": [0.42, 0.82], "y": [0.69, 0.83]}], "grille": [{"x": [-0.38, 0.38], "y": [0.7, 0.8], "kind": "g_slats"}, {"x": [-0.62, 0.62], "y": [0.34, 0.49]}], "plateF": 0.575,
		"tl": [{"x": [0.5, 0.88], "y": [0.75, 0.9]}], "rtrim": [{"x": [-0.8, 0.8], "y": [0.3, 0.4]}], "plateR": 0.57, "mz": 0.62, "my": 0.98, "handles": [0.05, -0.7], "hy": 0.86, "sill": [0.3, 0.37], "exh": [0.5]}
	_dressStd(K, D, o)
	D.deco.color(0xc8302a); hF(K, D.deco, -0.4, 0.4, 0.645, 0.668, 0.02, 4, 1); _indF(K, D, 0.64, 0.8, 0.52, 0.57)
	postWingRoof(K, D)
	_dressExh(K, D, o)

static func _dress_rally(K: CarBody, D: Dictionary) -> void:
	var o := {"hl": [{"x": [0.44, 0.84], "y": [0.74, 0.88]}], "grille": [{"x": [-0.4, 0.4], "y": [0.73, 0.84], "kind": "g_slats"}, {"x": [-0.75, 0.75], "y": [0.36, 0.54]}],
		"tl": [{"x": [0.52, 0.9], "y": [0.82, 0.97]}], "rtrim": [{"x": [-0.85, 0.85], "y": [0.33, 0.44]}], "plateR": 0.62, "mz": 0.62, "my": 1.04, "handles": [0.05, -0.7], "hy": 0.92, "sill": [0.33, 0.42], "exh": [-0.55, 0.55]}
	_dressStd(K, D, o)
	# light pod on the bumper, roof scoop, mud flaps, big wing
	var s = K.on_front(0, 0.66)
	if s != null:
		var z: float = s[0].z + 0.07
		D.trim.box(1.3, 0.04, 0.05, 0, 0.66, z - 0.02)
		for x in [-0.5, -0.17, 0.17, 0.5]:
			var c := Geo.cylinder(0.1, 0.1, 0.06, 16); c.rotate_x(PI / 2); c.translate(x, 0.66, z); D.trim.geo(c)
			var n0: int = D.lamp.P.size()
			var l := Geo.circle(0.086, 16); l.translate(x, 0.66, z + 0.033); D.lamp.geo(l)
			uvCell(D.lamp, n0, "h_pod")
	var sz := -0.55
	var sy := K.cabY(sz, 0)
	D.trim.box(0.34, 0.07, 0.4, 0, sy + 0.01, sz, 0.04)
	noNum(K, [-0.17, 0.17, sz - 0.2, sz + 0.2])
	for sx in [-1.0, 1.0]:
		D.trim.box(0.26, 0.22, 0.02, sx * K.S.wx, 0.22, K.S.wz[1] - K.ra - 0.03)
	var wz := -1.45
	var wy := K.cabY(wz, 0.5)
	for q in [-1.0, 1.0]:
		D.wingT.box(0.04, 0.16, 0.3, q * 0.62, wy + 0.05, wz - 0.16, 0.2)
	D.wingT.box(1.72, 0.045, 0.38, 0, wy + 0.14, wz - 0.3, -0.1)
	for q in [-1.0, 1.0]:
		D.wingT.box(0.03, 0.16, 0.44, q * 0.875, wy + 0.13, wz - 0.3)
	_dressExh(K, D, o)

static func _dress_coupe(K: CarBody, D: Dictionary) -> void:
	var o := {"hl": [{"x": [0.4, 0.8], "y": [0.6, 0.73]}], "grille": [{"x": [-0.3, 0.3], "y": [0.6, 0.68], "kind": "g_slats"}, {"x": [-0.62, 0.62], "y": [0.33, 0.47]}], "plateF": 0.55,
		"tl": [{"x": [0.42, 0.86], "y": [0.73, 0.86], "kind": "t_wide"}], "rtrim": [{"x": [-0.8, 0.8], "y": [0.3, 0.4]}], "plateR": 0.58, "mz": 0.48, "my": 0.92, "handles": [-0.35], "hy": 0.8, "sill": [0.28, 0.35], "exh": [0.45]}
	_dressStd(K, D, o)
	_indF(K, D, 0.62, 0.78, 0.5, 0.55); lipSpoiler(K, D, -1.86, 1.5)
	_dressExh(K, D, o)

static func _dress_roadster(K: CarBody, D: Dictionary) -> void:
	var o := {"hl": [{"x": [0.46, 0.8], "z": [1.9, 1.64], "kind": "h_round"}], "grille": [{"x": [-0.36, 0.36], "y": [0.4, 0.56]}], "plateF": 0.47,
		"tl": [{"x": [0.46, 0.86], "y": [0.7, 0.84], "kind": "t_round"}], "rtrim": [{"x": [-0.8, 0.8], "y": [0.32, 0.42]}], "plateR": 0.57, "mz": 0.3, "my": 0.95, "handles": [-0.4], "hy": 0.78, "sill": [0.3, 0.37], "exh": [-0.5, 0.5]}
	_dressStd(K, D, o)
	# open cockpit (CarBody.interior): fairings behind the seats, windscreen in a frame
	for x in [-K.seat.get("x", 0.34), K.seat.get("x", 0.34)]:
		var f := K.topY(-1.0, x)
		var hump := Geo.sphere(1, 12, 8, 0, PI * 2, 0, PI / 2); hump.scale(0.17, 0.12, 0.36); hump.translate(x, f, -1.0); D.paint.geo(hump)
	var z := 0.42
	var yw := K.topY(z, 0)
	noNum(K, [-0.7, 0.7, z - 0.32, z + 0.08])
	D.glass.box(1.3, 0.4, 0.02, 0, yw + 0.18, z - 0.1, -0.62)
	for s in [-1.0, 1.0]:
		D.trim.box(0.05, 0.44, 0.05, s * 0.67, yw + 0.18, z - 0.1, -0.62)
	D.trim.box(1.36, 0.05, 0.05, 0, yw + 0.36, z - 0.23, -0.62)
	lipSpoiler(K, D, -1.9, 1.4)
	_dressExh(K, D, o)

static func _dress_gt(K: CarBody, D: Dictionary) -> void:
	var o := {"hl": [{"x": [0.46, 0.86], "y": [0.56, 0.7], "kind": "h_slim"}], "grille": [{"x": [-0.45, 0.45], "y": [0.36, 0.54]}], "plateF": 0.62,
		"tl": [{"x": [0.48, 0.9], "y": [0.68, 0.82], "kind": "t_round"}], "rtrim": [{"x": [-0.85, 0.85], "y": [0.28, 0.4]}], "plateR": 0.56, "mz": 0.2, "my": 0.95, "handles": [-0.55], "hy": 0.82, "sill": [0.26, 0.34], "exh": [-0.5, 0.5]}
	_dressStd(K, D, o)
	# side gills behind the front wheels, hood vent, ducktail
	var n0: int = D.lamp.P.size()
	hSd(K, D.lamp, 0.62, 0.86, 0.52, 0.66, 0.02, 3, 2); uvCell(D.lamp, n0, "g_vent")
	n0 = D.lamp.P.size()
	hTp(K, D.lamp, 0.36, 0.6, 1.0, 1.3, 0.02, 3, 2); uvCell(D.lamp, n0, "g_vent")
	lipSpoiler(K, D, -2.06, 1.7)
	_dressExh(K, D, o)
	stripeGeo(K, D.stripe, 0.1, 0.28)

static func _dress_muscle(K: CarBody, D: Dictionary) -> void:
	var o := {"grille": [{"x": [-0.92, 0.92], "y": [0.6, 0.9], "kind": "g_slats", "tile": 0.46}], "rtrim": [{"x": [-0.9, 0.9], "y": [0.32, 0.44]}], "plateR": 0.62, "mz": 0.5, "my": 1.08, "handles": [-0.35], "hy": 0.94, "sill": [0.34, 0.4], "exh": [-0.7, -0.5, 0.5, 0.7], "exR": 0.04,
		"tl": [{"x": [-0.88, 0.88], "y": [0.8, 0.92], "kind": "t_slats", "flat": true, "tile": 0.44}]}
	_dressStd(K, D, o)
	# round lamps in the grille (4 cm in front of it), chrome bumpers, hood scoop, boot lip
	for x in [0.5, 0.74]:
		_roundLamps(K, D, x, 0.75, 0.1, "h_round", 0.01)
	hF(K, D.chrome, -0.98, 0.98, 0.46, 0.54, 0.02, 8, 1); hR(K, D.chrome, -0.98, 0.98, 0.48, 0.54, 0.02, 8, 1)
	var z := 1.2
	var y := K.topY(z, 0)
	D.paint.box(0.62, 0.12, 0.9, 0, y + 0.04, z, 0.04); D.trim.box(0.5, 0.07, 0.02, 0, y + 0.06, z + 0.456)
	lipSpoiler(K, D, -2.3, 1.9)
	_dressExh(K, D, o)
	stripeGeo(K, D.stripe, 0.1, 0.34)

static func _dress_fastback(K: CarBody, D: Dictionary) -> void:
	var o := {"grille": [{"x": [-0.62, 0.62], "y": [0.54, 0.84], "tile": 0.31}], "rtrim": [{"x": [-0.88, 0.88], "y": [0.32, 0.44]}], "plateF": 0.48, "plateR": 0.56, "mz": 0.5, "my": 1.06, "handles": [-0.3], "hy": 0.9, "sill": [0.34, 0.4], "exh": [-0.6, 0.6],
		"tl": [{"x": [0.3, 0.85], "y": [0.74, 0.88], "kind": "t_slats", "flat": true}]}
	_dressStd(K, D, o)
	for x in [0.8]:
		_roundLamps(K, D, x, 0.72, 0.11, "h_round", 0.01)
	hF(K, D.chrome, -0.98, 0.98, 0.4, 0.48, 0.02, 8, 1)
	D.deco.color(0xf7f7f2); hSd(K, D.deco, -1.05, 1.05, 0.44, 0.5, 0.02, 10, 1)
	for k in 3:
		hSd(K, D.trim, -1.02 + k * 0.1, -0.95 + k * 0.1, 1.02, 1.12, 0.02, 1, 1)
	lipSpoiler(K, D, -2.3, 1.8)
	_dressExh(K, D, o)

static func _dress_sedan(K: CarBody, D: Dictionary) -> void:
	var o := {"hl": [{"x": [0.42, 0.84], "y": [0.69, 0.82]}], "grille": [{"x": [0.05, 0.3], "y": [0.66, 0.8], "kind": "g_slats"}, {"x": [-0.7, 0.7], "y": [0.32, 0.48]}], "plateF": 0.56,
		"tl": [{"x": [0.46, 0.92], "y": [0.83, 0.96], "kind": "t_wide"}], "rtrim": [{"x": [-0.85, 0.85], "y": [0.3, 0.4]}], "plateR": 0.62, "mz": 0.78, "my": 1.03, "handles": [0.35, -0.55], "hy": 0.9, "sill": [0.29, 0.36], "exh": [-0.55, 0.55]}
	_dressStd(K, D, o)
	_indF(K, D, 0.7, 0.82, 0.52, 0.56); lipSpoiler(K, D, -2.3, 1.5)
	_dressExh(K, D, o)

static func _dress_super(K: CarBody, D: Dictionary) -> void:
	var o := {"hl": [{"x": [0.48, 0.86], "z": [2.08, 1.78], "kind": "h_led"}], "grille": [{"x": [0.36, 0.9], "y": [0.26, 0.42]}, {"x": [-0.26, 0.26], "y": [0.26, 0.4]}],
		"tl": [{"x": [0.42, 0.92], "y": [0.6, 0.74], "kind": "t_round"}], "rtrim": [{"x": [-0.92, 0.92], "y": [0.24, 0.44]}], "plateR": 0.52, "mz": 0.62, "my": 0.86, "handles": [], "sill": [0.24, 0.32], "exh": [-0.35, 0.35], "exR": 0.06}
	_dressStd(K, D, o)
	# side intakes in front of the rear wheels, engine cover louvres, diffuser fins, small wing
	var n0: int = D.lamp.P.size()
	hSd(K, D.lamp, -0.92, -0.48, 0.42, 0.66, 0.02, 4, 2); uvCell(D.lamp, n0, "g_mesh")
	for k in 5:
		hTp(K, D.trim, -0.45, 0.45, -1.9 + k * 0.18, -1.83 + k * 0.18, 0.02, 3, 1)
	diffuser(K, D)
	postWing(K, D, -1.98, 1.8, 0.2, 0.34)
	_dressExh(K, D, o)

static func _dress_hyper(K: CarBody, D: Dictionary) -> void:
	var o := {"hl": [{"x": [0.5, 0.84], "z": [2.22, 1.9], "kind": "h_slim"}], "grille": [{"x": [0.3, 0.92], "y": [0.22, 0.36]}, {"x": [-0.22, 0.22], "y": [0.22, 0.34]}],
		"tl": [{"x": [-0.9, 0.9], "y": [0.64, 0.71], "kind": "t_full", "flat": true}], "rtrim": [{"x": [-0.92, 0.92], "y": [0.22, 0.52]}], "mz": 0.68, "my": 0.82, "sill": [0.2, 0.3], "exh": [-0.3, 0.3], "exR": 0.07}
	_dressStd(K, D, o)
	var n0: int = D.lamp.P.size()
	hSd(K, D.lamp, -1.0, -0.45, 0.36, 0.64, 0.02, 4, 2); uvCell(D.lamp, n0, "g_mesh")
	for sg in [[-0.55, -0.25], [0.25, 0.55]]:
		n0 = D.lamp.P.size()
		hTp(K, D.lamp, sg[0], sg[1], 1.5, 1.9, 0.02, 2, 3); uvCell(D.lamp, n0, "g_vent")
	var z := -1.2
	var y := K.topY(z, 0)
	D.trim.box(0.5, 0.2, 1.2, 0, y + 0.03, z, -0.06)
	diffuser(K, D)
	var wz := -2.02
	var y0 := K.topY(wz, 0.45)
	for s in [-1.0, 1.0]:
		D.wingT.box(0.06, 0.44, 0.16, s * 0.45, y0 + 0.2, wz + 0.04, 0.3)
	D.wingT.box(2.06, 0.05, 0.5, 0, y0 + 0.44, wz - 0.06, -0.14)
	for s in [-1.0, 1.0]:
		D.wingT.box(0.03, 0.26, 0.6, s * 1.045, y0 + 0.42, wz - 0.08)
	_dressExh(K, D, o)

static func _dress_longtail(K: CarBody, D: Dictionary) -> void:
	var o := {"hl": [{"x": [0.5, 0.86], "z": [2.3, 2.0], "kind": "h_led"}], "grille": [{"x": [-0.3, 0.3], "y": [0.22, 0.34]}, {"x": [0.4, 0.92], "y": [0.22, 0.34]}],
		"tl": [{"x": [0.35, 0.88], "y": [0.44, 0.54], "kind": "t_bar", "flat": true}], "rtrim": [{"x": [-0.92, 0.92], "y": [0.22, 0.4]}], "plateR": 0.62, "mz": 1.1, "my": 0.8, "sill": [0.2, 0.3], "exh": [-0.3, 0.3], "exR": 0.06}
	_dressStd(K, D, o)
	# roof snorkel, fins along the tail, low wing between them, diffuser
	var y := K.cabY(-0.1, 0)
	D.trim.box(0.3, 0.16, 0.8, 0, y + 0.04, -0.45, 0.06); D.trim.box(0.24, 0.1, 0.02, 0, y + 0.08, -0.06); noNum(K, [-0.15, 0.15, -0.85, -0.05])
	for s in [-1.0, 1.0]:
		var fy := K.topY(-2.0, 0.78) - 0.04
		finPlate(D.paint, [[-1.3, fy], [-1.3, fy + 0.02], [-2.7, fy + 0.3], [-2.8, fy + 0.3], [-2.8, fy]], s * 0.8, 0.05)
	var z := -2.55
	var y0 := K.topY(z, 0.78) + 0.22
	D.wingT.box(1.66, 0.05, 0.42, 0, y0, z, -0.1)
	diffuser(K, D)
	_dressExh(K, D, o)

static func _dress_proto(K: CarBody, D: Dictionary) -> void:
	var o := {"hl": [{"x": [0.6, 0.8], "z": [2.14, 1.92], "kind": "h_led"}], "grille": [{"x": [-0.3, 0.3], "y": [0.2, 0.32]}],
		"tl": [{"x": [0.55, 0.95], "y": [0.5, 0.58], "kind": "t_bar"}], "rtrim": [{"x": [-0.95, 0.95], "y": [0.2, 0.42]}], "mz": 0.9, "my": 0.66, "exh": [-0.4, 0.4], "exR": 0.05, "wipers": false}
	_dressStd(K, D, o)
	# shark fin, big wing on end plates, splitter, side stripe
	finPlate(D.paint, [[-0.55, 0.8], [-0.75, 0.93], [-2.05, 0.93], [-2.2, 0.6], [-0.55, 0.55]], 0, 0.03)
	var z := -2.28
	var y0 := 0.98
	for s in [-1.0, 1.0]:
		finPlate(D.wingT, [[z + 0.26, 0.84], [z + 0.26, y0 + 0.16], [z - 0.34, y0 + 0.24], [z - 0.34, 0.8]], s * 1.035, 0.03)
	D.wingT.box(2.04, 0.05, 0.5, 0, y0 + 0.1, z, -0.12); D.wingT.box(2.02, 0.04, 0.16, 0, y0 + 0.18, z - 0.3, -0.5)
	for s in [-1.0, 1.0]:
		D.wingT.box(0.04, 0.36, 0.14, s * 0.3, y0 - 0.12, z + 0.05)
	D.trim.box(1.4, 0.03, 0.18, 0, 0.15, 2.27); D.deco.color(0xf7f7f2); hSd(K, D.deco, -0.7, 0.9, 0.36, 0.46, 0.02, 8, 1)
	_dressExh(K, D, o)

# class B: a boxy city car with round lamps, a 60s rear-engined coupe with frog-eye lamps on the wings
static func _dress_mini(K: CarBody, D: Dictionary) -> void:
	var o := {"grille": [{"x": [-0.36, 0.36], "y": [0.64, 0.74], "kind": "g_slats"}, {"x": [-0.6, 0.6], "y": [0.34, 0.48]}], "plateF": 0.55,
		"tl": [{"x": [0.62, 0.86], "y": [0.62, 0.86], "kind": "t_van"}], "rtrim": [{"x": [-0.82, 0.82], "y": [0.3, 0.4]}], "plateR": 0.55, "mz": 0.62, "my": 0.98, "handles": [-0.25], "hy": 0.86, "sill": [0.3, 0.37], "exh": [0.42]}
	_dressStd(K, D, o)
	# round headlamps with a chrome ring, amber indicators, a roof lip
	_roundLamps(K, D, 0.6, 0.7, 0.115, "h_round", 0.0)
	_indF(K, D, 0.62, 0.78, 0.52, 0.57)
	postWingRoof(K, D, -1.56, 1.4)
	_dressExh(K, D, o)

static func _dress_retro(K: CarBody, D: Dictionary) -> void:
	var o := {"plateF": 0.44,
		"tl": [{"x": [0.36, 0.8], "y": [0.58, 0.67], "kind": "t_bar", "flat": true}], "rtrim": [{"x": [-0.8, 0.8], "y": [0.26, 0.36]}], "plateR": 0.48, "mz": 0.36, "my": 0.94, "handles": [-0.3], "hy": 0.78, "sill": [0.25, 0.32], "exh": [-0.36, 0.36]}
	_dressStd(K, D, o)
	# frog-eye lamps on top of the wings, engine-lid louvres, chrome bumper strips, a small ducktail
	for sx in [1.0, -1.0]:
		var n0: int = D.lamp.P.size()
		discPatch(D.chrome, func(x: float, z: float): return K.on_top(sx * 0.6 - x, z), 1.72, 0.135, 0.02, 3, 20)
		discPatch(D.lamp, func(x: float, z: float): return K.on_top(sx * 0.6 - x, z), 1.72, 0.112, 0.032, 3, 20)
		uvCell(D.lamp, n0, "h_fog")
	for k in 5:
		hTp(K, D.trim, -0.36, 0.36, -1.66 + k * 0.1, -1.62 + k * 0.1, 0.02, 3, 1)
	hF(K, D.chrome, -0.7, 0.7, 0.42, 0.47, 0.02, 8, 1); hR(K, D.chrome, -0.72, 0.72, 0.4, 0.45, 0.02, 8, 1)
	lipSpoiler(K, D, -1.88, 1.2)
	_dressExh(K, D, o)

# class A: a fast estate with roof rails, a boxy turbo rally sedan with a big wing
static func _dress_wagon(K: CarBody, D: Dictionary) -> void:
	var o := {"hl": [{"x": [0.42, 0.86], "y": [0.69, 0.82]}], "grille": [{"x": [-0.38, 0.38], "y": [0.62, 0.8]}, {"x": [-0.72, 0.72], "y": [0.32, 0.5]}], "plateF": 0.56,
		"tl": [{"x": [0.54, 0.92], "y": [0.8, 0.97]}], "rtrim": [{"x": [-0.86, 0.86], "y": [0.3, 0.42]}], "plateR": 0.62, "mz": 0.78, "my": 1.03, "handles": [0.35, -0.55], "hy": 0.9, "sill": [0.29, 0.36], "exh": [-0.66, -0.52, 0.52, 0.66], "exR": 0.04}
	_dressStd(K, D, o)
	_indF(K, D, 0.7, 0.84, 0.52, 0.56)
	var n0: int = D.lamp.P.size()
	hSd(K, D.lamp, 1.72, 1.98, 0.62, 0.7, 0.02, 3, 1); uvCell(D.lamp, n0, "g_vent")
	postWingRoof(K, D, -2.08, 1.56)
	_dressExh(K, D, o)

static func _dress_evo(K: CarBody, D: Dictionary) -> void:
	var o := {"hl": [{"x": [0.44, 0.86], "y": [0.69, 0.82]}], "grille": [{"x": [-0.36, 0.36], "y": [0.68, 0.8]}, {"x": [-0.74, 0.74], "y": [0.32, 0.58]}], "plateF": 0.62,
		"tl": [{"x": [0.48, 0.9], "y": [0.81, 0.94]}], "rtrim": [{"x": [-0.85, 0.85], "y": [0.32, 0.42]}], "plateR": 0.62, "mz": 0.66, "my": 1.03, "handles": [0.3, -0.5], "hy": 0.88, "sill": [0.31, 0.38], "exh": [0.52], "exR": 0.055}
	_dressStd(K, D, o)
	# bonnet scoop and vents, fog lamps in the bumper, a tall wing on posts
	var z := 1.0
	var y := K.topY(z, 0)
	D.trim.box(0.5, 0.08, 0.44, 0, y + 0.02, z, 0.05)
	var n0: int = D.lamp.P.size()
	hTp(K, D.lamp, 0.3, 0.56, 1.3, 1.6, 0.02, 3, 2); uvCell(D.lamp, n0, "g_vent")
	_roundLamps(K, D, 0.6, 0.42, 0.06, "h_fog", 0.0, false)
	postWing(K, D, -2.0, 1.7, 0.24, 0.32, false, true)
	_dressExh(K, D, o)

# class S: a front-engined V12 grand tourer, an open speedster without a roof
static func _dress_v12(K: CarBody, D: Dictionary) -> void:
	var o := {"hl": [{"x": [0.53, 0.9], "z": [2.14, 1.86], "kind": "h_led"}], "grille": [{"x": [-0.56, 0.56], "y": [0.26, 0.42], "tile": 0.28}],
		"tl": [{"x": [0.5, 0.92], "y": [0.62, 0.76], "kind": "t_round"}], "rtrim": [{"x": [-0.92, 0.92], "y": [0.24, 0.42]}], "plateR": 0.53, "mz": -0.06, "my": 0.92, "handles": [-0.72], "hy": 0.78, "sill": [0.22, 0.3], "exh": [-0.62, -0.48, 0.48, 0.62], "exR": 0.045}
	_dressStd(K, D, o)
	# long bonnet with vents, side gills behind the front wheels, diffuser, a small lip
	for k in 4:
		hTp(K, D.trim, 0.42, 0.66, 0.7 + k * 0.14, 0.76 + k * 0.14, 0.02, 3, 1)
	var n0: int = D.lamp.P.size()
	hSd(K, D.lamp, 0.72, 1.0, 0.42, 0.6, 0.02, 3, 2); uvCell(D.lamp, n0, "g_vent")
	diffuser(K, D); lipSpoiler(K, D, -2.14, 1.3)
	_dressExh(K, D, o)

static func _dress_speedster(K: CarBody, D: Dictionary) -> void:
	var o := {"hl": [{"x": [0.5, 0.86], "z": [2.08, 1.8], "kind": "h_slim"}], "grille": [{"x": [0.36, 0.9], "y": [0.25, 0.38]}, {"x": [-0.26, 0.26], "y": [0.25, 0.37]}],
		"tl": [{"x": [0.4, 0.92], "y": [0.64, 0.73], "kind": "t_bar", "flat": true}], "rtrim": [{"x": [-0.92, 0.92], "y": [0.24, 0.44]}], "plateR": 0.52, "mz": 0.24, "my": 0.88, "sill": [0.22, 0.3], "exh": [-0.3, 0.3], "exR": 0.06}
	_dressStd(K, D, o)
	# open cockpit (CarBody.interior): humps behind the seats, a low wraparound visor instead of a windscreen
	for x in [-K.seat.get("x", 0.36), K.seat.get("x", 0.36)]:
		var f := K.topY(-1.1, x)
		var hump := Geo.sphere(1, 12, 8, 0, PI * 2, 0, PI / 2); hump.scale(0.2, 0.16, 0.5); hump.translate(x, f, -1.12); D.paint.geo(hump)
	var z := 0.36
	var yw := K.topY(z, 0)
	noNum(K, [-0.75, 0.75, z - 0.24, z + 0.08])
	D.glass.box(1.36, 0.14, 0.02, 0, yw + 0.07, z - 0.06, -0.9); D.trim.box(1.4, 0.035, 0.05, 0, yw + 0.14, z - 0.12, -0.9)
	diffuser(K, D); postWing(K, D, -1.98, 1.76, 0.2, 0.32)
	_dressExh(K, D, o)

## the traffic hatchback (not for sale; buildHatchTraffic)
static func _dress_city(K: CarBody, D: Dictionary) -> void:
	dressStd(K, D, {"hl": [{"x": [0.44, 0.84], "y": [0.75, 0.9], "kind": "h_van"}], "grille": [{"x": [-0.4, 0.4], "y": [0.76, 0.86], "kind": "g_slats"}, {"x": [-0.6, 0.6], "y": [0.36, 0.5]}], "plateF": 0.6,
		"tl": [{"x": [0.52, 0.9], "y": [0.85, 1.01]}], "rtrim": [{"x": [-0.85, 0.85], "y": [0.32, 0.44]}], "plateR": 0.64, "mz": 0.62, "my": 1.08, "handles": [0.05, -0.75], "hy": 0.96, "exh": [0.5]})

# ---------------------------------------------------------------- kit and car

## the accumulators a model's dress function fills (D): paint = body colour; trim = black plastic; chrome; deco = own vertex
## colours; det = own vertex colours with shine in alpha (CarKit.sc); lamp / tail = atlas patches (uvCell); plate; glass;
## wingP / wingT = the stock spoiler (paint / black), hidden when a tuned wing is fitted; exh / exhD = stock exhaust (chrome /
## dark inside); stripe; int = interior; driver
const PART_SETS := ["paint", "trim", "lamp", "tail", "chrome", "plate", "deco", "det", "glass", "wingP", "wingT", "exh", "exhD", "stripe", "int", "driver"]

## the body kit of a model with all its fixed parts, built once and shared by every car of that type.
## K.G: paint, detail, glass, lamp, tail, plate, driver, wingP, wingT, exh, stripe (Geo or null)
static func carKit(type: String) -> CarBody:
	if KITS.has(type):
		return KITS[type]
	var S := Cars.spec(type)
	var K := CarBody.new(S)
	var D := {}
	for k in PART_SETS:
		D[k] = CarAcc.new()
	K.interior(D.int, D.driver)
	_dress(type if Cars.CAR_SPECS.has(type) else "gt", K, D)
	K.G = {}
	# paint: the skin (alpha 1 = panel lines), the cabin's roof and pillars, painted parts
	var pm := Mb.new()
	pm.group(K.body, 0, Color(1, 1, 1, 1))
	if K.cab != null: pm.group(K.cab, 0, Color(1, 1, 1, 0))
	pm.acc(D.paint, Color(1, 1, 1, 0))
	K.G.paint = pm.build()
	# detail: underside and wheel wells, window frames, belt moulding, the cabin seen from inside, trim, chrome, interior
	var dm := Mb.new()
	dm.group(K.body, 1, sc(LINER, 0.05))
	if K.cab != null:
		dm.group(K.cab, 2, sc(0x0c0d0f, 0.35))
		dm.group(K.cab, 3, sc(CHROME, 0.95) if S.get("belt", "") == "chrome" else sc(0x0c0d0f, 0.45))
		dm.group(K.cab, 0, sc(0x2c2e33, 0.0), true)
		dm.group(K.cab, 2, sc(0x1c1d21, 0.0), true)
	dm.acc(D.trim, sc(TRIM, 0.3))
	dm.acc(D.chrome, sc(CHROME, 1.0))
	dm.acc(D.deco, null, 0.4)
	dm.acc(D.det)
	dm.acc(D.int)
	K.G.detail = dm.build()
	var gm := Mb.new()
	if K.cab != null: gm.group(K.cab, 1, Color.WHITE)
	gm.acc(D.glass, Color.WHITE)
	K.G.glass = gm.build()
	for k in ["lamp", "tail", "plate", "wingP", "stripe", "driver"]:
		K.G[k] = D[k].build()
	var wm := Mb.new()
	wm.acc(D.wingT, sc(TRIM, 0.35))
	K.G.wingT = wm.build()
	var em := Mb.new()
	em.acc(D.exh, sc(CHROME, 1.0))
	em.acc(D.exhD, sc(0x08080a, 0.05))
	K.G.exh = em.build()
	var img := K.lines_image()
	img.generate_mipmaps()
	K.lines_tex = ImageTexture.create_from_image(img)
	var w: Dictionary = S.wing
	K.wingZ = w.z
	K.wingY = K.cabY(w.z, 0.45) if w.get("roof", false) else K.topY(w.z, 0.45)
	K._memo.clear()
	KITS[type] = K
	return K

## the soft contact shadow under a car
static func addBlob(g: Node3D, length: float, wid: float, off := 0.0) -> MeshInstance3D:
	if blobMat == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var u := absf((x + 0.5) / n * 2 - 1)
				var v := absf((y + 0.5) / n * 2 - 1)
				var d := pow(pow(u, 4.0) + pow(v, 4.0), 0.25)
				img.set_pixel(x, y, Color(0, 0, 0, 1.0 - smoothstep(0.5, 1.0, d)))
		img.generate_mipmaps()
		blobMat = Mats.basic(0x000000, {"map": ImageTexture.create_from_image(img), "transparent": true, "depthWrite": false, "opacity": 0.5})
		blobMat.render_priority = -1
		_blobGeo = Geo.plane(1, 1)
		_blobGeo.rotate_x(-PI / 2)
	var b := mesh(g, _blobGeo, blobMat)
	b.scale = Vector3(wid + 0.55, 1, length + 0.6)
	b.position = Vector3(0, 0.035, off)
	return b

## a car of model `type` in colour `color` (Color, hex int or "#rrggbb"). lite (traffic): no brake calipers.
static func buildCar(type: String, color, lite := false) -> Dictionary:
	var K := carKit(type)
	var S := K.S
	var g := Node3D.new()
	var shell := Node3D.new()
	shell.name = "shell"
	g.add_child(shell)
	var paint := CarPaint.paint(_col(color))
	paint.set_lines(K.lines_tex, K.lines_map())
	var body := mesh(shell, K.G.paint, paint, true)
	var det := mesh(shell, K.G.detail, detailMat, true)   # casts too: the floor closes the body's shadow under the windows
	var glass := mesh(shell, K.G.glass, carGlass)
	var lamp := mesh(shell, K.G.lamp, lampMat)
	var tail := mesh(shell, K.G.tail, tailMat)
	var plate := mesh(shell, K.G.plate, carPlate)
	var driver := mesh(shell, K.G.driver, detailMat)
	if plate != null: plate.visibility_range_end = 120.0
	if driver != null: driver.visibility_range_end = 90.0
	var stock := [mesh(shell, K.G.wingP, paint, true), mesh(shell, K.G.wingT, detailMat, true)].filter(func(o): return o != null)
	var ex := mesh(shell, K.G.exh, detailMat)
	shell.set_meta("exh", {"meshes": [ex] if ex != null else []})
	g.set_meta("exh", shell.get_meta("exh"))
	if K.G.stripe != null:
		var stp := _M(0xf7f7f2)
		stp.set_meta("stripe", true)
		mesh(shell, K.G.stripe, stp)
	var wheels := []
	for z in S.wz:
		for sx in [-1.0, 1.0]:
			wheels.append(addWheel(g, sx * S.wx, S.r, z, S.r, S.w, S.get("rim", "std"), null if lite else "default"))
	var beam := addBeam(g, S.len / 2.0, S.wid)
	var blob := addBlob(g, S.len, S.wid, S.get("off", 0.0))
	return {"g": g, "shell": shell, "wheels": wheels, "len": S.len, "wid": S.wid, "rc": S.get("hitR", Cars.CAR_RC), "off": S.get("off", 0.0), "type": type,
		"wingY": K.wingY, "wingZ": K.wingZ, "stockWing": stock, "beam": beam, "blob": blob, "kit": K, "paint": paint,
		"body": body, "detail": det, "glass": glass, "lamp": lamp, "tail": tail, "plate": plate, "driver": driver, "lights": {"brake": false, "rev": false}}

# ---------------------------------------------------------------- looks and tuning

## the upgrades/looks of a car (id: a car id, or such a Dictionary itself)
static func carUp(id) -> Dictionary:
	if id is Dictionary:
		var u := Cars.default_up()
		u.merge(id, true)
		return u
	if up_of.is_valid():
		var u := Cars.default_up()
		u.merge(up_of.call(id), true)
		return u
	return Cars.default_up()

static func _meshes_of(n: Node, out: Array) -> Array:
	for c in n.get_children():
		if c is MeshInstance3D: out.append(c)
		_meshes_of(c, out)
	return out

## paint finish, rims, stripes, race number, wing and exhaust of a built car from the garage (id) or an upgrades Dictionary
static func styleCar(m: Dictionary, id) -> void:
	var u := carUp(id)
	var pm = m.get("paint", null)
	if pm is CarPaint:
		pm.finish = str(u.get("finish", "gloss"))
	var rim := sc(Cars.RIMS[u.rim][1] if Cars.RIMS.has(u.rim) else RIM_SILVER, 0.72)
	styleExtras(m, u, rim)
	setRims(m, u.rimStyle if Cars.RIMSTYLES.has(u.rimStyle) else "std", rim)
	var K = m.get("kit", null)
	var shell: Node3D = m.get("shell", m.g)
	var hole = numSpot(K) if (u.num > 0 and K != null) else null
	var own: Array = []
	var all: Array = []
	_meshes_of(m.g, all)
	for o in all:
		var mt = o.get_surface_override_material(0)
		if mt != null and mt.has_meta("stripe"): own.append(o)
	if hole != null:
		for o in own: set_geo(o, stripeHoled(K))   # stripes stop round the roof number
	var st: String = u.stripe if Cars.STRIPES.has(u.stripe) else "std"
	if st == "std": return
	var scol = Cars.STRIPES[st][1]
	if scol == null:
		for o in own: o.visible = false
		return
	if not own.is_empty():
		own[0].get_surface_override_material(0).albedo_color = MathX.col(scol)
		return
	# no factory stripes on this model: lay a pair over bonnet, roof and boot (built once per model)
	if K == null: return
	if K.stripes == null:
		K.stripes = stripeGeo(K, CarAcc.new(), 0.1, 0.28).build()
	var sm := _M(scol)
	sm.set_meta("stripe", true)
	mesh(shell, stripeHoled(K) if hole != null else K.stripes, sm)

static func styleExtras(m: Dictionary, u: Dictionary, _rim = null) -> void:
	var K = m.get("kit", null)
	if K == null: return
	var S: Dictionary = K.S
	var C = K.C
	var shell: Node3D = m.get("shell", m.g)
	if u.num > 0:
		var num := str(int(u.num))   # garage values come from JSON (floats)
		var t := Canvas2D.tex(128, 128, func(g, _w, _h):
			g.fillStyle = "#f7f7f2"; g.beginPath(); g.arc(64, 64, 60, 0, PI * 2); g.fill(); g.fillStyle = "#161a22"
			g.font = "800 78px Barlow Condensed"; g.textAlign = "center"; g.textBaseline = "middle"; g.fillText(num, 64, 70))
		var dm := _M(0xffffff, {"map": t, "transparent": true})
		# number roundels follow the door skin 2 cm out, and one on the roof (the bonnet on the open roadster)
		var zA: float = S.wz[1] + K.ra + 0.08
		var zB: float = S.wz[0] - K.ra - 0.08
		var z0: float = maxf(C.sg[0], zA) if C != null else zA
		var z1: float = minf(C.sg[1], zB) if C != null else zB
		var SR: Array = K.sideRects
		var best = null
		if S.has("numFin"):   # race cars carry it on the fin
			var f: Dictionary = S.numFin
			for sx in [-1.0, 1.0]:
				var d := mesh(shell, Geo.plane(f.s, f.s), dm)
				d.position = Vector3(sx * 0.035, f.y, f.z)
				O3.rot(d, 0, sx * PI / 2, 0)
			best = []
		var sz := 0.62
		while sz >= 0.22 and best == null:
			for k in 13:
				if best != null: break
				var zc: float = (z0 + z1) / 2 + (1 if k % 2 else -1) * ceilf(k / 2.0) * 0.06
				var belt: float = K.top(zc) - 0.1
				var sill: float = K.bot(zc) + 0.14
				if belt - sill < sz or zc - sz / 2 < zA or zc + sz / 2 > zB: continue
				for q in 7:
					if best != null: break
					var yc: float = belt - sz / 2 - (belt - sill - sz) * q / 6.0
					var hit := false
					for r in SR:
						if r[1] > zc - sz / 2 - 0.02 and r[0] < zc + sz / 2 + 0.02 and r[3] > yc - sz / 2 - 0.02 and r[2] < yc + sz / 2 + 0.02:
							hit = true
							break
					if not hit: best = [zc, yc, sz]
			sz -= 0.04
		if best != null and not best.is_empty():
			var zc: float = best[0]
			var yc: float = best[1]
			var bs: float = best[2]
			var sg := patch(CarAcc.new(), K.on_side, zc + bs / 2, zc - bs / 2, yc - bs / 2, yc + bs / 2, 4, 4, 0.02, true, true).build()
			if sg != null: mesh(shell, sg, dm)
		# the roof number lies 2 cm on a flat bit of the roof (stripes make way for it, see styleCar); text reads right way
		# round from the chase camera
		var sp = numSpot(K)
		if sp != null:
			if K.numGeo == null:
				K.numGeo = discPatch(CarAcc.new(), sp.f, sp.z, sp.r, 0.02, 5, 32).build()
			var d := mesh(shell, K.numGeo, dm)
			d.sorting_offset = 0.01
	var col = m.get("paint", null)
	if col == null: col = CarPaint.paint(Color.WHITE)
	# a tuned spoiler replaces the factory one; wings, ducktails and exhaust tips are fitted per model (tuneParts)
	if u.get("wing", "std") != "std" and m.has("stockWing"):
		for o in m.stockWing: o.visible = false
	if u.get("wing", "std") == "gt" or u.get("wing", "std") == "duck":
		var t := tuneParts(K, u.wing)
		mesh(shell, t.detail, detailMat, true); mesh(shell, t.paint, col, true)
	# exhaust (classes B and A only): the stock tips make way for a sport, twin or centre-exit set
	var exm = m.g.get_meta("exh", null)
	var ux: String = u.get("exhaust", "std")
	if exm != null and ux != "std" and Cars.CARS.has(m.type) and Cars.CARS[m.type].cls != "S":
		for o in exm.meshes: o.visible = false
		var t := tuneParts(K, ux)
		mesh(shell, t.detail, detailMat)

## the delivery van (traffic): a panel van with glass only round the cab, tall tail lamps, a stripe along the flank
static func _dress_van(K: CarBody, D: Dictionary) -> void:
	dressStd(K, D, {"hl": [{"x": [0.52, 0.92], "y": [0.86, 1.04], "kind": "h_van", "flat": true}], "grille": [{"x": [-0.42, 0.42], "y": [0.9, 1.02], "kind": "g_slats"}, {"x": [-0.7, 0.7], "y": [0.56, 0.74], "kind": "g_slats", "tile": 0.35}],
		"plateF": 0.8, "tl": [{"x": [0.74, 0.96], "y": [0.72, 1.14], "kind": "t_van", "flat": true}], "rtrim": [{"x": [-0.95, 0.95], "y": [0.44, 0.58]}], "plateR": 0.82,
		"mz": 1.72, "my": 1.5, "handles": [0.5, -0.9], "hy": 1.08, "exh": [-0.6]})
	D.deco.color(0x30343a); hSd(K, D.deco, -2.3, 1.9, 0.9, 1.0, 0.02, 12, 1)
	# rear doors: a seam down the middle and two handles
	var y0 := 0.66
	var s = K.on_rear(0, 1.0)
	if s != null:
		D.trim.box(0.014, 1.5, 0.02, 0, 1.75, K.C.z1 - 0.004)
		D.trim.box(0.05, 0.14, 0.03, 0.08, 1.3, K.C.z1 - 0.012); D.trim.box(0.05, 0.14, 0.03, -0.08, 1.3, K.C.z1 - 0.012)
		D.trim.box(0.014, 0.5, 0.02, 0, y0 + 0.25, s[0].z - 0.004)

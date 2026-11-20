extends RefCounted
## The cars and the traffic vehicles.
##
## 1. Every model as approved (tests/golden/cars.json, recorded with `run.py --update cars` after looking at the contact
##    sheets of tools/view_car.py): per mesh in traversal order the triangle count, the bounding box in car space, the material
##    colours and kind, and visibility; plus the rig's fields (len, wid, rc, off, wingY, wingZ, wheel radii).
##    Variants: looks/tuning through styleCar (VARIANTS).
## 2. Things that must be right whatever the model looks like: wheels on the road, lamps front and rear on both sides, nothing
##    through the road, the skin inside the hitbox and the hitbox on the skin (the fit check of the HTML tests), the driver
##    inside the glass, a mesh and triangle budget, every paint finish, the car shader hooked into LMat, brake lights.

const VARIANTS := {
	"num": {"num": 7},
	"tune": {"wing": "gt", "exhaust": "sport", "rimStyle": "spoke", "rim": "gold", "stripe": "white"},
	"duck": {"wing": "duck", "exhaust": "dual", "rimStyle": "dish", "rim": "black", "stripe": "none", "num": 12},
	"center": {"exhaust": "center", "stripe": "yellow", "num": 3},
}
const TOL := 0.003
## what a car may cost: meshes drawn (stock / tuned) and triangles
const MAX_MESHES := 20
const MAX_MESHES_TUNED := 26
const MAX_TRIS := 26000

static func _hex(c: Color) -> int:
	return (int(round(c.r * 255)) << 16) | (int(round(c.g * 255)) << 8) | int(round(c.b * 255))

static func _meshes(n: Node, xf: Transform3D, out: Array) -> void:
	for c in n.get_children():
		var t: Transform3D = xf * c.transform if c is Node3D else xf
		if c is MeshInstance3D:
			out.append([c, t])
		_meshes(c, t, out)

static func dump_nodes(g: Node) -> Array:
	var list := []
	_meshes(g, Transform3D.IDENTITY, list)
	return list.map(func(e): return e[0])

## [triangle corners, min, max] of a mesh in car space
static func _box(o: MeshInstance3D, t: Transform3D) -> Array:
	var mn := Vector3(1e9, 1e9, 1e9)
	var mx := Vector3(-1e9, -1e9, -1e9)
	var tri := 0
	for s in o.mesh.get_surface_count():
		var arr: Array = o.mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ix = arr[Mesh.ARRAY_INDEX]
		tri += ix.size() if ix != null and ix.size() > 0 else vs.size()
		for v in vs:
			var p := t * v
			mn = mn.min(p); mx = mx.max(p)
	return [tri, mn, mx]

static func dump(m: Dictionary) -> Dictionary:
	var list := []
	_meshes(m.g, Transform3D.IDENTITY, list)
	var out := []
	for e in list:
		var o: MeshInstance3D = e[0]
		var b := _box(o, e[1])
		var mn: Vector3 = b[1]
		var mx: Vector3 = b[2]
		var cols := []
		var kind := "?"
		for s in o.mesh.get_surface_count():
			var mat = o.get_active_material(s)
			cols.append(_hex(mat.albedo_color) if mat is LMat else -1)
			if s == 0 and mat is LMat:
				kind = ["L", "P", "B"][mat.kind]
		out.append([b[0], TestReport.r3(mn.x), TestReport.r3(mn.y), TestReport.r3(mn.z), TestReport.r3(mx.x), TestReport.r3(mx.y), TestReport.r3(mx.z), cols, kind, o.visible])
	var wr := []
	for w in m.wheels: wr.append(w.r)
	return {"meshes": out, "len": m.len, "wid": m.wid, "rc": m.rc, "off": m.get("off", 0.0), "wingY": m.get("wingY", null), "wingZ": m.get("wingZ", null), "wheels": wr}

static func build(key: String) -> Dictionary:
	var p := key.split("/")
	if p[0] == "traffic":
		match p[1]:
			"hatch": return Vehicles.buildHatchTraffic(0x2f6db3)
			"van": return Vehicles.makeVan(0xecece8)
			"truck":
				var keep := World.rnd
				World.rnd = Rng.seeded(5)
				var t := Vehicles.makeTruck()
				World.rnd = keep
				return t
			_: return Vehicles.makeTractor()
	if p[1] == "base":
		return CarKit.buildCar(p[0], Color("#d62a2a"))
	var m := CarKit.buildCar(p[0], Color("#1d4f9e"))
	CarKit.styleCar(m, VARIANTS[p[1]])
	return m

## compare one car with its golden entry; "" = equal, else what differs
static func compare(mine: Dictionary, g: Dictionary) -> String:
	for k in ["len", "wid", "rc", "off", "wingZ"]:
		if g[k] != null and absf(float(mine[k]) - float(g[k])) > 1e-6:
			return "%s: nu %s, vastgelegd %s" % [k, mine[k], g[k]]
	if g.wingY != null and absf(float(mine.wingY) - float(g.wingY)) > TOL:
		return "wingY: nu %.4f, vastgelegd %.4f" % [mine.wingY, g.wingY]
	if mine.wheels.size() != g.wheels.size():
		return "wielen: nu %d, vastgelegd %d" % [mine.wheels.size(), g.wheels.size()]
	var a: Array = mine.meshes
	var b: Array = g.meshes
	for i in maxi(a.size(), b.size()):
		if i >= a.size() or i >= b.size():
			return "mesh %d ontbreekt (nu %d meshes, vastgelegd %d)" % [i, a.size(), b.size()]
		var x: Array = a[i]
		var y: Array = b[i]
		if int(x[0]) != int(y[0]):
			return "mesh %d: driehoekshoeken nu %d, vastgelegd %d (kleur %s)" % [i, x[0], y[0], y[7]]
		for k in range(1, 7):
			if absf(float(x[k]) - float(y[k])) > TOL:
				return "mesh %d: bbox nu %s, vastgelegd %s" % [i, str(x.slice(1, 7)), str(y.slice(1, 7))]
		var yc: Array = y[7].map(func(c): return int(c))
		if x[7] != yc:
			return "mesh %d: kleuren nu %s, vastgelegd %s" % [i, x[7], yc]
		if x[8] != y[8]:
			return "mesh %d: materiaal nu %s, vastgelegd %s" % [i, x[8], y[8]]
		if bool(x[9]) != bool(y[9]):
			return "mesh %d: zichtbaar nu %s, vastgelegd %s" % [i, x[9], y[9]]
	return ""

# ---------------------------------------------------------------- what must always be right

## what is wrong with this rig ("" = nothing). tuned: looks from styleCar are on it
static func faults(key: String, m: Dictionary, tuned: bool) -> String:
	var bad := []
	var list := []
	_meshes(m.g, Transform3D.IDENTITY, list)
	var skip := [m.get("beam"), m.get("blob")]
	var wheelMeshes := {}
	for w in m.wheels:
		wheelMeshes[w.mesh] = w
		if absf(w.pivot.position.y - w.r) > 1e-3: bad.append("wielas op %.3f, straal %.3f" % [w.pivot.position.y, w.r])
	var drawn := 0
	var tris := 0
	var low := 1e9
	var lowName := ""
	for e in list:
		var o: MeshInstance3D = e[0]
		if o in skip or not o.visible: continue
		var b := _box(o, e[1])
		drawn += 1
		tris += int(b[0]) / 3
		if wheelMeshes.has(o):
			# a wheel stands on the road: its lowest point within a centimetre of y = 0
			if absf(b[1].y) > 0.012: bad.append("wiel raakt de weg niet (onderkant %.3f)" % b[1].y)
		elif b[1].y < low:
			low = b[1].y
			lowName = str(o.get_meta("geo", null))
	if low < 0.06: bad.append("onderdeel door of op de weg (y = %.3f)" % low)
	var cap := MAX_MESHES_TUNED if tuned else MAX_MESHES
	if key.begins_with("traffic/truck"): cap += 4   # eight wheels
	if drawn > cap: bad.append("%d meshes (max %d)" % [drawn, cap])
	if tris > MAX_TRIS: bad.append("%d driehoeken (max %d)" % [tris, MAX_TRIS])
	# lamps: a front and a rear set, on both sides, at the ends of the car
	var L: float = m.len
	var off: float = m.get("off", 0.0)
	for q in [["lamp", 1.0, "koplampen"], ["tail", -1.0, "achterlichten"]]:
		var o = m.get(q[0], null)
		if o == null:
			bad.append("geen " + q[2])
			continue
		var b := _box(o, o.transform)
		var zEnd: float = b[2].z if q[1] > 0 else b[1].z
		if b[1].x > -0.3 or b[2].x < 0.3: bad.append(q[2] + " niet aan beide kanten")
		if (zEnd - off) * q[1] < L * 0.36: bad.append("%s niet aan het eind van de auto (z = %.2f)" % [q[2], zEnd])
	# brake lights and reversing lamps switch the tail lamps' material
	if m.get("tail") != null:
		var o: MeshInstance3D = m.tail
		CarKit.setLights(m, true, false)
		var okB := o.get_surface_override_material(0) == CarKit.brakeMat
		CarKit.setLights(m, false, true)
		var okR := o.get_surface_override_material(0) == CarKit.revMat
		CarKit.setLights(m, false, false)
		if not (okB and okR and o.get_surface_override_material(0) == CarKit.tailMat): bad.append("remlicht/achteruitrijlicht schakelt niet")
		# and there is a reversing lamp to switch: a cell with a white lamp in the reversing map
		var cells := {}
		for si in o.mesh.get_surface_count():
			for uv in o.mesh.surface_get_arrays(si)[Mesh.ARRAY_TEX_UV]: cells[CarLamps.cellAt(uv)] = true
		if not cells.keys().any(func(k): return k in CarLamps.REV_CELLS): bad.append("geen achteruitrijlicht (achterlichten: %s)" % str(cells.keys()))
	var K = m.get("kit", null)
	if K != null:
		# the skin inside the hitbox, the hitbox on the skin (plan view; mirrors and spoilers left out)
		var f := fit(K, m)
		if f[0] > 0.09 or f[1] > 0.09: bad.append("hitbox past niet: %.3f buiten de carrosserie, carrosserie %.3f buiten de hitbox" % [f[0], f[1]])
		# the driver sits inside the car: under the roof and inside the glass
		if not K.seat.is_empty() and K.C != null:
			var xg: float = K.cabX(K.seat.z, K.seat.y)
			if xg > 0 and K.seat.x + 0.125 > xg - 0.01: bad.append("helm door de zijruit (x %.2f, ruit %.2f)" % [K.seat.x, xg])
			if K.seat.y + 0.13 > K.roof(K.seat.z) - 0.01: bad.append("helm door het dak")
		if m.get("driver") == null and K.has_hole: bad.append("geen coureur")
		if K.lines_tex == null: bad.append("geen paneellijnen")
	return "; ".join(bad)

static func _hull(pts: Array) -> Array:
	pts = pts.duplicate()
	pts.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	var cr := func(o: Vector2, a: Vector2, b: Vector2) -> float: return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
	var lo := []
	var up := []
	for p in pts:
		while lo.size() >= 2 and cr.call(lo[-2], lo[-1], p) <= 0: lo.pop_back()
		lo.append(p)
	for i in range(pts.size() - 1, -1, -1):
		var p: Vector2 = pts[i]
		while up.size() >= 2 and cr.call(up[-2], up[-1], p) <= 0: up.pop_back()
		up.append(p)
	up.pop_back(); lo.pop_back()
	return lo + up

static func _sdist(p: Vector2, H: Array) -> float:
	var d := 1e9
	var inside := false
	var j := H.size() - 1
	for i in H.size():
		var a: Vector2 = H[i]
		var b: Vector2 = H[j]
		d = minf(d, (p - Geometry2D.get_closest_point_to_segment(p, a, b)).length())
		if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x: inside = not inside
		j = i
	return -d if inside else d

## [how far the hitbox sticks out of the body's footprint, how far the footprint sticks out of the hitbox] (m, plan view)
static func fit(K: CarBody, m: Dictionary) -> Array:
	var P := []
	for g in [K.body, K.cab]:
		if g == null: continue
		for v in g.pos: P.append(Vector2(v.x, v.z))
	var H := _hull(P)
	var O := []
	var rc: float = m.rc
	var a: float = m.len / 2.0 - rc
	var b: float = m.wid / 2.0 - rc
	for c in [[b, a, 0.0], [-b, a, PI / 2], [-b, -a, PI], [b, -a, PI * 1.5]]:
		for k in 9:
			var t: float = c[2] + k / 8.0 * PI / 2
			O.append(Vector2(c[0] + cos(t) * rc, c[1] + sin(t) * rc + m.get("off", 0.0)))
	var out := -1e9
	for p in O: out = maxf(out, _sdist(p, H))
	var Hb := _hull(O)
	var miss := -1e9
	for p in H: miss = maxf(miss, _sdist(p, Hb))
	return [out, miss]

func run(host: Node) -> TestReport:
	var r := TestReport.new("auto's en verkeer: zoals vastgelegd (golden/cars.json) en wat altijd moet kloppen")
	var gold: Dictionary = TestReport.load_golden("cars")
	var upd := TestReport.updating()
	if World.root == null:
		World.root = Node3D.new()
		host.add_child(World.root)
	var only := OS.get_environment("CARS")
	# the car shader hangs on LMat's: without its anchors the cars are plain LMat (still lit, but no gloss, no real glass)
	var probe := CarPaint.paint(Color.RED)
	r.check(CarPaint.hooked and probe.shader != null and probe.shader.code.find("cp_env") > 0, "autolak haakt in op de LMat-shader", "ankers gevonden" if CarPaint.hooked else "anker weg: zie CarPaint._patch")
	var fins := []
	for f in CarPaint.FINISHES:
		var pm := CarPaint.paint(Color("#1d4f9e"), f)
		if pm.shader == null or pm.finish != f or not CarPaint.FINISH_NAMES.has(f): fins.append(f)
	r.check(fins.is_empty(), "elke lakafwerking bouwt", str(CarPaint.FINISHES.keys()) if fins.is_empty() else "mislukt: " + str(fins))
	# every car model plain and in every variant of VARIANTS, plus the traffic vehicles
	var keys := []
	for id in Cars.CARS:
		keys.append(id + "/base")
		for v in VARIANTS: keys.append("%s/%s" % [id, v])
	for t in ["hatch", "van", "truck", "tractor"]: keys.append("traffic/" + t)
	for key in keys:
		if only != "" and not key.split("/")[0] in only.split(","): continue
		var t0 := Time.get_ticks_msec()
		var m := build(key)
		var ms := Time.get_ticks_msec() - t0
		if upd:
			gold[key] = dump(m)      # record this model as the approved state
			r.check(true, key + ": vastgelegd", "%d meshes" % gold[key].meshes.size())
		elif not gold.has(key):
			r.check(false, key, "staat niet in golden/cars.json (leg vast met run.py --update cars)")
		else:
			var bad := compare(dump(m), gold[key])
			r.check(bad == "", key, bad if bad != "" else "%d meshes (%d ms)" % [gold[key].meshes.size(), ms])
		var tuned: bool = not (key.ends_with("/base") or key.begins_with("traffic/"))
		if key.ends_with("/base") or key.ends_with("/tune") or key.ends_with("/duck") or key.begins_with("traffic/"):
			var fl := faults(key, m, tuned)
			r.check(fl == "", key + ": klopt", fl)
		# a finish from the garage ends up on the paint
		if key.ends_with("/base"):
			CarKit.styleCar(m, {"finish": "metallic"})
			r.check(m.paint.finish == "metallic", key + ": afwerking via styleCar", m.paint.finish)
		# hold the materials until the nodes are gone (the headless renderer complains about a material freed first)
		var keep := []
		for e in dump_nodes(m.g):
			for s in e.mesh.get_surface_count(): keep.append(e.get_surface_override_material(s))
		m.g.free()
		keep.clear()
	if upd: TestReport.save_golden("cars", gold)
	return r

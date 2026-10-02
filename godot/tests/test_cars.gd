extends RefCounted
## Every car model (and the traffic vehicles) against the HTML game's own build (tests/golden/cars.json, made by
## tools/export_cars.py): per mesh in traversal order the triangle count, the bounding box in car space, the material
## colours and kind, and visibility; plus the car's fields (len, wid, rc, off, wingY, wingZ, wheel radii).
## Variants: looks/tuning through styleCar (same table as tools/export_cars.py).

const VARIANTS := {
	"num": {"num": 7},
	"tune": {"wing": "gt", "exhaust": "sport", "rimStyle": "spoke", "rim": "gold", "stripe": "white"},
	"duck": {"wing": "duck", "exhaust": "dual", "rimStyle": "dish", "rim": "black", "stripe": "none", "num": 12},
	"center": {"exhaust": "center", "stripe": "yellow", "num": 3},
}
const TOL := 0.003

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

static func dump(m: Dictionary) -> Dictionary:
	var list := []
	_meshes(m.g, Transform3D.IDENTITY, list)
	var out := []
	for e in list:
		var o: MeshInstance3D = e[0]
		var t: Transform3D = e[1]
		var mn := Vector3(1e9, 1e9, 1e9)
		var mx := Vector3(-1e9, -1e9, -1e9)
		var tri := 0
		var cols := []
		var kind := "?"
		for s in o.mesh.get_surface_count():
			var arr: Array = o.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ix = arr[Mesh.ARRAY_INDEX]
			tri += ix.size() if ix != null and ix.size() > 0 else vs.size()
			for v in vs:
				var p := t * v
				mn = mn.min(p); mx = mx.max(p)
			var mat = o.get_active_material(s)
			cols.append(_hex(mat.albedo_color) if mat is LMat else -1)
			if s == 0 and mat is LMat:
				kind = ["L", "P", "B"][mat.kind]
		out.append([tri, mn.x, mn.y, mn.z, mx.x, mx.y, mx.z, cols, kind, o.visible])
	var wr := []
	for w in m.wheels: wr.append(w.r)
	return {"meshes": out, "len": m.len, "wid": m.wid, "rc": m.rc, "off": m.get("off", 0.0), "wingY": m.get("wingY", null), "wingZ": m.get("wingZ", null), "wheels": wr}

static func build(key: String) -> Dictionary:
	var p := key.split("/")
	if p[0] == "traffic":
		match p[1]:
			"hatch": return Vehicles.buildHatchTraffic(0x2f6db3)
			"van": return Vehicles.makeVan()
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
			return "%s: godot %s, html %s" % [k, mine[k], g[k]]
	if g.wingY != null and absf(float(mine.wingY) - float(g.wingY)) > TOL:
		return "wingY: godot %.4f, html %.4f" % [mine.wingY, g.wingY]
	if mine.wheels.size() != g.wheels.size():
		return "wielen: godot %d, html %d" % [mine.wheels.size(), g.wheels.size()]
	var a: Array = mine.meshes
	var b: Array = g.meshes
	for i in maxi(a.size(), b.size()):
		if i >= a.size() or i >= b.size():
			return "mesh %d ontbreekt (godot %d meshes, html %d)" % [i, a.size(), b.size()]
		var x: Array = a[i]
		var y: Array = b[i]
		if int(x[0]) != int(y[0]):
			return "mesh %d: driehoekshoeken godot %d, html %d (kleur %s)" % [i, x[0], y[0], y[7]]
		for k in range(1, 7):
			if absf(float(x[k]) - float(y[k])) > TOL:
				return "mesh %d: bbox godot %s, html %s" % [i, str(x.slice(1, 7)), str(y.slice(1, 7))]
		var yc: Array = y[7].map(func(c): return int(c))
		if x[7] != yc:
			return "mesh %d: kleuren godot %s, html %s" % [i, x[7], yc]
		if x[8] != y[8]:
			return "mesh %d: materiaal godot %s, html %s" % [i, x[8], y[8]]
		if bool(x[9]) != bool(y[9]):
			return "mesh %d: zichtbaar godot %s, html %s" % [i, x[9], y[9]]
	return ""

func run(host: Node) -> TestReport:
	var r := TestReport.new("auto's en verkeer gelijk aan de HTML-versie")
	var gold: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/cars.json"))
	if World.root == null:
		World.root = Node3D.new()
		host.add_child(World.root)
	var only := OS.get_environment("CARS")
	for key in gold:
		if only != "" and not key.split("/")[0] in only.split(","): continue
		var t0 := Time.get_ticks_msec()
		var m := build(key)
		var ms := Time.get_ticks_msec() - t0
		var bad := compare(dump(m), gold[key])
		r.check(bad == "", key, bad if bad != "" else "%d meshes (%d ms)" % [gold[key].meshes.size(), ms])
		# hold the materials until the nodes are gone (the headless renderer complains about a material freed first)
		var keep := []
		for e in dump_nodes(m.g):
			for s in e.mesh.get_surface_count(): keep.append(e.get_surface_override_material(s))
		m.g.free()
		keep.clear()
	return r

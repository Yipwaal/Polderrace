extends RefCounted
## The geometry of a built world for the map tests (roadclear, zfight, ground): every visible mesh and every instance
## of every MultiMesh under a root as an Item with its transform to world space, its world box and its triangles.
## Use it on a world straight from TrackLoader.build_world (before World.batch merges the boxes of one object, so
## an item still is one box / one roof / one sail and can be described by its size, colour and place).

class Item:
	var node: Node3D
	var k := -1                 ## instance index in a MultiMesh; -1 = a MeshInstance3D
	var count := 1              ## instances in that MultiMesh
	var xf: Transform3D         ## local -> world
	var mesh: Mesh
	var box: AABB               ## world
	var id := 0
	var gate := false           ## part of a start / checkpoint gate (World.cpGates)

var items: Array = []
var _surf := {}                 ## mesh instance id -> Array of {v: PackedVector3Array (3 per triangle, local), n: normals or null, mat: Material}

## build a track the way the map tests need it: not batched, the instance transforms kept (World.inst_log)
static func build(id: String, dir: String) -> void:
	World.inst_log = []
	TrackLoader.build_world(id, dir)
	World.inst_log = null

func collect(root: Node3D) -> void:
	items = []
	var gates := {}
	for g in World.cpGates: gates[g] = true
	_walk(root, Transform3D.IDENTITY, false, gates)

func _walk(n: Node, xf: Transform3D, gate: bool, gates: Dictionary) -> void:
	for c in n.get_children():
		if not (c is Node3D) or not c.visible: continue
		var t: Transform3D = xf * c.transform
		var g: bool = gate or gates.has(c)
		if c is MeshInstance3D and c.mesh != null:
			var it := Item.new()
			it.node = c; it.xf = t; it.mesh = c.mesh; it.box = t * c.mesh.get_aabb(); it.id = items.size(); it.gate = g
			items.append(it)
		elif c is MultiMeshInstance3D and c.multimesh != null and c.multimesh.mesh != null:
			var mm: MultiMesh = c.multimesh
			var lb := mm.mesh.get_aabb()
			var cnt := mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
			# headless Godot does not keep a MultiMesh's transforms: World.inst leaves them on the node while World.inst_log is set
			var xfs = c.get_meta("xfs", null)
			for k in cnt:
				var it := Item.new()
				it.node = c; it.k = k; it.count = cnt; it.xf = t * (xfs[k] if xfs != null else mm.get_instance_transform(k)); it.mesh = mm.mesh
				it.box = it.xf * lb; it.id = items.size(); it.gate = g
				items.append(it)
		_walk(c, t, g, gates)

## the triangle surfaces of a mesh in its own space (cached): [{v, n, mat}], lines and points left out
func surfaces(mesh: Mesh) -> Array:
	var key := mesh.get_instance_id()
	if _surf.has(key): return _surf[key]
	var out := []
	for s in mesh.get_surface_count():
		if mesh is ArrayMesh and mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES: continue
		var a: Array = mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ns = a[Mesh.ARRAY_NORMAL]
		var ix = a[Mesh.ARRAY_INDEX]
		var v := PackedVector3Array()
		var nn = null
		if ix != null:
			var pi: PackedInt32Array = ix
			v.resize(pi.size())
			for i in pi.size(): v[i] = vs[pi[i]]
			if ns != null:
				var src: PackedVector3Array = ns
				var o := PackedVector3Array(); o.resize(pi.size())
				for i in pi.size(): o[i] = src[pi[i]]
				nn = o
		else:
			v = vs
			nn = ns
		out.append({"v": v, "n": nn, "mat": mesh.surface_get_material(s)})
	_surf[key] = out
	return out

## the material an item draws surface s with
func material(it: Item, surf: Dictionary) -> Material:
	if it.node is MeshInstance3D and it.node.material_override != null: return it.node.material_override
	if it.node is MultiMeshInstance3D and it.node.material_override != null: return it.node.material_override
	return surf.mat

## not something you could bump into or see flicker: (nearly) see-through, glow, drawn without depth
static func ghost(m: Material) -> bool:
	if not (m is LMat): return false
	var lm: LMat = m
	if lm.blend_mode != BaseMaterial3D.BLEND_MODE_MIX or lm.no_depth_test: return true
	return lm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and lm.albedo_color.a < 0.3

static func see_through(m: Material) -> bool:
	return m is LMat and (m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA or m.blend_mode != BaseMaterial3D.BLEND_MODE_MIX)

static func two_sided(m: Material) -> bool:
	return m is LMat and m.cull_mode == BaseMaterial3D.CULL_DISABLED

static func colour(m: Material) -> String:
	if m is LMat:
		return "#" + (m.albedo_color as Color).to_html(false) + ("+tex" if m.albedo_texture != null else "")
	return "?"

## size of an item along its own axes (w x h x d of a box as it was built, scale included)
func size(it: Item) -> Vector3:
	var s := it.mesh.get_aabb().size
	return Vector3(s.x * it.xf.basis.x.length(), s.y * it.xf.basis.y.length(), s.z * it.xf.basis.z.length())

## what an item is, for a report line: "inst x240 0.16x1.10x0.16 #f2f2ec" (the same for every instance / copy of it)
func kind(it: Item) -> String:
	var s := size(it)
	var surfs := surfaces(it.mesh)
	var col := colour(material(it, surfs[0])) if not surfs.is_empty() else "?"
	var shape := "mesh"
	if not surfs.is_empty():
		var nv: int = surfs[0].v.size()
		shape = "kast" if nv == 36 and surfs.size() == 1 else ("vlak" if nv == 6 else ("strook" if s.x > 200 or s.z > 200 else "mesh %d dr." % (nv / 3)))
		if surfs.size() > 1: shape = "kast/mesh met %d materialen" % surfs.size()
	return "%s%s %.2fx%.2fx%.2f %s" % ["inst " if it.k >= 0 else "", shape, s.x, s.y, s.z, col]

static func xz(v: Vector3) -> String:
	return "x=%.0f z=%.0f" % [v.x, v.z]

## track position of a world point: [distance along the lap (m), metres right of the centre line]
static func track_pos(p: Vector3) -> Array:
	var b := 1e18
	var bi := 0
	for i in Trk.NS:
		var q := Trk.P[i]
		var d := (p.x - q.x) * (p.x - q.x) + (p.z - q.z) * (p.z - q.z)
		if d < b: b = d; bi = i
	var q := Trk.P[bi]
	return [bi * Trk.SPC + (p.x - q.x) * Trk.T[bi].x + (p.z - q.z) * Trk.T[bi].z, (p.x - q.x) * Trk.R[bi].x + (p.z - q.z) * Trk.R[bi].z]

## clip a convex polygon to c[axis] >= lo (keep = +1) or <= hi (keep = -1): Sutherland-Hodgman, one plane
static func clip(poly: PackedVector3Array, axis: int, bound: float, keep: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := poly.size()
	if n == 0: return out
	var a := poly[n - 1]
	var da := (a[axis] - bound) * keep
	for i in n:
		var b := poly[i]
		var db := (b[axis] - bound) * keep
		if db >= 0.0:
			if da < 0.0: out.append(a + (b - a) * (da / (da - db)))
			out.append(b)
		elif da >= 0.0:
			out.append(a + (b - a) * (da / (da - db)))
		a = b; da = db
	return out

static func clip_range(poly: PackedVector3Array, axis: int, lo: float, hi: float) -> PackedVector3Array:
	return clip(clip(poly, axis, lo, 1.0), axis, hi, -1.0)

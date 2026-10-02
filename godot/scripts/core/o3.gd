class_name O3
## three.js-like scene helpers: groups and meshes with position / rotation (Euler order XYZ, as three.js) / scale,
## so ported code can say O3.mesh(Geo.box(1,2,3), mat, x, y, z) like `new THREE.Mesh(...)` + position.set.
## Note: three.js meshes do NOT cast shadows unless castShadow = true; Godot meshes do by default. mesh() follows three.js
## (cast = false) unless you pass cast = true.

## three Euler(rx, ry, rz, 'XYZ') as a Basis: Rx * Ry * Rz
static func euler(rx: float, ry: float, rz: float) -> Basis:
	return Basis(Vector3.RIGHT, rx) * Basis(Vector3.UP, ry) * Basis(Vector3.BACK, rz)

static func group(x := 0.0, y := 0.0, z := 0.0, parent: Node = null) -> Node3D:
	var g := Node3D.new()
	g.position = Vector3(x, y, z)
	if parent != null:
		parent.add_child(g)
	return g

## a mesh node from a Geo (or a ready Mesh); mats: Material or Array (per geometry group, see Geo.to_mesh)
static func mesh(geo, mats, x := 0.0, y := 0.0, z := 0.0, parent: Node = null, cast := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = geo.to_mesh(mats) if geo is Geo else geo
	mi.position = Vector3(x, y, z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if parent != null:
		parent.add_child(mi)
	return mi

## set rotation the three.js way (order XYZ), keeping position and scale
static func rot(n: Node3D, rx: float, ry: float, rz: float) -> Node3D:
	var s := n.scale
	n.basis = euler(rx, ry, rz).scaled_local(s) if s != Vector3.ONE else euler(rx, ry, rz)
	return n

static func set_scale(n: Node3D, sx: float, sy := -1.0, sz := -1.0) -> Node3D:
	if sy < 0: sy = sx
	if sz < 0: sz = sx
	n.scale = Vector3(sx, sy, sz)
	return n

## three Matrix4 compose(position, euler XYZ, scale) as a Transform3D (for instancing, see World.inst)
static func mtx(x: float, y: float, z: float, ry := 0.0, sx := 1.0, sy := -1.0, sz := -1.0) -> Transform3D:
	if sy < 0: sy = sx
	if sz < 0: sz = sx
	return Transform3D(Basis(Vector3.UP, ry).scaled_local(Vector3(sx, sy, sz)), Vector3(x, y, z))

## free a node tree (meshes and materials go with it; shared resources are reference counted in Godot)
static func dispose(n: Node) -> void:
	if n != null and is_instance_valid(n):
		n.queue_free()

## a polyline (JS THREE.Line with LineBasicMaterial) through world points
static func line(points: Array, color: int, parent: Node = null, strip := true) -> MeshInstance3D:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array(points)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP if strip else Mesh.PRIMITIVE_LINES, arr)
	m.surface_set_material(0, Mats.basic(color))
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if parent != null:
		parent.add_child(mi)
	return mi

## wireframe of a Geo (JS MeshBasicMaterial({wireframe:true})): every triangle edge once, unlit
static func wire(geo: Geo, color: int, parent: Node = null) -> MeshInstance3D:
	var seen := {}
	var pts := PackedVector3Array()
	var tri := geo.idx if not geo.idx.is_empty() else PackedInt32Array(range(geo.pos.size()))
	for i in range(0, tri.size(), 3):
		for e in [[tri[i], tri[i + 1]], [tri[i + 1], tri[i + 2]], [tri[i + 2], tri[i]]]:
			var a: int = mini(e[0], e[1])
			var b: int = maxi(e[0], e[1])
			var k := a * 1000003 + b
			if seen.has(k):
				continue
			seen[k] = true
			pts.append(geo.pos[a]); pts.append(geo.pos[b])
	return line(Array(pts), color, parent, false)

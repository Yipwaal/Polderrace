class_name CarAcc
extends RefCounted
## Port of the HTML game's Acc() geometry accumulator: collects triangles (with normals, optional vertex colour and uv)
## and turns them into one non-indexed Geo, so a car needs one mesh per material instead of one per part.
## Positions and normals use three.js conventions (counter-clockwise triangles), like Geo.

var P := PackedVector3Array()
var N := PackedVector3Array()
var C := PackedColorArray()
var U := PackedVector2Array()
var col = null   ## Color or null (= white)

const WHITE := Color(1, 1, 1)

## JS A.color(c): the vertex colour of what follows (null = white). c: hex int or Color
func color(c = null) -> CarAcc:
	if c == null:
		col = null
	elif c is Color:
		col = c
	else:
		col = MathX.col(int(c))
	return self

## JS A.geo(g, m): add a geometry (indexed or not), optionally transformed by m
func geo(g: Geo, m = null) -> CarAcc:
	var q := g.to_non_indexed() if not g.idx.is_empty() else g
	var has_uv := q.uv.size() == q.pos.size()
	var c: Color = col if col != null else WHITE
	if m != null:
		var t: Transform3D = m
		var nb := t.basis.inverse().transposed()
		for i in q.pos.size():
			P.append(t * q.pos[i])
			N.append((nb * q.nrm[i]).normalized())
	else:
		P.append_array(q.pos)
		N.append_array(q.nrm)
	for i in q.pos.size():
		C.append(c)
		U.append(q.uv[i] if has_uv else Vector2.ZERO)
	return self

## box of size w,h,d at x,y,z, rotated by euler rx,ry,rz (order XYZ)
func box(w: float, h: float, d: float, x: float, y: float, z: float, rx := 0.0, ry := 0.0, rz := 0.0) -> CarAcc:
	return geo(Geo.box(w, h, d), Transform3D(O3.euler(rx, ry, rz), Vector3(x, y, z)))

## box standing on a body surface: p = surface point, n = outward normal; it pokes out `out` metres and sinks `d-out` into the body
func boxOn(w: float, h: float, d: float, p: Vector3, n: Vector3, out: float, up = null) -> CarAcc:
	var z := n.normalized()
	var u: Vector3 = up if up != null else Vector3(0, 1, 0)
	var y := u - z * u.dot(z)
	if y.length_squared() < 1e-6:
		y = Vector3(0, 0, 1) - z * z.z
	y = y.normalized()
	var x := y.cross(z)
	return geo(Geo.box(w, h, d), Transform3D(Basis(x, y, z), p + z * (out - d / 2.0)))

## one triangle; uv (Vector2 or null = 0,0) per corner
func tri(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ua = null, ub = null, uc = null) -> CarAcc:
	var k: Color = col if col != null else WHITE
	P.append(a); P.append(b); P.append(c)
	N.append(na); N.append(nb); N.append(nc)
	C.append(k); C.append(k); C.append(k)
	U.append(ua if ua != null else Vector2.ZERO)
	U.append(ub if ub != null else Vector2.ZERO)
	U.append(uc if uc != null else Vector2.ZERO)
	return self

## the collected triangles as one Geo (null when empty)
func build() -> Geo:
	if P.is_empty():
		return null
	var g := Geo.new()
	g.pos = P.duplicate()
	g.nrm = N.duplicate()
	g.col = C.duplicate()
	g.uv = U.duplicate()
	return g

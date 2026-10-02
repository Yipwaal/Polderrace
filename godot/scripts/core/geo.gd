class_name Geo
## A three.js-style BufferGeometry: exact ports of the r128 geometry generators the HTML game uses (box, cylinder/cone,
## plane, sphere, torus, circle, ring, lathe, extrude, icosahedron), plus translate/rotate/scale/computeVertexNormals.
## Data is kept in three.js conventions (counter-clockwise triangles, uv with v up); to_mesh() converts to Godot
## (clockwise front faces, v down), so ported code can use the same numbers as the JS and textures land the same way.

var pos := PackedVector3Array()
var nrm := PackedVector3Array()
var uv := PackedVector2Array()
var col := PackedColorArray()        ## optional vertex colours (same length as pos when used)
var idx := PackedInt32Array()        ## empty = non-indexed
var groups: Array = []               ## [start, count, material_index] over idx (or over vertices when non-indexed)

# ---------------------------------------------------------------- generators (three.js r128)

static func box(width := 1.0, height := 1.0, depth := 1.0, ws := 1, hs := 1, ds := 1) -> Geo:
	var g := Geo.new()
	var st := {"nv": 0, "gs": 0}
	var bp := func(u: int, v: int, w: int, udir: float, vdir: float, wd: float, ht: float, dp: float, gx: int, gy: int, mi: int) -> void:
		var sw := wd / gx
		var sh := ht / gy
		var whalf := wd / 2.0
		var hhalf := ht / 2.0
		var dhalf := dp / 2.0
		var gx1 := gx + 1
		var gy1 := gy + 1
		var vc := 0
		var gc := 0
		for iy in gy1:
			var y := iy * sh - hhalf
			for ix in gx1:
				var x := ix * sw - whalf
				var vec := [0.0, 0.0, 0.0]
				vec[u] = x * udir
				vec[v] = y * vdir
				vec[w] = dhalf
				g.pos.append(Vector3(vec[0], vec[1], vec[2]))
				var n := [0.0, 0.0, 0.0]
				n[w] = 1.0 if dp > 0 else -1.0
				g.nrm.append(Vector3(n[0], n[1], n[2]))
				g.uv.append(Vector2(float(ix) / gx, 1.0 - float(iy) / gy))
				vc += 1
		for iy in gy:
			for ix in gx:
				var a: int = st.nv + ix + gx1 * iy
				var b: int = st.nv + ix + gx1 * (iy + 1)
				var c: int = st.nv + (ix + 1) + gx1 * (iy + 1)
				var d: int = st.nv + (ix + 1) + gx1 * iy
				g.idx.append_array([a, b, d, b, c, d])
				gc += 6
		g.groups.append([st.gs, gc, mi])
		st.gs += gc
		st.nv += vc
	# axes: x=0, y=1, z=2
	bp.call(2, 1, 0, -1.0, -1.0, depth, height, width, ds, hs, 0)   # px
	bp.call(2, 1, 0, 1.0, -1.0, depth, height, -width, ds, hs, 1)   # nx
	bp.call(0, 2, 1, 1.0, 1.0, width, depth, height, ws, ds, 2)     # py
	bp.call(0, 2, 1, 1.0, -1.0, width, depth, -height, ws, ds, 3)   # ny
	bp.call(0, 1, 2, 1.0, -1.0, width, height, depth, ws, hs, 4)    # pz
	bp.call(0, 1, 2, -1.0, -1.0, width, height, -depth, ws, hs, 5)  # nz
	return g

static func cylinder(rt := 1.0, rb := 1.0, height := 1.0, rs := 8, hs := 1, open_ended := false, ts := 0.0, tl := TAU) -> Geo:
	var g := Geo.new()
	var index := 0
	var rows: Array = []
	var hh := height / 2.0
	var gstart := 0
	var gc := 0
	var slope := (rb - rt) / height
	for y in hs + 1:
		var row: Array[int] = []
		var v := float(y) / hs
		var radius := v * (rb - rt) + rt
		for x in rs + 1:
			var u := float(x) / rs
			var theta := u * tl + ts
			var s := sin(theta)
			var c := cos(theta)
			g.pos.append(Vector3(radius * s, -v * height + hh, radius * c))
			g.nrm.append(Vector3(s, slope, c).normalized())
			g.uv.append(Vector2(u, 1.0 - v))
			row.append(index)
			index += 1
		rows.append(row)
	for x in rs:
		for y in hs:
			var a: int = rows[y][x]
			var b: int = rows[y + 1][x]
			var c: int = rows[y + 1][x + 1]
			var d: int = rows[y][x + 1]
			g.idx.append_array([a, b, d, b, c, d])
			gc += 6
	g.groups.append([gstart, gc, 0])
	gstart += gc
	if not open_ended:
		for top in [true, false]:
			var radius := rt if top else rb
			if radius <= 0.0:
				continue
			var sign := 1.0 if top else -1.0
			var cstart := index
			for _x in rs:
				g.pos.append(Vector3(0, hh * sign, 0)); g.nrm.append(Vector3(0, sign, 0)); g.uv.append(Vector2(0.5, 0.5)); index += 1
			var cend := index
			for x in rs + 1:
				var u := float(x) / rs
				var theta := u * tl + ts
				var c := cos(theta)
				var s := sin(theta)
				g.pos.append(Vector3(radius * s, hh * sign, radius * c))
				g.nrm.append(Vector3(0, sign, 0))
				g.uv.append(Vector2(c * 0.5 + 0.5, s * 0.5 * sign + 0.5))
				index += 1
			var cc := 0
			for x in rs:
				var c2 := cstart + x
				var i := cend + x
				if top:
					g.idx.append_array([i, i + 1, c2])
				else:
					g.idx.append_array([i + 1, i, c2])
				cc += 3
			g.groups.append([gstart, cc, 1 if top else 2])
			gstart += cc
	return g

static func cone(radius := 1.0, height := 1.0, rs := 8, hs := 1, open_ended := false, ts := 0.0, tl := TAU) -> Geo:
	return cylinder(0.0, radius, height, rs, hs, open_ended, ts, tl)

static func plane(width := 1.0, height := 1.0, ws := 1, hs := 1) -> Geo:
	var g := Geo.new()
	var gx1 := ws + 1
	var sw := width / ws
	var sh := height / hs
	for iy in hs + 1:
		var y := iy * sh - height / 2.0
		for ix in gx1:
			var x := ix * sw - width / 2.0
			g.pos.append(Vector3(x, -y, 0)); g.nrm.append(Vector3(0, 0, 1)); g.uv.append(Vector2(float(ix) / ws, 1.0 - float(iy) / hs))
	for iy in hs:
		for ix in ws:
			var a := ix + gx1 * iy
			var b := ix + gx1 * (iy + 1)
			var c := (ix + 1) + gx1 * (iy + 1)
			var d := (ix + 1) + gx1 * iy
			g.idx.append_array([a, b, d, b, c, d])
	return g

static func sphere(radius := 1.0, ws := 8, hs := 6, phs := 0.0, phl := TAU, ths := 0.0, thl := PI) -> Geo:
	var g := Geo.new()
	ws = maxi(3, ws)
	hs = maxi(2, hs)
	var the := minf(ths + thl, PI)
	var index := 0
	var grid: Array = []
	for iy in hs + 1:
		var row: Array[int] = []
		var v := float(iy) / hs
		var uo := 0.0
		if iy == 0 and ths == 0.0:
			uo = 0.5 / ws
		elif iy == hs and the == PI:
			uo = -0.5 / ws
		for ix in ws + 1:
			var u := float(ix) / ws
			var vx := -radius * cos(phs + u * phl) * sin(ths + v * thl)
			var vy := radius * cos(ths + v * thl)
			var vz := radius * sin(phs + u * phl) * sin(ths + v * thl)
			var p := Vector3(vx, vy, vz)
			g.pos.append(p)
			g.nrm.append(p.normalized())
			g.uv.append(Vector2(u + uo, 1.0 - v))
			row.append(index)
			index += 1
		grid.append(row)
	for iy in hs:
		for ix in ws:
			var a: int = grid[iy][ix + 1]
			var b: int = grid[iy][ix]
			var c: int = grid[iy + 1][ix]
			var d: int = grid[iy + 1][ix + 1]
			if iy != 0 or ths > 0.0:
				g.idx.append_array([a, b, d])
			if iy != hs - 1 or the < PI:
				g.idx.append_array([b, c, d])
	return g

static func torus(radius := 1.0, tube := 0.4, rs := 8, ts := 6, arc := TAU) -> Geo:
	var g := Geo.new()
	for j in rs + 1:
		for i in ts + 1:
			var u := float(i) / ts * arc
			var v := float(j) / rs * TAU
			var p := Vector3((radius + tube * cos(v)) * cos(u), (radius + tube * cos(v)) * sin(u), tube * sin(v))
			g.pos.append(p)
			g.nrm.append((p - Vector3(radius * cos(u), radius * sin(u), 0)).normalized())
			g.uv.append(Vector2(float(i) / ts, float(j) / rs))
	for j in range(1, rs + 1):
		for i in range(1, ts + 1):
			var a := (ts + 1) * j + i - 1
			var b := (ts + 1) * (j - 1) + i - 1
			var c := (ts + 1) * (j - 1) + i
			var d := (ts + 1) * j + i
			g.idx.append_array([a, b, d, b, c, d])
	return g

static func circle(radius := 1.0, segments := 8, ts := 0.0, tl := TAU) -> Geo:
	var g := Geo.new()
	segments = maxi(3, segments)
	g.pos.append(Vector3.ZERO); g.nrm.append(Vector3(0, 0, 1)); g.uv.append(Vector2(0.5, 0.5))
	for s in segments + 1:
		var seg := ts + float(s) / segments * tl
		var p := Vector3(radius * cos(seg), radius * sin(seg), 0)
		g.pos.append(p); g.nrm.append(Vector3(0, 0, 1)); g.uv.append(Vector2((p.x / radius + 1) / 2, (p.y / radius + 1) / 2))
	for i in range(1, segments + 1):
		g.idx.append_array([i, i + 1, 0])
	return g

static func ring(inner := 0.5, outer := 1.0, tseg := 8, pseg := 1, ts := 0.0, tl := TAU) -> Geo:
	var g := Geo.new()
	tseg = maxi(3, tseg)
	pseg = maxi(1, pseg)
	var radius := inner
	var step := (outer - inner) / pseg
	for j in pseg + 1:
		for i in tseg + 1:
			var seg := ts + float(i) / tseg * tl
			var p := Vector3(radius * cos(seg), radius * sin(seg), 0)
			g.pos.append(p); g.nrm.append(Vector3(0, 0, 1)); g.uv.append(Vector2((p.x / outer + 1) / 2, (p.y / outer + 1) / 2))
		radius += step
	for j in pseg:
		var lvl := j * (tseg + 1)
		for i in tseg:
			var s := i + lvl
			g.idx.append_array([s, s + tseg + 1, s + 1, s + tseg + 1, s + tseg + 2, s + 1])
	return g

## points: Array of Vector2 (x = radius, y = height)
static func lathe(points: Array, segments := 12, phs := 0.0, phl := TAU) -> Geo:
	var g := Geo.new()
	phl = clampf(phl, 0.0, TAU)
	var n := points.size()
	for i in segments + 1:
		var phi := phs + float(i) / segments * phl
		var s := sin(phi)
		var c := cos(phi)
		for j in n:
			var pt: Vector2 = points[j]
			g.pos.append(Vector3(pt.x * s, pt.y, pt.x * c))
			g.uv.append(Vector2(float(i) / segments, float(j) / (n - 1)))
	for i in segments:
		for j in n - 1:
			var base := j + i * n
			var a := base
			var b := base + n
			var c := base + n + 1
			var d := base + 1
			g.idx.append_array([a, b, d, b, c, d])
	g.compute_vertex_normals()
	if phl == TAU:
		var base := segments * n
		for j in n:
			var m := (g.nrm[j] + g.nrm[base + j]).normalized()
			g.nrm[j] = m
			g.nrm[base + j] = m
	return g

## extrude a 2D outline (Array of Vector2) by depth along +z, no bevel (three ExtrudeGeometry with bevelEnabled:false)
static func extrude(shape: Array, depth := 1.0) -> Geo:
	var pts := PackedVector2Array(shape)
	# three keeps the contour clockwise (ShapeUtils.isClockWise: area < 0)
	var area := 0.0
	for i in pts.size():
		var a := pts[(i + pts.size() - 1) % pts.size()]
		var b := pts[i]
		area += a.x * b.y - b.x * a.y
	if area >= 0.0:  # counter-clockwise -> reverse
		pts.reverse()
	var tris := Geometry2D.triangulate_polygon(pts)
	var g := Geo.new()
	var put := func(a: Vector3, b: Vector3, c: Vector3) -> void:
		g.pos.append_array([a, b, c])
		g.uv.append_array([Vector2(a.x, a.y), Vector2(b.x, b.y), Vector2(c.x, c.y)])
	# triangulate_polygon gives triangles in the winding of the input; caps: bottom faces away (-z), top towards +z
	for t in range(0, tris.size(), 3):
		var p0 := pts[tris[t]]; var p1 := pts[tris[t + 1]]; var p2 := pts[tris[t + 2]]
		var n := (Vector3(p1.x, p1.y, 0) - Vector3(p0.x, p0.y, 0)).cross(Vector3(p2.x, p2.y, 0) - Vector3(p0.x, p0.y, 0))
		if n.z > 0.0:  # counter-clockwise in xy -> faces +z
			put.call(Vector3(p0.x, p0.y, depth), Vector3(p1.x, p1.y, depth), Vector3(p2.x, p2.y, depth))
			put.call(Vector3(p0.x, p0.y, 0), Vector3(p2.x, p2.y, 0), Vector3(p1.x, p1.y, 0))
		else:
			put.call(Vector3(p0.x, p0.y, depth), Vector3(p2.x, p2.y, depth), Vector3(p1.x, p1.y, depth))
			put.call(Vector3(p0.x, p0.y, 0), Vector3(p1.x, p1.y, 0), Vector3(p2.x, p2.y, 0))
	# side walls (contour is clockwise: outward normal is on the left of travel)
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var a0 := Vector3(a.x, a.y, 0); var b0 := Vector3(b.x, b.y, 0); var a1 := Vector3(a.x, a.y, depth); var b1 := Vector3(b.x, b.y, depth)
		var out := Vector3(a.y - b.y, b.x - a.x, 0)   # left of travel: outside of a clockwise loop
		var tri_n := (b0 - a0).cross(a1 - a0)
		if tri_n.dot(out) >= 0.0:
			put.call(a0, b0, a1); put.call(b0, b1, a1)
		else:
			put.call(a0, a1, b0); put.call(b0, a1, b1)
	g.compute_vertex_normals()
	return g

## three IcosahedronGeometry(radius, detail): flat normals at detail 0, smooth (= position) above
static func icosahedron(radius := 1.0, detail := 0) -> Geo:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v := [-1, t, 0, 1, t, 0, -1, -t, 0, 1, -t, 0, 0, -1, t, 0, 1, t, 0, -1, -t, 0, 1, -t, t, 0, -1, t, 0, 1, -t, 0, -1, -t, 0, 1]
	var ind := [0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8, 3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]
	var g := Geo.new()
	var vb: Array[Vector3] = []
	for i in range(0, ind.size(), 3):
		var a := Vector3(v[ind[i] * 3], v[ind[i] * 3 + 1], v[ind[i] * 3 + 2])
		var b := Vector3(v[ind[i + 1] * 3], v[ind[i + 1] * 3 + 1], v[ind[i + 1] * 3 + 2])
		var c := Vector3(v[ind[i + 2] * 3], v[ind[i + 2] * 3 + 1], v[ind[i + 2] * 3 + 2])
		var cols := detail + 1
		var vv: Array = []
		for ii in cols + 1:
			var row: Array = []
			var aj := a.lerp(c, float(ii) / cols)
			var bj := b.lerp(c, float(ii) / cols)
			var rows := cols - ii
			for j in rows + 1:
				row.append(aj if (j == 0 and ii == cols) else aj.lerp(bj, float(j) / rows))
			vv.append(row)
		for ii in cols:
			for j in 2 * (cols - ii) - 1:
				var k := j / 2
				if j % 2 == 0:
					vb.append_array([vv[ii][k + 1], vv[ii + 1][k], vv[ii][k]])
				else:
					vb.append_array([vv[ii][k + 1], vv[ii + 1][k + 1], vv[ii + 1][k]])
	for p in vb:
		var q := p.normalized() * radius
		g.pos.append(q)
		g.uv.append(Vector2(atan2(q.z, -q.x) / TAU + 0.5, 1.0 - (atan2(-q.y, sqrt(q.x * q.x + q.z * q.z)) / PI + 0.5)))
	if detail == 0:
		g.compute_vertex_normals()
	else:
		for p in g.pos:
			g.nrm.append(p.normalized())
	return g

# ---------------------------------------------------------------- operations

func clone() -> Geo:
	var g := Geo.new()
	g.pos = pos.duplicate(); g.nrm = nrm.duplicate(); g.uv = uv.duplicate(); g.col = col.duplicate(); g.idx = idx.duplicate()
	g.groups = groups.duplicate(true)
	return g

func apply_transform(t: Transform3D) -> Geo:
	var nb := t.basis.inverse().transposed()
	for i in pos.size():
		pos[i] = t * pos[i]
	for i in nrm.size():
		nrm[i] = (nb * nrm[i]).normalized()
	return self

func translate(x: float, y: float, z: float) -> Geo:
	for i in pos.size():
		pos[i] += Vector3(x, y, z)
	return self

func rotate_x(a: float) -> Geo:
	return apply_transform(Transform3D(Basis(Vector3.RIGHT, a), Vector3.ZERO))

func rotate_y(a: float) -> Geo:
	return apply_transform(Transform3D(Basis(Vector3.UP, a), Vector3.ZERO))

func rotate_z(a: float) -> Geo:
	return apply_transform(Transform3D(Basis(Vector3.BACK, a), Vector3.ZERO))

func scale(x: float, y: float, z: float) -> Geo:
	return apply_transform(Transform3D(Basis.from_scale(Vector3(x, y, z)), Vector3.ZERO))

func to_non_indexed() -> Geo:
	if idx.is_empty():
		return clone()
	var g := Geo.new()
	for k in idx:
		g.pos.append(pos[k])
		if nrm.size() > k: g.nrm.append(nrm[k])
		if uv.size() > k: g.uv.append(uv[k])
		if col.size() > k: g.col.append(col[k])
	g.groups = groups.duplicate(true)
	return g

## three computeVertexNormals: area-weighted face normals summed per vertex (indexed), or flat per triangle
func compute_vertex_normals() -> Geo:
	nrm.resize(pos.size())
	for i in nrm.size():
		nrm[i] = Vector3.ZERO
	if idx.is_empty():
		for i in range(0, pos.size(), 3):
			var n := (pos[i + 2] - pos[i + 1]).cross(pos[i] - pos[i + 1])
			nrm[i] = n; nrm[i + 1] = n; nrm[i + 2] = n
	else:
		for i in range(0, idx.size(), 3):
			var a := idx[i]; var b := idx[i + 1]; var c := idx[i + 2]
			var n := (pos[c] - pos[b]).cross(pos[a] - pos[b])
			nrm[a] += n; nrm[b] += n; nrm[c] += n
	for i in nrm.size():
		nrm[i] = nrm[i].normalized()
	return self

## all vertex colours to one colour (Acc.color)
func set_color(c: Color) -> Geo:
	col.resize(pos.size())
	col.fill(c)
	return self

# ---------------------------------------------------------------- to Godot

## Godot surface arrays for triangles [start, start+count) of the index buffer (or vertices when non-indexed)
func _arrays(start: int, count: int) -> Array:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	var P := PackedVector3Array()
	var N := PackedVector3Array()
	var U := PackedVector2Array()
	var C := PackedColorArray()
	var has_n := nrm.size() == pos.size()
	var has_u := uv.size() == pos.size()
	var has_c := col.size() == pos.size()
	if idx.is_empty():
		for i in range(start, start + count, 3):
			for k in [i, i + 2, i + 1]:   # ccw -> cw
				P.append(pos[k])
				if has_n: N.append(nrm[k])
				if has_u: U.append(Vector2(uv[k].x, 1.0 - uv[k].y))
				if has_c: C.append(col[k])
		a[Mesh.ARRAY_VERTEX] = P
	else:
		# keep it indexed: copy the used vertices once
		var remap := {}
		var I := PackedInt32Array()
		for i in range(start, start + count, 3):
			for k in [idx[i], idx[i + 2], idx[i + 1]]:
				if not remap.has(k):
					remap[k] = P.size()
					P.append(pos[k])
					if has_n: N.append(nrm[k])
					if has_u: U.append(Vector2(uv[k].x, 1.0 - uv[k].y))
					if has_c: C.append(col[k])
				I.append(remap[k])
		a[Mesh.ARRAY_VERTEX] = P
		a[Mesh.ARRAY_INDEX] = I
	if has_n: a[Mesh.ARRAY_NORMAL] = N
	if has_u: a[Mesh.ARRAY_TEX_UV] = U
	if has_c: a[Mesh.ARRAY_COLOR] = C
	return a

## ArrayMesh with one surface per material. mats: a Material, or an Array indexed by the geometry's group material index
## (like a three.js mesh with a material array: BoxGeometry faces 0..5, CylinderGeometry torso/top/bottom).
func to_mesh(mats = null) -> ArrayMesh:
	var m := ArrayMesh.new()
	var total := idx.size() if not idx.is_empty() else pos.size()
	if total == 0:
		return m
	if mats is Array and not groups.is_empty():
		# merge the groups per material
		var per := {}
		for gr in groups:
			var mi: int = gr[2]
			if mi >= mats.size() or mats[mi] == null:
				continue
			if not per.has(mi): per[mi] = []
			per[mi].append(gr)
		for mi in per:
			var merged := []
			for gr in per[mi]:
				var arr := _arrays(gr[0], gr[1])
				if merged.is_empty():
					merged = arr
				else:
					merged = _concat(merged, arr)
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, merged)
			m.surface_set_material(m.get_surface_count() - 1, mats[mi])
	else:
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays(0, total))
		var mat = mats[0] if mats is Array else mats
		if mat != null:
			m.surface_set_material(0, mat)
	return m

static func _concat(a: Array, b: Array) -> Array:
	var off: int = a[Mesh.ARRAY_VERTEX].size()
	for k in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_COLOR]:
		if a[k] != null and b[k] != null:
			a[k].append_array(b[k])
	if a[Mesh.ARRAY_INDEX] != null and b[Mesh.ARRAY_INDEX] != null:
		var bi: PackedInt32Array = b[Mesh.ARRAY_INDEX]
		for i in bi.size():
			bi[i] += off
		a[Mesh.ARRAY_INDEX].append_array(bi)
	return a

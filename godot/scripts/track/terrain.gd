class_name Terrain
extends RefCounted
## Port of terrainFn(hillsFn) from polderrace-3d.html: the hilly ground of Veluwe and Limburg, which blends from the
## road height (0.3 m below the road) into the hills between 11.5 and 96.5 m from the centre line.
##
## JS: `const TF=terrainFn(); veluweTF=TF; ... const t=TF(x,z); t.h, t.d`.
## Godot: `var TF := Terrain.terrainFn(); Trk.terrain_fn = TF.fn(); ... var h := TF.at(x, z); TF.d`.
##   at(x, z)  terrain height at (x, z); also sets d = distance to the nearest centre-line point (every 2nd sample,
##             searched in the 5x5 cells of 60 m around (x, z), 1e9 when there is none), exactly like the JS closure.
##             Allocates nothing: use it in the builders' big loops.
##   fn()      the JS-style Callable(x, z) -> {"h": height, "d": distance} (Trk.terrain_fn = JS veluweTF).
## It is called ~100k times per build (every ground vertex, every tree, tuft and flower), so the JS Map of string keys
## is a dense grid of packed arrays here, and a cell whose points' bounding box is farther away than the best point so
## far is skipped. The point found is still the JS one: the nearest in the same 25 cells, and on an exactly equal
## distance the one the JS scans first.

const CELL := 60.0
## scan order: the query's own cell, then the ring around it, then the outer ring (finds a near point first, so the
## other cells can be skipped); _rank[o] = the JS scan order of that cell (a outer, b inner, both -2..2)
const OA := [0, -1, -1, -1, 0, 0, 1, 1, 1, -2, -2, -2, -2, -2, -1, -1, 0, 0, 1, 1, 2, 2, 2, 2, 2]
const OB := [0, -1, 0, 1, -1, 1, -1, 0, 1, -2, -1, 0, 1, 2, -2, 2, -2, 2, -2, 2, -2, -1, 0, 1, 2]

var hills: Callable
## distance to the centre line found by the last at() (JS t.d)
var d := 1e9

var _ht := PackedFloat64Array()
var _gx0 := 0
var _gz0 := 0
var _nx := 0
var _nz := 0
var _start := PackedInt32Array()   ## per cell (gx * _nz + gz): its first point in _px/_pz/_pi; _start[c + 1] = end
var _px := PackedFloat64Array()
var _pz := PackedFloat64Array()
var _pi := PackedInt32Array()      ## sample index of the point (ascending within a cell, like the JS lists)
var _bb := PackedFloat64Array()    ## per cell: min x, max x, min z, max z of its points
var _any := PackedByteArray()      ## per cell: 1 when a point lies in its 5x5 neighbourhood
var _oa := PackedInt32Array(OA)
var _ob := PackedInt32Array(OB)
var _rank := PackedInt32Array()

## JS default hills (Veluwe)
static func veluweHills(x: float, z: float) -> float:
	return 11 + 9 * sin(x / 190 + 1.3) * cos(z / 230 - 0.4) + 6 * sin((x - z) / 120) + 3 * cos((x * 0.7 + z) / 61)

## JS terrainFn(hillsFn): hillsFn = Callable(x, z) -> height, or none for the Veluwe hills
static func terrainFn(hillsFn: Callable = Callable()) -> Terrain:
	var t := Terrain.new()
	t.hills = hillsFn if hillsFn.is_valid() else Callable(Terrain, "veluweHills")
	t._build_grid()
	return t

func _build_grid() -> void:
	var NS := Trk.NS
	_ht = Trk.HT
	_rank.resize(25)
	for o in 25:
		_rank[o] = (_oa[o] + 2) * 5 + (_ob[o] + 2)
	# JS: for(let i=0;i<NS;i+=2) grid[floor(P[i].x/cell)+','+floor(P[i].z/cell)].push(i)
	# The points are taken from the curve again in 64 bit (Trk.P holds 32-bit floats), so nearly equal distances to two
	# stretches of road (hairpins) are decided as in the JS.
	var cxs := PackedInt32Array()
	var czs := PackedInt32Array()
	var idx := PackedInt32Array()
	var xs := PackedFloat64Array()
	var zs := PackedFloat64Array()
	var minx := 1 << 30
	var minz := 1 << 30
	var maxx := -(1 << 30)
	var maxz := -(1 << 30)
	for i in range(0, NS, 2):
		var p := Trk.curve.get_point_at(float(i) / NS)
		var cx := floori(p[0] / CELL)
		var cz := floori(p[2] / CELL)
		cxs.append(cx); czs.append(cz); idx.append(i); xs.append(p[0]); zs.append(p[2])
		minx = mini(minx, cx); maxx = maxi(maxx, cx); minz = mini(minz, cz); maxz = maxi(maxz, cz)
	# dense grid with a margin of 2 cells, so every neighbourhood of a cell with points lies inside it
	_gx0 = minx - 2
	_gz0 = minz - 2
	_nx = maxx - minx + 5
	_nz = maxz - minz + 5
	var nc := _nx * _nz
	var count := PackedInt32Array()
	count.resize(nc)
	for k in idx.size():
		count[(cxs[k] - _gx0) * _nz + (czs[k] - _gz0)] += 1
	_start.resize(nc + 1)
	var acc := 0
	for c in nc:
		_start[c] = acc
		acc += count[c]
	_start[nc] = acc
	_px.resize(acc); _pz.resize(acc); _pi.resize(acc)
	_bb.resize(nc * 4)
	for c in nc:
		_bb[c * 4] = 1e18; _bb[c * 4 + 1] = -1e18; _bb[c * 4 + 2] = 1e18; _bb[c * 4 + 3] = -1e18
	var fill := _start.duplicate()
	for k in idx.size():
		var c := (cxs[k] - _gx0) * _nz + (czs[k] - _gz0)
		var j := fill[c]
		fill[c] += 1
		var x := xs[k]
		var z := zs[k]
		_px[j] = x; _pz[j] = z; _pi[j] = idx[k]
		_bb[c * 4] = minf(_bb[c * 4], x); _bb[c * 4 + 1] = maxf(_bb[c * 4 + 1], x)
		_bb[c * 4 + 2] = minf(_bb[c * 4 + 2], z); _bb[c * 4 + 3] = maxf(_bb[c * 4 + 3], z)
	_any.resize(nc)
	for gx in _nx:
		for gz in _nz:
			var c := gx * _nz + gz
			if _start[c] == _start[c + 1]: continue
			for a in range(-2, 3):
				for b in range(-2, 3):
					_any[(gx + a) * _nz + gz + b] = 1

## JS TF(x,z).h (and sets d = TF(x,z).d)
func at(x: float, z: float) -> float:
	var hn: float = hills.call(x, z)
	var gx := floori(x / CELL) - _gx0
	var gz := floori(z / CELL) - _gz0
	if gx < 0 or gz < 0 or gx >= _nx or gz >= _nz or _any[gx * _nz + gz] == 0:
		d = 1e9
		return hn
	var bd := 1e12
	var bi := -1
	var bo := 0
	for o in 25:
		var cx := gx + _oa[o]
		var cz := gz + _ob[o]
		if cx < 0 or cz < 0 or cx >= _nx or cz >= _nz: continue
		var c := cx * _nz + cz
		var k0 := _start[c]
		var k1 := _start[c + 1]
		if k0 == k1: continue
		# nearest possible point of this cell (bounding box): no nearer than the best so far -> skip the cell
		var b4 := c * 4
		var ex := 0.0
		if x < _bb[b4]: ex = _bb[b4] - x
		elif x > _bb[b4 + 1]: ex = x - _bb[b4 + 1]
		var ez := 0.0
		if z < _bb[b4 + 2]: ez = _bb[b4 + 2] - z
		elif z > _bb[b4 + 3]: ez = z - _bb[b4 + 3]
		if ex * ex + ez * ez > bd: continue
		for k in range(k0, k1):
			var dx := x - _px[k]
			var dz := z - _pz[k]
			var dd := dx * dx + dz * dz
			if dd < bd:
				bd = dd; bi = _pi[k]; bo = o
			elif dd == bd and _rank[o] < _rank[bo]:
				bi = _pi[k]; bo = o
	if bi < 0:
		d = 1e9
		return hn
	d = sqrt(bd)
	var t := clampf((d - 11.5) / 85, 0, 1)
	var s := t * t * (3 - 2 * t)
	return (_ht[bi] - 0.3) * (1 - s) + hn * s

## the JS closure itself: Callable(x, z) -> {"h": height, "d": distance} (for Trk.terrain_fn)
func fn() -> Callable:
	return func(x: float, z: float) -> Dictionary:
		var h := at(x, z)
		return {"h": h, "d": d}

## JS: new THREE.PlaneGeometry(size,size,seg,seg) + geo.rotateX(-PI/2): vertex k = iy*(seg+1)+ix lies at
## (ix*size/seg - size/2, 0, iy*size/seg - size/2)
static func planeXZ(size: float, seg: int) -> PackedVector3Array:
	var pos := PackedVector3Array()
	pos.resize((seg + 1) * (seg + 1))
	var sw := size / seg
	var k := 0
	for iy in seg + 1:
		for ix in seg + 1:
			pos[k] = Vector3(ix * sw - size / 2, 0, iy * sw - size / 2)
			k += 1
	return pos

## The hilly ground as vertex-coloured meshes at (cx, 0, cz); pos = planeXZ(size, seg) with the heights filled in.
## Normals are summed per vertex over the whole plane (three computeVertexNormals: triangles (a,b,d) (b,c,d)), then the
## plane is cut into chunks x chunks meshes, so the renderer only draws the part of the hills in view (one mesh of
## 148k triangles was drawn whole in the picture, the mirror and the shadow pass).
## tex: an optional detail texture (grey around white: the vertex colours keep their hue), repeated every `tile` m.
static func groundMesh(pos: PackedVector3Array, cols: PackedColorArray, seg: int, cx: float, cz: float, tex: Texture2D = null, tile := 24.0, chunks := 6) -> Array:
	var w := seg + 1
	var nrm := PackedVector3Array()
	nrm.resize(pos.size())
	for iy in seg:
		for ix in seg:
			var a := ix + w * iy
			var b := ix + w * (iy + 1)
			var c := (ix + 1) + w * (iy + 1)
			var dd := (ix + 1) + w * iy
			var pb := pos[b]
			var pc := pos[c]
			var pd := pos[dd]
			var n1 := (pd - pb).cross(pos[a] - pb)
			var n2 := (pd - pc).cross(pb - pc)
			nrm[a] += n1; nrm[b] += n1 + n2; nrm[dd] += n1 + n2; nrm[c] += n2
	for k in nrm.size():
		nrm[k] = nrm[k].normalized()
	var o := {"vertexColors": true, "receiveShadow": true}
	if tex != null: o["map"] = tex
	var mat := Mats.M(0xffffff, o)
	var out := []
	for cy in chunks:
		var y0 := seg * cy / chunks
		var y1 := seg * (cy + 1) / chunks
		for cxi in chunks:
			var x0 := seg * cxi / chunks
			var x1 := seg * (cxi + 1) / chunks
			var cw := x1 - x0 + 1
			var n := cw * (y1 - y0 + 1)
			var P := PackedVector3Array(); P.resize(n)
			var N := PackedVector3Array(); N.resize(n)
			var C := PackedColorArray(); C.resize(n)
			var U := PackedVector2Array(); U.resize(n)
			var k := 0
			for iy in range(y0, y1 + 1):
				for ix in range(x0, x1 + 1):
					var g := ix + w * iy
					P[k] = pos[g]; N[k] = nrm[g]; C[k] = cols[g]
					U[k] = Vector2((pos[g].x + cx) / tile, (pos[g].z + cz) / tile)
					k += 1
			var I := PackedInt32Array()
			I.resize((x1 - x0) * (y1 - y0) * 6)
			var q := 0
			for iy in y1 - y0:
				for ix in x1 - x0:
					var a := ix + cw * iy
					var b := ix + cw * (iy + 1)
					var c := (ix + 1) + cw * (iy + 1)
					var dd := (ix + 1) + cw * iy
					I[q] = a; I[q + 1] = dd; I[q + 2] = b
					I[q + 3] = b; I[q + 4] = dd; I[q + 5] = c
					q += 6
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = P
			arr[Mesh.ARRAY_NORMAL] = N
			arr[Mesh.ARRAY_COLOR] = C
			if tex != null: arr[Mesh.ARRAY_TEX_UV] = U
			arr[Mesh.ARRAY_INDEX] = I
			var m := ArrayMesh.new()
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			m.surface_set_material(0, mat)
			var mi := O3.mesh(m, null, cx, 0, cz)
			World.add(mi)
			out.append(mi)
	return out

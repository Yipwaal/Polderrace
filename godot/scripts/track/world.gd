class_name World
## The HTML game's "world building helpers" (ribbon, vribbon, place, box, mtx, inst, roadMat, groundPlane, startLine,
## bannerTex, gates, roadTexture) working on World.root, the node that holds everything of the current track
## (JS: `world`). Builders port with the same names: World.ribbon(...), World.box(...), World.inst(...).
## World.rnd is the seeded random of the track being built (JS: rnd = seeded(TRK.seed) during loadTrack).

static var root: Node3D
static var rnd: Rng = Rng.random()
## material / object lists the environment code updates (night lamps, wet roads, windows, ...): same names as the JS
static var roadMats: Array = []
static var lampMats: Array = []
static var hillMats: Array = []
static var winMats: Array = []
static var reflMats: Array = []
static var beaconMats: Array = []
static var trackLights: Array = []
static var cpGates: Array = []
static var sailGroups: Array = []

static func pick(a: Array):
	return a[int(floor(rnd.next() * a.size()))]

## JS clearSpot(minD, tries): a random spot in the track's box (+150 m) at least minD from the track
static func clearSpot(minD: float, tries := 60):
	for _k in tries:
		var x := Trk.BX0 - 150 + rnd.next() * (Trk.BX1 - Trk.BX0 + 300)
		var z := Trk.BZ0 - 150 + rnd.next() * (Trk.BZ1 - Trk.BZ0 + 300)
		if Trk.distToTrack(x, z) >= minD:
			return [x, z]
	return null

## pavement spots already taken [x, z, radius] (Dorp: lamp posts, bikes, terraces); planters() and benches() keep clear
static var pavTaken: Array = []
static func pavBusy(x: float, z: float, r: float) -> bool:
	for t in pavTaken:
		if (t[0] - x) * (t[0] - x) + (t[1] - z) * (t[1] - z) < (t[2] + r) * (t[2] + r):
			return true
	return false

## JS wire(pts, mat): a line through world points
static func wire(pts: Array, color: int) -> void:
	root.add_child(O3.line(pts, color))

static func clear() -> void:
	if root != null and is_instance_valid(root):
		var parent := root.get_parent()
		var name := root.name
		root.queue_free()
		root = Node3D.new()
		root.name = name
		if parent != null:
			parent.add_child(root)
	roadMats = []; lampMats = []; hillMats = []; winMats = []; reflMats = []; beaconMats = []
	trackLights = []; cpGates = []; sailGroups = []

static func add(n: Node) -> Node:
	root.add_child(n)
	return n

static func _lat(v, i: int) -> float:
	return v.call(i) if v is Callable else float(v)

## a strip along the track between lateral offsets latA and latB (number or Callable(i)), yOff above the road surface
static func ribbon(latA, latB, mat: Material, vRep: float, yOff: float, filter = null) -> MeshInstance3D:
	var NS := Trk.NS
	var n := NS + 1
	var g := Geo.new()
	g.pos.resize(n * 2)
	g.uv.resize(n * 2)
	for k in n:
		var i := k % NS
		var p := Trk.P[i]
		var r := Trk.R[i]
		var a := _lat(latA, i)
		var b := _lat(latB, i)
		g.pos[k * 2] = Vector3(p.x + r.x * a, Trk.hAt(i, a) + yOff, p.z + r.z * a)
		g.pos[k * 2 + 1] = Vector3(p.x + r.x * b, Trk.hAt(i, b) + yOff, p.z + r.z * b)
		var v := k * Trk.SPC / vRep
		g.uv[k * 2] = Vector2(0, v)
		g.uv[k * 2 + 1] = Vector2(1, v)
		if k < n - 1 and (filter == null or filter.call(i)):
			var A := k * 2
			g.idx.append_array([A, A + 1, A + 2, A + 1, A + 3, A + 2])
	g.compute_vertex_normals()
	# the JS also gives strips a real height gap (its depth buffer ignores polygon offset): verges 3 cm down, kerbs 2 cm up
	if yOff < 0.07:
		for k in g.pos.size():
			g.pos[k].y -= 0.03
	elif yOff > 0.07 and yOff < 0.1:
		for k in g.pos.size():
			g.pos[k].y += 0.02
	var m := O3.mesh(g, mat)
	root.add_child(m)
	return m

## a vertical strip along the track at lateral offset lat, from y0 to y1 above the local ground (walls, rails)
static func vribbon(lat, y0: float, y1: float, mat: Material, vRep: float, filter = null) -> MeshInstance3D:
	var NS := Trk.NS
	var n := NS + 1
	var g := Geo.new()
	g.pos.resize(n * 2)
	g.uv.resize(n * 2)
	for k in n:
		var i := k % NS
		var p := Trk.P[i]
		var r := Trk.R[i]
		var l := _lat(lat, i)
		var base := Trk.hAt(i, l)
		var x := p.x + r.x * l
		var z := p.z + r.z * l
		g.pos[k * 2] = Vector3(x, base + y0, z)
		g.pos[k * 2 + 1] = Vector3(x, base + y1, z)
		var v := k * Trk.SPC / vRep
		g.uv[k * 2] = Vector2(v, 0)
		g.uv[k * 2 + 1] = Vector2(v, 1)
		if k < n - 1 and (filter == null or filter.call(i)):
			var A := k * 2
			g.idx.append_array([A, A + 2, A + 1, A + 1, A + 2, A + 3])
	g.compute_vertex_normals()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var m := O3.mesh(g, mat)
	root.add_child(m)
	return m

## put obj at sample i, lateral lat, y above the road surface there, facing along the track
static func place(obj: Node3D, i: int, lat := 0.0, y := 0.0) -> Node3D:
	var p := Trk.P[i]
	var r := Trk.R[i]
	obj.position = Vector3(p.x + r.x * lat, y + Trk.hAt(i, lat), p.z + r.z * lat)
	O3.rot(obj, 0.0, Trk.heading_of(Trk.T[i]), 0.0)
	root.add_child(obj)
	return obj

## JS box(w,h,d,mat,x,y,z,parent,cast): cast defaults to true there (cast!==false)
static func box(w: float, h: float, d: float, mat, x: float, y: float, z: float, parent: Node = null, cast := true) -> MeshInstance3D:
	var m := O3.mesh(Geo.box(w, h, d), mat, x, y, z, null, cast)
	(parent if parent != null else root).add_child(m)
	return m

static func mtx(x: float, y: float, z: float, ry := 0.0, sx := 1.0, sy := -1.0, sz := -1.0) -> Transform3D:
	# JS: sy||sx||1, sz||sx||1 (sz follows sx, not sy)
	if sy < 0: sy = sx
	if sz < 0: sz = sx
	return O3.mtx(x, y, z, ry, sx, sy, sz)

## many copies of one geometry (JS InstancedMesh in cells of 150 m, for culling): transforms + optional colours
## tests set inst_log = [] to record every inst() call: [count, first origin, last origin] (see tests/test_build.gd)
static var inst_log = null

static func inst(geo: Geo, mat: Material, xfs: Array, colors = null, cast := false):
	if xfs.is_empty():
		return null
	if inst_log != null:
		inst_log.append([xfs.size(), xfs[0].origin, xfs[-1].origin])
	var CH := 150.0
	var cells := {}
	for i in xfs.size():
		var o: Vector3 = xfs[i].origin
		var k := "%d,%d" % [int(floor(o.x / CH)), int(floor(o.z / CH))]
		if not cells.has(k): cells[k] = []
		cells[k].append(i)
	var use_mat: Material = mat
	if colors != null:
		use_mat = mat.clone()
		use_mat.vertex_color_use_as_albedo = true
		# the JS uses the material itself: what Env does to it (night windows, lamps) must reach the clone too
		for l in [winMats, lampMats, reflMats, beaconMats, roadMats, hillMats]:
			if l.has(mat): l.append(use_mat)
	var mesh := geo.to_mesh(use_mat)
	for idxs in cells.values():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = colors != null
		mm.mesh = mesh
		mm.instance_count = idxs.size()
		for j in idxs.size():
			mm.set_instance_transform(j, xfs[idxs[j]])
			if colors != null:
				mm.set_instance_color(j, colors[idxs[j]])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	return true

static func roadMat(tex: Texture2D, o: Dictionary = {}) -> LMat:
	var oo := o.duplicate()
	oo["map"] = tex
	var m := Mats.M(0xffffff, oo)
	roadMats.append(m)
	return m

## the land under everything: tiles of 36 m (one 3.6 km quad gave grass through the road in the JS version)
static func groundPlane(tex: Texture2D, rep: float) -> MeshInstance3D:
	var g := Geo.plane(3600, 3600, 100, 100)
	var m := O3.mesh(g, Mats.M(0xffffff, {"map": tex, "repeat": Vector2(rep, rep)}))
	O3.rot(m, -PI / 2, 0, 0)
	m.position = Vector3((Trk.BX0 + Trk.BX1) / 2.0, 0.0, (Trk.BZ0 + Trk.BZ1) / 2.0)
	root.add_child(m)
	return m

static var _checker: ImageTexture
static func checkerTex() -> ImageTexture:
	if _checker == null:
		_checker = Canvas2D.tex(256, 32, func(g, _w, _h):
			for x in 16:
				for y in 2:
					g.fillStyle = "#f2f2ee" if (x + y) % 2 else "#202226"
					g.fillRect(x * 16, y * 16, 16, 16))
	return _checker

static func startLine() -> void:
	var line := O3.mesh(Geo.plane(Trk.ROAD_HALF * 2, 1.8), Mats.M(0xffffff, {"map": checkerTex()}))
	O3.rot(line, -PI / 2, 0, 0)
	var g := Node3D.new()
	g.add_child(line)
	place(g, Trk.START_I, 0, 0.09)

static func bannerTex(text: String, checker := false) -> ImageTexture:
	return Canvas2D.tex(1024, 160 if checker else 128, func(g, w, h):
		g.fillStyle = "#1d4f9e"; g.fillRect(0, 0, w, h)
		g.strokeStyle = "#f7f7f2"; g.lineWidth = 8; g.strokeRect(14, 14, w - 28, (128 if checker else h) - 28)
		g.fillStyle = "#f7f7f2"; g.font = "italic 800 84px Barlow Condensed"; g.textAlign = "center"; g.textBaseline = "middle"
		g.fillText(text, w / 2.0, 64, w - 80)
		if checker:
			for x in 64:
				for y in 2:
					g.fillStyle = "#f7f7f2" if (x + y) % 2 else "#1b1b1b"
					g.fillRect(x * 16, 128 + y * 16, 16, 16))

static func gates(def: Dictionary) -> void:
	var postX: float = minf(Trk.ROAD_HALF + 3.2, Trk.SHOULDER - 0.8)
	var postMat := Mats.M(0xd2d5d7)
	var blue := Mats.M(0x1d4f9e)
	cpGates = []
	for k in Trk.cps.size():
		var i: int = Trk.cps[k]
		var checker := k == 0
		var g := Node3D.new()
		cpGates.append(g)
		var face := Mats.M(0xffffff, {"map": bannerTex(def.banner if checker else "CHECKPOINT", checker)})
		for x in [-postX, postX]:
			O3.mesh(Geo.box(0.6, 9, 0.6), postMat, x, 4.5, 0, g, true)
		# box faces: px nx py ny pz nz -> the banner on both big faces
		O3.mesh(Geo.box(postX * 2 + 0.8, 3.2 if checker else 2.6, 0.35), [blue, blue, blue, blue, face, face], 0, 8.1 if checker else 8.3, 0, g, true)
		place(g, i, 0, 0)

static func setGateMode(showCp: bool) -> void:
	for k in cpGates.size():
		cpGates[k].visible = k == 0 or showCp

static func roadTexture(base: String, dashes: Array, edge: bool, brick := false, dashFrac := 0.3) -> ImageTexture:
	return Canvas2D.tex(256, 512, func(g, w, h):
		g.fillStyle = base; g.fillRect(0, 0, w, h)
		if brick:
			g.strokeStyle = "rgba(40,20,15,.35)"; g.lineWidth = 2
			var y := 0
			while y < h:
				g.beginPath(); g.moveTo(0, y); g.lineTo(w, y); g.stroke()
				var x := (y / 16) % 2 * 16
				while x < w:
					g.beginPath(); g.moveTo(x, y); g.lineTo(x, y + 16); g.stroke()
					x += 32
				y += 16
			for _i in 900:
				g.fillStyle = "rgba(255,255,255,.05)" if randf() < .5 else "rgba(0,0,0,.07)"
				g.fillRect(randf() * w, randf() * h, 14, 6)
		else:
			for _i in 6000:
				g.fillStyle = "rgba(255,255,255,.05)" if randf() < .5 else "rgba(0,0,0,.08)"
				g.fillRect(randf() * w, randf() * h, 2, 2)
			g.fillStyle = "rgba(0,0,0,.08)"; g.fillRect(w / 2.0 - 45, 0, 30, h); g.fillRect(w / 2.0 + 15, 0, 30, h)
		g.fillStyle = "#f2f2ec"
		if edge:
			g.fillRect(8, 0, 8, h); g.fillRect(w - 16, 0, 8, h)
		for x in dashes:
			g.fillRect(x * w - 3, 0, 6, h * dashFrac), true)

class_name TrackCommon
## Track-building helpers that several tracks use (JS: waterPlane, landPlane, railTex, facadeTex, lampRow, signs,
## roofGeo, roofMesh). Track-specific helpers live in that track's builder file.

static func waterPlane(w: float, d: float, x: float, z: float, y: float, col := 0x4f7394) -> MeshInstance3D:
	var m := O3.mesh(Geo.plane(w, d), Mats.phong(col, {"specular": 0x9fb4c8, "shininess": 70, "receiveShadow": true}))
	O3.rot(m, -PI / 2, 0, 0)
	m.position = Vector3(x, y, z)
	O3.receive(m)
	World.add(m)
	return m

static func landPlane(tex: Texture2D, x0: float, z0: float, x1: float, z1: float, tile: float) -> MeshInstance3D:
	var m := O3.mesh(Geo.plane(x1 - x0, z1 - z0), Mats.M(0xffffff, {"map": tex, "repeat": Vector2((x1 - x0) / tile, (z1 - z0) / tile), "receiveShadow": true}))
	O3.rot(m, -PI / 2, 0, 0)
	m.position = Vector3((x0 + x1) / 2, 0, (z0 + z1) / 2)
	O3.receive(m)
	World.add(m)
	return m

static func railTex() -> ImageTexture:
	return Canvas2D.tex(64, 32, func(g, w, h):
		g.fillStyle = "#b9bec3"; g.fillRect(0, 0, w, h); g.fillStyle = "#8d9398"; g.fillRect(0, 10, w, 3); g.fillRect(0, 20, w, 3)
		g.fillStyle = "#6c7277"; g.fillRect(0, 0, 4, h), true)

static func facadeTex(floors: int) -> ImageTexture:
	return Canvas2D.tex(128, 256, func(g, w, h):
		g.fillStyle = "#ffffff"; g.fillRect(0, 0, w, h)
		var fh: float = h / (floors + 0.6)
		for f in floors:
			for x in [14, 52, 90]:
				g.fillStyle = "#1f2a33"; g.fillRect(x, h - fh * (f + 1) - 4, 24, fh * 0.62)
				g.fillStyle = "#e8e4dc"; g.fillRect(x - 2, h - fh * (f + 1) - 6, 28, 3)
		g.fillStyle = "#2b2017"; g.fillRect(52, h - fh * 0.9, 24, fh * 0.9))

## street lamps along the track; opts.both = alternate sides. Adds their light pools to World.trackLights.
static func lampRow(latAbs: float, every: float, h: float, opts: Dictionary = {}) -> void:
	var pm := Mats.M(0x23382c)
	var hm := Mats.M(0x333a40, {"emissive": 0x222222})
	World.lampMats.append(hm)
	var lp := []; var lh := []
	var sd := 1
	var d := 10.0
	while d < Trk.TRACK_LEN:
		var i := int(round(d / Trk.SPC)) % Trk.NS
		sd = -sd if opts.get("both", false) else 1
		var xz := Trk.onTrack(i, sd * latAbs)
		var hxz := Trk.onTrack(i, sd * (latAbs - 1.2))
		lp.append(World.mtx(xz[0], Trk.HT[i] + h / 2, xz[1], Trk.heading_of(Trk.T[i]) + (0.0 if sd > 0 else PI)))
		lh.append(World.mtx(hxz[0], Trk.HT[i] + h, hxz[1], Trk.heading_of(Trk.T[i])))
		var pxz := Trk.onTrack(i, sd * (latAbs - 4))
		World.trackLights.append([pxz[0], Trk.HT[i], pxz[1], 9])
		d += every
	# the post with its arm (local +x, towards the road): the lamp head hangs 1.2 m in from the post and used to float beside it
	var post := Geo.cylinder(0.08, 0.11, h, 6)
	var arm := Geo.box(1.3, 0.07, 0.07).translate(0.6, h / 2 - 0.05, 0)
	var off := post.pos.size()
	post.pos.append_array(arm.pos); post.nrm.append_array(arm.nrm); post.uv.append_array(arm.uv)
	for k in arm.idx: post.idx.append(k + off)
	post.groups = []
	World.inst(post, pm, lp, null, true)
	World.inst(Geo.box(0.9, 0.22, 0.45), hm, lh, null, false)

## blue ANWB-style place-name signs along the track (skipped where the road is on a dike)
static func signs(list: Array, lat: float) -> void:
	var blue := Mats.M(0x1d4f9e)
	var postMat := Mats.M(0xd2d5d7)
	for k in list.size():
		var n: String = list[k][0]
		var km: String = list[k][1]
		var i := int(floor(Trk.NS * (k + 0.35) / list.size())) % Trk.NS
		if Trk.EMB[i] > 0.5:
			continue
		var tex := Canvas2D.tex(256, 128, func(g, w, h):
			g.fillStyle = "#1d4f9e"; g.fillRect(0, 0, w, h); g.strokeStyle = "#f7f7f2"; g.lineWidth = 6; g.strokeRect(10, 10, w - 20, h - 20)
			g.fillStyle = "#f7f7f2"; g.font = "700 46px Barlow Condensed"; g.textAlign = "left"; g.fillText(n, 26, 62, 200)
			g.textAlign = "right"; g.fillText(km, w - 26, 108))
		var g := Node3D.new()
		var face := Mats.M(0xffffff, {"map": tex})
		O3.mesh(Geo.box(3.2, 1.6, 0.12), [blue, blue, blue, blue, face, blue], 0, 3.2, 0, g, true)
		for x in [-1.1, 1.1]:
			World.box(0.12, 2.6, 0.12, postMat, x, 1.3, -0.12, g)
		World.place(g, i, lat, 0)
		g.rotate_y(PI)

## a gable roof: triangle (-0.5,0) (0.5,0) (0,1) extruded 1 deep, centred in z; scale it to w x h x d
static func roofGeo() -> Geo:
	var geo := Geo.extrude([Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(0, 1)], 1.0)
	geo.translate(0, 0, -0.5)
	return geo

static func roofMesh(w: float, h: float, d: float, mat) -> MeshInstance3D:
	var m := O3.mesh(roofGeo(), mat, 0, 0, 0, null, true)
	m.scale = Vector3(w, h, d)
	return m

## red-and-white bend boards on the outside of every tight bend: they face the oncoming driver and their arrows point
## into the bend (right in both driving directions: the back of a board is its mirror image). lat: metres from the
## centre line (number or Callable(i)); y0: lower edge above the ground there (1.6 m: a car that runs wide passes
## under the board, only the thin post stands in its way); min_curv: 1 / the widest bend radius that gets boards.
static var _chevTex: Array = []
static func chevrons(lat, y0 := 1.6, min_curv := 0.016, every := 10.0, size := 1.25) -> void:
	if _chevTex.is_empty():
		for dir in [-1, 1]:
			_chevTex.append(Canvas2D.tex(128, 48, func(g, w, h):
				g.fillStyle = "#f4f4ee"; g.fillRect(0, 0, w, h)
				g.fillStyle = "#c8201c"
				for k in 3:
					var x0: float = 10 + k * 40
					var pts := [[x0, 4], [x0 + 16, 4], [x0 + 32, h / 2.0], [x0 + 16, h - 4], [x0, h - 4], [x0 + 16, h / 2.0]]
					g.beginPath()
					for q in pts.size():
						var px: float = pts[q][0] if dir > 0 else w - pts[q][0]
						if q == 0: g.moveTo(px, pts[q][1])
						else: g.lineTo(px, pts[q][1])
					g.closePath(); g.fill()
				g.strokeStyle = "#1c1c1c"; g.lineWidth = 3; g.strokeRect(1.5, 1.5, w - 3, h - 3)))
	var NS := Trk.NS
	var T := Trk.T
	var per := [[], []]
	var posts := []
	var step := maxi(1, int(round(every / Trk.SPC)))
	for i in range(0, NS, step):
		# the tightest spot within a few metres decides, so a board row starts just before the bend and ends just after
		var c := 0.0
		for k in range(-3, 9): c = maxf(c, Trk.CURV[(i + k + NS) % NS])
		if c < min_curv: continue
		var a := T[(i - 4 + NS) % NS]
		var b := T[(i + 4) % NS]
		var sg := MathX.sgn(a.z * b.x - a.x * b.z)
		if sg == 0: continue
		var l: float = lat.call(i) if lat is Callable else float(lat)
		var xz := Trk.onTrack(i, sg * l)
		var gy := Dress.groundY(xz[0], xz[1]) if Trk.TRK.get("terrain", false) else Trk.hAt(i, l)
		per[0 if sg > 0 else 1].append(World.mtx(xz[0], gy + y0 + 0.36 * size, xz[1], Trk.heading_of(T[i]) + PI, size))
		posts.append(World.mtx(xz[0], gy + (y0 + 0.1) / 2.0, xz[1], 0, 1, y0 + 0.1, 1))
	for k in 2:
		# lit like a reflecting sign once the lamps are on (Env sets the emission of World.lampMats; the map keeps the arrows)
		# (a little of its own light by day too: the side turned away from the sun stays readable)
		var m := Mats.M(0xffffff, {"map": _chevTex[k], "emissive": 0x4a4a4a, "emissiveMap": _chevTex[k], "side": "double"})
		World.lampMats.append(m)
		World.inst(Geo.plane(1.9, 0.72), m, per[k], null, false)
	World.inst(Geo.cylinder(0.05, 0.05, 1, 5), Mats.M(0x8d9398), posts, null, false)

## standing people (spectators, a market crowd): pts = [[x, y, z, yaw], ...] with y the ground under their feet. Three
## instanced shapes (legs, body, head) with colours from the seeded World.rnd, so everybody online sees the same crowd.
static func people(pts: Array) -> void:
	if pts.is_empty(): return
	var shirts := [0xc8302a, 0x1d4f9e, 0xf2c200, 0xecece8, 0x2f8f5b, 0xf36f21, 0x2b2f36, 0x8e44ad, 0x4aa3c8, 0xe85a9a].map(func(c): return MathX.col(c))
	var trousers := [0x23304a, 0x2b2f36, 0x4a3a2a, 0x5a6a7a, 0x1b1b1b].map(func(c): return MathX.col(c))
	var skins := [0xe8b890, 0xd9a47a, 0xf0c8a0, 0xa9744a, 0x7a4f30].map(func(c): return MathX.col(c))
	var legs := []; var lc := []; var body := []; var bc := []; var head := []; var hc := []
	for q in pts:
		var s := 0.9 + World.rnd.next() * 0.2
		var b := Basis(Vector3.UP, q[3]).scaled_local(Vector3(s, s, s))
		legs.append(Transform3D(b, Vector3(q[0], q[1] + 0.42 * s, q[2]))); lc.append(World.pick(trousers))
		body.append(Transform3D(b, Vector3(q[0], q[1] + 1.14 * s, q[2]))); bc.append(World.pick(shirts))
		head.append(Transform3D(b, Vector3(q[0], q[1] + 1.62 * s, q[2]))); hc.append(World.pick(skins))
	World.inst(Geo.box(0.36, 0.84, 0.22), Mats.M(0xffffff), legs, lc, false)
	World.inst(Geo.box(0.48, 0.62, 0.26), Mats.M(0xffffff), body, bc, true)
	World.inst(Geo.sphere(0.16, 6, 5), Mats.M(0xffffff), head, hc, false)

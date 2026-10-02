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
		lp.append(World.mtx(xz[0], Trk.HT[i] + h / 2, xz[1]))
		lh.append(World.mtx(hxz[0], Trk.HT[i] + h, hxz[1], Trk.heading_of(Trk.T[i])))
		var pxz := Trk.onTrack(i, sd * (latAbs - 4))
		World.trackLights.append([pxz[0], Trk.HT[i], pxz[1], 9])
		d += every
	World.inst(Geo.cylinder(0.08, 0.11, h, 6), pm, lp, null, true)
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

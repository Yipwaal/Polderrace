class_name Dress
## Port of "roadside dressing for every track" (dressTrack and its helpers) from polderrace-3d.html.
## Same seeded random order as the JS (World.rnd), so everything lands on the same spot.

## parked cars need the car builder (scripts/car); it registers itself here: func(type: String, color: Color) -> Node3D
static var car_builder: Callable = Callable()

static func rnd() -> float:
	return World.rnd.next()

static func M(c: int, o: Dictionary = {}) -> LMat:
	return Mats.M(c, o)

static func groundY(x: float, z: float) -> float:
	if Trk.terrain_fn.is_valid() and (Trk.TRACK_ID == "veluwe" or Trk.TRACK_ID == "limburg"):
		return Trk.terrain_fn.call(x, z).h
	return 0.0

static func alongSides(every: float, latFn: Callable, fn: Callable) -> void:
	var d := rnd() * every
	while d < Trk.TRACK_LEN:
		var i := int(round(d / Trk.SPC)) % Trk.NS
		for s in [-1, 1]:
			var lat = latFn.call(i, s)
			if lat != null:
				var xz := Trk.onTrack(i, s * lat)
				if not (Trk.distToTrack(xz[0], xz[1]) < (12.0 if Trk.TRK.get("terrain", false) else Trk.ROAD_HALF + 1)):
					fn.call(xz[0], xz[1], i, s)
		d += every * (0.7 + rnd() * 0.6)

static func edgeLat(i: int, extra: float) -> float:
	return Trk.SHOULDER + Trk.EMB[i] + extra

static func _cols(list: Array) -> Array:
	return list.map(func(k): return MathX.col(k) if k is int else Color(k))

static func flowers(every: float, near: float, far: float, cols = null) -> void:
	var m := []; var c := []
	var pal := _cols(cols if cols != null else ["#e8e4dc", "#f2c200", "#c8302a", "#9a5ab8", "#f36f21"])
	alongSides(every, func(i, _s): return edgeLat(i, near + rnd() * (far - near)), func(x, z, _i, _s):
		for _k in 4:
			var px: float = x + (rnd() - .5) * 2.4
			var pz: float = z + (rnd() - .5) * 2.4
			m.append(World.mtx(px, groundY(px, pz) + 0.18, pz, 0, 0.22 + rnd() * 0.12))
			c.append(World.pick(pal)))
	World.inst(Geo.sphere(1, 6, 4), M(0xffffff), m, c, false)

static func reeds(every: float, near: float, far: float) -> void:
	var m := []
	alongSides(every, func(i, _s): return edgeLat(i, near + rnd() * (far - near)), func(x, z, _i, _s):
		for _k in 6:
			var px: float = x + (rnd() - .5) * 2
			var pz: float = z + (rnd() - .5) * 2
			var h := 1.2 + rnd() * 0.8
			m.append(World.mtx(px, groundY(px, pz) + h / 2, pz, rnd() * 6, 0.12, h, 0.12)))
	World.inst(Geo.cone(1, 1, 4), M(0x8a9a4a), m, null, false)

static func bushes(every: float, near: float, far: float, col := 0x4f7a3a) -> void:
	var m := []
	alongSides(every, func(i, _s): return edgeLat(i, near + rnd() * (far - near)), func(x, z, _i, _s):
		var s := 0.8 + rnd() * 1.2
		m.append(World.mtx(x, groundY(x, z) + s * 0.6, z, rnd() * 6, s, s * 0.8, s)))
	World.inst(Geo.sphere(1, 7, 5), M(col), m, null, true)

static func fences(every: float, lat: float) -> void:
	var p := []; var r := []
	var d := 0.0
	while d < Trk.TRACK_LEN:
		var i := int(round(d / Trk.SPC)) % Trk.NS
		for s in [-1, 1]:
			var l := edgeLat(i, lat)
			var xz := Trk.onTrack(i, s * l)
			var x: float = xz[0]; var z: float = xz[1]
			if Trk.distToTrack(x, z) < Trk.ROAD_HALF + 2: continue
			var y := groundY(x, z)
			p.append(World.mtx(x, y + 0.6, z))
			var j := int(round(minf(d + every, Trk.TRACK_LEN) / Trk.SPC)) % Trk.NS
			var xz2 := Trk.onTrack(j, s * edgeLat(j, lat))
			var x2: float = xz2[0]; var z2: float = xz2[1]
			var len := Vector2(x2 - x, z2 - z).length()
			if len > every * 1.6: continue
			var yaw := atan2(x2 - x, z2 - z)
			var y2 := groundY(x2, z2)
			# rails run from post to post and follow the slope (rotation order YXZ)
			for h in [0.45, 0.9]:
				var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -atan2(y2 - y, len))
				b = b.scaled_local(Vector3(0.08, 0.1, Vector2(len, y2 - y).length()))
				r.append(Transform3D(b, Vector3((x + x2) / 2, (y + y2) / 2 + h, (z + z2) / 2)))
		d += every
	World.inst(Geo.box(0.14, 1.2, 0.14), M(0x6b4a2e), p, null, true)
	World.inst(Geo.box(1, 1, 1), M(0x8a6a4a), r, null, false)

static func planters(every: float, lat: float) -> void:
	var b := []; var f := []; var c := []
	var pal := _cols(["#c8302a", "#f2c200", "#e8e4dc", "#9a5ab8"])
	var d := rnd() * every
	while d < Trk.TRACK_LEN:
		var i := int(round(d / Trk.SPC)) % Trk.NS
		if Trk.HT[i] > 0.2:
			d += every; continue
		var s := -1 if rnd() < 0.5 else 1
		var xz := Trk.onTrack(i, s * lat)
		var x: float = xz[0]; var z: float = xz[1]
		var busy := World.pavBusy(x, z, 0.75)
		if not busy:
			b.append(World.mtx(x, 0.45, z, Trk.heading_of(Trk.T[i]), 1.4, 0.5, 0.7))
			World.pavTaken.append([x, z, 0.75])
		for _k in 5:
			# a taken spot still draws its rnd() calls, so nothing else moves
			var fx := x + (rnd() - .5) * 1.1
			var fz := z + (rnd() - .5) * 0.5
			var fc = World.pick(pal)
			if not busy:
				f.append(World.mtx(fx, 0.82, fz, 0, 0.16)); c.append(fc)
		d += every
	World.inst(Geo.box(1, 1, 1), M(0x6b4a2e), b, null, true)
	World.inst(Geo.sphere(1, 6, 4), M(0xffffff), f, c, false)

static func benches(every: float, lat: float) -> void:
	var m := []; var l := []
	var d := rnd() * every
	while d < Trk.TRACK_LEN:
		var i := int(round(d / Trk.SPC)) % Trk.NS
		if Trk.HT[i] > 0.2:
			d += every; continue
		var s := -1 if rnd() < 0.5 else 1
		var xz := Trk.onTrack(i, s * lat)
		var x: float = xz[0]; var z: float = xz[1]
		var h := Trk.heading_of(Trk.T[i])
		if not World.pavBusy(x, z, 0.95):
			m.append(World.mtx(x, 0.5, z, h, 0.45, 0.08, 1.8))
			m.append(World.mtx(x + cos(h) * s * 0.2, 0.8, z - sin(h) * s * 0.2, h, 0.06, 0.5, 1.8))
			l.append(World.mtx(x, 0.25, z, h, 0.4, 0.5, 0.1))
		d += every
	World.inst(Geo.box(1, 1, 1), M(0x7a5a3a), m, null, true)
	World.inst(Geo.box(1, 1, 1), M(0x2b2f36), l, null, false)

static func parkedCars(n: int, lat: float, filter = null) -> void:
	var cols := ["#d62a2a", "#1d4f9e", "#ecece8", "#2b2f36", "#2f8f5b", "#8a8f96", "#f2c200"]
	var placed := 0
	var spots := []
	var t := 0
	while t < n * 4 and placed < n:
		t += 1
		var i := int(floor(rnd() * Trk.NS))
		if Trk.HT[i] > 0.2 or (filter != null and not filter.call(i)): continue
		var s := -1 if rnd() < 0.5 else 1
		var xz := Trk.onTrack(i, s * lat)
		var x: float = xz[0]; var z: float = xz[1]
		var hit := false
		for sp in spots:
			if (sp[0] - x) * (sp[0] - x) + (sp[1] - z) * (sp[1] - z) < 49: hit = true
		if hit: continue
		spots.append([x, z])
		var type: String = World.pick(["hatch", "sedan", "coupe", "rally"])
		var col := Color(World.pick(cols))
		var ry := Trk.heading_of(Trk.T[i]) + (0.0 if rnd() < 0.5 else PI)
		if car_builder.is_valid():
			var g: Node3D = car_builder.call(type, col)
			g.position = Vector3(x, 0, z)
			g.rotation.y = ry
			for mi in g.find_children("*", "GeometryInstance3D", true, false):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			World.add(g)
		placed += 1

static func adBoards(every: float, lat: float) -> void:
	var texts := ["POLDERRACE", "DIJKBANDEN", "STROOPWAFEL", "KLOMPEN", "MOLENOLIE", "TULPENBOL"]
	var cols := ["#1d4f9e", "#c8302a", "#f2c200", "#2e5d3e", "#f36f21"]
	var mats := []
	for k in texts.size():
		var t: String = texts[k]
		mats.append(M(0xffffff, {"map": Canvas2D.tex(256, 64, func(g, w, h):
			g.fillStyle = cols[k % cols.size()]; g.fillRect(0, 0, w, h)
			g.fillStyle = "#161a22" if k % cols.size() == 2 else "#f7f7f2"
			g.font = "italic 800 40px Barlow Condensed"; g.textAlign = "center"; g.textBaseline = "middle"
			g.fillText(t, w / 2.0, h / 2.0 + 2))}))
	var per := []
	for _m in mats: per.append([])
	var n := 0
	var d := 20.0
	while d < Trk.TRACK_LEN:
		var i := int(round(d / Trk.SPC)) % Trk.NS
		for s in [-1, 1]:
			var xz := Trk.onTrack(i, s * lat)
			per[n % mats.size()].append(World.mtx(xz[0], Trk.HT[i] + 0.75, xz[1], Trk.heading_of(Trk.T[i]) + PI / 2, 0.12, 1.1, 5.4))
			n += 1
		d += every
	for k in per.size():
		World.inst(Geo.box(1, 1, 1), mats[k], per[k], null, false)

static func tyreStacks() -> void:
	var m := []
	var NS := Trk.NS
	var T := Trk.T
	for i in range(0, NS, 6):
		if Trk.CURV[i] < 0.018: continue
		var a := T[(i - 3 + NS) % NS]
		var b := T[(i + 3) % NS]
		var sg := MathX.sgn(a.z * b.x - a.x * b.z)
		if sg == 0: sg = 1
		var xz := Trk.onTrack(i, sg * 17.5)
		for k in 3:
			m.append(World.mtx(xz[0] + (k - 1) * 0.9 * T[i].x, Trk.HT[i] + 0.15 + 0.3 * (k % 2), xz[1] + (k - 1) * 0.9 * T[i].z, 0, 0.42, 0.3, 0.42))
	World.inst(Geo.cylinder(1, 1, 1, 12), M(0x1b1b1b), m, null, true)

static func crates(n: int) -> void:
	var m := []; var c := []
	var pal := _cols(["#8a6a4a", "#6b4a2e", "#1d4f9e", "#c8302a"])
	for _k in n:
		var s = World.clearSpot(12)
		if s == null: continue
		var h := 1 + int(floor(rnd() * 3))
		for y in h:
			m.append(World.mtx(s[0], 0.6 + y * 1.2, s[1], rnd() * 0.3, 1.2, 1.2, 1.2))
			c.append(World.pick(pal))
	World.inst(Geo.box(1, 1, 1), M(0xffffff), m, c, true)

static func beachHuts() -> void:
	var cols := ["#1d4f9e", "#c8302a", "#f2c200", "#2f8f5b", "#ecece8", "#f36f21"]
	var m := []; var c := []; var r := []
	for k in 26:
		var x := 180 + k * 44 + rnd() * 10
		var z := 440 + rnd() * 6
		if Trk.distToTrack(x, z) < 16: continue
		m.append(World.mtx(x, 1.3, z, 0, 3, 2.6, 3.2))
		c.append(Color(World.pick(cols)))
		r.append(World.mtx(x, 3.1, z, 0, 2.4, 1.2, 3.4))
	World.inst(Geo.box(1, 1, 1), M(0xffffff), m, c, true)
	World.inst(Geo.cone(1, 1, 4), M(0xecece8), r, null, true)

static func flagPoles(every: float, lat: float) -> void:
	var p := []; var f := []; var c := []
	var pal := _cols(["#ae1c28", "#21468b", "#f36f21", "#f2c200"])
	var d := 30.0
	while d < Trk.TRACK_LEN:
		var i := int(round(d / Trk.SPC)) % Trk.NS
		var s := 1 if int(d / every) % 2 else -1
		var xz := Trk.onTrack(i, s * edgeLat(i, lat))
		if not (Trk.distToTrack(xz[0], xz[1]) < Trk.ROAD_HALF + 2):
			p.append(World.mtx(xz[0], 4, xz[1]))
			f.append(World.mtx(xz[0] + 0.7, 7.2, xz[1], 0, 1.4, 0.9, 0.05))
			c.append(World.pick(pal))
		d += every
	World.inst(Geo.cylinder(0.05, 0.07, 8, 6), M(0xe8e4dc), p, null, false)
	World.inst(Geo.box(1, 1, 1), M(0xffffff), f, c, false)

static func horizonHills() -> void:
	var cx := (Trk.BX0 + Trk.BX1) / 2
	var cz := (Trk.BZ0 + Trk.BZ1) / 2
	for spec in [[1500.0, 0x3f5a3a, 0.62, 1.0, 1.3], [1180.0, 0x4a6a3f, 0.48, 0.62, 4.1]]:
		var R0: float = spec[0]; var base: int = spec[1]; var k: float = spec[2]; var amp: float = spec[3]; var seed: float = spec[4]
		var n := 160
		var g := Geo.new()
		for i in n + 1:
			var a := float(i) / n * PI * 2
			var h := amp * (45 + 60 * absf(sin(a * 3.3 + seed)) + 38 * absf(sin(a * 7.1 + seed * 2)) + 18 * sin(a * 13 + seed))
			var x := cx + cos(a) * R0
			var z := cz + sin(a) * R0
			g.pos.append(Vector3(x, -6, z)); g.pos.append(Vector3(x, h, z))
		for i in n:
			var A := i * 2
			g.idx.append_array([A, A + 1, A + 2, A + 1, A + 3, A + 2])
		var m := Mats.basic(base, {"side": "double", "fog": false})
		m.set_meta("base", MathX.col(base)); m.set_meta("k", k)
		World.hillMats.append(m)
		var mesh := O3.mesh(g, m)
		mesh.extra_cull_margin = 16384
		m.render_priority = -5
		World.add(mesh)

static var _grimeTex: ImageTexture
static func grimeTex() -> ImageTexture:
	if _grimeTex == null:
		_grimeTex = Canvas2D.tex(64, 256, func(g, w, h):
			g.clearRect(0, 0, w, h)
			for _i in 260:
				g.fillStyle = "rgba(20,16,12,%f)" % (0.08 + randf() * 0.22)
				var x: float = randf() * w
				var y: float = randf() * h
				g.beginPath(); g.ellipse(x, y, 4 + randf() * 10, 2 + randf() * 4, 0, 0, PI * 2); g.fill(), true)
	return _grimeTex

static func roadGrime() -> void:
	var m := M(0xffffff, {"map": grimeTex(), "transparent": true, "depthWrite": false, "opacity": 0.75})
	for sd in [-1, 1]:
		World.ribbon(sd * (Trk.ROAD_HALF - 0.55), sd * (Trk.ROAD_HALF + 0.55), m, 6, 0.085)

static func grassTufts(every: float, near: float, far: float) -> void:
	var m := []; var c := []
	var pal := _cols([0x6f9a3a, 0x86ac48, 0x5f8a34, 0x9ab54a])
	alongSides(every, func(i, _s): return edgeLat(i, near + rnd() * (far - near)), func(x, z, _i, _s):
		for _k in 5:
			var px: float = x + (rnd() - .5) * 2.6
			var pz: float = z + (rnd() - .5) * 2.6
			var h := 0.35 + rnd() * 0.4
			m.append(World.mtx(px, groundY(px, pz) + h / 2, pz, rnd() * 6, 0.22 + rnd() * 0.15, h, 0.22 + rnd() * 0.15))
			c.append(World.pick(pal)))
	World.inst(Geo.cone(1, 1, 4), M(0xffffff), m, c, false)

static func dressTrack(id: String) -> void:
	roadGrime()
	if not id in ["afsluitdijk", "zeeland", "haven"]: horizonHills()
	if id == "polder": grassTufts(6, 0.2, 1.2)
	elif id in ["afsluitdijk", "circuit", "veluwe", "limburg", "zeeland"]: grassTufts(6, 0.4, 4)
	match id:
		"polder": reeds(9, 2, 5); flowers(7, 1, 8); fences(6, 14)
		"dorp": planters(18, 7.5); benches(55, 7.7)
		"circuit": adBoards(26, 19.6); tyreStacks(); flowers(12, 4, 12, ["#f2c200", "#e8e4dc"])
		"afsluitdijk": reeds(8, 4, 10); bushes(40, 6, 16, 0x5f7f3a)
		"haven": crates(40)
		"veluwe":
			bushes(7, 3, 14, 0x3f6a2a); flowers(14, 2, 10, ["#e8e4dc", "#c8302a"])
			var lg := []
			alongSides(38, func(_i, _s): return 12 + rnd() * 10, func(x, z, _i, _s):
				lg.append(World.mtx(x, groundY(x, z) + 0.3, z, rnd() * 6, 0.6, 0.6, 4 + rnd() * 3)))
			World.inst(Geo.box(1, 1, 1), M(0x5a3f2a), lg, null, true)
		"grachten": planters(16, 6.5); benches(40, 6.6)
		"limburg": fences(6, 4); bushes(5, 2.5, 4.5, 0x3f6a2a); flowers(6, 1, 6)
		"rotterdam": _dressRotterdam()
		"zeeland": beachHuts(); flagPoles(120, 6); reeds(10, 6, 14)

static func _dressRotterdam() -> void:
	var tr := []; var tk := []
	var d := 5.0
	while d < Trk.TRACK_LEN:
		var i := int(round(d / Trk.SPC)) % Trk.NS
		if Trk.HT[i] <= 1:
			for s in [-1, 1]:
				var xz := Trk.onTrack(i, s * 11.2)
				tk.append(World.mtx(xz[0], 2, xz[1]))
				tr.append(World.mtx(xz[0], 5.2, xz[1], rnd() * 6, 2.6, 3, 2.6))
		d += 18
	World.inst(Geo.cylinder(0.18, 0.24, 4, 6), M(0x5a3f2a), tk, null, true)
	World.inst(Geo.sphere(1, 8, 6), M(0x4f7a3a), tr, null, true)
	parkedCars(14, 12.6, func(i): return Trk.HT[i] < 0.2)
	var bm := M(0xffffff, {"map": Canvas2D.tex(64, 128, func(g, w, h):
		g.fillStyle = "#1d4f9e"; g.fillRect(0, 0, w, h); g.fillStyle = "#f2c200"; g.fillRect(6, 6, w - 12, h - 40)
		g.fillStyle = "#fff"; g.font = "800 16px Barlow Condensed"; g.textAlign = "center"; g.fillText("R'DAM", w / 2.0, h - 14))})
	World.winMats.append(bm)
	var bs := []
	d = 60.0
	while d < Trk.TRACK_LEN:
		var i := int(round(d / Trk.SPC)) % Trk.NS
		if Trk.HT[i] <= 0.5:
			var xz := Trk.onTrack(i, -12.8)
			bs.append(World.mtx(xz[0], 1.6, xz[1], Trk.heading_of(Trk.T[i]), 0.5, 3.2, 1.4))
		d += 150
	World.inst(Geo.box(1, 1, 1), bm, bs, null, true)

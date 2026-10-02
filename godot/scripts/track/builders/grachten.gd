class_name BuildGrachten
## Port of buildGrachten from polderrace-3d.html: Amsterdam canals under humpback bridges, rows of narrow canal houses
## with gables, trees, bollards and street lamps. Same numbers, same seeded random order (World.rnd).

static func M(c: int, o: Dictionary = {}) -> LMat:
	return Mats.M(c, o)

static func rnd() -> float:
	return World.rnd.next()

static func build() -> void:
	var NS := Trk.NS
	var SPC := Trk.SPC
	var T := Trk.T
	var HT := Trk.HT
	var P := Trk.P
	var TRACK_LEN := Trk.TRACK_LEN
	var RH := Trk.ROAD_HALF
	var SH := Trk.SHOULDER
	World.groundPlane(Canvas2D.tex(128, 128, func(g, w, h):
		g.fillStyle = "#8f877b"; g.fillRect(0, 0, w, h); g.strokeStyle = "rgba(60,50,40,.3)"
		var i := 0
		while i < w:
			g.beginPath(); g.moveTo(i, 0); g.lineTo(i, h); g.stroke(); g.beginPath(); g.moveTo(0, i); g.lineTo(w, i); g.stroke()
			i += 16, true), 16)
	var rt := World.roadTexture("#7a5a4a", [], false, true)
	World.ribbon(-RH, RH, World.roadMat(rt, {"repeat": Vector2(4, 1)}), 6, 0.07)
	var sw := M(0xb9b4aa); World.ribbon(-SH, -RH, sw, 3, 0.2); World.ribbon(RH, SH, sw, 3, 0.2)
	var curb := M(0x9d9990); World.vribbon(-RH, 0.07, 0.2, curb, 1); World.vribbon(RH, 0.07, 0.2, curb, 1)
	World.startLine(); World.gates(Trk.TRK)
	# a canal under every humpback bridge (local height maxima above 1.5 m, at least 40 samples apart)
	var bridges := []
	for i in NS:
		var a := HT[(i - 1 + NS) % NS]
		var b := HT[(i + 1) % NS]
		if HT[i] > 1.5 and HT[i] >= a and HT[i] >= b and not bridges.any(func(k): return absi(k - i) < 40):
			bridges.append(i)
	var canals := bridges.map(func(ib): return {"p": Trk.P[ib], "t": Trk.T[ib], "r": Trk.R[ib]})
	var inCanal := func(x: float, z: float) -> bool:
		for c in canals:
			if absf((x - c.p.x) * c.t.x + (z - c.p.z) * c.t.z) < 13 and absf((x - c.p.x) * c.r.x + (z - c.p.z) * c.r.z) < 260:
				return true
		return false
	var brick := M(0x7a3a2c)
	var water := Mats.phong(0x3a5560, {"specular": 0x8fa6bb, "shininess": 80})
	# a canal runs 260 m to both sides of its bridge and can meet another part of the track at street level. There the
	# street dams it: water and quay walls stop 0.6 m short of the pavement and a cross wall closes the canal off.
	# dams(c) = local x ranges along the canal taken by a street-level road.
	var roadDist := func(x: float, z: float) -> Array:
		var bb := 1e9
		var bi := 0
		for i in NS:
			var p := P[i]
			var q := P[(i + 1) % NS]
			var ex: float = q.x - p.x
			var ez: float = q.z - p.z
			var f := clampf(((x - p.x) * ex + (z - p.z) * ez) / (ex * ex + ez * ez), 0, 1)
			var dx: float = x - p.x - ex * f
			var dz: float = z - p.z - ez * f
			var dd := dx * dx + dz * dz
			if dd < bb:
				bb = dd; bi = i
		return [sqrt(bb), bi]
	var dams := func(c: Dictionary) -> Array:
		var out := []
		var cur = null
		var u := -260.0
		while u <= 260:
			var hit := false
			for v in [-10.75, 0.0, 10.75]:
				var x: float = c.p.x + c.t.z * u + c.t.x * v
				var z: float = c.p.z - c.t.x * u + c.t.z * v
				if Trk.distToTrack(x, z) > SH + 4: continue
				var r: Array = roadDist.call(x, z)
				if r[0] < SH + 0.6 and Trk.HT[r[1]] < 1: hit = true
			if hit:
				if cur == null: cur = [u - 0.5, u]
				cur[1] = u + 0.5
			elif cur != null:
				out.append(cur); cur = null
			u += 0.5
		if cur != null: out.append(cur)
		return out
	for c in canals:
		var g := O3.group(c.p.x, 0, c.p.z)
		O3.rot(g, 0, Trk.heading_of(c.t), 0)
		var dm: Array = dams.call(c)
		var parts := []
		var a := -260.0
		for d01 in dm:
			if d01[0] > a: parts.append([a, d01[0]])
			a = maxf(a, d01[1])
		if a < 260: parts.append([a, 260.0])
		for ab in parts:
			var pa: float = ab[0]
			var pb: float = ab[1]
			var w := O3.mesh(Geo.plane(pb - pa, 20), water, (pa + pb) / 2, 0.05, 0, g)
			O3.rot(w, -PI / 2, 0, 0)
			for s in [-1, 1]:
				World.box(pb - pa, 0.5, 0.7, brick, (pa + pb) / 2, 0.22, s * 10.4, g, false)
			if pa > -260: World.box(0.7, 0.5, 20.1, brick, pa + 0.35, 0.22, 0, g, false)
			if pb < 260: World.box(0.7, 0.5, 20.1, brick, pb - 0.35, 0.22, 0, g, false)
		var hb := [0x2e5d3e, 0x7a2a2a, 0x1d4f9e, 0x3a3e45]
		for k in 5:
			var x := -220 + k * 95 + rnd() * 20
			if absf(x) < 18: continue
			var s := 1 if k % 2 else -1
			var col: int = World.pick(hb)
			if dm.any(func(d01): return x + 8 > d01[0] and x - 8 < d01[1]): continue
			World.box(14, 1.6, 3.6, M(col), x, 0.8, s * 7.2, g); World.box(9, 2.2, 3, M(0xe8e4dc), x - 1, 2.7, s * 7.2, g)
			World.box(9.4, 0.2, 3.4, M(0x3a3e45), x - 1, 3.9, s * 7.2, g, false)
		World.add(g)
	var hump := func(i): return Trk.HT[i] > 0.05
	var top := func(i): return Trk.HT[i] > 0.35
	for s in [-1, 1]:
		World.vribbon(s * SH, -4, 0.2, brick, 3, hump); World.vribbon(s * (SH - 0.01), 0.2, 1.1, M(0x2b2f36), 3, top)
	var cols := ["#7a3a2c", "#5a2a22", "#8c4a32", "#3b3530", "#6b5a4a", "#9a8f7a", "#2f3033"].map(func(c): return Color(c))
	var fm := M(0xffffff, {"map": TrackCommon.facadeTex(4), "emissive": 0x000000, "emissiveMap": Canvas2D.tex(128, 256, func(g, w, h):
		g.fillStyle = "#000"; g.fillRect(0, 0, w, h)
		var fh: float = h / 4.6
		for f in 4:
			for x in [14, 52, 90]:
				if randf() < 0.6:
					g.fillStyle = "#ffd890"; g.fillRect(x, h - fh * (f + 1) - 4, 24, fh * 0.62))})
	World.winMats.append(fm)
	var hB := []; var hC := []; var gB := []; var gC := []; var placed := []
	for sd in [-1, 1]:
		var s := 0.0
		while s < TRACK_LEN:
			var w := 4.6 + rnd() * 2.4
			var dep := 10 + rnd() * 3
			var i := int(round((s + w / 2) / SPC)) % NS
			var lat: float = sd * (SH + 0.3 + dep / 2)
			var xz := Trk.onTrack(i, lat)
			var x: float = xz[0]; var z: float = xz[1]
			if Trk.distToTrack(x, z) < absf(lat) - 0.6 or inCanal.call(x, z) or placed.any(func(o): return sqrt((o[0] - x) * (o[0] - x) + (o[1] - z) * (o[1] - z)) < (w + o[2]) / 2 + 0.05):
				s += 3; continue
			placed.append([x, z, w])
			var hh := 10 + rnd() * 6
			var ry := Trk.heading_of(T[i])
			var c = World.pick(cols)
			hB.append(World.mtx(x, hh / 2, z, ry, dep, hh, w * 0.98)); hC.append(c)
			# gable: a cube turned 45 deg about the house's depth axis, so the point faces the street and it is exactly as
			# wide as its own house (w along the road) and runs back over its depth
			var q := Basis(Vector3.UP, ry) * Basis(Vector3.RIGHT, PI / 4)
			gB.append(Transform3D(q.scaled_local(Vector3(dep * 0.98, w * 0.69, w * 0.69)), Vector3(x, hh, z))); gC.append(c)
			s += w
	World.inst(Geo.box(1, 1, 1), fm, hB, hC, true); World.inst(Geo.box(1, 1, 1), M(0xffffff), gB, gC, true)
	var tr := []
	var d := 6.0
	while d < TRACK_LEN:
		var i := int(round(d / SPC)) % NS
		if HT[i] > 0.1:
			d += 17; continue
		var s := 1 if int(d / 17) % 2 else -1
		var xz := Trk.onTrack(i, s * 6.1)
		if inCanal.call(xz[0], xz[1]):
			d += 17; continue
		tr.append(World.mtx(xz[0], 5.4, xz[1], rnd() * 6, 3.2, 3.4, 3.2))
		d += 17
	World.inst(Geo.sphere(1, 8, 6), M(0x4f7a3a), tr, null, true)
	var bol := []
	d = 0.0
	while d < TRACK_LEN:
		var i := int(round(d / SPC)) % NS
		for l in [-5.4, 5.4]:
			var xz := Trk.onTrack(i, l)
			bol.append(World.mtx(xz[0], HT[i] + 0.62, xz[1]))
		d += 2.6
	World.inst(Geo.cylinder(0.08, 0.1, 0.85, 7), M(0x5a1f1a), bol, null, false)
	TrackCommon.lampRow(6.6, 30, 4.8, {"both": true})

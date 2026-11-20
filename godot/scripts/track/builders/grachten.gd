class_name BuildGrachten
## Amsterdam canals. Started as a port of buildGrachten from polderrace-3d.html; fase 2 made it a canal city:
## the canals lie 1.3 m below the street between brick quay walls (the ground has trenches for them), the three
## bridges are real arches you can see and sail under, with stone parapets, lanterns and parked bikes; the canal
## houses have brick fronts with tall windows and step, neck, bell and spout gables with a hoisting beam, tiled roofs,
## and more rows of them line the quays along the canals, so the city no longer ends behind the first row; elms with
## high crowns (clear of the road and the camera), moored boats, a tour boat that sails under the bridge, the
## Westertoren over the roofs, flags and fans. Everything random comes from the seeded World.rnd.

static func M(c: int, o: Dictionary = {}) -> LMat:
	return Mats.M(c, o)

static func rnd() -> float:
	return World.rnd.next()

const CANAL := 260.0      ## a canal runs this far to both sides of its bridge
const WATER_Y := -1.3
const QUAY := 8.3         ## from the water's edge to the house fronts along a canal

## the canals: {p, t, r (bridge centre, track direction, right), i (sample), parts: [[u0, u1], ...] (stretches of water
## along the canal, u = distance along r), k (index)}
static var canals: Array = []

static func inCanal(x: float, z: float, along := 13.0, far := CANAL) -> bool:
	for c in canals:
		if absf((x - c.p.x) * c.t.x + (z - c.p.z) * c.t.z) < along and absf((x - c.p.x) * c.r.x + (z - c.p.z) * c.r.z) < far:
			return true
	return false

## world position of canal coordinates (u along the canal, v across it: along the track)
static func cpos(c: Dictionary, u: float, v: float) -> Vector2:
	return Vector2(c.p.x + c.r.x * u + c.t.x * v, c.p.z + c.r.z * u + c.t.z * v)

## the canal-house front: brick courses, three tall windows a floor with white frames, a cornice, a door with a fanlight
static func frontTex() -> ImageTexture:
	return Canvas2D.tex(128, 256, func(g, w, h):
		g.fillStyle = "#ffffff"; g.fillRect(0, 0, w, h)
		g.strokeStyle = "rgba(0,0,0,.10)"; g.lineWidth = 1
		var y := 0
		while y < h:
			g.beginPath(); g.moveTo(0, y); g.lineTo(w, y); g.stroke()
			y += 6
		var fh: float = h / 4.6
		for f in 4:
			for x in [14, 52, 90]:
				g.fillStyle = "#f4f1e8"; g.fillRect(x - 3, h - fh * (f + 1) - 7, 30, fh * 0.62 + 6)
				g.fillStyle = "#1f2a33"; g.fillRect(x, h - fh * (f + 1) - 4, 24, fh * 0.62)
				g.fillStyle = "#f4f1e8"; g.fillRect(x + 11, h - fh * (f + 1) - 4, 2, fh * 0.62); g.fillRect(x, h - fh * (f + 1) - 4 + fh * 0.3, 24, 2)
		g.fillStyle = "#f4f1e8"; g.fillRect(0, 0, w, 7); g.fillRect(0, h - fh - 12, w, 4)
		g.fillStyle = "#ece6d6"; g.fillRect(48, h - fh * 0.95, 32, fh * 0.95)
		g.fillStyle = "#24352a"; g.fillRect(52, h - fh * 0.7, 24, fh * 0.7)
		g.fillStyle = "#1f2a33"; g.fillRect(52, h - fh * 0.9, 24, fh * 0.16)
		g.fillStyle = "#8a857c"; g.fillRect(0, h - 8, w, 8))

static func litTex() -> ImageTexture:
	return Canvas2D.tex(128, 256, func(g, w, h):
		g.fillStyle = "#000"; g.fillRect(0, 0, w, h)
		var fh: float = h / 4.6
		for f in 4:
			for x in [14, 52, 90]:
				if randf() < 0.6:
					g.fillStyle = "#ffd890"; g.fillRect(x, h - fh * (f + 1) - 4, 24, fh * 0.62))

## a gable outline (z across the front -0.5..0.5, y up 0..1) as a slab 1 thick in x, with a hoisting beam and hook
static func gableGeo(kind: int) -> Geo:
	var pts := []
	match kind:
		0:   # step gable
			pts = [Vector2(-0.5, 0), Vector2(-0.5, 0.22), Vector2(-0.36, 0.22), Vector2(-0.36, 0.44), Vector2(-0.22, 0.44), Vector2(-0.22, 0.66), Vector2(-0.09, 0.66), Vector2(-0.09, 0.9),
				Vector2(0.09, 0.9), Vector2(0.09, 0.66), Vector2(0.22, 0.66), Vector2(0.22, 0.44), Vector2(0.36, 0.44), Vector2(0.36, 0.22), Vector2(0.5, 0.22), Vector2(0.5, 0)]
		1:   # neck gable
			pts = [Vector2(-0.5, 0), Vector2(-0.5, 0.1), Vector2(-0.3, 0.2), Vector2(-0.21, 0.42), Vector2(-0.21, 0.82), Vector2(0, 1.0), Vector2(0.21, 0.82), Vector2(0.21, 0.42), Vector2(0.3, 0.2), Vector2(0.5, 0.1), Vector2(0.5, 0)]
		2:   # bell gable
			pts = [Vector2(-0.5, 0)]
			for k in 13:
				var z := -0.5 + k / 12.0
				pts.append(Vector2(z, 0.12 + 0.8 * pow(0.5 + 0.5 * cos(z * TAU), 0.75)))
			pts.append(Vector2(0.5, 0))
		_:   # spout gable
			pts = [Vector2(-0.5, 0), Vector2(-0.09, 0.82), Vector2(-0.09, 0.98), Vector2(0.09, 0.98), Vector2(0.09, 0.82), Vector2(0.5, 0)]
	var slab := Geo.extrude(pts, 1.0)
	slab.rotate_y(PI / 2)            # the outline now stands in the z-y plane, 1 thick along x
	slab.translate(-0.5, 0, 0)
	return BKit.merge([
		[slab, 0xffffff],
		[Geo.box(1.0, 0.035, 0.6).translate(0.02, 1.0 if kind == 1 else 0.92, 0), 0xf4f1e8],   # white coping on top
		[Geo.box(1.9, 0.05, 0.05).translate(0.9, 0.6, 0), 0x2a2622],
		[Geo.box(0.12, 0.09, 0.09).translate(1.75, 0.53, 0), 0x2a2622]])

static func build() -> void:
	var NS := Trk.NS
	var SPC := Trk.SPC
	var T := Trk.T
	var HT := Trk.HT
	var TRACK_LEN := Trk.TRACK_LEN
	var RH := Trk.ROAD_HALF
	var SH := Trk.SHOULDER
	findCanals()
	ground()
	var rt := World.roadTexture("#7a5a4a", [], false, true)
	World.ribbon(-RH, RH, World.roadMat(rt, {"repeat": Vector2(4, 1)}), 6, 0.07)
	var sw := M(0x9c978d, {"map": paveTex(), "repeat": Vector2(1, 1)})
	World.ribbon(-SH, -RH, sw, 2, 0.2); World.ribbon(RH, SH, sw, 2, 0.2)
	var curb := M(0x8d8980); World.vribbon(-RH, 0.07, 0.2, curb, 1); World.vribbon(RH, 0.07, 0.2, curb, 1)
	World.startLine(); World.gates(Trk.TRK)
	water()
	bridges()
	# houses along the track, then along the quays of the canals
	var cols := ["#7a3a2c", "#5a2a22", "#8c4a32", "#3b3530", "#6b5a4a", "#9a8f7a", "#2f3033", "#84402e", "#6a3326"].map(func(c): return Color(c))
	var roofs := ["#3a3432", "#4a3630", "#2e3034", "#5a3a2c"].map(func(c): return Color(c))
	var H := {"hB": [], "hC": [], "rB": [], "rC": [], "g": [[], [], [], []], "gc": [[], [], [], []], "placed": []}
	var addHouse := func(x: float, z: float, ry: float, w: float, dep: float, front: float) -> void:
		# ry: local +x looks at the street; front: where the facade stands on local x (dep / 2)
		var hh := 10 + rnd() * 6
		var c: Color = World.pick(cols)
		var rc: Color = World.pick(roofs)
		var kind := int(floor(rnd() * 4))
		var gh := w * (0.62 + rnd() * 0.2)
		H.hB.append(Transform3D(Basis(Vector3.UP, ry).scaled_local(Vector3(dep, hh, w * 0.98)), Vector3(x, hh / 2, z))); H.hC.append(c)
		H.rB.append(Transform3D(Basis(Vector3.UP, ry).scaled_local(Vector3(dep * 0.99, w * 0.5, w * 0.98)), Vector3(x, hh - 0.02, z))); H.rC.append(rc)
		# the gable stands on the front, a hand's width proud of it
		var gx := x + cos(ry) * (front - 0.12)
		var gz := z - sin(ry) * (front - 0.12)
		H.g[kind].append(Transform3D(Basis(Vector3.UP, ry).scaled_local(Vector3(0.5, gh, w * 0.98)), Vector3(gx, hh - 0.04, gz))); H.gc[kind].append(c)
	for sd in [-1, 1]:
		var s := 0.0
		while s < TRACK_LEN:
			var w := 4.6 + rnd() * 2.4
			var dep := 10 + rnd() * 3
			var i := int(round((s + w / 2) / SPC)) % NS
			var lat: float = sd * (SH + 0.3 + dep / 2)
			var xz := Trk.onTrack(i, lat)
			var x: float = xz[0]; var z: float = xz[1]
			if Trk.distToTrack(x, z) < absf(lat) - 0.6 or inCanal(x, z, 10.0 + QUAY + w / 2) or H.placed.any(func(o): return sqrt((o[0] - x) * (o[0] - x) + (o[1] - z) * (o[1] - z)) < (w + o[2]) / 2 + 0.05):
				s += 3; continue
			H.placed.append([x, z, w])
			# local +x = -R: the street side of a house on the right; the left ones turn round
			addHouse.call(x, z, Trk.heading_of(T[i]) + (0.0 if sd > 0 else PI), w, dep, dep / 2)
			s += w
	# rows along both quays of every canal, where the track's own rows leave room
	for c in canals:
		for bank in [-1.0, 1.0]:
			var u := -CANAL + 2.0
			while u < CANAL - 2:
				var w := 4.8 + rnd() * 2.6
				var dep := 9 + rnd() * 3
				var p := cpos(c, u + w / 2, bank * (10.0 + QUAY + dep / 2))
				u += w
				if Trk.distToTrack(p.x, p.y) < Trk.SHOULDER + 15 + dep / 2 or onOtherCanal(c, p.x, p.y, dep): continue
				if H.placed.any(func(o): return Vector2(o[0] - p.x, o[1] - p.y).length() < (dep + 13.0) / 2 + 1.0): continue
				H.placed.append([p.x, p.y, w])
				# the front looks at the canal: local +x = -bank * t
				addHouse.call(p.x, p.y, atan2(-bank * c.t.z, bank * c.t.x) + PI, w, dep, dep / 2)
		# and a block across both ends, so the canal does not run out into nothing
		for e in [-1.0, 1.0]:
			var v := -34.0
			while v < 34:
				var w := 5.0 + rnd() * 2.6
				var dep := 10.0
				var p := cpos(c, e * (CANAL + 2.5 + dep / 2), v + w / 2)
				v += w
				if Trk.distToTrack(p.x, p.y) < Trk.SHOULDER + 15 + dep / 2 or onOtherCanal(c, p.x, p.y, dep): continue
				if H.placed.any(func(o): return Vector2(o[0] - p.x, o[1] - p.y).length() < (dep + 13.0) / 2 + 1.0): continue
				H.placed.append([p.x, p.y, w])
				addHouse.call(p.x, p.y, atan2(-e * c.r.x, -e * c.r.z) + PI / 2, w, dep, dep / 2)
	var fm := M(0xffffff, {"map": frontTex(), "emissive": 0x000000, "emissiveMap": litTex()})
	World.winMats.append(fm)
	World.inst(Geo.box(1, 1, 1), fm, H.hB, H.hC, true)
	World.inst(TrackCommon.roofGeo().rotate_y(PI / 2), M(0xffffff), H.rB, H.rC, true)
	for k in 4:
		World.inst(gableGeo(k), M(0xffffff), H.g[k], H.gc[k], false)
	trees()
	var bol := []
	var d := 0.0
	while d < TRACK_LEN:
		var i := int(round(d / SPC)) % NS
		for l in [-5.4, 5.4]:
			var xz := Trk.onTrack(i, l)
			bol.append(World.mtx(xz[0], HT[i] + 0.62, xz[1]))
		d += 2.6
	World.inst(Geo.cylinder(0.08, 0.1, 0.85, 7), M(0x5a1f1a), bol, null, false)
	TrackCommon.lampRow(6.6, 30, 4.8, {"both": true})
	boats()
	tower()
	streetLife()

## is (x, z) on the water or the quay of another canal than c (houses of one canal stay off the next one)
static func onOtherCanal(c: Dictionary, x: float, z: float, dep: float) -> bool:
	for o in canals:
		if o == c: continue
		if absf((x - o.p.x) * o.t.x + (z - o.p.z) * o.t.z) < 10.0 + QUAY + dep / 2 + 3.5 and absf((x - o.p.x) * o.r.x + (z - o.p.z) * o.r.z) < CANAL + 16:
			return true
	return false

static func paveTex() -> ImageTexture:
	return Canvas2D.tex(64, 64, func(g, w, h):
		g.fillStyle = "#e6e6e6"; g.fillRect(0, 0, w, h)
		g.strokeStyle = "rgba(0,0,0,.22)"; g.lineWidth = 1
		for k in 4:
			g.beginPath(); g.moveTo(0, k * 16 + 0.5); g.lineTo(w, k * 16 + 0.5); g.stroke()
			g.beginPath(); g.moveTo(k * 16 + (8 if k % 2 else 0) + 0.5, 0); g.lineTo(k * 16 + (8 if k % 2 else 0) + 0.5, h); g.stroke()
		for _i in 60:
			g.fillStyle = "rgba(0,0,0,%f)" % (randf() * 0.08)
			g.fillRect(randf() * w, randf() * h, 5, 5), true)

## a canal under every humpback bridge (local height maxima above 1.5 m, at least 40 samples apart). A canal runs 260 m
## to both sides of its bridge and can meet another part of the track at street level. There the street dams it: the
## water stops 0.6 m short of the pavement and a quay wall closes the canal off. parts = the stretches of water.
static func findCanals() -> void:
	var NS := Trk.NS
	var HT := Trk.HT
	var P := Trk.P
	var SH := Trk.SHOULDER
	var bridges := []
	for i in NS:
		var a := HT[(i - 1 + NS) % NS]
		var b := HT[(i + 1) % NS]
		if HT[i] > 1.5 and HT[i] >= a and HT[i] >= b and not bridges.any(func(k): return absi(k - i) < 40):
			bridges.append(i)
	canals = []
	for ib in bridges:
		canals.append({"p": P[ib], "t": Trk.T[ib], "r": Trk.R[ib], "i": ib, "k": canals.size(), "parts": []})
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
	for c in canals:
		var dm := []
		var cur = null
		var u := -CANAL
		while u <= CANAL:
			var hit := false
			for v in [-10.75, 0.0, 10.75]:
				var q := cpos(c, u, v)
				if Trk.distToTrack(q.x, q.y) > SH + 4: continue
				var r: Array = roadDist.call(q.x, q.y)
				if r[0] < SH + 0.6 and HT[r[1]] < 1: hit = true
			if hit:
				if cur == null: cur = [u - 0.5, u]
				cur[1] = u + 0.5
			elif cur != null:
				dm.append(cur); cur = null
			u += 0.5
		if cur != null: dm.append(cur)
		var a := -CANAL
		for d01 in dm:
			if d01[0] > a + 4: c.parts.append([a, d01[0]])
			a = maxf(a, d01[1])
		if a < CANAL - 4: c.parts.append([a, CANAL])

## the ground: street tiles with a trench where the water lies (a canal is 1.3 m below the street), and round every
## trench a paved quay. The ground lies at -0.02; the quays of canal k at 0.02 k (two quays that cross are 2 cm apart).
static func ground() -> void:
	var tex := Canvas2D.tex(128, 128, func(g, w, h):
		g.fillStyle = "#857d72"; g.fillRect(0, 0, w, h); g.strokeStyle = "rgba(60,50,40,.3)"
		var i := 0
		while i < w:
			g.beginPath(); g.moveTo(i, 0); g.lineTo(i, h); g.stroke(); g.beginPath(); g.moveTo(0, i); g.lineTo(w, i); g.stroke()
			i += 16, true)
	var CS := 12.0
	var x0 := floorf((Trk.BX0 - 240) / CS) * CS
	var z0 := floorf((Trk.BZ0 - 240) / CS) * CS
	var nx := int(ceil((Trk.BX1 + 240 - x0) / CS))
	var nz := int(ceil((Trk.BZ1 + 240 - z0) / CS))
	var g := Geo.new()
	var quad := func(geo: Geo, ax: float, az: float, bx: float, bz: float, y: float, tile: float) -> void:
		var o := geo.pos.size()
		geo.pos.append_array([Vector3(ax, y, az), Vector3(bx, y, az), Vector3(bx, y, bz), Vector3(ax, y, bz)])
		for k in 4: geo.nrm.append(Vector3.UP)
		geo.uv.append_array([Vector2(ax / tile, az / tile), Vector2(bx / tile, az / tile), Vector2(bx / tile, bz / tile), Vector2(ax / tile, bz / tile)])
		geo.idx.append_array([o, o + 2, o + 1, o, o + 3, o + 2])
	for ix in nx:
		for iz in nz:
			var cx := x0 + (ix + 0.5) * CS
			var cz := z0 + (iz + 0.5) * CS
			var wet := false
			for c in canals:
				var u: float = (cx - c.p.x) * c.r.x + (cz - c.p.z) * c.r.z
				var v: float = (cx - c.p.x) * c.t.x + (cz - c.p.z) * c.t.z
				if absf(v) > 19.2: continue
				for pt in c.parts:
					if u > pt[0] - 9.2 and u < pt[1] + 9.2: wet = true
			if not wet: quad.call(g, x0 + ix * CS, z0 + iz * CS, x0 + (ix + 1) * CS, z0 + (iz + 1) * CS, -0.02, 16.0)
	# the land beyond, out to the horizon
	var X1 := x0 + nx * CS
	var Z1 := z0 + nz * CS
	quad.call(g, x0 - 1600, z0 - 1600, X1 + 1600, z0, -0.02, 16.0); quad.call(g, x0 - 1600, Z1, X1 + 1600, Z1 + 1600, -0.02, 16.0)
	quad.call(g, x0 - 1600, z0, x0, Z1, -0.02, 16.0); quad.call(g, X1, z0, X1 + 1600, Z1, -0.02, 16.0)
	var gm := O3.mesh(g, M(0xffffff, {"map": tex, "receiveShadow": true}))
	World.add(gm)
	# the quays: a paved frame round each stretch of water (local canal coordinates u, v)
	var qm := M(0x8f8a80, {"map": paveTex(), "receiveShadow": true})
	for c in canals:
		var q := Geo.new()
		var y: float = 0.02 * c.k
		var lq := func(u0: float, v0: float, u1: float, v1: float) -> void:
			var o := q.pos.size()
			for uv in [[u0, v0], [u1, v0], [u1, v1], [u0, v1]]:
				var p := cpos(c, uv[0], uv[1])
				q.pos.append(Vector3(p.x, y, p.y)); q.nrm.append(Vector3.UP); q.uv.append(Vector2(uv[0] / 2.0, uv[1] / 2.0))
			# (u, v) -> (r, t) is a right-handed pair seen from above when t = r turned left: wind both ways to be safe
			q.idx.append_array([o, o + 1, o + 2, o, o + 2, o + 3, o, o + 2, o + 1, o, o + 3, o + 2])
		var prev := -CANAL - 30.0
		for pt in c.parts:
			lq.call(prev, -30.0, pt[0], 30.0)                   # the street between two stretches of water (and the far end)
			lq.call(pt[0], -30.0, pt[1], -10.0); lq.call(pt[0], 10.0, pt[1], 30.0)
			prev = pt[1]
		lq.call(prev, -30.0, CANAL + 30.0, 30.0)
		World.add(O3.mesh(q, qm))

## the water, 1.3 m below the street, and the brick quay walls round it with a stone coping
static func water() -> void:
	var wat := Mats.phong(0x34505a, {"specular": 0x8fa6bb, "shininess": 80})
	var A := BKit.Acc.new(null, false)
	var brick := 0x70382b; var cope := 0x9a958c
	for c in canals:
		var ry := atan2(c.r.x, c.r.z) - PI / 2     # local x = along the canal (r)
		for pt in c.parts:
			var u0: float = pt[0]; var u1: float = pt[1]
			var mid := cpos(c, (u0 + u1) / 2, 0)
			var w := O3.mesh(Geo.plane(u1 - u0, 20), wat, mid.x, WATER_Y, mid.y)
			O3.rot(w, -PI / 2, 0, ry)
			World.add(w)
			A.at(mid.x, 0, mid.y, ry)
			for s in [-1.0, 1.0]:
				A.box(u1 - u0 + 1.2, 2.3, 0.6, 0, -0.95, s * 10.3, brick)
				A.box(u1 - u0 + 1.4, 0.14, 0.8, 0, 0.27, s * 10.3, cope)
			for e in [[u0, -1.0], [u1, 1.0]]:
				var ex: float = e[0] - (u0 + u1) / 2 + e[1] * 0.3
				A.box(0.6, 2.3, 20.0, ex, -0.95, 0, brick)
				A.box(0.8, 0.14, 21.4, ex, 0.27, 0, cope)
	A.commit()

## the three humpback bridges: brick ramps with side walls, a brick arch over the water (the old bridge was a solid wall
## straight across its own canal), stone parapets, lanterns on the four corners and bikes against the parapet
static func bridges() -> void:
	var NS := Trk.NS
	var HT := Trk.HT
	var SH := Trk.SHOULDER
	var brick := M(0x7a3a2c)
	var overWater := func(i: int) -> bool:
		for c in canals:
			var d := absi(i - c.i)
			if mini(d, NS - d) <= 5: return true
		return false
	var ramp := func(i): return Trk.HT[i] > 0.05 and not overWater.call(i)
	var top := func(i): return Trk.HT[i] > 0.35
	var stone := M(0xa8a196)
	for s in [-1, 1]:
		World.vribbon(s * SH, -4, 0.2, brick, 3, ramp)
		World.vribbon(s * (SH - 0.01), 0.2, 0.86, stone, 3, top)
		World.vribbon(s * (SH - 0.36), 0.2, 0.86, stone, 3, top)
		World.ribbon(s * (SH - 0.36), s * (SH - 0.01), stone, 3, 0.86, top)
	var A := BKit.Acc.new()
	var lampM := M(0xfff2c0, {"emissive": 0x3a3220})
	World.lampMats.append(lampM)
	var lh := []; var bikes := []; var bcol := []
	var bpal := [Color(0.12, 0.12, 0.14), Color(0.55, 0.1, 0.1), Color(0.1, 0.25, 0.5), Color(0.85, 0.85, 0.8), Color(0.15, 0.4, 0.25), Color(0.9, 0.6, 0.1)]
	for c in canals:
		var ib: int = c.i
		# the arch: the outline in (distance along the track, height) pulled across the bridge. The road lies 10 cm above it.
		var pts := []
		for k in range(-5, 6):
			pts.append(Vector2(k * Trk.SPC, HT[(ib + k + NS) % NS] - 0.1))
		var hw := 5 * Trk.SPC
		pts.append(Vector2(hw, -1.9)); pts.append(Vector2(8.6, -1.9))
		for k in 11:
			var a := PI * k / 10.0
			pts.append(Vector2(cos(a) * 8.6, -1.9 + sin(a) * (HT[ib] + 1.9 - 0.75)))
		pts.append(Vector2(-hw, -1.9))
		var arch := Geo.extrude(pts, SH * 2 + 0.5)
		arch.translate(0, 0, -(SH + 0.25))
		# extrude: x = along the track, z = across; the bridge frame: local x -> t, local z -> r
		var fr := Transform3D(Basis(Vector3(c.t.x, 0, c.t.z), Vector3.UP, Vector3(c.r.x, 0, c.r.z)), Vector3(c.p.x, 0, c.p.z))
		A.frame = fr
		A.add(arch, 0x74392c)
		for s in [-1.0, 1.0]:
			# a keystone band along the arch's face and the lantern posts on the four corners
			A.box(hw * 2, 0.3, 0.3, 0, HT[ib] - 0.32, s * (SH + 0.3), 0xa8a196)
			for e in [-1.0, 1.0]:
				var j := (ib + int(e * 7) + NS) % NS
				var q := Trk.onTrack(j, s * (SH - 0.18))
				A.frame = Transform3D(Basis(), Vector3(q[0], HT[j], q[1]))
				A.box(0.5, 1.2, 0.5, 0, 0.8, 0, 0x8f897e)
				A.cyl(0.05, 0.07, 2.2, 6, 0, 2.5, 0, 0x23382c)
				lh.append(World.mtx(q[0], HT[j] + 3.75, q[1]))
				World.trackLights.append([q[0] - s * Trk.R[j].x * 3.0, HT[j] + 0.1, q[1] - s * Trk.R[j].z * 3.0, 5])
				A.frame = fr
		# bikes against the parapet, on the pavement of the bridge
		for s in [-1.0, 1.0]:
			for k in range(-5, 6):
				var keep := rnd() < 0.55
				var lean := (rnd() - .5) * 0.3
				var col: Color = World.pick(bpal)
				if not keep: continue
				var j := (ib + k + NS) % NS
				var q := Trk.onTrack(j, s * (SH - 0.72))
				bikes.append(Transform3D(Basis(Vector3.UP, Trk.heading_of(Trk.T[j]) + lean) * Basis(Vector3.BACK, s * 0.18), Vector3(q[0], HT[j] + 0.2, q[1])))
				bcol.append(col)
	A.commit()
	World.inst(Geo.box(0.42, 0.5, 0.42), lampM, lh, null, false)
	World.inst(bikeGeo(), M(0xffffff), bikes, bcol, false)

## a parked bike: two wheels, a frame in the instance colour, saddle and handlebars (length along z)
static func bikeGeo() -> Geo:
	var wheel := Geo.cylinder(0.33, 0.33, 0.04, 10).rotate_z(PI / 2)
	return BKit.merge([
		[wheel.clone().translate(0, 0.33, -0.52), 0x1e1e20],
		[wheel.clone().translate(0, 0.33, 0.52), 0x1e1e20],
		[Geo.box(0.05, 0.05, 0.8).rotate_x(-0.5).translate(0, 0.58, 0.14), 0xffffff],
		[Geo.box(0.05, 0.05, 0.62).translate(0, 0.78, -0.02), 0xffffff],
		[Geo.box(0.05, 0.6, 0.05).rotate_x(0.25).translate(0, 0.62, -0.3), 0xffffff],
		[Geo.box(0.05, 0.62, 0.05).rotate_x(-0.3).translate(0, 0.66, 0.42), 0xffffff],
		[Geo.box(0.14, 0.06, 0.26).translate(0, 0.95, -0.34), 0x2a2420],
		[Geo.box(0.46, 0.04, 0.04).translate(0, 1.0, 0.32), 0x2a2a2c]])

## elms with a clear 5.4 m trunk and a high crown (the crown keeps above 4.8 m: clear of the cars and the camera),
## along the pavements of the track and along the quays of the canals
static func elmGeo() -> Geo:
	return BKit.merge([
		[Geo.cylinder(0.15, 0.22, 5.6, 6, 1, true).translate(0, 2.8, 0), 0x4a3828],
		[Geo.icosahedron(1.0, 0).scale(1.75, 1.9, 1.75).translate(0, 7.0, 0), 0x4a7434],
		[Geo.icosahedron(1.0, 0).scale(1.2, 1.1, 1.2).translate(0.5, 5.95, 0.3), 0x426a2e],
		[Geo.box(1.1, 0.06, 1.1).translate(0, 0.03, 0), 0x3a322a]])

static func trees() -> void:
	var NS := Trk.NS
	var tr := []; var tc := []
	var d := 6.0
	var k := 0
	while d < Trk.TRACK_LEN:
		var i := int(round(d / Trk.SPC)) % NS
		var s := 1 if k % 2 else -1
		var ry := rnd() * 6
		var sc := 0.92 + rnd() * 0.2
		var tint := 0.85 + rnd() * 0.3
		d += 12.5; k += 1
		if Trk.HT[i] > 0.1: continue
		var xz := Trk.onTrack(i, s * 5.78)
		if inCanal(xz[0], xz[1], 12.0): continue
		tr.append(World.mtx(xz[0], 0.2, xz[1], ry, 1.0, sc, 1.0)); tc.append(Color(tint, tint, tint * 0.92))
		World.pavTaken.append([xz[0], xz[1], 1.0])
	for c in canals:
		for bank in [-1.0, 1.0]:
			var u := -CANAL + 8.0
			while u < CANAL - 6:
				var ry := rnd() * 6
				var sc := 0.92 + rnd() * 0.25
				var tint := 0.85 + rnd() * 0.3
				var p := cpos(c, u, bank * 12.2)
				u += 13.0
				if Trk.distToTrack(p.x, p.y) < Trk.SHOULDER + 3.5 or not onWaterSide(c, u - 13.0): continue
				tr.append(World.mtx(p.x, 0.02 * c.k, p.y, ry, 1.0, sc, 1.0)); tc.append(Color(tint, tint, tint * 0.92))
	World.inst(elmGeo(), M(0xffffff), tr, tc, true)

## is u (along canal c) beside a stretch of water (not on a street that dams the canal)
static func onWaterSide(c: Dictionary, u: float) -> bool:
	for pt in c.parts:
		if u > pt[0] + 1.5 and u < pt[1] - 1.5: return true
	return false

## houseboats and sloops moored along the quays, and a tour boat that sails up and down each canal under its bridge
static func boats() -> void:
	var A := BKit.Acc.new()
	var hb := [0x2e5d3e, 0x7a2a2a, 0x1d4f9e, 0x3a3e45, 0x6b4a2e]
	var sl := []; var sc := []
	var spal := [Color(0.85, 0.85, 0.8), Color(0.15, 0.3, 0.5), Color(0.5, 0.15, 0.12), Color(0.2, 0.4, 0.25), Color(0.9, 0.75, 0.3)]
	for c in canals:
		var ry := atan2(c.r.x, c.r.z) - PI / 2
		for k in 9:
			var u := -235 + k * 58 + rnd() * 20
			var s := 1.0 if k % 2 else -1.0
			var col: int = World.pick(hb)
			if absf(u) < 22 or not onWaterSide(c, u - 8) or not onWaterSide(c, u + 8): continue
			var p := cpos(c, u, s * 7.6)
			A.at(p.x, WATER_Y, p.y, ry)
			A.box(14, 1.5, 3.6, 0, 0.45, 0, col); A.box(9, 2.0, 3.0, -1, 2.1, 0, 0xe8e4dc)
			A.box(9.4, 0.2, 3.4, -1, 3.2, 0, 0x3a3e45)
			A.box(1.2, 0.5, 0.5, 4.6, 1.5, 0.8, 0x7a4a2a); A.box(0.4, 0.5, 0.4, 5.6, 1.6, -0.7, 0x4f7a3a)
		for _k in 16:
			var u := (rnd() - .5) * 2 * (CANAL - 12)
			var s := 1.0 if rnd() < 0.5 else -1.0
			var col: Color = World.pick(spal)
			var turn := (rnd() - .5) * 0.12
			if absf(u) < 12 or not onWaterSide(c, u - 3) or not onWaterSide(c, u + 3): continue
			var p := cpos(c, u, s * 8.9)
			sl.append(Transform3D(Basis(Vector3.UP, ry + PI / 2 + turn), Vector3(p.x, WATER_Y, p.y))); sc.append(col)
		# the tour boat: a long low boat with a glass roof, on the middle of the widest stretch through the bridge
		for pt in c.parts:
			if pt[0] < -30 and pt[1] > 30:
				var g := Node3D.new()
				World.box(3.4, 1.0, 17, M(0xf2efe6), 0, 0.3, 0, g, false)
				World.box(3.0, 0.9, 12, M(0x2c3a48), 0, 1.15, -0.5, g, false)
				World.box(3.2, 0.12, 12.4, M(0x1d4f9e), 0, 1.66, -0.5, g, false)
				World.box(3.44, 0.25, 17.04, M(0xc8302a), 0, 0.2, 0, g, false)
				var a := cpos(c, maxf(pt[0] + 14, -150), -3.0)
				var b := cpos(c, minf(pt[1] - 14, 150), -3.0)
				World.add(AnimB.shuttle(g, Vector3(a.x, WATER_Y, a.y), Vector3(b.x, WATER_Y, b.y), 3.2, rnd()))
	A.commit()
	var sloop := BKit.merge([
		[Geo.box(1.7, 0.6, 4.6).translate(0, 0.2, 0), 0xffffff],
		[Geo.box(1.3, 0.5, 1.2).translate(0, 0.45, 2.6), 0xffffff],
		[Geo.box(1.4, 0.08, 3.6).translate(0, 0.42, -0.2), 0x7a5a3a],
		[Geo.box(1.5, 0.3, 0.4).translate(0, 0.6, -1.4), 0x7a5a3a]])
	World.inst(sloop, M(0xffffff), sl, sc, false)

## the Westertoren over the roofs: a brick tower with white galleries, a clock and the blue imperial crown
static func tower() -> void:
	var s = World.clearSpot(44, 120)
	if s == null or inCanal(s[0], s[1], 40.0, CANAL + 20): return
	var A := BKit.Acc.new()
	A.at(s[0], 0, s[1], 0.3)
	var brick := 0x8a4a34; var white := 0xe8e4d8; var lead := 0x4a5a66
	A.box(22, 14, 34, 0, 7, -22, brick)                    # the church
	A.roof(22.6, 7, 34.6, 0, 13.97, -22, 0x3a3a40)
	A.box(9, 44, 9, 0, 22, 0, brick)
	A.box(10, 1.2, 10, 0, 44.6, 0, white)
	A.box(7, 9, 7, 0, 49.7, 0, white)
	A.box(8, 0.8, 8, 0, 54.6, 0, white)
	A.box(5, 7, 5, 0, 58.5, 0, white)
	A.box(5.8, 0.6, 5.8, 0, 62.3, 0, white)
	A.cyl(1.6, 2.2, 5, 8, 0, 65.1, 0, lead)
	A.add(Geo.sphere(1.9, 10, 6), 0x2a55a8, BKit.xf(0, 69.0, 0))
	A.cyl(0.1, 0.1, 4, 5, 0, 72.5, 0, 0xd8b040)
	for f in 4:
		var ry := f * PI / 2
		A.add(Geo.cylinder(2.3, 2.3, 0.2, 14).rotate_x(PI / 2), 0xf4f1e8, BKit.xf(sin(ry) * 4.56, 38, cos(ry) * 4.56, ry))
		A.box(0.25, 1.9, 0.1, sin(ry) * 4.7, 38.6, cos(ry) * 4.7, 0x2a2622, ry)
	A.commit()
	World.pavTaken.append([s[0], s[1], 30.0])

## flags from the house fronts, bikes against the houses and fans on the pavements at the start and by the bridges
static func streetLife() -> void:
	var NS := Trk.NS
	var HT := Trk.HT
	var SH := Trk.SHOULDER
	var bikes := []; var bcol := []
	var bpal := [Color(0.12, 0.12, 0.14), Color(0.55, 0.1, 0.1), Color(0.1, 0.25, 0.5), Color(0.85, 0.85, 0.8), Color(0.15, 0.4, 0.25), Color(0.9, 0.6, 0.1)]
	var fl := []; var fp := []
	for _k in 170:
		var i := int(floor(rnd() * NS))
		var s := -1.0 if rnd() < 0.5 else 1.0
		var col: Color = World.pick(bpal)
		var lean := (rnd() - .5) * 0.3
		if HT[i] > 0.1: continue
		var xz := Trk.onTrack(i, s * (SH - 0.28))
		if inCanal(xz[0], xz[1], 10.0 + QUAY) or World.pavBusy(xz[0], xz[1], 1.0): continue
		World.pavTaken.append([xz[0], xz[1], 0.9])
		bikes.append(Transform3D(Basis(Vector3.UP, Trk.heading_of(Trk.T[i]) + lean) * Basis(Vector3.BACK, s * 0.16), Vector3(xz[0], 0.2, xz[1])))
		bcol.append(col)
	World.inst(bikeGeo(), M(0xffffff), bikes, bcol, false)
	# flags: red-black-red with three white crosses, on a pole slanting out from a front at 5 m
	for _k in 60:
		var i := int(floor(rnd() * NS))
		var s := -1.0 if rnd() < 0.5 else 1.0
		if HT[i] > 0.1: continue
		var xz := Trk.onTrack(i, s * (SH + 0.25))
		if inCanal(xz[0], xz[1], 10.0 + QUAY): continue
		# local +x points from the front to the street
		var ry := Trk.heading_of(Trk.T[i]) + (0.0 if s > 0 else PI)
		var m := Transform3D(Basis(Vector3.UP, ry), Vector3(xz[0], 5.2, xz[1]))
		fp.append(m)
		fl.append(m)
	var flagTex := Canvas2D.tex(64, 96, func(g, w, h):
		g.fillStyle = "#c81e1e"; g.fillRect(0, 0, w, h); g.fillStyle = "#16161a"; g.fillRect(w / 3.0, 0, w / 3.0, h)
		g.strokeStyle = "#f4f4f0"; g.lineWidth = 4
		for k in 3:
			var cy: float = 18 + k * 30
			g.beginPath(); g.moveTo(w / 2.0 - 7, cy - 7); g.lineTo(w / 2.0 + 7, cy + 7); g.stroke()
			g.beginPath(); g.moveTo(w / 2.0 + 7, cy - 7); g.lineTo(w / 2.0 - 7, cy + 7); g.stroke())
	World.inst(Geo.cylinder(0.03, 0.03, 2.4, 5).rotate_z(-PI / 2 + 0.6).translate(0.95, 0.65, 0), M(0xe8e4dc), fp, null, false)
	World.inst(Geo.plane(0.9, 1.5).rotate_y(PI / 2).translate(1.5, 0.45, 0), M(0xffffff, {"map": flagTex, "side": "double"}), fl, null, false)
	# fans behind the bollards: at the start and on both sides of every bridge
	var ppl := []
	for s in [-1.0, 1.0]:
		ppl.append_array(BKit.crowdRow(Trk.START_I + 4, 22, s * 6.2, 1.5, 1))
		for c in canals:
			ppl.append_array(BKit.crowdRow(c.i - 16, 8, s * 6.2, 1.4, 1))
			ppl.append_array(BKit.crowdRow(c.i + 10, 8, s * 6.2, 1.4, 1))
	var keep := []
	for p in ppl:
		if not World.pavBusy(p[0], p[2], 0.6): keep.append(p)
	BKit.crowd(keep)
	for p in keep: World.pavTaken.append([p[0], p[2], 0.7])

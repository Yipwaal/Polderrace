class_name BuildDorp
## Port of buildDorp from polderrace-3d.html: brick village street with a canal under a humpback bridge, lamp posts,
## bikes, cafe terraces, rows of houses and a church. Same numbers, same seeded random order (World.rnd).

static func M(c: int, o: Dictionary = {}) -> LMat:
	return Mats.M(c, o)

static func rnd() -> float:
	return World.rnd.next()

## JS hitsHouse: does a house at (x,z) with yaw, width w (along the road) and depth dep overlap a placed one?
## (separating axis test on the two rectangles, only against houses closer than 20 m)
static func hitsHouse(placedH: Array, x: float, z: float, yaw: float, w: float, dep: float) -> bool:
	var f := [sin(yaw), cos(yaw)]
	var r := [f[1], -f[0]]
	for o in placedH:
		var dx: float = o.x - x
		var dz: float = o.z - z
		if dx * dx + dz * dz > 400: continue
		var of := [sin(o.yaw), cos(o.yaw)]
		var orr := [of[1], -of[0]]
		var sep := func(ax: float, az: float) -> bool:
			var pa: float = absf(w / 2 * (f[0] * ax + f[1] * az)) + absf(dep / 2 * (r[0] * ax + r[1] * az))
			var pb: float = absf(o.w / 2 * (of[0] * ax + of[1] * az)) + absf(o.dep / 2 * (orr[0] * ax + orr[1] * az))
			return absf(dx * ax + dz * az) >= pa + pb + 0.05
		if not (sep.call(f[0], f[1]) or sep.call(r[0], r[1]) or sep.call(of[0], of[1]) or sep.call(orr[0], orr[1])):
			return true
	return false

static func build() -> void:
	var NS := Trk.NS
	var SPC := Trk.SPC
	var T := Trk.T
	var HT := Trk.HT
	var P := Trk.P
	var TRACK_LEN := Trk.TRACK_LEN
	var RH := Trk.ROAD_HALF
	var SH := Trk.SHOULDER
	World.groundPlane(Canvas2D.tex(256, 256, func(g, w, h):
		g.fillStyle = "#6f9a48"; g.fillRect(0, 0, w, h)
		for _i in 500:
			g.fillStyle = "rgba(255,255,255,.05)" if randf() < .5 else "rgba(0,0,0,.06)"
			g.fillRect(randf() * w, randf() * h, 4, 4)
		g.fillStyle = "#4f7535"; g.fillRect(0, 0, w, 6); g.fillRect(0, 0, 6, h), true), 60)
	var tile := Canvas2D.tex(128, 128, func(g, w, h):
		g.fillStyle = "#b9b4aa"; g.fillRect(0, 0, w, h); g.strokeStyle = "rgba(60,55,50,.35)"; g.lineWidth = 2
		var i := 0
		while i <= w:
			g.beginPath(); g.moveTo(i, 0); g.lineTo(i, h); g.stroke(); g.beginPath(); g.moveTo(0, i); g.lineTo(w, i); g.stroke()
			i += 32, true)
	var rt := World.roadTexture("#8a5d4c", [], false, true)
	World.ribbon(-RH, RH, World.roadMat(rt, {"repeat": Vector2(4, 1)}), 6, 0.07)
	var sw := M(0xffffff, {"map": tile})
	World.ribbon(-SH, -RH, sw, 2.5, 0.2); World.ribbon(RH, SH, sw, 2.5, 0.2)
	var curb := M(0x9d9990); World.vribbon(-RH, 0.07, 0.2, curb, 1); World.vribbon(RH, 0.07, 0.2, curb, 1)
	World.startLine(); World.gates(Trk.TRK)
	var ib := 0
	for i in NS:
		if HT[i] > HT[ib]: ib = i
	var cT := T[ib]
	var cP := P[ib]
	var cR := Trk.R[ib]
	var inCanal := func(x: float, z: float) -> bool:
		return absf((x - cP.x) * cT.x + (z - cP.z) * cT.z) < 14 and absf((x - cP.x) * cR.x + (z - cP.z) * cR.z) < 230
	# the canal under the humpback bridge (the highest point of the track), with quay walls and moored boats
	var cg := O3.group(cP.x, 0, cP.z)
	O3.rot(cg, 0, Trk.heading_of(cT), 0)
	var wm := O3.mesh(Geo.plane(460, 22), Mats.phong(0x3f5f6e, {"specular": 0x8fa6bb, "shininess": 80}), 0, 0.04, 0, cg)
	O3.rot(wm, -PI / 2, 0, 0)
	var quay := M(0x8c3f2c)
	for s in [-1, 1]:
		World.box(460, 0.45, 0.8, quay, 0, 0.2, s * 11.4, cg, false)
	var boat := M(0x2e5d3e); var boat2 := M(0x7a2a2a)
	for xc in [[-60, boat], [70, boat2], [140, boat]]:
		World.box(9, 1, 2.4, xc[1], xc[0], 0.5, -7.5, cg); World.box(3, 1.2, 2, M(0xf3efe4), xc[0] - 1.5, 1.4, -7.5, cg)
	World.add(cg)
	var brick := M(0x8c3f2c)
	var hump := func(i): return Trk.HT[i] > 0.05
	var top := func(i): return Trk.HT[i] > 0.35
	for s in [-1, 1]:
		World.vribbon(s * SH, -4, 0.2, brick, 3, hump); World.vribbon(s * (SH - 0.01), 0.2, 1.15, brick, 3, top)

	var bol := []; var lampP := []; var lampH := []
	var d := 0.0
	while d < TRACK_LEN:
		var i := int(round(d / SPC)) % NS
		for lat in [-5.95, 5.95]:
			var xz := Trk.onTrack(i, lat)
			bol.append(World.mtx(xz[0], HT[i] + 0.2 + 0.47, xz[1]))
		d += 2.4
	var side := 1
	d = 10.0
	while d < TRACK_LEN:
		var i := int(round(d / SPC)) % NS
		side = -side
		var xz := Trk.onTrack(i, side * 7.6)
		lampP.append(World.mtx(xz[0], HT[i] + 2.95, xz[1])); World.pavTaken.append([xz[0], xz[1], 0.2])
		var hxz := Trk.onTrack(i, side * 6.9)
		lampH.append(World.mtx(hxz[0], HT[i] + 5.6, hxz[1], Trk.heading_of(T[i])))
		d += 32
	World.inst(Geo.cylinder(0.09, 0.11, 0.95, 8), M(0x5a1f1a), bol, null, false)
	World.inst(Geo.cylinder(0.07, 0.1, 5.5, 6), M(0x23382c), lampP, null, true)
	var lm := M(0x23382c, {"emissive": 0x2a2a1a}); World.lampMats.append(lm)
	World.inst(Geo.box(1.1, 0.22, 0.45), lm, lampH, null, false)
	for m in lampH:
		World.trackLights.append([m.origin.x, 0, m.origin.z, 9])

	var facade := Canvas2D.tex(128, 128, func(g, w, h):
		g.fillStyle = "#ffffff"; g.fillRect(0, 0, w, h)
		g.fillStyle = "rgba(0,0,0,.07)"
		var y := 0
		while y < h:
			g.fillRect(0, y, w, 1); y += 6
		for xy in [[18, 18], [74, 18], [18, 64], [74, 64]]:
			var x: int = xy[0]; var yy: int = xy[1]
			g.fillStyle = "#f4f1ea"; g.fillRect(x - 3, yy - 3, 42, 36); g.fillStyle = "#34414f"; g.fillRect(x, yy, 36, 30)
			g.fillStyle = "#f4f1ea"; g.fillRect(x + 17, yy, 2, 30); g.fillRect(x, yy + 13, 36, 2)
		g.fillStyle = "#f4f1ea"; g.fillRect(50, 98, 28, 30); g.fillStyle = "#2e4a3a"; g.fillRect(53, 101, 22, 27))
	var walls := ["#8c3f2c", "#7a3526", "#9b4a33", "#e8e2d4", "#6e2f25", "#a0553a", "#d9d2c0", "#5e4a3d"].map(func(c): return Color(c))
	var roofs := ["#3b3530", "#5a2a22", "#2f3033", "#4b3a33", "#6b3024"].map(func(c): return Color(c))
	var hB := []; var hBC := []; var hR := []; var hRC := []; var trees := []; var treeC := []
	var tree := func(x: float, z: float) -> void:
		var s := 0.8 + rnd() * 0.5
		trees.append(World.mtx(x, 5 * s, z, rnd() * 6, 3.4 * s, 3.2 * s, 3.4 * s))
		treeC.append(MathX.hsl(0.25 + rnd() * 0.05, 0.35, 0.3 + rnd() * 0.1))
	var placedH := []
	for sd in [-1, 1]:
		var s := 0.0
		while s < TRACK_LEN:
			var w := 6 + rnd() * 3.5
			var dep := 9 + rnd() * 3
			var i := int(round((s + w / 2) / SPC)) % NS
			var lat: float = sd * (SH + 0.4 + dep / 2 + rnd() * 0.3)
			var xz := Trk.onTrack(i, lat)
			var x: float = xz[0]; var z: float = xz[1]
			if Trk.distToTrack(x, z) < absf(lat) - 0.8 or inCanal.call(x, z):
				s += w; continue
			if rnd() < 0.12:
				var txz := Trk.onTrack(i, sd * (SH + 3))
				tree.call(txz[0], txz[1]); s += w; continue
			var hh := 5.5 + rnd() * 4.5
			var rh := 3 + rnd() * 2.5
			var ry := Trk.heading_of(T[i])
			var ok := false
			for k in [1, 0.85, 0.7, 0.55]:
				if not hitsHouse(placedH, x, z, ry, w * 0.97 * k, dep):
					w *= k; ok = true; break
			if not ok:
				s += 3; continue
			placedH.append({"x": x, "z": z, "yaw": ry, "w": w * 0.97, "dep": dep})
			hB.append(World.mtx(x, hh / 2, z, ry, dep, hh, w * 0.97)); hBC.append(World.pick(walls))
			hR.append(World.mtx(x, hh, z, ry + PI / 2, w * 0.97, rh, dep * 1.02)); hRC.append(World.pick(roofs))
			s += w
	for _k in 160:
		var p = Trk.randPos(World.rnd, 24)
		if p != null and not inCanal.call(p[0], p[1]): tree.call(p[0], p[1])

	var fr := []; var wh := []; var tb := []; var um := []; var uc := []; var ch := []
	var ucol := [0xc8302a, 0x1d4f9e, 0xf2c200, 0x2e5d3e].map(func(c): return MathX.col(c))
	# bikes stand side by side, square to the kerb (0.7 m apart); not in front of a cafe terrace (the rnd() calls stay)
	var terS := []
	for t in 3:
		terS.append([(int(round(NS * (0.15 + t * 0.3))) % NS) * SPC, 1 if t % 2 else -1])
	var posts := []
	var side2 := 1
	d = 10.0
	while d < TRACK_LEN:
		side2 = -side2
		posts.append(Trk.onTrack(int(round(d / SPC)) % NS, side2 * 7.6))   # the lamp posts placed above
		d += 32
	d = 20.0
	while d < TRACK_LEN:
		var i := int(round(d / SPC)) % NS
		if HT[i] > 0.05:
			d += 23; continue
		var sd := 1 if int(d / 23) % 2 else -1
		var xz := Trk.onTrack(i, sd * 7.6)
		var x: float = xz[0]; var z: float = xz[1]
		if inCanal.call(x, z):
			d += 23; continue
		var h := Trk.heading_of(T[i])
		var busy := false
		for ts in terS:
			if ts[1] == sd and absf(fmod(fmod(d - ts[0], TRACK_LEN) + TRACK_LEN * 1.5, TRACK_LEN) - TRACK_LEN / 2) < 9:
				busy = true
		# JS: for(let b=0;b<2+Math.floor(rnd()*3);b++): the bound draws a new rnd() at every test
		var b := 0
		while b < 2 + int(floor(rnd() * 3)):
			if not busy:
				var o := b * 0.7 - 0.7
				var px: float = x + T[i].x * o
				var pz: float = z + T[i].z * o
				var yaw := h
				# no bike through a lamp post (they stand on the same 7.6 m line): measured in the bike's own frame
				var hit := false
				for lp in posts:
					var dx: float = lp[0] - px
					var dz: float = lp[1] - pz
					if absf(dx * cos(yaw) - dz * sin(yaw)) < 1 and absf(dx * sin(yaw) + dz * cos(yaw)) < 0.3:
						hit = true; break
				if not hit:
					fr.append(World.mtx(px, 0.9, pz, yaw, 1.1, 0.08, 0.08)); World.pavTaken.append([px, pz, 0.55])
					for ww in [-0.5, 0.5]:
						wh.append(World.mtx(px + cos(yaw) * ww, 0.56, pz - sin(yaw) * ww, yaw))
			b += 1
		d += 23
	for t in 3:
		var i := int(round(NS * (0.15 + t * 0.3))) % NS
		if HT[i] > 0.05: continue
		var sd := 1 if t % 2 else -1
		# tables 3 m apart measured along the pavement line itself
		var at := func(o: float) -> Array:
			var st := signf(o)
			var j := i
			var a0 := Trk.onTrack(i, sd * 7.2)
			var ax: float = a0[0]; var az: float = a0[1]
			var left := absf(o)
			for _n in 40:
				j = (j + int(st) + NS) % NS
				var b0 := Trk.onTrack(j, sd * 7.2)
				var bx: float = b0[0]; var bz: float = b0[1]
				var L := sqrt((bx - ax) * (bx - ax) + (bz - az) * (bz - az))
				if L >= left:
					var f := left / L
					return [ax + (bx - ax) * f, az + (bz - az) * f, (bx - ax) / L * st, (bz - az) / L * st]
				left -= L; ax = bx; az = bz
			return [ax, az, Trk.T[i].x, Trk.T[i].z]
		for k in 4:
			var q: Array = at.call(k * 3 - 4.5)
			var px: float = q[0]; var pz: float = q[1]; var tx: float = q[2]; var tz: float = q[3]
			tb.append(World.mtx(px, 0.95, pz, 0, 1)); World.pavTaken.append([px, pz, 1.3]); um.append(World.mtx(px, 2.35, pz, 0, 1)); uc.append(ucol[t])
			for c in [-0.7, 0.7]:
				ch.append(World.mtx(px + tx * c, 0.45, pz + tz * c, 0, 1))
	World.inst(Geo.box(1, 1, 1), M(0x2b2f36), fr, null, false); World.inst(Geo.torus(0.33, 0.04, 5, 12), M(0x1b1b1b), wh, null, false)
	World.inst(Geo.cylinder(0.55, 0.55, 0.06, 10), M(0xe8e4dc), tb, null, true); World.inst(Geo.cone(1.4, 0.7, 8), M(0xffffff), um, uc, true)
	World.inst(Geo.box(0.45, 0.9, 0.45), M(0x3a3e45), ch, null, false)
	var mask := Canvas2D.tex(128, 128, func(g, w, h):
		g.fillStyle = "#000"; g.fillRect(0, 0, w, h)
		for e in [[18, 18, 1], [74, 18, 0.55], [18, 64, 0.8], [74, 64, 1]]:
			g.fillStyle = "rgba(255,210,130,%s)" % str(e[2]); g.fillRect(e[0], e[1], 36, 30))
	var fm := M(0xffffff, {"map": facade, "emissive": 0x000000, "emissiveMap": mask}); World.winMats.append(fm)
	World.inst(Geo.box(1, 1, 1), fm, hB, hBC, true)
	World.inst(TrackCommon.roofGeo(), M(0xffffff), hR, hRC, true)
	World.inst(Geo.sphere(1, 10, 8), M(0xffffff), trees, treeC, true)
	var trunks := trees.map(func(m): return World.mtx(m.origin.x, 1.5, m.origin.z, 0, 1))
	World.inst(Geo.cylinder(0.25, 0.35, 3, 6), M(0x4a3a2a), trunks, null, false)

	# the church: in the open spot furthest from the road near the middle
	var best = null
	var bd := 0.0
	for _k in 300:
		var x := (Trk.BX0 + Trk.BX1) / 2 + (rnd() - .5) * 300
		var z := (Trk.BZ0 + Trk.BZ1) / 2 + (rnd() - .5) * 300
		var dd := Trk.distToTrack(x, z)
		if dd > bd:
			bd = dd; best = [x, z]
	if best != null and bd > 30:
		var g := O3.group(best[0], 0, best[1])
		O3.rot(g, 0, rnd() * 6, 0)
		var cb := M(0x7a3a2a)
		World.box(12, 11, 28, cb, 0, 5.5, 0, g)
		var r := TrackCommon.roofMesh(13, 8, 29, M(0x2f3033)); r.position.y = 11; g.add_child(r)
		World.box(7, 26, 7, cb, 0, 13, 17, g)
		var sp := O3.mesh(Geo.cone(4.6, 16, 4), M(0x2c3a34), 0, 34, 17, g, true)
		O3.rot(sp, 0, PI / 4, 0)
		O3.mesh(Geo.circle(1.5, 20), M(0xf3efe4), 0, 21, 20.55, g)
		World.add(g)

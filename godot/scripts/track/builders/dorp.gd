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

## a house front as [texture, night mask]: `floors` storeys of `cols` windows with white frames, a door, optionally a
## shop front with an awning. The left 5 % is bare wall: the side walls and the top of a house sample only that strip.
static func facadeTex(wall: String, trim: String, door: String, floors: int, cols: int, shop: bool, awning := "#c8302a") -> Array:
	var W := 256.0
	var top := 16.0
	var fh := (W - top) / floors
	var wins := []
	var cw := (W - 34) / cols
	for f in floors:
		var y0 := top + f * fh
		var ground := f == floors - 1
		if ground and shop:
			wins.append([36.0, y0 + fh * 0.3, cw * (cols - 1) - 14, fh * 0.52])
		else:
			for c in cols:
				if ground and c == cols - 1: continue
				wins.append([26 + c * cw + cw * 0.22, y0 + fh * 0.22, cw * 0.56, fh * 0.52])
	var dx := 26 + (cols - 1) * cw + cw * 0.24
	var dy := top + (floors - 1) * fh + fh * 0.22
	var tex := Canvas2D.tex(256, 256, func(g, w, h):
		g.fillStyle = wall; g.fillRect(0, 0, w, h)
		g.fillStyle = "rgba(0,0,0,.08)"
		var y := 0
		while y < h:
			g.fillRect(0, y, w, 1); y += 6
		for _i in 240:
			g.fillStyle = "rgba(255,255,255,.05)" if randf() < 0.5 else "rgba(0,0,0,.06)"
			g.fillRect(14 + randf() * (w - 14), randf() * h, 10, 5)
		g.fillStyle = trim; g.fillRect(13, 0, w - 13, 9)                # cornice
		g.fillStyle = "rgba(0,0,0,.25)"; g.fillRect(13, 9, w - 13, 3)
		g.fillStyle = "rgba(0,0,0,.3)"; g.fillRect(13, h - 10, w - 13, 10)   # plinth
		for q in wins:
			g.fillStyle = trim; g.fillRect(q[0] - 5, q[1] - 5, q[2] + 10, q[3] + 12)
			g.fillStyle = "#2c3946"; g.fillRect(q[0], q[1], q[2], q[3])
			g.fillStyle = "rgba(150,190,220,.28)"; g.fillRect(q[0], q[1], q[2], q[3] * 0.45)
			g.fillStyle = trim
			if q[2] < 100:
				g.fillRect(q[0] + q[2] / 2 - 1.5, q[1], 3, q[3]); g.fillRect(q[0], q[1] + q[3] * 0.4, q[2], 3)
			else:
				var x: float = q[0] + q[2] / 3
				while x < q[0] + q[2] - 4:
					g.fillRect(x - 1.5, q[1], 3, q[3]); x += q[2] / 3
		g.fillStyle = trim; g.fillRect(dx - 5, dy - 5, cw * 0.52 + 10, fh * 0.78 + 5 - 10)
		g.fillStyle = door; g.fillRect(dx, dy, cw * 0.52, fh * 0.78 - 10)
		g.fillStyle = "rgba(255,255,255,.14)"; g.fillRect(dx + 4, dy + 5, cw * 0.52 - 8, fh * 0.2)
		if shop:
			var ay := top + (floors - 1) * fh + fh * 0.1
			var x := 26.0
			var k := 0
			while x < 26 + cw * (cols - 1):
				g.fillStyle = awning if k % 2 == 0 else "#f4f1ea"
				g.fillRect(x, ay, minf(14, 26 + cw * (cols - 1) - x), fh * 0.16); x += 14; k += 1)
	var mask := Canvas2D.tex(64, 64, func(g, w, h):
		g.fillStyle = "#000"; g.fillRect(0, 0, w, h)
		for k in wins.size():
			var q: Array = wins[k]
			var lit: float = [1.0, 0.0, 0.75, 0.9, 0.0, 0.6, 1.0, 0.45][(k * 3 + floors + cols) % 8]
			if shop and k == wins.size() - 1: lit = 0.85
			if lit <= 0.0: continue
			g.fillStyle = "rgba(255,210,130,%s)" % str(lit); g.fillRect(q[0] / 4, q[1] / 4, q[2] / 4, q[3] / 4))
	return [tex, mask]

## a market stall on the square: a table of crates under a striped awning on four posts
static func stall(x: float, z: float, yaw: float, col: Color, awn: Array, awnC: Array, posts: Array, tabs: Array, goods: Array, goodC: Array) -> void:
	var base := Transform3D(Basis(Vector3.UP, yaw), Vector3(x, 0.2, z))
	awn.append(base * Transform3D(O3.euler(0.16, 0, 0).scaled_local(Vector3(3.6, 0.1, 2.9)), Vector3(0, 2.55, 0))); awnC.append(col)
	for px in [-1.6, 1.6]:
		for pz in [-1.2, 1.2]:
			var ph: float = 2.55 + pz * 0.16
			posts.append(base * Transform3D(Basis().scaled(Vector3(1, ph, 1)), Vector3(px, ph / 2, pz)))
	tabs.append(base * Transform3D(Basis().scaled(Vector3(3.0, 0.9, 1.3)), Vector3(0, 0.45, 0)))
	var pal := [0xd62a2a, 0xf5c518, 0xf07a1a, 0x3f8f3a, 0xe85a9a, 0xecece8, 0x8e44ad]
	for k in 8:
		var gh := 0.22 + rnd() * 0.2
		goods.append(base * Transform3D(Basis().scaled(Vector3(0.6, gh, 0.48)), Vector3(-1.2 + (k % 4) * 0.8, 0.9 + gh / 2, -0.3 + (k / 4) * 0.6)))
		goodC.append(MathX.col(World.pick(pal)))

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
	var wm := O3.mesh(Geo.plane(460, 22), Mats.phong(0x3f5f6e, {"specular": 0x8fa6bb, "shininess": 80, "receiveShadow": true}), 0, 0.04, 0, cg)
	O3.rot(wm, -PI / 2, 0, 0)
	var quay := M(0x8c3f2c)
	for s in [-1, 1]:
		World.box(460, 0.45, 0.8, quay, 0, 0.2, s * 11.4, cg, false)
	var boat := M(0x2e5d3e); var boat2 := M(0x7a2a2a)
	for xc in [[-60, boat], [70, boat2], [140, boat]]:
		World.box(9, 1, 2.4, xc[1], xc[0], 0.5, -7.5, cg); World.box(3, 1.2, 2, M(0xf3efe4), xc[0] - 1.5, 1.4, -7.5, cg)
	World.add(cg)
	var brick := M(0x8c3f2c)
	var hump := func(i): return Trk.HT[i] > 0.21   # (planters stand on the pavement up to 0.2 m: none in the wall)
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
	World.inst(Geo.box(1.5, 0.22, 0.45), lm, lampH, null, false)   # long enough to reach its post in a bend too
	for m in lampH:
		World.trackLights.append([m.origin.x, 0, m.origin.z, 9])

	# house fronts: six kinds with their own wall colour, trim and windows (the colour of a copy only tints it a little)
	var fronts := [
		facadeTex("#9a4a34", "#f4f1ea", "#2e4a3a", 2, 3, false),
		facadeTex("#7c3a2a", "#efe9da", "#5a1f1a", 2, 2, false),
		facadeTex("#e2dccb", "#f7f5ee", "#1d3f6e", 2, 3, false),
		facadeTex("#8c4a36", "#f4f1ea", "#2b2f36", 2, 3, true, "#c8302a"),
		facadeTex("#6e3d2e", "#efe9da", "#2e4a3a", 3, 2, false),
		facadeTex("#d6cfbd", "#f7f5ee", "#7a2a2a", 3, 3, true, "#1d4f9e")]
	var tints := [1.0, 0.93, 0.87, 0.97, 0.9].map(func(k): return Color(k, k, k))
	var roofs := ["#3b3530", "#5a2a22", "#2f3033", "#4b3a33", "#6b3024"].map(func(c): return Color(c))
	# the market square with the church: left of the start straight, 34 to 104 m after sample 0
	# (the same place in both driving directions: reversed, the samples count from the other end and left is right)
	var rev := Trk.TRACK_DIR == "rev"
	var SQ0 := NS - 52 if rev else 17
	var SQ1 := NS - 17 if rev else 52
	var sqS := 1.0 if rev else -1.0     # the side of the road the square is on
	var sq := Trk.P[(SQ0 + SQ1) / 2]
	var sqT := T[(SQ0 + SQ1) / 2]
	var sqR := Trk.R[(SQ0 + SQ1) / 2]
	var inSquare := func(x: float, z: float) -> bool:
		var al: float = (x - sq.x) * sqT.x + (z - sq.z) * sqT.z
		var la: float = (x - sq.x) * sqR.x + (z - sq.z) * sqR.z
		return absf(al) < 40 and la * sqS > 6 and la * sqS < 58
	var hB := []; var hBC := []; var hR := []; var hRC := []; var trees := []; var treeC := []
	for _k in fronts.size():
		hB.append([]); hBC.append([])
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
			if Trk.distToTrack(x, z) < absf(lat) - 0.8 or inCanal.call(x, z) or inSquare.call(x, z):
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
			# tall houses get three storeys, some of the others a shop
			var wi := int(floor(rnd() * 8))
			var kind: int = (4 + wi % 2) if hh > 8.0 else [0, 1, 2, 3, 0, 1, 3, 2][wi]
			hB[kind].append(World.mtx(x, hh / 2, z, ry + (0.0 if sd > 0 else PI), dep, hh, w * 0.97)); hBC[kind].append(tints[(wi * 3 + kind) % 5])
			hR.append(World.mtx(x, hh, z, ry + PI / 2, w * 0.97, rh, dep * 1.02)); hRC.append(World.pick(roofs))
			s += w
	for _k in 160:
		var p = Trk.randPos(World.rnd, 24)
		if p != null and not inCanal.call(p[0], p[1]) and not inSquare.call(p[0], p[1]): tree.call(p[0], p[1])
	# a row of trees closes the back of the market square
	for k in 9:
		var txz := Trk.onTrack(SQ0 + k * 4 + 1, sqS * 56.5)
		tree.call(txz[0], txz[1])

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
	# one pole per table: the table's leg and the parasol's stick (both floated)
	World.inst(Geo.cylinder(0.04, 0.04, 2.6, 6), M(0xd2d5d7), tb.map(func(m): return World.mtx(m.origin.x, 1.5, m.origin.z)), null, false)
	# a house is a box whose street and garden walls show the whole front; side walls and top only its bare-wall strip
	var hgeo := Geo.box(1, 1, 1)
	for k in range(8, 24): hgeo.uv[k] = Vector2(hgeo.uv[k].x * 0.04, hgeo.uv[k].y)
	for k in fronts.size():
		var fm := M(0xffffff, {"map": fronts[k][0], "emissive": 0x000000, "emissiveMap": fronts[k][1]}); World.winMats.append(fm)
		World.inst(hgeo, fm, hB[k], hBC[k], true)
	World.inst(TrackCommon.roofGeo(), M(0xffffff), hR, hRC, true)
	World.inst(Geo.sphere(1, 10, 8), M(0xffffff), trees, treeC, true)
	var trunks := trees.map(func(m): return World.mtx(m.origin.x, 1.5, m.origin.z, 0, 1))
	World.inst(Geo.cylinder(0.25, 0.35, 3, 6), M(0x4a3a2a), trunks, null, false)

	# ---- the market square (Godot only): paved from the pavement back to the church, stalls, people
	var sqMat := M(0xffffff, {"map": tile, "repeat": Vector2(17, 1)})
	if rev: World.ribbon(SH, 52, sqMat, 2.5, 0.2, func(i): return i >= SQ0 and i < SQ1)
	else: World.ribbon(-52, -SH, sqMat, 2.5, 0.2, func(i): return i >= SQ0 and i < SQ1)
	var cxz := Trk.onTrack((SQ0 + SQ1) / 2, sqS * 33)
	var g := O3.group(cxz[0], 0.2, cxz[1])
	O3.rot(g, 0, atan2(-sqS * sqR.x, -sqS * sqR.z), 0)   # the tower towards the road
	var cb := M(0x7a3a2a); var cream := M(0xf3efe4); var slate := M(0x2f3033)
	World.winMats.append(cream)
	World.box(12, 11, 28, cb, 0, 5.5, -3, g)
	var r := TrackCommon.roofMesh(13, 8, 29, slate); r.position = Vector3(0, 11, -3); g.add_child(r)
	World.box(7, 26, 7, cb, 0, 13, 14, g)
	var sp := O3.mesh(Geo.cone(4.6, 16, 4), M(0x2c3a34), 0, 34, 14, g, true)
	O3.rot(sp, 0, PI / 4, 0)
	O3.mesh(Geo.circle(1.5, 20), cream, 0, 21, 17.55, g)
	World.box(2.2, 3.6, 0.2, M(0x3a2a1c), 0, 1.8, 17.55, g, false)
	World.box(1.4, 4.0, 0.2, cream, 0, 12, 17.55, g, false)
	for k in 4:
		for sdx in [-1.0, 1.0]:
			World.box(0.2, 5, 1.8, cream, sdx * 6.02, 6, -13 + k * 6.2, g, false)
	World.add(g)
	var awn := []; var awnC := []; var sposts := []; var tabs := []; var goods := []; var goodC := []; var folk := []
	var awnCols := [0xc8302a, 0x1d4f9e, 0xf2c200, 0x2e7d4f].map(func(c): return MathX.col(c))
	var yawS := Trk.heading_of(sqT) + PI / 2    # stalls and people square to the road
	var k2 := 0
	for al in [-27.0, -19.0, 19.0, 27.0]:
		for la0 in [13.5, 21.5]:
			var la: float = sqS * la0
			var i := (SQ0 + SQ1) / 2 + int(round(al / SPC))
			var xz := Trk.onTrack(i, la)
			stall(xz[0], xz[1], yawS + (PI if rev else 0.0), awnCols[k2 % 4], awn, awnC, sposts, tabs, goods, goodC)
			# the stallholder behind the table, a customer or two in front (the side of the road)
			var b1 := Trk.onTrack(i, la + sqS * 1.5)
			folk.append([b1[0], 0.2, b1[1], yawS])
			var nc := 1 + int(floor(rnd() * 3))
			for c in nc:
				var c1 := Trk.onTrack(i, la - sqS * (1.7 + rnd() * 0.9))
				var off := (c - (nc - 1) / 2.0) * 0.95 + (rnd() - 0.5) * 0.3
				folk.append([c1[0] + sqT.x * off, 0.2, c1[1] + sqT.z * off, yawS + (rnd() - 0.5)])
			k2 += 1
	# spectators at the edge of the square, looking at the road
	for k in 2 * (SQ1 - SQ0 - 2):
		if rnd() < 0.42: continue
		var la := sqS * (SH + 0.45 + (k % 2) * 0.85 + rnd() * 0.25)
		var xz := Trk.onTrack(SQ0 + 1 + k / 2, la)
		var off := (k % 2) * 0.9 + (rnd() - 0.5) * 0.5
		folk.append([xz[0] + sqT.x * off, 0.2, xz[1] + sqT.z * off, yawS + (rnd() - 0.5) * 0.7])
	var stripes := Canvas2D.tex(64, 16, func(gc, w, h):
		for x in 8:
			gc.fillStyle = "#ffffff" if x % 2 == 0 else "#b9b9b4"
			gc.fillRect(x * 8, 0, 8, h))
	World.inst(Geo.box(1, 1, 1), M(0xffffff, {"map": stripes}), awn, awnC, true)
	World.inst(Geo.cylinder(0.04, 0.04, 1, 5), M(0xd2d5d7), sposts, null, false)
	World.inst(Geo.box(1, 1, 1), M(0x7a5a3a), tabs, null, true)
	World.inst(Geo.box(1, 1, 1), M(0xffffff), goods, goodC, false)
	TrackCommon.people(folk)

class_name BuildLimburg
## The hills of South Limburg (terrain, see terrain.gd). Started as a port of buildLimburg from polderrace-3d.html;
## fase 2 filled the bare hills: a patchwork of pasture, wheat, rapeseed and ploughed land, woods on the hilltops,
## orchards in blossom, rows of poplars, vineyards, a marl quarry cut into a hillside, a castle on a hill, a village of
## marl-stone and half-timbered houses round the church, cows, wayside crosses, a guard rail with reflector posts,
## arrow boards in the bends and fans with painted road on the steepest climb. Everything random: seeded World.rnd.

static func M(c: int, o: Dictionary = {}) -> LMat:
	return Mats.M(c, o)

static func rnd() -> float:
	return World.rnd.next()

## the marl quarry: [x, z, floor height, radius], set by build() before the terrain is made
static var quarry: Array = []

static func hills0(x: float, z: float) -> float:
	return 20 + 18 * sin(x / 260 + 0.4) * cos(z / 300 - 0.8) + 9 * sin((x + z) / 150) + 4 * cos((x * 0.8 - z) / 70)

## how far (x, z) lies outside the quarry (< 0: inside): a round pit with a cutting 0.7 R wide towards the road,
## so the quarry lies open to the road and its back wall can be seen from it
static func quarrySdf(x: float, z: float) -> float:
	var dx: float = x - quarry[0]
	var dz: float = z - quarry[1]
	var R: float = quarry[3]
	var sd := sqrt(dx * dx + dz * dz) - R
	var u: float = dx * quarry[6] + dz * quarry[7]
	if u > 0.0: sd = minf(sd, maxf(absf(dx * quarry[7] - dz * quarry[6]) - R * 0.7, u - 92.0))
	return sd

## the hills with the quarry cut out: a flat floor and a steep wall where the hill is higher than the floor
static func hills(x: float, z: float) -> float:
	var h := hills0(x, z)
	if quarry.is_empty(): return h
	var sd := quarrySdf(x, z)
	if sd >= 14.0: return h
	var k := clampf(sd / 14.0, 0, 1)
	var fl: float = quarry[2]
	return lerpf(fl, maxf(h, fl), k * k * (3 - 2 * k))

## woods grow on the hilltops
static func woodL(x: float, z: float) -> float:
	return (hills0(x, z) - 33) / 9.0 + 0.45 * sin(x / 90 + 1.0) * cos(z / 75)

static func hash2(a: float, b: float) -> float:
	var v := sin(a * 127.1 + b * 311.7) * 43758.5453
	return v - floor(v)

## the fields: strips of 46 by 130 m across the slopes; 0 pasture, 1 wheat, 2 rapeseed, 3 ploughed, 4 dark crop
static func field(x: float, z: float) -> int:
	var u := x * 0.88 + z * 0.48
	var v := -x * 0.48 + z * 0.88
	var r := hash2(floor(u / 46.0), floor(v / 130.0))
	if r < 0.46: return 0
	if r < 0.62: return 1
	if r < 0.72: return 2
	if r < 0.86: return 3
	return 4

static func build() -> void:
	var NS := Trk.NS
	var HT := Trk.HT
	pickQuarry()
	var TF := Terrain.terrainFn(hills)
	Trk.terrain_fn = TF.fn()
	var size := 3400.0
	var seg := 272
	var pos := Terrain.planeXZ(size, seg)
	var cx := (Trk.BX0 + Trk.BX1) / 2
	var cz := (Trk.BZ0 + Trk.BZ1) / 2
	var cols := PackedColorArray()
	cols.resize(pos.size())
	var fc := [MathX.col(0x6f9645), MathX.col(0xb3a24c), MathX.col(0xc9b930), MathX.col(0x8a6c4a), MathX.col(0x4c7634)]
	var cg2 := MathX.col(0x5f8a3e); var cw := MathX.col(0x47602f); var marl := MathX.col(0xe2d6a4); var marl2 := MathX.col(0xcfc294)
	for k in pos.size():
		var x := pos[k].x + cx
		var z := pos[k].z + cz
		pos[k].y = TF.at(x, z)
		var sp := hash2(x, z)
		var f := field(x, z)
		var tmp: Color = fc[f]
		if f == 0: tmp = tmp.lerp(cg2, 0.5 + 0.5 * sin(x / 31) * cos(z / 27))
		# the verge and the land right beside the road stay grass
		if TF.d < 30: tmp = tmp.lerp(fc[0], clampf((30 - TF.d) / 12, 0, 1))
		var wv := woodL(x, z)
		if wv > 0: tmp = tmp.lerp(cw, clampf(wv * 2.5, 0, 0.9))
		if not quarry.is_empty():
			var dq := quarrySdf(x, z)
			if dq < 16 and TF.d > 26: tmp = tmp.lerp(marl.lerp(marl2, sp), clampf((16 - dq) / 8, 0, 1) * clampf((TF.d - 26) / 10, 0, 1))
		var j := 0.96 + sp * 0.08
		cols[k] = Color(tmp.r * j, tmp.g * j, tmp.b * j)
	Terrain.groundMesh(pos, cols, seg, cx, cz, BKit.noiseTex(256, 2600, 0.18, 0.1), 23.0)
	var RH := Trk.ROAD_HALF
	var SH := Trk.SHOULDER
	World.ribbon(-RH, RH, World.roadMat(World.roadTexture("#58595b", [0.5], true, false, 0.3)), 10, 0.07)
	var verge := M(0x6c9044, {"map": BKit.noiseTex(64, 600, 0.12, 0.06)})
	World.ribbon(-SH, -RH, verge, 3.5, 0.05); World.ribbon(RH, SH, verge, 3.5, 0.05)
	World.startLine()
	World.gates(Trk.TRK)
	guardRail()
	sites(TF)
	woods(TF)
	vineyards(TF)
	houses(TF)
	church(TF)
	castle(TF)
	quarryDecor(TF)
	cattle(TF)
	crosses(TF)
	BKit.chevrons(12.4, 0.016, 9.0, 1.2, true)
	climb(TF)
	TrackCommon.signs([["Valkenburg", "3"], ["Cauberg", "1"], ["Maastricht", "14"]], 11.5)

## the quarry goes where a hill stands highest over the road, 95 m from it and clear of every other stretch of road
static func pickQuarry() -> void:
	quarry = []
	var NS := Trk.NS
	var best := 9.0
	for i in range(0, NS, 8):
		for side in [-1.0, 1.0]:
			var c := Trk.onTrack(i, side * 95)
			var b := Trk.onTrack(i, side * 140)
			if Trk.distToTrack(c[0], c[1]) < 88 or Trk.distToTrack(b[0], b[1]) < 125: continue
			var fl := Trk.HT[i] + 0.5
			var sc := hills0(b[0], b[1]) - fl
			if sc > best:
				best = sc
				quarry = [c[0], c[1], fl, 40.0, i, side, -side * Trk.R[i].x, -side * Trk.R[i].z]

## spots kept free of trees, cows and the roadside dressing: the church, the village, the castle
static var churchAt: Array = []
static var castleAt: Array = []
static func sites(TF: Terrain) -> void:
	var NS := Trk.NS
	var ci := int(round(NS * 0.28))
	var cxz := Trk.onTrack(ci, -40)
	churchAt = [cxz[0], cxz[1], Trk.heading_of(Trk.T[ci])]
	World.pavTaken.append([cxz[0], cxz[1], 23.0])
	# the castle: the highest hill 75 to 120 m from the road, away from the quarry and the church
	castleAt = []
	var best := -1e9
	for i in range(0, NS, 6):
		for side in [-1.0, 1.0]:
			for lat in [80.0, 105.0]:
				var p := Trk.onTrack(i, side * lat)
				if Trk.distToTrack(p[0], p[1]) < lat - 8: continue
				if not quarry.is_empty() and Vector2(p[0] - quarry[0], p[1] - quarry[1]).length() < 130: continue
				if Vector2(p[0] - cxz[0], p[1] - cxz[1]).length() < 200: continue
				var sc := hills0(p[0], p[1]) - 0.35 * absf(hills0(p[0] + 14, p[1]) - hills0(p[0] - 14, p[1])) - 0.35 * absf(hills0(p[0], p[1] + 14) - hills0(p[0], p[1] - 14))
				if sc > best:
					best = sc
					castleAt = [p[0], p[1], Trk.heading_of(Trk.T[i]) + (PI / 2 if side < 0 else -PI / 2)]
	if not castleAt.is_empty(): World.pavTaken.append([castleAt[0], castleAt[1], 24.0])

static func inQuarry(x: float, z: float, extra := 6.0) -> bool:
	return not quarry.is_empty() and quarrySdf(x, z) < 14 + extra

## white posts with a reflector every 10 m and a steel guard rail where the invisible wall stands (lat 10.6)
static func guardRail() -> void:
	var NS := Trk.NS
	var HT := Trk.HT
	var post := []; var refl := []
	var dd := 0.0
	while dd < Trk.TRACK_LEN:
		var i := int(round(dd / Trk.SPC)) % NS
		var hd := Trk.heading_of(Trk.T[i])
		for s in [-1, 1]:
			var xz := Trk.onTrack(i, s * 10.86)
			post.append(World.mtx(xz[0], HT[i] + 0.3, xz[1], hd))
			var rxz := Trk.onTrack(i, s * 10.78)
			refl.append(World.mtx(rxz[0], HT[i] + 0.82, rxz[1], hd))
		dd += 10
	World.inst(Geo.box(0.16, 1.5, 0.16), M(0xe8e6de), post, null, false)
	var rm := M(0xb8421c, {"emissive": 0x000000})
	World.reflMats.append(rm)
	World.inst(Geo.box(0.05, 0.2, 0.14), rm, refl, null, false)
	var rail := M(0xffffff, {"map": TrackCommon.railTex()})
	for s in [-1, 1]:
		World.vribbon(s * 10.8, 0.3, 0.68, rail, 4)

## woods of oak and spruce on the hilltops, loners in the fields, rows of poplars along the road, orchards in blossom
static func woods(TF: Terrain) -> void:
	var NS := Trk.NS
	var om := []; var oc := []; var sm := []; var sc := []; var pm := []; var pc := []; var fm := []; var fcol := []
	for _k in 3400:
		var x := Trk.BX0 - 300 + rnd() * (Trk.BX1 - Trk.BX0 + 600)
		var z := Trk.BZ0 - 300 + rnd() * (Trk.BZ1 - Trk.BZ0 + 600)
		var r := rnd()
		var s := 0.8 + rnd() * 0.7
		var ry := rnd() * 6
		var tint := 0.8 + rnd() * 0.4
		var th := TF.at(x, z)
		if TF.d < 18 or inQuarry(x, z) or World.pavBusy(x, z, 4.0): continue
		var wv := woodL(x, z)
		if wv < 0.0 and r > 0.05: continue
		if r < 0.8 or wv < 0.0:
			om.append(World.mtx(x, th - 0.2, z, ry, s * 1.15)); oc.append(Color(tint, tint, tint * 0.9))
		else:
			sm.append(World.mtx(x, th - 0.2, z, ry, s)); sc.append(Color(tint, tint, tint))
	# poplars: rows of 8 to 14 along one side of the road
	var d := 30.0
	while d < Trk.TRACK_LEN:
		var n := 8 + int(floor(rnd() * 7))
		var side := -1.0 if rnd() < 0.5 else 1.0
		var gap := 60 + rnd() * 160
		for q in n:
			var i := int(round((d + q * 11.0) / Trk.SPC)) % NS
			var xz := Trk.onTrack(i, side * 17.5)
			var s := 0.85 + rnd() * 0.3
			var th := TF.at(xz[0], xz[1])
			if TF.d < 16.5 or inQuarry(xz[0], xz[1]) or World.pavBusy(xz[0], xz[1], 3.0): continue
			pm.append(World.mtx(xz[0], th - 0.2, xz[1], rnd() * 6, s)); pc.append(Color(s, s, s * 0.9))
		d += n * 11.0 + gap
	# orchards: fruit trees in rows, white and pink blossom
	var blossom := [Color(1.0, 0.93, 0.9), Color(0.98, 0.76, 0.8), Color(0.98, 0.84, 0.86), Color(0.5, 0.68, 0.32)]
	for _o in 11:
		var i := int(floor(rnd() * NS))
		var side := -1.0 if rnd() < 0.5 else 1.0
		var c := Trk.onTrack(i, side * (34 + rnd() * 50))
		var ang := Trk.heading_of(Trk.T[i]) + (rnd() - .5) * 0.6
		var bc: Color = World.pick(blossom)
		for a in 6:
			for b in 8:
				var lx := (a - 2.5) * 6.5
				var lz := (b - 3.5) * 6.0
				var x: float = c[0] + cos(ang) * lx + sin(ang) * lz
				var z: float = c[1] - sin(ang) * lx + cos(ang) * lz
				var s := 0.85 + rnd() * 0.35
				var th := TF.at(x, z)
				if TF.d < 16 or woodL(x, z) > 0 or inQuarry(x, z) or World.pavBusy(x, z, 3.0): continue
				fm.append(World.mtx(x, th - 0.1, z, rnd() * 6, s)); fcol.append(Color(bc.r * (0.92 + rnd() * 0.08), bc.g, bc.b))
	var tm := M(0xffffff)
	World.inst(BKit.oakGeo(), tm, om, oc, true)
	World.inst(BKit.spruceGeo(), tm, sm, sc, true)
	World.inst(BKit.poplarGeo(), tm, pm, pc, true)
	World.inst(BKit.fruitGeo(), tm, fm, fcol, true)

## vineyards: rows of vines on the slopes, with a post every third vine
static func vineyards(TF: Terrain) -> void:
	var vp := []; var vh := []
	for _v in 16:
		var x0 := Trk.BX0 + rnd() * (Trk.BX1 - Trk.BX0)
		var z0 := Trk.BZ0 + rnd() * (Trk.BZ1 - Trk.BZ0)
		var ang := rnd() * 3
		for r in 9:
			for c in 14:
				var x := x0 + cos(ang) * c * 3 + sin(ang) * r * 2.6
				var z := z0 - sin(ang) * c * 3 + cos(ang) * r * 2.6
				var th := TF.at(x, z)
				if TF.d < 16 or woodL(x, z) > 0.1 or inQuarry(x, z) or World.pavBusy(x, z, 3.0): continue
				vh.append(World.mtx(x, th + 0.7, z, ang, 0.5, 1.2, 2.6))
				if c % 3 == 0: vp.append(World.mtx(x, th + 0.8, z))
	World.inst(Geo.box(1, 1, 1), M(0x3f6a2a), vh, null, true)
	World.inst(Geo.box(0.1, 1.6, 0.1), M(0x6b4a2e), vp, null, false)

## wall textures: marl stone (cream blocks) and half-timbering (white panels in dark beams), windows and a door
static func wallTex(timber: bool) -> ImageTexture:
	return Canvas2D.tex(128, 128, func(g, w, h):
		g.fillStyle = "#efe9da" if timber else "#e2cf92"; g.fillRect(0, 0, w, h)
		if timber:
			g.strokeStyle = "#3a2a1e"; g.lineWidth = 5
			for y in [3, 62, 125]:
				g.beginPath(); g.moveTo(0, y); g.lineTo(w, y); g.stroke()
			for x in [3, 44, 84, 125]:
				g.beginPath(); g.moveTo(x, 0); g.lineTo(x, h); g.stroke()
			g.lineWidth = 4
			g.beginPath(); g.moveTo(3, 62); g.lineTo(44, 3); g.stroke()
			g.beginPath(); g.moveTo(125, 62); g.lineTo(84, 3); g.stroke()
		else:
			g.strokeStyle = "rgba(120,96,50,.35)"; g.lineWidth = 1
			var y := 0
			while y < h:
				g.beginPath(); g.moveTo(0, y); g.lineTo(w, y); g.stroke()
				var x := (y / 16) % 2 * 16
				while x < w:
					g.beginPath(); g.moveTo(x, y); g.lineTo(x, y + 16); g.stroke()
					x += 32
				y += 16
			g.fillStyle = "#8a7a56"; g.fillRect(0, h - 10, w, 10)
		for wx in [14, 92]:
			g.fillStyle = "#f4f0e6"; g.fillRect(wx - 3, 22, 28, 30)
			g.fillStyle = "#26323c"; g.fillRect(wx, 25, 22, 24)
			g.fillStyle = "#f4f0e6"; g.fillRect(wx + 10, 25, 2, 24)
			g.fillStyle = "#3f6a4a"; g.fillRect(wx - 9, 22, 6, 30); g.fillRect(wx + 25, 22, 6, 30)
		for wx in [14, 92]:
			g.fillStyle = "#f4f0e6"; g.fillRect(wx - 3, 76, 28, 30)
			g.fillStyle = "#26323c"; g.fillRect(wx, 79, 22, 24)
			g.fillStyle = "#f4f0e6"; g.fillRect(wx + 10, 79, 2, 24)
		g.fillStyle = "#4a3222"; g.fillRect(52, 76, 24, 52)
		g.fillStyle = "#f4f0e6"; g.fillRect(52, 72, 24, 4))

static func winTex() -> ImageTexture:
	return Canvas2D.tex(128, 128, func(g, w, h):
		g.fillStyle = "#000"; g.fillRect(0, 0, w, h)
		g.fillStyle = "#ffd890"
		for wx in [14, 92]:
			if randf() < 0.7: g.fillRect(wx, 25, 22, 24)
			if randf() < 0.8: g.fillRect(wx, 79, 22, 24))

## the village round the church and farms in the fields: marl-stone and half-timbered houses with dark gable roofs,
## standing on the terrain (walls 1.5 m into the ground), windows lit at night
static func houses(TF: Terrain) -> void:
	var mb := []; var mc := []; var tb := []; var tcol := []; var rf := []; var rc := []
	var placed := []
	var roofs := [Color(0.3, 0.27, 0.25), Color(0.42, 0.24, 0.18), Color(0.25, 0.25, 0.28), Color(0.5, 0.3, 0.2)]
	var add := func(x: float, z: float, ry: float, timber: bool) -> bool:
		var w := 6.0 + rnd() * 2.5
		var d := 8.5 + rnd() * 5.0
		var h := 5.4 + rnd() * 1.2
		var rcol: Color = World.pick(roofs)
		var tn := 0.9 + rnd() * 0.14
		var th := TF.at(x, z)
		if TF.d < 24 or inQuarry(x, z, 12.0) or World.pavBusy(x, z, 8.0): return false
		for o in placed:
			if Vector2(o[0] - x, o[1] - z).length() < 15: return false
		placed.append([x, z])
		World.pavTaken.append([x, z, 8.0])
		if timber: tb.append(BKit.houseXf(x, th, z, ry, w, h, d)); tcol.append(Color(tn, tn, tn))
		else: mb.append(BKit.houseXf(x, th, z, ry, w, h, d)); mc.append(Color(tn, tn, tn * 0.96))
		rf.append(BKit.roofXf(x, th, z, ry, w, h, d, w * 0.52)); rc.append(rcol)
		return true
	# the village: up to 26 houses within 110 m of the church, turned along the street (the road) or across it
	for _k in 80:
		var a := rnd() * TAU
		var r := 26 + rnd() * 85
		var ry: float = churchAt[2] + (0.0 if rnd() < 0.6 else PI / 2) + (rnd() - .5) * 0.3
		var timber := rnd() < 0.45
		if placed.size() >= 26: continue
		add.call(churchAt[0] + cos(a) * r, churchAt[1] + sin(a) * r, ry, timber)
	# farms in the fields
	for _k in 70:
		var x := Trk.BX0 - 100 + rnd() * (Trk.BX1 - Trk.BX0 + 200)
		var z := Trk.BZ0 - 100 + rnd() * (Trk.BZ1 - Trk.BZ0 + 200)
		var ry := rnd() * 6
		var timber := rnd() < 0.3
		if woodL(x, z) > 0.0: continue
		add.call(x, z, ry, timber)
	var emap := winTex()
	var mm := M(0xffffff, {"map": wallTex(false), "emissive": 0x000000, "emissiveMap": emap})
	var tm := M(0xffffff, {"map": wallTex(true), "emissive": 0x000000, "emissiveMap": emap})
	World.winMats.append(mm); World.winMats.append(tm)
	World.inst(Geo.box(1, 1, 1), mm, mb, mc, true)
	World.inst(Geo.box(1, 1, 1), tm, tb, tcol, true)
	World.inst(TrackCommon.roofGeo(), M(0xffffff), rf, rc, true)

## the village church: nave with a slate roof, a tower with a spire, lit windows
static func church(TF: Terrain) -> void:
	var th := TF.at(churchAt[0], churchAt[1])
	var A := BKit.Acc.new()
	A.at(churchAt[0], th, churchAt[1], churchAt[2])
	var marl := 0xe0cc8c; var slate := 0x3b3a3e; var trim := 0xcdb878
	A.box(9, 12, 20, 0, 4, 0, marl)
	A.roof(9.8, 5, 20.8, 0, 9.97, 0, slate)
	A.box(7, 9, 5, 0, 2.5, -12, marl)                       # the choir
	A.roof(7.6, 3.6, 5.6, 0, 6.97, -12, slate)
	A.box(5.6, 26, 5.6, 0, 11, 12.2, marl)                  # the tower
	A.box(6.2, 0.5, 6.2, 0, 17.2, 12.2, trim); A.box(6.2, 0.5, 6.2, 0, 23.8, 12.2, trim)
	A.spire(6.0, 11, 6.0, 0, 24, 12.2, slate)
	A.box(0.14, 2.0, 0.14, 0, 36, 12.2, 0xd8c060); A.box(0.9, 0.14, 0.14, 0, 36.3, 12.2, 0xd8c060)
	for s in [-1.0, 1.0]:
		for k in 4:
			A.box(0.5, 4.6, 1.0, s * 4.6, 3.3, -7.0 + k * 4.4, trim)   # buttresses
	A.box(2.2, 3.4, 0.2, 0, 1.7, 15.06, 0x4a3222)           # the door
	A.commit()
	var win := BKit.Acc.new(BKit.vmat({"emissive": 0x000000}), false)
	World.winMats.append(win.mat)
	win.frame = A.frame
	for s in [-1.0, 1.0]:
		for k in 3:
			win.box(0.12, 4.2, 1.5, s * 4.52, 5.4, -4.8 + k * 4.4, 0x2a3446)
	win.box(1.2, 2.2, 0.12, 0, 15, 15.02, 0x2a3446)
	for s in [-1.0, 1.0]:
		win.box(0.12, 2.0, 1.2, s * 2.82, 20.5, 12.2, 0x2a3446)
	win.commit()

## a castle on its hill: a square keep, four round towers with pointed roofs, curtain walls, a gate house and a flag
static func castle(TF: Terrain) -> void:
	if castleAt.is_empty(): return
	var x: float = castleAt[0]
	var z: float = castleAt[1]
	var lo := 1e9
	for a in 8:
		lo = minf(lo, TF.at(x + cos(a * PI / 4) * 17, z + sin(a * PI / 4) * 17))
	var A := BKit.Acc.new()
	A.at(x, lo, z, castleAt[2])
	var stone := 0xd8c68e; var stone2 := 0xc4b27c; var roof := 0x4a4e5a
	A.box(40, 6, 34, 0, 0, 0, 0xb0a276)                     # the mound wall: the hill falls away under the castle
	for s in [-1.0, 1.0]:
		A.box(34, 7, 1.6, 0, 6.5, s * 15, stone); A.box(1.6, 7, 30, s * 17, 6.5, 0, stone)
		for k in 9:
			A.box(1.9, 1.0, 1.8, -15.2 + k * 3.8, 10.5, s * 15, stone2)
		for k in 7:
			A.box(1.8, 1.0, 1.9, s * 17, 10.5, -11.4 + k * 3.8, stone2)
		for t in [-1.0, 1.0]:
			A.cyl(3.2, 3.4, 14, 10, s * 17, 10, t * 15, stone)
			A.add(Geo.cone(3.9, 6.5, 10), roof, BKit.xf(s * 17, 20.2, t * 15))
	A.box(13, 16, 11, -3, 11, -3, stone)                    # the keep
	A.roof(11.8, 6, 13.8, -3, 18.97, -3, roof, PI / 2)
	A.box(7, 11, 4, 0, 8.5, 15, stone2)                     # the gate house, towards the road
	A.spire(7.6, 4.5, 4.6, 0, 14, 15, roof)
	A.box(3.2, 4.6, 0.3, 0, 5.3, 17.0, 0x3a2a1e)
	A.cyl(0.07, 0.07, 6, 5, -3, 28, -3, 0xe8e6de)
	A.box(2.4, 1.3, 0.05, -1.75, 30.2, -3, 0xc8302a)
	A.commit()
	var win := BKit.Acc.new(BKit.vmat({"emissive": 0x000000}), false)
	World.winMats.append(win.mat)
	win.frame = A.frame
	for k in 3:
		win.box(1.0, 1.8, 0.12, -6.5 + k * 3.5, 14, 2.56, 0x2a3446)
		win.box(1.0, 1.8, 0.12, -6.5 + k * 3.5, 9.5, 2.56, 0x2a3446)
	win.box(0.9, 1.4, 0.12, 0, 11, 17.02, 0x2a3446)
	win.commit()

## in the quarry: sawn marl blocks, dark gallery mouths in the back wall, an excavator and a board
static func quarryDecor(TF: Terrain) -> void:
	if quarry.is_empty(): return
	var qx: float = quarry[0]
	var qz: float = quarry[1]
	var R: float = quarry[3]
	var i: int = quarry[4]
	var side: float = quarry[5]
	# local +z points away from the road, to the back wall
	var ry := Trk.heading_of(Trk.T[i]) + (-PI / 2 if side > 0 else PI / 2)
	var fl := TF.at(qx, qz)
	var A := BKit.Acc.new()
	A.at(qx, fl, qz, ry)
	for k in 5:
		var gx := -24.0 + k * 12.0
		var gz := sqrt(maxf(0.0, (R - 2) * (R - 2) - gx * gx))
		A.box(5.0, 5.0, 9.0, gx, 2.3, gz, 0x1c1a16)             # gallery mouths: a dark hole in a frame of sawn marl
		A.box(7.0, 6.2, 8.6, gx, 2.9, gz + 0.4, 0xd6c998)
	for _k in 26:
		var bx := (rnd() - .5) * 56
		var bz := (rnd() - .5) * 50
		var s := 1.2 + rnd() * 1.6
		var rr := rnd() * 3
		var st := 1 + int(floor(rnd() * 2.4))
		if bx * bx + bz * bz > (R - 6) * (R - 6): continue
		for q in st:
			A.box(s * 1.6, s, s, bx, s * (0.5 + q), bz, 0xe8dcae if q % 2 == 0 else 0xdccf9c, rr)
	# the excavator: tracks, a yellow body with a cab, a boom and a bucket
	A.box(3.2, 0.9, 4.6, 9, 0.45, -6, 0x2a2a2e, 0.5)
	A.box(3.0, 1.6, 3.6, 9, 1.7, -6, 0xe2b21c, 0.5)
	A.box(1.3, 1.5, 1.5, 8.2, 3.2, -5.2, 0x2c3a48, 0.5)
	A.box(0.5, 0.5, 6.0, 10.9, 4.0, -2.9, 0xe2b21c, 0.5, -0.5, 0)
	A.box(0.45, 0.45, 3.6, 12.6, 4.2, 0.6, 0xe2b21c, 0.5, 0.9, 0)
	A.box(1.2, 1.0, 1.0, 13.3, 2.4, 1.9, 0x3a3a3e, 0.5)
	A.commit()
	World.pavTaken.append([qx, qz, R + 14])

## cows in the pastures near the road: black-and-white and red-and-white
static func cattle(TF: Terrain) -> void:
	var NS := Trk.NS
	var cm := []; var cc := []
	var groups := 0
	for _k in 120:
		var i := int(floor(rnd() * NS))
		var side := -1 if rnd() < 0.5 else 1
		var xz := Trk.onTrack(i, side * (24 + rnd() * 40))
		var n := 4 + int(floor(rnd() * 5))
		var red := rnd() < 0.3
		if groups >= 14: continue
		TF.at(xz[0], xz[1])
		if TF.d < 21 or field(xz[0], xz[1]) != 0 or woodL(xz[0], xz[1]) > -0.1 or inQuarry(xz[0], xz[1]) or World.pavBusy(xz[0], xz[1], 10.0): continue
		groups += 1
		for q in n:
			var x: float = xz[0] + (rnd() - .5) * 16
			var z: float = xz[1] + (rnd() - .5) * 16
			var r := rnd() * 6
			var th := TF.at(x, z)
			if TF.d < 17 or World.pavBusy(x, z, 2.0): continue
			cm.append(World.mtx(x, th, z, r, 0.95 + rnd() * 0.15))
			cc.append(Color(0.75, 0.42, 0.3) if red else Color(1, 1, 1))
	World.inst(BKit.cowGeo(), M(0xffffff), cm, cc, true)

## wayside crosses (wegkruis) under two lime trees, where Limburg roads have them
static func crosses(TF: Terrain) -> void:
	var NS := Trk.NS
	var A := BKit.Acc.new()
	var tm := []; var tc := []
	for k in 4:
		var i := int(round(NS * (0.09 + k * 0.24))) % NS
		var side := 1.0 if k % 2 else -1.0
		var xz := Trk.onTrack(i, side * 15.5)
		var th := TF.at(xz[0], xz[1])
		if TF.d < 14.5 or World.pavBusy(xz[0], xz[1], 3.0): continue
		World.pavTaken.append([xz[0], xz[1], 4.0])
		A.at(xz[0], th, xz[1], Trk.heading_of(Trk.T[i]) + (PI / 2 if side > 0 else -PI / 2))
		A.box(1.4, 1.0, 1.4, 0, 0.3, 0, 0xd8c88e)
		A.box(0.24, 3.4, 0.24, 0, 2.5, 0, 0x4a3222); A.box(1.5, 0.24, 0.24, 0, 3.4, 0, 0x4a3222)
		A.box(1.9, 0.12, 0.6, 0, 4.3, 0, 0x4a3222, 0, 0, 0.5); A.box(1.9, 0.12, 0.6, 0, 4.3, 0, 0x4a3222, 0, 0, -0.5)
		for t in [-1.0, 1.0]:
			var p := A.frame * Vector3(t * 3.4, 0, -1.0)
			tm.append(World.mtx(p.x, TF.at(p.x, p.z) - 0.1, p.z, rnd() * 6, 0.95)); tc.append(Color(0.95, 1, 0.9))
	A.commit()
	World.inst(BKit.oakGeo(), M(0xffffff), tm, tc, true)

## the steepest climb of the lap is the "Cauberg": fans along both sides and paint on the road
static func climb(_TF: Terrain) -> void:
	var NS := Trk.NS
	var HT := Trk.HT
	var W := 40
	var bi := 0
	var bg := -1e9
	for i in NS:
		var g := HT[(i + W) % NS] - HT[i]
		if g > bg:
			bg = g; bi = i
	var texts := ["HUP", "KOM OP", "CAUBERG", "GAS!"]
	for k in texts.size():
		var m := M(0xffffff, {"map": BKit.paintTex(texts[k], "#f4f4ee" if k % 2 == 0 else "#f2c200"), "transparent": true, "depthWrite": false, "opacity": 0.85})
		BKit.decal(bi + 3 + k * 10, 4, -5.6 if k % 2 else -0.6, 0.6 if k % 2 else 5.6, m, 0.115)
	var ppl := []
	for s in [-1.0, 1.0]:
		ppl.append_array(BKit.crowdRow(bi, 30, s * 12.0, 2.4, 1))
	BKit.crowd(ppl)
	# flags on poles behind the fans
	var fp := []; var ff := []; var fc := []
	var pal := [Color(0.68, 0.11, 0.16), Color(0.95, 0.76, 0.0), Color(0.13, 0.27, 0.55), Color(0.95, 0.44, 0.13)]
	for k in 8:
		var i := (bi + 4 + k * 5) % NS
		var s := -1.0 if k % 2 else 1.0
		var xz := Trk.onTrack(i, s * 13.4)
		var y := BKit.gy(xz[0], xz[1])
		var hd := Trk.heading_of(Trk.T[i])
		fp.append(World.mtx(xz[0], y + 3, xz[1]))
		ff.append(World.mtx(xz[0] + sin(hd) * 0.75, y + 5.4, xz[1] + cos(hd) * 0.75, hd + PI / 2, 1.5, 0.95, 0.05))
		fc.append(World.pick(pal))
		World.pavTaken.append([xz[0], xz[1], 1.0])
	World.inst(Geo.cylinder(0.05, 0.06, 6.4, 5), M(0xe8e4dc), fp, null, false)
	World.inst(Geo.box(1, 1, 1), M(0xffffff), ff, fc, false)

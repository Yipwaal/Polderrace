class_name BuildRotterdam
## Rotterdam. Started as a port of buildRotterdam from polderrace-3d.html (the Maas, the Erasmusbrug with pylon and
## stays, the red Willemsbrug, a skyline of boxes, the Euromast, water taxis); fase 2 built the city round it: blocks
## of glass, concrete and brick lining the streets, De Rotterdam, the cube houses, the Markthal, a Euromast with its
## crow's nest, container cranes, a container ship and barges on the river (one sails), a tram along the start
## straight, light boards on the roofs, bridge piers, arrow boards and fans. Everything random: seeded World.rnd.

static func M(c: int, o: Dictionary = {}) -> LMat:
	return Mats.M(c, o)

static func rnd() -> float:
	return World.rnd.next()

## JS Math.round (halves go up, also for negative numbers)
static func jround(v: float) -> int:
	return int(floor(v + 0.5))

const RZ0 := -300.0   ## the Maas lies between these two z
const RZ1 := -160.0

static func overRiver(x: float, z: float) -> bool:
	return z > RZ0 and z < RZ1

static func land(i: int) -> bool:
	return not overRiver(Trk.P[i].x, Trk.P[i].z)

## building lots of the whole city (blocks, towers, landmarks): nothing stands in anything else
static var lots: BKit.Lots
## the three kinds of front: transforms and tints of unit boxes [glass, concrete, brick]
static var fronts: Array = []

## fronts: 0 glass curtain wall, 1 white concrete with window bands, 2 brick with windows; lit = the night picture
static func frontTex(kind: int, lit: bool) -> ImageTexture:
	return Canvas2D.tex(128, 256, func(g, w, h):
		var floors := 10
		var fh: float = h / (floors + 0.7)
		if lit:
			g.fillStyle = "#000"; g.fillRect(0, 0, w, h)
		else:
			g.fillStyle = ["#9fb6c8", "#f2f0ea", "#ffffff"][kind]; g.fillRect(0, 0, w, h)
		for f in floors:
			var y: float = h - fh * (f + 1) - 4
			if kind == 0:
				for c in 8:
					if lit:
						if randf() < 0.3:
							g.fillStyle = "rgba(255,%d,%d,%f)" % [200 + randi() % 40, 130 + randi() % 80, 0.35 + randf() * 0.6]; g.fillRect(c * 16 + 1, y, 14, fh - 3)
					else:
						g.fillStyle = "#3d5a70" if (c + f) % 3 else "#4a6a82"; g.fillRect(c * 16 + 1, y, 14, fh - 3)
			elif kind == 1:
				if lit:
					for c in 6:
						if randf() < 0.35:
							g.fillStyle = "rgba(255,%d,%d,%f)" % [200 + randi() % 40, 130 + randi() % 80, 0.35 + randf() * 0.6]; g.fillRect(6 + c * 20, y + 2, 16, fh * 0.5)
				else:
					g.fillStyle = "#26323c"; g.fillRect(4, y + 2, w - 8, fh * 0.5)
					g.fillStyle = "#f2f0ea"
					for c in 5: g.fillRect(23 + c * 20, y + 2, 3, fh * 0.5)
			else:
				for x in [10, 40, 70, 100]:
					if lit:
						if randf() < 0.4:
							g.fillStyle = "rgba(255,%d,%d,%f)" % [200 + randi() % 40, 130 + randi() % 80, 0.35 + randf() * 0.6]; g.fillRect(x, y, 18, fh * 0.62)
					else:
						g.fillStyle = "#1f2a33"; g.fillRect(x, y, 18, fh * 0.62)
						g.fillStyle = "#e8e4dc"; g.fillRect(x - 1, y - 2, 20, 2)
		if lit:
			# the shops on the ground floor are lit
			g.fillStyle = "rgba(255,225,170,0.8)"; g.fillRect(6, h - fh * 0.6, w - 12, fh * 0.45)
		else:
			g.fillStyle = "#2a2e34"; g.fillRect(0, h - fh * 0.72, w, fh * 0.72)
			g.fillStyle = "#6f8496"; g.fillRect(6, h - fh * 0.6, w - 12, fh * 0.45)
			g.fillStyle = "#2a2e34"
			for c in 5: g.fillRect(24 + c * 20, h - fh * 0.6, 3, fh * 0.45))

## a block or tower: a unit box with a front texture, w along its local x, d along z
static func addBlock(kind: int, x: float, z: float, ry: float, w: float, h: float, d: float, tint: Color) -> void:
	fronts[kind][0].append(Transform3D(Basis(Vector3.UP, ry).scaled_local(Vector3(w, h, d)), Vector3(x, h / 2, z)))
	fronts[kind][1].append(tint)

static func build() -> void:
	var NS := Trk.NS
	var P := Trk.P
	var R := Trk.R
	var HT := Trk.HT
	var EMB := Trk.EMB
	var RH := Trk.ROAD_HALF
	var SH := Trk.SHOULDER
	lots = BKit.Lots.new()
	fronts = [[[], []], [[], []], [[], []]]
	TrackCommon.waterPlane(5000, RZ1 - RZ0, 400, (RZ0 + RZ1) / 2, -0.6, 0x44606e)
	var pave := Canvas2D.tex(256, 256, func(g, w, h):
		# city ground: slabs of concrete in slightly different greys, thin joints, stains
		g.fillStyle = "#6c6f72"; g.fillRect(0, 0, w, h)
		for a in 8:
			for b in 8:
				var v := 104 + randi() % 20
				g.fillStyle = "rgb(%d,%d,%d)" % [v, v + 2, v + 5]; g.fillRect(a * 32 + 1, b * 32 + 1, 31, 31)
		for _k in 260:
			g.fillStyle = "rgba(0,0,0,%f)" % (randf() * 0.07)
			g.beginPath(); g.ellipse(randf() * w, randf() * h, 2 + randf() * 14, 2 + randf() * 8, 0, 0, TAU); g.fill(), true)
	TrackCommon.landPlane(pave, Trk.BX0 - 500, RZ1, Trk.BX1 + 500, Trk.BZ1 + 500, 40)
	TrackCommon.landPlane(pave, Trk.BX0 - 500, Trk.BZ0 - 500, Trk.BX1 + 500, RZ0, 40)
	for z in [RZ0, RZ1]:
		World.box(Trk.BX1 - Trk.BX0 + 1000, 3, 1.2, M(0x5a5f63), (Trk.BX0 + Trk.BX1) / 2, -1, z, null, false)
	var landF := func(i: int) -> bool: return land(i)
	var conc := M(0x96999c, {"map": BKit.noiseTex(64, 500, 0.1, 0.05)})
	World.ribbon(-RH, RH, World.roadMat(World.roadTexture("#4d4f52", [0.25, 0.5, 0.75], true, false, 0.3)), 12, 0.07)
	World.ribbon(-SH, -RH, conc, 2.5, 0.06)
	World.ribbon(RH, SH, conc, 2.5, 0.06)
	World.ribbon(func(i): return -(SH + EMB[i]), -SH, conc, 8, 0.05, landF)
	World.ribbon(SH, func(i): return SH + EMB[i], conc, 8, 0.05, landF)
	var deck := M(0x8d9398)
	var rail := M(0xffffff, {"map": TrackCommon.railTex()})
	for s: int in [-1, 1]:
		World.vribbon(s * SH, -3, 0.1, deck, 4, func(i): return not land(i) or HT[i] > 1)
		World.vribbon(s * (SH - 0.2), 0.1, 1.1, rail, 3)
	World.startLine()
	World.gates(Trk.TRK)
	erasmus()
	willems()
	piers()
	tramLine()
	cubeHouses()
	streetBlocks()
	deRotterdam()
	markthal()
	euromast()
	skyline()
	World.inst(Geo.box(1, 1, 1), frontMat(0), fronts[0][0], fronts[0][1], true)
	World.inst(Geo.box(1, 1, 1), frontMat(1), fronts[1][0], fronts[1][1], true)
	World.inst(Geo.box(1, 1, 1), frontMat(2), fronts[2][0], fronts[2][1], true)
	harbour()
	river()
	BKit.chevrons(14.6, 0.016, 9.0, 1.3, false)
	fans()
	TrackCommon.lampRow(9.2, 45, 9, {"both": true})

static func frontMat(kind: int) -> LMat:
	var m := M(0xffffff, {"map": frontTex(kind, false), "emissive": 0x000000, "emissiveMap": frontTex(kind, true)})
	World.winMats.append(m)
	return m

## Erasmusbrug pylon: the two legs stand in the river beside the deck (outside the railing), rise straight up to 16 m above
## the road, are tied by a cross beam there and only then lean in to one mast. The stays fan out from the mast to the deck edges.
static func erasmus() -> void:
	var NS := Trk.NS
	var P := Trk.P
	var R := Trk.R
	var HT := Trk.HT
	var RH := Trk.ROAD_HALF
	var SH := Trk.SHOULDER
	var cables := 0xe8ecef
	var ib := 0
	for i in NS:
		if HT[i] > HT[ib]: ib = i
	var g := Node3D.new()
	var wht := M(0xf2f4f5)
	var h := HT[ib]
	var lx := SH + 3
	var kn := h + 16
	var mt := h + 44
	World.place(g, ib, 0, 0)
	g.position.y = 0
	# each arm runs from the top of its leg (lx,kn) to x=1 under the mast; it reaches 0.4 m into the leg and 1.2 m into the mast,
	# so its cross-section at the knee is exactly the top of the leg and no corner sticks out of the leg or the mast
	for s: int in [-1, 1]:
		World.box(2.4, kn + 2, 2.8, wht, s * lx, (kn - 2) / 2, 0, g)
		var dx := lx - 1
		var dy := mt - kn
		var L := sqrt(dx * dx + dy * dy)
		var ux := -s * dx / L
		var uy := dy / L
		var a := World.box(2.2, L + 1.6, 2.4, wht, (s * lx - ux * 0.4 + s + ux * 1.2) / 2, (kn - uy * 0.4 + mt + uy * 1.2) / 2, 0, g)
		O3.rot(a, 0, 0, s * atan2(dx, dy))
	World.box(lx * 2, 2.2, 2, wht, 0, kn - 1.4, 0, g)
	World.box(lx * 2, 1.8, 2, wht, 0, h - 3.8, 0, g, false)
	World.box(3.2, 40, 3.2, wht, 0, mt + 18, 0, g)
	# on the curved approaches a stay to a far anchor cuts the corner over the inner lanes: only build stays that stay 8 m above the lanes
	for k in range(-12, 13):
		if k == 0: continue
		var j := (ib + k * 6 + NS) % NS
		for s: int in [-1, 1]:
			var axz := Trk.onTrack(ib, s * 1.7)
			var bxz := Trk.onTrack(j, s * (SH + 0.15))
			var ax: float = axz[0]
			var az: float = axz[1]
			var bx: float = bxz[0]
			var bz: float = bxz[1]
			var Ay := mt + 12 + absi(k) * 2
			var By := HT[j] + 0.05
			var low := false
			var q := 1
			while q < 120 and not low:
				var f := q / 120.0
				var x := ax + (bx - ax) * f
				var z := az + (bz - az) * f
				var bi := ib
				var bd := 1e9
				for m in range(-80, 81):
					var i := (ib + m + NS) % NS
					var ex := x - P[i].x
					var ez := z - P[i].z
					var d := ex * ex + ez * ez
					if d < bd:
						bd = d
						bi = i
				if absf((x - P[bi].x) * R[bi].x + (z - P[bi].z) * R[bi].z) <= RH and Ay + (By - Ay) * f - HT[bi] < 8:
					low = true
				q += 1
			if not low:
				World.wire([Vector3(ax, Ay, az), Vector3(bx, By, bz)], cables)

## Willemsbrug: two red portal frames on the river bridge west of x=200
static func willems() -> void:
	var NS := Trk.NS
	var HT := Trk.HT
	var best := -1.0
	var bi := 0
	for i in NS:
		if not land(i) and Trk.P[i].x < 200 and HT[i] > best:
			best = HT[i]
			bi = i
	var red := M(0xc8302a)
	for off: int in [-20, 20]:
		var j := (bi + jround(off / Trk.SPC) + NS) % NS
		var g := Node3D.new()
		for s: int in [-1, 1]:
			World.box(1.6, 26, 1.6, red, s * 11, HT[j] + 10, 0, g)
		World.box(24, 2, 1.8, red, 0, HT[j] + 22, 0, g)
		World.place(g, j, 0, 0)
		g.position.y = 0

## concrete piers under both river bridges, every 44 m, from the river bed to the deck
static func piers() -> void:
	var NS := Trk.NS
	var HT := Trk.HT
	var A := BKit.Acc.new()
	for i in range(0, NS, 22):
		if land(i) or HT[i] < 4.5: continue
		var g := Node3D.new()
		World.place(g, i, 0, 0)
		A.frame = Transform3D(g.transform.basis, Vector3(g.position.x, 0, g.position.z))
		World.root.remove_child(g)
		g.free()
		var top := HT[i] - 3.0
		A.box(Trk.SHOULDER * 2 - 3, top + 2.5, 2.4, 0, (top - 2.5) / 2, 0, 0x9a9fa4)
		A.box(Trk.SHOULDER * 2 + 1, 1.2, 3.4, 0, top - 0.6, 0, 0x8d9398)
	A.commit()

## a tram line beside the start straight (lat -15.5) with a tram that rides up and down it
static var tramEnd := 0.0
static func tramLine() -> void:
	var NS := Trk.NS
	# the straight: from the start as long as the road is level and nearly straight
	var n := 0
	while n < NS / 3 and Trk.CURV[(Trk.START_I + n) % NS] < 0.004 and Trk.HT[(Trk.START_I + n) % NS] < 0.3: n += 1
	var i0 := Trk.START_I - 4
	var i1 := Trk.START_I + n - 6
	tramEnd = i1 * Trk.SPC
	if n < 40: return
	var bed := M(0x5f6468, {"map": BKit.noiseTex(64, 400, 0.14, 0.06)})
	var steel := M(0xb4b8bc)
	var on := func(i: int) -> bool: return i >= i0 and i < i1
	World.ribbon(-17.3, -13.7, bed, 3, 0.05, on)
	for l in [-16.22, -14.78]:
		World.ribbon(l - 0.06, l + 0.06, steel, 3, 0.12, on)
	# the overhead wire on masts
	var mast := []
	for i in range(i0, i1, 15):
		var xz := Trk.onTrack(i, -17.9)
		mast.append(World.mtx(xz[0], 0, xz[1], Trk.heading_of(Trk.T[i])))
		World.pavTaken.append([xz[0], xz[1], 1.0])
	World.inst(BKit.merge([[Geo.cylinder(0.09, 0.12, 6.6, 6).translate(0, 3.3, 0), 0x3a4046], [Geo.box(2.7, 0.08, 0.08).translate(1.3, 6.2, 0), 0x3a4046]]), BKit.vmat(), mast, null, false)
	var a := Trk.onTrack(i0, -15.5)
	var b := Trk.onTrack(i1, -15.5)
	World.wire([Vector3(a[0], 5.9, a[1]), Vector3(b[0], 5.9, b[1])], 0x2a2e33)
	# the tram: two cars and a joint, silver with a red band, lit windows
	var g := Node3D.new()
	var body := M(0xd8dcdf); var red := M(0xc8202a); var dark := M(0x23282e)
	var win := M(0x26323c, {"emissive": 0x000000})
	World.winMats.append(win)
	for k in [-1.0, 1.0]:
		World.box(2.4, 2.5, 13.0, body, 0, 1.95, k * 6.9, g, false)
		World.box(2.44, 0.5, 13.02, red, 0, 0.95, k * 6.9, g, false)
		World.box(2.46, 0.9, 12.2, win, 0, 2.35, k * 6.9, g, false)
		World.box(2.0, 0.25, 12.4, dark, 0, 3.32, k * 6.9, g, false)
		World.box(2.2, 0.5, 3.0, dark, 0, 0.45, k * 3.4, g, false); World.box(2.2, 0.5, 3.0, dark, 0, 0.45, k * 10.4, g, false)
	World.box(2.1, 2.3, 0.8, dark, 0, 1.9, 0, g, false)
	World.box(0.08, 2.4, 0.08, dark, 0, 4.6, 6.9, g, false); World.box(1.4, 0.06, 0.06, dark, 0, 5.82, 6.9, g, false)
	World.add(AnimB.along(g, (i0 + 9) * Trk.SPC, (i1 - 9) * Trk.SPC, -15.5, 0.0, 9.0))

## the cube houses: yellow cubes standing on a corner on six-sided trunks, two rows beside the road
static func cubeHouses() -> void:
	var NS := Trk.NS
	var best := []
	for f in [0.17, 0.2, 0.74, 0.8, 0.86, 0.52]:
		for side in [1.0, -1.0]:
			var i := int(round(NS * f)) % NS
			var c := Trk.onTrack(i, side * 34)
			if not land(i) or Trk.HT[i] > 0.5 or absf(c[1] - RZ0) < 60 or absf(c[1] - RZ1) < 60 or overRiver(c[0], c[1]): continue
			if Trk.distToTrack(c[0], c[1]) < 30: continue
			if best.is_empty(): best = [c[0], c[1], Trk.heading_of(Trk.T[i])]
	if best.is_empty(): return
	if not lots.take(best[0], best[1], best[2], 15, 27, 2.0, 2.0): return
	# a cube on its corner: turn the body diagonal upright
	var cube := Geo.box(7.4, 7.4, 7.4)
	cube.apply_transform(Transform3D(Basis(Vector3(1, 0, -1).normalized(), acos(1.0 / sqrt(3.0))), Vector3.ZERO))
	cube.translate(0, 11.6, 0)
	var roof := Geo.box(7.46, 2.2, 7.46).translate(0, 2.65, 0)
	roof.apply_transform(Transform3D(Basis(Vector3(1, 0, -1).normalized(), acos(1.0 / sqrt(3.0))), Vector3.ZERO))
	roof.translate(0, 11.6, 0)
	var geo := BKit.merge([
		[Geo.cylinder(2.3, 2.6, 7.4, 6).translate(0, 3.7, 0), 0xb8b4aa],
		[cube, 0xe8c21c],
		[roof, 0x8a8f96]])
	var xf := []
	var fr := Transform3D(Basis(Vector3.UP, best[2]), Vector3(best[0], 0, best[1]))
	for a in 2:
		for b in 6:
			xf.append(fr * Transform3D(Basis(Vector3.UP, (a + b) * 0.52), Vector3((a - 0.5) * 13.0, 0, (b - 2.5) * 8.6 + a * 4.3)))
	World.inst(geo, BKit.vmat(), xf, null, true)
	World.pavTaken.append([best[0], best[1], 30.0])

## blocks along the streets: 5 to 11 floors of glass, concrete or brick with shops below, a plant room on the roof and
## here and there a light board; side streets between them. The tram side of the start straight stands further back.
static func streetBlocks() -> void:
	var tints := [[Color(0.75, 0.86, 0.95), Color(0.62, 0.78, 0.86), Color(0.86, 0.9, 0.92), Color(0.55, 0.66, 0.74)],
		[Color(0.95, 0.94, 0.9), Color(0.82, 0.8, 0.74), Color(0.7, 0.74, 0.78), Color(0.93, 0.86, 0.72)],
		[Color(0.62, 0.34, 0.25), Color(0.5, 0.3, 0.24), Color(0.72, 0.6, 0.45), Color(0.4, 0.36, 0.34)]]
	var plant := []; var boards := [[], [], [], [], []]
	for sd in [-1.0, 1.0]:
		var s := 6.0 + rnd() * 10
		while s < Trk.TRACK_LEN - 20:
			var L := 18.0 + rnd() * 18
			var D := 12.0 + rnd() * 7
			var hgt := 15.0 + rnd() * rnd() * 30
			var kind := int(floor(rnd() * 3))
			var tint: Color = World.pick(tints[kind])
			var gap := 3.0 + rnd() * rnd() * 16
			var sign := rnd()
			var f := Trk.trackAt(s + L / 2)
			var front := 17.6 if not (sd < 0 and s < tramEnd + 12) else 20.4
			var lat: float = sd * (front + D / 2)
			var x: float = f.px + f.rx * lat
			var z: float = f.pz + f.rz * lat
			var hd := atan2(f.tx, f.tz)
			s += L + gap
			if Trk.HT[f.i] > 1.2 or not land(f.i) or overRiver(x, z) or absf(z - RZ0) < D / 2 + L / 2 + 4 or absf(z - RZ1) < D / 2 + L / 2 + 4: continue
			if Trk.distToTrack(x, z) < absf(lat) - 1.5: continue
			if not lots.take(x, z, hd, D / 2, L / 2, 1.5, 1.5): continue
			# local x = depth (across the street), local z = length (along it)
			addBlock(kind, x, z, hd, D, hgt, L, tint)
			plant.append(Transform3D(Basis(Vector3.UP, hd).scaled_local(Vector3(D * 0.45, 2.6, L * 0.35)), Vector3(x, hgt + 1.3, z)))
			if sign < 0.3:
				# a light board on the roof edge, facing the street
				var bx: float = x - sd * f.rx * (D / 2 - 0.3)
				var bz: float = z - sd * f.rz * (D / 2 - 0.3)
				boards[int(sign * 1000) % 5].append(Transform3D(Basis(Vector3.UP, hd + (-PI / 2 if sd > 0 else PI / 2)), Vector3(bx, hgt + 1.5, bz)))
	World.inst(Geo.box(1, 1, 1), M(0x4a4f55), plant, null, false)
	var texts := ["HOTEL MAAS", "010 CAFÉ", "DE KUIP", "HAVENBANK", "KAPSALON"]
	var cols := ["#ff5a4a", "#4ad2ff", "#ffd24a", "#7dff8a", "#ff7ad8"]
	for k in 5:
		if boards[k].is_empty(): continue
		var t: String = texts[k]
		var tex := Canvas2D.tex(256, 64, func(g, w, h):
			g.fillStyle = "#14161a"; g.fillRect(0, 0, w, h)
			g.strokeStyle = cols[k]; g.lineWidth = 3; g.strokeRect(4, 4, w - 8, h - 8)
			g.fillStyle = cols[k]; g.font = "800 40px Barlow Condensed"; g.textAlign = "center"; g.textBaseline = "middle"
			g.fillText(t, w / 2.0, h / 2.0 + 2, w - 24))
		var m := M(0xffffff, {"map": tex, "emissive": 0x000000, "emissiveMap": tex})
		World.lampMats.append(m)
		World.inst(BKit.merge([[Geo.plane(9, 2.25), 0xffffff]]), m, boards[k], null, false)
	var back := []
	for k in 5:
		for m in boards[k]:
			back.append(m)
	World.inst(BKit.merge([[Geo.box(9.2, 2.45, 0.2).translate(0, 0, -0.14), 0x1c1e22], [Geo.box(0.2, 1.2, 0.2).translate(-3, -1.5, -0.14), 0x1c1e22], [Geo.box(0.2, 1.2, 0.2).translate(3, -1.5, -0.14), 0x1c1e22]]), BKit.vmat(), back, null, false)

## De Rotterdam: three towers, each of two glass blocks that have shifted, on one base, on the south bank by the bridge
static func deRotterdam() -> void:
	var NS := Trk.NS
	var done := false
	for i in range(0, NS, 6):
		for side in [-1.0, 1.0]:
			if done: continue
			var c := Trk.onTrack(i, side * 78)
			# on the south bank, on the quay
			if c[1] > RZ0 - 30 or c[1] < RZ0 - 75 or Trk.distToTrack(c[0], c[1]) < 62: continue
			if not lots.take(c[0], c[1], 0.0, 54, 20, 3.0, 3.0): continue
			done = true
			addBlock(1, c[0], c[1], 0.0, 104, 22, 34, Color(0.72, 0.76, 0.8))
			for k in 3:
				var x: float = c[0] + (k - 1) * 35.0
				var sh := 5.0 if k % 2 else -5.0
				fronts[0][0].append(Transform3D(Basis.from_scale(Vector3(28, 52, 28)), Vector3(x, 22 + 26, c[1] + sh))); fronts[0][1].append(Color(0.72, 0.84, 0.95))
				fronts[0][0].append(Transform3D(Basis.from_scale(Vector3(28, 56, 28)), Vector3(x + 4, 74 + 28, c[1] - sh))); fronts[0][1].append(Color(0.6, 0.74, 0.88))
			World.pavTaken.append([c[0], c[1], 60.0])

## the Markthal: a grey horseshoe arch of flats over a market hall with a glass end, on the north bank
static func markthal() -> void:
	var NS := Trk.NS
	for f in [0.08, 0.92, 0.12, 0.88, 0.04, 0.96]:
		for side in [1.0, -1.0]:
			var i := int(round(NS * f)) % NS
			var c := Trk.onTrack(i, side * 66)
			if c[1] < RZ1 + 50 or Trk.distToTrack(c[0], c[1]) < 52: continue
			var ry := Trk.heading_of(Trk.T[i]) + PI / 2
			if not lots.take(c[0], c[1], ry, 30, 22, 2.0, 2.0): continue
			var pts := []
			for k in 13:
				var a := PI * k / 12.0
				pts.append(Vector2(cos(a) * 20, sin(a) * 34))
			for k in 13:
				var a := PI * (12 - k) / 12.0
				pts.append(Vector2(cos(a) * 13, sin(a) * 26))
			var arch := Geo.extrude(pts, 56.0)
			arch.translate(0, 0, -28)
			var A := BKit.Acc.new()
			A.at(c[0], 0, c[1], ry)
			A.add(arch, 0xa9adb2)
			A.commit()
			var glass := BKit.Acc.new(BKit.vmat({"emissive": 0x000000}), false)
			World.winMats.append(glass.mat)
			glass.at(c[0], 0, c[1], ry)
			for e in [-1.0, 1.0]:
				var pane := Geo.extrude(pts.slice(13), 0.3)
				pane.translate(0, 0, e * 27.4 - 0.15)
				glass.add(pane, 0x4a6272)
			glass.commit()
			World.pavTaken.append([c[0], c[1], 36.0])
			return

## the skyline: towers of 30 to 160 m further from the road, in the three kinds of front
static func skyline() -> void:
	var tcols := [Color(0.72, 0.84, 0.95), Color(0.9, 0.9, 0.88), Color(0.55, 0.62, 0.7), Color(0.95, 0.93, 0.86), Color(0.5, 0.56, 0.62), Color(0.72, 0.6, 0.46)]
	parks()
	for _k in 220:
		var x := Trk.BX0 - 300 + rnd() * (Trk.BX1 - Trk.BX0 + 600)
		var z := Trk.BZ0 - 300 + rnd() * (Trk.BZ1 - Trk.BZ0 + 600)
		var h := (30.0 if z < RZ0 else 40.0) + rnd() * (120.0 if z > RZ1 else 60.0)
		var w := 14 + rnd() * 16
		var ry := 0.0 if rnd() < 0.5 else PI / 2
		var dz := w * (0.7 + rnd() * 0.6)
		var kind := int(floor(rnd() * 3))
		var tint: Color = World.pick(tcols)
		if overRiver(x, z) or absf(z - RZ0) < 30 or absf(z - RZ1) < 30 or Trk.distToTrack(x, z) < 34: continue
		if not lots.take(x, z, ry, w / 2, dz / 2, 2.0, 2.0): continue
		addBlock(kind, x, z, ry, w, h, dz, tint)
	# lower blocks of flats and offices in between (the city does not stop behind the first row)
	for _k in 500:
		var x := Trk.BX0 - 250 + rnd() * (Trk.BX1 - Trk.BX0 + 500)
		var z := Trk.BZ0 - 250 + rnd() * (Trk.BZ1 - Trk.BZ0 + 500)
		var w := 16 + rnd() * 22
		var dz := 12 + rnd() * 10
		var h := 9.0 + rnd() * rnd() * 26
		var ry := 0.0 if rnd() < 0.5 else PI / 2
		var kind := 2 if rnd() < 0.45 else int(floor(rnd() * 2))
		var tint: Color = World.pick(tcols)
		if overRiver(x, z) or absf(z - RZ0) < 26 or absf(z - RZ1) < 26 or Trk.distToTrack(x, z) < 30 + maxf(w, dz) / 2: continue
		if not lots.take(x, z, ry, w / 2, dz / 2, 4.0, 4.0): continue
		addBlock(kind, x, z, ry, w, h, dz, tint)

## parks: lawns with trees and paths in a few open spots of the city
static func parks() -> void:
	var A := BKit.Acc.new(BKit.vmat(), false)
	var trees := []; var tc := []
	var n := 0
	for _k in 60:
		if n >= 7: break
		var x := Trk.BX0 - 150 + rnd() * (Trk.BX1 - Trk.BX0 + 300)
		var z := Trk.BZ0 - 150 + rnd() * (Trk.BZ1 - Trk.BZ0 + 300)
		var w := 40 + rnd() * 40
		var d := 40 + rnd() * 30
		if overRiver(x, z) or absf(z - RZ0) < d / 2 + 10 or absf(z - RZ1) < d / 2 + 10 or Trk.distToTrack(x, z) < 22 + maxf(w, d) / 2: continue
		if not lots.take(x, z, 0.0, w / 2, d / 2, 3.0, 3.0): continue
		n += 1
		# the lawn stands 6 cm proud of the pavement, the paths 3 cm on top of it
		A.at(x, 0, z)
		A.box(w, 0.12, d, 0, 0, 0, 0x5f8a3a)
		A.box(w - 0.4, 0.03, 3.0, 0, 0.075, 0, 0xc8b89a)
		A.box(3.0, 0.03, d - 0.4, 0, 0.075, 0, 0xc8b89a)
		for _q in int(w * d / 180):
			var tx := x + (rnd() - 0.5) * (w - 6)
			var tz := z + (rnd() - 0.5) * (d - 6)
			if absf(tx - x) < 3.5 or absf(tz - z) < 3.5: continue
			var s := 0.75 + rnd() * 0.45
			trees.append(World.mtx(tx, 0.06, tz, rnd() * 6, s)); tc.append(Color(1, 1, 1).darkened(rnd() * 0.25))
		World.pavTaken.append([x, z, maxf(w, d) / 2])
	A.commit()
	World.inst(BKit.oakGeo(), BKit.vmat({"sway": 0.12, "swayBase": 3.0, "swaySpan": 6.0}), trees, tc, true)

## the Euromast: the shaft, the crow's nest at 96 m, the Space Tower on top and a red light
static func euromast() -> void:
	var s = World.clearSpot(40)
	if s == null: return
	for _try in 30:
		if s != null and not overRiver(s[0], s[1]) and absf(s[1] - RZ0) > 20 and absf(s[1] - RZ1) > 20 and lots.take(s[0], s[1], 0.0, 9, 9, 2.0, 2.0): break
		s = World.clearSpot(40)
		if s == null: return
	var A := BKit.Acc.new()
	A.at(s[0], 0, s[1], 0)
	A.cyl(3.0, 4.2, 96, 12, 0, 48, 0, 0xdcd8ce)
	A.cyl(9.0, 4.0, 3.0, 16, 0, 94.5, 0, 0xb9b5ab)
	A.cyl(9.0, 9.0, 3.4, 16, 0, 97.7, 0, 0x3a4652)
	A.cyl(7.4, 9.0, 1.2, 16, 0, 100.0, 0, 0xdcd8ce)
	A.cyl(5.5, 6.0, 4.0, 14, 0, 102.6, 0, 0xdcd8ce)
	A.cyl(1.1, 1.6, 78, 8, 0, 143.6, 0, 0xe8e4dc)
	A.cyl(2.6, 2.6, 2.4, 10, 0, 150, 0, 0xc8302a)
	A.commit()
	var bm := M(0x601010, {"emissive": 0x220000})
	World.beaconMats.append(bm)
	World.box(1.2, 1.2, 1.2, bm, s[0], 183.2, s[1], null, false)

## the harbour on the south bank: container gantry cranes on the quay, stacks of containers and a container ship
static func harbour() -> void:
	# a stretch of quay 260 m long that the road keeps 70 m away from
	var x0 := 1e9
	var x := Trk.BX0 - 100
	while x < Trk.BX1 - 160 and x0 > 1e8:
		var ok := true
		for k in 8:
			if Trk.distToTrack(x + k * 36, RZ0 - 34) < 72: ok = false
		if ok and lots.take(x + 130, RZ0 - 36, 0.0, 135, 32, 0.0, 0.0): x0 = x
		x += 40
	if x0 > 1e8: return
	var A := BKit.Acc.new()
	var cols := [0xc8302a, 0x1d4f9e, 0x2f8f5b, 0xf36f21, 0x8a8f96, 0xe8c21c]
	for k in 3:
		var cx := x0 + 40 + k * 84.0
		A.at(cx, 0, RZ0 - 14, 0)
		var blue := 0x1f5f9a if k % 2 else 0xd24a2a
		for a in [-9.0, 9.0]:
			for b in [-9.0, 9.0]:
				A.box(1.4, 44, 1.4, a, 22, b, blue)
			A.box(1.2, 1.2, 19.4, a, 30, 0, blue); A.box(1.2, 1.2, 19.4, a, 12, 0, blue)
		A.box(19.4, 1.4, 1.4, 0, 43.4, -9, blue); A.box(19.4, 1.4, 1.4, 0, 43.4, 9, blue)
		A.box(3.0, 2.2, 74, 0, 45.6, 22, blue)            # the boom, out over the water (north)
		A.box(1.0, 14, 1.0, 0, 53, -6, blue); A.box(0.5, 0.5, 46, 0, 52.4, 16, blue, 0, 0.3, 0)
		A.box(5, 4, 6, 0, 47, -9, 0xe8e4dc)
		A.box(3.4, 2.6, 4, 0, 43, 24, 0xe8e4dc)
		A.box(2.5, 2.6, 6.1, 0, 30, 24, World.pick(cols)); A.box(0.1, 11, 0.1, -0.9, 37, 24, 0x2a2a2e); A.box(0.1, 11, 0.1, 0.9, 37, 24, 0x2a2a2e)
	A.commit()
	var cm := []; var cc := []
	for k in 110:
		var cx := x0 + 8 + rnd() * 246
		var cz := RZ0 - 30 - floorf(rnd() * 8) * 3.2
		var n := 1 + int(floor(rnd() * 4))
		var gx := floorf(cx / 12.6) * 12.6
		for q in n:
			cm.append(World.mtx(gx, 1.3 + q * 2.6, cz, 0, 12.2, 2.6, 2.44)); cc.append(BKit.col(World.pick(cols)))
	# drop doubles (two stacks drawn on the same spot would flicker)
	var seen := {}
	var um := []; var uc := []
	for k in cm.size():
		var o: Vector3 = cm[k].origin
		var key := "%d,%d,%d" % [int(round(o.x * 10)), int(round(o.y * 10)), int(round(o.z * 10))]
		if seen.has(key): continue
		seen[key] = true
		um.append(cm[k]); uc.append(cc[k])
	World.inst(Geo.box(1, 1, 1), M(0xffffff), um, uc, true)
	# the ship at the quay
	var S := BKit.Acc.new()
	S.at(x0 + 124, -0.6, RZ0 + 16, 0)
	S.box(150, 9, 22, 0, 3.0, 0, 0x23364a); S.box(150.2, 1.6, 22.2, 0, 0.4, 0, 0x8a2a22)
	S.box(12, 16, 20, -62, 15, 0, 0xe8e4dc); S.box(5, 5, 6, -64, 25, 0, 0xc8302a)
	for a in 9:
		for b in 3:
			var hq := 1 + (a * 7 + b * 3) % 3
			for q in hq:
				S.box(12.2, 2.6, 6.2, -44 + a * 12.6, 8.8 + q * 2.6, (b - 1) * 6.6, cols[(a + b * 2 + q) % cols.size()])
	S.commit()

## the river: water taxis and barges; one barge and two taxis sail between the bridges
static func river() -> void:
	var zc := (RZ0 + RZ1) / 2
	for k in 5:
		var gx := -300 + k * 300 + rnd() * 80
		var gz := zc + (rnd() - .5) * 80
		var turn := PI / 2 + (rnd() - .5) * 0.3
		var g := Node3D.new()
		World.box(4, 1.6, 11, M(0xf2c200 if k % 2 else 0xecece8), 0, 0.9, 0, g)
		World.box(3.2, 1.8, 5, M(0x2b2f36), 0, 2.3, -1, g)
		if k == 1 or k == 2:
			# these two cross the river between the bridges
			World.add(AnimB.shuttle(g, Vector3(gx, -0.6, RZ1 - 16), Vector3(gx + 60, -0.6, RZ0 + 46), 7.0, rnd()))
		else:
			g.position = Vector3(gx, -0.6, gz)
			O3.rot(g, 0, turn, 0)
			World.add(g)
	# a barge under way between the bridges and one lying at anchor
	for k in 2:
		var g := Node3D.new()
		World.box(9, 2.2, 78, M(0x2a3a4a), 0, 0.7, 0, g)
		World.box(7.4, 1.2, 52, M(0x6a4a2e if k else 0x3f4a55), 0, 2.1, 6, g)
		World.box(8, 5, 8, M(0xe8e4dc), 0, 4.2, -30, g)
		World.box(3, 2, 3, M(0x2b2f36), 0, 7.6, -30, g)
		if k == 0:
			World.add(AnimB.shuttle(g, Vector3(-30, -0.6, zc + 22), Vector3(520, -0.6, zc + 30), 4.0, rnd()))
		else:
			g.position = Vector3(820, -0.6, zc - 30)
			O3.rot(g, 0, PI / 2 + 0.1, 0)
			World.add(g)

## fans behind the barrier at the start and on the outside of the two tightest bends on land
static func fans() -> void:
	var ppl := []
	for s in [-1.0, 1.0]:
		ppl.append_array(BKit.crowdRow(Trk.START_I + 3, 30, s * 10.5, 1.3, 2 if s > 0 else 1))
	var bl := BKit.bends(0.016)
	bl.sort_custom(func(a, b): return a.kmax > b.kmax)
	var n := 0
	for b in bl:
		if n >= 2 or Trk.HT[b.apex] > 0.6 or not land(b.apex): continue
		n += 1
		ppl.append_array(BKit.crowdRow(b.apex - 10, 20, -b.dir * 10.5, 1.2, 2))
	BKit.crowd(ppl)

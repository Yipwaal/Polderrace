class_name BuildLimburg
## Port of buildLimburg from polderrace-3d.html: the hills of South Limburg (terrain, see terrain.gd) with vineyards,
## marl-stone farmhouses, fruit trees and a church. Same numbers, same seeded random order (World.rnd) as the HTML game.

static func M(c: int, o: Dictionary = {}) -> LMat:
	return Mats.M(c, o)

static func rnd() -> float:
	return World.rnd.next()

static func hills(x: float, z: float) -> float:
	return 20 + 18 * sin(x / 260 + 0.4) * cos(z / 300 - 0.8) + 9 * sin((x + z) / 150) + 4 * cos((x * 0.8 - z) / 70)

static func build() -> void:
	var NS := Trk.NS
	var HT := Trk.HT
	var TF := Terrain.terrainFn(hills)
	Trk.terrain_fn = TF.fn()
	var size := 3400.0
	var seg := 272
	var pos := Terrain.planeXZ(size, seg)
	var cx := (Trk.BX0 + Trk.BX1) / 2
	var cz := (Trk.BZ0 + Trk.BZ1) / 2
	var cols := PackedColorArray()
	cols.resize(pos.size())
	var cg := MathX.col(0x7aa04a); var cf := MathX.col(0xa8a050); var cv := MathX.col(0x4f7a32)
	for k in pos.size():
		var x := pos[k].x + cx
		var z := pos[k].z + cz
		pos[k].y = TF.at(x, z)
		var f := sin(x / 70) * cos(z / 85)
		var tmp := cg
		if f > 0.5: tmp = tmp.lerp(cf, 0.6)
		elif f < -0.55: tmp = tmp.lerp(cv, 0.6)
		cols[k] = tmp
	Terrain.groundMesh(pos, cols, seg, cx, cz)
	var RH := Trk.ROAD_HALF
	var SH := Trk.SHOULDER
	World.ribbon(-RH, RH, World.roadMat(World.roadTexture("#58595b", [0.5], true, false, 0.3)), 10, 0.07)
	var verge := M(0x8aa65a)
	World.ribbon(-SH, -RH, verge, 8, 0.05); World.ribbon(RH, SH, verge, 8, 0.05)
	World.startLine()
	World.gates(Trk.TRK)
	var post := []
	var dd := 0.0
	while dd < Trk.TRACK_LEN:
		var i := int(round(dd / Trk.SPC)) % NS
		for s in [-1, 1]:
			var xz := Trk.onTrack(i, s * 10.8)
			post.append(World.mtx(xz[0], HT[i] + 0.5, xz[1]))
		dd += 10
	World.inst(Geo.box(0.16, 1, 0.16), M(0xf2f0ea), post, null, false)

	# vineyards: rows of vines on the slopes, with a post every third vine
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
				if TF.d < 16: continue
				vh.append(World.mtx(x, th + 0.7, z, ang, 0.5, 1.2, 2.6))
				if c % 3 == 0: vp.append(World.mtx(x, th + 0.8, z))
	World.inst(Geo.box(1, 1, 1), M(0x3f6a2a), vh, null, true)
	World.inst(Geo.box(0.1, 1.6, 0.1), M(0x6b4a2e), vp, null, false)

	# marl-stone farmhouses (one in three spots; the others get a fruit tree)
	var marl := M(0xe3cf8f); var hr := M(0x3b3530)
	var hb := []; var hrf := []; var ft := []
	for k in 70:
		var x := Trk.BX0 - 100 + rnd() * (Trk.BX1 - Trk.BX0 + 200)
		var z := Trk.BZ0 - 100 + rnd() * (Trk.BZ1 - Trk.BZ0 + 200)
		var th := TF.at(x, z)
		if TF.d < 22: continue
		if k % 3:
			ft.append(World.mtx(x, th + 2.6, z, 0, 2.2 + rnd())); continue
		var w := 6 + rnd() * 5
		var d := 7 + rnd() * 4
		var ry := rnd() * 6
		hb.append(World.mtx(x, th + 2.2, z, ry, w, 4.4, d))
		hrf.append(World.mtx(x, th + 4.4, z, ry, w * 1.05, 2.6, d * 1.05))
	World.inst(Geo.box(1, 1, 1), marl, hb, null, true)
	World.inst(Geo.cone(0.72, 1, 4), hr, hrf, null, true)
	World.inst(Geo.sphere(1, 7, 5), M(0x5f8a3a), ft, null, true)

	# the village church
	var ci := int(round(NS * 0.28))
	var cxz := Trk.onTrack(ci, -40)
	var g := O3.group(cxz[0], TF.at(cxz[0], cxz[1]), cxz[1])
	World.box(8, 9, 16, marl, 0, 4.5, 0, g); World.box(4, 20, 4, marl, 0, 10, 9, g)
	var sp := O3.mesh(Geo.cone(2.8, 9, 4), hr, 0, 24.5, 9, g)
	O3.rot(sp, 0, PI / 4, 0)
	World.add(g)

	TrackCommon.signs([["Valkenburg", "3"], ["Cauberg", "1"], ["Maastricht", "14"]], 11.5)

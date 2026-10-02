class_name CarKit
## TEMPORARY STUB (main session): box cars with real dimensions and wheel positions, so the gameplay port can run
## until the car module (G3) lands. The real file replaces this one completely (same API: buildCar, styleCar, tailMat, lampMat).

static var tailMat: LMat = Mats.M(0x6e0b0b, {"emissive": 0xc81d1d})
static var lampMat: LMat = Mats.M(0xf4f1e6, {"emissive": 0x807860})

static func _wheel(g: Node3D, x: float, y: float, z: float, r: float) -> Dictionary:
	var pivot := O3.group(x, y, z, g)
	var spin := O3.group(0, 0, 0, pivot)
	var tyre := O3.mesh(Geo.cylinder(r, r, 0.26, 14).rotate_z(PI / 2), Mats.M(0x1b1b1b), 0, 0, 0, spin, true)
	O3.mesh(Geo.box(0.27, r * 1.2, 0.12), Mats.M(0xa1a4a8), 0, 0, 0, spin)
	return {"pivot": pivot, "spin": spin, "r": r, "tyre": tyre}

static func buildCar(type: String, color: Color) -> Dictionary:
	var S: Dictionary = Cars.CAR_SPECS.get(type, Cars.CAR_SPECS.hatch)
	var g := Node3D.new()
	var paint := Mats.PM(0xffffff)
	paint.albedo_color = color
	var L: float = S.len
	var W: float = S.wid
	O3.mesh(Geo.box(W * 0.96, 0.55, L * 0.98), paint, 0, 0.62, S.off, g, true)
	O3.mesh(Geo.box(W * 0.8, 0.45, L * 0.45), Mats.M(0x1f2a33), 0, 1.1, S.off - L * 0.08, g, true)
	O3.mesh(Geo.box(0.5, 0.15, 0.06), tailMat, -W * 0.3, 0.75, S.off - L * 0.49, g)
	O3.mesh(Geo.box(0.5, 0.15, 0.06), tailMat, W * 0.3, 0.75, S.off - L * 0.49, g)
	O3.mesh(Geo.box(0.4, 0.12, 0.06), lampMat, -W * 0.3, 0.72, S.off + L * 0.49, g)
	O3.mesh(Geo.box(0.4, 0.12, 0.06), lampMat, W * 0.3, 0.72, S.off + L * 0.49, g)
	var wheels := []
	for w in S.wheels:
		wheels.append(_wheel(g, w[0], w[1], w[2], w[3]))
	return {"g": g, "wheels": wheels, "len": L, "wid": W, "rc": S.hitR, "off": S.off, "type": type, "beam": null, "paint": paint}

static func styleCar(_m: Dictionary, _id: String) -> void:
	pass

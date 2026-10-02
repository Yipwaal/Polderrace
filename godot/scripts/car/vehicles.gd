class_name Vehicles
## Port of the HTML game's traffic vehicles (end of the "cars" section): buildHatchTraffic, makeVan, makeTruck, makeTractor.
## Each returns a Dictionary like buildCar: g, wheels ({pivot, spin, r, w, style}), len, wid, rc, off, beam.
## (The JS objects of van and tractor have no `off`; here it is 0.0, which is what the JS gameplay reads for them: `off||0`.)
## makeTruck picks its colours with World.pick, i.e. the track's seeded random while a track is built (haven parks trucks).

static func M(c: int, o: Dictionary = {}) -> LMat:
	return Mats.M(c, o)

static func buildHatchTraffic(color) -> Dictionary:
	return CarKit.buildCar("city", color, true)

static func makeVan() -> Dictionary:
	var g := Node3D.new()
	var white := M(0xecece8)
	World.box(2.0, 2.1, 5.0, white, 0, 1.35, 0, g); World.box(1.9, 0.8, 0.1, CarKit.glassMat, 0, 1.9, 2.51, g, false); World.box(2.02, 0.25, 5.02, M(0x2f6db3), 0, 1.05, 0, g, false)
	World.box(0.14, 0.55, 0.06, CarKit.tailMat, -0.9, 1.1, -2.51, g, false); World.box(0.14, 0.55, 0.06, CarKit.tailMat, 0.9, 1.1, -2.51, g, false); World.box(0.5, 0.14, 0.05, CarKit.plateMat, 0, 0.55, -2.51, g, false)
	var wheels := []
	for xz in [[-0.92, 1.75], [0.92, 1.75], [-0.92, -1.75], [0.92, -1.75]]:
		wheels.append(CarKit.addWheel(g, xz[0], 0.4, xz[1], 0.4, 0.28, "steel", null))
	return {"g": g, "wheels": wheels, "len": 5.1, "wid": 2.05, "rc": 0.15, "off": 0.0, "beam": CarKit.addBeam(g, 2.5, 2.05)}

static func makeTruck() -> Dictionary:
	var g := Node3D.new()
	var cab := M(World.pick([0xd62a2a, 0xecece8, 0x2f6db3, 0x2f8f5b]))
	var cont := M(World.pick([0xc4452a, 0x1d4f9e, 0x3f7d3a, 0xd9a21b, 0x8a8f96, 0xecece8]))
	World.box(2.4, 2.7, 2.3, cab, 0, 1.85, 5.2, g); World.box(2.2, 0.9, 0.1, CarKit.glassMat, 0, 2.5, 6.36, g, false); World.box(0.9, 0.5, 0.06, CarKit.lampMat, 0, 0.9, 6.36, g, false)
	World.box(1.5, 0.35, 12.6, CarKit.blk, 0, 0.85, -0.6, g); World.box(2.44, 2.6, 10.4, cont, 0, 2.45, -1.6, g)
	World.box(0.2, 0.2, 0.06, CarKit.tailMat, -1.0, 0.9, -6.83, g, false); World.box(0.2, 0.2, 0.06, CarKit.tailMat, 1.0, 0.9, -6.83, g, false); World.box(0.5, 0.14, 0.05, CarKit.plateMat, 0, 0.75, -6.83, g, false)
	var wheels := []
	for xz in [[-1.05, 5.1], [1.05, 5.1], [-1.05, -4.8], [1.05, -4.8], [-1.05, -5.9], [1.05, -5.9]]:
		wheels.append(CarKit.addWheel(g, xz[0], 0.5, xz[1], 0.5, 0.35, "steel", null))
	return {"g": g, "wheels": wheels, "len": 13.6, "wid": 2.5, "rc": 0.12, "off": -0.2, "beam": CarKit.addBeam(g, 6.4, 2.5)}

static func makeTractor() -> Dictionary:
	var g := Node3D.new()
	var green := M(0x3f7d3a)
	World.box(1.1, 1.0, 2.4, green, 0, 1.2, 0.6, g); World.box(0.9, 0.3, 0.1, M(0xe8c21c), 0, 1.35, 1.81, g, false)
	for xz in [[-0.72, -0.25], [0.72, -0.25], [-0.72, -1.4], [0.72, -1.4]]:
		World.box(0.1, 1.9, 0.1, CarKit.blk, xz[0], 2.35, xz[1], g)
	World.box(1.7, 0.14, 1.4, green, 0, 3.32, -0.82, g)
	O3.mesh(Geo.box(1.4, 1.7, 1.1), M(0xbad4e0, {"transparent": true, "opacity": 0.45}), 0, 2.35, -0.82, g)
	O3.mesh(Geo.sphere(0.16, 8, 6), M(0xff9a1a, {"emissive": 0xff7a00}), 0, 3.5, -0.82, g)
	World.box(0.9, 0.14, 0.06, CarKit.plateMat, 0, 1.0, -1.6, g, false); World.box(0.8, 0.5, 0.8, green, 0, 1.1, -1.1, g)
	var wheels := [CarKit.addWheel(g, -0.8, 0.5, 1.35, 0.5, 0.3, "steel", null), CarKit.addWheel(g, 0.8, 0.5, 1.35, 0.5, 0.3, "steel", null),
		CarKit.addWheel(g, -1.05, 0.95, -0.9, 0.95, 0.5, "steel", null), CarKit.addWheel(g, 1.05, 0.95, -0.9, 0.95, 0.5, "steel", null)]
	return {"g": g, "wheels": wheels, "len": 3.9, "wid": 2.6, "rc": 0.2, "off": 0.0, "beam": CarKit.addBeam(g, 1.9, 2.2)}

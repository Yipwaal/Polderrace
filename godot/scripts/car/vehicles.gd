class_name Vehicles
## TEMPORARY STUB (main session): traffic vehicles as boxes until the car module (G3) lands (same API as the real file).

static func _box_vehicle(len: float, wid: float, h: float, col: int, rc: float, off := 0.0) -> Dictionary:
	var g := Node3D.new()
	O3.mesh(Geo.box(wid, h, len), Mats.M(col), 0, h / 2 + 0.35, off, g, true)
	var wheels := []
	for z in [len * 0.32, -len * 0.32]:
		for x in [-wid * 0.42, wid * 0.42]:
			wheels.append(CarKit._wheel(g, x, 0.4, z + off, 0.4))
	return {"g": g, "wheels": wheels, "len": len, "wid": wid, "rc": rc, "off": off, "beam": null}

static func buildHatchTraffic(col: int) -> Dictionary:
	return _box_vehicle(4.1, 1.8, 1.2, col, 0.3)

static func makeVan() -> Dictionary:
	return _box_vehicle(5.1, 2.05, 2.0, 0xe9e9e4, 0.15)

static func makeTruck() -> Dictionary:
	return _box_vehicle(13.6, 2.5, 3.4, 0x2f6db3, 0.12, -0.2)

static func makeTractor() -> Dictionary:
	return _box_vehicle(3.9, 2.6, 2.2, 0x2f8f5b, 0.2)

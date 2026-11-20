extends RefCounted
## Handling measurements (no checks): the numbers behind the before/after tables of the handling work.
##   TAG=before MEASURE=basic,corner,slide,track,laps,race godot --headless --path godot res://tests/runner.tscn -- measure
## writes tests/.out/handling_<TAG>.json; tools/handling_table.py prints two of those side by side.
## Parts: basic (acceleration, top speed, braking), corner (skid pad, steering response), slide (lift, brake, handbrake,
## power, recovery), track (verges, walls, hills), laps (clean laps per track and car), race (the tidy driver against bots).

var H
var out := {}

func rec(key: String, d: Dictionary) -> void:
	var o := {}
	for k in d:
		o[k] = snappedf(d[k], 0.001) if d[k] is float else d[k]
	out[key] = o
	print("M ", key, " ", JSON.stringify(o))

func run(host: Node) -> TestReport:
	var r := TestReport.new("rijgedrag meten")
	H = load("res://tests/handling_lib.gd").new()
	H.setup(host)
	var parts := OS.get_environment("MEASURE").split(",", false)
	if parts.is_empty(): parts = PackedStringArray(["basic", "corner", "slide", "track"])
	var cars := OS.get_environment("CARS").split(",", false)
	if cars.is_empty(): cars = PackedStringArray(["hatch", "gt", "super"])
	var tag := OS.get_environment("TAG")
	if tag == "": tag = "now"
	var path := ProjectSettings.globalize_path("res://tests/.out/handling_%s.json" % tag)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if FileAccess.file_exists(path):
		var old = JSON.parse_string(FileAccess.get_file_as_string(path))
		if old is Dictionary: out = old
	for car in cars:
		if "basic" in parts:
			rec("accel/" + car, H.accel(car))
			for kmh in [100, 200]:
				rec("brake%d/%s" % [kmh, car], H.braking(car, kmh))
				rec("brake%d-rain/%s" % [kmh, car], H.braking(car, kmh, "rain"))
			rec("coast150/" + car, H.coasting(car, 150))
		if "corner" in parts:
			for kmh in [50, 100, 150, 200]:
				rec("skid%d/%s" % [kmh, car], H.skidpad(car, kmh))
			rec("skid100-keys/" + car, H.skidpad(car, 100, 1.0, "dry", true))
			rec("skid100-half/" + car, H.skidpad(car, 100, 0.5))
			rec("skid100-rain/" + car, H.skidpad(car, 100, 1.0, "rain"))
			for R in [20, 40, 80, 160]:
				rec("corner%d/%s" % [R, car], H.max_corner(car, R))
			rec("corner40-rain/" + car, H.max_corner(car, 40, "rain"))
			for kmh in [100, 200]:
				rec("step%d/%s" % [kmh, car], H.step_steer(car, kmh))
				rec("step%d-keys/%s" % [kmh, car], H.step_steer(car, kmh, true))
		if "slide" in parts:
			rec("lift120/" + car, H.mid_corner(car, 120, 0.9, 0.0))
			rec("brake120/" + car, H.mid_corner(car, 120, 0.9, 1.0))
			rec("brake120-half/" + car, H.mid_corner(car, 120, 0.9, 0.5))
			rec("brake120-rain/" + car, H.mid_corner(car, 120, 0.9, 1.0, "rain"))
			rec("power40/" + car, H.power_exit(car, 40))
			rec("power60/" + car, H.power_exit(car, 60))
			rec("power60-keys/" + car, H.power_exit(car, 60, true))
			rec("hand80/" + car, H.handbrake(car, 80))
			rec("hand120/" + car, H.handbrake(car, 120))
			rec("hand80-nocounter/" + car, H.handbrake(car, 80, 0.7, false))
			rec("slide30/" + car, H.slide_recover(car, 100, 30))
			rec("slide30-counter/" + car, H.slide_recover(car, 100, 30, true))
			rec("slide80/" + car, H.slide_recover(car, 100, 80))
		if "track" in parts:
			rec("verge-polder/" + car, H.surface("polder", car, 8.4, 150))
			rec("grass-circuit/" + car, H.surface("circuit", car, 10.5, 150))
			rec("gravel-circuit/" + car, H.surface("circuit", car, 15.0, 150))
			rec("verge-limburg/" + car, H.surface("limburg", car, 8.0, 150))
			rec("road-polder/" + car, H.surface("polder", car, 0.0, 150))
			for deg in [5, 15, 45, 80]:
				rec("wall%d/%s" % [deg, car], H.wall("haven", car, deg, 120))
			rec("wall15-fast/" + car, H.wall("haven", car, 15, 220))
			rec("wall15-dorp/" + car, H.wall("dorp", car, 15, 90))
		if "laps" in parts:
			var only := OS.get_environment("TRACKS").split(",", false)
			for tr in TrackLoader.ported():
				if not only.is_empty() and not tr in only: continue
				var b: Dictionary = H.best_clean(tr, car)
				if b.is_empty(): b = {"lap": -1.0}
				rec("lap-%s/%s" % [tr, car], b)
		if "wet" in parts:
			for tr in ["circuit", "dorp"]:
				var b: Dictionary = H.best_clean(tr, car, "rain")
				if b.is_empty(): b = {"lap": -1.0}
				rec("lap-%s-rain/%s" % [tr, car], b)
		if "race" in parts:
			for tr in ["circuit", "polder", "dorp", "veluwe"]:
				for diff in ["easy", "normal", "hard", "extreme"]:
					rec("race-%s-%s/%s" % [tr, diff, car], H.race(tr, car, diff, 5, 2, 0.94))
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(out, "  "))
		f.close()
	H.done()
	r.check(true, "gemeten", path)
	return r

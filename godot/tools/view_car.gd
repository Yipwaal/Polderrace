extends Node3D
## Car viewer. Two modes:
##
## 1. One picture (tools/compare_car.py): the car alone with the light and sky of a track.
##    godot --path godot res://tools/view_car.tscn -- car=gt color=#d62a2a up={json} time=day weather=dry view=ex,ey,ez,lx,ly,lz out=/abs/path.png
##      car: a model id, or traffic:hatch / traffic:van / traffic:truck / traffic:tractor; up: looks/tuning for styleCar
##
## 2. Turntable (tools/view_car.py makes contact sheets of it): every car on a piece of road in the real game light, from fixed
##    angles, by day and by night with the lamps on, stock and tuned.
##    xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver opengl3 --resolution 640x400 res://tools/view_car.tscn -- \
##      sheet=1 cars=gt,hatch,traffic:van sets=day,night,tune,duck colors=#d62a2a out=/abs/dir
##    sets (one row of tiles each; see SETS): day, night, dusk, rain, tune, duck, num, center, colors, finishes
##    files: <out>/<car>__<set>__<view>.png

const VIEWS := {
	# name: [ex, ey, ez, lx, ly, lz, fov]; in units of k (L / 4.6 for long vehicles), z offsets from the car's ends
	"f34": [3.3, 1.55, 3.3, 0, 0.5, 0.1, 36],
	"side": [7.4, 0.95, 0, 0, 0.6, 0, 30],
	"r34": [-3.3, 1.6, -3.4, 0, 0.5, -0.1, 36],
	"front": [0, 0.95, 5.0, 0, 0.6, 0, 30],
	"rear": [0, 1.0, -5.0, 0, 0.6, 0, 30],
	"top": [0.001, 9.4, 0.02, 0, 0, 0, 30],
	"lowf": [1.9, 0.38, 3.6, 0, 0.55, 0, 36],
	"lowr": [-1.9, 0.42, -3.7, 0, 0.55, 0, 36],
	"chase": [0, 2.55, -4.9, 0, 1.0, 5.0, 58],
	"high": [-2.6, 3.6, 2.2, 0, 0.5, 0, 36],
}
## what each set shows: env, looks (styleCar), views
const SETS := {
	"day": {"views": ["f34", "side", "r34", "top", "front", "rear", "lowf", "lowr", "chase", "high", "wheel", "nose", "tail", "cabin"]},
	"night": {"time": "night", "views": ["f34", "r34", "brake", "chase"]},
	"dusk": {"time": "dusk", "views": ["f34", "r34"]},
	"rain": {"weather": "rain", "views": ["f34", "r34"]},
	"num": {"up": {"num": 7}, "views": ["f34", "side", "high"]},
	"tune": {"up": {"wing": "gt", "exhaust": "sport", "rimStyle": "spoke", "rim": "gold", "stripe": "white"}, "views": ["f34", "side", "r34", "rear", "wheel"]},
	"duck": {"up": {"wing": "duck", "exhaust": "dual", "rimStyle": "dish", "rim": "black", "stripe": "none", "num": 12}, "views": ["f34", "side", "r34", "high", "wheel"]},
	"center": {"up": {"exhaust": "center", "stripe": "yellow", "num": 3}, "views": ["r34", "rear", "high"]},
	"colors": {"colors": true, "views": ["f34"]},
	"finishes": {"finishes": true, "views": ["f34", "r34"]},
}

var env: Env
var cam: Camera3D
var ground: MeshInstance3D

func _ready() -> void:
	get_tree().create_timer(1500, true, false, true).timeout.connect(func(): print("ERROR view timeout"); get_tree().quit(1))
	var a := {"car": "gt", "color": "#d62a2a", "up": "", "track": "polder", "time": "day", "weather": "dry", "view": "4,1.6,5,0,0.6,0", "out": "/tmp/car.png", "fov": "40", "near": "0.1",
		"sheet": "", "cars": "", "sets": "day,night,tune,duck", "colors": "#d62a2a"}
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2: a[kv[0]] = kv[1]
	env = Env.new()
	add_child(env)
	World.root = Node3D.new()
	World.root.name = "World"
	add_child(World.root)
	# the track only for its fog and cloud ring, like the HTML scene the car stands in (its world is hidden there)
	Trk.compute_track(a.track, "fwd")
	env.place_clouds()
	cam = Camera3D.new()
	cam.near = float(a.near); cam.far = 3000
	add_child(cam)
	cam.current = true
	if a.sheet != "":
		await _sheets(a)
		get_tree().quit()
		return
	_env(a.time, a.weather)
	var m := _build(a.car, a.color, JSON.parse_string(a.up) if a.up != "" else null)
	add_child(m.g)
	cam.fov = float(a.fov)
	var v := Array(a.view.split(",")).map(func(x): return float(x))
	cam.position = Vector3(v[0], v[1], v[2])
	cam.look_at(Vector3(v[3], v[4], v[5]))
	await _shoot(a.out)
	get_tree().quit()

func _env(t: String, w: String) -> void:
	env.time = t; env.weather = w
	env.apply(t, w, true)

func _build(car: String, color: String, up) -> Dictionary:
	var m: Dictionary
	if car.begins_with("traffic:"):
		World.rnd = Rng.seeded(5)
		match car.substr(8):
			"hatch": m = Vehicles.buildHatchTraffic(Color(color))
			"van": m = Vehicles.makeVan()
			"truck": m = Vehicles.makeTruck()
			_: m = Vehicles.makeTractor()
		World.rnd = Rng.random()
	else:
		m = CarKit.buildCar(car, Color(color))
		if up != null:
			CarKit.styleCar(m, up)
	return m

func _shoot(path: String) -> void:
	env.update(0.0, cam)
	await Canvas2D.flush(self)
	for _i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)

func _ground() -> void:
	# a piece of road under the car: asphalt that takes shadows, with a white line to see the stance and the scale
	var asphalt := Mats.M(0x4a4d52, {"receiveShadow": true})
	ground = O3.mesh(Geo.plane(400, 400).rotate_x(-PI / 2), asphalt, 0, 0, 0, self)
	var line := Mats.M(0xe8e8e2, {"receiveShadow": true})
	O3.mesh(Geo.plane(0.15, 400).rotate_x(-PI / 2), line, -3.2, 0.02, 0, self)
	O3.mesh(Geo.plane(0.15, 400).rotate_x(-PI / 2), line, 3.2, 0.02, 0, self)

## camera for a view of car m: [pos, look, fov]
func _view(name: String, m: Dictionary) -> Array:
	var L: float = m.len
	var W: float = m.wid
	var off: float = m.get("off", 0.0)
	var k := maxf(1.0, L / 4.6)
	var zf := off + L / 2
	var zr := off - L / 2
	var wz: float = m.wheels[0].pivot.position.z if not m.wheels.is_empty() else L * 0.3
	var wr: float = m.wheels[0].r if not m.wheels.is_empty() else 0.35
	match name:
		"wheel": return [Vector3(W / 2 + 1.25, 0.55, wz + 0.75), Vector3(W / 2 - 0.15, wr, wz), 34]
		"nose": return [Vector3(1.25, 0.95, zf + 1.5), Vector3(0.35, 0.55, zf - 0.1), 36]
		"tail", "brake": return [Vector3(-1.25, 1.0, zr - 1.5), Vector3(-0.35, 0.6, zr + 0.1), 36]
		"cabin": return [Vector3(2.0, 1.75, 1.3), Vector3(0, 0.95, -0.35), 36]
	var v: Array = VIEWS[name]
	var ez: float = v[2] * k
	if name in ["f34", "front", "lowf"]: ez += L / 2 - 2.3 * k + off
	if name in ["r34", "rear", "lowr"]: ez -= L / 2 - 2.3 * k - off
	if name == "chase": ez += off
	return [Vector3(v[0] * k, v[1] * k, ez), Vector3(v[3], v[4] * k, v[5] * k + (off if name != "chase" else 0.0)), v[6]]

func _sheets(a: Dictionary) -> void:
	_ground()
	var out: String = a.out
	DirAccess.make_dir_recursive_absolute(out)
	var cars: Array = Array(a.cars.split(",")) if a.cars != "" else Cars.CARS.keys() + ["traffic:hatch", "traffic:van", "traffic:truck", "traffic:tractor"]
	var has_finish := ResourceLoader.exists("res://scripts/car/car_paint.gd")
	for car in cars:
		var traffic: bool = car.begins_with("traffic:")
		for sname in a.sets.split(","):
			if not SETS.has(sname): continue
			var st: Dictionary = SETS[sname]
			if traffic and (st.has("up") or st.has("colors") or st.has("finishes")): continue
			_env(st.get("time", "day"), st.get("weather", "dry"))
			var looks: Array = [[a.colors.split(",")[0], st.get("up", null), ""]]
			if st.has("colors"):
				looks = []
				for c in Cars.COLORS: looks.append([c, null, "_" + c.substr(1)])
			if st.has("finishes"):
				looks = []
				if has_finish:
					for f in ["gloss", "metallic", "matte", "satin", "pearl", "chrome"]:
						looks.append([a.colors.split(",")[0], {"finish": f}, "_" + f])
			for lk in looks:
				var m := _build(car, lk[0], lk[1])
				add_child(m.g)
				if m.get("beam") != null: m.beam.visible = CarKit.lampsOn
				for vn in st.views:
					if vn == "chase" and m.wheels.size() > 0: pass
					var braking: bool = vn == "brake"
					if braking: pass   # TODO CarKit.setBrake(m, braking)
					var v := _view(vn, m)
					cam.fov = v[2]
					cam.position = v[0]
					cam.look_at(v[1], Vector3.UP if absf(v[0].x) + absf(v[0].z - v[1].z) > 0.1 else Vector3.BACK)
					await _shoot("%s/%s__%s__%s%s.png" % [out, car.replace(":", "-"), sname, vn, lk[2]])
				m.g.free()

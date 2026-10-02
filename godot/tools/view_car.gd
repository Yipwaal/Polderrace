extends Node3D
## Renders one car (or traffic vehicle) alone, with the light and sky of a track, and saves it as PNG (for comparing with
## the HTML game, see tools/compare_car.py).
## godot --path godot res://tools/view_car.tscn -- car=gt color=#d62a2a up={json} time=day weather=dry view=ex,ey,ez,lx,ly,lz out=/abs/path.png
##   car: a model id, or traffic:hatch / traffic:van / traffic:truck / traffic:tractor; up: looks/tuning for styleCar

func _ready() -> void:
	get_tree().create_timer(600, true, false, true).timeout.connect(func(): print("ERROR view timeout"); get_tree().quit(1))
	var a := {"car": "gt", "color": "#d62a2a", "up": "", "track": "polder", "time": "day", "weather": "dry", "view": "4,1.6,5,0,0.6,0", "out": "/tmp/car.png", "fov": "40", "near": "0.1"}
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2: a[kv[0]] = kv[1]
	var env := Env.new()
	add_child(env)
	World.root = Node3D.new()
	World.root.name = "World"
	add_child(World.root)
	# the track only for its fog and cloud ring, like the HTML scene the car stands in (its world is hidden there)
	Trk.compute_track(a.track, "fwd")
	env.place_clouds()
	env.time = a.time; env.weather = a.weather
	env.apply(a.time, a.weather, true)
	var m: Dictionary
	var car: String = a.car
	if car.begins_with("traffic:"):
		World.rnd = Rng.seeded(5)
		match car.substr(8):
			"hatch": m = Vehicles.buildHatchTraffic(Color(a.color))
			"van": m = Vehicles.makeVan()
			"truck": m = Vehicles.makeTruck()
			_: m = Vehicles.makeTractor()
		World.rnd = Rng.random()
	else:
		m = CarKit.buildCar(car, Color(a.color))
		if a.up != "":
			CarKit.styleCar(m, JSON.parse_string(a.up))
	add_child(m.g)
	var cam := Camera3D.new()
	cam.fov = float(a.fov); cam.near = float(a.near); cam.far = 3000
	add_child(cam)
	var v := Array(a.view.split(",")).map(func(x): return float(x))
	cam.position = Vector3(v[0], v[1], v[2])
	cam.look_at(Vector3(v[3], v[4], v[5]))
	cam.current = true
	env.update(0.0, cam)
	await Canvas2D.flush(self)
	for _i in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(a.out)
	print("saved ", a.out)
	get_tree().quit()

extends Node3D
## Camera tour of a track: a series of views every N metres along the lap, saved as numbered PNGs, so a whole track can
## be reviewed from a handful of contact sheets (tools/tour.py runs this under xvfb and composes the sheets).
##
##   godot --path godot --rendering-driver opengl3 --resolution 960x540 res://tools/tour.tscn -- track=polder dir=fwd \
##       time=day weather=dry step=150 from=0 to=-1 views=drive,high,left,right,over out=/abs/dir
##
## Views at every stop (s = distance along the centre line from sample 0; the start line is at 12 m):
##   drive  the chase camera of the game with the car at s: 6 m behind and 2.4 m up, looking 8 m ahead
##   high   11 m up and 18 m back, looking down the road (how a corner reads, what stands beside it)
##   left / right   from the middle of the road at eye height, square to the road
##   back   the drive view looking backwards (what the mirror and the other direction see)
##   over   five overviews of the whole track without fog: from straight above and from four corners
## Zooming in:
##   from=1200 to=1500 step=25         part of the lap, more stops
##   lat=3.5                           the camera that far right of the centre line (drive, high, left, right)
##   cam=ex,ey,ez,lx,ly,lz[;...]       free camera positions (world coordinates), saved as cam_<n>.png
##   spot=s,lat[;...]                  two looks at the point s metres along the lap, lat metres right of the centre
##                                     line (what the tests report), from the road before and after it: spot_<n>a/b.png
##   car=hatch                         a car on the road 22 m past every stop (scale); night=0 turns the headlight off
## At dusk, at night, in rain and fog the drive, high and back views have the player's headlight (as in the game).

var env: Env
var cam: Camera3D
var head: SpotLight3D
var out := ""
var scale_car: Node3D

func _ready() -> void:
	get_tree().create_timer(3000, true, false, true).timeout.connect(func(): print("ERROR tour timeout"); get_tree().quit(1))
	var a := {"track": "polder", "dir": "fwd", "time": "day", "weather": "dry", "step": "150", "from": "0", "to": "-1", "views": "drive,high,left,right,over",
		"out": "/tmp/tour", "cam": "", "spot": "", "fov": "62", "lat": "0", "car": "", "night": "1"}
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2: a[kv[0]] = kv[1]
	out = a.out
	DirAccess.make_dir_recursive_absolute(out)
	env = Env.new()
	add_child(env)
	World.root = Node3D.new()
	World.root.name = "World"
	add_child(World.root)
	env.time = a.time; env.weather = a.weather
	TrackLoader.load_track(a.track, a.dir)
	cam = Camera3D.new()
	cam.near = 0.5; cam.far = 3000; cam.fov = float(a.fov)
	add_child(cam)
	cam.current = true
	env.apply(a.time, a.weather, true)
	# the player's headlight (Fx.headL): JS SpotLight(0xfff2d0, 0, 95, 0.5, 0.45, 1), 2.4 at night, 1.2 with lamps on
	head = SpotLight3D.new()
	head.light_color = MathX.col(0xfff2d0)
	head.spot_range = 95
	head.spot_angle = rad_to_deg(0.5)
	head.spot_angle_attenuation = 1.6
	head.spot_attenuation = 0.0
	head.shadow_enabled = false
	head.light_energy = 2.4 if a.time == "night" else 1.2
	head.visible = false
	add_child(head)
	var lamps: bool = env.lamps_on and a.night != "0"
	if a.car != "":
		scale_car = CarKit.buildCar(a.car, Color("#d62a2a")).g
		add_child(scale_car)
	await Canvas2D.flush(self)
	for _i in 3:
		await RenderingServer.frame_post_draw

	var L := Trk.TRACK_LEN
	var views: Array = Array(a.views.split(",", false))
	var s0 := float(a.from)
	var s1 := float(a.to) if float(a.to) >= 0 else L - 1.0
	var step := maxf(1.0, float(a.step))
	var lat := float(a.lat)
	var stops := []
	if a.cam == "" and a.spot == "":
		var s := s0
		while s <= s1 + 0.01:
			stops.append(s); s += step
	print("TOUR len=%.0f spc=%.3f ns=%d start=%.0f stops=%d" % [L, Trk.SPC, Trk.NS, Trk.S_START, stops.size()])
	for s in stops:
		if scale_car != null:
			var c := at(s + 22, Trk.LANES[-1], 0)
			var c2 := at(s + 23, Trk.LANES[-1], 0)
			scale_car.position = c
			scale_car.rotation.y = atan2(c2.x - c.x, c2.z - c.z)
		for v in views:
			var name := "%s_%05d.png" % [v, int(round(s))]
			match v:
				"drive": await shot(at(s - 6, lat, 2.4), at(s + 8, lat, 1.05), 62, name, s if lamps else -1.0)
				"back": await shot(at(s + 6, lat, 2.4), at(s - 8, lat, 1.05), 62, name, -1.0)
				"high": await shot(at(s - 18, lat, 11), at(s + 45, lat, 0), 62, name, s if lamps else -1.0)
				"left": await shot(at(s, lat, 1.7), at(s, lat - 30, 4.5), 80, name, -1.0)
				"right": await shot(at(s, lat, 1.7), at(s, lat + 30, 4.5), 80, name, -1.0)
	if views.has("over") and a.cam == "" and a.spot == "":
		# the whole track without fog: straight down and from four corners
		RenderingServer.global_shader_parameter_set("pr_fog_range", Vector4(20000, 40000, 0, 0))
		var cx := (Trk.BX0 + Trk.BX1) / 2.0; var cz := (Trk.BZ0 + Trk.BZ1) / 2.0
		var ex := (Trk.BX1 - Trk.BX0) / 2.0 - 250; var ez := (Trk.BZ1 - Trk.BZ0) / 2.0 - 250
		var hgt := maxf(ex / (16.0 / 9.0), ez) / tan(deg_to_rad(31)) * 1.02
		cam.far = 6000
		await shot(Vector3(cx, hgt, cz + 1), Vector3(cx, 0, cz), 62, "over_0.png", -1.0)
		var k := 1
		for d in [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var r := Vector2(ex, ez).length()
			await shot(Vector3(cx + d.x * r * 0.72, r * 0.42, cz + d.y * r * 0.72), Vector3(cx, -r * 0.12, cz), 62, "over_%d.png" % k, -1.0)
			k += 1
		cam.far = 3000
		RenderingServer.global_shader_parameter_set("pr_fog_range", Vector4(env.fog_near, env.fog_far, 0, 0))
	var n := 0
	for c in a.cam.split(";", false):
		var v := Array(c.split(",")).map(func(x): return float(x))
		if v.size() >= 6:
			await shot(Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5]), float(a.fov), "cam_%d.png" % n, -1.0)
			n += 1
	n = 0
	for c in a.spot.split(";", false):
		var v := Array(c.split(",")).map(func(x): return float(x))
		var s: float = v[0]
		var sl: float = v[1] if v.size() > 1 else 0.0
		var side := clampf(sl * 0.4, -Trk.ROAD_HALF + 1, Trk.ROAD_HALF - 1)
		await shot(at(s - 16, side, 3.2), at(s, sl, 0.8), float(a.fov), "spot_%da.png" % n, -1.0)
		await shot(at(s + 16, side, 3.2), at(s, sl, 0.8), float(a.fov), "spot_%db.png" % n, -1.0)
		n += 1
	get_tree().quit()

## world point at distance s along the lap, lat metres right of the centre line, up metres above the road there
func at(s: float, lat: float, up: float) -> Vector3:
	var t := Trk.trackAt(s)
	var h: float = Trk.HT[t.i] + (Trk.HT[t.j] - Trk.HT[t.i]) * t.t
	return Vector3(t.px + t.rx * lat, h + up, t.pz + t.rz * lat)

func shot(eye: Vector3, look: Vector3, fov: float, name: String, light_s: float) -> void:
	cam.fov = fov
	cam.position = eye
	cam.look_at(look)
	head.visible = light_s >= 0
	if light_s >= 0:
		var p := at(light_s + 1.8, 0, 0.9)
		head.look_at_from_position(p, at(light_s + 30, 0, 0), Vector3.UP)
	env.update(0.0, cam)
	for _i in 2:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name))
	print("saved ", name)

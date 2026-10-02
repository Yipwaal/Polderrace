extends Node3D
## Renders one fixed view of a track and saves it as PNG (for comparing with the HTML game, see tools/compare.py).
## godot --path godot res://tools/view.tscn -- track=polder dir=fwd time=day weather=dry view=ex,ey,ez,lx,ly,lz out=/abs/path.png

func _ready() -> void:
	get_tree().create_timer(600, true, false, true).timeout.connect(func(): print("ERROR view timeout"); get_tree().quit(1))
	var a := {"track": "polder", "dir": "fwd", "time": "day", "weather": "dry", "view": "0,30,0,100,0,100", "out": "/tmp/view.png", "fov": "62"}
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2: a[kv[0]] = kv[1]
	var env := Env.new()
	add_child(env)
	World.root = Node3D.new()
	World.root.name = "World"
	add_child(World.root)
	env.time = a.time; env.weather = a.weather
	var t0 := Time.get_ticks_msec()
	TrackLoader.load_track(a.track, a.dir)
	print("build ms ", Time.get_ticks_msec() - t0)
	var cam := Camera3D.new()
	cam.fov = float(a.fov); cam.near = 0.5; cam.far = 3000
	add_child(cam)
	var v := Array(a.view.split(",")).map(func(x): return float(x))
	cam.position = Vector3(v[0], v[1], v[2])
	cam.look_at(Vector3(v[3], v[4], v[5]))
	cam.current = true
	env.apply(a.time, a.weather, true)
	env.update(0.0, cam)

	t0 = Time.get_ticks_msec()
	await Canvas2D.flush(self)
	print("canvas ms ", Time.get_ticks_msec() - t0)
	for _i in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(a.out)
	print("saved ", a.out)
	get_tree().quit()

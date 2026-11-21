extends Node
## Bug hunt: the replay's trackside camera (Rep.trackCam) at points round every track, looking at the road where the
## car would be: xvfb-run -a -s "-screen 0 960x540x24" godot --path godot --rendering-driver opengl3 --resolution 960x540 \
##   res://tools/hunt_cams.tscn -- tracks=dorp,grachten points=6 out=/abs/dir

func _ready() -> void:
	var a := {"tracks": "all", "points": "6", "out": "/tmp"}
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2: a[kv[0]] = kv[1]
	G.use_store("user://hunt-cams.json", {})
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	while Game.state != "menu" or Game.car == null: await get_tree().process_frame
	Menu.hideAll()
	var ids: Array = TrackDefs.TRACKS.keys() if a.tracks == "all" else Array(a.tracks.split(","))
	Game.set_process(false)
	for id in ids:
		G.settings.dir = "fwd"
		await main.load_track(id)
		Env.me.apply("day", "dry", true)
		var n := int(a.points)
		for k in n:
			var j := int(float(k) / n * Trk.NS)
			var sd := 1.0 if k % 2 == 0 else -1.0
			var c: Vector3 = Rep.trackCam(j, sd)
			var q := (j + 10) % Trk.NS
			var tgt := Vector3(Trk.P[q].x, Trk.HT[q] + 0.8, Trk.P[q].z)
			Game.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			Game.camera.position = c
			Game.camera.look_at(tgt, Vector3.UP)
			Game.camera.fov = 40
			Env.me.update(0.0, Game.camera)
			for _i in 3: await RenderingServer.frame_post_draw
			var p := "%s/cam_%s_%d.png" % [a.out, id, k]
			get_viewport().get_texture().get_image().save_png(p)
			print("saved ", p)
	get_tree().quit()

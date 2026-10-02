extends Node
## Screenshots of a race in the real game scene (HUD included): godot --path godot --rendering-driver opengl3 res://tools/shot_race.tscn -- \
##   track=polder mode=race bots=5 car=gt laps=2 time=day weather=dry at=4,15,30 out=/abs/dir
## The autopilot of the tests drives (tests/test_laps.gd).

func _ready() -> void:
	get_tree().create_timer(900, true, false, true).timeout.connect(func(): print("ERROR timeout"); get_tree().quit(1))
	var a := {"track": "polder", "mode": "race", "bots": "5", "car": "gt", "laps": "2", "time": "day", "weather": "dry", "at": "4,15,30", "out": "/tmp", "dir": "fwd"}
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2: a[kv[0]] = kv[1]
	var S := G.settings
	S.track = a.track; S.mode = a.mode; S.bots = int(a.bots); S.car = a.car; S.laps = int(a.laps); S.time = a.time; S.weather = a.weather; S.dir = a.dir
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	while Game.state != "menu" or Game.car == null:
		await get_tree().process_frame
	await get_tree().process_frame
	Game.startRace()
	var stepper = load("res://tests/test_laps.gd").new()
	Game.set_process(false)
	var t := 0.0
	for at in Array(a.at.split(",")).map(func(x): return float(x)):
		stepper.step(at - t, t >= 4.5)
		t = at
		Game.syncCar(1.0 / 60)
		Game.updateCamera(1.0 / 60)
		Hud.tick()
		Fx.me.updateMirror()
		Game.fx_overlay.tick(1.0 / 60)
		await Canvas2D.flush(self)
		for _i in 4: await RenderingServer.frame_post_draw
		var p: String = "%s/race_%s_%s_%d.png" % [a.out, a.track, a.mode, int(at)]
		get_viewport().get_texture().get_image().save_png(p)
		print("saved ", p)
	get_tree().quit()

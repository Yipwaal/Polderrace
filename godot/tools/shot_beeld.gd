extends Node
## Picture survey for the rendering work (Beeld): the real game scene, a race with bots, the player put at points along
## the lap, for every time of day and weather. One PNG per track x time x weather x point; tools/sheet_beeld.py makes
## contact sheets of them.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver opengl3 --resolution 1280x720 \
##     res://tools/shot_beeld.tscn -- tracks=polder,dorp times=day,dusk,night weathers=dry,rain,fog points=0.03,0.4,0.7 \
##     out=/abs/dir [quality=high] [speed=45] [hud=1] [dir=fwd] [view=ex,ey,ez,lx,ly,lz] [skid=1] [split=1] [run=2.5]
## points: fractions of the lap (from the start line). view: a free camera instead of the chase camera (one picture
## per time x weather). skid=1: the player slides (smoke, skid marks). run: seconds of real driving (autopilot) before
## each picture, so effects (spray, rain, smoke) are in the air.

var a := {"tracks": "polder", "times": "day,dusk,night", "weathers": "dry,rain,fog", "points": "0.03,0.4,0.7", "out": "/tmp", "quality": "high",
	"speed": "45", "hud": "1", "dir": "fwd", "view": "", "skid": "0", "split": "0", "run": "0", "car": "gt", "bots": "7", "mirror": "1"}
var stepper

func frame(dt := 1.0 / 60) -> void:
	Game.syncCar(dt)
	if Game.split and Game.p2 != null: Game.asP2(func(): Game.syncCar(dt))
	Game.updateCamera(dt)
	Fx.me.updateMirror()
	Game.fx_overlay.tick(dt)
	SplitView.me.tick(dt)
	Hud.tick()
	await RenderingServer.frame_post_draw

func put(s: float) -> void:
	var i := int(s / Trk.SPC) % Trk.NS
	Game.resetPlayer(i, 0)
	Game.player.speed = float(a.speed)
	var k := 0
	for b in Game.bots:
		b.s = fposmod(s + 10 + k * 8, Trk.TRACK_LEN); b.lat = -2.2 if k % 2 else 2.2
		b.speed = float(a.speed)
		Game.poseOnTrack(b.m.g, b.s, b.lat)
		k += 1
	if Game.split and Game.p2 != null:
		Game.asP2(func():
			Game.resetPlayer((i + Trk.NS - 6) % Trk.NS, 2.5)
			Game.snapCamera())
	Game.snapCamera()

func _ready() -> void:
	get_tree().create_timer(3000, true, false, true).timeout.connect(func(): print("ERROR timeout"); get_tree().quit(1))
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2: a[kv[0]] = kv[1]
	var owned := {}
	for id in Cars.CARS: owned[id] = true
	G.use_store("user://shot-beeld.json", {"polderrace3d-garage": {"owned": owned}})
	var S := G.settings
	S.car = a.car; S.diff = "normal"; S.laps = 3; S.time = "day"; S.weather = "dry"; S.dir = a.dir
	var tracks: Array = TrackLoader.TRACK_IDS if a.tracks == "all" else Array(a.tracks.split(","))
	S.track = tracks[0]
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	while Game.state != "menu" or Game.car == null:
		await get_tree().process_frame
	Game.set_process(false)
	stepper = load("res://tests/test_laps.gd").new()
	DirAccess.make_dir_recursive_absolute(a.out)
	G.prefs.quality = a.quality
	G.prefs.mirror = a.mirror == "1"
	Game.applyPrefs()
	for tr in tracks:
		S.track = tr
		await main.load_track(tr)
		for t in a.times.split(","):
			for w in a.weathers.split(","):
				if Game.state != "menu": Game.toMenu(-1)
				S.time = t; S.weather = w
				S.mode = "split" if a.split == "1" else "race"
				S.bots = int(a.bots)
				Game.startRace()
				stepper.step(4.8, false)
				stepper.step(1.0)
				Env.me.apply(t, w)
				Hud.visible = a.hud == "1"
				await Canvas2D.flush(self)
				var pts: Array = Array(a.points.split(",")).map(func(x): return float(x))
				if a.view != "": pts = [0.0]
				for pi in pts.size():
					put(Trk.S_START + Trk.TRACK_LEN * pts[pi] + 20)
					if float(a.run) > 0.0:
						stepper.step(float(a.run))
					if a.skid == "1":
						Game.player.slide = Vector2(4, 0); Game.player.speed = 30
						for _k in 30:
							Game.player.slide = Vector2(4, 0)
							Fx.me.updateFx(0.05)
					for _k in 3:
						Env.me.update(1.0 / 60, Game.camera)
						Fx.me.updateFx(1.0 / 60)
					for _f in 3: await frame()
					if a.view != "":
						var v := Array(a.view.split(",")).map(func(x): return float(x))
						Game.camera.position = Vector3(v[0], v[1], v[2])
						Game.camera.look_at(Vector3(v[3], v[4], v[5]))
						Env.me.update(0.0, Game.camera)
						for _f in 2: await RenderingServer.frame_post_draw
					for _f in 2: await RenderingServer.frame_post_draw
					var p: String = "%s/%s_%s_%s_%d.png" % [a.out, tr, t, w, pi]
					get_viewport().get_texture().get_image().save_png(p)
					print("saved ", p)
	get_tree().quit()

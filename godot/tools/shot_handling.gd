extends Node
## Screenshots of the car in action, to judge the handling by eye (body lean, slides, the camera):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver opengl3 --resolution 1280x720 \
##     res://tools/shot_handling.tscn -- track=circuit car=muscle out=/abs/dir [cam=0] [weather=dry]
## Drives a fixed programme with the handling harness (tests/handling_lib.gd) and saves a picture of each moment:
## corner (steady at the limit), brake (hard braking), turnin (braking into a corner), power (full gas out of a slow
## corner), hand (handbrake slide), catch (just after it), grass (two wheels on the verge), bots (in the pack).

var H
var a := {"track": "circuit", "car": "gt", "out": "/tmp", "cam": "0", "weather": "dry", "only": ""}

func shot(name: String) -> void:
	for _i in 3:
		Game.syncCar(1.0 / 60)
		Game.updateCamera(1.0 / 60)
	for b in Game.bots: pass
	Hud.tick()
	Fx.me.updateMirror()
	Game.fx_overlay.tick(1.0 / 60)
	await Canvas2D.flush(self)
	for _i in 4: await RenderingServer.frame_post_draw
	var p: String = "%s/handling_%s_%s_%s.png" % [a.out, a.track, a.car, name]
	get_viewport().get_texture().get_image().save_png(p)
	print("saved ", p)

## drive for secs with the camera and the body following every frame (so the picture shows the motion, not a snap)
func run(secs: float, fn: Callable) -> void:
	var n := int(secs * 120)
	for k in n:
		fn.call(k / 120.0)
		if k % 2 == 1:
			Game.syncCar(1.0 / 60)
			Game.updateCamera(1.0 / 60)

func want(name: String) -> bool:
	return a.only == "" or name in a.only.split(",")

func _ready() -> void:
	get_tree().create_timer(900, true, false, true).timeout.connect(func(): print("ERROR timeout"); get_tree().quit(1))
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2: a[kv[0]] = kv[1]
	var owned := {}
	for id in Cars.CARS: owned[id] = true
	G.use_store("user://shot-handling.json", {"polderrace3d-garage": {"owned": owned}})
	var S := G.settings
	S.track = a.track; S.mode = "ghost"; S.bots = 1; S.car = a.car; S.laps = 3; S.time = "day"; S.weather = a.weather; S.dir = "fwd"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	while Game.state != "menu" or Game.car == null:
		await get_tree().process_frame
	await get_tree().process_frame
	G.prefs.cam = int(a.cam)
	Game.applyPrefs()
	H = load("res://tests/handling_lib.gd").new()
	H.env = Env.me
	Game.set_process(false)
	Game.startRace()
	H.countdown()
	var i0: int = H.straight_i(260.0)
	var v := 110 / 3.6
	if want("corner"):
		H.put(i0, 0, 0, v); Game.snapCamera()
		run(2.0, func(_t): H.tick(1.0, H.hold(v), 0))
		await shot("corner")
	if want("brake"):
		H.put(i0, 0, 0, 180 / 3.6); Game.snapCamera()
		run(0.6, func(_t): H.tick(0, 1, 0))
		run(0.45, func(_t): H.tick(0, 0, 1))
		await shot("brake")
	if want("turnin"):
		H.put(i0, 0, 0, 150 / 3.6); Game.snapCamera()
		run(0.5, func(_t): H.tick(0, 1, 0))
		run(0.7, func(_t): H.tick(-0.9, 0, 1))
		await shot("turnin")
	if want("power"):
		H.put(i0, 0, 0, 50 / 3.6); Game.snapCamera()
		run(1.3, func(_t): H.tick(1, 1, 0))
		await shot("power")
	if want("hand"):
		H.put(i0, -2, 0, 90 / 3.6); Game.snapCamera()
		run(0.5, func(_t): H.tick(0, 1, 0))
		run(0.6, func(_t): H.tick(1, 0, 0, true))
		await shot("hand")
		run(0.35, func(_t): H.tick(clampf(-H.beta() * 2.5, -1, 1), 0.5, 0))
		await shot("catch")
	if want("grass"):
		H.put(i0, Trk.ROAD_HALF + 1.9, 0, 130 / 3.6); Game.snapCamera()
		run(0.8, func(_t): H.tick(H.keep(Trk.ROAD_HALF + 1.9), 1, 0))
		await shot("grass")
	if want("launch"):
		H.put(i0, 0, 0, 0); Game.snapCamera()
		run(0.5, func(_t): H.tick(0, 1, 0))
		await shot("launch")
	if want("bots"):
		S.mode = "race"; S.bots = 5; S.grid = "mid"
		Game.state = "menu"; Game.startRace()
		H.countdown()
		run(7.0, func(_t): H.drive_step(1.2, true))
		await shot("bots")
	get_tree().quit()

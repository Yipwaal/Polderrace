extends Node
## Screenshots of every menu screen in the real game scene, to compare with the HTML version (tools/menus_html.py makes
## the same screens; tools/compare_menus.py puts them side by side):
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1280x720 res://tools/shot_menus.tscn -- \
##     out=/abs/dir [only=home,garage,...]
## Plays on its own save file seeded from tools/menus_state.json (the same data the HTML screenshots get).

var out := "/tmp"
var only: Array = []

func _ready() -> void:
	get_tree().create_timer(1500, true, false, true).timeout.connect(func(): print("ERROR timeout"); get_tree().quit(1))
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out": out = kv[1]
		if kv.size() == 2 and kv[0] == "only": only = Array(kv[1].split(","))
	DirAccess.make_dir_recursive_absolute(out)
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://tools/menus_state.json"))
	G.use_store("user://menus-shot.json", data)
	Career.initGarage()
	Champ.reload()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	get_tree().current_scene = main
	while Game.state != "menu" or Game.car == null or not Menu.home.visible:
		await get_tree().process_frame
	await _frames(20)
	await shot("home", func(): Game.toMenu(-1))
	await shot("play", func(): Menu.homePanel("play"))
	await shot("career", func(): Menu.homePanel("career"))
	await shot("ach", func(): Menu.homePanel("ach"))
	await shot("records", func(): Menu.homePanel("records"))
	await shot("settings", func(): Menu.homePanel("settings"))
	await shot("settings_keys", func(): Menu.settingsUI.tabRadio.find("keys").press())
	await shot("settings_pad", func(): Menu.settingsUI.tabRadio.find("pad").press())
	Menu.settingsUI.showTab("general")
	# the orbit camera stands still at its start angle (the HTML tool does the same)
	await shot("garage", func(): Menu.homePanel("main"); Menu.homePanel("garage"); Menu.orb.a = 0.5; Menu.orb.idle = -1e9; Menu.orb.vel = 0.0, 30)
	await shot("garage_look", func(): Menu.garageUI.garTab("look"))
	Menu.garageUI.garTab("perf")
	Menu.homePanel("main")
	await shot("menu_modus", func(): Menu.menuFlow = "quick"; Menu.showMenu(2))
	await shot("menu_auto", func(): Menu.showMenu(0))
	await shot("menu_baan", func(): Menu.showMenu(1))
	await shot("menu_champ", func(): Game.toMenu(-1); Menu.homePanel("play"); Menu.homeUI.hChamp.press(); Menu.showMenu(3))
	if _want(["pause", "pause_settings", "results", "champ_results", "standings", "timetrial"]):
		var stepper = load("res://tests/test_laps.gd").new()
		Game.toMenu(-1)
		Menu.menuFlow = "quick"
		Champ.leaveChampMode()
		G.settings.mode = "race"; G.settings.bots = 3; G.settings.laps = 1
		Game.startRace()
		Game.set_process(false)
		stepper.step(4.5, false)
		stepper.step(1.5)
		_sync()
		await shot("pause", func(): Game.setPaused(true))
		await shot("pause_settings", func(): Menu.openPauseSettings())
		Menu.closePauseSettings()
		Game.setPaused(false)
		await _race_to_end(stepper)
		await shot("results", func(): pass, 40)
		# a championship round, then its standings
		Game.toMenu(-1)
		Champ.champ = Champ.loadQuickChamp()
		Menu.menuFlow = "champ"
		if not Champ.champInProgress(): Champ.newChamp()
		Champ.champ.active = true
		Champ.saveChamp()
		Champ.loadChampRound()
		Game.startRace()
		await _race_to_end(stepper)
		await shot("champ_results", func(): pass, 40)
		await shot("standings", func(): Game.overReady = true; Game.onAgain(), 30)
		Game.toMenu(-1)
		Champ.champ = null
		G.store_set("polderrace3d-champ", "null")
		Menu.menuFlow = "quick"
		G.settings.mode = "time"
		Game.startRace()
		stepper.step(5)
		Game.timeLeft = 0.01
		stepper.step(0.5)
		await shot("timetrial", func(): pass, 20)
		Game.set_process(true)
	get_tree().quit()

func _want(names: Array) -> bool:
	return only.is_empty() or names.any(func(n): return only.has(n))

## the race is driven by the test autopilot (tests/test_laps.gd), then the results come up
func _race_to_end(stepper) -> void:
	stepper.step(4.5, false)
	var t := 0.0
	while t < 400 and Game.state != "over":
		stepper.step(5)
		t += 5
	stepper.step(1)
	_sync()

func _sync() -> void:
	Game.syncCar(1.0 / 60)
	Game.updateCamera(1.0 / 60)
	Hud.tick()

func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame

func shot(name: String, fn: Callable, frames := 12) -> void:
	if not only.is_empty() and not only.has(name):
		return
	fn.call()
	await Canvas2D.flush(get_tree().current_scene)
	for _i in frames:
		if not Game.is_processing():
			Game.syncCar(1.0 / 60)
			Game.updateCamera(1.0 / 60)
			Hud.tick()
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var p := "%s/%s.png" % [out, name]
	get_viewport().get_texture().get_image().save_png(p)
	print("saved ", p)

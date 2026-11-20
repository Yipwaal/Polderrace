extends Node
## Screenshots of the looks (the Aanpassen work): the garage's Uiterlijk tab with every group open, and cars wearing a
## look in the garage from the view that belongs to it, with the lights on and off.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver opengl3 --resolution 1280x720 \
##     res://tools/shot_looks.tscn -- out=/abs/dir [only=groups,looks,cars] [car=gt] [credits=3450]
## groups: garage_<group>.png per group; looks: look_<name>.png for LOOKS below (panel hidden, the car alone);
## cars: car_<id>.png for every model in one busy look (fit check).
## race: race_<time>_<s>.png, a race with bots (their own looks) and the player's car in a look with neon, by day and
## by night (the test autopilot drives).
## The looks and cars also come as contact sheets (sheet_<n>.png: the car cut out and enlarged, eight to a sheet).
## Plays on its own save file.

const LOOKS := {
	"flames": [{"stripe": "flames", "sc": "yellow", "sc2": "red", "num": 7, "numStyle": "square", "numBg": "yellow", "rim": "gold", "tw": "letter", "d1": "polder", "d2": "tulp"}, "side"],
	"flag": [{"stripe": "flag", "num": 31, "rim": "white", "d1": "vlag", "d2": "hart", "ban": "ORANJE BOVEN", "banCol": "orange", "roof": "white"}, "q"],
	"delft": [{"stripe": "delft", "rim": "blue", "tw": "white", "d1": "molen", "d2": "kaas", "plate": "DELFT-1", "plateStyle": "old"}, "side"],
	"tulips": [{"stripe": "tulips", "d1": "wafel", "d2": "kroon", "num": 4, "numStyle": "ring", "numBg": "white", "numFg": "white"}, "side"],
	"lion": [{"stripe": "lion", "sc": "gold", "sc2": "red", "d1": "cup", "d2": "legende", "num": 1, "numStyle": "plain", "numFg": "gold", "rim": "gold", "finish": "pearl"}, "side"],
	"rally": [{"stripe": "rally", "sc": "yellow", "sc2": "black", "num": 46, "numFont": "round", "d1": "turbo", "d2": "patat", "rim": "black", "rimStyle": "spoke", "wing": "gt"}, "side"],
	"checker": [{"stripe": "checker", "sc": "white", "sc2": "black", "d1": "finish", "d2": "delta", "num": 88, "numFont": "block", "tw": "red"}, "side"],
	"sidestripe": [{"stripe": "side", "sc": "white", "sc2": "orange", "cal": "yellow", "rim": "gun", "tw": "yellow"}, "side"],
	"triple": [{"stripe": "triple", "sc": "white", "sc2": "red", "num": 12, "numPos": "roof", "roof": "black"}, "top"],
	"center": [{"stripe": "center", "sc": "yellow", "num": 9, "numPos": "doors", "tint": "mirror"}, "top"],
	"front": [{"lamp": "yellow", "ban": "POLDERRACE", "banCol": "black", "tint": "blue", "plate": "YIP-01"}, "front"],
	"rear": [{"plate": "SNEL-99", "plateStyle": "black", "wing": "duck", "exhaust": "dual", "tint": "bronze"}, "rear"],
	"wheel": [{"rim": "red", "rimStyle": "dish", "cal": "blue", "tw": "letter"}, "wheel"],
	"chrome": [{"finish": "chrome", "tint": "black", "rim": "chrome"}, "q"],
	"matte": [{"finish": "matte", "rim": "black", "tint": "black", "lamp": "smoke"}, "q"],
	"metallic": [{"finish": "metallic"}, "q"],
	"neon": [{"glow": "purple", "lamp": "ice", "rim": "black"}, "low"],
}
const BUSY := {"stripe": "flames", "sc": "yellow", "sc2": "red", "num": 7, "d1": "polder", "d2": "tulp", "ban": "POLDERRACE", "roof": "black", "tw": "letter", "rim": "gold",
	"plate": "YIP-01", "glow": "blue"}

var out := "/tmp"
var only: Array = []
var car := "gt"
var credits := 3450

func _ready() -> void:
	get_tree().create_timer(1500, true, false, true).timeout.connect(func(): print("ERROR timeout"); get_tree().quit(1))
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() != 2: continue
		match kv[0]:
			"out": out = kv[1]
			"only": only = Array(kv[1].split(","))
			"car": car = kv[1]
			"credits": credits = int(kv[1])
	DirAccess.make_dir_recursive_absolute(out)
	var owned := {}
	for id in Cars.CARS: owned[id] = true
	G.use_store("user://looks-shot.json", {"polderrace3d-settings": {"car": car, "color": "#1d4f9e"}, "polderrace3d-garage": {"credits": credits, "owned": owned, "looks": {}}})
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	get_tree().current_scene = main
	while Game.state != "menu" or Game.car == null or not Menu.home.visible:
		await get_tree().process_frame
	await _frames(20)
	Menu.homePanel("garage")
	var ui: GarageUI = Menu.garageUI
	ui.garTab("look")
	if _want("groups"):
		# a look with something in the fitting room, so the bar shows
		ui.pick("finish", "pearl")
		ui.pick("stripe", "flames")
		ui.pick("num", 7)
		for g in CarLook.GROUPS:
			ui.lookGroup(g[0])
			await shot("garage_" + g[0], 45)
		ui.fitUndo.press()
	if _want("looks"):
		Menu.home.visible = false
		for n in LOOKS:
			await _wear(car, LOOKS[n][0], LOOKS[n][1])
			await shot("look_" + n, 34, true)
		GarageRoom.setDark(true)
		await _wear(car, LOOKS.neon[0], "low")
		await shot("look_neon_dark", 34, true)
		await _wear(car, LOOKS.front[0], "front")
		await shot("look_front_dark", 34, true)
		GarageRoom.setDark(false)
		_sheets("looks")
	if only.has("race"):
		Menu.homePanel("main")
		await _race()
		get_tree().quit()
		return
	if _want("cars"):
		Menu.home.visible = false
		for id in Cars.CARS:
			await _wear(id, BUSY, "q")
			await shot("car_" + id, 34, true)
			GarageRoom.aim("side")
			await shot("car_" + id + "_side", 34, true)
		_sheets("cars")
	get_tree().quit()

func _race() -> void:
	var stepper = load("res://tests/test_laps.gd").new()
	var S := G.settings
	for tm in ["day", "night"]:
		G.settings.car = car
		var u := G.carUp(car)
		u.merge({"stripe": "flames", "sc": "yellow", "sc2": "red", "num": 7, "glow": "purple", "rim": "gold", "tw": "letter", "lamp": "ice", "ban": "POLDERRACE", "plate": "YIP-01"}, true)
		S.track = "polder"; S.mode = "race"; S.bots = 7; S.laps = 2; S.time = tm; S.weather = "dry"; S.grid = "mid"
		Menu.loadTrack("polder", "fwd")
		Menu.applyEnv(tm, "dry")
		Game.rebuildPlayerCar()
		Game.startRace()
		Game.set_process(false)
		var t := 0.0
		for at in [3.0, 9.0]:
			stepper.step(at - t, t >= 4.5)
			t = at
			Game.syncCar(1.0 / 60)
			Game.updateCamera(1.0 / 60)
			Hud.tick()
			Fx.me.updateMirror()
			Game.fx_overlay.tick(1.0 / 60)
			await Canvas2D.flush(get_tree().current_scene)
			for _i in 4: await RenderingServer.frame_post_draw
			var p := "%s/race_%s_%d.png" % [out, tm, int(at)]
			get_viewport().get_texture().get_image().save_png(p)
			print("saved ", p)
		Game.set_process(true)
		Game.toMenu(-1)

func _want(n: String) -> bool:
	return only.is_empty() or only.has(n)

## the car in the garage in a look (saved straight on the car, as if everything was owned)
func _wear(id: String, look: Dictionary, view: String) -> void:
	G.settings.car = id
	var u := G.carUp(id)
	for k in CarLook.defaults(): u.erase(k)
	u.merge(CarLook.defaults(), true)
	u.merge(look, true)
	Game.rebuildPlayerCar()
	GarageRoom.aim(view)
	await _frames(2)

func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame

var _cuts: Array = []

func shot(name: String, frames := 12, cut := false) -> void:
	await Canvas2D.flush(get_tree().current_scene)
	await _frames(frames)
	await RenderingServer.frame_post_draw
	var p := "%s/%s.png" % [out, name]
	var img := get_viewport().get_texture().get_image()
	img.save_png(p)
	print("saved ", p)
	if cut:
		# the car stands right of the middle (the panel's place is left): cut it out
		var w := img.get_width()
		var h := img.get_height()
		_cuts.append(img.get_region(Rect2i(int(w * 0.44), int(h * 0.3), int(w * 0.5), int(h * 0.4))))

## the cut-out cars, enlarged, eight to a sheet (two columns)
func _sheets(name: String) -> void:
	var n := 0
	while not _cuts.is_empty():
		var part: Array = _cuts.slice(0, 8)
		_cuts = _cuts.slice(8)
		var cw: int = part[0].get_width() * 3 / 2
		var ch: int = part[0].get_height() * 3 / 2
		var sheet := Image.create(cw * 2, ch * ((part.size() + 1) / 2), false, part[0].get_format())
		for i in part.size():
			var im: Image = part[i]
			im.resize(cw, ch, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(im, Rect2i(0, 0, cw, ch), Vector2i((i % 2) * cw, (i / 2) * ch))
		var p := "%s/sheet_%s_%d.png" % [out, name, n]
		sheet.save_png(p)
		print("saved ", p)
		n += 1

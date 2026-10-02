extends Node3D
## The game scene: environment, the world of the current track, the camera; Game (autoload) runs the race and
## Hud (autoload) draws the HUD and overlays. JS init line: loadTrack(settings.track); applyEnv(...); rebuildPlayerCar().

var env: Env
var cam: Camera3D
var fx: Fx
var overlay: CanvasLayer

func _ready() -> void:
	env = Env.new()
	add_child(env)
	World.root = Node3D.new()
	World.root.name = "World"
	add_child(World.root)
	cam = Camera3D.new()
	cam.fov = 62
	cam.near = 0.5
	cam.far = 3000
	add_child(cam)
	cam.current = true
	Game.camera = cam
	fx = Fx.new()
	add_child(fx)
	overlay = load("res://scripts/ui/fx_overlay.gd").new()
	add_child(overlay)
	Game.fx_overlay = overlay
	add_child(SplitView.new())
	Game.applyPrefs()
	if G.store_get("polderrace3d-window") == "full": setFullscreen(true)
	env.time = G.settings.time
	env.weather = G.settings.weather
	await load_track(G.settings.track)
	Game.rebuildPlayerCar()
	await Canvas2D.flush(self)
	Game.toMenu(-1)

## PC version only (in the browser F11 is the browser's): F11 or Alt+Enter switches full screen in every screen; the main
## scene gets key events before the autoloads, so the menus never see these keys
func _input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo): return
	var k: Key = e.keycode
	if k == KEY_F11 or (e.alt_pressed and (k == KEY_ENTER or k == KEY_KP_ENTER)):
		get_viewport().set_input_as_handled()
		var full := DisplayServer.window_get_mode() < DisplayServer.WINDOW_MODE_FULLSCREEN
		setFullscreen(full)
		G.store_set("polderrace3d-window", "full" if full else "win")

func setFullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)

func load_track(id: String) -> void:
	Game.clearBots()
	Game.clearTraffic()
	TrackLoader.load_track(id, G.settings.dir)
	Game.resetPlayer(Trk.START_I, 0)
	await Canvas2D.flush(self)

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
	env.time = G.settings.time
	env.weather = G.settings.weather
	await load_track(G.settings.track)
	Game.rebuildPlayerCar()
	await Canvas2D.flush(self)
	Game.toMenu(-1)

func load_track(id: String) -> void:
	Game.clearBots()
	Game.clearTraffic()
	TrackLoader.load_track(id, G.settings.dir)
	Game.resetPlayer(Trk.START_I, 0)
	await Canvas2D.flush(self)

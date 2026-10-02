extends RefCounted
## Cost of a race in the real game scene (scenes/main.tscn), with budgets so that a slowdown shows up. The budgets are
## generous (machines differ; the game has to run on modest laptops with integrated graphics):
## - always (also headless): loading every track, the simulation with 7 bots (ms per simulated second, 120 Hz) and one
##   frame of the game (Game._process: simulation, camera, effects, sound, HUD; and Hud.tick on its own).
## - with a renderer: draw calls and triangles of the main view and the mirror on every track at high quality, 7 bots round
##   the player, at four points of the lap. Run it as
##     xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver opengl3 --resolution 1280x720 res://tests/runner.tscn -- perf
##   (tools/perf_render.gd measures more: other qualities, night, rain, split screen, traffic).

## per track: [draw calls main view, draw calls mirror, triangles main view + mirror] (high quality, average of 4 points);
## measured after the batching (World.batch, 300 m instancing cells) plus a third
const DRAWS := {
	"polder": [750, 520, 850000], "dorp": [600, 200, 450000], "circuit": [750, 150, 600000], "afsluitdijk": [700, 160, 500000],
	"haven": [650, 170, 280000], "veluwe": [780, 360, 1200000], "grachten": [600, 150, 350000], "limburg": [570, 160, 880000],
	"rotterdam": [620, 280, 350000], "zeeland": [640, 130, 450000]}

var host: Node
var L

func frames(n := 1) -> void:
	for _i in n: await host.get_tree().process_frame

func vp_info(vp: RID, what: int) -> int:
	return RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, what)

## the player at distance s along the lap, the bots in a bunch just ahead of and beside it (tools/perf_render.gd)
func put(s: float) -> void:
	Game.resetPlayer(int(s / Trk.SPC) % Trk.NS, 0)
	Game.player.speed = 30
	var k := 0
	for b in Game.bots:
		b.s = fposmod(s + 12 + k * 9, Trk.TRACK_LEN); b.lat = -2.5 if k % 2 else 2.5
		Game.poseOnTrack(b.m.g, b.s, b.lat)
		k += 1
	Game.snapCamera()

func run(h: Node) -> TestReport:
	var r := TestReport.new("snelheid: laden, simulatie, frame en tekenaanroepen")
	host = h
	L = load("res://tests/test_laps.gd").new()
	var rendering := DisplayServer.get_name() != "headless"
	var S := G.settings
	S.car = "gt"; S.diff = "normal"; S.laps = 3; S.time = "day"; S.weather = "dry"; S.dir = "fwd"; S.track = "polder"
	G.prefs.quality = "high"; G.prefs.mirror = true
	var main: Node = load("res://scenes/main.tscn").instantiate()
	host.add_child(main)
	while Game.state != "menu" or Game.car == null:
		await frames()
	Game.set_process(false)
	Game.set_process_input(false)
	Game.applyPrefs()
	# ---- loading every track (with a renderer this includes drawing its canvas textures, like the menu does)
	var load_max := 10000.0 if rendering else 3000.0
	for tr in TrackLoader.TRACK_IDS:
		S.track = tr
		var t0 := Time.get_ticks_usec()
		await main.load_track(tr)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		r.check(ms < load_max, "%s: baan laden" % tr, "%.0f ms (budget %.0f)" % [ms, load_max])
	# ---- simulation and one game frame, 7 bots, on the busiest tracks
	for tr in ["polder", "veluwe", "rotterdam"]:
		S.track = tr
		await main.load_track(tr)
		S.mode = "race"; S.bots = 7
		Game.toMenu(-1)
		Game.startRace()
		L.step(5.0, false)
		var t0 := Time.get_ticks_usec()
		L.step(10.0)
		var per_s := (Time.get_ticks_usec() - t0) / 1000.0 / 10.0
		r.check(per_s < 250, "%s: race met 7 bots, 120 Hz" % tr, "%.1f ms rekentijd per gesimuleerde seconde (%.2f ms per frame bij 60 fps)" % [per_s, per_s / 60])
		var proc := 0.0
		var hud := 0.0
		for _i in 240:
			var a := Time.get_ticks_usec()
			Game._process(1.0 / 60)
			proc += Time.get_ticks_usec() - a
			a = Time.get_ticks_usec()
			Hud.boardAt = 0.0   # the lap board refills every half second: here every frame (the worst case)
			Hud.tick()
			hud += Time.get_ticks_usec() - a
			if _i % 8 == 0: await frames()
		proc /= 240000.0
		hud /= 240000.0
		r.check(proc < 10.0, "%s: een frame van het spel (Game._process)" % tr, "%.2f ms (budget 10)" % proc)
		r.check(hud < 1.0, "%s: HUD per frame (Hud.tick, rondenbord elke frame bijgewerkt)" % tr, "%.3f ms (budget 1)" % hud)
	# ---- draw calls (a renderer only)
	if not rendering:
		print("--   tekenaanroepen: alleen met een renderer (xvfb-run ... --rendering-driver opengl3 res://tests/runner.tscn -- perf)")
	else:
		var mvp := host.get_viewport().get_viewport_rid()
		var mir: RID = Fx.me.mirror_vp.get_viewport_rid()
		for tr in TrackLoader.TRACK_IDS:
			S.track = tr
			await main.load_track(tr)
			S.mode = "race"; S.bots = 7
			Game.toMenu(-1)
			Game.startRace()
			L.step(4.8, false)
			L.step(2.0)   # past the start lights: the mirror is off while they show
			var sum := [0.0, 0.0, 0.0]
			for p in 4:
				put(Trk.S_START + Trk.TRACK_LEN * p / 4.0 + 20)
				for _f in 3:
					Game.syncCar(1.0 / 60); Game.updateCamera(1.0 / 60); Fx.me.updateMirror(); Hud.tick()
					await RenderingServer.frame_post_draw
				sum[0] += vp_info(mvp, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME) / 4.0
				sum[1] += vp_info(mir, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME) / 4.0
				sum[2] += (vp_info(mvp, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME) + vp_info(mir, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)) / 4.0
			var bud: Array = DRAWS[tr]
			r.check(sum[0] < bud[0], "%s: tekenaanroepen beeld" % tr, "%.0f (budget %d)" % [sum[0], bud[0]])
			r.check(sum[1] < bud[1], "%s: tekenaanroepen spiegel" % tr, "%.0f (budget %d)" % [sum[1], bud[1]])
			r.check(sum[2] < bud[2], "%s: driehoeken beeld + spiegel" % tr, "%.0f (budget %d)" % [sum[2], bud[2]])
	Game.toMenu(-1)
	main.queue_free()
	await frames(2)
	Fx.me = null; SplitView.me = null; Env.me = null; Game.camera = null; Game.fx_overlay = null
	Game.set_process(true)
	Game.set_process_input(true)
	return r

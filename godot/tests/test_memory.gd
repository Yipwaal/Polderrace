extends RefCounted
## Memory (like the HTML tests/test_memory.py): rounds of loading all 10 tracks fwd and rev in changing time and weather,
## a race with 7 bots to the results and the podium, the replay, a ghost lap, split screen, a time trial with traffic and
## the garage room, in the real game scene (scenes/main.tscn: Env, Fx, mirror, SplitView, screen effects). After every
## round the counts of nodes, objects, resources and orphan nodes (and with a renderer: video, texture and buffer memory)
## must come back to the same level: round 3 against round 2 (round 1 fills the caches: shaders, car kits, fonts, sounds).
## Headless (run.py) there is no renderer; with one (xvfb-run ... --rendering-driver opengl3 res://tests/runner.tscn -- memory)
## the canvas textures are really drawn and video memory is checked too. MEM_ROUNDS=n sets the number of rounds (default 3).

var L
var r: TestReport
var host: Node
var main: Node
var rendering := false

func frames(n := 3) -> void:
	for _i in n: await host.get_tree().process_frame

## a frame of the game as Game._process runs it (the tests drive with Game's processing off)
func tick(n := 2) -> void:
	for _i in n:
		Game._process(1.0 / 60)
		await host.get_tree().process_frame

func snap() -> Dictionary:
	var s := {"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), "orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, "shaders": LMat._cache.size(),
		"viewports": host.get_tree().root.find_children("*", "SubViewport", true, false).size(), "pending": Canvas2D.pending_count(),
		"scene": host.get_tree().current_scene.get_child_count()}
	if rendering:
		s.video_mb = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
		s.texture_mb = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
		s.buffer_mb = Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0
	return s

func fmt(s: Dictionary) -> String:
	var out := []
	for k in s:
		out.append("%s %s" % [k, ("%.1f" % s[k]) if s[k] is float and k.ends_with("_mb") else str(int(s[k]))])
	return ", ".join(out)

func race(mode: String, bots: int, secs: float) -> void:
	var S := G.settings
	S.mode = mode; S.bots = bots; S.laps = 1
	if Game.state != "menu": Game.toMenu(-1)
	Game.startRace()
	await tick()
	L.step(4.5, false)
	L.step(secs)
	await tick(3)

func round_(k: int) -> void:
	var S := G.settings
	var times := ["day", "dusk", "night"]
	var weathers := ["dry", "rain", "fog"]
	var n := 0
	for id in TrackLoader.TRACK_IDS:
		for dir in ["fwd", "rev"]:
			S.track = id; S.dir = dir
			S.time = times[(n + k) % 3]; S.weather = weathers[(n / 3 + k) % 3]
			Menu.loadTrack(id, dir)
			Menu.applyEnv(S.time, S.weather)
			Game.rebuildPlayerCar()
			Menu.menuScene()
			await tick()
			n += 1
		await frames(2)
	# a race with 7 bots to the results board and the podium, the replay, back to the menu
	S.track = "rotterdam"; S.dir = "fwd"; S.time = "night"; S.weather = "rain"
	Menu.loadTrack("rotterdam", "fwd")
	Menu.applyEnv(S.time, S.weather)
	Game.rebuildPlayerCar()
	await race("race", 7, 6)
	Game.finishPlayer()
	L.step(3.5)
	await tick(3)
	Game.overReady = true
	Rep.replayOpen()
	for _i in 30: Rep.replayUpdate(1.0 / 30)
	await tick()
	Rep.replayClose()
	await tick()
	Game.toMenu(-1)
	await tick()
	# ghost: a stored best lap drives along (its see-through car is made at the start)
	S.track = "polder"; S.time = "day"; S.weather = "dry"
	Menu.loadTrack("polder", "fwd")
	Menu.applyEnv(S.time, S.weather)
	var d := []
	for i in 400:
		var p: Vector3 = Trk.P[(Trk.START_I + i * 2) % Trk.NS]
		d.append_array([i * 0.1, i * 4.0, p.x, Trk.HT[(Trk.START_I + i * 2) % Trk.NS], p.z, 0.0])
	G.store_set(Rep.ghostKey("polder"), JSON.stringify({"t": 40.0, "car": "gt", "color": "#ffffff", "d": d}))
	await race("ghost", 0, 8)
	Game.toMenu(-1)
	# split screen with 2 bots (two SubViewports, player 2's HUD), and a time trial with traffic
	await race("split", 2, 5)
	Game.toMenu(-1)
	S.weather = "fog"
	Menu.applyEnv(S.time, S.weather)
	await race("time", 0, 6)
	Game.timeLeft = 0.05
	L.step(0.2)
	await tick()
	Game.toMenu(-1)
	# the garage room and back, the other home panels, the setup steps, the pause screen
	Menu.homePanel("garage")
	await tick()
	Menu.homeBack()
	await tick()
	for v in ["play", "records", "settings", "ach", "career", "main"]:
		Menu.homePanel(v)
		await tick(1)
	# (back home between the steps: headless, step to step in the game scene makes the UI layout loop; with a renderer not)
	for st in [2, 0, 1]:
		Menu.showMenu(st)
		await tick(1)
		Menu.showMenu(-1)
		await tick(1)
	S.mode = "race"
	Game.startRace()
	L.step(4.5, false)
	Game.setPaused(true)
	await tick()
	Game.setPaused(false)
	Game.toMenu(-1)
	await tick()
	await frames(4)

func run(h: Node) -> TestReport:
	r = TestReport.new("geheugen (geen lekken)")
	host = h
	rendering = DisplayServer.get_name() != "headless"
	L = load("res://tests/test_laps.gd").new()
	G.settings.car = "gt"; G.settings.diff = "easy"
	G.prefs.mirror = true
	main = load("res://scenes/main.tscn").instantiate()
	host.add_child(main)
	while Game.state != "menu" or Game.car == null:
		await frames(1)
	Game.set_process(false)
	Game.set_process_input(false)
	var rounds := int(OS.get_environment("MEM_ROUNDS")) if OS.get_environment("MEM_ROUNDS") != "" else 3
	var snaps: Array = []
	for k in rounds:
		var t0 := Time.get_ticks_msec()
		await round_(k)
		var s := snap()
		snaps.append(s)
		print("   ronde %d (%.0f s): %s" % [k + 1, (Time.get_ticks_msec() - t0) / 1000.0, fmt(s)])
	var a: Dictionary = snaps[rounds - 2]
	var b: Dictionary = snaps[rounds - 1]
	var keys := [["nodes", 1.0, 2], ["objects", 1.01, 20], ["resources", 1.01, 10], ["orphans", 1.0, 0], ["viewports", 1.0, 0], ["pending", 1.0, 0], ["scene", 1.0, 0], ["shaders", 1.0, 0]]
	if rendering:
		keys += [["video_mb", 1.02, 2.0], ["texture_mb", 1.02, 2.0], ["buffer_mb", 1.02, 2.0]]
	for kk in keys:
		var key: String = kk[0]
		r.check(b[key] <= a[key] * kk[1] + kk[2], "%s stabiel" % key, "ronde %d: %s, ronde %d: %s" % [rounds - 1, str(a[key]), rounds, str(b[key])])
	r.check(b.static_mb <= a.static_mb * 1.02 + 4, "geheugen (static) stabiel", "%.1f -> %.1f MB" % [a.static_mb, b.static_mb])
	# what a long session could pile up: the replay goes with the race, the pools and caches have a fixed size
	r.check(Rep.replay == null and Rep.rp == null, "replay opgeruimd in het menu", "ghost-opname: %d getallen (hooguit een ronde, de volgende ghost-race begint opnieuw)" % Rep.ghostRec.size())
	r.check(Fx.me.parts.size() == 90 and Fx.me.skids.multimesh.instance_count == Fx.SKID_MAX, "rook en remsporen: vaste pool", "%d rookwolkjes, %d remsporen" % [Fx.me.parts.size(), Fx.me.skids.multimesh.instance_count])
	r.check(Sfx._tones.size() <= 64 and Sfx._bursts.size() <= 64 and Sfx.get_child_count() <= 6, "geluid: begrensde caches, vaste spelers", "%d tonen, %d klappen, %d spelers" % [Sfx._tones.size(), Sfx._bursts.size(), Sfx.get_child_count()])
	r.check(Canvas2D._specs.size() < 64, "lettertypecache begrensd", str(Canvas2D._specs.size()))
	main.queue_free()
	await frames(2)
	Fx.me = null; SplitView.me = null; Env.me = null; Game.camera = null; Game.fx_overlay = null
	Game.set_process(true)
	Game.set_process_input(true)
	return r

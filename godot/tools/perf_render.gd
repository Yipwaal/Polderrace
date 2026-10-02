extends Node
## Render cost per track in the real game scene (needs a renderer): draw calls, objects and primitives per frame of the
## main view (and its shadow pass), the mirror and split screen, at points along the lap with 7 bots round the player.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver opengl3 --resolution 1280x720 \
##     res://tools/perf_render.tscn -- tracks=all variants=high,mid,low,night,rain,nomirror,split,time points=4 out=/abs/file.json
## Variants: high/mid/low = picture quality (day, dry, mirror on); night, rain (high); nomirror (high, mirror off);
## split (2 players, 5 bots); time (time trial: traffic instead of bots). Software OpenGL is slow: count, do not time.

var a := {"tracks": "all", "variants": "high,mid,low,night,rain,nomirror,split,time", "points": "4", "out": "", "frames": "3"}

func info(vp: RID, type: int, what: int) -> int:
	return RenderingServer.viewport_get_render_info(vp, type, what)

func vp_stats(vp: RID) -> Dictionary:
	var V := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE
	var S := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW
	return {"draws": info(vp, V, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME), "objects": info(vp, V, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
		"prims": info(vp, V, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME), "sh_draws": info(vp, S, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"sh_objects": info(vp, S, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME), "sh_prims": info(vp, S, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)}

## one frame of the game the way Game._process draws it (Game's own processing is off; the tests' autopilot drives)
func frame() -> void:
	Game.syncCar(1.0 / 60)
	if Game.split and Game.p2 != null: Game.asP2(func(): Game.syncCar(1.0 / 60))
	Game.updateCamera(1.0 / 60)
	Fx.me.updateMirror()
	Game.fx_overlay.tick(1.0 / 60)
	SplitView.me.tick(1.0 / 60)
	Hud.tick()
	await RenderingServer.frame_post_draw

## the player at distance s along the lap, the bots in a bunch just ahead of and beside it
func put(s: float) -> void:
	var i := int(s / Trk.SPC) % Trk.NS
	Game.resetPlayer(i, 0)
	Game.player.speed = 30
	var k := 0
	for b in Game.bots:
		b.s = fposmod(s + 12 + k * 9, Trk.TRACK_LEN); b.lat = -2.5 if k % 2 else 2.5
		Game.poseOnTrack(b.m.g, b.s, b.lat)
		k += 1
	if Game.split and Game.p2 != null:
		Game.asP2(func():
			Game.resetPlayer((i + Trk.NS - 6) % Trk.NS, 2.5)
			Game.snapCamera())
	Game.snapCamera()

func lights_visible() -> int:
	var n := 0
	for l in get_tree().root.find_children("*", "Light3D", true, false):
		if l is DirectionalLight3D: continue
		if (l as Light3D).is_visible_in_tree() and (l as Light3D).light_energy > 0: n += 1
	return n

## shadow casters near the camera (the GL renderer does not count its shadow pass): a rough measure of that pass
func casters() -> int:
	if not Env.me.sun.shadow_enabled: return 0
	var cp := Game.camera.global_position
	var n := 0
	for gi in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g: GeometryInstance3D = gi
		if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF or not g.is_visible_in_tree(): continue
		var bb := g.global_transform * g.get_aabb()
		if bb.grow(Env.me.sun.directional_shadow_max_distance).has_point(cp): n += 1
	return n

## what the main camera sees, by kind (frustum test on the bounding boxes, like the renderer's culling)
func breakdown() -> Dictionary:
	var cam := Game.camera
	var planes := cam.get_frustum()
	var out := {}
	for gi in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g: GeometryInstance3D = gi
		if not g.is_visible_in_tree() or not (g.layers & cam.cull_mask): continue
		var bb := g.global_transform * g.get_aabb()
		var inside := true
		for pl in planes:
			var c := bb.get_center()
			var e := bb.size / 2
			var r := absf(pl.normal.x) * e.x + absf(pl.normal.y) * e.y + absf(pl.normal.z) * e.z
			if pl.distance_to(c) > r: inside = false; break
		if not inside: continue
		var kind := g.get_class()
		if World.root.is_ancestor_of(g): kind = "world:" + kind
		out[kind] = out.get(kind, 0) + 1
	return out

func _ready() -> void:
	get_tree().create_timer(3000, true, false, true).timeout.connect(func(): print("ERROR timeout"); get_tree().quit(1))
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2: a[kv[0]] = kv[1]
	var owned := {}
	for id in Cars.CARS: owned[id] = true
	G.use_store("user://perf-render.json", {"polderrace3d-garage": {"owned": owned}})
	var S := G.settings
	S.car = "gt"; S.diff = "normal"; S.laps = 3; S.time = "day"; S.weather = "dry"
	var tracks: Array = TrackLoader.TRACK_IDS if a.tracks == "all" else Array(a.tracks.split(","))
	S.track = tracks[0]
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	while Game.state != "menu" or Game.car == null:
		await get_tree().process_frame
	Game.set_process(false)
	var stepper = load("res://tests/test_laps.gd").new()
	var results := {}
	var mvp := get_viewport().get_viewport_rid()
	for tr in tracks:
		S.track = tr; S.dir = "fwd"
		var t0 := Time.get_ticks_msec()
		await main.load_track(tr)
		var load_ms := Time.get_ticks_msec() - t0
		results[tr] = {"load_ms": load_ms}
		for v in Array(a.variants.split(",")):
			if Game.state != "menu": Game.toMenu(-1)
			G.prefs.quality = v if v in ["high", "mid", "low"] else "high"
			G.prefs.mirror = v != "nomirror"
			Game.applyPrefs()
			Env.me.apply("night" if v == "night" else "day", "rain" if v == "rain" else "dry")
			S.mode = "split" if v == "split" else ("time" if v == "time" else "race")
			S.bots = 5 if v == "split" else 7
			Game.startRace()
			# past the start lights (the mirror stays off while they show)
			stepper.step(4.8, false)
			stepper.step(2.0)
			await Canvas2D.flush(self)
			var rows := []
			var np := int(a.points)
			for p in np:
				put(Trk.S_START + Trk.TRACK_LEN * p / np + 20)
				for _f in int(a.frames): await frame()
				var st := vp_stats(mvp)
				if v == "split":
					var s1 := vp_stats(SplitView.me.vp1.get_viewport_rid())
					var s2 := vp_stats(SplitView.me.vp2.get_viewport_rid())
					for kk in st: st[kk] += s1[kk] + s2[kk]
				if Fx.me.mirrorOn():
					var sm := vp_stats(Fx.me.mirror_vp.get_viewport_rid())
					st.mirror_draws = sm.draws; st.mirror_objects = sm.objects; st.mirror_prims = sm.prims
				st.lights = lights_visible()
				st.casters = casters()
				if a.get("breakdown", "") != "": print("   ", tr, " ", v, " punt ", p, ": ", breakdown())
				st.total_draws = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				st.total_prims = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
				rows.append(st)
			results[tr][v] = rows
			var avg := func(k: String) -> float:
				var t := 0.0
				for rw in rows: t += float(rw.get(k, 0))
				return t / rows.size()
			print("%-11s %-8s draws %5.0f (+sh %4.0f, mirror %4.0f) objects %4.0f prims %7.0f  total draws %5.0f prims %7.0f lights %d casters %4.0f load %d ms" % [tr, v,
				avg.call("draws"), avg.call("sh_draws"), avg.call("mirror_draws"), avg.call("objects"), avg.call("prims"), avg.call("total_draws"), avg.call("total_prims"), rows[0].lights, avg.call("casters"), load_ms])
	results["_mem"] = {"video_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, "texture_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		"buffer_mb": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0, "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}
	print("geheugen: ", results._mem)
	if a.out != "":
		var f := FileAccess.open(a.out, FileAccess.WRITE)
		f.store_string(JSON.stringify(results, " "))
		f.close()
		print("saved ", a.out)
	get_tree().quit()

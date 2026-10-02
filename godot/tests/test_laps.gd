extends RefCounted
## Physics parity: the autopilot of the HTML test harness (full gas, steer -df*3 - lat*0.15, 120 Hz) drives one lap in
## ghost mode (no bots, no traffic) on every ported track with a few cars; finish time, lap time and top speed must equal
## the HTML game's (tests/golden/laps.json, made by tools/export_laps.py). Wind tracks get a looser limit (random gusts).

var wrong := 0.0
var resets := 0

## JS window.__step(sec, steer)
func step(sec: float, steer := true) -> void:
	var g := Game
	for _i in int(round(sec * 120)):
		g.keysDown["KeyW"] = true
		g.pad = {"steer": 0.0, "gas": 0.0, "brake": 0.0, "hand": false, "look": false}
		if steer:
			var th := Trk.heading_of(Trk.T[g.player.idx])
			var df := fposmod(th - g.player.heading + PI, TAU) - PI
			g.pad.steer = clampf(-df * 3 - g.player.lat * 0.15, -1, 1)
			wrong = wrong + 1.0 / 120 if absf(df) > 2.1 else 0.0
			if wrong > 1.5:
				wrong = 0; resets += 1; g.resetToTrack()
		if g.split and g.p2 != null:
			# player 2 (split screen): gas and steering keys of the P2 key set, steered bang-bang by the same autopilot
			g.keysDown["ArrowUp"] = true
			g.keysDown.erase("ArrowLeft"); g.keysDown.erase("ArrowRight")
			if steer:
				var st: float = g.asP2(func():
					var th2 := Trk.heading_of(Trk.T[g.player.idx])
					var df2 := fposmod(th2 - g.player.heading + PI, TAU) - PI
					return clampf(-df2 * 3 - g.player.lat * 0.15, -1, 1))
				if st > 0.15: g.keysDown["ArrowRight"] = true
				elif st < -0.15: g.keysDown["ArrowLeft"] = true
		g.update(1.0 / 120)
	g.keysDown.erase("KeyW")
	g.keysDown.erase("ArrowUp"); g.keysDown.erase("ArrowLeft"); g.keysDown.erase("ArrowRight")

func run(host: Node) -> TestReport:
	var r := TestReport.new("rijden zoals de HTML-versie (autopiloot-ronde)")
	var gold: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/laps.json"))
	var env := Env.new()
	host.add_child(env)
	World.root = Node3D.new()
	host.add_child(World.root)
	var cam := Camera3D.new()
	host.add_child(cam)
	Game.camera = cam
	Game.set_process(false)
	Game.set_process_input(false)
	var only := OS.get_environment("TRACKS")
	for key in gold:
		var parts: PackedStringArray = key.split("/")
		var tr := parts[0]
		var carId := parts[1]
		if not tr in TrackLoader.ported() or (only != "" and not tr in only.split(",")): continue
		var S := G.settings
		S.track = tr; S.dir = "fwd"; S.mode = "ghost"; S.laps = 1; S.car = carId; S.grid = "back"
		Game.state = "menu"
		TrackLoader.load_track(tr, "fwd")
		env.apply("day", "dry", true)
		Game.rebuildPlayerCar()
		Game.startRace()
		resets = 0
		step(4.5, false)
		var t := 0.0
		while t < 300 and not Game.raceDone:
			step(2)
			t += 2
		var h: Dictionary = gold[key]
		var tol := 3.0 if TrackDefs.TRACKS[tr].get("wind", false) else 0.15
		r.check(Game.raceDone, "%s %s: ronde uitgereden" % [tr, carId])
		r.check(absf(Game.raceFinishTime - h.ft) < tol, "%s %s: finishtijd gelijk" % [tr, carId], "godot %.3f, html %.3f s" % [Game.raceFinishTime, h.ft])
		if not Game.lapTimes.is_empty() and not h.laps.is_empty():
			r.check(absf(Game.lapTimes[0] - h.laps[0]) < tol, "%s %s: rondetijd gelijk" % [tr, carId], "godot %.3f, html %.3f s" % [Game.lapTimes[0], h.laps[0]])
		r.check(absf(Game.raceTopSpeed - h.top) < 0.5, "%s %s: topsnelheid gelijk" % [tr, carId], "godot %.1f, html %.1f km/u" % [Game.raceTopSpeed * 3.6, h.top * 3.6])
		r.check(resets == int(h.resets), "%s %s: zelfde aantal keer terug op de baan" % [tr, carId], "godot %d, html %d" % [resets, h.resets])
	Game.set_process(true)
	Game.set_process_input(true)
	return r

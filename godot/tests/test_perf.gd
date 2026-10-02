extends RefCounted
## CPU cost of the race simulation (headless, no rendering): ms per simulated second with 7 bots, and track load times.
## Budget: the simulation of one second must take well under 1 s of one core (60 fps leaves ~16 ms a frame for everything).

func run(host: Node) -> TestReport:
	var r := TestReport.new("snelheid van de simulatie")
	var L = load("res://tests/test_laps.gd").new()
	var env := Env.new()
	host.add_child(env)
	World.root = Node3D.new()
	host.add_child(World.root)
	var cam := Camera3D.new()
	host.add_child(cam)
	Game.camera = cam
	Game.set_process(false)
	var S := G.settings
	for tr in ["polder", "veluwe", "rotterdam"]:
		var t0 := Time.get_ticks_usec()
		TrackLoader.load_track(tr, "fwd")
		var load_ms := (Time.get_ticks_usec() - t0) / 1000.0
		r.check(load_ms < 4000, "%s: baan laden" % tr, "%.0f ms" % load_ms)
		S.track = tr; S.mode = "race"; S.bots = 7; S.laps = 3; S.car = "gt"
		Game.state = "menu"; Game.rebuildPlayerCar(); Game.startRace()
		L.step(5.0, false)
		t0 = Time.get_ticks_usec()
		L.step(10.0)
		var per_s := (Time.get_ticks_usec() - t0) / 1000.0 / 10.0
		r.check(per_s < 250, "%s: race met 7 bots, 120 Hz" % tr, "%.1f ms rekentijd per gesimuleerde seconde (%.2f ms per frame bij 60 fps)" % [per_s, per_s / 60])
	Game.set_process(true)
	return r

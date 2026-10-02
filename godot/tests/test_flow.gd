extends RefCounted
## Race flow per mode with the test autopilot (tests/test_laps.gd): ghost (the first lap becomes the ghost, the second
## lap drives against it), race with bots (finish, results), elimination (bots drop out), time trial (time runs out),
## and the replay (record, open, play, close).

var L

func run(host: Node) -> TestReport:
	var r := TestReport.new("spelverloop per modus")
	L = load("res://tests/test_laps.gd").new()
	var env := Env.new()
	host.add_child(env)
	if Fx.me == null: host.add_child(Fx.new())     # skid marks, smoke, the headlight
	World.root = Node3D.new()
	host.add_child(World.root)
	var cam := Camera3D.new()
	host.add_child(cam)
	Game.camera = cam
	Game.set_process(false)
	Game.set_process_input(false)
	var S := G.settings
	S.track = "polder"; S.dir = "fwd"; S.car = "super"; S.grid = "back"
	TrackLoader.load_track("polder", "fwd")
	# ---- ghost: 2 laps
	G.store_set(Rep.ghostKey("polder", "S"), "null")
	S.mode = "ghost"; S.laps = 2
	Game.state = "menu"; Game.rebuildPlayerCar(); Game.startRace()
	L.step(4.5, false)
	_drive_until(func(): return Game.player.lap >= 2, 120)
	r.check(Rep.ghostBest != null, "ghost: eerste ronde opgeslagen als ghost", "t=%s" % (Rep.ghostBest.t if Rep.ghostBest else "-"))
	L.step(10)
	Rep.ghostUpdate()
	r.check(Rep.ghostCar != null and Rep.ghostCar.g.visible, "ghost: doorzichtige auto rijdt mee in ronde 2")
	r.check(Rep.ghostDelta() != null, "ghost: verschil met de ghost wordt getoond", str(Rep.ghostDelta()))
	_drive_until(func(): return Game.raceDone, 120)
	r.check(Game.raceDone and Game.lapTimes.size() == 2, "ghost: 2 ronden gereden", str(Game.lapTimes))
	# ---- race with bots, 1 lap
	S.mode = "race"; S.laps = 1; S.bots = 3
	Game.state = "menu"; Game.startRace()
	r.check(Game.bots.size() == 3, "race: 3 bots op de grid")
	L.step(4.5, false)
	_drive_until(func(): return Game.state == "over", 200)
	r.check(Game.state == "over", "race: uitgereden, uitslag getoond", Game.state)
	r.check(Game.resultRows.size() == 4, "race: uitslag met 4 rijders", str(Game.resultRows.size()))
	var bots_moved := Game.bots.all(func(b): return b.lap >= 1)
	r.check(bots_moved, "race: alle bots over de startlijn", str(Game.bots.map(func(b): return b.lap)))
	r.check(Rep.canReplay(), "replay: opgenomen", "%d frames" % (Rep.replay.frames.size() if Rep.replay else 0))
	Game.overReady = true
	Rep.replayOpen()
	r.check(Game.state == "replay", "replay: geopend")
	for _i in 120: Rep.replayUpdate(1.0 / 60)
	r.check(Rep.rp != null and Rep.rp.t > 1.9, "replay: speelt af")
	Rep.replayClose()
	r.check(Game.state == "over", "replay: terug naar de uitslag")
	# ---- elimination: 2 bots -> 2 laps, someone drops out each lap
	S.mode = "elim"; S.bots = 2
	Game.state = "over"; Game.overReady = true; Game.startRace()
	r.check(Game.raceLaps == 2, "eliminatie: ronden = aantal bots", str(Game.raceLaps))
	L.step(4.5, false)
	_drive_until(func(): return Game.state == "over" or Game.playerOut, 260)
	var outs := Game.bots.filter(func(b): return b.out).size() + (1 if Game.playerOut else 0)
	r.check(outs >= 1, "eliminatie: er valt iemand af", "%d eruit" % outs)
	# ---- split screen: 2 players, 2 bots, 1 lap
	S.mode = "split"; S.bots = 2; S.laps = 1; S.p2car = "hatch"
	Game.state = "over"; Game.overReady = true; Game.startRace()
	r.check(Game.split and Game.p2 != null and Game.p2.car != null, "2 spelers: tweede speler met eigen auto")
	r.check(Game.bots.size() == 2, "2 spelers: 2 bots")
	r.check(Fx.me.headL.get_parent() == Game.car.g, "2 spelers: de koplamp blijft op de auto van speler 1")
	var p1s: float = Game.player.s
	L.step(1.0, false)
	r.check(Game.state == "countdown" and Game.p2.pl.gasIn > 0.9 and Game.p2.pl.speed == 0, "2 spelers: gas van speler 2 tijdens het aftellen (toerental)",
		"%s, gas %.1f" % [Game.state, Game.p2.pl.gasIn])
	L.step(3.5, false)
	L.step(20)
	r.check(Game.player.s != p1s and Game.p2.pl.speed > 5, "2 spelers: allebei rijden", "p1 %.0f m/s, p2 %.0f m/s" % [Game.player.speed, Game.p2.pl.speed])
	r.check(Game.otherProgress() != null, "2 spelers: voortgang van speler 2 telt mee")
	_drive_until(func(): return Game.state == "over", 220)
	r.check(Game.state == "over", "2 spelers: uitslag na de finish", Game.state)
	r.check(Game.resultRows.filter(func(x): return x.get("me", false)).size() == 2, "2 spelers: allebei in de uitslag")
	var rc: Array = Rep.replay.cars
	r.check(rc.size() == 4 and rc[3].name == "Speler 2" and Rep.replay.frames[-1].size() == 20, "2 spelers: speler 2 staat in de replay",
		str(rc.map(func(x): return x.name)))
	var p2s: float = Game.p2.pl.s
	L.step(2.0, false)
	r.check(absf(Trk.wrapD(Game.p2.pl.s - p2s)) > 10, "2 spelers: speler 2 rijdt na de uitslag door (autopiloot)", "%.0f m" % Trk.wrapD(Game.p2.pl.s - p2s))
	Game.toMenu(-1)
	r.check(not Game.split and Game.p2 == null, "2 spelers: opgeruimd na het menu")
	# ---- time trial: runs out of time
	S.mode = "time"
	Game.state = "over"; Game.overReady = true; Game.startRace()
	r.check(Game.traffic.size() == int(Trk.TRK.get("traffic", 0)), "tijdrit: verkeer op de baan", str(Game.traffic.size()))
	L.step(5.5, false)
	Game.timeLeft = 6.0
	L.step(8)
	r.check(Game.state == "over", "tijdrit: tijd is op", Game.state)
	r.check(Game.distance > 50, "tijdrit: afstand gemeten", G.fmtKm(Game.distance))
	# ---- quit a race at speed: no speed blur left in the menu
	S.mode = "race"; S.bots = 1; S.laps = 3
	Game.state = "over"; Game.overReady = true; Game.startRace()
	L.step(4.5, false)
	L.step(12)
	Game.updateCamera(1.0 / 60)
	var fxRace: float = Game.speedFx
	Game.toMenu(-1)
	Game.updateCamera(1.0 / 60)
	r.check(fxRace > 0.3 and Game.speedFx == 0, "stoppen tijdens de race: geen snelheidseffect in het menu", "race %.2f, menu %.2f" % [fxRace, Game.speedFx])
	Game.set_process(true)
	Game.set_process_input(true)
	return r

func _drive_until(cond: Callable, max_s: float) -> void:
	var t := 0.0
	while t < max_s and not cond.call():
		L.step(1.0)
		t += 1.0

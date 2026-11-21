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
	var br: Array = Hud.boardRows()
	r.check(br.size() == 2 and br[1].name == "Ghost" and absf(br[1].best - float(Rep.ghostBest.t)) < 1e-6, "ghost: rondetijdenbord met Jij en de ghost",
		str(br.map(func(x): return x.name)))
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
	# player 2's camera follows with the frame's own time step (it used a fixed 1/60: twice as fast at 120 fps)
	var svPrev = SplitView.me
	var sv := SplitView.new()
	host.add_child(sv)
	var turn := func(dt: float) -> float:
		Game.p2.camHeading = Game.p2.pl.heading + 0.6
		SplitView.me.tick(dt)
		return absf(Game.p2.camHeading - (Game.p2.pl.heading + 0.6))
	var big: float = turn.call(0.05)
	var small: float = turn.call(0.0125)
	r.check(small > 0 and big / small > 2.5, "2 spelers: camera van speler 2 volgt met de echte frametijd", "50 ms: %.3f rad, 12,5 ms: %.3f rad" % [big, small])
	# and its field of view widens with its own speed, not player 1's (player 1 stands still here)
	var sp2: float = Game.p2.pl.speed
	Game.p2.pl.speed = 80.0
	for _i in 120:
		cam.fov = 58.0
		sv.tick(1.0 / 60)
	r.check(sv.cam2.fov > 68.0, "2 spelers: camera van speler 2 zoomt uit met zijn eigen snelheid", "fov %.1f (speler 1: 58)" % sv.cam2.fov)
	Game.p2.pl.speed = sp2
	# player 2 in the bumper view: player 2's half leaves out its own car, player 1 still sees it
	Game.p2.cam = 2
	sv.tick(1.0 / 60)
	var b2 := 1 << (Game.P2_LAYER - 1)
	var vis: bool = Game.p2.car.g.visible and Game.p2.car.g.find_children("*", "VisualInstance3D", true, false).all(func(n): return n.layers == b2)
	r.check(vis and (sv.cam2.cull_mask & b2) == 0 and (sv.cam1.cull_mask & b2) != 0, "2 spelers: bumpercamera van speler 2 verbergt zijn auto alleen in zijn eigen helft",
		"zichtbaar %s, camera 1 %x, camera 2 %x" % [str(vis), sv.cam1.cull_mask, sv.cam2.cull_mask])
	Game.p2.cam = 0
	sv.tick(1.0 / 60)
	# a gust on a windy track pushes player 2 too
	var trk0: Dictionary = Trk.TRK
	Trk.TRK = trk0.duplicate()
	Trk.TRK["wind"] = true
	Game.gustPhase = 1.2; Game.gustT = 0.0; Game.gustDir = 1.0
	var sl0: Vector2 = Game.p2.pl.slide
	Game.updateWind(0.1)
	var pushed: float = (Game.p2.pl.slide - sl0).length()
	Trk.TRK = trk0
	Game.gustPhase = 0.0
	r.check(pushed > 0.1, "2 spelers: een windvlaag duwt ook speler 2 opzij", "%.2f m/s" % pushed)
	# player 2 switches camera (Numpad1): player 1's saved camera preference stays as it was
	var camBefore = JSON.parse_string(str(G.store_get("polderrace3d-prefs", "{}"))).get("cam", 0)
	G.prefs.cam = 2
	G.savePrefs()
	Game.asP2(func(): Game.cycleCam())
	var camAfter = JSON.parse_string(str(G.store_get("polderrace3d-prefs", "{}"))).get("cam", 0)
	r.check(int(camAfter) == 2 and Game.p2.cam == 1 and int(G.prefs.cam) == 2, "2 spelers: camera van speler 2 wisselen bewaart niets als voorkeur van speler 1",
		"opgeslagen %s (was %s), speler 2 %s" % [str(camAfter), str(camBefore), str(Game.p2.cam)])
	G.prefs.cam = 0
	G.savePrefs()
	Game.p2.cam = 0
	if sv._main_mask != 0: cam.cull_mask = sv._main_mask
	sv.queue_free()
	SplitView.me = svPrev
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
	# the far hills (no fog of their own) fade into the fog instead of standing sharp above the fog bank
	var hm := Mats.basic(0x3f5a3a, {"fog": false})
	hm.set_meta("base", MathX.col(0x3f5a3a)); hm.set_meta("k", 0.62)
	World.hillMats.append(hm)
	env.apply("day", "fog", true)
	var dFog: float = Vector3(hm.albedo_color.r - env.fog_color.r, hm.albedo_color.g - env.fog_color.g, hm.albedo_color.b - env.fog_color.b).length()
	env.apply("day", "dry", true)
	var dDry: float = Vector3(hm.albedo_color.r - env.fog_color.r, hm.albedo_color.g - env.fog_color.g, hm.albedo_color.b - env.fog_color.b).length()
	World.hillMats.erase(hm)
	r.check(dFog < 0.06 and dDry > 0.15, "verre heuvels verdwijnen in de mist", "verschil met de mistkleur: mist %.3f, droog %.3f" % [dFog, dDry])
	# a gust that was blowing when the race ended: the rain does not keep streaming sideways in the menu / next race
	env.wind_x = 20.0
	Game.updateWind(0.1)
	r.check(env.wind_x == 0.0, "na de race: geen zijwind meer in de regen", str(env.wind_x))
	# in the ditch: the car is put back on the dike and the camera jumps along (it eased up from below: car off screen)
	Game.state = "racing"
	var hi := 0
	for i in Trk.NS:
		if Trk.HT[i] > Trk.HT[hi]: hi = i
	Game.resetPlayer(hi, 0)
	Game.camY = Game.player.y - 6
	Game.player.pos += Vector3(Trk.R[hi].x, 0, Trk.R[hi].z) * (Trk.EDGE[hi] + 1.5)
	Game.locatePlayer()
	Game.edges(hi, sin(Game.player.heading), cos(Game.player.heading), 0.01)
	r.check(Trk.TRK.edge == "ditch" and absf(Game.player.lat) < Trk.ROAD_HALF and absf(Game.camY - Game.player.y) < 0.01,
		"in de sloot: camera springt mee naar de auto op de dijk", "lat %.1f, camY %.2f, auto %.2f" % [Game.player.lat, Game.camY, Game.player.y])
	# a lorry stopped right behind you: the chase camera rises over it instead of looking out from inside it
	Game.resetPlayer(40, Trk.LANES[0])
	Game.snapCamera()
	var tm := Vehicles.makeTruck()
	host.add_child(tm.g)
	var tr := Mover.new()
	tr.m = tm; tr.lat = Trk.LANES[0]; tr.s = fposmod(Game.player.s - 8.0, Trk.TRACK_LEN)
	Game.poseOnTrack(tm.g, tr.s, tr.lat)
	Game.traffic.append(tr)
	for _i in 40: Game.updateCamera(1.0 / 60)
	var top: float = tm.g.global_position.y + Game.carHeight(tm)
	r.check(Game.carHeight(tm) > 3.5 and cam.global_position.y > top + 0.2, "camera komt over een vrachtwagen vlak achter je", "camera %.2f, dak %.2f" % [cam.global_position.y, top])
	Game.traffic.erase(tr)
	tm.g.queue_free()
	for _i in 120: Game.updateCamera(1.0 / 60)
	r.check(Game.player.camDodge < 0.05, "en zakt daarna weer terug", "%.2f m" % Game.player.camDodge)
	# the results come up while the pause screen is open (online the race goes on behind it): the pause screen goes
	Game.setPaused(true)
	Game.state = "finished"
	Game.showResults()
	r.check(not Game.paused and not Menu.pauseOv.visible and Menu.overOv.visible, "uitslag sluit het pauzescherm", "pauze %s" % str(Game.paused))
	Game.toMenu(-1)
	# the replay's trackside camera in a town stands over the pavement, not inside the houses beyond the shoulder
	TrackLoader.load_track("dorp", "fwd")
	var far := 0.0
	for k in 8:
		var j := k * Trk.NS / 8
		var c: Vector3 = Rep.trackCam(j, 1.0 if k % 2 else -1.0)
		far = maxf(far, Vector2(c.x, c.z).distance_to(_nearest(c)))
	r.check(far < Trk.SHOULDER - 0.5, "replay: camera langs de baan in het dorp staat op de stoep, niet in de huizen", "%.1f m van de weg (huizen vanaf %.1f m)" % [far, Trk.SHOULDER])
	TrackLoader.load_track("polder", "fwd")
	Game.set_process(true)
	Game.set_process_input(true)
	return r

func _drive_until(cond: Callable, max_s: float) -> void:
	var t := 0.0
	while t < max_s and not cond.call():
		L.step(1.0)
		t += 1.0

## the centre line point nearest to c (x, z)
func _nearest(c: Vector3) -> Vector2:
	var best := Vector2.ZERO
	var bd := INF
	for p in Trk.P:
		var d := Vector2(p.x - c.x, p.z - c.z).length_squared()
		if d < bd: bd = d; best = Vector2(p.x, p.z)
	return best

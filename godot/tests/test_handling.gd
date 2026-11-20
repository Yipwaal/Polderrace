extends RefCounted
## Handling and collisions (tests/handling_lib.gd drives the car with exact inputs through Game.update):
##  - what must not change: acceleration, top speed, braking distance and steady cornering (the game's pace)
##  - the limit: a wet road brakes longer and corners slower; braking or lifting in a corner turns the car in but never
##    spins it; power slides only in cars that have the power for it; the handbrake starts a slide you can catch
##  - verges, gravel, walls (a glancing hit costs little, the car never sticks or goes through), hills
##  - the same input gives the same result, also at 30 frames per second
##  - collisions (the HTML project's tests/test_collisions.py): a light tap does nothing, a PIT spins the other car,
##    straight into the back turns nobody, a tap is not a brake
##  - grid and reset: no car starts or lands inside another one
##  - the body leans and the wheels stay on the road; nothing moves at standstill or in a pause
##  - bots: they race each other without wrecking, leave the player room, and the race stays winnable

var H
var r: TestReport

func run(host: Node) -> TestReport:
	r = TestReport.new("rijgedrag en botsingen")
	H = load("res://tests/handling_lib.gd").new()
	H.setup(host)
	var only := OS.get_environment("HANDLING").split(",", false)
	var parts := {"pace": pace, "limit": limit, "ground": ground, "same": same, "hits": hits, "places": places, "body": body, "bots": bots}
	for k in parts:
		if only.is_empty() or k in only: parts[k].call()
	H.done()
	return r

func near(a: float, b: float, rel: float) -> bool:
	return absf(a - b) <= absf(b) * rel

# ------------------------------------------------------------------ the game's pace stays what it was
## measured with the handling of before 20 November 2026: [0-100 s, 0-200 s, top km/h, braking distance from 100 and 200 km/h (m)]
const PACE := {"hatch": [4.125, 16.133, 215.0, 16.13, 64.72], "gt": [3.842, 11.167, 249.9, 17.75, 71.22], "super": [2.958, 7.258, 305.0, 15.65, 62.82]}

func pace() -> void:
	for car in PACE:
		var P: Array = PACE[car]
		var a: Dictionary = H.accel(car)
		r.check(near(a.t100, P[0], 0.03) and near(a.t200, P[1], 0.03) and near(a.top, P[2], 0.01), "%s: optrekken en topsnelheid als voorheen" % car,
			"0-100 %.2f s, 0-200 %.2f s, top %.0f km/u" % [a.t100, a.t200, a.top])
		var b1: Dictionary = H.braking(car, 100)
		var b2: Dictionary = H.braking(car, 200)
		r.check(near(b1.dist, P[3], 0.03) and near(b2.dist, P[4], 0.03), "%s: remweg droog als voorheen" % car, "%.1f m en %.1f m" % [b1.dist, b2.dist])
		var w: Dictionary = H.braking(car, 200, "rain")
		r.check(w.dist > b2.dist * 1.05 and w.dist < b2.dist * 1.2, "%s: in de regen is de remweg langer" % car, "%.1f m tegen %.1f m" % [w.dist, b2.dist])
		# steady cornering at full lock: the lateral grip the game was built on (turn rate x speed)
		for kmh in [100, 200]:
			if kmh / 3.6 > Game.MAXV: continue
			var s: Dictionary = H.skidpad(car, kmh)
			var vv: float = s.kmh / 3.6
			var want: float = H.lat_limit(vv) / 9.81
			r.check(near(s.g, want, 0.04) and absf(s.beta) < 6, "%s: bocht op %d km/u op de grip-limiet, zonder te glijden" % [car, kmh],
				"%.2f g (ontwerp %.2f), sliphoek %.1f gr" % [s.g, want, s.beta])
		var wet: Dictionary = H.skidpad(car, 100, 1.0, "rain")
		var dry: Dictionary = H.skidpad(car, 100)
		r.check(wet.g < dry.g * 0.9 and wet.g > dry.g * 0.78, "%s: nat wegdek, minder grip in de bocht" % car, "%.2f g tegen %.2f g" % [wet.g, dry.g])
		var st: Dictionary = H.step_steer(car, 150, true)
		r.check(st.t90 > 0.12 and st.t90 < 0.5 and st.over < 20, "%s: sturen met toetsen: snel en zonder doorschieten" % car,
			"90 %% van de draaisnelheid na %.2f s, doorschot %.0f %%" % [st.t90, st.over])

# ------------------------------------------------------------------ at and over the limit
func limit() -> void:
	for car in ["hatch", "gt", "muscle", "super", "proto", "mini"]:
		var l: Dictionary = H.mid_corner(car, 120, 0.9, 0.0)
		r.check(not l.spun and l.betaMax < 20 and l.yawPeak > 1.03, "%s: gas los in de bocht: de neus draait in, de auto spint niet" % car,
			"draaisnelheid x%.2f, sliphoek max %.0f gr" % [l.yawPeak, l.betaMax])
		var b: Dictionary = H.mid_corner(car, 120, 0.9, 1.0)
		r.check(not b.spun and b.betaMax < 25, "%s: vol remmen in de bocht: geen spin" % car, "sliphoek max %.0f gr, na 1 s %.0f km/u" % [b.betaMax, b.v1s])
		var bw: Dictionary = H.mid_corner(car, 120, 0.9, 1.0, "rain")
		r.check(not bw.spun and bw.betaMax < 25, "%s: vol remmen in de bocht in de regen: geen spin" % car, "sliphoek max %.0f gr" % bw.betaMax)
		var p: Dictionary = H.power_exit(car, 60, true)
		var drv: String = Game.handling(car).drv
		if car == "muscle":
			r.check(p.betaMax > 12 and p.betaMax < 45 and absf(p.liftEnd) < 12, "muscle: vol gas uit de bocht geeft een powerslide die stopt als je gas loslaat",
				"sliphoek max %.0f gr, 1 s na gas los %.0f gr" % [p.betaMax, p.liftEnd])
		else:
			r.check(p.betaMax < (9.0 if drv != "r" else 16.0) and absf(p.liftEnd) < 6, "%s: vol gas uit de bocht blijft beheersbaar" % car, "sliphoek max %.0f gr" % p.betaMax)
		var h: Dictionary = H.handbrake(car, 80)
		r.check(h.betaMax > 30 and h.tRecover > 0 and h.tRecover < 1.6, "%s: handrem zet de auto dwars en je vangt hem weer op" % car,
			"sliphoek max %.0f gr, %.0f gr gedraaid, recht na %.2f s" % [h.betaMax, h.turned, h.tRecover])
		var h0: Dictionary = H.handbrake(car, 80, 0.7, false)
		r.check(h0.tRecover > 0 and h0.tRecover < 2.0, "%s: na de handrem komt de auto ook zonder tegensturen recht" % car, "na %.2f s" % h0.tRecover)
		var s: Dictionary = H.slide_recover(car, 100, 30)
		r.check(s.tRecover > 0 and s.tRecover < 1.2 and s.overshoot < 8, "%s: een slip van 30 graden herstelt zonder slingeren" % car,
			"recht na %.2f s, doorschot %.1f gr" % [s.tRecover, s.overshoot])
	# every model: the worst a keyboard can do (full lock with full gas, then full lock with full brakes) never spins the car
	var bad := []
	for car in Cars.CARS:
		var p: Dictionary = H.power_exit(car, 50, true)
		var b: Dictionary = H.mid_corner(car, 150, 1.0, 1.0)
		if p.betaMax > 45 or b.spun or b.betaMax > 30 or absf(p.liftEnd) > 12: bad.append("%s gas %.0f/%.0f rem %.0f" % [car, p.betaMax, p.liftEnd, b.betaMax])
	r.check(bad.is_empty(), "alle 18 auto's: vol sturen met vol gas of vol remmen spint de auto niet", str(bad))

# ------------------------------------------------------------------ verges, walls, hills
func ground() -> void:
	var road: Dictionary = H.surface("polder", "gt", 0.0, 150)
	var verge: Dictionary = H.surface("polder", "gt", 9.6, 150)
	r.check(road.lost < 0 and verge.lost > 40, "polder: de berm remt af, de weg niet", "weg %+.0f km/u, berm %+.0f km/u in 3 s" % [-road.lost, -verge.lost])
	var edge: Dictionary = H.surface("polder", "gt", 7.3, 150)
	r.check(edge.lost < verge.lost * 0.5, "polder: met twee wielen in de berm verlies je minder dan met vier", "%.0f tegen %.0f km/u" % [edge.lost, verge.lost])
	var grass: Dictionary = H.surface("circuit", "gt", 11.0, 150)
	var gravel: Dictionary = H.surface("circuit", "gt", 16.0, 150)
	r.check(grass.lost > 30 and gravel.lost > grass.lost + 20, "circuit: gras remt, grind remt harder", "gras %.0f, grind %.0f km/u in 3 s" % [grass.lost, gravel.lost])
	for car in ["hatch", "super"]:
		var w15: Dictionary = H.wall("haven", car, 15, 120)
		r.check(w15.hitAt > 0 and w15.vAfter > 85 and w15.free > 1.0 and w15.deep <= 0.06, "%s: muur schampen (15 gr) kost weinig en je stuurt er zo weer vanaf" % car,
			"na 1,2 s %.0f km/u, daarna %.1f m van de muur" % [w15.vAfter, w15.free])
		var w45: Dictionary = H.wall("haven", car, 45, 120)
		r.check(w45.vMin > 25 and w45.vMin < 90 and w45.free > 1.0 and absf(w45.angAfter) < 12, "%s: schuin de muur in (45 gr) kost flink snelheid, de auto komt langs de muur" % car,
			"laagste %.0f km/u, hoek daarna %.0f gr" % [w45.vMin, w45.angAfter])
		var w80: Dictionary = H.wall("haven", car, 80, 120)
		r.check(w80.hitAt > 0 and w80.vMin < 30 and w80.free > 0.5 and w80.deep <= 0.06, "%s: recht de muur in: stilstand, niet erdoorheen en je komt weer weg" % car,
			"laagste %.0f km/u, %.1f m van de muur na 0,8 s wegsturen" % [w80.vMin, w80.free])
		var wf: Dictionary = H.wall("afsluitdijk", car, 20, 250)
		r.check(wf.deep <= 0.06 and wf.vAfter > 120, "%s: op 250 km/u tegen de muur: niet erdoorheen" % car, "diepste %.2f m, daarna %.0f km/u" % [wf.deep, wf.vAfter])
	# hills: the car follows the road (no jumps in height), the body stays close to it
	for tr in ["veluwe", "limburg"]:
		H.start(tr, "super"); Game.raceLaps = 99; H.countdown()
		var jump := 0.0
		var y0: float = Game.player.y
		var gap := 0.0
		var t := 0.0
		var lo := 2.0; var hi := 0.0
		while t < 45:
			H.drive_step(1.2, false); t += H.DT
			var dy: float = absf(Game.player.y - y0) - H.v() * H.DT * 0.25      # more than a 25 % slope in one step is a jump
			y0 = Game.player.y
			jump = maxf(jump, dy)
			lo = minf(lo, Game.player.load); hi = maxf(hi, Game.player.load)
			if int(t * 120) % 4 == 0:
				Game.syncCar(4 * H.DT)
				gap = maxf(gap, absf(Game.car.g.position.y - Game.player.y))
		r.check(jump < 0.02 and gap < 0.08, "%s: de auto volgt de weg over de heuvels zonder sprongen" % tr, "grootste sprong %.3f m, carrosserie max %.3f m van de weg" % [jump, gap])
		r.check(lo < 0.97 and lo >= 0.85 and hi > 1.02, "%s: licht over een heuveltop, zwaar in een dal" % tr, "wieldruk %.2f tot %.2f" % [lo, hi])

# ------------------------------------------------------------------ same input, same result
func _run_once(dt: float) -> Vector3:
	H.start("haven", "gt"); H.free_plane(); H.put(40, 0, 0, 30)
	var n := int(round(6.0 / dt))
	for k in n:
		var t := k * dt
		var steer := 1.0 if t < 1.5 else (-0.6 if t < 3.0 else 0.4)
		var brake := 1.0 if (t > 2.6 and t < 3.0) else 0.0
		Game.keysDown.clear()
		Game.pad = {"steer": steer, "gas": 0.0 if brake > 0 else 1.0, "brake": brake, "hand": t > 4.0 and t < 4.4, "look": false}
		Game.update(dt)
	return Vector3(Game.player.pos.x, Game.player.heading, Game.player.pos.z)

func same() -> void:
	var a := _run_once(1.0 / 120)
	var b := _run_once(1.0 / 120)
	r.check(a == b, "zelfde invoer geeft precies hetzelfde resultaat", str(a))
	var c := _run_once(1.0 / 30)
	var d := Vector2(a.x - c.x, a.z - c.z).length()
	r.check(d < 6.0 and absf(H.angDiff(a.y, c.y)) < 0.25, "30 beelden per seconde rijdt als 120 (zelfde bochten, remmen, handrem)", "%.1f m verschil na 6 s en ruim 250 m" % d)
	var e := _run_once(1.0 / 144)
	d = Vector2(a.x - e.x, a.z - e.z).length()
	r.check(d < 4.0, "144 beelden per seconde rijdt als 120", "%.1f m verschil na 6 s" % d)

# ------------------------------------------------------------------ collisions (tests/test_collisions.py of the HTML project)
var A: Mover
var B: Mover
const I0 := 40

func _set_bot(b: Mover, s: float, lat: float, v: float) -> void:
	b.s = s; b.lat = lat; b.gridLat = lat; b.lap = 0; b.speed = v; b.cur = v; b.vmax = v; b.lp = 0; b.latV = 0; b.spin = 0; b.yawOff = 0
	b.spun = false; b.yawK = 0; b.slideT = 0; b.passT = 0; b.slowT = 0; b.mistT = 1e9; b.contactT = 0; b.noAvoid = true; b.pushDv = 0
	Game.poseOnTrack(b.m.g, b.s, b.lat, 0)

func _place(o: Dictionary) -> void:
	Game.paused = false; Game.state = "racing"
	_set_bot(A, I0 * Trk.SPC, o.botLat, o.botV)
	_set_bot(B, fmod(I0 * Trk.SPC + 900, Trk.TRACK_LEN), 0, o.botV)
	var a := Trk.trackAt(I0 * Trk.SPC + o.pDs)
	Game.resetPlayer(I0, 0)
	var pl := Game.player
	pl.pos = Vector3(a.px + a.rx * o.pLat, 0, a.pz + a.rz * o.pLat)
	pl.heading = atan2(a.tx, a.tz) + o.pAng
	pl.speed = o.pV
	Game.drift = 0
	Game.locatePlayer()
	while pl.gear < 6 and pl.speed > Game.gearTop(pl.gear) * 0.9: pl.gear += 1

func _steer(o: Dictionary, k: int) -> float:
	var pl := Game.player
	var th := Trk.heading_of(Trk.T[pl.idx])
	var want: float = th + (o.pAng if k < o.steerFrames else clampf((pl.lat - o.pLat) * 0.12, -0.12, 0.12))
	return clampf(-H.angDiff(want, pl.heading) * 4, -1, 1)

## one scenario: the player drives at bot A as described by o; what happened to both
func scn(o: Dictionary) -> Dictionary:
	seed(12345)
	_place(o)
	var m := {"botYaw": 0.0, "botLp": 0.0, "pSpin": 0.0, "pSlide": 0.0, "botDLat": 0.0, "pTurn": 0.0}
	var lat0: float = A.lat
	for k in int(120 * o.T):
		var pl := Game.player
		H.tick(_steer(o, k), 1.0 if pl.speed < o.pV else 0.0, 0)
		m.botYaw = maxf(m.botYaw, absf(A.yawOff)); m.botLp = maxf(m.botLp, absf(A.lp)); m.pSpin = maxf(m.pSpin, absf(pl.spin))
		m.pSlide = maxf(m.pSlide, pl.slide.length()); m.botDLat = maxf(m.botDLat, absf(A.lat - lat0))
		m.pTurn = maxf(m.pTurn, absf(H.angDiff(pl.heading, Trk.heading_of(Trk.T[pl.idx]))))
	m.botYaw = rad_to_deg(m.botYaw)
	m.pTurn = rad_to_deg(m.pTurn)
	return m

## speed before the first contact and half a second after it (gas held all the time), in km/h
func tap(o: Dictionary) -> Dictionary:
	seed(12345)
	_place(o)
	var first := -1
	var v0 := 0.0; var b0 := 0.0
	var n := 0
	var prev := false
	for k in 360:
		var pl := Game.player
		var pv := pl.speed
		var bv := A.speed
		H.tick(_steer(o, k), 1, 0)
		var c: bool = Game.pairContact(Game.playerBody(), Game.bodyOf(A)) != null
		if c and not prev: n += 1
		prev = c
		if c and first < 0:
			first = k; v0 = pv; b0 = bv
		if first >= 0 and k - first == 60:
			return {"loss": (v0 - pl.speed) * 3.6, "bot": (A.speed - b0) * 3.6, "hits": n}
	return {"loss": 99.0, "bot": 0.0, "hits": n}

func hits() -> void:
	H.start("circuit", "gt", "dry", "fwd", 2, "normal", 5)
	H.countdown()
	Game.setupBots(0, [{"name": "A", "type": "gt", "color": "#ffffff"}, {"name": "B", "type": "gt", "color": "#222222"}])
	for b in Game.bots:
		b.acc = 15; b.aLat = 10; b.brk = 20
	A = Game.bots[0]; B = Game.bots[1]
	var m := scn({"botLat": 1.9, "botV": 30.0, "pDs": 0.0, "pLat": -0.35, "pV": 30.0, "pAng": -0.035, "steerFrames": 90, "T": 3.0})
	r.check(m.botYaw < 6 and m.pSpin < 0.3 and m.botLp < 2 and m.pTurn < 8, "lichte zijtik: niemand spint", str(m))
	m = scn({"botLat": 1.9, "botV": 30.0, "pDs": -3.6, "pLat": -1.9, "pV": 33.0, "pAng": -0.3, "steerFrames": 24, "T": 6.0})
	r.check(m.botYaw > 60, "PIT op achterhoek: bot spint", str(m))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bad := []
	for n in 30:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var ds := rng.randf_range(-4.2, 4.2)
		var close := rng.randf_range(0.3, 1.5)
		var v := rng.randf_range(18, 40)
		m = scn({"botLat": side * 1.9, "botV": v, "pDs": ds, "pLat": side * (1.9 - 2.3), "pV": v, "pAng": -side * close / v, "steerFrames": int(rng.randf_range(30, 70)), "T": 2.5})
		if m.botYaw >= 10 or m.pSpin >= 0.6 or m.pTurn >= 15: bad.append([n, m])
	r.check(bad.is_empty(), "30 willekeurige lichte tikjes, geen te heftige reactie", str(bad.slice(0, 3)))
	# straight into the back of a bot: pushes it straight, it must not turn; off-centre hits turn it a little, the same to either side
	var yaws := {}
	for q in [[10, 0.0], [14, 0.0], [23, 0.0], [14, 0.6], [14, -0.6]]:
		var bv := 22.0 if q[0] == 23 else 30.0
		m = scn({"botLat": 0.0, "botV": bv, "pDs": -6.5, "pLat": q[1], "pV": bv + q[0], "pAng": 0.0, "steerFrames": 0, "T": 3.0})
		yaws[q] = [m.botYaw, m.pSpin]
	var straight := true
	for q in yaws:
		if q[1] == 0.0 and (yaws[q][0] >= 5 or yaws[q][1] >= 0.3): straight = false
	r.check(straight, "recht van achteren (10-23 m/s verschil): niemand draait", str(yaws))
	var yl: float = yaws[[14, 0.6]][0]
	var yr: float = yaws[[14, -0.6]][0]
	r.check(absf(yl - yr) <= 2 and yl >= 1 and yl < 15, "scheef van achteren: links en rechts even veel", "%.1f en %.1f gr" % [yl, yr])
	var t := tap({"botLat": 1.9, "botV": 33.0, "pDs": -6.0, "pLat": -0.2, "pV": 40.0, "pAng": -0.03, "steerFrames": 80})
	r.check(t.loss < 8 and t.hits <= 3, "schampen bij inhalen remt je niet af", str(t))
	t = tap({"botLat": 0.0, "botV": 35.0, "pDs": -6.0, "pLat": 0.0, "pV": 38.0, "pAng": 0.0, "steerFrames": 0})
	r.check(t.loss < 8 and t.bot > 5, "tikje van achteren: bot gaat mee, jij houdt je snelheid grotendeels", str(t))
	# a bot hits the player on the rear corner (a PIT on you): you are turned round, and you get the car back
	seed(12345)
	_place({"botLat": 0.0, "botV": 30.0, "pDs": 0.0, "pLat": 0.0, "pV": 30.0, "pAng": 0.0})
	Game.player.spin = 3.0
	var turned := 0.0
	var h0: float = Game.player.heading
	for k in 300:
		H.tick(0, 0, 0)
		turned = maxf(turned, absf(H.angDiff(Game.player.heading, h0)))
	r.check(turned > 0.8 and Game.player.spin == 0.0 and absf(Game.player.yr) < 0.6, "een tik op je achterhoek draait je om, daarna is de auto weer rustig",
		"%.0f gr gedraaid, draaisnelheid daarna %.2f + %.2f rad/s" % [rad_to_deg(turned), Game.player.spin, Game.player.yr])
	# pile-up: the player stands still across the road and five bots arrive: nobody is thrown out of the world
	H.start("haven", "gt", "dry", "fwd", 5, "normal", 3)
	H.countdown()
	for k in 5 * 120: H.drive_step(1.0, true)
	var i := Game.player.idx
	Game.resetPlayer((i + 20) % Trk.NS, 0)
	Game.player.heading += PI / 2
	for k in 5: _set_bot(Game.bots[k], fposmod(Game.player.s - 30 - k * 9, Trk.TRACK_LEN), (k % 2) * 2.0 - 1.0, 40)
	for b in Game.bots: b.noAvoid = false; b.vmax = 60
	var far := 0.0
	var fin := true
	for k in 4 * 120:
		H.tick(0, 0, 0)
		var pl := Game.player
		if is_nan(pl.pos.x) or is_nan(pl.heading) or is_nan(pl.speed): fin = false
		far = maxf(far, absf(pl.lat))
		for b in Game.bots:
			if is_nan(b.s) or is_nan(b.lat): fin = false
			far = maxf(far, absf(b.lat))
	r.check(fin and far <= Game.botLatLimit() + 0.3 and absf(Game.player.speed) < 40, "kettingbotsing: iedereen blijft binnen de muren, geen onzin-waarden",
		"verste %.1f m uit het midden, speler %.0f km/u" % [far, Game.player.speed * 3.6])

# ------------------------------------------------------------------ nobody inside anybody: grid, reset, ditch
func _overlaps() -> int:
	var bodies := [Game.playerBody()]
	for b in Game.bots: bodies.append(Game.bodyOf(b))
	var n := 0
	for a in bodies.size():
		for k in range(a + 1, bodies.size()):
			if Game.pairContact(bodies[a], bodies[k]) != null: n += 1
	return n

func places() -> void:
	var bad := []
	for tr in ["dorp", "grachten", "polder", "circuit"]:
		for grid in ["back", "mid", "pole"]:
			var S := G.settings
			S.track = tr; S.dir = "fwd"; S.car = "v12"; S.grid = grid; S.mode = "race"; S.bots = 7; S.laps = 2; S.diff = "normal"
			if Trk.TRACK_ID != tr or H._dirty:
				TrackLoader.load_track(tr, "fwd"); H._dirty = false
			Game.state = "menu"
			Game.rebuildPlayerCar()
			Game.startRace()
			if _overlaps() > 0: bad.append(tr + "/" + grid)
			# the start: the first two seconds nobody touches anybody when the player just drives straight on
			if grid == "mid":
				H.countdown()
				var c0: int = Game.raceContacts
				var touch := 0
				for k in 3 * 120:
					H.drive_step(1.0, true)
					if k % 6 == 0: touch += _overlaps()
				if Game.raceContacts > c0 or touch > 0: bad.append("%s start: %d tikken, %d keer overlap" % [tr, Game.raceContacts - c0, touch])
	r.check(bad.is_empty(), "startopstelling met 7 bots: niemand staat in een ander en de eerste seconden raakt niemand elkaar", str(bad))
	# reset to the track with a bot parked exactly where the car would land
	H.start("polder", "gt", "dry", "fwd", 3, "normal", 3)
	H.countdown()
	for k in 3 * 120: H.drive_step(1.0, true)
	var pl := Game.player
	var lane: float = Trk.LANES[0]
	for l in Trk.LANES:
		if absf(l - pl.lat) < absf(lane - pl.lat): lane = l
	var b: Mover = Game.bots[0]
	b.s = pl.idx * Trk.SPC; b.lat = lane; b.speed = 0; b.vmax = 0
	Game.poseOnTrack(b.m.g, b.s, b.lat)
	Game.resetT = -9
	Game.resetToTrack()
	var th := Trk.heading_of(Trk.T[pl.idx])
	r.check(Game.pairContact(Game.playerBody(), Game.bodyOf(b)) == null and pl.speed == 0 and absf(H.angDiff(pl.heading, th)) < 1e-6 and absf(pl.lat) < Trk.ROAD_HALF,
		"terug op de baan: op een vrije plek, stil, in de rijrichting", "%.1f m achter de bot, lat %.1f" % [Trk.wrapD(b.s - pl.s), pl.lat])
	# the ditch: back on the road, standing still, the right way round
	H.start("polder", "gt")
	H.put(H.straight_i(), 6.0, 0.5, 40)
	var d0: int = H.ditches
	for k in 2 * 120:
		H.tick(0, 1, 0)
		if H.ditches > d0: break
	r.check(H.ditches > d0 and absf(Game.player.lat) < Trk.ROAD_HALF and absf(H.angDiff(Game.player.heading, Trk.heading_of(Trk.T[Game.player.idx]))) < 1e-6 and Game.player.yr == 0.0,
		"in de sloot: terug op de weg, in de rijrichting, zonder restslip", "lat %.1f" % Game.player.lat)

# ------------------------------------------------------------------ the body on its springs
func _wheel_gap(m: Dictionary) -> float:
	# how far the lowest point of a wheel is from the road under the car (the rig's own height is the road's)
	var g: Node3D = m.g
	var worst := 0.0
	for w in m.wheels:
		var p: Vector3 = g.transform * w.pivot.position
		worst = maxf(worst, absf(p.y - w.r - Game.player.y))
	return worst

func body() -> void:
	H.start("haven", "retro"); H.free_plane(); H.put(40, 0, 0, 33)
	var rollMax := 0.0; var pitchMax := 0.0; var pitchMin := 0.0
	var gapMax := 0.0
	for k in 6 * 120:
		var t := k / 120.0
		H.tick(1.0 if t < 2 else (0.0 if t < 3 else -1.0), 0.0 if (t > 2 and t < 3) else 1.0, 1.0 if (t > 2 and t < 3) else 0.0)
		if k % 2 == 0:
			Game.syncCar(1.0 / 60)
			rollMax = maxf(rollMax, absf(Game.car.g.rotation.z)); pitchMax = maxf(pitchMax, Game.car.g.rotation.x); pitchMin = minf(pitchMin, Game.car.g.rotation.x)
			gapMax = maxf(gapMax, _wheel_gap(Game.car))
	r.check(rollMax > 0.02 and rollMax < 0.09, "de carrosserie helt in de bocht", "max %.1f gr" % rad_to_deg(rollMax))
	r.check(pitchMax > 0.01 and pitchMax < 0.06 and pitchMin < -0.003, "duikt bij remmen, zakt achter door bij gas geven", "%.1f gr duik, %.1f gr hurk" % [rad_to_deg(pitchMax), rad_to_deg(-pitchMin)])
	r.check(gapMax < 0.035, "de wielen blijven op de weg terwijl de carrosserie beweegt", "max %.3f m" % gapMax)
	# standstill: nothing moves, also on bricks and in a pause
	H.start("dorp", "gt")
	for k in 60: H.tick(0, 0, 0)
	var moved := 0.0
	Game.syncCar(1.0 / 60)
	var p0: Vector3 = Game.car.g.position
	var r0: Vector3 = Game.car.g.rotation
	for k in 120:
		H.tick(0, 0, 0)
		Game.syncCar(1.0 / 60)
		moved = maxf(moved, (Game.car.g.position - p0).length() + (Game.car.g.rotation - r0).length())
	r.check(moved < 1e-4, "stilstaand trilt of beweegt de auto niet (klinkers)", "%.6f" % moved)
	H.countdown()
	for k in 240: H.tick(H.keep(0), 1, 0)
	Game.syncCar(1.0 / 60)
	p0 = Game.car.g.position; r0 = Game.car.g.rotation
	Game.syncCar(0.0); Game.syncCar(0.0)
	r.check(Game.car.g.position == p0 and Game.car.g.rotation == r0 and Game.player.rumble > 0.05, "in de pauze staat de auto stil (ook op klinkers, met trillen aan)", "trillen %.2f" % Game.player.rumble)
	# split screen: each player's own slide and lean
	var S := G.settings
	S.mode = "split"; S.bots = 0; S.laps = 2; S.p2car = "muscle"; S.track = "haven"
	Game.state = "menu"
	TrackLoader.load_track("haven", "fwd"); H._dirty = false
	Game.rebuildPlayerCar(); Game.startRace()
	H.countdown()
	var L = load("res://tests/test_laps.gd").new()
	L.step(4.0)
	var p1: PlayerState = Game.player
	var p2: PlayerState = Game.p2.pl
	Game.syncCar(1.0 / 60); Game.asP2(func(): Game.syncCar(1.0 / 60))
	var ok: bool = p1 != p2 and p2.speed > 10 and p1.speed > 10 and not is_nan(p2.yr) and not is_nan(p2.roll) and Game.p2.car.g.position.distance_to(Game.car.g.position) > 1.0
	r.check(ok and Game.player == p1, "2 spelers: elk zijn eigen auto, slip en carrosserie", "p1 %.0f km/u, p2 %.0f km/u" % [p1.speed * 3.6, p2.speed * 3.6])
	Game.toMenu(-1)
	S.mode = "race"

# ------------------------------------------------------------------ bots
func bots() -> void:
	# bots among themselves: 7 bots, 2 laps, the player parked out of the way; they finish, without wrecks or trains
	for tr in ["circuit", "dorp"]:
		H.start(tr, "gt", "dry", "fwd", 7, "normal", 2, "back")
		H.countdown()
		var t := 0.0
		var spun := 0
		var was := {}
		var hitsBB := 0
		var prevC := {}
		while t < 400 and not Game.bots.all(func(b): return b.finished):
			# the player drives slowly along the right-hand edge: out of the racing line
			var pl := Game.player
			H.tick(H.keep(Trk.ROAD_HALF - 1.4), 1.0 if pl.speed < 12 else 0.0, 0)
			t += H.DT
			for b in Game.bots:
				if b.spun and not was.get(b, false): spun += 1
				was[b] = b.spun
			if int(t * 120) % 12 == 0:
				for a in Game.bots.size():
					for k in range(a + 1, Game.bots.size()):
						var key := a * 10 + k
						var c: bool = absf(Trk.wrapD(Game.bots[a].s - Game.bots[k].s)) < 6 and Game.pairContact(Game.bodyOf(Game.bots[a]), Game.bodyOf(Game.bots[k])) != null
						if c and not prevC.get(key, false): hitsBB += 1
						prevC[key] = c
		var done: bool = Game.bots.all(func(b): return b.finished)
		var times: Array = Game.bots.map(func(b): return b.finishTime)
		times.sort()
		r.check(done and spun <= 2 and Game.raceContacts <= 2, "%s: 7 bots rijden 2 ronden uit zonder elkaar of de speler van de baan te rijden" % tr,
			"%d spins, %d keer bot tegen bot, %d keer tegen de speler" % [spun, hitsBB, Game.raceContacts])
		r.check(done and times[-1] - times[0] > 1.5, "%s: de bots rijden niet als een treintje over de streep" % tr, "eerste en laatste %.1f s uit elkaar" % (times[-1] - times[0] if done else 0.0))
	# a race stays winnable on easy and normal with a tidy driver, and hard is not a walkover
	var res := {}
	for diff in ["easy", "normal", "hard"]:
		var q: Dictionary = H.race("circuit", "gt", diff, 5, 2, 1.3)
		res[diff] = q
	r.check(res.easy.done and res.easy.pos <= 2, "makkelijk: een nette rijder wint (bijna) altijd", "plaats %d" % res.easy.pos)
	r.check(res.normal.done and res.normal.pos <= 4, "normaal: een nette rijder rijdt voorin mee", "plaats %d, eigen ronde %.2f, beste bot %.2f" % [res.normal.pos, res.normal.best, res.normal.botBest])
	r.check(res.hard.done and res.hard.botBest < res.normal.botBest, "moeilijk: de bots zijn sneller dan op normaal", "beste bot %.2f tegen %.2f" % [res.hard.botBest, res.normal.botBest])

extends RefCounted
## Handling harness: drives the player's car headless with exact inputs (120 Hz, through Game.update like a player) and
## measures what it does. Used by tests/test_handling.gd (checks) and tests/test_measure.gd (the before/after tables).
## Nothing here knows how the physics work inside: it only sets inputs (gamepad or keys) and reads position, heading
## and speed, so the same measurements can be compared across versions of the handling model.

const HZ := 120.0
const DT := 1.0 / HZ
const KMH := 3.6

var env: Env
var vel := Vector2.ZERO          ## measured world velocity (x, z) of the last tick
var yawRate := 0.0               ## measured, positive = turning right
var walls := 0                   ## wall contacts since start()
var ditches := 0                 ## times in the ditch since start()
var offT := 0.0                  ## seconds with the car's centre off the tarmac
var _wallT := 0.0
var _dirty := true               ## the loaded track was altered (free plane): load it again next time

func setup(host: Node) -> void:
	env = Env.new()
	host.add_child(env)
	if Fx.me == null: host.add_child(Fx.new())
	World.root = Node3D.new()
	host.add_child(World.root)
	var cam := Camera3D.new()
	host.add_child(cam)
	Game.camera = cam
	Game.set_process(false)
	Game.set_process_input(false)

func done() -> void:
	Game.toMenu(-1)
	Game.keysDown.clear()
	Game.pad = {"steer": 0.0, "gas": 0.0, "brake": 0.0, "hand": false, "look": false}
	Game.set_process(true)
	Game.set_process_input(true)

## load a track and put the player on the grid, racing (no countdown). bots > 0: a race against bots.
func start(track: String, car := "gt", weather := "dry", dir := "fwd", bots := 0, diff := "normal", laps := 3, grid := "back") -> void:
	var S := G.settings
	S.track = track; S.dir = dir; S.car = car; S.grid = grid; S.diff = diff; S.laps = laps
	S.mode = "race" if bots > 0 else "ghost"; S.bots = maxi(1, bots)
	S.time = "day"; S.weather = weather
	if Game.split or Game.p2 != null: Game.splitTeardown()
	Game.state = "menu"
	if _dirty or Trk.TRACK_ID != track or Trk.TRACK_DIR != dir:
		TrackLoader.load_track(track, dir)
		_dirty = false
	env.apply("day", weather, true)
	Game.rebuildPlayerCar()
	Game.startRace()
	# another test may have set the game clock back (tests/test_rules.gd): the last wall hit must lie in the past
	Game.wallT = minf(Game.wallT, Game.clock - 1.0); Game.hitT = minf(Game.hitT, Game.clock - 1.0)
	walls = 0; ditches = 0; offT = 0.0; _wallT = Game.wallT
	vel = Vector2.ZERO; yawRate = 0.0

## through the start lights, like a player (the bots start with you)
func countdown() -> void:
	var n := 0
	while Game.state == "countdown" and n < 1500:
		tick(0, 0, 0)
		n += 1

## an endless flat plane without walls, verges or laps: for skid pad, braking and slide measurements
func free_plane() -> void:
	for i in Trk.NS:
		Trk.EDGE[i] = 1e9; Trk.HT[i] = 0.0; Trk.EMB[i] = 0.0
	Trk.ROAD_HALF = 1e6; Trk.SHOULDER = 1e6
	_dirty = true
	Game.raceLaps = 999999
	Game.mode = "race"; Game.raceMode = true
	Game.state = "racing"

## put the car at sample i, lateral lat, turned ang to the right of the track direction, at speed v (m/s); slip: the
## car's nose points this many radians to the right of where it is going (a slide)
func put(i: int, lat := 0.0, ang := 0.0, v := 0.0, slip := 0.0) -> void:
	var g := Game
	i = posmod(i, Trk.NS)
	g.resetPlayer(i, lat)
	g.player.heading -= ang
	var vx := sin(g.player.heading) * v
	var vz := cos(g.player.heading) * v
	g.player.heading -= slip
	var fx := sin(g.player.heading); var fz := cos(g.player.heading)
	g.player.speed = vx * fx + vz * fz
	g.player.slide = Vector2(vx - fx * g.player.speed, vz - fz * g.player.speed)
	# the car's own slide (tyres), not a shove from outside
	if "slideOut" in g.player: g.player.slideOut = g.player.slide
	g.player.gear = 1
	while g.player.gear < 6 and v > g.gearTop(g.player.gear) * 0.9: g.player.gear += 1
	g.drift = 0
	g.state = "racing"
	vel = Vector2(vx, vz); yawRate = 0.0
	_wallT = g.wallT

## one step with gamepad input (steer -1..1, right is positive); keys=true: the same through the keyboard (digital)
func tick(steer := 0.0, gas := 0.0, brake := 0.0, hand := false, keys := false) -> void:
	var g := Game
	g.keysDown.clear()
	g.pad = {"steer": 0.0, "gas": 0.0, "brake": 0.0, "hand": false, "look": false}
	if keys:
		if steer > 0.5: g.keysDown["KeyD"] = true
		if steer < -0.5: g.keysDown["KeyA"] = true
		if gas > 0.5: g.keysDown["KeyW"] = true
		if brake > 0.5: g.keysDown["KeyS"] = true
		if hand: g.keysDown["Space"] = true
	else:
		g.pad = {"steer": steer, "gas": gas, "brake": brake, "hand": hand, "look": false}
	var p0 := g.player.pos
	var h0 := g.player.heading
	var v0 := g.player.speed
	g.update(DT)
	vel = Vector2(g.player.pos.x - p0.x, g.player.pos.z - p0.z) / DT
	yawRate = -angDiff(g.player.heading, h0) / DT
	if g.wallT != _wallT:
		_wallT = g.wallT; walls += 1
	if v0 > 5 and g.player.speed == 0.0 and vel.length() > 20: ditches += 1
	if absf(g.player.lat) > Trk.ROAD_HALF + 0.3: offT += DT
	g.keysDown.clear()

static func angDiff(a: float, b: float) -> float:
	return fposmod(a - b + PI, TAU) - PI

func v() -> float:
	return vel.length()

## slip angle: how far the nose points to the right of the direction of travel (radians)
func beta() -> float:
	if vel.length() < 0.5: return 0.0
	return angDiff(atan2(vel.x, vel.y), Game.player.heading)

## gas that holds speed tv (m/s)
func hold(tv: float) -> float:
	return clampf((tv - v()) * 0.6 + 0.35, 0.0, 1.0)

# ------------------------------------------------------------------ straight line
func accel(car: String) -> Dictionary:
	start("haven", car); free_plane(); put(40)
	var r := {"t100": -1.0, "t200": -1.0, "top": 0.0, "d400": -1.0}
	var d := 0.0
	for k in int(70 * HZ):
		tick(0, 1, 0)
		d += v() * DT
		var t := (k + 1) * DT
		if r.t100 < 0 and v() * KMH >= 100: r.t100 = t
		if r.t200 < 0 and v() * KMH >= 200: r.t200 = t
		if r.d400 < 0 and d >= 400: r.d400 = t
	r.top = v() * KMH
	return r

func braking(car: String, kmh: float, weather := "dry") -> Dictionary:
	start("haven", car, weather); free_plane(); put(40, 0, 0, kmh / KMH)
	var d := 0.0
	var t := 0.0
	while v() > 0.3 and t < 20:
		tick(0, 0, 1)
		d += v() * DT; t += DT
	return {"dist": d, "time": t}

func coasting(car: String, kmh: float) -> Dictionary:
	start("haven", car); free_plane(); put(40, 0, 0, kmh / KMH)
	for _k in int(3 * HZ): tick(0, 0, 0)
	return {"lost3s": kmh - v() * KMH}

# ------------------------------------------------------------------ cornering
## full (or part) lock at a held speed: yaw rate, radius, lateral g and slip angle once it has settled
func skidpad(car: String, kmh: float, steer := 1.0, weather := "dry", keys := false) -> Dictionary:
	start("haven", car, weather); free_plane(); put(40, 0, 0, kmh / KMH)
	var tv := kmh / KMH
	var n := 0
	var sy := 0.0; var sv := 0.0; var sb := 0.0
	for k in int(5 * HZ):
		tick(steer, hold(tv), 0, false, keys)
		if k >= int(4 * HZ):
			n += 1; sy += yawRate; sv += v(); sb += beta()
	var yr := sy / n; var vv := sv / n
	return {"kmh": vv * KMH, "yaw": yr, "radius": vv / maxf(1e-6, absf(yr)), "g": vv * yr / 9.81, "beta": rad_to_deg(sb / n)}

## the fastest the car goes round a circle of radius R (m): speed creeps up until it cannot hold the line any more
func max_corner(car: String, R: float, weather := "dry") -> Dictionary:
	start("haven", car, weather); free_plane()
	var v0 := 0.45 * sqrt(22.0 * R)
	put(40, 0, 0, v0)
	var g := Game
	var h := g.player.heading
	# turning right: the centre is to the right of the car
	var c := Vector2(g.player.pos.x - cos(h) * R, g.player.pos.z + sin(h) * R)
	var tv := v0
	var best := v0
	var t := 0.0
	var bmax := 0.0
	while t < 120:
		var rel := Vector2(g.player.pos.x, g.player.pos.z) - c
		var e := rel.length() - R
		# heading of the circle's tangent (clockwise seen from above = turning right), corrected towards the line
		var tang := atan2(-rel.y, rel.x)
		var want := tang - clampf(e * 0.15, -0.6, 0.6)
		var df := angDiff(want, g.player.heading)
		tick(clampf(-df * 5.0, -1, 1), hold(tv), 0)
		t += DT
		tv += 0.7 * DT
		if e > maxf(2.5, R * 0.06): break
		if t > 2.0:
			best = maxf(best, v())
			bmax = maxf(bmax, absf(beta()))
		if tv > g.MAXV + 3: break
	return {"kmh": best * KMH, "g": best * best / R / 9.81, "beta": rad_to_deg(bmax)}

## from straight ahead to full lock at once: how fast the car answers
func step_steer(car: String, kmh: float, keys := false) -> Dictionary:
	start("haven", car); free_plane(); put(40, 0, 0, kmh / KMH)
	var tv := kmh / KMH
	for _k in int(0.5 * HZ): tick(0, hold(tv), 0)
	var ys := []
	for _k in int(2.5 * HZ):
		tick(1, hold(tv), 0, false, keys)
		ys.append(yawRate)
	var ss := 0.0
	for k in range(ys.size() - 36, ys.size()): ss += ys[k] / 36.0
	var t50 := -1.0; var t90 := -1.0; var pk := 0.0
	for k in ys.size():
		if t50 < 0 and ys[k] >= ss * 0.5: t50 = (k + 1) * DT
		if t90 < 0 and ys[k] >= ss * 0.9: t90 = (k + 1) * DT
		pk = maxf(pk, ys[k])
	return {"yaw": ss, "t50": t50, "t90": t90, "over": (pk / ss - 1.0) * 100.0 if ss > 0 else 0.0}

## steady in a corner at `steer`, then lift (brake = 0) or brake: what the car does in the next 1.5 s
func mid_corner(car: String, kmh: float, steer: float, brake: float, weather := "dry", gas := 0.0) -> Dictionary:
	start("haven", car, weather); free_plane(); put(40, 0, 0, kmh / KMH)
	var tv := kmh / KMH
	for _k in int(3 * HZ): tick(steer, hold(tv), 0)
	var y0 := yawRate; var v0 := v(); var b0 := beta()
	var ymax := y0; var bmax := 0.0; var bend := 0.0
	var h0 := Game.player.heading
	for k in int(1.5 * HZ):
		if v() < 4.0: break       # stopped (holding the brake would reverse)
		tick(steer, gas, brake)
		ymax = maxf(ymax, yawRate)
		bmax = maxf(bmax, absf(beta()))
		if k <= int(1.0 * HZ) - 1: bend = v()
	return {"yaw0": y0, "yawPeak": ymax / maxf(1e-6, y0), "beta0": rad_to_deg(b0), "betaMax": rad_to_deg(bmax), "v1s": bend * KMH, "v0": v0 * KMH,
		"turned": rad_to_deg(-angDiff(Game.player.heading, h0)), "spun": absf(beta()) > 1.2}

## flat out through a corner from `kmh` (a power slide in a strong rear-wheel-drive car)
func power_exit(car: String, kmh: float, keys := false) -> Dictionary:
	start("haven", car); free_plane(); put(40, 0, 0, kmh / KMH)
	var bmax := 0.0
	for _k in int(2.5 * HZ):
		tick(1, 1, 0, false, keys)
		bmax = maxf(bmax, absf(beta()))
	var vEnd := v()
	# then lift with the lock still on: does the slide die out by itself
	var b2 := 0.0
	for _k in int(1.0 * HZ):
		tick(1, 0, 0, false, keys)
		b2 = maxf(b2, absf(beta()))
	return {"betaMax": rad_to_deg(bmax), "vEnd": vEnd * KMH, "liftMax": rad_to_deg(b2), "liftEnd": rad_to_deg(beta())}

## handbrake turn: full lock and handbrake for `hold_s`, then let go and steer against the slide
func handbrake(car: String, kmh: float, hold_s := 0.7, counter := true) -> Dictionary:
	start("haven", car); free_plane(); put(40, 0, 0, kmh / KMH)
	var h0 := Game.player.heading
	var bmax := 0.0
	for _k in int(hold_s * HZ):
		tick(1, 0, 0, true)
		bmax = maxf(bmax, absf(beta()))
	var vRel := v()
	var tRec := -1.0
	var calm := 0
	for k in int(4 * HZ):
		# steer towards where the car is going (counter-steer), gently on the gas
		tick(clampf(-beta() * 2.5, -1, 1) if counter else 0.0, 0.5, 0)
		bmax = maxf(bmax, absf(beta()))
		if absf(beta()) < 0.07 and absf(yawRate) < 0.15:
			calm += 1
			if calm > 12 and tRec < 0: tRec = (k + 1) * DT
		else:
			calm = 0; tRec = -1.0
	return {"betaMax": rad_to_deg(bmax), "turned": rad_to_deg(-angDiff(Game.player.heading, h0)), "tRecover": tRec, "vRelease": vRel * KMH, "vEnd": v() * KMH}

## the car slides (nose `slip_deg` to the right of its path) with the wheels straight and no pedals: does it catch itself?
func slide_recover(car: String, kmh: float, slip_deg: float, counter := false) -> Dictionary:
	start("haven", car); free_plane(); put(40, 0, 0, kmh / KMH, deg_to_rad(slip_deg))
	var tRec := -1.0
	var calm := 0
	var over := 0.0
	for k in int(4 * HZ):
		tick(clampf(-beta() * 2.5, -1, 1) if counter else 0.0, 0, 0)
		over = maxf(over, -beta())
		if absf(beta()) < 0.07 and absf(yawRate) < 0.15:
			calm += 1
			if calm > 12 and tRec < 0: tRec = (k + 1) * DT
		else:
			calm = 0; tRec = -1.0
	return {"tRecover": tRec, "overshoot": rad_to_deg(over), "vEnd": v() * KMH, "betaEnd": rad_to_deg(beta())}

# ------------------------------------------------------------------ on the track
## the straightest stretch of the loaded track: sample index where the next `m` metres bend least
func straight_i(m := 300.0) -> int:
	var n := int(m / Trk.SPC)
	var best := 0
	var bc := 1e9
	var i := 0
	while i < Trk.NS:
		var c := 0.0
		for k in n: c = maxf(c, Trk.CURV[(i + k) % Trk.NS])
		if c < bc: bc = c; best = i
		i += 5
	return best

## steer that keeps the car along the road at lateral offset lat
func keep(lat: float) -> float:
	var g := Game
	var th := Trk.heading_of(Trk.T[g.player.idx])
	var want := th + clampf((g.player.lat - lat) * 0.07, -0.3, 0.3)
	return clampf(-angDiff(want, g.player.heading) * 4.0, -1, 1)

## full gas for `secs` along the road at lateral offset lat (on the verge, the grass, the gravel)
func surface(track: String, car: String, lat: float, kmh: float, secs := 3.0, weather := "dry") -> Dictionary:
	start(track, car, weather)
	put(straight_i(), lat, 0, kmh / KMH)
	var bmax := 0.0
	for _k in int(secs * HZ):
		tick(keep(lat), 1, 0)
		bmax = maxf(bmax, absf(beta()))
	return {"vEnd": v() * KMH, "lost": kmh - v() * KMH, "lat": Game.player.lat, "beta": rad_to_deg(bmax)}

## into the wall at `deg` degrees and `kmh`: what is left of the speed, and can you steer away again?
func wall(track: String, car: String, deg: float, kmh: float) -> Dictionary:
	start(track, car)
	var i := straight_i(260.0)
	var E: float = Trk.EDGE[i]
	put(i, E - 1.6, deg_to_rad(deg), kmh / KMH)
	var vmin := 1e9
	var hit := -1.0
	var deep := 0.0
	var t := 0.0
	var w0 := walls
	while t < 1.2:
		tick(0, 0.5, 0)
		t += DT
		deep = maxf(deep, absf(Game.player.lat) - E)
		if walls > w0 and hit < 0: hit = t
		if hit >= 0 and t - hit < 0.5: vmin = minf(vmin, v())
	var vAfter := v()
	var th := Trk.heading_of(Trk.T[Game.player.idx])
	var ang := rad_to_deg(angDiff(th, Game.player.heading))
	# steer away from the wall for a second: how far do you get from it
	for _k in int(0.8 * HZ): tick(-1, 0.5, 0)
	return {"hitAt": hit, "vAfter": vAfter * KMH, "vMin": (vmin if vmin < 1e8 else v()) * KMH, "angAfter": ang, "deep": deep, "free": E - absf(Game.player.lat), "hits": walls - w0}

# ------------------------------------------------------------------ a racing driver for the tests
## the lateral acceleration the car is designed to hold at speed vv (the turn rate at full lock times the speed)
func lat_limit(vv: float) -> float:
	return 1.7 * Game.GRIP * Game.gripFactor() * vv * clampf(vv / 8.0, 0, 1) * maxf(0.32, 1 - 0.5 * vv / 69.4)

## the speed for a bend of curvature c, using the share k of the car's cornering power
func corner_speed(c: float, k: float) -> float:
	var K := k * 1.7 * Game.GRIP * Game.gripFactor()
	var vv := K / (c + K / 138.8)
	if vv > 94.4: vv = K * 0.32 / c
	return vv

## One step of a tidy driver: racing line, brakes for the bends (k = how close to the limit, 1 = all of it), passes
## slower cars on the free side. Returns nothing; reads the result from the game.
func drive_step(k: float, avoid := true) -> void:
	var g := Game
	var pl := g.player
	var vv := maxf(0.0, pl.speed)
	var bdec: float = g.BRAKE * 0.8 * g.gripFactor()
	var target := 999.0
	var look := 30.0 + vv * vv / (2 * bdec) * 1.25
	var d := 2.0
	while d < look:
		var c: float = Trk.CURV[int(fposmod(pl.s + d, Trk.TRACK_LEN) / Trk.SPC) % Trk.NS]
		if c > 1e-4:
			var vc := corner_speed(c, k)
			var al := sqrt(vc * vc + 2 * bdec * maxf(0.0, d - 6.0))
			if al < target: target = al
		d += 4.0
	var Ld := 7.0 + vv * 0.3
	var a := Trk.trackAt(pl.s + Ld)
	var lt: float = Trk.LINE[a.i]
	if avoid:
		for b in g.bots + g.traffic:
			if b.out: continue
			var ds := Trk.wrapD(b.s - pl.s)
			if ds > 1.0 and ds < 10.0 + vv * 0.35 and absf(b.lat - pl.lat) < 2.6 and b.cur < vv + 1:
				var lim := Trk.ROAD_HALF - 1.2
				var o1: float = b.lat - 3.3
				var o2: float = b.lat + 3.3
				var ok1 := absf(o1) <= lim
				var ok2 := absf(o2) <= lim
				if ok1 and ok2: lt = o1 if absf(o1 - pl.lat) < absf(o2 - pl.lat) else o2
				elif ok1: lt = o1
				elif ok2: lt = o2
				else: target = minf(target, b.cur + (ds - 7.0) * 0.6)
				break
	var want := atan2(a.px + a.rx * lt - pl.pos.x, a.pz + a.rz * lt - pl.pos.z)
	var df := angDiff(want, pl.heading)
	var st := clampf(-df * 3.5, -1, 1)
	if vv < target - 1.0: tick(st, 1, 0)
	elif vv > target + 1.0: tick(st, 0, clampf((vv - target) / 5.0, 0.2, 1.0))
	else: tick(st, 0.35, 0)

## one flying lap by the tidy driver (after a run-up of 60 % of a lap): lap time, and how clean it was
func clean_lap(track: String, car: String, k: float, weather := "dry", dir := "fwd") -> Dictionary:
	start(track, car, weather, dir)
	Game.raceLaps = 99
	countdown()
	var t := 0.0
	var lap0: float = -1.0
	var w0 := 0; var d0 := 0; var o0 := 0.0
	var top := 0.0
	var bmax := 0.0
	while t < 400:
		drive_step(k, false)
		t += DT
		if lap0 < 0 and Game.player.lap >= 1:
			lap0 = t; w0 = walls; d0 = ditches; o0 = offT
		if lap0 >= 0:
			top = maxf(top, v())
			bmax = maxf(bmax, absf(beta()))
		if Game.player.lap >= 2: break
	return {"lap": t - lap0 if lap0 >= 0 and Game.player.lap >= 2 else -1.0, "walls": walls - w0, "ditch": ditches - d0, "off": offT - o0, "top": top * KMH, "beta": rad_to_deg(bmax)}

## the tidy driver's best clean lap: the highest k that stays on the tarmac and off the walls
func best_clean(track: String, car: String, weather := "dry", ks := [2.0, 1.8, 1.6, 1.4, 1.2, 1.0, 0.8]) -> Dictionary:
	var best := {}
	for k in ks:
		var r := clean_lap(track, car, k, weather)
		r.k = k
		if r.lap > 0 and r.walls == 0 and r.ditch == 0 and r.off < 0.3:
			if best.is_empty() or r.lap < best.lap: best = r
	return best

## a race against bots with the tidy driver: finishing place, gap to the winner, contacts
func race(track: String, car: String, diff: String, nbots: int, laps: int, k: float, grid := "back") -> Dictionary:
	start(track, car, "dry", "fwd", nbots, diff, laps, grid)
	countdown()
	var t := 0.0
	var minGap := 1e9
	var train := 0.0
	var samples := 0
	while t < 900 and not Game.raceDone:
		drive_step(k, true)
		t += DT
		if int(t * HZ) % 60 == 0 and t > 15:
			# how spread out the bots are: mean gap between successive bots (m)
			var ps := []
			for b in Game.bots: ps.append(Game.progressOf(b.lap, b.s, b.finished, b.finishTime))
			ps.sort()
			var gsum := 0.0
			for q in range(1, ps.size()): gsum += ps[q] - ps[q - 1]
			if ps.size() > 1:
				train += gsum / (ps.size() - 1); samples += 1
	var pos := Game.playerPosition()
	var bt := []
	for b in Game.bots: bt.append(b.bestLap)
	bt.sort()
	return {"pos": pos, "time": Game.raceFinishTime, "best": Game.raceBestLap, "botBest": bt[0] if not bt.is_empty() else 0.0, "contacts": Game.raceContacts,
		"walls": walls, "ditch": ditches, "spread": train / maxi(1, samples), "done": Game.raceDone}

extends Node
## Autoload "Game": the race itself, ported from the HTML game's player, traffic, bots, physics, camera and game flow
## sections (same names, same numbers). The menus, garage, career, championship, ghost, replay, split screen and online
## parts hook in through the functions marked "hook" (filled in by their own ports).

const REVMAX := -9.0
const COAST := 4.0
const START_I := 6

# ------------------------------------------------------------------ scene objects (set by main.gd)
var camera: Camera3D
var fx_overlay: CanvasLayer                ## screen effects (blur, speed lines, mirror), set by main.gd
var car = null                       ## the player's car model (Dictionary from CarKit.buildCar)

# ------------------------------------------------------------------ player (JS: player section)
var player := PlayerState.new()
var MAXV := 250.0 / 3.6
var ACC := 15.5
var BRAKE := 30.0
var GRIP := 1.0
var resetT := -9.0
var hitT := -9.0

# ------------------------------------------------------------------ game flow state (JS: game flow section)
var state := "menu"
var paused := false
var raceMode := false
var mode := "race"
var timeLeft := 30.0
var distance := 0.0
var checkpoints := 0
var nextCp := 1
var cd := 0.0
var lastCount := 4
var shake := 0.0
var overReady := false
var clock := 0.0
var wrongT := 0.0
var lapStart := 0.0
var raceBestLap := 0.0
var raceTopSpeed := 0.0
var wallT := 0.0
var raceTime := 0.0
var raceDone := false
var raceFinishTime := 0.0
var finishAt := 0.0
var raceLaps := 3
var elimDone := 0
var playerOut := false
var elimPos := 0
var lapTimes: Array = []
var overView := "results"
var ghostSaved := false
var lapRecordSet := false
var goDelay := 0.6
var resultsAt := 0.0
var resultRows: Array = []
var split := false
var activeP := 1
## split screen: the other player's context (JS p2), swapped in by asP2 (swapCtx); inP2 while swapped
var p2 = null
var inP2 := false
var splitFirstDone := 0.0
var splitEndAt := 0.0
var raceContacts := 0
var racePits := 0

# ------------------------------------------------------------------ traffic & bots
const HATCH_COLORS := [0xe9e9e4, 0x2f6db3, 0x8c1c24, 0x3f444b, 0x5f8a3a, 0xd9a21b, 0x6a7fa0]
const BOT_NAMES := ["Henk", "Ingrid", "Daan", "Fenna", "Kees", "Sanne", "Joost"]
## rivals tune too: the bots get most of the edge your upgrades give over the stock car
const RIVAL_TUNE := 0.8
## how firmly a bot covers its line when a faster car comes up behind it (0 = never)
const DEFEND := {"easy": 0.0, "normal": 0.5, "hard": 0.8, "extreme": 1.0}
const WIDE_LEN := 1.5        ## seconds a bot's small mistake (running wide) lasts
var traffic: Array = []
var bots: Array = []
var lampsOn := false

# ------------------------------------------------------------------ camera
var camPos := Vector3.ZERO
var camLook := Vector3.ZERO
var drift := 0.0
var camHeading := 0.0
var camY := 0.0
var speedFx := 0.0
var flyS := 0.0
var camLift := 0.0
const CAM_NAMES := ["Achter de auto", "Verder weg", "Bumper"]

# ------------------------------------------------------------------ wind (Afsluitdijk, Zeeland)
var gustT := 9.0
var gustDir := 1.0
var gustPhase := 0.0
var gustWarn := false
var windX := 0.0
const GUST_LEN := 2.4

# ------------------------------------------------------------------ sector times
var secBest := [0.0, 0.0, 0.0]
var secLast := [0.0, 0.0, 0.0]
var secStart := 0.0
var secPrev := 0

# ------------------------------------------------------------------ helpers
static func clamp_(v: float, a: float, b: float) -> float:
	return maxf(a, minf(b, v))

static func wheelSpin(v: float, r: float, dt: float) -> float:
	return clamp_(v / r, -22, 22) * dt

func gripFactor() -> float:
	return Env.me.grip_factor() if Env.me != null else 1.0

func fxOn() -> bool:
	return bool(G.prefs.get("fx", true))

func settings() -> Dictionary:
	return G.settings

func activeBots() -> Array:
	return bots.filter(func(b): return not b.out)

# ================================================================== player
func rebuildPlayerCar(pid := "", pcol := "") -> void:
	var S := G.settings
	var id: String = pid if pid != "" else S.car
	var col: String = pcol if pcol != "" else S.color
	if car != null:
		car.g.queue_free()
	if pid != "":
		var sc = S.color
		S.color = col
		car = CarKit.buildCar(id, Color(col))
		CarKit.styleCar(car, id)
		S.color = sc
	else:
		car = CarKit.buildCar(S.car, Color(S.color))
		CarKit.styleCar(car, S.car)
	get_tree().current_scene.add_child(car.g)
	if car.get("beam") != null:
		car.beam.visible = false
	if GarageRoom.inGarage: CarKit.setDriver(car, false)   # (the garage shows an empty car)
	# the headlight is player 1's (JS: if(activeP===1)attachHeadlights()): player 2's car in split screen has none
	if Fx.me != null and activeP == 1: Fx.me.attachCar(car)
	var c := G.effStats(id)
	MAXV = c.vmax / 3.6
	ACC = c.acc * G.ACC_K
	BRAKE = c.brake * G.BRK_K
	GRIP = c.grip
	syncCar(0)
	# the race number is a canvas texture: draw it now (JS canvasTex draws at once), else it stays a grey square on the
	# door until the next track or garage load
	if Canvas2D.pending_count() > 0 and get_tree().current_scene != null: Canvas2D.flush(get_tree().current_scene)

# ================================================================== traffic
func clearTraffic() -> void:
	for c in traffic:
		c.m.g.queue_free()
	traffic = []

func buildTraffic() -> void:
	clearTraffic()
	var n: int = Trk.TRK.get("traffic", 0)
	var L := Trk.LANES.size()
	var dorp := Trk.TRACK_ID == "dorp"
	for _k in n:
		var r := randf()
		var m: Dictionary
		var lane: int
		var v: float
		var tractor := false
		if Trk.TRK.get("tractors", false) and r < 0.14:
			m = Vehicles.makeTractor(); lane = L - 1; v = 8 + randf() * 4; tractor = true
		elif Trk.TRK.get("trucks", false) and r < 0.4:
			m = Vehicles.makeTruck(); lane = L - 1; v = 17 + randf() * 6
		elif r < 0.32:
			m = Vehicles.makeVan(); lane = L - 1 if randf() < 0.6 else maxi(0, L - 2); v = (9 + randf() * 4) if dorp else (20 + randf() * 9)
		else:
			m = Vehicles.buildHatchTraffic(HATCH_COLORS[int(randf() * HATCH_COLORS.size())])
			lane = int(floor(randf() * L))
			v = (11 + randf() * 5) if dorp else (22 + randf() * 16 + (4 if lane == 0 else 0))
		get_tree().current_scene.add_child(m.g)
		var c := Mover.new()
		c.m = m; c.lane = lane; c.target = lane; c.lat = Trk.LANES[lane]; c.s = 140 + randf() * (Trk.TRACK_LEN - 200)
		c.speed = v; c.cur = v; c.tractor = tractor
		c.mass = 3.2 if tractor else (4.0 if m.len > 10 else (1.6 if m.len > 5 else 1.0))
		traffic.append(c)

func poseOnTrack(g: Node3D, s: float, lat: float, yawOff := 0.0) -> void:
	var a := Trk.trackAt(s)
	var y: float = Trk.hAt(a.i, lat) * (1 - a.t) + Trk.hAt(a.j, lat) * a.t
	g.position = Vector3(a.px + a.rx * lat, y, a.pz + a.rz * lat)
	# nose up the hill, down the dip (the road's own slope; the lean of the body comes on top, see leanBot)
	g.rotation = Vector3(-atan((Trk.hAt(a.j, lat) - Trk.hAt(a.i, lat)) / Trk.SPC) * cos(yawOff), atan2(a.tx, a.tz) + yawOff, 0)

func laneFree(c: Mover, l: int, obs: Array) -> bool:
	var x: float = Trk.LANES[l]
	for o in obs:
		if o == c: continue
		var d := Trk.wrapD(o.s - c.s)
		if d > -14 and d < 34 and absf(o.lat - x) < 2.4:
			return false
	return true

func updateTraffic(dt: float, withPlayer: bool) -> void:
	if traffic.is_empty():
		return
	var obs: Array = traffic.duplicate()
	if withPlayer:
		var pm := Mover.new()
		pm.s = player.s; pm.lat = player.lat; pm.cur = maxf(0, player.speed)
		obs.append(pm)
	for c in traffic:
		c.cur = c.speed
		if c.m.get("beam") != null:
			c.m.beam.visible = lampsOn
		for o in obs:
			if o == c: continue
			var d := Trk.wrapD(o.s - c.s)
			if d > 0 and d < 46 and absf(o.lat - c.lat) < 2.4 and o.cur < c.speed + 0.5:
				if not c.tractor and c.lane == c.target and d < 40:
					var opts := []
					for l in [c.lane - 1, c.lane + 1]:
						if l >= 0 and l < Trk.LANES.size() and laneFree(c, l, obs): opts.append(l)
					if not opts.is_empty():
						c.target = opts[int(randf() * opts.size())]
				if c.target == c.lane:
					if d < 22: c.cur = minf(c.cur, o.cur * 0.97)
					if d < 8: c.cur = minf(c.cur, o.cur * 0.7)
		var tgt: float = Trk.LANES[c.target]
		var dl: float = tgt - c.lat
		var vmL := 2.4
		if c.contactT > 0:
			c.contactT -= dt
			if MathX.sgn(dl) == c.contactSide: vmL = 0.3
		var want := clamp_(dl * 1.6, -vmL, vmL)
		c.latV += clamp_(want - c.latV, -5 * dt, 5 * dt)
		c.lat += c.latV * dt
		if absf(dl) < 0.05 and absf(c.latV) < 0.1:
			c.lane = c.target
		var sl := spinStep(c, dt, 1.4)
		if sl > 0.05:
			c.dv = maxf(-c.cur, c.dv - (11.0 if c.spun else sl * 12) * dt)
		c.s = fposmod(c.s + (c.cur + c.dv) * dt + Trk.TRACK_LEN, Trk.TRACK_LEN)
		c.lat += c.lp * dt
		var lim := botLatLimit()
		c.lat = clamp_(c.lat, -lim, lim)
		if absf(c.lat) > Trk.ROAD_HALF + 0.8 and c.cur + c.dv > 8:
			c.dv -= 7 * dt
		c.dv *= exp(-dt * 1.4)
		c.lp *= exp(-dt * 2.5)
		c.yawK *= exp(-dt * 3)
		c.cur = maxf(0, c.cur + c.dv)
		poseOnTrack(c.m.g, c.s, c.lat, -atan2(c.latV, maxf(4, c.cur)) + c.yawK + c.yawOff)
		var i := int(floor(c.s / Trk.SPC)) % Trk.NS
		var lv: float = c.latV + c.lp
		var v: float = c.cur + c.dv
		c.vx = Trk.T[i].x * v + Trk.R[i].x * lv
		c.vz = Trk.T[i].z * v + Trk.R[i].z * lv
		for w in c.m.wheels:
			w.spin.rotation.x += wheelSpin(c.cur, w.r, dt)
		CarKit.autoBrake(c.m, c.cur, dt)

# ================================================================== bots
func clearBots() -> void:
	for b in bots:
		b.m.g.queue_free()
	bots = []

func makeBotDefs(n: int) -> Array:
	var types: Array = Cars.carsOf(Cars.CARS[G.settings.car].cls)
	types.shuffle()
	var cols: Array = Cars.COLORS.filter(func(c): return c != G.settings.color)
	var out := []
	for k in n:
		out.append({"name": BOT_NAMES[k], "type": types[k % types.size()], "color": cols[k % cols.size()]})
	return out

func rivalBoost() -> Dictionary:
	var r := {"vmax": 1.0, "acc": 1.0, "grip": 1.0, "brake": 1.0}
	if netInRace(): return r
	var ids: Array = [G.settings.car, G.settings.p2car] if split and G.settings.p2car else [G.settings.car]
	for k in r:
		var m := 0.0
		for id in ids:
			m += G.effStats(id)[k] / Cars.CARS[id][k] / ids.size()
		r[k] = 1 + (m - 1) * RIVAL_TUNE
	return r

func setupBots(n: int, defs = null) -> void:
	clearBots()
	var d: Dictionary = G.DIFF[G.settings.diff]
	var rb := rivalBoost()
	if defs == null: defs = makeBotDefs(n)
	for k in defs.size():
		var type: String = defs[k].type
		var col: String = defs[k].color
		var m := CarKit.buildCar(type, Color(col))
		CarKit.styleCar(m, CarLook.botLook(defs[k].name, type, col, defs[k].get("rival", false)))   # a look of their own, the same on every computer
		var cdf: Dictionary = Cars.CARS[type]
		var sk := 1.015 if defs[k].get("rival", false) else 1.0   # a career rival drives a touch sharper
		get_tree().current_scene.add_child(m.g)
		var b := Mover.new()
		b.is_bot = true; b.m = m; b.name = defs[k].name; b.type = type; b.color = col; b.rival = defs[k].get("rival", false)
		b.lineLat = (randf() - .5) * 2.2
		b.vmax = cdf.vmax / 3.6 * d.speed * rb.vmax * sk * (1 - d.jit * 0.7 + randf() * d.jit)
		b.acc = cdf.acc * G.ACC_K * d.acc * rb.acc * (1 - d.jit * 0.5 + randf() * d.jit)
		b.aLat = d.aLat * cdf.grip * rb.grip * sk * (1 - d.jit + randf() * d.jit * 1.2)
		b.brk = d.brake * G.BRK_K * rb.brake
		b.mass = cdf.mass
		bots.append(b)

func gridSlot(k: int) -> Dictionary:
	var row := k / 2
	var col := k % 2
	return {"s": fposmod(Trk.S_START - 9 - row * 9 + Trk.TRACK_LEN, Trk.TRACK_LEN), "lat": (1.0 if col else -1.0) * minf(3.2, Trk.ROAD_HALF - 2.2)}

func placeGrid() -> void:
	var n := bots.size()
	var ps := 0 if G.settings.grid == "pole" else (n / 2 if G.settings.grid == "mid" else n)
	for k in n:
		var b: Mover = bots[k]
		var g := gridSlot(k + 1 if k >= ps else k)
		b.s = g.s; b.lat = g.lat; b.gridLat = g.lat; b.speed = 0; b.cur = 0; b.lap = 0; b.finished = false; b.bestLap = 0; b.finishTime = 0
		b.mistT = null; b.slowT = 0
		poseOnTrack(b.m.g, b.s, b.lat)
	var g := gridSlot(ps)
	resetPlayer(int(round(g.s / Trk.SPC)) % Trk.NS, g.lat)

func progressOf(lap: int, s: float, finished: bool, finishTime: float) -> float:
	if finished:
		return (raceLaps + 2) * Trk.TRACK_LEN + 100000 - finishTime * 10
	var rel := fposmod(s - Trk.S_START, Trk.TRACK_LEN)
	if lap <= 0:
		return -fmod(Trk.TRACK_LEN - rel, Trk.TRACK_LEN)
	return (lap - 1) * Trk.TRACK_LEN + rel

func updateBots(dt: float) -> void:
	if bots.is_empty():
		return
	var racing := state == "racing" or state == "finished" or state == "over"
	var obs := []
	for b in bots:
		obs.append({"ref": b, "s": b.s, "lat": b.lat, "cur": b.speed})
	obs.append({"ref": null, "s": player.s, "lat": player.lat, "cur": maxf(0, player.speed)})
	var pProg := progressOf(player.lap, player.s, raceDone, raceFinishTime)
	var df: Dictionary = G.DIFF[G.settings.diff]
	# the look-ahead loops below run some 60 times per bot per step: the track arrays and the grip as locals
	var CURV := Trk.CURV
	var LEN := Trk.TRACK_LEN
	var SPC := Trk.SPC
	var NS := Trk.NS
	var gf := gripFactor()
	for b in bots:
		if b.m.get("beam") != null:
			b.m.beam.visible = lampsOn and not b.out
		if not racing:
			b.speed = 0; b.cur = 0; b.vx = 0; b.vz = 0; b.lp = 0; b.yawK = 0; b.spin = 0; b.yawOff = 0; b.spun = false; b.pushDv = 0
			b.roll = 0; b.pitch = 0; b.prevV = 0; b.wideT = 0; b.defT = 0
			tiltRig(b.m, 0, 0, 0)
			for k in 2: b.m.wheels[k].pivot.rotation.y = 0.0
			poseOnTrack(b.m.g, b.s, b.lat)
			continue
		if netInRace() and not netIsHost():
			# the host drives the bots (Net applies its positions, 20 times a second); in between they roll on smoothly
			if Net.botsFresh():
				var rel := fposmod(b.s - Trk.S_START, Trk.TRACK_LEN)
				b.s = fposmod(b.s + b.speed * dt, Trk.TRACK_LEN)
				if fposmod(b.s - Trk.S_START, Trk.TRACK_LEN) < rel: b.lap += 1
			poseOnTrack(b.m.g, b.s, b.lat, b.yawOff)
			for w in b.m.wheels: w.spin.rotation.x += wheelSpin(b.speed, w.r, dt)
			CarKit.autoBrake(b.m, b.speed, dt)
			continue
		if b.out:
			b.speed = maxf(0, b.speed - 14 * dt)
			var tl := MathX.sgn(b.lat if b.lat != 0 else 1.0) * (Trk.ROAD_HALF + 1.2)
			b.lat += (tl - b.lat) * minf(1, dt * 1.5)
			b.s = fmod(b.s + b.speed * dt, Trk.TRACK_LEN)
			poseOnTrack(b.m.g, b.s, b.lat)
			if raceTime - b.outAt > 3: b.m.g.visible = false
			b.cur = b.speed
			continue
		var target: float = b.vmax
		var look := minf(260, 25 + b.speed * b.speed / 40)
		var d := 4.0
		while d < look:
			var i := int(floor(fposmod(b.s + d, LEN) / SPC)) % NS
			var c: float = CURV[i]
			if c > 2e-4:
				var vl := sqrt(b.aLat * gf / c)
				var allowed := sqrt(vl * vl + 2 * b.brk * d)
				if allowed < target: target = allowed
			d += 6
		if b.finished: target = minf(target, 22)
		if not b.finished and not raceDone and df.slow:
			var gap := progressOf(b.lap, b.s, false, 0) - pProg
			target *= 1 - 0.05 * clamp_((gap - 100) / 60, 0, 1)
		if not b.finished and not raceDone:
			var gap2 := pProg - progressOf(b.lap, b.s, false, 0)
			target *= 1 + (df.catchUp - 1) * clamp_((gap2 - 140) / 60, 0, 1)
		if df.mist > 0 and not b.finished:
			if b.mistT == null: b.mistT = 5 + randf() / df.mist
			b.mistT -= dt
			if b.mistT <= 0:
				# a small mistake: a moment too late on the brakes, so the car runs wide (to the outside of the bend that
				# is coming, or just off its line on a straight) and loses a little time
				b.mistT = 4 + randf() / df.mist
				var li: float = Trk.LINE[(int(floor(b.s / SPC)) + 30) % NS]
				b.wideDir = -MathX.sgn(li) if absf(li) > 0.5 else (-1.0 if randf() < .5 else 1.0)
				b.wideAmp = 1.2 + randf() * 1.3
				b.wideT = WIDE_LEN
				b.slowT = 1.2
		if b.slowT > 0:
			b.slowT -= dt; target *= 0.82
		if b.slideT > 0:
			b.slideT -= dt; target = minf(target, b.speed)
		# pushed from behind: keep the extra speed for a moment and ease back to your own pace
		if b.pushDv > 0.05:
			target = maxf(target, minf(b.speed, target + b.pushDv)); b.pushDv *= exp(-dt * 1.2)
		else:
			b.pushDv = 0
		var wantLat: float = Trk.LINE[(int(floor(b.s / Trk.SPC)) + 8) % Trk.NS] * 0.85 + b.lineLat * 0.35
		var into: float
		var ls := Trk.wrapD(b.s - Trk.S_START)
		into = (0.0 if b.lap < 1 else maxf(0, ls)) if b.lap <= 1 else 1e9
		var bend := 0.0
		var dd := 10.0
		while dd < 160:
			bend = maxf(bend, CURV[int(floor(fmod(b.s + dd, LEN) / SPC)) % NS])
			dd += 10
		# which side is the inside of the bend that is coming (the racing line leans to it)
		var insideSgn := MathX.sgn(Trk.LINE[(int(floor(b.s / SPC)) + 45) % NS])
		var kq := clamp_((into - 60) / 260, 0, 1)
		var kk := maxf(kq, clamp_((bend - 0.004) / 0.01, 0, 1) * clamp_(into / 40, 0, 1))
		if b.gridLat != null and kk < 1:
			wantLat = b.gridLat * (1 - kk) + wantLat * kk
		var defend := 0.0
		for o in obs:
			if o.ref == b: continue
			var dz := Trk.wrapD(o.s - b.s)
			var closing: float = b.speed - o.cur
			# a much slower car (a spin, a crash, a back marker) is seen from further away
			if dz > 0 and dz < 24 + maxf(0, closing) * 1.1 and absf(o.lat - b.lat) < 2.3 and o.cur < b.speed + 4:
				if b.passT <= 0 and into > 150 and dz < 24 + maxf(0, closing) * 0.6:
					var lim := Trk.ROAD_HALF - 1.4
					var best = null
					var bs := 1e9
					for v in [o.lat - 3.4, o.lat + 3.4]:
						if absf(v) > lim: continue
						# not into a car that is already there or coming up on that side
						var taken := false
						for q in obs:
							if q.ref == b or q == o: continue
							var dq := Trk.wrapD(q.s - b.s)
							if dq > -9 and dq < dz + 8 and absf(q.lat - v) < 2.2:
								taken = true; break
						if taken: continue
						# the nearest side, with a preference for the inside of the bend that is coming
						var sc: float = absf(v - b.lat) - (1.2 if (v - o.lat) * insideSgn > 0 else 0.0)
						if sc < bs:
							bs = sc; best = v
					if best != null:
						b.passLat = best; b.passT = 1.6
				if dz < 16: target = minf(target, o.cur + clamp_((dz - 8) * 0.7, -6, 4))
				elif closing > 6: target = minf(target, sqrt(o.cur * o.cur + 2 * b.brk * 0.7 * (dz - 12)))
			# someone faster is coming up from behind on a straight: cover the side they are on, once, and only while
			# they are still well behind (never into a car that is alongside)
			elif DEFEND[G.settings.diff] > 0 and dz < -7 and dz > -22 and closing < -1.5 and bend < 0.003 and b.passT <= 0 and b.defCool <= 0 \
					and absf(o.lat - b.lat) > 1.0 and absf(o.lat - b.lat) < 4.5:
				defend = clamp_(o.lat - b.lat, -1.6, 1.6) * DEFEND[G.settings.diff]
		if defend != 0.0 and b.defT <= 0:
			b.defT = 1.6; b.defLat = clamp_(b.lat + defend, -(Trk.ROAD_HALF - 1.6), Trk.ROAD_HALF - 1.6); b.defCool = 7.0
		b.defCool -= dt
		if b.defT > 0:
			b.defT -= dt; wantLat = b.defLat
		if b.wideT > 0:
			b.wideT -= dt; wantLat += b.wideDir * b.wideAmp * sin(PI * (1 - b.wideT / WIDE_LEN))
		if b.passT > 0:
			b.passT -= dt; wantLat = b.passLat
		if absf(b.speed - target) < 0.4:
			pass
		elif b.speed < target:
			b.speed = minf(target, b.speed + b.acc * maxf(0.08, 1 - pow(b.speed / b.vmax, 2)) * clamp_((target - b.speed) * 0.6 + 0.25, 0.25, 1) * dt)
		else:
			b.speed = maxf(target, b.speed - clamp_((b.speed - target) * 4, 0, b.brk + 4) * dt)
		var sd = surfaceDrag(absf(b.lat))
		if sd != null and b.speed > sd[0]: b.speed -= sd[1] * dt
		b.speed = maxf(0, b.speed)
		b.cur = b.speed
		if not b.noAvoid:
			var others := []
			for o in bots:
				if o != b and not o.out: others.append({"s": o.s, "lat": o.lat, "len": o.m.len})
			others.append({"s": player.s, "lat": player.lat, "len": car.len if car != null else 4.4})
			if split and p2 != null: others.append({"s": p2.pl.s, "lat": p2.pl.lat, "len": p2.car.len if p2.car != null else 4.4})
			for o in others:
				var ds := Trk.wrapD(o.s - b.s)
				var dl2: float = b.lat - o.lat
				if absf(ds) < (o.len + b.m.len) / 2 + 1.2 and absf(dl2) < 3.0:
					var away := MathX.sgn(dl2)
					if away == 0: away = -1.0 if b.lat < 0 else 1.0
					var lim2 := Trk.ROAD_HALF - 1.3
					var cand: float = o.lat + away * 3.05
					wantLat = cand if absf(cand) <= lim2 else o.lat - away * 3.05
					if MathX.sgn(wantLat - b.lat) == -away:
						b.contactT = maxf(b.contactT, 0.3); b.contactSide = -away
		var dl: float = clamp_(wantLat, -(Trk.ROAD_HALF - 1.3), Trk.ROAD_HALF - 1.3) - b.lat
		var vmaxL := 3.2
		if b.contactT > 0:
			b.contactT -= dt
			if MathX.sgn(dl) == b.contactSide: vmaxL = 0.4
		var want := clamp_(dl * 1.6, -vmaxL, vmaxL)
		b.latV += clamp_(want - b.latV, -7 * dt, 7 * dt)
		b.lat += b.latV * dt
		var slip := spinStep(b, dt, df.rec)
		if slip > 0.05:
			b.speed = maxf(0, b.speed - (11.0 if b.spun else slip * 14) * dt)
			b.slideT = 0.8 if b.spun else 0.4
		b.lat += b.lp * dt
		b.lp *= exp(-dt * (1.1 if slip > 0.1 else 2.5))
		b.yawK *= exp(-dt * 3)
		var lim3 := botLatLimit()
		b.lat = clamp_(b.lat, -lim3, lim3)
		var prevRel := Trk.wrapD(b.s - Trk.S_START)
		b.s = fmod(b.s + b.speed * dt, Trk.TRACK_LEN)
		var rel := Trk.wrapD(b.s - Trk.S_START)
		if prevRel < 0 and rel >= 0:
			b.lap += 1
			if b.lap > 1:
				var lt: float = raceTime - b.lapStart
				if not b.bestLap or lt < b.bestLap: b.bestLap = lt
			b.lapStart = raceTime
			if b.lap > raceLaps and not b.finished and mode != "elim":
				b.finished = true; b.finishTime = raceTime
		poseOnTrack(b.m.g, b.s, b.lat, -atan2(b.latV, maxf(4, b.speed)) + b.yawK + b.yawOff)
		var i2 := int(floor(b.s / Trk.SPC)) % Trk.NS
		leanBot(b, i2, dt)
		var lv: float = b.latV + b.lp
		b.vx = Trk.T[i2].x * b.speed + Trk.R[i2].x * lv
		b.vz = Trk.T[i2].z * b.speed + Trk.R[i2].z * lv
		for w in b.m.wheels:
			w.spin.rotation.x += wheelSpin(b.speed, w.r, dt)
		CarKit.autoBrake(b.m, b.speed, dt)
	botCollisions()

## a bot's body leans like the player's: out of the bend, forward under braking (and its wheels stay on the road)
func leanBot(b: Mover, i: int, dt: float) -> void:
	var NS := Trk.NS
	var ta := Trk.T[(i - 2 + NS) % NS]
	var tb := Trk.T[(i + 2) % NS]
	var right := -MathX.sgn(ta.z * tb.x - ta.x * tb.z)          # +1 in a right-hand bend
	var soft: float = handling(b.type).roll
	var ay: float = b.speed * b.speed * Trk.CURV[i] * right + b.latV * 2.0
	var ax: float = (b.speed - b.prevV) / maxf(dt, 1e-4)
	b.prevV = b.speed
	var k := minf(1, dt * 6)
	b.roll += (clamp_(ay * 0.0011 * soft, -0.07, 0.07) - b.roll) * k
	b.pitch += (clamp_(-ax * 0.0014 * (0.6 + 0.4 * soft), -0.03, 0.045) - b.pitch) * k
	var g: Node3D = b.m.g
	g.rotation.x += b.pitch
	g.rotation.z = -b.roll
	tiltRig(b.m, b.pitch, b.roll, 0.0)
	# the front wheels point into the bend (and where the car is steering to across the road)
	var sv := clamp_(right * Trk.CURV[i] * handling(b.type).L * 1.3 + b.latV * 0.04, -0.45, 0.45)
	for q in 2: b.m.wheels[q].pivot.rotation.y = -sv

func playerPosition() -> int:
	if mode == "elim" and playerOut: return elimPos
	var me := progressOf(player.lap, player.s, raceDone and not playerOut, raceFinishTime)
	var p := 1
	var o = otherProgress()
	if o != null and o > me: p += 1
	p += netAheadCount(me)
	for b in bots:
		if not b.out and progressOf(b.lap, b.s, b.finished, b.finishTime) > me: p += 1
	return p

# ================================================================== physics
func locatePlayer() -> void:
	var best := player.idx
	var bd := INF
	var NS := Trk.NS
	for k in range(-45, 46):
		var i := (player.idx + k + NS) % NS
		var dx := player.pos.x - Trk.P[i].x
		var dz := player.pos.z - Trk.P[i].z
		var d := dx * dx + dz * dz
		if d < bd: bd = d; best = i
	var i := best
	var dx := player.pos.x - Trk.P[i].x
	var dz := player.pos.z - Trk.P[i].z
	player.idx = i
	player.lat = dx * Trk.R[i].x + dz * Trk.R[i].z
	var along := dx * Trk.T[i].x + dz * Trk.T[i].z
	player.s = fposmod(i * Trk.SPC + along, Trk.TRACK_LEN)
	var f := along / Trk.SPC
	var j := (i + 1) % NS if f >= 0 else (i - 1 + NS) % NS
	var t := minf(1, absf(f))
	player.y = Trk.hAt(i, player.lat) * (1 - t) + Trk.hAt(j, player.lat) * t

func surfaceDrag(a: float) -> Variant:
	match Trk.TRACK_ID:
		"polder": return [17, 26] if a > Trk.ROAD_HALF + 0.8 else null
		"limburg": return [16, 14] if a > Trk.ROAD_HALF + 0.6 else null
		"veluwe": return [16, 14] if a > Trk.ROAD_HALF + 0.6 and not (a > 7.3 and a < 9.7) else null
		"circuit":
			if a > 13: return [9, 40]
			if a > Trk.ROAD_HALF + 1.3: return [25, 18]
	return null

const GEARS := [0.3, 0.47, 0.62, 0.76, 0.89, 1.0]
const GACC := [1.12, 1.07, 1.0, 0.93, 0.86, 0.8]
const SHIFT := {"B": 0.32, "A": 0.26, "S": 0.18}

func gearTop(g: int) -> float:
	return GEARS[g - 1] * MAXV * 1.03

func updateGear(dt: float, gas: float) -> void:
	var v := player.speed
	if v < -0.5:
		player.gear = -1; player.shiftT = 0; return
	if player.gear < 1: player.gear = 1
	if player.shiftT > 0:
		player.shiftT -= dt; return
	if G.prefs.gearbox == "manual": return
	var rpm := maxf(0, v) / gearTop(player.gear)
	if rpm > 0.96 and player.gear < 6 and gas > 0.1:
		player.gear += 1; player.shiftT = SHIFT[Cars.CARS[G.settings.car].cls]
		if v > 8: Sfx.tone(170, 0.06, "triangle", 0.05)
	elif player.gear > 1 and v < gearTop(player.gear - 1) * (0.7 if gas > 0.1 else 0.55):
		player.gear -= 1; player.shiftT = 0.1

func shiftUp() -> void:
	if player.gear < 1 or player.gear >= 6 or player.shiftT > 0: return
	player.gear += 1; player.shiftT = SHIFT[Cars.CARS[G.settings.car].cls]; Sfx.tone(170, 0.06, "triangle", 0.05)

func shiftDown() -> void:
	if player.gear <= 1 or player.shiftT > 0: return
	if maxf(0, player.speed) / gearTop(player.gear - 1) > 1.04:
		Hud.showToast("Toerental te hoog"); return
	player.gear -= 1; player.shiftT = 0.12

func engineRpm() -> float:
	if player.gear < 1: return clamp_(0.18 + absf(player.speed) / 12, 0.18, 0.6)
	var r := maxf(0, player.speed) / gearTop(player.gear)
	return clamp_(maxf(r, (0.3 + player.gasIn * 0.1) if (player.gear == 1 and player.gasIn > 0.1) else 0.14), 0.14, 1)

## JS gearInfo / skidAmount (audio section; also used by the HUD and the fx): the gear shown and the engine's rpm,
## and how hard the tyres squeal
func gearInfo() -> Dictionary:
	var v := absf(player.speed)
	var live := state == "racing" or state == "finished"
	return {"gear": "R" if player.gear < 0 else ("N" if not live and v < 0.5 else str(player.gear)),
		"rpm": (0.14 + player.gasIn * 0.6) if state == "countdown" else engineRpm()}

func skidAmount() -> float:
	if not (state == "racing" or state == "finished"): return 0.0
	var pl := player
	var v := absf(pl.speed)
	# tyres over their limit: the rear counts fully (a slide), the front less (scrubbing wide)
	var tyres := clamp_((maxf(pl.slipF * 0.8, pl.slipR) - 0.9) * 3.0, 0, 3.5) * clamp_(v / 8, 0, 1)
	return (1.6 if pl.gear == 1 and pl.gasIn > 0.9 and v < 9 and Cars.CARS[G.settings.car].cls != "B" else 0.0) \
		+ (pl.push + pl.slide - pl.slideOut).length() * 0.6 + (2.5 if pl.hand and v > 5 else 0.0) + tyres \
		+ (1.3 if pl.brk > 0.5 and v > 18 else 0.0)

# ------------------------------------------------------------------ handling model
## How the player's car drives (drive -> driveStep):
##  - The car has a velocity of its own (`speed` along the nose, `slide` across it) and a yaw rate (`yr`). Two axles of
##    tyres pull that velocity towards where the wheels point. Each axle has a limit: the lateral grip the game always
##    had (grip stat x weather x surface; it grows with speed), shared by the weight on the axle. Up to the limit the
##    car goes where you steer; past it the tyres slide: the front runs wide (understeer), the rear comes round.
##  - What shifts the balance: braking moves weight to the front and uses grip (the tail gets light: trail braking
##    turns the car in), power uses the grip of the driven wheels (a strong rear-drive car power-slides, a front-drive
##    car pushes wide), lifting tucks the nose in, the handbrake lets go of the rear, a crest makes the car light.
##  - Steering asks for a yaw rate (the turn rates the game always had) and the front wheels turn as far as that takes,
##    so a steady corner is driven exactly as before; the limit shows in what you ask on top of it.
##  - Below ~30 km/h and in reverse the car simply follows its wheels (parking and hairpins stay easy).
##  - Shoves from outside (a hit, a wall, a gust) go through `push`: they move the car sideways for a moment and fade,
##    as before, instead of being eaten by the tyres.
const AP_F := 0.11           ## slip angle (rad) at which the front / rear tyres give their most
const AP_R := 0.10
const TY_C := 1.3            ## tyre curve sin(C atan(B x)): 1 at x = 1, 0.89 far past it (a slide keeps most of its grip)
const TY_B := 2.6427
const STEER_OVER := 1.05     ## full lock asks 5 % more than the front tyres have: you hear and feel the limit
const WT_K := 0.0035         ## weight moved per m/s2 of acceleration (share of the car's weight)
const TYRE_LS := 0.8         ## a tyre with twice the load has 2^0.8 times the grip
const BRAKE_USE_F := 0.62    ## share of the front / rear tyres' grip that full braking takes
const BRAKE_USE_R := 0.64
const STEER_AID := 1.0      ## how far the stability aid opens the steering when the tail slides (0 = off)
const POWER_GRIP := 0.78     ## grip along the car against grip across it (lower: power slides sooner)
const HAND_GRIP := 0.4       ## rear grip left with the handbrake on
const SCRUB := 0.4          ## share of the natural speed loss of a slipping tyre that is kept (1 = real, 0 = slides cost nothing)
const BETA_LIFT := 0.14      ## slip angle (rad) past which the car helps you catch the slide: off the gas,
const BETA_GAS := 0.42       ## on the gas (a power slide),
const BETA_HAND := 1.1       ## with the handbrake on
const LOAD_G := 70.0         ## "gravity" for crests and dips (m/s2): the car gets light when v2 x curvature nears it

## what kind of car each model is (how fast it is stays in Cars.CARS): driven wheels (f front, r rear, a all), share of
## the weight on the front wheels, how planted the rear is (1.04 lively .. 1.18 very steady), how much the body leans,
## and how much of the driven tyres' grip full power may take (traction: 0.6 tidy .. 0.86 a handful)
const FEEL := {
	"hatch": ["f", 0.61, 1.16, 1.15, 0.7], "rally": ["a", 0.56, 1.10, 1.25, 0.8], "coupe": ["f", 0.59, 1.14, 1.05, 0.7],
	"roadster": ["r", 0.50, 1.07, 1.0, 0.76], "mini": ["f", 0.62, 1.12, 1.2, 0.7], "retro": ["r", 0.53, 1.06, 1.3, 0.8],
	"gt": ["r", 0.50, 1.10, 0.9, 0.72], "muscle": ["r", 0.55, 1.05, 1.35, 0.86], "fastback": ["r", 0.53, 1.07, 1.1, 0.78],
	"sedan": ["r", 0.53, 1.13, 1.0, 0.66], "wagon": ["a", 0.55, 1.16, 1.1, 0.7], "evo": ["a", 0.57, 1.11, 0.95, 0.8],
	"super": ["r", 0.43, 1.10, 0.6, 0.64], "hyper": ["a", 0.45, 1.14, 0.55, 0.7], "longtail": ["r", 0.42, 1.12, 0.6, 0.62],
	"proto": ["r", 0.46, 1.16, 0.45, 0.58], "v12": ["r", 0.51, 1.08, 0.75, 0.7], "speedster": ["r", 0.47, 1.07, 0.65, 0.68]}
var _feel := {}

## the handling numbers of a model: L wheelbase, a/b centre of gravity to front/rear axle, k2 yaw inertia per mass,
## wf front weight share, df share of the power on the front wheels, kr rear grip margin, roll body lean, pw traction
func handling(id: String) -> Dictionary:
	if _feel.has(id): return _feel[id]
	var F: Array = FEEL.get(id, FEEL.gt)
	var S: Dictionary = Cars.CAR_SPECS.get(id, Cars.CAR_SPECS.gt)
	var L: float = S.wz[0] - S.wz[1]
	var wf: float = F[1]
	var m: float = Cars.CARS[id].mass if Cars.CARS.has(id) else 1.0
	var h := {"L": L, "a": L * (1 - wf), "b": L * wf, "k2": L * L * wf * (1 - wf) * (0.8 + 0.25 * m), "wf": wf,
		"df": 1.0 if F[0] == "f" else (0.0 if F[0] == "r" else 0.4), "kr": F[2], "roll": F[3], "drv": F[0], "pw": F[4]}
	_feel[id] = h
	return h

static func tyre(x: float) -> float:
	return sin(TY_C * atan(TY_B * x))

## the slip (in units of the slip at the limit) that gives the share q of a tyre's grip; asked for more than it has
## (q > 1) the tyre is pushed past its limit
static func tyreInv(q: float) -> float:
	if q >= 1.0: return minf(2.2, 1.0 + (q - 1.0) * 3.0)
	return tan(asin(q) / TY_C) / TY_B

## the lateral acceleration (m/s2) a car with grip 1 can hold at speed v: the turn rate the game always had times the speed
static func latGrip(v: float) -> float:
	var vv := maxf(v, 8.0)
	return 1.7 * vv * maxf(0.32, 1 - 0.5 * vv / 69.4)

## off the tarmac, per track: [where it starts (m past the road edge), grip, drag (m/s2), the speed the drag works down to, rumble]
const VERGE := {"polder": [0.8, 0.7, 26.0, 17.0, 1.0], "limburg": [0.6, 0.72, 14.0, 16.0, 0.9], "veluwe": [0.6, 0.72, 14.0, 16.0, 0.9],
	"circuit": [1.3, 0.75, 18.0, 25.0, 0.8]}
const GRAVEL := [13.0, 0.6, 40.0, 9.0, 1.5]     ## circuit: the gravel trap, from 13 m off the centre line
const COBBLES := {"dorp": 0.2, "grachten": 0.2}  ## brick roads rumble a little
var _kerbKey := ""
var _kerb := PackedByteArray()

## circuit: the stretches with red and white kerbs (the rule of the track builder: where the road bends)
func kerbAt(i: int) -> bool:
	if Trk.TRACK_ID != "circuit": return false
	var key := Trk.TRACK_DIR + str(Trk.NS)
	if key != _kerbKey or _kerb.size() != Trk.NS:
		_kerbKey = key
		var NS := Trk.NS
		_kerb = PackedByteArray()
		_kerb.resize(NS)
		for j in NS:
			var a := Trk.T[(j - 4 + NS) % NS]
			var b := Trk.T[(j + 4) % NS]
			if acos(clampf(a.x * b.x + a.z * b.z, -1, 1)) > 0.07:
				for k in range(-6, 7): _kerb[(j + k + NS) % NS] = 1
	return _kerb[i] != 0

## the ground under the wheels of one side, a metres from the centre line: [share off the tarmac, grip, drag, slowest, rumble]
func groundAt(a: float, i: int) -> Array:
	var id := Trk.TRACK_ID
	var V = VERGE.get(id)
	var rum: float = COBBLES.get(id, 0.0) if a < Trk.ROAD_HALF else 0.0
	if V == null: return [0.0, 1.0, 0.0, 0.0, rum]
	var t := clamp_((a - (Trk.ROAD_HALF + V[0])) / 0.8, 0, 1)
	if id == "veluwe": t *= clamp_(maxf(7.4 - a, a - 9.6) / 0.3, 0, 1)      # the cycle path beside the road is paved
	if id == "circuit":
		if a > Trk.ROAD_HALF and a < Trk.ROAD_HALF + 1.3 and kerbAt(i): rum = 0.7
		var g := clamp_((a - (GRAVEL[0] - 0.3)) / 0.6, 0, 1)
		if g > 0:
			return [1.0, V[1] + (GRAVEL[1] - V[1]) * g, V[2] + (GRAVEL[2] - V[2]) * g, V[3] + (GRAVEL[3] - V[3]) * g, V[4] + (GRAVEL[4] - V[4]) * g]
	t = t * t * (3 - 2 * t)
	return [t, V[1], V[2], V[3], maxf(rum, V[4] * t)]

## how hard the road pushes back at sample i at speed v: less over a crest, more in a dip (0.85 .. 1.15)
func roadLoad(i: int, v: float) -> float:
	var NS := Trk.NS
	var d := 3
	var k: float = (Trk.HT[(i + d) % NS] - 2 * Trk.HT[i] + Trk.HT[(i - d + NS) % NS]) / (d * d * Trk.SPC * Trk.SPC)
	return clamp_(1 + v * v * k / LOAD_G, 0.85, 1.15)

func drive(dt: float, inp: Dictionary) -> void:
	# the tyre model wants short steps (the game loop gives at most 8.5 ms; anything longer is cut up here)
	var n := maxi(1, int(ceil(dt / 0.009 - 1e-6)))
	for _k in n: driveStep(dt / n, inp)

func driveStep(dt: float, inp: Dictionary) -> void:
	var pl := player
	var H := handling(G.settings.car)
	pl.gasIn = inp.gas
	updateGear(dt, inp.gas)
	# ---- the velocity the tyres work on: along the nose (u) and to the right (w), without the shoves from outside
	pl.push += pl.slide - pl.slideOut
	var fx := sin(pl.heading); var fz := cos(pl.heading)
	var tvx := fx * pl.speed + pl.slide.x - pl.push.x
	var tvz := fz * pl.speed + pl.slide.y - pl.push.y
	var u := tvx * fx + tvz * fz
	var w := -tvx * fz + tvz * fx
	var v := u
	var av := absf(u)
	var sAbs := av / 69.4
	# ---- steering: a stick is followed almost directly; keys ease into the lock (calmer at speed) and centre quickly
	var st := clamp_(inp.steer, -1, 1)
	var rate := 16.0
	if not inp.analog:
		rate = 11.0 if (absf(st) < absf(pl.steer) or st * pl.steer < 0) else lerpf(8.5, 5.5, minf(1, sAbs))
	pl.steer += (st - pl.steer) * minf(1, dt * rate)
	# ---- the ground: verge, grass, gravel, kerbs (left and right wheels apart), crests and dips
	var ti := pl.idx % Trk.NS
	var gL := groundAt(absf(pl.lat - 0.8), ti)
	var gR := groundAt(absf(pl.lat + 0.8), ti)
	var off: float = (gL[0] + gR[0]) * 0.5
	# loose ground has less grip; at walking pace that does not matter (you can always steer out of the gravel)
	var surf: float = 1 - (gL[0] * (1 - gL[1]) + gR[0] * (1 - gR[1])) * 0.5 * clamp_((av - 6) / 10, 0, 1)
	var dragL: float = gL[0] * gL[2] * clamp_((av - gL[3]) / 5.0, 0, 1)
	var dragR: float = gR[0] * gR[2] * clamp_((av - gR[3]) / 5.0, 0, 1)
	pl.offroad = off
	pl.rumble += (maxf(gL[4], gR[4]) * clamp_(av / 12, 0, 1) - pl.rumble) * minf(1, dt * 10)
	pl.load += (roadLoad(ti, av) - pl.load) * minf(1, dt * 8)
	var gf := gripFactor()
	# ---- engine, brakes, drag
	var VM := MAXV
	var gi := clampi(pl.gear, 1, 6) - 1
	var rpm := engineRpm()
	var torque := 0.78 + 0.22 * clamp_(rpm / 0.45, 0, 1)
	var limiter := 0.0 if maxf(0, pl.speed) >= gearTop(clampi(pl.gear, 1, 6)) * 0.995 else 1.0
	var cut := (0.12 if pl.shiftT > 0 and pl.gear > 1 else 1.0) * limiter
	var aDrive := 0.0
	var ax := 0.0
	var braking := 0.0
	if inp.gas > 0.05:
		aDrive = ACC * GACC[gi] * torque * cut * inp.gas * maxf(0.04, 1 - pow(maxf(0, v) / VM, 2))
		ax = aDrive
	elif inp.brake > 0.05:
		if v > 0.5:
			# a wet or loose surface takes longer to stop on
			braking = inp.brake
			ax = -BRAKE * inp.brake * (0.4 + 0.6 * gf * surf)
		else: ax = -6 * inp.brake
	else:
		var c := COAST * (0.7 + 0.9 * rpm * (1.2 - gi * 0.08))
		ax = -MathX.sgn(v) * minf(c, av / dt)
	ax -= (dragL + dragR) * 0.5 * MathX.sgn(v)
	pl.hand = bool(inp.hand) and absf(pl.speed) > 3
	pl.brk = inp.brake
	if pl.hand: ax -= MathX.sgn(v) * 7
	if state == "racing":
		if pl.speed > raceTopSpeed: raceTopSpeed = pl.speed
		if pl.speed > 83.3: unlockAch("speed300")
	# ---- grip: what each axle can hold sideways right now
	pl.wt += (clamp_(ax * WT_K, -0.17, 0.1) - pl.wt) * minf(1, dt * 9)
	var A := GRIP * gf * surf * pl.load * latGrip(av)
	var Nf: float = H.wf - pl.wt
	var capF: float = A * H.wf * pow(Nf / H.wf, TYRE_LS)
	var capR: float = A * (1 - H.wf) * pow((1 - Nf) / (1 - H.wf), TYRE_LS) * H.kr
	# brakes and power use up grip. When the rear starts to slide they let go of it again (as ABS and traction control
	# do): hard braking in a corner turns the car in but does not spin it, power slides stay catchable
	var useF := braking * BRAKE_USE_F
	var useR := braking * BRAKE_USE_R * (1 - 0.85 * clamp_((pl.slipR - 0.8) / 0.6, 0, 1))
	if aDrive > 0:
		var Ax := A * POWER_GRIP
		useF = minf(H.pw, aDrive * H.df / (Ax * Nf))
		useR = minf(H.pw, aDrive * (1 - H.df) / (Ax * (1 - Nf))) * (1 - 0.7 * clamp_((pl.slipR - 1.8) / 1.5, 0, 1))
	capF *= sqrt(1 - useF * useF)
	capR *= sqrt(1 - useR * useR)
	if pl.hand: capR *= HAND_GRIP
	# ---- the front wheels: steering asks for a yaw rate; they turn as far as that takes in a steady corner
	var wFull := 1.7 * GRIP * clamp_(av / 8, 0, 1) * maxf(0.32, 1 - 0.5 * sAbs)
	# hard on the brakes the fronts have less to steer with: ask for less, as the game always did
	var wc := pl.steer * wFull * STEER_OVER * (1 - 0.26 * braking * clamp_((av - 10) / 5, 0, 1))
	# stability aid: the tail is sliding out and you still steer into the corner: the car opens the steering a little
	# for you (counter-steering yourself, or the handbrake, switches it off)
	if not pl.hand and pl.steer * pl.beta < 0:
		wc *= 1 - STEER_AID * clamp_((pl.slipR - 1.1 - 0.8 * inp.gas) / 1.2, 0, 1)
	var q := absf(wc) * av / (GRIP * gf * surf * latGrip(av))
	var den := maxf(av, 3.0)
	var delta: float = clamp_(MathX.sgn(wc) * (H.L * absf(wc) / maxf(av, 8.0) + AP_F * tyreInv(q) - AP_R * tyreInv(q / H.kr)), -0.6, 0.6)
	pl.delta = delta
	# ---- tyre forces (per unit of mass, to the right) from the slip angle of each axle
	var aF := atan2(w + H.a * pl.yr, den) - delta
	var aR := atan2(w - H.b * pl.yr, den)
	var FF: float = -capF * tyre(aF / AP_F)
	var FR: float = -capR * tyre(aR / AP_R)
	# kd: 1 = the tyres decide, 0 = slow or reversing: the car follows its wheels
	var kd := clamp_((u - 3.0) / 6.0, 0, 1)
	var yawAcc: float = (H.a * FF - H.b * FR) / H.k2
	# a wheel on the grass drags that side back
	yawAcc += (dragR - dragL) * 0.03
	var beta := atan2(w, den)
	# a slide that gets too deep: the car helps to catch it (not while a hit is spinning it). On the gas you may
	# hold a deeper slide (a power slide), the handbrake allows a deeper one still; lifting off brings the car back
	var soft := BETA_HAND if pl.hand else lerpf(BETA_LIFT, BETA_GAS, clamp_(inp.gas, 0, 1))
	var over := maxf(0, absf(beta) - soft) * (1 - clamp_(absf(pl.spin), 0, 1))
	if over > 0:
		# turn the nose back towards where the car is going, and brake any turning that makes the slide deeper
		yawAcc += MathX.sgn(beta) * over * 16.0
		if pl.yr * beta < 0: yawAcc -= pl.yr * minf(8.0, over * 16.0)
	var latAcc := (FF + FR) * kd
	pl.yr += yawAcc * kd * dt
	var turn := 1.7 * GRIP * gf * clamp_(av / 8, 0, 1) * maxf(0.32, 1 - 0.5 * sAbs)
	if inp.brake > 0.3 and av > 15: turn *= 1 - 0.22 * inp.brake
	if pl.hand: turn *= 1.55
	pl.yr += (pl.steer * turn * (MathX.sgn(u) if u != 0 else 1.0) - pl.yr) * (1 - kd) * minf(1, dt * 30)
	# a slipping tyre costs speed; part of that is given back (SCRUB), less the deeper the slide
	if latAcc * w < 0 and u > 5:
		ax += (1 - SCRUB) * absf(latAcc * w) / sqrt(u * u + w * w) * clamp_(1 - (absf(beta) - 0.9) / 0.5, 0, 1)
	u += ax * dt
	w += latAcc * dt
	u = clamp_(u, minf(REVMAX, v), MAXV)
	# ---- turn the car; its velocity stays where it was (kd) or turns along (slow)
	var phi := pl.yr * dt
	pl.heading -= phi
	var cp := cos(phi * kd); var sp := sin(phi * kd)
	var u2 := u * cp + w * sp
	w = -u * sp + w * cp
	u = u2
	w *= exp(-dt * (1 - kd) * 8)
	# ---- a hit spins the car round its own momentum (as before)
	if pl.spin != 0:
		var ps := -pl.spin * dt
		pl.heading += pl.spin * dt
		var cs := cos(ps); var ss := sin(ps)
		u2 = u * cs + w * ss
		w = -u * ss + w * cs
		u = u2
		pl.spin *= exp(-dt * (6.0 if absf(pl.spin) < 0.5 else 1.6))
		if absf(pl.spin) < 0.02: pl.spin = 0
	pl.push *= exp(-dt * (1.6 if pl.hand else 4.5))
	if pl.push.length_squared() < 1e-6: pl.push = Vector2.ZERO
	# ---- back to speed along the nose + the rest, and move
	fx = sin(pl.heading); fz = cos(pl.heading)
	var nvx := fx * u - fz * w + pl.push.x
	var nvz := fz * u + fx * w + pl.push.y
	pl.speed = nvx * fx + nvz * fz
	pl.slide = Vector2(nvx - fx * pl.speed, nvz - fz * pl.speed)
	pl.slideOut = pl.slide
	pl.pos.x += nvx * dt
	pl.pos.z += nvz * dt
	# ---- what the rest of the game shows and hears
	pl.slipF = absf(aF) / AP_F * kd
	pl.slipR = absf(aR) / AP_R * kd
	pl.beta = beta * clamp_(av / 4.0, 0, 1) if u > 0 else 0.0
	pl.ax += (ax - pl.ax) * minf(1, dt * 12)
	pl.ay += (u * pl.yr - pl.ay) * minf(1, dt * 12)

func botLatLimit() -> float:
	return minf(Trk.TRK.edgeAt - 0.2, Trk.ROAD_HALF + 4) if Trk.TRK.edge == "wall" else Trk.ROAD_HALF + 1.6

func hitFx(j: float, near: bool) -> void:
	if j < 2 or clock - hitT < 0.12: return
	hitT = clock
	var q := 1.0 if near else 0.35
	if near and fxOn() and j > 3.5: shake = maxf(shake, minf(0.2, (j - 3.5) * 0.015))
	Sfx.noise(0.12 + minf(0.2, j * 0.012), minf(0.45, 0.1 + j * 0.02) * q, 600 + minf(900, j * 40))
	if j > 7 and near: Sfx.tone(85, 0.14, "square", 0.1)

func nudgeOther(c: Mover, dx: float, dz: float) -> void:
	var a := Trk.trackAt(c.s)
	var ds: float = dx * a.tx + dz * a.tz
	var dl: float = dx * a.rx + dz * a.rz
	c.s = fposmod(c.s + ds + Trk.TRACK_LEN, Trk.TRACK_LEN)
	c.lat += dl

func kickOther(c: Mover, dvx: float, dvz: float, sp: float) -> void:
	var a := Trk.trackAt(c.s)
	var along: float = dvx * a.tx + dvz * a.tz
	var side: float = dvx * a.rx + dvz * a.rz
	if c.is_bot:
		c.speed = maxf(0, c.speed + along)
		if along > 0: c.pushDv = minf(8, c.pushDv + along)
	else:
		c.dv += along
	c.lp += side
	c.spin = clamp_(c.spin + sp, -6, 6)
	if absf(side) > 0.01:
		c.contactT = 0.8; c.contactSide = -MathX.sgn(side)

## spin & slide of a pushed car: a damped spring pulls the car straight again (countersteer); big spins scrub speed
func spinStep(c: Mover, dt: float, rec: float) -> float:
	if c.spin == 0 and c.yawOff == 0 and not c.spun: return 0.0
	var y := c.yawOff
	if c.spun:
		c.spunT += dt
		c.spin *= exp(-dt * (6.0 if c.spunT > 2.5 else 1.25))
		var slow := (c.speed < 11 or c.spunT > 2.5) if c.is_bot else true
		if absf(c.spin) < 0.4 and slow:
			y = fposmod(y + PI, TAU) - PI
			c.spin = 0
			y -= MathX.sgn(y) * minf(absf(y), 2.6 * dt)
			if absf(y) < 0.3:
				c.spun = false; c.spunT = 0
	else:
		if absf(y) > 1.0 and c.is_bot and c.hitByPlayer and clock - c.hitByPlayer < 2 and state == "racing":
			c.hitByPlayer = 0; achPit()
		c.spin += (-sin(y) * rec * 1.1 * (0.3 if absf(c.spin) > 1.2 else 1.0) - c.spin * (6.0 if absf(c.spin) < 0.5 and absf(y) < 0.35 else 1.4)) * dt
		if absf(y) > 1.0: c.spun = true
	y += c.spin * dt
	c.yawOff = y
	if not c.spun and absf(y) < 0.002 and absf(c.spin) < 0.01:
		c.yawOff = 0; c.spin = 0
	return 1.0 if c.spun else absf(sin(y))

const WALL_RUB := 0.4        ## share of the speed into a wall that the hit takes off the speed along it
const WALL_BOUNCE := 0.12    ## share of the speed into a wall that comes back
const WALL_SCRAPE := 5.0     ## m/s2 lost while scraping along a wall
const POS_K := 0.4
const REST := 0.1
const SPIN_K := 0.8
const YAW_GRIP := 0.55
const CAR_RC := 0.26

## tyres absorb small yaw kicks: only the part above the grip limit turns the car
static func yawKick(d: float, grip := 1.0) -> float:
	return MathX.sgn(d) * maxf(0, absf(d) - YAW_GRIP * grip)

## In plan view every car is a rounded rectangle: its length and width with corners of radius rc, turned the way
## you see it (the player's drift included). So the hitbox is the car itself, not a box round it.
func bodyOf(c: Mover) -> Dictionary:
	var g: Node3D = c.m.g
	var h := g.rotation.y
	var co: float = c.m.get("off", 0.0)
	return {"c": c, "x": g.position.x + sin(h) * co, "z": g.position.z + cos(h) * co, "h": h, "len": c.m.len, "wid": c.m.wid,
		"rc": c.m.get("rc", 0.0), "m": c.mass, "vx": c.vx, "vz": c.vz}

func playerBody() -> Dictionary:
	var po: float = car.get("off", 0.0)
	var h := player.heading - drift
	var fx := sin(player.heading); var fz := cos(player.heading)
	return {"x": player.pos.x + sin(h) * po, "z": player.pos.z + cos(h) * po, "h": h, "len": car.len, "wid": car.wid, "rc": car.get("rc", 0.0),
		"m": Cars.CARS[G.settings.car].mass, "vx": fx * player.speed + player.slide.x, "vz": fz * player.speed + player.slide.y}

## the rectangle inside the rounded corners, corners in order round it
static func innerRect(D: Dictionary) -> Array:
	var s := sin(D.h); var c := cos(D.h)
	var a: float = D.len / 2 - D.rc
	var b: float = D.wid / 2 - D.rc
	return [Vector2(D.x + s * a + c * b, D.z + c * a - s * b), Vector2(D.x + s * a - c * b, D.z + c * a + s * b),
		Vector2(D.x - s * a - c * b, D.z - c * a + s * b), Vector2(D.x - s * a + c * b, D.z - c * a - s * b)]

## contact between two rounded rectangles: normal from B to A, penetration, and (when the corners touch) the contact point
static func pairContact(A: Dictionary, B: Dictionary) -> Variant:
	var dx: float = A.x - B.x
	var dz: float = A.z - B.z
	var ra := Vector2(A.len, A.wid).length() / 2
	var rb := Vector2(B.len, B.wid).length() / 2
	if dx * dx + dz * dz > (ra + rb) * (ra + rb): return null
	var PA := innerRect(A)
	var PB := innerRect(B)
	var R: float = A.rc + B.rc
	var sep := false
	var bo := 1e9
	var bn := Vector2.ZERO
	for D in [A, B]:
		var s := sin(D.h); var c := cos(D.h)
		for u in [Vector2(s, c), Vector2(c, -s)]:
			var a0 := 1e9; var a1 := -1e9; var b0 := 1e9; var b1 := -1e9
			for q in PA:
				var d: float = q.x * u.x + q.y * u.y
				a0 = minf(a0, d); a1 = maxf(a1, d)
			for q in PB:
				var d: float = q.x * u.x + q.y * u.y
				b0 = minf(b0, d); b1 = maxf(b1, d)
			var o1 := a1 - b0
			var o2 := b1 - a0
			if o1 <= 0 or o2 <= 0:
				sep = true; break
			var o := minf(o1, o2)
			if o < bo:
				bo = o; bn = -u if o1 < o2 else u
		if sep: break
	if not sep:
		return {"nx": bn.x, "nz": bn.y, "pen": bo + R}
	var pr := []
	var bd := 1e9
	for pass_ in 2:
		var Pp: Array = PA if pass_ == 0 else PB
		var Q: Array = PB if pass_ == 0 else PA
		for q in Pp:
			for i in 4:
				var a: Vector2 = Q[i]
				var b: Vector2 = Q[(i + 1) & 3]
				var e := b - a
				var el := e.length_squared()
				var t := clamp_(((q.x - a.x) * e.x + (q.y - a.y) * e.y) / (el if el != 0 else 1.0), 0, 1)
				var p := a + e * t
				var d: float = (q - p).length()
				if d < bd: bd = d
				pr.append([p.x, p.y, q.x, q.y, d] if pass_ == 1 else [q.x, q.y, p.x, p.y, d])
	var dd := bd
	if dd >= R: return null
	if dd < 1e-6:
		var l := Vector2(dx, dz).length()
		if l == 0: l = 1
		return {"nx": dx / l, "nz": dz / l, "pen": R}
	# every pair (nearly) as close as the closest one: two parallel sides touch along a line, and its middle is the contact
	# point, so a straight hit pushes straight instead of turning the car round a corner
	var ax := 0.0; var az := 0.0; var bx := 0.0; var bz := 0.0; var n := 0
	var m = null
	for q in pr:
		if q[4] <= dd + 0.01:
			ax += q[0]; az += q[1]; bx += q[2]; bz += q[3]; n += 1
		if m == null and q[4] == dd: m = q
	ax /= n; az /= n; bx /= n; bz /= n
	var nx: float = (m[0] - m[2]) / dd
	var nz: float = (m[1] - m[3]) / dd
	var k: float = B.rc - (R - dd) / 2
	return {"nx": nx, "nz": nz, "pen": R - dd, "cx": bx + nx * k, "cz": bz + nz * k}

## contact point of a deep hit: middle of the overlap of both boxes along the contact face, on B's surface
static func contactOn(A: Dictionary, B: Dictionary, ct: Dictionary) -> Vector2:
	var tx: float = -ct.nz
	var tz: float = ct.nx
	var ext := func(D: Dictionary, ux: float, uz: float) -> float:
		var f := Vector2(sin(D.h), cos(D.h))
		var r := Vector2(f.y, -f.x)
		return absf(D.len / 2 * (f.x * ux + f.y * uz)) + absf(D.wid / 2 * (r.x * ux + r.y * uz))
	var at: float = A.x * tx + A.z * tz
	var bt: float = B.x * tx + B.z * tz
	var ea: float = ext.call(A, tx, tz)
	var eb: float = ext.call(B, tx, tz)
	var lo := maxf(at - ea, bt - eb)
	var hi := minf(at + ea, bt + eb)
	var mt := (lo + hi) / 2 if lo <= hi else (at + bt) / 2
	var bn: float = B.x * ct.nx + B.z * ct.nz + ext.call(B, ct.nx, ct.nz)
	return Vector2(ct.nx * bn + tx * mt, ct.nz * bn + tz * mt)

static func pairImpulse(A: Dictionary, B: Dictionary, ct: Dictionary) -> Variant:
	var vn: float = (A.vx - B.vx) * ct.nx + (A.vz - B.vz) * ct.nz
	if vn >= 0: return null
	var j: float = -(1 + (REST if vn < -1.5 else 0.0)) * vn / (1 / A.m + 1 / B.m)
	var tx: float = -ct.nz
	var tz: float = ct.nx
	var vt: float = (A.vx - B.vx) * tx + (A.vz - B.vz) * tz
	var ft := clamp_(vt, -j * 0.25, j * 0.25) * 0.5
	var cc: Vector2 = Vector2(ct.cx, ct.cz) if ct.has("cx") else contactOn(A, B, ct)
	var tq := func(D: Dictionary, fx: float, fz: float) -> float:
		var rx: float = cc.x - D.x
		var rz: float = cc.y - D.z
		var fk := 1.0 if (rx * sin(D.h) + rz * cos(D.h)) < 0 else 0.4
		return (rz * fx - rx * fz) * fk
	var FAx: float = ct.nx * j - tx * ft
	var FAz: float = ct.nz * j - tz * ft
	return {"j": j, "FAx": FAx, "FAz": FAz, "sA": tq.call(A, FAx, FAz) * 12 / (A.m * A.len * A.len) * SPIN_K,
		"sB": tq.call(B, -FAx, -FAz) * 12 / (B.m * B.len * B.len) * SPIN_K}

func collide() -> void:
	var P0 := playerBody()
	for c in traffic + bots:
		if c.out: continue
		var B := bodyOf(c)
		var ct = pairContact(P0, B)
		if ct == null: continue
		var tot: float = P0.m + B.m
		var pc := minf(0.04, maxf(0, ct.pen - 0.03) * POS_K)
		player.pos.x += ct.nx * pc * B.m / tot
		player.pos.z += ct.nz * pc * B.m / tot
		nudgeOther(c, -ct.nx * pc * P0.m / tot, -ct.nz * pc * P0.m / tot)
		var A := playerBody()
		var im = pairImpulse(A, B, ct)
		if im == null: continue
		var fx := sin(player.heading); var fz := cos(player.heading)
		var nvx: float = A.vx + im.FAx / A.m
		var nvz: float = A.vz + im.FAz / A.m
		player.speed = nvx * fx + nvz * fz
		player.slide = Vector2(nvx - fx * player.speed, nvz - fz * player.speed)
		player.spin = clamp_(player.spin + yawKick(im.sA, GRIP * gripFactor()), -6, 6)
		kickOther(c, -im.FAx / B.m, -im.FAz / B.m, yawKick(im.sB, gripFactor()))
		if netInRace() and not netIsHost() and bots.has(c):
			netKick(bots.find(c), -im.FAx / B.m, -im.FAz / B.m, yawKick(im.sB, gripFactor()))
		if im.j > 0.4:
			raceContacts += 1; c.hitByPlayer = clock
		hitFx(im.j, true)

func botCollisions() -> void:
	if netInRace() and not netIsHost(): return
	for a in bots.size():
		for k in range(a + 1, bots.size()):
			var X: Mover = bots[a]
			var Y: Mover = bots[k]
			if X.out or Y.out or absf(Trk.wrapD(Y.s - X.s)) > 9 or absf(Y.lat - X.lat) > 5: continue
			var A := bodyOf(X)
			var B := bodyOf(Y)
			var ct = pairContact(A, B)
			if ct == null: continue
			var tot: float = A.m + B.m
			var pc := minf(0.04, maxf(0, ct.pen - 0.03) * POS_K)
			nudgeOther(X, ct.nx * pc * B.m / tot, ct.nz * pc * B.m / tot)
			nudgeOther(Y, -ct.nx * pc * A.m / tot, -ct.nz * pc * A.m / tot)
			var im = pairImpulse(A, B, ct)
			if im == null: continue
			kickOther(X, im.FAx / A.m, im.FAz / A.m, yawKick(im.sA, gripFactor()))
			kickOther(Y, -im.FAx / B.m, -im.FAz / B.m, yawKick(im.sB, gripFactor()))
			if im.j > 2 and absf(Trk.wrapD(X.s - player.s)) < 45: hitFx(im.j, false)

## every other car on the road as [x, z] (bots, traffic, the other player, online players)
func otherCars() -> Array:
	var out := []
	for c in traffic + bots:
		if not c.out: out.append(Vector2(c.m.g.position.x, c.m.g.position.z))
	if split and p2 != null and p2.car != null: out.append(Vector2(p2.pl.pos.x, p2.pl.pos.z))
	if Net.net != null and Net.net.get("inRace", false):
		for r in Net.net.remotes.values():
			if r.car != null and r.car.g.visible: out.append(Vector2(r.car.g.position.x, r.car.g.position.z))
	return out

## where to put the car back on the road: the lane nearest to lat at sample i, or the next free spot behind it when
## another car is there (never on top of someone). Returns [sample, lat].
func safeSpot(i: int, lat: float) -> Array:
	var lanes: Array = Trk.LANES.duplicate()
	lanes.sort_custom(func(a, b): return absf(a - lat) < absf(b - lat))
	var cars := otherCars()
	var NS := Trk.NS
	for back in 12:
		var j := posmod(i - back * 4, NS)
		for l in lanes:
			var x: float = Trk.P[j].x + Trk.R[j].x * l
			var z: float = Trk.P[j].z + Trk.R[j].z * l
			var free := true
			for c in cars:
				var dx: float = c.x - x
				var dz: float = c.y - z
				# 7 m along the road, 2.6 m beside it
				var along := dx * Trk.T[j].x + dz * Trk.T[j].z
				var side := dx * Trk.R[j].x + dz * Trk.R[j].z
				if absf(along) < 7.0 and absf(side) < 2.6:
					free = false; break
			if free: return [j, l]
	return [i, lanes[0]]

func resetToTrack() -> void:
	if state != "racing" or clock - resetT < 2: return
	resetT = clock
	var spot := safeSpot(player.idx, player.lat)
	resetPlayer(spot[0], spot[1])
	snapCamera()
	Hud.showMsg("Terug op de baan", "ok", 1.2)

func edges(prevIdx: int, fx: float, fz: float, dt: float) -> bool:
	var i := player.idx
	var NS := Trk.NS
	if absf(player.lat) > Trk.EDGE[i]:
		var sgn := MathX.sgn(player.lat)
		if Trk.TRK.edge == "ditch":
			var spot := safeSpot(i, Trk.LANES[-1] if sgn > 0 else Trk.LANES[0])
			resetPlayer(spot[0], spot[1])
			shake = 0.35
			Hud.showMsg("In de sloot!", "bad", 1.5)
			Sfx.noise(0.7, 0.5, 1800)
			return true
		var over: float = absf(player.lat) - Trk.EDGE[i] + 0.05
		player.pos.x -= Trk.R[i].x * sgn * over
		player.pos.z -= Trk.R[i].z * sgn * over
		var th := Trk.heading_of(Trk.T[i])
		var dirTh := th if cos(player.heading - th) >= 0 else th + PI
		var into := absf(sin(player.heading - dirTh))
		# the wall takes the speed that goes into it (a small bounce: the car never sticks) and rubs along the side:
		# a glancing hit costs a little, a square one nearly everything
		var hx := sin(player.heading); var hz := cos(player.heading)
		var vx := hx * player.speed + player.slide.x
		var vz := hz * player.speed + player.slide.y
		var nx: float = Trk.R[i].x * sgn
		var nz: float = Trk.R[i].z * sgn
		var tx: float = Trk.T[i].x
		var tz: float = Trk.T[i].z
		var vn := vx * nx + vz * nz
		var vt := vx * tx + vz * tz
		var hit := vn > 0.3
		var v0 := sqrt(vx * vx + vz * vz)
		if vn > 0:
			vt -= MathX.sgn(vt) * minf(absf(vt), vn * WALL_RUB)
			vn = -vn * WALL_BOUNCE
		# scraping along the wall keeps costing a little
		vt -= MathX.sgn(vt) * minf(absf(vt), WALL_SCRAPE * dt)
		vx = tx * vt + nx * vn
		vz = tz * vt + nz * vn
		# the nose is turned along the wall: at once by the hit, then gently while the car leans on it
		var h0 := player.heading
		player.heading = MathX.lerp_angle_(player.heading, dirTh, minf(0.95, 0.55 + 0.45 * into) if hit else minf(1, dt * 12))
		# the body on screen swings round in a blink instead of jumping (syncCar lets wallYaw fade)
		player.wallYaw = clamp_(player.wallYaw + fposmod(h0 - player.heading + PI, TAU) - PI, -1.4, 1.4)
		if hit: player.yr *= 0.3
		hx = sin(player.heading); hz = cos(player.heading)
		player.speed = vx * hx + vz * hz
		player.slide = Vector2(vx - hx * player.speed, vz - hz * player.speed)
		if v0 > 4 and clock - wallT > 0.35:
			wallT = clock
			if fxOn(): shake = minf(0.22, 0.05 + into * 0.25)
			Sfx.noise(0.22, 0.4, 650)
			if into > 0.3: Sfx.tone(70, 0.18, "square", 0.12)
		locatePlayer()
	var d := (player.idx - prevIdx + NS) % NS
	if d > 0 and d < NS / 2:
		var tI: int = Trk.cps[nextCp]
		var dd := (tI - prevIdx + NS) % NS
		if dd > 0 and dd <= d:
			hitCheckpoint(nextCp)
			nextCp = (nextCp + 1) % Trk.cps.size()
	var k := player.idx
	var along := fx * Trk.T[k].x + fz * Trk.T[k].z
	if state != "racing": return false
	if player.speed > 0: distance += player.speed * dt * maxf(0, along)
	if along < -0.4 and player.speed > 5:
		wrongT += dt
		if wrongT > 0.8: Hud.showMsg("Verkeerde kant op", "bad", 0.3)
	else:
		wrongT = 0
	return false

func updatePlayer(dt: float) -> void:
	drive(dt, input())
	collide()
	var prev := player.idx
	locatePlayer()
	edges(prev, sin(player.heading), cos(player.heading), dt)

func autopilot(dt: float, tv: float) -> void:
	var th := Trk.heading_of(Trk.T[player.idx])
	var want := th + clamp_(player.lat * 0.07, -0.35, 0.35)
	var diff := fposmod(want - player.heading + PI, TAU) - PI
	drive(dt, {"steer": clamp_(-diff * 3, -1, 1), "analog": true, "gas": 0.5 if player.speed < tv - 2 else 0.0, "brake": 0.4 if player.speed > tv + 3 else 0.0, "hand": false})
	collide()
	var prev := player.idx
	locatePlayer()
	edges(prev, sin(player.heading), cos(player.heading), dt)

func updateWind(dt: float) -> void:
	if Trk.TRK.is_empty() or not Trk.TRK.get("wind", false) or state != "racing":
		windX = 0; gustPhase = 0; return
	gustT -= dt
	if gustT < 1.1 and not gustWarn and gustPhase <= 0:
		gustWarn = true; gustDir = -1.0 if randf() < .5 else 1.0
	if gustT <= 0 and gustPhase <= 0:
		gustPhase = GUST_LEN; gustWarn = false
	if gustPhase > 0:
		gustPhase -= dt
		var f := sin((1 - gustPhase / GUST_LEN) * PI) * 8 * gustDir
		var i := player.idx
		var ex := clamp_(0.35 + player.y / 5, 0.35, 1.1) * clamp_(absf(player.speed) / 22, 0.2, 1)
		player.slide.x += Trk.R[i].x * f * ex * dt
		player.slide.y += Trk.R[i].z * f * ex * dt
		for b in bots:
			if not b.out: b.lp += f * 0.45 * dt
		for c in traffic: c.lp += f * 0.25 * dt
		windX = f * 3 * Trk.R[i].x
		if gustPhase <= 0: gustT = 7 + randf() * 8
	else:
		windX = 0
	if Env.me != null: Env.me.wind_x = windX

# ================================================================== camera & car pose
## The body of a car rig leans while its wheels stay on the road: every wheel moves the other way inside the rig, as far
## as its spring travels. The caller turns the rig itself: rotation.x = pitch (nose down is positive), rotation.z = -roll
## (roll: leaning to the car's left is positive, as in a right-hand bend), position.y + heave. Works on any rig from
## CarKit.buildCar (player, bots, remote cars); tiltRig(m, 0, 0, 0) puts the wheels back.
static func tiltRig(m: Dictionary, pitch: float, roll: float, heave: float) -> void:
	for w in m.wheels:
		var pv: Node3D = w.pivot
		if not w.has("y0"): w["y0"] = pv.position.y
		var dy: float = heave - pitch * pv.position.z - roll * pv.position.x
		pv.position.y = w.y0 - clamp_(dy, -0.09, 0.09)

## a spring that follows a target with a little overshoot (the body settling after a bump or a corner)
static func springStep(x: float, vel: float, target: float, k: float, c: float, dt: float) -> Vector2:
	var n := maxi(1, int(ceil(dt / 0.012)))
	var h := dt / n
	for _i in n:
		vel += (k * (target - x) - c * vel) * h
		x += vel * h
	return Vector2(x, vel)

func syncCar(dt: float) -> void:
	if car == null or Trk.NS <= 1: return
	var pl := player
	var H := handling(G.settings.car)
	var live := state == "racing" or state == "finished" or state == "over"
	# the tyres' slip already turns the car into the corner; the look gets a little more of it
	drift += (clamp_(-pl.beta * 0.2, -0.08, 0.08) * (1.0 if live else 0.0) - drift) * minf(1, dt * 6)
	var i := pl.idx % Trk.NS      # (a track with fewer samples may just have been loaded)
	var slope := 0.0
	if absf(pl.lat) < Trk.SHOULDER:
		slope = (Trk.HT[(i + 1) % Trk.NS] - Trk.HT[i]) / Trk.SPC * (sin(pl.heading) * Trk.T[i].x + cos(pl.heading) * Trk.T[i].z)
	# ---- the body on its springs: leans out of the corner, dives under braking, squats on the gas, rides the bumps
	var soft: float = H.roll
	var tr := clamp_(pl.ay * 0.0011 * soft, -0.075, 0.075) if live else 0.0
	var tp := clamp_(-pl.ax * 0.0014 * (0.6 + 0.4 * soft), -0.03, 0.045) if live else 0.0
	var th := clamp_((pl.load - 1) * -0.09, -0.035, 0.04) if live else 0.0
	var r2 := springStep(pl.roll, pl.rollV, tr, 150, 15, dt); pl.roll = r2.x; pl.rollV = r2.y
	var p2s := springStep(pl.pitch, pl.pitchV, tp, 130, 14, dt); pl.pitch = p2s.x; pl.pitchV = p2s.y
	var h2 := springStep(pl.heave, pl.heaveV, th, 110, 12, dt); pl.heave = h2.x; pl.heaveV = h2.y
	# rough ground (grass, gravel, kerbs, bricks): a fine shake; the clock stands still in a pause, so does the car
	var rb := pl.rumble if live else 0.0
	var shakeY := (sin(clock * 67.0) + sin(clock * 41.3) * 0.6) * 0.007 * rb
	var shakeR := sin(clock * 53.7) * 0.006 * rb
	var shakeP := sin(clock * 47.1) * 0.004 * rb
	var roll := pl.roll + shakeR
	var pitch := pl.pitch + shakeP
	var heave := pl.heave + shakeY
	car.g.position = Vector3(pl.pos.x, pl.y + heave, pl.pos.z)
	car.g.rotation_order = EULER_ORDER_YXZ
	pl.wallYaw *= exp(-dt * 16)
	if absf(pl.wallYaw) < 1e-4: pl.wallYaw = 0.0
	car.g.rotation = Vector3(-atan(slope) + pitch, pl.heading - drift + pl.wallYaw, -roll)
	tiltRig(car, pitch, roll, heave)
	# ---- wheels: the fronts point where the steering puts them, the rears stand still on the handbrake, driven
	# wheels spin up on a hard launch
	var launch: bool = pl.gear == 1 and pl.gasIn > 0.9 and absf(pl.speed) < 9 and Cars.CARS[G.settings.car].cls != "B" and (state == "racing" or state == "finished")
	var sv := clamp_(pl.delta * 1.3 + pl.steer * 0.14, -0.5, 0.5) if live else pl.steer * 0.4
	for k in 4:
		var w: Dictionary = car.wheels[k]
		var front := k < 2
		var driven: bool = (H.drv == "a") or (H.drv == "f") == front
		var wv := pl.speed
		if launch and driven: wv = maxf(wv, 14.0)
		if pl.hand and not front: wv = 0.0
		w.spin.rotation.x += wheelSpin(wv, w.r, dt)
		if front: w.pivot.rotation.y = -sv
	# brake lights and reversing lamps (CarKit swaps the tail lamps' material)
	var br := (state == "racing" or state == "finished") and (pl.brk > 0.3 or pl.hand) and absf(pl.speed) > 0.5
	CarKit.setLights(car, br, state == "racing" and pl.speed < -0.5)

func cycleCam() -> void:
	if not (state == "racing" or state == "countdown" or state == "finished"): return
	G.prefs.cam = (int(G.prefs.cam) + 1) % 3
	G.savePrefs()
	Hud.showToast("Camera: " + CAM_NAMES[G.prefs.cam])

func camParams() -> Dictionary:
	var sp := clamp_(maxf(0, player.speed) / 69.4, 0, 1.3)
	if int(G.prefs.cam) == 1:
		return {"dist": 10.5 - sp * 1.6, "h": 3.8 - sp * 0.3, "fov": 56 + sp * 12}
	return {"dist": 7.0 - sp * 1.35, "h": 2.55 - sp * 0.3, "fov": 58 + sp * 13}

func snapCamera() -> void:
	camLift = 0
	player.camSide = 0
	camHeading = player.heading
	camY = player.y
	var c := camParams()
	placeCam(c)
	camera.position = camPos
	camera.look_at(camLook, Vector3.UP)
	camera.fov = c.fov

func placeCam(c: Dictionary) -> void:
	var fx := sin(camHeading); var fz := cos(camHeading)
	var dist: float = c.dist + player.camD
	camPos = Vector3(player.pos.x - fx * dist, camY + c.h, player.pos.z - fz * dist)
	# (camSide: a little into the corner, to the right of the nose when turning right)
	camLook = Vector3(player.pos.x + fx * 8 - fz * player.camSide, camY + 1.05, player.pos.z + fz * 8 + fx * player.camSide)

func lookHeld() -> bool:
	return actHeld(activeP, "look") or padFor(activeP).look

func updateCamera(dt: float) -> void:
	# before the menu views, as in the JS: in the menus there is no speed blur (also after quitting a race at speed)
	speedFx = clamp_((maxf(0, player.speed) - 20) / 50, 0, 1) if (state == "racing" or state == "finished") else 0.0
	if Net.specCam(dt): return       # online: watching another player's car
	if Menu.menuCamera(dt): return   # menus: podium, home fly-over, orbit round the car, garage (Menu.menuCamera)
	var c := camParams()
	# reversing (holding the brake below walking pace) turns the camera round; rolling back off a wall does not
	if player.speed < -1 and player.brk > 0.3: player.camBack = true
	elif player.speed > -0.5 or player.gasIn > 0.3: player.camBack = false
	var back := PI if player.camBack else 0.0
	# in a slide the camera looks between the nose and where the car is going, so you see the car turned in its slide
	var live := state == "racing" or state == "finished"
	var slipLook := clamp_(player.beta, -0.9, 0.9) * 0.55 if live and player.speed > 3 else 0.0
	camHeading = MathX.lerp_angle_(camHeading, player.heading - slipLook + back, 1 - exp(-dt * 7))
	camY += (player.y - camY) * (1 - exp(-dt * 8))
	# the car pulls away from the camera when it accelerates, the camera closes in under braking
	player.camD += ((clamp_(player.ax * 0.03, -0.45, 0.3) if live else 0.0) - player.camD) * (1 - exp(-dt * 3))
	# and looks a little into the corner the car is turning into
	player.camSide += ((clamp_(player.yr * 0.9, -1.2, 1.2) if live and player.speed > 3 else 0.0) - player.camSide) * (1 - exp(-dt * 3))
	placeCam(c)
	var look := lookHeld() and state != "countdown"
	var hood := int(G.prefs.cam) == 2 and not look
	car.g.visible = not hood
	var fx := sin(player.heading); var fz := cos(player.heading)
	if look:
		camPos = Vector3(player.pos.x + fx * 5.5, player.y + 2.3, player.pos.z + fz * 5.5)
		camLook = Vector3(player.pos.x - fx * 25, player.y + 0.8, player.pos.z - fz * 25)
	elif hood:
		camPos = Vector3(player.pos.x + fx * 0.9, player.y + 1.12, player.pos.z + fz * 0.9)
		camLook = Vector3(player.pos.x + fx * 30, player.y + 0.9, player.pos.z + fz * 30)
	# keep the chase camera out of the hills on the rolling tracks: lift it over the ground and ease back down afterwards
	if not hood and Trk.terrain_fn.is_valid():
		var need := maxf(0, Dress.groundY(camPos.x, camPos.z) + 1.7 - camPos.y)
		camLift = need if need > camLift else camLift + (need - camLift) * (1 - exp(-dt * 2.5))
		camPos.y += camLift
	else:
		camLift = 0
	var p := camPos
	if fxOn():
		var v := speedFx * 0.022
		p.y += sin(clock * 53) * v + sin(clock * 31) * v * 0.6
		p.x += sin(clock * 41) * v * 0.5
		# rough ground shakes the picture a little
		if player.rumble > 0.05 and (state == "racing" or state == "finished"): p.y += sin(clock * 61) * player.rumble * 0.012
		if shake > 0:
			p.x += (randf() - .5) * shake * 1.0
			p.y += (randf() - .5) * shake * 0.6
	camera.position = p
	camera.look_at(camLook, Vector3.UP)
	if absf(camera.fov - c.fov) > 0.02:
		camera.fov += (c.fov - camera.fov) * minf(1, dt * 4)

# ================================================================== game flow
func resetPlayer(i: int, lat: float) -> void:
	player.idx = i
	player.pos = Vector3(Trk.P[i].x + Trk.R[i].x * lat, 0, Trk.P[i].z + Trk.R[i].z * lat)
	player.heading = Trk.heading_of(Trk.T[i])
	player.settle()
	drift = 0
	locatePlayer()

func startRace() -> void:
	if not (state == "menu" or (state == "over" and overReady)): return
	Sfx.initAudio()
	Menu.beforeRace()                                    # menus: garage room and podium off, menu screens hidden
	if not Champ.active(): Career.ensureOwnedCars()     # you only race cars you own
	Rep.replayClear()
	var S := G.settings
	mode = "champ" if Champ.active() else S.mode
	split = mode == "split"
	if split: mode = "race"
	if not split and p2 != null: splitTeardown()
	if mode == "race" and int(S.bots) < 1 and not split: mode = "time"
	if mode == "elim" and int(S.bots) < 2: S.bots = 2
	raceMode = mode == "race" or mode == "elim" or mode == "champ"
	raceLaps = int(Champ.CR()[int(Champ.champ.round)].laps) if mode == "champ" else (int(S.bots) if mode == "elim" else int(S.laps))
	lapRecordSet = false; ghostSaved = false; sectorsReset(); World.setGateMode(mode == "time")
	distance = 0; checkpoints = 0; shake = 0; raceBestLap = 0; raceTopSpeed = 0; raceTime = 0; raceDone = false; raceFinishTime = 0; finishAt = 0
	elimDone = 0; playerOut = false; raceContacts = 0; racePits = 0
	gustT = 9; gustPhase = 0; gustWarn = false; elimPos = 0; lapTimes = []; player.lap = 0; overView = "results"
	if raceMode:
		clearTraffic()
		# a championship races its fixed field, an online race the host's, a career event its own (with the rival)
		setupBots(0, Champ.champ.bots if mode == "champ" else (Net.net.botDefs if netInRace() and Net.net.botDefs != null else
			(G.careerEv.defs if G.careerEv != null else makeBotDefs(mini(int(S.bots), 5) if split else int(S.bots)))))
		placeGrid(); nextCp = 0
		if split: splitSetup()
		if netInRace(): Net.netPlace()
	elif mode == "ghost":
		clearTraffic(); clearBots(); placeGrid(); nextCp = 0; Rep.ghostStart()
	else:
		clearBots(); buildTraffic(); resetPlayer(0, 0); nextCp = 1; timeLeft = Trk.TRK.startTime
	if mode != "ghost": Rep.ghostHide()
	snapCamera()
	if Fx.me != null:
		Fx.me.clearSkids(); Fx.me.clearParts()
	state = "countdown"; cd = 0; lastCount = -1; goDelay = 0.4 + randf() * 0.8
	Hud.raceStart(raceMode, mode)
	clearKeys()

func finishPlayer(_win := false) -> void:
	if split:
		splitFinish(); return
	raceDone = true; raceFinishTime = raceTime; state = "finished"; finishAt = clock + 3
	var pos := playerPosition()
	Hud.showMsg("Finish!" if mode == "ghost" else ("Finish! Gewonnen" if pos == 1 else "Finish! %de plaats" % pos), "ok", 3)
	Sfx.tone(880, 0.2, "triangle", 0.18); Sfx.tone(1320, 0.2, "triangle", 0.18, 0.18); Sfx.tone(1760, 0.5, "triangle", 0.18, 0.36)

func elimCheck() -> void:
	if mode != "elim" or playerOut or raceDone: return
	var act := activeBots()
	var lead := player.lap
	for b in act: lead = maxi(lead, b.lap)
	lead -= 1
	if lead <= elimDone or lead < 1: return
	elimDone = lead
	var list := [{"me": true, "prog": progressOf(player.lap, player.s, false, 0)}]
	for b in act: list.append({"b": b, "prog": progressOf(b.lap, b.s, false, 0)})
	list.sort_custom(func(a, b): return a.prog < b.prog)
	var lastOne: Dictionary = list[0]
	if lastOne.get("me", false):
		playerOut = true; elimPos = list.size(); raceDone = true; raceFinishTime = raceTime; state = "finished"; finishAt = clock + 3
		Hud.showMsg("Uitgeschakeld! %de plaats" % elimPos, "bad", 3)
		Sfx.tone(330, 0.3, "square", 0.12); Sfx.tone(220, 0.5, "square", 0.12, 0.3)
	else:
		var b: Mover = lastOne.b
		b.out = true; b.outAt = raceTime; b.elimPos = list.size()
		Hud.showMsg(b.name + " ligt eruit", "ok", 2)
		Sfx.tone(660, 0.15, "triangle", 0.12)
		if act.size() == 1: finishPlayer(true)

func endTimeTrial() -> void:
	state = "over"; timeLeft = 0
	var rec := false
	var best := float(G.store_get(bestKey(Trk.TRACK_ID), 0))
	if distance > best and distance > 0:
		G.store_set(bestKey(Trk.TRACK_ID), int(round(distance))); rec = true
	if distance >= 5000: unlockAch("tt5")
	var cr := awardCredits(0)
	Hud.showTimeTrialOver(distance, checkpoints, raceBestLap, maxf(best, distance), rec, cr)
	Sfx.tone(660, 0.18, "square", 0.1); Sfx.tone(520, 0.18, "square", 0.1, 0.18); Sfx.tone(392, 0.4, "square", 0.1, 0.36)
	overReady = false
	get_tree().create_timer(0.7).timeout.connect(func(): overReady = true)

func resultOrder() -> Array:
	var rows := [{"name": "Speler 1" if split else "Jij", "car": Cars.CARS[G.settings.car].name, "me": true, "finished": raceDone and not playerOut, "ft": raceFinishTime,
		"out": playerOut, "elimPos": elimPos, "prog": -1e9 if playerOut else progressOf(player.lap, player.s, raceDone, raceFinishTime), "best": raceBestLap}]
	rows += Net.resultRows()
	if split and p2 != null:
		rows.append({"name": "Speler 2", "car": Cars.CARS[p2.carId].name, "me": true, "finished": p2.raceDone, "ft": p2.raceFinishTime, "out": false,
			"elimPos": 0, "prog": otherProgress(), "best": p2.raceBestLap})
	for b in bots:
		rows.append({"name": b.name, "car": Cars.CARS[b.type].name, "finished": b.finished, "ft": b.finishTime, "out": b.out, "elimPos": b.elimPos,
			"prog": -1e9 if b.out else progressOf(b.lap, b.s, b.finished, b.finishTime), "best": b.bestLap})
	rows.sort_custom(func(a, b): return (a.elimPos < b.elimPos) if (a.out and b.out) else (a.prog > b.prog))
	return rows

func showResults() -> void:
	state = "over"
	Menu.showResults()      # menus: results board, credits, championship points, career result, achievements, podium
	overReady = false
	get_tree().create_timer(0.7).timeout.connect(func(): overReady = true)

func onAgain() -> void:
	if not (state == "over" and overReady): return
	if Net.net != null:
		# online: the host starts the next race for everyone; the others wait for it
		if Net.isHost(): Net.netHostStart()
		return
	if Menu.onAgain(): return    # menus: championship standings / next round, on to the next career event
	startRace()

func toMenu(step := -1) -> void:
	if Rep.rp != null: Rep.replayClose()
	Rep.replayClear()
	Rep.ghostHide()
	if split or p2 != null: splitTeardown()
	Net.netAfterRace()
	paused = false
	Hud.toMenu()
	if Fx.me != null:
		Fx.me.clearSkids(); Fx.me.clearParts()
	state = "menu"
	Menu.toMenu(step)       # menus: championship and career clean-up, then the menu (step -1 = home screen)
	if Net.net != null and step < 0: Menu.netOpen()    # back in the online game's screen

## after a career race or cup: back to the career screen; otherwise to the menu
func toCareerOr(step := -1) -> void:
	Menu.toCareerOr(step)

## the pause screen stops the world, except online: there the race goes on for everyone (the host drives the bots)
func frozen() -> bool:
	return paused and not netInRace()

func setPaused(p: bool) -> void:
	if p and not (state == "racing" or state == "countdown" or state == "finished"): return
	if p == paused: return
	paused = p
	Hud.setPaused(p)
	clearKeys()

## JS applyPrefs: picture quality and sound on/off. The settings menu calls this after changing a preference.
##   laag:   no shadows (a soft blob under each car), 75% 3D resolution, no anti-aliasing, a simpler sky, no smoke,
##           no screen effects; the mirror looks 600 m back
##   middel: shadows (2048, soft edge, 150 m), MSAA 2x, smoke/dust/spray, no full-screen passes (vignette, speed blur)
##   hoog:   shadows (4096, softer, 220 m, blended splits), MSAA 4x, everything incl. vignette/colour cast and speed blur
## Split screen and the mirror: MSAA 2x at most (they are small), none on laag. See Env.set_quality, Fx.set_quality.
func applyPrefs() -> void:
	var q: String = G.prefs.get("quality", "high")
	if q != "low" and q != "mid": q = "high"
	if Env.me != null: Env.me.set_quality(q)
	if Fx.me != null: Fx.me.set_quality(q)
	var vp := get_viewport()
	vp.scaling_3d_scale = 0.75 if q == "low" else 1.0
	vp.msaa_3d = Viewport.MSAA_DISABLED if q == "low" else (Viewport.MSAA_2X if q == "mid" else Viewport.MSAA_4X)
	if SplitView.me != null:
		for v in [SplitView.me.vp1, SplitView.me.vp2]:
			v.msaa_3d = Viewport.MSAA_DISABLED if q == "low" else Viewport.MSAA_2X
			v.scaling_3d_scale = 0.75 if q == "low" else 1.0
	Sfx.muted = not bool(G.prefs.get("sound", true))

func bestKey(id: String, cls := "") -> String:
	return "polderrace3d-best-" + tv(id) + "-" + (cls if cls != "" else Cars.CARS[G.settings.car].cls)

func lapKey(id: String, cls := "") -> String:
	return "polderrace3d-lap-" + tv(id) + "-" + (cls if cls != "" else Cars.CARS[G.settings.car].cls)

func lapCarKey(id: String, c := "") -> String:
	return "polderrace3d-lapcar-" + tv(id) + "-" + (c if c != "" else G.settings.car)

func tv(id: String, dir := "") -> String:
	var t: Dictionary = TrackDefs.TRACKS.get(id, {})
	var d: String = dir if dir != "" else (Trk.TRACK_DIR if id == Trk.TRACK_ID else G.settings.dir)
	return (id + "@" + str(t.ver) if t.get("ver") else id) + ("-rev" if d == "rev" else "")

func recordLap(lt: float) -> void:
	if not raceBestLap or lt < raceBestLap: raceBestLap = lt
	var pb := float(G.store_get(lapKey(Trk.TRACK_ID), 0))
	if not pb or lt < pb:
		G.store_set(lapKey(Trk.TRACK_ID), G.toFixed(lt, 2))
		G.store_set(lapKey(Trk.TRACK_ID) + "-car", G.settings.car)
		lapRecordSet = true
	var pc := float(G.store_get(lapCarKey(Trk.TRACK_ID), 0))
	if not pc or lt < pc: G.store_set(lapCarKey(Trk.TRACK_ID), G.toFixed(lt, 2))

func sectorsReset() -> void:
	secBest = [0.0, 0.0, 0.0]; secLast = [0.0, 0.0, 0.0]; secStart = 0; secPrev = 0

func sectorLapStart() -> void:
	if secPrev == 2 and player.lap > 1:
		var t := raceTime - secStart
		secLast[2] = t
		if not secBest[2] or t < secBest[2]: secBest[2] = t
	secStart = raceTime; secPrev = 0

func sectorUpdate() -> void:
	if split or not (raceMode or mode == "ghost") or player.lap < 1 or raceDone or state != "racing": return
	var rel := fposmod(player.s - Trk.S_START, Trk.TRACK_LEN)
	var sec := mini(2, int(floor(rel / (Trk.TRACK_LEN / 3))))
	if sec == secPrev or (secPrev == 0 and sec == 2): return
	if sec == secPrev + 1:
		var k := secPrev
		var t := raceTime - secStart
		secStart = raceTime; secLast[k] = t
		if not secBest[k] or t < secBest[k]: secBest[k] = t
	secPrev = sec

func hitCheckpoint(k: int) -> void:
	if state != "racing": return   # the autopilot after "Tijd is op" must not collect checkpoints or laps
	if mode == "time":
		checkpoints += 1
		var bonus := maxi(9, int(round(15 - checkpoints * 0.4)))
		timeLeft += bonus
		if k == 0:
			var lt := clock - lapStart
			lapStart = clock; player.lap += 1; recordLap(lt)
			Hud.showMsg("Ronde " + G.fmtLap(lt) + "  +%d s" % bonus, "ok", 2.2)
		else:
			Hud.showMsg("Checkpoint  +%d s" % bonus, "ok", 1.6)
		Sfx.tone(880, 0.14, "triangle", 0.16); Sfx.tone(1320, 0.26, "triangle", 0.16, 0.12)
		return
	if k != 0 or raceDone: return
	player.lap += 1
	if player.lap == 1:
		lapStart = raceTime
		if not split: sectorLapStart()
		if mode == "ghost": Rep.ghostLapStart()
		return
	var lt := raceTime - lapStart
	lapStart = raceTime; recordLap(lt); lapTimes.append(lt)
	if not split: sectorLapStart()
	if mode == "ghost" and Rep.ghostLapDone(lt): ghostSaved = true
	if mode != "elim" and player.lap > raceLaps:
		finishPlayer(); return
	var lbl := ("Ronde %d" % player.lap) if mode == "elim" else ("Laatste ronde" if player.lap == raceLaps else "Ronde %d/%d" % [player.lap, raceLaps])
	Hud.showMsg(lbl + "  " + G.fmtLap(lt), "ok", 2)
	Sfx.tone(880, 0.14, "triangle", 0.16); Sfx.tone(1320, 0.26, "triangle", 0.16, 0.12)

func awardCredits(pos: int) -> int:
	# a championship pays at its own difficulty (JS: champ.diff)
	var p: float = G.DIFF[Champ.champ.diff if mode == "champ" and Champ.champ != null else G.settings.diff].pay
	if mode == "time": return G.addCredits(distance / 1000 * 60)
	if mode == "ghost": return G.addCredits(lapTimes.size() * 40 + (150 if ghostSaved else 0))
	var bases := [400, 300, 220, 160, 120, 90, 70, 50]
	var base: int = bases[(pos if pos > 0 else 8) - 1] if (pos if pos > 0 else 8) <= 8 else 40
	return G.addCredits(base * p * (1.0 if mode == "elim" else clamp_(0.6 + raceLaps * 0.2, 0.8, 1.6)))

# ------------------------------------------------------------------ hooks (filled in by later ports)
func netInRace() -> bool: return Net.inRace()
func netIsHost() -> bool: return Net.isHost()
func netAheadCount(me: float) -> int: return Net.aheadCount(me)
func netKick(i: int, dvx: float, dvz: float, sp: float) -> void: Net.netKick(i, dvx, dvz, sp)
## the car step of an online game is done (Menu calls this): back to the online screen
func netCarDone() -> void: Net.netCarDone()
func otherProgress() -> Variant:
	if not split or p2 == null: return null
	var o: PlayerState = p2.pl
	return progressOf(o.lap, o.s, p2.raceDone, p2.raceFinishTime)

## the other human player in split screen (for the minimap): {pl, color} or null
func otherPlayer() -> Variant:
	if not split or p2 == null: return null
	return {"pl": p2.pl, "color": p2.color}

# ================================================================== split screen (JS split section)
func newP2() -> Dictionary:
	return {"pl": PlayerState.new(), "car": null, "carId": G.settings.get("p2car", "hatch"), "color": G.settings.get("p2color", "#1d4f9e"),
		"MAXV": 0.0, "ACC": 0.0, "BRAKE": 0.0, "GRIP": 0.0, "nextCp": 0, "wrongT": 0.0, "wallT": 0.0, "lapStart": 0.0, "raceBestLap": 0.0,
		"raceDone": false, "raceFinishTime": 0.0, "lapTimes": [], "drift": 0.0, "camHeading": 0.0, "camY": 0.0, "camLift": 0.0, "resetT": -9.0,
		"hitT": -9.0, "cam": 0, "activeP": 2}

## every per-player global changes place with the other player's copy (also camLift: see CLAUDE.md)
func swapCtx(c: Dictionary) -> void:
	var t
	t = car; car = c.car; c.car = t
	t = MAXV; MAXV = c.MAXV; c.MAXV = t
	t = ACC; ACC = c.ACC; c.ACC = t
	t = BRAKE; BRAKE = c.BRAKE; c.BRAKE = t
	t = GRIP; GRIP = c.GRIP; c.GRIP = t
	t = nextCp; nextCp = c.nextCp; c.nextCp = t
	t = wrongT; wrongT = c.wrongT; c.wrongT = t
	t = wallT; wallT = c.wallT; c.wallT = t
	t = lapStart; lapStart = c.lapStart; c.lapStart = t
	t = raceBestLap; raceBestLap = c.raceBestLap; c.raceBestLap = t
	t = raceDone; raceDone = c.raceDone; c.raceDone = t
	t = raceFinishTime; raceFinishTime = c.raceFinishTime; c.raceFinishTime = t
	t = lapTimes; lapTimes = c.lapTimes; c.lapTimes = t
	t = drift; drift = c.drift; c.drift = t
	t = camHeading; camHeading = c.camHeading; c.camHeading = t
	t = camY; camY = c.camY; c.camY = t
	t = camLift; camLift = c.camLift; c.camLift = t
	t = resetT; resetT = c.resetT; c.resetT = t
	t = hitT; hitT = c.hitT; c.hitT = t
	t = G.settings.car; G.settings.car = c.carId; c.carId = t
	t = G.settings.color; G.settings.color = c.color; c.color = t
	t = G.prefs.cam; G.prefs.cam = c.cam; c.cam = t
	t = activeP; activeP = c.activeP; c.activeP = t
	t = player; player = c.pl; c.pl = t

func asP2(fn: Callable) -> Variant:
	if not split or p2 == null or inP2: return fn.call()
	swapCtx(p2)
	inP2 = true
	var r = fn.call()
	inP2 = false
	swapCtx(p2)
	return r

func runFor(pi: int, fn: Callable) -> Variant:
	return asP2(fn) if pi == 2 and split else fn.call()

func splitSetup() -> void:
	if p2 != null and p2.car != null: p2.car.g.queue_free()
	p2 = newP2()
	splitFirstDone = 0; splitEndAt = 0
	asP2(func():
		rebuildPlayerCar()
		var n := bots.size()
		var g := gridSlot(n + 1 if n + 1 > 0 else 1)
		resetPlayer(int(round(g.s / Trk.SPC)) % Trk.NS, g.lat)
		player.lap = 0; nextCp = 0; lapTimes = []; raceDone = false
		snapCamera())

func splitTeardown() -> void:
	if p2 != null and p2.car != null: p2.car.g.queue_free()
	p2 = null
	split = false

## collisions between the two human players, same solver as everything else
func collidePlayers() -> void:
	if not split or p2 == null or p2.car == null: return
	var A := playerBody()
	var o: PlayerState = p2.pl
	var f2x := sin(o.heading); var f2z := cos(o.heading)
	var po: float = p2.car.get("off", 0.0)
	var h2: float = o.heading - p2.drift
	var B := {"x": o.pos.x + sin(h2) * po, "z": o.pos.z + cos(h2) * po, "h": h2, "len": p2.car.len, "wid": p2.car.wid, "rc": p2.car.get("rc", 0.0),
		"m": Cars.CARS[p2.carId].mass, "vx": f2x * o.speed + o.slide.x, "vz": f2z * o.speed + o.slide.y}
	var ct = pairContact(A, B)
	if ct == null: return
	var tot: float = A.m + B.m
	var pc := maxf(0, ct.pen - 0.02) * POS_K
	player.pos.x += ct.nx * pc * B.m / tot; player.pos.z += ct.nz * pc * B.m / tot
	o.pos.x -= ct.nx * pc * A.m / tot; o.pos.z -= ct.nz * pc * A.m / tot
	var im = pairImpulse(playerBody(), B, ct)
	if im == null: return
	var apply := func(pl: PlayerState, body: Dictionary, dvx: float, dvz: float, sp: float, grip: float) -> void:
		var fx := sin(pl.heading); var fz := cos(pl.heading)
		var vx: float = body.vx + dvx
		var vz: float = body.vz + dvz
		pl.speed = vx * fx + vz * fz
		pl.slide = Vector2(vx - fx * pl.speed, vz - fz * pl.speed)
		pl.spin = clamp_(pl.spin + yawKick(sp, grip), -6, 6)
	apply.call(player, playerBody(), im.FAx / A.m, im.FAz / A.m, im.sA, GRIP * gripFactor())
	apply.call(o, B, -im.FAx / B.m, -im.FAz / B.m, im.sB, p2.GRIP * gripFactor())
	hitFx(im.j, true)

func splitUpdate(dt: float) -> void:
	var step := func():
		if raceDone: autopilot(dt, 22)
		else: updatePlayer(dt)
	step.call()
	asP2(step)
	collidePlayers()
	if not splitFirstDone and (raceDone or p2.raceDone): splitFirstDone = clock
	if not splitEndAt and raceDone and p2.raceDone: splitEndAt = clock + 2.5
	if not splitEndAt and splitFirstDone and clock > splitFirstDone + 30: splitEndAt = clock
	if splitEndAt and clock > splitEndAt:
		splitEndAt = 0
		showResults()

func splitFinish() -> void:
	raceDone = true; raceFinishTime = raceTime
	var pos := playerPosition()
	Hud.showMsg("Speler %d finisht als %de!" % [activeP, pos], "ok", 2.5)
	Sfx.tone(880, 0.2, "triangle", 0.18); Sfx.tone(1320, 0.3, "triangle", 0.18, 0.18)
func unlockAch(id: String) -> void: Ach.unlockAch(id)
func achPit() -> void:
	racePits += 1
	unlockAch("pit")
	if racePits >= 3: unlockAch("pit3")

# ================================================================== input (JS input section)
const ACTIONS := ["up", "down", "left", "right", "hand", "reset", "cam", "look", "shiftUp", "shiftDown"]
const DEFAULT_BINDS := {"p1": {"up": ["KeyW", "ArrowUp"], "down": ["KeyS", "ArrowDown"], "left": ["KeyA", "ArrowLeft"], "right": ["KeyD", "ArrowRight"],
		"hand": ["Space", "ShiftLeft"], "reset": ["KeyR"], "cam": ["KeyV"], "look": ["KeyC"], "shiftUp": ["KeyE"], "shiftDown": ["KeyQ"]},
	"p2": {"up": ["ArrowUp"], "down": ["ArrowDown"], "left": ["ArrowLeft"], "right": ["ArrowRight"], "hand": ["ShiftRight"], "reset": ["Numpad0"],
		"cam": ["Numpad1"], "look": ["Numpad2"], "shiftUp": ["PageUp"], "shiftDown": ["PageDown"]}}
var binds: Dictionary = DEFAULT_BINDS.duplicate(true)
var keysDown := {}
var pad := {"steer": 0.0, "gas": 0.0, "brake": 0.0, "hand": false, "look": false}
var padPrev := {}

func _load_binds() -> void:
	var b = G._json("polderrace3d-binds", null)
	if b is Dictionary:
		for p in ["p1", "p2"]:
			for a in ACTIONS:
				if b.get(p, {}).get(a) is Array: binds[p][a] = b[p][a]

func codesFor(p: String, a: String) -> Array:
	var c: Array = binds[p].get(a, [])
	if p == "p1" and split:
		var o := {}
		for x in ACTIONS:
			for k in binds.p2.get(x, []): o[k] = true
		return c.filter(func(k): return not o.has(k))
	return c

func actHeld(pi: int, a: String) -> bool:
	for k in codesFor("p2" if pi == 2 else "p1", a):
		if keysDown.has(k): return true
	return false

func actionOf(code: String) -> Variant:
	for pi in ([2, 1] if split else [1]):
		for a in ACTIONS:
			if codesFor("p2" if pi == 2 else "p1", a).has(code): return [pi, a]
	return null

var padStates: Array = []
var padPrevS: Array = []      ## the pads' states of the previous frame (edges per pad in split screen)

## with two gamepads in split screen: pad 1 is player 1, pad 2 player 2; with one pad it is player 2's
func padFor(pi: int) -> Dictionary:
	if not split: return pad
	if padStates.size() >= 2: return padStates[0] if pi == 1 else padStates[1]
	if pi == 2 and padStates.size() == 1: return padStates[0]
	return {"steer": 0.0, "gas": 0.0, "brake": 0.0, "hand": false, "look": false}

func input() -> Dictionary:
	# online the race goes on behind the pause screen (see frozen): the car rolls out, hands off
	if paused: return {"steer": 0.0, "analog": false, "gas": 0.0, "brake": 0.0, "hand": false}
	var pi := activeP
	var K := func(a: String) -> bool: return actHeld(pi, a) or (pi == 1 and Hud.touchHeld(a))
	var pd := padFor(pi)
	var kSteer := (1.0 if K.call("right") else 0.0) - (1.0 if K.call("left") else 0.0)
	return {"steer": pd.steer if pd.steer != 0 else kSteer, "analog": pd.steer != 0, "gas": maxf(1.0 if K.call("up") else 0.0, pd.gas),
		"brake": maxf(1.0 if K.call("down") else 0.0, pd.brake), "hand": K.call("hand") or pd.hand}

func clearKeys() -> void:
	keysDown.clear()

## JS KeyboardEvent.code of a Godot key event (so the key bindings stay compatible with the HTML version's)
static func codeOf(e: InputEventKey) -> String:
	var k := e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
	if k >= KEY_A and k <= KEY_Z: return "Key" + char(k)
	if k >= KEY_0 and k <= KEY_9: return "Digit" + char(k)
	if k >= KEY_KP_0 and k <= KEY_KP_9: return "Numpad" + str(k - KEY_KP_0)
	if k >= KEY_F1 and k <= KEY_F12: return "F" + str(k - KEY_F1 + 1)
	match k:
		KEY_UP: return "ArrowUp"
		KEY_DOWN: return "ArrowDown"
		KEY_LEFT: return "ArrowLeft"
		KEY_RIGHT: return "ArrowRight"
		KEY_SPACE: return "Space"
		KEY_SHIFT: return "ShiftRight" if e.location == KEY_LOCATION_RIGHT else "ShiftLeft"
		KEY_CTRL: return "ControlRight" if e.location == KEY_LOCATION_RIGHT else "ControlLeft"
		KEY_ALT: return "AltRight" if e.location == KEY_LOCATION_RIGHT else "AltLeft"
		KEY_ENTER: return "Enter"
		KEY_KP_ENTER: return "NumpadEnter"
		KEY_ESCAPE: return "Escape"
		KEY_BACKSPACE: return "Backspace"
		KEY_TAB: return "Tab"
		KEY_PAGEUP: return "PageUp"
		KEY_PAGEDOWN: return "PageDown"
		KEY_HOME: return "Home"
		KEY_END: return "End"
		KEY_INSERT: return "Insert"
		KEY_DELETE: return "Delete"
		KEY_COMMA: return "Comma"
		KEY_PERIOD: return "Period"
		KEY_SLASH: return "Slash"
		KEY_SEMICOLON: return "Semicolon"
		KEY_APOSTROPHE: return "Quote"
		KEY_BRACKETLEFT: return "BracketLeft"
		KEY_BRACKETRIGHT: return "BracketRight"
		KEY_BACKSLASH: return "Backslash"
		KEY_QUOTELEFT: return "Backquote"
		KEY_CAPSLOCK: return "CapsLock"
		KEY_MINUS: return "Minus"
		KEY_EQUAL: return "Equal"
		KEY_KP_ADD: return "NumpadAdd"
		KEY_KP_SUBTRACT: return "NumpadSubtract"
		KEY_KP_MULTIPLY: return "NumpadMultiply"
		KEY_KP_DIVIDE: return "NumpadDivide"
		KEY_KP_PERIOD: return "NumpadDecimal"
	return OS.get_keycode_string(k)

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey): return
	var code := codeOf(e)
	if not e.pressed:
		keysDown.erase(code)
		return
	# typing in a text field (name, IP address, start number): leave every key to the field (JS: INPUT target)
	var fo := get_viewport().gui_get_focus_owner()
	if (fo is LineEdit or fo is TextEdit) and fo.is_visible_in_tree(): return
	if code == "KeyM": Sfx.toggleMute()
	if state == "menu": return    # the menus handle their keys themselves (Menu._input)
	var ac = actionOf(code)
	if ac != null: keysDown[code] = true
	if (code == "Enter" or code == "Space"):
		if paused: setPaused(false)
		elif state == "over" and overReady: onAgain()
	if (code == "KeyP" or code == "Escape") and (state == "racing" or state == "countdown" or state == "finished"):
		setPaused(not paused)
	if state == "over" and overReady and code == "Escape": toCareerOr(-1)
	if ac != null and not e.echo and not paused:
		var a: String = ac[1]
		runFor(ac[0], func():
			if a == "reset": resetToTrack()
			if a == "cam": cycleCam()
			if G.prefs.gearbox == "manual" and (state == "racing" or state == "finished"):
				if a == "shiftUp": shiftUp()
				if a == "shiftDown": shiftDown())

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clearKeys()
		setPaused(true)

## stick to steering: nothing inside the dead zone, then from 0 (no jump at its edge) to full lock, finer round the centre
static func stickCurve(ax: float) -> float:
	var t := clamp_((absf(ax) - 0.12) / 0.84, 0, 1)
	return MathX.sgn(ax) * t * (0.5 + 0.5 * t)

## trigger to pedal: a small dead zone at the top, full just before the end of the travel
static func triggerCurve(a: float) -> float:
	return clamp_((a - 0.06) / 0.88, 0, 1)

## gamepad (JS readPad, standard mapping): Godot's joypad buttons/axes mapped onto the same roles
func readPad() -> void:
	pad = {"steer": 0.0, "gas": 0.0, "brake": 0.0, "hand": false, "look": false}
	var now := {}
	padStates = []
	for dev in Input.get_connected_joypads():
		var ax := Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
		pad.steer = stickCurve(ax)
		var btn := func(b: int) -> bool: return Input.is_joy_button_pressed(dev, b)
		if btn.call(JOY_BUTTON_DPAD_LEFT): pad.steer = -1.0
		if btn.call(JOY_BUTTON_DPAD_RIGHT): pad.steer = 1.0
		pad.gas = maxf(triggerCurve(Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT)), 1.0 if btn.call(JOY_BUTTON_A) else 0.0)
		pad.brake = maxf(triggerCurve(Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT)), 1.0 if btn.call(JOY_BUTTON_B) else 0.0)
		pad.hand = btn.call(JOY_BUTTON_X) or (G.prefs.gearbox != "manual" and btn.call(JOY_BUTTON_RIGHT_SHOULDER))
		pad.look = btn.call(JOY_BUTTON_RIGHT_STICK)
		var ay := Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y)
		now = {"a": btn.call(JOY_BUTTON_A), "b": btn.call(JOY_BUTTON_B), "start": btn.call(JOY_BUTTON_START), "y": btn.call(JOY_BUTTON_Y),
			"lb": btn.call(JOY_BUTTON_LEFT_SHOULDER), "rb": btn.call(JOY_BUTTON_RIGHT_SHOULDER), "sel": btn.call(JOY_BUTTON_BACK),
			"l": btn.call(JOY_BUTTON_DPAD_LEFT) or ax < -0.6, "r": btn.call(JOY_BUTTON_DPAD_RIGHT) or ax > 0.6,
			"up": btn.call(JOY_BUTTON_DPAD_UP) or ay < -0.6, "down": btn.call(JOY_BUTTON_DPAD_DOWN) or ay > 0.6}
		var ps: Dictionary = pad.duplicate()
		ps.merge({"y": now.y, "sel": now.sel, "lb": now.lb, "rb": now.rb})
		padStates.append(ps)
		# one player: the first pad; split screen: every pad (padFor hands them out)
		if not split: break
	var edge := func(k: String) -> bool: return now.get(k, false) and not padPrev.get(k, false)
	if Menu.padNav(now, padPrev):    # menus, pause and results screen (Menu.padNav)
		pass
	else:
		if edge.call("start"): setPaused(true)
		# reset, camera and gears for the player whose pad it is (split screen: pad 1 is player 1, pad 2 player 2; one pad: player 2)
		var handle := func(pi: int, e: Callable) -> void:
			runFor(pi, func():
				if e.call("y"): resetToTrack()
				if e.call("sel"): cycleCam()
				if G.prefs.gearbox == "manual":
					if e.call("rb"): shiftUp()
					if e.call("lb"): shiftDown())
		if not split:
			handle.call(1, edge)
		else:
			var n := padStates
			var prevS := padPrevS
			var pe := func(i: int, k: String) -> bool:
				return i < n.size() and n[i].get(k, false) and not (prevS[i] if i < prevS.size() else {}).get(k, false)
			if n.size() >= 2:
				handle.call(1, func(k: String) -> bool: return pe.call(0, k))
				handle.call(2, func(k: String) -> bool: return pe.call(1, k))
			elif n.size() == 1:
				handle.call(2, func(k: String) -> bool: return pe.call(0, k))
	padPrevS = padStates.map(func(p): return p.duplicate())
	padPrev = now

# ================================================================== main loop
func _ready() -> void:
	_load_binds()
	process_mode = Node.PROCESS_MODE_ALWAYS

func update(dt: float) -> void:
	clock += dt
	lampsOn = CarKit.lampsOn
	if shake > 0: shake = maxf(0, shake - dt)
	if Fx.me != null: Fx.me.updateFx(dt)
	if Env.me != null: Env.me.update(dt, camera)
	for s in World.sailGroups:
		s.rotation.z += dt * float(s.get_meta("speed", 0.8))
	if state == "menu":
		updateTraffic(dt, false); updateBots(dt); return
	updateTraffic(dt, true); updateBots(dt)
	if state == "countdown":
		player.speed = 0
		if split and p2 != null:
			p2.pl.speed = 0
			asP2(func(): player.gasIn = input().gas)
		player.gasIn = input().gas
		cd += dt
		var on := mini(5, int(floor(cd / 0.7)))
		if on != lastCount and cd < 3.5 + goDelay:
			lastCount = on
			Hud.setLights(on)
			if on > 0: Sfx.tone(440, 0.16, "square", 0.09)
		if cd >= 3.5 + goDelay:
			Rep.replayStart()
			state = "racing"
			lapStart = 0.0 if raceMode else clock
			Hud.lightsGo()
			Sfx.tone(880, 0.35, "square", 0.1)
		return
	if state == "over":
		autopilot(dt, 22.0 if raceMode else 0.0)
		if split and p2 != null: asP2(func(): autopilot(dt, 22))
		Menu.overTick()    # the results list keeps up while the bots finish
		return
	raceTime += dt
	Rep.replayRecord(dt)
	if state == "finished":
		autopilot(dt, 22)
		if clock > finishAt: showResults()
		return
	if split and p2 != null:
		splitUpdate(dt); updateWind(dt); return
	updatePlayer(dt)
	if netInRace(): Net.netCollide()
	updateWind(dt); Rep.ghostRecord(dt); sectorUpdate(); elimCheck()
	if mode == "time":
		var before := timeLeft
		timeLeft -= dt
		if timeLeft > 0 and timeLeft < 5.5 and ceil(before) != ceil(timeLeft): Sfx.tone(1250, 0.05, "square", 0.08)
		if timeLeft <= 0: endTimeTrial()

func _process(delta: float) -> void:
	if camera == null or Trk.NS <= 1: return
	var dt := minf(0.1, delta)
	readPad()
	if state == "replay":
		if not paused: Rep.replayUpdate(dt)
		clock += dt
		if Env.me != null: Env.me.update(dt, camera)
		Sfx.updateAudio()
		Hud.tick()
		return
	var still := frozen()
	if not still:
		var n := mini(12, maxi(1, int(ceil(dt / 0.0085))))
		for _k in n: update(dt / n)
	if car != null: syncCar(0.0 if still else dt)
	if split and p2 != null: asP2(func(): syncCar(0.0 if still else dt))
	Rep.ghostUpdate()
	updateCamera(0.0 if still else dt)
	if Fx.me != null: Fx.me.updateMirror()
	if fx_overlay != null: fx_overlay.tick(dt)
	if SplitView.me != null: SplitView.me.tick(dt)
	Sfx.updateAudio()
	Hud.tick()

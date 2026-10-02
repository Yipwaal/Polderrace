extends Node
## Autoload "Game": the race itself, ported from the HTML game's player, traffic, bots, physics, camera and game flow
## sections (same names, same numbers). The menus, garage, career, championship, ghost, replay, split screen and online
## parts hook in through the functions marked "hook" (filled in by their own ports).

const REVMAX := -9.0
const COAST := 4.0
const START_I := 6

# ------------------------------------------------------------------ scene objects (set by main.gd)
var camera: Camera3D
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
var raceContacts := 0
var racePits := 0

# ------------------------------------------------------------------ traffic & bots
const HATCH_COLORS := [0xe9e9e4, 0x2f6db3, 0x8c1c24, 0x3f444b, 0x5f8a3a, 0xd9a21b, 0x6a7fa0]
const BOT_NAMES := ["Henk", "Ingrid", "Daan", "Fenna", "Kees", "Sanne", "Joost"]
## rivals tune too: the bots get most of the edge your upgrades give over the stock car
const RIVAL_TUNE := 0.8
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
	# the player's car gets its own tail-light material so the brake lights can light up
	var tail: LMat = CarKit.tailMat.clone()
	car.tail = tail
	for mi in car.g.find_children("*", "MeshInstance3D", true, false):
		for k in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_material(k) == CarKit.tailMat:
				mi.set_surface_override_material(k, tail)
	if car.get("beam") != null:
		car.beam.visible = false
	var c := G.effStats(id)
	MAXV = c.vmax / 3.6
	ACC = c.acc * G.ACC_K
	BRAKE = c.brake * G.BRK_K
	GRIP = c.grip
	syncCar(0)

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
	g.rotation = Vector3(0, atan2(a.tx, a.tz) + yawOff, 0)

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
	for b in bots:
		if b.m.get("beam") != null:
			b.m.beam.visible = lampsOn and not b.out
		if not racing:
			b.speed = 0; b.cur = 0; b.vx = 0; b.vz = 0; b.lp = 0; b.yawK = 0; b.spin = 0; b.yawOff = 0; b.spun = false; b.pushDv = 0
			poseOnTrack(b.m.g, b.s, b.lat)
			continue
		if netInRace() and not netIsHost():
			poseOnTrack(b.m.g, b.s, b.lat, b.yawOff)
			for w in b.m.wheels: w.spin.rotation.x += wheelSpin(b.speed, w.r, dt)
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
			var i := int(floor(fposmod(b.s + d, Trk.TRACK_LEN) / Trk.SPC)) % Trk.NS
			var c: float = Trk.CURV[i]
			if c > 2e-4:
				var vl := sqrt(b.aLat * gripFactor() / c)
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
				b.mistT = 4 + randf() / df.mist
				b.lp += (-1.0 if randf() < .5 else 1.0) * (2 + randf() * 2)
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
			bend = maxf(bend, Trk.CURV[int(floor(fmod(b.s + dd, Trk.TRACK_LEN) / Trk.SPC)) % Trk.NS])
			dd += 10
		var kq := clamp_((into - 60) / 260, 0, 1)
		var kk := maxf(kq, clamp_((bend - 0.004) / 0.01, 0, 1) * clamp_(into / 40, 0, 1))
		if b.gridLat != null and kk < 1:
			wantLat = b.gridLat * (1 - kk) + wantLat * kk
		for o in obs:
			if o.ref == b: continue
			var dz := Trk.wrapD(o.s - b.s)
			if dz > 0 and dz < 24 and absf(o.lat - b.lat) < 2.3 and o.cur < b.speed + 4:
				if b.passT <= 0 and into > 150:
					var lim := Trk.ROAD_HALF - 1.4
					var opts := []
					for v in [o.lat - 3.4, o.lat + 3.4]:
						if absf(v) <= lim: opts.append(v)
					if not opts.is_empty():
						var best: float = opts[0]
						for v in opts:
							if absf(v - b.lat) < absf(best - b.lat): best = v
						b.passLat = best; b.passT = 1.6
				if dz < 16: target = minf(target, o.cur + clamp_((dz - 8) * 0.7, -6, 4))
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
		var lv: float = b.latV + b.lp
		b.vx = Trk.T[i2].x * b.speed + Trk.R[i2].x * lv
		b.vz = Trk.T[i2].z * b.speed + Trk.R[i2].z * lv
		for w in b.m.wheels:
			w.spin.rotation.x += wheelSpin(b.speed, w.r, dt)
	botCollisions()

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

func drive(dt: float, inp: Dictionary) -> void:
	player.gasIn = inp.gas
	updateGear(dt, inp.gas)
	var v := player.speed
	var sAbs := absf(v) / 69.4
	player.steer += (clamp_(inp.steer, -1, 1) - player.steer) * minf(1, dt * (14.0 if inp.analog else 7.0))
	var VM := MAXV
	var gi := clampi(player.gear, 1, 6) - 1
	var rpm := engineRpm()
	var torque := 0.78 + 0.22 * clamp_(rpm / 0.45, 0, 1)
	var limiter := 0.0 if maxf(0, player.speed) >= gearTop(clampi(player.gear, 1, 6)) * 0.995 else 1.0
	var cut := (0.12 if player.shiftT > 0 and player.gear > 1 else 1.0) * limiter
	if inp.gas > 0.05:
		player.speed += ACC * GACC[gi] * torque * cut * inp.gas * maxf(0.04, 1 - pow(maxf(0, v) / VM, 2)) * dt
	elif inp.brake > 0.05:
		if v > 0.5: player.speed -= BRAKE * inp.brake * dt
		else: player.speed -= 6 * inp.brake * dt
	else:
		var c := COAST * (0.7 + 0.9 * rpm * (1.2 - gi * 0.08)) * dt
		player.speed = 0.0 if absf(v) <= c else v - MathX.sgn(v) * c
	var sd = surfaceDrag(absf(player.lat))
	if sd != null and player.speed > sd[0]: player.speed -= sd[1] * dt
	player.speed = clamp_(player.speed, minf(REVMAX, v), maxf(VM, minf(player.speed, MAXV)))
	if player.speed > VM: player.speed -= 6 * dt
	var turn := 1.7 * GRIP * gripFactor() * clamp_(absf(player.speed) / 8, 0, 1) * maxf(0.32, 1 - 0.5 * sAbs)
	if inp.brake > 0.3 and absf(player.speed) > 15: turn *= 1 - 0.22 * inp.brake
	player.hand = bool(inp.hand) and absf(player.speed) > 3
	player.brk = inp.brake
	if state == "racing":
		if player.speed > raceTopSpeed: raceTopSpeed = player.speed
		if player.speed > 83.3: unlockAch("speed300")
	if player.hand:
		turn *= 1.55
		player.speed -= MathX.sgn(player.speed) * 7 * dt
		var k := -player.steer * absf(player.speed) * 0.32 * dt
		player.slide.x += -cos(player.heading) * k
		player.slide.y += sin(player.heading) * k
	player.heading -= player.steer * turn * dt * (MathX.sgn(player.speed) if player.speed != 0 else 1.0)
	if player.spin != 0:
		var hx := sin(player.heading); var hz := cos(player.heading)
		var vx := hx * player.speed + player.slide.x; var vz := hz * player.speed + player.slide.y
		player.heading += player.spin * dt
		var nx2 := sin(player.heading); var nz2 := cos(player.heading)
		player.speed = vx * nx2 + vz * nz2
		player.slide = Vector2(vx - nx2 * player.speed, vz - nz2 * player.speed)
		player.spin *= exp(-dt * (6.0 if absf(player.spin) < 0.5 else 1.6))
		if absf(player.spin) < 0.02: player.spin = 0
	var fx := sin(player.heading); var fz := cos(player.heading)
	player.pos.x += (fx * player.speed + player.slide.x) * dt
	player.pos.z += (fz * player.speed + player.slide.y) * dt
	player.slide *= exp(-dt * (1.6 if player.hand else 4.5))

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

func resetToTrack() -> void:
	if state != "racing" or clock - resetT < 2: return
	resetT = clock
	var i := player.idx
	var best: float = Trk.LANES[0]
	var bd := 1e9
	for l in Trk.LANES:
		if absf(l - player.lat) < bd:
			bd = absf(l - player.lat); best = l
	resetPlayer(i, best)
	snapCamera()
	Hud.showMsg("Terug op de baan", "ok", 1.2)

func edges(prevIdx: int, fx: float, fz: float, dt: float) -> bool:
	var i := player.idx
	var NS := Trk.NS
	if absf(player.lat) > Trk.EDGE[i]:
		var sgn := MathX.sgn(player.lat)
		if Trk.TRK.edge == "ditch":
			resetPlayer(i, Trk.LANES[-1] if sgn > 0 else Trk.LANES[0])
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
		player.heading = MathX.lerp_angle_(player.heading, dirTh, 0.35)
		var sn := (player.slide.x * Trk.R[i].x + player.slide.y * Trk.R[i].z) * sgn
		if sn > 0:
			player.slide.x -= Trk.R[i].x * sgn * sn
			player.slide.y -= Trk.R[i].z * sgn * sn
		if player.speed > 4 and clock - wallT > 0.35:
			player.speed *= clamp_(0.95 - into * 0.9, 0.5, 0.95)
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
func syncCar(dt: float) -> void:
	if car == null or Trk.NS <= 1: return
	var sp := player.speed / MAXV
	drift += ((player.steer * maxf(0, sp) * (0.4 if player.hand else 0.12) / GRIP) - drift) * minf(1, dt * (3.0 if player.hand else 5.0))
	var i := player.idx
	var slope := 0.0
	if absf(player.lat) < Trk.SHOULDER:
		slope = (Trk.HT[(i + 1) % Trk.NS] - Trk.HT[i]) / Trk.SPC * (sin(player.heading) * Trk.T[i].x + cos(player.heading) * Trk.T[i].z)
	car.g.position = Vector3(player.pos.x, player.y, player.pos.z)
	var pitch := -atan(slope) - ((0.012 if input().gas > 0.1 else 0.0) * (1 - sp) if state == "racing" else 0.0)
	car.g.rotation_order = EULER_ORDER_YXZ
	car.g.rotation = Vector3(pitch, player.heading - drift, -player.steer * maxf(0, sp) * 0.05)
	for k in 4:
		var w: Dictionary = car.wheels[k]
		w.spin.rotation.x += wheelSpin(player.speed, w.r, dt)
		if k < 2: w.pivot.rotation.y = -player.steer * 0.4
	if car.get("tail") != null:
		var br := (state == "racing" or state == "finished") and (player.brk > 0.3 or player.hand) and absf(player.speed) > 0.5
		var base: Color = CarKit.tailMat.emission if CarKit.tailMat.emission_enabled else Color.BLACK
		car.tail.emission_enabled = true
		car.tail.emission = base * (2.2 if br else 1.0)
		car.tail.albedo_color = MathX.col(0xff3a30 if br else 0x6e0b0b)

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
	camHeading = player.heading
	camY = player.y
	var c := camParams()
	placeCam(c)
	camera.position = camPos
	camera.look_at(camLook, Vector3.UP)
	camera.fov = c.fov

func placeCam(c: Dictionary) -> void:
	var fx := sin(camHeading); var fz := cos(camHeading)
	camPos = Vector3(player.pos.x - fx * c.dist, camY + c.h, player.pos.z - fz * c.dist)
	camLook = Vector3(player.pos.x + fx * 8, camY + 1.05, player.pos.z + fz * 8)

func lookHeld() -> bool:
	return actHeld(activeP, "look") or padFor(activeP).look

func updateCamera(dt: float) -> void:
	if Menu.menuCamera(dt): return   # menus: podium, home fly-over, orbit round the car, garage (Menu.menuCamera)
	speedFx = clamp_((maxf(0, player.speed) - 20) / 50, 0, 1) if (state == "racing" or state == "finished") else 0.0
	var c := camParams()
	var back := PI if player.speed < -1 else 0.0
	camHeading = MathX.lerp_angle_(camHeading, player.heading - drift * 0.5 + back, 1 - exp(-dt * 7))
	camY += (player.y - camY) * (1 - exp(-dt * 8))
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
	player.speed = 0; player.steer = 0; player.gear = 1; player.shiftT = 0; player.spin = 0
	player.slide = Vector2.ZERO
	locatePlayer()

func startRace() -> void:
	if not (state == "menu" or (state == "over" and overReady)): return
	Sfx.initAudio()
	Menu.beforeRace()                                    # menus: garage room and podium off, menu screens hidden
	if not Champ.active(): Career.ensureOwnedCars()     # you only race cars you own
	var S := G.settings
	mode = "champ" if Champ.active() else S.mode
	split = mode == "split"
	if split: mode = "race"
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
		# a championship races its fixed field, a career event its own (with the rival)
		setupBots(0, Champ.champ.bots if mode == "champ" else (G.careerEv.defs if G.careerEv != null else makeBotDefs(mini(int(S.bots), 5) if split else int(S.bots))))
		placeGrid(); nextCp = 0
	elif mode == "ghost":
		clearTraffic(); clearBots(); placeGrid(); nextCp = 0
	else:
		clearBots(); buildTraffic(); resetPlayer(0, 0); nextCp = 1; timeLeft = Trk.TRK.startTime
	snapCamera()
	state = "countdown"; cd = 0; lastCount = -1; goDelay = 0.4 + randf() * 0.8
	Hud.raceStart(raceMode, mode)
	clearKeys()

func finishPlayer(_win := false) -> void:
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
	if Menu.onAgain(): return    # menus: championship standings / next round, on to the next career event
	startRace()

func toMenu(step := -1) -> void:
	paused = false
	Hud.toMenu()
	state = "menu"
	Menu.toMenu(step)       # menus: championship and career clean-up, then the menu (step -1 = home screen)

## after a career race or cup: back to the career screen; otherwise to the menu
func toCareerOr(step := -1) -> void:
	Menu.toCareerOr(step)

func setPaused(p: bool) -> void:
	if p and not (state == "racing" or state == "countdown" or state == "finished"): return
	if p == paused: return
	paused = p
	Hud.setPaused(p)
	clearKeys()

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
		G.store_set(lapKey(Trk.TRACK_ID), "%.2f" % lt)
		G.store_set(lapKey(Trk.TRACK_ID) + "-car", G.settings.car)
		lapRecordSet = true
	var pc := float(G.store_get(lapCarKey(Trk.TRACK_ID), 0))
	if not pc or lt < pc: G.store_set(lapCarKey(Trk.TRACK_ID), "%.2f" % lt)

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
		return
	var lt := raceTime - lapStart
	lapStart = raceTime; recordLap(lt); lapTimes.append(lt)
	if not split: sectorLapStart()
	if mode != "elim" and player.lap > raceLaps:
		finishPlayer(); return
	var lbl := ("Ronde %d" % player.lap) if mode == "elim" else ("Laatste ronde" if player.lap == raceLaps else "Ronde %d/%d" % [player.lap, raceLaps])
	Hud.showMsg(lbl + "  " + G.fmtLap(lt), "ok", 2)
	Sfx.tone(880, 0.14, "triangle", 0.16); Sfx.tone(1320, 0.26, "triangle", 0.16, 0.12)

func awardCredits(pos: int) -> int:
	var p: float = G.DIFF[G.settings.diff].pay
	if mode == "time": return G.addCredits(distance / 1000 * 60)
	if mode == "ghost": return G.addCredits(lapTimes.size() * 40 + (150 if ghostSaved else 0))
	var bases := [400, 300, 220, 160, 120, 90, 70, 50]
	var base: int = bases[(pos if pos > 0 else 8) - 1] if (pos if pos > 0 else 8) <= 8 else 40
	return G.addCredits(base * p * (1.0 if mode == "elim" else clamp_(0.6 + raceLaps * 0.2, 0.8, 1.6)))

# ------------------------------------------------------------------ hooks (filled in by later ports)
func netInRace() -> bool: return false
func netIsHost() -> bool: return false
func netAheadCount(_me: float) -> int: return 0
func netKick(_i: int, _dvx: float, _dvz: float, _sp: float) -> void: pass
func otherProgress() -> Variant: return null
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

func padFor(_pi: int) -> Dictionary:
	return pad

func input() -> Dictionary:
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
		if a == "reset": resetToTrack()
		if a == "cam": cycleCam()
		if G.prefs.gearbox == "manual" and (state == "racing" or state == "finished"):
			if a == "shiftUp": shiftUp()
			if a == "shiftDown": shiftDown()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clearKeys()
		setPaused(true)

## gamepad (JS readPad, standard mapping): Godot's joypad buttons/axes mapped onto the same roles
func readPad() -> void:
	pad = {"steer": 0.0, "gas": 0.0, "brake": 0.0, "hand": false, "look": false}
	var now := {}
	for dev in Input.get_connected_joypads():
		var ax := Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
		pad.steer = ax if absf(ax) > 0.14 else 0.0
		var btn := func(b: int) -> bool: return Input.is_joy_button_pressed(dev, b)
		if btn.call(JOY_BUTTON_DPAD_LEFT): pad.steer = -1.0
		if btn.call(JOY_BUTTON_DPAD_RIGHT): pad.steer = 1.0
		pad.gas = maxf(Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_RIGHT), 1.0 if btn.call(JOY_BUTTON_A) else 0.0)
		pad.brake = maxf(Input.get_joy_axis(dev, JOY_AXIS_TRIGGER_LEFT), 1.0 if btn.call(JOY_BUTTON_B) else 0.0)
		pad.hand = btn.call(JOY_BUTTON_X) or (G.prefs.gearbox != "manual" and btn.call(JOY_BUTTON_RIGHT_SHOULDER))
		pad.look = btn.call(JOY_BUTTON_RIGHT_STICK)
		var ay := Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y)
		now = {"a": btn.call(JOY_BUTTON_A), "b": btn.call(JOY_BUTTON_B), "start": btn.call(JOY_BUTTON_START), "y": btn.call(JOY_BUTTON_Y),
			"lb": btn.call(JOY_BUTTON_LEFT_SHOULDER), "rb": btn.call(JOY_BUTTON_RIGHT_SHOULDER), "sel": btn.call(JOY_BUTTON_BACK),
			"l": btn.call(JOY_BUTTON_DPAD_LEFT) or ax < -0.6, "r": btn.call(JOY_BUTTON_DPAD_RIGHT) or ax > 0.6,
			"up": btn.call(JOY_BUTTON_DPAD_UP) or ay < -0.6, "down": btn.call(JOY_BUTTON_DPAD_DOWN) or ay > 0.6}
		break
	var edge := func(k: String) -> bool: return now.get(k, false) and not padPrev.get(k, false)
	if Menu.padNav(now, padPrev):    # menus, pause and results screen (Menu.padNav)
		pass
	else:
		if edge.call("start"): setPaused(true)
		if edge.call("y"): resetToTrack()
		if edge.call("sel"): cycleCam()
		if G.prefs.gearbox == "manual":
			if edge.call("rb"): shiftUp()
			if edge.call("lb"): shiftDown()
	padPrev = now

# ================================================================== main loop
func _ready() -> void:
	_load_binds()
	process_mode = Node.PROCESS_MODE_ALWAYS

func update(dt: float) -> void:
	clock += dt
	if shake > 0: shake = maxf(0, shake - dt)
	if Env.me != null: Env.me.update(dt, camera)
	for s in World.sailGroups:
		s.rotation.z += dt * float(s.get_meta("speed", 0.8))
	if state == "menu":
		updateTraffic(dt, false); updateBots(dt); return
	updateTraffic(dt, true); updateBots(dt)
	if state == "countdown":
		player.speed = 0
		player.gasIn = input().gas
		cd += dt
		var on := mini(5, int(floor(cd / 0.7)))
		if on != lastCount and cd < 3.5 + goDelay:
			lastCount = on
			Hud.setLights(on)
			if on > 0: Sfx.tone(440, 0.16, "square", 0.09)
		if cd >= 3.5 + goDelay:
			state = "racing"
			lapStart = 0.0 if raceMode else clock
			Hud.lightsGo()
			Sfx.tone(880, 0.35, "square", 0.1)
		return
	if state == "over":
		autopilot(dt, 22.0 if raceMode else 0.0)
		Menu.overTick()    # the results list keeps up while the bots finish
		return
	raceTime += dt
	if state == "finished":
		autopilot(dt, 22)
		if clock > finishAt: showResults()
		return
	updatePlayer(dt); updateWind(dt); sectorUpdate(); elimCheck()
	if mode == "time":
		var before := timeLeft
		timeLeft -= dt
		if timeLeft > 0 and timeLeft < 5.5 and ceil(before) != ceil(timeLeft): Sfx.tone(1250, 0.05, "square", 0.08)
		if timeLeft <= 0: endTimeTrial()

func _process(delta: float) -> void:
	if camera == null or Trk.NS <= 1: return
	var dt := minf(0.1, delta)
	readPad()
	if not paused:
		var n := mini(12, maxi(1, int(ceil(dt / 0.0085))))
		for _k in n: update(dt / n)
	if car != null: syncCar(0.0 if paused else dt)
	updateCamera(0.0 if paused else dt)
	Sfx.updateAudio()
	Hud.tick()

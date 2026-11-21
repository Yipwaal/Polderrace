extends Node
## Bug hunt: plays races in the real game scene with real key events (tests/play_driver.gd) and a driver that brakes
## for the bends like a player (or keeps its foot down: style=flat), watches for things that look wrong and saves
## screenshots. Each problem found prints a line "VREEMD ...".
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver opengl3 --resolution 1280x720 \
##     res://tools/hunt.tscn -- track=polder dir=fwd mode=race bots=5 car=gt laps=1 time=day weather=dry quality=high \
##     style=brake secs=60 shots=10,30 out=/abs/dir cam=0 size=1280x720
## Checks: the car on screen where a chase camera puts it, the camera never inside another car, no NaN, no spin
## or roll-over out of nothing, the car not under the road, errors in the log.

var D
var a := {"track": "polder", "dir": "fwd", "mode": "race", "bots": "5", "car": "gt", "laps": "1", "time": "day", "weather": "dry",
	"quality": "high", "style": "brake", "secs": "60", "shots": "", "out": "/tmp", "cam": "0", "size": "1280x720", "scale": "2"}
var odd := 0
var sloot := 0
var _msgPrev := ""
var ys: Array = []
var worstY := 0.0
var worstMsg := ""

func _ready() -> void:
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2: a[kv[0]] = kv[1]
	var rep := TestReport.new("bugjacht")
	D = load("res://tests/play_driver.gd").new(get_tree(), rep)
	D.shots = ""
	var owned := {}
	for id in Cars.CARS: owned[id] = true
	var sz: PackedStringArray = a.size.split("x")
	var S := {"car": a.car, "track": a.track, "dir": a.dir, "mode": a.mode, "bots": int(a.bots), "laps": int(a.laps), "time": a.time, "weather": a.weather}
	await D.boot("user://hunt.json", {"polderrace3d-garage": {"owned": owned}, "polderrace3d-settings": S,
		"polderrace3d-prefs": {"quality": a.quality, "cam": int(a.cam)}}, Vector2i(int(sz[0]), int(sz[1])))
	for k in S: G.settings[k] = S[k]
	G.prefs.quality = a.quality
	G.prefs.cam = int(a.cam)
	Game.applyPrefs()
	if Trk.TRACK_ID != a.track or Trk.TRACK_DIR != a.dir or Env.me.time != a.time or Env.me.weather != a.weather:
		await get_tree().current_scene.load_track(a.track)
	Game.rebuildPlayerCar()
	Game.startRace()
	if a.get("p2cam", "") != "" and Game.split and Game.p2 != null: Game.p2.cam = int(a.p2cam)
	var shots: Array = Array(a.shots.split(",", false)).map(func(x): return float(x))
	var secs := float(a.secs)
	Engine.time_scale = float(a.scale)
	var c0: float = Game.clock
	# qswitch=low@10,high@20: change the picture quality mid-race (as the pause settings do)
	var qs: Array = Array(a.get("qswitch", "").split(",", false)).map(func(x): return x.split("@"))
	while Game.clock - c0 < secs and Game.state != "over" and Game.state != "menu":
		await drive()
		await get_tree().process_frame
		var t: float = Game.clock - c0
		look(t)
		var mt: String = Hud.msg_label.text if Hud.msg.visible else ""
		if mt != _msgPrev and mt == "In de sloot!": sloot += 1
		_msgPrev = mt
		if a.get("trace", "") == "1" and int(t * 2) != int((t - get_process_delta_time() * Engine.time_scale) * 2):
			var pl: PlayerState = Game.player
			print("  t %.1f i %d lat %.1f v %.0f gear %d beta %.2f off %.2f y %.2f keys %s" % [t, pl.idx, pl.lat, pl.speed * 3.6, pl.gear, pl.beta, pl.offroad, pl.y, str(Game.keysDown.keys())])
		if not qs.is_empty() and t >= float(qs[0][1]):
			G.prefs.quality = qs[0][0]
			Menu.applyPrefs()
			print("     kwaliteit nu ", qs[0][0])
			qs.pop_front()
		if not shots.is_empty() and t >= shots[0]:
			await shot("t%d" % int(shots[0]))
			if a.get("look", "") == "1":
				D.hold(KEY_C, true)
				await D.frames(3)
				await shot("t%d_achter" % int(shots[0]))
				D.hold(KEY_C, false)
			shots.pop_front()
		D.check_errors("rijden")
	Engine.time_scale = 1.0
	# replay=1: open the replay at the results and take pictures of it (each camera)
	if a.get("replay", "") == "1" and Game.state == "over":
		await D.until(func(): return Game.overReady, 3)
		Rep.replayOpen()
		for k in 3:
			Rep.rp.camMode = k; Rep.rp.camT = 0.0; Rep.rp.anchor = null
			Rep.rp.t = 20.0 + k * 9
			await D.frames(20)
			await shot("replay_cam%d" % k)
		D.check_errors("replay")
	print("KLAAR %s %s %s %s %s: state %s ronde %d plaats %d finish %.1f, %d keer R, %d keer sloot, %d vreemd, tijd %.1f" % [a.track, a.dir, a.mode, a.car, a.style, Game.state, Game.player.lap, Game.playerPosition(), Game.raceFinishTime, D.resets, sloot, odd, Game.clock - c0])
	ys.sort()
	if not ys.is_empty():
		print("SCHERM %s %s: auto op het scherm (hoogte/venster) mediaan %.2f, 99%% %.2f, max %.2f, %d frames > 0,8; ergste: %s" % [a.track, a.dir, ys[ys.size() / 2], ys[int(ys.size() * 0.99)], ys[-1], ys.filter(func(y): return y > 0.8).size(), worstMsg])
	D.check_errors("einde")
	D.done()
	get_tree().quit()

var _wrong := [0.0, 0.0]
## a player-like driver: aims at the racing line a bit ahead, brakes for what is coming (style brake) or never (flat)
func drive() -> void:
	var g := Game
	if g.state != "racing" and g.state != "countdown":
		for k in [KEY_A, KEY_D, KEY_W, KEY_S, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]: D.hold(k, false)
		return
	await drive_one(g.player, g.GRIP, [KEY_W, KEY_S, KEY_A, KEY_D, KEY_R], 0)
	if g.split and g.p2 != null:
		await drive_one(g.p2.pl, g.p2.GRIP, [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_KP_0], 1)

func drive_one(pl: PlayerState, grip: float, keys: Array, n: int) -> void:
	var g := Game
	var NS := Trk.NS
	var ahead := int(clampf(pl.speed * 0.5 / Trk.SPC, 3, 30))
	var j := (pl.idx + ahead) % NS
	var tl: float = Trk.LINE[j] * 0.8
	var tx: float = Trk.P[j].x + Trk.R[j].x * tl
	var tz: float = Trk.P[j].z + Trk.R[j].z * tl
	var want := atan2(tx - pl.pos.x, tz - pl.pos.z)
	var df := fposmod(want - pl.heading + PI, TAU) - PI
	var st := clampf(-df * 2.5, -1, 1)
	D.hold(keys[3], st > 0.1)
	D.hold(keys[2], st < -0.1)
	var gas := true
	var brk := false
	if a.style == "brake":
		var target := 999.0
		var d := 4.0
		while d < 220:
			var i := int(floor(fposmod(pl.s + d, Trk.TRACK_LEN) / Trk.SPC)) % NS
			var c: float = Trk.CURV[i]
			if c > 2e-4:
				var vl := 1.7 * grip * g.gripFactor() / (c + 1.7 * 0.5 / 69.4) * 0.92
				target = minf(target, sqrt(vl * vl + 2 * 20.0 * d))
			d += 6
		if pl.speed > target + 2: brk = true; gas = false
		elif pl.speed > target - 1: gas = false
	if a.style == "stop":
		gas = g.state == "racing" and g.raceTime < 3.0
		brk = not gas
	D.hold(keys[0], gas)
	D.hold(keys[1], brk)
	var th := Trk.heading_of(Trk.T[pl.idx])
	var dw := fposmod(th - pl.heading + PI, TAU) - PI
	_wrong[n] = _wrong[n] + 1.0 / 60 if absf(dw) > 2.1 and g.state == "racing" else 0.0
	if _wrong[n] > 1.5:
		_wrong[n] = 0
		D.resets += 1
		await D.tap(keys[4])

var _lastOdd := {}
func vreemd(key: String, msg: String) -> void:
	var t: float = Game.clock
	if t - float(_lastOdd.get(key, -99.0)) < 3.0: return
	_lastOdd[key] = t
	odd += 1
	print("VREEMD %s %s %s t=%.1f: %s" % [a.track, a.dir, key, Game.raceTime, msg])
	if odd <= 12: shot("vreemd_%d_%s" % [odd, key])

func look(_t: float) -> void:
	var g := Game
	var pl: PlayerState = g.player
	if is_nan(pl.pos.x) or is_nan(pl.heading) or is_nan(pl.speed):
		vreemd("nan", "NaN in de speler")
		return
	if g.state != "racing" and g.state != "finished": return
	var cam: Camera3D = g.camera
	# the camera inside another car
	for b in g.bots + g.traffic:
		var bp: Vector3 = b.m.g.global_position
		var lp: Vector3 = b.m.g.global_transform.affine_inverse() * cam.global_position
		var hh: float = 3.9 if b.m.len > 10 else (2.6 if b.m.len > 5 else 1.6)
		if absf(lp.x) < b.m.wid * 0.5 + 0.1 and absf(lp.z - float(b.m.get("off", 0.0))) < b.m.len * 0.5 + 0.1 and lp.y < hh and lp.y > -0.3:
			vreemd("camInCar", "camera in %s (%.1f m)" % [b.get("name") if b.is_bot else "verkeer", cam.global_position.distance_to(bp)])
	# the chase camera: the car round the lower middle of the screen
	if int(G.prefs.cam) != 2 and not g.lookHeld() and g.car.g.visible:
		var vp := get_viewport().get_visible_rect().size
		var sp := cam.unproject_position(g.car.g.global_position + Vector3(0, 0.6, 0))
		var behind := cam.is_position_behind(g.car.g.global_position)
		var fy: float = sp.y / vp.y
		ys.append(fy)
		if fy > 0.8 and fy > worstY:
			worstY = fy
			worstMsg = "t=%.1f i %d lat %.1f v %.0f camY-y %.2f camLift %.2f" % [g.raceTime, pl.idx, pl.lat, pl.speed * 3.6, g.camY - pl.y, g.camLift]
		if behind or sp.y > vp.y * 0.92 or sp.y < vp.y * 0.35 or sp.x < vp.x * 0.15 or sp.x > vp.x * 0.85:
			vreemd("carOnScreen", "auto op het scherm op (%.0f, %.0f) van %s, achter %s, camLift %.2f, cam-auto %.1f m, camY %.2f auto y %.2f, v %.0f km/h, lat %.1f (rand %.1f, i %d), melding '%s'" % [sp.x, sp.y, str(vp), str(behind), g.camLift,
				cam.global_position.distance_to(g.car.g.global_position), g.camY, pl.y, pl.speed * 3.6, pl.lat, Trk.EDGE[pl.idx], pl.idx, Hud.msg_label.text if Hud.msg.visible else ""])
	# under the road / off the ground
	var gy: float = pl.y
	if g.car.g.global_position.y < gy - 0.3:
		vreemd("underRoad", "auto %.2f m onder de weg" % (gy - g.car.g.global_position.y))
	if absf(pl.spin) > 3 and g.raceContacts == 0:
		vreemd("spin", "spin %.2f zonder botsing" % pl.spin)
	if absf(pl.beta) > 1.2 and pl.speed > 10:
		vreemd("slide", "slip %.2f rad bij %.0f km/h" % [pl.beta, pl.speed * 3.6])

func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var p := "%s/%s_%s_%s_%s_%s_%s.png" % [a.out, a.track, a.dir, a.time, a.weather, a.quality, name]
	get_viewport().get_texture().get_image().save_png(p)
	print("     shot ", p)

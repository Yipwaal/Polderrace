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
	var shots: Array = Array(a.shots.split(",", false)).map(func(x): return float(x))
	var secs := float(a.secs)
	Engine.time_scale = float(a.scale)
	var c0: float = Game.clock
	var lastRoll := 0.0
	while Game.clock - c0 < secs and Game.state != "over" and Game.state != "menu":
		await drive()
		await get_tree().process_frame
		var t: float = Game.clock - c0
		look(t)
		if not shots.is_empty() and t >= shots[0]:
			await shot("t%d" % int(shots[0]))
			shots.pop_front()
		D.check_errors("rijden")
	Engine.time_scale = 1.0
	print("KLAAR %s %s %s %s %s: state %s ronde %d plaats %d finish %.1f, %d keer R, %d vreemd, tijd %.1f" % [a.track, a.dir, a.mode, a.car, a.style, Game.state, Game.player.lap, Game.playerPosition(), Game.raceFinishTime, D.resets, odd, Game.clock - c0])
	D.check_errors("einde")
	D.done()
	get_tree().quit()

var _wrong := 0.0
## a player-like driver: aims at the racing line a bit ahead, brakes for what is coming (style brake) or never (flat)
func drive() -> void:
	var g := Game
	if g.state != "racing" and g.state != "countdown":
		D.hold(KEY_A, false); D.hold(KEY_D, false); D.hold(KEY_W, false); D.hold(KEY_S, false)
		return
	var pl: PlayerState = g.player
	var NS := Trk.NS
	var ahead := int(clampf(pl.speed * 0.5 / Trk.SPC, 3, 30))
	var j := (pl.idx + ahead) % NS
	var tl: float = Trk.LINE[j] * 0.8
	var tx: float = Trk.P[j].x + Trk.R[j].x * tl
	var tz: float = Trk.P[j].z + Trk.R[j].z * tl
	var want := atan2(tx - pl.pos.x, tz - pl.pos.z)
	var df := fposmod(want - pl.heading + PI, TAU) - PI
	var st := clampf(-df * 2.5, -1, 1)
	D.hold(KEY_D, st > 0.1)
	D.hold(KEY_A, st < -0.1)
	var gas := true
	var brk := false
	if a.style == "brake":
		var target := 999.0
		var d := 4.0
		while d < 220:
			var i := int(floor(fposmod(pl.s + d, Trk.TRACK_LEN) / Trk.SPC)) % NS
			var c: float = Trk.CURV[i]
			if c > 2e-4:
				var vl := 1.7 * g.GRIP * g.gripFactor() / (c + 1.7 * 0.5 / 69.4) * 0.92
				target = minf(target, sqrt(vl * vl + 2 * 20.0 * d))
			d += 6
		if pl.speed > target + 2: brk = true; gas = false
		elif pl.speed > target - 1: gas = false
	D.hold(KEY_W, gas)
	D.hold(KEY_S, brk)
	var th := Trk.heading_of(Trk.T[pl.idx])
	var dw := fposmod(th - pl.heading + PI, TAU) - PI
	_wrong = _wrong + 1.0 / 60 if absf(dw) > 2.1 and g.state == "racing" else 0.0
	if _wrong > 1.5:
		_wrong = 0
		D.resets += 1
		await D.tap(KEY_R)

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
		if absf(lp.x) < b.m.wid * 0.5 + 0.1 and absf(lp.z - float(b.m.get("off", 0.0))) < b.m.len * 0.5 + 0.1 and lp.y < 1.6 and lp.y > -0.3:
			vreemd("camInCar", "camera in %s (%.1f m)" % [b.get("name") if b.is_bot else "verkeer", cam.global_position.distance_to(bp)])
	# the chase camera: the car round the lower middle of the screen
	if int(G.prefs.cam) != 2 and not g.lookHeld() and g.car.g.visible:
		var vp := get_viewport().get_visible_rect().size
		var sp := cam.unproject_position(g.car.g.global_position + Vector3(0, 0.6, 0))
		var behind := cam.is_position_behind(g.car.g.global_position)
		if behind or sp.y > vp.y * 0.92 or sp.y < vp.y * 0.35 or sp.x < vp.x * 0.15 or sp.x > vp.x * 0.85:
			vreemd("carOnScreen", "auto op het scherm op (%.0f, %.0f) van %s, achter %s, camLift %.2f" % [sp.x, sp.y, str(vp), str(behind), g.camLift])
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

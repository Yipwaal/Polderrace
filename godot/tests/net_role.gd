extends Node
## One side of the online test (tests/test_net.py starts a host and a guest process):
##   godot --headless --path godot res://tests/net_role.tscn -- role=host|guest nick=... secs=...
## Prints "NET <key> <value>" lines that the Python side checks.

var role := "host"
var stepper

func say(k: String, v) -> void:
	print("NET %s %s" % [k, JSON.stringify(v)])

func _ready() -> void:
	var a := {"role": "host", "nick": "Host", "secs": "12"}
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2: a[kv[0]] = kv[1]
	role = a.role
	get_tree().create_timer(120, true, false, true).timeout.connect(func(): say("timeout", true); get_tree().quit(1))
	G.prefs.nick = a.nick
	G.settings.track = "polder"; G.settings.bots = 2; G.settings.laps = 1; G.settings.car = "gt" if role == "host" else "hatch"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	while Game.state != "menu" or Game.car == null:
		await get_tree().process_frame
	stepper = load("res://tests/test_laps.gd").new()
	if role == "host":
		Net.netCreate()
		say("hosting", Net.net != null)
		var t0 := Time.get_ticks_msec()
		while Net.net.remotes.is_empty() and Time.get_ticks_msec() - t0 < 30000:
			await get_tree().process_frame
		say("guest_seen", Net.net.remotes.size())
		await get_tree().create_timer(0.5).timeout
		Net.netHostStart()
	else:
		Net.browse()
		var t0 := Time.get_ticks_msec()
		while Net.lobbies().is_empty() and Time.get_ticks_msec() - t0 < 20000:
			await get_tree().process_frame
		var ls := Net.lobbies()
		say("lobbies", ls.map(func(l): return {"name": l.name, "ip": l.ip, "track": l.track, "n": l.n}))
		if ls.is_empty(): get_tree().quit(1); return
		Net.netJoin(ls[0].ip)
		t0 = Time.get_ticks_msec()
		while not Net.inRace() and Time.get_ticks_msec() - t0 < 30000:
			await get_tree().process_frame
	say("in_race", Net.inRace())
	say("track", Trk.TRACK_ID)
	say("bots", Game.bots.map(func(b): return b.name + ":" + b.type))
	# drive: the autopilot, one 1/60 s step per frame so the network keeps ticking
	Game.set_process(false)
	var frames := int(float(a.secs) * 60)
	for _f in frames:
		stepper.step(1.0 / 60, Game.state == "racing")
		await get_tree().process_frame
	var rem := []
	for r in Net.net.remotes.values():
		rem.append({"name": r.name, "car": r.carId, "has_st": r.st != null, "s": r.st[5] if r.st != null else -1, "visible": r.car.g.visible})
	say("remotes", rem)
	say("me_s", Game.player.s)
	say("bot_s", Game.bots.map(func(b): return snappedf(b.s, 0.1)))
	# the bots relative to the host's car, at the same moment on both sides: host = its own car, guest = the host's car as received
	var ref: float = Game.player.s
	if role == "guest":
		for r in Net.net.remotes.values():
			if r.host and r.st != null: ref = r.st[5]
	say("bot_rel", Game.bots.map(func(b): return snappedf(Trk.wrapD(b.s - ref), 0.1)))
	say("state", Game.state)
	say("position", Game.playerPosition())
	if role == "host":
		await get_tree().create_timer(1.0).timeout
		Net.netLeave()
		say("left", true)
		await get_tree().create_timer(1.0).timeout
	else:
		var t1 := Time.get_ticks_msec()
		while Net.net != null and Time.get_ticks_msec() - t1 < 8000:
			await get_tree().process_frame
		say("closed_by_host", Net.net == null)
		say("status", Net.status)
	get_tree().quit()

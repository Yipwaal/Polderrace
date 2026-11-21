extends Node
## One player of the online scenarios (tests/test_net_more.py), driven from outside like a player at the keyboard:
##   godot --headless --path godot res://tests/net_ctl.tscn -- name=p1 ctl=/abs/p1.cmd [nick=Kees] [car=hatch] [ts=1]
## The Python side appends lines "<seq> <command> [args]" to the ctl file; each command answers one line "NET <seq> <json>".
## While a race runs the player drives itself (gas and steering keys, steered like the autopilot of test_laps).
## Commands press the same buttons a player would (NetUi, results and pause screens); nothing in the game scripts knows
## about this test. ts = Engine.time_scale (races go faster, the network keeps real time).

var pname := "p1"
var ctl := ""
var handled := 0
var busy := false
var queue: Array = []
var drive := true
var wrong := 0.0
var go_at := 0.0                   ## wall clock when the lights went green (start in sync on every PC)
var grid := []                     ## my place on the grid at the countdown
var grid_bots := []
var last_state := ""
var bot_track := []                ## per frame: how far bot 0's car moved (smooth or jumpy)
var hitches := 0
var ram_until := 0                 ## while ramming: steer for bot 0's lane instead of the middle
var ts := 1.0                      ## Engine.time_scale while racing (the countdown runs at real speed)
var me_track := []                 ## per frame: wall clock, x, z of my own car (truth for the others' picture of it)
var rem_track := []                ## per frame: wall clock, x, z of the car of `rem_name` as this game shows it
var rem_name := ""
var tracking := false
var said := []                     ## chat lines heard
var frame_us := 0                  ## wall clock of the last frame (usec)
var max_frame := 0.0               ## the longest frame since the last "frames" command (ms, wall clock)

func say(seq: String, v) -> void:
	print("NET %s %s" % [seq, JSON.stringify(v)])

func _ready() -> void:
	var a := {"name": "p1", "ctl": "", "nick": "", "car": "hatch", "ts": "1", "color": "", "tok": "", "look": ""}
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2: a[kv[0]] = kv[1]
	pname = a.name
	ctl = a.ctl
	get_tree().create_timer(600, true, false, true).timeout.connect(func(): say("0", "timeout"); get_tree().quit(1))
	Engine.max_fps = 60
	# own save file per player (never the player's), owning every car
	var owned := {}
	for id in Cars.CARS: owned[id] = true
	# (the same token every time this player starts: a game that crashed comes back as the same player)
	var store := {"polderrace3d-garage": {"owned": owned}, "polderrace3d-online": {"tok": ("tok-%s-0123456789abcdef" % pname) if a.get("tok", "") == "" else a.tok}}
	if a.get("look", "") != "":
		# a whole garage entry, as the game saves one (the looks given on top of the factory state)
		var up := Cars.default_up()
		up.merge(JSON.parse_string(a.look), true)
		store["polderrace3d-garage"]["cars"] = {a.car: up}
	G.use_store("user://test-netctl-%s.json" % pname, store)
	Net.said.connect(func(who, text): said.append([who, text]))
	G.prefs.nick = a.nick if a.nick != "" else pname
	G.settings.track = "dorp"; G.settings.bots = 2; G.settings.laps = 1; G.settings.car = a.car
	if a.color != "": G.settings.color = a.color
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	while Game.state != "menu" or Game.car == null:
		await get_tree().process_frame
	ts = float(a.ts)
	say("0", "ready")

func _process(dt: float) -> void:
	var now_us := Time.get_ticks_usec()
	if frame_us > 0: max_frame = maxf(max_frame, (now_us - frame_us) / 1000.0)
	frame_us = now_us
	# first what happened this frame (a report must not see "racing" before go_at is set), then the next command
	_watch(dt)
	_drive()
	Engine.time_scale = 1.0 if Game.state == "countdown" or Game.state == "menu" else ts
	_poll_ctl()
	if not busy and not queue.is_empty():
		var line: String = queue.pop_front()
		busy = true
		await _run(line)
		busy = false

func _poll_ctl() -> void:
	if ctl == "" or not FileAccess.file_exists(ctl): return
	var lines := FileAccess.get_file_as_string(ctl).split("\n")
	# only whole lines (the last one may still be written)
	for i in range(handled, lines.size() - 1):
		if lines[i].strip_edges() != "": queue.append(lines[i].strip_edges())
		handled = i + 1

func _watch(_dt: float) -> void:
	var st := Game.state
	if st != last_state:
		if st == "countdown":
			grid = [snappedf(Game.player.pos.x, 0.01), snappedf(Game.player.pos.z, 0.01)]
			grid_bots = Game.bots.map(func(b): return [snappedf(b.m.g.position.x, 0.01), snappedf(b.m.g.position.z, 0.01)])
			bot_track = []
		if st == "racing": go_at = Time.get_unix_time_from_system()
		last_state = st
	# how bot 0 moves on screen, frame by frame (a guest's bots come from the host's snapshots)
	if st == "racing" and not Game.bots.is_empty() and bot_track.size() < 600:
		bot_track.append(snappedf(Game.bots[0].m.g.position.x, 0.001))
		bot_track.append(snappedf(Game.bots[0].m.g.position.z, 0.001))
		bot_track.append(snappedf(Game.clock, 0.0001))
	# my own car and one other player's car as shown here, against the wall clock (the same on every game of this PC)
	if tracking and st == "racing":
		var t := Time.get_unix_time_from_system()
		if me_track.size() < 9000:
			me_track.append_array([t, snappedf(Game.player.pos.x, 0.001), snappedf(Game.player.pos.z, 0.001)])
		if Net.net != null and rem_track.size() < 9000:
			for r in Net.net.remotes.values():
				if r.name == rem_name and r.car != null and r.car.g.visible:
					rem_track.append_array([t, snappedf(r.car.g.position.x, 0.001), snappedf(r.car.g.position.z, 0.001)])

## the player's hands: gas, and steering keys like the autopilot of test_laps
func _drive() -> void:
	var g := Game
	for k in ["KeyW", "KeyA", "KeyD"]: g.keysDown.erase(k)
	if not drive or g.paused or not (g.state == "countdown" or g.state == "racing"): return
	if Trk.NS <= 1: return
	g.keysDown["KeyW"] = true
	var th := Trk.heading_of(Trk.T[g.player.idx])
	var df := fposmod(th - g.player.heading + PI, TAU) - PI
	var aim: float = g.bots[0].lat if Time.get_ticks_msec() < ram_until and not g.bots.is_empty() else 0.0
	var st := clampf(-df * 3 - (g.player.lat - aim) * 0.15, -1, 1)
	if st > 0.15: g.keysDown["KeyD"] = true
	elif st < -0.15: g.keysDown["KeyA"] = true
	wrong = wrong + 1.0 / 60 if absf(df) > 2.1 else 0.0
	if wrong > 1.5 and g.state == "racing":
		wrong = 0; g.resetToTrack()

# ------------------------------------------------------------------ buttons, like a player clicking
func _buttons(root: Node, out: Array) -> void:
	for c in root.get_children():
		if (c is Button or c is UiKit.Btn) and c.is_visible_in_tree(): out.append(c)
		_buttons(c, out)

func _find(text: String) -> Control:
	var all := []
	for root in [NetUi, Menu, Rep]: _buttons(root, all)
	for b in all:
		if _text(b) == text and not b.get("disabled"): return b
	return null

## a button's caption: Button.text, or the label inside a menu button (UiKit.Btn)
static func _text(b: Control) -> String:
	if b is Button and b.text != "": return b.text
	var l = b.get_meta("label") if b.has_meta("label") else null
	return l.text if l is Label else ""

func press(text: String) -> bool:
	var b := _find(text)
	if b == null: return false
	b.emit_signal("pressed")
	return true

func _wait(cond: Callable, secs: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > secs * 1000: return false
		await get_tree().process_frame
	return true

## one row of the host's option rows in the online screen (track, laps, bots, ...): its ◀ or ▶ button
func _arrow(key: String, right := true) -> Control:
	if not NetUi.cyc.has(key): return null
	var row: Node = NetUi.cyc[key].get_parent()
	var b: Control = row.get_child(3 if right else 1)
	return b if b.is_visible_in_tree() else null

## the value a host option has now
func _opt(key: String) -> String:
	if key == "grid" or key == "next": return str(Net.onl().get(key, "rev" if key == "grid" else "host"))
	if key == "open": return "1" if Net.net != null and Net.net.open else "0"
	return str(G.settings[key])

## the row of a player in the lobby
func _player_row(nick: String) -> Node:
	for c in NetUi.players.get_children():
		if not c.is_queued_for_deletion() and c.get_meta("nick", "") == nick: return c
	return null

func _run(line: String) -> void:
	var parts := line.split(" ", false)
	var seq: String = parts[0]
	var cmd: String = parts[1] if parts.size() > 1 else ""
	var args := parts.slice(2)
	var rest := " ".join(args)
	match cmd:
		"report":
			say(seq, report())
		"open":
			Menu.netOpen()
			say(seq, NetUi.is_open())
		"nick":
			NetUi.nick.text = rest
			NetUi.nick.text_changed.emit(rest)
			say(seq, G.prefs.nick)
		"press":
			say(seq, press(rest))
		"join":
			# the n-th game in the list (wait for it to show up), its Meedoen button
			var n := int(args[0]) if args.size() > 0 else 0
			var ok := await _wait(func(): return NetUi.list.get_child_count() > n and _card_btn(n) != null, 15)
			ok = ok and not _card_btn(n).get("disabled")    # a greyed-out button cannot be clicked
			if ok: _card_btn(n).emit_signal("pressed")
			say(seq, ok)
		"joinip":
			NetUi.ip_in.text = rest
			var jb: Button = null
			for c in NetUi.ip_in.get_parent().get_children():
				if c is Button: jb = c
			jb.pressed.emit()
			say(seq, true)
		"set":
			# host: an option of the online screen (track, dir, laps, bots, diff, time, weather, grid, next, open) with its
			# arrows until it has the value
			var want: String = args[1]
			var ok := false
			for _i in 14:
				if _opt(args[0]) == want: ok = true; break
				# numbers: ◀ to go down, ▶ to go up; the rest: ▶ round the list
				var b := _arrow(args[0], not want.is_valid_int() or args[0] == "open" or int(want) > int(_opt(args[0])))
				if b == null: break
				b.emit_signal("pressed")
				await get_tree().process_frame
			say(seq, ok)
		"start":
			# the host's start button, whatever it says ("Start race", "Start toch (...)", "Annuleren (...)")
			var ok: bool = NetUi.start_btn.is_visible_in_tree()
			if ok: NetUi.start_btn.pressed.emit()
			say(seq, ok)
		"ready":
			var ok: bool = NetUi.ready_btn.is_visible_in_tree()
			if ok and Net.isReady() != (rest != "off"): NetUi.ready_btn.pressed.emit()
			say(seq, ok and Net.isReady() == (rest != "off"))
		"kick":
			# the host's "Eruit" button on a player's row, twice (the second click is the "Zeker?")
			var ok := false
			for _i in 2:
				var row := _player_row(rest)
				if row == null or not (row.get_child(row.get_child_count() - 1) is Button): break
				row.get_child(row.get_child_count() - 1).pressed.emit()
				await get_tree().process_frame
				ok = _i == 1
			say(seq, ok)
		"say":
			if rest.is_valid_int(): Net.say(int(rest))
			else:
				NetUi.chat_in.text = rest
				NetUi.chat_in.grab_focus()
				await _key(KEY_ENTER)
			say(seq, true)
		"key":
			await _key(OS.find_keycode_from_string(rest))
			say(seq, true)
		"follow":
			# from now on: my own car and the car of this player as shown here, frame by frame against the wall clock
			rem_name = rest
			me_track = []
			rem_track = []
			tracking = rest != "off"
			say(seq, true)
		"frames":
			# the longest frame since the last time this was asked (a hitch shows here), then start again
			say(seq, snappedf(max_frame, 0.1))
			max_frame = 0.0
		"tracks":
			say(seq, {"me": me_track, "rem": rem_track})
		"shot":
			for _i in 3: await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(rest.get_base_dir())
			get_viewport().get_texture().get_image().save_png(rest)
			say(seq, rest)
		"hostile":
			# what a broken or hostile game could send: straight onto the wire, past this game's own checks
			var room: NetRoom = Net.net.game
			var big := "x".repeat(3000)
			var deep = 1
			for _i in 200: deep = [deep]
			var junk := [{"t": "p", "p": {"st": "boem", "nick": 12, "car": {"a": 1}, "color": "rood", "k": [1, 2, "x"], "look": [1, 2], "rdy": "ja", "e": "x", "vote": 4}},
				{"t": "p", "p": {"st": [1, 2, 3], "host": true, "race": {"id": 99, "track": "polder"}, "cfg": {"track": "x"}, "pts": {"a": [1]}, "b": [[0, 0, 0, 0, 0, 0, 0]], "uid": "h4x", "off": true}},
				{"t": "p", "p": {"st": ["1", null, {}, [], 1, 1, 1, 1, 1, 1, 1]}},
				{"t": "p", "p": {"look": {"num": "veel", "rim": 5, "stripe": big, "wing": {"x": 1}, "exhaust": null}}},
				{"t": "p", "p": {"nick": big, "e": [1, big]}},
				{"t": "p", "p": deep}, {"t": "p"}, {"t": 5}, {"t": "all", "you": "h", "peers": {}}, {"t": "end"}, {"t": "kick"},
				{"t": "f", "m": {"h": {"st": null}}}, {"t": "hi", "v": 3, "tok": "een-andere-token-0123456789"}, {"p": {"nick": "x"}}, []]
			for j in junk:
				room.enet.set_target_peer(1)
				room.enet.transfer_channel = 0
				room.enet.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
				room.enet.put_packet(JSON.stringify(j).to_utf8_buffer())
			for raw in [PackedByteArray([0, 255, 254, 1, 2, 3]), "{\"t\":\"p\",\"p\":{".to_utf8_buffer(), ("[".repeat(5000)).to_utf8_buffer(), big.repeat(4).to_utf8_buffer(),
					"{\"t\":\"p\",\"p\":{\"st\":[1e999,-1e999,1,1,1,1,1,1,1,1,1]}}".to_utf8_buffer()]:
				room.enet.set_target_peer(1)
				room.enet.put_packet(raw)
			# and a flood: far more than a game ever sends
			for _i in 400:
				room.enet.set_target_peer(1)
				room.enet.put_packet(JSON.stringify({"t": "p", "p": {"nick": "Flood %d" % _i}}).to_utf8_buffer())
			say(seq, true)
		"car":
			# the car step of the online screen (Auto kiezen), pick the car (and colour), Klaar
			var ok := press("Auto kiezen")
			if ok:
				await get_tree().process_frame
				var cb = Menu.setupUI.carRadio.find(args[0])
				if cb != null: cb.pressed.emit()
				var sw = Menu.setupUI.colorRadio.find(args[1]) if args.size() > 1 else null
				if sw != null: sw.pressed.emit()
				await get_tree().process_frame
				ok = press("Klaar")
			say(seq, ok)
		"again":
			var ok := await _wait(func(): return Game.state == "over" and Game.overReady and _find("Nieuwe race") != null, 20)
			if ok: press("Nieuwe race")
			say(seq, ok)
		"quitrace":
			# pause and Stoppen: back to the menu, still in the online game
			Game.setPaused(true)
			await get_tree().process_frame
			say(seq, press("Naar lobby"))
		"drive":
			drive = rest != "off"
			say(seq, drive)
		"ts":
			ts = float(rest)
			say(seq, ts)
		"ex":
			# look into the game (debugging a scenario): one GDScript expression
			var e := Expression.new()
			var err := e.parse(rest)
			var v = e.execute([], self) if err == OK else e.get_error_text()
			say(seq, str(v))
		"track":
			# follow bot 0 frame by frame from now on
			bot_track = []
			say(seq, true)
		"hitch":
			OS.delay_msec(int(rest))
			hitches += 1
			say(seq, true)
		"esc":
			var ev := InputEventKey.new()
			ev.keycode = KEY_ESCAPE; ev.physical_keycode = KEY_ESCAPE; ev.pressed = true
			Input.parse_input_event(ev)
			await get_tree().process_frame
			var up := ev.duplicate(); up.pressed = false
			Input.parse_input_event(up)
			await get_tree().process_frame
			say(seq, true)
		"ram":
			# drive into bot 0 from behind, fast (a guest's hit on a bot the host drives)
			var b: Mover = Game.bots[0]
			var i := int(round(fposmod(b.s - 6.5, Trk.TRACK_LEN) / Trk.SPC)) % Trk.NS
			Game.resetPlayer(i, b.lat)
			Game.player.speed = b.speed + 14
			ram_until = Time.get_ticks_msec() + 1500
			bot_track = []
			say(seq, [snappedf(b.s, 0.1), snappedf(b.speed, 0.1)])
			drive = true
		"close":
			# the window's close button (Alt+F4): the same notification the game gets, then the game quits
			say(seq, true)
			get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
			get_tree().quit()
		"quit":
			say(seq, true)
			get_tree().quit()
		_:
			say(seq, "unknown " + cmd)

func _key(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k; ev.physical_keycode = k; ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := ev.duplicate(); up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame

func _card_btn(n: int) -> Control:
	var card: Node = NetUi.list.get_child(n)
	var all := []
	_buttons(card, all)
	return all[0] if not all.is_empty() else null

func report() -> Dictionary:
	var g := Game
	var r := {"name": pname, "nick": G.prefs.nick, "state": g.state, "paused": g.paused, "net": Net.net != null, "inRace": Net.inRace(),
		"host": Net.isHost(), "status": Net.status, "ui": NetUi.is_open(), "lobbyView": NetUi.lobby_box.visible,
		"track": Trk.TRACK_ID, "dir": Trk.TRACK_DIR, "laps": g.raceLaps, "car": G.settings.car, "color": G.settings.color,
		"bots": g.bots.map(func(b): return b.name + ":" + b.type + ":" + b.color),
		"bot_s": g.bots.map(func(b): return snappedf(b.s, 0.1)), "bot_fin": g.bots.map(func(b): return b.finished),
		"bot_v": g.bots.map(func(b): return snappedf(b.speed, 0.1)), "bot_push": g.bots.map(func(b): return snappedf(b.pushDv + absf(b.spin) + absf(b.lp), 0.01)),
		"me_s": snappedf(g.player.s, 0.1), "me_lap": g.player.lap, "raceDone": g.raceDone, "ft": snappedf(g.raceFinishTime, 0.01),
		"pos": [snappedf(g.player.pos.x, 0.01), snappedf(g.player.pos.z, 0.01)], "position": g.playerPosition() if g.state != "menu" else 0,
		"go_at": go_at, "grid": grid, "grid_bots": grid_bots, "goDelay": g.goDelay, "cd": g.cd,
		"over": Menu.overOv.visible, "again": Menu.overUI.againBtn.visible and Menu.overOv.visible,
		"hud": Hud.hud.visible, "nodes": get_tree().get_node_count(),
		"lobbies": Net.lobbies().map(func(l): return {"name": l.get("name"), "ip": l.get("ip"), "track": l.get("track"), "n": l.get("n"), "open": l.get("open"), "race": l.get("race"), "deaf": l.get("deaf", false), "v": l.get("v")}),
		"help": NetUi.help.text if NetUi.help.is_visible_in_tree() else "", "sweeps": Net.lan.sweeps, "searching": Net.lan.searching(), "selftest": Net.lan.selftest,
		"recent": Net.recentIps(), "banner": NetUi.banner_lbl.text if NetUi.banner.visible else "", "specbar": NetUi.spec_lbl.text if NetUi.specbar.visible else "",
		"said": said, "settings": {"track": G.settings.track, "dir": G.settings.dir, "laps": G.settings.laps, "bots": G.settings.bots, "mode": G.settings.mode, "time": G.settings.time, "weather": G.settings.weather},
		"mapdots": Net.mapDots().size(), "raceTime": snappedf(g.raceTime, 0.01), "speed": snappedf(g.player.speed, 0.1), "mode": g.mode,
		"cards": NetUi.list.get_children().map(func(c): return c.find_children("*", "Label", true, false).map(func(x): return x.text)),
		"focus": str(get_viewport().gui_get_focus_owner().get_path()) if get_viewport().gui_get_focus_owner() != null else "",
		"list_n": NetUi.list.get_child_count(), "bot_track": bot_track}
	if Net.net != null:
		var nn: Dictionary = Net.net
		r.me = nn.game.me
		r.raceId = nn.raceId
		r.order = nn.order
		r.seen = nn.seen
		r.cfg = Net.cfg()
		r.countdown = snappedf(Net.countdown(), 0.01)
		r.ready = Net.isReady()
		r.pts = Net.standings()
		r.res = nn.res
		r.chat = nn.chat
		r.spec = Net.specName() if Net.spectating() else ""
		r.watch = nn.watch
		r.canWatch = Net.canWatch()
		r.reconn = nn.game.is_reconnecting()
		r.mig = nn.mig != null
		r.open = nn.open
		r.up = nn.game.up_bps
		r.down = nn.game.down_bps
		r.dropped = nn.game.dropped
		r.ping = nn.game.my_ping()
		r.diag = NetUi.ip_note.text if NetUi.ip_note.is_visible_in_tree() else ""
		r.race_ui = [NetUi.race_lbl.text, NetUi.race_sub.text] if NetUi.race_lbl.is_visible_in_tree() else []
		r.start_ui = NetUi.start_btn.text if NetUi.start_btn.is_visible_in_tree() else ""
		r.over_ui = NetUi.over_info.text if NetUi.over_box != null and NetUi.over_box.is_visible_in_tree() else ""
		r.over_btns = NetUi.over_btns.get_children().filter(func(c): return not c.is_queued_for_deletion()).map(func(c): return _text(c)) if NetUi.over_box != null and NetUi.over_box.is_visible_in_tree() else []
		r.rows_ui = Menu.overUI.results.get_children().filter(func(c): return not c.is_queued_for_deletion()).map(func(c): return c.find_children("*", "Label", true, false).map(func(x): return x.text)) if Menu.overOv.visible else []
		var rem := []
		for rm in Net.net.remotes.values():
			rem.append({"peer": rm.peer, "name": rm.name, "car": rm.carId, "color": rm.color, "host": rm.host, "has_st": rm.st != null, "rdy": rm.rdy, "off": rm.off, "uid": rm.uid,
				"look": rm.lookD, "carlook": rm.car.get("look", {}) if rm.car != null else {}, "q": Net.quality(rm.peer), "tag": rm.tag != null and rm.tag.visible and rm.tag.text == rm.name, "vote": rm.vote, "vdist": snappedf(rm.vdist, 0.1),
				"meshes": rm.car.g.find_children("*", "MeshInstance3D", true, false).size() if rm.car != null else 0,
				"visible": rm.car != null and rm.car.g.visible, "s": rm.st[5] if rm.st != null else -1, "lap": rm.lap, "done": rm.done, "ft": rm.ft,
				"x": rm.car.g.position.x if rm.car != null else 0.0, "z": rm.car.g.position.z if rm.car != null else 0.0})
		r.remotes = rem
		var pl := []
		for c in NetUi.players.get_children():
			if c.is_queued_for_deletion(): continue
			pl.append(c.get_child(1).text + " | " + c.get_child(4).text)
		r.players_ui = pl
	if g.state == "over" or g.state == "replay":
		r.results = g.resultRows.map(func(x): return {"name": x.name, "finished": x.finished, "ft": snappedf(x.ft, 0.01), "me": x.get("me", false)})
	return r

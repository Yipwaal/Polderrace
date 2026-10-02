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
var ts := 1.0                      ## Engine.time_scale while racing (the countdown runs at real speed)

func say(seq: String, v) -> void:
	print("NET %s %s" % [seq, JSON.stringify(v)])

func _ready() -> void:
	var a := {"name": "p1", "ctl": "", "nick": "", "car": "hatch", "ts": "1", "color": ""}
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
	G.use_store("user://test-netctl-%s.json" % pname, {"polderrace3d-garage": {"owned": owned}})
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

## the player's hands: gas, and steering keys like the autopilot of test_laps
func _drive() -> void:
	var g := Game
	for k in ["KeyW", "KeyA", "KeyD"]: g.keysDown.erase(k)
	if not drive or g.paused or not (g.state == "countdown" or g.state == "racing"): return
	if Trk.NS <= 1: return
	g.keysDown["KeyW"] = true
	var th := Trk.heading_of(Trk.T[g.player.idx])
	var df := fposmod(th - g.player.heading + PI, TAU) - PI
	var st := clampf(-df * 3 - g.player.lat * 0.15, -1, 1)
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

## one row of the online screen's option rows (Baan, Ronden, Bots): its ▶ button
func _arrow(label: String, right := true) -> Control:
	var all := []
	_buttons(NetUi, all)
	for b in all:
		var row: Node = b.get_parent()
		if row is HBoxContainer and row.get_child_count() >= 4 and row.get_child(0) is Label and row.get_child(0).text == label:
			if _text(b) == ("▶" if right else "◀"): return b
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
			# host: Baan / Ronden / Bots with the arrows of the online screen until it has the value
			var label: String = {"track": "Baan", "laps": "Ronden", "bots": "Bots"}[args[0]]
			var want: String = args[1]
			var ok := false
			for _i in 14:
				if str(G.settings[args[0]]) == want: ok = true; break
				# numbers: ◀ to go down, ▶ to go up; tracks: ▶ round the list
				var b := _arrow(label, not want.is_valid_int() or int(want) > int(G.settings[args[0]]))
				if b == null: break
				b.emit_signal("pressed")
				await get_tree().process_frame
			say(seq, ok)
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
			say(seq, press("Naar menu"))
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
		"lobbies": Net.lobbies().map(func(l): return {"name": l.get("name"), "ip": l.get("ip"), "track": l.get("track"), "n": l.get("n"), "open": l.get("open"), "race": l.get("race")}),
		"cards": NetUi.list.get_children().map(func(c): return c.find_children("*", "Label", true, false).map(func(x): return x.text)),
		"focus": str(get_viewport().gui_get_focus_owner().get_path()) if get_viewport().gui_get_focus_owner() != null else "",
		"list_n": NetUi.list.get_child_count(), "bot_track": bot_track}
	if Net.net != null:
		r.me = Net.net.game.me
		r.raceId = Net.net.raceId
		r.order = Net.net.order
		r.seen = Net.net.seen
		var rem := []
		for rm in Net.net.remotes.values():
			rem.append({"peer": rm.peer, "name": rm.name, "car": rm.carId, "color": rm.color, "host": rm.host, "has_st": rm.st != null,
				"visible": rm.car != null and rm.car.g.visible, "s": rm.st[5] if rm.st != null else -1, "lap": rm.lap, "done": rm.done, "ft": rm.ft,
				"x": rm.car.g.position.x if rm.car != null else 0.0, "z": rm.car.g.position.z if rm.car != null else 0.0})
		r.remotes = rem
		var pl := []
		for c in NetUi.players.get_children():
			if c.is_queued_for_deletion(): continue
			pl.append(c.get_child(1).text)
		r.players_ui = pl
	if g.state == "over" or g.state == "replay":
		r.results = g.resultRows.map(func(x): return {"name": x.name, "finished": x.finished, "ft": snappedf(x.ft, 0.01), "me": x.get("me", false)})
	return r

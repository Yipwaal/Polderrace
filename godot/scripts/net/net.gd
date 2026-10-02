extends Node
## Autoload "Net": online racing, ported from the HTML game's net code (netEnter, netSyncRemotes, netHostStart, netBegin,
## netPlace, netKick, netTick, netRemoteProg, netCollide) on top of NetRoom (ENet) and LanDiscovery (games on the local
## network show up by themselves: no codes). Presence per game: nick, car, color, host, st, b, k, race — as in the HTML.
## The host decides: the race (track, laps, time, weather, bots, start order) and the bots' positions (b); guests send
## their own position (st) and their kicks against bots (k), which the host applies.

signal changed                     ## lobby list / players / status changed (UI refresh)

var net = null                     ## Dictionary while in a game (JS `net`), null otherwise
var lan: LanDiscovery
var status := ""
var _game_id := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	lan = LanDiscovery.new()
	add_child(lan)
	lan.lobbies_changed.connect(func(): changed.emit())
	if not G.prefs.get("nick", ""):
		G.prefs.nick = "Racer %d" % (100 + randi() % 900)
		G.savePrefs()

func netStatus(t: String) -> void:
	status = t
	changed.emit()

# ------------------------------------------------------------------ lobby (LAN)
func browse() -> void:
	if net == null:
		lan.browse()

func stop_browse() -> void:
	if net == null or not net.host:
		lan.stop()

func lobbies() -> Array:
	var out := []
	for k in lan.lobbies:
		var l: Dictionary = lan.lobbies[k]
		if l.get("open", false):
			out.append(l)
	return out

func _lobby_info() -> Dictionary:
	var S := G.settings
	return {"pr": 1, "id": _game_id, "name": str(G.prefs.nick) + "s game", "track": TrackDefs.TRACKS[S.track].name + (" (omgekeerd)" if S.dir == "rev" else ""),
		"n": 1 + (net.remotes.size() if net != null else 0), "max": 8, "open": net != null and not net.inRace, "port": NetRoom.PORT}

func netCreate() -> void:
	_game_id = "g%d" % (Time.get_ticks_msec() + randi() % 10000)
	var room := NetRoom.new()
	add_child(room)
	var err := room.start_host(G.prefs.nick)
	if err != OK:
		room.queue_free()
		netStatus("Hosten lukte niet (poort %d bezet?)." % NetRoom.PORT)
		return
	lan.serve(_lobby_info)
	netEnter(room, true)

func netJoin(address: String) -> void:
	lan.stop()
	var room := NetRoom.new()
	add_child(room)
	if room.start_guest(address) != OK:
		room.queue_free()
		netStatus("Meedoen lukte niet.")
		browse()
		return
	netStatus("Verbinden met %s…" % address)
	netEnter(room, false)
	# no answer within 6 s: give up
	get_tree().create_timer(6.0).timeout.connect(func():
		if net != null and net.game == room and not room.is_connected_room():
			netLeave()
			netStatus("Geen verbinding met %s. Staat de host aan, en zit je op hetzelfde netwerk?" % address))

func netEnter(room: NetRoom, host: bool) -> void:
	if net != null:
		netLeave()
	net = {"game": room, "host": host, "inRace": false, "remotes": {}, "lastSend": 0, "raceId": 0, "kicks": [], "kickSeq": 0, "seen": {}, "botDefs": null, "order": []}
	room.presence({"nick": G.prefs.nick, "car": G.settings.car, "color": G.settings.color, "host": host, "st": null, "b": null, "k": [], "race": null})
	room.peers_changed.connect(func():
		netSyncRemotes()
		changed.emit())
	room.closed.connect(func(reason: String):
		var was_racing: bool = net != null and net.inRace
		netLeave()
		if was_racing and Game.state != "menu": Game.toMenu(-1)
		netStatus("De host heeft de game gesloten." if reason == "end" else ("De game is vol." if reason == "full" else "Verbinding met de host verbroken.")))
	if host:
		netStatus("Je bent de host. Spelers op hetzelfde netwerk zien je game nu in hun lijst.")
	else:
		netStatus("Je zit in de game. Wacht tot de host start.")
	changed.emit()

func netLeave() -> void:
	if net == null:
		return
	var g: NetRoom = net.game
	for r in net.remotes.values():
		if r.car != null: r.car.g.queue_free()
	net = null
	g.leave()
	# the room says goodbye to the guests for a moment before it closes (NetRoom.leave)
	get_tree().create_timer(0.6, true, false, true).timeout.connect(g.queue_free)
	lan.stop()
	changed.emit()

func netSyncRemotes() -> void:
	if net == null:
		return
	var seen := {}
	for p in net.game.peers():
		if p.sameTab: continue
		var pr: Dictionary = p.presence if p.presence is Dictionary else {}
		if not pr.get("nick", ""): continue
		seen[p.peer] = true
		var r = net.remotes.get(p.peer)
		if r == null:
			r = {"peer": p.peer, "car": null, "carId": null, "color": null, "st": null, "prev": null, "t": 0, "lap": 0, "done": false, "ft": 0.0, "upd": 0, "name": "", "host": false}
			net.remotes[p.peer] = r
		r.name = str(pr.nick).substr(0, 24)
		r.host = bool(pr.get("host", false))
		if r.carId != pr.get("car") or r.color != pr.get("color"):
			if r.car != null: r.car.g.queue_free()
			r.carId = pr.car if Cars.CARS.has(pr.get("car", "")) else "gt"
			r.color = pr.get("color", "#ffffff")
			r.car = CarKit.buildCar(r.carId, Color(r.color))
			r.car.g.visible = false
			get_tree().current_scene.add_child(r.car.g)
	for k in net.remotes.keys():
		if not seen.has(k):
			var r: Dictionary = net.remotes[k]
			if r.car != null: r.car.g.queue_free()
			net.remotes.erase(k)

## the host starts a race for everyone in the game (JS netHostStart)
func netHostStart() -> void:
	if net == null or not net.host: return
	var S := G.settings
	var defs := Game.makeBotDefs(mini(int(S.bots), 5))
	net.botDefs = defs
	net.order = [net.game.me] + net.remotes.keys()
	net.order.sort()
	net.order.erase("h")
	net.order.push_front("h")
	var race := {"id": Time.get_ticks_msec(), "track": S.track, "dir": S.dir, "laps": S.laps, "time": S.time, "weather": S.weather, "bots": defs, "order": net.order}
	net.game.presence({"race": race})
	net.raceId = race.id
	netBegin(race)

func netBegin(race: Dictionary) -> void:
	net.inRace = true
	net.botDefs = race.bots
	net.order = race.order
	var S := G.settings
	S.track = race.track; S.dir = "rev" if race.dir == "rev" else "fwd"; S.laps = int(race.laps); S.time = race.time; S.weather = race.weather
	S.bots = race.bots.size(); S.mode = "race"; S.grid = "back"
	if Trk.TRACK_ID != race.track or Trk.TRACK_DIR != S.dir:
		get_tree().current_scene.load_track(race.track)
	if Env.me != null: Env.me.apply(race.time, race.weather)
	for r in net.remotes.values():
		r.done = false; r.lap = 0; r.st = null
	if Game.state == "over": Game.overReady = true
	if Game.state == "menu" or Game.state == "over":
		Game.startRace()
	changed.emit()

## put me on the grid behind the bots, in the host's start order (JS netPlace)
func netPlace() -> void:
	var k: int = maxi(0, net.order.find(net.game.me))
	var g := Game.gridSlot(Game.bots.size() + k)
	Game.resetPlayer(int(round(g.s / Trk.SPC)) % Trk.NS, g.lat)
	Game.snapCamera()

func netKick(i: int, x: float, z: float, s: float) -> void:
	net.kickSeq += 1
	net.kicks.append({"q": net.kickSeq, "i": i, "x": snappedf(x, 0.001), "z": snappedf(z, 0.001), "s": snappedf(s, 0.001)})
	if net.kicks.size() > 8: net.kicks.pop_front()

func _process(_dt: float) -> void:
	netTick()

func netTick() -> void:
	if net == null: return
	var now := Time.get_ticks_msec()
	for p in net.game.peers():
		if p.sameTab: continue
		var pr: Dictionary = p.presence if p.presence is Dictionary else {}
		var r = net.remotes.get(p.peer)
		if r == null: continue
		var race = pr.get("race")
		if not net.host and pr.get("host", false) and race is Dictionary and race.id != net.raceId:
			net.raceId = race.id
			# joined later: wait for the next race
			if not (race.get("order") is Array) or race.order.has(net.game.me):
				netBegin(race)
		var st = pr.get("st")
		if st is Array and p.updatedAt != r.upd:
			r.upd = p.updatedAt; r.prev = r.st; r.st = st; r.t = now; r.lap = int(st[6])
			if st[7] and not r.done:
				r.done = true; r.ft = float(st[8])
		var b = pr.get("b")
		if not net.host and pr.get("host", false) and net.inRace and b is Array:
			for i in b.size():
				if i >= Game.bots.size(): break
				var q: Array = b[i]
				var bot: Mover = Game.bots[i]
				bot.s = q[0]; bot.lat = q[1]; bot.speed = q[2]; bot.lap = int(q[3]); bot.yawOff = q[4]; bot.finished = bool(q[5]); bot.finishTime = q[6] if q[6] else 0.0
		var kicks = pr.get("k")
		if net.host and kicks is Array:
			var last: int = net.seen.get(p.peer, 0)
			for kq in kicks:
				if int(kq.q) > last:
					var bot = Game.bots[int(kq.i)] if int(kq.i) < Game.bots.size() else null
					if bot != null: Game.kickOther(bot, kq.x, kq.z, kq.s)
					net.seen[p.peer] = int(kq.q)
	if not net.inRace: return
	if now - net.lastSend > 50:
		net.lastSend = now
		var pl := Game.player
		var st := [snappedf(pl.pos.x, 0.01), snappedf(pl.y, 0.01), snappedf(pl.pos.z, 0.01), snappedf(pl.heading, 0.001), snappedf(pl.speed, 0.01),
			snappedf(pl.s, 0.1), pl.lap, 1 if Game.raceDone else 0, snappedf(Game.raceFinishTime, 0.01)]
		var patch := {"st": st}
		if net.host:
			var bs := []
			for bot in Game.bots:
				bs.append([snappedf(bot.s, 0.01), snappedf(bot.lat, 0.01), snappedf(bot.speed, 0.01), bot.lap, snappedf(bot.yawOff, 0.001), 1 if bot.finished else 0, snappedf(bot.finishTime, 0.01)])
			patch.b = bs
		else:
			patch.k = net.kicks.duplicate()
		net.game.presence(patch)
	for r in net.remotes.values():
		if r.car == null: continue
		if r.st == null:
			r.car.g.visible = false; continue
		r.car.g.visible = true
		if r.car.get("beam") != null: r.car.beam.visible = Game.lampsOn
		var a: Array = r.prev if r.prev != null else r.st
		var b: Array = r.st
		var k := clampf((now - r.t) / 50.0, 0, 1.6)
		var f := minf(1, k)
		var ex := maxf(0, k - 1) * 0.05
		r.car.g.position = Vector3(a[0] + (b[0] - a[0]) * f + sin(b[3]) * b[4] * ex, a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f + cos(b[3]) * b[4] * ex)
		r.car.g.rotation = Vector3(0, MathX.lerp_angle_(a[3], b[3], f), 0)
		for w in r.car.wheels: w.spin.rotation.x += Game.wheelSpin(b[4], w.r, 1.0 / 60)

func netRemoteProg(r: Dictionary) -> float:
	if r.done: return (Game.raceLaps + 2) * Trk.TRACK_LEN + 100000 - r.ft * 10
	return Game.progressOf(r.lap, r.st[5], false, 0) if r.st != null else -1e9

## bump into the other players' cars (each player handles his own side of a hit)
func netCollide() -> void:
	if net == null or not net.inRace: return
	for r in net.remotes.values():
		if r.car == null or r.st == null: continue
		var g: Node3D = r.car.g
		var h := g.rotation.y
		var v: float = r.st[4]
		var co: float = r.car.get("off", 0.0)
		var B := {"x": g.position.x + sin(h) * co, "z": g.position.z + cos(h) * co, "h": h, "len": r.car.len, "wid": r.car.wid, "rc": r.car.get("rc", 0.0),
			"m": Cars.CARS[r.carId].mass if Cars.CARS.has(r.carId) else 1.3, "vx": sin(h) * v, "vz": cos(h) * v}
		var A := Game.playerBody()
		var ct = Game.pairContact(A, B)
		if ct == null: continue
		var pc := minf(0.04, maxf(0, ct.pen - 0.03) * 0.4)
		Game.player.pos.x += ct.nx * pc
		Game.player.pos.z += ct.nz * pc
		var im = Game.pairImpulse(Game.playerBody(), B, ct)
		if im == null: continue
		var fx := sin(Game.player.heading); var fz := cos(Game.player.heading)
		var vx: float = A.vx + im.FAx / A.m
		var vz: float = A.vz + im.FAz / A.m
		Game.player.speed = vx * fx + vz * fz
		Game.player.slide = Vector2(vx - fx * Game.player.speed, vz - fz * Game.player.speed)
		Game.player.spin = clampf(Game.player.spin + Game.yawKick(im.sA, Game.GRIP * Game.gripFactor()), -6, 6)
		Game.hitFx(im.j, true)

## after the race / back in the menu: clear the race state, show the game as open again
func netAfterRace() -> void:
	if net == null: return
	net.inRace = false
	for r in net.remotes.values():
		if r.car != null: r.car.g.visible = false
	net.game.presence({"st": null, "b": null})
	changed.emit()

# ------------------------------------------------------------------ helpers for Game
func inRace() -> bool:
	return net != null and net.inRace

func isHost() -> bool:
	return net != null and net.host

func aheadCount(me: float) -> int:
	if not inRace(): return 0
	var n := 0
	for r in net.remotes.values():
		if r.st != null and netRemoteProg(r) > me: n += 1
	return n

func racers() -> int:
	if not inRace(): return 0
	var n := 0
	for r in net.remotes.values():
		if r.st != null: n += 1
	return n

## extra result rows for the other players (JS resultOrder)
func resultRows() -> Array:
	var rows := []
	if not inRace(): return rows
	for r in net.remotes.values():
		if r.st != null:
			rows.append({"name": r.name, "car": Cars.CARS[r.carId].name, "finished": r.done, "ft": r.ft, "out": false, "elimPos": 0, "prog": netRemoteProg(r), "best": 0})
	return rows

# ------------------------------------------------------------------ internet: UPnP port forwarding (optional)
var upnp_status := ""

func open_internet() -> void:
	upnp_status = "Router vragen om poort %d open te zetten…" % NetRoom.PORT
	changed.emit()
	var th := Thread.new()
	th.start(func():
		var u := UPNP.new()
		var err := u.discover(2000, 2)
		var msg: String
		if err != OK or u.get_gateway() == null or not u.get_gateway().is_valid_gateway():
			msg = "Geen router met UPnP gevonden. Zet poort %d (UDP) zelf open in je router." % NetRoom.PORT
		elif u.add_port_mapping(NetRoom.PORT, NetRoom.PORT, "Polderrace", "UDP") != UPNP.UPNP_RESULT_SUCCESS:
			msg = "De router wilde poort %d niet openzetten. Zet hem zelf open (UDP)." % NetRoom.PORT
		else:
			msg = "Via internet bereikbaar op %s (poort %d)." % [u.query_external_address(), NetRoom.PORT]
		call_deferred("_upnp_done", msg, th))

func _upnp_done(msg: String, th: Thread) -> void:
	th.wait_to_finish()
	upnp_status = msg
	changed.emit()

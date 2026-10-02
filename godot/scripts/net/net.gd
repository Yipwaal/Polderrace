extends Node
## Autoload "Net": online racing, ported from the HTML game's net code (netEnter, netSyncRemotes, netHostStart, netBegin,
## netPlace, netKick, netTick, netRemoteProg, netCollide) on top of NetRoom (ENet) and LanDiscovery (games on the local
## network show up by themselves: no codes). Presence per game: nick, car, color, host, st, b, k, race — as in the HTML.
## The host decides: the race (track, laps, time, weather, bots, start order) and the bots' positions (b); guests send
## their own position (st) and their kicks against bots (k), which the host applies.
## st and the kicks carry the race id, so a late packet of an earlier race never counts in the next one.

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

## the window closes: say goodbye right away, so the others do not wait for a time-out (JS pagehide)
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		netLeave()

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

## back in the list after a game: look for games again while the online screen is open
func _relist() -> void:
	if NetUi.is_open(): browse()

## every game on this network; the list shows which ones are full or racing
func lobbies() -> Array:
	return lan.lobbies.values()

## "Yips game", "Kees' game", "Anna's game" (Dutch possessive)
static func gameName(nick: String) -> String:
	var n := nick.strip_edges()
	if n == "": return "Game"
	var last := n.right(1).to_lower()
	if last in ["s", "x", "z"]: return n + "' game"
	if last in ["a", "i", "o", "u", "y"] or last.is_valid_int(): return n + "'s game"
	return n + "s game"

func _lobby_info() -> Dictionary:
	var S := G.settings
	var n: int = 1 + (net.remotes.size() if net != null else 0)
	return {"pr": 1, "v": NetRoom.PROTO, "id": _game_id, "name": gameName(str(G.prefs.nick)),
		"track": TrackDefs.TRACKS[S.track].name + (" (omgekeerd)" if S.dir == "rev" else ""),
		"n": n, "max": NetRoom.MAX_GUESTS + 1, "open": net != null and n <= NetRoom.MAX_GUESTS, "race": net != null and net.inRace, "port": NetRoom.PORT}

func netCreate() -> void:
	if net != null: return
	# a game we just left may still be saying goodbye on the port
	for c in get_children():
		if c is NetRoom: c.close_now()
	_game_id = "%08x%08x" % [randi(), randi()]
	var room := NetRoom.new()
	add_child(room)
	var err := room.start_host(G.prefs.nick)
	if err != OK:
		room.queue_free()
		netStatus("Hosten lukte niet: poort %d is bezet. Is er op deze pc al iemand host?" % NetRoom.PORT)
		return
	var listed := lan.serve(_lobby_info)
	netEnter(room, true)
	if listed != OK:
		netStatus("Je bent de host, maar je game staat niet in de lijst van anderen (poort %d is bezet). Meedoen kan via je IP-adres." % LanDiscovery.DISCO_PORT)

func netJoin(address: String) -> void:
	if net != null: return
	# "192.168.1.20:47810" works too: the port is always the same
	var addr := address.strip_edges()
	if addr.count(":") == 1: addr = addr.get_slice(":", 0)
	lan.stop()
	var room := NetRoom.new()
	add_child(room)
	# a typo like "192.168.1" is no address (a PC name like "YIP-PC" is fine)
	var typo := addr.replace(".", "").is_valid_int() and not addr.is_valid_ip_address()
	if addr == "" or typo or room.start_guest(addr) != OK:
		room.queue_free()
		netStatus("Meedoen lukte niet: '%s' is geen IP-adres." % address.strip_edges())
		_relist()
		return
	netEnter(room, false)
	net.addr = addr
	netStatus("Verbinden met %s…" % addr)
	# no answer within 6 s: give up (the room may be gone by then: compare ids, not the freed object)
	var rid := room.get_instance_id()
	get_tree().create_timer(6.0, true, false, true).timeout.connect(func():
		if net != null and net.game.get_instance_id() == rid and not net.game.is_connected_room():
			_onClosed(net.game, "fail"))

func netEnter(room: NetRoom, host: bool) -> void:
	if net != null:
		netLeave()
	net = {"game": room, "host": host, "inRace": false, "remotes": {}, "lastSend": 0, "raceId": 0, "kicks": [], "kickSeq": 0, "seen": {},
		"botDefs": null, "order": [], "startAt": 0, "botUpd": -1, "botAt": 0, "sentCar": G.settings.car + G.settings.color, "addr": "", "hostGo": -1e12, "botErr": {}, "botHold": {}}
	room.presence({"nick": G.prefs.nick, "car": G.settings.car, "color": G.settings.color, "host": host, "st": null, "b": null, "k": [], "race": null})
	room.peers_changed.connect(func():
		if net != null and net.game == room and netSyncRemotes(): changed.emit())
	room.closed.connect(func(reason: String): _onClosed(room, reason))
	room.joined.connect(func():
		if net != null and net.game == room: netStatus("Je zit in de game van %s. Wacht tot de host start." % room.hostNick))
	if host:
		netStatus("Je bent de host. Spelers op hetzelfde netwerk zien je game nu in hun lijst.")
	changed.emit()

## the game is over for us: the host closed it, it is full, or the connection is gone
func _onClosed(room: NetRoom, reason: String) -> void:
	if net == null or net.game != room: return
	var t: String = {"end": "De host heeft de game gesloten.", "full": "De game zit vol: maximaal %d spelers." % (NetRoom.MAX_GUESTS + 1),
		"version": "De host speelt een andere versie van Polderrace. Zorg dat jullie dezelfde versie hebben.",
		"fail": "Geen verbinding met %s. Is de game er nog, en zit je op hetzelfde netwerk? Anders houdt de firewall van de host het spel misschien tegen." % net.get("addr", "de host")
		}.get(reason, "De verbinding met de host is weggevallen.")
	var racing: bool = Game.state != "menu"
	netLeave()
	if racing:
		# from the race, its results or the replay back to the online screen, where the message is
		Game.toMenu(-1)
		Menu.netOpen()
	else:
		_relist()
	netStatus(t + (" Je bent uit de game." if reason == "end" or reason == "lost" else ""))
	if not NetUi.is_open(): Hud.showToast(t)

func netLeave() -> void:
	if net == null:
		return
	var g: NetRoom = net.game
	for r in net.remotes.values():
		if r.car != null: r.car.g.queue_free()
	net = null
	g.leave()
	close_internet()
	# the room says goodbye to the guests for a moment before it closes (NetRoom.leave)
	get_tree().create_timer(0.6, true, false, true).timeout.connect(g.queue_free)
	lan.stop()
	changed.emit()

## the other players' cars, from the presence; true when someone came, went or changed name or car (the screen updates)
func netSyncRemotes() -> bool:
	if net == null:
		return false
	var seen := {}
	var news := false
	for p in net.game.peers():
		if p.sameTab: continue
		var pr: Dictionary = p.presence if p.presence is Dictionary else {}
		if not pr.get("nick", ""): continue
		seen[p.peer] = true
		var r = net.remotes.get(p.peer)
		if r == null:
			r = {"peer": p.peer, "car": null, "carId": null, "want": null, "color": null, "st": null, "prev": null, "t": 0, "lap": 0, "done": false,
				"ft": 0.0, "upd": 0, "name": "", "host": false, "out": false}
			net.remotes[p.peer] = r
			news = true
			if net.host: netStatus("%s doet mee." % str(pr.nick).substr(0, 24))
		var nm := str(pr.nick).substr(0, 24)
		var hs := bool(pr.get("host", false))
		if nm != r.name or hs != r.host:
			r.name = nm; r.host = hs; news = true
		if r.want != pr.get("car") or r.color != pr.get("color"):
			if r.car != null: r.car.g.queue_free()
			r.want = pr.get("car")
			r.carId = pr.car if Cars.CARS.has(str(pr.get("car", ""))) else "gt"
			r.color = pr.get("color", "#ffffff")
			r.car = CarKit.buildCar(r.carId, Color(str(r.color)) if Color.html_is_valid(str(r.color)) else Color.WHITE)
			r.car.g.visible = false
			get_tree().current_scene.add_child(r.car.g)
			news = true
	for k in net.remotes.keys():
		if not seen.has(k):
			var r: Dictionary = net.remotes[k]
			if r.car != null: r.car.g.queue_free()
			net.remotes.erase(k)
			news = true
			var t := "%s heeft de game verlaten." % r.name
			netStatus(t)
			if Game.state != "menu": Hud.showToast(t)
	return news

## the host starts a race for everyone in the game (JS netHostStart)
func netHostStart() -> void:
	if net == null or not net.host: return
	var S := G.settings
	var defs := Game.makeBotDefs(mini(int(S.bots), 5))
	net.botDefs = defs
	var guests: Array = net.remotes.keys()
	guests.sort()
	net.order = ["h"] + guests
	var race := {"id": Time.get_ticks_msec(), "track": S.track, "dir": S.dir, "laps": S.laps, "time": S.time, "weather": S.weather, "bots": defs, "order": net.order}
	net.game.presence({"race": race})
	net.raceId = race.id
	netBegin(race)

func netBegin(race: Dictionary) -> void:
	net.startAt = Time.get_ticks_msec()
	net.hostGo = -1e12
	net.botErr = {}
	net.botHold = {}
	net.inRace = true
	net.botDefs = race.bots
	net.order = race.order
	var S := G.settings
	# a career event or a championship the player had open makes way for the host's race (JS leaveChampMode)
	if G.careerEv != null:
		G.careerEv = null
		if G.careerPrev != null:
			S.merge(G.careerPrev, true)
			G.careerPrev = null
	if Champ.champ != null and Champ.champ.get("active", false):
		Champ.champ.active = false
		Champ.saveChamp()
	if Champ.champPrevDiff != null:
		S.diff = Champ.champPrevDiff
		Champ.champPrevDiff = null
	S.track = race.track; S.dir = "rev" if race.dir == "rev" else "fwd"; S.laps = int(race.laps); S.time = race.time; S.weather = race.weather
	S.bots = race.bots.size(); S.mode = "race"; S.grid = "back"
	if Trk.TRACK_ID != race.track or Trk.TRACK_DIR != S.dir:
		get_tree().current_scene.load_track(race.track)
	if Env.me != null: Env.me.apply(race.time, race.weather)
	for r in net.remotes.values():
		r.done = false; r.lap = 0; r.st = null; r.prev = null; r.out = false
	# the host decides when the race starts: results, replay, pause or a race still under way make way for it
	if Game.state != "menu":
		if Rep.rp != null: Rep.replayClose()
		if Game.paused: Game.setPaused(false)
		Game.state = "over"
		Game.overReady = true
	Game.startRace()
	# the same wait for green on every PC (the lights follow the time since the start, see netTick)
	Game.goDelay = 0.4 + float(int(race.id) % 800) / 1000.0
	_sendCar()
	changed.emit()

## the others see the car I drive (after the car step, or when the race swapped in a car I own)
func _sendCar() -> void:
	if net == null: return
	var c: String = G.settings.car + G.settings.color
	if c != net.sentCar:
		net.sentCar = c
		net.game.presence({"car": G.settings.car, "color": G.settings.color})

## the car step of an online game is done (JS netCarDone): back to the online screen, the others see the new car
func netCarDone() -> void:
	Menu.menuFlow = "quick"
	Menu.showMenu(-1)
	Menu.homePanel("play")
	Menu.netOpen()
	_sendCar()
	changed.emit()

## put me on the grid behind the bots, in the host's start order (JS netPlace)
func netPlace() -> void:
	var k: int = maxi(0, net.order.find(net.game.me))
	var g := Game.gridSlot(Game.bots.size() + k)
	Game.resetPlayer(int(round(g.s / Trk.SPC)) % Trk.NS, g.lat)
	Game.snapCamera()

func netKick(i: int, x: float, z: float, s: float) -> void:
	# this game already pushed its copy of the bot; the host's next positions do not have the push yet: skip them a moment
	net.botHold[i] = Time.get_ticks_msec() + 200
	net.kickSeq += 1
	net.kicks.append({"q": net.kickSeq, "r": net.raceId, "i": i, "x": snappedf(x, 0.001), "z": snappedf(z, 0.001), "s": snappedf(s, 0.001)})
	if net.kicks.size() > 8: net.kicks.pop_front()

## guests: the host's latest bot positions are recent (in between, Game lets the bots roll on)
func botsFresh() -> bool:
	return net != null and Time.get_ticks_msec() - int(net.botAt) < 300

## a remote car on the road: in this race, not gone back to the menu, and heard from lately (not closed or hanging)
func _onRoad(r: Dictionary, now: int) -> bool:
	return r.car != null and r.st != null and not r.out and now - int(r.t) < 1500

func _process(_dt: float) -> void:
	netTick()

func netTick() -> void:
	if net == null: return
	var now := Time.get_ticks_msec()
	var rid := int(net.raceId)
	for p in net.game.peers():
		if p.sameTab: continue
		var pr: Dictionary = p.presence if p.presence is Dictionary else {}
		var r = net.remotes.get(p.peer)
		if r == null: continue
		var race = pr.get("race")
		if not net.host and pr.get("host", false) and race is Dictionary and int(race.get("id", 0)) != rid:
			net.raceId = race.id
			rid = int(race.id)
			if not (race.get("order") is Array) or race.order.has(net.game.me):
				netBegin(race)
			elif not net.inRace:
				# joined during a race: wait for the next one
				netStatus("Er is een race bezig. Je doet mee vanaf de volgende race.")
		var st = pr.get("st")
		if st is Array and st.size() > 9 and int(st[9]) == rid:
			if p.updatedAt != r.upd and not r.out:
				r.upd = p.updatedAt; r.prev = r.st; r.st = st; r.t = now; r.lap = int(st[6])
				if st[7] and not r.done:
					r.done = true; r.ft = float(st[8])
				if r.host and st.size() > 10:
					# how long ago the host started this race (a start message that had to be sent again came late)
					net.hostGo = float(st[10]) * 1000.0 - now
		elif st == null and r.st != null and net.inRace and not r.out:
			# back to the menu during the race: the car goes; who finished keeps his place in the results
			r.out = true
			if not r.done: r.st = null
		var b = pr.get("b")
		if not net.host and pr.get("host", false) and net.inRace and b is Array and p.updatedAt != net.botUpd and st is Array and st.size() > 9 and int(st[9]) == rid:
			# a new snapshot of the host's bots (only once: in between they roll on, see botsFresh)
			net.botUpd = p.updatedAt
			net.botAt = now
			var L := Trk.TRACK_LEN
			for i in b.size():
				if i >= Game.bots.size(): break
				if now < int(net.botHold.get(i, 0)): continue
				var q: Array = b[i]
				var bot: Mover = Game.bots[i]
				# a small difference with where the bot rolled on to here is smoothed out over a few frames (the host's
				# frames are not evenly spaced either); a big one (a crash, a reset) is taken over at once
				var es := Trk.wrapD(float(q[0]) - bot.s)
				var el: float = float(q[1]) - bot.lat
				var lap := int(q[3])
				if absf(es) < 8 and absf(el) < 3:
					net.botErr[i] = Vector2(es, el)
					# the lap that goes with the bot's own position (it may still be just before or after the line)
					var rq := fposmod(float(q[0]) - Trk.S_START, L)
					var rb := fposmod(bot.s - Trk.S_START, L)
					if rb - rq > L / 2: lap -= 1
					elif rq - rb > L / 2: lap += 1
				else:
					net.botErr[i] = Vector2.ZERO
					bot.s = q[0]; bot.lat = q[1]
				bot.speed = q[2]; bot.lap = lap; bot.yawOff = q[4]; bot.finished = bool(q[5]); bot.finishTime = q[6] if q[6] else 0.0
		var kicks = pr.get("k")
		if net.host and kicks is Array:
			var last: int = net.seen.get(p.peer, 0)
			for kq in kicks:
				if not (kq is Dictionary) or int(kq.get("q", 0)) <= last: continue
				last = int(kq.q)
				var bi := int(kq.get("i", -1))
				if net.inRace and int(kq.get("r", 0)) == rid and bi >= 0 and bi < Game.bots.size():
					Game.kickOther(Game.bots[bi], float(kq.x), float(kq.z), float(kq.s))
			net.seen[p.peer] = last
	if not net.inRace: return
	if not net.host and botsFresh():
		# the rest of the difference with the host's bot positions: a part every frame (gone in about 0.1 s)
		var k := minf(1.0, get_process_delta_time() * 12)
		for i in mini(Game.bots.size(), 16):
			var e: Vector2 = net.botErr.get(i, Vector2.ZERO)
			if e == Vector2.ZERO: continue
			var c := e * k
			var bot: Mover = Game.bots[i]
			var rel := fposmod(bot.s - Trk.S_START, Trk.TRACK_LEN)
			bot.s = fposmod(bot.s + c.x, Trk.TRACK_LEN)
			var rel2 := fposmod(bot.s - Trk.S_START, Trk.TRACK_LEN)
			if rel2 < rel - Trk.TRACK_LEN / 2: bot.lap += 1
			elif rel2 > rel + Trk.TRACK_LEN / 2: bot.lap -= 1
			bot.lat += c.y
			net.botErr[i] = e - c if (e - c).length() > 0.01 else Vector2.ZERO
	# the start lights follow the time since the race was started, the same on every PC: a game that was busy (loading
	# the track, a hitch) does not start later than the others
	if Game.state == "countdown" and int(net.startAt) > 0:
		Game.cd = maxf(Game.cd, maxf(now - int(net.startAt), now + float(net.hostGo)) / 1000.0)
	if now - net.lastSend > 50:
		net.lastSend = now
		var pl := Game.player
		var st := [snappedf(pl.pos.x, 0.01), snappedf(pl.y, 0.01), snappedf(pl.pos.z, 0.01), snappedf(pl.heading, 0.001), snappedf(pl.speed, 0.01),
			snappedf(pl.s, 0.1), pl.lap, 1 if Game.raceDone else 0, snappedf(Game.raceFinishTime, 0.01), net.raceId, snappedf((now - int(net.startAt)) / 1000.0, 0.001)]
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
		if not _onRoad(r, now):
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
	var now := Time.get_ticks_msec()
	for r in net.remotes.values():
		if not _onRoad(r, now): continue
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
	net.startAt = 0
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
var _upnp: Thread = null

func open_internet() -> void:
	if _upnp != null: return      # still asking the router
	upnp_status = "Router vragen om poort %d open te zetten…" % NetRoom.PORT
	changed.emit()
	_upnp = Thread.new()
	_upnp.start(func():
		var u := UPNP.new()
		var err := u.discover(2000, 2)
		var msg: String
		if err != OK or u.get_gateway() == null or not u.get_gateway().is_valid_gateway():
			msg = "Geen router met UPnP gevonden. Zet poort %d (UDP) zelf open in je router." % NetRoom.PORT
		elif u.add_port_mapping(NetRoom.PORT, NetRoom.PORT, "Polderrace", "UDP") != UPNP.UPNP_RESULT_SUCCESS:
			msg = "De router wilde poort %d niet openzetten. Zet hem zelf open (UDP)." % NetRoom.PORT
		else:
			msg = "Via internet bereikbaar op %s (poort %d)." % [u.query_external_address(), NetRoom.PORT]
			call_deferred("_upnp_done", msg, u)
			return
		call_deferred("_upnp_done", msg, null))

## the router keeps a mapping until it is removed: it is closed again when the host leaves the game or quits
var _mapped: UPNP = null
var _unmap: Thread = null

func _upnp_done(msg: String, u: UPNP) -> void:
	_upnp.wait_to_finish()
	_upnp = null
	upnp_status = msg
	if u != null:
		_mapped = u
		if net == null: close_internet()    # the host left while the router was still being asked
	changed.emit()

func close_internet(wait := false) -> void:
	if _mapped == null: return
	var u := _mapped
	_mapped = null
	upnp_status = ""
	if _unmap != null: _unmap.wait_to_finish()
	_unmap = null
	if wait:
		u.delete_port_mapping(NetRoom.PORT, "UDP")
		return
	_unmap = Thread.new()
	_unmap.start(func(): u.delete_port_mapping(NetRoom.PORT, "UDP"))

func _exit_tree() -> void:
	if _upnp != null: _upnp.wait_to_finish()
	if _unmap != null: _unmap.wait_to_finish()
	close_internet(true)

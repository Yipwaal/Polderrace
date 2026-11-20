extends Node
## Autoload "Net": online racing, ported from the HTML game's net code (netEnter, netSyncRemotes, netHostStart, netBegin,
## netPlace, netKick, netTick, netRemoteProg, netCollide) on top of NetRoom (ENet) and LanDiscovery (games on the local
## network show up by themselves: no codes), and since phase 2 grown into a whole LAN evening.
##
## Presence per player: nick, car, color, look (how the car looks), rdy (ready), vote (next track), e (chat / emote),
## st (position, 20 per second), k (hits against bots). The host also has: host, cfg (the race settings, live),
## cd (the countdown to the start), race (the race that runs: track, laps, time, weather, bots, start order),
## b (the bots' positions), res (the official results of the race), pts (the standings of the evening),
## q (ping and loss per player), seats (who sits where, for a host change).
## The host decides: the race, the bots, the results and the points. Guests send their own position (the host checks
## that it can be true) and their hits against bots, which the host applies.
## st and the kicks carry the race id, so a late packet of an earlier race never counts in the next one; st[10] is the
## sender's time since the start, with which everyone shows the other cars where they are now (not where they were).
## When the host leaves or falls away another player takes over (host migration): the standings, the settings and
## even a race that is under way go on.

signal changed                     ## lobby list / players / status changed (UI refresh)
signal said(who: String, text: String)

const ON_KEY := "polderrace3d-online"
const PTS := [10, 8, 6, 5, 4, 3, 2, 1]             ## points per race, by place among the players
const FINISH_WAIT := 45.0                         ## seconds the others get after the first player finished
const START_SECS := 3.0                           ## the countdown everyone sees before the host's race starts
const EMOTES := ["Hoi!", "Klaar?", "Even wachten…", "Succes!", "Goeie race!", "Haha!", "Toet toet!"]
const NEXT_MODES := [["host", "Host kiest"], ["rot", "Om de beurt"], ["rand", "Willekeurig"], ["vote", "Stemmen"]]
const GRID_MODES := [["rev", "Leider achteraan"], ["pts", "Leider vooraan"], ["rand", "Willekeurig"], ["join", "Vaste volgorde"]]
const TAG_LAYER := 2               ## Fx.PLAYER_LAYER: the rear-view mirror leaves it out (name tags would read mirrored)

var net = null                     ## Dictionary while in a game (JS `net`), null otherwise
var lan: LanDiscovery
var status := ""
var _game_id := ""
var _on := {}                      ## what this player keeps about online play (see onl())
var _on_path := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	lan = LanDiscovery.new()
	add_child(lan)
	lan.lobbies_changed.connect(func(): changed.emit())
	lan.diag_changed.connect(func(): changed.emit())
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

# ------------------------------------------------------------------ what this player keeps about online play
## {tok: this player's secret token (its seat and its points go with it), ips: hosts joined by address, next, grid,
##  pts + ptsAt: the last standings seen (a new game within a few hours goes on with them)}
func onl() -> Dictionary:
	if _on_path != G.STORE_PATH:
		_on_path = G.STORE_PATH
		var d = G._json(ON_KEY, {})
		_on = d if d is Dictionary else {}
		if not (_on.get("tok") is String) or str(_on.tok).length() < 16:
			_on.tok = Crypto.new().generate_random_bytes(16).hex_encode()
			saveOnl()
	return _on

func saveOnl() -> void:
	G.store_set(ON_KEY, JSON.stringify(_on))

## the addresses this player joined before, newest first
func recentIps() -> Array:
	var a = onl().get("ips")
	return a.filter(func(x): return x is String and x != "") if a is Array else []

func _rememberIp(ip: String) -> void:
	if ip == "" or ip.begins_with("127."): return
	var a := recentIps()
	a.erase(ip)
	a.push_front(ip)
	onl().ips = a.slice(0, 4)
	saveOnl()

# ------------------------------------------------------------------ lobby (LAN)
func browse() -> void:
	if net == null:
		lan.extra = recentIps()
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

static func trackName(id, dir) -> String:
	if not TrackDefs.TRACKS.has(str(id)): return "?"
	return TrackDefs.TRACKS[str(id)].name + (" (omgekeerd)" if str(dir) == "rev" else "")

func _lobby_info() -> Dictionary:
	var S := G.settings
	var n: int = 1 + (net.remotes.size() if net != null else 0)
	return {"pr": 1, "v": NetRoom.PROTO, "id": _game_id, "name": gameName(str(G.prefs.nick)), "track": trackName(S.track, S.dir), "laps": int(S.laps),
		"n": n, "max": NetRoom.MAX_GUESTS + 1, "open": net != null and net.open and n <= NetRoom.MAX_GUESTS, "race": net != null and (net.inRace or net.ref), "port": NetRoom.PORT}

func netCreate() -> void:
	if net != null: return
	# a game we just left may still be saying goodbye on the port
	for c in get_children():
		if c is NetRoom: c.close_now()
	_game_id = "%08x%08x" % [randi(), randi()]
	var room := NetRoom.new()
	add_child(room)
	var err := room.start_host(G.prefs.nick, onl().tok)
	if err != OK:
		room.queue_free()
		netStatus("Hosten lukte niet: poort %d is bezet. Staat Polderrace nog een keer open op deze pc? Sluit dat venster (of kijk in Taakbeheer) en probeer het opnieuw." % NetRoom.PORT)
		return
	var listed := lan.serve(_lobby_info)
	netEnter(room, true)
	firewall_check()
	# an evening goes on: the standings of a game this player was in less than three hours ago
	var o := onl()
	if o.get("pts") is Dictionary and not o.pts.is_empty() and Time.get_unix_time_from_system() - float(o.get("ptsAt", 0)) < 3 * 3600:
		net.pts = _cleanPts(o.pts)
		room.presence({"pts": net.pts})
		netStatus("Je bent de host. De stand van eerder vanavond telt door (wissen kan bij Stand).")
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
	if addr == "" or typo or room.start_guest(addr, onl().tok) != OK:
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
		if net != null and net.game.get_instance_id() == rid and not net.joinedOnce and not net.game.is_connected_room():
			_onClosed(net.game, "fail"))

func _myPresence(host: bool) -> Dictionary:
	var p := {"nick": G.prefs.nick, "car": G.settings.car, "color": G.settings.color, "look": myLook(), "rdy": host, "vote": "", "e": [0, 0],
		"host": host, "st": null, "b": null, "k": [], "race": null}
	if host:
		p.merge({"cfg": {}, "cd": null, "res": null, "pts": {}, "seats": {}, "uid": NetRoom.uid_of(onl().tok)})
	return p

func netEnter(room: NetRoom, host: bool) -> void:
	if net != null:
		netLeave()
	net = {"game": room, "host": host, "inRace": false, "remotes": {}, "lastSend": 0, "raceId": 0, "kicks": [], "kickSeq": 0, "seen": {},
		"botDefs": null, "order": [], "startAt": 0, "botUpd": -1, "botAt": 0, "sentCar": "", "addr": "", "hostGo": -1e12, "botErr": {}, "botHold": {},
		"cfg": {}, "cd": null, "cdN": 0, "cdAt": 0, "cdSeen": -1, "pts": {}, "res": null, "resSent": "", "resAt": 0, "q": {}, "seats": {}, "open": true,
		"rdy": host, "vote": "", "eSeq": 0, "race": null, "raced": false, "firstFin": 0, "final": false, "forced": false, "warned": 0,
		"spec": null, "watch": false, "wspd": {}, "mig": null, "prevS": null, "chat": [], "joinedOnce": host, "nt": "", "cands": [],
		"clock": 0.0, "lookAt": 0, "seatsSent": "", "reconn": false, "preloaded": false, "noRoad": 0, "probe": null, "lostIps": [], "clockAt": Time.get_ticks_msec(),
		"ref": false, "raceL": 0.0, "raceS0": 0.0, "raceLaps": 1, "meRow": null, "botRows": []}
	# the host's races use this player's settings for a while: they come back when he leaves the game
	# (the host keeps what he picked in the online screen; only the mode and the grid place are the game's)
	net.prevS = G.settings.duplicate(true) if not host else {"mode": G.settings.mode, "grid": G.settings.grid}
	room.presence(_myPresence(host))
	net.sentCar = _carKey()
	_wire(room)
	if host:
		pushCfg()
		netStatus("Je bent de host. Spelers op hetzelfde netwerk zien je game nu in hun lijst.")
	changed.emit()

func _wire(room: NetRoom) -> void:
	room.peers_changed.connect(func():
		if net != null and net.game == room and netSyncRemotes(): changed.emit())
	room.closed.connect(func(reason: String): _onClosed(room, reason))
	room.joined.connect(func(): _onJoined(room))
	room.reconnecting.connect(func():
		if net == null or net.game != room: return
		net.reconn = true
		netStatus("Verbinding met de host kwijt. Opnieuw verbinden…")
		if not NetUi.is_open(): Hud.showToast("Verbinding kwijt. Opnieuw verbinden…"))

func _onJoined(room: NetRoom) -> void:
	if net == null or net.game != room: return
	if net.mig != null:
		_migDone()
	elif net.joinedOnce:
		net.reconn = false
		netStatus("Verbinding hersteld.")
		if not NetUi.is_open(): Hud.showToast("Verbinding hersteld.")
	else:
		net.joinedOnce = true
		_rememberIp(str(net.addr))
		netStatus("Je zit in de game van %s. Wacht tot de host start." % room.hostNick)
	netSyncRemotes()
	changed.emit()

## the game is over for us: it is full, closed, another version, we were kicked, or the connection is gone for good
func _onClosed(room: NetRoom, reason: String) -> void:
	if net == null or net.game != room: return
	if net.mig != null:
		# on the way to a new host: it is not there yet (it needs a moment to open the game): try again, then the next
		var m: Dictionary = net.mig
		if int(m.at) > 0 and Time.get_ticks_msec() - int(m.at) < 5000:
			get_tree().create_timer(0.4, true, false, true).timeout.connect(func():
				if net != null and net.mig == m and net.game == room: _migDial())
		else:
			_migNext()
		return
	if (reason == "end" or reason == "lost") and net.joinedOnce and _migStart(reason):
		return
	var t: String = {"end": "De host heeft de game gesloten.", "full": "De game zit vol: maximaal %d spelers." % (NetRoom.MAX_GUESTS + 1),
		"version": "De host speelt een andere versie van Polderrace. Zorg dat jullie dezelfde versie hebben (de nieuwste staat op de downloadpagina).",
		"kick": "De host heeft je uit de game gezet.", "shut": "Deze game is gesloten voor nieuwe spelers. Vraag de host hem open te zetten.",
		"fail": "Geen verbinding met %s. Is de game er nog, en zit je op hetzelfde netwerk? Anders houdt de firewall van de host het spel tegen." % net.get("addr", "de host")
		}.get(reason, "De verbinding met de host is weggevallen.")
	_leaveToList(t + (" Je bent uit de game." if reason == "end" or reason == "lost" else ""), t)

## out of the game with a message, back to the list of games (from wherever we were: race, results, replay, lobby)
func _leaveToList(msg: String, toast: String) -> void:
	var racing: bool = Game.state != "menu"
	var watching: bool = net.watch
	netLeave()
	if watching:
		Menu.netOpen()
	elif racing:
		# from the race, its results or the replay back to the online screen, where the message is
		Game.toMenu(-1)
		Menu.netOpen()
	else:
		_relist()
	netStatus(msg)
	if not NetUi.is_open(): Hud.showToast(toast)

func netLeave() -> void:
	if net == null:
		return
	var g: NetRoom = net.game
	var watching: bool = net.watch
	for r in net.remotes.values():
		if r.car != null: r.car.g.queue_free()
	var prev = net.prevS
	net = null
	g.leave()
	close_internet()
	# the room says goodbye for a moment before it closes (NetRoom.leave)
	get_tree().create_timer(0.6, true, false, true).timeout.connect(g.queue_free)
	lan.stop()
	if watching:
		Game.clearBots()
		Menu.showMenu(-1)
		Menu.homePanel("play")
	_restoreSettings(prev)
	changed.emit()

## a guest's own race settings come back (the host's races borrowed them)
func _restoreSettings(prev) -> void:
	if not (prev is Dictionary): return
	var S := G.settings
	for k in ["track", "dir", "laps", "bots", "mode", "grid", "time", "weather"]:
		if prev.has(k): S[k] = prev[k]
	G.saveSettings()
	_fitWorld.call_deferred()

## the world shows the track and the weather of the settings again (in the menus only: a race loads its own)
func _fitWorld() -> void:
	var S := G.settings
	if net != null or Game.state != "menu" or get_tree().current_scene == null or not get_tree().current_scene.has_method("load_track"): return
	if Trk.TRACK_ID != S.track or Trk.TRACK_DIR != S.dir:
		get_tree().current_scene.load_track(S.track)
	if Env.me != null: Env.me.apply(S.time, S.weather)

# ------------------------------------------------------------------ the car and its looks
## how my car looks, to send to the others: G.lookOf (the paid-for looks of the garage, with the paint; never the
## performance upgrades and never what is only being tried on in the garage)
func myLook() -> Dictionary:
	var car: String = G.settings.car
	var d: Dictionary
	if G.has_method("lookOf"):
		var v = G.call("lookOf", car)
		d = v.duplicate() if v is Dictionary else {}
	else:
		d = G.carUp(car).duplicate()
		for u in G.UPG: d.erase(u.k)
		d.erase("body")
	d = NetRoom.clean_look(d)
	if JSON.stringify(d).length() > NetRoom.LOOK_MAX: d = {"paint": G.settings.color}
	return d

## a look that came off the wire, safe to hand to CarKit.styleCar on a car of type `car`: only catalogue keys, each
## with a valid value (CarLook.clean), never upgrades
static func safeLook(v, car := "") -> Dictionary:
	if not (v is Dictionary): return {}
	return CarLook.compact(CarLook.clean(v, car))

## the paint of a remote car: from its look, else its colour field
static func _paintOf(r: Dictionary) -> Color:
	var p = r.lookD.get("paint") if r.lookD is Dictionary else null
	if p is String and CarLook.isHex(p): return Color(p)
	return Color(str(r.color)) if Color.html_is_valid(str(r.color)) else Color.WHITE

## the car of another player by name (for the podium): {carId, color, look}, or null
func remoteCar(name: String):
	if net == null: return null
	for r in net.remotes.values():
		if r.name == name: return {"carId": r.carId, "color": "#" + _paintOf(r).to_html(false), "look": safeLook(r.lookD, r.carId)}
	return null

func _carKey() -> String:
	return str(G.settings.car) + str(G.settings.color) + JSON.stringify(myLook())

## the others see the car I drive (after the car step, the garage, or when the race swapped in a car I own)
func _sendCar() -> void:
	if net == null: return
	var c := _carKey()
	if c != net.sentCar:
		net.sentCar = c
		net.game.presence({"car": G.settings.car, "color": G.settings.color, "look": myLook()})

## the car step of an online game is done (JS netCarDone): back to the online screen, the others see the new car
func netCarDone() -> void:
	Menu.menuFlow = "quick"
	Menu.showMenu(-1)
	Menu.homePanel("play")
	Menu.netOpen()
	_sendCar()
	changed.emit()

## the next or previous car I own, or colour, without leaving the lobby
func cycleCar(d: int) -> void:
	var ids: Array = Cars.CARS.keys().filter(func(id): return Career.owns(id))
	if ids.is_empty(): return
	var i := ids.find(G.settings.car)
	G.settings.car = ids[(i + d + ids.size()) % ids.size()]
	G.saveSettings()
	Game.rebuildPlayerCar()
	_sendCar()
	changed.emit()

func cycleColor(d: int) -> void:
	var cols: Array = Cars.COLORS
	var i := cols.find(G.settings.color)
	G.settings.color = cols[(i + d + cols.size()) % cols.size()]
	G.saveSettings()
	Game.rebuildPlayerCar()
	_sendCar()
	changed.emit()

func _buildRemoteCar(r: Dictionary) -> void:
	if r.car != null: r.car.g.queue_free()
	r.car = CarKit.buildCar(r.carId, _paintOf(r))
	CarKit.styleCar(r.car, safeLook(r.lookD, r.carId))
	r.car.g.visible = false
	r.shown = false
	get_tree().current_scene.add_child(r.car.g)
	# the name above the car (not in the mirror, where it would read mirrored)
	var t := Label3D.new()
	t.text = r.name
	t.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	t.fixed_size = true
	t.pixel_size = 0.0011
	t.font = Hud.font("800 16px Nunito")[0]
	t.font_size = 30
	t.outline_size = 9
	t.modulate = Color(1, 1, 1, 0.95)
	t.outline_modulate = Color(0.06, 0.09, 0.15, 0.85)
	t.position = Vector3(0, 2.05, 0)
	t.layers = 1 << (TAG_LAYER - 1)
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.car.g.add_child(t)
	r.tag = t
	# a race number is a canvas texture: draw it now
	if Canvas2D.pending_count() > 0 and get_tree().current_scene != null: Canvas2D.flush(get_tree().current_scene)

# ------------------------------------------------------------------ the players
## the other players' cars, from the presence; true when someone came, went or changed name or car (the screen updates)
func netSyncRemotes() -> bool:
	if net == null or net.mig != null:
		return false
	var room: NetRoom = net.game
	if not net.host and not room.is_connected_room():
		return false      # reconnecting: what we knew stays as it is
	var seen := {}
	var news := false
	for p in room.peers():
		if p.sameTab: continue
		var pr: Dictionary = p.presence if p.presence is Dictionary else {}
		if not pr.get("nick", ""): continue
		seen[p.peer] = true
		var r = net.remotes.get(p.peer)
		if r == null:
			r = {"peer": p.peer, "car": null, "carId": null, "want": null, "color": null, "look": "", "lookD": {}, "st": null, "prev": null, "t": 0, "lap": 0,
				"done": false, "ft": 0.0, "upd": 0, "name": "", "host": false, "out": false, "uid": "", "rdy": false, "off": false, "vote": "", "eSeq": -1,
				"tag": null, "clk": 1e18, "clkAt": 0, "yaw": 0.0, "vy": 0.0, "dp": Vector3.ZERO, "dh": 0.0, "shown": false,
				"vdist": 0.0, "vs": -1.0, "vt": 0, "bad": false, "vel": Vector2.ZERO, "velOk": false}
			net.remotes[p.peer] = r
			news = true
			if net.host: netStatus("%s doet mee." % str(pr.nick).substr(0, 24))
		var nm := _dispName(p.peer, str(pr.nick).substr(0, 24))
		var hs := bool(pr.get("host", false))
		if nm != r.name or hs != r.host:
			r.name = nm; r.host = hs; news = true
			if r.tag != null: r.tag.text = nm
		var rd: bool = pr.get("rdy", false) == true or hs
		var off: bool = pr.get("off", false) == true
		var vt := str(pr.get("vote", ""))
		var ud := str(pr.get("uid", ""))
		if rd != r.rdy or off != r.off or vt != r.vote or ud != r.uid:
			r.rdy = rd; r.off = off; r.vote = vt; r.uid = ud; news = true
		var lk = pr.get("look")
		var lks := JSON.stringify(lk) if lk is Dictionary else ""
		if r.want != pr.get("car") or r.color != pr.get("color") or r.look != lks:
			r.want = pr.get("car")
			r.carId = pr.car if Cars.CARS.has(str(pr.get("car", ""))) else "gt"
			r.color = pr.get("color", "#ffffff")
			r.look = lks
			r.lookD = lk if lk is Dictionary else {}
			_buildRemoteCar(r)
			news = true
		# chat / emote: [seq, number of EMOTES or text]
		var e = pr.get("e")
		if e is Array and e.size() == 2:
			var sq := int(e[0])
			if r.eSeq < 0: r.eSeq = sq
			elif sq != r.eSeq:
				r.eSeq = sq
				_heard(r.name, e[1])
		# the host's side of the game
		if hs and not net.host:
			if _hostState(pr): news = true
	for k in net.remotes.keys():
		if not seen.has(k):
			var r: Dictionary = net.remotes[k]
			if r.car != null: r.car.g.queue_free()
			net.remotes.erase(k)
			news = true
			if net.host and r.off:
				# it fell away without a goodbye: maybe it was us (see _probeTick)
				var s = net.seats.get(k)
				if s is Array and s.size() == 2 and str(s[1]) != "" and not str(s[1]) in net.lostIps: net.lostIps.append(str(s[1]))
				if net.remotes.is_empty() and not net.lostIps.is_empty(): _probeStart(net.lostIps.slice(-6))
			var t := "%s heeft de game verlaten." % r.name
			netStatus(t)
			if Game.state != "menu": Hud.showToast(t)
	if net.host and news: _sendSeats()
	return news

## the name of a player as every PC shows it: two players with the same name are "Bram" and "Bram (2)" (by seat,
## so it is the same on every screen)
func _dispName(id: String, nick: String) -> String:
	var key := nick.strip_edges().to_lower()
	var n := 1
	for p in net.game.peers():
		if p.peer == id or not (p.presence is Dictionary): continue
		if str(p.presence.get("nick", "")).substr(0, 24).strip_edges().to_lower() == key and _seatNo(p.peer) < _seatNo(id): n += 1
	return nick if n == 1 else "%s (%d)" % [nick, n]

static func _seatNo(id: String) -> int:
	return 0 if id == "h" else (int(id.substr(1)) if id.begins_with("g") else 999)

## guest: what the host says about the game (settings, countdown, results, standings, connection quality, seats)
func _hostState(pr: Dictionary) -> bool:
	var news := false
	var c = pr.get("cfg")
	if c is Dictionary and JSON.stringify(c) != JSON.stringify(net.cfg):
		net.cfg = c; news = true
	var cd = pr.get("cd")
	if cd is Dictionary and NetRoom._num(cd.get("n")) and NetRoom._num(cd.get("s")):
		if int(cd.n) != int(net.cdSeen):
			net.cdSeen = int(cd.n)
			net.cd = {"until": Time.get_ticks_msec() + int(clampf(float(cd.s), 0, 30) * 1000), "track": str(cd.get("track", "")), "dir": str(cd.get("dir", "fwd"))}
			news = true
			_preload.call_deferred(str(cd.get("track", "")), str(cd.get("dir", "fwd")))
	elif net.cd != null:
		net.cd = null; net.cdSeen = -1; news = true
	var res = pr.get("res")
	if res is Dictionary and _resOk(res):
		if JSON.stringify(res) != JSON.stringify(net.res): net.res = res; news = true
	elif res == null and net.res != null and not net.inRace:
		pass      # the results of the last race stay until the next one starts
	var pts = pr.get("pts")
	if pts is Dictionary and JSON.stringify(pts) != JSON.stringify(net.pts):
		net.pts = _cleanPts(pts); news = true
		_savePts()
	var q = pr.get("q")
	if q is Dictionary: net.q = q
	var seats = pr.get("seats")
	if seats is Dictionary: net.seats = seats
	return news

## the standings as they come off the wire or out of the save: {uid: [name, points, races, wins, last race]}
static func _cleanPts(pts: Dictionary) -> Dictionary:
	var out := {}
	for k in pts:
		var a = pts[k]
		if k is String and k.length() <= 24 and a is Array and a.size() == 5 and a[0] is String and NetRoom._nums(a.slice(1), 4, 4):
			out[k] = [NetRoom._text(a[0], 24), int(a[1]), int(a[2]), int(a[3]), int(a[4])]
		if out.size() >= 64: break
	return out

func _savePts() -> void:
	var o := onl()
	o.pts = net.pts
	o.ptsAt = Time.get_unix_time_from_system()
	saveOnl()

## host: who sits where and at which address (a guest that becomes the host needs to be found by the others)
func _sendSeats() -> void:
	var room: NetRoom = net.game
	var s := {}
	for k in net.remotes:
		s[k] = [room.uid_at(k), room.address_of(k)]
	var js := JSON.stringify(s)
	if js != net.seatsSent:
		net.seatsSent = js
		net.seats = s
		room.presence({"seats": s})

func isReady() -> bool:
	return net != null and (net.host or net.rdy)

func setReady(b: bool) -> void:
	if net == null or net.host or net.rdy == b: return
	net.rdy = b
	net.game.presence({"rdy": b})
	changed.emit()

## the players that have not said they are ready (not counting who lost his connection)
func notReady() -> Array:
	var out := []
	if net == null: return out
	for r in net.remotes.values():
		if not r.rdy and not r.off: out.append(r.name)
	return out

func kick(peer: String) -> void:
	if net == null or not net.host or not net.remotes.has(peer): return
	var nm: String = net.remotes[peer].name
	net.game.kick(peer)
	netStatus("%s is uit de game gezet." % nm)

func setOpen(b: bool) -> void:
	if net == null or not net.host: return
	net.open = b
	net.game.open = b
	pushCfg()

## ping and loss of every guest as the host measures them: {peer: [ping ms, loss %, seconds silent]}
func _q() -> Dictionary:
	if not net.host: return net.q
	var q = net.game.presence_of(net.game.me).get("q")
	return q if q is Dictionary else {}

## connection of a player as the lobby shows it: {ping (ms, -1 unknown), warn, text}
func quality(peer: String) -> Dictionary:
	if net == null: return {"ping": -1, "warn": false, "text": ""}
	var room: NetRoom = net.game
	var ping := -1
	var loss := 0.0
	var silent := 0.0
	if peer == room.me:
		if net.host: return {"ping": 0, "warn": false, "text": "host"}
		ping = room.my_ping()
		silent = room.host_silence()
		if room.is_reconnecting(): return {"ping": -1, "warn": true, "text": "verbinding kwijt"}
	else:
		var r = net.remotes.get(peer)
		if r != null and r.off: return {"ping": -1, "warn": true, "text": "verbinding kwijt"}
		if r != null and r.host: return {"ping": 0, "warn": room.host_silence() > 3.0, "text": "host" if room.host_silence() <= 3.0 else "reageert niet"}
		var q = _q().get(peer)
		if NetRoom._nums(q, 3, 3):
			ping = int(q[0]); loss = float(q[1]); silent = float(q[2])
	if ping < 0: return {"ping": -1, "warn": false, "text": ""}
	var warn := ping > 120 or loss > 4.0 or silent > 3.0
	return {"ping": ping, "warn": warn, "text": "%d ms" % ping + (" · %d%% verlies" % int(round(loss)) if loss > 4.0 else "")}

# ------------------------------------------------------------------ chat and emotes
## say something to everyone: a number of EMOTES, or a short text
func say(v) -> void:
	if net == null: return
	net.eSeq = int(net.eSeq) + 1
	if v is String:
		v = NetRoom._text(v, 60)
		if v == "": return
	net.game.presence({"e": [net.eSeq, v]})
	_heard(str(G.prefs.nick), v)

var _lastHeard := {}
func _heard(who: String, v) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_lastHeard.get(who, -9999)) < 400: return     # (nobody floods the others)
	_lastHeard[who] = now
	var text := ""
	if v is String: text = v
	elif (v is int or v is float) and int(v) >= 0 and int(v) < EMOTES.size(): text = EMOTES[int(v)]
	if text == "": return
	if text == EMOTES[6]:
		Sfx.tone(392, 0.22, "square", 0.1); Sfx.tone(392, 0.3, "square", 0.1, 0.28)
	if net != null:
		net.chat.append([who, text])
		if net.chat.size() > 5: net.chat.pop_front()
	said.emit(who, text)
	if not (NetUi.is_open() and NetUi.ov.visible): Hud.showToast("%s: %s" % [who, text])
	changed.emit()

# ------------------------------------------------------------------ the race settings (host) as everyone sees them
## track, dir, laps, bots, diff, time, weather, grid, next, open (+ nt: the next track, cands: tracks to vote for)
func cfg() -> Dictionary:
	if net == null: return {}
	return _myCfg() if net.host else net.cfg

func _myCfg() -> Dictionary:
	var S := G.settings
	var o := onl()
	return {"track": S.track, "dir": S.dir, "laps": int(S.laps), "bots": mini(int(S.bots), 5), "diff": S.diff, "time": S.time, "weather": S.weather,
		"grid": o.get("grid", "rev"), "next": o.get("next", "host"), "open": net.open, "nt": net.nt, "cands": net.cands}

## host: a setting changed; everyone sees it
func pushCfg() -> void:
	if net == null or not net.host: return
	net.game.presence({"cfg": _myCfg()})
	changed.emit()

func setNextMode(m: String) -> void:
	onl().next = m
	saveOnl()
	if net != null and net.host:
		net.nt = ""; net.cands = []
		if net.raced: _planNext()
	pushCfg()

func setGridMode(m: String) -> void:
	onl().grid = m
	saveOnl()
	pushCfg()

func vote(id: String) -> void:
	if net == null: return
	net.vote = id
	net.game.presence({"vote": id})
	changed.emit()

## how many votes each track has (mine and the others')
func votes() -> Dictionary:
	var out := {}
	if net == null: return out
	if net.vote != "": out[net.vote] = 1
	for r in net.remotes.values():
		if r.vote != "" and not r.off: out[r.vote] = int(out.get(r.vote, 0)) + 1
	return out

## host, after a race: what comes next (shown on the results screen; applied when the next race starts)
func _planNext() -> void:
	var S := G.settings
	var ids: Array = TrackLoader.ported()
	var mode: String = onl().get("next", "host")
	net.nt = ""
	net.cands = []
	if mode == "rot":
		net.nt = ids[(ids.find(S.track) + 1) % ids.size()]
	elif mode == "rand" or mode == "vote":
		var others: Array = ids.filter(func(id): return id != S.track)
		others.shuffle()
		if mode == "rand": net.nt = others[0] if not others.is_empty() else S.track
		else: net.cands = others.slice(0, 3)

## host, when the next race starts: the planned or voted track becomes the track
func _applyNext() -> void:
	if not net.raced: return
	net.raced = false
	var S := G.settings
	var pick: String = net.nt
	if not net.cands.is_empty():
		var v := votes()
		var best := 0
		var top := []
		for c in net.cands:
			var n := int(v.get(c, 0))
			if n > best: best = n; top = [c]
			elif n == best: top.append(c)
		pick = top[randi() % top.size()]
	net.nt = ""
	net.cands = []
	if pick != "" and TrackDefs.TRACKS.has(pick) and pick != S.track:
		S.track = pick
		G.saveSettings()
	if net.vote != "": vote("")
	pushCfg()

# ------------------------------------------------------------------ the start
## the host starts a race for everyone in the game (JS netHostStart): first a short countdown everyone sees
func netHostStart() -> void:
	if net == null or not net.host or int(net.cdAt) > 0: return
	# the last race is not over for everyone yet: it ends now, with the places as they are (else it never counted)
	if (net.inRace or net.ref) and net.raced and not net.final: _judge(Time.get_ticks_msec(), true)
	_applyNext()
	var S := G.settings
	net.cdN = int(net.cdN) + 1
	net.cdAt = Time.get_ticks_msec() + int(START_SECS * 1000)
	net.cd = {"until": net.cdAt, "track": S.track, "dir": S.dir}
	net.game.presence({"cd": {"n": net.cdN, "s": START_SECS, "track": S.track, "dir": S.dir}})
	changed.emit()
	_preload.call_deferred(S.track, S.dir)

## the host changes his mind during the countdown
func netHostCancel() -> void:
	if net == null or not net.host or int(net.cdAt) == 0: return
	net.cdAt = 0
	net.cd = null
	net.game.presence({"cd": null})
	netStatus("Start afgebroken.")

## seconds until the host's race starts (0 = no countdown)
func countdown() -> float:
	if net == null or net.cd == null: return 0.0
	return maxf(0.0, (int(net.cd.until) - Time.get_ticks_msec()) / 1000.0)

## during the countdown: the track of the race is loaded already, so the start itself is instant for everyone
## (only from the menus and the results; who is still driving loads when the race starts)
func _preload(track: String, dir: String) -> void:
	if net == null or net.cd == null or not TrackLoader.ported().has(track): return
	if not (Game.state == "menu" or Game.state == "over") or Rep.rp != null or net.watch: return
	dir = "rev" if dir == "rev" else "fwd"
	if Trk.TRACK_ID == track and Trk.TRACK_DIR == dir: return
	if Game.state == "menu" and Menu.menuStep >= 0: return     # in the car step: its scene stays as it is
	net.preloaded = true
	for r in net.remotes.values():
		if r.car != null: r.car.g.visible = false
	G.settings.track = track
	G.settings.dir = dir
	get_tree().current_scene.load_track(track)

func _newRaceId() -> int:
	return maxi(int(net.raceId) + 1, int(Time.get_unix_time_from_system() * 10.0) % 2000000000)

## host: the start order of the players (the bots are in front of them)
func _gridOrder() -> Array:
	var ids: Array = net.remotes.keys().filter(func(k): return not net.remotes[k].off)
	ids.sort_custom(func(a, b): return int(str(a).substr(1)) < int(str(b).substr(1)))
	var me: String = net.game.me
	ids.push_front(me)
	var mode: String = onl().get("grid", "rev")
	var room: NetRoom = net.game
	var pts := func(id) -> int:
		var e = net.pts.get(room.uid_at(id))
		return int(e[1]) if e is Array else 0
	var any := false
	for id in ids:
		if pts.call(id) > 0: any = true
	if mode == "rand" or ((mode == "rev" or mode == "pts") and not any):
		if mode != "pts": ids.shuffle()
	elif mode == "rev":
		ids.sort_custom(func(a, b): return pts.call(a) < pts.call(b))
	elif mode == "pts":
		ids.sort_custom(func(a, b): return pts.call(a) > pts.call(b))
	return ids

func _hostGo() -> void:
	if net == null or not net.host: return
	net.cdAt = 0
	net.cd = null
	var S := G.settings
	var defs := Game.makeBotDefs(mini(int(S.bots), 5))
	net.botDefs = defs
	net.order = _gridOrder()
	var race := {"id": _newRaceId(), "track": S.track, "dir": S.dir, "laps": int(S.laps), "time": S.time, "weather": S.weather, "bots": defs, "order": net.order}
	net.res = null
	net.resSent = ""
	net.game.presence({"race": race, "cd": null, "res": null})
	net.raceId = race.id
	netBegin(race)

## a race as the host sent it: only what this game knows (a broken or strange host cannot crash the others)
static func raceOk(race) -> bool:
	if not (race is Dictionary): return false
	if not NetRoom._num(race.get("id")) or not NetRoom._num(race.get("laps")): return false
	if not (race.get("track") is String) or not TrackLoader.ported().has(race.track): return false
	if not (race.get("time") is String) or not Env.TIME_NAMES.has(race.time): return false
	if not (race.get("weather") is String) or not Env.WEATHER_NAMES.has(race.weather): return false
	var bots = race.get("bots")
	if not (bots is Array) or bots.size() > 7: return false
	for b in bots:
		if not (b is Dictionary) or not (b.get("name") is String) or not (b.get("type") is String) or not Cars.CARS.has(b.type): return false
		if not (b.get("color") is String) or not Color.html_is_valid(b.color): return false
	var order = race.get("order")
	if not (order is Array) or order.size() > 16: return false
	for o in order:
		if not (o is String): return false
	return true

func netBegin(race: Dictionary) -> void:
	net.startAt = Time.get_ticks_msec()
	net.hostGo = -1e12
	net.botErr = {}
	net.botHold = {}
	net.inRace = true
	net.race = race
	net.raced = true
	net.final = false
	net.forced = false
	net.firstFin = 0
	net.warned = 0
	net.clock = 0.0
	net.cd = null
	net.preloaded = false
	net.botDefs = race.bots
	net.order = race.order
	if net.watch: _watchEnd(false)
	net.spec = null
	if net.res != null and int(net.res.get("id", 0)) != int(race.id): net.res = null
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
	S.track = race.track; S.dir = "rev" if race.dir == "rev" else "fwd"; S.laps = clampi(int(race.laps), 1, 9); S.time = race.time; S.weather = race.weather
	# (a race without bots is still a race, not a time trial: Game looks at the number in the settings)
	S.bots = maxi(1, race.bots.size()); S.mode = "race"; S.grid = "back"
	if Trk.TRACK_ID != race.track or Trk.TRACK_DIR != S.dir:
		get_tree().current_scene.load_track(race.track)
	if Env.me != null: Env.me.apply(race.time, race.weather)
	for r in net.remotes.values():
		r.done = false; r.lap = 0; r.st = null; r.prev = null; r.velOk = false; r.out = false; r.shown = false; r.vs = -1.0; r.vdist = 0.0; r.bad = false; r.clk = 1e18
	# the host decides when the race starts: results, replay, pause or a race still under way make way for it
	if Game.state != "menu":
		if Rep.rp != null: Rep.replayClose()
		if Game.paused: Game.setPaused(false)
		Game.state = "over"
		Game.overReady = true
	Game.startRace()
	if net.host: S.bots = race.bots.size()      # (the host's own setting: 0 bots stays 0)
	# the race's own track: the host goes on judging it from the lobby, where he may load another track (see netAfterRace)
	net.ref = false
	net.raceL = Trk.TRACK_LEN
	net.raceS0 = Trk.S_START
	net.raceLaps = Game.raceLaps
	net.botAt = Time.get_ticks_msec()     # (the host's bots count as live until his snapshots stop, see hostBots)
	# the same wait for green on every PC (the lights follow the time since the start, see netTick)
	Game.goDelay = 0.4 + float(int(race.id) % 800) / 1000.0
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

## guests: the host drives the bots. When his positions stop coming (he went back to the lobby, or he fell away and a
## new host is being found) each game drives them itself, instead of leaving them standing on the road.
func hostBots() -> bool:
	return net != null and not net.host and Time.get_ticks_msec() - int(net.botAt) < 2000

## how far a car is in this race (Game.progressOf on the race's own track: the host may have loaded another one)
func _prog(lap: int, s: float, finished: bool, ft: float) -> float:
	var L: float = net.raceL if float(net.raceL) > 0 else Trk.TRACK_LEN
	if finished: return (int(net.raceLaps) + 2) * L + 100000 - ft * 10
	var rel := fposmod(s - float(net.raceS0), L)
	if lap <= 0: return -fmod(L - rel, L)
	return (lap - 1) * L + rel

func _wrapL(d: float) -> float:
	var L: float = net.raceL if float(net.raceL) > 0 else Trk.TRACK_LEN
	return d - L if d > L / 2.0 else (d + L if d < -L / 2.0 else d)

## a remote car on the road: in this race, not gone back to the menu, and heard from lately (not closed or hanging)
func _onRoad(r: Dictionary, now: int) -> bool:
	return r.car != null and r.st != null and not r.out and now - int(r.t) < 1500

func _process(dt: float) -> void:
	netTick(dt)

## how old a position of this player is by now, in game seconds: its own clock (st[10]) against ours, plus the trip
func _age(r: Dictionary, st: Array, now: int) -> float:
	var lat := 0.0
	var room: NetRoom = net.game
	if net.host:
		var q = _q().get(r.peer)
		if NetRoom._nums(q, 3, 3) and float(q[0]) > 0: lat = float(q[0]) / 2.0
	else:
		lat = maxf(0.0, room.my_ping()) / 2.0
		if not r.host:
			var q2 = net.q.get(r.peer)
			if NetRoom._nums(q2, 3, 3) and float(q2[0]) > 0: lat += float(q2[0]) / 2.0
	var a := (float(now) - float(r.clk) - float(st[10]) * 1000.0 + minf(lat, 120.0)) / 1000.0
	return clampf(a, 0.0, 0.35) * Engine.time_scale

func netTick(dt: float) -> void:
	if net == null: return
	var now := Time.get_ticks_msec()
	if net.mig != null:
		_migTick(now)
		if net == null or net.mig != null: return
	var room: NetRoom = net.game
	var rid := int(net.raceId)
	var live: bool = net.inRace or net.watch
	# the race clock for the results: real time since green (as fast as the game runs), whatever the frame rate
	if (net.inRace and Game.state != "countdown" and Game.state != "menu") or net.ref:
		net.clock += minf(2.0, (now - int(net.clockAt)) / 1000.0) * Engine.time_scale
	net.clockAt = now
	for p in room.peers():
		if p.sameTab: continue
		var pr: Dictionary = p.presence if p.presence is Dictionary else {}
		var r = net.remotes.get(p.peer)
		if r == null: continue
		var race = pr.get("race")
		if not net.host and pr.get("host", false) and race is Dictionary and NetRoom._num(race.get("id")) and int(race.id) != rid:
			net.raceId = int(race.id)
			rid = int(race.id)
			if not raceOk(race):
				netStatus("De host startte een race die dit spel niet kent. Hebben jullie dezelfde versie?")
			elif race.order.has(room.me):
				netBegin(race)
				live = true
			else:
				net.race = race
				if not net.inRace:
					# joined during a race: wait for the next one
					netStatus("Er is een race bezig. Je doet mee vanaf de volgende race; meekijken kan nu al.")
		elif not net.host and pr.get("host", false) and race == null and not net.inRace and net.race != null:
			net.race = null      # the host's race is over
			changed.emit()
		var st = pr.get("st")
		if st is Array and st.size() > 10 and int(st[9]) == rid:
			# (a position older than the one we have came late over a bad connection: it would pull the car back)
			var stale: bool = r.st != null and float(st[10]) < float(r.st[10]) and int(st[7]) == int(r.st[7])
			if stale: r.upd = p.updatedAt
			if p.updatedAt != r.upd and not r.out:
				r.upd = p.updatedAt
				# the sender's clock against ours: the quickest packet so far (it slowly forgets, clocks drift)
				var d := float(now) - float(st[10]) * 1000.0
				r.clk = minf(float(r.clk) + float(now - int(r.clkAt)) * 0.002 if float(r.clk) < 1e17 else d, d)
				r.clkAt = now
				if r.st != null and float(st[10]) > float(r.st[10]):
					var dts: float = (float(st[10]) - float(r.st[10])) * Engine.time_scale
					r.yaw = clampf(wrapf(float(st[3]) - float(r.st[3]), -PI, PI) / dts, -3.0, 3.0) if dts > 0.005 else 0.0
					r.vy = clampf((float(st[1]) - float(r.st[1])) / dts, -12.0, 12.0) if dts > 0.005 else 0.0
					# how it really moved (a drifting car goes sideways: its heading and speed alone would say otherwise);
					# not over a jump (put back on the road) or a long gap
					var mv := Vector2(float(st[0]) - float(r.st[0]), float(st[2]) - float(r.st[2])) / maxf(dts, 0.001)
					r.velOk = dts > 0.005 and dts < 0.6 and mv.length() < absf(float(st[4])) + 12.0
					if r.velOk: r.vel = mv
				r.prev = r.st; r.st = st; r.t = now; r.lap = int(st[6])
				# can it be true? the distance it covered at a speed a car can have (the host's results go by this)
				if float(net.raceL) > 0:
					if float(r.vs) < 0: r.vdist = 0.0
					else:
						var cap := 130.0 * (now - int(r.vt)) / 1000.0 * Engine.time_scale + 6.0
						r.vdist += clampf(_wrapL(float(st[5]) - float(r.vs)), -cap, cap)
					r.vs = float(st[5]); r.vt = now
				if st[7] and not r.done:
					if r.vdist >= int(net.raceLaps) * float(net.raceL) - 60.0:
						r.done = true
						var ft := float(st[8])
						# its own time, when that can be right by the clock here (else the moment it came in)
						r.ft = ft if (ft > float(net.clock) - 6.0 and ft < float(net.clock) + 3.0) else float(net.clock)
					elif not r.bad:
						r.bad = true
						if net.host: netStatus("De finish van %s telt niet: die auto kan daar nog niet zijn." % r.name)
				if r.host and st.size() > 10:
					# how long ago the host started this race (a start message that had to be sent again came late)
					net.hostGo = float(st[10]) * 1000.0 - now
		elif st == null and r.st != null and live and not r.out:
			# back to the menu during the race: the car goes; who finished keeps his place in the results
			r.out = true
			if not r.done: r.st = null
		var b = pr.get("b")
		if not net.host and pr.get("host", false) and live and b is Array and p.updatedAt != net.botUpd and st is Array and st.size() > 10 and int(st[9]) == rid:
			# a new snapshot of the host's bots (only once: in between they roll on, see botsFresh)
			net.botUpd = p.updatedAt
			net.botAt = now
			var L := Trk.TRACK_LEN
			var age := _age(r, st, now)
			for i in b.size():
				if i >= Game.bots.size(): break
				if now < int(net.botHold.get(i, 0)): continue
				var q: Array = b[i]
				var bot: Mover = Game.bots[i]
				# where the bot is by now: the host's position plus what it drove since (finished bots too: they roll out)
				var qs := fposmod(float(q[0]) + float(q[2]) * age, L)
				# a small difference with where the bot rolled on to here is smoothed out over a few frames (the host's
				# frames are not evenly spaced either); a big one (a crash, a reset) is taken over at once
				var es := Trk.wrapD(qs - bot.s)
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
					bot.s = qs; bot.lat = q[1]
				bot.speed = q[2]; bot.lap = lap; bot.yawOff = q[4]; bot.finished = bool(q[5]); bot.finishTime = q[6] if q[6] else 0.0
				net.wspd[i] = [float(q[2]), float(q[4])]
		var kicks = pr.get("k")
		if net.host and kicks is Array:
			var last: int = net.seen.get(p.peer, 0)
			for kq in kicks:
				if not (kq is Dictionary) or int(kq.get("q", 0)) <= last: continue
				last = int(kq.q)
				var bi := int(kq.get("i", -1))
				if net.inRace and int(kq.get("r", 0)) == rid and bi >= 0 and bi < Game.bots.size():
					# (a push no harder than a car can give)
					Game.kickOther(Game.bots[bi], clampf(float(kq.x), -25, 25), clampf(float(kq.z), -25, 25), clampf(float(kq.s), -8, 8))
			net.seen[p.peer] = last
	if net == null: return
	# host: the countdown ran out
	if net.host and int(net.cdAt) > 0 and now >= int(net.cdAt):
		_hostGo()
	# in the lobby: the garage may have changed my car's looks
	if not net.inRace and now - int(net.lookAt) > 1000:
		net.lookAt = now
		_sendCar()
	if net.host and net.probe != null: _probeTick(now)
	if net == null: return
	if net.watch: _watchTick(dt, now)
	if net == null: return
	# host back in the lobby while the others still race: he is still the referee of their race
	if net.host and net.ref and not net.inRace: _judge(now)
	if not (net.inRace or net.watch):
		return
	if not net.host and botsFresh() and not net.watch:
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
	if net.inRace:
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
			room.presence(patch)
		if net.host: _judge(now)
		_raceEnd(now)
	_showRemotes(dt, now)
	if net != null and net.spec != null and not net.watch:
		net.noRoad = int(net.noRoad) + 1 if specTargets().is_empty() else 0
		if int(net.noRoad) > 90: specStop()

## the other players' cars, where they are now: from the last position each one sent, its speed, heading and how fast
## it turns, carried on over the age of that position (its own clock, see _age); the picture glides to that point
## instead of jumping when a packet is late, lost or early.
func _showRemotes(dt: float, now: int) -> void:
	var tags: bool = G.prefs.get("tags", true)
	var cam: Camera3D = Game.camera
	for r in net.remotes.values():
		if r.car == null: continue
		var g: Node3D = r.car.g
		if not _onRoad(r, now) or net.preloaded:
			g.visible = false; r.shown = false; continue
		if r.car.get("beam") != null: r.car.beam.visible = Game.lampsOn
		var b: Array = r.st
		var age := _age(r, b, now)
		var v := float(b[4])
		var h := float(b[3]) + float(r.yaw) * age
		# its velocity: as it really moved between its last two positions, else along its heading; turning as the car turns
		var vel: Vector2 = r.vel if r.velOk else Vector2(sin(float(b[3])), cos(float(b[3]))) * v
		var vm := vel.rotated(-float(r.yaw) * age * 0.5)
		var vn := vel.rotated(-float(r.yaw) * age)
		var target := Vector3(float(b[0]) + vm.x * age, float(b[1]) + float(r.vy) * age, float(b[2]) + vm.y * age)
		# (more than a few metres off: the car was put back on the road, or the picture was far off: jump, do not glide)
		if not r.shown or r.dp.distance_to(target) > 5.0:
			r.dp = target
			r.dh = h
			r.shown = true
		else:
			# along with the car's own speed, and the rest of the difference a part every frame
			r.dp += Vector3(vn.x, float(r.vy), vn.y) * dt
			r.dp += (target - r.dp) * (1.0 - exp(-dt * 10.0 / maxf(1.0, Engine.time_scale)))
			r.dh = MathX.lerp_angle_(float(r.dh), h, 1.0 - exp(-dt * 14.0 / maxf(1.0, Engine.time_scale)))
		g.visible = true
		g.position = r.dp
		g.rotation = Vector3(0, r.dh, 0)
		for w in r.car.wheels: w.spin.rotation.x += Game.wheelSpin(v, w.r, dt)
		CarKit.autoBrake(r.car, v, dt)
		if r.tag != null:
			var near: bool = tags and cam != null and Game.state != "replay" and cam.global_position.distance_to(r.dp) < 110.0
			r.tag.visible = near

## dots for the minimap: the other players on the road [x, z, Color]
func mapDots() -> Array:
	var out := []
	if net == null or not (net.inRace or net.watch): return out
	for r in net.remotes.values():
		if r.car != null and r.car.g.visible:
			out.append([r.car.g.position.x, r.car.g.position.z, Color(str(r.color)) if Color.html_is_valid(str(r.color)) else Color.WHITE])
	return out

func netRemoteProg(r: Dictionary) -> float:
	if r.done: return _prog(0, 0.0, true, r.ft)
	return _prog(r.lap, r.st[5], false, 0) if r.st != null else -1e9

## bump into the other players' cars (each player handles his own side of a hit)
func netCollide() -> void:
	if net == null or not net.inRace: return
	var now := Time.get_ticks_msec()
	for r in net.remotes.values():
		if not _onRoad(r, now) or not r.shown: continue
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
	if net.spec != null and not net.watch: net.spec = null
	for r in net.remotes.values():
		if r.car != null: r.car.g.visible = false
		r.shown = false
	if net.host and net.raced and not net.final and not net.ref and _othersRacing():
		# the host goes back to the lobby while the others still race: he stays the referee of their race (results,
		# points); his own finish keeps its place, and the bots stay where they were in his results (from now on each
		# player's game drives them, see hostBots)
		net.ref = true
		net.meRow = null
		if Game.raceDone and not Game.playerOut:
			net.meRow = {"p": net.game.me, "n": _dispName(net.game.me, str(G.prefs.nick)), "c": G.settings.car, "f": true, "t": Game.raceFinishTime,
				"g": _prog(0, 0.0, true, Game.raceFinishTime), "b": false}
		net.botRows = []
		for bot in Game.bots:
			net.botRows.append({"p": "", "n": bot.name, "c": bot.type, "f": bot.finished, "t": bot.finishTime if bot.finished else 0.0,
				"g": -1e9 if bot.out else _prog(bot.lap, bot.s, bot.finished, bot.finishTime), "b": true})
		net.game.presence({"st": null, "b": null})
	else:
		# (the host's race is over: who comes in now does not wait for it)
		net.game.presence({"st": null, "b": null, "race": null} if net.host else {"st": null, "b": null})
	changed.emit()

## host: another player is still on the road in this race
func _othersRacing() -> bool:
	for id in net.order:
		var r = net.remotes.get(id)
		if r != null and r.st != null and not r.done and not r.out and not r.off: return true
	return false

## host, refereeing from the lobby: the race is over (final, or nobody left in it)
func _refEnd() -> void:
	net.ref = false
	net.meRow = null
	net.botRows = []
	net.game.presence({"race": null})
	changed.emit()

# ------------------------------------------------------------------ the results: the host decides
## host: the official order of this race. A player counts as finished when the host saw him cover the distance; the
## race is final when every player is in or gone, or FINISH_WAIT after the first one; then come the points.
## force: final now (the host starts the next race before everyone is in: who is still driving gets the place he has)
func _judge(now: int, force := false) -> void:
	if net.final or (now - int(net.resAt) < 250 and not force): return
	var room: NetRoom = net.game
	var rows := []
	var open := 0
	var humans := 0
	if not net.inRace and net.ref and net.meRow != null:
		rows.append(net.meRow)
		humans += 1
		net.firstFin = now if int(net.firstFin) == 0 else net.firstFin
	if net.inRace and Game.state != "menu":
		var fin: bool = Game.raceDone and not Game.playerOut
		rows.append({"p": room.me, "n": _dispName(room.me, str(G.prefs.nick)), "c": G.settings.car, "f": fin, "t": Game.raceFinishTime if fin else 0.0,
			"g": _prog(Game.player.lap, Game.player.s, fin, Game.raceFinishTime), "b": false})
		humans += 1
		if fin: net.firstFin = now if int(net.firstFin) == 0 else net.firstFin
		else: open += 1
	for id in net.order:
		var r = net.remotes.get(id)
		if r == null or (r.st == null and not r.done) or r.off and not r.done: continue
		rows.append({"p": id, "n": r.name, "c": r.carId, "f": r.done, "t": r.ft if r.done else 0.0, "g": netRemoteProg(r), "b": false})
		humans += 1
		if r.done: net.firstFin = now if int(net.firstFin) == 0 else net.firstFin
		elif not r.out: open += 1
	if net.inRace:
		for bot in Game.bots:
			rows.append({"p": "", "n": bot.name, "c": bot.type, "f": bot.finished, "t": bot.finishTime if bot.finished else 0.0,
				"g": -1e9 if bot.out else _prog(bot.lap, bot.s, bot.finished, bot.finishTime), "b": true})
	elif net.ref:
		if humans == 0:
			_refEnd()      # everyone went: no results, no points
			return
		rows.append_array(net.botRows)
	rows.sort_custom(func(a, b): return a.g > b.g)
	var left := -1.0
	if int(net.firstFin) > 0: left = maxf(0.0, FINISH_WAIT - (now - int(net.firstFin)) / 1000.0)
	var final: bool = humans > 0 and (open == 0 or (int(net.firstFin) > 0 and left <= 0.0) or force)
	if Game.state == "countdown" and net.inRace and not force: final = false
	var out := []
	var place := 0
	for x in rows:
		var pts := -1
		if final and not x.b:
			pts = PTS[place] if place < PTS.size() else 0
			place += 1
		out.append([x.p, x.n, x.c, 1 if x.f else 0, snappedf(x.t, 0.01), pts, 1 if x.b else 0])
	var res := {"id": net.raceId, "final": final, "left": int(ceil(left)), "rows": out}
	var js := JSON.stringify(res)
	if js == net.resSent: return
	if not final and now - int(net.resAt) < 700: return
	net.resAt = now
	net.resSent = js
	net.res = res
	if final:
		net.final = true
		# the standings of the evening: [name, points, races, wins, points of the last race]
		var first := true
		for a in out:
			if a[6]: continue
			var u: String = room.uid_at(str(a[0]))
			if u == "": continue
			var e: Array = net.pts.get(u, [a[1], 0, 0, 0, 0])
			net.pts[u] = [a[1], int(e[1]) + int(a[5]), int(e[2]) + 1, int(e[3]) + (1 if first else 0), int(a[5])]
			first = false
		_savePts()
		_planNext()
		room.presence({"res": res, "pts": net.pts, "cfg": _myCfg()})
		if net.ref: _refEnd()
	else:
		room.presence({"res": res})
	changed.emit()

## results as the host sent them: {id, final, left, rows: [[peer, name, car, finished, time, points, bot]]}
static func _resOk(res: Dictionary) -> bool:
	if not NetRoom._num(res.get("id")) or not (res.get("rows") is Array) or res.rows.size() > 24: return false
	for a in res.rows:
		if not (a is Array) or a.size() != 7 or not (a[0] is String) or not (a[1] is String) or not (a[2] is String) or not NetRoom._nums(a.slice(3), 4, 4): return false
	return true

## everyone: the end of the race as the host called it (time is up for who is still driving)
func _raceEnd(now: int) -> void:
	var res = net.res
	if not (res is Dictionary) or int(res.get("id", 0)) != int(net.raceId): return
	var left := int(res.get("left", -1)) if NetRoom._num(res.get("left")) else -1
	if Game.state == "racing" and not Game.raceDone:
		if left > 0 and int(net.warned) == 0:
			net.warned = 1
			var who := ""
			for a in res.rows:
				if a[3] and not a[6]: who = str(a[1]); break
			Hud.showToast("%s is binnen. Nog %d s om te finishen." % [who if who != "" else "De eerste", left])
		elif left > 0 and left <= 10 and int(net.warned) == 1:
			net.warned = 2
			Hud.showToast("Nog %d s." % left)
		if res.get("final", false) == true and not net.forced:
			net.forced = true
			if Game.paused: Game.setPaused(false)
			Hud.showMsg("Tijd is om", "bad", 2)
			Game.showResults()

## the results list of the race for the results screen: the host's official order when there is one, else what this
## game sees itself (`local`, from Game.resultOrder)
func officialRows(local: Array) -> Array:
	if net == null or not net.inRace: return local
	var res = net.res
	if not (res is Dictionary) or int(res.get("id", 0)) != int(net.raceId) or res.rows.is_empty(): return local
	var me: String = net.game.me
	var final: bool = res.get("final", false) == true
	var rows := []
	var mine := false
	for a in res.rows:
		var isMe: bool = str(a[0]) == me
		if isMe: mine = true
		var fin: bool = a[3] != 0
		var row := {"name": "Jij" if isMe else str(a[1]).substr(0, 24), "car": Cars.CARS[a[2]].name if Cars.CARS.has(a[2]) else "", "finished": fin, "ft": float(a[4]),
			"out": false, "elimPos": 0, "prog": -float(rows.size()), "best": Game.raceBestLap if isMe else 0.0}
		if isMe:
			row.me = true
			# my own finish shows at once, also when the host has not heard of it yet
			if Game.raceDone and not fin and not final:
				row.finished = true; row.ft = Game.raceFinishTime
		if final:
			row.pt = "" if a[6] else "+%d" % int(a[5])
			if not fin: row.dnf = "niet gefinisht"
		rows.append(row)
	return rows if mine else local

## the standings of the evening, best first: [{name, pts, races, wins, last, me, here}]
func standings() -> Array:
	var out := []
	if net == null: return out
	var room: NetRoom = net.game
	var here := {}
	var mine := room.my_uid()
	here[mine] = true
	for r in net.remotes.values():
		if r.uid != "": here[r.uid] = true
	for u in net.pts:
		var e: Array = net.pts[u]
		out.append({"name": e[0], "pts": int(e[1]), "races": int(e[2]), "wins": int(e[3]), "last": int(e[4]), "me": u == mine, "here": here.has(u)})
	out.sort_custom(func(a, b): return a.pts > b.pts if a.pts != b.pts else (a.wins > b.wins if a.wins != b.wins else a.name < b.name))
	return out

## host: start the evening's standings again
func resetStandings() -> void:
	if net == null or not net.host: return
	net.pts = {}
	_savePts()
	net.game.presence({"pts": {}})
	netStatus("De stand is gewist.")

# ------------------------------------------------------------------ watching: after the finish, or when you came late
## the cars that can be followed, the ones still racing first, by place: [{key, name, node}]
func specTargets() -> Array:
	var out := []
	if net == null: return out
	var now := Time.get_ticks_msec()
	for r in net.remotes.values():
		if _onRoad(r, now) and r.shown:
			out.append({"key": "p:" + str(r.peer), "name": r.name, "node": r.car.g, "g": netRemoteProg(r), "done": r.done, "bot": false})
	for i in Game.bots.size():
		var b: Mover = Game.bots[i]
		if b.m.g.visible and not b.out:
			out.append({"key": "b:%d" % i, "name": b.name, "node": b.m.g, "g": Game.progressOf(b.lap, b.s, b.finished, b.finishTime), "done": b.finished, "bot": true})
	# the players before the bots, who is still racing before who is in, the leader first
	out.sort_custom(func(a, b):
		if a.bot != b.bot: return not a.bot
		return (a.g > b.g) if a.done == b.done else (not a.done))
	return out

func spectating() -> bool:
	return net != null and net.spec != null

## follow another car (from the results screen: the cars still racing)
func specStart() -> void:
	if net == null or net.spec != null: return
	var ts := specTargets()
	if ts.is_empty(): return
	net.spec = {"key": ts[0].key, "pos": Vector3.ZERO, "look": Vector3.ZERO, "init": false, "at": Vector3.ZERO}
	net.noRoad = 0
	if Game.state == "over": Menu.overOv.visible = false
	changed.emit()

func specStop() -> void:
	if net == null or net.spec == null: return
	if net.watch:
		_watchEnd(true)
		return
	net.spec = null
	if Game.state == "over" and Rep.rp == null: Menu.overOv.visible = true
	changed.emit()

func specNext(d: int) -> void:
	if net == null or net.spec == null: return
	var ts := specTargets()
	if ts.is_empty(): return
	var i := 0
	for k in ts.size():
		if ts[k].key == net.spec.key: i = k
	net.spec.key = ts[(i + d + ts.size()) % ts.size()].key
	net.spec.auto = false
	changed.emit()

## who is being followed ("" when nobody)
func specName() -> String:
	if net == null or net.spec == null: return ""
	for t in specTargets():
		if t.key == net.spec.key: return t.name
	return ""

## from Game.updateCamera: the camera behind the car that is being followed; false = not watching
func specCam(dt: float) -> bool:
	if net == null or net.spec == null: return false
	var ts := specTargets()
	if ts.is_empty(): return false
	var t: Dictionary = ts[0]
	var found := false
	for x in ts:
		if x.key == net.spec.key: t = x; found = true
	# nobody picked yet (or that car is gone): the first player, or a bot until a player's car is there
	if not found or (net.spec.get("auto", true) and t.bot and not ts[0].bot):
		t = ts[0]
		net.spec.key = t.key
	var n: Node3D = t.node
	var f := n.global_transform.basis.z
	f.y = 0
	f = f.normalized() if f.length() > 0.01 else Vector3(0, 0, 1)
	var p := n.global_position
	var want := p - f * 8.5 + Vector3(0, 3.3, 0)
	var look := p + f * 6.0 + Vector3(0, 1.0, 0)
	if Trk.terrain_fn.is_valid():
		want.y = maxf(want.y, Dress.groundY(want.x, want.z) + 1.8)
	var sp: Dictionary = net.spec
	if not sp.init or sp.pos.distance_to(want) > 40.0:
		sp.pos = want; sp.look = look; sp.init = true
	else:
		# along with the car (whatever the frame rate), and easing round to behind it when it turns
		var moved: Vector3 = p - sp.at
		if moved.length() < 30.0:
			sp.pos += moved; sp.look += moved
		var k := 1.0 - exp(-dt * 5.0)
		sp.pos += (want - sp.pos) * k
		sp.look += (look - sp.look) * (1.0 - exp(-dt * 9.0))
	sp.at = p
	var cam: Camera3D = Game.camera
	cam.position = sp.pos
	cam.look_at(sp.look, Vector3.UP)
	if absf(cam.fov - 60.0) > 0.05: cam.fov += (60.0 - cam.fov) * minf(1.0, dt * 4.0)
	if Game.car != null: Game.car.g.visible = Game.state != "menu"
	return true

## a race is on and I am not in it (came late, or went back to the lobby): it can be watched
func canWatch() -> bool:
	if net == null or net.inRace or net.watch or not raceOk(net.race) or int(net.race.id) != int(net.raceId): return false
	var now := Time.get_ticks_msec()
	for r in net.remotes.values():
		if r.st != null and not r.out and now - int(r.t) < 1500: return true
	return false

## watch the race from the lobby: the track, the bots and the players of the host's race, and a camera behind them
func watchStart() -> void:
	if not canWatch() or Game.state != "menu": return
	var race: Dictionary = net.race
	var S := G.settings
	S.track = race.track
	S.dir = "rev" if race.dir == "rev" else "fwd"
	if Trk.TRACK_ID != race.track or Trk.TRACK_DIR != S.dir:
		get_tree().current_scene.load_track(race.track)
	if Env.me != null: Env.me.apply(race.time, race.weather)
	if net == null: return
	Game.clearTraffic()
	# (the host watching the race he left: his bots are driven by each player's own game now, he has no positions of them)
	Game.setupBots(0, [] if net.host else race.bots)
	Game.raceLaps = clampi(int(race.laps), 1, 9)
	net.raceL = Trk.TRACK_LEN
	net.raceS0 = Trk.S_START
	net.raceLaps = Game.raceLaps
	net.watch = true
	net.wspd = {}
	net.botErr = {}
	net.botUpd = -1
	net.preloaded = false
	Menu.hideAll()
	NetUi.ov.visible = false
	net.spec = {"key": "", "pos": Vector3.ZERO, "look": Vector3.ZERO, "init": false, "at": Vector3.ZERO}
	net.noRoad = 0
	changed.emit()

## watching ends: the bots go, the menus come back (reopen: with the online screen)
func _watchEnd(reopen: bool) -> void:
	if net == null or not net.watch: return
	net.watch = false
	net.spec = null
	Game.clearBots()
	for r in net.remotes.values():
		if r.car != null: r.car.g.visible = false
		r.shown = false
	if reopen:
		Menu.showMenu(-1)
		Menu.homePanel("play")
		Menu.netOpen()
	changed.emit()

## watching: the host's bots roll on between its positions (in the menus Game holds bots still, so here)
func _watchTick(dt: float, now: int) -> void:
	var humans := 0
	for r in net.remotes.values():
		if _onRoad(r, now): humans += 1
	net.noRoad = 0 if humans > 0 else int(net.noRoad) + 1
	if int(net.noRoad) > 120:
		# the race is over: back to the lobby
		_watchEnd(true)
		return
	var fresh := botsFresh()
	var k := minf(1.0, dt * 12)
	for i in Game.bots.size():
		var bot: Mover = Game.bots[i]
		var w: Array = net.wspd.get(i, [0.0, 0.0])
		if fresh: bot.s = fposmod(bot.s + float(w[0]) * dt, Trk.TRACK_LEN)
		var e: Vector2 = net.botErr.get(i, Vector2.ZERO)
		if e != Vector2.ZERO:
			var c := e * k
			bot.s = fposmod(bot.s + c.x, Trk.TRACK_LEN)
			bot.lat += c.y
			net.botErr[i] = e - c if (e - c).length() > 0.01 else Vector2.ZERO
		Game.poseOnTrack(bot.m.g, bot.s, bot.lat, float(w[1]))
		for wh in bot.m.wheels: wh.spin.rotation.x += Game.wheelSpin(float(w[0]), wh.r, dt)

# ------------------------------------------------------------------ host migration: the evening goes on without its host
## The host left (reason "end") or fell away (reason "lost", after reconnecting failed). The players that are left
## agree on a new host without talking: the first of the list everyone has (players in the race first, then by seat).
## That one opens the game on its own PC with everything it knows (standings, settings, the race under way); the others
## connect to its address, which the old host told everyone. Who cannot reach it tries the next in the list.
func _migStart(reason: String) -> bool:
	var room: NetRoom = net.game
	var me: String = room.me
	var cands := []
	var ids: Array = net.remotes.keys().filter(func(k): return not net.remotes[k].host and not net.remotes[k].off)
	ids.append(me)
	var racing := func(id) -> bool:
		if not net.inRace: return false
		if id == me: return Game.state != "menu"
		var r: Dictionary = net.remotes[id]
		return r.st != null and not r.out
	ids.sort_custom(func(a, b):
		var ra: bool = racing.call(a); var rb: bool = racing.call(b)
		if ra != rb: return ra
		return int(str(a).substr(1)) < int(str(b).substr(1)))
	for id in ids:
		var s = net.seats.get(id)
		var ip := str(s[1]) if (s is Array and s.size() == 2) else ""
		if id != me and ip == "": continue
		cands.append({"id": id, "ip": ip})
	if cands.is_empty(): return false
	var old := ""
	var known := {}
	var seats := {}
	for k in net.remotes:
		var r: Dictionary = net.remotes[k]
		if r.host: old = r.name; continue
		known[k] = room.presence_of(k).duplicate(true)
		var s2 = net.seats.get(k)
		seats[k] = str(s2[0]) if (s2 is Array and s2.size() == 2) else r.uid
	# the old host's car goes; the others stay as they are until they are back
	for k in net.remotes.keys():
		if net.remotes[k].host:
			if net.remotes[k].car != null: net.remotes[k].car.g.queue_free()
			net.remotes.erase(k)
	net.mig = {"cands": cands, "i": -1, "at": 0, "old": old, "known": known, "seats": seats, "me": me, "why": reason, "tries": 0, "hostAt": 0}
	net.cd = null
	netStatus("%s is weg. Even geduld: het spel zoekt een nieuwe host…" % (old if old != "" else "De host"))
	if not NetUi.is_open(): Hud.showToast("%s is weg. Nieuwe host zoeken…" % (old if old != "" else "De host"))
	_migNext()
	return true

func _migNext() -> void:
	if net == null or net.mig == null: return
	var m: Dictionary = net.mig
	var old: NetRoom = net.game
	m.i = int(m.i) + 1
	if int(m.i) >= m.cands.size():
		net.mig = null
		_leaveToList("De host is weggevallen en een nieuwe host vinden lukte niet. Maak een nieuwe game: de stand van vanavond telt door.", "De host is weggevallen.")
		return
	var c: Dictionary = m.cands[int(m.i)]
	if c.id == m.me:
		if old != null and is_instance_valid(old):
			old.leave()
			get_tree().create_timer(0.6, true, false, true).timeout.connect(old.queue_free)
		m.hostAt = Time.get_ticks_msec()
		m.tries = 0
		_migHost()
		return
	m.at = Time.get_ticks_msec()
	_migDial()

## one attempt to get into the game of the candidate whose turn it is
func _migDial() -> void:
	if net == null or net.mig == null: return
	var m: Dictionary = net.mig
	var c: Dictionary = m.cands[int(m.i)]
	var old: NetRoom = net.game
	if old != null and is_instance_valid(old):
		old.leave()
		get_tree().create_timer(0.6, true, false, true).timeout.connect(old.queue_free)
	var room := NetRoom.new()
	add_child(room)
	net.game = room
	_wire(room)
	# who I am, but not "no car on the track": the race goes on (the new host knows my car from before and would take
	# a st = null for leaving the race)
	var me := _myPresence(false).merged({"rdy": net.rdy, "vote": net.vote}, true)
	for k in ["st", "b", "k", "race", "e"]: me.erase(k)
	room.presence(me)
	if room.start_guest(str(c.ip), onl().tok, str(m.me)) != OK:
		_migNext.call_deferred()
		return
	net.addr = str(c.ip)

## I am the new host: open the game here (the port may still be closing on this PC: try for a few seconds)
func _migHost() -> void:
	if net == null or net.mig == null: return
	var m: Dictionary = net.mig
	for c in get_children():
		if c is NetRoom: c.close_now()
	var room := NetRoom.new()
	add_child(room)
	if room.start_host(G.prefs.nick, onl().tok, str(m.me)) != OK:
		room.queue_free()
		m.tries = int(m.tries) + 1
		if int(m.tries) > 16:
			net.mig = null
			_leaveToList("De host is weggevallen. Overnemen lukte niet: poort %d is bezet op deze pc." % NetRoom.PORT, "De host is weggevallen.")
			return
		get_tree().create_timer(0.3, true, false, true).timeout.connect(_migHost)
		return
	room.adopt(m.seats, m.known)
	net.game = room
	net.host = true
	net.rdy = true
	net.open = true
	net.mig = null
	net.reconn = false
	net.q = {}
	net.seatsSent = ""
	net.resSent = ""
	net.resAt = 0
	net.cdAt = 0
	net.final = net.res is Dictionary and net.res.get("final", false) == true and int(net.res.get("id", 0)) == int(net.raceId)
	# was it the host that fell away, or me? And did another player take over too (the players did not all see the same
	# moment)? Keep asking at the old address and at the others' for a while: a game there with players wins (_probeTick)
	var addrs := []
	if m.why == "lost" and str(net.addr) != "": addrs.append(str(net.addr))
	for c in m.cands:
		if c.id != m.me and str(c.ip) != "" and not str(c.ip) in addrs: addrs.append(str(c.ip))
	if not addrs.is_empty(): _probeStart(addrs)
	# the game goes on with the old host's settings
	var cf: Dictionary = net.cfg
	var S := G.settings
	if TrackDefs.TRACKS.has(str(cf.get("track", ""))): S.track = cf.track
	S.dir = "rev" if cf.get("dir") == "rev" else "fwd"
	if NetRoom._num(cf.get("laps")): S.laps = clampi(int(cf.laps), 1, 5)
	if NetRoom._num(cf.get("bots")): S.bots = clampi(int(cf.bots), 0, 5)
	if Env.TIME_NAMES.has(str(cf.get("time", ""))): S.time = cf.time
	if Env.WEATHER_NAMES.has(str(cf.get("weather", ""))): S.weather = cf.weather
	if net.inRace and net.race is Dictionary:
		S.track = net.race.track; S.dir = "rev" if net.race.dir == "rev" else "fwd"; S.laps = clampi(int(net.race.laps), 1, 9)
	_wire(room)
	var p := _myPresence(true)
	p.merge({"cfg": _myCfg(), "pts": net.pts, "race": net.race if net.inRace else null, "res": net.res}, true)
	room.presence(p)
	net.sentCar = _carKey()
	_game_id = "%08x%08x" % [randi(), randi()]
	lan.serve(_lobby_info)
	netSyncRemotes()
	var t := "%s is weg. Jij bent nu de host: het spel gaat gewoon door." % (m.old if m.old != "" else "De host")
	netStatus(t)
	if not NetUi.is_open(): Hud.showToast(t)
	changed.emit()

## I am in the new host's game
func _migDone() -> void:
	var m: Dictionary = net.mig
	net.mig = null
	net.reconn = false
	var room: NetRoom = net.game
	var t := "%s is weg. %s is nu de host: het spel gaat gewoon door." % [m.old if m.old != "" else "De host", room.hostNick]
	netStatus(t)
	if not NetUi.is_open(): Hud.showToast(t)

## A host that is alone after players fell away (or after it took over from a host that fell away) may be the one whose
## network dropped. It keeps asking at the addresses of the others: when a game with players answers there, this
## player goes back into that game by itself (its seat and points are still there).
func _probeStart(addrs: Array) -> void:
	var u := PacketPeerUDP.new()
	if u.bind(0, "*") != OK: return
	net.probe = {"udp": u, "addrs": addrs, "until": Time.get_ticks_msec() + 120000, "at": 0}

func _probeTick(now: int) -> void:
	var pb: Dictionary = net.probe
	var u: PacketPeerUDP = pb.udp
	var alone := true
	for r in net.remotes.values():
		if not r.off: alone = false
	if not alone or now > int(pb.until):
		u.close()
		net.probe = null
		return
	if now - int(pb.at) > 2000:
		pb.at = now
		for a in pb.addrs:
			if str(a).is_valid_ip_address():
				u.set_dest_address(str(a), LanDiscovery.DISCO_PORT)
				u.put_packet(LanDiscovery.QUERY.to_utf8_buffer())
	while u.get_available_packet_count() > 0:
		var d = NetRoom.parse_json(u.get_packet().get_string_from_utf8())
		var ip := u.get_packet_ip()
		if not (d is Dictionary) or d.get("pr", 0) != 1 or str(d.get("id", "")) == _game_id: continue
		if not NetRoom._num(d.get("v")) or int(d.v) != NetRoom.PROTO or d.get("open", true) != true: continue
		var n := int(d.n) if NetRoom._num(d.get("n")) else 1
		# their game has players, or we are both alone and theirs goes first: join it
		if n > 1 or str(d.get("id", "")) < _game_id:
			var back: bool = Game.state == "menu" and NetUi.is_open()
			if Game.state != "menu": Game.toMenu(-1)
			netLeave()
			netJoin(ip)
			if back or true: Menu.netOpen()
			netStatus("De anderen spelen in %s: je gaat daarheen (je plek en je punten blijven)." % NetRoom._text(d.get("name", "de game"), 40))
			return

func _migTick(now: int) -> void:
	var m: Dictionary = net.mig
	if int(m.at) > 0 and now - int(m.at) > 5000 and not net.game.is_connected_room():
		m.at = 0
		_migNext()

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

# ------------------------------------------------------------------ Windows firewall: look and, when asked, open it
## "" unknown / not Windows, "ok" an allow rule for this game, "block" a block rule (Windows makes one when the
## question "allow access?" is answered with Cancel), "none" no rule yet (Windows will ask)
var fw_state := ""
var _fw: Thread = null

func firewall_check() -> void:
	if OS.get_name() != "Windows" or _fw != null: return
	_fw = Thread.new()
	_fw.start(func():
		var exe := OS.get_executable_path().replace("/", "\\").replace("'", "''")
		var out := []
		var cmd := "$r = Get-NetFirewallApplicationFilter -Program '%s' -ErrorAction SilentlyContinue | Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object { $_.Direction -eq 'Inbound' -and $_.Enabled -eq 'True' }; if (-not $r) { 'none' } elseif ($r | Where-Object { $_.Action -eq 'Block' }) { 'block' } else { 'ok' }" % exe
		var code := OS.execute("powershell", ["-NoProfile", "-NonInteractive", "-Command", cmd], out, false, false)
		var s := "".join(out).strip_edges().to_lower() if code == 0 else ""
		call_deferred("_fw_done", s if s in ["ok", "block", "none"] else ""))

func _fw_done(s: String) -> void:
	_fw.wait_to_finish()
	_fw = null
	if s != fw_state:
		fw_state = s
		changed.emit()

## Windows: ask (with the Windows permission question) to let this game through the firewall on every kind of network.
## Removes this game's own block rules first: a block rule wins from an allow rule.
func firewall_open() -> void:
	if OS.get_name() != "Windows" or _fw != null: return
	_fw = Thread.new()
	_fw.start(func():
		var exe := OS.get_executable_path().replace("/", "\\")
		var inner := "netsh advfirewall firewall delete rule name=all program=\"%s\" & netsh advfirewall firewall add rule name=\"Polderrace 3D\" dir=in action=allow program=\"%s\" enable=yes profile=any" % [exe, exe]
		var cmd := "Start-Process -FilePath cmd.exe -Verb RunAs -WindowStyle Hidden -Wait -ArgumentList '/c', '%s'" % inner.replace("'", "''")
		OS.execute("powershell", ["-NoProfile", "-NonInteractive", "-Command", cmd], [], false, false)
		call_deferred("_fw_reopen"))

func _fw_reopen() -> void:
	_fw.wait_to_finish()
	_fw = null
	fw_state = ""
	firewall_check()

func _exit_tree() -> void:
	if _upnp != null: _upnp.wait_to_finish()
	if _unmap != null: _unmap.wait_to_finish()
	if _fw != null: _fw.wait_to_finish()
	close_internet(true)

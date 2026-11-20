class_name LanDiscovery
extends Node
## Finding games on the local network without codes: a player's game asks "who hosts?" by UDP broadcast every second,
## every host answers with its lobby (name, track, players, open). Only hosts listen on DISCO_PORT, so any number of
## players (and one host) can run on one PC. The answer's sender address is the host's IP to join with ENet.
##
## Real networks get in the way, so there is more than one road, and the game looks at itself:
##  - the question goes to the global broadcast, to every local network's own broadcast address (several sizes), to
##    this PC, and straight to the hosts this player joined before (`extra`);
##  - while nothing is found, the question is also sent one by one to all 254 addresses of each local /24 network
##    (a "sweep": some routers and switches drop broadcasts but pass ordinary packets);
##  - a host also shouts its lobby itself once a second (a "beacon" on BEACON_PORT): a player that hears the beacon but
##    gets no answer to its question knows the host's firewall is closed, and says so;
##  - a host counts who is asking (`searching()`: players that have its game in their list right now) and tests whether
##    its own broadcast comes back to it (`selftest`), so its screen can say "2 players see your game" or what to check.

signal lobbies_changed
signal diag_changed                ## host: the number of searching players or the self-test changed

const DISCO_PORT := 47811
const BEACON_PORT := 47812
const QUERY := "POLDERRACE?1"
const SELFTEST := "POLDERRACE?T"
const BEACON := "POLDERRACE!1"

var _udp: PacketPeerUDP
var _serving := false
var _info := Callable()            ## host: () -> Dictionary lobby info
var _browsing := false
var _t := 0.0
var lobbies := {}                  ## game id -> {ip, name, track, n, max, open, race, v, seen, deaf}
var extra: Array = []              ## player: addresses asked directly (hosts joined before)
var browse_at := 0                 ## player: msec the search started
var sweeps := 0                    ## player: how many sweeps were sent
# host
var selftest := ""                 ## "", "wait", "ok", "fail", "nonet" (this PC has no network at all)
var _searchers := {}               ## "ip:port" -> msec of its last question
var _n_search := 0
var _st_udp: PacketPeerUDP
var _st_nonce := ""
var _st_at := 0
var _st_tries := 0
var _beacon_t := 0.0
# player
var _bc: PacketPeerUDP             ## hears beacons (when the port is free: one game per PC)
var _sweep: Array = []
var _sweep_at := 0

## host: answer queries with info.call()
func serve(info: Callable) -> int:
	stop()
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	var err := _udp.bind(DISCO_PORT, "*")
	if err != OK:
		_udp = null
		return err
	_serving = true
	_info = info
	_searchers.clear()
	_n_search = 0
	_beacon_t = 0.0
	_st_tries = 0
	_selftest_start()
	return OK

## player: look for hosts until stop()
func browse() -> int:
	stop()
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	var err := _udp.bind(0, "*")
	if err != OK:
		_udp = null
		return err
	_bc = PacketPeerUDP.new()
	if _bc.bind(BEACON_PORT, "*") != OK: _bc = null     # another game on this PC listens there already
	_browsing = true
	lobbies.clear()
	_t = 0.0
	browse_at = Time.get_ticks_msec()
	_sweep = []
	_sweep_at = browse_at - 6500        # the first sweep after 1.5 s without a game
	sweeps = 0
	return OK

func stop() -> void:
	for u in [_udp, _bc, _st_udp]:
		if u != null: u.close()
	_udp = null
	_bc = null
	_st_udp = null
	_serving = false
	_browsing = false
	selftest = ""

func is_browsing() -> bool:
	return _browsing

func is_serving() -> bool:
	return _serving

## player: seconds this search has been going on
func browse_secs() -> float:
	return (Time.get_ticks_msec() - browse_at) / 1000.0 if _browsing else 0.0

## host: how many players are looking at the list of games right now (they got our answer: they see this game)
func searching() -> int:
	return _n_search

## where to send the question: the global broadcast, the broadcast address of every local IPv4 network, and this PC.
## Windows sends 255.255.255.255 out of one network card only (with VirtualBox, Hyper-V or a VPN often the wrong one);
## a network's own broadcast address goes out of the card on that network. Godot does not tell the netmask, so the
## usual sizes are all tried (/24 at home, /23 or /22 and /16 on bigger LANs, /8 for 10.x); a wrong guess goes nowhere.
static func targets() -> Array:
	var out := ["255.255.255.255", "127.0.0.1"]
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			var p := a.split(".")
			var ip: int = (int(p[0]) << 24) | (int(p[1]) << 16) | (int(p[2]) << 8) | int(p[3])
			for bits in ([24, 23, 22, 16, 8] if p[0] == "10" else [24, 23, 22, 16]):
				var bc: int = ip | ((1 << (32 - bits)) - 1)
				var b := "%d.%d.%d.%d" % [(bc >> 24) & 255, (bc >> 16) & 255, (bc >> 8) & 255, bc & 255]
				if not b in out:
					out.append(b)
	return out

## this PC's IPv4 addresses, the real network first: VirtualBox, Hyper-V, VPN and other virtual adapters last.
## [{a: address, nm: adapter name, virt: bool, lan: bool (a private home/LAN range)}]
static func adapters() -> Array:
	var found := []
	for it in IP.get_local_interfaces():
		var nm := str(it.get("friendly", it.get("name", "")))
		var low := nm.to_lower()
		var virt := false
		for w in ["virtual", "vbox", "vmware", "vethernet", "hyper-v", "wsl", "docker", "vpn", "tap", "tun", "hamachi", "zerotier", "tailscale", "radmin", "bluetooth", "loopback", "virbr", "wireguard", "nordlynx"]:
			if w in low: virt = true
		for addr in it.get("addresses", []):
			var a := str(addr)
			if a.count(".") != 3 or a.begins_with("127.") or a.begins_with("169.254."): continue
			var b := int(a.get_slice(".", 1))
			var lan: bool = a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and b >= 16 and b < 32)
			var v: bool = virt or a.begins_with("192.168.56.")    # 192.168.56.x: VirtualBox host-only
			found.append({"a": a, "nm": nm, "virt": v, "lan": lan, "k": (2 if v else 0) + (0 if lan else 1)})
	found.sort_custom(func(x, y): return x.k < y.k)
	return found

## every address of the local /24 networks (at most three networks, the real ones first), without our own
static func sweep_targets() -> Array:
	var out := []
	var nets := 0
	for ad in adapters():
		if not ad.lan or nets >= 3: continue
		var pre: String = ad.a.substr(0, ad.a.rfind(".") + 1)
		if (pre + "1") in out or (pre + "2") in out: continue
		nets += 1
		for i in range(1, 255):
			var ip := pre + str(i)
			if ip != ad.a: out.append(ip)
	return out

func _selftest_start() -> void:
	var ts := targets().filter(func(a): return a != "127.0.0.1" and a != "255.255.255.255")
	if ts.is_empty():
		selftest = "nonet"
		return
	if _st_udp == null:
		_st_udp = PacketPeerUDP.new()
		_st_udp.set_broadcast_enabled(true)
		if _st_udp.bind(0, "*") != OK:
			_st_udp = null
			selftest = ""
			return
	selftest = "wait"
	_st_nonce = "%08x" % randi()
	_st_at = Time.get_ticks_msec()
	_st_tries += 1
	for ip in ts + ["255.255.255.255"]:
		_st_udp.set_dest_address(ip, DISCO_PORT)
		_st_udp.put_packet((SELFTEST + _st_nonce).to_utf8_buffer())

func _process(dt: float) -> void:
	if _udp == null:
		return
	var now := Time.get_ticks_msec()
	if _browsing:
		_t -= dt
		if _t <= 0:
			_t = 1.0
			var ts := targets()
			for ip in extra:
				if not ip in ts and str(ip).is_valid_ip_address(): ts.append(ip)
			for k in lobbies:
				if not lobbies[k].ip in ts: ts.append(lobbies[k].ip)
			for ip in ts:
				_udp.set_dest_address(ip, DISCO_PORT)
				_udp.put_packet(QUERY.to_utf8_buffer())
			var gone := false
			for k in lobbies.keys():
				var l: Dictionary = lobbies[k]
				if now - int(l.seen) > 3500 and now - int(l.get("beacon", 0)) > 3500:
					lobbies.erase(k); gone = true
				elif not l.get("deaf", false) and now - int(l.seen) > 3500:
					# only its beacon is heard: it does not answer us
					l.deaf = true; gone = true
			if gone: lobbies_changed.emit()
			if lobbies.is_empty() and _sweep.is_empty() and now - _sweep_at > 8000:
				_sweep = sweep_targets()
				_sweep_at = now
				if not _sweep.is_empty(): sweeps += 1
		# the sweep, a few addresses per frame
		for _i in mini(40, _sweep.size()):
			_udp.set_dest_address(_sweep.pop_back(), DISCO_PORT)
			_udp.put_packet(QUERY.to_utf8_buffer())
		if not lobbies.is_empty(): _sweep = []
	if _serving:
		_beacon_t -= dt
		if _beacon_t <= 0 and _info.is_valid():
			_beacon_t = 1.0
			var pkt := (BEACON + JSON.stringify(_info.call())).to_utf8_buffer()
			for ip in targets():
				_udp.set_dest_address(ip, BEACON_PORT)
				_udp.put_packet(pkt)
			var n := 0
			for k in _searchers.keys():
				if now - int(_searchers[k]) > 3200: _searchers.erase(k)
				else: n += 1
			if n != _n_search:
				_n_search = n
				diag_changed.emit()
		if selftest == "wait" and now - _st_at > 2000:
			if _st_tries < 3: _selftest_start()
			else:
				selftest = "fail"
				diag_changed.emit()
	while _udp != null and _udp.get_available_packet_count() > 0:
		var data := _udp.get_packet().get_string_from_utf8()
		var ip := _udp.get_packet_ip()
		var port := _udp.get_packet_port()
		if _serving:
			if data == QUERY and _info.is_valid():
				_udp.set_dest_address(ip, port)
				_udp.put_packet(JSON.stringify(_info.call()).to_utf8_buffer())
				var key := "%s:%d" % [ip, port]
				if not _searchers.has(key):
					_n_search = _searchers.size() + 1
					_searchers[key] = now
					diag_changed.emit()
				_searchers[key] = now
			elif data.begins_with(SELFTEST) and data.substr(SELFTEST.length()) == _st_nonce and selftest == "wait":
				selftest = "ok"
				diag_changed.emit()
		elif _browsing and data.length() < 4000:
			_answer(JSON.parse_string(data), ip, false)
	while _bc != null and _bc.get_available_packet_count() > 0:
		var data := _bc.get_packet().get_string_from_utf8()
		var ip := _bc.get_packet_ip()
		if _browsing and data.begins_with(BEACON) and data.length() < 4000:
			_answer(JSON.parse_string(data.substr(BEACON.length())), ip, true)

## player: a host's lobby, as its answer to our question or as its beacon
func _answer(d, ip: String, beacon: bool) -> void:
	if not (d is Dictionary) or not (d.get("pr", 0) is float) or d.get("pr", 0) != 1: return
	var now := Time.get_ticks_msec()
	# the same host can answer via several of our targets (and as 127.0.0.1): one entry per game id
	var key := str(d.get("id", ip))
	var known: Dictionary = lobbies.get(key, {})
	var info := {"name": NetRoom._text(d.get("name", "Game"), 40), "track": NetRoom._text(d.get("track", ""), 40),
		"n": int(d.n) if NetRoom._num(d.get("n")) else 1, "max": int(d.max) if NetRoom._num(d.get("max")) else 8,
		"open": d.get("open", true) == true, "race": d.get("race", false) == true, "v": int(d.v) if NetRoom._num(d.get("v")) else 1,
		"laps": int(d.laps) if NetRoom._num(d.get("laps")) else 0, "id": key}
	info.ip = ip if (not known.has("ip") or known.ip == "127.0.0.1") else known.ip
	info.seen = int(known.get("seen", 0))
	info.beacon = int(known.get("beacon", 0))
	info.deaf = known.get("deaf", false)
	if beacon:
		info.beacon = now
		# a beacon alone is not enough to join: ask this address ourselves (see _process); no answer = closed firewall
		if not known.has("first"): info.first = now
		else: info.first = known.first
		if info.seen == 0 and now - int(info.first) > 3000: info.deaf = true
	else:
		info.seen = now
		info.deaf = false
		info.first = known.get("first", now)
	var changed := not lobbies.has(key)
	for f in ["n", "open", "track", "race", "name", "deaf", "v", "laps"]:
		if known.get(f) != info.get(f): changed = true
	lobbies[key] = info
	if changed: lobbies_changed.emit()

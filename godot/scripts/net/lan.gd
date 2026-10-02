class_name LanDiscovery
extends Node
## Finding games on the local network without codes: a player's game asks "who hosts?" by UDP broadcast every second,
## every host answers with its lobby (name, track, players, open). Only hosts listen on DISCO_PORT, so any number of
## players (and one host) can run on one PC. The answer's sender address is the host's IP to join with ENet.

signal lobbies_changed

const DISCO_PORT := 47811
const QUERY := "POLDERRACE?1"

var _udp: PacketPeerUDP
var _serving := false
var _info := Callable()            ## host: () -> Dictionary lobby info
var _browsing := false
var _t := 0.0
var lobbies := {}                  ## "ip" -> {ip, name, track, n, max, open, seen}

## host: answer queries with info.call()
func serve(info: Callable) -> int:
	stop()
	_udp = PacketPeerUDP.new()
	var err := _udp.bind(DISCO_PORT, "*")
	if err != OK:
		_udp = null
		return err
	_serving = true
	_info = info
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
	_browsing = true
	lobbies.clear()
	_t = 0.0
	return OK

func stop() -> void:
	if _udp != null:
		_udp.close()
	_udp = null
	_serving = false
	_browsing = false

## where to send the question: the global broadcast, the /24 broadcast of every local IPv4 address, and this PC
static func targets() -> Array:
	var out := ["255.255.255.255", "127.0.0.1"]
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			var p := a.split(".")
			var b := "%s.%s.%s.255" % [p[0], p[1], p[2]]
			if not b in out:
				out.append(b)
	return out

func _process(dt: float) -> void:
	if _udp == null:
		return
	if _browsing:
		_t -= dt
		if _t <= 0:
			_t = 1.0
			for ip in targets():
				_udp.set_dest_address(ip, DISCO_PORT)
				_udp.put_packet(QUERY.to_utf8_buffer())
			var now := Time.get_ticks_msec()
			var gone := false
			for k in lobbies.keys():
				if now - int(lobbies[k].seen) > 3500:
					lobbies.erase(k); gone = true
			if gone: lobbies_changed.emit()
	while _udp.get_available_packet_count() > 0:
		var data := _udp.get_packet().get_string_from_utf8()
		var ip := _udp.get_packet_ip()
		var port := _udp.get_packet_port()
		if _serving and data == QUERY and _info.is_valid():
			_udp.set_dest_address(ip, port)
			_udp.put_packet(JSON.stringify(_info.call()).to_utf8_buffer())
		elif _browsing:
			var d = JSON.parse_string(data)
			if d is Dictionary and d.get("pr", 0) == 1:
				# the same host can answer via several of our targets (and as 127.0.0.1): one entry per game id
				var key := str(d.get("id", ip))
				var known: Dictionary = lobbies.get(key, {})
				var addr: String = ip if (not known.has("ip") or known.ip == "127.0.0.1") else known.ip
				d.ip = addr
				d.seen = Time.get_ticks_msec()
				var changed: bool = not lobbies.has(key) or known.get("n") != d.get("n") or known.get("open") != d.get("open") or known.get("track") != d.get("track")
				lobbies[key] = d
				if changed: lobbies_changed.emit()

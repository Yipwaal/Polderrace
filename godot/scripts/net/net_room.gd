class_name NetRoom
extends Node
## One online game as a "room" with presence, the interface the HTML game's net code is written against
## (presence(patch), peers(), onPeers(cb), leave()), here over Godot ENet (UDP) instead of the claude.ai room / WebRTC.
## Star topology like the HTML "spelen via host": the host (server) keeps the presence of everyone and relays every change;
## guests only talk to the host. Ids: host "h", guests "g1", "g2", ... (given out by the host).
##
## Messages (JSON on the wire, ENet range coder compression):
##   guest -> host   {t:"hi", v, tok, want}   first message: protocol version, the player's secret token, the seat it had
##                   {t:"p", p}               presence patch (only GUEST_KEYS, every value checked)
##                   {t:"hb"}                 heartbeat (once a second while nothing else is sent)
##                   {t:"bye"}                leaving on purpose (the seat is freed at once)
##   host -> guest   {t:"all", you, host, hid, peers, v}   snapshot for a new or returning guest
##                   {t:"p", id, p}           a presence patch of someone
##                   {t:"f", m:{id: patch}}   the position patches (st, b, k, q) of this frame, all in one packet
##                   {t:"bye", id}            a peer left
##                   {t:"end"} the host left, {t:"full"}, {t:"shut"} closed for new players, {t:"kick"}, {t:"ver", v}
## Patches that only carry positions (FAST_KEYS) go unreliable-ordered on channel 1 (20 per second, newest wins);
## everything else reliable on channel 0.
##
## Seats: a guest is known by uid = hash of its token (the token itself never leaves the host). A guest whose connection
## drops without a goodbye keeps its seat (id and presence, marked "off") for KEEP_MS; when it connects again with the
## same token it is back in the same seat. A guest reconnects by itself for RECONNECT_MS before it gives up.
## After a host change (Net: host migration) the new host expects the old guests in their old seats (adopt()).

signal peers_changed
signal closed(reason: String)
signal joined                      ## guest: the host let us in (we have an id and everyone's presence); also after a reconnect
signal reconnecting                ## guest: the connection dropped, trying again

const PORT := 47810
const MAX_GUESTS := 7
## the version of what goes over the wire: games of another version do not mix (the guest gets a clear message)
const PROTO := 4
const LOOK_MAX := 1000            ## the most characters of JSON a car's look may take (G.lookOf is < 600)
## what a guest may set in its own presence (JS P2P_GUEST_KEYS): everything else is the host's alone
const GUEST_KEYS := ["nick", "car", "color", "look", "rdy", "vote", "e", "st", "k", "pre"]
const FAST_KEYS := ["st", "b", "k", "q"]
## ENet drops a peer that has not answered for this long (ms). A game does not answer while it builds a track (seconds
## on a slow laptop); should that take longer than this, the guest is back in its seat by itself a moment later
## (reconnect), so this can be short enough to notice a host that crashed. A game that closes says goodbye instead.
const TIMEOUT_MIN := 6000
const TIMEOUT_MAX := 10000
const KEEP_MS := 45000             ## host: how long a dropped guest keeps its seat
const RECONNECT_MS := 15000        ## guest: how long it keeps trying to get back
const DIAL_MS := 2500              ## guest: one connection attempt
const MAX_GUEST_PACKET := 6000     ## bytes; a guest's biggest honest packet (car look + name) is well under 3 kB
const MAX_HOST_PACKET := 262144

var host := false
var me := ""                       ## my id ("h" or "gN")
var uid := ""                      ## my public id (hash of my token)
var hostNick := ""
var hostId := "h"                  ## the id of the host (after a host change it keeps its guest id)
var open := true                   ## host: new players may join
var enet: ENetMultiplayerPeer
var up_bps := 0                    ## bytes per second sent / received (measured each second)
var down_bps := 0
var dropped := 0                   ## host: packets of guests thrown away (too big, too many, not valid)
var _presence := {}                ## id -> Dictionary
var _updated := {}                 ## id -> msec of the last patch
var _mine := {}                    ## my own presence (sent again in full after a reconnect)
var _ids := {}                     ## host: ENet peer id -> "gN"
var _seats := {}                   ## host: "gN" -> {uid, pid (0 = not connected), off_at}
var _pending := {}                 ## host: ENet peer id -> msec it connected (has not said hi yet)
var _heard := {}                   ## host: ENet peer id -> msec of its last packet
var _bucket := {}                  ## host: ENet peer id -> [reliable tokens, fast tokens, msec]
var _banned := {}                  ## host: uid -> true (kicked)
var _relay := {}                   ## host: id -> fast patch of this frame
var _next := 1
var _connected := false
var _ever := false                 ## guest: was in the game at least once
var _left := false
var _lost := false
var _closing_at := 0
var _addr := ""
var _tok := ""
var _dial_at := 0
var _retry_at := 0
var _re_until := 0
var _last_tx := 0
var _host_heard := 0
var _stat_at := 0
var _q_at := 0

## the public id that goes with a token
static func uid_of(tok: String) -> String:
	return tok.sha256_text().substr(0, 10)

## host a game on PORT (all interfaces). Returns OK or an error code.
func start_host(nick: String, tok: String, my_id := "h") -> int:
	enet = ENetMultiplayerPeer.new()
	# spare connections: a guest too many is let in just long enough to hear that the game is full, and a guest that
	# reconnects may still have its dead connection here
	var err := enet.create_server(PORT, MAX_GUESTS + 6, 2)
	if err != OK:
		enet = null
		return err
	enet.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	host = true
	me = my_id
	hostId = my_id
	uid = uid_of(tok)
	_tok = tok
	hostNick = nick
	_connected = true
	_ever = true
	enet.peer_connected.connect(_on_guest_connected)
	enet.peer_disconnected.connect(_on_guest_disconnected)
	return OK

## join the game hosted at address (IP or host name). Returns OK when the attempt started; connection is async.
## want: the seat this player had (reconnect after a host change)
func start_guest(address: String, tok: String, want := "") -> int:
	host = false
	_addr = address
	_tok = tok
	uid = uid_of(tok)
	if want != "": me = want
	return _dial()

func _dial() -> int:
	enet = ENetMultiplayerPeer.new()
	var err := enet.create_client(_addr, PORT, 2)
	if err != OK:
		enet = null
		return err
	enet.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	_lost = false
	_dial_at = Time.get_ticks_msec()
	var e := enet
	enet.peer_connected.connect(func(_id):
		if e != enet: return
		_patient(1)
		_raw(1, {"t": "hi", "v": PROTO, "tok": _tok, "want": me}, false)
		enet.host.flush())
	# handled after this frame's packets, so a goodbye ("end") that came with it wins
	enet.peer_disconnected.connect(func(_id):
		if e == enet: _lost = true)
	return OK

## ENet's time-out for this peer: it only gives up when a resend is due, and with its default limit (32) the resends
## grow so far apart that a crashed game stayed for half a minute; 8 keeps them close (about TIMEOUT_MIN)
func _patient(pid: int) -> void:
	var pp := enet.get_peer(pid)
	if pp != null: pp.set_timeout(8, TIMEOUT_MIN, TIMEOUT_MAX)

func is_connected_room() -> bool:
	return _connected and not _left

## guest: the connection dropped and we are trying to get back in
func is_reconnecting() -> bool:
	return _re_until > 0 and not _left

## guest: seconds since the host was last heard (0 while all is well); host: 0
func host_silence() -> float:
	if host or not _connected or _host_heard == 0: return 0.0
	return maxf(0.0, (Time.get_ticks_msec() - _host_heard) / 1000.0)

## updatedAt of a presence: strictly increasing (JS p2pStamp), so every change is seen, also two in one millisecond
var _t := 0
func _stamp() -> int:
	var t := Time.get_ticks_msec()
	_t = t if t > _t else _t + 1
	return _t

# ------------------------------------------------------------------ room interface (as in the HTML game)
func presence(patch: Dictionary) -> void:
	for k in patch:
		_mine[k] = patch[k]
	if _left: return
	if not _connected:
		# a guest before the host gave it a seat (or while reconnecting): everything is sent once it is in
		return
	var p: Dictionary = _presence.get(me, {})
	for k in patch:
		p[k] = patch[k]
	_presence[me] = p
	_updated[me] = _stamp()
	var fast := _fast(patch)
	if host:
		if fast:
			var r: Dictionary = _relay.get(me, {})
			r.merge(patch, true)
			_relay[me] = r
		else:
			_broadcast({"t": "p", "id": me, "p": patch}, false)
	else:
		_raw(1, {"t": "p", "p": patch}, fast)
	# a change (a race that starts, a new car) goes out now instead of at the next frame
	if not fast and _live(): enet.host.flush()
	peers_changed.emit()

## [{peer, presence, sameTab, updatedAt}] like the claude.ai room
func peers() -> Array:
	var out := []
	for id in _presence:
		out.append({"peer": id, "presence": _presence[id], "sameTab": id == me, "updatedAt": _updated.get(id, 0)})
	return out

func presence_of(id: String) -> Dictionary:
	return _presence.get(id, {})

## the goodbye of leave() is still under way: end it now (a new game on this PC needs the port)
func close_now() -> void:
	if _closing_at > 0:
		_closing_at = 0
		if enet != null: enet.close()

## the ENet connection is up (asking a closed one for its host or its packets is an error)
func _live() -> bool:
	return enet != null and enet.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func leave() -> void:
	if _left:
		return
	if _live() and _connected and not is_reconnecting():
		# say goodbye (on the wire right away, also when the window closes now) and keep the connection a moment,
		# so the others get it before the disconnect
		if host:
			if not _ids.is_empty():
				_broadcast({"t": "end"}, false)
				enet.host.flush()
				_closing_at = Time.get_ticks_msec() + 400
		else:
			_raw(1, {"t": "bye"}, false)
			enet.host.flush()
			_closing_at = Time.get_ticks_msec() + 250
	_left = true
	_presence.clear()
	if enet != null and _closing_at == 0:
		enet.close()

# ------------------------------------------------------------------ host: players
## host: this guest goes out of the game and cannot come back in this game
func kick(id: String) -> void:
	if not host or not _seats.has(id): return
	var s: Dictionary = _seats[id]
	_banned[s.uid] = true
	if int(s.pid) != 0:
		_raw(int(s.pid), {"t": "kick"}, false)
		var pp := enet.get_peer(int(s.pid))
		if pp != null: pp.peer_disconnect_later()
	_remove_seat(id)

## host: the address of a guest as the host sees it (the others need it when this guest becomes the host)
func address_of(id: String) -> String:
	if not host or not _seats.has(id) or int(_seats[id].pid) == 0: return ""
	var pp := enet.get_peer(int(_seats[id].pid))
	return pp.get_remote_address() if pp != null else ""

## host: the uid of a seat ("" when unknown)
func uid_at(id: String) -> String:
	if id == me: return uid
	return str(_seats[id].uid) if _seats.has(id) else ""

## host after a host change: the guests of the old host are expected back in their old seats (id -> uid), with what
## was known about them (shown as "off" until they are back)
func adopt(seats: Dictionary, known: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	for id in seats:
		if id == me or str(seats[id]) == "": continue
		# a little shorter than a dropped guest: they come over within seconds, or not at all
		_seats[id] = {"uid": str(seats[id]), "pid": 0, "off_at": now - KEEP_MS + 20000}
		var p: Dictionary = known.get(id, {}).duplicate(true)
		p.uid = str(seats[id])
		p.off = true
		p.erase("host")
		_presence[id] = p
		_updated[id] = _stamp()
		var n := int(str(id).substr(1)) if str(id).begins_with("g") else 0
		_next = maxi(_next, n + 1)
	if me.begins_with("g"): _next = maxi(_next, int(me.substr(1)) + 1)

func _remove_seat(id: String) -> void:
	if not _seats.has(id): return
	var pid := int(_seats[id].pid)
	_seats.erase(id)
	if pid != 0: _ids.erase(pid)
	_presence.erase(id)
	_updated.erase(id)
	_relay.erase(id)
	_broadcast({"t": "bye", "id": id}, false)
	peers_changed.emit()

# ------------------------------------------------------------------ transport
static func _fast(patch: Dictionary) -> bool:
	for k in patch:
		if not k in FAST_KEYS:
			return false
	return true

func _raw(to: int, msg: Dictionary, fast: bool) -> void:
	if enet == null or _left:
		return
	if enet.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED: return
	enet.set_target_peer(to)
	enet.transfer_channel = 1 if fast else 0
	enet.transfer_mode = MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED if fast else MultiplayerPeer.TRANSFER_MODE_RELIABLE
	enet.put_packet(JSON.stringify(msg).to_utf8_buffer())
	_last_tx = Time.get_ticks_msec()

func _broadcast(msg: Dictionary, fast: bool, except := 0) -> void:
	for pid in _ids:
		if pid != except:
			_raw(pid, msg, fast)

func _on_guest_connected(pid: int) -> void:
	_patient(pid)
	_pending[pid] = Time.get_ticks_msec()
	_heard[pid] = Time.get_ticks_msec()

func _on_guest_disconnected(pid: int) -> void:
	_pending.erase(pid)
	_heard.erase(pid)
	_bucket.erase(pid)
	var gid: String = _ids.get(pid, "")
	_ids.erase(pid)
	if gid == "" or not _seats.has(gid) or int(_seats[gid].pid) != pid:
		return     # never seated, already gone (goodbye, kick), or back on a new connection
	# no goodbye: the connection dropped (Wi-Fi, a crash). The seat waits for it.
	var s: Dictionary = _seats[gid]
	s.pid = 0
	s.off_at = Time.get_ticks_msec()
	_set_host_key(gid, "off", true)

## host: a field of a guest's presence that only the host sets (uid, off)
func _set_host_key(id: String, k: String, v) -> void:
	var p: Dictionary = _presence.get(id, {})
	p[k] = v
	_presence[id] = p
	_updated[id] = _stamp()
	_broadcast({"t": "p", "id": id, "p": {k: v}}, false)
	peers_changed.emit()

## host: a guest introduces itself; it gets its old seat back, a new one, or a reason why not
func _hello(pid: int, msg: Dictionary) -> void:
	if _ids.has(pid): return
	_pending.erase(pid)
	var bye := func(reason: Dictionary) -> void:
		_raw(pid, reason, false)
		var pp := enet.get_peer(pid)
		if pp != null: pp.peer_disconnect_later()     # after the message
	if int(msg.get("v", 0)) != PROTO:
		bye.call({"t": "ver", "v": PROTO}); return
	var tok := str(msg.get("tok", ""))
	if tok.length() < 8 or tok.length() > 64:
		bye.call({"t": "full"}); return
	var u := uid_of(tok)
	if _banned.has(u):
		bye.call({"t": "kick"}); return
	var now := Time.get_ticks_msec()
	# its old seat: one of this token that is not connected, or whose connection is dead (ENet has not noticed yet).
	# A seat of this token with a lively connection is another game on the same save file (two games on one PC,
	# testing): then this is a second player ("uid-2"), not a returning one.
	var gid := ""
	var taken := u == uid
	for g in _seats:
		var su := str(_seats[g].uid)
		if su != u and not su.begins_with(u + "-"): continue
		var old := int(_seats[g].pid)
		if old == 0 or now - int(_heard.get(old, 0)) >= 2500:
			if gid == "" or old == 0: gid = g
		elif su == u: taken = true
	if gid != "":
		u = str(_seats[gid].uid)
		var old := int(_seats[gid].pid)
		if old != 0:
			_ids.erase(old)
			var pp := enet.get_peer(old)
			if pp != null: pp.peer_disconnect_now()
	if gid == "":
		if taken:
			var n2 := 2
			while _uid_taken("%s-%d" % [u, n2]): n2 += 1
			u = "%s-%d" % [u, n2]
		if not open:
			bye.call({"t": "shut"}); return
		if _seats.size() >= MAX_GUESTS:
			bye.call({"t": "full"}); return
		gid = "g%d" % _next
		while _seats.has(gid) or gid == me:
			_next += 1
			gid = "g%d" % _next
		_next += 1
		_seats[gid] = {"uid": u, "pid": pid, "off_at": 0}
		_presence[gid] = {"uid": u}
		_updated[gid] = _stamp()
		_broadcast({"t": "p", "id": gid, "p": {"uid": u}}, false)
	else:
		_seats[gid].pid = pid
		_seats[gid].off_at = 0
		var p: Dictionary = _presence.get(gid, {})
		p.erase("off")
		p.uid = u
		_presence[gid] = p
		_updated[gid] = _stamp()
		_broadcast({"t": "p", "id": gid, "p": {"off": false}}, false)
	_ids[pid] = gid
	_heard[pid] = now
	_raw(pid, {"t": "all", "you": gid, "host": hostNick, "hid": me, "peers": _presence, "v": PROTO}, false)
	enet.host.flush()
	peers_changed.emit()

func _uid_taken(u: String) -> bool:
	if u == uid: return true
	for g in _seats:
		if _seats[g].uid == u: return true
	return false

## host: at most this many packets per guest (a game sends 20 position packets a second and now and then a change)
func _allow(pid: int, fast: bool) -> bool:
	var now := Time.get_ticks_msec()
	var b: Array = _bucket.get(pid, [40.0, 90.0, now])
	var dt := (now - int(b[2])) / 1000.0
	b[0] = minf(40.0, float(b[0]) + dt * 20.0)
	b[1] = minf(90.0, float(b[1]) + dt * 45.0)
	b[2] = now
	var i := 1 if fast else 0
	var ok: bool = b[i] >= 1.0
	if ok: b[i] -= 1.0
	_bucket[pid] = b
	return ok

func _process(_dt: float) -> void:
	if enet == null:
		# guest between two attempts to reconnect
		if not host and not _left and _retry_at > 0 and Time.get_ticks_msec() >= _retry_at:
			_retry_at = 0
			if _dial() != OK: _dropped()
		return
	var now := Time.get_ticks_msec()
	if _closing_at > 0:
		if _live(): enet.poll()
		if now >= _closing_at or not _live():
			_closing_at = 0
			enet.close()
		return
	if _left:
		return
	if not host:
		var st := enet.get_connection_status()
		if st == MultiplayerPeer.CONNECTION_DISCONNECTED or (not _connected and now - _dial_at > DIAL_MS and (_ever or now - _dial_at > 6000)):
			# ENet gave up by itself (no route to that address, or the attempt timed out)
			_dropped()
			return
	enet.poll()
	while enet != null and not _left and enet.get_available_packet_count() > 0:
		var from := enet.get_packet_peer()
		var raw := enet.get_packet()
		if host:
			_heard[from] = now
			if raw.size() > MAX_GUEST_PACKET:
				dropped += 1
				continue
		elif raw.size() > MAX_HOST_PACKET:
			continue
		else:
			_host_heard = now
		var msg = parse_json(raw.get_string_from_utf8())
		if not (msg is Dictionary):
			dropped += 1
			continue
		_handle(from, msg)
	if _left or enet == null: return
	if _lost and not host:
		_dropped()
		return
	if host:
		_host_tick(now)
	elif _connected and now - _last_tx > 1000:
		_raw(1, {"t": "hb"}, true)
	if now - _stat_at >= 1000 and _live():
		var secs := maxf(0.2, (now - _stat_at) / 1000.0)
		_stat_at = now
		up_bps = int(enet.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA) / secs)
		down_bps = int(enet.host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA) / secs)

func _host_tick(now: int) -> void:
	# this frame's position patches of everyone: one packet per guest
	if not _relay.is_empty():
		for pid in _ids:
			var own: String = _ids[pid]
			if _relay.size() == 1 and _relay.has(own): continue
			var m := {}
			for id in _relay:
				if id != own: m[id] = _relay[id]
			_raw(pid, {"t": "f", "m": m}, true)
		_relay.clear()
	# who never said hi goes; a dropped guest's seat is given up after a while
	for pid in _pending.keys():
		if now - int(_pending[pid]) > 4000:
			_pending.erase(pid)
			var pp := enet.get_peer(pid)
			if pp != null: pp.peer_disconnect_now()
	for g in _seats.keys():
		var s: Dictionary = _seats[g]
		if int(s.pid) == 0 and now - int(s.off_at) > KEEP_MS:
			_remove_seat(g)
	# connection quality of every guest, once a second: [ping ms, loss %, seconds silent]
	if now - _q_at >= 1000:
		_q_at = now
		var q := {}
		for g in _seats:
			var pid := int(_seats[g].pid)
			var pp := enet.get_peer(pid) if pid != 0 else null
			if pp == null:
				q[g] = [-1, 0, 99]
			else:
				q[g] = [int(pp.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)), snappedf(pp.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS) / 655.36, 0.1),
					snappedf(minf(99, (now - int(_heard.get(pid, now))) / 1000.0), 0.1)]
		presence({"q": q})

## my public id as the host knows it (two games on one save file: the second one is "uid-2")
func my_uid() -> String:
	return str(_presence.get(me, {}).get("uid", uid))

## guest: ping to the host in ms (-1 when not connected)
func my_ping() -> int:
	if host or not _live() or not _connected or is_reconnecting(): return -1
	var pp := enet.get_peer(1)
	return int(pp.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)) if pp != null else -1

## guest: the connection is gone. Before we were in: the attempt failed. After: try again for a while.
func _dropped() -> void:
	if _left: return
	var now := Time.get_ticks_msec()
	if enet != null: enet.close()
	enet = null
	_lost = false
	if not _ever:
		_close("fail")
		return
	if _re_until == 0:
		_re_until = now + RECONNECT_MS
		_connected = false
		reconnecting.emit()
	if now > _re_until:
		_re_until = 0
		_close("lost")
		return
	_retry_at = now + 600

func _handle(from: int, msg: Dictionary) -> void:
	var t = msg.get("t", "")
	if host:
		if t is String and t == "hi":
			_hello(from, msg)
			return
		var id: String = _ids.get(from, "")
		if id == "": return
		if t is String and t == "bye":
			var pp := enet.get_peer(from)
			if pp != null: pp.peer_disconnect_later()
			_remove_seat(id)
			return
		if not (t is String and t == "p"): return     # (a heartbeat only shows the guest is alive)
		var raw = msg.get("p")
		if not (raw is Dictionary):
			dropped += 1
			return
		# a guest can only patch itself, and only its own keys, each of the right shape
		var patch := clean(raw, true)
		if patch.is_empty(): return
		var fast := _fast(patch)
		if not _allow(from, fast):
			dropped += 1
			return
		var p: Dictionary = _presence.get(id, {})
		for k in patch:
			p[k] = patch[k]
		_presence[id] = p
		_updated[id] = _stamp()
		if fast:
			var r: Dictionary = _relay.get(id, {})
			r.merge(patch, true)
			_relay[id] = r
		else:
			_broadcast({"t": "p", "id": id, "p": patch}, false, from)
		peers_changed.emit()
		return
	if not (t is String): return
	match t:
		"p":
			_apply(str(msg.get("id", "")), msg.get("p"))
			peers_changed.emit()
		"f":
			var m = msg.get("m")
			if m is Dictionary:
				for id in m: _apply(str(id), m[id])
				peers_changed.emit()
		"all":
			if int(msg.get("v", 1)) != PROTO:
				_close("version")    # another version of the game: its races would not match ours
				return
			var ps = msg.get("peers")
			if not (ps is Dictionary) or not (msg.get("you") is String): return
			me = str(msg.you)
			hostNick = str(msg.get("host", "")).substr(0, 24)
			hostId = str(msg.get("hid", "h"))
			_presence = {}
			for id in ps:
				if ps[id] is Dictionary and str(id) != "": _presence[str(id)] = clean(ps[id], false)
			for id in _presence:
				_updated[id] = _stamp()
			_connected = true
			_ever = true
			_re_until = 0
			_host_heard = Time.get_ticks_msec()
			# everything about me, as it is now (the host may know an older me, or nothing yet)
			var mine := _mine.duplicate()
			if not mine.is_empty(): presence(mine)
			joined.emit()
			peers_changed.emit()
		"bye":
			var id := str(msg.get("id", ""))
			if id != me:
				_presence.erase(id)
				peers_changed.emit()
		"end":
			_close("end")
		"full":
			_close("full")
		"shut":
			_close("shut")
		"kick":
			_close("kick")
		"ver":
			_close("version")

## guest: a patch of someone else, as the host passed it on
func _apply(id: String, raw) -> void:
	if id == "" or id == me or not (raw is Dictionary): return
	var patch := clean(raw, false)
	if patch.is_empty(): return
	var p: Dictionary = _presence.get(id, {})
	for k in patch:
		if k == "off" and patch[k] == false: p.erase(k)
		else: p[k] = patch[k]
	_presence[id] = p
	_updated[id] = _stamp()

## JSON from the wire: null when it is not JSON (quietly: JSON.parse_string prints an error for every broken packet)
static func parse_json(text: String):
	var j := JSON.new()
	return j.data if j.parse(text) == OK else null

func _close(reason: String) -> void:
	if _left:
		return
	_re_until = 0
	# first tell, then leave: who listens may still need what this room knew (a host change takes the others' presence along)
	closed.emit(reason)
	leave()

# ------------------------------------------------------------------ what may be in a presence
## Every value that comes off the wire is checked here before anything else sees it: the right type, a sensible size,
## plain numbers. A packet that is wrong (a bug, another program, someone trying) loses its bad fields; it never
## reaches the game code as something unexpected. guest: only the keys a guest may set.
static func clean(patch: Dictionary, guest: bool) -> Dictionary:
	var out := {}
	for k in patch:
		if not (k is String): continue
		if guest and not k in GUEST_KEYS: continue
		var v = patch[k]
		match k:
			"nick":
				var s := _text(v, 24)
				if s != "": out[k] = s
			"car", "vote", "uid":
				if v is String and v.length() <= 24: out[k] = _text(v, 24)
			"color":
				if v is String and v.length() <= 9 and Color.html_is_valid(v): out[k] = v
			"rdy", "host", "off":
				if v is bool: out[k] = v
			"pre":
				if _num(v): out[k] = int(v)
			"st":
				if v == null or _nums(v, 11, 16): out[k] = v
			"b":
				if v == null: out[k] = v
				elif v is Array and v.size() <= 16:
					var ok := true
					for q in v:
						if not _nums(q, 7, 10): ok = false
					if ok: out[k] = v
			"k":
				if v is Array and v.size() <= 8:
					var ks := []
					for q in v:
						if q is Dictionary and _num(q.get("q")) and _num(q.get("r")) and _num(q.get("i")) and _num(q.get("x")) and _num(q.get("z")) and _num(q.get("s")):
							ks.append({"q": q.q, "r": q.r, "i": q.i, "x": q.x, "z": q.z, "s": q.s})
					out[k] = ks
			"e":
				if v is Array and v.size() == 2 and _num(v[0]):
					if _num(v[1]): out[k] = [v[0], int(v[1])]
					elif v[1] is String:
						var s := _text(v[1], 60)
						if s != "": out[k] = [v[0], s]
			"look":
				if v is Dictionary: out[k] = clean_look(v)
			"q", "pts", "seats", "cfg":
				if v is Dictionary: out[k] = v
			"race", "cd", "res":
				if v == null or v is Dictionary: out[k] = v
	return out

## a car's looks as they go over the wire: a flat list of plain numbers, booleans and short strings
static func clean_look(v: Dictionary) -> Dictionary:
	var out := {}
	var n := 0
	for key in v:
		# (a key set as d.paint = … is a StringName: the same as text here)
		if not (key is String or key is StringName) or str(key).length() > 20: continue
		var k := str(key)
		var x = v[key]
		if _num(x) or x is bool: out[k] = x
		elif (x is String or x is StringName) and str(x).length() <= 40: out[k] = _text(str(x), 40)
		else: continue
		n += 1
		if n >= 64: break     # (the catalogue has 40 items now; LOOK_MAX keeps it small anyway)
	if JSON.stringify(out).length() > LOOK_MAX: return {}
	return out

static func _num(v) -> bool:
	return (v is float or v is int) and not is_nan(v) and not is_inf(v)

static func _nums(a, lo: int, hi: int) -> bool:
	if not (a is Array) or a.size() < lo or a.size() > hi: return false
	for v in a:
		if not _num(v): return false
	return true

## a short line of text without control characters ("" when v is no text)
static func _text(v, n: int) -> String:
	if not (v is String): return ""
	var s := ""
	for i in mini(v.length(), n * 2):
		var c: int = v.unicode_at(i)
		if c >= 32 and c != 127 and not (c >= 0x200b and c <= 0x200f) and not (c >= 0x202a and c <= 0x202e): s += v[i]
	return s.strip_edges().substr(0, n)

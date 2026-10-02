class_name NetRoom
extends Node
## One online game as a "room" with presence, the interface the HTML game's net code is written against
## (presence(patch), peers(), onPeers(cb), leave()), here over Godot ENet (UDP) instead of the claude.ai room / WebRTC.
## Star topology like the HTML "spelen via host": the host (server) keeps the presence of everyone and relays every change;
## guests only talk to the host. Ids: host "h", guests "g1", "g2", ... (given out by the host).
## Messages (JSON on the wire): {t:"p", id, p} presence patch, {t:"all", you, peers, v} snapshot for a new guest,
## {t:"bye", id} a peer left, {t:"end"} the host closed the game, {t:"full"} no room left.
## Patches that only carry positions (st, b, k) go unreliable-ordered on channel 1 (20 per second, newest wins);
## everything else reliable on channel 0.

signal peers_changed
signal closed(reason: String)
signal joined                      ## guest: the host let us in (we have an id and everyone's presence)

const PORT := 47810
const MAX_GUESTS := 7
## the version of what goes over the wire: games of another version do not mix (the guest gets a clear message)
const PROTO := 2
## what a guest may set in its own presence (JS P2P_GUEST_KEYS): "host" and "race" are the host's alone
const GUEST_KEYS := ["nick", "car", "color", "st", "k"]
## ENet drops a peer that has not answered for this long (ms). A game does not answer while it builds a track (seconds
## on a slow laptop), so this is generous; a game that closes says goodbye right away instead.
const TIMEOUT_MIN := 12000
const TIMEOUT_MAX := 20000

var host := false
var me := ""                       ## my id ("h" or "gN")
var hostNick := ""
var enet: ENetMultiplayerPeer
var _presence := {}                ## id -> Dictionary
var _updated := {}                 ## id -> msec of the last patch
var _ids := {}                     ## host: ENet peer id -> "gN"
var _next := 1
var _connected := false
var _left := false
var _lost := false
var _closing_at := 0

## host a game on PORT (all interfaces). Returns OK or an error code.
func start_host(nick: String) -> int:
	enet = ENetMultiplayerPeer.new()
	# one spare connection, so a guest too many is let in just long enough to hear that the game is full
	var err := enet.create_server(PORT, MAX_GUESTS + 1, 2)
	if err != OK:
		return err
	host = true
	me = "h"
	hostNick = nick
	_connected = true
	enet.peer_connected.connect(_on_guest_connected)
	enet.peer_disconnected.connect(_on_guest_disconnected)
	return OK

## join the game hosted at address (IP or host name). Returns OK when the attempt started; connection is async.
func start_guest(address: String) -> int:
	enet = ENetMultiplayerPeer.new()
	var err := enet.create_client(address, PORT, 2)
	if err != OK:
		return err
	host = false
	enet.peer_connected.connect(func(_id): _patient(1))
	# handled after this frame's packets, so a goodbye ("end") that came with it wins
	enet.peer_disconnected.connect(func(_id): _lost = true)
	return OK

## ENet's time-out for this peer: it only gives up when a resend is due, and with its default limit (32) the resends
## grow so far apart that a crashed game stayed for half a minute; 8 keeps them close (about TIMEOUT_MIN)
func _patient(pid: int) -> void:
	var pp := enet.get_peer(pid)
	if pp != null: pp.set_timeout(8, TIMEOUT_MIN, TIMEOUT_MAX)

func is_connected_room() -> bool:
	return _connected and not _left

## updatedAt of a presence: strictly increasing (JS p2pStamp), so every change is seen, also two in one millisecond
var _t := 0
func _stamp() -> int:
	var t := Time.get_ticks_msec()
	_t = t if t > _t else _t + 1
	return _t

# ------------------------------------------------------------------ room interface (as in the HTML game)
func presence(patch: Dictionary) -> void:
	if me == "":
		# a guest before the host gave it an id: keep it, it is sent as soon as the snapshot arrives
		var early: Dictionary = _presence.get("", {})
		early.merge(patch, true)
		_presence[""] = early
		return
	var p: Dictionary = _presence.get(me, {})
	for k in patch:
		p[k] = patch[k]
	_presence[me] = p
	_updated[me] = _stamp()
	var msg := {"t": "p", "id": me, "p": patch}
	var fast := _fast(patch)
	if host:
		_broadcast(msg, fast)
	elif _connected:
		_send(1, msg, fast)
	# a change (a race that starts, a new car) goes out now instead of at the next frame
	if not fast and enet != null and not _left: enet.host.flush()
	peers_changed.emit()

## [{peer, presence, sameTab, updatedAt}] like the claude.ai room
func peers() -> Array:
	var out := []
	for id in _presence:
		out.append({"peer": id, "presence": _presence[id], "sameTab": id == me, "updatedAt": _updated.get(id, 0)})
	return out

## the goodbye of leave() is still under way: end it now (a new game on this PC needs the port)
func close_now() -> void:
	if _closing_at > 0:
		_closing_at = 0
		enet.close()

func leave() -> void:
	if _left:
		return
	if enet != null and host and not _ids.is_empty():
		# say goodbye (on the wire right away, also when the window closes now) and keep the connection a moment,
		# so the guests get the "end" before the disconnect
		_broadcast({"t": "end"}, false)
		enet.host.flush()
		_closing_at = Time.get_ticks_msec() + 400
	_left = true
	_presence.clear()
	if enet != null and _closing_at == 0:
		enet.close()

# ------------------------------------------------------------------ transport
static func _fast(patch: Dictionary) -> bool:
	for k in patch:
		if not k in ["st", "b", "k"]:
			return false
	return true

func _send(to: int, msg: Dictionary, fast: bool) -> void:
	if enet == null or _left:
		return
	enet.set_target_peer(to)
	enet.transfer_channel = 1 if fast else 0
	enet.transfer_mode = MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED if fast else MultiplayerPeer.TRANSFER_MODE_RELIABLE
	enet.put_packet(JSON.stringify(msg).to_utf8_buffer())

func _broadcast(msg: Dictionary, fast: bool, except := 0) -> void:
	for pid in _ids:
		if pid != except:
			_send(pid, msg, fast)

func _on_guest_connected(pid: int) -> void:
	_patient(pid)
	if _ids.size() >= MAX_GUESTS:
		_send(pid, {"t": "full"}, false)
		enet.get_peer(pid).peer_disconnect_later()    # after the message
		return
	var gid := "g%d" % _next
	_next += 1
	_ids[pid] = gid
	_send(pid, {"t": "all", "you": gid, "host": hostNick, "peers": _presence, "v": PROTO}, false)

func _on_guest_disconnected(pid: int) -> void:
	var gid: String = _ids.get(pid, "")
	_ids.erase(pid)
	if gid != "":
		_presence.erase(gid)
		_updated.erase(gid)
		_broadcast({"t": "bye", "id": gid}, false)
		peers_changed.emit()

func _process(_dt: float) -> void:
	if enet == null:
		return
	if _closing_at > 0:
		enet.poll()
		if Time.get_ticks_msec() >= _closing_at:
			_closing_at = 0
			enet.close()
		return
	if _left:
		return
	if not host and enet.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		# ENet gave up by itself (no route to that address, or the attempt timed out)
		_close("lost" if _connected else "fail")
		return
	enet.poll()
	while enet.get_available_packet_count() > 0:
		var from := enet.get_packet_peer()
		var raw := enet.get_packet()
		var msg = JSON.parse_string(raw.get_string_from_utf8())
		if not (msg is Dictionary):
			continue
		_handle(from, msg)
	if _lost and not _left:
		_close("lost")

func _handle(from: int, msg: Dictionary) -> void:
	match msg.get("t", ""):
		"p":
			var id := str(msg.get("id", ""))
			var patch: Dictionary = msg.get("p") if msg.get("p") is Dictionary else {}
			if host:
				id = _ids.get(from, "")   # a guest can only patch itself, and only its own keys
				if id == "":
					return
				var own := {}
				for k in patch:
					if k in GUEST_KEYS: own[k] = patch[k]
				patch = own
				msg = {"t": "p", "id": id, "p": patch}
			elif id == "" or id == me:
				return
			var p: Dictionary = _presence.get(id, {})
			for k in patch:
				p[k] = patch[k]
			_presence[id] = p
			_updated[id] = _stamp()
			if host:
				_broadcast(msg, _fast(patch), from)
			peers_changed.emit()
		"all":
			if int(msg.get("v", 1)) != PROTO:
				_close("version")    # another version of the game: its races would not match ours
				return
			me = msg.get("you", "")
			hostNick = msg.get("host", "")
			var mine: Dictionary = _presence.get("", {})
			_presence = msg.get("peers", {})
			_presence.erase("")
			for id in _presence:
				_updated[id] = _stamp()
			_connected = true
			if not mine.is_empty():
				presence(mine)
			joined.emit()
			peers_changed.emit()
		"bye":
			_presence.erase(msg.get("id", ""))
			peers_changed.emit()
		"end":
			_close("end")
		"full":
			_close("full")

func _close(reason: String) -> void:
	if _left:
		return
	leave()
	closed.emit(reason)

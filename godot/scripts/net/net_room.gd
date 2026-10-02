class_name NetRoom
extends Node
## One online game as a "room" with presence, the interface the HTML game's net code is written against
## (presence(patch), peers(), onPeers(cb), leave()), here over Godot ENet (UDP) instead of the claude.ai room / WebRTC.
## Star topology like the HTML "spelen via host": the host (server) keeps the presence of everyone and relays every change;
## guests only talk to the host. Ids: host "h", guests "g1", "g2", ... (given out by the host).
## Messages (JSON on the wire): {t:"p", id, p} presence patch, {t:"all", you, peers} snapshot for a new guest,
## {t:"bye", id} a peer left, {t:"end"} the host closed the game, {t:"full"} no room left.
## Patches that only carry positions (st, b, k) go unreliable-ordered on channel 1 (20 per second, newest wins);
## everything else reliable on channel 0.

signal peers_changed
signal closed(reason: String)

const PORT := 47810
const MAX_GUESTS := 7

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
	var err := enet.create_server(PORT, MAX_GUESTS, 2)
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
	# handled after this frame's packets, so a goodbye ("end") that came with it wins
	enet.peer_disconnected.connect(func(_id): _lost = true)
	return OK

func is_connected_room() -> bool:
	return _connected and not _left

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
	_updated[me] = Time.get_ticks_msec()
	var msg := {"t": "p", "id": me, "p": patch}
	if host:
		_broadcast(msg, _fast(patch))
	elif _connected:
		_send(1, msg, _fast(patch))
	peers_changed.emit()

## [{peer, presence, sameTab, updatedAt}] like the claude.ai room
func peers() -> Array:
	var out := []
	for id in _presence:
		out.append({"peer": id, "presence": _presence[id], "sameTab": id == me, "updatedAt": _updated.get(id, 0)})
	return out

func leave() -> void:
	if _left:
		return
	if enet != null and host and not _ids.is_empty():
		# say goodbye and keep the connection a moment, so the guests get the "end" before the disconnect
		_broadcast({"t": "end"}, false)
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
	if _ids.size() >= MAX_GUESTS:
		_send(pid, {"t": "full"}, false)
		return
	var gid := "g%d" % _next
	_next += 1
	_ids[pid] = gid
	_send(pid, {"t": "all", "you": gid, "host": hostNick, "peers": _presence}, false)

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
	enet.poll()
	if not host and not _connected and enet.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		pass   # waits for the "all" snapshot, which gives our id
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
			var id: String = msg.get("id", "")
			if host:
				id = _ids.get(from, "")   # a guest can only patch itself
				if id == "":
					return
				msg.id = id
			var p: Dictionary = _presence.get(id, {})
			var patch: Dictionary = msg.get("p", {})
			for k in patch:
				p[k] = patch[k]
			_presence[id] = p
			_updated[id] = Time.get_ticks_msec()
			if host:
				_broadcast(msg, _fast(patch), from)
			peers_changed.emit()
		"all":
			me = msg.get("you", "")
			hostNick = msg.get("host", "")
			var mine: Dictionary = _presence.get("", {})
			_presence = msg.get("peers", {})
			_presence.erase("")
			for id in _presence:
				_updated[id] = Time.get_ticks_msec()
			_connected = true
			if not mine.is_empty():
				presence(mine)
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

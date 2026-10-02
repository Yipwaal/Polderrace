extends RefCounted
## Plays the real game scene (res://scenes/main.tscn) like a player: real input events through Input.parse_input_event
## (keys with keycode and physical keycode, mouse clicks on the centre of a button, the mouse wheel to scroll a list),
## real frames (the game runs its own _process), the race driven with the keys (W plus A/D, steered like the autopilot
## of tests/test_laps.gd, R when the car faces the wrong way). Used by tests/test_play.gd.
## Errors that the engine logs while it plays (SCRIPT ERROR, ERROR) are collected by an own Logger.

var tree: SceneTree
var main: Node = null
var r: TestReport
var shots := ""             ## directory for screenshots (empty: none; only with a display)
var held := {}              ## keycodes held down by the driver
var log: ErrLog
var _err_seen := 0

## every error the engine logs (script errors, push_error, engine errors), with where it came from
class ErrLog extends Logger:
	var errors: Array[String] = []
	var last := ""            ## what the driver did last (a click, a key)
	var mx := Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, bt: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING: return
		# the dummy renderer of a headless run complains about a material freed with its mesh (the OpenGL renderer does not)
		if "rendering/dummy/" in file: return
		var where := ""
		for b in bt:
			if b.get_frame_count() > 0: where += " <- " + " <- ".join(range(mini(4, b.get_frame_count())).map(func(i): return "%s:%d %s" % [b.get_frame_file(i).get_file(), b.get_frame_line(i), b.get_frame_function(i)]))
		mx.lock()
		errors.append("%s (%s:%d %s) %s%s [na: %s]" % [code, file.get_file(), line, function, rationale, where, last])
		mx.unlock()
	func _log_message(_message: String, _error: bool) -> void:
		pass

func _init(t: SceneTree, rep: TestReport) -> void:
	tree = t
	r = rep
	log = ErrLog.new()
	OS.add_logger(log)
	shots = OS.get_environment("PLAY_SHOTS")
	if DisplayServer.get_name() == "headless": shots = ""
	if shots != "": DirAccess.make_dir_recursive_absolute(shots)

func done() -> void:
	OS.remove_logger(log)

## errors logged since the last call: each becomes a FOUT line (where: what the driver was doing)
func check_errors(where: String) -> bool:
	var n := log.errors.size()
	var fresh := log.errors.slice(_err_seen, n)
	_err_seen = n
	if fresh.is_empty(): return true
	for e in fresh.slice(0, 5): print("     ", e)
	return r.check(false, "geen fouten in de uitvoer: " + where, "%d fout(en), eerste: %s" % [fresh.size(), fresh[0]])

# ------------------------------------------------------------------ the game scene
## start the game scene on a save file of its own (data: {key: value} as the JS stores them), wait for the home screen
func boot(store: String, data: Dictionary, size := Vector2i(1280, 720)) -> void:
	await resize(size.x, size.y)
	G.use_store(store, data)
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	tree.current_scene = main
	await until(func(): return Game.state == "menu" and Game.car != null and Menu.home.visible, 60.0)
	await frames(3)

## "start the game again" on what it saved: the save file read back like a fresh start (G.use_store), home screen anew
func relaunch(store: String) -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(G.STORE_PATH))
	G.use_store(store, d if d is Dictionary else {})
	Game.toMenu(-1)
	await frames(3)

func frame() -> void:
	await tree.process_frame

func frames(n: int) -> void:
	for _i in n: await tree.process_frame

## seconds of game time (Game.clock; while paused, real seconds scaled by Engine.time_scale)
func wait(sec: float) -> void:
	var c0: float = Game.clock
	var t0 := Time.get_ticks_msec()
	while true:
		var real := (Time.get_ticks_msec() - t0) / 1000.0
		if Game.paused and real * Engine.time_scale >= sec: break
		if not Game.paused and Game.clock - c0 >= sec: break
		if real > 600: break
		await tree.process_frame

## frames until cond() holds, at most max_s real seconds; false when it never did
func until(cond: Callable, max_s := 10.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > max_s * 1000.0: return false
		await tree.process_frame
	return true

func shot(name: String) -> void:
	if shots == "": return
	await frames(2)
	await RenderingServer.frame_post_draw
	var p := "%s/%s.png" % [shots, name]
	tree.root.get_texture().get_image().save_png(p)
	print("     screenshot ", p)

func resize(w: int, h: int) -> void:
	tree.root.size = Vector2i(w, h)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(Vector2i(w, h))
	await frames(4)

# ------------------------------------------------------------------ keyboard
func key_event(code: Key, pressed: bool, mods := "", echo := false) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	e.echo = echo
	e.shift_pressed = "shift" in mods
	e.alt_pressed = "alt" in mods
	e.ctrl_pressed = "ctrl" in mods
	if "right" in mods: e.location = KEY_LOCATION_RIGHT
	elif code == KEY_SHIFT or code == KEY_CTRL or code == KEY_ALT: e.location = KEY_LOCATION_LEFT
	if pressed:
		if code >= KEY_A and code <= KEY_Z: e.unicode = code + (0 if "shift" in mods else 32)
		elif (code >= KEY_0 and code <= KEY_9) or code == KEY_SPACE: e.unicode = code
	Input.parse_input_event(e)

## press and release a key (one frame between)
func tap(code: Key, mods := "") -> void:
	log.last = "toets " + OS.get_keycode_string(code)
	key_event(code, true, mods)
	await frame()
	key_event(code, false, mods)
	await frames(2)

func hold(code: Key, on: bool, mods := "") -> void:
	var k := "%d%s" % [code, mods]
	if on == held.has(k): return
	if on: held[k] = [code, mods]
	else: held.erase(k)
	key_event(code, on, mods)

func release_all() -> void:
	for k in held.keys():
		key_event(held[k][0], false, held[k][1])
	held.clear()

## type text into the focused field (digits and letters)
func type_text(s: String) -> void:
	for ch in s:
		var code: Key = (ch.to_upper().unicode_at(0)) as Key
		key_event(code, true)
		await frame()
		key_event(code, false)
		await frame()

# ------------------------------------------------------------------ mouse
func mouse_move(p: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)

func _mouse_button(p: Vector2, idx: MouseButton, pressed: bool) -> void:
	var b := InputEventMouseButton.new()
	b.button_index = idx
	b.position = p
	b.global_position = p
	b.pressed = pressed
	if pressed: b.button_mask = MOUSE_BUTTON_MASK_LEFT if idx == MOUSE_BUTTON_LEFT else 0
	Input.parse_input_event(b)

## the control under the mouse at p (after moving there)
func hovered_at(p: Vector2) -> Control:
	mouse_move(p)
	await frames(2)
	return tree.root.gui_get_hovered_control()

## scroll the list around c with the mouse wheel until c is inside it (a real player scrolls to a button below)
func scroll_to(c: Control) -> void:
	var sc: ScrollContainer = null
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer and p.is_visible_in_tree():
			sc = p
			break
		p = p.get_parent()
	if sc == null: return
	for _i in 60:
		var view := sc.get_global_rect()
		var cr := c.get_global_rect()
		if view.encloses(cr) or (cr.size.y > view.size.y and view.has_point(cr.get_center())): return
		var down := cr.get_center().y > view.get_center().y
		var at := view.get_center()
		_mouse_button(at, MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP, true)
		_mouse_button(at, MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP, false)
		await frames(2)

## click a button like a player: scroll it into view, move the mouse onto its centre, press and release there.
## A FOUT when it is not visible, outside the window, or something else lies on top of it.
func click(c: Control, label := "") -> bool:
	var what := label if label != "" else _name_of(c)
	log.last = "klik " + what
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		return r.check(false, "klik: " + what + " is zichtbaar")
	await frames(3)        # a panel that just opened lays itself out and scrolls its chosen item into view first
	if not is_instance_valid(c) or not c.is_visible_in_tree():
		return r.check(false, "klik: " + what + " blijft staan")
	await scroll_to(c)
	var p := c.get_global_rect().get_center()
	var vp := tree.root.get_visible_rect()
	if not vp.has_point(p):
		return r.check(false, "klik: " + what + " ligt in het venster", "midden %s, venster %s" % [p, vp.size])
	var h := await hovered_at(p)
	if not (h == c or (h != null and c.is_ancestor_of(h))):
		return r.check(false, "klik: " + what + " is bereikbaar met de muis", "eronder: %s" % _name_of(h))
	_mouse_button(p, MOUSE_BUTTON_LEFT, true)
	await frame()
	_mouse_button(p, MOUSE_BUTTON_LEFT, false)
	await frames(2)
	return true

func _name_of(c) -> String:
	if c == null: return "niets"
	if not is_instance_valid(c): return "(weg)"
	var l := _first_label(c)
	return "%s \"%s\"" % [c.get_class(), l] if l != "" else str(c)

func _first_label(n: Node) -> String:
	if n is Label: return n.text
	if n is Button: return n.text
	for ch in n.get_children():
		var t := _first_label(ch)
		if t != "": return t
	return ""

## the first visible button under n with a text that contains t
func find_btn(n: Node, t: String) -> Control:
	for c in n.find_children("*", "", true, false):
		if (c is UiKit.Btn or c is BaseButton) and c.is_visible_in_tree() and t in _all_text(c):
			return c
	return null

func _all_text(n: Node) -> String:
	var s: String = n.text if (n is Label or n is Button) else ""
	for ch in n.get_children(): s += " " + _all_text(ch)
	return s

func focused() -> Control:
	return tree.root.gui_get_focus_owner()

# ------------------------------------------------------------------ driving with the keys
var _wrong := 0.0
var resets := 0

## one frame of driving for player 1 (W A S D) and, in split screen, player 2 (arrows): gas, steer like the autopilot
func drive_keys(p2 := false) -> void:
	var g := Game
	if g.state != "racing" and g.state != "countdown":
		hold(KEY_A, false); hold(KEY_D, false)
		return
	hold(KEY_W, true)
	var st := _steer_of(g.player)
	hold(KEY_D, st > 0.12)
	hold(KEY_A, st < -0.12)
	var th := Trk.heading_of(Trk.T[g.player.idx])
	var df := fposmod(th - g.player.heading + PI, TAU) - PI
	_wrong = _wrong + 1.0 / 60 if absf(df) > 2.1 and g.state == "racing" else 0.0
	if _wrong > 1.5:
		_wrong = 0
		resets += 1
		await tap(KEY_R)
	if p2 and g.split and g.p2 != null:
		hold(KEY_UP, true)
		var st2 := _steer_of(g.p2.pl)
		hold(KEY_RIGHT, st2 > 0.12)
		hold(KEY_LEFT, st2 < -0.12)

func _steer_of(pl) -> float:
	var th := Trk.heading_of(Trk.T[pl.idx])
	var df := fposmod(th - pl.heading + PI, TAU) - PI
	return clampf(-df * 3 - pl.lat * 0.15, -1, 1)

## drive until cond() holds, at most max_s seconds of game time (a slow software renderer gets as long as it needs, up
## to 20 real minutes); keys are let go afterwards
func drive_until(cond: Callable, max_s := 120.0, p2 := false) -> bool:
	var c0: float = Game.clock
	var t0 := Time.get_ticks_msec()
	var ok := true
	while not cond.call():
		if Game.clock - c0 > max_s or Time.get_ticks_msec() - t0 > 1200000:
			ok = false
			break
		await drive_keys(p2)
		await tree.process_frame
	release_all()
	await frame()
	return ok

## frames until cond() holds, at most max_s seconds of game time
func until_game(cond: Callable, max_s := 60.0) -> bool:
	var c0: float = Game.clock
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Game.clock - c0 > max_s or Time.get_ticks_msec() - t0 > 1200000: return false
		await tree.process_frame
	return true

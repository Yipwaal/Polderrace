extends CanvasLayer
## Autoload "Hud": the race HUD of the HTML game (time/position sign, minimap, lap board, gauge, start lights, messages,
## toast, big count). Same look: ANWB-blue signs, yellow detour pills, Nunito.
## The menus, the pause and the results screens are in Menu (scripts/ui/menu.gd); setPaused / toMenu /
## showTimeTrialOver forward to it.

const SIGN := Color("#1d4f9e")
const SIGN_INK := Color("#f7f7f2")
const DETOUR := Color("#f2c200")
const INK := Color("#161a22")
const ALERT := Color("#c8302a")
const LAB := Color("#bcd0f0")
const SUB := Color("#d6e0f3")

var root: Control
var hud: Control
var time_sign: SignBox
var lbl: Label
var big: Label
var lapT: Label
var dist: Label
var map_sign: SignBox
var minimap: MiniMap
var board: SignBox
var board_list: VBoxContainer
var gauge: Gauge
var msg: PanelContainer
var msg_label: Label
var toast: PanelContainer
var toast_label: Label
var count: Label
var lights: PanelContainer
var light_dots: Array = []
var toast_layer: CanvasLayer

var msgUntil := 0.0
var countUntil := 0.0
var toastT := 0.0
var lightsOff := 0.0
var boardAt := 0.0
var _hT := ""
var _hL := ""
var _hD := ""

# ------------------------------------------------------------------ fonts & styles
static func font(spec: String) -> Array:
	return Canvas2D.font_of(spec)

static func mk_label(text: String, spec: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	var f := font(spec)
	l.add_theme_font_override("font", f[0])
	l.add_theme_font_size_override("font_size", int(f[1]))
	l.add_theme_color_override("font_color", col)
	return l

static func pill(bg: Color, radius := 999) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 24; s.content_margin_right = 24; s.content_margin_top = 12; s.content_margin_bottom = 12
	s.shadow_color = Color(0.04, 0.08, 0.16, 0.45); s.shadow_size = 10; s.shadow_offset = Vector2(0, 8)
	return s

## the blue road-sign panel (CSS .sign: blue, rounded 20, a white line 3-5 px inside the edge)
class SignBox extends PanelContainer:
	var bg := Color("#1d4f9e")
	func _init(pad := Vector4(18, 14, 18, 14)) -> void:
		var s := StyleBoxEmpty.new()
		s.content_margin_left = pad.x; s.content_margin_top = pad.y; s.content_margin_right = pad.z; s.content_margin_bottom = pad.w
		add_theme_stylebox_override("panel", s)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var a := StyleBoxFlat.new()
		a.bg_color = bg; a.set_corner_radius_all(20)
		a.shadow_color = Color(0.04, 0.08, 0.16, 0.5); a.shadow_size = 12; a.shadow_offset = Vector2(0, 8)
		draw_style_box(a, r)
		var b := StyleBoxFlat.new()
		b.draw_center = false; b.border_color = Color("#f7f7f2"); b.set_border_width_all(2); b.set_corner_radius_all(17)
		draw_style_box(b, r.grow(-3))

# ------------------------------------------------------------------ build
func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_hud()
	hud.visible = false

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	time_sign = SignBox.new()
	time_sign.position = Vector2(16, 16)
	time_sign.custom_minimum_size = Vector2(110, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	time_sign.add_child(v)
	lbl = mk_label("TIJD", "800 11px Nunito", LAB)
	big = mk_label("30", "900 42px Nunito", SIGN_INK)
	lapT = mk_label("Ronde 1", "800 14px Nunito", SIGN_INK)
	dist = mk_label("0,0 km", "800 14px Nunito", SIGN_INK)
	for c in [lbl, big, lapT, dist]: v.add_child(c)
	hud.add_child(time_sign)
	map_sign = SignBox.new(Vector4(12, 12, 12, 12))
	map_sign.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	map_sign.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	map_sign.position = Vector2(-16 - 156, 16)
	minimap = MiniMap.new()
	minimap.custom_minimum_size = Vector2(132, 132)
	map_sign.add_child(minimap)
	hud.add_child(map_sign)
	board = SignBox.new(Vector4(10, 12, 10, 10))
	board.position = Vector2(16, 160)
	board.custom_minimum_size = Vector2(200, 0)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 1)
	board.add_child(bv)
	bv.add_child(mk_label("  SNELSTE RONDEN", "800 11px Nunito", LAB))
	board_list = VBoxContainer.new()
	board_list.add_theme_constant_override("separation", 1)
	bv.add_child(board_list)
	hud.add_child(board)
	gauge = Gauge.new()
	gauge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	gauge.size = Vector2(184, 184)
	gauge.position = Vector2(-16 - 184, -16 - 184)
	hud.add_child(gauge)
	# message pill, toast, big count, start lights
	msg = PanelContainer.new()
	msg_label = mk_label("", "900 22px Nunito", INK)
	msg.add_child(msg_label)
	msg.visible = false
	root.add_child(msg)
	toast = PanelContainer.new()
	toast.add_theme_stylebox_override("panel", _toast_style())
	toast_label = mk_label("", "800 15px Nunito", Color.WHITE)
	toast.add_child(toast_label)
	toast.visible = false
	# the toast shows above the menus and the results board (CSS z-index 31): its own layer over Menu's
	toast_layer = CanvasLayer.new()
	toast_layer.layer = 31
	add_child(toast_layer)
	toast_layer.add_child(toast)
	count = mk_label("", "italic 900 150px Nunito", Color.WHITE)
	count.set_anchors_preset(Control.PRESET_FULL_RECT)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.add_theme_color_override("font_shadow_color", SIGN)
	count.add_theme_constant_override("shadow_offset_y", 6)
	count.add_theme_constant_override("shadow_offset_x", 0)
	count.visible = false
	root.add_child(count)
	lights = PanelContainer.new()
	var ls := pill(INK)
	ls.content_margin_left = 16; ls.content_margin_right = 16
	lights.add_theme_stylebox_override("panel", ls)
	var lh := HBoxContainer.new()
	lh.add_theme_constant_override("separation", 10)
	lights.add_child(lh)
	for _k in 5:
		var d := LightDot.new()
		d.custom_minimum_size = Vector2(34, 34)
		lh.add_child(d)
		light_dots.append(d)
	lights.visible = false
	root.add_child(lights)

func _toast_style() -> StyleBoxFlat:
	var s := pill(Color(0.086, 0.1, 0.133, 0.85))
	s.content_margin_left = 16; s.content_margin_right = 16; s.content_margin_top = 8; s.content_margin_bottom = 8
	s.shadow_size = 0
	return s

class LightDot extends Control:
	var on := false
	var go := false
	func _draw() -> void:
		var c := size / 2
		var col := Color("#2fd35a") if go else (Color("#ff2a1f") if on else Color("#3b1414"))
		if on or go:
			draw_circle(c, size.x / 2 + 6, Color(col, 0.25))
		draw_circle(c, size.x / 2, Color("#0b0d12"))
		draw_circle(c, size.x / 2 - 3, col)

## a plain pill button (the online screen NetUi uses it)
static func mk_button(text: String, cta := true) -> Button:
	var b := Button.new()
	b.text = text
	var f := font("900 18px Nunito")
	b.add_theme_font_override("font", f[0])
	b.add_theme_font_size_override("font_size", int(f[1]))
	var n := pill(DETOUR if cta else Color(1, 1, 1, 0.1))
	n.content_margin_top = 10; n.content_margin_bottom = 10; n.shadow_size = 0
	var h := n.duplicate(); h.bg_color = Color("#ffd83d") if cta else Color(1, 1, 1, 0.2)
	var fo := h.duplicate(); fo.border_color = SIGN_INK; fo.set_border_width_all(3)
	for st in [["normal", n], ["hover", h], ["pressed", h], ["focus", fo]]:
		b.add_theme_stylebox_override(st[0], st[1])
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, INK if cta else SIGN_INK)
	return b

# ------------------------------------------------------------------ API used by Game
func showMsg(text: String, kind: String, dur: float) -> void:
	if Game.split and Game.p2 != null and Game.activeP == 2 and SplitView.me != null:
		SplitView.me.showMsg2(text, kind, dur); return
	msg_label.text = text
	msg_label.add_theme_color_override("font_color", Color.WHITE if kind == "bad" else (SIGN_INK if kind == "sec" else INK))
	msg.add_theme_stylebox_override("panel", pill(ALERT if kind == "bad" else (SIGN if kind == "sec" else DETOUR)))
	msg.visible = true
	msgUntil = Game.clock + dur

func showCount(text: String, dur: float) -> void:
	count.text = text
	count.visible = true
	countUntil = Game.clock + dur if dur > 0 else 0.0

func showToast(t: String) -> void:
	toast_label.text = t
	toast.visible = true
	toastT = Game.clock + 1.4

func raceStart(raceMode: bool, mode: String) -> void:
	lbl.text = "POSITIE" if raceMode else ("RONDETIJD" if mode == "ghost" else "TIJD")
	for d in light_dots:
		d.on = false; d.go = false; d.queue_redraw()
	lights.visible = true
	lightsOff = 0
	msg.visible = false
	Menu.hideAll()
	hud.visible = true
	minimap.build()
	_hT = ""; _hL = ""; _hD = ""

func setLights(on: int) -> void:
	for k in light_dots.size():
		light_dots[k].on = k < on
		light_dots[k].queue_redraw()

func lightsGo() -> void:
	for d in light_dots:
		d.on = false; d.go = true; d.queue_redraw()
	lightsOff = Game.clock + 0.9
	showCount("GO!", 0.8)

func setPaused(p: bool) -> void:
	Menu.setPausedUI(p)

func toMenu() -> void:
	for o in [hud, msg, count, lights, toast]: o.visible = false

func touchHeld(_a: String) -> bool:
	return false

func showTimeTrialOver(distance: float, cps: int, bestLap: float, best: float, rec: bool, cr: int) -> void:
	Menu.showTimeTrialOver(distance, cps, bestLap, best, rec, cr)

# ------------------------------------------------------------------ per frame (JS hud())
func tick() -> void:
	var g := Game
	var st := g.state
	var vp := root.get_viewport_rect().size
	msg.position = Vector2((vp.x - msg.size.x) / 2, vp.y * 0.22)
	toast.position = Vector2((vp.x - toast.size.x) / 2, vp.y * 0.78 - toast.size.y)
	lights.position = Vector2((vp.x - lights.size.x) / 2, vp.y * 0.15)
	var hh: float = vp.y / 2 if g.split and g.p2 != null else vp.y
	gauge.size = Vector2(132, 132) if hh < vp.y else Vector2(184, 184)
	map_sign.position = Vector2(vp.x - 16 - map_sign.size.x, 16)
	gauge.position = Vector2(vp.x - 16 - gauge.size.x, hh - (10 if hh < vp.y else 16) - gauge.size.y)
	if st == "racing" or st == "countdown" or st == "finished":
		var t: String
		var l: String
		var d: String
		var dc := SIGN_INK
		if g.mode == "elim":
			var act: int = g.activeBots().size() + (0 if g.playerOut else 1)
			t = "%d/%d" % [g.playerPosition(), g.bots.size() + 1 if g.playerOut else act]
			l = "Ronde %d" % maxi(1, g.player.lap)
			d = "Laatste valt af!" if not g.playerOut and g.playerPosition() == act and act > 1 else G.fmtLap(g.raceFinishTime if g.raceDone else g.raceTime)
			if d == "Laatste valt af!": dc = Color("#ffd0cc")
		elif g.mode == "ghost":
			t = G.fmtLap(g.raceTime - g.lapStart) if g.player.lap >= 1 and not g.raceDone else (G.fmtLap(g.lapTimes[-1] if not g.lapTimes.is_empty() else 0.0) if g.raceDone else "0:00,0")
			l = "Ronde %d/%d" % [clampi(maxi(1, g.player.lap), 1, g.raceLaps), g.raceLaps]
			var gd = null if g.raceDone else Rep.ghostDelta()
			if gd == null:
				d = ("Ghost " + G.fmtLap(Rep.ghostBest.t)) if Rep.ghostBest != null else "Nog geen ghost"
			else:
				d = G.fmtD(gd) + " s"
				dc = Color("#9df0a8") if gd <= 0 else Color("#ffb4ab")
		elif g.raceMode:
			t = "%d/%d" % [g.playerPosition(), g.bots.size() + 1 + Net.racers() + (1 if g.split and g.p2 != null else 0)]
			l = "Ronde %d/%d" % [clampi(maxi(1, g.player.lap), 1, g.raceLaps), g.raceLaps]
			d = G.fmtLap(g.raceFinishTime if g.raceDone else g.raceTime)
		else:
			t = str(maxi(0, int(ceil(g.timeLeft))))
			l = "Ronde %d" % (g.player.lap + 1)
			d = G.fmtKm(g.distance)
		dist.add_theme_color_override("font_color", dc)
		if t != _hT: _hT = t; big.text = t
		if l != _hL: _hL = l; lapT.text = l
		if d != _hD: _hD = d; dist.text = d
		time_sign.bg = ALERT if g.mode == "time" and g.timeLeft < 6 and st == "racing" else SIGN
		time_sign.queue_redraw()
		minimap.queue_redraw()
		gauge.queue_redraw()
	_update_board()
	if lightsOff and g.clock > lightsOff: lights.visible = false; lightsOff = 0
	if toastT and g.clock > toastT: toast.visible = false; toastT = 0
	if msgUntil and g.clock > msgUntil: msg.visible = false; msgUntil = 0
	if countUntil and g.clock > countUntil: count.visible = false; countUntil = 0

func _update_board() -> void:
	var g := Game
	var on: bool = (g.raceMode or g.mode == "ghost") and not g.split and (g.state == "racing" or g.state == "countdown" or g.state == "finished")
	board.visible = on
	if not on or g.clock < boardAt: return
	boardAt = g.clock + 0.5
	var rows := [{"name": "Jij", "best": g.raceBestLap, "me": true, "out": g.playerOut, "prog": -1e9 if g.playerOut else g.progressOf(g.player.lap, g.player.s, g.raceDone, g.raceFinishTime)}]
	if Net.inRace():
		for r in Net.net.remotes.values():
			if r.st != null: rows.append({"name": r.name, "best": 0, "prog": Net.netRemoteProg(r)})
	for b in g.bots:
		rows.append({"name": b.name, "best": b.bestLap, "out": b.out, "prog": -1e9 if b.out else g.progressOf(b.lap, b.s, b.finished, b.finishTime)})
	rows.sort_custom(func(a, b): return a.prog > b.prog)
	var fastest := 1e9
	for r in rows:
		if r.best > 0: fastest = minf(fastest, r.best)
	for c in board_list.get_children(): c.queue_free()
	for k in mini(9, rows.size()):
		var r: Dictionary = rows[k]
		var me: bool = r.get("me", false)
		var pc := PanelContainer.new()
		var st := pill(DETOUR if me else Color(0, 0, 0, 0))
		st.content_margin_top = 3; st.content_margin_bottom = 3; st.content_margin_left = 8; st.content_margin_right = 8; st.shadow_size = 0
		pc.add_theme_stylebox_override("panel", st)
		pc.modulate.a = 0.55 if r.out else 1.0
		var h := HBoxContainer.new()
		pc.add_child(h)
		var col := INK if me else SIGN_INK
		var a := mk_label("%d." % (k + 1), "700 13px Nunito", col); a.custom_minimum_size = Vector2(20, 0)
		var n := mk_label(r.name, "800 13px Nunito" if me else "700 13px Nunito", col); n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fast: bool = r.best > 0 and r.best == fastest
		var t := mk_label("eruit" if r.out else (G.fmtLap(r.best) if r.best > 0 else "–"), "800 13px Nunito",
			(Color("#5a2ea6") if me else Color("#c9a8ff")) if fast else (INK if me else SUB))
		for c in [a, n, t]: h.add_child(c)
		board_list.add_child(pc)

# ------------------------------------------------------------------ minimap (JS buildMinimap / drawMinimap)
class MiniMap extends Control:
	var p2 := false                ## split screen: draw from player 2's point of view
	var pts := PackedVector2Array()
	var S := 1.0
	var ox := 0.0
	var oz := 0.0
	func build() -> void:
		var W := custom_minimum_size.x
		var x0 := 1e9; var x1 := -1e9; var z0 := 1e9; var z1 := -1e9
		for p in Trk.P:
			x0 = minf(x0, p.x); x1 = maxf(x1, p.x); z0 = minf(z0, p.z); z1 = maxf(z1, p.z)
		var pad := W * 0.1
		var span := W - 2 * pad
		S = span / maxf(x1 - x0, z1 - z0)
		ox = pad - x0 * S + (span - (x1 - x0) * S) / 2
		oz = pad - z0 * S + (span - (z1 - z0) * S) / 2
		pts = PackedVector2Array()
		var i := 0
		while i <= Trk.NS:
			var p: Vector3 = Trk.P[i % Trk.NS]
			pts.append(Vector2(p.x * S + ox, p.z * S + oz))
			i += 4
	func _draw() -> void:
		if p2: Game.asP2(paint)
		else: paint()
	func paint() -> void:
		if pts.size() < 2: return
		var W := custom_minimum_size.x
		var u := W / 132.0
		draw_polyline(pts, Color(0.97, 0.97, 0.95, 0.95), maxf(3, W * 0.035), true)
		var dot := func(x: float, z: float, r: float, c: Color, st: bool) -> void:
			var q := Vector2(x * S + ox, z * S + oz)
			if st: draw_circle(q, r + u, Color("#161a22"))
			draw_circle(q, r, c)
		var g := Game
		for c in g.traffic: dot.call(c.m.g.position.x, c.m.g.position.z, 2.2 * u, Color("#9fb0c8"), false)
		for b in g.bots:
			if b.m.g.visible: dot.call(b.m.g.position.x, b.m.g.position.z, 3.2 * u, Color(b.color), true)
		if g.mode == "time":
			var cp: Vector3 = Trk.P[Trk.cps[g.nextCp]]
			dot.call(cp.x, cp.z, 4 * u, Color("#f2c200"), false)
		var c0 := Vector2(g.player.pos.x * S + ox, g.player.pos.z * S + oz)
		var a := -g.player.heading + PI
		var tri := PackedVector2Array([Vector2(0, -7 * u), Vector2(5 * u, 5 * u), Vector2(-5 * u, 5 * u)])
		for k in 3: tri[k] = c0 + tri[k].rotated(a)
		draw_colored_polygon(tri, Color(G.settings.color))
		tri.append(tri[0])
		draw_polyline(tri, Color("#161a22"), 1.5 * u, true)
		var o = g.otherPlayer()
		if o != null:
			var c1 := Vector2(o.pl.pos.x * S + ox, o.pl.pos.z * S + oz)
			var t2 := PackedVector2Array([Vector2(0, -7 * u), Vector2(5 * u, 5 * u), Vector2(-5 * u, 5 * u)])
			for k in 3: t2[k] = c1 + t2[k].rotated(-o.pl.heading + PI)
			draw_colored_polygon(t2, Color(o.color))
			t2.append(t2[0])
			draw_polyline(t2, Color("#161a22"), 1.5 * u, true)

# ------------------------------------------------------------------ gauge (JS drawGauge)
class Gauge extends Control:
	var needle := 0.0
	var rpm := 0.14
	var p2 := false                ## split screen: player 2's gauge
	func _draw() -> void:
		if p2: Game.asP2(paint)
		else: paint()
	func paint() -> void:
		var g := Game
		var W := size.x
		var c := Vector2(W / 2, W / 2)
		var R := W * 0.47
		var top: float = ceil(g.MAXV * 3.6 / 40) * 40
		var step := 40.0 if (top > 240 or W < 300) else 20.0
		var a0 := PI * 0.75
		var a1 := PI * 2.25
		var ang := func(v: float) -> float: return a0 + (a1 - a0) * clampf(v / top, 0, 1)
		var kmh := absf(g.player.speed) * 3.6
		var live: bool = g.state == "racing" or g.state == "finished"
		var gear := "R" if g.player.gear < 0 else ("N" if not live and absf(g.player.speed) < 0.5 else str(g.player.gear))
		var grpm: float = (0.14 + g.player.gasIn * 0.6) if g.state == "countdown" else g.engineRpm()
		var ks := 1 - exp(-get_process_delta_time() * 26)
		needle += (kmh - needle) * ks
		rpm += (grpm - rpm) * ks
		draw_circle(c + Vector2(0, 8), R, Color(0.04, 0.08, 0.16, 0.35))
		draw_circle(c, R, Color("#12151b"))
		draw_circle(c, R * 0.85, Color("#1d222b"))
		draw_arc(c, R - W * 0.015, 0, TAU, 64, Color("#1d4f9e"), W * 0.03, true)
		var rr := R * 0.9
		draw_arc(c, rr, a0, a1, 48, Color(1, 1, 1, 0.08), W * 0.035, true)
		draw_arc(c, rr, a0 + (a1 - a0) * 0.88, a1, 12, Color(1, 0.23, 0.18, 0.35), W * 0.035, true)
		draw_arc(c, rr, a0, a0 + (a1 - a0) * clampf(rpm, 0, 1), 48, Color("#ff3b2f") if rpm > 0.9 else Color("#f2c200"), W * 0.035, true)
		var f := Hud.font("800 %dpx Nunito" % int(round(W * 0.068)))
		var v := 0.0
		while v <= top:
			var a: float = ang.call(v)
			var bigt := fmod(v, step) == 0
			var r1 := R * 0.8
			var r0 := R * (0.7 if bigt else 0.75)
			draw_line(c + Vector2(cos(a), sin(a)) * r0, c + Vector2(cos(a), sin(a)) * r1, Color("#f7f7f2"), W * (0.013 if bigt else 0.006), true)
			if bigt:
				_text(str(int(v)), c + Vector2(cos(a), sin(a)) * R * 0.56, f, Color("#f7f7f2"))
			v += step / 2
		_text(str(int(round(kmh))), c + Vector2(0, R * 0.62), Hud.font("900 %dpx Nunito" % int(round(W * 0.15))), Color.WHITE)
		_text("km/u", c + Vector2(0, R * 0.8), Hud.font("700 %dpx Nunito" % int(round(W * 0.055))), Color(0.97, 0.97, 0.95, 0.7))
		var na: float = ang.call(needle)
		var hub := R * 0.17
		draw_line(c + Vector2(cos(na), sin(na)) * hub, c + Vector2(cos(na), sin(na)) * R * 0.78, Color("#f36f21"), W * 0.02, true)
		draw_circle(c, hub, Color("#0d0f14"))
		draw_arc(c, hub, 0, TAU, 32, Color("#f36f21"), W * 0.012, true)
		_text(gear, c + Vector2(0, W * 0.005), Hud.font("900 %dpx Nunito" % int(round(W * 0.12))), Color.WHITE if g.player.shiftT > 0 else Color("#f2c200"))
	func _text(t: String, at: Vector2, f: Array, col: Color) -> void:
		var fnt: Font = f[0]
		var sz := int(f[1])
		var w := fnt.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz)
		draw_string(fnt, at + Vector2(-w.x / 2, (fnt.get_ascent(sz) - fnt.get_descent(sz)) / 2), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

extends CanvasLayer
## Autoload "NetUi": the online screens.
##  - the list: games on this network show up by themselves (Net / LanDiscovery); joining by IP address with the last
##    used addresses one click away; when nothing is found, what to check;
##  - the lobby of a game: the players (car, ready, connection), the race as the host set it (track outline, laps,
##    bots, time, weather), chat, the standings of the evening; for the host the settings, Start and what the network says;
##  - on top of everything: the countdown to the host's start, "connection lost, reconnecting", the bar while watching
##    another player's car;
##  - on the results screen of an online race (Menu's board): standings, the next track or the vote for it, Meekijken.

const W_ONE := 560.0               ## the sign's width with one column (the list)
const W_TWO := 940.0               ## with two (a game: players left, the race right)

var ov: ColorRect
var card: Hud.SignBox
var box: VBoxContainer
var nick: LineEdit
var lobby_box: VBoxContainer
var list: VBoxContainer
var search_lbl: Label
var help: Label
var ip_in: LineEdit
var recent: HFlowContainer
var game_box: VBoxContainer
var cols: GridContainer
var players_head: Label
var players: VBoxContainer
var chat_log: Label
var chat_in: LineEdit
var race_pic: TrackPic
var race_lbl: Label
var race_sub: Label
var host_ctl: VBoxContainer
var host_ctl2: VBoxContainer       ## host: the options of the evening (start order, next track, open) under the chat
var act: HBoxContainer
var cyc := {}                      ## name -> value Label of a host option row
var pts_box: VBoxContainer
var pts_list: VBoxContainer
var pts_reset: Button
var car_lbl: Label
var col_swatch: Panel
var ip_note: Label
var net_note: Label
var upnp_note: Label
var fw_btn: Button
var status: Label
var start_btn: Button
var ready_btn: Button
var watch_btn: Button
var tags_btn: Button
var scroll: ScrollContainer
var outer: VBoxContainer
var leave_btn: Button
var car_btn: Button
var create_btn: Button
var back_btn: Button
var up_btn: Button
# on top of everything
var banner: PanelContainer
var banner_lbl: Label
var banner_sub: Label
var specbar: PanelContainer
var spec_lbl: Label
# on the results screen
var over_box: VBoxContainer
var over_info: Label
var over_btns: HFlowContainer
var _kick_arm := ""                ## the player whose kick button was pressed once ("Zeker?")
var _kick_at := 0
var _host_since := 0
var _refresh_at := 0

func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	ov = ColorRect.new()
	ov.color = Color(0.086, 0.1, 0.133, 0.45)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.visible = false
	add_child(ov)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(center)
	card = Hud.SignBox.new(Vector4(28, 20, 28, 20))
	card.custom_minimum_size = Vector2(W_ONE, 0)
	center.add_child(card)
	# a tall game screen (host controls) scrolls inside the sign instead of running off a small window
	outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	card.add_child(outer)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	outer.add_child(scroll)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	head.add_child(Hud.mk_label("Online spelen", "italic 900 36px Barlow Condensed", Hud.SIGN_INK))
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 10)
	nr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nr.alignment = BoxContainer.ALIGNMENT_END
	nr.add_child(_lab("Jouw naam"))
	nick = LineEdit.new()
	nick.max_length = 20
	nick.custom_minimum_size = Vector2(200, 0)
	_style_edit(nick)
	nick.text_changed.connect(func(t: String):
		var n := t.strip_edges()
		if n == "" or n == G.prefs.nick: return
		G.prefs.nick = n
		G.savePrefs()
		if Net.net != null: Net.net.game.presence({"nick": n}))
	nr.add_child(nick)
	head.add_child(nr)
	box.add_child(head)
	_build_list()
	_build_game()
	status = _note("")
	outer.add_child(status)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	outer.add_child(nav)
	back_btn = Hud.mk_button("Terug", false)
	back_btn.pressed.connect(func(): close())
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(back_btn)
	leave_btn = Hud.mk_button("Game verlaten", false)
	leave_btn.pressed.connect(func():
		Net.netLeave()
		Net.browse()
		refresh()
		create_btn.grab_focus())
	leave_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(leave_btn)
	_build_top()
	Net.changed.connect(refresh)
	_build_over.call_deferred()

# ------------------------------------------------------------------ building: the list of games
func _build_list() -> void:
	lobby_box = VBoxContainer.new()
	lobby_box.add_theme_constant_override("separation", 8)
	box.add_child(lobby_box)
	var lh := HBoxContainer.new()
	lh.add_child(_eyebrow("Games op dit netwerk"))
	search_lbl = _eyebrow("")
	search_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lh.add_child(search_lbl)
	lobby_box.add_child(lh)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	lobby_box.add_child(list)
	help = _note("")
	help.visible = false
	lobby_box.add_child(help)
	create_btn = Hud.mk_button("Nieuwe game maken")
	create_btn.pressed.connect(func(): Net.netCreate())
	lobby_box.add_child(create_btn)
	lobby_box.add_child(_eyebrow("Rechtstreeks via het IP-adres van de host"))
	var ir := HBoxContainer.new()
	ir.add_theme_constant_override("separation", 10)
	ip_in = LineEdit.new()
	ip_in.placeholder_text = "bijvoorbeeld 192.168.1.20"
	ip_in.custom_minimum_size = Vector2(250, 0)
	_style_edit(ip_in)
	ir.add_child(ip_in)
	var jb := Hud.mk_button("Meedoen", false)
	jb.pressed.connect(func(): _join_ip())
	ir.add_child(jb)
	lobby_box.add_child(ir)
	recent = HFlowContainer.new()
	recent.add_theme_constant_override("h_separation", 8)
	recent.add_theme_constant_override("v_separation", 6)
	lobby_box.add_child(recent)
	lobby_box.add_child(_note("Op hetzelfde netwerk (thuis, LAN-party) staat de game van de host vanzelf in de lijst. Het IP-adres staat in het scherm van de host. Via internet: de host klikt op 'Via internet bereikbaar maken' of zet poort %d (UDP) open in zijn router." % NetRoom.PORT))

# ------------------------------------------------------------------ building: inside a game
func _build_game() -> void:
	game_box = VBoxContainer.new()
	game_box.add_theme_constant_override("separation", 8)
	box.add_child(game_box)
	cols = GridContainer.new()
	cols.columns = 2
	cols.add_theme_constant_override("h_separation", 28)
	cols.add_theme_constant_override("v_separation", 10)
	game_box.add_child(cols)
	# ---- left: the players, chat, my car
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size = Vector2(420, 0)
	cols.add_child(left)
	players_head = _eyebrow("Spelers")
	left.add_child(players_head)
	players = VBoxContainer.new()
	players.add_theme_constant_override("separation", 3)
	left.add_child(players)
	# my car: next / previous car and colour here, or the full car step (stats, garage looks)
	var cr := HBoxContainer.new()
	cr.add_theme_constant_override("separation", 6)
	var a1 := _arrow("◀"); var a2 := _arrow("▶")
	a1.pressed.connect(func(): Net.cycleCar(-1))
	a2.pressed.connect(func(): Net.cycleCar(1))
	car_lbl = Hud.mk_label("", "900 15px Nunito", Hud.SIGN_INK)
	car_lbl.custom_minimum_size = Vector2(118, 0)
	car_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	car_lbl.clip_text = true
	var c1 := _arrow("◀"); var c2 := _arrow("▶")
	c1.pressed.connect(func(): Net.cycleColor(-1))
	c2.pressed.connect(func(): Net.cycleColor(1))
	col_swatch = _swatch(Vector2(26, 22))
	car_btn = _small("Auto kiezen")
	car_btn.pressed.connect(func():
		Net.setReady(false)
		ov.visible = false
		Menu.menuFlow = "net"
		Menu.showMenu(0))
	for c in [a1, car_lbl, a2, c1, col_swatch, c2, car_btn]: cr.add_child(c)
	left.add_child(_eyebrow("Jouw auto"))
	left.add_child(cr)
	# chat: a few fixed lines, or type something
	left.add_child(_eyebrow("Chat"))
	chat_log = _note("")
	chat_log.custom_minimum_size = Vector2(400, 0)
	left.add_child(chat_log)
	var er := HFlowContainer.new()
	er.add_theme_constant_override("h_separation", 6)
	er.add_theme_constant_override("v_separation", 4)
	for i in [0, 1, 2, 3, 6]:
		var eb := _small(Net.EMOTES[i])
		var k: int = i
		eb.pressed.connect(func(): Net.say(k))
		er.add_child(eb)
	left.add_child(er)
	chat_in = LineEdit.new()
	chat_in.placeholder_text = "Typ een bericht en druk op Enter"
	chat_in.max_length = 60
	_style_edit(chat_in, 14)
	left.add_child(chat_in)
	host_ctl2 = VBoxContainer.new()
	host_ctl2.add_theme_constant_override("separation", 3)
	left.add_child(host_ctl2)
	# ---- right: the race
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 5)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size = Vector2(420, 0)
	cols.add_child(right)
	right.add_child(_eyebrow("De race"))
	var rr := HBoxContainer.new()
	rr.add_theme_constant_override("separation", 12)
	race_pic = TrackPic.new()
	race_pic.custom_minimum_size = Vector2(150, 96)
	rr.add_child(race_pic)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 2)
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	race_lbl = Hud.mk_label("", "900 20px Nunito", Hud.SIGN_INK)
	race_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	race_sub = _note("")
	race_sub.custom_minimum_size = Vector2(230, 0)
	rv.add_child(race_lbl); rv.add_child(race_sub)
	rr.add_child(rv)
	right.add_child(rr)
	host_ctl = VBoxContainer.new()
	host_ctl.add_theme_constant_override("separation", 3)
	right.add_child(host_ctl)
	# (G.settings is looked up each time: tests and the menus may swap the whole Dictionary)
	_cycler("track", "Baan", func(d: int):
		var ids: Array = TrackLoader.ported()
		var i := ids.find(G.settings.track)
		G.settings.track = ids[(i + d + ids.size()) % ids.size()]
		G.saveSettings()
		Net.pushCfg()
		get_tree().current_scene.load_track(G.settings.track))
	_cycler("dir", "Richting", func(_d: int):
		G.settings.dir = "fwd" if G.settings.dir == "rev" else "rev"
		G.saveSettings()
		Net.pushCfg()
		get_tree().current_scene.load_track(G.settings.track))
	_cycler("laps", "Ronden", func(d: int):
		G.settings.laps = clampi(int(G.settings.laps) + d, 1, 5); G.saveSettings(); Net.pushCfg())
	_cycler("bots", "Bots", func(d: int):
		G.settings.bots = clampi(mini(int(G.settings.bots), 5) + d, 0, 5); G.saveSettings(); Net.pushCfg())
	_cycler("diff", "Niveau bots", func(d: int):
		var ks: Array = G.DIFF.keys()
		G.settings.diff = ks[(ks.find(G.settings.diff) + d + ks.size()) % ks.size()]; G.saveSettings(); Net.pushCfg())
	_cycler("time", "Tijd", func(d: int):
		var ks: Array = Env.TIME_NAMES.keys()
		G.settings.time = ks[(ks.find(G.settings.time) + d + ks.size()) % ks.size()]; G.saveSettings(); Net.pushCfg()
		if Env.me != null: Env.me.apply(G.settings.time, G.settings.weather))
	_cycler("weather", "Weer", func(d: int):
		var ks: Array = Env.WEATHER_NAMES.keys()
		G.settings.weather = ks[(ks.find(G.settings.weather) + d + ks.size()) % ks.size()]; G.saveSettings(); Net.pushCfg()
		if Env.me != null: Env.me.apply(G.settings.time, G.settings.weather))
	_cycler("grid", "Startvolgorde", func(d: int): Net.setGridMode(_cycle(Net.GRID_MODES, Net.onl().get("grid", "rev"), d)), host_ctl2)
	_cycler("next", "Volgende baan", func(d: int): Net.setNextMode(_cycle(Net.NEXT_MODES, Net.onl().get("next", "host"), d)), host_ctl2)
	_cycler("open", "Nieuwe spelers", func(_d: int): Net.setOpen(not Net.net.open), host_ctl2)
	# ---- under both, always in view (not in the scrolling part): ready / start, watching, name tags
	act = HBoxContainer.new()
	act.add_theme_constant_override("separation", 8)
	start_btn = Hud.mk_button("Start race")
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn.pressed.connect(func():
		if Net.countdown() > 0: Net.netHostCancel()
		else: Net.netHostStart())
	act.add_child(start_btn)
	ready_btn = Hud.mk_button("Ik ben klaar")
	ready_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ready_btn.pressed.connect(func(): Net.setReady(not Net.isReady()))
	act.add_child(ready_btn)
	watch_btn = Hud.mk_button("Meekijken", false)
	watch_btn.pressed.connect(func(): Net.watchStart())
	act.add_child(watch_btn)
	tags_btn = _small("")
	tags_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tags_btn.pressed.connect(func():
		G.prefs.tags = not G.prefs.get("tags", true)
		G.savePrefs()
		refresh())
	act.add_child(tags_btn)
	outer.add_child(act)
	# ---- the standings of the evening
	pts_box = VBoxContainer.new()
	pts_box.add_theme_constant_override("separation", 3)
	var ph := HBoxContainer.new()
	var pe := _eyebrow("Stand van de avond")
	pe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(pe)
	pts_reset = _small("Stand wissen")
	pts_reset.pressed.connect(func(): Net.resetStandings())
	ph.add_child(pts_reset)
	pts_box.add_child(ph)
	pts_list = VBoxContainer.new()
	pts_list.add_theme_constant_override("separation", 1)
	pts_box.add_child(pts_list)
	game_box.add_child(pts_box)
	# ---- host: what the network says (can the others find this game? always in view)
	ip_note = _note("")
	outer.add_child(ip_note)
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	fw_btn = _small("Windows-firewall openzetten")
	fw_btn.pressed.connect(func(): Net.firewall_open())
	hr.add_child(fw_btn)
	up_btn = _small("Via internet bereikbaar maken")
	up_btn.pressed.connect(func(): Net.open_internet())
	hr.add_child(up_btn)
	game_box.add_child(hr)
	upnp_note = _note("")
	game_box.add_child(upnp_note)
	net_note = _eyebrow("")
	game_box.add_child(net_note)

# ------------------------------------------------------------------ building: on top of everything
func _build_top() -> void:
	var top := CenterContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 18
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	banner = PanelContainer.new()
	var st := Hud.pill(Color(0.086, 0.1, 0.133, 0.88), 18)
	st.content_margin_left = 26; st.content_margin_right = 26; st.content_margin_top = 10; st.content_margin_bottom = 10
	st.border_color = Hud.DETOUR; st.set_border_width_all(2)
	banner.add_theme_stylebox_override("panel", st)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.visible = false
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 0)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_lbl = Hud.mk_label("", "900 26px Nunito", Hud.SIGN_INK)
	banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub = Hud.mk_label("", "700 14px Nunito", Hud.SUB)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(banner_lbl); bv.add_child(banner_sub)
	banner.add_child(bv)
	top.add_child(banner)
	var bot := CenterContainer.new()
	bot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot.offset_top = -92
	bot.offset_bottom = -22
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bot)
	specbar = PanelContainer.new()
	var s2 := Hud.pill(Color(0.086, 0.1, 0.133, 0.82), 18)
	s2.content_margin_left = 18; s2.content_margin_right = 18; s2.content_margin_top = 8; s2.content_margin_bottom = 8
	specbar.add_theme_stylebox_override("panel", s2)
	specbar.visible = false
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 12)
	var p1 := _arrow("◀"); var p2 := _arrow("▶")
	p1.focus_mode = Control.FOCUS_NONE; p2.focus_mode = Control.FOCUS_NONE
	p1.pressed.connect(func(): Net.specNext(-1))
	p2.pressed.connect(func(): Net.specNext(1))
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 0)
	spec_lbl = Hud.mk_label("", "900 18px Nunito", Hud.SIGN_INK)
	spec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spec_lbl.custom_minimum_size = Vector2(300, 0)
	var sn := Hud.mk_label("← → andere auto  ·  Esc terug", "700 12px Nunito", Hud.SUB)
	sn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(spec_lbl); sv.add_child(sn)
	var stop := _small("Terug")
	stop.focus_mode = Control.FOCUS_NONE
	stop.pressed.connect(func(): Net.specStop())
	for c in [p1, sv, p2, stop]: sh.add_child(c)
	specbar.add_child(sh)
	bot.add_child(specbar)

## the online part of the results screen lives in Menu's results board, under the list
func _build_over() -> void:
	var O = Menu.overUI
	if O == null: return
	over_box = UiKit.vbox(8)
	over_box.visible = false
	over_info = UiKit.lbl("", 700, 14, UiKit.SUB, true)
	over_box.add_child(over_info)
	over_btns = HFlowContainer.new()
	over_btns.add_theme_constant_override("h_separation", 6)
	over_btns.add_theme_constant_override("v_separation", 6)
	over_box.add_child(over_btns)
	var v: Node = O.results.get_parent()
	v.add_child(over_box)
	v.move_child(over_box, O.results.get_index() + 1)
	# 8 players and their bots: more rows than the board was made for. They get thinner and the three tiles make way.
	O.results.child_entered_tree.connect(func(row: Node):
		if Net.net == null or Game.state != "over" or not (row is PanelContainer): return
		var n: int = maxi(Game.resultRows.size(), Net.standings().size() if Game.overView == "netpts" else 0)
		if n <= 8: return
		O.rstats.visible = false
		var sb = row.get_theme_stylebox("panel")
		if sb is StyleBoxFlat:
			sb = sb.duplicate()
			var pad := 4 if n <= 11 else 2
			sb.content_margin_top = pad; sb.content_margin_bottom = pad
			row.add_theme_stylebox_override("panel", sb))

# ------------------------------------------------------------------ small parts
func _lab(t: String) -> Label:
	return Hud.mk_label(t, "800 15px Nunito", Hud.SIGN_INK)

func _eyebrow(t: String) -> Label:
	return Hud.mk_label(t.to_upper(), "800 12px Nunito", Hud.LAB)

func _note(t: String) -> Label:
	var l := Hud.mk_label(t, "700 13px Nunito", Hud.SUB)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(500, 0)
	return l

func _style_edit(e: LineEdit, size := 16) -> void:
	var f := Hud.font("800 %dpx Nunito" % size)
	e.add_theme_font_override("font", f[0])
	e.add_theme_font_size_override("font_size", int(f[1]))
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.04, 0.08, 0.16, 0.28)
	st.set_corner_radius_all(12)
	st.border_color = Color(0.97, 0.97, 0.95, 0.35); st.set_border_width_all(2)
	st.content_margin_left = 12; st.content_margin_right = 12; st.content_margin_top = 6; st.content_margin_bottom = 6
	e.add_theme_stylebox_override("normal", st)
	var fo := st.duplicate(); fo.border_color = Hud.DETOUR
	e.add_theme_stylebox_override("focus", fo)
	e.add_theme_color_override("font_color", Hud.SIGN_INK)
	e.add_theme_color_override("font_placeholder_color", Color(0.84, 0.88, 0.95, 0.6))

## one option row of the host: label, ◀ value ▶
func _cycler(key: String, label: String, cb: Callable, parent: Control = null) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	var l := _lab(label)
	l.custom_minimum_size = Vector2(118, 0)
	var a := _arrow("◀")
	var v := Hud.mk_label("", "900 15px Nunito", Hud.SIGN_INK)
	v.custom_minimum_size = Vector2(190, 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.clip_text = true
	var b := _arrow("▶")
	a.pressed.connect(func():
		cb.call(-1)
		refresh())
	b.pressed.connect(func():
		cb.call(1)
		refresh())
	for c in [l, a, v, b]: r.add_child(c)
	(parent if parent != null else host_ctl).add_child(r)
	cyc[key] = v

static func _cycle(modes: Array, cur, d: int) -> String:
	var i := 0
	for k in modes.size():
		if modes[k][0] == cur: i = k
	return modes[(i + d + modes.size()) % modes.size()][0]

static func _mode_name(modes: Array, cur) -> String:
	for m in modes:
		if m[0] == cur: return m[1]
	return modes[0][1]

## a little square in a car's colour, with a light edge (a blue car on the blue sign)
func _swatch(sz: Vector2) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = sz
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(4)
	sb.border_color = Color(0.97, 0.97, 0.95, 0.75)
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	return p

func _paint(p: Panel, color: String) -> void:
	var sb: StyleBoxFlat = p.get_theme_stylebox("panel")
	sb.bg_color = Color(color) if Color.html_is_valid(color) else Color.WHITE

## a small round arrow button for the option rows
func _arrow(t: String) -> Button:
	var b := Hud.mk_button(t, false)
	_tight(b, 11, 2, 14)
	return b

## a small pill button
func _small(t: String) -> Button:
	var b := Hud.mk_button(t, false)
	_tight(b, 12, 4, 13)
	return b

func _tight(b: Button, px: int, py: int, size: int) -> void:
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(st).duplicate()
		sb.content_margin_left = px; sb.content_margin_right = px; sb.content_margin_top = py; sb.content_margin_bottom = py
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_size_override("font_size", size)
	var d: StyleBoxFlat = b.get_theme_stylebox("normal").duplicate()
	d.bg_color = Color(1, 1, 1, 0.04)
	b.add_theme_stylebox_override("disabled", d)

## the outline of a track, from its control points (no need to load the track)
class TrackPic extends Control:
	var id := ""
	var rev := false
	var _pts := PackedVector2Array()
	var _for := ""
	func show_track(track: String, dir: String) -> void:
		if track == id and (dir == "rev") == rev: return
		id = track
		rev = dir == "rev"
		queue_redraw()
	func _draw() -> void:
		draw_style_box(Hud.pill(Color(0.04, 0.08, 0.16, 0.28), 14), Rect2(Vector2.ZERO, size))
		if not TrackDefs.TRACKS.has(id): return
		if _for != id:
			_for = id
			var ctrl: Array = TrackDefs.TRACKS[id].ctrl
			var c := CRCurve.new(ctrl.map(func(p): return [p[0], 0.0, p[1]]))
			_pts = PackedVector2Array()
			for i in 161:
				var q := c.get_point(i / 160.0)
				_pts.append(Vector2(q[0], q[2]))
		if _pts.size() < 3: return
		var lo := _pts[0]; var hi := _pts[0]
		for p in _pts:
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y)); hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
		var pad := 12.0
		var k := minf((size.x - 2 * pad) / maxf(1.0, hi.x - lo.x), (size.y - 2 * pad) / maxf(1.0, hi.y - lo.y))
		var off := (size - (hi - lo) * k) / 2.0 - lo * k
		var line := PackedVector2Array()
		for p in _pts: line.append(p * k + off)
		draw_polyline(line, Color(0.97, 0.97, 0.95, 0.95), 3.0, true)
		# the start, and which way round
		var a := line[0]
		var b := line[line.size() - 5] if rev else line[4]
		var dir := (b - a).normalized()
		var n := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([a + dir * 9, a - dir * 3 + n * 6, a - dir * 3 - n * 6]), Hud.DETOUR)

func _join_ip() -> void:
	var ip := ip_in.text.strip_edges()
	if ip == "":
		Net.netStatus("Vul het IP-adres van de host in.")
		return
	Net.netJoin(ip)

# ------------------------------------------------------------------ open / close / keys
func open() -> void:
	ov.visible = true
	nick.text = G.prefs.nick
	if Net.net == null:
		Net.browse()
	refresh()
	_focus_main()

## keyboard and gamepad: on the main button of this screen (when it opens, and when the focused button went away,
## like Nieuwe game maken or Meedoen once you are in a game)
func _focus_main() -> void:
	if not ov.visible: return
	var f: Control = (start_btn if Net.net.host else ready_btn) if Net.net != null else create_btn
	if f.is_visible_in_tree(): f.grab_focus()

func close() -> void:
	if Net.net != null and Net.net.watch:
		Net.specStop()
		return
	ov.visible = false
	Net.stop_browse()
	# back on the button that opened this screen
	if Game.state == "menu" and Menu.homeUI.hNet.is_visible_in_tree(): UiKit.focus(Menu.homeUI.hNet)

## the online screen has the keys and the gamepad: the lobby is open, or a race is being watched from the lobby
func is_open() -> bool:
	return ov.visible or (Net.net != null and Net.net.watch)

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed: return
	var k: Key = e.keycode
	if Net.spectating():
		# watching another car: left / right another one, anything like "back" stops
		if k == KEY_F11 or e.alt_pressed: return
		get_viewport().set_input_as_handled()
		if e.echo: return
		if k == KEY_LEFT or k == KEY_A: Net.specNext(-1)
		elif k == KEY_RIGHT or k == KEY_D: Net.specNext(1)
		elif k in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_BACKSPACE]: Net.specStop()
		return
	if not ov.visible or e.echo: return
	var f := get_viewport().gui_get_focus_owner()
	if f is LineEdit:
		# Enter in a field does what the field is for (Menu._input would only leave the field)
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			if f == ip_in: _join_ip()
			elif f == chat_in:
				if chat_in.text.strip_edges() != "": Net.say(chat_in.text)
				chat_in.text = ""
			else: f.release_focus()
		return
	# Escape closes the online screen, like Terug
	if k == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()

## from Menu.padNav (the gamepad, each frame): true = the online screens took it
func padNav(now: Dictionary, prev: Dictionary) -> bool:
	var edge := func(k: String) -> bool: return now.get(k, false) and not prev.get(k, false)
	if Net.spectating():
		if edge.call("l") or edge.call("lb"): Net.specNext(-1)
		if edge.call("r") or edge.call("rb"): Net.specNext(1)
		if edge.call("b") or edge.call("a") or edge.call("start"): Net.specStop()
		return true
	if Game.state == "menu" and ov.visible:
		# (the buttons themselves follow Godot's own focus keys: d-pad, stick and A)
		if edge.call("b"): close()
		return true
	if Net.net != null and Game.state == "over" and Game.overReady and Menu.overOv.visible:
		# the results screen of an online race has more buttons than Opnieuw and Menu: walk them
		if edge.call("up") or edge.call("l"): Menu.padFocus(-1, Menu.overOv)
		if edge.call("down") or edge.call("r"): Menu.padFocus(1, Menu.overOv)
		if edge.call("a"):
			var f := get_viewport().gui_get_focus_owner()
			if f is UiKit.Btn and Menu.overOv.is_ancestor_of(f): f.press()
		if edge.call("start"): Game.onAgain()
		if edge.call("b"): Game.toCareerOr(-1)
		return true
	return false

static func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

func _process(_dt: float) -> void:
	_top()
	# the search time, pings and the countdown on the buttons move by themselves
	var now := Time.get_ticks_msec()
	if ov.visible and now - _refresh_at > 1000: refresh()

## the banner (countdown, connection) and the bar while watching: over every screen
func _top() -> void:
	var n = Net.net
	var cd := Net.countdown()
	var show := false
	if n != null and cd > 0:
		show = true
		var c: Dictionary = n.cd
		banner_lbl.text = "Race start over %d" % int(ceil(cd))
		banner_sub.text = Net.trackName(c.get("track", ""), c.get("dir", "fwd"))
	elif n != null and not ov.visible and (n.mig != null or n.game.is_reconnecting()):
		show = true
		banner_lbl.text = "Nieuwe host zoeken…" if n.mig != null else "Verbinding kwijt"
		banner_sub.text = "Het spel gaat zo verder" if n.mig != null else "Opnieuw verbinden…"
	if banner.visible != show: banner.visible = show
	var sp := Net.spectating()
	if specbar.visible != sp: specbar.visible = sp
	if sp:
		var t := "Je kijkt mee met " + Net.specName()
		if spec_lbl.text != t: spec_lbl.text = t

# ------------------------------------------------------------------ refresh
func refresh() -> void:
	_over_fill()
	if not ov.visible:
		return
	_refresh_at = Time.get_ticks_msec()
	var inGame: bool = Net.net != null
	lobby_box.visible = not inGame
	game_box.visible = inGame
	act.visible = inGame
	ip_note.visible = inGame and Net.net.host
	leave_btn.visible = inGame
	status.text = Net.status
	status.visible = Net.status != ""
	var vp := get_viewport().get_visible_rect().size
	var two: bool = inGame and vp.x >= W_TWO + 40
	var w := (W_TWO if two else W_ONE) - 56
	card.custom_minimum_size.x = minf(W_TWO if two else W_ONE, vp.x - 16)
	cols.columns = 2 if two else 1
	status.custom_minimum_size.x = minf(w, vp.x - 80)
	if not inGame: _fill_list()
	else: _fill_game(w)
	# all of it when it fits, else a scroll bar inside the sign (name, status and the buttons below stay in view)
	var fixed := 150.0 + (status.get_combined_minimum_size().y + 8 if status.visible else 0.0) + (act.get_combined_minimum_size().y + 8 if inGame else 0.0)
	if ip_note.visible: fixed += ip_note.get_combined_minimum_size().y + 8
	scroll.custom_minimum_size = Vector2(minf(w, vp.x - 72), minf(box.get_combined_minimum_size().y, vp.y - fixed))
	var fnow := get_viewport().gui_get_focus_owner()
	if fnow == null or not fnow.is_visible_in_tree(): _focus_main.call_deferred()

func _fill_list() -> void:
	# keep the keyboard focus on the same card when the list changes
	var fo := get_viewport().gui_get_focus_owner()
	var fi := -1
	for i in list.get_child_count():
		if fo != null and list.get_child(i).is_ancestor_of(fo): fi = i
	_clear(list)
	var ls := Net.lobbies()
	var secs := Net.lan.browse_secs()
	search_lbl.text = ("ZOEKEN… %d S" % int(secs)) if ls.is_empty() else ""
	if ls.is_empty():
		list.add_child(_note("Nog geen games gevonden. Maak er zelf een aan, of wacht tot de host er een maakt."))
	for l in ls:
		list.add_child(_lobby_card(l))
	if fi >= 0:
		var bs := list.get_child(mini(fi, list.get_child_count() - 1)).find_children("*", "Button", true, false)
		if not bs.is_empty() and not bs[0].disabled: bs[0].grab_focus()
		else: create_btn.grab_focus()
	# nothing found after ten seconds: what to check, with what this PC knows about its own network
	var stuck: bool = ls.is_empty() and secs >= 10.0
	help.visible = stuck
	if stuck: help.text = _search_help()
	# the addresses joined before, one click each
	var ips := Net.recentIps()
	var key := ",".join(ips)
	if recent.get_meta("key", "") != key:
		recent.set_meta("key", key)
		_clear(recent)
		for ip in ips:
			var b := _small("Opnieuw: " + str(ip))
			var a: String = ip
			b.pressed.connect(func(): Net.netJoin(a))
			recent.add_child(b)
	recent.visible = not ips.is_empty()

## why the list stays empty, as far as this PC can tell
func _search_help() -> String:
	var ads := LanDiscovery.adapters()
	var real := ads.filter(func(a): return not a.virt)
	if ads.is_empty():
		return "Deze pc heeft geen netwerkverbinding: geen wifi en geen kabel. Maak eerst verbinding met hetzelfde netwerk als de host."
	var t := "Na 10 seconden nog niets. Loop dit na:\n"
	t += "1. Heeft de host op 'Nieuwe game maken' geklikt? In zijn scherm staat of spelers hem kunnen vinden.\n"
	t += "2. Zelfde netwerk? Deze pc zit op %s. Een gastnetwerk of hotspot laat pc's elkaar vaak niet zien.\n" % ", ".join((real if not real.is_empty() else ads).slice(0, 2).map(func(a): return "%s%s" % [a.a, " (%s)" % a.nm if a.nm != "" else ""]))
	t += "3. De firewall van de host: Polderrace toestaan, ook voor 'Openbare netwerken' (de host heeft daar een knop voor).\n"
	t += "4. Lukt het niet: typ hieronder het IP-adres dat in het scherm van de host staat."
	if real.is_empty(): t += "\nLet op: deze pc heeft alleen een virtueel netwerk (VPN, VirtualBox). Zet de VPN uit of maak verbinding met wifi."
	return t

func _fill_game(w: float) -> void:
	var n: Dictionary = Net.net
	var host: bool = n.host
	var cf := Net.cfg()
	var S := G.settings
	# ---- the players (built again every second: the keyboard focus stays on the same player's button)
	var fo := get_viewport().gui_get_focus_owner()
	var fpeer := ""
	for row in players.get_children():
		if fo != null and row.is_ancestor_of(fo): fpeer = str(row.get_meta("peer", ""))
	_clear(players)
	_player_row(G.prefs.nick, S.car, S.color, host, true, Net.isReady(), n.game.me, false)
	var ids: Array = n.remotes.keys()
	ids.sort_custom(func(a, b): return int(str(a).substr(1)) < int(str(b).substr(1)))
	for id in ids:
		var r: Dictionary = n.remotes[id]
		_player_row(r.name, r.carId, r.color, r.host, false, r.rdy, id, r.off)
	players_head.text = "SPELERS · %d VAN %d" % [n.remotes.size() + 1, NetRoom.MAX_GUESTS + 1]
	if fpeer != "":
		for row in players.get_children():
			if not row.is_queued_for_deletion() and str(row.get_meta("peer", "")) == fpeer and row.get_child(row.get_child_count() - 1) is Button:
				row.get_child(row.get_child_count() - 1).grab_focus()
	car_lbl.text = Cars.CARS[S.car].name
	_paint(col_swatch, str(S.color))
	var lines := []
	for c in n.chat.slice(-3): lines.append("%s: %s" % [c[0], c[1]])
	chat_log.text = "\n".join(lines) if not lines.is_empty() else "Nog niets gezegd."
	chat_log.custom_minimum_size.x = minf(400, w)
	# ---- the race as the host set it
	race_pic.show_track(str(cf.get("track", "")), str(cf.get("dir", "fwd")))
	race_lbl.text = Net.trackName(cf.get("track", ""), cf.get("dir", "fwd")) if not cf.is_empty() else "…"
	var bots := int(cf.get("bots", 0))
	var dn: String = G.DIFF[cf.diff].name.to_lower() if G.DIFF.has(cf.get("diff", "")) else ""
	var sub := "%d %s · %s · %s, %s" % [int(cf.get("laps", 0)), "ronde" if int(cf.get("laps", 0)) == 1 else "ronden",
		"geen bots" if bots == 0 else "%d %s (%s)" % [bots, "bot" if bots == 1 else "bots", dn],
		Env.TIME_NAMES.get(cf.get("time", ""), "?").to_lower(), Env.WEATHER_NAMES.get(cf.get("weather", ""), "?").to_lower()]
	if not host:
		sub += "\nStart: %s · volgende baan: %s" % [_mode_name(Net.GRID_MODES, cf.get("grid", "rev")).to_lower(), _mode_name(Net.NEXT_MODES, cf.get("next", "host")).to_lower()]
		if cf.get("open", true) == false: sub += "\nGesloten voor nieuwe spelers."
	race_sub.text = sub if not cf.is_empty() else "Wachten op de instellingen van de host…"
	host_ctl.visible = host
	host_ctl2.visible = host
	if host:
		cyc.track.text = TrackDefs.TRACKS[S.track].name
		cyc.dir.text = "Omgekeerd" if S.dir == "rev" else "Vooruit"
		cyc.laps.text = str(S.laps)
		cyc.bots.text = str(mini(int(S.bots), 5))
		cyc.diff.text = G.DIFF[S.diff].name
		cyc.time.text = Env.TIME_NAMES[S.time]
		cyc.weather.text = Env.WEATHER_NAMES[S.weather]
		cyc.grid.text = _mode_name(Net.GRID_MODES, cf.get("grid", "rev"))
		cyc.next.text = _mode_name(Net.NEXT_MODES, cf.get("next", "host"))
		cyc.open.text = "Welkom" if n.open else "Gesloten"
	# ---- start / ready / watch
	var cd := Net.countdown()
	start_btn.visible = host
	ready_btn.visible = not host
	if host:
		var nr := Net.notReady()
		if cd > 0: start_btn.text = "Annuleren (start over %d)" % int(ceil(cd))
		elif nr.is_empty(): start_btn.text = "Start race"
		else: start_btn.text = "Start toch (%s niet klaar)" % (nr[0] if nr.size() == 1 else "%d spelers" % nr.size())
	else:
		ready_btn.text = "Klaar! (klik om te wijzigen)" if Net.isReady() else "Ik ben klaar"
	watch_btn.visible = Net.canWatch()
	tags_btn.text = "Namen boven auto's: " + ("aan" if G.prefs.get("tags", true) else "uit")
	# ---- standings
	var st := Net.standings()
	pts_box.visible = not st.is_empty()
	pts_reset.visible = host
	_clear(pts_list)
	for k in st.size():
		var e: Dictionary = st[k]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var col := Hud.DETOUR if e.me else (Hud.SIGN_INK if e.here else Hud.LAB)
		var p := Hud.mk_label("%d." % (k + 1), "900 14px Nunito", col)
		p.custom_minimum_size = Vector2(26, 0)
		var nm := Hud.mk_label(str(e.name) + ("" if e.here else " (weg)"), "800 14px Nunito", col)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var info := Hud.mk_label("%d %s · %d gewonnen · laatste +%d" % [e.races, "race" if e.races == 1 else "races", e.wins, e.last], "700 12px Nunito", Hud.SUB)
		var pt := Hud.mk_label("%d pt" % e.pts, "900 14px Nunito", col)
		pt.custom_minimum_size = Vector2(56, 0)
		pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for c in [p, nm, info, pt]: h.add_child(c)
		pts_list.add_child(h)
	# ---- host: the network
	fw_btn.visible = host and (Net.fw_state == "block" or Net.fw_state == "none")
	fw_btn.disabled = Net.fw_busy()
	up_btn.visible = host
	upnp_note.text = Net.upnp_status
	upnp_note.visible = host and Net.upnp_status != ""
	net_note.visible = host
	if host:
		if _host_since == 0: _host_since = Time.get_ticks_msec()
		ip_note.text = _host_diag()
		ip_note.custom_minimum_size.x = w
		net_note.text = "NETWERK: %s OMHOOG · %s OMLAAG" % [_kb(n.game.up_bps), _kb(n.game.down_bps)]
	else:
		_host_since = 0

static func _kb(bps: int) -> String:
	return ("%d KB/S" % int(round(bps / 1000.0))) if bps >= 10000 else ("%s KB/S" % G.toFixed(bps / 1000.0, 1).replace(".", ","))

## host: can the others find this game? What this PC sees of it, and what to do when they cannot
func _host_diag() -> String:
	var n: Dictionary = Net.net
	var ads := LanDiscovery.adapters()
	var ips: Array = ads.slice(0, 3).map(func(a): return "%s%s" % [a.a, " (%s)" % a.nm if ads.size() > 1 and a.nm != "" else ""])
	var addr := ("Jouw IP-adres: " + ", ".join(ips) + ". ") if not ips.is_empty() else ""
	var lan := Net.lan
	var fw := ""
	if Net.fw_state == "block": fw = "De Windows-firewall BLOKKEERT Polderrace op deze pc: niemand kan meedoen. Klik op 'Windows-firewall openzetten'. "
	elif Net.fw_state == "none": fw = "Windows heeft Polderrace nog niet toegelaten tot het netwerk. Klik op 'Windows-firewall openzetten', of kies Toestaan (ook voor openbare netwerken) als Windows erom vraagt; die vraag kan achter het spel staan (Alt+Tab). "
	if Net.fw_msg != "": fw = Net.fw_msg + " " + fw
	if not lan.is_serving():
		return fw + addr + "Je game staat niet in de lijst van anderen; meedoen kan via je IP-adres."
	var s := lan.searching()
	if lan.selftest == "nonet" and s == 0 and n.remotes.is_empty():
		return "Deze pc heeft geen netwerkverbinding (geen wifi of kabel): anderen kunnen je game niet vinden."
	if s > 0:
		return fw + "%d %s nu naar games en %s de jouwe in de lijst. " % [s, "speler zoekt" if s == 1 else "spelers zoeken", "ziet" if s == 1 else "zien"] + addr
	if not n.remotes.is_empty():
		return fw + addr + "Nieuwe spelers vinden je game vanzelf in hun lijst."
	var waited := (Time.get_ticks_msec() - _host_since) / 1000.0
	if lan.selftest == "fail":
		return fw + "Deze pc ontvangt zijn eigen zoekbericht niet: vrijwel zeker houdt de firewall het spel tegen. Sta Polderrace toe, ook voor 'Openbare netwerken'. " + addr
	if waited < 8.0:
		return fw + "Je game staat klaar: spelers op hetzelfde netwerk zien hem in hun lijst. " + addr
	return fw + "Nog niemand ziet je game. Zoeken de anderen al (Online spelen)? Zo ja: sta Polderrace toe in de firewall van deze pc, ook voor 'Openbare netwerken' (de vraag van Windows kan achter het spel staan: Alt+Tab), en check dat iedereen op hetzelfde netwerk zit. Het kan ook via je IP-adres. " + addr

func _lobby_card(l: Dictionary) -> Control:
	var pc := PanelContainer.new()
	var st := Hud.pill(Color(1, 1, 1, 0.08), 16)
	st.content_margin_top = 8; st.content_margin_bottom = 8; st.shadow_size = 0
	pc.add_theme_stylebox_override("panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	pc.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Hud.mk_label(str(l.get("name", "Game")).substr(0, 40), "900 17px Nunito", Hud.SIGN_INK))
	var theirs := int(l.get("v", 1))
	var other: bool = theirs != NetRoom.PROTO
	var open: bool = l.get("open", true)
	var full: bool = int(l.get("n", 1)) >= int(l.get("max", 8))
	var sub := "%s · %d van %d spelers" % [l.get("track", ""), int(l.get("n", 1)), int(l.get("max", 8))]
	if int(l.get("laps", 0)) > 0: sub += " · %d %s" % [int(l.laps), "ronde" if int(l.laps) == 1 else "ronden"]
	if other: sub += "\nAndere versie van het spel: %s. De nieuwste staat op de downloadpagina." % ("de host heeft een nieuwere, werk jouw spel bij" if theirs > NetRoom.PROTO else "de host heeft een oudere, hij moet zijn spel bijwerken")
	elif full: sub += " · vol"
	elif not open: sub += " · gesloten voor nieuwe spelers"
	elif l.get("deaf", false): sub += "\nZichtbaar, maar deze pc laat geen spelers binnen: de firewall op de pc van de host houdt het spel tegen."
	elif l.get("race", false): sub += " · race bezig, je doet mee vanaf de volgende"
	var sl := Hud.mk_label(sub, "700 13px Nunito", Hud.SUB)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)
	h.add_child(v)
	var b := Hud.mk_button("Meedoen")
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = other or full or not open
	b.pressed.connect(func(): Net.netJoin(str(l.ip)))
	h.add_child(b)
	return pc

func _player_row(name: String, carId, color, host: bool, me: bool, rdy: bool, peer: String, off: bool) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var star := Hud.mk_label("★" if host else "", "900 15px Nunito", Hud.DETOUR)
	star.custom_minimum_size = Vector2(16, 0)
	h.add_child(star)
	var nm := Hud.mk_label(name + (" (jij)" if me else ""), "800 15px Nunito", Hud.SIGN_INK if not off else Hud.LAB)
	nm.clip_text = true
	nm.custom_minimum_size = Vector2(120, 0)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nm)
	var sw := _swatch(Vector2(14, 14))
	_paint(sw, str(color))
	h.add_child(sw)
	var cl := Hud.mk_label(Cars.CARS[carId].name if Cars.CARS.has(str(carId)) else "", "700 12px Nunito", Hud.SUB)
	cl.custom_minimum_size = Vector2(84, 0)
	cl.clip_text = true
	h.add_child(cl)
	var q := Net.quality(peer)
	var state := "host" if host else ("klaar" if rdy else "niet klaar")
	if off: state = "weg…"
	var sl := Hud.mk_label(state, "800 12px Nunito", Color("#9df0a8") if (rdy or host) and not off else Color("#ffd0cc"))
	sl.custom_minimum_size = Vector2(62, 0)
	h.add_child(sl)
	var qt: String = q.text if q.text != "host" else ""
	var ql := Hud.mk_label(("! " if q.warn else "") + qt, "800 12px Nunito", Color("#ffb4ab") if q.warn else Hud.SUB)
	ql.custom_minimum_size = Vector2(64, 0)
	ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(ql)
	if Net.net.host and not me:
		# out of the game: one click arms the button, the second within three seconds does it
		var armed: bool = _kick_arm == peer and Time.get_ticks_msec() - _kick_at < 3000
		var kb := _small("Zeker?" if armed else "Eruit")
		kb.tooltip_text = "Zet %s uit de game" % name
		kb.pressed.connect(func():
			if _kick_arm == peer and Time.get_ticks_msec() - _kick_at < 3000:
				_kick_arm = ""
				Net.kick(peer)
			else:
				_kick_arm = peer
				_kick_at = Time.get_ticks_msec()
				refresh()
				# (the row was built again: the focus goes to its new button)
				for row in players.get_children():
					if row.get_meta("peer", "") == peer and not row.is_queued_for_deletion():
						row.get_child(row.get_child_count() - 1).grab_focus())
		h.add_child(kb)
	h.set_meta("peer", peer)
	h.set_meta("nick", name)
	players.add_child(h)

# ------------------------------------------------------------------ the results screen of an online race
## from Menu.showOver: the results screen opens (offline: our part hides)
func overShown() -> void:
	if over_box == null: return
	over_box.visible = Net.net != null
	_over_view = "results"
	_over_key = ""
	_over_fill()

var _over_view := "results"
var _over_key := ""

func _over_fill() -> void:
	if over_box == null or not over_box.visible: return
	var n = Net.net
	if n == null or Game.state != "over":
		over_box.visible = n != null and Game.state == "over"
		return
	var cf := Net.cfg()
	var res = n.res
	var final: bool = res is Dictionary and int(res.get("id", 0)) == int(n.raceId) and res.get("final", false) == true
	var left := int(res.get("left", -1)) if res is Dictionary and int(res.get("id", 0)) == int(n.raceId) else -1
	var votes := Net.votes()
	var cands: Array = cf.get("cands", []) if cf.get("cands") is Array else []
	var info := ""
	if not final:
		info = "De anderen rijden nog%s. De punten komen als iedereen binnen is." % (" (nog %d s)" % left if left > 0 else "")
	else:
		info = "Klik op Nieuwe race voor de volgende." if n.host else "De host start de volgende race."
		if not cands.is_empty(): info += " Stem op de baan:"
		elif TrackDefs.TRACKS.has(str(cf.get("nt", ""))): info += " Volgende baan: %s." % TrackDefs.TRACKS[cf.nt].name
	over_info.text = info
	over_info.visible = info != ""
	var can_spec: bool = not Net.specTargets().is_empty() and not final
	var key := "%s|%s|%s|%s|%s|%s" % [_over_view, final, cands, votes, can_spec, n.vote]
	if _over_view == "pts": _fill_pts_rows()
	if key == _over_key: return
	_over_key = key
	var had := get_viewport().gui_get_focus_owner()
	var had_txt := ""
	if had is UiKit.Btn and over_btns.is_ancestor_of(had): had_txt = str(had.get_meta("k", ""))
	for c in over_btns.get_children():
		over_btns.remove_child(c)
		c.queue_free()
	var mk := func(text: String, k: String, cb: Callable, on: bool) -> void:
		var b := UiKit.ghost(text, not on, Vector4(16, 10, 16, 10), 14)
		b.set_meta("k", k)
		b.pressed.connect(cb)
		over_btns.add_child(b)
		if k == had_txt: UiKit.focus.call_deferred(b)
	if not Net.standings().is_empty():
		mk.call("Uitslag van de race" if _over_view == "pts" else "Stand van de avond", "view", func():
			_over_view = "results" if _over_view == "pts" else "pts"
			if _over_view == "pts":
				Game.overView = "netpts"
				_fill_pts_rows()
			else:
				Game.overView = "results"
				Menu.overUI.results.set_meta("pts", "")
				Menu.buildResults()
			_over_fill(), false)
	if can_spec:
		mk.call("Meekijken", "spec", func(): Net.specStart(), false)
	if final:
		for c in cands:
			if not TrackDefs.TRACKS.has(str(c)): continue
			var id: String = c
			mk.call("%s%s" % [TrackDefs.TRACKS[id].name, " (%d)" % int(votes[id]) if votes.has(id) else ""], "v" + id, func(): Net.vote(id), n.vote == id)

## the standings of the evening in the results list (the race's own list comes back with the button)
func _fill_pts_rows() -> void:
	var O = Menu.overUI
	var st := Net.standings()
	var key := JSON.stringify(st)
	if O.results.get_meta("pts", "") == key and Game.overView == "netpts" and O.results.get_child_count() == st.size(): return
	O.results.set_meta("pts", key)
	UiKit.clear(O.results)
	for k in st.size():
		var e: Dictionary = st[k]
		O.results.add_child(O.row(e.me, "%d." % (k + 1), str(e.name) + ("" if e.here else " (weg)"),
			"%d %s · %d gewonnen" % [e.races, "race" if e.races == 1 else "races", e.wins], "+%d" % e.last, "%d pt" % e.pts))

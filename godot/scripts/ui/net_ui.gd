extends CanvasLayer
## Autoload "NetUi": the online screen (HTML home panel "Online spelen"), for LAN games without codes:
## games on this network show up by themselves (Net / LanDiscovery); joining by IP address for internet games.
## Inside a game: the players, and for the host the race settings and Start race.

var ov: ColorRect
var box: VBoxContainer
var nick: LineEdit
var lobby_box: VBoxContainer
var list: VBoxContainer
var ip_in: LineEdit
var game_box: VBoxContainer
var players: VBoxContainer
var host_ctl: VBoxContainer
var track_lbl: Label
var laps_lbl: Label
var bots_lbl: Label
var car_lbl: Label
var ip_note: Label
var upnp_note: Label
var status: Label
var start_btn: Button
var scroll: ScrollContainer
var leave_btn: Button

func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	ov = ColorRect.new()
	ov.color = Color(0.086, 0.1, 0.133, 0.45)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.visible = false
	add_child(ov)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(center)
	var card := Hud.SignBox.new(Vector4(28, 22, 28, 22))
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)
	# a tall game screen (host controls) scrolls inside the sign instead of running off a small window
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(Hud.mk_label("Online spelen", "italic 900 40px Barlow Condensed", Hud.SIGN_INK))
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 10)
	nr.add_child(_lab("Jouw naam"))
	nick = LineEdit.new()
	nick.max_length = 20
	nick.custom_minimum_size = Vector2(220, 0)
	_style_edit(nick)
	nick.text_changed.connect(func(t: String):
		G.prefs.nick = t if t.strip_edges() != "" else G.prefs.nick
		G.savePrefs()
		if Net.net != null: Net.net.game.presence({"nick": G.prefs.nick}))
	nr.add_child(nick)
	box.add_child(nr)
	# ---- not in a game: the games on this network, make one, or join by IP
	lobby_box = VBoxContainer.new()
	lobby_box.add_theme_constant_override("separation", 10)
	box.add_child(lobby_box)
	lobby_box.add_child(_eyebrow("Games op dit netwerk"))
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	lobby_box.add_child(list)
	var create := Hud.mk_button("Nieuwe game maken")
	create.pressed.connect(func(): Net.netCreate())
	lobby_box.add_child(create)
	lobby_box.add_child(_eyebrow("Via internet of een ander netwerk"))
	var ir := HBoxContainer.new()
	ir.add_theme_constant_override("separation", 10)
	ip_in = LineEdit.new()
	ip_in.placeholder_text = "IP-adres van de host"
	ip_in.custom_minimum_size = Vector2(240, 0)
	_style_edit(ip_in)
	ip_in.text_submitted.connect(func(t: String): _join_ip())
	ir.add_child(ip_in)
	var jb := Hud.mk_button("Meedoen", false)
	jb.pressed.connect(func(): _join_ip())
	ir.add_child(jb)
	lobby_box.add_child(ir)
	lobby_box.add_child(_note("Op hetzelfde netwerk (thuis, LAN-party) verschijnt de game van de host vanzelf in de lijst. Via internet: de host zet poort %d (UDP) open in zijn router, of klikt in zijn game op 'Via internet bereikbaar maken'." % NetRoom.PORT))
	# ---- in a game
	game_box = VBoxContainer.new()
	game_box.add_theme_constant_override("separation", 10)
	box.add_child(game_box)
	game_box.add_child(_eyebrow("Spelers"))
	players = VBoxContainer.new()
	players.add_theme_constant_override("separation", 4)
	game_box.add_child(players)
	host_ctl = VBoxContainer.new()
	host_ctl.add_theme_constant_override("separation", 6)
	game_box.add_child(host_ctl)
	track_lbl = _cycler(host_ctl, "Baan", func(d: int):
		var ids: Array = TrackLoader.ported()
		var i := ids.find(G.settings.track)
		G.settings.track = ids[(i + d + ids.size()) % ids.size()]
		G.saveSettings()
		get_tree().current_scene.load_track(G.settings.track)
		refresh())
	laps_lbl = _cycler(host_ctl, "Ronden", func(d: int):
		G.settings.laps = clampi(int(G.settings.laps) + d, 1, 5); G.saveSettings(); refresh())
	bots_lbl = _cycler(host_ctl, "Bots", func(d: int):
		G.settings.bots = clampi(mini(int(G.settings.bots), 5) + d, 0, 5); G.saveSettings(); refresh())
	start_btn = Hud.mk_button("Start race")
	start_btn.pressed.connect(func():
		close()
		Net.netHostStart())
	host_ctl.add_child(start_btn)
	ip_note = _note("")
	host_ctl.add_child(ip_note)
	var up := Hud.mk_button("Via internet bereikbaar maken", false)
	up.pressed.connect(func(): Net.open_internet())
	host_ctl.add_child(up)
	upnp_note = _note("")
	host_ctl.add_child(upnp_note)
	car_lbl = _cycler(game_box, "Auto", func(d: int):
		var ids: Array = Cars.CARS.keys()
		var i := ids.find(G.settings.car)
		G.settings.car = ids[(i + d + ids.size()) % ids.size()]
		G.saveSettings()
		Game.rebuildPlayerCar()
		if Net.net != null: Net.net.game.presence({"car": G.settings.car, "color": G.settings.color})
		refresh())
	status = _note("")
	box.add_child(status)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	box.add_child(nav)
	var back := Hud.mk_button("Terug", false)
	back.pressed.connect(func(): close())
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(back)
	leave_btn = Hud.mk_button("Game verlaten", false)
	leave_btn.pressed.connect(func():
		Net.netLeave()
		Net.browse()
		refresh())
	leave_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(leave_btn)
	Net.changed.connect(refresh)

func _lab(t: String) -> Label:
	return Hud.mk_label(t, "800 15px Nunito", Hud.SIGN_INK)

func _eyebrow(t: String) -> Label:
	return Hud.mk_label(t.to_upper(), "800 12px Nunito", Hud.LAB)

func _note(t: String) -> Label:
	var l := Hud.mk_label(t, "700 13px Nunito", Hud.SUB)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(500, 0)
	return l

func _style_edit(e: LineEdit) -> void:
	var f := Hud.font("800 16px Nunito")
	e.add_theme_font_override("font", f[0])
	e.add_theme_font_size_override("font_size", int(f[1]))
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.04, 0.08, 0.16, 0.28)
	st.set_corner_radius_all(12)
	st.border_color = Color(0.97, 0.97, 0.95, 0.35); st.set_border_width_all(2)
	st.content_margin_left = 12; st.content_margin_right = 12; st.content_margin_top = 8; st.content_margin_bottom = 8
	e.add_theme_stylebox_override("normal", st)
	var fo := st.duplicate(); fo.border_color = Hud.DETOUR
	e.add_theme_stylebox_override("focus", fo)
	e.add_theme_color_override("font_color", Hud.SIGN_INK)

func _cycler(parent: Control, label: String, cb: Callable) -> Label:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	var l := _lab(label)
	l.custom_minimum_size = Vector2(80, 0)
	var a := _arrow("◀")
	var v := Hud.mk_label("", "900 17px Nunito", Hud.SIGN_INK)
	v.custom_minimum_size = Vector2(230, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := _arrow("▶")
	a.pressed.connect(func(): cb.call(-1))
	b.pressed.connect(func(): cb.call(1))
	for c in [l, a, v, b]: r.add_child(c)
	parent.add_child(r)
	return v

## a small round arrow button for the option rows
func _arrow(t: String) -> Button:
	var b := Hud.mk_button(t, false)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(st).duplicate()
		sb.content_margin_left = 12; sb.content_margin_right = 12; sb.content_margin_top = 4; sb.content_margin_bottom = 4
		b.add_theme_stylebox_override(st, sb)
	return b

func _join_ip() -> void:
	var ip := ip_in.text.strip_edges()
	if ip == "":
		Net.netStatus("Vul het IP-adres van de host in.")
		return
	Net.netJoin(ip)

func open() -> void:
	ov.visible = true
	nick.text = G.prefs.nick
	if Net.net == null:
		Net.browse()
	refresh()

func close() -> void:
	ov.visible = false
	Net.stop_browse()

func is_open() -> bool:
	return ov.visible

func refresh() -> void:
	if not ov.visible:
		return
	var inGame: bool = Net.net != null
	lobby_box.visible = not inGame
	game_box.visible = inGame
	leave_btn.visible = inGame
	scroll.custom_minimum_size = Vector2(504, minf(box.get_combined_minimum_size().y, get_viewport().get_visible_rect().size.y - 90))
	status.text = Net.status
	status.visible = Net.status != ""
	if not inGame:
		for c in list.get_children(): c.queue_free()
		var ls := Net.lobbies()
		if ls.is_empty():
			list.add_child(_note("Nog geen games gevonden. Maak er zelf een aan, of wacht tot de host er een maakt."))
		for l in ls:
			list.add_child(_lobby_card(l))
		return
	for c in players.get_children(): c.queue_free()
	_player_row(G.prefs.nick, G.settings.car, Net.net.host, true)
	for r in Net.net.remotes.values():
		_player_row(r.name, r.carId, r.host, false)
	host_ctl.visible = Net.net.host
	track_lbl.text = TrackDefs.TRACKS[G.settings.track].name + (" (omgekeerd)" if G.settings.dir == "rev" else "")
	laps_lbl.text = str(G.settings.laps)
	bots_lbl.text = str(mini(int(G.settings.bots), 5))
	car_lbl.text = Cars.CARS[G.settings.car].name
	var ips := []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."): ips.append(a)
	ip_note.text = ("Jouw IP-adres (voor meedoen via IP): " + ", ".join(ips)) if not ips.is_empty() else ""
	upnp_note.text = Net.upnp_status
	upnp_note.visible = Net.upnp_status != ""

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
	v.add_child(Hud.mk_label("%s · %d van %d spelers" % [l.get("track", ""), int(l.get("n", 1)), int(l.get("max", 8))], "700 13px Nunito", Hud.SUB))
	h.add_child(v)
	var b := Hud.mk_button("Meedoen")
	b.pressed.connect(func(): Net.netJoin(str(l.ip)))
	h.add_child(b)
	return pc

func _player_row(name: String, carId, host: bool, me: bool) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var star := Hud.mk_label("★" if host else "", "900 16px Nunito", Hud.DETOUR)
	star.custom_minimum_size = Vector2(20, 0)
	h.add_child(star)
	h.add_child(Hud.mk_label(name + (" (jij)" if me else ""), "800 16px Nunito", Hud.SIGN_INK))
	h.add_child(Hud.mk_label(Cars.CARS[carId].name if Cars.CARS.has(str(carId)) else "", "700 13px Nunito", Hud.SUB))
	players.add_child(h)

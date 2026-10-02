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
var outer: VBoxContainer
var leave_btn: Button
var car_btn: Button
var create_btn: Button
var back_btn: Button

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
	outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	card.add_child(outer)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
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
		var n := t.strip_edges()
		if n == "" or n == G.prefs.nick: return
		G.prefs.nick = n
		G.savePrefs()
		if Net.net != null: Net.net.game.presence({"nick": n}))
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
	create_btn = Hud.mk_button("Nieuwe game maken")
	create_btn.pressed.connect(func(): Net.netCreate())
	lobby_box.add_child(create_btn)
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
	# your car: the car step of the menus (JS netCar), with only the cars you own and their colours
	var cr := HBoxContainer.new()
	cr.add_theme_constant_override("separation", 8)
	var cl := _lab("Auto")
	cl.custom_minimum_size = Vector2(80, 0)
	car_lbl = Hud.mk_label("", "900 17px Nunito", Hud.SIGN_INK)
	car_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	car_btn = Hud.mk_button("Auto kiezen", false)
	car_btn.pressed.connect(func():
		ov.visible = false
		Menu.menuFlow = "net"
		Menu.showMenu(0))
	for c in [cl, car_lbl, car_btn]: cr.add_child(c)
	game_box.add_child(cr)
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
	_focus_main()

## keyboard and gamepad: on the main button of this screen (when it opens, and when the focused button went away,
## like Nieuwe game maken or Meedoen once you are in a game)
func _focus_main() -> void:
	if not ov.visible: return
	var f: Control = (start_btn if Net.net.host else car_btn) if Net.net != null else create_btn
	f.grab_focus()

func close() -> void:
	ov.visible = false
	Net.stop_browse()
	# back on the button that opened this screen
	if Game.state == "menu" and Menu.homeUI.hNet.is_visible_in_tree(): UiKit.focus(Menu.homeUI.hNet)

func is_open() -> bool:
	return ov.visible

## Escape closes the online screen, like Terug (in the name or address field Menu._input first leaves the field)
func _input(e: InputEvent) -> void:
	if not ov.visible or not (e is InputEventKey) or not e.pressed or e.echo or e.keycode != KEY_ESCAPE: return
	if get_viewport().gui_get_focus_owner() is LineEdit: return
	get_viewport().set_input_as_handled()
	close()

static func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

func refresh() -> void:
	if not ov.visible:
		return
	var inGame: bool = Net.net != null
	lobby_box.visible = not inGame
	game_box.visible = inGame
	leave_btn.visible = inGame
	status.text = Net.status
	status.visible = Net.status != ""
	if not inGame:
		# keep the keyboard focus on the same card when the list changes
		var fo := get_viewport().gui_get_focus_owner()
		var fi := -1
		for i in list.get_child_count():
			if fo != null and list.get_child(i).is_ancestor_of(fo): fi = i
		_clear(list)
		var ls := Net.lobbies()
		if ls.is_empty():
			list.add_child(_note("Nog geen games gevonden. Maak er zelf een aan, of wacht tot de host er een maakt."))
		for l in ls:
			list.add_child(_lobby_card(l))
		if fi >= 0:
			var bs := list.get_child(mini(fi, list.get_child_count() - 1)).find_children("*", "Button", true, false)
			if not bs.is_empty() and not bs[0].disabled: bs[0].grab_focus()
			else: create_btn.grab_focus()
	else:
		_clear(players)
		_player_row(G.prefs.nick, G.settings.car, Net.net.host, true)
		for r in Net.net.remotes.values():
			_player_row(r.name, r.carId, r.host, false)
		host_ctl.visible = Net.net.host
		track_lbl.text = TrackDefs.TRACKS[G.settings.track].name + (" (omgekeerd)" if G.settings.dir == "rev" else "")
		laps_lbl.text = str(G.settings.laps)
		bots_lbl.text = str(mini(int(G.settings.bots), 5))
		car_lbl.text = Cars.CARS[G.settings.car].name
		var ips := lanAddresses()
		ip_note.text = (("Jouw IP-adres (voor meedoen via IP): " + ", ".join(ips.slice(0, 3)) + ". ") if not ips.is_empty() else "") + \
			"Zien anderen je game niet? Sta Polderrace toe in de Windows-firewall, ook voor openbare netwerken."
		upnp_note.text = Net.upnp_status
		upnp_note.visible = Net.upnp_status != ""
	scroll.custom_minimum_size = Vector2(504, minf(box.get_combined_minimum_size().y, get_viewport().get_visible_rect().size.y - 190))
	var fnow := get_viewport().gui_get_focus_owner()
	if fnow == null or not fnow.is_visible_in_tree(): _focus_main.call_deferred()

## this PC's IPv4 addresses, the real network first: VirtualBox, Hyper-V, VPN and other virtual adapters last,
## with the adapter's name when there are several ("192.168.1.20 (Wi-Fi)")
static func lanAddresses() -> Array:
	var found := []
	for it in IP.get_local_interfaces():
		var nm := str(it.get("friendly", it.get("name", "")))
		var low := nm.to_lower()
		var virt := 0
		for w in ["virtual", "vbox", "vmware", "vethernet", "hyper-v", "wsl", "docker", "vpn", "tap", "tun", "hamachi", "zerotier", "tailscale", "radmin", "bluetooth", "loopback", "virbr"]:
			if w in low: virt = 1
		for addr in it.get("addresses", []):
			var a := str(addr)
			if a.count(".") != 3 or a.begins_with("127.") or a.begins_with("169.254."): continue
			var b := int(a.get_slice(".", 1))
			var lan: bool = a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and b >= 16 and b < 32)
			var v := 1 if virt == 1 or a.begins_with("192.168.56.") else 0    # 192.168.56.x: VirtualBox host-only
			found.append({"a": a, "nm": nm, "k": v * 2 + (0 if lan else 1)})
	found.sort_custom(func(x, y): return x.k < y.k)
	var out := []
	for f in found:
		out.append(f.a + (" (%s)" % f.nm if found.size() > 1 and f.nm != "" else ""))
	return out

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
	var other: bool = int(l.get("v", 1)) != NetRoom.PROTO
	var full: bool = not l.get("open", true)
	var sub := "%s · %d van %d spelers" % [l.get("track", ""), int(l.get("n", 1)), int(l.get("max", 8))]
	if other: sub += " · andere versie van het spel"
	elif full: sub += " · vol"
	elif l.get("race", false): sub += " · race bezig, je doet mee vanaf de volgende"
	var sl := Hud.mk_label(sub, "700 13px Nunito", Hud.SUB)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)
	h.add_child(v)
	var b := Hud.mk_button("Meedoen")
	b.disabled = other or full
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

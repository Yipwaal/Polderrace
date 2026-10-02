class_name GarageUI
extends RefCounted
## The garage panel of the HTML game (JS #homeGarage, openGarage, garTab, buildGarageDom): tabs Prestaties (class, cars
## with buying, upgrades) and Uiterlijk (paint, rims, rim style, wing, exhaust, stripes, start number). The car itself
## stands in the garage room (GarageRoom) beside the panel.

var content: VBoxContainer
var nav: HBoxContainer
var back: UiKit.Btn
var credits: PanelContainer
var tabPerf: UiKit.Btn
var tabLook: UiKit.Btn
var perf: VBoxContainer
var look: VBoxContainer
var classRadio: UiKit.Radio
var carRadio: UiKit.Radio
var carCards := {}            ## id -> {b, name, badge, line}
var garStats: Label
var upgBox: PanelContainer
var upgRows: VBoxContainer
var paintRadio: UiKit.Radio
var paintPick: UiKit.Btn
var pickPopup: PopupPanel
var picker: ColorPicker
var rimRadio: UiKit.Radio
var rimStyleRadio: UiKit.Radio
var wingRadio: UiKit.Radio
var exhRadio: UiKit.Radio
var exhRow: Control
var stripeRadio: UiKit.Radio
var numIn: LineEdit

func _init() -> void:
	content = UiKit.vbox(16)
	var head := UiKit.FlexRow.new(12, 12)
	head.grow_first = false
	head.add_child(UiKit.h2("Garage"))
	credits = UiKit.credits_pill()
	head.add_child(credits)
	content.add_child(head)
	# tabs
	var tv := UiKit.vbox(0)
	var th := UiKit.hbox(20)
	tabPerf = _tab("Prestaties")
	tabLook = _tab("Uiterlijk")
	tabPerf.pressed.connect(func() -> void: garTab("perf"))
	tabLook.pressed.connect(func() -> void: garTab("look"))
	th.add_child(tabPerf); th.add_child(tabLook)
	tv.add_child(th)
	tv.add_child(UiKit.hline(UiKit.LINE3))
	content.add_child(tv)
	_build_perf()
	_build_look()
	garTab("perf")
	var n := HomeUI.back_nav()
	nav = n[0]
	back = n[1]

func _tab(text: String) -> UiKit.Btn:
	var b := UiKit.Btn.new(UiKit.pad_box(Vector4(4, 10, 4, 0)))
	b.radius = 8
	b.ring_off = -3.0
	var v := UiKit.vbox(9)
	var l := UiKit.lbl(text, 800, 16, UiKit.LAB, false, 0, false, 1.0)
	var u := ColorRect.new()
	u.color = UiKit.DETOUR
	u.custom_minimum_size = Vector2(0, 3)
	u.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l); v.add_child(u)
	b.add_child(v)
	b.watch(func(c: bool, _h: bool) -> void:
		l.add_theme_color_override("font_color", UiKit.SIGN_INK if c else UiKit.LAB)
		UiKit.reweight(l, 900 if c else 800)
		u.color = UiKit.DETOUR if c else Color(0, 0, 0, 0))
	return b

func garTab(t: String) -> void:
	tabPerf.checked = t == "perf"
	tabLook.checked = t == "look"
	perf.visible = t == "perf"
	look.visible = t == "look"

# ------------------------------------------------------------------ Prestaties
func _build_perf() -> void:
	perf = UiKit.vbox(16)
	var s := UiKit.seg([["B", "Klasse B"], ["A", "Klasse A"], ["S", "Klasse S"]], func(v) -> void:
		if Cars.CARS[G.settings.car].cls != v:
			var lb = G.settings.get("lastByClass", {})
			Menu.pickCar(lb.get(v, Cars.carsOf(v)[0]) if lb is Dictionary and lb.get(v) else Cars.carsOf(v)[0])
			openGarage(), true)
	classRadio = s[1]
	perf.add_child(s[0])
	var grid := UiKit.EqGrid.new(2, 8, 8)
	carRadio = UiKit.Radio.new(func(v) -> void:
		Menu.pickCar(v)
		openGarage())
	for id in Cars.CARS:
		var b := UiKit.ccard()
		var v: VBoxContainer = b.get_child(0)
		var top := UiKit.hbox(6)
		top.custom_minimum_size.y = 21
		var nm := UiKit.lbl(Cars.CARS[id].name, 800, 16, UiKit.SIGN_INK, true, 0, false, 1.1)
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(nm)
		var bd := UiKit.badge("in gebruik")
		top.add_child(bd)
		v.add_child(top)
		var line := UiKit.hbox(6)
		line.custom_minimum_size.y = 18
		v.add_child(line)
		b.tint(nm, UiKit.SIGN_INK, UiKit.INK, 800, 900)
		b.watch(func(c: bool, _h: bool) -> void: UiKit.badge_on(bd, c))
		carCards[id] = {"b": b, "badge": bd, "line": line}
		grid.add_child(b)
		carRadio.add(b, id)
	perf.add_child(grid)
	garStats = UiKit.note("")
	garStats.visible = false
	perf.add_child(garStats)
	upgBox = UiKit.panel(UiKit.flat(UiKit.CARD, 16))
	upgRows = UiKit.vbox(0)
	upgBox.add_child(upgRows)
	perf.add_child(upgBox)
	perf.add_child(UiKit.note("Geld verdien je met races, tijdritten en de carrière. Hoger niveau en betere plek levert meer op. Je tegenstanders tunen mee: upgrades geven je een voorsprong, maar winnen moet je nog steeds zelf. Sleep naast het paneel om de auto rond te draaien.", true))
	content.add_child(perf)

## the line under a car card: its stats when you own it, else a lock with the price
func _card_line(line: HBoxContainer, id: String, own: bool, on: bool) -> void:
	UiKit.clear(line)
	if own:
		line.add_child(UiKit.lbl(Menu.carStatsLine(id), 700, 12, UiKit.INK if on else UiKit.SUB, false, 0, false, 1.3))
	else:
		var c := UiKit.INK if on else UiKit.DETOUR
		var ic := UiKit.icon("lock", 13, 2.4, c)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(ic)
		line.add_child(UiKit.lbl(G.fmtCr(Career.CAR_PRICE.get(id, 0)), 800, 13, c))

## JS openGarage: the cards, the upgrades (or the buy row) and the looks of the chosen car
func openGarage() -> void:
	var S := G.settings
	if Career.owns(S.car): Menu.garageCar = S.car
	var cls: String = Cars.CARS[S.car].cls
	classRadio.sync(cls)
	UiKit.pill_text(credits, G.fmtCr(G.garage.credits))
	carRadio.sync(S.car)
	for id in carCards:
		var cc: Dictionary = carCards[id]
		cc.b.visible = Cars.CARS[id].cls == cls
		cc.badge.visible = id == S.car and Career.owns(id)
		_card_line(cc.line, id, Career.owns(id), id == S.car)
	var u := G.carUp(S.car)
	UiKit.clear(upgRows)
	rimRadio.sync(u.rim); stripeRadio.sync(u.stripe); wingRadio.sync(u.wing); rimStyleRadio.sync(u.rimStyle); exhRadio.sync(u.exhaust)
	exhRow.visible = cls != "S"
	paintRadio.sync(S.color)
	_pick_color(Color(S.color))
	numIn.text = str(int(u.num)) if int(u.get("num", 0)) > 0 else ""
	var e := G.effStats(S.car)
	garStats.text = "%s: %d km/u top, acceleratie %s, grip %s" % [Cars.CARS[S.car].name, int(round(e.vmax)), Menu.f1(Menu.nA(e.acc)), Menu.f1(Menu.nG(e.grip))]
	if not Career.owns(S.car):
		var p: int = Career.CAR_PRICE.get(S.car, 0)
		var r := UiKit.hbox(16)
		var t := UiKit.vbox(0)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.add_child(UiKit.lbl("Nog niet in bezit", 800, 16, UiKit.SIGN_INK, true, 0, false, 1.2))
		t.add_child(UiKit.lbl(Menu.carStatsLine(S.car) + " · kopen om hem in de carrière te rijden en te upgraden", 600, 12, UiKit.SUB, true, 0, false, 1.3))
		r.add_child(t)
		var pr := UiKit.lbl(G.fmtCr(p), 900, 14, UiKit.DETOUR)
		pr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(pr)
		var b := UiKit.cta("Kopen", Vector4(12, 10, 12, 10), 14)
		(b.get_meta("label") as Label).add_theme_color_override("font_color", UiKit.SIGN_INK)
		b.custom_minimum_size.x = 96
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = G.garage.credits < p
		b.pressed.connect(func() -> void:
			if Career.buyCar(S.car): openGarage())
		b.set_meta("buy", true)
		r.add_child(b)
		upgRows.add_child(UiKit.margin(r, Vector4(18, 9, 10, 9)))
		return
	for k in G.UPG.size():
		var g: Dictionary = G.UPG[k]
		var lvl := int(u.get(g.k, 0))
		if k > 0: upgRows.add_child(UiKit.hline(UiKit.LINE2))
		var r := UiKit.hbox(16)
		var t := UiKit.vbox(0)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.add_child(UiKit.lbl(g.name, 800, 16, UiKit.SIGN_INK, true, 0, false, 1.2))
		t.add_child(UiKit.lbl(g.desc, 600, 12, UiKit.SUB, true, 0, false, 1.3))
		r.add_child(t)
		var pips := UiKit.hbox(4)
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for j in 3:
			var pip := UiKit.panel(UiKit.flat(UiKit.DETOUR if j < lvl else UiKit.SHADE, 999))
			pip.custom_minimum_size = Vector2(18, 8)
			pips.add_child(pip)
		r.add_child(pips)
		var b: UiKit.Btn
		if lvl >= 3:
			b = UiKit.ghost("Max", false, Vector4(12, 10, 12, 10), 14)
			b.disabled = true
		else:
			var c := G.upCost(S.car, g, lvl)
			b = UiKit.ghost(G.fmtCr(c), false, Vector4(12, 10, 12, 10), 14)
			b.disabled = G.garage.credits < c
			var gk: String = g.k
			b.pressed.connect(func() -> void:
				if G.garage.credits < c: return
				G.garage.credits -= c
				u[gk] = lvl + 1
				G.saveGarage()
				if G.UPG.all(func(q): return int(u.get(q.k, 0)) >= 3): Ach.unlockAch("maxed")
				Game.rebuildPlayerCar()
				Sfx.tone(880, 0.12, "triangle", 0.12); Sfx.tone(1320, 0.2, "triangle", 0.12, 0.1)
				openGarage()
				UiKit.focus(_buy_buttons()[k]))
		var bl: Label = b.get_meta("label")
		UiKit.reweight(bl, 900)
		bl.add_theme_color_override("font_color", UiKit.LAB if b.disabled else UiKit.SIGN_INK)
		if b.disabled: b.dis_alpha = 0.8; b.restyle()
		b.custom_minimum_size.x = 96
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.set_meta("buy", true)
		r.add_child(b)
		upgRows.add_child(UiKit.margin(r, Vector4(18, 9, 10, 9)))

func _pick_color(c: Color) -> void:
	var sw = paintPick.get_child(0)
	sw.col = c
	sw.queue_redraw()

func _buy_buttons() -> Array:
	var out := []
	for m in upgRows.get_children():
		if m is MarginContainer:
			for c in m.get_child(0).get_children():
				if c is UiKit.Btn and c.has_meta("buy"): out.append(c)
	return out

func first_buy() -> UiKit.Btn:
	var b := _buy_buttons()
	return b[0] if not b.is_empty() else null

# ------------------------------------------------------------------ Uiterlijk
func _look_seg(items: Dictionary, key: String) -> Array:
	var its := []
	for k in items:
		var v = items[k]
		its.append([k, v[0] if v is Array else v])
	return UiKit.seg(its, func(v) -> void:
		G.carUp(G.settings.car)[key] = v
		G.saveGarage()
		Game.rebuildPlayerCar()
		openGarage())

func _build_look() -> void:
	look = UiKit.vbox(16)
	var pv := UiKit.vbox(10)
	pv.add_child(UiKit.eyebrow("Lakkleur"))
	var row := UiKit.FlexRow.new(10, 10)
	var well := UiKit.panel(UiKit.flat(UiKit.WELL, 23, Vector4(12, 8, 12, 8)))
	var sw := UiKit.hbox(12)
	well.add_child(sw)
	paintRadio = UiKit.Radio.new(func(v) -> void:
		G.settings.color = v
		G.saveSettings()
		Game.rebuildPlayerCar()
		openGarage())
	for c in Cars.COLORS:
		var b := UiKit.swatch(Color(c))
		sw.add_child(b)
		paintRadio.add(b, c)
	row.add_child(well)
	var pick := UiKit.panel(UiKit.flat(UiKit.WELL, 999, Vector4(16, 8, 10, 8)))
	var ph := UiKit.hbox(8)
	pick.add_child(ph)
	var pl := UiKit.lbl("Eigen kleur", 800, 13, UiKit.SIGN_INK)
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(pl)
	# the colour input (<input type=color>): a round swatch that opens a colour picker
	paintPick = UiKit.swatch(Color(G.settings.color))
	paintPick.ring_off = 2.0
	paintPick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pickPopup = PopupPanel.new()
	picker = ColorPicker.new()
	picker.edit_alpha = false
	picker.presets_visible = false
	pickPopup.add_child(picker)
	picker.color_changed.connect(func(c: Color) -> void:
		G.settings.color = "#" + c.to_html(false)
		G.saveSettings()
		Game.rebuildPlayerCar()
		_pick_color(c)
		paintRadio.sync(G.settings.color))
	paintPick.pressed.connect(func() -> void:
		if pickPopup.get_parent() == null: paintPick.get_tree().root.add_child(pickPopup)
		picker.color = Color(G.settings.color)
		var r := paintPick.get_global_rect()
		pickPopup.popup(Rect2i(int(r.position.x), int(r.end.y + 6), 0, 0)))
	ph.add_child(paintPick)
	row.add_child(pick)
	row.min_first = 290    # .paintrow .colors{flex:1 1 290px}
	pv.add_child(row)
	look.add_child(pv)
	var rs := _look_seg(G.RIMS, "rim"); rimRadio = rs[1]
	var ms := _look_seg(G.RIMSTYLES, "rimStyle"); rimStyleRadio = ms[1]
	var ws := _look_seg(G.WINGS, "wing"); wingRadio = ws[1]
	var es := _look_seg(G.EXHAUSTS, "exhaust"); exhRadio = es[1]
	var ss := _look_seg(G.STRIPES, "stripe"); stripeRadio = ss[1]
	numIn = LineEdit.new()
	numIn.custom_minimum_size = Vector2(84, 0)
	numIn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	numIn.placeholder_text = "–"
	numIn.max_length = 2
	numIn.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	numIn.add_theme_font_override("font", UiKit.font(900))
	numIn.add_theme_font_size_override("font_size", 18)
	numIn.add_theme_color_override("font_color", UiKit.SIGN_INK)
	numIn.add_theme_color_override("font_placeholder_color", UiKit.LAB)
	numIn.add_theme_color_override("caret_color", UiKit.SIGN_INK)
	var nst := UiKit.flat(UiKit.WELL, 10, Vector4(8, 9, 8, 9))
	var nfo := nst.duplicate()
	nfo.border_color = Color.WHITE; nfo.set_border_width_all(2)
	numIn.add_theme_stylebox_override("normal", nst)
	numIn.add_theme_stylebox_override("focus", nfo)
	numIn.add_theme_stylebox_override("read_only", nst)
	var commit := func(_t = null) -> void:
		var n := clampi(int(numIn.text) if numIn.text.is_valid_int() else 0, 0, 99)
		numIn.text = str(n) if n > 0 else ""
		var u := G.carUp(G.settings.car)
		if int(u.get("num", 0)) == n: return
		u.num = n
		G.saveGarage()
		Game.rebuildPlayerCar()
		openGarage()
	numIn.text_submitted.connect(commit)
	numIn.focus_exited.connect(commit)
	exhRow = UiKit.opt(UiKit.optl("Uitlaat", "Alleen klasse B en A"), es[0], Vector4(18, 10, 12, 10))
	var rows := [UiKit.opt(UiKit.optl("Velgen"), rs[0], Vector4(18, 10, 12, 10)), UiKit.opt(UiKit.optl("Velgmodel"), ms[0], Vector4(18, 10, 12, 10)),
		UiKit.opt(UiKit.optl("Spoiler"), ws[0], Vector4(18, 10, 12, 10)), exhRow, UiKit.opt(UiKit.optl("Striping"), ss[0], Vector4(18, 10, 12, 10)),
		UiKit.opt(UiKit.optl("Startnummer", "1 tot 99, leeg is geen nummer"), numIn, Vector4(18, 10, 12, 10))]
	var card := UiKit.rows_card(rows)
	look.add_child(card)
	# the line above the exhaust row goes with it (S class has no exhaust choice)
	var lines := card.get_child(0)
	var sep_before: Control = lines.get_child(lines.get_children().find(exhRow) - 1)
	exhRow.visibility_changed.connect(func() -> void: sep_before.visible = exhRow.visible)
	look.visible = false
	content.add_child(look)

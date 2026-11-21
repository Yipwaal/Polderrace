class_name GarageUI
extends RefCounted
## The garage panel (JS #homeGarage, openGarage, garTab, buildGarageDom): tabs Prestaties (class, cars with buying,
## upgrades) and Uiterlijk: every item of the looks catalogue (CarLook.ITEMS) in its group, built from the catalogue.
## The car itself stands in the garage room (GarageRoom) beside the panel and shows every choice at once.
## Looking is free: a choice you do not own hangs in the fitting room (G.fit) until you buy it in the bar at the bottom.

var content: VBoxContainer
var nav: Control
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
var tab := "perf"
# Uiterlijk
var groupRadio: UiKit.Radio
var group := "lak"
var groupBoxes := {}          ## group id -> the card with its rows
var rows := {}                ## catalogue key -> {root, line, radio, info, sync}
var numIn: LineEdit
var texts := {}               ## key -> LineEdit (plate, band)
var pickPopup: PopupPanel
var picker: ColorPicker
var mixKey := ""              ## the colour item the colour picker is open for
var lastMix := {}             ## key -> the colour last mixed for it
var lookTools: Control        ## Willekeurig, Standaard, Licht uit
var darkBtn: UiKit.Btn
var fitBar: PanelContainer
var fitText: Label
var fitNote: Label
var fitBtns: Control
var fitBuy: UiKit.Btn
var fitUndo: UiKit.Btn

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
	_build_nav()

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
	tab = t
	tabPerf.checked = t == "perf"
	tabLook.checked = t == "look"
	perf.visible = t == "perf"
	look.visible = t == "look"
	if lookTools != null: lookTools.visible = t == "look"
	if t == "look":
		syncLook()
		_aim("")
	else:
		leaveLook()
		GarageRoom.aim("q")

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
	if G.fit.car != "" and G.fit.car != S.car: G.fitClear()    # another car: what was being fitted goes back
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
	syncLook()
	var e := G.effStats(S.car)
	garStats.text = "%s: %d km/u top, acceleratie %s, grip %s" % [Cars.CARS[S.car].name, int(round(e.vmax)), Menu.f1(Menu.nA(e.acc)), Menu.f1(Menu.nG(e.grip))]
	if not Career.owns(S.car):
		var p: int = Career.CAR_PRICE.get(S.car, 0)
		var r := UiKit.hbox(16)
		var t := UiKit.vbox(0)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.add_child(UiKit.lbl("Nog niet in bezit", 800, 16, UiKit.SIGN_INK, true, 0, false, 1.2))
		t.add_child(_upn_small(Menu.carStatsLine(S.car) + " · kopen om hem in de carrière te rijden en te upgraden"))
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
		t.add_child(_upn_small(g.desc))
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

## .upn small is inline text in a block: its line box gets the parent's 16 px Nunito strut (line-height normal,
## 21.8 px with the baseline 16.2 px down), so the row is taller than the small text itself
static func _upn_small(text: String) -> Control:
	return UiKit.margin(UiKit.lbl(text, 600, 12, UiKit.SUB, true, 0, false, 1.3), Vector4(0, 4, 0, 2))

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
const MIX := "#mix"       ## the radio value of the "own colour" swatch

## a colour swatch: a colour, "none" (off) or "mix" (own colour); coin = for sale
class LookSwatch extends Control:
	var col := Color.WHITE
	var kind := ""
	var on := false
	var coin := false
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := size.x / 2
		var c := size / 2
		if on:
			draw_circle(c, r + 6, UiKit.DETOUR, true, -1, true)
			draw_circle(c, r + 3, UiKit.INK, true, -1, true)
		if kind == "none":
			draw_circle(c, r, UiKit.SHADE, true, -1, true)
			draw_line(c + Vector2(-r, r) * 0.6, c + Vector2(r, -r) * 0.6, UiKit.SIGN_INK, 2.0, true)
		elif kind == "mix":
			for k in 12:
				var pts := PackedVector2Array([c])
				for j in 4:
					var a := (k + j / 3.0) / 12.0 * TAU
					pts.append(c + Vector2(cos(a), sin(a)) * r)
				draw_colored_polygon(pts, Color.from_hsv(k / 12.0, 0.85, 1.0))
			draw_circle(c, r * 0.56, col, true, -1, true)
		else:
			draw_circle(c, r, col, true, -1, true)
		draw_arc(c, r - 1, 0, TAU, 40, Color(247 / 255.0, 247 / 255.0, 242 / 255.0, 0.22), 2, true)
		if coin:
			var p := c + Vector2(r, r) * 0.74
			draw_circle(p, 6.0, UiKit.INK, true, -1, true)
			draw_circle(p, 4.2, UiKit.DETOUR, true, -1, true)

func _swatch(c: Color, kind := "") -> UiKit.Btn:
	var b := UiKit.Btn.new(StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(30, 30)
	b.ring_off = 2.0
	b.ring_w = 2.0
	var sw := LookSwatch.new()
	sw.col = c
	sw.kind = kind
	b.add_child(sw)
	b.set_meta("sw", sw)
	b.watch(func(on: bool, _h: bool) -> void: sw.on = on; sw.queue_redraw())
	return b

## an option chip: its name and, while it is not yours, what it costs (or a lock)
func _chip(text: String) -> UiKit.Btn:
	var pad := Vector4(12, 8, 12, 8)
	var b := UiKit.Btn.new(UiKit.flat(UiKit.LITE, 999, pad), UiKit.flat(UiKit.LITE_HI, 999, pad), UiKit.flat(UiKit.DETOUR, 999, pad))
	b.ring_off = -3.0
	b.ring_col_on = UiKit.INK
	var h := UiKit.hbox(6)
	var l := UiKit.lbl(text, 800, 13, UiKit.SIGN_INK, false, 0, false, 1.0)
	h.add_child(l)
	var lock := UiKit.icon("lock", 12, 2.6, UiKit.DETOUR)
	lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lock.visible = false
	h.add_child(lock)
	var tag := UiKit.lbl("", 800, 12, UiKit.DETOUR, false, 0, false, 1.0)
	tag.visible = false
	h.add_child(tag)
	b.add_child(h)
	b.tint(l, UiKit.SIGN_INK, UiKit.INK, 800, 900)
	b.watch(func(on: bool, _h: bool) -> void:
		tag.add_theme_color_override("font_color", UiKit.INK if on else UiKit.DETOUR)
		lock.col = UiKit.INK if on else UiKit.DETOUR
		lock.queue_redraw())
	b.set_meta("tag", tag)
	b.set_meta("lock", lock)
	return b

static func _flow(gap := 6) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", gap)
	f.add_theme_constant_override("v_separation", gap)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f

func _field(width: float, max_len: int, placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.custom_minimum_size = Vector2(width, 0)
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.placeholder_text = placeholder
	e.max_length = max_len
	e.add_theme_font_override("font", UiKit.font(900))
	e.add_theme_font_size_override("font_size", 18)
	e.add_theme_color_override("font_color", UiKit.SIGN_INK)
	e.add_theme_color_override("font_placeholder_color", UiKit.LAB)
	e.add_theme_color_override("caret_color", UiKit.SIGN_INK)
	var nst := UiKit.flat(UiKit.WELL, 10, Vector4(8, 9, 8, 9))
	var nfo := nst.duplicate()
	nfo.border_color = Color.WHITE; nfo.set_border_width_all(2)
	e.add_theme_stylebox_override("normal", nst)
	e.add_theme_stylebox_override("focus", nfo)
	e.add_theme_stylebox_override("read_only", nst)
	return e

## the radio group of a catalogue item (tests and tools)
func radio(k: String) -> UiKit.Radio:
	return rows[k].radio if rows.has(k) else null

func _build_look() -> void:
	look = UiKit.vbox(14)
	var gf := _flow(6)
	groupRadio = UiKit.Radio.new(func(v) -> void: lookGroup(v))
	for g in CarLook.GROUPS:
		var b := UiKit.chip(g[1])
		gf.add_child(b)
		groupRadio.add(b, g[0])
	look.add_child(gf)
	for g in CarLook.GROUPS:
		var card := UiKit.panel(UiKit.flat(UiKit.CARD, 16))
		var v := UiKit.vbox(0)
		card.add_child(v)
		for it in CarLook.itemsOf(g[0]):
			v.add_child(_row(it))
		groupBoxes[g[0]] = card
		look.add_child(card)
	look.add_child(UiKit.note("Kijken is gratis: wat je nog niet hebt, hangt in de paskamer tot je het koopt. Lak, stickers en sets koop je één keer, voor al je auto's. Ga je de garage uit, dan gaat wat niet betaald is terug in het rek. Niets hiervan maakt de auto sneller.", true))
	pickPopup = PopupPanel.new()
	picker = ColorPicker.new()
	picker.edit_alpha = false
	picker.presets_visible = false
	pickPopup.add_child(picker)
	picker.color_changed.connect(_mixed)
	look.visible = false
	content.add_child(look)
	lookGroup("lak")

## one row of the look tab: the item's name with what is on the car now, and its control
func _row(it: Dictionary) -> Control:
	var k: String = it.k
	var root := UiKit.vbox(0)
	var body := UiKit.vbox(8)
	var head := UiKit.hbox(10)
	var name := UiKit.vbox(2)
	name.add_child(UiKit.lbl(it.name, 800, 16, UiKit.SIGN_INK, true, 0, false, 1.2))
	if it.has("sub"): name.add_child(UiKit.lbl(it.sub, 600, 12, UiKit.SUB, true, 0, false, 1.3))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	var info := UiKit.lbl("", 700, 12, UiKit.SUB, false, 0, false, 1.2)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(info)
	body.add_child(head)
	var r := {"root": root, "info": info, "radio": null, "item": it}
	match it.type:
		"choice":
			var plain: bool = it.opts.size() <= 4 and it.opts.all(func(o): return int(o[2]) == 0 and (o.size() < 4 or not o[3].has("ach")))
			var rg := UiKit.Radio.new(func(v) -> void: pick(k, v))
			if plain:
				# a few free options: the pill of the other menus, beside the name
				var s := UiKit.seg(it.opts.map(func(o): return [o[0], o[1]]), func(v) -> void: pick(k, v))
				rg = s[1]
				s[0].size_flags_vertical = Control.SIZE_SHRINK_CENTER
				head.remove_child(info)
				head.add_child(s[0])
				r.info = null
			else:
				var f := _flow(6)
				for o in it.opts:
					var b := _chip(o[1])
					f.add_child(b)
					rg.add(b, o[0])
				body.add_child(f)
			r.radio = rg
		"color":
			var f := _flow(10)
			var rg := UiKit.Radio.new(func(v) -> void:
				if v is String and v == MIX: v = _mixColor(k)
				pick(k, v))
			if it.has("none"):
				var b := _swatch(Color.WHITE, "none")
				b.tooltip_text = it.none
				f.add_child(b)
				rg.add(b, "")
			for o in it.opts:
				var b := _swatch(CarLook.colorOf(k, o[0]))
				b.tooltip_text = o[1] + ((" · " + G.fmtCr(o[2])) if int(o[2]) > 0 else "")
				f.add_child(b)
				rg.add(b, o[0])
			if it.get("mix", false):
				var b := _swatch(Color.WHITE, "mix")
				b.tooltip_text = "Eigen kleur"
				f.add_child(b)
				rg.add(b, MIX)
				r.mix = b
				# a click or Enter opens the colour picker (an arrow key only puts the colour on)
				b.pressed.connect(func() -> void: _openPicker(k, b))
			var well := UiKit.margin(f, Vector4(6, 6, 6, 6))
			body.add_child(well)
			r.radio = rg
		"num":
			var st := UiKit.stepper(func(d: int) -> void:
				pick(k, clampi(int(G.lookShown(G.settings.car, k)) + d, 0, 99)))
			numIn = _field(64, 2, "–")
			numIn.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
			var commit := func(_t = null) -> void:
				var n := clampi(int(numIn.text) if numIn.text.is_valid_int() else 0, 0, 99)
				numIn.text = str(n) if n > 0 else ""
				if int(G.lookShown(G.settings.car, k)) != n: pick(k, n)
			numIn.text_submitted.connect(commit)
			numIn.focus_exited.connect(commit)
			# <input type=number>: only digits go in (a letter typed in between, like M, is not taken)
			numIn.text_changed.connect(func(t: String) -> void:
				var d := ""
				for ch in t:
					if ch >= "0" and ch <= "9": d += ch
				if d == t: return
				var cc := numIn.caret_column - (t.length() - d.length())
				numIn.text = d
				numIn.caret_column = clampi(cc, 0, d.length()))
			# the field between the minus and the plus of the stepper
			var srow: HBoxContainer = st.box.get_child(0)
			st.out.visible = false
			srow.add_child(numIn)
			srow.move_child(numIn, 1)
			st.box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			head.remove_child(info)
			head.add_child(st.box)
			r.info = null
			r.stepper = st
		"text":
			var e := _field(190, int(it.max), "–")
			var commit := func(_t = null) -> void:
				var v = CarLook.cleanValue(k, e.text)
				e.text = v
				if str(G.lookShown(G.settings.car, k)) != v: pick(k, v)
			e.text_submitted.connect(commit)
			e.focus_exited.connect(commit)
			e.text_changed.connect(func(t: String) -> void:
				var d := ""
				for ch in t.to_upper():
					if it.chars.contains(ch): d += ch
				if d == t: return
				var cc := e.caret_column - (t.length() - d.length())
				e.text = d
				e.caret_column = clampi(cc, 0, d.length()))
			e.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			head.add_child(e)
			texts[k] = e
	root.add_child(UiKit.margin(body, Vector4(18, 11, 12, 11)))
	var line := UiKit.hline(UiKit.LINE)
	root.add_child(line)
	r.line = line
	rows[k] = r
	return root

func lookGroup(g: String) -> void:
	group = g
	groupRadio.sync(g)
	for id in groupBoxes: groupBoxes[id].visible = id == g
	if tab == "look" and GarageRoom.inGarage: _aim("")

## the camera turns to what is being changed: the item's view, or the group's first item
func _aim(k: String, v = null) -> void:
	var view := ""
	if k != "":
		view = CarLook.extra(k, v).get("view", CarLook.item(k).get("view", ""))
	else:
		var its := CarLook.itemsOf(group)
		if not its.is_empty(): view = its[0].get("view", "")
	if view != "": GarageRoom.aim(view)

func _mixColor(k: String) -> String:
	if lastMix.has(k): return lastMix[k]
	var cur = G.lookShown(G.settings.car, k)
	return cur if CarLook.isHex(cur) and CarLook.option(k, cur) == null else "#ff7a00"

func _openPicker(k: String, b: Control) -> void:
	mixKey = k
	if pickPopup.get_parent() == null: b.get_tree().root.add_child(pickPopup)
	picker.color = Color(_mixColor(k))
	var r := b.get_global_rect()
	# below the swatch, but inside the window (a small window: beside or over the swatch rather than off the screen)
	var vs := b.get_viewport().get_visible_rect().size
	var ps := pickPopup.get_contents_minimum_size()
	var x := clampf(r.position.x, 0.0, maxf(0.0, vs.x - ps.x))
	var y := clampf(r.end.y + 6, 0.0, maxf(0.0, vs.y - ps.y))
	pickPopup.popup(Rect2i(int(x), int(y), 0, 0))

## a colour from the colour picker (only while it is open for a row of the look tab)
func _mixed(c: Color) -> void:
	if mixKey == "" or not pickerOpen() or not GarageRoom.inGarage: return
	var hex := "#" + c.to_html(false)
	lastMix[mixKey] = hex
	pick(mixKey, hex)

func pickerOpen() -> bool:
	return pickPopup != null and pickPopup.visible

func closePicker() -> void:
	if pickerOpen(): pickPopup.hide()
	mixKey = ""

## the gamepad while the colour picker is open (Menu.padNav reads the pad itself, past the popup): left/right turn the
## hue, up/down make it lighter or darker, A or B closes it (B does not leave the garage). true = handled
func padPicker(now: Dictionary, prev: Dictionary) -> bool:
	if not pickerOpen(): return false
	var edge := func(k: String) -> bool: return now.get(k, false) and not prev.get(k, false)
	if edge.call("a") or edge.call("b") or edge.call("start"):
		var k := mixKey
		closePicker()
		if rows.has(k) and rows[k].has("mix"): UiKit.focus(rows[k].mix)
		return true
	var c := picker.color
	var h := c.h
	var v := c.v
	var sat := maxf(c.s, 0.35)
	if edge.call("l"): h -= 1.0 / 24
	if edge.call("r"): h += 1.0 / 24
	if edge.call("up"): v += 0.1
	if edge.call("down"): v -= 0.1
	var n := Color.from_hsv(fposmod(h, 1.0), sat, clampf(v, 0.15, 1.0))
	if not n.is_equal_approx(c):
		picker.color = n
		_mixed(n)
	return true

## a choice in the look tab: on the car at once; saved when it is yours, else in the fitting room
func pick(k: String, v) -> void:
	# (only in the garage: a text field that commits as it is hidden, after the garage was left, must not fill the fitting
	# room the race car is styled from)
	if not GarageRoom.inGarage: return
	var car: String = G.settings.car
	G.lookPick(car, k, v)
	if k == "stripe":
		# a design comes in its own colours
		var cols: Array = CarLook.extra(k, v).get("cols", [])
		for i in cols.size(): G.lookPick(car, ["sc", "sc2"][i], cols[i])
	_aim(k, v)
	Game.rebuildPlayerCar()
	syncLook()

## the look tab shows the car as it stands (with the fitting room): checked options, what things cost, which rows apply
func syncLook() -> void:
	var car: String = G.settings.car
	UiKit.pill_text(credits, G.fmtCr(G.garage.credits))
	var val := {}
	for k in rows: val[k] = G.lookShown(car, k)
	var n: int = CarLook.extra("stripe", val.stripe).get("n", 0)
	var hasNum: bool = int(val.num) > 0
	var show := {"sc": n >= 1, "sc2": n >= 2, "numStyle": hasNum, "numFg": hasNum, "numFont": hasNum, "numPos": hasNum,
		"numBg": hasNum and val.numStyle != "plain", "banCol": val.ban != ""}
	# a row that no longer applies (a second colour of a one-colour design, the colours of no start number, ...) shows
	# nothing on the car: what hangs in the fitting room for it would be paid for without being seen
	if G.fit.car == car:
		for k in show:
			if not show[k] and G.fit.look.has(k):
				G.fit.look.erase(k)
				val[k] = G.lookShown(car, k)
	for k in rows:
		var r: Dictionary = rows[k]
		var it: Dictionary = r.item
		var v = val[k]
		r.root.visible = CarLook.fits(car, k) and show.get(k, true)
		var needs := G.lookNeeds(k, v)
		if r.info != null:
			var t := CarLook.nameOf(k, v) if it.type != "text" else ""
			var col := UiKit.SUB
			for nd in needs:
				col = UiKit.DETOUR
				t += (" · " if t != "" else "") + (G.fmtCr(nd[1]) if nd[3] == "" else "nog vrijspelen")
			# a set you do not have yet: what it costs, before you try it
			if needs.is_empty() and it.has("kit") and not G.lookHas(k): t += (" · " if t != "" else "") + "set " + G.fmtCr(it.kit)
			if needs.is_empty() and it.get("mix", false) and k == "paint" and not G.lookHas("mix"): t += " · eigen kleur " + G.fmtCr(CarLook.MIX_PRICE)
			r.info.text = t
			r.info.add_theme_color_override("font_color", col)
		match it.type:
			"choice":
				r.radio.sync(v)
				for b in r.radio.items:
					if not b.has_meta("tag"): continue
					var nd := G.lookNeeds(k, b.value)
					var tag: Label = b.get_meta("tag")
					var lock: Control = b.get_meta("lock")
					b.visible = CarLook.optFits(car, k, b.value)     # (a body-kit part that does not fit this model)
					var locked: bool = nd.any(func(q): return q[3] != "")
					var cost := 0
					for q in nd: cost += int(q[1])
					lock.visible = locked
					tag.visible = not locked and cost > 0
					tag.text = G.fmtCr(cost)
					b.tooltip_text = ("Vrijspelen: " + nd[0][3]) if locked else ""
			"color":
				var preset: bool = CarLook.option(k, v) != null
				r.radio.sync(v if preset or (v is String and v == "") else MIX)
				for b in r.radio.items:
					var sw: LookSwatch = b.get_meta("sw")
					if sw.kind == "mix":
						sw.col = Color(v) if CarLook.isHex(v) and not preset else Color(_mixColor(k))
						sw.coin = not G.lookHas("mix")
					elif sw.kind == "":
						var o = CarLook.option(k, b.value)
						sw.coin = o != null and int(o[2]) > 0 and not G.lookHas(k + ":" + str(b.value))
					sw.queue_redraw()
			"num":
				if not numIn.has_focus(): numIn.text = str(int(v)) if int(v) > 0 else ""
				UiKit.stepper_sync(r.stepper, int(v), 0, 99)
			"text":
				var e: LineEdit = texts[k]
				if not e.has_focus(): e.text = str(v)
	# the line under the last row of a card that shows is not drawn
	for g in groupBoxes:
		var last = null
		for it in CarLook.itemsOf(g):
			var r: Dictionary = rows[it.k]
			r.line.visible = true
			if r.root.visible: last = r
		if last != null: last.line.visible = false
	_syncFit()

# ------------------------------------------------------------------ the fitting room bar and the buttons under the panel
func _build_nav() -> void:
	var v := UiKit.vbox(10)
	# the fitting room: what is on the car but not paid for (one or two lines), its buttons beside Terug below
	fitBar = UiKit.panel(UiKit.flat(UiKit.WELL_HI, 14, Vector4(14, 8, 14, 8)))
	var top := UiKit.vbox(1)
	fitBar.add_child(top)
	top.add_child(UiKit.eyebrow("In de paskamer", UiKit.DETOUR))
	fitText = UiKit.lbl("", 700, 13, UiKit.SIGN_INK, true, 0, false, 1.3)
	fitText.max_lines_visible = 2
	fitText.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(fitText)
	fitNote = UiKit.lbl("", 600, 12, UiKit.SUB, true, 0, false, 1.3)
	top.add_child(fitNote)
	fitBar.visible = false
	v.add_child(fitBar)
	var n := HomeUI.back_nav()
	var h: HBoxContainer = n[0]
	back = n[1]
	h.add_child(UiKit.expander())
	var small := Vector4(16, 12, 16, 12)
	fitBtns = UiKit.hbox(8)
	fitBuy = UiKit.cta("Kopen", small, 14)
	fitBuy.dis_alpha = 0.5
	fitBuy.pressed.connect(func() -> void:
		if not G.fitBuy(): return
		Sfx.tone(880, 0.12, "triangle", 0.12); Sfx.tone(1320, 0.2, "triangle", 0.12, 0.1)
		Game.rebuildPlayerCar()
		syncLook()
		if not fitBar.visible: UiKit.focus(groupRadio.checked_item()))
	fitUndo = UiKit.ghost("Terugzetten", false, small, 14)
	fitUndo.tooltip_text = "Alles wat niet betaald is, gaat van de auto af"
	fitUndo.pressed.connect(func() -> void:
		if G.fitClear(): Game.rebuildPlayerCar()
		syncLook()
		UiKit.focus(groupRadio.checked_item()))
	fitBtns.add_child(fitUndo); fitBtns.add_child(fitBuy)
	fitBtns.visible = false
	h.add_child(fitBtns)
	lookTools = UiKit.hbox(8)
	var rnd := UiKit.ghost("Willekeurig", false, small, 14)
	rnd.tooltip_text = "Een willekeurig uiterlijk uit wat je hebt"
	rnd.pressed.connect(randomLook)
	var std := UiKit.ghost("Standaard", false, small, 14)
	std.tooltip_text = "Terug naar hoe de auto uit de fabriek kwam (de lakkleur blijft)"
	std.pressed.connect(resetLook)
	darkBtn = UiKit.ghost("Licht uit", false, small, 14)
	darkBtn.tooltip_text = "Bekijk lampen en neon in het donker"
	darkBtn.pressed.connect(func() -> void:
		GarageRoom.setDark(not GarageRoom.dark)
		UiKit.btn_text(darkBtn, "Licht aan" if GarageRoom.dark else "Licht uit"))
	lookTools.add_child(rnd); lookTools.add_child(std); lookTools.add_child(darkBtn)
	lookTools.visible = false
	h.add_child(lookTools)
	v.add_child(h)
	nav = v

func _syncFit() -> void:
	var c := G.fitCost()
	var on: bool = tab == "look" and not c.items.is_empty()
	fitBar.visible = on
	fitBtns.visible = on
	lookTools.visible = tab == "look" and not on
	if not on: return
	var parts := []
	var locked := []
	for n in c.items:
		if n[3] == "": parts.append("%s (%s)" % [n[2], G.fmtCr(n[1])])
		else: locked.append("%s: %s" % [n[2], n[3].to_lower()])
	fitText.text = ", ".join(parts) if not parts.is_empty() else "Alleen om te kijken"
	var short: int = c.total - int(G.garage.credits)
	var note := []
	if short > 0: note.append("Je komt %s tekort." % G.fmtCr(short))
	if not locked.is_empty(): note.append("Niet te koop, wel vrij te spelen: " + "; ".join(locked) + ".")
	fitNote.text = " ".join(note)
	fitNote.visible = not note.is_empty()
	UiKit.btn_text(fitBuy, "Kopen · " + G.fmtCr(c.total))
	fitBuy.visible = c.total > 0
	fitBuy.disabled = short > 0

## leaving the look tab or the garage: what is not paid for goes back
func leaveLook() -> void:
	closePicker()
	if G.fitClear() and Game.car != null: Game.rebuildPlayerCar()
	if GarageRoom.dark:
		GarageRoom.setDark(false)
		UiKit.btn_text(darkBtn, "Licht uit")
	if fitBar != null:
		fitBar.visible = false
		fitBtns.visible = false

## a random look out of what you own (and what is free), so nothing lands in the fitting room
func randomLook() -> void:
	var car: String = G.settings.car
	G.fitClear()
	for it in CarLook.ITEMS:
		var k: String = it.k
		if not CarLook.fits(car, k): continue
		match it.type:
			"choice", "color":
				var c: Array = it.opts.map(func(o): return o[0]).filter(func(v): return G.lookNeeds(k, v).is_empty() and CarLook.optFits(car, k, v))
				if it.type == "color" and it.has("none"): c.append("")
				if it.type == "color" and it.get("mix", false) and G.lookHas("mix") and randf() < 0.2:
					# an own colour, unless the item is a set you do not have (roof, neon: that would go to the fitting room)
					var hex := "#" + Color.from_hsv(randf(), 0.4 + randf() * 0.6, 0.35 + randf() * 0.65).to_html(false)
					if G.lookNeeds(k, hex).is_empty(): c = [hex]
				if not c.is_empty(): G.lookPick(car, k, c.pick_random())
			"num":
				G.lookPick(car, k, 0 if randf() < 0.25 else randi_range(1, 99))
	Sfx.tone(660, 0.08, "triangle", 0.1)
	Game.rebuildPlayerCar()
	syncLook()

## back to how the car left the factory; the paint colour stays
func resetLook() -> void:
	var car: String = G.settings.car
	G.fitClear()
	for it in CarLook.ITEMS:
		if it.k != "paint": G.lookPick(car, it.k, it.def)
	Game.rebuildPlayerCar()
	syncLook()

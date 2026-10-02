class_name HomeUI
extends RefCounted
## The home screen of the HTML game (JS #home): the big "Polderrace" with three tiles (play, garage, more), and the
## panels Spelen (play), Records and Prestaties (achievements). Built once; refresh*() fills in the current state.

var main: Control            ## #homeMain: hero, tagline, tiles, key tip
var hero: Label
var tagline: Label
var tiles: HFlowContainer
var tipRow: HBoxContainer
var topPad: Control
var tilesPad: Control
var tileList: Array = []
var playTitle: Label
var playSub: Label
var hResume: UiKit.Btn
var hPlay: UiKit.Btn
var garTitle: Label
var garSub: Label
var garBars: VBoxContainer
var hGarage: UiKit.Btn
var hAch: UiKit.Btn
var achHomeInfo: Label
var achBar: UiKit.Bar
var hRecords: UiKit.Btn
var hSettings: UiKit.Btn

var play := {}               ## {content, nav}
var hStart: UiKit.Btn
var hQuick: UiKit.Btn
var hCareer: UiKit.Btn
var hChamp: UiKit.Btn
var hNet: UiKit.Btn
var records := {}
var recList: VBoxContainer
var ach := {}
var achCount: PanelContainer
var achBar2: UiKit.Bar
var achList: UiKit.EqGrid

static func back_nav() -> Array:
	var nav := UiKit.hbox(8)
	var b := UiKit.ghost("Terug")
	b.set_meta("homeback", true)
	nav.add_child(b)
	return [nav, b]

func _init() -> void:
	_build_main()
	_build_play()
	_build_records()
	_build_ach()

# ------------------------------------------------------------------ the main screen
func _tile(w: float) -> Array:
	var t := PanelContainer.new()
	var st := UiKit.SignStyle.new(24, Vector4(26, 26, 26, 26))
	t.add_theme_stylebox_override("panel", st)
	t.custom_minimum_size = Vector2(w, 340)
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := UiKit.vbox(10)
	t.add_child(v)
	tileList.append(t)
	return [t, v]

func _tt(text: String) -> Label:
	return UiKit.lbl(text, 900, 32, UiKit.SIGN_INK, true, -1, false, 1.0)

func _ts(text: String) -> Label:
	return UiKit.lbl(text, 700, 14, UiKit.SUB, true, 0, false, 1.3)

func _tile_ghost(text: String) -> UiKit.Btn:
	var b := UiKit.ghost(text, true, Vector4(18, 13, 18, 13))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

func _build_main() -> void:
	main = UiKit.vbox(0)
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	topPad = UiKit.spacer(64)
	main.add_child(topPad)
	hero = UiKit.lbl("Polderrace", 900, 104, UiKit.SIGN_INK, false, -4, true, 0.9)
	hero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_theme_color_override("font_shadow_color", UiKit.SIGN)
	hero.add_theme_constant_override("shadow_offset_x", 0)
	hero.add_theme_constant_override("shadow_offset_y", 6)
	var heroWrap := Control.new()
	heroWrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# the soft shadow under the hero (CSS text-shadow 0 18px 36px rgba(10,20,40,.4))
	var soft := UiKit.lbl("Polderrace", 900, 104, Color(10 / 255.0, 20 / 255.0, 40 / 255.0, 0.0), false, -4, true, 0.9)
	soft.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soft.add_theme_color_override("font_shadow_color", Color(10 / 255.0, 20 / 255.0, 40 / 255.0, 0.16))
	soft.add_theme_constant_override("shadow_offset_y", 18)
	soft.add_theme_constant_override("shadow_outline_size", 22)
	main.add_child(heroWrap)
	heroWrap.add_child(soft)
	heroWrap.add_child(hero)
	for l in [soft, hero]: l.set_anchors_preset(Control.PRESET_FULL_RECT)
	heroWrap.set_meta("labels", [soft, hero])
	tagline = UiKit.lbl("Arcaderacen over dijk, door dorp en langs duin.", 700, 18, UiKit.SIGN_INK)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_color_override("font_shadow_color", Color(10 / 255.0, 20 / 255.0, 40 / 255.0, 0.22))
	tagline.add_theme_constant_override("shadow_offset_y", 2)
	tagline.add_theme_constant_override("shadow_outline_size", 3)
	main.add_child(UiKit.spacer(10))
	main.add_child(tagline)
	tilesPad = UiKit.spacer(47)
	main.add_child(tilesPad)
	tiles = HFlowContainer.new()
	tiles.alignment = FlowContainer.ALIGNMENT_CENTER
	tiles.add_theme_constant_override("h_separation", 20)
	tiles.add_theme_constant_override("v_separation", 20)
	tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.add_child(UiKit.margin(tiles, Vector4(20, 0, 20, 0)))
	# tile 1: play
	var a := _tile(320)
	a[1].add_child(UiKit.eyebrow("Spelen · verder waar je was"))
	playTitle = _tt("Polder"); a[1].add_child(playTitle)
	playSub = _ts(""); a[1].add_child(playSub)
	a[1].add_child(UiKit.expander())
	var foot := UiKit.vbox(14)
	hResume = _tile_ghost("Verder racen")
	hPlay = UiKit.cta("Start", Vector4(16, 16, 16, 16))
	foot.add_child(hResume); foot.add_child(hPlay)
	a[1].add_child(foot)
	tiles.add_child(a[0])
	# tile 2: garage
	var b := _tile(300)
	b[1].add_child(UiKit.eyebrow("Garage"))
	garTitle = _tt(""); b[1].add_child(garTitle)
	garSub = _ts(""); b[1].add_child(garSub)
	garBars = UiKit.vbox(7)
	b[1].add_child(UiKit.margin(garBars, Vector4(0, 6, 0, 0)))
	b[1].add_child(UiKit.expander())
	hGarage = _tile_ghost("Naar de garage")
	b[1].add_child(hGarage)
	tiles.add_child(b[0])
	# tile 3: more
	var c := _tile(300)
	c[1].add_child(UiKit.eyebrow("Meer"))
	hAch = UiKit.Btn.new(StyleBoxEmpty.new())
	hAch.radius = 12
	var av := UiKit.vbox(10)
	hAch.add_child(av)
	var att := _tt("Prestaties")
	av.add_child(att)
	hAch.watch(func(_c: bool, h: bool) -> void: att.add_theme_color_override("font_color", UiKit.DETOUR_HI if h else UiKit.SIGN_INK))
	achHomeInfo = _ts(""); av.add_child(achHomeInfo)
	achBar = UiKit.Bar.new(8)
	av.add_child(UiKit.margin(achBar, Vector4(0, 6, 0, 0)))
	c[1].add_child(hAch)
	c[1].add_child(UiKit.expander())
	var foot2 := UiKit.vbox(14)
	hRecords = _tile_ghost("Records"); hSettings = _tile_ghost("Instellingen")
	foot2.add_child(hRecords); foot2.add_child(hSettings)
	c[1].add_child(foot2)
	tiles.add_child(c[0])
	main.add_child(UiKit.expander())
	# key tip (kb-only)
	tipRow = UiKit.hbox(8)
	tipRow.alignment = BoxContainer.ALIGNMENT_CENTER
	var tip := func(k: String, t: String) -> void:
		tipRow.add_child(UiKit.kbd(k, true))
		var l := UiKit.lbl(t, 700, 13, UiKit.SIGN_INK)
		l.add_theme_color_override("font_shadow_color", Color(10 / 255.0, 20 / 255.0, 40 / 255.0, 0.35))
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.add_theme_constant_override("shadow_outline_size", 4)
		tipRow.add_child(l)
	tip.call("← →", "kies een knop"); tipRow.add_child(UiKit.spacer(0, 4))
	tip.call("Enter", "start"); tipRow.add_child(UiKit.spacer(0, 4))
	tip.call("Esc", "terug")
	main.add_child(UiKit.margin(tipRow, Vector4(20, 28, 20, 32)))

## responsive bits of #homeMain (CSS clamp() and the max-height:640px query)
func layout(vp: Vector2) -> void:
	var low := vp.y <= 640
	topPad.custom_minimum_size.y = 18.0 if low else clampf(vp.y * 0.09, 28, 88)
	tilesPad.custom_minimum_size.y = 16.0 if low else clampf(vp.y * 0.065, 24, 64)
	var hs := int(round(clampf(vp.x * 0.1, 3.4 * 16, 104)))
	var wrap: Control = hero.get_parent()
	for l in wrap.get_meta("labels"):
		l.add_theme_font_size_override("font_size", hs)
		l.add_theme_font_override("font", UiKit.font(900, true, -int(round(hs * 0.04)), hs, 0.9))
	wrap.custom_minimum_size.y = round(hs * 0.9)
	tagline.add_theme_font_size_override("font_size", int(round(clampf(vp.x * 0.02, 15, 18))))
	for t in tileList: t.custom_minimum_size.y = 0.0 if low else 340.0

func refreshMain(ri: Dictionary) -> void:
	playTitle.text = ri.title
	playSub.text = ri.sub
	UiKit.btn_text(hResume, ri.cta)
	hResume.visible = ri.get("resume", false)
	var id: String = G.settings.car
	garTitle.text = Cars.CARS[id].name
	garSub.text = "Klasse %s · %s · %s" % [Cars.CARS[id].cls, "getuned" if Menu.isTuned(id) else "af fabriek", G.fmtCr(G.garage.credits)]
	UiKit.clear(garBars)
	for r in Menu.carStats(id):
		garBars.add_child(r)
	var na := Ach.count()
	achHomeInfo.text = "%d van %d behaald" % [na, Ach.ACH.size()]
	achBar.v = na / float(Ach.ACH.size())
	achBar.queue_redraw()

# ------------------------------------------------------------------ Spelen
func _build_play() -> void:
	var v := UiKit.vbox(16)
	v.add_child(UiKit.h2("Spelen"))
	var cups := UiKit.vbox(10)
	hStart = UiKit.cupcard(UiKit.icon("flag"), "Race", "Kies zelf modus, auto en baan")
	hQuick = UiKit.cupcard(UiKit.icon("bolt"), "Snel racen", "")
	hCareer = UiKit.cupcard(UiKit.icon("road"), "Carrière", "")
	hChamp = UiKit.cupcard(UiKit.icon("cup"), "Kampioenschap", "")
	# (the HTML says "met een uitnodigingscode": the Godot version finds games on the network by itself, see NetUi)
	hNet = UiKit.cupcard(UiKit.icon("globe"), "Online", "Tot 8 spelers op hetzelfde netwerk of via IP")
	for b in [hStart, hQuick, hCareer, hChamp, hNet]: cups.add_child(b)
	v.add_child(cups)
	var n := back_nav()
	play = {"content": v, "nav": n[0], "back": n[1]}

func refreshPlay(quickInfo: String, careerInfo: String, champInfo: String) -> void:
	(hQuick.get_meta("sub") as Label).text = quickInfo
	(hCareer.get_meta("sub") as Label).text = careerInfo
	(hChamp.get_meta("sub") as Label).text = champInfo

# ------------------------------------------------------------------ Records
func _build_records() -> void:
	var v := UiKit.vbox(16)
	var head := UiKit.FlexRow.new(12, 12)
	head.grow_first = false
	head.add_child(UiKit.h2("Records"))
	var ns := UiKit.lbl("Snelste ronde per klasse", 600, 13, UiKit.SUB, false, 0, false, 1.55)
	head.add_child(ns)
	v.add_child(head)
	recList = UiKit.vbox(14)
	v.add_child(recList)
	var n := back_nav()
	records = {"content": v, "nav": n[0], "back": n[1]}

## a records table: header (title, B, A, S) and rows {name, sub, cells}
func _rectable(title: String, rows: Array) -> PanelContainer:
	var p := UiKit.panel(UiKit.flat(UiKit.CARD, 16))
	var v := UiKit.vbox(0)
	p.add_child(v)
	var mkrow := func(cells: Array, head: bool, last: bool) -> void:
		var r := UiKit.hbox(0)
		for k in cells.size():
			var c: Control = cells[k]
			if k == 0: c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			else: c.custom_minimum_size.x = 84
			r.add_child(c)
		v.add_child(UiKit.margin(r, Vector4(18, 11, 18, 11)))
		if not last: v.add_child(UiKit.hline(UiKit.LINE3 if head else UiKit.LINE4))
	var hcells: Array = [UiKit.eyebrow(title)]
	for c in ["B", "A", "S"]:
		var l := UiKit.eyebrow(c)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hcells.append(l)
	mkrow.call(hcells, true, rows.is_empty())
	for k in rows.size():
		var r: Dictionary = rows[k]
		var nv := UiKit.vbox(0)
		nv.add_child(UiKit.lbl(r.name, 800, 15, UiKit.SIGN_INK))
		if r.get("sub", "") != "":
			nv.add_child(UiKit.lbl(r.sub, 600, 11, UiKit.SUB))
		var cells: Array = [nv]
		for t in r.cells:
			var l := UiKit.lbl(t if t != "" else "–", 800 if t != "" else 700, 15, UiKit.SIGN_INK if t != "" else UiKit.SUB)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cells.append(l)
		mkrow.call(cells, false, k == rows.size() - 1)
	return p

func refreshRecords() -> void:
	UiKit.clear(recList)
	var CL := ["B", "A", "S"]
	var laps := []
	var tts := []
	for id in TrackDefs.TRACKS:
		for dr in ["fwd", "rev"]:
			var cells := []
			var cars := []
			var tt := []
			for c in CL:
				var lk: String = "polderrace3d-lap-" + Game.tv(id, dr) + "-" + c
				var bk: String = "polderrace3d-best-" + Game.tv(id, dr) + "-" + c
				var lp := float(G.store_get(lk, 0))
				var carId := str(G.store_get(lk + "-car", ""))
				var bt := float(G.store_get(bk, 0))
				cells.append(G.fmtLap(lp) if lp > 0 else "")
				if lp > 0 and Cars.CARS.has(carId): cars.append(c + ": " + Cars.CARS[carId].name)
				tt.append(G.fmtKm(bt) if bt > 0 else "")
			var name: String = TrackDefs.TRACKS[id].name + (" (omgekeerd)" if dr == "rev" else "")
			if dr == "fwd" or cells.any(func(x): return x != ""):
				laps.append({"name": name, "sub": " · ".join(cars), "cells": cells})
			if tt.any(func(x): return x != ""):
				tts.append({"name": name, "cells": tt})
	recList.add_child(_rectable("Baan · snelste ronde", laps))
	if not tts.is_empty(): recList.add_child(_rectable("Tijdrit · afstand", tts))

# ------------------------------------------------------------------ Prestaties
func _build_ach() -> void:
	var v := UiKit.vbox(16)
	var head := UiKit.FlexRow.new(12, 12)
	head.grow_first = false
	head.add_child(UiKit.h2("Prestaties"))
	achCount = UiKit.credits_pill()
	head.add_child(achCount)
	v.add_child(head)
	achBar2 = UiKit.Bar.new(8)
	v.add_child(achBar2)
	achList = UiKit.EqGrid.new(2, 8, 8)
	v.add_child(achList)
	var n := back_nav()
	ach = {"content": v, "nav": n[0], "back": n[1]}

func refreshAch() -> void:
	var n := Ach.count()
	UiKit.pill_text(achCount, "%d van %d" % [n, Ach.ACH.size()])
	achBar2.v = n / float(Ach.ACH.size())
	achBar2.queue_redraw()
	UiKit.clear(achList)
	for a in Ach.ACH:
		var got := Ach.got(a[0])
		var p := UiKit.panel(UiKit.flat(UiKit.DETOUR if got else UiKit.CARD, 16, Vector4(10, 10, 14, 10)))
		var r := UiKit.hbox(12)
		p.add_child(r)
		var ic := UiKit.panel(UiKit.flat(UiKit.INK if got else UiKit.WELL, 999))
		ic.custom_minimum_size = Vector2(32, 32)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if got:
			var ck := UiKit.icon("check", 14, 3, UiKit.DETOUR)
			ck.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			ck.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			ic.add_child(ck)
		r.add_child(ic)
		var tv := UiKit.vbox(1)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_child(UiKit.lbl(a[1], 900 if got else 800, 15, UiKit.INK if got else UiKit.SIGN_INK, true, 0, false, 1.2))
		tv.add_child(UiKit.lbl(a[2], 700 if got else 600, 12, UiKit.INK if got else UiKit.SUB, true, 0, false, 1.3))
		r.add_child(tv)
		var em := UiKit.lbl("+" + G.fmtCr(a[3]), 900 if got else 800, 13, UiKit.INK if got else UiKit.DETOUR)
		em.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(em)
		achList.add_child(p)

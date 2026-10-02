class_name SetupUI
extends RefCounted
## The race setup of the HTML game (JS #menu, buildMenuDom, refreshMenu, refreshChampPanel): the board with the steps
## Spelmodus (2), Kies je auto (0), Kies je baan (1) and Kampioenschap (3), the step pills, and Terug / Volgende.

var board: PanelContainer
var title: Label
var pills := {}               ## step -> StepPill
var pillRow: HBoxContainer
var stepBox := {}             ## step -> VBoxContainer
var scroll: ScrollContainer
var backBtn: UiKit.Btn
var nextBtn: UiKit.Btn
# step 0
var pTabs: HBoxContainer
var pTab1: UiKit.Btn
var pTab2: UiKit.Btn
var classRadio: UiKit.Radio
var carRadio: UiKit.Radio
var carCards := {}
var carsNote: Label
var colorRadio: UiKit.Radio
# step 1
var trackRadio: UiKit.Radio
var trackCards := {}
var tiName: Label
var tiText: Label
var timeRadio: UiKit.Radio
var weatherRadio: UiKit.Radio
var dirRadio: UiKit.Radio
# step 2
var modeRadio: UiKit.Radio
var diffRadio: UiKit.Radio
var gridRadio: UiKit.Radio
var botsSt: Dictionary
var lapsSt: Dictionary
var rows := {}
var optLines: VBoxContainer
var modeNote: Label
# step 3
var champInfo: Label
var rounds: VBoxContainer
var champDiffRow: Control
var champDiffRadio: UiKit.Radio
var champReset: UiKit.Btn

static var _outlines := {}

## the outline of a track for its thumbnail and its length (JS trackOutline: CatmullRom through the control points)
static func trackOutline(id: String) -> Dictionary:
	if _outlines.has(id): return _outlines[id]
	var pts := []
	for c in TrackDefs.TRACKS[id].ctrl:
		pts.append([float(c[0]), float(c[2]), float(c[1])])
	var cv := CRCurve.new(pts, true)
	var out := PackedVector2Array()
	for i in 161:
		var p := cv.get_point_at(i / 160.0)
		out.append(Vector2(p[0], p[2]))
	_outlines[id] = {"pts": out, "len": cv.get_length()}
	return _outlines[id]

static func km(id: String) -> String:
	return ("%.1f" % (trackOutline(id).len / 1000.0)).replace(".", ",")

func _init() -> void:
	board = UiKit.board()
	var v := UiKit.vbox(18)
	board.add_child(v)
	var head := UiKit.FlexRow.new(12, 12)
	head.grow_first = false
	title = UiKit.lbl("Spelmodus", 900, 36, UiKit.SIGN_INK, false, -1, false, 1.0)
	head.add_child(title)
	pillRow = UiKit.hbox(4)
	pillRow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for s in [[2, "Modus"], [0, "Auto"], [1, "Baan"], [3, "Kampioenschap"]]:
		var p := StepPill.new(s[1])
		pills[s[0]] = p
		pillRow.add_child(p)
	head.add_child(pillRow)
	v.add_child(head)
	var steps := UiKit.vbox(0)
	scroll = UiKit.scroller(steps)
	v.add_child(UiKit.outer(scroll))
	for k in [0, 1, 2, 3]:
		var sb := UiKit.vbox(12 if k == 1 else 18)
		stepBox[k] = sb
		steps.add_child(sb)
	_build0()
	_build1()
	_build2()
	_build3()
	var navv := UiKit.vbox(14)
	navv.add_child(UiKit.hline(UiKit.LINE3))
	var nav := UiKit.hbox(8)
	backBtn = UiKit.ghost("Terug")
	nextBtn = UiKit.cta("Volgende")
	backBtn.pressed.connect(func() -> void: Menu.menuBack())
	nextBtn.pressed.connect(func() -> void: Menu.menuNext())
	nav.add_child(backBtn)
	nav.add_child(UiKit.expander())
	nav.add_child(nextBtn)
	navv.add_child(nav)
	v.add_child(navv)

# ------------------------------------------------------------------ step 0: car
func _build0() -> void:
	var b: VBoxContainer = stepBox[0]
	pTabs = UiKit.hbox(6)
	pTab1 = UiKit.chip("Speler 1"); pTab2 = UiKit.chip("Speler 2")
	pTab1.pressed.connect(func() -> void: Menu.setEditP(1))
	pTab2.pressed.connect(func() -> void: Menu.setEditP(2))
	pTabs.add_child(pTab1); pTabs.add_child(pTab2)
	pTabs.visible = false
	b.add_child(pTabs)
	var cs := UiKit.seg([["B", "B · Compact"], ["A", "A · GT"], ["S", "S · Super"]], func(v) -> void:
		if Cars.CARS[Menu.edCar()].cls != v: Menu.pickClass(v), false, false, true)
	classRadio = cs[1]
	b.add_child(cs[0])
	var grid := UiKit.EqGrid.new(2, 10, 10)
	carRadio = UiKit.Radio.new(func(v) -> void: Menu.pickCar(v))
	for id in Cars.CARS:
		var pad := Vector4(16, 16, 16, 16)
		var c := UiKit.Btn.new(UiKit.flat(UiKit.CARD, 16, pad), UiKit.flat(UiKit.CARD_HI, 16, pad), UiKit.flat(UiKit.DETOUR, 16, pad))
		c.radius = 16
		c.add_child(UiKit.vbox(10))
		carCards[id] = c
		grid.add_child(c)
		carRadio.add(c, id)
	b.add_child(grid)
	carsNote = UiKit.note("Je kiest uit je eigen auto's. Meer auto's koop je in de garage.", true)
	b.add_child(carsNote)
	var well := UiKit.panel(UiKit.flat(UiKit.WELL, 23, Vector4(12, 8, 12, 8)))
	var row := UiKit.hbox(12)
	well.add_child(row)
	var lab := UiKit.lbl("KLEUR", 800, 11, UiKit.LAB, false, 1, false, 1.0)
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lab)
	row.add_child(UiKit.spacer(0, 0))
	colorRadio = UiKit.Radio.new(func(v) -> void:
		if Menu.editP == 2: G.settings.p2color = v
		else: G.settings.color = v
		G.saveSettings()
		Menu.previewEdit()
		refresh())
	for col in Cars.COLORS:
		var sw := UiKit.swatch(Color(col))
		row.add_child(sw)
		colorRadio.add(sw, col)
	b.add_child(well)

## JS carCardHtml: name with a "getuned" badge, and the Top / Acc. / Grip bars
func refreshCarCards() -> void:
	for id in carCards:
		var c: UiKit.Btn = carCards[id]
		var v: VBoxContainer = c.get_child(0)
		UiKit.clear(v)
		c.watchers.clear()
		var top := UiKit.hbox(8)
		var nm := UiKit.lbl(Cars.CARS[id].name, 800, 18, UiKit.SIGN_INK, true, 0, false, 1.1)
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(nm)
		c.tint(nm, UiKit.SIGN_INK, UiKit.INK, 800, 900)
		if Menu.isTuned(id):
			var bd := UiKit.badge("getuned")
			top.add_child(bd)
			c.watch(func(on: bool, _h: bool) -> void: UiKit.badge_on(bd, on))
		v.add_child(top)
		for r in Menu.carStats(id):
			v.add_child(r)
			c.watch(func(on: bool, _h: bool) -> void: UiKit.stat_on(r, on))

# ------------------------------------------------------------------ step 1: track
func _build1() -> void:
	var b: VBoxContainer = stepBox[1]
	var grid := UiKit.EqGrid.new(2, 8, 8)
	trackRadio = UiKit.Radio.new(func(v) -> void:
		if v != Trk.TRACK_ID:
			G.settings.track = v
			G.saveSettings()
			Menu.loadTrack(v)
			Menu.applyEnv(G.settings.time, G.settings.weather)
			Menu.menuScene()
		refresh())
	for id in TrackDefs.TRACKS:
		var pad := Vector4(7, 7, 12, 7)
		var c := UiKit.Btn.new(UiKit.flat(UiKit.CARD, 16, pad), UiKit.flat(UiKit.CARD_HI, 16, pad), UiKit.flat(UiKit.DETOUR, 16, pad))
		c.radius = 16
		var h := UiKit.hbox(12)
		c.add_child(h)
		var th := TrackThumb.new(id)
		h.add_child(th)
		var tn := UiKit.vbox(2)
		tn.alignment = BoxContainer.ALIGNMENT_CENTER
		var nm := UiKit.lbl(TrackDefs.TRACKS[id].name, 800, 16, UiKit.SIGN_INK, false, 0, false, 1.1)
		var em := UiKit.lbl("", 600, 12, UiKit.SUB)
		tn.add_child(nm); tn.add_child(em)
		h.add_child(tn)
		c.tint(nm, UiKit.SIGN_INK, UiKit.INK, 800, 900)
		c.tint(em, UiKit.SUB, UiKit.INK, 600, 700)
		c.watch(func(on: bool, _h: bool) -> void: th.on = on; th.queue_redraw())
		trackCards[id] = {"b": c, "em": em}
		grid.add_child(c)
		trackRadio.add(c, id)
	b.add_child(grid)
	var ti := UiKit.panel(UiKit.flat(Color(10 / 255.0, 20 / 255.0, 40 / 255.0, 0.22), 16, Vector4(16, 12, 16, 12)))
	var tv := UiKit.vbox(4)
	ti.add_child(tv)
	tiName = UiKit.lbl("", 900, 17, UiKit.SIGN_INK, true, 0, false, 1.2)
	tiText = UiKit.lbl("", 600, 14, UiKit.SUB, true, 0, false, 1.5)
	tv.add_child(tiName); tv.add_child(tiText)
	b.add_child(ti)
	var og := GridContainer.new()
	og.columns = 2
	og.add_theme_constant_override("h_separation", 16)
	og.add_theme_constant_override("v_separation", 10)
	og.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mk := func(label: String, items: Array, cb: Callable) -> UiKit.Radio:
		var l := UiKit.lbl(label, 800, 15, UiKit.SIGN_INK, false, 0, false, 1.2)
		og.add_child(l)
		var s := UiKit.seg(items, cb, true, false, false)
		og.add_child(s[0])
		return s[1]
	timeRadio = mk.call("Tijd", [["day", "Dag"], ["dusk", "Avond"], ["night", "Nacht"]], func(v) -> void:
		G.settings.time = v; G.saveSettings(); Menu.applyEnv(G.settings.time, G.settings.weather); refresh())
	weatherRadio = mk.call("Weer", [["dry", "Droog"], ["rain", "Regen"], ["fog", "Mist"]], func(v) -> void:
		G.settings.weather = v; G.saveSettings(); Menu.applyEnv(G.settings.time, G.settings.weather); refresh())
	dirRadio = mk.call("Richting", [["fwd", "Normaal"], ["rev", "Omgekeerd"]], func(v) -> void:
		if v != G.settings.dir:
			G.settings.dir = v; G.saveSettings(); Menu.loadTrack(Trk.TRACK_ID); Menu.applyEnv(G.settings.time, G.settings.weather); Menu.menuScene()
		refresh())
	for s in [timeRadio, weatherRadio, dirRadio]:
		for it in s.items: it.sb_normal = UiKit.pad_box(Vector4(0, 8, 0, 8)); it.sb_hover = it.sb_normal; it.sb_on = UiKit.flat(UiKit.DETOUR, 999, Vector4(0, 8, 0, 8)); it.sb_on_hover = it.sb_on; it.restyle()
	b.add_child(og)

# ------------------------------------------------------------------ step 2: mode
func _build2() -> void:
	var b: VBoxContainer = stepBox[2]
	var ms := UiKit.seg([["race", "Race"], ["elim", "Eliminatie"], ["time", "Tijdrit"], ["ghost", "Ghost"], ["split", "2 spelers"]], func(v) -> void:
		G.settings.mode = v
		if v == "elim": G.settings.bots = maxi(2, int(G.settings.bots))
		G.saveSettings()
		Menu.menuScene()
		refresh(), false, false, true)
	modeRadio = ms[1]
	b.add_child(ms[0])
	botsSt = UiKit.stepper(func(d: int) -> void: _step("bots", d))
	lapsSt = UiKit.stepper(func(d: int) -> void: _step("laps", d))
	var ds := UiKit.seg([["easy", "Makkelijk"], ["normal", "Normaal"], ["hard", "Moeilijk"], ["extreme", "Extreem"]], func(v) -> void:
		G.settings.diff = v; G.saveSettings(); Menu.menuScene(); refresh())
	diffRadio = ds[1]
	var gs := UiKit.seg([["back", "Achteraan"], ["mid", "Midden"], ["pole", "Pole"]], func(v) -> void:
		G.settings.grid = v; G.saveSettings(); Menu.menuScene(); refresh())
	gridRadio = gs[1]
	rows.bots = UiKit.opt(UiKit.optl("Bots"), botsSt.box)
	rows.diff = UiKit.opt(UiKit.optl("Niveau"), ds[0])
	rows.grid = UiKit.opt(UiKit.optl("Startplek"), gs[0])
	rows.laps = UiKit.opt(UiKit.optl("Ronden"), lapsSt.box)
	var card := UiKit.rows_card([rows.bots, rows.diff, rows.grid, rows.laps])
	optLines = card.get_child(0)
	b.add_child(card)
	modeNote = UiKit.note("")
	b.add_child(modeNote)
	var keys := HFlowContainer.new()
	keys.add_theme_constant_override("h_separation", 18)
	keys.add_theme_constant_override("v_separation", 8)
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in [[["W", "A", "S", "D"], "rijden"], [["Spatie"], "handrem"], [["R"], "terug op de baan"], [["V"], "camera"], [["Esc"], "pauze"]]:
		var g := UiKit.hbox(5)
		for c in k[0]: g.add_child(UiKit.kbd(c))
		var l := UiKit.lbl(k[1], 700, 14, UiKit.SUB)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		g.add_child(l)
		keys.add_child(g)
	b.add_child(keys)

## a hidden row takes its line along (CSS .opts>*+* border-top): a line shows above a visible row with a visible row before it
static func fix_lines(lines: VBoxContainer) -> void:
	var seen := false
	var sep: Control = null
	for c in lines.get_children():
		if c is ColorRect:
			sep = c
			continue
		if sep != null: sep.visible = c.visible and seen
		if c.visible: seen = true

func _step(f: String, d: int) -> void:
	var r := Menu.stepRange(f)
	G.settings[f] = clampi(int(G.settings[f]) + d, r[0], r[1])
	G.saveSettings()
	if f == "bots": Menu.menuScene()
	refresh()

# ------------------------------------------------------------------ step 3: championship
func _build3() -> void:
	var b: VBoxContainer = stepBox[3]
	champInfo = UiKit.note("")
	b.add_child(champInfo)
	var rc := UiKit.panel(UiKit.flat(UiKit.CARD, 16))
	rounds = UiKit.vbox(0)
	rc.add_child(rounds)
	b.add_child(rc)
	var og := HBoxContainer.new()
	og.add_theme_constant_override("separation", 16)
	og.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.lbl("Niveau", 800, 15, UiKit.SIGN_INK, false, 0, false, 1.2)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	og.add_child(l)
	var ds := UiKit.seg([["easy", "Makkelijk"], ["normal", "Normaal"], ["hard", "Moeilijk"], ["extreme", "Extreem"]], func(v) -> void:
		G.settings.diff = v; G.saveSettings(); refresh(), true)
	champDiffRadio = ds[1]
	for it in champDiffRadio.items: it.sb_normal = UiKit.pad_box(Vector4(0, 8, 0, 8)); it.sb_hover = it.sb_normal; it.sb_on = UiKit.flat(UiKit.DETOUR, 999, Vector4(0, 8, 0, 8)); it.sb_on_hover = it.sb_on; it.restyle()
	og.add_child(ds[0])
	champDiffRow = og
	b.add_child(og)
	champReset = UiKit.ghost("Opnieuw beginnen", true)
	champReset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	champReset.pressed.connect(func() -> void:
		Champ.champ = null
		G.store_set("polderrace3d-champ", "null")
		refresh())
	b.add_child(champReset)

func refreshChampPanel() -> void:
	var ip := Champ.champInProgress()
	var champ = Champ.champ
	UiKit.clear(rounds)
	var CR := Champ.CR()
	for k in CR.size():
		var r: Dictionary = CR[k]
		var cur := ip and k == int(champ.round)
		var done := ip and k < int(champ.round)
		if k > 0 and not cur and not (ip and k - 1 == int(champ.round)): rounds.add_child(UiKit.hline(UiKit.LINE))
		var h := UiKit.hbox(10)
		var a := UiKit.lbl("%d. %s" % [k + 1, TrackDefs.TRACKS[r.track].name], 800, 15, UiKit.INK if cur else UiKit.SIGN_INK)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var sm: String = Env.TIME_NAMES[r.time] + ", " + Env.WEATHER_NAMES[r.weather].to_lower() + (", omgekeerd" if r.get("dir") == "rev" else "") + ", %d ronden" % int(r.laps)
		if ip and k < champ.history.size(): sm += " · %de" % (champ.history[k].find("Jij") + 1)
		var s := UiKit.lbl(sm, 600, 12, UiKit.INK if cur else UiKit.SUB)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(a); h.add_child(s)
		var row := UiKit.panel(UiKit.flat(UiKit.DETOUR, 12, Vector4(18, 10, 18, 10)) if cur else UiKit.pad_box(Vector4(18, 10, 18, 10)))
		row.add_child(h)
		if done: row.modulate.a = 0.7
		rounds.add_child(row)
	if ip:
		var st := Champ.champStandings()
		var me := 0
		for k in st.size():
			if st[k].me: me = k + 1
		champInfo.text = "Bezig met %s (klasse %s) op %s. Je staat %de met %d punten." % [Cars.CARS[champ.car].name, champ.cls, G.DIFF[champ.diff].name.to_lower(), me, int(champ.pts.Jij)]
	else:
		champInfo.text = "%d races tegen 5 vaste tegenstanders in klasse %s. Punten per race: 10, 8, 6, 5, 4, 3." % [CR.size(), Cars.CARS[G.settings.car].cls]
	champDiffRow.visible = not ip
	champReset.visible = ip

# ------------------------------------------------------------------ refreshMenu
func refresh() -> void:
	var S := G.settings
	var step: int = Menu.menuStep
	var steps: Array = Menu.flowSteps()
	title.text = {0: "Kies je auto", 1: "Kies je baan", 3: "Kampioenschap"}.get(step, "Spelmodus")
	for k in stepBox: stepBox[k].visible = k == step
	var n := 0
	var cur := steps.find(step)
	for s in [2, 0, 1, 3]:
		var p: StepPill = pills[s]
		var idx := steps.find(s)
		p.visible = idx >= 0
		if idx >= 0:
			n += 1
			p.set_state(n, idx < cur, s == step)
	pTabs.visible = Menu.menuFlow == "quick" and S.mode == "split"
	if not pTabs.visible and Menu.editP == 2:
		Menu.editP = 1
		Game.rebuildPlayerCar()
	pTab1.checked = Menu.editP == 1
	pTab2.checked = Menu.editP == 2
	var cls: String = Cars.CARS[Menu.edCar()].cls
	for id in carCards:
		carCards[id].visible = Cars.CARS[id].cls == cls and Career.owns(id)
	classRadio.sync(cls)
	for b in classRadio.items:
		var any: bool = Cars.carsOf(b.value).any(func(id): return Career.owns(id))
		b.disabled = not any
		b.tooltip_text = "" if any else "Nog geen auto in bezit: koop er een in de garage"
	carsNote.visible = not Cars.CARS.keys().all(func(id): return Career.owns(id))
	carRadio.sync(Menu.edCar())
	colorRadio.sync(Menu.edCol())
	trackRadio.sync(Trk.TRACK_ID)
	dirRadio.sync(S.dir)
	diffRadio.sync(S.diff)
	champDiffRadio.sync(S.diff)
	gridRadio.sync(S.grid)
	modeRadio.sync(S.mode)
	timeRadio.sync(S.time)
	weatherRadio.sync(S.weather)
	for id in trackCards: trackCards[id].em.text = km(id) + " km"
	var tid: String = Trk.TRACK_ID if Trk.TRACK_ID != "" else S.track
	var lp := float(G.store_get(Game.lapKey(tid), 0))
	var rc := str(G.store_get(Game.lapKey(tid) + "-car", ""))
	tiName.text = TrackDefs.TRACKS[tid].name + (" · omgekeerd" if S.dir == "rev" else "")
	tiText.text = TrackDefs.TRACKS[tid].desc + ". " + km(tid) + " km · " + (("ronderecord klasse %s: %s%s" % [cls, G.fmtLap(lp), " (" + Cars.CARS[rc].name + ")" if Cars.CARS.has(rc) else ""]) if lp > 0 else "nog geen ronderecord in klasse " + cls) + "."
	var br := Menu.stepRange("bots")
	var lr := Menu.stepRange("laps")
	UiKit.stepper_sync(botsSt, int(S.bots), br[0], br[1])
	UiKit.stepper_sync(lapsSt, int(S.laps), lr[0], lr[1])
	var m: String = S.mode
	var withBots := m == "race" or m == "elim" or m == "split"
	rows.bots.visible = withBots
	rows.diff.visible = withBots
	rows.grid.visible = withBots
	rows.laps.visible = m == "race" or m == "ghost" or m == "split"
	fix_lines(optLines)
	var nb := int(S.bots)
	var L := int(S.laps)
	var rn := func(x: int) -> String: return "%d %s" % [x, "ronde" if x == 1 else "ronden"]
	if m == "race": modeNote.text = "Race van %s tegen %d %s. Er rijdt geen ander verkeer." % [rn.call(L), nb, "bot" if nb == 1 else "bots"]
	elif m == "elim": modeNote.text = "Na elke ronde valt de laatste auto af. Met %d bots duurt de race maximaal %s." % [nb, rn.call(nb)]
	elif m == "split": modeNote.text = "Twee spelers op één scherm%s, %s. Speler 1: W A S D en spatie. Speler 2: pijltjes en rechter Shift. Met één controller rijdt speler 2 op de controller; met twee controllers heeft elke speler er één." % [(" met %d %s" % [nb, "bot" if nb == 1 else "bots"]) if nb else "", rn.call(L)]
	elif m == "ghost": modeNote.text = "Rij %s alleen op de baan. Je snelste ronde wordt als doorzichtige ghost-auto opgeslagen om tegen te racen." % rn.call(L)
	else: modeNote.text = "Rij een tijdrit tussen het verkeer: haal elke checkpoint voordat je tijd op is."
	if step == 3: refreshChampPanel()
	var fs: Array = steps
	var nt := "Volgende"
	if Menu.menuFlow == "net": nt = "Klaar"
	elif step == fs[fs.size() - 1] and Menu.menuFlow != "champ": nt = "Start race"
	elif step == 3: nt = ("Ga verder: race %d" % (int(Champ.champ.round) + 1)) if Champ.champInProgress() else "Start kampioenschap"
	UiKit.btn_text(nextBtn, nt)

## the control to focus when a step opens: its chosen option, else Volgende
func first_focus() -> Control:
	var step: int = Menu.menuStep
	for rg in ({0: [carRadio, classRadio], 1: [trackRadio], 2: [modeRadio], 3: [champDiffRadio]}).get(step, []):
		var b = rg.checked_item()
		if b != null and b.is_visible_in_tree(): return b
	return nextBtn

# ------------------------------------------------------------------ widgets
## a step pill (ol.steps li): number in a circle (✓ when done), the name; the current one is white
class StepPill extends PanelContainer:
	var circle: Control
	var label: Label
	var num := 1
	var done := false
	var cur := false
	func _init(text: String) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(h)
		circle = Control.new()
		circle.custom_minimum_size = Vector2(20, 20)
		circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		circle.draw.connect(_draw_circle)
		h.add_child(circle)
		label = UiKit.lbl(text, 800, 13, UiKit.LAB, false, 0, false, 1.0)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(label)
	func set_state(n: int, d: bool, c: bool) -> void:
		num = n; done = d; cur = c
		add_theme_stylebox_override("panel", UiKit.flat(UiKit.SIGN_INK if c else Color(0, 0, 0, 0), 999, Vector4(6, 6, 12 if c else 10, 6)))
		label.add_theme_color_override("font_color", UiKit.SIGN if c else (UiKit.SIGN_INK if d else UiKit.LAB))
		circle.queue_redraw()
	func _draw_circle() -> void:
		var bg: Color = UiKit.SIGN if cur else (UiKit.DETOUR if done else UiKit.WELL)
		circle.draw_circle(Vector2(10, 10), 10, bg, true, -1, true)
		if done and not cur:
			var a := PackedVector2Array([Vector2(6, 10.4), Vector2(8.8, 13.2), Vector2(14, 7.4)])
			circle.draw_polyline(a, UiKit.INK, 1.8, true)
		else:
			var f := UiKit.font(800)
			var t := str(num)
			var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
			circle.draw_string(f, Vector2(10 - w.x / 2, 10 + (f.get_ascent(11) - f.get_descent(11)) / 2), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiKit.SIGN_INK)

## the track outline thumbnail (.tmap, JS drawTrackThumb): white line with a dark edge, yellow start dot
class TrackThumb extends Control:
	var id := ""
	var on := false
	func _init(tid: String) -> void:
		id = tid
		custom_minimum_size = Vector2(56, 40)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var s := StyleBoxFlat.new()
		s.bg_color = UiKit.SIGN if on else UiKit.WELL
		s.set_corner_radius_all(10); s.anti_aliasing = true; s.corner_detail = 8
		s.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		var pts: PackedVector2Array = SetupUI.trackOutline(id).pts
		# the canvas is 112 x 80 shown at 56 x 40: every size is half of the JS one
		var W := 112.0
		var H := 80.0
		var x0 := 1e9; var x1 := -1e9; var z0 := 1e9; var z1 := -1e9
		for p in pts:
			x0 = minf(x0, p.x); x1 = maxf(x1, p.x); z0 = minf(z0, p.y); z1 = maxf(z1, p.y)
		var pad := roundf(W * 0.1)
		var k0 := W / 168.0
		var sc := minf((W - 2 * pad) / maxf(1e-6, x1 - x0), (H - 2 * pad) / maxf(1e-6, z1 - z0))
		var ox := (W - (x1 - x0) * sc) / 2
		var oz := (H - (z1 - z0) * sc) / 2
		var q := PackedVector2Array()
		for p in pts: q.append(Vector2(ox + (p.x - x0) * sc, oz + (p.y - z0) * sc) * 0.5)
		q.append(q[0])
		draw_polyline(q, Color(0, 0, 0, 0.35), 7 * k0 * 0.5, true)
		draw_polyline(q, Color("#f7f7f2"), 4 * k0 * 0.5, true)
		draw_circle(q[0], 5 * k0 * 0.5, Color("#f2c200"), true, -1, true)
		draw_arc(q[0], 5 * k0 * 0.5, 0, TAU, 16, Color("#161a22"), 1.5 * k0 * 0.5, true)

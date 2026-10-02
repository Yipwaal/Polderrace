class_name CareerUI
extends RefCounted
## The career panel of the HTML game (JS #homeCareer, openCareer): chapter tabs, the chapter's title and story, its
## events (the chosen one unfolds with what is said about it and its goal), your car for the chapter, and Start.

var content: VBoxContainer
var nav: HBoxContainer
var back: UiKit.Btn
var careerNew: UiKit.Btn
var careerGo: UiKit.Btn
var credits: PanelContainer
var chRadio: UiKit.Radio
var chTitle: Label
var chSub: Label
var intro: PanelContainer
var list: VBoxContainer
var cars: UiKit.EqGrid
var carNote: Label
var _go := Callable()
var _new := Callable()

func _init() -> void:
	content = UiKit.vbox(16)
	var head := UiKit.FlexRow.new(12, 12)
	head.grow_first = false
	head.add_child(UiKit.h2("Carrière"))
	credits = UiKit.credits_pill()
	head.add_child(credits)
	content.add_child(head)
	var items := []
	for c in Career.CHAPTERS: items.append([c.id, ""])
	var s := UiKit.seg(items, func(v) -> void:
		var ch = null
		for c in Career.CHAPTERS:
			if c.id == v: ch = c
		if ch == null or not Career.chUnlocked(ch): return
		Menu.careerCh = v
		var sel = ch.events[0]
		for e in ch.events:
			if Career.evUnlocked(e) and not Career.evPassed(e): sel = e; break
		Menu.careerSel = sel.id
		openCareer(), true)
	chRadio = s[1]
	# chapter tabs: [lock] number name
	for b in chRadio.items:
		UiKit.clear(b)
		b.watchers.clear()
		var h := UiKit.hbox(5)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		b.add_child(h)
		b.dis_alpha = 0.4
	content.add_child(s[0])
	var chv := UiKit.vbox(6)
	chTitle = UiKit.lbl("", 900, 20, UiKit.SIGN_INK, true, 0, false, 1.15)
	chSub = UiKit.lbl("", 700, 13, UiKit.SUB, true, 0, false, 1.3)
	intro = UiKit.story_box()
	chv.add_child(chTitle); chv.add_child(chSub); chv.add_child(intro)
	content.add_child(chv)
	list = UiKit.vbox(10)
	content.add_child(list)
	var cp := UiKit.vbox(10)
	cp.add_child(UiKit.eyebrow("Jouw auto"))
	cars = UiKit.EqGrid.new(2, 8, 8)
	cp.add_child(cars)
	carNote = UiKit.note("", true)
	cp.add_child(carNote)
	content.add_child(cp)
	nav = UiKit.hbox(8)
	back = UiKit.ghost("Terug")
	back.set_meta("homeback", true)
	nav.add_child(back)
	nav.add_child(UiKit.expander())
	careerNew = UiKit.ghost("Opnieuw beginnen", true)
	careerGo = UiKit.cta("Start")
	careerNew.pressed.connect(func() -> void:
		if _new.is_valid(): _new.call())
	careerGo.pressed.connect(func() -> void:
		if _go.is_valid(): _go.call())
	nav.add_child(careerNew); nav.add_child(careerGo)

static func storyLine(line: Array) -> HBoxContainer:
	var P: Dictionary = Career.PEOPLE[line[0]]
	return UiKit.story_line(P.name, P.col, P.get("ink", ""), line[1])

func openCareer() -> void:
	var run = Career.careerRun()
	var nx = Career.careerNext()
	UiKit.pill_text(credits, G.fmtCr(G.garage.credits))
	if Menu.careerSel == null or Career.evById(Menu.careerSel) == null:
		var e = Career.cupById(run.career) if run != null else (nx if nx != null else Career.CAREER_EVS[Career.CAREER_EVS.size() - 1])
		Menu.careerSel = e.id
		Menu.careerCh = Career.chapterOf(e).id
	var ch: Dictionary = Career.CHAPTERS[0]
	for c in Career.CHAPTERS:
		if c.id == Menu.careerCh: ch = c
	# chapter tabs
	for i in Career.CHAPTERS.size():
		var c: Dictionary = Career.CHAPTERS[i]
		var b: UiKit.Btn = chRadio.items[i]
		var ok := Career.chUnlocked(c)
		b.disabled = not ok
		var h: HBoxContainer = b.get_child(0)
		UiKit.clear(h)
		var on: bool = c.id == ch.id
		var col := UiKit.INK if on else UiKit.SIGN_INK
		if not ok:
			var ic := UiKit.icon("lock", 13, 2.4, col)
			ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(ic)
		h.add_child(UiKit.lbl(str(i + 1), 900, 14, col, false, 0, false, 1.0))
		h.add_child(UiKit.lbl(c.tab, 900 if on else 800, 14, col, false, 0, false, 1.0))
		b.tooltip_text = "Hoofdstuk %d: %s%s" % [i + 1, c.name, "" if ok else ", vergrendeld: haal eerst de " + Career.CHAPTERS[i - 1].events[-1].name]
	chRadio.sync(ch.id)
	var done: int = ch.events.filter(func(e): return Career.evPassed(e)).size()
	var R: Dictionary = Career.RIVALS[ch.rival[0]]
	chTitle.text = "Hoofdstuk %d · %s" % [Career.CHAPTERS.find(ch) + 1, ch.name]
	chSub.text = "Klasse %s · rivaal: %s (%s) · %d van %d gehaald" % [ch.cls, R.full, Cars.CARS[ch.rival[1]].name, done, ch.events.size()]
	var iv := UiKit.story_clear(intro)
	if Career.evPassed(ch.events[-1]): iv.add_child(storyLine(ch.outro))
	elif not ch.events.any(func(e): return Career.evRes(e) != null): iv.add_child(storyLine(ch.intro))
	intro.visible = iv.get_child_count() > 0
	# the events of this chapter
	UiKit.clear(list)
	var selBtn: UiKit.Btn = null
	var info: Control = null
	for k in ch.events.size():
		var e: Dictionary = ch.events[k]
		var ok := Career.evUnlocked(e)
		var st = Career.evRes(e)
		var passed := Career.evPassed(e)
		var letter: Control
		if passed: letter = UiKit.icon("check", 14, 3)
		else: letter = UiKit.lbl(str(k + 1), 900, 18, UiKit.SIGN_INK)
		var sub: String = Career.evSub(e) if ok else "Vergrendeld: haal eerst %s (%s)" % [ch.events[k - 1].name, Career.goalText(ch.events[k - 1].goal)]
		var b := UiKit.cupcard(letter, e.name, sub)
		b.disabled = not ok
		b.mouse_default_cursor_shape = Control.CURSOR_ARROW if not ok else Control.CURSOR_POINTING_HAND
		b.checked = Menu.careerSel == e.id
		var status := ""
		var ic := ""
		if not ok: ic = "lock"
		elif run != null and run.get("career") == e.id: status = "bezig · %d van %d" % [int(run.round) + 1, e.rounds.size()]
		elif st != null and int(st.get("best", 99)) < 99:
			status = "🏆 gewonnen" if st.get("won", false) else ("✓ %de" % int(st.best) if passed else "beste: %de" % int(st.best))
		else: status = G.fmtCr(e.prize[0])
		UiKit.cup_status(b, status, ic)
		var eid: String = e.id
		b.pressed.connect(func() -> void:
			Menu.careerSel = eid
			openCareer())
		list.add_child(b)
		if Menu.careerSel == e.id and ok:
			selBtn = b
			var d := UiKit.panel(UiKit.flat(Color(1, 1, 1, 0.07), 16, Vector4(16, 14, 16, 14)))
			var dv := UiKit.vbox(12)
			d.add_child(dv)
			dv.add_child(storyLine(e.pre))
			var goal := "Doel: %s · prijzengeld %s" % [Career.goalText(e.goal), " / ".join(e.prize.map(func(p): return G.fmtCr(p)))]
			if k == ch.events.size() - 1 and ch.bonus and not G.garage.career.bonus.get(ch.id, false):
				goal += " · bonus %s als je hem haalt" % G.fmtCr(ch.bonus)
			dv.add_child(UiKit.lbl(goal, 800, 13, UiKit.SUB, true, 0, false, 1.35))
			info = UiKit.margin(d, Vector4(0, -4, 0, 4))
			list.add_child(info)
	var ev: Dictionary = ch.events[0]
	for e in ch.events:
		if e.id == Menu.careerSel: ev = e
	# your car: one of your own cars of the chapter's class
	var cls: String = ch.cls
	var all: Array = Cars.carsOf(cls)
	var own: Array = all.filter(func(id): return Career.owns(id))
	UiKit.clear(cars)
	var pick: String = G.settings.car if own.has(G.settings.car) else (own[0] if not own.is_empty() else "")
	for id in all:
		var b := UiKit.ccard()
		var v: VBoxContainer = b.get_child(0)
		var mine := Career.owns(id)
		b.checked = id == pick
		var top := UiKit.hbox(6)
		top.custom_minimum_size.y = 21
		var nm := UiKit.lbl(Cars.CARS[id].name, 800, 16, UiKit.SIGN_INK, true, 0, false, 1.1)
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(nm)
		b.tint(nm, UiKit.SIGN_INK, UiKit.INK, 800, 900)
		if mine:
			var bd := UiKit.badge("in bezit")
			top.add_child(bd)
			b.watch(func(c: bool, _h: bool) -> void: UiKit.badge_on(bd, c))
		v.add_child(top)
		var line := UiKit.hbox(6)
		line.custom_minimum_size.y = 18
		if mine:
			var l := UiKit.lbl("Klasse %s · %d km/u" % [cls, int(round(G.effStats(id).vmax))], 700, 12, UiKit.SUB, false, 0, false, 1.3)
			b.tint(l, UiKit.SUB, UiKit.INK)
			line.add_child(l)
		else:
			var lc := UiKit.INK if b.checked else UiKit.DETOUR
			var ic := UiKit.icon("lock", 13, 2.4, lc)
			ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(ic)
			line.add_child(UiKit.lbl(G.fmtCr(Career.CAR_PRICE.get(id, 0)), 800, 13, lc))
		v.add_child(line)
		var cid: String = id
		b.pressed.connect(func() -> void:
			if mine:
				G.settings.car = cid
				Game.rebuildPlayerCar()
				openCareer()
			else:
				Menu.pickCar(cid)
				Menu.garageUI.garTab("perf")
				Menu.homePanel("garage")
				Menu.garageFrom = "career"
				UiKit.focus(Menu.garageUI.first_buy()))
		cars.add_child(b)
	carNote.visible = own.is_empty()
	carNote.text = "Je hebt nog geen klasse %s-auto. Koop er een in de garage (tik hierboven op een auto)." % cls
	var inRun: bool = run != null and run.get("career") == ev.id
	careerGo.disabled = not Career.evUnlocked(ev) or (own.is_empty() and not inRun)
	UiKit.btn_text(careerGo, "Ga verder: race %d" % (int(run.round) + 1) if inRun else "Start")
	careerNew.visible = inRun
	var carFor: String = run.car if inRun else pick
	_go = func() -> void: Career.startCareerEvent(ev, carFor)
	_new = func() -> void:
		if pick != "": Career.startCup(ev, pick, true)
	# the chosen event (and what is said about it) in view
	if selBtn != null:
		_reveal.call_deferred(selBtn, info)

func _reveal(b: Control, info: Control) -> void:
	# after the new list has its layout (JS scrollIntoView({block:'nearest'}))
	for _i in 2: await Menu.get_tree().process_frame
	if not is_instance_valid(b): return
	var sc := _scroller(b)
	if sc == null: return
	if is_instance_valid(b): sc.ensure_control_visible(b)
	if info != null and is_instance_valid(info): sc.ensure_control_visible(info)

static func _scroller(c: Node) -> ScrollContainer:
	var p := c.get_parent() if c != null and is_instance_valid(c) else null
	while p != null:
		if p is ScrollContainer: return p
		p = p.get_parent()
	return null

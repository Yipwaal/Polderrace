class_name OverUI
extends RefCounted
## The results screen (JS #over: buildResults, raceStatTiles, showStandings, setEarned, careerStory, endTimeTrial's
## tiles) and the pause screen (JS #pause) of the HTML game. Menu fills them; this builds and holds the controls.

var board: PanelContainer
var overSub: Label
var overTitle: Label
var recordTag: PanelContainer
var earnTag: PanelContainer
var storyBox: PanelContainer
var stats: UiKit.EqGrid
var oDist: Label
var oCp: Label
var oLap: Label
var oBest: Label
var rstats: UiKit.EqGrid
var rTot: Label
var rLap: Label
var rTop: Label
var results: VBoxContainer
var menuBtn: UiKit.Btn
var replayBtn: UiKit.Btn
var againBtn: UiKit.Btn

var pauseBoard: PanelContainer
var pauseMain: VBoxContainer
var pauseSub: Label
var resumeBtn: UiKit.Btn
var restartBtn: UiKit.Btn
var pSettings: UiKit.Btn
var quitBtn: UiKit.Btn

func _init() -> void:
	board = UiKit.board(Vector4(32, 30, 32, 30), false)
	var v := UiKit.vbox(20)
	board.add_child(v)
	var head := UiKit.FlexRow.new(16, 16)
	head.grow_first = false
	head.align_center = false
	var hv := UiKit.vbox(6)
	overSub = UiKit.eyebrow("")
	overTitle = UiKit.lbl("Tijd is op", 900, 48, UiKit.SIGN_INK, true, -1, true, 1.0)
	hv.add_child(overSub); hv.add_child(overTitle)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	var tags := UiKit.hbox(6)
	recordTag = UiKit.tag("Nieuw record")
	earnTag = UiKit.tag("", true)
	tags.add_child(recordTag); tags.add_child(earnTag)
	head.add_child(tags)
	v.add_child(head)
	storyBox = UiKit.story_box()
	storyBox.visible = false
	v.add_child(storyBox)
	stats = _tiles()
	oDist = _tile(stats, "Afstand")
	oCp = _tile(stats, "Checkpoints")
	oLap = _tile(stats, "Snelste ronde")
	oBest = _tile(stats, "Record")
	v.add_child(stats)
	rstats = _tiles()
	rTot = _tile(rstats, "Totaal")
	rLap = _tile(rstats, "Snelste ronde")
	rTop = _tile(rstats, "Topsnelheid", " km/u")
	rstats.visible = false
	v.add_child(rstats)
	results = UiKit.vbox(2)
	results.visible = false
	v.add_child(results)
	var btns := UiKit.FlexRow.new(8, 8)
	btns.grow_first = false
	var grp := UiKit.hbox(6)
	menuBtn = UiKit.ghost("Hoofdmenu", false, Vector4(20, 14, 20, 14), 15)
	replayBtn = UiKit.ghost("Bekijk replay", true, Vector4(20, 14, 20, 14), 15)
	grp.add_child(menuBtn); grp.add_child(replayBtn)
	btns.add_child(grp)
	againBtn = UiKit.cta("Opnieuw racen")
	btns.add_child(againBtn)
	v.add_child(btns)
	_build_pause()

func _tiles() -> UiKit.EqGrid:
	var g := UiKit.EqGrid.new(4, 8, 8)
	g.min_col = 130
	return g

## a stats tile (.stats dt/dd): label in small capitals, value big; unit = small text after the value
func _tile(g: Control, label: String, unit := "") -> Label:
	var p := UiKit.panel(UiKit.flat(UiKit.CARD, 16, Vector4(16, 14, 16, 14)))
	var v := UiKit.vbox(4)
	p.add_child(v)
	var dt := UiKit.lbl(label.to_upper(), 800, 11, UiKit.LAB, true, 1, false, 1.2)
	v.add_child(dt)
	var row := UiKit.hbox(0)
	var dd := UiKit.lbl("–", 900, 24, UiKit.SIGN_INK, false, 0, false, 1.1)
	row.add_child(dd)
	if unit != "":
		var u := UiKit.lbl(unit, 800, 14, UiKit.SUB)
		u.size_flags_vertical = Control.SIZE_SHRINK_END
		u.custom_minimum_size.y = 0
		row.add_child(UiKit.margin(u, Vector4(0, 0, 0, 3)))
	v.add_child(row)
	g.add_child(p)
	return dd

func _build_pause() -> void:
	pauseBoard = UiKit.board(Vector4(32, 30, 32, 30), false)
	pauseMain = UiKit.vbox(18)
	pauseBoard.add_child(pauseMain)
	var hv := UiKit.vbox(6)
	hv.add_child(UiKit.h2("Pauze"))
	pauseSub = UiKit.lbl("", 700, 14, UiKit.SUB, true)
	hv.add_child(pauseSub)
	pauseMain.add_child(hv)
	var col := UiKit.vbox(6)
	resumeBtn = UiKit.cta("Verder racen", Vector4(16, 16, 16, 16))
	col.add_child(UiKit.margin(resumeBtn, Vector4(0, 0, 0, 6)))
	var lite := Color(1, 1, 1, 0.1)
	var mk := func(t: String, bg: Color) -> UiKit.Btn:
		var b := UiKit.ghost(t, false, Vector4(14, 14, 14, 14))
		b.sb_normal = UiKit.flat(bg, 999, Vector4(14, 14, 14, 14))
		b.sb_hover = b.sb_normal
		b.restyle()
		col.add_child(b)
		return b
	restartBtn = mk.call("Herstart", lite)
	pSettings = mk.call("Instellingen", lite)
	quitBtn = mk.call("Naar menu", UiKit.WELL)
	pauseMain.add_child(col)
	var tip := UiKit.hbox(8)
	tip.alignment = BoxContainer.ALIGNMENT_CENTER
	tip.add_child(UiKit.kbd("Esc", true))
	var tl := UiKit.lbl("verder racen", 700, 13, UiKit.SUB)
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tip.add_child(tl)
	pauseMain.add_child(tip)

## one row of the results list (JS li3): position, name with the car in small, time or gap, [points]
func row(me: bool, p: String, name: String, sub: String, tm: String, pt = null) -> PanelContainer:
	var pc := UiKit.panel(UiKit.flat(UiKit.DETOUR if me else Color(0, 0, 0, 0), 999, Vector4(16, 9, 16, 9)))
	var h := UiKit.hbox(10)
	pc.add_child(h)
	var a := UiKit.lbl(p, 900, 15, UiKit.INK if me else UiKit.SIGN_INK)
	a.custom_minimum_size.x = 36
	h.add_child(a)
	var nh := UiKit.hbox(6)
	nh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nh.add_child(UiKit.lbl(name, 800 if me else 700, 15, UiKit.INK if me else UiKit.SIGN_INK))
	if sub != "":
		var s := UiKit.lbl(sub, 600, 12, UiKit.INK if me else UiKit.SUB)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nh.add_child(s)
	h.add_child(nh)
	var t := UiKit.lbl(tm, 800 if me else 700, 15, UiKit.INK if me else UiKit.SUB)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(t)
	if pt != null:
		var q := UiKit.lbl(str(pt), 900, 15, UiKit.INK if me else UiKit.SIGN_INK)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		q.custom_minimum_size.x = 45
		h.add_child(q)
	return pc

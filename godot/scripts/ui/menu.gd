extends CanvasLayer
## Autoload "Menu": the menus of the HTML game (JS sections "menu", "key binding UI" and the screen side of "game flow"):
## the home screen and its panels (HomeUI, GarageUI, CareerUI, SettingsUI), the race setup (SetupUI), the results and
## pause screens (OverUI), the achievement popup, keyboard and gamepad navigation (padFocus, menuNext, menuBack,
## menuCycle, classCycle), and the menu camera (fly-over, orbit round the car, garage room, podium).
## Same names as the JS. Game (game.gd) calls in through the functions marked "from game.gd".

const MODE_NAMES := {"split": "2 spelers", "race": "Race", "elim": "Eliminatie", "time": "Tijdrit", "ghost": "Ghost-tijdrit", "champ": "Kampioenschap"}
## panels opened from "Spelen" go back there; the rest back to the home screen
const HOME_PARENT := {"career": "play", "net": "play"}

# ------------------------------------------------------------------ state (JS menu section)
var menuStep := -1
var menuFlow := "quick"
var homeView := "main"
var editP := 1
## the career screen can open the garage to buy a car: Terug returns there
var garageFrom = null
## the car you entered the garage with
var garageCar = null
var careerCh = null
var careerSel = null
## while set, the next key press goes to the key binding UI
var bindCapture := Callable()
## orbit round the car in the garage and the car step: drag to turn it, it turns slowly by itself when left alone
var orb := {"a": 0.5, "h": 1.9, "vel": 0.0, "idle": 99.0, "drag": null}
var _viewOff := 0.0
var _resumeGo := Callable()
var _overMenu := false

# ------------------------------------------------------------------ screens
var root: Control
var home: Control
var homeBackdrop: UiKit.Backdrop
var homeHolder: UiKit.Holder
var homeBoard: PanelContainer
var homeScroll: ScrollContainer
var homeContent: VBoxContainer
var homeNav: MarginContainer
var panels := {}
var menuOv: Control
var overOv: Control
var overBack: UiKit.Backdrop
var overHolder: UiKit.Holder
var pauseOv: Control
var pauseHolder: UiKit.Holder
var popLayer: CanvasLayer
var achPop: PanelContainer
var achPopTitle: Label
var achPopSub: Label

var homeUI: HomeUI
var garageUI: GarageUI
var careerUI: CareerUI
var settingsUI: SettingsUI
var setupUI: SetupUI
var overUI: OverUI

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	homeUI = HomeUI.new()
	garageUI = GarageUI.new()
	careerUI = CareerUI.new()
	settingsUI = SettingsUI.new()
	setupUI = SetupUI.new()
	overUI = OverUI.new()
	_build_home()
	_build_menu()
	_build_over()
	_build_pause()
	_build_pop()
	_wire()
	Sfx.mute_changed.connect(func(_m) -> void: settingsUI.syncToggles())
	for o in [home, menuOv, overOv, pauseOv]: o.visible = false
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()

func _overlay(back: UiKit.Backdrop) -> Control:
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	o.add_child(back)
	root.add_child(o)
	return o

func _build_home() -> void:
	homeBackdrop = UiKit.Backdrop.new("main")
	home = _overlay(homeBackdrop)
	home.gui_input.connect(_orbit_input)
	home.add_child(homeUI.main)
	homeBoard = UiKit.board()
	var v := UiKit.vbox(0)
	homeBoard.add_child(v)
	homeContent = UiKit.vbox(0)
	homeScroll = UiKit.scroller(homeContent)
	v.add_child(UiKit.outer(homeScroll))
	var navs := UiKit.vbox(0)
	homeNav = UiKit.margin(navs, Vector4(0, 12, 0, 0))
	v.add_child(homeNav)
	homeHolder = UiKit.Holder.new(homeBoard)
	homeHolder.full = true
	homeHolder.set_anchors_preset(Control.PRESET_FULL_RECT)
	home.add_child(homeHolder)
	registerPanel("play", homeUI.play.content, homeUI.play.nav)
	registerPanel("records", homeUI.records.content, homeUI.records.nav)
	registerPanel("ach", homeUI.ach.content, homeUI.ach.nav)
	registerPanel("garage", garageUI.content, garageUI.nav)
	registerPanel("career", careerUI.content, careerUI.nav)
	registerPanel("settings", settingsUI.content, settingsUI.nav)

## a panel of the home board (the online port registers "net" here): content scrolls, nav stays at the bottom
func registerPanel(v: String, content: Control, nav: Control) -> void:
	panels[v] = {"content": content, "nav": nav}
	content.visible = false
	nav.visible = false
	homeContent.add_child(content)
	homeNav.get_child(0).add_child(nav)
	for b in _buttons(nav):
		if b.has_meta("homeback"):
			b.pressed.connect(func() -> void:
				if pauseSettingsOpen(): closePauseSettings()
				else: homeBack())

func _build_menu() -> void:
	menuOv = _overlay(UiKit.Backdrop.new("menu"))
	menuOv.gui_input.connect(_orbit_input)
	var h := UiKit.Holder.new(setupUI.board)
	h.full = true
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	menuOv.add_child(h)

func _scroll_overlay(o: Control, holder: UiKit.Holder) -> void:
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	sc.add_child(holder)
	o.add_child(sc)

func _build_over() -> void:
	overBack = UiKit.Backdrop.new("blur")
	overOv = _overlay(overBack)
	overHolder = UiKit.Holder.new(overUI.board)
	overHolder.left = false
	overHolder.max_w = 640
	_scroll_overlay(overOv, overHolder)

func _build_pause() -> void:
	pauseOv = _overlay(UiKit.Backdrop.new("blur"))
	pauseHolder = UiKit.Holder.new(overUI.pauseBoard)
	pauseHolder.left = false
	pauseHolder.max_w = 400
	_scroll_overlay(pauseOv, pauseHolder)

func _build_pop() -> void:
	popLayer = CanvasLayer.new()
	popLayer.layer = 30
	add_child(popLayer)
	achPop = PanelContainer.new()
	var s := UiKit.flat(UiKit.DETOUR, 20, Vector4(22, 12, 22, 12))
	s.shadow_color = Color(0, 0, 0, 0.3); s.shadow_size = 14; s.shadow_offset = Vector2(0, 10)
	achPop.add_theme_stylebox_override("panel", s)
	achPop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UiKit.vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	achPop.add_child(v)
	var top := UiKit.lbl("PRESTATIE BEHAALD", 800, 11, UiKit.INK, false, 1)
	achPopTitle = UiKit.lbl("", 900, 20, UiKit.INK)
	achPopSub = UiKit.lbl("", 700, 13, UiKit.INK)
	for l in [top, achPopTitle, achPopSub]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	achPop.visible = false
	popLayer.add_child(achPop)

## the achievement popup (JS #achPop), shown by Ach one at a time
func achPopup(title: String, sub: String, show: bool) -> void:
	achPopTitle.text = title
	achPopSub.text = sub
	achPop.visible = show
	achPop.reset_size()
	_place_pop.call_deferred()

func _place_pop() -> void:
	var vp := get_viewport().get_visible_rect().size
	achPop.reset_size()
	achPop.position = Vector2((vp.x - achPop.size.x) / 2.0, 84)

func _on_resize() -> void:
	var vp := get_viewport().get_visible_rect().size
	homeUI.layout(vp)
	_place_pop()
	homeBackdrop.queue_redraw()

func _wire() -> void:
	var H := homeUI
	H.hPlay.pressed.connect(func() -> void: homePanel("play"))
	H.hResume.pressed.connect(func() -> void:
		if _resumeGo.is_valid(): _resumeGo.call())
	H.hRecords.pressed.connect(func() -> void: homePanel("records"))
	H.hSettings.pressed.connect(func() -> void: homePanel("settings"))
	H.hAch.pressed.connect(func() -> void: homePanel("ach"))
	H.hGarage.pressed.connect(func() -> void:
		garageFrom = null
		homePanel("garage")
		var f = garageUI.carRadio.checked_item()
		if f != null: UiKit.focus(f))
	H.hStart.pressed.connect(func() -> void:
		menuFlow = "quick"
		Champ.leaveChampMode()
		showMenu(2))
	H.hQuick.pressed.connect(func() -> void:
		menuFlow = "quick"
		Champ.leaveChampMode()
		Game.startRace())
	H.hCareer.pressed.connect(func() -> void: homePanel("career"))
	H.hChamp.pressed.connect(func() -> void:
		Champ.champ = Champ.loadQuickChamp()
		menuFlow = "champ"
		showMenu(3 if Champ.champInProgress() else 0))
	H.hNet.pressed.connect(netOpen)
	var O := overUI
	O.againBtn.pressed.connect(func() -> void: Game.onAgain())
	O.menuBtn.pressed.connect(func() -> void: Game.toCareerOr(-1))
	O.replayBtn.pressed.connect(func() -> void: Rep.replayOpen())
	O.resumeBtn.pressed.connect(func() -> void: Game.setPaused(false))
	O.restartBtn.pressed.connect(func() -> void:
		if not Game.paused: return
		Game.paused = false
		pauseOv.visible = false
		Game.state = "over"
		Game.overReady = true
		Game.startRace())
	O.pSettings.pressed.connect(openPauseSettings)
	O.quitBtn.pressed.connect(func() -> void: Game.toCareerOr(-1))

## the Online card (and back in an online game after a race): the online screen NetUi, over the menus
func netOpen() -> void:
	NetUi.layer = layer + 5
	NetUi.open()

# ------------------------------------------------------------------ helpers (JS stat bars, car lines)
static func nTop(v: float) -> float: return clampf((v - 150) / (335 - 150), 0.05, 1)
static func nA(a: float) -> float: return clampf((a - 12) / (23 - 12), 0.05, 1)
static func nG(g: float) -> float: return clampf((g - 0.75) / (1.35 - 0.75), 0.05, 1)
static func f1(v: float) -> String: return G.toFixed(v * 10, 1).replace(".", ",")

func isTuned(id: String) -> bool:
	var c: Dictionary = Cars.CARS[id]
	var e := G.effStats(id)
	return e.vmax != c.vmax or e.acc != c.acc or e.grip != c.grip

## the three bars of a car (JS carStatsHtml): Top, Acc., Grip
func carStats(id: String) -> Array:
	var e := G.effStats(id)
	return [UiKit.stat("Top", nTop(e.vmax), str(int(round(e.vmax)))), UiKit.stat("Acc.", nA(e.acc), f1(nA(e.acc))), UiKit.stat("Grip", nG(e.grip), f1(nG(e.grip)))]

func carStatsLine(id: String) -> String:
	var e := G.effStats(id)
	return "%d km/u · acc. %s · grip %s" % [int(round(e.vmax)), f1(nA(e.acc)), f1(nG(e.grip))]

## JS loadTrack(id, dir) for the menus: the world of another track (textures are drawn on the next frames)
func loadTrack(id: String, dir := "") -> void:
	if dir == "": dir = G.settings.dir
	TrackLoader.load_track(id, dir)
	var host := get_tree().current_scene
	if host != null: Canvas2D.flush(host)

func applyEnv(t: String, w: String) -> void:
	if Env.me != null: Env.me.apply(t, w)

## JS applyPrefs after a setting changed: sound and picture quality (Game.applyPrefs)
func applyPrefs() -> void:
	var was := Sfx.muted
	Game.applyPrefs()
	if Sfx.muted != was: Sfx.mute_changed.emit(Sfx.muted)

func toggleMute() -> void:
	Sfx.toggleMute()
	settingsUI.syncToggles()

# ------------------------------------------------------------------ the car being edited (player 1, or player 2 in split screen)
func edCar() -> String: return G.settings.p2car if editP == 2 else G.settings.car
func edCol() -> String: return G.settings.p2color if editP == 2 else G.settings.color

func previewEdit() -> void:
	if editP == 2: Game.rebuildPlayerCar(G.settings.p2car, G.settings.p2color)
	else: Game.rebuildPlayerCar()

func setEditP(n: int) -> void:
	editP = n
	previewEdit()
	refreshMenu()

func pickCar(v: String) -> void:
	if not Cars.CARS.has(v): return
	var S := G.settings
	if editP == 2:
		S.p2car = v
		G.saveSettings()
		previewEdit()
		refreshMenu()
		return
	S.car = v
	if Career.owns(v):
		var lb: Dictionary = (S.get("lastByClass", {}) if S.get("lastByClass") is Dictionary else {}).duplicate()
		lb[Cars.CARS[v].cls] = v
		S.lastByClass = lb
	G.saveSettings()
	Game.rebuildPlayerCar()
	refreshMenu()
	if menuStep == 0:
		var f := get_viewport().gui_get_focus_owner()
		if f == null or not f.is_visible_in_tree() or not menuOv.is_ancestor_of(f):
			var b = setupUI.carRadio.checked_item()
			if b != null: UiKit.focus(b)

## car step: another class gives the car you last drove there (player 1), else the first one you own
func pickClass(v: String) -> void:
	var ids: Array = Cars.carsOf(v).filter(func(id): return Career.owns(id))
	if ids.is_empty(): return
	var lb = G.settings.get("lastByClass", {})
	var l = lb.get(v) if lb is Dictionary else null
	pickCar(l if editP != 2 and l != null and Career.owns(l) else ids[0])

## the steps of the flow: a championship under way keeps its car
func flowSteps() -> Array:
	if menuFlow == "champ": return [3] if Champ.champInProgress() else [0, 3]
	if menuFlow == "net": return [0]
	return [2, 0, 1]

func stepRange(f: String) -> Array:
	var m: String = G.settings.mode
	if f == "bots": return [2 if m == "elim" else (0 if m == "split" else 1), 5 if m == "split" else 7]
	return [1, 5]

func refreshMenu() -> void:
	setupUI.refresh()

## the scene behind the setup: the grid with the bots on the mode step, else the car alone on the track
func menuScene() -> void:
	var m: String = G.settings.mode
	if menuStep == 2 and (m == "race" or m == "elim" or m == "split"):
		Game.clearTraffic(); Game.setupBots(int(G.settings.bots)); Game.placeGrid()
	elif menuStep == 2 and m == "ghost":
		Game.clearTraffic(); Game.clearBots(); Game.placeGrid()
	else:
		Game.clearBots(); Game.clearTraffic(); Game.resetPlayer(0, 0)
	Game.syncCar(0)

# ------------------------------------------------------------------ showMenu, homePanel (JS)
func showMenu(step: int) -> void:
	if editP == 2 and step != 0:
		editP = 1
		Game.rebuildPlayerCar()
	menuStep = step
	if step == 0: Career.ensureOwnedCars()
	if step < 0:
		menuScene()
		menuOv.visible = false
		home.visible = true
		homePanel("main")
		return
	if step == 3 and Champ.champInProgress():
		G.settings.car = Champ.champ.car
		G.settings.color = Champ.champ.color
		Game.rebuildPlayerCar()
	menuScene()
	home.visible = false
	if step == 0: setupUI.refreshCarCards()
	refreshMenu()
	menuOv.visible = true
	UiKit.focus(setupUI.first_focus())
	_reveal_checked.call_deferred()

## the chosen car or track in view (six cars a class, ten tracks)
func _reveal_checked() -> void:
	for _i in 2: await get_tree().process_frame
	var rg = {0: setupUI.carRadio, 1: setupUI.trackRadio}.get(menuStep)
	var f = rg.checked_item() if rg != null else null
	if f != null and f.is_visible_in_tree(): setupUI.scroll.ensure_control_visible(f)

## what "Verder racen" on the home screen does: continue a cup or championship under way, else a quick race
func resumeInfo() -> Dictionary:
	var run = Career.careerRun()
	var S := G.settings
	if run != null:
		var cup = Career.cupById(run.career)
		if cup != null:
			var goCup := func() -> void: Career.startCup(cup, run.car, false)
			return {"title": cup.name, "sub": "Carrière · race %d van %d · %s" % [int(run.round) + 1, cup.rounds.size(), TrackDefs.TRACKS[cup.rounds[int(run.round)].track].name],
				"cta": "Verder racen", "resume": true, "go": goCup}
	var qc = Champ.loadQuickChamp()
	var CRN: Array = Champ.CHAMP_ROUNDS
	if qc != null and not qc.get("done", false) and not qc.get("career") and int(qc.round) < CRN.size():
		var goChamp := func() -> void:
			Champ.champ = qc
			menuFlow = "champ"
			Champ.champ.active = true
			Champ.saveChamp()
			Champ.loadChampRound()
			Game.startRace()
		return {"title": "Kampioenschap", "sub": "Race %d van %d · %s · %d pt" % [int(qc.round) + 1, CRN.size(), TrackDefs.TRACKS[CRN[int(qc.round)].track].name, int(qc.pts.Jij)],
			"cta": "Verder racen", "resume": true, "go": goChamp}
	var m: String = S.mode
	var nb := int(S.bots)
	var L := int(S.laps)
	var sub: String = MODE_NAMES[m] + " · " + Cars.CARS[S.car].name
	if m == "race" or m == "elim" or m == "split": sub += " · %d %s" % [nb, "bot" if nb == 1 else "bots"]
	if m == "race" or m == "ghost" or m == "split": sub += " · %d %s" % [L, "ronde" if L == 1 else "ronden"]
	var goQuick := func() -> void: homeUI.hQuick.press()
	return {"title": TrackDefs.TRACKS[S.track].name + (" · omgekeerd" if S.dir == "rev" else ""), "sub": sub, "cta": "Snel racen", "go": goQuick}

func homePanel(v: String) -> void:
	var from := homeView
	homeView = v
	var S := G.settings
	# browsing the garage can show cars you have not bought: leaving it puts you back in a car you own
	if v == "garage" and from != "garage": garageCar = S.car
	if from == "garage" and v != "garage" and not Career.owns(S.car):
		S.car = garageCar if garageCar != null and Career.owns(garageCar) else Career.ownedCar(S.car)
		G.saveSettings()
		if Game.car != null and v != "main": Game.rebuildPlayerCar()
	if v == "main" and Game.car != null: Game.rebuildPlayerCar()
	for k in panels:
		panels[k].content.visible = k == v
		panels[k].nav.visible = k == v
	var main := v == "main"
	homeUI.main.visible = main
	homeHolder.visible = not main
	homeBackdrop.set_mode("main" if main else "menu")
	homeHolder.max_w = 720.0 if v == "ach" else 540.0
	homeHolder.queue_sort()
	homeScroll.scroll_vertical = 0
	if main:
		var ri := resumeInfo()
		homeUI.refreshMain(ri)
		_resumeGo = ri.go
		UiKit.focus(homeUI.hPlay)
	if v == "play":
		var m: String = S.mode
		var nb := int(S.bots)
		var L := int(S.laps)
		var q: String = TrackDefs.TRACKS[S.track].name + (" (omgekeerd)" if S.dir == "rev" else "") + " · " + MODE_NAMES[m].to_lower() + " · " + Cars.CARS[S.car].name
		if m == "race" or m == "elim" or m == "split": q += " · %d %s" % [nb, "bot" if nb == 1 else "bots"]
		if m == "race" or m == "ghost" or m == "split": q += " · %d %s" % [L, "ronde" if L == 1 else "ronden"]
		var run = Career.careerRun()
		var nx = Career.careerNext()
		var cup = Career.cupById(run.career) if run != null else null
		var ci: String = ("%s · race %d van %d" % [cup.name, int(run.round) + 1, cup.rounds.size()]) if cup != null else \
			(("Hoofdstuk %d · %s" % [Career.CHAPTERS.find(Career.chapterOf(nx)) + 1, nx.name]) if nx != null else "Legende! Alles gehaald")
		var qc = Champ.loadQuickChamp()
		var CRN: Array = Champ.CHAMP_ROUNDS
		var ip: bool = qc != null and not qc.get("done", false) and not qc.get("career") and int(qc.round) < CRN.size()
		homeUI.refreshPlay(q, ci, ("Bezig · race %d van %d · %d pt" % [int(qc.round) + 1, CRN.size(), int(qc.pts.Jij)]) if ip else "%d races tegen 5 vaste tegenstanders" % CRN.size())
		UiKit.focus(homeUI.hStart)
	if v == "records":
		homeUI.refreshRecords()
		UiKit.focus(homeUI.records.back)
	if v == "settings":
		settingsUI.syncToggles()
		UiKit.focus(_first_setting())
	if v == "career":
		careerUI.openCareer()
		UiKit.focus(careerUI.careerGo if not careerUI.careerGo.disabled else careerUI.back)
	if v == "ach":
		homeUI.refreshAch()
	if v == "garage":
		GarageRoom.enterGarageScene()
		garageUI.openGarage()
	else:
		GarageRoom.leaveGarageScene()
		if v != "main": menuScene()

## JS: querySelector('.tog,[role=radio]') (pause: '[role=switch],[role=radio]'): the first match in document order is
## always the first tab, "Algemeen", whichever tab is open
func _first_setting() -> Control:
	return settingsUI.tabRadio.find("general")

func homeBack() -> void:
	var from := homeView
	var to: String = garageFrom if from == "garage" and garageFrom != null else HOME_PARENT.get(from, "main")
	garageFrom = null
	homePanel(to)
	if to == "play":
		var b = {"career": homeUI.hCareer, "net": homeUI.hNet}.get(from)
		if b != null: UiKit.focus(b)

func menuNext() -> void:
	if menuStep < 0:
		if homeView == "main": homeUI.hPlay.press()
		return
	var steps := flowSteps()
	var i := steps.find(menuStep)
	if i < steps.size() - 1:
		showMenu(steps[i + 1])
		return
	if menuFlow == "net":
		_netCarDone()
		return
	if menuFlow == "champ":
		if not Champ.champInProgress(): Champ.newChamp()
		Champ.champ.active = true
		Champ.saveChamp()
		Champ.loadChampRound()
		Game.startRace()
	else:
		Game.startRace()

func menuBack() -> void:
	if menuStep < 0:
		if homeView != "main": homeBack()
		return
	if menuFlow == "net":
		_netCarDone()
		return
	var steps := flowSteps()
	var i := steps.find(menuStep)
	if i > 0:
		showMenu(steps[i - 1])
		return
	# first step of Race or Kampioenschap: back to "Spelen", on the button that opened it
	var fl := menuFlow
	showMenu(-1)
	homePanel("play")
	UiKit.focus(homeUI.hChamp if fl == "champ" else homeUI.hStart)

## the car step of an online game is done (the online port provides Game.netCarDone)
func _netCarDone() -> void:
	if Game.has_method("netCarDone"): Game.call("netCarDone")
	else:
		menuFlow = "quick"
		showMenu(-1)

func menuCycle(d: int) -> void:
	if menuStep < 0: return
	var S := G.settings
	if menuStep == 0:
		var ids: Array = Cars.carsOf(Cars.CARS[edCar()].cls).filter(func(id): return Career.owns(id))
		if not ids.is_empty(): pickCar(ids[(ids.find(edCar()) + d + ids.size()) % ids.size()])
		return
	elif menuStep == 1:
		var ids: Array = TrackDefs.TRACKS.keys()
		var v: String = ids[(ids.find(Trk.TRACK_ID) + d + ids.size()) % ids.size()]
		S.track = v
		G.saveSettings()
		loadTrack(v)
		applyEnv(S.time, S.weather)
		menuScene()
	elif menuStep == 2:
		var ms := ["race", "elim", "time", "ghost", "split"]
		S.mode = ms[(ms.find(S.mode) + d + 5) % 5]
		G.saveSettings()
		menuScene()
	refreshMenu()

func classCycle(d: int) -> void:
	if menuStep != 0: return
	var cl := ["B", "A", "S"].filter(func(c): return Cars.carsOf(c).any(func(id): return Career.owns(id)))
	if cl.size() < 2: return
	pickClass(cl[(cl.find(Cars.CARS[edCar()].cls) + d + cl.size()) % cl.size()])

# ------------------------------------------------------------------ from game.gd: race start, toMenu, results, pause
## JS startRace: the garage room and the podium go, every menu screen hides
func beforeRace() -> void:
	GarageRoom.leaveGarageScene()
	Podium.leavePodium()
	closePauseSettings()
	hideAll()
	if NetUi.is_open(): NetUi.ov.visible = false    # the online screen is a home panel in the HTML: it goes too
	syncOverMode()
	_setViewOff(Game.camera, 0, -1)

func hideAll() -> void:
	for o in [home, menuOv, overOv, pauseOv]: o.visible = false

## JS toMenu (after the generic part in game.gd): championship and career clean-up, then the menu
func toMenu(step: int) -> void:
	closePauseSettings()
	Podium.leavePodium()
	pauseOv.visible = false
	overOv.visible = false
	var S := G.settings
	if Champ.champPrevDiff != null:
		S.diff = Champ.champPrevDiff
		Champ.champPrevDiff = null
	var c = Champ.champ
	if c != null and int(c.round) >= Champ.CR().size() and not c.get("done", false):
		c.done = true
		c.active = false
		Champ.saveChamp()
	if c != null and c.get("career"):
		c.active = false
		Champ.saveChamp()
		Champ.champ = Champ.loadQuickChamp()
	G.careerEv = null
	if G.careerPrev != null:
		S.merge(G.careerPrev, true)
		G.careerPrev = null
	showMenu(step)

## JS toCareerOr: after a career race or cup back to the career screen (the next event is selected there)
func toCareerOr(step: int) -> void:
	var c: bool = G.careerEv != null or (Champ.champ != null and Champ.champ.get("career") != null)
	Game.toMenu(step)
	if c:
		careerSel = null
		homePanel("career")

func pauseSettingsOpen() -> bool:
	return settingsUI.content.get_parent() == overUI.pauseBoard.get_child(0) and settingsUI.content.is_inside_tree()

func openPauseSettings() -> void:
	var s := settingsUI
	var pv: VBoxContainer = overUI.pauseBoard.get_child(0)
	if pauseSettingsOpen(): return
	overUI.pauseMain.visible = false
	s.content.reparent(pv)
	s.nav.reparent(pv)
	s.content.visible = true
	s.nav.visible = true
	pauseHolder.max_w = 540
	pauseHolder.queue_sort()
	s.syncToggles()
	UiKit.focus(_first_setting())

func closePauseSettings() -> void:
	if not pauseSettingsOpen(): return
	var s := settingsUI
	s.content.reparent(homeContent)
	s.nav.reparent(homeNav.get_child(0))
	s.content.visible = homeView == "settings"
	s.nav.visible = homeView == "settings"
	overUI.pauseMain.visible = true
	pauseHolder.max_w = 400
	pauseHolder.queue_sort()
	if Game.paused: UiKit.focus(overUI.resumeBtn)

## JS setPaused (the screen side): the pause screen with where you are in the race
func setPausedUI(p: bool) -> void:
	if not p: closePauseSettings()
	pauseOv.visible = p
	if p and TrackDefs.TRACKS.has(Trk.TRACK_ID):
		var g := Game
		var t: String = TrackDefs.TRACKS[Trk.TRACK_ID].name + (" (omgekeerd)" if Trk.TRACK_DIR == "rev" else "") + " · " + Hud.lapT.text.to_lower().replace("/", " van ")
		if g.raceMode or g.mode == "elim": t += " · plek " + Hud.big.text.replace("/", " van ")
		elif g.mode == "time": t += " · " + G.fmtKm(g.distance)
		overUI.pauseSub.text = t

func setEarned(n: int, label := "") -> void:
	overUI.earnTag.visible = n > 0
	UiKit.pill_text(overUI.earnTag, "+" + G.fmtCr(n) + (" " + label if label != "" else ""))

## JS showOver: the results board with the right buttons
func showOver() -> void:
	var O := overUI
	var g := Game
	O.replayBtn.visible = Rep.canReplay()
	for n in [Hud.hud, Hud.msg, Hud.lights]: n.visible = false
	overOv.visible = true
	g.clearKeys()
	O.overSub.text = (TrackDefs.TRACKS[Trk.TRACK_ID].name + (" (omgekeerd)" if Trk.TRACK_DIR == "rev" else "") + " · " + MODE_NAMES[g.mode].to_lower() +
		("" if g.mode == "time" else " · %d %s" % [g.raceLaps, "ronde" if g.raceLaps == 1 else "ronden"])).to_upper()
	O.storyBox.visible = false
	var ce = G.careerEv.res if G.careerEv != null else null
	UiKit.btn_text(O.againBtn, "Tussenstand" if g.mode == "champ" else (("Verder" if ce.passed else "Nog een keer") if ce != null else "Opnieuw racen"))
	UiKit.btn_text(O.menuBtn, "Carrière" if G.careerEv != null or (Champ.champ != null and Champ.champ.get("career")) else "Hoofdmenu")
	O.menuBtn.visible = true
	O.againBtn.visible = true
	if Net.net != null:
		# online: only the host starts the next race; the others get it automatically
		UiKit.btn_text(O.againBtn, "Nieuwe race")
		O.againBtn.visible = Net.isHost()
	get_tree().create_timer(0.7, true, false, true).timeout.connect(func() -> void:
		if Game.state == "over" and overOv.visible: UiKit.focus(O.againBtn))

## JS buildResults (+ raceStatTiles): the results list, refreshed every half second while cars still finish
func buildResults() -> void:
	var g := Game
	var O := overUI
	UiKit.clear(O.results)
	g.resultsAt = g.clock + 0.5
	if g.mode == "ghost":
		var best := 1e9
		for t in g.lapTimes: best = minf(best, t)
		for k in g.lapTimes.size():
			O.results.add_child(O.row(g.lapTimes[k] == best, "%d." % (k + 1), "Ronde %d" % (k + 1), "", G.fmtLap(g.lapTimes[k])))
		O.overTitle.text = "Ghost-tijdrit klaar"
		O.stats.visible = false
		O.results.visible = true
		raceStatTiles()
		UiKit.pill_text(O.recordTag, "Nieuwe ghost opgeslagen")
		O.recordTag.visible = g.ghostSaved
		return
	var rows: Array = g.resultOrder()
	g.resultRows = rows
	var winner = null
	for r in rows:
		if r.finished: winner = r; break
	raceStatTiles()
	for k in rows.size():
		var r: Dictionary = rows[k]
		var tm: String
		if g.mode == "elim": tm = "eruit" if r.out else ("winnaar" if k == 0 and not g.playerOut else "rijdt nog")
		elif r.finished: tm = G.fmtLap(r.ft) if r == winner else "+" + G.toFixed(r.ft - winner.ft, 1).replace(".", ",") + " s"
		else: tm = "rijdt nog"
		r.tm = tm
		O.results.add_child(O.row(r.get("me", false), "%d." % (k + 1), r.name, r.car, tm, ("+%d" % (Champ.CHAMP_PTS[k] if k < Champ.CHAMP_PTS.size() else 0)) if g.mode == "champ" else null))
	var pos := 0
	for k in rows.size():
		if rows[k].get("me", false): pos = k + 1; break
	if g.split:
		O.overTitle.text = str(rows[pos - 1].name) + " is de snelste speler!"
	elif g.mode == "elim" and g.playerOut: O.overTitle.text = "Uitgeschakeld: %de" % pos
	else: O.overTitle.text = "Gewonnen!" if pos == 1 else "Je werd %de" % pos
	O.stats.visible = false
	O.results.visible = true
	O.recordTag.visible = g.lapRecordSet
	UiKit.pill_text(O.recordTag, "Nieuw klasserecord " + (G.fmtLap(g.raceBestLap) if g.raceBestLap else ""))

func raceStatTiles() -> void:
	var g := Game
	var O := overUI
	O.rstats.visible = true
	O.rTot.text = G.fmtLap(g.raceFinishTime) if g.raceDone and not g.playerOut and g.raceFinishTime > 0 else "–"
	O.rLap.text = G.fmtLap(g.raceBestLap) if g.raceBestLap else "–"
	O.rTop.text = str(int(round(g.raceTopSpeed * 3.6)))

## from game.gd (state "over" each frame): the results of a race keep updating while the bots finish
func overTick() -> void:
	var g := Game
	if g.raceMode and g.mode != "champ" and g.overView == "results" and g.clock > g.resultsAt and overOv.visible:
		buildResults()

## from game.gd: JS showResults (after state = "over"): results, credits, championship points, career result, podium
func showResults() -> void:
	var g := Game
	buildResults()
	var cr := 0
	var label := ""
	var pos := 0
	for k in g.resultRows.size():
		if g.resultRows[k].get("me", false): pos = k + 1; break
	if not g.split: Ach.achRaceEnd(pos)
	if g.mode == "champ":
		Champ.champRecordRace()
		cr = g.awardCredits(pos)
	elif g.mode == "ghost":
		cr = g.awardCredits(0)
	elif G.careerEv != null:
		var ev: Dictionary = G.careerEv.ev
		G.careerEv.res = Career.careerEventDone(ev, pos)
		cr = G.addCredits(ev.prize[pos - 1] if pos - 1 < ev.prize.size() else 0)
		label = "prijzengeld"
	else:
		cr = g.awardCredits(pos)
	setEarned(cr, label)
	showOver()
	if G.careerEv != null: careerStory(G.careerEv.ev, G.careerEv.res)
	if (g.mode == "race" or g.mode == "elim" or g.mode == "champ") and not g.split and not g.netInRace() and g.resultRows.size() > 1:
		var cup = Career.cupById(Champ.champ.career) if g.mode == "champ" and Champ.champ != null and Champ.champ.get("career") else null
		var tr: Dictionary = TrackDefs.TRACKS[Trk.TRACK_ID]
		Podium.enterPodium(Podium.podiumEntries(g.resultRows, func(r): return r.get("tm", "")), cup.name if cup != null else ("Kampioenschap" if g.mode == "champ" else tr.get("banner", tr.name)))
		syncOverMode()

## from Hud (game.gd endTimeTrial): the time trial's tiles
func showTimeTrialOver(distance: float, cps: int, bestLap: float, best: float, rec: bool, cr: int) -> void:
	var O := overUI
	O.overTitle.text = "Tijd is op"
	O.stats.visible = true
	O.rstats.visible = false
	O.results.visible = false
	O.oDist.text = G.fmtKm(distance)
	O.oCp.text = str(cps)
	O.oLap.text = G.fmtLap(bestLap) if bestLap else "–"
	O.oBest.text = G.fmtKm(best)
	UiKit.pill_text(O.recordTag, "Nieuw record")
	O.recordTag.visible = rec
	setEarned(cr)
	showOver()

## from game.gd (onAgain): the championship standings / next round, or on to the next career event; true = handled
func onAgain() -> bool:
	var g := Game
	if g.mode == "champ":
		if g.overView == "results":
			showStandings()
			return true
		if int(Champ.champ.round) < Champ.CR().size():
			Champ.loadChampRound()
			g.startRace()
		else:
			g.toCareerOr(-1)
		return true
	if G.careerEv != null and G.careerEv.res != null and G.careerEv.res.passed:
		g.toCareerOr(-1)
		return true
	return false

## JS showStandings: the championship table after a round; at the end the final standings, the bonus and the podium
func showStandings() -> void:
	var g := Game
	var O := overUI
	var champ: Dictionary = Champ.champ
	g.overView = "standings"
	var st := Champ.champStandings()
	UiKit.clear(O.results)
	for k in st.size():
		var r: Dictionary = st[k]
		O.results.add_child(O.row(r.me, "%d." % (k + 1), r.name, r.car, "%d pt" % int(r.pts)))
	var done: bool = int(champ.round) >= Champ.CR().size()
	var pos := 0
	for k in st.size():
		if st[k].me: pos = k + 1
	O.storyBox.visible = false
	if done:
		O.overTitle.text = "Kampioen!" if pos == 1 else "Eindstand: %de" % pos
		var cup = Career.cupById(champ.career) if champ.get("career") else null
		Podium.enterPodium(Podium.podiumEntries(st, func(r): return "%d pt" % int(r.pts)), cup.name if cup != null else "Kampioenschap")
		syncOverMode()
		if not champ.get("bonusPaid", false):
			champ.bonusPaid = true
			var b := 0
			if cup != null: b = cup.prize[pos - 1] if pos - 1 < cup.prize.size() else 0
			else: b = int(round(([2000, 1200, 800][pos - 1] if pos <= 3 else 0) * G.DIFF[champ.diff].pay))
			var cr := G.addCredits(b) if b else 0
			setEarned(cr, cup.name + "-bonus" if cup != null else "Kampioenschapsbonus")
			champ.active = false
			champ.done = true
			Champ.saveChamp()
			if cup != null: champ.res = Career.careerEventDone(cup, pos)
			elif pos == 1: Ach.unlockAch("champ")
		if cup != null and champ.get("res") != null: careerStory(cup, champ.res)
		UiKit.btn_text(O.againBtn, "Verder" if champ.get("career") else "Naar het hoofdmenu")
		O.menuBtn.visible = false
		O.replayBtn.visible = false
	else:
		O.overTitle.text = "Tussenstand na race %d van %d" % [int(champ.round), Champ.CR().size()]
		var nx: Dictionary = Champ.CR()[int(champ.round)]
		UiKit.btn_text(O.againBtn, "Volgende race: " + TrackDefs.TRACKS[nx.track].name)
	O.recordTag.visible = false
	O.stats.visible = false
	O.rstats.visible = false
	O.results.visible = true
	UiKit.focus(O.againBtn)

## JS careerStory: who says what after this event (and the chapter's ending, with its bonus)
func careerStory(ev: Dictionary, res: Dictionary) -> void:
	var lines := [ev.win if res.passed else ev.lose]
	if res.first and res.fin: lines.append(Career.CHAPTERS[res.chi].outro)
	var v := UiKit.story_clear(overUI.storyBox)
	for l in lines: v.add_child(CareerUI.storyLine(l))
	if res.bonus:
		v.add_child(UiKit.lbl("+ " + G.fmtCr(res.bonus) + " bonus", 900, 15, UiKit.DETOUR, false, 0, false, 1.0))
	overUI.storyBox.visible = true

# ------------------------------------------------------------------ per frame
func _process(_dt: float) -> void:
	syncOverMode()

## the results board stands left beside the podium (JS #over.menu), centred over a blurred race otherwise
func syncOverMode() -> void:
	var pm := Podium.inPodium
	if pm != _overMenu:
		_overMenu = pm
		overHolder.left = pm
		overHolder.max_w = 540.0 if pm else 640.0
		overBack.set_mode("menu" if pm else "blur")
		overHolder.queue_sort()

# ------------------------------------------------------------------ camera (JS updateCamera, menu part)
## from game.gd updateCamera: the menu views; true = handled (the race camera does not run)
func menuCamera(dt: float) -> bool:
	var cam: Camera3D = Game.camera
	if Podium.inPodium:
		Game.speedFx = 0
		Podium.podiumUpdate(dt, cam)
		_setViewOff(cam, _wideOff(), 46)
		return true
	if Game.state != "menu":
		if _viewOff != 0 or cam.projection != Camera3D.PROJECTION_PERSPECTIVE: _setViewOff(cam, 0, -1)
		return false
	var car = Game.car
	if car != null: car.g.visible = true
	var a := Game.clock * 0.14
	if GarageRoom.inGarage and car != null:
		car.g.position = GarageRoom.GPOS
		car.g.rotation = Vector3(0, 0.5, 0)
	if menuStep < 0 and homeView != "garage":
		# home screen fly-over along the track
		Game.flyS = fmod(Game.flyS + dt * 24, Trk.TRACK_LEN)
		var lat := sin(Game.clock * 0.12) * minf(10, Trk.SHOULDER - 2.2)
		var ta := Trk.trackAt(Game.flyS)
		var cx: float = ta.px + ta.rx * lat
		var cz: float = ta.pz + ta.rz * lat
		var cy: float = Trk.hAt(ta.i, lat) + 4.2 + sin(Game.clock * 0.2) * 1.2
		var tb := Trk.trackAt(Game.flyS + 35)
		cam.position = Vector3(cx, cy, cz)
		cam.look_at(Vector3(tb.px, Trk.hAt(tb.i, 0) + 1.5, tb.pz), Vector3.UP)
	elif car != null and (menuStep == 0 or menuStep < 0):
		var p: Vector3 = car.g.position
		_orbitStep(dt)
		cam.position = Vector3(p.x + sin(orb.a) * 7.4, p.y + orb.h, p.z + cos(orb.a) * 7.4)
		cam.look_at(Vector3(p.x, p.y + 0.6, p.z), Vector3.UP)
	elif car != null:
		var p: Vector3 = car.g.position
		var rad := minf(13, Trk.SHOULDER - 1.6)
		cam.position = Vector3(p.x + sin(a) * rad, p.y + 3.6, p.z + cos(a) * rad)
		cam.look_at(Vector3(p.x, p.y + 1, p.z), Vector3.UP)
	_setViewOff(cam, _wideOff(), 58)
	return true

func _wideOff() -> float:
	var w := get_viewport().get_visible_rect().size.x
	return -minf(w * 0.2, 260) if w > 760 else 0.0

## three.js camera.setViewOffset(): the picture shifted sideways (the car beside the panel, not behind it). Godot has no
## view offset on a perspective camera, so the same frustum is set as an off-centre frustum.
func _setViewOff(cam: Camera3D, ox: float, fov: float) -> void:
	if cam == null: return
	_viewOff = ox
	if ox == 0:
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		if fov > 0: cam.fov = fov
		return
	var h := get_viewport().get_visible_rect().size.y
	cam.projection = Camera3D.PROJECTION_FRUSTUM
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.fov = fov
	cam.size = 2.0 * cam.near * tan(deg_to_rad(fov) / 2.0)
	cam.frustum_offset = Vector2(ox / h * cam.size, 0)

func _orbitStep(dt: float) -> void:
	if orb.drag != null: return
	orb.a += orb.vel * dt
	orb.vel *= exp(-dt * 3)
	orb.idle += dt
	if orb.idle > 4: orb.a += dt * 0.14

## drag beside the panel to turn the car (the car step and the garage)
func _orbit_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			if not (Game.state == "menu" and (menuStep == 0 or homeView == "garage")): return
			if menuStep < 0 and homeView == "main": return
			orb.drag = {"x": e.position.x, "y": e.position.y, "t": Time.get_ticks_msec()}
			orb.vel = 0.0
		else:
			orb.drag = null
	elif e is InputEventMouseMotion and orb.drag != null:
		var d: Dictionary = orb.drag
		var dx: float = e.position.x - d.x
		var dy: float = e.position.y - d.y
		var now := Time.get_ticks_msec()
		var dtt := maxf(0.004, (now - d.t) / 1000.0)
		orb.a -= dx * 0.009
		orb.h = clampf(orb.h - dy * 0.01, 0.7, 4.2)
		orb.vel = -dx * 0.009 / dtt * 0.6
		d.x = e.position.x; d.y = e.position.y; d.t = now
		orb.idle = 0.0

# ------------------------------------------------------------------ keyboard and gamepad (JS keydown / readPad, menu part)
## every button under a node in tree order
static func _buttons(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is UiKit.Btn: out.append(c)
		out.append_array(_buttons(c))
	return out

## JS padFocus: the next or previous button (only the checked one of a radio group), and scroll it into view
func padFocus(d: int, r: Control = null) -> void:
	if r == null: r = home if Game.state == "menu" and menuStep < 0 else menuOv
	var list := _buttons(r).filter(func(b): return b.is_visible_in_tree() and not b.disabled and (b.radio == null or b.checked))
	if list.is_empty(): return
	var i := list.find(get_viewport().gui_get_focus_owner())
	var n: Control = list[(i + d + list.size()) % list.size()]
	UiKit.focus(n, true)

func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed: UiKit.pointer = true
	elif e is InputEventKey or e is InputEventJoypadButton: UiKit.pointer = false
	if not (e is InputEventKey) or not e.pressed: return
	var code := Game.codeOf(e)
	if bindCapture.is_valid():
		get_viewport().set_input_as_handled()
		if not e.echo: bindCapture.call(code)
		return
	var f := get_viewport().gui_get_focus_owner()
	# typing in a text field (start number): leave every key to the field; Escape and Enter leave it
	if f is LineEdit:
		if code == "Escape" or code == "Enter" or code == "NumpadEnter":
			f.release_focus()
			get_viewport().set_input_as_handled()
		return
	var onBtn: bool = f is UiKit.Btn and f.is_visible_in_tree()
	var enter := code == "Enter" or code == "NumpadEnter"
	var st: String = Game.state
	# the online screen (NetUi) over the menus has its own controls
	if NetUi.is_open() and st == "menu": return
	if st == "menu":
		if code == "Tab": return
		get_viewport().set_input_as_handled()
		if code == "KeyM" and not e.echo: toggleMute()    # (Game._input mutes in the other states)
		if (enter or code == "Space") and onBtn:
			if not e.echo: f.press()
			return
		if enter and not e.echo: menuNext()
		if code == "Escape" or code == "Backspace": menuBack()
		if code.begins_with("Arrow"):
			var d := 1 if (code == "ArrowRight" or code == "ArrowDown") else -1
			if onBtn and f.radio != null: f.radio.arrow(f, d)
			elif menuStep < 0: padFocus(d)
		return
	if Game.paused or (st == "over" and overOv.visible):
		if (enter or code == "Space") and onBtn:
			get_viewport().set_input_as_handled()
			if not e.echo: f.press()
			return
		if code.begins_with("Arrow") and onBtn:
			get_viewport().set_input_as_handled()
			if f.radio != null: f.radio.arrow(f, 1 if (code == "ArrowRight" or code == "ArrowDown") else -1)
			return
		if Game.paused and pauseSettingsOpen():
			if code == "Escape" or code == "KeyP":
				get_viewport().set_input_as_handled()
				closePauseSettings()
			elif enter or code == "Space":
				get_viewport().set_input_as_handled()

## from game.gd readPad: the gamepad in the menus, the pause and the results screen; true = handled
func padNav(now: Dictionary, prev: Dictionary) -> bool:
	var edge := func(k: String) -> bool: return now.get(k, false) and not prev.get(k, false)
	var g := Game
	if g.state == "menu" and NetUi.is_open():
		if edge.call("b"): NetUi.close()
		return true
	if g.state == "menu" and menuStep < 0:
		if edge.call("up"): padFocus(-1)
		if edge.call("down"): padFocus(1)
		if edge.call("a"):
			var f := get_viewport().gui_get_focus_owner()
			if f is UiKit.Btn and home.is_ancestor_of(f): f.press()
			else: menuNext()
		elif edge.call("start"): menuNext()
		if edge.call("b"): menuBack()
		return true
	if g.state == "menu":
		if edge.call("up"): padFocus(-1)
		if edge.call("down"): padFocus(1)
		if edge.call("a") or edge.call("start"): menuNext()
		if edge.call("b"): menuBack()
		if edge.call("l"): menuCycle(-1)
		if edge.call("r"): menuCycle(1)
		if edge.call("lb"): classCycle(-1)
		if edge.call("rb"): classCycle(1)
		return true
	if g.paused:
		if edge.call("up"): padFocus(-1, pauseOv)
		if edge.call("down"): padFocus(1, pauseOv)
		if edge.call("a"):
			var f := get_viewport().gui_get_focus_owner()
			if f is UiKit.Btn and pauseOv.is_ancestor_of(f): f.press()
			else: g.setPaused(false)
		if edge.call("start"): g.setPaused(false)
		if edge.call("b"):
			if pauseSettingsOpen(): closePauseSettings()
			else: g.setPaused(false)
		return true
	if g.state == "over" and g.overReady:
		if edge.call("a") or edge.call("start"): g.onAgain()
		if edge.call("b"): g.toCareerOr(-1)
		return true
	return false

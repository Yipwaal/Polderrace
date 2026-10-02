extends RefCounted
## The menus and the meta-game (Menu, Champ, Career, Ach), walked through like a player would: every home panel, keys
## on the home screen, a quick race set up step by step (start, finish, results with the podium, again, back to the
## menu), buying an upgrade and a car, a championship round with its standings, a career event, achievements,
## settings with a key binding, and the pause screen. Plays on its own save file (G.use_store) and checks it too.

var L
var r: TestReport

func key(code: int, shift := false) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	e.shift_pressed = shift
	Menu.get_viewport().push_input(e)
	var u := e.duplicate()
	u.pressed = false
	Menu.get_viewport().push_input(u)

func focused() -> Control:
	return Menu.get_viewport().gui_get_focus_owner()

func saved(k: String) -> Dictionary:
	var v = JSON.parse_string(str(G.store_get(k, "{}")))
	return v if v is Dictionary else {}

## from the start lights to the results (the test autopilot drives, tests/test_laps.gd)
func race_to_end(max_s := 260.0) -> void:
	L.step(4.5, false)
	var t := 0.0
	while t < max_s and Game.state != "over":
		L.step(2)
		t += 2
	L.step(0.2)

## a race cut short: a few seconds of driving, then the finish (the result is wherever you are)
func quick_finish() -> void:
	L.step(4.5, false)
	L.step(4)
	Game.finishPlayer()
	L.step(3.5)

func run(host: Node) -> TestReport:
	r = TestReport.new("menu's, garage, kampioenschap, carrière en prestaties")
	L = load("res://tests/test_laps.gd").new()
	var env := Env.new()
	host.add_child(env)
	World.root = Node3D.new()
	host.add_child(World.root)
	var cam := Camera3D.new()
	host.add_child(cam)
	Game.camera = cam
	Game.set_process(false)
	Game.set_process_input(false)
	# a new player: only the hot hatch, € 5.000
	G.use_store("user://test-menus.json", {"polderrace3d-garage": {"credits": 5000, "owned": {"hatch": true}}})
	r.check(G.settings.car == "hatch", "nieuwe speler: in de enige eigen auto (hot hatch)", G.settings.car)
	TrackLoader.load_track("polder", "fwd")
	env.apply("day", "dry", true)
	Game.rebuildPlayerCar()
	Game.toMenu(-1)
	# ---- home screen
	r.check(Game.state == "menu" and Menu.home.visible and Menu.homeView == "main", "hoofdscherm open")
	r.check(Menu.homeUI.playTitle.text == "Polder", "tegel Spelen: baan", Menu.homeUI.playTitle.text)
	r.check(Menu.homeUI.garTitle.text == "Hot hatch", "tegel Garage: auto", Menu.homeUI.garTitle.text)
	r.check(Menu.homeUI.achHomeInfo.text == "0 van 21 behaald", "tegel Meer: prestaties", Menu.homeUI.achHomeInfo.text)
	r.check(focused() == Menu.homeUI.hPlay, "Start heeft de focus")
	key(KEY_RIGHT)
	r.check(focused() == Menu.homeUI.hGarage, "pijl rechts: volgende knop", str(focused()))
	key(KEY_LEFT)
	r.check(focused() == Menu.homeUI.hPlay, "pijl links: terug op Start")
	for v in ["play", "records", "settings", "ach", "career", "garage"]:
		Menu.homePanel(v)
		var shown: Array = Menu.panels.keys().filter(func(k): return Menu.panels[k].content.visible)
		r.check(shown == [v] and Menu.panels[v].nav.visible and not Menu.homeUI.main.visible, "paneel %s open" % v, str(shown))
	r.check(GarageRoom.inGarage, "garage: de auto staat in de garage")
	key(KEY_ESCAPE)
	r.check(Menu.homeView == "main" and not GarageRoom.inGarage, "Esc: terug naar het hoofdscherm, garage dicht", Menu.homeView)
	Menu.homePanel("career")
	key(KEY_ESCAPE)
	r.check(Menu.homeView == "play", "Esc in de carrière: terug naar Spelen", Menu.homeView)
	r.check(focused() == Menu.homeUI.hCareer, "focus op Carrière")
	key(KEY_ENTER)
	r.check(Menu.homeView == "career", "Enter op een knop: die knop", Menu.homeView)
	Menu.homeBack()
	Menu.homeBack()
	r.check(Menu.homeView == "main", "terug op het hoofdscherm")
	# ---- records panel lists every track, achievements all 21
	Menu.homePanel("records")
	r.check(Menu.homeUI.recList.get_child_count() >= 1, "records: tabel")
	Menu.homePanel("ach")
	r.check(Menu.homeUI.achList.get_child_count() == 21, "prestaties: 21 stuks", str(Menu.homeUI.achList.get_child_count()))
	Menu.homePanel("main")
	# ---- quick race, step by step
	Menu.homeUI.hPlay.press()
	Menu.homeUI.hStart.press()
	r.check(Menu.menuOv.visible and Menu.menuStep == 2 and Menu.menuFlow == "quick", "Race: stap Spelmodus", str(Menu.menuStep))
	Menu.setupUI.modeRadio.find("elim").press()
	r.check(G.settings.mode == "elim" and int(G.settings.bots) >= 2, "modus eliminatie gekozen")
	Menu.setupUI.modeRadio.find("race").press()
	Menu.setupUI.botsSt.minus.press(); Menu.setupUI.botsSt.minus.press()
	r.check(int(G.settings.bots) == 3, "bots: 5 - 2 = 3", str(G.settings.bots))
	while int(G.settings.laps) > 1: Menu.setupUI.lapsSt.minus.press()
	r.check(Menu.setupUI.lapsSt.minus.disabled, "ronden: niet minder dan 1")
	r.check(Game.bots.size() == 3, "de bots staan klaar op de grid", str(Game.bots.size()))
	r.check(Menu.setupUI.modeNote.text == "Race van 1 ronde tegen 3 bots. Er rijdt geen ander verkeer.", "uitleg bij de modus", Menu.setupUI.modeNote.text)
	# Enter on a focused button presses that button (like a browser); elsewhere Enter is Volgende
	UiKit.focus(Menu.setupUI.nextBtn)
	key(KEY_ENTER)
	r.check(Menu.menuStep == 0, "Enter op Volgende: stap Kies je auto", str(Menu.menuStep))
	r.check(focused() == Menu.setupUI.classRadio.find("B"), "focus op de gekozen klasse")
	focused().release_focus()
	key(KEY_ENTER)
	r.check(Menu.menuStep == 1, "Enter zonder focus: volgende stap", str(Menu.menuStep))
	key(KEY_ESCAPE)
	var visCars: Array = Menu.setupUI.carCards.keys().filter(func(id): return Menu.setupUI.carCards[id].visible)
	r.check(visCars == ["hatch"], "alleen eigen auto's te kiezen", str(visCars))
	r.check(Menu.setupUI.classRadio.find("A").disabled, "klasse zonder eigen auto is uit")
	Menu.setupUI.colorRadio.find("#1d4f9e").press()
	r.check(G.settings.color == "#1d4f9e" and saved("polderrace3d-settings").get("color") == "#1d4f9e", "kleur gekozen en bewaard")
	Menu.menuNext()
	r.check(Menu.menuStep == 1, "stap Kies je baan")
	r.check((Menu.setupUI.nextBtn.get_meta("label") as Label).text == "Start race", "knop Start race", (Menu.setupUI.nextBtn.get_meta("label") as Label).text)
	Menu.menuCycle(1)
	r.check(G.settings.track == "dorp" and Trk.TRACK_ID == "dorp", "volgende baan (controller rechts)", Trk.TRACK_ID)
	Menu.menuCycle(-1)
	r.check(Trk.TRACK_ID == "polder", "en terug")
	key(KEY_ESCAPE)
	r.check(Menu.menuStep == 0, "Esc: een stap terug", str(Menu.menuStep))
	Menu.menuNext()
	var cr0: int = G.garage.credits
	Menu.menuNext()
	r.check(Game.state == "countdown" and not Menu.menuOv.visible and not Menu.home.visible, "race gestart, menu's weg", Game.state)
	race_to_end()
	r.check(Game.state == "over" and Menu.overOv.visible, "uitslag na de finish", Game.state)
	r.check(Menu.overUI.results.get_child_count() == 4, "uitslag met 4 rijders", str(Menu.overUI.results.get_child_count()))
	r.check(G.garage.credits > cr0 and Menu.overUI.earnTag.visible, "prijzengeld uitbetaald", "%d -> %d" % [cr0, G.garage.credits])
	r.check(Podium.inPodium and Podium.podiumCars.size() == 3 and Podium.podiumLabels.size() == 3, "podium met de eerste drie", str(Podium.podiumCars.size()))
	r.check(Menu.overHolder.left, "uitslag links naast het podium")
	var title: String = Menu.overUI.overTitle.text
	r.check(title == "Gewonnen!" or title.begins_with("Je werd "), "titel van de uitslag", title)
	Game.overReady = true
	Game.onAgain()
	r.check(Game.state == "countdown" and not Podium.inPodium and not Menu.overOv.visible, "Opnieuw racen", Game.state)
	Game.toMenu(-1)
	r.check(Menu.home.visible and Menu.homeView == "main" and Game.state == "menu", "naar het hoofdmenu")
	# ---- pause
	Menu.homeUI.hQuick.press()
	r.check(Game.state == "countdown", "Snel racen start meteen")
	L.step(5)
	Game.setPaused(true)
	r.check(Menu.pauseOv.visible and Menu.overUI.pauseSub.text.begins_with("Polder · ronde 1"), "pauze met waar je bent", Menu.overUI.pauseSub.text)
	Menu.overUI.pSettings.press()
	r.check(Menu.pauseSettingsOpen() and Menu.settingsUI.content.is_visible_in_tree(), "instellingen in de pauze")
	key(KEY_ESCAPE)
	r.check(not Menu.pauseSettingsOpen() and Game.paused, "Esc: terug naar de pauze")
	Menu.overUI.quitBtn.press()
	r.check(Game.state == "menu" and not Game.paused and Menu.home.visible, "Naar menu")
	# ---- garage: an upgrade and a car
	Menu.homeUI.hGarage.press()
	var c0: int = G.garage.credits
	var cost := G.upCost("hatch", G.UPG[0], 0)
	Menu.garageUI.first_buy().press()
	r.check(int(G.garage.cars.hatch.eng) == 1 and G.garage.credits == c0 - cost, "motor-upgrade gekocht", "%d, %d -> %d" % [int(G.garage.cars.hatch.eng), c0, G.garage.credits])
	r.check(int(saved("polderrace3d-garage").cars.hatch.eng) == 1, "upgrade bewaard")
	r.check(Menu.isTuned("hatch"), "auto is nu getuned")
	G.garage.credits += 3000
	Menu.garageUI.carRadio.find("mini").press()
	r.check(G.settings.car == "mini" and not Career.owns("mini"), "garage: niet-gekochte auto bekijken")
	var c1: int = G.garage.credits
	Menu.garageUI.first_buy().press()
	r.check(Career.owns("mini") and G.garage.credits == c1 - Career.CAR_PRICE.mini, "Cityflitser gekocht", str(G.garage.credits))
	r.check(saved("polderrace3d-garage").owned.has("mini"), "aankoop bewaard")
	Menu.garageUI.carRadio.find("rally").press()
	Menu.homeBack()
	r.check(G.settings.car == "mini", "Terug: weer in een eigen auto", G.settings.car)
	Menu.homePanel("garage")
	Menu.garageUI.garTab("look")
	Menu.garageUI.rimRadio.find("gold").press()
	r.check(G.carUp("mini").rim == "gold", "velgen goud")
	Menu.homePanel("main")
	# ---- championship: one round, standings, next round
	Menu.homeUI.hPlay.press()
	Menu.homeUI.hChamp.press()
	r.check(Menu.menuFlow == "champ" and Menu.menuStep == 0, "kampioenschap: eerst de auto", str(Menu.menuStep))
	Menu.menuNext()
	r.check(Menu.menuStep == 3 and Menu.setupUI.rounds.get_child_count() >= 6, "kampioenschap: de rondes")
	Menu.menuNext()
	r.check(Game.mode == "champ" and Champ.champ != null and Champ.champ.active and Game.state == "countdown", "kampioenschap gestart", Game.mode)
	r.check(Game.bots.size() == 5 and Game.raceLaps == 2, "5 vaste tegenstanders, 2 ronden", "%d bots, %d ronden" % [Game.bots.size(), Game.raceLaps])
	quick_finish()
	r.check(Game.state == "over" and int(Champ.champ.round) == 1, "ronde 1 gereden", str(Champ.champ.round))
	r.check(Champ.champ.pts.values().reduce(func(a, b): return a + b, 0) == 10 + 8 + 6 + 5 + 4 + 3, "punten verdeeld", str(Champ.champ.pts))
	r.check((Menu.overUI.againBtn.get_meta("label") as Label).text == "Tussenstand", "knop Tussenstand")
	Game.overReady = true
	Game.onAgain()
	r.check(Game.overView == "standings" and Menu.overUI.overTitle.text == "Tussenstand na race 1 van 6", "tussenstand", Menu.overUI.overTitle.text)
	r.check((Menu.overUI.againBtn.get_meta("label") as Label).text == "Volgende race: Dorp", "volgende race: Dorp")
	Game.onAgain()
	r.check(Game.state == "countdown" and Trk.TRACK_ID == "dorp" and Env.me.time == "dusk", "ronde 2 in het dorp, 's avonds", "%s %s" % [Trk.TRACK_ID, Env.me.time])
	Game.toMenu(-1)
	var qc = Champ.loadQuickChamp()
	r.check(qc != null and int(qc.round) == 1 and Champ.champInProgress(), "kampioenschap bewaard, ronde 2 volgt")
	r.check(Menu.homeUI.hResume.visible and Menu.homeUI.playTitle.text == "Kampioenschap", "hoofdscherm: Verder racen")
	# ---- career: the first event
	Menu.homePanel("career")
	r.check(Menu.careerSel == "b1" and not Menu.careerUI.careerGo.disabled, "carrière: Proefrit klaar om te starten", str(Menu.careerSel))
	var prevMode: String = G.settings.mode
	Menu.careerUI.careerGo.press()
	r.check(G.careerEv != null and G.careerEv.ev.id == "b1" and Game.bots.size() == 3 and Game.raceLaps == 2, "carrière-race gestart", str(Game.bots.size()))
	r.check(Game.bots.any(func(b): return b.name == "Daan" and b.rival), "rivaal Daan rijdt mee")
	var c2: int = G.garage.credits
	quick_finish()
	var res = G.careerEv.res
	var pos := 0
	for k in Game.resultRows.size():
		if Game.resultRows[k].get("me", false): pos = k + 1
	r.check(res != null and res.passed == (pos <= 3), "resultaat van het evenement", "plek %d, gehaald %s" % [pos, res.passed if res else "-"])
	r.check(int(G.garage.career.cups.b1.best) == pos, "beste plek bewaard", str(G.garage.career.cups.b1))
	r.check(Menu.overUI.storyBox.visible and Menu.overUI.storyBox.get_child(0).get_child_count() >= 1, "verhaal onder de uitslag")
	var prize: int = Career.evById("b1").prize[pos - 1] if pos <= 3 else 0
	r.check(G.garage.credits >= c2 + prize, "prijzengeld van het evenement", "%d -> %d" % [c2, G.garage.credits])
	Game.overReady = true
	Game.toCareerOr(-1)
	r.check(Menu.homeView == "career" and G.careerEv == null and G.settings.mode == prevMode, "terug naar de carrière, eigen instellingen terug", G.settings.mode)
	if pos <= 3: r.check(Menu.careerSel == "b2", "volgend evenement gekozen", str(Menu.careerSel))
	Menu.homePanel("main")
	# ---- achievements
	var c3: int = G.garage.credits
	Ach.unlockAch("tt5")
	r.check(Ach.got("tt5") and G.garage.credits == c3 + 400 and Menu.achPop.visible, "prestatie Lange adem: + € 400 en melding")
	r.check(saved("polderrace3d-garage").ach.has("tt5"), "prestatie bewaard")
	Ach.unlockAch("tt5")
	r.check(G.garage.credits == c3 + 400, "een prestatie telt maar één keer")
	# ---- settings and a key binding
	Menu.homePanel("settings")
	var snd: bool = G.prefs.sound
	Menu.settingsUI.togs.sound.press()
	r.check(G.prefs.sound == not snd and Sfx.muted == snd and saved("polderrace3d-prefs").sound == (not snd), "geluid uit/aan en bewaard")
	Menu.settingsUI.qualRadio.find("low").press()
	r.check(G.prefs.quality == "low" and not Env.me.sun.shadow_enabled, "kwaliteit laag: geen schaduwen")
	Menu.settingsUI.qualRadio.find("high").press()
	Menu.settingsUI.showTab("keys")
	var bb: UiKit.Btn = Menu._buttons(Menu.settingsUI.bindList)[0]
	bb.press()
	r.check(Menu.bindCapture.is_valid(), "toets wijzigen: wacht op een toets")
	key(KEY_I)
	r.check(Game.binds.p1.up == ["KeyI"], "gas op I", str(Game.binds.p1.up))
	r.check(saved("polderrace3d-binds").p1.up == ["KeyI"], "toetsen bewaard")
	Menu._buttons(Menu.settingsUI.bindList)[0].press()
	key(KEY_ESCAPE)
	r.check(Game.binds.p1.up == ["KeyI"] and not Menu.bindCapture.is_valid(), "Esc: niets gewijzigd")
	Menu.settingsUI.bindP1.get_parent().get_parent().get_child(1).press()
	r.check(Game.binds.p1.up == ["KeyW", "ArrowUp"], "standaard herstellen", str(Game.binds.p1.up))
	Menu.homeBack()
	Game.set_process(true)
	Game.set_process_input(true)
	return r

extends RefCounted
## A playthrough of the real game scene with real input (tests/play_driver.gd): a new player (only the hot hatch) and a
## player with everything, the home screen and its panels, the race setup step by step with keys and clicks, a race to
## the finish, results and podium, again, pause (with the settings inside), every mode, a whole championship, split
## screen, the career, the garage, settings (key binding), the keys during a race (M, R, V, C, E/Q, F11), the replay
## viewer, and window sizes from 1024x600 to 2560x1440. Checks what the screen shows, what is saved, and that the
## engine logs no errors on the way.
## Only some parts: PLAY_ONLY=home,race python godot/tests/run.py play. With screenshots (OpenGL in xvfb, slower):
## PLAY_SHOTS=/abs/dir PLAY_ONLY=home,garage xvfb-run -a -s "-screen 0 2560x1440x24" godot --path godot --rendering-driver opengl3 \
##   res://tests/runner.tscn -- play

var D
var r: TestReport

func run(host: Node) -> TestReport:
	r = TestReport.new("doorspelen met echte invoer (toetsen, muis)")
	D = load("res://tests/play_driver.gd").new(host.get_tree(), r)
	var only := OS.get_environment("PLAY_ONLY")
	var parts := ["home", "setup", "race", "pause", "modes", "replay", "keys", "split", "garage", "settings", "career", "champ", "sizes", "pad", "rich"]
	await D.boot("user://test-play.json", {"polderrace3d-garage": {"owned": {"hatch": true}}})
	D.check_errors("opstarten")
	for p in parts:
		if only != "" and not p in only.split(","): continue
		print("-- deel: ", p)
		var t0 := Time.get_ticks_msec()
		Engine.time_scale = 1.0
		await call("part_" + p)
		D.release_all()
		D.check_errors(p)
		print("   (%.0f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	Engine.time_scale = 1.0
	D.done()
	return r

# ------------------------------------------------------------------ home screen, new player
func part_home() -> void:
	r.check(G.settings.car == "hatch" and Game.car != null, "nieuwe speler: in de hot hatch", G.settings.car)
	r.check(Menu.home.visible and Menu.homeView == "main", "hoofdscherm open")
	r.check(D.focused() == Menu.homeUI.hPlay, "Spelen heeft de focus", str(D.focused()))
	await D.shot("home_new")
	await D.tap(KEY_RIGHT)
	r.check(D.focused() == Menu.homeUI.hGarage, "pijl rechts: Garage", D._name_of(D.focused()))
	await D.tap(KEY_LEFT)
	await D.tap(KEY_ENTER)
	r.check(Menu.homeView == "play", "Enter op Spelen: paneel Spelen", Menu.homeView)
	await D.tap(KEY_ESCAPE)
	r.check(Menu.homeView == "main", "Esc: terug", Menu.homeView)
	# every tile with the mouse, and back with the Terug button
	for t in [["hRecords", "records"], ["hSettings", "settings"], ["hAch", "ach"], ["hGarage", "garage"], ["hPlay", "play"]]:
		if not await D.click(Menu.homeUI.get(t[0]), t[1]): continue
		r.check(Menu.homeView == t[1] and Menu.panels[t[1]].content.visible, "tegel %s: paneel open" % t[1], Menu.homeView)
		var back = D.find_btn(Menu.panels[t[1]].nav, "Terug")
		if back == null: back = D.find_btn(Menu.panels[t[1]].nav, "Hoofdmenu")
		if await D.click(back, "Terug in " + t[1]):
			r.check(Menu.homeView == "main", "Terug uit %s: hoofdscherm" % t[1], Menu.homeView)
	await D.click(Menu.homeUI.hPlay, "Spelen")
	await D.click(Menu.homeUI.hCareer, "Carrière")
	r.check(Menu.homeView == "career", "carrière open", Menu.homeView)
	await D.tap(KEY_BACKSPACE)
	r.check(Menu.homeView == "play", "Backspace: terug naar Spelen", Menu.homeView)
	await D.tap(KEY_BACKSPACE)
	r.check(Menu.homeView == "main", "Backspace: hoofdscherm", Menu.homeView)
	# M in the menu: sound off and on, saved, the switch in the settings follows
	var m0 := Sfx.muted
	await D.tap(KEY_M)
	r.check(Sfx.muted != m0 and JSON.parse_string(str(G.store_get("polderrace3d-prefs"))).sound == (not Sfx.muted), "M in het menu: geluid uit, bewaard", str(Sfx.muted))
	r.check(Menu.settingsUI.togs.sound.checked == (not Sfx.muted), "schakelaar Geluid volgt")
	await D.tap(KEY_M)
	r.check(Sfx.muted == m0, "M: geluid weer aan")

# ------------------------------------------------------------------ race setup with keys and clicks
func part_setup() -> void:
	await D.click(Menu.homeUI.hPlay, "Spelen")
	await D.click(Menu.homeUI.hStart, "Race")
	r.check(Menu.menuOv.visible and Menu.menuStep == 2, "Race: stap Spelmodus", str(Menu.menuStep))
	var S := G.settings
	await D.click(Menu.setupUI.modeRadio.find("race"), "modus Race")
	r.check(S.mode == "race", "modus race")
	while int(S.bots) > 2:
		if not await D.click(Menu.setupUI.botsSt.minus, "bots min"): break
	while int(S.laps) > 1:
		if not await D.click(Menu.setupUI.lapsSt.minus, "ronden min"): break
	r.check(int(S.bots) == 2 and int(S.laps) == 1, "2 bots, 1 ronde", "%d bots, %d ronden" % [int(S.bots), int(S.laps)])
	r.check(Game.bots.size() == 2, "2 bots op de grid", str(Game.bots.size()))
	await D.click(Menu.setupUI.nextBtn, "Volgende")
	r.check(Menu.menuStep == 0, "stap Kies je auto", str(Menu.menuStep))
	await D.click(Menu.setupUI.colorRadio.find("#1d4f9e"), "kleur blauw")
	r.check(S.color == "#1d4f9e", "kleur gekozen", S.color)
	await D.tap(KEY_ESCAPE)
	r.check(Menu.menuStep == 2, "Esc: terug naar de modus", str(Menu.menuStep))
	r.check(D.focused() == Menu.setupUI.modeRadio.find("race"), "focus op de gekozen modus", D._name_of(D.focused()))
	await D.tap(KEY_ENTER)
	r.check(Menu.menuStep == 2, "Enter op een keuze: die keuze (zoals de browser)", str(Menu.menuStep))
	D.focused().release_focus()
	await D.tap(KEY_ENTER)
	r.check(Menu.menuStep == 0, "Enter zonder focus: volgende stap", str(Menu.menuStep))
	await D.click(Menu.setupUI.nextBtn, "Volgende")
	r.check(Menu.menuStep == 1, "stap Kies je baan", str(Menu.menuStep))
	await D.shot("setup_track")
	await D.click(Menu.setupUI.trackRadio.find("dorp"), "baan Dorp")
	r.check(Trk.TRACK_ID == "dorp" and S.track == "dorp", "baan Dorp geladen", Trk.TRACK_ID)
	await D.click(Menu.setupUI.trackRadio.find("polder"), "baan Polder")
	r.check(Trk.TRACK_ID == "polder", "terug naar Polder", Trk.TRACK_ID)
	await D.click(Menu.setupUI.dirRadio.find("rev"), "Omgekeerd")
	r.check(Trk.TRACK_DIR == "rev" and S.dir == "rev" and Menu.setupUI.tiName.text.ends_with("omgekeerd"), "richting omgekeerd: baan opnieuw geladen", Trk.TRACK_DIR)
	await D.click(Menu.setupUI.dirRadio.find("fwd"), "Normaal")
	r.check(Trk.TRACK_DIR == "fwd", "richting normaal", Trk.TRACK_DIR)
	await D.click(Menu.setupUI.weatherRadio.find("rain"), "Regen")
	await D.click(Menu.setupUI.timeRadio.find("night"), "Nacht")
	r.check(Env.me.weather == "rain" and Env.me.time == "night" and S.weather == "rain" and S.time == "night", "nacht en regen", "%s %s" % [Env.me.time, Env.me.weather])
	await D.shot("setup_night_rain")
	await D.click(Menu.setupUI.weatherRadio.find("dry"), "Droog")
	await D.click(Menu.setupUI.timeRadio.find("day"), "Dag")
	r.check(Env.me.weather == "dry" and Env.me.time == "day", "dag en droog")
	await D.tap(KEY_BACKSPACE)
	await D.tap(KEY_BACKSPACE)
	r.check(Menu.menuStep == 2, "twee keer terug: modus", str(Menu.menuStep))
	await D.tap(KEY_BACKSPACE)
	r.check(Menu.menuStep < 0 and Menu.homeView == "play", "nog eens: paneel Spelen", "%d %s" % [Menu.menuStep, Menu.homeView])
	r.check(D.focused() == Menu.homeUI.hStart, "focus op Race", D._name_of(D.focused()))

# ------------------------------------------------------------------ a race to the finish, results, again
func part_race() -> void:
	if Menu.homeView != "play":
		await D.click(Menu.homeUI.hPlay, "Spelen")
	await D.tap(KEY_ENTER)      # focus on Race
	r.check(Menu.menuStep == 2, "Enter op Race: modus", str(Menu.menuStep))
	await D.click(Menu.setupUI.nextBtn, "Volgende")
	await D.click(Menu.setupUI.nextBtn, "Volgende")
	r.check(Menu.menuStep == 1, "Volgende, Volgende: baan", str(Menu.menuStep))
	await D.click(Menu.setupUI.nextBtn, "Start race")
	r.check(Game.state == "countdown" and not Menu.menuOv.visible and Hud.hud.visible, "race gestart", Game.state)
	r.check(Game.bots.size() == int(G.settings.bots) and Game.raceLaps == int(G.settings.laps), "bots en ronden zoals gekozen", "%d bots, %d ronden" % [Game.bots.size(), Game.raceLaps])
	Engine.time_scale = 3.0
	var ok: bool = await D.drive_until(func(): return Game.state == "over", 120)
	r.check(ok, "race uitgereden met de toetsen", "state %s, ronde %d, %d keer R" % [Game.state, Game.player.lap, D.resets])
	Engine.time_scale = 1.0
	await D.until(func(): return Game.overReady, 3)
	r.check(Menu.overOv.visible and Menu.overUI.results.get_child_count() == int(G.settings.bots) + 1, "uitslag", str(Menu.overUI.results.get_child_count()))
	r.check(Podium.inPodium, "podium")
	await D.shot("results")
	await D.tap(KEY_ENTER)
	r.check(Game.state == "countdown" and not Podium.inPodium and not Menu.overOv.visible, "Enter: opnieuw racen", Game.state)

func part_pause() -> void:
	if Game.state == "menu":
		if Menu.homeView != "play": await D.click(Menu.homeUI.hPlay, "Spelen")
		await D.click(Menu.homeUI.hQuick, "Snel racen")
	await D.wait(4.5)
	await D.tap(KEY_ESCAPE)
	r.check(Game.paused and Menu.pauseOv.visible, "Esc: pauze", str(Game.paused))
	await D.tap(KEY_TAB)
	r.check(D.focused() != null and Menu.pauseOv.is_ancestor_of(D.focused()), "Tab: focus in het pauzescherm", D._name_of(D.focused()))
	await D.shot("pause")
	await D.click(Menu.overUI.pSettings, "Instellingen")
	r.check(Menu.pauseSettingsOpen(), "instellingen in de pauze")
	await D.tap(KEY_ESCAPE)
	r.check(Game.paused and not Menu.pauseSettingsOpen(), "Esc: terug in de pauze")
	await D.tap(KEY_P)
	r.check(not Game.paused, "P: verder")
	await D.tap(KEY_P)
	r.check(Game.paused, "P: weer pauze")
	await D.click(Menu.overUI.quitBtn, "Naar menu")
	r.check(Game.state == "menu" and Menu.home.visible and not Game.paused, "naar het hoofdmenu", Game.state)

# ------------------------------------------------------------------ helpers: a race set up through the menus
## Spelen -> Race -> mode, bots, laps (stepper clicks) -> Volgende -> Volgende -> (track) -> Start race
func setup_race(mode: String, bots := -1, laps := -1, track := "") -> void:
	if Game.state != "menu":
		r.check(false, "setup_race vanuit het menu", Game.state)
		return
	if Menu.menuStep >= 0:
		while Menu.menuStep >= 0: await D.tap(KEY_ESCAPE)
	if Menu.homeView != "play":
		if Menu.homeView != "main": await D.click(D.find_btn(Menu.panels[Menu.homeView].nav, "Terug"), "Terug")
		await D.click(Menu.homeUI.hPlay, "Spelen")
	await D.click(Menu.homeUI.hStart, "Race")
	await D.click(Menu.setupUI.modeRadio.find(mode), "modus " + mode)
	var S := G.settings
	if bots >= 0:
		while int(S.bots) > bots and not Menu.setupUI.botsSt.minus.disabled:
			if not await D.click(Menu.setupUI.botsSt.minus, "bots min"): break
		while int(S.bots) < bots and not Menu.setupUI.botsSt.plus.disabled:
			if not await D.click(Menu.setupUI.botsSt.plus, "bots plus"): break
	if laps >= 0:
		while int(S.laps) > laps and not Menu.setupUI.lapsSt.minus.disabled:
			if not await D.click(Menu.setupUI.lapsSt.minus, "ronden min"): break
		while int(S.laps) < laps and not Menu.setupUI.lapsSt.plus.disabled:
			if not await D.click(Menu.setupUI.lapsSt.plus, "ronden plus"): break
	await D.click(Menu.setupUI.nextBtn, "Volgende (naar auto)")
	await D.click(Menu.setupUI.nextBtn, "Volgende (naar baan)")
	if track != "" and Trk.TRACK_ID != track:
		await D.click(Menu.setupUI.trackRadio.find(track), "baan " + track)
		await D.frames(3)
	await D.click(Menu.setupUI.nextBtn, "Start race")
	r.check(Game.state == "countdown", "%s gestart vanuit het menu" % mode, Game.state)

## drive (keys) until the results are up, at speed
func race_to_results(max_s := 150.0, p2 := false) -> bool:
	Engine.time_scale = 4.0
	var ok: bool = await D.drive_until(func(): return Game.state == "over", max_s, p2)
	Engine.time_scale = 1.0
	await D.until(func(): return Game.overReady and Menu.overOv.visible, 3)
	return r.check(ok and Menu.overOv.visible, "uitgereden tot de uitslag (%s)" % Game.mode, "state %s, ronde %d" % [Game.state, Game.player.lap])

func to_menu_from_results() -> void:
	await D.click(Menu.overUI.menuBtn, "Hoofdmenu")
	r.check(Game.state == "menu" and Menu.home.visible and Menu.homeView == "main", "uitslag -> hoofdmenu", "%s %s" % [Game.state, Menu.homeView])
	r.check(not Podium.inPodium and not Hud.hud.visible, "podium en HUD weg in het menu")

func audio_quiet(where: String) -> void:
	await D.wait(1.0)
	r.check(Sfx.engGain < 0.005 and Sfx.windGain < 0.005 and Sfx.squealGain < 0.005, "geen motorgeluid in " + where, "motor %.3f wind %.3f" % [Sfx.engGain, Sfx.windGain])

# ------------------------------------------------------------------ every mode
func part_modes() -> void:
	# elimination: 2 bots, 2 laps, someone drops out each lap
	await setup_race("elim", 2)
	r.check(Game.mode == "elim" and Game.bots.size() == 2 and Game.raceLaps == 2 and Game.traffic.is_empty(), "eliminatie: 2 bots, 2 ronden, geen verkeer", "%d bots %d ronden %d verkeer" % [Game.bots.size(), Game.raceLaps, Game.traffic.size()])
	if await race_to_results(200):
		var t: String = Menu.overUI.overTitle.text
		r.check(t == "Gewonnen!" or t.begins_with("Uitgeschakeld") or t.begins_with("Je werd"), "eliminatie: titel", t)
		r.check(Game.bots.any(func(b): return b.out) or Game.playerOut, "eliminatie: iemand ligt eruit")
	await to_menu_from_results()
	await audio_quiet("het menu")
	# time trial: no bots, traffic; drive a bit, then stop: the time runs out
	await setup_race("time")
	r.check(Game.mode == "time" and Game.bots.is_empty() and Game.traffic.size() == int(Trk.TRK.get("traffic", 0)), "tijdrit: geen bots, wel verkeer", "%d bots %d verkeer" % [Game.bots.size(), Game.traffic.size()])
	Engine.time_scale = 4.0
	var c0: float = Game.clock
	await D.drive_until(func(): return Game.clock - c0 > 10.0, 20)
	Engine.time_scale = 6.0
	var ok: bool = await D.until_game(func(): return Game.state == "over", 120)
	Engine.time_scale = 1.0
	await D.until(func(): return Game.overReady, 3)
	r.check(ok and Menu.overOv.visible and Menu.overUI.overTitle.text == "Tijd is op" and Menu.overUI.stats.visible and not Menu.overUI.results.visible, "tijdrit: Tijd is op", Menu.overUI.overTitle.text)
	r.check(not Podium.inPodium, "tijdrit: geen podium")
	await D.shot("timetrial_over")
	await D.click(Menu.overUI.againBtn, "Opnieuw racen")
	r.check(Game.state == "countdown" and Game.mode == "time" and Game.timeLeft == float(Trk.TRK.startTime), "tijdrit opnieuw: tijd weer vol", str(Game.timeLeft))
	await D.wait(1.0)
	await D.tap(KEY_ESCAPE)
	await D.click(Menu.overUI.quitBtn, "Naar menu")
	r.check(Game.state == "menu" and Game.traffic.is_empty(), "menu: verkeer weg", str(Game.traffic.size()))
	# ghost: one lap saves a ghost, the next race drives against it
	G.store_set(Rep.ghostKey("polder", Cars.CARS[G.settings.car].cls), "null")
	await setup_race("ghost", -1, 1, "polder")
	r.check(Game.mode == "ghost" and Game.bots.is_empty() and Game.traffic.is_empty(), "ghost: alleen op de baan")
	if await race_to_results(120):
		r.check(Menu.overUI.overTitle.text == "Ghost-tijdrit klaar" and Menu.overUI.recordTag.visible, "ghost: klaar, ghost opgeslagen", Menu.overUI.overTitle.text)
	await D.click(Menu.overUI.againBtn, "Opnieuw racen")
	await D.drive_until(func(): return Game.player.lap >= 1 and Game.raceTime - Game.lapStart > 2, 20)
	await D.frames(2)
	r.check(Rep.ghostCar != null and Rep.ghostCar.g.visible, "ghost rijdt mee in de volgende race")
	await D.tap(KEY_ESCAPE)
	await D.click(Menu.overUI.quitBtn, "Naar menu")
	r.check(Rep.ghostCar == null or not Rep.ghostCar.g.visible, "ghost weg in het menu")
	# a race after the ghost: bots back, no ghost
	await setup_race("race", 1, 1)
	r.check(Game.bots.size() == 1 and (Rep.ghostCar == null or not Rep.ghostCar.g.visible), "race na ghost: 1 bot, geen ghost")
	await D.tap(KEY_ESCAPE)
	await D.click(Menu.overUI.quitBtn, "Naar menu")
	# what these races left behind: a lap record and a time trial distance in Records, the ghost achievement
	await D.click(Menu.homeUI.hRecords, "Records")
	var txt: String = D._all_text(Menu.homeUI.recList)
	r.check(G.store_get(Game.lapKey("polder", "B")) != null and G.fmtLap(float(G.store_get(Game.lapKey("polder", "B")))) in txt, "records: ronderecord Polder klasse B", str(G.store_get(Game.lapKey("polder", "B"))))
	r.check("TIJDRIT" in txt.to_upper() and G.store_get(Game.bestKey("polder", "B")) != null, "records: tijdrit-afstand", str(G.store_get(Game.bestKey("polder", "B"))))
	await D.tap(KEY_ESCAPE)
	r.check(Ach.got("ghost") and Menu.homeUI.achHomeInfo.text != "0 van 21 behaald", "prestatie Ghost behaald, tegel telt mee", Menu.homeUI.achHomeInfo.text)
	await D.click(Menu.homeUI.hAch, "Prestaties")
	await D.shot("achievements")
	await D.tap(KEY_ESCAPE)

# ------------------------------------------------------------------ replay viewer
func part_replay() -> void:
	await setup_race("race", 1, 1)
	if not await race_to_results(): return
	if not await D.click(Menu.overUI.replayBtn, "Bekijk replay"): return
	r.check(Game.state == "replay" and Rep.bar.visible and not Menu.overOv.visible and not Podium.inPodium, "replay open", Game.state)
	await D.wait(1.0)
	var t0: float = Rep.rp.t
	await D.wait(0.5)
	r.check(Rep.rp.t > t0, "replay speelt", "%.2f -> %.2f" % [t0, Rep.rp.t])
	await D.shot("replay")
	var cm: int = Rep.rp.camMode
	await D.click(D.find_btn(Rep.bar, "Camera"), "Camera")
	r.check(Rep.rp.camMode == (cm + 1) % 3, "replay: andere camera", str(Rep.rp.camMode))
	await D.click(Rep.next_btn, "volgende auto")
	r.check(Rep.rp.target == 1, "replay: volgende auto", str(Rep.rp.target))
	await D.click(Rep.prev_btn, "vorige auto")
	r.check(Rep.rp.target == 0, "replay: vorige auto", str(Rep.rp.target))
	var before := DirAccess.get_files_at("user://replays") if DirAccess.dir_exists_absolute("user://replays") else PackedStringArray()
	await D.click(D.find_btn(Rep.bar, "Opslaan"), "Opslaan")
	var after := DirAccess.get_files_at("user://replays")
	r.check(after.size() == before.size() + 1 and Hud.toast.visible, "replay opgeslagen", str(after.size()))
	for f in after:
		if not before.has(f): DirAccess.remove_absolute("user://replays/" + f)
	await D.tap(KEY_ESCAPE)
	r.check(Game.state == "over" and Menu.overOv.visible and not Rep.bar.visible and Podium.inPodium, "Esc: terug naar de uitslag met podium", Game.state)
	await D.until(func(): return D.focused() == Menu.overUI.againBtn, 1)
	r.check(D.focused() == Menu.overUI.againBtn, "focus op Opnieuw racen", D._name_of(D.focused()))
	await D.click(Menu.overUI.replayBtn, "Bekijk replay")
	await D.click(D.find_btn(Rep.bar, "Terug naar uitslag"), "Terug naar uitslag")
	r.check(Game.state == "over" and Menu.overOv.visible, "knop: terug naar de uitslag")
	await to_menu_from_results()
	r.check(not Rep.bar.visible, "replaybalk weg")

# ------------------------------------------------------------------ keys during a race
func part_keys() -> void:
	await setup_race("race", 1, 2)
	await D.wait(5.0)
	r.check(Game.state == "racing", "race loopt", Game.state)
	var m0 := Sfx.muted
	await D.tap(KEY_M)
	r.check(Sfx.muted != m0, "M: geluid uit", str(Sfx.muted))
	await D.tap(KEY_M)
	r.check(Sfx.muted == m0, "M: geluid weer aan")
	var cam0 := int(G.prefs.cam)
	await D.tap(KEY_V)
	r.check(int(G.prefs.cam) == (cam0 + 1) % 3 and Hud.toast.visible, "V: andere camera", str(G.prefs.cam))
	await D.tap(KEY_V)
	await D.tap(KEY_V)
	r.check(int(G.prefs.cam) == cam0, "V V: weer de eerste camera")
	# drive a bit, then C looks back
	D.hold(KEY_W, true)
	await D.wait(2.0)
	D.hold(KEY_C, true)
	await D.frames(3)
	var fwd := Vector3(sin(Game.player.heading), 0, cos(Game.player.heading))
	var look := -Game.camera.global_transform.basis.z
	r.check(look.dot(fwd) < -0.5, "C: achterom kijken", "%.2f" % look.dot(fwd))
	D.hold(KEY_C, false)
	await D.frames(3)
	look = -Game.camera.global_transform.basis.z
	r.check(look.dot(Vector3(sin(Game.player.heading), 0, cos(Game.player.heading))) > 0.5, "C los: weer vooruit")
	D.hold(KEY_W, false)
	# R puts you back on the track
	Game.player.lat = Trk.ROAD_HALF + 1.0
	await D.wait(2.2)
	await D.tap(KEY_R)
	r.check(absf(Game.player.lat) < Trk.ROAD_HALF, "R: terug op de baan", "lat %.1f" % Game.player.lat)
	# space is the handbrake (not "resume")
	D.hold(KEY_W, true)
	D.hold(KEY_SPACE, true)
	await D.frames(5)
	r.check(Game.player.hand or absf(Game.player.speed) <= 3, "spatie: handrem", str(Game.player.hand))
	D.hold(KEY_SPACE, false)
	D.hold(KEY_W, false)
	# F11: full screen and back (saved); without a display the window has no modes, only the saved choice is checked
	await D.tap(KEY_F11)
	r.check(G.store_get("polderrace3d-window") == "full", "F11: volledig scherm bewaard", str(G.store_get("polderrace3d-window")))
	if DisplayServer.get_name() != "headless":
		await D.frames(10)
		r.check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "F11: volledig scherm")
		await D.tap(KEY_F11)
		await D.frames(10)
		r.check(G.store_get("polderrace3d-window") == "win" and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN, "F11: weer venster", str(G.store_get("polderrace3d-window")))
	G.store_set("polderrace3d-window", "win")
	r.check(not Game.paused, "F11 pauzeert niet")
	# resize during the race: the HUD stays in the window
	for sz in [Vector2i(1024, 600), Vector2i(1920, 1080), Vector2i(1280, 720)]:
		await D.resize(sz.x, sz.y)
		await D.frames(3)
		var vr := Rect2(Vector2.ZERO, Vector2(sz))
		r.check(vr.encloses(Hud.gauge.get_global_rect()) and vr.encloses(Hud.map_sign.get_global_rect()) and vr.encloses(Hud.time_sign.get_global_rect()), "HUD in beeld na vergroten/verkleinen tot %dx%d" % [sz.x, sz.y], "meter %s" % Hud.gauge.get_global_rect())
	# the HUD pause button
	if await D.click(Hud.topbtns.get_child(0), "pauzeknop"):
		r.check(Game.paused, "pauzeknop: pauze")
		await D.click(Menu.overUI.resumeBtn, "Verder")
		r.check(not Game.paused, "Verder: race loopt door")
	# manual gearbox: E and Q
	G.prefs.gearbox = "manual"
	D.hold(KEY_W, true)
	await D.wait(1.0)
	var g0: int = Game.player.gear
	await D.tap(KEY_E)
	r.check(Game.player.gear == g0 + 1, "E: opschakelen", "%d -> %d" % [g0, Game.player.gear])
	D.hold(KEY_W, false)
	await D.wait(0.5)     # the shift takes a moment (SHIFT per class)
	await D.tap(KEY_Q)
	r.check(Game.player.gear == g0, "Q: terugschakelen", str(Game.player.gear))
	D.hold(KEY_W, false)
	G.prefs.gearbox = "auto"
	await D.tap(KEY_ESCAPE)
	await D.click(Menu.overUI.restartBtn, "Opnieuw starten")
	r.check(Game.state == "countdown" and not Game.paused and Game.player.lap == 0 and Game.raceTime == 0.0, "Opnieuw starten vanuit de pauze", Game.state)
	await D.tap(KEY_ESCAPE)
	await D.click(Menu.overUI.quitBtn, "Naar menu")
	await audio_quiet("het menu na de pauze")

# ------------------------------------------------------------------ split screen from the menu
func part_split() -> void:
	await D.click(Menu.homeUI.hPlay, "Spelen")
	await D.click(Menu.homeUI.hStart, "Race")
	await D.click(Menu.setupUI.modeRadio.find("split"), "modus 2 spelers")
	var S := G.settings
	while int(S.bots) > 1: if not await D.click(Menu.setupUI.botsSt.minus, "bots min"): break
	while int(S.laps) > 1: if not await D.click(Menu.setupUI.lapsSt.minus, "ronden min"): break
	await D.click(Menu.setupUI.nextBtn, "Volgende")
	r.check(Menu.setupUI.pTabs.visible, "auto kiezen: tabs Speler 1 en Speler 2")
	await D.click(Menu.setupUI.pTab2, "Speler 2")
	r.check(Menu.editP == 2, "speler 2 kiest", str(Menu.editP))
	await D.click(Menu.setupUI.colorRadio.find("#2f8f5b"), "kleur speler 2")
	r.check(S.p2color == "#2f8f5b" and S.color != "#2f8f5b", "kleur van speler 2 apart", "%s / %s" % [S.color, S.p2color])
	await D.shot("setup_split_p2")
	await D.click(Menu.setupUI.pTab1, "Speler 1")
	r.check(Menu.editP == 1 and Game.car != null, "terug naar speler 1")
	await D.click(Menu.setupUI.nextBtn, "Volgende")
	await D.click(Menu.setupUI.nextBtn, "Start race")
	r.check(Game.split and Game.p2 != null and SplitView.me.active(), "2 spelers: gestart, scherm in tweeën", str(Game.split))
	r.check(Game.bots.size() == 1, "2 spelers: 1 bot", str(Game.bots.size()))
	await D.wait(4.6)
	D.hold(KEY_UP, true)
	await D.wait(1.5)
	D.hold(KEY_UP, false)
	r.check(Game.p2.pl.speed > 3 and absf(Game.player.speed) < 2, "pijl omhoog: alleen speler 2 rijdt", "p1 %.1f, p2 %.1f" % [Game.player.speed, Game.p2.pl.speed])
	await D.shot("split_race")
	if await race_to_results(200, true):
		r.check(Menu.overUI.overTitle.text.ends_with("is de snelste speler!"), "2 spelers: uitslag", Menu.overUI.overTitle.text)
		r.check(not Podium.inPodium, "2 spelers: geen podium")
	await to_menu_from_results()
	r.check(not Game.split and Game.p2 == null and not SplitView.me.active() and not SplitView.me.hud2.visible and not SplitView.me.img1.visible, "2 spelers: helemaal opgeruimd")
	r.check(Game.camera.cull_mask != 0, "hoofdcamera tekent weer")
	# the next quick race is a race of one again
	await setup_race("race", 1, 1)
	r.check(not Game.split and Game.p2 == null and Hud.hud.visible and not SplitView.me.hud2.visible, "race na 2 spelers: één speler")
	await D.tap(KEY_ESCAPE)
	await D.click(Menu.overUI.quitBtn, "Naar menu")

# ------------------------------------------------------------------ garage: upgrade, car, looks, start number
func part_garage() -> void:
	G.garage.credits = maxi(int(G.garage.credits), 2500)
	G.saveGarage()
	await D.click(Menu.homeUI.hGarage, "Garage")
	r.check(GarageRoom.inGarage and Menu.homeView == "garage", "garage open")
	await D.shot("garage")
	var car: String = G.settings.car
	var c0: int = G.garage.credits
	var lvl0 := int(G.carUp(car).get("eng", 0))
	var buy = Menu.garageUI.first_buy()
	await D.click(buy, "motor-upgrade")
	r.check(int(G.carUp(car).eng) == lvl0 + 1 and G.garage.credits < c0, "upgrade gekocht", "%d -> %d" % [c0, G.garage.credits])
	r.check(D.focused() == Menu.garageUI.first_buy(), "focus blijft op de upgradeknop", D._name_of(D.focused()))
	# look at a car you do not own, buy it
	await D.click(Menu.garageUI.carRadio.find("mini"), "Cityflitser")
	r.check(G.settings.car == "mini" and not Career.owns("mini"), "niet-gekochte auto bekijken")
	var c1: int = G.garage.credits
	if await D.click(Menu.garageUI.first_buy(), "Kopen"):
		r.check(Career.owns("mini") and G.garage.credits == c1 - Career.CAR_PRICE.mini, "Cityflitser gekocht", str(G.garage.credits))
	# looks
	await D.click(Menu.garageUI.tabLook, "Uiterlijk")
	r.check(Menu.garageUI.look.visible, "tab Uiterlijk")
	await D.click(Menu.garageUI.paintRadio.find("#d62a2a"), "lak rood")
	r.check(G.settings.color == "#d62a2a", "lakkleur", G.settings.color)
	for seg in [["rimRadio", "gold", "rim"], ["rimStyleRadio", "spoke", "rimStyle"], ["wingRadio", "duck", "wing"], ["exhRadio", "dual", "exhaust"], ["stripeRadio", "white", "stripe"]]:
		await D.click(Menu.garageUI.get(seg[0]).find(seg[1]), seg[2])
		r.check(G.carUp("mini")[seg[2]] == seg[1], "uiterlijk: %s = %s" % [seg[2], seg[1]], str(G.carUp("mini")[seg[2]]))
	# the start number: click the field, type; M is not the mute key while typing
	var muted := Sfx.muted
	await D.click(Menu.garageUI.numIn, "startnummer")
	r.check(D.focused() == Menu.garageUI.numIn, "startnummer: veld heeft de focus")
	await D.type_text("4")
	await D.tap(KEY_M)
	await D.type_text("2")
	r.check(Sfx.muted == muted, "M in het tekstveld zet het geluid niet uit")
	r.check(Menu.garageUI.numIn.text == "42", "startnummer: alleen cijfers", Menu.garageUI.numIn.text)
	await D.tap(KEY_ENTER)
	r.check(int(G.carUp("mini").num) == 42, "startnummer 42 bewaard", str(G.carUp("mini").num))
	r.check(D.focused() != Menu.garageUI.numIn, "Enter: uit het veld")
	await D.frames(4)
	r.check(Canvas2D.pending_count() == 0, "startnummer meteen getekend (geen grijs vlak op de deur)", str(Canvas2D.pending_count()))
	await D.shot("garage_look")
	var sv = JSON.parse_string(str(G.store_get("polderrace3d-garage")))
	r.check(sv is Dictionary and int(sv.cars.mini.num) == 42 and sv.cars.mini.rim == "gold" and sv.owned.has("mini"), "garage bewaard")
	# look at another car, leave: you sit in a car you own
	await D.click(Menu.garageUI.tabPerf, "Prestaties")
	await D.click(Menu.garageUI.carRadio.find("rally"), "Rallybeest")
	await D.tap(KEY_ESCAPE)
	r.check(Menu.homeView == "main" and Career.owns(G.settings.car) and not GarageRoom.inGarage, "Esc uit de garage: eigen auto", G.settings.car)

# ------------------------------------------------------------------ settings: tabs, switches, a key binding
func part_settings() -> void:
	await D.click(Menu.homeUI.hSettings, "Instellingen")
	var su := Menu.settingsUI
	var fx0 := bool(G.prefs.fx)
	await D.click(su.togs.fx, "snelheidseffecten")
	r.check(bool(G.prefs.fx) != fx0 and JSON.parse_string(str(G.store_get("polderrace3d-prefs"))).fx == G.prefs.fx, "schakelaar bewaard")
	await D.click(su.togs.fx, "snelheidseffecten")
	await D.click(su.qualRadio.find("mid"), "kwaliteit middel")
	r.check(G.prefs.quality == "mid", "kwaliteit middel")
	await D.click(su.qualRadio.find("high"), "kwaliteit hoog")
	await D.click(su.gearRadio.find("manual"), "handgeschakeld")
	r.check(G.prefs.gearbox == "manual", "versnellingsbak handgeschakeld")
	await D.click(su.gearRadio.find("auto"), "automaat")
	await D.click(su.tabRadio.find("keys"), "tab Toetsen")
	r.check(su.keys.visible and not su.general.visible, "tab Toetsen")
	await D.shot("settings_keys")
	await D.click(su.bindP2, "Speler 2")
	var bb: Control = Menu._buttons(su.bindList)[0]
	await D.click(bb, "gas speler 2")
	r.check(Menu.bindCapture.is_valid(), "wacht op een toets")
	await D.tap(KEY_I)
	r.check(Game.binds.p2.up == ["KeyI"] and JSON.parse_string(str(G.store_get("polderrace3d-binds"))).p2.up == ["KeyI"], "gas speler 2 op I, bewaard", str(Game.binds.p2.up))
	await D.click(Menu._buttons(su.bindList)[0], "gas speler 2")
	await D.tap(KEY_P)
	r.check(Game.binds.p2.up == ["KeyI"] and not Menu.bindCapture.is_valid(), "P is gereserveerd")
	# the toast stands above the menus (CSS pointer-events:none): a click goes through it
	r.check(Hud.toast.visible, "melding: P is gereserveerd")
	var under: Control = await D.hovered_at(Hud.toast.get_global_rect().get_center())
	r.check(under == null or not (under == Hud.toast or Hud.toast.is_ancestor_of(under)), "de melding vangt geen muisklikken", D._name_of(under))
	await D.click(D.find_btn(su.keys, "Standaard herstellen"), "Standaard herstellen")
	r.check(Game.binds.p2.up == ["ArrowUp"], "standaard terug", str(Game.binds.p2.up))
	await D.click(su.tabRadio.find("pad"), "tab Controller")
	r.check(su.pad.visible, "tab Controller")
	await D.click(su.tabRadio.find("general"), "tab Algemeen")
	await D.tap(KEY_ESCAPE)
	r.check(Menu.homeView == "main", "Esc: hoofdscherm")
	# the settings in the pause: switch the mirror off, back to the pause, on with the race
	await setup_race("race", 1, 1)
	await D.wait(1.0)
	await D.tap(KEY_ESCAPE)
	await D.click(Menu.overUI.pSettings, "Instellingen in de pauze")
	var m0 := bool(G.prefs.mirror)
	await D.click(su.togs.mirror, "spiegel")
	r.check(bool(G.prefs.mirror) != m0, "spiegel omgezet in de pauze")
	await D.click(su.togs.mirror, "spiegel")
	await D.shot("pause_settings")
	await D.click(D.find_btn(su.nav, "Terug"), "Terug (pauze)")
	r.check(Game.paused and not Menu.pauseSettingsOpen() and Menu.overUI.pauseMain.visible, "Terug: pauzescherm")
	await D.tap(KEY_ENTER)
	r.check(not Game.paused, "Enter: verder racen")
	await D.tap(KEY_ESCAPE)
	await D.click(Menu.overUI.quitBtn, "Naar menu")
	await D.click(Menu.homeUI.hSettings, "Instellingen")
	r.check(su.content.is_visible_in_tree() and Menu.homeView == "settings", "instellingen weer in het hoofdmenu")
	await D.tap(KEY_ESCAPE)

# ------------------------------------------------------------------ career: the first event as a new player, then a duel
func part_career() -> void:
	await D.click(Menu.homeUI.hPlay, "Spelen")
	await D.click(Menu.homeUI.hCareer, "Carrière")
	r.check(Menu.homeView == "career" and Menu.careerSel == "b1", "carrière: eerste evenement", str(Menu.careerSel))
	await D.shot("career")
	# a car you do not own under "Jouw auto": the garage opens on it, Terug comes back here in a car you own
	await D.click(D.find_btn(Menu.careerUI.cars, "Rallyhatch"), "Rallyhatch (niet in bezit)")
	var kopen = Menu.garageUI.first_buy()
	r.check(Menu.homeView == "garage" and G.settings.car == "rally" and kopen != null and "Kopen" in D._all_text(kopen), "carrière -> garage op de Rallyhatch met Kopen", "%s %s" % [Menu.homeView, G.settings.car])
	# (like a browser: a Kopen you cannot pay is disabled and takes no focus)
	r.check(D.focused() == kopen or kopen.disabled, "focus op Kopen als je hem kunt betalen")
	await D.tap(KEY_ESCAPE)
	r.check(Menu.homeView == "career" and Career.owns(G.settings.car), "Esc: terug in de carrière, in een eigen auto", "%s %s" % [Menu.homeView, G.settings.car])
	var prevMode: String = G.settings.mode
	var prevLaps := int(G.settings.laps)
	await D.click(Menu.careerUI.careerGo, "Start")
	r.check(G.careerEv != null and Game.state == "countdown" and Game.bots.size() == 3 and Game.raceLaps == 2, "Proefrit gestart", "%d bots %d ronden" % [Game.bots.size(), Game.raceLaps])
	var cr0: int = G.garage.credits
	if await race_to_results(200):
		r.check(Menu.overUI.storyBox.visible, "verhaal onder de uitslag")
		var res = G.careerEv.res
		r.check(res != null, "resultaat van het evenement")
		var lab: String = (Menu.overUI.againBtn.get_meta("label") as Label).text
		r.check(lab == ("Verder" if res.passed else "Nog een keer"), "knop Verder / Nog een keer", lab)
		r.check((Menu.overUI.menuBtn.get_meta("label") as Label).text == "Carrière", "knop Carrière")
		await D.shot("career_result")
		r.check(G.garage.credits >= cr0, "prijzengeld", "%d -> %d" % [cr0, G.garage.credits])
		await D.click(Menu.overUI.menuBtn, "Carrière")
		r.check(Menu.homeView == "career" and G.careerEv == null, "terug in de carrière", Menu.homeView)
		r.check(G.settings.mode == prevMode and int(G.settings.laps) == prevLaps, "eigen race-instellingen terug", "%s %d" % [G.settings.mode, int(G.settings.laps)])
		r.check(Menu.careerSel == ("b2" if res.passed else "b1"), "volgend evenement gekozen", str(Menu.careerSel))
	await D.tap(KEY_ESCAPE)
	await D.tap(KEY_ESCAPE)
	r.check(Menu.homeView == "main", "Esc Esc: hoofdscherm", Menu.homeView)
	# a player further on: b1-b3 done, the duel against Daan is next
	var cups := {"b1": {"best": 1, "won": true}, "b2": {"best": 2}, "b3": {"best": 1, "won": true}}
	G.garage.career.cups = cups
	G.saveGarage()
	await D.click(Menu.homeUI.hPlay, "Spelen")
	await D.click(Menu.homeUI.hCareer, "Carrière")
	r.check(not Menu.careerUI.careerGo.disabled, "carrière: Start kan")
	await D.click(D.find_btn(Menu.careerUI.list, "Duel op de dijk"), "kaart Duel op de dijk")
	r.check(Menu.careerSel == "b4", "duel gekozen", str(Menu.careerSel))
	await D.shot("career_duel")
	await D.click(Menu.careerUI.careerGo, "Start duel")
	r.check(G.careerEv != null and G.careerEv.ev.kind == "duel" and Game.bots.size() == 1 and Game.bots[0].name == "Daan" and Trk.TRACK_ID == "afsluitdijk", "duel: één tegen één met Daan op de Afsluitdijk", "%d bots, %s" % [Game.bots.size(), Trk.TRACK_ID])
	if await race_to_results(200):
		var res = G.careerEv.res
		var t: String = Menu.overUI.overTitle.text
		r.check(t == "Gewonnen!" or t == "Je werd 2e", "duel: uitslag", t)
		if res.passed:
			await D.click(Menu.overUI.againBtn, "Verder")
			r.check(Menu.homeView == "career" and Menu.careerSel == "B", "duel gewonnen: de Polder Cup is volgende", str(Menu.careerSel))
		else:
			await D.click(Menu.overUI.againBtn, "Nog een keer")
			r.check(Game.state == "countdown" and G.careerEv != null and G.careerEv.ev.id == "b4", "duel verloren: nog een keer", Game.state)
			await D.tap(KEY_ESCAPE)
			await D.click(Menu.overUI.quitBtn, "Naar menu")
			r.check(Menu.homeView == "career", "pauze, naar menu: terug in de carrière", Menu.homeView)
	if Menu.homeView != "main":
		await D.tap(KEY_ESCAPE)
		await D.tap(KEY_ESCAPE)

# ------------------------------------------------------------------ a whole championship, quit halfway and go on
func part_champ() -> void:
	await D.click(Menu.homeUI.hPlay, "Spelen")
	await D.click(Menu.homeUI.hChamp, "Kampioenschap")
	r.check(Menu.menuFlow == "champ" and Menu.menuStep == 0, "kampioenschap: eerst de auto", str(Menu.menuStep))
	await D.click(Menu.setupUI.nextBtn, "Volgende")
	r.check(Menu.menuStep == 3, "kampioenschap: de rondes", str(Menu.menuStep))
	await D.shot("champ_rounds")
	await D.click(Menu.setupUI.nextBtn, "Start kampioenschap")
	var n: int = Champ.CR().size()
	r.check(Game.mode == "champ" and Game.state == "countdown" and Game.bots.size() == 5, "kampioenschap gestart", Game.mode)
	var car: String = G.settings.car
	for k in n:
		r.check(Trk.TRACK_ID == Champ.CR()[k].track and Game.raceLaps == int(Champ.CR()[k].laps) and G.settings.car == car, "race %d: %s, %d ronden" % [k + 1, Champ.CR()[k].track, int(Champ.CR()[k].laps)], "%s %d %s" % [Trk.TRACK_ID, Game.raceLaps, G.settings.car])
		if not await race_to_results(300): return
		r.check(int(Champ.champ.round) == k + 1, "race %d gereden" % (k + 1), str(Champ.champ.round))
		await D.click(Menu.overUI.againBtn, "Tussenstand")
		r.check(Game.overView == "standings", "tussenstand na race %d" % (k + 1), Menu.overUI.overTitle.text)
		if k < n - 1:
			if k == 1:
				# halfway: back to the menu, and the game is closed and started again
				await D.click(Menu.overUI.menuBtn, "Hoofdmenu")
				r.check(Menu.home.visible and Menu.homeUI.hResume.visible, "hoofdmenu: Verder racen")
				await D.relaunch("user://test-play-2.json")
				r.check(Menu.homeUI.hResume.visible and Menu.homeUI.playTitle.text == "Kampioenschap", "na opnieuw starten: kampioenschap bewaard", Menu.homeUI.playTitle.text)
				await D.click(Menu.homeUI.hResume, "Verder racen")
				r.check(Game.mode == "champ" and int(Champ.champ.round) == k + 1 and Trk.TRACK_ID == Champ.CR()[k + 1].track, "verder met race %d" % (k + 2), "%s %s" % [Game.mode, Trk.TRACK_ID])
			else:
				await D.click(Menu.overUI.againBtn, "Volgende race")
				r.check(Game.state == "countdown" and Game.mode == "champ", "race %d begint" % (k + 2), Game.state)
	r.check(Champ.champ.get("done", false) and not Champ.champ.active, "kampioenschap klaar", str(Champ.champ))
	var t: String = Menu.overUI.overTitle.text
	r.check(t == "Kampioen!" or t.begins_with("Eindstand"), "eindstand", t)
	r.check(Podium.inPodium, "eindpodium")
	r.check((Menu.overUI.againBtn.get_meta("label") as Label).text == "Naar het hoofdmenu" and not Menu.overUI.menuBtn.visible, "knop Naar het hoofdmenu")
	await D.shot("champ_final")
	await D.click(Menu.overUI.againBtn, "Naar het hoofdmenu")
	r.check(Menu.home.visible and Menu.homeView == "main" and not Menu.homeUI.hResume.visible, "hoofdmenu, geen kampioenschap meer bezig")
	r.check(G.settings.diff == JSON.parse_string(str(G.store_get("polderrace3d-settings"))).diff, "eigen niveau terug")

# ------------------------------------------------------------------ window sizes: every screen fits and its buttons are reachable
func layout_ok(where: String) -> void:
	await D.frames(3)
	var vp := Rect2(Vector2.ZERO, Vector2(D.tree.root.size))
	var bad := []
	var btns := []
	var shown := {}       # button -> the part of it you see (a scrolling list clips its content)
	for c in Menu.root.find_children("*", "", true, false):
		if c is UiKit.Btn and c.is_visible_in_tree(): btns.append(c)
	for b in btns:
		var rc: Rect2 = b.get_global_rect()
		var sc = CareerUI._scroller(b)
		var clip: Rect2 = sc.get_global_rect() if sc != null else vp
		if not rc.intersects(clip): continue        # scrolled out of view: the list scrolls
		shown[b] = rc.intersection(clip)
		if not vp.grow(1).encloses(shown[b]): bad.append("buiten beeld: " + D._name_of(b))
	var vis: Array = shown.keys()
	for i in vis.size():
		for j in range(i + 1, vis.size()):
			var a: Control = vis[i]
			var b: Control = vis[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a): continue
			if shown[a].grow(-2).intersects(shown[b].grow(-2)): bad.append("overlap: %s / %s" % [D._name_of(a), D._name_of(b)])
	r.check(bad.is_empty(), "%s: alles in beeld, niets over elkaar" % where, ", ".join(bad.slice(0, 4)))

func part_sizes() -> void:
	for sz in [Vector2i(1024, 600), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		var tag := "%dx%d" % [sz.x, sz.y]
		await D.resize(sz.x, sz.y)
		Menu.homePanel("main")
		await layout_ok(tag + " hoofdscherm")
		await D.shot("size_%s_home" % tag)
		for t in [["hPlay", "play"], ["hGarage", "garage"], ["hSettings", "settings"], ["hAch", "ach"], ["hRecords", "records"]]:
			await D.click(Menu.homeUI.get(t[0]), t[1])
			await layout_ok("%s paneel %s" % [tag, t[1]])
			if t[1] == "garage" or t[1] == "play": await D.shot("size_%s_%s" % [tag, t[1]])
			await D.tap(KEY_ESCAPE)
		await D.click(Menu.homeUI.hPlay, "Spelen")
		await D.click(Menu.homeUI.hCareer, "Carrière")
		await layout_ok(tag + " carrière")
		await D.tap(KEY_ESCAPE)
		await D.click(Menu.homeUI.hStart, "Race")
		for st in 3:
			await layout_ok("%s race-opzet stap %d" % [tag, Menu.menuStep])
			await D.shot("size_%s_setup%d" % [tag, Menu.menuStep])
			if st < 2: await D.click(Menu.setupUI.nextBtn, "Volgende")
		await D.click(Menu.setupUI.nextBtn, "Start race")
		await D.wait(4.6)
		await D.tap(KEY_ESCAPE)
		await layout_ok(tag + " pauze")
		await D.shot("size_%s_pause" % tag)
		await D.click(Menu.overUI.quitBtn, "Naar menu")
	# a resize while a menu is open: the panel follows
	await D.click(Menu.homeUI.hSettings, "Instellingen")
	await D.resize(1024, 600)
	await layout_ok("instellingen na verkleinen")
	await D.resize(1920, 1080)
	await layout_ok("instellingen na vergroten")
	await D.tap(KEY_ESCAPE)
	# a window dragged very small: every screen still runs (the scroll area's right margin once grew with content that
	# did not fit, re-queued itself and looped until the message queue overflowed and the game crashed)
	for sz in [Vector2i(400, 300), Vector2i(64, 64)]:
		await D.resize(sz.x, sz.y)
		for v in ["play", "garage", "settings", "career", "ach", "records", "main"]:
			Menu.homePanel(v)
			await D.frames(3)
		for st in [2, 0, 1, -1]:
			Menu.showMenu(st)
			await D.frames(3)
		r.check(Game.state == "menu" and Menu.home.visible, "venster %dx%d: alle schermen open zonder vastlopen" % [sz.x, sz.y])
	await D.resize(1280, 720)

# ------------------------------------------------------------------ the gamepad in the menus, the pause and the results
## a button of the gamepad pressed and let go (Menu.padNav, what Game.readPad calls every frame: a gamepad cannot be
## plugged in for a test, Input.get_connected_joypads stays empty)
func pad(k: String) -> void:
	Menu.padNav({k: true}, {})
	await D.frame()
	Menu.padNav({}, {k: true})
	await D.frames(2)

func part_pad() -> void:
	Menu.homePanel("main")
	await D.frames(2)
	r.check(D.focused() == Menu.homeUI.hPlay, "controller: Spelen heeft de focus")
	await pad("down")
	var f1: Control = D.focused()
	r.check(f1 != Menu.homeUI.hPlay and f1 is UiKit.Btn and Menu.home.is_ancestor_of(f1), "omlaag: volgende knop", D._name_of(f1))
	await pad("up")
	r.check(D.focused() == Menu.homeUI.hPlay, "omhoog: terug op Spelen")
	await pad("a")
	r.check(Menu.homeView == "play", "A: Spelen", Menu.homeView)
	await pad("b")
	r.check(Menu.homeView == "main", "B: terug", Menu.homeView)
	await pad("start")
	r.check(Menu.homeView == "play" and D.focused() == Menu.homeUI.hStart, "Start: Spelen, focus op Race", D._name_of(D.focused()))
	await pad("a")
	r.check(Menu.menuStep == 2, "A op Race: stap Spelmodus", str(Menu.menuStep))
	var m0: String = G.settings.mode
	await pad("r")
	r.check(G.settings.mode != m0, "rechts: volgende modus", G.settings.mode)
	await pad("l")
	r.check(G.settings.mode == m0, "links: terug", G.settings.mode)
	await pad("a")
	r.check(Menu.menuStep == 0, "A: volgende stap", str(Menu.menuStep))
	var car0: String = G.settings.car
	var mine: int = Cars.carsOf(Cars.CARS[car0].cls).filter(func(id): return Career.owns(id)).size()
	await pad("r")
	r.check((G.settings.car != car0 if mine > 1 else G.settings.car == car0) and Career.owns(G.settings.car), "rechts: volgende eigen auto", G.settings.car)
	await pad("l")
	await pad("b")
	await pad("b")
	r.check(Menu.menuStep < 0 and Menu.homeView == "play", "B B: terug naar Spelen", "%d %s" % [Menu.menuStep, Menu.homeView])
	# pause: down walks the buttons, B goes on with the race
	await D.click(Menu.homeUI.hQuick, "Snel racen")
	await D.wait(4.6)
	await D.tap(KEY_ESCAPE)
	await pad("down")
	r.check(D.focused() != null and Menu.pauseOv.is_ancestor_of(D.focused()), "pauze: omlaag geeft een knop de focus", D._name_of(D.focused()))
	await pad("b")
	r.check(not Game.paused, "B: verder racen")
	await D.tap(KEY_ESCAPE)
	await pad("start")
	r.check(not Game.paused, "Start: verder racen")
	await D.tap(KEY_ESCAPE)
	for _i in 6:
		await pad("down")
		if D.focused() == Menu.overUI.quitBtn: break
	r.check(D.focused() == Menu.overUI.quitBtn, "pauze: omlaag tot Naar menu", D._name_of(D.focused()))
	await pad("a")
	r.check(Game.state == "menu" and Menu.home.visible, "A op Naar menu: hoofdmenu", Game.state)

# ------------------------------------------------------------------ a player with everything
func part_rich() -> void:
	var owned := {}
	for id in Cars.CARS: owned[id] = true
	var cups := {}
	for e in Career.CAREER_EVS: cups[e.id] = {"best": 1, "won": true}
	var bonus := {}
	for c in Career.CHAPTERS: bonus[c.id] = true
	G.use_store("user://test-play-rich.json", {"polderrace3d-garage": {"credits": 60000, "owned": owned, "career": {"cups": cups, "bonus": bonus}},
		"polderrace3d-settings": {"car": "v12", "color": "#f36f21", "mode": "race", "bots": 3, "laps": 1}})
	Game.toMenu(-1)
	await D.frames(3)
	r.check(G.settings.car == "v12" and Menu.homeUI.garTitle.text == Cars.CARS.v12.name, "alles in bezit: in de " + Cars.CARS.v12.name, Menu.homeUI.garTitle.text)
	await D.shot("home_rich")
	await D.click(Menu.homeUI.hPlay, "Spelen")
	r.check("Legende! Alles gehaald" in D._all_text(Menu.homeUI.hCareer), "carrière: alles gehaald", D._all_text(Menu.homeUI.hCareer))
	await D.click(Menu.homeUI.hStart, "Race")
	await D.click(Menu.setupUI.nextBtn, "Volgende")
	r.check(Menu.setupUI.classRadio.items.all(func(b): return not b.disabled) and not Menu.setupUI.carsNote.visible, "alle klassen te kiezen, geen koop-tip")
	r.check(D.focused() == Menu.setupUI.classRadio.find("S"), "focus op klasse S", D._name_of(D.focused()))
	await D.tap(KEY_LEFT)
	r.check(Cars.CARS[G.settings.car].cls == "A", "pijl links: klasse A", G.settings.car)
	var n := Menu.setupUI.carCards.keys().filter(func(id): return Menu.setupUI.carCards[id].visible).size()
	r.check(n == Cars.carsOf("A").size(), "alle A-auto's te kiezen", str(n))
	await D.shot("setup_cars_rich")
	await D.tap(KEY_RIGHT)
	r.check(Cars.CARS[G.settings.car].cls == "S", "pijl rechts: klasse S", G.settings.car)
	await pad("lb")
	r.check(Cars.CARS[G.settings.car].cls == "A", "controller LB: klasse terug", G.settings.car)
	await pad("rb")
	r.check(Cars.CARS[G.settings.car].cls == "S", "controller RB: klasse verder", G.settings.car)
	await D.click(Menu.setupUI.nextBtn, "Volgende")
	await D.click(Menu.setupUI.nextBtn, "Start race")
	r.check(Game.state == "countdown" and Game.bots.size() == 3 and Cars.CARS[Game.bots[0].type].cls == "S", "race in klasse S met 3 bots", str(Game.bots.size()))
	await race_to_results(150)
	await to_menu_from_results()
	# garage: every car owned, upgrades to buy
	await D.click(Menu.homeUI.hGarage, "Garage")
	await D.click(Menu.garageUI.classRadio.find("B"), "klasse B")
	r.check(Menu.garageUI.carCards.keys().all(func(id): return not Menu.garageUI.carCards[id].b.visible or Career.owns(id)), "garage: alle auto's in bezit")
	var b = Menu.garageUI.first_buy()
	r.check(b != null and not D._all_text(b).contains("Kopen"), "garage: upgrades, niets te kopen")
	await D.tap(KEY_ESCAPE)
	# career: every chapter open
	await D.click(Menu.homeUI.hPlay, "Spelen")
	await D.click(Menu.homeUI.hCareer, "Carrière")
	r.check(Menu.careerUI.chRadio.items.all(func(x): return not x.disabled) and not Menu.careerUI.careerGo.disabled, "carrière: alle hoofdstukken open")
	await D.click(Menu.careerUI.chRadio.items[0], "hoofdstuk 1")
	r.check(Menu.careerCh == "c1", "hoofdstuk 1 gekozen", str(Menu.careerCh))
	await D.shot("career_rich")
	await D.tap(KEY_ESCAPE)
	await D.tap(KEY_ESCAPE)
	r.check(Menu.homeView == "main", "terug op het hoofdscherm")

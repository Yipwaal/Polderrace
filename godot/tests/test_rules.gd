extends RefCounted
## The game rules against the HTML game (golden/rules.json, made by tools/export_rules.py): the same scripted inputs must
## give the same credits, championship points and standings, career results (bonus, what opens, achievements), race-end
## achievements, rival tuning, result order and position, eliminations, lap/checkpoint messages and the records they
## save, save keys, number formats, upgrade prices, event lines and career fields.

var r: TestReport

func run(host: Node) -> TestReport:
	r = TestReport.new("spelregels gelijk aan de HTML-versie")
	var gold: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/golden/rules.json"))
	var I: Dictionary = gold["in"]
	var O: Dictionary = gold["out"]
	var env := Env.new()
	host.add_child(env)
	World.root = Node3D.new()
	host.add_child(World.root)
	Game.set_process(false)
	Game.set_process_input(false)
	var S := G.settings
	S.track = "polder"; S.dir = "fwd"; S.car = "gt"
	TrackLoader.load_track("polder", "fwd")
	var g := Game

	# ---- credits
	var got := []
	for c in I.credits:
		g.mode = c.mode; S.diff = c.diff; g.raceLaps = int(c.laps); g.distance = float(c.get("dist", 0))
		g.lapTimes = []
		for _k in int(c.get("nl", 0)): g.lapTimes.append(60.0)
		g.ghostSaved = bool(c.get("gs", false))
		Champ.champ = {"diff": c.cdiff} if c.has("cdiff") else null
		G.garage.credits = 0
		got.append(g.awardCredits(int(c.pos)))
	_list(got, O.credits, I.credits, "credits per modus, plaats, ronden en niveau")

	# ---- championship points and standings
	var cb: Array = I.champ.bots
	Champ.champ = {"nRounds": 6, "active": true, "car": "gt", "color": "#ffffff", "cls": "A", "diff": "normal", "round": 0, "bots": cb.duplicate(true),
		"pts": {"Jij": 0}, "history": []}
	for d in cb: Champ.champ.pts[d.name] = 0
	for k in I.champ.orders.size():
		g.resultRows = I.champ.orders[k].map(func(n): return {"me": true, "name": "Jij"} if n == "Jij" else {"name": n})
		Champ.champRecordRace()
		var st: Array = Champ.champStandings().map(func(x): return [x.name, x.pts, x.car, x.me])
		_same({"round": Champ.champ.round, "st": st}, O.champ[k], "kampioenschap: punten en stand na race %d" % (k + 1))
	_same(Champ.champ.history, O.champHist, "kampioenschap: uitslagen per race")
	G.store_set("polderrace3d-champ", "null")
	Champ.champ = null

	# ---- career
	G.garage.career = {"cups": {}, "bonus": {}}
	G.garage.ach = {}
	G.garage.credits = 0
	G.garage.owned = {"hatch": true}
	G.store_set("polderrace3d-career-run", "null")
	var bad := []
	for k in I.career.size():
		var step: Array = I.career[k]
		var ev: Dictionary = Career.evById(step[0])
		var res := Career.careerEventDone(ev, int(step[1]))
		var nx = Career.careerNext()
		var mine := {"res": res, "credits": G.garage.credits, "next": nx.id if nx != null else null,
			"open": Career.CAREER_EVS.filter(func(e): return Career.evUnlocked(e)).map(func(e): return e.id),
			"chs": Career.CHAPTERS.filter(func(c): return Career.chUnlocked(c)).map(func(c): return c.id)}
		if not _eq(mine, O.career[k]): bad.append("%s %de: %s / html %s" % [step[0], step[1], JSON.stringify(mine), JSON.stringify(O.career[k])])
	r.check(bad.is_empty(), "carrière: resultaat, bonus, vrijgespeeld en volgende evenement na elke race", "" if bad.is_empty() else bad[0])
	_same(G.garage.career.cups, O.careerCups, "carrière: beste plek en gewonnen per evenement")
	_same(G.garage.career.bonus, O.careerBonus, "carrière: hoofdstukbonussen")
	var ach: Array = G.garage.ach.keys()
	ach.sort()
	_same(ach, O.careerAch, "carrière: prestaties (cups, duels)")
	_same(Career.CAREER_EVS.map(func(e): return [e.id, Career.evSub(e), Career.goalText(e.goal)]), O.evSub, "carrière: regel en doel per evenement")
	got = []
	for c in I.owned:
		G.garage.owned = c[0].duplicate()
		S.lastByClass = c[1].duplicate()
		got.append(Career.ownedCar(c[2]))
	_list(got, O.owned, I.owned, "eigen auto (ownedCar)")
	got = []
	for c in I.defs:
		S.color = c[1]; S.car = "gt"
		got.append(Career.careerDefs(Career.evById(c[0])).map(func(d): return [d.name, d.color, d.get("rival", false), d.type if d.get("rival", false) else ""]))
	_list(got, O.defs, I.defs, "carrière: tegenstanders (namen, kleuren, rivalen)")
	got = []
	S.car = "evo"
	for k in 3:
		S.color = Cars.COLORS[k * 2]
		got.append(g.makeBotDefs(7).map(func(d): return [d.name, d.color, Cars.CARS[d.type].cls]))
	_list(got, O.botDefs, [0, 1, 2], "bots: namen, kleuren en klasse")

	# ---- achievements at the end of a race
	got = []
	for a in I.ach:
		G.garage.ach = {}
		G.garage.wins = {}
		if a.get("wins") == "others":
			for t in TrackDefs.TRACKS:
				if t != Trk.TRACK_ID: G.garage.wins[t] = true
		g.mode = a.mode; Env.me.time = a.time; Env.me.weather = a.weather; g.raceContacts = int(a.contacts); S.grid = a.grid
		g.bots = []
		for _k in int(a.bots): g.bots.append(Mover.new())
		Ach.achRaceEnd(int(a.pos))
		var ks: Array = G.garage.ach.keys()
		ks.sort()
		var ws: Array = G.garage.wins.keys()
		ws.sort()
		got.append({"ach": ks, "wins": ws})
	_list(got, O.ach, I.ach, "prestaties na een race")

	# ---- rival tuning
	got = []
	for c in I.rival:
		G.garage.cars = c.cars.duplicate(true)
		S.car = c.car; S.p2car = c.p2car; g.split = c.split
		var rb := g.rivalBoost()
		got.append([rb.vmax, rb.acc, rb.grip, rb.brake])
	g.split = false
	_list(got, O.rival, I.rival, "tegenstanders tunen mee (rivalBoost)")

	# ---- result order and position
	got = []
	for c in I.order:
		g.mode = c.mode; g.raceLaps = int(c.laps); g.bots = c.bots.map(_bot)
		g.player.lap = int(c.pl.lap); g.player.s = c.pl.s; g.raceDone = c.pl.done; g.playerOut = c.pl.out
		g.raceFinishTime = c.pl.ft; g.elimPos = int(c.pl.ep); g.raceBestLap = c.pl.best
		got.append({"rows": g.resultOrder().map(func(x): return [x.name, x.car, x.finished, x.out]), "pos": g.playerPosition()})
	_list(got, O.order, I.order, "uitslag: volgorde en plek")

	# ---- elimination
	got = []
	for c in I.elim:
		g.mode = "elim"; g.state = "racing"; g.raceDone = false; g.playerOut = false; g.elimDone = 0; g.elimPos = 0; g.raceTime = 77
		g.bots = c.bots.map(_bot)
		g.player.lap = int(c.pl.lap); g.player.s = c.pl.s
		Hud.msg_label.text = ""
		g.elimCheck()
		got.append({"bots": g.bots.map(func(b): return [b.name, b.out, b.elimPos, b.outAt]), "playerOut": g.playerOut, "elimPos": g.elimPos,
			"raceDone": g.raceDone, "state": g.state, "msg": Hud.msg_label.text, "elimDone": g.elimDone})
	_list(got, O.elim, I.elim, "eliminatie: wie eruit ligt, melding")

	# ---- laps and checkpoints
	g.bots = []
	got = []
	for c in I.laps:
		S.car = c.car; g.mode = c.mode; g.raceMode = g.mode != "time"; g.state = "racing"; g.raceDone = false; g.playerOut = false
		g.raceLaps = int(c.get("laps", 3)); g.player.lap = 0; g.lapStart = 0; g.lapTimes = []; g.raceBestLap = 0; g.lapRecordSet = false
		g.checkpoints = 0; g.timeLeft = 10; g.ghostSaved = false
		for k in [g.lapKey(Trk.TRACK_ID), g.lapKey(Trk.TRACK_ID) + "-car", g.lapCarKey(Trk.TRACK_ID)]: G.store_set(k, "0")
		var msgs := []
		var times: Array = c.get("times", [])
		var n: int = times.size() if c.has("times") else c.cps.size()
		for i in n:
			if c.has("times"): g.raceTime = times[i]
			else: g.clock = c.clock[i]
			Hud.msg_label.text = ""
			g.hitCheckpoint(0 if c.has("times") else int(c.cps[i]))
			msgs.append([Hud.msg_label.text, g.state, g.player.lap, g.timeLeft])
		got.append({"msgs": msgs, "lapTimes": g.lapTimes, "best": g.raceBestLap, "rec": g.lapRecordSet, "cps": g.checkpoints,
			"store": [g.lapKey(Trk.TRACK_ID), g.lapCarKey(Trk.TRACK_ID)].map(func(k): return [k, G.store_get(k, "?"), G.store_get(k + "-car", "?")])})
	_list(got, O.laps, I.laps, "ronden en checkpoints: meldingen, rondetijden, records")

	# ---- key names: Godot keys as KeyboardEvent.code (Game.codeOf), and their labels in the key binding screen
	var KEYS := {"Space": KEY_SPACE, "ShiftLeft": KEY_SHIFT, "ShiftRight": KEY_SHIFT, "ControlLeft": KEY_CTRL, "AltRight": KEY_ALT, "KeyA": KEY_A,
		"KeyQ": KEY_Q, "Digit5": KEY_5, "Numpad0": KEY_KP_0, "Numpad3": KEY_KP_3, "ArrowUp": KEY_UP, "ArrowLeft": KEY_LEFT, "Enter": KEY_ENTER,
		"Tab": KEY_TAB, "PageUp": KEY_PAGEUP, "PageDown": KEY_PAGEDOWN, "Comma": KEY_COMMA, "Period": KEY_PERIOD, "Slash": KEY_SLASH,
		"Semicolon": KEY_SEMICOLON, "Quote": KEY_APOSTROPHE, "BracketLeft": KEY_BRACKETLEFT, "BracketRight": KEY_BRACKETRIGHT,
		"Backslash": KEY_BACKSLASH, "Minus": KEY_MINUS, "Equal": KEY_EQUAL, "F5": KEY_F5, "Backquote": KEY_QUOTELEFT, "CapsLock": KEY_CAPSLOCK,
		"Home": KEY_HOME, "Delete": KEY_DELETE}
	var codes := []
	for c in I.keyLabels:
		var ek := InputEventKey.new()
		ek.physical_keycode = KEYS[c]
		ek.location = KEY_LOCATION_RIGHT if c.ends_with("Right") and KEYS[c] in [KEY_SHIFT, KEY_CTRL, KEY_ALT] else KEY_LOCATION_LEFT
		codes.append(Game.codeOf(ek))
	_list(codes, I.keyLabels, I.keyLabels, "toetsnamen als in de browser (KeyboardEvent.code)")
	_list(I.keyLabels.map(func(c): return SettingsUI.keyLabel(c)), O.keyLabels, I.keyLabels, "toetsnamen in het toetsenscherm")

	# ---- save keys, formats, prices
	_same(I.keys.tracks.map(func(t): return [g.tv(t, "fwd"), g.tv(t, "rev")]), O.tv, "opslag: baan+versie+richting")
	got = []
	for c in I.keys.ids:
		S.dir = c[1]; S.car = c[2]
		var id: String = c[0]
		got.append([g.bestKey(id), g.lapKey(id), g.lapCarKey(id), Rep.ghostKey(id), g.bestKey(id, "S"), g.lapCarKey(id, "mini")])
	_list(got, O.keys, I.keys.ids, "opslag: sleutels voor records en ghosts")
	_list(I.fmt.lap.map(func(v): return G.fmtLap(v)), O.fmt.lap, I.fmt.lap, "fmtLap")
	_list(I.fmt.km.map(func(v): return G.fmtKm(v)), O.fmt.km, I.fmt.km, "fmtKm")
	_list(I.fmt.cr.map(func(v): return G.fmtCr(v)), O.fmt.cr, I.fmt.cr, "fmtCr")
	_list(I.fmt.d.map(func(v): return G.fmtD(v)), O.fmt.d, I.fmt.d, "fmtD")
	_same(O.upCost.map(func(e): return [e[0], G.UPG.map(func(u): return [0, 1, 2].map(func(l): return G.upCost(e[0], u, l)))]), O.upCost, "upgradeprijzen per klasse")
	G.garage.cars = {"gt": {"eng": 3, "turbo": 2, "tyre": 1, "brake": 3}}
	var e := G.effStats("gt")
	_same([e.vmax, e.acc, e.grip, e.brake], O.effStats, "effStats met upgrades")

	g.bots = []
	g.state = "menu"; g.mode = "race"; g.raceDone = false; g.playerOut = false
	Game.set_process(true)
	Game.set_process_input(true)
	return r

func _bot(d: Dictionary) -> Mover:
	var b := Mover.new()
	b.name = d.name; b.type = d.type; b.lap = int(d.lap); b.s = d.s; b.finished = d.finished; b.finishTime = d.finishTime
	b.out = d.out; b.elimPos = int(d.elimPos); b.bestLap = d.bestLap
	return b

## one check for a list, naming the first input that differs
func _list(mine: Array, gold: Array, inputs: Array, label: String) -> void:
	var bad := []
	for k in maxi(mine.size(), gold.size()):
		var a = mine[k] if k < mine.size() else "<geen>"
		var b = gold[k] if k < gold.size() else "<geen>"
		if not _eq(a, b): bad.append("%s: %s / html %s" % [JSON.stringify(inputs[k]) if k < inputs.size() else str(k), JSON.stringify(a), JSON.stringify(b)])
	r.check(bad.is_empty(), label, ("%d gelijk" % gold.size()) if bad.is_empty() else ("%d anders, bv. %s" % [bad.size(), bad[0]]))

func _same(mine, gold, label: String) -> void:
	r.check(_eq(mine, gold), label, "" if _eq(mine, gold) else "%s / html %s" % [JSON.stringify(mine), JSON.stringify(gold)])

## deep equality; numbers compare as numbers (JSON gives floats), to 1e-6
func _eq(a, b) -> bool:
	if (a is int or a is float) and (b is int or b is float): return absf(float(a) - float(b)) < 1e-6
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for k in a.size():
			if not _eq(a[k], b[k]): return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for k in a:
			if not b.has(k) or not _eq(a[k], b[k]): return false
		return true
	if a == null or b == null: return a == null and b == null
	if typeof(a) != typeof(b): return false
	return a == b

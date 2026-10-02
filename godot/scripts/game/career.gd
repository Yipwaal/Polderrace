extends Node
## Autoload "Career": the career of the HTML game (JS section "career & achievements"): four chapters with a story, each a
## string of events (race, elimination, a duel with the chapter's rival) ending in a cup on points; the cars you own and buy
## (CAR_PRICE, owns, ownedCar, ensureOwnedCars, buyCar). Results live in G.garage.career.cups[event id] = {best, won}
## (the finales keep the old cup ids B, A, S, so old saves carry over).

const CAR_PRICE := {"hatch": 0, "mini": 1200, "coupe": 1500, "rally": 1800, "roadster": 2200, "retro": 2600, "sedan": 5500, "gt": 6000, "wagon": 6500,
	"fastback": 7000, "muscle": 7500, "evo": 8000, "super": 16000, "proto": 18000, "speedster": 19000, "longtail": 20000, "hyper": 22000, "v12": 24000}
const PEOPLE := {"kees": {"name": "Opa Kees", "col": "#f2c200", "ink": "#1b1b1b"}, "daan": {"name": "Daan de Wit", "col": "#d62a2a"},
	"marloes": {"name": "Marloes", "col": "#2f8f5b"}, "ingrid": {"name": "Ingrid Bakker", "col": "#1d4f9e"}, "baron": {"name": "De Baron", "col": "#1b1b1b"}}
const RIVALS := {"daan": {"name": "Daan", "full": "Daan de Wit", "color": "#d62a2a"}, "ingrid": {"name": "Ingrid", "full": "Ingrid Bakker", "color": "#1d4f9e"},
	"baron": {"name": "De Baron", "full": "Joost van Dam, de Baron", "color": "#1b1b1b"}}
const EV_KIND := {"race": "Race", "elim": "Eliminatie", "duel": "Duel", "cup": "Kampioenschap"}
const CHAPTERS := [
	{"id": "c1", "tab": "Polder", "cls": "B", "name": "De polder", "rival": ["daan", "rally"], "bonus": 1500,
		"intro": ["kees", "Zo, dus jij wilt racen? Ik reed vroeger rally, weet je. Begin maar in de polder, met de jongens uit het dorp. En pas op voor Daan de Wit: die denkt dat hij de snelste van de streek is."],
		"outro": ["kees", "Kampioen van de polder! Er belde net iemand van Team Delta: ze willen je zien rijden in klasse A. Van mij krijg je € 1.500 voor je eerste A-auto."],
		"events": [
			{"id": "b1", "kind": "race", "name": "Proefrit door de polder", "track": "polder", "laps": 2, "bots": 3, "diff": "easy", "goal": 3, "prize": [500, 350, 250],
				"pre": ["kees", "Rustig beginnen: drie jongens uit het dorp, twee rondjes. Kom maar bij de eerste drie."], "win": ["kees", "Niet slecht voor een eerste keer! Je hebt het in je bloed."], "lose": ["kees", "Geeft niks. Nog een keer, en kijk verder vooruit in de bochten."]},
			{"id": "b2", "kind": "race", "name": "Kermisrace", "track": "dorp", "time": "dusk", "laps": 3, "bots": 5, "diff": "easy", "goal": 3, "prize": [700, 450, 300],
				"pre": ["kees", "Op de kermis rijden ze elk jaar een race door de straatjes. Daan wint hem altijd. Tijd dat iemand hem op zijn plek zet."], "win": ["daan", "Hé, wie ben jij nou weer? Geluk gehad. Volgende keer niet."], "lose": ["daan", "Haha! Ga eerst maar eens leren rijden."]},
			{"id": "b3", "kind": "elim", "name": "Laatste man staat", "track": "circuit", "bots": 4, "diff": "normal", "goal": 2, "prize": [900, 600, 300],
				"pre": ["kees", "Op het circuit doen ze eliminatie: na elke ronde valt de laatste af. Niet achteraan blijven hangen!"], "win": ["kees", "Zie je wel. Rustig blijven en op het goede moment toeslaan."], "lose": ["kees", "Achteraan is het gevaarlijk. Haal in de eerste ronde al een paar auto's in."]},
			{"id": "b4", "kind": "duel", "name": "Duel op de dijk", "track": "afsluitdijk", "laps": 2, "diff": "hard", "goal": 1, "prize": [1200, 300],
				"pre": ["daan", "Jij denkt dat je snel bent? Eén tegen één, over de Afsluitdijk. Wie verliest, betaalt de patat."], "win": ["daan", "...Oké. Jij hoeft de patat niet te betalen. Respect."], "lose": ["daan", "Patat met, graag! Kom maar terug als je durft."]},
			{"id": "B", "kind": "cup", "name": "Polder Cup", "diff": "normal", "goal": 3, "prize": [3000, 1800, 1000], "rounds": [{"track": "polder", "time": "day", "weather": "dry", "laps": 2}, {"track": "dorp", "time": "day", "weather": "dry", "laps": 3}, {"track": "veluwe", "time": "day", "weather": "dry", "laps": 2}],
				"pre": ["kees", "Dit is hem: de Polder Cup. Drie races, punten tellen. Eindig bij de eerste drie en de grote teams gaan je zien."], "win": ["kees", "Wat een cup! Ik heb de hele tijd staan juichen."], "lose": ["kees", "Net niet. De punten tellen over alle races: elke plek telt, ook als je niet wint."]}]},
	{"id": "c2", "tab": "Delta", "cls": "A", "name": "De delta", "rival": ["ingrid", "evo"], "bonus": 5000,
		"intro": ["marloes", "Welkom bij Team Delta. Wij rijden klasse A, van de havens tot de Zeeuwse dijken. Onze kopvrouw Ingrid Bakker is de beste van het land. Laat zien dat je naast haar hoort."],
		"outro": ["marloes", "De Delta Trofee is van jou! Het team geeft je € 5.000 voor een klasse S-auto. En er is iemand die je wil spreken: de Baron zelf."],
		"events": [
			{"id": "a1", "kind": "race", "name": "Havennacht", "track": "haven", "time": "night", "laps": 2, "bots": 5, "diff": "normal", "goal": 3, "prize": [1100, 700, 450],
				"pre": ["marloes", "Eerste test: een nachtrace tussen de containers. Houd je hoofd koel."], "win": ["marloes", "Mooi. Ingrid keek mee, ik zag haar fronsen."], "lose": ["marloes", "Tussen de containers is het krap. Rem eerder, geef eerder gas."]},
			{"id": "a2", "kind": "race", "name": "Regen op de dijk", "track": "afsluitdijk", "weather": "rain", "laps": 2, "bots": 5, "diff": "normal", "goal": 3, "prize": [1300, 800, 500],
				"pre": ["kees", "Regen? Dat is juist jouw kans. De anderen durven niet. Jij wel."], "win": ["kees", "Ha! Net als ik vroeger."], "lose": ["kees", "In de regen win je in de bochten, niet op het rechte stuk."]},
			{"id": "a3", "kind": "elim", "name": "Zeeuwse eliminatie", "track": "zeeland", "bots": 5, "diff": "hard", "goal": 2, "prize": [1500, 900, 400],
				"pre": ["ingrid", "Dus jij bent de nieuwe. In Zeeland valt elke ronde iemand af. Ik hoop voor je dat jij het niet bent."], "win": ["ingrid", "Hm. Niet slecht. Maar een eliminatie is nog geen kampioenschap."], "lose": ["ingrid", "Zie je. Eén ronde te laat, en je staat aan de kant."]},
			{"id": "a4", "kind": "duel", "name": "Duel in de Maasstad", "track": "rotterdam", "time": "night", "laps": 2, "diff": "hard", "goal": 1, "prize": [2000, 500],
				"pre": ["ingrid", "Rotterdam, 's nachts, jij en ik. Geen teamorders. Laat maar zien wat je waard bent."], "win": ["ingrid", "...Je bent goed. Echt goed. Ik zie je in de Delta Trofee."], "lose": ["ingrid", "Je bent snel, maar je bent nog geen Ingrid Bakker."]},
			{"id": "A", "kind": "cup", "name": "Delta Trofee", "diff": "hard", "goal": 3, "prize": [5000, 3000, 1600], "rounds": [{"track": "haven", "time": "dusk", "weather": "dry", "laps": 2}, {"track": "afsluitdijk", "time": "day", "weather": "rain", "laps": 2}, {"track": "circuit", "time": "day", "weather": "dry", "laps": 2}, {"track": "polder", "time": "night", "weather": "dry", "laps": 2}],
				"pre": ["marloes", "De Delta Trofee. Vier races, en Ingrid wil winnen. Het hele team kijkt."], "win": ["ingrid", "Gefeliciteerd. Dat meen ik. Pas op voor de Baron: die verliest niet graag."], "lose": ["marloes", "Volgend jaar weer een kans. Of nu meteen, natuurlijk."]}]},
	{"id": "c3", "tab": "Oranje", "cls": "S", "name": "Oranje", "rival": ["baron", "v12"], "bonus": 6000,
		"intro": ["baron", "Zo. Jij bent dus het polderwonder waar iedereen het over heeft. Ik ben Joost van Dam, maar ze noemen me de Baron. In klasse S win ik al vijf jaar alles. Dat blijft zo."],
		"outro": ["kees", "Kampioen van Nederland! Mijn kleinkind! Hier, € 6.000 uit de spaarpot. Maar de Baron wil revanche, hoor ik..."],
		"events": [
			{"id": "s1", "kind": "race", "name": "Grachten bij nacht", "track": "grachten", "time": "night", "laps": 2, "bots": 5, "diff": "hard", "goal": 3, "prize": [2200, 1400, 900],
				"pre": ["kees", "Klasse S! Die auto's gaan harder dan mijn ouwe rallyauto ooit ging. Pas op de bruggetjes."], "win": ["kees", "Ik zat op het puntje van mijn stoel!"], "lose": ["kees", "Die bruggetjes... neem ze recht, dan blijf je op de weg."]},
			{"id": "s2", "kind": "race", "name": "Mist op de Veluwe", "track": "veluwe", "weather": "fog", "laps": 2, "bots": 5, "diff": "hard", "goal": 3, "prize": [2400, 1500, 1000],
				"pre": ["marloes", "Mist op de Veluwe. Je ziet de bochten pas als je erin zit. Vertrouw op je geheugen."], "win": ["marloes", "Blind rijden en toch winnen. De Baron heeft je gezien."], "lose": ["marloes", "Rij een paar rondjes tijdrit op de Veluwe, dan ken je de bochten uit je hoofd."]},
			{"id": "s3", "kind": "elim", "name": "Limburgse heuvels", "track": "limburg", "bots": 5, "diff": "hard", "goal": 2, "prize": [2800, 1600, 800],
				"pre": ["baron", "Heuvels, haarspelden en een eliminatie. Hier zie je wie echt kan rijden."], "win": ["baron", "Hm. Een toevalstreffer."], "lose": ["baron", "Zoals ik al zei."]},
			{"id": "s4", "kind": "duel", "name": "Duel met de Baron", "track": "circuit", "time": "dusk", "laps": 3, "diff": "extreme", "goal": 1, "prize": [4000, 800],
				"pre": ["baron", "Het circuit, drie ronden. Win je, dan rijd je mee in de Oranje Grand Prix. Verlies je, dan ga je terug naar je polder."], "win": ["baron", "...Onmogelijk. Goed dan. Tot in de Grand Prix."], "lose": ["baron", "De polder roept, geloof ik."]},
			{"id": "S", "kind": "cup", "name": "Oranje Grand Prix", "diff": "extreme", "goal": 3, "prize": [9000, 5000, 2500], "rounds": [{"track": "circuit", "time": "dusk", "weather": "dry", "laps": 3}, {"track": "veluwe", "time": "day", "weather": "fog", "laps": 2}, {"track": "haven", "time": "night", "weather": "dry", "laps": 2, "dir": "rev"}, {"track": "afsluitdijk", "time": "day", "weather": "dry", "laps": 2}, {"track": "dorp", "time": "night", "weather": "dry", "laps": 3, "dir": "rev"}],
				"pre": ["kees", "De Oranje Grand Prix. Vijf races. Ik heb een kaartje voor de tribune gekocht. Maak me trots."], "win": ["baron", "Ik... feliciteer je. Maar dit is nog niet voorbij."], "lose": ["baron", "Vijf jaar op rij. En volgend jaar weer."]}]},
	{"id": "c4", "tab": "Legende", "cls": "S", "name": "Legende", "rival": ["baron", "v12"], "bonus": 0,
		"intro": ["baron", "Je hebt de Grand Prix gewonnen. Knap. Maar echte legendes rijden de Tour van Nederland: elke uithoek van het land. Ingrid en Daan doen ook mee. Durf jij?"],
		"outro": ["kees", "Een legende! Kom, we gaan patat halen. Ik trakteer."],
		"events": [
			{"id": "l1", "kind": "duel", "name": "Revanche van Daan", "track": "zeeland", "dir": "rev", "time": "dusk", "laps": 2, "diff": "extreme", "goal": 1, "prize": [3000, 600], "rivals": [["daan", "speedster"]],
				"pre": ["daan", "Weet je nog, de patat? Ik heb gespaard en een Speedster gekocht. Revanche!"], "win": ["daan", "Oké, oké. Jij bent gewoon beter. Zullen we samen patat halen?"], "lose": ["daan", "Ha! Eindelijk! Dat was de patat van toen."]},
			{"id": "l2", "kind": "race", "name": "Ingrids laatste seizoen", "track": "haven", "dir": "rev", "laps": 3, "bots": 7, "diff": "hard", "goal": 1, "prize": [3500, 1500, 800], "rivals": [["ingrid", "hyper"]],
				"pre": ["ingrid", "Dit is mijn laatste seizoen. Ik ga niet zomaar opzij. Win maar eens van zeven man tegelijk."], "win": ["ingrid", "Van zeven man tegelijk. Dat had ik nooit gedacht: jij bent beter dan ik."], "lose": ["ingrid", "Nog niet, nieuwkomer. Nog niet."]},
			{"id": "l3", "kind": "elim", "name": "Nacht in het dorp", "track": "dorp", "dir": "rev", "time": "night", "bots": 6, "diff": "hard", "goal": 1, "prize": [4000, 2000, 1000], "rivals": [["baron", "v12"], ["daan", "speedster"]],
				"pre": ["kees", "Het dorp waar alles begon, maar dan 's nachts en achterstevoren. Zes tegenstanders, één winnaar."], "win": ["kees", "Het hele dorp stond op straat te juichen!"], "lose": ["kees", "In het donker lijken de straatjes smaller. Je kunt het, echt."]},
			{"id": "L", "kind": "cup", "name": "Tour van Nederland", "diff": "extreme", "goal": 3, "prize": [15000, 7000, 3500], "rivals": [["baron", "v12"], ["ingrid", "hyper"], ["daan", "speedster"]],
				"rounds": [{"track": "polder", "time": "dusk", "weather": "dry", "laps": 2}, {"track": "veluwe", "time": "day", "weather": "dry", "laps": 2}, {"track": "grachten", "time": "night", "weather": "dry", "laps": 2}, {"track": "limburg", "time": "day", "weather": "dry", "laps": 2}, {"track": "rotterdam", "time": "night", "weather": "dry", "laps": 2}, {"track": "zeeland", "time": "day", "weather": "rain", "laps": 2}],
				"pre": ["baron", "Zes races door heel Nederland, en wij drieën tegen jou. Na deze tour weet iedereen wie de beste is."], "win": ["baron", "Je bent een legende. Dat moet ik toegeven. Het was me een eer."], "lose": ["baron", "De Tour is zwaar. Zelfs voor een Grand Prix-kampioen."]}]}]
const CAREER_NAMES := ["Henk", "Fenna", "Sanne", "Bram", "Lotte", "Mees", "Noor", "Sem"]
## the settings a single career event borrows from the quick race (given back in toMenu via G.careerPrev)
const EV_KEYS := ["mode", "bots", "laps", "grid", "diff", "track", "dir", "time", "weather"]

var CAREER_EVS: Array = []
var CUPS: Array = []

func _ready() -> void:
	for c in CHAPTERS:
		for e in c.events: CAREER_EVS.append(e)
	CUPS = CAREER_EVS.filter(func(e): return e.kind == "cup")
	initGarage()

## JS start-up: the garage of an old save gets the cars it tuned, the career/achievement records, and you sit in a car you own
func initGarage() -> void:
	var g := G.garage
	if not g.has("owned"):
		g.owned = {"hatch": true}
		for id in g.cars:
			var u: Dictionary = g.cars[id]
			if u.get("eng", 0) or u.get("turbo", 0) or u.get("tyre", 0) or u.get("brake", 0): g.owned[id] = true
		G.saveGarage()
	if not g.has("career"): g.career = {"cups": {}}
	if not g.career.has("cups"): g.career.cups = {}
	if not g.career.has("bonus"): g.career.bonus = {}
	if not g.has("ach"): g.ach = {}
	if not g.has("wins"): g.wins = {}
	var a := ownedCar(G.settings.car)
	var b := ownedCar(G.settings.p2car)
	if a != G.settings.car or b != G.settings.p2car:
		G.settings.car = a
		G.settings.p2car = b
		G.saveSettings()

func chapterOf(ev: Dictionary) -> Dictionary:
	for c in CHAPTERS:
		for e in c.events:
			if e.id == ev.id: return c
	return CHAPTERS[0]

func evById(id: String):
	for e in CAREER_EVS:
		if e.id == id: return e
	return null

func owns(id: String) -> bool:
	return bool(G.garage.get("owned", {}).get(id, false))

## you only race cars you own: the last one you drove in that class, else another one of that class, else any car you own
func ownedCar(id: String) -> String:
	if Cars.CARS.has(id) and owns(id): return id
	var cls: String = Cars.CARS[id].cls if Cars.CARS.has(id) else "B"
	var lb: Dictionary = G.settings.get("lastByClass", {}) if G.settings.get("lastByClass") is Dictionary else {}
	if lb.get(cls) and owns(lb[cls]): return lb[cls]
	for c in Cars.carsOf(cls):
		if owns(c): return c
	for c in ["B", "A", "S"]:
		if lb.get(c) and owns(lb[c]): return lb[c]
	for c in Cars.CARS:
		if owns(c): return c
	return "hatch"

func ensureOwnedCars() -> bool:
	var a := ownedCar(G.settings.car)
	var b := ownedCar(G.settings.p2car)
	if a == G.settings.car and b == G.settings.p2car: return false
	G.settings.car = a
	G.settings.p2car = b
	G.saveSettings()
	if Game.car != null: Menu.previewEdit()
	return true

func evRes(ev: Dictionary):
	return G.garage.career.cups.get(ev.id)

func evPassed(ev: Dictionary) -> bool:
	var r = evRes(ev)
	return r != null and r.has("best") and float(r.best) <= ev.goal

func chUnlocked(ch: Dictionary) -> bool:
	var i := CHAPTERS.find(ch)
	if i <= 0: return true
	var prev: Array = CHAPTERS[i - 1].events
	return evPassed(prev[prev.size() - 1])

## the first event of an open chapter is open; the next one when this one met its goal (or when a later one was raced
## already: an old save). A cup under way (also from an old save) can always be finished.
func evUnlocked(ev: Dictionary) -> bool:
	var ch := chapterOf(ev)
	var k: int = ch.events.find(ev)
	var run = careerRun()
	if ev.kind == "cup" and run != null and run.get("career") == ev.id: return true
	if not chUnlocked(ch): return false
	if k == 0 or evPassed(ch.events[k - 1]): return true
	for e in ch.events.slice(k):
		if evRes(e) != null: return true
	return false

## where your career stands: the first event still to do in the furthest open chapter, else any event still to do anywhere
func careerNext():
	var open := CHAPTERS.filter(func(c): return chUnlocked(c))
	var todo := func(e): return evUnlocked(e) and not evPassed(e)
	for e in open[open.size() - 1].events:
		if todo.call(e): return e
	for e in CAREER_EVS:
		if todo.call(e): return e
	return null

## the cup under way (polderrace3d-career-run), or null
func careerRun():
	var r = Champ._parse(G.store_get("polderrace3d-career-run", "null"))
	if r == null or r.get("done", false): return null
	for c in CUPS:
		if c.id == r.get("career"): return r
	return null

func cupById(id) -> Variant:
	for c in CUPS:
		if c.id == id: return c
	return null

func buyCar(id: String) -> bool:
	var p: int = CAR_PRICE.get(id, 0)
	if owns(id) or G.garage.credits < p: return false
	G.garage.credits -= p
	G.garage.owned[id] = true
	G.saveGarage()
	Sfx.tone(880, 0.12, "triangle", 0.12); Sfx.tone(1320, 0.2, "triangle", 0.12, 0.1)
	if G.garage.owned.size() >= 6: Ach.unlockAch("collector")
	return true

## the bots of an event: the usual field with the chapter's rival(s) in their own car and colour (not your colour); the
## others get names that are not a character of the story
func careerDefs(ev: Dictionary) -> Array:
	var ch := chapterOf(ev)
	var n: int = 1 if ev.kind == "duel" else int(ev.get("bots", 5))
	var rv: Array = ev.get("rivals", [ch.rival]).slice(0, n)
	var defs: Array = Game.makeBotDefs(n)
	for k in rv.size():
		var R: Dictionary = RIVALS[rv[k][0]]
		var d: Dictionary = defs[defs.size() - 1 - k]
		d.name = R.name
		d.type = rv[k][1]
		d.color = R.color if R.color != G.settings.color else d.color
		d.rival = true
	var j := 0
	for d in defs:
		if not d.get("rival", false):
			d.name = CAREER_NAMES[j]
			j += 1
	return defs

func startCup(cup: Dictionary, carId: String, fresh: bool) -> void:
	var run = careerRun()
	if fresh or run == null or run.get("career") != cup.id: run = null
	G.settings.car = carId
	Game.rebuildPlayerCar()
	Champ.leaveChampMode()
	if run != null:
		Champ.champ = run
	else:
		var defs := careerDefs(cup)
		var c := {"career": cup.id, "rounds": cup.rounds.duplicate(true), "nRounds": cup.rounds.size(), "active": true, "car": carId, "color": G.settings.color,
			"cls": chapterOf(cup).cls, "diff": cup.diff, "round": 0, "bots": defs, "pts": {"Jij": 0}, "history": []}
		for d in defs: c.pts[d.name] = 0
		Champ.champ = c
	Champ.champ.active = true
	Champ.saveChamp()
	Menu.menuFlow = "champ"
	Champ.loadChampRound()
	Game.startRace()

## a single career event (race, elimination, duel) borrows the quick-race settings for one race; toMenu gives them back
func startCareerEvent(ev: Dictionary, carId: String) -> void:
	if ev.kind == "cup":
		startCup(ev, carId, false)
		return
	var S := G.settings
	S.car = carId
	Game.rebuildPlayerCar()
	if Champ.active():
		Champ.champ.active = false
		Champ.saveChamp()
	if G.careerPrev == null:
		G.careerPrev = {}
		for k in EV_KEYS: G.careerPrev[k] = S[k]
	S.mode = "elim" if ev.kind == "elim" else "race"
	S.bots = 1 if ev.kind == "duel" else int(ev.get("bots", 5))
	S.laps = int(ev.get("laps", 2))
	S.grid = ev.get("grid", "back")
	S.diff = ev.diff
	S.track = ev.track
	S.dir = ev.get("dir", "fwd")
	S.time = ev.get("time", "day")
	S.weather = ev.get("weather", "dry")
	G.careerEv = {"ev": ev, "defs": careerDefs(ev), "res": null}
	Menu.menuFlow = "quick"
	if Trk.TRACK_ID != ev.track or Trk.TRACK_DIR != S.dir: Menu.loadTrack(ev.track, S.dir)
	Menu.applyEnv(S.time, S.weather)
	Game.startRace()

## an event is over (a race, or a cup's final standings): keep the best result, pay a chapter's bonus the first time its
## finale is passed, open what comes next. Returns what the results screen shows.
func careerEventDone(ev: Dictionary, pos: int) -> Dictionary:
	var ch := chapterOf(ev)
	var was := evPassed(ev)
	var r: Dictionary = G.garage.career.cups.get(ev.id, {})
	r.best = mini(int(r.get("best", 99)), pos)
	if pos == 1: r.won = true
	G.garage.career.cups[ev.id] = r
	var passed: bool = pos <= ev.goal
	var fin: bool = ev.id == ch.events[ch.events.size() - 1].id
	var bonus := 0
	if passed and fin and ch.bonus and not G.garage.career.bonus.get(ch.id, false):
		G.garage.career.bonus[ch.id] = true
		bonus = G.addCredits(ch.bonus)
	G.saveGarage()
	if pos == 1 and fin: Ach.unlockAch("cup" + ev.id)
	var allDuels := true
	for e in CAREER_EVS:
		if e.kind == "duel" and not (evRes(e) != null and evRes(e).get("won", false)): allDuels = false
	if allDuels: Ach.unlockAch("duels")
	var unlocked := ""
	if passed and not was:
		var k: int = ch.events.find(ev)
		var ci := CHAPTERS.find(ch)
		var nx = ch.events[k + 1] if k + 1 < ch.events.size() else null
		var nc = CHAPTERS[ci + 1] if ci + 1 < CHAPTERS.size() else null
		unlocked = nx.name if nx != null else ("Hoofdstuk %d: %s" % [ci + 2, nc.name] if fin and nc != null else "")
		if unlocked != "": Hud.showToast(unlocked + " vrijgespeeld!")
	return {"passed": passed, "first": passed and not was, "bonus": bonus, "fin": fin, "chi": CHAPTERS.find(ch), "unlocked": unlocked}

static func goalText(g) -> String:
	return "winnen" if int(g) == 1 else "top %d" % int(g)

## the line under an event's name: kind, track, laps, opponents, time and weather
func evSub(ev: Dictionary) -> String:
	var tr := func(r: Dictionary) -> String: return TrackDefs.TRACKS[r.track].name + (" omgekeerd" if r.get("dir") == "rev" else "")
	if ev.kind == "cup":
		return "%d races · %s" % [ev.rounds.size(), ", ".join(ev.rounds.map(func(r): return tr.call(r)))]
	var n: int = 1 if ev.kind == "duel" else int(ev.get("bots", 5))
	var L: int = n if ev.kind == "elim" else int(ev.get("laps", 2))
	var s: String = EV_KIND[ev.kind] + " · " + tr.call(ev) + " · %d%s" % [L, " ronde" if L == 1 else " ronden"]
	if ev.kind != "duel": s += " · %d tegenstanders" % n
	if ev.get("time", "day") != "day": s += " · " + Env.TIME_NAMES[ev.time].to_lower()
	if ev.get("weather", "dry") != "dry": s += " · " + Env.WEATHER_NAMES[ev.weather].to_lower()
	return s

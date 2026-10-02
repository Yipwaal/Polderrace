extends Node
## Autoload "Ach": the achievements of the HTML game (JS: ACH, unlockAch, achRaceStart, achRaceEnd, achPit). An unlocked
## achievement pays its reward and shows the yellow popup (Menu.achPopup), one after the other.

const ACH := [["first_win", "Eerste overwinning", "Win een race", 300], ["all_tracks", "Nederland rond", "Win op alle banen", 1500], ["pit", "PIT-manoeuvre", "Laat een bot uitspinnen met een tik", 400],
	["pit3", "Sloopkogel", "Laat 3 bots uitspinnen in één race", 800], ["clean", "Schone race", "Win zonder een andere auto te raken", 600], ["speed300", "300-club", "Rij 300 km/u", 500],
	["ghost", "Ghost-jager", "Zet een ghost-ronde neer", 200], ["elim", "Laatste man", "Win een eliminatierace", 500], ["tt5", "Lange adem", "Rij 5 km in een tijdrit", 400],
	["night", "Nachtbraker", "Win een race in het donker", 400], ["rain", "Regenmeester", "Win een race in de regen", 400], ["comeback", "Van achteren", "Win vanaf de laatste startplek met 5+ bots", 700],
	["champ", "Kampioen", "Win een los kampioenschap", 1000], ["cupB", "Polder Cup", "Win de Polder Cup", 1000], ["cupA", "Delta Trofee", "Win de Delta Trofee", 2000], ["cupS", "Oranje Grand Prix", "Win de Oranje Grand Prix", 4000], ["cupL", "Legende", "Win de Tour van Nederland", 6000], ["duels", "Rivalen verslagen", "Win alle duels in de carrière", 1500],
	["maxed", "Volledig getuned", "Breng alle upgrades van één auto naar max", 600], ["rich", "Spaarpot", "Heb € 20.000 op zak", 1000], ["collector", "Verzamelaar", "Bezit 6 auto's", 1500]]

var achQueue: Array = []
var achBusy := false

static func achInfo(id: String) -> Array:
	for a in ACH:
		if a[0] == id: return a
	return []

func got(id: String) -> bool:
	return G.garage.get("ach", {}).has(id)

func count() -> int:
	return ACH.filter(func(a): return got(a[0])).size()

func unlockAch(id: String) -> void:
	if not G.garage.has("ach"): G.garage.ach = {}
	if G.garage.ach.has(id): return
	var a := achInfo(id)
	if a.is_empty(): return
	G.garage.ach[id] = int(Time.get_unix_time_from_system() * 1000)
	G.garage.credits += a[3]
	G.saveGarage()
	achQueue.append(a)
	if not achBusy: nextAch()

func nextAch() -> void:
	if achQueue.is_empty():
		achBusy = false
		return
	var a: Array = achQueue.pop_front()
	achBusy = true
	Menu.achPopup(a[1], a[2] + " · +" + G.fmtCr(a[3]), true)
	Sfx.tone(660, 0.12, "triangle", 0.12); Sfx.tone(990, 0.12, "triangle", 0.12, 0.12); Sfx.tone(1320, 0.25, "triangle", 0.12, 0.24)
	get_tree().create_timer(2.6, true, false, true).timeout.connect(func() -> void:
		Menu.achPopup("", "", false)
		get_tree().create_timer(0.25, true, false, true).timeout.connect(nextAch))

func achRaceStart() -> void:
	Game.raceContacts = 0
	Game.racePits = 0

func achRaceEnd(pos: int) -> void:
	var mode: String = Game.mode
	if pos == 1 and (mode == "race" or mode == "champ" or mode == "elim"):
		unlockAch("first_win")
		G.garage.wins[Trk.TRACK_ID] = true
		G.saveGarage()
		if TrackDefs.TRACKS.keys().all(func(t): return G.garage.wins.get(t, false)): unlockAch("all_tracks")
		if Game.raceContacts == 0: unlockAch("clean")
		var env := Env.me
		if env != null and env.time == "night": unlockAch("night")
		if env != null and env.weather == "rain": unlockAch("rain")
		if mode == "elim": unlockAch("elim")
		if mode == "race" and G.settings.grid == "back" and Game.bots.size() >= 5: unlockAch("comeback")

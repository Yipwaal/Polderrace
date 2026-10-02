extends Node
## Autoload "Champ": the championship of the HTML game (JS section "championship"): a loose championship of six rounds
## against five fixed opponents, and the career cups, which run through the same `champ` record (champ.career = cup id,
## saved under polderrace3d-career-run instead of polderrace3d-champ). Same names, same fields, same save data.

const CHAMP_PTS := [10, 8, 6, 5, 4, 3, 2, 1]
const CHAMP_ALL := [{"track": "polder", "time": "day", "weather": "dry", "laps": 2}, {"track": "dorp", "time": "dusk", "weather": "dry", "laps": 3},
	{"track": "haven", "time": "night", "weather": "dry", "laps": 2}, {"track": "afsluitdijk", "time": "day", "weather": "rain", "laps": 2, "dir": "rev"},
	{"track": "veluwe", "time": "day", "weather": "fog", "laps": 2}, {"track": "circuit", "time": "dusk", "weather": "dry", "laps": 2, "dir": "rev"}]
var CHAMP_ROUNDS: Array = CHAMP_ALL.filter(func(r): return TrackDefs.TRACKS.has(r.track))

## the championship under way (or the last one), a Dictionary {nRounds, active, car, color, cls, diff, round, bots, pts,
## history, [career, rounds, done, bonusPaid, res]} or null
var champ = null
## the quick-race difficulty, kept while a championship plays at its own (given back in toMenu)
var champPrevDiff = null

func _ready() -> void:
	reload()

## the championship from the save data (start-up, or after G.use_store)
func reload() -> void:
	champPrevDiff = null
	champ = _parse(G.store_get("polderrace3d-champ", "null"))
	if champ != null and champ.get("rounds") == null and int(champ.get("nRounds", -1)) != CHAMP_ROUNDS.size():
		champ = null

## a championship record from JSON (numbers come back as floats: round is used as an index)
static func _parse(s):
	if s == null: return null
	var c = JSON.parse_string(str(s))
	if not (c is Dictionary): return null
	c.round = int(c.get("round", 0))
	if c.get("rounds") is Array:
		for r in c.rounds: r.laps = int(r.laps)
	return c

## the rounds being raced: a career cup's own, else the championship's
func CR() -> Array:
	return champ.rounds if champ != null and champ.get("rounds") is Array else CHAMP_ROUNDS

func active() -> bool:
	return champ != null and bool(champ.get("active", false))

func saveChamp() -> void:
	G.store_set("polderrace3d-career-run" if champ != null and champ.get("career") else "polderrace3d-champ", JSON.stringify(champ))

func loadQuickChamp():
	var c = _parse(G.store_get("polderrace3d-champ", "null"))
	if c != null and int(c.get("nRounds", -1)) != CHAMP_ROUNDS.size(): c = null
	return c

func newChamp() -> void:
	var S := G.settings
	var defs: Array = Game.makeBotDefs(5)
	champ = {"nRounds": CHAMP_ROUNDS.size(), "active": true, "car": S.car, "color": S.color, "cls": Cars.CARS[S.car].cls, "diff": S.diff, "round": 0,
		"bots": defs, "pts": {"Jij": 0}, "history": []}
	for d in defs: champ.pts[d.name] = 0
	saveChamp()

func champInProgress() -> bool:
	return champ != null and not champ.get("career") and not champ.get("done", false) and int(champ.round) < CR().size()

## the next round: its car, colour, difficulty, track and weather
func loadChampRound() -> void:
	var r: Dictionary = CR()[int(champ.round)]
	var S := G.settings
	S.car = champ.car
	S.color = champ.color
	if champPrevDiff == null: champPrevDiff = S.diff
	S.diff = champ.diff
	if Game.car == null or Game.car.get("type") != champ.car: Game.rebuildPlayerCar()
	var dir: String = r.get("dir", "fwd")
	if Trk.TRACK_ID != r.track or Trk.TRACK_DIR != dir: Menu.loadTrack(r.track, dir)
	Menu.applyEnv(r.time, r.weather)

## points for the race just finished (once per round)
func champRecordRace() -> void:
	if champ.history.size() > int(champ.round): return
	var order: Array = Game.resultRows.map(func(r): return "Jij" if r.get("me", false) else r.name)
	for k in order.size():
		champ.pts[order[k]] = champ.pts.get(order[k], 0) + (CHAMP_PTS[k] if k < CHAMP_PTS.size() else 0)
	champ.history.append(order)
	champ.round = int(champ.round) + 1
	saveChamp()

func champStandings() -> Array:
	var out := []
	var names: Array = champ.pts.keys()
	for k in names.size():
		var n: String = names[k]
		var type := "gt"
		for b in champ.bots:
			if b.name == n: type = b.type
		out.append({"name": n, "pts": champ.pts[n], "me": n == "Jij", "car": Cars.CARS[champ.car if n == "Jij" else type].name, "_k": k})
	# JS sort((a,b)=>b.pts-a.pts||(a.me?-1:1)): more points first, you first on a tie, the rest keep their order
	out.sort_custom(func(a, b):
		if a.pts != b.pts: return a.pts > b.pts
		if a.me != b.me: return a.me
		return a._k < b._k)
	return out

## leave a championship (JS leaveChampMode, menu section): inactive, the quick-race difficulty, track and weather back
func leaveChampMode() -> void:
	if champ != null and champ.get("active", false):
		champ.active = false
		saveChamp()
	if champPrevDiff != null:
		G.settings.diff = champPrevDiff
		champPrevDiff = null
	if Trk.TRACK_ID != G.settings.track or Trk.TRACK_DIR != G.settings.dir: Menu.loadTrack(G.settings.track)
	Menu.applyEnv(G.settings.time, G.settings.weather)

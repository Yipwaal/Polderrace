extends Node
## Autoload "G": storage, settings, preferences and the garage (JS: store, DIFF, settings, prefs, garage, effStats, ...).
## Same keys and fields as the HTML game, so the save data reads the same.

const VERSION := "0.1-godot"

# ------------------------------------------------------------------ store (JS localStorage)
## everything the HTML game keeps in localStorage, as strings under the same keys, in one JSON file
const STORE_PATH := "user://polderrace3d.json"
var _store := {}

func _init() -> void:
	if FileAccess.file_exists(STORE_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(STORE_PATH))
		if d is Dictionary:
			_store = d
	_load_settings()

func store_get(k: String, d = null):
	return _store.get(k, d)

func store_set(k: String, v) -> void:
	_store[k] = str(v)
	var f := FileAccess.open(STORE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_store))

func _json(k: String, d):
	var s = store_get(k)
	if s == null:
		return d
	var v = JSON.parse_string(s)
	return d if v == null else v

# ------------------------------------------------------------------ settings
const DIFF := {
	"easy": {"rec": 1.3, "pay": 0.6, "mist": 1.0 / 14, "name": "Makkelijk", "speed": 0.94, "acc": 0.97, "aLat": 34, "brake": 24, "catchUp": 1.04, "slow": true, "jit": 0.07},
	"normal": {"rec": 1.6, "pay": 1, "mist": 1.0 / 32, "name": "Normaal", "speed": 1.0, "acc": 1.05, "aLat": 42, "brake": 28, "catchUp": 1.06, "slow": false, "jit": 0.05},
	"hard": {"rec": 1.9, "pay": 1.4, "mist": 0, "name": "Moeilijk", "speed": 1.04, "acc": 1.12, "aLat": 50, "brake": 33, "catchUp": 1.08, "slow": false, "jit": 0.035},
	"extreme": {"rec": 2.2, "pay": 1.8, "mist": 0, "name": "Extreem", "speed": 1.08, "acc": 1.2, "aLat": 60, "brake": 38, "catchUp": 1.12, "slow": false, "jit": 0.015}}
const ACC_K := 0.48
const BRK_K := 0.72

var settings := {"car": "gt", "color": "#f36f21", "track": "polder", "dir": "fwd", "bots": 5, "diff": "normal", "laps": 3, "grid": "back", "mode": "race",
	"time": "day", "weather": "dry", "p2car": "hatch", "p2color": "#1d4f9e"}
var prefs := {"sound": true, "fx": true, "cam": 0, "damage": true, "gearbox": "auto", "mirror": true}
## careerEv: the career event being raced (race, elimination or duel); careerPrev: the quick-race settings it borrowed,
## given back in toMenu and never saved over
var careerEv = null
var careerPrev = null

var garage := {"credits": 500, "cars": {}}

func _load_settings() -> void:
	settings.merge(_json("polderrace3d-settings", {}), true)
	if not Cars.CARS.has(settings.car): settings.car = "gt"
	if not TrackDefs.TRACKS.has(settings.track): settings.track = "polder"
	if not DIFF.has(settings.diff): settings.diff = "normal"
	if settings.dir != "rev": settings.dir = "fwd"
	if not settings.mode in ["race", "elim", "time", "ghost", "split"]:
		settings.mode = "race" if int(settings.bots) > 0 else "time"
	settings.bots = clampi(int(settings.bots), 0 if settings.mode == "split" else 1, 7)
	settings.laps = clampi(int(settings.laps), 1, 5)
	prefs.merge(_json("polderrace3d-prefs", {}), true)
	if not prefs.has("quality"):
		prefs.quality = "low" if prefs.get("shadows", true) == false else "high"
	garage.merge(_json("polderrace3d-garage", {}), true)
	# damage was removed: refund what was spent on the old 'Versteviging' upgrade
	var refund := 0
	for id in garage.cars:
		var u: Dictionary = garage.cars[id]
		if u.get("body", 0) and Cars.CARS.has(id):
			for l in int(u.body):
				refund += int(round([300, 650, 1200][l] * CLS_COST[Cars.CARS[id].cls] / 50.0)) * 50
			u.body = 0
	if refund:
		garage.credits += refund
		saveGarage()

func saveSettings() -> void:
	var s := settings.duplicate()
	if careerPrev != null:
		s.merge(careerPrev, true)
	store_set("polderrace3d-settings", JSON.stringify(s))

func savePrefs() -> void:
	store_set("polderrace3d-prefs", JSON.stringify(prefs))

# ------------------------------------------------------------------ garage & credits
const UPG := [{"k": "eng", "name": "Motor", "desc": "Topsnelheid +3% per niveau", "cost": [600, 1200, 2200]},
	{"k": "turbo", "name": "Turbo", "desc": "Acceleratie +6% per niveau", "cost": [500, 1000, 1900]},
	{"k": "tyre", "name": "Banden", "desc": "Grip +4% per niveau", "cost": [450, 900, 1700]},
	{"k": "brake", "name": "Remmen", "desc": "Remkracht +8% per niveau", "cost": [300, 650, 1200]}]
const CLS_COST := {"B": 1, "A": 1.4, "S": 1.9}
const RIMS := {"silver": ["Zilver", 0xa1a4a8], "black": ["Zwart", 0x222428], "gold": ["Goud", 0xc9a227], "white": ["Wit", 0xf2f2ee]}
const STRIPES := {"std": ["Standaard", "std"], "none": ["Geen", null], "white": ["Wit", 0xf7f7f2], "black": ["Zwart", 0x1d1f24], "yellow": ["Geel", 0xf2c200]}
const WINGS := {"std": "Af fabriek", "duck": "Ducktail", "gt": "GT-vleugel"}
const RIMSTYLES := {"std": "Standaard", "spoke": "Spaken", "dish": "Diep"}
const EXHAUSTS := {"std": "Af fabriek", "sport": "Sport", "dual": "Dubbel", "center": "Centraal"}

func saveGarage() -> void:
	store_set("polderrace3d-garage", JSON.stringify(garage))

static func fmtCr(n: float) -> String:
	var s := str(int(round(n)))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return "€ " + s + out

func carUp(id: String) -> Dictionary:
	if not garage.cars.has(id):
		garage.cars[id] = {"eng": 0, "turbo": 0, "tyre": 0, "brake": 0, "body": 0, "rim": "silver", "stripe": "std"}
	var u: Dictionary = garage.cars[id]
	if not u.has("num"):
		u.num = 0; u.wing = "std"; u.rimStyle = "std"
	if not u.get("exhaust", ""):
		u.exhaust = "std"
	return u

func upCost(id: String, u: Dictionary, lvl: int) -> int:
	return int(round(u.cost[lvl] * CLS_COST[Cars.CARS[id].cls] / 50.0)) * 50

func effStats(id: String) -> Dictionary:
	var c: Dictionary = Cars.CARS[id]
	var u: Dictionary = garage.cars.get(id, {})
	return {"vmax": c.vmax * (1 + 0.03 * u.get("eng", 0)), "acc": c.acc * (1 + 0.06 * u.get("turbo", 0)),
		"grip": c.grip * (1 + 0.04 * u.get("tyre", 0)), "brake": c.brake * (1 + 0.08 * u.get("brake", 0))}

func addCredits(n: float) -> int:
	var v := maxi(0, int(round(n / 10.0)) * 10)
	garage.credits += v
	saveGarage()
	if garage.credits >= 20000 and has_method("unlockAch"):
		call("unlockAch", "rich")
	return v

# ------------------------------------------------------------------ formatting (JS fmtKm, fmtLap, fmtD)
static func fmtKm(m: float) -> String:
	return ("%.1f" % (m / 1000.0)).replace(".", ",") + " km"

static func fmtLap(t: float) -> String:
	var m := int(floor(t / 60.0))
	var s := t - m * 60
	return "%d:%s%s" % [m, "0" if s < 10 else "", ("%.1f" % s).replace(".", ",")]

static func fmtD(t: float) -> String:
	return ("−" if t < 0 else "+") + ("%.2f" % absf(t)).replace(".", ",")

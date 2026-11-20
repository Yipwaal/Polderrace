extends Node
## Autoload "G": storage, settings, preferences and the garage (JS: store, DIFF, settings, prefs, garage, effStats, ...).
## Same keys and fields as the HTML game, so the save data reads the same.

const VERSION := "0.1-godot"

# ------------------------------------------------------------------ store (JS localStorage)
## everything the HTML game keeps in localStorage, as strings under the same keys, in one JSON file
var STORE_PATH := "user://polderrace3d.json"
var _store := {}

## tests and tools: play on their own save file (seeded with data: {key: value}, values as the JS stores them), never
## the player's; settings, preferences and garage are read again from it
func use_store(path: String, data: Dictionary = {}) -> void:
	STORE_PATH = path
	_store = {}
	for k in data:
		_store[k] = data[k] if data[k] is String else JSON.stringify(data[k])
	settings = _defaults.settings.duplicate(true)
	prefs = _defaults.prefs.duplicate(true)
	garage = _defaults.garage.duplicate(true)
	careerEv = null
	careerPrev = null
	_load_settings()
	_write()
	# the career/achievement records of the garage, the championship and the key bindings come from the store too
	Career.initGarage()
	Champ.reload()
	Game.binds = Game.DEFAULT_BINDS.duplicate(true)
	Game._load_binds()
	# like a fresh start on this save: the menus forget what was picked this session (career event, open tabs)
	Menu.careerSel = null
	Menu.careerCh = null
	if Menu.garageUI != null: Menu.garageUI.garTab("perf")
	if Menu.settingsUI != null: Menu.settingsUI.showTab("general")

var _defaults := {}

func _init() -> void:
	_defaults = {"settings": settings.duplicate(true), "prefs": prefs.duplicate(true), "garage": garage.duplicate(true)}
	# (a crash between writing the temporary file and renaming it leaves only that one)
	for path in [STORE_PATH, STORE_PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			var d = JSON.parse_string(FileAccess.get_file_as_string(path))
			if d is Dictionary:
				_store = d
				break
	_load_settings()

func _ready() -> void:
	# the car module styles cars from the garage entry (JS carUp), plus what hangs in the fitting room
	CarKit.up_of = styleUp

func store_get(k: String, d = null):
	return _store.get(k, d)

func store_set(k: String, v) -> void:
	_store[k] = str(v)
	if not _dirty:
		_dirty = true
		_flush.call_deferred()

## the save file holds everything (ghosts too) and a lap end sets several keys: write it at most once per frame, and on quit
var _dirty := false

func _flush() -> void:
	if _dirty:
		_dirty = false
		_write()

## via a temporary file, so a crash halfway through never leaves a broken save
func _write() -> void:
	var tmp := STORE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_store))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(STORE_PATH))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_flush()

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
	var saved = _json("polderrace3d-garage", null)
	garage.merge(saved if saved is Dictionary else {}, true)
	# looks you own (see "looks" below). A save from before the catalogue keeps the free colour picker it had.
	if not (garage.get("looks") is Dictionary):
		garage.looks = {"mix": 1} if saved is Dictionary else {}
	fit = {"car": "", "look": {}}
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
## (the looks of a car, their names and prices: the catalogue CarLook.ITEMS in scripts/car/car_look.gd)

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
	# stripes from before the catalogue: the colour was the choice
	var st = u.get("stripe")
	if st is String and CarLook.OLD_STRIPES.has(st):
		u.sc = CarLook.OLD_STRIPES[st]
		u.stripe = "twin"
	return u

# ------------------------------------------------------------------ looks (catalogue: CarLook.ITEMS)
# A car's look lives in its garage entry (carUp) next to the upgrades, one value per catalogue key; its paint colour in
# `col` (settings.color is the colour of the car you sit in). What you own is account-wide: garage.looks holds
# "<key>:<option>" for a bought option, "<key>" for a bought kit (neon, own plate, ...) and "mix" for the colour mixer.
# Looking is free: a choice you do not own hangs in the fitting room (fit) and shows on the car in the garage only; it
# is never saved on the car and never part of lookOf().

## the fitting room: the unpaid choices shown on `car` in the garage
var fit := {"car": "", "look": {}}

## the appearance of a car as a small JSON-safe Dictionary: everything CarKit.styleCar needs (CarKit.buildCar(type,
## look.paint) + CarKit.styleCar(m, look) gives the same car anywhere), without the performance upgrades
func lookOf(id: String) -> Dictionary:
	var u: Dictionary = carUp(id) if Cars.CARS.has(id) else {}
	var L := CarLook.compact(CarLook.clean(u, id))
	var c = settings.color if id == settings.car else u.get("col", settings.color)
	L.paint = ("#" + Color(str(c)).to_html(false)) if Color.html_is_valid(str(c)) else "#ffffff"
	return L

## what CarKit styles a car of yours from: its garage entry, with the fitting room's choices on top
func styleUp(id: String) -> Dictionary:
	var u := carUp(id)
	if fit.car != id or fit.look.is_empty(): return u
	var o := u.duplicate()
	o.merge(fit.look, true)
	return o

## the paint colour belongs to the car: the car you leave remembers its colour, a car that has one gets it back
func carPicked(old: String, new: String) -> void:
	if old == new or not Cars.CARS.has(new): return
	if Cars.CARS.has(old): carUp(old).col = settings.color
	var c = carUp(new).get("col")
	if c is String and Color.html_is_valid(c): settings.color = c
	saveGarage()

func lookHas(key: String) -> bool:
	return garage.get("looks", {}).has(key)

## what a value still costs you: [[own key, price, label, locked], ...]; empty = free or yours. locked (a text) = not for
## sale: an achievement unlocks it
func lookNeeds(k: String, v) -> Array:
	var it := CarLook.item(k)
	var out := []
	if it.is_empty() or (typeof(v) == typeof(it.def) and v == it.def): return out
	if it.has("kit") and not lookHas(k): out.append([k, int(it.kit), it.name, ""])
	var o = CarLook.option(k, v)
	if o != null:
		var ex: Dictionary = o[3] if o.size() > 3 else {}
		if ex.has("ach"):
			if not Ach.got(ex.ach): out.append([k + ":" + o[0], 0, "%s: %s" % [it.name, o[1]], Ach.achInfo(ex.ach)[2]])
		elif int(o[2]) > 0 and not lookHas(k + ":" + o[0]):
			out.append([k + ":" + o[0], int(o[2]), "%s: %s" % [it.name, o[1]], ""])
	elif it.type == "color" and v is String and v != "" and not lookHas("mix"):
		out.append(["mix", CarLook.MIX_PRICE, "Kleurenmenger", ""])
	return out

## the value of a key as the garage shows it on the car: the fitting room's, else the saved one
func lookShown(car: String, k: String):
	if fit.car == car and fit.look.has(k): return fit.look[k]
	if k == "paint": return lookOf(car).paint
	return CarLook.clean(carUp(car), car)[k]

## choose a value in the garage: yours (or free) is saved on the car, anything else goes to the fitting room
func lookPick(car: String, k: String, v) -> void:
	if CarLook.item(k).is_empty() or not Cars.CARS.has(car): return
	if fit.car != car: fit = {"car": car, "look": {}}
	v = CarLook.cleanValue(k, v)
	if k == "paint" and v == "": return
	if lookNeeds(k, v).is_empty():
		fit.look.erase(k)
		_lookSave(car, k, v)
	else:
		fit.look[k] = v

func _lookSave(car: String, k: String, v) -> void:
	var u := carUp(car)
	if k == "paint":
		u.col = v
		if car == settings.car:
			settings.color = v
			saveSettings()
	else:
		u[k] = v
	saveGarage()

## what is in the fitting room and what it costs: {items: [[own key, price, label, locked], ...], total, locked}
func fitCost() -> Dictionary:
	var items := []
	var seen := {}
	var total := 0
	var locked := 0
	for k in fit.look:
		for n in lookNeeds(k, fit.look[k]):
			if seen.has(n[0]): continue
			seen[n[0]] = true
			items.append(n)
			if n[3] != "": locked += 1
			else: total += int(n[1])
	return {"items": items, "total": total, "locked": locked}

## pay for what is in the fitting room; what is still locked stays there. false = not enough credits
func fitBuy() -> bool:
	var c := fitCost()
	if c.total > int(garage.credits): return false
	garage.credits -= c.total
	for n in c.items:
		if n[3] == "": garage.looks[n[0]] = 1
	var car: String = fit.car
	for k in fit.look.keys():
		if lookNeeds(k, fit.look[k]).is_empty():
			_lookSave(car, k, fit.look[k])
			fit.look.erase(k)
	saveGarage()
	return true

## put back everything that is not paid for; true = there was something
func fitClear() -> bool:
	var had: bool = not fit.look.is_empty()
	fit = {"car": "", "look": {}}
	return had

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
	if garage.credits >= 20000:
		Ach.unlockAch("rich")
	return v

# ------------------------------------------------------------------ formatting (JS toFixed, fmtKm, fmtLap, fmtD)
## JS Number.toFixed(f): the decimal closest to x; when x lies exactly halfway (2.25 with one decimal) the one away from
## zero, where printf ("%.1f") rounds to even. Such a tie is x * 2^(f+1) being an odd whole number.
static func toFixed(x: float, f: int) -> String:
	var a := absf(x)
	var p := a * pow(2.0, f + 1)
	if p == floor(p) and fmod(p, 2.0) == 1.0 and p < 1e15:
		var s := str(int(floor(a * pow(10.0, f))) + 1)
		if f > 0:
			s = s.lpad(f + 1, "0")
			s = s.substr(0, s.length() - f) + "." + s.substr(s.length() - f)
		return ("-" if x < 0 else "") + s
	return ("%." + str(f) + "f") % x

static func fmtKm(m: float) -> String:
	return toFixed(m / 1000.0, 1).replace(".", ",") + " km"

static func fmtLap(t: float) -> String:
	var m := int(floor(t / 60.0))
	var s := t - m * 60
	return "%d:%s%s" % [m, "0" if s < 10 else "", toFixed(s, 1).replace(".", ",")]

static func fmtD(t: float) -> String:
	return ("−" if t < 0 else "+") + toFixed(absf(t), 2).replace(".", ",")

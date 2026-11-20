class_name CarLook
## The looks of a car. One catalogue (ITEMS) holds everything a player can change about the appearance of a car, the
## "look" is a small JSON-safe Dictionary {key: value} that describes one car (what G.lookOf(car) returns, what the garage
## saves per car and what players send each other online), and pre()/post() put a look on a built car: CarKit.styleCar
## calls pre() before its own standard parts (rims, factory stripes, start number, wing, exhaust) and post() after them.
##
## Catalogue item: {k: key in the look, g: garage group, name, sub, type, def: default value, view: garage camera,
##   fit: "" | "cab" (cars with a roof) | "BA" (classes B and A), kit: price that unlocks the item (every value but the
##   default), mix: a free colour ("#rrggbb") is allowed (needs the colour mixer), none: label of the "off" value "",
##   opts: [[id, name, price, {hex, ach, cols, n}], ...]}
##   type "choice": one of opts.  type "color": a preset id of opts (hex in its extra) or "#rrggbb".
##   type "num": 0..99.  type "text": upper-case text of at most `max` characters out of `chars`.
## Prices are credits; an option with "ach" is not for sale: it is unlocked by that achievement (Ach).
## Nothing here changes how a car drives or its hitbox.
##
## A look is always passed through clean() first: unknown keys are dropped, junk values fall back to the default, so a
## look from an old save or from another player online can never break a car.

const MIX_PRICE := 600      ## the colour mixer: free colours ("#rrggbb") everywhere a colour is chosen
const GROUPS := [["lak", "Lak"], ["stripe", "Striping"], ["wheel", "Wielen"], ["glass", "Ruiten & licht"], ["num", "Nummer"], ["decal", "Stickers"], ["parts", "Onderdelen"]]

const PAINTS := [["#f36f21", "Oranje", 0], ["#d62a2a", "Rood", 0], ["#f2c200", "Geel", 0], ["#1d4f9e", "Blauw", 0], ["#2f8f5b", "Groen", 0], ["#f2f2ee", "Wit", 0], ["#1b1b1b", "Zwart", 0],
	["#e8451e", "Vuurrood", 150], ["#8c1c24", "Bordeaux", 150], ["#ff4f8b", "Tulpenroze", 150], ["#f5a3b8", "Zuurstok", 150], ["#7a2fbf", "Paars", 150], ["#3a2466", "Aubergine", 150],
	["#0f2a5c", "Nachtblauw", 150], ["#2a6fdb", "Delfts blauw", 150], ["#4fb3e8", "IJsblauw", 150], ["#18b5a8", "Turquoise", 150], ["#9ad0c2", "Mint", 150],
	["#0f5b3f", "Racegroen", 150], ["#6cc04a", "Grasgroen", 150], ["#b7d433", "Limoen", 150], ["#f0e6c0", "Vla", 150], ["#c2b59b", "Duinzand", 150],
	["#c9a227", "Goud", 150], ["#b5651d", "Koper", 150], ["#5b3a1e", "Chocola", 150], ["#8a8d92", "Zilver", 150], ["#3f444b", "Antraciet", 150]]
## the colours of stripes, numbers and bands (all free)
const BASIC := [["white", "Wit", 0, {"hex": "#f7f7f2"}], ["black", "Zwart", 0, {"hex": "#1d1f24"}], ["yellow", "Geel", 0, {"hex": "#f2c200"}], ["red", "Rood", 0, {"hex": "#d62a2a"}],
	["orange", "Oranje", 0, {"hex": "#f36f21"}], ["blue", "Blauw", 0, {"hex": "#1d4f9e"}], ["green", "Groen", 0, {"hex": "#2f8f5b"}], ["silver", "Zilver", 0, {"hex": "#a1a4a8"}],
	["gold", "Goud", 0, {"hex": "#c9a227"}], ["pink", "Roze", 0, {"hex": "#ff4f8b"}]]
const STICKERS := [["", "Geen", 0], ["polder", "Polderrace", 120], ["tulp", "Tulp", 120], ["molen", "Molen", 120], ["kaas", "Kaas", 120], ["vlag", "Vlag", 120], ["hart", "I ♥ NL", 120],
	["wafel", "Stroopwafel", 120], ["turbo", "Turbo", 120], ["kroon", "Oranje", 120],
	["finish", "Finishvlag", 0, {"ach": "first_win"}], ["cup", "Polder Cup", 0, {"ach": "cupB"}], ["delta", "Team Delta", 0, {"ach": "cupA"}],
	["patat", "Patat met", 0, {"ach": "duels"}], ["legende", "Legende", 0, {"ach": "cupL"}]]

const ITEMS := [
	{"k": "paint", "g": "lak", "name": "Lakkleur", "type": "color", "def": "", "mix": true, "view": "q", "opts": PAINTS},
	{"k": "finish", "g": "lak", "name": "Afwerking", "type": "choice", "def": "gloss", "view": "q",
		"opts": [["gloss", "Glans", 0], ["metallic", "Metallic", 400], ["satin", "Zijdeglans", 300], ["matte", "Mat", 500], ["pearl", "Parelmoer", 900], ["chrome", "Chroom", 2500]]},
	{"k": "roof", "g": "lak", "name": "Dak in tweede kleur", "type": "color", "def": "", "none": "Lakkleur", "kit": 350, "mix": true, "fit": "cab", "view": "top",
		"opts": [["black", "Zwart", 0, {"hex": "#1b1b1b"}], ["white", "Wit", 0, {"hex": "#f2f2ee"}], ["silver", "Zilver", 0, {"hex": "#a1a4a8"}], ["red", "Rood", 0, {"hex": "#d62a2a"}],
			["orange", "Oranje", 0, {"hex": "#f36f21"}], ["yellow", "Geel", 0, {"hex": "#f2c200"}], ["blue", "Blauw", 0, {"hex": "#1d4f9e"}], ["green", "Groen", 0, {"hex": "#2f8f5b"}]]},
	# n: how many of the two stripe colours a design uses; cols: the colours it gets when you pick it
	{"k": "stripe", "g": "stripe", "name": "Ontwerp", "type": "choice", "def": "std", "view": "top",
		"opts": [["std", "Af fabriek", 0, {"n": 0}], ["none", "Geen", 0, {"n": 0}], ["twin", "Dubbele streep", 0, {"n": 1}], ["center", "Middenstreep", 200, {"n": 1}],
			["triple", "Drie strepen", 250, {"n": 2}], ["side", "Zijstreep", 250, {"n": 2, "view": "side"}], ["rally", "Rally", 500, {"n": 2, "view": "side", "cols": ["yellow", "black"]}],
			["checker", "Finishvlag", 400, {"n": 2, "view": "side"}], ["flames", "Vlammen", 600, {"n": 2, "view": "side", "cols": ["yellow", "red"]}],
			["flag", "Rood-wit-blauw", 400, {"n": 0}], ["delft", "Delfts blauw", 700, {"n": 0, "view": "side"}],
			["tulips", "Tulpen", 0, {"n": 0, "view": "side", "ach": "all_tracks"}], ["lion", "Oranje leeuw", 0, {"n": 2, "view": "side", "ach": "cupS", "cols": ["gold", "red"]}]]},
	{"k": "sc", "g": "stripe", "name": "Kleur", "type": "color", "def": "white", "mix": true, "view": "top", "opts": BASIC},
	{"k": "sc2", "g": "stripe", "name": "Tweede kleur", "type": "color", "def": "black", "mix": true, "view": "top", "opts": BASIC},
	{"k": "rimStyle", "g": "wheel", "name": "Velgmodel", "type": "choice", "def": "std", "view": "wheel", "opts": [["std", "Standaard", 0], ["spoke", "Spaken", 0], ["dish", "Diep", 0]]},
	{"k": "rim", "g": "wheel", "name": "Velgkleur", "type": "color", "def": "silver", "mix": true, "view": "wheel",
		"opts": [["silver", "Zilver", 0, {"hex": "#a1a4a8"}], ["black", "Zwart", 0, {"hex": "#222428"}], ["gold", "Goud", 0, {"hex": "#c9a227"}], ["white", "Wit", 0, {"hex": "#f2f2ee"}],
			["gun", "Antraciet", 100, {"hex": "#4a4e55"}], ["bronze", "Brons", 100, {"hex": "#9a6a3a"}], ["chrome", "Chroom", 100, {"hex": "#dfe3e6"}], ["red", "Rood", 100, {"hex": "#c8302a"}],
			["orange", "Oranje", 100, {"hex": "#f36f21"}], ["blue", "Blauw", 100, {"hex": "#1d4f9e"}], ["green", "Groen", 100, {"hex": "#2f8f5b"}], ["pink", "Roze", 100, {"hex": "#ff4f8b"}]]},
	{"k": "cal", "g": "wheel", "name": "Remklauwen", "type": "color", "def": "red", "mix": true, "view": "wheel",
		"opts": [["red", "Rood", 0, {"hex": "#c8302a"}], ["yellow", "Geel", 50, {"hex": "#f2c200"}], ["orange", "Oranje", 50, {"hex": "#f36f21"}], ["blue", "Blauw", 50, {"hex": "#2a6fdb"}],
			["green", "Groen", 50, {"hex": "#3fae5a"}], ["white", "Wit", 50, {"hex": "#f2f2ee"}], ["black", "Zwart", 50, {"hex": "#1b1b1b"}], ["silver", "Zilver", 50, {"hex": "#a1a4a8"}]]},
	{"k": "tw", "g": "wheel", "name": "Banden", "type": "choice", "def": "std", "view": "wheel",
		"opts": [["std", "Zwart", 0], ["white", "Witte wand", 300], ["red", "Rode lijn", 250], ["letter", "Witte letters", 350], ["yellow", "Gele letters", 350]]},
	{"k": "tint", "g": "glass", "name": "Ruiten", "type": "choice", "def": "std", "view": "q",
		"opts": [["std", "Standaard", 0], ["clear", "Helder", 200], ["black", "Zwart", 300], ["blue", "Blauw", 300], ["bronze", "Brons", 300], ["green", "Groen", 300], ["mirror", "Spiegel", 700]]},
	{"k": "lamp", "g": "glass", "name": "Koplampen", "type": "choice", "def": "std", "view": "front",
		"opts": [["std", "Standaard", 0], ["yellow", "Geel", 200], ["smoke", "Gerookt", 250], ["green", "Groen", 300], ["purple", "Paars", 400], ["ice", "Xenon-blauw", 0, {"ach": "night"}]]},
	{"k": "glow", "g": "glass", "name": "Neon onder de auto", "type": "color", "def": "", "none": "Uit", "kit": 900, "mix": true, "view": "low",
		"opts": [["blue", "Blauw", 0, {"hex": "#2a6fff"}], ["ice", "IJs", 0, {"hex": "#5fe0ff"}], ["purple", "Paars", 0, {"hex": "#a040ff"}], ["pink", "Roze", 0, {"hex": "#ff3fa0"}],
			["red", "Rood", 0, {"hex": "#ff2a20"}], ["orange", "Oranje", 0, {"hex": "#ff8a10"}], ["green", "Groen", 0, {"hex": "#30ff60"}], ["white", "Wit", 0, {"hex": "#f0f4ff"}]]},
	{"k": "num", "g": "num", "name": "Startnummer", "sub": "1 tot 99, leeg is geen nummer", "type": "num", "def": 0, "view": "side"},
	{"k": "numStyle", "g": "num", "name": "Vorm", "type": "choice", "def": "disc", "view": "side", "opts": [["disc", "Rondje", 0], ["square", "Vierkant", 0], ["ring", "Ring", 0], ["plain", "Los cijfer", 0]]},
	{"k": "numBg", "g": "num", "name": "Vlak", "type": "color", "def": "white", "mix": true, "view": "side", "opts": BASIC},
	{"k": "numFg", "g": "num", "name": "Cijfers", "type": "color", "def": "ink", "mix": true, "view": "side",
		"opts": [["ink", "Zwart", 0, {"hex": "#161a22"}], ["white", "Wit", 0, {"hex": "#f7f7f2"}], ["yellow", "Geel", 0, {"hex": "#f2c200"}], ["red", "Rood", 0, {"hex": "#d62a2a"}],
			["orange", "Oranje", 0, {"hex": "#f36f21"}], ["blue", "Blauw", 0, {"hex": "#1d4f9e"}], ["green", "Groen", 0, {"hex": "#2f8f5b"}], ["gold", "Goud", 0, {"hex": "#c9a227"}]]},
	{"k": "numFont", "g": "num", "name": "Lettertype", "type": "choice", "def": "race", "view": "side", "opts": [["race", "Race", 0], ["block", "Recht", 0], ["round", "Rond", 0]]},
	{"k": "numPos", "g": "num", "name": "Plek", "type": "choice", "def": "all", "view": "side", "opts": [["all", "Deuren en dak", 0], ["doors", "Deuren", 0], ["roof", "Dak", 0]]},
	{"k": "plate", "g": "num", "name": "Kenteken", "sub": "Eigen tekst, leeg is PR-3D-01", "type": "text", "def": "", "kit": 250, "max": 8, "chars": "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789- ", "view": "rear"},
	{"k": "plateStyle", "g": "num", "name": "Kentekenplaat", "type": "choice", "def": "nl", "view": "rear", "opts": [["nl", "Geel", 0], ["old", "Blauw (klassiek)", 150], ["black", "Zwart", 150], ["white", "Wit", 150]]},
	{"k": "d1", "g": "decal", "name": "Sticker voor op de deur", "type": "choice", "def": "", "view": "side", "opts": STICKERS},
	{"k": "d2", "g": "decal", "name": "Sticker achter op de deur", "type": "choice", "def": "", "view": "side", "opts": STICKERS},
	{"k": "ban", "g": "decal", "name": "Voorruitband", "sub": "Tekst boven aan de voorruit", "type": "text", "def": "", "kit": 300, "max": 14, "chars": "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-!&.' ", "fit": "cab", "view": "front"},
	{"k": "banCol", "g": "decal", "name": "Kleur van de band", "type": "color", "def": "black", "mix": true, "fit": "cab", "view": "front", "opts": BASIC},
	{"k": "wing", "g": "parts", "name": "Spoiler", "type": "choice", "def": "std", "view": "rear", "opts": [["std", "Af fabriek", 0], ["duck", "Ducktail", 0], ["gt", "GT-vleugel", 0]]},
	{"k": "exhaust", "g": "parts", "name": "Uitlaat", "sub": "Alleen klasse B en A", "type": "choice", "def": "std", "fit": "BA", "view": "rear",
		"opts": [["std", "Af fabriek", 0], ["sport", "Sport", 0], ["dual", "Dubbel", 0], ["center", "Centraal", 0]]},
]

## the stripe colours of saves and online players from before the catalogue: stripe "white" = design twin in white
const OLD_STRIPES := {"white": "white", "black": "black", "yellow": "yellow"}
## the rim colours CarKit's standard styling knows by name
const STD_RIMS := ["silver", "black", "gold", "white"]

static var _byKey := {}
static var _optIdx := {}      ## key -> {id: option}

static func _index() -> void:
	for it in ITEMS:
		_byKey[it.k] = it
		var ix := {}
		for o in it.get("opts", []): ix[o[0]] = o
		_optIdx[it.k] = ix

## the catalogue item of a key ({} when there is none)
static func item(k: String) -> Dictionary:
	if _byKey.is_empty(): _index()
	return _byKey.get(k, {})

## the option [id, name, price, extra] of an item (null when it has none by that id)
static func option(k: String, id):
	if _byKey.is_empty(): _index()
	return _optIdx.get(k, {}).get(id) if id is String else null

static func extra(k: String, id) -> Dictionary:
	var o = option(k, id)
	return o[3] if o != null and o.size() > 3 else {}

static func itemsOf(group: String) -> Array:
	return ITEMS.filter(func(it): return it.g == group)

## does the item go on this car at all (a roof colour needs a roof, the exhaust choice is for classes B and A)
static func fits(car: String, k: String) -> bool:
	var f: String = item(k).get("fit", "")
	if f == "" or car == "": return true
	if f == "cab": return Cars.CAR_SPECS.has(car) and Cars.CAR_SPECS[car].has("cab")
	if f == "BA": return Cars.CARS.has(car) and Cars.CARS[car].cls != "S"
	return true

static func isHex(v) -> bool:
	if not (v is String) or v.length() != 7 or v[0] != "#": return false
	return v.substr(1).is_valid_hex_number()

## the colour of a colour item's value (a preset id or "#rrggbb"); the default's colour when the value is neither
static func colorOf(k: String, v) -> Color:
	var o = option(k, v)
	if o != null: return Color(o[3].hex if o.size() > 3 and o[3].has("hex") else o[0])
	if isHex(v): return Color(v)
	var d = item(k).get("def", "")
	o = option(k, d)
	return Color(o[3].hex if o != null and o.size() > 3 and o[3].has("hex") else "#ffffff")

## the name of a value as the garage shows it
static func nameOf(k: String, v) -> String:
	var it := item(k)
	var o = option(k, v)
	if o != null: return o[1]
	match it.get("type", ""):
		"color":
			if v is String and v == "" and it.has("none"): return it.none
			return "Eigen kleur"
		"num": return str(int(v)) if int(v) > 0 else "Geen"
		"text": return str(v) if str(v) != "" else "Standaard"
	return str(v)

# ------------------------------------------------------------------ the look dictionary

## one value made safe: the value itself when the item allows it, else the item's default
static func cleanValue(k: String, v):
	var it := item(k)
	if it.is_empty(): return null
	var d = it.def
	match it.type:
		"choice":
			return v if option(k, v) != null else d
		"color":
			if not (v is String): return d
			if option(k, v) != null: return v
			if v == "" and (it.has("none") or d == ""): return ""
			if it.get("mix", false) and isHex(v): return v.to_lower()
			return d
		"num":
			if not (v is int or v is float) or is_nan(v) or is_inf(v): return 0
			return clampi(int(v), 0, 99)
		"text":
			if not (v is String): return ""
			var out := ""
			for ch in v.to_upper():
				if out.length() >= int(it.max): break
				if it.chars.contains(ch): out += ch
			return out.strip_edges()
	return d

## a complete, safe look from anything (a garage entry, a look from another player, junk): every catalogue key with a
## valid value. car: the model it goes on (items that do not fit it get their default)
static func clean(u, car := "") -> Dictionary:
	var L := {}
	var src: Dictionary = u if u is Dictionary else {}
	for it in ITEMS:
		var k: String = it.k
		L[k] = cleanValue(k, src.get(k, it.def)) if fits(car, k) else it.def
	# stripes from before the catalogue: the colour was the choice
	var st = src.get("stripe")
	if st is String and OLD_STRIPES.has(st):
		L.stripe = "twin"
		L.sc = OLD_STRIPES[st]
	if L.paint == "": L.erase("paint")
	return L

## the look without the values that are the default anyway (what is saved and sent)
static func compact(L: Dictionary) -> Dictionary:
	var out := {}
	for k in L:
		var it := item(k)
		if it.is_empty(): continue
		if typeof(L[k]) != typeof(it.def) or L[k] != it.def: out[k] = L[k]
	return out

static func defaults() -> Dictionary:
	var L := {}
	for it in ITEMS:
		if it.k != "paint": L[it.k] = it.def
	return L

# ------------------------------------------------------------------ styling a built car
## where body parts of a car hang (CarKit.buildCar's shell; the whole car for a rig without one)
static func _par(m: Dictionary) -> Node3D:
	return m.get("shell", m.g)


## before CarKit's standard styling. m: the car from CarKit.buildCar; u: its garage entry or a look. Keeps the cleaned
## look on the car (m.look) and returns what the standard styling understands: the stripes as it knows them (std, none,
## white), a rim colour it has by name, the number, wing and exhaust.
static func pre(m: Dictionary, u: Dictionary) -> Dictionary:
	var L := clean(u, str(m.get("type", "")))
	m["look"] = L
	m["lookKids"] = _par(m).get_child_count()
	var s := u.duplicate()
	s.merge(L, true)
	s.rim = L.rim if STD_RIMS.has(L.rim) else "silver"
	s.stripe = "std" if L.stripe == "std" else ("white" if L.stripe == "twin" else "none")
	return s

## after CarKit's standard styling: everything else of the look
static func post(m: Dictionary) -> void:
	var L: Dictionary = m.get("look", {})
	if L.is_empty(): return
	var K = m.get("kit", null)
	var all: Array = []
	CarKit._meshes_of(m.g, all)
	_paint(m, L, K, all)
	_swap(m, L, all)
	_rims(m, L)
	if K != null:
		_numbers(m, L, K)
		_stripes(m, L, K, all)
		_decals(m, L, K)
	_glow(m, L)
	_flushSoon()
	m["lookDone"] = true

# ---- paint, finish, roof
static func _paint(m: Dictionary, L: Dictionary, K, all: Array) -> void:
	var p = m.get("paint", null)
	if not (p is LMat): return
	if L.has("paint"):
		var c := Color(L.paint)
		p.albedo_color = Color(c.r, c.g, c.b, p.albedo_color.a)
	finish(p, L.finish)
	if L.roof != "" and K != null and K.cab != null:
		# the paint is one mesh (body and cabin): swap it for the body alone and lay the cabin's paint in the roof colour
		var sp = CarKit.roofSplit(K)
		var body = m.get("body", null)
		if sp == null or body == null: return
		var rm: LMat = p.clone()
		var rc := colorOf("roof", L.roof)
		rm.albedo_color = Color(rc.r, rc.g, rc.b, p.albedo_color.a)
		finish(rm, L.finish)
		CarKit.set_geo(body, sp[0])
		CarKit.mesh(_par(m), sp[1], rm, true).set_meta("roof", true)

## the paint finish on a paint material. A stand-in until the car paint material does this itself (it then tags the
## material with meta "finish" and this leaves it alone): the highlight of the Phong paint is widened, tinted or dimmed.
static func finish(p: LMat, f: String) -> void:
	if p.has_meta("finish") or p.kind != LMat.Kind.PHONG: return
	var c := p.albedo_color
	match f:
		"metallic":
			p.specular = Color(0.62, 0.62, 0.62).lerp(c, 0.35); p.shininess = 26.0
		"satin":
			p.specular = Color(0.2, 0.2, 0.2); p.shininess = 12.0
		"matte":
			p.specular = Color(0.03, 0.03, 0.03); p.shininess = 5.0
		"pearl":
			p.specular = Color.from_hsv(fposmod(c.h + 0.14, 1.0), 0.45, 0.95); p.shininess = 40.0
		"chrome":
			var k := Color(0.82, 0.84, 0.86).lerp(c, 0.42)
			p.albedo_color = Color(k.r, k.g, k.b, c.a)
			p.specular = Color(1, 1, 1); p.shininess = 120.0

# ---- shared materials swapped for a look's own: calipers, tyres, glass, lamps, plate
const TINTS := {"clear": [0x44566a, 0xb8c4d0, 80.0], "black": [0x07080a, 0x40464c, 60.0], "blue": [0x0f2f66, 0x8fb4ff, 80.0], "bronze": [0x33200f, 0xa87a44, 80.0],
	"green": [0x0f3320, 0x8fd8a8, 80.0], "mirror": [0x5b6876, 0xffffff, 110.0]}
## lamp glass colour and what it does to the light of the lamps (CarKit.lampMat's emission, which follows the time of day)
const LAMPS := {"yellow": [0xffe04a, Vector3(1.0, 0.86, 0.3)], "smoke": [0x55524c, Vector3(0.42, 0.42, 0.42)], "green": [0xc8ffd0, Vector3(0.5, 1.0, 0.55)],
	"purple": [0xe6d0ff, Vector3(0.78, 0.5, 1.05)], "ice": [0xd8eeff, Vector3(0.72, 0.9, 1.15)]}

static var _glassMats := {}
static var _lampMats := {}
static var _tyreMats := {}
static var _weak := {}        ## key -> WeakRef of a material made for free colours and texts (lives as long as a car uses it)

static func _cached(key: String, make: Callable) -> LMat:
	var w = _weak.get(key)
	if w != null:
		var hit = w.get_ref()
		if hit != null: return hit
	var mt: LMat = make.call()
	_weak[key] = weakref(mt)
	if _weak.size() > 160:
		for k in _weak.keys():
			if _weak[k].get_ref() == null: _weak.erase(k)
	return mt

## glass tint: [colour, how dark (CarPaint.glass opacity)]
const GLASS := {"clear": [0x44566a, 0.3], "black": [0x07080a, 0.9], "blue": [0x0f2f66, 0.62], "bronze": [0x33200f, 0.66], "green": [0x0f3320, 0.62],
	"mirror": [0x5b6876, 0.86]}

static func _swap(m: Dictionary, L: Dictionary, all: Array) -> void:
	# calipers and tyres are vertex-coloured parts of the wheels (CarKit): recolour / add a sidewall ring
	if L.cal != "red":
		CarKit.setCalipers(m, colorOf("cal", L.cal))
	if L.tw != "std":
		if not _tyreMats.has(L.tw):
			var tx := CarDecal.tyre(L.tw)
			var mt := CarKit._M(0xffffff, {"map": tx})
			_tyreMats[L.tw] = mt
			_wait(mt, tx, MathX.col(0x1b1b1b), Color.WHITE)
		CarKit.setTyreWall(m, _tyreMats[L.tw])
	if GLASS.has(L.tint):
		CarKit.setGlass(m, GLASS[L.tint][0], GLASS[L.tint][1])
	var lamp = null
	if LAMPS.has(L.lamp):
		if not _lampMats.has(L.lamp):
			# the lamp atlas (CarLamps) in a tinted glass: the same textures, its colour multiplied in
			var lm: LMat = CarKit.lampMat.clone()
			lm.albedo_color = MathX.col(LAMPS[L.lamp][0])
			lm.set_meta("lamp", true)   # Fx still finds the head lamps for their glow
			_lampMats[L.lamp] = lm
			_syncLamps()
		lamp = _lampMats[L.lamp]
	var plate = null
	if L.plate != "" or L.plateStyle != "nl":
		var txt: String = L.plate if L.plate != "" else "PR-3D-01"
		var st: String = L.plateStyle
		plate = _cached("plate" + st + "/" + txt, func():
			var tx := CarDecal.plate(txt, st)
			var mt := CarKit._M(0xffffff, {"map": tx})
			_wait(mt, tx, CarDecal.plateWait(st), Color.WHITE)
			return mt)
	if lamp == null and plate == null: return
	for o in all:
		for s in o.mesh.get_surface_count():
			var mt = o.get_surface_override_material(s)
			if mt == CarKit.lampMat:
				if lamp != null: o.set_surface_override_material(s, lamp)
			elif mt == CarKit.carPlate:
				if plate != null: o.set_surface_override_material(s, plate)

# ---- rims: the standard styling made the car's rim material in a colour it knows; any other colour goes on here
static func _rims(m: Dictionary, L: Dictionary) -> void:
	if STD_RIMS.has(L.rim): return
	var ws: Array = m.get("wheels", [])
	if ws.is_empty(): return
	CarKit.setRims(m, ws[0].style, colorOf("rim", L.rim))   # the rim colour is in the wheel's vertex colours

# ---- start numbers: the standard styling placed them (doors or fin, and roof); here their style and which ones show
static func _numMeshes(m: Dictionary) -> Array:
	var out := []
	var kids: Array = _par(m).get_children()
	var dm = null
	for i in range(int(m.get("lookKids", 0)), kids.size()):
		var o = kids[i]
		if not (o is MeshInstance3D): continue
		var mt = o.get_surface_override_material(0)
		if dm == null and mt is LMat and mt.albedo_texture != null and mt.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: dm = mt
		if dm != null and mt == dm: out.append(o)
	return out

static func _numbers(m: Dictionary, L: Dictionary, K) -> void:
	if int(L.num) <= 0: return
	var plain: bool = L.numStyle == "disc" and L.numBg == "white" and L.numFg == "ink" and L.numFont == "race"
	if plain and L.numPos == "all": return
	var nm := _numMeshes(m)
	var mat = null
	if not plain:
		var bg := colorOf("numBg", L.numBg)
		var fg := colorOf("numFg", L.numFg)
		var n := int(L.num)
		var st: String = L.numStyle
		var fo: String = L.numFont
		mat = _cached("num%d/%s/%s/%s/%s" % [n, st, fo, bg.to_html(false), fg.to_html(false)], func():
			var tx := CarDecal.number(n, st, fo, bg, fg)
			var mt := CarKit._M(0xffffff, {"map": tx, "transparent": true})
			_wait(mt, tx, Color(1, 1, 1, 0), Color.WHITE)
			return mt)
	for o in nm:
		if mat != null: o.set_surface_override_material(0, mat)
		var roof: bool = K.numGeo != null and o.get_meta("geo", null) == K.numGeo
		if (roof and L.numPos == "doors") or (not roof and L.numPos == "roof"): o.visible = false

## is the number on the roof shown (the stripes over the roof make way for it)
static func _roofNum(L: Dictionary) -> bool:
	return int(L.num) > 0 and L.numPos != "doors"

# ---- stripes and liveries
static func _kitGeo(K: CarBody, key: String, make: Callable) -> Geo:
	var c: Dictionary = K.get_meta("look", {})
	if not c.has(key):
		c[key] = make.call()
		K.set_meta("look", c)
	return c[key]

## stripes over bonnet, roof and boot between x0 and x1 either side of the middle (CarKit.stripeGeo, which remembers the
## first width it is asked for as the factory width: put that back)
static func _topGeo(K: CarBody, x0: float, x1: float, hole: bool) -> Geo:
	return _kitGeo(K, "top%.2f/%.2f/%s" % [x0, x1, hole], func():
		var w = K.stripeW
		var g := CarKit.stripeGeo(K, CarAcc.new(), x0, x1, CarKit.numSpot(K) if hole else null).build()
		K.stripeW = w
		return g)

## one half (side: 1 left of the middle, -1 right) of mirrored stripes, for designs that differ left and right
static func _half(g: Geo, side: float) -> Geo:
	if g == null: return null
	var h := Geo.new()
	var has_uv := g.uv.size() == g.pos.size()
	for i in range(0, g.pos.size(), 3):
		if (g.pos[i].x + g.pos[i + 1].x + g.pos[i + 2].x) * side <= 0: continue
		for k in 3:
			h.pos.append(g.pos[i + k]); h.nrm.append(g.nrm[i + k])
			if has_uv: h.uv.append(g.uv[i + k])
	return h if h.pos.size() > 0 else null

## the panel a side design is printed on: the flank between the wheel arches, sill to shoulder, both sides. u runs from
## the front arch to the rear one on both sides (a design flows backwards left and right), v from the sill up.
static func doorGeo(K: CarBody) -> Geo:
	return _kitGeo(K, "door", func():
		var S: Dictionary = K.S
		var zA: float = S.wz[1] + K.ra + 0.05
		var zB: float = S.wz[0] - K.ra - 0.05
		var f := func(u: float, v: float):
			var z: float = zB + (zA - zB) * u
			var lo: float = K.bot(z) + 0.09
			var hi: float = K.top(z) - 0.07
			return K.on_side(z, lo + (hi - lo) * v)
		return CarKit.patch(CarAcc.new(), f, 0.0, 1.0, 0.0, 1.0, 18, 8, 0.012, true, false).build())

static func _flat(c: Color) -> LMat:
	return _cached("flat" + c.to_html(false), func():
		var mt := CarKit._M(0xffffff)
		mt.albedo_color = c
		return mt)

static func _stripes(m: Dictionary, L: Dictionary, K: CarBody, all: Array) -> void:
	var d: String = L.stripe
	var hole := _roofNum(L)
	var c1 := colorOf("sc", L.sc)
	var c2 := colorOf("sc2", L.sc2)
	if d == "std" or d == "twin":
		# the standard styling laid them (factory stripes, or its own pair); colour them, and close the hole it left for a
		# roof number that is not shown
		for o in all:
			var mt = o.get_surface_override_material(0)
			var geo = o.get_meta("geo", null)
			var stock: bool = mt != null and mt.has_meta("stripe")
			var own: bool = o.get_parent() == _par(m) and geo != null and (geo == K.stripes or geo == K.stripeNum)
			if not (stock or own): continue
			if d == "twin" and mt is LMat: mt.albedo_color = c1
			if int(L.num) > 0 and not hole and geo == K.stripeNum:
				var whole: Geo = K.G.get("stripe") if stock else K.stripes
				if whole != null: CarKit.set_geo(o, whole)
		return
	match d:
		"center":
			CarKit.mesh(_par(m), _topGeo(K, 0.0, 0.2, hole), _flat(c1))
		"triple":
			CarKit.mesh(_par(m), _topGeo(K, 0.0, 0.09, hole), _flat(c1))
			CarKit.mesh(_par(m), _topGeo(K, 0.15, 0.21, hole), _flat(c2))
		"rally":
			CarKit.mesh(_par(m), _topGeo(K, 0.1, 0.28, hole), _flat(c1))
		"lion":
			CarKit.mesh(_par(m), _topGeo(K, 0.1, 0.28, hole), _flat(c1))
		"delft":
			CarKit.mesh(_par(m), _topGeo(K, 0.0, 0.2, hole), _flat(Color("#f7f7f2")))
			CarKit.mesh(_par(m), _topGeo(K, 0.24, 0.29, hole), _flat(Color("#1d4f9e")))
		"flag":
			CarKit.mesh(_par(m), _topGeo(K, 0.0, 0.07, hole), _flat(Color("#f7f7f2")))
			var side := _topGeo(K, 0.07, 0.21, hole)
			CarKit.mesh(_par(m), _kitGeo(K, "flagL%s" % hole, func(): return _half(side, 1.0)), _flat(Color("#ae1c28")))
			CarKit.mesh(_par(m), _kitGeo(K, "flagR%s" % hole, func(): return _half(side, -1.0)), _flat(Color("#21468b")))
	if CarDecal.DOORS.has(d):
		var g := doorGeo(K)
		if g == null: return
		var key := "door%s/%s/%s" % [d, c1.to_html(false), c2.to_html(false)]
		var mat := _cached(key, func():
			var tx := CarDecal.door(d, c1, c2)
			var mt := CarKit._M(0xffffff, {"map": tx, "transparent": true})
			mt.render_priority = -1      # under the numbers and stickers that lie on it
			_wait(mt, tx, Color(1, 1, 1, 0), Color.WHITE)
			return mt)
		CarKit.mesh(_par(m), g, mat)

# ---- stickers on the doors and the band across the windscreen
## where the standard styling puts the start number on the door (the same search as CarKit.styleExtras): [z0, z1, y0, y1]
static func _numRect(K: CarBody) -> Array:
	var S: Dictionary = K.S
	var C = K.C
	if S.has("numFin"): return []
	var zA: float = S.wz[1] + K.ra + 0.08
	var zB: float = S.wz[0] - K.ra - 0.08
	var z0: float = maxf(C.sg[0], zA) if C != null else zA
	var z1: float = minf(C.sg[1], zB) if C != null else zB
	var sz := 0.62
	while sz >= 0.22:
		for k in 13:
			var zc: float = (z0 + z1) / 2 + (1 if k % 2 else -1) * ceilf(k / 2.0) * 0.06
			var belt: float = K.top(zc) - 0.1
			var sill: float = K.bot(zc) + 0.14
			if belt - sill < sz or zc - sz / 2 < zA or zc + sz / 2 > zB: continue
			for q in 7:
				var yc: float = belt - sz / 2 - (belt - sill - sz) * q / 6.0
				if not _blocked(K.sideRects, zc, yc, sz, sz): return [zc - sz / 2, zc + sz / 2, yc - sz / 2, yc + sz / 2]
		sz -= 0.04
	return []

static func _blocked(rects: Array, zc: float, yc: float, w: float, h: float) -> bool:
	for r in rects:
		if r[1] > zc - w / 2 - 0.02 and r[0] < zc + w / 2 + 0.02 and r[3] > yc - h / 2 - 0.02 and r[2] < yc + h / 2 + 0.02: return true
	return false

## where the two stickers go on the door: the first as far forward as it fits, the second as far back, both clear of the
## start number's place, handles, vents and sills; per slot {z, y, w, h}, or {} when the door has no room for it
static func stickerSpots(K: CarBody) -> Array:
	var c: Dictionary = K.get_meta("look", {})
	if c.has("spots"): return c.spots
	var S: Dictionary = K.S
	var zA: float = S.wz[1] + K.ra + 0.06
	var zB: float = S.wz[0] - K.ra - 0.06
	var rects: Array = K.sideRects.duplicate()
	var nr := _numRect(K)
	if not nr.is_empty(): rects.append([nr[0] - 0.02, nr[1] + 0.02, nr[2], nr[3]])
	var spots := []
	for slot in 2:
		var spot := {}
		var w := 0.44
		while w >= 0.26 and spot.is_empty():
			var h := w / 2
			var n := int((zB - zA - w) / 0.04)
			for i in n + 1:
				if not spot.is_empty(): break
				var zc: float = zB - w / 2 - i * 0.04 if slot == 0 else zA + w / 2 + i * 0.04
				var belt: float = K.top(zc) - 0.12
				var sill: float = K.bot(zc) + 0.12
				if belt - sill < h: continue
				for q in 7:
					# from the middle of the door outwards
					var yc: float = (belt + sill) / 2 + (1 if q % 2 else -1) * ceilf(q / 2.0) * (belt - sill - h) / 6.0
					if not _blocked(rects, zc, yc, w, h) and K.on_side(zc, yc) != null:
						spot = {"z": zc, "y": yc, "w": w, "h": h}
						break
			w -= 0.06
		spots.append(spot)
		if not spot.is_empty(): rects.append([spot.z - spot.w / 2, spot.z + spot.w / 2, spot.y - spot.h / 2, spot.y + spot.h / 2])
	c.spots = spots
	K.set_meta("look", c)
	return spots

static func _decals(m: Dictionary, L: Dictionary, K: CarBody) -> void:
	for slot in 2:
		var id: String = L["d%d" % (slot + 1)]
		if id == "": continue
		var sp: Dictionary = stickerSpots(K)[slot]
		if sp.is_empty(): continue
		# like the start number: u from the front on the left side and mirrored on the right, so texts read on both
		var g := _kitGeo(K, "stick%d" % slot, func():
			return CarKit.patch(CarAcc.new(), K.on_side, sp.z + sp.w / 2, sp.z - sp.w / 2, sp.y - sp.h / 2, sp.y + sp.h / 2, 4, 3, 0.02, true, true).build())
		if g == null: continue
		if not _stickMats.has(id):
			var tx := CarDecal.sticker(id)
			var mt := CarKit._M(0xffffff, {"map": tx, "transparent": true})
			_wait(mt, tx, Color(1, 1, 1, 0), Color.WHITE)
			_stickMats[id] = mt
		CarKit.mesh(_par(m), g, _stickMats[id])
	if L.ban != "" and K.C != null:
		var g := bannerGeo(K)
		if g != null:
			var bc := colorOf("banCol", L.banCol)
			var txt: String = L.ban
			var mat := _cached("ban" + bc.to_html(false) + "/" + txt, func():
				var tx := CarDecal.banner(txt, bc)
				var mt := CarKit._M(0xffffff, {"map": tx})
				_wait(mt, tx, bc, Color.WHITE)
				return mt)
			CarKit.mesh(_par(m), g, mat)

static var _stickMats := {}

## the band along the top of the windscreen, 2 cm above the glass; text reads from in front of the car
static func bannerGeo(K: CarBody) -> Geo:
	return _kitGeo(K, "banner", func():
		var C: Dictionary = K.C
		var zt: float = C.ws + 0.02
		var zb: float = minf(C.ws + 0.2, (C.ws + C.z0) / 2)
		if zb - zt < 0.06: return null
		# as wide as the flat of the screen allows at both edges of the band (the last point of the cabin section's corner)
		var xw := 9.0
		for z in [zt, zb]:
			var P: PackedFloat64Array = K.csec(z)
			xw = minf(xw, P[18] - 0.03)   # point 9: the end of the roof rail round (CarBody's cabin ring)
		while xw > 0.2 and (K.on_cab(xw, zt) == null or K.on_cab(xw, zb) == null): xw -= 0.02
		if xw <= 0.2: return null
		return CarKit.patch(CarAcc.new(), K.on_cab, -xw, xw, zb, zt, 10, 2, 0.02, false).build())

# ---- neon under the car: a soft pool of light on the road, strongest at night
static var _glowTex: ImageTexture = null
static var _glowGeo: Geo = null
static var _glowLevel := 0.3
static var _glows: Array = []       ## WeakRefs of the glow materials in use

static func glowTex() -> ImageTexture:
	if _glowTex == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				# a rounded box: bright under the sills, fading out past the car
				var u := absf(x - (n - 1) / 2.0) / ((n - 1) / 2.0)
				var v := absf(y - (n - 1) / 2.0) / ((n - 1) / 2.0)
				var d := Vector2(maxf(u - 0.5, 0.0), maxf(v - 0.62, 0.0)).length()
				var a := pow(clampf(1.0 - d / 0.38, 0.0, 1.0), 1.7)
				var core := clampf(1.0 - maxf(u / 0.5, v / 0.62), 0.0, 1.0)
				a *= 1.0 - 0.45 * core            # darker right under the middle: the light comes from the edges
				img.set_pixel(x, y, Color(1, 1, 1, a))
		img.generate_mipmaps()
		_glowTex = ImageTexture.create_from_image(img)
	return _glowTex

static func _glow(m: Dictionary, L: Dictionary) -> void:
	if L.glow == "": return
	var c := colorOf("glow", L.glow)
	var mat := _cached("glow" + c.to_html(false), func():
		var mt := Mats.basic(0xffffff, {"map": glowTex(), "transparent": true, "depthWrite": false, "blending": "add", "opacity": 1.0})
		mt.albedo_color = Color(c.r, c.g, c.b, _glowLevel)
		_glows.append(weakref(mt))
		return mt)
	if _glowGeo == null:
		_glowGeo = Geo.plane(1, 1)
		_glowGeo.rotate_x(-PI / 2)
	var o := CarKit.mesh(m.g, _glowGeo, mat)
	o.scale = Vector3(float(m.wid) + 1.5, 1, float(m.len) + 1.3)
	# (the road surface lies 7 cm above the height a car drives at, kerbs 9 cm)
	o.position = Vector3(0, 0.105, float(m.get("off", 0.0)))
	o.set_meta("glow", true)

## the light changed (CarKit.applyEnv, the garage, the podium): tinted lamps follow the lamp glass, the neon its level
## (0..1: faint by day, full at night)
static func envChanged(level: float) -> void:
	_glowLevel = level
	_syncLamps()
	var live: Array = []
	for w in _glows:
		var mt = w.get_ref()
		if mt == null: continue
		live.append(w)
		var c: Color = mt.albedo_color
		mt.albedo_color = Color(c.r, c.g, c.b, level)
	_glows = live

static func _syncLamps() -> void:
	var base: Color = CarKit.lampMat.emission if CarKit.lampMat.emission_enabled else Color.BLACK
	for id in _lampMats:
		var k: Vector3 = LAMPS[id][1]
		var mt: LMat = _lampMats[id]
		mt.emission_enabled = true
		mt.emission = Color(base.r * k.x, base.g * k.y, base.b * k.z)

# ---- canvas textures are drawn a few frames after they are asked for: until then the part shows in a quiet colour
static var _waiting: Array = []     ## [WeakRef material, texture, colour when drawn]
static var _polling := false
static var _flushing := false

static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

static func _wait(mt: LMat, tx: Texture2D, while_waiting: Color, ready: Color) -> void:
	if DisplayServer.get_name() == "headless" or tx == null or tx.get_width() > 1: return
	mt.albedo_color = while_waiting
	_waiting.append([weakref(mt), tx, ready, 0])
	if not _polling and _tree() != null:
		_polling = true
		_tree().process_frame.connect(_poll)

static func _poll() -> void:
	var keep: Array = []
	for w in _waiting:
		var mt = w[0].get_ref()
		if mt == null: continue
		w[3] += 1
		if w[1].get_width() > 1 or w[3] > 240: mt.albedo_color = w[2]
		else: keep.append(w)
	_waiting = keep
	if keep.is_empty():
		_polling = false
		_tree().process_frame.disconnect(_poll)

## draw the textures a look asked for (the start number of a bot, a livery) without waiting for the next track load
static func _flushSoon() -> void:
	if _flushing or Canvas2D.pending_count() == 0 or _tree() == null: return
	_flushing = true
	_tree().process_frame.connect(func() -> void:
		_flushing = false
		var sc := _tree().current_scene
		if sc != null and Canvas2D.pending_count() > 0: Canvas2D.flush(sc), CONNECT_ONE_SHOT)

# ------------------------------------------------------------------ bots and rivals
## the career rivals drive a car of their own making
const RIVAL_LOOKS := {
	"Daan": {"num": 13, "stripe": "rally", "sc": "white", "sc2": "black", "rim": "black", "rimStyle": "spoke", "numStyle": "square", "numBg": "white", "wing": "gt", "d2": "patat"},
	"Ingrid": {"num": 1, "finish": "metallic", "stripe": "center", "sc": "white", "rim": "white", "rimStyle": "dish", "numBg": "orange", "numFg": "white", "d1": "delta", "ban": "TEAM DELTA", "banCol": "blue"},
	"De Baron": {"num": 5, "finish": "pearl", "stripe": "twin", "sc": "gold", "rim": "gold", "rimStyle": "dish", "numStyle": "ring", "numBg": "gold", "numFg": "gold", "tint": "black", "roof": "black",
		"ban": "DE BARON", "banCol": "gold", "plate": "BARON-1", "plateStyle": "black"}}

static func _hash(s: String) -> int:
	var h := 2166136261
	for b in s.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0xffffffff
	return h

## the look of a computer driver, the same on every computer (it follows from the name, the car and its colour): a start
## number, rims and often stripes that go with the paint. rival: a career rival in his or her own colours.
static func botLook(name: String, type: String, color, rival := false) -> Dictionary:
	if rival and RIVAL_LOOKS.has(name):
		return compact(clean(RIVAL_LOOKS[name], type))
	var h := _hash(name + "/" + type)
	var col: Color = color if color is Color else (Color(str(color)) if Color.html_is_valid(str(color)) else Color.WHITE)
	var dark := col.get_luminance() < 0.35
	var L := {"num": 2 + (_hash(name) % 97)}
	L.rim = ["silver", "black", "silver", "white", "gold", "black"][h % 6]
	if L.rim == "white" and not dark and col.get_luminance() > 0.8: L.rim = "black"
	L.rimStyle = ["std", "spoke", "dish"][(h >> 3) % 3]
	var s := (h >> 5) % 5
	if s == 1: L.stripe = "twin"
	elif s == 2: L.stripe = "center"
	elif s == 3: L.stripe = "none"
	if L.has("stripe") and L.stripe != "none":
		L.sc = "white" if dark or col.get_luminance() < 0.6 else "black"
		if (h >> 9) % 4 == 0 and absf(col.h - 0.13) > 0.08: L.sc = "yellow"
	if (h >> 11) % 3 == 0: L.finish = "metallic"
	if (h >> 13) % 4 == 0:
		L.numStyle = "square"
	if dark and (h >> 15) % 2 == 0:
		L.numBg = "yellow"
	return compact(clean(L, type))

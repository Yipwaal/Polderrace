extends RefCounted
## The looks of a car (CarLook, G's looks API, the garage's Uiterlijk tab): the catalogue is sound; every option goes on
## every car it fits; a look survives saving and G.lookOf() (what players send each other) and gives the same car again;
## junk is ignored; saves from before the catalogue load; buying, owning, kits, the colour mixer and unlocking work; the
## fitting room never leaks into the save; bots look the same everywhere; every option of the garage is reachable with
## the keyboard; looks never touch performance or the hitbox.

var r: TestReport
var Cars_ := load("res://tests/test_cars.gd")
var log: ErrLog

## every error the engine or a script logs while the looks are tested (the headless dummy renderer's noise left out)
class ErrLog extends Logger:
	var errors: Array[String] = []
	var strict := false       ## also the dummy renderer's complaints (a material freed before its mesh)
	var mx := Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING or ("rendering/dummy/" in file and not strict): return
		mx.lock()
		errors.append("%s (%s:%d %s) %s" % [code, file.get_file(), line, function, rationale])
		mx.unlock()
	func _log_message(_message: String, _error: bool) -> void:
		pass
	func take() -> Array[String]:
		mx.lock()
		var e := errors.duplicate()
		errors.clear()
		mx.unlock()
		return e

func key(code: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	Menu.get_viewport().push_input(e)
	var u := e.duplicate()
	u.pressed = false
	Menu.get_viewport().push_input(u)

func focused() -> Control:
	return Menu.get_viewport().gui_get_focus_owner()

func saved(k: String) -> Dictionary:
	var v = JSON.parse_string(str(G.store_get(k, "{}")))
	return v if v is Dictionary else {}

func car(id: String, look: Dictionary, color := "#1d4f9e") -> Dictionary:
	var m := CarKit.buildCar(id, Color(color))
	CarKit.styleCar(m, look)
	return m

func drop(m: Dictionary) -> void:
	var keep := []
	for e in Cars_.dump_nodes(m.g):
		for s in e.mesh.get_surface_count(): keep.append(e.get_surface_override_material(s))
	m.g.free()
	keep.clear()

## the values of an item to try: every option, off, and a mixed colour
func values(it: Dictionary) -> Array:
	var out: Array = it.get("opts", []).map(func(o): return o[0])
	if it.type == "color":
		if it.has("none"): out.append("")
		if it.get("mix", false): out.append("#12ab9f")
	elif it.type == "num": out = [0, 7, 99]
	elif it.type == "text": out = ["", "AB-12", "Z" + "9".repeat(int(it.max) - 1)]
	return out

func run(host: Node) -> TestReport:
	r = TestReport.new("uiterlijk: catalogus, toepassen, opslaan, kopen, garage")
	var env := Env.new()
	host.add_child(env)
	World.root = Node3D.new()
	host.add_child(World.root)
	var cam := Camera3D.new()
	host.add_child(cam)
	Game.camera = cam
	Game.set_process(false)
	Game.set_process_input(false)
	log = ErrLog.new()
	OS.add_logger(log)
	part_repros()
	part_catalogue()
	part_apply()
	part_kits()
	part_roundtrip()
	part_junk()
	part_saves()
	part_bots()
	TrackLoader.load_track("polder", "fwd")
	env.apply("day", "dry", true)
	Game.rebuildPlayerCar()
	Game.toMenu(-1)
	part_buying()
	part_garage()
	await part_keys(host)
	await part_picker(host)
	Game.toMenu(-1)
	Menu.homePanel("main")
	Game.set_process(true)
	Game.set_process_input(true)
	var errs := log.take()
	OS.remove_logger(log)
	r.check(errs.is_empty(), "geen foutmeldingen van de engine tijdens de uiterlijk-test", "; ".join(errs.slice(0, 4)))
	return r

# ------------------------------------------------------------------ bugs that were found (each one stays fixed)
func part_repros() -> void:
	# a hatch with the twin stripe (and the old stripe colours of saves) logged "Parameter material is null" (LAN agent);
	# strict: every engine error counts, the car is freed the plain way
	log.strict = true
	for st in [{"stripe": "twin"}, {"stripe": "white"}, {"stripe": "black"}, {"stripe": "yellow"}, {"stripe": "twin", "num": 4}, {"stripe": "twin", "paint": "#123456"}]:
		for id in ["hatch", "gt", "roadster"]:
			var m := car(id, st, "#ff0000")
			m.g.free()
	log.strict = false
	var errs := log.take()
	r.check(errs.is_empty(), "dubbele streep (en oude streepkleuren) zonder foutmeldingen", "; ".join(errs.slice(0, 3)))
	# lookOf: plain String keys (clean JSON for the other players)
	G.use_store("user://test-looks.json", {"polderrace3d-settings": {"car": "gt", "color": "#f36f21"}})
	var L := G.lookOf("gt")
	r.check(L.keys().all(func(k): return typeof(k) == TYPE_STRING) and L.has("paint"), "G.lookOf: alle sleutels zijn gewone tekst", str(L.keys().map(func(k): return type_string(typeof(k)))))
	# a partial garage entry (num without rimStyle, no wing, ...) loads and styles without crashing
	G.use_store("user://test-looks.json", {"polderrace3d-settings": {"car": "gt", "color": "#f36f21"}, "polderrace3d-garage": {"credits": 10, "cars": {"gt": {"num": 7}, "hatch": {"rimStyle": "dish"}, "mini": "rommel"}}})
	var u := G.carUp("gt")
	var ok: bool = u.has("rimStyle") and u.has("wing") and u.has("rim") and u.has("stripe") and G.carUp("hatch").has("num") and G.carUp("mini").has("rimStyle")
	var m2 := CarKit.buildCar("gt", Color.RED)
	CarKit.styleCar(m2, "gt")
	r.check(ok and m2.get("lookDone", false) and int(m2.look.num) == 7, "half ingevulde garage (nummer zonder velgmodel, ...) wordt aangevuld", str(u))
	drop(m2)
	var e2 := log.take()
	r.check(e2.is_empty(), "half ingevulde garage: geen foutmeldingen", "; ".join(e2.slice(0, 3)))

# ------------------------------------------------------------------ the catalogue itself
func part_catalogue() -> void:
	var keys := {}
	var bad := []
	var n_opts := 0
	var groups: Array = CarLook.GROUPS.map(func(g): return g[0])
	for it in CarLook.ITEMS:
		if keys.has(it.k): bad.append("dubbele sleutel " + it.k)
		keys[it.k] = true
		if not it.type in ["choice", "color", "num", "text"]: bad.append(it.k + ": type")
		if not groups.has(it.g): bad.append(it.k + ": groep")
		if not GarageRoom.VIEWS.has(it.get("view", "")): bad.append(it.k + ": camera")
		if it.k != "paint" and (typeof(CarLook.cleanValue(it.k, it.def)) != typeof(it.def) or CarLook.cleanValue(it.k, it.def) != it.def): bad.append(it.k + ": standaardwaarde ongeldig")
		var ids := {}
		for o in it.get("opts", []):
			n_opts += 1
			if ids.has(o[0]): bad.append("%s: dubbele optie %s" % [it.k, o[0]])
			ids[o[0]] = true
			if int(o[2]) < 0 or str(o[1]) == "": bad.append("%s/%s: naam of prijs" % [it.k, o[0]])
			var ex: Dictionary = o[3] if o.size() > 3 else {}
			if ex.has("ach") and Ach.achInfo(ex.ach).is_empty(): bad.append("%s/%s: prestatie %s bestaat niet" % [it.k, o[0], ex.ach])
			if ex.has("ach") and int(o[2]) != 0: bad.append("%s/%s: vrijspelen én een prijs" % [it.k, o[0]])
			if it.type == "color" and not CarLook.isHex(ex.get("hex", o[0])): bad.append("%s/%s: kleur" % [it.k, o[0]])
			if ex.has("view") and not GarageRoom.VIEWS.has(ex.view): bad.append("%s/%s: camera" % [it.k, o[0]])
			for c in ex.get("cols", []):
				if CarLook.option("sc", c) == null: bad.append("%s/%s: kleur %s" % [it.k, o[0], c])
		if it.type in ["choice", "color"] and it.get("opts", []).is_empty(): bad.append(it.k + ": geen opties")
	r.check(bad.is_empty(), "catalogus klopt (sleutels, opties, kleuren, prestaties, camera's)", "%d items, %d opties%s" % [CarLook.ITEMS.size(), n_opts, ("; " + ", ".join(bad)) if not bad.is_empty() else ""])
	r.check(CarLook.ITEMS.size() >= 24 and n_opts >= 150, "veel te kiezen", "%d items, %d opties" % [CarLook.ITEMS.size(), n_opts])
	# every design that is drawn on the doors has a drawing, and the other way round
	var doors: Array = CarLook.item("stripe").opts.map(func(o): return o[0]).filter(func(id): return CarDecal.DOORS.has(id))
	r.check(doors.size() == CarDecal.DOORS.size(), "elk deurontwerp staat in de catalogus", str(doors))
	# prices: a nice set is affordable from the first chapter's prize money (no grinding)
	var first := 0
	for e in Career.CHAPTERS[0].events: first += int(e.prize[0])
	var set := 0
	for kv in [["paint", "#2a6fdb"], ["finish", "metallic"], ["stripe", "flames"], ["rim", "gun"], ["d1", "polder"], ["d2", "tulp"], ["plate", "YIP-01"]]:
		for nd in G.lookNeeds(kv[0], kv[1]): set += int(nd[1])
	r.check(set > 0 and set * 3 <= first, "een mooie set kost hooguit een derde van het prijzengeld van hoofdstuk 1", "set € %d, hoofdstuk 1 € %d" % [set, first])

# ------------------------------------------------------------------ every option on every car
func part_apply() -> void:
	var total := 0
	for id in Cars.CARS:
		var base := CarKit.buildCar(id, Color("#1d4f9e"))
		var bad := []
		# round i puts option i of every item on one car: every option gets its turn, in changing company
		var most := 0
		for it in CarLook.ITEMS: most = maxi(most, values(it).size())
		for i in most:
			var look := {}
			for it in CarLook.ITEMS:
				var vs := values(it)
				look[it.k] = vs[i % vs.size()]
			look.num = [7, 0, 99, 12][i % 4]
			var m := car(id, look)
			total += 1
			if not m.get("lookDone", false):
				bad.append("ronde %d: niet afgemaakt" % i)
			else:
				for k in look:
					var want = look[k] if CarLook.fits(id, k) and CarLook.optFits(id, k, look[k]) else CarLook.item(k).def
					if k == "paint": want = CarLook.cleanValue(k, want)
					if m.look.get(k) != want and not (k == "paint" and want == ""): bad.append("%s = %s werd %s" % [k, want, m.look.get(k)])
				if m.len != base.len or m.wid != base.wid or m.rc != base.rc or m.wheels.size() != base.wheels.size(): bad.append("ronde %d: hitbox of wielen veranderd" % i)
			drop(m)
		drop(base)
		r.check(bad.is_empty(), "%s: elke optie past" % id, ", ".join(bad.slice(0, 4)) if not bad.is_empty() else "%d rondes" % most)
	# what a look does, on one car
	var plain := car("gt", {})
	var n0: int = Cars_.dump_nodes(plain.g).size()
	var full := car("gt", {"stripe": "flames", "d1": "polder", "d2": "tulp", "ban": "HALLO", "glow": "blue", "num": 7, "numStyle": "square", "roof": "black", "tint": "blue", "lamp": "yellow",
		"cal": "yellow", "tw": "white", "plate": "YIP-01", "rim": "red", "finish": "matte", "paint": "#ff00aa"})
	var nodes: Array = Cars_.dump_nodes(full.g)
	# (4 of them: the lettered ring on each tyre, CarKit.setTyreWall; the tyre itself is part of the one-mesh wheel)
	r.check(nodes.size() <= n0 + 13, "een volle look kost hooguit 13 meshes extra", "%d -> %d" % [n0, nodes.size()])
	var mats := {}
	for o in nodes:
		for s in o.mesh.get_surface_count(): mats[o.get_surface_override_material(s)] = true
	r.check(not mats.has(CarKit.carGlass) and not mats.has(CarKit.lampMat) and not mats.has(CarKit.carPlate),
		"ruiten, lampen en kenteken hebben hun eigen materiaal")
	# calipers and tyres are part of the wheels (vertex colours, CarKit): the calipers recoloured, a lettered ring on each tyre
	var yel := CarLook.colorOf("cal", "yellow")
	var calOk := true
	for wh in full.wheels:
		var c = wh.get("cal")
		if c != null:
			var k: Color = c.get_meta("geo").col[0]
			if not Color(k.r, k.g, k.b).is_equal_approx(Color(yel.r, yel.g, yel.b)): calOk = false
	r.check(calOk and full.wheels.all(func(wh): return wh.get("wall") != null), "remklauwen in de lookkleur, banden met opdruk")
	r.check(mats.has(CarKit.tailMat), "achterlichten blijven het gedeelde materiaal (remlicht van de speler)")
	r.check(full.paint.albedo_color.is_equal_approx(Color("#ff00aa")), "lakkleur uit de look", full.paint.albedo_color.to_html(false))
	r.check(nodes.any(func(o): return o.has_meta("glow")), "neon ligt onder de auto")
	var plain_nodes: Array = Cars_.dump_nodes(plain.g)
	var shared := true
	for o in plain_nodes:
		for s in o.mesh.get_surface_count():
			var mt = o.get_surface_override_material(s)
			if mt == CarKit.carGlass and not Color(mt.albedo_color, 1).is_equal_approx(MathX.col(CarKit.GLASS_TINT)): shared = false
	r.check(shared, "een look verandert de gedeelde materialen niet (andere auto's blijven zoals ze zijn)")
	drop(plain); drop(full)
	# cars without a roof: no roof colour, no band; class S: no exhaust choice
	var ro := car("roadster", {"roof": "black", "ban": "DAK", "exhaust": "dual"})
	r.check(ro.look.roof == "" and ro.look.ban == "" and ro.look.exhaust == "dual", "roadster: geen dak, geen voorruitband, wel een uitlaat", str(CarLook.compact(ro.look)))
	drop(ro)
	var sup := car("super", {"exhaust": "dual"})
	r.check(sup.look.exhaust == "std", "klasse S: uitlaat blijft af fabriek")
	drop(sup)
	# every sticker and the band have a place on every car that can carry them
	var no_room := []
	for id in Cars.CARS:
		var K := CarKit.carKit(id)
		var sp := CarLook.stickerSpots(K)
		if sp[0].is_empty() and not K.S.has("numFin"): no_room.append(id + ": sticker voor")    # (the prototype's flank is too low)
		if K.C != null and CarLook.bannerGeo(K) == null: no_room.append(id + ": voorruitband")
		if CarLook.doorGeo(K) == null: no_room.append(id + ": deurontwerp")
	r.check(no_room.is_empty(), "elke auto heeft plek voor een sticker, een deurontwerp en (met dak) de voorruitband", ", ".join(no_room))
	print("--   ", total, " auto's gebouwd")

# ------------------------------------------------------------------ body kits (CarParts): every part on every car it fits
const KIT_A := {"wing": "rally", "splitter": "race", "canard": "on", "skirt": "black", "arch": "black", "diffuser": "on", "flap": "red", "scoop": "scoop",
	"roofx": "bar", "tow": "on", "exhaust": "big", "wsize": "l", "track": "l", "ride": "low"}
const KIT_B := {"wing": "swan", "splitter": "street", "skirt": "paint", "arch": "paint", "scoop": "vents", "roofx": "rack", "wsize": "m", "track": "m", "ride": "high", "flap": "black"}
const KIT_C := {"wing": "lip", "roofx": "scoop", "exhaust": "big", "ride": "low"}

## cells of 10 cm holding the skin of a model (body and cabin)
func _skinCells(K: CarBody) -> Dictionary:
	var cells := {}
	for g in [K.body, K.cab]:
		if g == null: continue
		for v in g.pos: cells[Vector3i((v / 0.1).floor())] = true
	return cells

func _touches(A: CarAcc, cells: Dictionary) -> bool:
	for i in range(0, A.P.size(), 3):
		var c := Vector3i((A.P[i] / 0.1).floor())
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				for dz in [-1, 0, 1]:
					if cells.has(c + Vector3i(dx, dy, dz)): return true
	return false

func part_kits() -> void:
	var missing := []
	var offered := {}      ## "k=v" -> [cars it fits by the item's rule, cars it builds on]
	var outside := []
	var floating := []
	var n := 0
	for id in Cars.CARS:
		var K := CarKit.carKit(id)
		var S := K.S
		var cells := _skinCells(K)
		var hl: float = float(S.len) / 2.0
		var off: float = S.get("off", 0.0)
		for it in CarLook.ITEMS:
			if not it.k in CarParts.PART_KEYS or not CarLook.fits(id, it.k): continue
			for o in it.opts:
				var v: String = o[0]
				if v in ["none", "std"] or (it.k == "wing" and not v in CarParts.WINGS) or (it.k == "exhaust" and not v in CarParts.EXHAUSTS): continue
				n += 1
				var P := CarParts.part(K, it.k, v)
				var kv: String = it.k + "=" + v
				if not offered.has(kv): offered[kv] = [0, 0]
				offered[kv][0] += 1
				if P.d == null and P.p == null:
					missing.append("%s %s" % [id, kv])
					if CarLook.optFits(id, it.k, v): outside.append(id + " " + kv + ": niet gebouwd maar wel te koop")
					continue
				offered[kv][1] += 1
				for A in [P.d, P.p]:
					if A == null: continue
					var mn := Vector3(1e9, 1e9, 1e9)
					var mx := -mn
					for q in A.P: mn = mn.min(q); mx = mx.max(q)
					# inside the hitbox's plan (wide arches and splitters a few centimetres proud), above the road
					if maxf(-mn.x, mx.x) > float(S.wid) / 2.0 + 0.08 or mx.z > off + hl + 0.1 or mn.z < off - hl - 0.08 or mn.y < 0.075:
						outside.append("%s %s=%s %s..%s" % [id, it.k, v, mn.snapped(Vector3.ONE * 0.01), mx.snapped(Vector3.ONE * 0.01)])
					if not _touches(A, cells): floating.append("%s %s=%s" % [id, it.k, v])
	var rare := []
	for kv in offered:
		if offered[kv][1] * 4 < offered[kv][0] * 3: rare.append("%s: %d van %d" % [kv, offered[kv][1], offered[kv][0]])
	r.check(rare.is_empty(), "elk bodykit-onderdeel past op (bijna) elke auto; waar niet, staat het niet in de garage", ("%d onderdelen, niet op: %s" % [n, ", ".join(missing)]) if rare.is_empty() else ", ".join(rare))
	r.check(outside.is_empty(), "onderdelen binnen de hitbox (bovenaanzicht) en boven de weg", ", ".join(outside.slice(0, 4)))
	r.check(floating.is_empty(), "onderdelen zitten aan de carrosserie vast (niets zweeft)", ", ".join(floating.slice(0, 6)))
	# a full kit on every car: still a sound car (wheels on the road, nothing through it, budgets), same hitbox, two meshes more
	var bad := []
	var extra := 0
	for id in Cars.CARS:
		var base := car(id, {})
		var n0: int = Cars_.dump_nodes(base.g).filter(func(o): return o.visible).size()
		for kit in [KIT_A, KIT_B, KIT_C]:
			var m := car(id, kit)
			var fl: String = Cars_.faults(id + "/kit", m, true)
			if fl != "": bad.append("%s: %s" % [id, fl])
			if m.len != base.len or m.wid != base.wid or m.rc != base.rc or m.off != base.off: bad.append(id + ": hitbox veranderd")
			for wh in m.wheels:
				if absf(wh.pivot.position.x) + float(wh.w) / 2.0 > float(m.wid) / 2.0 + 1e-3: bad.append(id + ": wiel buiten de hitbox")
			var parts: Array = Cars_.dump_nodes(m.g).filter(func(o): return o.has_meta("parts"))
			if parts.size() > 2: bad.append("%s: %d meshes voor de onderdelen" % [id, parts.size()])
			extra = maxi(extra, Cars_.dump_nodes(m.g).filter(func(o): return o.visible).size() - n0)
			drop(m)
		drop(base)
	r.check(bad.is_empty(), "volle bodykit op elke auto: wielen op de weg, niets door de weg, binnen het budget, hitbox gelijk", ", ".join(bad.slice(0, 4)) if not bad.is_empty() else "hooguit %d meshes extra" % extra)
	# wheel size, track and ride height do what they say
	var a := car("gt", {})
	var b := car("gt", {"wsize": "l", "track": "l", "ride": "low"})
	var rbA: float = CarKit.wheelGeos(a.wheels[0].r, a.wheels[0].w, "std").rb
	var rbB: float = CarKit.wheelGeos(b.wheels[0].r, b.wheels[0].w, "std", null, 0.72, b.wheels[0].get("big", 0.0)).rb
	r.check(rbB > rbA + 0.02 and b.wheels[0].mesh.get_meta("geo") != a.wheels[0].mesh.get_meta("geo"), "velgmaat: grotere velg", "%.3f -> %.3f" % [rbA, rbB])
	r.check(absf(b.wheels[0].pivot.position.x) > absf(a.wheels[0].pivot.position.x) + 0.01 and b.wheels[0].pivot.position.y == a.wheels[0].pivot.position.y, "spoorbreedte: wielen verder naar buiten, op dezelfde hoogte")
	r.check(b.shell.position.y < -0.01 and a.shell.position.y == 0.0, "rijhoogte: de carrosserie zakt, de wielen niet")
	drop(a); drop(b)
	var flat := []
	for id in Cars.CARS:
		var lo := car(id, {"ride": "low"})
		if lo.shell.position.y > -0.015: flat.append("%s %.3f" % [id, lo.shell.position.y])
		drop(lo)
	r.check(flat.is_empty(), "Verlaagd: elke auto zakt minstens 1,5 cm (en nooit tot op de weg)", ", ".join(flat))
	# the diffuser stays clear of every exhaust the model can wear (stock, sport, dual, centre, kanon)
	var hitEx := []
	for id in Cars.CARS:
		if not CarLook.fits(id, "diffuser"): continue
		var K := CarKit.carKit(id)
		var P := CarParts.part(K, "diffuser", "on")
		if P.d == null: continue
		var tri: PackedVector3Array = P.d.P
		for t in CarParts.exhaustTips(K):
			var hit := false
			for i in range(0, tri.size() - 2, 3):
				if hit: break
				for ia in 31:
					if hit: break
					for ib in 31 - ia:
						var q: Vector3 = tri[i] + (tri[i + 1] - tri[i]) * (ia / 30.0) + (tri[i + 2] - tri[i]) * (ib / 30.0)
						if q.z > t[3] - 0.03 and q.z < t[3] + 0.17 and Vector2(q.x - t[0], q.y - t[1]).length() < t[2] - 0.004:
							hit = true
							break
			if hit: hitEx.append("%s: uitlaat x %.2f r %.3f" % [id, t[0], t[2]])
	r.check(hitEx.is_empty(), "diffuser: geen uitlaat (af fabriek, sport, dubbel, centraal, kanon) door de vinnen of de plaat", ", ".join(hitEx.slice(0, 6)))
	# carbon / matt black bonnet: the bonnet only, never the fender humps beside it (super, hyper, proto, ...)
	var hoodBad := []
	var hooded := 0
	for id in Cars.CARS:
		var K := CarKit.carKit(id)
		var sp := CarParts.hoodSplit(K, false, "carbon")
		if sp.is_empty(): continue
		hooded += 1
		var hump := 0
		var memo := {}
		var maxRise := 0.0
		var zA: float = (K.C.z0 + 0.02) if K.C != null else float(K.S.wz[0]) - 0.75
		var wideBack := 0.0      ## how wide the bonnet is just in front of the windscreen
		for p in (sp[1] as Geo).pos:
			var rise := CarParts._hump(K, p.z, memo)
			maxRise = maxf(maxRise, rise)
			if p.y > K.topY(p.z, 0.0) + 0.035 and rise >= 0.1: hump += 1
			if p.z < zA + 0.25: wideBack = maxf(wideBack, absf(p.x))
		if hump > 0: hoodBad.append("%s: %d punten op de spatborden" % [id, hump])
		# a bonnet without humps stays whole (the evo's curves up towards the wings: all of it, up to the windscreen)
		if maxRise < 0.1 and wideBack < 0.5: hoodBad.append("%s: kap bij de voorruit maar %.2f m breed" % [id, wideBack * 2])
	r.check(hoodBad.is_empty() and hooded >= 14, "carbon motorkap: alleen de kap, niet de spatborden ernaast", ", ".join(hoodBad.slice(0, 4)) if not hoodBad.is_empty() else "%d auto's" % hooded)
	# a spoiler from the kit replaces the factory one; the kanon replaces the factory exhaust
	var w := car("gt", {"wing": "swan", "exhaust": "big"})
	r.check(w.stockWing.all(func(o): return not o.visible) and w.g.get_meta("exh").meshes.all(func(o): return not o.visible), "bodykit-spoiler en kanon vervangen die van de fabriek")
	drop(w)

# ------------------------------------------------------------------ save -> lookOf -> JSON -> the same car
func part_roundtrip() -> void:
	var owned := {}
	for id in Cars.CARS: owned[id] = true
	var looks := {"mix": 1}
	for it in CarLook.ITEMS:
		if it.has("kit"): looks[it.k] = 1
		for o in it.get("opts", []): looks["%s:%s" % [it.k, o[0]]] = 1
	var ach := {}
	for a in Ach.ACH: ach[a[0]] = 1
	G.use_store("user://test-looks.json", {"polderrace3d-settings": {"car": "gt", "color": "#f36f21"}, "polderrace3d-garage": {"credits": 100, "owned": owned, "looks": looks, "ach": ach}})
	var want := {"paint": "#2a6fdb", "finish": "pearl", "roof": "white", "stripe": "lion", "sc": "gold", "sc2": "#123456", "rimStyle": "dish", "rim": "#aa5500", "cal": "blue", "tw": "letter",
		"tint": "bronze", "lamp": "purple", "glow": "pink", "num": 46, "numStyle": "ring", "numBg": "yellow", "numFg": "white", "numFont": "round", "numPos": "doors", "plate": "YIP-46",
		"plateStyle": "old", "d1": "kaas", "d2": "molen", "ban": "TEAM YIP", "banCol": "orange", "wing": "swan", "exhaust": "big",
		"splitter": "race", "canard": "on", "skirt": "paint", "arch": "paint", "diffuser": "on", "flap": "red", "scoop": "vents", "roofx": "bar", "tow": "on", "wsize": "l", "track": "m", "ride": "low"}
	for k in want: G.lookPick("gt", k, want[k])
	r.check(G.fit.look.is_empty() and G.garage.credits == 100, "alles in bezit: keuzes gaan meteen op de auto, niets in de paskamer")
	var L := G.lookOf("gt")
	var same := true
	for k in want:
		if L.get(k) != want[k]: same = false
	r.check(same and L.size() == want.size(), "G.lookOf geeft de look terug", str(L))
	r.check(not L.has("eng") and not L.has("col") and not L.has("turbo"), "G.lookOf zonder upgrades")
	var wire := JSON.stringify(L)
	r.check(wire.length() < 600, "look is klein genoeg om te versturen", "%d tekens" % wire.length())
	G._flush()
	G.use_store("user://test-looks.json", JSON.parse_string(FileAccess.get_file_as_string("user://test-looks.json")))
	var L2 := G.lookOf("gt")
	r.check(JSON.stringify(L2) == wire, "look komt gelijk terug uit het savebestand", JSON.stringify(L2) if JSON.stringify(L2) != wire else "")
	# the same car from the dictionary as from the garage (another player's screen)
	var mine := CarKit.buildCar("gt", Color(G.settings.color))
	CarKit.styleCar(mine, "gt")
	var parsed = JSON.parse_string(wire)
	var theirs := CarKit.buildCar("gt", Color(str(parsed.paint)))
	CarKit.styleCar(theirs, parsed)
	var diff: String = Cars_.compare(Cars_.dump(mine), JSON.parse_string(JSON.stringify(Cars_.dump(theirs))))
	r.check(diff == "", "auto uit G.lookOf (via JSON) = auto uit de garage", diff)
	drop(mine); drop(theirs)
	# a car with nothing chosen sends next to nothing
	var plain := G.lookOf("hatch")
	r.check(plain.size() == 1 and plain.has("paint"), "auto zonder keuzes: alleen de lakkleur", str(plain))
	# paint per car
	G.settings.car = "gt"; G.settings.color = "#2a6fdb"
	Menu.pickCar("hatch")
	r.check(G.settings.car == "hatch" and G.settings.color == "#2a6fdb", "andere auto zonder eigen kleur: de kleur gaat mee")
	G.lookPick("hatch", "paint", "#d62a2a")
	Menu.pickCar("gt")
	r.check(G.settings.color == "#2a6fdb", "terug in de GT: zijn eigen kleur", G.settings.color)
	Menu.pickCar("hatch")
	r.check(G.settings.color == "#d62a2a" and G.lookOf("gt").paint == "#2a6fdb", "terug in de hatch: rood; de GT blijft blauw", G.settings.color)

# ------------------------------------------------------------------ junk never breaks a car
func part_junk() -> void:
	var junk := [null, 3, -1, 1e30, NAN, INF, true, "", "x", "#zzzzzz", "#12345", "#1234567", "none; drop", [], [1, 2], {}, {"a": 1}, "A".repeat(5000), "std\n", 0.5]
	var D := CarLook.defaults()
	var bad := []
	for it in CarLook.ITEMS:
		for j in junk:
			var v = CarLook.cleanValue(it.k, j)
			var ok := false
			match it.type:
				"choice": ok = CarLook.option(it.k, v) != null
				"color": ok = v is String and (v == "" or CarLook.option(it.k, v) != null or CarLook.isHex(v))
				"num": ok = v is int and v >= 0 and v <= 99
				"text": ok = v is String and v.length() <= int(it.max)
			if not ok: bad.append("%s <- %s gaf %s" % [it.k, str(j).left(12), str(v).left(12)])
	r.check(bad.is_empty(), "rommel wordt een geldige waarde", ", ".join(bad.slice(0, 5)))
	var L := CarLook.clean({"stripe": 12, "rim": ["gold"], "num": "7", "plate": "drop table;<b>", "ban": "héllo wörld 💥", "glow": "#GGGGGG", "wing": null, "foo": "bar", "eng": 3, "paint": "red"}, "gt")
	r.check(L.stripe == D.stripe and L.rim == D.rim and L.num == 0 and L.glow == "" and L.wing == "std" and not L.has("foo") and not L.has("eng") and not L.has("paint"),
		"een look vol rommel wordt de standaardlook", str(CarLook.compact(L)))
	r.check(L.plate == "DROP TAB" and L.ban == "HLLO WRLD", "teksten: alleen toegestane tekens, op lengte", "%s / %s" % [L.plate, L.ban])
	for u in [{"stripe": 12, "rim": [], "num": NAN, "numStyle": {}, "plate": 5, "d1": "nope", "glow": 1, "paint": 7, "rimStyle": "x", "wing": "x", "exhaust": 9}, {"num": 1e30, "roof": "#12", "tw": null}]:
		var m := car("gt", u)
		r.check(m.get("lookDone", false) and CarLook.compact(m.look).is_empty(), "auto met rommel-look wordt gewoon gebouwd (standaard)", str(CarLook.compact(m.look)))
		drop(m)
	r.check(CarLook.clean("geen woordenboek", "gt") == CarLook.clean({}, "gt") and CarLook.clean(null) == CarLook.clean({}), "geen woordenboek: standaardlook")
	# looks from before the catalogue: the stripe colour was the choice
	for old in [["white", "white"], ["black", "black"], ["yellow", "yellow"]]:
		var Lo := CarLook.clean({"stripe": old[0]}, "gt")
		if Lo.stripe != "twin" or Lo.sc != old[1]: r.check(false, "oude streep " + old[0], str(Lo))
	r.check(CarLook.clean({"stripe": "white"}, "gt").stripe == "twin", "oude strepen (wit, zwart, geel) worden de dubbele streep in die kleur")

# ------------------------------------------------------------------ old and new saves
func part_saves() -> void:
	# a save from before the catalogue (HTML game / phase 1): looks as they were, the free colour picker stays
	G.use_store("user://test-looks.json", {"polderrace3d-settings": {"car": "gt", "color": "#3a7f2c"},
		"polderrace3d-garage": {"credits": 900, "owned": {"hatch": true, "gt": true}, "cars": {"gt": {"eng": 2, "turbo": 0, "tyre": 1, "brake": 0, "body": 0, "rim": "gold", "stripe": "yellow",
			"num": 7, "wing": "gt", "rimStyle": "spoke", "exhaust": "sport"}, "hatch": {"eng": 0, "turbo": 0, "tyre": 0, "brake": 0, "rim": "black", "stripe": "none"}}}})
	var L := G.lookOf("gt")
	r.check(L == {"stripe": "twin", "sc": "yellow", "rim": "gold", "num": 7, "wing": "gt", "rimStyle": "spoke", "exhaust": "sport", "paint": "#3a7f2c"}, "oude save: uiterlijk blijft", str(L))
	r.check(G.lookHas("mix") and G.lookNeeds("paint", "#3a7f2c").is_empty(), "oude save: eigen kleur blijft gratis (kleurenmenger in bezit)")
	r.check(int(G.carUp("gt").eng) == 2 and G.effStats("gt").vmax > Cars.CARS.gt.vmax, "oude save: upgrades blijven")
	var h := G.lookOf("hatch")
	r.check(h.get("stripe") == "none" and h.get("rim") == "black", "oude save: auto zonder nummer/spoiler-velden", str(h))
	var a := car("gt", G.carUp("gt"))
	var b := car("gt", {"stripe": "yellow", "rim": "gold", "num": 7, "wing": "gt", "rimStyle": "spoke", "exhaust": "sport"})
	var diff: String = Cars_.compare(Cars_.dump(a), JSON.parse_string(JSON.stringify(Cars_.dump(b))))
	r.check(diff == "", "oude save: zelfde auto als voorheen", diff)
	drop(a); drop(b)
	# a new player: nothing bought, no mixer
	G.use_store("user://test-looks.json", {})
	r.check(not G.lookHas("mix") and G.garage.looks.is_empty(), "nieuwe speler: nog niets gekocht, geen kleurenmenger")
	r.check(G.lookNeeds("paint", "#123456") == [["mix", CarLook.MIX_PRICE, "Kleurenmenger", ""]], "nieuwe speler: eigen kleur vraagt de kleurenmenger")
	r.check(G.lookNeeds("paint", "#f36f21").is_empty() and G.lookNeeds("stripe", "twin").is_empty() and G.lookNeeds("rim", "gold").is_empty() and G.lookNeeds("wing", "gt").is_empty(),
		"wat altijd gratis was, is gratis gebleven")

# ------------------------------------------------------------------ bots
func part_bots() -> void:
	var a := CarLook.botLook("Henk", "gt", "#d62a2a")
	var b := CarLook.botLook("Henk", "gt", "#d62a2a")
	r.check(JSON.stringify(a) == JSON.stringify(b) and int(a.num) > 0, "bot: zelfde naam en auto, zelfde look", str(a))
	var seen := {}
	for n in Game.BOT_NAMES + Career.CAREER_NAMES:
		for t in ["gt", "hatch", "super"]:
			var L := CarLook.botLook(n, t, "#1d4f9e")
			seen[JSON.stringify(L)] = true
			if CarLook.compact(CarLook.clean(L, t)) != L: r.check(false, "botlook geldig", "%s %s: %s" % [n, t, L])
	r.check(seen.size() >= 12, "bots verschillen van elkaar", "%d looks" % seen.size())
	for id in Career.RIVALS:
		var R: Dictionary = Career.RIVALS[id]
		var L := CarLook.botLook(R.name, "v12", R.color, true)
		r.check(CarLook.RIVAL_LOOKS.has(R.name) and CarLook.compact(CarLook.clean(L, "v12")) == L and L.size() >= 6, "rivaal %s heeft een eigen, geldige look" % R.name, str(L))
	r.check(JSON.stringify(CarLook.botLook("Daan", "gt", "#d62a2a")) != JSON.stringify(CarLook.botLook("Daan", "gt", "#d62a2a", true)), "een gewone bot die Daan heet, is de rivaal niet")
	# bots in a race wear it
	G.settings.car = "gt"; G.settings.bots = 3
	Game.setupBots(3)
	var nums := Game.bots.map(func(q): return int(q.m.get("look", {}).get("num", 0)))
	r.check(Game.bots.size() == 3 and nums.all(func(n): return n > 0), "bots op de baan hebben een startnummer", str(nums))
	Game.clearBots()

# ------------------------------------------------------------------ buying, owning, kits, mixer, unlocks
func part_buying() -> void:
	G.use_store("user://test-looks.json", {"polderrace3d-settings": {"car": "hatch", "color": "#f36f21"}, "polderrace3d-garage": {"credits": 1000, "owned": {"hatch": true, "gt": true}, "looks": {}}})
	Game.rebuildPlayerCar()
	G.lookPick("hatch", "finish", "pearl")
	r.check(G.fit.look == {"finish": "pearl"} and G.carUp("hatch").get("finish", "gloss") == "gloss" and not G.lookOf("hatch").has("finish"), "niet gekocht: in de paskamer, niet op de auto bewaard, niet in lookOf")
	r.check(G.styleUp("hatch").get("finish") == "pearl", "paskamer is te zien op de auto in de garage")
	r.check(G.lookShown("hatch", "finish") == "pearl", "de garage toont de gepaste waarde")
	G.lookPick("hatch", "stripe", "flames")
	var c := G.fitCost()
	r.check(c.total == 1500 and c.items.size() == 2 and c.locked == 0, "paskamer: twee dingen, € 1.500", str(c))
	r.check(not G.fitBuy() and G.garage.credits == 1000 and not G.lookHas("finish:pearl"), "te weinig geld: niets gekocht")
	G.garage.credits = 1600
	r.check(G.fitBuy() and G.garage.credits == 100 and G.lookHas("finish:pearl") and G.lookHas("stripe:flames"), "gekocht: geld eraf, in bezit", str(G.garage.credits))
	r.check(G.fit.look.is_empty() and G.carUp("hatch").finish == "pearl" and G.lookOf("hatch").stripe == "flames", "gekocht: op de auto bewaard")
	var sv := saved("polderrace3d-garage")
	r.check(sv.looks.has("finish:pearl") and sv.cars.hatch.finish == "pearl" and int(sv.credits) == 100, "aankoop bewaard in de save")
	# account-wide: free on the next car; switching back and forth costs nothing
	G.lookPick("gt", "finish", "pearl")
	r.check(G.fit.look.is_empty() and G.carUp("gt").finish == "pearl" and G.garage.credits == 100, "eenmaal gekocht: gratis op je andere auto's")
	G.lookPick("hatch", "finish", "gloss"); G.lookPick("hatch", "finish", "pearl")
	r.check(G.garage.credits == 100 and G.carUp("hatch").finish == "pearl", "wisselen tussen wat je hebt kost niets")
	# a kit: one price for the item, then every colour
	G.garage.credits = 2000
	G.lookPick("hatch", "glow", "blue")
	r.check(G.fitCost().total == 900, "neon: de set kost € 900", str(G.fitCost()))
	G.fitBuy()
	G.lookPick("hatch", "glow", "pink")
	r.check(G.lookHas("glow") and G.fit.look.is_empty() and G.carUp("hatch").glow == "pink" and G.garage.credits == 1100, "neon gekocht: elke kleur vrij", str(G.garage.credits))
	# the mixer: once, for every colour item
	G.lookPick("hatch", "paint", "#123456")
	G.lookPick("hatch", "rim", "#654321")
	r.check(G.fitCost().total == CarLook.MIX_PRICE and G.fitCost().items.size() == 1, "kleurenmenger: één keer betalen voor alle eigen kleuren", str(G.fitCost()))
	r.check(G.settings.color == "#f36f21", "gepaste lak verandert de bewaarde kleur niet", G.settings.color)
	G.fitBuy()
	r.check(G.lookHas("mix") and G.settings.color == "#123456" and G.carUp("hatch").rim == "#654321" and G.garage.credits == 1100 - CarLook.MIX_PRICE, "kleurenmenger gekocht: lak en velgen in eigen kleur")
	# locked: not for sale, free once the achievement is there
	var cr: int = G.garage.credits
	G.lookPick("hatch", "stripe", "lion")
	c = G.fitCost()
	r.check(c.locked == 1 and c.total == 0, "Oranje leeuw: niet te koop", str(c))
	r.check(G.fitBuy() and G.fit.look.has("stripe") and G.carUp("hatch").stripe == "flames" and G.garage.credits == cr, "Kopen laat wat nog vrijgespeeld moet worden in de paskamer")
	r.check(G.fitClear() and G.fit.look.is_empty() and G.lookShown("hatch", "stripe") == "flames", "Terugzetten: de auto is weer zoals hij was")
	G.garage.ach["cupS"] = 1
	G.lookPick("hatch", "stripe", "lion")
	r.check(G.fit.look.is_empty() and G.carUp("hatch").stripe == "lion", "Oranje Grand Prix gewonnen: de Oranje leeuw is vrij")
	# looks never touch performance
	var e := G.effStats("hatch")
	var k: Dictionary = Cars.CARS.hatch
	r.check(e.vmax == k.vmax and e.acc == k.acc and e.grip == k.grip and e.brake == k.brake, "uiterlijk verandert de prestaties niet")

# ------------------------------------------------------------------ the garage: fitting room, leaving, random, reset
func part_garage() -> void:
	G.use_store("user://test-looks.json", {"polderrace3d-settings": {"car": "hatch", "color": "#f36f21"}, "polderrace3d-garage": {"credits": 5000, "owned": {"hatch": true, "gt": true}, "looks": {}}})
	Game.rebuildPlayerCar()
	Menu.homePanel("garage")
	var ui: GarageUI = Menu.garageUI
	ui.tabLook.press()
	r.check(ui.look.visible and ui.lookTools.visible and not ui.fitBar.visible, "tab Uiterlijk open, paskamer leeg")
	ui.lookGroup("lak")
	ui.radio("finish").find("matte").press()
	r.check(ui.fitBar.visible and ui.fitBuy.visible and not ui.fitBuy.disabled and Game.car.look.finish == "matte", "mat gepast: te zien op de auto, balk met Kopen")
	r.check((ui.fitBuy.get_meta("label") as Label).text.contains("500") and ui.fitText.text.contains("Mat"), "balk noemt wat het kost", ui.fitText.text)
	ui.fitBuy.press()
	r.check(G.lookHas("finish:matte") and G.garage.credits == 4500 and not ui.fitBar.visible and G.carUp("hatch").finish == "matte", "Kopen in de balk")
	# leaving puts unpaid things back: another tab, another car, out of the garage
	ui.radio("finish").find("chrome").press()
	ui.tabPerf.press()
	r.check(G.fit.look.is_empty() and Game.car.look.finish == "matte", "tab Prestaties: gepaste afwerking teruggezet")
	ui.tabLook.press()
	ui.radio("finish").find("chrome").press()
	ui.lookGroup("stripe")
	ui.radio("stripe").find("flames").press()
	r.check(G.fit.look.size() >= 2 and G.fit.look.get("sc") == null and G.carUp("hatch").sc == "yellow", "Vlammen krijgt zijn eigen kleuren (geel en rood, gratis)", str(G.fit.look))
	Menu.homeBack()
	r.check(not GarageRoom.inGarage and G.fit.look.is_empty() and Game.car.look.finish == "matte" and Game.car.look.stripe == "std", "garage uit: niets onbetaalds op de auto", str(CarLook.compact(Game.car.look)))
	r.check(not saved("polderrace3d-garage").looks.has("finish:chrome") and G.garage.credits == 4500, "niets betaald, niets gekregen")
	Menu.homePanel("garage")
	r.check(ui.tab == "look" and not ui.fitBar.visible, "garage weer open op Uiterlijk, paskamer leeg")
	ui.lookGroup("lak")
	ui.radio("finish").find("pearl").press()
	ui.tabPerf.press()
	ui.carRadio.find("gt").press()
	ui.tabLook.press()
	r.check(G.fit.look.is_empty() and Game.car.look.finish == "gloss", "andere auto: de paskamer is leeg")
	# too little money: the bar says so
	G.garage.credits = 100
	ui.radio("finish").find("chrome").press()
	r.check(ui.fitBuy.disabled and ui.fitNote.visible and ui.fitNote.text.contains("tekort"), "te weinig geld: Kopen uit, de balk zegt hoeveel je tekortkomt", ui.fitNote.text)
	ui.fitUndo.press()
	r.check(not ui.fitBar.visible and Game.car.look.finish == "gloss", "Terugzetten")
	# random: only what you have; reset: factory
	G.garage.credits = 5000
	for _i in 12:
		ui.randomLook()
		if not G.fit.look.is_empty() or G.garage.credits != 5000: r.check(false, "Willekeurig kost niets", str(G.fit.look))
	r.check(G.fit.look.is_empty() and G.garage.credits == 5000, "Willekeurig: alleen wat je hebt, niets in de paskamer")
	# with the colour mixer but without the roof and neon sets: no own colour on those (it would land in the fitting room)
	G.garage.looks["mix"] = 1
	var leak := []
	for _i in 60:
		ui.randomLook()
		if not G.fit.look.is_empty(): leak.append(str(G.fit.look))
	r.check(leak.is_empty(), "Willekeurig met kleurenmenger: geen eigen kleur op dak of neon zonder de set", ", ".join(leak.slice(0, 3)))
	G.garage.looks.erase("mix")
	var col: String = G.settings.color
	ui.resetLook()
	var L := G.lookOf("gt")
	r.check(L.size() == 1 and L.paint == col, "Standaard: fabriekslook, de lakkleur blijft", str(L))
	# the start number: stepper and field
	ui.lookGroup("num")
	rows_press(ui, "num", 1)
	rows_press(ui, "num", 1)
	r.check(int(G.carUp("gt").num) == 2 and ui.numIn.text == "2" and ui.rows.numStyle.root.visible, "startnummer met de plusknop; de stijl-rijen verschijnen", ui.numIn.text)
	rows_press(ui, "num", -1); rows_press(ui, "num", -1)
	r.check(int(G.carUp("gt").num) == 0 and not ui.rows.numStyle.root.visible, "nummer weg: de stijl-rijen ook")
	# dark garage for neon, back on when leaving
	ui.darkBtn.press()
	r.check(GarageRoom.dark, "Licht uit")
	Menu.homeBack()
	r.check(not GarageRoom.dark, "garage uit: het licht is weer aan")

func rows_press(ui: GarageUI, k: String, d: int) -> void:
	var st: Dictionary = ui.rows[k].stepper
	(st.plus if d > 0 else st.minus).press()

# ------------------------------------------------------------------ every option reachable with the keyboard
func part_keys(host: Node) -> void:
	var owned := {}
	for id in Cars.CARS: owned[id] = true
	G.use_store("user://test-looks.json", {"polderrace3d-settings": {"car": "gt", "color": "#f36f21"}, "polderrace3d-garage": {"credits": 99999, "owned": owned, "looks": {}}})
	Game.rebuildPlayerCar()
	Menu.homePanel("garage")
	var ui: GarageUI = Menu.garageUI
	ui.tabLook.press()
	ui.pick("num", 5)
	ui.pick("ban", "TEST")
	ui.pick("stripe", "triple")
	await host.get_tree().process_frame
	var missed := []
	var n := 0
	for g in CarLook.GROUPS:
		# to the group with the arrow keys on its chip, then Tab through the rows (arrows walk the options of a row)
		UiKit.focus(ui.groupRadio.checked_item())
		var guard := 0
		while ui.group != g[0] and guard < 12:
			key(KEY_RIGHT)
			guard += 1
		if ui.group != g[0]:
			missed.append("groep " + g[0])
			continue
		for it in CarLook.itemsOf(g[0]):
			if not ui.rows[it.k].root.visible or ui.rows[it.k].radio == null: continue
			var rg: UiKit.Radio = ui.rows[it.k].radio
			guard = 0
			while guard < 40 and not (focused() is UiKit.Btn and focused().radio == rg):
				key(KEY_TAB)
				guard += 1
			if not (focused() is UiKit.Btn and focused().radio == rg):
				missed.append(it.k + ": rij niet bereikt")
				continue
			# right through every option: each one gets picked (shown on the car) and takes the focus
			var seen := {}
			for _i in rg.items.size() + 1:
				seen[focused().value] = true
				key(KEY_RIGHT)
				var v = G.lookShown("gt", it.k)
				var fv = focused().value
				if not (focused().radio == rg and focused().checked): missed.append("%s: focus kwijt" % it.k)
				if fv is String and fv == GarageUI.MIX:
					if not CarLook.isHex(v) or CarLook.option(it.k, v) != null: missed.append("%s: eigen kleur niet gekozen" % it.k)
				elif v != fv: missed.append("%s: %s niet gekozen (%s)" % [it.k, fv, v])
			n += seen.size()
			if seen.size() != rg.items.size(): missed.append("%s: %d van %d opties" % [it.k, seen.size(), rg.items.size()])
	r.check(missed.is_empty(), "elke optie van elke groep is met de pijltjestoetsen te kiezen", ("%d opties" % n) if missed.is_empty() else ", ".join(missed.slice(0, 6)))
	# everything that was walked through and is not owned sits in the fitting room, with one total
	var c := G.fitCost()
	r.check(c.total > 0 and c.total < 99999 and ui.fitBar.visible, "na het rondkijken: de paskamer telt alles op", "€ %d, %d dingen" % [c.total, c.items.size()])
	# Escape leaves the garage and takes nothing along
	key(KEY_ESCAPE)
	r.check(Menu.homeView == "main" and G.fit.look.is_empty() and G.garage.credits == 99999, "Esc: garage uit, niets gekocht")
	# gamepad: left/right change the option the focus is on
	Menu.homePanel("garage")
	ui.lookGroup("wheel")
	UiKit.focus(ui.radio("rimStyle").checked_item())
	var before = G.lookShown("gt", "rimStyle")
	Menu.padNav({"r": true}, {})
	r.check(G.lookShown("gt", "rimStyle") != before, "gamepad rechts: volgende optie", "%s -> %s" % [before, G.lookShown("gt", "rimStyle")])
	Menu.padNav({"down": true}, {})
	r.check(focused() is UiKit.Btn and focused().radio == ui.radio("rim"), "gamepad omlaag: volgende rij")
	Menu.homePanel("main")

# ------------------------------------------------------------------ the colour picker (own colour) with gamepad and keyboard
func part_picker(host: Node) -> void:
	G.use_store("user://test-looks.json", {"polderrace3d-settings": {"car": "gt", "color": "#f36f21"}, "polderrace3d-garage": {"credits": 5000, "owned": {"gt": true}, "looks": {}}})
	Game.rebuildPlayerCar()
	Menu.homePanel("garage")
	var ui: GarageUI = Menu.garageUI
	ui.tabLook.press()
	ui.lookGroup("wheel")
	ui.rows.rim.mix.press()
	await host.get_tree().process_frame
	r.check(ui.pickerOpen(), "eigen kleur: de kleurenkiezer gaat open")
	var before = G.lookShown("gt", "rim")
	Menu.padNav({"r": true}, {})
	Menu.padNav({"up": true}, {})
	var after = G.lookShown("gt", "rim")
	r.check(CarLook.isHex(after) and after != before and ui.pickerOpen() and Game.car.look.rim == after, "gamepad: links/rechts en op/neer kiezen de kleur, de auto toont hem", "%s -> %s" % [before, after])
	Menu.padNav({"b": true}, {})
	r.check(not ui.pickerOpen() and GarageRoom.inGarage and Menu.homeView == "garage", "gamepad B: kleurenkiezer dicht, nog in de garage")
	r.check(focused() == ui.rows.rim.mix, "focus terug op het kleurvakje")
	# Escape with the picker open closes the picker, not the garage
	await host.get_tree().process_frame
	ui.rows.rim.mix.press()
	await host.get_tree().process_frame
	var was: bool = ui.pickerOpen()
	key(KEY_ESCAPE)
	await host.get_tree().process_frame
	r.check(was and not ui.pickerOpen() and GarageRoom.inGarage, "Esc: kleurenkiezer dicht, nog in de garage", "kiezer open: %s, garage: %s" % [ui.pickerOpen(), GarageRoom.inGarage])
	if not GarageRoom.inGarage: Menu.homePanel("garage")
	# leaving the garage while the picker is open: it closes, and a colour from it no longer lands on the car
	await host.get_tree().process_frame
	ui.rows.rim.mix.press()
	await host.get_tree().process_frame
	Menu.homeBack()
	r.check(not ui.pickerOpen() and G.fit.look.is_empty(), "garage uit met de kleurenkiezer open: de kiezer gaat dicht, niets in de paskamer")
	ui.picker.color_changed.emit(Color(0.2, 0.9, 0.3))
	r.check(G.fit.look.is_empty() and G.lookShown("gt", "rim") == "silver", "een kleur uit een oude kiezer komt niet op de auto (en niet in een race)", str(G.fit.look))
	# typing a plate (not owned) and leaving with Terug while the field still has the focus: the field commits when it is
	# hidden, after the fitting room was emptied; that must not put the plate in the fitting room outside the garage
	Menu.homePanel("garage")
	ui.tabLook.press()
	ui.lookGroup("num")
	var pf: LineEdit = ui.texts.plate
	pf.grab_focus()
	pf.text = "SNEL-1"
	Menu.homeBack()
	await host.get_tree().process_frame
	r.check(G.fit.look.is_empty() and str(G.lookShown("gt", "plate")) == "", "kenteken getypt, garage uit met de focus in het veld: niets in de paskamer", str(G.fit.look))
	Menu.homePanel("main")

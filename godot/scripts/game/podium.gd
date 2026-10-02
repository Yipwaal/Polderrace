class_name Podium
## The podium scene of the HTML game (JS section "podium scene", after every race and at the end of a championship or
## cup): a stage far away (PPOS) with a banner wall carrying the title, three steps with the top three cars and their name
## labels, spotlights, grandstands and confetti. The results board stands on the left (Menu), the camera sways in front.

const PPOS := Vector3(9000, 0, -9000)
const PODIUM_STEPS := [[0.0, 1.5, 1], [-5.4, 1.08, 2], [5.4, 0.78, 3]]
const FONT := '"Barlow Condensed"'
const UI_FONT := '"Nunito"'

static var podiumRoom: Node3D = null
static var inPodium := false
static var podiumCars: Array = []
static var podiumLabels: Array = []
static var podiumLights: Array = []
static var confetti: MultiMeshInstance3D = null
static var confData: Array = []
static var podiumT := 0.0
static var podiumArgs = null

static func _scene() -> Node:
	return Game.get_tree().current_scene

static func _box(w: float, h: float, d: float, mat, x: float, y: float, z: float, g: Node3D, cast := true) -> MeshInstance3D:
	return World.box(w, h, d, mat, x, y, z, g, cast)

static func buildPodiumRoom(title: String) -> void:
	if podiumRoom != null and is_instance_valid(podiumRoom): podiumRoom.queue_free()
	var g := O3.group(PPOS.x, PPOS.y, PPOS.z)
	g.name = "Podium"
	# floor: dark stage with a checkered strip and a red carpet in front of the steps
	var floorT := Canvas2D.tex(256, 256, func(c, w, h):
		c.fillStyle = "#3d424b"; c.fillRect(0, 0, w, h)
		for _i in 500:
			c.fillStyle = "rgba(255,255,255,.05)" if randf() < .5 else "rgba(0,0,0,.08)"
			c.fillRect(randf() * w, randf() * h, 3, 3), true)
	O3.rot(O3.mesh(Geo.plane(90, 70), Mats.M(0xffffff, {"map": floorT, "repeat": Vector2(8, 8)}), 0, 0, 0, g), -PI / 2, 0, 0)
	O3.rot(O3.mesh(Geo.plane(20, 10), Mats.M(0x9c1f2b), 0, 0.02, 2.5, g), -PI / 2, 0, 0)
	var chk := Canvas2D.tex(64, 64, func(c, w, h):
		c.fillStyle = "#f7f7f2"; c.fillRect(0, 0, w, h)
		c.fillStyle = "#161a22"; c.fillRect(0, 0, w / 2.0, h / 2.0); c.fillRect(w / 2.0, h / 2.0, w / 2.0, h / 2.0), true)
	O3.rot(O3.mesh(Geo.plane(24, 2), Mats.M(0xffffff, {"map": chk, "repeat": Vector2(24, 2)}), 0, 0.03, 8.2, g), -PI / 2, 0, 0)
	# backdrop: big banner wall with the title, LED strip and a glowing rim
	var wallT := Canvas2D.tex(2048, 512, func(c, w, h):
		var gr = c.createLinearGradient(0, 0, 0, h)
		gr.addColorStop(0, "#173f82"); gr.addColorStop(1, "#1d4f9e")
		c.fillStyle = gr; c.fillRect(0, 0, w, h)
		c.strokeStyle = "rgba(247,247,242,.12)"; c.lineWidth = 3
		var x := 60
		while x < w:
			c.strokeRect(x, 50, 120, h - 120); x += 180
		c.fillStyle = "#f2c200"; c.fillRect(0, h - 40, w, 40)
		c.fillStyle = "#f7f7f2"; c.fillRect(0, h - 48, w, 8)
		c.fillStyle = "#f7f7f2"; c.font = "italic 800 190px " + FONT; c.textAlign = "center"; c.textBaseline = "middle"
		c.fillText((title if title != "" else "KAMPIOENSCHAP").to_upper(), w / 2.0, h / 2.0 - 30, w - 200))
	_box(44, 10, 0.6, Mats.M(0xffffff, {"map": wallT}), 0, 5, -7.5, g)
	var led := Canvas2D.tex(512, 16, func(c, w, h):
		var x := 0
		while x < w:
			c.fillStyle = "#f2c200" if x % 32 else "#f7f7f2"; c.fillRect(x + 2, 2, 12, h - 4); x += 16, true)
	_box(44, 0.5, 0.7, Mats.M(0xffffff, {"map": led, "repeat": Vector2(6, 1), "emissive": 0xf2c200, "emissiveIntensity": 0.5}), 0, 10.25, -7.5, g, false)
	O3.mesh(Geo.plane(70, 26), Mats.basic(0x2a5fb8, {"transparent": true, "opacity": 0.35, "fog": false}), 0, 12, -9.2, g)
	# sponsor boards on both sides of the banner
	var sign := func(txt: String, bg: String, fg: String) -> LMat:
		return Mats.M(0xffffff, {"map": Canvas2D.tex(512, 128, func(c, w, h):
			c.fillStyle = bg; c.fillRect(0, 0, w, h)
			c.fillStyle = fg; c.font = "italic 800 84px " + FONT; c.textAlign = "center"; c.textBaseline = "middle"
			c.fillText(txt, w / 2.0, h / 2.0 + 4, w - 40))})
	for s in [["TULP OLIE", "#f7f7f2", "#c8302a", -16.5], ["MOLEN BANDEN", "#161a22", "#f2c200", 16.5]]:
		_box(9, 2.2, 0.3, sign.call(s[0], s[1], s[2]), s[3], 3.2, -6.9, g, false)
	# podium steps: a shared plinth, striped blue blocks, gold/silver/bronze tops and a number badge on the front
	_box(17.6, 0.22, 4.6, Mats.M(0x24406f), 0, 0.11, 0.2, g, false); _box(17.8, 0.05, 4.8, Mats.M(0xf2c200), 0, 0.245, 0.2, g, false)
	var sideT := Canvas2D.tex(256, 128, func(c, w, h):
		var gr = c.createLinearGradient(0, 0, 0, h)
		gr.addColorStop(0, "#2a63bd"); gr.addColorStop(1, "#163c7d")
		c.fillStyle = gr; c.fillRect(0, 0, w, h)
		c.fillStyle = "rgba(247,247,242,.08)"
		var x: float = -h
		while x < w:
			c.beginPath(); c.moveTo(x, h); c.lineTo(x + 24, h); c.lineTo(x + 24 + h, 0); c.lineTo(x + h, 0); c.fill(); x += 48, true)
	var MEDAL := ["#f2c200", "#c9ced3", "#c07a3a"]
	var badge := func(n: int) -> LMat:
		return Mats.basic(0xffffff, {"transparent": true, "map": Canvas2D.tex(256, 256, func(c, w, h):
			c.clearRect(0, 0, w, h)
			var i := 14
			var r := 46
			c.beginPath(); c.moveTo(i + r, i); c.lineTo(w - i - r, i); c.quadraticCurveTo(w - i, i, w - i, i + r); c.lineTo(w - i, h - i - r)
			c.quadraticCurveTo(w - i, h - i, w - i - r, h - i); c.lineTo(i + r, h - i); c.quadraticCurveTo(i, h - i, i, h - i - r); c.lineTo(i, i + r)
			c.quadraticCurveTo(i, i, i + r, i); c.closePath()
			c.fillStyle = "#161a22"; c.fill(); c.lineWidth = 16; c.strokeStyle = MEDAL[n - 1]; c.stroke()
			c.fillStyle = "#f7f7f2"; c.font = "900 168px " + UI_FONT; c.textAlign = "center"; c.textBaseline = "middle"
			c.fillText(str(n), w / 2.0, h / 2.0 + 6))})
	var tops := [0xf2c200, 0xc9ced3, 0xc07a3a]
	var white := Mats.M(0xf3f1e8)
	for st in PODIUM_STEPS:
		var x: float = st[0]
		var h: float = st[1]
		var n: int = st[2]
		_box(4.9, h, 3.6, Mats.M(0xffffff, {"map": sideT, "repeat": Vector2(2, h / 1.35)}), x, h / 2 + 0.22, 0, g)
		_box(5.0, 0.1, 3.7, white, x, h + 0.27, 0, g, false)
		_box(4.5, 0.03, 3.2, Mats.phong(tops[n - 1], {"specular": 0xffffff, "shininess": 80}), x, h + 0.335, 0, g, false)
		_box(4.9, 0.05, 0.06, Mats.M(0xffffff, {"emissive": 0xf7f7f2, "emissiveIntensity": 0.8}), x, h + 0.3, 1.83, g, false)
		var bs := minf(1.05, h * 0.78)
		# 2 cm in front of the block (the JS polygonOffset does not work with a log depth buffer either)
		O3.mesh(Geo.plane(bs, bs), badge.call(n), x, 0.22 + h / 2, 1.82, g)
	# flags and a truss with spotlights above the stage
	var flagT := Canvas2D.tex(96, 64, func(c, _w, _h):
		var cols := ["#ae1c28", "#ffffff", "#21468b"]
		for k in 3:
			c.fillStyle = cols[k]; c.fillRect(0, k * 21.3, 96, 21.4))
	for x in [-20, 20]:
		_box(0.14, 11, 0.14, Mats.M(0xd2d5d7), x, 5.5, -3, g)
		O3.mesh(Geo.plane(2.8, 1.8), Mats.M(0xffffff, {"map": flagT, "side": "double"}), x + 1.45, 10, -3, g)
	var truss := Mats.M(0x9aa0a8)
	for x in [-14, 14]: _box(0.3, 11.85, 0.3, truss, x, 5.925, 6, g, false)
	_box(29, 0.3, 0.34, truss, 0, 12, 6, g, false); _box(29, 0.3, 0.3, truss, 0, 11.4, 6.6, g, false)
	var coneM := Mats.basic(0xfff2c0, {"transparent": true, "opacity": 0.16, "depthWrite": false, "fog": false, "side": "double"})
	podiumLights = []
	for x in [-10, -3.5, 3.5, 10]:
		_box(0.5, 0.5, 0.5, Mats.M(0x222222), x, 11.6, 6, g, false)
		var cone := O3.mesh(Geo.cone(2.6, 13, 18, 1, true), coneM, x, 5.4, 3, g)
		O3.rot(cone, 0.25, 0, 0)
		podiumLights.append({"cone": cone, "ph": x * 0.7})
		var sp := SpotLight3D.new()
		sp.light_color = MathX.col(0xfff0d0)
		sp.light_energy = 0.85
		sp.spot_range = 40
		sp.spot_angle = rad_to_deg(0.5)
		sp.spot_angle_attenuation = 0.6
		sp.spot_attenuation = 1.0
		sp.shadow_enabled = false
		g.add_child(sp)
		sp.position = Vector3(x, 11.6, 6)
		sp.look_at_from_position(Vector3(x, 11.6, 6), Vector3(x * 0.5, 1, 0), Vector3.UP)
	# grandstands: a crowd behind the banner wall that rises above it, and angled stands left and right
	var crowdT := Canvas2D.tex(512, 128, func(c, w, h):
		c.fillStyle = "#2b3140"; c.fillRect(0, 0, w, h)
		var cs := ["#f36f21", "#f7f7f2", "#1d4f9e", "#d62a2a", "#f2c200", "#333", "#2f8f5b", "#ffd7b0"]
		for _i in 2200:
			c.fillStyle = cs[int(randf() * cs.size())]; c.fillRect(randf() * w, randf() * h, 3, 5), true)
	var crowd := func(w: float, d: float, rows: int, x: float, z: float, ry: float, parent: Node3D) -> void:
		var s := O3.group(x, 0, z, parent)
		s.rotation.y = ry
		for k in rows:
			_box(w, 1.0, d, Mats.M(0xffffff, {"map": crowdT, "repeat": Vector2(w / 6.0, 1)}), 0, k * 1.0 + 0.5 + k * 0.1, -k * d, s, false)
			_box(w, 0.12, d, Mats.M(0x545a66), 0, k * 1.1 + 1.06, -k * d, s, false)
	crowd.call(46.0, 1.6, 8, 0.0, -9.5, 0.0, g)
	crowd.call(22.0, 1.6, 6, -24.0, 4.0, PI / 2.4, g)
	crowd.call(22.0, 1.6, 6, 24.0, 4.0, -PI / 2.4, g)
	for p in [[-10, -11], [10, -11], [0, -11.5]]:
		_box(0.4, 14, 0.4, Mats.M(0x4a4f5a), p[0], 7, p[1], g, false)
		_box(1.6, 0.7, 0.7, Mats.M(0xffffff, {"emissive": 0xfff0d0, "emissiveIntensity": 1}), p[0], 13.6, p[1] + 0.3, g, false)
	g.visible = false
	_scene().add_child(g)
	podiumRoom = g
	if confetti == null or not is_instance_valid(confetti):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var cm := Mats.basic(0xffffff, {"side": "double"})
		cm.vertex_color_use_as_albedo = true
		mm.mesh = Geo.plane(0.16, 0.11).to_mesh(cm)
		mm.instance_count = 320
		var cols := [0xf2c200, 0xc8302a, 0x1d4f9e, 0xf7f7f2, 0x2f8f5b, 0xf36f21]
		confData = []
		for i in 320:
			confData.append({"x": (randf() - .5) * 30, "y": randf() * 13, "z": (randf() - .5) * 12, "vy": 1.1 + randf() * 1.2, "ph": randf() * 6, "sp": 0.6 + randf()})
			mm.set_instance_color(i, MathX.col(cols[i % cols.size()]))
		confetti = MultiMeshInstance3D.new()
		confetti.multimesh = mm
		confetti.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		confetti.extra_cull_margin = 16384
		_scene().add_child(confetti)
	confetti.position = PPOS
	Canvas2D.flush(_scene())

## a name label over a car: a white (yellow for you) speech balloon with the name and a small line under it
static func nameLabel(name: String, sub: String, me: bool) -> Sprite3D:
	var t := Canvas2D.tex(512, 192, func(c, w, h):
		var r := 40
		c.fillStyle = "#f2c200" if me else "#f7f7f2"
		c.beginPath(); c.moveTo(r, 10); c.lineTo(w - r, 10); c.quadraticCurveTo(w, 10, w, 10 + r); c.lineTo(w, h - 50 - r); c.quadraticCurveTo(w, h - 50, w - r, h - 50)
		c.lineTo(w / 2.0 + 16, h - 50); c.lineTo(w / 2.0, h - 30); c.lineTo(w / 2.0 - 16, h - 50); c.lineTo(r, h - 50); c.quadraticCurveTo(0, h - 50, 0, h - 50 - r)
		c.lineTo(0, 10 + r); c.quadraticCurveTo(0, 10, r, 10); c.fill()
		c.fillStyle = "#161a22"; c.textAlign = "center"; c.textBaseline = "middle"; c.font = "900 %dpx %s" % [54 if sub != "" else 62, UI_FONT]
		c.fillText(name, w / 2.0, 56 if sub != "" else 76, w - 40)
		if sub != "":
			c.font = "700 36px " + UI_FONT; c.fillStyle = "#161a22" if me else "#1d4f9e"; c.fillText(sub, w / 2.0, 108, w - 40))
	var sp := Sprite3D.new()
	sp.texture = t
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.shaded = false
	sp.pixel_size = 4.8 / 512.0
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sp.render_priority = 2
	return sp

## entries: [{name, sub, carId, color, me}] in finishing order; title goes on the banner wall
static func enterPodium(entries: Array, title: String) -> void:
	podiumArgs = {"entries": entries, "title": title}
	buildPodiumRoom(title)
	leavePodiumCars()
	inPodium = true
	podiumT = 0
	podiumRoom.visible = true
	confetti.visible = true
	GarageRoom.stage(0x0b1120, 70, 260, 0xe8ecff, 0x3a3f4a, 0.9, 0xfff3dc, 0.8, Vector3(0.25, 1, 0.8))
	GarageRoom.carLamps(0xfff2c0, 0x6e0b0b)
	for k in mini(3, entries.size()):
		var r: Dictionary = entries[k]
		var col := Color(r.get("color", "#ffffff"))
		var m: Dictionary
		if r.get("me", false):
			var sc = G.settings.color
			G.settings.color = r.color
			m = CarKit.buildCar(r.carId, col)
			CarKit.styleCar(m, r.carId)
			G.settings.color = sc
		else:
			m = CarKit.buildCar(r.carId, col)
		var st: Array = PODIUM_STEPS[k]
		_scene().add_child(m.g)
		m.g.position = Vector3(PPOS.x + st[0], PPOS.y + st[1] + 0.35, PPOS.z + 0.1)
		m.g.rotation = Vector3(0, -0.3 if k == 1 else (0.3 if k == 2 else 0.0), 0)
		if m.get("beam") != null: m.beam.visible = false
		podiumCars.append(m)
		var lb := nameLabel(r.name, r.get("sub", ""), r.get("me", false))
		_scene().add_child(lb)
		lb.position = Vector3(PPOS.x + st[0], PPOS.y + st[1] + 3.15, PPOS.z + 0.1)
		podiumLabels.append(lb)
	Canvas2D.flush(_scene())
	if Game.car != null: Game.car.g.visible = false

static func leavePodiumCars() -> void:
	for m in podiumCars:
		if is_instance_valid(m.g): m.g.queue_free()
	podiumCars = []
	for l in podiumLabels:
		if is_instance_valid(l): l.queue_free()
	podiumLabels = []

static func leavePodium() -> void:
	podiumArgs = null
	if not inPodium: return
	inPodium = false
	leavePodiumCars()
	if podiumRoom != null and is_instance_valid(podiumRoom): podiumRoom.visible = false
	if confetti != null and is_instance_valid(confetti): confetti.visible = false
	World.root.visible = true
	if Env.me != null: Env.me.sky_dome.visible = true
	if Game.car != null: Game.car.g.visible = true
	# the podium view was shifted beside the results board (Menu._setViewOff): a plain camera again
	if Game.camera != null: Game.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	if Env.me != null: Env.me.apply(Env.me.time, Env.me.weather, true)

## podium entries for the rows of a results list (race) or standings (championship)
static func podiumEntries(rows: Array, subOf: Callable) -> Array:
	var out := []
	var champ = Champ.champ
	for k in mini(3, rows.size()):
		var r: Dictionary = rows[k]
		var carId := "gt"
		var color := "#ffffff"
		if r.get("me", false):
			var inChamp: bool = Game.mode == "champ" and champ != null
			carId = champ.car if inChamp else G.settings.car
			color = champ.color if inChamp else G.settings.color
		else:
			var found = null
			for b in Game.bots:
				if b.name == r.name: found = {"type": b.type, "color": b.color}; break
			if found == null and champ != null:
				for b in champ.get("bots", []):
					if b.name == r.name: found = {"type": b.type, "color": b.color}; break
			if found != null:
				carId = found.type; color = found.color
		out.append({"name": r.name, "sub": subOf.call(r), "carId": carId, "color": color, "me": r.get("me", false)})
	return out

## per frame while the podium is shown: confetti, swaying spotlights and the camera
static func podiumUpdate(dt: float, camera: Camera3D) -> void:
	if not inPodium: return
	podiumT += dt
	var mm := confetti.multimesh
	for i in confData.size():
		var c: Dictionary = confData[i]
		c.y -= c.vy * dt
		c.x += sin(podiumT * c.sp * 2 + c.ph) * 0.6 * dt
		if c.y < 0.05:
			c.y = 10 + randf() * 3; c.x = (randf() - .5) * 26; c.z = (randf() - .5) * 10
		mm.set_instance_transform(i, Transform3D(O3.euler(podiumT * c.sp * 3 + c.ph, c.ph, podiumT * c.sp * 2), Vector3(c.x, c.y, c.z)))
	for l in podiumLights:
		l.cone.rotation.z = sin(podiumT * 0.9 + l.ph) * 0.22
	var a := sin(podiumT * 0.16) * 0.45
	var r := 27.0
	camera.position = Vector3(PPOS.x - 2.4 + sin(a) * r, PPOS.y + 5.4 + sin(podiumT * 0.3) * 0.5, PPOS.z + cos(a) * r)
	camera.look_at(Vector3(PPOS.x - 2.4, PPOS.y + 1.8, PPOS.z - 1), Vector3.UP)

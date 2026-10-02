class_name GarageRoom
## The garage room of the HTML game (JS buildGarageRoom, enterGarageScene, leaveGarageScene): a workshop far away from
## the track (GPOS) with its own lighting. The player's car stands in it while the garage panel is open (Menu camera).

const GPOS := Vector3(9000, 0, 9000)
static var garageRoom: Node3D = null
static var inGarage := false

static func _box(w: float, h: float, d: float, mat, x: float, y: float, z: float, g: Node3D) -> MeshInstance3D:
	return World.box(w, h, d, mat, x, y, z, g, false)

static func buildGarageRoom() -> void:
	var g := O3.group(GPOS.x, GPOS.y, GPOS.z)
	g.name = "GarageRoom"
	var floorT := Canvas2D.tex(512, 512, func(c, w, h):
		c.fillStyle = "#5d6166"; c.fillRect(0, 0, w, h)
		for _i in 900:
			c.fillStyle = "rgba(255,255,255,.05)" if randf() < .5 else "rgba(0,0,0,.06)"
			c.fillRect(randf() * w, randf() * h, 3, 3)
		c.strokeStyle = "rgba(0,0,0,.35)"; c.lineWidth = 3
		var i := 0
		while i <= w:
			c.beginPath(); c.moveTo(i, 0); c.lineTo(i, h); c.stroke()
			c.beginPath(); c.moveTo(0, i); c.lineTo(w, i); c.stroke()
			i += 128
		c.fillStyle = "rgba(20,20,20,.18)"; c.beginPath(); c.ellipse(w * 0.62, h * 0.58, 60, 34, 0.4, 0, TAU); c.fill(), true)
	var floor := O3.mesh(Geo.plane(26, 22), Mats.M(0xffffff, {"map": floorT, "repeat": Vector2(2, 2)}), 0, 0, 0, g)
	O3.rot(floor, -PI / 2, 0, 0)
	var hz := Canvas2D.tex(256, 32, func(c, w, h):
		var x: float = -h
		while x < w:
			c.fillStyle = "#f2c200"; c.beginPath(); c.moveTo(x, 0); c.lineTo(x + 16, 0); c.lineTo(x + 16 + h, h); c.lineTo(x + h, h); c.fill()
			c.fillStyle = "#161a22"; c.beginPath(); c.moveTo(x + 16, 0); c.lineTo(x + 32, 0); c.lineTo(x + 32 + h, h); c.lineTo(x + 16 + h, h); c.fill()
			x += 32, true)
	for z in [-4.2, 4.2]:
		var s := O3.mesh(Geo.plane(9, 0.35), Mats.M(0xffffff, {"map": hz, "repeat": Vector2(4, 1)}), 0, 0.01, z, g)
		O3.rot(s, -PI / 2, 0, 0)
	var wallT := Canvas2D.tex(256, 256, func(c, w, h):
		c.fillStyle = "#d9d6ce"; c.fillRect(0, 0, w, h)
		c.fillStyle = "#1d4f9e"; c.fillRect(0, h * 0.72, w, h * 0.28)
		c.fillStyle = "rgba(0,0,0,.06)"
		var y := 0.0
		while y < h * 0.72:
			c.fillRect(0, y, w, 1); y += 16, true)
	var wall := Mats.M(0xffffff, {"map": wallT, "repeat": Vector2(3, 1)})
	_box(26, 8, 0.3, wall, 0, 4, -11, g); _box(0.3, 8, 22, wall, -13, 4, 0, g); _box(0.3, 8, 22, wall, 13, 4, 0, g)
	var doorT := Canvas2D.tex(128, 128, func(c, w, h):
		c.fillStyle = "#a8adb3"; c.fillRect(0, 0, w, h)
		c.fillStyle = "rgba(0,0,0,.25)"
		var y := 0
		while y < h:
			c.fillRect(0, y, w, 2); y += 8)
	_box(26, 8, 0.3, wall, 0, 4, 11, g); _box(12, 5.6, 0.1, Mats.M(0xffffff, {"map": doorT}), 0, 2.8, 10.7, g)
	_box(26, 0.3, 22, Mats.M(0x3a3e45), 0, 8, 0, g)
	for x in [-7, 0, 7]:
		for z in [-5, 5]:
			_box(0.5, 0.12, 4, Mats.M(0xffffff, {"emissive": 0xffffff}), x, 7.8, z, g)
	var sign := Canvas2D.tex(512, 128, func(c, w, h):
		c.fillStyle = "#1d4f9e"; c.fillRect(0, 0, w, h)
		c.strokeStyle = "#f7f7f2"; c.lineWidth = 8; c.strokeRect(10, 10, w - 20, h - 20)
		c.fillStyle = "#f7f7f2"; c.font = 'italic 800 64px "Barlow Condensed"'; c.textAlign = "center"; c.textBaseline = "middle"
		c.fillText("POLDERRACE GARAGE", w / 2.0, h / 2.0 + 4))
	_box(10, 2.5, 0.1, Mats.M(0xffffff, {"map": sign}), 0, 6, -10.7, g)
	var drw := Canvas2D.tex(64, 128, func(c, w, h):
		c.fillStyle = "#c8302a"; c.fillRect(0, 0, w, h)
		c.fillStyle = "rgba(0,0,0,.3)"
		var y := 10
		while y < h:
			c.fillRect(4, y, w - 8, 2); y += 20
		c.fillStyle = "#d9d6ce"
		y = 18
		while y < h:
			c.fillRect(w / 2.0 - 8, y, 16, 3); y += 20)
	for x in [-9, -6.8]: _box(2, 2.4, 1, Mats.M(0xffffff, {"map": drw}), x, 1.2, -10.3, g)
	_box(4.6, 0.12, 1.1, Mats.M(0x7a7f86), -7.9, 2.46, -10.3, g)
	var peg := Canvas2D.tex(256, 128, func(c, w, h):
		c.fillStyle = "#b99a6a"; c.fillRect(0, 0, w, h)
		c.fillStyle = "rgba(0,0,0,.35)"
		var x := 8
		while x < w:
			var y := 8
			while y < h:
				c.fillRect(x, y, 3, 3); y += 16
			x += 16
		c.fillStyle = "#2b2f36"; c.fillRect(30, 20, 10, 70); c.fillRect(24, 20, 22, 10); c.fillRect(80, 30, 60, 8); c.fillRect(160, 20, 8, 80); c.fillRect(190, 40, 40, 10)
		c.fillStyle = "#c8302a"; c.fillRect(100, 70, 30, 30))
	_box(5.2, 2.8, 0.08, Mats.M(0xffffff, {"map": peg}), 7.6, 3.35, -10.76, g); _box(5.2, 0.15, 1.3, Mats.M(0x6b4a2e), 7.6, 1.1, -10.15, g)
	for x in [5.2, 10.0]: _box(0.15, 1.1, 1.1, Mats.M(0x3a3e45), x, 0.55, -10.15, g)
	var tyre := Geo.cylinder(0.42, 0.42, 0.28, 16)
	var tm := Mats.M(0x1b1b1b)
	for t in [[-11.3, -8.8, 5], [-11.3, -7.6, 3], [11.3, 8.8, 4], [-11.3, 8.9, 2]]:
		for k in int(t[2]):
			O3.mesh(tyre, tm, t[0], 0.14 + k * 0.29, t[1], g)
	var drum := Geo.cylinder(0.4, 0.4, 1.1, 14)
	for d in [[11.9, -10.1, 0x1d4f9e], [11.0, -10.2, 0xc8302a], [11.9, -9.1, 0x1d4f9e]]:
		O3.mesh(drum, Mats.M(d[2]), d[0], 0.55, d[1], g)
	for x in [-2.4, 2.4]:
		_box(0.35, 3.6, 0.35, Mats.M(0xf2c200), x, 1.8, -7.5, g); _box(0.9, 0.1, 1.4, Mats.M(0x3a3e45), x, 0.05, -7.5, g)
	_box(1.2, 0.9, 0.7, Mats.M(0x5a5f66), -10.2, 0.45, 5, g)
	var hose := O3.mesh(Geo.torus(0.5, 0.06, 6, 18), Mats.M(0x1b1b1b), -12.8, 3, 5, g)
	O3.rot(hose, 0, PI / 2, 0)
	var flag := Canvas2D.tex(96, 64, func(c, _w, _h):
		var cols := ["#ae1c28", "#ffffff", "#21468b"]
		for k in 3:
			c.fillStyle = cols[k]; c.fillRect(0, k * 21.3, 96, 21.4))
	_box(0.05, 1.3, 2, Mats.M(0xffffff, {"map": flag}), 12.8, 5, -3, g)
	var post := Canvas2D.tex(128, 176, func(c, w, _h):
		c.fillStyle = "#f2c200"; c.fillRect(0, 0, w, 176)
		c.fillStyle = "#161a22"; c.font = '800 26px "Barlow Condensed"'; c.textAlign = "center"
		c.fillText("KAMPIOEN", w / 2.0, 40); c.fillText("SCHAP", w / 2.0, 70)
		c.fillStyle = "#1d4f9e"; c.beginPath(); c.arc(w / 2.0, 125, 30, 0, TAU); c.fill()
		c.fillStyle = "#f7f7f2"; c.font = '800 30px "Barlow Condensed"'; c.fillText("1", w / 2.0, 136))
	_box(0.05, 1.8, 1.3, Mats.M(0xffffff, {"map": post}), 12.8, 4.3, 1, g); _box(0.05, 1.8, 1.3, Mats.M(0xffffff, {"map": post}), -12.8, 4.3, -2, g)
	g.visible = false
	Game.get_tree().current_scene.add_child(g)
	garageRoom = g
	Canvas2D.flush(Game.get_tree().current_scene)

## light a stage scene the three.js way (scene background, fog, hemisphere light, sun) and hide the track's world
static func stage(bg: int, fogNear: float, fogFar: float, hs: int, hg: int, hi: float, sc: int, si: float, dir: Vector3) -> void:
	var e := Env.me
	if e == null: return
	World.root.visible = false
	for c in e.clouds: c.visible = false
	e.stars.visible = false; e.rain.visible = false; e.birds.visible = false
	if e.pools != null: e.pools.visible = false
	e.sky_dome.visible = false; e.sun_sprite.visible = false
	e.environment.background_color = MathX.col(bg)
	var fc := MathX.col(bg)
	RenderingServer.global_shader_parameter_set("pr_fog", Vector4(fc.r, fc.g, fc.b, 0))
	RenderingServer.global_shader_parameter_set("pr_fog_range", Vector4(fogNear, fogFar, 0, 0))
	var d := dir.normalized()
	e.SUN_DIR = d
	e._set_lights(MathX.col(hs), MathX.col(hg), hi, MathX.col(sc), si, d)
	e.sun.look_at_from_position(Vector3.ZERO, -d, Vector3.UP if absf(d.y) < 0.99 else Vector3.FORWARD)

static func carLamps(lamp: int, tail: int) -> void:
	if CarKit.lampMat != null: CarKit.lampMat.emission_enabled = true; CarKit.lampMat.emission = MathX.col(lamp)
	if CarKit.tailMat != null: CarKit.tailMat.emission_enabled = true; CarKit.tailMat.emission = MathX.col(tail)

static func enterGarageScene() -> void:
	if garageRoom == null or not is_instance_valid(garageRoom): buildGarageRoom()
	if inGarage: return
	inGarage = true
	garageRoom.visible = true
	Game.clearBots(); Game.clearTraffic()
	stage(0x1a1d22, 80, 300, 0xffffff, 0x5a5f66, 0.95, 0xffffff, 0.5, Vector3(0.35, 1, 0.55))
	carLamps(0x807860, 0xc81d1d)

static func leaveGarageScene() -> void:
	if not inGarage: return
	inGarage = false
	if garageRoom != null and is_instance_valid(garageRoom): garageRoom.visible = false
	World.root.visible = true
	if Env.me != null:
		Env.me.sky_dome.visible = true
		Env.me.apply(Env.me.time, Env.me.weather, true)

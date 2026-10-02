class_name Env
extends Node3D
## Time of day and weather (JS: SKY, LIGHT, applyEnv, updateEnv): sky dome, sun, ambient ("hemisphere") light, fog,
## clouds, stars, rain, birds and the lamp/window/road material switches. One instance lives in the game scene (Env.me).

static var me: Env

const SKY := {"day": ["#44689a", "#86a5c3", "#cdd0c6", "#dcd6c2"], "dusk": ["#2c3360", "#86587a", "#e8946a", "#f2c28c"], "night": ["#04071a", "#0b1330", "#18213f", "#1f2842"]}
const LIGHT := {
	"day": {"hemi": [0xe2eaf5, 0x5b7440, 0.78], "sun": [0xfff0d4, 0.95], "dir": [-0.55, 1, 0.4], "fog": 0xdcd6c2, "lamp": 0.0, "cloud": [1, 1, 1]},
	"dusk": {"hemi": [0xf0c8b0, 0x3f4250, 0.58], "sun": [0xffa05a, 0.9], "dir": [-0.9, 0.32, 0.25], "fog": 0xe3aa86, "lamp": 0.55, "cloud": [1, 0.78, 0.66]},
	"night": {"hemi": [0x6d7fb8, 0x0e1219, 0.32], "sun": [0xa8b8ff, 0.22], "dir": [0.35, 1, -0.4], "fog": 0x182036, "lamp": 1.0, "cloud": [0.22, 0.25, 0.36]}}
const TIME_NAMES := {"day": "Dag", "dusk": "Avond", "night": "Nacht"}
const WEATHER_NAMES := {"dry": "Droog", "rain": "Regen", "fog": "Mist"}
const SKY_R := 2400.0

var time := "day"
var weather := "dry"
var lamps_on := false
var SUN_DIR := Vector3(-0.55, 1, 0.4).normalized()
var wind_x := 0.0

var world_env: WorldEnvironment
var environment: Environment
var sun: DirectionalLight3D
var sky_dome: MeshInstance3D
var sky_geo: Geo
var sun_sprite: Sprite3D
var clouds: Array = []
var stars: MeshInstance3D
var birds: Node3D
var pools: MultiMeshInstance3D
var _pool_tex: ImageTexture
var rain: MeshInstance3D
var rain_pos := PackedVector3Array()
var fog_color := Color.WHITE
var fog_near := 160.0
var fog_far := 1150.0
var clock := 0.0
const RAIN_N := 1500

func _init() -> void:
	me = self

func _ready() -> void:
	world_env = WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	# lighting and fog are done the three.js way by LMat's shader (global pr_* parameters), not by Godot
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = false
	world_env.environment = environment
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 160.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	# sky dome: vertex-coloured sphere around the camera, horizon haze where the horizon is
	sky_geo = Geo.sphere(SKY_R, 28, 14)
	sky_geo.col.resize(sky_geo.pos.size())
	sky_dome = MeshInstance3D.new()
	sky_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sky_dome)
	sun_sprite = Sprite3D.new()
	sun_sprite.texture = Canvas2D.tex(128, 128, func(g, _w, _h):
		var gr = g.createRadialGradient(64, 64, 2, 64, 64, 64)
		gr.addColorStop(0, "rgba(255,250,235,1)"); gr.addColorStop(0.18, "rgba(255,240,200,0.9)")
		gr.addColorStop(0.5, "rgba(255,220,160,0.25)"); gr.addColorStop(1, "rgba(255,210,150,0)")
		g.fillStyle = gr; g.fillRect(0, 0, 128, 128))
	sun_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sun_sprite.shaded = false
	sun_sprite.no_depth_test = false
	sun_sprite.pixel_size = 420.0 / 128.0
	sun_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sun_sprite.fixed_size = false
	sun_sprite.render_priority = -10
	add_child(sun_sprite)
	_make_clouds()
	_make_stars()
	_make_rain()
	_make_birds()
	_pool_tex = Canvas2D.tex(64, 64, func(g, _w, _h):
		var gr = g.createRadialGradient(32, 32, 1, 32, 32, 31)
		gr.addColorStop(0, "rgba(255,220,150,0.55)"); gr.addColorStop(1, "rgba(255,220,150,0)")
		g.fillStyle = gr; g.fillRect(0, 0, 64, 64))

func _make_clouds() -> void:
	var texs := []
	for _t in 3:
		texs.append(Canvas2D.tex(512, 256, func(g, w, _h):
			var puffs := []
			for _j in 11:
				puffs.append({"x": w / 2.0 + (randf() - .5) * 300, "y": 170 - randf() * 70, "r": 45 + randf() * 50})
			g.save(); g.beginPath(); g.rect(0, 0, w, 200); g.clip()
			g.fillStyle = "rgba(150,162,180,.9)"
			for p in puffs:
				g.beginPath(); g.arc(p.x, p.y + 12, p.r, 0, TAU); g.fill()
			var gr = g.createLinearGradient(0, 40, 0, 200)
			gr.addColorStop(0, "#fffdf6"); gr.addColorStop(0.6, "#f3efe6"); gr.addColorStop(1, "#c3cad6")
			g.fillStyle = gr; g.beginPath()
			for p in puffs:
				g.moveTo(p.x + p.r, p.y); g.arc(p.x, p.y, p.r, 0, TAU)
			g.fill(); g.restore()))
	for k in 34:
		var sp := Sprite3D.new()
		sp.texture = texs[k % 3]
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.shaded = false
		var s := 160.0 + randf() * 220.0
		sp.pixel_size = s / 512.0
		sp.scale = Vector3(1, 1, 1)
		sp.set_meta("a", randf() * TAU)
		sp.set_meta("r", 700.0 + randf() * 900.0)
		sp.set_meta("y", 170.0 + randf() * 170.0)
		sp.render_priority = -5
		clouds.append(sp)
		add_child(sp)

## flocks of little V-shaped birds circling over the track (JS birds)
func _make_birds() -> void:
	birds = Node3D.new()
	add_child(birds)
	var mat := Mats.basic(0x2a2e36)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.9, 0.25, 0), Vector3.ZERO, Vector3.ZERO, Vector3(0.9, 0.25, 0)])
	var bm := ArrayMesh.new()
	bm.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	bm.surface_set_material(0, mat)
	for _f in 4:
		var fl := Node3D.new()
		fl.set_meta("u", {"a": randf() * 6, "r": 120 + randf() * 220, "y": 45 + randf() * 40, "w": (-1.0 if randf() < .5 else 1.0) * (0.05 + randf() * 0.05), "p": randf() * 6, "cx": 0.0, "cz": 0.0})
		for _k in 7 + int(floor(randf() * 6)):
			var b := MeshInstance3D.new()
			b.mesh = bm
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			b.position = Vector3((randf() - .5) * 16, (randf() - .5) * 5, (randf() - .5) * 16)
			b.scale = Vector3.ONE * 1.3
			b.set_meta("p", randf() * 6)
			fl.add_child(b)
		birds.add_child(fl)

func _make_stars() -> void:
	var g := PackedVector3Array()
	for _i in 700:
		var t := randf() * TAU
		var p := randf() * 1.25
		g.append(Vector3(cos(t) * cos(p) * 1500, sin(p) * 1500 + 60, sin(t) * cos(p) * 1500))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = g
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arr)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.use_point_size = true
	mat.point_size = 2.2
	mat.albedo_color = Color(1, 1, 1, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.disable_fog = true
	m.surface_set_material(0, mat)
	stars = MeshInstance3D.new()
	stars.mesh = m
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stars.extra_cull_margin = 16384
	stars.visible = false
	add_child(stars)

func _make_rain() -> void:
	rain_pos.resize(RAIN_N * 2)
	for i in RAIN_N:
		var x := (randf() - .5) * 50; var y := randf() * 26; var z := (randf() - .5) * 50
		rain_pos[i * 2] = Vector3(x, y, z)
		rain_pos[i * 2 + 1] = Vector3(x + 0.05, y - 0.8, z)
	rain = MeshInstance3D.new()
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain.extra_cull_margin = 16384
	rain.visible = false
	_rain_mesh()
	add_child(rain)

func _rain_mesh() -> void:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = rain_pos
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(MathX.col(0xaab6c8), 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.disable_fog = true
	m.surface_set_material(0, mat)
	rain.mesh = m

static func grey(c: Color, k: float) -> Color:
	var g := (c.r + c.g + c.b) / 3.0
	return c.lerp(Color(g, g, g), k)

func _set_sky(cols: Array, ground: Color) -> void:
	var c0 := Canvas2D.css(cols[0]); var c1 := Canvas2D.css(cols[1]); var c2 := Canvas2D.css(cols[2])
	for i in sky_geo.pos.size():
		var y := sky_geo.pos[i].y / SKY_R
		var c: Color
		if y > 0.2: c = c1.lerp(c0, minf(1.0, (y - 0.2) / 0.5))
		elif y > 0.035: c = c2.lerp(c1, (y - 0.035) / 0.165)
		elif y > -0.012: c = ground.lerp(c2, (y + 0.012) / 0.047)
		else: c = ground
		sky_geo.col[i] = c
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.disable_fog = true
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.render_priority = -20
	sky_dome.mesh = sky_geo.to_mesh(mat)

## hand the three.js light set-up to LMat's shader (see lmat.gd): hemisphere, sun, fog, all in gamma space
func _set_lights(hs: Color, hg: Color, hi: float, sc: Color, si: float, l: Vector3) -> void:
	RenderingServer.global_shader_parameter_set("pr_hemi_sky", Vector4(hs.r * hi, hs.g * hi, hs.b * hi, 0))
	RenderingServer.global_shader_parameter_set("pr_hemi_ground", Vector4(hg.r * hi, hg.g * hi, hg.b * hi, 0))
	RenderingServer.global_shader_parameter_set("pr_sun", Vector4(sc.r * si, sc.g * si, sc.b * si, 1.0 if sun.shadow_enabled else 0.0))
	RenderingServer.global_shader_parameter_set("pr_sun_dir", Vector4(l.x, l.y, l.z, 0))
	# the light itself only gives the shadow and the light pass; LMat takes its colour from pr_sun
	sun.light_color = Color.WHITE
	sun.light_energy = 1.0 if si > 0.0 else 0.0

## shadows on/off (quality setting): with shadows the sun gets its own light pass, without them LMat adds it itself
func set_shadows(on: bool) -> void:
	sun.shadow_enabled = on
	var v: Vector4 = RenderingServer.global_shader_parameter_get("pr_sun")
	v.w = 1.0 if on else 0.0
	RenderingServer.global_shader_parameter_set("pr_sun", v)

## JS applyEnv(t, w): time 'day'/'dusk'/'night', weather 'dry'/'rain'/'fog'
func apply(t: String, w: String, force := false) -> void:
	if not LIGHT.has(t): t = "day"
	if not WEATHER_NAMES.has(w): w = "dry"
	if not force and time == t and weather == w and sky_dome.mesh != null:
		return
	time = t
	weather = w
	var L: Dictionary = LIGHT[t]
	var wet := w == "rain"
	var fog := w == "fog"
	var sky: Array = SKY[t].duplicate()
	if wet or fog:
		sky = sky.map(func(c): return "#" + grey(Canvas2D.css(c), 0.55 if wet else 0.7).to_html(false))
	var fogc: Color = grey(MathX.col(L.fog), 0.6) if (wet or fog) else MathX.col(L.fog)
	environment.background_color = Canvas2D.css(sky[3])
	_set_sky(sky, fogc)
	sun_sprite.visible = t != "night" and not fog and not wet
	sun_sprite.modulate = MathX.col(0xffb070 if t == "dusk" else 0xfff4d6)
	sun_sprite.pixel_size = (560.0 if t == "dusk" else 420.0) / 128.0
	var hi: float = L.hemi[2] * (0.85 if wet else 1.0)
	var si: float = L.sun[1] * (0.45 if wet else (0.6 if fog else 1.0))
	_set_lights(MathX.col(L.hemi[0]), MathX.col(L.hemi[1]), hi, MathX.col(L.sun[0]), si, Vector3(L.dir[0], L.dir[1], L.dir[2]).normalized())
	SUN_DIR = Vector3(L.dir[0], L.dir[1], L.dir[2]).normalized()
	sun.look_at_from_position(Vector3.ZERO, -SUN_DIR, Vector3.UP if absf(SUN_DIR.y) < 0.99 else Vector3.FORWARD)
	fog_color = fogc
	RenderingServer.global_shader_parameter_set("pr_fog", Vector4(fogc.r, fogc.g, fogc.b, 0))
	var f0: float = 160.0
	var f1: float = 1150.0
	if not Trk.TRK.is_empty():
		f0 = Trk.TRK.fog[0]; f1 = Trk.TRK.fog[1]
	if fog:
		fog_near = 10.0; fog_far = 140.0 if t == "night" else 190.0
	elif wet:
		fog_near = f0 * 0.4; fog_far = f1 * 0.5
	elif t == "night":
		fog_near = f0 * 0.6; fog_far = f1 * 0.7
	else:
		fog_near = f0; fog_far = f1
	RenderingServer.global_shader_parameter_set("pr_fog_range", Vector4(fog_near, fog_far, 0, 0))
	var cc: Array = L.cloud
	for c in clouds:
		c.modulate = Color(cc[0] * (0.62 if wet else 1.0), cc[1] * (0.64 if wet else 1.0), cc[2] * (0.68 if wet else 1.0))
		c.visible = not fog
	stars.visible = t == "night" and w == "dry"
	rain.visible = wet
	lamps_on = t != "day" or fog or wet
	CarKit.applyEnv(t, lamps_on)   # car lamp glass, tail lights, headlight pools (JS lampMat/tailMat/beamMat)
	for m in World.lampMats:
		if L.lamp > 0.0:
			m.emission_enabled = true
			m.emission = MathX.col(0xffd890) * L.lamp
		else:
			# JS: m.userData.base || 0x222222 (the base is set by TrackLoader after building)
			m.emission = m.get_meta("base_emissive", MathX.col(0x222222))
			m.emission_enabled = true
	for m in World.roadMats:
		var k := 0.7 if wet else 1.0
		m.albedo_color = Color(k, k, k)
	for m in World.winMats:
		var e := 0xffd27a if t == "night" else (0x6a5028 if t == "dusk" else 0)
		m.emission_enabled = e != 0
		m.emission = MathX.col(e)
	for m in World.reflMats:
		m.emission_enabled = lamps_on
		m.emission = MathX.col(0xff7a00)
	for m in World.hillMats:
		var base: Color = m.get_meta("base", m.albedo_color)
		m.albedo_color = base.lerp(fogc, float(m.get_meta("k", 0.0)))
	birds.visible = t != "night" and not fog
	if not Trk.TRK.is_empty():
		for f in birds.get_children():
			var u: Dictionary = f.get_meta("u")
			u.cx = Trk.BX0 + randf() * (Trk.BX1 - Trk.BX0); u.cz = Trk.BZ0 + randf() * (Trk.BZ1 - Trk.BZ0)
	# light pools under the track lamps at dusk and night (JS pools)
	if pools != null:
		pools.queue_free(); pools = null
	if L.lamp > 0.0 and not World.trackLights.is_empty():
		var pg := Geo.plane(1, 1).rotate_x(-PI / 2)
		var pm := Mats.basic(0xffffff, {"map": _pool_tex, "transparent": true, "depthWrite": false, "blending": "add", "opacity": L.lamp})
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = pg.to_mesh(pm)
		mm.instance_count = World.trackLights.size()
		for k in World.trackLights.size():
			var tl: Array = World.trackLights[k]
			mm.set_instance_transform(k, World.mtx(tl[0], tl[1] + 0.14, tl[2], 0, tl[3] * 2, 1, tl[3] * 2))
		pools = MultiMeshInstance3D.new()
		pools.multimesh = mm
		pools.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pools.extra_cull_margin = 16384
		add_child(pools)

## position clouds round the track (JS loadTrack)
func place_clouds() -> void:
	var cx := (Trk.BX0 + Trk.BX1) / 2.0
	var cz := (Trk.BZ0 + Trk.BZ1) / 2.0
	for c in clouds:
		var a: float = c.get_meta("a")
		var r: float = c.get_meta("r")
		c.position = Vector3(cx + cos(a) * r, c.get_meta("y"), cz + sin(a) * r)

## JS updateEnv(dt): rain round the camera, dome/stars/sun follow the camera, beacons blink
func update(dt: float, cam: Camera3D) -> void:
	clock += dt
	if cam == null:
		return
	var cp := cam.global_position
	if rain.visible:
		var fall := 30.0 * dt
		var wx := wind_x * dt
		for i in RAIN_N:
			var p := rain_pos[i * 2]
			var x := p.x + wx; var y := p.y - fall; var z := p.z
			if y < cp.y - 6: y += 26
			if x - cp.x > 25: x -= 50
			elif x - cp.x < -25: x += 50
			if z - cp.z > 25: z -= 50
			elif z - cp.z < -25: z += 50
			if y > cp.y + 20: y -= 26
			rain_pos[i * 2] = Vector3(x, y, z)
			rain_pos[i * 2 + 1] = Vector3(x + 0.05, y - 0.9, z)
		_rain_mesh()
	stars.position = cp
	if birds.visible:
		for f in birds.get_children():
			var u: Dictionary = f.get_meta("u")
			u.a += dt * u.w
			f.position = Vector3(u.cx + cos(u.a) * u.r, u.y + sin(clock * 0.7 + u.p) * 3, u.cz + sin(u.a) * u.r)
			f.rotation.y = -u.a + (0.0 if u.w > 0 else PI)
			for bd in f.get_children():
				bd.scale.y = 0.6 + 0.4 * absf(sin(clock * 9 + bd.get_meta("p")))
	sky_dome.position = cp
	sun_sprite.position = cp + SUN_DIR * SKY_R * 0.8
	if not World.beaconMats.is_empty():
		var on := (Trk.TRK.size() > 0) and (time != "day" or weather == "fog") and sin(clock * 3.2) > 0.2
		for m in World.beaconMats:
			m.emission_enabled = true
			m.emission = MathX.col(0xff2020 if on else 0x220000)

func grip_factor() -> float:
	return 0.85 if weather == "rain" else 1.0

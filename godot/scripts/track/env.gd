class_name Env
extends Node3D
## Time of day and weather: the sky (one shader on a dome: gradient, haze, sun or moon with its glow, drifting clouds,
## stars), the sun and its shadows, the light and fog LMat's shader works with (global pr_* parameters, see lmat.gd),
## rain, birds, the glow and the light pools of the street lamps and the lamp / window / road material switches.
## One instance lives in the game scene (Env.me). JS: SKY, LIGHT, applyEnv, updateEnv.

static var me: Env

## sky colours: overhead, halfway, just above the horizon; the haze below is the fog colour
const SKY := {"day": ["#2f6cc0", "#79aee6", "#cfe0ec"], "dusk": ["#272f5e", "#84577c", "#ee9a68"], "night": ["#03061a", "#0a1230", "#19223f"]}
const LIGHT := {
	"day": {"hemi": [0xe2eaf5, 0x5b7440, 0.78], "sun": [0xfff0d4, 0.95], "dir": [-0.55, 1, 0.4], "fog": 0xd6dfe2, "lamp": 0.0,
		"glow": [0.10, 0.085, 0.05, 5.0], "disc": [1.0, 0.97, 0.86, 1.5], "cloud": [[1.0, 1.0, 0.99], [0.66, 0.72, 0.82]]},
	"dusk": {"hemi": [0xf0c8b0, 0x3f4250, 0.58], "sun": [0xffa05a, 0.9], "dir": [-0.9, 0.32, 0.25], "fog": 0xe3aa86, "lamp": 0.55,
		"glow": [0.30, 0.14, 0.03, 3.0], "disc": [1.0, 0.78, 0.5, 2.3], "cloud": [[1.0, 0.74, 0.56], [0.45, 0.34, 0.48]]},
	"night": {"hemi": [0x6d7fb8, 0x0e1219, 0.42], "sun": [0xa8b8ff, 0.32], "dir": [0.5, 0.6, -0.52], "fog": 0x182036, "lamp": 1.0,
		"glow": [0.035, 0.05, 0.085, 5.0], "disc": [0.93, 0.95, 1.0, 1.4], "cloud": [[0.2, 0.24, 0.36], [0.05, 0.07, 0.13]]}}
const TIME_NAMES := {"day": "Dag", "dusk": "Avond", "night": "Nacht"}
const WEATHER_NAMES := {"dry": "Droog", "rain": "Regen", "fog": "Mist"}
const SKY_R := 2400.0

var time := "day"
var weather := "dry"
var lamps_on := false
var SUN_DIR := Vector3(-0.55, 1, 0.4).normalized()
var wind_x := 0.0
## picture quality (Game.applyPrefs -> set_quality): "low", "mid" or "high"
var quality := "high"

var world_env: WorldEnvironment
var environment: Environment
var sun: DirectionalLight3D
var sky_dome: MeshInstance3D
var sky_mat: ShaderMaterial
var birds: Node3D
var pools: MultiMeshInstance3D
var glows: MultiMeshInstance3D
var _pool_tex: ImageTexture
var rain: MeshInstance3D
var rain_mat: ShaderMaterial
var rain_off := Vector3.ZERO
var fog_color := Color.WHITE
var fog_near := 160.0
var fog_far := 1150.0
var clock := 0.0
## kept for code that hides the environment piece by piece (GarageRoom.stage): the clouds and stars are part of the
## sky dome now and the sun is drawn by its shader
var clouds: Array = []
var stars: Node3D
var sun_sprite: Node3D
const RAIN_N := 2200
const RAIN_BOX := Vector3(46, 26, 46)

func _init() -> void:
	me = self

func _exit_tree() -> void:
	if me == self: me = null

func _ready() -> void:
	world_env = WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	# lighting and fog are done by LMat's shader (global pr_* parameters), not by Godot
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = false
	world_env.environment = environment
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 200.0
	sun.directional_shadow_split_1 = 0.22
	sun.directional_shadow_fade_start = 0.8
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	_make_sky()
	_make_rain()
	_make_birds()
	stars = Node3D.new(); stars.visible = false; add_child(stars)
	sun_sprite = Node3D.new(); sun_sprite.visible = false; add_child(sun_sprite)
	_pool_tex = Canvas2D.tex(64, 64, func(g, _w, _h):
		var gr = g.createRadialGradient(32, 32, 1, 32, 32, 31)
		gr.addColorStop(0, "rgba(255,220,150,0.55)"); gr.addColorStop(1, "rgba(255,220,150,0)")
		g.fillStyle = gr; g.fillRect(0, 0, 64, 64))

# ------------------------------------------------------------------ sky
const SKY_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled, shadows_disabled;
global uniform vec4 pr_sun_dir;
global uniform vec4 pr_glow;
global uniform vec4 pr_fog;
global uniform vec4 pr_wet;
uniform vec3 c_top;
uniform vec3 c_mid;
uniform vec3 c_hor;
uniform vec4 disc = vec4(1.0, 1.0, 1.0, 2.0);     // sun or moon: colour, cos of its radius (2 = none)
uniform float halo = 0.5;                         // glow close round the disc
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D star_tex : filter_nearest, repeat_enable;
uniform float cover = 0.4;                        // clouds: 0 = clear, 1 = overcast
uniform float soft = 0.2;                         // how soft their edge is
uniform vec3 cloud_lit;
uniform vec3 cloud_dark;
uniform vec2 drift = vec2(0.004, 0.0015);
uniform float stars = 0.0;
varying vec3 v_dir;

void vertex() {
	v_dir = VERTEX;
	// a sky box: round every camera (main view, mirror, split screen) and behind everything, whatever its far plane
	// (measured: the Compatibility renderer reverses depth inside OpenGL clip space, so the far plane is z = -w; the others use z = 0)
	vec4 p = PROJECTION_MATRIX * vec4(mat3(VIEW_MATRIX) * VERTEX, 1.0);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	POSITION = vec4(p.xy, -p.w * 0.99999, p.w);
#else
	POSITION = vec4(p.xy, p.w * 0.00001, p.w);
#endif
}

void fragment() {
	vec3 d = normalize(v_dir);
	float y = d.y;
	vec3 c = mix(c_mid, c_top, smoothstep(0.16, 0.8, y));
	c = mix(c_hor, c, smoothstep(0.025, 0.24, y));
	c = mix(pr_fog.rgb, c, smoothstep(-0.012, 0.045, y));
	float sd = max(dot(d, pr_sun_dir.xyz), 0.0);
	// the same sun-side haze the fog on the land gets (lmat.gd), so far things fade into exactly this
	c += pr_glow.rgb * pow(sd, pr_glow.a);
	float dens = 0.0;
	vec3 cc = vec3(0.0);
	if (cover > 0.0 && y > 0.0) {
		// a cloud layer: the dome's direction projected on a flat ceiling, two octaves of drifting noise
		vec2 p = d.xz / (y + 0.09) * 0.105 + drift * TIME;
		float n = texture(noise, p).r;
		if (pr_wet.w > 0.5) n += (texture(noise, p * 3.3 + vec2(0.37, 0.11) + drift * TIME * 1.6).g - 0.5) * 0.3;
		float lo = 1.0 - cover * 0.93;
		dens = smoothstep(lo - soft * 0.5, lo + soft * 0.5, n);
		// light: thicker towards the sun = our side is in the shade
		vec2 ls = normalize(pr_sun_dir.xz + vec2(0.0001)) * 0.03;
		float n2 = texture(noise, p + ls).r;
		float shade = clamp(0.55 + (n - n2) * 4.5 - (n - lo) * 1.1, 0.0, 1.0);
		cc = mix(cloud_dark, cloud_lit, shade);
		cc += pr_glow.rgb * pow(sd, pr_glow.a * 0.5) * 1.5 * (1.0 - dens * 0.5);     // lit rims near the sun
		dens *= smoothstep(0.015, 0.2, y);
	}
	if (stars > 0.0 && y > 0.0) {
		vec2 suv = d.xz / (y + 0.35) * 24.0;
		vec2 cell = floor(suv);
		vec4 rnd = texture(star_tex, (cell + 0.5) / 64.0);
		float dist = length(suv - cell - 0.2 - rnd.xy * 0.6);
		float tw = 0.72 + 0.28 * sin(TIME * (1.2 + rnd.w * 3.0) + rnd.z * 50.0);
		float br = step(0.62, rnd.z) * (0.35 + 0.65 * rnd.w);
		c += vec3(0.88, 0.92, 1.0) * (stars * br * tw * smoothstep(0.075, 0.02, dist) * smoothstep(0.03, 0.3, y));
	}
	if (disc.a < 1.5) {
		c += disc.rgb * (smoothstep(disc.a, disc.a + 0.00012, sd) + halo * (pow(sd, 900.0) * 0.55 + pow(sd, 120.0) * 0.25));
	}
	c = mix(c, cc, dens);
	ALBEDO = c;
}
"""

func _make_sky() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = Shader.new()
	sky_mat.shader.code = SKY_SHADER
	sky_mat.render_priority = -20
	sky_mat.set_shader_parameter("noise", LMat.noise_tex())
	# white noise for the stars: place in the cell, brightness, twinkle
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bytes := PackedByteArray()
	bytes.resize(64 * 64 * 4)
	for i in bytes.size(): bytes[i] = rng.randi() & 255
	sky_mat.set_shader_parameter("star_tex", ImageTexture.create_from_image(Image.create_from_data(64, 64, false, Image.FORMAT_RGBA8, bytes)))
	sky_dome = MeshInstance3D.new()
	sky_dome.mesh = Geo.sphere(SKY_R, 24, 12).to_mesh(sky_mat)
	sky_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky_dome.extra_cull_margin = 16384
	add_child(sky_dome)

# ------------------------------------------------------------------ birds
## flocks of little V-shaped birds circling over the track (JS birds): one line mesh per flock, the wings beat in the shader
const BIRD_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, cull_disabled;
void vertex() {
	// uv.x = this bird's phase, uv.y = 1 at a wing tip
	VERTEX.y *= mix(1.0, 0.6 + 0.4 * abs(sin(TIME * 9.0 + UV.x)), UV.y);
}
void fragment() {
	ALBEDO = vec3(0.165, 0.18, 0.21);
}
"""

func _make_birds() -> void:
	birds = Node3D.new()
	add_child(birds)
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = BIRD_SHADER
	for _f in 4:
		var fl := MeshInstance3D.new()
		fl.set_meta("u", {"a": randf() * 6, "r": 120 + randf() * 220, "y": 45 + randf() * 40, "w": (-1.0 if randf() < .5 else 1.0) * (0.05 + randf() * 0.05), "p": randf() * 6, "cx": 0.0, "cz": 0.0})
		var v := PackedVector3Array()
		var uv := PackedVector2Array()
		for _k in 7 + int(floor(randf() * 6)):
			var o := Vector3((randf() - .5) * 16, (randf() - .5) * 5, (randf() - .5) * 16)
			var ph := randf() * 6
			# a V: two lines from the body to the wing tips (1.3 x the JS bird of 0.9 wide, 0.25 high)
			v.append_array([o + Vector3(-1.17, 0.325, 0), o, o, o + Vector3(1.17, 0.325, 0)])
			uv.append_array([Vector2(ph, 1), Vector2(ph, 0), Vector2(ph, 0), Vector2(ph, 1)])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_TEX_UV] = uv
		var bm := ArrayMesh.new()
		bm.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
		bm.surface_set_material(0, mat)
		fl.mesh = bm
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		birds.add_child(fl)

# ------------------------------------------------------------------ rain
## Rain: streaks as thin quads in a box round the camera, moved in the shader (no work per drop per frame). Each
## streak lies along the way the drop moves past the camera, so at speed the rain comes at you.
const RAIN_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled, skip_vertex_transform;
uniform vec3 box = vec3(46.0, 26.0, 46.0);
uniform vec3 offset = vec3(0.0);        // how far the rain has fallen and blown (wraps in the box)
uniform vec3 streak = vec3(0.0, -0.9, 0.0);   // direction * length of a streak, world space
uniform vec4 tint = vec4(0.75, 0.8, 0.88, 0.5);
varying float v_a;

void vertex() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 p = cam + mod(VERTEX + offset - cam, box) - box * 0.5;
	vec3 to = p - cam;
	float d = length(to);
	vec3 side = normalize(cross(streak, to) + vec3(0.00001));
	float w = 0.008 + d * 0.0011;
	p += streak * UV.y + side * (UV.x * w);
	VERTEX = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	v_a = smoothstep(0.6, 2.5, d) * (1.0 - smoothstep(box.x * 0.36, box.x * 0.5, d)) * (0.55 + 0.45 * COLOR.r);
}

void fragment() {
	ALBEDO = tint.rgb;
	ALPHA = tint.a * v_a * (1.0 - abs(UV.x)) * smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.6, UV.y);
}
"""

func _make_rain() -> void:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	for i in RAIN_N:
		var p := Vector3(randf() * RAIN_BOX.x, randf() * RAIN_BOX.y, randf() * RAIN_BOX.z)
		var c := Color(randf(), 0, 0)
		for k in 4:
			v.append(p)
			col.append(c)
		uv.append_array([Vector2(-1, 0), Vector2(1, 0), Vector2(1, 1), Vector2(-1, 1)])
		idx.append_array([i * 4, i * 4 + 1, i * 4 + 2, i * 4, i * 4 + 2, i * 4 + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	rain_mat = ShaderMaterial.new()
	rain_mat.shader = Shader.new()
	rain_mat.shader.code = RAIN_SHADER
	rain_mat.set_shader_parameter("box", RAIN_BOX)
	m.surface_set_material(0, rain_mat)
	rain = MeshInstance3D.new()
	rain.mesh = m
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain.extra_cull_margin = 16384
	rain.visible = false
	add_child(rain)

# ------------------------------------------------------------------ glow (lamps here, car lights in Fx)
## A glow: a quad that always faces the camera and adds its colour (the "bloom" of a lamp, without a screen pass). One
## MultiMesh per kind: instance origin = where, instance scale = size in metres, instance colour (a = strength).
const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled, skip_vertex_transform;
global uniform vec4 pr_fog_range;
uniform sampler2D tex : filter_linear, repeat_disable;
uniform float far_size = 0.007;    // never smaller than this share of the distance: far lamps stay little dots of light
uniform float nearer = 0.5;        // metres towards the camera, so the lamp itself does not cut the glow in half
uniform float haze = 1.0;          // > 1 in fog: bigger, softer
varying vec4 v_col;

void vertex() {
	vec4 c = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	float d = max(-c.z, 0.01);
	float s = max(length(MODEL_MATRIX[0].xyz), d * far_size) * haze;
	c.xyz -= normalize(c.xyz) * min(nearer, d * 0.5);
	c.xy += VERTEX.xy * s;
	VERTEX = c.xyz;
	float f = smoothstep(pr_fog_range.x, pr_fog_range.y, d);
	v_col = COLOR;
	v_col.a *= 1.0 - f * 0.9;
}

void fragment() {
	ALBEDO = v_col.rgb;
	ALPHA = texture(tex, UV).r * v_col.a;
}
"""
static var _glow_tex: ImageTexture
static var _glow_mesh: ArrayMesh

## the glow texture: a bright core with a wide soft halo
static func glow_tex() -> ImageTexture:
	if _glow_tex == null:
		var S := 64
		var img := Image.create(S, S, false, Image.FORMAT_R8)
		for y in S:
			for x in S:
				var r := Vector2(x + 0.5 - S / 2.0, y + 0.5 - S / 2.0).length() / (S / 2.0)
				var v := clampf(1.0 - r, 0.0, 1.0)
				img.set_pixel(x, y, Color(minf(1.0, v * v * 0.55 + pow(v, 6.0) * 0.9), 0, 0))
		_glow_tex = ImageTexture.create_from_image(img)
	return _glow_tex

## a MultiMesh of n glows (use set_instance_transform with a uniform scale = size, set_instance_color)
static func glow_multimesh(n: int, far_size := 0.007, nearer := 0.5) -> MultiMeshInstance3D:
	if _glow_mesh == null:
		_glow_mesh = Geo.plane(1, 1).to_mesh(null)
	var mat := ShaderMaterial.new()
	mat.shader = _glow_shader()
	mat.set_shader_parameter("tex", glow_tex())
	mat.set_shader_parameter("far_size", far_size)
	mat.set_shader_parameter("nearer", nearer)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _glow_mesh
	mm.instance_count = n
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 16384
	return mmi

static var _glow_sh: Shader
static func _glow_shader() -> Shader:
	if _glow_sh == null:
		_glow_sh = Shader.new()
		_glow_sh.code = GLOW_SHADER
	return _glow_sh

## where the lamps of the track are: the middle of every mesh (or instance) whose material is one of World.lampMats;
## [position, size of the lamp]
func _lamp_points() -> Array:
	var pts := []
	if World.root == null or World.lampMats.is_empty(): return pts
	var lamp := {}
	for m in World.lampMats: lamp[m] = true
	for n in World.root.find_children("*", "GeometryInstance3D", true, false):
		if n is MultiMeshInstance3D:
			var mm: MultiMesh = n.multimesh
			if mm == null or mm.mesh == null or mm.mesh.get_surface_count() == 0: continue
			if not lamp.has(mm.mesh.surface_get_material(0)): continue
			var bb: AABB = mm.mesh.get_aabb()
			var xf: Transform3D = n.global_transform
			for i in mm.instance_count:
				var t: Transform3D = xf * mm.get_instance_transform(i)
				pts.append([t * bb.get_center(), (t.basis * bb.size).length()])
		elif n is MeshInstance3D and n.mesh != null and n.mesh.get_surface_count() == 1:
			if not lamp.has(n.get_active_material(0)): continue
			var bb2: AABB = n.mesh.get_aabb()
			pts.append([n.global_transform * bb2.get_center(), (n.global_transform.basis * bb2.size).length()])
	return pts

static func grey(c: Color, k: float) -> Color:
	var g := (c.r + c.g + c.b) / 3.0
	return c.lerp(Color(g, g, g), k)

static func _v3(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)

static func _gset(name: String, v: Vector4) -> void:
	RenderingServer.global_shader_parameter_set(name, v)

## hand the light set-up to LMat's shader (see lmat.gd): hemisphere, sun, all in gamma space. Also used by the stage
## scenes (garage, podium: GarageRoom.stage), so everything the weather adds is switched off here; apply() sets it after.
func _set_lights(hs: Color, hg: Color, hi: float, sc: Color, si: float, l: Vector3) -> void:
	_gset("pr_hemi_sky", Vector4(hs.r * hi, hs.g * hi, hs.b * hi, 0))
	_gset("pr_hemi_ground", Vector4(hg.r * hi, hg.g * hi, hg.b * hi, 0))
	_sun_param = Vector4(sc.r * si, sc.g * si, sc.b * si, 1.0 if sun.shadow_enabled else 0.0)
	_gset("pr_sun", _sun_param)
	_gset("pr_sun_dir", Vector4(l.x, l.y, l.z, 0))
	_gset("pr_glow", Vector4(0, 0, 0, 6))
	_gset("pr_sky", Vector4(hs.r * hi, hs.g * hi, hs.b * hi, 0))
	_wet_param = Vector4(0, 0, 0, _wet_param.w)
	_gset("pr_wet", _wet_param)
	if glows != null: glows.visible = false
	if Fx.me != null: Fx.me.stage()
	# the light itself only gives the shadow and the light pass; LMat takes its colour from pr_sun
	sun.light_color = Color.WHITE
	sun.light_energy = 1.0 if si > 0.0 else 0.0

## shadows on/off (quality setting): with shadows the sun gets its own light pass, without them LMat adds it itself
## (global_shader_parameter_get only works in the editor, so the last values are kept here)
var _sun_param := Vector4(0.95, 0.894, 0.789, 1)
var _wet_param := Vector4(0, 0, 0, 2)

func set_shadows(on: bool) -> void:
	sun.shadow_enabled = on
	_sun_param.w = 1.0 if on else 0.0
	_gset("pr_sun", _sun_param)

## picture quality: "low" no shadows, simpler sky; "mid" shadows with a soft edge, 150 m; "high" softer, 220 m, blended
func set_quality(q: String) -> void:
	quality = q
	set_shadows(q != "low")
	RenderingServer.directional_shadow_atlas_set_size(4096 if q == "high" else 2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if q == "high" else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	sun.directional_shadow_max_distance = 220.0 if q == "high" else 150.0
	sun.directional_shadow_blend_splits = q == "high"
	_wet_param.w = 0.0 if q == "low" else (1.0 if q == "mid" else 2.0)
	_gset("pr_wet", _wet_param)

## JS applyEnv(t, w): time 'day'/'dusk'/'night', weather 'dry'/'rain'/'fog'
func apply(t: String, w: String, force := false) -> void:
	if not LIGHT.has(t): t = "day"
	if not WEATHER_NAMES.has(w): w = "dry"
	if not force and time == t and weather == w and _applied:
		return
	_applied = true
	time = t
	weather = w
	var L: Dictionary = LIGHT[t]
	var wet := w == "rain"
	var fog := w == "fog"
	var dull := 0.6 if wet else (0.75 if fog else 0.0)
	var sky: Array = SKY[t].map(func(c): return grey(Canvas2D.css(c), dull))
	var fogc: Color = grey(MathX.col(L.fog), 0.6) if (wet or fog) else MathX.col(L.fog)
	if fog:
		# in fog the whole sky is the fog
		sky = sky.map(func(c): return c.lerp(fogc, 0.7))
	environment.background_color = fogc
	var hi: float = L.hemi[2] * (0.85 if wet else 1.0)
	var si: float = L.sun[1] * (0.45 if wet else (0.6 if fog else 1.0))
	SUN_DIR = Vector3(L.dir[0], L.dir[1], L.dir[2]).normalized()
	_set_lights(MathX.col(L.hemi[0]), MathX.col(L.hemi[1]), hi, MathX.col(L.sun[0]), si, SUN_DIR)
	sun.look_at_from_position(Vector3.ZERO, -SUN_DIR, Vector3.UP if absf(SUN_DIR.y) < 0.99 else Vector3.FORWARD)
	fog_color = fogc
	_gset("pr_fog", Vector4(fogc.r, fogc.g, fogc.b, 0))
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
	_gset("pr_fog_range", Vector4(fog_near, fog_far, 0, 0))
	lamps_on = t != "day" or fog or wet
	# what the weather adds for LMat: haze on the sun's side, the sky to mirror, wet roads, wind
	var gl: Array = L.glow
	var gk := 0.3 if (wet or fog) else 1.0
	_gset("pr_glow", Vector4(gl[0] * gk, gl[1] * gk, gl[2] * gk, gl[3]))
	var over: Color = (sky[0] as Color).lerp(sky[1], 0.45)
	_gset("pr_sky", Vector4(over.r, over.g, over.b, 0))
	_wet_param = Vector4(1.0 if wet else 0.0, 1.0 if wet else 0.0, 1.0 if lamps_on else 0.0, _wet_param.w)
	_gset("pr_wet", _wet_param)
	var wk := 1.9 if wet else (0.45 if fog else 1.0)
	_gset("pr_wind", Vector4(0.95 * wk, 0.3 * wk, 1.25 if wet else 1.0, 0))
	# the sky dome
	sky_dome.visible = true
	sky_mat.set_shader_parameter("c_top", _v3(sky[0]))
	sky_mat.set_shader_parameter("c_mid", _v3(sky[1]))
	sky_mat.set_shader_parameter("c_hor", _v3(sky[2]))
	var dc: Array = L.disc
	var clear := not wet and not fog
	sky_mat.set_shader_parameter("disc", Vector4(dc[0], dc[1], dc[2], cos(deg_to_rad(dc[3])) if clear else 2.0))
	sky_mat.set_shader_parameter("halo", 0.35 if t == "night" else (0.8 if t == "dusk" else 0.6))
	var lit := Color(L.cloud[0][0], L.cloud[0][1], L.cloud[0][2])
	var dark := Color(L.cloud[1][0], L.cloud[1][1], L.cloud[1][2])
	if wet:
		lit = grey(lit, 0.8) * 0.68; dark = grey(dark, 0.7) * 0.78
	sky_mat.set_shader_parameter("cloud_lit", _v3(lit))
	sky_mat.set_shader_parameter("cloud_dark", _v3(dark))
	sky_mat.set_shader_parameter("cover", 0.0 if fog else (1.0 if wet else 0.42))
	sky_mat.set_shader_parameter("soft", 0.5 if wet else 0.16)
	sky_mat.set_shader_parameter("drift", Vector2(0.0075, 0.0028) if wet else Vector2(0.0032, 0.0012))
	sky_mat.set_shader_parameter("stars", 1.0 if (t == "night" and w == "dry") else 0.0)
	rain.visible = wet
	rain_mat.set_shader_parameter("tint", Vector4(0.3, 0.34, 0.44, 0.55) if t == "night" else (Vector4(0.62, 0.6, 0.62, 0.5) if t == "dusk" else Vector4(0.78, 0.82, 0.88, 0.5)))
	CarKit.applyEnv(t, lamps_on)   # car lamp glass, tail lights, headlight pools (JS lampMat/tailMat/beamMat)
	if Fx.me != null: Fx.me.applyEnv(t, lamps_on)   # the player's headlights and the glow of the car lights
	for m in World.lampMats:
		if L.lamp > 0.0:
			m.emission_enabled = true
			m.emission = MathX.col(0xffd890) * L.lamp
		else:
			# JS: m.userData.base || 0x222222 (the base is set by TrackLoader after building)
			m.emission = m.get_meta("base_emissive", MathX.col(0x222222))
			m.emission_enabled = true
	for m in World.roadMats:
		# a wet road: LMat's shader darkens it and makes it shine (variant "wet")
		m.albedo_color = Color.WHITE
		m.wet = wet
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
	_lamps(L.lamp, wet, fog)

var _applied := false

## the street lamps at dusk and night: a pool of light on the ground under each (JS pools; World.trackLights) and a
## glow round each lamp head (found through World.lampMats)
func _lamps(lamp: float, wet: bool, fog: bool) -> void:
	if pools != null:
		pools.queue_free(); pools = null
	if glows != null:
		glows.queue_free(); glows = null
	if lamp <= 0.0: return
	if not World.trackLights.is_empty():
		var pg := Geo.plane(1, 1).rotate_x(-PI / 2)
		var pm := Mats.basic(0xffffff, {"map": _pool_tex, "transparent": true, "depthWrite": false, "blending": "add", "opacity": lamp * (1.25 if wet else 1.0)})
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
	var pts := _lamp_points()
	if pts.is_empty(): return
	glows = glow_multimesh(pts.size(), 0.0075, 0.6)
	glows.material_override.set_shader_parameter("haze", 2.2 if fog else (1.4 if wet else 1.0))
	var col := Color(1.0, 0.82, 0.5, (0.5 if fog else 0.75) * lamp)
	for k in pts.size():
		var s: float = clampf(pts[k][1] * 2.6, 1.8, 6.0)
		glows.multimesh.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3.ONE * s), pts[k][0]))
		glows.multimesh.set_instance_color(k, col)
	add_child(glows)

## (the clouds were sprites placed round the track; they are part of the sky now)
func place_clouds() -> void:
	pass

var _cam_prev := Vector3.ZERO
var _cam_vel := Vector3.ZERO

## JS updateEnv(dt): rain round the camera, the dome follows the camera, birds circle, beacons blink
func update(dt: float, cam: Camera3D) -> void:
	clock += dt
	if cam == null:
		return
	var cp := cam.global_position
	if rain.visible:
		if dt > 0.0:
			var v := (cp - _cam_prev) / dt
			# a jump (reset, another camera) is not speed
			_cam_vel = _cam_vel.lerp(v if v.length() < 120.0 else Vector3.ZERO, minf(1.0, dt * 6.0))
		var fall := Vector3(wind_x * 0.6 + 2.0, -30.0, 0.8)
		rain_off += fall * dt
		rain_off = Vector3(fposmod(rain_off.x, RAIN_BOX.x), fposmod(rain_off.y, RAIN_BOX.y), fposmod(rain_off.z, RAIN_BOX.z))
		rain_mat.set_shader_parameter("offset", rain_off)
		rain_mat.set_shader_parameter("streak", (fall - _cam_vel * 0.55) * -0.03)
	_cam_prev = cp
	if birds.visible:
		for f in birds.get_children():
			var u: Dictionary = f.get_meta("u")
			u.a += dt * u.w
			f.position = Vector3(u.cx + cos(u.a) * u.r, u.y + sin(clock * 0.7 + u.p) * 3, u.cz + sin(u.a) * u.r)
			f.rotation.y = -u.a + (0.0 if u.w > 0 else PI)
	sky_dome.position = cp
	if not World.beaconMats.is_empty():
		var on := (Trk.TRK.size() > 0) and (time != "day" or weather == "fog") and sin(clock * 3.2) > 0.2
		for m in World.beaconMats:
			m.emission_enabled = true
			m.emission = MathX.col(0xff2020 if on else 0x220000)

func grip_factor() -> float:
	return 0.85 if weather == "rain" else 1.0

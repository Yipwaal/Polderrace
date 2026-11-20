class_name LMat
extends ShaderMaterial
## The game's material: one shader for every surface (Mats.M / PM / phong / basic / water). It started as the HTML game's
## three.js r128 Lambert / Phong / Basic materials and still lights the three.js way: in gamma space,
## colour * (hemisphere + sun * N.L) + emissive, then fog. On top of that (phase 2, "Beeld"): per-pixel light, the
## player's headlights, a sun-side glow in the haze, water, wet roads in the rain, sky reflection on glossy things and
## wind sway. Light and weather come from global shader parameters set by Env (pr_*), not from Godot's ambient or fog.
##
## How the Compatibility renderer is used (measured with tools/calib_shader.gd and tools/exp_beeld.gd):
##   - an unshaded shader's ALBEDO goes to the screen as it is; a shaded one's EMISSION too, and every light with
##     shadows is drawn in an extra pass that adds enc(SPECULAR_LIGHT) on top (blended in gamma space).
##   - So surfaces that take NO shadows (three.js: receiveShadow false - buildings, trees, cars, ...) are unshaded: the
##     shader adds hemisphere, sun, headlights and fog itself and the mesh is drawn once.
##   - Surfaces that DO take shadows (O3.receive / receiveShadow: ground, road, water) or ask for Godot's lights
##     (use_lights: the podium under its spot lights) are shaded ("LIT"): base pass EMISSION = everything but the sun,
##     and the sun comes in its own pass with the shadow: SPECULAR_LIGHT = dec((1 - fog) * colour * sun * N.L * shadow).
##     Without sun shadows (quality "laag", pr_sun.w = 0) the base pass adds the sun and there is no second pass.
##
## Global shader parameters (project.godot [shader_globals], set by Env; all colours in gamma space). Other shaders
## (the car paint in scripts/car/car_paint.gd) may read them; names and meaning are stable:
##   pr_hemi_sky.rgb, pr_hemi_ground.rgb   hemisphere light from above / below, times its intensity
##   pr_sun.rgb     sun (at night: moon) colour times intensity
##   pr_sun.w       1 = the sun has shadows and comes in its own light pass FOR SHADED SHADERS (their fragment() must
##                  then leave the sun out and light() adds it); 0 = add the sun in fragment(). Unshaded shaders
##                  always add the sun themselves and ignore w.
##   pr_sun_dir.xyz towards the sun, world space, unit length
##   pr_fog.rgb     fog / haze colour (also the sky's colour at the horizon)
##   pr_fog_range   x = near, y = far: fog = smoothstep(near, far, view depth)
##   pr_glow.rgb    haze colour added on the sun's side: fog colour = pr_fog + pr_glow * pow(max(dot(view ray, sun), 0), pr_glow.a)
##   pr_sky.rgb     the sky's colour overhead: what water, wet roads and gloss mirror (towards the horizon: pr_fog)
##   pr_wet         x = wet roads 0..1, y = rain 0..1 (drops on water and road), z = lamps on 0..1 (dusk, night, rain, fog),
##                  w = picture quality 0 laag, 1 middel, 2 hoog
##   pr_wind        xy = wind direction * strength in world xz (1 = a breeze), z = speed of the sway
##   pr_head0, pr_head0_dir   player 1's headlights: xyz = world position, w = brightness (0 = off); xyz = direction,
##   pr_head1, pr_head1_dir   w = range in m. Player 2's (split screen) in pr_head1.
##
## Shadows: like three.js only what asks for it receives shadows (three mesh.receiveShadow = true -> O3.receive(mesh), which
## sets receive_shadow on its materials); everything else is lit by the sun without shadows (no self-shadowing on boxes, ...).
##
## The properties carry StandardMaterial3D's names (albedo_color, albedo_texture, emission, transparency, cull_mode, ...),
## so code can treat an LMat like a StandardMaterial3D. Flags that change the shader code rebuild it (cached per variant).

enum Kind { LAMBERT, PHONG, BASIC, WATER }

var kind := Kind.LAMBERT: set = _set_kind
var albedo_color := Color.WHITE: set = _set_albedo_color
var albedo_texture: Texture2D: set = _set_albedo_texture
var uv1_scale := Vector3.ONE: set = _set_uv1_scale
var uv1_offset := Vector3.ZERO: set = _set_uv1_offset
var emission_enabled := false: set = _set_emission_enabled
var emission := Color.BLACK: set = _set_emission
var emission_energy_multiplier := 1.0: set = _set_emission_energy
## three emissiveMap: multiplies the emissive colour (same uv as the map)
var emission_texture: Texture2D: set = _set_emission_texture
var specular := Color(0.0666, 0.0666, 0.0666): set = _set_specular
var shininess := 30.0: set = _set_shininess
var transparency := BaseMaterial3D.TRANSPARENCY_DISABLED: set = _set_transparency
var alpha_scissor_threshold := 0.5: set = _set_alpha_scissor
var cull_mode := BaseMaterial3D.CULL_BACK: set = _set_cull_mode
var blend_mode := BaseMaterial3D.BLEND_MODE_MIX: set = _set_blend_mode
var depth_draw_mode := BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY: set = _set_depth_draw
var no_depth_test := false: set = _set_no_depth_test
var disable_fog := false: set = _set_disable_fog
var vertex_color_use_as_albedo := false: set = _set_vcol
var flat_shading := false: set = _set_flat
## three mesh.receiveShadow (per material here, see O3.receive): shadows fall on it (a shaded shader with a sun pass)
var receive_shadow := false: set = _set_receive
## lit by Godot's own lights too (spot and omni lights: the podium's spots, lights under a car) without taking shadows
var use_lights := false: set = _set_use_lights
## a road in the rain (Env switches this on World.roadMats): darker, glossy, mirrors the sky, drops
var wet := false: set = _set_wet
## wind sway (Mats option "sway"): the top of the mesh moves this many metres in a breeze; 0 = off. The part of the
## mesh below model height sway_base stands still, from there the movement grows over sway_span (model units).
var sway := 0.0: set = _set_sway
var sway_base := -0.5: set = _set_sway_base
var sway_span := 1.0: set = _set_sway_span
## kept for code written against StandardMaterial3D; the shader ignores them
var vertex_color_is_srgb := false
var texture_filter := BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
var texture_repeat := true

var _building := false
static var _cache := {}
static var _noise: ImageTexture

func _init() -> void:
	_rebuild()

func clone() -> LMat:
	var m := LMat.new()
	m._building = true
	for p in ["kind", "albedo_color", "albedo_texture", "uv1_scale", "uv1_offset", "emission_enabled", "emission", "emission_energy_multiplier", "emission_texture",
			"specular", "shininess", "transparency", "alpha_scissor_threshold", "cull_mode", "blend_mode", "depth_draw_mode", "no_depth_test", "disable_fog",
			"vertex_color_use_as_albedo", "flat_shading", "receive_shadow", "use_lights", "wet", "sway", "sway_base", "sway_span"]:
		m.set(p, get(p))
	m._building = false
	m.render_priority = render_priority
	m._rebuild()
	for k in get_meta_list():
		m.set_meta(k, get_meta(k))
	return m

func _set_kind(v): kind = v; _rebuild()
func _set_albedo_color(v): albedo_color = v; set_shader_parameter("albedo", Vector4(v.r, v.g, v.b, v.a))
func _set_albedo_texture(v): albedo_texture = v; _rebuild()
func _set_uv1_scale(v): uv1_scale = v; set_shader_parameter("uv_scale", Vector2(v.x, v.y))
func _set_uv1_offset(v): uv1_offset = v; set_shader_parameter("uv_offset", Vector2(v.x, v.y))
func _set_emission_enabled(v): emission_enabled = v; _push_emission()
func _set_emission(v): emission = v; _push_emission()
func _set_emission_energy(v): emission_energy_multiplier = v; _push_emission()
func _set_emission_texture(v): emission_texture = v; _rebuild()
func _set_specular(v): specular = v; set_shader_parameter("spec", Vector3(v.r, v.g, v.b))
func _set_shininess(v): shininess = v; set_shader_parameter("shininess", v)
func _set_transparency(v): transparency = v; _rebuild()
func _set_alpha_scissor(v): alpha_scissor_threshold = v; set_shader_parameter("alpha_cut", v)
func _set_cull_mode(v): cull_mode = v; _rebuild()
func _set_blend_mode(v): blend_mode = v; _rebuild()
func _set_depth_draw(v): depth_draw_mode = v; _rebuild()
func _set_no_depth_test(v): no_depth_test = v; _rebuild()
func _set_disable_fog(v): disable_fog = v; _rebuild()
func _set_vcol(v): vertex_color_use_as_albedo = v; _rebuild()
func _set_flat(v): flat_shading = v; _rebuild()
func _set_receive(v): receive_shadow = v; _rebuild()
func _set_use_lights(v): use_lights = v; _rebuild()
func _set_wet(v):
	if wet != v: wet = v; _rebuild()
func _set_sway(v):
	var was := sway > 0.0
	sway = v
	if was != (v > 0.0): _rebuild()
	else: _push_sway()
func _set_sway_base(v): sway_base = v; _push_sway()
func _set_sway_span(v): sway_span = v; _push_sway()

func _push_emission() -> void:
	var e := emission * emission_energy_multiplier if emission_enabled else Color.BLACK
	set_shader_parameter("emissive", Vector3(e.r, e.g, e.b))

func _push_sway() -> void:
	if sway > 0.0: set_shader_parameter("sway", Vector3(sway, sway_base, maxf(sway_span, 0.001)))

## shaded (Godot's lights and shadows reach it, one more pass per shadowed light) or unshaded (drawn once)
func is_lit() -> bool:
	return kind != Kind.BASIC and (receive_shadow or use_lights)

func _rebuild() -> void:
	if _building:
		return
	var key := "%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d" % [kind, transparency, blend_mode, cull_mode, depth_draw_mode, int(no_depth_test), int(disable_fog),
		int(vertex_color_use_as_albedo), int(flat_shading), int(albedo_texture != null), int(emission_texture != null), int(receive_shadow), int(use_lights), int(wet), int(sway > 0.0)]
	if not _cache.has(key):
		var sh := Shader.new()
		sh.code = _code()
		_cache[key] = sh
	shader = _cache[key]
	set_shader_parameter("albedo", Vector4(albedo_color.r, albedo_color.g, albedo_color.b, albedo_color.a))
	set_shader_parameter("tex", albedo_texture)
	set_shader_parameter("emap", emission_texture)
	set_shader_parameter("uv_scale", Vector2(uv1_scale.x, uv1_scale.y))
	set_shader_parameter("uv_offset", Vector2(uv1_offset.x, uv1_offset.y))
	set_shader_parameter("spec", Vector3(specular.r, specular.g, specular.b))
	set_shader_parameter("shininess", shininess)
	set_shader_parameter("alpha_cut", alpha_scissor_threshold)
	set_shader_parameter("noise", noise_tex() if (kind == Kind.WATER or wet) else null)
	_push_emission()
	_push_sway()

func _code() -> String:
	var rm := []
	if blend_mode == BaseMaterial3D.BLEND_MODE_ADD:
		rm.append("blend_add")
	elif transparency == BaseMaterial3D.TRANSPARENCY_ALPHA or transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
		rm.append("blend_mix")
	match cull_mode:
		BaseMaterial3D.CULL_DISABLED: rm.append("cull_disabled")
		BaseMaterial3D.CULL_FRONT: rm.append("cull_front")
		_: rm.append("cull_back")
	match depth_draw_mode:
		BaseMaterial3D.DEPTH_DRAW_DISABLED: rm.append("depth_draw_never")
		BaseMaterial3D.DEPTH_DRAW_ALWAYS: rm.append("depth_draw_always")
		_: rm.append("depth_draw_opaque")
	if no_depth_test: rm.append("depth_test_disabled")
	rm.append("fog_disabled")
	rm.append("ambient_light_disabled")
	var lit := is_lit()
	if not lit: rm.append("unshaded")
	if not receive_shadow: rm.append("shadows_disabled")
	var d := []
	if albedo_texture != null: d.append("#define TEX")
	if emission_texture != null: d.append("#define EMAP")
	if vertex_color_use_as_albedo: d.append("#define VCOL")
	if transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR: d.append("#define SCISSOR")
	if transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or blend_mode == BaseMaterial3D.BLEND_MODE_ADD: d.append("#define ALPHA_ON")
	if not disable_fog: d.append("#define FOG")
	if kind == Kind.PHONG: d.append("#define PHONG")
	if kind == Kind.BASIC: d.append("#define BASIC")
	if kind == Kind.WATER: d.append("#define WATER")
	if flat_shading: d.append("#define FLAT")
	if lit: d.append("#define LIT")
	if wet and kind != Kind.BASIC and kind != Kind.WATER: d.append("#define WET")
	if sway > 0.0: d.append("#define SWAY")
	return "shader_type spatial;\nrender_mode %s;\n%s\n%s" % [", ".join(rm), "\n".join(d), SHADER_BODY]

## One tiling 256 x 256 noise texture for the whole picture (clouds, water, wet roads):
##   r, g = two cloudy fbm fields (0..1), b, a = the slope (normal xy, 0.5 = flat) of a field of ripples
static func noise_tex() -> ImageTexture:
	if _noise != null: return _noise
	var S := 256
	var fields := []
	for spec in [[1.0 / 96, 4, 11], [1.0 / 64, 4, 23], [1.0 / 40, 3, 37]]:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.frequency = spec[0]
		n.fractal_octaves = spec[1]
		n.seed = spec[2]
		fields.append(n.get_seamless_image(S, S, false, false, 0.3, true).get_data())
	var a: PackedByteArray = fields[0]
	var b: PackedByteArray = fields[1]
	var h: PackedByteArray = fields[2]
	var out := PackedByteArray()
	out.resize(S * S * 4)
	for y in S:
		var yu := ((y + S - 1) % S) * S
		var yd := ((y + 1) % S) * S
		var y0 := y * S
		for x in S:
			var xl := (x + S - 1) % S
			var xr := (x + 1) % S
			var o := (y0 + x) * 4
			out[o] = a[y0 + x]
			out[o + 1] = b[y0 + x]
			out[o + 2] = clampi(128 + (h[y0 + xr] - h[y0 + xl]) * 4, 0, 255)
			out[o + 3] = clampi(128 + (h[yd + x] - h[yu + x]) * 4, 0, 255)
	var img := Image.create_from_data(S, S, false, Image.FORMAT_RGBA8, out)
	img.generate_mipmaps()
	_noise = ImageTexture.create_from_image(img)
	return _noise

const SHADER_BODY := """
global uniform vec4 pr_hemi_sky;      // hemisphere light from above: colour * intensity (gamma)
global uniform vec4 pr_hemi_ground;
global uniform vec4 pr_sun;           // sun colour * intensity (gamma); w = 1 when the sun has shadows (own light pass, shaded shaders)
global uniform vec4 pr_sun_dir;       // towards the sun, world space
global uniform vec4 pr_fog;           // fog colour (gamma)
global uniform vec4 pr_fog_range;     // near, far: smoothstep(near, far, depth)
global uniform vec4 pr_glow;          // rgb haze added on the sun's side, a = exponent
global uniform vec4 pr_sky;           // sky colour overhead (mirrored by water, wet roads, gloss)
global uniform vec4 pr_wet;           // x wet roads, y rain, z lamps on, w quality (0 laag, 1 middel, 2 hoog)
global uniform vec4 pr_wind;          // xy wind direction * strength (world xz), z sway speed
global uniform vec4 pr_head0;         // headlights of player 1: world position, w brightness (0 = off)
global uniform vec4 pr_head0_dir;     // direction, w range
global uniform vec4 pr_head1;         // player 2 (split screen)
global uniform vec4 pr_head1_dir;

uniform vec4 albedo = vec4(1.0);
uniform sampler2D tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D emap : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform vec3 emissive = vec3(0.0);
uniform vec3 spec = vec3(0.0666);
uniform float shininess = 30.0;
uniform float alpha_cut = 0.5;
uniform vec3 sway = vec3(0.0, -0.5, 1.0);   // metres at the top, model height of the still base, height over which it grows

varying vec3 v_nw;      // world normal (also right for non-uniform scale and instances)
varying vec3 v_wp;      // world position
#ifdef LIT
varying vec3 g_col;     // fragment -> light(): surface colour (fog and gloss taken off), N.L, the sun's highlight, view-space normal
varying float g_ndl;
varying vec3 g_spec;
varying vec3 g_nv;
varying float g_fog;
#endif

// sRGB decode. Measured on the Compatibility renderer: the base pass outputs enc(dec(EMISSION) + lights) and every
// shadowed light adds enc(its light) on top (blended in gamma space). So EMISSION takes the gamma value as it is
// (emit()), and light() hands over dec(value), which the renderer encodes back to the gamma value.
// Forward+/Mobile work in linear space throughout: there EMISSION needs the decoded value too.
vec3 dec(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
vec3 emit(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return max(c, vec3(0.0));
#else
	return dec(c);
#endif
}

// three.js r128 BRDF_Specular_BlinnPhong * PI (irradiance factor), per unit light colour; n, l, v in one space
vec3 phong_spec(vec3 n, vec3 l, vec3 v, vec3 sc, float sh) {
	vec3 h = normalize(l + v);
	float dnh = max(dot(n, h), 0.0);
	float dlh = max(dot(l, h), 0.0);
	float fres = exp2((-5.55473 * dlh - 6.98316) * dlh);
	vec3 F = (1.0 - sc) * fres + sc;
	return F * 0.25 * (sh * 0.5 + 1.0) * pow(dnh, sh);
}

// a car's headlights: a soft cone from hp.xyz along hd.xyz, fading out at range hd.w; flat ground far ahead still
// catches some (0.3) so the beam reads as a pool on the road, upright things light up fully
float headlight(vec4 hp, vec4 hd, vec3 wp, vec3 n) {
	vec3 l = hp.xyz - wp;
	float d = length(l);
	l /= max(d, 0.001);
	float ca = dot(-l, hd.xyz);
	float cone = smoothstep(0.80, 0.965, ca);
	float att = clamp(1.0 - d / hd.w, 0.0, 1.0);
	float nl = dot(n, l);
	return hp.w * cone * (0.55 + 0.45 * cone) * att * att * smoothstep(-0.05, 0.08, nl) * (0.3 + 0.7 * max(nl, 0.0));
}

// the sky as mirrored in direction r (world): haze at the horizon, the sky's own colour overhead
vec3 sky_mirror(vec3 r, vec3 fogc) {
	return mix(fogc, pr_sky.rgb, clamp(r.y * 1.7, 0.0, 1.0));
}

void vertex() {
	UV = UV * uv_scale + uv_offset;
	mat3 m = mat3(MODEL_MATRIX);
	vec3 sc = vec3(dot(m[0], m[0]), dot(m[1], m[1]), dot(m[2], m[2]));
#ifdef SWAY
	{
		vec3 o = MODEL_MATRIX[3].xyz;
		float w = clamp((VERTEX.y - sway.y) / sway.z, 0.0, 1.0);
		float ph = o.x * 0.31 + o.z * 0.47;
		float t = TIME * pr_wind.z;
		float g = sin(t * 1.3 + ph) * 0.55 + sin(t * 2.9 + ph * 1.7) * 0.3 + sin(t * 0.37 + ph * 0.2) * 0.35 + 0.5;
		vec3 dw = vec3(pr_wind.x, 0.0, pr_wind.y) * (g * sway.x * w * w);
		VERTEX += vec3(dot(m[0], dw), dot(m[1], dw), dot(m[2], dw)) / sc;
	}
#endif
#ifndef BASIC
	v_nw = normalize(m * (NORMAL / sc));
#endif
	v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 c = albedo;
#ifdef TEX
	c *= texture(tex, UV);
#endif
#ifdef VCOL
	c.rgb *= COLOR.rgb;
#endif
#ifdef SCISSOR
	if (c.a < alpha_cut) discard;
#endif
	vec3 lv = normalize(mat3(VIEW_MATRIX) * pr_sun_dir.xyz);
	float f = 0.0;
	vec3 fogc = pr_fog.rgb;
#ifdef FOG
	f = smoothstep(pr_fog_range.x, pr_fog_range.y, -VERTEX.z);
	fogc += pr_glow.rgb * pow(max(dot(-VIEW, lv), 0.0), pr_glow.a);
#endif
#ifdef BASIC
	ALBEDO = emit(mix(c.rgb, fogc, f));
#else
	vec3 nw = normalize(v_nw) * (FRONT_FACING ? 1.0 : -1.0);
#ifdef FLAT
	nw = normalize((INV_VIEW_MATRIX * vec4(normalize(cross(dFdx(VERTEX), dFdy(VERTEX))), 0.0)).xyz);
#endif
	vec3 vw = normalize(CAMERA_POSITION_WORLD - v_wp);
	vec3 gloss = vec3(0.0);     // mirrored light, added after the diffuse light
	float keep = 1.0;           // share of the diffuse light that stays (1 - mirror)
	vec3 sc = spec;
	float sh = shininess;
#ifdef WATER
	{
		// ripples: two layers of the slope field drifting across each other, calmer far away
		float calm = 1.0 / (1.0 + length(CAMERA_POSITION_WORLD - v_wp) * 0.012);
		vec2 w1 = texture(noise, v_wp.xz * 0.043 + vec2(0.019, 0.011) * TIME).ba - 0.5;
		vec2 w2 = texture(noise, v_wp.xz * 0.117 - vec2(0.023, 0.031) * TIME).ba - 0.5;
		vec2 sl = (w1 + w2 * 0.6) * (0.5 + 0.9 * calm) * (1.0 + pr_wet.y);
		nw = normalize(vec3(sl.x, 1.0, sl.y));
		float fr = 0.04 + 0.96 * pow(1.0 - max(dot(nw, vw), 0.0), 5.0);
		fr = min(fr, 0.72);
		vec3 r = reflect(-vw, nw);
		r.y = abs(r.y);
		gloss = sky_mirror(r, fogc) * fr;
		keep = 1.0 - fr;
		// rain: drops as small sparkles that come and go
		if (pr_wet.y > 0.0) {
			float ph = fract(texture(noise, v_wp.xz * 0.61).g * 17.0 + TIME * 1.4);
			gloss += pr_hemi_sky.rgb * (pr_wet.y * 0.35 * smoothstep(0.88, 1.0, ph) * calm);
		}
		sh = 220.0;
	}
#endif
#ifdef WET
	{
		float wetk = pr_wet.x;
		// puddles in big patches; paint (bright) stays matt so the lines keep showing
		float pud = smoothstep(0.50, 0.66, texture(noise, v_wp.xz * 0.023).r);
		float lum = dot(c.rgb, vec3(0.3, 0.6, 0.1));
		c.rgb *= mix(1.0, 0.62, wetk);
		vec2 rip = (texture(noise, v_wp.xz * 0.41).ba - 0.5) * (0.10 - 0.07 * pud);
		vec3 nr = normalize(vec3(rip.x, 1.0, rip.y));
		float fr = 0.03 + 0.97 * pow(1.0 - max(dot(nr, vw), 0.0), 4.0);
		fr *= wetk * mix(0.45, 0.85, pud) * (1.0 - smoothstep(0.25, 0.6, lum) * 0.85) * step(0.5, nw.y);
		vec3 r = reflect(-vw, nr);
		r.y = abs(r.y);
		gloss = sky_mirror(r, fogc) * fr;
		keep = 1.0 - fr;
		if (pr_wet.y > 0.0) {
			float ph = fract(texture(noise, v_wp.xz * 0.83).g * 19.0 + TIME * 1.7);
			gloss += pr_hemi_sky.rgb * (pr_wet.y * 0.22 * smoothstep(0.9, 1.0, ph) * step(0.5, nw.y));
		}
		sc = max(sc, vec3(0.25 * wetk));
		sh = mix(sh, 90.0, wetk);
		nw = normalize(mix(nw, nr, 0.5));
	}
#endif
	vec3 hemi = mix(pr_hemi_ground.rgb, pr_hemi_sky.rgb, 0.5 * nw.y + 0.5);
	float ndl = max(dot(nw, pr_sun_dir.xyz), 0.0);
	vec3 dif = hemi;
	vec3 sunspec = vec3(0.0);
#if defined(PHONG) || defined(WATER) || defined(WET)
	sunspec = pr_sun.rgb * ndl * phong_spec(nw, pr_sun_dir.xyz, vw, sc, sh);
#endif
#ifdef PHONG
	{
		// gloss: glass, chrome and paint mirror the sky a little, more at a glancing angle
		float fr = pow(1.0 - max(dot(nw, vw), 0.0), 4.0);
		vec3 r = reflect(-vw, nw);
		gloss = sky_mirror(vec3(r.x, abs(r.y), r.z), fogc) * sc * (0.12 + 0.88 * fr) * 0.7;
	}
#endif
	float hl = 0.0;
	if (pr_head0.w > 0.0) hl += headlight(pr_head0, pr_head0_dir, v_wp, nw);
	if (pr_head1.w > 0.0) hl += headlight(pr_head1, pr_head1_dir, v_wp, nw);
	dif += vec3(1.0, 0.95, 0.82) * hl;
#ifdef LIT
	if (pr_sun.w < 0.5) {
		dif += pr_sun.rgb * ndl;
		gloss += sunspec;
	}
#else
	dif += pr_sun.rgb * ndl;
	gloss += sunspec;
#endif
	vec3 lit = c.rgb * dif * keep + gloss;
#ifdef EMAP
	lit += emissive * texture(emap, UV).rgb;
#else
	lit += emissive;
#endif
#ifdef LIT
	EMISSION = emit(mix(lit, fogc, f));
	ALBEDO = vec3(0.0);
	g_col = c.rgb * keep * (1.0 - f);
	g_spec = sunspec * (1.0 - f);
	g_ndl = ndl;
	g_fog = f;
	g_nv = normalize(mat3(VIEW_MATRIX) * nw);
#else
	ALBEDO = emit(mix(lit, fogc, f));
#endif
#endif
#ifdef ALPHA_ON
	ALPHA = c.a;
#endif
}

#ifdef LIT
void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		if (pr_sun.w > 0.5) {
			SPECULAR_LIGHT += dec((g_col * pr_sun.rgb * g_ndl + g_spec) * ATTENUATION);
		}
	} else {
		// spot and omni lights (podium, lights under a car): added in gamma space too; close enough on the dark scenes they light
		float sl = max(dot(g_nv, LIGHT), 0.0);
		SPECULAR_LIGHT += dec(g_col * LIGHT_COLOR / PI * sl * ATTENUATION);
	}
}
#endif
"""

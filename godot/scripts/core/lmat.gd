class_name LMat
extends ShaderMaterial
## The HTML game's materials (three.js r128 MeshLambertMaterial / MeshPhongMaterial / MeshBasicMaterial) as one Godot
## shader that lights the three.js way: in gamma space, colour * (hemisphere + sun * N.L) + emissive, then linear fog.
##
## Why: Godot lights in linear space, has a flat ambient instead of a hemisphere light, and its Compatibility renderer
## adds the shadowed sun in a separate pass on top of the encoded picture, so StandardMaterial3D comes out much too bright
## next to the HTML version. Here the shader computes the three.js result itself and hands Godot values that come out as
## exactly that (measured with tools/calib_shader.gd, see emit() and dec() in the shader):
##   base pass:   EMISSION = mix(colour * (hemisphere [+ sun when it has no shadows]) + emissive, fog, f)
##   sun pass:    SPECULAR_LIGHT = dec((1 - f) * colour * sun * N.L * shadow)   (added on top in gamma space by the GPU)
## Light comes from global shader parameters set by Env (pr_*), not from Godot's ambient light or fog.
##
## The properties carry StandardMaterial3D's names (albedo_color, albedo_texture, emission, transparency, cull_mode, ...),
## so code can treat an LMat like a StandardMaterial3D. Flags that change the shader code rebuild it (cached per variant).

enum Kind { LAMBERT, PHONG, BASIC }

var kind := Kind.LAMBERT: set = _set_kind
var albedo_color := Color.WHITE: set = _set_albedo_color
var albedo_texture: Texture2D: set = _set_albedo_texture
var uv1_scale := Vector3.ONE: set = _set_uv1_scale
var uv1_offset := Vector3.ZERO: set = _set_uv1_offset
var emission_enabled := false: set = _set_emission_enabled
var emission := Color.BLACK: set = _set_emission
var emission_energy_multiplier := 1.0: set = _set_emission_energy
var emission_texture: Texture2D: set = _set_emission_texture   ## three emissiveMap (multiplies emissive)
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
## three.js receiveShadow (per mesh there, per material here): only ground, roads, water and the like get shadows;
## buildings, trees and instanced decor do not (otherwise big tree crowns get stripy self-shadow)
var receive_shadow := false: set = _set_receive
## kept for code written against StandardMaterial3D; the shader ignores them
var vertex_color_is_srgb := false
var texture_filter := BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
var texture_repeat := true

var _building := false
static var _cache := {}

func _init() -> void:
	_rebuild()

func clone() -> LMat:
	var m := LMat.new()
	m._building = true
	for p in ["kind", "albedo_color", "albedo_texture", "uv1_scale", "uv1_offset", "emission_enabled", "emission", "emission_energy_multiplier", "emission_texture",
			"specular", "shininess", "transparency", "alpha_scissor_threshold", "cull_mode", "blend_mode", "depth_draw_mode", "no_depth_test", "disable_fog",
			"vertex_color_use_as_albedo", "flat_shading", "receive_shadow"]:
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

func _push_emission() -> void:
	var e := emission * emission_energy_multiplier if emission_enabled else Color.BLACK
	set_shader_parameter("emissive", Vector3(e.r, e.g, e.b))

func _rebuild() -> void:
	if _building:
		return
	var key := "%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d" % [kind, transparency, blend_mode, cull_mode, depth_draw_mode, int(no_depth_test), int(disable_fog),
		int(vertex_color_use_as_albedo), int(flat_shading), int(albedo_texture != null), int(emission_texture != null), int(receive_shadow)]
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
	_push_emission()

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
	if kind == Kind.BASIC: rm.append("unshaded")
	var d := []
	if albedo_texture != null: d.append("#define TEX")
	if emission_texture != null: d.append("#define EMAP")
	if vertex_color_use_as_albedo: d.append("#define VCOL")
	if transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR: d.append("#define SCISSOR")
	if transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or blend_mode == BaseMaterial3D.BLEND_MODE_ADD: d.append("#define ALPHA_ON")
	if not disable_fog: d.append("#define FOG")
	if kind == Kind.PHONG: d.append("#define PHONG")
	if kind == Kind.BASIC: d.append("#define BASIC")
	if flat_shading: d.append("#define FLAT")
	if receive_shadow: d.append("#define RECV")
	return "shader_type spatial;\nrender_mode %s;\n%s\n%s" % [", ".join(rm), "\n".join(d), SHADER_BODY]

const SHADER_BODY := """
global uniform vec4 pr_hemi_sky;      // three HemisphereLight sky colour * intensity (gamma)
global uniform vec4 pr_hemi_ground;
global uniform vec4 pr_sun;           // sun colour * intensity (gamma); w = 1 when the sun has shadows (own light pass)
global uniform vec4 pr_sun_dir;       // towards the sun, world space
global uniform vec4 pr_fog;           // fog colour (gamma)
global uniform vec4 pr_fog_range;     // near, far (three.js Fog: smoothstep(near, far, depth))

uniform vec4 albedo = vec4(1.0);
uniform sampler2D tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D emap : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform vec3 emissive = vec3(0.0);
uniform vec3 spec = vec3(0.0666);
uniform float shininess = 30.0;
uniform float alpha_cut = 0.5;

varying vec3 v_nw;      // world normal (three-style: also right for non-uniform scale and instances)
varying vec3 v_hf;      // Lambert is lit per vertex in three.js r128 (Gouraud): hemisphere and sun N.L, front and back
varying vec3 v_hb;
varying float v_lf;
varying float v_lb;
varying vec3 g_col;     // fragment -> light(): surface colour, fog, N.L, view-space normal and sun direction
varying float g_fog;
varying float g_ndl;
varying vec3 g_nv;
varying vec3 g_lv;

// sRGB decode. Measured on the Compatibility renderer: the base pass outputs enc(dec(EMISSION) + lights) and every
// shadowed light adds enc(its light) on top (blended in gamma space). So EMISSION takes the three.js (gamma) value as
// it is (emit()), and light() hands over dec(value), which the renderer encodes back to the three.js value.
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

// three.js r128 BRDF_Specular_BlinnPhong * PI (irradiance factor), per unit light colour
vec3 phong_spec(vec3 n, vec3 l, vec3 v) {
	vec3 h = normalize(l + v);
	float dnh = max(dot(n, h), 0.0);
	float dlh = max(dot(l, h), 0.0);
	float fres = exp2((-5.55473 * dlh - 6.98316) * dlh);
	vec3 F = (1.0 - spec) * fres + spec;
	return F * 0.25 * (shininess * 0.5 + 1.0) * pow(dnh, shininess);
}

void vertex() {
	UV = UV * uv_scale + uv_offset;
#ifndef BASIC
	mat3 m = mat3(MODEL_MATRIX);
	vec3 nw = normalize(m * (NORMAL / vec3(dot(m[0], m[0]), dot(m[1], m[1]), dot(m[2], m[2]))));
	v_nw = nw;
	v_hf = mix(pr_hemi_ground.rgb, pr_hemi_sky.rgb, 0.5 * nw.y + 0.5);
	v_hb = mix(pr_hemi_ground.rgb, pr_hemi_sky.rgb, -0.5 * nw.y + 0.5);
	v_lf = max(dot(nw, pr_sun_dir.xyz), 0.0);
	v_lb = max(dot(-nw, pr_sun_dir.xyz), 0.0);
#endif
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
	float f = 0.0;
#ifdef FOG
	f = smoothstep(pr_fog_range.x, pr_fog_range.y, -VERTEX.z);
#endif
#ifdef BASIC
	ALBEDO = emit(mix(c.rgb, pr_fog.rgb, f));
#else
	vec3 hemi;
	float ndl;
	vec3 nw = normalize(v_nw) * (FRONT_FACING ? 1.0 : -1.0);
#ifdef FLAT
	nw = normalize((INV_VIEW_MATRIX * vec4(normalize(cross(dFdx(VERTEX), dFdy(VERTEX))), 0.0)).xyz);
#endif
#if defined(PHONG) || defined(FLAT)
	hemi = mix(pr_hemi_ground.rgb, pr_hemi_sky.rgb, 0.5 * nw.y + 0.5);
	ndl = max(dot(nw, pr_sun_dir.xyz), 0.0);
#else
	hemi = FRONT_FACING ? v_hf : v_hb;
	ndl = FRONT_FACING ? v_lf : v_lb;
#endif
	vec3 nv = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	vec3 lv = normalize((VIEW_MATRIX * vec4(pr_sun_dir.xyz, 0.0)).xyz);
	vec3 lit = c.rgb * hemi;
	if (pr_sun.w < 0.5) {
		lit += c.rgb * pr_sun.rgb * ndl;
#ifdef PHONG
		lit += pr_sun.rgb * ndl * phong_spec(nv, lv, VIEW);
#endif
	}
#ifdef EMAP
	lit += emissive * texture(emap, UV).rgb;
#else
	lit += emissive;
#endif
	EMISSION = emit(mix(lit, pr_fog.rgb, f));
	ALBEDO = vec3(0.0);
	g_col = c.rgb;
	g_fog = f;
	g_ndl = ndl;
	g_nv = nv;
	g_lv = lv;
#endif
#ifdef ALPHA_ON
	ALPHA = c.a;
#endif
}

#ifndef BASIC
void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		if (pr_sun.w > 0.5) {
			vec3 t = g_col * pr_sun.rgb * g_ndl;
#ifdef PHONG
			t += pr_sun.rgb * g_ndl * phong_spec(g_nv, g_lv, VIEW);
#endif
#ifdef RECV
			float sh = ATTENUATION;
#else
			float sh = 1.0;
#endif
			SPECULAR_LIGHT += dec((1.0 - g_fog) * t * sh);
		}
	} else {
		// spot lights (headlights, podium): three adds them in gamma space too; close enough on the dark scenes they light
		float sl = max(dot(g_nv, LIGHT), 0.0);
		SPECULAR_LIGHT += dec((1.0 - g_fog) * g_col * LIGHT_COLOR / PI * sl * ATTENUATION);
	}
}
#endif
"""

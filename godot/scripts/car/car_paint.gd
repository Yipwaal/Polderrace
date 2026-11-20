class_name CarPaint
extends LMat
## Car materials on top of LMat: the same light, shadows and fog as the world (the pr_* globals), plus what makes a car look
## like a car: a clear coat with a sharp sun glint, a fresnel rim and a cheap fake reflection of sky, horizon and road
## (no reflection probes), metallic flakes, pearl colour shift, panel lines, real (see-through) glass.
##
## It does not copy LMat's shader: it takes the shader LMat picks for the material's flags and adds its own code at four
## anchors (see _patch). If lmat.gd changes so that an anchor is gone, the material falls back to plain LMat (CarPaint.hooked
## turns false and tests/test_cars.gd fails), so cars are never unlit.
##
## Three kinds (mode):
##   PAINT   the body colour. finish: gloss (default), metallic, matte, satin, pearl, chrome (FINISHES). Optional panel-line
##           map (set_lines) drawn in object space on vertices whose colour alpha is 1 (the body skin), see CarBody.lines_image.
##   DETAIL  everything else that is opaque, in one material: vertex colour = colour, vertex alpha = shine
##           (0 rubber/matte plastic .. 0.5 gloss plastic .. 0.8 polished metal .. 1 chrome).
##   GLASS   tinted glass: see-through head-on, mirror-like at a glancing angle.

enum Mode { PAINT, DETAIL, GLASS }

## finish -> [f0, reflection, roughness, coat strength, coat shininess, base colour factor, flake, pearl, specular (hex), shininess, tint]
##   f0: reflection head-on; reflection: strength of the sky/road reflection; roughness: 0 sharp horizon .. 1 blurred;
##   tint: how much the reflection takes the paint's colour (chrome, metallic)
const FINISHES := {
	"gloss": {"f0": 0.13, "refl": 0.85, "rough": 0.03, "coat": 1.0, "coat_shin": 420.0, "base": 0.94, "flake": 0.0, "pearl": 0.0, "spec": 0x4a4a4a, "shin": 40.0, "tint": 0.35},
	"metallic": {"f0": 0.16, "refl": 0.8, "rough": 0.08, "coat": 1.0, "coat_shin": 380.0, "base": 0.8, "flake": 1.0, "pearl": 0.0, "spec": 0xa8a8a8, "shin": 12.0, "tint": 0.5},
	"matte": {"f0": 0.03, "refl": 0.1, "rough": 1.0, "coat": 0.0, "coat_shin": 40.0, "base": 0.9, "flake": 0.0, "pearl": 0.0, "spec": 0x303030, "shin": 8.0, "tint": 0.0},
	"satin": {"f0": 0.12, "refl": 0.5, "rough": 0.5, "coat": 0.25, "coat_shin": 50.0, "base": 0.93, "flake": 0.0, "pearl": 0.0, "spec": 0x585858, "shin": 18.0, "tint": 0.15},
	"pearl": {"f0": 0.14, "refl": 0.85, "rough": 0.04, "coat": 1.0, "coat_shin": 400.0, "base": 0.92, "flake": 0.4, "pearl": 0.8, "spec": 0x787878, "shin": 26.0, "tint": 0.25},
	"chrome": {"f0": 0.78, "refl": 1.0, "rough": 0.02, "coat": 1.4, "coat_shin": 700.0, "base": 0.14, "flake": 0.0, "pearl": 0.0, "spec": 0x303030, "shin": 60.0, "tint": 0.5},
}
const FINISH_NAMES := {"gloss": "Glans", "metallic": "Metallic", "matte": "Mat", "satin": "Zijdeglans", "pearl": "Parelmoer", "chrome": "Chroom"}

var mode := Mode.PAINT
var finish := "gloss": set = set_finish
var lines: Texture2D = null
var lines_map := Vector4(0, 1, 1, 1)

## true while every anchor was found in LMat's shader (false = plain LMat look; a test checks it)
static var hooked := true
static var _variants := {}   # LMat Shader -> [paint, detail, glass] Shader

static func paint(color, fin := "gloss") -> CarPaint:
	var m := CarPaint.new()
	m._building = true
	m.mode = Mode.PAINT
	m.kind = LMat.Kind.PHONG
	m.albedo_color = color if color is Color else MathX.col(int(color))
	m._building = false
	m.finish = fin if FINISHES.has(fin) else "gloss"   # the setter rebuilds
	return m

static func detail() -> CarPaint:
	var m := CarPaint.new()
	m._building = true
	m.mode = Mode.DETAIL
	m.kind = LMat.Kind.PHONG
	m.vertex_color_use_as_albedo = true
	m.specular = MathX.col(0x3a3a3a)
	m.shininess = 30.0
	m._building = false
	m._rebuild()
	return m

static func glass(color: int, opacity: float) -> CarPaint:
	var m := CarPaint.new()
	m._building = true
	m.mode = Mode.GLASS
	m.kind = LMat.Kind.PHONG
	m.albedo_color = MathX.col(color)
	m.albedo_color.a = opacity
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.specular = MathX.col(0x9aa6b2)
	m.shininess = 90.0
	m._building = false
	m._rebuild()
	return m

func set_finish(f: String) -> void:
	finish = f if FINISHES.has(f) else "gloss"
	if mode == Mode.PAINT:
		var F: Dictionary = FINISHES[finish]
		_building = true
		specular = MathX.col(F.spec)
		shininess = F.shin
		_building = false
		_rebuild()

## the panel-line map of a model (CarBody.lines_tex) and how car space maps onto it: (zR, 1 / length, 1 / height, 1 / half width)
func set_lines(tex: Texture2D, map: Vector4) -> void:
	lines = tex
	lines_map = map
	set_shader_parameter("cp_lines", lines)
	set_shader_parameter("cp_map", lines_map)
	set_shader_parameter("cp_lines_on", 1.0 if lines != null else 0.0)

func clone() -> LMat:
	var m := CarPaint.new()
	m._building = true
	m.mode = mode
	for p in ["kind", "albedo_color", "albedo_texture", "uv1_scale", "uv1_offset", "emission_enabled", "emission", "emission_energy_multiplier", "emission_texture",
			"specular", "shininess", "transparency", "alpha_scissor_threshold", "cull_mode", "blend_mode", "depth_draw_mode", "no_depth_test", "disable_fog",
			"vertex_color_use_as_albedo", "flat_shading", "receive_shadow"]:
		m.set(p, get(p))
	m.finish = finish
	m._building = false
	m.render_priority = render_priority
	m._rebuild()
	m.set_lines(lines, lines_map)
	for k in get_meta_list():
		m.set_meta(k, get_meta(k))
	return m

func _rebuild() -> void:
	if _building:
		return
	super._rebuild()   # LMat picks its shader for the flags and pushes its own parameters
	var base: Shader = shader
	if base == null:
		return
	if not _variants.has(base):
		_variants[base] = [_patch(base.code, Mode.PAINT), _patch(base.code, Mode.DETAIL), _patch(base.code, Mode.GLASS)]
	var sh = _variants[base][mode]
	if sh != null:
		shader = sh
	_push()

func _push() -> void:
	var F: Dictionary = FINISHES[finish if mode == Mode.PAINT else "gloss"]
	if mode == Mode.GLASS:
		F = {"f0": 0.1, "refl": 1.0, "rough": 0.04, "coat": 1.2, "coat_shin": 500.0, "base": 1.0, "flake": 0.0, "pearl": 0.0, "tint": 0.0}
	set_shader_parameter("cp_a", Vector4(F.f0, F.refl, F.rough, F.base))
	set_shader_parameter("cp_b", Vector4(F.coat, F.coat_shin, F.flake, F.pearl))
	set_shader_parameter("cp_tint", F.tint)
	set_shader_parameter("cp_lines", lines)
	set_shader_parameter("cp_map", lines_map)
	set_shader_parameter("cp_lines_on", 1.0 if lines != null else 0.0)

## LMat's shader code with the car code added: null when an anchor is missing (then the material stays plain LMat)
static func _patch(code: String, m: int):
	var A_SPEC := "vec3 phong_spec(vec3 n, vec3 l, vec3 v, vec3 sc, float sh) {"
	var A_VERT := "void vertex() {"
	var A_FRAG := "\tfloat f = 0.0;"
	var A_GLOSS := "\tfloat hl = 0.0;"
	var A_OUT := "\tvec3 lit = c.rgb * dif * keep + gloss;\n"
	var A_ALPHA := "\tALPHA = c.a;"
	for a in [A_SPEC, A_VERT, A_FRAG, A_GLOSS, A_OUT]:
		if code.count(a) != 1:
			if hooked: push_warning("CarPaint: anker niet gevonden in LMat-shader: " + a)
			hooked = false
			return null
	if m == Mode.GLASS and code.count(A_ALPHA) != 1:
		hooked = false
		return null
	var defs := ["#define CP_PAINT", "#define CP_DETAIL", "#define CP_GLASS"]
	code = code.replace(A_SPEC, "vec3 phong_spec0(vec3 n, vec3 l, vec3 v, vec3 sc, float sh) {")
	code = code.replace(A_VERT, defs[m] + "\n" + CP_FUNCS + A_VERT + "\n\tcp_pos = VERTEX;\n\tcp_nrm = NORMAL;\n\tcp_col = COLOR;")
	code = code.replace(A_FRAG, CP_SURFACE + A_FRAG)
	# LMat's own sky mirror (PHONG) makes way for the car's reflection below
	code = code.replace(A_GLOSS, "\tgloss = vec3(0.0);\n" + A_GLOSS)
	code = code.replace(A_OUT, A_OUT + CP_REFLECT)
	if m == Mode.GLASS:
		code = code.replace(A_ALPHA, "\tALPHA = mix(c.a, 1.0, clamp(cp_fres * 1.6, 0.0, 1.0));")
	var sh := Shader.new()
	sh.code = code
	return sh

const CP_FUNCS := """
uniform vec4 cp_a = vec4(0.07, 0.6, 0.05, 1.0);    // f0, reflection, roughness, base colour factor
uniform vec4 cp_b = vec4(1.0, 420.0, 0.0, 0.0);    // coat strength, coat shininess, flake, pearl
uniform float cp_tint = 0.0;                        // how much the reflection takes the surface colour
uniform sampler2D cp_lines : filter_linear_mipmap_anisotropic, repeat_disable, hint_default_white;
uniform vec4 cp_map = vec4(0.0, 1.0, 1.0, 1.0);    // zR, 1 / length, 1 / height, 1 / half width
uniform float cp_lines_on = 0.0;
varying vec3 cp_pos;      // car space
varying vec3 cp_nrm;
varying vec4 cp_col;
varying float cp_shine;   // fragment -> phong_spec: coat strength of this fragment
varying float cp_fres;
varying float cp_spark;

float cp_hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// the world a car body mirrors: sky above, haze at the horizon, a dark band of land and the road below (r: world direction)
vec3 cp_env(vec3 r, float rough) {
	float up = r.y;
	float ls = dot(pr_hemi_sky.rgb, vec3(0.3, 0.5, 0.2));
	float lg = dot(pr_hemi_ground.rgb, vec3(0.3, 0.5, 0.2));
	vec3 sky = mix(pr_sky.rgb, pr_hemi_sky.rgb * vec3(0.72, 0.86, 1.1), 0.25);   // the sky overhead (Env: pr_sky)
	vec3 hor = mix(pr_fog.rgb, vec3(ls), 0.35) * 1.08;
	vec3 land = mix(pr_hemi_ground.rgb, vec3(lg), 0.6) * 0.42;
	vec3 road = vec3(ls * 0.26 + lg * 0.1);
	vec3 above = mix(hor, sky, pow(clamp(up, 0.0, 1.0), 0.5 + rough * 0.4));
	vec3 below = mix(land, road, clamp(-up * 2.4 - 0.2, 0.0, 1.0));
	float w = 0.01 + rough * 0.7;
	vec3 e = mix(below, above, smoothstep(-w, w, up + 0.015));
	// the sun's glow in the sky
	float sd = max(dot(r, pr_sun_dir.xyz), 0.0);
	e += pr_sun.rgb * (pow(sd, 40.0 / (1.0 + rough * 12.0)) * 0.35) * (1.0 - rough * 0.7);
	return e;
}

// LMat's Blinn-Phong lobe (the paint itself) plus the clear coat: a tight glint of the sun
vec3 phong_spec(vec3 n, vec3 l, vec3 v, vec3 sc, float sh0) {
	vec3 s = phong_spec0(n, l, v, sc, sh0);
	vec3 h = normalize(l + v);
	float dnh = max(dot(n, h), 0.0);
	float sh = cp_b.y;
	float coat = cp_shine * 0.05 * 0.25 * (sh * 0.5 + 1.0) * pow(dnh, sh);
	// flakes: tiny mirrors that light up round the highlight
	float fl = cp_spark * 3.0 * pow(dnh, 30.0);
	return s + vec3(coat + fl);
}

"""

const CP_SURFACE := """
	vec3 cp_n = normalize(NORMAL) * (FRONT_FACING ? 1.0 : -1.0);
	float cp_ndv = clamp(dot(cp_n, VIEW), 0.0, 1.0);
	float cp_f0 = cp_a.x;
	float cp_refl = cp_a.y;
	float cp_rough = cp_a.z;
	float cp_tn = cp_tint;
	cp_shine = cp_b.x;
	cp_spark = 0.0;
#ifdef CP_PAINT
	c.rgb *= cp_a.w;
	if (cp_lines_on > 0.5 && cp_col.a > 0.5) {
		// panel lines, drawn in car space: the flank chart (z, y) on the upper half of the map, the top chart (z, |x|) below
		vec3 an = abs(normalize(cp_nrm));
		float u = (cp_pos.z - cp_map.x) * cp_map.y;
		float side = texture(cp_lines, vec2(u, 0.5 - cp_pos.y * cp_map.z * 0.5)).r;
		float top = texture(cp_lines, vec2(u, 0.5 + abs(cp_pos.x) * cp_map.w * 0.5)).r;
		float wt = smoothstep(0.55, 0.75, an.y / max(an.x + an.y, 1e-4));
		float ln = mix(side, top, wt);
		ln = mix(ln, 1.0, smoothstep(0.55, 0.8, an.z));
		c.rgb *= ln;
		cp_shine *= ln;
	}
	if (cp_b.z > 0.0) {
		// metallic: the colour is lighter where it faces you and darker at a glancing angle, with a fine grain of flakes
		float cp_nr = 1.0 - smoothstep(3.0, 11.0, -VERTEX.z);
		float g = cp_hash(floor(cp_pos * 700.0));
		c.rgb *= mix(1.0, 0.94 + 0.12 * g, cp_b.z * cp_nr) * mix(0.78, 1.14, cp_ndv);
		cp_spark = cp_b.z * cp_nr * step(0.9, g);
	}
	if (cp_b.w > 0.0) {
		// pearl: the colour turns towards its neighbour on the colour wheel at a glancing angle
		vec3 sh = c.gbr * 0.75 + c.brg * 0.25 + 0.1;
		c.rgb = mix(c.rgb, sh, cp_b.w * pow(1.0 - cp_ndv, 1.5));
	}
#endif
#ifdef CP_DETAIL
	float cp_s = cp_col.a;
	float cp_metal = smoothstep(0.7, 1.0, cp_s);
	cp_f0 = mix(0.04, 0.7, cp_metal);
	cp_refl = cp_s;
	cp_rough = mix(0.5, 0.04, cp_s);
	cp_tn = cp_metal * 0.6;
	cp_shine = cp_s * 1.2;
	vec3 cp_c0 = c.rgb;
	c.rgb *= mix(1.0, 0.3, cp_metal);
#endif
"""

const CP_REFLECT := """
	{
		vec3 cp_vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		vec3 cp_r = reflect(-cp_vw, nw);
		float cp_fr = cp_f0 + (1.0 - cp_f0) * pow(1.0 - cp_ndv, 3.5);
		cp_fres = cp_fr;
		vec3 cp_e = cp_env(cp_r, cp_rough);
#ifdef CP_DETAIL
		cp_e *= mix(vec3(1.0), cp_c0 * 1.6, cp_tn);
#else
		cp_e *= mix(vec3(1.0), c.rgb / max(cp_a.w, 0.05) * 1.5, cp_tn);
#endif
		lit += cp_e * cp_fr * cp_refl * (1.0 - cp_rough * 0.6);
	}
"""

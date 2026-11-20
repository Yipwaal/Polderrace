extends CanvasLayer
## Screen effects of the race (JS: radial blur post pass, speed lines overlay, rear-view mirror frame), between the 3D
## picture and the HUD. One instance in the game scene (main.gd). Plus a vignette with a slight colour cast per time of
## day (one multiplied quad, no screen copy). Quality "laag": none of the full-screen effects.

var blur: ColorRect
var grade: ColorRect
var _grade_key := ""
var _blur_q := ""
var lines: SpeedLines
var mirror_frame: Panel
var mirror_img: TextureRect

const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength = 0.0;
uniform vec2 center = vec2(0.5, 0.5);
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - center;
	float s = strength * smoothstep(0.28, 0.85, length(dir));
	vec4 c = vec4(0.0);
	for (int i = 0; i < TAPS; i++) {
		c += texture(screen_tex, uv - dir * s * float(i) / float(TAPS - 1));
	}
	COLOR = c / float(TAPS);
}
"""

## darker towards the corners, times a colour cast: multiplied over the 3D picture
const GRADE_SHADER := """
shader_type canvas_item;
render_mode blend_mul;
uniform vec3 tint = vec3(1.0);
uniform float vig = 0.22;
void fragment() {
	vec2 d = UV - 0.5;
	float v = 1.0 - vig * smoothstep(0.18, 0.62, dot(d, d));
	COLOR = vec4(tint * v, 1.0);
}
"""
const GRADE := {"day": [Vector3(1.0, 0.995, 0.975), 0.2], "dusk": [Vector3(1.0, 0.965, 0.93), 0.26], "night": [Vector3(0.93, 0.96, 1.0), 0.3]}

## rounded corners of the mirror (JS mirrorMask), the picture flipped left-right like a mirror
const MIRROR_SHADER := """
shader_type canvas_item;
uniform vec2 px = vec2(420.0, 123.0);
uniform float radius = 21.0;
void fragment() {
	vec2 uv = vec2(1.0 - UV.x, UV.y);
	vec4 c = texture(TEXTURE, uv);
	vec2 p = UV * px;
	vec2 q = abs(p - px * 0.5) - (px * 0.5 - vec2(radius));
	float d = length(max(q, 0.0)) - radius;
	COLOR = vec4(c.rgb, clamp(0.5 - d, 0.0, 1.0));
}
"""

func _ready() -> void:
	layer = 5
	grade = ColorRect.new()
	grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = Shader.new()
	gm.shader.code = GRADE_SHADER
	grade.material = gm
	grade.visible = false
	add_child(grade)
	blur = ColorRect.new()
	blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	blur.material = sm
	blur.visible = false
	add_child(blur)
	lines = SpeedLines.new()
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lines)
	mirror_frame = Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#161a22")
	st.set_corner_radius_all(14)
	st.shadow_color = Color(0, 0, 0, 0.4); st.shadow_size = 7; st.shadow_offset = Vector2(0, 4)
	mirror_frame.add_theme_stylebox_override("panel", st)
	mirror_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mirror_frame.visible = false
	add_child(mirror_frame)
	mirror_img = TextureRect.new()
	mirror_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mirror_img.stretch_mode = TextureRect.STRETCH_SCALE
	var mm := ShaderMaterial.new()
	mm.shader = Shader.new()
	mm.shader.code = MIRROR_SHADER
	mirror_img.material = mm
	mirror_frame.add_child(mirror_img)

func tick(dt: float) -> void:
	var g := Game
	var fxOn: bool = g.fxOn()
	# radial blur by speed (JS: fxOn && quality != low ? speedFx * 0.055)
	var q: String = G.prefs.get("quality", "high")
	var b: float = g.speedFx * 0.055 if fxOn and q != "low" and not g.split else 0.0
	blur.visible = b > 0.002
	if blur.visible:
		if q != _blur_q:
			# fewer samples on "middel"
			_blur_q = q
			blur.material.shader.code = BLUR_SHADER.replace("TAPS", "10" if q == "high" else "6")
		blur.material.set_shader_parameter("strength", b)
	# vignette and colour cast: in the race and the menus over the track, not in the garage or on the podium
	var staged: bool = World.root != null and not World.root.visible
	grade.visible = q != "low" and Env.me != null and not staged
	if grade.visible:
		var key: String = Env.me.time + Env.me.weather
		if key != _grade_key:
			_grade_key = key
			var gr: Array = GRADE.get(Env.me.time, GRADE.day)
			var dull := Env.me.weather != "dry"
			grade.material.set_shader_parameter("tint", (gr[0] as Vector3).lerp(Vector3(0.97, 0.98, 1.0), 0.6) if dull else gr[0])
			grade.material.set_shader_parameter("vig", gr[1])
	lines.step(0.0 if g.paused else dt, g.speedFx if fxOn and not g.split else 0.0)
	# mirror
	var on: bool = Fx.me != null and Fx.me.mirrorOn()
	mirror_frame.visible = on
	if on:
		var vp := get_viewport().get_visible_rect().size
		var w := minf(420, vp.x * 0.34)
		var h := w * 150 / 512
		mirror_frame.position = Vector2((vp.x - w) / 2 - 4, 66 - 4)
		mirror_frame.size = Vector2(w + 8, h + 8)
		mirror_img.position = Vector2(4, 4)
		mirror_img.size = Vector2(w, h)
		mirror_img.texture = Fx.me.mirror_vp.get_texture()
		mirror_img.material.set_shader_parameter("px", Vector2(w, h))
		mirror_img.material.set_shader_parameter("radius", 26.0 * w / 512)

## JS drawSpeedLines: white streaks flying out of the centre at high speed
class SpeedLines extends Control:
	var streaks: Array = []
	var a := 0.0
	func _init() -> void:
		for _i in 46:
			streaks.append({"a": randf() * TAU, "r": 0.3 + randf() * 0.7, "len": 0.06 + randf() * 0.12, "v": 0.8 + randf() * 0.8})
	func step(dt: float, speedFx: float) -> void:
		a = clampf((speedFx - 0.45) / 0.55, 0, 1)
		if a <= 0.01:
			if visible: visible = false
			return
		visible = true
		for s in streaks:
			s.r += dt * s.v * (1.2 + 2.5 * speedFx)
			if s.r > 1.05:
				s.r = 0.32 + randf() * 0.15; s.a = randf() * TAU
		queue_redraw()
	func _draw() -> void:
		var W := size.x
		var H := size.y
		var c := Vector2(W / 2, H * 0.44)
		var maxR := Vector2(W, H).length() * 0.6
		for s in streaks:
			var r0: float = s.r * maxR
			var r1: float = (s.r + s.len) * maxR
			var al: float = a * 0.28 * clampf((s.r - 0.32) / 0.3, 0, 1)
			var d := Vector2(cos(s.a), sin(s.a) * 0.75)
			draw_line(c + d * r0, c + d * r1, Color(1, 1, 1, al), maxf(1, W / 900.0), true)

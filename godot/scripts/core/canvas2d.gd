class_name Canvas2D
extends RefCounted
## The HTML5 canvas 2D API (the part the HTML game uses), so its canvasTex(w,h,fn,repeat) drawing code ports almost
## line for line:   Canvas2D.tex(256, 512, func(g, w, h): g.fillStyle = "#4a4d52"; g.fillRect(0, 0, w, h), true)
## Drawing is recorded and rendered on the GPU in a SubViewport by Canvas2D.flush(node) (await it once after building a
## scene); tex() returns the ImageTexture right away and flush() fills it in.
## Supported: fillStyle/strokeStyle (css colours "#rgb" "#rrggbb" "rgb()" "rgba()" or a gradient), lineWidth, lineCap,
## lineJoin, font, textAlign, textBaseline, globalAlpha, fillRect, strokeRect, clearRect, beginPath, moveTo, lineTo,
## quadraticCurveTo, arc, ellipse, rect, closePath, fill, stroke, clip (rectangular), fillText (with maxWidth),
## measureText, save, restore, translate, rotate, scale, createLinearGradient, createRadialGradient.
## Note: the result is premultiplied by alpha where it is not opaque (Mats.M with a premul map handles that).

static var _pending: Array = []
static var _fonts := {}

var width := 0
var height := 0
var texture: ImageTexture
var cmds: Array = []

var fillStyle = "#000000"
var strokeStyle = "#000000"
var lineWidth := 1.0
var lineCap := "butt"
var lineJoin := "miter"
var font := "10px sans-serif"
var textAlign := "start"
var textBaseline := "alphabetic"
var globalAlpha := 1.0

var _xf := Transform2D.IDENTITY
var _stack: Array = []
var _subs: Array = []           ## finished sub-paths: [PackedVector2Array, closed]
var _cur := PackedVector2Array()
var _cur_closed := false
var _clip = null                ## PackedVector2Array or null

func _init(w: int, h: int) -> void:
	width = w
	height = h

## new texture of w x h drawn by fn(g, w, h); repeat: wrap (the material sets texture_repeat)
static func tex(w: int, h: int, fn: Callable, repeat := false) -> ImageTexture:
	var c := Canvas2D.new(w, h)
	fn.call(c, w, h)
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 1))
	c.texture = ImageTexture.create_from_image(img)
	c.texture.set_meta("canvas", true)
	c.texture.set_meta("repeat", repeat)
	_pending.append(c)
	return c.texture

static func pending_count() -> int:
	return _pending.size()

## render every pending canvas (a few frames) and fill in their textures
static func flush(host: Node) -> void:
	if _pending.is_empty():
		return
	if DisplayServer.get_name() == "headless":
		# no renderer (tests, dedicated runs): nothing can be drawn, the textures keep their grey placeholder
		_pending = []
		return
	var batch: Array = _pending
	_pending = []
	var vps: Array = []
	# Godot blends 2D into a transparent target premultiplied (rgb * a); a browser canvas hands three.js straight alpha.
	# So every canvas is drawn in an inner viewport and copied through an un-premultiply shader into the outer one
	# (a child viewport renders before its parent).
	var mk := func(w: int, h: int) -> SubViewport:
		var v := SubViewport.new()
		v.size = Vector2i(w, h)
		v.transparent_bg = true
		v.disable_3d = true
		v.render_target_update_mode = SubViewport.UPDATE_ONCE
		v.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		return v
	for c in batch:
		var outer: SubViewport = mk.call(c.width, c.height)
		var inner: SubViewport = mk.call(c.width, c.height)
		c._build_nodes(inner)
		outer.add_child(inner)
		var tr := TextureRect.new()
		tr.texture = inner.get_texture()
		tr.size = Vector2(c.width, c.height)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.material = _unpremul_material()
		outer.add_child(tr)
		host.add_child(outer)
		vps.append(outer)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for i in batch.size():
		var img: Image = vps[i].get_texture().get_image() if DisplayServer.get_name() != "headless" else null
		if img != null and not img.is_empty():
			img.convert(Image.FORMAT_RGBA8)
			img.generate_mipmaps()
			batch[i].texture.set_image(img)
		vps[i].queue_free()

# ------------------------------------------------------------------ state

func save() -> void:
	_stack.append([_xf, fillStyle, strokeStyle, lineWidth, lineCap, lineJoin, font, textAlign, textBaseline, globalAlpha, _clip])

func restore() -> void:
	if _stack.is_empty():
		return
	var s: Array = _stack.pop_back()
	_xf = s[0]; fillStyle = s[1]; strokeStyle = s[2]; lineWidth = s[3]; lineCap = s[4]; lineJoin = s[5]
	font = s[6]; textAlign = s[7]; textBaseline = s[8]; globalAlpha = s[9]; _clip = s[10]

func translate(x: float, y: float) -> void:
	_xf = _xf * Transform2D(0.0, Vector2(x, y))

func rotate(a: float) -> void:
	_xf = _xf * Transform2D(a, Vector2.ZERO)

func scale(x: float, y: float) -> void:
	_xf = _xf * Transform2D(0.0, Vector2(x, y), 0.0, Vector2.ZERO)

# ------------------------------------------------------------------ gradients

func createLinearGradient(x0: float, y0: float, x1: float, y1: float) -> CanvasGrad:
	return CanvasGrad.new(false, _xf * Vector2(x0, y0), _xf * Vector2(x1, y1), 0.0, 0.0)

func createRadialGradient(x0: float, y0: float, r0: float, x1: float, y1: float, r1: float) -> CanvasGrad:
	var sc := _xf.get_scale().x
	return CanvasGrad.new(true, _xf * Vector2(x0, y0), _xf * Vector2(x1, y1), r0 * sc, r1 * sc)

# ------------------------------------------------------------------ paths

func beginPath() -> void:
	_subs = []
	_cur = PackedVector2Array()
	_cur_closed = false

func _flush_sub() -> void:
	if _cur.size() > 0:
		_subs.append([_cur, _cur_closed])
	_cur = PackedVector2Array()
	_cur_closed = false

func moveTo(x: float, y: float) -> void:
	_flush_sub()
	_cur.append(_xf * Vector2(x, y))

func lineTo(x: float, y: float) -> void:
	_cur.append(_xf * Vector2(x, y))

func quadraticCurveTo(cx: float, cy: float, x: float, y: float) -> void:
	var p0 := _xf.affine_inverse() * (_cur[_cur.size() - 1] if _cur.size() > 0 else _xf * Vector2(cx, cy))
	for k in range(1, 13):
		var t := k / 12.0
		var a := p0.lerp(Vector2(cx, cy), t)
		var b := Vector2(cx, cy).lerp(Vector2(x, y), t)
		_cur.append(_xf * a.lerp(b, t))

func arc(x: float, y: float, r: float, a0: float, a1: float, ccw := false) -> void:
	ellipse(x, y, r, r, 0.0, a0, a1, ccw)

func ellipse(x: float, y: float, rx: float, ry: float, rot: float, a0: float, a1: float, ccw := false) -> void:
	var da := a1 - a0
	if not ccw:
		if da >= TAU: da = TAU
		elif da < 0: da = fposmod(da, TAU)
	else:
		if -da >= TAU: da = -TAU
		elif da > 0: da = -fposmod(-da, TAU)
	var n := clampi(int(ceil(maxf(rx, ry) * absf(da) / 3.0)), 12, 96)
	var cr := cos(rot)
	var sr := sin(rot)
	for k in n + 1:
		var a := a0 + da * k / n
		var px := rx * cos(a)
		var py := ry * sin(a)
		_cur.append(_xf * Vector2(x + px * cr - py * sr, y + px * sr + py * cr))

func rect(x: float, y: float, w: float, h: float) -> void:
	moveTo(x, y); lineTo(x + w, y); lineTo(x + w, y + h); lineTo(x, y + h)
	closePath()

func closePath() -> void:
	_cur_closed = true
	var first := _cur[0] if _cur.size() > 0 else Vector2.ZERO
	_flush_sub()
	_cur.append(first)

func _polys() -> Array:
	var all := _subs.duplicate()
	if _cur.size() > 0:
		all.append([_cur, _cur_closed])
	return all

func fill() -> void:
	var polys: Array = []
	for s in _polys():
		var p: PackedVector2Array = s[0]
		if p.size() >= 3:
			polys.append(p)
	if polys.is_empty():
		return
	if polys.size() > 1:   # one fill of several sub-paths covers their union once (non-zero rule)
		var merged: Array = []
		for p in polys:
			var cur: PackedVector2Array = p
			var changed := true
			while changed:
				changed = false
				for i in merged.size():
					var u := Geometry2D.merge_polygons(merged[i], cur)
					if u.size() == 1:
						cur = u[0]
						merged.remove_at(i)
						changed = true
						break
			merged.append(cur)
		polys = merged
	_push_fill(polys, fillStyle)

func stroke() -> void:
	for s in _polys():
		var p: PackedVector2Array = s[0]
		if p.size() < 2:
			continue
		if s[1] and p[0] != p[p.size() - 1]:
			p = p.duplicate(); p.append(p[0])
		cmds.append({"t": "line", "pts": p, "col": _color(strokeStyle), "w": lineWidth * _xf.get_scale().x})

func clip() -> void:
	var ps := _polys()
	if ps.is_empty():
		return
	var bb := Rect2(ps[0][0][0], Vector2.ZERO)
	for s in ps:
		for v in s[0]:
			bb = bb.expand(v)
	_clip = PackedVector2Array([bb.position, Vector2(bb.end.x, bb.position.y), bb.end, Vector2(bb.position.x, bb.end.y)])

# ------------------------------------------------------------------ rectangles and text

func fillRect(x: float, y: float, w: float, h: float) -> void:
	var p := PackedVector2Array([_xf * Vector2(x, y), _xf * Vector2(x + w, y), _xf * Vector2(x + w, y + h), _xf * Vector2(x, y + h)])
	_push_fill([p], fillStyle)

func strokeRect(x: float, y: float, w: float, h: float) -> void:
	var p := PackedVector2Array([_xf * Vector2(x, y), _xf * Vector2(x + w, y), _xf * Vector2(x + w, y + h), _xf * Vector2(x, y + h), _xf * Vector2(x, y)])
	cmds.append({"t": "line", "pts": p, "col": _color(strokeStyle), "w": lineWidth * _xf.get_scale().x})

func clearRect(x: float, y: float, w: float, h: float) -> void:
	var p := PackedVector2Array([_xf * Vector2(x, y), _xf * Vector2(x + w, y), _xf * Vector2(x + w, y + h), _xf * Vector2(x, y + h)])
	cmds.append({"t": "clear", "polys": [p]})

func fillText(text, x: float, y: float, max_width := -1.0) -> void:
	_text(str(text), x, y, max_width, fillStyle)

func strokeText(text, x: float, y: float, max_width := -1.0) -> void:
	_text(str(text), x, y, max_width, strokeStyle)

func measureText(text) -> Dictionary:
	var f := Canvas2D.font_of(font)
	var fnt: Font = f[0]
	var size: int = f[1]
	var w := fnt.get_string_size(str(text), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return {"width": w, "actualBoundingBoxAscent": size * 0.72, "actualBoundingBoxDescent": 0.0}

func _text(text: String, x: float, y: float, max_width: float, style) -> void:
	var f := Canvas2D.font_of(font)
	var fnt: Font = f[0]
	var size: int = f[1]
	var w := fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var sx := 1.0
	if max_width > 0.0 and w > max_width:
		sx = max_width / w
	var dx := 0.0
	match textAlign:
		"center": dx = -w * sx / 2.0
		"right", "end": dx = -w * sx
	var asc := fnt.get_ascent(size)
	var desc := fnt.get_descent(size)
	var by := y
	match textBaseline:
		"middle": by = y + (asc - desc) / 2.0
		"top", "hanging": by = y + asc
		"bottom", "ideographic": by = y - desc
	var xf := _xf * Transform2D(0.0, Vector2(sx, 1.0), 0.0, Vector2(x + dx, by))
	cmds.append({"t": "text", "text": text, "font": fnt, "size": size, "xf": xf, "col": _color(style)})

# ------------------------------------------------------------------ internals

func _push_fill(polys: Array, style) -> void:
	if _clip != null:
		var cl: Array = []
		for p in polys:
			for q in Geometry2D.intersect_polygons(p, _clip):
				cl.append(q)
		polys = cl
		if polys.is_empty():
			return
	if style is CanvasGrad:
		cmds.append({"t": "grad", "polys": polys, "g": style, "alpha": globalAlpha})
	else:
		cmds.append({"t": "fill", "polys": polys, "col": _color(style)})

func _color(style) -> Color:
	var c: Color = Canvas2D.css(style) if style is String else (style if style is Color else Color.BLACK)
	c.a *= globalAlpha
	return c

static func css(s: String) -> Color:
	s = s.strip_edges()
	if s.begins_with("#"):
		var h := s.substr(1)
		if h.length() == 3:
			h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2]
		return Color.html("#" + h)
	if s.begins_with("rgb"):
		var inner := s.substr(s.find("(") + 1).trim_suffix(")")
		var p := inner.split(",")
		var a := 1.0 if p.size() < 4 else float(p[3])
		return Color(float(p[0]) / 255.0, float(p[1]) / 255.0, float(p[2]) / 255.0, a)
	match s:
		"white": return Color.WHITE
		"black": return Color.BLACK
		"transparent": return Color(0, 0, 0, 0)
	return Color.MAGENTA

## [Font, pixel size] for a css font string like 'italic 800 84px "Barlow Condensed",sans-serif'
static func font_of(spec: String) -> Array:
	var size := 10
	var re := RegEx.create_from_string("(\\d+(?:\\.\\d+)?)px")
	var m := re.search(spec)
	if m:
		size = int(round(float(m.get_string(1))))
	var italic := spec.contains("italic")
	var weight := 400
	var rw := RegEx.create_from_string("\\b([1-9]00)\\b")
	var mw := rw.search(spec)
	if mw:
		weight = int(mw.get_string(1))
	elif spec.contains("bold"):
		weight = 700
	var barlow := spec.contains("Barlow") or not spec.contains("Nunito")
	var key := "%s/%s/%d" % ["barlow" if barlow else "nunito", italic, weight]
	if not _fonts.has(key):
		var f: Font
		if barlow:
			f = load("res://assets/fonts/BarlowCondensed-ExtraBoldItalic.ttf" if (italic or weight >= 800) else "res://assets/fonts/BarlowCondensed-Bold.ttf")
		else:
			var v := FontVariation.new()
			v.base_font = load("res://assets/fonts/Nunito-Variable.ttf")
			# keys are OpenType tags as ints (a String key would be read as an axis *name*, e.g. "weight")
			v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
			if italic:
				# Nunito has no italic: like a browser, slant it (oblique)
				v.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
			f = v
		_fonts[key] = f
	return [_fonts[key], size]

func _build_nodes(vp: SubViewport) -> void:
	# consecutive plain commands share one node; gradients and clears get their own (with a shader)
	var run: Array = []
	var flush_run := func() -> void:
		if run.is_empty():
			return
		var n := _Layer.new()
		n.items = run.duplicate()
		vp.add_child(n)
		run.clear()
	for c in cmds:
		if c.t == "grad" or c.t == "clear":
			flush_run.call()
			var n := _Layer.new()
			n.items = [c]
			n.material = (c.g as CanvasGrad).shader_material(c.alpha) if c.t == "grad" else _clear_material()
			vp.add_child(n)
		else:
			run.append(c)
	flush_run.call()

static var _unpremul_mat: ShaderMaterial
static func _unpremul_material() -> ShaderMaterial:
	if _unpremul_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nrender_mode blend_disabled;\nvoid fragment(){ vec4 c = texture(TEXTURE, UV); COLOR = c.a > 0.0 ? vec4(min(c.rgb / c.a, vec3(1.0)), c.a) : vec4(0.0); }\n"
		_unpremul_mat = ShaderMaterial.new()
		_unpremul_mat.shader = sh
	return _unpremul_mat

static var _clear_mat: ShaderMaterial
static func _clear_material() -> ShaderMaterial:
	if _clear_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nrender_mode blend_disabled;\nvoid fragment(){ COLOR = vec4(0.0); }\n"
		_clear_mat = ShaderMaterial.new()
		_clear_mat.shader = sh
	return _clear_mat

class _Layer extends Node2D:
	var items: Array = []
	func _draw() -> void:
		for c in items:
			match c.t:
				"fill":
					for p in c.polys:
						_poly(p, c.col)
				"grad", "clear":
					for p in c.polys:
						_poly(p, Color.WHITE)
				"line":
					draw_polyline(c.pts, c.col, maxf(c.w, 1.0), true)
				"text":
					draw_set_transform_matrix(c.xf)
					draw_string(c.font, Vector2.ZERO, c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, c.size, c.col)
					draw_set_transform_matrix(Transform2D.IDENTITY)
	func _poly(p: PackedVector2Array, col: Color) -> void:
		if p.size() < 3:
			return
		var tri := Geometry2D.triangulate_polygon(p)
		if tri.is_empty():
			draw_colored_polygon(p, col)
			return
		for i in range(0, tri.size(), 3):
			draw_colored_polygon(PackedVector2Array([p[tri[i]], p[tri[i + 1]], p[tri[i + 2]]]), col)

class CanvasGrad extends RefCounted:
	var radial := false
	var p0 := Vector2.ZERO
	var p1 := Vector2.ZERO
	var r0 := 0.0
	var r1 := 0.0
	var stops: Array = []
	func _init(rad: bool, a: Vector2, b: Vector2, ra: float, rb: float) -> void:
		radial = rad; p0 = a; p1 = b; r0 = ra; r1 = rb
	func addColorStop(off: float, c) -> void:
		stops.append([off, Canvas2D.css(c) if c is String else c])
	func shader_material(alpha: float) -> ShaderMaterial:
		var g := Gradient.new()
		var st := stops.duplicate()
		st.sort_custom(func(a, b): return a[0] < b[0])
		g.offsets = PackedFloat32Array(st.map(func(s): return s[0]))
		g.colors = PackedColorArray(st.map(func(s): return s[1]))
		var gt := GradientTexture1D.new()
		gt.gradient = g
		gt.width = 256
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
uniform sampler2D grad : filter_linear, repeat_disable;
uniform vec2 p0; uniform vec2 p1; uniform float r0; uniform float r1; uniform bool radial; uniform float alpha;
varying vec2 pos;
void vertex(){ pos = VERTEX; }
void fragment(){
	float t;
	if (radial) { t = (distance(pos, p1) - r0) / max(r1 - r0, 1e-4); }
	else { vec2 d = p1 - p0; t = dot(pos - p0, d) / max(dot(d, d), 1e-6); }
	vec4 c = texture(grad, vec2(clamp(t, 0.0, 1.0), 0.5));
	COLOR = vec4(c.rgb, c.a * alpha);
}
"""
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("grad", gt)
		m.set_shader_parameter("p0", p0)
		m.set_shader_parameter("p1", p1)
		m.set_shader_parameter("r0", r0)
		m.set_shader_parameter("r1", r1)
		m.set_shader_parameter("radial", radial)
		m.set_shader_parameter("alpha", alpha)
		return m

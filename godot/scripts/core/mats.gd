class_name Mats
## Materials like the HTML game's: M(color, opts) = MeshLambertMaterial, PM(...) = MeshPhongMaterial, basic = MeshBasicMaterial.
## All are LMat (one shader that lights the three.js way, see lmat.gd). Colours are JS hex ints (0xRRGGBB).
## Options use the three.js names:
##   map (Texture), repeat (Vector2: three texture.repeat), emissive (hex), emissiveMap (Texture), emissiveIntensity, transparent, opacity,
##   side ("double"/"back"), vertexColors, depthWrite, depthTest, fog (false = no fog), specular (hex), shininess,
##   flatShading, alphaTest, blending ("add" = THREE.AdditiveBlending).

static func _base(kind: int, c: int, o: Dictionary) -> LMat:
	var m := LMat.new()
	m._building = true
	m.kind = kind
	m.albedo_color = MathX.col(c)
	if o.has("map") and o.map != null:
		m.albedo_texture = o.map
		if o.has("repeat"):
			set_repeat(m, o.repeat)
	if o.get("vertexColors", false):
		m.vertex_color_use_as_albedo = true
	if o.has("emissiveMap") and o.emissiveMap != null:
		m.emission_texture = o.emissiveMap
	if o.has("emissive") and int(o.emissive) != 0:
		m.emission_enabled = true
		m.emission = MathX.col(o.emissive)
		m.emission_energy_multiplier = float(o.get("emissiveIntensity", 1.0))
	var op: float = o.get("opacity", 1.0)
	if o.get("transparent", false) or op < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = op
	if o.has("alphaTest"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = o.alphaTest
	match o.get("side", ""):
		"double": m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"back": m.cull_mode = BaseMaterial3D.CULL_FRONT
	if o.get("depthWrite", true) == false:
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if o.get("depthTest", true) == false:
		m.no_depth_test = true
	if o.get("blending", "") == "add":
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if o.get("fog", true) == false:
		m.disable_fog = true
	if o.get("flatShading", false):
		m.flat_shading = true
	if o.get("receiveShadow", false):
		m.receive_shadow = true
	if kind == LMat.Kind.PHONG:
		m.specular = MathX.col(o.get("specular", 0x111111))
		m.shininess = float(o.get("shininess", 30.0))
	m._building = false
	m._rebuild()
	return m

## three MeshLambertMaterial: diffuse only, no highlights
static func M(c: int, o: Dictionary = {}) -> LMat:
	return _base(LMat.Kind.LAMBERT, c, o)

## the HTML game's PM(c, o): MeshPhongMaterial with specular 0x3a3a3a, shininess 38 (cars)
static func PM(c: int, o: Dictionary = {}) -> LMat:
	var oo := {"specular": 0x3a3a3a, "shininess": 38.0}
	oo.merge(o, true)
	return _base(LMat.Kind.PHONG, c, oo)

## new THREE.MeshPhongMaterial({...}) itself (three's defaults: specular 0x111111, shininess 30)
static func phong(c: int, o: Dictionary = {}) -> LMat:
	return _base(LMat.Kind.PHONG, c, o)

## three MeshBasicMaterial: unlit
static func basic(c: int, o: Dictionary = {}) -> LMat:
	return _base(LMat.Kind.BASIC, c, o)

## three texture.repeat on a Godot material: Godot flips v (uv origin top-left), so the offset keeps the
## same texel rows where the JS version has them (three samples v*ry with flipY; Godot samples (1-v)*ry + 1-ry)
static func set_repeat(m: Material, rep: Vector2) -> void:
	m.uv1_scale = Vector3(rep.x, rep.y, 1.0)
	m.uv1_offset = Vector3(0.0, fposmod(1.0 - rep.y, 1.0), 0.0)

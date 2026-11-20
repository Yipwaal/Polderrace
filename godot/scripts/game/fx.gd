class_name Fx
extends Node3D
## Effects of the race: skid marks that fade, smoke / dust / spray / sparks, the headlights of the players' cars, the
## glow of every car's lamps with a soft shadow under it, and the rear-view mirror. One instance in the game scene
## (Fx.me). Game calls updateFx(dt), clearSkids(), clearParts(), attachCar(car); the HUD shows the mirror texture.
## Everything that moves is animated in a shader (age = now - birth): no work per particle per frame.

static var me: Fx

const SKID_MAX := 900
const PART_MAX := 320
var skids: MultiMeshInstance3D
var skid_mat: ShaderMaterial
var skidHead := 0
var skidCount := 0
var skidLast: Array = [null, null]
var parts: MultiMeshInstance3D
var part_mat: ShaderMaterial
var partHead := 0
var emitAcc := 0.0
var now := 0.0
## where player 1's headlights are (a marker on the car; hiding it switches the headlights off, see GarageRoom.stage)
var headL: Node3D
var head_k := 0.0
var mirror_vp: SubViewport
var mirror_cam: Camera3D
var carfx_mat: ShaderMaterial
var _scanT := 0.0
var _wallT := 0.0
var _gear := 1

## visual layer of the player's own car: the mirror camera leaves it out (JS hides the car while rendering the mirror)
const PLAYER_LAYER := 2

const SKID_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
global uniform vec4 pr_fog_range;
uniform float now = 0.0;
varying float v_a;
void vertex() {
	// custom: x = time it was laid, y = how dark
	v_a = INSTANCE_CUSTOM.y * (1.0 - smoothstep(10.0, 20.0, now - INSTANCE_CUSTOM.x));
}
void fragment() {
	float f = smoothstep(pr_fog_range.x, pr_fog_range.y, -VERTEX.z);
	ALBEDO = vec3(0.07, 0.07, 0.075);
	ALPHA = v_a * (1.0 - f) * smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x);
}
"""

## One MultiMesh of quads facing the camera. An instance's "transform" carries its numbers instead of a placement:
## origin = where it started, x axis = velocity, y axis = (size at birth, size at the end, gravity),
## z axis = (time of birth, life, kind: 0 smoke lit by the sky, 1 a spark that glows and streaks along its path).
const PART_SHADER := """
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled, skip_vertex_transform;
global uniform vec4 pr_hemi_sky;
global uniform vec4 pr_sun;
global uniform vec4 pr_fog;
global uniform vec4 pr_fog_range;
uniform sampler2D tex : filter_linear, repeat_disable;
uniform float now = 0.0;
varying vec4 v_col;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 vel = MODEL_MATRIX[0].xyz;
	vec3 sz = MODEL_MATRIX[1].xyz;
	vec3 tl = MODEL_MATRIX[2].xyz;
	float age = now - tl.x;
	float t = age / max(tl.y, 0.001);
	vec4 c = vec4(0.0);
	v_col = vec4(0.0);
	if (age >= 0.0 && t < 1.0) {
		vec3 p = o + vel * age;
		p.y -= 0.5 * sz.z * age * age;
		c = VIEW_MATRIX * vec4(p, 1.0);
		float s = mix(sz.x, sz.y, t);
		if (tl.z > 0.5) {
			vec3 v2 = mat3(VIEW_MATRIX) * (vel - vec3(0.0, sz.z * age, 0.0));
			vec2 dir = normalize(v2.xy + vec2(0.0001));
			c.xy += dir * (VERTEX.y * s * 5.0) + vec2(-dir.y, dir.x) * (VERTEX.x * s);
			v_col = vec4(COLOR.rgb * (COLOR.a * (1.0 - t * t)), 0.0);
		} else {
			c.xy += VERTEX.xy * s;
			float a = COLOR.a * (1.0 - t) * smoothstep(0.0, 0.08, t);
			float f = smoothstep(pr_fog_range.x, pr_fog_range.y, -c.z);
			vec3 light = pr_hemi_sky.rgb * 0.85 + pr_sun.rgb * 0.4;
			v_col = vec4(mix(COLOR.rgb * light, pr_fog.rgb, f) * a, a);
		}
	}
	VERTEX = c.xyz;
}
void fragment() {
	float k = texture(tex, UV).r;
	ALBEDO = v_col.rgb * k;
	ALPHA = v_col.a * k;
}
"""

## One mesh per car for its lights and its shadow: quads with uv = corner (-1..1), uv2 = (size, kind), colour.
##   kind 0: a glow that faces the camera (head and tail lamps), only seen from the side the lamp faces (normal)
##   kind 1: the lamp's streak on a wet road, from under the lamp towards the camera
##   kind 2: the soft shadow under the car (the vertex is the corner itself)
const CARFX_SHADER := """
shader_type spatial;
render_mode unshaded, blend_premul_alpha, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled, skip_vertex_transform;
global uniform vec4 pr_wet;
global uniform vec4 pr_fog_range;
uniform sampler2D tex : filter_linear, repeat_disable;
uniform float lamps = 0.0;
uniform float shadow = 1.0;
varying vec4 v_col;
varying float v_kind;
varying vec2 v_q;
void vertex() {
	vec3 wc = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec4 vc = VIEW_MATRIX * vec4(wc, 1.0);
	float d = max(-vc.z, 0.01);
	float fogk = 1.0 - smoothstep(pr_fog_range.x, pr_fog_range.y, d);
	v_q = UV;
	v_kind = 0.0;
	if (UV2.y > 1.5) {
		v_kind = 1.0;
		vc.xyz -= normalize(vc.xyz) * min(0.15, d * 0.2);
		v_col = vec4(0.0, 0.0, 0.0, COLOR.a * fogk * shadow);
	} else {
		vec3 nw = normalize(mat3(MODEL_MATRIX) * NORMAL);
		float on = lamps * COLOR.a * (0.25 + 0.75 * fogk) * smoothstep(-0.05, 0.45, dot(nw, normalize(cam - wc)));
		if (UV2.y < 0.5) {
			float s = max(UV2.x, d * 0.0055);
			vc.xyz -= normalize(vc.xyz) * min(0.3, d * 0.5);
			vc.xy += UV * (s * 0.5);
		} else {
			on *= pr_wet.x * fogk;
			vec2 dir = normalize(cam.xz - wc.xz + vec2(0.0001));
			vec3 p = wc + vec3(dir.x, 0.0, dir.y) * ((UV.y * 0.5 + 0.5) * UV2.x) + vec3(-dir.y, 0.0, dir.x) * (UV.x * 0.4);
			vc = VIEW_MATRIX * vec4(p, 1.0);
			vc.xyz -= normalize(vc.xyz) * min(0.12, d * 0.2);
		}
		if (on < 0.003) vc = vec4(0.0);
		v_col = vec4(COLOR.rgb * on, 0.0);
	}
	VERTEX = vc.xyz;
}
void fragment() {
	vec2 e = abs(v_q);
	float blob = (1.0 - smoothstep(0.45, 1.0, e.x)) * (1.0 - smoothstep(0.55, 1.0, e.y));
	float k = mix(texture(tex, v_q * 0.5 + 0.5).r, blob, v_kind);
	ALBEDO = v_col.rgb * k;
	ALPHA = v_col.a * k;
}
"""

func _init() -> void:
	me = self

func _exit_tree() -> void:
	if me == self: me = null

static func _smat(code: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = code
	return m

func _ready() -> void:
	# skid marks: a ring of SKID_MAX strips, each fading out by its own age
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	skid_mat = _smat(SKID_SHADER)
	mm.mesh = Geo.plane(0.3, 1).rotate_x(-PI / 2).to_mesh(skid_mat)
	mm.instance_count = SKID_MAX
	mm.visible_instance_count = 0
	skids = MultiMeshInstance3D.new()
	skids.multimesh = mm
	skids.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skids.custom_aabb = AABB(Vector3(-1e5, -1e3, -1e5), Vector3(2e5, 2e3, 2e5))
	add_child(skids)
	# particles
	part_mat = _smat(PART_SHADER)
	part_mat.set_shader_parameter("tex", puff_tex())
	var pm := MultiMesh.new()
	pm.transform_format = MultiMesh.TRANSFORM_3D
	pm.use_colors = true
	pm.mesh = Geo.plane(1, 1).to_mesh(part_mat)
	pm.instance_count = PART_MAX
	parts = MultiMeshInstance3D.new()
	parts.multimesh = pm
	parts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parts.custom_aabb = AABB(Vector3(-1e5, -1e3, -1e5), Vector3(2e5, 2e3, 2e5))
	add_child(parts)
	clearParts()
	carfx_mat = _smat(CARFX_SHADER)
	carfx_mat.set_shader_parameter("tex", Env.glow_tex())
	headL = Node3D.new()
	headL.visible = false
	# rear-view mirror: a second camera into the same world, rendered into a 512 x 150 texture
	mirror_vp = SubViewport.new()
	mirror_vp.size = Vector2i(512, 150)
	mirror_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	mirror_vp.msaa_3d = Viewport.MSAA_2X
	add_child(mirror_vp)
	mirror_cam = Camera3D.new()
	mirror_cam.fov = 46
	mirror_cam.near = 0.5
	mirror_cam.far = 1500
	mirror_cam.cull_mask = 0xFFFFF & ~(1 << (PLAYER_LAYER - 1))
	mirror_vp.add_child(mirror_cam)
	mirror_vp.world_3d = get_viewport().world_3d

## a soft, slightly lumpy puff (smoke, dust, spray)
static var _puff: ImageTexture
static func puff_tex() -> ImageTexture:
	if _puff == null:
		var S := 64
		var n := FastNoiseLite.new()
		n.seed = 5; n.frequency = 0.07
		var img := Image.create(S, S, false, Image.FORMAT_R8)
		for y in S:
			for x in S:
				var r := Vector2(x + 0.5 - S / 2.0, y + 0.5 - S / 2.0).length() / (S / 2.0)
				var v := clampf(1.0 - r, 0.0, 1.0)
				v = smoothstep(0.0, 0.75, v) * (0.78 + 0.22 * n.get_noise_2d(x, y))
				img.set_pixel(x, y, Color(clampf(v, 0.0, 1.0), 0, 0))
		_puff = ImageTexture.create_from_image(img)
	return _puff

## picture quality (Game.applyPrefs): the mirror gets cheaper on "low" and "mid"
func set_quality(q: String) -> void:
	mirror_vp.msaa_3d = Viewport.MSAA_DISABLED if q == "low" else Viewport.MSAA_2X
	mirror_cam.far = 600.0 if q == "low" else (900.0 if q == "mid" else 1500.0)

## put the headlight marker on the player's car (JS attachHeadlights) and the car on its own visual layer
func attachCar(car: Dictionary) -> void:
	if headL.get_parent() != null:
		headL.get_parent().remove_child(headL)
	car.g.add_child(headL)
	headL.position = Vector3(0, 0.8, 1.8)
	for gi in car.g.find_children("*", "VisualInstance3D", true, false):
		gi.layers = 1 << (PLAYER_LAYER - 1)

## Env.apply: headlights (night 1.5, dusk / rain / fog 0.85, day off) and the glow of the car lamps
func applyEnv(t: String, lamps: bool) -> void:
	head_k = 1.5 if t == "night" else (0.85 if lamps else 0.0)
	headL.visible = lamps
	carfx_mat.set_shader_parameter("lamps", 1.0 if t == "night" else (0.7 if lamps else 0.0))
	_push_heads()

## a stage scene (garage, podium): no headlights, no lamp glow (Env._set_lights)
func stage() -> void:
	carfx_mat.set_shader_parameter("lamps", 0.0)
	RenderingServer.global_shader_parameter_set("pr_head0", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("pr_head1", Vector4.ZERO)

## the players' headlights for LMat's shader (pr_head0 / pr_head1): position, brightness, direction, range
func _push_heads() -> void:
	var g := Game
	_head("pr_head0", g.car, head_k if (headL.visible and headL.is_inside_tree()) else 0.0)
	_head("pr_head1", g.p2.car if (g.split and g.p2 != null) else null, head_k)

func _head(pname: String, car, k: float) -> void:
	if car == null or k <= 0.0 or not is_instance_valid(car.g) or not car.g.is_inside_tree():
		RenderingServer.global_shader_parameter_set(pname, Vector4.ZERO)
		return
	var xf: Transform3D = car.g.global_transform
	var p := xf * Vector3(0, 0.8, 1.8)
	var d := (xf.basis * Vector3(0, -0.03, 1)).normalized()
	RenderingServer.global_shader_parameter_set(pname, Vector4(p.x, p.y, p.z, k))
	RenderingServer.global_shader_parameter_set(pname + "_dir", Vector4(d.x, d.y, d.z, 115.0))

# ------------------------------------------------------------------ car lights and shadow
## every vehicle on the road: the players' cars, bots, traffic and the cars of online players
func _cars() -> Array:
	var g := Game
	var out := []
	if g.car != null: out.append(g.car)
	if g.p2 != null and g.p2.car != null: out.append(g.p2.car)
	for b in g.bots: out.append(b.m)
	for c in g.traffic: out.append(c.m)
	if Net.net != null:
		for r in Net.net.get("remotes", {}).values():
			if r.get("car") is Dictionary: out.append(r.car)
	return out

## give every vehicle that has none yet its lights-and-shadow mesh (a child of the car, so it follows by itself)
func _scan_cars() -> void:
	for c in _cars():
		if not (c is Dictionary) or not c.has("g"): continue
		var g: Node3D = c.g
		if not is_instance_valid(g) or not g.is_inside_tree() or g.has_meta("carfx"): continue
		g.set_meta("carfx", true)
		var mi := _carfx_mesh(c)
		if mi != null: g.add_child(mi)

## the lamps of a car: the middle of the left and right part of every mesh that uses the lamp / tail-light material,
## in the car's own space; {"head": [...], "tail": [...]}
func _lamp_spots(c: Dictionary) -> Dictionary:
	var g: Node3D = c.g
	var inv := g.global_transform.affine_inverse()
	var hv := PackedVector3Array()
	var tv := PackedVector3Array()
	for mi in g.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null: continue
		for s in mi.mesh.get_surface_count():
			var mat = mi.get_surface_override_material(s)
			if mat == null: mat = mi.mesh.surface_get_material(s)
			var head: bool = mat == CarKit.lampMat
			var tail: bool = mat == CarKit.tailMat or (mat != null and mat == c.get("tail"))
			if not head and not tail: continue
			var xf: Transform3D = inv * mi.global_transform
			var vs = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			if vs == null: continue
			if head: hv.append_array(xf * (vs as PackedVector3Array))
			else: tv.append_array(xf * (vs as PackedVector3Array))
	return {"head": _spots(hv, 1.0), "tail": _spots(tv, -1.0)}

## left and right lamp (or one in the middle) at the front (dir 1) or back (dir -1) end of a cloud of lamp vertices
func _spots(vs: PackedVector3Array, dir: float) -> Array:
	if vs.is_empty(): return []
	var zend := -1e9
	for v in vs: zend = maxf(zend, v.z * dir)
	var sums := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var cnt := [0, 0, 0]
	for v in vs:
		if v.z * dir < zend - 0.5: continue
		var k := 0 if v.x < -0.2 else (2 if v.x > 0.2 else 1)
		sums[k] += v; cnt[k] += 1
	var out := []
	if cnt[0] > 0 and cnt[2] > 0:
		out.append(sums[0] / cnt[0]); out.append(sums[2] / cnt[2])
	else:
		var n: int = cnt[0] + cnt[1] + cnt[2]
		out.append((sums[0] + sums[1] + sums[2]) / n)
	for i in out.size():
		out[i].z = (zend + 0.02) * dir
	return out

func _carfx_mesh(c: Dictionary) -> MeshInstance3D:
	var V := PackedVector3Array(); var N := PackedVector3Array(); var U := PackedVector2Array(); var U2 := PackedVector2Array()
	var C := PackedColorArray(); var I := PackedInt32Array()
	var quad := func(pts: Array, n: Vector3, size: float, kind: float, col: Color) -> void:
		var o := V.size()
		for k in 4:
			V.append(pts[k]); N.append(n); U2.append(Vector2(size, kind)); C.append(col)
		U.append_array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
		I.append_array([o, o + 1, o + 2, o, o + 2, o + 3])
	var len: float = c.get("len", 4.4)
	var wid: float = c.get("wid", 1.9)
	var off: float = c.get("off", 0.0)
	# the shadow: a little wider and longer than the car, just above the road
	var hw := wid * 0.5 + 0.35
	var hl := len * 0.5 + 0.45
	quad.call([Vector3(-hw, 0.1, off - hl), Vector3(hw, 0.1, off - hl), Vector3(hw, 0.1, off + hl), Vector3(-hw, 0.1, off + hl)], Vector3.UP, 0.0, 2.0, Color(0, 0, 0, 0.5))
	var sp := _lamp_spots(c)
	var big := len > 6.0
	for p in sp.head:
		quad.call([p, p, p, p], Vector3(0, 0, 1), 1.9 if big else 1.5, 0.0, Color(1.0, 0.93, 0.74, 0.8))
		quad.call([Vector3(p.x, 0.1, p.z), Vector3(p.x, 0.1, p.z), Vector3(p.x, 0.1, p.z), Vector3(p.x, 0.1, p.z)], Vector3(0, 0, 1), 9.0, 1.0, Color(1.0, 0.93, 0.74, 0.3))
	for p in sp.tail:
		quad.call([p, p, p, p], Vector3(0, 0, -1), 1.05, 0.0, Color(1.0, 0.12, 0.06, 0.85))
		quad.call([Vector3(p.x, 0.1, p.z), Vector3(p.x, 0.1, p.z), Vector3(p.x, 0.1, p.z), Vector3(p.x, 0.1, p.z)], Vector3(0, 0, -1), 6.5, 1.0, Color(1.0, 0.1, 0.05, 0.45))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = V; arr[Mesh.ARRAY_NORMAL] = N; arr[Mesh.ARRAY_TEX_UV] = U; arr[Mesh.ARRAY_TEX_UV2] = U2
	arr[Mesh.ARRAY_COLOR] = C; arr[Mesh.ARRAY_INDEX] = I
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, carfx_mat)
	var mi := MeshInstance3D.new()
	mi.name = "CarFx"
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-hw - 9, -0.5, off - hl - 9), Vector3(hw * 2 + 18, 4, hl * 2 + 18))
	# on the car's own visual layer (the mirror leaves the player's car out)
	for gi in c.g.find_children("*", "VisualInstance3D", true, false):
		mi.layers = gi.layers
		break
	return mi

# ------------------------------------------------------------------ skid marks
func clearSkids() -> void:
	skidCount = 0; skidHead = 0; skidLast = [null, null]
	skids.multimesh.visible_instance_count = 0

func addSkid(k: int, p: Vector3, dark := 0.5) -> void:
	var l = skidLast[k]
	if l == null:
		skidLast[k] = p; return
	var dx: float = p.x - l.x
	var dz: float = p.z - l.z
	var d := sqrt(dx * dx + dz * dz)
	if d < 0.45: return
	if d > 4:
		skidLast[k] = p; return
	var xf := Transform3D(Basis(Vector3.UP, atan2(dx, dz)).scaled_local(Vector3(1, 1, d)), Vector3((p.x + l.x) / 2, (p.y + l.y) / 2 + 0.1, (p.z + l.z) / 2))
	skids.multimesh.set_instance_transform(skidHead, xf)
	skids.multimesh.set_instance_custom_data(skidHead, Color(now, dark, 0, 0))
	skidHead = (skidHead + 1) % SKID_MAX
	skidCount = mini(SKID_MAX, skidCount + 1)
	skids.multimesh.visible_instance_count = skidCount
	skidLast[k] = p

# ------------------------------------------------------------------ smoke, dust, spray, sparks
## a puff: colour (hex), size at birth (m), life (s), opacity, velocity, how many times bigger it ends
func emit(x: float, y: float, z: float, col: int, size: float, life: float, alpha: float, vx := 0.0, vy := 0.6, vz := 0.0, grow := 2.8) -> void:
	_put(Vector3(x, y, z), Vector3(vx, vy, vz), size, size * grow, 0.0, life, 0.0, Color(MathX.col(col), alpha))

## a spark: glows, falls, leaves a short streak
func spark(p: Vector3, v: Vector3, life := 0.45, size := 0.05, col := Color(1.0, 0.72, 0.3, 1.0)) -> void:
	_put(p, v, size, size * 0.4, 14.0, life, 1.0, col)

func _put(p: Vector3, v: Vector3, s0: float, s1: float, grav: float, life: float, kind: float, col: Color) -> void:
	parts.multimesh.set_instance_transform(partHead, Transform3D(Basis(v, Vector3(s0, s1, grav), Vector3(now, life, kind)), p))
	parts.multimesh.set_instance_color(partHead, col)
	partHead = (partHead + 1) % PART_MAX

func clearParts() -> void:
	var dead := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3(-1000, 0.001, 0)), Vector3.ZERO)
	for i in PART_MAX:
		parts.multimesh.set_instance_transform(i, dead)
		parts.multimesh.set_instance_color(i, Color(0, 0, 0, 0))

## world position of wheel k of the player's car (JS wheelWorld)
func wheelWorld(k: int) -> Vector3:
	var g := Game
	var lp: Vector3 = g.car.wheels[k].pivot.position
	var h: float = g.player.heading
	var c := cos(h); var s := sin(h)
	return Vector3(g.player.pos.x + c * lp.x + s * lp.z, g.player.y, g.player.pos.z - s * lp.x + c * lp.z)

func updateFx(dt: float) -> void:
	var g := Game
	now = g.clock
	skid_mat.set_shader_parameter("now", now)
	part_mat.set_shader_parameter("now", now)
	_scanT -= dt
	if _scanT <= 0.0:
		_scanT = 0.4
		_scan_cars()
	if not (g.state == "racing" or g.state == "finished") or g.car == null:
		_wallT = g.wallT; _gear = g.player.gear
		return
	var sk: float = g.skidAmount()
	for k in 2:
		if sk > 1.2: addSkid(k, wheelWorld(2 + k), clampf(0.22 + sk * 0.1, 0.3, 0.6))
		else: skidLast[k] = null
	var p: PlayerState = g.player
	var v := absf(p.speed)
	var fwd := Vector3(sin(p.heading), 0, cos(p.heading))
	# a scrape along the wall: sparks from the side that touches
	if g.wallT != _wallT:
		_wallT = g.wallT
		if v > 6 and g.fxOn():
			var sgn := 1.0 if p.lat > 0 else -1.0
			var side := Vector3(Trk.R[p.idx].x, 0, Trk.R[p.idx].z) * sgn
			var at: Vector3 = Vector3(p.pos.x, p.y + 0.45, p.pos.z) + side * (float(g.car.get("wid", 1.9)) * 0.5)
			for _i in 14:
				spark(at + fwd * (randf() - .3) * 1.6, fwd * v * (0.25 + randf() * 0.5) - side * (1 + randf() * 4) + Vector3(0, 1 + randf() * 3.5, 0), 0.25 + randf() * 0.35)
	# a flame from the exhaust when shifting up with the foot down
	if p.gear != _gear:
		if p.gear > _gear and p.gasIn > 0.8 and v > 12 and g.fxOn():
			var back: Vector3 = Vector3(p.pos.x, p.y + 0.38, p.pos.z) - fwd * (float(g.car.get("len", 4.4)) * 0.5 + 0.1)
			for _i in 3:
				_put(back + Vector3(randf() - .5, 0, randf() - .5) * 0.5, fwd * (v - 2 - randf() * 3), 0.16, 0.05, 0.0, 0.1 + randf() * 0.08, 1.0, Color(1.0, 0.55, 0.15, 0.9))
		_gear = p.gear
	emitAcc += dt
	if emitAcc < 0.045: return
	emitAcc = 0
	if G.prefs.get("quality", "high") == "low": return
	if sk > 1.6:
		for k in 2:
			var w := wheelWorld(2 + k)
			emit(w.x, p.y + 0.4, w.z, 0xdadada, 1.1, 1.1, minf(0.5, 0.12 + sk * 0.07), randf() - .5, 0.8, randf() - .5)
	# off the road on grass, sand or gravel: dust
	if v > 7 and g.surfaceDrag(absf(p.lat)) != null:
		for k in range(2, 4):
			var w := wheelWorld(k)
			emit(w.x, p.y + 0.3, w.z, 0xb49c74, 0.9, 0.9, minf(0.42, 0.14 + v / 120), (randf() - .5) * 2, 0.9 + randf() * 0.6, (randf() - .5) * 2, 3.0)
	# rain: spray behind the rear wheels
	if Env.me != null and Env.me.weather == "rain" and v >= 14:
		for k in range(2, 4):
			var w := wheelWorld(k)
			emit(w.x, p.y + 0.3, w.z, 0xc8ced6, 0.9, 0.7, minf(0.4, v / 150), (randf() - .5) * 1.5, 1.0, (randf() - .5) * 1.5, 2.2)

# ------------------------------------------------------------------ mirror (JS renderMirror)
func mirrorOn() -> bool:
	var g := Game
	return bool(G.prefs.get("mirror", true)) and not (g.split and g.p2 != null) and not g.paused and g.car != null and not Hud.lights.visible and (g.state == "racing" or g.state == "finished")

## once a frame after the cars and the camera have moved: the mirror camera and the headlights
func updateMirror() -> void:
	_push_heads()
	var on := mirrorOn()
	mirror_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if not on: return
	var p: PlayerState = Game.player
	var fx := sin(p.heading); var fz := cos(p.heading)
	mirror_cam.position = Vector3(p.pos.x + fx * 0.2, p.y + 1.45, p.pos.z + fz * 0.2)
	mirror_cam.look_at(Vector3(p.pos.x - fx * 40, p.y + 0.7, p.pos.z - fz * 40), Vector3.UP)

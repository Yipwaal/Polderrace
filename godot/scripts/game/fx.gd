class_name Fx
extends Node3D
## JS "fx: skid marks, smoke, spray" plus the headlight (headL) and the rear-view mirror: one instance in the game scene
## (Fx.me). Game calls updateFx(dt), clearSkids(), clearParts(); the HUD shows the mirror texture.

static var me: Fx

const SKID_MAX := 900
var skids: MultiMeshInstance3D
var skidHead := 0
var skidCount := 0
var skidLast: Array = [null, null]
var parts: Array = []
var partHead := 0
var emitAcc := 0.0
var smokeTex: ImageTexture
var headL: SpotLight3D
var mirror_vp: SubViewport
var mirror_cam: Camera3D

## visual layer of the player's own car: the mirror camera leaves it out (JS hides the car while rendering the mirror)
const PLAYER_LAYER := 2

func _init() -> void:
	me = self

func _ready() -> void:
	var sg := Geo.plane(0.3, 1).rotate_x(-PI / 2)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sg.to_mesh(Mats.basic(0x141414, {"transparent": true, "opacity": 0.5, "depthWrite": false}))
	mm.instance_count = SKID_MAX
	mm.visible_instance_count = 0
	skids = MultiMeshInstance3D.new()
	skids.multimesh = mm
	skids.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skids.extra_cull_margin = 16384
	add_child(skids)
	smokeTex = Canvas2D.tex(64, 64, func(g, _w, _h):
		var gr = g.createRadialGradient(32, 32, 2, 32, 32, 30)
		gr.addColorStop(0, "rgba(255,255,255,0.95)"); gr.addColorStop(1, "rgba(255,255,255,0)")
		g.fillStyle = gr; g.fillRect(0, 0, 64, 64))
	for _i in 90:
		var sp := Sprite3D.new()
		sp.texture = smokeTex
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.shaded = false
		sp.no_depth_test = false
		sp.pixel_size = 1.0 / 64.0
		sp.visible = false
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sp)
		parts.append({"sp": sp, "life": 0.0, "max": 1.0, "vx": 0.0, "vy": 0.0, "vz": 0.0, "s0": 1.0, "s1": 3.0, "a": 0.5})
	# JS headL: SpotLight(0xfff2d0, 0, 95, 0.5, 0.45, 1) on the player's car, aimed 30 m ahead
	headL = SpotLight3D.new()
	headL.light_color = MathX.col(0xfff2d0)
	headL.spot_range = 95
	headL.spot_angle = rad_to_deg(0.5)
	headL.spot_angle_attenuation = 1.6
	# three.js (decay 1, distance 95) fades linearly over 95 m; Godot's attenuation 1 would be 1/d (far too dark):
	# no distance decay, only Godot's range window, comes closest
	headL.spot_attenuation = 0.0
	headL.shadow_enabled = false
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

## attach the headlight to the player's car (JS attachHeadlights) and put the car on its own visual layer
func attachCar(car: Dictionary) -> void:
	if headL.get_parent() != null:
		headL.get_parent().remove_child(headL)
	car.g.add_child(headL)
	headL.position = Vector3(0, 0.9, 1.8)
	headL.look_at_from_position(Vector3(0, 0.9, 1.8), Vector3(0, 0, 30), Vector3.UP)
	for gi in car.g.find_children("*", "VisualInstance3D", true, false):
		gi.layers = 1 << (PLAYER_LAYER - 1)

## JS applyEnv: headL.intensity = night 2.4, lamps 1.2, day 0
func applyEnv(t: String, lamps: bool) -> void:
	headL.light_energy = 2.4 if t == "night" else (1.2 if lamps else 0.0)
	headL.visible = lamps

# ------------------------------------------------------------------ skid marks
func clearSkids() -> void:
	skidCount = 0; skidHead = 0; skidLast = [null, null]
	skids.multimesh.visible_instance_count = 0

func addSkid(k: int, p: Vector3) -> void:
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
	skidHead = (skidHead + 1) % SKID_MAX
	skidCount = mini(SKID_MAX, skidCount + 1)
	skids.multimesh.visible_instance_count = skidCount
	skidLast[k] = p

# ------------------------------------------------------------------ smoke & spray
func emit(x: float, y: float, z: float, col: int, size: float, life: float, alpha: float, vx := 0.0, vy := 0.6, vz := 0.0, grow := 2.8) -> void:
	var p: Dictionary = parts[partHead]
	partHead = (partHead + 1) % parts.size()
	var sp: Sprite3D = p.sp
	sp.position = Vector3(x, y, z)
	sp.modulate = Color(MathX.col(col), alpha)
	p.life = life; p.max = life; p.s0 = size; p.s1 = size * grow; p.a = alpha; p.vx = vx; p.vy = vy; p.vz = vz
	sp.visible = true
	sp.scale = Vector3.ONE * size

func clearParts() -> void:
	for p in parts:
		p.life = 0.0; p.sp.visible = false

func updateParts(dt: float) -> void:
	for p in parts:
		if p.life <= 0: continue
		p.life -= dt
		var sp: Sprite3D = p.sp
		if p.life <= 0:
			sp.visible = false; continue
		var t: float = 1 - p.life / p.max
		sp.position += Vector3(p.vx, p.vy, p.vz) * dt
		sp.scale = Vector3.ONE * (p.s0 + (p.s1 - p.s0) * t)
		sp.modulate.a = p.a * (1 - t)

## world position of wheel k of the player's car (JS wheelWorld)
func wheelWorld(k: int) -> Vector3:
	var g := Game
	var lp: Vector3 = g.car.wheels[k].pivot.position
	var h: float = g.player.heading
	var c := cos(h); var s := sin(h)
	return Vector3(g.player.pos.x + c * lp.x + s * lp.z, g.player.y, g.player.pos.z - s * lp.x + c * lp.z)

func updateFx(dt: float) -> void:
	updateParts(dt)
	var g := Game
	if not (g.state == "racing" or g.state == "finished") or g.car == null: return
	var sk: float = g.skidAmount()
	for k in 2:
		if sk > 1.2: addSkid(k, wheelWorld(2 + k))
		else: skidLast[k] = null
	emitAcc += dt
	if emitAcc < 0.045: return
	emitAcc = 0
	if G.prefs.get("quality", "high") == "low": return
	if sk > 1.6:
		for k in 2:
			var w := wheelWorld(2 + k)
			emit(w.x, g.player.y + 0.4, w.z, 0xdadada, 1.1, 1.1, minf(0.5, 0.12 + sk * 0.07), randf() - .5, 0.8, randf() - .5)
	# rain: spray behind the rear wheels
	if Env.me != null and Env.me.weather == "rain" and absf(g.player.speed) >= 14:
		for k in range(2, 4):
			var w := wheelWorld(k)
			emit(w.x, g.player.y + 0.3, w.z, 0xc8ced6, 0.9, 0.7, minf(0.4, absf(g.player.speed) / 150), (randf() - .5) * 1.5, 1.0, (randf() - .5) * 1.5, 2.2)

# ------------------------------------------------------------------ mirror (JS renderMirror)
func mirrorOn() -> bool:
	var g := Game
	return bool(G.prefs.get("mirror", true)) and not (g.split and g.p2 != null) and not g.paused and g.car != null and not Hud.lights.visible and (g.state == "racing" or g.state == "finished")

func updateMirror() -> void:
	var on := mirrorOn()
	mirror_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if not on: return
	var p: PlayerState = Game.player
	var fx := sin(p.heading); var fz := cos(p.heading)
	mirror_cam.position = Vector3(p.pos.x + fx * 0.2, p.y + 1.45, p.pos.z + fz * 0.2)
	mirror_cam.look_at(Vector3(p.pos.x - fx * 40, p.y + 0.7, p.pos.z - fz * 40), Vector3.UP)

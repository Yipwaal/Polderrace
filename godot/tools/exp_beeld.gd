extends Node3D
## Renderer experiments for the Beeld work (Compatibility renderer facts, measured instead of assumed):
##  1. draw calls of one mesh under a shadowed sun: shaded / shadows_disabled / unshaded material
##  2. WorldEnvironment glow / adjustments: do LMat colours stay the same?
##  3. screen-space AA (FXAA) and MSAA levels: accepted by the renderer?
##   godot/tools/beeld.sh exp_beeld out=/abs/dir

var out := "/tmp"

func px(x: int, y: int) -> Color:
	return get_viewport().get_texture().get_image().get_pixel(x, y)

func draws() -> int:
	return RenderingServer.viewport_get_render_info(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)

func wait(n := 3) -> void:
	for _i in n: await RenderingServer.frame_post_draw

func _ready() -> void:
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out": out = kv[1]
	DirAccess.make_dir_recursive_absolute(out)
	var env := Env.new()
	add_child(env)
	env.apply("day", "dry", true)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 6, 12)
	add_child(cam)
	cam.look_at(Vector3(0, 0.5, 0))
	cam.current = true
	env.update(0.0, cam)
	# a floor that receives shadows and a row of boxes
	var floor_m := Mats.M(0x6f9a3a, {"receiveShadow": true})
	var fl := O3.mesh(Geo.plane(60, 60), floor_m)
	O3.rot(fl, -PI / 2, 0, 0)
	add_child(fl)
	var boxes := []
	var bm := Mats.M(0xd04020)
	for i in 10:
		var b := O3.mesh(Geo.box(1, 2, 1), bm, -9 + i * 2, 1, 0, self, true)
		boxes.append(b)
	await wait(4)
	for b in boxes: b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await wait(4)
	print("EXP shaded boxes, not casting: draws ", draws())
	env.set_shadows(false)
	await wait(4)
	print("EXP shaded boxes, not casting, sun shadows off: draws ", draws())
	env.set_shadows(true)
	for b in boxes: b.visible = false
	await wait(4)
	print("EXP boxes hidden: draws ", draws())
	for b in boxes: b.visible = true
	await wait(4)
	print("EXP shaded boxes (LMat, no receive): draws ", draws(), " floor px ", px(640, 600), " box px ", px(600, 345))
	get_viewport().get_texture().get_image().save_png(out + "/exp_base.png")
	var un := ShaderMaterial.new()
	un.shader = Shader.new()
	un.shader.code = "shader_type spatial;\nrender_mode unshaded, fog_disabled;\nvoid fragment(){ ALBEDO = vec3(0.8, 0.25, 0.1); }"
	for b in boxes: b.material_override = un
	await wait(4)
	print("EXP unshaded boxes: draws ", draws(), " px ", px(600, 345))
	var sd := ShaderMaterial.new()
	sd.shader = Shader.new()
	sd.shader.code = "shader_type spatial;\nrender_mode shadows_disabled, fog_disabled, ambient_light_disabled;\nvoid fragment(){ ALBEDO = vec3(0.0); EMISSION = vec3(0.8, 0.25, 0.1); }"
	for b in boxes: b.material_override = sd
	await wait(4)
	print("EXP shadows_disabled boxes: draws ", draws(), " px ", px(600, 345))
	for b in boxes: b.material_override = null
	for b in boxes: b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	env.set_shadows(false)
	await wait(4)
	print("EXP no sun shadows: draws ", draws(), " floor px ", px(640, 600), " box px ", px(600, 345))
	env.set_shadows(true)
	await wait(4)
	# 2. glow
	var e := env.environment
	e.glow_enabled = true
	e.glow_intensity = 0.0
	await wait(4)
	print("EXP glow on, intensity 0: draws ", draws(), " floor px ", px(640, 600), " box px ", px(600, 345))
	e.glow_intensity = 0.8
	e.glow_hdr_threshold = 0.9
	await wait(4)
	print("EXP glow 0.8: floor px ", px(640, 600), " box px ", px(600, 345))
	get_viewport().get_texture().get_image().save_png(out + "/exp_glow.png")
	e.glow_enabled = false
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.0
	await wait(4)
	print("EXP adjustments on (neutral): floor px ", px(640, 600), " box px ", px(600, 345))
	e.adjustment_enabled = false
	await wait(4)
	# 3. AA
	var vp := get_viewport()
	for aa in [Viewport.SCREEN_SPACE_AA_FXAA, Viewport.SCREEN_SPACE_AA_SMAA if "SCREEN_SPACE_AA_SMAA" in Viewport else Viewport.SCREEN_SPACE_AA_FXAA]:
		vp.screen_space_aa = aa
		await wait(4)
		print("EXP screen_space_aa ", aa, ": floor px ", px(640, 600), " box px ", px(600, 345), " edge px ", px(632, 300), px(633, 300), px(634, 300))
		vp.get_texture().get_image().save_png(out + "/exp_ssaa%d.png" % aa)
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	for m in [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X]:
		vp.msaa_3d = m
		await wait(4)
		print("EXP msaa ", m, ": box px ", px(600, 345))
		vp.get_texture().get_image().save_png(out + "/exp_msaa%d.png" % m)
	vp.use_taa = true
	await wait(4)
	print("EXP taa: box px ", px(600, 345))
	get_tree().quit()

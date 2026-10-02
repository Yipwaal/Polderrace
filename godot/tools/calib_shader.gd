extends Node3D
## What does the Compatibility renderer do with shader outputs? Prints pixel values for EMISSION and light() outputs with
## and without a shadowed sun. The numbers behind emit()/dec() in lmat.gd. Run: xvfb-run -a godot --path godot --rendering-driver opengl3 res://tools/calib_shader.tscn

func px() -> Color:
	for _i in 3: await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	return img.get_pixel(20, 20) * 255

func _ready() -> void:
	var we := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR; we.environment = e; add_child(we)
	var cam := Camera3D.new(); cam.position = Vector3(0, 5, 0); add_child(cam); cam.look_at(Vector3(0, 0, 0.001)); cam.current = true
	var q := MeshInstance3D.new(); q.mesh = PlaneMesh.new(); q.mesh.size = Vector2(40, 40); add_child(q)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(-PI / 2, 0, 0); add_child(sun)
	for shadow in [false, true]:
		sun.shadow_enabled = shadow
		for code in ["render_mode ambient_light_disabled; void fragment(){ ALBEDO = vec3(0.0); } void light(){ SPECULAR_LIGHT += vec3(0.05); }",
				"render_mode ambient_light_disabled; void fragment(){ ALBEDO = vec3(0.0); } void light(){ SPECULAR_LIGHT += vec3(0.1); }",
				"render_mode ambient_light_disabled; void fragment(){ ALBEDO = vec3(0.0); } void light(){ SPECULAR_LIGHT += vec3(0.2); }",
				"render_mode ambient_light_disabled; void fragment(){ ALBEDO = vec3(0.0); EMISSION = vec3(0.2); } void light(){ SPECULAR_LIGHT += vec3(0.0); }",
				"render_mode ambient_light_disabled; void fragment(){ ALBEDO = vec3(0.0); } void light(){ SPECULAR_LIGHT += LIGHT_COLOR * 0.1; }"]:
			var sh := Shader.new(); sh.code = "shader_type spatial;\n" + code
			var m := ShaderMaterial.new(); m.shader = sh; q.material_override = m
			print("shadow ", shadow, " ", code.substr(80, 120), " -> ", await px())
	var sm := StandardMaterial3D.new(); sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; sm.albedo_color = Color(0.5, 0.5, 0.5)
	q.material_override = sm
	print("standard unshaded 0.5 -> ", await px())
	get_tree().quit()

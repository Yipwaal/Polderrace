class_name SplitView
extends CanvasLayer
## Split screen (2 players on one PC), the picture part of the JS split section (splitRender, splitHud, #hud2):
## two cameras into the same world, each rendered into its own half of the window, and player 2's HUD in the bottom half.
## The game logic (newP2, swapCtx, asP2, splitSetup, splitUpdate, collidePlayers) lives in Game.

static var me: SplitView

var vp1: SubViewport
var vp2: SubViewport
var cam1: Camera3D
var cam2: Camera3D
var img1: TextureRect
var img2: TextureRect
var hud2: Control
var sign2: Hud.SignBox
var t2: Label
var lapT2: Label
var map2: Hud.MiniMap
var gauge2: Hud.Gauge
var msg2: PanelContainer
var msg2_label: Label
var msg2Until := 0.0
var line: ColorRect
var _main_mask := 0

func _init() -> void:
	me = self

func _ready() -> void:
	layer = 1
	for k in 2:
		var vp := SubViewport.new()
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.msaa_3d = Viewport.MSAA_2X
		vp.world_3d = get_viewport().world_3d
		var cam := Camera3D.new()
		cam.near = 0.5; cam.far = 3000; cam.fov = 62
		vp.add_child(cam)
		add_child(vp)
		var img := TextureRect.new()
		img.texture = vp.get_texture()
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_SCALE
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.visible = false
		add_child(img)
		if k == 0: vp1 = vp; cam1 = cam; img1 = img
		else: vp2 = vp; cam2 = cam; img2 = img
	line = ColorRect.new()
	line.color = Color("#161a22")
	line.visible = false
	add_child(line)
	# player 2's HUD (JS #hud2): position sign, minimap, gauge, message
	hud2 = Control.new()
	hud2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud2.visible = false
	add_child(hud2)
	sign2 = Hud.SignBox.new()
	sign2.custom_minimum_size = Vector2(110, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	sign2.add_child(v)
	v.add_child(Hud.mk_label("SPELER 2", "800 11px Nunito", Hud.LAB))
	t2 = Hud.mk_label("1/2", "900 34px Nunito", Hud.SIGN_INK)
	v.add_child(t2)
	lapT2 = Hud.mk_label("", "800 14px Nunito", Hud.SIGN_INK)
	v.add_child(lapT2)
	hud2.add_child(sign2)
	var ms := Hud.SignBox.new(Vector4(8, 8, 8, 8))
	map2 = Hud.MiniMap.new()
	map2.p2 = true
	map2.custom_minimum_size = Vector2(92, 92)
	ms.add_child(map2)
	ms.name = "map2"
	hud2.add_child(ms)
	gauge2 = Hud.Gauge.new()
	gauge2.p2 = true
	gauge2.size = Vector2(132, 132)
	hud2.add_child(gauge2)
	msg2 = PanelContainer.new()
	msg2.mouse_filter = Control.MOUSE_FILTER_IGNORE    # CSS pointer-events:none
	msg2_label = Hud.mk_label("", "900 22px Nunito", Hud.INK)
	msg2.add_child(msg2_label)
	msg2.visible = false
	hud2.add_child(msg2)

func showMsg2(text: String, kind: String, dur: float) -> void:
	msg2_label.text = text
	msg2_label.add_theme_color_override("font_color", Color.WHITE if kind == "bad" else Hud.INK)
	msg2.add_theme_stylebox_override("panel", Hud.pill(Hud.ALERT if kind == "bad" else Hud.DETOUR))
	msg2.visible = true
	msg2Until = Game.clock + dur

func active() -> bool:
	var g := Game
	return g.split and g.p2 != null and g.state != "menu" and g.state != "replay"

## JS splitRender + splitHud, every frame
func tick(dt: float) -> void:
	var g := Game
	var on := active()
	var main_cam: Camera3D = g.camera
	img1.visible = on; img2.visible = on; line.visible = on; hud2.visible = on and (g.state == "racing" or g.state == "countdown" or g.state == "finished")
	vp1.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	vp2.render_target_update_mode = vp1.render_target_update_mode
	if not on:
		if _main_mask != 0:
			main_cam.cull_mask = _main_mask; _main_mask = 0
		return
	if _main_mask == 0:
		# the full-window camera draws nothing while the two halves are shown
		_main_mask = main_cam.cull_mask
		main_cam.cull_mask = 0
	var vp := get_viewport().get_visible_rect().size
	var h2 := vp.y / 2
	for v in [vp1, vp2]: v.size = Vector2i(int(vp.x), int(h2))
	img1.position = Vector2.ZERO; img1.size = Vector2(vp.x, h2)
	img2.position = Vector2(0, h2); img2.size = Vector2(vp.x, h2)
	line.position = Vector2(0, h2 - 1.5); line.size = Vector2(vp.x, 3)
	# player 1 looks through the main camera's pose; player 2's camera is placed by updateCamera as player 2
	cam1.global_transform = main_cam.global_transform; cam1.fov = main_cam.fov
	var save_t := main_cam.global_transform
	var save_f := main_cam.fov
	g.asP2(func(): g.updateCamera(0.0 if g.paused else 1.0 / 60))
	cam2.global_transform = main_cam.global_transform; cam2.fov = main_cam.fov
	main_cam.global_transform = save_t; main_cam.fov = save_f
	# player 2's HUD
	if hud2.visible:
		hud2.position = Vector2(0, h2)
		hud2.size = Vector2(vp.x, h2)
		sign2.position = Vector2(16, 16)
		var ms: Control = hud2.get_node("map2")
		ms.position = Vector2(vp.x - 16 - ms.size.x, 16)
		gauge2.position = Vector2(vp.x - 16 - gauge2.size.x, h2 - 10 - gauge2.size.y)
		msg2.position = Vector2((vp.x - msg2.size.x) / 2, h2 * 0.22)
		var pos: int = g.asP2(func(): return g.playerPosition())
		t2.text = "%d/%d" % [pos, g.bots.size() + 2]
		lapT2.text = "Ronde %d/%d" % [clampi(maxi(1, g.p2.pl.lap), 1, g.raceLaps), g.raceLaps]
		map2.queue_redraw()
		gauge2.queue_redraw()
		if msg2Until and g.clock > msg2Until:
			msg2.visible = false; msg2Until = 0
	if map2.pts.is_empty() or map2.get_meta("track", "") != Trk.TRACK_ID:
		map2.build(); map2.set_meta("track", Trk.TRACK_ID)

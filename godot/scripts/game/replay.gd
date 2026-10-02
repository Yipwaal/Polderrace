extends CanvasLayer
## Autoload "Rep": ghost time trial and replays (JS sections "ghost" and "replay"), plus the replay bar.
## Ghost: the best lap per track (+version, direction) and class is stored under polderrace3d-ghost-... like the HTML;
## a see-through car drives it again. Replay: every car's position 30 times a second; after the race you watch it with
## three cameras (behind, along the track, helicopter) and can save it as JSON.

const REP_CAMS := ["Achter de auto", "Langs de baan", "Helikopter"]

# ------------------------------------------------------------------ ghost
var ghostBest = null
var ghostCar = null
var ghostRec: Array = []
var ghostRecT := 0.0

func ghostKey(id: String, cls := "") -> String:
	return "polderrace3d-ghost-" + Game.tv(id) + "-" + (cls if cls != "" else Cars.CARS[G.settings.car].cls)

func relLap() -> float:
	var g := Game
	var rel := fposmod(g.player.s - Trk.S_START, Trk.TRACK_LEN)
	if g.raceTime - g.lapStart < 8 and rel > Trk.TRACK_LEN * 0.5: rel -= Trk.TRACK_LEN
	return rel

func ghostHide() -> void:
	if ghostCar != null: ghostCar.g.visible = false

func makeGhostModel() -> void:
	if ghostCar != null:
		ghostCar.g.queue_free(); ghostCar = null
	if ghostBest == null: return
	var m := CarKit.buildCar(ghostBest.car if Cars.CARS.has(str(ghostBest.get("car", ""))) else "gt", Color(ghostBest.get("color", "#ffffff")))
	# see-through: every material a transparent copy at 36 %, emissive halved
	for mi in m.g.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for k in mi.mesh.get_surface_count():
			var cur = mi.get_surface_override_material(k)
			if cur == null: cur = mi.mesh.surface_get_material(k)
			if cur is LMat:
				var c: LMat = cur.clone()
				c.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				c.albedo_color.a = 0.36
				c.albedo_color = c.albedo_color
				c.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
				c.emission = c.emission * 0.5
				mi.set_surface_override_material(k, c)
	m.g.visible = false
	get_tree().current_scene.add_child(m.g)
	ghostCar = m

func ghostStart() -> void:
	var s = G.store_get(ghostKey(Trk.TRACK_ID))
	ghostBest = JSON.parse_string(s) if s != null else null
	if not (ghostBest is Dictionary): ghostBest = null
	makeGhostModel()
	ghostRec = []; ghostRecT = 0

func ghostLapStart() -> void:
	ghostRec = []; ghostRecT = 0

func ghostRecord(dt: float) -> void:
	var g := Game
	if g.mode != "ghost" or g.player.lap < 1 or g.state != "racing": return
	ghostRecT -= dt
	if ghostRecT > 0: return
	ghostRecT = 0.08
	var t: float = g.raceTime - g.lapStart
	ghostRec.append_array([snappedf(t, 0.01), snappedf(relLap(), 0.1), snappedf(g.player.pos.x, 0.01), snappedf(g.player.y, 0.01), snappedf(g.player.pos.z, 0.01), snappedf(g.player.heading, 0.001)])

func ghostLapDone(lt: float) -> bool:
	var saved := false
	if ghostRec.size() > 60 and (ghostBest == null or lt < float(ghostBest.t)):
		ghostBest = {"t": snappedf(lt, 0.01), "car": G.settings.car, "color": G.settings.color, "d": ghostRec}
		G.store_set(ghostKey(Trk.TRACK_ID), JSON.stringify(ghostBest))
		makeGhostModel()
		saved = true
		Game.unlockAch("ghost")
		Hud.showToast("Nieuwe ghost: " + G.fmtLap(lt))
	ghostRec = []; ghostRecT = 0
	return saved

func ghostSample(key: int, val: float):
	var d: Array = ghostBest.d
	var n := d.size() / 6
	if n < 2: return null
	if val < d[key] or val > d[(n - 1) * 6 + key]: return null
	var lo := 0
	var hi := n - 1
	while hi - lo > 1:
		var m := (lo + hi) >> 1
		if d[m * 6 + key] <= val: lo = m
		else: hi = m
	return {"A": lo * 6, "B": hi * 6, "f": clampf((val - d[lo * 6 + key]) / maxf(1e-3, d[hi * 6 + key] - d[lo * 6 + key]), 0, 1)}

func ghostUpdate() -> void:
	if ghostCar == null: return
	var g := Game
	var on: bool = g.mode == "ghost" and g.player.lap >= 1 and g.state == "racing"
	if not on:
		ghostCar.g.visible = false; return
	var s = ghostSample(0, g.raceTime - g.lapStart)
	if s == null:
		ghostCar.g.visible = false; return
	var d: Array = ghostBest.d
	var A: int = s.A
	var B: int = s.B
	var f: float = s.f
	ghostCar.g.visible = true
	ghostCar.g.position = Vector3(d[A + 2] + (d[B + 2] - d[A + 2]) * f, d[A + 3] + (d[B + 3] - d[A + 3]) * f, d[A + 4] + (d[B + 4] - d[A + 4]) * f)
	ghostCar.g.rotation = Vector3(0, MathX.lerp_angle_(d[A + 5], d[B + 5], f), 0)

func ghostDelta():
	if ghostBest == null or Game.player.lap < 1: return null
	var s = ghostSample(1, relLap())
	if s == null: return null
	var d: Array = ghostBest.d
	return (Game.raceTime - Game.lapStart) - (d[s.A] + (d[s.B] - d[s.A]) * s.f)

# ------------------------------------------------------------------ replay
var replay = null
var repRec := 0.0
var rp = null                       ## playback state

func replayStart() -> void:
	var g := Game
	var cars := [{"id": G.settings.car, "color": G.settings.color, "name": "Speler 1" if g.split else "Jij"}]
	for b in g.bots: cars.append({"id": b.type, "color": b.color, "name": b.name})
	# online: the other players in this race, each in a fixed place of every frame (someone who leaves halfway keeps it)
	if Net.inRace():
		for r in Net.net.remotes.values():
			if r.car != null and Net.net.order.has(r.peer): cars.append({"id": r.carId, "color": r.color, "name": r.name, "peer": r.peer})
	replay = {"v": 1, "track": Trk.TRACK_ID, "time": Env.me.time if Env.me else "day", "weather": Env.me.weather if Env.me else "dry", "hz": 30, "cars": cars, "frames": []}
	repRec = 0

func replayRecord(dt: float) -> void:
	if replay == null or replay.frames.size() > 30 * 60 * 20: return
	repRec -= dt
	if repRec > 0: return
	repRec += 1.0 / replay.hz
	var g := Game
	var f := []
	var push := func(n: Node3D, v: float) -> void:
		f.append_array([snappedf(n.position.x, 0.01), snappedf(n.position.y, 0.01), snappedf(n.position.z, 0.01), snappedf(n.rotation.y, 0.001), snappedf(v, 0.1)])
	push.call(g.car.g, g.player.speed)
	for b in g.bots: push.call(b.m.g, 0.0 if b.out else b.speed)
	for c in replay.cars:
		if not c.has("peer"): continue
		var r = Net.net.remotes.get(c.peer) if Net.net != null else null
		if r != null and r.car != null and r.car.g.visible:
			push.call(r.car.g, r.st[4] if r.st != null else 0.0)
		else:
			# gone (left the game, back to the menu): stays where it was last seen
			var o := f.size()
			var last: Array = replay.frames.back() if not replay.frames.is_empty() else []
			f.append_array(last.slice(o, o + 4) + [0.0] if last.size() >= o + 5 else [0.0, -1000.0, 0.0, 0.0, 0.0])
	replay.frames.append(f)

func canReplay() -> bool:
	return replay != null and replay.frames.size() > 30

func replayOpen() -> void:
	if replay == null or replay.frames.size() < 10: return
	var g := Game
	var meshes := [g.car]
	for b in g.bots: meshes.append(b.m)
	for c in replay.cars:
		if not c.has("peer"): continue
		var r = Net.net.remotes.get(c.peer) if Net.net != null else null
		meshes.append(r.car if r != null else null)    # a player who left the game has no car any more: skipped
	# the podium makes way for the replay and comes back after it (JS: podiumArgs kept in rp.podium)
	var pa = Podium.podiumArgs
	Podium.leavePodium()
	rp = {"t": 0.0, "meshes": meshes, "target": 0, "camMode": 0, "camT": 0.0, "anchor": null, "speed": 0.0, "podium": pa}
	g.state = "replay"
	Menu.overOv.visible = false
	bar.visible = true
	for b in g.bots: b.m.g.visible = true
	for c in g.traffic: c.m.g.visible = false     # traffic is not recorded: hide it instead of leaving it frozen on the road
	if ghostCar != null: ghostCar.g.visible = false
	replayLabel()

func replayClose() -> void:
	if rp == null: return
	var pa = rp.get("podium")
	rp = null
	Game.state = "over"
	bar.visible = false
	Menu.overOv.visible = true
	if pa != null: Podium.enterPodium(pa.entries, pa.title)
	UiKit.focus(Menu.overUI.againBtn)
	for c in Game.traffic: c.m.g.visible = true

func replayClear() -> void:
	replay = null; rp = null
	if bar != null: bar.visible = false

## the next car the camera can follow (online, a player who left the game has no car: skipped)
func nextTarget(d: int) -> int:
	var n: int = rp.meshes.size()
	var t: int = rp.target
	for _i in n:
		t = (t + d + n) % n
		if rp.meshes[t] != null: return t
	return rp.target

func replayLabel() -> void:
	var c: Dictionary = replay.cars[rp.target]
	var n: int = rp.meshes.size()
	var pv: Dictionary = replay.cars[nextTarget(-1)]
	var nx: Dictionary = replay.cars[nextTarget(1)]
	info.text = "REPLAY · %s (%s) · %s" % [c.name, Cars.CARS[c.id].name if Cars.CARS.has(c.id) else "", REP_CAMS[rp.camMode]]
	prev_btn.text = "◀ " + pv.name
	next_btn.text = nx.name + " ▶"
	prev_btn.visible = n >= 2; next_btn.visible = n >= 2

func nearestIdx(x: float, z: float) -> int:
	var b := 1e12
	var bi := 0
	var i := 0
	while i < Trk.NS:
		var dx := x - Trk.P[i].x
		var dz := z - Trk.P[i].z
		var d := dx * dx + dz * dz
		if d < b: b = d; bi = i
		i += 2
	return bi

func replayUpdate(dt: float) -> void:
	var F: Array = replay.frames
	var n := F.size()
	var ft: float = rp.t * replay.hz
	var i := mini(n - 2, int(floor(ft)))
	var k := clampf(ft - i, 0, 1)
	rp.t += dt
	if rp.t * replay.hz >= n - 1:
		rp.t = 0.0; rp.anchor = null
	var a: Array = F[i]
	var b: Array = F[i + 1]
	for c in rp.meshes.size():
		var m = rp.meshes[c]
		if m == null: continue
		var o: int = c * 5
		if o >= a.size(): continue
		m.g.position = Vector3(a[o] + (b[o] - a[o]) * k, a[o + 1] + (b[o + 1] - a[o + 1]) * k, a[o + 2] + (b[o + 2] - a[o + 2]) * k)
		m.g.rotation = Vector3(0, MathX.lerp_angle_(a[o + 3], b[o + 3], k), 0)
		m.g.visible = true
		for w in m.wheels: w.spin.rotation.x += Game.wheelSpin(a[o + 4], w.r, dt)
	var ot: int = rp.target * 5
	rp.speed = a[ot + 4] + (b[ot + 4] - a[ot + 4]) * k if ot + 4 < a.size() else 0.0
	rp.camT += dt
	if rp.camT > 7:
		rp.camT = 0.0; rp.camMode = (rp.camMode + 1) % 3; rp.anchor = null; replayLabel()
	var cam := Game.camera
	var g: Node3D = rp.meshes[rp.target].g
	var p := g.position
	var h := g.rotation.y
	var fx := sin(h); var fz := cos(h)
	if rp.camMode == 0:
		cam.position = Vector3(p.x - fx * 7, p.y + 2.6, p.z - fz * 7)
		cam.look_at(Vector3(p.x + fx * 6, p.y + 0.8, p.z + fz * 6), Vector3.UP)
	elif rp.camMode == 2:
		cam.position = Vector3(p.x - fx * 18, p.y + 22, p.z - fz * 18)
		cam.look_at(p, Vector3.UP)
	else:
		if rp.anchor == null or rp.anchor.distance_to(p) > 70:
			var j := nearestIdx(p.x, p.z)
			var ta := Trk.trackAt(fmod(j * Trk.SPC + 45, Trk.TRACK_LEN))
			var sd := -1.0 if randf() < 0.5 else 1.0
			rp.anchor = Vector3(ta.px + ta.rx * sd * (Trk.SHOULDER + 4), Trk.HT[ta.i] + 3.2, ta.pz + ta.rz * sd * (Trk.SHOULDER + 4))
		cam.position = rp.anchor
		cam.look_at(Vector3(p.x, p.y + 0.8, p.z), Vector3.UP)
	cam.fov = 40 if rp.camMode == 1 else 58

func replaySave() -> void:
	if replay == null: return
	DirAccess.make_dir_recursive_absolute("user://replays")
	var name := "polderrace-replay-%s-%s.json" % [replay.track, Time.get_datetime_string_from_system().substr(0, 16).replace(":", "-").replace("T", "-")]
	var f := FileAccess.open("user://replays/" + name, FileAccess.WRITE)
	if f == null:
		Hud.showToast("Opslaan lukte niet"); return
	f.store_string(JSON.stringify(replay))
	f.close()
	Hud.showToast("Replay opgeslagen: " + ProjectSettings.globalize_path("user://replays/" + name))

# ------------------------------------------------------------------ replay bar (JS #replayBar)
var bar: PanelContainer
var info: Label
var prev_btn: Button
var next_btn: Button

func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	bar = PanelContainer.new()
	var st := Hud.pill(Color(0.086, 0.1, 0.133, 0.85), 24)
	st.content_margin_left = 14; st.content_margin_right = 14; st.content_margin_top = 12; st.content_margin_bottom = 12
	bar.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	bar.add_child(v)
	info = Hud.mk_label("", "800 15px Nunito", Color.WHITE)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	prev_btn = Hud.mk_button("◀ Auto", false)
	prev_btn.pressed.connect(func():
		if rp == null: return
		rp.target = nextTarget(-1); rp.anchor = null; replayLabel())
	next_btn = Hud.mk_button("Auto ▶", false)
	next_btn.pressed.connect(func():
		if rp == null: return
		rp.target = nextTarget(1); rp.anchor = null; replayLabel())
	var cam := Hud.mk_button("Camera", false)
	cam.pressed.connect(func():
		if rp == null: return
		rp.camMode = (rp.camMode + 1) % 3; rp.camT = 0.0; rp.anchor = null; replayLabel())
	var save := Hud.mk_button("Opslaan", false)
	save.pressed.connect(replaySave)
	var back := Hud.mk_button("Terug naar uitslag")
	back.pressed.connect(replayClose)
	for b in [prev_btn, next_btn, cam, save, back]: row.add_child(b)
	bar.visible = false
	add_child(bar)

func _process(_dt: float) -> void:
	if bar.visible:
		var vp := bar.get_viewport_rect().size
		bar.position = Vector2((vp.x - bar.size.x) / 2, vp.y - 16 - bar.size.y)

func _input(e: InputEvent) -> void:
	if rp != null and e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_ESCAPE or e.keycode == KEY_BACKSPACE):
		replayClose()
		get_viewport().set_input_as_handled()

extends Node3D
## Banen B's own quick tour (not committed): many views of one track in one process.
## godot --path godot res://tools/btour.tscn -- track=veluwe dir=fwd time=day weather=dry n=36 mode=chase out=/abs/dir [from=0 to=1] [views=x,y,z,lx,ly,lz;...]
## mode: chase (driver's chase camera), high (40 m up, behind), side (from 60 m beside the road, looking at it), back (looking back)

func _ready() -> void:
	get_tree().create_timer(900, true, false, true).timeout.connect(func(): print("ERROR tour timeout"); get_tree().quit(1))
	var a := {"track": "veluwe", "dir": "fwd", "time": "day", "weather": "dry", "n": "36", "mode": "chase", "out": "/tmp", "from": "0", "to": "1", "views": "", "fov": "64", "tag": "", "pts": "", "info": "", "around": ""}
	for s in OS.get_cmdline_user_args():
		var kv := s.split("=", true, 1)
		if kv.size() == 2: a[kv[0]] = kv[1]
	var env := Env.new()
	add_child(env)
	World.root = Node3D.new()
	World.root.name = "World"
	add_child(World.root)
	env.time = a.time; env.weather = a.weather
	TrackLoader.load_track(a.track, a.dir)
	var cam := Camera3D.new()
	cam.fov = float(a.fov); cam.near = 0.3; cam.far = 3000
	add_child(cam)
	cam.current = true
	env.apply(a.time, a.weather, true)
	await Canvas2D.flush(self)
	var views := []
	if a.info != "":
		print("INFO NS ", Trk.NS, " cps ", Trk.cps, " taken ", World.pavTaken.slice(0, 6))
		for b in BKit.bends(0.016): print("INFO bend ", b)
	if a.around != "":
		# x,z,r,h[;...]: four views of the spot (x, z) from r metres away, h above the ground there
		for ps in a.around.split(";"):
			var q := Array(ps.split(",")).map(func(x): return float(x))
			for k in 4:
				var ex: float = q[0] + cos(k * PI / 2 + 0.6) * q[2]; var ez: float = q[1] + sin(k * PI / 2 + 0.6) * q[2]
				views.append([Vector3(ex, Dress.groundY(ex, ez) + q[3], ez), Vector3(q[0], Dress.groundY(q[0], q[1]) + 4.0, q[1]), "a%d" % views.size()])
	elif a.pts != "":
		# i:lat:h:li:llat:lh  (camera at sample i, lateral lat, h above the road there; looking at sample li, lateral llat, lh above)
		for ps in a.pts.split(";"):
			var q := Array(ps.split(":")).map(func(x): return float(x))
			var i0 := int(q[0]) % Trk.NS; var i1 := int(q[3]) % Trk.NS
			var e2 := Trk.onTrack(i0, q[1]); var l2 := Trk.onTrack(i1, q[4])
			views.append([Vector3(e2[0], Trk.HT[i0] + q[2], e2[1]), Vector3(l2[0], Trk.HT[i1] + q[5], l2[1]), "p%d" % views.size()])
	elif a.views != "":
		for vs in a.views.split(";"):
			var v := Array(vs.split(",")).map(func(x): return float(x))
			views.append([Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5]), "v%d" % views.size()])
	else:
		var n := int(a.n)
		var NS := Trk.NS
		for k in n:
			var i := (Trk.START_I + int(round((float(a.from) + (float(a.to) - float(a.from)) * k / n) * NS))) % NS
			var p := Trk.P[i]; var t := Trk.T[i]; var r := Trk.R[i]
			var j := (i + 8) % NS
			var q := Trk.P[j]
			var b := (i - 3 + NS) % NS
			var pb := Trk.P[b]
			var e: Vector3; var l: Vector3
			match a.mode:
				"high":
					e = Vector3(p.x - t.x * 70, p.y + 45, p.z - t.z * 70); l = Vector3(p.x + t.x * 30, p.y, p.z + t.z * 30)
				"side":
					var sd := 1.0 if k % 2 else -1.0
					e = Vector3(p.x + r.x * 45 * sd, p.y, p.z + r.z * 45 * sd)
					e.y = maxf(p.y, Dress.groundY(e.x, e.z)) + 12
					l = Vector3(p.x, p.y + 1, p.z)
				"back":
					e = Vector3(q.x, q.y + 2.4, q.z); l = Vector3(pb.x, pb.y + 1.0, pb.z)
				"hood":
					e = Vector3(p.x, p.y + 1.15, p.z); l = Vector3(q.x, q.y + 0.9, q.z)
				_:
					e = Vector3(pb.x, pb.y + 2.5, pb.z); l = Vector3(q.x, q.y + 1.05, q.z)
					var need := maxf(0, Dress.groundY(e.x, e.z) + 1.7 - e.y)
					e.y += need
			views.append([e, l, "%04d" % i])
	var names := []
	for v in views:
		cam.position = v[0]
		cam.look_at(v[1])
		env.update(0.0, cam)
		for _i in 2:
			await RenderingServer.frame_post_draw
		var nm: String = "%s/%s%s_%s_%s_%s_%s_%s.png" % [a.out, a.tag, a.track, a.dir, a.time, a.weather, a.mode, v[2]]
		var img := get_viewport().get_texture().get_image()
		img.save_png(nm)
		names.append(nm)
	print("TOUR ", ",".join(names))
	get_tree().quit()

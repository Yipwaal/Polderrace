extends RefCounted
## scratch: time series of one manoeuvre (not part of the suites)
var H

func run(host: Node) -> TestReport:
	var r := TestReport.new("dbg")
	H = load("res://tests/handling_lib.gd").new()
	H.setup(host)
	var car := OS.get_environment("CAR")
	if car == "": car = "super"
	var what := OS.get_environment("WHAT")
	if what == "laps":
		for tr in OS.get_environment("TRACKS").split(","):
			var ks := OS.get_environment("KS").split(",", false)
			if ks.is_empty(): ks = PackedStringArray(["2.0", "1.8", "1.6", "1.4", "1.2", "1.0", "0.8"])
			for k in ks:
				var d: Dictionary = H.clean_lap(tr, car, float(k))
				print("D %s %s k=%s lap=%.2f walls=%d off=%.2f top=%.0f beta=%.0f" % [tr, car, k, d.lap, d.walls, d.off, d.top, d.beta])
		H.done()
		return r
	if what == "slow":
		# bots coming up on a slow player: on the racing line at 55 %, then parked on the line
		for tr in OS.get_environment("TRACKS").split(","):
			for diff in ["easy", "normal", "extreme"]:
				H.start(tr, car, "dry", "fwd", 7, diff, 3, "pole")
				H.countdown()
				var t := 0.0
				var log := []
				var c0 := 0
				while t < 60:
					var pl := Game.player
					var a := Trk.trackAt(pl.s + 12)
					var lt: float = Trk.LINE[a.i]
					var want := atan2(a.px + a.rx * lt - pl.pos.x, a.pz + a.rz * lt - pl.pos.z)
					var park := t > 35
					H.tick(clampf(-H.angDiff(want, pl.heading) * 3.5, -1, 1), 1.0 if (pl.speed < 28 and not park) else 0.0, 1.0 if park else 0.0)
					t += 1.0 / 120
					if Game.raceContacts != c0:
						c0 = Game.raceContacts
						var near: Mover = Game.bots[0]
						for b in Game.bots:
							if absf(Trk.wrapD(b.s - pl.s)) < absf(Trk.wrapD(near.s - pl.s)): near = b
						log.append("t=%.1f v=%.0f bot %s ds=%.1f dlat=%.1f bv=%.0f" % [t, pl.speed, near.name, Trk.wrapD(near.s - pl.s), near.lat - pl.lat, near.speed])
				print("D slow %s %s contacts=%d  %s" % [tr, diff, Game.raceContacts, str(log.slice(0, 6))])
		H.done()
		return r
	if what == "grid":
		for tr in OS.get_environment("TRACKS").split(","):
			for grid in ["back", "mid", "pole"]:
				H.start(tr, car, "dry", "fwd", 7, "normal", 2, grid)
				H.countdown()
				var c0 := 0
				var lat0: float = Game.player.lat
				for k in 4 * 120:
					H.tick(H.keep(lat0), 1, 0)
					if Game.raceContacts != c0:
						c0 = Game.raceContacts
						var pl := Game.player
						for b in Game.bots:
							if absf(Trk.wrapD(b.s - pl.s)) < 6: print("D grid %s %s t=%.2f pv=%.1f plat=%.2f bot %s ds=%.1f lat=%.2f gridLat=%.2f v=%.1f latV=%.2f" % [tr, grid, k / 120.0, pl.speed, pl.lat, b.name, Trk.wrapD(b.s - pl.s), b.lat, b.gridLat, b.speed, b.latV])
				print("D grid %s %s contacts=%d" % [tr, grid, Game.raceContacts])
		H.done()
		return r
	if what == "spin":
		H.start("haven", car); H.free_plane(); H.put(40, 0, 0, 30)
		Game.player.spin = 3.0
		var h0: float = Game.player.heading
		for k in 300:
			H.tick(0, 0, 0)
			var p := Game.player
			if k % 10 == 0: print("D t=%.2f turned=%.0f spin=%.2f yr=%.2f u=%.1f slide=%.1f beta=%.0f v=%.1f" % [k / 120.0, rad_to_deg(H.angDiff(p.heading, h0)), p.spin, p.yr, p.speed, p.slide.length(), rad_to_deg(H.beta()), H.v()])
		H.done()
		return r
	if what == "trace":
		var k := float(OS.get_environment("KS"))
		H.start(OS.get_environment("TRACKS"), car); Game.raceLaps = 99; H.countdown()
		var t := 0.0
		var n := 0
		var w0 := 0
		while t < 200 and Game.player.lap < 2:
			H.drive_step(k, false); t += 1.0 / 120; n += 1
			var p := Game.player
			var ev: bool = H.walls != w0
			w0 = H.walls
			if p.lap >= 1 and (ev or (n % 12 == 0 and (absf(H.beta()) > 0.12 or absf(p.lat) > Trk.ROAD_HALF))):
				print("D t=%.2f s=%.0f lat=%.1f v=%.0f beta=%.1f yr=%.2f sF=%.2f sR=%.2f steer=%.2f gas=%.1f brk=%.1f load=%.2f off=%.2f %s" % [t, p.s, p.lat, H.v() * 3.6, rad_to_deg(H.beta()), p.yr, p.slipF, p.slipR, p.steer, p.gasIn, p.brk, p.load, p.offroad, "WALL" if ev else ""])
		H.done()
		return r
	var v0 := float(OS.get_environment("V0")) if OS.get_environment("V0") != "" else 120.0
	H.start("haven", car); H.free_plane(); H.put(40, 0, 0, v0 / 3.6)
	var tv := v0 / 3.6
	if what != "power":
		for _k in int(3 * 120): H.tick(0.9, H.hold(tv), 0)
	for k in int((3.6 if what == "power" else 1.6) * 120):
		if what == "lift": H.tick(0.9, 0, 0)
		elif what == "power": H.tick(1.0, 1.0 if k < 300 else 0.0, 0)
		elif what == "hand": H.tick(1.0, 0, 0, k < 84)
		else: H.tick(0.9, 0, 1)
		if k % 6 == 0:
			var p := Game.player
			print("D t=%.2f v=%.1f u=%.1f yr=%.2f beta=%.1f sF=%.2f sR=%.2f wt=%.3f delta=%.3f steer=%.2f ax=%.1f" % [k / 120.0, H.v() * 3.6, p.speed, p.yr, rad_to_deg(H.beta()), p.slipF, p.slipR, p.wt, p.delta, p.steer, p.ax])
	H.done()
	return r

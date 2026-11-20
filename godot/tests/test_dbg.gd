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

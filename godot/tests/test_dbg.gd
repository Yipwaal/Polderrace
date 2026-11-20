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

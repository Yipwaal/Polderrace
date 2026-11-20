class_name AnimB
extends Node3D
## Decor that moves a little (boats, a tram, kites, flags): cheap, local, purely for looks (nothing collides with it,
## nothing is sent online; every player sees it at his own moment). It hangs under World.root, so loading another
## track frees it.
##   AnimB.shuttle(node, a, b, speed)   back and forth between two points, turning round at the ends (a boat)
##   AnimB.along(node, s0, s1, lat, y, speed)   along the track between two distances at a lateral offset (a tram)
##   AnimB.sway(node, amp_deg, period)   swings round its own y axis (a flag), and bobs `lift` m up and down (a kite, a buoy)
##   AnimB.spin(node, rate)   turns round its own z axis, rate in radians per second (a wind turbine rotor, a lighthouse beam
##                            when the node is turned so that its z points up)
##   AnimB.bob(node, offset, period)   moves to and fro along `offset` (surf rolling up the beach)

var kind := ""
var a := Vector3.ZERO
var b := Vector3.ZERO
var speed := 3.0
var t := 0.0
var dirn := 1.0
var s0 := 0.0
var s1 := 0.0
var lat := 0.0
var yoff := 0.0
var amp := 0.0
var period := 3.0
var lift := 0.0
var base := Transform3D.IDENTITY
var wait := 0.0

static func shuttle(n: Node3D, from: Vector3, to: Vector3, spd: float, phase := 0.0) -> AnimB:
	var m := AnimB.new()
	m.kind = "shuttle"; m.a = from; m.b = to; m.speed = spd
	m.t = clampf(phase, 0.0, 1.0) * from.distance_to(to)
	m.add_child(n)
	m._place()
	return m

static func along(n: Node3D, from_s: float, to_s: float, lateral: float, y: float, spd: float) -> AnimB:
	var m := AnimB.new()
	m.kind = "along"; m.s0 = from_s; m.s1 = to_s; m.lat = lateral; m.yoff = y; m.speed = spd
	m.add_child(n)
	m._place()
	return m

static func spin(n: Node3D, rate: float, phase := 0.0) -> AnimB:
	var m := AnimB.new()
	m.kind = "spin"; m.speed = rate; m.t = phase
	m.transform = n.transform
	m.base = n.transform
	n.transform = Transform3D.IDENTITY
	m.add_child(n)
	m._process(0.0)
	return m

static func bob(n: Node3D, offset: Vector3, per: float, phase := 0.0) -> AnimB:
	var m := AnimB.new()
	m.kind = "bob"; m.a = offset; m.period = per; m.t = phase
	m.transform = n.transform
	m.base = n.transform
	n.transform = Transform3D.IDENTITY
	m.add_child(n)
	return m

static func sway(n: Node3D, amp_deg: float, per: float, lift_m := 0.0, phase := 0.0) -> AnimB:
	var m := AnimB.new()
	m.kind = "sway"; m.amp = deg_to_rad(amp_deg); m.period = per; m.lift = lift_m; m.t = phase
	m.transform = n.transform
	m.base = n.transform
	n.transform = Transform3D.IDENTITY
	m.add_child(n)
	return m

func _process(dt: float) -> void:
	if kind == "spin":
		t += dt
		transform = base * Transform3D(Basis(Vector3.BACK, t * speed), Vector3.ZERO)
		return
	if kind == "bob":
		t += dt
		transform = Transform3D(base.basis, base.origin + a * sin(TAU * t / period))
		return
	if kind == "sway":
		t += dt
		var w := TAU * t / period
		transform = base * Transform3D(Basis(Vector3.UP, sin(w) * amp), Vector3(0, sin(w * 0.7) * lift, 0))
		return
	if wait > 0.0:
		wait -= dt
		return
	t += dt * speed * dirn
	var total := a.distance_to(b) if kind == "shuttle" else absf(s1 - s0)
	if t > total:
		t = total; dirn = -1.0; wait = 2.0
	elif t < 0.0:
		t = 0.0; dirn = 1.0; wait = 2.0
	_place()

func _place() -> void:
	if kind == "shuttle":
		var d := b - a
		var total := d.length()
		if total < 0.01: return
		position = a + d * (t / total)
		rotation.y = atan2(d.x, d.z) + (0.0 if dirn > 0 else PI)
	elif kind == "along":
		var sg := 1.0 if s1 >= s0 else -1.0
		var f := Trk.trackAt(s0 + sg * t)
		position = Vector3(f.px + f.rx * lat, lerpf(Trk.HT[f.i], Trk.HT[f.j], f.t) + yoff, f.pz + f.rz * lat)
		rotation.y = atan2(f.tx, f.tz) + (0.0 if dirn * sg > 0 else PI)

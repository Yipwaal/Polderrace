extends Node
## Autoload "Trk": the track state of the HTML game (computeTrack and the track queries).
## Same names as in polderrace-3d.html so ported code reads the same: Trk.P[i], Trk.R[i], Trk.hAt(i, lat), ...

const START_I := 6
const UP := Vector3.UP

var TRK: Dictionary = {}          ## the definition (TrackDefs.TRACKS[id])
var TRACK_ID := ""
var TRACK_DIR := "fwd"
var curve: CRCurve
var TRACK_LEN := 1.0
var NS := 1
var SPC := 2.0
var ROAD_HALF := 7.0
var SHOULDER := 9.0
var LANES: Array = [0.0]
var P := PackedVector3Array()     ## centre line points (y = road height)
var T := PackedVector3Array()     ## flat tangents
var R := PackedVector3Array()     ## right vectors
var HT := PackedFloat64Array()    ## road height
var EMB := PackedFloat64Array()   ## dike embankment width
var DIT := PackedFloat64Array()
var EDGE := PackedFloat64Array()  ## lateral distance of the wall / ditch
var CURV := PackedFloat64Array()
var LINE := PackedFloat64Array()  ## racing line (lateral offset)
var cps: Array[int] = []          ## checkpoint sample indices
var TS := PackedVector3Array()    ## every 3rd sample, for distToTrack
var TSi: Array[int] = []
var S_START := 0.0
var BX0 := 0.0
var BX1 := 0.0
var BZ0 := 0.0
var BZ1 := 0.0
## set by the terrain builders (Veluwe/Limburg): Callable(x, z) -> {h, d}
var terrain_fn: Callable = Callable()

static func dir_ctrl(ctrl: Array, dir: String) -> Array:
	if dir != "rev":
		return ctrl
	var out := [ctrl[0]]
	for k in range(ctrl.size() - 1, 0, -1):
		out.append(ctrl[k])
	return out

static func heading_of(t: Vector3) -> float:
	return atan2(t.x, t.z)

func compute_track(id: String, dir: String) -> void:
	var def: Dictionary = TrackDefs.TRACKS[id]
	TRK = def
	TRACK_ID = id
	TRACK_DIR = dir
	var pts := []
	for c in dir_ctrl(def.ctrl, dir):
		pts.append([float(c[0]), float(c[2]), float(c[1])])
	curve = CRCurve.new(pts, true)
	TRACK_LEN = curve.get_length()
	NS = int(round(TRACK_LEN / 2.0))
	SPC = TRACK_LEN / NS
	ROAD_HALF = def.roadHalf
	SHOULDER = def.shoulder
	LANES = def.lanes
	P.resize(NS); T.resize(NS); R.resize(NS)
	HT.resize(NS); EMB.resize(NS); DIT.resize(NS); EDGE.resize(NS)
	for i in NS:
		var u := float(i) / NS
		var p := curve.get_point_at(u)
		var t := curve.get_tangent_at(u)
		var tv := Vector3(t[0], 0.0, t[2]).normalized()
		var h: float = maxf(0.0, p[1])
		P[i] = Vector3(p[0], h, p[2])
		T[i] = tv
		R[i] = tv.cross(UP).normalized()
		HT[i] = h
		var e: float = h * def.embK
		EMB[i] = e
		DIT[i] = SHOULDER + e + 1.5
		EDGE[i] = SHOULDER + e + 2.1 if def.edge == "ditch" else float(def.edgeAt)
	CURV.resize(NS)
	for i in NS:
		var a := T[(i - 2 + NS) % NS]
		var b := T[(i + 2) % NS]
		CURV[i] = acos(clampf(a.x * b.x + a.z * b.z, -1.0, 1.0)) / (4.0 * SPC)
	S_START = START_I * SPC
	# racing line: towards the inside of each bend, smoothed twice with a 41-sample moving average
	var mo: float = maxf(1.0, ROAD_HALF - 1.8)
	var cur := PackedFloat64Array()
	cur.resize(NS)
	for i in NS:
		var a := T[(i - 3 + NS) % NS]
		var b := T[(i + 3) % NS]
		var cy := a.z * b.x - a.x * b.z
		cur[i] = -MathX.sgn(cy) * minf(1.0, CURV[i] * 60.0) * mo
	for _pass in 2:
		var out := PackedFloat64Array()
		out.resize(NS)
		var W := 20
		var sum := 0.0
		for k in range(-W, W + 1):
			sum += cur[(k + NS) % NS]
		for i in NS:
			out[i] = sum / (2 * W + 1)
			sum += cur[(i + W + 1) % NS] - cur[(i - W + NS) % NS]
		cur = out
	LINE.resize(NS)
	for i in NS:
		LINE[i] = clampf(cur[i], -mo, mo)
	TS = PackedVector3Array()
	TSi = []
	var i3 := 0
	while i3 < NS:
		TS.append(P[i3]); TSi.append(i3); i3 += 3
	BX0 = 1e9; BZ0 = 1e9; BX1 = -1e9; BZ1 = -1e9
	for p in P:
		BX0 = minf(BX0, p.x); BX1 = maxf(BX1, p.x); BZ0 = minf(BZ0, p.z); BZ1 = maxf(BZ1, p.z)
	BX0 -= 320; BX1 += 320; BZ0 -= 320; BZ1 += 320
	var step := int(round(def.cpM / SPC))
	cps = []
	var ci := START_I
	while ci < NS - step * 0.5:
		cps.append(ci); ci += step
	terrain_fn = Callable()

## road height at sample i, lateral offset lat (dike slopes down to 0 past the shoulder)
func hAt(i: int, lat: float) -> float:
	var a := absf(lat)
	var h := HT[i]
	var e := EMB[i]
	if a <= SHOULDER or TRK.get("terrain", false):
		return h
	if e > 0.0 and a < SHOULDER + e:
		return h * (1.0 - (a - SHOULDER) / e)
	return 0.0

## distance from (x,z) to the centre line minus the dike width there
func distToTrack(x: float, z: float) -> float:
	var b := 1e12
	var bi := 0
	for k in TS.size():
		var p := TS[k]
		var dx := x - p.x
		var dz := z - p.z
		var d := dx * dx + dz * dz
		if d < b:
			b = d; bi = k
	return sqrt(b) - EMB[TSi[bi]]

func randPos(rnd: Rng, minD: float):
	for _k in 40:
		var x := BX0 + rnd.next() * (BX1 - BX0)
		var z := BZ0 + rnd.next() * (BZ1 - BZ0)
		if distToTrack(x, z) >= minD:
			return [x, z]
	return null

func onTrack(i: int, lat: float) -> Array:
	return [P[i].x + R[i].x * lat, P[i].z + R[i].z * lat]

## interpolated track frame at distance s along the centre line (JS trackAt)
func trackAt(s: float) -> Dictionary:
	s = fposmod(s, TRACK_LEN)
	var f := s / SPC
	var i := int(floor(f)) % NS
	var j := (i + 1) % NS
	var t := f - floorf(f)
	return {"i": i, "j": j, "t": t,
		"px": P[i].x + (P[j].x - P[i].x) * t, "pz": P[i].z + (P[j].z - P[i].z) * t,
		"rx": R[i].x + (R[j].x - R[i].x) * t, "rz": R[i].z + (R[j].z - R[i].z) * t,
		"tx": T[i].x + (T[j].x - T[i].x) * t, "tz": T[i].z + (T[j].z - T[i].z) * t}

## signed distance along the loop, wrapped to (-L/2, L/2]
func wrapD(d: float) -> float:
	if d > TRACK_LEN / 2.0:
		return d - TRACK_LEN
	if d < -TRACK_LEN / 2.0:
		return d + TRACK_LEN
	return d

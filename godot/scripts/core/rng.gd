class_name Rng
## Port of the HTML game's random helpers. `seeded(s)` is the same LCG as the JS version
## (Math.imul(s,1664525)+1013904223 >>> 0), so a seeded track builds exactly the same decor.

var s: int = 0
var calls := 0                       ## number of next() calls (tests compare it with the HTML game)
var unseeded := false

static func seeded(seed: int) -> Rng:
	var r := Rng.new()
	r.s = seed & 0xFFFFFFFF
	return r

static func random() -> Rng:
	var r := Rng.new()
	r.unseeded = true
	return r

## next value in [0,1)
func next() -> float:
	if unseeded:
		return randf()
	calls += 1
	s = (s * 1664525 + 1013904223) & 0xFFFFFFFF
	return float(s) / 4294967296.0

func pick(a: Array):
	return a[int(floor(next() * a.size()))]

class_name TrackLoader
## JS loadTrack(id, dir): clear the world, compute the track, build it with the track's own seed (so every decor
## object lands where it does in the HTML game), then fog, clouds and environment. Builders not yet ported are skipped.
## A builder is a class with static build() and, when the JS has DETAILS[id], static details().

static var BUILDERS := {
	"polder": BuildPolder,
}

## builds the world of a track; returns the number of seeded rnd() calls per stage (for tests/test_build.gd)
static func build_world(id: String, dir: String) -> Dictionary:
	World.clear()
	World.pavTaken = []
	Trk.compute_track(id, dir)
	var rng := Rng.seeded(int(Trk.TRK.seed))
	World.rnd = rng
	var counts := {"build": 0, "details": 0, "veluwe": 0, "dress": 0}
	var b = BUILDERS.get(id)
	var c0 := rng.calls
	if b != null: b.build()
	counts.build = rng.calls - c0; c0 = rng.calls
	if b != null and b.has_method("details"): b.details()
	counts.details = rng.calls - c0; c0 = rng.calls
	if b != null and b.has_method("finish_details"): b.finish_details()
	counts.veluwe = rng.calls - c0; c0 = rng.calls
	Dress.dressTrack(id)
	counts.dress = rng.calls - c0
	World.rnd = Rng.random()
	return counts

static func load_track(id: String, dir := "fwd") -> void:
	if not TrackDefs.TRACKS.has(id): id = "polder"
	if dir != "rev": dir = "fwd"
	build_world(id, dir)
	if Env.me != null:
		Env.me.place_clouds()
		Env.me.apply(Env.me.time, Env.me.weather, true)

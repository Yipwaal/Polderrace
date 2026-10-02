class_name TrackLoader
## JS loadTrack(id, dir): clear the world, compute the track, build it with the track's own seed (so every decor
## object lands where it does in the HTML game), then fog, clouds and environment.
## A track's builder is res://scripts/track/builders/<id>.gd: a script with static build() (JS BUILDERS[id]) and
## optionally static details() (JS DETAILS[id]) and static finish_details() (JS finishVeluweDetails). No builder yet:
## the track is built without its own decor (road and dressing are missing too; only the shared dressing).

const TRACK_IDS := ["polder", "dorp", "circuit", "afsluitdijk", "haven", "veluwe", "grachten", "limburg", "rotterdam", "zeeland"]

static func builder(id: String):
	var path := "res://scripts/track/builders/%s.gd" % id
	return load(path) if ResourceLoader.exists(path) else null

## the tracks that have a builder
static func ported() -> Array:
	return TRACK_IDS.filter(func(id): return builder(id) != null)

## builds the world of a track; returns the number of seeded rnd() calls per stage (for tests/test_build.gd)
static func build_world(id: String, dir: String) -> Dictionary:
	World.clear()
	World.pavTaken = []
	Trk.terrain_fn = Callable()
	Trk.compute_track(id, dir)
	var rng := Rng.seeded(int(Trk.TRK.seed))
	World.rnd = rng
	var counts := {"build": 0, "details": 0, "veluwe": 0, "dress": 0}
	var b = builder(id)
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
	for m in World.lampMats:
		m.set_meta("base_emissive", m.emission if m.emission_enabled else Color.BLACK)
	return counts

static func load_track(id: String, dir := "fwd") -> void:
	if not TrackDefs.TRACKS.has(id): id = "polder"
	if dir != "rev": dir = "fwd"
	build_world(id, dir)
	World.batch()   # fewer draw calls, same picture (see World.batch)
	if Env.me != null:
		Env.me.place_clouds()
		Env.me.apply(Env.me.time, Env.me.weather, true)

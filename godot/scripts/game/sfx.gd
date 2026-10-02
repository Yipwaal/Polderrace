extends Node
## Autoload "Sfx": the game's sound, ported from the HTML game's audio section (ENG, getNoise, loopNoise, initAudio,
## updateAudio, tone, noise, toggleMute). Same graph, same numbers; no sample files, every sound is synthesised here.
##
## How, and why not sample by sample in GDScript: an AudioStreamGenerator filled from GDScript costs ~4 us per sample
## for this graph (about 9% of a fast core at 22 kHz, much more on an old laptop) and drops out whenever a frame hitches
## (loading a track). So the waves are synthesised once into looping AudioStreamWAVs and Godot's own mixer (C++, on the
## audio thread) plays, pitches, filters and mixes them; GDScript only moves the parameters once per frame.
## - engine (JS engA + engB at half gain, through engF): the main wave and the sub-octave square keep a fixed frequency
##   ratio, so one band-limited wave table per class holds both; it plays at pitch_scale = f * sub / F_REF on bus
##   "SfxEngine", whose AudioEffectLowPassFilter is the same RBJ biquad as Web Audio's lowpass (Godot's resonance is the
##   linear Q; Web Audio gives a lowpass/highpass Q in dB, so Q 4 -> 10^(4/20)). Checked by test `audio`.
## - wind, squeal, rain (JS loopNoise): their filters never move, so the two seconds of noise are filtered once with
##   Web Audio's biquad formulas (cyclically, so the loop has no seam); only the gain follows the game.
## - nearest bot (JS botA through bf): a band-limited sawtooth table, pitched, on bus "SfxBot" (lowpass 900 Hz).
## - tone() / noise(): rendered sample-exact (exponential ramps, the falling lowpass of noise) into a short
##   AudioStreamWAV, cached, and started on an AudioStreamPolyphonic voice pool; tone()'s delay is silence in front.
## - setTargetAtTime(v, t, tau): every frame cur = v + (cur - v) * exp(-dt / tau), dt = real time since the last frame
##   (like the AudioContext clock); Godot ramps volumes and filter coefficients over each mix block.
## - master gain 0.6 = the volume of bus "Sfx", which sends to Master. Oscillator waves are band-limited and
##   peak-normalised like Chrome's built-in OscillatorNode types.
## - the waves (~0.1 s of GDScript) are rendered on a worker thread when initAudio runs at the first race start.
## Cost (test `audio`): updateAudio ~20 us per frame; Godot's mixer well under 1% of a core for all loops.
## The settings menu (JS applyPrefs) sets `Sfx.muted = not G.prefs.sound`; the mute button listens to mute_changed.

signal mute_changed(muted: bool)

## JS ENG: per class the engine's base frequency, rpm range, main wave and the sub-octave square's frequency ratio
const ENG := {"B": {"base": 66, "mul": 125, "type": "square", "sub": 0.5},
	"A": {"base": 36, "mul": 82, "type": "sawtooth", "sub": 0.5},
	"S": {"base": 58, "mul": 160, "type": "sawtooth", "sub": 0.25}}
const MASTER_GAIN := 0.6
const RATE := 44100              ## wave tables, the rain loop and tone()
const LOW_RATE := 22050          ## noise() and the wind/squeal loops: their filters leave nothing above 11 kHz
const TAB := 2048                ## samples per cycle of the engine and bot wave tables
const F_REF := float(RATE) / TAB ## a table at pitch_scale 1 sounds at this frequency
const BAND := 18000.0            ## oscillators are band-limited to this (Hz)
const NOISE_SEC := 2.0           ## JS getNoise: two seconds of white noise
const GIBBS := 1.17898           ## peak of a full-band square/sawtooth: Chrome normalises its oscillators to peak 1
const SILENT := 1e-5             ## a loop quieter than this is paused (inaudible; saves the mixer the work)
const GUARD := 4                 ## samples copied around a loop so Godot's interpolation reads the wrapped neighbours
const BUS := "Sfx"
const BUS_ENGINE := "SfxEngine"
const BUS_BOT := "SfxBot"
## the beeps of a race, rendered in initAudio so the first one costs nothing (gear shift, countdown, GO, time trial, lap)
const WARM := [[170, 0.06, "triangle", 0.05, 0.0], [440, 0.16, "square", 0.09, 0.0], [880, 0.35, "square", 0.1, 0.0],
	[1250, 0.05, "square", 0.08, 0.0], [880, 0.14, "triangle", 0.16, 0.0], [1320, 0.26, "triangle", 0.16, 0.12]]

var muted := false
var actx := false                ## JS actx: initAudio has run
var initMs := 0.0                ## how long initAudio took (main thread)
var buildMs := 0.0               ## how long rendering the waves took (worker thread)
var engType := ""                ## the class whose table the engine plays (JS engType)

var engP: AudioStreamPlayer          ## JS engA + engB (+ bg 0.5)
var engF: AudioEffectLowPassFilter   ## JS engF (bus SfxEngine)
var windP: AudioStreamPlayer         ## JS windG
var squealP: AudioStreamPlayer       ## JS squealG
var rainP: AudioStreamPlayer         ## JS rainG
var botP: AudioStreamPlayer          ## JS botA -> bf -> botG (bus SfxBot)
var oneP: AudioStreamPlayer          ## tone() and noise() voices
var engTabs := {}                    ## class -> AudioStreamWAV

## the smoothed AudioParams (JS setTargetAtTime targets): Hz and linear gains, starting at the Web Audio defaults
var engFreq := 440.0
var engCut := 700.0
var engGain := 0.0
var windGain := 0.0
var squealGain := 0.0
var rainGain := 0.0
var botFreq := 440.0
var botGain := 0.0

var _t := -1                         ## Time.get_ticks_usec() of the previous updateAudio
var _noise := {}                     ## rate -> PackedFloat32Array (JS noiseBuf)
var _waves := {}                     ## "type|freq" -> one band-limited cycle for tone()
var _tones := {}                     ## tone() samples by their arguments
var _bursts := {}                    ## noise() samples by their (rounded) arguments
var _poly: AudioStreamPlaybackPolyphonic
var _queue: Array = []               ## [stream, volume_db] waiting for _flush
var _task := -1                      ## WorkerThreadPool task rendering the waves
var _built := {}                     ## the loops it made

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # the AudioContext keeps running while the game is paused
	muted = not bool(G.prefs.get("sound", true))

# ================================================================== JS audio section
## Buses and players now; the waves are rendered on a worker thread (~0.1 s of GDScript), so the race start does not
## hitch. updateAudio picks them up when they are done (a frame or a few later); tone()/noise() wait for them.
func initAudio() -> void:
	if actx: return
	actx = true
	var t0 := Time.get_ticks_usec()
	AudioServer.set_bus_volume_db(_bus(BUS, "Master"), linear_to_db(MASTER_GAIN))
	engF = AudioEffectLowPassFilter.new()
	engF.cutoff_hz = engCut
	engF.resonance = pow(10.0, 4 / 20.0)
	AudioServer.add_bus_effect(_bus(BUS_ENGINE, BUS), engF)
	var bf := AudioEffectLowPassFilter.new()
	bf.cutoff_hz = 900
	bf.resonance = pow(10.0, 1 / 20.0)   # the default Q (1 dB)
	AudioServer.add_bus_effect(_bus(BUS_BOT, BUS), bf)
	engP = _player(BUS_ENGINE)
	windP = _player(BUS)
	squealP = _player(BUS)
	rainP = _player(BUS)
	botP = _player(BUS_BOT)
	oneP = AudioStreamPlayer.new()
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = 32
	oneP.stream = poly
	oneP.bus = BUS
	add_child(oneP)
	_task = WorkerThreadPool.add_task(_build, false, "Sfx: golven")
	initMs = (Time.get_ticks_usec() - t0) / 1000.0

## (worker thread) every wave; nothing else touches these fields until wavesReady() has taken them over
func _build() -> void:
	var t0 := Time.get_ticks_usec()
	for c in ENG:
		engTabs[c] = _wav(_engineCycle(ENG[c]), RATE, true)
	var saw := {}
	for k in range(1, int(BAND / (180 * 1.1)) + 1):
		saw[k] = _coef("sawtooth", k)
	_built = {"wind": loopNoise("bandpass", 900, 0.6, LOW_RATE), "squeal": loopNoise("bandpass", 2600, 5, LOW_RATE),
		"rain": loopNoise("highpass", 1600, 0.4, RATE), "bot": _wav(_cycle(TAB, saw), RATE, true)}
	for a in WARM:
		_toneWav(a[0], a[1], a[2], a[3], a[4])
	buildMs = (Time.get_ticks_usec() - t0) / 1000.0

## true once the waves are rendered and playing (wait: block until they are)
func wavesReady(wait := false) -> bool:
	if _task < 0: return actx
	if not wait and not WorkerThreadPool.is_task_completed(_task): return false
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_start(windP, _built.wind)
	_start(squealP, _built.squeal)
	_start(rainP, _built.rain)
	_start(botP, _built.bot)
	_built = {}
	return true

## JS updateAudio, once per frame (also when paused). gearInfo() and skidAmount() live in Game: the HUD and the fx
## use them too.
func updateAudio() -> void:
	if not wavesReady(): return
	var now := Time.get_ticks_usec()
	var dt := 0.0 if _t < 0 else (now - _t) / 1e6
	_t = now
	var g := Game
	var pl: PlayerState = g.player
	var st: String = g.state
	# in a replay the engine follows the car the camera is on: speed from the recording, gears from a simple ratio
	# ladder (Rep.rp / Rep.replay, the replay port's playback state)
	var rep := false
	var rc: Dictionary = {}
	var rv := absf(pl.speed)
	if st == "replay":
		var rp = Rep.rp
		var replay = Rep.replay
		if rp != null and replay != null:
			rep = true
			rc = Cars.CARS.get(replay.cars[rp.target].id, Cars.CARS[G.settings.car])
			rv = absf(float(rp.speed)) if rp.speed != null else 0.0
	var sp: float = rv / ((float(rc.vmax) / 3.6) if rep else g.MAXV)
	var cls: String = rc.cls if rep else Cars.CARS[G.settings.car].cls
	var e: Dictionary = ENG[cls]
	var rpm: float
	if rep:
		var gr := mini(5, int(floor(sp * 5.2)))
		var lo := gr / 5.2
		var hi := (gr + 1) / 5.2
		rpm = 0.12 if sp < 0.01 else 0.28 + 0.62 * clampf((sp - lo) / (hi - lo), 0, 1)
	else:
		rpm = g.gearInfo().rpm
	if engType != cls:
		engType = cls
		_start(engP, engTabs[cls])
	var f: float = e.base * 0.85 + rpm * e.mul * 1.25
	engFreq = _target(engFreq, f, dt, 0.04)
	engCut = _target(engCut, 500 + sp * 1600, dt, 0.1)
	var on: bool = (st == "racing" or st == "countdown" or st == "finished" or rep) and not g.paused and not muted
	engGain = _target(engGain, (0.05 + sp * 0.05) if on else 0.0, dt, 0.08)
	windGain = _target(windGain, (pow(rv / 80, 2) * 0.22 + absf(g.windX) * 0.008) if on else 0.0, dt, 0.15)
	squealGain = _target(squealGain, clampf((g.skidAmount() - 0.8) * 0.03, 0, 0.11) if on else 0.0, dt, 0.05)
	var rain := Env.me != null and Env.me.weather == "rain"
	var inGarage = g.get("inGarage")
	rainGain = _target(rainGain, ((0.035 if st == "menu" else 0.06) if not muted and not g.paused and inGarage != true and rain else 0.0), dt, 0.3)
	var nb: Mover = null
	var nd := 45.0
	if on and not rep:
		for b: Mover in g.bots:
			var p: Vector3 = b.m.g.position
			var d := Vector2(p.x - pl.pos.x, p.z - pl.pos.z).length()
			if d < nd:
				nd = d; nb = b
	if nb != null:
		botFreq = _target(botFreq, 40 + clampf(nb.speed / nb.vmax if nb.vmax > 0 else 0.0, 0, 1) * 140, dt, 0.05)
		botGain = _target(botGain, 0.045 * (1 - nd / 45), dt, 0.1)
	else:
		botGain = _target(botGain, 0, dt, 0.1)
	# hand the values to Godot's mixer
	engP.pitch_scale = engFreq * e.sub / F_REF
	engF.cutoff_hz = engCut
	botP.pitch_scale = botFreq / F_REF
	_vol(engP, engGain)
	_vol(windP, windGain)
	_vol(squealP, squealGain)
	_vol(rainP, rainGain)
	_vol(botP, botGain)

## JS tone(freq, dur, type, vol, delay): an oscillator whose gain falls exponentially from vol to 0.0001 in dur seconds
func tone(freq: float, dur: float, type := "sine", vol := 0.15, delay := 0.0) -> void:
	if not actx or muted: return
	wavesReady(true)
	if type == "": type = "sine"
	if vol == 0: vol = 0.15
	_play(_toneWav(freq, dur, type, vol, delay), vol)

## JS noise(dur, vol, freq): a burst of the noise through a lowpass falling from freq to max(80, freq * 0.2), gain from
## vol to 0.0001
func noise(dur: float, vol: float, freq: float) -> void:
	if not actx or muted: return
	wavesReady(true)
	# the hits of a race (hitFx: all three follow the impulse) share a handful of samples; the rounding is inaudible
	var qd := maxf(0.01, snappedf(dur, 0.01))
	var qv := maxf(0.01, snappedf(vol, 0.02))
	var qf := maxf(20.0, snappedf(freq, 20))
	var key := "%s|%s|%s" % [qd, qv, qf]
	var w: AudioStreamWAV = _bursts.get(key)
	if w == null:
		if _bursts.size() >= 64: _bursts.clear()
		w = _renderNoise(qd, qv, qf)
		_bursts[key] = w
	_play(w, vol)

func toggleMute() -> void:
	muted = not muted
	G.prefs.sound = not muted
	G.savePrefs()
	mute_changed.emit(muted)

## JS getNoise: two seconds of white noise (a fixed seed: the same every run, and the game's randf() is left alone).
## At half rate the mean of each pair keeps the noise density, so a filter gives the same level as at full rate.
func getNoise(rate: int) -> PackedFloat32Array:
	if _noise.has(rate): return _noise[rate]
	var d := PackedFloat32Array()
	if rate == RATE:
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261002
		d.resize(int(RATE * NOISE_SEC))
		for i in d.size():
			d[i] = rng.randf() * 2 - 1
	else:
		var hi := getNoise(RATE)
		d.resize(hi.size() >> 1)
		for i in d.size():
			d[i] = (hi[2 * i] + hi[2 * i + 1]) * 0.5
	_noise[rate] = d
	return d

## JS loopNoise(type, freq, Q): the noise looping through a fixed biquad. The filter starts on the end of the buffer,
## so the result is the noise filtered as an endless loop: no seam where it wraps.
func loopNoise(type: String, freq: float, q: float, rate: int) -> AudioStreamWAV:
	var c := _biquad(type, freq, q, rate)
	var b0: float = c[0]
	var b1: float = c[1]
	var b2: float = c[2]
	var a1: float = c[3]
	var a2: float = c[4]
	var src := getNoise(rate)
	var n := src.size()
	var buf := PackedFloat32Array()
	buf.resize(n)
	var x1 := 0.0; var x2 := 0.0; var y1 := 0.0; var y2 := 0.0
	for i in range(-2048, n):
		var x := src[i]
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1; x1 = x; y2 = y1; y1 = y
		if i >= 0: buf[i] = y
	return _wav(buf, rate, true)

# ================================================================== synthesis helpers
static func _target(cur: float, v: float, dt: float, tau: float) -> float:
	return v + (cur - v) * exp(-dt / tau)

## Fourier sine coefficient k of Web Audio's built-in oscillator types, normalised to peak 1 like Chrome does
static func _coef(type: String, k: int) -> float:
	match type:
		"sine": return 1.0 if k == 1 else 0.0
		"square": return 4.0 / (PI * k) / GIBBS if k % 2 == 1 else 0.0
		"sawtooth": return (2.0 if k % 2 == 1 else -2.0) / (PI * k) / GIBBS
		"triangle": return (8.0 / (PI * PI * k * k)) * (1.0 if k % 4 == 1 else -1.0) if k % 2 == 1 else 0.0
	return 0.0

## Web Audio's BiquadFilterNode coefficients (spec formulas: lowpass/highpass Q in dB, bandpass Q linear), a0 = 1:
## [b0, b1, b2, a1, a2]
static func _biquad(type: String, f0: float, q: float, rate: float) -> Array:
	var w := TAU * f0 / rate
	var cs := cos(w)
	var sn := sin(w)
	var al: float
	var b0: float
	var b1: float
	var b2: float
	if type == "bandpass":
		al = sn / (2 * q)
		b0 = al; b1 = 0.0; b2 = -al
	else:
		al = sn / (2 * pow(10.0, q / 20))
		if type == "lowpass":
			b0 = (1 - cs) / 2; b1 = 1 - cs
		else:
			b0 = (1 + cs) / 2; b1 = -(1 + cs)
		b2 = b0
	var a0 := 1 + al
	return [b0 / a0, b1 / a0, b2 / a0, -2 * cs / a0, (1 - al) / a0]

## In-place radix-2 FFT (size a power of two). inverse: sum X[k] e^(+2 pi i k n / N), without the 1/N.
## Returns [re, im].
static func fft(re: PackedFloat64Array, im: PackedFloat64Array, inverse := false) -> Array:
	var n := re.size()
	var j := 0
	for i in range(1, n):
		var bit := n >> 1
		while j & bit:
			j ^= bit
			bit >>= 1
		j ^= bit
		if i < j:
			var t := re[i]; re[i] = re[j]; re[j] = t
			t = im[i]; im[i] = im[j]; im[j] = t
	var sgn := 1.0 if inverse else -1.0
	var size := 2
	while size <= n:
		var half := size >> 1
		var wr := cos(TAU / size)
		var wi := sgn * sin(TAU / size)
		for start in range(0, n, size):
			var cr := 1.0
			var ci := 0.0
			for k in half:
				var a := start + k
				var b := a + half
				var tr := re[b] * cr - im[b] * ci
				var ti := re[b] * ci + im[b] * cr
				re[b] = re[a] - tr; im[b] = im[a] - ti
				re[a] += tr; im[a] += ti
				var nr := cr * wr - ci * wi
				ci = cr * wi + ci * wr
				cr = nr
		size <<= 1
	return [re, im]

## one cycle of n samples holding the sine partials {harmonic: amplitude} (an inverse FFT)
static func _cycle(n: int, parts: Dictionary) -> PackedFloat32Array:
	var re := PackedFloat64Array()
	re.resize(n)
	var im := PackedFloat64Array()
	im.resize(n)
	for k in parts:
		re[k] = parts[k]
	var r := fft(re, im, true)
	var s: PackedFloat64Array = r[1]
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = s[i]
	return out

## the engine of a class: main wave plus the sub-octave square at half gain, one cycle of the sub, band-limited for
## the highest rpm
static func _engineCycle(e: Dictionary) -> PackedFloat32Array:
	var r := int(round(1.0 / e.sub))
	var top := mini(int(BAND / ((e.base * 0.85 + e.mul * 1.25) * 1.1 * e.sub)), (TAB >> 1) - 1)
	var parts := {}
	for c in range(1, top + 1):
		var a := 0.5 * _coef("square", c)
		if c % r == 0: a += _coef(e.type, int(float(c) / r))
		if a != 0.0: parts[c] = a
	return _cycle(TAB, parts)

## one band-limited cycle of a tone() oscillator, as many samples as its partials need
func _waveCycle(type: String, freq: float) -> PackedFloat32Array:
	var key := "%s|%s" % [type, freq]
	if _waves.has(key): return _waves[key]
	var top := 1 if type == "sine" else maxi(1, int(BAND / freq))
	var parts := {}
	for k in range(1, top + 1):
		var a := _coef(type, k)
		if a != 0.0: parts[k] = a
	var n := 64
	while n < top * 4 and n < TAB:
		n *= 2
	var cyc := _cycle(n, parts)
	_waves[key] = cyc
	return cyc

func _toneWav(freq: float, dur: float, type: String, vol: float, delay: float) -> AudioStreamWAV:
	var key := "%s|%s|%s|%s|%s" % [freq, dur, type, vol, delay]
	var w: AudioStreamWAV = _tones.get(key)
	if w != null: return w
	var cyc := _waveCycle(type, freq)
	var n := cyc.size()
	var mask := n - 1
	var d0 := int(round(maxf(0, delay) * RATE))
	var cnt := int(ceil((dur + 0.02) * RATE))     # o.stop(t + dur + 0.02)
	var nd := maxi(1, int(round(dur * RATE)))
	var buf := PackedFloat32Array()
	buf.resize(d0 + cnt)                          # zeros first: the delay
	var k := pow(0.0001 / vol, 1.0 / nd)          # gain ramp vol -> 0.0001 in dur, relative to vol
	var inc := n * freq / RATE
	var env := 1.0
	var ph := 0.0
	for i in cnt:
		var j := int(ph)
		var a := cyc[j]
		buf[d0 + i] = (a + (cyc[(j + 1) & mask] - a) * (ph - j)) * env
		if i < nd: env *= k
		ph += inc
		if ph >= n: ph -= n
	w = _wav(buf, RATE)
	if _tones.size() >= 64: _tones.clear()
	_tones[key] = w
	return w

func _renderNoise(dur: float, vol: float, freq: float) -> AudioStreamWAV:
	var src := getNoise(LOW_RATE)
	var m := src.size()
	var n := maxi(8, int(round(dur * LOW_RATE)))  # s.stop(t + dur)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var fc := freq
	var kf := pow(maxf(80, freq * 0.2) / freq, 8.0 / n)   # exponential cutoff ramp, a step per 8 samples
	var kg := pow(0.0001 / vol, 1.0 / n)                 # gain ramp vol -> 0.0001, relative to vol
	var qa := 0.5 / pow(10.0, 1 / 20.0)                  # the default Q (1 dB)
	var g := 1.0
	var b0 := 0.0; var b1 := 0.0; var a1 := 0.0; var a2 := 0.0
	var x1 := 0.0; var x2 := 0.0; var y1 := 0.0; var y2 := 0.0
	for i in n:
		if (i & 7) == 0:
			var w := TAU * fc * sqrt(kf) / LOW_RATE        # the cutoff in the middle of the step
			var cs := cos(w)
			var al := sin(w) * qa
			var a0 := 1 + al
			b0 = (1 - cs) * 0.5 / a0; b1 = (1 - cs) / a0; a1 = -2 * cs / a0; a2 = (1 - al) / a0
			fc *= kf
		var x := src[i % m]
		var y := b0 * (x + x2) + b1 * x1 - a1 * y1 - a2 * y2
		x2 = x1; x1 = x; y2 = y1; y1 = y
		buf[i] = y * g
		g *= kg
	return _wav(buf, LOW_RATE)

## 16-bit AudioStreamWAV of buf, scaled to full range; meta "level" scales it back (players multiply it in)
static func _wav(buf: PackedFloat32Array, rate: int, loop := false) -> AudioStreamWAV:
	var n := buf.size()
	var peak := 1e-9
	for i in n:
		peak = maxf(peak, absf(buf[i]))
	var k := 32767.0 / peak
	var gd := GUARD if loop else 0
	var d := PackedByteArray()
	d.resize((n + 2 * gd) * 2)
	for i in n:
		d.encode_s16((i + gd) * 2, int(buf[i] * k))
	for i in gd:
		d.encode_s16(i * 2, int(buf[n - gd + i] * k))
		d.encode_s16((n + gd + i) * 2, int(buf[i] * k))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = d
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = gd
		w.loop_end = n + gd
	w.set_meta("level", peak * 32768.0 / 32767.0)
	return w

static func _bus(name: String, send: String) -> int:
	var i := AudioServer.get_bus_index(name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, name)
	AudioServer.set_bus_send(i, send)
	return i

func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = -100
	add_child(p)
	return p

## a loop starts paused and silent; _vol wakes it
static func _start(p: AudioStreamPlayer, w: AudioStream) -> void:
	p.stream = w
	p.volume_db = -100
	p.play()
	p.stream_paused = true

## a loop's gain; silent loops are paused
static func _vol(p: AudioStreamPlayer, gain: float) -> void:
	var v := gain * float(p.stream.get_meta("level", 1.0))
	if v < SILENT:
		if not p.stream_paused:
			p.volume_db = -100
			p.stream_paused = true
		return
	p.volume_db = linear_to_db(v)
	if p.stream_paused: p.stream_paused = false

## the sounds of one frame start together at the end of it, in the same mix block (Web Audio schedules them on one
## clock: the fanfare's delays stay exact)
func _play(w: AudioStreamWAV, vol: float) -> void:
	if _queue.is_empty(): _flush.call_deferred()
	_queue.append([w, linear_to_db(vol * float(w.get_meta("level", 1.0)))])

func _flush() -> void:
	if not oneP.playing or _poly == null:
		oneP.play()
		_poly = oneP.get_stream_playback()
	AudioServer.lock()
	for q in _queue:
		_poly.play_stream(q[0], 0, q[1], 1.0)
	AudioServer.unlock()
	_queue.clear()

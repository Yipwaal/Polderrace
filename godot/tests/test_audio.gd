extends RefCounted
## Sound (Sfx, the JS audio section). Listens to the real mixer output: an AudioEffectCapture on the Master bus (with no
## sound card Godot falls back to its dummy audio driver, which still mixes in real time), and checks it against the JS
## graph with numbers worked out here from the Web Audio spec: engine pitch per class (f = base*0.85 + rpm*mul*1.25) and
## its level through the lowpass, the gains following the game, wind/squeal/rain/bot, tone() and noise(), mute, no NaN
## or clipping, and the CPU cost. Writes WAV files of a few scenarios to tests/.out/audio/ to listen to.

const CAR := {"B": "hatch", "A": "gt", "S": "super"}
const GIBBS := 1.17898

var host: Node
var r: TestReport
var cap: AudioEffectCapture
var rate := 44100.0
var peakAll := 0.0
var finiteAll := true
var outDir := ""
var drive := {}          ## the throttle scenario's input (null: nobody drives)
var sub := 0.0           ## real time left over for the 120 Hz drive steps
var fdt := 0.0           ## real time of the last frame
var _last := 0

func run(h: Node) -> TestReport:
	host = h
	r = TestReport.new("geluid zoals de HTML-versie (Sfx)")
	var g := Game
	# keep what other tests left behind and give it back at the end
	var keep := {"state": g.state, "paused": g.paused, "player": g.player, "bots": g.bots, "MAXV": g.MAXV, "windX": g.windX,
		"car": G.settings.car, "muted": Sfx.muted, "proc": g.is_processing()}
	var envMade := Env.me == null
	if envMade: Env.new()       # a bare Env (not in the tree) just for its weather
	var weather: String = Env.me.weather
	g.set_process(false)
	g.set_process_input(false)
	g.paused = false
	g.bots = []
	g.windX = 0
	g.player = PlayerState.new()
	Sfx.muted = false
	Env.me.weather = "dry"
	Sfx.initAudio()
	Sfx.wavesReady(true)
	rate = AudioServer.get_mix_rate()
	cap = AudioEffectCapture.new()
	cap.buffer_length = 4.0
	AudioServer.add_bus_effect(0, cap)
	outDir = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir() + "/tests/.out/audio/"
	DirAccess.make_dir_recursive_absolute(outDir)
	r.check(Sfx.actx and AudioServer.get_bus_index("Sfx") >= 0 and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Sfx"))), 0.6),
		"initAudio: bus Sfx met hoofdvolume 0,6",
		"%.1f ms op de hoofdthread + %.0f ms golven op een worker, mixfrequentie %d Hz" % [Sfx.initMs, Sfx.buildMs, rate])

	await engine_tests()
	await gain_tests()
	await rain_test()
	await bot_test()
	await mute_test()
	await tone_tests()
	await noise_tests()
	await worst_case()
	await cpu_tests()
	await wav_scenarios()
	r.check(finiteAll, "geen NaN/oneindig in alles wat is opgenomen")
	r.check(peakAll <= 1.0, "nergens boven 1,0 (geen clipping)", "hoogste piek %.3f" % peakAll)

	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	g.state = keep.state; g.paused = keep.paused; g.player = keep.player; g.bots = keep.bots; g.MAXV = keep.MAXV
	g.windX = keep.windX; G.settings.car = keep.car; Sfx.muted = keep.muted
	Env.me.weather = weather
	if envMade:
		Env.me.free()
		Env.me = null
	g.set_process(keep.proc)
	g.set_process_input(true)
	Sfx.updateAudio()
	return r

# ------------------------------------------------------------------ driving the mixer
func setCar(cls: String) -> void:
	G.settings.car = CAR[cls]
	Game.MAXV = G.effStats(CAR[cls]).vmax / 3.6

## one frame: the step (game state for this moment), updateAudio, and whatever the mixer made meanwhile
func _frame(step: Callable, out: PackedFloat32Array, want: int) -> PackedFloat32Array:
	await host.get_tree().process_frame
	var now := Time.get_ticks_usec()
	fdt = minf(0.1, (now - _last) / 1e6) if _last > 0 else 0.0
	_last = now
	if step.is_valid(): step.call()
	if not drive.is_empty(): _drive()
	Sfx.updateAudio()
	var n := cap.get_frames_available()
	if n > 0:
		var b := cap.get_buffer(n)
		if want > 0:
			for i in mini(n, want - out.size()):
				out.append(b[i].x)
	return out

func settle(sec: float, step := Callable()) -> void:
	var t0 := Time.get_ticks_msec()
	var none := PackedFloat32Array()
	while Time.get_ticks_msec() - t0 < sec * 1000:
		await _frame(step, none, 0)
	cap.clear_buffer()

## sec seconds of the Master output (mono)
func record(sec: float, step := Callable()) -> PackedFloat32Array:
	var want := int(sec * rate)
	var out := PackedFloat32Array()
	cap.clear_buffer()
	while out.size() < want:
		out = await _frame(step, out, want)
	for v in out:
		if is_nan(v) or is_inf(v): finiteAll = false
		peakAll = maxf(peakAll, absf(v))
	return out

func _drive() -> void:
	var g := Game
	sub += fdt
	while sub >= 1.0 / 120:
		sub -= 1.0 / 120
		g.drive(1.0 / 120, drive)

func save(name: String, x: PackedFloat32Array) -> void:
	var d := PackedByteArray()
	d.resize(x.size() * 2)
	for i in x.size():
		d.encode_s16(i * 2, clampi(int(x[i] * 32767), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(rate)
	w.stereo = false
	w.data = d
	w.save_to_wav(outDir + name + ".wav")

# ------------------------------------------------------------------ analysis
func spectrum(x: PackedFloat32Array, start: int, n: int) -> PackedFloat64Array:
	var re := PackedFloat64Array()
	re.resize(n)
	var im := PackedFloat64Array()
	im.resize(n)
	for i in n:
		re[i] = (x[start + i] if start + i < x.size() else 0.0) * (0.5 - 0.5 * cos(TAU * i / n))
	var res := Sfx.fft(re, im)
	var a: PackedFloat64Array = res[0]
	var b: PackedFloat64Array = res[1]
	var mag := PackedFloat64Array()
	mag.resize(n >> 1)
	for i in n >> 1:
		mag[i] = sqrt(a[i] * a[i] + b[i] * b[i]) * 4.0 / n   # a sine of amplitude A reads A (Hann window)
	return mag

## frequency of the strongest component between lo and hi Hz (parabola through the log magnitudes)
func peakFreq(mag: PackedFloat64Array, n: int, lo: float, hi: float) -> float:
	var bw := rate / n
	var best := int(ceil(lo / bw))
	for i in range(best, int(hi / bw) + 1):
		if mag[i] > mag[best]: best = i
	var a := log(mag[best - 1] + 1e-12); var b := log(mag[best] + 1e-12); var c := log(mag[best + 1] + 1e-12)
	var d := 0.5 * (a - c) / (a - 2 * b + c) if absf(a - 2 * b + c) > 1e-12 else 0.0
	return (best + d) * bw

func bandMax(mag: PackedFloat64Array, n: int, lo: float, hi: float) -> float:
	var m := 0.0
	for i in range(int(lo * n / rate), int(hi * n / rate) + 1):
		m = maxf(m, mag[i])
	return m

func bandPow(mag: PackedFloat64Array, n: int, lo: float, hi: float) -> float:
	var s := 0.0
	for i in range(int(lo * n / rate), int(hi * n / rate) + 1):
		s += mag[i] * mag[i]
	return s

func centroid(mag: PackedFloat64Array, n: int) -> float:
	var s := 0.0
	var w := 0.0
	for i in range(1, n >> 1):
		s += mag[i] * mag[i] * i
		w += mag[i] * mag[i]
	return s / maxf(w, 1e-30) * rate / n

func rms(x: PackedFloat32Array, a := 0, b := -1) -> float:
	if b < 0: b = x.size()
	var s := 0.0
	for i in range(a, b):
		s += x[i] * x[i]
	return sqrt(s / maxi(1, b - a))

func onset(x: PackedFloat32Array, from := 0, thr := 2e-3) -> int:
	for i in range(from, x.size()):
		if absf(x[i]) > thr: return i
	return -1

static func db(v: float) -> float:
	return 20 * log(maxf(v, 1e-12)) / log(10.0)

## Web Audio oscillator partials (spec), normalised to peak 1 like Chrome: independent of Sfx's own tables
static func coefSpec(type: String, k: int) -> float:
	if type == "square": return 4.0 / (PI * k) / GIBBS if k % 2 == 1 else 0.0
	if type == "sawtooth": return (2.0 if k % 2 == 1 else -2.0) / (PI * k) / GIBBS
	return 1.0 if k == 1 else 0.0

## |H| of Web Audio's lowpass (Q in dB) at f
func lowpassGain(f: float, cut: float, qdb: float) -> float:
	var w := TAU * cut / rate
	var al := sin(w) / (2 * pow(10.0, qdb / 20))
	var cs := cos(w)
	var b := [(1 - cs) / 2, 1 - cs, (1 - cs) / 2]
	var a := [1 + al, -2 * cs, 1 - al]
	var z := TAU * f / rate
	var num := Vector2(b[0] + b[1] * cos(z) + b[2] * cos(2 * z), -b[1] * sin(z) - b[2] * sin(2 * z))
	var den := Vector2(a[0] + a[1] * cos(z) + a[2] * cos(2 * z), -a[1] * sin(z) - a[2] * sin(2 * z))
	return num.length() / den.length()

## RMS of the JS engine graph: (main + 0.5 * sub square) -> lowpass(cut, Q 4 dB) -> gain -> master 0.6
func engineRms(cls: String, f: float, cut: float, gain: float) -> float:
	var e: Dictionary = Sfx.ENG[cls]
	var rr := int(round(1.0 / e.sub))
	var fc: float = f * e.sub
	var s := 0.0
	var c := 1
	while c * fc < rate / 2:
		var a := 0.5 * coefSpec("square", c)
		if c % rr == 0: a += coefSpec(e.type, int(float(c) / rr))
		s += pow(a * lowpassGain(c * fc, cut, 4), 2) / 2
		c += 1
	return sqrt(s) * gain * 0.6

static func expectF(cls: String, rpm: float) -> float:
	var e: Dictionary = Sfx.ENG[cls]
	return e.base * 0.85 + rpm * e.mul * 1.25

# ------------------------------------------------------------------ tests
func engine_tests() -> void:
	var g := Game
	var N := 32768
	for cls in ["B", "A", "S"]:
		setCar(cls)
		var e: Dictionary = Sfx.ENG[cls]
		# countdown, no gas: idle (rpm 0.14); full gas (0.74); racing in 3rd at 80% (0.8)
		for k in 3:
			var rpm := [0.14, 0.74, 0.8][k] as float
			if k < 2:
				g.state = "countdown"; g.player.speed = 0; g.player.gear = 1; g.player.gasIn = 0.0 if k == 0 else 1.0
			else:
				g.state = "racing"; g.player.gear = 3; g.player.gasIn = 0; g.player.speed = g.gearTop(3) * 0.8
			await settle(0.9 if k == 0 else 0.5)
			var x := await record(N / rate + 0.01)
			var mag := spectrum(x, 0, N)
			var f := expectF(cls, rpm)
			var fm := peakFreq(mag, N, f * 0.9, f * 1.1)
			var fs := peakFreq(mag, N, f * e.sub * 0.9, f * e.sub * 1.1)
			r.check(absf(fm - f) < f * 0.005 and absf(fs - f * e.sub) < f * e.sub * 0.006,
				"motor %s rpm %.2f: grondtoon %.1f Hz en sub-octaaf %.1f Hz" % [cls, rpm, f, f * e.sub], "gemeten %.2f en %.2f Hz" % [fm, fs])
			if k == 0:
				var want := engineRms(cls, f, 500, 0.05)
				var got := rms(x)
				r.check(absf(got / want - 1) < 0.05, "motor %s stationair: niveau na het laagdoorlaatfilter (500 Hz, Q 4 dB) gelijk" % cls,
					"rms %.5f, Web Audio %.5f" % [got, want])

func gain_tests() -> void:
	var g := Game
	setCar("B")
	g.state = "racing"; g.player.gasIn = 0; g.player.gear = 4
	var lv := []
	for v in [12.0, 45.0]:
		g.player.speed = v
		await settle(1.3)
		var sp: float = v / g.MAXV
		var ok := absf(Sfx.engGain - (0.05 + sp * 0.05)) < 1e-3 and absf(Sfx.engCut - (500 + sp * 1600)) < 2 \
			and absf(Sfx.windGain - pow(v / 80, 2) * 0.22) < 1e-3 and Sfx.squealGain < 1e-4
		r.check(ok, "%.0f km/u: motorvolume, filter en wind volgen de snelheid" % (v * 3.6),
			"motor %.4f (JS %.4f), filter %.0f Hz (JS %.0f), wind %.4f (JS %.4f)" % [Sfx.engGain, 0.05 + sp * 0.05, Sfx.engCut, 500 + sp * 1600, Sfx.windGain, pow(v / 80, 2) * 0.22])
		lv.append(rms(await record(0.3)))
	r.check(lv[1] > lv[0] * 1.25, "harder rijden klinkt harder", "rms %.4f -> %.4f" % [lv[0], lv[1]])
	# gust of wind (Afsluitdijk, Zeeland)
	g.windX = 3
	await settle(1.0)
	r.check(absf(Sfx.windGain - (pow(45.0 / 80, 2) * 0.22 + 3 * 0.008)) < 1e-3, "windvlaag telt mee in de wind", "%.4f" % Sfx.windGain)
	g.windX = 0
	# squeal: handbrake at 90 km/h (skidAmount 2.5) against the same speed without
	g.player.speed = 25; g.player.gear = 3
	await settle(0.8)
	var N := 16384
	var calm := spectrum(await record(N / rate + 0.01), 0, N)
	g.player.hand = true
	await settle(0.5)
	var want := clampf((g.skidAmount() - 0.8) * 0.03, 0, 0.11)
	var skid := spectrum(await record(N / rate + 0.01), 0, N)
	r.check(absf(Sfx.squealGain - want) < 1e-3 and absf(g.skidAmount() - 2.5) < 1e-6, "handrem: piepende banden volgen skidAmount()",
		"skidAmount %.2f, piep %.4f (JS %.4f)" % [g.skidAmount(), Sfx.squealGain, want])
	var gain := db(sqrt(bandPow(skid, N, 2450, 2750) / bandPow(calm, N, 2450, 2750)))
	r.check(gain > 6, "piepen hoorbaar rond 2600 Hz", "+%.1f dB in 2450-2750 Hz" % gain)
	g.player.hand = false

func rain_test() -> void:
	var g := Game
	g.state = "menu"; g.player.speed = 0
	Env.me.weather = "rain"
	await settle(2.2)
	var x := await record(0.6)
	# the rain loop's own rms (16-bit data back to the level it was rendered at)
	var w: AudioStreamWAV = Sfx.rainP.stream
	var d := w.data
	var s := 0.0
	for i in range(w.loop_begin, w.loop_end):
		var v := d.decode_s16(i * 2) / 32768.0
		s += v * v
	var loopRms := sqrt(s / (w.loop_end - w.loop_begin)) * float(w.get_meta("level"))
	var want := loopRms * 0.035 * 0.6
	r.check(absf(rms(x) / want - 1) < 0.05, "regen in het menu: 0,035 x hoogdoorlaat-ruis (1600 Hz)", "rms %.5f, verwacht %.5f" % [rms(x), want])
	var N := 16384
	var mag := spectrum(x, 0, N)
	r.check(bandPow(mag, N, 3000, 12000) > 20 * bandPow(mag, N, 50, 800), "regen is hoog gefilterd", "")
	# the garage is indoors: no rain there (JS !inGarage)
	GarageRoom.inGarage = true
	await settle(2.0)
	r.check(Sfx.rainGain < 0.001, "geen regen in de garage", "%.5f (buiten 0,035)" % Sfx.rainGain)
	GarageRoom.inGarage = false
	Env.me.weather = "dry"

func bot_test() -> void:
	var g := Game
	setCar("B")
	g.state = "racing"; g.player.gear = 3; g.player.speed = 20; g.player.pos = Vector3.ZERO
	var b := Mover.new()
	b.is_bot = true
	var n3 := Node3D.new()
	n3.position = Vector3(9, 0, 12)     # 15 m away
	b.m = {"g": n3}
	b.vmax = 60; b.speed = 30
	g.bots = [b]
	await settle(1.0)
	r.check(absf(Sfx.botFreq - 110) < 0.5 and absf(Sfx.botGain - 0.045 * (1 - 15.0 / 45)) < 5e-4, "dichtstbijzijnde bot: toon 40 + 140 x v/vmax, volume naar afstand",
		"%.1f Hz (JS 110), %.4f (JS %.4f)" % [Sfx.botFreq, Sfx.botGain, 0.045 * (1 - 15.0 / 45)])
	var N := 32768
	var withBot := spectrum(await record(N / rate + 0.01), 0, N)
	g.bots = []
	await settle(0.8)
	var noBot := spectrum(await record(N / rate + 0.01), 0, N)
	var lift := db(bandMax(withBot, N, 108, 112) / bandMax(noBot, N, 108, 112))
	r.check(lift > 10 and absf(peakFreq(withBot, N, 100, 120) - 110) < 0.6, "bot-motor hoorbaar op 110 Hz", "+%.1f dB" % lift)
	n3.free()
	b.m = {"g": Node3D.new()}
	b.m.g.position = Vector3(0, 0, 50)    # 50 m: out of earshot
	g.bots = [b]
	await settle(0.8)
	r.check(Sfx.botGain < 1e-3, "bot verder dan 45 m: stil", "%.5f" % Sfx.botGain)
	b.m.g.free()
	g.bots = []

func mute_test() -> void:
	var g := Game
	g.state = "racing"; g.player.speed = 40; g.player.gear = 4
	Env.me.weather = "rain"
	await settle(0.5)
	var loud := rms(await record(0.2))
	Sfx.muted = true
	await settle(1.6)
	Sfx.tone(440, 0.3, "square", 0.2)
	Sfx.noise(0.3, 0.4, 1500)
	var x := await record(0.4)
	var pk := 0.0
	for v in x: pk = maxf(pk, absf(v))
	r.check(loud > 0.01 and pk < 1e-3, "geluid uit: stil (ook tone() en noise())", "rms ervoor %.4f, piek daarna %.6f" % [loud, pk])
	Sfx.muted = false
	Env.me.weather = "dry"
	var pref: bool = G.prefs.sound
	Sfx.toggleMute()
	var a: bool = Sfx.muted and G.prefs.sound == false
	Sfx.toggleMute()
	r.check(a and not Sfx.muted and G.prefs.sound == true, "toggleMute zet geluid uit en weer aan (en bewaart prefs.sound)")
	G.prefs.sound = pref
	G.savePrefs()
	Sfx.muted = false

func tone_tests() -> void:
	var g := Game
	g.state = "menu"; g.player.speed = 0
	await settle(1.2)
	Sfx.tone(440, 0.16, "square", 0.09)
	Sfx.tone(880, 0.1, "sine", 0.15, 0.3)
	var x := await record(0.6)
	var o1 := onset(x)
	r.check(o1 >= 0, "tone() klinkt")
	if o1 < 0: return
	var N := 4096
	var f1 := peakFreq(spectrum(x, o1, N), N, 300, 600)
	var p1 := 0.0
	for i in range(o1, o1 + int(0.01 * rate)): p1 = maxf(p1, absf(x[i]))
	r.check(absf(f1 - 440) < 4, "tone(440, 0.16, 'square', 0.09): 440 Hz", "%.1f Hz" % f1)
	r.check(p1 > 0.09 * 0.6 * 0.85 and p1 < 0.09 * 0.6 * 1.15, "tone(): begint op vol x 0,6", "piek %.4f (verwacht ~%.4f)" % [p1, 0.054])
	var a := rms(x, o1, o1 + int(0.01 * rate))
	var b := rms(x, o1 + int(0.1 * rate), o1 + int(0.11 * rate))
	var want := db(pow(0.0001 / 0.09, 0.1 / 0.16))
	r.check(absf(db(b / a) - want) < 3, "tone(): exponentieel uitsterven naar 0,0001 in 'dur'", "na 0,1 s %.1f dB (JS %.1f dB)" % [db(b / a), want])
	var o2 := onset(x, o1 + int(0.2 * rate))
	r.check(o2 > 0 and absf((o2 - o1) / rate - 0.3) < 0.001, "tone(..., delay 0.3): begint 0,3 s later", "%.4f s" % ((o2 - o1) / rate))
	if o2 > 0:
		var f2 := peakFreq(spectrum(x, o2, N), N, 700, 1100)
		var p2 := 0.0
		for i in range(o2, o2 + int(0.01 * rate)): p2 = maxf(p2, absf(x[i]))
		r.check(absf(f2 - 880) < 6 and absf(p2 / (0.15 * 0.6) - 1) < 0.04, "tone(880, 0.1, 'sine', 0.15): 880 Hz, piek 0,09", "%.1f Hz, piek %.4f" % [f2, p2])

func noise_tests() -> void:
	await settle(0.6)
	var n0: int = Sfx._bursts.size()
	Sfx.noise(0.3, 0.4, 1500)
	var x := await record(0.5)
	var o := onset(x)
	r.check(o >= 0, "noise() klinkt")
	if o < 0: return
	var a := rms(x, o, o + int(0.02 * rate))
	var b := rms(x, o + int(0.2 * rate), o + int(0.22 * rate))
	var N := 2048
	var c1 := centroid(spectrum(x, o, N), N)
	var c2 := centroid(spectrum(x, o + int(0.13 * rate), N), N)
	r.check(db(b / a) < -30, "noise(): uitsterven", "na 0,2 s %.1f dB" % db(b / a))
	r.check(c2 < c1 * 0.75, "noise(): laagdoorlaat zakt van 1500 naar 300 Hz", "zwaartepunt %.0f -> %.0f Hz" % [c1, c2])
	var pk := 0.0
	for v in x: pk = maxf(pk, absf(v))
	r.check(pk < 0.4 * 0.6 * 2, "noise(): niveau past bij vol 0,4", "piek %.3f" % pk)
	Sfx.noise(0.3, 0.4, 1500)
	Sfx.noise(0.301, 0.401, 1502)
	r.check(Sfx._bursts.size() == n0 + 1, "noise(): dezelfde klap wordt hergebruikt (cache)")
	await settle(0.5)

func worst_case() -> void:
	# everything at once: S class flat out, gust, rain, handbrake slide, a bot alongside, a crash and the fanfare
	var g := Game
	setCar("S")
	g.state = "racing"; g.player.gear = 6; g.player.speed = g.MAXV; g.player.hand = true; g.player.slide = Vector2(8, 0)
	g.player.steer = 1; g.player.brk = 1; g.windX = 3
	Env.me.weather = "rain"
	var b := Mover.new()
	b.is_bot = true
	b.m = {"g": Node3D.new()}
	b.vmax = 80; b.speed = 80
	g.bots = [b]
	await settle(1.0)
	r.check(Sfx.squealGain > 0.105, "volle slip: piepen op het maximum (0,11)", "%.3f" % Sfx.squealGain)
	Sfx.noise(0.7, 0.5, 1800)
	Sfx.noise(0.32, 0.45, 1500)
	Sfx.tone(85, 0.14, "square", 0.1)
	Sfx.tone(70, 0.18, "square", 0.12)
	Sfx.tone(880, 0.2, "triangle", 0.18); Sfx.tone(1320, 0.2, "triangle", 0.18, 0.18); Sfx.tone(1760, 0.5, "triangle", 0.18, 0.36)
	var x := await record(1.0)
	var pk := 0.0
	for v in x: pk = maxf(pk, absf(v))
	r.check(pk <= 1.0, "alles tegelijk blijft onder 1,0", "piek %.3f" % pk)
	save("alles_tegelijk", x)
	g.player.hand = false; g.player.slide = Vector2.ZERO; g.player.steer = 0; g.player.brk = 0; g.windX = 0
	Env.me.weather = "dry"
	b.m.g.free()
	g.bots = []

## CPU time of a thread per tid (Linux /proc; empty elsewhere)
func threadTicks() -> Dictionary:
	var out := {}
	var base := "/proc/%d/task" % OS.get_process_id()
	if not DirAccess.dir_exists_absolute(base): return out
	for tid in DirAccess.get_directories_at(base):
		var f := FileAccess.open(base + "/" + tid + "/stat", FileAccess.READ)
		if f == null: continue
		var s := f.get_line()
		var p := s.rfind(")")
		var parts := s.substr(p + 2).split(" ")
		if parts.size() > 12: out[tid] = int(parts[11]) + int(parts[12])
	return out

## share of one core used by the busiest thread other than the main thread (the audio thread) during sec seconds
func audioThreadLoad(sec: float) -> float:
	var a := threadTicks()
	var t0 := Time.get_ticks_usec()
	await settle(sec)
	var b := threadTicks()
	var el := (Time.get_ticks_usec() - t0) / 1e6
	var best := 0
	for tid in b:
		if tid == str(OS.get_process_id()) or not a.has(tid): continue
		best = maxi(best, b[tid] - a[tid])
	return best / 100.0 / el

func cpu_tests() -> void:
	var g := Game
	setCar("A")
	g.state = "racing"; g.player.gear = 4; g.player.speed = 50; g.player.hand = true; g.windX = 2
	Env.me.weather = "rain"
	var bots := []
	for k in 7:
		var b := Mover.new()
		b.is_bot = true
		b.m = {"g": Node3D.new()}
		b.m.g.position = Vector3(k * 6 - 18, 0, 10 + k)
		b.vmax = 70; b.speed = 50
		bots.append(b)
	g.bots = bots
	await settle(0.5)
	var t0 := Time.get_ticks_usec()
	for i in 2000: Sfx.updateAudio()
	var us := (Time.get_ticks_usec() - t0) / 2000.0
	r.check(us < 300, "updateAudio per frame (7 bots)", "%.1f us = %.2f ms per seconde bij 60 fps" % [us, us * 60 / 1000])
	var busy := await audioThreadLoad(3.0)
	# 40 extra loops through the same buses, to see what one loop costs the mixer
	var extra := []
	for k in 40:
		var p := AudioStreamPlayer.new()
		p.stream = Sfx.engTabs["A"] if k % 2 == 0 else Sfx.windP.stream
		p.bus = "SfxEngine" if k % 2 == 0 else "Sfx"
		p.volume_db = -60
		p.pitch_scale = 1.5 + k * 0.05
		host.add_child(p)
		p.play()
		extra.append(p)
	var stress := await audioThreadLoad(3.0)
	for p in extra: p.queue_free()
	g.state = "menu"; g.player.hand = false; g.windX = 0
	Env.me.weather = "dry"
	await settle(1.5)
	var idle := await audioThreadLoad(3.0)
	if threadTicks().is_empty():
		print("--   audiothread: niet te meten (geen /proc)")
	else:
		r.check(busy < 0.05, "mixen kost weinig: audiothread met alle lussen aan",
			"%.2f%% van een kern (stil %.2f%%; met 40 lussen extra %.2f%%, dus ~%.3f%% per lus; /proc meet in stappen van 10 ms)" % [busy * 100, idle * 100, stress * 100, maxf(0, stress - busy) * 100 / 40])
	t0 = Time.get_ticks_usec()
	Sfx._toneWav(333, 0.3, "square", 0.1, 0.0)
	var tms := (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	Sfx._renderNoise(0.32, 0.45, 1500)
	var nms := (Time.get_ticks_usec() - t0) / 1000.0
	r.check(tms < 60 and nms < 60, "een nieuwe tone()/noise() maken", "tone 0,3 s: %.1f ms, klap 0,32 s: %.1f ms (daarna uit de cache)" % [tms, nms])
	for b in bots: b.m.g.free()
	g.bots = []

func wav_scenarios() -> void:
	var g := Game
	# idle: countdown without gas, hot hatch
	setCar("B")
	g.state = "countdown"; g.player.speed = 0; g.player.gear = 1; g.player.gasIn = 0
	await settle(0.6)
	save("stationair_B", await record(2.0))
	# countdown as the game runs it (Game.update: five beeps and GO), then idling on
	g.state = "countdown"; g.cd = 0; g.lastCount = -1; g.goDelay = 0.6
	var cdStep := func():
		if g.state == "countdown": g.update(fdt)
	var x := await record(4.7, cdStep)
	r.check(g.state == "racing", "aftellen via Game.update: piepjes en GO")
	save("aftellen", x)
	# full throttle from standstill through the gears (Game.drive, automatic gearbox with the shift tick)
	var box: String = G.prefs.gearbox
	G.prefs.gearbox = "auto"
	for cls in ["B", "A", "S"]:
		setCar(cls)
		g.state = "racing"; g.player = PlayerState.new()
		await settle(0.4)
		sub = 0
		drive = {"gas": 1.0, "brake": 0.0, "steer": 0.0, "analog": false, "hand": false}
		x = await record(5.0)
		drive = {}
		r.check(g.player.gear >= 3, "vol gas %s: schakelt op (versnelling %d, %.0f km/u)" % [cls, g.player.gear, g.player.speed * 3.6])
		save("vol_gas_" + cls, x)
	G.prefs.gearbox = box
	# skid: handbrake slide at 90 km/h
	setCar("A")
	g.player = PlayerState.new()
	g.state = "racing"; g.player.gear = 3; g.player.speed = 25
	await settle(0.5)
	var t := [0.0]
	var skidStep := func():
		t[0] += fdt
		g.player.hand = t[0] > 0.3 and t[0] < 1.6
	save("slip", await record(2.2, skidStep))
	g.player.hand = false
	# crashes: hitFx light and hard, a wall, the ditch (the same calls as Game)
	setCar("B")
	g.player.speed = 20
	await settle(0.4)
	t = [0.0]
	var done := [false, false, false, false]
	var crashStep := func():
		t[0] += fdt
		if t[0] > 0.3 and not done[0]:
			done[0] = true; g.hitT = -9; g.hitFx(5, true)
		if t[0] > 0.9 and not done[1]:
			done[1] = true; g.hitT = -9; g.hitFx(14, true)
		if t[0] > 1.6 and not done[2]:
			done[2] = true; Sfx.noise(0.22, 0.4, 650); Sfx.tone(70, 0.18, "square", 0.12)
		if t[0] > 2.2 and not done[3]:
			done[3] = true; Sfx.noise(0.7, 0.5, 1800)
	save("botsingen", await record(3.2, crashStep))
	# finish fanfare (finishPlayer's tones) over the engine
	Sfx.tone(880, 0.2, "triangle", 0.18); Sfx.tone(1320, 0.2, "triangle", 0.18, 0.18); Sfx.tone(1760, 0.5, "triangle", 0.18, 0.36)
	save("finish", await record(1.4))
	# a bot passing at 50 km/h faster
	var b := Mover.new()
	b.is_bot = true
	b.m = {"g": Node3D.new()}
	b.vmax = 70; b.speed = 34
	g.bots = [b]
	t = [0.0]
	var passStep := func():
		t[0] += fdt
		b.m.g.position = Vector3(3, 0, -40 + t[0] * 14 * 2)
	save("bot_haalt_in", await record(3.0, passStep))
	b.m.g.free()
	g.bots = []
	g.state = "menu"
	await settle(0.3)
	print("--   WAV-bestanden: ", outDir)

class_name TripodSound
## The tripod's sounds, made in code the first time each is wanted (no files),
## and kept: its horn, its footfalls, the hiss of a leg lifting, the hum of
## the heat ray charging, the roar of the ray, and the clank of its grasper.
## All mono, 22050 a second.
##
## THE HORN is the one that matters: a deep, distorted, droning blast in two
## syllables, "ULLA". A brassy note round 55 Hz (and a dissonant voice a
## tritone above it, and a beating copy a little off it) is shaped by the
## mouth of a vowel that opens from "oo" to "ah" as the second syllable comes
## in, its pitch sagging and lifting, driven into distortion, and echoed back
## by the walls. Made from two single cycles worked out once, so that it is
## quick to make even in a browser.

const RATE := 22050

static var _horn: AudioStreamWAV
static var _footfall: AudioStreamWAV
static var _hiss: AudioStreamWAV
static var _hum: AudioStreamWAV
static var _roar: AudioStreamWAV
static var _clank: AudioStreamWAV


static func horn() -> AudioStreamWAV:
	if _horn:
		return _horn
	var length := 4.6
	var count := int(length * RATE)
	var size := 2048
	# One cycle of a brassy note through each vowel's mouth: "oo" and "ah".
	var oo := _vowel_cycle(size, 54.0, [[300.0, 90.0, 1.0], [870.0, 120.0, 0.35], [2240.0, 200.0, 0.08]])
	var ah := _vowel_cycle(size, 54.0, [[700.0, 110.0, 1.0], [1150.0, 130.0, 0.6], [2500.0, 220.0, 0.15]])
	var out := PackedFloat32Array()
	out.resize(count)
	var phases := [0.0, 0.0, 0.0]
	var low := 0.0
	for i in count:
		var t := float(i) / RATE
		# Pitch: "UL" lifts a little, dips between the syllables, "LA" a step up, sagging away at the end.
		var pitch := 50.0 + 6.0 * smoothstep(0.0, 0.35, t) - 4.0 * _bump(t, 1.25, 0.25) + 7.0 * smoothstep(1.3, 1.6, t) - 9.0 * smoothstep(2.4, 4.6, t)
		pitch *= 1.0 + 0.004 * sin(t * 37.0) + 0.006 * sin(t * 5.3)
		var mouth := smoothstep(1.2, 1.55, t)
		var level := smoothstep(0.0, 0.18, t) * (1.0 - 0.55 * _bump(t, 1.3, 0.18)) * (1.0 - smoothstep(3.2, 4.5, t))
		var sample := 0.0
		var freqs := [pitch, pitch * 1.006, pitch * 1.414]
		var gains := [1.0, 0.7, 0.28]
		for v in 3:
			phases[v] = fmod(phases[v] + freqs[v] / RATE, 1.0)
			var at: float = phases[v] * size
			var k := int(at)
			var f := at - k
			var a := lerpf(oo[k % size], oo[(k + 1) % size], f)
			var b := lerpf(ah[k % size], ah[(k + 1) % size], f)
			sample += lerpf(a, b, mouth) * gains[v]
		# (a sub-octave under it, felt more than heard)
		low += (sin(TAU * pitch * 0.5 * t) - low) * 0.02
		sample = sample * 0.55 + sin(TAU * pitch * 0.5 * t) * 0.35
		# driven into distortion, with a rasp that comes and goes
		var drive := 2.6 + 1.4 * sin(t * 2.3) * sin(t * 0.7)
		out[i] = tanh(sample * drive) * level * 0.62
	# Echoes off the walls: a few taps, fed back.
	var taps := [[0.13, 0.42], [0.29, 0.3], [0.47, 0.22], [0.71, 0.16]]
	var echoed := out.duplicate()
	for i in count:
		var add := 0.0
		for tap: Array in taps:
			var back := i - int(tap[0] * RATE)
			if back >= 0:
				add += echoed[back] * tap[1]
		echoed[i] = out[i] + add * 0.55
	_horn = _wav(echoed, 0.9)
	return _horn


## One cycle (`size` samples) of a buzzing note at `pitch` heard through
## resonances [[hz, width, gain], ...]: harmonics weighted by how near each is to one.
static func _vowel_cycle(size: int, pitch: float, formants: Array) -> PackedFloat32Array:
	var cycle := PackedFloat32Array()
	cycle.resize(size)
	var harmonics := int(3200.0 / pitch)
	var weights := PackedFloat32Array()
	for h in range(1, harmonics + 1):
		var hz := h * pitch
		var gain := 0.08
		for f: Array in formants:
			var d: float = (hz - f[0]) / f[1]
			gain += f[2] / (1.0 + d * d)
		weights.append(gain / sqrt(float(h)))
	for k in size:
		var x := TAU * k / size
		var s := 0.0
		for h in harmonics:
			s += sin(x * (h + 1)) * weights[h]
		cycle[k] = s
	var peak := 0.0
	for k in size:
		peak = maxf(peak, absf(cycle[k]))
	for k in size:
		cycle[k] /= maxf(peak, 0.0001)
	return cycle


## A great foot coming down: a deep falling boom, the thump of it and a
## metallic clank and rattle on top.
static func footfall() -> AudioStreamWAV:
	if _footfall:
		return _footfall
	var count := int(1.7 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var phase := 0.0
	var thump := 0.0
	for i in count:
		var t := float(i) / RATE
		var hz := 34.0 + 46.0 * exp(-t * 7.0)
		phase += hz / RATE
		var boom := sin(TAU * phase) * exp(-t * 2.6) * smoothstep(0.0, 0.01, t)
		thump += (rng.randf_range(-1.0, 1.0) - thump) * 0.05
		var crunch := thump * exp(-t * 9.0) * 2.2
		var clank := 0.0
		for p: Array in [[187.0, 0.5, 5.0], [413.0, 0.32, 7.0], [691.0, 0.22, 9.0], [1123.0, 0.12, 12.0]]:
			clank += sin(TAU * p[0] * t + p[1] * 3.0) * p[1] * exp(-t * p[2])
		var rattle := rng.randf_range(-1.0, 1.0) * 0.12 * _bump(t, 0.2, 0.12)
		out[i] = tanh(boom * 1.6 + crunch * 0.5 + clank * 0.4 * smoothstep(0.0, 0.004, t) + rattle)
	_footfall = _wav(out, 0.95)
	return _footfall


## A leg lifting: a hydraulic hiss and a servo's whine, rising.
static func hiss() -> AudioStreamWAV:
	if _hiss:
		return _hiss
	var count := int(1.3 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var low := 0.0
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		var n := rng.randf_range(-1.0, 1.0)
		low += (n - low) * 0.35
		var air := (n - low) * smoothstep(0.0, 0.06, t) * exp(-t * 2.2)
		phase += (120.0 + 90.0 * smoothstep(0.0, 1.2, t)) / RATE
		var whine := (fmod(phase, 1.0) * 2.0 - 1.0) * 0.18 * smoothstep(0.05, 0.3, t) * (1.0 - smoothstep(0.9, 1.3, t))
		out[i] = air * 0.5 + whine
	_hiss = _wav(out, 0.6)
	return _hiss


## The heat ray charging: a rich, buzzing hum (a loop of a second; it is
## played faster and louder as the charge builds).
static func hum() -> AudioStreamWAV:
	if _hum:
		return _hum
	var count := RATE
	var out := PackedFloat32Array()
	out.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in count:
		var t := float(i) / RATE
		var s := 0.0
		for h in range(1, 9):
			s += sin(TAU * 110.0 * h * t + h * 0.7) / h
		s += sin(TAU * 113.0 * t) * 0.5
		var crackle := rng.randf_range(-1.0, 1.0) * (0.15 if rng.randf() < 0.02 else 0.03)
		out[i] = tanh(s * 0.8) * 0.7 + crackle
	_hum = _wav(out, 0.7, true)
	return _hum


## The heat ray burning: a roaring, crackling blast over a deep buzz (a loop).
static func roar() -> AudioStreamWAV:
	if _roar:
		return _roar
	var count := RATE
	var out := PackedFloat32Array()
	out.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var low := 0.0
	var band := 0.0
	for i in count:
		var t := float(i) / RATE
		var n := rng.randf_range(-1.0, 1.0)
		low += (n - low) * 0.12
		band += (low - band) * 0.5
		var buzz := 0.0
		for h in range(1, 6):
			buzz += sin(TAU * 73.0 * h * t) / h
		var pop := rng.randf_range(-1.0, 1.0) * 0.8 if rng.randf() < 0.004 else 0.0
		var flutter := 0.75 + 0.25 * sin(TAU * 11.0 * t)
		out[i] = tanh((band * 2.4 + buzz * 0.45) * flutter + pop)
	_roar = _wav(out, 0.85, true)
	return _roar


## The grasper's claws closing: a hard clank and a ratchet.
static func clank() -> AudioStreamWAV:
	if _clank:
		return _clank
	var count := int(0.7 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in count:
		var t := float(i) / RATE
		var s := 0.0
		for p: Array in [[310.0, 0.5, 9.0], [742.0, 0.35, 12.0], [1290.0, 0.2, 16.0], [2210.0, 0.1, 22.0]]:
			s += sin(TAU * p[0] * t) * p[1] * exp(-t * p[2])
		var ratchet := rng.randf_range(-1.0, 1.0) * 0.4 * (1.0 if fmod(t, 0.045) < 0.006 else 0.0) * _bump(t, 0.3, 0.2)
		out[i] = tanh(s * 1.5 + ratchet)
	_clank = _wav(out, 0.8)
	return _clank


static func _bump(t: float, at: float, width: float) -> float:
	var d := (t - at) / width
	return exp(-d * d)


## 16-bit mono at RATE, scaled so that its loudest is `peak`.
static func _wav(samples: PackedFloat32Array, peak: float, loop := false) -> AudioStreamWAV:
	var top := 0.0001
	for s in samples:
		top = maxf(top, absf(s))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / top * peak, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav

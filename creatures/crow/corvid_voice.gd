class_name CorvidVoice
extends Node3D
## The sounds of a CorvidFlock, made in code (no sound files): a crow's caw
## (and the harsher, faster alarm caw), a raven's deep croak and its hollow
## knocking, a blue jay's "jay! jay!", its squeaky "queedle" and its mimic of a
## red-tailed hawk's scream, and the clatter of wings taking off. Put one in as
## a child of the flock (`CorvidVoice.new(flock)`) and it plays them where the
## birds are, on a few 3D players of its own.
##
## The sounds are made once (the first time any voice is made) and shared.

## How many sounds at once, at most.
const VOICES := 4
const RATE := 16000

static var _sounds := {}

## How loud, decibels.
@export var volume := -6.0

var _players: Array[AudioStreamPlayer3D] = []
var _next := 0
var _wings_in := 0.0
var _rng := RandomNumberGenerator.new()


func _init(flock: CorvidFlock = null) -> void:
	name = "Voice"
	if flock:
		flock.called.connect(call_out)
		flock.took_off.connect(wings)


func _ready() -> void:
	_make_sounds()
	top_level = true
	for i in VOICES:
		var player := AudioStreamPlayer3D.new()
		player.volume_db = volume
		add_child(player)
		_players.append(player)


func _process(delta: float) -> void:
	_wings_in -= delta


## Plays call `call` (CorvidFlock.Call) at `at`.
func call_out(at: Vector3, call: int) -> void:
	var options: Array = _sounds.get(call, [])
	if options.is_empty():
		return
	var stream: AudioStreamWAV = options[_rng.randi_range(0, options.size() - 1)]
	match call:
		CorvidFlock.Call.HAWK:
			_play(stream, at, _rng.randf_range(0.97, 1.03), 2.0, 10.0, 160.0)
		CorvidFlock.Call.CROAK, CorvidFlock.Call.KNOCK:
			_play(stream, at, _rng.randf_range(0.92, 1.06), 1.0, 9.0, 140.0)
		CorvidFlock.Call.ALARM:
			_play(stream, at, _rng.randf_range(0.95, 1.12), 2.0, 9.0, 140.0)
		_:
			_play(stream, at, _rng.randf_range(0.93, 1.08), 0.0, 8.0, 120.0)


## The clatter of wings as one takes off (no more than three a second).
func wings(at: Vector3) -> void:
	if _wings_in > 0.0:
		return
	_wings_in = 0.33
	_play(_sounds["wings"][0], at, _rng.randf_range(0.85, 1.15), -4.0, 3.0, 35.0)


func _play(stream: AudioStreamWAV, at: Vector3, pitch: float, louder: float, unit: float, reach: float) -> void:
	if _players.is_empty() or stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume + louder
	player.unit_size = unit
	player.max_distance = reach
	player.global_position = at + Vector3.UP * 0.3
	player.play()


## Every sound, by CorvidFlock.Call (and "wings"): a few of each.
static func sounds() -> Dictionary:
	_make_sounds()
	return _sounds


static func _make_sounds() -> void:
	if not _sounds.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	# A crow's caw: "caaw", nasal and harsh, the pitch falling; the alarm shorter, harsher, higher.
	_sounds[CorvidFlock.Call.CAW] = []
	for pitch: float in [560.0, 610.0, 660.0]:
		_sounds[CorvidFlock.Call.CAW].append(_wave(_voice([[0.36, pitch * 1.08, pitch * 0.82]], 0.32, 0.8, [1250.0, 2300.0], rng, 0.0, 0.0)))
	_sounds[CorvidFlock.Call.ALARM] = []
	for pitch: float in [640.0, 720.0]:
		_sounds[CorvidFlock.Call.ALARM].append(_wave(_voice([[0.24, pitch * 1.12, pitch * 0.8]], 0.5, 0.9, [1400.0, 2600.0], rng, 0.0, 0.0)))
	# A raven's croak: deep, gurgling ("grronk"), rattled by the throat.
	_sounds[CorvidFlock.Call.CROAK] = []
	for pitch: float in [240.0, 280.0]:
		_sounds[CorvidFlock.Call.CROAK].append(_wave(_voice([[0.42, pitch * 0.92, pitch * 1.05]], 0.28, 0.7, [700.0, 1500.0], rng, 0.0, 34.0)))
	# Its knocking: a run of hollow wooden knocks.
	_sounds[CorvidFlock.Call.KNOCK] = [_wave(_knocks(rng))]
	# A blue jay: "jay!" (harsh, falling), the squeaky two-note "queedle", and a red-tailed hawk's scream.
	_sounds[CorvidFlock.Call.JAY] = []
	for pitch: float in [1900.0, 2150.0]:
		_sounds[CorvidFlock.Call.JAY].append(_wave(_voice([[0.26, pitch * 1.1, pitch * 0.82]], 0.42, 0.75, [2600.0, 4200.0], rng, 0.0, 0.0)))
	_sounds[CorvidFlock.Call.QUEEDLE] = [_wave(_voice([[0.09, 1500.0, 1700.0], [0.12, 2300.0, 2100.0]], 0.08, 0.4, [2000.0, 3500.0], rng, 0.0, 0.0))]
	_sounds[CorvidFlock.Call.HAWK] = [_wave(_voice([[0.12, 2600.0, 3100.0], [1.25, 3100.0, 2050.0]], 0.55, 0.85, [2900.0, 4600.0], rng, 0.02, 0.0))]
	_sounds[CorvidFlock.Call.RATTLE] = [_wave(_knocks(rng, 0.03, 2400.0))]
	_sounds["wings"] = [_wave(_wings(rng))]


# A voice: syllables [seconds, pitch at its start, at its end], each its own
# swell; harmonics shaped by two formants, roughened by `noise` (and a jitter in
# the pitch), with `bright` of the upper harmonics; `vibrato` a share of pitch
# wavering on the last syllable; `rattle` (Hz) a throaty flutter in the loudness.
static func _voice(syllables: Array, noise: float, bright: float, formants: Array, rng: RandomNumberGenerator, vibrato: float, rattle: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	var phase := 0.0
	var jitter := 0.0
	var hiss := 0.0
	for s in syllables.size():
		var syllable: Array = syllables[s]
		var count := int(float(syllable[0]) * RATE)
		var gap := int(0.025 * RATE) if s < syllables.size() - 1 else 0
		var mean := (float(syllable[1]) + float(syllable[2])) * 0.5
		var weights: Array[float] = []
		for h in range(1, 9):
			var f := mean * h
			var w := 0.12
			for formant: float in formants:
				w += exp(-pow((f - formant) / (formant * 0.3), 2.0))
			weights.append(w * pow(0.6 + 0.4 * bright, h - 1) / sqrt(h))
		for i in count:
			var t := float(i) / count
			jitter = lerpf(jitter, rng.randf_range(-1.0, 1.0), 0.08)
			var pitch := lerpf(float(syllable[1]), float(syllable[2]), t) * (1.0 + 0.025 * jitter * (1.0 + 5.0 * noise))
			if s == syllables.size() - 1:
				pitch *= 1.0 + vibrato * sin(t * TAU * 7.0) * smoothstep(0.2, 0.5, t)
			phase = fmod(phase + TAU * pitch / RATE, TAU * 64.0)
			var v := 0.0
			for h in weights.size():
				if mean * (h + 1) < RATE * 0.45:
					v += weights[h] * sin(phase * (h + 1))
			# (the harshness: noise shaped by the voice itself, so it rasps rather than hisses)
			hiss = lerpf(hiss, rng.randf_range(-1.0, 1.0), 0.6)
			v += noise * hiss * (0.5 + 0.5 * absf(sin(phase))) * 1.2
			if rattle > 0.0:
				v *= 0.55 + 0.45 * sin(TAU * rattle * float(i) / RATE)
			var swell := smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.6, 1.0, t))
			samples.append(v * swell)
		for i in gap:
			samples.append(0.0)
	return samples


# Hollow knocks: a run of short, resonant clicks, quick, slowing.
static func _knocks(rng: RandomNumberGenerator, spacing := 0.085, tone := 1050.0) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	var many := 5
	samples.resize(int((spacing * many * 1.3 + 0.1) * RATE))
	var at := 0.0
	for k in many:
		var start := int(at * RATE)
		var pitch := tone * rng.randf_range(0.92, 1.08)
		for i in int(0.045 * RATE):
			var t := float(i) / RATE
			var v := sin(TAU * pitch * t) * exp(-t * 85.0) + rng.randf_range(-1.0, 1.0) * exp(-t * 400.0) * 0.6
			if start + i < samples.size():
				samples[start + i] += v
		at += spacing * (1.0 + 0.06 * k)
	return samples


# Wings beating on take-off: three soft thumps of air with a rustle of feathers.
static func _wings(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(0.42 * RATE))
	var low := 0.0
	for k in 3:
		var start := int(k * 0.12 * RATE)
		for i in int(0.11 * RATE):
			var t := float(i) / (0.11 * RATE)
			low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.08)
			var v := low * 2.5 + rng.randf_range(-1.0, 1.0) * 0.25 * (1.0 - t)
			if start + i < samples.size():
				samples[start + i] += v * sin(PI * t) * (1.0 - 0.25 * k)
	return samples


static func _wave(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.001
	for v in samples:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / peak * 0.85, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream

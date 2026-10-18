class_name ChickenVoice
extends Node3D
## The sounds of a ChickenFlock, made in code (no sound files): clucks while they
## forage, squawks when they bolt or leap, and the rooster's crow, heard a long way
## off. Put one in as a child of the flock (`ChickenVoice.new(flock)`) and it plays
## them where the birds are, on a few 3D players of its own.
##
## The sounds are made once (the first time any voice is made) and shared:
## - a cluck: a short low "bok", its pitch falling, in three pitches;
## - a squawk: a harsh, rough "bagawk" that rises and breaks, in two;
## - a crow: "cock-a-doodle-doo", four calls, the last long and wavering.

## How many sounds at once, at most.
const VOICES := 4
const RATE := 16000

static var _clucks: Array[AudioStreamWAV] = []
static var _squawks: Array[AudioStreamWAV] = []
static var _crow: AudioStreamWAV

## How loud, decibels.
@export var volume := -4.0

var _players: Array[AudioStreamPlayer3D] = []
var _next := 0
var _cluck_in := 0.0
var _rng := RandomNumberGenerator.new()


func _init(flock: ChickenFlock = null) -> void:
	name = "Voice"
	if flock:
		flock.clucked.connect(cluck)
		flock.squawked.connect(squawk)
		flock.crowed.connect(crow)


func _ready() -> void:
	_make_sounds()
	top_level = true
	for i in VOICES:
		var player := AudioStreamPlayer3D.new()
		player.unit_size = 3.0
		player.max_distance = 45.0
		player.volume_db = volume
		add_child(player)
		_players.append(player)


func _process(delta: float) -> void:
	_cluck_in -= delta


## A cluck at `at` (no more than four a second from a flock).
func cluck(at: Vector3) -> void:
	if _cluck_in > 0.0 or _clucks.is_empty():
		return
	_cluck_in = 0.25
	_play(_clucks[_rng.randi_range(0, _clucks.size() - 1)], at, _rng.randf_range(0.9, 1.15), 0.0, 3.0, 45.0)


func squawk(at: Vector3) -> void:
	if _squawks.is_empty():
		return
	_play(_squawks[_rng.randi_range(0, _squawks.size() - 1)], at, _rng.randf_range(0.85, 1.2), 3.0, 4.0, 60.0)


## The crow, heard far off (in a maze's mist, from round corners).
func crow(at: Vector3) -> void:
	if _crow:
		_play(_crow, at, _rng.randf_range(0.95, 1.05), 2.0, 12.0, 160.0)


func _play(stream: AudioStreamWAV, at: Vector3, pitch: float, louder: float, unit: float, reach: float) -> void:
	if _players.is_empty():
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume + louder
	player.unit_size = unit
	player.max_distance = reach
	player.global_position = at + Vector3.UP * 0.4
	player.play()


static func _make_sounds() -> void:
	if _crow != null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for pitch: float in [330.0, 380.0, 430.0]:
		_clucks.append(_wave(_call([[0.11, pitch * 1.15, pitch * 0.85]], 0.06, 0.5, [700.0, 1600.0], rng)))
	for pitch: float in [950.0, 1150.0]:
		_squawks.append(_wave(_call([[0.07, pitch * 0.8, pitch * 1.25], [0.32, pitch * 1.3, pitch * 0.7]], 0.3, 0.9, [1400.0, 2800.0], rng)))
	_crow = _wave(_call([[0.17, 560.0, 640.0], [0.12, 700.0, 760.0], [0.2, 800.0, 840.0], [0.85, 860.0, 600.0]], 0.08, 0.75, [1100.0, 2400.0], rng, 0.05))


# A call: syllables [seconds, pitch at its start, at its end], each its own
# swell; a voice of harmonics shaped by two formants, roughened by `noise`
# (and a jitter in its pitch), with `bright` (0..1) of the upper harmonics;
# `vibrato` a share of pitch wavering on the last syllable.
static func _call(syllables: Array, noise: float, bright: float, formants: Array, rng: RandomNumberGenerator, vibrato := 0.0) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	var phase := 0.0
	var jitter := 0.0
	for s in syllables.size():
		var syllable: Array = syllables[s]
		var count := int(float(syllable[0]) * RATE)
		var gap := int(0.03 * RATE) if s < syllables.size() - 1 else 0
		# (each harmonic's weight, by how near it is to a formant: worked out at the syllable's mean pitch)
		var mean := (float(syllable[1]) + float(syllable[2])) * 0.5
		var weights: Array[float] = []
		for h in range(1, 7):
			var f := mean * h
			var w := 0.15
			for formant: float in formants:
				w += exp(-pow((f - formant) / (formant * 0.35), 2.0))
			weights.append(w * pow(0.6 + 0.4 * bright, h - 1) / h)
		for i in count:
			var t := float(i) / count
			jitter = lerpf(jitter, rng.randf_range(-1.0, 1.0), 0.05)
			var pitch := lerpf(float(syllable[1]), float(syllable[2]), t) * (1.0 + 0.02 * jitter * (1.0 + 4.0 * noise))
			if s == syllables.size() - 1:
				pitch *= 1.0 + vibrato * sin(t * TAU * 6.0) * smoothstep(0.2, 0.5, t)
			phase = fmod(phase + TAU * pitch / RATE, TAU * 64.0)
			var v := 0.0
			for h in weights.size():
				v += weights[h] * sin(phase * (h + 1))
			v += noise * rng.randf_range(-1.0, 1.0) * 0.6
			var swell := smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.55, 1.0, t))
			samples.append(v * swell)
		for i in gap:
			samples.append(0.0)
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

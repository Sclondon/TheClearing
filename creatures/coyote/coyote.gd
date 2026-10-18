class_name Coyote
extends Dog
## A coyote: lean and rangy, long-legged, grizzled grey and tan with a cream
## throat and belly, tawny legs and ears, big upright pointed ears, a narrow
## pointed muzzle, yellow eyes, and a bushy black-tipped tail carried low. Its
## look, every move and its voice are here; what it does is for the game to say.
## It knows nothing of the game it is in.
##
## It is the dog (Dog, creatures/dog: needs GameCommon's godot/dog) on a
## coyote's model, so it is driven the same way: move it (its position and its
## rotation about Y: it faces +Z) and it walks, trots (a coyote's loping trot)
## or gallops to match. Everything the dog does it does too (`tracking`,
## `stalking`, `snarling`, `look_at_point`, `sitting`, `lying`, `howl`, `lunge`,
## `bite_hits`, `shake`), and more:
## - `slinking`: low and stiff, the head low and glancing back over its
##   shoulder, the ears flat back and the tail tucked: slinking off.
## - `yip()`: one sharp yip, the head tossed up with it.
## - `chorus(variant, sitting)`: a run of yips going up into a wavering howl
##   and breaking back into yips, about three seconds, the jaw keeping time
##   with it. Several coyotes doing it at once, each its own `variant`, is the
##   yip-howl chorus of a pack.
##
## It makes its own sounds (made in code: nothing to load), from where it is,
## unless `sound` is off; the signals `yipped` and `chorused` say when.
##
## It is drawn by CoyoteRig (coyote_rig.gd, which extends the dog's DogRig) on
## one of two models (`variant`: 0 greyer, 1 redder and slighter, a notch out of
## one ear; made by tools/build_coyote.py), with CoyoteLook's materials.

signal yipped
signal chorused

## Plays its yips and howls (made in code) from where it is.
@export var sound := true
@export var volume_db := -2.0
## How far off it is heard (world units): a chorus carries.
@export var sound_range := 90.0

## Slinking off: low, ears back, tail tucked, glancing back.
var slinking := false

## The yips of a chorus still to come (seconds from its start), and how far into it it is.
var _yips_left: Array[float] = []
var _chorus_time := INF
var _voice: AudioStreamPlayer3D

## The sounds, made once and shared: a yip, and a few choruses (each with its yips' times).
static var _yip: AudioStreamWAV
static var _choruses: Array[AudioStreamWAV] = []
static var _chorus_yips: Array[Array] = []
static var _chorus_howls: Array[Vector2] = []
## How many different choruses there are.
const CHORUSES := 3


func _ready() -> void:
	rig = CoyoteRig.new()
	rig.name = "Rig"
	rig.variant = variant
	rig.low_poly = low_poly
	rig.fur_shells = fur_shells
	rig.coat_tint = coat_tint
	rig.mange = 0.0
	rig.eyeshine = eyeshine
	add_child(rig)
	if sound:
		_voice = AudioStreamPlayer3D.new()
		_voice.volume_db = volume_db
		_voice.unit_size = 10.0
		_voice.max_distance = sound_range
		_voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		_voice.position = Vector3(0.0, 0.8, 0.45)
		add_child(_voice)


func _process(delta: float) -> void:
	super(delta)
	if _chorus_time < INF:
		_chorus_time += delta
		while not _yips_left.is_empty() and _chorus_time >= _yips_left[0]:
			_yips_left.pop_front()
			if rig:
				(rig as CoyoteRig).yip()
		if _yips_left.is_empty() and not howling():
			_chorus_time = INF


## One sharp yip.
func yip() -> void:
	if rig:
		(rig as CoyoteRig).yip()
	yipped.emit()
	if _voice:
		_voice.stream = yip_sound()
		_voice.pitch_scale = randf_range(0.9, 1.12)
		_voice.play()


## A run of yips going up into a wavering howl and breaking into yips again
## (`variant` picks which, 0 .. CHORUSES - 1; -1 any), sitting to it or not.
func chorus(which := -1, sitting := false) -> void:
	if which < 0:
		which = randi() % CHORUSES
	which = which % CHORUSES
	var stream := chorus_sound(which)
	_yips_left.clear()
	for at: float in _chorus_yips[which]:
		_yips_left.append(at)
	_chorus_time = 0.0
	var howl_at: Vector2 = _chorus_howls[which]
	sit_to_howl = sitting
	# (the howl in the middle of it: the head goes back while it lasts)
	get_tree().create_timer(howl_at.x, false).timeout.connect(func() -> void:
		if is_inside_tree() and _chorus_time < INF:
			howl(howl_at.y))
	chorused.emit()
	if _voice:
		_voice.stream = stream
		_voice.pitch_scale = randf_range(0.94, 1.08)
		_voice.play()


## Whether it is in a chorus.
func chorusing() -> bool:
	return _chorus_time < INF


## Stops a chorus (and its sound).
func hush() -> void:
	_yips_left.clear()
	_chorus_time = INF
	if _voice:
		_voice.stop()


# --- The voice, made in code ---

const RATE := 22050
## How strong each harmonic of a yip is.
const YIP_HARMONICS: Array[float] = [1.0, 0.62, 0.38, 0.22, 0.12, 0.06]


## One yip: a short, sharp, nasal bark that leaps up in pitch and drops.
static func yip_sound() -> AudioStreamWAV:
	if _yip == null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var samples := PackedFloat32Array()
		samples.resize(int(RATE * 0.2))
		var state := {"phase": 0.0}
		_add_yip(samples, 0.0, 1.0, 1.0, rng, state)
		_yip = _wav(_echoed(samples, 0.0))
	return _yip


## A chorus (see `chorus`), and when its yips fall and its howl is.
static func chorus_sound(which: int) -> AudioStreamWAV:
	while _choruses.size() < CHORUSES:
		_make_chorus(_choruses.size())
	return _choruses[which]


static func _make_chorus(which: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 101 + which * 17
	var length := 3.4
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * length))
	var state := {"phase": 0.0}
	var yips: Array[float] = []
	var t := 0.05
	# A run of yips, each a little higher...
	var count := rng.randi_range(4, 6)
	for k in count:
		var lift := 1.0 + 0.08 * k + rng.randf_range(-0.05, 0.05)
		_add_yip(samples, t, lift, rng.randf_range(0.75, 1.0), rng, state)
		yips.append(t)
		t += rng.randf_range(0.13, 0.22)
	# ...going up into a howl that wavers and breaks...
	var howl_from := t
	var howl_for := rng.randf_range(1.0, 1.35)
	_add_howl(samples, t, howl_for, rng.randf_range(0.95, 1.1), rng, state)
	t += howl_for + 0.05
	# ...and breaking back into yips, and a last short yelp of a howl.
	for k in rng.randi_range(2, 4):
		_add_yip(samples, t, rng.randf_range(1.05, 1.3), rng.randf_range(0.6, 0.9), rng, state)
		yips.append(t)
		t += rng.randf_range(0.12, 0.18)
	_add_howl(samples, t, 0.32, 1.25, rng, state)
	_choruses.append(_wav(_echoed(samples, 0.32)))
	_chorus_yips.append(yips)
	_chorus_howls.append(Vector2(howl_from, howl_for))


## Adds a yip at `at` seconds: a harmonic voice whose pitch leaps up and falls,
## through a nasal resonance, with a breathy start.
static func _add_yip(samples: PackedFloat32Array, at: float, pitch: float, loud: float, rng: RandomNumberGenerator, state: Dictionary) -> void:
	var length := rng.randf_range(0.1, 0.15)
	var start := int(at * RATE)
	var nasal := Band.new(1900.0 * pitch, 2.5, RATE)
	var breath := Band.new(2600.0, 1.5, RATE)
	var phase: float = state["phase"]
	for i in int(length * RATE):
		var index := start + i
		if index >= samples.size():
			break
		var u := float(i) / (length * RATE)
		var f := (720.0 + 820.0 * sin(PI * pow(u, 0.55)) - 180.0 * u) * pitch
		phase += f / RATE
		var voice := 0.0
		for k in 6:
			voice += sin(TAU * phase * (k + 1)) * YIP_HARMONICS[k]
		var envelope := smoothstep(0.0, 0.06, u) * pow(1.0 - u, 1.6)
		var air := breath.run(rng.randf_range(-1.0, 1.0)) * (1.0 - smoothstep(0.0, 0.3, u)) * 0.8
		samples[index] += (voice * 0.55 + nasal.run(voice) * 0.9 + air) * envelope * loud
	state["phase"] = phase


## Adds a howl at `at`, `length` long: a purer, rising, wavering voice that
## breaks (jumps up and comes back) as it goes, and falls away at its end.
static func _add_howl(samples: PackedFloat32Array, at: float, length: float, pitch: float, rng: RandomNumberGenerator, state: Dictionary) -> void:
	var start := int(at * RATE)
	var throat := Band.new(1300.0 * pitch, 3.0, RATE)
	var breaks: Array[Vector2] = []
	for k in rng.randi_range(1, 3):
		breaks.append(Vector2(rng.randf_range(0.25, 0.8), rng.randf_range(0.04, 0.09)))
	var phase: float = state["phase"]
	var wander := 0.0
	for i in int(length * RATE):
		var index := start + i
		if index >= samples.size():
			break
		var t := float(i) / RATE
		var u := t / length
		wander = clampf(wander + rng.randf_range(-1.0, 1.0) * 0.004, -0.6, 0.6)
		var f := (560.0 + 420.0 * smoothstep(0.0, 0.3, u) - 260.0 * smoothstep(0.7, 1.0, u)) * pitch
		f *= 1.0 + 0.035 * sin(TAU * 5.6 * t) + 0.04 * wander
		for b in breaks:
			if u > b.x and u < b.x + b.y / length:
				f *= 1.32
		phase += f / RATE
		var voice := sin(TAU * phase) + 0.34 * sin(TAU * phase * 2.0) + 0.14 * sin(TAU * phase * 3.0) + 0.05 * sin(TAU * phase * 4.0)
		var envelope := smoothstep(0.0, 0.12, u) * (1.0 - smoothstep(0.78, 1.0, u))
		samples[index] += (voice * 0.6 + throat.run(voice) * 0.4 + rng.randf_range(-1.0, 1.0) * 0.03) * envelope * 0.75
	state["phase"] = phase


## The sound thrown back off the walls: a couple of quieter copies, later.
static func _echoed(samples: PackedFloat32Array, amount: float) -> PackedFloat32Array:
	if amount <= 0.0:
		return samples
	var out := samples.duplicate()
	for echo: Vector2 in [Vector2(0.11, 0.45), Vector2(0.23, 0.25), Vector2(0.41, 0.12)]:
		var gap := int(echo.x * RATE)
		for i in range(gap, out.size()):
			out[i] += samples[i - gap] * echo.y * amount * 2.0
	return out


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var loudest := 0.001
	for value in samples:
		loudest = maxf(loudest, absf(value))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / loudest, -1.0, 1.0) * 29000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream


## A resonant band-pass filter (a biquad), for the voice.
class Band:
	var _b0 := 0.0
	var _a1 := 0.0
	var _a2 := 0.0
	var _x1 := 0.0
	var _x2 := 0.0
	var _y1 := 0.0
	var _y2 := 0.0

	func _init(frequency: float, q: float, rate: int) -> void:
		var w := TAU * minf(frequency, rate * 0.45) / rate
		var alpha := sin(w) / (2.0 * q)
		var a0 := 1.0 + alpha
		_b0 = alpha / a0
		_a1 = -2.0 * cos(w) / a0
		_a2 = (1.0 - alpha) / a0

	func run(x: float) -> float:
		var y := _b0 * x - _b0 * _x2 - _a1 * _y1 - _a2 * _y2
		_x2 = _x1
		_x1 = x
		_y2 = _y1
		_y1 = y
		return y

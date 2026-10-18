class_name Fox
extends Dog
## A red fox: small and slight, long and low on slender black-stockinged legs,
## rust red with a white bib and chin, big black-backed ears, a fine pointed
## muzzle, amber eyes, and a great bushy brush of a tail with a white tip. Its
## look, every move and its voice are here; what it does is for the game to
## say. It knows nothing of the game it is in.
##
## It is the dog (Dog, creatures/dog: needs GameCommon's godot/dog) on a fox's
## model, so it is driven the same way: move it (its position and its rotation
## about Y: it faces +Z) and it walks, trots (the fox's light, straight trot,
## the brush held out level behind) or gallops to match. Everything the dog
## does it does too (`tracking`, `stalking`, `look_at_point`, `sitting`,
## `lying`, `lunge`, `shake`), and more:
## - `listening`: stock-still, ears pricked forward and the head cocked to one
##   side then the other: listening for a mouse in the grass.
## - `pounce(at)`: the mousing pounce. It gathers itself, the rump wiggling
##   (CROUCH), springs high into the air and comes down nose first, forepaws
##   together (LEAP: move it each frame by `pounce_push()`), pins whatever it
##   came down on with its forepaws, nose in the grass (PIN), and gets up
##   (RISE). `pounce_stage()`, `pounce_progress()`, `pounce_lift()` (how high
##   off the ground it is), `pounce_spot()`.
## - `carrying`: something held in its jaws (they are a little open, the head
##   carried higher); `jaw_position()` is where to put it.
## - `bark()`: the fox's bark, a run of hoarse high "wow"s, each with a jerk of
##   the head. `scream()`: the vixen's scream, a long, hoarse, eerie cry, the
##   head lifted with it.
## Sitting, its brush is wrapped round its forefeet; curled up lying, round its nose.
##
## It makes its own sounds (made in code: nothing to load), from where it is,
## unless `sound` is off; the signals `barked`, `screamed`, `pounced` and
## `pinned` say when.
##
## It is drawn by FoxRig (fox_rig.gd, which extends the dog's DogRig) on one of
## two models (`variant`: 0 the redder dog fox, 1 the slighter, paler vixen
## with a notch out of one ear; made by tools/build_fox.py), with FoxLook's
## materials.

signal screamed
## It has sprung, at `at`.
signal pounced(at: Vector3)
## It has come down on `at` and pinned it.
signal pinned(at: Vector3)

enum Pounce { NONE, CROUCH, LEAP, PIN, RISE }

## Seconds each part of the pounce takes.
const CROUCH_TIME := 0.5
const LEAP_TIME := 0.62
const PIN_TIME := 0.75
const RISE_TIME := 0.35

## Plays its barks and screams (made in code) from where it is.
@export var sound := true
@export var volume_db := -6.0
## How far off it is heard (world units): a scream carries.
@export var sound_range := 70.0
## How far it pounces at least and at most, and how high the top of the arc is (m, in the world).
@export var pounce_reach := Vector2(1.0, 4.2)
@export var pounce_height := 0.7

## Listening for something in the grass: still, ears forward, head cocked.
var listening := false
## Something held in its jaws.
var carrying := false

var _pounce_time := INF
var _pounce_from := Vector3.ZERO
var _pounce_way := Vector3.FORWARD
var _pounce_span := 0.0
var _barks_left: Array[float] = []
var _bark_time := INF
var _voice: AudioStreamPlayer3D

## The sounds, made once and shared.
static var _barks: Array[AudioStreamWAV] = []
static var _bark_times: Array[Array] = []
static var _scream: AudioStreamWAV
## How many different runs of barks there are.
const BARKINGS := 3


func _ready() -> void:
	rig = FoxRig.new()
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
		_voice.unit_size = 8.0
		_voice.max_distance = sound_range
		_voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		_voice.position = Vector3(0.0, 0.6, 0.45)
		add_child(_voice)


func _process(delta: float) -> void:
	super(delta)
	if _pounce_time < INF:
		var was := pounce_stage()
		_pounce_time += delta
		var now := pounce_stage()
		if now != was:
			if now == Pounce.LEAP:
				pounced.emit(pounce_spot())
			elif now == Pounce.PIN:
				pinned.emit(pounce_spot())
		if now == Pounce.NONE:
			_pounce_time = INF
		# (in the air it is off the ground, whatever the game says)
		if now == Pounce.LEAP:
			grounded = false
	if _bark_time < INF:
		_bark_time += delta
		while not _barks_left.is_empty() and _bark_time >= _barks_left[0]:
			_barks_left.pop_front()
			if rig:
				rig.bark()
		if _barks_left.is_empty():
			_bark_time = INF


func settle() -> void:
	super()
	_pounce_time = INF


# --- The pounce ---

## The mousing pounce at `at` (in the world): it gathers itself, springs high
## and comes down nose first on it (as near as it can within `pounce_reach`).
## Not while it is pouncing or lunging already.
func pounce(at: Vector3) -> void:
	if _pounce_time < INF or busy():
		return
	var to := at - global_position
	to.y = 0.0
	_pounce_from = global_position
	_pounce_way = to.normalized() if to.length() > 0.01 else global_basis.z.normalized()
	# (its forepaws come down a little ahead of its middle)
	_pounce_span = clampf(to.length() - 0.25 * global_basis.get_scale().x, pounce_reach.x, pounce_reach.y)
	_pounce_time = 0.0
	listening = false


func pounce_stage() -> Pounce:
	if _pounce_time == INF:
		return Pounce.NONE
	var t := _pounce_time
	if t < CROUCH_TIME:
		return Pounce.CROUCH
	t -= CROUCH_TIME
	if t < LEAP_TIME:
		return Pounce.LEAP
	t -= LEAP_TIME
	if t < PIN_TIME:
		return Pounce.PIN
	t -= PIN_TIME
	return Pounce.RISE if t < RISE_TIME else Pounce.NONE


## How far through the part of the pounce it is in, 0..1.
func pounce_progress() -> float:
	match pounce_stage():
		Pounce.CROUCH:
			return _pounce_time / CROUCH_TIME
		Pounce.LEAP:
			return (_pounce_time - CROUCH_TIME) / LEAP_TIME
		Pounce.PIN:
			return (_pounce_time - CROUCH_TIME - LEAP_TIME) / PIN_TIME
		Pounce.RISE:
			return (_pounce_time - CROUCH_TIME - LEAP_TIME - PIN_TIME) / RISE_TIME
	return 0.0


## The way it should be moving through the world just now while it pounces:
## nothing but in the air, where it goes the whole span of the leap.
func pounce_push() -> Vector3:
	if pounce_stage() == Pounce.LEAP:
		return _pounce_way * _pounce_span / LEAP_TIME
	return Vector3.ZERO


## How high off the ground it is in the leap (m, in the world).
func pounce_lift() -> float:
	if pounce_stage() != Pounce.LEAP:
		return 0.0
	var u := pounce_progress()
	# (up steeply, and down more steeply still: nose first)
	return pounce_height * 4.0 * u * (1.0 - u) * (1.0 + 0.25 * (1.0 - u))


## Where it comes down (in the world).
func pounce_spot() -> Vector3:
	return _pounce_from + _pounce_way * _pounce_span


## The way it pounces (flat, in the world).
func pounce_way() -> Vector3:
	return _pounce_way


## Pouncing, lunging or shaking: too taken up to do anything else.
func pouncing() -> bool:
	return _pounce_time < INF


# --- The voice ---

## The fox's bark: a run of hoarse high barks.
func bark() -> void:
	bark_run(-1)


## One of the runs of barks (`which`, 0 .. BARKINGS - 1; -1 any).
func bark_run(which := -1) -> void:
	if which < 0:
		which = randi() % BARKINGS
	which = which % BARKINGS
	var stream := bark_sound(which)
	_barks_left.clear()
	for at: float in _bark_times[which]:
		_barks_left.append(at)
	_bark_time = 0.0
	barked.emit()
	if _voice:
		_voice.stream = stream
		_voice.pitch_scale = randf_range(0.94, 1.08)
		_voice.play()


## The vixen's scream: a long, hoarse, wavering cry, the head lifted with it.
func scream() -> void:
	sit_to_howl = false
	howl(1.3)
	screamed.emit()
	if _voice:
		_voice.stream = scream_sound()
		_voice.pitch_scale = randf_range(0.95, 1.05)
		_voice.play()


## Stops its voice.
func hush() -> void:
	_barks_left.clear()
	_bark_time = INF
	if _voice:
		_voice.stop()


const RATE := 22050


## A run of barks (see `bark`), and when each falls in it.
static func bark_sound(which: int) -> AudioStreamWAV:
	while _barks.size() < BARKINGS:
		_make_barks(_barks.size())
	return _barks[which]


static func _make_barks(which: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 211 + which * 31
	var count := rng.randi_range(2, 4)
	var length := 0.25 + count * 0.42
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * length))
	var times: Array[float] = []
	var t := 0.04
	for k in count:
		_add_bark(samples, t, rng.randf_range(0.95, 1.1) * (1.0 - 0.03 * k), rng.randf_range(0.8, 1.0), rng)
		times.append(t)
		t += rng.randf_range(0.34, 0.5)
	_barks.append(_wav(_echoed(samples, 0.35)))
	_bark_times.append(times)


## Adds a bark at `at`: a short hoarse "wow", rising and falling, rough with breath.
static func _add_bark(samples: PackedFloat32Array, at: float, pitch: float, loud: float, rng: RandomNumberGenerator) -> void:
	var length := rng.randf_range(0.13, 0.18)
	var start := int(at * RATE)
	var throat := Band.new(1500.0 * pitch, 2.2, RATE)
	var rasp := Band.new(2900.0, 1.4, RATE)
	var phase := 0.0
	for i in int(length * RATE):
		var index := start + i
		if index >= samples.size():
			break
		var u := float(i) / (length * RATE)
		var f := (560.0 + 520.0 * sin(PI * pow(u, 0.6)) - 160.0 * u) * pitch
		phase += f / RATE
		var voice := 0.0
		for k in 5:
			voice += sin(TAU * phase * (k + 1)) / (k + 1.0)
		# (hoarse: the voice beats against noise)
		var noise := rng.randf_range(-1.0, 1.0)
		var envelope := smoothstep(0.0, 0.08, u) * pow(1.0 - u, 1.3)
		samples[index] += (voice * 0.45 + throat.run(voice) * 0.8 + rasp.run(noise) * 0.9 * (0.5 + 0.5 * sin(TAU * phase * 0.5))) * envelope * loud


## The scream: a long cry that climbs, wavers and breaks, hoarse all through.
static func scream_sound() -> AudioStreamWAV:
	if _scream == null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		var length := 1.35
		var samples := PackedFloat32Array()
		samples.resize(int(RATE * length))
		var throat := Band.new(1700.0, 2.0, RATE)
		var rasp := Band.new(3200.0, 1.2, RATE)
		var phase := 0.0
		var wander := 0.0
		var cry := length - 0.15
		for i in int(cry * RATE):
			var t := float(i) / RATE
			var u := t / cry
			wander = clampf(wander + rng.randf_range(-1.0, 1.0) * 0.006, -0.7, 0.7)
			var f := (820.0 + 380.0 * smoothstep(0.0, 0.25, u) - 300.0 * smoothstep(0.6, 1.0, u)) * (1.0 + 0.05 * sin(TAU * 7.0 * t) + 0.05 * wander)
			# (it cracks up now and then)
			if fposmod(u * 3.3, 1.0) < 0.06:
				f *= 1.35
			phase += f / RATE
			var voice := sin(TAU * phase) + 0.55 * sin(TAU * phase * 2.0) + 0.35 * sin(TAU * phase * 3.0) + 0.2 * sin(TAU * phase * 4.0)
			var envelope := smoothstep(0.0, 0.06, u) * (1.0 - smoothstep(0.7, 1.0, u))
			var noise := rng.randf_range(-1.0, 1.0)
			samples[i] += (voice * 0.35 + throat.run(voice) * 0.6 + rasp.run(noise) * 1.4) * envelope
		_scream = _wav(_echoed(samples, 0.4))
	return _scream


static func _echoed(samples: PackedFloat32Array, amount: float) -> PackedFloat32Array:
	if amount <= 0.0:
		return samples
	var out := samples.duplicate()
	for echo: Vector2 in [Vector2(0.12, 0.45), Vector2(0.25, 0.25), Vector2(0.43, 0.12)]:
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
		data.encode_s16(i * 2, int(clampf(samples[i] / loudest, -1.0, 1.0) * 26000.0))
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

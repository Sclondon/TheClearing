class_name Deinonychus
extends Node3D
## A deinonychus (Deinonychus antirrhopus) as the bones and its living
## relatives say it was, not the film raptor: about 3.3 m from snout to tail
## tip and hip-high to a man, most of that a stiff tail held straight out for
## balance; a deep narrow body, an S of a neck, a long narrow skull with a big
## gold eye and lips over its teeth. Fully feathered, dark grey-brown with a
## dark mask through the eye, a paler throat and belly and a barred tail; its
## arms are folded wings (the palms facing in: it cannot turn them down), and
## a fan of long feathers spreads flat either side of the end of its tail. It
## walks on two toes of each foot, the second toe held up with its great
## sickle claw off the ground. Its look, its moves and its calls are here;
## what it does is for the game to say. It knows nothing of the game it is in.
##
## HOW TO DRIVE IT. Put it in the world and move it (its position and its
## rotation about Y: it faces +Z). It works out how fast it is going from how
## it is moved (or set `measure_velocity` false and set `velocity`), and walks
## or runs to match, its feet planted where they come down; slowing hard it
## brakes, sat back on its legs with its tail up. Set `grounded` false while it
## is in the air. The model is life size.
##
## Then say what it is doing:
## - `look_at_point`: what it watches (INF for nothing): its head snaps round
##   to it in a bird's quick jerks. `cocking`: it cocks its head to one side
##   to look with one eye (curious); it does now and then anyway.
## - `crouching`: low and long on bent legs (stalking).
## - `tired`: panting, jaw open, chest heaving.
## - `hoot(pitch)`: a closed-mouth call, its throat swelling; `click()`: the
##   jaw clacked two or three times; `hiss()`: jaw wide, head thrust low.
## - `pounce()`: the wind-up (WIND_UP s: a crouch, its head low and fixed, the
##   tail flicking, a hiss), then the leap (`leapt`: move it through the air
##   now, LEAP_TIME s, with `grounded` false), then it lands. `pounce_stage()`
##   says where in it it is. Landing on what it wanted, call `pin()`: down on
##   it, the sickle claws driving in and the wings spread and beating to keep
##   its balance, for PIN_TIME s. Missing, call `stumble()`.
## - `claws_hit(point)`: whether its feet and sickle claws (or its jaws) are on
##   `point`, for the game to say whether a pounce has caught something.
##
## Signals say when it does each, and `footfall(at, weight)` when a foot comes
## down. It plays its own sounds (made here in code, no files) unless `sound`
## is off.
##
## It is drawn by DeinonychusRig (deinonychus_rig.gd) on the model made by
## tools/build_deinonychus.py, with DeinonychusLook's materials: a few draws,
## and fewer with `low_poly`.

signal hooted
signal clicked
signal hissed
## The wind-up is over: it has sprung.
signal leapt
## A foot has come down.
signal footfall(at: Vector3, weight: float)

## The demade, low-poly model, without feather shells. Set before it enters the tree.
@export var low_poly := false
## Layers of feather tips stood off its outline (each is one more draw of its coat). Set before it enters the tree.
@export_range(0, 3) var plume_shells := 2
## Multiplies the colours of its plumage. Set before it enters the tree.
@export var tint := Color.WHITE
## How brightly its eyes give back the light.
@export_range(0.0, 2.0) var eyeshine := 0.4
## Works out `velocity` from how it is moved (else the game sets it).
@export var measure_velocity := true
@export_group("Sound")
## Plays its own calls (and its running feet).
@export var sound := true
@export var volume_db := 0.0
## How far off it can be heard (m).
@export var sound_range := 60.0
## Its voice, higher or lower than the others' (1 the middle).
@export var voice := 1.0

## How fast it is going, in the world.
var velocity := Vector3.ZERO
## Whether its feet are on the ground.
var grounded := true
## What it watches, in the world (INF: nothing).
var look_at_point := Vector3.INF
var cocking := false
var crouching := false
var tired := false
var rig: DeinonychusRig

var _was_at := Vector3.INF
var _voice: AudioStreamPlayer3D
var _feet: AudioStreamPlayer3D
var _sprung := true

const WIND_UP := DeinonychusRig.WIND_UP
const LEAP_TIME := DeinonychusRig.LEAP_TIME
const LAND_TIME := DeinonychusRig.LAND_TIME
const PIN_TIME := DeinonychusRig.PIN_TIME

static var _hoot: AudioStreamWAV
static var _clicks: AudioStreamWAV
static var _hiss: AudioStreamWAV
static var _step: AudioStreamWAV


func _ready() -> void:
	rig = DeinonychusRig.new()
	rig.name = "Rig"
	rig.low_poly = low_poly
	rig.plume_shells = plume_shells
	rig.tint = tint
	rig.eyeshine = eyeshine
	add_child(rig)
	rig.footfall.connect(_on_footfall)
	if sound:
		_voice = AudioStreamPlayer3D.new()
		_voice.position = Vector3(0.0, 1.2, 0.8)
		_voice.unit_size = 10.0
		_voice.max_distance = sound_range
		_voice.volume_db = volume_db
		add_child(_voice)
		_feet = AudioStreamPlayer3D.new()
		_feet.unit_size = 6.0
		_feet.max_distance = sound_range * 0.5
		_feet.max_polyphony = 3
		_feet.stream = step_sound()
		add_child(_feet)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if measure_velocity:
		var at := global_position
		if _was_at.is_finite():
			var moved := (at - _was_at) / delta
			if moved.length() > 60.0:
				# (put somewhere: not a speed)
				settle()
			else:
				velocity = velocity.lerp(moved, 1.0 - exp(-16.0 * delta))
		_was_at = at
	if not _sprung and rig and rig.pounce_stage() == DeinonychusRig.Pounce.LEAP:
		_sprung = true
		leapt.emit()


## Stands it still where it is, with nothing in motion: for when it is put somewhere.
func settle() -> void:
	velocity = Vector3.ZERO
	_was_at = global_position
	if rig:
		rig.settle()


## A call to the others of its pack: a soft, booming hoot with its beak shut,
## the throat swelling with it. `pitch` above 1 higher (an answer), below lower.
func hoot(pitch := 1.0) -> void:
	if rig:
		rig.hoot(pitch)
	_say(hoot_sound(), 0.0, voice * pitch * randf_range(0.96, 1.04))
	hooted.emit()


## Two or three hard clacks of its jaws.
func click() -> void:
	if rig:
		rig.click()
	_say(click_sound(), -3.0, voice * randf_range(0.92, 1.1))
	clicked.emit()


## A hiss, jaws wide.
func hiss() -> void:
	if rig:
		rig.hiss()
	_say(hiss_sound(), 0.0, voice * randf_range(0.95, 1.05))
	hissed.emit()


## The wind-up (and a hiss), then the leap: see the top of this file.
func pounce() -> void:
	if rig:
		rig.pounce()
	_sprung = false
	_say(hiss_sound(), 1.0, voice * randf_range(1.05, 1.15))
	hissed.emit()


func pounce_stage() -> DeinonychusRig.Pounce:
	return rig.pounce_stage() if rig else DeinonychusRig.Pounce.NONE


func pin() -> void:
	if rig:
		rig.pin()


func pinning() -> bool:
	return rig != null and rig.pinning()


func stumble() -> void:
	if rig:
		rig.stumble()


## Pouncing, pinning or stumbling: too taken up to do anything else.
func busy() -> bool:
	return rig != null and (rig.pounce_stage() != DeinonychusRig.Pounce.NONE or rig.pinning() or rig.stumbling())


## Where the point of a sickle claw is, in the world (`side` 0 its left, 1 its right).
func claw_tip(side: int) -> Vector3:
	return rig.claw_tip(side) if rig else global_position


func snout_tip() -> Vector3:
	return rig.snout_tip() if rig else global_position


## Whether its feet and claws, or its jaws, are on `point` (in the world):
## within `radius` (m, at a scale of 1) of a line from one sickle claw to the
## other, or of the tip of its snout.
func claws_hit(point: Vector3, radius := 0.45) -> bool:
	var size := global_basis.get_scale().x
	var left := claw_tip(0)
	var right := claw_tip(1)
	var ab := right - left
	var t := clampf((point - left).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	var near := point.distance_to(left + ab * t)
	near = minf(near, point.distance_to(snout_tip()) * 1.3)
	return near < radius * size


func _on_footfall(at: Vector3, weight: float) -> void:
	if _feet and weight > 0.35:
		_feet.volume_db = volume_db - 16.0 + 10.0 * weight
		_feet.pitch_scale = randf_range(0.9, 1.15)
		_feet.play()
	footfall.emit(at, weight)


func _say(stream: AudioStreamWAV, gain: float, pitch: float) -> void:
	if _voice == null:
		return
	_voice.stream = stream
	_voice.volume_db = volume_db + gain
	_voice.pitch_scale = pitch
	_voice.play()


# --- Sounds, made in code ---

const RATE := 22050


## A hoot: a low, booming, closed-mouth call (as an emu's or a cassowary's
## boom, or a dove's coo much deeper): "hoo-oo", rising and falling, through
## the resonance of a swollen throat, with a little roughness in it.
static func hoot_sound() -> AudioStreamWAV:
	if _hoot:
		return _hoot
	var length := 1.0
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * length))
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var throat := Band.new(320.0, 3.0)
	var chest := Band.new(140.0, 2.0)
	var phase := 0.0
	var rough := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		# (two swells: a short one and a long one, the second higher, then falling)
		var first := smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.18, 0.3, t))
		var second := smoothstep(0.3, 0.4, t) * (1.0 - smoothstep(0.7, 0.98, t))
		var level := first * 0.8 + second
		var pitch := (118.0 + 20.0 * smoothstep(0.0, 0.2, t)) * (1.0 - second) + (150.0 - 32.0 * smoothstep(0.45, 0.95, t)) * second
		pitch *= 1.0 + 0.012 * sin(TAU * 5.5 * t)
		phase += pitch / RATE
		rough = lerpf(rough, rng.randf_range(-1.0, 1.0), 0.08)
		var p := fposmod(phase, 1.0)
		var pulse := sin(TAU * p) + 0.45 * sin(TAU * p * 2.0) + 0.18 * sin(TAU * p * 3.0)
		var value := throat.run(pulse) * 1.2 + chest.run(pulse) * 0.9 + pulse * 0.25 + rough * 0.06
		samples[i] = tanh(value * level * 1.6)
	_hoot = _wave(samples)
	return _hoot


## Its clicks: three hard clacks of its jaws, each a crack with a short knock
## in it, quickly one after another.
static func click_sound() -> AudioStreamWAV:
	if _clicks:
		return _clicks
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * 0.45))
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for at: float in [0.0, 0.13, 0.27]:
		var crack := Band.new(2600.0 + rng.randf_range(-300.0, 300.0), 2.5)
		var knock := Band.new(780.0, 6.0)
		var start := int(at * RATE)
		for i in int(RATE * 0.05):
			var index := start + i
			if index >= samples.size():
				break
			var t := float(i) / RATE
			var noise := rng.randf_range(-1.0, 1.0) * exp(-t * 900.0)
			samples[index] += crack.run(noise) * 2.2 + knock.run(noise) * 3.0 * exp(-t * 120.0)
	_clicks = _wave(samples)
	return _clicks


## A hiss: a long breath forced out through an open throat, with a low growl under it.
static func hiss_sound() -> AudioStreamWAV:
	if _hiss:
		return _hiss
	var length := 0.8
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * length))
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	var air := Band.new(3600.0, 0.9)
	var throat := Band.new(1200.0, 1.5)
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		var level := smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.5, length, t))
		var noise := rng.randf_range(-1.0, 1.0)
		phase += (62.0 + 8.0 * sin(t * 9.0)) / RATE
		var growl := (pow(1.0 - fposmod(phase, 1.0), 4.0) - 0.2) * 0.6
		samples[i] = tanh((air.run(noise) * 1.4 + throat.run(noise) * 0.6 + growl * (0.5 + 0.5 * noise)) * level * 1.8)
	_hiss = _wave(samples)
	return _hiss


## A running foot coming down: a soft thud and a scuff of grit.
static func step_sound() -> AudioStreamWAV:
	if _step:
		return _step
	var samples := PackedFloat32Array()
	samples.resize(int(RATE * 0.16))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var scuff := Band.new(1500.0, 0.8)
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		phase += lerpf(140.0, 60.0, minf(t / 0.06, 1.0)) / RATE
		samples[i] = tanh((sin(TAU * phase) * exp(-t * 40.0) + scuff.run(rng.randf_range(-1.0, 1.0)) * exp(-t * 55.0) * 0.8) * 1.5)
	_step = _wave(samples)
	return _step


static func _wave(samples: PackedFloat32Array) -> AudioStreamWAV:
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

	func _init(frequency: float, q: float) -> void:
		var w := TAU * minf(frequency, RATE * 0.45) / RATE
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

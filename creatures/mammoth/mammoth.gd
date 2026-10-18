class_name Mammoth
extends Node3D
## A woolly mammoth: a grown cow (2.9 m at the shoulder; scale it for a bigger
## or smaller one) or a calf (`calf`: its own model, all fuzz and no tusks).
## True to the frozen ones: the high domed head, a notch behind it, the hump
## over the shoulders and the back sloping steeply away, small furred ears, the
## long heavy ringed trunk with its two fingers, the great spiralling tusks, the
## column legs, and the long shaggy brown-grey coat hanging in a skirt that
## sways as it goes. Its look and every move are here; what it does is for the
## game to say. It knows nothing of the game it is in.
##
## HOW TO DRIVE IT. Put it in the world and move it (its position and its
## rotation about Y: it faces +Z). It works out how fast it is going from how
## it is moved (or set `measure_velocity` false and set `velocity`), and walks
## or ambles to match, its feet planted at its feet. Then say what it is doing
## (each eases in and out):
## - `look_at_point`: what it watches (INF for nothing): its head turns to it
##   (a little: its neck is short).
## - `grazing`: head down, the trunk pulling up grass and putting it in its mouth.
## - `feeling`: the trunk raised and reaching out to `look_at_point`, sniffing.
## - `alert`: head up, ears out.
## - `ears_out`: ears spread wide (a display).
## - `lowered`: head down, tusks forward, trunk curled up out of the way (a charge).
## - `trumpet()`: the trunk thrown up, and the blare; `trumpeting()`.
## - `rumble()`: a low rumble, felt more than heard (the herd's alarm).
## - `stamp()`: a forefoot raised and brought down hard.
##
## Signals say when it trumpets, rumbles and stamps; with `sound` on it makes
## the sounds too (made in code, nothing to load). It is drawn by MammothRig
## (mammoth_rig.gd) on its model (made by tools/build_mammoth.py) with
## MammothLook's materials.

signal trumpeted
signal rumbled
signal stamped

## Seconds a trumpet takes.
const TRUMPET_TIME := 2.0

## A calf. Set before it enters the tree.
@export var calf := false
## The demade, low-poly model. Set before it enters the tree.
@export var low_poly := false
## Layers of wool stood off its coat (each one more draw of it). Set before it enters the tree.
@export_range(0, 3) var fur_shells := 1
## Multiplies the colours of its coat and hair. Set before it enters the tree.
@export var coat_tint := Color.WHITE
## Works out `velocity` from how it is moved (else the game sets it).
@export var measure_velocity := true
## Makes its own sounds.
@export var sound := true
@export var volume_db := 0.0

var velocity := Vector3.ZERO
var grounded := true
var look_at_point := Vector3.INF
var grazing := false
var feeling := false
var alert := false
var ears_out := false
var lowered := false
var rig: MammothRig

var _was_at := Vector3.INF
var _trumpet_left := 0.0
var _voice: AudioStreamPlayer3D
var _low_voice: AudioStreamPlayer3D
static var _trumpet: AudioStreamWAV
static var _rumble: AudioStreamWAV
static var _thud: AudioStreamWAV


func _ready() -> void:
	rig = MammothRig.new()
	rig.name = "Rig"
	rig.model_path = "res://creatures/mammoth/models/mammoth%s%s.glb" % ["_calf" if calf else "", "_lo" if low_poly else ""]
	rig.low_poly = low_poly
	rig.fur_shells = fur_shells
	rig.coat_tint = coat_tint
	add_child(rig)
	if sound:
		_voice = AudioStreamPlayer3D.new()
		_voice.volume_db = volume_db
		_voice.unit_size = 16.0
		_voice.max_distance = 160.0
		_voice.position = Vector3(0.0, 2.6, 2.0)
		add_child(_voice)
		_low_voice = AudioStreamPlayer3D.new()
		_low_voice.volume_db = volume_db - 2.0
		_low_voice.unit_size = 10.0
		_low_voice.max_distance = 90.0
		_low_voice.position = Vector3(0.0, 2.0, 1.0)
		add_child(_low_voice)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if _trumpet_left > 0.0:
		_trumpet_left -= delta
	if measure_velocity:
		var at := global_position
		if _was_at.is_finite():
			var moved := (at - _was_at) / delta
			if moved.length() > 60.0:
				settle()
			else:
				velocity = velocity.lerp(moved, 1.0 - exp(-10.0 * delta))
		_was_at = at


## Stands it still where it is, with nothing in motion: for when it is put somewhere.
func settle() -> void:
	velocity = Vector3.ZERO
	_was_at = global_position
	if rig:
		rig.settle()


func trumpet() -> void:
	_trumpet_left = TRUMPET_TIME
	trumpeted.emit()
	_play(_voice, trumpet_sound(), randf_range(0.94, 1.06) * (1.45 if calf else 1.0))


func trumpeting() -> bool:
	return _trumpet_left > 0.0


## How far through its trumpet it is, 0..1 (0 when it is not).
func trumpet_progress() -> float:
	return 1.0 - _trumpet_left / TRUMPET_TIME if _trumpet_left > 0.0 else 0.0


func rumble() -> void:
	rumbled.emit()
	_play(_low_voice, rumble_sound(), randf_range(0.92, 1.05) * (1.4 if calf else 1.0))


func stamp() -> void:
	if rig:
		rig.stamp()
	stamped.emit()
	# (the thud as the foot comes down)
	get_tree().create_timer(MammothRig.STAMP_TIME * 0.6).timeout.connect(func() -> void: _play(_low_voice, thud_sound(), randf_range(0.9, 1.1)))


## Stamping.
func busy() -> bool:
	return rig != null and rig.busy()


## Where the tips of its tusks are, in the world (none on a calf).
func tusk_tips() -> Array[Vector3]:
	return rig.tusk_tips() if rig else []


func trunk_tip() -> Vector3:
	return rig.trunk_tip() if rig else global_position


func head_position() -> Vector3:
	return rig.head_position() if rig else global_position


func _play(player: AudioStreamPlayer3D, stream: AudioStream, pitch := 1.0) -> void:
	if player == null or not player.is_inside_tree():
		return
	player.stream = stream
	player.pitch_scale = pitch
	player.play()


## The trumpet: a harsh brassy blare that leaps up, holds wavering and rasping,
## and breaks and falls away. Made once and shared.
static func trumpet_sound() -> AudioStreamWAV:
	if _trumpet:
		return _trumpet
	var rate := 22050
	var length := TRUMPET_TIME * 0.9
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var samples := PackedFloat32Array()
	samples.resize(count)
	var horn := Band.new(900.0, 2.0, rate)
	var bell := Band.new(2200.0, 3.0, rate)
	var air := Band.new(3000.0, 1.0, rate)
	var phase := 0.0
	var wander := 0.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var u := t / length
		wander = clampf(wander + rng.randf_range(-1.0, 1.0) * 0.05, -1.0, 1.0)
		var pitch := 260.0 + 300.0 * smoothstep(0.0, 0.12, u) + 40.0 * sin(TAU * 4.5 * t) * smoothstep(0.1, 0.3, u) - 220.0 * smoothstep(0.7, 1.0, u)
		pitch *= 1.0 + 0.03 * wander
		phase += pitch / rate
		# (a buzz of the lips: a ramp, rich in overtones, rasping)
		var buzz := (fposmod(phase, 1.0) * 2.0 - 1.0) * (0.75 + 0.25 * sin(TAU * 47.0 * t + wander))
		var value := horn.run(buzz) * 1.6 + bell.run(buzz) * 0.9 + buzz * 0.25
		value += air.run(rng.randf_range(-1.0, 1.0)) * 0.3
		value *= smoothstep(0.0, 0.05, u) * (1.0 - smoothstep(0.82, 1.0, u))
		value = tanh(value * 1.8)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_trumpet = _wav(samples, loudest, rate)
	return _trumpet


## The rumble: a deep, slow, rolling growl, swelling and dying. Made once and shared.
static func rumble_sound() -> AudioStreamWAV:
	if _rumble:
		return _rumble
	var rate := 22050
	var length := 1.8
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 43
	var samples := PackedFloat32Array()
	samples.resize(count)
	var throat := Band.new(140.0, 1.4, rate)
	var phase := 0.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var u := t / length
		var pitch := 48.0 + 10.0 * sin(PI * u)
		phase += pitch * (1.0 + rng.randf_range(-0.03, 0.03)) / rate
		var pulse := pow(1.0 - fposmod(phase, 1.0), 4.0) * 2.0 - 0.4
		var value := throat.run(pulse) * 2.0 + pulse * 0.5
		value *= sin(PI * u) * (0.8 + 0.2 * sin(TAU * 3.0 * t))
		value = tanh(value * 1.3)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_rumble = _wav(samples, loudest, rate)
	return _rumble


## A great foot brought down: a deep thud. Made once and shared.
static func thud_sound() -> AudioStreamWAV:
	if _thud:
		return _thud
	var rate := 22050
	var count := int(rate * 0.35)
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	var samples := PackedFloat32Array()
	samples.resize(count)
	var dust := Band.new(700.0, 1.0, rate)
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var value := sin(TAU * (60.0 - 30.0 * t / 0.35) * t) * exp(-t * 14.0) + dust.run(rng.randf_range(-1.0, 1.0)) * exp(-t * 30.0) * 0.4
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_thud = _wav(samples, loudest, rate)
	return _thud


static func _wav(samples: PackedFloat32Array, loudest: float, rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / maxf(loudest, 0.001), -1.0, 1.0) * 30000.0))
	var made := AudioStreamWAV.new()
	made.format = AudioStreamWAV.FORMAT_16_BITS
	made.mix_rate = rate
	made.data = data
	return made


## A resonant band-pass filter (a biquad), for the sounds.
class Band:
	var _b0 := 0.0
	var _a1 := 0.0
	var _a2 := 0.0
	var _x1 := 0.0
	var _x2 := 0.0
	var _y1 := 0.0
	var _y2 := 0.0

	func _init(frequency: float, q: float, rate: int) -> void:
		var w := TAU * clampf(frequency, 20.0, rate * 0.45) / rate
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

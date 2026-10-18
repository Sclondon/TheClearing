class_name Dimetrodon
extends Node3D
## A dimetrodon (Dimetrodon grandis), at its real size: 3.4 m from snout to
## tail tip, a synapsid of the Permian (no dinosaur: nearer to us than to
## them), low on sprawling legs, the tall sail of spines and skin down its
## back, about a metre over it at the middle; a big, deep, narrow skull with
## the two kinds of teeth its name is for, the great canines at the front and
## the smaller teeth behind. Its look, its moves and its sounds are here; what
## it does is for the game to say. It knows nothing of the game it is in.
##
## HOW TO DRIVE IT. Put it in the world and move it (position, rotation about
## Y: it faces +Z). It works out how fast it is going from how it is moved
## (or set `measure_velocity` false and set `velocity`) and walks to match, a
## sprawler's walk with the spine swinging in an S; faster, a scuttling rush.
## Then say what it is doing:
## - `basking`: lying flat on the ground, still (turn it side on to the sun:
##   its sail is how it warms).
## - `threatening`: up on its legs, jaws gaping wide; with `hiss()`.
## - `lunge()`: a sudden dart, the jaws flung open and snapped shut (`snapped`).
## - `look_at_point`: what it watches (INF: nothing).
## Signals: `snapped`, `hissed`, `footfall(at, weight)`. Its sounds are made in code.
##
## It is drawn by DimetrodonRig (dimetrodon_rig.gd) on the model made by
## tools/build_dimetrodon.py, with DimetrodonLook's materials: two draws.

signal snapped
signal hissed
signal footfall(at: Vector3, weight: float)

@export var low_poly := false
@export var skin_tint := Color.WHITE
@export var scales := 36.0
@export_range(0.0, 2.0) var eyeshine := 0.3
@export var measure_velocity := true
@export_group("Sound")
@export var sound := true
@export var volume_db := 0.0
@export var sound_range := 40.0

var velocity := Vector3.ZERO
var look_at_point := Vector3.INF
var basking := false
var threatening := false
var rig: DimetrodonRig

var _was_at := Vector3.INF
var _voice: AudioStreamPlayer3D
var _feet: AudioStreamPlayer3D

static var _hiss: AudioStreamWAV
static var _snap: AudioStreamWAV
static var _grunt: AudioStreamWAV
static var _scrape: AudioStreamWAV


func _ready() -> void:
	rig = DimetrodonRig.new()
	rig.name = "Rig"
	rig.low_poly = low_poly
	rig.skin_tint = skin_tint
	rig.scales = scales
	rig.eyeshine = eyeshine
	add_child(rig)
	rig.footfall.connect(_on_footfall)
	rig.snapped.connect(_on_snapped)
	if sound:
		_voice = _player(Vector3(0.0, 0.5, 1.1), 1)
		_feet = _player(Vector3(0.0, 0.1, 0.0), 2)
		_feet.stream = scrape_sound()


func _process(delta: float) -> void:
	if delta <= 0.0 or not measure_velocity:
		return
	var at := global_position
	if _was_at.is_finite():
		var moved := (at - _was_at) / delta
		if moved.length() > 30.0:
			settle()
		else:
			velocity = velocity.lerp(moved, 1.0 - exp(-12.0 * delta))
	_was_at = at


func settle() -> void:
	velocity = Vector3.ZERO
	_was_at = global_position
	if rig:
		rig.settle()


## A long rasping hiss through gaping jaws: its warning.
func hiss() -> void:
	_say(hiss_sound(), 0.0, randf_range(0.9, 1.08))
	hissed.emit()


## A low grunt.
func grunt() -> void:
	_say(grunt_sound(), -4.0, randf_range(0.9, 1.1))


func lunge() -> void:
	if rig:
		rig.lunge()


func lunging() -> bool:
	return rig != null and rig.lunging()


## Where the front of its jaws is, in the world.
func snout_tip() -> Vector3:
	return rig.snout_tip() if rig else global_position


func _on_snapped() -> void:
	_say(snap_sound(), 2.0, randf_range(0.9, 1.1))
	snapped.emit()


func _on_footfall(at: Vector3, weight: float) -> void:
	if _feet and weight > 0.25:
		_feet.volume_db = volume_db - 14.0 + 8.0 * minf(weight, 1.0)
		_feet.pitch_scale = randf_range(0.85, 1.15)
		_feet.play()
	footfall.emit(at, weight)


func _player(at: Vector3, polyphony: int) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.position = at
	player.unit_size = 6.0
	player.max_distance = sound_range
	player.volume_db = volume_db
	player.max_polyphony = polyphony
	add_child(player)
	return player


func _say(stream: AudioStreamWAV, gain: float, pitch: float) -> void:
	if _voice == null:
		return
	_voice.stream = stream
	_voice.volume_db = volume_db + gain
	_voice.pitch_scale = pitch
	_voice.play()


static func hiss_sound() -> AudioStreamWAV:
	if _hiss:
		return _hiss
	var rate := 22050
	var length := 1.4
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 301
	var hiss := Band.new(3200.0, 0.9, rate)
	var throat := Band.new(900.0, 2.0, rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / rate
		var level := smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(length * 0.55, length, t))
		var rasp := 0.7 + 0.3 * sin(t * TAU * 31.0)
		var air := rng.randf_range(-1.0, 1.0)
		samples[i] = tanh((hiss.run(air) * 1.6 * rasp + throat.run(air) * 0.8) * level * 1.8)
	_hiss = _wave(samples, rate)
	return _hiss


static func snap_sound() -> AudioStreamWAV:
	if _snap:
		return _snap
	var rate := 22050
	var count := int(rate * 0.25)
	var rng := RandomNumberGenerator.new()
	rng.seed = 307
	var clack := Band.new(1400.0, 3.0, rate)
	var thump := Band.new(180.0, 2.0, rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / rate
		var hit := rng.randf_range(-1.0, 1.0) * exp(-t * 60.0)
		samples[i] = tanh((clack.run(hit) * 4.0 + thump.run(hit) * 3.0) * 1.5)
	_snap = _wave(samples, rate)
	return _snap


static func grunt_sound() -> AudioStreamWAV:
	if _grunt:
		return _grunt
	var rate := 22050
	var length := 0.5
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 311
	var chest := Band.new(140.0, 3.0, rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / rate
		var level := minf(t / 0.03, 1.0) * pow(1.0 - t / length, 1.5)
		phase += (70.0 - 20.0 * t) / rate
		var pulse := pow(1.0 - fposmod(phase, 1.0), 5.0) * 2.0 - 0.3
		samples[i] = tanh((chest.run(pulse) * 3.0 + rng.randf_range(-0.1, 0.1)) * level * 2.0)
	_grunt = _wave(samples, rate)
	return _grunt


## A foot set down: claws scraping on grit.
static func scrape_sound() -> AudioStreamWAV:
	if _scrape:
		return _scrape
	var rate := 22050
	var count := int(rate * 0.18)
	var rng := RandomNumberGenerator.new()
	rng.seed = 313
	var grit := Band.new(2200.0, 1.0, rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / rate
		samples[i] = tanh(grit.run(rng.randf_range(-1.0, 1.0)) * exp(-t * 25.0) * 2.0)
	_scrape = _wave(samples, rate)
	return _scrape


static func _wave(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var loudest := 0.001
	for value in samples:
		loudest = maxf(loudest, absf(value))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / loudest, -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream


## A resonant band-pass filter (a biquad), for the sounds.
class Band:
	var _b0 := 0.0
	var _a1 := 0.0
	var _a2 := 0.0
	var _rate := 22050
	var _x1 := 0.0
	var _x2 := 0.0
	var _y1 := 0.0
	var _y2 := 0.0

	func _init(frequency: float, q: float, rate: int) -> void:
		_rate = rate
		var w := TAU * frequency / _rate
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

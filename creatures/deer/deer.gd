class_name Deer
extends Node3D
## A white-tailed deer, a doe or a buck: lean, long-legged, big-eared, its
## eyes big, dark and wet and giving back the light. Its look and every move
## are here; what it does is for the game to say. It knows nothing of the game
## it is in.
##
## HOW TO DRIVE IT. Put it in the world and move it (its position and its
## rotation about Y: it faces +Z). It works out how fast it is going from how
## it is moved (or set `measure_velocity` false and set `velocity`), and walks,
## trots or gallops to match, its hooves planted on the ground at its feet. Set
## `grounded` false while it is falling. Scale it to make it bigger.
##
## Then say what it is doing (each eases in and out):
## - `look_at_point`: what it watches (INF for nothing): head and ears turn to it.
## - `grazing`: head down to the ground, cropping.
## - `alert`: frozen, head high, ears forward, stock still but for the ears.
## - `flagging`: its tail up, the white under it and round it showing.
## - `fleeing`: ears laid back (running flat out).
## - `pronking`: stotting, bounding on all four stiff legs at once, straight
##   up and down; the game moves it along a little.
## - `upright`: stood up on its hind legs, front legs hanging (a deer that is
##   not one: see `wrong`).
## - `stamp()`: a forefoot raised high and brought down hard. `snort()`: a
##   blast of breath through its nose, the head jerking.
## - `wrong` (0..1): how far it is not a deer. Its legs are a little too long
##   (it stands taller than the rest), and its head turns further round than a
##   neck should let it, all the way to look behind it.
##
## Signals say when it stamps and snorts; with `sound` on it makes the sounds
## too (made in code, nothing to load).
##
## It is drawn by DeerRig (deer_rig.gd) on one of two models (`variant`: a doe
## or a buck with antlers, made by tools/build_deer.py), with DeerLook's
## materials. Elk (creatures/elk) is a deer too.

signal stamped
signal snorted

enum Variant { DOE, BUCK }

## Doe or buck. Set before it enters the tree.
@export var variant := Variant.DOE
## The demade, low-poly model. Set before it enters the tree.
@export var low_poly := false
## Layers of hair stood off its coat (each one more draw of it). Set before it enters the tree.
@export_range(0, 3) var fur_shells := 1
## Multiplies the colours of its coat.
@export var coat_tint := Color.WHITE
## How brightly its eyes give back the light (the rig raises it while it watches).
@export_range(0.0, 3.0) var eyeshine := 0.9
## A fawn: white spots along its back (scale it down to make it small). Set before it enters the tree.
@export var fawn := false
## How far it is not a deer, 0..1 (see above). Set before it enters the tree.
@export_range(0.0, 1.0) var wrong := 0.0
## Works out `velocity` from how it is moved (else the game sets it).
@export var measure_velocity := true
## Makes its own sounds.
@export var sound := true
@export var volume_db := 0.0

## How fast it is going, in the world.
var velocity := Vector3.ZERO
## Whether its hooves are on the ground.
var grounded := true
## What it watches, in the world (INF: nothing).
var look_at_point := Vector3.INF
var grazing := false
var alert := false
var flagging := false
var fleeing := false
var pronking := false
var upright := false
var rig: DeerRig

var _was_at := Vector3.INF
var _voice: AudioStreamPlayer3D
static var _snort: AudioStreamWAV
static var _stamp: AudioStreamWAV


func _ready() -> void:
	rig = DeerRig.new()
	rig.name = "Rig"
	rig.model_path = model_path()
	rig.low_poly = low_poly
	rig.fur_shells = fur_shells
	rig.coat_tint = coat_tint
	rig.eyeshine = eyeshine
	rig.wrong = wrong
	rig.spots = 1.0 if fawn else 0.0
	rig.colours = colours()
	add_child(rig)
	if sound:
		_voice = AudioStreamPlayer3D.new()
		_voice.volume_db = volume_db
		_voice.unit_size = 6.0 * scale.x
		_voice.max_distance = 60.0 * scale.x
		_voice.position = Vector3(0.0, 1.2, 0.5)
		add_child(_voice)


## The model it is drawn on.
func model_path() -> String:
	return "res://creatures/deer/models/deer_%s%s.glb" % ["buck" if variant == Variant.BUCK else "doe", "_lo" if low_poly else ""]


## The coat's colours: grey-brown in its winter coat, darker along the back.
func colours() -> Dictionary:
	return {"coat": Color(0.36, 0.30, 0.24), "dark": Color(0.2, 0.16, 0.125), "pale": Color(0.82, 0.8, 0.76)}


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if measure_velocity:
		var at := global_position
		if _was_at.is_finite():
			var moved := (at - _was_at) / delta
			if moved.length() > 60.0:
				settle()
			else:
				velocity = velocity.lerp(moved, 1.0 - exp(-14.0 * delta))
		_was_at = at


## Stands it still where it is, with nothing in motion: for when it is put somewhere.
func settle() -> void:
	velocity = Vector3.ZERO
	_was_at = global_position
	if rig:
		rig.settle()


func stamp() -> void:
	if rig:
		rig.stamp()
	stamped.emit()
	_play(stamp_sound(), randf_range(0.9, 1.1))


func snort() -> void:
	if rig:
		rig.snort()
	snorted.emit()
	_play(snort_sound(), randf_range(0.92, 1.08) / sqrt(scale.x))


## Stamping or snorting.
func busy() -> bool:
	return rig != null and rig.busy()


## Where the tip of its nose is, in the world.
func nose_position() -> Vector3:
	return rig.nose() if rig else global_position


## The front of its antlers (or its brow), in the world: what a charge strikes with.
func brow_position() -> Vector3:
	return rig.brow() if rig else global_position


func _play(stream: AudioStream, pitch := 1.0) -> void:
	if _voice == null or not _voice.is_inside_tree():
		return
	_voice.stream = stream
	_voice.pitch_scale = pitch
	_voice.play()


## A snort: a hard blast of air through the nose, hissing and fluttering at the
## nostrils, gone in a third of a second. Made once and shared.
static func snort_sound() -> AudioStreamWAV:
	if _snort:
		return _snort
	var rate := 22050
	var count := int(rate * 0.42)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var samples := PackedFloat32Array()
	samples.resize(count)
	var hiss := Band.new(1900.0, 1.2, rate)
	var body := Band.new(650.0, 2.0, rate)
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var air := smoothstep(0.0, 0.012, t) * exp(-t * 9.0)
		# (the nostrils flutter as the air goes through)
		var flutter := 0.75 + 0.25 * sin(TAU * 38.0 * t + sin(TAU * 7.0 * t))
		var n := rng.randf_range(-1.0, 1.0)
		var value := (hiss.run(n) * 0.8 + body.run(n) * 1.1) * air * flutter
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_snort = _wav(samples, loudest, rate)
	return _snort


## A hoof brought down on hard ground: a dull thud with a click on top.
static func stamp_sound() -> AudioStreamWAV:
	if _stamp:
		return _stamp
	var rate := 22050
	var count := int(rate * 0.22)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var samples := PackedFloat32Array()
	samples.resize(count)
	var click := Band.new(2400.0, 2.0, rate)
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var thud := sin(TAU * (95.0 - 50.0 * t / 0.22) * t) * exp(-t * 26.0)
		var value := thud + click.run(rng.randf_range(-1.0, 1.0)) * exp(-t * 120.0) * 0.6
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_stamp = _wav(samples, loudest, rate)
	return _stamp


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
	var _rate := 22050
	var _q := 1.0
	var _x1 := 0.0
	var _x2 := 0.0
	var _y1 := 0.0
	var _y2 := 0.0

	func _init(frequency: float, q: float, rate: int) -> void:
		_rate = rate
		set_frequency(frequency, q)

	func set_frequency(frequency: float, q: float) -> void:
		_q = q
		var w := TAU * clampf(frequency, 20.0, _rate * 0.45) / _rate
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

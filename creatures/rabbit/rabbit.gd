class_name Rabbit
extends Node3D
## A rabbit, a brown hare or a jackalope: how it looks and every move it makes;
## what it does is for the game to say. It knows nothing of the game it is in.
##
## - RABBIT: the European rabbit, small, round and grey-brown, short-eared
##   for a leporid, its scut white beneath.
## - HARE: the brown hare, half as big again, lean and long-legged, tawny,
##   with long black-tipped ears, a black-topped tail and big amber eyes.
## - JACKALOPE: a hare, greyer, with a pair of small polished antlers (a roe
##   buck's: a tine forward, one back, a fork at the top) from in front of its
##   ears. Its eyes give back more light than they should, it holds stiller,
##   and its nose does not twitch while it watches.
##
## HOW TO DRIVE IT. Put it in the world and move it (its position and its
## rotation about Y: it faces +Z). It works out how fast it is going from how
## it is moved (or set `measure_velocity` false and set `velocity`), and sits,
## hops or bounds to match: still, it sits hunched with its hind feet flat
## under it; slowly, the leporid's hop (forefeet forward one and then the
## other, the hind feet brought up together beside them); fast, the bound (the
## hind feet drive off together, it flies stretched out, lands on one forefoot
## and the other, and the hind feet swing forward outside them to land ahead of
## where the forefeet were). Set `grounded` false while it is falling. Scale it
## to make it bigger.
##
## Then say what it is doing (each eases in and out):
## - `look_at_point`: what it watches (INF for nothing): head and ears turn to it.
## - `grazing`: crouched, head down to the grass, nibbling, the jaw going.
## - `alert`: still, head up, ears up and forward, turning to listen.
## - `upright`: sat up on its haunches, forepaws held to its chest, looking.
## - `washing`: sat up, washing its face with its forepaws, ears too.
## - `flattened`: pressed flat to the ground, ears laid along its back (a
##   hare in its form): stock still.
## - `fleeing`: ears laid back, running flat out; `flagging`: the scut held up,
##   flashing white.
## - `boxing`: stood up tall, striking out with its forepaws (March hares).
## - `lowered`: the head down, a jackalope's antlers forward (its charge).
## - `thump()`: both hind feet drummed on the ground, the alarm. `grunt()`: a
##   jackalope's low growl before it charges.
##
## Signals say when it thumps and grunts; with `sound` on it makes the sounds
## too (made in code, nothing to load).
##
## It is drawn by RabbitRig (rabbit_rig.gd) on one of three models (made by
## tools/build_rabbit.py), with RabbitLook's materials.

signal thumped
signal grunted

enum Variant { RABBIT, HARE, JACKALOPE }

## Which. Set before it enters the tree.
@export var variant := Variant.RABBIT
## The demade, low-poly model. Set before it enters the tree.
@export var low_poly := false
## Layers of hair stood off its coat (each one more draw of it). Set before it enters the tree.
@export_range(0, 2) var fur_shells := 1
## Multiplies the colours of its coat.
@export var coat_tint := Color.WHITE
## How brightly its eyes give back the light.
@export_range(0.0, 3.0) var eyeshine := 0.5
## Works out `velocity` from how it is moved (else the game sets it).
@export var measure_velocity := true
## Makes its own sounds.
@export var sound := true
@export var volume_db := 0.0

## How fast it is going, in the world.
var velocity := Vector3.ZERO
## Whether its feet are on the ground.
var grounded := true
## What it watches, in the world (INF: nothing).
var look_at_point := Vector3.INF
var grazing := false
var alert := false
var upright := false
var washing := false
var flattened := false
var fleeing := false
var flagging := false
var boxing := false
var lowered := false
var rig: RabbitRig

var _was_at := Vector3.INF
var _voice: AudioStreamPlayer3D
static var _thump: AudioStreamWAV
static var _grunt: AudioStreamWAV


func _ready() -> void:
	rig = RabbitRig.new()
	rig.name = "Rig"
	rig.model_path = model_path()
	rig.low_poly = low_poly
	rig.fur_shells = fur_shells
	rig.coat_tint = coat_tint
	rig.eyeshine = eyeshine * (2.2 if variant == Variant.JACKALOPE else 1.0)
	rig.uncanny = 1.0 if variant == Variant.JACKALOPE else 0.0
	rig.colours = colours()
	add_child(rig)
	if sound:
		_voice = AudioStreamPlayer3D.new()
		_voice.volume_db = volume_db
		_voice.unit_size = 3.0 * scale.x
		_voice.max_distance = 30.0 * scale.x
		_voice.position = Vector3(0.0, 0.05, -0.1)
		add_child(_voice)


## The model it is drawn on.
func model_path() -> String:
	return "res://creatures/rabbit/models/%s%s.glb" % [["rabbit", "hare", "jackalope"][variant], "_lo" if low_poly else ""]


## The coat's colours.
func colours() -> Dictionary:
	match variant:
		Variant.HARE:
			return {"coat": Color(0.47, 0.37, 0.26), "dark": Color(0.27, 0.21, 0.15), "pale": Color(0.82, 0.78, 0.7)}
		Variant.JACKALOPE:
			return {"coat": Color(0.42, 0.36, 0.29), "dark": Color(0.25, 0.21, 0.17), "pale": Color(0.78, 0.75, 0.7)}
	return {"coat": Color(0.4, 0.35, 0.29), "dark": Color(0.24, 0.2, 0.16), "pale": Color(0.8, 0.77, 0.71)}


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
				velocity = velocity.lerp(moved, 1.0 - exp(-16.0 * delta))
		_was_at = at


## Stands it still where it is, with nothing in motion: for when it is put somewhere.
func settle() -> void:
	velocity = Vector3.ZERO
	_was_at = global_position
	if rig:
		rig.settle()


func thump() -> void:
	if rig:
		rig.thump()
	thumped.emit()
	_play(thump_sound(), randf_range(0.9, 1.1) / sqrt(scale.x))


func grunt() -> void:
	if rig:
		rig.grunt()
	grunted.emit()
	_play(grunt_sound(), randf_range(0.92, 1.05))


## Thumping or grunting.
func busy() -> bool:
	return rig != null and rig.busy()


## Where the tip of its nose is, in the world.
func nose_position() -> Vector3:
	return rig.nose() if rig else global_position


## The top of its head (a jackalope's antlers), in the world: what a charge strikes with.
func brow_position() -> Vector3:
	return rig.brow() if rig else global_position


func _play(stream: AudioStream, pitch := 1.0) -> void:
	if _voice == null or not _voice.is_inside_tree():
		return
	_voice.stream = stream
	_voice.pitch_scale = pitch
	_voice.play()


## A thump: two hind feet brought down hard on the ground, a dull, deep knock
## that carries, felt more than heard. Made once and shared.
static func thump_sound() -> AudioStreamWAV:
	if _thump:
		return _thump
	var rate := 22050
	var count := int(rate * 0.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var samples := PackedFloat32Array()
	samples.resize(count)
	var scuff := Band.new(900.0, 1.4, rate)
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		# (the two feet a hair apart)
		var knock := 0.0
		for foot: float in [0.0, 0.012]:
			var u := t - foot
			if u > 0.0:
				knock += sin(TAU * (72.0 - 30.0 * u / 0.3) * u) * exp(-u * 30.0)
		var value := knock + scuff.run(rng.randf_range(-1.0, 1.0)) * exp(-t * 70.0) * 0.35
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_thump = _wav(samples, loudest, rate)
	return _thump


## A low, throaty growl with a snort at its front: a buck rabbit's warning
## grunt, too deep for something its size.
static func grunt_sound() -> AudioStreamWAV:
	if _grunt:
		return _grunt
	var rate := 22050
	var count := int(rate * 0.55)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var samples := PackedFloat32Array()
	samples.resize(count)
	var throat := Band.new(320.0, 3.0, rate)
	var nose := Band.new(2100.0, 1.5, rate)
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var shape := smoothstep(0.0, 0.04, t) * (1.0 - smoothstep(0.35, 0.55, t))
		# (a rough buzz, pulsed, like a purr gone wrong)
		var buzz := signf(sin(TAU * 58.0 * t)) * (0.6 + 0.4 * sin(TAU * 17.0 * t))
		var air := rng.randf_range(-1.0, 1.0)
		var value := throat.run(buzz * 0.7 + air * 0.4) * shape * 1.4 + nose.run(air) * exp(-t * 18.0) * 0.6
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_grunt = _wav(samples, loudest, rate)
	return _grunt


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

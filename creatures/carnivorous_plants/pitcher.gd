class_name Pitcher
extends Node3D
## A giant pitcher plant, sunk to its mouth in the mud: a wide mouth at the
## ground ringed by a ribbed, striped lip (wet, glistening, and as slippery as
## it looks), black fluid down inside, its lid held up over it, two fringed wings
## down its front, a tendril coiled behind and two small pitchers beside it.
## Whatever steps onto the lip goes in; the lid drops down over the mouth (it
## does not shut it: only lowers over it, shuddering) and the fluid churns.
##
## This is only how it looks, moves and sounds. It does no thinking: a game asks
## whether a point is over its mouth and tells it when it has swallowed.
##
##     var pit := Pitcher.new()
##     add_child(pit)                # its mouth at its origin, sloping down towards +Z
##     pit.over_mouth(point)         # whether a point (world) is over the mouth (in, if it is on the ground)
##     pit.swallow()                 # the lid drops shut over it, a gulp, the fluid churns
##     pit.open_lid(6.0)             # it lifts again, slowly

## The mouth, as modelled: half its width (x) and depth (z), metres.
const MOUTH := Vector2(0.72, 0.6)
## How far down the lid comes when it has swallowed something, as a share of the way to shut.
const LID_DROP := 0.62

@export var low_poly := false
@export var sound := true
@export var volume_db := -4.0
@export var far := 85.0

## How far its lid is down, 0 (held up) to 1 (shut), eased.
var lid_down := 0.0
var lid: Node3D

var _material: ShaderMaterial
var _lid_goal := 0.0
var _lid_rate := 1.0
var _churn := 0.0
var _time := 0.0
var _voice: AudioStreamPlayer3D
static var _gulp: AudioStreamWAV


func _ready() -> void:
	var path := PlantLook.PITCHER_LO if low_poly or Settings.low_poly else PlantLook.PITCHER
	_material = PlantLook.material()
	_material.set_shader_parameter(&"glint", 1.6)
	add_child(PlantLook.part(path, "pitcher", _material, far))
	lid = Node3D.new()
	lid.name = "Lid"
	lid.position = PlantLook.LID_HINGE
	add_child(lid)
	lid.add_child(PlantLook.part(path, "pitcher_lid", _material, far))
	if sound:
		_voice = AudioStreamPlayer3D.new()
		_voice.volume_db = volume_db
		_voice.unit_size = 5.0
		_voice.max_distance = 30.0
		_voice.position = Vector3(0.0, 0.2, 0.0)
		add_child(_voice)


func _process(delta: float) -> void:
	_time += delta
	lid_down = move_toward(lid_down, _lid_goal, delta * _lid_rate)
	_churn = maxf(_churn - delta * 0.12, 0.0)
	# (shut, it shudders as what is in it struggles; held up, it hardly moves)
	var shudder := sin(_time * 23.0) * 0.03 * _churn * lid_down
	lid.rotation.x = PlantLook.LID_OPEN * LID_DROP * ease(lid_down, 2.2) + shudder + sin(_time * 0.8) * 0.01
	_material.set_shader_parameter(&"dull", 0.4 * _churn)


## Whether `point` (world) is over its mouth: inside the lip, within `height` of the ground there.
func over_mouth(point: Vector3, radius := 0.0, height := 0.9) -> bool:
	var size := global_basis.get_scale().x
	var at := to_local(point)
	var r := radius / size
	var e := Vector2(at.x / (MOUTH.x * 0.9 + r), at.z / (MOUTH.y * 0.9 + r))
	return e.length() < 1.0 and at.y < height / size and at.y > -1.0


## Something is in: the lid drops, a gulp, and the fluid churns.
func swallow() -> void:
	_lid_goal = 1.0
	_lid_rate = 3.0
	_churn = 1.0
	if _voice and _voice.is_inside_tree():
		_voice.stream = gulp_sound()
		_voice.pitch_scale = randf_range(0.9, 1.1)
		_voice.play()


## Lifts its lid again over `seconds`.
func open_lid(seconds := 6.0) -> void:
	_lid_goal = 0.0
	_lid_rate = 1.0 / maxf(seconds, 0.1)


func is_shut() -> bool:
	return lid_down > 0.5


## Straight to shut or open, nothing in motion.
func set_shut(value: bool) -> void:
	_lid_goal = 1.0 if value else 0.0
	lid_down = _lid_goal


## A deep, wet gulp, and bubbles rising after it.
static func gulp_sound() -> AudioStreamWAV:
	if _gulp:
		return _gulp
	var rate := 22050
	var count := int(rate * 1.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	var samples := PackedFloat32Array()
	samples.resize(count)
	var low := 0.0
	var bubble_at := -1.0
	var bubble_pitch := 300.0
	for i in count:
		var t := float(i) / rate
		low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.08)
		# The gulp: a falling, hollow plop
		var plop := sin(TAU * (140.0 - 60.0 * t) * t) * exp(-t * 7.0) + low * 2.0 * exp(-t * 10.0)
		# Bubbles after: each a short rising chirp
		if t > 0.25 and rng.randf() < 0.0012 and t - bubble_at > 0.04:
			bubble_at = t
			bubble_pitch = rng.randf_range(220.0, 520.0)
		var since := t - bubble_at
		var bubble := sin(TAU * bubble_pitch * since * (1.0 + since * 18.0)) * exp(-since * 40.0) * 0.5 if bubble_at >= 0.0 else 0.0
		samples[i] = tanh(plop * 1.2 + bubble * (1.0 - t / 1.4))
	_gulp = PlantLook.wav(samples)
	return _gulp

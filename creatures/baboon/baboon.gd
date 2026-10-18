class_name Baboon
extends Node3D
## A demonic baboon, or the great mandrill that leads them: how it looks and how
## it moves, and nothing of what it thinks. Whatever drives it (a game's enemy
## script, a cutscene, the example) moves this node about and calls on it; it
## poses itself from that.
##
## WHAT IT IS. A coarse grey ape on all fours, its back sloping down from high
## shoulders to its haunches, long arms walking on the knuckles, a long dog's
## muzzle, a heavy brow with two small eyes glowing like embers under it, and
## fangs. `kind` says which:
## - BABOON: lean and long-legged, a dark face, a long tail held up in a hook
##   and hanging from the bend, a short ruff.
## - ALPHA: the mandrill. Twice as heavy, a barrel chest, a shaggy cape of mane
##   over the shoulders, a short tail, longer fangs, and the face: a vivid red
##   ridge down the nose and ridged blue cheeks either side, the one colour in
##   it. It is drawn bigger (`size`).
## Everything is made in code (BaboonLook): a skinned mesh for each kind on a
## skeleton made here, so each baboon is one draw.
##
## HOW IT MOVES. Move the node (`global_position`) and turn it (its Y rotation;
## it faces +Z); it works out its own speed from that each frame, and its feet
## keep to the ground as it goes:
## - slow, it knuckle-walks, a foot at a time (left hind, left fore, right hind,
##   right fore), its head low and swinging;
## - fast, it gallops in bounds, both hind feet landing together ahead of where
##   the hands left, the back bunching and stretching, the whole body thrown up
##   between bounds;
## - stopped, it stands on all fours, or with `sitting` it sits up on its
##   haunches, knees up, hands down between its feet, and looks about.
## It leans into turns, its tail swings, it breathes. `look_at_point` (world,
## INF for none) is what its head turns to and its eyes are on.
##
## WHAT IT DOES, each on a call, each blending in and out by itself:
## - `bark()`: a sharp cough of a bark, the head thrown up, the jaw snapped open.
## - `display(seconds)`: the threat. It rears up on its hind legs over its hands,
##   shoulders hunched and mane up, and yawns its jaw right back to show every
##   fang, slapping the ground with one hand and then the other.
## - `leap(flight, height)`: it crouches (`leap_stage()` CROUCH, `CROUCH_TIME`),
##   springs, and is in the air for `flight` seconds (FLIGHT), arms flung
##   forward, hands open, legs streaming behind, as high as `height` at the top
##   (it lifts itself: whoever moves it moves it along the ground); then lands
##   on its hands (LAND, `LAND_TIME`) and gathers itself.
## - `panting` (0..1): tired, it stands with its mouth open, heaving.
## `reaches(point, radius)` says whether its hands or jaws are on a point now
## (only while it is leaping or landing), for whatever decides a grab.
##
## Set `kind` (and `size`, `seed_value` for its own small differences) before it
## goes into the tree. `settle()` stands it still, for when it is put somewhere.

enum Kind { BABOON, ALPHA }
enum Leap { NONE, CROUCH, FLIGHT, LAND }

const CROUCH_TIME := 0.28
const LAND_TIME := 0.45
const BARK_TIME := 0.4

## How big each kind is drawn (one unit is its own shoulder height, about 0.6).
const SIZES := {Kind.BABOON: 1.2, Kind.ALPHA: 2.05}

## Each kind's build, in its own units: thickness of chest, belly and haunches;
## of the upper arm and forearm, thigh and shin; how big its head is, its fangs,
## its mane; how long each joint of its tail is; its coat (back, belly and inner
## limbs, the mane, the rump and the patch on it), its skin, and its face (the
## nose ridge and the cheek pads), the beard.
const BUILDS := {
	Kind.BABOON: {"chest": 0.14, "belly": 0.105, "haunch": 0.105, "arm": Vector2(0.056, 0.044), "leg": Vector2(0.066, 0.047),
		"head": 0.92, "fang": 0.06, "mane": 0.55, "tail_step": 0.075, "legs_long": 1.0, "muzzle": "dog",
		"fur": Color(0.25, 0.235, 0.18), "belly_fur": Color(0.38, 0.36, 0.29), "mane_fur": Color(0.29, 0.27, 0.2), "rump": Color(0.4, 0.36, 0.31), "rump_patch": Color(0.0, 0.0, 0.0, 0.0),
		"dark": Color(0.16, 0.15, 0.13), "face": Color(0.15, 0.13, 0.13), "nose": Color(0.15, 0.13, 0.13), "cheek": Color(0.15, 0.13, 0.13), "beard": Color(0.47, 0.44, 0.36)},
	Kind.ALPHA: {"chest": 0.2, "belly": 0.15, "haunch": 0.13, "arm": Vector2(0.08, 0.062), "leg": Vector2(0.084, 0.058),
		"head": 1.12, "fang": 0.1, "mane": 1.0, "tail_step": 0.032, "legs_long": 0.97, "muzzle": "mandrill",
		"fur": Color(0.17, 0.155, 0.12), "belly_fur": Color(0.3, 0.28, 0.22), "mane_fur": Color(0.2, 0.18, 0.13), "rump": Color(0.45, 0.42, 0.38), "rump_patch": Color(0.36, 0.3, 0.55, 1.0),
		"dark": Color(0.12, 0.11, 0.1), "face": Color(0.09, 0.08, 0.08), "nose": Color(0.85, 0.08, 0.07), "cheek": Color(0.22, 0.43, 0.95), "beard": Color(0.82, 0.62, 0.3)},
}
const EMBER := Color(1.0, 0.3, 0.05)
const BONE := Color(0.86, 0.82, 0.7)
const GUM := Color(0.32, 0.05, 0.06)
const BEARD := Color(0.62, 0.6, 0.53)

## Lengths of the limbs, in units: upper arm, forearm; thigh, shin.
const ARM := Vector2(0.3, 0.29)
const LEG := Vector2(0.25, 0.26)
## Where each foot stands still (units, forward +Z): left hand, right hand, left foot, right foot.
const REST: Array[Vector3] = [Vector3(0.12, 0.0, 0.31), Vector3(-0.12, 0.0, 0.31), Vector3(0.12, 0.0, -0.25), Vector3(-0.12, 0.0, -0.25)]
## Where the middle of its haunches and of its shoulders are as it stands (units).
const PELVIS := Vector3(0.0, 0.5, -0.25)
const SHOULDERS := Vector3(0.0, 0.62, 0.16)
## The two ways of going: when each foot comes down in the cycle, how much of the
## cycle it is down, and how far the body goes in a cycle (units).
const WALK := {"offsets": [0.25, 0.75, 0.0, 0.5], "duty": 0.64, "cycle": 0.72, "lift": 0.07}
const GALLOP := {"offsets": [0.5, 0.58, 0.02, 0.0], "duty": 0.3, "cycle": 1.45, "lift": 0.16}

@export var kind := Kind.BABOON
## How big it is drawn (0: its kind's size).
@export var size := 0.0
## Its own small differences (coat, build): two with one seed are alike.
@export var seed_value := 0
## Use the low-poly model (models/*_lo.glb), as `low_poly` does for every baboon.
@export var force_low := false

## The models (creatures/baboon/models/, made by tools/build_baboon.py).
const MODELS := {Kind.BABOON: "baboon", Kind.ALPHA: "mandrill"}
## Every baboon uses the low-poly model (phones).
static var low_poly := false

## What it looks at (world). INF: it looks where it goes, or about it.
var look_at_point := Vector3.INF
## Sit up on its haunches when it stops.
var sitting := false
## How tired it is, 0..1: it pants.
var panting := 0.0

var _build := {}
var _model: Node3D
var _skeleton: Skeleton3D
var _body: MeshInstance3D
## Each bone as it stands, as `_joints` puts it (its own units and space).
var _rest: Array[Transform3D] = []
## Each of BONES: its index in the model's skeleton, and how it stands there.
var _index := PackedInt32Array()
var _model_rest: Array[Transform3D] = []
var _skeleton_from_model := Transform3D.IDENTITY
## Every bone is put through this (lean, lift) when it is posed.
var _frame := Transform3D.IDENTITY

var _t := 0.0
var _was := Vector3.INF
var _yaw_was := 0.0
var _speed := 0.0
var _turn := 0.0
var _phase := 0.0
var _gallop := 0.0
var _moving := 0.0
var _sit := 0.0
var _display := 0.0
var _display_left := 0.0
var _bark := INF
var _leap := INF
var _flight := 0.5
var _height := 0.6
var _leap_w := 0.0
var _gaze := Vector3(0.0, -0.25, 1.0)
var _scan := Vector3.ZERO
var _scan_next := 0.0
var _rng := RandomNumberGenerator.new()
var _tone := 1.0
## Where its hands and jaws were at the last pose (world), for `reaches`.
var _grabbers := PackedVector3Array()


func _ready() -> void:
	_build = BUILDS[kind].duplicate()
	_rng.seed = seed_value
	_tone = _rng.randf_range(0.88, 1.12)
	if size <= 0.0:
		size = SIZES[kind] * _rng.randf_range(0.94, 1.06)
	# Its skeleton as it stands (the model was built round the same), and the model.
	_rest = _bone_globals(_joints(_standing(), STANDING_GAZE))
	var low := low_poly or force_low
	_model = (load("res://creatures/baboon/models/%s%s.glb" % [MODELS[kind], "_lo" if low else ""]) as PackedScene).instantiate()
	_model.scale = Vector3.ONE * size
	add_child(_model)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	_body = _model.find_children("*", "MeshInstance3D", true, false)[0]
	_body.material_override = BaboonLook.material()
	_body.custom_aabb = AABB(Vector3(-0.9, -0.3, -1.0), Vector3(1.8, 1.8, 2.2))
	_body.set_instance_shader_parameter(&"tone", _tone)
	_index.resize(BONES.size())
	_model_rest.resize(BONES.size())
	var to_skeleton := _skeleton.global_transform.affine_inverse() * _model.global_transform
	for b in BONES.size():
		_index[b] = _skeleton.find_bone(BONES[b])
		_model_rest[b] = _skeleton.get_bone_global_rest(_index[b])
	_skeleton_from_model = to_skeleton
	settle()


## Stands it still as it is now, with nothing going on.
func settle() -> void:
	_was = global_position
	_yaw_was = global_rotation.y
	_speed = 0.0
	_moving = 0.0
	_gallop = 0.0
	_sit = 1.0 if sitting else 0.0
	_display = 0.0
	_display_left = 0.0
	_bark = INF
	_leap = INF
	_leap_w = 0.0
	_pose(0.0)


func bark() -> void:
	_bark = 0.0


func display(seconds := 1.8) -> void:
	_display_left = maxf(_display_left, seconds)


func displaying() -> bool:
	return _display_left > 0.0


## Leaps: a crouch, then `flight` seconds in the air rising `height` (world metres) at the top.
func leap(flight := 0.5, height := 0.6) -> void:
	_flight = maxf(flight, 0.15)
	_height = height
	_leap = 0.0


func leap_stage() -> Leap:
	if _leap < CROUCH_TIME:
		return Leap.CROUCH
	if _leap < CROUCH_TIME + _flight:
		return Leap.FLIGHT
	if _leap < CROUCH_TIME + _flight + LAND_TIME:
		return Leap.LAND
	return Leap.NONE


## How far through the stage it is in, 0..1.
func leap_progress() -> float:
	match leap_stage():
		Leap.CROUCH:
			return _leap / CROUCH_TIME
		Leap.FLIGHT:
			return (_leap - CROUCH_TIME) / _flight
		Leap.LAND:
			return (_leap - CROUCH_TIME - _flight) / LAND_TIME
	return 0.0


## Whether its hands or jaws are within `radius` of `point` (world), while leaping or landing.
func reaches(point: Vector3, radius: float) -> bool:
	var stage := leap_stage()
	if stage != Leap.FLIGHT and not (stage == Leap.LAND and leap_progress() < 0.4):
		return false
	for p in _grabbers:
		if p.distance_to(point) < radius:
			return true
	return false


## Where its hands and jaws are (world), from the last frame.
func grabbers() -> PackedVector3Array:
	return _grabbers


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_t += delta
	# How it is moving, from how it has been moved.
	var at := global_position
	if not _was.is_finite():
		_was = at
	var moved := Vector3(at.x - _was.x, 0.0, at.z - _was.z)
	_was = at
	var forward := global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.BACK
	var along := moved.dot(forward)
	var leaping := leap_stage() != Leap.NONE
	if not leaping:
		_phase = fposmod(_phase + along / size / lerpf(WALK["cycle"], GALLOP["cycle"], _gallop), 1.0)
	var speed := moved.length() / delta
	_speed = lerpf(_speed, speed, 1.0 - exp(-10.0 * delta))
	var yaw := global_rotation.y
	_turn = lerpf(_turn, angle_difference(_yaw_was, yaw) / delta, 1.0 - exp(-6.0 * delta))
	_yaw_was = yaw
	var unit_speed := _speed / size
	_moving = move_toward(_moving, 1.0 if unit_speed > 0.08 else 0.0, delta * 4.0)
	_gallop = move_toward(_gallop, smoothstep(1.0, 1.7, unit_speed), delta * 3.0)
	_sit = move_toward(_sit, 1.0 if sitting and unit_speed < 0.1 and not leaping else 0.0, delta * 2.2)
	_display_left -= delta
	_display = move_toward(_display, 1.0 if _display_left > 0.0 and not leaping else 0.0, delta * 4.0)
	_bark += delta
	if leaping:
		_leap += delta
	elif _leap != INF:
		_leap = INF
	_leap_w = move_toward(_leap_w, 1.0 if leap_stage() != Leap.NONE else 0.0, delta * 8.0)
	_pose(delta)


# --- Posing ---

## One whole pose: pelvis and shoulders (the middle of each), each foot, which
## way each knee and elbow bends, the jaw, how bristled, how high it is lifted.
class Pose:
	var pelvis := PELVIS
	var chest := SHOULDERS
	var feet: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var poles: Array[Vector3] = [Vector3(0.4, 0.0, -1.0), Vector3(-0.4, 0.0, -1.0), Vector3(0.3, 0.2, 1.0), Vector3(-0.3, 0.2, 1.0)]
	var head_up := 0.0
	var head_out := 0.0
	var jaw := 0.06
	var bristle := 0.0
	var tail_up := 0.0

	func blend(other: Pose, w: float) -> Pose:
		if w <= 0.0:
			return self
		var p := Pose.new()
		p.pelvis = pelvis.lerp(other.pelvis, w)
		p.chest = chest.lerp(other.chest, w)
		for i in 4:
			p.feet[i] = feet[i].lerp(other.feet[i], w)
			p.poles[i] = poles[i].lerp(other.poles[i], w)
		p.head_up = lerpf(head_up, other.head_up, w)
		p.head_out = lerpf(head_out, other.head_out, w)
		p.jaw = lerpf(jaw, other.jaw, w)
		p.bristle = lerpf(bristle, other.bristle, w)
		p.tail_up = lerpf(tail_up, other.tail_up, w)
		return p


## On all fours, going (or standing, as `_moving` falls).
func _going() -> Pose:
	var p := Pose.new()
	var g := _gallop
	var cycle := lerpf(WALK["cycle"], GALLOP["cycle"], g)
	var duty := lerpf(WALK["duty"], GALLOP["duty"], g)
	var lift := lerpf(WALK["lift"], GALLOP["lift"], g)
	var reach := cycle * duty
	var legs_long: float = _build["legs_long"]
	for i in 4:
		var off := lerpf(WALK["offsets"][i], GALLOP["offsets"][i], g)
		var s := fposmod(_phase - off, 1.0)
		var foot := REST[i]
		var dz := 0.0
		var dy := 0.0
		if s < duty:
			dz = reach * (0.5 - s / duty)
		else:
			var k := (s - duty) / (1.0 - duty)
			var e := k * k * (3.0 - 2.0 * k)
			dz = reach * (-0.5 + e)
			dy = lift * sin(PI * k) * (1.2 if i < 2 else 1.0)
		foot.z += dz * _moving
		foot.y += dy * _moving
		if i >= 2:
			foot.z -= 0.03 * (legs_long - 1.0) * 10.0
		p.feet[i] = foot
	# The body: a bob twice a cycle at a walk; at a gallop, bunched as the hind
	# feet come under it, stretched and thrown up as they push off.
	var wave := sin(TAU * _phase)
	var bob := -cos(TAU * 2.0 * _phase) * 0.012 * (1.0 - g) * _moving
	var bound := sin(TAU * (_phase - 0.2)) * 0.05 * g * _moving
	var stretch := sin(TAU * (_phase - 0.05)) * 0.07 * g * _moving
	p.pelvis = Vector3(0.0, PELVIS.y * legs_long + bob + bound - 0.02 * g, PELVIS.z - stretch * 0.5)
	p.chest = Vector3(0.0, SHOULDERS.y + bob * 0.6 + bound * 0.7 - 0.03 * g, SHOULDERS.z + stretch * 0.5 + 0.03 * g)
	# At a walk the shoulders roll with the hands.
	p.chest.x = wave * 0.012 * (1.0 - g) * _moving
	p.head_up = -0.15 + 0.06 * g + sin(TAU * 2.0 * _phase) * 0.05 * _moving
	p.head_out = 0.03 * g
	p.jaw = 0.06 + 0.12 * g * _moving
	p.tail_up = 0.2 * g * _moving
	# Breath, and panting.
	var breath := sin(_t * lerpf(2.0, 9.0, panting))
	p.chest.y += breath * lerpf(0.004, 0.012, panting)
	p.jaw = maxf(p.jaw, panting * (0.32 + 0.1 * breath))
	p.head_up -= panting * 0.12
	return p


## Up on its haunches.
func _sat() -> Pose:
	var p := Pose.new()
	var breath := sin(_t * 2.0)
	p.pelvis = Vector3(0.0, 0.16, -0.22)
	p.chest = Vector3(0.0, 0.62 + breath * 0.005, -0.08)
	p.feet = [Vector3(0.08, 0.0, 0.17), Vector3(-0.09, 0.0, 0.19), Vector3(0.16, 0.0, 0.07), Vector3(-0.16, 0.0, 0.07)]
	p.poles = [Vector3(0.5, 0.0, -1.0), Vector3(-0.5, 0.0, -1.0), Vector3(0.6, 1.0, 0.6), Vector3(-0.6, 1.0, 0.6)]
	p.head_up = 0.05
	p.jaw = 0.04
	p.tail_up = -0.3
	return p


## The threat: reared up over its hands, yawning, slapping the ground.
func _threat() -> Pose:
	var p := Pose.new()
	var slap_time := fposmod(_t, 0.7) / 0.7
	var side := int(_t / 0.7) % 2
	var raised := sin(PI * clampf(slap_time / 0.75, 0.0, 1.0))
	var thump := smoothstep(0.75, 0.8, slap_time) * (1.0 - smoothstep(0.8, 1.0, slap_time))
	p.pelvis = Vector3(0.0, 0.36, -0.34)
	p.chest = Vector3(0.0, 0.8 - thump * 0.05 + raised * 0.03, 0.1)
	p.feet = [Vector3(0.17, 0.0, 0.42), Vector3(-0.17, 0.0, 0.42), Vector3(0.15, 0.0, -0.26), Vector3(-0.15, 0.0, -0.26)]
	p.feet[side] += Vector3(0.0, 0.3 * raised, -0.08 * raised)
	p.poles = [Vector3(1.0, 0.0, -0.6), Vector3(-1.0, 0.0, -0.6), Vector3(0.5, 0.2, 1.0), Vector3(-0.5, 0.2, 1.0)]
	p.head_up = 0.1 + sin(_t * 9.0) * 0.04
	p.head_out = 0.1
	p.jaw = 1.05 + sin(_t * 5.0) * 0.08
	p.bristle = 1.0
	p.tail_up = 0.6
	return p


## The leap: crouched, flying, landed.
func _leaping() -> Pose:
	var p := Pose.new()
	var k := leap_progress()
	match leap_stage():
		Leap.CROUCH:
			var c := smoothstep(0.0, 1.0, k)
			p.pelvis = PELVIS + Vector3(0.0, -0.17 * c, 0.04 * c)
			p.chest = SHOULDERS + Vector3(0.0, -0.2 * c, -0.03 * c)
			p.feet = [REST[0] + Vector3(0.02, 0, -0.06 * c), REST[1] + Vector3(-0.02, 0, -0.06 * c), REST[2] + Vector3(0.02, 0, 0.05 * c), REST[3] + Vector3(-0.02, 0, 0.05 * c)]
			p.head_up = -0.1 + 0.2 * c
			p.jaw = 0.1 + 0.4 * c
			p.bristle = c
			p.tail_up = 0.4 * c
		Leap.FLIGHT:
			var lift := 4.0 * k * (1.0 - k)
			p.pelvis = Vector3(0.0, 0.5, -0.38)
			p.chest = Vector3(0.0, 0.66 + 0.05 * lift, 0.28)
			var reach := 0.9 - 0.25 * k
			p.feet = [Vector3(0.26, 0.55 - 0.35 * k, 0.28 + reach), Vector3(-0.26, 0.55 - 0.35 * k, 0.28 + reach),
				Vector3(0.12, 0.3, -0.8 + 0.25 * k), Vector3(-0.12, 0.3, -0.78 + 0.25 * k)]
			p.poles = [Vector3(1.0, -0.4, 0.0), Vector3(-1.0, -0.4, 0.0), Vector3(0.2, -1.0, 0.2), Vector3(-0.2, -1.0, 0.2)]
			p.head_up = 0.2 - 0.2 * k
			p.head_out = 0.08
			p.jaw = 0.95
			p.bristle = 1.0
			p.tail_up = 0.5
		Leap.LAND:
			var hit := 1.0 - smoothstep(0.0, 1.0, k)
			p.pelvis = PELVIS + Vector3(0.0, -0.05 * hit, -0.05 * hit)
			p.chest = SHOULDERS + Vector3(0.0, -0.2 * hit, 0.1 * hit)
			p.feet = [REST[0] + Vector3(0.06, 0, 0.16 * hit), REST[1] + Vector3(-0.06, 0, 0.16 * hit), REST[2], REST[3]]
			p.head_up = -0.25 * hit
			p.jaw = 0.4 * hit + 0.06
			p.bristle = hit
	return p


## The lift off the ground now (units), and the forward pitch of the whole body.
func _lift() -> float:
	if leap_stage() == Leap.FLIGHT:
		var k := leap_progress()
		return 4.0 * k * (1.0 - k) * _height / size
	return 0.0


func _pose(delta: float) -> void:
	var p := _going()
	p = p.blend(_sat(), smoothstep(0.0, 1.0, _sit))
	p = p.blend(_threat(), smoothstep(0.0, 1.0, _display))
	if leap_stage() != Leap.NONE or _leap_w > 0.0:
		p = p.blend(_leaping(), _leap_w)
	# The bark: thrown up and snapped open, over whatever else it is doing.
	if _bark < BARK_TIME:
		var b := sin(PI * _bark / BARK_TIME)
		p.head_up += 0.2 * b
		p.jaw = maxf(p.jaw, 0.85 * b)
		p.chest += Vector3(0.0, 0.03, 0.02) * b
		p.bristle = maxf(p.bristle, b * 0.6)
	# Leaning into turns, and lifted in a leap.
	var lean := clampf(-_turn * _speed * 0.03, -0.3, 0.3)
	var pitch := 0.0
	if leap_stage() == Leap.FLIGHT:
		pitch = lerpf(-0.25, 0.2, leap_progress())
	_frame = Transform3D(Basis(Vector3.BACK, lean) * Basis(Vector3.RIGHT, pitch), Vector3(0.0, _lift(), 0.0))
	_look(p, delta)
	_apply(p)


## Where its eyes are on: what it was given, or where it goes, or (still) about it.
func _look(p: Pose, delta: float) -> void:
	var want := Vector3(0.0, -0.3, 1.0)
	if look_at_point.is_finite():
		var local := (global_transform.affine_inverse() * look_at_point) / size
		var from := p.chest + Vector3(0.0, 0.15, 0.2)
		want = (local - from).normalized()
		if want.z < 0.2:
			# (it cannot turn its head right round: it looks as far round as it can)
			want.z = 0.2
			want = want.normalized()
	elif _moving < 0.5:
		_scan_next -= delta
		if _scan_next <= 0.0:
			_scan_next = _rng.randf_range(0.8, 2.6)
			_scan = Vector3(_rng.randf_range(-1.1, 1.1), _rng.randf_range(-0.25, 0.15), 1.0)
		want = _scan.normalized()
	_gaze = _gaze.slerp(want, 1.0 - exp(-7.0 * delta)) if delta > 0.0 else want



# --- The skeleton ---

## Its bones. None is the child of another: each is posed straight in the
## skeleton's space (where its two ends are, worked out in `_joints`), so the
## mesh bends between them however the body is put.
const BONES: Array[String] = ["rump", "back", "chest", "neck", "head", "jaw", "mane",
	"arm_l", "arm_r", "forearm_l", "forearm_r", "hand_l", "hand_r",
	"thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r",
	"tail_1", "tail_2", "tail_3", "tail_4", "tail_5"]
const RUMP := 0
const BACK := 1
const CHEST := 2
const NECK := 3
const HEAD := 4
const JAW := 5
const MANE := 6
const ARM_U := 7
const ARM_L := 9
const HAND := 11
const LEG_U := 13
const LEG_L := 15
const FOOT := 17
const TAIL := 19
## The way it looks as it stands, before any looking about.
const STANDING_GAZE := Vector3(0.0, -0.3, 1.0)


## Standing on all fours, still.
func _standing() -> Pose:
	var p := Pose.new()
	p.pelvis = Vector3(0.0, PELVIS.y * float(_build["legs_long"]), PELVIS.z)
	for i in 4:
		p.feet[i] = REST[i]
	return p


## Where everything is, for a pose and a way of looking (units, the body's own space).
func _joints(p: Pose, gaze_dir: Vector3) -> Dictionary:
	var j := {}
	var spine := p.chest - p.pelvis
	var torso := Basis.looking_at(-spine.normalized(), Vector3.UP)
	var up := torso.y
	var side := torso.x
	var fwd := torso.z
	var chest_r: float = _build["chest"]
	var haunch_r: float = _build["haunch"]
	j["torso"] = torso
	j["pelvis"] = p.pelvis
	j["chest"] = p.chest
	j["mid"] = p.pelvis.lerp(p.chest, 0.5) + up * 0.025
	j["tail_root"] = p.pelvis - fwd * haunch_r * 0.95 + up * 0.03
	var neck := p.chest + fwd * chest_r * 0.65 + up * chest_r * 0.4
	j["neck"] = neck
	# Limbs, each bent at the elbow or knee to reach its foot.
	var roots := PackedVector3Array()
	var mids := PackedVector3Array()
	var ends := PackedVector3Array()
	for i in 4:
		var front := i < 2
		var sign := 1.0 if i % 2 == 0 else -1.0
		var root := (p.chest + side * sign * chest_r * 0.72 - up * 0.04) if front else (p.pelvis + side * sign * haunch_r * 0.8 - up * 0.03)
		var end := p.feet[i] + Vector3(0.0, 0.04 if front else 0.05, 0.0)
		var lengths := ARM if front else LEG * float(_build["legs_long"])
		var pole := p.poles[i]
		var mid := _bend(root, end, lengths.x, lengths.y, pole)
		roots.append(root)
		mids.append(mid)
		# (the end as far as the bones reach, if the foot is further)
		ends.append(mid + (end - mid).normalized() * lengths.y)
	j["roots"] = roots
	j["mids"] = mids
	j["ends"] = ends
	j["feet_up"] = PackedFloat32Array([p.feet[0].y, p.feet[1].y, p.feet[2].y, p.feet[3].y])
	# The head, turned to look along `gaze_dir`, tipped up by `head_up`; the jaw.
	var gaze := (Basis(Vector3.RIGHT, -p.head_up) * gaze_dir.normalized()).normalized()
	var hs: float = _build["head"]
	var head_at := neck + Vector3(0.0, 0.04, 0.08 + p.head_out) + gaze * 0.05
	var head_basis := Basis.looking_at(-gaze, Vector3.UP)
	var head := Transform3D(head_basis, head_at)
	j["head"] = head_at - gaze * 0.08 * hs
	j["head_xform"] = head
	j["jaw_xform"] = Transform3D(head_basis * Basis(Vector3.RIGHT, p.jaw * 0.85), head * (Vector3(0.0, -0.035, 0.03) * hs))
	j["mane_xform"] = Transform3D(torso * Basis.from_scale(Vector3.ONE * (1.0 + p.bristle * 0.3)), p.chest + up * chest_r * 0.6)
	# The tail: up from the rump in a hook and hanging from the bend (a baboon's),
	# or a short stub (the mandrill's).
	var tail := PackedVector3Array()
	var at: Vector3 = j["tail_root"]
	tail.append(at)
	var swing := sin(_t * 1.7 + _phase * TAU) * 0.08 + clampf(_turn, -2.0, 2.0) * 0.05
	# Up and back from the rump in an arch, then broken and hanging.
	var step: float = _build["tail_step"]
	var dir := (-fwd * 0.55 + up * (1.0 + p.tail_up * 0.6)).normalized()
	for k in 5:
		at += dir * step + side * swing * k * step * 0.15
		tail.append(at)
		if k == 1:
			dir = (-fwd * 0.9 + Vector3.DOWN * (0.35 - p.tail_up * 0.3)).normalized()
		elif k >= 2:
			dir = dir.lerp((Vector3.DOWN - fwd * 0.25).normalized(), 0.45).normalized()
	j["tail"] = tail
	return j


## Each bone's two ends, as a pair, or (for the bones that are not stretched
## between two places: head, jaw, mane, hands, feet) its whole transform.
func _pairs(j: Dictionary) -> Array:
	var pairs := []
	pairs.resize(BONES.size())
	pairs[RUMP] = [j["tail_root"], j["pelvis"]]
	pairs[BACK] = [j["pelvis"], j["mid"]]
	pairs[CHEST] = [j["mid"], j["chest"]]
	pairs[NECK] = [j["chest"], j["neck"]]
	pairs[HEAD] = j["head_xform"]
	pairs[JAW] = j["jaw_xform"]
	pairs[MANE] = j["mane_xform"]
	var torso: Basis = j["torso"]
	for i in 4:
		var front := i < 2
		var root: Vector3 = j["roots"][i]
		var mid: Vector3 = j["mids"][i]
		var end: Vector3 = j["ends"][i]
		pairs[(ARM_U if front else LEG_U) + i % 2] = [root, mid]
		pairs[(ARM_L if front else LEG_L) + i % 2] = [mid, end]
		if front:
			pairs[HAND + i % 2] = Transform3D(_along((end - mid).normalized(), torso.x), end)
		else:
			# Flat on the ground; pointed back as it is lifted (trailing in a leap).
			var up: float = j["feet_up"][i]
			pairs[FOOT + i % 2] = Transform3D(Basis(Vector3.RIGHT, clampf(up / 0.25, 0.0, 1.0) * 1.1), end)
	var tail: PackedVector3Array = j["tail"]
	for k in 5:
		pairs[TAIL + k] = [tail[k], tail[k + 1]]
	return pairs


## Each bone's transform (skeleton space, as `_rest` is) for these joints.
func _bone_globals(j: Dictionary) -> Array[Transform3D]:
	var pairs := _pairs(j)
	var torso: Basis = j["torso"]
	var out: Array[Transform3D] = []
	for b in BONES.size():
		if pairs[b] is Transform3D:
			out.append(pairs[b])
			continue
		var a: Vector3 = pairs[b][0]
		var c: Vector3 = pairs[b][1]
		var length := (c - a).length()
		out.append(Transform3D(_along((c - a) / maxf(length, 0.0001), torso.x), a))
	return out


## A basis whose Y is `y`, with X as near `side` as can be.
static func _along(y: Vector3, side: Vector3) -> Basis:
	var z := side.cross(y)
	if z.length() < 0.05:
		z = Vector3.UP.cross(y) if absf(y.y) < 0.9 else Vector3.FORWARD
	z = z.normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, z)


## The middle joint of a limb from `a` to `target`, bones `l1` and `l2` long, bending towards `pole`.
static func _bend(a: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var to := target - a
	var d := clampf(to.length(), 0.01, (l1 + l2) * 0.999)
	var along := to.normalized()
	var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var side := pole - along * pole.dot(along)
	side = side.normalized() if side.length() > 0.001 else Vector3.UP
	return a + along * x + side * h


## Poses the skeleton.
func _apply(p: Pose) -> void:
	var j := _joints(p, _gaze)
	var globals := _bone_globals(j)
	# Each bone is moved from where it stands by as much as `_joints` has moved
	# its own idea of that bone (the model's bones may be turned otherwise).
	for b in globals.size():
		var moved := _frame * globals[b] * _rest[b].affine_inverse()
		var g := _skeleton_from_model * moved * _skeleton_from_model.affine_inverse() * _model_rest[b]
		var bone := _index[b]
		var parent := _skeleton.get_bone_parent(bone)
		if parent >= 0:
			g = _skeleton.get_bone_global_pose(parent).affine_inverse() * g
		_skeleton.set_bone_pose_position(bone, g.origin)
		_skeleton.set_bone_pose_rotation(bone, g.basis.get_rotation_quaternion())
		_skeleton.set_bone_pose_scale(bone, g.basis.get_scale())
	# Where it can take hold of something: its hands, and its jaws.
	var to_world := _model.global_transform * _frame
	_grabbers = PackedVector3Array()
	for i in 2:
		var end: Vector3 = j["ends"][i]
		var mid: Vector3 = j["mids"][i]
		_grabbers.append(to_world * (end + (end - mid).normalized() * 0.05))
	var head: Transform3D = j["head_xform"]
	_grabbers.append(to_world * (head * Vector3(0.0, -0.02, 0.24 * float(_build["head"]))))

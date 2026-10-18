class_name Imp
extends Node3D
## A tiny imp: how it looks and how it moves, and nothing of what it thinks.
## Whatever drives it (a game's enemy script, a cutscene, the example) moves
## this node about and calls on it; it poses itself from that.
##
## WHAT IT IS. A knee-high devil, wiry and pot-bellied: sooty red-brown skin
## going to charcoal on its back, hands and feet; too-long arms with three
## long clawed fingers and a thumb; short bowed legs standing on its toes;
## big bat's ears; two small horns curving back; stubby leathery wings on its
## shoulder blades; a whip of a tail with a barbed tip; small glinting eyes
## under a heavy brow and a wide grin of needle teeth. It is one skinned mesh
## (models/imp.glb, built in Blender by tools/build_imp.py) on a skeleton
## posed here, so each imp is one draw.
##
## HOW IT MOVES. Move the node and turn it; it works out its own speed from how
## it is moved, in its own floor (the node's XZ plane: its Y is "up" for it).
## So it walks on walls and ceilings just as on the ground: turn the node so
## that its Y is the wall's normal and its Z the way it is going, and move it.
## - slow, it walks upright, hunched, its long arms swinging;
## - faster, it drops onto all fours and scuttles, in diagonal pairs, then
##   bounds (it goes on all fours from about `FOURS_FROM` of its heights a
##   second, and `on_all_fours` makes it whatever its speed);
## - `clinging`: flat against what it is on, its limbs splayed out wide like
##   a lizard's (on a wall), and the same scuttle from there;
## - `riding`: hugging something round (the node's -Y is towards it, its Z up
##   it): arms clasped round it, claws in, legs gripping, wriggling;
## - `tumbling`: thrown, its limbs flail (whoever throws it turns it).
## It leans into turns, its tail sways and its ears twitch. `look_at_point`
## (world, INF for none) is what its head snaps round to; left alone it looks
## about in quick, bird-like jerks.
##
## WHAT IT DOES, each on a call, blending in and out by itself:
## - `cackle()`: head thrown back, jaw chattering, shoulders shaking, clutching
##   its belly (on all fours or riding, only the head and shoulders).
## - `chitter()`: a quick chatter of its teeth, ears up.
## - `tantrum(seconds)`: stamping, beating the ground with its fists, its head
##   thrashing and its tail whipping, ears flat, shrieking.
## - `leap(flight, height)`: crouches (`leap_stage()` CROUCH, `CROUCH_TIME`),
##   springs, and is in the air `flight` seconds (FLIGHT), arms flung out with
##   claws spread, wings open, tail streaming, `height` up at the top (it lifts
##   itself: move it along yourself), and lands on all fours (LAND).
## `reaches(point, radius)` says whether its claws or jaws are on a point now
## (only while it is leaping), for whatever decides a grab; `grabbers()` says
## where they are.
##
## SOUNDS (`voice`): its cackle, a chitter and a shriek, made in code, through
## its own AudioStreamPlayer3D. Only when called; `voice` off for none.
##
## Set `size` (metres to the top of its head upright) and `seed_value` (its
## own small differences) before it goes into the tree. `settle()` puts it
## straight into its pose where it is, for when it is put somewhere.

enum Leap { NONE, CROUCH, FLIGHT, LAND }

const CROUCH_TIME := 0.2
const LAND_TIME := 0.32
const CACKLE_TIME := 1.1
const CHITTER_TIME := 0.5

## How fast (its own heights a second) it goes before it drops onto all fours,
## and from what speed it bounds.
const FOURS_FROM := 1.6
const BOUND_FROM := 4.5

## Colours, as the model is built (tools/build_imp.py) and the shader takes them.
const SKIN := Color(0.3, 0.12, 0.08)
const SOOT := Color(0.07, 0.055, 0.05)
const EYE := Color(1.0, 0.62, 0.12)

## Limb lengths (its own units: one is its height to the crown): upper arm,
## forearm; thigh, shin. Its arms are too long: hanging, its claws all but
## touch the ground.
const ARM := Vector2(0.225, 0.22)
const LEG := Vector2(0.135, 0.13)
## Where the ankle is from the ball of the foot (it stands on its toes).
const ANKLE := Vector3(0.0, 0.065, -0.055)
## How far the hand reaches past the wrist (palm and fingers).
const HAND_LONG := 0.12

## Its stances, as places (units): pelvis and chest, and where each hand
## (wrist) and foot (ball) is: left hand, right hand, left foot, right foot.
## +X is its left, +Z ahead.
const UPRIGHT := {"pelvis": Vector3(0.0, 0.3, -0.03), "chest": Vector3(0.0, 0.52, 0.045),
	"feet": [Vector3(0.15, 0.12, 0.07), Vector3(-0.15, 0.12, 0.07), Vector3(0.095, 0.0, 0.04), Vector3(-0.095, 0.0, 0.04)],
	"poles": [Vector3(0.5, 0.0, -1.0), Vector3(-0.5, 0.0, -1.0), Vector3(0.8, 0.0, 1.0), Vector3(-0.8, 0.0, 1.0)]}
const FOURS := {"pelvis": Vector3(0.0, 0.22, -0.11), "chest": Vector3(0.0, 0.27, 0.11),
	"feet": [Vector3(0.16, 0.03, 0.29), Vector3(-0.16, 0.03, 0.29), Vector3(0.12, 0.0, -0.12), Vector3(-0.12, 0.0, -0.12)],
	"poles": [Vector3(1.0, 0.4, -0.6), Vector3(-1.0, 0.4, -0.6), Vector3(0.9, 0.3, 0.6), Vector3(-0.9, 0.3, 0.6)]}
const CLING := {"pelvis": Vector3(0.0, 0.11, -0.13), "chest": Vector3(0.0, 0.13, 0.12),
	"feet": [Vector3(0.25, 0.03, 0.26), Vector3(-0.25, 0.03, 0.26), Vector3(0.21, 0.0, -0.18), Vector3(-0.21, 0.0, -0.18)],
	"poles": [Vector3(1.0, 1.0, -0.3), Vector3(-1.0, 1.0, -0.3), Vector3(1.0, 1.0, 0.3), Vector3(-1.0, 1.0, 0.3)]}
## The gaits: when each foot comes down in the cycle, how much of it each is
## down, how far the body goes in one (units), and how high a foot is lifted.
const WALK := {"offsets": [0.5, 0.0, 0.0, 0.5], "duty": 0.62, "cycle": 0.38, "lift": 0.06}
const TROT := {"offsets": [0.0, 0.5, 0.5, 0.0], "duty": 0.5, "cycle": 0.55, "lift": 0.07}
const BOUND := {"offsets": [0.5, 0.58, 0.02, 0.0], "duty": 0.32, "cycle": 1.25, "lift": 0.12}

## Metres to the top of its head, standing upright.
@export var size := 0.44
## Its own small differences (skin, build): two with one seed are alike.
@export var seed_value := 0
## Use the low-poly model (models/imp_lo.glb), as `low_poly` does for every imp.
@export var force_low := false
## Its sounds (cackle, chitter, shriek), and how loud and far.
@export var voice := true
@export var volume_db := -2.0
@export var voice_range := 30.0

## Every imp uses the low-poly model (phones).
static var low_poly := false

## What it looks at (world). INF: it looks where it goes, or about it.
var look_at_point := Vector3.INF
## On all fours whatever its speed.
var on_all_fours := false
## Flat against what it is on, limbs splayed (a wall, a ceiling).
var clinging := false
## Hugging something round, which is at its -Y (see the class notes).
var riding := false
## Thrown: flailing.
var tumbling := false

const MODEL := "res://creatures/imp/models/imp.glb"
const MODEL_LO := "res://creatures/imp/models/imp_lo.glb"

var _model: Node3D
var _skeleton: Skeleton3D
var _body: MeshInstance3D
var _rest: Array[Transform3D] = []
var _index := PackedInt32Array()
var _model_rest: Array[Transform3D] = []
var _skeleton_from_model := Transform3D.IDENTITY
var _frame := Transform3D.IDENTITY
var _voice: AudioStreamPlayer3D

var _t := 0.0
var _was := Vector3.INF
var _forward_was := Vector3.ZERO
var _speed := 0.0
var _turn := 0.0
var _phase := 0.0
var _fours := 0.0
var _bound := 0.0
var _moving := 0.0
var _cling := 0.0
var _ride := 0.0
var _tumble := 0.0
var _tantrum := 0.0
var _tantrum_left := 0.0
var _cackle := INF
var _chitter := INF
var _leap := INF
var _flight := 0.4
var _height := 0.4
var _leap_w := 0.0
var _gaze := Vector3(0.0, 0.0, 1.0)
var _scan := Vector3(0.0, 0.0, 1.0)
var _scan_next := 0.0
var _ears := 0.0
var _ear_twitch := Vector2.ZERO
var _twitch_next := 1.0
var _rng := RandomNumberGenerator.new()
var _build := 1.0
var _grabbers := PackedVector3Array()

static var _sounds := {}


func _ready() -> void:
	_rng.seed = seed_value
	_build = _rng.randf_range(0.92, 1.08)
	_rest = _bone_globals(_joints(_standing(), Vector3(0.0, -0.15, 1.0)))
	var low := low_poly or force_low
	_model = (load(MODEL_LO if low else MODEL) as PackedScene).instantiate()
	_model.scale = Vector3.ONE * size
	add_child(_model)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	_body = _model.find_children("*", "MeshInstance3D", true, false)[0]
	_body.material_override = ImpLook.material()
	_body.custom_aabb = AABB(Vector3(-0.8, -0.6, -0.8), Vector3(1.6, 1.8, 1.8))
	_body.set_instance_shader_parameter(&"tone", _rng.randf_range(0.85, 1.15))
	_body.set_instance_shader_parameter(&"warmth", _rng.randf_range(-0.5, 0.5))
	_index.resize(BONES.size())
	_model_rest.resize(BONES.size())
	_skeleton_from_model = _skeleton.global_transform.affine_inverse() * _model.global_transform
	for b in BONES.size():
		_index[b] = _skeleton.find_bone(BONES[b])
		_model_rest[b] = _skeleton.get_bone_global_rest(_index[b])
	if voice:
		_voice = AudioStreamPlayer3D.new()
		_voice.volume_db = volume_db
		_voice.unit_size = 3.0
		_voice.max_distance = voice_range
		_voice.position = Vector3(0.0, 0.8 * size, 0.1 * size)
		add_child(_voice)
	_phase = _rng.randf()
	settle()


## Puts it straight into its pose as it is now, with nothing going on.
func settle() -> void:
	_was = global_position
	_forward_was = global_basis.z
	_speed = 0.0
	_moving = 0.0
	_fours = 1.0 if on_all_fours else 0.0
	_cling = 1.0 if clinging else 0.0
	_ride = 1.0 if riding else 0.0
	_tumble = 1.0 if tumbling else 0.0
	_tantrum = 0.0
	_tantrum_left = 0.0
	_cackle = INF
	_leap = INF
	_leap_w = 0.0
	_pose(0.0)


func cackle() -> void:
	_cackle = 0.0
	_say(&"cackle")


func chitter() -> void:
	_chitter = 0.0
	_say(&"chitter")


func tantrum(seconds := 1.4) -> void:
	if _tantrum_left <= 0.0:
		_say(&"shriek")
	_tantrum_left = maxf(_tantrum_left, seconds)


func in_tantrum() -> bool:
	return _tantrum_left > 0.0


func cackling() -> bool:
	return _cackle < CACKLE_TIME


## Leaps: a crouch, then `flight` seconds in the air rising `height` (metres) at the top.
func leap(flight := 0.4, height := 0.4) -> void:
	_flight = maxf(flight, 0.12)
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


## Ends a leap at once (it has landed on something, or been caught in the air).
func end_leap() -> void:
	_leap = INF


## Whether its claws or jaws are within `radius` of `point` (world), while it is in the air.
func reaches(point: Vector3, radius: float) -> bool:
	if leap_stage() != Leap.FLIGHT:
		return false
	for p in _grabbers:
		if p.distance_to(point) < radius:
			return true
	return false


## Where its claws and jaws are (world), from the last frame.
func grabbers() -> PackedVector3Array:
	return _grabbers


## Where its head is (world), from the last frame.
func head_position() -> Vector3:
	return _grabbers[2] if _grabbers.size() > 2 else global_position


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_t += delta
	# How it is moving, in its own floor, from how it has been moved.
	var at := global_position
	if not _was.is_finite():
		_was = at
	var basis_now := global_basis.orthonormalized()
	var moved := basis_now.inverse() * (at - _was)
	moved.y = 0.0
	moved /= size
	_was = at
	var leaping := leap_stage() != Leap.NONE
	var cycle := _cycle()
	if not leaping:
		_phase = fposmod(_phase + moved.z / cycle, 1.0)
	var speed := moved.length() / delta
	_speed = lerpf(_speed, speed, 1.0 - exp(-10.0 * delta))
	var forward := basis_now.z
	var up := basis_now.y
	var turned := 0.0
	if _forward_was.length_squared() > 0.5:
		var a := _forward_was - up * _forward_was.dot(up)
		if a.length_squared() > 0.0001:
			turned = a.normalized().signed_angle_to(forward, up)
	_forward_was = forward
	_turn = lerpf(_turn, turned / delta, 1.0 - exp(-6.0 * delta))
	_moving = move_toward(_moving, 1.0 if _speed > 0.15 else 0.0, delta * 5.0)
	var want_fours := on_all_fours or clinging or _speed > FOURS_FROM
	_fours = move_toward(_fours, 1.0 if want_fours else 0.0, delta * 4.0)
	_bound = move_toward(_bound, smoothstep(BOUND_FROM * 0.85, BOUND_FROM * 1.15, _speed) * (1.0 - _cling), delta * 3.0)
	_cling = move_toward(_cling, 1.0 if clinging else 0.0, delta * 5.0)
	_ride = move_toward(_ride, 1.0 if riding else 0.0, delta * 7.0)
	_tumble = move_toward(_tumble, 1.0 if tumbling else 0.0, delta * 8.0)
	_tantrum_left -= delta
	_tantrum = move_toward(_tantrum, 1.0 if _tantrum_left > 0.0 and not leaping and not riding and not tumbling else 0.0, delta * 5.0)
	_cackle += delta
	_chitter += delta
	if leaping:
		_leap += delta
	elif _leap != INF:
		_leap = INF
	_leap_w = move_toward(_leap_w, 1.0 if leap_stage() != Leap.NONE else 0.0, delta * 10.0)
	# The ears: flat in a tantrum or a leap, up when it chatters or is after something.
	var ears := 0.0
	if _tantrum > 0.3 or leap_stage() == Leap.FLIGHT or tumbling:
		ears = -1.0
	elif _chitter < CHITTER_TIME or look_at_point.is_finite():
		ears = 0.7
	_ears = move_toward(_ears, ears, delta * 6.0)
	_twitch_next -= delta
	if _twitch_next <= 0.0:
		_twitch_next = _rng.randf_range(0.6, 2.8)
		_ear_twitch = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * 0.5
	_ear_twitch = _ear_twitch.move_toward(Vector2.ZERO, delta * 3.0)
	_pose(delta)


func _cycle() -> float:
	var quad: float = lerpf(TROT["cycle"], BOUND["cycle"], _bound)
	return lerpf(WALK["cycle"], quad, _fours)


# --- Posing ---

## One whole pose: pelvis and chest, each hand (wrist) and foot (ball), which
## way each elbow and knee bends, and the rest.
class Pose:
	var pelvis := Vector3.ZERO
	var chest := Vector3.ZERO
	var feet: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var poles: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	## How far each hand is laid flat (0: in line with the forearm).
	var flat := [0.0, 0.0]
	var head_up := 0.0
	var head_turn := 0.0
	var jaw := 0.05
	var fingers := 0.2
	var wings := 0.0
	var tail_up := 0.0
	var tail_whip := 0.0
	var belly := 0.0

	static func from(stance: Dictionary) -> Pose:
		var p := Pose.new()
		p.pelvis = stance["pelvis"]
		p.chest = stance["chest"]
		for i in 4:
			p.feet[i] = stance["feet"][i]
			p.poles[i] = stance["poles"][i]
		return p

	func blend(other: Pose, w: float) -> Pose:
		if w <= 0.0:
			return self
		if w >= 1.0:
			return other
		var p := Pose.new()
		p.pelvis = pelvis.lerp(other.pelvis, w)
		p.chest = chest.lerp(other.chest, w)
		for i in 4:
			p.feet[i] = feet[i].lerp(other.feet[i], w)
			p.poles[i] = poles[i].lerp(other.poles[i], w)
		for i in 2:
			p.flat[i] = lerpf(flat[i], other.flat[i], w)
		p.head_up = lerpf(head_up, other.head_up, w)
		p.head_turn = lerpf(head_turn, other.head_turn, w)
		p.jaw = lerpf(jaw, other.jaw, w)
		p.fingers = lerpf(fingers, other.fingers, w)
		p.wings = lerpf(wings, other.wings, w)
		p.tail_up = lerpf(tail_up, other.tail_up, w)
		p.tail_whip = lerpf(tail_whip, other.tail_whip, w)
		p.belly = lerpf(belly, other.belly, w)
		return p


## Where a foot is in its step: (forward, up) from where it stands.
static func _step(phase: float, offset: float, duty: float, reach: float, lift: float) -> Vector2:
	var s := fposmod(phase - offset, 1.0)
	if s < duty:
		return Vector2(reach * (0.5 - s / duty), 0.0)
	var k := (s - duty) / (1.0 - duty)
	var e := k * k * (3.0 - 2.0 * k)
	return Vector2(reach * (-0.5 + e), lift * sin(PI * k))


## Upright, walking (or standing, as `_moving` falls).
func _upright() -> Pose:
	var p := Pose.from(UPRIGHT)
	var reach: float = WALK["cycle"] * WALK["duty"]
	for i in [2, 3]:
		var s := _step(_phase, WALK["offsets"][i], WALK["duty"], reach, WALK["lift"])
		p.feet[i] += Vector3(0.0, s.y, s.x) * _moving
	# Its long arms swing against its legs, the hands well forward and back.
	var swing := sin(TAU * _phase)
	p.feet[0] += Vector3(0.0, 0.03 * absf(swing), 0.11 * swing) * _moving
	p.feet[1] += Vector3(0.0, 0.03 * absf(swing), -0.11 * swing) * _moving
	# A waddle: bobbing twice a stride, swaying from foot to foot; hunched lower going.
	var bob := -cos(TAU * 2.0 * _phase) * 0.018 * _moving
	var sway := sin(TAU * _phase) * 0.018 * _moving
	p.pelvis += Vector3(sway, bob - 0.02 * _moving, 0.0)
	p.chest += Vector3(sway * 1.4, bob * 0.7 - 0.04 * _moving, 0.05 * _moving)
	p.head_up = 0.1 * _moving
	p.tail_up = 0.1
	p.belly = 1.0
	p.fingers = 0.35
	# Breathing (the belly goes in and out).
	var breath := sin(_t * 3.1)
	p.chest.y += breath * 0.004
	p.belly += breath * 0.12
	return p


## On all fours (or flat against something with `_cling`), scuttling.
func _fours_pose() -> Pose:
	var p := Pose.from(FOURS).blend(Pose.from(CLING), _cling)
	var b := _bound
	var cycle := lerpf(TROT["cycle"], BOUND["cycle"], b)
	var duty := lerpf(TROT["duty"], BOUND["duty"], b)
	var lift := lerpf(TROT["lift"], BOUND["lift"], b) * lerpf(1.0, 0.6, _cling)
	var reach := cycle * duty * lerpf(1.0, 0.85, _cling)
	for i in 4:
		var off := lerpf(TROT["offsets"][i], BOUND["offsets"][i], b)
		var s := _step(_phase, off, duty, reach, lift)
		# (on a wall the feet swing out round, not straight)
		var out := s.y * 0.6 * _cling * (1.0 if i % 2 == 0 else -1.0)
		p.feet[i] += Vector3(out, s.y * (1.0 - _cling * 0.5), s.x) * _moving
	p.flat = [1.0, 1.0]
	# The body: rolling from one diagonal to the other at a scuttle; at a bound
	# bunched and stretched and thrown up.
	var roll := sin(TAU * _phase) * 0.018 * (1.0 - b) * _moving
	var bound := sin(TAU * (_phase - 0.2)) * 0.05 * b * _moving
	var stretch := sin(TAU * (_phase - 0.05)) * 0.07 * b * _moving
	p.pelvis += Vector3(-roll, bound - absf(roll) * 0.5, -stretch * 0.5)
	p.chest += Vector3(roll, bound * 0.7, stretch * 0.5)
	p.head_up = 0.25 + 0.12 * _cling
	p.tail_up = 0.35 + 0.3 * b * _moving
	p.tail_whip = 0.3 * _moving
	p.fingers = 0.1
	p.belly = 0.6
	p.jaw = 0.08 + 0.15 * b * _moving
	var breath := sin(_t * 3.6)
	p.chest.y += breath * 0.004
	return p


## Hugging what it rides: arms round it, legs gripping, wriggling.
func _riding() -> Pose:
	var p := Pose.new()
	var wr := sin(_t * 7.0)
	var wr2 := sin(_t * 5.3 + 1.0)
	p.pelvis = Vector3(0.0, 0.1, -0.12)
	p.chest = Vector3(0.0, 0.12 + 0.01 * wr, 0.13)
	p.feet = [Vector3(0.21, -0.13, 0.22 + 0.025 * wr2), Vector3(-0.21, -0.13, 0.22 - 0.025 * wr2),
		Vector3(0.18, -0.1, -0.14 - 0.02 * wr), Vector3(-0.18, -0.1, -0.14 + 0.02 * wr)]
	p.poles = [Vector3(1.0, 0.8, -0.2), Vector3(-1.0, 0.8, -0.2), Vector3(1.0, 0.7, 0.2), Vector3(-1.0, 0.7, 0.2)]
	p.flat = [0.4, 0.4]
	p.fingers = 0.85
	p.head_up = 0.35
	p.jaw = 0.2 + 0.2 * maxf(sin(_t * 9.0), 0.0)
	p.tail_up = 0.5
	p.tail_whip = 1.0
	p.wings = 0.35 + 0.25 * sin(_t * 17.0)
	return p


## The tantrum: stamping, beating the ground with both fists, head thrashing.
func _tantrum_pose() -> Pose:
	var p := Pose.from(UPRIGHT)
	var beat := fposmod(_t * 2.6, 1.0)
	var side := int(_t * 2.6) % 2
	var stamp := fposmod(_t * 5.2, 1.0)
	var stamp_side := 2 + (int(_t * 5.2) % 2)
	# Stamping, one foot and the other, fast.
	p.feet[stamp_side] += Vector3(0.0, 0.11 * sin(PI * stamp), 0.02)
	# Hunched right over, fists up over its head and down on the ground.
	var up := sin(PI * clampf(beat / 0.7, 0.0, 1.0))
	var slam := smoothstep(0.7, 0.78, beat) * (1.0 - smoothstep(0.78, 1.0, beat))
	p.pelvis += Vector3(0.0, -0.06, -0.03)
	p.chest = Vector3(0.0, 0.41 + 0.07 * up - 0.04 * slam, 0.14 - 0.06 * up)
	for i in 2:
		var s := 1.0 if i == 0 else -1.0
		var mine := up if i == side else up * 0.35
		p.feet[i] = Vector3(0.1 * s, lerpf(0.04, 0.7, mine), lerpf(0.26, 0.05, mine))
		p.poles[i] = Vector3(1.0 * s, -0.3, -0.4)
	p.flat = [0.0, 0.0]
	p.fingers = 1.0
	p.head_up = 0.15 + 0.3 * up
	p.head_turn = sin(_t * 11.0) * 0.7
	p.jaw = 0.85 + sin(_t * 23.0) * 0.12
	p.tail_up = 0.6
	p.tail_whip = 1.6
	p.wings = 0.5 + 0.4 * sin(_t * 13.0)
	return p


## The leap: crouched, flying, landed.
func _leaping() -> Pose:
	var p := Pose.from(FOURS)
	var k := leap_progress()
	match leap_stage():
		Leap.CROUCH:
			var c := smoothstep(0.0, 1.0, k)
			p.pelvis += Vector3(0.0, -0.12 * c, 0.03 * c)
			p.chest += Vector3(0.0, -0.13 * c, -0.04 * c)
			p.feet[0].z -= 0.05 * c
			p.feet[1].z -= 0.05 * c
			p.feet[2].z += 0.05 * c
			p.feet[3].z += 0.05 * c
			p.flat = [1.0, 1.0]
			p.head_up = 0.4 * c
			p.jaw = 0.1 + 0.5 * c
			p.tail_up = 0.6 * c
		Leap.FLIGHT:
			# Spread-eagled at it: arms flung out, claws spread, legs trailing.
			p.pelvis = Vector3(0.0, 0.3, -0.18)
			p.chest = Vector3(0.0, 0.36, 0.16)
			var reach := 0.75 - 0.2 * k
			p.feet = [Vector3(0.24, 0.42 - 0.1 * k, 0.1 + reach * 0.5), Vector3(-0.24, 0.42 - 0.1 * k, 0.1 + reach * 0.5),
				Vector3(0.16, 0.24, -0.45 + 0.15 * k), Vector3(-0.16, 0.24, -0.45 + 0.15 * k)]
			p.poles = [Vector3(1.0, 0.2, -0.5), Vector3(-1.0, 0.2, -0.5), Vector3(0.6, -1.0, 0.0), Vector3(-0.6, -1.0, 0.0)]
			p.fingers = 0.0
			p.head_up = 0.15
			p.jaw = 0.95
			p.wings = 1.0
			p.tail_up = -0.2
			p.tail_whip = 0.4
		Leap.LAND:
			var hit := 1.0 - smoothstep(0.0, 1.0, k)
			p.pelvis += Vector3(0.0, -0.06 * hit, -0.02 * hit)
			p.chest += Vector3(0.0, -0.14 * hit, 0.04 * hit)
			p.feet[0] += Vector3(0.05, 0.0, 0.05 * hit)
			p.feet[1] += Vector3(-0.05, 0.0, 0.05 * hit)
			p.flat = [1.0, 1.0]
			p.head_up = 0.2
			p.jaw = 0.3 * hit + 0.08
			p.wings = 0.6 * hit
	return p


## Thrown: arms and legs flailing every way.
func _tumbling() -> Pose:
	var p := Pose.from(FOURS)
	p.pelvis = Vector3(0.0, 0.28, -0.12)
	p.chest = Vector3(0.0, 0.32, 0.12)
	for i in 4:
		var a := _t * (13.0 + i * 2.3) + i * 1.7
		var s := 1.0 if i % 2 == 0 else -1.0
		var base: Vector3 = FOURS["feet"][i]
		p.feet[i] = base + Vector3(0.1 * s + 0.08 * sin(a) * s, 0.22 + 0.12 * cos(a * 1.3), 0.1 * sin(a * 0.9))
	p.fingers = 0.0
	p.jaw = 0.9
	p.wings = 0.8 + 0.2 * sin(_t * 19.0)
	p.tail_whip = 1.5
	return p


## The lift off what it stands on now (units).
func _lift() -> float:
	if leap_stage() == Leap.FLIGHT:
		var k := leap_progress()
		return 4.0 * k * (1.0 - k) * _height / size
	return 0.0


func _pose(delta: float) -> void:
	var p := _upright()
	if _fours > 0.0:
		p = p.blend(_fours_pose(), smoothstep(0.0, 1.0, _fours))
	if _tantrum > 0.0:
		p = p.blend(_tantrum_pose(), smoothstep(0.0, 1.0, _tantrum))
	if _ride > 0.0:
		p = p.blend(_riding(), smoothstep(0.0, 1.0, _ride))
	if _leap_w > 0.0:
		p = p.blend(_leaping(), _leap_w)
	if _tumble > 0.0:
		p = p.blend(_tumbling(), _tumble)
	# The cackle, over whatever else it does: head thrown back, jaw chattering,
	# shoulders shaking; upright, it clutches its belly.
	if _cackle < CACKLE_TIME:
		var c := sin(PI * clampf(_cackle / CACKLE_TIME, 0.0, 1.0))
		c = minf(c * 2.0, 1.0)
		var shake := sin(_cackle * 31.0)
		p.head_up += 0.55 * c
		p.jaw = maxf(p.jaw, (0.4 + 0.45 * absf(sin(_cackle * 26.0))) * c)
		p.chest += Vector3(0.0, 0.012 * shake, -0.01) * c
		var upright := (1.0 - _fours) * (1.0 - _ride) * (1.0 - _leap_w) * (1.0 - _tantrum)
		if upright > 0.0:
			var w := c * upright
			p.feet[0] = p.feet[0].lerp(Vector3(0.07, 0.37 + 0.01 * shake, 0.17), w)
			p.feet[1] = p.feet[1].lerp(Vector3(-0.07, 0.37 - 0.01 * shake, 0.17), w)
			p.poles[0] = p.poles[0].lerp(Vector3(1.0, -0.5, -0.4), w)
			p.poles[1] = p.poles[1].lerp(Vector3(-1.0, -0.5, -0.4), w)
			p.fingers = lerpf(p.fingers, 0.9, w)
			p.chest.z += 0.03 * w
	# The chitter: a quick chatter of the teeth.
	if _chitter < CHITTER_TIME:
		var c := sin(PI * _chitter / CHITTER_TIME)
		p.jaw = maxf(p.jaw, 0.22 * absf(sin(_chitter * 40.0)) * c)
	var lean := clampf(-_turn * _speed * 0.05, -0.35, 0.35) * (1.0 - _ride)
	var pitch := 0.0
	if leap_stage() == Leap.FLIGHT:
		pitch = lerpf(-0.3, 0.25, leap_progress())
	_frame = Transform3D(Basis(Vector3.BACK, lean) * Basis(Vector3.RIGHT, pitch), Vector3(0.0, _lift(), 0.0))
	_look(p, delta)
	_apply(p)


## Where its eyes are on: what it was given, or where it goes, or (still) about
## it in quick jerks, as a bird looks.
func _look(p: Pose, delta: float) -> void:
	var want := Vector3(0.0, -0.1, 1.0)
	var snap := 9.0
	if look_at_point.is_finite():
		var local := (global_transform.affine_inverse() * look_at_point) / size
		want = (local - p.chest - Vector3(0.0, 0.12, 0.08)).normalized()
		if want.z < 0.1:
			want.z = 0.1
			want = want.normalized()
		snap = 14.0
	elif _moving < 0.5 and _tantrum < 0.5:
		_scan_next -= delta
		if _scan_next <= 0.0:
			_scan_next = _rng.randf_range(0.35, 1.6)
			_scan = Vector3(_rng.randf_range(-1.3, 1.3), _rng.randf_range(-0.3, 0.35), 1.0)
		want = _scan.normalized()
		if _cling > 0.5:
			# (on a wall it looks out from it, at whatever comes by below)
			want = Vector3(_scan.x * 0.6, 0.85, 0.45 + _scan.y).normalized()
		# (it snaps round, and holds)
		snap = 22.0
	_gaze = _gaze.slerp(want, 1.0 - exp(-snap * delta)) if delta > 0.0 else want


# --- The skeleton ---

## Its bones. None is the child of another: each is posed straight in the
## skeleton's space (where its two ends are, worked out in `_joints`), so the
## mesh bends between them however the body is put.
const BONES: Array[String] = ["hips", "belly", "chest", "neck", "head", "jaw", "ear_l", "ear_r",
	"arm_l", "arm_r", "forearm_l", "forearm_r", "hand_l", "hand_r", "fingers_l", "fingers_r",
	"thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r",
	"wing_l", "wing_r", "wingtip_l", "wingtip_r",
	"tail_1", "tail_2", "tail_3", "tail_4", "tail_5", "tail_6", "tail_7"]
const HIPS := 0
const BELLY := 1
const CHEST := 2
const NECK := 3
const HEAD := 4
const JAW := 5
const EAR := 6
const ARM_U := 8
const ARM_L := 10
const HAND := 12
const FINGERS := 14
const LEG_U := 16
const LEG_L := 18
const FOOT := 20
const WING := 22
const WINGTIP := 24
const TAIL := 26
const TAIL_COUNT := 7
const TAIL_STEP := 0.085

## How big its head is (units): the skull's half-width.
const HEAD_SIZE := 0.115
## Where the jaw hinges (head space: +Z ahead, +Y up).
const HINGE := Vector3(0.0, -0.035, -0.015)
## Where each ear grows from (head space, the left one), and how long it is.
const EAR_ROOT := Vector3(0.085, 0.03, -0.03)
const EAR_LONG := 0.17
## Where the wings grow from (from the chest, along: across, up the back, out of the back).
const WING_ROOT := Vector3(0.045, 0.02, -0.075)
const WING_LONG := Vector2(0.11, 0.1)


## Standing upright, still: the way it was modelled.
func _standing() -> Pose:
	var p := Pose.from(UPRIGHT)
	p.fingers = 0.2
	return p


## Where everything is, for a pose and a way of looking (units, its own space).
func _joints(p: Pose, gaze_dir: Vector3) -> Dictionary:
	var j := {}
	var spine := (p.chest - p.pelvis).normalized()
	var side := Vector3.RIGHT - spine * spine.x
	side = side.normalized()
	var front := side.cross(spine).normalized()
	var torso := Basis(side, spine, front)
	j["torso"] = torso
	j["pelvis"] = p.pelvis
	j["chest"] = p.chest
	# The pot belly hangs out in front of the middle of it.
	var middle := p.pelvis.lerp(p.chest, 0.45)
	j["belly"] = middle + front * 0.02 * (1.0 + p.belly * 0.3)
	var neck := p.chest + spine * 0.05 + front * 0.045
	j["neck"] = neck
	# Limbs, each bent at the elbow or knee to reach its hand or foot.
	var roots := PackedVector3Array()
	var mids := PackedVector3Array()
	var ends := PackedVector3Array()
	for i in 4:
		var arm := i < 2
		var sign := 1.0 if i % 2 == 0 else -1.0
		var root := (p.chest + side * sign * 0.083 + spine * 0.005 - front * 0.005) if arm else (p.pelvis + side * sign * 0.062 - spine * 0.03)
		var end := p.feet[i] if arm else p.feet[i] + ANKLE
		var lengths := ARM if arm else LEG
		var mid := _bend(root, end, lengths.x, lengths.y, p.poles[i])
		roots.append(root)
		mids.append(mid)
		ends.append(mid + (end - mid).normalized() * lengths.y)
	j["roots"] = roots
	j["mids"] = mids
	j["ends"] = ends
	j["balls"] = PackedVector3Array([p.feet[2], p.feet[3]])
	j["feet_up"] = PackedFloat32Array([p.feet[0].y, p.feet[1].y, p.feet[2].y, p.feet[3].y])
	# The hands: in line with the forearm, or laid flat ahead on what it is on.
	var hands: Array[Basis] = []
	var knuckles := PackedVector3Array()
	for i in 2:
		var sign := 1.0 if i == 0 else -1.0
		var along := (ends[i] - mids[i]).normalized()
		var flat_way := Vector3(0.35 * sign, -0.12, 1.0).normalized()
		var dir := along.slerp(flat_way, clampf(p.flat[i], 0.0, 1.0) * 0.9).normalized()
		var hand := _along(dir, side)
		hands.append(hand)
		knuckles.append(ends[i] + dir * 0.05)
	j["hands"] = hands
	j["knuckles"] = knuckles
	# The head, turned to look along `gaze_dir`, tipped up by `head_up`; the jaw.
	var gaze := (Basis(Vector3.UP, p.head_turn) * Basis(Vector3.RIGHT, -p.head_up) * gaze_dir.normalized()).normalized()
	var head_at := neck + (spine + Vector3.UP).normalized() * 0.06 + gaze * 0.03
	var head_basis := Basis.looking_at(-gaze, Vector3.UP if absf(gaze.y) < 0.95 else front)
	var head := Transform3D(head_basis, head_at)
	j["head_xform"] = head
	j["jaw_xform"] = Transform3D(head_basis * Basis(Vector3.RIGHT, p.jaw * 0.85), head * HINGE)
	# The ears: out from the skull, laid back flat or pricked up, and twitching.
	var ears: Array[Transform3D] = []
	for i in 2:
		var sign := 1.0 if i == 0 else -1.0
		var root := head * Vector3(EAR_ROOT.x * sign, EAR_ROOT.y, EAR_ROOT.z)
		var lie := Vector3(0.75 * sign, 0.62, -0.28)
		if _ears > 0.0:
			lie = lie.lerp(Vector3(0.55 * sign, 0.85, 0.05), _ears)
		else:
			lie = lie.lerp(Vector3(0.45 * sign, 0.05, -0.9), -_ears)
		var twitch := _ear_twitch.x if i == 0 else _ear_twitch.y
		lie = (lie + Vector3(0.0, twitch * 0.3, twitch * 0.2)).normalized()
		ears.append(Transform3D(_along(head_basis * lie, head_basis.x), root))
	j["ears"] = ears
	# The wings, folded on its back or spread.
	var wing_roots := PackedVector3Array()
	var wing_mids := PackedVector3Array()
	var wing_tips := PackedVector3Array()
	for i in 2:
		var sign := 1.0 if i == 0 else -1.0
		var root := p.chest + side * WING_ROOT.x * sign + spine * WING_ROOT.y + front * WING_ROOT.z
		var w := clampf(p.wings, 0.0, 1.2)
		var one := (side * 0.45 * sign + spine * 0.65 - front * 0.6).lerp(side * 1.0 * sign + spine * 0.35 - front * 0.25, w).normalized()
		var two := (side * 0.15 * sign - spine * 0.75 - front * 0.45).lerp(side * 0.9 * sign - spine * 0.05 - front * 0.4, w).normalized()
		var mid := root + one * WING_LONG.x
		wing_roots.append(root)
		wing_mids.append(mid)
		wing_tips.append(mid + two * WING_LONG.y)
	j["wing_roots"] = wing_roots
	j["wing_mids"] = wing_mids
	j["wing_tips"] = wing_tips
	# The tail: down from the rump, curling up at the end, swaying and whipping.
	var tail := PackedVector3Array()
	var at := p.pelvis - front * 0.065 - spine * 0.03
	tail.append(at)
	var swing := sin(_t * 1.9 + _phase * TAU) * 0.15 + clampf(_turn, -2.0, 2.0) * 0.08
	for k in TAIL_COUNT:
		var bend := -1.0 + p.tail_up * 0.6 + k * 0.3
		var lash := sin(_t * (2.5 + p.tail_whip * 7.0) - k * 0.9) * (0.12 + p.tail_whip * 0.22) * (k + 1) / TAIL_COUNT
		var down := -front * cos(bend) + spine * sin(bend)
		var dir := (down + side * (swing + lash) * (0.4 + k * 0.15)).normalized()
		at += dir * TAIL_STEP * (1.0 - k * 0.04)
		tail.append(at)
	j["tail"] = tail
	j["fingers"] = p.fingers
	return j


## Each bone's two ends, as a pair, or (for the bones that are not stretched
## between two places) its whole transform.
func _pairs(j: Dictionary) -> Array:
	var pairs := []
	pairs.resize(BONES.size())
	var torso: Basis = j["torso"]
	pairs[HIPS] = [j["pelvis"] - torso.y * 0.06, j["pelvis"]]
	pairs[BELLY] = [j["pelvis"], j["belly"]]
	pairs[CHEST] = [j["belly"], j["chest"]]
	pairs[NECK] = [j["chest"], j["neck"]]
	pairs[HEAD] = j["head_xform"]
	pairs[JAW] = j["jaw_xform"]
	var ears: Array = j["ears"]
	pairs[EAR] = ears[0]
	pairs[EAR + 1] = ears[1]
	var hands: Array = j["hands"]
	var curl: float = j["fingers"]
	for i in 4:
		var arm := i < 2
		var root: Vector3 = j["roots"][i]
		var mid: Vector3 = j["mids"][i]
		var end: Vector3 = j["ends"][i]
		pairs[(ARM_U if arm else LEG_U) + i % 2] = [root, mid]
		pairs[(ARM_L if arm else LEG_L) + i % 2] = [mid, end]
		if arm:
			var hand: Basis = hands[i]
			pairs[HAND + i] = Transform3D(hand, end)
			pairs[FINGERS + i] = Transform3D(hand * Basis(Vector3.RIGHT, curl * 1.3), j["knuckles"][i])
		else:
			pairs[FOOT + i % 2] = [end, j["balls"][i - 2]]
	for i in 2:
		pairs[WING + i] = [j["wing_roots"][i], j["wing_mids"][i]]
		pairs[WINGTIP + i] = [j["wing_mids"][i], j["wing_tips"][i]]
	var tail: PackedVector3Array = j["tail"]
	for k in TAIL_COUNT:
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
	for b in globals.size():
		var moved := _frame * globals[b] * _rest[b].affine_inverse()
		var g := _skeleton_from_model * moved * _skeleton_from_model.affine_inverse() * _model_rest[b]
		var bone := _index[b]
		if bone < 0:
			continue
		var parent := _skeleton.get_bone_parent(bone)
		if parent >= 0:
			g = _skeleton.get_bone_global_pose(parent).affine_inverse() * g
		_skeleton.set_bone_pose_position(bone, g.origin)
		_skeleton.set_bone_pose_rotation(bone, g.basis.get_rotation_quaternion())
		_skeleton.set_bone_pose_scale(bone, g.basis.get_scale())
	# Where it can take hold of something: its claws, and its jaws.
	var to_world := _model.global_transform * _frame
	_grabbers = PackedVector3Array()
	var hands: Array = j["hands"]
	for i in 2:
		var end: Vector3 = j["ends"][i]
		_grabbers.append(to_world * (end + (hands[i] as Basis).y * HAND_LONG))
	var head: Transform3D = j["head_xform"]
	_grabbers.append(to_world * (head * Vector3(0.0, -0.03, 0.1)))


# --- Its voice ---

func _say(what: StringName) -> void:
	if _voice == null or not is_inside_tree():
		return
	_voice.stream = sound(what)
	_voice.pitch_scale = _rng.randf_range(0.9, 1.15)
	_voice.play()


## Its sounds, made once and shared: `cackle`, `chitter` or `shriek`.
static func sound(what: StringName) -> AudioStreamWAV:
	if _sounds.has(what):
		return _sounds[what]
	var made: AudioStreamWAV
	match what:
		&"cackle":
			made = _voice_sound(1.05, 23, _cackle_shape, 8.5)
		&"chitter":
			made = _clicks(0.45, 31)
		&"shriek":
			made = _voice_sound(1.0, 37, _shriek_shape)
	_sounds[what] = made
	return made


## The cackle: a wheezing, breathy "heh-heh-heh-hih" that climbs and breaks
## (pitch, loudness, how much of each syllable is voiced; `t` 0..1).
static func _cackle_shape(t: float) -> Vector3:
	var climb := 520.0 + 380.0 * smoothstep(0.0, 0.9, t)
	return Vector3(climb, 1.0, 0.45 + 0.2 * smoothstep(0.5, 1.0, t))


## The tantrum's shriek: one long, rough, wavering scream.
static func _shriek_shape(t: float) -> Vector3:
	var pitch := 980.0 + 420.0 * sin(PI * clampf(t / 0.9, 0.0, 1.0)) + 180.0 * sin(t * 37.0)
	return Vector3(pitch, 1.0, 1.0)


## A small, rasping voice: glottal pulses (a little off in time) through a
## throat's resonances, with breath, chopped into syllables `rate` a second
## (0: one long cry). `shape(t)` is (pitch, loudness, how much of each
## syllable is voice) at each moment.
static func _voice_sound(length: float, seed: int, shape: Callable, rate := 0.0) -> AudioStreamWAV:
	var mix := 22050
	var count := int(mix * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var samples := PackedFloat32Array()
	samples.resize(count)
	var bands: Array[_Band] = [_Band.new(1350.0, 5.0, mix), _Band.new(2400.0, 6.0, mix), _Band.new(3600.0, 6.0, mix), _Band.new(5200.0, 4.0, mix)]
	var gains := [1.0, 0.8, 0.55, 0.3]
	var breath := _Band.new(4200.0, 1.0, mix)
	var phase := 0.0
	var wander := 0.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / mix
		var s: Vector3 = shape.call(t / length)
		wander = clampf(wander + rng.randf_range(-1.0, 1.0) * 0.12, -1.0, 1.0)
		var pitch := s.x * (1.0 + 0.09 * wander)
		var gate := 1.0
		if rate > 0.0:
			var syl := fposmod(t * rate, 1.0)
			gate = smoothstep(0.0, 0.08, syl) * (1.0 - smoothstep(s.z * 0.8, s.z, syl))
			# (each syllable starts high and falls: a snigger)
			pitch *= 1.25 - 0.35 * syl
		phase += pitch / mix * (1.0 + rng.randf_range(-0.05, 0.05))
		var p := fposmod(phase, 1.0)
		var pulse := pow(1.0 - p, 5.0) * 2.0 - 0.35
		var throat := 0.0
		for k in bands.size():
			throat += bands[k].run(pulse) * gains[k]
		var air := breath.run(rng.randf_range(-1.0, 1.0)) * (0.6 + 0.4 * (1.0 - p))
		var fade := smoothstep(0.0, 0.03, t) * (1.0 - smoothstep(length - 0.12, length, t))
		var value := (throat * 1.6 + air * 1.1) * gate * s.y * fade
		value = tanh(value * 2.2)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	return _wav(samples, loudest, mix)


## Quick dry clicks of teeth, with tiny squeaks among them.
static func _clicks(length: float, seed: int) -> AudioStreamWAV:
	var mix := 22050
	var count := int(mix * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var samples := PackedFloat32Array()
	samples.resize(count)
	var at := 0
	while at < count:
		var long := rng.randi_range(40, 120)
		var loud := rng.randf_range(0.4, 1.0)
		var tone := _Band.new(rng.randf_range(2500.0, 4500.0), 9.0, mix)
		for k in long:
			if at + k >= count:
				break
			var env := exp(-float(k) / long * 6.0)
			samples[at + k] += tone.run(rng.randf_range(-1.0, 1.0)) * loud * env * 2.5
		if rng.randf() < 0.25:
			# (a squeak)
			var squeak := rng.randi_range(500, 900)
			var pitch := rng.randf_range(2200.0, 3200.0)
			for k in squeak:
				if at + k >= count:
					break
				var e := sin(PI * float(k) / squeak)
				samples[at + k] += sin(TAU * pitch * k / mix * (1.0 + 0.2 * float(k) / squeak)) * 0.25 * e
		at += rng.randi_range(450, 1300)
	var loudest := 0.001
	for v in samples:
		loudest = maxf(loudest, absf(v))
	return _wav(samples, loudest, mix)


static func _wav(samples: PackedFloat32Array, loudest: float, mix: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / maxf(loudest, 0.001), -1.0, 1.0) * 28000.0))
	var made := AudioStreamWAV.new()
	made.format = AudioStreamWAV.FORMAT_16_BITS
	made.mix_rate = mix
	made.data = data
	return made


## A resonant band-pass filter (a biquad).
class _Band:
	var _b0 := 0.0
	var _a1 := 0.0
	var _a2 := 0.0
	var _x1 := 0.0
	var _x2 := 0.0
	var _y1 := 0.0
	var _y2 := 0.0

	func _init(frequency: float, q: float, rate: int) -> void:
		var w := TAU * frequency / rate
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

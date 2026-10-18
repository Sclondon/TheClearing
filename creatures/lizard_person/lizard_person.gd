class_name LizardPerson
extends Node3D
## One of the lizard people: how it looks, moves and sounds, and nothing of what
## it thinks. Whatever drives it (a game's enemy script, the example) moves this
## node about and says what it is on and which way it faces; it poses itself
## from that.
##
## WHAT IT IS. A reptile the size of a man, lean and long in the limb, with a
## long tail: fine scales all over, mottled grey-olive, darker over the back in
## broken bands, the belly pale and plated; a row of keeled scutes down the
## spine and bigger plates over the shoulders; a lizard's head, its skull flat,
## a long jaw, heat pits along the lip, yellow eyes with slit pupils that blink
## sideways (a pale membrane drawn over them from the front); a fan of a dewlap
## folded under the throat; a forked tongue. Five long splayed fingers and toes,
## each with a pad at its tip and a claw. One skinned mesh and one material
## (models/lizard_person.glb, or `_lo` for phones, built in Blender by
## tools/build_lizard_person.py round the skeleton this script works out), so
## one draw and its shadow.
##
## WHAT IT IS ON. `surface` is the normal of what it is on (UP for the ground,
## a wall's normal on a wall, DOWN under a ceiling) and `heading` the way it
## faces along it (on a wall, DOWN is head down); its node's position is the
## point on the surface under its middle. It rolls over to a new surface by
## itself, quickly. Its feet are posed on the surface, so it walks on a wall
## exactly as on the floor: crawling, low and splayed like a gecko, its knees
## and elbows high and out, its spine and tail swinging from side to side.
##
## HOW IT MOVES. Move the node and set `heading`: it works out its own speed,
## and its feet keep to the surface as it goes (they are stepped from how far
## it has gone). On the ground, slow or still, it stands up on two legs,
## stooped, its arms hanging, its tail on the ground behind (unless `crouch`);
## going quicker it drops to all fours and scuttles, a trot of diagonal pairs.
## On a wall it is always on all fours. In the air (`airborne`) it is spread
## out flat, hands and feet thrown forward, jaws open, its tail streaming; it
## pitches with how it falls.
##
## WHAT IT DOES, each on a call, blending in and out by itself:
## - `hiss(seconds)`: the warning. It rears its forebody up off what it is on,
##   arms spread wide with the claws open, head up, mouth gaping, the dewlap
##   fanned out under its throat, its tail lashing, and hisses (`hissing()`).
## - `lunge()`: from where it is, it springs forward low (GATHER), hands and
##   jaws thrown out ahead (REACH), and gathers itself (RECOVER). The driver
##   moves it forward; `reaches(point, radius)` says whether its hands or jaws
##   are on a point while it reaches (or while it is airborne).
## - By itself: its tongue flicks out to taste the air (more often while
##   `tasting` is high), it blinks, it breathes, it looks about in quick jerks
##   (or at `aim`).
## `warmth` (0 cold to 1 warm) is how quick it is in itself: cold, it blinks and
## tastes slowly, lies pressed flat when still, and its skin darkens (as cold
## lizards' do).

signal hissed

enum Stage { NONE, GATHER, REACH, RECOVER }

const GATHER_TIME := 0.12
const REACH_TIME := 0.3
const RECOVER_TIME := 0.45
const BLINK_TIME := 0.24
const FLICK_TIME := 0.34

## The models (built by tools/build_lizard_person.py).
const MODEL := "res://creatures/lizard_person/models/lizard_person.glb"
const MODEL_LO := "res://creatures/lizard_person/models/lizard_person_lo.glb"

## Lengths of the limbs (metres as modelled): upper arm, forearm; thigh, shin.
const ARM := Vector2(0.33, 0.31)
const LEG := Vector2(0.47, 0.45)
## How high the wrist and ankle are over the sole of a planted hand or foot.
const ANKLE := 0.06
## Crawling: the middle of its hips and of its shoulders, and where each hand
## and foot rests (left hand, right hand, left foot, right foot; +X is its left,
## it faces +Z), all on the surface.
const CRAWL_PELVIS := Vector3(0.0, 0.36, -0.3)
const CRAWL_CHEST := Vector3(0.0, 0.4, 0.31)
const CRAWL_FEET: Array[Vector3] = [Vector3(0.44, 0.0, 0.62), Vector3(-0.44, 0.0, 0.62), Vector3(0.6, 0.0, -0.52), Vector3(-0.6, 0.0, -0.52)]
## Which way the fingers and toes point as they lie flat crawling (forward and out).
const CRAWL_DIGITS: Array[Vector3] = [Vector3(0.55, 0.0, 0.84), Vector3(-0.55, 0.0, 0.84), Vector3(0.85, 0.0, 0.3), Vector3(-0.85, 0.0, 0.3)]
## Standing: hips and shoulders (stooped), the feet, and where the hands hang.
const STAND_PELVIS := Vector3(0.0, 0.93, -0.06)
const STAND_CHEST := Vector3(0.0, 1.43, 0.27)
const STAND_FEET: Array[Vector3] = [Vector3(0.3, 0.8, 0.33), Vector3(-0.3, 0.8, 0.33), Vector3(0.15, 0.0, 0.03), Vector3(-0.15, 0.0, 0.03)]
const STAND_DIGITS: Array[Vector3] = [Vector3(0.0, -1.0, 0.1), Vector3(0.0, -1.0, 0.1), Vector3(0.25, 0.0, 0.97), Vector3(-0.25, 0.0, 0.97)]
## The ways of going: when each foot comes down in the cycle, how much of the
## cycle it is down, how far the body goes in a cycle (m), how high a foot lifts.
const TROT := {"offsets": [0.0, 0.5, 0.5, 0.0], "duty": 0.6, "cycle": 1.0, "lift": 0.11}
const SCUTTLE := {"offsets": [0.0, 0.5, 0.52, 0.02], "duty": 0.42, "cycle": 1.45, "lift": 0.14}
const WALK := {"offsets": [0.5, 0.0, 0.0, 0.5], "duty": 0.62, "cycle": 1.25, "lift": 0.12}
## Where the tongue, the lids (at the front corner of each eye) and the
## dewlap are fixed in the head (its own space: the back of the skull at the
## origin, the snout along +Z).
const TONGUE_AT := Vector3(0.0, -0.032, 0.14)
const LID_AT: Array[Vector3] = [Vector3(0.056, 0.025, 0.133), Vector3(-0.056, 0.025, 0.133)]
const DEWLAP_AT := Vector3(0.0, -0.075, 0.0)
## How much bigger the head is drawn than its own units (all the places in it
## above are in its own units).
const HEAD_SIZE := 1.2
## The jaw's hinge, in the head.
const JAW_AT := Vector3(0.0, -0.03, 0.0)
## How long each joint of the tail is.
const TAIL_STEPS: Array[float] = [0.3, 0.28, 0.26, 0.24, 0.21, 0.19]
## The way it looks as modelled.
const REST_GAZE := Vector3(0.0, -0.08, 1.0)

## Its bones. None is the child of another: each is posed straight in the
## skeleton's space, so the mesh bends between them however the body is put.
const BONES: Array[String] = ["hips", "belly", "chest", "neck", "head", "jaw", "dewlap", "tongue", "lid_l", "lid_r",
	"arm_l", "arm_r", "forearm_l", "forearm_r", "hand_l", "hand_r",
	"thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r",
	"tail_1", "tail_2", "tail_3", "tail_4", "tail_5", "tail_6"]
const HIPS := 0
const BELLY := 1
const CHEST := 2
const NECK := 3
const HEAD := 4
const JAW := 5
const DEWLAP := 6
const TONGUE := 7
const LID := 8
const ARM_U := 10
const ARM_L := 12
const HAND := 14
const LEG_U := 16
const LEG_L := 18
const FOOT := 20
const TAIL := 22

## How big it is drawn (1: as modelled, about 1.85 m standing).
@export var size := 1.0
## Its own small differences (how dark, how it moves): two with one seed are alike.
@export var seed_value := 0
## Use the low-poly model (as `low_poly_all` does for every one).
@export var low_poly := false
@export var sound := true
@export var volume_db := 2.0
@export var sound_range := 40.0

## Every one uses the low-poly model (phones).
static var low_poly_all := false

## The normal of what it is on, and the way it faces along it.
var surface := Vector3.UP
var heading := Vector3.BACK
## In the air: spread out, pitched with its fall.
var airborne := false
## On all fours even when still on the ground.
var crouch := false
## What it looks at (world). INF: about it, or where it goes.
var aim := Vector3.INF
## How warm it is, 0..1 (cold: slow, flat, dark).
var warmth := 1.0
## How keenly it tastes the air, 0..1: how often the tongue flicks.
var tasting := 0.3

var _model: Node3D
var _skeleton: Skeleton3D
var _body: MeshInstance3D
var _voice: AudioStreamPlayer3D
var _rest: Array[Transform3D] = []
var _index := PackedInt32Array()
var _model_rest: Array[Transform3D] = []
var _skeleton_from_model := Transform3D.IDENTITY
## Every bone is put through this (the pitch in the air, a lunge's stretch).
var _frame := Transform3D.IDENTITY
var _turned := Quaternion.IDENTITY

var _t := 0.0
var _was := Vector3.INF
var _heading_was := Vector3.BACK
var _speed := 0.0
var _vertical := 0.0
var _turn := 0.0
var _phase := 0.0
var _moving := 0.0
var _scuttle := 0.0
var _upright := 0.0
var _hiss_left := 0.0
var _hiss_w := 0.0
var _lunge := INF
var _lunge_w := 0.0
var _air_w := 0.0
var _blink := INF
var _blink_in := 2.0
var _flick := INF
var _flick_in := 1.0
var _gaze := REST_GAZE.normalized()
var _scan := REST_GAZE
var _scan_in := 0.0
var _rng := RandomNumberGenerator.new()
var _tone := 1.0
var _grabbers := PackedVector3Array()
## Where its head was at the last pose (its own space).
var _head_local := Vector3(0.0, 1.6, 0.4)
static var _hiss_sound: AudioStreamWAV


func _ready() -> void:
	_rng.seed = seed_value
	_tone = _rng.randf_range(0.9, 1.1)
	_phase = _rng.randf()
	_rest = _bone_globals(_joints(_rest_pose(), REST_GAZE))
	var low := low_poly or low_poly_all
	_model = (load(MODEL_LO if low else MODEL) as PackedScene).instantiate()
	_model.top_level = true
	add_child(_model)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	_body = _model.find_children("*", "MeshInstance3D", true, false)[0]
	_body.material_override = LizardPersonLook.material()
	_body.custom_aabb = AABB(Vector3(-1.3, -0.5, -2.3), Vector3(2.6, 2.6, 3.8))
	_body.set_instance_shader_parameter(&"tone", _tone)
	_index.resize(BONES.size())
	_model_rest.resize(BONES.size())
	for b in BONES.size():
		_index[b] = _skeleton.find_bone(BONES[b])
		_model_rest[b] = _skeleton.get_bone_global_rest(_index[b])
	_skeleton_from_model = _skeleton.global_transform.affine_inverse() * _model.global_transform
	if sound:
		_voice = AudioStreamPlayer3D.new()
		_voice.stream = hiss_sound()
		_voice.volume_db = volume_db
		_voice.unit_size = 7.0
		_voice.max_distance = sound_range
		add_child(_voice)
	settle()


## Puts it still as it is told it is, with nothing going on.
func settle() -> void:
	_was = global_position
	_heading_was = heading
	_speed = 0.0
	_vertical = 0.0
	_turn = 0.0
	_moving = 0.0
	_scuttle = 0.0
	_upright = 1.0 if _wants_upright() else 0.0
	_hiss_left = 0.0
	_hiss_w = 0.0
	_lunge = INF
	_lunge_w = 0.0
	_air_w = 1.0 if airborne else 0.0
	_turned = _surface_basis().get_rotation_quaternion()
	_pose(0.0)


## The warning: reared, gaping, the dewlap out, hissing, for `seconds`.
func hiss(seconds := 0.8) -> void:
	if _hiss_left <= 0.0 and _voice and is_inside_tree():
		_voice.pitch_scale = _rng.randf_range(0.9, 1.08)
		_voice.play()
	_hiss_left = maxf(_hiss_left, seconds)
	hissed.emit()


func hissing() -> bool:
	return _hiss_left > 0.0


## Springs forward low with hands and jaws out (the driver moves it).
func lunge() -> void:
	_lunge = 0.0
	_hiss_left = 0.0


func lunge_stage() -> Stage:
	if _lunge < GATHER_TIME:
		return Stage.GATHER
	if _lunge < GATHER_TIME + REACH_TIME:
		return Stage.REACH
	if _lunge < GATHER_TIME + REACH_TIME + RECOVER_TIME:
		return Stage.RECOVER
	return Stage.NONE


## How far through its stage the lunge is, 0..1.
func lunge_progress() -> float:
	match lunge_stage():
		Stage.GATHER:
			return _lunge / GATHER_TIME
		Stage.REACH:
			return (_lunge - GATHER_TIME) / REACH_TIME
		Stage.RECOVER:
			return (_lunge - GATHER_TIME - REACH_TIME) / RECOVER_TIME
	return 0.0


func busy() -> bool:
	return hissing() or lunge_stage() != Stage.NONE


## Whether its hands or jaws are within `radius` of `point` (world), while it
## reaches in a lunge or is in the air.
func reaches(point: Vector3, radius: float) -> bool:
	if lunge_stage() != Stage.REACH and not airborne:
		return false
	for p in _grabbers:
		if p.distance_to(point) < radius:
			return true
	return false


## Where its hands and jaws are (world), from the last pose.
func grabbers() -> PackedVector3Array:
	return _grabbers


## Where its head is (world), from the last pose.
func head_point() -> Vector3:
	return _grabbers[2] if _grabbers.size() > 2 else global_position + Vector3.UP


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_t += delta
	var basis_now := Basis(_turned)
	var at := global_position
	if not _was.is_finite():
		_was = at
	var moved := at - _was
	_was = at
	var normal := surface.normalized()
	var flat_move := moved - normal * moved.dot(normal)
	var forward := basis_now.z
	var along := flat_move.dot(forward)
	_speed = lerpf(_speed, flat_move.length() / delta, 1.0 - exp(-10.0 * delta))
	_vertical = lerpf(_vertical, moved.y / delta, 1.0 - exp(-10.0 * delta))
	_turn = lerpf(_turn, _heading_was.signed_angle_to(heading, normal) / delta, 1.0 - exp(-6.0 * delta))
	_heading_was = heading
	# (turning on the spot, it shuffles its feet round)
	var shuffle := absf(_turn) * 0.25 * delta if _speed < 0.3 else 0.0
	var cycle := lerpf(lerpf(TROT["cycle"], SCUTTLE["cycle"], _scuttle), WALK["cycle"], _upright)
	if not airborne:
		_phase = fposmod(_phase + (along + shuffle) / (cycle * size), 1.0)
	var unit_speed := _speed / size
	_moving = move_toward(_moving, 1.0 if unit_speed > 0.08 or shuffle > 0.0 else 0.0, delta * 5.0)
	_scuttle = move_toward(_scuttle, smoothstep(1.8, 3.6, unit_speed), delta * 3.0)
	_upright = move_toward(_upright, 1.0 if _wants_upright() else 0.0, delta * (1.6 if _wants_upright() else 3.5))
	_hiss_left -= delta
	_hiss_w = move_toward(_hiss_w, 1.0 if _hiss_left > 0.0 else 0.0, delta * (7.0 if _hiss_left > 0.0 else 3.0))
	if _lunge != INF:
		_lunge += delta
		if lunge_stage() == Stage.NONE:
			_lunge = INF
	_lunge_w = move_toward(_lunge_w, 1.0 if _lunge != INF else 0.0, delta * 9.0)
	_air_w = move_toward(_air_w, 1.0 if airborne else 0.0, delta * 7.0)
	# Blinks and tastes, slower when cold.
	var quick := lerpf(0.45, 1.0, warmth)
	_blink += delta * quick
	_blink_in -= delta * quick
	if _blink_in <= 0.0:
		_blink = 0.0
		_blink_in = _rng.randf_range(2.5, 7.0)
	_flick += delta * lerpf(0.6, 1.0, warmth)
	_flick_in -= delta * quick
	if _flick_in <= 0.0:
		_flick = 0.0
		# (and now and then twice running)
		_flick_in = _rng.randf_range(0.4, 0.6) if _rng.randf() < 0.3 else lerpf(_rng.randf_range(2.5, 5.0), _rng.randf_range(0.7, 1.4), tasting)
	# Rolls over to what it is on.
	var want := _surface_basis().get_rotation_quaternion()
	_turned = _turned.slerp(want, 1.0 - exp(-11.0 * delta)) if _turned.dot(want) < 0.99999 else want
	_pose(delta)


func _wants_upright() -> bool:
	return surface.normalized().y > 0.9 and not airborne and not crouch and _speed / maxf(size, 0.01) < 1.4 \
		and _hiss_left <= 0.0 and _lunge == INF


## The way it is turned on its surface: Y the surface's normal, Z its heading along it.
func _surface_basis() -> Basis:
	var y := surface.normalized() if surface.length() > 0.01 else Vector3.UP
	var z := heading - y * heading.dot(y)
	if z.length() < 0.01:
		z = Vector3.BACK - y * y.z
		if z.length() < 0.01:
			z = Vector3.UP - y * y.y
	z = z.normalized()
	return Basis(y.cross(z).normalized(), y, z)


# --- Posing ---

## One whole pose (metres as modelled, in its own space on its surface): hips
## and shoulders (the middle of each); each hand and foot, which way each knee
## and elbow bends, and how flat each lies; the swing of the spine; the head;
## the jaw, the dewlap; the tail.
class Pose:
	var pelvis := CRAWL_PELVIS
	var chest := CRAWL_CHEST
	var feet: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var poles: Array[Vector3] = [Vector3(1.0, 0.7, -0.4), Vector3(-1.0, 0.7, -0.4), Vector3(1.0, 0.32, 0.25), Vector3(-1.0, 0.32, 0.25)]
	var flat: Array[float] = [1.0, 1.0, 1.0, 1.0]
	var digits: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var sway := 0.0
	var head_up := 0.0
	var jaw := 0.0
	var dewlap := 0.0
	var tail_up := 0.0
	var tail_wave := 0.0
	var tail_phase := 0.0

	func _init() -> void:
		for i in 4:
			digits[i] = CRAWL_DIGITS[i]

	func blend(other: Pose, w: float) -> Pose:
		if w <= 0.0:
			return self
		var p := Pose.new()
		p.pelvis = pelvis.lerp(other.pelvis, w)
		p.chest = chest.lerp(other.chest, w)
		for i in 4:
			p.feet[i] = feet[i].lerp(other.feet[i], w)
			p.poles[i] = poles[i].lerp(other.poles[i], w)
			p.flat[i] = lerpf(flat[i], other.flat[i], w)
			p.digits[i] = digits[i].lerp(other.digits[i], w)
		p.sway = lerpf(sway, other.sway, w)
		p.head_up = lerpf(head_up, other.head_up, w)
		p.jaw = lerpf(jaw, other.jaw, w)
		p.dewlap = lerpf(dewlap, other.dewlap, w)
		p.tail_up = lerpf(tail_up, other.tail_up, w)
		p.tail_wave = lerpf(tail_wave, other.tail_wave, w)
		p.tail_phase = lerpf(tail_phase, other.tail_phase, w)
		return p


## Stepping a foot through a gait: how far forward of its rest (dz) and how high (dy).
static func _step(phase: float, offset: float, gait_duty: float, reach: float, lift: float) -> Vector2:
	var s := fposmod(phase - offset, 1.0)
	if s < gait_duty:
		return Vector2(reach * (0.5 - s / gait_duty), 0.0)
	var k := (s - gait_duty) / (1.0 - gait_duty)
	var e := k * k * (3.0 - 2.0 * k)
	return Vector2(reach * (-0.5 + e), lift * sin(PI * k))


## On all fours: still, or trotting, or scuttling flat out.
func _crawling() -> Pose:
	var p := Pose.new()
	var g := _scuttle
	var gait_duty := lerpf(TROT["duty"], SCUTTLE["duty"], g)
	var cycle := lerpf(TROT["cycle"], SCUTTLE["cycle"], g)
	var lift := lerpf(TROT["lift"], SCUTTLE["lift"], g)
	var reach := cycle * gait_duty
	for i in 4:
		var off := lerpf(TROT["offsets"][i], SCUTTLE["offsets"][i], g)
		var step := _step(_phase, off, gait_duty, reach, lift)
		var foot := CRAWL_FEET[i]
		foot.z += step.x * _moving
		foot.y += step.y * _moving
		p.feet[i] = foot
		p.flat[i] = 1.0 - smoothstep(0.02, 0.09, step.y * _moving)
	# The spine swings from side to side with the strides (the shoulders turned
	# to the hand that reaches), and the body bobs a little.
	p.sway = cos(TAU * _phase) * lerpf(0.2, 0.3, g) * _moving
	var bob := -cos(TAU * 2.0 * _phase) * 0.012 * _moving
	var cold := (1.0 - warmth) * (1.0 - _moving)
	p.pelvis = CRAWL_PELVIS + Vector3(0.0, bob - 0.04 * g - 0.13 * cold, 0.0)
	p.chest = CRAWL_CHEST + Vector3(0.0, bob * 0.7 - 0.03 * g - 0.12 * cold, 0.02 * g)
	var breath := sin(_t * lerpf(1.1, 2.2, warmth))
	p.chest.y += breath * 0.006
	p.head_up = 0.05 - 0.12 * g - 0.18 * cold
	p.tail_wave = lerpf(0.06, 0.22, _moving) * (1.0 - 0.4 * cold)
	p.tail_phase = _phase if _moving > 0.1 else _t * 0.12
	p.jaw = 0.0
	return p


## Up on its hind legs, stooped, the arms hanging and swinging as it walks.
func _standing() -> Pose:
	var p := Pose.new()
	var reach := WALK["cycle"] * WALK["duty"]
	for i in 4:
		p.digits[i] = STAND_DIGITS[i]
		var foot := STAND_FEET[i]
		if i >= 2:
			var step := _step(_phase, WALK["offsets"][i], WALK["duty"], reach, WALK["lift"])
			foot.z += step.x * _moving
			foot.y += step.y * _moving
			p.flat[i] = 1.0 - smoothstep(0.02, 0.09, step.y * _moving)
		else:
			# (the hands swing with the opposite foot, the claws loose)
			var swing := sin(TAU * (_phase - WALK["offsets"][i])) * 0.16 * _moving
			foot += Vector3(0.0, absf(swing) * 0.25, swing)
			foot.x += sin(_t * 0.9 + i * 2.0) * 0.01
			p.flat[i] = 0.0
		p.feet[i] = foot
	p.poles = [Vector3(0.5, 0.0, -1.0), Vector3(-0.5, 0.0, -1.0), Vector3(0.12, 0.0, 1.0), Vector3(-0.12, 0.0, 1.0)]
	var bob := -cos(TAU * 2.0 * _phase) * 0.02 * _moving
	var breath := sin(_t * lerpf(1.0, 1.9, warmth))
	p.pelvis = STAND_PELVIS + Vector3(sin(TAU * _phase) * 0.025 * _moving, bob, 0.0)
	p.chest = STAND_CHEST + Vector3(sin(TAU * _phase) * 0.012 * _moving, bob + breath * 0.008, 0.05 * _moving)
	p.sway = sin(TAU * _phase) * 0.12 * _moving
	p.head_up = -0.15
	p.tail_wave = 0.08
	p.tail_phase = _phase if _moving > 0.1 else _t * 0.1
	return p


## The threat: reared off what it is on, arms spread, gaping, dewlap out, tail lashing.
func _threat() -> Pose:
	var p := Pose.new()
	var shake := sin(_t * 31.0) * 0.008
	p.pelvis = Vector3(0.0, 0.34, -0.34)
	p.chest = Vector3(shake, 0.82, 0.12)
	p.feet = [Vector3(0.6, 0.62, 0.42), Vector3(-0.6, 0.62, 0.42), Vector3(0.52, 0.0, -0.42), Vector3(-0.52, 0.0, -0.42)]
	p.flat = [0.0, 0.0, 1.0, 1.0]
	p.digits = [Vector3(0.6, 0.2, 0.75), Vector3(-0.6, 0.2, 0.75), CRAWL_DIGITS[2], CRAWL_DIGITS[3]]
	p.poles = [Vector3(0.6, -0.6, -1.0), Vector3(-0.6, -0.6, -1.0), Vector3(1.0, 0.5, 0.4), Vector3(-1.0, 0.5, 0.4)]
	p.head_up = 0.3
	p.jaw = 1.0
	p.dewlap = 1.0
	p.tail_up = 0.25
	p.tail_wave = 0.45
	p.tail_phase = _t * 1.6
	return p


## The lunge: gathered, thrown out low with hands and jaws ahead, recovering.
func _lunging() -> Pose:
	var thrown := Pose.new()
	thrown.pelvis = Vector3(0.0, 0.34, -0.22)
	thrown.chest = Vector3(0.0, 0.5, 0.42)
	thrown.feet = [Vector3(0.28, 0.42, 1.02), Vector3(-0.28, 0.42, 1.02), Vector3(0.4, 0.0, -0.78), Vector3(-0.4, 0.0, -0.78)]
	thrown.flat = [0.0, 0.0, 0.7, 0.7]
	thrown.digits = [Vector3(0.3, 0.1, 0.95), Vector3(-0.3, 0.1, 0.95), Vector3(0.5, 0.0, -0.86), Vector3(-0.5, 0.0, -0.86)]
	thrown.poles = [Vector3(1.0, -0.2, -0.3), Vector3(-1.0, -0.2, -0.3), Vector3(1.0, 0.8, 0.2), Vector3(-1.0, 0.8, 0.2)]
	thrown.head_up = 0.05
	thrown.jaw = 1.0
	thrown.dewlap = 0.6
	thrown.tail_up = 0.1
	thrown.tail_wave = 0.1
	var gathered := _crawling()
	gathered.pelvis += Vector3(0.0, -0.06, -0.06)
	gathered.chest += Vector3(0.0, -0.1, -0.1)
	gathered.jaw = 0.5
	gathered.dewlap = 0.8
	gathered.head_up = 0.15
	var k := lunge_progress()
	match lunge_stage():
		Stage.GATHER:
			return _crawling().blend(gathered, smoothstep(0.0, 1.0, k))
		Stage.REACH:
			return gathered.blend(thrown, smoothstep(0.0, 0.45, k))
		Stage.RECOVER:
			return thrown.blend(_crawling(), smoothstep(0.0, 1.0, k))
	return _crawling()


## In the air: flat, spread out, hands and feet thrown forward.
func _flying() -> Pose:
	var p := Pose.new()
	p.pelvis = Vector3(0.0, 0.36, -0.32)
	p.chest = Vector3(0.0, 0.44, 0.3)
	p.feet = [Vector3(0.5, 0.18, 0.78), Vector3(-0.5, 0.18, 0.78), Vector3(0.62, 0.05, -0.36), Vector3(-0.62, 0.05, -0.36)]
	p.flat = [0.6, 0.6, 0.6, 0.6]
	p.digits = [Vector3(0.45, 0.2, 0.87), Vector3(-0.45, 0.2, 0.87), Vector3(0.8, 0.1, 0.5), Vector3(-0.8, 0.1, 0.5)]
	p.head_up = 0.1
	p.jaw = 0.9
	p.dewlap = 0.5
	p.tail_up = 0.15
	p.tail_wave = 0.12
	p.tail_phase = _t * 1.2
	return p


func _pose(delta: float) -> void:
	var p := _crawling()
	p = p.blend(_standing(), smoothstep(0.0, 1.0, _upright))
	if _hiss_w > 0.0:
		# (still, it rears; running, it only gapes and fans its dewlap as it comes)
		var w := smoothstep(0.0, 1.0, _hiss_w)
		p = p.blend(_threat(), w * (1.0 - _scuttle) * (1.0 - _moving * 0.6))
		p.jaw = maxf(p.jaw, w)
		p.dewlap = maxf(p.dewlap, w)
		p.head_up += 0.15 * w
	if _lunge_w > 0.0:
		p = p.blend(_lunging(), _lunge_w)
	if _air_w > 0.0:
		p = p.blend(_flying(), smoothstep(0.0, 1.0, _air_w))
	# In the air it pitches with its fall (nose down falling, up rising).
	var pitch := 0.0
	if _air_w > 0.0:
		pitch = clampf(-atan2(_vertical, maxf(_speed, 0.5)) * 0.8, -0.5, 0.9) * _air_w
	_frame = Transform3D(Basis(Vector3.RIGHT, pitch), Vector3(0.0, 0.25 * absf(pitch), 0.0))
	_look(delta)
	_model.global_transform = Transform3D(Basis(_turned).scaled(Vector3.ONE * size), global_position)
	_apply(p)


## Where its eyes are on: what it was given (as far round as it can turn its
## head), or (still) about it, in quick jerks as a lizard looks.
func _look(delta: float) -> void:
	var want := REST_GAZE
	if aim.is_finite():
		var local := (_model.global_transform.affine_inverse() * aim)
		var from := _head_local
		want = (local - from).normalized()
		if want.z < 0.25:
			want.z = 0.25
			want = want.normalized()
	else:
		_scan_in -= delta * lerpf(0.4, 1.0, warmth)
		if _scan_in <= 0.0:
			_scan_in = _rng.randf_range(0.6, 2.8)
			_scan = Vector3(_rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.3, 0.2), 1.0) if _moving < 0.5 else REST_GAZE
		want = _scan
	want = want.normalized()
	_gaze = _gaze.slerp(want, 1.0 - exp(-16.0 * delta)).normalized() if delta > 0.0 else want


# --- The skeleton ---

## As modelled: lying on all fours with its limbs half way between how it
## crawls (out to the sides) and how it stands (down along the body), so that
## neither bends the mesh too far; its tongue out, its eyes covered by their
## membranes and its dewlap fanned out (the bones shrink these away in play).
func _rest_pose() -> Pose:
	var p := Pose.new()
	p.feet = [Vector3(0.52, 0.0, 0.1), Vector3(-0.52, 0.0, 0.1), Vector3(0.6, 0.0, -0.84), Vector3(-0.6, 0.0, -0.84)]
	p.poles = [Vector3(1.0, 0.8, -0.2), Vector3(-1.0, 0.8, -0.2), Vector3(1.0, 0.5, 0.35), Vector3(-1.0, 0.5, 0.35)]
	p.dewlap = 1.0
	return p


## Where everything is, for a pose and a way of looking (its own space).
func _joints(p: Pose, gaze_dir: Vector3, tongue_out := 1.0, lids := 1.0, flicker := 0.0) -> Dictionary:
	var j := {}
	var spine := p.chest - p.pelvis
	var torso := Basis.looking_at(-spine.normalized(), Vector3.UP)
	var up := torso.y
	var chest_g := Basis(up, p.sway) * torso
	var hips_g := Basis(up, -p.sway * 0.8) * torso
	j["torso"] = torso
	j["chest_g"] = chest_g
	j["hips_g"] = hips_g
	j["pelvis"] = p.pelvis
	j["chest"] = p.chest
	j["mid"] = p.pelvis.lerp(p.chest, 0.5) + up * 0.02
	j["tail_root"] = p.pelvis - hips_g.z * 0.16 + hips_g.y * 0.01
	var neck_root := p.chest + chest_g.z * 0.16 + chest_g.y * 0.06
	j["neck_root"] = neck_root
	var neck_dir := (Vector3.BACK * 0.85 + Vector3.UP * (0.45 + p.head_up * 0.6)).normalized()
	var neck_end := neck_root + neck_dir * 0.19
	j["neck_end"] = neck_end
	# Limbs: each bent at the elbow or knee to reach its hand or foot, and the hand
	# or foot laid flat on the surface, or along the limb as it lifts.
	var roots := PackedVector3Array()
	var mids := PackedVector3Array()
	var ends := PackedVector3Array()
	var digits: Array[Basis] = []
	for i in 4:
		var front := i < 2
		var sign := 1.0 if i % 2 == 0 else -1.0
		var girdle := chest_g if front else hips_g
		var root := (p.chest + girdle.x * sign * 0.2 + girdle.y * 0.02) if front else (p.pelvis + girdle.x * sign * 0.15 - girdle.y * 0.03)
		var end := p.feet[i] + Vector3.UP * ANKLE * p.flat[i]
		var lengths := ARM if front else LEG
		var mid := _bend(root, end, lengths.x, lengths.y, p.poles[i])
		roots.append(root)
		mids.append(mid)
		var reach_end := mid + (end - mid).normalized() * lengths.y
		ends.append(reach_end)
		var limb := (reach_end - mid).normalized()
		var lying := p.digits[i].normalized()
		var w := clampf(p.flat[i], 0.0, 1.0)
		var y := limb.lerp(lying, w)
		y = y.normalized() if y.length() > 0.01 else lying
		var z_hint := (Vector3.UP * w + girdle.x * sign * (1.0 - w) + Vector3.UP * 0.001)
		var x := y.cross(z_hint)
		if x.length() < 0.01:
			x = girdle.x * sign
		x = x.normalized()
		digits.append(Basis(x, y, x.cross(y).normalized()))
	j["roots"] = roots
	j["mids"] = mids
	j["ends"] = ends
	j["digits"] = digits
	# The head, turned to look along `gaze_dir`, tipped by `head_up`; the jaw,
	# tongue, lids, dewlap in it.
	var gaze := (Basis(Vector3.RIGHT, -p.head_up) * gaze_dir.normalized()).normalized()
	# (drawn a size bigger than its own units, so the head is heavy on the neck)
	var head_basis := Basis.looking_at(-gaze, Vector3.UP).scaled_local(Vector3.ONE * HEAD_SIZE)
	var head := Transform3D(head_basis, neck_end)
	j["head_xform"] = head
	j["jaw_xform"] = Transform3D(head_basis * Basis(Vector3.RIGHT, p.jaw * 0.7), head * JAW_AT)
	var fan := p.dewlap
	j["dewlap_xform"] = Transform3D(head_basis * Basis(Vector3.RIGHT, p.jaw * 0.4 - 0.15 * fan) * Basis.from_scale(Vector3(1.0, lerpf(0.14, 1.0, fan), lerpf(0.7, 1.0, fan))), head * DEWLAP_AT)
	j["tongue_xform"] = Transform3D(head_basis * Basis(Vector3.RIGHT, flicker + p.jaw * 0.35) * Basis.from_scale(Vector3(1.0, 1.0, maxf(tongue_out, 0.04))), head * TONGUE_AT)
	var lid_xforms: Array[Transform3D] = []
	for i in 2:
		lid_xforms.append(Transform3D(head_basis * Basis.from_scale(Vector3.ONE * maxf(lids, 0.03)), head * LID_AT[i]))
	j["lid_xforms"] = lid_xforms
	# The tail: back from the hips and down onto the surface, then along it,
	# swinging in a wave that runs down it.
	var tail := PackedVector3Array()
	var at: Vector3 = j["tail_root"]
	tail.append(at)
	var back := -hips_g.z
	back.y = minf(back.y, 0.0)
	var dir := (back.normalized() + Vector3.DOWN * 0.6).normalized()
	var swing := clampf(-_turn * 0.06, -0.4, 0.4)
	for k in TAIL_STEPS.size():
		var flat_back := Vector3(dir.x, 0.0, dir.z).normalized() if Vector2(dir.x, dir.z).length() > 0.01 else Vector3.FORWARD
		dir = dir.lerp(flat_back + Vector3.UP * p.tail_up + Vector3.DOWN * 0.3 * (1.0 - p.tail_up * 2.0), 0.4).normalized()
		var wave := sin(TAU * p.tail_phase - float(k) * 0.95) * p.tail_wave * (0.35 + 0.65 * float(k) / TAIL_STEPS.size())
		var across := Vector3.UP.cross(dir).normalized()
		var step_dir := (dir + across * (wave + swing * float(k) / TAIL_STEPS.size())).normalized()
		at += step_dir * TAIL_STEPS[k]
		# (it lies on the surface, never through it)
		at.y = maxf(at.y, 0.085 - 0.012 * k + p.tail_up * 0.4 * k)
		tail.append(at)
	j["tail"] = tail
	return j


## Each bone's transform (in its own space, as `_rest` is) for these joints.
func _bone_globals(j: Dictionary) -> Array[Transform3D]:
	var torso: Basis = j["torso"]
	var side := torso.x
	var out: Array[Transform3D] = []
	out.resize(BONES.size())
	out[HIPS] = Transform3D(j["hips_g"], j["pelvis"])
	out[BELLY] = _span(j["pelvis"], j["mid"], side)
	out[CHEST] = Transform3D(j["chest_g"], j["chest"])
	out[NECK] = _span(j["neck_root"], j["neck_end"], side)
	out[HEAD] = j["head_xform"]
	out[JAW] = j["jaw_xform"]
	out[DEWLAP] = j["dewlap_xform"]
	out[TONGUE] = j["tongue_xform"]
	out[LID] = j["lid_xforms"][0]
	out[LID + 1] = j["lid_xforms"][1]
	for i in 4:
		var front := i < 2
		out[(ARM_U if front else LEG_U) + i % 2] = _span(j["roots"][i], j["mids"][i], side)
		out[(ARM_L if front else LEG_L) + i % 2] = _span(j["mids"][i], j["ends"][i], side)
		out[(HAND if front else FOOT) + i % 2] = Transform3D(j["digits"][i], j["ends"][i])
	var tail: PackedVector3Array = j["tail"]
	for k in TAIL_STEPS.size():
		out[TAIL + k] = _span(tail[k], tail[k + 1], side)
	return out


## A bone from `a` to `b`: Y along it, X as near `side` as can be.
static func _span(a: Vector3, b: Vector3, side: Vector3) -> Transform3D:
	var y := b - a
	y = y.normalized() if y.length() > 0.0001 else Vector3.UP
	var z := side.cross(y)
	if z.length() < 0.05:
		z = Vector3.UP.cross(y) if absf(y.y) < 0.9 else Vector3.FORWARD
	z = z.normalized()
	return Transform3D(Basis(y.cross(z).normalized(), y, z), a)


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
	var tongue := 0.0
	var flicker := 0.0
	if _flick < FLICK_TIME:
		var k := _flick / FLICK_TIME
		tongue = pow(sin(PI * k), 0.6)
		flicker = sin(k * TAU * 3.0) * 0.3
	# (gaping, the tongue lies in the mouth)
	tongue = maxf(tongue, 0.25 * p.jaw)
	var lids := 0.0
	if _blink < BLINK_TIME:
		lids = sin(PI * _blink / BLINK_TIME)
	var j := _joints(p, _gaze, tongue, lids, flicker)
	var globals := _bone_globals(j)
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
	_body.set_instance_shader_parameter(&"cold", 1.0 - warmth)
	# Where it can take hold: its hands' fingertips and its jaws.
	var to_world := _model.global_transform * _frame
	_grabbers = PackedVector3Array()
	for i in 2:
		var hand: Basis = j["digits"][i]
		_grabbers.append(to_world * ((j["ends"][i] as Vector3) + hand.y * 0.14))
	var head: Transform3D = j["head_xform"]
	_grabbers.append(to_world * (head * Vector3(0.0, -0.03, 0.3)))
	_head_local = head.origin


# --- Sound ---

## The hiss, made once and shared: breath forced out through a gaping throat,
## a broad rush of air with a wet rattle in it, pulsing twice, and a low
## throaty growl under it. 1.1 s.
static func hiss_sound() -> AudioStreamWAV:
	if _hiss_sound:
		return _hiss_sound
	var rate := 22050
	var length := 1.1
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	var air := Band.new(4200.0, 0.8, rate)
	var throat := Band.new(1900.0, 1.6, rate)
	var growl := Band.new(140.0, 3.0, rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var loudest := 0.0
	var rattle := 0.0
	for i in count:
		var t := float(i) / rate
		var swell := smoothstep(0.0, 0.05, t) * (1.0 - smoothstep(0.75, length, t))
		# (two pushes of breath, the second the longer)
		var pulse := 0.75 + 0.25 * sin(PI * clampf(t / 0.3, 0.0, 1.0)) - 0.25 * exp(-pow((t - 0.33) / 0.05, 2.0))
		if rng.randf() < 0.004:
			rattle = 1.0
		rattle *= 0.993
		var noise := rng.randf_range(-1.0, 1.0)
		var value := air.run(noise) * 1.2 + throat.run(noise) * (0.5 + rattle * 0.8)
		value += growl.run(noise) * 2.5 * smoothstep(0.05, 0.2, t)
		value *= swell * pulse
		samples[i] = tanh(value * 1.6)
		loudest = maxf(loudest, absf(samples[i]))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(clampf(samples[i] / maxf(loudest, 0.001), -1.0, 1.0) * 26000.0))
	_hiss_sound = AudioStreamWAV.new()
	_hiss_sound.format = AudioStreamWAV.FORMAT_16_BITS
	_hiss_sound.mix_rate = rate
	_hiss_sound.data = data
	return _hiss_sound


## A resonant band-pass filter (a biquad), for the hiss.
class Band:
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

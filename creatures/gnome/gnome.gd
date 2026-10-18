class_name Gnome
extends Node3D
## A gnome out of an old folk tale: how it looks and how it moves, and nothing
## of what it thinks. Whatever drives it (a game's enemy script, a cutscene, the
## example) moves this node about and calls on it; it poses itself from that.
##
## WHAT IT IS. Knee-high, old and stooped: a big head with a heavy bulbous nose,
## deep-set little eyes like wet beads under bushy brows, long drooping ears and
## leathery, deeply wrinkled skin; a long matted grey beard to its belly and a
## drooping moustache; a tall faded pointed hat, its tip flopping; a worn coat
## belted over a paunch, its skirts to the knee; short bowed legs in pointed
## boots; big knobbly hands. Eerie rather than sweet: no bright colours, and it
## holds itself too still. It is one skinned mesh (models/gnome.glb, built in
## Blender by tools/build_gnome.py) on a skeleton posed here, so each is one draw.
##
## HOW IT MOVES. Move the node and turn it (it faces +Z); it works out its own
## speed from how it is moved, and walks, stooped, hands clasped; creeps on tiptoe
## with its knees high and its hands up in front (`creeping`); or scurries
## headlong, leaning, arms pumping, when fast. Its hat tip and beard swing after
## it. `look_at_point` (world, INF for none) is what it turns its head to; left
## alone it looks slowly about, now and then tipping its head on one side.
##
## STILL. `frozen` holds it exactly as it is, mid-stride or mid-reach, as stiff
## as a garden ornament, and costs nothing (it is not posed at all) until it is
## let go. `still` is a pose to stand in when it is not going anywhere: hands
## clasped, a finger to its lips, peering under its hand, or pointing.
##
## WHAT IT DOES, each on a call, blending in and out by itself:
## - `snatch()`: a quick grab up and forward with both hands (`SNATCH_TIME`),
##   `snatch_reached()` true at the end of the reach;
## - `carrying`: hugging something to its chest (put it at `carry_point()`);
## - `hauling`: leaning back on a rope, hands forward at `rope_point()`;
## - `giggle()`: hand over its mouth, shoulders shaking, a breathy titter;
## - `whisper()`: a dry hiss of a whisper, head tipped;
## - `squeal()`: arms thrown up, a thin squeal (caught out);
## - `tumbling`: knocked over, limbs flailing (whoever drives it turns it).
## `pattering` plays the patter of its feet while it moves (a warning).
##
## Set `size` (metres to the crown of its head, under the hat) and `seed_value`
## before it goes into the tree; `voice` off for no sound (always pass
## `--audio-driver Dummy` to test runs). Hide it or disable its processing when
## it is far from the camera: it poses itself every frame it is not frozen.

enum Still { CLASP, HUSH, PEER, POINT }

const SNATCH_TIME := 0.42
const GIGGLE_TIME := 1.0
const SQUEAL_TIME := 0.8
const WHISPER_TIME := 0.9

## How fast (its own heights a second) it goes before it scurries.
const SCURRY_FROM := 4.0

## Limb lengths (its own units: one is its height to the crown): upper arm,
## forearm; thigh, shin.
const ARM := Vector2(0.19, 0.17)
const LEG := Vector2(0.17, 0.16)
## Where the ankle is from the ball of the foot.
const ANKLE := Vector3(0.0, 0.05, -0.065)
## How far the hand reaches past the wrist.
const HAND_LONG := 0.09

## Its stances (units): pelvis and chest, each hand (wrist) and foot (ball):
## left hand, right hand, left foot, right foot; and which way each elbow and
## knee bends. +X is its left, +Z ahead.
const STAND := {"pelvis": Vector3(0.0, 0.32, -0.03), "chest": Vector3(0.0, 0.57, 0.035),
	"feet": [Vector3(0.055, 0.4, 0.15), Vector3(-0.055, 0.4, 0.15), Vector3(0.075, 0.0, 0.03), Vector3(-0.075, 0.0, 0.03)],
	"poles": [Vector3(1.0, -0.3, -0.8), Vector3(-1.0, -0.3, -0.8), Vector3(0.3, 0.0, 1.0), Vector3(-0.3, 0.0, 1.0)]}
const CREEP := {"pelvis": Vector3(0.0, 0.28, -0.03), "chest": Vector3(0.0, 0.51, 0.055),
	"feet": [Vector3(0.1, 0.56, 0.19), Vector3(-0.1, 0.56, 0.19), Vector3(0.08, 0.0, 0.02), Vector3(-0.08, 0.0, 0.02)],
	"poles": [Vector3(1.0, -1.0, -0.2), Vector3(-1.0, -1.0, -0.2), Vector3(0.4, 0.0, 1.0), Vector3(-0.4, 0.0, 1.0)]}
const RUN := {"pelvis": Vector3(0.0, 0.3, 0.0), "chest": Vector3(0.0, 0.53, 0.13),
	"feet": [Vector3(0.12, 0.38, 0.1), Vector3(-0.12, 0.38, 0.1), Vector3(0.07, 0.0, 0.03), Vector3(-0.07, 0.0, 0.03)],
	"poles": [Vector3(1.0, -0.6, -0.8), Vector3(-1.0, -0.6, -0.8), Vector3(0.2, 0.0, 1.0), Vector3(-0.2, 0.0, 1.0)]}
const HAUL := {"pelvis": Vector3(0.0, 0.25, -0.1), "chest": Vector3(0.0, 0.47, -0.07),
	"feet": [Vector3(0.035, 0.3, 0.26), Vector3(-0.035, 0.33, 0.2), Vector3(0.085, 0.0, 0.11), Vector3(-0.085, 0.0, -0.06)],
	"poles": [Vector3(1.0, -1.0, 0.0), Vector3(-1.0, -1.0, 0.0), Vector3(0.4, 0.0, 1.0), Vector3(-0.4, 0.0, 1.0)]}
## The gaits: when each hand and foot comes in the cycle, how much of it a foot
## is down, how far the body goes in one (units), and how high a foot is lifted.
const WALK := {"offsets": [0.0, 0.5, 0.5, 0.0], "duty": 0.62, "cycle": 0.34, "lift": 0.04}
const TIPTOE := {"offsets": [0.0, 0.5, 0.5, 0.0], "duty": 0.55, "cycle": 0.46, "lift": 0.1}
const SCURRY := {"offsets": [0.0, 0.5, 0.5, 0.0], "duty": 0.36, "cycle": 0.9, "lift": 0.09}

## How big it is: metres to each of its own units (the crown of its head is
## 0.86 of them up, the tip of its hat 1.4).
@export var size := 0.4
## Its own small differences (build, hat, coat): two with one seed are alike.
@export var seed_value := 0
## Use the low-poly model (models/gnome_lo.glb), as `low_poly` does for every gnome.
@export var force_low := false
## Its sounds (giggle, whisper, squeal, patter), and how loud and far.
@export var voice := true
@export var volume_db := -8.0
@export var voice_range := 22.0

## Every gnome uses the low-poly model (phones).
static var low_poly := false

## What it looks at (world). INF: it looks where it goes, or about it.
var look_at_point := Vector3.INF
## Held exactly as it is, not posed at all, until let go.
var frozen := false:
	set(value):
		if value == frozen:
			return
		frozen = value
		if not frozen:
			# (it goes on from where it was, not with a jump in speed)
			_was = global_position
			_forward_was = global_basis.z
## The pose it stands in when it is not going anywhere.
var still := Still.CLASP
## On tiptoe, knees high, hands up in front, whatever its speed.
var creeping := false
## Hugging something to its chest.
var carrying := false
## Leaning back on a rope (`rope_point()` is where its hands are).
var hauling := false
## Knocked over, flailing.
var tumbling := false
## The patter of its feet as it goes.
var pattering := false

const MODEL := "res://creatures/gnome/models/gnome.glb"
const MODEL_LO := "res://creatures/gnome/models/gnome_lo.glb"

var _model: Node3D
var _skeleton: Skeleton3D
var _body: MeshInstance3D
var _rest: Array[Transform3D] = []
var _index := PackedInt32Array()
var _model_rest: Array[Transform3D] = []
var _skeleton_from_model := Transform3D.IDENTITY
var _frame := Transform3D.IDENTITY
var _voice: AudioStreamPlayer3D
var _feet: AudioStreamPlayer3D

var _t := 0.0
var _was := Vector3.INF
var _forward_was := Vector3.ZERO
var _speed := 0.0
var _turn := 0.0
var _phase := 0.0
var _moving := 0.0
var _creep := 0.0
var _scurry := 0.0
var _carry := 0.0
var _haul := 0.0
var _tumble := 0.0
var _still_w := {}
var _snatch := INF
var _giggle := INF
var _squeal := INF
var _whisper := INF
var _gaze := Vector3(0.0, 0.0, 1.0)
var _scan := Vector3(0.0, 0.0, 1.0)
var _scan_next := 0.0
var _tilt := 0.0
var _tilt_want := 0.0
var _hat := Vector2.ZERO
var _hat_v := Vector2.ZERO
var _beard := 0.0
var _rng := RandomNumberGenerator.new()
var _build := 1.0
var _hat_droop := Vector2.ZERO
var _hands := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _head_at := Vector3.ZERO

static var _sounds := {}


func _ready() -> void:
	_rng.seed = seed_value
	_build = _rng.randf_range(0.93, 1.07)
	_hat_droop = Vector2(_rng.randf_range(-0.2, 0.25), _rng.randf_range(-0.35, 0.35))
	_rest = _bone_globals(_joints(_standing(), Vector3(0.0, -0.1, 1.0)))
	var low := low_poly or force_low
	_model = (load(MODEL_LO if low else MODEL) as PackedScene).instantiate()
	_model.scale = Vector3.ONE * size
	add_child(_model)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	_body = _model.find_children("*", "MeshInstance3D", true, false)[0]
	_body.material_override = GnomeLook.material()
	_body.custom_aabb = AABB(Vector3(-0.8, -0.4, -0.8), Vector3(1.6, 2.4, 1.8))
	_body.set_instance_shader_parameter(&"tone", _rng.randf_range(0.85, 1.12))
	_body.set_instance_shader_parameter(&"hat_tint", GnomeLook.hat_colour(_rng.randi()))
	_body.set_instance_shader_parameter(&"coat_tint", GnomeLook.coat_colour(_rng.randi()))
	_index.resize(BONES.size())
	_model_rest.resize(BONES.size())
	_skeleton_from_model = _skeleton.global_transform.affine_inverse() * _model.global_transform
	for b in BONES.size():
		_index[b] = _skeleton.find_bone(BONES[b])
		_model_rest[b] = _skeleton.get_bone_global_rest(_index[b])
	if voice:
		_voice = AudioStreamPlayer3D.new()
		_voice.volume_db = volume_db
		_voice.unit_size = 2.0
		_voice.max_distance = voice_range
		_voice.position = Vector3(0.0, 0.8 * size, 0.1 * size)
		add_child(_voice)
		_feet = AudioStreamPlayer3D.new()
		_feet.volume_db = volume_db - 4.0
		_feet.unit_size = 1.5
		_feet.max_distance = voice_range * 0.6
		add_child(_feet)
	_phase = _rng.randf()
	settle()


## Puts it straight into its pose as it is now, with nothing going on.
func settle() -> void:
	_was = global_position
	_forward_was = global_basis.z
	_speed = 0.0
	_moving = 0.0
	_creep = 1.0 if creeping else 0.0
	_scurry = 0.0
	_carry = 1.0 if carrying else 0.0
	_haul = 1.0 if hauling else 0.0
	_tumble = 1.0 if tumbling else 0.0
	_still_w = {still: 1.0}
	_snatch = INF
	_giggle = INF
	_squeal = INF
	_whisper = INF
	_hat = _hat_droop
	_hat_v = Vector2.ZERO
	_pose(0.0)


func snatch() -> void:
	_snatch = 0.0


## Whether a snatch has just got to the end of its reach (this frame or the last).
func snatch_reached() -> bool:
	return _snatch >= SNATCH_TIME * 0.55 and _snatch < SNATCH_TIME * 0.55 + 0.05


func snatching() -> bool:
	return _snatch < SNATCH_TIME


func giggle() -> void:
	_giggle = 0.0
	_say(&"giggle")


func whisper() -> void:
	_whisper = 0.0
	_say(&"whisper")


func squeal() -> void:
	_squeal = 0.0
	_say(&"squeal")


## Where what it carries is held (world), from the last frame: between its hands.
func carry_point() -> Vector3:
	return (_hands[0] + _hands[1]) * 0.5


## Where its hands are on the rope (world), from the last frame.
func rope_point() -> Vector3:
	return (_hands[0] + _hands[1]) * 0.5


## Where its hands are (world), from the last frame.
func hands() -> PackedVector3Array:
	return _hands


## Where its head is (world), from the last frame.
func head_position() -> Vector3:
	return _head_at


func _process(delta: float) -> void:
	if delta <= 0.0 or frozen:
		return
	_t += delta
	var at := global_position
	if not _was.is_finite():
		_was = at
	var basis_now := global_basis.orthonormalized()
	var moved := basis_now.inverse() * (at - _was)
	moved.y = 0.0
	moved /= size
	_was = at
	var cycle := _cycle()
	_phase = fposmod(_phase + moved.z / cycle, 1.0)
	var speed := moved.length() / delta
	_speed = lerpf(_speed, speed, 1.0 - exp(-10.0 * delta))
	var forward := basis_now.z
	var turned := 0.0
	if _forward_was.length_squared() > 0.5:
		var a := _forward_was - basis_now.y * _forward_was.dot(basis_now.y)
		if a.length_squared() > 0.0001:
			turned = a.normalized().signed_angle_to(forward, basis_now.y)
	_forward_was = forward
	_turn = lerpf(_turn, turned / delta, 1.0 - exp(-6.0 * delta))
	_moving = move_toward(_moving, 1.0 if _speed > 0.25 else 0.0, delta * 5.0)
	_creep = move_toward(_creep, 1.0 if creeping else 0.0, delta * 4.0)
	_scurry = move_toward(_scurry, smoothstep(SCURRY_FROM * 0.7, SCURRY_FROM * 1.2, _speed) * (1.0 - _creep * 0.7), delta * 4.0)
	_carry = move_toward(_carry, 1.0 if carrying else 0.0, delta * 6.0)
	_haul = move_toward(_haul, 1.0 if hauling else 0.0, delta * 5.0)
	_tumble = move_toward(_tumble, 1.0 if tumbling else 0.0, delta * 8.0)
	for key: Variant in Still.values():
		var w: float = _still_w.get(key, 0.0)
		_still_w[key] = move_toward(w, 1.0 if key == still else 0.0, delta * 3.5)
	_snatch += delta
	_giggle += delta
	_squeal += delta
	_whisper += delta
	# The hat tip swings after it (a spring), drooping forward and aside when still.
	var push := Vector2(-moved.z / delta * 0.04 - _scurry * 0.35, -_turn * 0.08 * minf(_speed, 3.0))
	var want := _hat_droop * (1.0 - _moving * 0.6) + push
	_hat_v += (want - _hat) * 60.0 * delta - _hat_v * 7.0 * delta
	_hat += _hat_v * delta
	_hat = _hat.clamp(Vector2(-1.0, -0.9), Vector2(1.0, 0.9))
	_beard = lerpf(_beard, sin(TAU * _phase) * 0.12 * _moving + clampf(-_turn * 0.05, -0.2, 0.2), 1.0 - exp(-8.0 * delta))
	_patter(delta)
	_pose(delta)


func _cycle() -> float:
	var foot: float = lerpf(WALK["cycle"], TIPTOE["cycle"], _creep)
	return lerpf(foot, SCURRY["cycle"], _scurry)


func _patter(_delta: float) -> void:
	if _feet == null or not pattering or _speed < 0.6 or not is_inside_tree():
		return
	if not _feet.playing:
		_feet.stream = sound(&"patter")
		_feet.pitch_scale = clampf(0.8 + _speed * 0.05, 0.85, 1.35)
		_feet.play()


# --- Posing ---

## One whole pose: pelvis and chest, each hand (wrist) and foot (ball), which
## way each elbow and knee bends, and the rest.
class Pose:
	var pelvis := Vector3.ZERO
	var chest := Vector3.ZERO
	var feet: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var poles: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	## How far each hand turns palm in (0) or flat out ahead (1).
	var flat := [0.0, 0.0]
	var head_up := 0.0
	var head_turn := 0.0
	var head_tilt := 0.0
	## Fingers curled (1: a fist), each hand.
	var fingers := [0.5, 0.5]

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
			p.fingers[i] = lerpf(fingers[i], other.fingers[i], w)
		p.head_up = lerpf(head_up, other.head_up, w)
		p.head_turn = lerpf(head_turn, other.head_turn, w)
		p.head_tilt = lerpf(head_tilt, other.head_tilt, w)
		return p


## Where a foot is in its step: (forward, up) from where it stands.
static func _step(phase: float, offset: float, duty: float, reach: float, lift: float) -> Vector2:
	var s := fposmod(phase - offset, 1.0)
	if s < duty:
		return Vector2(reach * (0.5 - s / duty), 0.0)
	var k := (s - duty) / (1.0 - duty)
	var e := k * k * (3.0 - 2.0 * k)
	return Vector2(reach * (-0.5 + e), lift * sin(PI * k))


## Standing (in its still pose), or walking stooped as `_moving` rises.
func _standing_pose() -> Pose:
	var p := Pose.from(STAND)
	for key: Variant in _still_w:
		var w: float = _still_w[key]
		if w > 0.0 and key != Still.CLASP:
			p = p.blend(_still_pose(key), w * (1.0 - _moving))
	var reach: float = WALK["cycle"] * WALK["duty"]
	for i in [2, 3]:
		var s := _step(_phase, WALK["offsets"][i], WALK["duty"], reach, WALK["lift"])
		p.feet[i] += Vector3(0.0, s.y, s.x) * _moving
	# Walking, the hands come apart and swing a little; the body rocks foot to foot.
	var swing := sin(TAU * _phase)
	p.feet[0] = p.feet[0].lerp(Vector3(0.12, 0.33, 0.05 + 0.07 * swing), _moving * 0.85)
	p.feet[1] = p.feet[1].lerp(Vector3(-0.12, 0.33, 0.05 - 0.07 * swing), _moving * 0.85)
	var bob := -cos(TAU * 2.0 * _phase) * 0.012 * _moving
	var sway := sin(TAU * _phase) * 0.016 * _moving
	p.pelvis += Vector3(sway, bob, 0.0)
	p.chest += Vector3(sway * 1.3, bob * 0.7, 0.02 * _moving)
	# Breathing: slow, old.
	var breath := sin(_t * 1.7)
	p.chest.y += breath * 0.004
	return p


## A pose to stand in, as a garden ornament.
func _still_pose(which: Still) -> Pose:
	var p := Pose.from(STAND)
	match which:
		Still.HUSH:
			# (a finger to its lips, under the moustache; the other hand behind its back)
			p.feet[1] = Vector3(-0.025, 0.73, 0.2)
			p.poles[1] = Vector3(-1.0, -1.0, 0.0)
			p.fingers = [0.5, 0.1]
			p.feet[0] = Vector3(0.07, 0.37, -0.1)
			p.poles[0] = Vector3(1.0, 0.0, 1.0)
			p.head_up = -0.1
			p.head_tilt = 0.15
		Still.PEER:
			# (its hand flat over its brow, peering out under it, leaning on)
			p.feet[1] = Vector3(-0.05, 0.86, 0.2)
			p.poles[1] = Vector3(-1.0, -0.4, 0.0)
			p.flat = [0.0, 1.0]
			p.fingers = [0.6, 0.0]
			p.chest += Vector3(0.0, 0.0, 0.04)
			p.head_up = 0.12
		Still.POINT:
			# (one long arm out, pointing the way on)
			p.feet[1] = Vector3(-0.31, 0.63, 0.29)
			p.poles[1] = Vector3(-0.5, -1.0, 0.0)
			p.fingers = [0.6, 0.0]
			p.head_turn = -0.4
	return p


## On tiptoe, knees high, hands up in front with the fingers drooping.
func _creep_pose() -> Pose:
	var p := Pose.from(CREEP)
	var reach: float = TIPTOE["cycle"] * TIPTOE["duty"]
	for i in [2, 3]:
		var s := _step(_phase, TIPTOE["offsets"][i], TIPTOE["duty"], reach, TIPTOE["lift"])
		p.feet[i] += Vector3(0.0, s.y, s.x) * _moving
	var swing := sin(TAU * _phase)
	p.feet[0] += Vector3(0.0, 0.02 * swing, 0.03 * swing) * _moving
	p.feet[1] += Vector3(0.0, -0.02 * swing, -0.03 * swing) * _moving
	var bob := -cos(TAU * 2.0 * _phase) * 0.02 * _moving
	p.pelvis.y += bob
	p.chest.y += bob * 0.8
	p.flat = [0.4, 0.4]
	p.fingers = [0.25, 0.25]
	p.head_up = 0.05
	return p


## Scurrying headlong: leaning, arms pumping, long bounding steps.
func _scurry_pose() -> Pose:
	var p := Pose.from(RUN)
	var reach: float = SCURRY["cycle"] * SCURRY["duty"]
	for i in [2, 3]:
		var s := _step(_phase, SCURRY["offsets"][i], SCURRY["duty"], reach, SCURRY["lift"])
		p.feet[i] += Vector3(0.0, s.y, s.x) * _moving
	var swing := sin(TAU * _phase)
	p.feet[0] += Vector3(0.0, 0.05 * maxf(swing, 0.0), 0.13 * swing)
	p.feet[1] += Vector3(0.0, 0.05 * maxf(-swing, 0.0), -0.13 * swing)
	var bound := absf(sin(TAU * _phase)) * 0.03
	p.pelvis.y += bound
	p.chest.y += bound * 0.8
	p.fingers = [0.9, 0.9]
	p.head_up = 0.15
	return p


## Hugging something to its chest (over the other poses' legs).
func _carry_over(p: Pose, w: float) -> Pose:
	var q := Pose.new()
	q.pelvis = p.pelvis
	q.chest = p.chest + Vector3(0.0, 0.0, -0.03)
	q.feet = p.feet.duplicate()
	q.poles = p.poles.duplicate()
	q.feet[0] = p.chest + Vector3(0.075, -0.02, 0.17)
	q.feet[1] = p.chest + Vector3(-0.075, -0.02, 0.17)
	q.poles[0] = Vector3(1.0, -0.5, 0.0)
	q.poles[1] = Vector3(-1.0, -0.5, 0.0)
	q.fingers = [0.8, 0.8]
	q.head_up = p.head_up + 0.15
	q.head_turn = p.head_turn
	q.head_tilt = p.head_tilt
	return p.blend(q, w)


## Leaning back on a rope, both hands on it in front, braced.
func _haul_pose() -> Pose:
	var p := Pose.from(HAUL)
	var heave := sin(_t * 5.0) * 0.012
	p.pelvis.z += heave
	p.chest.z += heave * 1.5
	p.fingers = [1.0, 1.0]
	p.head_up = 0.1
	return p


## Knocked over: on its back, arms and legs flailing.
func _tumble_pose() -> Pose:
	var p := Pose.from(STAND)
	p.pelvis = Vector3(0.0, 0.12, -0.05)
	p.chest = Vector3(0.0, 0.17, -0.3)
	for i in 4:
		var a := _t * (12.0 + i * 2.1) + i * 1.9
		var s := 1.0 if i % 2 == 0 else -1.0
		if i < 2:
			p.feet[i] = Vector3(0.18 * s + 0.05 * sin(a) * s, 0.35 + 0.08 * cos(a * 1.2), -0.15 + 0.07 * sin(a * 0.8))
		else:
			p.feet[i] = Vector3(0.09 * s, 0.25 + 0.08 * sin(a), 0.12 + 0.06 * cos(a))
	p.fingers = [0.0, 0.0]
	p.head_up = 0.6
	return p


func _pose(delta: float) -> void:
	var p := _standing_pose()
	if _creep > 0.0:
		p = p.blend(_creep_pose(), smoothstep(0.0, 1.0, _creep))
	if _scurry > 0.0:
		p = p.blend(_scurry_pose(), smoothstep(0.0, 1.0, _scurry))
	if _haul > 0.0:
		p = p.blend(_haul_pose(), smoothstep(0.0, 1.0, _haul))
	if _carry > 0.0:
		p = _carry_over(p, smoothstep(0.0, 1.0, _carry))
	# The snatch: both hands flung up and forward, then hugged in.
	if _snatch < SNATCH_TIME:
		var k := _snatch / SNATCH_TIME
		var out := smoothstep(0.0, 0.5, k) * (1.0 - smoothstep(0.6, 1.0, k))
		var lean := sin(PI * k)
		p.chest += Vector3(0.0, 0.03 * lean, 0.08 * lean)
		p.pelvis += Vector3(0.0, 0.02 * lean, 0.04 * lean)
		for i in 2:
			var s := 1.0 if i == 0 else -1.0
			p.feet[i] = p.feet[i].lerp(Vector3(0.07 * s, 0.68, 0.36), out)
			p.poles[i] = p.poles[i].lerp(Vector3(s, -1.0, 0.0), out)
			p.fingers[i] = lerpf(p.fingers[i], 0.0, out) if k < 0.5 else lerpf(p.fingers[i], 1.0, out)
		p.head_up += 0.2 * lean
	# The giggle: a hand over its mouth, shoulders shaking.
	if _giggle < GIGGLE_TIME:
		var c := minf(sin(PI * _giggle / GIGGLE_TIME) * 2.0, 1.0)
		var shake := sin(_giggle * 34.0)
		var free := 1.0 - maxf(_carry, _haul)
		p.feet[1] = p.feet[1].lerp(Vector3(-0.02, 0.71, 0.21), c * free)
		p.poles[1] = p.poles[1].lerp(Vector3(-1.0, -1.0, 0.0), c * free)
		p.chest += Vector3(0.0, 0.008 * shake, 0.0) * c
		p.head_up -= 0.15 * c
		p.head_tilt += 0.2 * c
	# The whisper: head tipped right over, leaning in.
	if _whisper < WHISPER_TIME:
		var c := minf(sin(PI * _whisper / WHISPER_TIME) * 2.0, 1.0)
		p.head_tilt += 0.45 * c
		p.chest.z += 0.03 * c
	# The squeal: arms flung up.
	if _squeal < SQUEAL_TIME:
		var c := minf(sin(PI * _squeal / SQUEAL_TIME) * 2.5, 1.0)
		var flap := sin(_squeal * 30.0) * 0.04
		p.feet[0] = p.feet[0].lerp(Vector3(0.16, 0.86 + flap, 0.08), c)
		p.feet[1] = p.feet[1].lerp(Vector3(-0.16, 0.86 - flap, 0.08), c)
		p.poles[0] = p.poles[0].lerp(Vector3(1.0, 0.0, -0.5), c)
		p.poles[1] = p.poles[1].lerp(Vector3(-1.0, 0.0, -0.5), c)
		p.fingers = [0.0, 0.0]
		p.head_up += 0.4 * c
	if _tumble > 0.0:
		p = p.blend(_tumble_pose(), _tumble)
	var lean := clampf(-_turn * _speed * 0.03, -0.3, 0.3)
	_frame = Transform3D(Basis(Vector3.BACK, lean), Vector3.ZERO)
	_look(p, delta)
	_apply(p)


## Where its eyes are on: what it was given, or where it goes, or (still) about
## it slowly, now and then its head tipped on one side.
func _look(p: Pose, delta: float) -> void:
	var want := Vector3(0.0, -0.1, 1.0)
	var rate := 4.0
	if look_at_point.is_finite():
		var local := (global_transform.affine_inverse() * look_at_point) / size
		want = (local - p.chest - Vector3(0.0, 0.2, 0.05)).normalized()
		if want.z < 0.15:
			want.z = 0.15
			want = want.normalized()
		rate = 6.0
	elif _moving < 0.5:
		_scan_next -= delta
		if _scan_next <= 0.0:
			_scan_next = _rng.randf_range(1.5, 4.5)
			_scan = Vector3(_rng.randf_range(-1.1, 1.1), _rng.randf_range(-0.25, 0.25), 1.0)
			_tilt_want = _rng.randf_range(-0.35, 0.35) if _rng.randf() < 0.4 else 0.0
		want = _scan.normalized()
		rate = 1.6
	_tilt = lerpf(_tilt, _tilt_want * (1.0 - _moving), 1.0 - exp(-2.0 * delta)) if delta > 0.0 else _tilt
	_gaze = _gaze.slerp(want, 1.0 - exp(-rate * delta)) if delta > 0.0 else want
	p.head_tilt += _tilt


# --- The skeleton ---

## Its bones. None is the child of another: each is posed straight in the
## skeleton's space (where its two ends are, worked out in `_joints`), so the
## mesh bends between them however the body is put.
const BONES: Array[String] = ["hips", "belly", "chest", "neck", "head",
	"hat_1", "hat_2", "hat_3", "beard_1", "beard_2",
	"arm_l", "arm_r", "forearm_l", "forearm_r", "hand_l", "hand_r", "fingers_l", "fingers_r",
	"thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r"]
const HIPS := 0
const BELLY := 1
const CHEST := 2
const NECK := 3
const HEAD := 4
const HAT_B := 5
const BEARD_B := 8
const ARM_U := 10
const ARM_L := 12
const HAND := 14
const FINGERS := 16
const LEG_U := 18
const LEG_L := 20
const FOOT := 22

## How big its head is (units): the skull's half-width.
const HEAD_SIZE := 0.15
## The hat: where it sits on the head (head space), how wide, and how long (units).
const HAT_BASE := Vector3(0.0, 0.04, 0.0)
const HAT_WIDE := 0.148
const HAT_LONG := Vector3(0.19, 0.17, 0.15)
## How its hat droops as it was made (forward, aside), before it swings.
const HAT_REST := Vector2(0.6, 0.12)
## The beard: where it hangs from (head space) and how long each part is.
const CHIN := Vector3(0.0, -0.08, 0.09)
const BEARD_LONG := Vector2(0.15, 0.14)


## Standing still: the way it was modelled.
func _standing() -> Pose:
	return Pose.from(STAND)


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
	# The paunch hangs out in front of the middle.
	var middle := p.pelvis.lerp(p.chest, 0.45)
	j["belly"] = middle + front * 0.025
	var neck := p.chest + spine * 0.05 + front * 0.045
	j["neck"] = neck
	var roots := PackedVector3Array()
	var mids := PackedVector3Array()
	var ends := PackedVector3Array()
	for i in 4:
		var arm := i < 2
		var sign := 1.0 if i % 2 == 0 else -1.0
		var root := (p.chest + side * sign * 0.105 - front * 0.01) if arm else (p.pelvis + side * sign * 0.06 - spine * 0.025)
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
	var hands: Array[Basis] = []
	var knuckles := PackedVector3Array()
	for i in 2:
		var sign := 1.0 if i == 0 else -1.0
		var along := (ends[i] - mids[i]).normalized()
		var flat_way := Vector3(0.2 * sign, 0.35, 1.0).normalized()
		var dir := along.slerp(flat_way, clampf(float(p.flat[i]), 0.0, 1.0) * 0.8).normalized()
		hands.append(_along(dir, side))
		knuckles.append(ends[i] + dir * 0.05)
	j["hands"] = hands
	j["knuckles"] = knuckles
	# The head, turned to look along `gaze_dir`, tipped up by `head_up` and over by `head_tilt`.
	var gaze := (Basis(Vector3.UP, p.head_turn) * Basis(Vector3.RIGHT, -p.head_up) * gaze_dir.normalized()).normalized()
	var head_at := neck + (spine * 0.6 + Vector3.UP * 0.4).normalized() * 0.11 + gaze * 0.02
	var head_basis := Basis.looking_at(-gaze, Vector3.UP if absf(gaze.y) < 0.95 else front)
	head_basis = Basis(head_basis.z, p.head_tilt) * head_basis
	var head := Transform3D(head_basis, head_at)
	j["head_xform"] = head
	# The hat: three lengths up from its band, each bent further by the droop and swing.
	var hat := PackedVector3Array()
	var at := head * HAT_BASE
	hat.append(at)
	var up := head_basis.y.rotated(head_basis.x, 0.06)
	for k in 3:
		var bend := float(k + 1) / 3.0
		var flop := pow(bend, 2.2) * 1.1
		var dir := up.rotated(head_basis.x, (HAT_REST.x + _hat.x) * flop).rotated(head_basis.z, (HAT_REST.y + _hat.y) * flop)
		at += dir.normalized() * HAT_LONG[k]
		hat.append(at)
	j["hat"] = hat
	# The beard, hanging from the chin, swinging.
	var chin := head * CHIN
	var hang := (Vector3.DOWN + front * 0.12 + side * _beard).normalized()
	var tip1 := chin + hang * BEARD_LONG.x
	var hang2 := (Vector3.DOWN - front * 0.06 + side * _beard * 1.6).normalized()
	j["beard"] = PackedVector3Array([chin, tip1, tip1 + hang2 * BEARD_LONG.y])
	j["fingers"] = PackedFloat32Array([p.fingers[0], p.fingers[1]])
	return j


## Each bone's two ends, as a pair, or (for those not stretched between two
## places) its whole transform.
func _pairs(j: Dictionary) -> Array:
	var pairs := []
	pairs.resize(BONES.size())
	var torso: Basis = j["torso"]
	pairs[HIPS] = [j["pelvis"] - torso.y * 0.06, j["pelvis"]]
	pairs[BELLY] = [j["pelvis"], j["belly"]]
	pairs[CHEST] = [j["belly"], j["chest"]]
	pairs[NECK] = [j["chest"], j["neck"]]
	pairs[HEAD] = j["head_xform"]
	var hat: PackedVector3Array = j["hat"]
	for k in 3:
		pairs[HAT_B + k] = [hat[k], hat[k + 1]]
	var beard: PackedVector3Array = j["beard"]
	pairs[BEARD_B] = [beard[0], beard[1]]
	pairs[BEARD_B + 1] = [beard[1], beard[2]]
	var hands: Array = j["hands"]
	var curl: PackedFloat32Array = j["fingers"]
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
			pairs[FINGERS + i] = Transform3D(hand * Basis(Vector3.RIGHT, curl[i] * 1.4), j["knuckles"][i])
		else:
			pairs[FOOT + i % 2] = [end, j["balls"][i - 2]]
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
	var to_world := _model.global_transform * _frame
	var hands: Array = j["hands"]
	for i in 2:
		var end: Vector3 = j["ends"][i]
		_hands[i] = to_world * (end + (hands[i] as Basis).y * HAND_LONG * 0.6)
	_head_at = to_world * (j["head_xform"] as Transform3D).origin


# --- Its voice ---

func _say(what: StringName) -> void:
	if _voice == null or not is_inside_tree():
		return
	_voice.stream = sound(what)
	_voice.pitch_scale = _rng.randf_range(0.9, 1.1)
	_voice.play()


## Its sounds, made once and shared: `giggle`, `whisper`, `squeal` or `patter`.
static func sound(what: StringName) -> AudioStreamWAV:
	if _sounds.has(what):
		return _sounds[what]
	var made: AudioStreamWAV
	match what:
		&"giggle":
			made = _voice_sound(0.95, 41, _giggle_shape, 7.5, 0.55)
		&"squeal":
			made = _voice_sound(0.7, 43, _squeal_shape, 0.0, 0.25)
		&"whisper":
			made = _voice_sound(0.85, 47, _whisper_shape, 4.5, 1.0)
		&"patter":
			made = _patter_sound(0.6, 53)
	_sounds[what] = made
	return made


## A thin, old titter, "hee-hee-hee" (pitch, loudness, how much of each syllable is voiced).
static func _giggle_shape(t: float) -> Vector3:
	return Vector3(640.0 + 160.0 * sin(t * 9.0) - 120.0 * t, 1.0 - 0.4 * t, 0.5)


static func _squeal_shape(t: float) -> Vector3:
	return Vector3(900.0 + 700.0 * smoothstep(0.0, 0.5, t) - 300.0 * smoothstep(0.6, 1.0, t), 1.0, 1.0)


## A whisper is all breath: the pitch only shapes it.
static func _whisper_shape(t: float) -> Vector3:
	return Vector3(300.0, 0.8 - 0.3 * t, 0.7)


## A small, dry voice: glottal pulses through a throat's resonances, with
## breath (`breathy` 0..1 how much is breath), chopped into syllables `rate` a
## second (0: one cry). `shape(t)` is (pitch, loudness, how much of each
## syllable is voice).
static func _voice_sound(length: float, seed: int, shape: Callable, rate: float, breathy: float) -> AudioStreamWAV:
	var mix := 22050
	var count := int(mix * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var samples := PackedFloat32Array()
	samples.resize(count)
	var bands: Array[_Band] = [_Band.new(900.0, 5.0, mix), _Band.new(2100.0, 6.0, mix), _Band.new(3300.0, 6.0, mix)]
	var gains := [1.0, 0.7, 0.4]
	var breath := _Band.new(3600.0, 1.2, mix)
	var phase := 0.0
	var wander := 0.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / mix
		var s: Vector3 = shape.call(t / length)
		wander = clampf(wander + rng.randf_range(-1.0, 1.0) * 0.1, -1.0, 1.0)
		var pitch := s.x * (1.0 + 0.06 * wander)
		var gate := 1.0
		if rate > 0.0:
			var syl := fposmod(t * rate, 1.0)
			gate = smoothstep(0.0, 0.07, syl) * (1.0 - smoothstep(s.z * 0.8, s.z, syl))
			pitch *= 1.15 - 0.25 * syl
		phase += pitch / mix
		var p := fposmod(phase, 1.0)
		var pulse := pow(1.0 - p, 5.0) * 2.0 - 0.35
		var throat := 0.0
		for k in bands.size():
			throat += bands[k].run(pulse) * gains[k]
		var air := breath.run(rng.randf_range(-1.0, 1.0))
		var fade := smoothstep(0.0, 0.03, t) * (1.0 - smoothstep(length - 0.12, length, t))
		var value := (throat * 1.4 * (1.0 - breathy) + air * (0.6 + 1.6 * breathy)) * gate * s.y * fade
		value = tanh(value * 2.0)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	return _wav(samples, loudest, mix)


## The patter of small boots on mud: quick soft taps, a little uneven.
static func _patter_sound(length: float, seed: int) -> AudioStreamWAV:
	var mix := 22050
	var count := int(mix * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var samples := PackedFloat32Array()
	samples.resize(count)
	var at := 0
	while at < count:
		var long := rng.randi_range(300, 700)
		var loud := rng.randf_range(0.5, 1.0)
		var tone := _Band.new(rng.randf_range(500.0, 1100.0), 2.5, mix)
		for k in long:
			if at + k >= count:
				break
			samples[at + k] += tone.run(rng.randf_range(-1.0, 1.0)) * loud * exp(-float(k) / long * 5.0) * 2.0
		at += rng.randi_range(1500, 2600)
	var loudest := 0.001
	for v in samples:
		loudest = maxf(loudest, absf(v))
	return _wav(samples, loudest, mix)


static func _wav(samples: PackedFloat32Array, loudest: float, mix: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / maxf(loudest, 0.001), -1.0, 1.0) * 26000.0))
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

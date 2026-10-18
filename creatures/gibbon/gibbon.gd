class_name Gibbon
extends Node3D
## A gibbon: how it looks, moves and sounds, and nothing of what it thinks.
## Whatever drives it (a game's enemy script, a cutscene, the example) moves
## this node about and calls on it; it poses itself from that.
##
## WHAT IT IS. A small ape with no tail, made to hang: arms far longer than its
## legs (fingertips to the ground when it stands), long hook hands with a small
## thumb set low, short bowed legs with long grasping feet, a narrow chest, a
## small round head on a short neck, a flat bare face, dark, with deep-set eyes
## and long canines. Shaggy, dense fur all over but the face, palms and soles.
## `kind` says its coat (GibbonLook shades it):
## - DARK: black-brown all over (like a siamang or a black crested gibbon).
## - RINGED: as dark, with a white ring of fur round the face and white hands and
##   feet (a lar gibbon's dark phase).
## - PALE: buff-grey, with the white ring, hands and feet (a lar's pale phase).
## Everything is one skinned mesh on a skeleton made here (models/gibbon.glb, or
## gibbon_lo.glb), so each gibbon is one draw.
##
## HOW IT MOVES. Move the node (`global_position`) and turn it (its Y rotation;
## it faces +Z, the way it is going); it works out its speed from that. `gait`
## says how it is going, and where the node is on it:
## - HANG: the node is on the bar or edge it hangs from (where its hands
##   grip). Going along, it brachiates: hand over hand, its body swinging under
##   each grip like a pendulum, turning about the arm it hangs from, the free
##   hand reaching ahead for the next hold; fast, the swings get longer and it
##   lets go between them and flies (ricochetal). Its legs are tucked up. Still,
##   it hangs by one arm and sways, the other arm loose, or holds on with both.
## - WALK: the node is on the ground under its feet. It walks upright on short
##   bent legs in quick steps, its arms held up and out for balance; stopped, it
##   stands with its arms hanging to the ground, or with `sitting` it squats on
##   its haunches, knees up, an arm over a knee, and looks about.
## - FLY: the node is where its hands will be when it catches hold again (move
##   it along the leap's arc yourself): it flies with both arms stretched out
##   ahead to take hold, its legs tucked under it.
## Changing gait it blends from one to the next (`GAIT_TIME`): from HANG to WALK
## with the node where the edge is, it hauls itself up over it.
## `look_at_point` (world, INF for none) is what its head turns to.
##
## WHAT IT DOES, on a call, each blending in and out by itself:
## - `great_call(seconds)`: the great call, the gibbon's song: head back, lips
##   in an O, a run of whoops rising in pitch and quickening, to a climax where
##   it shakes itself and flails its free arm (or both, sitting). With `sound`
##   on it is heard (made in code); two or more calling at once is a duet.
## - `lunge(point)`: the grab. A wind-up (`WIND_UP`): it draws its body back and
##   up, legs tucked, mouth wide, and shrieks; then (`STRIKE`) it swings at the
##   point feet first, its free hand reaching for it; then gathers itself
##   (`RECOVER`). `reaches(point, radius)` says whether its feet or free hand are
##   on a point now (only in the strike), for whatever decides a grab.
##
## Set `kind` (and `size`, `seed_value` for its own small differences) before it
## goes into the tree. `settle()` puts it still where it is, for when it is put
## somewhere. Hide it or disable it when it is far from the camera: it poses
## itself every frame.

enum Kind { DARK, RINGED, PALE }
enum Gait { HANG, WALK, FLY }
enum Lunge { NONE, WIND_UP, STRIKE, RECOVER }

const WIND_UP := 0.6
const STRIKE := 0.38
const RECOVER := 0.5
## Seconds a change of gait takes.
const GAIT_TIME := 0.35
## The great call's length, by default.
const CALL_TIME := 4.5

## Its coats (GibbonLook): the fur, the pale ring and hands (if it has them), the bare skin.
const COATS := {
	Kind.DARK: {"coat": Color(0.085, 0.078, 0.072), "pale": Color(0.085, 0.078, 0.072), "ring": 0.0},
	Kind.RINGED: {"coat": Color(0.11, 0.1, 0.09), "pale": Color(0.62, 0.6, 0.57), "ring": 1.0},
	Kind.PALE: {"coat": Color(0.5, 0.46, 0.39), "pale": Color(0.86, 0.84, 0.79), "ring": 1.0},
}

## Its proportions, metres at size 1 (it stands about 0.8 m, its arms reach 2 m across).
## Pelvis to the line of the shoulders; half across the shoulders and the hips.
const SPINE := 0.33
const SHOULDER := 0.1
const HIP := 0.062
## Upper arm and forearm; palm and fingers.
const ARM := Vector2(0.37, 0.4)
const HAND := Vector2(0.085, 0.095)
## Thigh and shin; foot and toes.
const LEG := Vector2(0.21, 0.2)
const FOOT := Vector2(0.075, 0.07)
## From the wrist to where the hooked fingers take hold.
const GRIP := 0.13
## Shoulder to the hold, hanging (the arm straight, the hand hooked).
const REACH := ARM.x + ARM.y + GRIP

@export var kind := Kind.RINGED
## How big it is drawn (metres per unit).
@export var size := 1.0
## Its own small differences (coat, build): two with one seed are alike.
@export var seed_value := 0
## Use the low-poly model (models/gibbon_lo.glb), as `low_poly` does for every gibbon.
@export var force_low := false
## Makes its own sounds (the great call, the shriek).
@export var sound := true
@export var volume_db := 0.0

## Every gibbon uses the low-poly model (phones).
static var low_poly := false

## How it is going, and where the node is on it (see above).
var gait := Gait.WALK
## Sit on its haunches when it stops (walking).
var sitting := false
## What it looks at (world). INF: where it goes, or about it.
var look_at_point := Vector3.INF
## Hanging from the edge of a ledge or a wall: the way out from the wall
## (world, flat), so that it hangs clear of the face below the edge. Zero: a
## bar in the open.
var away_from := Vector3.ZERO

var _model: Node3D
var _skeleton: Skeleton3D
var _body: MeshInstance3D
var _rest: Array[Transform3D] = []
## Each limb bone as it stands, in the torso's own frame (for posing without twisting).
var _rest_dir: Array[Vector3] = []
var _rest_basis: Array[Basis] = []
var _index := PackedInt32Array()
var _model_rest: Array[Transform3D] = []
var _skeleton_from_model := Transform3D.IDENTITY

var _t := 0.0
var _was := Vector3.INF
var _speed := 0.0
var _dir := Vector3.BACK
var _w := [0.0, 1.0, 0.0]
var _phase := 0.0
var _moving := 0.0
var _sit := 0.0
# Brachiation: each hand's hold (world), which hand holds, where the free one let go, the swing's length.
var _grips: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _holding := 0
var _let_go := Vector3.ZERO
var _swing := 1.2
var _gripped := false
var _two_hands := 0.0
var _idle_swap := 4.0
var _call_left := 0.0
var _call_time := CALL_TIME
var _lunge := INF
var _lunge_at := Vector3.ZERO
var _gaze := Vector3(0.0, 0.0, 1.0)
var _scan := Vector3(0.0, 0.0, 1.0)
var _scan_next := 0.0
var _rng := RandomNumberGenerator.new()
var _grabbers := PackedVector3Array()
var _voice: AudioStreamPlayer3D
static var _call_sound: AudioStreamWAV
static var _shriek_sound: AudioStreamWAV


func _ready() -> void:
	_rng.seed = seed_value
	_rest = _bone_globals(_joints(_standing(), Vector3(0.0, 0.0, 1.0)))
	_keep_rest(_joints(_standing(), Vector3(0.0, 0.0, 1.0)))
	var low := low_poly or force_low
	_model = (load("res://creatures/gibbon/models/gibbon%s.glb" % ("_lo" if low else "")) as PackedScene).instantiate()
	_model.scale = Vector3.ONE * size
	add_child(_model)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	_body = _model.find_children("*", "MeshInstance3D", true, false)[0]
	_body.material_override = GibbonLook.material()
	# (hanging, it is below its node; walking, above)
	_body.custom_aabb = AABB(Vector3(-1.2, -1.6, -1.2), Vector3(2.4, 2.8, 2.4))
	var coat: Dictionary = COATS[kind]
	var tone := _rng.randf_range(0.9, 1.1)
	_body.set_instance_shader_parameter(&"coat", (coat["coat"] as Color) * tone)
	_body.set_instance_shader_parameter(&"pale", coat["pale"])
	_body.set_instance_shader_parameter(&"ring", coat["ring"])
	_index.resize(BONES.size())
	_model_rest.resize(BONES.size())
	for b in BONES.size():
		_index[b] = _skeleton.find_bone(BONES[b])
		_model_rest[b] = _skeleton.get_bone_global_rest(_index[b])
	_skeleton_from_model = _skeleton.global_transform.affine_inverse() * _model.global_transform
	if sound:
		_voice = AudioStreamPlayer3D.new()
		_voice.volume_db = volume_db
		_voice.unit_size = 12.0
		_voice.max_distance = 120.0
		_voice.position = Vector3(0.0, 0.3, 0.0)
		add_child(_voice)
		# (made now, while the round is being made, not when it first calls)
		call_sound()
		shriek_sound()
	settle()


## Puts it still as it is now, in its gait, with nothing going on.
func settle() -> void:
	_was = global_position
	_speed = 0.0
	_moving = 0.0
	for g in 3:
		_w[g] = 1.0 if g == gait else 0.0
	_sit = 1.0 if sitting and gait == Gait.WALK else 0.0
	_call_left = 0.0
	_lunge = INF
	_regrip()
	_pose(0.0)


## The great call, for `seconds`.
func great_call(seconds := CALL_TIME) -> void:
	_call_time = maxf(seconds, 1.0)
	_call_left = _call_time
	_play(call_sound(), CALL_TIME / _call_time * _rng.randf_range(0.93, 1.08))


func calling() -> bool:
	return _call_left > 0.0


## How far through its call it is, 0..1 (0 when it is not calling).
func call_progress() -> float:
	return 1.0 - _call_left / _call_time if _call_left > 0.0 else 0.0


## Winds up and swings at `point` (world), feet first.
func lunge(point: Vector3) -> void:
	_lunge = 0.0
	_lunge_at = point
	_call_left = 0.0
	_play(shriek_sound(), _rng.randf_range(0.92, 1.1))


## Where it swings at, while lunging (you may move it as the thing moves).
func aim_lunge(point: Vector3) -> void:
	_lunge_at = point


func lunge_stage() -> Lunge:
	if _lunge < WIND_UP:
		return Lunge.WIND_UP
	if _lunge < WIND_UP + STRIKE:
		return Lunge.STRIKE
	if _lunge < WIND_UP + STRIKE + RECOVER:
		return Lunge.RECOVER
	return Lunge.NONE


## How far through the stage of its lunge it is, 0..1.
func lunge_progress() -> float:
	match lunge_stage():
		Lunge.WIND_UP:
			return _lunge / WIND_UP
		Lunge.STRIKE:
			return (_lunge - WIND_UP) / STRIKE
		Lunge.RECOVER:
			return (_lunge - WIND_UP - STRIKE) / RECOVER
	return 0.0


## Whether its feet or free hand are within `radius` of `point` (world), in the strike of a lunge.
func reaches(point: Vector3, radius: float) -> bool:
	if lunge_stage() != Lunge.STRIKE:
		return false
	for p in _grabbers:
		if p.distance_to(point) < radius:
			return true
	return false


## Where its free hand and its feet are (world), from the last frame.
func grabbers() -> PackedVector3Array:
	return _grabbers


## Where its hands hold now (world), hanging: the one it hangs from first.
func holds() -> PackedVector3Array:
	return PackedVector3Array([_grips[_holding], _grips[1 - _holding]])


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_t += delta
	var at := global_position
	if not _was.is_finite():
		_was = at
	var moved := at - _was
	_was = at
	var flat := Vector3(moved.x, 0.0, moved.z)
	var forward := global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.BACK
	_speed = lerpf(_speed, flat.length() / delta, 1.0 - exp(-10.0 * delta))
	_dir = flat.normalized() if flat.length() > 0.0005 else forward
	var unit_speed := _speed / size
	_moving = move_toward(_moving, 1.0 if unit_speed > 0.15 else 0.0, delta * 4.0)
	# The gaits, blending.
	var was_hanging: float = _w[Gait.HANG]
	for g in 3:
		_w[g] = move_toward(_w[g], 1.0 if g == gait else 0.0, delta / GAIT_TIME)
	if was_hanging <= 0.0 and _w[Gait.HANG] > 0.0 or gait == Gait.FLY:
		_gripped = false
	if gait == Gait.WALK:
		_phase = fposmod(_phase + flat.dot(forward) / size / 0.62, 1.0)
	_sit = move_toward(_sit, 1.0 if sitting and gait == Gait.WALK and unit_speed < 0.1 else 0.0, delta * 2.0)
	if gait == Gait.HANG:
		_brachiate(delta)
	_call_left = maxf(_call_left - delta, 0.0)
	if _lunge != INF:
		_lunge += delta
		if lunge_stage() == Lunge.NONE:
			_lunge = INF
	_pose(delta)


## Takes hold where it is: the hanging hand on the node, the other beside it.
func _regrip() -> void:
	var side := global_basis.x
	_grips[_holding] = global_position
	_grips[1 - _holding] = global_position + side * (0.22 if _holding == 0 else -0.22) * size
	_let_go = _grips[1 - _holding]
	_swing = 1.0 * size
	_gripped = true


## Hand over hand: the hand that holds stays where it took hold; when the
## body has swung past it far enough, the free hand takes the next hold ahead
## and the other lets go.
func _brachiate(delta: float) -> void:
	if not _gripped:
		_regrip()
	var at := global_position
	var hold := _grips[_holding]
	var off := at - hold
	off.y = 0.0
	var along := off.dot(_dir)
	var unit_speed := _speed / size
	var stride := clampf(0.75 + 0.3 * unit_speed, 0.85, 2.5) * size
	if _moving > 0.3:
		_two_hands = move_toward(_two_hands, 0.0, delta * 3.0)
		if along > _swing * 0.5 or off.length() > _swing * 0.8:
			_let_go = hold
			_holding = 1 - _holding
			_grips[_holding] = at + _dir * stride * 0.5
			_swing = stride
	else:
		# Still: hanging by one arm, now and then taking hold with both, or changing hands.
		if off.length() > 0.35 * size:
			_let_go = hold
			_holding = 1 - _holding
			_grips[_holding] = at
			_swing = 0.7 * size
		_idle_swap -= delta
		if _idle_swap <= 0.0:
			_idle_swap = _rng.randf_range(3.0, 7.0)
			if _two_hands > 0.5:
				_two_hands = 0.0
			elif _rng.randf() < 0.5:
				_two_hands = 1.0
			else:
				_let_go = _grips[_holding]
				_holding = 1 - _holding
				_grips[_holding] = at + global_basis.x * (0.1 if _holding == 0 else -0.1) * size
		if _two_hands > 0.0:
			_grips[1 - _holding] = _grips[_holding] + global_basis.x * (0.24 if _holding == 0 else -0.24) * size


# --- Posing ---

## One whole pose, in units (metres at size 1) in the node's own space: the
## middle of the hips and of the shoulders, which way its front faces, where
## each hand takes hold and each ankle is, which way elbows and knees bend, how
## hooked the hands are, which way the feet point, the head and jaw.
class Pose:
	var pelvis := Vector3(0.0, 0.4, 0.0)
	var chest := Vector3(0.0, 0.73, 0.02)
	var front := Vector3(0.0, 0.0, 1.0)
	var hands: Array[Vector3] = [Vector3(0.35, 0.2, 0.05), Vector3(-0.35, 0.2, 0.05)]
	var elbows: Array[Vector3] = [Vector3(0.5, 0.0, -1.0), Vector3(-0.5, 0.0, -1.0)]
	var curl: Array[float] = [0.3, 0.3]
	var feet: Array[Vector3] = [Vector3(0.08, 0.04, 0.02), Vector3(-0.08, 0.04, 0.02)]
	var knees: Array[Vector3] = [Vector3(0.3, 0.0, 1.0), Vector3(-0.3, 0.0, 1.0)]
	var toes: Array[Vector3] = [Vector3(0.1, -0.15, 1.0), Vector3(-0.1, -0.15, 1.0)]
	var toe_curl: Array[float] = [0.1, 0.1]
	var head_up := 0.0
	var jaw := 0.05

	func blend(other: Pose, w: float) -> Pose:
		if w <= 0.0:
			return self
		if w >= 1.0:
			return other
		var p := Pose.new()
		p.pelvis = pelvis.lerp(other.pelvis, w)
		p.chest = chest.lerp(other.chest, w)
		p.front = front.slerp(other.front, w) if front.dot(other.front) > -0.9 else front.lerp(other.front, w).normalized()
		for i in 2:
			p.hands[i] = hands[i].lerp(other.hands[i], w)
			p.elbows[i] = elbows[i].lerp(other.elbows[i], w)
			p.curl[i] = lerpf(curl[i], other.curl[i], w)
			p.feet[i] = feet[i].lerp(other.feet[i], w)
			p.knees[i] = knees[i].lerp(other.knees[i], w)
			p.toes[i] = toes[i].lerp(other.toes[i], w)
			p.toe_curl[i] = lerpf(toe_curl[i], other.toe_curl[i], w)
		p.head_up = lerpf(head_up, other.head_up, w)
		p.jaw = lerpf(jaw, other.jaw, w)
		return p


## A point in the world in the node's own space, in units.
func _local(world: Vector3) -> Vector3:
	return (global_transform.affine_inverse() * world) / size


## Standing upright, still, its arms hanging out a little from its sides: as it is modelled.
func _standing() -> Pose:
	var p := Pose.new()
	p.pelvis = Vector3(0.0, 0.4, 0.0)
	p.chest = Vector3(0.0, 0.4 + SPINE, 0.02)
	p.hands = [Vector3(0.52, 0.2, 0.06), Vector3(-0.52, 0.2, 0.06)]
	p.elbows = [Vector3(0.4, 0.0, -1.0), Vector3(-0.4, 0.0, -1.0)]
	p.curl = [0.25, 0.25]
	p.feet = [Vector3(0.085, 0.045, 0.0), Vector3(-0.085, 0.045, 0.0)]
	return p


## Walking upright (the node at its feet): quick short steps on bent legs, the
## arms held up and out; stopped, standing with the arms down to the ground.
func _walking() -> Pose:
	var p := Pose.new()
	var m := _moving
	var breath := sin(_t * 2.4)
	for i in 2:
		var s := fposmod(_phase - 0.5 * i, 1.0)
		var sign := 1.0 if i == 0 else -1.0
		var foot := Vector3(0.085 * sign, 0.045, 0.0)
		var duty := 0.6
		var reach := 0.3
		if s < duty:
			foot.z += reach * (0.5 - s / duty) * m
		else:
			var k := (s - duty) / (1.0 - duty)
			foot.z += reach * (-0.5 + k * k * (3.0 - 2.0 * k)) * m
			foot.y += 0.07 * sin(PI * k) * m
		# (a little bowed, the feet turned out)
		foot.x += 0.02 * sign * m
		p.feet[i] = foot
		p.toes[i] = Vector3(0.25 * sign, -0.1, 1.0)
		p.knees[i] = Vector3(0.45 * sign, 0.0, 1.0)
	var bob := -cos(TAU * 2.0 * _phase) * 0.018 * m
	var sway := sin(TAU * _phase) * 0.025 * m
	p.pelvis = Vector3(sway, 0.385 + bob - 0.025 * m, 0.0)
	p.chest = p.pelvis + Vector3(sway * 0.4, SPINE - 0.01, 0.05 + 0.04 * m)
	p.chest.y += breath * 0.004
	p.front = Vector3(0.0, -0.1 * m, 1.0).normalized()
	# The arms: up and out for balance, swaying with the steps; still, hanging down.
	for i in 2:
		var sign := 1.0 if i == 0 else -1.0
		var step := sin(TAU * (_phase - 0.5 * i))
		var up := Vector3(0.36 * sign, 0.4 + 0.06 * step, -0.02 + 0.05 * step)
		var down := Vector3(0.13 * sign, -0.65, 0.12)
		var shoulder := p.chest + Vector3(SHOULDER * sign, 0.0, 0.0)
		p.hands[i] = shoulder + down.lerp(up, m)
		p.elbows[i] = Vector3(0.35 * sign, 0.0, -1.0).lerp(Vector3(sign, -0.6, -0.3), m)
		p.curl[i] = lerpf(0.35, 0.2, m)
	p.head_up = 0.05 - 0.05 * m
	return p


## Squatting on its haunches, knees up, an arm over a knee, the other hand down.
func _sat() -> Pose:
	var p := Pose.new()
	var breath := sin(_t * 2.0)
	p.pelvis = Vector3(0.0, 0.11, -0.06)
	p.chest = Vector3(0.0, 0.11 + SPINE * 0.97, 0.0 + breath * 0.003)
	p.front = Vector3(0.0, 0.1, 1.0).normalized()
	p.feet = [Vector3(0.1, 0.045, 0.16), Vector3(-0.1, 0.045, 0.16)]
	p.knees = [Vector3(0.4, 1.0, 0.5), Vector3(-0.4, 1.0, 0.5)]
	p.toes = [Vector3(0.2, -0.1, 1.0), Vector3(-0.2, -0.1, 1.0)]
	# (its arms wrapped round its knees, the long hands crossed in front of them)
	p.hands = [Vector3(-0.06, 0.24, 0.3), Vector3(0.06, 0.2, 0.31)]
	p.elbows = [Vector3(0.9, 0.1, 0.5), Vector3(-0.9, 0.1, 0.5)]
	p.curl = [0.6, 0.45]
	p.head_up = 0.1
	return p


## Hanging (the node at its holds), swinging hand over hand or hanging still.
func _hanging() -> Pose:
	var p := Pose.new()
	var hold := _local(_grips[_holding])
	var other := _local(_grips[1 - _holding])
	var dir := (global_basis.inverse() * _dir).normalized()
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3(0.0, 0.0, 1.0)
	var swing_len := _swing / size
	var along := -hold.dot(dir)
	var u := clampf(along / maxf(swing_len, 0.01) + 0.5, 0.0, 1.0)
	var sign := 1.0 if _holding == 0 else -1.0
	var m := _moving
	# The pendulum: its holding shoulder on a circle under the hold, lowest under it.
	var reach := REACH * 0.98
	var dz := clampf(along, -reach * 0.92, reach * 0.92)
	var drop := sqrt(reach * reach - dz * dz)
	var sway := sin(_t * 1.3) * 0.05 * (1.0 - m)
	var shoulder := hold + dir * dz + Vector3(sway * 0.4, -drop, sway)
	if away_from != Vector3.ZERO:
		# (against a wall: the body held out from its face, the arm slanting in to the edge)
		var off := global_basis.inverse() * away_from
		shoulder += Vector3(off.x, 0.0, off.z).normalized() * 0.16
	# The free hand: from where it let go, up and forward to the next hold.
	var next := hold + dir * swing_len
	var from := _local(_let_go)
	var e := smoothstep(0.1, 0.92, u) if m > 0.3 else 1.0
	var free := from.lerp(next, e) + Vector3.UP * 0.12 * sin(PI * e) * m
	if m <= 0.3:
		# (hanging still: the free arm loose, or holding on too)
		var loose := shoulder + Vector3(-0.08 * sign, -0.55, 0.12) + Vector3(0.0, 0.0, sin(_t * 1.1) * 0.05)
		free = loose.lerp(other, _two_hands)
	# The torso hangs from the holding shoulder, its top towards the hands, turning about the holding arm.
	var twist := 0.5 * cos(PI * u) * sign * m + 0.35 * sign * (1.0 - m) * (1.0 - _two_hands)
	var hands_mid := hold.lerp(free, 0.5 * m + 0.5 * _two_hands * (1.0 - m))
	var up := ((hands_mid - shoulder).normalized() * 0.45 + Vector3.UP * 0.55).normalized()
	var chest := shoulder - Basis(up, twist) * Vector3(SHOULDER * sign, 0.0, 0.0)
	chest = Vector3(chest.x, shoulder.y + 0.01, chest.z)
	var lag := Vector3(0.0, 0.0, 0.0)
	if m > 0.3:
		# (the legs lag behind the swing at the bottom and run ahead at its ends)
		lag = dir * -cos(PI * u) * 0.06 * m
	var pelvis := chest - up * SPINE + lag * 0.5
	p.chest = chest
	p.pelvis = pelvis
	var face := Basis(up, twist) * Vector3(dir.x, 0.0, dir.z)
	p.front = (face - up * face.dot(up)).normalized()
	var side := up.cross(p.front).normalized()
	p.hands = [Vector3.ZERO, Vector3.ZERO]
	p.hands[_holding] = hold
	p.hands[1 - _holding] = free
	p.elbows[_holding] = side * sign * 0.5 - p.front * 0.8
	p.elbows[1 - _holding] = -side * sign * 0.3 - p.front * 0.5 + Vector3.DOWN * 0.4 * (1.0 - m)
	p.curl[_holding] = 1.0
	p.curl[1 - _holding] = lerpf(0.4, 0.9, e * m + _two_hands * (1.0 - m))
	# The legs: knees drawn up, shins and long feet hanging; looser hanging still.
	var tuck := lerpf(0.35, 1.0, m)
	for i in 2:
		var s := 1.0 if i == 0 else -1.0
		var hip := pelvis + side * s * HIP
		var foot := hip + p.front * (0.2 * tuck) - up * lerpf(0.38, 0.22, tuck) + side * s * 0.03 + lag
		p.feet[i] = foot
		p.knees[i] = (p.front * 1.0 + up * 0.5 * tuck + side * s * 0.4).normalized()
		p.toes[i] = (Vector3.DOWN * 0.7 + p.front * 0.5 + side * s * 0.2).normalized()
		p.toe_curl[i] = 0.5 * tuck
	p.head_up = 0.15 + 0.15 * m
	p.jaw = 0.05
	return p


## Flying between holds (the node where its hands will take hold): both arms out ahead, legs tucked.
func _flying() -> Pose:
	var p := Pose.new()
	var dir := (global_basis.inverse() * _dir).normalized()
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3(0.0, 0.0, 1.0)
	var side := Vector3.UP.cross(dir).normalized()
	var up := (Vector3.UP * 0.7 + dir * 0.7).normalized()
	p.chest = -dir * 0.45 + Vector3.DOWN * 0.48
	p.pelvis = p.chest - up * SPINE
	p.front = (dir - up * dir.dot(up) + Vector3.DOWN * 0.4).normalized()
	p.hands = [side * 0.16 + dir * 0.05, -side * 0.16 + dir * 0.05]
	p.elbows = [side * 0.6 + Vector3.DOWN * 0.6, -side * 0.6 + Vector3.DOWN * 0.6]
	p.curl = [0.45, 0.45]
	for i in 2:
		var s := 1.0 if i == 0 else -1.0
		p.feet[i] = p.pelvis + p.front * 0.24 - up * 0.12 + side * s * 0.08
		p.knees[i] = (p.front + up * 0.6 + side * s * 0.3).normalized()
		p.toes[i] = (-up + p.front * 0.3).normalized()
		p.toe_curl[i] = 0.6
	p.head_up = 0.3
	p.jaw = 0.25
	return p


## The great call over whatever it is doing: head back, the jaw opening with
## each whoop, quickening; at the climax it shakes and flails.
func _calling(p: Pose) -> void:
	var k := call_progress()
	var w := smoothstep(0.0, 0.06, k) * (1.0 - smoothstep(0.93, 1.0, k))
	# (the whoops: slow at first, coming faster and faster)
	var notes := 3.0 * k + 9.0 * k * k
	var note := fposmod(notes, 1.0)
	var open := sin(PI * minf(note / 0.7, 1.0))
	p.head_up = lerpf(p.head_up, 0.65 + 0.15 * k, w)
	p.jaw = lerpf(p.jaw, 0.25 + 0.55 * open * (0.6 + 0.4 * k), w)
	var climax := smoothstep(0.62, 0.72, k) * (1.0 - smoothstep(0.9, 0.98, k))
	if climax <= 0.0:
		return
	var shake := sin(_t * 31.0) * 0.06 * climax
	p.chest += Vector3(shake, absf(shake) * 0.6, 0.0)
	p.pelvis += Vector3(-shake * 0.5, 0.0, 0.0)
	var flail := sin(_t * 13.0)
	if _w[Gait.HANG] > 0.5:
		var i := 1 - _holding
		var sign := 1.0 if i == 0 else -1.0
		var shoulder := p.chest + Vector3(SHOULDER * sign, 0.0, 0.0)
		p.hands[i] = p.hands[i].lerp(shoulder + Vector3(0.5 * sign, 0.25 + 0.3 * flail, 0.2 * flail), climax)
	else:
		for i in 2:
			var sign := 1.0 if i == 0 else -1.0
			var shoulder := p.chest + Vector3(SHOULDER * sign, 0.0, 0.0)
			p.hands[i] = p.hands[i].lerp(shoulder + Vector3(0.42 * sign, 0.5 + 0.12 * sin(_t * 13.0 + i * 2.0), 0.15), climax)
			p.elbows[i] = p.elbows[i].lerp(Vector3(sign, -0.4, -0.3), climax)


## The lunge over whatever it is doing: drawn back and up, mouth wide; then a
## swing at its mark feet first, the free hand out for it; then gathering itself.
func _lunging(p: Pose) -> void:
	var stage := lunge_stage()
	if stage == Lunge.NONE:
		return
	var k := lunge_progress()
	var mark := _local(_lunge_at)
	var hanging: float = _w[Gait.HANG]
	var pivot := p.hands[_holding] if hanging > 0.5 else p.pelvis
	var to := mark - pivot
	var flat := Vector3(to.x, 0.0, to.z)
	var away := -flat.normalized() if flat.length() > 0.01 else Vector3(0.0, 0.0, -1.0)
	var free := 1 - _holding if hanging > 0.5 else 0
	var drawn := 0.0
	var strike := 0.0
	match stage:
		Lunge.WIND_UP:
			drawn = smoothstep(0.0, 1.0, k)
		Lunge.STRIKE:
			drawn = 1.0 - smoothstep(0.0, 0.35, k)
			strike = smoothstep(0.0, 0.5, k) * (1.0 - smoothstep(0.85, 1.0, k) * 0.3)
		Lunge.RECOVER:
			strike = 0.7 * (1.0 - smoothstep(0.0, 1.0, k))
	# Drawn back: the body swung away from the mark and up, legs tucked, mouth wide.
	var back := away * 0.32 * drawn + Vector3.UP * 0.12 * drawn
	p.chest += back
	p.pelvis += back * 1.4 + Vector3.UP * 0.1 * drawn
	for i in 2:
		p.feet[i] += back * 1.5 + Vector3.UP * 0.12 * drawn
	p.jaw = maxf(p.jaw, 0.9 * drawn + 0.6 * strike)
	p.head_up = lerpf(p.head_up, 0.25, drawn)
	var sign := 1.0 if free == 0 else -1.0
	p.hands[free] = p.hands[free].lerp(p.chest + Vector3(0.3 * sign, 0.35, 0.0) + away * 0.25, drawn)
	if strike <= 0.0:
		return
	# The swing: the body out towards the mark, the feet and the free hand at it.
	var lean := to.limit_length(0.55 if hanging > 0.5 else 0.4) * strike
	p.chest += lean * 0.7
	p.pelvis += lean * 1.1
	var hip := p.pelvis
	for i in 2:
		var at := mark + Vector3(0.06 * (1.0 if i == 0 else -1.0), 0.0, 0.0)
		var leg := (at - hip).limit_length(LEG.x + LEG.y + 0.05)
		p.feet[i] = p.feet[i].lerp(hip + leg, strike)
		p.toe_curl[i] = lerpf(p.toe_curl[i], 0.1, strike)
	var arm := (mark - p.chest).limit_length(ARM.x + ARM.y + GRIP)
	p.hands[free] = p.hands[free].lerp(p.chest + arm, strike)
	p.curl[free] = lerpf(p.curl[free], 0.15, strike)


func _pose(delta: float) -> void:
	var p := _walking()
	if _sit > 0.0:
		p = p.blend(_sat(), smoothstep(0.0, 1.0, _sit))
	var hang: float = _w[Gait.HANG]
	var fly: float = _w[Gait.FLY]
	if hang > 0.0:
		p = p.blend(_hanging(), smoothstep(0.0, 1.0, hang / maxf(hang + _w[Gait.WALK], 0.001)))
	if fly > 0.0:
		p = p.blend(_flying(), smoothstep(0.0, 1.0, fly))
	if _call_left > 0.0:
		_calling(p)
	if _lunge != INF:
		_lunging(p)
	_look(p, delta)
	_apply(p)


## Where it looks: what it was given, or ahead going, or (still) about it.
func _look(p: Pose, delta: float) -> void:
	var want := Vector3(0.0, -0.05, 1.0)
	if look_at_point.is_finite():
		var from := p.chest + Vector3(0.0, 0.12, 0.0)
		want = (_local(look_at_point) - from).normalized()
		# (it turns its head a long way, but not right round)
		var front := Vector3(p.front.x, 0.0, p.front.z).normalized()
		if Vector3(want.x, 0.0, want.z).normalized().dot(front) < -0.2:
			want = (want + front * 0.9).normalized()
	elif _moving < 0.5:
		_scan_next -= delta
		if _scan_next <= 0.0:
			_scan_next = _rng.randf_range(0.7, 2.4)
			_scan = Vector3(_rng.randf_range(-1.3, 1.3), _rng.randf_range(-0.5, 0.3), 1.0)
		want = Basis(Vector3.UP, atan2(p.front.x, p.front.z)) * _scan.normalized()
	else:
		want = Vector3(p.front.x, -0.1, p.front.z).normalized()
	_gaze = _gaze.slerp(want, 1.0 - exp(-8.0 * delta)) if delta > 0.0 else want


# --- The skeleton ---

## Its bones. None is the child of another: each is posed straight in the
## skeleton's space (where its two ends are, worked out in `_joints`), so the
## mesh bends between them however the body is put.
const BONES: Array[String] = ["rump", "belly", "chest", "neck", "head", "jaw",
	"arm_l", "arm_r", "forearm_l", "forearm_r", "hand_l", "hand_r", "fingers_l", "fingers_r",
	"thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r", "toes_l", "toes_r"]
const RUMP := 0
const BELLY := 1
const CHEST := 2
const NECK := 3
const HEAD := 4
const JAW := 5
const ARM_U := 6
const ARM_L := 8
const PALM := 10
const FINGERS := 12
const LEG_U := 14
const LEG_L := 16
const FOOT_B := 18
const TOES := 20


## Where everything is, for a pose and a way of looking (units, the node's own space).
func _joints(p: Pose, gaze_dir: Vector3) -> Dictionary:
	var j := {}
	var up := (p.chest - p.pelvis).normalized()
	var front := p.front - up * p.front.dot(up)
	front = front.normalized() if front.length() > 0.01 else Vector3(0.0, 0.0, 1.0)
	var side := up.cross(front).normalized()
	var torso := Basis(side, up, front)
	j["torso"] = torso
	j["pelvis"] = p.pelvis
	j["chest"] = p.chest
	j["mid"] = p.pelvis.lerp(p.chest, 0.5) + front * 0.012
	j["rump"] = p.pelvis - up * 0.07 - front * 0.02
	var neck := p.chest + up * 0.055 + front * 0.012
	j["neck"] = neck
	var roots := PackedVector3Array()
	var mids := PackedVector3Array()
	var ends := PackedVector3Array()
	var tips := PackedVector3Array()
	var knuckles := PackedVector3Array()
	for i in 4:
		var arm := i < 2
		var k := i % 2
		var sign := 1.0 if k == 0 else -1.0
		if arm:
			var root := p.chest + side * sign * SHOULDER - up * 0.012
			var target := p.hands[k]
			var reach_dir := (target - root).normalized() if (target - root).length() > 0.001 else -up
			# (the wrist short of where the hooked fingers hold)
			var wrist := target - reach_dir * GRIP * lerpf(0.6, 0.8, p.curl[k])
			var mid := _bend(root, wrist, ARM.x, ARM.y, p.elbows[k])
			var end := mid + (wrist - mid).normalized() * ARM.y
			var forearm := (end - mid).normalized()
			# The hand: on from the forearm, then the fingers hooked over towards the palm.
			var palm_n := front - forearm * front.dot(forearm)
			palm_n = palm_n.normalized() if palm_n.length() > 0.05 else up.cross(forearm).normalized()
			var bend_axis := forearm.cross(palm_n).normalized()
			var hand_dir := forearm.rotated(bend_axis, 0.25 * p.curl[k])
			var knuckle := end + hand_dir * HAND.x
			var tip := knuckle + hand_dir.rotated(bend_axis, 1.6 * p.curl[k]) * HAND.y
			roots.append(root)
			mids.append(mid)
			ends.append(end)
			knuckles.append(knuckle)
			tips.append(tip)
		else:
			var root := p.pelvis + side * sign * HIP - up * 0.03
			var mid := _bend(root, p.feet[k], LEG.x, LEG.y, p.knees[k])
			var end := mid + (p.feet[k] - mid).normalized() * LEG.y
			var toes := p.toes[k].normalized()
			var ball := end + toes * FOOT.x
			# (curled towards the sole)
			var sole := side.cross(toes).normalized()
			var tip := ball + toes.lerp(sole, p.toe_curl[k] * 0.8).normalized() * FOOT.y
			roots.append(root)
			mids.append(mid)
			ends.append(end)
			knuckles.append(ball)
			tips.append(tip)
	j["roots"] = roots
	j["mids"] = mids
	j["ends"] = ends
	j["knuckles"] = knuckles
	j["tips"] = tips
	# The head, turned to look along `gaze_dir`, tipped up by `head_up`; the jaw.
	var flat_gaze := gaze_dir.normalized()
	var tipped := (Basis(flat_gaze.cross(Vector3.UP).normalized() if absf(flat_gaze.y) < 0.95 else Vector3.RIGHT, p.head_up) * flat_gaze).normalized()
	# (it turns its head on its neck: halfway between its body's up and the world's)
	var head_up := (up + Vector3.UP).normalized()
	var head_basis := Basis.looking_at(-tipped, head_up if absf(tipped.dot(head_up)) < 0.97 else front)
	var head_at := neck + head_up * 0.06 + tipped * 0.012
	var head := Transform3D(head_basis, head_at)
	j["head"] = head_at
	j["head_xform"] = head
	j["jaw_xform"] = Transform3D(head_basis * Basis(Vector3.RIGHT, p.jaw * 0.7), head * Vector3(0.0, -0.022, 0.012))
	return j


## Each bone's two ends, as a pair, or (head, jaw) its whole transform.
func _pairs(j: Dictionary) -> Array:
	var pairs := []
	pairs.resize(BONES.size())
	pairs[RUMP] = [j["rump"], j["pelvis"]]
	pairs[BELLY] = [j["pelvis"], j["mid"]]
	pairs[CHEST] = [j["mid"], j["chest"]]
	pairs[NECK] = [j["chest"], j["neck"]]
	pairs[HEAD] = j["head_xform"]
	pairs[JAW] = j["jaw_xform"]
	for i in 4:
		var arm := i < 2
		var k := i % 2
		pairs[(ARM_U if arm else LEG_U) + k] = [j["roots"][i], j["mids"][i]]
		pairs[(ARM_L if arm else LEG_L) + k] = [j["mids"][i], j["ends"][i]]
		pairs[(PALM if arm else FOOT_B) + k] = [j["ends"][i], j["knuckles"][i]]
		pairs[(FINGERS if arm else TOES) + k] = [j["knuckles"][i], j["tips"][i]]
	return pairs


## Keeps how each bone lies in the torso's frame as it stands, to pose it from.
func _keep_rest(j: Dictionary) -> void:
	var torso: Basis = j["torso"]
	var globals := _bone_globals(j)
	var pairs := _pairs(j)
	_rest_dir.resize(BONES.size())
	_rest_basis.resize(BONES.size())
	for b in BONES.size():
		_rest_basis[b] = torso.inverse() * globals[b].basis
		if pairs[b] is Array:
			_rest_dir[b] = torso.inverse() * ((pairs[b][1] as Vector3) - (pairs[b][0] as Vector3)).normalized()


## Each bone's transform (the node's space, units) for these joints. A bone
## between two points is turned from how it lay as it stood by the least turn
## that points it the new way (in the torso's frame), so it never twists round.
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
		var dir := (c - a) / maxf((c - a).length(), 0.0001)
		if _rest_dir.is_empty():
			out.append(Transform3D(_along(dir, torso.x), a))
			continue
		var turn := _arc(_rest_dir[b], torso.inverse() * dir)
		out.append(Transform3D(torso * Basis(turn) * _rest_basis[b], a))
	return out


## The least turn from `a` to `b` (both unit).
static func _arc(a: Vector3, b: Vector3) -> Quaternion:
	var d := a.dot(b)
	if d < -0.9995:
		var axis := a.cross(Vector3.RIGHT)
		if axis.length() < 0.1:
			axis = a.cross(Vector3.UP)
		return Quaternion(axis.normalized(), PI)
	var c := a.cross(b)
	return Quaternion(c.x, c.y, c.z, 1.0 + d).normalized()


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
	var along := to.normalized() if to.length() > 0.0001 else Vector3.DOWN
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
		var moved := globals[b] * _rest[b].affine_inverse()
		var g := _skeleton_from_model * moved * _skeleton_from_model.affine_inverse() * _model_rest[b]
		var bone := _index[b]
		var parent := _skeleton.get_bone_parent(bone)
		if parent >= 0:
			g = _skeleton.get_bone_global_pose(parent).affine_inverse() * g
		_skeleton.set_bone_pose_position(bone, g.origin)
		_skeleton.set_bone_pose_rotation(bone, g.basis.get_rotation_quaternion())
	# Where it can take hold of something: the free hand, and the feet.
	var to_world := _model.global_transform
	var free := 1 - _holding if _w[Gait.HANG] > 0.5 else 0
	_grabbers = PackedVector3Array([to_world * (j["tips"][free] as Vector3), to_world * (j["tips"][2] as Vector3), to_world * (j["tips"][3] as Vector3)])


# --- Sounds ---

func _play(stream: AudioStream, pitch := 1.0) -> void:
	if _voice == null or not _voice.is_inside_tree():
		return
	_voice.stream = stream
	_voice.pitch_scale = pitch
	_voice.play()


## The great call: a run of hooting whoops, each sliding up, the run rising in
## pitch and coming faster, to a trill at the top, then a few falling hoots.
static func call_sound() -> AudioStreamWAV:
	if _call_sound:
		return _call_sound
	var rate := 22050
	var count := int(rate * CALL_TIME)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var samples := PackedFloat32Array()
	samples.resize(count)
	var breath := Band.new(1400.0, 1.2, rate)
	var loudest := 0.0
	# The notes: [start, length, from Hz, to Hz, loudness].
	var notes: Array = []
	var t := 0.05
	while t < CALL_TIME * 0.72:
		var x := t / (CALL_TIME * 0.72)
		var length := lerpf(0.42, 0.11, x)
		notes.append([t, length * 0.82, lerpf(420.0, 820.0, x), lerpf(700.0, 1350.0, x), lerpf(0.55, 1.0, x)])
		t += length
	# (the trill at the climax)
	for n in 9:
		notes.append([t, 0.06, 1250.0, 1500.0, 0.9])
		t += 0.07
	# (and falling hoots to end it)
	for n in 3:
		notes.append([t + 0.08, 0.24, 900.0 - n * 120.0, 650.0 - n * 120.0, 0.6 - n * 0.12])
		t += 0.3
	# (each note written into its own stretch only)
	for note: Array in notes:
		var start := int(float(note[0]) * rate)
		var length := maxi(int(float(note[1]) * rate), 1)
		var phase := 0.0
		for n in length:
			var i := start + n
			if i >= count:
				break
			var u := float(n) / length
			# (a hoot that swoops up: a low "hoo", then a quick rise)
			var pitch := lerpf(note[2], note[3], smoothstep(0.15, 0.85, u))
			var loud := sin(PI * u) * float(note[4])
			phase += pitch * (1.0 + 0.006 * sin(TAU * 5.5 * float(i) / rate)) / rate
			samples[i] += (sin(TAU * phase) + 0.18 * sin(TAU * phase * 2.0) + 0.05 * sin(TAU * phase * 3.0)) * loud \
					+ breath.run(rng.randf_range(-1.0, 1.0)) * 0.12 * loud
	for i in count:
		samples[i] = tanh(samples[i] * 1.2)
		loudest = maxf(loudest, absf(samples[i]))
	_call_sound = _wav(samples, loudest, rate)
	return _call_sound


## The shriek before it lunges: a harsh rising "waa".
static func shriek_sound() -> AudioStreamWAV:
	if _shriek_sound:
		return _shriek_sound
	var rate := 22050
	var length := 0.55
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 34
	var samples := PackedFloat32Array()
	samples.resize(count)
	var throat := Band.new(1600.0, 3.0, rate)
	var rasp := Band.new(2600.0, 2.0, rate)
	var phase := 0.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var u := t / length
		var pitch := lerpf(700.0, 1250.0, smoothstep(0.0, 0.5, u)) - 250.0 * smoothstep(0.6, 1.0, u)
		phase += pitch / rate
		var pulse := pow(1.0 - fposmod(phase, 1.0), 2.0) * 2.0 - 0.6
		var loud := smoothstep(0.0, 0.06, u) * (1.0 - smoothstep(0.7, 1.0, u))
		var value := (throat.run(pulse) * 1.4 + rasp.run(rng.randf_range(-1.0, 1.0)) * 0.6 + sin(TAU * phase) * 0.3) * loud
		value = tanh(value * 2.0)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_shriek_sound = _wav(samples, loudest, rate)
	return _shriek_sound


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
	var _x1 := 0.0
	var _x2 := 0.0
	var _y1 := 0.0
	var _y2 := 0.0

	func _init(frequency: float, q: float, rate: int) -> void:
		_rate = rate
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

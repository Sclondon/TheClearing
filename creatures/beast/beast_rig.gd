class_name BeastRig
extends CharacterRig
## How the beast moves: the boy's figure (models/boy.glb) on the boy's rig, drawn
## far taller and black, so CharacterRig walks it (slowly, stooped, nothing loose
## about it); this lays over that what it does with its lantern and its long
## hands (`_pose_extra`). Its body (`Beast`, beast.gd) is this node's parent and
## says how fast it goes, what it looks at (`aim`) and how far its lantern is held
## out (`lure`); it starts the reach with `act`.
##
## - Its lantern hangs from its right fist, held a little out before it; LURING,
##   it is held up and out at whoever it lures, swaying slowly from side to side,
##   as a light is swung to call someone in the dark.
## - Its other arm hangs long at its side, the fingers apart.
## - Its head turns slowly to what it looks at, tipped over to one side, curious.
## - THE REACH: both arms drawn up and out, the head tipped right over (WIND: the
##   warning), then flung forward at whoever is there, the hands closing (GRAB),
##   held a moment (HOLD) and let fall (DROP).

enum Act { NONE, REACH }
enum Stage { NONE, WIND, GRAB, HOLD, DROP }

## Seconds each part takes.
const WIND := 0.95
const GRAB := 0.22
const HOLD := 0.5
const DROP := 0.6

## What it looks at, in the world (INF: nothing).
var aim := Vector3.INF
## How far its lantern is held out at `aim`, 0..1 (eased).
var lure := 0.0

var _doing := Act.NONE
var _doing_time := INF
var _gaze := Vector2.ZERO
var _lured := 0.0


func act(what: Act) -> void:
	_doing = what
	_doing_time = 0.0 if what != Act.NONE else INF


func act_time() -> float:
	return _doing_time


func stage() -> Stage:
	var t := _doing_time
	if _doing == Act.REACH:
		if t < WIND:
			return Stage.WIND
		if t < WIND + GRAB:
			return Stage.GRAB
		if t < WIND + GRAB + HOLD:
			return Stage.HOLD
		if t < WIND + GRAB + HOLD + DROP:
			return Stage.DROP
	return Stage.NONE


func _notice() -> void:
	_interest = null
	_interest_is_threat = false


func _pose_extra(delta: float) -> void:
	if _doing != Act.NONE:
		_doing_time += delta
		if stage() == Stage.NONE:
			_doing = Act.NONE
			_doing_time = INF
	var t := _doing_time
	var frame := global_basis.orthonormalized()
	var wind := 0.0
	var grab := 0.0
	if _doing == Act.REACH:
		wind = smoothstep(0.0, WIND * 0.8, t) * (1.0 - smoothstep(WIND, WIND + GRAB, t))
		grab = smoothstep(WIND, WIND + GRAB, t) * (1.0 - smoothstep(WIND + GRAB + HOLD, WIND + GRAB + HOLD + DROP, t))

	var mark := Vector3(0.0, 0.8, 6.0)
	if aim.is_finite():
		mark = to_local(aim)
	var shoulder_r := to_local(_shoulders[1].global_position)
	var shoulder_l := to_local(_shoulders[0].global_position)
	var at_aim := (mark - Vector3(0.0, 0.85, 0.0)).normalized()
	if at_aim.z < 0.3:
		at_aim = Vector3(at_aim.x, at_aim.y, 0.3).normalized()

	# --- The body: drawn up to reach, flung forward ---
	var lean := -0.12 * wind + 0.4 * grab
	_hips.position += Vector3(0.0, 0.02 * wind, 0.04 * grab)
	_spine.rotate_object_local(Vector3.RIGHT, lean * 0.5)
	if _chest:
		_chest.rotate_object_local(Vector3.RIGHT, lean * 0.5)

	# --- Its head: slowly on what it looks at, tipped over to one side ---
	var look := Vector2.ZERO
	if aim.is_finite():
		var to := mark - Vector3(0.0, 1.1, 0.0)
		look = Vector2(clampf(atan2(to.x, to.z), -1.2, 1.2), clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.7, 0.7))
	_gaze = _gaze.lerp(look, 1.0 - exp(-2.0 * delta))
	var tilt := 0.22 + 0.08 * sin(_time * 0.4) + 0.35 * wind
	var held := 1.0 if aim.is_finite() else 0.0
	if _neck:
		_neck.rotation = Vector3(lerpf(_neck.rotation.x, _gaze.y * 0.45, held), lerpf(_neck.rotation.y, _gaze.x * 0.4, held), _neck.rotation.z + tilt * 0.4)
	_head.rotation = Vector3(lerpf(_head.rotation.x, _gaze.y * 0.55, held) - lean * 0.3, lerpf(_head.rotation.y, _gaze.x * 0.6, held), _head.rotation.z + tilt * 0.6)

	# --- The lantern, in its right fist ---
	_lured = _approach(_lured, clampf(lure, 0.0, 1.0), 1.5, delta)
	var moving := clampf(_move * 1.4, 0.0, 1.0)
	var step := sin(TAU * _phase)
	var low := Vector3(-0.2, 0.56 + 0.01 * absf(step) * moving, 0.18)
	# (held up and out at them, swung slowly from side to side: come)
	var sway := sin(_time * 1.3) * 0.12
	var held_out := shoulder_r + (Vector3(at_aim.x * 0.5 - 0.15 + sway, at_aim.y * 0.5 + 0.12, at_aim.z)).normalized() * 0.37
	var lamp_at := low.lerp(held_out, _lured)
	lamp_at = lamp_at.lerp(shoulder_r + Vector3(-0.3, 0.1, 0.05), wind).lerp(shoulder_r + Vector3(-0.15, -0.05, 0.3), grab)
	_solve_arm(1, -1.0, to_global(lamp_at), _forearm + 0.06, 1.0, (frame * Vector3(-0.7, -0.8, -0.4)).normalized())
	_curl[1] = 1.0
	_splay[1] = 0.05
	_pose_fingers(1, -1.0)

	# --- Its other hand: hanging long; drawn up, then flung at them ---
	var reach := maxf(wind, grab)
	if reach > 0.01:
		var up := shoulder_l + Vector3(0.28, 0.2, 0.05)
		var out := shoulder_l + (at_aim + Vector3(-0.1, 0.05, 0.0)).normalized() * 0.42
		_solve_arm(0, 1.0, to_global(up.lerp(out, grab)), _forearm + 0.08, reach, (frame * Vector3(0.7, -0.6, -0.4)).normalized())
		_curl[0] = lerpf(0.1, 0.9, grab)
		_splay[0] = lerpf(1.0, 0.2, grab)
	else:
		_curl[0] = 0.35
		_splay[0] = 0.8
	_pose_fingers(0, 1.0)


## Where its lantern hangs from: its right fist, in the world.
func lantern_hold() -> Vector3:
	return _hands[1].global_transform * Vector3(0.0, -PALM - 0.03, 0.0)


## Where its reaching hand is, in the world.
func hand_point() -> Vector3:
	return _hands[0].global_transform * Vector3(0.0, -PALM * 2.0, 0.0)

class_name DrivenBoy
extends Player
## The boy steered by code instead of by a thumb: someone else in the level (an
## NPC) on the very same character controller and rig as the player, so that he
## runs, sprints, jumps, climbs ladders and takes his falls exactly as the player
## does, and looks it.
##
## Make one with `DrivenBoy.make()` (or `make(SomeScript)` for a script that
## extends this one): it is player.tscn with this script on the body and a
## GestureRig on its Rig, so he can also beckon, wave and point. Then steer him:
##
##     boy.steer(point, DrivenBoy.Pace.RUN)   # each physics step: towards a point
##     boy.move = direction                   # or by hand: level, world space, length 0..1
##     boy.sprint = true                      # with `move`, at a sprint
##     boy.jump()
##     boy.climb = 1.0                        # on a ladder: up (1), down (-1), still (0)
##     boy.face(point)                        # stood still, turn to it
##     boy.gesture(GestureRig.Gesture.BECKON) # and NONE to stop
##
## How he gets there is his steerer's business (a navmesh, a grid, waypoints):
## this only turns "go that way, this fast" into what a stick and buttons would
## have done. Walking into a ladder takes hold of it, as it does for the player.
## `stuck_time` says how long he has been pushing without getting anywhere.
##
## Over a network: the machine that steers him sends `state_bytes()` (what he is
## told to do as well as where he is) and the others feed it to a copy with
## `puppet` set, through `from_bytes`. The copy is steered with the same inputs,
## so it climbs, jumps and falls as he does and is posed alike, and is drawn back
## to where he really is when it strays.
##
## He takes nothing from the keys, pads or touch. `hold(seconds)` stops him dead
## (as something that paralyses a player would).

enum Pace { STILL, WALK, JOG, RUN, SPRINT }
## How far a stick would be pushed for each pace.
const PACE_PUSH: Array[float] = [0.0, 0.4, 0.66, 1.0, 1.0]
## Bytes in `state_bytes`.
const STATE_SIZE := 30
## As a puppet: further than this from where he is said to be, he is put there.
const SNAP_DISTANCE := 3.0

## Which way he is to go, level, in the world; its length is how hard (0..1, as
## far as a stick is pushed).
var move := Vector3.ZERO
## Sprint held (with `move` pushed past a walk).
var sprint := false
## Duck held.
var duck := false
## On a ladder: up (1) or down (-1) it, or still (0).
var climb := 0.0
## Whether he catches ropes he passes in the air (off: they are only for players).
var catches_ropes := false
## Run by another machine: steered only by what `from_bytes` hears.
var puppet := false
## How long he has been pushing (on the ground, not on a ladder) without getting anywhere, seconds.
var stuck_time := 0.0

var _face_at := Vector3.INF
var _held := 0.0
var _jump_hold := 0.0
var _jumps := 0
# What he was last heard to be doing, as a puppet.
var _heard := false
var _heard_at := Vector3.ZERO
var _heard_moving := Vector3.ZERO
var _heard_yaw := 0.0
var _heard_state := 0
var _heard_jumps := 0
var _astray := 0.0


## A new one: player.tscn with `script` (DrivenBoy, or one that extends it) on
## the body and a GestureRig on its Rig. Add it to the scene as any node.
static func make(script: Script = null) -> DrivenBoy:
	var boy: Node = (load("res://player.tscn") as PackedScene).instantiate()
	boy.get_node(^"Rig").set_script(GestureRig)
	boy.set_script(script if script else load("res://scripts/driven_boy.gd"))
	return boy as DrivenBoy


func _ready() -> void:
	takes_input = false
	# (a stick that only ever points where it is going: no sprinting by itself, and
	# none of the moves that come of whipping it round or of ducking in the air)
	auto_sprint = false
	spin_enabled = false
	dive_enabled = false
	flip_enabled = false
	sleep_after = 0.0
	sit_hold = 0.0
	super()


## Towards `point` (level) at `pace`: call it each physics step he is to go on.
func steer(point: Vector3, pace := Pace.RUN) -> void:
	var to := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	if pace == Pace.STILL or to.length() < 0.05:
		move = Vector3.ZERO
		sprint = false
		return
	# (slowing to a walk for the last metre, so as to stop on it)
	move = to.normalized() * PACE_PUSH[pace] * clampf(to.length() / 0.8, 0.45, 1.0)
	sprint = pace == Pace.SPRINT


## Stands still (and lets go of sprint and duck).
func halt() -> void:
	move = Vector3.ZERO
	sprint = false
	duck = false
	climb = 0.0


## Jump, as the button pressed once.
func jump() -> void:
	_jumps = (_jumps + 1) & 0xff
	_jump_hold = 0.3
	_queue_jump()


## Stood still, he turns to face `point` (Vector3.INF: he does not).
func face(point: Vector3) -> void:
	_face_at = point


## Beckons, waves or points (GestureRig), or stops (NONE). `way` is where to point.
func gesture(which: GestureRig.Gesture, way := Vector3.ZERO) -> void:
	var rig := _rig as GestureRig
	if rig:
		rig.gesture = which
		if way != Vector3.ZERO:
			rig.point_way = way


func gesturing() -> GestureRig.Gesture:
	var rig := _rig as GestureRig
	return rig.gesture if rig else GestureRig.Gesture.NONE


## Stops him where he is for `seconds` (as a ghoul's shriek holds a player).
func hold(seconds: float) -> void:
	_held = maxf(_held, seconds)
	velocity.x *= 0.2
	velocity.z *= 0.2


func is_held() -> bool:
	return _held > 0.0


# --- His inputs, from code ---------------------------------------------------

func _listening() -> bool:
	return false


func _read_move_input() -> Vector2:
	if _held > 0.0:
		return Vector2.ZERO
	# (on a ladder, up the stick is up it)
	if state == State.LADDER:
		return Vector2(0.0, -climb)
	var push := move.limit_length(1.0)
	return Vector2(push.x, push.z)


## The stick is already in the world (see `_read_move_input`), not the camera's view.
func _to_world(input: Vector2) -> Vector3:
	return Vector3(input.x, 0.0, input.y).limit_length(1.0)


func _is_sprint_held() -> bool:
	return sprint and _held <= 0.0


func _is_duck_held() -> bool:
	return duck and _held <= 0.0


func _is_jump_held() -> bool:
	return _jump_hold > 0.0


func _is_act_held() -> bool:
	return false


func _try_catch_rope() -> bool:
	return catches_ropes and super()


func _physics_process(delta: float) -> void:
	_held = maxf(_held - delta, 0.0)
	_jump_hold -= delta
	var before := global_position
	super(delta)
	if puppet:
		_follow(delta)
	var pushing := move.length() > 0.2 and state == State.FREE and not is_limp and _held <= 0.0
	var went := Vector2(global_position.x - before.x, global_position.z - before.z).length() / maxf(delta, 0.0001)
	stuck_time = stuck_time + delta if pushing and went < 0.35 else 0.0


func _process(delta: float) -> void:
	# Stood still, he turns to what he was told to face.
	if _face_at.is_finite() and state == State.FREE and not is_limp and Vector2(velocity.x, velocity.z).length() < 0.6:
		var to := _face_at - global_position
		if Vector2(to.x, to.z).length() > 0.2:
			facing_yaw = lerp_angle(facing_yaw, atan2(to.x, to.z), 1.0 - exp(-7.0 * delta))
	super(delta)


# --- Over a network ------------------------------------------------------------

## What he is doing, in STATE_SIZE bytes: where he is (3 floats), how fast he
## is going (3 halves), the stick (2 halves), what is held (sprint, duck, limp,
## the ladder), how many jumps, which way he faces, his gesture and where it
## points, and his State.
func state_bytes() -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(STATE_SIZE)
	var at := global_position
	data.encode_float(0, at.x)
	data.encode_float(4, at.y)
	data.encode_float(8, at.z)
	data.encode_half(12, velocity.x)
	data.encode_half(14, velocity.y)
	data.encode_half(16, velocity.z)
	data.encode_half(18, move.x)
	data.encode_half(20, move.z)
	var flags := (1 if sprint else 0) | (2 if duck else 0) | (4 if is_limp else 0) | (8 if climb > 0.1 else 0) | (16 if climb < -0.1 else 0) | (32 if _held > 0.0 else 0)
	data[22] = flags
	data[23] = _jumps
	data.encode_u16(24, int(fposmod(facing_yaw, TAU) / TAU * 65535.0))
	var rig := _rig as GestureRig
	data[26] = rig.gesture if rig else 0
	var way := rig.point_way if rig else Vector3.FORWARD
	data[27] = int(fposmod(atan2(way.x, way.z), TAU) / TAU * 255.0)
	data[28] = state
	data[29] = 0
	return data


## As a puppet: hears a `state_bytes` (from `offset` in `data`).
func from_bytes(data: PackedByteArray, offset := 0) -> void:
	if data.size() < offset + STATE_SIZE:
		return
	var at := Vector3(data.decode_float(offset), data.decode_float(offset + 4), data.decode_float(offset + 8))
	_heard_moving = Vector3(data.decode_half(offset + 12), data.decode_half(offset + 14), data.decode_half(offset + 16))
	move = Vector3(data.decode_half(offset + 18), 0.0, data.decode_half(offset + 20))
	var flags := data[offset + 22]
	sprint = flags & 1 != 0
	duck = flags & 2 != 0
	climb = 1.0 if flags & 8 != 0 else (-1.0 if flags & 16 != 0 else 0.0)
	if flags & 32 != 0:
		_held = maxf(_held, 0.15)
	var limp := flags & 4 != 0
	if limp and not is_limp:
		ragdoll(_heard_moving)
	elif not limp and is_limp:
		recover()
		_snap(at)
	var jumps := data[offset + 23]
	if _heard and jumps != _heard_jumps and not limp:
		jump()
	_heard_jumps = jumps
	_jumps = jumps
	_heard_yaw = data.decode_u16(offset + 24) / 65535.0 * TAU
	var angle := data[offset + 27] / 255.0 * TAU
	gesture(data[offset + 26] as GestureRig.Gesture, Vector3(sin(angle), 0.0, cos(angle)))
	_heard_state = data[offset + 28]
	_heard_at = at
	if not _heard:
		_snap(at)
		facing_yaw = _heard_yaw
	_heard = true


## As a puppet: drawn back towards where he is said to be (carried on as he was
## going since), put there if he is far off, and on or off a ladder as he is.
func _follow(delta: float) -> void:
	if not _heard or is_limp:
		return
	if state != State.LADDER:
		_heard_at += _heard_moving * delta
	var off := _heard_at - global_position
	if off.length() > SNAP_DISTANCE:
		_snap(_heard_at)
		return
	if state == _heard_state:
		_astray = 0.0
	else:
		_astray += delta
	if _astray > 0.5:
		_astray = 0.0
		if _heard_state == State.LADDER and state != State.LADDER:
			_onto_nearest_ladder()
		elif state == State.LADDER and _heard_state != State.LADDER:
			_leave_ladder()
	# (stood still, he comes round the way he is said to face)
	if move.length_squared() < 0.01 and state == State.FREE and not _face_at.is_finite():
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-6.0 * delta))
	var pull := off * minf(1.0, 3.0 * delta)
	if state == State.LADDER:
		pull = Vector3(0.0, pull.y, 0.0)
	_put(global_position + pull)


## Puts him straight at `at`, as he is, without easing.
func _snap(at: Vector3) -> void:
	if state == State.LADDER:
		_leave_ladder()
	elif state == State.ROPE:
		_leave_rope()
	global_position = at
	_reset_visuals()


## Takes hold of the ladder nearest him, if there is one at hand.
func _onto_nearest_ladder() -> void:
	var best: Ladder = null
	var near := 1.5
	for ladder: Ladder in get_tree().get_nodes_in_group(&"ladders"):
		var y := clampf(global_position.y, ladder.bottom_y(), ladder.top_y() - 0.6)
		var d := global_position.distance_to(ladder.stand(y))
		if d < near:
			near = d
			best = ladder
	if best == null:
		return
	_ladder = best
	_engage()
	ladder_travel = 0.0
	velocity = Vector3.ZERO
	ladder_off = 0.0
	_ladder_leaving = 0.0
	state = State.LADDER
	_state_time = 0.0
	_put(best.stand(clampf(global_position.y, best.bottom_y(), best.top_y() - 0.6)))

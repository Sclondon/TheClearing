class_name GhoulRig
extends CharacterRig
## How a ghoul (creatures/ghoul/models/ghoul.glb) moves: the whole figure is
## posed here, over CharacterRig (see `_pose_extra`); nothing of the boy's walk
## is kept. Its body (`Ghoul`, ghoul.gd) is this node's parent and says how fast
## it is going (`velocity`), how awake it is (`awake`) and what it is looking at
## (`aim`); and it starts the two things it does, `act(Act.SCREAM)` and
## `act(Act.GRAB)`.
##
## - ASLEEP (awake 0) it is a statue: slightly bowed, its arms hanging dead
##   straight, its head down. It does not breathe. Now and then its head jerks
##   to one side and slowly comes back.
## - AWAKE it shuffles: short, stiff steps whose feet hardly leave the ground,
##   toes turned out and scraping, its body rocking from side to side over each
##   foot and its arms swinging from the shoulders like weights on strings. It
##   leans towards what it is after, its head held up to look at it; near to,
##   its arms come up to take hold.
## - THE SCREAM: it straightens, throws its head right back so that its open
##   mouth is to the sky, arches its back and spreads its arms down and out with
##   the fingers splayed, and shudders all over while it shrieks (SCREAM_RISE,
##   SCREAMING, SCREAM_FALL).
## - THE GRAB: both arms are thrown up and wide as it leans in (REACH), then
##   brought round together in front of its chest (CLOSE: the moment it takes
##   hold, if anything is there); if it has someone (`held`), it clings to them
##   and grinds against them (HOLD), else it is left hugging the air; then it
##   lets go and straightens up (LET_GO).
##
## Its joints are the mummy's and the boy's (the same bone names), so any figure
## built on them can be moved by it.

enum Act { NONE, SCREAM, GRAB }
enum Stage { NONE, SCREAM_RISE, SCREAMING, SCREAM_FALL, REACH, CLOSE, HOLD, LET_GO }

## Seconds each part of a scream and of a grab takes.
const SCREAM_RISE := 0.3
const SCREAMING := 0.85
const SCREAM_FALL := 0.4
const REACH := 0.4
const CLOSE := 0.18
const HOLD := 1.1
const LET_GO := 0.55
## One whole cycle of its shuffle (two steps), as modelled, and the share of it
## each foot is off the ground.
const STRIDE := 0.44
const SWING := 0.44

## How awake it is, 0 (a statue) to 1. The body sets this.
var awake := 0.0
## What it is after, in the world; INF for nothing.
var aim := Vector3.INF
## In a grab: whether it has hold of someone (it clings) or missed (it hugs the air).
var held := false

var _doing := Act.NONE
var _doing_time := INF
var _wake := 0.0
var _cycle := 0.0
var _trod := false
var _posed := false
var _was_at := Vector3.INF
var _yaw_was := 0.0
## Each foot: where it is on the ground (in the rig's space, as modelled), where
## a step takes it from and to, whether it is stepping, and how it is held.
var _foot_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_to: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_moving: Array[bool] = [false, false]
var _foot_swing: Array[float] = [-1.0, -1.0]
var _foot_began: Array[float] = [0.0, 0.0]
var _foot_lift: Array[float] = [0.0, 0.0]
var _foot_toes: Array[float] = [0.0, 0.0]
var _foot_turn: Array[float] = [0.0, 0.0]
## Each hand, a weight on a spring (rig space).
var _hand_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _hand_speed: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
## Which way its head is turned to look (to the side, down), and how it rocks
## (on springs: (where, how fast)).
var _gaze := Vector2.ZERO
var _rocking := Vector2.ZERO
var _nodding := Vector2.ZERO
## A jerk of the head: how much is left of it, which way, and when the next comes.
var _twitch := 0.0
var _twitch_way := 1.0
var _twitch_in := 3.0
var _own_dust: Dust


func _build() -> void:
	# (the boy's footfalls are not its own: it raises its own dust)
	dusty = false
	super()
	_own_dust = Dust.new()
	add_child(_own_dust)
	settle()


## Stands it still as it is, nothing in motion: for when it is put somewhere.
func settle() -> void:
	_doing = Act.NONE
	_doing_time = INF
	_cycle = 0.0
	_wake = awake
	_posed = false
	_was_at = Vector3.INF
	_yaw_was = rotation.y
	_rocking = Vector2.ZERO
	_nodding = Vector2.ZERO
	for i in 2:
		_foot_at[i] = _standing(i)
		_foot_moving[i] = false
		_foot_swing[i] = -1.0


## Begins a scream or a grab (anything it was doing is cut short).
func act(what: Act) -> void:
	_doing = what
	_doing_time = 0.0 if what != Act.NONE else INF
	held = false


## The whole length of what it is doing, seconds.
func act_length(what: Act) -> float:
	match what:
		Act.SCREAM:
			return SCREAM_RISE + SCREAMING + SCREAM_FALL
		Act.GRAB:
			return REACH + CLOSE + HOLD + LET_GO
	return 0.0


## How far into what it is doing it is, seconds (INF: doing nothing).
func act_time() -> float:
	return _doing_time


func stage() -> Stage:
	var t := _doing_time
	match _doing:
		Act.SCREAM:
			if t < SCREAM_RISE:
				return Stage.SCREAM_RISE
			if t < SCREAM_RISE + SCREAMING:
				return Stage.SCREAMING
			if t < SCREAM_RISE + SCREAMING + SCREAM_FALL:
				return Stage.SCREAM_FALL
		Act.GRAB:
			if t < REACH:
				return Stage.REACH
			if t < REACH + CLOSE:
				return Stage.CLOSE
			if t < REACH + CLOSE + HOLD:
				return Stage.HOLD
			if t < REACH + CLOSE + HOLD + LET_GO:
				return Stage.LET_GO
	return Stage.NONE


## Where a foot stands when it is going nowhere: close together, toes out.
func _standing(i: int) -> Vector3:
	return Vector3((_hip_width + 0.006) * (1.0 if i == 0 else -1.0), 0.0, 0.01 if i == 0 else -0.012)


static func _sprung(spring: Vector2, to: float, stiffness: float, damping: float, delta: float) -> Vector2:
	spring.y += ((to - spring.x) * stiffness - spring.y * damping) * delta
	spring.x += spring.y * delta
	return spring


func _pose_extra(delta: float) -> void:
	var turned := angle_difference(_yaw_was, rotation.y)
	_yaw_was = rotation.y
	_wake = _approach(_wake, awake, 3.0, delta)
	if _doing != Act.NONE:
		_doing_time += delta
		if _doing_time >= act_length(_doing):
			_doing = Act.NONE
			_doing_time = INF
	var t := _doing_time
	var going := _gone(delta)
	var go := clampf(going.length() / 0.35, 0.0, 1.0) * (1.0 - _air)

	# How far into each of the things it does, 0..1, rising and falling.
	var scream := 0.0
	var shudder := 0.0
	var reach := 0.0
	var closed := 0.0
	var clinging := 0.0
	if _doing == Act.SCREAM:
		scream = smoothstep(0.0, SCREAM_RISE, t) * (1.0 - smoothstep(SCREAM_RISE + SCREAMING, act_length(Act.SCREAM), t))
		shudder = smoothstep(SCREAM_RISE * 0.6, SCREAM_RISE, t) * (1.0 - smoothstep(SCREAM_RISE + SCREAMING - 0.1, SCREAM_RISE + SCREAMING + 0.15, t))
	elif _doing == Act.GRAB:
		var out := 1.0 - smoothstep(REACH + CLOSE + HOLD, act_length(Act.GRAB), t)
		reach = smoothstep(0.0, REACH * 0.8, t) * out
		closed = smoothstep(REACH, REACH + CLOSE, t) * out
		clinging = closed * (1.0 if held else 0.0)

	_tread(going, turned, go, delta)
	_shape_steps(go)

	# --- The body ---
	var swing_side := sin(_cycle * TAU)
	_rocking = _sprung(_rocking, go * swing_side * 0.11, 70.0, 6.0, delta)
	_nodding = _sprung(_nodding, go * (0.06 + 0.03 * absf(swing_side)), 50.0, 6.0, delta)
	# Its head jerks now and then, most of all while it stands.
	_twitch_in -= delta
	if _twitch_in <= 0.0:
		_twitch_in = randf_range(2.5, 7.0) * (1.0 if _wake < 0.5 else 1.6)
		_twitch = 1.0
		_twitch_way = -1.0 if randf() < 0.5 else 1.0
	_twitch = maxf(_twitch - delta * 1.4, 0.0)
	var jerk := _twitch_way * pow(_twitch, 3.0) * 0.45 * (1.0 - scream)

	var hunch := lerpf(0.2, 0.42, _wake) * (1.0 - scream) + 0.35 * reach - 0.1 * closed
	var arch := 0.42 * scream
	var tremble := Vector3(sin(_time * 53.0), sin(_time * 61.0 + 1.3), sin(_time * 47.0 + 2.1)) * shudder
	# (clinging, it grinds against them)
	var grind := sin(_time * 9.0) * clinging
	var bend := _wake * 0.06 + 0.04 * reach + 0.05 * scream
	var height := _hip_height - bend - 0.008 * absf(swing_side) * go + 0.02 * scream - 0.03 * clinging
	_hips.position = Vector3(_rocking.x * 0.12 + tremble.x * 0.004, height, 0.05 * reach + 0.06 * closed + 0.02 * grind - 0.03 * scream)
	_hips.rotation = Vector3(hunch * 0.25 + _nodding.x - arch * 0.15 + 0.06 * grind, 0.0, -_rocking.x * 0.6 + tremble.z * 0.02)
	_spine.rotation = Vector3(hunch * 0.35 - arch * 0.4 + tremble.y * 0.025, _rocking.x * 0.3, _rocking.x * 0.4)
	_chest.rotation = Vector3(hunch * 0.45 - arch * 0.55 + tremble.x * 0.03 - 0.08 * grind, -_rocking.x * 0.2, _rocking.x * 0.3 + tremble.z * 0.03)

	# Its head: hanging asleep; held up to look at what it is after; thrown back to scream.
	_watch_him(_hip_height + 0.5, Vector2(1.0, 0.6), 3.0, delta)
	var look := _gaze * smoothstep(0.3, 0.8, _wake) * (1.0 - scream)
	var bowed := lerpf(0.42, 0.05, _wake) - hunch * 0.9 - 0.3 * reach
	var thrown := -1.15 * scream
	_neck.rotation = Vector3(bowed * 0.45 + thrown * 0.4 + look.y * 0.4 + tremble.y * 0.04, look.x * 0.4, jerk * 0.4 - _rocking.x * 0.6)
	_head.rotation = Vector3(bowed * 0.55 + thrown * 0.6 + look.y * 0.6 + tremble.x * 0.06 + 0.1 * grind, look.x * 0.6, jerk * 0.6 + tremble.z * 0.05 - _rocking.x * 0.5)

	_stand_legs(0.1 + 0.05 * _wake)
	_arms(go, scream, shudder, tremble, reach, closed, clinging, delta)
	_posed = true


## Shapes the steps `_tread` takes into a shuffle: the foot barely lifted,
## turned out, its toes scraping, put down flat.
func _shape_steps(go: float) -> void:
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		_foot_turn[i] = side * -0.22
		if _foot_swing[i] >= 0.0:
			var s := _foot_swing[i]
			_foot_lift[i] = sin(PI * s) * 0.022
			_foot_toes[i] = -0.12 * sin(PI * s)
			if s > 0.85 and s < 0.9:
				_own_dust.puff(to_global(_foot_at[i] + Vector3(0.0, 0.02, 0.06)), Vector3.ZERO, 0.09 * global_basis.get_scale().y, 1)
		else:
			_foot_lift[i] = 0.0
			_foot_toes[i] = 0.25 * smoothstep(-0.06, -0.16, _foot_at[i].z) * go
	for i in 2:
		_foot_at[i] = _foot_at[i].lerp(_standing(i), _air)
		_foot_lift[i] = lerpf(_foot_lift[i], 0.05, _air)


func _arms(go: float, scream: float, shudder: float, tremble: Vector3, reach: float, closed: float, clinging: float, delta: float) -> void:
	var mark := Vector3(0.0, 0.9, 1.5)
	if aim.is_finite():
		mark = to_local(aim)
	var near := clampf(1.0 - (Vector2(mark.x, mark.z).length() - 0.8) / 2.0, 0.0, 1.0) * arms_reach
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var shoulder := to_local(_shoulders[i].global_position)
		# Hanging dead (a little forward of the shoulder as it stoops), swinging as it shuffles.
		var swing := sin(_cycle * TAU + (0.0 if i == 0 else PI)) * 0.06 * go
		var hanging := shoulder + Vector3(side * 0.035, -_upper_arm - _forearm + 0.02, 0.05 + swing)
		# After someone close: held out to take them.
		var out := shoulder + Vector3(side * 0.1, -0.22 + 0.1 * side * sin(_time * 1.1), 0.55)
		var goal := hanging.lerp(out, near * smoothstep(0.4, 0.9, _wake))
		# Screaming: down and out, spread, shaking.
		var spread := shoulder + Vector3(side * 0.56, -0.36, -0.06) + tremble * 0.012
		goal = goal.lerp(spread, scream)
		# Grabbing: up and wide, then round together in front of its chest.
		var wide := shoulder + Vector3(side * 0.5, 0.1, 0.32)
		# (a ring of arms: the hands meet in front, the elbows out wide)
		var hug := shoulder + Vector3(-side * 0.13, -0.1, 0.42) + Vector3(0.0, 0.02, 0.0) * sin(_time * 9.0) * clinging
		goal = goal.lerp(wide, reach * (1.0 - closed)).lerp(hug, closed)
		var stiff := 26.0 + 120.0 * maxf(maxf(reach, scream), closed)
		_hand_follow(i, goal, stiff, 4.0 + 10.0 * maxf(reach, scream), delta)
		var pole := Vector3(side * 0.6, -0.6, -0.6).lerp(Vector3(side * 0.9, 0.2, -0.4), maxf(reach, scream)).lerp(Vector3(side, 0.15, 0.0), closed)
		_hinge_arm(i, to_global(_hand_at[i]), (global_basis * pole).normalized())
		var curl := lerpf(0.55, 0.35, _wake) * (1.0 - scream) + 0.05 * scream
		curl = lerpf(curl, lerpf(0.15, 1.0, closed), reach)
		var splay := lerpf(0.5, 0.8, _wake) + 0.8 * scream + 0.6 * reach * (1.0 - closed)
		var wrist := lerpf(0.1, 0.25, _wake) - 0.6 * scream + 0.4 * reach + shudder * 0.15 * sin(_time * 40.0 + i)
		_set_hand(i, curl, splay, wrist)


# --- Shared with the mummies' rigs (after scripts/enemies/mummy_rig.gd in The Clearing) ---

## Steps with each leg in turn: a whole cycle is STRIDE long and each foot is
## off the ground for SWING of it. A planted foot stays where it is on the
## ground; one that steps is brought down already going back with the ground.
func _tread(going: Vector3, turned: float, go: float, delta: float) -> void:
	var speed := going.length()
	_cycle = fposmod(_cycle + speed / STRIDE * delta, 1.0)
	var walking := (go > 0.15 or speed > 0.08) and speed > 0.02
	var ahead := going / maxf(speed, 0.0001)
	if walking and not _trod:
		_cycle = 0.0 if _foot_at[0].dot(ahead) <= _foot_at[1].dot(ahead) else 0.5
	_trod = walking
	var tether := STRIDE * (1.0 - SWING) * 0.5 + 0.18
	var width := _hip_width + 0.006
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		_foot_at[i] = (_foot_at[i] - going * delta).rotated(Vector3.UP, -turned)
		var home := Vector3(side * width, 0.0, 0.0)
		if _foot_at[i].distance_to(home) > tether:
			_foot_at[i] = home + (_foot_at[i] - home).normalized() * tether
		var p := fposmod(_cycle - 0.5 * i, 1.0)
		var stepping := walking and p < SWING and (_foot_moving[i] or p < SWING * 0.8)
		if stepping and not _foot_moving[i]:
			_foot_began[i] = p
			_foot_from[i] = _foot_at[i]
			_foot_to[i] = home + ahead * STRIDE * (1.0 - SWING) * 0.5
		_foot_moving[i] = stepping
		var s := (p - _foot_began[i]) / maxf(SWING - _foot_began[i], 0.0001)
		_foot_swing[i] = s if stepping else -1.0
		if stepping:
			_foot_at[i] = _foot_from[i].lerp(_foot_to[i] + ahead * (SWING - p) * STRIDE, s * s * (3.0 - 2.0 * s))
	if not walking:
		for i in 2:
			var home := _standing(i)
			var off := _foot_at[i].distance_to(home)
			_foot_at[i] = _foot_at[i].lerp(home, 1.0 - exp(-(4.0 if off > 0.04 else 0.0) * delta)) if _posed else home
			_foot_swing[i] = -1.0
			_foot_moving[i] = false


## Puts each leg to its foot; the knees `spread` apart from the way the feet point.
func _stand_legs(spread: float) -> void:
	var to_hips := _hips.transform.affine_inverse()
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var toes := _foot_toes[i]
		var target := Vector3(_foot_at[i].x, _foot_lift[i], _foot_at[i].z) + _ankle_offset(toes)
		var foot := Basis(Vector3.UP, _foot_turn[i]) * Basis(Vector3.RIGHT, toes)
		_toes[i].rotation.x = lerpf(-maxf(toes, 0.0), 0.15, smoothstep(0.0, 0.035, _foot_lift[i]))
		_solve_leg(i, side, to_hips * target, (to_hips.basis * foot).orthonormalized(), _foot_turn[i] * 0.8 + side * spread)


## How fast it is really going in its own space, from where it was a frame ago.
func _gone(delta: float) -> Vector3:
	var here := global_position
	var moved := here - _was_at if _was_at.is_finite() else Vector3.ZERO
	_was_at = here
	moved.y = 0.0
	if moved.length() > 0.5 * global_basis.get_scale().y:
		moved = Vector3.ZERO
	return global_basis.inverse() * moved / maxf(delta, 0.0001)


## Turns an arm to put its wrist at `point` (world), the elbow towards `pole`,
## each bone turned about the hinge of the elbow.
func _hinge_arm(i: int, point: Vector3, pole: Vector3) -> void:
	var shoulder := _shoulders[i]
	var from := shoulder.global_position
	var to := point - from
	var size := global_basis.get_scale().y
	var upper_length := _upper_arm * size
	var fore_length := _forearm * size
	var reach := clampf(to.length(), 0.1 * size, upper_length + fore_length - 0.005 * size)
	var direction := to.normalized() if to.length_squared() > 0.000001 else Vector3.DOWN
	var hinge := direction.cross(pole)
	hinge = hinge.normalized() if hinge.length_squared() > 0.0001 else global_basis.x.normalized()
	var angle := acos(clampf((upper_length * upper_length + reach * reach - fore_length * fore_length) / (2.0 * upper_length * reach), -1.0, 1.0))
	var upper_direction := direction.rotated(hinge, angle)
	var fore_direction := (from + direction * reach - (from + upper_direction * upper_length)).normalized()
	var parent := (shoulder.get_parent() as Node3D).global_basis.orthonormalized()
	shoulder.basis = parent.inverse() * Basis(hinge, -upper_direction, hinge.cross(-upper_direction))
	var upper := shoulder.global_basis.orthonormalized()
	_elbows[i].basis = upper.inverse() * Basis(hinge, -fore_direction, hinge.cross(-fore_direction))


func _hand_follow(i: int, goal: Vector3, stiffness: float, damping: float, delta: float) -> void:
	_hand_speed[i] += ((goal - _hand_at[i]) * stiffness - _hand_speed[i] * damping) * delta
	_hand_at[i] += _hand_speed[i] * delta
	if not _posed:
		_hand_at[i] = goal
		_hand_speed[i] = Vector3.ZERO


## Turns `_gaze` towards `aim`, seen from `height` up it: (to the side, down), within `most`.
func _watch_him(height: float, most: Vector2, rate: float, delta: float) -> void:
	var look := Vector2.ZERO
	if aim.is_finite() and _wake > 0.5:
		var to := to_local(aim) - Vector3(0.0, height, 0.0)
		look = Vector2(clampf(atan2(to.x, to.z), -most.x, most.x), clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -most.y, most.y))
	_gaze = _gaze.lerp(look, 1.0 - exp(-rate * delta))


func _set_hand(i: int, curl: float, splay: float, wrist: float) -> void:
	_hands[i].rotation = Vector3(wrist, 0.0, 0.0)
	_curl[i] = curl
	_splay[i] = splay
	_pose_fingers(i, 1.0 if i == 0 else -1.0)

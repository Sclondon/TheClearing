class_name MushroomZombieRig
extends CharacterRig
## How a mushroom zombie (the boy, models/boy.glb, taken over by a fungus)
## moves: the whole figure is posed here, and none of the boy's own posing is
## run (see `_process`). It is not walking: it is being walked, like a puppet
## on strings worked by a hand that does not know how a body goes. Its body
## (`MushroomZombie`, mushroom_zombie.gd) is this node's parent and says how
## fast it is going (`velocity`), how risen it is (`risen`), and what it is
## listening to (`aim`); and it starts the two things it does,
## `act(Act.LISTEN)` and `act(Act.LUNGE)`.
##
## - HUNG FROM ITS UPPER BACK: shoulders hitched up, the chest drawn up and
##   forward, the head hanging forward and lolling over to one side, the arms
##   hanging dead and swinging loose on long springs, the hands slack.
## - IT JERKS. Every so often something pulls a string: the head snaps up or
##   round, a shoulder hitches, the trunk twists, a hand flicks open; each snap
##   comes on at once and dies away on its spring.
## - ITS STEPS go in fits: the cycle stalls and lurches on (never two alike); a
##   knee is lifted high with the foot dangling from it, toes down, and dropped
##   flat; it rocks over each foot as it lands. Driven fast (it heard you), it
##   lurches, pitched forward, the arms swinging out.
## - LISTENING (LISTEN): it stops dead, its head snaps round to where the sound
##   was and tips, an ear to it; it holds there, twitching, the fingers working.
## - THE LUNGE (LUNGE): arms thrown up and out ahead, it pitches forward off its
##   feet at what it heard (REACH), the hands clawing shut (CLOSE: the moment it
##   takes hold, if anything is there); holding (`held`) it clings, else it is
##   left bent over, and it hauls itself back up (RECOVER).
## - RISING (`risen` 0 to 1): it comes up out of the ground under it as if pulled
##   up by the back of its neck, head and shoulders first, arms hanging.

enum Act { NONE, LISTEN, LUNGE }
enum Stage { NONE, TURN, LISTENING, REACH, CLOSE, HOLD, RECOVER }

## Seconds each part of a listen and of a lunge takes.
const TURN := 0.18
const LISTENING := 0.9
const REACH := 0.42
const CLOSE := 0.16
const HOLD := 1.0
const RECOVER := 0.7
## One whole cycle of its steps (two), as modelled, and the share of it each foot is off the ground.
const STRIDE := 0.62
const SWING := 0.42

## What it is listening to and lunging at, in the world (INF: nothing).
var aim := Vector3.INF
## How far it is up out of the ground: 0 under it, 1 standing.
var risen := 1.0
## In a lunge: whether it has hold of someone.
var held := false
## How wildly it is being worked, 0..1 (more when it hunts).
var frenzy := 0.0

var _doing := Act.NONE
var _doing_time := INF
var _cycle := 0.0
var _stride := STRIDE
var _trod := false
var _posed := false
var _was_at := Vector3.INF
var _yaw_was := 0.0
var _foot_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_to: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_moving: Array[bool] = [false, false]
var _foot_swing: Array[float] = [-1.0, -1.0]
var _foot_began: Array[float] = [0.0, 0.0]
var _foot_lift: Array[float] = [0.0, 0.0]
var _foot_toes: Array[float] = [0.0, 0.0]
var _foot_turn: Array[float] = [0.0, 0.0]
var _hand_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _hand_speed: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _gaze := Vector2.ZERO
var _rocking := Vector2.ZERO
## The strings: each a spring (where, how fast) that a jerk throws, and when the next jerk comes.
var _head_jerk := Vector3.ZERO
var _head_jerk_speed := Vector3.ZERO
var _trunk_jerk := Vector3.ZERO
var _trunk_jerk_speed := Vector3.ZERO
var _shrug := Vector2.ZERO
var _shrug_speed := Vector2.ZERO
var _jerk_in := 0.5
## How the gait stalls and lurches: a slow wander, and how far through a stall it is.
var _fits := 0.0
## Which way the head lolls (1 its left), changed now and then by a jerk.
var _loll := 1.0
var _own_dust: Dust


## Shaded as the mushrooms are (MushroomLook): his colours are the model's own,
## painted on him, and his growths glow faintly at night.
func restyle() -> void:
	for part: MeshInstance3D in _figure.find_children("*", "MeshInstance3D", true, false):
		part.material_override = MushroomLook.shared()


func _build() -> void:
	# (the boy's footfalls are not its own: it raises its own dust)
	dusty = false
	super()
	_own_dust = Dust.new()
	add_child(_own_dust)
	settle()


## Only its own posing: the boy's (CharacterRig's) is not run at all, which is
## most of what a rig costs.
func _process(delta: float) -> void:
	if _player == null:
		return
	delta = minf(delta, 1.0 / 30.0)
	_time += delta
	var grounded: bool = _player.is_on_floor()
	_air = _approach(_air, 0.0 if grounded else 1.0, 10.0, delta)
	_pose_extra(delta)
	_apply_pose()


## Stands it still as it is: for when it is put somewhere.
func settle() -> void:
	_doing = Act.NONE
	_doing_time = INF
	_cycle = 0.0
	_posed = false
	_was_at = Vector3.INF
	_yaw_was = rotation.y
	_rocking = Vector2.ZERO
	for i in 2:
		_foot_at[i] = _standing(i)
		_foot_moving[i] = false
		_foot_swing[i] = -1.0


func act(what: Act) -> void:
	_doing = what
	_doing_time = 0.0 if what != Act.NONE else INF
	held = false


func act_length(what: Act) -> float:
	match what:
		Act.LISTEN:
			return TURN + LISTENING
		Act.LUNGE:
			return REACH + CLOSE + HOLD + RECOVER
	return 0.0


func act_time() -> float:
	return _doing_time


func stage() -> Stage:
	var t := _doing_time
	match _doing:
		Act.LISTEN:
			if t < TURN:
				return Stage.TURN
			if t < TURN + LISTENING:
				return Stage.LISTENING
		Act.LUNGE:
			if t < REACH:
				return Stage.REACH
			if t < REACH + CLOSE:
				return Stage.CLOSE
			if t < REACH + CLOSE + HOLD:
				return Stage.HOLD
			if t < act_length(Act.LUNGE):
				return Stage.RECOVER
	return Stage.NONE


func _standing(i: int) -> Vector3:
	# (feet a little apart and one a little ahead: it never quite stands square)
	return Vector3((_hip_width + 0.02) * (1.0 if i == 0 else -1.0), 0.0, 0.03 if i == 0 else -0.025)


static func _sprung(spring: Vector2, to: float, stiffness: float, damping: float, delta: float) -> Vector2:
	spring.y += ((to - spring.x) * stiffness - spring.y * damping) * delta
	spring.x += spring.y * delta
	return spring


## A string pulled: a snap of the head, the trunk or a shoulder, now and then.
func _jerks(delta: float, still: float) -> void:
	_jerk_in -= delta * (1.0 + 1.5 * frenzy)
	if _jerk_in <= 0.0:
		_jerk_in = randf_range(0.35, 1.6)
		match randi() % 4:
			0, 1:
				_head_jerk_speed += Vector3(randf_range(-9.0, 4.0), randf_range(-10.0, 10.0), randf_range(-12.0, 12.0)) * (0.6 + 0.6 * still)
				if randf() < 0.35:
					_loll = -_loll
			2:
				_trunk_jerk_speed += Vector3(randf_range(-5.0, 5.0), randf_range(-6.0, 6.0), randf_range(-4.0, 4.0))
			3:
				var side := randi() % 2
				_shrug_speed[side] += randf_range(4.0, 9.0)
	# (stiff strings: a snap, and it settles back)
	_head_jerk_speed += (-_head_jerk * 160.0 - _head_jerk_speed * 9.0) * delta
	_head_jerk += _head_jerk_speed * delta
	_trunk_jerk_speed += (-_trunk_jerk * 120.0 - _trunk_jerk_speed * 8.0) * delta
	_trunk_jerk += _trunk_jerk_speed * delta
	for i in 2:
		_shrug_speed[i] += (-_shrug[i] * 140.0 - _shrug_speed[i] * 8.0) * delta
		_shrug[i] += _shrug_speed[i] * delta


func _pose_extra(delta: float) -> void:
	var turned := angle_difference(_yaw_was, rotation.y)
	_yaw_was = rotation.y
	if _doing != Act.NONE:
		_doing_time += delta
		if _doing_time >= act_length(_doing):
			_doing = Act.NONE
			_doing_time = INF
	var t := _doing_time
	var going := _gone(delta)
	var go := clampf(going.length() / 0.3, 0.0, 1.0) * (1.0 - _air)

	var listen := 0.0
	var reach := 0.0
	var closed := 0.0
	var clinging := 0.0
	var recover := 0.0
	if _doing == Act.LISTEN:
		listen = smoothstep(0.0, TURN, t) * (1.0 - smoothstep(TURN + LISTENING - 0.2, TURN + LISTENING, t))
	elif _doing == Act.LUNGE:
		var out := 1.0 - smoothstep(REACH + CLOSE + HOLD, act_length(Act.LUNGE), t)
		reach = smoothstep(0.0, REACH * 0.85, t) * out
		closed = smoothstep(REACH, REACH + CLOSE, t) * out
		clinging = closed * (1.0 if held else 0.0)
		recover = smoothstep(REACH + CLOSE + HOLD, act_length(Act.LUNGE), t) * (1.0 - smoothstep(act_length(Act.LUNGE) - 0.15, act_length(Act.LUNGE), t))
	var still := 1.0 - go
	_jerks(delta, still * (1.0 - listen))

	# The fits of its gait: it stalls and lurches on, never in time with itself.
	_fits += delta * (0.9 + 0.8 * frenzy)
	var lurch := clampf(0.55 + 0.9 * sin(_fits * 2.3) * sin(_fits * 0.77 + 1.0), 0.15, 1.5)
	var hurry := smoothstep(1.2, 3.0, going.length())
	_stride = lerpf(STRIDE, STRIDE * 1.6, hurry)
	_tread(going * lerpf(lurch, 1.0, hurry * 0.5), turned, go, delta)
	_shape_steps(go, hurry)

	# --- The body: hung from the upper back ---
	var swing_side := sin(_cycle * TAU)
	_rocking = _sprung(_rocking, go * swing_side * 0.16, 55.0, 4.0, delta)
	var hunch := 0.32 + 0.25 * hurry + 0.5 * reach - 0.2 * recover + 0.1 * listen
	var pitch := 0.12 * hurry + 0.55 * reach * (1.0 - 0.6 * clinging)
	var rise := smoothstep(0.0, 1.0, risen)
	# (rising, it is bent right over, drawn up by the back of the neck)
	hunch += (1.0 - rise) * 0.9
	var height := _hip_height - 0.02 - 0.03 * absf(swing_side) * go - 0.1 * reach - 0.06 * recover
	_hips.position = Vector3(_rocking.x * 0.1 + _trunk_jerk.x * 0.01, height, 0.07 * reach + 0.04 * hurry)
	_hips.rotation = Vector3(pitch * 0.5 + _trunk_jerk.x * 0.05, _trunk_jerk.y * 0.05, -_rocking.x * 0.9 + _trunk_jerk.z * 0.04)
	_spine.rotation = Vector3(hunch * 0.3 + pitch * 0.3 + _trunk_jerk.x * 0.06, _rocking.x * 0.4 + _trunk_jerk.y * 0.08, _rocking.x * 0.5)
	if _chest:
		# (the chest is drawn up by the strings: arched forward at the top, the shoulders hitched)
		_chest.rotation = Vector3(hunch * 0.35 - 0.12, -_rocking.x * 0.3 + _trunk_jerk.y * 0.06, _rocking.x * 0.3 + _trunk_jerk.z * 0.05)
	# Shoulders hitched up (each on its own string)
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		_shoulders[i].position = _shoulder_rest[i] + Vector3(0.0, 0.025 + 0.03 * _shrug[i] + 0.02 * reach, -0.01)

	# The head: hanging forward and lolled over; snapped round to listen
	_listen_to(delta, listen)
	var hang := lerpf(0.55, 0.25, hurry) * (1.0 - listen) * (1.0 - reach * 0.7) + (1.0 - rise) * 0.4
	var loll := _loll * 0.42 * (1.0 - listen) * (1.0 - reach * 0.5)
	var tip := 0.35 * listen * signf(_gaze.x if absf(_gaze.x) > 0.05 else 1.0)
	var head := Vector3(hang + _gaze.y * listen, _gaze.x * listen, loll + tip) + _head_jerk * 0.08
	if _neck:
		_neck.rotation = Vector3(head.x * 0.45, head.y * 0.45, head.z * 0.4)
		_head.rotation = Vector3(head.x * 0.55, head.y * 0.55, head.z * 0.6)
	else:
		_head.rotation = head

	_stand_legs(0.08 + 0.06 * hurry)
	_arms(go, hurry, listen, reach, closed, clinging, delta)
	_posed = true
	# Risen as far as it is: the whole of it let down into the ground
	position.y = -1.35 * (1.0 - rise)


## Turns `_gaze` towards `aim` while it listens: (round, down), the head snapping there.
func _listen_to(delta: float, listen: float) -> void:
	var look := Vector2.ZERO
	if aim.is_finite() and listen > 0.01:
		var to := to_local(aim) - Vector3(0.0, _hip_height + 0.45, 0.0)
		look = Vector2(clampf(atan2(to.x, to.z), -1.3, 1.3), clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.5, 0.6))
	_gaze = _gaze.lerp(look, 1.0 - exp(-18.0 * delta))


## Shapes the steps `_tread` takes: the knee lifted high, the foot dangling
## toes down from it, dropped flat.
func _shape_steps(go: float, hurry: float) -> void:
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		_foot_turn[i] = side * -0.12 + 0.15 * sin(_fits * 1.3 + i)
		if _foot_swing[i] >= 0.0:
			var s := _foot_swing[i]
			# (up fast, as if on a string, and down at once)
			var up := pow(sin(PI * pow(s, 0.7)), 1.5)
			_foot_lift[i] = up * lerpf(0.13, 0.18, hurry)
			_foot_toes[i] = 0.75 * up
			if s > 0.88 and s < 0.93:
				_own_dust.puff(to_global(_foot_at[i] + Vector3(0.0, 0.02, 0.05)), Vector3.ZERO, 0.08 * global_basis.get_scale().y, 1)
		else:
			_foot_lift[i] = 0.0
			_foot_toes[i] = 0.1 * go
	for i in 2:
		_foot_at[i] = _foot_at[i].lerp(_standing(i), _air)


func _arms(go: float, hurry: float, listen: float, reach: float, closed: float, clinging: float, delta: float) -> void:
	var mark := Vector3(0.0, 0.8, 1.2)
	if aim.is_finite():
		mark = to_local(aim)
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var shoulder := to_local(_shoulders[i].global_position)
		# Hanging dead, a little in front of it as it is bent, and swinging loose
		var swing := sin(_cycle * TAU + (0.0 if i == 0 else PI)) * (0.09 + 0.1 * hurry) * go
		var hanging := shoulder + Vector3(side * 0.04, -_upper_arm - _forearm + 0.015, 0.09 + swing + 0.05 * hurry)
		# Listening: the hands come up a little, fingers working
		hanging += Vector3(0.0, 0.06, 0.04) * listen
		# The lunge: up and out ahead at what it heard, then clawed shut on it
		var low := clampf(mark.y - shoulder.y, -0.4, 0.15)
		var ahead := shoulder + Vector3(side * 0.12, low + 0.12, 0.6)
		var shut := shoulder + Vector3(side * 0.06, low, 0.48)
		var goal := hanging.lerp(ahead, reach * (1.0 - closed)).lerp(shut, closed)
		# (slack strings: loose and slow, but thrown hard in a lunge)
		var stiff := 18.0 + 180.0 * maxf(reach, closed)
		_hand_follow(i, goal, stiff, 2.5 + 12.0 * reach, delta)
		var pole := Vector3(side * 0.5, -0.4, -0.8).lerp(Vector3(side * 0.9, -0.2, -0.3), reach)
		_hinge_arm(i, to_global(_hand_at[i]), (global_basis * pole).normalized())
		var twitch := 0.25 * sin(_time * 23.0 + i * 2.0) * listen
		var curl := 0.55 + twitch - 0.4 * reach * (1.0 - closed) + 0.7 * closed
		var splay := 0.3 + 0.7 * reach * (1.0 - closed) + 0.3 * listen
		var wrist := 0.35 - 0.3 * reach + 0.25 * sin(_time * 1.7 + i) * (1.0 - reach)
		_set_hand(i, curl, splay, wrist)


# --- After the ghoul's rig (creatures/ghoul/ghoul_rig.gd), which these are from ---

## Steps with each leg in turn: a whole cycle is `_stride` long and each foot is
## off the ground for SWING of it. A planted foot stays where it is on the
## ground; one that steps is brought down already going back with the ground.
func _tread(going: Vector3, turned: float, go: float, delta: float) -> void:
	var speed := going.length()
	_cycle = fposmod(_cycle + speed / _stride * delta, 1.0)
	var walking := (go > 0.15 or speed > 0.08) and speed > 0.02
	var ahead := going / maxf(speed, 0.0001)
	if walking and not _trod:
		_cycle = 0.0 if _foot_at[0].dot(ahead) <= _foot_at[1].dot(ahead) else 0.5
	_trod = walking
	var tether := _stride * (1.0 - SWING) * 0.5 + 0.18
	var width := _hip_width + 0.02
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
			_foot_to[i] = home + ahead * _stride * (1.0 - SWING) * 0.5
		_foot_moving[i] = stepping
		var s := (p - _foot_began[i]) / maxf(SWING - _foot_began[i], 0.0001)
		_foot_swing[i] = s if stepping else -1.0
		if stepping:
			_foot_at[i] = _foot_from[i].lerp(_foot_to[i] + ahead * (SWING - p) * _stride, s * s * (3.0 - 2.0 * s))
	if not walking:
		for i in 2:
			var home := _standing(i)
			var off := _foot_at[i].distance_to(home)
			_foot_at[i] = _foot_at[i].lerp(home, 1.0 - exp(-(4.0 if off > 0.04 else 0.0) * delta)) if _posed else home
			_foot_swing[i] = -1.0
			_foot_moving[i] = false


func _stand_legs(spread: float) -> void:
	var to_hips := _hips.transform.affine_inverse()
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var toes := _foot_toes[i]
		var target := Vector3(_foot_at[i].x, _foot_lift[i], _foot_at[i].z) + _ankle_offset(toes)
		var foot := Basis(Vector3.UP, _foot_turn[i]) * Basis(Vector3.RIGHT, toes)
		_toes[i].rotation.x = lerpf(-maxf(toes, 0.0), 0.15, smoothstep(0.0, 0.035, _foot_lift[i]))
		_solve_leg(i, side, to_hips * target, (to_hips.basis * foot).orthonormalized(), _foot_turn[i] * 0.8 + side * spread)


func _gone(delta: float) -> Vector3:
	var here := global_position
	var moved := here - _was_at if _was_at.is_finite() else Vector3.ZERO
	_was_at = here
	moved.y = 0.0
	if moved.length() > 0.5 * global_basis.get_scale().y:
		moved = Vector3.ZERO
	return global_basis.inverse() * moved / maxf(delta, 0.0001)


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


func _set_hand(i: int, curl: float, splay: float, wrist: float) -> void:
	_hands[i].rotation = Vector3(wrist, 0.0, 0.0)
	_curl[i] = curl
	_splay[i] = splay
	_pose_fingers(i, 1.0 if i == 0 else -1.0)

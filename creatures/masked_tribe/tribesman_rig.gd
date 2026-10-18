class_name TribesmanRig
extends CharacterRig
## How a tribesman moves: he is the boy (models/boy.glb), so CharacterRig walks,
## runs, sprints, creeps (`is_ducking` on his body), pants and stoops to pick
## things up for him exactly as it does for a player; this lays over that what a
## boy gone wild does with a spear (see `_pose_extra`). His body (`Tribesman`,
## tribesman.gd) is this node's parent and says how fast he is going, what he is
## looking at (`aim`) and whether he has his spear (`armed`); it starts what he
## does with `act`.
##
## - CARRIED, the spear is in his right fist: stood still, upright beside him,
##   its butt on the ground by his foot; on the move, low at his side at the
##   balance, its point forward and up, swinging a little with his stride.
## - THE CALL: he plants himself and drums the butt of his spear on the ground,
##   lifting it and driving it down, four times; his head goes back with each
##   blow and his free fist pumps up beside it (CHANT).
## - THE THROW: he turns side on to what he is throwing at and draws the spear
##   back over his shoulder, its point along his aim, the other arm straight out
##   at them, leaning back, the shaft trembling, as long as he is told to hold
##   it (WIND); then whips it over and through (LOOSE: it leaves his hand as
##   this begins) and follows through, bent forward (FOLLOW).
## - THE JAB: both hands on the shaft, he draws it back low at his hip, crouched
##   (GATHER), drives it straight out at them, lunging (THRUST), holds it there
##   a moment (HOLD) and draws it back (RECOVER).
## - His head turns to what he is after (`aim`), and away from nothing else: he
##   takes no notice of the other hunters, as the boy would.

enum Act { NONE, CHANT, THROW, JAB }
enum Stage { NONE, CHANT, WIND, LOOSE, FOLLOW, GATHER, THRUST, HOLD, RECOVER }

## Seconds each part takes. (WIND lasts as long as the body holds it: `loose()`.)
const CHANT := 1.75
## When each blow of the drumming lands, seconds into the call.
const BEATS: Array[float] = [0.32, 0.68, 1.04, 1.4]
const LOOSE := 0.14
const FOLLOW := 0.5
## How long the wind-up takes to come right back (it is held from then on).
const DRAW := 0.42
const GATHER := 0.24
const THRUST := 0.11
const HOLD := 0.14
const RECOVER := 0.32
## How far the point of a jab reaches out in front of him (as modelled, at the full of the thrust).
const JAB_REACH := 1.55

## What he is after, in the world (INF: nothing).
var aim := Vector3.INF
## The spear is in his hand.
var armed := true
## His spear (Tribesman makes it): put in his hand each frame while `armed`.
var spear: TribeSpear

var _doing := Act.NONE
var _doing_time := INF
## WIND is held until loosed: when that came (seconds into the act), INF until then.
var _loosed_at := INF
var _gaze := Vector2.ZERO
var _held_spear := 1.0
var _upright := 1.0
var _tremble := Vector3.ZERO
var _was_armed := true


func _build() -> void:
	super()
	_held_spear = 1.0 if armed else 0.0


## Begins something (anything he was doing is cut short).
func act(what: Act) -> void:
	_doing = what
	_doing_time = 0.0 if what != Act.NONE else INF
	_loosed_at = INF


## In a throw: lets it go now (if he is not yet drawn right back, at once anyway).
func loose() -> void:
	if _doing == Act.THROW and not is_finite(_loosed_at):
		_loosed_at = _doing_time


func act_time() -> float:
	return _doing_time


func stage() -> Stage:
	var t := _doing_time
	match _doing:
		Act.CHANT:
			if t < CHANT:
				return Stage.CHANT
		Act.THROW:
			if not is_finite(_loosed_at):
				return Stage.WIND
			var since := t - _loosed_at
			if since < LOOSE:
				return Stage.LOOSE
			if since < LOOSE + FOLLOW:
				return Stage.FOLLOW
		Act.JAB:
			if t < GATHER:
				return Stage.GATHER
			if t < GATHER + THRUST:
				return Stage.THRUST
			if t < GATHER + THRUST + HOLD:
				return Stage.HOLD
			if t < GATHER + THRUST + HOLD + RECOVER:
				return Stage.RECOVER
	return Stage.NONE


## He takes no notice of anything for himself: his body says what he looks at (`aim`).
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
	var size := global_basis.get_scale().y
	var frame := global_basis.orthonormalized()

	# How far into each thing he does, 0..1, rising and falling.
	var chant := 0.0
	var pulse := 0.0
	var wind := 0.0
	var whip := 0.0
	var follow := 0.0
	var jab := 0.0
	var thrust := 0.0
	match _doing:
		Act.CHANT:
			chant = smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(CHANT - 0.25, CHANT, t))
			# (each blow: the spear lifted slowly, driven down hard)
			for beat in BEATS:
				var d := t - beat
				if d >= 0.0:
					pulse = maxf(pulse, 1.0 - smoothstep(0.0, 0.16, d))
		Act.THROW:
			if not is_finite(_loosed_at):
				wind = smoothstep(0.0, DRAW, t)
			else:
				var since := t - _loosed_at
				var drawn := smoothstep(0.0, DRAW, _loosed_at)
				whip = smoothstep(0.0, LOOSE, since)
				wind = drawn * (1.0 - whip)
				follow = (1.0 - smoothstep(LOOSE + FOLLOW * 0.4, LOOSE + FOLLOW, since)) * whip
		Act.JAB:
			jab = smoothstep(0.0, GATHER * 0.8, t) * (1.0 - smoothstep(GATHER + THRUST + HOLD, GATHER + THRUST + HOLD + RECOVER, t))
			thrust = smoothstep(GATHER, GATHER + THRUST, t) * (1.0 - smoothstep(GATHER + THRUST + HOLD, GATHER + THRUST + HOLD + RECOVER * 0.8, t))

	# Where he is aiming, in his own space (straight ahead if at nothing).
	var mark := Vector3(0.0, 0.8, 6.0)
	if aim.is_finite():
		mark = to_local(aim)
	var shoulder_r := to_local(_shoulders[1].global_position)
	var shoulder_l := to_local(_shoulders[0].global_position)

	# --- The body: turned side on to throw, crouched to jab, braced to drum ---
	var turn := -1.0 * wind + 0.45 * follow
	var lean := -0.22 * wind + 0.5 * follow + 0.32 * jab + 0.12 * thrust - 0.12 * chant * pulse
	_hips.position += Vector3(0.0, -0.05 * jab - 0.04 * chant * pulse - 0.025 * wind, 0.1 * thrust - 0.02 * wind + 0.05 * follow) * 1.0
	_hips.rotate_object_local(Vector3.UP, turn * 0.35)
	_spine.rotate_object_local(Vector3.UP, turn * 0.3)
	_spine.rotate_object_local(Vector3.RIGHT, lean * 0.5)
	if _chest:
		_chest.rotate_object_local(Vector3.UP, turn * 0.35)
		_chest.rotate_object_local(Vector3.RIGHT, lean * 0.5 - 0.15 * chant)
	# Drumming, his knees give with each blow.
	if chant > 0.0:
		_crouch_hips(0.035 * chant * pulse)

	# --- His head: on what he is after; thrown back with each blow of the drum ---
	var look := Vector2.ZERO
	if aim.is_finite():
		var eyes := Vector3(0.0, 1.1, 0.0)
		var to := mark - eyes
		look = Vector2(clampf(atan2(to.x, to.z) - turn * 0.9, -1.2, 1.2), clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.7, 0.6))
	_gaze = _gaze.lerp(look, 1.0 - exp(-7.0 * delta))
	var held := 1.0 if aim.is_finite() else 0.0
	var back := -0.5 * chant * (0.4 + 0.6 * pulse)
	if _neck:
		_neck.rotation = Vector3(lerpf(_neck.rotation.x, _gaze.y * 0.45, held) + back * 0.4, lerpf(_neck.rotation.y, _gaze.x * 0.4, held), _neck.rotation.z)
	_head.rotation = Vector3(lerpf(_head.rotation.x, _gaze.y * 0.55, held) + back * 0.6 + lean * -0.4, lerpf(_head.rotation.y, _gaze.x * 0.6, held), _head.rotation.z)

	# --- The spear ---
	if armed != _was_armed:
		_was_armed = armed
	_held_spear = _approach(_held_spear, 1.0 if armed else 0.0, 10.0, delta)
	var picking := _picking < 1.0
	var moving := clampf(_move * 1.4, 0.0, 1.0)
	_upright = _approach(_upright, 0.0 if moving > 0.3 or _duck > 0.3 else 1.0, 4.0, delta)
	# Carried: upright beside him stood still; low at his side, point forward and up, on the move.
	var step := sin(TAU * _phase)
	var stood_grip := Vector3(-0.15, 0.7, 0.1)
	var stood_dir := Vector3(-0.04, 1.0, 0.1)
	var low_grip := Vector3(-0.17, 0.5 + 0.06 * _run + absf(step) * 0.015 * moving, 0.06 + step * 0.04 * moving)
	low_grip.y -= 0.12 * _duck
	var low_dir := Vector3(0.04, lerpf(0.42, 0.18, _run), 1.0)
	var grip := low_grip.lerp(stood_grip, _upright)
	var dir := low_dir.normalized().slerp(stood_dir.normalized(), _upright)
	var fingers := Vector3(1.0, -0.2, 0.0)
	# Drumming: held upright before him, lifted and driven down.
	if chant > 0.0:
		var lift := 0.2 * _raised(t)
		var drum_grip := Vector3(-0.1, 0.76 + lift, 0.26)
		grip = grip.lerp(drum_grip, chant)
		dir = dir.slerp(Vector3(0.0, 1.0, -0.05).normalized(), chant)
	# The wind-up: back over his shoulder, along his aim, trembling.
	var at_aim := (mark - (shoulder_r + Vector3(0.0, 0.1, 0.0))).normalized()
	if at_aim.z < 0.3:
		at_aim = Vector3(at_aim.x, at_aim.y, 0.3).normalized()
	if wind > 0.0 or whip > 0.0:
		_tremble = Vector3(sin(_time * 41.0), sin(_time * 37.0 + 1.0), sin(_time * 29.0)) * 0.006 * wind
		var drawn := shoulder_r + Vector3(-0.1, 0.2, -0.46) + _tremble
		var drawn_dir := (at_aim + Vector3(0.0, 0.38, 0.0)).normalized()
		var through := shoulder_r + at_aim * 0.42 + Vector3(0.02, -0.05, 0.0)
		var thrown := drawn.lerp(through, whip)
		grip = grip.lerp(thrown, maxf(wind, whip))
		dir = dir.slerp(drawn_dir, maxf(wind, whip))
		fingers = fingers.lerp(Vector3(0.3, 0.0, 1.0), wind)
	# The jab: low at his hip, then straight out at them.
	if jab > 0.0:
		var level := Vector3(at_aim.x, clampf(at_aim.y, -0.45, 0.25), at_aim.z).normalized()
		var hip := Vector3(-0.14, 0.62, -0.1) + level * 0.05
		var out := Vector3(-0.06, 0.78, 0.0) + level * 0.42
		grip = grip.lerp(hip.lerp(out, thrust), jab)
		dir = dir.slerp(level, jab)
		fingers = fingers.lerp(Vector3(1.0, 0.0, 0.0), jab)

	var weight := _held_spear * (1.0 - smoothstep(0.0, 0.25, 1.0 - _picking) if picking else 1.0)
	if weight > 0.01:
		_hold_spear(grip, dir.normalized(), fingers, weight)
		# Two hands on it to jab.
		if jab > 0.01:
			var shaft := spear_transform()
			var forward := -shaft.basis.z.normalized()
			var front := shaft.origin + forward * 0.36 * size
			_solve_arm(0, 1.0, front, _forearm + 0.06, jab, (frame * Vector3(0.6, -1.0, -0.2)).normalized())
			_lay_hand(0, 1.0, (frame * Vector3(0.0, 1.0, 0.0)).normalized(), (frame * Vector3(-1.0, -0.3, 0.0)).normalized(), jab * 0.6)
	if armed and spear and is_instance_valid(spear):
		spear.hold(spear_transform())

	# The other arm: straight out at what he throws at; a fist pumped up beside his head as he drums.
	var left_goal := Vector3.INF
	var left_weight := 0.0
	if wind > 0.01:
		left_goal = shoulder_l + (at_aim * Vector3(1.0, 1.0, 1.0) + Vector3(0.12, 0.05, 0.0)).normalized() * 0.38
		left_weight = wind
	if chant > 0.01:
		var pump := shoulder_l + Vector3(0.14, 0.16 + 0.1 * pulse, 0.12)
		left_goal = pump if not left_goal.is_finite() else left_goal.lerp(pump, chant)
		left_weight = maxf(left_weight, chant)
	if follow > 0.01:
		var tuck := shoulder_l + Vector3(0.05, -0.3, 0.15)
		left_goal = tuck if not left_goal.is_finite() else left_goal.lerp(tuck, follow)
		left_weight = maxf(left_weight, follow)
	if left_weight > 0.01 and jab < 0.01:
		_solve_arm(0, 1.0, to_global(left_goal), _forearm + 0.06, left_weight, (frame * Vector3(0.7, -0.8, -0.3)).normalized())
		_curl[0] = lerpf(_curl[0], 1.0 if chant > 0.5 else 0.2, left_weight)
		_splay[0] = lerpf(_splay[0], 0.0 if chant > 0.5 else 0.6, left_weight)
		_pose_fingers(0, 1.0)
	# Empty-handed after the throw, the hand opens.
	if not armed:
		_curl[1] = lerpf(_curl[1], 0.15, follow)
		_splay[1] = lerpf(_splay[1], 0.9, follow)
		if follow > 0.01:
			var after := shoulder_r + Vector3(0.12, -0.36, 0.3)
			_solve_arm(1, -1.0, to_global(after), _forearm + 0.06, follow, (frame * Vector3(-0.6, -0.8, -0.3)).normalized())
		_pose_fingers(1, -1.0)


## Drumming: how high the spear is lifted `t` seconds into the call, 0..1. It
## comes up slowly after each blow and is driven down hard onto the next.
func _raised(t: float) -> float:
	var last := 0.0
	for beat in BEATS:
		if t < beat:
			return smoothstep(0.0, 0.2, t - last) * smoothstep(0.0, 0.07, beat - t)
		last = beat
	return smoothstep(0.0, 0.25, t - last) * 0.4


## Lowers his hips by `drop` (his feet stay where they are: the knees give).
func _crouch_hips(drop: float) -> void:
	_hips.position.y -= drop


## Puts the spear in his right fist: its grip at `grip` and its point along `dir`
## (both in his own space), the knuckles towards `fingers`; the arm reaches for it.
func _hold_spear(grip: Vector3, dir: Vector3, fingers: Vector3, weight: float) -> void:
	var frame := global_basis.orthonormalized()
	var size := global_basis.get_scale().y
	var along := (frame * dir).normalized()
	var curl := (frame * fingers).slide(along)
	curl = curl.normalized() if curl.length_squared() > 0.0001 else along.cross(Vector3.UP).normalized()
	# (the fist round the shaft: the shaft runs through it along its Z, point out by the thumb)
	var y := -curl
	var hand := Basis(y.cross(along), y, along).orthonormalized()
	var wrist := to_global(grip) - hand * GUN_IN_HAND * size
	var pole := (frame * Vector3(-0.5, -1.0, -0.4)).normalized()
	_solve_arm(1, -1.0, wrist, _forearm, weight, pole)
	var fore := _elbows[1].global_basis.orthonormalized()
	_hands[1].basis = _hands[1].basis.orthonormalized().slerp((fore.inverse() * hand).orthonormalized(), weight)
	_curl[1] = lerpf(_curl[1], 1.0, weight)
	_splay[1] = lerpf(_splay[1], 0.1, weight)
	_pose_fingers(1, -1.0)


## Where the spear in his hand is, in the world: its grip, the point down its -Z.
func spear_transform() -> Transform3D:
	var held := _hands[1].global_transform.orthonormalized()
	return Transform3D(Basis(-held.basis.x, held.basis.y, -held.basis.z), held * GUN_IN_HAND)


## The point of the spear in his hand, in the world.
func spear_tip() -> Vector3:
	return spear_transform() * Vector3(0.0, 0.0, -TribeSpear.TIP * global_basis.get_scale().y)

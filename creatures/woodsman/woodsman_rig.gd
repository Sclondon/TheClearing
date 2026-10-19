class_name WoodsmanRig
extends CharacterRig
## How the woodsman moves: he is the boy's figure (models/boy.glb) on the boy's
## rig, so CharacterRig walks him, stoops him and turns his head for him as it
## does a player; this lays over that what an old woodsman does with his axe and
## his lantern (`_pose_extra`). His body (`Woodsman`, woodsman.gd) is this
## node's parent and says how fast he is going, what he looks at (`aim`) and how
## far his lantern is raised (`raise`); it starts what he does with `act`.
##
## - CARRIED, the axe lies over his right shoulder, his fist round the haft
##   before it, the head behind him; the lantern hangs from his left fist held a
##   little out in front of him at his waist, swinging as he walks.
## - RAISED, the lantern is held up and out at what he is looking at, his arm
##   straight: to see who is there, and to warn them off.
## - THE CHOP (at a wall, at the ivy on it): the axe drawn back high over his
##   shoulder (DRAW), then brought down across in front of him into the wall
##   (STROKE), and back (BACK); again, CHOPS times.
## - THE SWING (at someone): the axe raised high over his head with the lantern
##   arm out (WIND: the warning, held until `strike`), then brought straight down
##   in front of him (STRIKE: where it lands is `blade_point`) and through
##   (THROUGH).

enum Act { NONE, CHOP, SWING }
enum Stage { NONE, DRAW, STROKE, BACK, WIND, STRIKE, THROUGH }

## Seconds each part takes. (WIND lasts as long as the body holds it: `strike()`.)
const DRAW := 0.62
const STROKE := 0.13
const BACK := 0.4
const CHOPS := 3
const WIND := 0.7
const STRIKE := 0.16
const THROUGH := 0.55
## How far in front of him the axe's blade comes down, as modelled (boy units).
const BLADE_REACH := 0.62

## What he looks at, in the world (INF: nothing).
var aim := Vector3.INF
## How far his lantern is raised at `aim`, 0..1 (eased).
var raise := 0.0
## His axe, in his right hand (a child of its joint).
var axe: MeshInstance3D

var _doing := Act.NONE
var _doing_time := INF
var _struck_at := INF
var _gaze := Vector2.ZERO
var _raised := 0.0
var _chopped := 0


## Begins something (anything he was doing is cut short).
func act(what: Act) -> void:
	_doing = what
	_doing_time = 0.0 if what != Act.NONE else INF
	_struck_at = INF
	_chopped = 0


## In a swing: brings the axe down now.
func strike() -> void:
	if _doing == Act.SWING and not is_finite(_struck_at):
		_struck_at = _doing_time


func act_time() -> float:
	return _doing_time


## How many chops have landed in this act.
func chops_landed() -> int:
	return _chopped


func stage() -> Stage:
	var t := _doing_time
	match _doing:
		Act.CHOP:
			var each := DRAW + STROKE + BACK
			if t < each * CHOPS:
				var in_one := fmod(t, each)
				if in_one < DRAW:
					return Stage.DRAW
				if in_one < DRAW + STROKE:
					return Stage.STROKE
				return Stage.BACK
		Act.SWING:
			if not is_finite(_struck_at):
				return Stage.WIND
			var since := t - _struck_at
			if since < STRIKE:
				return Stage.STRIKE
			if since < STRIKE + THROUGH:
				return Stage.THROUGH
	return Stage.NONE


## He takes no notice of anything for himself: his body says what he looks at.
func _notice() -> void:
	_interest = null
	_interest_is_threat = false


func _pose_extra(delta: float) -> void:
	if _doing != Act.NONE:
		_doing_time += delta
		if _doing == Act.CHOP:
			_chopped = mini(int((_doing_time - DRAW - STROKE * 0.5) / (DRAW + STROKE + BACK)) + 1, CHOPS) if _doing_time > DRAW + STROKE * 0.5 else 0
		if stage() == Stage.NONE:
			_doing = Act.NONE
			_doing_time = INF
	var t := _doing_time
	var frame := global_basis.orthonormalized()

	# How far into each thing he does, 0..1.
	var chop := 0.0
	var draw := 0.0
	var stroke := 0.0
	var wind := 0.0
	var strike_now := 0.0
	var through := 0.0
	match _doing:
		Act.CHOP:
			var each := DRAW + STROKE + BACK
			chop = smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(each * CHOPS - 0.3, each * CHOPS, t))
			var in_one := fmod(t, each)
			if in_one < DRAW:
				draw = smoothstep(0.0, DRAW, in_one)
				stroke = 0.0
			elif in_one < DRAW + STROKE:
				draw = 1.0
				stroke = smoothstep(DRAW, DRAW + STROKE, in_one)
			else:
				draw = 1.0 - smoothstep(DRAW + STROKE, each, in_one)
				stroke = 1.0 - smoothstep(DRAW + STROKE, each, in_one)
		Act.SWING:
			if not is_finite(_struck_at):
				wind = smoothstep(0.0, WIND, t)
			else:
				var since := t - _struck_at
				strike_now = smoothstep(0.0, STRIKE, since)
				wind = smoothstep(0.0, WIND, _struck_at) * (1.0 - strike_now)
				through = strike_now * (1.0 - smoothstep(STRIKE + THROUGH * 0.35, STRIKE + THROUGH, since))

	var mark := Vector3(0.0, 0.8, 6.0)
	if aim.is_finite():
		mark = to_local(aim)
	var shoulder_r := to_local(_shoulders[1].global_position)
	var shoulder_l := to_local(_shoulders[0].global_position)
	var at_aim := (mark - shoulder_r).normalized()
	if at_aim.z < 0.25:
		at_aim = Vector3(at_aim.x, at_aim.y, 0.25).normalized()

	# --- The body: turned to draw the axe back, bent forward into a blow ---
	var swung := maxf(strike_now * through, chop * stroke)
	var turn := -0.55 * chop * draw + 0.35 * chop * stroke - 0.2 * wind
	var lean := -0.15 * wind + 0.45 * through + 0.3 * chop * stroke - 0.08 * chop * draw
	_hips.position += Vector3(0.0, -0.04 * swung - 0.02 * wind, 0.05 * swung)
	_hips.rotate_object_local(Vector3.UP, turn * 0.3)
	_spine.rotate_object_local(Vector3.UP, turn * 0.3)
	_spine.rotate_object_local(Vector3.RIGHT, lean * 0.5)
	if _chest:
		_chest.rotate_object_local(Vector3.UP, turn * 0.4)
		_chest.rotate_object_local(Vector3.RIGHT, lean * 0.5)

	# --- His head: on what he is looking at ---
	var look := Vector2.ZERO
	if aim.is_finite():
		var eyes := Vector3(0.0, 1.1, 0.0)
		var to := mark - eyes
		look = Vector2(clampf(atan2(to.x, to.z) - turn * 0.9, -1.1, 1.1), clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.6, 0.6))
	_gaze = _gaze.lerp(look, 1.0 - exp(-4.0 * delta))
	var held := 1.0 if aim.is_finite() else 0.0
	if _neck:
		_neck.rotation = Vector3(lerpf(_neck.rotation.x, _gaze.y * 0.45, held), lerpf(_neck.rotation.y, _gaze.x * 0.4, held), _neck.rotation.z)
	_head.rotation = Vector3(lerpf(_head.rotation.x, _gaze.y * 0.55, held) - lean * 0.3, lerpf(_head.rotation.y, _gaze.x * 0.6, held), _head.rotation.z)

	# --- The axe, in his right fist ---
	var moving := clampf(_move * 1.4, 0.0, 1.0)
	var step := sin(TAU * _phase)
	# Carried: over his shoulder, the head behind him, nodding a little with his stride.
	var grip := Vector3(-0.13, 0.82 + absf(step) * 0.01 * moving, 0.09)
	var dir := Vector3(-0.07, 0.67, -0.74 + 0.04 * step * moving).normalized()
	var fingers := Vector3(0.0, 1.0, 0.2)
	if chop > 0.0:
		# Drawn back high over his shoulder, then down across in front of him into the wall.
		var back_grip := shoulder_r + Vector3(-0.06, 0.16, -0.08)
		var back_dir := Vector3(-0.35, 0.75, -0.55).normalized()
		var hit_grip := shoulder_r + Vector3(0.12, -0.12, 0.3)
		var hit_dir := Vector3(0.75, -0.15, 0.62).normalized()
		var over := Vector3(-0.05, 1.0, 0.25).normalized()
		var g := back_grip.lerp(hit_grip, stroke)
		var d := back_dir.slerp(over, minf(stroke * 2.0, 1.0)).slerp(hit_dir, maxf(stroke * 2.0 - 1.0, 0.0)) if stroke > 0.0 else back_dir
		var pose_grip := grip.lerp(g, draw)
		var pose_dir := dir.slerp(d, draw)
		grip = grip.lerp(pose_grip, chop)
		dir = dir.slerp(pose_dir, chop).normalized()
		fingers = fingers.lerp(Vector3(0.3, -0.6, 0.6), chop * stroke)
	if wind > 0.0 or strike_now > 0.0:
		# Raised high over his head, the head of the axe hanging back behind him; then
		# brought straight down in front of him at whoever it is.
		var up_grip := shoulder_r + Vector3(0.04, 0.3, -0.02)
		var up_dir := Vector3(0.05, 0.4, -1.0).normalized()
		var down_grip := shoulder_r + Vector3(0.1, -0.22, 0.0) + at_aim * 0.34
		var down_dir := (Vector3(at_aim.x * 0.5, -0.75, maxf(at_aim.z, 0.4) * 0.65)).normalized()
		var over := Vector3(0.0, 1.0, 0.1).normalized()
		var d := up_dir
		if strike_now > 0.0:
			d = up_dir.slerp(over, minf(strike_now * 2.0, 1.0)).slerp(down_dir, maxf(strike_now * 2.0 - 1.0, 0.0))
		var g := up_grip.lerp(down_grip, strike_now)
		var weight := maxf(wind, strike_now)
		# (a tremble in the arm held up)
		g += Vector3(sin(_time * 31.0), sin(_time * 27.0), 0.0) * 0.004 * wind
		grip = grip.lerp(g, weight)
		dir = dir.slerp(d, weight).normalized()
		fingers = fingers.lerp(Vector3(0.0, 0.3, 1.0), wind).lerp(Vector3(0.0, -1.0, 0.4), strike_now)
	_hold_axe(grip, dir, fingers, 1.0)

	# --- The lantern, in his left fist ---
	var swing_out := maxf(wind, through)
	_raised = _approach(_raised, clampf(raise, 0.0, 1.0), 3.0, delta)
	var low := Vector3(0.17, 0.6 + 0.012 * absf(step) * moving, 0.2)
	var up_at := shoulder_l + (Vector3(at_aim.x * 0.6 + 0.25, at_aim.y + 0.35, at_aim.z)).normalized() * 0.37
	var out_side := shoulder_l + Vector3(0.3, 0.02, 0.12)
	var lamp_at := low.lerp(up_at, _raised).lerp(out_side, swing_out * 0.8)
	# (set down by his foot while he chops? no: held out of the way, to his side)
	lamp_at = lamp_at.lerp(shoulder_l + Vector3(0.22, -0.28, 0.0), chop)
	_solve_arm(0, 1.0, to_global(lamp_at), _forearm + 0.06, 1.0, (frame * Vector3(0.7, -0.8, -0.4)).normalized())
	_lay_hand(0, 1.0, (frame * Vector3(-1.0, 0.0, 0.0)).normalized(), (frame * Vector3(0.0, -0.3, 1.0)).normalized(), 0.8)
	_curl[0] = 1.0
	_splay[0] = 0.05
	_pose_fingers(0, 1.0)


## Puts the axe in his right fist: its grip at `grip` and its head along `dir`
## (both in his own space), the knuckles (and the blade's edge) towards
## `fingers`; the arm reaches for it.
func _hold_axe(grip: Vector3, dir: Vector3, fingers: Vector3, weight: float) -> void:
	var frame := global_basis.orthonormalized()
	var size := global_basis.get_scale().y
	var along := (frame * dir).normalized()
	var curl := (frame * fingers).slide(along)
	curl = curl.normalized() if curl.length_squared() > 0.0001 else along.cross(Vector3.UP).normalized()
	var y := -curl
	var hand := Basis(y.cross(along), y, along).orthonormalized()
	var wrist := to_global(grip) - hand * GUN_IN_HAND * size
	var pole := (frame * Vector3(-0.5, -1.0, -0.3)).normalized()
	_solve_arm(1, -1.0, wrist, _forearm, weight, pole)
	var fore := _elbows[1].global_basis.orthonormalized()
	_hands[1].basis = _hands[1].basis.orthonormalized().slerp((fore.inverse() * hand).orthonormalized(), weight)
	_curl[1] = lerpf(_curl[1], 1.0, weight)
	_splay[1] = lerpf(_splay[1], 0.1, weight)
	_pose_fingers(1, -1.0)


## Where the axe in his hand is, in the world: its grip, its head down -Z, its edge down -Y.
func axe_transform() -> Transform3D:
	var held := _hands[1].global_transform.orthonormalized()
	return Transform3D(Basis(-held.basis.x, held.basis.y, -held.basis.z), held * GUN_IN_HAND)


## The edge of the axe's blade, in the world.
func blade_point() -> Vector3:
	return axe_transform() * Vector3(0.0, -0.1 * global_basis.get_scale().y, -0.49 * global_basis.get_scale().y)


## Where the lantern hangs from: his left fist, in the world.
func lantern_hold() -> Vector3:
	var hand := _hands[0].global_transform
	return hand * Vector3(0.0, -PALM - 0.03, 0.0)

class_name MummyRig
extends CharacterRig
## The mummy's own way of moving, laid over the boy's rig (see `_pose_extra`).
## Nothing of the boy's walk is kept: it poses the whole figure itself.
##
## - It walks as something that has forgotten how. Its left leg takes a quick,
##   falling step; it lands on it, catches itself, and hauls the right leg up
##   after it along the ground, stiff and turned out. Its body pitches over
##   each step and is caught late; its head hangs and rolls; now and then it
##   nearly goes over. `pace()` gives the body the speed that goes with this,
##   so it really does lurch across the floor and not just in place.
## - Its arms do not swing. Dormant, they are crossed on its chest. Awake, they
##   hang; after someone, they are held out at him (`arms_reach`), the left
##   higher than the right, and jolt with every step, because each hand is a
##   weight on a spring that the body drags about.
## - `swipe()` is how it takes hold of him: it rears up and back, an arm
##   raised behind it (WIND_UP: this is what he has to see and get away from),
##   throws the arm down and across in front of it (STRIKE), is left hanging
##   over where he was (HOLD), and gathers itself (RECOVER). `claw()` says
##   where a sweeping arm is, for the body to tell whether it has him.
## - Its loose ends of bandage are chains of weights (class Chain), found from
##   the bones named `drape_<name>_<k>`: each link hangs from the one above,
##   is pulled down, held back by the air, kept off the ground, and (those at
##   the waist and shoulders) kept out of its body and legs.
##
## The other kinds of mummy (see `Mummy.Kind`) each have a rig that extends this
## one and poses the figure its own way (scripts/mummy_priest_rig.gd and the
## rest). What they share is here: the stages of a swipe, whose lengths are
## each rig's own (`swipe_wind_up`, `swipe_strike` and so on); steps taken by two
## legs in turn, on feet that stay where they are put (`_tread`); hands on
## springs; and the loose ends.

enum Stage { NONE, WIND_UP, STRIKE, HOLD, RECOVER }

## Seconds each part of a swipe takes.
const WIND_UP := 0.6
const STRIKE := 0.17
const HOLD := 0.35
const RECOVER := 0.6
## The length of one whole cycle of its walk (a step and a drag), as modelled.
const STRIDE := 0.7
## How far through that cycle the stepping foot comes down, and when the other is dragged (from, to).
const STEP_ENDS := 0.34
const DRAG := Vector2(0.44, 0.95)
## The leg that steps and the leg that is dragged.
const GOOD := 0
const BAD := 1

## Seconds each part of a swipe takes for this rig: the first mummy's, unless a kind sets its own.
var swipe_wind_up := WIND_UP
var swipe_strike := STRIKE
var swipe_hold := HOLD
var swipe_recover := RECOVER
## How thick it is, for what hangs on it to lie against (see _body_shapes): its
## trunk, the top of its back, and its thighs.
var trunk_round := 0.058
var back_round := 0.098
var thigh_round := 0.05


## A loose strip: joints from where it is rooted to its tip, in the world.
class Chain:
	var bones := PackedInt32Array()
	var parent: Node3D
	## Which arm the bone it hangs from belongs to, if any (as CharacterRig._arm_sides).
	var arm := 0
	## Where it roots, in that bone's space; and each link, as the way to the next joint.
	var origin := Vector3.ZERO
	var links := PackedVector3Array()
	var at := PackedVector3Array()
	var was := PackedVector3Array()
	## Which of the body's shapes it is kept out of (see _body_shapes).
	var shapes := PackedInt32Array()
	var settled := false


## How awake it is, 0 (standing dead, arms crossed) to 1. The body sets this.
var awake := 0.0
## What it is after, in the world: it looks at this and reaches for it. INF for nothing.
var aim := Vector3.INF

var _wake := 0.0
var _cycle := 0.0
var _yaw_was := 0.0
## Each foot: where it is on the ground (in the rig's own space, as modelled),
## where it is being moved from and to, and how it is held.
var _foot_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_to: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_moving: Array[bool] = [false, false]
var _foot_lift: Array[float] = [0.0, 0.0]
var _foot_toes: Array[float] = [0.0, 0.0]
var _foot_turn: Array[float] = [0.0, 0.0]
## Nearly going over: set off now and then by a step, and fading.
var _stagger := 0.0
var _stagger_next := 3
## What of it is on springs: how far it is pitched and rolled, how far it has
## sunk, which way its head hangs (nod, tilt), and each hand.
var _lurch := Vector2.ZERO
var _list := Vector2.ZERO
var _sink := Vector2.ZERO
var _nod := Vector2.ZERO
var _loll := Vector2.ZERO
var _gaze := Vector2.ZERO
var _hand_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _hand_speed: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _posed := false
## A swipe: how long ago it began (INF: none), and with which arm (0 left, 1 right, 2 both).
var _swipe_time := INF
var _swipe_arm := 0
var _chains: Array[Chain] = []
var _own_dust: Dust
var _scuff := 0.0
## For the kinds that step with each leg in turn (see _tread): how far through
## its step each foot is, or -1 while it stands.
var _foot_swing: Array[float] = [-1.0, -1.0]
var _foot_began: Array[float] = [0.0, 0.0]
var _trod := false
## Where it was a frame ago (see _gone), and whether its arms are turned by the
## hinge of the elbow (see _hinge_arm), which the other kinds' are.
var _was_at := Vector3.INF
var _hinged := false


func _build() -> void:
	# (the boy's footfalls are not its own: it raises its own dust)
	dusty = false
	super()
	_own_dust = Dust.new()
	add_child(_own_dust)
	_find_chains()
	settle()


## Stands it still as it is, with nothing in motion: for when it is put somewhere.
func settle() -> void:
	_swipe_time = INF
	_stagger = 0.0
	_cycle = 0.0
	_yaw_was = rotation.y
	_lurch = Vector2.ZERO
	_list = Vector2.ZERO
	_sink = Vector2.ZERO
	_nod = Vector2.ZERO
	_loll = Vector2.ZERO
	_wake = awake
	_posed = false
	_was_at = Vector3.INF
	for i in 2:
		_foot_at[i] = _standing(i)
		_foot_moving[i] = false
	for chain in _chains:
		chain.settled = false


## Begins a swipe with the left arm (0), the right (1) or both (2).
func swipe(arm: int) -> void:
	_swipe_arm = arm
	_swipe_time = 0.0


func stage() -> Stage:
	if _swipe_time >= swipe_wind_up + swipe_strike + swipe_hold + swipe_recover:
		return Stage.NONE
	if _swipe_time < swipe_wind_up:
		return Stage.WIND_UP
	if _swipe_time < swipe_wind_up + swipe_strike:
		return Stage.STRIKE
	return Stage.HOLD if _swipe_time < swipe_wind_up + swipe_strike + swipe_hold else Stage.RECOVER


## How long until the arm comes down, while it is winding up.
func strikes_in() -> float:
	return swipe_wind_up - _swipe_time


## The arms that are sweeping now, each as the line from its elbow to its fingertips, in the world.
func claws() -> Array[PackedVector3Array]:
	var found: Array[PackedVector3Array] = []
	if stage() != Stage.STRIKE:
		return found
	for i in 2:
		if _swipe_arm == 2 or _swipe_arm == i:
			found.append(claw(i))
	return found


func claw(i: int) -> PackedVector3Array:
	var hand := _hands[i].global_transform
	return PackedVector3Array([_elbows[i].global_position, hand * Vector3(0.0, -0.16, 0.0)])


## How fast it should be going just now, against its ordinary speed: it falls
## onto its good leg at a rush and labours while it hauls the other up.
func pace() -> float:
	var rush := 1.0 - smoothstep(STEP_ENDS - 0.02, STEP_ENDS + 0.1, _cycle)
	return lerpf(0.78, 1.5, rush) * (1.0 - 0.85 * _stagger)


## Where a foot stands when it is going nowhere.
func _standing(i: int) -> Vector3:
	return Vector3(_hip_width + 0.02, 0.0, 0.03) if i == GOOD else Vector3(-_hip_width - 0.045, 0.0, -0.05)


## A value on a spring, as (where it is, how fast it is going), drawn towards `to`.
static func _sprung(spring: Vector2, to: float, stiffness: float, damping: float, delta: float) -> Vector2:
	spring.y += ((to - spring.x) * stiffness - spring.y * damping) * delta
	spring.x += spring.y * delta
	return spring


func _pose_extra(delta: float) -> void:
	var size := global_basis.get_scale().y
	var going: Vector3 = global_basis.inverse() * _player.velocity
	going.y = 0.0
	var turned := angle_difference(_yaw_was, rotation.y)
	_yaw_was = rotation.y
	_wake = _approach(_wake, awake, 2.5, delta)
	var go := _move * (1.0 - _air)
	_stagger = _approach(_stagger, 0.0, 2.6, delta)

	# Where it is in a swipe. `wound`: reared back, 0..1. `struck`: thrown
	# forward after the arm, 0..1. `sweep`: how far the arm is through its stroke.
	var total := swipe_wind_up + swipe_strike + swipe_hold + swipe_recover
	if _swipe_time < total:
		_swipe_time += delta
	var swiping := _swipe_time < total
	var wound := 0.0
	var struck := 0.0
	var sweep := 0.0
	if swiping:
		# (it goes back slowly and hangs there a moment before it comes down)
		wound = smoothstep(0.0, swipe_wind_up * 0.7, _swipe_time) * (1.0 - smoothstep(swipe_wind_up, swipe_wind_up + swipe_strike * 0.5, _swipe_time))
		sweep = clampf((_swipe_time - swipe_wind_up) / swipe_strike, 0.0, 1.0)
		struck = smoothstep(swipe_wind_up, swipe_wind_up + swipe_strike, _swipe_time) * (1.0 - smoothstep(swipe_wind_up + swipe_strike + swipe_hold, total, _swipe_time))
	# Which way the swipe turns it: its left arm comes across to its right.
	var across := 0.0 if _swipe_arm == 2 else (1.0 if _swipe_arm == 0 else -1.0)

	_walk(going, turned, go, delta)

	# --- The body ---
	var p := _cycle
	# Falling forward as the good foot goes out, most as it lands; then caught.
	var fall := smoothstep(0.04, STEP_ENDS, p) * (1.0 - smoothstep(STEP_ENDS, STEP_ENDS + 0.16, p))
	# Whether its weight is on the bad leg (while the good one steps) or the good.
	var on_bad := 1.0 - smoothstep(STEP_ENDS - 0.08, STEP_ENDS + 0.06, p) + smoothstep(0.92, 1.0, p)
	var dragged := smoothstep(DRAG.x, DRAG.y, p)
	_lurch = _sprung(_lurch, go * (0.07 + 0.3 * fall) + _stagger * 0.45, 80.0, 7.0, delta)
	_list = _sprung(_list, go * lerpf(-0.13, 0.12, on_bad) + _stagger * 0.12, 60.0, 6.5, delta)
	# (up over the stiff leg, and down onto the other)
	_sink = _sprung(_sink, go * (0.03 * on_bad * sin(PI * clampf(p / STEP_ENDS, 0.0, 1.0)) - 0.015) - _stagger * 0.05, 140.0, 11.0, delta)
	# The hip of the dragged leg comes round with it, and goes back as the other steps.
	var twist := go * (lerpf(0.2, -0.14, smoothstep(0.0, STEP_ENDS, p)) if p < STEP_ENDS else lerpf(-0.14, 0.2, dragged))
	var hunch := lerpf(0.4, 1.0, _wake) + stoop
	var lean := _lurch.x - 0.3 * wound + 0.5 * struck
	var swing := across * (0.55 * wound - 0.8 * struck)

	var height := _hip_height - 0.065 * _wake + _sink.x - _crouch + 0.05 * wound - 0.1 * struck
	_hips.position = Vector3(go * lerpf(0.035, -0.03, on_bad) - across * 0.03 * struck, height, 0.035 * fall * go - 0.05 * wound + 0.13 * struck)
	_hips.rotation = Vector3(0.04 * hunch + lean * 0.4, twist + swing * 0.25, _list.x * 0.55)
	_spine.rotation = Vector3(0.14 * hunch + lean * 0.3, -twist * 0.7 + swing * 0.35, _list.x * 0.3)
	_chest.rotation = Vector3(0.24 * hunch + lean * 0.3, -twist * 0.6 + swing * 0.4, _list.x * 0.25)

	# Its head hangs forward off a neck that carries it like a weight on a stick:
	# it nods to each step and rolls to the side its body is not leaning.
	var bowed := 0.04 * hunch + 0.38 * hunch + lean
	_nod = _sprung(_nod, go * 0.22 * fall + _stagger * 0.35, 45.0, 4.0, delta)
	_loll = _sprung(_loll, _wake * (0.2 - _list.x * 1.6), 26.0, 3.2, delta)
	# It turns its face to him all the same.
	var look := Vector2.ZERO
	if aim.is_finite() and _wake > 0.5:
		var to := to_local(aim) - Vector3(0.0, _hip_height + 0.55, 0.0)
		look = Vector2(clampf(atan2(to.x, to.z), -1.1, 1.1), clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.5, 0.7))
	_gaze = _gaze.lerp(look, 1.0 - exp(-3.0 * delta))
	var face := -bowed * 0.62 * _wake + 0.2 * (1.0 - _wake) + _gaze.y - 0.25 * wound + 0.2 * struck
	_neck.rotation = Vector3(0.4 * hunch + face * 0.35 + _nod.x * 0.5, _gaze.x * 0.4 - swing * 0.3, _loll.x * 0.4)
	_head.rotation = Vector3(face * 0.65 + _nod.x * 0.5, _gaze.x * 0.6 - swing * 0.4, _loll.x * 0.6)

	_legs(go)
	_arms(wound, struck, sweep, across, swiping, go, delta)
	_hang_chains(size, delta)
	_posed = true


## Moves its feet. Each stands where it was put (so the ground carries it back
## under the body) until its turn comes: the good one is lifted and thrown
## forward; the bad one is drawn up along the ground behind it.
func _walk(going: Vector3, turned: float, go: float, delta: float) -> void:
	var speed := going.length()
	_cycle = fposmod(_cycle + speed / STRIDE * delta, 1.0)
	var walking := go > 0.15
	for i in 2:
		_foot_at[i] = (_foot_at[i] - going * delta).rotated(Vector3.UP, -turned)

	# The good leg's step.
	var stepping := walking and _cycle < STEP_ENDS
	if stepping and not _foot_moving[GOOD]:
		_foot_from[GOOD] = _foot_at[GOOD]
		# No two alike: long or short, and sometimes across its own line.
		_stagger_next -= 1
		var wild := _stagger_next <= 0
		_foot_to[GOOD] = Vector3(_hip_width + randf_range(-0.02, 0.04) - (0.07 if wild else 0.0), 0.0, randf_range(0.2, 0.27) * (0.75 if wild else 1.0))
	if _foot_moving[GOOD] and not stepping:
		# Down, hard.
		_sink.y -= 0.55 * go
		_nod.y += 1.6 * go
		_own_dust.puff(to_global(_foot_at[GOOD] + Vector3(0.0, 0.02, 0.05)), -global_basis.z * 0.2, 0.16, 2)
		if _stagger_next <= 0:
			_stagger_next = randi_range(3, 6)
			_stagger = 1.0
	_foot_moving[GOOD] = stepping
	if stepping:
		var t := _cycle / STEP_ENDS
		_foot_at[GOOD] = _foot_from[GOOD].lerp(_foot_to[GOOD], smoothstep(0.0, 1.0, t))
		_foot_lift[GOOD] = sin(PI * pow(t, 0.75)) * 0.085
		_foot_toes[GOOD] = lerpf(0.6, -0.3, smoothstep(0.25, 0.9, t))
		_foot_turn[GOOD] = 0.12
	else:
		_foot_lift[GOOD] = 0.0
		# (it goes up onto its toes as the body leaves it behind)
		_foot_toes[GOOD] = 0.55 * smoothstep(-0.07, -0.2, _foot_at[GOOD].z) * go
		_foot_turn[GOOD] = 0.12

	# The bad leg's drag.
	var dragging := walking and _cycle >= DRAG.x and _cycle < DRAG.y
	if dragging and not _foot_moving[BAD]:
		_foot_from[BAD] = _foot_at[BAD]
		_foot_to[BAD] = Vector3(-_hip_width - randf_range(0.02, 0.07), 0.0, randf_range(-0.03, 0.03))
	_foot_moving[BAD] = dragging
	if dragging:
		var t := (_cycle - DRAG.x) / (DRAG.y - DRAG.x)
		_foot_at[BAD] = _foot_from[BAD].lerp(_foot_to[BAD], t * t * (3.0 - 2.0 * t))
		_foot_lift[BAD] = 0.006
		_foot_toes[BAD] = lerpf(0.5, 0.1, smoothstep(0.6, 1.0, t))
		_foot_turn[BAD] = -lerpf(0.75, 0.5, smoothstep(0.7, 1.0, t))
		_scuff -= delta
		if _scuff <= 0.0:
			_scuff = 0.09
			_own_dust.puff(to_global(_foot_at[BAD] + Vector3(0.0, 0.02, 0.06)), Vector3.ZERO, 0.09, 1)
	else:
		_foot_lift[BAD] = 0.0
		_foot_toes[BAD] = 0.5 * smoothstep(-0.12, -0.26, _foot_at[BAD].z) * go
		_foot_turn[BAD] = -lerpf(0.5, 0.75, smoothstep(-0.05, -0.25, _foot_at[BAD].z))

	# Going nowhere, each foot is shuffled back to where it stands.
	if not walking:
		for i in 2:
			var home := _standing(i)
			var off := _foot_at[i].distance_to(home)
			_foot_at[i] = _foot_at[i].lerp(home, 1.0 - exp(-(4.0 if off > 0.05 else 0.0) * delta)) if _posed else home
			_foot_lift[i] = minf(off * 0.25, 0.02) if i == GOOD else 0.0
	# Off the ground they only hang.
	for i in 2:
		_foot_at[i] = _foot_at[i].lerp(_standing(i), _air)
		_foot_lift[i] = lerpf(_foot_lift[i], 0.06, _air)
		_foot_toes[i] = lerpf(_foot_toes[i], 0.5, _air)


func _legs(_go: float) -> void:
	var to_hips := _hips.transform.affine_inverse()
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var toes := _foot_toes[i]
		var target := Vector3(_foot_at[i].x, _foot_lift[i], _foot_at[i].z) + _ankle_offset(toes)
		# (the dragged foot is rolled over onto its inner edge)
		var edge := 0.22 if i == BAD and _foot_moving[BAD] else 0.0
		var foot := Basis(Vector3.UP, _foot_turn[i]) * Basis(Vector3.RIGHT, toes) * Basis(Vector3.BACK, side * edge)
		_toes[i].rotation.x = -maxf(toes, 0.0) if _foot_lift[i] < 0.02 else 0.25
		# The knees go where the feet point, and a little apart.
		_solve_leg(i, side, to_hips * target, (to_hips.basis * foot).orthonormalized(), _foot_turn[i] * 0.8 + side * 0.08)


## Puts a hand at `point` (in the rig's own space). The reach is worked out as
## modelled, so that it comes out right on a figure that has been scaled.
func _hand_to(i: int, point: Vector3, pole: Vector3) -> void:
	var side := 1.0 if i == 0 else -1.0
	var from := _shoulders[i].global_position
	var to := to_global(point) - from
	if _hinged:
		# (the other kinds' hands go to the very place: see _hinge_arm)
		_hinge_arm(i, to_global(point), (global_basis * pole).normalized())
		return
	_solve_arm(i, side, from + to / global_basis.get_scale().y, _forearm, 1.0, (global_basis * pole).normalized())


func _arms(wound: float, struck: float, sweep: float, across: float, swiping: bool, go: float, delta: float) -> void:
	# How high he is, and how near: its hands go down to him as it closes.
	var mark := Vector3(0.0, 0.85, 2.0)
	if aim.is_finite():
		mark = to_local(aim)
	var near := clampf(1.0 - (Vector2(mark.x, mark.z).length() - 0.7) / 1.4, 0.0, 1.0)
	var level := clampf(mark.y, 0.4, 1.05)
	var chest := to_local(_chest.global_position)
	var chest_basis := (global_basis.inverse() * _chest.global_basis).orthonormalized()
	var total := swipe_wind_up + swipe_strike + swipe_hold + swipe_recover
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var shoulder := to_local(_shoulders[i].global_position)
		# Dormant: crossed on its chest, each hand on the other shoulder.
		var crossed := chest + chest_basis * Vector3(-side * 0.05, 0.03, 0.125 + 0.02 * side)
		# Awake: hanging, dead.
		var hanging := shoulder + Vector3(side * 0.05, -0.655, 0.04)
		# After him: held out at him. The left leads; the right is carried lower and looser.
		var waver := Vector3(sin(_time * 1.3 + i * 2.0) * 0.02, sin(_time * 0.9 + i * 1.3) * 0.025, 0.0)
		var held := shoulder + (Vector3(-0.05, lerpf(-0.12, level - shoulder.y, near), 0.6) if i == 0 else Vector3(0.03, lerpf(-0.36, level - 0.12 - shoulder.y, near * 0.7), 0.47)) + waver
		# (nearly going over, both are thrown out in front of it)
		held += Vector3(side * 0.06, -0.12, 0.08) * _stagger
		var goal := crossed.lerp(hanging.lerp(held, arms_reach), smoothstep(0.15, 0.9, _wake))
		var pole := Vector3(side * 0.5, -1.0, 0.25).lerp(Vector3(side * 0.6, -1.0, -0.3), _wake)
		var curl := lerpf(0.25, lerpf(0.5, 0.62 + sin(_time * 2.1 + i) * 0.1, arms_reach), _wake)
		var splay := lerpf(0.4, lerpf(0.6, 1.1, arms_reach), _wake)
		var wrist := lerpf(0.9, lerpf(0.15, -0.25 if i == 0 else 0.55, arms_reach), _wake)

		# It is a weight the body drags about: it follows late, and overshoots.
		var stiffness := 70.0 if i == 0 else 42.0
		_hand_speed[i] += ((goal - _hand_at[i]) * stiffness - _hand_speed[i] * (7.0 if i == 0 else 4.5)) * delta
		_hand_at[i] += _hand_speed[i] * delta
		if not _posed or _wake < 0.03:
			_hand_at[i] = goal
			_hand_speed[i] = Vector3.ZERO

		if swiping:
			var taking := _swipe_arm == 2 or _swipe_arm == i
			var place := _hand_at[i]
			if taking:
				# Back and up behind its shoulder; down through where he stands; and on across itself.
				var back := Vector3(side * 0.5, 1.24, -0.2)
				var through := Vector3(side * 0.2, level + 0.08, 0.74)
				var done := Vector3(-side * 0.3, level - 0.14, 0.44)
				if _swipe_arm == 2:
					# (both: flung wide, and brought together on him)
					back = Vector3(side * 0.66, 1.02, -0.06)
					through = Vector3(side * 0.4, level + 0.04, 0.62)
					done = Vector3(side * 0.03, level - 0.04, 0.6)
				# (a curve from `back` to `done` that passes through `through`)
				var bend := through * 2.0 - (back + done) * 0.5
				var u := sweep * sweep * (3.0 - 2.0 * sweep)
				var stroke := back.lerp(bend, u).lerp(bend.lerp(done, u), u)
				place = goal.lerp(back, smoothstep(0.0, swipe_wind_up * 0.75, _swipe_time)) if _swipe_time < swipe_wind_up else stroke
				pole = pole.lerp(Vector3(side, 0.35, -0.6), wound)
				# Its fingers are spread wide to take him, and close on what they find.
				curl = lerpf(curl, lerpf(0.12, 1.15, smoothstep(0.75, 1.0, sweep)), maxf(wound, struck))
				splay = lerpf(splay, 1.35, maxf(wound, struck))
				wrist = lerpf(wrist, lerpf(-0.45, 0.3, sweep), maxf(wound, struck))
			else:
				# The other arm goes out behind it, for balance.
				place = goal + Vector3(side * 0.12, -0.1, -0.3) * wound + Vector3(side * 0.2, -0.2, -0.5) * struck
			var over := smoothstep(0.0, 0.1, _swipe_time) * (1.0 - smoothstep(total - swipe_recover * 0.8, total, _swipe_time))
			_hand_at[i] = _hand_at[i].lerp(place, over)
			_hand_speed[i] *= 1.0 - over

		_hand_to(i, _hand_at[i], pole)
		_hands[i].rotation = Vector3(wrist, 0.0, 0.0)
		_curl[i] = curl
		_splay[i] = splay
		_pose_fingers(i, side)


# --- Loose ends ---

func _find_chains() -> void:
	var joints := {}
	for i in _joints.size():
		joints[_bones[i]] = i
	for bone in _skeleton.get_bone_count():
		var called := _skeleton.get_bone_name(bone)
		var parent := _skeleton.get_bone_parent(bone)
		if not called.begins_with("drape_") or not called.ends_with("_0") or not joints.has(parent):
			continue
		var chain := Chain.new()
		chain.parent = _joints[joints[parent]]
		chain.arm = _arm_sides[joints[parent]]
		chain.origin = _skeleton.get_bone_rest(bone).origin
		# (the last bone of each only marks where it ends)
		var at := bone
		while not _skeleton.get_bone_children(at).is_empty():
			var next := _skeleton.get_bone_children(at)[0]
			chain.bones.append(at)
			chain.links.append(_skeleton.get_bone_rest(next).origin)
			at = next
		if chain.bones.is_empty():
			continue
		chain.at.resize(chain.bones.size() + 1)
		chain.was.resize(chain.bones.size() + 1)
		if "waist" in called:
			chain.shapes = PackedInt32Array([0, 2, 3])
		elif "shoulder" in called or "stole" in called or "lappet" in called:
			chain.shapes = PackedInt32Array([0, 1])
		_chains.append(chain)


## The body, for what hangs on it to lie against: each a line and a radius, in the world.
func _body_shapes(size: float) -> Array[Vector4]:
	var hips := _hips.global_position
	var chest := _chest.global_position
	var up := _hips.global_basis.y.normalized()
	var back := _chest.global_basis.orthonormalized()
	var lines: Array[Vector4] = []
	for line: Array in [[hips, chest, trunk_round], [chest + back * Vector3(0.0, 0.03, -0.02) * size, chest + back * Vector3(0.0, 0.15, -0.01) * size, back_round],
			[_thighs[0].global_position, _shins[0].global_position, thigh_round], [_thighs[1].global_position, _shins[1].global_position, thigh_round]]:
		lines.append(Vector4(line[0].x, line[0].y, line[0].z, line[2] * size))
		lines.append(Vector4(line[1].x, line[1].y, line[1].z, 0.0))
	return lines


## Swings the loose ends. Each joint keeps going the way it was going, is pulled
## down and slowed by the air; then each link is brought back to its length from
## the root down, lifted off the ground and pushed out of the body; and the
## bones are turned to lie along the links.
func _hang_chains(size: float, delta: float) -> void:
	if _chains.is_empty():
		return
	var shapes := _body_shapes(size)
	var ground := global_position.y + 0.012 * size
	for chain in _chains:
		# The bone it hangs from, in the world: an arm's is turned from how it
		# is posed (hanging) to how it is modelled (see CharacterRig._apply_pose).
		var frame := chain.parent.global_basis.orthonormalized()
		if chain.arm != 0:
			frame = frame * Basis(Vector3.BACK, signf(chain.arm) * _arm_rest).inverse()
		var root := chain.parent.global_position + frame * chain.origin * size
		var count := chain.bones.size()
		if not chain.settled or root.distance_to(chain.at[0]) > 1.5:
			# Put somewhere new: it starts as it was made, and at rest.
			var joint := root
			for k in count + 1:
				chain.at[k] = joint
				chain.was[k] = joint
				if k < count:
					joint += frame * chain.links[k] * size
			chain.settled = true
		chain.at[0] = root
		for k in range(1, count + 1):
			var here := chain.at[k]
			var moving := (here - chain.was[k]) * exp(-1.6 * delta)
			# (what is lying on the ground is held by it)
			if here.y <= ground + 0.002:
				moving *= exp(-9.0 * delta)
			chain.was[k] = here
			chain.at[k] = here + moving + Vector3.DOWN * 9.0 * size * delta * delta
		for pass_index in 3:
			for k in range(1, count + 1):
				var length := chain.links[k - 1].length() * size
				var along := chain.at[k] - chain.at[k - 1]
				chain.at[k] = chain.at[k - 1] + (along.normalized() if along.length_squared() > 0.000001 else Vector3.DOWN) * length
				if chain.at[k].y < ground:
					chain.at[k] = Vector3(chain.at[k].x, ground, chain.at[k].z)
				for shape in chain.shapes:
					var a := shapes[shape * 2]
					var b := shapes[shape * 2 + 1]
					var from := Vector3(a.x, a.y, a.z)
					var line := Vector3(b.x, b.y, b.z) - from
					var nearest := from + line * clampf((chain.at[k] - from).dot(line) / maxf(line.length_squared(), 0.000001), 0.0, 1.0)
					var out := chain.at[k] - nearest
					if out.length_squared() < a.w * a.w:
						chain.at[k] = nearest + (out.normalized() if out.length_squared() > 0.000001 else frame.z) * a.w
		# Each bone is turned, from how the one above it lies, to point down its link.
		var above := frame
		for k in count:
			var rest := chain.links[k].normalized()
			var lies := (above * rest).normalized()
			var wants := (chain.at[k + 1] - chain.at[k]).normalized()
			var turn := Basis.IDENTITY
			if lies.dot(wants) < -0.9999:
				turn = Basis(above.x.normalized(), PI)
			elif lies.dot(wants) < 0.9999:
				turn = Basis(Quaternion(lies, wants))
			var now := (turn * above).orthonormalized()
			_skeleton.set_bone_pose(chain.bones[k], Transform3D(above.inverse() * now, chain.origin if k == 0 else chain.links[k - 1]))
			above = now


# --- What the other kinds share ---

## Runs the swipe on, and says where it is in it: how far it is drawn back
## (x, 0..1), how far thrown forward after the blow (y, 0..1), and how far the
## blow itself is through (z, 0..1).
func _swipe_levels(delta: float) -> Vector3:
	var total := swipe_wind_up + swipe_strike + swipe_hold + swipe_recover
	if _swipe_time < total:
		_swipe_time += delta
	if _swipe_time >= total:
		return Vector3.ZERO
	var wound := smoothstep(0.0, swipe_wind_up * 0.7, _swipe_time) * (1.0 - smoothstep(swipe_wind_up, swipe_wind_up + swipe_strike * 0.5, _swipe_time))
	var struck := smoothstep(swipe_wind_up, swipe_wind_up + swipe_strike, _swipe_time) * (1.0 - smoothstep(swipe_wind_up + swipe_strike + swipe_hold, total, _swipe_time))
	return Vector3(wound, struck, clampf((_swipe_time - swipe_wind_up) / swipe_strike, 0.0, 1.0))


## Steps with each leg in turn. A whole cycle (two steps) is `stride` long, and
## each foot is off the ground for `swing` of it; `width` is how far out from
## the middle it is put down. A foot that stands stays where it is on the
## ground (the body going forward carries it back under it), and one that
## steps is brought down already going back with the ground, so that neither
## slides. Leaves `_foot_at`, `_foot_moving` and `_foot_swing` for the kind to
## shape the step from; `stepped` is called with each foot that has just come down.
func _tread(going: Vector3, turned: float, go: float, delta: float, stride: float, swing: float, width: float, stepped := Callable()) -> void:
	var speed := going.length()
	_cycle = fposmod(_cycle + speed / stride * delta, 1.0)
	# (it is walking as soon as it is really moving, though the body it is on has not yet said so)
	var walking := (go > 0.15 or speed > 0.3) and speed > 0.02
	if walking and not _trod:
		# (setting off, it steps at once, with whichever foot is further behind)
		_cycle = 0.0 if _foot_at[0].dot(ahead_of(going)) <= _foot_at[1].dot(ahead_of(going)) else 0.5
	_trod = walking
	var ahead := going / maxf(speed, 0.0001)
	# (a foot the body has been thrown clear of, by a lunge, is drawn along after it)
	var tether := stride * (1.0 - swing) * 0.5 + 0.22
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		_foot_at[i] = (_foot_at[i] - going * delta).rotated(Vector3.UP, -turned)
		var home := Vector3(side * width, 0.0, 0.0)
		if _foot_at[i].distance_to(home) > tether:
			_foot_at[i] = home + (_foot_at[i] - home).normalized() * tether
		var p := fposmod(_cycle - 0.5 * i, 1.0)
		# (it does not begin a step that is all but over, as it may be when it starts off: it waits for its next)
		var stepping := walking and p < swing and (_foot_moving[i] or p < swing * 0.8)
		if stepping and not _foot_moving[i]:
			_foot_began[i] = p
			_foot_from[i] = _foot_at[i]
			_foot_to[i] = Vector3(side * width, 0.0, 0.0) + ahead * stride * (1.0 - swing) * 0.5
		if _foot_moving[i] and not stepping and stepped.is_valid():
			stepped.call(i)
		_foot_moving[i] = stepping
		var t := (p - _foot_began[i]) / (swing - _foot_began[i])
		_foot_swing[i] = t if stepping else -1.0
		if stepping:
			# (where it is making for is still ahead of where it will come down by as far as the body has yet to go)
			_foot_at[i] = _foot_from[i].lerp(_foot_to[i] + ahead * (swing - p) * stride, t * t * (3.0 - 2.0 * t))
	if not walking:
		_feet_home(delta)


static func ahead_of(going: Vector3) -> Vector3:
	return going / maxf(going.length(), 0.0001)


## Going nowhere, each foot is shuffled back to where it stands.
func _feet_home(delta: float) -> void:
	for i in 2:
		var home := _standing(i)
		var off := _foot_at[i].distance_to(home)
		_foot_at[i] = _foot_at[i].lerp(home, 1.0 - exp(-(4.0 if off > 0.04 else 0.0) * delta)) if _posed else home
		_foot_lift[i] = lerpf(_foot_lift[i], minf(off * 0.25, 0.02), 1.0 - exp(-18.0 * delta))
		_foot_swing[i] = -1.0
		_foot_moving[i] = false


## Puts each leg to its foot, as `_foot_at`, `_foot_lift`, `_foot_toes` and
## `_foot_turn` have it; the knees `spread` apart from the way the feet point.
func _stand_legs(spread: float) -> void:
	var to_hips := _hips.transform.affine_inverse()
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var toes := _foot_toes[i]
		var target := Vector3(_foot_at[i].x, _foot_lift[i], _foot_at[i].z) + _ankle_offset(toes)
		var foot := Basis(Vector3.UP, _foot_turn[i]) * Basis(Vector3.RIGHT, toes)
		# (the toes lie flat while the ball of the foot is down, and hang a little once it is up)
		_toes[i].rotation.x = lerpf(-maxf(toes, 0.0), 0.15, smoothstep(0.0, 0.035, _foot_lift[i]))
		_solve_leg(i, side, to_hips * target, (to_hips.basis * foot).orthonormalized(), _foot_turn[i] * 0.8 + side * spread)


## How fast it is really going, in its own space: from where it was a frame ago
## and not from what its body says its speed is, which the picture of it runs a
## step behind. Feet that are moved by this stay exactly where they stand.
func _gone(delta: float) -> Vector3:
	var here := global_position
	var moved := here - _was_at if _was_at.is_finite() else Vector3.ZERO
	_was_at = here
	moved.y = 0.0
	if moved.length() > 0.5:
		# (it has been put somewhere else)
		moved = Vector3.ZERO
	return global_basis.inverse() * moved / maxf(delta, 0.0001)


## Turns an arm to put its wrist at `point` (in the world), the elbow towards
## `pole`. As CharacterRig._solve_arm, but each bone is turned about the hinge
## of the elbow and not towards the way it faces: an arm held straight out in
## front, or brought down through there, does not turn over on itself.
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


## A hand as a weight on a spring, drawn to `goal` (in the rig's own space).
func _hand_follow(i: int, goal: Vector3, stiffness: float, damping: float, delta: float) -> void:
	_hand_speed[i] += ((goal - _hand_at[i]) * stiffness - _hand_speed[i] * damping) * delta
	_hand_at[i] += _hand_speed[i] * delta
	if not _posed or _wake < 0.03:
		_hand_at[i] = goal
		_hand_speed[i] = Vector3.ZERO


## Turns `_gaze` towards what it is after, seen from `height` up it: (to the side, down), within `most`.
func _watch_him(height: float, most: Vector2, rate: float, delta: float) -> void:
	var look := Vector2.ZERO
	if aim.is_finite() and _wake > 0.5:
		var to := to_local(aim) - Vector3(0.0, height, 0.0)
		look = Vector2(clampf(atan2(to.x, to.z), -most.x, most.x), clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -most.y, most.y))
	_gaze = _gaze.lerp(look, 1.0 - exp(-rate * delta))


## A hand's fingers and wrist: how far closed, how far spread, and the wrist bent.
func _set_hand(i: int, curl: float, splay: float, wrist: float) -> void:
	_hands[i].rotation = Vector3(wrist, 0.0, 0.0)
	_curl[i] = curl
	_splay[i] = splay
	_pose_fingers(i, 1.0 if i == 0 else -1.0)

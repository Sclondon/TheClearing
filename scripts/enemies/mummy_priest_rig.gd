class_name MummyPriestRig
extends MummyRig
## The priest's way of moving (`Mummy.Kind.PRIEST`, models/enemies/mummy_priest.glb).
##
## - It walks as it was laid out: stiff and upright, on legs that do not bend.
##   Each leg is swung forward from the hip like a rod, toes up, and comes down
##   on its heel; the body goes up over the leg it stands on and down between
##   steps, as a pair of compasses walks, and turns from the hips as one piece.
##   Its pace is even: it neither lurches nor hurries.
## - Its arms stay crossed on its chest while it walks. As it nears him they
##   unfold and are held straight out at him, side by side.
## - It strikes with both: up to its full height with its arms over its head
##   (WIND_UP), then it bows from the hips, back flat, and its hands come down
##   on him a long way in front of it (STRIKE). It is slow to straighten.

## The length of a whole cycle of its walk (two steps), as modelled, and how much of it each foot is off the ground.
const STRIDE_LENGTH := 0.9
const SWING := 0.4
## How much of its length a leg is let out to: it stands just short of locked.
const STRAIGHT := 0.975

## How far through unfolding its arms it is.
var _unfold := 0.0
var _height := Vector2.ZERO


func _build() -> void:
	super()
	swipe_wind_up = 0.75
	swipe_strike = 0.2
	swipe_hold = 0.5
	swipe_recover = 0.8
	trunk_round = 0.052
	back_round = 0.086
	thigh_round = 0.04
	_hinged = true


## It has only the one way of striking: with both.
func swipe(_arm: int) -> void:
	super(2)


func pace() -> float:
	return 1.0


func _standing(i: int) -> Vector3:
	return Vector3((_hip_width + 0.012) * (1.0 if i == 0 else -1.0), 0.0, 0.0)


func _heel_down(i: int) -> void:
	_nod.y += 0.7 * _move
	_own_dust.puff(to_global(_foot_at[i] + Vector3(0.0, 0.02, -0.03)), Vector3.ZERO, 0.1, 1)


func _pose_extra(delta: float) -> void:
	var size := global_basis.get_scale().y
	var going := _gone(delta)
	var turned := angle_difference(_yaw_was, rotation.y)
	_yaw_was = rotation.y
	_wake = _approach(_wake, awake, 2.0, delta)
	var go := _move * (1.0 - _air)
	var levels := _swipe_levels(delta)
	var wound := levels.x
	var struck := levels.y
	var sweep := levels.z
	var swiping := _swipe_time < swipe_wind_up + swipe_strike + swipe_hold + swipe_recover

	# --- Its feet ---
	_tread(going, turned, go, delta, STRIDE_LENGTH, SWING, _hip_width + 0.012, _heel_down)
	for i in 2:
		var t := _foot_swing[i]
		_foot_turn[i] = 0.07 if i == 0 else -0.07
		if t >= 0.0:
			# Swung through close to the ground: it leaves toes last and its heel leads.
			_foot_lift[i] = sin(PI * t) * 0.04
			_foot_toes[i] = lerpf(0.32, -0.42, smoothstep(0.1, 0.7, t))
		elif go > 0.15:
			# Down on its heel, flat as the body comes over it, and off its toes behind.
			var z := _foot_at[i].z
			_foot_lift[i] = 0.0
			_foot_toes[i] = -0.42 * smoothstep(0.15, 0.25, z) + 0.36 * smoothstep(-0.17, -0.27, z)
		else:
			_foot_toes[i] = lerpf(_foot_toes[i], 0.0, 1.0 - exp(-14.0 * delta))

	# --- Its body ---
	var p := _cycle
	# To the side of the leg it stands on (the left swings first), and that leg's hip leading.
	var sway := -sin(TAU * (p + 0.05)) * go
	var twist := -0.11 * cos(TAU * (p - SWING)) * go
	_nod = _sprung(_nod, 0.0, 120.0, 12.0, delta)
	# Drawn up and a little back before the blow; bowed right over after it.
	var bow := 0.95 * struck - 0.14 * wound
	var back := 0.1 * struck - 0.03 * wound
	var hips_at := Vector2(sway * 0.016, -back)
	# It is as high as the legs it stands on will hold it, and no higher: they are straight.
	var top := INF
	var long := (_thigh + _shin) * STRAIGHT
	for i in 2:
		if _foot_swing[i] >= 0.0:
			continue
		var side := 1.0 if i == 0 else -1.0
		var ankle := Vector3(_foot_at[i].x, _foot_lift[i], _foot_at[i].z) + _ankle_offset(_foot_toes[i])
		var away := Vector2(ankle.x - side * _hip_width - hips_at.x, ankle.z - hips_at.y).length()
		top = minf(top, ankle.y + sqrt(maxf(long * long - away * away, 0.04)))
	if top == INF:
		top = ANKLE + long
	_height = _sprung(_height, top - _hip_drop, 900.0, 50.0, delta)
	if not _posed:
		_height = Vector2(top - _hip_drop, 0.0)
	_hips.position = Vector3(hips_at.x, minf(_height.x, top - _hip_drop + 0.004), hips_at.y)
	_hips.rotation = Vector3(-0.02 + bow * 0.58, twist, -sway * 0.05)
	_spine.rotation = Vector3(-0.03 + bow * 0.26, -twist * 0.2, sway * 0.03)
	_chest.rotation = Vector3(-0.05 + bow * 0.16, -twist * 0.2, sway * 0.02)

	# Its head is carried level and turned on him; dormant, it is bowed.
	_watch_him(_hip_height + 0.52, Vector2(1.0, 0.55), 2.2, delta)
	var face := 0.3 * (1.0 - _wake) + 0.1 + _gaze.y - bow * 0.62 + _nod.x * 0.4
	_neck.rotation = Vector3(face * 0.45, _gaze.x * 0.45, 0.0)
	_head.rotation = Vector3(face * 0.55, _gaze.x * 0.55, 0.0)

	_stand_legs(0.0)
	_priest_arms(wound, struck, sweep, swiping, delta)
	_hang_chains(size, delta)
	_posed = true


func _priest_arms(wound: float, struck: float, sweep: float, swiping: bool, delta: float) -> void:
	var mark := Vector3(0.0, 0.85, 3.0)
	if aim.is_finite():
		mark = to_local(aim)
	var level := clampf(mark.y, 0.35, 1.0)
	# They come uncrossed as it closes on him.
	var near := 1.0 - smoothstep(1.5, 2.3, Vector2(mark.x, mark.z).length())
	_unfold = _approach(_unfold, arms_reach * near, 2.2, delta)
	var chest := to_local(_chest.global_position)
	var chest_basis := (global_basis.inverse() * _chest.global_basis).orthonormalized()
	var total := swipe_wind_up + swipe_strike + swipe_hold + swipe_recover
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var shoulder := to_local(_shoulders[i].global_position)
		# Crossed: each hand flat on the other shoulder, the left over the right.
		var crossed := chest + chest_basis * Vector3(-side * 0.062, 0.105, 0.088 + 0.014 * side)
		# Held out: straight at him, level with its shoulders, a hand's breadth apart.
		var held := shoulder + Vector3(-side * 0.035, -0.04 + 0.012 * sin(_time * 1.1 + i * 1.7), 0.56)
		var goal := crossed.lerp(held, smoothstep(0.0, 1.0, _unfold) * smoothstep(0.3, 0.9, _wake))
		var pole := Vector3(side * 0.5, -1.0, 0.25).lerp(Vector3(side * 0.4, -1.0, -0.2), _unfold)
		var curl := lerpf(0.18, 0.3, _unfold)
		var splay := lerpf(0.3, 0.95, _unfold)
		var wrist := lerpf(0.75, -0.2, _unfold)
		_hand_follow(i, goal, 110.0, 16.0, delta)
		if swiping:
			# Over its head; down through where he stands; and to the ground in front of him.
			var up := Vector3(side * 0.15, _hip_height + 0.86, 0.08)
			var through := Vector3(side * 0.09, level + 0.1, 0.86)
			var done := Vector3(side * 0.035, level - 0.16, 0.8)
			var bend := through * 2.0 - (up + done) * 0.5
			var u := sweep * sweep * (3.0 - 2.0 * sweep)
			var stroke := up.lerp(bend, u).lerp(bend.lerp(done, u), u)
			var place := goal.lerp(up, smoothstep(0.0, swipe_wind_up * 0.75, _swipe_time)) if _swipe_time < swipe_wind_up else stroke
			pole = pole.lerp(Vector3(side, -0.3, -0.6), maxf(wound, struck))
			curl = lerpf(curl, lerpf(0.1, 1.1, smoothstep(0.7, 1.0, sweep)), maxf(wound, struck))
			splay = lerpf(splay, 1.3, maxf(wound, struck))
			wrist = lerpf(wrist, lerpf(-0.4, 0.3, sweep), maxf(wound, struck))
			var over := smoothstep(0.0, 0.12, _swipe_time) * (1.0 - smoothstep(total - swipe_recover * 0.8, total, _swipe_time))
			_hand_at[i] = _hand_at[i].lerp(place, over)
			_hand_speed[i] *= 1.0 - over
		_hand_to(i, _hand_at[i], pole)
		_set_hand(i, curl, splay, wrist)

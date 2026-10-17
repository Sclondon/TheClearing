class_name MummyBruteRig
extends MummyRig
## The brute's way of moving (`Mummy.Kind.BRUTE`, models/enemies/mummy_brute.glb).
##
## - It waddles. Its legs are short and set wide, so to take a step it has to
##   tip its whole weight over the other foot first: the barrel of it rolls
##   from side to side and swings round with each leg, and every foot comes
##   down flat and hard, which it sinks under and its head nods to.
## - Its arms are longer than its legs and hang like weights, knuckles near the
##   ground, swinging forward and back against its steps; after him they are
##   held out low and wide.
## - It strikes with one arm, swept round level at the height of his chest from
##   far out at its side (which goes over him if he is down); every third time
##   it brings both down from over its head instead.

const STRIDE_LENGTH := 0.58
const SWING := 0.42
## How high, as modelled, the level sweep of an arm passes.
const SWEEP_HEIGHT := 0.86


func _build() -> void:
	super()
	swipe_wind_up = 0.75
	swipe_strike = 0.22
	swipe_hold = 0.5
	swipe_recover = 0.7
	trunk_round = 0.14
	back_round = 0.16
	thigh_round = 0.075
	_hinged = true


## Slower as each foot comes down and it gathers itself, quicker as it tips onto the next.
func pace() -> float:
	return 1.0 + 0.22 * sin(TAU * 2.0 * (_cycle - 0.05))


func _standing(i: int) -> Vector3:
	return Vector3((_hip_width + 0.055) * (1.0 if i == 0 else -1.0), 0.0, 0.0)


func _stamp(i: int) -> void:
	_sink.y -= 0.5 * _move
	_nod.y += 1.3 * _move
	_own_dust.puff(to_global(_foot_at[i] + Vector3(0.0, 0.02, 0.04)), -global_basis.z * 0.15, 0.24, 3)


func _pose_extra(delta: float) -> void:
	var size := global_basis.get_scale().y
	var going := _gone(delta)
	var turned := angle_difference(_yaw_was, rotation.y)
	_yaw_was = rotation.y
	_wake = _approach(_wake, awake, 1.8, delta)
	var go := _move * (1.0 - _air)
	var levels := _swipe_levels(delta)
	var wound := levels.x
	var struck := levels.y
	var sweep := levels.z
	var swiping := _swipe_time < swipe_wind_up + swipe_strike + swipe_hold + swipe_recover
	var across := 0.0 if _swipe_arm == 2 else (1.0 if _swipe_arm == 0 else -1.0)

	# --- Its feet: lifted clear, turned well out, and set down flat ---
	_tread(going, turned, go, delta, STRIDE_LENGTH, SWING, _hip_width + 0.055, _stamp)
	for i in 2:
		var t := _foot_swing[i]
		_foot_turn[i] = 0.32 if i == 0 else -0.32
		if t >= 0.0:
			_foot_lift[i] = sin(PI * pow(t, 0.8)) * 0.055
			_foot_toes[i] = lerpf(0.3, -0.06, smoothstep(0.2, 0.9, t))
		elif go > 0.15:
			_foot_lift[i] = 0.0
			_foot_toes[i] = 0.3 * smoothstep(-0.09, -0.17, _foot_at[i].z)
		else:
			_foot_toes[i] = lerpf(_foot_toes[i], 0.0, 1.0 - exp(-14.0 * delta))

	# --- Its body ---
	var p := _cycle
	# Over the foot it stands on (the left steps first, so it starts over the right).
	var sway := -sin(TAU * (p + 0.04)) * go
	var twist := -0.2 * cos(TAU * (p - SWING)) * go
	_list = _sprung(_list, -sway * 0.17, 55.0, 6.0, delta)
	_sink = _sprung(_sink, -0.012 * go, 150.0, 12.0, delta)
	_nod = _sprung(_nod, 0.0, 50.0, 5.0, delta)
	var hunch := lerpf(0.5, 1.0, _wake)
	var lean := 0.06 * go - 0.16 * wound + 0.34 * struck
	var swing := across * (0.6 * wound - 0.85 * struck)
	var height := _hip_height - 0.05 * lerpf(0.4, 1.0, _wake) + _sink.x + 0.03 * wound - 0.06 * struck
	_hips.position = Vector3(sway * 0.06 - across * 0.03 * struck, height, -0.04 * wound + 0.1 * struck)
	_hips.rotation = Vector3(0.12 * hunch + lean * 0.4, twist + swing * 0.3, _list.x * 0.5)
	_spine.rotation = Vector3(0.14 * hunch + lean * 0.3, -twist * 0.35 + swing * 0.35, _list.x * 0.28)
	_chest.rotation = Vector3(0.2 * hunch + lean * 0.3, -twist * 0.35 + swing * 0.35, _list.x * 0.22)

	# Its head is sunk between its shoulders and looks out from under its brow; it stays the level its body does not.
	_watch_him(_hip_height + 0.45, Vector2(0.8, 0.5), 2.5, delta)
	var face := -0.46 * hunch * _wake + 0.1 * (1.0 - _wake) - lean * 0.6 + _gaze.y + _nod.x * 0.5
	_neck.rotation = Vector3(face * 0.5, _gaze.x * 0.4 - swing * 0.3, -_list.x * 0.4)
	_head.rotation = Vector3(face * 0.5, _gaze.x * 0.6 - swing * 0.4, -_list.x * 0.4)

	_stand_legs(0.12)
	_brute_arms(wound, struck, sweep, swiping, p, go, delta)
	_hang_chains(size, delta)
	_posed = true


func _brute_arms(wound: float, struck: float, sweep: float, swiping: bool, p: float, go: float, delta: float) -> void:
	var chest := to_local(_chest.global_position)
	var chest_basis := (global_basis.inverse() * _chest.global_basis).orthonormalized()
	var total := swipe_wind_up + swipe_strike + swipe_hold + swipe_recover
	var long := _upper_arm + _forearm
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var shoulder := to_local(_shoulders[i].global_position)
		# Dormant: folded on its chest, as far as arms like these fold.
		var crossed := chest + chest_basis * Vector3(-side * 0.1, 0.08, 0.2 + 0.03 * side)
		# Awake: hanging, and swung against the legs (the left goes forward with the right foot).
		var swung := cos(TAU * p) * side * 0.2 * go
		var hanging := shoulder + Vector3(side * 0.11, -long * 0.9, 0.1 + swung)
		# After him: out in front, low and wide.
		var held := shoulder + Vector3(side * 0.2, -0.36 + 0.02 * sin(_time * 1.2 + i * 2.0), 0.42 + swung * 0.4)
		var goal := crossed.lerp(hanging.lerp(held, arms_reach), smoothstep(0.15, 0.9, _wake))
		var pole := Vector3(side * 0.5, -1.0, 0.3).lerp(Vector3(side * 1.0, -0.6, -0.4), _wake)
		var curl := lerpf(0.4, lerpf(1.0, 0.6, arms_reach), _wake)
		var splay := lerpf(0.3, lerpf(0.3, 1.0, arms_reach), _wake)
		var wrist := lerpf(0.7, lerpf(0.25, -0.2, arms_reach), _wake)
		_hand_follow(i, goal, 34.0, 4.5, delta)
		if swiping:
			var taking := _swipe_arm == 2 or _swipe_arm == i
			var place := _hand_at[i]
			if taking:
				# Far out at its side and behind; round, level, through where he stands; and on across itself.
				var back := Vector3(side * 0.74, SWEEP_HEIGHT, -0.3)
				var through := Vector3(side * 0.12, SWEEP_HEIGHT, 0.84)
				var done := Vector3(-side * 0.5, SWEEP_HEIGHT, 0.36)
				if _swipe_arm == 2:
					# (both: up over its head, and down onto the ground in front of it)
					back = Vector3(side * 0.3, _hip_height + 0.86, -0.12)
					through = Vector3(side * 0.2, 0.7, 0.74)
					done = Vector3(side * 0.13, 0.14, 0.66)
				var bend := through * 2.0 - (back + done) * 0.5
				var u := sweep * sweep * (3.0 - 2.0 * sweep)
				var stroke := back.lerp(bend, u).lerp(bend.lerp(done, u), u)
				place = goal.lerp(back, smoothstep(0.0, swipe_wind_up * 0.75, _swipe_time)) if _swipe_time < swipe_wind_up else stroke
				pole = pole.lerp(Vector3(side, 0.4, -0.6) if _swipe_arm == 2 else Vector3(side * 0.3, -1.0, -0.5), maxf(wound, struck))
				curl = lerpf(curl, lerpf(0.1, 1.1, smoothstep(0.75, 1.0, sweep)), maxf(wound, struck))
				splay = lerpf(splay, 1.3, maxf(wound, struck))
				wrist = lerpf(wrist, lerpf(-0.4, 0.3, sweep), maxf(wound, struck))
			else:
				# The other is thrown out behind it, for balance.
				place = goal + Vector3(side * 0.16, 0.06, -0.3) * wound + Vector3(side * 0.24, 0.1, -0.5) * struck
			var over := smoothstep(0.0, 0.12, _swipe_time) * (1.0 - smoothstep(total - swipe_recover * 0.8, total, _swipe_time))
			_hand_at[i] = _hand_at[i].lerp(place, over)
			_hand_speed[i] *= 1.0 - over
		_hand_to(i, _hand_at[i], pole)
		_set_hand(i, curl, splay, wrist)


## Its hands are big: the line of a sweeping arm runs further past the wrist,
## straight on from the forearm (so that a level sweep is level all along it).
func claw(i: int) -> PackedVector3Array:
	var elbow := _elbows[i].global_position
	var wrist := _hands[i].global_position
	return PackedVector3Array([wrist.lerp(elbow, 0.35), wrist + (wrist - elbow).normalized() * 0.2 * global_basis.get_scale().y])

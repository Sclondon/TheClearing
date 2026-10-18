class_name MummyChildRig
extends MummyRig
## The child's way of moving (`Mummy.Kind.CHILD`, models/enemies/mummy_child.glb).
## (In Warren: Outside's `_burst` and `_burst_pace` are `_spurt` and `_spurt_pace`
## here, as GameCommon's CharacterRig has a `_burst` of its own.)
##
## - It scuttles. It goes in bursts, each as long as it happens to be and not
##   quite as fast as the last, and between them it stops dead (`pace` is what
##   tells the body so): bolt upright, its hands drawn up to its chest, its big
##   head tipped to one side, looking at him.
## - In a burst it is thrown forward and low on bent legs and runs on its toes,
##   with steps too quick for its size, both feet off the ground between them;
##   its arms trail out behind it and its head is held back to see where he is.
## - It strikes by springing: down on its haunches (WIND_UP), then up and at
##   him with both arms thrown out (STRIKE), and lands in a heap.

const STRIDE_LENGTH := 0.9
## (more than half: there is a moment in each step when neither foot is down)
const SWING := 0.62

## How long the burst it is in has left, or the stop; and how fast this burst is.
var _spurt := 0.5
var _stop := 0.0
var _spurt_pace := 1.0
## Which way its head is tipped while it looks, and how upright it has come.
var _tip := 1.0
var _still := 0.0


func _build() -> void:
	super()
	swipe_wind_up = 0.28
	swipe_strike = 0.2
	swipe_hold = 0.3
	swipe_recover = 0.4
	trunk_round = 0.07
	back_round = 0.075
	thigh_round = 0.04
	_hinged = true


func swipe(_arm: int) -> void:
	super(2)


func settle() -> void:
	super()
	_spurt = 0.5
	_stop = 0.0
	_still = 0.0


func pace() -> float:
	return 0.0 if _stop > 0.0 else _spurt_pace


func _standing(i: int) -> Vector3:
	return Vector3((_hip_width + 0.012) * (1.0 if i == 0 else -1.0), 0.0, 0.02 if i == 0 else -0.02)


func _patter(i: int) -> void:
	_sink.y -= 0.25 * _move
	_own_dust.puff(to_global(_foot_at[i] + Vector3(0.0, 0.02, 0.0)), -global_basis.z * 0.3, 0.08, 1)


func _pose_extra(delta: float) -> void:
	var size := global_basis.get_scale().y
	var going := _gone(delta)
	var turned := angle_difference(_yaw_was, rotation.y)
	_yaw_was = rotation.y
	_wake = _approach(_wake, awake, 4.0, delta)
	var go := _move * (1.0 - _air)
	var levels := _swipe_levels(delta)
	var wound := levels.x
	var struck := levels.y
	var sweep := levels.z
	var total := swipe_wind_up + swipe_strike + swipe_hold + swipe_recover
	var swiping := _swipe_time < total

	# Its bursts and its stops, while it is up and about.
	if awake > 0.5 and not swiping:
		if _stop > 0.0:
			_stop -= delta
			if _stop <= 0.0:
				_spurt = randf_range(0.4, 1.0)
				_spurt_pace = randf_range(0.8, 1.15)
		else:
			_spurt -= delta
			if _spurt <= 0.0:
				_stop = randf_range(0.25, 0.6)
				_tip = -1.0 if randf() < 0.5 else 1.0
	_still = _approach(_still, 1.0 - clampf(go * 1.6, 0.0, 1.0), 14.0, delta)
	var run := 1.0 - _still

	# --- Its feet: on its toes, knees up, quick ---
	_tread(going, turned, go, delta, STRIDE_LENGTH, SWING, _hip_width * 0.6, _patter)
	for i in 2:
		var t := _foot_swing[i]
		_foot_turn[i] = 0.1 if i == 0 else -0.1
		if t >= 0.0:
			_foot_lift[i] = sin(PI * pow(t, 0.7)) * 0.1
			_foot_toes[i] = lerpf(1.0, 0.32, smoothstep(0.25, 0.95, t))
		elif go > 0.15:
			_foot_lift[i] = 0.0
			_foot_toes[i] = lerpf(0.32, 0.8, smoothstep(0.1, -0.16, _foot_at[i].z))
		else:
			_foot_toes[i] = lerpf(_foot_toes[i], 0.0, 1.0 - exp(-14.0 * delta))
	# The spring: both feet leave the ground with it.
	var hop := sin(PI * clampf((_swipe_time - swipe_wind_up) / (swipe_strike + 0.12), 0.0, 1.0)) if swiping else 0.0
	for i in 2:
		_foot_lift[i] += hop * 0.1
		_foot_toes[i] = lerpf(_foot_toes[i], 0.7, hop)

	# --- Its body ---
	var p := _cycle
	var twist := -0.16 * cos(TAU * (p - SWING)) * run
	_sink = _sprung(_sink, 0.0, 260.0, 16.0, delta)
	_lurch = _sprung(_lurch, 0.42 * run, 70.0, 11.0, delta)
	var lean := _lurch.x - 0.12 * wound + 0.5 * struck
	var crouch := 0.075 * run + 0.02 * lerpf(1.0, 0.0, _wake) + 0.13 * wound + 0.07 * struck * (1.0 - hop)
	var height := _hip_height - 0.012 - crouch + _sink.x + 0.016 * absf(sin(TAU * p)) * run + hop * 0.17
	_hips.position = Vector3(0.0, height, 0.02 * run - 0.05 * wound + 0.1 * struck)
	_hips.rotation = Vector3(lean * 0.55, twist, 0.0)
	_spine.rotation = Vector3(lean * 0.25 + 0.2 * wound, -twist * 0.8, 0.0)
	_chest.rotation = Vector3(lean * 0.2 + 0.15 * wound, -twist * 0.7, 0.0)

	# Its head: back on its neck to see him as it runs; tipped over to one side while it looks.
	_watch_him(_hip_height + 0.4, Vector2(1.2, 0.7), 9.0, delta)
	_loll = _sprung(_loll, _tip * 0.38 * _still * _wake * (0.0 if swiping else 1.0), 120.0, 9.0, delta)
	var face := -lean * 0.85 + 0.3 * (1.0 - _wake) + _gaze.y - 0.3 * wound
	_neck.rotation = Vector3(face * 0.5, _gaze.x * 0.45, _loll.x * 0.45)
	_head.rotation = Vector3(face * 0.5, _gaze.x * 0.55, _loll.x * 0.55)

	_stand_legs(0.1)
	_child_arms(wound, struck, sweep, swiping, run, delta)
	_hang_chains(size, delta)
	_posed = true


func _child_arms(wound: float, struck: float, sweep: float, swiping: bool, run: float, delta: float) -> void:
	var mark := Vector3(0.0, 0.8, 2.0)
	if aim.is_finite():
		mark = to_local(aim)
	var level := clampf(mark.y, 0.3, 1.05)
	var chest := to_local(_chest.global_position)
	var chest_basis := (global_basis.inverse() * _chest.global_basis).orthonormalized()
	var total := swipe_wind_up + swipe_strike + swipe_hold + swipe_recover
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var shoulder := to_local(_shoulders[i].global_position)
		var crossed := chest + chest_basis * Vector3(-side * 0.04, 0.07, 0.085 + 0.012 * side)
		# Stopped: drawn up to its chest, the hands hanging from the wrists.
		var drawn := shoulder + Vector3(-side * 0.02, -0.15, 0.14 + 0.012 * sin(_time * 5.0 + i * 2.0))
		# Running: trailed out behind it and to the side, and shaken by every step.
		var trailed := shoulder + Vector3(side * 0.13, -0.17 + 0.012 * sin(TAU * _cycle + i * PI), -0.27)
		var goal := crossed.lerp(drawn.lerp(trailed, run), smoothstep(0.15, 0.9, _wake))
		var pole := Vector3(side * 0.5, -1.0, 0.25).lerp(Vector3(side * 0.8, -1.0, -0.2).lerp(Vector3(side * 0.7, 0.6, -0.4), run), _wake)
		var curl := lerpf(0.25, lerpf(0.7, 0.3, run), _wake)
		var splay := lerpf(0.4, lerpf(0.5, 1.0, run), _wake)
		var wrist := lerpf(0.8, lerpf(0.9, -0.2, run), _wake)
		_hand_follow(i, goal, 95.0 if i == 0 else 70.0, 8.0 if i == 0 else 6.0, delta)
		if swiping:
			# Down and back; and flung up at him, both together.
			var back := shoulder + Vector3(side * 0.27, -0.2, -0.1)
			var through := Vector3(side * 0.22, minf(level + 0.1, shoulder.y + 0.12), 0.3)
			var done := Vector3(side * 0.04, minf(level - 0.04, shoulder.y), 0.34)
			var bend := through * 2.0 - (back + done) * 0.5
			var u := sweep * sweep * (3.0 - 2.0 * sweep)
			var stroke := back.lerp(bend, u).lerp(bend.lerp(done, u), u)
			var place := goal.lerp(back, smoothstep(0.0, swipe_wind_up * 0.75, _swipe_time)) if _swipe_time < swipe_wind_up else stroke
			pole = pole.lerp(Vector3(side, -0.15, -0.1), maxf(wound, struck))
			curl = lerpf(curl, lerpf(0.1, 1.15, smoothstep(0.3, 1.0, sweep)), maxf(wound, struck))
			splay = lerpf(splay, 1.35, maxf(wound, struck))
			wrist = lerpf(wrist, -0.3, maxf(wound, struck))
			var over := smoothstep(0.0, 0.08, _swipe_time) * (1.0 - smoothstep(total - swipe_recover * 0.8, total, _swipe_time))
			_hand_at[i] = _hand_at[i].lerp(place, over)
			_hand_speed[i] *= 1.0 - over
		_hand_to(i, _hand_at[i], pole)
		_set_hand(i, curl, splay, wrist)


## Its arms are short: the line of one runs from its elbow only a little past its hand.
func claw(i: int) -> PackedVector3Array:
	return PackedVector3Array([_elbows[i].global_position, _hands[i].global_transform * Vector3(0.0, -0.11, 0.0)])

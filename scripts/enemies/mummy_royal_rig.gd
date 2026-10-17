class_name MummyRoyalRig
extends MummyRig
## The royal one's way of moving (`Mummy.Kind.ROYAL`, models/enemies/mummy_royal.glb).
##
## - It glides. Its steps are long, slow and all alike, each foot drawn forward
##   close over the ground, pointed, and set down toes first on the line the
##   other foot is on, as in a procession; its hips are carried at one height
##   and its shoulders square to the front, so that above the knees nothing of
##   it seems to move at all. It never goes faster or slower than this.
## - Its arms are crossed on its chest, as it was buried: the crook in its
##   right fist lying up over its left shoulder, the flail in its left over its
##   right. (Each is modelled running on from the fist in a line with the
##   forearm, so the arm alone places it. The strings of the flail and the
##   lappets of its headcloth are loose ends, and swing as the first mummy's
##   bandages do.)
## - It strikes with the crook and goes on walking as it does: the arm unfolds
##   and is carried up and out behind its shoulder (WIND_UP, which is long: he
##   can see it coming), and the crook is brought down and across through where
##   he stands, a long way in front of it (STRIKE). `claw` is the crook's line.

const STRIDE_LENGTH := 0.66
const SWING := 0.36
## How far past the wrist the crook reaches, as modelled.
const CROOK := 0.52


func _build() -> void:
	super()
	swipe_wind_up = 0.9
	swipe_strike = 0.2
	swipe_hold = 0.3
	swipe_recover = 0.7
	trunk_round = 0.08
	back_round = 0.125
	thigh_round = 0.05
	_hinged = true


## It strikes only with the crook, which is in its right hand.
func swipe(_arm: int) -> void:
	super(1)


func pace() -> float:
	return 1.0


func _standing(i: int) -> Vector3:
	return Vector3((_hip_width * 0.85) * (1.0 if i == 0 else -1.0), 0.0, 0.0)


func claw(i: int) -> PackedVector3Array:
	var hand := _hands[i].global_transform
	return PackedVector3Array([hand.origin, hand * Vector3(0.0, -CROOK, 0.03)])


func _pose_extra(delta: float) -> void:
	var size := global_basis.get_scale().y
	var going := _gone(delta)
	var turned := angle_difference(_yaw_was, rotation.y)
	_yaw_was = rotation.y
	_wake = _approach(_wake, awake, 1.2, delta)
	var go := _move * (1.0 - _air)
	var levels := _swipe_levels(delta)
	var wound := levels.x
	var struck := levels.y
	var sweep := levels.z
	var total := swipe_wind_up + swipe_strike + swipe_hold + swipe_recover
	var swiping := _swipe_time < total

	# --- Its feet: skimmed forward, pointed, and set down toes first ---
	_tread(going, turned, go, delta, STRIDE_LENGTH, SWING, _hip_width * 0.5)
	var reach := STRIDE_LENGTH * (1.0 - SWING) * 0.5
	for i in 2:
		var t := _foot_swing[i]
		_foot_turn[i] = 0.16 if i == 0 else -0.16
		if t >= 0.0:
			_foot_lift[i] = sin(PI * t) * 0.022
			_foot_toes[i] = lerpf(0.5, 0.3, smoothstep(0.1, 0.8, t))
		elif go > 0.15:
			# The heel is let down after the toes, and peels up again as the foot is left behind.
			var z := _foot_at[i].z
			_foot_lift[i] = 0.0
			_foot_toes[i] = 0.3 * smoothstep(reach - 0.11, reach, z) + 0.5 * smoothstep(-reach + 0.12, -reach, z)
		else:
			_foot_toes[i] = lerpf(_foot_toes[i], 0.0, 1.0 - exp(-14.0 * delta))

	# --- Its body: level, square, upright ---
	var p := _cycle
	var twist := -0.07 * cos(TAU * (p - SWING)) * go
	# The blow turns it: its right shoulder goes back with the crook and comes through with it.
	var swing := -0.4 * wound + 0.45 * struck
	var height := _hip_height - lerpf(0.015, 0.045, smoothstep(0.0, 1.0, _wake))
	_hips.position = Vector3(-sin(TAU * (p + 0.05)) * 0.008 * go, height, 0.0)
	_hips.rotation = Vector3(-0.02 + 0.1 * struck, twist + swing * 0.3, 0.0)
	_spine.rotation = Vector3(-0.03 + 0.08 * struck, -twist * 0.5 + swing * 0.35, 0.0)
	_chest.rotation = Vector3(-0.04 + 0.08 * struck - 0.06 * wound, -twist * 0.5 + swing * 0.35, 0.0)

	# Its head comes up as it wakes, and turns to him slowly and no further than it need.
	_watch_him(_hip_height + 0.5, Vector2(0.7, 0.35), 1.3, delta)
	var face := 0.22 * (1.0 - _wake) - 0.03 + _gaze.y * 0.8
	_neck.rotation = Vector3(face * 0.5, _gaze.x * 0.5 - swing * 0.5, 0.0)
	_head.rotation = Vector3(face * 0.5, _gaze.x * 0.5 - swing * 0.5, 0.0)

	_stand_legs(0.05)

	# --- Its arms ---
	var mark := Vector3(0.0, 0.8, 3.0)
	if aim.is_finite():
		mark = to_local(aim)
	var level := clampf(mark.y, 0.3, 0.95)
	var chest := to_local(_chest.global_position)
	var chest_basis := (global_basis.inverse() * _chest.global_basis).orthonormalized()
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		# Crossed: each fist in the middle of its chest, the left wrist over the right.
		var crossed := chest + chest_basis * Vector3(-side * 0.012, 0.055 + 0.012 * side, 0.118 + 0.016 * side)
		var pole := Vector3(side * 0.9, -1.0, 0.1)
		var place := crossed
		if swiping and i == 1:
			# Up and out behind its right shoulder; down through where he stands; and across to its left.
			var back := Vector3(-0.42, _hip_height + 0.62, -0.16)
			var through := Vector3(-0.1, level + 0.16, 0.66)
			var done := Vector3(0.24, level - 0.04, 0.46)
			var bend := through * 2.0 - (back + done) * 0.5
			var u := sweep * sweep * (3.0 - 2.0 * sweep)
			var stroke := back.lerp(bend, u).lerp(bend.lerp(done, u), u)
			var blow := crossed.lerp(back, smoothstep(0.0, swipe_wind_up * 0.8, _swipe_time)) if _swipe_time < swipe_wind_up else stroke
			var over := smoothstep(0.0, 0.15, _swipe_time) * (1.0 - smoothstep(total - swipe_recover * 0.85, total, _swipe_time))
			place = crossed.lerp(blow, over)
			pole = pole.lerp(Vector3(-1.0, 0.2, -0.6), maxf(wound, struck))
		_hand_at[i] = place
		_hand_to(i, place, pole)
		# (fists, round what they hold)
		_set_hand(i, 1.35, 0.2, 0.0)

	_hang_chains(size, delta)
	_posed = true

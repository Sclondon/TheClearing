class_name GestureRig
extends CharacterRig
## The boy's rig (CharacterRig) with a few gestures laid over whatever else he
## is doing, for someone who cannot speak to the player but has to tell them
## something: come on, over here, that way. No voice, only the arms.
##
## - BECKON: the right hand up in front of him, palm in, waving him on towards
##   himself, again and again ("come on, follow me").
## - WAVE: both arms up over his head, swept from side to side ("over here!").
## - POINT: the right arm out straight along `point_way` ("that way").
##
## Set `gesture` (NONE stops); it is eased in and out, and one gives way to the
## next. The rest of him goes on as it was: he can beckon at a walk, and wave as
## he runs (the arm swing gives way to it).

enum Gesture { NONE, BECKON, WAVE, POINT }

var gesture := Gesture.NONE
## Which way to point, in the world (level is best).
var point_way := Vector3.FORWARD

## How far into the gesture he is, 0..1, and which gesture that is (the one
## asked for, once the last has eased out).
var _gesture_amount := 0.0
var _gesture_shown := Gesture.NONE
var _gesture_time := 0.0


func _pose_extra(delta: float) -> void:
	super(delta)
	if _shoulders.size() < 2 or _ragdoll:
		return
	var wanted := 1.0 if gesture != Gesture.NONE and gesture == _gesture_shown else 0.0
	if _gesture_amount < 0.03 and gesture != _gesture_shown:
		_gesture_shown = gesture
		_gesture_time = 0.0
	_gesture_amount = _approach(_gesture_amount, wanted, 7.0 if wanted > 0.0 else 9.0, delta)
	if _gesture_amount < 0.01 or _gesture_shown == Gesture.NONE:
		return
	_gesture_time += delta
	var t := _gesture_time
	var weight := smoothstep(0.0, 1.0, _gesture_amount)
	var forward := global_basis.z.normalized()
	var left := global_basis.x.normalized()
	var up := global_basis.y.normalized()
	var size := global_basis.get_scale().y
	match _gesture_shown:
		Gesture.BECKON:
			# The right hand out before him at chest height, palm up and in, the
			# forearm drawn back towards him, out, and back again.
			var from := _shoulders[1].global_position
			var come := 0.5 + 0.5 * sin(t * 8.5)
			var hand := from + (forward * lerpf(0.36, 0.2, come) + up * lerpf(0.02, 0.13, come) - left * 0.1) * size
			_solve_arm(1, -1.0, hand, _forearm, weight, Vector3.DOWN - left * 0.7 - forward * 0.2)
			_curl[1] = lerpf(_curl[1], lerpf(0.2, 0.9, come), weight)
			_pose_fingers(1, -1.0)
			# (and he leans a little after it, his head tipped to say "this way")
			_head.rotate_object_local(Vector3.FORWARD, -0.12 * weight)
		Gesture.WAVE:
			# Both arms up over his head, swept from side to side together.
			var sweep := sin(t * 7.0)
			for i in 2:
				var side := 1.0 if i == 0 else -1.0
				var from := _shoulders[i].global_position
				var hand := from + (up * 0.36 + left * (side * 0.12 + sweep * 0.14) + forward * 0.06) * size
				_solve_arm(i, side, hand, _forearm, weight, left * side + Vector3.DOWN * 0.3)
				_curl[i] = lerpf(_curl[i], 0.1, weight)
				_pose_fingers(i, side)
		Gesture.POINT:
			# The right arm out straight, a finger along it.
			var way := point_way.normalized() if point_way.length_squared() > 0.001 else forward
			var from := _shoulders[1].global_position
			var hand := from + (way * 0.4 + up * 0.04) * size
			_solve_arm(1, -1.0, hand, _forearm, weight)
			_curl[1] = lerpf(_curl[1], 0.25, weight)
			_pose_fingers(1, -1.0)

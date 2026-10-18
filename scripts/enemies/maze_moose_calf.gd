class_name MazeMooseCalf
extends MazeMoose
## A moose calf (with its mother, MazeMoose.family): red-brown, half her size,
## all legs. It keeps near her, wandering about her as she browses and wading
## in after her; when she warns or charges anyone it scrambles round behind
## her, away from them; with a hunter after it, it runs to her. It catches
## nobody, but anyone near it is too near her. It is a kind of its own to the
## world's life (Ecology): smaller, and so the hunters' prey, which its mother
## does not allow.

## How far about its mother it wanders, m.
@export var stray := 4.0

var _about := Vector3.ZERO
var _about_left := 0.0


func is_calf() -> bool:
	return true


func _physics_process(delta: float) -> void:
	if puppet or maze == null:
		super(delta)
		return
	_sense(delta)
	_mode_time += delta
	var wish := Vector3.ZERO
	var speed := 0.0
	var mum := mother if mother and is_instance_valid(mother) and not mother.dead else null
	_point = Vector3.INF
	if mum:
		_go(Mode.FOLLOW)
		var spot: Vector3
		var hers := mum._target if mum.mode in [Mode.WARN, Mode.CHARGE, Mode.KNOCK, Mode.STRIKE, Mode.BLOW] else null
		if hers and is_instance_valid(hers):
			# (round behind her, away from what she faces)
			var away := mum.global_position - hers.global_position
			away.y = 0.0
			spot = mum.global_position + (away.normalized() if away.length() > 0.1 else Vector3.BACK) * 3.0
			_point = hers.global_position + Vector3.UP
		elif threat and is_instance_valid(threat) and not threat.dead:
			spot = mum.global_position
		else:
			_about_left -= delta
			if _about_left <= 0.0:
				_about_left = _rng.randf_range(5.0, 10.0)
				var round_about := _rng.randf_range(0.0, TAU)
				_about = Vector3(cos(round_about), 0.0, sin(round_about)) * _rng.randf_range(1.8, stray)
			spot = mum.global_position + _about
		var to := spot - global_position
		to.y = 0.0
		if to.length() > 1.0:
			wish = nav.waypoint(global_position, spot, MazeNav.clearance_for(_radius)) - global_position
			speed = clampf(to.length() * 0.9, walk_speed, trot_speed * (1.2 if hers or threat else 0.7))
	elif threat and is_instance_valid(threat) and not threat.dead:
		_go(Mode.FLEE)
		wish = way(_radius)
		speed = trot_speed
	else:
		_go(Mode.BROWSE)
	chasing = false
	if wish.length() > 0.01:
		wish = Vector3(wish.x, 0.0, wish.z).normalized()
	_drive(wish, speed, turn_rate * 1.6, delta, is_on_floor())


func _process(delta: float) -> void:
	super(delta)
	if moose and not _far:
		# (it browses when she does, and watches what she watches)
		var mum := mother if mother and is_instance_valid(mother) else null
		var slow := Vector2(velocity.x, velocity.z).length() < 0.35
		moose.browsing = slow and mum != null and mum.mode == Mode.BROWSE and _flat(home()) >= pool_radius * 0.85
		moose.grazing = slow and mum != null and mum.mode == Mode.BROWSE and _flat(home()) < pool_radius * 0.85
		moose.alert = mum != null and mum.mode in [Mode.WATCH, Mode.WARN, Mode.BLOW]
		moose.bristling = false
		moose.lowered = false
		moose.look_at_point = _point if _point.is_finite() else (mum._point if mum else Vector3.INF)

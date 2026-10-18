class_name BatColony
extends Node3D
## A colony of big bats: how they look and how they fly, and nothing else. It
## knows nothing of the game it is in; a game tells it three things, and it
## does the rest:
##
## - WHERE THEY ROOST: `set_roost(point, out)`, a point on a wall (or under a
##   ledge or a ceiling) and the way out of that surface. They hang there head
##   down in a clump, wings wrapped round them, asleep: they breathe and sway,
##   and now and then one shuffles, half opens its wings and wraps them again.
## - WHETHER THEY ARE AWAKE: `awake = true` and they let go one after another,
##   falling head first as they open their wings, and are away. `awake = false`
##   and they each make their way back to their place at the roost, flutter in,
##   turn over and hang.
## - WHAT THEY ARE AFTER: `target`, a point in the world (a head, say), or
##   `Vector3.INF` for nothing. Awake, with a target, they whirl round it in a
##   cloud, each on its own orbit (some wide, some tight, at different heights
##   and speeds, a few the other way round), and every few seconds one breaks
##   off and dives at it. Awake with no target they mill about `rally` (by
##   default a little out and down from the roost). Move the target and they
##   follow it, as fast as `speed`.
##
## How they fly: each bat is steered towards where it wants to be by a spring
## (so they overshoot and swing round), kept off the others, and turned the way
## it is going and banked into its turns. It beats its wings hard to climb, to
## turn hard and to catch up, and glides on held wings between whiles when it
## can; its body bobs against each beat.
##
## Optional: `keep_in`, a Callable(point: Vector3) -> Vector3 that moves a
## point to where bats may fly (out of walls, say); each bat's goal is passed
## through it. The bats themselves are not collided with anything.
##
## Drawn as ONE MultiMesh (BatBody's mesh and shader: wings beaten, bent and
## folded in the vertex shader from per-bat custom data), so a colony is one
## draw call. It casts no shadow. Hanging, out of `view_range` from the camera,
## it does no work at all; nearer, or flying, it moves every bat each frame
## (a dozen bats is a fraction of a millisecond).
##
## The bats are made from `colony_seed`: two colonies made with the same seed,
## count and roost are the same bats in the same places on their roost, and
## fly the same orbits (they drift apart in the details, which no one can tell).
##
## The bats' positions are in the world; this node's own transform does nothing
## but say where the colony is for `view_range`. Signals: `woke` (the first one
## lets go), `settled` (the last one is hanging again), for sounds.

signal woke
signal settled

enum Phase { HANG, DROP, FLY, HOME, LAND }

@export_range(1, 64) var count := 12
## Wing tip to wing tip, metres (each bat is a little more or less).
@export var wingspan := 1.4
@export var colony_seed := 0
## Top speed in the air, metres a second.
@export var speed := 11.0
## Wingbeats a second, flapping hard.
@export var flap_rate := 4.0
## How far out from the target they whirl (least, most), and how high over it.
@export var swirl_radius := Vector2(1.3, 2.6)
@export var swirl_height := 0.25
## What is at the target (a head and the shoulders under it): how far round it
## is, how far down it goes, and how clear of it they keep (wing tips and all),
## except while one dives at it.
@export var target_radius := 0.3
@export var target_depth := 0.8
@export var clearance := 0.3
## Seconds between one bat's dives at the target (least, most).
@export var dive_every := Vector2(2.5, 6.0)
## How wide and how deep the clump at the roost is.
@export var cluster := Vector2(2.6, 1.3)
## Further than this from the camera, a colony that is all hanging is not touched.
@export var view_range := 90.0
@export_group("Look")
@export var fur := Color(0.13, 0.115, 0.11)
## The lighter fur over the shoulders and chest.
@export var mantle := Color(0.22, 0.185, 0.16)
## The wings (and the backs of the ears), and the insides of the ears.
@export var skin := Color(0.1, 0.086, 0.085)
@export var ear := Color(0.36, 0.26, 0.25)
@export var eye := Color(0.95, 0.88, 0.72)

## Awake: off the roost and flying. Asleep: back to the roost and hanging.
var awake := false:
	set(value):
		if value == awake:
			return
		awake = value
		_turned_over()
## What they whirl round, in the world (INF: nothing).
var target := Vector3.INF
## Where they mill when awake with nothing to go after (INF: out from the roost).
var rally := Vector3.INF
## Optional: Callable(point: Vector3) -> Vector3, moving a goal to where bats may fly.
var keep_in := Callable()
## Frozen: they are not moved at all, only posed by `pose_bat` (for pictures of them).
var frozen := false

var _roost := Vector3.ZERO
var _out := Vector3.BACK
var _mesh: MultiMeshInstance3D
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _target_was := Vector3.INF
var _target_moving := Vector3.ZERO
var _hanging := 0

# Each bat: what it is doing, how long it has been doing it (or until it does),
# where it is and how it is going, how it is turned, its wingbeat, how hard it
# beats, how far its wings are folded, its place at the roost, its size and
# tone, its orbit (how far out, how fast, where round, how high it bobs and how
# fast), and its moments: a dive or a glide or a stretch (seconds left, and
# until the next).
var _phase := PackedInt32Array()
var _clock := PackedFloat32Array()
var _at := PackedVector3Array()
var _moving := PackedVector3Array()
var _turn: Array[Quaternion] = []
var _beat := PackedFloat32Array()
var _strength := PackedFloat32Array()
var _fold := PackedFloat32Array()
var _slot := PackedVector3Array()
var _size := PackedFloat32Array()
var _hover := PackedFloat32Array()
var _orbit := PackedVector4Array()
var _round := PackedFloat32Array()
var _dive := PackedVector2Array()
var _glide := PackedVector2Array()
var _stretch := PackedVector2Array()
var _land_from: Array[Transform3D] = []


func _ready() -> void:
	_mesh = MultiMeshInstance3D.new()
	_mesh.name = "Bats"
	_mesh.top_level = true
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.material_override = BatBody.material(fur, mantle, skin, ear, eye)
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = BatBody.mesh()
	many.instance_count = count
	_mesh.multimesh = many
	add_child(_mesh)
	_mesh.global_transform = Transform3D.IDENTITY
	_make_bats()
	settle()


## Where they hang: a point on a surface, and the way out of it (away from the wall).
func set_roost(point: Vector3, out: Vector3) -> void:
	_roost = point
	_out = out.normalized() if out.length() > 0.01 else Vector3.BACK
	if is_inside_tree():
		_place_slots()


func roost() -> Vector3:
	return _roost


## Every bat hanging in its place at once, asleep (for when the colony is put somewhere).
func settle() -> void:
	awake = false
	if _phase.size() != count:
		return
	for i in count:
		_phase[i] = Phase.HANG
		_fold[i] = 1.0
		_strength[i] = 0.0
		_moving[i] = Vector3.ZERO
		var hang := _hang_transform(i, 0.0)
		_at[i] = hang.origin
		_turn[i] = hang.basis.get_rotation_quaternion()
	_hanging = count
	_draw_all()


## Whether every one is hanging at the roost.
func all_home() -> bool:
	return _hanging == count


## How many are in the air.
func flying() -> int:
	return count - _hanging


## The middle of the colony, as it is now.
func centre() -> Vector3:
	var sum := Vector3.ZERO
	for i in count:
		sum += _at[i]
	return sum / maxf(count, 1)


## Where bat `i` is.
func bat_position(i: int) -> Vector3:
	return _at[i]


## Poses bat `i` by hand (with `frozen` set): where and how it is turned, its
## wingbeat (0..1, 0 at the top), how hard it beats (0 held out, gliding), how
## far folded, and how much it is hovering (deep, cupped strokes).
func pose_bat(i: int, where: Transform3D, beat: float, strength: float, fold: float, hover := 0.0) -> void:
	_hover[i] = hover
	_at[i] = where.origin
	_turn[i] = where.basis.get_rotation_quaternion()
	_beat[i] = beat
	_strength[i] = strength
	_fold[i] = fold
	_draw(i)


func _make_bats() -> void:
	_rng.seed = colony_seed
	# (each one by name: packed arrays are copied, not shared, when put in a list)
	_phase.resize(count)
	_clock.resize(count)
	_at.resize(count)
	_moving.resize(count)
	_beat.resize(count)
	_strength.resize(count)
	_fold.resize(count)
	_slot.resize(count)
	_size.resize(count)
	_hover.resize(count)
	_orbit.resize(count)
	_round.resize(count)
	_dive.resize(count)
	_glide.resize(count)
	_stretch.resize(count)
	_turn.resize(count)
	_land_from.resize(count)
	for i in count:
		_size[i] = wingspan * _rng.randf_range(0.82, 1.12)
		var wide := _rng.randf_range(swirl_radius.x, swirl_radius.y)
		var fast := _rng.randf_range(1.5, 2.6) * (-1.0 if _rng.randf() < 0.25 else 1.0)
		_orbit[i] = Vector4(wide, fast, _rng.randf_range(0.25, 0.8), _rng.randf_range(0.6, 1.4))
		_round[i] = _rng.randf_range(0.0, TAU)
		_beat[i] = _rng.randf()
		_dive[i] = Vector2(0.0, _rng.randf_range(0.5, dive_every.y))
		_glide[i] = Vector2(0.0, _rng.randf_range(0.5, 2.5))
		_stretch[i] = Vector2(0.0, _rng.randf_range(3.0, 20.0))
	_place_slots()


# Their places at the roost: a clump on the surface, rows hung a little below
# one another, each with its feet on the surface.
func _place_slots() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = colony_seed + 7
	var across := _out.cross(Vector3.UP)
	if across.length() < 0.1:
		across = Vector3.RIGHT
	across = across.normalized()
	var down := across.cross(_out).normalized()
	if down.dot(Vector3.DOWN) < 0.0:
		down = -down
	for i in count:
		var placed := Vector3.ZERO
		for tries in 12:
			var u := rng.randf_range(-0.5, 0.5) * cluster.x
			var v := rng.randf_range(0.0, 1.0) * cluster.y
			# (thickest in the middle, as a clump is)
			u *= 1.0 - 0.35 * v / maxf(cluster.y, 0.01)
			placed = _roost + across * u + down * v + _out * 0.05
			var apart := true
			for j in i:
				if _slot[j].distance_to(placed) < wingspan * 0.2:
					apart = false
					break
			if apart:
				break
		_slot[i] = placed


func _process(delta: float) -> void:
	if frozen or _mesh == null:
		return
	var camera := get_viewport().get_camera_3d()
	if _hanging == count and not awake and camera and camera.global_position.distance_to(_roost) > view_range:
		return
	_time += delta
	if target.is_finite():
		if _target_was.is_finite():
			_target_moving = _target_moving.lerp((target - _target_was) / maxf(delta, 0.001), 1.0 - exp(-8.0 * delta))
		_target_was = target
	else:
		_target_was = Vector3.INF
		_target_moving = Vector3.ZERO
	var hanging := 0
	for i in count:
		match _phase[i]:
			Phase.HANG:
				hanging += 1
				_hang(i, delta)
			Phase.DROP:
				_drop(i, delta)
			Phase.FLY, Phase.HOME:
				_fly(i, delta)
			Phase.LAND:
				_land(i, delta)
		_draw(i)
	if _hanging < count and hanging == count:
		settled.emit()
	_hanging = hanging


# Awake or asleep has just changed: each takes it up in its own time.
func _turned_over() -> void:
	if _phase.is_empty():
		return
	for i in count:
		if awake:
			if _phase[i] == Phase.HANG:
				# (the nearest the middle of the roost go first, and the rest after)
				_clock[i] = -(0.08 + _rng.randf_range(0.0, 0.9) * clampf(_slot[i].distance_to(_roost) / maxf(cluster.x * 0.5, 0.1), 0.2, 1.0))
			elif _phase[i] == Phase.HOME or _phase[i] == Phase.LAND:
				_phase[i] = Phase.FLY
				_clock[i] = 0.0
		elif _phase[i] == Phase.FLY or _phase[i] == Phase.DROP:
			_phase[i] = Phase.HOME
			_clock[i] = -_rng.randf_range(0.0, 0.9)


# Hanging asleep: it sways from its feet and breathes; now and then it opens
# its wings a way, shakes them and wraps them round again. Awake, it waits
# its turn (its clock below zero) and lets go.
func _hang(i: int, delta: float) -> void:
	if awake:
		_clock[i] += delta
		_fold[i] = 1.0 - 0.12 * absf(sin(_time * 19.0 + i))
		if _clock[i] >= 0.0:
			_phase[i] = Phase.DROP
			_clock[i] = 0.0
			_moving[i] = _out * 1.6 + Vector3.DOWN * 0.5
			if _hanging == count:
				woke.emit()
		var stir := _hang_transform(i, _time)
		_at[i] = stir.origin
		_turn[i] = stir.basis.get_rotation_quaternion()
		return
	var stretch := _stretch[i]
	stretch.y -= delta
	if stretch.x > 0.0:
		stretch.x -= delta
		var u := clampf(1.0 - stretch.x / 1.8, 0.0, 1.0)
		var open := sin(PI * u)
		_fold[i] = 1.0 - 0.7 * open
		_strength[i] = 0.35 * open
		_beat[i] = fposmod(_beat[i] + delta * 2.2, 1.0)
	else:
		_fold[i] = move_toward(_fold[i], 1.0, delta * 2.0)
		_strength[i] = 0.0
		if stretch.y <= 0.0:
			stretch = Vector2(1.8, _rng.randf_range(6.0, 22.0))
	_stretch[i] = stretch
	var hang := _hang_transform(i, _time)
	_at[i] = hang.origin
	_turn[i] = hang.basis.get_rotation_quaternion()


# How bat `i` hangs at its place: head down, its back to the surface and its
# wrapped front to the room, feet up against the surface and its head leaning
# out from it a little, swaying about its feet.
func _hang_transform(i: int, time: float) -> Transform3D:
	var head := Vector3.DOWN
	var back := -_out
	if absf(back.dot(head)) > 0.9:
		back = Vector3.BACK
	var side := back.cross(head).normalized()
	back = head.cross(side).normalized()
	var basis := Basis(side, back, head)
	var sway := 0.07 * sin(time * 0.8 + i * 1.7) + 0.03 * sin(time * 2.1 + i) - 0.3
	basis = Basis(_out.cross(Vector3.DOWN).normalized() if absf(_out.y) < 0.9 else Vector3.RIGHT, sway) * Basis(Vector3.DOWN, 0.15 * sin(i * 2.3)) * basis
	var feet := _slot[i]
	# (its feet are at -Z, about a sixth of its span behind its middle)
	return Transform3D(basis, feet + basis.z * 0.165 * _size[i])


# Let go: it falls head first, its wings opening, and swings out and away.
func _drop(i: int, delta: float) -> void:
	_clock[i] += delta
	var u := clampf(_clock[i] / 0.55, 0.0, 1.0)
	var moving := _moving[i] + Vector3.DOWN * 9.0 * delta * (1.0 - u) + _out * 6.0 * delta * u
	_moving[i] = moving
	_at[i] += moving * delta
	_fold[i] = 1.0 - smoothstep(0.1, 0.8, u)
	_strength[i] = smoothstep(0.3, 0.9, u)
	_beat[i] = fposmod(_beat[i] + delta * flap_rate * 1.2 * u, 1.0)
	_turn[i] = _turn[i].slerp(_flight_turn(i, moving, Vector3.ZERO), 1.0 - exp(-7.0 * delta * u))
	if u >= 1.0:
		_phase[i] = Phase.FLY
		_clock[i] = 0.0


# In the air: steered by a spring to where it wants to be.
func _fly(i: int, delta: float) -> void:
	var size := _size[i]
	var goal := Vector3.ZERO
	var goal_moving := Vector3.ZERO
	var top := speed
	var homing := _phase[i] == Phase.HOME
	if homing:
		_clock[i] += delta
	var orbit := _orbit[i]
	_round[i] += orbit.y / maxf(orbit.x, 0.5) * 1.3 * delta
	var round_about := Vector3(cos(_round[i]), 0.0, sin(_round[i]))
	var bob := sin(_time * orbit.w + i * 2.1) * orbit.z
	if homing and _clock[i] >= 0.0:
		# (in to just out from its place, then it lands)
		goal = _slot[i] + _out * 0.9 + Vector3.DOWN * 0.35
		top = speed * 0.75
		if _at[i].distance_to(goal) < 0.9 or _at[i].distance_to(_slot[i]) < 1.0:
			_phase[i] = Phase.LAND
			_clock[i] = 0.0
			_land_from[i] = Transform3D(Basis(_turn[i]), _at[i])
			return
	elif target.is_finite() and not homing:
		var dive := _dive[i]
		dive.y -= delta
		if dive.x > 0.0:
			dive.x -= delta
		elif dive.y <= 0.0:
			dive = Vector2(0.55, _rng.randf_range(dive_every.x, dive_every.y))
		_dive[i] = dive
		if dive.x > 0.0:
			# (at the face, and up and away over it)
			goal = target + round_about * (target_radius + size * 0.25) + Vector3.UP * 0.15
			top = speed * 1.15
		else:
			goal = target + round_about * maxf(orbit.x, _clear_of(size) + 0.15) + Vector3.UP * (swirl_height + bob)
			goal_moving = Vector3(-round_about.z, 0.0, round_about.x) * orbit.y * 1.3 * signf(orbit.y)
		goal_moving += _target_moving
	else:
		var middle := rally if rally.is_finite() else _roost + _out * 3.5 + Vector3.DOWN * 2.5
		goal = middle + round_about * orbit.x * 1.5 + Vector3.UP * bob * 1.5
		goal_moving = Vector3(-round_about.z, 0.0, round_about.x) * orbit.y * 1.5
	if keep_in.is_valid():
		goal = keep_in.call(goal)
	var at := _at[i]
	var moving := _moving[i]
	var push := (goal - at) * 5.0 + (goal_moving - moving) * 3.2
	# (kept off each other; less so coming in to the roost, where their places are close)
	var apart := clampf(at.distance_to(goal) / 3.0, 0.0, 1.0) if homing else 1.0
	for j in count:
		if j == i or _phase[j] == Phase.HANG:
			continue
		var off := at - _at[j]
		var near := (size + _size[j]) * 0.32
		var d := off.length()
		if d < near and d > 0.001:
			push += off / d * (near - d) / near * 30.0 * apart
	push = push.limit_length(32.0)
	moving = (moving + push * delta).limit_length(top)
	at += moving * delta
	if target.is_finite() and not homing and _dive[i].x <= 0.0:
		var kept := _keep_clear(at, moving, size, delta)
		at = kept[0]
		moving = kept[1]
	_at[i] = at
	_moving[i] = moving
	# Its wings: beating hard to climb, to turn hard, to catch up; held out and
	# gliding between whiles when it can.
	var glide := _glide[i]
	glide.y -= delta
	if glide.x > 0.0:
		glide.x -= delta
	elif glide.y <= 0.0:
		glide = Vector2(_rng.randf_range(0.35, 0.9), _rng.randf_range(1.2, 3.0))
	_glide[i] = glide
	var straining := push.length() > 14.0 or moving.y > 1.2 or moving.length() < 2.5
	var want := 0.12 if glide.x > 0.0 and not straining else clampf(0.7 + push.length() * 0.012, 0.7, 1.0)
	_strength[i] = move_toward(_strength[i], want, delta * 4.0)
	_fold[i] = move_toward(_fold[i], 0.0, delta * 3.0)
	# Hovering (deep, cupped, forward strokes): braking in to the roost, and
	# keeping up round the target rather than shooting past it.
	var hover := 0.0
	if homing and _clock[i] >= 0.0 and at.distance_to(goal) < 3.0:
		hover = 1.0
	elif target.is_finite() and not homing and _dive[i].x <= 0.0 and (moving - _target_moving).length() < 4.5:
		hover = 0.6
	_hover[i] = move_toward(_hover[i], hover, delta * 3.0)
	_beat[i] = fposmod(_beat[i] + delta * flap_rate * (0.85 + 0.3 * _strength[i]) * (1.4 / maxf(size, 0.5)) ** 0.5, 1.0)
	_turn[i] = _turn[i].slerp(_flight_turn(i, moving, push), 1.0 - exp(-9.0 * delta))


# How far from the target's middle a bat `size` across must keep, level with it.
func _clear_of(size: float) -> float:
	return target_radius + clearance + size * 0.5


# Keeps a bat out of the space round the target (from `target_depth` below it
# to a little over it): pushed back out to the edge of it (quickly, but not in
# one jump, for one just out of a dive), its speed inwards lost.
func _keep_clear(at: Vector3, moving: Vector3, size: float, delta: float) -> Array:
	var reach := size * 0.15
	if at.y < target.y - target_depth - reach or at.y > target.y + 0.35 + reach:
		return [at, moving]
	var off := Vector3(at.x - target.x, 0.0, at.z - target.z)
	var need := _clear_of(size)
	if off.length() >= need:
		return [at, moving]
	var out := off.normalized() if off.length() > 0.01 else Vector3.RIGHT
	at += out * minf(need - off.length(), 10.0 * delta)
	var inwards := moving.dot(out)
	if inwards < 0.0:
		moving -= out * inwards
	return [at, moving]


# Which way it is turned flying: along the way it is going (not too steeply),
# banked into the turn as the push to the side says.
func _flight_turn(i: int, moving: Vector3, push: Vector3) -> Quaternion:
	var ahead := moving
	if ahead.length() < 0.4:
		ahead = Basis(_turn[i]).z
		ahead.y = 0.0
		if ahead.length() < 0.1:
			ahead = Vector3.FORWARD
	ahead = ahead.normalized()
	ahead.y = clampf(ahead.y, -0.6, 0.6)
	ahead = ahead.normalized()
	var aside := push - ahead * push.dot(ahead)
	aside.y = 0.0
	var up := (Vector3.UP * 9.8 + aside.limit_length(14.0)).normalized()
	var side := up.cross(ahead).normalized()
	up = ahead.cross(side).normalized()
	return Basis(side, up, ahead).get_rotation_quaternion()


# Landing: it flutters in, swings over and takes hold, and folds up.
func _land(i: int, delta: float) -> void:
	_clock[i] += delta
	var u := clampf(_clock[i] / 0.5, 0.0, 1.0)
	var eased := u * u * (3.0 - 2.0 * u)
	var hang := _hang_transform(i, _time)
	var from := _land_from[i]
	_at[i] = from.origin.lerp(hang.origin, eased) + _out * 0.25 * sin(PI * u)
	_turn[i] = from.basis.get_rotation_quaternion().slerp(hang.basis.get_rotation_quaternion(), eased)
	_strength[i] = 0.9 * (1.0 - u)
	_hover[i] = 1.0 - u
	_fold[i] = smoothstep(0.4, 1.0, u)
	_beat[i] = fposmod(_beat[i] + delta * flap_rate * 1.6, 1.0)
	_moving[i] = Vector3.ZERO
	if u >= 1.0:
		_phase[i] = Phase.HANG
		_clock[i] = 0.0
		if awake:
			_clock[i] = -0.2


func _draw(i: int) -> void:
	var size := _size[i]
	var at := _at[i]
	# (its body bobs against each beat of its wings)
	if _phase[i] != Phase.HANG:
		at += Basis(_turn[i]).y * (-0.04 * size * _strength[i] * cos(TAU * _beat[i]))
	_mesh.multimesh.set_instance_transform(i, Transform3D(Basis(_turn[i]).scaled(Vector3.ONE * size), at))
	_mesh.multimesh.set_instance_custom_data(i, Color(_beat[i], _strength[i], _fold[i], _hover[i]))


func _draw_all() -> void:
	if _mesh == null:
		return
	for i in count:
		_draw(i)

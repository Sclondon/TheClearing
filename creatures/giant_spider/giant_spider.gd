class_name GiantSpider
extends Node3D
## A giant spider, to look at and to move: a hairy, tarantula-like thing about
## four and a half metres across its legs, with a cluster of glinting eyes and
## two black fangs, whose eight legs walk by themselves over floors and up
## walls. It is only the creature's body: what it does is for whoever drives it.
##
## DRIVING IT. Move the node (its position is the point on the surface under
## the middle of its body) and say:
## - `heading`: the way it should face (it turns to it; on a wall, "up the wall"
##   or "down the wall" are fine);
## - `surface`: the way the surface it is on faces (Vector3.UP on a floor, a
##   wall's normal on a wall). It rolls over smoothly when this changes, and
##   its legs find the new surface by themselves;
## - `hanging`: true while it hangs in the air on its thread (its legs are let
##   go and held out round it, and the node's position is the body's middle);
## - `anchor`: where its silk thread is fixed, INF for no thread. The thread
##   runs from there to the spinnerets at the end of its back body;
## - `aim`: something to look at and turn its feelers to, INF for nothing.
## How fast it is going is worked out from how the node moves, so its gait,
## its lean and its stepping follow whatever moves it.
##
## THE STRIKE. `rear()` starts it: it rears up on its back legs with its front
## legs raised high and its fangs spread (REAR: the warning, `REAR_TIME`), then
## by itself throws itself forward and down with its fangs closing (STRIKE,
## `STRIKE_TIME`), and gathers itself (RECOVER). `strike()` cuts the rearing
## short. `stage()` says where it is in this; `bites(a, b, radius)` whether a
## line (someone's body, feet to head) is within `radius` of a fang now, while
## it strikes. It does not move itself forward in a strike: the driver lunges.
##
## IT NEEDS a world with collision on `collision_mask` for its feet; with
## nothing there, they stand where they would rest. Call `settle()` after
## putting it somewhere new. Pass the things its feet should not stand on (the
## player's body) in `exclude`.
##
## Draws: the front body (two: hide and eyes), the back body, every leg part
## (one MultiMesh), the feet (another), the fangs and claws, and the thread when there is one. Nothing is
## built after `_ready` but transforms. Set `process_mode` to disabled (and hide
## it) when nobody is near.
##
## Files: giant_spider.gd, giant_spider_legs.gd (the legs), giant_spider_look.gd
## (the meshes and shaders). See example.gd.

enum Stage { NONE, REAR, STRIKE, RECOVER }

const REAR_TIME := 0.8
const STRIKE_TIME := 0.24
const RECOVER_TIME := 0.75

## How big it is (1: about four metres across its legs).
@export var size := 1.15
## How high the middle of its front body rides over the surface (at size 1).
@export var ride := 0.5
## How quickly it turns to `heading` (per second).
@export var turn_rate := 9.0
## What its feet stand on.
@export_flags_3d_physics var collision_mask := 1

var heading := Vector3.FORWARD
var surface := Vector3.UP
var hanging := false
var anchor := Vector3.INF
var aim := Vector3.INF
## What its feet do not stand on.
var exclude: Array[RID] = []
## Where its front body is, this frame (forward is -Z).
var body := Transform3D()
var legs := GiantSpiderLegs.new()

var _up := Vector3.UP
var _forward := Vector3.FORWARD
var _was := Vector3.INF
var _velocity := Vector3.ZERO
var _push := Vector3.ZERO
var _stage_time := INF
var _time := 0.0
## Springs: its lean (pitch, roll), and how its back body swings (pitch, yaw).
var _lean := Vector2.ZERO
var _lean_speed := Vector2.ZERO
var _swing := Vector2.ZERO
var _swing_speed := Vector2.ZERO
var _rear := 0.0
var _fangs := 0.0
var _hang := 0.0
var _settled := false
var _fang_tips := PackedVector3Array([Vector3.INF, Vector3.INF])
var _held := PackedVector3Array()

var _ceph: MeshInstance3D
var _abdomen: MeshInstance3D
var _parts: MultiMeshInstance3D
var _feet_parts: MultiMeshInstance3D
var _fang_parts: MultiMeshInstance3D
var _thread: MeshInstance3D


func _ready() -> void:
	_ceph = MeshInstance3D.new()
	_ceph.name = "Body"
	_ceph.mesh = GiantSpiderLook.ceph_mesh()
	_abdomen = MeshInstance3D.new()
	_abdomen.name = "Abdomen"
	_abdomen.mesh = GiantSpiderLook.abdomen_mesh()
	# (eight legs of four parts, the feelers' first parts, the jaws; then the
	# feet and the feelers' tips; then the fangs and the claws)
	_parts = GiantSpiderLook.parts(GiantSpiderLook.segment_mesh(), GiantSpiderLegs.COUNT * 4 + 4, GiantSpiderLook.hide_material())
	_parts.name = "Legs"
	_feet_parts = GiantSpiderLook.parts(GiantSpiderLook.foot_mesh(), GiantSpiderLegs.COUNT + 2, GiantSpiderLook.hide_material())
	_feet_parts.name = "Feet"
	_fang_parts = GiantSpiderLook.parts(GiantSpiderLook.fang_mesh(), 2 + GiantSpiderLegs.COUNT, GiantSpiderLook.gloss_material())
	_fang_parts.name = "Fangs"
	_thread = MeshInstance3D.new()
	_thread.name = "Thread"
	_thread.mesh = GiantSpiderLook.thread_mesh()
	_thread.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for part: GeometryInstance3D in [_ceph, _abdomen, _parts, _feet_parts, _fang_parts, _thread]:
		part.top_level = true
		part.extra_cull_margin = 3.0
		add_child(part)
	_thread.visible = false
	_held.resize(GiantSpiderLegs.COUNT)
	legs.size = size
	legs.mask = collision_mask
	_forward = _flat(heading, _up, Vector3.FORWARD)


## Stands it still where it is, its feet put straight down, nothing in motion.
func settle() -> void:
	_up = surface.normalized() if surface.length_squared() > 0.01 else Vector3.UP
	_forward = _flat(heading, _up, _forward)
	_was = Vector3.INF
	_velocity = Vector3.ZERO
	_lean = Vector2.ZERO
	_lean_speed = Vector2.ZERO
	_swing = Vector2.ZERO
	_swing_speed = Vector2.ZERO
	_stage_time = INF
	_rear = 0.0
	_fangs = 0.0
	_hang = 1.0 if hanging else 0.0
	_settled = false


## Rears up to strike (and strikes by itself after REAR_TIME).
func rear() -> void:
	_stage_time = 0.0


## Strikes now (or, rearing, cuts the rearing short).
func strike() -> void:
	_stage_time = REAR_TIME


func stage() -> Stage:
	if _stage_time < REAR_TIME:
		return Stage.REAR
	if _stage_time < REAR_TIME + STRIKE_TIME:
		return Stage.STRIKE
	if _stage_time < REAR_TIME + STRIKE_TIME + RECOVER_TIME:
		return Stage.RECOVER
	return Stage.NONE


## Seconds until the stage it is in ends.
func stage_left() -> float:
	match stage():
		Stage.REAR:
			return REAR_TIME - _stage_time
		Stage.STRIKE:
			return REAR_TIME + STRIKE_TIME - _stage_time
		Stage.RECOVER:
			return REAR_TIME + STRIKE_TIME + RECOVER_TIME - _stage_time
	return 0.0


## The points of its fangs in the world (as last drawn).
func fang_tips() -> PackedVector3Array:
	return _fang_tips


## Whether the line from `a` to `b` is within `radius` of a fang, while it strikes.
func bites(a: Vector3, b: Vector3, radius: float) -> bool:
	if stage() != Stage.STRIKE:
		return false
	for tip in _fang_tips:
		if not tip.is_finite():
			continue
		if tip.distance_to(Geometry3D.get_closest_point_to_segment(tip, a, b)) < radius:
			return true
	return false


## Where its silk comes out, in the world.
func spinnerets() -> Vector3:
	return _abdomen.global_transform * GiantSpiderLook.SPINNERETS if _abdomen else global_position


func _physics_process(delta: float) -> void:
	if delta > 0.0:
		animate(delta)


## Moves everything on by `delta` seconds (called each physics frame).
func animate(delta: float) -> void:
	_time += delta
	_stage_time += delta
	legs.size = size
	legs.mask = collision_mask
	legs.exclude = exclude
	var at := global_position
	if not _was.is_finite():
		_was = at
	var moved := (at - _was) / delta
	_was = at
	if moved.length() > 30.0:
		moved = _velocity
	var was_velocity := _velocity
	_velocity = _velocity.lerp(moved, 1.0 - exp(-12.0 * delta))
	var accel := (_velocity - was_velocity) / delta

	# Which way is up, and which forward.
	var want_up := surface.normalized() if surface.length_squared() > 0.01 else Vector3.UP
	_up = _turn_towards(_up, want_up, 1.0 - exp(-7.0 * delta))
	_forward = _flat(_forward, _up, Vector3.FORWARD)
	_forward = _turn_towards(_forward, _flat(heading, _up, _forward), 1.0 - exp(-turn_rate * delta))
	_hang = move_toward(_hang, 1.0 if hanging else 0.0, delta * 3.0)

	# The strike: how far it has reared, and its fangs.
	var now := stage()
	var rear_to := 0.0
	var fang_to := 0.0
	var lunge := 0.0
	match now:
		Stage.REAR:
			rear_to = 1.0
			fang_to = 1.0
		Stage.STRIKE:
			var t := (_stage_time - REAR_TIME) / STRIKE_TIME
			rear_to = -0.35
			fang_to = 1.0 - smoothstep(0.3, 0.9, t)
			lunge = sin(t * PI * 0.5)
		Stage.RECOVER:
			var t := (_stage_time - REAR_TIME - STRIKE_TIME) / RECOVER_TIME
			rear_to = -0.35 * (1.0 - t)
			lunge = 1.0 - smoothstep(0.0, 1.0, t)
	_rear = move_toward(_rear, rear_to, delta * (9.0 if now == Stage.STRIKE else 3.2))
	_fangs = move_toward(_fangs, fang_to, delta * (10.0 if now == Stage.STRIKE else 3.0))

	# Its lean: back as it sets off, forward as it stops, over into a turn.
	var side_dir := _up.cross(-_forward).normalized()
	var lean_to := Vector2(clampf(-accel.dot(_forward) * 0.02, -0.25, 0.25), clampf(accel.dot(side_dir) * 0.015, -0.2, 0.2))
	_lean_speed += ((lean_to - _lean) * 90.0 - _lean_speed * 11.0) * delta
	_lean += _lean_speed * delta
	# Its back body lags behind every move.
	var swing_to := Vector2(clampf(accel.dot(_up) * 0.01 - accel.dot(_forward) * 0.01, -0.3, 0.3), clampf(-accel.dot(side_dir) * 0.012, -0.35, 0.35))
	_swing_speed += ((swing_to - _swing) * 60.0 - _swing_speed * 6.0) * delta
	_swing += _swing_speed * delta

	# The body: up from the surface (unless it hangs), raised as it rears.
	var z := -_forward
	var x := _up.cross(z).normalized()
	var frame := Basis(x, _up, x.cross(_up))
	var pitch := _rear * 0.62 + _lean.x - lunge * 0.12
	var tilt := frame * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, _lean.y)
	var walking := clampf(_velocity.length() / (3.0 * size), 0.0, 1.0)
	var bob := -0.03 * size * legs.lifted() / 4.0 * walking + sin(_time * 2.1) * 0.01 * size
	var lift := ride * size * (1.0 - _hang) + maxf(_rear, 0.0) * 0.5 * size + bob
	var origin := at + _up * lift + _forward * lunge * 0.5 * size
	body = Transform3D(tilt, origin)
	var ground := Transform3D(frame, at - _up * (_hang * ride * size))

	# The legs: let go while it hangs, and the front two pairs while it rears.
	var front := clampf(_rear * 1.6, 0.0, 1.0) if now != Stage.NONE else 0.0
	for i in GiantSpiderLegs.COUNT:
		_held[i] = Vector3.INF
		var pair := i % 4
		var s := GiantSpiderLegs.side(i)
		var hip := GiantSpiderLegs.hip_local(i)
		if _hang > 0.5:
			# Held out round it in a loose basket, feeling the air.
			var rest := GiantSpiderLegs.rest_local(i)
			var wave := sin(_time * 3.0 + i * 1.7) * 0.15
			_held[i] = body * ((hip + Vector3(rest.x * 0.55, -0.35 + wave, rest.z * 0.5 - 0.3)) * size)
		elif now == Stage.REAR and pair < 2 and front > 0.3:
			var wave := sin(_time * 9.0 + i * 2.0) * 0.1
			var raised := Vector3(0.45 * s, 1.35 + wave, -0.9) if pair == 0 else Vector3(0.95 * s, 0.95 + wave, -0.45)
			_held[i] = body * ((hip + raised) * size)
		elif now == Stage.STRIKE and pair < 2:
			# Thrown down and forward over whoever is in front.
			_held[i] = body * ((hip + Vector3((0.55 if pair == 0 else 1.1) * s, -0.75, -1.5 if pair == 0 else -1.0)) * size)
	var space := get_world_3d().direct_space_state
	if not _settled:
		_settled = true
		legs.settle(space, body, ground)
	legs.update(delta, space, body, ground, _velocity, _held)
	legs.pose(body.basis.y, body.origin)
	_draw()


func _draw() -> void:
	var scale_basis := Basis.from_scale(Vector3.ONE * size)
	_ceph.global_transform = Transform3D(body.basis * scale_basis, body.origin)
	# The back body hangs from the waist, swinging, breathing, and tipped down
	# as the front rears.
	var breath := 1.0 + sin(_time * 1.3) * 0.015
	var hang_back := Basis(Vector3.RIGHT, -0.12 - _rear * 0.45 + _swing.x) * Basis(Vector3.UP, _swing.y)
	var waist := body * (GiantSpiderLook.PEDICEL * size)
	_abdomen.global_transform = Transform3D(body.basis * hang_back * Basis.from_scale(Vector3(breath, breath, 1.0) * size), waist)

	var multi := _parts.multimesh
	var feet := _feet_parts.multimesh
	var gloss := _fang_parts.multimesh
	var up := body.basis.y
	var k := 0
	for i in GiantSpiderLegs.COUNT:
		# Hip, femur, tibia, metatarsus; then the tarsus with its pad, and a claw.
		var ankle := legs.ankles[i]
		var tarsus := ankle.lerp(legs.feet[i], 0.66)
		multi.set_instance_transform(k, GiantSpiderLook.between(legs.hips[i], legs.roots[i], 0.12 * size, up))
		multi.set_instance_transform(k + 1, GiantSpiderLook.between(legs.roots[i], legs.knees[i], 0.105 * size, up))
		multi.set_instance_transform(k + 2, GiantSpiderLook.between(legs.knees[i], ankle, 0.09 * size, up))
		multi.set_instance_transform(k + 3, GiantSpiderLook.between(ankle, tarsus, 0.068 * size, up))
		k += 4
		feet.set_instance_transform(i, GiantSpiderLook.between(tarsus, legs.feet[i], 0.058 * size, up))
		var along := (legs.feet[i] - tarsus).normalized()
		var hook := (-legs.normals[i] - along * along.dot(-legs.normals[i]))
		hook = hook.normalized() if hook.length_squared() > 0.0001 else up
		var long := 0.09 * size
		var across := along.cross(hook)
		gloss.set_instance_transform(2 + i, Transform3D(Basis(across * long * 0.6, along * long, hook * long), legs.feet[i] - along * 0.02 * size))
	# The feelers: twitching, and turned towards what it looks at.
	var look := Vector3.ZERO
	if aim.is_finite():
		look = body.basis.inverse() * (aim - body.origin)
		look = look.normalized() * 0.25
	for p in 2:
		var s := -1.0 if p == 0 else 1.0
		var root := body * (Vector3(0.2 * s, -0.08, -0.46) * size)
		var twitch := Vector3(sin(_time * 4.1 + s) * 0.05, sin(_time * 6.3 + s * 2.0) * 0.08, 0.0)
		var tip_local := Vector3(0.36 * s, -0.52 + _rear * 0.55, -1.0 - _rear * 0.2) + twitch + look
		var tip := body * (tip_local * size)
		var solved := GiantSpiderLegs.two_bone(root, tip, 0.42 * size, 0.42 * size, up + body.basis * Vector3.FORWARD)
		multi.set_instance_transform(k, GiantSpiderLook.between(root, solved[0], 0.08 * size, up))
		k += 1
		feet.set_instance_transform(GiantSpiderLegs.COUNT + p, GiantSpiderLook.between(solved[0], solved[1], 0.075 * size, up))
	# The jaws (two bulky, hairy chelicerae side by side under the eyes), and
	# the fangs folded back under them, or spread.
	for f in 2:
		var s := -1.0 if f == 0 else 1.0
		var base := body * (Vector3(0.115 * s, 0.0, -0.48) * size)
		var tip := body * (Vector3(0.12 * s, -0.3 - _fangs * 0.04, -0.76 - _fangs * 0.06) * size)
		multi.set_instance_transform(k, GiantSpiderLook.between(base, tip, 0.15 * size, body.basis.z))
		multi.set_instance_color(k, Color(0.75, 0.75, 0.75))
		k += 1
		var closed := Vector3(-0.5 * s, -0.75, 0.35).normalized()
		var spread := Vector3(0.3 * s, -0.8, -0.45).normalized()
		var dir := body.basis.orthonormalized() * closed.slerp(spread, _fangs)
		var curl := body.basis.orthonormalized() * Vector3.BACK
		curl = (curl - dir * curl.dot(dir)).normalized()
		var across := dir.cross(curl)
		var long := 0.32 * size
		var fang := Transform3D(Basis(across * long, dir * long, curl * long), tip + dir * 0.03 * size)
		gloss.set_instance_transform(f, fang)
		_fang_tips[f] = fang * GiantSpiderLook.FANG_TIP

	# The thread.
	_thread.visible = anchor.is_finite()
	if _thread.visible:
		var from := spinnerets()
		var line := GiantSpiderLook.between(from, anchor, 0.018)
		# (the cylinder stands about its middle)
		line.origin = (from + anchor) * 0.5
		_thread.global_transform = line


## `v` laid flat in the plane square to `up`, unit length (or `fallback` if it lies along `up`).
static func _flat(v: Vector3, up: Vector3, fallback: Vector3) -> Vector3:
	var flat := v - up * v.dot(up)
	if flat.length_squared() < 0.0001:
		flat = fallback - up * fallback.dot(up)
		if flat.length_squared() < 0.0001:
			flat = up.cross(Vector3.RIGHT) if absf(up.x) < 0.9 else up.cross(Vector3.BACK)
	return flat.normalized()


## Turns unit vector `from` towards `to` by `weight` of the angle (half way round, any way).
static func _turn_towards(from: Vector3, to: Vector3, weight: float) -> Vector3:
	# (nearly there: slerp's axis would be too short to trust)
	if from.dot(to) > 0.9999:
		return to
	if from.dot(to) < -0.999:
		var aside := from.cross(Vector3.UP if absf(from.y) < 0.9 else Vector3.RIGHT).normalized()
		return from.rotated(aside, PI * weight).normalized()
	return from.slerp(to, weight).normalized()

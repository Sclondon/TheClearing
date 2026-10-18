class_name CorvidFlock
extends Node3D
## A flock of corvids (a murder of American crows, a pair of ravens, a family of
## blue jays: `kind`): how they look and how they go about, and nothing about
## what they mean in a game. A game tells it where they may sit and what is
## going on, and it does the rest:
##
## - WHERE THEY SIT: `set_perches(points, faces)`, points (a wall's top edge, a
##   ledge, branches) and the way a bird sitting there faces (out over a hall,
##   away from a trunk). Each bird takes one of its own. Sitting, they go about
##   it as corvids do: look about (the head snapped from pose to pose, cocked to
##   look with one eye), preen, fluff and shake out, shuffle a step or two along
##   the ledge or turn about, call (a crow bows forward, tail flicked, bill
##   wide, on each caw; a raven fluffs its throat and croaks, or knocks; a jay
##   bobs up and down with its crest raised: "jay! jay!", and now and then
##   mimics a hawk's scream). New perches (`set_perches` again): they move over
##   to them in short flights, one after another (as crows follow someone along
##   the wall tops, leapfrogging).
## - THE GROUND: with `ground_share` above 0, that share of them come down to
##   forage round `home` (within `roam`): a crow walks with its swagger (the
##   body rolling, the head thrust forward with each step), a jay hops with both
##   feet; they peck and probe, look about, and fly back up.
## - `erupt(over, seconds)`: they all burst off at once (one after another in
##   a moment), calling hard, and wheel over `over`, round and round,
##   `circle_height` above it, for `seconds`; then they come back down to perches.
##   `circle_over(point, seconds)` does the same without the alarm (a murder
##   wheeling over a place, cawing).
## - `watch(point)`: every head turns to it (and a body that would have to
##   turn too far turns round on its perch). Vector3.INF: nothing.
## - `scold(point)`: (jays) they come to the perches nearest it, crests up,
##   bobbing and screaming at it. Vector3.INF: they calm down.
## - `send_ahead(i, perch)`: one bird flies to a particular perch (a raven
##   leading someone, say).
##
## FLIGHT: a take-off with a jump and a downstroke, flapping (a crow rows
## steadily, a raven flaps slow and deep and soars, a jay bounds: a burst of
## beats, then wings shut a moment), gliding, banking into its turns, and a
## landing: it swings up to the perch, flares (wings up and forward, tail fanned
## down, legs reaching), touches down and folds its wings. They fly curves
## (from where they are, over, to where they are going), so they need no
## collisions: give them perches they can reach in the open.
##
## Optional: `ground_height`, a Callable(point: Vector3) -> float, for uneven
## ground (else it is level with `home`), and `keep_in`, a
## Callable(point: Vector3) -> Vector3 that moves a point to where they may walk.
##
## Drawn as ONE MultiMesh (CorvidBody's mesh and shader: every bird posed in the
## vertex shader from its pose, which this sets on the flock's material every
## frame), so a flock is one draw (and one for its shadow). Far from the camera
## (`far_detail`) it draws the low-detail bird; out of `view_range`, and with
## nobody in the air, it does no work and is not drawn. Signals: `called` (a
## call, with where and which: Call), `took_off`, `landed`, `erupted`. Seeded by
## `flock_seed`: two machines that make one with the same seed and perches get
## the same birds.

signal called(at: Vector3, call: int)
signal took_off(at: Vector3)
signal landed(at: Vector3)
signal erupted
## A wingbeat's downstroke (for a sound of wings), now and then.
signal flapped(at: Vector3)

## The most birds a flock can have (the shader's arrays hold this many).
const MOST := 16
## Which call.
enum Call { CAW, ALARM, CROAK, KNOCK, JAY, QUEEDLE, HAWK, RATTLE }
## What each is doing.
enum Act { SIT, LOOK, PREEN, CALL, SHUFFLE, SHAKE, TURN, WALK, HOP, PECK, WAIT, FLY, CIRCLE, LAND, SCOLD }

@export var kind := CorvidBody.Kind.CROW
@export_range(1, 16) var count := 8
@export var flock_seed := 0
## How big (1: the model's size: a crow 0.45 m from bill to tail).
@export var size := 1.0
## Where they forage on the ground (and what they keep near), and how far.
@export var home := Vector3.ZERO
@export var roam := 6.0
## The share of them that come down to the ground to forage (0: none ever).
@export_range(0.0, 1.0) var ground_share := 0.0
## How often a bird flies to another perch (or down, or up) by itself, per second.
@export var restless := 0.02
## Speeds, m/s: flying, walking.
@export var flight_speed := 8.0
@export var walk_speed := 0.5
## How wide they wheel when they circle, and how high over the point.
@export var circle_radius := 9.0
@export var circle_height := 9.0
## How often each calls by itself (seconds between, roughly).
@export var call_every := 14.0
## Past this far from the camera, the low-detail bird.
@export var far_detail := 28.0
@export var view_range := 140.0
@export var cast_shadows := true
## The low-detail bird always (phones).
@export var low_poly := false
## How hard they grip with their toes, sitting (branches 0.6; a flat ledge, little).
@export_range(0.0, 1.0) var grip := 0.6

## Optional: Callable(point: Vector3) -> float, the ground's height there.
var ground_height := Callable()
## Optional: Callable(point: Vector3) -> Vector3, where a bird on the ground at `point` may be instead.
var keep_in := Callable()
## For pictures: nothing moves but what `pose_bird` says.
var frozen := false

var perch_points := PackedVector3Array()
var perch_faces := PackedVector3Array()

var _birds: Array[Bird] = []
var _mesh: MultiMeshInstance3D
var _material: ShaderMaterial
var _full: ArrayMesh
var _low: ArrayMesh
var _poses := PackedVector4Array()
var _looks := PackedVector4Array()
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _joints := {}
var _level := 0.3
## Metres to the crow model's units: how big this kind is beside a crow, times `size`.
var _m := 1.0
var _watch := Vector3.INF
var _scold := Vector3.INF
var _circle_at := Vector3.INF
var _circle_left := 0.0
var _alarmed := false
var _far := false
var _detail_far := false


## One bird: what it is doing and how it is posed.
class Bird:
	var index := 0
	var mark := 0.0
	var scale := 1.0
	var act := Act.SIT
	var left := 0.0
	var clock := 0.0
	var count := 0
	var at := Vector3.ZERO
	var yaw := 0.0
	var face := 0.0
	var perch := -1
	var on_ground := false
	var lift := 0.0
	var call_in := 0.0
	var depart_in := -1.0
	var going := -1
	var going_down := false
	# Flying: the curve, how far along it, how long it takes.
	var from := Vector3.ZERO
	var ctrl := Vector3.ZERO
	var to := Vector3.ZERO
	var t := 0.0
	var span := 1.0
	var velocity := Vector3.ZERO
	var orbit := 0.0
	var orbit_way := 1.0
	var orbit_r := 9.0
	var orbit_h := 9.0
	var bound := 0.0
	# The pose.
	var walk := 0.0
	var step := 0.0
	var hop := 0.0
	var tuck := 0.0
	var head := Vector3.ZERO
	var head_aim := Vector3.ZERO
	var turn := Vector3.ZERO
	var turn_aim := Vector3.ZERO
	var look_in := 0.0
	var beak := 0.0
	var fluff := 0.0
	var fold := 1.0
	var beat := 0.0
	var strength := 0.0
	var pitch := 0.0
	var flare := 0.0
	var tail_lift := 0.0
	var tail_fan := 0.0
	var bank := 0.0
	var crest := 0.35
	var grip := 0.5
	var reach := 0.0
	var crouch := 0.0


func _ready() -> void:
	_rng.seed = flock_seed
	_joints = CorvidBody.joints(kind)
	_level = float(_joints.get("flight_pitch", 0.3))
	_m = size * (_joints.get("hip", Vector3(0.0, 0.13, 0.0)) as Vector3).y / 0.13
	_material = CorvidBody.material(kind)
	# (the low-detail bird to start with; the full one is made when first wanted, near the camera)
	_low = CorvidBody.mesh(kind, true)
	_detail_far = true
	_mesh = MultiMeshInstance3D.new()
	_mesh.name = "Birds"
	_mesh.top_level = true
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.material_override = _material
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.mesh = _low
	many.instance_count = mini(count, MOST)
	_mesh.multimesh = many
	add_child(_mesh)
	_mesh.global_transform = Transform3D.IDENTITY
	_poses.resize(MOST * 6)
	_looks.resize(MOST)
	_make_birds()
	_draw_all()


func _make_birds() -> void:
	_birds.clear()
	for i in mini(count, MOST):
		var bird := Bird.new()
		bird.index = i
		bird.mark = _rng.randf()
		bird.scale = size * _rng.randf_range(0.93, 1.06)
		bird.yaw = _rng.randf_range(-PI, PI)
		bird.left = _rng.randf_range(0.3, 3.0)
		bird.call_in = _rng.randf_range(2.0, call_every * 1.5)
		bird.orbit = _rng.randf_range(0.0, TAU)
		bird.orbit_way = 1.0
		bird.beat = _rng.randf()
		bird.at = home + Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)) * roam * 0.5
		bird.at.y = _ground(bird.at)
		bird.on_ground = true
		bird.fold = 1.0
		_birds.append(bird)
		_looks[i] = Vector4(bird.mark, _rng.randf_range(0.6, 1.0), _rng.randf(), 0.0)
	_material.set_shader_parameter(&"looks", _looks)


# --- What a game tells it ---

## Where they may sit: `points`, and the way a bird there faces (`faces`, flat
## directions; or empty: they face as they came). With `move` (and birds already
## about), those not on one of these fly over to free ones, one after another;
## else they are put straight on them (for a start). With `gather`, those
## sitting out at the ends of the new perches come in to the free ones nearest
## their middle (as crows following someone along a wall leapfrog ahead).
func set_perches(points: PackedVector3Array, faces := PackedVector3Array(), move := true, gather := false) -> void:
	perch_points = points
	perch_faces = faces
	var placed := not move or _birds.is_empty() or _time <= 0.0
	var middle := Vector3.ZERO
	var reach := INF
	if gather and not points.is_empty():
		for p in points:
			middle += p
		middle /= points.size()
		reach = 0.0
		for p in points:
			reach += Vector2(p.x - middle.x, p.z - middle.z).length()
		reach = reach / points.size() * 0.75
	# (who is where they may stay)
	var taken := {}
	for bird in _birds:
		if bird.perch >= 0 and not placed:
			# (its old perch's number means nothing now: does a new one stand where it sits?)
			var kept := _perch_at(bird.at, 0.25)
			if kept >= 0 and Vector2(bird.at.x - middle.x, bird.at.z - middle.z).length() > reach:
				kept = -1
			bird.perch = kept if kept >= 0 and not taken.has(kept) else -1
			if bird.perch >= 0:
				taken[bird.perch] = true
	var order := _birds.duplicate()
	order.sort_custom(func(p: Bird, q: Bird) -> bool: return p.mark < q.mark)
	var stagger := 0.0
	for bird: Bird in order:
		if bird.act == Act.CIRCLE or bird.act == Act.FLY and _circle_left > 0.0:
			continue
		if bird.act == Act.FLY and not placed:
			# (on its way to a perch that may be gone: to the new one nearest where it was going)
			if bird.count >= 0:
				var spot := _free_perch(bird.to, taken, false)
				if spot >= 0:
					taken[spot] = true
					bird.going = spot
					_fly_from_circle(bird, 0.0)
			continue
		if placed:
			if bird.on_ground and _rng.randf() < ground_share:
				continue
			var spot := _free_perch(bird.at, taken, true)
			if spot < 0:
				continue
			taken[spot] = true
			_put_on_perch(bird, spot)
		elif bird.perch < 0 and not bird.on_ground or bird.going >= 0:
			var spot := _free_perch(middle if gather else bird.at, taken, false)
			if spot < 0:
				continue
			taken[spot] = true
			bird.going = spot
			bird.going_down = false
			bird.depart_in = stagger + _rng.randf_range(0.0, 0.35)
			stagger += _rng.randf_range(0.12, 0.45)


## Puts every bird straight onto the perches (and the ground, its share), settled.
func settle() -> void:
	for bird in _birds:
		bird.perch = -1
		bird.going = -1
		bird.depart_in = -1.0
	set_perches(perch_points, perch_faces, false)
	for bird in _birds:
		if bird.perch < 0:
			bird.on_ground = true
			bird.at = _kept(home + Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)) * roam * 0.6)
			_start(bird, Act.WALK if _rng.randf() < 0.5 else Act.PECK)
		_settle_pose(bird)
	_draw_all()


## They burst off at once, calling hard, and wheel over `over` (Vector3.INF:
## where they are), `circle_height` above it, for `seconds`.
func erupt(over := Vector3.INF, seconds := 8.0) -> void:
	_alarmed = true
	_go_round(over, seconds, true)
	erupted.emit()


## They wheel over `point` for `seconds`, calling now and then (no alarm).
func circle_over(point: Vector3, seconds := 15.0) -> void:
	_alarmed = false
	_go_round(point, seconds, false)


func _go_round(over: Vector3, seconds: float, burst: bool) -> void:
	_circle_at = over if over.is_finite() else centre()
	_circle_left = seconds
	var order := _birds.duplicate()
	order.sort_custom(func(p: Bird, q: Bird) -> bool: return p.mark < q.mark)
	for k in order.size():
		var bird: Bird = order[k]
		bird.orbit_r = circle_radius * _rng.randf_range(0.75, 1.3)
		bird.orbit_h = circle_height * _rng.randf_range(0.85, 1.25)
		bird.orbit_way = 1.0 if (flock_seed % 2 == 0) else -1.0
		if bird.act != Act.CIRCLE:
			bird.depart_in = (k * 0.06 if burst else k * 0.3) + _rng.randf_range(0.0, 0.12 if burst else 0.4)
			bird.going = -2
		if burst:
			bird.call_in = bird.depart_in + _rng.randf_range(0.0, 0.4)


## Moves the middle of their wheeling (they follow it round).
func move_circle(point: Vector3) -> void:
	if _circle_left > 0.0 and point.is_finite():
		_circle_at = point


## Those on the ground (and any sitting within `near` of `from`) fly up to
## perches away from `from`, calling.
func startle(from: Vector3, near := 0.0) -> void:
	var taken := _taken()
	var k := 0
	for bird in _birds:
		var close := near > 0.0 and Vector2(bird.at.x - from.x, bird.at.z - from.z).length() < near
		if not (bird.on_ground or close) or bird.act in [Act.FLY, Act.CIRCLE] or bird.depart_in >= 0.0:
			continue
		var away := bird.at - from
		away.y = 0.0
		var spot := _free_perch(bird.at + away.normalized() * 6.0 * _m, taken, false)
		if spot < 0:
			continue
		taken[spot] = true
		bird.going = spot
		bird.going_down = false
		bird.depart_in = k * 0.08 + _rng.randf_range(0.0, 0.1)
		bird.call_in = bird.depart_in + _rng.randf_range(0.05, 0.3)
		k += 1


## Whether they are wheeling (or setting off to).
func circling() -> bool:
	return _circle_left > 0.0


## Every head turns to `point` (Vector3.INF: nothing).
func watch(point: Vector3) -> void:
	_watch = point


## (Jays) they come to the perches nearest `point` and scold it, crests up
## (Vector3.INF: they calm down and go back to their own business).
func scold(point: Vector3) -> void:
	var was := _scold
	_scold = point
	if not point.is_finite() or (was.is_finite() and was.distance_to(point) < 3.0):
		return
	# (each to a perch near it, the nearest first)
	var near: Array[int] = []
	for p in perch_points.size():
		near.append(p)
	near.sort_custom(func(a: int, b: int) -> bool: return perch_points[a].distance_squared_to(point) < perch_points[b].distance_squared_to(point))
	var taken := {}
	var k := 0
	for bird in _birds:
		if bird.act == Act.CIRCLE:
			continue
		while k < near.size() and taken.has(near[k]):
			k += 1
		if k >= near.size() or perch_points[near[k]].distance_to(point) > 14.0:
			break
		taken[near[k]] = true
		if bird.perch != near[k]:
			bird.going = near[k]
			bird.going_down = false
			bird.depart_in = _rng.randf_range(0.0, 0.8)
		k += 1


## Bird `i` flies to perch `p` (a raven going ahead of someone, say).
func send_ahead(i: int, p: int) -> void:
	if i < 0 or i >= _birds.size() or p < 0 or p >= perch_points.size():
		return
	var bird := _birds[i]
	for other in _birds:
		if other != bird and other.perch == p:
			other.going = _free_perch(other.at, {p: true}, false)
			other.depart_in = 0.2
	bird.going = p
	bird.going_down = false
	bird.depart_in = 0.0


## Bird `i` calls now (whatever it was doing on its perch).
func call_now(i: int) -> void:
	if i >= 0 and i < _birds.size() and _birds[i].act in [Act.SIT, Act.LOOK, Act.PREEN, Act.SHUFFLE, Act.WAIT, Act.PECK]:
		_start(_birds[i], Act.CALL)


func centre() -> Vector3:
	var sum := Vector3.ZERO
	for bird in _birds:
		sum += bird.at
	return sum / maxf(_birds.size(), 1)


func bird_position(i: int) -> Vector3:
	return _birds[i].at


func act_of(i: int) -> int:
	return _birds[i].act


func perch_of(i: int) -> int:
	return _birds[i].perch


## How many are in the air.
func flying() -> int:
	var many := 0
	for bird in _birds:
		if bird.act in [Act.FLY, Act.CIRCLE]:
			many += 1
	return many


## How many sit on perches.
func perched() -> int:
	var many := 0
	for bird in _birds:
		if bird.perch >= 0 and not (bird.act in [Act.FLY, Act.CIRCLE]):
			many += 1
	return many


## For pictures (`frozen`): puts bird `i` at `at` facing `yaw`, posed by
## `pose` (any of: fold, beat, strength, pitch, flare, tail_lift, tail_fan, bank,
## crest, grip, reach, crouch, beak, fluff, head (Vector3), turn (yaw, pitch,
## roll), walk, step, hop, tuck). `pitch` is on top of the level flight pitch
## when `fold` is under 0.5.
func pose_bird(i: int, at: Vector3, yaw: float, pose := {}) -> void:
	if not low_poly and _detail_far:
		# (pictures are close: the full bird)
		if _full == null:
			_full = CorvidBody.mesh(kind, false)
		_detail_far = false
		_mesh.multimesh.mesh = _full
	var bird := _birds[i]
	bird.at = at
	bird.yaw = yaw
	_settle_pose(bird)
	for key: String in pose:
		bird.set(key, pose[key])
	if pose.has("pitch") and float(pose.get("fold", 1.0)) < 0.5:
		bird.pitch = _level + float(pose["pitch"])
	elif not pose.has("pitch") and float(pose.get("fold", 1.0)) < 0.5:
		bird.pitch = _level
	_draw_all()


# --- Each frame ---

func _process(delta: float) -> void:
	if frozen or _mesh == null:
		return
	var camera := get_viewport().get_camera_3d()
	var middle := centre()
	var far_off := camera.global_position.distance_to(middle) if camera else 0.0
	var idle := flying() == 0 and _circle_left <= 0.0
	_far = camera != null and far_off > view_range
	_mesh.visible = not (_far and idle)
	if _far and idle:
		return
	if not low_poly:
		# (the low-detail bird far off, with a little room either way)
		var want_far := far_off > far_detail * (0.9 if _detail_far else 1.1)
		if want_far != _detail_far:
			_detail_far = want_far
			if not want_far and _full == null:
				_full = CorvidBody.mesh(kind, false)
			_mesh.multimesh.mesh = _low if want_far else _full
	delta = minf(delta, 0.05)
	_time += delta
	if _circle_left > 0.0:
		_circle_left -= delta
		if _circle_left <= 0.0:
			_come_down()
	for bird in _birds:
		_think(bird, delta)
		_move(bird, delta)
		_pose(bird, delta)
	_draw_all()


# They come back down out of the sky to the perches nearest where they are.
func _come_down() -> void:
	_alarmed = false
	var taken := {}
	for bird in _birds:
		if bird.act != Act.CIRCLE and bird.perch >= 0:
			taken[bird.perch] = true
	var stagger := 0.0
	for bird in _birds:
		if bird.act != Act.CIRCLE:
			if bird.going == -2:
				bird.going = -1
				bird.depart_in = -1.0
			continue
		var spot := _free_perch(bird.at, taken, false)
		bird.depart_in = -1.0
		if spot >= 0:
			taken[spot] = true
			bird.going = spot
			bird.going_down = false
		elif ground_share > 0.0:
			bird.going = -1
			bird.going_down = true
		else:
			bird.going = -1
			continue
		_fly_from_circle(bird, stagger)
		stagger += _rng.randf_range(0.1, 0.5)


func _think(bird: Bird, delta: float) -> void:
	bird.left -= delta
	bird.clock += delta
	bird.call_in -= delta
	# Setting off somewhere (a new perch, the sky, the ground).
	if bird.depart_in >= 0.0 and not (bird.act in [Act.FLY, Act.LAND]):
		bird.depart_in -= delta
		if bird.depart_in < 0.0 and (bird.act != Act.CIRCLE or bird.going >= 0):
			if bird.going == -2:
				_take_off_to_circle(bird)
			elif bird.going >= 0:
				_fly_to(bird, perch_points[bird.going], bird.going, false)
			elif bird.going_down:
				_fly_to(bird, _ground_spot(bird.at), -1, true)
	# Calling, by itself, now and then (and often, alarmed or scolding).
	if bird.call_in <= 0.0:
		var alarmed := _alarmed and bird.act in [Act.CIRCLE, Act.FLY]
		var scolding := _scold.is_finite() and bird.act == Act.SCOLD
		bird.call_in = _rng.randf_range(0.4, 1.4) if alarmed or scolding else _rng.randf_range(call_every * 0.5, call_every * 1.5)
		if bird.act in [Act.CIRCLE, Act.FLY]:
			called.emit(bird.at, _flight_call(alarmed))
		elif bird.act in [Act.SIT, Act.LOOK, Act.WAIT, Act.PECK, Act.PREEN, Act.SCOLD]:
			_start(bird, Act.CALL)
	match bird.act:
		Act.SIT, Act.LOOK, Act.PREEN, Act.SHAKE, Act.TURN, Act.WAIT, Act.PECK:
			if bird.left <= 0.0:
				_next(bird)
		Act.SHUFFLE, Act.WALK, Act.HOP:
			if bird.left <= 0.0 or bird.to.distance_to(bird.at) < 0.03:
				_next(bird)
		Act.CALL:
			if bird.left <= 0.0:
				_start(bird, Act.SCOLD if _scold.is_finite() and bird.perch >= 0 else Act.SIT)
		Act.SCOLD:
			if not _scold.is_finite():
				_start(bird, Act.SIT)
			elif bird.left <= 0.0:
				_start(bird, Act.CALL)
		Act.LAND:
			if bird.left <= 0.0:
				landed.emit(bird.at)
				_start(bird, Act.SCOLD if _scold.is_finite() and bird.perch >= 0 else Act.SIT)


# The call it makes in the air: crows caw (an alarm, harsh and fast), ravens croak, jays scream.
func _flight_call(alarmed: bool) -> int:
	match kind:
		CorvidBody.Kind.RAVEN:
			return Call.CROAK
		CorvidBody.Kind.BLUE_JAY:
			return Call.JAY
	return Call.ALARM if alarmed else Call.CAW


# What to do next, sitting or on the ground.
func _next(bird: Bird) -> void:
	var roll := _rng.randf()
	if bird.perch >= 0:
		# (now and then off somewhere: another perch, or down to the ground)
		if _rng.randf() < restless * 4.0 and not _scold.is_finite():
			if ground_share > 0.0 and _rng.randf() < ground_share and _on_ground_count() < ceili(ground_share * _birds.size()):
				bird.going = -1
				bird.going_down = true
				bird.depart_in = 0.0
				return
			var taken := _taken()
			var spot := _free_perch(bird.at + Vector3(_rng.randf_range(-6.0, 6.0), 0.0, _rng.randf_range(-6.0, 6.0)), taken, false)
			if spot >= 0 and spot != bird.perch:
				bird.going = spot
				bird.going_down = false
				bird.depart_in = 0.0
				return
		if _scold.is_finite():
			_start(bird, Act.SCOLD)
		elif roll < 0.42:
			_start(bird, Act.LOOK)
		elif roll < 0.58:
			_start(bird, Act.PREEN)
		elif roll < 0.72:
			_start(bird, Act.SHUFFLE)
		elif roll < 0.78:
			_start(bird, Act.SHAKE)
		elif roll < 0.86:
			_start(bird, Act.TURN)
		else:
			_start(bird, Act.SIT)
		return
	if bird.on_ground:
		# (back up to a perch now and then)
		if not perch_points.is_empty() and (_rng.randf() < restless * 5.0 or ground_share <= 0.0):
			var spot := _free_perch(bird.at, _taken(), false)
			if spot >= 0:
				bird.going = spot
				bird.going_down = false
				bird.depart_in = 0.0
				return
		var from_home := Vector2(bird.at.x - home.x, bird.at.z - home.z).length()
		if from_home > roam or roll < 0.4:
			_start(bird, Act.HOP if kind == CorvidBody.Kind.BLUE_JAY or _rng.randf() < 0.15 else Act.WALK)
		elif roll < 0.72:
			_start(bird, Act.PECK)
		elif roll < 0.85:
			_start(bird, Act.LOOK)
		else:
			_start(bird, Act.WAIT)


func _start(bird: Bird, act: Act) -> void:
	bird.act = act
	bird.clock = 0.0
	bird.count = 0
	match act:
		Act.SIT:
			bird.left = _rng.randf_range(1.0, 4.0)
		Act.LOOK:
			bird.left = _rng.randf_range(1.5, 4.5)
		Act.PREEN:
			bird.left = _rng.randf_range(1.5, 3.5)
			bird.count = 1 if _rng.randf() < 0.5 else -1
		Act.SHAKE:
			bird.left = 0.8
		Act.TURN:
			bird.left = 0.6
			bird.face = wrapf(bird.face + PI * _rng.randf_range(0.6, 1.0) * (1.0 if _rng.randf() < 0.5 else -1.0), -PI, PI)
		Act.CALL:
			bird.count = _calls_in_a_row()
			bird.set_meta(&"calls", 0)
			bird.set_meta(&"knock", kind == CorvidBody.Kind.RAVEN and _rng.randf() < 0.3)
			var hawk := kind == CorvidBody.Kind.BLUE_JAY and _rng.randf() < 0.12 and not _scold.is_finite()
			bird.set_meta(&"hawk", hawk)
			if hawk:
				bird.count = 1
			bird.left = bird.count * _call_length() * (2.6 if hawk else 1.0) + 0.3
		Act.SCOLD:
			bird.left = _rng.randf_range(0.4, 1.2)
		Act.SHUFFLE:
			bird.left = 1.2
			var along := Vector3(cos(bird.face), 0.0, -sin(bird.face)) * (1.0 if _rng.randf() < 0.5 else -1.0)
			var spot := perch_points[bird.perch] if bird.perch >= 0 else bird.at
			var aim := spot + along * _rng.randf_range(0.08, 0.3) * _m
			# (stays near its perch)
			bird.to = spot.lerp(aim, 1.0) if aim.distance_to(spot) < 0.4 * _m else spot
			bird.to.y = spot.y
		Act.WALK, Act.HOP:
			var from_home := Vector2(bird.at.x - home.x, bird.at.z - home.z).length()
			var aim := home if from_home > roam else bird.at
			var round_about := _rng.randf_range(0.0, TAU)
			bird.to = _kept(aim + Vector3(cos(round_about), 0.0, sin(round_about)) * _rng.randf_range(0.5, minf(roam, 3.0)) * _m)
			bird.left = _rng.randf_range(2.0, 6.0)
		Act.PECK:
			bird.count = _rng.randi_range(2, 6)
			bird.left = bird.count * 0.45 + 0.3
		Act.WAIT:
			bird.left = _rng.randf_range(0.8, 2.5)
		Act.LAND:
			bird.left = 0.32


func _calls_in_a_row() -> int:
	match kind:
		CorvidBody.Kind.RAVEN:
			return _rng.randi_range(1, 3)
		CorvidBody.Kind.BLUE_JAY:
			return _rng.randi_range(2, 4)
	return _rng.randi_range(2, 4)


func _call_length() -> float:
	match kind:
		CorvidBody.Kind.RAVEN:
			return 0.75
		CorvidBody.Kind.BLUE_JAY:
			return 0.42
	return 0.55


# --- Going places ---

# Off the perch or the ground, along a curve to `goal`: a perch (`spot`), or the ground.
func _fly_to(bird: Bird, goal: Vector3, spot: int, to_ground: bool) -> void:
	if bird.perch >= 0 and bird.perch != spot:
		bird.perch = -1
	bird.going = -1
	bird.going_down = false
	var from := bird.at
	var flat := Vector2(goal.x - from.x, goal.z - from.z).length()
	var rise := goal.y - from.y
	# (over and down onto it: up off the perch, the arc higher the further, and
	# coming down onto the goal from above)
	var arc := clampf(flat * 0.22, 0.5 * _m, 5.0) + maxf(rise, 0.0) * 0.6
	bird.from = from
	bird.to = goal
	bird.ctrl = from.lerp(goal, 0.45) + Vector3.UP * arc
	bird.t = 0.0
	var length := flat + absf(rise) + arc
	bird.span = maxf(length / flight_speed, 0.7) * (1.15 if kind == CorvidBody.Kind.BLUE_JAY else 1.0)
	bird.perch = -1
	bird.on_ground = false
	bird.velocity = Vector3.ZERO
	bird.count = spot
	bird.lift = 0.0
	bird.bound = 0.0
	if to_ground:
		bird.count = -1
	_start_flight(bird)


func _start_flight(bird: Bird) -> void:
	bird.act = Act.FLY
	bird.clock = 0.0
	bird.left = bird.span
	took_off.emit(bird.at)


# Off into the sky to wheel over the circle's middle.
func _take_off_to_circle(bird: Bird) -> void:
	bird.going = -2
	bird.perch = -1
	bird.on_ground = false
	bird.act = Act.CIRCLE
	bird.clock = 0.0
	bird.velocity = Vector3.UP * 3.0 + _forward(bird) * 1.5
	bird.orbit = atan2(bird.at.z - _circle_at.z, bird.at.x - _circle_at.x)
	took_off.emit(bird.at)


# Out of the circle to where it is going (`bird.going`, or the ground), along a curve.
func _fly_from_circle(bird: Bird, delay: float) -> void:
	var goal := perch_points[bird.going] if bird.going >= 0 else _ground_spot(bird.at)
	var spot := bird.going
	var down := bird.going_down
	bird.going = -1
	bird.going_down = false
	bird.from = bird.at
	bird.to = goal
	var ahead := bird.velocity.normalized() if bird.velocity.length() > 0.5 else _forward(bird)
	var flat := Vector2(goal.x - bird.at.x, goal.z - bird.at.z).length()
	bird.ctrl = bird.at + ahead * clampf(flat * 0.4, 2.0, 10.0)
	bird.ctrl.y = maxf(bird.at.y, goal.y + 1.5)
	bird.t = -delay / maxf(flat / flight_speed, 1.0)
	bird.span = maxf((flat + absf(goal.y - bird.at.y)) / flight_speed, 1.0)
	bird.count = -1 if down else spot
	bird.act = Act.FLY
	bird.clock = 0.0


func _move(bird: Bird, delta: float) -> void:
	match bird.act:
		Act.FLY:
			_fly(bird, delta)
		Act.CIRCLE:
			_circle(bird, delta)
		Act.SHUFFLE:
			var to := bird.to - bird.at
			bird.at += to.limit_length(0.35 * _m * delta)
		Act.WALK, Act.HOP:
			_walk(bird, delta)
		Act.LAND:
			pass
	# Facing: on a perch, its own way (or round to what it watches); on the ground, as it goes.
	if bird.act in [Act.SIT, Act.LOOK, Act.PREEN, Act.CALL, Act.SHAKE, Act.TURN, Act.SCOLD, Act.SHUFFLE, Act.LAND, Act.WAIT, Act.PECK]:
		var want := bird.face
		var target := _scold if _scold.is_finite() else _watch
		if target.is_finite():
			var to := target - bird.at
			var toward := atan2(to.x, to.z)
			if absf(angle_difference(bird.face, toward)) > 1.5 or _scold.is_finite():
				want = toward
		bird.yaw = lerp_angle(bird.yaw, want, 1.0 - exp(-(9.0 if bird.act == Act.TURN else 3.0) * delta))


# Along its curve: up off the perch with a jump, on, and down onto the goal with a flare.
func _fly(bird: Bird, delta: float) -> void:
	bird.t += delta / bird.span
	if bird.t < 0.0:
		# (waiting its turn: still wheeling)
		_circle(bird, delta)
		return
	var u := clampf(bird.t, 0.0, 1.0)
	# (easing: slow off and slow in, steady between)
	var s := _ease(u)
	var was := bird.at
	bird.at = _bezier(bird.from, bird.ctrl, bird.to, s)
	bird.velocity = (bird.at - was) / maxf(delta, 0.0001)
	var flat := Vector2(bird.velocity.x, bird.velocity.z)
	if flat.length() > 0.2:
		bird.yaw = lerp_angle(bird.yaw, atan2(flat.x, flat.y), 1.0 - exp(-10.0 * delta))
	if u >= 1.0:
		bird.at = bird.to
		bird.velocity = Vector3.ZERO
		if bird.count >= 0:
			bird.perch = bird.count
			bird.on_ground = false
			bird.face = _perch_face(bird.perch, bird.yaw)
		else:
			bird.on_ground = true
			bird.perch = -1
			bird.face = bird.yaw
		_start(bird, Act.LAND)


static func _ease(u: float) -> float:
	# (accelerating over the first fifth, steady, slowing over the last fifth)
	const A := 0.2
	var v := 1.0 / (1.0 - A)
	if u < A:
		return v * u * u / (2.0 * A)
	if u > 1.0 - A:
		var w := 1.0 - u
		return 1.0 - v * w * w / (2.0 * A)
	return v * (u - A * 0.5)


static func _bezier(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)


# Wheeling round the circle's middle, steering for a point that runs on round it.
func _circle(bird: Bird, delta: float) -> void:
	var middle := _circle_at if _circle_at.is_finite() else home
	var speed := flight_speed * 0.8
	bird.orbit += bird.orbit_way * speed / maxf(bird.orbit_r, 1.0) * delta
	var bob := sin(_time * 0.7 + bird.mark * 9.0) * 1.2 * _m
	var target := middle + Vector3(cos(bird.orbit), 0.0, sin(bird.orbit)) * bird.orbit_r + Vector3.UP * (bird.orbit_h + bob)
	var want := (target - bird.at)
	var desired := want.limit_length(1.0) * speed * clampf(want.length() / 3.0, 0.6, 1.6)
	var before := bird.velocity
	bird.velocity = bird.velocity.move_toward(desired, 9.0 * delta)
	bird.at += bird.velocity * delta
	var flat := Vector2(bird.velocity.x, bird.velocity.z)
	if flat.length() > 0.3:
		var old_yaw := bird.yaw
		bird.yaw = lerp_angle(bird.yaw, atan2(flat.x, flat.y), 1.0 - exp(-6.0 * delta))
		# (banked into the turn: by how fast it turns at this speed)
		var rate := angle_difference(old_yaw, bird.yaw) / maxf(delta, 0.0001)
		bird.bank = lerpf(bird.bank, clampf(-rate * flat.length() / 9.8, -0.9, 0.9), 1.0 - exp(-4.0 * delta))
	bird.lift = (bird.velocity.y - before.y)


# Walking (a crow's swagger) or hopping (both feet together) to `bird.to`.
func _walk(bird: Bird, delta: float) -> void:
	var to := bird.to - bird.at
	to.y = 0.0
	if bird.act == Act.HOP:
		# (each hop: down in a crouch, a spring forward a little way, land)
		var hop_time := 0.32 if kind == CorvidBody.Kind.BLUE_JAY else 0.4
		var phase := fmod(bird.clock, hop_time) / hop_time
		var air := phase > 0.3 and phase < 0.85
		if air:
			bird.at += to.limit_length(1.0) * walk_speed * 2.6 * _m * delta
		bird.lift = sin(PI * clampf((phase - 0.3) / 0.55, 0.0, 1.0)) * 0.06 * _m
	else:
		bird.at += to.limit_length(1.0) * walk_speed * _m * delta
		bird.lift = 0.0
	bird.at = _kept(bird.at)
	if to.length() > 0.02:
		bird.yaw = lerp_angle(bird.yaw, atan2(to.x, to.z), 1.0 - exp(-8.0 * delta))
		bird.face = bird.yaw


# Snaps the head from pose to pose as a corvid looks about: turned to look with
# one eye, cocked, held; `rate` how often.
func _look_about(bird: Bird, delta: float, rate: float) -> void:
	bird.look_in -= delta
	if bird.look_in <= 0.0:
		bird.look_in = _rng.randf_range(0.3, 1.6) / maxf(rate * 4.0, 0.1)
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var eye_on := _rng.randf() < 0.55
		bird.turn_aim = Vector3(side * _rng.randf_range(0.2, 1.0) if eye_on else _rng.randf_range(-0.35, 0.35), _rng.randf_range(-0.35, 0.2), side * _rng.randf_range(0.15, 0.6) if eye_on else 0.0)
		bird.head_aim = Vector3(0.0, _rng.randf_range(-0.004, 0.006), _rng.randf_range(-0.004, 0.008)) * _m


# The head turned to look at `point` (on top of what it was doing).
func _look_at(bird: Bird, point: Vector3) -> void:
	var head := bird.at + Vector3.UP * 0.23 * _m
	var to := point - head
	var flat := Vector2(to.x, to.z).length()
	var yaw := clampf(angle_difference(bird.yaw, atan2(to.x, to.z)), -1.9, 1.9)
	var pitch := clampf(-atan2(to.y, flat), -0.9, 1.0)
	# (one eye on it, now and then: the head turned further and cocked)
	var cock := 0.35 * sin(_time * 0.9 + bird.mark * 7.0)
	bird.turn_aim = Vector3(yaw + cock * 0.6, pitch, cock)


func _pose(bird: Bird, delta: float) -> void:
	var t := bird.clock
	var sz := _m
	var step_aim := 0.0
	var hop_aim := 0.0
	var tuck_aim := 0.0
	var fold_aim := 1.0
	var strength_aim := 0.0
	var beat_rate := 0.0
	var pitch_aim := 0.0
	var flare_aim := 0.0
	var tail_aim := 0.0
	var fan_aim := 0.0
	var bank_aim := 0.0
	var crest_aim := 0.3
	var grip_aim := grip if bird.perch >= 0 else 0.0
	var reach_aim := 0.0
	var crouch_aim := 0.0
	var beak_aim := 0.0
	var fluff_aim := 0.0
	var head_snap := 16.0
	var jay := kind == CorvidBody.Kind.BLUE_JAY
	var raven := kind == CorvidBody.Kind.RAVEN
	var flap_hz := 7.5 if jay else (3.0 if raven else 4.0)
	match bird.act:
		Act.SIT, Act.WAIT:
			_look_about(bird, delta, 0.25)
			pitch_aim = -0.05
		Act.LOOK:
			_look_about(bird, delta, 0.7)
			pitch_aim = -0.08
			crest_aim = 0.55
		Act.PREEN:
			var side := float(bird.count)
			# (the head turned back into the shoulder, nibbling)
			bird.head_aim = Vector3(0.03 * side, -0.035, -0.06) * sz + Vector3(0.0, 0.004 * sin(t * 21.0), 0.004 * sin(t * 15.0)) * sz
			bird.turn_aim = Vector3(2.2 * side, 0.6, 0.35 * side)
			fluff_aim = 0.45
			pitch_aim = 0.05
			head_snap = 10.0
		Act.SHAKE:
			fluff_aim = 1.0 if t < 0.5 else 0.0
			bird.turn_aim = Vector3(0.0, 0.0, 0.5 * sin(t * 48.0) * (1.0 - smoothstep(0.3, 0.75, t)))
			head_snap = 50.0
		Act.TURN:
			crouch_aim = 0.4
			hop_aim = 1.0
			bird.lift = sin(PI * clampf(t / 0.35, 0.0, 1.0)) * 0.03 * sz
		Act.SHUFFLE:
			step_aim = 0.03
			hop_aim = 1.0 if jay else 0.0
			_look_about(bird, delta, 0.5)
		Act.CALL:
			_pose_call(bird, t, delta)
			pitch_aim = bird.pitch
			beak_aim = bird.beak
			fluff_aim = bird.fluff
			tail_aim = bird.tail_lift
			crest_aim = bird.crest
			crouch_aim = bird.crouch
		Act.SCOLD:
			# (crest up, bobbing on its perch, tail flicking, the head on what it scolds)
			crest_aim = 1.0
			crouch_aim = 0.5 + 0.5 * sin(t * 9.0)
			tail_aim = 0.25 * maxf(sin(t * 9.0 + 1.0), 0.0)
			fluff_aim = 0.4
		Act.WALK:
			step_aim = 0.075 * sz
			# (the swagger: the head thrust forward on each step)
			var stride := fmod(bird.walk * 2.0, 1.0)
			bird.head_aim = Vector3(0.0, -0.004, 0.012 * sin(TAU * stride)) * sz
			bird.turn_aim = Vector3(bird.turn_aim.x * 0.95, 0.15, 0.0)
			pitch_aim = 0.12
		Act.HOP:
			hop_aim = 1.0
			step_aim = 0.0
			var phase := fmod(t, 0.32 if jay else 0.4) / (0.32 if jay else 0.4)
			crouch_aim = 1.0 - smoothstep(0.1, 0.3, phase) + smoothstep(0.8, 0.95, phase) * 0.6
			tail_aim = 0.2 * sin(PI * phase)
			pitch_aim = 0.15
			_look_about(bird, delta, 0.4)
		Act.PECK:
			var cycle := fmod(t, 0.45) / 0.45
			pitch_aim = 0.55
			if t < bird.count * 0.45:
				var stab := smoothstep(0.35, 0.5, cycle) * (1.0 - smoothstep(0.55, 0.8, cycle))
				bird.head_aim = Vector3(0.0, -0.05 - 0.07 * stab, 0.03 + 0.02 * stab) * sz
				bird.turn_aim = Vector3(0.0, lerpf(0.5, 1.2, stab), lerpf(0.4 * (1.0 if bird.mark > 0.5 else -1.0), 0.0, smoothstep(0.2, 0.4, cycle)))
				tail_aim = 0.1 * stab
				head_snap = 34.0
			else:
				bird.head_aim = Vector3.ZERO
				bird.turn_aim = Vector3(0.0, 0.1, 0.0)
				pitch_aim = 0.05
		Act.LAND:
			# Touched down: wings fold over the first moments, the body bobs, the tail flicks.
			var u := clampf(t / 0.32, 0.0, 1.0)
			fold_aim = 1.0
			strength_aim = 0.0
			crouch_aim = 0.8 * (1.0 - u)
			tail_aim = 0.35 * sin(PI * u)
			grip_aim = grip if bird.perch >= 0 else 0.0
		Act.FLY:
			var u := clampf(bird.t, 0.0, 1.0)
			fold_aim = 0.0
			tuck_aim = 1.0 if u > 0.08 and u < 0.85 else 0.25
			var climbing := bird.velocity.y > 0.6 or u < 0.25
			strength_aim = 1.0 if climbing else (0.75 if not raven else 0.55)
			beat_rate = flap_hz * (1.3 if climbing else 1.0)
			# (a raven glides between bouts of flapping; a crow now and then; a jay bounds)
			if raven and not climbing and fmod(_time + bird.mark * 5.0, 3.2) > 1.6:
				strength_aim = 0.0
			if not raven and not jay and not climbing and fmod(_time + bird.mark * 5.0, 4.5) > 3.6:
				strength_aim = 0.0
			if jay and not climbing and u < 0.85 and fmod(_time * 1.6 + bird.mark, 1.0) > 0.62:
				fold_aim = 1.0
			# Swinging up to land: the flare, the legs reaching, the tail fanned down.
			var landing := smoothstep(0.78, 0.95, u)
			flare_aim = landing
			reach_aim = smoothstep(0.82, 0.97, u)
			fan_aim = maxf(landing, 0.25 * (1.0 if climbing else 0.0))
			tail_aim = -0.25 * landing
			pitch_aim = _level - clampf(bird.velocity.y * 0.06, -0.35, 0.35) - landing * 0.75
			bird.head_aim = Vector3(0.0, -0.01, 0.015) * sz
			bird.turn_aim = Vector3(0.0, -0.2 + landing * 0.25, 0.0)
			bank_aim = clampf(angle_difference(bird.yaw, atan2(bird.to.x - bird.at.x, bird.to.z - bird.at.z)) * 0.4, -0.5, 0.5)
		Act.CIRCLE:
			fold_aim = 0.0
			tuck_aim = 1.0
			var rising := bird.at.y < (_circle_at.y if _circle_at.is_finite() else home.y) + bird.orbit_h * 0.7 or bird.velocity.y > 0.8
			var phase := fmod(_time * 0.35 + bird.mark, 1.0)
			strength_aim = 1.0 if rising or bird.clock < 1.2 else (0.7 if phase < 0.6 else 0.0)
			if raven and not rising:
				strength_aim = 0.6 if phase < 0.3 else 0.0
			if jay and not rising and fmod(_time * 1.6 + bird.mark, 1.0) > 0.62:
				fold_aim = 1.0
			beat_rate = flap_hz * (1.35 if rising else 1.0)
			pitch_aim = _level - clampf(bird.velocity.y * 0.06, -0.3, 0.35)
			bank_aim = bird.bank
			fan_aim = 0.3 + 0.4 * absf(bird.bank)
			bird.head_aim = Vector3(0.0, -0.01, 0.015) * sz
			bird.turn_aim = Vector3(clampf(bird.bank * -0.6, -0.5, 0.5), 0.15, 0.0)
	# What it watches (or scolds), the head turned to it, sitting.
	var target := _scold if _scold.is_finite() else _watch
	if target.is_finite() and bird.act in [Act.SIT, Act.LOOK, Act.SCOLD, Act.WAIT, Act.SHUFFLE, Act.LAND]:
		_look_at(bird, target)
		crest_aim = maxf(crest_aim, 0.7)
	# A take-off: the first moments of a flight, a crouch and a spring, the wings
	# flung open on a downstroke.
	if bird.act == Act.FLY and bird.clock < 0.18 and bird.t <= 0.12:
		crouch_aim = 1.0 - bird.clock / 0.18
		strength_aim = 1.0
		beat_rate = flap_hz * 1.6
	# The legs.
	bird.step = move_toward(bird.step, step_aim, 1.0 * delta)
	bird.hop = move_toward(bird.hop, hop_aim, 6.0 * delta)
	bird.tuck = move_toward(bird.tuck, tuck_aim, 4.0 * delta)
	if bird.act == Act.WALK and bird.step > 0.005:
		bird.walk = fmod(bird.walk + delta * walk_speed * sz / maxf(bird.step, 0.02) * 0.55, 1.0)
	elif bird.act == Act.SHUFFLE:
		bird.walk = fmod(bird.walk + delta * 2.2, 1.0)
	elif bird.act == Act.HOP:
		bird.walk = 0.0
	bird.head = bird.head.lerp(bird.head_aim, 1.0 - exp(-head_snap * delta))
	bird.turn = bird.turn.lerp(bird.turn_aim, 1.0 - exp(-head_snap * delta))
	if bird.act != Act.CALL:
		bird.beak = move_toward(bird.beak, beak_aim, 8.0 * delta)
		bird.fluff = move_toward(bird.fluff, fluff_aim, (5.0 if fluff_aim > bird.fluff else 1.5) * delta)
		bird.pitch = lerpf(bird.pitch, pitch_aim, 1.0 - exp(-7.0 * delta))
		bird.tail_lift = lerpf(bird.tail_lift, tail_aim, 1.0 - exp(-12.0 * delta))
		bird.crest = move_toward(bird.crest, crest_aim, 3.0 * delta)
		bird.crouch = move_toward(bird.crouch, crouch_aim, 6.0 * delta)
	# (folding takes a moment; opening is quick)
	bird.fold = move_toward(bird.fold, fold_aim, (9.0 if fold_aim < bird.fold else 4.5) * delta)
	bird.strength = move_toward(bird.strength, strength_aim, 3.5 * delta)
	bird.flare = move_toward(bird.flare, flare_aim, 4.0 * delta)
	bird.tail_fan = move_toward(bird.tail_fan, fan_aim, 3.0 * delta)
	bird.bank = lerpf(bird.bank, bank_aim, 1.0 - exp(-4.0 * delta))
	bird.grip = move_toward(bird.grip, grip_aim, 4.0 * delta)
	bird.reach = move_toward(bird.reach, reach_aim, 5.0 * delta)
	if beat_rate > 0.0:
		var was := bird.beat
		bird.beat = fmod(bird.beat + beat_rate * delta * (0.92 + 0.16 * bird.mark), 1.0)
		if bird.beat < was and bird.strength > 0.5 and bird.index % 3 == 0:
			flapped.emit(bird.at)
	elif bird.fold > 0.95:
		bird.beat = 0.0


# A call's pose, beat by beat (and the call itself, at the start of each).
func _pose_call(bird: Bird, t: float, delta: float) -> void:
	var length := _call_length() * (2.6 if bird.get_meta(&"hawk", false) else 1.0)
	var k := int(t / length)
	var u := fmod(t, length) / length
	if k >= bird.count:
		bird.beak = move_toward(bird.beak, 0.0, 8.0 * delta)
		bird.pitch = lerpf(bird.pitch, 0.0, 1.0 - exp(-6.0 * delta))
		bird.crouch = move_toward(bird.crouch, 0.0, 6.0 * delta)
		bird.tail_lift = lerpf(bird.tail_lift, 0.0, 1.0 - exp(-8.0 * delta))
		bird.fluff = move_toward(bird.fluff, 0.0, 2.0 * delta)
		return
	if k == int(bird.get_meta(&"calls", 0)):
		bird.set_meta(&"calls", k + 1)
		called.emit(bird.at, _perched_call(bird, k))
	var swell := sin(PI * clampf(u / 0.75, 0.0, 1.0))
	match kind:
		CorvidBody.Kind.CROW:
			# Caw: bowing forward, the tail flicked up, the head thrust out, the bill wide.
			bird.pitch = lerpf(bird.pitch, 0.32 * swell, 1.0 - exp(-14.0 * delta))
			bird.tail_lift = 0.4 * swell
			bird.beak = swell
			bird.fluff = 0.25 * swell
			bird.crouch = 0.5 * swell
			bird.head_aim = Vector3(0.0, -0.006 * swell, 0.018 * swell) * _m
			bird.turn_aim = Vector3(bird.turn_aim.x * 0.9, 0.25 * swell - 0.1, 0.0)
		CorvidBody.Kind.RAVEN:
			# A croak: the throat's hackles out, the head low and forward, the bill
			# open; or a knock (the bill clapped quickly, the head bobbing).
			var knock := bird.get_meta(&"knock", false) as bool
			if knock:
				bird.beak = 0.35 * maxf(sin(u * TAU * 4.0), 0.0)
				bird.head_aim = Vector3(0.0, -0.006 * absf(sin(u * TAU * 4.0)), 0.004) * _m
				bird.fluff = 0.4
			else:
				bird.beak = 0.75 * swell
				bird.fluff = 0.4 + 0.6 * swell
				bird.head_aim = Vector3(0.0, -0.012 * swell, 0.012 * swell) * _m
				bird.pitch = lerpf(bird.pitch, 0.18 * swell, 1.0 - exp(-10.0 * delta))
				bird.tail_lift = 0.15 * swell
			bird.turn_aim = Vector3(bird.turn_aim.x * 0.9, 0.35 * swell, 0.0)
		CorvidBody.Kind.BLUE_JAY:
			# "Jay!": bobbing down and up on the call, the crest raised, the bill wide.
			var hawk := bird.get_meta(&"hawk", false) as bool
			bird.crest = 1.0 if not hawk else 0.4
			bird.beak = swell * (0.9 if not hawk else 0.7)
			bird.crouch = (0.8 * swell) if not hawk else 0.0
			bird.tail_lift = 0.3 * swell
			bird.head_aim = Vector3(0.0, 0.004 * swell, 0.006 * swell) * _m
			bird.turn_aim = Vector3(bird.turn_aim.x * 0.9, -0.15 * swell if not hawk else -0.4, 0.0)
	bird.head = bird.head.lerp(bird.head_aim, 1.0 - exp(-18.0 * delta))


func _perched_call(bird: Bird, _k: int) -> int:
	match kind:
		CorvidBody.Kind.RAVEN:
			return Call.KNOCK if bird.get_meta(&"knock", false) else Call.CROAK
		CorvidBody.Kind.BLUE_JAY:
			if bird.get_meta(&"hawk", false):
				return Call.HAWK
			return Call.JAY if _scold.is_finite() or _rng.randf() < 0.75 else Call.QUEEDLE
	return Call.CAW


# --- Perches and ground ---

func _taken() -> Dictionary:
	var taken := {}
	for bird in _birds:
		if bird.perch >= 0:
			taken[bird.perch] = true
		if bird.going >= 0:
			taken[bird.going] = true
		if bird.act == Act.FLY and bird.count >= 0:
			taken[bird.count] = true
	return taken


func _on_ground_count() -> int:
	var many := 0
	for bird in _birds:
		if bird.on_ground or bird.going_down:
			many += 1
	return many


# The free perch nearest `near` (with `spread`, the next free one round the
# perches in turn, so a flock put on at once fills them evenly), or -1.
func _free_perch(near: Vector3, taken: Dictionary, spread: bool) -> int:
	var best := -1
	var far := INF
	for p in perch_points.size():
		if taken.has(p):
			continue
		# (not right beside another bird)
		var crowded := false
		for q: int in taken:
			if q >= 0 and q < perch_points.size() and perch_points[q].distance_to(perch_points[p]) < 0.32 * _m:
				crowded = true
				break
		if crowded:
			continue
		var d := perch_points[p].distance_squared_to(near) + (_rng.randf() * 4.0 if spread else 0.0)
		if d < far:
			far = d
			best = p
	return best


func _perch_at(point: Vector3, within: float) -> int:
	for p in perch_points.size():
		if perch_points[p].distance_to(point) < within:
			return p
	return -1


# Which way a bird on perch `p` sits: mostly side on to the way the perch
# faces (along a wall's edge, across a branch), now and then facing out.
func _perch_face(p: int, fallback: float) -> float:
	if p < perch_faces.size() and perch_faces[p].length() > 0.01:
		var out := atan2(perch_faces[p].x, perch_faces[p].z)
		if _rng.randf() < 0.3:
			return out + _rng.randf_range(-0.4, 0.4)
		return out + (PI * 0.5 if _rng.randf() < 0.5 else -PI * 0.5) + _rng.randf_range(-0.45, 0.45)
	return fallback


func _put_on_perch(bird: Bird, p: int) -> void:
	bird.perch = p
	bird.on_ground = false
	bird.at = perch_points[p]
	bird.face = _perch_face(p, bird.yaw)
	bird.yaw = bird.face
	bird.going = -1
	bird.depart_in = -1.0
	_start(bird, Act.SIT)
	bird.left = _rng.randf_range(0.2, 3.0)


func _settle_pose(bird: Bird) -> void:
	var flying := bird.act in [Act.FLY, Act.CIRCLE]
	bird.fold = 0.0 if flying else 1.0
	bird.tuck = 1.0 if flying else 0.0
	bird.pitch = _level if flying else 0.0
	bird.grip = 0.6 if bird.perch >= 0 else 0.0


func _ground_spot(near: Vector3) -> Vector3:
	var round_about := _rng.randf_range(0.0, TAU)
	var aim := home + Vector3(cos(round_about), 0.0, sin(round_about)) * _rng.randf_range(0.0, roam * 0.8)
	return _kept(aim.lerp(Vector3(near.x, home.y, near.z), 0.25))


func _ground(at: Vector3) -> float:
	return float(ground_height.call(at)) if ground_height.is_valid() else home.y


func _kept(at: Vector3) -> Vector3:
	var put: Vector3 = keep_in.call(at) if keep_in.is_valid() else at
	put.y = _ground(put)
	return put


func _forward(bird: Bird) -> Vector3:
	return Vector3(sin(bird.yaw), 0.0, cos(bird.yaw))


func _draw_all() -> void:
	if _mesh == null:
		return
	var many := _mesh.multimesh
	var low := Vector3.INF
	var high := -Vector3.INF
	for i in _birds.size():
		var bird := _birds[i]
		var at := bird.at + Vector3.UP * (bird.lift if bird.act in [Act.HOP, Act.TURN] else 0.0)
		many.set_instance_transform(i, Transform3D(Basis(Vector3.UP, bird.yaw).scaled(Vector3.ONE * bird.scale), at))
		_poses[i * 6] = Vector4(bird.walk, bird.step / maxf(bird.scale, 0.01), bird.hop, bird.tuck)
		_poses[i * 6 + 1] = Vector4(bird.head.x, bird.head.y, bird.head.z, bird.turn.x) / Vector4(bird.scale, bird.scale, bird.scale, 1.0)
		_poses[i * 6 + 2] = Vector4(bird.turn.y, bird.turn.z, bird.beak, bird.fluff)
		_poses[i * 6 + 3] = Vector4(bird.fold, bird.beat, bird.strength, bird.pitch)
		_poses[i * 6 + 4] = Vector4(bird.flare, bird.tail_lift, bird.tail_fan, bird.bank)
		_poses[i * 6 + 5] = Vector4(bird.crest, bird.grip, bird.reach, bird.crouch)
		low = low.min(at)
		high = high.max(at)
	_material.set_shader_parameter(&"pose", _poses)
	if low.is_finite():
		var reach := 0.7 * _m
		many.custom_aabb = AABB(low - Vector3(reach, reach, reach), high - low + Vector3(reach, reach, reach) * 2.0)

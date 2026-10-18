class_name ChickenFlock
extends Node3D
## A flock of scruffy chickens, hens and a rooster: how they look and how they
## go about, and nothing about what they mean in a game. A game tells it a few
## things and it does the rest:
##
## - WHERE THEY LIVE: `home` (a point on the ground) and `roam` (how far from it
##   they wander). Left alone they forage there, each on its own: walking with
##   the head-lock (the head held still in the air while the body walks on under
##   it, then darted forward), stopping to peck at the ground in quick runs of
##   pecks, scratching (raking the mud back with one foot and then the other,
##   then stepping back to peck at what they turned up), preening (the head
##   turned back into the feathers), shaking out their feathers, standing and
##   looking about (the head snapped from pose to pose, turned and cocked to look
##   with one eye), clucking. The rooster crows now and then: he flaps, draws
##   himself up and throws his head back.
## - WHAT FRIGHTENS THEM: `scare(from)` and they explode: each, one after
##   another from the nearest out, squawks and bolts away from it, wings beating,
##   and some burst up into the air in short flapping flights, glide down and
##   land running; feathers fly and drift down. They calm down after a few
##   seconds, shake themselves and drift back home. `uneasy` (points, such as
##   where people are) they keep a little way from without panicking, walking off
##   and clucking.
## - WHO HAS MADE THEM FURIOUS: `mob_target`, a point (a head, say), or
##   `Vector3.INF` for nobody. The rooster puffs up, hackles flared, and the
##   whole flock goes for it: they run round it, leap up at it flapping, hang
##   beating round it and peck, fall, and leap again, the rooster most.
##
## Optional: `keep_in`, a Callable(point: Vector3) -> Vector3 that moves a point
## to where they may go (out of walls, say), and `ground_height`, a
## Callable(point: Vector3) -> float, for uneven ground (else it is level with
## `home`). They are not collided with anything else.
##
## Drawn as ONE MultiMesh (ChickenBody's mesh and shader: every bird posed in
## the vertex shader from its pose, which this sets on the flock's material
## every frame), so a flock is one draw (and one for its shadow), and a second,
## small MultiMesh for the loose feathers while there are any. Out of
## `view_range` from the camera, and calm, a flock does no work and is not
## drawn. Signals: `startled` (the first squawk of a panic), `crowed` (the
## rooster, with where he is), `clucked` (now and then, foraging), `furious` (the
## rooster's rage, at a new `mob_target`). The flock is seeded by `flock_seed`:
## two machines that make one with the same seed and home get the same birds.

signal startled
signal crowed(at: Vector3)
signal clucked(at: Vector3)
signal furious
## A bird squawks (bolting, leaping at someone).
signal squawked(at: Vector3)

## The most birds a flock can have (the shader's arrays hold this many).
const MOST := 16
## What each is doing.
enum Act { IDLE, WALK, PECK, SCRATCH, PREEN, CROW, SHAKE, RUN, FLY, MOB, AWAY }

@export_range(1, 16) var count := 10
## How many of them are roosters (the first ones).
@export_range(0, 4) var roosters := 1
@export var flock_seed := 0
## The ground they forage on, and how far from it they wander.
@export var home := Vector3.ZERO
@export var roam := 4.0
## A hen's size (1: about half a metre to the top of her comb); the rooster is a fifth bigger.
@export var size := 1.0
## Speeds, m/s: foraging, bolting, flying.
@export var walk_speed := 0.45
@export var run_speed := 4.2
@export var flight_speed := 4.5
## How many of a panicking flock take to the air (the rest run).
@export_range(0.0, 1.0) var fly_share := 0.4
## How far they keep from `uneasy` points.
@export var shy_distance := 2.2
## How dirty, and how molted (0..1).
@export_range(0.0, 1.0) var filth := 0.6
@export_range(0.0, 1.0) var molt := 0.4
## Colours, by share of the hens: red-brown, speckled, white, black (the rooster's is the first hen's).
@export var colours := Vector4(0.45, 0.2, 0.15, 0.2)
@export var view_range := 75.0
@export var cast_shadows := true
## Tame: ordinary farmyard birds. Scared, they only scatter a few steps (hardly
## ever taking wing) and settle at once; they never mob (`mob_target` is ignored).
@export var tame := false
## The low-detail bird (about a third of the triangles), for phones.
@export var low_poly := false

## Optional: Callable(point: Vector3) -> Vector3, where a bird at `point` may be instead.
var keep_in := Callable()
## Optional: Callable(point: Vector3) -> float, the ground's height there.
var ground_height := Callable()
## Who has made them furious (a point, a head); Vector3.INF: nobody.
var mob_target := Vector3.INF
## Points they keep `shy_distance` from (calmly).
var uneasy := PackedVector3Array()
## For pictures: nothing moves but what `pose_bird` says.
var frozen := false

var _birds: Array[Bird] = []
var _mesh: MultiMeshInstance3D
var _material: ShaderMaterial
var _poses := PackedVector4Array()
var _looks := PackedVector4Array()
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _mob_was := Vector3.INF
var _panic_left := 0.0
var _scared_from := Vector3.INF
var _feathers: MultiMeshInstance3D
var _loose: Array[Loose] = []


## One bird: what it is doing and how it is posed.
class Bird:
	var rooster := false
	var variant := 0
	var mark := 0.0
	var scale := 1.0
	var act := Act.IDLE
	var left := 0.0
	var at := Vector3.ZERO
	var moving := Vector3.ZERO
	var yaw := 0.0
	var height := 0.0
	var climb := 0.0
	var goal := Vector3.ZERO
	var count := 0
	var clock := 0.0
	var startle_in := -1.0
	var flies := false
	var flee := Vector3.ZERO
	var orbit := 0.0
	var leap_in := 0.0
	var hover := 0.0
	var crow_in := 0.0
	var cluck_in := 0.0
	# The pose: legs, head, beak, feathers, wings, body.
	var walk := 0.0
	var step := 0.0
	var scratch := 0.0
	var tuck := 0.0
	var head := Vector3.ZERO
	var head_aim := Vector3.ZERO
	var lock := 0.0
	var turn := Vector3.ZERO
	var turn_aim := Vector3.ZERO
	var look_in := 0.0
	var beak := 0.0
	var puff := 0.0
	var wings := 0.0
	var beat := 0.0
	var strength := 0.0
	var pitch := 0.0


## A loose feather, drifting down.
class Loose:
	var at := Vector3.ZERO
	var moving := Vector3.ZERO
	var spin := 0.0
	var age := 0.0
	var colour := Color.WHITE
	var settled := false


func _ready() -> void:
	_rng.seed = flock_seed
	_material = ChickenBody.material()
	_material.set_shader_parameter(&"filth", filth)
	_mesh = MultiMeshInstance3D.new()
	_mesh.name = "Birds"
	_mesh.top_level = true
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.material_override = _material
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.mesh = ChickenBody.mesh(low_poly)
	many.instance_count = mini(count, MOST)
	_mesh.multimesh = many
	add_child(_mesh)
	_mesh.global_transform = Transform3D.IDENTITY
	_poses.resize(MOST * 4)
	_looks.resize(MOST)
	_make_feathers()
	_make_birds()
	_draw_all()


func _make_birds() -> void:
	_birds.clear()
	var total := colours.x + colours.y + colours.z + colours.w
	for i in mini(count, MOST):
		var bird := Bird.new()
		bird.rooster = i < roosters
		var pick := _rng.randf() * maxf(total, 0.001)
		bird.variant = 0 if pick < colours.x else (1 if pick < colours.x + colours.y else (2 if pick < colours.x + colours.y + colours.z else 3))
		bird.mark = _rng.randf()
		bird.scale = size * (1.2 if bird.rooster else _rng.randf_range(0.88, 1.04))
		var round_about := _rng.randf_range(0.0, TAU)
		bird.at = home + Vector3(cos(round_about), 0.0, sin(round_about)) * _rng.randf_range(0.3, roam * 0.7)
		bird.at = _kept(bird.at)
		bird.yaw = _rng.randf_range(-PI, PI)
		bird.left = _rng.randf_range(0.2, 2.0)
		bird.walk = _rng.randf()
		bird.crow_in = _rng.randf_range(4.0, 25.0)
		bird.cluck_in = _rng.randf_range(1.0, 6.0)
		bird.orbit = _rng.randf_range(0.0, TAU)
		_birds.append(bird)
		_looks[i] = Vector4(bird.variant, 1.0 if bird.rooster else 0.0, bird.mark, molt * _rng.randf_range(0.4, 1.2))
	# (the rooster wears the first hen's colours)
	if roosters > 0 and _birds.size() > roosters:
		for r in roosters:
			_birds[r].variant = _birds[roosters].variant
			_looks[r].x = _birds[r].variant
	_material.set_shader_parameter(&"looks", _looks)


# --- What a game tells it ---

## Every bird panics, away from `from`: the nearest first.
func scare(from: Vector3) -> void:
	var first := _panic_left <= 0.0
	_scared_from = from
	_panic_left = 2.0 if tame else 4.0
	# (the nearest two always go up)
	var order := _birds.duplicate()
	order.sort_custom(func(p: Bird, q: Bird) -> bool: return p.at.distance_squared_to(from) < q.at.distance_squared_to(from))
	for k in order.size():
		(order[k] as Bird).flies = (k == 0 and _rng.randf() < 0.3) or _rng.randf() < 0.05 if tame else k < 2 or _rng.randf() < fly_share
	for bird in _birds:
		if bird.act == Act.MOB:
			continue
		var far := Vector2(bird.at.x - from.x, bird.at.z - from.z).length()
		if bird.act == Act.RUN or bird.act == Act.FLY:
			# (already running: on again, away from this)
			bird.flee = _away(bird.at, from)
			# (a runner runs on; a bird in the air does not climb higher for it)
			if bird.act == Act.RUN:
				bird.left = maxf(bird.left, 0.8 if tame else 1.5)
			continue
		bird.startle_in = clampf(far * 0.05, 0.0, 0.35) + _rng.randf_range(0.0, 0.12)
	if first:
		startled.emit()


## Every bird calms down at once (for a game resetting things).
func calm() -> void:
	mob_target = Vector3.INF
	_panic_left = 0.0
	for bird in _birds:
		bird.startle_in = -1.0
		if bird.act in [Act.RUN, Act.FLY, Act.MOB, Act.AWAY]:
			_start(bird, Act.IDLE)


## How many are panicking (running or flying from something).
func panicking() -> int:
	var many := 0
	for bird in _birds:
		if bird.act == Act.RUN or bird.act == Act.FLY or bird.startle_in >= 0.0:
			many += 1
	return many


## How many are in the air.
func flying() -> int:
	var many := 0
	for bird in _birds:
		if bird.height > 0.05:
			many += 1
	return many


## Whether they are mobbing someone.
func mobbing() -> bool:
	return mob_target.is_finite()


## Where they are on average (their feet).
func centre() -> Vector3:
	var sum := Vector3.ZERO
	for bird in _birds:
		sum += bird.at + Vector3.UP * bird.height
	return sum / maxf(_birds.size(), 1)


func bird_position(i: int) -> Vector3:
	return _birds[i].at + Vector3.UP * _birds[i].height


## Whether bird `i` is a rooster.
func is_rooster(i: int) -> bool:
	return _birds[i].rooster


## What bird `i` is doing (Act).
func act_of(i: int) -> int:
	return _birds[i].act


## How many loose feathers are about.
func loose_feathers() -> int:
	return _loose.size()


## Makes the rooster (the first) crow now.
func crow() -> void:
	for bird in _birds:
		if bird.rooster and bird.act in [Act.IDLE, Act.WALK, Act.PECK, Act.SCRATCH, Act.PREEN]:
			_start(bird, Act.CROW)
			return


## Moves bird `i` (for a game laying them out, or for pictures).
func place_bird(i: int, at: Vector3, yaw := 0.0) -> void:
	_birds[i].at = at
	_birds[i].yaw = yaw
	_birds[i].height = 0.0


## For pictures (`frozen`): poses bird `i` exactly. `head` is where the head is
## from rest (the bird's own space), `turn` its yaw, pitch and roll; `wings`
## (open, phase, strength); `legs` (walk phase, step, scratch, tuck).
func pose_bird(i: int, at: Vector3, yaw: float, legs := Vector4.ZERO, head := Vector3.ZERO, turn := Vector3.ZERO, beak := 0.0, puff := 0.0, wings := Vector3.ZERO, pitch := 0.0) -> void:
	var bird := _birds[i]
	bird.at = Vector3(at.x, 0.0, at.z)
	bird.height = at.y
	bird.yaw = yaw
	bird.walk = legs.x
	bird.step = legs.y
	bird.scratch = legs.z
	bird.tuck = legs.w
	bird.head = head
	bird.turn = turn
	bird.beak = beak
	bird.puff = puff
	bird.wings = wings.x
	bird.beat = wings.y
	bird.strength = wings.z
	bird.pitch = pitch
	_draw_all()


# --- Each frame ---

func _process(delta: float) -> void:
	if frozen or _mesh == null:
		_update_feathers(delta)
		return
	var camera := get_viewport().get_camera_3d()
	var calm_now := _panic_left <= 0.0 and not mob_target.is_finite() and _loose.is_empty() and panicking() == 0 and flying() == 0
	var far := camera != null and camera.global_position.distance_to(home) > view_range
	_mesh.visible = not (far and calm_now)
	if far and calm_now:
		return
	delta = minf(delta, 0.05)
	_time += delta
	_panic_left -= delta
	if tame:
		mob_target = Vector3.INF
	if mob_target.is_finite() and not _mob_was.is_finite():
		furious.emit()
		for bird in _birds:
			if bird.act != Act.MOB:
				bird.startle_in = -1.0
				_start(bird, Act.MOB)
				# (the rooster at once, the rest as they see him go)
				bird.left = 0.0 if bird.rooster else _rng.randf_range(0.15, 0.7)
	elif not mob_target.is_finite() and _mob_was.is_finite():
		for bird in _birds:
			if bird.act == Act.MOB:
				_start(bird, Act.RUN if bird.height < 0.05 else Act.FLY)
				bird.flee = _away(bird.at, _mob_was)
				bird.left = _rng.randf_range(0.6, 1.4)
	_mob_was = mob_target
	for bird in _birds:
		if bird.startle_in >= 0.0:
			bird.startle_in -= delta
			if bird.startle_in < 0.0:
				_bolt(bird)
		_think(bird, delta)
		_move(bird, delta)
		_pose(bird, delta)
	_draw_all()
	_update_feathers(delta)


# What each does, act by act.
func _think(bird: Bird, delta: float) -> void:
	bird.left -= delta
	bird.clock += delta
	bird.crow_in -= delta
	bird.cluck_in -= delta
	match bird.act:
		Act.IDLE:
			_look_about(bird, delta, 0.25)
			if bird.left <= 0.0:
				_next(bird)
		Act.WALK:
			var to := bird.goal - bird.at
			to.y = 0.0
			if to.length() < 0.15 or bird.left <= 0.0:
				_start(bird, Act.PECK if _rng.randf() < 0.55 else Act.IDLE)
		Act.PECK, Act.SCRATCH, Act.PREEN, Act.SHAKE, Act.AWAY:
			if bird.left <= 0.0:
				if bird.act == Act.SCRATCH:
					_start(bird, Act.PECK)
					# (a step back, to look at what it turned up)
					bird.at -= _forward(bird) * 0.1 * bird.scale
				else:
					_next(bird)
		Act.CROW:
			if bird.left <= 0.0:
				_start(bird, Act.IDLE)
		Act.RUN:
			if bird.left <= 0.0:
				_start(bird, Act.SHAKE if _rng.randf() < 0.5 else Act.IDLE)
				bird.puff = 0.8
		Act.FLY:
			pass
		Act.MOB:
			if not mob_target.is_finite():
				_start(bird, Act.IDLE)
	if bird.cluck_in <= 0.0:
		bird.cluck_in = _rng.randf_range(2.0, 9.0)
		if bird.act in [Act.IDLE, Act.WALK, Act.PECK, Act.SCRATCH]:
			clucked.emit(bird.at)


# Picks what to do next, foraging.
func _next(bird: Bird) -> void:
	var roll := _rng.randf()
	var from_home := Vector2(bird.at.x - home.x, bird.at.z - home.z).length()
	if bird.rooster and bird.crow_in <= 0.0:
		_start(bird, Act.CROW)
	elif from_home > roam or roll < 0.38:
		_start(bird, Act.WALK)
	elif roll < 0.62:
		_start(bird, Act.PECK)
	elif roll < 0.8:
		_start(bird, Act.SCRATCH)
	elif roll < 0.88:
		_start(bird, Act.PREEN)
	elif roll < 0.92:
		_start(bird, Act.SHAKE)
	else:
		_start(bird, Act.IDLE)


func _start(bird: Bird, act: Act) -> void:
	bird.act = act
	bird.clock = 0.0
	bird.count = 0
	match act:
		Act.IDLE:
			bird.left = _rng.randf_range(0.6, 2.4)
		Act.WALK:
			var from_home := Vector2(bird.at.x - home.x, bird.at.z - home.z).length()
			var aim := home if from_home > roam else bird.at
			var round_about := _rng.randf_range(0.0, TAU)
			bird.goal = _kept(aim + Vector3(cos(round_about), 0.0, sin(round_about)) * _rng.randf_range(0.6, minf(roam, 2.5)))
			bird.left = _rng.randf_range(2.0, 6.0)
		Act.PECK:
			bird.count = _rng.randi_range(2, 6)
			bird.left = bird.count * 0.5 + 0.4
		Act.SCRATCH:
			bird.left = _rng.randf_range(1.2, 2.6)
		Act.PREEN:
			bird.left = _rng.randf_range(1.8, 3.8)
			bird.count = 1 if _rng.randf() < 0.5 else -1
		Act.SHAKE:
			bird.left = 0.9
		Act.CROW:
			bird.left = 2.6
			bird.crow_in = _rng.randf_range(20.0, 45.0)
		Act.RUN:
			bird.left = _rng.randf_range(0.7, 1.4) if tame else _rng.randf_range(1.8, 3.2)
		Act.FLY:
			bird.left = _rng.randf_range(0.35, 0.7)
			bird.climb = _rng.randf_range(3.0, 4.2)
		Act.MOB:
			bird.left = 0.0
			bird.leap_in = _rng.randf_range(0.0, 0.5)
		Act.AWAY:
			bird.left = _rng.randf_range(0.8, 1.6)


# Starts a startled bird off: up into the air or away on foot.
func _bolt(bird: Bird) -> void:
	if not tame or _rng.randf() < 0.5:
		squawked.emit(bird.at)
	bird.flee = _away(bird.at, _scared_from)
	_spill(bird, _rng.randi_range(1, 3))
	if bird.flies:
		_start(bird, Act.FLY)
	else:
		_start(bird, Act.RUN)


# A way to run from `from`: away, spread a little.
func _away(at: Vector3, from: Vector3) -> Vector3:
	var out := at - from
	out.y = 0.0
	if out.length() < 0.05:
		out = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
	return out.normalized().rotated(Vector3.UP, _rng.randf_range(-0.7, 0.7))


func _forward(bird: Bird) -> Vector3:
	return Vector3(sin(bird.yaw), 0.0, cos(bird.yaw))


func _ground(at: Vector3) -> float:
	return float(ground_height.call(at)) if ground_height.is_valid() else home.y


func _kept(at: Vector3) -> Vector3:
	var put: Vector3 = keep_in.call(at) if keep_in.is_valid() else at
	put.y = _ground(put)
	return put


# Moves it: walking or running on the ground, flying, mobbing.
func _move(bird: Bird, delta: float) -> void:
	var wish := Vector3.ZERO
	var turn_rate := 6.0
	match bird.act:
		Act.WALK:
			var to := bird.goal - bird.at
			to.y = 0.0
			wish = to.normalized() * walk_speed * bird.scale
		Act.RUN:
			_tether(bird)
			wish = bird.flee * run_speed * (0.85 + 0.3 * bird.mark) * (0.6 if tame else 1.0)
			turn_rate = 12.0
			_spill_now_and_then(bird, delta, 0.6)
		Act.AWAY:
			wish = bird.flee * walk_speed * 2.2
		Act.FLY:
			_fly(bird, delta)
			return
		Act.MOB:
			_mob(bird, delta)
			return
	# Keeping from people, calmly (but for those already fleeing).
	if bird.act in [Act.IDLE, Act.WALK, Act.PECK, Act.SCRATCH, Act.PREEN, Act.SHAKE]:
		for point in uneasy:
			var off := bird.at - point
			off.y = 0.0
			if off.length() < shy_distance:
				bird.flee = off.normalized().rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5))
				_start(bird, Act.AWAY)
				clucked.emit(bird.at)
				wish = bird.flee * walk_speed * 2.2
				break
	# A little room from the others.
	for other in _birds:
		if other == bird:
			continue
		var off := bird.at - other.at
		off.y = 0.0
		var room := 0.28 * (bird.scale + other.scale) * 0.5
		if off.length() < room and off.length() > 0.001:
			wish += off.normalized() * (room - off.length()) * 4.0
	bird.moving = bird.moving.move_toward(wish, (30.0 if bird.act == Act.RUN else 6.0) * delta)
	bird.at += bird.moving * delta
	bird.at = _kept(bird.at)
	if bird.height > 0.0:
		bird.climb -= 18.0 * delta
		bird.height = maxf(bird.height + bird.climb * delta, 0.0)
	var flat := Vector2(bird.moving.x, bird.moving.z)
	if flat.length() > 0.08:
		bird.yaw = lerp_angle(bird.yaw, atan2(flat.x, flat.y), 1.0 - exp(-turn_rate * delta))


# A short flight: up, beating hard; then a glide down on spread wings, braking
# with a few deep beats to land, and away running.
func _fly(bird: Bird, delta: float) -> void:
	var rising := bird.left > 0.0
	var gravity := 3.0 if rising else 7.0
	if rising:
		bird.climb = move_toward(bird.climb, 2.6, 10.0 * delta)
	else:
		bird.climb = maxf(bird.climb - gravity * delta, -2.2)
	bird.height = maxf(bird.height + bird.climb * delta, 0.0)
	_tether(bird)
	var wish := bird.flee * flight_speed * (0.8 + 0.4 * bird.mark)
	bird.moving = bird.moving.move_toward(wish, 12.0 * delta)
	var before := bird.at
	bird.at = _kept(bird.at + bird.moving * delta)
	if (bird.at - before).length() < bird.moving.length() * delta * 0.3:
		# (it has hit a wall: it turns along it)
		bird.flee = bird.flee.rotated(Vector3.UP, PI * 0.5 * (1.0 if bird.mark > 0.5 else -1.0))
	var flat := Vector2(bird.moving.x, bird.moving.z)
	if flat.length() > 0.1:
		bird.yaw = lerp_angle(bird.yaw, atan2(flat.x, flat.y), 1.0 - exp(-8.0 * delta))
	_spill_now_and_then(bird, delta, 1.2)
	if not rising and bird.height <= 0.0 and bird.clock > 0.25:
		_start(bird, Act.RUN)
		bird.left = _rng.randf_range(0.5, 1.2)


# Mobbing: round the target on the ground, leaping up at it, hanging there
# beating and pecking, falling, and leaping again.
func _mob(bird: Bird, delta: float) -> void:
	if bird.left > 0.0:
		# (it has not seen yet: it stares, puffing up)
		return
	var target := mob_target
	if not target.is_finite():
		return
	bird.orbit += delta * (1.4 + bird.mark) * (1.0 if bird.mark > 0.4 else -1.0)
	var ground := _ground(bird.at)
	var reach := 0.55 + 0.45 * bird.mark if bird.height > 0.05 else 0.8 + 0.6 * bird.mark
	var spot := Vector3(target.x, ground, target.z) + Vector3(cos(bird.orbit), 0.0, sin(bird.orbit)) * reach
	var to := spot - bird.at
	to.y = 0.0
	var flat_to_target := Vector2(target.x - bird.at.x, target.z - bird.at.z)
	if bird.height <= 0.0:
		bird.leap_in -= delta
		var wish := to.limit_length(1.0) * run_speed * 1.1
		bird.moving = bird.moving.move_toward(wish, 25.0 * delta)
		if bird.leap_in <= 0.0 and flat_to_target.length() < 1.6:
			# Up at it.
			var rise := maxf(target.y - ground - 0.25 * bird.scale - _rng.randf_range(0.0, 0.5), 0.4)
			bird.climb = sqrt(2.0 * 9.0 * rise)
			bird.height = 0.01
			bird.hover = _rng.randf_range(0.35, 0.9) * (1.4 if bird.rooster else 1.0)
			squawked.emit(bird.at)
			_spill(bird, 1)
	else:
		var near_top := bird.climb < 1.0
		if near_top and bird.hover > 0.0:
			# Hanging there, beating hard, pecking.
			bird.hover -= delta
			bird.climb = move_toward(bird.climb, 0.0, 12.0 * delta)
			var aim_y := target.y - ground - 0.35 * bird.scale + 0.5 * bird.mark + 0.2 * sin(_time * 5.0 + bird.mark * 9.0)
			bird.climb += (aim_y - bird.height) * 3.0 * delta
		else:
			bird.climb -= 9.0 * delta
		bird.height = maxf(bird.height + bird.climb * delta, 0.0)
		bird.moving = bird.moving.move_toward(to * 4.0, 18.0 * delta)
		if bird.height <= 0.0:
			bird.leap_in = _rng.randf_range(0.15, 0.7) * (0.6 if bird.rooster else 1.0)
		_spill_now_and_then(bird, delta, 0.5)
	bird.at = _kept(bird.at + bird.moving * delta)
	# (facing what it is after)
	if flat_to_target.length() > 0.05:
		bird.yaw = lerp_angle(bird.yaw, atan2(flat_to_target.x, flat_to_target.y), 1.0 - exp(-10.0 * delta))


# Snaps the head from pose to pose, as a chicken looks about: turned to look
# with one eye, cocked, held; `rate` how often.
func _look_about(bird: Bird, delta: float, rate: float) -> void:
	bird.look_in -= delta
	if bird.look_in <= 0.0:
		bird.look_in = _rng.randf_range(0.25, 1.4) / maxf(rate * 4.0, 0.1)
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var eye_on := _rng.randf() < 0.6
		bird.turn_aim = Vector3(side * _rng.randf_range(0.2, 0.9) if eye_on else _rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.3, 0.25), side * _rng.randf_range(0.2, 0.55) if eye_on else 0.0)
		bird.head_aim = Vector3(0.0, _rng.randf_range(-0.03, 0.025), _rng.randf_range(-0.015, 0.025))


# Works out its pose from what it is doing: legs, head, beak, feathers, wings.
func _pose(bird: Bird, delta: float) -> void:
	var t := bird.clock
	var speed := Vector2(bird.moving.x, bird.moving.z).length() / bird.scale
	var on_ground := bird.height <= 0.02
	# Defaults, that each act changes.
	var step_aim := 0.0
	var scratch_aim := 0.0
	var tuck_aim := 0.0
	var pitch_aim := 0.0
	var puff_aim := 0.0
	var wings_aim := 0.0
	var strength_aim := 0.0
	var beat_rate := 0.0
	var beak_aim := 0.0
	var head_snap := 18.0
	var locked := false
	# Clucking: the beak opens a little now and then.
	if fmod(_time + bird.mark * 7.0, 3.1) < 0.12:
		beak_aim = 0.25
	match bird.act:
		Act.IDLE, Act.AWAY:
			if bird.act == Act.AWAY:
				step_aim = 0.12
				locked = true
				_look_about(bird, delta, 0.6)
		Act.WALK:
			step_aim = 0.1
			locked = true
			if bird.look_in <= 0.0 or _rng.randf() < delta * 0.5:
				bird.turn_aim = Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf_range(-0.1, 0.35), _rng.randf_range(-0.2, 0.2))
				bird.look_in = _rng.randf_range(0.5, 1.5)
			bird.look_in -= delta
			bird.head_aim.y = -0.02
			pitch_aim = 0.08
		Act.PECK:
			# Each peck: down fast, a stab, up part way; looking between with one eye.
			pitch_aim = 0.7
			var cycle := fmod(t, 0.5) / 0.5
			var low := Vector3(0.0, -0.36, 0.17)
			var hover := Vector3(0.0, -0.27, 0.15)
			if t < bird.count * 0.5:
				var stab := smoothstep(0.35, 0.5, cycle) * (1.0 - smoothstep(0.55, 0.75, cycle))
				bird.head_aim = hover.lerp(low, stab)
				bird.turn_aim = Vector3(0.0, lerpf(0.6, 1.25, stab), lerpf(0.45 * (1.0 if bird.mark > 0.5 else -1.0), 0.0, smoothstep(0.2, 0.4, cycle)))
				head_snap = 40.0
			else:
				bird.head_aim = Vector3(0.0, -0.05, 0.02)
				bird.turn_aim = Vector3(0.0, 0.2, 0.0)
				pitch_aim = 0.1
		Act.SCRATCH:
			scratch_aim = 1.0
			pitch_aim = 0.32
			bird.head_aim = Vector3(0.0, -0.17, 0.08)
			bird.turn_aim = Vector3(0.3 * sin(t * 2.0), 0.85, 0.4 * sin(t * 1.3))
		Act.PREEN:
			var side := float(bird.count)
			bird.head_aim = Vector3(0.055 * side, -0.1, -0.12)
			bird.turn_aim = Vector3(2.3 * side, 0.7, 0.4 * side)
			# (nibbling)
			bird.head_aim += Vector3(0.0, 0.012 * sin(t * 23.0), 0.012 * sin(t * 17.0))
			puff_aim = 0.35
			wings_aim = 0.08
			pitch_aim = 0.05
		Act.SHAKE:
			puff_aim = 1.0 if t < 0.55 else 0.0
			bird.turn_aim = Vector3(0.0, 0.0, 0.5 * sin(t * 45.0) * (1.0 - smoothstep(0.3, 0.8, t)))
			wings_aim = 0.25 * (1.0 - smoothstep(0.4, 0.8, t))
			strength_aim = 0.3
			beat_rate = 8.0
			head_snap = 50.0
		Act.CROW:
			if t < 0.75:
				# Wings beaten first, standing tall.
				wings_aim = 1.0
				strength_aim = 1.0
				beat_rate = 4.5
				pitch_aim = -0.3
				bird.head_aim = Vector3(0.0, 0.02, 0.0)
				bird.turn_aim = Vector3.ZERO
			else:
				if bird.count == 0:
					bird.count = 1
					crowed.emit(bird.at)
				var u := (t - 0.75) / 1.6
				pitch_aim = -0.35
				bird.head_aim = Vector3(0.0, 0.07, 0.05)
				bird.turn_aim = Vector3(0.0, -0.75, 0.0)
				# (cock-a-doodle-doo: four calls, the last long)
				var call := 0.0
				if u < 1.0:
					var syll := u * 4.0
					call = sin(PI * fposmod(syll, 1.0)) if syll < 3.0 else sin(PI * clampf((syll - 3.0), 0.0, 1.0))
				beak_aim = call
				puff_aim = 0.45
				wings_aim = 0.12
		Act.RUN:
			step_aim = clampf(speed * 0.085, 0.12, 0.32)
			pitch_aim = 0.12
			wings_aim = 0.6
			strength_aim = 0.75
			beat_rate = 7.0
			beak_aim = 0.6 + 0.4 * sin(_time * 19.0 + bird.mark * 5.0)
			bird.head_aim = Vector3(0.0, -0.04, 0.06)
			bird.turn_aim = Vector3(0.0, -0.1, 0.0)
			puff_aim = 0.4
		Act.FLY:
			tuck_aim = 0.9 if bird.height > 0.15 else 0.2
			wings_aim = 1.0
			var rising := bird.left > 0.0
			strength_aim = 1.0 if rising or bird.height < 0.4 else 0.25
			beat_rate = 6.0
			pitch_aim = -0.1 if rising else 0.15
			beak_aim = 0.8
			bird.head_aim = Vector3(0.0, -0.03, 0.05)
			bird.turn_aim = Vector3(0.0, -0.15, 0.0)
			puff_aim = 0.3
		Act.MOB:
			puff_aim = 1.0 if bird.rooster else 0.7
			beak_aim = 0.5 + 0.5 * sin(_time * 15.0 + bird.mark * 4.0)
			if bird.left > 0.0:
				# Squaring up: low, puffed, hackles out, staring.
				pitch_aim = 0.35
				bird.head_aim = Vector3(0.0, -0.12, 0.08)
				bird.turn_aim = Vector3(0.0, 0.0, 0.0)
				wings_aim = 0.2
				bird.left -= delta
			elif on_ground:
				step_aim = clampf(speed * 0.085, 0.0, 0.3)
				pitch_aim = 0.25
				wings_aim = 0.55
				strength_aim = 0.6
				beat_rate = 7.0
				bird.head_aim = Vector3(0.0, -0.08, 0.07)
				bird.turn_aim = Vector3(0.0, -0.4, 0.0)
			else:
				tuck_aim = 0.15
				wings_aim = 1.0
				strength_aim = 1.0
				beat_rate = 7.5
				pitch_aim = -0.45
				# (pecking at the face: the head stabs forward)
				var stab := maxf(sin(_time * 11.0 + bird.mark * 6.0), 0.0)
				bird.head_aim = Vector3(0.0, 0.02, 0.05 + 0.08 * stab)
				bird.turn_aim = Vector3(0.0, -0.3 + 0.6 * stab, 0.0)
				head_snap = 40.0
	# Off the ground the legs tuck or reach for it.
	if not on_ground and bird.act != Act.FLY and bird.act != Act.MOB:
		tuck_aim = 0.6
	# The legs: a stride that matches the speed (and goes on round while scratching).
	bird.step = move_toward(bird.step, step_aim, 1.5 * delta)
	bird.scratch = move_toward(bird.scratch, scratch_aim, 4.0 * delta)
	bird.tuck = move_toward(bird.tuck, tuck_aim, 5.0 * delta)
	if bird.scratch > 0.05:
		bird.walk = fmod(bird.walk + delta * 1.9, 1.0)
	elif bird.step > 0.01 and on_ground:
		var length := maxf(bird.step, 0.03)
		bird.walk = fmod(bird.walk + delta * 0.6 * speed / length, 1.0)
	# The head-lock: walking, the head stays where it is in the air (it slides
	# back on the body as the body goes on) and then darts forward.
	if locked and speed > 0.05:
		bird.lock -= speed * delta
		if bird.lock < -0.035:
			bird.lock = 0.04
	else:
		bird.lock = move_toward(bird.lock, 0.0, 0.3 * delta)
	var head_goal := bird.head_aim + Vector3(0.0, 0.0, bird.lock)
	bird.head = bird.head.lerp(head_goal, 1.0 - exp(-head_snap * delta))
	if locked and speed > 0.05:
		# (the lock is exact: no lag on z)
		bird.head.z = head_goal.z
	bird.turn = bird.turn.lerp(bird.turn_aim, 1.0 - exp(-head_snap * delta))
	bird.beak = move_toward(bird.beak, beak_aim, 8.0 * delta)
	bird.puff = move_toward(bird.puff, puff_aim, (6.0 if puff_aim > bird.puff else 1.5) * delta)
	bird.wings = move_toward(bird.wings, wings_aim, 5.0 * delta)
	bird.strength = move_toward(bird.strength, strength_aim, 5.0 * delta)
	bird.pitch = lerpf(bird.pitch, pitch_aim, 1.0 - exp(-8.0 * delta))
	if beat_rate > 0.0:
		bird.beat = fmod(bird.beat + beat_rate * delta * (0.9 + 0.2 * bird.mark), 1.0)


func _draw_all() -> void:
	if _mesh == null:
		return
	var many := _mesh.multimesh
	var low := Vector3.INF
	var high := -Vector3.INF
	for i in _birds.size():
		var bird := _birds[i]
		var at := bird.at + Vector3.UP * bird.height
		many.set_instance_transform(i, Transform3D(Basis(Vector3.UP, bird.yaw).scaled(Vector3.ONE * bird.scale), at))
		_poses[i * 4] = Vector4(bird.walk, bird.step, bird.scratch, bird.tuck)
		_poses[i * 4 + 1] = Vector4(bird.head.x, bird.head.y, bird.head.z, bird.turn.x)
		_poses[i * 4 + 2] = Vector4(bird.turn.y, bird.turn.z, bird.beak, bird.puff)
		_poses[i * 4 + 3] = Vector4(bird.wings, bird.beat, bird.strength, bird.pitch)
		low = low.min(at)
		high = high.max(at)
	_material.set_shader_parameter(&"pose", _poses)
	# (the birds' reach round their feet: wings spread, heads up)
	if low.is_finite():
		many.custom_aabb = AABB(low - Vector3(0.6, 0.2, 0.6), high - low + Vector3(1.2, 1.3, 1.2))


# --- Loose feathers ---

func _make_feathers() -> void:
	_feathers = MultiMeshInstance3D.new()
	_feathers.name = "Feathers"
	_feathers.top_level = true
	_feathers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var look := StandardMaterial3D.new()
	look.vertex_color_use_as_albedo = true
	look.vertex_color_is_srgb = true
	look.cull_mode = BaseMaterial3D.CULL_DISABLED
	look.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	look.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_feathers.material_override = look
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_colors = true
	many.mesh = _feather_mesh()
	many.instance_count = 48
	many.visible_instance_count = 0
	_feathers.multimesh = many
	add_child(_feathers)
	_feathers.global_transform = Transform3D.IDENTITY


# A loose contour feather: a small curved vane with a shaft, 10 cm long.
static func _feather_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 4
	var points: Array[Vector3] = []
	for r in rows + 1:
		var t := float(r) / rows
		var half := 0.018 * (0.4 + 0.6 * sin(PI * minf(0.15 + t * 0.9, 0.98)))
		var bend := 0.006 * t * t
		points.append(Vector3(-half, bend - 0.002, t * 0.09))
		points.append(Vector3(0.0, bend + 0.001, t * 0.09))
		points.append(Vector3(half, bend - 0.002, t * 0.09))
	var tip := Vector3(0.0, 0.008, 0.1)
	for r in rows:
		var a := r * 3
		var b := a + 3
		for quad: Array in [[a, b, b + 1, a + 1], [a + 1, b + 1, b + 2, a + 2]]:
			for k: int in [quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]]:
				st.set_normal(Vector3.UP)
				st.add_vertex(points[k])
	var last := rows * 3
	for tri: Array in [[points[last], tip, points[last + 1]], [points[last + 1], tip, points[last + 2]]]:
		for p: Vector3 in tri:
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	# (and its quill)
	return st.commit()


# Feathers knocked out of `bird`, into the air round it.
func _spill(bird: Bird, many: int) -> void:
	for k in many:
		if _loose.size() >= 48:
			_loose.pop_front()
		var one := Loose.new()
		one.at = bird.at + Vector3.UP * (bird.height + 0.3 * bird.scale) + Vector3(_rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.05, 0.1), _rng.randf_range(-0.1, 0.1))
		one.moving = Vector3(_rng.randf_range(-1.2, 1.2), _rng.randf_range(0.6, 2.0), _rng.randf_range(-1.2, 1.2)) + bird.moving * 0.3
		one.spin = _rng.randf_range(0.0, TAU)
		one.colour = _feather_colour(bird)
		_loose.append(one)


func _spill_now_and_then(bird: Bird, delta: float, rate: float) -> void:
	if _rng.randf() < rate * delta:
		_spill(bird, 1)


func _feather_colour(bird: Bird) -> Color:
	match bird.variant:
		0:
			return Color(0.88, 0.42, 0.16) if bird.rooster else Color(0.56, 0.27, 0.11)
		1:
			return Color(0.42, 0.19, 0.08) if _rng.randf() < 0.6 else Color(0.9, 0.88, 0.82)
		2:
			return Color(0.86, 0.84, 0.77)
	return Color(0.08, 0.08, 0.085)


func _update_feathers(delta: float) -> void:
	if _feathers == null:
		return
	var many := _feathers.multimesh
	var i := _loose.size() - 1
	while i >= 0:
		var one := _loose[i]
		one.age += delta
		if one.age > 9.0:
			_loose.remove_at(i)
		i -= 1
	for k in _loose.size():
		var one := _loose[k]
		var ground := _ground(one.at)
		var drift := 0.0
		if not one.settled:
			# Drifting down: slowed by the air, rocking side to side as it falls.
			one.moving.y = maxf(one.moving.y - 6.0 * delta, -0.45)
			one.moving.x = lerpf(one.moving.x, 0.0, 1.0 - exp(-2.5 * delta))
			one.moving.z = lerpf(one.moving.z, 0.0, 1.0 - exp(-2.5 * delta))
			drift = sin(one.age * 4.0 + one.spin)
			one.at += (one.moving + Vector3(cos(one.spin), 0.0, sin(one.spin)) * drift * 0.5) * delta
			if one.at.y <= ground + 0.004:
				one.at.y = ground + 0.004
				one.settled = true
		var rock := Basis(Vector3.UP, one.spin + one.age * (0.0 if one.settled else 1.5)) * Basis(Vector3.FORWARD, 0.0 if one.settled else drift * 0.7)
		var fade := 1.0 - smoothstep(7.0, 9.0, one.age)
		many.set_instance_transform(k, Transform3D(rock.scaled(Vector3.ONE * maxf(fade, 0.01)), one.at))
		many.set_instance_color(k, one.colour)
	many.visible_instance_count = _loose.size()
	_feathers.visible = not _loose.is_empty()


# A bird that has run far from home (three times `roam`) turns back round towards it.
func _tether(bird: Bird) -> void:
	var out := bird.at - home
	out.y = 0.0
	if out.length() > roam * 3.0 and bird.flee.dot(out.normalized()) > 0.0:
		bird.flee = bird.flee.slerp(-out.normalized(), 0.15).normalized()

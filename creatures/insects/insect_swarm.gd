class_name InsectSwarm
extends Node3D
## A swarm of small flying insects: moths, flies or dragonflies (InsectLook),
## how they look and how they fly, and nothing of what they mean in a game.
## The game says what they gather round, where they may land and who
## disturbs them; they do the rest.
##
##     var moths := InsectSwarm.new()
##     moths.kind = InsectLook.Kind.MOTH
##     moths.count = 20
##     moths.swarm_seed = 7
##     moths.follow = lamp            # (or moths.centre = a point)
##     moths.radius = 1.2
##     add_child(moths)
##     moths.scarers = [player]       # perched ones fly off when he comes near
##
## - MOTHS flutter round their centre (a light) in a loose cloud, each on its
##   own erratic orbit (wide or tight, high or low, either way round), lurching
##   this way and that, and every few seconds one blunders straight into the
##   light and bounces off it. They keep their backs to the light. Given
##   `perches` (points on a wall), some go and rest there, wings spread flat,
##   and take off again when someone comes near.
## - FLIES buzz round their centre (carrion) close in, darting from point to
##   point in short straight hops, a few at a time landing on it (`perches`, or
##   anywhere on its top if there are none) to crawl about with their wings
##   folded, then up again. `land_on_still` of them land on anyone who stands
##   still near them for `still_time`, and crawl on their head and shoulders
##   until they move. `buzz` gives them a buzz (made in code), heard from
##   among them.
## - DRAGONFLIES hunt over their patch (`radius` round the centre, at
##   `patrol_height` over it): they hover, then dart off fast in a straight
##   line, often turning sharply (a right angle, or straight back), hover
##   again; now and then one flies to a perch (a reed's tip) and sits with its
##   wings held out flat, until disturbed.
##
## `scarers` (nodes, the players) send perched insects off when they come
## within `scare_range` moving, or half of it standing.
##
## THE COST is kept small. A swarm is ONE MultiMesh (one draw; the wings beat
## in the vertex shader), moved in one loop and written to it in one piece.
## Further than `active_range` from the camera (or with `active` off) it is
## not drawn and not moved at all; a swarm that is not seen costs nothing.
## Seeded by `swarm_seed`: two machines that make the same swarm get the same
## insects (they drift apart in the details, which no one can tell).
##
## The insects are in the world; this node's own place is only where the
## swarm is when it has no `follow` and its `centre` is not set.

## Some that were resting took off because someone came near.
signal scattered

enum State { FLY, LAND, PERCH, ON }

@export var kind := InsectLook.Kind.MOTH
@export_range(1, 200) var count := 20
## Wing tip to wing tip, metres (least, most).
@export var wingspan := Vector2(0.06, 0.09)
@export var swarm_seed := 0
## How far out from the centre they fly, metres (flies: how far round the
## carrion their hops reach; dragonflies: their patch).
@export var radius := 1.2
## How far below and above the centre they go (metres).
@export var spread_height := Vector2(-0.6, 0.8)
## Dragonflies: how high over the centre they hunt.
@export var patrol_height := Vector2(0.35, 1.6)
## How fast they fly, metres a second (dragonflies: their dart).
@export var speed := 1.6
## Wingbeats a second (as drawn: a fly's are a blur whatever this is).
@export var flap_rate := 9.0
## The chance that one goes and rests on a perch when it has flown a while, and how long it rests (s).
@export_range(0.0, 1.0) var rest_share := 0.2
@export var rest_time := Vector2(4.0, 14.0)
@export var fly_time := Vector2(3.0, 10.0)
## Moths: the share of them that are of each kind (dusty, luna, death's-head).
@export var varieties := Vector3(1.0, 0.0, 0.0)
## Perched ones fly off when a scarer comes this near moving (or half of it standing).
@export var scare_range := 2.5
## Flies: how many may land on a scarer who stands still near them, and after how long.
@export_range(0, 16) var land_on_still := 0
@export var still_time := 3.0
## Flies with no perches land anywhere on the top of their carrion: how high
## over the centre its top is (less than 0: most of `spread_height`'s top).
@export var land_height := -1.0
## A scarer's height (for where flies land on him), metres.
@export var scarer_height := 1.6
## A buzz, made in code, heard from among them (flies).
@export var buzz := false
@export var buzz_volume_db := -8.0
## Further than this from the camera they are not drawn or moved.
@export var active_range := 45.0

## What they gather round, in the world (with no `follow`). INF: this node's place.
var centre := Vector3.INF
## A node they gather round instead (a lamp, carrion), and how far from its origin.
var follow: Node3D
var follow_offset := Vector3.ZERO
## Where they may land: transforms whose origin is on the surface, Y out of it
## and Z the way an insect resting there faces. In the world, or in `follow`'s
## own space if `perches_follow`.
var perches: Array[Transform3D] = []
var perches_follow := false
## Optional: Callable(perch: int, point: Vector3) -> Vector3, how far a perch has
## moved from where it is (a reed nodding in the wind).
var perch_moves := Callable()
## Who sends them off a perch (and whom flies land on): Node3D's.
var scarers: Array = []
## Off: not drawn, not moved (a moth cloud that is out only at dusk).
var active := true
## Frozen: not moved (for pictures); they are drawn as they were.
var frozen := false

## How long the last update took, microseconds (all swarms: `cost_total`).
var cost := 0
static var cost_total := 0
static var _cost_frame := -1

var _mesh: MultiMeshInstance3D
var _buffer := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _seen := false
var _seen_check := 0.0
var _last_centre := Vector3.INF
var _sound: AudioStreamPlayer3D
var _still := {}
var _scarer_was := {}

# Each insect: what it is doing and until when, where it is and how it goes,
# which way it faces and which way is up for it, its wingbeat and how hard it
# beats, its size, variety and shade, where it is making for (and a jolt off
# that), its orbit (how far out, how fast and which way, where round, how high
# it bobs), its perch (or whom it is on, and where on him).
var _state := PackedInt32Array()
var _timer := PackedFloat32Array()
var _at := PackedVector3Array()
var _moving := PackedVector3Array()
var _facing := PackedVector3Array()
var _up := PackedVector3Array()
var _beat := PackedFloat32Array()
var _strength := PackedFloat32Array()
var _size := PackedFloat32Array()
var _variety := PackedFloat32Array()
var _tone := PackedFloat32Array()
var _goal := PackedVector3Array()
var _goal_in := PackedFloat32Array()
var _jolt := PackedVector3Array()
var _orbit := PackedVector4Array()
var _round := PackedFloat32Array()
var _perch := PackedInt32Array()
var _on := PackedInt32Array()
var _on_spot := PackedVector3Array()
var _crawl := PackedVector3Array()
var _rush := PackedFloat32Array()


func _ready() -> void:
	_rng.seed = swarm_seed
	_mesh = MultiMeshInstance3D.new()
	_mesh.name = "Insects"
	_mesh.top_level = true
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.material_override = InsectLook.material(kind)
	_mesh.visibility_range_end = active_range + 5.0
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = InsectLook.mesh(kind)
	many.instance_count = count
	_mesh.multimesh = many
	add_child(_mesh)
	_mesh.global_transform = Transform3D.IDENTITY
	_buffer.resize(count * 16)
	_make()
	if buzz:
		_sound = AudioStreamPlayer3D.new()
		_sound.name = "Buzz"
		_sound.stream = buzz_stream()
		_sound.volume_db = buzz_volume_db
		_sound.unit_size = 1.2
		_sound.max_distance = 16.0
		_sound.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		_sound.top_level = true
		add_child(_sound)
	_seen = _near_camera()
	_mesh.visible = _seen and active
	_draw_all()


## Where they gather round, now.
func middle() -> Vector3:
	if follow != null and is_instance_valid(follow) and follow.is_inside_tree():
		return follow.global_transform * follow_offset
	if centre.is_finite():
		return centre
	return global_position if is_inside_tree() else position


## Where insect `i` is.
func insect_position(i: int) -> Vector3:
	return _at[i]


## What insect `i` is doing (State).
func state_of(i: int) -> int:
	return _state[i]


## How many are resting (on a perch, or on someone).
func resting() -> int:
	var n := 0
	for i in count:
		if _state[i] == State.PERCH or _state[i] == State.ON:
			n += 1
	return n


## How many are on someone.
func on_someone() -> int:
	var n := 0
	for i in count:
		if _state[i] == State.ON:
			n += 1
	return n


## Whether it is being drawn and moved (near the camera and active).
func running() -> bool:
	return _seen and active


## The middle of the insects themselves.
func swarm_middle() -> Vector3:
	var sum := Vector3.ZERO
	for i in count:
		sum += _at[i]
	return sum / maxf(count, 1)


## Every insect at rest on a perch at once, if there are perches (for a swarm put down resting).
func settle() -> void:
	if perches.is_empty():
		return
	var taken := {}
	for i in count:
		var k := _free_perch(_at[i], taken, INF)
		if k < 0:
			continue
		taken[k] = true
		_perch[i] = k
		_state[i] = State.PERCH
		_timer[i] = _rng.randf_range(rest_time.x, rest_time.y) * 2.0
		_strength[i] = 0.0
		var spot := _perch_transform(k, i)
		_at[i] = spot.origin
		_facing[i] = spot.basis.z
		_up[i] = spot.basis.y
	_draw_all()


## Sends every resting one off at once, away from `from`.
func scatter(from: Vector3) -> void:
	for i in count:
		if _state[i] in [State.PERCH, State.LAND, State.ON]:
			_take_off(i, from)


func _make() -> void:
	_state.resize(count)
	_timer.resize(count)
	_at.resize(count)
	_moving.resize(count)
	_facing.resize(count)
	_up.resize(count)
	_beat.resize(count)
	_strength.resize(count)
	_size.resize(count)
	_variety.resize(count)
	_tone.resize(count)
	_goal.resize(count)
	_goal_in.resize(count)
	_jolt.resize(count)
	_orbit.resize(count)
	_round.resize(count)
	_perch.resize(count)
	_on.resize(count)
	_on_spot.resize(count)
	_crawl.resize(count)
	_rush.resize(count)
	var c := middle()
	_last_centre = c
	var shares := varieties / maxf(varieties.x + varieties.y + varieties.z, 0.001)
	for i in count:
		_state[i] = State.FLY
		_timer[i] = _rng.randf_range(fly_time.x, fly_time.y) * _rng.randf()
		_size[i] = _rng.randf_range(wingspan.x, wingspan.y)
		var pick := _rng.randf()
		_variety[i] = 0.0 if pick < shares.x else (1.0 if pick < shares.x + shares.y else 2.0)
		if kind != InsectLook.Kind.MOTH:
			_variety[i] = 0.0
		_tone[i] = _rng.randf()
		_beat[i] = _rng.randf()
		_strength[i] = 1.0
		# (orbit: how far out, angular speed and way round, how high, how fast it bobs)
		var out := radius * sqrt(_rng.randf_range(0.08, 1.0))
		var way := 1.0 if _rng.randf() < 0.65 else -1.0
		_orbit[i] = Vector4(out, way * speed / maxf(out, 0.2) * _rng.randf_range(0.5, 1.1), _rng.randf_range(spread_height.x, spread_height.y), _rng.randf_range(0.6, 2.0))
		_round[i] = _rng.randf() * TAU
		var start := c + Vector3(cos(_round[i]) * out, _orbit[i].z, sin(_round[i]) * out)
		if kind == InsectLook.Kind.DRAGONFLY:
			var spot := Vector2.from_angle(_rng.randf() * TAU) * radius * sqrt(_rng.randf())
			start = c + Vector3(spot.x, _rng.randf_range(patrol_height.x, patrol_height.y), spot.y)
		_at[i] = start
		_moving[i] = Vector3.ZERO
		_facing[i] = Vector3(sin(_round[i] * 3.0), 0.0, cos(_round[i] * 3.0))
		_up[i] = Vector3.UP
		_goal[i] = start
		_goal_in[i] = _rng.randf() * 0.5
		_jolt[i] = Vector3.ZERO
		_perch[i] = -1
		_on[i] = -1
		_crawl[i] = Vector3.ZERO
		_rush[i] = 0.0


# --- Each frame ---

func _process(delta: float) -> void:
	if count == 0 or _state.size() != count:
		return
	_seen_check -= delta
	if _seen_check <= 0.0:
		_seen_check = 0.25
		var seen := _near_camera()
		if seen != _seen:
			_seen = seen
			if seen:
				_catch_up()
		_mesh.visible = _seen and active
		if _sound:
			var hear := _seen and active and _hearable()
			if hear and not _sound.playing:
				_sound.play(_rng.randf() * 1.5)
			elif not hear and _sound.playing:
				_sound.stop()
	if not (_seen and active) or frozen:
		return
	var started := Time.get_ticks_usec()
	var dt := minf(delta, 0.05)
	_time += dt
	var c := middle()
	_last_centre = c
	_watch_scarers(dt)
	match kind:
		InsectLook.Kind.DRAGONFLY:
			for i in count:
				_dragonfly(i, dt, c)
		_:
			for i in count:
				_flutter(i, dt, c)
	_draw_all()
	if _sound:
		_sound.global_position = c
	cost = Time.get_ticks_usec() - started
	var frame := Engine.get_process_frames()
	if frame != _cost_frame:
		_cost_frame = frame
		cost_total = 0
	cost_total += cost


func _near_camera() -> bool:
	if not is_inside_tree():
		return false
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return true
	return camera.global_position.distance_to(middle()) < active_range + radius


func _hearable() -> bool:
	var camera := get_viewport().get_camera_3d()
	return camera == null or camera.global_position.distance_to(middle()) < 18.0


## Back in view: what flew round a centre that has moved since is moved with it.
func _catch_up() -> void:
	var c := middle()
	if not _last_centre.is_finite():
		_last_centre = c
		return
	var shift := c - _last_centre
	if shift.length() < 0.01:
		return
	for i in count:
		if _state[i] == State.FLY or _state[i] == State.LAND:
			_at[i] += shift
			_goal[i] += shift
	_last_centre = c


# Who is standing still near them, and for how long (for flies to land on).
func _watch_scarers(dt: float) -> void:
	if land_on_still <= 0 and rest_share <= 0.0 and perches.is_empty():
		return
	for k in scarers.size():
		var who: Node3D = scarers[k] if is_instance_valid(scarers[k]) else null
		if who == null or not who.is_inside_tree():
			_still.erase(k)
			continue
		var at := who.global_position
		var was: Vector3 = _scarer_was.get(k, at)
		var moving := (at - was).length() / maxf(dt, 0.001)
		_scarer_was[k] = at
		if moving < 0.35:
			_still[k] = float(_still.get(k, 0.0)) + dt
		else:
			_still[k] = 0.0
			# (moving: anything on him takes off)
			if moving > 1.0:
				for i in count:
					if _state[i] == State.ON and _on[i] == k:
						_take_off(i, at + Vector3.UP * 1.2)


func _scarer_speed(k: int) -> float:
	return 0.0 if float(_still.get(k, 0.0)) > 0.2 else 2.0


## Whether a scarer is near enough `point` to send a resting insect off it.
func _scared(point: Vector3) -> Vector3:
	for k in scarers.size():
		var who: Node3D = scarers[k] if is_instance_valid(scarers[k]) else null
		if who == null:
			continue
		var at := who.global_position + Vector3.UP * 0.8
		var reach := scare_range if float(_still.get(k, 0.0)) < 0.3 else scare_range * 0.5
		if at.distance_squared_to(point) < reach * reach:
			return at
	return Vector3.INF


# --- Moths and flies ---

func _flutter(i: int, dt: float, c: Vector3) -> void:
	var moth := kind == InsectLook.Kind.MOTH
	match _state[i]:
		State.PERCH, State.ON:
			_resting(i, dt)
			return
		State.LAND:
			_landing(i, dt)
			return
	_timer[i] -= dt
	_goal_in[i] -= dt
	var o := _orbit[i]
	if _goal_in[i] <= 0.0:
		if moth:
			# A lurch off its orbit, now and then a blunder into the light.
			_goal_in[i] = _rng.randf_range(0.15, 0.55)
			_jolt[i] = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.7, 0.7), _rng.randf_range(-1, 1)) * radius * 0.45
			if _rng.randf() < 0.06:
				_rush[i] = 0.45
			if _rng.randf() < 0.05:
				_orbit[i].y = -o.y
		else:
			# A fly: a short hop to another point close round the carrion.
			_goal_in[i] = _rng.randf_range(0.1, 0.42)
			var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.2, 1.0), _rng.randf_range(-1, 1)).normalized()
			_jolt[i] = dir * radius * _rng.randf_range(0.45, 1.25)
			_jolt[i].y = clampf(_jolt[i].y, spread_height.x, spread_height.y)
	var goal: Vector3
	if moth:
		_round[i] += o.y * dt
		goal = c + Vector3(cos(_round[i]) * o.x, o.z + 0.25 * radius * sin(_time * o.w + i), sin(_round[i]) * o.x) + _jolt[i]
		if _rush[i] > 0.0:
			_rush[i] -= dt
			goal = c + _jolt[i] * 0.1
	else:
		goal = c + _jolt[i]
	var want := goal - _at[i]
	var top := speed * (2.2 if _rush[i] > 0.0 else 1.0)
	var aim := want.limit_length(top * 1.0) * (4.0 if not moth else 2.5)
	aim = aim.limit_length(top)
	var accel := 9.0 if moth else 30.0
	_moving[i] = _moving[i].move_toward(aim, accel * dt)
	# (moths flutter: their path wobbles with each beat)
	if moth:
		_moving[i].y += sin(_beat[i] * TAU) * 1.6 * dt * 8.0
	_at[i] += _moving[i] * dt
	# (never through the light itself)
	var off := _at[i] - c
	var keep := radius * 0.12
	if off.length() < keep:
		_at[i] = c + (off.normalized() if off.length() > 0.001 else Vector3.UP) * keep
		_moving[i] = _moving[i].bounce(off.normalized() if off.length() > 0.001 else Vector3.UP) * 0.6
	_turn_to(i, dt, c, 14.0 if moth else 22.0)
	_beat[i] = fposmod(_beat[i] + dt * flap_rate * _rng.randf_range(0.85, 1.15), 1.0) if moth else _rng.randf()
	_strength[i] = move_toward(_strength[i], 1.0, dt * 6.0)
	if _timer[i] <= 0.0:
		_timer[i] = _rng.randf_range(fly_time.x, fly_time.y)
		if _rng.randf() < rest_share:
			_go_rest(i)


# Facing the way it goes (a moth with its back to the light; a fly level, banked a little).
func _turn_to(i: int, dt: float, c: Vector3, rate: float) -> void:
	var heading := _moving[i]
	if heading.length() > 0.05:
		_facing[i] = _facing[i].lerp(heading.normalized(), clampf(rate * dt, 0.0, 1.0)).normalized()
	var up := Vector3.UP
	if kind == InsectLook.Kind.MOTH:
		var to_light := (c - _at[i])
		if to_light.length() > 0.01:
			up = (Vector3.UP * 0.6 + to_light.normalized() * 0.9).normalized()
	_up[i] = _up[i].lerp(up, clampf(6.0 * dt, 0.0, 1.0)).normalized()


func _go_rest(i: int) -> void:
	# (a fly near a still scarer may land on him)
	if land_on_still > 0:
		for k in scarers.size():
			var who: Node3D = scarers[k] if is_instance_valid(scarers[k]) else null
			if who and float(_still.get(k, 0.0)) > still_time and _count_on(k) < land_on_still \
					and who.global_position.distance_to(middle()) < radius + 2.5:
				_on[i] = k
				_on_spot[i] = _spot_on_someone()
				_state[i] = State.LAND
				_timer[i] = 3.0
				return
	if perches.is_empty() and kind == InsectLook.Kind.MOTH:
		return
	if perches.is_empty():
		# (a fly with no perches: lands on the top of the carrion, anywhere)
		_perch[i] = -1
		var dir := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, 0.85)
		var top := sqrt(maxf(1.0 - dir.length_squared(), 0.0))
		_crawl[i] = Vector3(dir.x * radius * 0.8, top * _top(), dir.y * radius * 0.8)
		_state[i] = State.LAND
		_timer[i] = 3.0
		return
	var k := _free_perch(_at[i], _taken_perches(), 6.0 + radius)
	if k < 0:
		return
	_perch[i] = k
	_crawl[i] = Vector3.ZERO
	_state[i] = State.LAND
	_timer[i] = 4.0


func _count_on(k: int) -> int:
	var n := 0
	for i in count:
		if _on[i] == k and (_state[i] == State.ON or _state[i] == State.LAND):
			n += 1
	return n


# A place on someone to land, in his own space: the top of the head, the
# shoulders, the back, the arms.
func _spot_on_someone() -> Vector3:
	var h := scarer_height
	var spots := [Vector3(0.0, h * 1.0, 0.02), Vector3(0.17, h * 0.86, 0.0), Vector3(-0.17, h * 0.86, 0.0),
		Vector3(0.0, h * 0.75, -0.13), Vector3(0.24, h * 0.62, 0.02), Vector3(-0.24, h * 0.62, 0.02), Vector3(0.05, h * 0.92, 0.1)]
	var spot: Vector3 = spots[_rng.randi_range(0, spots.size() - 1)]
	return spot + Vector3(_rng.randf_range(-0.04, 0.04), _rng.randf_range(-0.03, 0.03), _rng.randf_range(-0.03, 0.03))


func _taken_perches() -> Dictionary:
	var taken := {}
	for i in count:
		if _perch[i] >= 0 and (_state[i] == State.PERCH or _state[i] == State.LAND):
			taken[_perch[i]] = true
	return taken


func _free_perch(from: Vector3, taken: Dictionary, reach: float) -> int:
	var best := -1
	var best_d := INF
	var tries := mini(perches.size(), 8)
	for t in tries:
		var k := _rng.randi_range(0, perches.size() - 1)
		if taken.has(k):
			continue
		var d := _perch_point(k).distance_squared_to(from)
		if d < best_d and d < reach * reach:
			best_d = d
			best = k
	return best


func _perch_point(k: int) -> Vector3:
	var spot := perches[k]
	var point := follow.global_transform * spot.origin if perches_follow and follow != null and is_instance_valid(follow) else spot.origin
	if perch_moves.is_valid():
		point += perch_moves.call(k, point)
	return point


# Where insect `i` sits on perch `k`: on the surface, turned its own way about
# the perch's upright, its feet on it.
func _perch_transform(k: int, i: int) -> Transform3D:
	var spot := perches[k]
	var basis := spot.basis
	if perches_follow and follow != null and is_instance_valid(follow):
		basis = follow.global_transform.basis.orthonormalized() * basis
	var turned := basis.rotated(basis.y.normalized(), (_tone[i] - 0.5) * 1.2) if kind != InsectLook.Kind.DRAGONFLY else basis.rotated(basis.y.normalized(), _tone[i] * TAU)
	var point := _perch_point(k) + turned.y.normalized() * _size[i] * 0.06
	return Transform3D(turned.orthonormalized(), point)


func _rest_spot(i: int) -> Transform3D:
	if _state[i] == State.ON or (_state[i] == State.LAND and _on[i] >= 0):
		var who: Node3D = scarers[_on[i]] if _on[i] < scarers.size() and is_instance_valid(scarers[_on[i]]) else null
		if who == null:
			return Transform3D(Basis.IDENTITY, _at[i])
		var place := who.global_transform
		var at := place * (_on_spot[i] + _crawl[i])
		var out := (at - (place.origin + place.basis.y * (_on_spot[i].y - 0.15))).normalized()
		return Transform3D(_basis_from(out, place.basis.z.rotated(out, _tone[i] * TAU)), at + out * 0.004)
	if _perch[i] >= 0 and _perch[i] < perches.size():
		var spot := _perch_transform(_perch[i], i)
		if _crawl[i] != Vector3.ZERO:
			spot.origin += spot.basis.x * _crawl[i].x + spot.basis.z * _crawl[i].z
		return spot
	# (anywhere on the top of the carrion)
	var c := middle()
	var at := c + _crawl[i]
	var out := (_crawl[i] - Vector3(0.0, -radius * 0.3, 0.0)).normalized()
	return Transform3D(_basis_from(out, Vector3(sin(_tone[i] * TAU), 0.0, cos(_tone[i] * TAU))), at)


static func _basis_from(up: Vector3, forward: Vector3) -> Basis:
	var y := up.normalized()
	var z := (forward - y * forward.dot(y))
	z = z.normalized() if z.length() > 0.01 else y.cross(Vector3.RIGHT).normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, z)


func _landing(i: int, dt: float) -> void:
	_timer[i] -= dt
	var spot := _rest_spot(i)
	var want := spot.origin + spot.basis.y * 0.08 - _at[i]
	var near := want.length()
	if near < 0.12:
		want = spot.origin - _at[i]
	var top := speed * (0.7 if near < 0.4 else 1.2)
	_moving[i] = _moving[i].move_toward(want.limit_length(top * 1.0) * 5.0, 14.0 * dt).limit_length(top)
	_at[i] += _moving[i] * dt
	_turn_to(i, dt, middle(), 10.0)
	_beat[i] = fposmod(_beat[i] + dt * flap_rate, 1.0) if kind != InsectLook.Kind.FLY else _rng.randf()
	if (spot.origin - _at[i]).length() < 0.02 + _size[i] * 0.1:
		_state[i] = State.ON if _on[i] >= 0 else State.PERCH
		_timer[i] = _rng.randf_range(rest_time.x, rest_time.y)
		_goal_in[i] = _rng.randf_range(0.3, 1.2)
	elif _timer[i] <= 0.0 or (_on[i] >= 0 and _scarer_left(i)):
		_state[i] = State.FLY
		_on[i] = -1
		_perch[i] = -1
		_timer[i] = _rng.randf_range(fly_time.x, fly_time.y)


func _scarer_left(i: int) -> bool:
	return _on[i] >= scarers.size() or not is_instance_valid(scarers[_on[i]]) or float(_still.get(_on[i], 0.0)) <= 0.0


func _resting(i: int, dt: float) -> void:
	_timer[i] -= dt
	_strength[i] = move_toward(_strength[i], 0.0, dt * 8.0)
	_moving[i] = Vector3.ZERO
	# Flies crawl about in little starts, and rub their legs; others sit still,
	# now and then shivering their wings.
	_goal_in[i] -= dt
	if _goal_in[i] <= 0.0:
		_goal_in[i] = _rng.randf_range(0.4, 1.6)
		if kind == InsectLook.Kind.FLY:
			var step := Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)) * 0.025
			if _perch[i] < 0 and _on[i] < 0:
				# (on the carrion's top: kept on it)
				var c := _crawl[i] + Vector3(step.x, 0.0, step.z) * 2.0
				var flat := Vector2(c.x, c.z)
				if flat.length() > radius * 0.8:
					flat = flat.normalized() * radius * 0.8
				var top := sqrt(maxf(1.0 - (flat / maxf(radius * 0.8, 0.01)).length_squared(), 0.0))
				_crawl[i] = Vector3(flat.x, top * _top(), flat.y)
			elif _on[i] >= 0:
				_crawl[i] = (_crawl[i] + step * 0.6).limit_length(0.05)
			else:
				_crawl[i] = (_crawl[i] + step).limit_length(0.06)
			_tone[i] = fposmod(_tone[i] + _rng.randf_range(-0.08, 0.08), 1.0)
		elif _rng.randf() < 0.25:
			_strength[i] = 0.25
	var spot := _rest_spot(i)
	_at[i] = spot.origin
	_facing[i] = spot.basis.z
	_up[i] = spot.basis.y
	_beat[i] = fposmod(_beat[i] + dt * flap_rate * 0.5, 1.0)
	var fright := _scared(_at[i]) if _on[i] < 0 else Vector3.INF
	if fright.is_finite():
		_take_off(i, fright)
		scattered.emit()
	elif _timer[i] <= 0.0 and _on[i] < 0:
		_state[i] = State.FLY
		_perch[i] = -1
		_timer[i] = _rng.randf_range(fly_time.x, fly_time.y)
		_moving[i] = _up[i] * 0.8


func _take_off(i: int, from: Vector3) -> void:
	_state[i] = State.FLY
	_perch[i] = -1
	_on[i] = -1
	var away := _at[i] - from
	away.y = maxf(away.y, 0.0)
	away = away.normalized() if away.length() > 0.01 else Vector3.UP
	_moving[i] = (away + _up[i] * 0.6 + Vector3(_rng.randf_range(-0.4, 0.4), 0.5, _rng.randf_range(-0.4, 0.4))).normalized() * speed * 2.2
	# (a moment of panic: they fly fast and wide before they settle down)
	_timer[i] = _rng.randf_range(fly_time.x, fly_time.y)
	_goal_in[i] = 0.0
	_strength[i] = 1.0
	if kind == InsectLook.Kind.DRAGONFLY:
		_goal[i] = _at[i] + Vector3(away.x, 0.3, away.z) * _rng.randf_range(3.0, 6.0)
		_goal_in[i] = 0.6


# --- Dragonflies ---

func _dragonfly(i: int, dt: float, c: Vector3) -> void:
	match _state[i]:
		State.PERCH:
			_resting(i, dt)
			return
		State.LAND:
			_landing(i, dt)
			_facing[i].y = 0.0
			_facing[i] = _facing[i].normalized() if _facing[i].length() > 0.01 else Vector3.FORWARD
			_up[i] = Vector3.UP
			return
	_goal_in[i] -= dt
	_timer[i] -= dt
	var to_goal := _goal[i] - _at[i]
	var darting := _goal_in[i] > 0.0 and to_goal.length() > 0.15
	if not darting and _goal_in[i] <= -_jolt[i].x:
		# Hovered long enough: perch, or dart off (straight on, a right angle, or back).
		if _timer[i] <= 0.0 and not perches.is_empty() and _rng.randf() < rest_share * 2.0:
			_timer[i] = _rng.randf_range(fly_time.x, fly_time.y)
			_go_rest(i)
			if _state[i] == State.LAND:
				return
		if _timer[i] <= 0.0:
			_timer[i] = _rng.randf_range(fly_time.x, fly_time.y)
		var heading := Vector3(_facing[i].x, 0.0, _facing[i].z).normalized()
		if heading.length() < 0.5:
			heading = Vector3.FORWARD
		var pick := _rng.randf()
		var turn := 0.0 if pick < 0.3 else (PI * 0.5 if pick < 0.6 else (-PI * 0.5 if pick < 0.9 else PI))
		turn += _rng.randf_range(-0.25, 0.25)
		var dir := heading.rotated(Vector3.UP, turn)
		var goal := _at[i] + dir * _rng.randf_range(1.5, 6.0)
		var flat := Vector2(goal.x - c.x, goal.z - c.z)
		if flat.length() > radius:
			# (back towards the middle of its patch)
			var back := Vector2(c.x - _at[i].x, c.z - _at[i].z).normalized().rotated(_rng.randf_range(-0.6, 0.6))
			goal = _at[i] + Vector3(back.x, 0.0, back.y) * _rng.randf_range(2.0, 6.0)
		goal.y = c.y + clampf(_at[i].y - c.y + _rng.randf_range(-0.5, 0.5), patrol_height.x, patrol_height.y)
		_goal[i] = goal
		_goal_in[i] = 1.6
		# (how long it will hover when it gets there)
		_jolt[i].x = _rng.randf_range(0.25, 2.2)
		to_goal = goal - _at[i]
		darting = true
	if darting:
		var want := to_goal.normalized() * minf(speed, to_goal.length() * 6.0)
		_moving[i] = _moving[i].move_toward(want, 45.0 * dt)
		# (its body swung straight round to the new line, fast)
		var flat_dir := Vector3(to_goal.x, 0.0, to_goal.z)
		if flat_dir.length() > 0.05:
			_facing[i] = _facing[i].lerp(flat_dir.normalized(), clampf(18.0 * dt, 0.0, 1.0)).normalized()
		if to_goal.length() < 0.15:
			_goal_in[i] = 0.0
	else:
		# Hovering: still in the air but for a bob and a sideways slip.
		var bob := Vector3(sin(_time * 1.7 + i) * 0.08, sin(_time * 2.9 + i * 1.3) * 0.12, cos(_time * 1.3 + i * 0.7) * 0.08)
		_moving[i] = _moving[i].move_toward(bob, 30.0 * dt)
	_at[i] += _moving[i] * dt
	_up[i] = Vector3.UP
	_beat[i] = fposmod(_beat[i] + dt * flap_rate * (1.15 if darting else 1.0), 1.0)
	_strength[i] = move_toward(_strength[i], 1.0, dt * 8.0)


# --- Drawing ---

func _draw_all() -> void:
	if _mesh == null or _buffer.size() != count * 16:
		return
	for i in count:
		var forward := _facing[i]
		var up := _up[i]
		var y := up.normalized()
		var z := forward - y * forward.dot(y)
		z = z.normalized() if z.length() > 0.01 else y.cross(Vector3.RIGHT).normalized()
		var x := y.cross(z).normalized()
		# (a dragonfly dips its nose as it speeds up, and lifts it braking)
		if kind == InsectLook.Kind.DRAGONFLY and _state[i] == State.FLY:
			var pitch := clampf(_moving[i].dot(z) * 0.03, -0.25, 0.25)
			z = z.rotated(x, pitch)
			y = y.rotated(x, pitch)
		var s := _size[i]
		var o := _at[i]
		var k := i * 16
		_buffer[k] = x.x * s
		_buffer[k + 1] = y.x * s
		_buffer[k + 2] = z.x * s
		_buffer[k + 3] = o.x
		_buffer[k + 4] = x.y * s
		_buffer[k + 5] = y.y * s
		_buffer[k + 6] = z.y * s
		_buffer[k + 7] = o.y
		_buffer[k + 8] = x.z * s
		_buffer[k + 9] = y.z * s
		_buffer[k + 10] = z.z * s
		_buffer[k + 11] = o.z
		_buffer[k + 12] = _beat[i]
		_buffer[k + 13] = _strength[i]
		_buffer[k + 14] = _variety[i]
		_buffer[k + 15] = _tone[i]
	_mesh.multimesh.buffer = _buffer


# --- The buzz ---

static var _buzz: AudioStreamWAV

## A loop of flies buzzing: a few wingbeat tones (each with its own wavering
## pitch and swelling and fading as one flies by) over a little hiss.
static func buzz_stream() -> AudioStreamWAV:
	if _buzz != null:
		return _buzz
	const RATE := 22050
	const LENGTH := 2.0
	var n := int(RATE * LENGTH)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	# (everything comes round a whole number of times in the loop, so it joins up)
	var flies := []
	for f in 5:
		flies.append([rng.randi_range(340, 470) / LENGTH, rng.randi_range(2, 7) / LENGTH, rng.randf_range(4.0, 14.0),
			rng.randi_range(1, 3) / LENGTH, rng.randf() * TAU, rng.randf_range(0.5, 1.0)])
	var noise := 0.0
	for s in n:
		var t := float(s) / RATE
		var v := 0.0
		for fly: Array in flies:
			var phase: float = TAU * float(fly[0]) * t + float(fly[2]) * sin(TAU * float(fly[1]) * t)
			# (a buzzing wingbeat: a rough saw, its upper harmonics)
			var tone := sin(phase) + 0.5 * sin(2.0 * phase + 0.3) + 0.3 * sin(3.0 * phase + 1.1) + 0.15 * sin(5.0 * phase)
			var swell: float = 0.55 + 0.45 * sin(TAU * float(fly[3]) * t + float(fly[4]))
			v += tone * swell * swell * float(fly[5])
		noise = noise * 0.7 + rng.randf_range(-1.0, 1.0) * 0.3
		samples[s] = v * 0.2 + noise * 0.05
	var peak := 0.001
	for v in samples:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(n * 2)
	for s in n:
		data.encode_s16(s * 2, int(clampf(samples[s] / peak * 0.8, -1.0, 1.0) * 32767.0))
	_buzz = AudioStreamWAV.new()
	_buzz.format = AudioStreamWAV.FORMAT_16_BITS
	_buzz.mix_rate = RATE
	_buzz.data = data
	_buzz.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_buzz.loop_begin = 0
	_buzz.loop_end = n
	return _buzz


# How high over the centre the top of the carrion is, for flies to land on it.
func _top() -> float:
	return land_height if land_height >= 0.0 else maxf(spread_height.y, 0.1) * 0.85

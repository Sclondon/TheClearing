class_name ImpSwarm
extends Node3D
## A swarm of tiny imps: dozens of them pouring out of a crack (this node is
## the crack: the `nest`) as a chattering tide, over the ground and up and
## along the walls, after someone; climbing up them; and home again. How they
## look and move, and nothing of what it means: whatever drives it says who
## they are after and when, and decides what their getting on someone does.
##
##     var swarm := ImpSwarm.new()
##     swarm.count = 48
##     swarm.position = the_foot_of_a_wall
##     add_child(swarm)
##     swarm.target = player             # who they go for (any Node3D)
##     swarm.steer = my_way_finder       # optional: Callable(from: Vector3) -> Vector3, where to make for next
##     swarm.release()                   # out they come (after a chorus of chittering); recall() calls them home
##     swarm.overwhelmed.connect(...)    # enough of them on him for long enough
##
## - THE TIDE. They run at `speed` (a little faster than a boy runs, slower than
##   he sprints), each its own way about the line to him, the ones behind
##   hurrying, so that they come as a carpet. They keep apart by counting
##   themselves into squares of the ground and moving off the fuller ones, and
##   weave as they go.
## - WALLS. Anything higher than `climb` in their way is a wall: a share of them
##   (`climbers`) run up it, slantwise, to as high as `wall_climb` and along it
##   after him, and leap off it at him when they are level with him, or when
##   the wall ends; the rest turn along its foot. Those that like walls make
##   for the nearest one even when nothing is in their way, so the tide runs
##   along the walls as well as the floor.
## - ON HIM. Those that reach him run up him and cling, all round him, at every
##   height (`on_him`). Each has a grip (`hold`, seconds), which goes while he
##   is in the air or going fast; then it is flung off. `shake_off()` flings
##   every one off at once (a roll, a dive). `catch_count` on him for
##   `catch_time` and `overwhelmed` is emitted, and they let go.
## - GIVING UP. Getting no nearer for `give_up_after` seconds (he is up on
##   something, or gone), or with him further than `chase_distance` from the
##   nest, they stream home and go down the crack. `rest_time` before they
##   will come again.
##
## The cost is flat: there is no node for an imp. All of them are one
## MultiMesh (one draw), moved here in one loop and written to it in one
## piece; their legs, tails, wings and jaws move in the shader
## (imp_swarm.gdshader). The ground is found with a ray straight down, once
## for each square of a grid (`CELL` across) round the nest as an imp first
## comes to it, and remembered; walls with a ray across, no more than a few a
## frame.

signal overwhelmed(target: Node3D)
signal came_out
signal went_home

## How many imps.
@export_range(1, 200) var count := 48
## How tall one is (metres, on all fours to the top of its head about a third of this).
@export var imp_size := 0.6
@export var speed := 4.8
## How far from the nest they will follow.
@export var chase_distance := 55.0
## How many come out of the crack a second.
@export var pour_rate := 40.0
## How long they chitter in the crack before they pour out.
@export var warn_time := 1.0
## The highest step they run up, and the furthest they drop off one.
@export var climb := 0.5
@export var drop := 3.0
## How high up a wall they run, at most, and what share of them like walls.
@export var wall_climb := 2.8
@export_range(0.0, 1.0) var climbers := 0.45
## How many on him bring him down, and for how long.
@export var catch_count := 10
@export var catch_time := 1.0
## How long each holds on while he shakes (in the air, or going fast).
@export var hold := Vector2(0.5, 1.3)
## He shakes them as much as being in the air when going faster than this.
@export var shake_speed := 5.0
@export var give_up_after := 5.0
@export var rest_time := 6.0
## A dark crack drawn on the ground at the nest.
@export var crack := true
## Their chatter.
@export var voice := true
@export var volume_db := -4.0

## Who they go for.
var target: Node3D
## Where to make for next from a place (Callable(Vector3) -> Vector3), to find
## the way round walls; empty: straight for him.
var steer := Callable()
## How many are out, and how many on him.
var out := 0
var on_him := 0

enum Mode { DORMANT, WARN, HUNT, HOME }
const HIDDEN := 0
const FLOOR := 1
const WALL := 2
const ON_HIM := 3
const FLUNG := 4

## The side of a square of ground they remember, metres.
const CELL := 0.35
const BLOCKED := 1000000.0
## Rays a frame, down and across.
const RAYS := 30
const WALL_RAYS := 6
const CROWD := 2
## Squares (metres) the way to him is asked for and kept, and for how long.
const STEER_CELL := 2.0
const STEER_KEEP := 0.5

var mode := Mode.DORMANT
var _time := 0.0
var _warn := 0.0
var _rest := 0.0
var _pour := 0.0
var _meter := 0.0
var _best_seen := INF
var _stuck_for := 0.0
var _gap := 0.0
var _rays := 0
var _wall_rays := 0
var _front := Vector3.ZERO

# Each imp.
var _state := PackedByteArray()
var _x := PackedFloat32Array()
var _y := PackedFloat32Array()
var _z := PackedFloat32Array()
var _hx := PackedFloat32Array()
var _hz := PackedFloat32Array()
var _ground := PackedFloat32Array()
var _seed := PackedFloat32Array()
var _pace := PackedFloat32Array()
var _stride := PackedFloat32Array()
var _grown := PackedFloat32Array()
var _detour := PackedFloat32Array()
var _side := PackedFloat32Array()
var _likes_walls := PackedByteArray()
# (on a wall: its normal, which way along, how high it means to go, how long it stays;
#  on him: how far round and up, and its grip; flung: its speed)
var _nx := PackedFloat32Array()
var _nz := PackedFloat32Array()
var _a := PackedFloat32Array()
var _b := PackedFloat32Array()
var _c := PackedFloat32Array()
var _timer := PackedFloat32Array()
var _go := PackedFloat32Array()
var _splay := PackedFloat32Array()
var _daze := PackedFloat32Array()

var _nest := Vector3.ZERO
var _width := 0
var _corner := Vector2.ZERO
var _heights := PackedFloat32Array()
var _crowd := PackedByteArray()
var _crowd_next := PackedByteArray()
var _crowded := PackedInt32Array()
var _crowded_next := PackedInt32Array()
var _steer_cache := {}

var _drawn: MultiMeshInstance3D
var _buffer := PackedFloat32Array()
var _crack: MeshInstance3D
var _chatter: AudioStreamPlayer3D
var _query: PhysicsRayQueryParameters3D

const MODEL := "res://creatures/imp_swarm/models/imp_swarm.glb"
static var _mesh: Mesh
static var _shader: Shader
static var _chatter_stream: AudioStreamWAV


func _ready() -> void:
	_nest = global_position
	var reach := chase_distance + 4.0
	_width = clampi(ceili(reach * 2.0 / CELL) + 1, 8, 400)
	_corner = Vector2(_nest.x, _nest.z) - Vector2.ONE * _width * CELL * 0.5
	_heights.resize(_width * _width)
	_heights.fill(NAN)
	_crowd.resize(_width * _width)
	_crowd_next.resize(_width * _width)
	_query = PhysicsRayQueryParameters3D.new()
	_query.collision_mask = 1
	_query.hit_from_inside = true
	for list: PackedFloat32Array in [_x, _y, _z, _hx, _hz, _ground, _seed, _pace, _stride, _grown, _detour, _side, _nx, _nz, _a, _b, _c, _timer, _go, _splay, _daze]:
		list.resize(count)
	_state.resize(count)
	_likes_walls.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_nest)
	for i in count:
		_seed[i] = rng.randf()
		_pace[i] = rng.randf_range(0.88, 1.12)
		_side[i] = 1.0 if rng.randf() < 0.5 else -1.0
		_likes_walls[i] = 1 if rng.randf() < climbers else 0
		_hz[i] = 1.0
		_x[i] = _nest.x
		_y[i] = _nest.y
		_z[i] = _nest.z
	_drawn = MultiMeshInstance3D.new()
	_drawn.top_level = true
	_drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = mesh()
	many.instance_count = count
	_drawn.multimesh = many
	add_child(_drawn)
	_drawn.global_transform = Transform3D.IDENTITY
	_drawn.custom_aabb = AABB(_nest - Vector3(reach, 8.0, reach), Vector3(reach * 2.0, 20.0, reach * 2.0))
	_buffer.resize(count * 16)
	many.buffer = _buffer
	if crack:
		_crack = MeshInstance3D.new()
		_crack.mesh = _crack_mesh()
		_crack.top_level = true
		_crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_crack)
		_crack.global_position = _nest + Vector3.UP * 0.015
	if voice:
		_chatter = AudioStreamPlayer3D.new()
		_chatter.stream = chatter_sound()
		_chatter.unit_size = 5.0
		_chatter.max_distance = 45.0
		_chatter.volume_db = volume_db
		_chatter.top_level = true
		add_child(_chatter)


## The imp as the swarm draws it, in its material. One for every swarm.
static func mesh() -> Mesh:
	if _mesh == null:
		var model := (load(MODEL) as PackedScene).instantiate()
		var part := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		_mesh = part.mesh
		model.free()
		if _shader == null:
			_shader = load("res://creatures/imp_swarm/imp_swarm.gdshader")
		var made := ShaderMaterial.new()
		made.shader = _shader
		_mesh.surface_set_material(0, made)
	return _mesh


## Lets them out after `target`: a chorus of chittering from the crack, then they pour.
func release() -> void:
	if mode == Mode.HUNT or mode == Mode.WARN:
		return
	mode = Mode.WARN
	_warn = warn_time
	_meter = 0.0
	_best_seen = INF
	_stuck_for = 0.0
	if _chatter:
		_chatter.global_position = _nest + Vector3.UP * 0.3
		_chatter.play()


## Calls them home: they run back to the crack and down it.
func recall() -> void:
	if mode == Mode.DORMANT or mode == Mode.HOME:
		return
	mode = Mode.HOME
	_rest = rest_time
	for i in count:
		if _state[i] == ON_HIM:
			_fling(i, Vector3.ZERO)


## Whether they are out after someone.
func hunting() -> bool:
	return mode == Mode.HUNT or mode == Mode.WARN


## Whether they can be let out again (not resting after giving up).
func rested() -> bool:
	return _rest <= 0.0


## Flings every one of them off him (a roll, a dive).
func shake_off() -> void:
	var going := Vector3.ZERO
	if target and target.get(&"velocity") is Vector3:
		going = target.get(&"velocity")
	for i in count:
		if _state[i] == ON_HIM:
			_fling(i, going)


## Puts them all back in the crack at once.
func reset() -> void:
	mode = Mode.DORMANT
	_state.fill(HIDDEN)
	_buffer.fill(0.0)
	_drawn.multimesh.buffer = _buffer
	out = 0
	on_him = 0
	_meter = 0.0
	if _chatter:
		_chatter.stop()


## The front of them (the one nearest him), for whatever watches it.
func front() -> Vector3:
	return _front


## Where imp `i` is (world), and whether it is out.
func imp_position(i: int) -> Vector3:
	return Vector3(_x[i], _y[i], _z[i])


func imp_state(i: int) -> int:
	return _state[i]


func _physics_process(delta: float) -> void:
	_time += delta
	_rest = maxf(_rest - delta, 0.0)
	var him := Vector3.INF
	var going := Vector3.ZERO
	var shaking := 0.0
	var valid := target != null and is_instance_valid(target) and target.is_inside_tree()
	if valid:
		him = target.global_position
		if target.get(&"velocity") is Vector3:
			going = target.get(&"velocity")
		var air: bool = target.has_method(&"is_on_floor") and not target.call(&"is_on_floor")
		var flat := Vector2(going.x, going.z).length()
		shaking = 1.0 if air else (0.6 if flat > shake_speed else 0.0)
	match mode:
		Mode.DORMANT:
			return
		Mode.WARN:
			_warn -= delta
			if _warn <= 0.0:
				mode = Mode.HUNT
				came_out.emit()
		Mode.HUNT:
			if not valid or Vector2(him.x - _nest.x, him.z - _nest.z).length() > chase_distance:
				recall()
		Mode.HOME:
			if out == 0:
				mode = Mode.DORMANT
				if _chatter:
					_chatter.stop()
				went_home.emit()
				return
	var hunting_now := mode == Mode.HUNT and valid
	if hunting_now and out < count:
		_pour += pour_rate * delta
		while _pour >= 1.0 and out < count:
			_pour -= 1.0
			var found := false
			for i in count:
				if _state[i] == HIDDEN:
					_come_out(i)
					found = true
					break
			if not found:
				out = count
				break
	# (they are counted into one set of squares while they read the last frame's count from the other)
	var spare := _crowd
	_crowd = _crowd_next
	_crowd_next = spare
	var spare_list := _crowded
	_crowded = _crowded_next
	_crowded_next = spare_list
	for index in _crowded_next:
		_crowd_next[index] = 0
	_crowded_next.clear()
	_rays = RAYS
	_wall_rays = WALL_RAYS
	if hunting_now:
		_steer_cache_tick()
	var best := INF
	var best_at := _nest
	var latched := 0
	var active := 0
	var stride_rate := minf(speed / (imp_size * 0.9), 7.0)
	var width := _width
	for i in count:
		var state := _state[i]
		if state == HIDDEN:
			continue
		active += 1
		var seed := _seed[i]
		var big := imp_size * (0.85 + 0.3 * seed) * _grown[i]
		var at := i * 16
		var x := _x[i]
		var y := _y[i]
		var z := _z[i]
		if state == ON_HIM:
			latched += 1
			_c[i] -= delta * shaking
			if not hunting_now or _c[i] <= 0.0:
				_fling(i, going)
				continue
			# Up him and round him.
			var top := 0.25 + seed * 0.95
			_b[i] = minf(_b[i] + delta * 1.2, top)
			_a[i] += delta * (seed - 0.5) * 2.0
			var round_a := _a[i]
			var out_x := cos(round_a)
			var out_z := sin(round_a)
			var wide := 0.17 + 0.05 * sin(_b[i] * 5.0 + seed * 9.0)
			x = him.x + out_x * wide
			y = him.y + _b[i]
			z = him.z + out_z * wide
			_x[i] = x
			_y[i] = y
			_z[i] = z
			_stride[i] += delta * 3.0
			_go[i] = 0.6
			_splay[i] = move_toward(_splay[i], 1.0, delta * 6.0)
			# (its back to the outside, head up)
			_write(at, x, y, z, Vector3(out_x, 0.0, out_z), Vector3.UP, big, i)
			continue
		if state == FLUNG:
			_b[i] -= 18.0 * delta
			x += _a[i] * delta
			y += _b[i] * delta
			z += _c[i] * delta
			var under := _height(x, z, y)
			if under >= BLOCKED:
				_a[i] = -_a[i] * 0.5
				_c[i] = -_c[i] * 0.5
				x = _x[i]
				z = _z[i]
				under = _height(x, z, y)
				if under >= BLOCKED:
					under = y - 0.01
			if y <= under:
				y = under
				_state[i] = FLOOR
				_ground[i] = under
				_daze[i] = 0.3 + seed * 0.4
			_x[i] = x
			_y[i] = y
			_z[i] = z
			_stride[i] += delta * 9.0
			_splay[i] = move_toward(_splay[i], 0.0, delta * 4.0)
			_write(at, x, y, z, Vector3(_hx[i], 0.0, _hz[i]), Vector3(sin(_time * 9.0 + seed * 6.0), 1.0, cos(_time * 7.0 + seed * 4.0)).normalized(), big, i)
			continue
		if state == WALL:
			_wall_step(i, him, hunting_now, delta, big, at)
			continue

		# On the ground. Where it wants to go:
		var ground := _ground[i]
		if ground != ground:
			ground = _height(x, z, y)
			if ground >= BLOCKED:
				ground = y
			y = ground
		var want_x := 0.0
		var want_z := 0.0
		var quick := 1.0
		var still := false
		var apart_kept := true
		if _daze[i] > 0.0:
			# (dazed, after a fall)
			_daze[i] -= delta
			still = true
		elif hunting_now:
			var goal := _goal_from(x, y, z, him)
			want_x = goal.x + (seed - 0.5) * 1.2 - x
			want_z = goal.z + (_pace[i] - 1.0) * 3.0 - z
			var off := (him.x - x) * (him.x - x) + (him.z - z) * (him.z - z)
			var apart := off + (him.y - y) * (him.y - y)
			if apart < best:
				best = apart
				best_at = Vector3(x, y, z)
			apart_kept = off > 0.6
			quick = clampf(1.0 + (sqrt(off) - _gap - 1.0) * 0.25, 0.92, 1.4)
			# Wall-lovers make for the nearest wall, now and then looking for one.
			if _likes_walls[i] == 1 and off > 16.0:
				_timer[i] -= delta
				if _timer[i] <= 0.0 and _wall_rays > 0:
					_timer[i] = 1.0 + seed
					_look_for_wall(i, x, y, z, want_x, want_z)
				if _nx[i] != 0.0 or _nz[i] != 0.0:
					var long := sqrt(want_x * want_x + want_z * want_z) + 0.0001
					want_x = want_x / long - _nx[i] * 1.3
					want_z = want_z / long - _nz[i] * 1.3
		else:
			want_x = _nest.x - x
			want_z = _nest.z - z
			var off := want_x * want_x + want_z * want_z
			apart_kept = off > 1.5
			if off < 1.0:
				quick = 0.5
			_grown[i] = minf(_grown[i], off * 6.0 + 0.15)
			if off < 0.09:
				_state[i] = HIDDEN
				active -= 1
				for k in 16:
					_buffer[at + k] = 0.0
				continue
		var far := sqrt(want_x * want_x + want_z * want_z) + 0.0001
		want_x /= far
		want_z /= far
		# Not on top of one another.
		var cell_x := int((x - _corner.x) / CELL)
		var cell_z := int((z - _corner.y) / CELL)
		if cell_x > 0 and cell_z > 0 and cell_x < width - 1 and cell_z < width - 1:
			var index := cell_z * width + cell_x
			var here := _crowd[index]
			if here >= CROWD and apart_kept:
				var push := 0.25 * (here - CROWD + 1)
				want_x += (_crowd[index - 1] - _crowd[index + 1]) * 0.2 + cos(seed * 40.0 + i) * push
				want_z += (_crowd[index - width] - _crowd[index + width]) * 0.2 + sin(seed * 40.0 + i) * push
			var counted := _crowd_next[index]
			if counted < 250:
				_crowd_next[index] = counted + 1
				if counted == 0:
					_crowded_next.append(index)
		var weave := sin(_time * (5.0 + seed * 5.0) + seed * 50.0) * (0.4 if apart_kept else 0.0)
		var wish_x := want_x - want_z * weave
		var wish_z := want_z + want_x * weave
		var head_x := _hx[i]
		var head_z := _hz[i]
		if _detour[i] > 0.0:
			_detour[i] -= delta
			wish_x = head_x
			wish_z = head_z
		var turn := minf(delta * 10.0, 1.0)
		head_x += (wish_x - head_x) * turn
		head_z += (wish_z - head_z) * turn
		var length := sqrt(head_x * head_x + head_z * head_z)
		if length > 0.001:
			head_x /= length
			head_z /= length
		_hx[i] = head_x
		_hz[i] = head_z
		var pace := 0.0 if still else speed * _pace[i] * quick * (0.7 if mode == Mode.HOME else 1.0)
		if pace > 0.0:
			var step := pace * delta
			var next_x := x + head_x * (step + 0.05)
			var next_z := z + head_z * (step + 0.05)
			var ahead := _height(next_x, next_z, ground)
			if ahead >= BLOCKED or ahead - ground > climb or ground - ahead > drop:
				# A wall: up it (the climbers, after him), or along its foot.
				if hunting_now and ahead - ground > climb and (_likes_walls[i] == 1 or seed < climbers * 0.5) and _onto_wall(i, x, ground, z, head_x, head_z):
					_stride[i] += stride_rate * delta
					continue
				for attempt in 6:
					var turned: float = [PI * 0.5, 2.3, 3.0][attempt / 2] * (_side[i] if attempt % 2 == 0 else -_side[i])
					var try_x := head_x * cos(turned) - head_z * sin(turned)
					var try_z := head_x * sin(turned) + head_z * cos(turned)
					var there := _height(x + try_x * 0.3, z + try_z * 0.3, ground)
					if there < BLOCKED and there - ground <= climb and ground - there <= drop:
						_hx[i] = try_x
						_hz[i] = try_z
						_detour[i] = 0.2 + seed * 0.4
						if attempt % 2 == 1:
							_side[i] = -_side[i]
						break
			else:
				x += head_x * step
				z += head_z * step
				ground = ahead
				y = move_toward(y, ground, step * 2.0)
			_stride[i] += stride_rate * _pace[i] * quick * delta
		elif y > ground:
			y = maxf(y - delta * 3.0, ground)
		_x[i] = x
		_y[i] = y
		_z[i] = z
		_ground[i] = ground
		if _grown[i] < 1.0 and mode != Mode.HOME:
			_grown[i] = minf(_grown[i] + delta * 4.0, 1.0)
		_go[i] = move_toward(_go[i], 0.0 if still else 1.0, delta * 6.0)
		_splay[i] = move_toward(_splay[i], 0.0, delta * 5.0)
		# Onto him.
		if hunting_now:
			var to_x := him.x - x
			var to_z := him.z - z
			if to_x * to_x + to_z * to_z < 0.2 and absf(him.y - y) < 0.7:
				_latch(i, to_x, to_z)
				latched += 1
				continue
		_write(at, x, y, z, Vector3(head_x, 0.0, head_z), Vector3.UP, big, i)

	_drawn.multimesh.buffer = _buffer
	out = active
	on_him = latched
	if best < INF:
		_front = _front.lerp(best_at, minf(delta * 8.0, 1.0))
	elif active == 0:
		_front = _nest
	if _chatter and _chatter.playing:
		_chatter.global_position = _front + Vector3.UP * 0.3
		var loud := clampf(maxf(active, 6.0 if mode == Mode.WARN else 0.0) / 30.0, 0.0, 1.0)
		_chatter.volume_db = volume_db + linear_to_db(maxf(loud, 0.02))
	if hunting_now:
		if latched >= mini(catch_count, count):
			_meter += delta
			if _meter >= catch_time:
				_meter = 0.0
				overwhelmed.emit(target)
				shake_off()
				recall()
		else:
			_meter = maxf(_meter - delta * 0.5, 0.0)
		# Getting no nearer, with nobody on him: they give up.
		var gap := sqrt(best) if best < INF else 0.0
		_gap = gap
		if latched > 0 or out < count:
			_best_seen = gap
			_stuck_for = 0.0
		elif gap < _best_seen - 0.4:
			_best_seen = gap
			_stuck_for = 0.0
		else:
			_best_seen = maxf(_best_seen, gap - 2.0)
			_stuck_for += delta
			if _stuck_for > give_up_after:
				recall()


## Onto the wall in front of it, if there is one to be found (a ray across).
func _onto_wall(i: int, x: float, ground: float, z: float, head_x: float, head_z: float) -> bool:
	if _wall_rays <= 0:
		return false
	_wall_rays -= 1
	_query.from = Vector3(x, ground + 0.3, z)
	_query.to = Vector3(x + head_x * 0.8, ground + 0.3, z + head_z * 0.8)
	var hit := get_world_3d().direct_space_state.intersect_ray(_query)
	if hit.is_empty():
		return false
	var normal: Vector3 = hit["normal"]
	if absf(normal.y) > 0.4:
		return false
	normal.y = 0.0
	normal = normal.normalized()
	var point: Vector3 = hit["position"]
	_state[i] = WALL
	_nx[i] = normal.x
	_nz[i] = normal.z
	_x[i] = point.x + normal.x * 0.03
	_z[i] = point.z + normal.z * 0.03
	_y[i] = ground + 0.08
	_ground[i] = ground
	# (which way along it: the way it was going, more or less)
	var along_x := -normal.z
	var along_z := normal.x
	_a[i] = 1.0 if head_x * along_x + head_z * along_z >= 0.0 else -1.0
	_b[i] = minf(wall_climb, 0.9 + _seed[i] * wall_climb)
	_timer[i] = 1.4 + _seed[i] * 2.0
	return true


## Looks for a wall off to one side of where it is going, for a wall-lover to make for.
func _look_for_wall(i: int, x: float, y: float, z: float, want_x: float, want_z: float) -> void:
	_wall_rays -= 1
	var far := sqrt(want_x * want_x + want_z * want_z) + 0.0001
	var side_x := -want_z / far * _side[i]
	var side_z := want_x / far * _side[i]
	_query.from = Vector3(x, y + 0.4, z)
	_query.to = Vector3(x + side_x * 9.0, y + 0.4, z + side_z * 9.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(_query)
	if hit.is_empty():
		_nx[i] = 0.0
		_nz[i] = 0.0
		return
	var normal: Vector3 = hit["normal"]
	_nx[i] = normal.x
	_nz[i] = normal.z


## On a wall: up it slantwise to its height, along it after him, and off it at him.
func _wall_step(i: int, him: Vector3, hunting_now: bool, delta: float, big: float, at: int) -> void:
	var nx := _nx[i]
	var nz := _nz[i]
	var along_x := -nz
	var along_z := nx
	var x := _x[i]
	var y := _y[i]
	var z := _z[i]
	var ground := _ground[i]
	var up := 0.0
	var way := _a[i]
	if hunting_now:
		var d := (him.x - x) * along_x + (him.z - z) * along_z
		if absf(d) > 0.8:
			way = signf(d)
			_a[i] = way
		else:
			_jump_off(i, him)
			return
	else:
		_jump_off(i, him)
		return
	_timer[i] -= delta
	var height := y - ground
	if height < _b[i]:
		up = 1.0
	var pace := speed * _pace[i] * 0.85
	var dir := Vector3(along_x * way, up * 0.8, along_z * way).normalized()
	x += dir.x * pace * delta
	y += dir.y * pace * delta
	z += dir.z * pace * delta
	# (now and then it feels ahead for the wall: where it ends, it leaps off)
	if (i + Engine.get_physics_frames()) % 10 == 0 and _wall_rays > 0:
		_wall_rays -= 1
		var ahead := Vector3(x, y, z) + Vector3(along_x, 0.0, along_z) * way * 0.4
		_query.from = ahead + Vector3(nx, 0.0, nz) * 0.4
		_query.to = ahead - Vector3(nx, 0.0, nz) * 0.4
		if get_world_3d().direct_space_state.intersect_ray(_query).is_empty():
			_jump_off(i, him)
			return
	if _timer[i] <= 0.0:
		_jump_off(i, him)
		return
	_x[i] = x
	_y[i] = y
	_z[i] = z
	_stride[i] += minf(speed / (imp_size * 0.9), 7.0) * delta
	_go[i] = 1.0
	_splay[i] = move_toward(_splay[i], 1.0, delta * 6.0)
	_hx[i] = along_x * way
	_hz[i] = along_z * way
	# (its belly to the wall, head the way it goes)
	_write(at, x, y, z, dir, Vector3(nx, 0.0, nz), big, i)


## Leaps off the wall, out and at him.
func _jump_off(i: int, him: Vector3) -> void:
	_state[i] = FLUNG
	var out_x := _nx[i]
	var out_z := _nz[i]
	var to := Vector3.ZERO
	if him.is_finite():
		to = Vector3(him.x - _x[i], 0.0, him.z - _z[i]).normalized()
	_a[i] = out_x * 1.5 + to.x * 3.0
	_c[i] = out_z * 1.5 + to.z * 3.0
	_b[i] = 2.0
	_x[i] += out_x * 0.1
	_z[i] += out_z * 0.1
	_nx[i] = 0.0
	_nz[i] = 0.0
	_hx[i] = to.x if to != Vector3.ZERO else out_x
	_hz[i] = to.z if to != Vector3.ZERO else out_z


func _latch(i: int, to_x: float, to_z: float) -> void:
	_state[i] = ON_HIM
	_a[i] = atan2(-to_z, -to_x)
	_b[i] = 0.05
	_c[i] = randf_range(hold.x, hold.y)


## Off him: flung the way he was going, and out.
func _fling(i: int, going: Vector3) -> void:
	var way := _a[i]
	_state[i] = FLUNG
	_a[i] = going.x * 0.5 + cos(way) * 2.0
	_c[i] = going.z * 0.5 + sin(way) * 2.0
	_b[i] = 2.0 + going.y * 0.3
	_nx[i] = 0.0
	_nz[i] = 0.0


func _come_out(i: int) -> void:
	var way := _seed[i] * TAU + _time
	_state[i] = FLOOR
	_x[i] = _nest.x + cos(way) * 0.1
	_z[i] = _nest.z + sin(way) * 0.1
	_y[i] = _nest.y
	_hx[i] = cos(way)
	_hz[i] = sin(way)
	_ground[i] = NAN
	_grown[i] = 0.0
	_timer[i] = 0.0
	_detour[i] = 0.0
	_nx[i] = 0.0
	_nz[i] = 0.0
	out += 1


## Writes imp `i` into the MultiMesh: where it is, which way it heads, which way is up for it.
func _write(at: int, x: float, y: float, z: float, heading: Vector3, up: Vector3, big: float, i: int) -> void:
	var fwd := heading - up * heading.dot(up)
	if fwd.length_squared() < 0.0001:
		fwd = up.cross(Vector3.RIGHT) if absf(up.x) < 0.9 else up.cross(Vector3.FORWARD)
	fwd = fwd.normalized()
	var side := up.cross(fwd).normalized()
	# (columns: across, up, forward; scaled)
	_buffer[at] = side.x * big
	_buffer[at + 1] = up.x * big
	_buffer[at + 2] = fwd.x * big
	_buffer[at + 3] = x
	_buffer[at + 4] = side.y * big
	_buffer[at + 5] = up.y * big
	_buffer[at + 6] = fwd.y * big
	_buffer[at + 7] = y
	_buffer[at + 8] = side.z * big
	_buffer[at + 9] = up.z * big
	_buffer[at + 10] = fwd.z * big
	_buffer[at + 11] = z
	_buffer[at + 12] = _stride[i]
	_buffer[at + 13] = _go[i]
	_buffer[at + 14] = _splay[i]
	_buffer[at + 15] = _seed[i]


## Where an imp at a place makes for: him, if he is near; else the way to him (`steer`), asked
## once for each square of `STEER_CELL` and kept a while.
func _goal_from(x: float, y: float, z: float, him: Vector3) -> Vector3:
	if not steer.is_valid() or Vector2(him.x - x, him.z - z).length() < 7.0:
		return him
	var key := Vector2i(floori(x / STEER_CELL), floori(z / STEER_CELL))
	if _steer_cache.has(key):
		return _steer_cache[key]
	var made: Vector3 = steer.call(Vector3((key.x + 0.5) * STEER_CELL, y, (key.y + 0.5) * STEER_CELL))
	_steer_cache[key] = made
	return made


var _steer_age := 0.0


func _steer_cache_tick() -> void:
	_steer_age += get_physics_process_delta_time()
	if _steer_age > STEER_KEEP:
		_steer_age = 0.0
		_steer_cache.clear()


# How high the ground is at a place, for an imp at the height `from`: remembered, or looked for now.
func _height(x: float, z: float, from: float) -> float:
	var cell_x := int((x - _corner.x) / CELL)
	var cell_z := int((z - _corner.y) / CELL)
	if cell_x < 0 or cell_z < 0 or cell_x >= _width or cell_z >= _width:
		return BLOCKED
	var index := cell_z * _width + cell_x
	var known := _heights[index]
	if known == known:
		return known
	if _rays <= 0:
		return from
	_rays -= 1
	known = _probe(_corner.x + (cell_x + 0.5) * CELL, _corner.y + (cell_z + 0.5) * CELL, from)
	_heights[index] = known
	return known


func _probe(x: float, z: float, from: float) -> float:
	_query.from = Vector3(x, from + climb + 0.5, z)
	_query.to = Vector3(x, from - drop - 0.6, z)
	var found := get_world_3d().direct_space_state.intersect_ray(_query)
	if found.is_empty():
		return BLOCKED
	return found.position.y


# The crack: a ragged dark split in the ground, with cracks running out of it.
func _crack_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var rim: Array[Vector3] = []
	for k in 14:
		var turn := TAU * k / 14.0
		var far := (0.42 if k % 2 == 0 else 0.26) * rng.randf_range(0.8, 1.2)
		rim.append(Vector3(cos(turn) * far * 1.4, 0.0, sin(turn) * far * 0.7))
	for k in 14:
		tool.add_vertex(Vector3.ZERO)
		tool.add_vertex(rim[(k + 1) % 14])
		tool.add_vertex(rim[k])
	# Cracks running out.
	for c in 6:
		var turn := rng.randf() * TAU
		var at := Vector3(cos(turn), 0.0, sin(turn)) * 0.3
		var width := 0.05
		for s in 4:
			var bend := turn + rng.randf_range(-0.6, 0.6)
			var next := at + Vector3(cos(bend), 0.0, sin(bend)) * rng.randf_range(0.15, 0.3)
			var across := Vector3(-sin(bend), 0.0, cos(bend)) * width
			tool.add_vertex(at - across)
			tool.add_vertex(next)
			tool.add_vertex(at + across)
			at = next
			width *= 0.6
	var made := tool.commit()
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.015, 0.01, 0.01)
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	made.surface_set_material(0, dark)
	return made


## Their chatter, made once and shared: a crowd of tiny voices, teeth clicking,
## squeaks and sniggers over one another, in a loop.
static func chatter_sound() -> AudioStreamWAV:
	if _chatter_stream:
		return _chatter_stream
	var rate := 22050
	var samples := PackedFloat32Array()
	samples.resize(rate * 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var size := samples.size()
	# Clicks of teeth.
	for n in 900:
		var start := rng.randi_range(0, size - 1)
		var long := rng.randi_range(25, 90)
		var loud := rng.randf_range(0.1, 0.45)
		var last := 0.0
		for k in long:
			var noise := rng.randf_range(-1.0, 1.0)
			samples[(start + k) % size] += (noise - last) * loud * (1.0 - float(k) / long)
			last = noise
	# Squeaks and sniggers: short falling chirps, some in runs.
	for n in 160:
		var start := rng.randi_range(0, size - 1)
		var runs := 1 if rng.randf() < 0.6 else rng.randi_range(3, 5)
		var pitch := rng.randf_range(1400.0, 3200.0)
		for r in runs:
			var long := rng.randi_range(500, 1400)
			var phase := 0.0
			for k in long:
				var s := float(k) / long
				phase += pitch * (1.2 - 0.45 * s) / rate
				var buzz := fposmod(phase, 1.0)
				var voice_now := (pow(1.0 - buzz, 4.0) - 0.2) * sin(PI * s) * 0.16
				samples[(start + r * int(rate * 0.11) + k) % size] += voice_now
	var loudest := 0.001
	for v in samples:
		loudest = maxf(loudest, absf(v))
	var data := PackedByteArray()
	data.resize(size * 2)
	for k in size:
		data.encode_s16(k * 2, int(clampf(samples[k] / loudest, -1.0, 1.0) * 26000.0))
	_chatter_stream = AudioStreamWAV.new()
	_chatter_stream.format = AudioStreamWAV.FORMAT_16_BITS
	_chatter_stream.mix_rate = rate
	_chatter_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_chatter_stream.loop_end = size
	_chatter_stream.data = data
	return _chatter_stream

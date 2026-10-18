class_name RatSwarm
extends Node3D
## A swarm of rats: a few hundred brown rats pouring out of drains at the foot
## of a wall (or a hole in the floor) like a river, flooding along the ground
## and over each other, streaming up anything low and up the feet of walls, and
## going for a target point; those that reach it climb whoever stands there.
## How they look, sound and move, and nothing of what they mean in a game: the
## game says where they are to go (`target`), lets them out and calls them
## home, and decides what being overrun does (`overwhelmed`). Made from
## BeetleSwarm (creatures/beetle_swarm/), with rats.
##
##     var swarm := RatSwarm.new()
##     swarm.count = 280
##     add_child(swarm)
##     swarm.add_drain(foot_of_the_wall, out_of_the_wall)   # (or Vector3.ZERO for a hole in the floor)
##     swarm.release()                                      # a squealing roar from the drains, then out they pour
##     # every frame, while they are out:
##     swarm.target = player.global_position
##     swarm.target_moving = player.velocity
##     swarm.target_grounded = player.is_on_floor()
##     swarm.overwhelmed.connect(...)                       # enough on them for long enough
##     swarm.recall()                                       # they stream home and go back in
##
## - THE WARNING. `release()` and first a squealing roar comes out of the
##   drains (RatVoice.roar) for `warn_time`; then they pour out (`pour_rate`),
##   fanning out from the wall, and the roar goes with the front of them.
## - THE RIVER. They run at `speed` (the front a little faster, those behind
##   hurrying to keep up, so they come as a flood, not a string), spreading
##   across a hall (`flood_width`) far from the target and weaving as they go.
##   Where they crowd they climb over each other, up to `pile` deep, a heaving
##   back of rats. They go up any face no higher than `climb` (low walls,
##   steps) and down drops of up to `drop`; a face higher than that is a wall:
##   some go along its foot and some (`wall_share`) run up it, as far as
##   `wall_climb`, and come down again.
## - UP PEOPLE. Those that reach the target run up the legs and round whoever
##   stands there, to the shoulders, at most `most_on` at once; the rest seethe
##   round their feet (and up any wall in the way). Going faster than
##   `shake_speed`, or jumping, shakes them off a few at a time; thrown off, they
##   tumble and right themselves. `catch_count` on at once for `catch_time` and
##   `overwhelmed` is emitted.
## - `stalled` is how long they have been getting no nearer the target, for
##   the game to give up by. `guide` and `forbid` are as BeetleSwarm's: where a
##   rat at a place should make for next on its way to a goal (round walls), and
##   ground they will not go onto.
##
## The cost is flat. All of them are one MultiMesh (the low rat, RatLook), moved
## in one loop and written to it in one piece, posed in the shader. The ground
## is found with a ray straight down once for each square of a grid (`CELL`
## across) round the first drain, as a rat first comes to it, and remembered.
## Asleep in their drains, they cost nothing. Seeded by `swarm_seed`, two
## machines that make the same swarm get the same rats.

## Enough of them have been on the target for long enough.
signal overwhelmed
signal came_out
signal went_home

enum Mode { DORMANT, WARN, OUT, HOME }

## How many rats.
@export_range(1, 800) var count := 240
## How big a rat is (1: a brown rat 25 cm nose to rump), and how much bigger or smaller one may be (a share of that).
@export var rat_size := 1.0
@export var size_spread := 0.3
## How fast they run, metres a second.
@export var speed := 5.0
## How far from the first drain they can go (the grid of the ground reaches this far).
@export var reach := 50.0
## How many come out of the drains a second, and how long the roar warns before they do.
@export var pour_rate := 170.0
@export var warn_time := 1.1
## How long they take going home before any still on the way slip into the nearest crack instead (s).
@export var home_time := 12.0
## The highest face they go up, and the furthest they drop (m).
@export var climb := 0.95
@export var drop := 2.5
## How far up a wall's face they run (m), and the share of those that meet a wall that do.
@export var wall_climb := 1.6
@export_range(0.0, 1.0) var wall_share := 0.5
## How wide they spread going along a hall far from the target (m).
@export var flood_width := 5.0
## How deep they pile up where they crowd (rats on rats).
@export_range(0, 4) var pile := 3
## How many on the target overwhelm it, and how long they need.
@export var catch_count := 14
@export var catch_time := 0.9
## The most that climb someone at once (the rest seethe round their feet).
@export var most_on := 40
## How fast the target must go to shake them off (m/s); jumping shakes them off too.
@export var shake_speed := 5.0
## The physics layers that are ground and walls to them.
@export_flags_3d_physics var ground_mask := 1
@export var swarm_seed := 0
## The dark mouths of the drains.
@export var show_drains := true
## Rats away from where they are going are worked out in full one frame in this many (1: every frame).
@export_range(1, 6) var stagger := 3
## Their roar (RatVoice.roar).
@export var voice := true
@export var volume_db := 2.0

## Where they are going: a point on the ground (the feet of whoever they are
## after), or `Vector3.INF` for nowhere (they mill where they are).
var target := Vector3.INF
## How the target is moving, and whether it is on the ground (to shake them off).
var target_moving := Vector3.ZERO
var target_grounded := true
var guide := Callable()
var forbid := Callable()
var mode := Mode.DORMANT
## How many are out of the drains, and how many of those are on the target.
var out := 0
var on_target := 0
## The rat nearest the target (or the first drain), and how far it is from it.
var front := Vector3.ZERO
var gap := INF
## How long they have got no nearer the target, seconds.
var stalled := 0.0

const HIDDEN := 0
const GROUND := 1
const WALL := 2
const ON := 3
const FLUNG := 4

## The side of a square of the ground they remember, metres.
const CELL := 0.3
## A square that cannot be entered at all (no ground; forbidden).
const BLOCKED := 1000000.0
## How many squares of ground are looked at afresh in one frame, at most.
const RAYS := 32
## How many rats to a square before they push apart (and climb over each other).
const CROWD := 2
## How many frames go by between one rat asking `guide` the way and the next time.
const GUIDE_EVERY := 8
## How high a rat on another rat stands, metres (for a rat of size 1).
const LAYER := 0.05

var _drains: Array[Vector3] = []
var _outs: Array[Vector3] = []
var _drain_meshes: Array[MeshInstance3D] = []
var _time := 0.0
var _warn := 0.0
var _meter := 0.0
var _pour := 0.0
var _next_out := 0
var _best_seen := INF
var _rays := 0
var _guided := 0
var _tick := 0
var _rng := RandomNumberGenerator.new()
var _roar: AudioStreamPlayer3D
var _loud := 0.0
var _homing := 0.0

# Each rat.
var _state := PackedByteArray()
var _x := PackedFloat32Array()
var _y := PackedFloat32Array()
var _z := PackedFloat32Array()
var _hx := PackedFloat32Array()
var _hz := PackedFloat32Array()
var _ground := PackedFloat32Array()
var _pitch := PackedFloat32Array()
var _seed := PackedFloat32Array()
var _spread := PackedFloat32Array()
var _pace := PackedFloat32Array()
var _stride := PackedFloat32Array()
var _grown := PackedFloat32Array()
var _detour := PackedFloat32Array()
var _side_of := PackedFloat32Array()
var _v := PackedFloat32Array()
var _sv := PackedFloat32Array()
var _size := PackedFloat32Array()
var _lift := PackedFloat32Array()
var _bend := PackedFloat32Array()
var _gx := PackedFloat32Array()
var _gz := PackedFloat32Array()
var _direct := PackedByteArray()
# (on the target: how far round and how far up; on a wall: how far up, which way
# along it, and its way out; thrown off: how fast it is going)
var _a := PackedFloat32Array()
var _b := PackedFloat32Array()
var _c := PackedFloat32Array()
var _nx := PackedFloat32Array()
var _nz := PackedFloat32Array()
var _wait := PackedFloat32Array()

# The ground round the first drain, square by square (NAN: not looked at yet), and how many rats stand in each.
var _nest := Vector3.ZERO
var _width := 0
var _corner := Vector2.ZERO
var _heights := PackedFloat32Array()
var _crowd := PackedByteArray()
var _crowded := PackedInt32Array()
var _crowd_next := PackedByteArray()
var _crowded_next := PackedInt32Array()

var _drawn: MultiMeshInstance3D
var _buffer := PackedFloat32Array()
var _query: PhysicsRayQueryParameters3D


func _ready() -> void:
	_rng.seed = swarm_seed
	for list: PackedFloat32Array in [_x, _y, _z, _hx, _hz, _ground, _pitch, _seed, _spread, _pace, _stride, _grown, _detour, _side_of, _size, _lift, _bend, _gx, _gz, _a, _b, _c, _nx, _nz, _wait, _v, _sv]:
		list.resize(count)
	_state.resize(count)
	_direct.resize(count)
	for i in count:
		_seed[i] = _rng.randf()
		_spread[i] = _rng.randf()
		_pace[i] = _rng.randf_range(0.88, 1.12)
		_side_of[i] = 1.0 if _rng.randf() < 0.5 else -1.0
		_size[i] = rat_size * (1.0 + (_rng.randf() - 0.6) * size_spread)
		_hx[i] = 0.0
		_hz[i] = 1.0
	_query = PhysicsRayQueryParameters3D.new()
	_query.collision_mask = ground_mask
	_query.hit_from_inside = true

	_drawn = MultiMeshInstance3D.new()
	_drawn.name = "Rats"
	_drawn.top_level = true
	_drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = RatLook.mesh(true)
	many.instance_count = count
	_drawn.multimesh = many
	add_child(_drawn)
	_drawn.global_transform = Transform3D.IDENTITY
	_buffer.resize(count * 16)
	many.buffer = _buffer
	_drawn.visible = false
	if _width > 0:
		_fit_bounds()
	for k in _drains.size():
		_open_mouth(k)
	if _drains.is_empty():
		add_drain(global_position, Vector3.ZERO)
	if voice:
		_roar = AudioStreamPlayer3D.new()
		_roar.name = "Roar"
		_roar.top_level = true
		_roar.unit_size = 9.0
		_roar.max_distance = 70.0
		_roar.volume_db = volume_db
		add_child(_roar)


## A drain they come out of and go back into: `at` on the ground at the foot of
## a wall, and `out_of` the way out of the wall (level), or Vector3.ZERO for a
## hole in the floor. The first one is where the grid of the ground is centred.
func add_drain(at: Vector3, out_of := Vector3.ZERO) -> void:
	out_of.y = 0.0
	out_of = out_of.normalized() if out_of.length() > 0.01 else Vector3.ZERO
	_drains.append(at)
	_outs.append(out_of)
	if _drains.size() == 1:
		_place_grid(at)
		front = at
	if is_inside_tree():
		_open_mouth(_drains.size() - 1)


func _open_mouth(index: int) -> void:
	if not show_drains:
		return
	var at := _drains[index]
	var out_of := _outs[index]
	var mouth := MeshInstance3D.new()
	mouth.name = "Drain%d" % (index + 1)
	mouth.mesh = RatSwarm.drain_mesh(out_of != Vector3.ZERO, swarm_seed + index + 1)
	mouth.top_level = true
	mouth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mouth)
	var facing := out_of if out_of != Vector3.ZERO else Vector3.BACK
	mouth.global_transform = Transform3D(Basis.looking_at(-facing, Vector3.UP), at)
	_drain_meshes.append(mouth)


## The drains, and the way out of each.
func drains() -> Array[Vector3]:
	return _drains


func drain_out(index: int) -> Vector3:
	return _outs[index]


func _place_grid(at: Vector3) -> void:
	_nest = at
	var across := reach + 3.0
	_width = clampi(ceili(across * 2.0 / CELL) + 1, 8, 400)
	_corner = Vector2(_nest.x, _nest.z) - Vector2.ONE * _width * CELL * 0.5
	_heights.resize(_width * _width)
	_heights.fill(NAN)
	_crowd.resize(_width * _width)
	_crowd.fill(0)
	_crowd_next.resize(_width * _width)
	_crowd_next.fill(0)
	_crowded.clear()
	_crowded_next.clear()
	if _drawn:
		_fit_bounds()


func _fit_bounds() -> void:
	var across := reach + 3.0
	_drawn.custom_aabb = AABB(_nest - Vector3(across, 6.0, across), Vector3(across, 8.0, across) * 2.0)


## Lets them out: the roar first, from the drains, then they pour (those on their way home turn round at once).
func release() -> void:
	if mode == Mode.OUT or mode == Mode.WARN:
		return
	var was_home := mode == Mode.HOME
	mode = Mode.WARN if not was_home else Mode.OUT
	_warn = warn_time
	_meter = 0.0
	_best_seen = INF
	stalled = 0.0
	if _roar:
		_roar.stream = RatVoice.roar()
		_roar.global_position = _drains[0] + Vector3.UP * 0.3
		if not _roar.playing:
			_roar.play(_rng.randf() * 2.0)
	if was_home:
		came_out.emit()


## Whether they are roaring in the drains, about to pour out.
func warning() -> bool:
	return mode == Mode.WARN


## Calls them home: they let go of whoever they are on, run back to their drains and go in.
func recall() -> void:
	if mode == Mode.WARN:
		mode = Mode.DORMANT
		_stop_roar()
		return
	if mode != Mode.OUT:
		return
	mode = Mode.HOME
	_homing = 0.0
	shake_off()


## They are after someone else now: how long they have got no nearer starts again.
func new_target() -> void:
	_best_seen = INF
	stalled = 0.0
	_meter = 0.0


## Everyone on the target is thrown off.
func shake_off() -> void:
	for i in count:
		if _state[i] == ON:
			_let_go(i, target_moving)
	_meter = 0.0


## Puts them all back in their drains at once.
func reset() -> void:
	mode = Mode.DORMANT
	_meter = 0.0
	stalled = 0.0
	_state.fill(HIDDEN)
	_buffer.fill(0.0)
	if _drawn:
		_drawn.multimesh.buffer = _buffer
		_drawn.visible = false
	out = 0
	on_target = 0
	gap = INF
	front = _nest
	_stop_roar()


func _stop_roar() -> void:
	_loud = 0.0
	if _roar:
		_roar.stop()


## Where rat `i` is (for tests and pictures), and what it is doing (HIDDEN, GROUND, WALL, ON or FLUNG).
func rat_position(i: int) -> Vector3:
	return Vector3(_x[i], _y[i] + _lift[i], _z[i])


func rat_state(i: int) -> int:
	return _state[i]


## How many rats are in a state.
func counted(state: int) -> int:
	return _state.count(state)


## How high the highest rat on the ground stands on the others (m).
func highest_pile() -> float:
	var top := 0.0
	for i in count:
		if _state[i] == GROUND:
			top = maxf(top, _lift[i])
	return top


func _physics_process(delta: float) -> void:
	if mode == Mode.DORMANT:
		return
	_time += delta
	if mode == Mode.WARN:
		_warn -= delta
		_loud = minf(_loud + delta * 3.0, 1.0)
		_voice(delta)
		if _warn <= 0.0:
			mode = Mode.OUT
			_drawn.visible = true
			came_out.emit()
		return
	var have_target := target.is_finite()
	var him := target if have_target else Vector3(INF, INF, INF)
	var shaking := have_target and (not target_grounded or Vector2(target_moving.x, target_moving.z).length() > shake_speed)

	if mode == Mode.HOME and out == 0:
		mode = Mode.DORMANT
		_drawn.visible = false
		_stop_roar()
		went_home.emit()
		return

	# Out of the drains, so many a second.
	if mode == Mode.OUT and out < count:
		_pour += pour_rate * delta
		while _pour >= 1.0 and out < count:
			_pour -= 1.0
			for tries in count:
				_next_out = (_next_out + 1) % count
				if _state[_next_out] == HIDDEN:
					break
			_come_out(_next_out)
	else:
		_pour = 0.0

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

	var hunting := mode == Mode.OUT and have_target
	var homing := mode == Mode.HOME
	if homing:
		_homing += delta
	var width := _width
	var inverse := 1.0 / CELL
	var corner_x := _corner.x
	var corner_z := _corner.y
	var best := INF
	var best_at := _nest
	var latched := 0
	var active := 0
	var has_guide := guide.is_valid()
	var drains_count := _drains.size()
	var layer := LAYER * rat_size

	for i in count:
		var state := _state[i]
		if state == HIDDEN:
			continue
		active += 1
		var x := _x[i]
		var y := _y[i]
		var z := _z[i]
		var seed := _seed[i]
		var at := i * 16
		var big := _size[i]

		if state == ON:
			# Up their legs and round them, heads up, climbing.
			latched += 1
			var up := _b[i]
			var top := 0.2 + seed * 1.2
			up = minf(up + delta * 1.3, top)
			_b[i] = up
			var round_them := _a[i] + delta * (seed - 0.5) * 3.0
			_a[i] = round_them
			var wide := lerpf(0.16, 0.24, smoothstep(0.6, 0.9, up)) + 0.03 * sin(up * 4.0 + seed * 9.0)
			if shaking:
				_wait[i] -= delta
			if _wait[i] <= 0.0 or not hunting:
				_let_go(i, target_moving)
				continue
			var cos_a := cos(round_them)
			var sin_a := sin(round_them)
			_stride[i] += delta * 4.5
			var place := Vector3(him.x + cos_a * wide, him.y + up, him.z + sin_a * wide)
			# (head up and a little round, its back out)
			var climbing := Vector3(-sin_a * 0.35 * _side_of[i], 1.0, cos_a * 0.35 * _side_of[i]).normalized()
			_write_basis(at, place, climbing, Vector3(cos_a, 0.0, sin_a), big, i, 0.8, sin(_time * 3.0 + seed * 20.0) * 0.5)
			_x[i] = place.x
			_y[i] = place.y
			_z[i] = place.z
			_lift[i] = 0.0
			continue

		if state == FLUNG:
			# Thrown off: it falls, tumbling, and lies a moment before it is on its feet.
			_c[i] -= 20.0 * delta
			x += _a[i] * delta
			y += _c[i] * delta
			z += _b[i] * delta
			var under := _height(x, z, y)
			if under >= BLOCKED:
				under = _ground[i] if _ground[i] == _ground[i] else y
			if y <= under:
				y = under
				_state[i] = GROUND
				_ground[i] = under
				_wait[i] = 0.2 + seed * 0.4
			_x[i] = x
			_y[i] = y
			_z[i] = z
			_pitch[i] += delta * 11.0
			_write(at, x, y + big * 0.04, z, _hx[i], _hz[i], _pitch[i], big, i, 1.0, 0.0)
			continue

		# Most frames, one well away from where it is going only carries on as it
		# was: the whole of the above and below is done for it one frame in
		# `stagger`. Within 2.5 m of the target or home it is done every frame.
		if state == GROUND and stagger > 1 and (i + _tick) % stagger != 0 and _wait[i] <= 0.0 and _detour[i] <= 0.0:
			var aim := him if hunting else (_drains[i % drains_count] if homing else Vector3(x, y, z))
			var away_x := aim.x - x
			var away_z := aim.z - z
			var away := away_x * away_x + away_z * away_z
			if away > 6.25 or not (hunting or homing):
				if hunting:
					var apart := away + (him.y - y) * (him.y - y)
					if apart < best:
						best = apart
						best_at = Vector3(x, y, z)
				var going := _v[i]
				if going > 0.0:
					var on_x := x + _hx[i] * going * delta
					var on_z := z + _hz[i] * going * delta
					var to_cell_x := int((on_x - corner_x) * inverse)
					var to_cell_z := int((on_z - corner_z) * inverse)
					if to_cell_x >= 0 and to_cell_z >= 0 and to_cell_x < width and to_cell_z < width:
						var known := _heights[to_cell_z * width + to_cell_x]
						if known != known or (known < BLOCKED and absf(known - _ground[i]) <= 0.08):
							x = on_x
							z = on_z
							_x[i] = x
							_z[i] = z
					_stride[i] += _sv[i] * delta
				var here_x := int((x - corner_x) * inverse)
				var here_z := int((z - corner_z) * inverse)
				if here_x >= 0 and here_z >= 0 and here_x < width and here_z < width:
					var spot := here_z * width + here_x
					var counted_there := _crowd_next[spot]
					if counted_there < 250:
						_crowd_next[spot] = counted_there + 1
						if counted_there == 0:
							_crowded_next.append(spot)
				_buffer[at + 3] = x
				_buffer[at + 11] = z
				_buffer[at + 12] = fposmod(_stride[i], 8.0)
				continue
		# Where it wants to go: to the target (by the way `guide` gives), or home.
		var goal_x := x
		var goal_z := z
		var goal_y := y
		if hunting:
			goal_x = him.x
			goal_z = him.z
			goal_y = him.y
		elif homing:
			var home := _drains[i % drains_count]
			goal_x = home.x
			goal_z = home.z
			goal_y = home.y
		var to_x := goal_x - x
		var to_z := goal_z - z
		var off := to_x * to_x + to_z * to_z
		var want_x := 0.0
		var want_z := 0.0
		var quick := 1.0
		var still := false
		var apart_kept := true
		if hunting or homing:
			if has_guide and (i + _guided) % GUIDE_EVERY == 0:
				var next: Vector3 = guide.call(Vector3(x, y, z), Vector3(goal_x, goal_y, goal_z))
				_gx[i] = next.x
				_gz[i] = next.z
				_direct[i] = 1 if Vector2(next.x - goal_x, next.z - goal_z).length_squared() < 0.01 else 0
			var aim_x := goal_x
			var aim_z := goal_z
			if has_guide and _direct[i] == 0 and off > 4.0:
				aim_x = _gx[i]
				aim_z = _gz[i]
			var far := sqrt(off)
			if hunting:
				var apart := off + (him.y - y) * (him.y - y)
				if apart < best:
					best = apart
					best_at = Vector3(x, y, z)
				apart_kept = off > 0.6
				if far > 3.0:
					# (along a hall, far from it, they spread out across it)
					var aim_dx := aim_x - x
					var aim_dz := aim_z - z
					var aim_far := sqrt(aim_dx * aim_dx + aim_dz * aim_dz) + 0.001
					var spread := (_spread[i] - 0.5) * minf(flood_width, far * 0.7)
					aim_x += -aim_dz / aim_far * spread
					aim_z += aim_dx / aim_far * spread
				else:
					# (at their feet: the most there is room for climb them, and the rest
					# seethe round and round them a metre or so out, and up any wall in the way)
					var ring := 0.12 if on_target < most_on * 0.7 else 0.4 + _spread[i] * 1.0
					var round_about := seed * TAU + _time * (0.6 + seed * 0.5) * _side_of[i]
					aim_x += cos(round_about) * ring + (seed - 0.5) * 0.3
					aim_z += sin(round_about) * ring + (_pace[i] - 1.0) * 0.6
				# (those behind hurry and those in front do not run away from the rest: a flood, not a string)
				quick = clampf(1.0 + (far - gap - 0.8) * 0.12, 0.94, 1.3)
			else:
				apart_kept = off > 1.5
				if off < 1.0:
					quick = 0.5
				_grown[i] = minf(_grown[i], off * 6.0 + 0.25)
				if _homing > home_time:
					# (too long on the way: it slips into a crack where it is)
					_grown[i] = minf(_grown[i], 1.0 - (_homing - home_time) * 1.5 - _seed[i] * 0.3)
					if _grown[i] <= 0.05:
						off = 0.0
				if off < 0.06:
					_state[i] = HIDDEN
					for k in 16:
						_buffer[at + k] = 0.0
					continue
				if off < 1.0:
					# (at the mouth of the drain: straight in, whatever the ground says at the foot of the wall)
					var into := sqrt(off) + 0.0001
					var slip := minf(speed * 0.6 * delta, into)
					x += to_x / into * slip
					z += to_z / into * slip
					y = lerpf(y, goal_y, minf(delta * 6.0, 1.0))
					_hx[i] = to_x / into
					_hz[i] = to_z / into
					_x[i] = x
					_y[i] = y
					_z[i] = z
					_lift[i] = 0.0
					_stride[i] += RatLook.stride_rate(speed * 0.6, big) * delta
					_write(at, x, y, z, _hx[i], _hz[i], 0.0, big * _grown[i], i, 0.5, 0.0)
					continue
			want_x = aim_x - x
			want_z = aim_z - z
		else:
			# (nowhere to go: they mill about where they are, now and then one rearing to sniff)
			want_x = cos(seed * 40.0 + _time * 0.7)
			want_z = sin(seed * 40.0 + _time * 0.7)
			quick = 0.3
			still = fmod(_time * (0.3 + seed) + seed * 7.0, 2.0) > 1.2
		if _wait[i] > 0.0:
			# (dazed)
			_wait[i] -= delta
			still = true
		var length := sqrt(want_x * want_x + want_z * want_z) + 0.0001
		want_x /= length
		want_z /= length

		if state == WALL:
			_on_wall(i, delta, want_x, want_z, him, hunting, homing, quick)
			if _state[i] == ON:
				latched += 1
			continue

		# Not on top of one another (unless crowded): away from the fuller squares, and up onto the others.
		var ground := _ground[i]
		if ground != ground:
			ground = _height(x, z, y)
			if ground >= BLOCKED:
				ground = y
		var cell_x := int((x - corner_x) * inverse)
		var cell_z := int((z - corner_z) * inverse)
		var lift_to := 0.0
		if cell_x > 0 and cell_z > 0 and cell_x < width - 1 and cell_z < width - 1:
			var index := cell_z * width + cell_x
			var here := _crowd[index]
			if here >= CROWD and apart_kept:
				var push := 0.22 * (here - CROWD + 1)
				want_x += (_crowd[index - 1] - _crowd[index + 1]) * 0.2 + cos(seed * 40.0 + i) * push
				want_z += (_crowd[index - width] - _crowd[index + width]) * 0.2 + sin(seed * 40.0 + i) * push
			if here > CROWD and pile > 0:
				# (crowded, the later ones go up over the earlier: a heaving back of them)
				lift_to = minf(float(here - CROWD) * (0.4 + _spread[i] * 0.6), float(pile)) * layer
			var counted_here := _crowd_next[index]
			if counted_here < 250:
				_crowd_next[index] = counted_here + 1
				if counted_here == 0:
					_crowded_next.append(index)

		# A weave in its way of going, so that they scurry.
		var weave := sin(_time * (4.0 + seed * 5.0) + seed * 50.0) * (0.3 if apart_kept else 0.0)
		var wish_x := want_x - want_z * weave
		var wish_z := want_z + want_x * weave
		var head_x := _hx[i]
		var head_z := _hz[i]
		if _detour[i] > 0.0:
			_detour[i] -= delta
			wish_x = head_x
			wish_z = head_z
		var turn := minf(delta * 10.0, 1.0)
		var new_x := head_x + (wish_x - head_x) * turn
		var new_z := head_z + (wish_z - head_z) * turn
		var head_length := sqrt(new_x * new_x + new_z * new_z)
		if head_length > 0.001:
			new_x /= head_length
			new_z /= head_length
		else:
			new_x = wish_x
			new_z = wish_z
		# (its back bends the way it turns)
		var turning := (head_x * new_z - head_z * new_x) / maxf(delta, 0.001)
		_bend[i] = lerpf(_bend[i], clampf(-turning * 0.25, -0.9, 0.9), minf(delta * 8.0, 1.0))
		head_x = new_x
		head_z = new_z
		_hx[i] = head_x
		_hz[i] = head_z

		var pace := 0.0 if still else speed * _pace[i] * quick
		_v[i] = 0.0
		var tip := 0.0
		if pace > 0.0:
			var step := pace * delta
			var next_x := x + head_x * (step + big * 0.12)
			var next_z := z + head_z * (step + big * 0.12)
			var ahead := _height(next_x, next_z, ground)
			if ahead < BLOCKED and ahead - ground > climb and wall_climb > 0.0 and (seed < wall_share or (hunting and him.y > ground + 0.6)):
				# A wall: up it.
				_onto_wall(i, x, z, ground, head_x, head_z)
				_x[i] = x
				_y[i] = y
				_z[i] = z
				_ground[i] = ground
				continue
			if ahead >= BLOCKED or ahead - ground > climb or ground - ahead > drop:
				# A wall, or the edge of what they may go on: along it, one way or the other.
				for attempt in 6:
					var turned: float = [PI * 0.5, 2.3, 3.0][attempt / 2] * (_side_of[i] if attempt % 2 == 0 else -_side_of[i])
					var try_x := head_x * cos(turned) - head_z * sin(turned)
					var try_z := head_x * sin(turned) + head_z * cos(turned)
					var there := _height(x + try_x * 0.35, z + try_z * 0.35, ground)
					if there < BLOCKED and there - ground <= climb and ground - there <= drop:
						_hx[i] = try_x
						_hz[i] = try_z
						_detour[i] = 0.2 + seed * 0.35
						if attempt % 2 == 1:
							_side_of[i] = -_side_of[i]
						break
			elif ahead > y + 0.06:
				# Up the face of it (a low wall, a step): they stream up it.
				y = minf(y + step * 0.9, ahead)
				tip = -1.1
			else:
				x += head_x * step
				_v[i] = pace
				z += head_z * step
				ground = ahead
				if y > ground + 0.06:
					# (and down the other side)
					y = maxf(y - step * 1.2, ground)
					tip = 0.9
				else:
					tip = clampf((y - ground) * 8.0, -0.6, 0.6)
					y = move_toward(y, ground, step)
			# (RatLook.stride_rate, written out: this is done for every rat)
			_sv[i] = pace / (RatLook.LENGTH * big * (0.75 + 0.85 * minf(pace / 3.0, 1.0))) * _pace[i]
			_stride[i] += _sv[i] * delta
		elif y > ground:
			y = maxf(y - delta * 3.0, ground)
		_x[i] = x
		_y[i] = y
		_z[i] = z
		_ground[i] = ground
		# (climbing up over the others, it tips up; coming down, forward)
		var lift := _lift[i]
		var lifting := (lift_to - lift) * minf(delta * 5.0, 1.0)
		lift += lifting
		_lift[i] = lift
		tip += clampf(-lifting / maxf(delta, 0.001) * 1.5, -0.5, 0.5)
		var pitch := _pitch[i]
		pitch += (tip - pitch) * minf(delta * 12.0, 1.0)
		_pitch[i] = pitch
		if _grown[i] < 1.0 and not homing:
			_grown[i] = minf(_grown[i] + delta * 4.0, 1.0)

		# Onto them, if they are there to be got onto.
		if hunting and on_target < most_on:
			var near_x := him.x - x
			var near_z := him.z - z
			if near_x * near_x + near_z * near_z < 0.16 and absf(him.y - y - lift) < 0.4:
				_onto_target(i, near_x, near_z)
				latched += 1
				continue

		_write(at, x, y + lift, z, head_x, head_z, pitch, big * _grown[i], i, pace / maxf(speed * 1.3, 0.01), _bend[i])

	_drawn.multimesh.buffer = _buffer
	_guided = (_guided + 1) % GUIDE_EVERY
	_tick += 1
	out = active
	on_target = latched

	# The front of them.
	if best < INF:
		front = best_at
		gap = sqrt(best)
	else:
		gap = INF
		if active == 0:
			front = _nest

	if hunting:
		# Enough of them on the target for long enough.
		var needed := mini(catch_count, maxi(count / 3, 1))
		if latched >= needed:
			_meter += delta
			if _meter >= catch_time:
				_meter = 0.0
				overwhelmed.emit()
		else:
			_meter = maxf(_meter - delta * 0.5, 0.0)
		# Getting no nearer, with nothing to show for it.
		if latched > 0 or out < count:
			_best_seen = gap
			stalled = 0.0
		elif gap < _best_seen - 0.3:
			_best_seen = gap
			stalled = 0.0
		else:
			_best_seen = maxf(_best_seen, gap - 2.0)
			stalled += delta
	else:
		stalled = 0.0
	# The roar goes with the front of them, as loud as how many are out.
	_loud = move_toward(_loud, clampf(float(active) / maxf(count * 0.4, 1.0), 0.0, 1.0) if not homing else clampf(float(active) / count, 0.0, 0.6), delta * 1.5)
	_voice(delta)


func _voice(delta: float) -> void:
	if _roar == null:
		return
	if _loud <= 0.01:
		if _roar.playing:
			_roar.stop()
		return
	if not _roar.playing:
		_roar.stream = RatVoice.roar()
		_roar.play(_rng.randf() * 2.0)
	var where := front if mode != Mode.WARN and out > 0 else _drains[0] + Vector3.UP * 0.3
	_roar.global_position = _roar.global_position.lerp(where, minf(delta * 6.0, 1.0))
	_roar.volume_db = volume_db + linear_to_db(maxf(_loud, 0.02))


# --- On a wall ----------------------------------------------------------------

# Rat `i`, at the foot of a face too high to go up, heading into it: onto it.
func _onto_wall(i: int, x: float, z: float, ground: float, head_x: float, head_z: float) -> void:
	var out_x := 0.0
	var out_z := 0.0
	for k in 4:
		var dx := [1.0, -1.0, 0.0, 0.0][k] as float
		var dz := [0.0, 0.0, 1.0, -1.0][k] as float
		var there := _height(x + dx * CELL, z + dz * CELL, ground)
		if there < BLOCKED and there - ground > climb:
			out_x -= dx
			out_z -= dz
	var length := sqrt(out_x * out_x + out_z * out_z)
	if length < 0.5:
		out_x = -head_x
		out_z = -head_z
		length = 1.0
	out_x /= length
	out_z /= length
	_state[i] = WALL
	_nx[i] = out_x
	_nz[i] = out_z
	_a[i] = 0.0
	var along := head_x * -out_z + head_z * out_x
	_b[i] = clampf(along * 2.0, -0.8, 0.8)
	_c[i] = wall_climb * (0.3 + 0.7 * _spread[i])
	_wait[i] = 0.0
	_pitch[i] = 0.0
	_lift[i] = 0.0


func _on_wall(i: int, delta: float, want_x: float, want_z: float, him: Vector3, hunting: bool, homing: bool, quick: float) -> void:
	var x := _x[i]
	var z := _z[i]
	var ground := _ground[i]
	var up := _a[i]
	var out_x := _nx[i]
	var out_z := _nz[i]
	var side_x := -out_z
	var side_z := out_x
	var along := _b[i]
	var big := _size[i]
	var seed := _seed[i]
	var top := _c[i]
	var away := want_x * out_x + want_z * out_z
	var climbing := _wait[i] <= 0.0 and up < top and (away < 0.85 or up < top * 0.5) and not homing
	if hunting and him.y > ground + up + 0.2 and Vector2(him.x - x, him.z - z).length() < 1.5 and up < wall_climb:
		climbing = true
	if not climbing:
		_wait[i] = 1.0
	var wish_up := 1.0 if climbing else -1.0
	var wish_along := clampf(want_x * side_x + want_z * side_z, -1.0, 1.0) * 0.8 + sin(_time * (3.0 + seed * 4.0) + seed * 30.0) * 0.4
	along += (wish_along - along) * minf(delta * 4.0, 1.0)
	_b[i] = along
	var pace := speed * 0.45 * _pace[i] * quick
	var length := sqrt(wish_up * wish_up + along * along) + 0.0001
	var move_up := wish_up / length * pace * delta
	var move_along := along / length * pace * delta
	var new_x := x + side_x * move_along
	var new_z := z + side_z * move_along
	var foot := _height(new_x, new_z, ground)
	var face := _height(new_x - out_x * CELL, new_z - out_z * CELL, ground)
	if foot < BLOCKED and absf(foot - ground) < climb and face < BLOCKED and face - ground > climb:
		x = new_x
		z = new_z
	else:
		_b[i] = -along
	up += move_up
	_stride[i] += RatLook.stride_rate(pace, big) * delta
	if up <= 0.0:
		# Down off it, and away along its foot.
		up = 0.0
		_state[i] = GROUND
		var turned := signf(along) if absf(along) > 0.1 else _side_of[i]
		_hx[i] = side_x * turned * 0.8 + out_x * 0.6
		_hz[i] = side_z * turned * 0.8 + out_z * 0.6
		_detour[i] = 0.3 + seed * 0.3
		_wait[i] = 0.0
	_a[i] = up
	# (its belly to the wall, a hair off it)
	var place := Vector3(x + out_x * big * 0.04, ground + up + big * 0.03, z + out_z * big * 0.04)
	_x[i] = place.x
	_y[i] = place.y
	_z[i] = place.z
	if hunting:
		var near := Vector2(him.x - place.x, him.z - place.z).length_squared()
		if on_target < most_on and near < 0.42 and place.y > him.y - 0.25 and place.y < him.y + 1.2:
			_onto_target(i, him.x - place.x, him.z - place.z)
			return
	var heading := Vector3(side_x * along, wish_up, side_z * along).normalized()
	if up <= 0.0:
		_write(i * 16, place.x, ground, place.z, _hx[i], _hz[i], 0.0, big, i, 0.6, 0.0)
	else:
		_write_basis(i * 16, place, heading, Vector3(out_x, 0.0, out_z), big, i, 0.7, along * 0.4)


# --- Writing them down ----------------------------------------------------------

# Writes one rat into the MultiMesh: where it is, which way it heads, how it is tipped up (`pitch`, nose up
# for less than 0), how big; and its pose (how fast it goes, how its back bends).
func _write(at: int, x: float, y: float, z: float, head_x: float, head_z: float, pitch: float, big: float, i: int, go: float, bend: float) -> void:
	var level := cos(pitch) * big
	var rise := -sin(pitch) * big
	_buffer[at] = head_z * big
	_buffer[at + 1] = -head_x * rise
	_buffer[at + 2] = head_x * level
	_buffer[at + 3] = x
	_buffer[at + 4] = 0.0
	_buffer[at + 5] = level
	_buffer[at + 6] = rise
	_buffer[at + 7] = y
	_buffer[at + 8] = -head_x * big
	_buffer[at + 9] = -head_z * rise
	_buffer[at + 10] = head_z * level
	_buffer[at + 11] = z
	# (RatLook.write_custom, written out)
	_buffer[at + 12] = fposmod(_stride[i], 8.0)
	_buffer[at + 13] = roundf((clampf(bend, -1.0, 1.0) + 1.0) * 8.0) + clampf(go, 0.0, 0.99)
	_buffer[at + 14] = 0.0
	_buffer[at + 15] = _seed[i]


# The same, for a rat on a wall or on someone: heading `forward`, its back to `back`.
func _write_basis(at: int, place: Vector3, forward: Vector3, back: Vector3, big: float, i: int, go: float, bend: float) -> void:
	var across := back.cross(forward).normalized()
	var up := forward.cross(across).normalized()
	var ahead := forward.normalized()
	_buffer[at] = across.x * big
	_buffer[at + 1] = up.x * big
	_buffer[at + 2] = ahead.x * big
	_buffer[at + 3] = place.x
	_buffer[at + 4] = across.y * big
	_buffer[at + 5] = up.y * big
	_buffer[at + 6] = ahead.y * big
	_buffer[at + 7] = place.y
	_buffer[at + 8] = across.z * big
	_buffer[at + 9] = up.z * big
	_buffer[at + 10] = ahead.z * big
	_buffer[at + 11] = place.z
	# (RatLook.write_custom, written out)
	_buffer[at + 12] = fposmod(_stride[i], 8.0)
	_buffer[at + 13] = roundf((clampf(bend, -1.0, 1.0) + 1.0) * 8.0) + clampf(go, 0.0, 0.99)
	_buffer[at + 14] = 0.0
	_buffer[at + 15] = _seed[i]


func _come_out(i: int) -> void:
	var which := i % _drains.size()
	var drain := _drains[which]
	var out_of := _outs[which]
	var way := _rng.randf() * TAU
	if out_of != Vector3.ZERO:
		# (out of the hole, fanning out from the wall)
		var across := Vector3(-out_of.z, 0.0, out_of.x)
		var spread := _rng.randf_range(-1.0, 1.0)
		way = atan2(out_of.z + across.z * spread * 0.8, out_of.x + across.x * spread * 0.8)
		var along := _rng.randf_range(-0.2, 0.2)
		_x[i] = drain.x + out_of.x * 0.1 + across.x * along
		_z[i] = drain.z + out_of.z * 0.1 + across.z * along
		_y[i] = drain.y + _rng.randf() * 0.12
	else:
		_x[i] = drain.x + cos(way) * 0.12
		_z[i] = drain.z + sin(way) * 0.12
		_y[i] = drain.y
	_state[i] = GROUND
	_hx[i] = cos(way)
	_hz[i] = sin(way)
	_ground[i] = NAN
	_grown[i] = 0.4
	_pitch[i] = 0.0
	_wait[i] = 0.0
	_detour[i] = 0.0
	_lift[i] = 0.0
	_direct[i] = 1
	out += 1


func _onto_target(i: int, to_x: float, to_z: float) -> void:
	_state[i] = ON
	_a[i] = atan2(-to_z, -to_x) + (_seed[i] - 0.5) * 4.0
	_b[i] = maxf(_y[i] + _lift[i] - target.y, 0.02)
	_wait[i] = 0.3 + _seed[i] * 0.6
	_lift[i] = 0.0


# Off them: flung the way they were going, and out.
func _let_go(i: int, going: Vector3) -> void:
	var way := _a[i]
	_state[i] = FLUNG
	_ground[i] = NAN
	_a[i] = going.x * 0.5 + cos(way) * 1.5
	_b[i] = going.z * 0.5 + sin(way) * 1.5
	_c[i] = 1.4 + going.y * 0.3


# --- The ground ---------------------------------------------------------------

# How high the ground is at a place, for a rat at the height `from`: remembered, or looked for now.
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


## Forgets what it knew of the ground (something has moved), so that it is looked at again.
func forget_ground() -> void:
	_heights.fill(NAN)


func _probe(x: float, z: float, from: float) -> float:
	_query.from = Vector3(x, from + climb + 0.45, z)
	_query.to = Vector3(x, from - drop - 0.6, z)
	var space := get_world_3d().direct_space_state
	var found := space.intersect_ray(_query)
	if found.is_empty():
		return BLOCKED
	var high: float = found.position.y
	if high - from > climb:
		# (too high to go up: but it may be something to go under)
		_query.from = Vector3(x, from + 0.3, z)
		var under := space.intersect_ray(_query)
		if not under.is_empty() and under.normal != Vector3.ZERO:
			high = under.position.y
	if forbid.is_valid() and forbid.call(Vector3(x, high, z)):
		return BLOCKED
	return high


# --- The drains -----------------------------------------------------------------

## The mouth of a drain, facing +Z (out of the wall) with its foot at the
## origin: a black hole broken through the foot of the wall, ragged at its
## edges, the stumps of an old iron grate across it, a wet stain run down the
## wall into it and spread out in front on the ground. `in_wall` false: a
## ragged hole in the floor, a grate half over it.
static func drain_mesh(in_wall: bool, drain_seed := 0) -> ArrayMesh:
	var chance := RandomNumberGenerator.new()
	chance.seed = drain_seed * 7919 + 31
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dark := Color(0.012, 0.011, 0.01)
	var stain := Color(0.06, 0.055, 0.05)
	var iron := Color(0.11, 0.085, 0.07)
	if in_wall:
		# The stain: a dark wet patch on the wall round and over the hole, and spread on the ground before it.
		tool.set_normal(Vector3.BACK)
		tool.set_color(stain)
		var high := chance.randf_range(0.36, 0.46)
		var wide := chance.randf_range(0.3, 0.38)
		var rim: Array[Vector3] = []
		for k in 13:
			var turn := PI * k / 12.0
			var far := chance.randf_range(1.15, 1.5)
			rim.append(Vector3(cos(turn) * wide * far, sin(turn) * high * far * 1.1, 0.008))
		for k in 12:
			_tri(tool, Vector3(0.0, 0.02, 0.008), rim[k], rim[k + 1])
		# The hole: an arch, its edge broken.
		tool.set_color(dark)
		var edge: Array[Vector3] = []
		for k in 11:
			var turn := PI * k / 10.0
			var bite := chance.randf_range(0.85, 1.12)
			edge.append(Vector3(cos(turn) * wide * bite, sin(turn) * high * bite, 0.014))
		for k in 10:
			_tri(tool, Vector3(0.0, 0.0, 0.014), edge[k], edge[k + 1])
		# The stumps of a grate: bent bars across the hole, two of them broken off.
		tool.set_color(iron)
		for bar in 5:
			var x := lerpf(-wide * 0.7, wide * 0.7, bar / 4.0)
			var top := sqrt(maxf(1.0 - pow(x / wide, 2.0), 0.0)) * high * 0.95
			var broken := chance.randf() < 0.4
			var stop := top * (chance.randf_range(0.15, 0.45) if broken else 1.0)
			var lean := chance.randf_range(-0.04, 0.04) + (0.08 if broken else 0.0)
			var a := Vector3(x - 0.012, 0.0, 0.02)
			var b := Vector3(x + 0.012, 0.0, 0.02)
			var c := Vector3(x + 0.012 + lean, stop, 0.02 + (0.05 if broken else 0.0))
			var d := Vector3(x - 0.012 + lean, stop, 0.02 + (0.05 if broken else 0.0))
			_quad(tool, a, b, c, d)
		# The spill on the ground before it.
		tool.set_normal(Vector3.UP)
		tool.set_color(stain)
		var spill: Array[Vector3] = []
		for k in 11:
			var turn := PI * k / 10.0
			var far := chance.randf_range(0.5, 0.9)
			spill.append(Vector3(cos(turn) * far * 1.1, 0.012, sin(turn) * far * 0.8 + 0.02))
		for k in 10:
			_tri(tool, Vector3(0.0, 0.012, 0.02), spill[k + 1], spill[k])
		tool.set_color(dark)
		var shade: Array[Vector3] = []
		for k in 9:
			var turn := PI * k / 8.0
			shade.append(Vector3(cos(turn) * wide * 1.05, 0.014, sin(turn) * 0.16 + 0.02))
		for k in 8:
			_tri(tool, Vector3(0.0, 0.014, 0.02), shade[k + 1], shade[k])
	else:
		tool.set_normal(Vector3.UP)
		tool.set_color(dark)
		var rim: Array[Vector3] = []
		for k in 12:
			var turn := TAU * k / 12.0
			var far := 0.4 + 0.08 * sin(k * 2.7 + drain_seed)
			rim.append(Vector3(cos(turn) * far, 0.012, sin(turn) * far))
		for k in 12:
			_tri(tool, Vector3(0.0, 0.012, 0.0), rim[(k + 1) % 12], rim[k])
		tool.set_color(iron)
		for bar in 4:
			var x := lerpf(-0.25, 0.25, bar / 3.0)
			_quad(tool, Vector3(x - 0.015, 0.016, -0.3), Vector3(x - 0.015, 0.016, 0.1), Vector3(x + 0.015, 0.016, 0.1), Vector3(x + 0.015, 0.016, -0.3))
	var made := tool.commit()
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.vertex_color_use_as_albedo = true
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	made.surface_set_material(0, paint)
	return made


static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)


static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(tool, a, b, c)
	_tri(tool, a, c, d)

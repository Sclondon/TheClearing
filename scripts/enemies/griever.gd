class_name Griever
extends Node3D
## A Griever: a great wet lump of flesh, as high as a man, carried through the
## maze on eight mechanical spider's legs, with a scorpion's tail of metal
## vertebrae curled over its back and a stinger at the end of it.
##
## It wanders the passages (a path over the Maze's cells, found breadth first),
## and hunts whoever it sees (in front of it with nothing in the way, or close
## enough in any direction) or hears (anyone running within earshot, through
## the walls too). It is quicker than a run and slower than a sprint: a boy who
## sprints down a straight gets away. Near enough, it winds its tail up (a
## shivering, coiling warning: the time to get out of the way) and then throws
## it; if the stinger meets someone, `caught` is emitted with them.
##
## Its legs walk by themselves (GrieverLegs: feet planted in the world, stepping
## when they are left behind, set down by casting rays, so they stand on the
## ground, on the walls' footings, or brace against the walls), and its body
## rides on them: as high as they hold it, tipped as they lie, sagging and
## sloshing as it starts, stops and steps (GrieverLook's flesh shader).
##
## Online, one copy (the host's) thinks for it; the others set `puppet` and pass
## on what the host sends (`state_bytes` there, `from_bytes` here). A puppet
## does not think and does not catch anybody; it follows its news smoothly, and
## its legs and tail move by themselves from how it moves and what it is doing.
##
## Spawn:
##     var griever := Griever.new()
##     add_child(griever)
##     griever.setup(maze, cell)
##     griever.targets = [player, ...remote players]
##     griever.caught.connect(func(who): ...)

## It has caught someone with its stinger. (Not emitted by a puppet.)
signal caught(target: Node3D)
## It has seen someone and given chase.
signal spotted(target: Node3D)
## It has begun to wind up a strike at someone: the warning.
signal winding_up(target: Node3D)

enum State { ROAM, HUNT, SEARCH, WINDUP, STRIKE, RECOVER }

const ROAM_SPEED := 2.2
## Faster than the boy runs (4.4), slower than he sprints (5.6).
const HUNT_SPEED := 4.9
## How far it sees ahead, and how wide (the cosine of half the angle).
const SIGHT := 42.0
const SIGHT_CONE := 0.3
## Anyone this close is noticed whichever way it is facing (if nothing is in the way).
const NEAR := 8.0
## Anyone running this close is heard, walls or no walls.
const HEAR := 16.0
## Strikes at someone this far from its middle (on the ground).
const STRIKE_RANGE := 4.8
const WINDUP_TIME := 0.6
const STRIKE_TIME := 0.34
const RECOVER_TIME := 0.85
## How far from the stinger's point someone's chest is struck.
const HIT_RADIUS := 0.9
## How high the middle of the lump rides over the ground.
const RIDE := 2.45
## Half its width, kept off the walls.
const HALF_WIDTH := 1.6
## Seconds before it goes after someone it has caught again.
const CATCH_COOLDOWN := 4.0

var maze: Maze
## Whoever it can hunt: Node3Ds, normally the Player and the RemotePlayers.
## Their position is their feet; `velocity`, if they have it, is read for hearing.
var targets: Array = []
## Online, on every copy but the host's: does not think, follows `hear`.
var puppet := false
## Keeps out of the clearing (and does not hunt anyone in it).
var stay_out_of_clearing := false
## Whether it is after someone (read by Player, as one of the "pursuers").
var chasing := false
var state := State.ROAM
## Whom it is after, if anyone.
var prey: Node3D
var velocity := Vector3.ZERO
## Which way it faces (radians about +Y; 0 faces -Z).
var yaw := 0.0

var legs := GrieverLegs.new()
var stinger := GrieverStinger.new()
## Where the body (the middle of the lump) is, this frame.
var body := Transform3D()

var _rng := RandomNumberGenerator.new()
var _path: Array[Vector2i] = []
var _path_at := 0
var _goal := Vector3.ZERO
var _steer := 0.0
## Which side of a passage it keeps to when it wanders (1 or -1).
var _hug_side := 1
var _repath := 0.0
var _sense := 0.0
var _state_time := 0.0
var _last_seen := Vector3.ZERO
var _since_seen := 99.0
var _wait := 0.0
var _cooldowns := {}
var _settle := true
var _direct := false
var _prev_velocity := Vector3.ZERO
var _height := RIDE
var _height_v := 0.0
var _tilt := Vector2.ZERO
var _jiggle := Vector3.ZERO
var _jiggle_v := Vector3.ZERO
var _time := 0.0
var _beat := 0.0
var _aim := Vector3.ZERO
var _exclude: Array[RID] = []

var _net_pos := Vector3.ZERO
var _net_velocity := Vector3.ZERO
var _net_yaw := 0.0
var _net_heard := false

var _flesh: MeshInstance3D
var _flesh_material: ShaderMaterial
var _bars: MultiMeshInstance3D
var _drums: MultiMeshInstance3D
var _spikes: MultiMeshInstance3D


func _init() -> void:
	_rng.randomize()


func _ready() -> void:
	add_to_group(&"pursuers")
	add_to_group(&"grievers")
	var hip_points: Array = []
	for i in GrieverLegs.COUNT:
		hip_points.append(GrieverLegs.hip_local(i))
	_flesh = MeshInstance3D.new()
	_flesh.name = "Flesh"
	_flesh.mesh = GrieverLook.flesh_mesh(hip_points)
	_flesh_material = GrieverLook.flesh_material()
	_flesh.material_override = _flesh_material
	_flesh.top_level = true
	_flesh.extra_cull_margin = 1.5
	add_child(_flesh)
	_bars = GrieverLook.parts(GrieverLook.bar(), 96)
	_bars.name = "Bars"
	add_child(_bars)
	_drums = GrieverLook.parts(GrieverLook.drum(), 40)
	_drums.name = "Hinges"
	add_child(_drums)
	_spikes = GrieverLook.parts(GrieverLook.spike(), 40)
	_spikes.name = "Spikes"
	add_child(_spikes)
	for part: Node3D in [_bars, _drums, _spikes]:
		part.global_transform = Transform3D.IDENTITY


## Puts it in `plan` at `cell`, facing `facing`.
func setup(plan: Maze, cell: Vector2i, facing := 0.0) -> void:
	maze = plan
	_rng.seed = hash(cell) ^ plan.maze_seed
	place(plan.world(cell), facing)


## Puts it straight somewhere (its feet are set down afresh).
func place(at: Vector3, facing := 0.0) -> void:
	global_position = at
	yaw = facing
	rotation = Vector3(0.0, yaw, 0.0)
	velocity = Vector3.ZERO
	_prev_velocity = Vector3.ZERO
	_height = RIDE
	_height_v = 0.0
	_path.clear()
	_settle = true
	_net_pos = at
	_net_yaw = facing


# --- Thinking -----------------------------------------------------------------


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	_time += delta
	_state_time += delta
	_exclude.clear()
	for t: Variant in players():
		if is_instance_valid(t) and t is CollisionObject3D:
			_exclude.append((t as CollisionObject3D).get_rid())
	legs.exclude = _exclude
	if puppet:
		_follow(delta)
	else:
		_think(delta)
		_drive(delta)
	chasing = prey != null and state != State.ROAM and state != State.SEARCH
	_animate(delta)


func _think(delta: float) -> void:
	for t: Variant in _cooldowns.keys():
		_cooldowns[t] -= delta
		if _cooldowns[t] <= 0.0 or not is_instance_valid(t):
			_cooldowns.erase(t)
	if prey != null and not is_instance_valid(prey):
		prey = null
	_since_seen += delta
	_sense -= delta
	if _sense <= 0.0:
		_sense = 0.15
		_look()

	match state:
		State.ROAM:
			if _path_done():
				_wait -= delta
				if _wait <= 0.0:
					_wander()
		State.HUNT:
			if prey == null or _since_seen > 2.5:
				_search(_last_seen)
			else:
				_repath -= delta
				if _repath <= 0.0:
					_repath = 0.45
					_path = _find_path(_cell(), maze.cell_at(_last_seen))
					_path_at = 0
					_steer = 0.0
				if _since_seen < 0.3 and _can_strike(prey):
					_enter(State.WINDUP)
					winding_up.emit(prey)
		State.SEARCH:
			if _path_done():
				# Look round where they were last.
				_wait -= delta
				if _wait <= 0.0:
					_enter(State.ROAM)
					_wait = 0.5
		State.WINDUP:
			if prey != null:
				_aim = _chest(prey)
			if _state_time >= WINDUP_TIME:
				_enter(State.STRIKE)
				if prey != null:
					var lead: Vector3 = _velocity_of(prey) * 0.12
					_aim = _chest(prey) + Vector3(lead.x, 0.0, lead.z)
		State.STRIKE:
			if stinger.throw > 0.55:
				_check_hits()
			if state == State.STRIKE and _state_time >= STRIKE_TIME:
				_enter(State.RECOVER)
		State.RECOVER:
			if _state_time >= RECOVER_TIME:
				if prey != null and _since_seen < 1.5:
					_enter(State.HUNT)
				else:
					_search(_last_seen)


func _enter(next: State) -> void:
	state = next
	_state_time = 0.0


## Looks and listens for whoever is about.
func _look() -> void:
	var forward := -global_basis.z
	var eye := global_position + Vector3.UP * (RIDE + 0.6)
	var best: Node3D = null
	var best_distance := INF
	var heard: Node3D = null
	for t: Variant in players():
		if not _huntable(t):
			continue
		var target := t as Node3D
		var to := target.global_position - global_position
		to.y = 0.0
		var distance := to.length()
		if distance > SIGHT:
			continue
		var ahead := forward.dot(to / maxf(distance, 0.01)) > SIGHT_CONE
		if (distance < NEAR or ahead) and _clear(eye, _chest(target)):
			if distance < best_distance:
				best = target
				best_distance = distance
		elif distance < HEAR and Vector2(_velocity_of(target).x, _velocity_of(target).z).length() > 3.0:
			heard = target
	if best != null:
		if prey != best and (state == State.ROAM or state == State.SEARCH or prey == null):
			spotted.emit(best)
		if prey == null or state == State.ROAM or state == State.SEARCH or best == prey or best_distance < 3.0:
			prey = best
		if prey == best:
			_last_seen = best.global_position
			_since_seen = 0.0
		if state == State.ROAM or state == State.SEARCH:
			_enter(State.HUNT)
			_repath = 0.0
	elif heard != null and (state == State.ROAM or state == State.SEARCH):
		prey = heard
		_search(heard.global_position)


## Whoever it may hunt: `targets`, or if that is empty everyone in the group
## `maze_players` (as for MazeEnemy).
func players() -> Array:
	if not targets.is_empty():
		return targets
	return get_tree().get_nodes_in_group(&"maze_players") if is_inside_tree() else []


## Not someone who is out of the maze, down (`is_limp`), or just caught.
func _huntable(t: Variant) -> bool:
	if not is_instance_valid(t) or not (t is Node3D) or not (t as Node3D).is_inside_tree():
		return false
	if _cooldowns.has(t):
		return false
	if (t as Node).get(&"escaped") == true or (t as Node).get(&"is_limp") == true:
		return false
	var cell := maze.cell_at((t as Node3D).global_position) if maze != null else Vector2i.ZERO
	if maze != null and not maze.inside(cell):
		return false
	if stay_out_of_clearing and maze != null and maze.in_clearing(cell):
		return false
	return true


func _can_strike(target: Node3D) -> bool:
	var to := target.global_position - global_position
	var up := to.y
	to.y = 0.0
	if to.length() > STRIKE_RANGE or absf(up) > 3.0:
		return false
	return _clear(global_position + Vector3.UP * (RIDE + 1.5), _chest(target))


func _check_hits() -> void:
	var from := stinger.joints[GrieverStinger.COUNT]
	for t: Variant in players():
		if not _huntable(t):
			continue
		var chest := _chest(t)
		var nearest := Geometry3D.get_closest_point_to_segment(chest, from, stinger.tip)
		# (from the chest down to the knees counts)
		var low := Geometry3D.get_closest_point_to_segment((t as Node3D).global_position + Vector3.UP * 0.4, from, stinger.tip)
		if nearest.distance_to(chest) < HIT_RADIUS or low.distance_to((t as Node3D).global_position + Vector3.UP * 0.4) < HIT_RADIUS * 0.8:
			_cooldowns[t] = CATCH_COOLDOWN
			if t == prey:
				prey = null
			caught.emit(t)
			_enter(State.RECOVER)
			return


func _wander() -> void:
	var here := _cell()
	for attempt in 12:
		var cell := Vector2i(_rng.randi_range(0, maze.size - 1), _rng.randi_range(0, maze.size - 1))
		if stay_out_of_clearing and maze.in_clearing(cell):
			continue
		var path := _find_path(here, cell)
		if path.size() >= 4 and path.size() <= 24:
			_path = path
			_path_at = 0
			_steer = 0.0
			_wait = _rng.randf_range(0.6, 2.2)
			_hug_side = 1 if _rng.randf() < 0.5 else -1
			return
	_wait = 0.5


## Sends it wandering to `cell` (along one wall of each passage, climbing it
## with the legs on that side), as it does by itself when nobody is about.
## `side` is which wall: 1 or -1 (0 leaves it as it was).
func walk_to(cell: Vector2i, side := 0) -> void:
	if puppet or maze == null:
		return
	_enter(State.ROAM)
	prey = null
	if side != 0:
		_hug_side = signi(side)
	_path = _find_path(_cell(), cell)
	_path_at = 0
	_steer = 0.0
	_wait = 1.0


## Something was heard at `at` (a shout, a door, a fall): if it is not hunting
## already, it goes to see.
func alert(at: Vector3) -> void:
	if not puppet and (state == State.ROAM or state == State.SEARCH):
		_search(at)


func _search(where: Vector3) -> void:
	_enter(State.SEARCH)
	_last_seen = where
	_path = _find_path(_cell(), maze.cell_at(where))
	_path_at = 0
	_steer = 0.0
	_wait = 2.0


func _path_done() -> bool:
	return _path_at >= _path.size()


func _cell() -> Vector2i:
	return maze.cell_at(global_position)


## Cells from `from` (not included) to `to`, breadth first round the walls.
func _find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if maze == null or not maze.inside(to) or from == to:
		return path
	var came := {from: from}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		if cell == to:
			while cell != from:
				path.push_front(cell)
				cell = came[cell]
			return path
		for step: Vector2i in Maze.STEPS:
			var next := cell + step
			if not maze.inside(next) or came.has(next) or maze.blocked(cell, step):
				continue
			if stay_out_of_clearing and maze.in_clearing(next) and next != to:
				continue
			came[next] = cell
			queue.push_back(next)
	return path


# --- Moving -------------------------------------------------------------------


func _drive(delta: float) -> void:
	var speed := 0.0
	var goal := global_position
	var face_to := Vector3.INF
	_direct = false
	match state:
		State.ROAM:
			speed = ROAM_SPEED
		State.SEARCH:
			speed = HUNT_SPEED * 0.75
		State.HUNT:
			speed = HUNT_SPEED
			if prey != null and _since_seen < 0.3:
				var gap := prey.global_position - global_position
				gap.y = 0.0
				# In sight and near: straight at them.
				_direct = gap.length() < Maze.CELL * 1.6 or maze.cell_at(prey.global_position) == _cell()
		State.WINDUP:
			speed = 1.0
			if prey != null:
				face_to = prey.global_position
				_direct = true
		State.STRIKE:
			speed = 0.0
			face_to = _aim
		State.RECOVER:
			speed = 0.8
	if _direct and prey != null:
		goal = prey.global_position
	elif not _path_done():
		_steer -= delta
		var flat := _goal - global_position
		flat.y = 0.0
		if _steer <= 0.0 or flat.length() < 1.2:
			_pick_goal()
		goal = _goal if not _path_done() else global_position
	var want := goal - global_position
	want.y = 0.0
	if want.length() < 0.6 and not _direct:
		speed = 0.0
	if _direct and want.length() < 2.6:
		speed = minf(speed, maxf(want.length() - 1.8, 0.0) * 2.0)
	var dir := want.normalized() if want.length() > 0.01 else Vector3.ZERO
	# Turning: towards where it goes, or at whom it strikes.
	var look := dir
	if face_to != Vector3.INF:
		look = face_to - global_position
		look.y = 0.0
		look = look.normalized() if look.length() > 0.01 else dir
	if state == State.SEARCH and _path_done():
		yaw += 1.4 * delta
	elif look != Vector3.ZERO:
		var wanted_yaw := atan2(-look.x, -look.z)
		var turn := 4.2 if state == State.HUNT or state == State.WINDUP else 2.4
		yaw = rotate_toward(yaw, wanted_yaw, turn * delta)
	# It can walk crabwise, but goes slowly until it has turned.
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var align := clampf(forward.dot(dir), 0.0, 1.0)
	var wish := dir * speed * (0.3 + 0.7 * align * align)
	velocity = velocity.move_toward(wish, (9.0 if wish.length() > velocity.length() else 12.0) * delta)
	var at := global_position + velocity * delta
	at = _keep_in(at)
	velocity = (at - global_position) / delta if delta > 0.0 else velocity
	velocity.y = 0.0
	at.y = _ground_under(at)
	global_position = at
	rotation = Vector3(0.0, yaw, 0.0)


## Where to make for along the path: the furthest of the next few cells it can
## reach in a straight line without brushing a wall (so it cuts corners), and,
## wandering, along one side of a passage rather than down its middle, close
## enough that the legs on that side climb the wall.
func _pick_goal() -> void:
	_steer = 0.15
	var here := _cell()
	var middle := maze.world(here)
	# (a cell is passed once it is in it and near its middle, or can see past it)
	while not _path_done() and _path[_path_at] == here:
		var on := _path_at + 1 < _path.size() and _sweep(global_position, _point_on_path(_path_at + 1))
		if not on and Vector2(global_position.x - middle.x, global_position.z - middle.z).length() > Maze.CELL * 0.3:
			break
		_path_at += 1
	if _path_done():
		return
	var best := _path_at
	for k in range(_path_at + 1, mini(_path_at + 4, _path.size())):
		if not _sweep(global_position, _point_on_path(k)):
			break
		best = k
	_goal = _point_on_path(best)


## The point it makes for in path cell k: its middle, or beside a wall.
func _point_on_path(k: int) -> Vector3:
	var cell := _path[k]
	var point := maze.world(cell)
	if state != State.ROAM:
		return point
	var before := _path[k - 1] if k > 0 else _cell()
	var step := cell - before
	if step == Vector2i.ZERO or (k + 1 < _path.size() and _path[k + 1] - cell != step):
		return point
	var side := Vector2i(-step.y, step.x) * _hug_side
	if not maze.blocked(cell, side):
		return point
	var hug := Maze.CELL * 0.5 - MazeBuilder.WALL_THICK * 0.5 - MazeBuilder.FOOT.x - 2.9
	return point + Vector3(side.x, 0.0, side.y) * maxf(hug, 0.0)


## Whether the body can go straight from `a` to `b` without touching a wall.
func _sweep(a: Vector3, b: Vector3) -> bool:
	var along := b - a
	along.y = 0.0
	if along.length() < 0.01:
		return true
	var across := Vector3(-along.z, 0.0, along.x).normalized() * (HALF_WIDTH + 0.4)
	var lift := Vector3.UP * 1.2
	return _clear(a + lift + across, b + lift + across) and _clear(a + lift - across, b + lift - across)


## Keeps the body off the walls of the cell it is in.
func _keep_in(at: Vector3) -> Vector3:
	if maze == null:
		return at
	var cell := maze.cell_at(at)
	if not maze.inside(cell):
		return at
	var middle := maze.world(cell)
	for step: Vector2i in Maze.STEPS:
		if not maze.blocked(cell, step):
			continue
		var thick := MazeBuilder.RING_THICK if maze.ring_wall(cell, step) else MazeBuilder.WALL_THICK
		var limit := Maze.CELL * 0.5 - thick * 0.5 - HALF_WIDTH
		var out := Vector3(step.x, 0.0, step.y)
		var along := (at - middle).dot(out)
		if along > limit:
			at -= out * (along - limit)
	return at


func _ground_under(at: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.5, at + Vector3.DOWN * 8.0, 1, _exclude))
	return float(hit["position"].y) if not hit.is_empty() else at.y


func _clear(from: Vector3, to: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1, _exclude)).is_empty()


static func _chest(t: Variant) -> Vector3:
	return (t as Node3D).global_position + Vector3.UP * 0.9


static func _velocity_of(t: Variant) -> Vector3:
	var moving: Variant = (t as Node).get(&"velocity")
	return moving if moving is Vector3 else Vector3.ZERO


# --- Online -------------------------------------------------------------------


## News of it from the host: where it is, how fast it goes, which way it
## faces, and what it is doing (a State). `aim` is where a strike is aimed.
func hear(at: Vector3, moving: Vector3, facing: float, doing: int, aim: Variant = null) -> void:
	_net_pos = at
	_net_velocity = moving
	_net_yaw = facing
	if aim is Vector3:
		_aim = aim
	if doing != state:
		_enter(doing as State)
	if not _net_heard or global_position.distance_to(at) > 6.0:
		place(at, facing)
	_net_heard = true


## Bytes in `state_bytes`: laid out as MazeEnemy's are (position, velocity,
## yaw, state, a spare byte, then the point it strikes at, from where it is).
const STATE_SIZE := 28


## It, in STATE_SIZE bytes, for the host to send. `from_bytes` on another copy takes it.
func state_bytes() -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(STATE_SIZE)
	data.encode_float(0, global_position.x)
	data.encode_float(4, global_position.y)
	data.encode_float(8, global_position.z)
	data.encode_half(12, velocity.x)
	data.encode_half(14, velocity.y)
	data.encode_half(16, velocity.z)
	data.encode_u16(18, int(fposmod(yaw, TAU) / TAU * 65535.0))
	data[20] = state
	data[21] = 0
	var off := (_aim - global_position).clamp(Vector3.ONE * -60000.0, Vector3.ONE * 60000.0)
	data.encode_half(22, off.x)
	data.encode_half(24, off.y)
	data.encode_half(26, off.z)
	return data


## Takes news made by `state_bytes` (from `offset` in `data`). It does not make
## it a puppet: set `puppet` for that. False if it is not news.
func from_bytes(data: PackedByteArray, offset := 0) -> bool:
	if data.size() < offset + STATE_SIZE or data[offset + 20] > State.RECOVER:
		return false
	var at := Vector3(data.decode_float(offset), data.decode_float(offset + 4), data.decode_float(offset + 8))
	var moving := Vector3(data.decode_half(offset + 12), data.decode_half(offset + 14), data.decode_half(offset + 16))
	var facing := data.decode_u16(offset + 18) / 65535.0 * TAU
	var aim := at + Vector3(data.decode_half(offset + 22), data.decode_half(offset + 24), data.decode_half(offset + 26))
	hear(at, moving, facing, data[offset + 20], aim)
	return true


func _follow(delta: float) -> void:
	if not _net_heard:
		return
	# Carry on as it was going, and close on where it was last heard of.
	_net_pos += _net_velocity * delta
	var at := global_position.lerp(_net_pos, 1.0 - exp(-7.0 * delta))
	velocity = velocity.lerp((at - global_position) / delta, 1.0 - exp(-12.0 * delta))
	velocity.y = 0.0
	global_position = at
	yaw = lerp_angle(yaw, _net_yaw, 1.0 - exp(-8.0 * delta))
	rotation = Vector3(0.0, yaw, 0.0)


# --- Moving the body, legs and tail -------------------------------------------


func _animate(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var ground := Transform3D(Basis(Vector3.UP, yaw), global_position)
	if _settle:
		_settle = false
		body = ground * Transform3D(Basis(), Vector3.UP * RIDE)
		legs.settle(space, body, ground)

	# The tail: wound up, thrown, or curled.
	var wind_to := 0.0
	var throw_to := 0.0
	match state:
		State.WINDUP:
			wind_to = clampf(_state_time / WINDUP_TIME, 0.0, 1.0)
		State.STRIKE:
			throw_to = 1.0
		State.RECOVER:
			throw_to = clampf(1.0 - _state_time / 0.45, 0.0, 1.0)
	stinger.wind = move_toward(stinger.wind, wind_to, delta * (2.5 if wind_to > stinger.wind else 6.0))
	stinger.throw = move_toward(stinger.throw, throw_to, delta * (9.0 if throw_to > stinger.throw else 2.5))
	stinger.aim = _aim

	# How high it rides and how it tips, from how its feet lie.
	var lie := legs.lie(ground)
	var up_steps := 0
	for i in GrieverLegs.COUNT:
		if legs.stepping[i]:
			up_steps += 1
	var want := RIDE + clampf(lie.x, -0.6, 2.0) * 0.4 - up_steps * 0.04 - stinger.wind * 0.45 - stinger.throw * 0.2
	var height_a := (want - _height) * 70.0 - _height_v * 11.0
	_height_v += height_a * delta
	_height += _height_v * delta
	var pitch := clampf(atan2(lie.y, 2.1) * 0.8, -0.35, 0.35)
	var roll := clampf(-atan2(lie.z, 2.5) * 0.8, -0.3, 0.3)
	var acceleration := (velocity - _prev_velocity) / delta
	_prev_velocity = velocity
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	# (it leans back as it sets off, into a stop, and rears as it winds up)
	pitch += clampf(-acceleration.dot(forward) * 0.015, -0.1, 0.1) + stinger.wind * 0.12 - stinger.throw * 0.18
	_tilt = _tilt.lerp(Vector2(pitch, roll), 1.0 - exp(-6.0 * delta))
	var lunge := Vector3(0.0, 0.0, stinger.wind * 0.35 - stinger.throw * 0.7)
	body = ground * Transform3D(Basis.from_euler(Vector3(_tilt.x, 0.0, _tilt.y)), Vector3(0.0, _height, 0.0) + lunge)

	# The flesh sloshes after the frame (and the bounce of the ride).
	var felt := body.basis.inverse() * (acceleration + Vector3.UP * height_a * 0.25)
	felt = felt.limit_length(18.0)
	_jiggle_v += (-_jiggle * 75.0 - _jiggle_v * 5.5 - felt * 1.4) * delta
	_jiggle += _jiggle_v * delta
	_jiggle = _jiggle.limit_length(0.35)
	var hunting := state != State.ROAM
	_beat += delta * (2.1 if hunting else 1.1) * TAU
	var pulse := pow(maxf(sin(_beat), 0.0), 8.0) + 0.6 * pow(maxf(sin(_beat - 0.9), 0.0), 8.0)
	_flesh_material.set_shader_parameter(&"jiggle", _jiggle)
	_flesh_material.set_shader_parameter(&"bounce", clampf(-_jiggle.y * 0.8, -0.12, 0.2))
	_flesh_material.set_shader_parameter(&"breath", sin(_time * (2.4 if hunting else 1.3)))
	_flesh_material.set_shader_parameter(&"pulse", pulse)
	_flesh.global_transform = body

	legs.update(delta, space, body, ground, velocity)
	legs.pose(body.basis.y, body.origin)
	# (the tail is rooted in the flesh, so it slops with it)
	stinger.update(delta, body.translated_local(_jiggle * 0.8))
	_draw()


## Rest of the metal, placed for this frame.
func _draw() -> void:
	var bars := _bars.multimesh
	var drums := _drums.multimesh
	var spikes := _spikes.multimesh
	var nb := 0
	var nd := 0
	var ns := 0
	var up := body.basis.y
	for i in GrieverLegs.COUNT:
		var hip := legs.hips[i]
		var knee := legs.knees[i]
		var ankle := legs.ankles[i]
		var foot := legs.feet[i]
		var local := GrieverLegs.hip_local(i)
		var mount := body * (local * Vector3(0.55, 1.0, 0.85) + Vector3.UP * 0.1)
		var bend := (hip - knee).cross(ankle - knee)
		var axis := bend.normalized() if bend.length_squared() > 0.0001 else body.basis.z
		var out := (knee - (hip + ankle) * 0.5).normalized()
		# The mount in the body, thigh and shin.
		nb = _bar(bars, nb, mount, hip, 0.2, axis, STEEL_DARK)
		# (the thigh a beam with a strut along it; the shin telescoped, thick
		# above and a thinner rod below)
		nb = _bar(bars, nb, hip, knee, 0.17, axis, STEEL)
		var brace := axis.cross(knee - hip).normalized()
		if brace.dot(out) < 0.0:
			brace = -brace
		nb = _bar(bars, nb, hip.lerp(knee, 0.12) + brace * 0.16, hip.lerp(knee, 0.88) + brace * 0.16, 0.06, axis, STEEL_DARK)
		nb = _bar(bars, nb, knee, knee.lerp(ankle, 0.5), 0.15, axis, STEEL_DARK)
		nb = _bar(bars, nb, knee.lerp(ankle, 0.45), ankle, 0.085, axis, STEEL)
		# A piston from the body to the thigh...
		var p0 := body * (local * Vector3(0.75, 1.0, 1.0) + Vector3.UP * 0.6)
		var p1 := hip.lerp(knee, 0.5) + out * 0.08
		nb = _bar(bars, nb, p0, p0.lerp(p1, 0.55), 0.085, axis, BRASS)
		nb = _bar(bars, nb, p0, p1, 0.04, axis, CHROME)
		# ...and one from the thigh to the shin, on the outside of the bend.
		var q0 := hip.lerp(knee, 0.35) + out * 0.24
		var q1 := knee.lerp(ankle, 0.4) + out * 0.16
		nb = _bar(bars, nb, q0, q0.lerp(q1, 0.5), 0.07, axis, BRASS)
		nb = _bar(bars, nb, q0, q1, 0.035, axis, CHROME)
		drums.set_instance_transform(nd, GrieverLook.hinge(hip, axis, 0.18, 0.32))
		drums.set_instance_color(nd, HINGE)
		drums.set_instance_transform(nd + 1, GrieverLook.hinge(knee, axis, 0.2, 0.34))
		drums.set_instance_color(nd + 1, HINGE)
		drums.set_instance_transform(nd + 2, GrieverLook.hinge(ankle, axis, 0.11, 0.22))
		drums.set_instance_color(nd + 2, HINGE)
		nd += 3
		spikes.set_instance_transform(ns, GrieverLook.between(ankle, foot, 0.1, axis))
		spikes.set_instance_color(ns, CLAW)
		# A spur standing up off the knee.
		var spur := (out + up * 0.6 + (knee - hip).normalized() * 0.5).normalized()
		spikes.set_instance_transform(ns + 1, GrieverLook.between(knee, knee + spur * 0.55, 0.09, axis))
		spikes.set_instance_color(ns + 1, CLAW)
		ns += 2
	# The tail.
	var joints := stinger.joints
	var side := body.basis.x
	for i in GrieverStinger.COUNT:
		var thick := lerpf(0.3, 0.1, float(i) / GrieverStinger.COUNT)
		nb = _bar(bars, nb, joints[i], joints[i + 1], thick, side, STEEL if i % 2 == 0 else STEEL_DARK)
		drums.set_instance_transform(nd, GrieverLook.hinge(joints[i], side, thick * 0.85, thick * 1.7))
		drums.set_instance_color(nd, HINGE)
		nd += 1
		# A fin of spikes down its back.
		if i > 0 and i < GrieverStinger.COUNT - 1:
			var along := joints[i + 1] - joints[i]
			var back := along.cross(side).normalized()
			var base := joints[i].lerp(joints[i + 1], 0.5)
			spikes.set_instance_transform(ns, GrieverLook.between(base, base + back * thick * 2.6 - along * 0.25, thick * 0.45, side))
			spikes.set_instance_color(ns, STEEL_DARK)
			ns += 1
	var last := joints[GrieverStinger.COUNT]
	spikes.set_instance_transform(ns, GrieverLook.between(last, stinger.tip, 0.13, side))
	spikes.set_instance_color(ns, STING)
	ns += 1
	# Barbs at the base of the sting.
	var point := (stinger.tip - last).normalized()
	for s: float in [-1.0, 1.0]:
		var barb := last + point * 0.15
		spikes.set_instance_transform(ns, GrieverLook.between(barb, barb + side * s * 0.25 - point * 0.3, 0.05, point))
		spikes.set_instance_color(ns, STING)
		ns += 1
	# Quills stuck in the flesh along its back.

	for quill: Vector4 in QUILLS:
		var dir := Vector3(quill.x, quill.y, quill.z).normalized()
		var on := GrieverLook.surface(dir) * 0.93 + _jiggle * (0.2 + 0.8 * clampf(dir.y * 0.55 + 0.5, 0.0, 1.0))
		var base := body * on
		var tip := body * (on + (dir + Vector3.BACK * 0.5).normalized() * quill.w)
		spikes.set_instance_transform(ns, GrieverLook.between(base, tip, quill.w * 0.12, up))
		spikes.set_instance_color(ns, STEEL_DARK)
		ns += 1
	bars.visible_instance_count = nb
	drums.visible_instance_count = nd
	spikes.visible_instance_count = ns


func _bar(bars: MultiMesh, n: int, a: Vector3, b: Vector3, thick: float, side: Vector3, colour: Color) -> int:
	bars.set_instance_transform(n, GrieverLook.between(a, b, thick, side))
	bars.set_instance_color(n, colour)
	return n + 1


const STEEL := Color(0.3, 0.31, 0.33)
const STEEL_DARK := Color(0.19, 0.2, 0.22)
const CHROME := Color(0.55, 0.57, 0.6)
const BRASS := Color(0.36, 0.3, 0.2)
const HINGE := Color(0.14, 0.14, 0.15)
const CLAW := Color(0.12, 0.11, 0.1)
const STING := Color(0.1, 0.08, 0.08)
## Quills in the lump: a direction from its middle and how long.
const QUILLS: Array[Vector4] = [
	Vector4(0.0, 1.0, -0.5, 0.55), Vector4(0.25, 1.0, -0.1, 0.45), Vector4(-0.25, 1.0, 0.0, 0.5),
	Vector4(0.1, 1.0, 0.35, 0.4), Vector4(-0.5, 0.8, -0.4, 0.38), Vector4(0.55, 0.75, 0.25, 0.4),
	Vector4(-0.6, 0.7, 0.4, 0.35), Vector4(0.45, 0.9, -0.6, 0.35),
]

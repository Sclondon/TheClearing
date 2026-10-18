class_name MazeBrachiosaurus
extends MazeEnemy
## A brachiosaurus out past the square maze: a gentle giant, 13 m tall, that
## roams the desert ring and the wide halls of the round sections, browsing at
## the walls. It is drawn and moved by Brachiosaurus
## (creatures/brachiosaurus/brachiosaurus.gd); this is what it thinks.
##
## ROAMING. It walks slowly (`walk_speed`) from one place to the next in its
## own part of the world (its quarter of the desert, between the great walls,
## or along the rows of a round section with wide halls), and stands a long
## while at each, browsing on what grows on the wall there (its neck stretched
## up to it, nibbling) or, out in the open, gazing about. Now and then it
## bellows, and it rumbles. It hunts nobody and never chases; someone near it
## it watches, its head coming down to look at them, and it walks on.
## THE DANGER is only its feet. Each foot is lifted high and slowly, a dark
## spot on the ground under it showing where it will come down, darkening as it
## comes (Brachiosaurus.foot_shadows); the ground shakes for anyone near as it
## comes (a little camera shake, more the nearer); whoever is on that spot when
## the foot comes down is crushed (thrown down limp) and `caught`. Out from
## under it, or between its legs and clear of the spots, nobody is hurt. Its
## legs are solid; its belly is high over a boy's head.
##
## Far from everyone it is drawn with its low model and posed only every few
## frames (it is meant to be seen from far off: a landmark that is alive).
##
## As a puppet it follows the host's news like the others; its stride (where in
## its gait it is) comes as its flag, so that its feet come down where and when
## the host's do; its bellows come as a count in its state.

enum Mode { ROAM, BROWSE, GAZE, FLEE }

## Where its legs stand, from its middle (fore, hind: x out, z along), m.
const LEGS := [Vector2(1.0, 2.62), Vector2(1.0, -2.22)]

@export var walk_speed := 1.1
@export var flee_speed := 2.4
## How fast it turns (rad/s).
@export var turn_rate := 0.22
@export var acceleration := 0.6
## How long it stands at a place (from, to), seconds.
@export var stay_time := Vector2(14.0, 34.0)
## How far round it someone is watched (m).
@export var watch_range := 22.0
## How near the middle of a foot coming down someone must be to be crushed (past its sole, m).
@export var crush_margin := 0.35
## How far off its footfalls shake the camera (m), and how hard at most (m of shake).
@export var shake_range := 45.0
@export var shake_strength := 0.16
## How often it bellows (from, to), seconds.
@export var bellow_every := Vector2(45.0, 110.0)

var mode := Mode.ROAM
var facing_yaw := 0.0
var brach: Brachiosaurus
## Where it is going, and what it is browsing (INF: nothing).
var goal_point := Vector3.INF
var browse_at := Vector3.INF
## Who it is watching (null: nobody).
var watched: Node3D

## Its part of the world: the desert quarter it is in (a side, or zero), or the
## round section and row it is in.
var _quarter := Vector2i.ZERO
var _ring: RoundMaze.Ring
var _row := -1
var _cell := -1
var _round_way := 1
var _stay_left := 0.0
var _bellow_in := 20.0
var _bellows := 0
var _heard_bellows := -1
var _crushed: Array = []
var _colliders: Array[CollisionShape3D] = []
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _look_left := 0.0
var _stuck := 0.0
var _phase_heard := -1.0
## (as a puppet) whom the host says it watches.
var _heard_watch := Vector3.INF

## The camera's shake, shared by all of them (one camera): how much now, and which frame it was last laid on.
static var _shake := 0.0
static var _shaken_frame := -1
static var _shaking := false


func _init() -> void:
	sight_range = 0.0
	hear_range = 0.0
	memory = 1.0
	alert_range = 0.0
	pack = &"brachiosaurs"
	look_every = 0.3
	spare_time = 4.0


## `count` places to put them, from the maze's seed: out in the desert's
## quarters in turn, then in the wide-halled round sections; [] if the maze has
## no desert.
static func spots(plan: Maze, count: int, seed_value: int) -> Array[Vector3]:
	var made: Array[Vector3] = []
	var outer := plan.round_rings
	if outer == null or count <= 0:
		return made
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sides: Array[Vector2] = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	var wide: Array = []
	for ring: RoundMaze.Ring in outer.rings:
		if ring.style.hallway_diameter_cells >= 2:
			wide.append(ring)
	var first := rng.randi_range(0, 3)
	for k in count:
		var at := Vector3.INF
		if k % 3 == 2 and not wide.is_empty():
			var ring: RoundMaze.Ring = wide[rng.randi_range(0, wide.size() - 1)]
			var row := rng.randi_range(0, ring.rows.size() - 1)
			var cells: int = ring.rows[row][2]
			var j := rng.randi_range(0, cells - 1)
			at = _round_point(ring, row, j)
		else:
			var side := sides[(first + k) % 4]
			var a := side.angle() + rng.randf_range(-0.42, 0.42)
			var near := outer.square_half / maxf(absf(cos(a)), absf(sin(a))) + 45.0
			var r := rng.randf_range(near, maxf(near + 1.0, outer.inner_radius - 35.0))
			at = Vector3(cos(a) * r, 0.0, sin(a) * r)
		at.y = plan.ground_height(at)
		made.append(at)
	return made


## The middle of cell `j` of row `row` of `ring`, on the ground (y 0).
static func _round_point(ring: RoundMaze.Ring, row: int, j: int) -> Vector3:
	var cells: int = ring.rows[row][2]
	var radius: float = (ring.rows[row][0] + ring.rows[row][1]) * 0.5
	var a := (RoundMaze.angle_of(j, cells) + RoundMaze.angle_of(j + 1, cells)) * 0.5
	return Vector3(cos(a) * radius, 0.0, sin(a) * radius)


func _ready() -> void:
	collision_layer = 0 if puppet else 4
	collision_mask = 1
	# (a column for each leg, from above the ground to its belly: under it, between them, is open)
	for leg: Vector2 in LEGS:
		for side: float in [1.0, -1.0]:
			var shape := CylinderShape3D.new()
			shape.radius = 0.5
			shape.height = 3.2
			var collider := CollisionShape3D.new()
			collider.shape = shape
			collider.set_meta(&"at", Vector3(leg.x * side, 2.4, leg.y))
			add_child(collider)
			_colliders.append(collider)
	brach = Brachiosaurus.new()
	brach.low_poly = Settings.low_poly
	brach.foot_shadows = true
	add_child(brach)
	brach.top_level = true
	if maze:
		brach.ground_at = func(x: float, z: float) -> float: return maze.ground_height(Vector3(x, 0.0, z))
	brach.footfall.connect(_on_footfall)
	facing_yaw = rotation.y
	rotation = Vector3.ZERO
	_find_place()
	_prev_pos = global_position
	_curr_pos = global_position
	_turn_colliders()
	brach.global_position = global_position
	brach.rotation = Vector3(0.0, facing_yaw, 0.0)
	brach.settle()
	_stay_left = _rng.randf_range(2.0, 8.0)
	_bellow_in = _rng.randf_range(bellow_every.x * 0.3, bellow_every.y)
	mode = Mode.BROWSE


## Works out its part of the world from where it is.
func _find_place() -> void:
	var outer := maze.round_rings if maze else null
	if outer == null:
		return
	var p := Vector2(global_position.x, global_position.z)
	var r := p.length()
	if r < outer.inner_radius and maxf(absf(p.x), absf(p.y)) > outer.square_half:
		_quarter = DesertStyle.quarter_at(p.x, p.y)
		return
	for ring: RoundMaze.Ring in outer.rings:
		for i in ring.rows.size():
			if r >= ring.rows[i][0] and r < ring.rows[i][1]:
				_ring = ring
				_row = i
				_cell = RoundMaze.cell_at(p.angle(), ring.rows[i][2])
				return


# --- Thinking ---

func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		_stand_on_ground()
		_prev_pos = _curr_pos
		_curr_pos = global_position
		_turn_colliders()
		return
	if maze == null:
		return
	_sense(delta)
	_look_left -= delta
	if _look_left <= 0.0:
		_look_left = look_every
		watched = _nearest_watched()
	_bellow_in -= delta
	if _bellow_in <= 0.0:
		_bellow_in = _rng.randf_range(bellow_every.x, bellow_every.y)
		_bellows += 1
		if _rng.randf() < 0.65:
			brach.bellow()
		else:
			brach.rumble()
	var wish := Vector3.ZERO
	var speed := 0.0
	if threat and is_instance_valid(threat) and not threat.dead:
		mode = Mode.FLEE
		wish = global_position - threat.global_position
		speed = flee_speed
	elif mode == Mode.FLEE:
		mode = Mode.ROAM
		goal_point = _next_goal()
	match mode:
		Mode.ROAM:
			browse_at = Vector3.INF
			if not goal_point.is_finite():
				goal_point = _next_goal()
			var to := goal_point - global_position
			to.y = 0.0
			if to.length() < 3.0 or _stuck > 6.0:
				_stuck = 0.0
				_arrive()
			else:
				wish = to
				speed = walk_speed
		Mode.BROWSE, Mode.GAZE:
			_stay_left -= delta
			if _stay_left <= 0.0:
				mode = Mode.ROAM
				goal_point = _next_goal()
	_move(wish, speed, delta)


## Someone on the ground near it it can see (the nearest), or null.
func _nearest_watched() -> Node3D:
	var best: Node3D = null
	var nearest := watch_range
	for player: Node3D in players():
		if not _can_hurt(player):
			continue
		var apart := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
		if apart < nearest:
			nearest = apart
			best = player
	return best


## Whether `player` is one it could tread on now (anywhere, in the maze or out of it).
func _can_hurt(player: Node3D) -> bool:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return false
	if player is MazeEnemy or player.get(&"escaped") == true or player.get(&"is_limp") == true:
		return false
	return not (_spared.has(player) and _spared[player] > 0.0) and not player in _crushed


## It has got where it was going: it browses at a wall if there is one near enough, or stands and gazes.
func _arrive() -> void:
	_stay_left = _rng.randf_range(stay_time.x, stay_time.y)
	var wall := _nearest_wall()
	if wall.is_finite() and Vector2(wall.x - global_position.x, wall.z - global_position.z).length() < 16.0:
		mode = Mode.BROWSE
		browse_at = wall + Vector3.UP * _rng.randf_range(11.5, 13.5)
	else:
		mode = Mode.GAZE
		browse_at = Vector3.INF


## Somewhere next to go in its part of the world.
func _next_goal() -> Vector3:
	var outer := maze.round_rings
	if outer == null:
		return global_position
	var goal := global_position
	if _ring:
		# Along its row, a few cells on (going on the way it was going), through the joined cells.
		var cells: int = _ring.rows[_row][2]
		var at := _cell
		if _rng.randf() < 0.25:
			_round_way = -_round_way
		for step in _rng.randi_range(1, 3):
			var next := posmod(at + _round_way, cells)
			if not RoundMaze.joined(_ring, Vector2i(_row, at), Vector2i(_row, next)):
				_round_way = -_round_way
				next = posmod(at + _round_way, cells)
				if not RoundMaze.joined(_ring, Vector2i(_row, at), Vector2i(_row, next)):
					break
			at = next
		_cell = at
		goal = _round_point(_ring, _row, at)
	elif _quarter != Vector2i.ZERO:
		# Somewhere else in its quarter: well in from the walls round it, often near enough one to browse.
		var side := Vector2(_quarter.x, _quarter.y)
		for attempt in 8:
			var a := side.angle() + _rng.randf_range(-0.5, 0.5)
			var near := outer.square_half / maxf(absf(cos(a)), absf(sin(a))) + 30.0
			var far := outer.inner_radius - 14.0
			var r := far if _rng.randf() < 0.4 else _rng.randf_range(near, maxf(near + 1.0, far))
			var p := Vector2(cos(a), sin(a)) * r
			if _off_diagonals(p) > 22.0 and p.distance_to(Vector2(global_position.x, global_position.z)) > 25.0:
				goal = Vector3(p.x, 0.0, p.y)
				break
	goal.y = maze.ground_height(goal)
	return goal


## How far a point is from the nearest of the great walls across the desert.
static func _off_diagonals(p: Vector2) -> float:
	var off := INF
	for a: float in RoundMaze.DIAGONALS:
		var along := Vector2(cos(a), sin(a))
		if p.dot(along) > 0.0:
			off = minf(off, absf(p.cross(along)))
	return off


## The nearest point on the face of a wall near it (at the ground), or INF.
func _nearest_wall() -> Vector3:
	var outer := maze.round_rings
	if outer == null:
		return Vector3.INF
	var p := Vector2(global_position.x, global_position.z)
	var r := p.length()
	var best := Vector2.INF
	var walls: Array[float] = []
	if _ring:
		walls = [_ring.rows[_row][0], _ring.rows[_row][1]]
	else:
		walls = [outer.inner_radius]
	for radius in walls:
		var face := radius + (2.5 if radius < r else -2.5)
		var on := p.normalized() * face
		if best == Vector2.INF or on.distance_to(p) < best.distance_to(p):
			best = on
	if not _ring:
		for a: float in RoundMaze.DIAGONALS:
			var along := Vector2(cos(a), sin(a))
			if p.dot(along) <= 0.0:
				continue
			var on := along * p.dot(along)
			on += (p - on).normalized() * 3.0
			if on.distance_to(p) < best.distance_to(p):
				best = on
	return Vector3(best.x, 0.0, best.y)


## Goes the way it faces (turning no faster than it can) towards `wish`.
func _move(wish: Vector3, speed: float, delta: float) -> void:
	wish.y = 0.0
	if wish.length() > 0.01:
		wish = wish.normalized()
		var off := angle_difference(facing_yaw, atan2(wish.x, wish.z))
		facing_yaw += clampf(off, -turn_rate * delta, turn_rate * delta)
	var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	# (it walks on only once it is facing near enough the way: turning first, on the spot)
	var target := forward * speed * smoothstep(0.2, 0.75, forward.dot(wish)) if wish != Vector3.ZERO else Vector3.ZERO
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, acceleration * delta)
	velocity = current
	_turn_colliders()
	var was := global_position
	move_and_slide()
	_stand_on_ground()
	if speed > 0.0 and target.length() > 0.3 and (global_position - was).length() < target.length() * delta * 0.3:
		_stuck += delta
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _stand_on_ground() -> void:
	if maze:
		global_position.y = maze.ground_height(global_position)


func _turn_colliders() -> void:
	var turned := Basis(Vector3.UP, facing_yaw)
	for collider in _colliders:
		collider.position = turned * (collider.get_meta(&"at") as Vector3)


# --- Its feet ---

## A foot has come down at `at`: whoever is under it is crushed; the ground shakes for this machine's player.
func _on_footfall(at: Vector3, weight: float) -> void:
	_shake_for(at, weight)
	if puppet or dead:
		return
	var soles := brach.sole()
	var radius := maxf(soles.x, soles.y) + crush_margin
	for player: Node3D in players():
		if not _can_hurt(player):
			continue
		var p := player.global_position
		if Vector2(p.x - at.x, p.z - at.z).length() < radius and absf(p.y - at.y) < 1.6:
			_crush(player, at)


func _crush(player: Node3D, at: Vector3) -> void:
	_crushed.append(player)
	if player is Player and is_instance_valid(player):
		# Knocked flat, out from under it.
		var out := player.global_position - at
		out.y = 0.0
		out = out.normalized() if out.length() > 0.01 else Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
		(player as Player).ragdoll((out * 0.6 + Vector3.DOWN * 0.4).normalized() * 40.0)
		get_tree().create_timer(1.2).timeout.connect(_crushed_down.bind(player))
	else:
		_crushed.erase(player)
		_catch(player)


func _crushed_down(player: Node3D) -> void:
	_crushed.erase(player)
	if not is_instance_valid(player):
		return
	if player is Player and (player as Player).is_limp:
		(player as Player).recover()
	_catch(player)


## Shakes this machine's camera, the more the nearer its player is to where the foot came down.
func _shake_for(at: Vector3, weight: float) -> void:
	var me := _local_player()
	if me == null:
		return
	var apart := me.global_position.distance_to(at)
	if apart > shake_range:
		return
	var near := 1.0 - apart / shake_range
	_shake = maxf(_shake, near * near * minf(weight, 1.0) * shake_strength)


func _local_player() -> Node3D:
	for player: Node in get_tree().get_nodes_in_group(&"maze_players"):
		if player is Player and not player.is_in_group(&"runners"):
			return player
	return null


## Lays the shake on the camera, once a frame for all of them, dying away.
static func _lay_shake(tree: SceneTree, delta: float) -> void:
	var frame := Engine.get_process_frames()
	if frame == _shaken_frame:
		return
	_shaken_frame = frame
	var camera := tree.root.get_viewport().get_camera_3d()
	if camera == null:
		return
	if _shake > 0.002:
		_shaking = true
		var t := Time.get_ticks_msec() * 0.001
		camera.v_offset = sin(t * 47.0) * _shake + sin(t * 31.0) * _shake * 0.5
		camera.h_offset = sin(t * 39.0 + 1.0) * _shake * 0.4
		_shake = move_toward(_shake * exp(-6.0 * delta), 0.0, 0.01 * delta)
	elif _shaking:
		_shaking = false
		_shake = 0.0
		camera.v_offset = 0.0
		camera.h_offset = 0.0


# --- What it looks like ---

func _process(delta: float) -> void:
	_lay_shake(get_tree(), delta)
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-4.0 * delta))
		if _phase_heard >= 0.0 and brach.rig:
			# (its stride kept with the host's, so that its feet come down where the host's do)
			var off := angle_difference(brach.rig._phase * TAU, _phase_heard * TAU) / TAU
			brach.rig._phase = fposmod(brach.rig._phase + off * minf(1.0, 3.0 * delta), 1.0)
			_phase_heard = fposmod(_phase_heard + brach.rig._pace / BrachiosaurusRig._keyed(BrachiosaurusRig.STRIDE, brach.rig._pace) * delta, 1.0)
	brach.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	brach.rotation = Vector3(0.0, facing_yaw, 0.0)
	brach.browse_point = browse_at if mode == Mode.BROWSE else Vector3.INF
	var look := _heard_watch if puppet else Vector3.INF
	if is_instance_valid(watched):
		look = watched.global_position + Vector3.UP * 1.2
	brach.look_at_point = look
	# (posed less often the further it is from the camera)
	var camera := get_viewport().get_camera_3d()
	var apart := camera.global_position.distance_to(global_position) if camera else 0.0
	brach.pose_every = 1 if apart < 60.0 else (2 if apart < 120.0 else 3)


func goal() -> Vector3:
	return global_position


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


## Its mode (low four bits) and bellows (high four).
func net_state() -> int:
	return mode | ((_bellows & 15) << 4)


## Where it is in its stride (0..255).
func net_flag() -> int:
	return int(brach.rig._phase * 256.0) & 0xff if brach and brach.rig else 0


## What it browses, or else whom it watches.
func net_point() -> Vector3:
	if mode == Mode.BROWSE and browse_at.is_finite():
		return browse_at
	return watched.global_position + Vector3.UP * 1.2 if is_instance_valid(watched) else Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = (state & 15) as Mode
	var bellows := (state >> 4) & 15
	if _heard_bellows >= 0 and bellows != _heard_bellows and brach:
		brach.bellow()
	_heard_bellows = bellows
	_phase_heard = flag / 256.0
	browse_at = point if mode == Mode.BROWSE else Vector3.INF
	watched = null
	_heard_watch = point if mode != Mode.BROWSE else Vector3.INF




func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if brach:
		brach.global_position = at
		brach.settle()


func _puppet_changed() -> void:
	collision_layer = 0 if puppet else 4

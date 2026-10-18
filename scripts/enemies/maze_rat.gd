class_name MazeRat
extends MazeEnemy
## A rat, one of a little group of them (a mischief) that goes about the maze:
## wildlife, harmless alone. It is drawn and moved by Rat (creatures/rats/);
## this is what it thinks.
##
## - ALONG THE WALLS. The group scurries along the foot of a wall, in short
##   dashes and stops, its leader choosing where (a cell a few away, MazeNav)
##   and the rest following in a line behind it; stopped, one sniffs about or
##   rears up on its haunches to sniff the air.
## - SCAVENGING. Now and then (`appetite` fills over a minute or two; or, with
##   the world's own life, Ecology, when it is hungry) the leader makes for the
##   nearest carcass within a few cells (anything in the group `fly_carrion`
##   that is not a living hunter: the carcasses in the dead ends, and those the
##   hunters leave), and they gather round it gnawing, heads down, for a while.
## - FLEEING. A player near (`flee_range`, or further, `run_range`, if they are
##   running), a fire, or a meat-eater that would eat it (Ecology's `threat`),
##   and it squeaks and bolts (`flee_speed`), away down the passages along the
##   wall foot, the rest of the group with it; once it is well away it stops,
##   rears up to look back, and goes on with what it was doing.
##
## It catches nobody. It is a tiny body that nothing bumps into (it is on no
## physics layer), but it runs over the ground and is stopped by the walls.
## With Ecology it is small prey (size 0): the meat-eaters may hunt it.
##
## `MazeRat.mischief(count, seed)` makes a group (each a little different in
## size and shade); its rats are told apart by `pack_id`. As a puppet it
## follows the host's news: where it is, how it is going, what it is doing
## (`net_state`), and whether it is reared up or gnawing (`net_flag`).

enum Mode { SCURRY, PAUSE, FEED, FLEE }

@export var dash_speed := 2.4
@export var flee_speed := 4.3
@export var flee_range := 6.0
## A player running is fled from as far off as this.
@export var run_range := 11.0
## How far from a carcass, by the passages (cells), it will go to it.
@export var carrion_cells := 3
## How long a group gnaws at a carcass, seconds.
@export var feed_time := 28.0
## Which group it is in (the same for all of a group, on every machine).
@export var pack_id := 0
@export var size := 1.0
@export var own := 0.5
@export var gravity := 20.0

var mode := Mode.SCURRY
var rat: Rat
## How much it wants to eat (0 to 1: a full one, at 1 it goes looking), without the world's own life.
var appetite := 0.0
## The carcass it is making for or at (null: none).
var carrion: Node3D

var _timer := 0.0
var _dash := 0.0
var _flee_from := Vector3.INF
var _wall_side := 1.0
var _wall_in := 0.0
var _wall_pull := 0.0
var _hungry_rate := 0.0
var _look_carrion := 0.0
var _feed_spot := Vector3.ZERO
var _stuck := 0.0
var _away_in := 0.0
var _away_at := Vector3.INF
var _unstick := 0.0
var _unstick_way := Vector3.ZERO


## A group of `count`, ready to be placed: each its own size and shade, all the same `pack_id`.
static func mischief(count: int, seed_value := 0) -> Array[MazeRat]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var made: Array[MazeRat] = []
	var id := absi(seed_value) % 1000000 + 1
	for i in count:
		var one := MazeRat.new()
		one.pack_id = id
		one.size = rng.randf_range(0.85, 1.12)
		one.own = rng.randf()
		made.append(one)
	return made


func _init() -> void:
	sight_range = 16.0
	hear_range = 8.0
	memory = 3.0
	pack = &"rats"
	look_every = 0.3
	keep_out_of_clearing = true


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0 if puppet else 1
	floor_snap_length = 0.2
	var shape := SphereShape3D.new()
	shape.radius = 0.06 * size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.06 * size
	add_child(collider)
	rat = Rat.new()
	rat.size = size
	rat.own = own
	rat.low_poly = Settings.low_poly
	rat.facing = rotation.y
	add_child(rat)
	rotation = Vector3.ZERO
	_hungry_rate = 1.0 / _rng.randf_range(60.0, 140.0)
	appetite = _rng.randf_range(0.0, 0.9)
	_wall_side = 1.0 if _rng.randf() < 0.5 else -1.0
	_dash = _rng.randf_range(0.5, 2.0)


## The others of its group (not itself).
func mates() -> Array[MazeRat]:
	var found: Array[MazeRat] = []
	if not is_inside_tree():
		return found
	for other: Node in get_tree().get_nodes_in_group(&"rats"):
		if other != self and other is MazeRat and (other as MazeRat).pack_id == pack_id and not _is_dead(other):
			found.append(other)
	return found


## Its leader: the first of its group in the scene still living (who chooses where they go).
func leader() -> MazeRat:
	var first: MazeRat = self
	for mate in mates():
		if mate.get_index() < first.get_index():
			first = mate
	return first


func _physics_process(delta: float) -> void:
	if puppet:
		_follow_news(delta)
		return
	if maze == null:
		return
	_sense(delta)
	_timer -= delta
	_wall_in -= delta
	_look_carrion -= delta
	_away_in -= delta
	# (with the world's own life it gets hungry by that too: see `_hunger`)
	appetite = minf(appetite + _hungry_rate * delta, 1.0)
	# (once running, it runs until they are well off)
	var danger := _danger(1.8 if mode == Mode.FLEE else 1.0)
	if danger.is_finite():
		if mode != Mode.FLEE:
			_bolt(danger)
			for mate in mates():
				if mate.global_position.distance_to(global_position) < 10.0:
					mate._bolt(danger)
		_flee_from = danger
	var head := leader()
	var wish := Vector3.ZERO
	var pace := 0.0
	match mode:
		Mode.FLEE:
			wish = _toward(_away(_flee_from))
			pace = flee_speed
			if not danger.is_finite() and _timer <= 0.0:
				# (well away: it stops and rears up to look back)
				mode = Mode.PAUSE
				_timer = _rng.randf_range(1.2, 2.4)
				rat.rear = 1.0
		Mode.PAUSE:
			if _timer <= 0.0:
				rat.rear = 0.0
				mode = Mode.SCURRY
				_dash = _rng.randf_range(0.6, 2.0)
		Mode.FEED:
			if carrion == null or not is_instance_valid(carrion) or not carrion.is_inside_tree():
				_done_feeding()
			else:
				var to := _feed_spot - global_position
				to.y = 0.0
				if to.length() > 0.15:
					wish = _toward(_feed_spot)
					pace = 1.2
					rat.feeding = false
				else:
					rat.feeding = true
					# (a shuffle now and then, round the carcass)
					if _rng.randf() < delta * 0.4:
						_feed_spot = _round(carrion)
				if _timer <= 0.0:
					_done_feeding()
		Mode.SCURRY:
			_dash -= delta
			if head == self:
				_find_carrion()
				if carrion:
					wish = _toward(_feed_spot)
					if carrion.global_position.distance_to(global_position) < 2.0:
						_start_feeding()
				else:
					wish = _along_wall(way(0.12))
			else:
				# (behind the leader, in a line along the wall; at the carcass with it)
				if head.mode == Mode.FEED and head.carrion:
					carrion = head.carrion
					_start_feeding()
				else:
					var behind := head.global_position - Vector3(sin(head.rat.facing), 0.0, cos(head.rat.facing)) * (0.4 + 0.35 * (get_index() % 4))
					var to := behind - global_position
					to.y = 0.0
					wish = _along_wall(to) if to.length() > 0.3 else Vector3.ZERO
			pace = dash_speed * (1.15 if head != self else 1.0)
			if _dash <= 0.0:
				# (a stop: a sniff about, or up on its haunches)
				mode = Mode.PAUSE
				_timer = _rng.randf_range(0.5, 2.2)
				rat.rear = 1.0 if _rng.randf() < 0.35 else 0.0
	_move(wish, pace, delta)


# What it should run from, if anything (a point; INF: nothing): a player near (further off if they run), a fire,
# or what would eat it.
func _danger(scale := 1.0) -> Vector3:
	var threat_now: Variant = get(&"threat")
	if threat_now is MazeEnemy and is_instance_valid(threat_now):
		return (threat_now as Node3D).global_position
	for player: Node3D in players():
		if not is_instance_valid(player) or not player.is_inside_tree() or player.get(&"escaped") == true:
			continue
		var apart := player.global_position.distance_to(global_position)
		var moving: Variant = player.get(&"velocity")
		var fast := moving is Vector3 and Vector2((moving as Vector3).x, (moving as Vector3).z).length() > 3.0
		if apart < flee_range * scale or (fast and apart < run_range and nav.sees(global_position + Vector3.UP * 0.3, player.global_position + Vector3.UP, run_range)):
			return player.global_position
	if FireWard.near(get_tree(), global_position):
		for fire: Node in get_tree().get_nodes_in_group(&"fire_wards"):
			if fire is Node3D and (fire as Node3D).global_position.distance_to(global_position) < 8.0:
				return (fire as Node3D).global_position
	return Vector3.INF


## Off it goes, away from `from`, with a squeak.
func _bolt(from: Vector3) -> void:
	if mode == Mode.FLEE:
		return
	mode = Mode.FLEE
	_flee_from = from
	_away_in = 0.0
	_timer = _rng.randf_range(1.5, 2.5)
	rat.rear = 0.0
	rat.feeding = false
	if _rng.randf() < 0.6:
		rat.squeak()


# A place two passages away from `danger` (or one): of those next to it, the
# one furthest from it and not past it, and not behind a wall the plan does not
# know of (a ray, looked again every half second).
func _away(danger: Vector3) -> Vector3:
	if _away_in > 0.0 and _away_at.is_finite():
		return _away_at
	_away_in = 0.5
	var here := maze.cell_at(global_position)
	var best := global_position + (global_position - danger).normalized() * 4.0
	var far := -INF
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 0.12
	var ways: Array[Vector3] = []
	for step: Vector2i in Maze.STEPS:
		if maze.blocked(here, step) or not nav.allowed(here + step):
			continue
		var to := here + step
		if not maze.blocked(to, step) and nav.allowed(to + step):
			to += step
		ways.append(nav.point(to))
	# (and straight along the way it is going, either way: a passage the plan's cells do not show)
	var along := Vector3(sin(rat.facing), 0.0, cos(rat.facing))
	ways.append(global_position + along * 6.0)
	ways.append(global_position - along * 6.0)
	for at: Vector3 in ways:
		var score := at.distance_to(danger) - at.distance_to(global_position) * 0.6
		var way := Vector3(at.x - from.x, 0.0, at.z - from.z).normalized()
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + way * 2.5, 1, [get_rid()]))
		if not hit.is_empty():
			score -= 30.0
		if score > far:
			far = score
			best = at
	_away_at = best
	return best


# Which way to go for `point`, round the walls (level).
func _toward(point: Vector3) -> Vector3:
	# (near it, straight for it: not along the wall)
	var flat := Vector2(point.x - global_position.x, point.z - global_position.z)
	if flat.length() < 2.5 and nav.line_free(global_position, point, 0.0):
		return Vector3(flat.x, 0.0, flat.y).normalized()
	var to := nav.waypoint(global_position, point, MazeNav.clearance_for(0.1)) - global_position
	to.y = 0.0
	return _along_wall(to)


# The way `wish` (level), pulled in towards the foot of the wall on its side so that it runs along it.
func _along_wall(wish: Vector3) -> Vector3:
	if wish.length() < 0.05:
		return Vector3.ZERO
	var ahead := wish.normalized()
	if _wall_in <= 0.0:
		_wall_in = 0.3
		var side := Vector3(-ahead.z, 0.0, ahead.x) * _wall_side
		var from := global_position + Vector3.UP * 0.12
		var space := get_world_3d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + side * 3.0, 1, [get_rid()]))
		if hit.is_empty():
			# (no wall that side: is there one the other?)
			var other := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - side * 3.0, 1, [get_rid()]))
			if not other.is_empty():
				_wall_side = -_wall_side
				hit = other
		_wall_pull = clampf((from.distance_to(hit["position"]) - 0.16) * 0.9, -0.6, 1.2) if not hit.is_empty() else 0.0
	var side_now := Vector3(-ahead.z, 0.0, ahead.x) * _wall_side
	return (ahead + side_now * _wall_pull).normalized()


func _move(wish: Vector3, pace: float, delta: float) -> void:
	if _unstick > 0.0:
		# (caught in a corner a moment ago: off another way for a moment)
		_unstick -= delta
		wish = _unstick_way
	var want := wish * pace
	var grip := 14.0 if pace > 0.1 else 9.0
	velocity.x = move_toward(velocity.x, want.x, grip * delta * maxf(pace, 2.0))
	velocity.z = move_toward(velocity.z, want.z, grip * delta * maxf(pace, 2.0))
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	if global_position.y < maze.ground_height(global_position) - 2.0:
		global_position.y = maze.ground_height(global_position) + 0.1
	var real := get_real_velocity()
	if pace > 0.5 and wish.length() > 0.1 and Vector2(real.x, real.z).length() < pace * 0.3:
		_stuck += delta
		if _stuck > 0.35:
			_stuck = 0.0
			_unstick = _rng.randf_range(0.35, 0.7)
			_wall_side = -_wall_side
			_unstick_way = wish.rotated(Vector3.UP, PI * _rng.randf_range(0.5, 0.8) * (1.0 if _rng.randf() < 0.5 else -1.0))
	else:
		_stuck = 0.0
	rat.global_position = global_position
	rat.step(real if real.length() < velocity.length() else velocity, delta)


# --- Carcasses ---

# How much it wants to eat: its own appetite, or the world's hunger (Ecology's, when there is one) if that is more.
func _hunger() -> float:
	var world_hunger: Variant = get(&"hunger")
	return maxf(world_hunger, appetite) if world_hunger is float else appetite


func _find_carrion() -> void:
	if carrion and is_instance_valid(carrion) and carrion.is_inside_tree():
		return
	carrion = null
	if _look_carrion > 0.0:
		return
	_look_carrion = 4.0
	if _hunger() < 0.6:
		return
	var here := maze.cell_at(global_position)
	var best_steps := carrion_cells + 1
	for found: Node in get_tree().get_nodes_in_group(&"fly_carrion"):
		if not (found is Node3D) or found is MazeEnemy or not (found as Node3D).is_inside_tree():
			continue
		var at := (found as Node3D).global_position
		if at.distance_to(global_position) > Maze.CELL * (carrion_cells + 1):
			continue
		var steps := nav.distance(here, maze.cell_at(at))
		if steps >= 0 and steps < best_steps:
			best_steps = steps
			carrion = found
	if carrion:
		_feed_spot = _round(carrion)


# A place round the edge of a carcass for it to gnaw at.
func _round(at: Node3D) -> Vector3:
	var reach := float(at.get_meta(&"carrion_radius", 0.8))
	var turn := own * TAU + _rng.randf_range(-0.6, 0.6)
	return at.global_position + Vector3(cos(turn), 0.0, sin(turn)) * reach * _rng.randf_range(0.8, 1.05)


func _start_feeding() -> void:
	if mode == Mode.FEED or carrion == null:
		return
	mode = Mode.FEED
	_timer = feed_time * _rng.randf_range(0.8, 1.2)
	_feed_spot = _round(carrion)
	appetite = 0.0
	if has_method(&"ate"):
		call(&"ate", 0.0)


func _done_feeding() -> void:
	mode = Mode.SCURRY
	carrion = null
	rat.feeding = false
	_look_carrion = 30.0
	_dash = _rng.randf_range(1.0, 2.5)


static func _is_dead(one: Node) -> bool:
	return one.get(&"dead") == true


# --- Being run by someone else ---

func yaw() -> float:
	return rat.facing if rat else 0.0


func net_state() -> int:
	return mode


func net_flag() -> int:
	return (1 if rat and rat.rear > 0.5 else 0) | (2 if rat and rat.feeding else 0)


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	var was := mode
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	if rat:
		rat.rear = 1.0 if flag & 1 else 0.0
		rat.feeding = flag & 2 != 0
		if mode == Mode.FLEE and was != Mode.FLEE and _rng.randf() < 0.6:
			rat.squeak()


func _follow_news(delta: float) -> void:
	if not _heard or rat == null:
		return
	_heard_at += _heard_moving * delta
	var at := global_position.lerp(_heard_at, 1.0 - exp(-8.0 * delta))
	if at.distance_to(_heard_at) > 3.0:
		at = _heard_at
	velocity = (at - global_position) / maxf(delta, 0.001)
	global_position = at
	rat.global_position = at
	rat.step(velocity if velocity.length() > 0.1 else _heard_moving, delta)


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	if rat:
		rat.facing = facing
		rat.global_position = at


func _puppet_changed() -> void:
	collision_layer = 0
	collision_mask = 0 if puppet else 1

class_name MazeHare
extends MazeEnemy
## A brown hare, alone in the open (the clearing's meadow, the halls, the
## desert ring's plains), or one of a pair (`add_hares`) that box now and then.
## It is drawn and moved by Rabbit (creatures/rabbit/rabbit.gd) as a HARE; this
## is what it thinks. It hunts nobody, and is what the meat-eaters eat
## (Ecology: small, it eats plants).
##
## IN ITS FORM (a scrape in the grass where it lies up) it sits hunched, ears
## turning; now and then it goes out to graze round it (`home_range`), and
## comes back to it.
## FROZEN. Someone comes within `wary_range` (in sight, or heard close by): it
## presses itself flat to the ground where it is, ears laid along its back, and
## does not move at all, trusting to not being seen, as they come on.
## FLUSHED. Only when they are nearly on it (`flush_range`), or running at it
## (`rush_range`), or something that would eat it is coming (`threat`), does it
## explode away: flat out at `run_speed` (far faster than anyone can run),
## jinking to one side and the other every second or so (`zig_angle`), for
## `flee_range` metres. Then it sits up (SETTLE), looks back, and makes a new
## form where it is.
## BOXING. A pair (`pair_id`) left alone, now and then, meet, stand up to each
## other and box: a flurry of blows with their forepaws, a few seconds.
##
## In the halls it finds its way by the passages (MazeNav) as the deer do, jinking
## only where the hall is wide enough; out in the desert ring (past the grid) it
## goes over open ground.
##
## As a puppet it follows the host's news like the others.

enum Mode { FORM, GRAZE, FREEZE, BOLT, SETTLE, BOX, GRUNT, CHARGE }

## How fast it moves grazing, and flat out (m/s).
@export var graze_speed := 0.9
@export var run_speed := 13.5
@export var acceleration := 45.0
@export var turn_rate := 10.0
## How near someone may come before it freezes, before it is flushed, and how near someone running at it.
@export var wary_range := 24.0
@export var flush_range := 5.5
@export var rush_range := 12.0
## How far it runs when flushed (m), how often it jinks (s) and how far round (radians).
@export var flee_range := 65.0
@export var zig_every := Vector2(0.45, 1.1)
@export var zig_angle := 0.65
## How far from its form it grazes.
@export var home_range := 10.0
## Further than this from every player it is not drawn; further than `pose_near`, posed only now and then.
@export var view_range := 90.0
@export var pose_near := 15.0
@export var gravity := 24.0
## How it looks (set before it goes in).
@export var coat_tint := Color.WHITE
@export var size := 1.0
## The pair it is one of (0: none). Those of a pair box.
@export var pair_id := 0

var mode := Mode.FORM
var facing_yaw := 0.0
var rabbit: Rabbit

var _radius := 0.12
var _home := Vector3.ZERO
var _plan: Maze
var _mode_left := 0.0
var _goal := Vector3.INF
var _danger: Node3D
var _danger_far := INF
var _watch_in := 0.0
var _point := Vector3.INF
var _calm_for := 0.0
var _flee_way := Vector3.ZERO
var _flee_to := Vector3.INF
var _fled := 0.0
var _zig_in := 0.0
var _zig := 1.0
var _box_in := 0.0
var _partner: MazeHare
var _grunts := 0
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flagged := false

static var _pairs := 0


## Puts a hare (or, with `pair`, two of them that box) at `at` through
## `enemies.add`, run and sent with what hunts. `open` (the clearing): free to
## go where the hunters may not.
static func add_hares(enemies: MazeEnemies, at: Vector3, pair: bool, seed_value: int, open := false) -> Array[MazeHare]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var maze := enemies.maze
	var made: Array[MazeHare] = []
	var id := 0
	if pair:
		_pairs += 1
		id = _pairs * 1000 + (seed_value & 0xff)
	for k in (2 if pair else 1):
		var one := MazeHare.new()
		one.pair_id = id
		one.keep_out_of_clearing = not open
		one.coat_tint = [Color.WHITE, Color(1.04, 0.98, 0.92), Color(0.92, 0.9, 0.88)][rng.randi_range(0, 2)]
		one.size = rng.randf_range(0.94, 1.06)
		var spot := at + (Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-3.0, 3.0)) if k > 0 else Vector3.ZERO)
		spot.y = maze.ground_height(spot)
		var cell := maze.cell_at(spot)
		enemies.add(one, cell, rng.randf_range(-PI, PI), rng.randi(), spot - maze.world(cell) + Vector3.UP * 0.25)
		made.append(one)
	return made


## Where the clearing's hares lie up: out in the open meadow, away from the
## middle and the woods, the marsh and the tall grass: `count` points on the ground.
static func clearing_spots(maze: Maze, count: int, rng: RandomNumberGenerator) -> Array[Vector3]:
	var look := maze.clearing_style
	var spots: Array[Vector3] = []
	var edge := maze.clearing * Maze.CELL * 0.5 - 35.0
	for i in count:
		var spot := Vector3.ZERO
		for attempt in 16:
			var angle := rng.randf_range(-PI, PI)
			spot = Vector3(sin(angle), 0.0, cos(angle)) * rng.randf_range(100.0, 220.0)
			spot.x = clampf(spot.x, -edge, edge)
			spot.z = clampf(spot.z, -edge, edge)
			var flat := Vector2(spot.x, spot.z)
			var marsh := look.marsh_rect() if look else Rect2()
			if marsh.has_area() and marsh.grow(20.0).has_point(flat):
				continue
			if look and (look.tall_grass_at(flat) > 0.0 or _near_woods(look, flat)):
				continue
			if spots.any(func(s: Vector3) -> bool: return s.distance_to(spot) < 60.0):
				continue
			break
		spot.y = maze.ground_height(spot)
		spots.append(spot)
	return spots


static func _near_woods(look: ClearingStyle, flat: Vector2) -> bool:
	var woods := look.entrance(ClearingStyle.Entrance.WOODS)
	return not woods.is_empty() and flat.distance_to(woods[0]) < look.woods_size * 0.6


## Where the desert ring's hares lie up: out on its plains (DesertStyle.Biome), as MazeRabbit.desert_spots.
static func desert_spots(maze: Maze, count: int, rng: RandomNumberGenerator) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for spot: Array in MazeRabbit.desert_spots(maze, count, rng, [DesertStyle.Biome.PLAINS]):
		spots.append(spot[0])
	return spots


func _init() -> void:
	sight_range = 0.0
	hear_range = 0.0
	memory = 4.0
	alert_range = 0.0
	pack = &"hares"
	look_every = 0.2
	spare_time = 1.0


## Which kind it is drawn as (the jackalope says otherwise).
func variant() -> Rabbit.Variant:
	return Rabbit.Variant.HARE


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0 if puppet else 1
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(55.0)
	var shape := CapsuleShape3D.new()
	_radius = 0.12 * size
	shape.radius = _radius
	shape.height = 0.42 * size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.rotation.x = PI * 0.5
	collider.position.y = _radius + 0.02
	add_child(collider)
	rabbit = Rabbit.new()
	rabbit.variant = variant()
	rabbit.coat_tint = coat_tint
	rabbit.low_poly = Settings.low_poly
	rabbit.fur_shells = 0 if Settings.low_poly else 1
	rabbit.scale = Vector3.ONE * size
	add_child(rabbit)
	rabbit.top_level = true
	facing_yaw = rotation.y
	_home = global_position
	_prev_pos = global_position
	_curr_pos = global_position
	rabbit.global_position = global_position
	rabbit.rotation = Vector3(0.0, facing_yaw, 0.0)
	rabbit.settle()
	_mode_left = _rng.randf_range(5.0, 30.0)
	_box_in = _rng.randf_range(25.0, 70.0)
	# (the grass parts round it as it goes through)
	Grass.push(self, 0.35 * size)
	if maze and not maze.inside(maze.cell_at(global_position)):
		_plan = maze
		maze = null


# --- Thinking ---

func _physics_process(delta: float) -> void:
	if puppet:
		_follow_heard(delta)
		_butting(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze:
		_sense(delta)
	_watch_in -= delta
	if _watch_in <= 0.0:
		_watch_in = look_every
		_look_round()
	var wish := Vector3.ZERO
	var speed := 0.0
	_mode_left -= delta
	_box_in -= delta
	match mode:
		Mode.FORM:
			_point = Vector3.INF
			if _danger and _danger_far < wary_range:
				_noticed()
			elif _mode_left <= 0.0:
				mode = Mode.GRAZE
				_mode_left = _rng.randf_range(10.0, 25.0)
				_goal = Vector3.INF
			elif pair_id != 0 and _box_in <= 0.0:
				_start_boxing()
		Mode.GRAZE:
			_point = Vector3.INF
			if _danger and _danger_far < wary_range:
				_noticed()
			elif _mode_left <= 0.0:
				# (back to its form)
				_goal = _home
				var to := _home - global_position
				to.y = 0.0
				if to.length() < 0.5:
					mode = Mode.FORM
					_mode_left = _rng.randf_range(15.0, 40.0)
				else:
					wish = to
					speed = graze_speed * 1.4
			else:
				if not _goal.is_finite() or Vector2(_goal.x - global_position.x, _goal.z - global_position.z).length() < 0.4:
					_goal = Vector3.INF
					if _rng.randf() < 0.02:
						_goal = _wander_spot()
				if _goal.is_finite():
					wish = _goal - global_position
					speed = graze_speed
		Mode.FREEZE:
			_point = _danger.global_position + Vector3.UP * 1.0 if _danger else Vector3.INF
			if _danger == null or _danger_far > wary_range * 1.15:
				_calm_for += delta
				if _calm_for > 4.0:
					mode = Mode.FORM
					_mode_left = _rng.randf_range(10.0, 30.0)
			else:
				_calm_for = 0.0
		Mode.BOLT:
			wish = _run_way(delta)
			speed = run_speed
			_fled += Vector2(velocity.x, velocity.z).length() * delta
			if _fled > flee_range or _mode_left <= 0.0:
				mode = Mode.SETTLE
				_mode_left = _rng.randf_range(3.0, 5.0)
		Mode.SETTLE:
			_point = _danger.global_position + Vector3.UP * 1.0 if _danger else Vector3.INF
			if _mode_left <= 0.0:
				# (a new form, where it stopped)
				_home = global_position
				mode = Mode.FORM
				_mode_left = _rng.randf_range(15.0, 40.0)
		Mode.BOX:
			if _partner == null or not is_instance_valid(_partner) or _partner.mode != Mode.BOX or _danger:
				_stop_boxing()
			else:
				var to := _partner.global_position - global_position
				to.y = 0.0
				_point = _partner.global_position + Vector3.UP * 0.4
				if to.length() > 0.55:
					wish = to
					speed = graze_speed * 2.5
				if _mode_left <= 0.0:
					_stop_boxing()
		Mode.GRUNT, Mode.CHARGE:
			var go := _charging(delta)
			wish = go
			speed = go.length()
	_move(wish, speed, delta)
	_butting(delta)
	_prev_pos = _curr_pos
	_curr_pos = global_position


## Looks out for whoever would frighten it: the nearest player in sight (or heard close by), or what would eat it.
func _look_round() -> void:
	_danger = null
	_danger_far = INF
	var eye := global_position + Vector3.UP * 0.35
	for player: Node3D in players():
		if not is_instance_valid(player) or not player.is_inside_tree() or player.get(&"escaped") == true:
			continue
		var d := eye.distance_to(player.global_position)
		if d < wary_range and d < _danger_far and (d < 5.0 or _in_sight(eye, player.global_position + Vector3.UP)):
			_danger = player
			_danger_far = d
	var hunter: Variant = get(&"threat")
	if hunter is MazeEnemy and is_instance_valid(hunter) and not (hunter as MazeEnemy).get(&"dead"):
		_danger = hunter
		_danger_far = minf(global_position.distance_to((hunter as Node3D).global_position), flush_range * 0.5)
	if _danger and mode in [Mode.FORM, Mode.GRAZE, Mode.FREEZE, Mode.SETTLE, Mode.BOX] and _flushed_by(_danger):
		_flushed()


func _in_sight(eye: Vector3, at: Vector3) -> bool:
	if maze == null:
		return true
	if not maze.inside(maze.cell_at(eye)) or not maze.inside(maze.cell_at(at)):
		return true
	return nav.sees(eye, at, wary_range)


## Whether `who` puts it up: nearly on it, running at it, or something that would eat it.
func _flushed_by(who: Node3D) -> bool:
	if who is MazeEnemy:
		return true
	var to := who.global_position - global_position
	var far := Vector2(to.x, to.z).length()
	if far < flush_range * size:
		return true
	var them: Variant = who.get(&"velocity")
	var moving: Vector3 = them if them is Vector3 else Vector3.ZERO
	var running := Vector2(moving.x, moving.z).length() > 3.4
	var at_it := Vector2(moving.x, moving.z).normalized().dot(Vector2(-to.x, -to.z).normalized()) > 0.5
	return running and at_it and far < rush_range


## Someone is about: it freezes, flat (the jackalope does otherwise).
func _noticed() -> void:
	mode = Mode.FREEZE
	_calm_for = 0.0


## Put up: away, flat out (the jackalope may turn on them instead).
func _flushed() -> void:
	_bolt()


func _bolt() -> void:
	if mode == Mode.BOX:
		_stop_boxing()
	mode = Mode.BOLT
	_fled = 0.0
	_mode_left = flee_range / run_speed * 2.0 + 2.0
	_zig_in = _rng.randf_range(0.2, 0.5)
	_zig = 1.0 if _rng.randf() < 0.5 else -1.0
	var from := _danger.global_position if _danger else global_position - Basis(Vector3.UP, facing_yaw).z
	_flee_way = global_position - from
	_flee_way.y = 0.0
	_flee_way = _flee_way.normalized() if _flee_way.length() > 0.01 else Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	_flee_to = _flee_from(from) if maze and not maze.in_clearing(maze.cell_at(global_position)) else Vector3.INF


## Where to run from `from`, by the passages (as the deer do): the cell a few
## steps off that is furthest from them for how near it is.
func _flee_from(from: Vector3) -> Vector3:
	var here := maze.cell_at(global_position)
	var mine := nav.field(here)
	var theirs := nav.field(maze.cell_at(from))
	var best := Vector3.INF
	var score := -INF
	for i in mine.size():
		var steps := mine[i]
		if steps < 2 or steps > 6:
			continue
		var cell := Vector2i(i % maze.size, i / maze.size)
		var from_them := theirs[i] if theirs[i] >= 0 else 99
		var value := from_them - steps * 0.3 + _rng.randf_range(0.0, 0.5)
		if value > score:
			score = value
			best = maze.world(cell)
	return best


## The way it runs, bolting: away (by the passages in the halls), jinking to one
## side and the other where there is room.
func _run_way(delta: float) -> Vector3:
	_zig_in -= delta
	if _zig_in <= 0.0:
		_zig_in = _rng.randf_range(zig_every.x, zig_every.y)
		_zig = -_zig
	var way := _flee_way
	if _flee_to.is_finite():
		var to := nav.waypoint(global_position, _flee_to, MazeNav.clearance_for(_radius)) - global_position
		to.y = 0.0
		if to.length() < 1.0 and Vector2(_flee_to.x - global_position.x, _flee_to.z - global_position.z).length() < 3.0:
			# (there: on to somewhere further from them)
			_flee_to = _flee_from(_danger.global_position if _danger else global_position - _flee_way * 5.0)
		way = to.normalized() if to.length() > 0.01 else _flee_way
	elif maze:
		# (in the clearing: straight away, kept off its walls)
		var ahead := global_position + way * 6.0
		if not nav.line_free(global_position, ahead, _radius + 0.5) or not maze.inside(maze.cell_at(ahead)):
			way = way.rotated(Vector3.UP, PI * 0.5 * _zig)
			_flee_way = way
	else:
		# (out on the open ground of the desert ring: not too far from where it lives)
		var from_home := global_position - _home
		from_home.y = 0.0
		if from_home.length() > 90.0:
			_flee_way = (_flee_way - from_home.normalized() * 0.6).normalized()
			way = _flee_way
	var jink := way.rotated(Vector3.UP, zig_angle * _zig)
	if maze == null or nav.line_free(global_position, global_position + jink * 3.0, _radius + 0.3):
		way = jink
	return way


func _wander_spot() -> Vector3:
	for attempt in 4:
		var round_about := _rng.randf_range(-PI, PI)
		var spot := _home + Vector3(cos(round_about), 0.0, sin(round_about)) * _rng.randf_range(1.0, home_range)
		if maze == null or nav.line_free(global_position, spot, _radius + 0.4):
			return spot
	return Vector3.INF


func _start_boxing() -> void:
	_box_in = _rng.randf_range(40.0, 100.0)
	for other: Node in get_tree().get_nodes_in_group(pack):
		var mate := other as MazeHare
		if mate == null or mate == self or mate.pair_id != pair_id or mate.puppet:
			continue
		if mate.mode in [Mode.FORM, Mode.GRAZE] and mate.global_position.distance_to(global_position) < 14.0:
			for one: MazeHare in [self, mate]:
				one.mode = Mode.BOX
				one._mode_left = _rng.randf_range(3.5, 6.0)
			_partner = mate
			mate._partner = self
			mate._mode_left = _mode_left
		return


func _stop_boxing() -> void:
	for one: MazeHare in [self, _partner]:
		if one and is_instance_valid(one) and one.mode == Mode.BOX:
			one.mode = Mode.GRAZE
			one._mode_left = _rng.randf_range(4.0, 10.0)
			one._point = Vector3.INF
			one._partner = null
			one._box_in = _rng.randf_range(40.0, 100.0)


## The jackalope's charge (see MazeJackalope); a hare has none.
func _charging(_delta: float) -> Vector3:
	mode = Mode.FORM
	return Vector3.ZERO


## The jackalope's butt (see MazeJackalope); a hare has none.
func _butting(_delta: float) -> void:
	pass


func _move(wish: Vector3, speed: float, delta: float) -> void:
	var grounded := is_on_floor()
	if wish.length() > 0.01:
		wish = Vector3(wish.x, 0.0, wish.z).normalized()
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, acceleration * delta)
	velocity.x = current.x
	velocity.z = current.z
	if not grounded:
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	if current.length() > 0.01 or not grounded:
		move_and_slide()


## Where it is making for, as the world's life sees it (also where it goes
## while out of everyone's sight): away from what would eat it, or its form.
func goal() -> Vector3:
	var hunter: Variant = get(&"threat")
	if hunter is MazeEnemy:
		return super()
	if Vector2(_home.x - global_position.x, _home.z - global_position.z).length() > home_range:
		return _home
	return global_position


# --- What it looks like ---

func _process(delta: float) -> void:
	if rabbit == null:
		return
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > view_range
		if far != _far:
			_far = far
			rabbit.visible = not far
			rabbit.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
			if not far:
				rabbit.settle()
		if near and rabbit.rig:
			var d := near.global_position.distance_to(global_position)
			rabbit.rig.pose_every = 1 if d < pose_near else (2 if d < pose_near * 2.5 else 3)
	if _far:
		return
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-12.0 * delta))
	elif heading.length_squared() > 0.04:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))
	elif _point.is_finite() and mode in [Mode.BOX, Mode.GRUNT, Mode.CHARGE]:
		var to := _point - global_position
		facing_yaw = lerp_angle(facing_yaw, atan2(to.x, to.z), 1.0 - exp(-8.0 * delta))
	rabbit.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	rabbit.rotation = Vector3(0.0, facing_yaw, 0.0)
	rabbit.grounded = is_on_floor() or puppet
	_dress(heading)


## Says to the Rabbit what it is doing.
func _dress(heading: Vector3) -> void:
	rabbit.grazing = mode == Mode.GRAZE and heading.length() < 0.4
	rabbit.flattened = mode == Mode.FREEZE
	rabbit.upright = mode == Mode.SETTLE
	rabbit.alert = mode in [Mode.SETTLE]
	rabbit.boxing = mode == Mode.BOX
	rabbit.flagging = mode == Mode.BOLT
	rabbit.fleeing = mode == Mode.BOLT
	rabbit.lowered = false
	rabbit.look_at_point = _point if mode in [Mode.SETTLE, Mode.FREEZE, Mode.BOX] else Vector3.INF


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Grunts (low two bits).
func net_flag() -> int:
	return _grunts & 3


func net_point() -> Vector3:
	return _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	_point = point
	var grunts := flag & 3
	if not _heard_flagged:
		_heard_flagged = true
	elif rabbit and grunts != (_grunts & 3):
		rabbit.grunt()
	_grunts = grunts


## As a puppet: goes where the host says, carrying on as it was going.
func _follow_heard(delta: float) -> void:
	if not _heard:
		return
	_heard_at += _heard_moving * delta
	var was := global_position
	global_position = global_position.lerp(_heard_at, 1.0 - exp(-12.0 * delta))
	if global_position.distance_to(_heard_at) > 3.0:
		global_position = _heard_at
	velocity = (global_position - was) / maxf(delta, 0.0001)


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if not puppet and mode in [Mode.BOLT, Mode.CHARGE, Mode.GRUNT, Mode.BOX]:
		# (brought back by the world: lying up again where it began)
		_home = at
		mode = Mode.FORM
		_mode_left = _rng.randf_range(10.0, 30.0)
	if rabbit:
		rabbit.global_position = at
		rabbit.settle()


func _puppet_changed() -> void:
	collision_layer = 4
	collision_mask = 0 if puppet else 1

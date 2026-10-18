class_name MazeRabbit
extends MazeEnemy
## A rabbit, one of a colony (`colony_of`) that lives in a warren (RabbitWarren:
## a hummock in the grass, or a bank at the foot of a wall) and grazes round
## it. It is drawn and moved by Rabbit (creatures/rabbit/rabbit.gd); this is
## what it thinks. It hunts nobody: it is the life of the place, and what the
## meat-eaters eat (Ecology: small, it eats plants).
##
## GRAZING, within `graze_range` of its warren, each rabbit on its own: it
## nibbles, hops a little way and nibbles again, sits up to look round, washes
## its face, sits hunched; by day and at dusk only (DayCycle): from an hour
## after sunset to dawn the colony is down its holes.
## WATCHING. Someone comes within `wary_range` (in sight, or heard close by):
## it sits up, ears up, and watches them.
## THE ALARM. Too near (`startle_range`), or running at it (`rush_range`), or
## something that would eat it coming (`threat`): it thumps a hind foot (the
## sound carries) and the whole colony bolts, each for the nearest hole, scuts
## flashing white, and vanishes down it (DIVE).
## DOWN ITS HOLE (UNDER) it is out of sight and out of reach: not drawn, not
## solid, and nothing can hunt it (`escaped`); it does no work at all. After
## `hide_time` it comes up to the mouth of its hole if nobody is within
## `safe_range` (else it waits longer), sits there looking (PEEK), and if all
## is quiet hops out to graze again.
##
## Out in the desert ring (beyond the square maze's grid, where MazeNav does
## not reach) it keeps to open ground by itself: there is no maze to find its
## way through, and it needs none so near its warren.
##
## As a puppet it follows the host's news: what it is doing (and its grazing
## act in its flag) and where it is looking; the thumps come in its flag too.

enum Mode { GRAZE, WATCH, BOLT, DIVE, UNDER, PEEK }
## What it is doing while it grazes.
enum Act { NIBBLE, HOP, SIT_UP, WASH, HUNCH }

## How fast it hops about grazing, and bolts (m/s).
@export var graze_speed := 0.7
@export var run_speed := 7.5
@export var acceleration := 30.0
@export var turn_rate := 9.0
## How near someone may come before it watches them, before it bolts, and how near someone running at it.
@export var wary_range := 15.0
@export var startle_range := 6.5
@export var rush_range := 13.0
## How far from its warren it grazes (m).
@export var graze_range := 7.0
## Seconds down its hole before it comes up to look, and how far off everyone must be for it to come out.
@export var hide_time := Vector2(10.0, 22.0)
@export var safe_range := 16.0
## Seconds it sits at the mouth of its hole before it comes out.
@export var peek_time := Vector2(1.5, 3.0)
## Further than this from every player it is not drawn; further than `pose_near`, posed only now and then.
@export var view_range := 60.0
@export var pose_near := 12.0
@export var gravity := 24.0
## How it looks (set before it goes in; `colony_of` sets them).
@export var coat_tint := Color.WHITE
@export var size := 1.0
## Which colony it is of (those of one colony bolt together).
@export var colony_id := 0

## Its warren (set before it goes in; `add_colony` sets it).
var warren: RabbitWarren
var mode := Mode.GRAZE
var act := Act.NIBBLE
var facing_yaw := 0.0
var rabbit: Rabbit
## Down its hole: out of everyone's reach (MazeEnemy.huntable passes over it).
var escaped := false

var _radius := 0.1
var _home := Vector3.ZERO
var _plan: Maze
var _mode_left := 0.0
var _act_left := 0.0
var _goal := Vector3.INF
var _hole := -1
var _danger: Node3D
var _danger_far := INF
var _watch_in := 0.0
var _point := Vector3.INF
var _calm_for := 0.0
var _thumps := 0
var _dive_from := Vector3.ZERO
var _dive_to := Vector3.ZERO
var _bolt_in := -1.0
var _hurry := true
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flagged := false
var _day: DayCycle
var _layers := Vector2i(4, 1)

static var _colonies := 0


## A colony of `count`, ready to be placed: each its own shade and size.
static func colony_of(count: int, seed_value := 0) -> Array[MazeRabbit]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_colonies += 1
	var tints := [Color.WHITE, Color(1.05, 1.0, 0.95), Color(0.9, 0.9, 0.9), Color(0.96, 0.93, 0.9), Color(1.06, 1.0, 0.92), Color(0.82, 0.8, 0.78)]
	var made: Array[MazeRabbit] = []
	for i in count:
		var one := MazeRabbit.new()
		one.colony_id = _colonies * 1000 + (seed_value & 0xff)
		one.coat_tint = tints[(i + rng.randi_range(0, 5)) % tints.size()]
		# (one or two young ones, smaller)
		one.size = rng.randf_range(0.92, 1.06) if i < count - 1 or count < 4 else rng.randf_range(0.7, 0.8)
		made.append(one)
	return made


## Puts a warren of `kind` at `at` (on the ground) facing `yaw` (a bank's holes
## face that way, its back to the wall behind it) under `enemies`, and a colony
## of `count` grazing round it, put in through `enemies.add`, so that they are
## run and sent with what hunts. `open` (the clearing): free to go where the
## hunters may not.
static func add_colony(enemies: MazeEnemies, at: Vector3, yaw: float, kind: RabbitWarren.Kind, count: int, seed_value: int, open := false) -> RabbitWarren:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var made := RabbitWarren.new()
	made.name = "Warren%d" % enemies.get_child_count()
	made.kind = kind
	made.low_poly = Settings.low_poly
	made.position = at
	made.rotation.y = yaw
	enemies.add_child(made)
	var maze := enemies.maze
	var colony := colony_of(count, rng.randi())
	for k in colony.size():
		var one := colony[k]
		one.warren = made
		one.keep_out_of_clearing = not open
		# (round the warren, in front of a bank)
		var round_about := yaw + (rng.randf_range(-1.2, 1.2) if kind == RabbitWarren.Kind.BANK else rng.randf_range(-PI, PI))
		var spot := at + Vector3(sin(round_about), 0.0, cos(round_about)) * rng.randf_range(made.reach() + 0.6, made.reach() + 3.0)
		spot.y = maze.ground_height(spot)
		var cell := maze.cell_at(spot)
		enemies.add(one, cell, rng.randf_range(-PI, PI), rng.randi(), spot - maze.world(cell) + Vector3.UP * 0.25)
	return made


## Where a bank warren goes in hall `cell`: against the foot of one of its
## walls, in from the middle of the cell, its holes facing out into the hall:
## [where (on the ground), the way its holes face (a yaw)].
static func bank_in_hall(maze: Maze, cell: Vector2i, rng: RandomNumberGenerator) -> Array:
	var walls: Array[Vector2i] = []
	for step: Vector2i in Maze.STEPS:
		if maze.blocked(cell, step):
			walls.append(step)
	if walls.is_empty():
		return [maze.world(cell), rng.randf_range(-PI, PI)]
	var wall: Vector2i = walls[rng.randi_range(0, walls.size() - 1)]
	var nav := MazeNav.new(maze)
	var middle := nav.point(cell)
	var out := Vector3(wall.x, 0.0, wall.y)
	# (its back on the face of the wall's footing)
	var face := maze.world(cell) + out * (Maze.CELL * 0.5 - maze.wall_thick(cell, wall) * 0.5 - MazeBuilder.FOOT.x - 0.05)
	var along := Vector3(out.z, 0.0, -out.x) * rng.randf_range(-2.5, 2.5)
	var at := Vector3(face.x, 0.0, face.z) + along
	if absf(out.x) > 0.5:
		at.z = middle.z + along.z
	else:
		at.x = middle.x + along.x
	at.y = maze.ground_height(at)
	return [at, atan2(-out.x, -out.z)]


## Where the clearing's warrens go: hummocks out in the meadow towards its
## corners and the edges of the woods, well away from the middle where everyone
## wakes and from the ways to the gates, clear of the marsh: [where, yaw] each.
static func clearing_spots(maze: Maze, count: int, rng: RandomNumberGenerator) -> Array:
	var look := maze.clearing_style
	var spots: Array = []
	var edge := maze.clearing * Maze.CELL * 0.5 - 30.0
	for i in count:
		var best := Vector3.ZERO
		for attempt in 16:
			var corner := (i + rng.randi_range(0, 3)) % 4
			var angle := PI * 0.25 + PI * 0.5 * corner + rng.randf_range(-0.35, 0.35)
			var spot := Vector3(sin(angle), 0.0, cos(angle)) * rng.randf_range(115.0, 210.0)
			spot.x = clampf(spot.x, -edge, edge)
			spot.z = clampf(spot.z, -edge, edge)
			best = spot
			var flat := Vector2(spot.x, spot.z)
			var marsh := look.marsh_rect() if look else Rect2()
			if marsh.has_area() and marsh.grow(20.0).has_point(flat):
				continue
			if look and look.tall_grass_at(flat) > 0.0:
				continue
			if spots.any(func(s: Array) -> bool: return (s[0] as Vector3).distance_to(spot) < 40.0):
				continue
			break
		best.y = maze.ground_height(best)
		spots.append([best, rng.randf_range(-PI, PI)])
	return spots


## Where the desert ring's warrens go: hummocks in those of its quarters that
## are `biomes` (DesertStyle.Biome: its plains and its forest), away from the
## walls that part them and from its gates: [where, yaw] each.
static func desert_spots(maze: Maze, count: int, rng: RandomNumberGenerator, biomes: Array = [DesertStyle.Biome.PLAINS, DesertStyle.Biome.FOREST]) -> Array:
	var spots: Array = []
	var desert := maze.desert_style
	var rings := maze.round_rings
	if desert == null or rings == null or count <= 0:
		return spots
	var quarters: Array[Vector2i] = []
	for quarter: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		if desert.biome_of(quarter) in biomes:
			quarters.append(quarter)
	if quarters.is_empty():
		return spots
	var inner := rings.square_half + 45.0
	var outer := rings.inner_radius - 45.0
	for i in count:
		var quarter: Vector2i = quarters[(i + rng.randi_range(0, quarters.size() - 1)) % quarters.size()]
		var way := Vector2(quarter.x, quarter.y)
		var spot := Vector3.ZERO
		for attempt in 12:
			var angle := way.angle() + rng.randf_range(-0.5, 0.5)
			var reach := rng.randf_range(inner, maxf(outer, inner + 1.0))
			spot = Vector3(cos(angle), 0.0, sin(angle)) * reach
			# (out past the square maze's sides, not at its corners where the great walls run)
			if maxf(absf(spot.x), absf(spot.z)) > rings.square_half + 30.0:
				break
		spot.y = maze.ground_height(spot)
		spots.append([spot, rng.randf_range(-PI, PI)])
	return spots


func _init() -> void:
	sight_range = 0.0
	hear_range = 0.0
	memory = 4.0
	alert_range = 0.0
	pack = &"rabbits"
	look_every = 0.25
	spare_time = 1.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0 if puppet else 1
	floor_snap_length = 0.2
	floor_max_angle = deg_to_rad(55.0)
	var shape := CapsuleShape3D.new()
	_radius = 0.09 * size
	shape.radius = _radius
	shape.height = 0.26 * size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.rotation.x = PI * 0.5
	collider.position.y = _radius
	add_child(collider)
	rabbit = Rabbit.new()
	rabbit.variant = Rabbit.Variant.RABBIT
	rabbit.coat_tint = coat_tint
	rabbit.low_poly = Settings.low_poly
	rabbit.fur_shells = 0 if Settings.low_poly else 1
	rabbit.scale = Vector3.ONE * size
	add_child(rabbit)
	rabbit.top_level = true
	facing_yaw = rotation.y
	_home = warren.global_position if warren else global_position
	_prev_pos = global_position
	_curr_pos = global_position
	rabbit.global_position = global_position
	rabbit.rotation = Vector3(0.0, facing_yaw, 0.0)
	rabbit.settle()
	_act_left = _rng.randf_range(0.5, 4.0)
	_day = _find_day()
	# (out past the square maze, there is no maze to find the way through: open ground)
	if maze and not maze.inside(maze.cell_at(global_position)):
		_plan = maze
		maze = null


func _find_day() -> DayCycle:
	var node := get_parent()
	while node:
		var day: Variant = node.get(&"day")
		if day is DayCycle:
			return day
		node = node.get_parent()
	return null


## Whether it is the colony's time to be down its holes (from an hour after sunset to dawn).
func night() -> bool:
	if _day == null or not is_instance_valid(_day):
		return false
	return _day.hour >= DayCycle.SUNSET + 1.0 or _day.hour < DayCycle.DAWN


## The others of its colony.
func colony() -> Array[MazeRabbit]:
	var mates: Array[MazeRabbit] = []
	if not is_inside_tree():
		return mates
	for other: Node in get_tree().get_nodes_in_group(pack):
		if other != self and other is MazeRabbit and (other as MazeRabbit).colony_id == colony_id:
			mates.append(other)
	return mates


# --- Thinking ---

func _physics_process(delta: float) -> void:
	if puppet:
		_follow_heard(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze:
		# (for the world's life: what would eat it)
		_sense(delta)
	_watch_in -= delta
	if _watch_in <= 0.0:
		_watch_in = look_every
		_look_round()
	var wish := Vector3.ZERO
	var speed := 0.0
	_mode_left -= delta
	match mode:
		Mode.GRAZE:
			if night():
				_bolt(0.0, false)
			elif _danger and _danger_far < wary_range:
				_watch()
			else:
				var go := _graze(delta)
				wish = go
				speed = graze_speed if go != Vector3.ZERO else 0.0
		Mode.WATCH:
			_point = _danger.global_position + Vector3.UP * 0.8 if _danger else Vector3.INF
			if _danger == null or _danger_far > wary_range * 1.2:
				_calm_for += delta
				if _calm_for > 2.5:
					mode = Mode.GRAZE
					_point = Vector3.INF
			else:
				_calm_for = 0.0
			if night():
				_bolt(0.0, false)
		Mode.BOLT:
			if _bolt_in > 0.0:
				_bolt_in -= delta
			else:
				var mouth := warren.mouth(_hole) if warren and _hole >= 0 else global_position
				var to := mouth - global_position
				to.y = 0.0
				if to.length() < 0.3 or _mode_left <= 0.0:
					_dive()
				else:
					wish = to
					speed = minf(run_speed if _hurry else graze_speed * 2.2, to.length() * 6.0 + 1.0)
		Mode.DIVE:
			var k := clampf(1.0 - _mode_left / 0.4, 0.0, 1.0)
			global_position = _dive_from.lerp(_dive_to, k)
			velocity = (_dive_to - _dive_from) / 0.4
			if _mode_left <= 0.0:
				_go_under()
			_prev_pos = _curr_pos
			_curr_pos = global_position
			return
		Mode.PEEK:
			_point = _danger.global_position + Vector3.UP * 0.8 if _danger else Vector3.INF
			if (_danger and _danger_far < wary_range) or night():
				_dive()
			elif _mode_left <= 0.0:
				_come_out()
			_prev_pos = _curr_pos
			_curr_pos = global_position
			return
	_move(wish, speed, delta)
	_prev_pos = _curr_pos
	_curr_pos = global_position


## Looks out (a few times a second) for whoever would frighten it: the nearest
## player in sight (or heard close by), or what would eat it (`threat`).
func _look_round() -> void:
	_danger = null
	_danger_far = INF
	var eye := global_position + Vector3.UP * 0.25
	for player: Node3D in players():
		if not is_instance_valid(player) or not player.is_inside_tree() or player.get(&"escaped") == true:
			continue
		var d := eye.distance_to(player.global_position)
		if d < wary_range and d < _danger_far and (d < 4.0 or _in_sight(eye, player.global_position + Vector3.UP)):
			_danger = player
			_danger_far = d
	var hunter: Variant = get(&"threat")
	if hunter is MazeEnemy and is_instance_valid(hunter) and not (hunter as MazeEnemy).get(&"dead"):
		var d := global_position.distance_to((hunter as Node3D).global_position)
		# (something that would eat it is always too near)
		if d < _danger_far + startle_range:
			_danger = hunter
			_danger_far = minf(d, startle_range * 0.5)
	if mode in [Mode.GRAZE, Mode.WATCH] and _danger and _startled_by(_danger):
		_alarm()


func _in_sight(eye: Vector3, at: Vector3) -> bool:
	if maze == null:
		return true
	if not maze.inside(maze.cell_at(eye)) or not maze.inside(maze.cell_at(at)):
		return true
	return nav.sees(eye, at, wary_range)


## Whether `who` frightens it into bolting: too near, running at it, or something that would eat it.
func _startled_by(who: Node3D) -> bool:
	if who is MazeEnemy:
		return true
	var to := who.global_position - global_position
	var far := Vector2(to.x, to.z).length()
	if far < startle_range * size:
		return true
	var them: Variant = who.get(&"velocity")
	var moving: Vector3 = them if them is Vector3 else Vector3.ZERO
	var running := Vector2(moving.x, moving.z).length() > 3.4
	var at_it := Vector2(moving.x, moving.z).normalized().dot(Vector2(-to.x, -to.z).normalized()) > 0.4
	return running and at_it and far < rush_range


## It sits up and watches whoever it has seen.
func _watch() -> void:
	mode = Mode.WATCH
	_calm_for = 0.0
	act = Act.SIT_UP


## It thumps, and every one of its colony out grazing or watching bolts for its hole (after a moment each).
func _alarm() -> void:
	_thumps += 1
	if rabbit:
		rabbit.thump()
	_bolt(0.0)
	for mate in colony():
		if not mate.puppet and mate.mode in [Mode.GRAZE, Mode.WATCH] and mate.global_position.distance_to(global_position) < 30.0:
			mate._bolt(_rng.randf_range(0.08, 0.35) + mate.global_position.distance_to(global_position) * 0.01)


## Makes for the nearest hole, `late` seconds from now.
func _bolt(late: float, flee := true) -> void:
	if warren == null or warren.hole_count() == 0:
		_go_under()
		return
	mode = Mode.BOLT
	_bolt_in = late
	_hurry = flee
	_hole = warren.nearest_hole(global_position)
	# (if it cannot get there in this long, it goes under where it is: lost in the grass)
	_mode_left = late + 5.0
	_point = Vector3.INF
	if not flee:
		# (going home at dusk, it hops)
		_bolt_in = late + _rng.randf_range(0.0, 3.0)


## Down the hole: along the tunnel from its mouth, out of sight.
func _dive() -> void:
	mode = Mode.DIVE
	_mode_left = 0.4
	collision_mask = 0
	_dive_from = global_position
	if warren and _hole >= 0:
		_dive_to = warren.deep(_hole)
		facing_yaw = atan2(warren.way_in(_hole).x, warren.way_in(_hole).z)
	else:
		_dive_to = global_position + Vector3.DOWN * 0.3


## Out of sight down its hole: hidden, not solid, out of reach, and doing nothing until it comes up.
func _go_under() -> void:
	mode = Mode.UNDER
	escaped = true
	visible = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	quarry = null
	if rabbit:
		rabbit.visible = false
	set_physics_process(false)
	set_process(false)
	_wait_under(_rng.randf_range(hide_time.x, hide_time.y))


func _wait_under(seconds: float) -> void:
	if not is_inside_tree():
		return
	get_tree().create_timer(seconds, false, true).timeout.connect(_come_up)


## Time to look out: if nobody is near (and it is not night) it comes up to the mouth of its hole.
func _come_up() -> void:
	if not is_instance_valid(self) or not is_inside_tree() or mode != Mode.UNDER or puppet or get(&"dead") == true:
		return
	if process_mode == Node.PROCESS_MODE_DISABLED or night():
		_wait_under(_rng.randf_range(8.0, 16.0))
		return
	var near := nearest_player(global_position)
	if near and near.global_position.distance_to(global_position) < safe_range:
		_wait_under(_rng.randf_range(5.0, 10.0))
		return
	var hunter: Variant = get(&"threat")
	if hunter is MazeEnemy and is_instance_valid(hunter):
		_wait_under(_rng.randf_range(5.0, 10.0))
		return
	if warren and warren.hole_count() > 0:
		_hole = _rng.randi_range(0, warren.hole_count() - 1)
		global_position = warren.mouth(_hole) - warren.way_in(_hole) * 0.12
		facing_yaw = atan2(-warren.way_in(_hole).x, -warren.way_in(_hole).z)
	mode = Mode.PEEK
	_mode_left = _rng.randf_range(peek_time.x, peek_time.y)
	act = Act.SIT_UP
	visible = true
	_prev_pos = global_position
	_curr_pos = global_position
	if rabbit:
		rabbit.global_position = global_position
		rabbit.visible = not _far
		rabbit.settle()
	set_physics_process(true)
	set_process(true)
	_watch_in = 0.0


## All quiet: it hops out to graze.
func _come_out() -> void:
	mode = Mode.GRAZE
	escaped = false
	collision_layer = _layers.x
	collision_mask = _layers.y
	act = Act.HOP
	_act_left = _rng.randf_range(1.0, 3.0)
	_goal = _graze_spot()
	_point = Vector3.INF


## Grazing: nibbling, hopping a little way, sitting up, washing, hunched;
## the way to go (zero while it stays put).
func _graze(delta: float) -> Vector3:
	_act_left -= delta
	if _act_left <= 0.0:
		var pick := _rng.randf()
		if pick < 0.42:
			act = Act.NIBBLE
			_act_left = _rng.randf_range(2.0, 6.0)
		elif pick < 0.7:
			act = Act.HOP
			_act_left = _rng.randf_range(1.0, 3.0)
			_goal = _graze_spot()
		elif pick < 0.82:
			act = Act.SIT_UP
			_act_left = _rng.randf_range(1.2, 3.0)
		elif pick < 0.92:
			act = Act.WASH
			_act_left = _rng.randf_range(2.0, 4.0)
		else:
			act = Act.HUNCH
			_act_left = _rng.randf_range(2.0, 5.0)
	if act == Act.HOP and _goal.is_finite():
		var to := _goal - global_position
		to.y = 0.0
		if to.length() > 0.25:
			return to
		act = Act.NIBBLE
		_act_left = _rng.randf_range(1.5, 4.0)
	return Vector3.ZERO


## A spot to hop to: a little way from where it is, within `graze_range` of its warren (on it, often), clear of walls.
func _graze_spot() -> Vector3:
	for attempt in 6:
		var round_about := _rng.randf_range(-PI, PI)
		var spot := global_position + Vector3(cos(round_about), 0.0, sin(round_about)) * _rng.randf_range(0.6, 2.2)
		if _rng.randf() < 0.3:
			# (up on to the warren, where the grass is shortest)
			spot = _home + Vector3(cos(round_about), 0.0, sin(round_about)) * _rng.randf_range(0.3, 1.5)
		var from_home := Vector2(spot.x - _home.x, spot.z - _home.z)
		if from_home.length() > graze_range:
			spot = _home + Vector3(from_home.x, 0.0, from_home.y).normalized() * graze_range * 0.8
		if maze == null or nav.line_free(global_position, spot, _radius + 0.4):
			return spot
	return Vector3.INF


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
	# (sat still on the ground, it need not move at all)
	if current.length() > 0.01 or not grounded:
		move_and_slide()


## Where it is making for, as the world's life sees it (MazeEnemy.goal: also
## where it goes while out of everyone's sight): its warren, or where it is.
func goal() -> Vector3:
	var hunter: Variant = get(&"threat")
	if warren and warren.hole_count() > 0 and (hunter is MazeEnemy or mode == Mode.BOLT):
		return warren.mouth(warren.nearest_hole(global_position))
	if Vector2(_home.x - global_position.x, _home.z - global_position.z).length() > graze_range:
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
	rabbit.visible = mode != Mode.UNDER
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	if puppet and mode in [Mode.BOLT, Mode.GRAZE] and heading.length_squared() > 0.04:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-12.0 * delta))
	elif puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-6.0 * delta))
	elif heading.length_squared() > 0.04 and mode != Mode.DIVE:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))
	elif _point.is_finite():
		# (it watches side-on, as a rabbit does, its eye on them: it turns only when they are behind it)
		var to := _point - global_position
		var off := angle_difference(facing_yaw, atan2(to.x, to.z))
		if absf(off) > 2.0:
			facing_yaw = lerp_angle(facing_yaw, atan2(to.x, to.z) - signf(off) * 1.2, 1.0 - exp(-3.0 * delta))
	rabbit.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	rabbit.rotation = Vector3(0.0, facing_yaw, 0.0)
	rabbit.grounded = is_on_floor() or puppet or mode in [Mode.DIVE, Mode.PEEK]
	var grazing := mode == Mode.GRAZE
	rabbit.grazing = grazing and act in [Act.NIBBLE, Act.HOP] and heading.length() < 0.3
	rabbit.upright = (grazing and act == Act.SIT_UP) or mode in [Mode.WATCH, Mode.PEEK]
	rabbit.washing = grazing and act == Act.WASH
	rabbit.alert = mode in [Mode.WATCH, Mode.PEEK]
	rabbit.flagging = mode in [Mode.BOLT, Mode.DIVE] and heading.length() > 1.0
	rabbit.fleeing = mode in [Mode.BOLT, Mode.DIVE] and heading.length() > 2.0
	rabbit.look_at_point = _point if mode in [Mode.WATCH, Mode.PEEK] else Vector3.INF


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Thumps (low two bits), what it is doing while it grazes (next three).
func net_flag() -> int:
	return (_thumps & 3) | ((act & 7) << 2)


func net_point() -> Vector3:
	return _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	_point = point
	act = ((flag >> 2) & 7) as Act
	var thumps := flag & 3
	if not _heard_flagged:
		_heard_flagged = true
	elif rabbit and thumps != (_thumps & 3):
		rabbit.thump()
	_thumps = thumps


func _heard_changed(_was: int, now: int, _first: bool) -> void:
	mode = now as Mode
	escaped = mode == Mode.UNDER
	visible = mode != Mode.UNDER
	collision_layer = 0 if mode in [Mode.DIVE, Mode.UNDER] else 4


## As a puppet: goes where the host says, straight (down its hole too), carrying on as it was going.
func _follow_heard(delta: float) -> void:
	if not _heard:
		return
	_heard_at += _heard_moving * delta
	var was := global_position
	global_position = global_position.lerp(_heard_at, 1.0 - exp(-12.0 * delta))
	if global_position.distance_to(_heard_at) > 2.5:
		global_position = _heard_at
	velocity = (global_position - was) / maxf(delta, 0.0001)


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if not puppet and mode != Mode.GRAZE:
		# (brought back by the world: grazing again, out of its hole)
		mode = Mode.GRAZE
		escaped = false
		collision_layer = _layers.x
		collision_mask = _layers.y
		set_physics_process(true)
		set_process(true)
	if rabbit:
		rabbit.global_position = at
		rabbit.settle()


func _puppet_changed() -> void:
	collision_layer = 4
	collision_mask = 0 if puppet else 1

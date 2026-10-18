class_name TameChickens
extends Node3D
## A flock of ordinary chickens, hens and a rooster, that hunts nobody and
## calls nobody: wildlife, for life in the clearing (and, if a ring's style asks
## for them, in the maze). They forage, cluck and crow; anyone running through
## them scatters them a few steps, squawking, and they settle again; anyone
## walking near, they edge away from. They never call the hunters and never mob.
##
## The birds are ChickenFlock (creatures/chicken/), `tame`, made with
## ChickenVoice for their sounds. Each machine runs its own copy: they are
## placed from the round's seed (`populate`), so everyone in a room has the same
## flocks in the same places, and each copy scatters them from the players it
## sees (its own and its friends').

## How near someone running scatters them (sprinting, half as far again), and how
## near anyone at all does; how near they edge away from anyone.
@export var scatter_near := 3.5
@export var touch := 0.8
@export var shy := 5.0
@export var roam := 7.0

var maze: Maze
var flock: ChickenFlock
var nav: MazeNav

var _seed := 0
var _look_in := 0.0


func _init(plan: Maze = null, flock_seed := 0) -> void:
	maze = plan
	_seed = flock_seed


func _ready() -> void:
	add_to_group(&"wildlife")
	if maze:
		nav = MazeNav.new(maze, false)
	var choose := RandomNumberGenerator.new()
	choose.seed = _seed
	flock = ChickenFlock.new()
	flock.name = "Flock"
	flock.tame = true
	flock.flock_seed = _seed
	flock.count = choose.randi_range(6, 10)
	flock.roosters = 1
	flock.filth = 0.3
	flock.molt = 0.15
	flock.low_poly = Settings.low_poly
	flock.home = Vector3(global_position.x, maze.ground_height(global_position) if maze else global_position.y, global_position.z)
	flock.roam = roam
	flock.keep_in = _keep_in
	if maze:
		flock.ground_height = maze.ground_height
	add_child(flock)
	flock.top_level = true
	flock.global_transform = Transform3D.IDENTITY
	flock.add_child(ChickenVoice.new(flock))


func _physics_process(delta: float) -> void:
	_look_in -= delta
	if _look_in > 0.0:
		return
	_look_in = 0.15
	var uneasy := PackedVector3Array()
	for player: Node in get_tree().get_nodes_in_group(&"maze_players"):
		if not (player is Node3D) or not (player as Node3D).is_inside_tree():
			continue
		var at := (player as Node3D).global_position
		var nearest := _nearest_bird(at)
		if nearest > 12.0:
			continue
		var moving: Variant = player.get(&"velocity")
		var pace := Vector2((moving as Vector3).x, (moving as Vector3).z).length() if moving is Vector3 else 0.0
		var reach := touch
		if player.get(&"is_sprinting") == true or pace > 5.2:
			reach = scatter_near * 1.5
		elif pace > 3.0:
			reach = scatter_near
		if nearest < reach:
			flock.scare(at)
		elif nearest < shy:
			uneasy.append(at)
	flock.uneasy = uneasy


func _nearest_bird(at: Vector3) -> float:
	var best := INF
	for i in flock.count:
		var bird := flock.bird_position(i)
		best = minf(best, Vector2(bird.x - at.x, bird.z - at.z).length())
	return best


## Keeps a bird where chickens may be: out of walls, out of the marsh, and (if
## home is in the clearing) in the clearing.
func _keep_in(point: Vector3) -> Vector3:
	if maze == null:
		return point
	var home := flock.home if flock else global_position
	var in_clearing := maze.in_clearing(maze.cell_at(home))
	for k in 6:
		var ok := maze.ground_height(point) > ClearingStyle.MARSH_LEVEL + 0.05
		if in_clearing:
			ok = ok and maze.in_clearing(maze.cell_at(point))
		elif nav:
			ok = ok and nav.clear_of_walls(point, 0.35)
		if ok:
			return point
		point = point.lerp(Vector3(home.x, point.y, home.z), 0.4)
	return Vector3(home.x, point.y, home.z)


## Puts in the tame flocks for a round: as many in the clearing as its
## ClearingStyle says (Wildlife: chicken_flocks), the first at the edge of the
## woods and the rest about the field, all well away from the middle (where
## everyone starts) and from the paths between the middle and the gates, and out
## of the marsh and the tall grass; and as many in the first ring's halls as its
## MazeStyle says (Wildlife: tame_chicken_flocks). Placed from `seed_value`.
static func populate(parent: Node, plan: Maze, seed_value: int) -> Array[TameChickens]:
	var made: Array[TameChickens] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var look := plan.clearing_style
	var spots: Array[Vector2] = []
	for i in look.chicken_flocks:
		var spot := clearing_spot(plan, rng, i == 0, spots)
		if not spot.is_finite():
			continue
		spots.append(spot)
		var at := Vector3(spot.x, 0.0, spot.y)
		at.y = plan.ground_height(at)
		made.append(_add(parent, plan, at, rng.randi()))
	var style: MazeStyle = plan.styles[0] if not plan.styles.is_empty() else null
	if style and style.tame_chicken_flocks > 0:
		var halls := MazeNav.new(plan).lairs(3)
		for i in style.tame_chicken_flocks:
			if halls.is_empty():
				break
			var cell := halls[rng.randi_range(0, halls.size() - 1)]
			made.append(_add(parent, plan, plan.world(cell), rng.randi()))
	return made


static func _add(parent: Node, plan: Maze, at: Vector3, flock_seed: int) -> TameChickens:
	var flock := TameChickens.new(plan, flock_seed)
	flock.name = "TameChickens%d" % parent.get_child_count()
	flock.position = at
	parent.add_child(flock)
	return flock


## A place in the clearing for a flock (x, z): at the edge of the woods if
## `by_woods` (and there are woods), else anywhere in the field; at least 45 m
## from the middle, 15 m from the way from the middle to any gate, 25 m in from
## the walls, `apart` from other flocks, out of the marsh and the tall grass.
## Not finite if none was found.
static func clearing_spot(plan: Maze, rng: RandomNumberGenerator, by_woods: bool, others: Array[Vector2] = []) -> Vector2:
	var look := plan.clearing_style
	var half := Maze.CLEARING * Maze.CELL * 0.5
	var woods := look.entrance(ClearingStyle.Entrance.WOODS)
	for attempt in 300:
		var spot: Vector2
		if by_woods and not woods.is_empty() and attempt < 200:
			var way := (woods[1] as Vector2).rotated(rng.randf_range(-1.0, 1.0))
			spot = (woods[0] as Vector2) + way * look.woods_size * rng.randf_range(0.98, 1.12)
		else:
			spot = Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		if maxf(absf(spot.x), absf(spot.y)) > half - 25.0 or spot.length() < 45.0:
			continue
		if look.tall_grass_at(spot) > 0.0:
			continue
		var marsh := look.marsh_rect()
		if marsh.has_area() and marsh.grow(10.0).has_point(spot):
			continue
		var on_path := false
		for gate: Array in look.entrance_spots:
			if Geometry2D.get_closest_point_to_segment(spot, Vector2.ZERO, gate[0]).distance_to(spot) < 15.0:
				on_path = true
		var crowded := false
		for other in others:
			if other.distance_to(spot) < 40.0:
				crowded = true
		if not on_path and not crowded:
			return spot
	return Vector2.INF

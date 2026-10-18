class_name Ravens
extends Node3D
## A pair of ravens (or a lone one) on the maze's walls: wildlife, and an omen.
## They hunt nobody and call nobody: they sit on the wall tops over their hall
## (Perches.along_walls), croaking deep now and then and knocking, preening,
## looking about. But when someone comes near (`notice_range`) and something
## that hunts is waiting in the halls ahead of them (`hunter_range`, not after
## anyone yet), the ravens take off, croaking, and fly over the walls ahead of
## them to sit on the walls over it: a warning, for those who notice where the
## ravens went. They stay there, croaking, while it stays (up to `omen_time`),
## then fly home; and not again for `rest_time`.
##
## The birds are CorvidFlock (creatures/crow/), kind RAVEN. Each machine runs its
## own copy (`populate` places them from the round's seed) and watches for its
## own player (the boy it plays), so everyone in a room has the same ravens, and
## each is warned of what lies ahead of them.

enum Mode { HOME, OMEN }

@export var notice_range := 32.0
@export var hunter_range := Vector2(18.0, 75.0)
@export var omen_time := 45.0
@export var rest_time := 50.0

var maze: Maze
var flock: CorvidFlock
var mode := Mode.HOME
## What they sit over, as an omen (null: nothing).
var omen: Node3D
## Whom they watch for (empty: the boy this machine plays).
var targets: Array = []

var _seed := 0
var _home := Vector3.ZERO
var _look_in := 0.0
var _left := 0.0
var _rest := 0.0
var _omen_at := Vector3.INF
var _settled := false


func _init(plan: Maze = null, pair_seed := 0) -> void:
	maze = plan
	_seed = pair_seed


func _ready() -> void:
	add_to_group(&"wildlife")
	_home = global_position
	var choose := RandomNumberGenerator.new()
	choose.seed = _seed
	flock = CorvidFlock.new()
	flock.name = "Pair"
	flock.kind = CorvidBody.Kind.RAVEN
	flock.flock_seed = _seed
	flock.count = 2 if choose.randf() < 0.75 else 1
	flock.low_poly = Settings.low_poly
	flock.home = _home
	flock.restless = 0.01
	flock.grip = 0.15
	flock.call_every = 22.0
	flock.flight_speed = 9.0
	if maze:
		flock.ground_height = maze.ground_height
	add_child(flock)
	flock.top_level = true
	flock.global_transform = Transform3D.IDENTITY
	flock.add_child(CorvidVoice.new(flock))
	_settle.call_deferred()


func _settle() -> void:
	if not is_inside_tree():
		return
	_perch_near(_home, false)
	flock.settle()
	_settled = true


func _perch_near(near: Vector3, move: bool) -> bool:
	var ground := maze.ground_height(near) if maze else near.y
	var found := Perches.along_walls(get_world_3d(), near, ground, 28.0, 3.0, 0.9)
	if (found[0] as PackedVector3Array).is_empty():
		if not move:
			flock.ground_share = 1.0
			flock.roam = 3.0
		return false
	flock.set_perches(found[0], found[1], move)
	return true


func _physics_process(delta: float) -> void:
	if not _settled or maze == null:
		return
	_rest -= delta
	_left -= delta
	_look_in -= delta
	if _look_in > 0.0:
		return
	_look_in = 0.5
	var boy := _local_player()
	match mode:
		Mode.HOME:
			if boy and _rest <= 0.0 and _flat(boy.global_position, flock.centre()) < notice_range:
				var hunter := _waiting_ahead(boy)
				if hunter:
					go_to(hunter)
		Mode.OMEN:
			var gone := omen == null or not is_instance_valid(omen) or _flat(omen.global_position, _omen_at) > 15.0
			var far := boy == null or _flat(boy.global_position, flock.centre()) > 110.0
			if gone or far or _left <= 0.0:
				_go_home()


## They fly to sit over `hunter` (as when someone comes near and it waits ahead of them).
func go_to(hunter: Node3D) -> void:
	var at := hunter.global_position
	if not _perch_near(at, true):
		return
	mode = Mode.OMEN
	omen = hunter
	_omen_at = at
	_left = omen_time
	flock.call_every = 6.0
	flock.watch(Vector3.INF)
	# (the first croaks as they go)
	for i in flock.count:
		flock.call_now(i)


func _go_home() -> void:
	mode = Mode.HOME
	omen = null
	_rest = rest_time
	flock.call_every = 22.0
	_perch_near(_home, true)


## Something that hunts, waiting (after nobody), in the maze between
## `hunter_range` from `boy`, ahead of him if any is (the way he faces or goes),
## else the nearest.
func _waiting_ahead(boy: Node3D) -> Node3D:
	var best: Node3D = null
	var score := -INF
	var facing := -boy.global_basis.z
	var moving: Variant = boy.get(&"velocity")
	if moving is Vector3 and Vector2((moving as Vector3).x, (moving as Vector3).z).length() > 0.5:
		facing = moving
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.01 else Vector3.FORWARD
	for node: Node in get_tree().get_nodes_in_group(&"maze_enemies"):
		if not (node is MazeEnemy) or node is Crows or node is Bats or node is Chickens:
			continue
		var hunter := node as MazeEnemy
		if hunter.chasing or not hunter.is_inside_tree() or not maze.inside(maze.cell_at(hunter.global_position)):
			continue
		var d := _flat(hunter.global_position, boy.global_position)
		if d < hunter_range.x or d > hunter_range.y:
			continue
		var way := hunter.global_position - boy.global_position
		way.y = 0.0
		var ahead := facing.dot(way.normalized())
		var value := ahead * 2.0 - d / hunter_range.y
		if value > score:
			score = value
			best = hunter
	return best


func _local_player() -> Node3D:
	for node: Variant in targets:
		if is_instance_valid(node) and (node as Node3D).is_inside_tree():
			return node
	for node: Node in get_tree().get_nodes_in_group(&"maze_players"):
		if node is Player and not node.is_in_group(&"runners") and (node as Node3D).is_inside_tree():
			return node
	return null


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Puts in the ravens for a round: as many pairs in the first ring's halls as
## its MazeStyle says (Wildlife: raven_pairs), well apart. Placed from `seed_value`.
static func populate(parent: Node, plan: Maze, seed_value: int) -> Array[Ravens]:
	var made: Array[Ravens] = []
	var style: MazeStyle = plan.styles[0] if not plan.styles.is_empty() else null
	if style == null or style.raven_pairs <= 0:
		return made
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var halls := MazeNav.new(plan).lairs(4)
	var taken: Array[Vector3] = []
	for i in style.raven_pairs:
		for attempt in 20:
			if halls.is_empty():
				break
			var at := plan.world(halls[rng.randi_range(0, halls.size() - 1)])
			var crowded := false
			for other in taken:
				if other.distance_to(at) < 60.0:
					crowded = true
			if crowded and attempt < 19:
				continue
			taken.append(at)
			made.append(add(parent, plan, at, rng.randi()))
			break
	return made


static func add(parent: Node, plan: Maze, at: Vector3, pair_seed: int) -> Ravens:
	var pair := Ravens.new(plan, pair_seed)
	pair.name = "Ravens%d" % parent.get_child_count()
	pair.position = at
	parent.add_child(pair)
	return pair

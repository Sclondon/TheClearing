class_name Birds
extends Node3D
## The birds that hunt nobody: blue jays and a few crows in the clearing's
## pines, and the ravens on the maze's walls (Ravens). (The crows of the maze,
## that give you away, are hunters: Crows, among MazeEnemies.)
##
## - BLUE JAYS (BlueJays, creatures/blue_jay/): families of three to six in the
##   pines at the edge of the woods, nearest the clearing's middle (as many as
##   ClearingStyle "Wildlife" says), flitting from branch to branch and tree to
##   tree, down to the ground in front of the trees to hop about, and back up.
##   They scold (crests up, screaming "jay! jay!") anyone who comes in under
##   their trees, or anything that hunts that comes near; anyone running through
##   those on the ground sends them up into the branches.
## - CROWS (CorvidFlock, creatures/crow/): a small flock in the tops of a stand
##   of pines by the woods, coming down to walk and peck in the meadow in front
##   of it. Walk near and those on the ground fly up into the trees; run at them
##   and the whole flock goes up cawing, wheels over the trees and settles again.
##   They call nobody: the clearing is safe.
## - RAVENS: as many pairs in the first ring as its MazeStyle says (Ravens).
##
## Everything is placed from the round's seed and the maze's trees (the TREE
## pieces of its layout), and each machine runs its own copy, frightened by the
## same players, so they agree closely enough. Nothing here is sent.

## How near someone must come under a jays' tree for them to scold (m), and how
## near something that hunts.
const SCOLD_NEAR := 7.0
const SCOLD_HUNTER := 25.0
## Crows: how near walking sends those on the ground up, and running the whole flock.
const CROW_SHY := 8.0
const CROW_RUN := 15.0

var maze: Maze
var jays: Array[BlueJays] = []
var crows: Array[CorvidFlock] = []
var ravens: Array[Ravens] = []

## Each jay family's trees (their trunks), by family.
var _jay_trees: Array = []
var _crow_rest: Array[float] = []
var _look_in := 0.0


## Makes the birds of a round in `world` (its maze, and its layout's trees).
static func put(world: Node3D, plan: Maze, seed_value: int) -> Birds:
	var made := Birds.new()
	made.name = "Birds"
	world.add_child(made)
	var builder := world.get_node_or_null(^"Maze") as MazeBuilder
	var trees: Array = []
	if builder and builder.layout:
		for piece in builder.layout.pieces(MazePiece.Kind.TREE):
			trees.append(piece.global_transform)
	made.populate(plan, trees, seed_value)
	return made


## Puts in every flock the clearing's and the first ring's styles ask for, from `seed_value`.
func populate(plan: Maze, trees: Array, seed_value: int) -> void:
	maze = plan
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var look := plan.clearing_style
	# (the trees nearest the middle first: the edge of the woods and the stands, facing the field)
	var order := trees.duplicate()
	order.sort_custom(func(a: Transform3D, b: Transform3D) -> bool: return Vector2(a.origin.x, a.origin.z).length() < Vector2(b.origin.x, b.origin.z).length())
	var used: Array[Vector3] = []
	for k in look.blue_jay_families:
		var stand := _stand(order, used, 45.0, 4, false)
		if stand.is_empty():
			break
		var anchor: Transform3D = stand[0]
		used.append(anchor.origin)
		add_jays(anchor.origin, stand, rng.randi())
	for k in look.crow_flocks:
		var stand := _stand(order, used, 45.0, 5, true)
		if stand.is_empty():
			break
		used.append((stand[0] as Transform3D).origin)
		add_crows(stand, rng.randi())
	ravens = Ravens.populate(self, plan, rng.randi())


## A stand of trees: one (and its nearest `size - 1` within 13 m) at least
## `apart` from each of `used`, not on the way from the middle to a gate; the
## nearest the middle such, or (with `far`) one well back from the edge.
func _stand(order: Array, used: Array[Vector3], apart: float, size: int, far: bool) -> Array:
	var look := maze.clearing_style
	var list := order.duplicate()
	if far:
		list.reverse()
	for place: Transform3D in list:
		var at := place.origin
		var crowded := false
		for other in used:
			if other.distance_to(at) < apart:
				crowded = true
		if crowded:
			continue
		var on_path := false
		for gate: Array in look.entrance_spots:
			if Geometry2D.get_closest_point_to_segment(Vector2(at.x, at.z), Vector2.ZERO, gate[0]).distance_to(Vector2(at.x, at.z)) < 12.0:
				on_path = true
		if on_path:
			continue
		var near: Array = []
		for other: Transform3D in order:
			if other.origin.distance_to(at) < 13.0:
				near.append(other)
		if near.size() < mini(size, 3):
			continue
		near.sort_custom(func(a: Transform3D, b: Transform3D) -> bool: return a.origin.distance_squared_to(at) < b.origin.distance_squared_to(at))
		return near.slice(0, size)
	return []


## A family of jays in the trees `stand` (transforms), round `at` (on the
## ground in front of them, towards the middle).
func add_jays(at: Vector3, stand: Array, family_seed: int) -> BlueJays:
	var rng := RandomNumberGenerator.new()
	rng.seed = family_seed
	var family := BlueJays.new()
	family.name = "Jays%d" % jays.size()
	family.flock_seed = family_seed
	family.count = rng.randi_range(3, 6)
	family.low_poly = Settings.low_poly
	var toward := Vector3(-at.x, 0.0, -at.z).normalized() if Vector2(at.x, at.z).length() > 1.0 else Vector3.FORWARD
	var ground := at + toward * 4.5
	family.home = Vector3(ground.x, maze.ground_height(ground) if maze else ground.y, ground.z)
	family.roam = 4.0
	if maze:
		family.ground_height = maze.ground_height
		family.keep_in = _out_of_marsh
	add_child(family)
	family.top_level = true
	family.global_transform = Transform3D.IDENTITY
	family.add_child(CorvidVoice.new(family))
	var trunks: Array[Vector3] = []
	for place: Transform3D in stand:
		trunks.append(place.origin)
	var found := Perches.in_pines(stand, rng, 7, 0.06, 0.4, Vector2(0.82, 1.0)) if not stand.is_empty() else [PackedVector3Array(), PackedVector3Array()]
	family.set_perches(found[0], found[1], false)
	family.settle()
	jays.append(family)
	_jay_trees.append(trunks)
	return family


## A small flock of crows in the tops of the trees `stand`, foraging in the meadow in front of them.
func add_crows(stand: Array, flock_seed: int) -> CorvidFlock:
	var rng := RandomNumberGenerator.new()
	rng.seed = flock_seed
	var flock := CorvidFlock.new()
	flock.name = "Crows%d" % crows.size()
	flock.kind = CorvidBody.Kind.CROW
	flock.flock_seed = flock_seed
	flock.count = rng.randi_range(4, 7)
	flock.low_poly = Settings.low_poly
	flock.ground_share = 0.6
	flock.restless = 0.02
	flock.circle_radius = 10.0
	flock.circle_height = 14.0
	var at: Vector3 = (stand[0] as Transform3D).origin
	var toward := Vector3(-at.x, 0.0, -at.z).normalized() if Vector2(at.x, at.z).length() > 1.0 else Vector3.FORWARD
	var ground := at + toward * 14.0
	flock.home = Vector3(ground.x, maze.ground_height(ground) if maze else ground.y, ground.z)
	flock.roam = 7.0
	if maze:
		flock.ground_height = maze.ground_height
		flock.keep_in = _out_of_marsh
	add_child(flock)
	flock.top_level = true
	flock.global_transform = Transform3D.IDENTITY
	flock.add_child(CorvidVoice.new(flock))
	var found := Perches.in_pines(stand, rng, 3, 0.55, 0.8, Vector2(0.8, 1.0), true)
	flock.set_perches(found[0], found[1], false)
	flock.settle()
	crows.append(flock)
	_crow_rest.append(0.0)
	return flock


## A family of jays round `at` anywhere (the dev panel): in the trees near it,
## or on the walls, or on the ground.
func add_jays_at(at: Vector3) -> BlueJays:
	var stand: Array = []
	var builder := get_parent().get_node_or_null(^"Maze") as MazeBuilder if get_parent() else null
	if builder and builder.layout:
		for piece in builder.layout.pieces(MazePiece.Kind.TREE):
			if piece.global_position.distance_to(at) < 25.0:
				stand.append(piece.global_transform)
	stand = stand.slice(0, 4)
	var family := add_jays(at, stand, randi())
	family.home = Vector3(at.x, maze.ground_height(at) if maze else at.y, at.z)
	if stand.is_empty():
		var found := Perches.along_walls(get_world_3d(), at, family.home.y, 25.0, 4.0, 0.8, 2.0)
		family.set_perches(found[0], found[1], false)
		family.ground_share = 0.6 if not (found[0] as PackedVector3Array).is_empty() else 1.0
		family.settle()
	return family


## A pair of ravens on the walls round `at` (the dev panel).
func add_ravens_at(at: Vector3) -> Ravens:
	var pair := Ravens.add(self, maze, at, randi())
	ravens.append(pair)
	return pair


func _out_of_marsh(point: Vector3) -> Vector3:
	if maze and maze.ground_height(point) <= ClearingStyle.MARSH_LEVEL + 0.05:
		return point.lerp(Vector3.ZERO, 0.05)
	return point


func _physics_process(delta: float) -> void:
	_look_in -= delta
	for k in _crow_rest.size():
		_crow_rest[k] -= delta
	if _look_in > 0.0:
		return
	_look_in = 0.2
	var players := get_tree().get_nodes_in_group(&"maze_players")
	for k in jays.size():
		_mind_jays(jays[k], _jay_trees[k], players)
	for k in crows.size():
		_mind_crows(k, players)


# Jays scold whoever comes in under their trees (or anything that hunts that
# comes near); runners through them on the ground send them up.
func _mind_jays(family: BlueJays, trunks: Array, players: Array) -> void:
	var target := Vector3.INF
	for player: Node in players:
		if not (player is Node3D) or not (player as Node3D).is_inside_tree():
			continue
		var at := (player as Node3D).global_position
		for trunk: Vector3 in trunks:
			if Vector2(at.x - trunk.x, at.z - trunk.z).length() < SCOLD_NEAR:
				target = at + Vector3.UP * 1.2
		if _running(player) and _flat(at, family.home) < family.roam + 3.0:
			family.startle(at)
	if not target.is_finite():
		for hunter: Node in get_tree().get_nodes_in_group(&"maze_enemies"):
			if hunter is MazeEnemy and _flat((hunter as Node3D).global_position, family.home) < SCOLD_HUNTER:
				target = (hunter as Node3D).global_position + Vector3.UP * 1.0
				break
	family.scold(target)


# Crows: walking near sends those on the ground up; running at them, the whole flock.
func _mind_crows(k: int, players: Array) -> void:
	var flock := crows[k]
	for player: Node in players:
		if not (player is Node3D) or not (player as Node3D).is_inside_tree():
			continue
		var at := (player as Node3D).global_position
		var d := _flat(at, flock.centre())
		if _running(player) and d < CROW_RUN and _crow_rest[k] <= 0.0 and not flock.circling():
			flock.erupt(flock.centre() + Vector3.UP * 4.0, 7.0)
			_crow_rest[k] = 20.0
		elif d < CROW_SHY:
			flock.startle(at)


static func _running(player: Node) -> bool:
	var moving: Variant = player.get(&"velocity")
	var pace := Vector2((moving as Vector3).x, (moving as Vector3).z).length() if moving is Vector3 else 0.0
	return player.get(&"is_sprinting") == true or pace > 3.0


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

class_name MazePlants
## What the things that grow in the maze share (the flytraps, sundews and
## pitchers, MazeFlytrap, MazeSundew, MazePitcher; the mushrooms,
## MazeMushrooms): where they grow, what they eat, and how they slow you.

## Puts in a ring's carnivorous plants, mushrooms and mushroom zombies (for
## MazeEnemies.add_hunters, with its nav, rng and the cells it uses): `flytraps`
## in pairs against the walls of halls and dead ends, each pair with a sundew or
## a pitcher by them while there are any (`sundews`, `pitchers`); `patches` of
## mushrooms in dead ends and halls; and `hordes` of mushroom zombies (three or
## four, and a sleeper under the ground), each round a patch of mushrooms if
## there is one (they keep to the dark halls where the fungus is).
static func populate(enemies: MazeEnemies, nav: MazeNav, rng: RandomNumberGenerator, taken: Array[Vector2i], halls: Array[Vector2i], ends: Array[Vector2i], lairs: Array[Vector2i],
		flytraps: int, sundews: int, pitchers: int, patches: int, hordes: int) -> void:
	var beds: Array[Vector2i] = halls + ends
	if beds.is_empty():
		beds = lairs
	var dews := sundews
	var pits := pitchers
	var traps := flytraps
	while traps > 0 or dews > 0 or pits > 0:
		var cell := enemies._far_from(taken, beds, rng)
		taken.append(cell)
		var pick := rng.randi_range(0, 3)
		for k in mini(traps, 2):
			var trap := MazeFlytrap.new()
			trap.wall_pick = pick + k
			enemies.add(trap, cell, 0.0, rng.randi())
			traps -= 1
		pick += 2
		if dews > 0 and (pits <= 0 or rng.randf() < 0.5):
			var dew := MazeSundew.new()
			dew.wall_pick = pick
			enemies.add(dew, cell, 0.0, rng.randi())
			dews -= 1
		elif pits > 0:
			var pit := MazePitcher.new()
			pit.wall_pick = pick
			enemies.add(pit, cell, 0.0, rng.randi())
			pits -= 1
	var grown: Array[Vector2i] = []
	var damp: Array[Vector2i] = ends + halls
	if damp.is_empty():
		damp = lairs
	for i in patches:
		var cell := enemies._far_from(taken, damp, rng)
		taken.append(cell)
		grown.append(cell)
		enemies.add(MazeMushrooms.new(), cell, 0.0, rng.randi())
	for i in hordes:
		var den: Vector2i = grown[i % grown.size()] if not grown.is_empty() else enemies._far_from(taken, halls if not halls.is_empty() else lairs, rng)
		var horde := MazeMushroomZombie.horde_of(rng.randi_range(3, 4) + 1, 1, rng.randi() % 100000)
		enemies._add_pack(horde, den, nav, rng, taken)


## Where a plant put in the middle of a cell grows instead: back against the
## foot of one of its walls (the one the seed picks of those it has), `out`
## metres in front of the wall's face, facing out from it. Anywhere else (put
## by hand, or by the dev panel) it stays where it is put, facing as it was.
## Returns [where, yaw].
static func by_wall(maze: Maze, at: Vector3, yaw: float, out: float, pick: int) -> Array:
	if maze == null:
		return [at, yaw]
	var cell := maze.cell_at(at)
	var middle := maze.world(cell)
	if Vector2(at.x - middle.x, at.z - middle.z).length() > 0.75:
		return [at, yaw]
	var walls: Array[Vector2i] = []
	for step: Vector2i in Maze.STEPS:
		if maze.blocked(cell, step):
			walls.append(step)
	if walls.is_empty():
		return [at, yaw]
	var step: Vector2i = walls[posmod(pick, walls.size())]
	var s := Vector3(step.x, 0.0, step.y)
	var face := Maze.CELL * 0.5 - maze.wall_thick(cell, step) * 0.5
	var along := Vector3(-s.z, 0.0, s.x) * (float(posmod(pick * 7, 5)) - 2.0) * 1.2
	var spot := Vector3(middle.x, at.y, middle.z) + s * (face - out) + along
	spot.y = maze.ground_height(spot) + 0.02
	return [spot, atan2(-s.x, -s.z)]


## Whether a creature of the maze could be eaten by a plant that takes things
## up to `most` big (Ecology's sizes): alive, run here, taking part in the
## world's life, and small enough.
static func edible(one: Node, most: int) -> bool:
	if not (one is MazeEnemy):
		return false
	var creature := one as MazeEnemy
	if creature.dead or creature.puppet or creature.process_mode == Node.PROCESS_MODE_DISABLED:
		return false
	return Ecology.takes_part(creature) and Ecology.bulk(creature) <= most


## The creatures near `at` (within `reach`) that a plant could eat.
static func creatures_near(tree: SceneTree, at: Vector3, reach: float, most: int) -> Array:
	var found: Array = []
	if Ecology.current == null:
		return found
	for one: Node in tree.get_nodes_in_group(&"maze_enemies"):
		if one is Node3D and (one as Node3D).global_position.distance_squared_to(at) < reach * reach and edible(one, most):
			found.append(one)
	return found


## How much each player is held back, by each thing that does it: player -> {thing: share}.
static var _burdens := {}


## Slows `player` (the one this machine plays) by the most anything that grows
## asks (`share` of their speed taken away, 0 to give it back), and gives them
## their speed back when nothing does.
static func weigh(player: Node3D, by: Object, share: float) -> void:
	if not is_instance_valid(player):
		return
	var of: Dictionary = _burdens.get(player, {})
	if share > 0.0:
		of[by] = share
	else:
		of.erase(by)
	var most := 0.0
	for one: Variant in of.keys():
		if is_instance_valid(one):
			most = maxf(most, of[one])
		else:
			of.erase(one)
	if not player.has_meta(&"plant_speeds"):
		if most <= 0.0:
			_burdens.erase(player)
			return
		player.set_meta(&"plant_speeds", [player.get(&"walk_speed"), player.get(&"run_speed"), player.get(&"sprint_speed"), player.get(&"crouch_speed")])
	var base: Array = player.get_meta(&"plant_speeds")
	var keep := 1.0 - most
	player.set(&"walk_speed", base[0] * keep)
	player.set(&"run_speed", base[1] * keep)
	player.set(&"sprint_speed", base[2] * keep)
	player.set(&"crouch_speed", base[3] * keep)
	if most <= 0.0:
		player.remove_meta(&"plant_speeds")
		_burdens.erase(player)
	else:
		_burdens[player] = of


## How much `player` is held back now, 0..1.
static func burden(player: Node3D) -> float:
	var most := 0.0
	for one: Variant in (_burdens.get(player, {}) as Dictionary).keys():
		if is_instance_valid(one):
			most = maxf(most, _burdens[player][one])
	return most

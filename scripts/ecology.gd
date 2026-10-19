class_name Ecology
extends Node
## The maze as a world that goes on by itself, whether anyone sees it or not
## (after Rain World and Kenshi, kept simple). It runs on the machine that runs
## the hunters (alone, or the host); a guest's puppets only follow.
##
## WHAT EACH IS. Every kind of hunter that takes part is in KINDS: how big it is
## (0 a hen, 4 the biggest) and what it eats. Kinds not there take no part:
## they neither hunt the others nor are hunted (swarms, flocks, the colossus).
##
## HUNGER. A meat-eater gets hungrier (MazeEnemy.hunger, 0 fed to 1) over
## HUNGER_SECONDS. Hungry (past HUNGRY) and after nobody, it goes after the
## nearest creature it sees that is smaller than it (or as big, if that one eats
## only plants), never one of its own kind. Catching it kills it: it lies there
## a carcass (that the flies come to) and its killer eats a while.
##
## FEAR. Anything that eats is wary of a meat-eater bigger than it near it that
## is after it, or hungry: it runs from it (MazeEnemy.threat).
##
## OUT OF SIGHT (asleep, World._sleep_far) the creatures still go about their
## ways (MazeEnemy.roam_unseen), and a hungry meat-eater that comes on smaller prey
## asleep there may kill it, so that the maze is not as it was left.
##
## DENS. The dead come back after RESPAWN_SECONDS, where they were first put,
## once nobody is within DEN_AWAY of it.

## Whatever is here, now (null: none).
static var current: Ecology

enum Diet { NONE, PLANTS, MEAT }

## Each kind, by its class name: [how big, what it eats].
const KINDS := {
	"Apophis": [4, Diet.MEAT], "Abomination": [4, Diet.MEAT], "Centipede": [3, Diet.MEAT],
	"MazeSpider": [3, Diet.MEAT], "MazeFleshMound": [3, Diet.MEAT], "MazeBaboon": [2, Diet.MEAT],
	"MazeCoyote": [2, Diet.MEAT], "MazeDog": [2, Diet.MEAT], "MazeFishPerson": [2, Diet.MEAT],
	"MazeFrog": [2, Diet.MEAT], "MazeGhoul": [2, Diet.MEAT], "MazeSkinwalker": [2, Diet.MEAT],
	"MazeBoar": [3, Diet.PLANTS], "MazeElk": [3, Diet.PLANTS], "MazeDeer": [2, Diet.PLANTS],
	"Mummy": [2, Diet.NONE], "Alien": [2, Diet.NONE], "MazeGargoyle": [3, Diet.NONE],
	"MazeHydra": [4, Diet.MEAT], "MazePterodactyl": [3, Diet.MEAT], "MazeDeinonychus": [2, Diet.MEAT],
	"MazeLizardPerson": [2, Diet.MEAT], "MazeTribesman": [2, Diet.MEAT],
	"MazeStegosaurus": [4, Diet.PLANTS], "MazeSnail": [3, Diet.PLANTS],
	"MazeSpiderMonkey": [1, Diet.PLANTS], "MazeGibbon": [1, Diet.PLANTS], "MazeClown": [2, Diet.NONE],
	"MazeBear": [4, Diet.MEAT], "MazeBrachiosaurus": [4, Diet.PLANTS], "MazeDimetrodon": [3, Diet.MEAT],
	"MazeGriffinfly": [1, Diet.MEAT], "MazePsychicChild": [1, Diet.NONE],
	"MazeFox": [1, Diet.MEAT], "MazePondFrogs": [0, Diet.PLANTS],
	"MazeLynx": [1, Diet.MEAT], "MazePanther": [3, Diet.MEAT], "MazeWolf": [3, Diet.MEAT],
	"MazeRabbit": [0, Diet.PLANTS], "MazeHare": [1, Diet.PLANTS], "MazeJackalope": [1, Diet.PLANTS],
	"MazeOctopus": [3, Diet.MEAT],
	"MazeMoose": [3, Diet.PLANTS], "MazeMooseCalf": [2, Diet.PLANTS],
	"MazeMammoth": [4, Diet.PLANTS], "MazeMammothCalf": [2, Diet.PLANTS],
	"MazeMushroomZombie": [2, Diet.NONE], "MazeGnome": [1, Diet.PLANTS], "MazeMantis": [3, Diet.MEAT],
	"MazeHorse": [3, Diet.PLANTS], "MazeWyvern": [4, Diet.MEAT],
	"MazeRat": [0, Diet.MEAT],
	# (the woodsman and the beast: neither hunts the others nor is hunted)
	"MazeWoodsman": [2, Diet.NONE], "MazeBeast": [4, Diet.NONE],
}

## How long a fed meat-eater takes to starve, seconds, and how hungry it must be to hunt the others.
const HUNGER_SECONDS := 300.0
const HUNGRY := 0.5
## How far off it sees prey, and how near a threat must be to be run from, metres.
const PREY_SIGHT := 32.0
const THREAT_NEAR := 16.0
## How often each looks out for prey and threats, seconds.
const LOOK_EVERY := 0.5
## How long a kill is eaten, seconds; how many carcasses the kills leave at most.
const EAT_SECONDS := 10.0
const CARCASSES := 24
## Out of sight: how often they go on their way, and how far each time, metres;
## how near a sleeping meat-eater must come to prey to kill it, and how often it does.
const ROAM_EVERY := 4.0
const ROAM_STEP := 6.0
const ASLEEP_KILL_NEAR := 6.0
const ASLEEP_KILL_CHANCE := 0.3
## The dead come back after this long, seconds, once nobody is this near their den, metres.
const RESPAWN_SECONDS := 180.0
const DEN_AWAY := 150.0

## A kill: `prey` by `hunter`.
signal killed(prey: MazeEnemy, hunter: MazeEnemy)

var insects: Insects
var seconds := 0.0
var kills := 0
var _rng := RandomNumberGenerator.new()
var _known := {}
## [the dead, when it died] in the order they died.
var _dead: Array = []
var _carcasses: Array[Node3D] = []
## Those still to go on their way this round of ROAM_EVERY, and how many are owed:
## a few each frame, not all at once (every pathfinding step in one frame was a
## tenth of a second's hitch every four seconds).
var _roam_queue: Array = []
var _roam_owed := 0.0
var _list: Array = []
var _list_dirty := true
## How often hunger is brought up to date, seconds.
const NEEDS_EVERY := 0.5
var _needs_owed := 0.0
var _dens_in := 10.0


## Puts the world's life under `world` (the hunters' `insects` for carcasses).
static func put(world: Node, seed_value: int, flies: Insects = null) -> Ecology:
	var made := Ecology.new()
	made.name = "Ecology"
	made.insects = flies
	made._rng.seed = hash("ecology/%d" % seed_value)
	world.add_child(made)
	return made


func _enter_tree() -> void:
	current = self
	get_tree().node_added.connect(_on_added)


func _exit_tree() -> void:
	get_tree().node_added.disconnect(_on_added)
	if current == self:
		current = null


# --- What each is ---

## Each script's [kind, how big, what it eats], worked out once (these are asked
## of every creature by every other, hundreds of times a frame).
static var _traits := {}


static func _traits_of(one: Node) -> Array:
	var script := one.get_script() as Script
	var known: Variant = _traits.get(script)
	if known == null:
		var kind := String(script.get_global_name()) if script else ""
		var entry: Array = KINDS.get(kind, [-1, Diet.NONE])
		known = [kind, entry[0], entry[1]]
		_traits[script] = known
	return known


static func kind_of(one: Node) -> String:
	return _traits_of(one)[0]


## Whether it takes part at all.
static func takes_part(one: Node) -> bool:
	return _traits_of(one)[1] >= 0


static func bulk(one: Node) -> int:
	return _traits_of(one)[1]


static func diet(one: Node) -> Diet:
	return _traits_of(one)[2]


## About how far its body reaches from its middle, metres.
static func reach(one: Node) -> float:
	return 0.7 + maxi(bulk(one), 0) * 0.45


func hungry(one: MazeEnemy) -> bool:
	return diet(one) == Diet.MEAT and one.hunger >= HUNGRY


## Every creature that takes part. Kept, not found afresh each time (looking
## through every node in the maze for them, every frame and for every look about,
## was most of a frame with hundreds about): found again when one comes or goes.
func creatures() -> Array:
	if _list_dirty:
		_list_dirty = false
		_list = get_tree().get_nodes_in_group(&"maze_enemies").filter(func(one: Node) -> bool: return one is MazeEnemy and takes_part(one))
		for one: Node in _list:
			if not _known.has(one):
				# (each starts somewhere between fed and hungry, and its den is where it began)
				_known[one] = (one as Node3D).global_position
				one.hunger = _rng.randf_range(0.0, 0.8)
			if not one.tree_exiting.is_connected(_relist):
				one.tree_exiting.connect(_relist, CONNECT_DEFERRED)
	return _list


func _on_added(node: Node) -> void:
	if node is MazeEnemy:
		_list_dirty = true


func _relist() -> void:
	_list_dirty = true


## The creatures by where they are, in squares GRID metres a side, put in their
## squares again every GRID_EVERY physics frames (none moves far meanwhile: each
## square is looked in GRID_SLACK metres wider than asked).
const GRID := 32.0
const GRID_EVERY := 6
const GRID_SLACK := 4.0
var _grid := {}
var _grid_frame := -1


## The creatures within about `radius` metres of `point` across the ground (some
## a little farther: what is asked for measures for itself). Looking for prey and
## threats goes over these, not every creature in the maze.
func near(point: Vector3, radius: float) -> Array:
	var frame := Engine.get_physics_frames()
	if _grid_frame < 0 or frame - _grid_frame >= GRID_EVERY or _list_dirty:
		_grid_frame = frame
		_grid.clear()
		for one: Node3D in creatures():
			var at := one.global_position
			var key := Vector2i(floori(at.x / GRID), floori(at.z / GRID))
			if _grid.has(key):
				(_grid[key] as Array).append(one)
			else:
				_grid[key] = [one]
	var found: Array = []
	var r := radius + GRID_SLACK
	for y in range(floori((point.z - r) / GRID), floori((point.z + r) / GRID) + 1):
		for x in range(floori((point.x - r) / GRID), floori((point.x + r) / GRID) + 1):
			var here: Variant = _grid.get(Vector2i(x, y))
			if here != null:
				found.append_array(here)
	return found


## Whether `one` could be eaten by `hunter`.
func is_prey(one: MazeEnemy, hunter: MazeEnemy) -> bool:
	if one == hunter or one.dead or one.puppet or diet(one) == Diet.NONE or kind_of(one) == kind_of(hunter):
		return false
	# (the giant plant-eaters, the mammoth, the stegosaurus, the brachiosaurus, nothing takes)
	if bulk(one) >= 4 and diet(one) == Diet.PLANTS:
		return false
	var mine := bulk(hunter)
	return bulk(one) < mine or (bulk(one) == mine and diet(one) == Diet.PLANTS)


## The nearest creature `hunter` sees that it could eat (null: none).
func prey_for(hunter: MazeEnemy) -> MazeEnemy:
	var eye := hunter.global_position + Vector3.UP
	var best: MazeEnemy = null
	var nearest := PREY_SIGHT
	for one: MazeEnemy in near(hunter.global_position, PREY_SIGHT + 1.0):
		if one.process_mode == Node.PROCESS_MODE_DISABLED or not is_prey(one, hunter):
			continue
		var apart := eye.distance_to(one.global_position)
		if apart < nearest and hunter.huntable(one) and hunter.nav.sees(eye, one.global_position + Vector3.UP, PREY_SIGHT):
			nearest = apart
			best = one
	return best


## The nearest meat-eater near `one` that could eat it and is after it, or hungry (null: none).
func threat_to(one: MazeEnemy) -> MazeEnemy:
	if diet(one) == Diet.NONE:
		return null
	var best: MazeEnemy = null
	var nearest := THREAT_NEAR
	for other: MazeEnemy in near(one.global_position, THREAT_NEAR):
		if other.dead or diet(other) != Diet.MEAT or not is_prey(one, other):
			continue
		if other.quarry != one and not hungry(other):
			continue
		var apart := other.global_position.distance_to(one.global_position)
		if apart < nearest and one.nav.sees(one.global_position + Vector3.UP, other.global_position + Vector3.UP, THREAT_NEAR):
			nearest = apart
			best = other
	return best


# --- Each frame ---

func _process(delta: float) -> void:
	seconds += delta
	var all := creatures()
	# (hunger every NEEDS_EVERY seconds, not every frame for every one)
	_needs_owed += delta
	if _needs_owed >= NEEDS_EVERY:
		_tend(all, _needs_owed)
		_needs_owed = 0.0
	if _roam_queue.is_empty():
		_roam_queue = all.duplicate()
	_roam_owed += all.size() * delta / ROAM_EVERY
	if _roam_owed >= 1.0:
		var take := mini(int(_roam_owed), _roam_queue.size())
		_roam_owed -= take
		_out_of_sight(all, _roam_queue.slice(0, take))
		_roam_queue = _roam_queue.slice(take)
	_dens_in -= delta
	if _dens_in <= 0.0:
		_dens_in = 10.0
		_back_from_dens()


## `prey` is killed by `hunter` (seen or not): a carcass where it fell, and the killer fed.
func kill(prey: MazeEnemy, hunter: MazeEnemy) -> void:
	if prey.dead:
		return
	var at := prey.global_position
	prey.die()
	_dead.append([prey, seconds])
	hunter.ate(EAT_SECONDS)
	kills += 1
	if insects and bulk(prey) >= 1:
		_carcasses.append(insects.add_carcass(at, _rng.randf() * TAU))
		if _carcasses.size() > CARCASSES:
			var oldest: Node3D = _carcasses.pop_front()
			insects.carcasses.erase(oldest)
			oldest.queue_free()
	killed.emit(prey, hunter)


## Each meat-eater's hunger grows by `delta` seconds' worth.
func _tend(all: Array, delta: float) -> void:
	for one: MazeEnemy in all:
		if diet(one) == Diet.MEAT and not one.dead and not one.puppet:
			one.hunger = minf(one.hunger + delta / HUNGER_SECONDS, 1.0)


## The sleeping go on their ways; a hungry sleeping meat-eater may kill sleeping prey it comes on.
## Only `turn` of them (those still valid) go this time, when given; all, when not.
func _out_of_sight(all: Array, turn: Array = []) -> void:
	var going := (all if turn.is_empty() else turn).filter(_asleep)
	for one: MazeEnemy in going:
		one.roam_unseen(ROAM_STEP)
	# (who is asleep to be eaten: found only if a hungry hunter is going)
	var asleep: Array = []
	for hunter: MazeEnemy in going:
		if hunter.dead or not hungry(hunter):
			continue
		if asleep.is_empty():
			asleep = all.filter(_asleep)
		for one: MazeEnemy in asleep:
			if not one.dead and is_prey(one, hunter) and one.global_position.distance_to(hunter.global_position) < ASLEEP_KILL_NEAR and _rng.randf() < ASLEEP_KILL_CHANCE:
				kill(one, hunter)
				break


## The dead long enough come back in their dens, if nobody is near.
func _back_from_dens() -> void:
	var eyes: Array[Vector3] = []
	for player: Node in get_tree().get_nodes_in_group(&"maze_players"):
		if player is Node3D:
			eyes.append((player as Node3D).global_position)
	for i in range(_dead.size() - 1, -1, -1):
		# (one freed meanwhile is let go before it is typed)
		if not is_instance_valid(_dead[i][0]):
			_dead.remove_at(i)
			continue
		var one: MazeEnemy = _dead[i][0]
		if seconds - float(_dead[i][1]) < RESPAWN_SECONDS:
			continue
		var den: Vector3 = _known.get(one, one.global_position)
		if eyes.any(func(eye: Vector3) -> bool: return eye.distance_to(den) < DEN_AWAY):
			continue
		one.revive(den, _rng.randf_range(-PI, PI))
		_dead.remove_at(i)


# Asleep (out of everyone's sight), and alive and run here.
func _asleep(one: Variant) -> bool:
	return is_instance_valid(one) and not one.dead and not one.puppet and one.process_mode == Node.PROCESS_MODE_DISABLED

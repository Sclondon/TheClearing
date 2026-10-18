class_name MazePondFrogs
extends MazeEnemy
## A colony of ordinary frogs (common and leopard frogs, a hand long) at the
## edge of the water: round a little pond of their own in a hall of the maze,
## or along the edges of the marsh's pools in the clearing. The life of the
## world, and food for the bigger things. They are drawn and moved by
## PondFrogs (creatures/pond_frog/pond_frogs.gd); this is what they are here.
##
## THEY SING at dusk and through the night, and in the rain (DayCycle,
## Weather: the chorus is fullest in a night's rain, a few croaks by day), go
## quiet when someone comes near, and leap into the water one after another
## (plop, plop) when they come close. Nothing about them hurts anyone.
##
## PREY (Ecology: size 0, they eat plants as far as the world goes, which is
## to say they hunt nothing there: Diet.PLANTS, so that the world's hunters
## eat them and they eat nobody). The colony is one creature to the world: it
## is where the frog sitting out nearest danger is; one that is hunted, or a
## hunter coming near, sends them in, and while every frog is in the water
## there is nothing to catch (`escaped`). Caught, one frog is eaten and the
## rest go under; the colony is gone to the world until it comes back (it is
## brought back as the others are, in time, and the eaten frog with it).
##
## Their own lives (singing, hushing, diving, coming up) are run on every
## machine from where the players are, as the herds are; only what the world
## does to them is sent: whether something hunts near them (net_state 1) and
## their being eaten (the colony dead, as any other).

## How many frogs, how big their pond (0: no pond, `banks` say where they sit), and where they sit.
@export var frogs := 12
@export var pond_radius := 1.8
var banks: Array = []
## Nothing out of the water to catch (see MazeEnemy.huntable: the world's hunters pass over it).
var escaped := false
## Something hunts near them (as heard by a guest).
var alarmed := false
## What draws them (made when it goes in, beside it: it stays when the colony is dead).
var colony: PondFrogs

var _keeper: Keeper
var _middle := Vector3.ZERO


func _init() -> void:
	sight_range = 0.0
	hear_range = 0.0
	keep_out_of_clearing = false
	pack = &"pond_frogs"
	look_every = 0.5


func _ready() -> void:
	# (intangible: a dozen frogs are not a body anyone bumps into)
	collision_layer = 0
	collision_mask = 0
	_middle = global_position
	colony = PondFrogs.new()
	colony.name = "Frogs"
	colony.count = frogs
	colony.pool = pond_radius > 0.0 and banks.is_empty()
	colony.pool_radius = pond_radius
	colony.banks = banks
	_keeper = Keeper.new()
	_keeper.name = "%sFrogs" % name
	_keeper.owner_frogs = self
	_keeper.add_child(colony)
	# (beside it, not under it: a dead colony is hidden, and its frogs are not)
	_keeper.transform = Transform3D(Basis.IDENTITY, position)
	get_parent().add_child.call_deferred(_keeper)


func _exit_tree() -> void:
	if _keeper and is_instance_valid(_keeper) and not _keeper.is_queued_for_deletion():
		_keeper.queue_free()


## Where it keeps to: where it is (frogs do not wander off).
func goal() -> Vector3:
	return global_position


func roam_unseen(_step: float) -> void:
	pass


## It hunts nothing, and sees nobody.
func huntable(_target: Node3D) -> bool:
	return false


func _physics_process(delta: float) -> void:
	if puppet or maze == null:
		return
	# (only the world's part: what would eat it; it is after nobody)
	_ecology(delta)
	alarmed = threat != null
	if colony and colony.is_inside_tree():
		var at := colony.nearest_out(threat.global_position if threat else _middle)
		escaped = not at.is_finite()
		if at.is_finite():
			global_position = at


func net_state() -> int:
	return 1 if alarmed else 0


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	alarmed = state == 1


## Runs the frogs, beside the colony: what frightens them (the players, and
## anything that hunts near them), how hard they sing, and the colony's being
## eaten and coming back.
class Keeper:
	extends Node3D

	var owner_frogs: MazePondFrogs
	var _was_dead := false
	var _look_in := 0.0
	var _world: Node

	func _ready() -> void:
		_world = get_parent().get_parent() if get_parent() else null

	func _process(delta: float) -> void:
		var frogs := owner_frogs
		if not is_instance_valid(frogs):
			return
		var colony := frogs.colony
		if frogs.dead != _was_dead:
			_was_dead = frogs.dead
			if frogs.dead:
				colony.take_one(frogs.global_position)
			else:
				colony.restore()
		_look_in -= delta
		if _look_in > 0.0:
			return
		_look_in = 0.25
		var fear: Array = []
		for player: Node in get_tree().get_nodes_in_group(&"maze_players"):
			fear.append(player)
		if frogs.threat and is_instance_valid(frogs.threat):
			fear.append(frogs.threat)
		if frogs.alarmed and frogs.puppet:
			# (a guest does not know what hunts: it is near, and they go in)
			colony.scare(frogs.global_position, colony.dive_range * 2.0)
		colony.frighten = fear
		colony.chorus = chorus_now()

	## How hard they sing now: a few croaks by day, a chorus at dusk and through
	## the night, more in the rain.
	func chorus_now() -> float:
		var day: Variant = _world.get(&"day") if _world else null
		var weather: Variant = _world.get(&"weather") if _world else null
		var evening := 0.0
		if day:
			var hour := float(day.get(&"hour"))
			evening = 1.0 if hour >= DayCycle.SUNSET - 0.8 or hour < DayCycle.DAWN + 0.3 else (0.5 if hour >= DayCycle.SUNSET - 2.0 else 0.0)
		var rain := float(weather.get(&"rain")) if weather else 0.0
		return clampf(0.12 + 0.6 * evening + 0.5 * rain, 0.0, 1.0)


# --- Where they are put ---

## Colonies along the edges of the marsh's pools in the clearing (if it has a
## marsh): `count` of them, spread out, each [its middle, its banks].
static func marsh_colonies(maze: Maze, count: int, rng: RandomNumberGenerator, per := 10) -> Array:
	var made: Array = []
	var style := maze.clearing_style
	if style == null or count <= 0:
		return made
	var rect := style.marsh_rect()
	if not rect.has_area():
		return made
	var seed_value := maze.maze_seed
	var level := ClearingStyle.MARSH_LEVEL
	var tries := 0
	while made.size() < count and tries < 600:
		tries += 1
		var at := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
		var shore := _shore(style, at, seed_value)
		if shore.is_empty():
			continue
		if made.any(func(one: Array) -> bool: return Vector2((one[0] as Vector3).x, (one[0] as Vector3).z).distance_to(at) < 22.0):
			continue
		if style.marsh_lane_at(at) > 0.2:
			continue
		var banks: Array = []
		for k in per * 6:
			if banks.size() >= per:
				break
			var near := at + Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-5.0, 5.0))
			var bank := _shore(style, near, seed_value)
			if bank.is_empty():
				continue
			var p: Vector2 = bank[0]
			var w: Vector2 = bank[1]
			if banks.any(func(one: Array) -> bool: return Vector2((one[0] as Vector3).x, (one[0] as Vector3).z).distance_to(p) < 0.5):
				continue
			banks.append([Vector3(p.x, style.height_at(p.x, p.y, seed_value) + 0.01, p.y), Vector3(w.x, level + 0.01, w.y)])
		if banks.size() >= per / 2:
			made.append([banks[0][0], banks])
	return made


# A spot at the water's edge near `at`, and a point in the water by it: [spot, water] (empty: none).
static func _shore(style: ClearingStyle, at: Vector2, seed_value: int) -> Array:
	var depth := style.marsh_depth_at(at, seed_value)
	# (just out of the water: wet ground, a few centimetres above it)
	if depth > -0.02 or depth < -0.14:
		return []
	for k in 8:
		var way := Vector2.from_angle(TAU * k / 8.0)
		for reach: float in [0.6, 1.0, 1.4]:
			if style.marsh_depth_at(at + way * reach, seed_value) > 0.12:
				return [at, at + way * reach]
	return []

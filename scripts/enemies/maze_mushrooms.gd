class_name MazeMushrooms
extends MazeEnemy
## A patch of mushrooms (creatures/mushrooms/, `MushroomPatch`) grown over one
## cell of the maze: tufts of honey fungus along the feet of its walls, bracket
## fungi in shelves up them, tall pale bonnets that glow in the dark (DayCycle),
## and giant puffballs out on the floor. It never moves and catches nobody.
##
## - TREAD NEAR A PUFFBALL (within `tread_range`, or run within `run_range`) and
##   it puffs: a cloud of olive-brown spores billows out (`SporeCloud`) and hangs
##   there a few seconds. Breathing it, the picture blurs, greys and goes dusty
##   (`SporeVeil`) and you are slowed (by up to `slow_share`). A creature that
##   blunders into one puffs it too. Spent, a puffball swells back in `regrow_time`.
## - THE SPORES CALL THE DEAD. A puff is heard by every mushroom zombie within
##   `call_range` (they come to see: MazeMushroomZombie.heard). Walk wide of the
##   puffballs, slowly.
##
## Online, the host says which puffball puffs (`net_flag`); every machine shows
## the puff, and blurs and slows only the player it plays. Spawn as
## MazeEnemies.add does: it grows over the cell it is put in, its puffballs
## round where it is put.

## How near treading puffs one, how near running does (faster than `run_speed`).
@export var tread_range := 1.3
@export var run_range := 2.8
@export var run_speed := 3.0
## How many puffballs, at least and at most.
@export var puffballs := Vector2i(2, 4)
@export var slow_share := 0.35
@export var regrow_time := 35.0
@export var call_range := 36.0
## How thickly it grows along the walls, 0..1.
@export var thickness := 1.0

var patch: MushroomPatch
var cloud: SporeCloud
## How many times its puffballs have puffed, and which last (sent).
var puffs := 0
var last_puffed := -1

var _regrow_in: Array[float] = []
var _check_in := 0.0
var _night_in := 0.0
var _heard_acts := false
var _breathing: Node3D
var _day: Node


func _init() -> void:
	sight_range = 0.0
	hear_range = 0.0
	memory = 0.0
	pack = &"mushroom_patches"
	look_every = 0.15


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	patch = MushroomPatch.new()
	patch.name = "Patch"
	add_child(patch)
	patch.top_level = true
	patch.global_transform = Transform3D.IDENTITY
	_grow()
	patch.build()
	cloud = SporeCloud.new()
	add_child(cloud)
	patch.puffed.connect(_on_puffed)
	for i in patch.puffballs.size():
		_regrow_in.append(0.0)
	_day = _find_day()


func _exit_tree() -> void:
	if _breathing and is_instance_valid(_breathing):
		MazePlants.weigh(_breathing, self, 0.0)


## Grows it: along every wall of its cell and round where it was put (from the
## cell, so that every machine grows the same).
func _grow() -> void:
	var at := global_position
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("mushrooms/%d/%d" % [roundi(at.x * 10.0), roundi(at.z * 10.0)])
	var walls := 0
	if maze:
		var cell := maze.cell_at(at)
		var middle := maze.world(cell)
		for step: Vector2i in Maze.STEPS:
			if not maze.blocked(cell, step):
				continue
			walls += 1
			var s := Vector3(step.x, 0.0, step.y)
			var along := Vector3(-s.z, 0.0, s.x)
			var face := Vector3(middle.x, 0.0, middle.z) + s * (Maze.CELL * 0.5 - maze.wall_thick(cell, step) * 0.5)
			var spots := int(round(rng.randf_range(4.0, 8.0) * thickness))
			for k in spots:
				var foot := face + along * rng.randf_range(-Maze.CELL * 0.45, Maze.CELL * 0.45)
				foot.y = maze.ground_height(foot)
				var pick := rng.randf()
				if pick < 0.5:
					patch.tuft(foot - s * rng.randf_range(0.15, 0.6), rng, rng.randf_range(2.0, 4.5))
				elif pick < 0.8:
					patch.shelves(foot - s * 0.02, -s, rng, rng.randf_range(1.5, 4.0), rng.randf_range(1.5, 3.0))
				else:
					patch.bonnets(foot - s * rng.randf_range(0.2, 0.7), rng, rng.randf_range(2.0, 3.5))
	# Round where it was put: a few tufts and bonnets on the floor, and the puffballs
	for k in rng.randi_range(3, 6) if walls == 0 else rng.randi_range(1, 3):
		var round_about := rng.randf() * TAU
		var spot := at + Vector3(cos(round_about), 0.0, sin(round_about)) * rng.randf_range(1.0, 5.0)
		spot.y = _ground(spot)
		if rng.randf() < 0.6:
			patch.tuft(spot, rng, rng.randf_range(2.0, 4.0))
		else:
			patch.bonnets(spot, rng)
	for k in rng.randi_range(puffballs.x, puffballs.y):
		var round_about := TAU * k / maxf(puffballs.y, 1.0) + rng.randf_range(-0.5, 0.5)
		var spot := at + Vector3(cos(round_about), 0.0, sin(round_about)) * rng.randf_range(1.2, 4.0)
		spot.y = _ground(spot)
		patch.add_puffball(spot, rng.randf_range(1.3, 2.2))


func _ground(at: Vector3) -> float:
	return maze.ground_height(at) if maze else global_position.y


## The round's DayCycle, if there is one (World.day).
func _find_day() -> Node:
	var up := get_parent()
	while up:
		var found: Variant = up.get(&"day")
		if found is Node:
			return found
		up = up.get_parent()
	return null


func _physics_process(delta: float) -> void:
	_breathe()
	_night_in -= delta
	if _night_in <= 0.0:
		_night_in = 2.0
		if _day and is_instance_valid(_day):
			MushroomLook.set_night(1.0 - clampf(float(_day.get(&"daylight")), 0.0, 1.0))
	for i in _regrow_in.size():
		if _regrow_in[i] > 0.0:
			_regrow_in[i] -= delta
			if _regrow_in[i] <= 0.0:
				patch.regrow(i, 8.0)
	if puppet:
		return
	_check_in -= delta
	if _check_in > 0.0:
		return
	_check_in = look_every
	# (what else walks about near it, looked up once for all its puffballs)
	var near := MazePlants.creatures_near(get_tree(), global_position, 7.0, 4).filter(func(one: Node) -> bool: return not (one is MazeMushroomZombie))
	for i in patch.puffballs.size():
		if patch.ripe(i) and _trodden(i, near):
			puffs += 1
			last_puffed = i
			patch.puff(i)


## Whether anyone (or anything) is treading near puffball `i`.
func _trodden(i: int, near: Array) -> bool:
	var ball := patch.puffballs[i]
	for player: Node3D in players():
		if not is_instance_valid(player) or not player.is_inside_tree():
			continue
		var apart := Vector2(player.global_position.x - ball.x, player.global_position.z - ball.z).length()
		if absf(player.global_position.y - ball.y) > 2.0:
			continue
		var moving: Variant = player.get(&"velocity")
		var pace := Vector2((moving as Vector3).x, (moving as Vector3).z).length() if moving is Vector3 else 0.0
		if apart < tread_range or (pace > run_speed and apart < run_range):
			return true
	for one: Node in near:
		if (one as Node3D).global_position.distance_to(ball) < 1.0:
			return true
	return false


## A puff: the cloud, the regrowing, and the dead called to it.
func _on_puffed(at: Vector3, size: float) -> void:
	cloud.puff(at, size / 1.6)
	if last_puffed >= 0 and last_puffed < _regrow_in.size():
		_regrow_in[last_puffed] = regrow_time
	if not puppet:
		for one: Node in get_tree().get_nodes_in_group(&"mushroom_zombies"):
			if one is Node3D and (one as Node3D).global_position.distance_to(at) < call_range and one.has_method(&"heard"):
				one.heard(at, 1.0)


## The spores in the air round the player this machine plays: it sees blurred and goes slower.
func _breathe() -> void:
	var me := local_player()
	if me != _breathing and _breathing and is_instance_valid(_breathing):
		MazePlants.weigh(_breathing, self, 0.0)
	_breathing = me
	if me == null:
		return
	var thick := cloud.density_at(me.global_position + Vector3.UP * 1.0) if cloud.active() else 0.0
	SporeVeil.report(get_tree(), self, thick)
	MazePlants.weigh(me, self, slow_share * thick)


# --- Being run by someone else ---

## Its puffs (low four bits) and which puffball puffed last (the high four).
func net_flag() -> int:
	return (puffs & 0x0f) | ((maxi(last_puffed, 0) & 0x0f) << 4)


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	var count := flag & 0x0f
	if not _heard_acts:
		_heard_acts = true
	elif count != puffs & 0x0f:
		last_puffed = (flag >> 4) & 0x0f
		patch.puff(last_puffed)
	puffs = count


func _put(at: Vector3, _facing: float) -> void:
	# (it grows where it was put; the news only says what it does)
	pass

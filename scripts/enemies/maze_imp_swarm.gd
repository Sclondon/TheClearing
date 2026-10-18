class_name MazeImpSwarm
extends MazeEnemy
## A swarm of imps in the maze: a crack at the foot of a wall that dozens of
## them pour out of, a chattering tide along the floor and up the walls. What
## they look like and how they move is ImpSwarm (creatures/imp_swarm/, a
## component that knows nothing of the maze); this is only what it thinks.
##
## - ASLEEP in their crack, at the foot of the nearest wall to where it is put.
##   Anyone within `wake_range` of it (round corners and all, by the passages)
##   or running within `wake_hear` (sprinting, half again) wakes them: a chorus
##   of chittering from the crack (a second's warning), then out they pour.
## - They go after whoever woke them, by the passages (MazeNav), a little
##   faster than he runs: a sprint gets away. Up on anything they cannot climb
##   (a terrace, ivy, a vine), or out of their reach for long, he is safe: they
##   give up and stream home. So does going into the clearing.
## - Those that reach him run up him and cling. Each holds him back a little
##   (`hold_back`); `catch_count` on him at once for a second and he is brought
##   down (`caught`). A jump loosens them; a roll or a dive throws them all off.
## - Home, they rest (`rest_time`) before they will come out again.
##
## As a puppet (online, not the host) its swarm is run here too, after the
## player the host's says, with the host's mode; only the host's catches count.

enum Mode { ASLEEP, WARN, HUNT, HOME }

@export var count := 48
@export var wake_range := 13.0
@export var wake_hear := 20.0
## How much of his sprint each imp on him takes away, and the least he is left with.
@export var hold_back := 0.045
@export var slowest := 0.4
## Further than this from every player it does nothing at all.
@export var active_range := 80.0

var mode := Mode.ASLEEP
var swarm: ImpSwarm

var _nest := Vector3.ZERO
var _listen := 0.0
var _rolled := false
## Whether its crack is against a wall (else in the open, where it was put).
var against_wall := false
## Which way is out from its wall.
var out_of_wall := Vector3.BACK


func _init() -> void:
	sight_range = 0.0
	hear_range = 0.0
	memory = 1.0
	pack = &"imp_swarms"
	spare_time = 4.0


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = 0
	collision_mask = 0
	process_physics_priority = 50
	swarm = ImpSwarm.new()
	swarm.name = "Swarm"
	swarm.count = count
	swarm.top_level = true
	_place_nest.call_deferred()


## The crack: at the foot of the wall nearest the middle of its cell.
func _place_nest() -> void:
	if not is_inside_tree():
		return
	var middle := global_position
	var ground := maze.ground_height(middle) if maze else middle.y
	middle.y = ground + 0.4
	var best := Vector3.INF
	var normal := Vector3.BACK
	var space := get_world_3d().direct_space_state
	for step: Vector2i in Maze.STEPS:
		var way := Vector3(step.x, 0.0, step.y)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(middle, middle + way * Maze.CELL, 1))
		if hit.is_empty():
			continue
		var point: Vector3 = hit["position"]
		if best == Vector3.INF or middle.distance_to(point) < middle.distance_to(best):
			best = point
			normal = hit["normal"]
	_nest = Vector3(middle.x, ground, middle.z)
	if best != Vector3.INF:
		normal.y = 0.0
		_nest = best + normal.normalized() * 0.45
		against_wall = true
		out_of_wall = normal.normalized()
		_nest.y = maze.ground_height(_nest) if maze else ground
	global_position = _nest
	swarm.position = _nest
	add_child(swarm)
	swarm.global_position = _nest
	swarm.steer = _way_from
	swarm.overwhelmed.connect(_on_overwhelmed)


## Whether its crack is there yet (the frame after it goes in).
func nested() -> bool:
	return swarm != null and swarm.is_inside_tree()


## Where an imp at `from` makes for next, by the passages, after its quarry.
func _way_from(from: Vector3) -> Vector3:
	if quarry == null or not is_instance_valid(quarry) or nav == null:
		return from
	return nav.waypoint(from, quarry.global_position, MazeNav.clearance_for(0.2))


func _physics_process(delta: float) -> void:
	if not nested():
		return
	var near := nearest_player(_nest)
	var awake := near != null and near.global_position.distance_to(_nest) < active_range
	swarm.process_mode = Node.PROCESS_MODE_INHERIT if awake or swarm.out > 0 else Node.PROCESS_MODE_DISABLED
	if puppet:
		_follow_host()
		_hold_back_local()
		return
	if maze == null:
		return
	for player: Variant in _spared.keys():
		if not is_instance_valid(player):
			_spared.erase(player)
			continue
		_spared[player] -= delta
		if _spared[player] <= 0.0:
			_spared.erase(player)
	match mode:
		Mode.ASLEEP:
			_listen -= delta
			if _listen <= 0.0 and swarm.rested():
				_listen = 0.25
				var woken := _woken_by()
				if woken:
					wake_on(woken)
		Mode.WARN, Mode.HUNT:
			if quarry == null or not huntable(quarry) or maze.in_clearing(maze.cell_at(quarry.global_position)):
				swarm.recall()
			if swarm.mode == ImpSwarm.Mode.HUNT:
				mode = Mode.HUNT
			elif swarm.mode == ImpSwarm.Mode.HOME or swarm.mode == ImpSwarm.Mode.DORMANT:
				mode = Mode.HOME
				quarry = null
			_shake(quarry)
		Mode.HOME:
			if swarm.mode == ImpSwarm.Mode.DORMANT:
				mode = Mode.ASLEEP
	chasing = mode == Mode.WARN or mode == Mode.HUNT
	global_position = swarm.front() if swarm.out > 0 else _nest
	_hold_back_local()


## Who, if anyone, has woken them: anyone near the crack by the passages, or running in earshot.
func _woken_by() -> Node3D:
	var best: Node3D = null
	var nearest := INF
	var here := maze.cell_at(_nest)
	for player: Node3D in players():
		if not huntable(player) or maze.in_clearing(maze.cell_at(player.global_position)):
			continue
		var at := player.global_position
		var far := at.distance_to(_nest)
		var moving: Variant = player.get(&"velocity")
		var pace := Vector2((moving as Vector3).x, (moving as Vector3).z).length() if moving is Vector3 else 0.0
		var reach := wake_range
		if player.get(&"is_sprinting") == true or pace > 5.2:
			reach = wake_hear * 1.5
		elif pace > 3.0:
			reach = wake_hear
		if far > reach or far > nearest:
			continue
		var steps := nav.distance(here, maze.cell_at(at))
		if steps < 0 or steps * Maze.CELL > reach + Maze.CELL:
			continue
		nearest = far
		best = player
	return best


## Wakes them, after `player`.
func wake_on(player: Node3D) -> void:
	if puppet or not huntable(player) or not nested():
		return
	if mode == Mode.ASLEEP:
		spotted.emit(player)
	quarry = player
	_forget = 999.0
	swarm.target = player
	swarm.release()
	mode = Mode.WARN


## MazeEnemy.notice: anything that sets the others after someone wakes them too, if he is near.
func notice(player: Node3D) -> void:
	if mode == Mode.ASLEEP and player.global_position.distance_to(_nest) < wake_hear * 1.5:
		wake_on(player)


func alerted(_player: Node3D, _from: Vector3) -> void:
	pass


## A roll or a dive throws every one off him.
func _shake(who: Node3D) -> void:
	if who == null or not is_instance_valid(who):
		return
	var rolling: bool = who.get(&"is_diving") == true
	var landing: Variant = who.get(&"landing")
	if landing is int and landing == Player.Landing.ROLL and (who.get(&"landing_progress") as float) < 0.6:
		rolling = true
	if who.get(&"state") is int and who.get(&"state") == Player.State.SLIDE:
		rolling = true
	if rolling and not _rolled:
		swarm.shake_off()
	_rolled = rolling


func _on_overwhelmed(who: Node3D) -> void:
	if puppet or who == null or not huntable(who):
		return
	_catch(who)


## Imps on this machine's own player hold him back (after he has moved).
func _hold_back_local() -> void:
	if swarm.on_him <= 0 or swarm.target == null or not is_instance_valid(swarm.target) or not (swarm.target is Player):
		return
	var boy := swarm.target as Player
	var cap := boy.sprint_speed * maxf(1.0 - hold_back * swarm.on_him, slowest)
	var flat := Vector3(boy.velocity.x, 0.0, boy.velocity.z)
	if flat.length() > cap:
		flat = flat.normalized() * cap
		boy.velocity.x = flat.x
		boy.velocity.z = flat.z
	_shake(boy)


# --- Being run by someone else ---

func net_state() -> int:
	return mode


func net_point() -> Vector3:
	if chasing and quarry and is_instance_valid(quarry):
		return quarry.global_position
	return Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	_heard = true
	_heard_at = at
	_heard_moving = moving
	_heard_state = state
	_heard_extra = point
	mode = state as Mode
	chasing = mode == Mode.WARN or mode == Mode.HUNT


## As a puppet: lets them out after the player the host says, or calls them home.
func _follow_host() -> void:
	if not _heard:
		return
	if chasing:
		var who := nearest_player(_heard_extra) if _heard_extra.is_finite() else null
		if who and swarm.target != who:
			swarm.target = who
		quarry = who
		if not swarm.hunting() and who:
			swarm.release()
	elif swarm.hunting():
		swarm.recall()
	global_position = swarm.front() if swarm.out > 0 else _nest


func _put(at: Vector3, _facing: float) -> void:
	pass


func _puppet_changed() -> void:
	collision_layer = 0
	collision_mask = 0

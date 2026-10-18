class_name Bats
extends MazeEnemy
## A colony of bats in the maze: the maze's alarm. They catch nobody; they give
## you away.
##
## What they look like and how they fly is BatColony (creatures/bats/, a
## component that knows nothing of the maze); this is only what they think.
## This node is the colony as the game sees it: where it is (it flies along the
## passages, by MazeNav, at head height after someone and higher going home),
## what it is doing (`mode`), and who it is after (`quarry`). The bats whirl
## round wherever it says.
##
## - ROOST. Put in a cell, it finds the nearest wall face of that cell (a ray
##   at `roost_height`) and hangs there, asleep. Nothing wakes it but noise:
##   anyone running within `wake_hear` (sprinting, `wake_hear` and half again),
##   or anyone at all who comes within `wake_near` of the roost (passing right
##   under it, quietly). For `rest_time` after it has come home it is harder to
##   wake: only someone right under it does.
## - MOB. Awake, it bursts off the wall and goes after whoever woke it, by the
##   passages, as fast as anyone can sprint and more; the bats whirl round
##   their head and dive at their face. While they are near them it calls out
##   (every `call_every` seconds): everything else that hunts the maze within
##   `alarm_range` is told where that player is (MazeEnemy.notice; a Griever
##   is sent to look, Griever.alert), as if it had seen them itself.
## - It loses interest in `interest` seconds, faster (`hush`) while they stand
##   still or duck or crawl; and at once if they get `give_up` metres away by
##   the passages, go into the clearing, or out of the maze, or are caught.
## - RETURN. It flies home along the passages and the bats go back to their
##   places on the roost.
##
## As a puppet (online, not the host) it follows the host's news: where the
## colony is, what it is doing, and the point the bats whirl round
## (`net_point`). The roost is found from the cell it was put in, the same on
## every machine, and so are the bats (seeded by `seed_choices`).

enum Mode { ROOST, MOB, RETURN }

## How high up the wall it roosts.
@export var roost_height := 8.5
## How many bats.
@export var bat_count := 12
@export var wake_hear := 15.0
@export var wake_near := 5.0
@export var rest_time := 8.0
## How long it keeps after someone, and how many times faster that runs out while they keep still or low.
@export var interest := 15.0
@export var hush := 3.0
@export var give_up := 45.0
@export var alarm_range := 45.0
@export var call_every := 1.0
## How fast the colony goes after someone, and home.
@export var mob_speed := 8.5
@export var home_speed := 6.0

var mode := Mode.ROOST
var colony: BatColony
## Which way is out from the wall it roosts on.
var roost_out := Vector3.BACK

var _roost := Vector3.INF
var _home := Vector3.ZERO
var _colony_seed := 0
var _interest := 0.0
var _rest := 0.0
var _call := 0.0
var _whirl := Vector3.INF
var _far := false


func _init() -> void:
	# (it does not look about as the others do: see `_listen`)
	sight_range = 0.0
	hear_range = 0.0
	memory = 1.0
	pack = &"bats"
	look_every = 0.25


func seed_choices(value: int) -> void:
	super(value)
	_colony_seed = value


func _ready() -> void:
	add_to_group(&"pursuers")
	# Nothing bumps into it: it is a cloud.
	collision_layer = 0
	collision_mask = 0
	colony = BatColony.new()
	colony.name = "Colony"
	colony.count = bat_count
	colony.colony_seed = _colony_seed
	colony.keep_in = _keep_in
	add_child(colony)
	colony.top_level = true
	_home = global_position
	_find_roost.call_deferred()


## Finds the wall face nearest the middle of its cell, `roost_height` up, and hangs there.
func _find_roost() -> void:
	if not is_inside_tree():
		return
	var middle := global_position
	middle.y = roost_height
	var best := Vector3.INF
	var best_out := Vector3.BACK
	var space := get_world_3d().direct_space_state
	for step: Vector2i in Maze.STEPS:
		var way := Vector3(step.x, 0.0, step.y)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(middle, middle + way * Maze.CELL, 1))
		if hit.is_empty():
			continue
		var point: Vector3 = hit["position"]
		if best == Vector3.INF or middle.distance_to(point) < middle.distance_to(best):
			best = point
			best_out = -way
	if best == Vector3.INF:
		# (no wall found, as in a bare test: the near side of the cell)
		best = middle + Vector3.BACK * (Maze.CELL * 0.5 - MazeBuilder.WALL_THICK * 0.5)
		best_out = Vector3.FORWARD
	_roost = best
	roost_out = best_out
	colony.set_roost(best, best_out)
	colony.settle()
	_home = best + best_out * 3.0 + Vector3.DOWN * 2.5
	global_position = _home
	colony.global_position = best


## Whether it has found its roost (the frame after it goes in).
func roosted() -> bool:
	return _roost.is_finite()


func _physics_process(delta: float) -> void:
	if puppet:
		_follow_news(delta)
		return
	if maze == null or not roosted():
		return
	_rest -= delta
	match mode:
		Mode.ROOST:
			_look_in -= delta
			if _look_in <= 0.0:
				_look_in = look_every
				var woken := _listen()
				if woken:
					wake_on(woken)
		Mode.MOB:
			_mob(delta)
		Mode.RETURN:
			_go_home(delta)
	chasing = mode == Mode.MOB
	_drive_colony()


## Who, if anyone, has woken it: the nearest runner in earshot, or anyone right under it.
func _listen() -> Node3D:
	var best: Node3D = null
	var nearest := INF
	for player: Node3D in players():
		if not huntable(player) or maze.in_clearing(maze.cell_at(player.global_position)):
			continue
		var level := Vector2(player.global_position.x - _roost.x, player.global_position.z - _roost.z).length()
		var moving: Variant = player.get(&"velocity")
		var pace := Vector2((moving as Vector3).x, (moving as Vector3).z).length() if moving is Vector3 else 0.0
		var reach := 0.0
		if _rest <= 0.0:
			if player.get(&"is_sprinting") == true or pace > 5.2:
				reach = wake_hear * 1.5
			elif pace > 3.0:
				reach = wake_hear
		var close := wake_near if _rest <= 0.0 else wake_near * 0.5
		if level < maxf(reach, close) and level < nearest:
			nearest = level
			best = player
	return best


## Wakes it, after `player` (as running under it does).
func wake_on(player: Node3D) -> void:
	if puppet or not huntable(player):
		return
	if mode != Mode.MOB:
		spotted.emit(player)
	mode = Mode.MOB
	quarry = player
	_forget = memory
	_interest = interest
	_call = 0.4


## MazeEnemy.notice: anything that would set others hunting someone wakes it too.
func notice(player: Node3D) -> void:
	wake_on(player)


func alerted(player: Node3D, _from: Vector3) -> void:
	pass


func _mob(delta: float) -> void:
	var after := quarry
	if after == null or not huntable(after) or maze.in_clearing(maze.cell_at(after.global_position)):
		_give_up()
		return
	var flat := after.get(&"velocity") as Vector3 if after.get(&"velocity") is Vector3 else Vector3.ZERO
	var still := Vector2(flat.x, flat.z).length() < 0.6
	var low: bool = after.get(&"is_ducking") == true or after.get(&"is_crawling") == true
	var head := after.global_position + Vector3.UP * (1.0 if low else 1.65)
	# (keeping still or low only counts once they are round them, to see it)
	var round_them := global_position.distance_to(head) < 6.0
	_interest -= delta * ((hush if still or low else 1.0) * (2.0 if still and low else 1.0) if round_them else 1.0)
	var steps := nav.distance(maze.cell_at(global_position), maze.cell_at(after.global_position))
	if _interest <= 0.0 or steps < 0 or steps * Maze.CELL > give_up:
		_give_up()
		return
	_fly_to(head, mob_speed, delta)
	# (they whirl round them where they can be seen from here; round the corner, round this)
	_whirl = head if nav.sees(global_position, head) and global_position.distance_to(head) < 12.0 else global_position
	_call -= delta
	if _call <= 0.0 and global_position.distance_to(head) < 10.0:
		_call = call_every
		_raise_alarm(after)


## Everything else that hunts within `alarm_range` is told where `player` is.
func _raise_alarm(player: Node3D) -> void:
	for other: Node in get_tree().get_nodes_in_group(&"maze_enemies"):
		if other == self or not (other is MazeEnemy) or other is Bats or (other as MazeEnemy).puppet:
			continue
		if (other as Node3D).global_position.distance_to(global_position) < alarm_range:
			(other as MazeEnemy).notice(player)
	for griever: Node in get_tree().get_nodes_in_group(&"grievers"):
		if griever.has_method(&"alert") and (griever as Node3D).global_position.distance_to(global_position) < alarm_range:
			griever.call(&"alert", player.global_position)


func _give_up() -> void:
	mode = Mode.RETURN
	quarry = null
	_forget = 0.0


func _go_home(delta: float) -> void:
	var to_home := _home - global_position
	if to_home.length() < 2.5:
		mode = Mode.ROOST
		_rest = rest_time
		return
	_fly_to(_home if Vector2(to_home.x, to_home.z).length() < 4.0 else Vector3(_home.x, 5.0, _home.z), home_speed, delta)
	_whirl = global_position


## Flies the colony's middle towards `goal` by the passages, at up to `pace`.
func _fly_to(goal: Vector3, pace: float, delta: float) -> void:
	var next := nav.waypoint(global_position, goal, MazeNav.clearance_for(0.8))
	next.y = goal.y
	var to := next - global_position
	var wish := to.limit_length(pace) if to.length() > 0.05 else Vector3.ZERO
	velocity = velocity.move_toward(wish, 30.0 * delta)
	global_position += velocity * delta


## What the bats are told: awake or not, and what to whirl round.
func _drive_colony() -> void:
	colony.awake = mode != Mode.ROOST
	colony.target = _whirl if mode != Mode.ROOST else Vector3.INF


## Keeps a bat's goal in the passage: off the walls' faces (pulled in towards
## the colony's middle, which is in the passage), and off the ground.
func _keep_in(point: Vector3) -> Vector3:
	if maze == null or nav == null:
		return point
	point.y = clampf(point.y, 0.7, roost_height + 2.0)
	var middle := global_position
	for k in 4:
		if nav.clear_of_walls(point, 0.5):
			return point
		point = point.lerp(Vector3(middle.x, point.y, middle.z), 0.5)
	return Vector3(middle.x, point.y, middle.z)


# --- Being run by someone else ---

func yaw() -> float:
	return 0.0


func net_state() -> int:
	return mode


func net_point() -> Vector3:
	return _whirl if mode != Mode.ROOST else Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode == Mode.MOB


func _follow_news(delta: float) -> void:
	if not _heard:
		return
	_heard_at += _heard_moving * delta
	global_position = global_position.lerp(_heard_at, 1.0 - exp(-6.0 * delta))
	if global_position.distance_to(_heard_at) > 6.0:
		global_position = _heard_at
	_whirl = _heard_extra if _heard_extra.is_finite() else global_position
	if roosted():
		_drive_colony()


func _put(at: Vector3, _facing: float) -> void:
	global_position = at


func _puppet_changed() -> void:
	collision_layer = 0
	collision_mask = 0

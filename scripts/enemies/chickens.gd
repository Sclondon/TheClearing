class_name Chickens
extends MazeEnemy
## A flock of feral chickens loose in the maze: another of its alarms. Like the
## bats they catch nobody; their racket gives you away, so you creep past them.
##
## What they look like and how they go about is ChickenFlock
## (creatures/chicken/, a component that knows nothing of the maze); this is
## only what the flock thinks. This node is the flock as the game sees it: it
## stands where the birds are (their middle), says what they are doing
## (`mode`), and who they are after (`quarry`).
##
## - FORAGE. Put in a cell, they peck and scratch about it (within `roam` of the
##   middle). Anyone walking near steps them a little way off, clucking; but
##   anyone running within `startle_hear` of a bird (sprinting, half as far
##   again), or walking upright within `startle_near` of one, or coming within
##   `touch` even crouched, startles the flock.
## - PANIC. They explode, squawking, every way from whoever did it, some up into
##   the air; feathers fly. The racket calls every hunter within `alarm_range`
##   to them (MazeEnemy.notice; a Griever is sent to look, Griever.alert), at
##   once and every `call_every` seconds for `racket_time`. Then they settle
##   and drift home.
## - MOB. Run into one of them (within `touch` of a bird, moving) and the
##   rooster flies into a rage: the whole flock goes for you, leaping and
##   beating round your head, pecking (hard to see, and you are slowed while
##   they are on you: `slowed_to` of your speed). The racket calls the hunters
##   all the while. They let you go after `mob_time`, or if you get `give_up`
##   metres away by the passages, or into the clearing, or out.
##
## As a puppet (online, not the host) it follows the host's news: what the
## flock is doing and the point it goes with that (where the scare came from,
## the head they are mobbing). The birds are seeded by `seed_choices`, so every
## machine has the same ones in the same cell; how each forages is its own.

enum Mode { FORAGE, PANIC, MOB }

@export var roam := 5.0
@export var startle_hear := 9.0
@export var startle_near := 3.0
@export var touch := 0.6
@export var racket_time := 3.0
@export var alarm_range := 40.0
@export var call_every := 1.0
@export var mob_time := 7.0
@export var give_up := 25.0
@export_range(0.2, 1.0) var slowed_to := 0.6

var mode := Mode.FORAGE
var flock: ChickenFlock

var _home := Vector3.ZERO
var _flock_seed := 0
var _racket := 0.0
var _call := 0.0
var _point := Vector3.INF
var _mob_left := 0.0
var _calm_in := 0.0


func _init() -> void:
	# (it does not look about as the others do: see `_listen`)
	sight_range = 0.0
	hear_range = 0.0
	memory = 1.0
	pack = &"chickens"
	look_every = 0.15


func seed_choices(value: int) -> void:
	super(value)
	_flock_seed = value


func _ready() -> void:
	add_to_group(&"pursuers")
	# Nothing bumps into it: it is a flock of birds.
	collision_layer = 0
	collision_mask = 0
	_home = global_position
	var choose := RandomNumberGenerator.new()
	choose.seed = _flock_seed
	flock = ChickenFlock.new()
	flock.name = "Flock"
	flock.flock_seed = _flock_seed
	flock.count = choose.randi_range(8, 13)
	flock.roosters = 1
	flock.home = Vector3(_home.x, maze.ground_height(_home) if maze else _home.y, _home.z)
	flock.roam = roam
	flock.keep_in = _keep_in
	if maze:
		flock.ground_height = maze.ground_height
	add_child(flock)
	flock.top_level = true
	flock.global_transform = Transform3D.IDENTITY


## Whether anyone is being mobbed.
func mobbing() -> bool:
	return mode == Mode.MOB


func _physics_process(delta: float) -> void:
	if puppet:
		_follow_news(delta)
		return
	if maze == null:
		return
	global_position = flock.centre()
	match mode:
		Mode.FORAGE:
			_look_in -= delta
			if _look_in <= 0.0:
				_look_in = look_every
				_listen()
		Mode.PANIC:
			_racket -= delta
			_call -= delta
			if _call <= 0.0 and _racket > 0.0:
				_call = call_every
				_raise_alarm(quarry)
			_calm_in -= delta
			if _calm_in <= 0.0 and flock.panicking() == 0:
				mode = Mode.FORAGE
				quarry = null
			# (startled again while still in a flap: on with the racket)
			_look_in -= delta
			if _look_in <= 0.0:
				_look_in = look_every
				_listen()
		Mode.MOB:
			_mob(delta)
	chasing = mode == Mode.MOB


## Who, if anyone, has startled them (or run into one), from what each player is doing.
func _listen() -> void:
	var uneasy := PackedVector3Array()
	for player: Node3D in players():
		if not huntable(player) or _off_limits(player):
			continue
		var at := player.global_position
		var nearest := _nearest_bird(at)
		var moving: Variant = player.get(&"velocity")
		var pace := Vector2((moving as Vector3).x, (moving as Vector3).z).length() if moving is Vector3 else 0.0
		var low: bool = player.get(&"is_ducking") == true or player.get(&"is_crawling") == true
		var sprinting: bool = player.get(&"is_sprinting") == true or pace > 5.2
		if nearest < 6.0:
			uneasy.append(at)
		if nearest < touch and pace > 0.3:
			start_mob(player)
			return
		var reach := 0.0
		if sprinting:
			reach = startle_hear * 1.5
		elif pace > 3.0:
			reach = startle_hear
		elif pace > 0.4 and not low:
			reach = startle_near
		else:
			reach = touch * 1.6
		if nearest < reach:
			startle(player)
			return
	flock.uneasy = uneasy


# How far `at` is from the nearest bird, on the level.
func _nearest_bird(at: Vector3) -> float:
	var best := INF
	for i in flock.count:
		var bird := flock.bird_position(i)
		best = minf(best, Vector2(bird.x - at.x, bird.z - at.z).length())
	return best


# Players in the clearing are let alone (unless the flock is in it too, as the dev tools can put it).
func _off_limits(player: Node3D) -> bool:
	return maze.in_clearing(maze.cell_at(player.global_position)) and not maze.in_clearing(maze.cell_at(_home))


## Startles the flock, from `player` (as running near them does). They panic
## and the racket goes up.
func startle(player: Node3D) -> void:
	if puppet or mode == Mode.MOB:
		return
	var first := mode != Mode.PANIC
	mode = Mode.PANIC
	quarry = player
	_point = player.global_position
	flock.scare(_point)
	_racket = racket_time
	_calm_in = 2.5
	if first:
		spotted.emit(player)
		_call = call_every
		_raise_alarm(player)


## The rooster's rage: the flock mobs `player`.
func start_mob(player: Node3D) -> void:
	if puppet or not huntable(player):
		return
	if mode != Mode.MOB:
		spotted.emit(player)
		_raise_alarm(player)
	mode = Mode.MOB
	quarry = player
	_mob_left = mob_time
	_call = call_every


## MazeEnemy.notice: anything that would set others hunting someone startles them too.
func notice(player: Node3D) -> void:
	if mode == Mode.FORAGE and huntable(player):
		startle(player)


func alerted(_player: Node3D, _from: Vector3) -> void:
	pass


func _mob(delta: float) -> void:
	var after := quarry
	if after == null or not huntable(after) or _off_limits(after):
		_end_mob()
		return
	var head := _head_of(after)
	_point = head
	flock.mob_target = head
	_mob_left -= delta
	var steps := nav.distance(maze.cell_at(_home), maze.cell_at(after.global_position))
	if _mob_left <= 0.0 or steps < 0 or steps * Maze.CELL > give_up:
		_end_mob()
		return
	_call -= delta
	if _call <= 0.0:
		_call = call_every
		_raise_alarm(after)
	# On them, the birds slow them down.
	if _nearest_bird(after.global_position) < 1.2:
		slow(after, slowed_to, 0.4)


func _end_mob() -> void:
	mode = Mode.PANIC
	flock.mob_target = Vector3.INF
	_racket = 0.0
	_calm_in = 1.5
	quarry = null


func _head_of(player: Node3D) -> Vector3:
	var low: bool = player.get(&"is_ducking") == true or player.get(&"is_crawling") == true
	return player.global_position + Vector3.UP * (0.9 if low else 1.5)


## Everything else that hunts within `alarm_range` is told where `player` is.
func _raise_alarm(player: Node3D) -> void:
	if player == null or not is_instance_valid(player):
		return
	for other: Node in get_tree().get_nodes_in_group(&"maze_enemies"):
		if other == self or not (other is MazeEnemy) or other is Chickens or other is Bats or (other as MazeEnemy).puppet:
			continue
		if (other as Node3D).global_position.distance_to(global_position) < alarm_range:
			(other as MazeEnemy).notice(player)
	for griever: Node in get_tree().get_nodes_in_group(&"grievers"):
		if griever.has_method(&"alert") and (griever as Node3D).global_position.distance_to(global_position) < alarm_range:
			griever.call(&"alert", player.global_position)


## Keeps a bird in the passages: off the walls' faces (pulled in towards home,
## which is in a passage).
func _keep_in(point: Vector3) -> Vector3:
	if maze == null or nav == null:
		return point
	# (not into the clearing, unless home is in it)
	if maze.in_clearing(maze.cell_at(point)) and not maze.in_clearing(maze.cell_at(_home)):
		point = point.lerp(Vector3(_home.x, point.y, _home.z), 0.3)
	for k in 5:
		if nav.clear_of_walls(point, 0.35):
			return point
		point = point.lerp(Vector3(_home.x, point.y, _home.z), 0.4)
	return Vector3(_home.x, point.y, _home.z)


## Slows a Player to `share` of their speed for `seconds` (kept up while it is
## called again). Anything else with a `slow(share, seconds)` of its own is asked to.
static func slow(player: Node3D, share: float, seconds: float) -> void:
	if player.has_method(&"slow"):
		player.call(&"slow", share, seconds)
		return
	if not (player is Player):
		return
	var held := player.get_node_or_null(^"ChickenSlowed") as Slowed
	if held:
		held.left = maxf(held.left, seconds)
		return
	held = Slowed.new()
	held.name = "ChickenSlowed"
	held.share = share
	held.left = seconds
	player.add_child(held)


## What slows a Player while chickens are round their head: their speeds cut,
## and given back when it goes.
class Slowed extends Node:
	var left := 0.4
	var share := 0.6
	var _was := Vector3.ZERO

	func _ready() -> void:
		var player := get_parent() as Player
		_was = Vector3(player.walk_speed, player.run_speed, player.sprint_speed)
		player.walk_speed = _was.x * share
		player.run_speed = _was.y * share
		player.sprint_speed = _was.z * share

	func _process(delta: float) -> void:
		left -= delta
		if left <= 0.0:
			queue_free()

	func _exit_tree() -> void:
		var player := get_parent() as Player
		if player:
			player.walk_speed = _was.x
			player.run_speed = _was.y
			player.sprint_speed = _was.z


# --- Being run by someone else ---

func yaw() -> float:
	return 0.0


func net_state() -> int:
	return mode


func net_point() -> Vector3:
	return _point if mode != Mode.FORAGE else Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	var was := mode
	mode = state as Mode
	chasing = mode == Mode.MOB
	if flock == null:
		return
	if mode == Mode.PANIC and was != Mode.PANIC and point.is_finite():
		flock.scare(point)
	if mode == Mode.MOB and point.is_finite():
		flock.mob_target = point
	elif was == Mode.MOB:
		flock.mob_target = Vector3.INF


func _follow_news(delta: float) -> void:
	if not _heard:
		return
	global_position = global_position.lerp(_heard_at, 1.0 - exp(-6.0 * delta))


func _put(at: Vector3, _facing: float) -> void:
	global_position = at


func _puppet_changed() -> void:
	collision_layer = 0
	collision_mask = 0

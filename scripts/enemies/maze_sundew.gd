class_name MazeSundew
extends MazeEnemy
## A giant sundew (creatures/carnivorous_plants/, `Sundew`): a rosette of long
## red leaves lying out over the floor of a hall, glistening with glue. It never
## moves and catches nobody, but it holds you.
##
## - IT STICKS. Walk onto its leaves and the glue drags at your feet: you are
##   slowed (by up to `slow_share`, the thicker the leaves under you the more).
## - IT HOLDS. Stay on them `hold_delay` and its tentacles bend over you and its
##   leaves curl in: for `hold_time` you can hardly move (`held_share`). Jumping
##   tears you free sooner (each jump takes `struggle` seconds off). Then it lets
##   go, and cannot take hold of you again for `free_time`: walk off it.
##   Held, you are easy meat for anything else in the hall.
## - IT EATS what is small (Ecology: creatures up to `prey_size` big) that it
##   holds `kill_time`.
##
## It slows only the player this machine plays (each machine its own), and
## bends over whoever stands in it on every machine alike, so nothing of it is
## sent but what the host's copy holds (`net_point`). Spawn as MazeEnemies.add
## does; put in the middle of a cell, it grows `off_wall` out from one of its walls.

## How much bigger than it is modelled it is drawn.
const SIZE := 1.1

@export var slow_share := 0.5
@export var held_share := 0.9
@export var hold_delay := 1.1
@export var hold_time := 2.4
@export var struggle := 0.7
@export var free_time := 3.0
@export var kill_time := 4.0
@export var prey_size := 1
@export var off_wall := 2.6
## Which of its cell's walls it grows against, and where along it (any number; -1: as its place in the maze picks).
@export var wall_pick := -1

var figure: Sundew
## The player this machine plays, while it is in the glue: how long, how much
## longer it is held, and how long until it can be held again.
var glued := 0.0
var held_left := 0.0
var free_in := 0.0

var _stuck: Node3D
var _jumped := false
var _prey: MazeEnemy
var _prey_time := 0.0
var _check_in := 0.0


func _init() -> void:
	sight_range = 0.0
	hear_range = 0.0
	memory = 0.0
	pack = &"sundews"
	look_every = 0.2


func _ready() -> void:
	var placed := MazePlants.by_wall(maze, global_position, rotation.y, off_wall, wall_pick if wall_pick >= 0 else int(absf(global_position.x * 5.0 + global_position.z * 3.0)))
	global_position = placed[0]
	rotation.y = placed[1]
	# (it lies on the ground: nothing bumps into it)
	collision_layer = 0
	collision_mask = 0
	figure = Sundew.new()
	figure.scale = Vector3.ONE * SIZE
	add_child(figure)


func _exit_tree() -> void:
	if _stuck and is_instance_valid(_stuck):
		MazePlants.weigh(_stuck, self, 0.0)


func _physics_process(delta: float) -> void:
	_stick(delta)
	_check_in -= delta
	if _check_in <= 0.0:
		_check_in = look_every
		_bend()
	if puppet or _prey == null:
		return
	# (what small thing it holds, it kills in time)
	if not is_instance_valid(_prey) or _prey.dead or figure.sticky(_prey.global_position) < 0.2:
		_prey = null
		return
	_prey_time += delta
	if _prey_time > kill_time and Ecology.current:
		Ecology.current.kill(_prey, self)
		_prey = null


## The glue on the player this machine plays.
func _stick(delta: float) -> void:
	var me := local_player()
	if me != _stuck:
		if _stuck and is_instance_valid(_stuck):
			MazePlants.weigh(_stuck, self, 0.0)
			if _stuck.is_connected(&"jumped", _on_jumped):
				_stuck.disconnect(&"jumped", _on_jumped)
		_stuck = me
		if me:
			me.jumped.connect(_on_jumped)
	free_in -= delta
	if me == null:
		return
	var thick := figure.sticky(me.global_position) if me.is_on_floor() or held_left > 0.0 else 0.0
	var share := 0.0
	if held_left > 0.0:
		held_left -= delta
		if _jumped:
			held_left -= struggle
			figure.unstick()
		if held_left <= 0.0:
			free_in = free_time
			glued = 0.0
			figure.unstick()
		share = held_share
	elif thick > 0.15:
		glued += delta
		share = slow_share * clampf(thick * 1.3, 0.0, 1.0) * (0.5 if free_in > 0.0 else 1.0)
		if glued > hold_delay and free_in <= 0.0:
			held_left = hold_time
			share = held_share
	else:
		glued = 0.0
	_jumped = false
	MazePlants.weigh(me, self, share)


func _on_jumped() -> void:
	_jumped = true


## Bends over whoever stands in it (or what small thing it has).
func _bend() -> void:
	var over := Vector3.INF
	var best := 0.15
	for player: Node3D in players():
		if is_instance_valid(player) and player.is_inside_tree():
			var thick := figure.sticky(player.global_position)
			if thick > best:
				best = thick
				over = player.global_position + Vector3.UP * 0.35
	if not puppet:
		if _prey == null:
			for one in MazePlants.creatures_near(get_tree(), global_position, Sundew.REACH * SIZE + 1.0, prey_size):
				if figure.sticky((one as Node3D).global_position) > 0.3:
					_prey = one
					_prey_time = 0.0
					break
		if _prey and over == Vector3.INF:
			over = _prey.global_position + Vector3.UP * 0.2
	elif _heard_extra.is_finite() and over == Vector3.INF:
		over = _heard_extra
	if over.is_finite():
		figure.hold(over)
	elif figure.held.is_finite():
		figure.let_go()
	chasing = over.is_finite()


# --- Being run by someone else ---

func yaw() -> float:
	return rotation.y


func net_state() -> int:
	return 1 if figure and figure.held.is_finite() else 0


func net_point() -> Vector3:
	return figure.held if figure else Vector3.INF


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	rotation.y = facing

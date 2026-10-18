class_name MazePitcher
extends MazeEnemy
## A giant pitcher plant (creatures/carnivorous_plants/, `Pitcher`) sunk to its
## mouth in the mud at the foot of a wall: a hole a metre and a half across in
## the floor of the hall, ringed by a ribbed, striped, wet lip that slopes down
## into it, black fluid inside, its lid held up over it, flies buzzing about it
## (it is in `fly_carrion`). It never moves.
##
## - STEP ON THE LIP AND YOU GO IN. Whoever walks (or lands) onto its mouth slips
##   in and is caught (`caught(player)`); the lid drops over it with a gulp, and
##   the fluid churns a while (`fed_time`), then the lid lifts (`open_time`). It
##   is a hole: it takes whoever steps on it, fed or not. Walk round it.
## - IT EATS what wanders onto it (Ecology: creatures up to `prey_size` big),
##   and is fed longer on them (`digest_time`), taking no more creatures meanwhile.
##
## Online, the host thinks for it; guests' copies drop and lift the lid as its
## state says. Spawn as MazeEnemies.add does; put in the middle of a cell, it
## grows `off_wall` out from one of its walls, sloping down towards the hall.

enum Mode { OPEN, FED, DIGESTING }

## How much bigger than it is modelled it is drawn.
const SIZE := 1.1

@export var fed_time := 6.0
@export var open_time := 5.0
@export var digest_time := 45.0
@export var prey_size := 2
@export var off_wall := 1.5
## Which of its cell's walls it grows against, and where along it (any number; -1: as its place in the maze picks).
@export var wall_pick := -1

var mode := Mode.OPEN
var figure: Pitcher
## How many it has swallowed (sent, so that a guest's copy gulps each time).
var swallows := 0

var _mode_time := 0.0
var _heard_acts := false


func _init() -> void:
	sight_range = 0.0
	hear_range = 0.0
	memory = 0.0
	pack = &"pitchers"
	look_every = 0.1
	spare_time = 4.0


func _ready() -> void:
	var placed := MazePlants.by_wall(maze, global_position, rotation.y, off_wall, wall_pick if wall_pick >= 0 else int(absf(global_position.x * 2.0 + global_position.z * 7.0)))
	global_position = placed[0]
	rotation.y = placed[1]
	# (a hole in the ground: nothing to bump into)
	collision_layer = 0
	collision_mask = 0
	figure = Pitcher.new()
	figure.scale = Vector3.ONE * SIZE
	add_child(figure)
	set_meta(&"carrion_radius", 1.3)
	set_meta(&"carrion_height", 0.8)
	add_to_group(&"fly_carrion")


func _physics_process(delta: float) -> void:
	if puppet or maze == null:
		return
	_mode_time += delta
	for player: Variant in _spared.keys():
		if not is_instance_valid(player):
			_spared.erase(player)
			continue
		_spared[player] -= delta
		if _spared[player] <= 0.0:
			_spared.erase(player)
	_look_in -= delta
	if _look_in <= 0.0:
		_look_in = look_every
		_look()
	if mode != Mode.OPEN and _mode_time > (digest_time if mode == Mode.DIGESTING else fed_time):
		figure.open_lid(open_time)
		_set_mode(Mode.OPEN)


## Whoever is on its lip goes in; and, if it is not still at one, a creature.
func _look() -> void:
	var took := false
	for player: Node3D in players():
		if huntable(player) and _on_lip(player):
			_catch(player)
			took = true
	if took:
		_swallow(Mode.DIGESTING if mode == Mode.DIGESTING else Mode.FED)
		return
	if mode == Mode.DIGESTING:
		return
	for one in MazePlants.creatures_near(get_tree(), global_position, 3.0, prey_size):
		if figure.over_mouth((one as Node3D).global_position, 0.1, 0.8) and Ecology.current:
			Ecology.current.kill(one as MazeEnemy, self)
			_swallow(Mode.DIGESTING)
			return


func _swallow(next: Mode) -> void:
	swallows += 1
	figure.swallow()
	_set_mode(next)


## Whether someone is standing (or landing) on its mouth.
func _on_lip(player: Node3D) -> bool:
	return figure.over_mouth(player.global_position, 0.05, 0.7)


func _set_mode(next: Mode) -> void:
	mode = next
	_mode_time = 0.0
	chasing = next != Mode.OPEN


# --- Being run by someone else ---

func yaw() -> float:
	return rotation.y


func net_state() -> int:
	return mode


## How many it has swallowed (low seven bits).
func net_flag() -> int:
	return swallows & 0x7f


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	var count := flag & 0x7f
	if not _heard_acts:
		_heard_acts = true
		figure.set_shut(state != Mode.OPEN)
	elif count != swallows & 0x7f:
		figure.swallow()
	swallows = count


func _heard_changed(was: int, now: int, first: bool) -> void:
	mode = now as Mode
	if not first and now == Mode.OPEN and was != Mode.OPEN:
		figure.open_lid(open_time)


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	rotation.y = facing

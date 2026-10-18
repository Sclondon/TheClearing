class_name MazeFlytrap
extends MazeEnemy
## A giant Venus flytrap (creatures/carnivorous_plants/, `Flytrap`) growing at
## the foot of a wall, its trap held out over the floor of the hall. It never
## moves. This is only its thinking; how it looks and sounds is the component.
##
## - IT WAITS, OPEN. Its two halves lie open in a V on the ground, red inside,
##   three trigger hairs on each, long pale teeth round the rims, nectar
##   glistening along them, and flies buzzing over it (it is in `fly_carrion`).
## - A TOUCH, AND IT SHIVERS. Whoever steps in between its halves brushes a
##   hair: the trap shivers, half shuts and opens again with a dry creak (the
##   warning). Step out at once.
## - THEN IT SNAPS. Anyone (or anything) still in it `snap_delay` after the
##   touch is caught as it slams shut (`caught(player)` for a player). Running
##   through it is quick enough: you are out before it shuts.
## - IT OPENS AGAIN SLOWLY. Shut on a player, it holds a moment (`hold_time`)
##   and opens over `reopen_time`; on nothing, the same, sooner; shut on a
##   creature of the maze (Ecology: anything up to `prey_size` big), it kills it,
##   bulges and goes dull, and digests it for `digest_time` before it opens.
##   While shut it takes nobody.
##
## Online, the host thinks for it and the others' copies are puppets: each
## shiver and snap, and whether it is full, is sent with its state (`net_flag`)
## and played out here too. Catching and killing are the host's alone.
##
## Spawn as MazeEnemies.add does. Put in the middle of a cell, it grows back
## against one of the cell's walls (MazePlants.by_wall), its trap out into the
## hall; anywhere else it grows where it is put, its trap ahead of it.

enum Mode { OPEN, TOUCHED, SHUT, DIGESTING, REOPENING }

## How much bigger than it is modelled it is drawn.
const SIZE := 1.15
## From the rosette (at the wall) to the middle of its trap, as modelled.
const REACH := 1.95

## After a touch, how long before it snaps on whatever is still in it.
@export var snap_delay := 0.75
## Shut on someone, or on nothing: how long it stays shut before it opens, and how long opening takes.
@export var hold_time := 3.0
@export var reopen_time := 9.0
@export var missed_hold := 1.5
@export var missed_reopen := 5.0
## Shut on a creature: how long it digests it.
@export var digest_time := 60.0
## The biggest creature it can take (Ecology's sizes).
@export var prey_size := 2
## How far the rosette stands out from the wall's face, metres.
@export var off_wall := 0.6
## Which of its cell's walls it grows against, and where along it (any number; -1: as its place in the maze picks).
@export var wall_pick := -1

var mode := Mode.OPEN
var figure: Flytrap

var _mode_time := 0.0
var _twitches := 0
var _snaps := 0
var _heard_acts := false
var _catch_open := false


func _init() -> void:
	sight_range = 0.0
	hear_range = 0.0
	memory = 0.0
	pack = &"flytraps"
	look_every = 0.1
	spare_time = 4.0


func _ready() -> void:
	var placed := MazePlants.by_wall(maze, global_position, rotation.y, off_wall + REACH * SIZE, wall_pick if wall_pick >= 0 else int(absf(global_position.x * 3.0 + global_position.z * 5.0)))
	global_position = placed[0]
	rotation.y = placed[1]
	# (the rosette at the wall is all of it that is in the way: the trap is to be stepped into)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.6
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0.0, 0.8, -REACH * SIZE)
	add_child(collider)
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 0
	figure = Flytrap.new()
	figure.scale = Vector3.ONE * SIZE
	figure.position = Vector3(0.0, 0.0, -REACH * SIZE)
	add_child(figure)
	figure.snapped.connect(_on_snapped)
	set_meta(&"carrion_radius", 1.4)
	set_meta(&"carrion_height", 0.9)
	add_to_group(&"fly_carrion")


func _physics_process(delta: float) -> void:
	if puppet or maze == null:
		return
	_mode_time += delta
	# (whoever it caught is let alone a while)
	for player: Variant in _spared.keys():
		if not is_instance_valid(player):
			_spared.erase(player)
			continue
		_spared[player] -= delta
		if _spared[player] <= 0.0:
			_spared.erase(player)
	match mode:
		Mode.OPEN:
			_look_in -= delta
			if _look_in <= 0.0:
				_look_in = look_every
				if not _in_it().is_empty():
					_set_mode(Mode.TOUCHED)
					_twitches += 1
					figure.twitch()
		Mode.TOUCHED:
			if _mode_time >= snap_delay:
				if _in_it().is_empty():
					_set_mode(Mode.OPEN)
				else:
					_snaps += 1
					_catch_open = true
					figure.snap()
					_set_mode(Mode.SHUT)
		Mode.SHUT:
			if not figure.is_snapping() and _mode_time > (hold_time if _catch_open else missed_hold) + Flytrap.SNAP_TIME:
				_open_again(reopen_time)
		Mode.DIGESTING:
			if _mode_time > digest_time:
				_open_again(reopen_time)
		Mode.REOPENING:
			if figure.is_open():
				_set_mode(Mode.OPEN)


func _set_mode(next: Mode) -> void:
	mode = next
	_mode_time = 0.0
	chasing = next == Mode.TOUCHED


func _open_again(seconds: float) -> void:
	figure.reopen(seconds)
	_set_mode(Mode.REOPENING)


## Who and what is between its halves now: players it may take, and creatures it could eat.
func _in_it(slack := 0.0) -> Array:
	var found: Array = []
	for player: Node3D in players():
		if huntable(player) and figure.inside(player.global_position + Vector3.UP * 0.4, 0.15 + slack):
			found.append(player)
	for one in MazePlants.creatures_near(get_tree(), global_position, 4.0, prey_size):
		if figure.inside((one as Node3D).global_position + Vector3.UP * 0.3, 0.2 + slack):
			found.append(one)
	return found


## Shut: whoever is still in it is caught; a creature is killed, and digested.
func _on_snapped() -> void:
	if puppet:
		return
	var took_player := false
	var took_creature := false
	for one: Node3D in _in_it(0.15):
		if one is MazeEnemy and not one.is_in_group(&"maze_players"):
			if Ecology.current and not took_creature:
				Ecology.current.kill(one as MazeEnemy, self)
				took_creature = true
		else:
			_catch(one)
			took_player = true
	_catch_open = took_player
	if took_creature:
		figure.full = true
		_set_mode(Mode.DIGESTING)
	elif not took_player:
		_catch_open = false


# --- Being run by someone else ---

func yaw() -> float:
	return rotation.y


func net_state() -> int:
	return mode


## Its shivers (low four bits), its snaps (the next three), and whether it is full (the top bit).
func net_flag() -> int:
	return (_twitches & 0x0f) | ((_snaps & 0x07) << 4) | (0x80 if figure and figure.full else 0)


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	var twitches := flag & 0x0f
	var snaps := (flag >> 4) & 0x07
	if not _heard_acts:
		_heard_acts = true
		figure.set_shut(state in [Mode.SHUT, Mode.DIGESTING])
	else:
		if twitches != _twitches & 0x0f:
			figure.twitch()
		if snaps != _snaps & 0x07:
			figure.snap()
	_twitches = twitches
	_snaps = snaps
	figure.full = flag & 0x80 != 0


func _heard_changed(_was: int, now: int, first: bool) -> void:
	mode = now as Mode
	if first:
		return
	if mode == Mode.REOPENING:
		figure.reopen(reopen_time)
	elif mode == Mode.OPEN and not figure.is_open():
		figure.reopen(1.0)


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	rotation.y = facing


func _puppet_changed() -> void:
	if is_inside_tree():
		collision_layer = PUPPET_LAYER if puppet else 4

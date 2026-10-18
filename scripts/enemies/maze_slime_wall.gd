class_name MazeSlimeWall
extends MazeEnemy
## A slime wall (SlimeWall, creatures/slime_wall/) let loose in the maze.
##
## It fills the passage it is in from wall to wall, so there is no getting past
## it: whoever meets one in a hall has to go round another way. It is slow,
## slower than a walk; it creeps about the passages, and when it notices
## someone (MazeEnemy's senses) it comes after them by the passages for a long
## time, squeezing through the gaps between rings, and swelling towards them
## as it comes near.
##
## It catches by touch. Whoever is in it is drawn in and held up inside it,
## turning slowly among the bones, for HOLD seconds, and only then `caught`.
## On this machine's own player that is shown (he is stopped while it lasts);
## a guest's copy of it shows the same to the guest's player when it reaches
## them, while the host, which does the catching, waits the same time.
##
## As a puppet it follows the host's news (MazeEnemy), and fits itself to the
## passage where it is, as the host's does, so the two look alike.

## Seconds it holds someone before they are caught.
const HOLD := 1.8
## Its speed creeping about, and going after someone (a walk is about 2).
@export var creep_speed := 0.75
@export var hunt_speed := 1.4
@export var turn_rate := 1.1
## How tall and deep, how wide where nothing hems it in, and the widest it fills (see SlimeWall).
@export var height := 9.0
@export var depth := 5.0
@export var width := 12.0
@export var max_width := 30.0
## Further than this from every player it is not drawn or moved about.
@export var pose_range := 100.0
@export var gravity := 24.0

enum Mode { CREEPING, HUNTING, HOLDING }

## How it looks: the creature this drives.
var creature: SlimeWall
var mode := Mode.CREEPING
var facing_yaw := 0.0

var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
## Whoever it has, and how long until they count as caught.
var _taking := {}
## This machine's player, while it holds him: and how he was going before.
var _held_local: Node3D
var _held_mode := Node.PROCESS_MODE_INHERIT
var _held_figure: Node3D
var _engulfs := 0
var _far := false
var _far_check := 0.0


func _init() -> void:
	sight_range = 40.0
	hear_range = 8.0
	memory = 30.0
	alert_range = 0.0
	spare_time = 3.0
	pack = &"slime_walls"


func _ready() -> void:
	add_to_group(&"pursuers")
	# Nothing bumps into it (touching it is being caught); only the world stops it.
	collision_layer = 0
	collision_mask = 1
	floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	shape.radius = 0.6
	shape.height = 2.0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 1.0
	add_child(collider)
	creature = SlimeWall.new()
	creature.name = "Slime"
	creature.height = height
	creature.depth = depth
	creature.width = width
	# (the first ring's avenues are some 25 m between walls; it fills them too)
	creature.max_width = max_width
	creature.contents_count = 40
	creature.contents_seed = _rng.randi_range(1, 1 << 20)
	creature.top_level = true
	add_child(creature)
	creature.released.connect(_on_released)
	facing_yaw = rotation.y
	_prev_pos = global_position
	_curr_pos = global_position
	creature.global_transform = Transform3D(Basis(Vector3.UP, facing_yaw), global_position)
	creature.settle()


func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		_touch_local()
		return
	if maze == null:
		return
	_sense(delta)
	mode = Mode.HOLDING if not _taking.is_empty() else (Mode.HUNTING if hunting() else Mode.CREEPING)
	chasing = mode != Mode.CREEPING

	# Creeping on, by the passages, to whoever it is after or wherever it wanders.
	var to := way(0.6)
	var wish := to.normalized() if to.length() > 0.1 else Vector3.ZERO
	var speed := hunt_speed if hunting() else creep_speed
	if mode == Mode.HOLDING:
		speed *= 0.3
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, 1.5 * delta)
	velocity.x = current.x
	velocity.z = current.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position

	# Whoever touches it is drawn in.
	for player: Node3D in players():
		if huntable(player) and not _taking.has(player) and _touches(player):
			_engulf(player)
	for player: Node3D in _taking.keys():
		_taking[player] -= delta
		if _taking[player] <= 0.0:
			_taking.erase(player)
			if player == _held_local:
				_free_local()
			if is_instance_valid(player):
				_catch(player)


func _touches(player: Node3D) -> bool:
	if creature == null or not creature.visible:
		return false
	var feet := player.global_position
	return creature.contains(feet + Vector3.UP * 0.3, 0.1) or creature.contains(feet + Vector3.UP * 1.2, 0.1)


## Takes `player` in: held up inside it for HOLD, then caught.
func _engulf(player: Node3D) -> void:
	_engulfs += 1
	_taking[player] = HOLD
	# (kept from being taken twice while it holds them)
	_spared[player] = HOLD + spare_time
	if player is Player:
		_hold_local(player)


## Holds this machine's player inside it, stopped, for HOLD. What is seen of
## him is his figure (the Player's top-level `Rig`), so that is what it holds;
## stopped, he does not move it himself, and his pose stays as it was.
func _hold_local(player: Node3D) -> void:
	if _held_local != null or creature == null:
		return
	_held_local = player
	_held_mode = player.process_mode
	player.process_mode = Node.PROCESS_MODE_DISABLED
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	var figure := player.get_node_or_null(^"Rig") as Node3D
	_held_figure = figure if figure else player
	creature.hold(_held_figure, HOLD)


func _free_local() -> void:
	if _held_local == null:
		return
	var player := _held_local
	_held_local = null
	if creature and creature.holding(_held_figure):
		creature.let_go()
	_held_figure = null
	if is_instance_valid(player):
		player.process_mode = _held_mode


func _on_released(node: Node3D) -> void:
	if node == _held_figure:
		_free_local()


## As a puppet: this machine's player walking into it is held as the host would hold him
## (the host says when he is caught).
func _touch_local() -> void:
	var mine := local_player()
	if mine == null or _held_local != null or not huntable(mine):
		return
	if _touches(mine):
		_spared[mine] = HOLD + spare_time
		_hold_local(mine)
	for player: Node3D in _spared.keys():
		_spared[player] -= get_physics_process_delta_time()
		if _spared[player] <= 0.0:
			_spared.erase(player)


func _process(delta: float) -> void:
	if creature == null:
		return
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range and _held_local == null
		if far != _far:
			_far = far
			creature.visible = not far
			creature.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
			if not far:
				creature.global_position = global_position
				creature.settle()
	if _far:
		return
	# It turns slowly to the way it is going.
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-4.0 * delta))
	else:
		var heading := Vector3(velocity.x, 0.0, velocity.z)
		if heading.length_squared() > 0.04:
			facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))
	var at := _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	creature.global_transform = Transform3D(Basis(Vector3.UP, facing_yaw), at)
	var after := quarry if chasing and quarry else null
	if puppet:
		creature.aim = _heard_extra
	else:
		creature.aim = after.global_position + Vector3.UP if after else Vector3.INF


func _exit_tree() -> void:
	_free_local()


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


func net_flag() -> int:
	return _engulfs & 0xff


func net_point() -> Vector3:
	if chasing and quarry:
		return quarry.global_position + Vector3.UP
	return Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode != Mode.CREEPING


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if creature:
		creature.global_transform = Transform3D(Basis(Vector3.UP, facing), at)
		creature.settle()

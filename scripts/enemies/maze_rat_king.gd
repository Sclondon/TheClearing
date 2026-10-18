class_name MazeRatKing
extends MazeEnemy
## A rat king in the maze: a knot of eight to fourteen rats whose tails are
## fused together, a writhing, squealing wheel of bodies that drags itself
## slowly and unevenly through the halls, each rat pulling its own way. What it
## looks like and how it moves is RatKing (creatures/rats/); this is what it
## thinks.
##
## - SLOW. It drags itself about its stretch of the maze (`wander_speed`), and
##   after someone it notices (`creep_speed`, well below a walk) in lurches, off
##   the line and back: it never runs anyone down.
## - TOUCHING IT CATCHES. Come within reach of its rats (RatKing.reach) and it
##   is a frenzy of teeth: caught. It fills little of a hall: go round it.
## - THE SWARMS' MASTER. When it notices someone it stops and SHRIEKS (about a
##   second and a half, every rat rearing and screaming at once; the shriek
##   carries through the walls). Every rat swarm (MazeRatSwarm) within
##   `call_range` of it, in a straight line, through walls and all, is called:
##   out they pour after whoever it is after, from as far as their
##   `called_range`, and BOLD for a while: a little faster (still short of a
##   sprint), slower to give up, and not kept off by fire. It shrieks again
##   every `call_every` seconds while it still knows where someone is. So the
##   king itself is slow and only dangerous close, but hearing it means the
##   rivers of rats are coming: get up high (two metres and more), or sprint.
## - FIRE does not keep it off (it cannot draw back from anything), and the
##   swarms it calls are bold enough to come through a torch's light: a torch
##   is no help against a king, only against a swarm alone.
##
## As a puppet it follows the host's news: where it is, which way it is going
## (its rats pull that way), what it is doing (`net_state`), and a count of its
## shrieks (`net_flag`) so that each is heard on every machine. Its rats are
## posed here, the same in look though not rat for rat.

enum Mode { WANDER, CREEP, SHRIEK }

## How many rats in it (0: eight to fourteen, by its seed).
@export var rat_count := 0
@export var wander_speed := 0.4
@export var creep_speed := 1.3
## How far its shriek calls the swarms (m, straight through walls).
@export var call_range := 60.0
## How often it shrieks again while it is after someone, seconds.
@export var call_every := 15.0
## How long it stands shrieking, seconds.
@export var shriek_time := 1.6

var mode := Mode.WANDER
var king: RatKing
## How many times it has shrieked (for the network; wraps at 256).
var shrieks := 0

var _timer := 0.0
var _call_in := 0.0
var _ground_in := 0.0
var _ground := 0.0
var _king_seed := 0
var _facing := 0.0
var _heard_shrieks := -1


func _init() -> void:
	sight_range = 26.0
	hear_range = 12.0
	memory = 10.0
	pack = &"rat_kings"
	# (it does not fear fire: a frenzied knot, it cannot draw back; and it is how the swarms come at someone with a torch)
	fears_fire = false
	look_every = 0.25
	spare_time = 4.0


func seed_choices(value: int) -> void:
	super(value)
	_king_seed = value


func _ready() -> void:
	add_to_group(&"pursuers")
	# Nothing bumps into it: touching it is being caught.
	collision_layer = 0
	collision_mask = 0
	var chance := RandomNumberGenerator.new()
	chance.seed = _king_seed
	king = RatKing.new()
	king.name = "King"
	king.king_seed = _king_seed
	king.count = rat_count if rat_count > 0 else chance.randi_range(8, 14)
	king.moves_itself = false
	king.speed = wander_speed
	king.top_level = true
	add_child(king)
	_facing = rotation.y
	_ground = maze.ground_height(global_position) if maze else global_position.y
	king.global_position = global_position
	king.rotation.y = _facing
	_call_in = 0.0


func _physics_process(delta: float) -> void:
	if puppet:
		_follow_news(delta)
		return
	if maze == null:
		return
	_sense(delta)
	_timer -= delta
	_call_in -= delta
	var who := quarry if hunting() else null
	match mode:
		Mode.SHRIEK:
			king.urge = 0.0
			king.wish = Vector3.ZERO
			if _timer <= 0.0:
				mode = Mode.CREEP if who else Mode.WANDER
		Mode.CREEP, Mode.WANDER:
			mode = Mode.CREEP if who else Mode.WANDER
			if who and _call_in <= 0.0:
				_shriek()
	chasing = mode != Mode.WANDER and who != null
	if mode != Mode.SHRIEK:
		var to := way(0.35)
		king.wish = to.normalized() if to.length() > 0.05 else Vector3.ZERO
		king.urge = 1.0 if mode == Mode.CREEP else 0.45
		king.speed = creep_speed if mode == Mode.CREEP else wander_speed
	_drag(delta)
	# A frenzy of teeth: whoever touches it.
	for player: Node3D in players():
		if not huntable(player):
			continue
		var at := player.global_position
		var apart := Vector2(at.x - global_position.x, at.z - global_position.z).length()
		if apart < king.reach() + 0.2 and absf(at.y - global_position.y) < 1.2:
			king.frenzy()
			_catch(player)
			break


## It shrieks, and every swarm within `call_range` is called after whoever it is after.
func _shriek() -> void:
	mode = Mode.SHRIEK
	_timer = shriek_time
	_call_in = call_every
	shrieks = (shrieks + 1) % 256
	king.squeal()
	var after := quarry if hunting() else null
	for swarm: Node in get_tree().get_nodes_in_group(&"rat_swarms"):
		if swarm is MazeRatSwarm and not (swarm as MazeRatSwarm).puppet and (swarm as Node3D).global_position.distance_to(global_position) < call_range:
			(swarm as MazeRatSwarm).called(self, after)


## Whether it is shrieking now.
func shrieking() -> bool:
	return mode == Mode.SHRIEK


# Moves it by its rats' pulling, kept off the walls (sliding along them), on the ground.
func _drag(delta: float) -> void:
	var move := king.drift * delta
	var keep := MazeNav.clearance_for(0.25)
	var at := global_position
	if move.length() > 0.0:
		var next := at + Vector3(move.x, 0.0, move.z)
		if not nav.clear_of_walls(next, keep):
			next = at + Vector3(move.x, 0.0, 0.0)
			if not nav.clear_of_walls(next, keep):
				next = at + Vector3(0.0, 0.0, move.z)
				if not nav.clear_of_walls(next, keep):
					next = at
		at = next
	_ground_in -= delta
	if _ground_in <= 0.0:
		_ground_in = 0.3
		_ground = _floor_at(at)
	at.y = lerpf(at.y, _ground, minf(delta * 8.0, 1.0))
	velocity = (at - global_position) / maxf(delta, 0.001)
	global_position = at
	_facing += king.spin * delta
	king.global_position = at
	king.rotation.y = _facing


# The ground under a point: a ray down onto what is there (a step, a slab), or the maze's ground.
func _floor_at(at: Vector3) -> float:
	var ground := maze.ground_height(at)
	if not is_inside_tree():
		return ground
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, at.y + 0.8, at.z), Vector3(at.x, at.y - 2.0, at.z), 1))
	return (hit["position"] as Vector3).y if not hit.is_empty() else ground


# --- Being run by someone else ---

func yaw() -> float:
	return _facing


func net_state() -> int:
	return mode


func net_flag() -> int:
	return shrieks


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode != Mode.WANDER
	if _heard_shrieks >= 0 and flag != _heard_shrieks and king:
		king.squeal()
	_heard_shrieks = flag


func _follow_news(delta: float) -> void:
	if not _heard or king == null:
		return
	_heard_at += _heard_moving * delta
	var at := global_position.lerp(_heard_at, 1.0 - exp(-5.0 * delta))
	if at.distance_to(_heard_at) > 4.0:
		at = _heard_at
	velocity = (at - global_position) / maxf(delta, 0.001)
	global_position = at
	var level := Vector3(_heard_moving.x, 0.0, _heard_moving.z)
	king.wish = level.normalized() if level.length() > 0.05 else Vector3.ZERO
	king.urge = 0.0 if mode == Mode.SHRIEK else (1.0 if mode == Mode.CREEP else 0.45)
	_facing = lerp_angle(_facing, _heard_yaw, minf(delta * 3.0, 1.0))
	king.global_position = at
	king.rotation.y = _facing


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	_facing = facing
	if king:
		king.global_position = at
		king.rotation.y = facing


func _puppet_changed() -> void:
	collision_layer = 0
	collision_mask = 0

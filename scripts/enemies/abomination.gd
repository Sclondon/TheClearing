class_name Abomination
extends MazeEnemy
## The meat abomination let loose in the maze: the thinking half. What it looks
## like and how it moves is MeatAbomination (creatures/abomination/, a
## component that knows nothing of the maze); this finds its way, decides when
## to lash, and says whom it has caught.
##
## - It goes by the passages (MazeEnemy, MazeNav) at a crawl when it has nobody,
##   and no faster than a walk when it has: slow, but it never gives up
##   (`memory`), and it nearly fills a hall, so it is hard to get past. Where a
##   passage narrows it squeezes through (the look measures the walls itself).
## - Anyone in reach of its tendrils, in front of it, is lashed at: it rears
##   with its mouth open (`wind_up`: the time to get away), and they come down
##   where the player stood; a tendril that finds them catches them. It stops
##   to lash, and does not lash again for `lash_rest` seconds.
## - Walking into its body catches too.
##
## `Abomination.new()`: set `maze` first, as for any MazeEnemy.

enum Mode { ABOUT, HUNTING }

## Its speed, wandering and hunting (a boy walks at about 2, runs at 4.4).
@export var crawl_speed := 1.1
@export var hunt_speed := 2.0
@export var acceleration := 2.5
@export var turn_rate := 1.4
## How far ahead of its middle someone can be for it to lash at them, and how
## far to either side of straight ahead (the cosine).
@export var lash_range := 12.5
@export var lash_cone := 0.35
## Seconds after a lash before it lashes again.
@export var lash_rest := 1.4
## How big it is (MeatAbomination.size).
@export var size := 1.0
## What it is kept off the walls by, for finding its way (its body squeezes; this is its core).
@export var core_radius := 0.8
@export var gravity := 24.0
## Further than this from every player it is not drawn or posed.
@export var pose_range := 90.0

## What it looks like (made in _ready).
var look: MeatAbomination
var mode := Mode.ABOUT
var facing_yaw := 0.0

var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _lashes := 0
var _rest := 0.0
var _has_him := {}
var _far := false
var _far_check := 0.0
var _heard_lashed := false


func _init() -> void:
	sight_range = 46.0
	hear_range = 10.0
	memory = 60.0
	alert_range = 0.0
	pack = &"abominations"


func _ready() -> void:
	add_to_group(&"pursuers")
	_puppet_changed()
	floor_snap_length = 0.4
	var shape := CapsuleShape3D.new()
	shape.radius = core_radius
	shape.height = 3.0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 1.5
	add_child(collider)
	look = MeatAbomination.new()
	look.size = size
	look.top_level = true
	add_child(look)
	facing_yaw = global_rotation.y
	_prev_pos = global_position
	_curr_pos = global_position
	look.global_position = global_position
	look.rotation.y = facing_yaw
	look.settle()


func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze == null or look == null:
		return
	_sense(delta)
	mode = Mode.HUNTING if hunting() else Mode.ABOUT
	chasing = mode == Mode.HUNTING
	_rest -= delta
	var after := quarry if chasing and quarry and quarry.get(&"is_limp") != true else null
	var stage := look.lash_stage()
	var wish := Vector3.ZERO
	if stage == MeatAbomination.Stage.NONE:
		if after and _rest <= 0.0 and _in_reach(after):
			_lashes += 1
			_has_him.clear()
			look.lash(after.global_position)
		else:
			var to := way(core_radius)
			if to.length() > 0.05:
				wish = to.normalized()
				# It keeps to the middle of a hall, as its bulk makes it.
				var sides := look.sides()
				if sides.x < INF and sides.y < INF:
					var across := Vector3(-wish.z, 0.0, wish.x)
					var right := Vector3(cos(facing_yaw), 0.0, -sin(facing_yaw))
					var off := (sides.y - sides.x) * 0.5 * (1.0 if right.dot(across) > 0.0 else -1.0)
					wish = (wish + across * clampf(off / 8.0, -0.6, 0.6)).normalized()
	elif stage == MeatAbomination.Stage.STRIKE or stage == MeatAbomination.Stage.HOLD:
		_rest = lash_rest
	_catching()
	var speed := (hunt_speed if chasing else crawl_speed) * size
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, acceleration * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


## Whether `player` is where its tendrils can reach: near enough, in front, at its level.
func _in_reach(player: Node3D) -> bool:
	var to := player.global_position - global_position
	if absf(to.y) > 3.0 * size:
		return false
	to.y = 0.0
	var forward := Vector3(-sin(facing_yaw), 0.0, -cos(facing_yaw))
	return to.length() < lash_range * size and forward.dot(to.normalized()) > lash_cone


## Anyone a striking tendril finds, or who has walked into it, is caught.
func _catching() -> void:
	for player: Node3D in players():
		if not huntable(player):
			continue
		var feet := player.global_position
		if feet.distance_to(global_position) > 30.0 * size:
			continue
		var low: bool = player.get(&"is_ducking") == true or player.get(&"is_crawling") == true
		var top := feet + Vector3.UP * (0.7 if low else 1.5)
		if not _has_him.has(player) and look.lash_hits(feet + Vector3.UP * 0.1, top, 0.3):
			_has_him[player] = true
			_catch(player)
		elif look.touches(feet + Vector3.UP * 0.8, 0.2):
			_catch(player)


func _process(delta: float) -> void:
	if look == null:
		return
	# Out of everyone's way, it is not drawn or posed (the walls hide it).
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			look.visible = not far
			look.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
			if not far:
				look.settle()
	if _far:
		return
	var aim := Vector3.INF
	if puppet:
		aim = _heard_extra
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-6.0 * delta))
	else:
		var after := quarry if chasing else null
		if after:
			aim = after.global_position + Vector3.UP * 0.8
		var heading := Vector3(velocity.x, 0.0, velocity.z)
		if after and heading.length_squared() < 0.05:
			heading = after.global_position - global_position
			heading.y = 0.0
		# (it does not turn while it lashes)
		if look.lash_stage() == MeatAbomination.Stage.NONE and heading.length_squared() > 0.01:
			facing_yaw = lerp_angle(facing_yaw, atan2(-heading.x, -heading.z), 1.0 - exp(-turn_rate * delta))
	look.aim = aim
	look.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	look.rotation = Vector3(0.0, facing_yaw, 0.0)


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## How many lashes it has made (wrapping at 256).
func net_flag() -> int:
	return _lashes & 0xff


## Where the lash under way is aimed, or else whom it is after.
func net_point() -> Vector3:
	if look and look.lash_stage() != MeatAbomination.Stage.NONE:
		return look.lash_target()
	if chasing and quarry:
		return quarry.global_position + Vector3.UP * 0.8
	return Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode == Mode.HUNTING
	# A new lash: it is made here too, at the same point (the catching is the host's).
	if not _heard_lashed:
		_heard_lashed = true
		_lashes = flag
	elif flag != (_lashes & 0xff):
		_lashes = flag
		if look and point.is_finite():
			look.lash(point)


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if look:
		look.global_position = at
		look.rotation.y = facing
		look.settle()


func _puppet_changed() -> void:
	# Players pass through it (it catches them instead); the world stops it.
	collision_layer = 0 if puppet else 4
	collision_mask = 1

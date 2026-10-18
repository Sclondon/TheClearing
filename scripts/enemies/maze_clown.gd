class_name MazeClown
extends MazeEnemy
## A horror clown (creatures/clown/: Clown is how he looks, moves and sounds;
## this is how he hunts the maze). Too tall, too thin, a painted grin, and one
## red balloon on a long string floating over the walls, so that where he is can
## be seen from far off.
##
## - HE STALKS. Once he has noticed someone (MazeEnemy's senses; he is patient,
##   and remembers them a long while: `memory`) he follows them through the
##   passages (`stalk_speed`, slower than a run), and his music box tinkles
##   where he is. With nobody to follow he prowls about (`prowl_speed`).
## - HE IS ONLY EVER STILL WHEN SOMEONE LOOKS AT HIM. While anyone he could go
##   after is looking his way (`watched_by`: the camera, for whoever plays on
##   this machine; the way they face, for anyone else; within `watch_range` and
##   with nothing in the way), he stops dead mid-pose, his head slowly tilting
##   over, and his music box winds down. The moment nobody is, he comes on.
##   So it goes: look round, and he is there, still, a little nearer.
## - HE BURSTS. Within `burst_range` of whoever he is after, in a straight line
##   and with nobody looking, he giggles (`grin_time`: the tell; look at him
##   then and it stops him), and then sprints at them in a lanky, flailing,
##   stop-motion run (`sprint_speed`, faster than the boy's sprint) that looking
##   does not stop; but it tires him quickly (`sprint_time`), and then he stands
##   winded (`winded_time`), and cannot burst again for `burst_rest`.
## - TOUCHING HIM CATCHES (`catch_radius`), whatever he is doing but standing winded.
##
## Unlike the angel (whose gaze takes whoever stays in it), the clown is held by
## yours: watched he is harmless, and it is when you look away that he comes.
##
## Online it is run where MazeEnemies is run (the host); a puppet follows the
## host's news (its state, its giggles in `net_flag`, whom it is after as
## `net_point`). A puppet also stands still for whoever plays on its own machine
## while they look at it (it catches up with the host when they look away), so
## nobody ever sees him move while they watch him.
##
## Spawn (as MazeEnemies.add does): `MazeClown.new()`, set `maze`, put it in a
## passage, add it to the tree.

enum Mode { PROWLING, STALKING, STILL, GRINNING, SPRINTING, WINDED }

## How much bigger than he is modelled he is drawn (and goes): about 2.35 m tall.
const SIZE := 1.55

## Metres a second: prowling, stalking (slower than a run), and his sprint
## (faster than the boy's 5.6, but short).
@export var prowl_speed := 1.3
@export var stalk_speed := 3.4
@export var sprint_speed := 8.0
## How long his sprint lasts, how long his giggle before it, how long he stands
## winded after, and how long before he can burst again.
@export var sprint_time := 2.3
@export var grin_time := 0.6
@export var winded_time := 3.2
@export var burst_rest := 5.0
## How near (and in a straight line) he must be to burst at someone.
@export var burst_range := 10.0
## How near (flat) someone must be to him to be caught.
@export var catch_radius := 0.95
## How far off someone looking at him holds him still (beyond, he is lost in the
## mist), and how near square on they must face him: the camera (a share of
## straight ahead, 1 dead ahead), or the way someone else faces (on the flat).
@export var watch_range := 48.0
@export var camera_cone := 0.62
@export var watch_cone := 0.5
@export var turn_rate := 8.0
@export var gravity := 24.0
## How far over the walls of his ring his balloon floats, metres.
@export var balloon_over := 3.0
## Further than this from every player he is not posed (the walls hide him; his
## balloon is still seen).
@export var pose_range := 70.0
## Further than this from every player he is posed only `pose_slow` times a second.
@export var pose_near := 24.0
@export var pose_slow := 20.0

var mode := Mode.PROWLING
## Which way he faces, radians about Y (0 faces +Z).
var facing_yaw := 0.0
## The figure he drives.
var figure: Clown
## Whether anyone is looking at him now (as last looked for).
var watched := false

var _left := 0.0
var _burst_in := 0.0
var _watch_in := 0.0
var _giggles := 0
var _bursts := 0
var _radius := 0.3
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_giggles := -1
var _held_here := false


func _init() -> void:
	sight_range = 40.0
	hear_range = 14.0
	memory = 30.0
	alert_range = 0.0
	look_every = 0.25
	spare_time = 4.0
	pack = &"clowns"


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	_radius = 0.2 * SIZE
	shape.radius = _radius
	shape.height = 1.5 * SIZE
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	facing_yaw = rotation.y
	rotation.y = 0.0
	figure = Clown.new()
	figure.scale = Vector3.ONE * SIZE
	if maze:
		figure.balloon_height = maze.maze_wall_height(maxi(maze.ring_of(maze.cell_at(global_position)), 1)) + balloon_over
	add_child(figure)
	figure.top_level = true
	figure.put(global_position, facing_yaw)
	_prev_pos = global_position
	_curr_pos = global_position


func _physics_process(delta: float) -> void:
	if puppet:
		_puppet_step(delta)
		return
	if maze == null:
		return
	_sense(delta)
	_burst_in -= delta
	_watch_in -= delta
	if _watch_in <= 0.0:
		_watch_in = 0.1
		watched = _watched()
	var wish := Vector3.ZERO
	var speed := 0.0
	match mode:
		Mode.PROWLING, Mode.STALKING, Mode.STILL:
			if watched:
				mode = Mode.STILL
			else:
				mode = Mode.STALKING if hunting() else Mode.PROWLING
				if mode == Mode.STALKING and _burst_in <= 0.0 and in_reach(quarry):
					mode = Mode.GRINNING
					_left = grin_time
					_giggles += 1
					figure.giggle()
				else:
					wish = _route()
					speed = stalk_speed if mode == Mode.STALKING else prowl_speed
		Mode.GRINNING:
			if watched:
				# (caught at it: he stops, and may try again a moment later)
				mode = Mode.STILL
				_burst_in = 1.0
			else:
				_left -= delta
				if _left <= 0.0:
					mode = Mode.SPRINTING
					_left = sprint_time
					_bursts += 1
		Mode.SPRINTING:
			_left -= delta
			if _left <= 0.0 or quarry == null:
				_wind()
			else:
				wish = _dash()
				speed = sprint_speed
		Mode.WINDED:
			_left -= delta
			if _left <= 0.0:
				mode = Mode.STALKING if hunting() else Mode.PROWLING
				_burst_in = burst_rest
	chasing = mode in [Mode.STALKING, Mode.GRINNING, Mode.SPRINTING] or (mode == Mode.STILL and hunting())
	if mode == Mode.STILL or mode == Mode.GRINNING or mode == Mode.WINDED:
		# (he stops dead: no slowing down)
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, (30.0 if mode == Mode.SPRINTING else 10.0) * delta)
		velocity.x = current.x
		velocity.z = current.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position
	if mode != Mode.WINDED:
		_touch()


## Catches anyone touching him.
func _touch() -> void:
	for player: Node3D in players():
		if not huntable(player):
			continue
		var to := player.global_position - global_position
		if Vector2(to.x, to.z).length() < catch_radius + 0.25 and absf(to.y) < 1.6:
			_catch(player)
			_wind()
			return


## Stands winded (after a sprint, or having caught someone).
func _wind() -> void:
	mode = Mode.WINDED
	_left = winded_time


## Whether `player` is near enough to burst at: within `burst_range` on the
## flat, about level, and in a straight line from his face.
func in_reach(player: Node3D) -> bool:
	if player == null or not huntable(player):
		return false
	var to := player.global_position - global_position
	if Vector2(to.x, to.z).length() > burst_range or absf(to.y) > 3.0:
		return false
	return nav.sees(figure.face(), player.global_position + Vector3.UP * 1.0, burst_range + 1.5)


func _route() -> Vector3:
	var to := way(_radius)
	var wish := to.normalized() if to.length() > 0.05 else Vector3.ZERO
	var push := _apart(_radius)
	if push != Vector3.ZERO:
		wish = (wish + push * 0.8).normalized()
	return wish


## Flat out at them: straight, where there is a straight line, else by the passages.
func _dash() -> Vector3:
	var to := quarry.global_position - global_position
	to.y = 0.0
	if nav.line_free(global_position, quarry.global_position, _radius + 0.2):
		return to.normalized() if to.length() > 0.05 else Vector3.ZERO
	return _route()


# --- Being looked at ---

## Where he is looked at (his chest, and his face), in the world.
func _marks() -> Array[Vector3]:
	return [global_position + Vector3.UP * 1.05 * SIZE, global_position + Vector3.UP * 1.42 * SIZE]


## Whether anyone he could go after is looking at him.
func _watched() -> bool:
	for player: Node3D in players():
		if huntable(player) and watched_by(player):
			return true
	return false


## Whether `player` is looking his way: for whoever plays on this machine, the
## camera (near enough square on to him); for anyone else, the way they face
## (on the flat); within `watch_range`, and with nothing in the way between
## their eyes and his chest or his face (by the plan of the maze, and by a ray
## against the walls and stone themselves, so that a thick wall's corner or a
## terrace hides him).
func watched_by(player: Node3D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var eye := player.global_position + Vector3.UP * 1.4
	var from := eye
	var forward := Vector3.ZERO
	var cone := watch_cone
	if player == local_player() and is_inside_tree() and get_viewport().get_camera_3d():
		var camera := get_viewport().get_camera_3d()
		from = camera.global_position
		forward = -camera.global_basis.z
		cone = camera_cone
	else:
		var facing: Variant = player.get(&"facing_yaw")
		var yaw_now: float = facing if facing != null else player.global_rotation.y
		forward = Vector3(sin(yaw_now), 0.0, cos(yaw_now))
	for mark: Vector3 in _marks():
		var to := mark - from
		if to.length() > watch_range:
			continue
		if forward.y == 0.0:
			to.y = 0.0
		if forward.normalized().dot(to.normalized()) < cone:
			continue
		if not nav.sees(eye, mark, watch_range):
			continue
		if is_inside_tree():
			var ray := PhysicsRayQueryParameters3D.create(eye, mark, 1)
			if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				continue
		return true
	return false


## As a puppet: whether whoever plays on this machine is looking at him.
func _watched_here() -> bool:
	var mine := local_player()
	return mine != null and huntable(mine) and watched_by(mine)


func _puppet_step(delta: float) -> void:
	_watch_in -= delta
	if _watch_in <= 0.0:
		_watch_in = 0.1
		_held_here = mode != Mode.SPRINTING and _watched_here()
	if mode == Mode.STILL or _held_here:
		velocity = Vector3.ZERO
	else:
		_follow(delta)
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _process(delta: float) -> void:
	var at := _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var off := near.global_position.distance_to(global_position) if near else 0.0
		_far = near != null and off > pose_range
		figure.far = _far
		# (well off, he is posed less often: it does not show, and costs less)
		figure.pose_rate = pose_slow if off > pose_near else 0.0
	var held := mode == Mode.STILL or (puppet and _held_here)
	var aim := Vector3.INF
	if puppet:
		if _heard_extra.is_finite():
			aim = _heard_extra
		if not held:
			facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-10.0 * delta))
	elif not held:
		if quarry and chasing:
			aim = quarry.global_position + Vector3.UP * 1.0
		var heading := Vector3(velocity.x, 0.0, velocity.z)
		if quarry and (mode == Mode.GRINNING or heading.length_squared() < 0.05):
			heading = quarry.global_position - global_position
			heading.y = 0.0
		if heading.length_squared() > 0.01:
			facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))
	if not held:
		figure.aim = aim
	figure.frozen = held
	figure.winded = mode == Mode.WINDED
	figure.velocity = Vector3.ZERO if held else velocity
	figure.grounded = is_on_floor() or puppet
	figure.global_position = at
	figure.rotation.y = facing_yaw


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## His giggles (low four bits) and his bursts (the next four).
func net_flag() -> int:
	return (_giggles & 0x0f) | ((_bursts & 0x0f) << 4)


func net_point() -> Vector3:
	if chasing and quarry:
		return quarry.global_position + Vector3.UP * 1.0
	return Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode in [Mode.STALKING, Mode.GRINNING, Mode.SPRINTING]
	var giggles := flag & 0x0f
	if _heard_giggles >= 0 and giggles != _heard_giggles:
		figure.giggle()
	_heard_giggles = giggles


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if figure:
		figure.put(at, facing)


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4

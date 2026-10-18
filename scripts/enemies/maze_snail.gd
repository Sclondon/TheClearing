class_name MazeSnail
extends MazeEnemy
## A giant snail (Snail, creatures/snail/) let loose in the maze: the thinking
## half. What it looks like and how it moves is Snail (a component that knows
## nothing of the maze); this finds its way, decides, catches, and slows
## anyone in its slime.
##
## It is painfully slow, slower than a walk, but it never stops: crawling
## about the passages, and when it notices someone (MazeEnemy's senses: it
## sees down the halls and feels anyone close), sliding after them by the
## passages for a long time (`memory`), its eye stalks reaching for them.
##
## IT CLIMBS. It crawls on whatever it touches, as a snail does: walls, wall
## tops, the undersides of ledges. Someone up high (on a terrace, a wall top,
## the ivy) and near, it goes straight for the wall under them and up it, and
## after them along the top. Someone just over a wall from it, a long way round
## by the passages, it goes over the wall. Lost up there, it comes back down
## to where it left the floor.
##
## ITS SLIME. It leaves a broad trail that lies for two minutes (Snail.slime_life)
## on the floor, the walls and the tops. Anyone standing in it is stuck in it:
## they can go no faster than `slime_speed` (slower than it hunts), slither
## when they turn, and can barely jump. So an old trail across a hall is a trap
## to be stepped round, not run through, with it behind you.
##
## Touching it catches: its foot, its head or its shell. Whoever it touches is
## drawn in under its head and down into the slime, for HOLD seconds, and only
## then `caught` (as the slime wall does: this machine's player is held while
## it lasts; on a guest's machine its copy holds the guest's player, and the
## host, which does the catching, waits the same time).
##
## It pulls into its shell for a few seconds (`withdraw_time`) when another
## creature bumps into it, when something hits it (a thrown spear: Stagger),
## and when it has lost whoever it was after; and each eye stalk rolls in when
## anyone comes near its tip.
##
## Online: what it is doing goes in its state, with which way is up from the
## surface it is on (its point); a puppet crawls where it is told, on that
## surface, pulls in and comes out when the host's does, and lays its own
## trail, which slows this machine's player as the host's slows the host's.

enum Mode { CRAWLING, HUNTING, CLIMBING, WITHDRAWN, EMERGING, DRAWING }

## Seconds whoever it touches is drawn in before they count as caught.
const HOLD := 1.7

## Its speeds: crawling about, after someone, and up and over a wall (a walk is 1.6).
@export var crawl_speed := 0.55
@export var hunt_speed := 1.15
@export var climb_speed := 0.95
## How fast it turns, radians a second.
@export var turn_rate := 0.9
## How big it is (1: its foot 8 m long, its shell nearly 4 m across).
@export var size := 1.0
## Seconds it stays in its shell, and how long before a bump can send it in again.
@export var withdraw_time := 2.8
@export var bump_rest := 10.0
## How fast anyone in its slime can go (m/s), and how long its slime lies (s).
@export var slime_speed := 0.6
@export var slime_life := 120.0
## Someone this far over the ground under them is up high; it climbs after
## them up high this near (in a straight line).
@export var climb_high := 2.2
@export var climb_reach := 26.0
## It goes over a wall after someone this near (in a straight line) that is at
## least this many cells round by the passages.
@export var over_near := 20.0
@export var over_cells := 6
## Climbing, it gives up if it has got no nearer in this long.
@export var climb_patience := 30.0
## Further than this from every player it is not drawn or moved about.
@export var pose_range := 110.0

## How it looks: the creature this drives.
var creature: Snail
var mode := Mode.CRAWLING
## Which way is up off the surface it is on, and which way it is going along it.
var up := Vector3.UP
var ahead := Vector3.BACK
## Going up and over (after someone up high, or over a wall), or back down.
var climbing := false
## Where it climbs for (INF: nobody), and where it last left the floor.
var climb_to := Vector3.INF
var floor_spot := Vector3.ZERO

var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _shown_up := Vector3.UP
var _shown_ahead := Vector3.BACK
var _shell_left := 0.0
var _bumped_in := 0.0
var _bump_check := 0.0
var _decide_in := 0.0
var _was_hunting := false
var _best_climb := INF
var _stuck_for := 0.0
var _takes := 0
var _withdraws := 0
## Whoever it is drawing in, and how long until they count as caught.
var _taking := {}
var _held_local: Node3D
var _held_mode := Node.PROCESS_MODE_INHERIT
var _held_figure: Node3D
var _far := false
var _far_check := 0.0
var _slime_tick := 0
var _heard_takes := -1
var _heard_withdraws := -1
var _query: PhysicsRayQueryParameters3D
var _body: CollisionShape3D


func _init() -> void:
	sight_range = 34.0
	hear_range = 9.0
	memory = 40.0
	alert_range = 0.0
	spare_time = 3.0
	pack = &"snails"


func _ready() -> void:
	add_to_group(&"pursuers")
	# Solid where its head is (layer 4, as the other hunters are: the boy walks into it and is
	# caught, as touching it catches); it finds its own footing (rays), so it collides with nothing.
	collision_layer = 4
	collision_mask = 0
	_body = CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.7 * size
	_body.shape = ball
	add_child(_body)
	_query = PhysicsRayQueryParameters3D.new()
	_query.collision_mask = 1
	creature = Snail.new()
	creature.name = "Snail"
	creature.low_poly = Settings.low_poly
	creature.slime_life = slime_life
	creature.top_level = true
	add_child(creature)
	creature.drawn.connect(_on_drawn)
	var yaw_now := global_rotation.y
	up = Vector3.UP
	ahead = Vector3(sin(yaw_now), 0.0, cos(yaw_now))
	_land()
	floor_spot = global_position
	_prev_pos = global_position
	_curr_pos = global_position
	_shown_up = up
	_shown_ahead = ahead
	_place_creature(global_position)
	creature.settle()


## Puts it down on whatever is under it.
func _land() -> void:
	if not is_inside_tree():
		return
	var hit := _ray(global_position + Vector3.UP * 2.0, global_position + Vector3.DOWN * 4.0)
	if hit:
		global_position = hit.position
		up = (hit.normal as Vector3).normalized()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	_query.from = from
	_query.to = to
	return get_world_3d().direct_space_state.intersect_ray(_query)


func _physics_process(delta: float) -> void:
	# (its solid part goes with its head)
	if _body and creature and creature.rig:
		_body.global_position = creature.head_point() if creature.head_point() != Vector3.ZERO else global_position + up * 0.7 * size
	if creature == null:
		return
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		_touch_local()
		_slow_in_slime()
		return
	if maze == null:
		return
	_sense(delta)
	var after := hunting()
	# Hit by something (a spear): into its shell while it lasts.
	if Stagger.on(self):
		_withdraw(withdraw_time)
	_bumps(delta)
	if _was_hunting and not after and _taking.is_empty():
		# (it has lost them: in, for a moment)
		_withdraw(withdraw_time)
	_was_hunting = after
	_hold_on(delta)

	match mode:
		Mode.WITHDRAWN:
			_shell_left -= delta
			if _shell_left <= 0.0:
				mode = Mode.EMERGING
				_shell_left = SnailRig.OUT_TIME
				creature.withdrawn = false
		Mode.EMERGING:
			_shell_left -= delta
			if _shell_left <= 0.0:
				mode = Mode.CRAWLING
		Mode.DRAWING:
			# (it crawls on slowly over whoever it is drawing in)
			_crawl(ahead, crawl_speed * 0.4, delta, climbing)
			if _taking.is_empty():
				mode = Mode.CRAWLING
		_:
			_go(delta, after)
	chasing = mode in [Mode.HUNTING, Mode.CLIMBING, Mode.DRAWING]
	_prev_pos = _curr_pos
	_curr_pos = global_position
	if mode != Mode.WITHDRAWN:
		_catching()
	_slow_in_slime()


## Decides which way to go, and goes.
func _go(delta: float, after: bool) -> void:
	var on_floor := _on_floor()
	if on_floor:
		floor_spot = global_position
	_decide_in -= delta
	if _decide_in <= 0.0:
		_decide_in = 0.5
		_decide(after, on_floor)
	if climbing:
		mode = Mode.CLIMBING
		var target := climb_to if climb_to.is_finite() else floor_spot
		_crawl(_climb_wish(target), climb_speed, delta, true)
		# (no nearer for too long: it gives up, and comes back down)
		var far := global_position.distance_to(target)
		if far < _best_climb - 1.0:
			_best_climb = far
			_stuck_for = 0.0
		else:
			_stuck_for += delta
		if _stuck_for > climb_patience:
			_stuck_for = 0.0
			_best_climb = INF
			quarry = null
			_forget = 0.0
			climb_to = Vector3.INF
			_withdraw(withdraw_time)
		return
	mode = Mode.HUNTING if after else Mode.CRAWLING
	var to := way(1.3 * size)
	var wish := to.normalized() if to.length() > 0.1 else Vector3.ZERO
	_crawl(wish, hunt_speed if after else crawl_speed, delta, false)


## Whether to climb, and for where: after someone up high, or over a wall to
## someone a long way round; back down when lost up there.
func _decide(after: bool, on_floor: bool) -> void:
	var was := climbing
	if after:
		var q := quarry.global_position
		var flat := Vector2(q.x - global_position.x, q.z - global_position.z).length()
		var high := q.y - maze.ground_height(q) > climb_high
		var over := false
		if not high and on_floor and flat < over_near:
			var steps := nav.distance(maze.cell_at(global_position), maze.cell_at(q))
			over = steps < 0 or steps >= over_cells
		if (high and flat < climb_reach) or over:
			climbing = true
			climb_to = q
		elif on_floor:
			climbing = false
		elif climbing:
			climb_to = q
	else:
		climb_to = Vector3.INF
		# (lost, or never after anyone: on the floor it finds its way; off it, it comes down)
		climbing = not on_floor
	if climbing and not was:
		_best_climb = INF
		_stuck_for = 0.0


## The way to go for `target` over walls and along them, before it is laid on the surface.
func _climb_wish(target: Vector3) -> Vector3:
	var to := target - global_position
	if up.y > 0.8:
		return Vector3(to.x, 0.0, to.z)
	if up.y < -0.5:
		return to
	# On a face: someone in front of it (on this side) it goes for; anyone behind it, up and over.
	var front := to.dot(up)
	if front < 0.5:
		var along := to - up * front
		along.y = 0.0
		return Vector3.UP + (along.normalized() * 0.25 if along.length() > 0.5 else Vector3.ZERO)
	return to


## On the floor of a passage (not up a wall or on top of one).
func _on_floor() -> bool:
	return up.y > 0.8 and global_position.y - maze.ground_height(global_position) < 1.2


## Crawls on along the surface it is on, turning towards `wish`, `speed`
## metres a second. Where something is in the way it goes up it if it may
## climb (else along it); over an edge it goes on round, down the face beyond.
func _crawl(wish: Vector3, speed: float, delta: float, may_climb: bool) -> void:
	var at := global_position
	var flat := wish - up * wish.dot(up)
	var turning := 0.0
	if flat.length() > 0.01:
		flat = flat.normalized()
		var angle := ahead.signed_angle_to(flat, up)
		turning = absf(angle)
		ahead = ahead.rotated(up, clampf(angle, -turn_rate * delta, turn_rate * delta)).normalized()
	elif wish == Vector3.ZERO:
		speed = 0.0
	# (it slows to turn hard)
	var step := speed * delta * lerpf(1.0, 0.35, clampf(turning / 1.4, 0.0, 1.0))
	if step <= 0.0:
		return
	var lift := 0.4 * size
	var probe := 0.9 * size
	var hit := _ray(at + up * lift, at + up * lift + ahead * (step + probe))
	if hit:
		var normal := (hit.normal as Vector3).normalized()
		if may_climb and normal.dot(up) < 0.6:
			# Onto it: up its face (the way that was up, laid on it).
			var onto := up - normal * up.dot(normal)
			ahead = onto.normalized() if onto.length() > 0.01 else ahead
			up = normal
			global_position = (hit.position as Vector3)
			return
		# Along it.
		var along := ahead - normal * ahead.dot(normal)
		along -= up * along.dot(up)
		if along.length() < 0.2:
			along = up.cross(normal)
		ahead = SnailRig.turned(ahead, along.normalized(), clampf(4.0 * delta, 0.0, 1.0))
		step *= 0.3
	at += ahead * step
	# Keep to the surface.
	hit = _ray(at + up * 0.6 * size, at - up * 1.2 * size)
	if hit and (hit.normal as Vector3).dot(up) > 0.3:
		at = hit.position
		var normal := (hit.normal as Vector3).normalized()
		up = SnailRig.turned(up, normal, 0.4)
		ahead = (ahead - up * ahead.dot(up)).normalized()
	else:
		# Over an edge: round it, and down the face beyond.
		var under := at - up * 0.35 * size
		hit = _ray(under, under - ahead * (step + probe))
		if hit:
			var normal := (hit.normal as Vector3).normalized()
			var down := -up
			ahead = (down - normal * down.dot(normal)).normalized()
			up = normal
			at = hit.position
		else:
			# (nothing under it at all: down to whatever is below)
			hit = _ray(at, at + Vector3.DOWN * 80.0)
			if hit:
				at = hit.position
				up = (hit.normal as Vector3).normalized()
				ahead = (ahead - up * ahead.dot(up)).normalized()
	global_position = at


## Into its shell for `seconds` (not again while it is in, nor while it draws someone in).
func _withdraw(seconds: float) -> void:
	if mode in [Mode.WITHDRAWN, Mode.DRAWING] or not _taking.is_empty():
		return
	mode = Mode.WITHDRAWN
	_shell_left = seconds
	_withdraws += 1
	creature.withdrawn = true
	creature.flinch(-1)


## Another creature bumping into it sends it into its shell.
func _bumps(delta: float) -> void:
	_bumped_in -= delta
	_bump_check -= delta
	if _bump_check > 0.0 or _bumped_in > 0.0:
		return
	_bump_check = 0.3
	for other: Node in get_tree().get_nodes_in_group(&"maze_enemies"):
		if other == self or not (other is Node3D) or not (other as Node3D).visible:
			continue
		var them := other as Node3D
		if them.global_position.distance_squared_to(global_position) > 400.0 * size * size:
			continue
		if creature.touches(them.global_position + Vector3.UP * 0.5, 0.8):
			_bumped_in = bump_rest
			_withdraw(withdraw_time)
			return


## Anyone who touches it is drawn in; and an eye stalk rolls in when anyone comes near its tip.
func _catching() -> void:
	for player: Node3D in players():
		if not is_instance_valid(player) or not player.is_inside_tree():
			continue
		var feet := player.global_position
		if feet.distance_squared_to(global_position) > 900.0 * size * size:
			continue
		for side in 2:
			if creature.eye_tip(side).distance_to(feet + Vector3.UP * 1.2) < 1.4 * size:
				creature.flinch(side)
		if huntable(player) and not _taking.has(player) and _touches(player):
			_take(player)


func _touches(player: Node3D) -> bool:
	var feet := player.global_position
	return creature.touches(feet + Vector3.UP * 0.35, 0.25) or creature.touches(feet + Vector3.UP * 1.3, 0.2)


## Takes `player`: drawn in under its head for HOLD, then caught.
func _take(player: Node3D) -> void:
	_takes += 1
	_taking[player] = HOLD
	_spared[player] = HOLD + spare_time
	mode = Mode.DRAWING
	if player is Player and not player.is_in_group(&"runners"):
		_hold_local(player)
	elif player.has_method(&"hold"):
		player.call(&"hold", HOLD)


func _hold_on(delta: float) -> void:
	for player: Node3D in _taking.keys():
		_taking[player] -= delta
		if _taking[player] <= 0.0:
			_taking.erase(player)
			if player == _held_local:
				_free_local()
			if is_instance_valid(player):
				_catch(player)


## Holds this machine's player, stopped, and draws his figure (the Player's
## top-level `Rig`) in under its head.
func _hold_local(player: Node3D) -> void:
	if _held_local != null:
		return
	_held_local = player
	_held_mode = player.process_mode
	player.process_mode = Node.PROCESS_MODE_DISABLED
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	var figure := player.get_node_or_null(^"Rig") as Node3D
	_held_figure = figure if figure else player
	creature.draw_in(_held_figure, HOLD)


func _free_local() -> void:
	if _held_local == null:
		return
	var player := _held_local
	_held_local = null
	if creature:
		creature.let_go()
	_held_figure = null
	if is_instance_valid(player):
		player.process_mode = _held_mode


func _on_drawn(node: Node3D) -> void:
	# (a guest's copy lets go of its player once he is under; the host says when he is caught)
	if puppet and node == _held_figure:
		var player := _held_local
		get_tree().create_timer(0.3).timeout.connect(func() -> void:
			if _held_local == player:
				_free_local())


## As a puppet: this machine's player touching it is held and drawn in as the
## host would (the host says when he is caught).
func _touch_local() -> void:
	for player: Node3D in _spared.keys():
		_spared[player] -= get_physics_process_delta_time()
		if _spared[player] <= 0.0:
			_spared.erase(player)
	var mine := local_player()
	if mine == null or _held_local != null or not huntable(mine) or mode == Mode.WITHDRAWN:
		return
	if _touches(mine):
		_spared[mine] = HOLD + spare_time
		_hold_local(mine)


## Anyone on this machine standing in its slime is held back (each Player here:
## this machine's own, and the runners where they are run).
func _slow_in_slime() -> void:
	_slime_tick += 1
	if _slime_tick % 3 != 0:
		return
	for player: Node in players():
		if not (player is Player) or not is_instance_valid(player):
			continue
		var boy := player as Player
		if boy.process_mode == Node.PROCESS_MODE_DISABLED or not boy.is_on_floor():
			continue
		if boy.global_position.distance_squared_to(global_position) > 160.0 * 160.0:
			continue
		if creature.slime_at(boy.global_position) > 0.0:
			SnailSlimed.on(boy, slime_speed)


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
				_place_creature(global_position)
				creature.settle()
	if _far:
		return
	# Its surface and its heading, smoothed (it does not snap round an edge).
	var ease := 1.0 - exp(-5.0 * delta)
	_shown_up = SnailRig.turned(_shown_up, up, ease)
	_shown_ahead = SnailRig.turned(_shown_ahead, ahead, ease)
	var at := _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	_place_creature(at)
	var reach_for := quarry if chasing and quarry else null
	if puppet:
		reach_for = nearest_player(global_position) if mode in [Mode.HUNTING, Mode.CLIMBING] else null
	if reach_for and reach_for.global_position.distance_to(global_position) < 18.0 * size:
		creature.aim = reach_for.global_position + Vector3.UP * 1.3
	else:
		creature.aim = Vector3.INF


func _place_creature(at: Vector3) -> void:
	creature.global_transform = Transform3D(SnailRig._frame(_shown_up, _shown_ahead).scaled(Vector3.ONE * size), at)


func _exit_tree() -> void:
	_free_local()


# --- Being run by someone else ---

## Which way it is heading along its surface, as an angle (on the floor, its yaw).
func yaw() -> float:
	return MazeSnail.plane_angle(up, ahead)


## The angle of `heading` about `normal`, from a direction fixed for that surface (+Z on a floor, up on a wall).
static func plane_angle(normal: Vector3, heading: Vector3) -> float:
	var reference := Vector3.BACK if absf(normal.y) > 0.7 else Vector3.UP
	reference = (reference - normal * reference.dot(normal)).normalized()
	var side := normal.cross(reference)
	return atan2(heading.dot(side), heading.dot(reference))


## The heading with that angle about `normal`.
static func from_plane_angle(normal: Vector3, angle: float) -> Vector3:
	var reference := Vector3.BACK if absf(normal.y) > 0.7 else Vector3.UP
	reference = (reference - normal * reference.dot(normal)).normalized()
	var side := normal.cross(reference)
	return (reference * cos(angle) + side * sin(angle)).normalized()


func net_state() -> int:
	return mode


## How many it has drawn in (low four bits) and how often it has pulled in (high four), wrapping.
func net_flag() -> int:
	return (_takes & 0x0f) | ((_withdraws & 0x0f) << 4)


## A metre off its surface, straight up from it (which way is up there).
func net_point() -> Vector3:
	return global_position + up


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode in [Mode.HUNTING, Mode.CLIMBING, Mode.DRAWING]
	if point.is_finite() and point.distance_to(at) > 0.5:
		up = (point - at).normalized()
	ahead = MazeSnail.from_plane_angle(up, facing)
	if creature:
		creature.withdrawn = mode == Mode.WITHDRAWN
		var takes := flag & 0x0f
		if _heard_takes >= 0 and takes != _heard_takes:
			creature.flinch(-1)
		_heard_takes = takes
		var withdraws := flag >> 4
		_heard_withdraws = withdraws


## As a puppet: it crawls where it was heard to be going, on its surface (no falling).
func _follow(delta: float) -> void:
	if not _heard:
		return
	_heard_at += _heard_moving * delta
	global_position = global_position.lerp(_heard_at, 1.0 - exp(-5.0 * delta))
	if global_position.distance_to(_heard_at) > 3.0:
		global_position = _heard_at


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	ahead = MazeSnail.from_plane_angle(up, facing)
	_prev_pos = at
	_curr_pos = at
	_shown_up = up
	_shown_ahead = ahead
	velocity = Vector3.ZERO
	if creature:
		_place_creature(at)
		creature.settle()


## What holds a Player back while he stands in a snail's slime: no faster than
## `cap` along the ground, slithering when he turns (his way changes only
## slowly), and barely able to jump. It lasts a moment and is kept up while he
## is in it (`on`). Called after he has moved (a late physics priority).
class SnailSlimed extends Node:
	var cap := 0.6
	var left := 0.2
	var _was := Vector3.ZERO

	## Holds `player` back for a moment (or keeps him held), no faster than `cap`.
	static func on(player: Player, cap_speed: float) -> void:
		var held := player.get_node_or_null(^"SnailSlimed") as SnailSlimed
		if held == null:
			held = SnailSlimed.new()
			held.name = "SnailSlimed"
			held.process_physics_priority = 1000
			player.add_child(held)
		held.cap = cap_speed
		held.left = 0.2

	func _physics_process(delta: float) -> void:
		left -= delta
		if left <= 0.0:
			queue_free()
			return
		var player := get_parent() as Player
		if player == null:
			return
		var flat := Vector3(player.velocity.x, 0.0, player.velocity.z)
		# (slithering: his way changes only slowly)
		if _was != Vector3.ZERO:
			flat = _was.lerp(flat, 1.0 - exp(-2.5 * delta))
		flat = flat.limit_length(cap)
		_was = flat
		player.velocity.x = flat.x
		player.velocity.z = flat.z
		# (stuck: he can barely lift his feet out of it)
		if player.velocity.y > 1.8:
			player.velocity.y = 1.8

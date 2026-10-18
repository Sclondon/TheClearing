class_name MazeMantis
extends MazeEnemy
## A giant praying mantis in the maze, three metres tall: an ambush hunter. It
## stands among a stand of ferns and bushes against a hall's wall (it brings
## them: `cover`), pale grey-green, still but for a slow rocking like a leaf in
## a breeze, and whoever comes within its reach it strikes at, faster than
## anything else in the maze. The fairness is all in seeing it: its head turns
## to follow you, in small jerks, from far off (the one thing that moves with
## purpose in that stand of leaves), there is a faint rustle when it shifts,
## and if you look straight at it from near it rears up in its threat display,
## wings up and spread, forelegs open, hissing. Keep out of its reach (about
## three metres in front of it) and it cannot have you.
## It is drawn and moved by GiantMantis (creatures/mantis/mantis.gd); this is what it thinks.
##
## - STILL. Swaying among its plants, facing out across the hall, looking about.
## - TRACK. Someone in sight within `sight_range`: its head follows them (the
##   tell), and a rustle as it starts; near (`turn_range`) it turns its body
##   slowly to them, rocking.
## - DISPLAY. Someone within `display_range`, in sight and facing it, makes it
##   rear in its threat display for `display_time` (once in `display_rest`):
##   the loud warning. It still strikes at anyone who comes right into reach.
## - STRIKE. Anyone within `strike_reach` of it and within `strike_cone` of the
##   way it faces: the forelegs shoot out at their chest (GiantMantis.STRIKE_COCK
##   then STRIKE_SHOOT: under a fifth of a second) and shut. Whoever they close
##   on is `caught` (low, ducked or crawling, the strike is aimed lower, so
##   ducking is no help: keeping out of reach is).
## - RECOVER. After a strike that missed, it draws its forelegs in and stands a
##   moment (`recover_time`): the time to get past.
## - STALK. Someone lingering near it (within `stalk_range`), not facing it, it
##   creeps after, swaying, a few metres from its post at most (`leash`), and
##   goes back to its post and its stillness when they are gone.
## - EAT. Fed (Ecology), it holds its kill to its jaws and chews.
##
## THE OTHERS (Ecology, KINDS: a big meat-eater). Hungry, it strikes at what
## smaller creature comes in reach, and will stalk one it sees a little further
## from its post than it would a person; giant ants passing near it on their
## trail it takes one at a time (MazeAnts.lose_ant).
##
## As a puppet it follows the host's news: what it is doing (`net_state`), its
## strikes as a count (`net_flag`) with the point struck at (`net_point`; while
## tracking, the point it looks at).

enum Mode { STILL, TRACK, DISPLAY, STRIKE, RECOVER, STALK, RETURN, EAT }

## How far out from the wall's face it stands (its abdomen reaches two metres behind it).
const WALL_GAP := 3.4

@export var strike_reach := 3.0
## How far round from straight ahead it can strike, radians.
@export var strike_cone := 0.95
@export var turn_range := 9.0
@export var display_range := 9.0
@export var display_time := 2.6
@export var display_rest := 7.0
@export var recover_time := 1.4
@export var stalk_range := 7.0
@export var stalk_speed := 0.55
@export var leash := 4.5
## How much further from its post it goes after a creature it could eat, metres.
@export var prey_leash := 9.0
## How fast it turns its body, radians a second.
@export var turn_rate := 0.9
## Further than this from every player it is not posed (the walls hide it).
@export var pose_range := 75.0
## Whether it brings its stand of plants (the game may give it its own cover).
@export var cover := true
@export var sound := true

var mode := Mode.STILL
var facing_yaw := 0.0
var mantis: GiantMantis
## How many strikes it has made (sent, so that guests strike too).
var strikes := 0

var _post := Vector3.ZERO
var _post_yaw := 0.0
var _mode_left := 0.0
var _display_in := 0.0
var _point := Vector3.INF
var _struck_at := Vector3.INF
var _hit := false
var _rustle_in := 0.0
var _ants_in := 0.0
var _tracking: Node3D
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _plants: Undergrowth
var _cover_seed := 0
var _heard_strikes := -1


func _init() -> void:
	sight_range = 22.0
	hear_range = 4.0
	memory = 4.0
	pack = &"mantises"
	look_every = 0.2


func seed_choices(value: int) -> void:
	super(value)
	_cover_seed = value


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	shape.radius = 0.55
	shape.height = 2.6
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0.0, 1.3, -0.1)
	add_child(collider)
	mantis = GiantMantis.new()
	mantis.low_poly = Settings.low_poly
	mantis.sound = sound
	add_child(mantis)
	mantis.top_level = true
	facing_yaw = rotation.y
	_find_post.call_deferred()


## Finds its place: against the nearest wall of its cell, a couple of metres
## out, facing across the hall; and puts its plants round it.
func _find_post() -> void:
	if not is_inside_tree() or maze == null:
		return
	var middle := nav.point(maze.cell_at(global_position))
	middle.y = maze.ground_height(middle)
	var best := middle
	var best_yaw := facing_yaw
	var nearest := INF
	var space := get_world_3d().direct_space_state
	var eye := middle + Vector3.UP * 1.2
	for step: Vector2i in Maze.STEPS:
		var way := Vector3(step.x, 0.0, step.y)
		# (the face of the wall that way, as built, then out from it far enough for its abdomen)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + way * Maze.CELL, 1))
		if hit.is_empty():
			continue
		var face: Vector3 = hit["position"]
		var far := Vector2(face.x - eye.x, face.z - eye.z).length()
		var spot := Vector3(face.x, middle.y, face.z) - way * WALL_GAP
		# (with room for its legs either side: its walking legs reach out a metre and a half)
		if far < nearest and nav.clear_of_walls(spot, 1.7):
			nearest = far
			best = spot
			best_yaw = atan2(-way.x, -way.z)
	best.y = maze.ground_height(best)
	_post = best
	_post_yaw = best_yaw
	if not puppet:
		global_position = best + Vector3.UP * 0.05
		facing_yaw = best_yaw
	_prev_pos = global_position
	_curr_pos = global_position
	mantis.global_position = global_position
	mantis.rotation = Vector3(0.0, facing_yaw, 0.0)
	mantis.settle()
	if cover:
		_plants = _cover_round(_post, _post_yaw)
		add_child(_plants)


# A stand of ferns, bushes and coarse tufts round its post, thickest behind it
# against the wall, thin in front of it: from the seed, the same everywhere.
func _cover_round(at: Vector3, yaw: float) -> Undergrowth:
	var plants := Undergrowth.new()
	plants.name = "Cover"
	plants.top_level = true
	var rng := RandomNumberGenerator.new()
	rng.seed = _cover_seed
	var turn := Basis(Vector3.UP, yaw)
	for k in 34:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf())
		var off := Vector3(cos(a) * r * 3.4, 0.0, sin(a) * r * 2.4)
		# (behind it, toward the wall, more; less in front where it strikes)
		if off.z > 0.6 and rng.randf() < 0.6:
			off.z = -off.z * 0.8
		var spot := at + turn * off
		if not nav.clear_of_walls(spot, 0.2):
			continue
		spot.y = maze.ground_height(spot)
		# (mostly ferns, tall enough to hide its legs and most of its abdomen: it stands up out of them; a few bushes behind)
		var kind := Undergrowth.Kind.FERN if k % 4 != 3 else (Undergrowth.Kind.BUSH if off.z < 0.0 and k % 8 == 3 else Undergrowth.Kind.TUFT)
		var size := rng.randf_range(1.3, 2.1) if kind == Undergrowth.Kind.FERN else rng.randf_range(0.9, 1.3)
		plants.add(kind, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), spot))
	plants.build()
	return plants


# --- Thinking ---

func _physics_process(delta: float) -> void:
	if mantis == null:
		return
	if puppet:
		_follow_news(delta)
		return
	if maze == null:
		return
	_sense(delta)
	_display_in -= delta
	_rustle_in -= delta
	var who := _nearest_seen()
	var prey := quarry as MazeEnemy if quarry is MazeEnemy and hunting() else null
	match mode:
		Mode.STILL, Mode.TRACK:
			if _eating > 0.0:
				_set_mode(Mode.EAT)
			elif who:
				if mode == Mode.STILL:
					_set_mode(Mode.TRACK)
				_watch(who, delta)
			elif prey:
				_set_mode(Mode.TRACK)
				_watch(prey, delta)
			else:
				_set_mode(Mode.STILL)
				_point = Vector3.INF
				_turn_to_yaw(_post_yaw, delta * 0.5)
				_ants_near(delta)
		Mode.DISPLAY:
			_mode_left -= delta
			if who:
				_point = _head_of(who)
				if _in_reach(who, 0.85):
					_strike_at(who)
					return
			if _mode_left <= 0.0:
				_display_in = display_rest
				_set_mode(Mode.TRACK if who else Mode.STILL)
		Mode.STRIKE:
			_strike_check()
			if not mantis.striking():
				if _hit:
					mantis.holding = false
					_set_mode(Mode.STILL)
				else:
					_set_mode(Mode.RECOVER)
					_mode_left = recover_time
		Mode.RECOVER:
			_mode_left -= delta
			if who:
				_point = _head_of(who)
			if _mode_left <= 0.0:
				_set_mode(Mode.TRACK if who else Mode.STILL)
		Mode.STALK:
			var after: Node3D = who if who else prey
			if after == null or _off_post() > (prey_leash if after is MazeEnemy else leash):
				_set_mode(Mode.RETURN)
			else:
				_watch(after, delta)
				if mode == Mode.STALK:
					_creep_to(after.global_position, delta)
		Mode.RETURN:
			if who and _in_reach(who):
				_strike_at(who)
				return
			if _creep_to(_post, delta) or _off_post() < 0.4:
				_set_mode(Mode.STILL)
		Mode.EAT:
			mantis.eating = true
			if _eating <= 0.0:
				mantis.eating = false
				_set_mode(Mode.STILL)
	_settle_body(delta)


func _set_mode(now: Mode) -> void:
	if now == mode:
		return
	if now == Mode.TRACK and mode == Mode.STILL and _rustle_in <= 0.0:
		mantis.rustle()
		_rustle_in = 3.0
	mode = now
	mantis.display = mode == Mode.DISPLAY
	chasing = mode in [Mode.TRACK, Mode.DISPLAY, Mode.STRIKE, Mode.STALK] and _tracking != null and not (_tracking is MazeEnemy)


## Watching `who`: its head on them; turning to them when near; striking when
## in reach; the display when they face it from near; creeping after them
## when they linger.
func _watch(who: Node3D, delta: float) -> void:
	_tracking = who
	_point = _head_of(who)
	var flat := _flat_to(who.global_position)
	if flat.length() < turn_range:
		_turn_to(who.global_position, delta)
		if _rng.randf() < delta * 0.25 and _rustle_in <= 0.0:
			mantis.rustle()
			_rustle_in = 4.0
	if _in_reach(who):
		_strike_at(who)
		return
	if not (who is MazeEnemy) and flat.length() < display_range and _display_in <= 0.0 and _faces_me(who):
		_set_mode(Mode.DISPLAY)
		_mode_left = display_time
		return
	var lingering := flat.length() < (stalk_range if not (who is MazeEnemy) else stalk_range * 1.6)
	if lingering and mode == Mode.TRACK and (who is MazeEnemy or not _faces_me(who)):
		_set_mode(Mode.STALK)


func _nearest_seen() -> Node3D:
	var best: Node3D = null
	var far := sight_range
	var eye := global_position + Vector3.UP * 2.8
	for player: Node3D in players():
		if not huntable(player):
			continue
		var d := eye.distance_to(player.global_position)
		if d < far and (d < hear_range or nav.sees(eye, player.global_position + Vector3.UP * 1.2, sight_range)):
			far = d
			best = player
	return best


func _in_reach(who: Node3D, share := 1.0) -> bool:
	var flat := _flat_to(who.global_position)
	if flat.length() > strike_reach * share:
		return false
	if absf(who.global_position.y - global_position.y) > 2.0:
		return false
	var ahead := Vector2(sin(facing_yaw), cos(facing_yaw))
	return absf(ahead.angle_to(flat)) < strike_cone


func _strike_at(who: Node3D) -> void:
	_set_mode(Mode.STRIKE)
	_tracking = who
	_hit = false
	strikes += 1
	_struck_at = _target_of(who)
	_point = _struck_at
	_wake()
	mantis.strike(_struck_at)


# Where it aims at someone: their chest, or lower if they are ducked or crawling.
func _target_of(who: Node3D) -> Vector3:
	if who is MazeEnemy:
		return who.global_position + Vector3.UP * 0.8
	var low: bool = who.get(&"is_ducking") == true or who.get(&"is_crawling") == true
	return who.global_position + Vector3.UP * (0.6 if low else 1.2)


func _head_of(who: Node3D) -> Vector3:
	return who.global_position + Vector3.UP * (1.0 if who is MazeEnemy else 1.5)


## While the forelegs are out: whoever they pass close to is caught (or killed, if it is a creature).
func _strike_check() -> void:
	if _hit or not (mantis.strike_stage() in [GiantMantis.Strike.SHOOT, GiantMantis.Strike.CLAMP]):
		return
	var who := _tracking
	if who and is_instance_valid(who):
		if who is MazeEnemy:
			var prey := who as MazeEnemy
			if not prey.dead and mantis.strikes(prey.global_position + Vector3.UP * 0.7, 0.6) and Ecology.current:
				_hit = true
				Ecology.current.kill(prey, self)
				mantis.holding = true
			return
	for player: Node3D in players():
		if not huntable(player):
			continue
		var feet := player.global_position
		for h: float in [0.5, 0.9, 1.3]:
			if mantis.strikes(feet + Vector3.UP * h, 0.32):
				_hit = true
				mantis.holding = true
				_catch(player)
				return


func _faces_me(who: Node3D) -> bool:
	var to := global_position + Vector3.UP * 2.0 - who.global_position - Vector3.UP * 1.4
	var forward := Vector3.ZERO
	if who == local_player() and is_inside_tree() and get_viewport().get_camera_3d():
		forward = -get_viewport().get_camera_3d().global_basis.z
	else:
		var facing: Variant = who.get(&"facing_yaw")
		var yaw_now: float = facing if facing != null else who.global_rotation.y
		forward = Vector3(sin(yaw_now), 0.0, cos(yaw_now))
	forward.y = 0.0
	to.y = 0.0
	return forward.normalized().dot(to.normalized()) > 0.8


func _flat_to(point: Vector3) -> Vector2:
	return Vector2(point.x - global_position.x, point.z - global_position.z)


func _off_post() -> float:
	return Vector2(global_position.x - _post.x, global_position.z - _post.z).length()


## Creeps towards `point` (by the passages), swaying; whether it is there.
func _creep_to(point: Vector3, delta: float) -> bool:
	var to := nav.waypoint(global_position, point, MazeNav.clearance_for(0.8)) - global_position
	to.y = 0.0
	if to.length() < 0.3:
		return true
	_turn_to(global_position + to, delta)
	var ahead := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	# (in its swaying walk it goes, stops, goes again)
	var surge := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.004)
	velocity.x = ahead.x * stalk_speed * surge * clampf(ahead.dot(to.normalized()), 0.0, 1.0)
	velocity.z = ahead.z * stalk_speed * surge * clampf(ahead.dot(to.normalized()), 0.0, 1.0)
	return false


func _turn_to(point: Vector3, delta: float) -> void:
	var to := point - global_position
	_turn_to_yaw(atan2(to.x, to.z), delta)


func _turn_to_yaw(yaw: float, delta: float) -> void:
	facing_yaw = rotate_toward(facing_yaw, yaw, turn_rate * delta)


# Ants on their trail near it: hungry, it takes one that comes into reach.
func _ants_near(delta: float) -> void:
	_ants_in -= delta
	if _ants_in > 0.0:
		return
	_ants_in = 0.5
	if Ecology.current == null or not Ecology.current.hungry(self) or _eating > 0.0:
		return
	for node: Node in get_tree().get_nodes_in_group(&"ants"):
		var ants := node as MazeAnts
		if ants == null or ants.colony == null or ants.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		var near := ants.colony.nearest_ant(global_position)
		if near.x < 0 or near.y > strike_reach + 1.0:
			continue
		var at := ants.colony.ant_position(int(near.x))
		var flat := _flat_to(at)
		var ahead := Vector2(sin(facing_yaw), cos(facing_yaw))
		if flat.length() < strike_reach and absf(ahead.angle_to(flat)) < strike_cone:
			_set_mode(Mode.STRIKE)
			_hit = true
			strikes += 1
			_struck_at = at + Vector3.UP * 0.3
			_point = _struck_at
			_wake()
			mantis.strike(_struck_at)
			mantis.holding = true
			ants.lose_ant(int(near.x))
			ate(Ecology.EAT_SECONDS * 0.5)
			return


# Posed again at once (it was far from everyone and not being posed).
func _wake() -> void:
	if _far:
		_far = false
		_far_check = 0.5
		mantis.visible = true
		mantis.process_mode = Node.PROCESS_MODE_INHERIT


func _settle_body(delta: float) -> void:
	if mode != Mode.STALK and mode != Mode.RETURN:
		velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = minf(velocity.y, 0.0)
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


# --- What it looks like ---

func _process(delta: float) -> void:
	if mantis == null:
		return
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		# (a strike, or a kill being eaten, is always played out: what it struck at is near)
		if mode in [Mode.STRIKE, Mode.EAT]:
			far = false
		if far != _far:
			_far = far
			mantis.visible = not far
			mantis.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
	if _far:
		return
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-10.0 * delta))
	mantis.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	mantis.rotation = Vector3(0.0, facing_yaw, 0.0)
	mantis.look_at_point = _point if mode != Mode.STILL else Vector3.INF


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Its strikes, as a count (four bits).
func net_flag() -> int:
	return strikes & 0x0f


func net_point() -> Vector3:
	return _struck_at if mode == Mode.STRIKE else _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	if mantis:
		mantis.display = mode == Mode.DISPLAY
		mantis.eating = mode == Mode.EAT
	chasing = mode in [Mode.TRACK, Mode.DISPLAY, Mode.STRIKE, Mode.STALK]
	var count := flag & 0x0f
	if _heard_strikes >= 0 and count != _heard_strikes and mantis and point.is_finite():
		mantis.strike(point)
	_heard_strikes = count
	strikes = count
	_point = point if mode != Mode.STRIKE else _point


func _follow_news(delta: float) -> void:
	if not _heard:
		return
	_heard_at += _heard_moving * delta
	global_position = global_position.lerp(_heard_at, 1.0 - exp(-8.0 * delta))
	if global_position.distance_to(_heard_at) > 4.0:
		global_position = _heard_at
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if mantis:
		mantis.global_position = at
		mantis.settle()


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4

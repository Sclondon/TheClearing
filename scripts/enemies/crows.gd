class_name Crows
extends MazeEnemy
## A murder of crows on the maze's walls: its watchers. They catch nobody; they
## follow you, and they give you away.
##
## What they look like and how they fly is CorvidFlock (creatures/crow/, a
## component that knows nothing of the maze); this is only what they think.
## This node is the murder as the game sees it: where it is (the birds' middle),
## what it is doing (`mode`), and who it is after (`quarry`).
##
## - ROOST. Put in a cell, the crows sit along the top edges of the walls round
##   it (and on any ledge), Perches.along_walls, a dozen or so: looking about,
##   preening, shuffling, now and then a caw.
## - WATCH. Someone in the halls below, in their sight (`watch_range`, a clear
##   line from the wall top): every head turns to them, and as they go the
##   crows follow along the wall tops in short flights, one after another,
##   leapfrogging, keeping over them (never more than `follow_range` from home,
##   never into the clearing). They caw now and then, quietly; that calls
##   nobody. Out of sight for `lose_after` seconds, they go home.
## - ALARM. Anyone running within `startle_run` of the murder (sprinting,
##   within `startle_sprint`) sets them off: they erupt, cawing hard, and wheel
##   over that player, following them round; and every `call_every` seconds while
##   they are over them, everything else that hunts within `alarm_range` is told
##   where they are (MazeEnemy.notice; a Griever is sent to look, Griever.alert).
##   After `alarm_time` they settle on the walls where they are (and may watch
##   again), and are slow to start again for `rest_time`.
## - MARK. When a hunter catches someone within `mark_range` of them
##   (`saw_catch`, from MazeEnemies), they rise and wheel over the place,
##   cawing, for `mark_time`: a sign to everyone else. That calls no one.
##
## As a puppet (online, not the host) it follows the host's news: what the
## murder is doing and the point that goes with it (who they wheel over, who
## they watch); its own birds sit and fly about that point as these do. The
## birds are seeded by `seed_choices`, and their perches are found from where
## they are put, so every machine has the same murder in the same place.

enum Mode { ROOST, WATCH, ALARM, MARK }

## How many crows, at least and at most.
@export var murder := Vector2i(7, 13)
@export var watch_range := 34.0
@export var follow_range := 75.0
@export var lose_after := 6.0
@export var startle_run := 16.0
@export var startle_sprint := 26.0
@export var alarm_range := 45.0
@export var call_every := 1.2
@export var alarm_time := 9.0
@export var rest_time := 8.0
@export var mark_range := 50.0
@export var mark_time := 24.0

var mode := Mode.ROOST
var flock: CorvidFlock

var _home := Vector3.ZERO
var _flock_seed := 0
var _settled_at := Vector3.INF
var _point := Vector3.INF
var _mode_left := 0.0
var _call := 0.0
var _rest := 0.0
var _unseen := 0.0
var _move_in := 0.0
var _ready_done := false


func _init() -> void:
	# (it does not look about as the others do: see `_watch`)
	sight_range = 0.0
	hear_range = 0.0
	memory = 1.0
	pack = &"crows"
	look_every = 0.25


func seed_choices(value: int) -> void:
	super(value)
	_flock_seed = value


func _ready() -> void:
	add_to_group(&"pursuers")
	# Nothing bumps into it: it is a murder of crows.
	collision_layer = 0
	collision_mask = 0
	_home = global_position
	var choose := RandomNumberGenerator.new()
	choose.seed = _flock_seed
	flock = CorvidFlock.new()
	flock.name = "Murder"
	flock.kind = CorvidBody.Kind.CROW
	flock.flock_seed = _flock_seed
	flock.count = choose.randi_range(murder.x, murder.y)
	flock.low_poly = Settings.low_poly
	flock.home = _home
	flock.restless = 0.008
	flock.grip = 0.15
	flock.call_every = 18.0
	flock.circle_radius = 8.0
	flock.circle_height = 0.0
	if maze:
		flock.ground_height = maze.ground_height
	add_child(flock)
	flock.top_level = true
	flock.global_transform = Transform3D.IDENTITY
	flock.add_child(CorvidVoice.new(flock))
	_settle.call_deferred()


## Finds the walls round where it was put and sits the crows on them.
func _settle() -> void:
	if not is_inside_tree():
		return
	_perch_near(_home, false)
	flock.settle()
	_ready_done = true


## Their perches along the walls round `near` (moving to them in short flights
## with `move`; with `gather`, those left out at the ends come in, leapfrogging).
func _perch_near(near: Vector3, move: bool, gather := false) -> bool:
	var ground := maze.ground_height(near) if maze else near.y
	var found := Perches.along_walls(get_world_3d(), near, ground, 30.0, 6.0 + flock.count * 0.35, 0.75)
	var points: PackedVector3Array = found[0]
	var faces: PackedVector3Array = found[1]
	# (they like the lowest ledges over the hall, where they see down it, if
	# there is room on them for the murder; else the wall tops)
	var lowest := INF
	for p in points:
		lowest = minf(lowest, p.y)
	var low_points := PackedVector3Array()
	var low_faces := PackedVector3Array()
	for k in points.size():
		if points[k].y < lowest + 3.0:
			low_points.append(points[k])
			low_faces.append(faces[k])
	if low_points.size() >= flock.count * 1.5:
		points = low_points
		faces = low_faces
	if points.is_empty():
		if not move:
			# (no walls round about, as in a bare test or the open: on the ground there)
			flock.ground_share = 1.0
			flock.roam = 4.0
		return false
	flock.set_perches(points, faces, move, gather)
	_settled_at = near
	return true


## Whether it has sat its crows on their walls (the frame after it goes in).
func roosted() -> bool:
	return _ready_done


func _physics_process(delta: float) -> void:
	if not _ready_done:
		return
	global_position = flock.centre()
	if puppet:
		_follow_news(delta)
		return
	if maze == null:
		return
	_rest -= delta
	_mode_left -= delta
	_look_in -= delta
	var looked := _look_in <= 0.0
	if looked:
		_look_in = look_every
	match mode:
		Mode.ROOST, Mode.WATCH:
			if looked:
				_watch()
		Mode.ALARM:
			_alarm(delta)
		Mode.MARK:
			if _mode_left <= 0.0:
				_settle_where_they_are()
	chasing = mode == Mode.ALARM


## Who is in their sight and what they are doing: watch the nearest, follow
## them along the walls, and erupt at anyone running near.
func _watch() -> void:
	var best: Node3D = null
	var nearest := INF
	var eye := flock.centre() + Vector3.UP * 0.5
	for player: Node3D in players():
		if not huntable(player) or maze.in_clearing(maze.cell_at(player.global_position)):
			continue
		var at := player.global_position
		var level := Vector2(at.x - eye.x, at.z - eye.z).length()
		if level > watch_range * 1.5:
			continue
		var moving: Variant = player.get(&"velocity")
		var pace := Vector2((moving as Vector3).x, (moving as Vector3).z).length() if moving is Vector3 else 0.0
		var sprinting: bool = player.get(&"is_sprinting") == true or pace > 5.2
		if _rest <= 0.0 and (sprinting and level < startle_sprint or pace > 3.0 and level < startle_run):
			erupt_over(player)
			return
		if level < watch_range and level < nearest and _seen(at + Vector3.UP * 1.2):
			nearest = level
			best = player
	if best:
		_unseen = 0.0
		if mode != Mode.WATCH:
			mode = Mode.WATCH
			spotted.emit(best)
		quarry = best
		_point = best.global_position
		flock.watch(best.global_position + Vector3.UP * 1.2)
		# (following along the walls: when they have got ahead of the murder, it moves over)
		_move_in -= look_every
		var from_them := Vector2(_settled_at.x - _point.x, _settled_at.z - _point.z).length()
		if _move_in <= 0.0 and from_them > 9.0 and _point.distance_to(_home) < follow_range:
			var moving: Variant = best.get(&"velocity")
			var ahead := (moving as Vector3) * 1.2 if moving is Vector3 else Vector3.ZERO
			ahead.y = 0.0
			if _perch_near(_point + ahead.limit_length(6.0), true, true):
				_move_in = 3.0
	elif mode == Mode.WATCH:
		_unseen += look_every
		if _unseen > lose_after:
			_go_home()
	else:
		flock.watch(Vector3.INF)


## Whether any of the crows (the first few) can see `to`: from over the edge it sits on.
func _seen(to: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var looked := 0
	for i in flock.count:
		var p := flock.perch_of(i)
		if p < 0 or p >= flock.perch_points.size():
			continue
		var out := flock.perch_faces[p] if p < flock.perch_faces.size() else Vector3.ZERO
		var eye := flock.bird_position(i) + out * 0.7 + Vector3.UP * 0.3
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, to, 1))
		if hit.is_empty() or (hit["position"] as Vector3).distance_to(to) < 1.0:
			return true
		looked += 1
		if looked >= 6:
			break
	return false


## They erupt over `player`, cawing, and call the hunters to them.
func erupt_over(player: Node3D) -> void:
	if puppet or not huntable(player):
		return
	if mode != Mode.ALARM:
		spotted.emit(player)
	mode = Mode.ALARM
	quarry = player
	_point = player.global_position
	_mode_left = alarm_time
	_call = 0.3
	flock.watch(Vector3.INF)
	flock.erupt(_point + Vector3.UP * _over_walls(_point), alarm_time + 2.0)


# How high over `at` they wheel: over the walls of its ring, and a little more.
func _over_walls(at: Vector3) -> float:
	var ring := maze.ring_of(maze.cell_at(at)) if maze else 1
	return (maze.maze_wall_height(maxi(ring, 1)) if maze else 12.0) * 0.55 + 4.0


func _alarm(delta: float) -> void:
	var after := quarry
	if after and huntable(after) and not maze.in_clearing(maze.cell_at(after.global_position)):
		_point = after.global_position
		flock.move_circle(_point + Vector3.UP * _over_walls(_point))
		_call -= delta
		if _call <= 0.0 and flock.centre().distance_to(after.global_position) < alarm_range:
			_call = call_every
			_raise_alarm(after)
	if _mode_left <= 0.0:
		_settle_where_they_are()


## When someone is caught near them: they rise and wheel over the place.
func saw_catch(at: Vector3) -> void:
	if puppet or global_position.distance_to(at) > mark_range or mode == Mode.ALARM:
		return
	mode = Mode.MARK
	quarry = null
	_point = at
	_mode_left = mark_time
	flock.watch(Vector3.INF)
	flock.circle_over(at + Vector3.UP * _over_walls(at), mark_time)


## MazeEnemy.notice: someone else's alarm. They look; they do not erupt for it.
func notice(player: Node3D) -> void:
	if mode == Mode.ROOST and huntable(player):
		flock.watch(player.global_position + Vector3.UP * 1.2)


func alerted(_player: Node3D, _from: Vector3) -> void:
	pass


func _settle_where_they_are() -> void:
	var at := _point if _point.is_finite() else flock.centre()
	mode = Mode.ROOST
	quarry = null
	_rest = rest_time
	if at.distance_to(_home) > follow_range or not _perch_near(at, true):
		_go_home()


func _go_home() -> void:
	mode = Mode.ROOST
	quarry = null
	flock.watch(Vector3.INF)
	_perch_near(_home, true)


## Everything else that hunts within `alarm_range` is told where `player` is.
func _raise_alarm(player: Node3D) -> void:
	if player == null or not is_instance_valid(player):
		return
	for other: Node in get_tree().get_nodes_in_group(&"maze_enemies"):
		if other == self or not (other is MazeEnemy) or other is Crows or other is Chickens or other is Bats or (other as MazeEnemy).puppet:
			continue
		if (other as Node3D).global_position.distance_to(flock.centre()) < alarm_range:
			(other as MazeEnemy).notice(player)
	for griever: Node in get_tree().get_nodes_in_group(&"grievers"):
		if griever.has_method(&"alert") and (griever as Node3D).global_position.distance_to(flock.centre()) < alarm_range:
			griever.call(&"alert", player.global_position)


# --- Being run by someone else ---

func net_state() -> int:
	return mode


func net_point() -> Vector3:
	return _point if mode != Mode.ROOST else Vector3.INF


func _heard_changed(_was: int, now: int, _first: bool) -> void:
	mode = now as Mode
	if not _ready_done:
		return
	var point := _heard_extra
	match mode:
		Mode.ALARM:
			if point.is_finite():
				flock.erupt(point + Vector3.UP * _over_walls(point), alarm_time + 2.0)
		Mode.MARK:
			if point.is_finite():
				flock.circle_over(point + Vector3.UP * _over_walls(point), mark_time)
		Mode.ROOST:
			flock.watch(Vector3.INF)
			_perch_near(_home if _settled_at.distance_to(_home) > follow_range else _settled_at, true)


func _follow_news(_delta: float) -> void:
	if not _heard:
		return
	var point := _heard_extra
	chasing = mode == Mode.ALARM
	match mode:
		Mode.ALARM:
			if point.is_finite():
				flock.move_circle(point + Vector3.UP * _over_walls(point))
		Mode.WATCH:
			if point.is_finite():
				flock.watch(point + Vector3.UP * 1.2)
				_move_in -= _delta
				if _move_in <= 0.0 and Vector2(_settled_at.x - point.x, _settled_at.z - point.z).length() > 9.0:
					_move_in = 3.0
					_perch_near(point, true)


func _put(_at: Vector3, _facing: float) -> void:
	pass


func _puppet_changed() -> void:
	collision_layer = 0
	collision_mask = 0

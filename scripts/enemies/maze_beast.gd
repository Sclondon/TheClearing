class_name MazeBeast
extends MazeEnemy
## The beast (the user, 2026-10-18: "a the Beast inspired character from Over the
## Garden Wall"): a tall shadow with great branching antlers, two pale burning eyes
## and a lantern of its own, glowing faintly. It is drawn and moved by Beast
## (creatures/beast/); this is what it thinks. It is rare (one in a section at
## most, none in the clearing) and mostly unseen.
##
## - IT LURKS (HIDDEN): not there at all, nothing drawn, nothing to bump into.
##   Every so often it picks whom to show itself to: the nearest player in its
##   section, alone best (nobody else within `company_range`: runners count as
##   company). It stands in a side passage they cannot see, at a turning down a
##   straight hall from them, and steps out into the hall (STEP_OUT): a silhouette
##   at the far end, its eyes and its lantern faint (WATCH). How far off is by how
##   dark it is (`far_by_day` by day; `near_in_dark` at night or in the mist and
##   rain, DayCycle.daylight and gloom), further still if they are not alone; it
##   shows itself by day less often (`show_chance_day`).
## - IT LURES whoever is alone (LURE): its lantern held up and out at them,
##   brightening, swung slowly from side to side, and a low hum, a tune of its own,
##   carrying down the halls. It comes on very slowly (`lure_speed`), and whoever
##   it lures, standing in its light, is drawn towards it (`pull`, a gentle drift,
##   less than a walk: walk or run away and you get away).
## - IF IT REACHES YOU (within `reach_range`), it draws its long arms up and out
##   (REACH: BeastRig.WIND, nearly a second, the warning: the hum stops, its eyes
##   flare, wood groans) and closes its hands: whoever is still within
##   `grab_range` is taken into the dark (caught: back to the clearing). Then it
##   goes.
## - IT GOES (WITHDRAW) when someone comes to it who is not alone, when the one it
##   lures gets far off or out of its sight, or after it has watched a while: back
##   the way it came, out of sight, and is gone (HIDDEN) for a while.
## - IT CANNOT ABIDE THE WOODSMAN'S LANTERN. It never shows itself within
##   `shun_range` of a woodsman (MazeWoodsman); one coming near it, or one that sees
##   it, and it flees (FLEE) at once, out of sight; the woodsman goes for it with
##   his light held up. Nor does it lure anyone in his light.
##
## Online it is run where MazeEnemies is run (the host); a puppet shows what it
## hears: what it does (`net_state`), whether it is there and a count of its
## reaches (`net_flag`), and whom it lures (`net_point`, where they are): on every
## machine, the one who plays there is drawn towards it while it lures them.

enum Mode { HIDDEN, STEP_OUT, WATCH, LURE, REACH, WITHDRAW, FLEE }

const GROUP := &"maze_beasts"

@export var walk_speed := 1.0
@export var lure_speed := 0.75
@export var flee_speed := 3.2
@export var acceleration := 4.0
## How far off it shows itself by day and in the dark, metres (further still with company).
@export var far_by_day := Vector2(38.0, 52.0)
@export var near_in_dark := Vector2(18.0, 30.0)
## How long it waits hidden between showings, seconds (the least and most), and the
## chance by day that it shows itself when it might.
@export var hidden_time := Vector2(14.0, 34.0)
@export var show_chance_day := 0.4
## How long it stands and watches before it goes, if it does not lure.
@export var watch_time := Vector2(5.0, 9.0)
## Nobody else within this of someone, and they are alone.
@export var company_range := 18.0
## It lures whoever is alone within this, in its sight; gives up past `lure_lost`.
@export var lure_range := 34.0
@export var lure_lost := 40.0
## How fast whoever it lures is drawn towards it, m/s (a slow walk is 1.6).
@export var pull := 0.55
## It reaches for whoever comes within this; its hands take whoever is within `grab_range`.
@export var reach_range := 2.6
@export var grab_range := 3.0
## It never shows itself within this of a woodsman, and flees one this near.
@export var shun_range := 24.0
@export var flee_range := 16.0
## Further than this from the camera it is not posed.
@export var pose_range := 110.0
@export var gravity := 24.0
## Put in by the dev tools: it stands where it is put and shows itself at once.
var shown_at_once := false

var mode := Mode.HIDDEN
var facing_yaw := 0.0
var figure: Beast
## Whom it is showing itself to, or luring.
var mark: Node3D

var _radius := 0.45
var _mode_time := 0.0
var _point := Vector3.INF
var _wait := 6.0
var _hide_cell := Vector2i(-1, -1)
var _stand_at := Vector3.INF
var _watch_for := 6.0
var _unseen_for := 0.0
var _reaches := 0
var _grabbed := false
var _lure := 0.0
var _collider: CollisionShape3D
var _world: Node
var _found_world := false
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flagged := false


func _init() -> void:
	sight_range = 0.0
	hear_range = 0.0
	memory = 0.0
	pack = &"beasts"
	look_every = 0.3


func _enter_tree() -> void:
	super()
	add_to_group(GROUP)


func _ready() -> void:
	floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	shape.radius = _radius
	shape.height = 2.6
	_collider = CollisionShape3D.new()
	_collider.shape = shape
	_collider.position.y = 1.3
	add_child(_collider)
	figure = Beast.new()
	figure.low_poly = Settings.low_poly
	add_child(figure)
	figure.top_level = true
	facing_yaw = rotation.y
	_prev_pos = global_position
	_curr_pos = global_position
	figure.put(global_position, facing_yaw)
	figure.grabbing.connect(_on_grabbing)
	_wait = _rng.randf_range(4.0, hidden_time.x)
	if shown_at_once:
		_set_mode(Mode.WATCH)
		_watch_for = 30.0
	_show(mode != Mode.HIDDEN)


## Whether it is there to be seen (not hidden).
func shown() -> bool:
	return mode != Mode.HIDDEN


func _show(on: bool) -> void:
	if figure:
		figure.visible = on and not _far
		figure.lantern.visible = on and not _far
	var layer := (PUPPET_LAYER if puppet else 4) if on else 0
	collision_layer = layer
	collision_mask = 1 if puppet or not on else 1 | 4


# --- How dark it is ---

## 0 by day to 1 at night, or in heavy rain and mist (DayCycle: daylight and gloom).
func darkness() -> float:
	if not _found_world:
		_found_world = true
		var node := get_parent()
		while node:
			if node.get(&"day") is Node:
				_world = node.get(&"day")
				break
			node = node.get_parent()
	if not is_instance_valid(_world):
		return 0.0
	return clampf(maxf(1.0 - float(_world.get(&"daylight")), float(_world.get(&"gloom")) * 0.85), 0.0, 1.0)


## Whether `who` is alone: nobody else (no player, no runner) within `company_range`.
func alone(who: Node3D) -> bool:
	for other: Node3D in players():
		if other == who or not is_instance_valid(other) or not other.is_inside_tree():
			continue
		if other.get(&"escaped") == true:
			continue
		if other.global_position.distance_to(who.global_position) < company_range:
			return false
	return true


## The beast is never after another creature, and nobody in a woodsman's light.
func huntable(player: Node3D) -> bool:
	return super(player) and not (player is MazeEnemy)


# --- Thinking ---

func _physics_process(delta: float) -> void:
	if puppet:
		if mode != Mode.HIDDEN:
			_follow(delta)
		else:
			global_position = _heard_at if _heard else global_position
		_prev_pos = _curr_pos
		_curr_pos = global_position
		_pull_local(delta)
		return
	if maze == null:
		return
	_sense(delta)
	_mode_time += delta
	var grounded := is_on_floor()
	chasing = mode in [Mode.LURE, Mode.REACH]
	if mark and not (is_instance_valid(mark) and huntable(mark)):
		mark = null
	# The woodsman's light: it will not stay near it.
	if mode in [Mode.STEP_OUT, Mode.WATCH, Mode.LURE, Mode.WITHDRAW]:
		var man := MazeWoodsman.nearest(get_tree(), global_position, flee_range)
		if man:
			_point = man.global_position + Vector3.UP * 1.5
			_set_mode(Mode.FLEE)
	match mode:
		Mode.HIDDEN:
			_wait -= delta
			velocity = Vector3.ZERO
			if _wait <= 0.0:
				_wait = _rng.randf_range(hidden_time.x, hidden_time.y) * lerpf(1.0, 0.55, darkness())
				_try_show()
		Mode.STEP_OUT:
			_look_at_mark()
			var to := _stand_at - global_position
			to.y = 0.0
			if to.length() < 0.4 or _mode_time > 12.0:
				_watch_for = _rng.randf_range(watch_time.x, watch_time.y)
				_set_mode(Mode.WATCH)
			_steer(to.normalized() if to.length() > 0.05 else Vector3.ZERO, walk_speed, delta, grounded)
		Mode.WATCH:
			_steer(Vector3.ZERO, 0.0, delta, grounded)
			_look_at_mark()
			if mark == null:
				_pick_mark()
			if mark:
				var d := mark.global_position.distance_to(global_position)
				if alone(mark) and d < lure_range and _sees(mark) and not MazeWoodsman.lit(get_tree(), mark.global_position):
					_set_mode(Mode.LURE)
				elif not alone(mark) and d < 16.0 and not shown_at_once:
					_withdraw()
			if mode == Mode.WATCH and _mode_time > _watch_for:
				_withdraw()
		Mode.LURE:
			if mark == null or not alone(mark) or MazeWoodsman.lit(get_tree(), mark.global_position):
				_withdraw()
			else:
				_look_at_mark()
				var d := mark.global_position.distance_to(global_position)
				_unseen_for = _unseen_for + delta if not _sees(mark) else 0.0
				if d > lure_lost or _unseen_for > 3.0 or _mode_time > 60.0:
					_withdraw()
				elif d < reach_range and absf(mark.global_position.y - global_position.y) < 2.0:
					_reaches += 1
					_grabbed = false
					figure.aim = _point
					figure.reach()
					_set_mode(Mode.REACH)
				else:
					var to := mark.global_position - global_position
					to.y = 0.0
					var wish := to if nav.line_free(global_position, mark.global_position, _radius) else _way_to(mark.global_position)
					_steer(wish.normalized() if wish.length() > 0.01 else Vector3.ZERO, lure_speed, delta, grounded)
					_pull_local(delta)
		Mode.REACH:
			_steer(Vector3.ZERO, 0.0, delta, grounded)
			if mark:
				_look_at_mark()
			if _mode_time > BeastRig.WIND + BeastRig.GRAB + BeastRig.HOLD + 0.2:
				_withdraw()
		Mode.WITHDRAW, Mode.FLEE:
			var speed := flee_speed if mode == Mode.FLEE else walk_speed * 1.3
			# (back into the side passage it came out of; from there, or fleeing, away from whom it fled)
			var goal_at := _away_from(_point if _point.is_finite() else global_position + Vector3.FORWARD)
			if mode == Mode.WITHDRAW and _hide_cell.x >= 0 and maze.cell_at(global_position) != _hide_cell:
				goal_at = nav.point(_hide_cell)
			var to := goal_at - global_position
			to.y = 0.0
			var wish := to if nav.line_free(global_position, goal_at, _radius) else _way_to(goal_at)
			_steer(wish.normalized() if wish.length() > 0.01 else Vector3.ZERO, speed, delta, grounded)
			# Out of everyone's sight, it is gone.
			if (_mode_time > 1.0 and not _seen_by_anyone()) or _mode_time > 14.0:
				_hide()


func _set_mode(next: Mode) -> void:
	var was := mode
	mode = next
	_mode_time = 0.0
	_unseen_for = 0.0
	if (was == Mode.HIDDEN) != (next == Mode.HIDDEN):
		_show(next != Mode.HIDDEN)


func _withdraw() -> void:
	if mode in [Mode.WITHDRAW, Mode.FLEE, Mode.HIDDEN]:
		return
	_set_mode(Mode.WITHDRAW)


func _hide() -> void:
	shown_at_once = false
	mark = null
	_point = Vector3.INF
	_set_mode(Mode.HIDDEN)


func _look_at_mark() -> void:
	if mark and is_instance_valid(mark):
		_point = mark.global_position + Vector3.UP * 1.0


## Whom to show itself to: the nearest huntable player within its reach of the
## maze (alone first), in its own section.
func _pick_mark() -> void:
	var best: Node3D = null
	var best_score := INF
	for player: Node3D in players():
		if not huntable(player) or not nav.in_own_ring(maze.cell_at(player.global_position)):
			continue
		var d := player.global_position.distance_to(global_position)
		if d > 160.0:
			continue
		var score := d + (0.0 if alone(player) else 60.0)
		if score < best_score:
			best_score = score
			best = player
	mark = best


## Looks for a turning down a straight hall from its mark, as far off as the dark
## lets it come, with a side passage they cannot see to step out of; and there it
## stands, about to step out. (Nothing found: it waits again.)
func _try_show() -> void:
	_pick_mark()
	if mark == null:
		return
	var dark := darkness()
	var with_company := not alone(mark)
	if dark < 0.3 and _rng.randf() > show_chance_day:
		return
	if with_company and _rng.randf() > 0.4:
		return
	var span := far_by_day.lerp(near_in_dark, dark)
	if with_company:
		span += Vector2(14.0, 14.0)
	var eye := mark.global_position + Vector3.UP * 1.5
	var from := maze.cell_at(mark.global_position)
	var found: Array = []
	for step: Vector2i in Maze.STEPS:
		var cell := from
		for k in 10:
			if maze.blocked(cell, step):
				break
			cell += step
			if not nav.allowed(cell) or not nav.in_own_ring(cell):
				break
			var at := nav.point(cell)
			var d := Vector2(at.x - eye.x, at.z - eye.z).length()
			if d < span.x or d > span.y:
				continue
			if not nav.sees(eye, at + Vector3.UP * 2.0, span.y + 5.0):
				continue
			if MazeWoodsman.nearest(get_tree(), at, shun_range):
				continue
			for side: Vector2i in [Vector2i(step.y, step.x), Vector2i(-step.y, -step.x)]:
				var hide := cell + side
				if maze.blocked(cell, side) or not nav.allowed(hide) or not nav.in_own_ring(hide):
					continue
				if nav.sees(eye, nav.point(hide) + Vector3.UP * 2.0, 400.0):
					continue
				found.append([hide, cell])
			# (in the mist and the dark, it may simply be there at the far end, where the mist hides its coming)
			if found.is_empty() and dark > 0.5 and d > 26.0:
				found.append([cell, cell])
	if found.is_empty():
		return
	var pick: Array = found[_rng.randi_range(0, found.size() - 1)]
	_hide_cell = pick[0]
	var start := nav.point(_hide_cell)
	start.y = maze.ground_height(start) + 0.05
	_stand_at = nav.point(pick[1])
	_stand_at.y = maze.ground_height(_stand_at)
	_put(start, atan2(_stand_at.x - start.x, _stand_at.z - start.z))
	_set_mode(Mode.STEP_OUT)


## Whether it sees `who` (and they it), down the passages.
func _sees(who: Node3D) -> bool:
	return nav.sees(global_position + Vector3.UP * 2.2, who.global_position + Vector3.UP * 1.2, lure_lost + 10.0)


## Whether any player could see it now.
func _seen_by_anyone() -> bool:
	for player: Node3D in players():
		if not is_instance_valid(player) or not player.is_inside_tree():
			continue
		if nav.sees(player.global_position + Vector3.UP * 1.5, global_position + Vector3.UP * 2.0, 120.0):
			return true
	return false


## Its hands close: whoever is still within reach is taken into the dark.
func _on_grabbing() -> void:
	if puppet or _grabbed or mark == null or not is_instance_valid(mark):
		return
	_grabbed = true
	var to := mark.global_position - global_position
	if absf(to.y) < 2.2 and Vector2(to.x, to.z).length() < grab_range and huntable(mark):
		_catch(mark)


## Whoever plays on this machine, if it is them it lures: drawn slowly towards it
## while they stand on the ground in its light.
func _pull_local(delta: float) -> void:
	if mode != Mode.LURE:
		return
	var mine := local_player()
	if mine == null or not is_instance_valid(mine):
		return
	var theirs := mark if not puppet else null
	if puppet:
		if not _point.is_finite() or mine.global_position.distance_to(_point - Vector3.UP * 1.0) > 2.5:
			return
	elif theirs != mine:
		return
	if mine.get(&"state") != Player.State.FREE or not mine.is_on_floor():
		return
	var to := global_position - mine.global_position
	to.y = 0.0
	if to.length() < 1.2:
		return
	mine.move_and_collide(to.normalized() * pull * delta)


func _way_to(point_at: Vector3) -> Vector3:
	var to := nav.waypoint(global_position, point_at, MazeNav.clearance_for(_radius)) - global_position
	to.y = 0.0
	return to


func _steer(wish: Vector3, speed: float, delta: float, grounded: bool) -> void:
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, acceleration * delta)
	velocity.x = current.x
	velocity.z = current.z
	if not grounded:
		velocity.y -= gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


## Out of everyone's sight it does not wander as others do: it is nowhere.
func roam_unseen(_step: float) -> void:
	pass


# --- What it looks like ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
		var far := camera != null and camera.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			_show(mode != Mode.HIDDEN)
			figure.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
	if _far or mode == Mode.HIDDEN:
		return
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	var faces := mode in [Mode.WATCH, Mode.LURE, Mode.REACH] and _point.is_finite()
	if faces:
		var to := _point - global_position
		if Vector2(to.x, to.z).length() > 0.2:
			facing_yaw = lerp_angle(facing_yaw, atan2(to.x, to.z), 1.0 - exp(-2.0 * delta))
	elif puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-5.0 * delta))
	elif heading.length_squared() > 0.04:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-3.0 * delta))
	figure.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	figure.rotation = Vector3(0.0, facing_yaw, 0.0)
	figure.velocity = heading
	figure.grounded = is_on_floor() or puppet
	figure.aim = _point if mode in [Mode.STEP_OUT, Mode.WATCH, Mode.LURE, Mode.REACH] else Vector3.INF
	_lure = move_toward(_lure, 1.0 if mode in [Mode.LURE, Mode.REACH] else 0.0, delta * 0.6)
	figure.lure = _lure if mode != Mode.REACH else minf(_lure, 0.35)
	figure.burn = 1.0 if mode == Mode.LURE else (0.25 if mode in [Mode.WITHDRAW, Mode.FLEE] else 0.7)


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Its reaches (low two bits).
func net_flag() -> int:
	return _reaches & 0x03


## Where whoever it lures or looks at is (its look; a guest's own player is drawn
## to it while it lures them).
func net_point() -> Vector3:
	return _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point_at := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point_at)
	_point = point_at
	var reaches := flag & 0x03
	if not _heard_flagged:
		_heard_flagged = true
	elif figure and reaches != (_reaches & 0x03):
		figure.aim = _point
		figure.reach()
	_reaches = reaches


func _heard_changed(_was: int, now: int, _first: bool) -> void:
	var was_hidden := mode == Mode.HIDDEN
	mode = now as Mode
	chasing = mode in [Mode.LURE, Mode.REACH]
	if was_hidden != (mode == Mode.HIDDEN):
		_show(mode != Mode.HIDDEN)
		if mode != Mode.HIDDEN:
			_put(_heard_at, _heard_yaw)


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if figure:
		figure.put(at, facing)


func _puppet_changed() -> void:
	_show(mode != Mode.HIDDEN)

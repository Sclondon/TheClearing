class_name MazeLizardPerson
extends MazeEnemy
## One of a band of lizard people (creatures/lizard_person: LizardPerson), set
## to hunt the maze from its walls. This is only its thinking; how it looks and
## moves is the creature's.
##
## - IT WAITS on a wall over a hall (`CLING_HIGH` up it), head down, flat to the
##   face like a gecko, now and then shifting along it. It is put in a cell and
##   finds the nearest wall itself (rays, eight ways), the first moment it is in
##   the world. From up there it watches the hall (a line of sight from just off
##   the face), and it tastes the air: anyone within `hear_range`, round corners
##   and all, is noticed. When one of a band notices someone, the rest near it
##   take up the hunt (`alert_range`).
## - IT STALKS along its wall: whoever it is after, if it can see them from its
##   wall, it skitters along the face to keep level with them, a few metres up,
##   in dashes and dead stops. Climbing does not save you: if they are up a
##   wall (the ivy, a terrace, a vine) it goes straight up the face at them, or
##   runs to the foot of their wall and up it, and over the top after them; up
##   on a ledge, a terrace or a concrete bridge, to the foot of its front, up it,
##   over the lip and along the top to them (MazeEnemy's CLIMBING: the user,
##   2026-10-18, "more creatures should be able to climb things"; its own crawl
##   up a face loses sight of them behind the lip).
## - IT HISSES first (the warning, `LizardPerson.hiss`: reared off the face, arms
##   spread, mouth gaping, the dewlap fanned out), for `HISS_TIME`, and then
##   LEAPS at where they were when it sprang, from as far as `POUNCE_RANGE` out
##   from its wall. Landing on them, or its claws or jaws reaching them in the
##   air, catches. Keep moving and it lands behind you.
## - ON THE GROUND (it drops off its wall when it cannot keep them in sight from
##   it) it scuttles after them by the passages on all fours: by day a little
##   quicker than a run and slower than a sprint. Near (`HISS_RANGE`) it gives
##   its warning as it comes, gaping and hissing with its dewlap out, and a
##   moment after lunges low with its hands and jaws out (`LUNGE_RANGE`), fast
##   enough to reach someone running; touching it catches too.
## - IT IS COLD-BLOODED: its `warmth` comes from the hour and the weather (the
##   World's DayCycle and Weather, if there are any): warm by day, sluggish at
##   night and in rain. Cold, it is slower on the ground and the walls (at night
##   slower than a run), slower to strike, sees and tastes less far, and does not
##   come down off its wall at all unless someone walks right under it.
## - IT GOES BACK UP when it has lost them (`memory` runs out): to the nearest
##   high wall, up it, and waits again.
##
## Online, the host's thinks; a puppet follows its news (MazeEnemy), and is
## posed from what it is doing (on which wall, in the air, hissing, lunging).
##
## Spawn (as MazeEnemies does any MazeEnemy): `MazeLizardPerson.band(3)`, each
## with `maze` set, put a little apart in a hall, added to the scene.

## What it is doing, as sent (`net_state`).
enum Mode { CLING, CRAWL, HISS, POUNCE, HUNT, LUNGE, RETURN, CLIMB }

## How high up its wall it waits, and how high it keeps stalking alongside someone.
const CLING_HIGH := 5.5
const STALK_HIGH := 3.0
## How far out from its wall (along the ground) it leaps at someone, and how fast it flies.
const POUNCE_RANGE := 7.0
const POUNCE_SPEED := 9.5
## How near its body (or claws or jaws) must come in the air or a lunge to catch.
const CATCH_RADIUS := 0.9
## How near and square in front someone must be on the ground for it to rear and lunge;
## its lunge, and how far short of them it stops (as the spider's).
const LUNGE_RANGE := 2.8
const LUNGE_SPEED := 14.0
const LUNGE_TO := 0.5
## How near on the ground it gives its warning (hissing and gaping as it comes).
const HISS_RANGE := 5.5
## Touching it on the ground catches.
const TOUCH := 0.8
## Speeds (cold, warm), m/s: on the ground, and on a wall.
const RUN_SPEED := Vector2(2.8, 5.1)
const WALL_SPEED := Vector2(1.5, 4.2)
## The warning (cold, warm), seconds.
const HISS_TIME := Vector2(1.1, 0.55)
## Colder than this it stays on its wall unless someone is under it.
const SLUGGISH := 0.35
## Its dashes and dead stops along a wall (seconds, least and most).
const DASH := Vector2(0.5, 1.0)
const STOP := Vector2(0.25, 0.6)
## Seconds from the ground onto the face.
const CLIMB_ON := 0.45
## Someone this far above the ground under them is up a wall.
const UP_HIGH := 2.0
const RADIUS := 0.4
const ACCELERATION := 30.0
## The ways it looks for a wall (round rings' walls are not square to the axes).
const LOOKS: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1),
	Vector3(0.7071, 0, 0.7071), Vector3(-0.7071, 0, 0.7071), Vector3(0.7071, 0, -0.7071), Vector3(-0.7071, 0, -0.7071)]

@export var gravity := 24.0
## Further than this from every player it is not posed or drawn.
@export var pose_range := 75.0
## For tests: how warm it is (0..1) instead of what the day says (-1: the day).
@export var warmth_override := -1.0

var mode := Mode.CLING
## The creature.
var look: LizardPerson
## The wall it is on (its normal; ZERO on the ground), where on it it waits, and
## the foot of the wall it is making for.
var wall := Vector3.ZERO
var cling_spot := Vector3.INF
var wall_foot := Vector3.INF
## How warm it is now, 0..1.
var warmth := 1.0
## Hisses and lunges made (for puppets to copy).
var acts := 0

var _mode_time := 0.0
var _heading := Vector3.BACK
var _on_wall_hiss := false
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _leap_time := 1.0
var _leap_height := 0.5
var _climb_from := Vector3.ZERO
var _climb_to := Vector3.ZERO
var _climb_normal := Vector3.ZERO
var _caught_one := false
var _warned := 99.0
var _dash_left := 0.0
var _stopped := false
var _shift_in := 8.0
var _wall_look_in := 0.0
var _placed := false
# (going up after someone by HighClimb last step)
var _climbed := false
var _stuck := 0.0
var _far := false
var _far_check := 0.0
var _warm_in := 0.0
var _day: Node
var _weather: Node
var _found_world := false
var _last_lunge := false
var _heard_acts := -1


## A band of `count`.
static func band(count := 3) -> Array[MazeLizardPerson]:
	var made: Array[MazeLizardPerson] = []
	for k in count:
		made.append(MazeLizardPerson.new())
	return made


func _init() -> void:
	sight_range = 36.0
	hear_range = 11.0
	memory = 6.0
	alert_range = 32.0
	pack = &"lizard_people"
	climbs = Climbs.SCRAMBLE
	climb_speed = 3.0


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.4
	var shape := SphereShape3D.new()
	shape.radius = RADIUS
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = RADIUS
	add_child(collider)
	look = LizardPerson.new()
	look.name = "Look"
	look.size = _rng.randf_range(0.95, 1.07)
	look.seed_value = _rng.randi()
	look.low_poly = Settings.low_poly
	look.top_level = true
	add_child(look)
	look.global_position = global_position
	_heading = Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	look.heading = _heading
	look.settle()
	_shift_in = _rng.randf_range(4.0, 12.0)


# --- Thinking ---

func _physics_process(delta: float) -> void:
	_cull(delta)
	if puppet:
		_follow_heard(delta)
		_pose()
		return
	if maze == null:
		return
	if not _placed:
		_placed = true
		_go_up_nearest_wall(true)
	_mode_time += delta
	_warm_in -= delta
	if _warm_in <= 0.0:
		_warm_in = 1.0
		_warm_up()
	_sense(delta)
	# Up after someone on a ledge, a terrace or a bridge (HighWays: its own crawl up a
	# face loses them behind the lip): to the foot, up the front, over, and along the top.
	if (climbing_now() or (mode == Mode.HUNT and is_on_floor())) and _ways_up(delta, RADIUS, _run_speed()):
		_climbed = true
		var on_face := aloft == HighClimb.Aloft.CLIMB or aloft == HighClimb.Aloft.DOWN
		wall = aloft_out() if on_face else Vector3.ZERO
		var facing := aloft_yaw()
		_heading = (Vector3.UP if aloft == HighClimb.Aloft.CLIMB else Vector3.DOWN) if on_face else Vector3(sin(facing), 0.0, cos(facing))
		chasing = true
		_pose()
		return
	if _climbed:
		# (down again: on the ground, as its own)
		_climbed = false
		wall = Vector3.ZERO
		_enter(Mode.HUNT)
	var before := global_position
	match mode:
		Mode.CLING:
			_cling(delta)
		Mode.CRAWL:
			_crawling(delta)
		Mode.HISS:
			_hissing(delta)
		Mode.POUNCE:
			_flying()
		Mode.HUNT:
			_hunt(delta)
		Mode.LUNGE:
			_lunging(delta)
		Mode.RETURN:
			_return(delta)
		Mode.CLIMB:
			_climb()
	chasing = hunting() and mode != Mode.CLING
	if wall != Vector3.ZERO or mode == Mode.POUNCE or mode == Mode.CLIMB:
		# (moved by hand there: its speed, for the others to follow)
		velocity = (global_position - before) / delta
	_pose()


func _enter(next: Mode) -> void:
	mode = next
	_mode_time = 0.0


## How warm it is: from the hour (DayCycle.daylight) and the rain (Weather.rain).
## Its senses and speeds go with it.
func _warm_up() -> void:
	if not _found_world:
		_found_world = true
		var node := get_parent()
		while node:
			if node.get(&"day") is Node:
				_day = node.get(&"day")
				_weather = node.get(&"weather") as Node
				break
			node = node.get_parent()
	var w := 1.0
	if warmth_override >= 0.0:
		w = warmth_override
	elif is_instance_valid(_day):
		w = lerpf(0.12, 1.0, float(_day.get(&"daylight")))
		if is_instance_valid(_weather):
			w *= 1.0 - 0.45 * float(_weather.get(&"rain"))
	warmth = clampf(w, 0.0, 1.0)
	sight_range = lerpf(16.0, 36.0, warmth)
	hear_range = lerpf(5.0, 11.0, warmth)


func _run_speed() -> float:
	return lerpf(RUN_SPEED.x, RUN_SPEED.y, warmth)


func _wall_speed() -> float:
	return lerpf(WALL_SPEED.x, WALL_SPEED.y, warmth)


func _hiss_time() -> float:
	return lerpf(HISS_TIME.x, HISS_TIME.y, warmth)


## On its wall, waiting: looks down the hall, and now and then shifts along the face.
func _cling(delta: float) -> void:
	velocity = Vector3.ZERO
	_watch(delta)
	if hunting():
		_enter(Mode.CRAWL)
		return
	_shift_in -= delta
	if _shift_in <= 0.0 and wall != Vector3.ZERO:
		_shift_in = _rng.randf_range(6.0, 15.0)
		var side := Vector3.UP.cross(wall).normalized()
		cling_spot = global_position + side * _rng.randf_range(-4.0, 4.0)
		cling_spot.y = _ground_under(global_position) + _rng.randf_range(CLING_HIGH - 1.2, CLING_HIGH + 1.0)
		_enter(Mode.CRAWL)


## From a wall: looks along the hall for anyone (a line from just off the face).
func _watch(delta: float) -> void:
	_wall_look_in -= delta
	if _wall_look_in > 0.0 or hunting():
		return
	_wall_look_in = 0.25
	var eye := global_position + wall * 0.8
	for player: Node3D in players():
		if not huntable(player):
			continue
		var chest := player.global_position + Vector3.UP
		if eye.distance_to(chest) < sight_range and _clear_line(eye, chest):
			notice(player)
			return


## On a wall, going somewhere on it: after someone (keeping level with them,
## or straight at them if they are up a wall), or to the place it waits.
func _crawling(delta: float) -> void:
	_watch(delta)
	if wall == Vector3.ZERO:
		_enter(Mode.HUNT)
		return
	if not hunting():
		if not cling_spot.is_finite():
			cling_spot = global_position
		var got := _crawl_to(cling_spot, _wall_speed() * 0.6, delta)
		if got != 0:
			_heading = Vector3.DOWN
			_enter(Mode.CLING)
		return
	var q := quarry.global_position
	var chest := q + Vector3.UP
	var eye := global_position + wall * 0.8
	var sees := _clear_line(eye, chest)
	var out := (q - global_position).dot(wall)
	var flat := Vector2(q.x - global_position.x, q.z - global_position.z).length()
	var climbing := _is_up(quarry)
	var cold := warmth < SLUGGISH
	if sees and out > -0.3:
		# Within a leap of them: the warning, then the leap.
		var reach := POUNCE_RANGE if not cold else 3.5
		if (flat < reach and q.y < global_position.y + 0.8) or global_position.distance_to(chest) < 1.8:
			_start_hiss(true)
			return
		if climbing and out < 3.0:
			# Up the face at them.
			if _crawl_to(chest, _wall_speed(), delta) == 2 and q.y > global_position.y:
				_over_the_top()
			return
		if not cold:
			# Along the face, level with them, a few metres up, in dashes and stops.
			var spot := q - wall * out
			spot.y = _ground_under(q) + STALK_HIGH
			_dash(delta)
			if _stopped:
				_heading = (spot - global_position).normalized() if spot.distance_to(global_position) > 0.3 else _heading
				return
			if _crawl_to(spot, _wall_speed(), delta) == 2:
				_jump_down()
			return
	if not cold or flat < 6.0:
		# Out of sight from here: down, and after them by the passages.
		_jump_down()


## Its dashes and dead stops: `_stopped` while it is still.
func _dash(delta: float) -> void:
	_dash_left -= delta
	if _dash_left <= 0.0:
		_stopped = not _stopped
		var span := STOP if _stopped else DASH
		_dash_left = _rng.randf_range(span.x, span.y) * (1.0 if _stopped else lerpf(1.6, 1.0, warmth))


## Crawls along its wall towards `target` (taken onto the face) at `speed`: 0 on
## the way, 1 there, 2 it can go no further that way (the wall ends, or something
## is in the way).
func _crawl_to(target: Vector3, speed: float, delta: float) -> int:
	var to := target - global_position
	to -= wall * to.dot(wall)
	if to.length() < 0.15:
		return 1
	var step := to.normalized() * minf(speed * delta, to.length())
	var next := global_position + step
	var skip := _skip_players()
	var space := get_world_3d().direct_space_state
	# (something across the face: an inner corner, a ledge)
	var ahead := PhysicsRayQueryParameters3D.create(global_position + wall * 0.3, next + wall * 0.3 + step.normalized() * 0.5, 1, skip)
	if not space.intersect_ray(ahead).is_empty():
		return 2
	# (still on the face there)
	var onto := PhysicsRayQueryParameters3D.create(next + wall * 0.6, next - wall * 0.6, 1, skip)
	var hit := space.intersect_ray(onto)
	if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.3:
		return 2
	var normal: Vector3 = hit["normal"]
	normal.y = 0.0
	wall = normal.normalized()
	global_position = (hit["position"] as Vector3) + wall * 0.02
	_heading = step.normalized()
	# (and never down into the ground)
	var low := _ground_under(global_position) + 0.6
	if global_position.y < low:
		global_position.y = low
	return 0


## At the top of a wall, after someone up there: over the edge and onto the top.
func _over_the_top() -> void:
	var space := get_world_3d().direct_space_state
	var over := global_position - wall * 0.7
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(over + Vector3.UP * 1.2, over - Vector3.UP * 0.6, 1, _skip_players()))
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7:
		return
	global_position = hit["position"]
	_heading = -wall
	wall = Vector3.ZERO
	velocity = Vector3.ZERO
	_enter(Mode.HUNT)


func _start_hiss(on_wall: bool) -> void:
	_on_wall_hiss = on_wall
	acts += 1
	_last_lunge = false
	look.hiss(_hiss_time())
	_enter(Mode.HISS)


## The warning; then the leap (off a wall) or the lunge (on the ground).
func _hissing(delta: float) -> void:
	velocity = Vector3(0.0, velocity.y, 0.0) if wall == Vector3.ZERO else Vector3.ZERO
	if quarry and wall == Vector3.ZERO:
		var flat := quarry.global_position - global_position
		_turn(flat, delta, 9.0)
	if wall == Vector3.ZERO:
		_move(delta, Vector3.ZERO)
	if _mode_time < _hiss_time():
		return
	if not hunting():
		_enter(Mode.CRAWL if wall != Vector3.ZERO else Mode.RETURN)
		return
	var q := quarry.global_position
	if _on_wall_hiss and wall != Vector3.ZERO:
		var flat := Vector2(q.x - global_position.x, q.z - global_position.z).length()
		if flat < POUNCE_RANGE * 1.35 and _clear_line(global_position + wall * 0.8, q + Vector3.UP):
			_leap(q + Vector3.UP * (0.0 if not _is_up(quarry) else 0.6), true)
		else:
			_enter(Mode.CRAWL)
		return
	acts += 1
	_last_lunge = true
	look.lunge()
	_caught_one = false
	_enter(Mode.LUNGE)


## Off its wall through the air to `to` (where they were, or the foot of the wall).
func _leap(to: Vector3, at_them: bool) -> void:
	_leap_from = global_position
	_leap_to = to
	var span := _leap_from.distance_to(_leap_to)
	_leap_time = clampf(span / POUNCE_SPEED, 0.4, 0.95) if at_them else clampf(0.35 + span * 0.04, 0.4, 0.8)
	_leap_height = 0.3 + 0.06 * span
	_caught_one = false
	var flat := to - global_position
	flat.y = 0.0
	if flat.length() < 0.1:
		flat = wall
	_heading = flat.normalized()
	wall = Vector3.ZERO
	_enter(Mode.POUNCE)


## Down off its wall to the ground at its foot.
func _jump_down() -> void:
	var foot := global_position + wall * 1.4
	foot.y = _ground_under(foot)
	_leap(foot, false)


func _flying() -> void:
	var t := clampf(_mode_time / _leap_time, 0.0, 1.0)
	var at := _leap_from.lerp(_leap_to, t)
	at.y += sin(PI * t) * _leap_height
	global_position = at
	velocity = Vector3.ZERO
	if t > 0.35 and not _caught_one:
		var body := global_position + Vector3.UP * 0.4
		for player: Node3D in players():
			if not huntable(player):
				continue
			var chest := player.global_position + Vector3.UP * 0.9
			if body.distance_to(chest) < CATCH_RADIUS + 0.35 or look.reaches(chest, CATCH_RADIUS * 0.6):
				_caught_one = true
				_catch(player)
				break
	if t >= 1.0:
		# (landed, or falls the rest of the way: the ground takes it from here)
		velocity = _heading * 2.0
		_dash_left = 0.0
		_enter(Mode.HUNT)


func _hunt(delta: float) -> void:
	if not hunting():
		_go_up_nearest_wall()
		return
	if _mode_time < 0.35 and is_on_floor():
		# (gathering itself after a landing)
		_move(delta, Vector3.ZERO)
		return
	var q := quarry.global_position
	var flat := q - global_position
	flat.y = 0.0
	if flat.length() < TOUCH and absf(q.y - global_position.y) < 1.6:
		_catch(quarry)
		return
	# Up a wall after someone who is up one.
	if _is_up(quarry) and flat.length() < 14.0 and is_on_floor() and q.y > global_position.y + UP_HIGH:
		var face := _wall_towards(q)
		if not face.is_empty():
			wall_foot = face[1]
			_climb_normal = face[0]
			var to_foot := wall_foot - global_position
			to_foot.y = 0.0
			if to_foot.length() < 0.5:
				_start_climb()
				return
			_move(delta, to_foot.normalized() * _run_speed())
			_turn(to_foot, delta, 10.0)
			return
	# Near, the warning as it comes (a hiss, gaping), and then the lunge.
	_warned += delta
	var sees := flat.length() < HISS_RANGE and _clear_line(global_position + Vector3.UP * 0.6, q + Vector3.UP)
	if sees and _warned > _hiss_time() + 3.0:
		_warned = 0.0
		acts += 1
		_last_lunge = false
		look.hiss(_hiss_time())
	if flat.length() < LUNGE_RANGE and absf(q.y - global_position.y) < 1.4 and is_on_floor() and _heading.dot(flat.normalized()) > 0.5 \
			and _warned >= _hiss_time() and _warned < _hiss_time() + 3.0:
		acts += 1
		_last_lunge = true
		look.lunge()
		_caught_one = false
		_enter(Mode.LUNGE)
		return
	var wish := Vector3.ZERO
	var high := global_position.y > _ground_under(global_position) + UP_HIGH
	var way_to := (flat if high else way(RADIUS))
	wish = way_to.normalized() if way_to.length() > 0.05 else Vector3.ZERO
	var push := _apart(RADIUS)
	if push != Vector3.ZERO:
		wish = (wish + push * 0.6).normalized()
	_move(delta, wish * _run_speed())
	var face_to := Vector3(velocity.x, 0.0, velocity.z)
	if face_to.length() < 0.5:
		face_to = flat
	_turn(face_to, delta, 10.0)


func _lunging(delta: float) -> void:
	if _far:
		look.settle()
		_enter(Mode.HUNT)
		return
	var stage := look.lunge_stage()
	if stage == LizardPerson.Stage.REACH:
		var gap := LUNGE_SPEED
		if quarry:
			gap = clampf(((quarry.global_position - global_position).dot(_heading) - LUNGE_TO) / delta, 0.0, LUNGE_SPEED)
		velocity.x = _heading.x * gap
		velocity.z = _heading.z * gap
		velocity.y -= gravity * delta
		move_and_slide()
		if not _caught_one:
			for player: Node3D in players():
				if not huntable(player):
					continue
				var feet := player.global_position
				var near := (feet - global_position)
				near.y = 0.0
				if look.reaches(feet + Vector3.UP * 0.8, CATCH_RADIUS * 0.7) or look.reaches(feet + Vector3.UP * 0.3, CATCH_RADIUS * 0.7) or near.length() < TOUCH:
					_caught_one = true
					_catch(player)
					break
		return
	# (gathering, it comes on as it was; recovering, it stops)
	_move(delta, _heading * _run_speed() if stage == LizardPerson.Stage.GATHER else Vector3.ZERO)
	if stage == LizardPerson.Stage.NONE or (stage == LizardPerson.Stage.RECOVER and look.lunge_progress() > 0.6):
		_enter(Mode.HUNT)
		_mode_time = 0.35


## Makes for the nearest wall that will do (or, at `now`, goes straight up onto it, for the start).
func _go_up_nearest_wall(now := false) -> void:
	var found := _find_wall(global_position)
	wall = Vector3.ZERO
	if found.is_empty():
		wall_foot = Vector3.INF
		_stuck = -2.5
		_enter(Mode.RETURN)
		return
	cling_spot = found[0]
	_climb_normal = found[1]
	wall_foot = found[2]
	_stuck = 0.0
	if now:
		wall = found[1]
		global_position = cling_spot
		_heading = Vector3.DOWN
		look.surface = wall
		look.heading = Vector3.DOWN
		look.global_position = cling_spot
		look.settle()
		_enter(Mode.CLING)
		return
	_enter(Mode.RETURN)


func _return(delta: float) -> void:
	if hunting():
		_enter(Mode.HUNT)
		return
	if not wall_foot.is_finite():
		# Nowhere to climb from here: wander a while and look again.
		_stuck += delta
		var to := way(RADIUS)
		_move(delta, to.normalized() * 1.2 if to.length() > 0.05 else Vector3.ZERO)
		_turn(Vector3(velocity.x, 0.0, velocity.z), delta, 5.0)
		if _stuck > 0.0:
			_go_up_nearest_wall()
		return
	var to := wall_foot - global_position
	to.y = 0.0
	if to.length() < 0.35:
		_start_climb()
		return
	var before := global_position
	# (it walks back upright, unhurried)
	_move(delta, to.normalized() * minf(1.3, to.length() * 3.0))
	_turn(to, delta, 6.0)
	_stuck = _stuck + delta if before.distance_to(global_position) < 1.3 * delta * 0.25 else 0.0
	if _stuck > 2.5:
		_go_up_nearest_wall()


## From the foot of a wall (`_climb_normal` its face) up onto it (and then after
## whoever it is after, or up to wait).
func _start_climb() -> void:
	_climb_from = global_position
	var space := get_world_3d().direct_space_state
	var low := global_position + Vector3.UP * 1.0
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(low, low - _climb_normal * 3.0, 1, _skip_players()))
	if hit.is_empty():
		_go_up_nearest_wall()
		return
	_climb_to = (hit["position"] as Vector3) + _climb_normal * 0.02
	cling_spot = Vector3(_climb_to.x, _ground_under(_climb_to) + CLING_HIGH, _climb_to.z)
	_enter(Mode.CLIMB)


func _climb() -> void:
	var t := smoothstep(0.0, CLIMB_ON, _mode_time)
	global_position = _climb_from.lerp(_climb_to, t)
	wall = _climb_normal
	_heading = Vector3.UP
	velocity = Vector3.ZERO
	if _mode_time >= CLIMB_ON:
		_stopped = false
		_dash_left = 0.0
		_enter(Mode.CRAWL)


func _move(delta: float, wish: Vector3) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish, ACCELERATION * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= gravity * delta
	move_and_slide()


func _turn(toward: Vector3, delta: float, rate: float) -> void:
	toward.y = 0.0
	if toward.length_squared() < 0.0001:
		return
	var flat := Vector3(_heading.x, 0.0, _heading.z)
	if flat.length_squared() < 0.0001:
		flat = toward
	flat = flat.normalized()
	_heading = flat.slerp(toward.normalized(), 1.0 - exp(-rate * delta)).normalized() if flat.dot(toward.normalized()) < 0.9999 else toward.normalized()


## The ground's height under a point.
func _ground_under(at: Vector3) -> float:
	return maze.ground_height(at) if maze else 0.0


## Whether someone is up off the ground (on a wall's ivy, a terrace, a vine, a wall top).
func _is_up(player: Node3D) -> bool:
	return player.global_position.y > _ground_under(player.global_position) + UP_HIGH


## The nearest wall face round `from` high enough to wait on: [where it waits
## on it, the face's normal, the foot of it on the ground], or [].
func _find_wall(from: Vector3, reach := 24.0) -> Array:
	var space := get_world_3d().direct_space_state
	var skip := _skip_players()
	var best: Array = []
	var nearest := INF
	var ground := _ground_under(from)
	for dir in LOOKS:
		var low := Vector3(from.x, ground + 2.5, from.z)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(low, low + dir * reach, 1, skip))
		if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.3:
			continue
		var high := Vector3(from.x, ground + CLING_HIGH + 0.8, from.z)
		var up_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(high, high + dir * reach, 1, skip))
		if up_hit.is_empty() or (up_hit["position"] as Vector3).distance_to(hit["position"] as Vector3) > CLING_HIGH:
			continue
		var d := low.distance_to(hit["position"])
		if d < nearest:
			nearest = d
			var normal: Vector3 = hit["normal"]
			normal.y = 0.0
			normal = normal.normalized()
			var spot: Vector3 = hit["position"]
			spot.y = ground + CLING_HIGH
			var foot: Vector3 = hit["position"]
			foot = Vector3(foot.x, ground, foot.z) + normal * 0.7
			best = [spot + normal * 0.02, normal, foot]
	return best


## The face of the wall that someone up off the ground is on or over:
## [its normal, the foot of it under them], or [].
func _wall_towards(at: Vector3) -> Array:
	var space := get_world_3d().direct_space_state
	var skip := _skip_players()
	var best: Array = []
	var nearest := INF
	var ground := _ground_under(global_position)
	for dir in LOOKS:
		var from := Vector3(at.x, ground + 1.2, at.z) - dir * 1.5
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * 4.0, 1, skip))
		if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.3:
			continue
		var d := (hit["position"] as Vector3).distance_to(Vector3(at.x, ground + 1.2, at.z))
		if d < nearest:
			nearest = d
			var normal: Vector3 = hit["normal"]
			normal.y = 0.0
			normal = normal.normalized()
			var foot: Vector3 = hit["position"]
			best = [normal, Vector3(foot.x, ground, foot.z) + normal * 0.6]
	return best


# --- How it looks ---

## Gives the creature what it is doing.
func _pose() -> void:
	if look == null or _far:
		return
	look.global_position = global_position
	look.surface = wall if wall != Vector3.ZERO else Vector3.UP
	look.heading = _heading
	look.airborne = mode == Mode.POUNCE
	look.crouch = mode in [Mode.HUNT, Mode.LUNGE, Mode.CLIMB] or (mode == Mode.HISS and wall != Vector3.ZERO)
	look.warmth = warmth
	look.tasting = 1.0 if hunting() or _last_seen.is_finite() else 0.25
	look.aim = quarry.global_position + Vector3.UP if quarry and (chasing or mode == Mode.HISS) else Vector3.INF


## What its rays pass through: itself and the players.
func _skip_players() -> Array[RID]:
	var skip: Array[RID] = [get_rid()]
	for player: Node in players():
		if player is CollisionObject3D and is_instance_valid(player):
			skip.append((player as CollisionObject3D).get_rid())
	return skip


## Out of everyone's way, it is not posed or drawn (the walls hide it).
func _cull(delta: float) -> void:
	_far_check -= delta
	if _far_check > 0.0 or look == null:
		return
	_far_check = 0.5
	var near := nearest_player(global_position)
	var far := near == null or near.global_position.distance_to(global_position) > pose_range
	if far != _far:
		_far = far
		look.visible = not far
		look.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
		if not far:
			_pose()
			look.settle()


# --- Being run by someone else ---

## On the ground, the way it faces about Y; on a wall, the way it faces in the
## face, from straight up, turning towards the wall's right (as one faces it).
func yaw() -> float:
	if wall != Vector3.ZERO:
		var side := Vector3.UP.cross(wall).normalized()
		return atan2(_heading.dot(side), _heading.dot(Vector3.UP))
	return atan2(_heading.x, _heading.z)


func net_state() -> int:
	return mode


## Hisses and lunges made (low four bits), whether the last was a lunge, and how warm it is (top three).
func net_flag() -> int:
	return (acts & 0x0f) | ((1 if _last_lunge else 0) << 4) | (clampi(int(warmth * 7.0 + 0.5), 0, 7) << 5)


## Off the wall it is on, by its normal (INF on the ground).
func net_point() -> Vector3:
	return global_position + wall if wall != Vector3.ZERO else Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	wall = Vector3.ZERO
	if point.is_finite():
		var normal := point - at
		normal.y = 0.0
		if normal.length() > 0.3:
			wall = normal.normalized()
	if wall != Vector3.ZERO:
		var side := Vector3.UP.cross(wall).normalized()
		_heading = Vector3.UP * cos(facing) + side * sin(facing)
	else:
		_heading = Vector3(sin(facing), 0.0, cos(facing))
	warmth = ((flag >> 5) & 7) / 7.0
	chasing = mode in [Mode.CRAWL, Mode.HISS, Mode.POUNCE, Mode.HUNT, Mode.LUNGE]
	var count := flag & 0x0f
	if _heard_acts >= 0 and count != _heard_acts and look:
		if (flag >> 4) & 1:
			look.lunge()
		else:
			look.hiss(_hiss_time())
	_heard_acts = count


## As a puppet: on the walls and in the air it is put where it is heard to be
## (gravity has no say); on the ground it walks there as MazeEnemy follows.
func _follow_heard(delta: float) -> void:
	if not _heard:
		return
	if wall != Vector3.ZERO or mode in [Mode.POUNCE, Mode.CLIMB]:
		_heard_at += _heard_moving * delta
		global_position = global_position.lerp(_heard_at, 1.0 - exp(-12.0 * delta))
		velocity = Vector3.ZERO
	else:
		_follow(delta)


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	if wall == Vector3.ZERO:
		_heading = Vector3(sin(facing), 0.0, cos(facing))
	if look:
		_pose()
		look.settle()


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4


## Whether nothing of the world stands between two points.
func _clear_line(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, _skip_players())
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

class_name MazeGriffinfly
extends MazeEnemy
## A griffinfly (creatures/griffinfly/: a giant dragonfly of the coal forests, a
## Meganeura, 1.2 m across the wings) that holds a stretch of the maze's halls,
## or a patch of the marsh, as its own. This is only its thinking; how it looks,
## flies and sounds is the `Griffinfly` component.
##
## - IT PATROLS its halls (`territory` cells round where it was put; or, with
##   `home_radius`, the open ground that far round it: the marsh) as a dragonfly
##   hunts: hovering, then darting off fast and straight, turning sharply, gliding
##   now and then on still wings, high and low under the walls. Now and then it
##   rests on a wall, head up, wings out flat, and takes off as anyone comes near.
## - IT HUNTS THE SMALL (Ecology: a meat-eater of size 1): hungry, it darts at
##   anything smaller it sees and takes it in its basket of legs, and eats on the
##   wing a while. Anything bigger and hungry near it it flies from, up out of reach.
## - IT BUZZES whoever comes into its halls. Seeing someone (`sight_range`), it
##   closes in and hangs in the air a few metres in front of them at head height
##   (STALK), its wings loud; then the warning (WIND, `WIND_TIME`): it stops dead
##   facing them, its legs thrown forward into a basket, its jaws open, its wings
##   clattering louder; then it STRIKEs: a dart straight through where they were
##   (its line is set when it goes), at head height, and on past them. Step out of
##   its line, or duck (or slide, crawl, roll), and it misses. If it hits, they
##   are knocked down (`knock`: sprawled in the maze, a stumble over the marsh),
##   not caught; it pulls up and away, and comes again after a few seconds.
## - TOGETHER they can take someone: a pair holds the same halls, and someone on
##   their own (no one else within `ALONE` metres) hit `HARRY_HITS` times inside
##   `HARRY_TIME` seconds, by both of them, is thrown down limp and caught. Never
##   over the clearing (the marsh ones only ever knock).
## - IT LOSES THEM when they leave its halls (`leash` cells from home; it goes
##   back), get into the clearing (the maze ones), or out of its sight for `memory`.
##
## Online, the host thinks; a puppet follows its news (what it is doing, where its
## strike is aimed or where it hit, which way it faces), and a strike that hit
## this machine's own player knocks him down here.
##
## Spawn (as MazeEnemies does any MazeEnemy): `MazeGriffinfly.new()`, `maze` set,
## put in a hall cell, added to the scene (`marsh_middle` says where over the marsh).

enum Mode { PATROL, PERCH, PREY, EAT, STALK, WIND, STRIKE, PULL, FLEE, HOME }

## Wing tip to wing tip, metres.
const WINGSPAN := 1.4
## How high over the ground it patrols (least, most), hangs in front of someone, and strikes.
const PATROL_HEIGHT := Vector2(2.2, 6.5)
const STALK_HEIGHT := 2.2
const STRIKE_HEIGHT := 1.35
## How fast it darts on patrol, closes in, and strikes (m/s).
const DART_SPEED := 8.5
const CLOSE_SPEED := 7.0
const STRIKE_SPEED := 13.0
## How far in front of someone it hangs before it strikes, how long the warning
## lasts (seconds), and how far it carries on past them.
const WIND_DISTANCE := 6.0
const WIND_TIME := 1.0
const STRIKE_PAST := 5.0
## How near its basket must pass someone's body to hit them.
const HIT_RADIUS := 0.42
## How tall someone counts as, standing and low (the boy: Player.stand_height, crouch_height).
const TALL := 1.55
const LOW := 0.75
## After a hit, how long anyone is let alone by every griffinfly (seconds), and how
## long it waits before it comes again.
const KNOCK_GRACE := 2.5
const AGAIN := Vector2(2.5, 4.0)
## Someone alone (no one within ALONE metres) hit HARRY_HITS times by two of them
## inside HARRY_TIME seconds is caught.
const HARRY_HITS := 3
const HARRY_TIME := 20.0
const ALONE := 12.0
## How long it is down, limp, before it counts (the last of a harrying).
const DOWN_TIME := 1.2

## How many cells round where it was put it patrols, and how far it follows someone.
@export var territory := 3
@export var leash := 6
## Over open ground (the marsh): how far round where it was put it patrols, metres (0: the maze's halls).
@export var home_radius := 0.0
## The chance that it rests on a wall when it stops on patrol.
@export var perch_chance := 0.18
## Further than this from every player it is not posed or drawn.
@export var pose_range := 70.0

var mode := Mode.PATROL
## The creature.
var look: Griffinfly
## Where it was put (its halls are round here).
var home := Vector3.INF
## Its strike: where it set out from and the point it is making for (their chest, led a little).
var strike_from := Vector3.INF
var strike_to := Vector3.INF
## Whether its last strike hit, how many it has hit in all, and where it last hit.
var struck := false
var strikes := 0
var last_hit := Vector3.INF
## Where it rests (on a wall), and the way out of the wall.
var perch_at := Vector3.INF
var perch_out := Vector3.BACK

## Everyone a griffinfly has hit lately (player -> [[seconds, griffinfly id], ...]), and when each was last knocked down.
static var _hits := {}
static var _knocked := {}

var _mode_time := 0.0
var _heading := Vector3.FORWARD
var _goal := Vector3.INF
var _hover := 0.0
var _gliding := false
var _leg := 6.0
var _short := false
var _anchor := Vector3.ZERO
var _route_in := 0.0
var _route_for := Vector3.INF
var _route_aim := Vector3.INF
var _hold := Vector3.INF
var _hold_in := 0.0
var _in_sight := false
var _pick_in := 0.0
var _ground := 0.0
var _ground_in := 0.0
var _again := 0.0
var _far := false
var _far_check := 0.0
var _last_at := Vector3.ZERO
var _heard_strikes := -1
var _side := 1.0


func _init() -> void:
	sight_range = 30.0
	hear_range = 5.0
	memory = 6.0
	alert_range = 24.0
	pack = &"griffinflies"
	look_every = 0.25


func _ready() -> void:
	add_to_group(&"pursuers")
	var shape := CollisionShape3D.new()
	var round_body := SphereShape3D.new()
	round_body.radius = 0.28
	shape.shape = round_body
	add_child(shape)
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 0
	Griffinfly.low_poly = Settings.low_poly
	look = Griffinfly.new()
	look.name = "Look"
	look.wingspan = WINGSPAN
	look.seed_value = _rng.seed
	look.top_level = true
	add_child(look)
	if home.is_finite() == false:
		home = global_position
	_side = 1.0 if _rng.randf() < 0.5 else -1.0
	# (it starts on the wing, somewhere over its halls)
	_ground = _ground_at(global_position)
	global_position.y = _ground + _rng.randf_range(PATROL_HEIGHT.x, PATROL_HEIGHT.y * 0.6)
	_heading = Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	rotation = Vector3.ZERO
	_drive_look(0.0)
	look.settle()


## Where over the marsh (the flooded entrance of the clearing) griffinflies hunt: its middle, at the water (INF: no marsh).
static func marsh_middle(plan: Maze) -> Vector3:
	var look_of := plan.clearing_style
	if look_of == null:
		return Vector3.INF
	var way := look_of.entrance(ClearingStyle.Entrance.MARSH)
	if way.is_empty():
		return Vector3.INF
	var middle: Vector2 = way[0] + way[1] * (look_of.marsh_distance + look_of.marsh_reach * 0.5)
	return Vector3(middle.x, ClearingStyle.MARSH_LEVEL, middle.y)


## How long it has been doing what it is doing, seconds.
func mode_time() -> float:
	return _mode_time


# --- Thinking ---

func _physics_process(delta: float) -> void:
	_cull(delta)
	if puppet:
		_follow_news(delta)
		_drive_look(delta)
		return
	if maze == null:
		return
	_mode_time += delta
	_again -= delta
	_ground_in -= delta
	if _ground_in <= 0.0:
		_ground_in = 0.3
		_ground = _ground_at(global_position)
	_sense(delta)
	_pick_mode(delta)
	var before := global_position
	match mode:
		Mode.PATROL:
			_patrol(delta)
		Mode.PERCH:
			_perched(delta)
		Mode.PREY:
			_hunt_prey(delta)
		Mode.EAT:
			_eat(delta)
		Mode.STALK:
			_stalk(delta)
		Mode.WIND:
			_wind(delta)
		Mode.STRIKE:
			_strike(delta)
		Mode.PULL:
			_pull(delta)
		Mode.FLEE:
			_flee(delta)
		Mode.HOME:
			_go_home(delta)
	velocity = (global_position - before) / delta
	chasing = mode in [Mode.STALK, Mode.WIND, Mode.STRIKE, Mode.PULL] and quarry != null and not (quarry is MazeEnemy)
	_drive_look(delta)


func _enter(next: Mode) -> void:
	_hold = Vector3.INF
	_anchor = global_position
	mode = next
	_mode_time = 0.0


## What it should be doing, from what it knows: it runs from a threat, eats, goes
## after prey or a player, or goes home when it has strayed.
func _pick_mode(delta := 0.0) -> void:
	# (a few times a second is often enough, but in the middle of a strike)
	_pick_in -= delta
	if _pick_in > 0.0 and mode not in [Mode.WIND, Mode.STRIKE, Mode.PULL]:
		return
	_pick_in = 0.1
	if mode in [Mode.WIND, Mode.STRIKE, Mode.PULL]:
		if threat and is_instance_valid(threat) and mode != Mode.STRIKE:
			_enter(Mode.FLEE)
		return
	if threat and is_instance_valid(threat) and not threat.dead:
		if mode != Mode.FLEE:
			_enter(Mode.FLEE)
		return
	if mode == Mode.FLEE:
		_enter(Mode.PATROL)
	if _eating > 0.0:
		if mode != Mode.EAT:
			_enter(Mode.EAT)
		return
	if mode == Mode.EAT:
		_enter(Mode.PATROL)
	if hunting():
		if quarry is MazeEnemy:
			if mode != Mode.PREY:
				_enter(Mode.PREY)
			return
		if _may_buzz(quarry) and _in_reach(quarry.global_position):
			if mode != Mode.STALK:
				_enter(Mode.STALK)
			return
		quarry = null
		_forget = 0.0
	if mode in [Mode.PREY, Mode.STALK]:
		_enter(Mode.HOME if not _in_reach(global_position) else Mode.PATROL)


## Whether it may go at `player` now: not in the clearing (unless it is one of
## the marsh's), not just knocked down.
func _may_buzz(player: Node3D) -> bool:
	if player == null or not huntable(player):
		return false
	if home_radius <= 0.0 and maze.in_clearing(maze.cell_at(player.global_position)):
		return false
	var now := _now()
	return now - float(_knocked.get(player, -100.0)) > KNOCK_GRACE


## Whether `at` is within its leash of home.
func _in_reach(at: Vector3) -> bool:
	if home_radius > 0.0:
		return Vector2(at.x - home.x, at.z - home.z).length() < home_radius * 1.6
	# (from there to home: the one field, its home's, shared and kept)
	var steps := nav.distance(maze.cell_at(at), maze.cell_at(home))
	return steps >= 0 and steps <= leash


# --- Patrol ---

func _patrol(delta: float) -> void:
	if not _goal.is_finite():
		_next_goal()
	if _hover > 0.0:
		_hover -= delta
		_hang(delta, _anchor)
		if _hover <= 0.0:
			_leg = _rng.randf_range(4.0, 10.0)
			if _short:
				# (stopped on the way: on again, as like as not on a new line)
				_short = false
				return
			if perch_chance > 0.0 and _rng.randf() < perch_chance and home_radius <= 0.0 and _find_perch():
				_hover = _rng.randf_range(8.0, 20.0)
				_enter(Mode.PERCH)
				return
			_next_goal()
		return
	var to := _goal - global_position
	if to.length() < 0.4:
		_hover = _rng.randf_range(0.5, 2.4)
		_anchor = global_position
		_gliding = false
		return
	var was := global_position
	_fly_to(_goal, DART_SPEED * (0.7 if _gliding else 1.0), delta)
	# A dart is a few metres at most (but a glide); then it stops dead and hangs a moment.
	_leg -= was.distance_to(global_position)
	if _leg <= 0.0 and not _gliding and to.length() > 3.0:
		_hover = _rng.randf_range(0.3, 1.2)
		_anchor = global_position
		_short = true


## Where it darts to next on patrol: somewhere in its halls (or its patch),
## high or low; often at a right angle, or back the way it came.
func _next_goal() -> void:
	var at: Vector3
	if home_radius > 0.0:
		var spot := Vector2.from_angle(_rng.randf() * TAU) * home_radius * sqrt(_rng.randf())
		at = home + Vector3(spot.x, 0.0, spot.y)
	else:
		var here := maze.cell_at(global_position)
		var cell := nav.wander(here if _in_reach(global_position) else maze.cell_at(home), _rng, 1, 2)
		if nav.distance(cell, maze.cell_at(home)) > territory:
			cell = nav.wander(maze.cell_at(home), _rng, 0, territory)
		at = nav.point(cell) + Vector3(_rng.randf_range(-2.5, 2.5), 0.0, _rng.randf_range(-2.5, 2.5))
	at.y = _ground_at(at) + _rng.randf_range(PATROL_HEIGHT.x, PATROL_HEIGHT.y)
	_goal = at
	_gliding = global_position.distance_to(at) > 7.0 and _rng.randf() < 0.45


## Flies towards `point` (by the halls if the way is not straight), at most `speed`.
func _fly_to(point: Vector3, speed: float, delta: float, turn_rate := 9.0) -> void:
	# (the way there is looked at again a few times a second, not every frame)
	_route_in -= delta
	if _route_in <= 0.0 or point.distance_to(_route_for) > 1.5:
		_route_in = 0.15
		_route_for = point
		_route_aim = point
		if not _straight_to(point):
			var by := nav.waypoint(global_position, point, 2.4)
			_route_aim = Vector3(by.x, point.y, by.z)
	var aim := point if _route_aim.distance_to(_route_for) < 0.01 else _route_aim
	var to := aim - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() > 0.05:
		_face(flat, delta, turn_rate)
	# (it darts: quickly up to speed, and slows only as it comes in)
	var want := to.normalized() * minf(speed, to.length() * 4.0) if to.length() > 0.001 else Vector3.ZERO
	var moving := velocity.move_toward(want, 40.0 * delta)
	global_position += moving * delta
	_keep_off_walls()


## Hangs in the air about `at`: still but for a bob and a sideways slip.
func _hang(delta: float, at: Vector3) -> void:
	var t := _now() + float(get_instance_id() % 97)
	var bob := Vector3(sin(t * 1.7) * 0.06, sin(t * 2.9) * 0.09, cos(t * 1.3) * 0.06)
	var to := at + bob - global_position
	global_position += to.limit_length(2.0 * delta)


## Whether it can fly straight to `point` (the plan has no wall in the way).
func _straight_to(point: Vector3) -> bool:
	if home_radius > 0.0:
		return true
	return nav.line_free(global_position, point, 1.4)


## Keeps it out of the walls (and above the ground) whatever it does.
func _keep_off_walls() -> void:
	if global_position.y < _ground + 0.6:
		global_position.y = _ground + 0.6
	if home_radius > 0.0 or nav.clear_of_walls(global_position, 0.9):
		_last_at = global_position
	elif _last_at != Vector3.ZERO:
		global_position = Vector3(_last_at.x, global_position.y, _last_at.z)


# --- Resting on a wall ---

## A place on the wall nearest it, at its height, to rest on (false: none near).
func _find_perch() -> bool:
	var space := get_world_3d().direct_space_state
	var best: Dictionary = {}
	for k in 4:
		var way := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 4.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(global_position, global_position + way * 8.0, 1, [get_rid()]))
		if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.2:
			continue
		if best.is_empty() or global_position.distance_to(hit["position"]) < global_position.distance_to(best["position"]):
			best = hit
	if best.is_empty():
		return false
	perch_out = (best["normal"] as Vector3).normalized()
	perch_at = (best["position"] as Vector3) + perch_out * 0.09 * WINGSPAN
	return true


func _perched(delta: float) -> void:
	if _mode_time < 1.0:
		# (in to the wall, braking)
		global_position = global_position.lerp(perch_at, 1.0 - exp(-6.0 * delta))
	else:
		global_position = perch_at
	_heading = perch_out
	# Anyone coming near sends it off; it rests a while, then goes on.
	var near := nearest_player(global_position)
	var disturbed := near != null and near.global_position.distance_to(global_position) < 7.0
	if disturbed or hunting() or _mode_time > _hover:
		global_position += perch_out * 0.4
		_goal = global_position + perch_out * 3.0 + Vector3.UP * 0.8
		_hover = 0.0
		_enter(Mode.PATROL)


# --- The small things it eats (Ecology) ---

func _hunt_prey(delta: float) -> void:
	if quarry == null or not is_instance_valid(quarry):
		_enter(Mode.PATROL)
		return
	# (in low over it, legs out; Ecology says when it has it)
	var at := quarry.global_position + Vector3.UP * 0.9
	_fly_to(at, DART_SPEED * 1.1, delta, 12.0)


func _eat(delta: float) -> void:
	_hang(delta, _anchor)


func _flee(delta: float) -> void:
	var away := _away_from(threat.global_position) if threat and is_instance_valid(threat) else home
	away.y = _ground_at(away) + PATROL_HEIGHT.y + 2.0
	_fly_to(away, DART_SPEED, delta)


func _go_home(delta: float) -> void:
	var at := Vector3(home.x, _ground_at(home) + PATROL_HEIGHT.x + 1.5, home.z)
	_fly_to(at, DART_SPEED, delta)
	if Vector2(at.x - global_position.x, at.z - global_position.z).length() < Maze.CELL * 0.6:
		_goal = Vector3.INF
		_enter(Mode.PATROL)


# --- Buzzing players ---

## Where it hangs before it strikes `player`: in front of them on its own side,
## WIND_DISTANCE off, at head height, in a straight line to them.
func _hold_point(player: Node3D) -> Vector3:
	var feet := player.global_position
	var off := Vector3(global_position.x - feet.x, 0.0, global_position.z - feet.z)
	if off.length() < 0.5:
		off = Vector3(_heading.x, 0.0, _heading.z) * -1.0
	var hold := feet + off.normalized() * WIND_DISTANCE
	if home_radius <= 0.0 and not nav.line_free(hold, feet, 0.9):
		# (along the hall instead, up or down it, whichever is nearer it)
		var best := INF
		for step: Vector2i in Maze.STEPS:
			var other := feet + Vector3(step.x, 0.0, step.y) * WIND_DISTANCE
			if nav.line_free(other, feet, 0.9) and other.distance_to(global_position) < best:
				best = other.distance_to(global_position)
				hold = other
	hold.y = _ground_at(hold) + STALK_HEIGHT
	return hold


func _stalk(delta: float) -> void:
	var player := quarry
	# (where to hang, and whether it sees them, a few times a second)
	_hold_in -= delta
	if _hold_in <= 0.0 or not _hold.is_finite():
		_hold_in = 0.2
		_hold = _hold_point(player)
		_in_sight = _sees(player)
	if _in_sight:
		_forget = memory
	var near := global_position.distance_to(_hold) < 1.2
	if near:
		_hang(delta, _hold)
		_face(player.global_position - global_position, delta, 8.0)
	else:
		_fly_to(_hold, CLOSE_SPEED, delta)
	# (it hangs there a moment, loud, before the warning: the first sign of it)
	if near and _mode_time > 0.8 and _again <= 0.0 and _in_sight and _line_to(player):
		_enter(Mode.WIND)


func _wind(delta: float) -> void:
	var player := quarry
	if player == null or not _may_buzz(player):
		_enter(Mode.PATROL)
		return
	# Stops dead, facing them, sinking to the height of their chest; basket out, jaws open.
	var at := Vector3(_anchor.x, _ground + STRIKE_HEIGHT + 0.35, _anchor.z)
	_hang(delta, at)
	_face(player.global_position - global_position, delta, 12.0)
	if _mode_time >= WIND_TIME:
		if not _line_to(player):
			_enter(Mode.STALK)
			return
		# Its line is set: where they will be in a moment (led a little), at their chest.
		var moving: Variant = player.get(&"velocity")
		var v: Vector3 = moving if moving is Vector3 else Vector3.ZERO
		v.y = 0.0
		var reach := global_position.distance_to(player.global_position + Vector3.UP * STRIKE_HEIGHT) / STRIKE_SPEED
		strike_from = global_position
		strike_to = player.global_position + v * minf(reach, 0.6) * 0.5
		strike_to.y = player.global_position.y + STRIKE_HEIGHT
		struck = false
		_enter(Mode.STRIKE)


func _strike(delta: float) -> void:
	var way := strike_to - strike_from
	var length := way.length() + STRIKE_PAST
	var along := way.normalized() if way.length() > 0.01 else _heading
	var travelled := minf(_mode_time * STRIKE_SPEED, length)
	var was := global_position
	var now := strike_from + along * travelled
	if travelled > way.length():
		# (on past them, levelling out)
		now.y = strike_to.y + 0.15 * (travelled - way.length())
	if home_radius <= 0.0 and not nav.clear_of_walls(now, 0.8):
		_enter(Mode.PULL)
		return
	global_position = now
	_face(along, delta, 20.0)
	if not struck:
		_hit_test(was, now, along)
	if travelled >= length:
		_enter(Mode.PULL)


## Whether its basket, going from `was` to `now`, passes through anyone.
func _hit_test(was: Vector3, now: Vector3, along: Vector3) -> void:
	var front := along * 0.25 * WINGSPAN
	for player: Node3D in players():
		if not huntable(player) or not _may_buzz(player):
			continue
		var feet := player.global_position
		var top := LOW if MazeHarpy.is_low(player) else TALL
		for k in 4:
			var p := was.lerp(now, (k + 1) / 4.0) + front + Vector3.DOWN * 0.08
			if MazeHarpy._to_segment(p, feet + Vector3.UP * 0.35, feet + Vector3.UP * top) < HIT_RADIUS:
				_hit(player, along)
				return


## It has hit `player`: knocked down; or, the last of a harrying, thrown down and caught.
func _hit(player: Node3D, along: Vector3) -> void:
	struck = true
	strikes += 1
	last_hit = player.global_position
	look.snap()
	var now := _now()
	_knocked[player] = now
	var mine: Array = _hits.get(player, [])
	mine = mine.filter(func(one: Array) -> bool: return now - float(one[0]) < HARRY_TIME)
	mine.append([now, get_instance_id()])
	_hits[player] = mine
	var by := {}
	for one: Array in mine:
		by[one[1]] = true
	var harried := mine.size() >= HARRY_HITS and by.size() >= 2 and _alone(player) and home_radius <= 0.0 \
			and not maze.in_clearing(maze.cell_at(player.global_position))
	if harried:
		_hits.erase(player)
		if player is Player and is_instance_valid(player):
			(player as Player).ragdoll((along + Vector3.UP * 0.6).normalized() * 45.0)
			get_tree().create_timer(DOWN_TIME).timeout.connect(_taken.bind(player))
		else:
			_catch(player)
	else:
		knock(player, along, home_radius <= 0.0)


## A harried player has come down: stood up, and caught.
func _taken(player: Node3D) -> void:
	if not is_instance_valid(player):
		return
	if player is Player and (player as Player).is_limp:
		(player as Player).recover()
	_catch(player)


## Knocks `player` down (if it is this machine's boy): `hard`, sprawled on his
## front the way he was hit; otherwise a stumble he runs off. Not in the water.
static func knock(player: Node3D, way: Vector3, hard := true) -> void:
	if not (player is Player) or not is_instance_valid(player):
		return
	var boy := player as Player
	if boy.is_limp or boy.state == Player.State.SWIM or boy.is_underwater:
		return
	var flat := Vector3(way.x, 0.0, way.z).normalized()
	boy.velocity.x = flat.x * 4.0
	boy.velocity.z = flat.z * 4.0
	boy.call(&"_take_landing", boy.landing_speeds.y + 0.5 if hard else boy.landing_speeds.z + 0.5)


## Whether nobody else is near `player` (the others in the maze count).
func _alone(player: Node3D) -> bool:
	for other: Node3D in players():
		if other != player and is_instance_valid(other) and other.global_position.distance_to(player.global_position) < ALONE:
			return false
	return true


## Up and away, out of the strike, and round to come again.
func _pull(delta: float) -> void:
	var up := Vector3(_heading.x, 0.0, _heading.z) * maxf(0.0, 1.0 - _mode_time) * 6.0 + Vector3.UP * 3.0
	global_position += up * delta
	_keep_off_walls()
	_face(_heading.rotated(Vector3.UP, _side * 2.4 * delta), delta, 6.0)
	if _mode_time > 1.1:
		_again = _rng.randf_range(AGAIN.x, AGAIN.y)
		_side = -_side
		_enter(Mode.STALK if hunting() else Mode.PATROL)


## Whether it can see `player` (a line through the halls, near enough).
func _sees(player: Node3D) -> bool:
	if player == null:
		return false
	return global_position.distance_to(player.global_position) < sight_range and (home_radius > 0.0 or nav.sees(global_position, player.global_position + Vector3.UP, sight_range))


## Whether nothing is in the way of a strike at `player` from here.
func _line_to(player: Node3D) -> bool:
	if home_radius > 0.0:
		return true
	return nav.line_free(global_position, player.global_position, 0.8)


func _face(toward: Vector3, delta: float, rate: float) -> void:
	toward.y = 0.0
	if toward.length_squared() < 0.0001:
		return
	_heading = _heading.slerp(toward.normalized(), 1.0 - exp(-rate * delta)).normalized() if _heading.dot(toward.normalized()) > -0.99 else toward.normalized()


func _ground_at(at: Vector3) -> float:
	var under := maze.ground_height(at) if maze else 0.0
	# (over the marsh, the water)
	if home_radius > 0.0:
		under = maxf(under, ClearingStyle.MARSH_LEVEL)
	return under


# --- How it looks ---

func _drive_look(_delta: float) -> void:
	if look == null:
		return
	look.global_position = global_position
	look.rotation = Vector3(0.0, atan2(_heading.x, _heading.z), 0.0)
	look.perched = mode == Mode.PERCH
	look.surface = perch_out
	look.effort = 0.0 if (_gliding and mode == Mode.PATROL and _hover <= 0.0) else (1.0 if mode != Mode.EAT else 0.8)
	look.basket = 1.0 if mode in [Mode.WIND, Mode.STRIKE, Mode.PREY] else 0.0
	look.jaws = 1.0 if mode == Mode.WIND or (mode == Mode.STRIKE and not struck) else (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.015) if mode == Mode.EAT else 0.0)
	look.rattle = 1.0 if mode in [Mode.WIND, Mode.STRIKE] else (0.4 if mode == Mode.STALK else 0.0)
	look.aim = quarry.global_position + Vector3.UP * 1.3 if quarry and is_instance_valid(quarry) and mode in [Mode.STALK, Mode.WIND, Mode.PREY] else Vector3.INF


## Out of everyone's way, it is not posed or drawn.
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
			look.settle()


# --- Being run by someone else ---

func yaw() -> float:
	return atan2(_heading.x, _heading.z)


func net_state() -> int:
	return mode


## How many it has hit (so a puppet knows when one lands); and whether this strike has hit.
func net_flag() -> int:
	return (strikes & 0x7f) | (0x80 if struck else 0)


## Where its strike is aimed (or where it hit), or where it rests.
func net_point() -> Vector3:
	if mode in [Mode.STRIKE, Mode.PULL] and struck:
		return last_hit
	if mode in [Mode.WIND, Mode.STRIKE]:
		return strike_to
	if mode == Mode.PERCH:
		return perch_at
	return Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	_heading = Vector3(sin(facing), 0.0, cos(facing))
	struck = flag & 0x80 != 0
	var count := flag & 0x7f
	if _heard_strikes >= 0 and count != _heard_strikes:
		if look:
			look.snap()
		# (a hit: if it was this machine's own boy, he goes down here)
		var mine := local_player()
		if mine and point.is_finite() and mine.global_position.distance_to(point) < 2.5:
			knock(mine, _heading, home_radius <= 0.0)
	_heard_strikes = count
	if mode == Mode.PERCH and point.is_finite():
		perch_at = point
		perch_out = _heading
	elif mode in [Mode.WIND, Mode.STRIKE] and point.is_finite():
		strike_to = point
	chasing = mode in [Mode.STALK, Mode.WIND, Mode.STRIKE, Mode.PULL]


func _follow_news(delta: float) -> void:
	if not _heard:
		return
	_heard_at += _heard_moving * delta
	global_position = global_position.lerp(_heard_at, 1.0 - exp(-10.0 * delta))
	if global_position.distance_to(_heard_at) > 6.0:
		global_position = _heard_at


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	_heading = Vector3(sin(facing), 0.0, cos(facing))
	if look:
		_drive_look(0.0)
		look.settle()


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 0


## The time of the game, seconds (its physics steps: the same however fast it runs).
static func _now() -> float:
	return Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)

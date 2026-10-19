class_name MazeEnemy
extends CharacterBody3D
## What the things that hunt in the maze (Apophis, Mummy) have in common: who
## they are after and how they find them, the way through the maze (MazeNav),
## and being run by another machine (`puppet`).
##
## SENSES. A few times a second each looks for players: one is noticed if they
## are within `hear_range` (round corners and all), or within `sight_range` in
## a straight line down the passages (`MazeNav.sees`). The nearest noticed, by
## the way round the walls, is its `quarry`, and it remembers where they are
## for `memory` seconds after it last noticed them; all that time it knows
## where they are, and goes after them by the passages. When it forgets them it
## goes on to where they were last, and then wanders (`_wander_goal`).
## `alert_range`: when it notices someone, others of its kind (`pack`) that
## near take up the hunt too.
##
## PLAYERS are `targets` if that is set, or else everything in the group
## `maze_players`. A player is passed over while `escaped` or `is_limp` is
## true on it, while it is outside the maze, and for `spare_time` seconds after
## it has been caught. `caught(player)` is all that catching does: what it
## means is for the game to say.
##
## PUPPET. With `puppet` set it does no thinking, and only follows what it
## hears (`hear`, or `from_bytes` with what `state_bytes` made on the machine
## that runs it), smoothly, as RemotePlayer does for players.
##
## THE OTHERS (Ecology, when the world has one): a meat-eater that is
## `hunger`ed and has nobody to go after goes after a smaller creature it sees
## (its `quarry`, as a player would be), and catching it kills it (`die`): it
## eats there a while. One a bigger meat-eater is after, or that is hungry near
## it, runs from it (`threat`). Out of everyone's sight it goes on its way
## (`roam_unseen`); killed, it is brought back in time where it began (`revive`).
##
## CLIMBING (`climbs`; the user, 2026-10-18: "more creatures should be able to climb
## things"). One that can goes up after a player who has got up out of reach of the
## floor, onto a ledge, a terrace or a concrete bridge (HighWays), each kind in its own
## way: SCRAMBLE (clinging to the face, as a rat or an ant goes up a wall), CLAMBER
## (hand over hand, as a person climbs), LEAP (a crouch and a bound, `leap_most` high,
## the rest clawed up) or FLOAT. Along the top to them, and down again when they get
## down (HighClimb). Each kind that climbs calls `_ways_up` first in its own thinking
## and does nothing else while it gives true, and poses itself by `aloft`; as a puppet
## it calls `_follow_aloft`. Only the awake and hunting ever look.

signal caught(player: Node3D)
## It has noticed someone it was not after.
signal spotted(player: Node3D)

## Bytes in `state_bytes`.
const STATE_SIZE := 29
## How high a dead one is said to be, in `state_bytes`.
const DEAD_DEPTH := -9999.0
## The bodies of hunters: layer 4 run here, this layer as puppets (run by
## another machine), so that players are stopped by both but a hunter is never
## stopped by a puppet (as a host and its puppet, side by side in a test, are not).
const PUPPET_LAYER := 16

## The maze it is in. Set before it goes into the scene, or call `set_maze`.
var maze: Maze:
	set(value):
		maze = value
		nav = MazeNav.new(value, keep_out_of_clearing) if value else null
var nav: MazeNav
## Run by someone else: no thinking, only following `hear`.
var puppet := false:
	set(value):
		puppet = value
		_puppet_changed()
## Who it may go after. Empty: the group `maze_players`.
var targets: Array = []
## Who it is after now (null: nobody).
var quarry: Node3D
## Whether it is after someone (the boy keeps an eye on anything in the group
## `pursuers` with this true).
var chasing := false

@export_group("Senses")
@export var sight_range := 44.0
@export var hear_range := 9.0
@export var memory := 12.0
@export var alert_range := 0.0
## The group that hears its alert (and that keeps apart from each other).
@export var pack := &"maze_enemies"
## Seconds a caught player is let alone.
@export var spare_time := 3.0
## Wanders from section to section (a special case). Otherwise it wanders only in
## the section it was put in: it may chase someone out of it, then goes back
## (MazeNav.keep_in_ring); and its zone sleeps while nobody is in it (World.zone_of).
@export var crosses_zones := false
## Kept out of the clearing (set before `maze`).
@export var keep_out_of_clearing := true
## How often it looks about, seconds.
@export var look_every := 0.2
## Whether fire keeps it off (FireWard): nobody within a lit torch's or a
## campfire's reach of the flame can be gone after. (The swarms: Beetles,
## MazeImpSwarm, MazeFrogSwarm.)
@export var fears_fire := false

## How it gets up after someone (see CLIMBING above): not at all, clinging to the face,
## climbing as a person does, in a bound, or floating up.
enum Climbs { NO, SCRAMBLE, CLAMBER, LEAP, FLOAT }
@export_group("Climbing")
@export var climbs := Climbs.NO
## How fast it goes up a face, m/s.
@export var climb_speed := 2.0
## The highest it leaps in one bound, m (LEAP).
@export var leap_most := 6.0
@export_group("")
## What it is doing up off the floor (HighClimb.Aloft: 0, on the floor as its own kind has it).
var aloft := 0
var _high: HighClimb

## The world's own life (Ecology): how hungry it is (0 fed, 1 starving), whether
## it is dead (gone until the world brings it back), and what it is running from.
var hunger := 0.0
var dead := false
var threat: MazeEnemy

var _forget := 0.0
var _last_seen := Vector3.INF
var _eating := 0.0
var _ecology_in := 0.0
var _alive_layers := Vector2i.ZERO
var _look_in := 0.0
var _spared := {}
var _wander_goal := Vector2i(-1, -1)
var _rng := RandomNumberGenerator.new()
# What it last heard, as a puppet.
var _heard := false
var _heard_at := Vector3.ZERO
var _heard_moving := Vector3.ZERO
var _heard_yaw := 0.0
var _heard_state := 0
var _heard_extra := Vector3.ZERO
var _heard_flag := 0
var _heard_aloft := 0


func _enter_tree() -> void:
	add_to_group(pack)
	add_to_group(&"maze_enemies")


## Seeds its own choices (where it wanders), so that two runs of the same game go the same way.
func seed_choices(value: int) -> void:
	_rng.seed = value


func set_maze(plan: Maze) -> void:
	maze = plan


# --- Players ---

func players() -> Array:
	if not targets.is_empty():
		return targets
	return get_tree().get_nodes_in_group(&"maze_players") if is_inside_tree() else []


## Whether a player can be gone after now.
func huntable(player: Node3D) -> bool:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return false
	if player is MazeEnemy and (player as MazeEnemy).dead:
		return false
	if player.get(&"escaped") == true or player.get(&"is_limp") == true:
		return false
	if _spared.has(player) and _spared[player] > 0.0:
		return false
	if fears_fire and FireWard.near(get_tree(), player.global_position):
		return false
	if _shy_of_lanterns() and MazeWoodsman.lit(get_tree(), player.global_position):
		return false
	return maze == null or maze.inside(maze.cell_at(player.global_position))


## Whether a woodsman's lantern keeps it back (MazeWoodsman.lit: nobody in its light
## can be gone after): whatever goes about the maze short of the biggest (Ecology's
## sizes under 4), and the beast; not the woodsman himself, nor the giants, swarms
## and flocks that take no part in Ecology. (Added with the woodsman, 2026-10-18.)
func _shy_of_lanterns() -> bool:
	if _lantern_shy < 0:
		var kind := Ecology.kind_of(self)
		_lantern_shy = 1 if kind == "MazeBeast" or (kind != "MazeWoodsman" and Ecology.KINDS.has(kind) and Ecology.bulk(self) < 4) else 0
	return _lantern_shy == 1


var _lantern_shy := -1


## Says that it has caught `player`, and lets them alone for `spare_time`.
func _catch(player: Node3D) -> void:
	_spared[player] = spare_time
	caught.emit(player)
	if quarry == player:
		quarry = null
		_forget = 0.0
		_last_seen = Vector3.INF


## Looks about (every `look_every` seconds) and settles who it is after.
func _sense(delta: float) -> void:
	# (untyped: a player who has left the room may already be freed)
	for player: Variant in _spared.keys():
		if not is_instance_valid(player):
			_spared.erase(player)
			continue
		_spared[player] -= delta
		if _spared[player] <= 0.0:
			_spared.erase(player)
	_forget -= delta
	if quarry and not huntable(quarry):
		quarry = null
	_ecology(delta)
	if quarry and _forget > 0.0:
		_last_seen = quarry.global_position
	_look_in -= delta
	if _look_in > 0.0:
		return
	_look_in = look_every
	var eye := global_position + Vector3.UP
	var here := maze.cell_at(global_position)
	var best: Node3D = null
	var best_steps := 1 << 30
	for player: Node3D in players():
		if not huntable(player):
			continue
		var at := player.global_position
		var noticed := eye.distance_to(at) < hear_range or nav.sees(eye, at + Vector3.UP, sight_range)
		if not noticed and climbs != Climbs.NO:
			noticed = _sees_up(eye, at, player)
		if not noticed:
			continue
		var steps := nav.distance(here, maze.cell_at(at))
		if steps < 0:
			steps = 9999
		# (it keeps to the one it is after unless another is a good deal nearer)
		if player == quarry:
			steps -= 2
		if steps < best_steps:
			best_steps = steps
			best = player
	if best:
		notice(best)
	elif _forget <= 0.0:
		quarry = null


## It notices `player` (as seeing or hearing them does): it is after them, and
## its pack near it is told. (For the game too: a noise, a trap sprung.)
func notice(player: Node3D) -> void:
	if not huntable(player):
		return
	if player != quarry or _forget <= 0.0:
		spotted.emit(player)
		_alert_pack(player)
	quarry = player
	_forget = memory
	_last_seen = player.global_position


## Others of its pack near enough take up the hunt for `player`.
func _alert_pack(player: Node3D) -> void:
	if alert_range <= 0.0:
		return
	for other: Node in get_tree().get_nodes_in_group(pack):
		if other != self and other is MazeEnemy and not other.puppet and (other as Node3D).global_position.distance_to(global_position) < alert_range:
			(other as MazeEnemy).alerted(player, global_position)


## Told by one of its pack that `player` is about.
func alerted(player: Node3D, _from: Vector3) -> void:
	if not huntable(player):
		return
	if quarry == null or _forget <= 0.0:
		quarry = player
		_forget = memory * 0.75
		_last_seen = player.global_position


## Whether it is after someone it still remembers.
func hunting() -> bool:
	return quarry != null and _forget > 0.0


## Where it is making for: away from what it runs from, or nowhere while it
## eats; the quarry, or where they were last, or somewhere to wander to.
func goal() -> Vector3:
	if threat and is_instance_valid(threat) and not threat.dead:
		return _away_from(threat.global_position)
	if _eating > 0.0:
		return global_position
	if hunting():
		return quarry.global_position
	var here := maze.cell_at(global_position)
	if _last_seen.is_finite():
		if Vector2(_last_seen.x - global_position.x, _last_seen.z - global_position.z).length() < 2.0 or nav.distance(here, maze.cell_at(_last_seen)) <= 0:
			_last_seen = Vector3.INF
		else:
			return _last_seen
	if _wander_goal.x < 0 or here == _wander_goal or nav.distance(here, _wander_goal) < 0:
		_wander_goal = nav.wander(here, _rng)
	return nav.point(_wander_goal)


## The way to go from where it is to `goal()`, flat, keeping `radius` off the walls.
func way(radius: float) -> Vector3:
	var to := nav.waypoint(global_position, goal(), MazeNav.clearance_for(radius)) - global_position
	to.y = 0.0
	return to


## The middle of a passage next to it (or the one past that) furthest from `danger`.
func _away_from(danger: Vector3) -> Vector3:
	var here := maze.cell_at(global_position)
	var best := global_position + (global_position - danger).normalized() * 4.0
	var far := -1.0
	for step: Vector2i in Maze.STEPS:
		if maze.blocked(here, step) or not nav.allowed(here + step):
			continue
		var to := here + step
		if not maze.blocked(to, step) and nav.allowed(to + step):
			to += step
		var at := nav.point(to)
		if at.distance_to(danger) > far:
			far = at.distance_to(danger)
			best = at
	return best


# --- Climbing (see CLIMBING above) ---

## First in its own thinking, for a kind that climbs: whether it is going up after
## someone, up there, or coming down (or on its way to the foot of the way up), in
## which case it does nothing else this step. `radius` is its body's, `speed` how
## fast it runs.
func _ways_up(delta: float, radius: float, speed: float) -> bool:
	if climbs == Climbs.NO or maze == null or puppet or dead:
		return false
	if _high == null:
		if not hunting():
			return false
		_high = HighClimb.new(self)
	var busy := _high.step(delta, radius, speed)
	aloft = _high.aloft if busy else 0
	return busy


## For one that climbs: whether it sees someone up on a ledge (MazeNav.sees counts
## the first level of ledge as the wall: a line to someone standing on one ends in
## it). From the floor, a line to the air a few metres out from them, over the hall;
## up there itself, along the ledge to the one it is after.
func _sees_up(eye: Vector3, at: Vector3, player: Node3D) -> bool:
	if at.y - maze.ground_height(at) < HighWays.UP:
		return false
	var flat := Vector3(eye.x - at.x, 0.0, eye.z - at.z)
	if flat.length() > sight_range:
		return false
	if is_aloft():
		return player == quarry and absf(at.y - global_position.y) < 2.0 and flat.length() < sight_range * 0.6
	if flat.length() < 3.5:
		return true
	var out := at + flat.normalized() * 3.0
	return nav.sees(eye, Vector3(out.x, at.y + 1.0, out.z), sight_range)


## Whether `_ways_up` has it now (going to the foot of a way up, on it, up there, or coming down).
func climbing_now() -> bool:
	return _high != null and _high.busy()


## Which way it faces while `_ways_up` has it (radians about Y).
func aloft_yaw() -> float:
	return _high.facing if _high else yaw()


## The way out from the face it is going up or down (or was last), for its pose.
func aloft_out() -> Vector3:
	if _high:
		return _high.out
	# (a puppet: it faces the face it is on)
	return -Vector3(sin(yaw()), 0.0, cos(yaw()))


## Up off the floor (going up, on a ledge, leaping, coming down): not on the floor as its own kind has it.
func is_aloft() -> bool:
	return aloft != HighClimb.Aloft.NONE


## Up there, within reach of who it is after: each kind may strike as it does; a catch.
func _strike_aloft(player: Node3D) -> void:
	_catch(player)


## A body's turn for a pose while it climbs (to go after its yaw): clinging to the face,
## nose up it (`upright` false: on all fours) or leaning into it (a person, upright);
## crouched or stretched in a leap. Unturned on a ledge or the floor.
func aloft_tilt(upright := false) -> Basis:
	match aloft:
		HighClimb.Aloft.CLIMB, HighClimb.Aloft.DOWN:
			# (about its right side: less than nothing tips its nose up, more its head forward)
			if upright:
				return Basis(Vector3.RIGHT, 0.15)
			return Basis(Vector3.RIGHT, -PI * 0.5 if aloft == HighClimb.Aloft.CLIMB else PI * 0.5)
		HighClimb.Aloft.LEAP:
			return Basis(Vector3.RIGHT, -0.5 if not upright else 0.25)
		HighClimb.Aloft.DROP:
			return Basis(Vector3.RIGHT, 0.45)
	return Basis.IDENTITY


## As a puppet, up off the floor: put where it is heard to be (gravity has no say).
## Whether it is (each kind calls it first in following its news).
func _follow_aloft(delta: float) -> bool:
	if aloft == HighClimb.Aloft.NONE or not _heard:
		return false
	_heard_at += _heard_moving * delta
	global_position = global_position.lerp(_heard_at, 1.0 - exp(-14.0 * delta))
	velocity = _heard_moving
	return true


# --- The others (Ecology) ---

## Looks out for what would eat it, and, hungry, for what it could eat; and
## kills what it is after when it catches it.
func _ecology(delta: float) -> void:
	var world := Ecology.current
	if world == null or puppet or dead:
		return
	_eating -= delta
	_ecology_in -= delta
	if _ecology_in <= 0.0:
		_ecology_in = Ecology.LOOK_EVERY
		threat = world.threat_to(self)
		var after_player := hunting() and not (quarry is MazeEnemy)
		if threat:
			# (running for its life, it is after nobody)
			if quarry is MazeEnemy:
				quarry = null
		elif not after_player and _eating <= 0.0 and world.hungry(self):
			var prey := world.prey_for(self)
			if prey:
				if prey != quarry:
					_alert_pack(prey)
				quarry = prey
				_forget = memory
				_last_seen = prey.global_position
	if quarry is MazeEnemy and hunting():
		var prey := quarry as MazeEnemy
		var apart := Vector2(prey.global_position.x - global_position.x, prey.global_position.z - global_position.z).length()
		if apart < world.reach(self) + world.reach(prey) * 0.5 and absf(prey.global_position.y - global_position.y) < 2.5:
			world.kill(prey, self)


## Fed on what it has killed: eats there for `seconds`.
func ate(seconds: float) -> void:
	hunger = 0.0
	_eating = seconds
	quarry = null
	_forget = 0.0
	_last_seen = Vector3.INF
	chasing = false


## Killed (by another, Ecology): gone until the world brings it back. It stays
## in the list of enemies, hidden and still, so that what is sent between
## machines keeps its order.
func die() -> void:
	if dead:
		return
	dead = true
	_alive_layers = Vector2i(collision_layer, collision_mask)
	collision_layer = 0
	collision_mask = 0
	visible = false
	quarry = null
	threat = null
	chasing = false
	velocity = Vector3.ZERO
	process_mode = Node.PROCESS_MODE_DISABLED
	if _high:
		_high = null
	aloft = 0


## Brought back at `at` (its den, out of everyone's sight), as hungry as `hungry`.
func revive(at: Vector3, facing: float, hungry := 0.3) -> void:
	if not dead:
		return
	dead = false
	collision_layer = _alive_layers.x
	collision_mask = _alive_layers.y
	visible = true
	hunger = hungry
	_eating = 0.0
	_forget = 0.0
	_last_seen = Vector3.INF
	_wander_goal = Vector2i(-1, -1)
	process_mode = Node.PROCESS_MODE_INHERIT
	_put(at, facing)


## Out of everyone's sight (asleep): goes on its way about the maze by the
## passages, at most `step` metres at once: from cell to open cell, on the way it
## was going where it can, in its own section (MazeNav.in_own_ring). Only its
## basic needs are kept up out of sight, so no way is found to anywhere (a whole
## maze's search for each of hundreds of sleepers was most of a frame).
func roam_unseen(step: float) -> void:
	if maze == null or puppet or dead:
		return
	# (asleep, nothing climbs: down on the floor)
	if _high and _high.busy():
		_high.land_now()
		aloft = 0
	var here := maze.cell_at(global_position)
	if _roam_to == Vector2i(-1, -1) or here == _roam_to or not nav.allowed(_roam_to):
		_roam_to = _next_roam_cell(here)
	var to := maze.world(_roam_to) - global_position
	to.y = 0.0
	if to.length() > 0.05:
		global_position += to.limit_length(step)


var _roam_to := Vector2i(-1, -1)
var _roam_way := Vector2i.ZERO


func _next_roam_cell(here: Vector2i) -> Vector2i:
	var open: Array[Vector2i] = []
	for step: Vector2i in Maze.STEPS:
		var next := here + step
		if nav.allowed(next) and nav.in_own_ring(next) and not maze.blocked(here, step):
			open.append(step)
	if open.is_empty():
		return here
	# (straight on mostly; back the way it came only at a dead end)
	if open.has(_roam_way) and _rng.randf() < 0.7:
		return here + _roam_way
	if open.size() > 1:
		open.erase(-_roam_way)
	_roam_way = open[_rng.randi_range(0, open.size() - 1)]
	return here + _roam_way


## A little push away from others of its pack that it is right up against.
func _apart(radius: float) -> Vector3:
	var push := Vector3.ZERO
	for other: Node in get_tree().get_nodes_in_group(pack):
		if other == self or not (other is Node3D):
			continue
		var out := global_position - (other as Node3D).global_position
		out.y = 0.0
		var near := radius * 2.2
		if out.length() < near and out.length() > 0.001:
			push += out.normalized() * (near - out.length()) / near
	return push


# --- Being run by someone else ---

## The way it faces, radians about Y (0 faces +Z). Each kind says.
func yaw() -> float:
	return 0.0


## What it is doing, as a small number for the network, and anything more (a
## number and a point near it) that goes with that. Each kind says.
func net_state() -> int:
	return 0


func net_flag() -> int:
	return 0


func net_point() -> Vector3:
	return Vector3.ZERO


## As a puppet: the latest news of it.
func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	var first := not _heard
	_heard = true
	if aloft != _heard_aloft and _heard_aloft == HighClimb.Aloft.NONE:
		# (down on the floor again: from where it is heard to be)
		global_position = at
	aloft = _heard_aloft
	_heard_at = at
	_heard_moving = moving
	_heard_yaw = facing
	_heard_flag = flag
	_heard_extra = point
	if first or state != _heard_state:
		var was := _heard_state
		_heard_state = state
		_heard_changed(was, state, first)
	if first or global_position.distance_to(at) > 6.0:
		_put(at, facing)


## Each kind: what it does when its state changes (as a puppet).
func _heard_changed(_was: int, _now: int, _first: bool) -> void:
	pass


## Each kind: put it straight somewhere (as a puppet, when it is far off).
func _put(at: Vector3, _facing: float) -> void:
	global_position = at


## Follows what it heard: carries on as it was going and closes the gap.
func _follow(delta: float) -> void:
	if not _heard or _follow_aloft(delta):
		return
	_heard_at += _heard_moving * delta
	var wish := _heard_moving + (_heard_at - global_position) * 6.0
	velocity.x = wish.x
	velocity.z = wish.z
	if is_on_floor():
		velocity.y = minf(wish.y, 0.0)
	else:
		velocity.y = maxf(velocity.y - 24.0 * delta, wish.y)
	move_and_slide()
	if global_position.distance_to(_heard_at) > 2.5:
		global_position = _heard_at


## Its state, in STATE_SIZE bytes: where it is (3 floats), how fast it is
## going (3 halves), which way it faces, what it is doing, a flag, a point
## near it (3 halves, from where it is), and what it is doing up off the floor
## (`aloft`: climbing, leaping, on a ledge, coming down).
func state_bytes() -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(STATE_SIZE)
	var at := global_position
	data.encode_float(0, at.x)
	# (dead, it is sent far under the ground: DEAD_DEPTH)
	data.encode_float(4, DEAD_DEPTH if dead else at.y)
	data.encode_float(8, at.z)
	data.encode_half(12, velocity.x)
	data.encode_half(14, velocity.y)
	data.encode_half(16, velocity.z)
	data.encode_u16(18, int(fposmod(yaw(), TAU) / TAU * 65535.0))
	data[20] = net_state()
	data[21] = net_flag() & 0xff
	var point := net_point()
	if not point.is_finite():
		point = Vector3(0.0, -1000.0, 0.0)
	point -= at
	data.encode_half(22, clampf(point.x, -60000.0, 60000.0))
	data.encode_half(24, clampf(point.y, -60000.0, 60000.0))
	data.encode_half(26, clampf(point.z, -60000.0, 60000.0))
	data[28] = aloft
	return data


## Hears a `state_bytes` (from `offset` in `data`).
func from_bytes(data: PackedByteArray, offset := 0) -> void:
	if data.size() < offset + STATE_SIZE:
		return
	var at := Vector3(data.decode_float(offset), data.decode_float(offset + 4), data.decode_float(offset + 8))
	if at.y <= DEAD_DEPTH + 1.0:
		die()
		return
	var facing_now := data.decode_u16(offset + 18) / 65535.0 * TAU
	if dead:
		revive(at, facing_now)
	var moving := Vector3(data.decode_half(offset + 12), data.decode_half(offset + 14), data.decode_half(offset + 16))
	var facing := data.decode_u16(offset + 18) / 65535.0 * TAU
	var point := Vector3(data.decode_half(offset + 22), data.decode_half(offset + 24), data.decode_half(offset + 26))
	point = Vector3.INF if point.y < -900.0 else at + point
	_heard_aloft = data[offset + 28]
	hear(at, moving, facing, data[offset + 20], data[offset + 21], point)


## The nearest player to a point that is in the group `maze_players`, or among `targets`.
func nearest_player(at: Vector3) -> Node3D:
	var best: Node3D = null
	var far := INF
	for player: Node3D in players():
		if not is_instance_valid(player) or not player.is_inside_tree():
			continue
		var d := player.global_position.distance_to(at)
		if d < far:
			far = d
			best = player
	return best


## The player this machine plays (a Player), if there is one among the players.
func local_player() -> Player:
	for player: Node in players():
		if player is Player and is_instance_valid(player) and not player.is_in_group(&"runners"):
			return player
	return null


## Each kind: anything that changes with being a puppet or not.
func _puppet_changed() -> void:
	pass

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

signal caught(player: Node3D)
## It has noticed someone it was not after.
signal spotted(player: Node3D)

## Bytes in `state_bytes`.
const STATE_SIZE := 28
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
	return maze == null or maze.inside(maze.cell_at(player.global_position))


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
	if not _heard:
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
## going (3 halves), which way it faces, what it is doing, a flag, and a point
## near it (3 halves, from where it is).
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

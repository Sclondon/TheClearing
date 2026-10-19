class_name MazeAnts
extends MazeEnemy
## A colony of giant ants in the maze, each the size of a dog: their nest mound
## in a dead end, and a trail of trodden ground from it out along the passages
## to where they forage, with workers going out and coming home along it in
## lines, and soldiers with great heads round the nest. They let alone whoever
## keeps off the trail and away from the nest; tread on it near them, walk into
## them, or come up to the nest, and the alarm runs through them and they come
## at you at a run, and a few on you at once for a moment is a catch.
##
## What they look like and how they move is AntColony (creatures/giant_ant/, a
## component that knows nothing of the maze); this is what they think. This
## node is the colony as the game sees it: it stands at the nest (where it is
## put to sleep when everyone is far off), what it is doing (`mode`), and who
## it is after (`quarry`).
##
## - CALM. Put in a cell (a dead end, best), it digs its nest against the wall
##   at the end of it and lays its trail from there by the passages to a cell
##   `trail_cells` steps away (one with a carcass in it, if there is one in
##   reach: the flies' carcasses). Whoever comes within `nest_guard` of the
##   nest, or within `bump_range` of an ant, or onto the trail (`trail_near`
##   of its middle) with an ant within `trail_watch` of them, raises the alarm.
##   Walking along beside the trail, a body's length off it, is safe; so is
##   crossing it in a gap in their lines.
## - ALARM. The alarm runs out through the ants near (the clicking, their
##   feelers up, a moment where they stand), those in the nest pour out, and
##   they come at whoever it was at a run (AntColony.run_speed: faster than a
##   run, slower than a sprint). Those that reach them seize them; a few
##   (AntColony.catch_count) on at once for a moment (AntColony.catch_time) is
##   a catch. A sprint tears them off and gets away, and so does a jump. Up on a
##   ledge, a terrace or a concrete bridge is not safe: they stream up the wall's
##   face under it, nose up, and come along the top (HighWays: the way up from the
##   foot of the wall, AntColony.climb; the user, 2026-10-18: "more creatures should
##   be able to climb things"); a vine, a rope bridge or a wall top still is. When none has got near them
##   for `give_up_after`, or they are further than `chase_range` from the nest
##   and the trail, or they are caught, the ants calm and go back to their ways.
##
## THE OTHERS (Ecology). They take no part as a kind (the colony is one node,
## its ants many), but they hunt: a creature that eats, no bigger than a dog
## (Ecology.bulk 2 or less), that comes on their trail or nest, or near an ant,
## raises the alarm the same way; enough of them on it for long enough
## (`prey_hold`) kills it (Ecology.kill), and they carry its carcass home and
## down into the nest. Any carcass lying near the trail they haul home too,
## one at a time (each machine its own: it is only to be seen). Something
## that hunts them may take one (`lose_ant`).
##
## As a puppet (online, not the host) it follows the host's news: what it is
## doing (`net_state`), the point they go for (`net_point`: the feet of who it
## is after), and how many alarms there have been (`net_flag`), so that each
## alarm is raised here too. The ants are run here, on their own, after that
## point (or the player standing at it, if one does), so they look the same
## without each being sent. The nest and the trail come from the cell it was put
## in and its seed, the same on every machine, and so do the ants.

enum Mode { CALM, ALARM }

## How many workers and soldiers, and how many on a phone (`Settings.low_poly`, or the grass at its lowest).
@export var worker_count := 22
@export var soldier_count := 5
@export var low_workers := 13
@export var low_soldiers := 3
## How many steps by the passages from the nest the trail runs, at least and at most.
@export var trail_cells := Vector2i(4, 7)
## Raising the alarm: how near the nest, how near an ant, and how near the
## trail's middle with an ant how near, metres.
@export var nest_guard := 7.0
@export var bump_range := 1.7
@export var trail_near := 1.0
@export var trail_watch := 9.0
## Giving up: how far from the nest and the trail they will follow, and how
## long with none of them getting near (within `near_enough`).
@export var chase_range := 30.0
@export var give_up_after := 6.0
@export var near_enough := 3.5
## How many on prey (no bigger than a hen, and bigger) kill it, and how long they must hold it.
@export var prey_small := 2
@export var prey_big := 4
@export var prey_hold := 1.5
@export var sound := true

var mode := Mode.CALM
## (tests) print how its hold on prey goes.
var trace_prey := false
## The ants (made the frame after it goes in).
var colony: AntColony
## How many alarms it has raised (sent, so that guests raise them too).
var alarms := 0

var _nest := Vector3.ZERO
var _colony_seed := 0
var _far_off := 0.0
var _hold := 0.0
var _prey_in := 0.0
var _carry_in := 2.0
var _alarm_point := Vector3.INF
# The way each ant is told to go, by the cell it is in, for the goal's cell (see `_guide`).
var _ways := {}
var _ways_for := Vector2i(-99999, -99999)


func _init() -> void:
	sight_range = 0.0
	hear_range = 0.0
	memory = 6.0
	pack = &"ants"
	look_every = 0.2
	# (each ant goes up the face by itself: AntColony.climb, not MazeEnemy's own climbing)
	climbs = Climbs.SCRAMBLE


func seed_choices(value: int) -> void:
	super(value)
	_colony_seed = value


func _ready() -> void:
	add_to_group(&"pursuers")
	# Nothing bumps into it: its ants are many and small.
	collision_layer = 0
	collision_mask = 0
	_nest = global_position
	_make_colony.call_deferred()


## Digs the nest and lays the trail, and puts the ants on it.
func _make_colony() -> void:
	if not is_inside_tree() or colony or maze == null:
		return
	var choose := RandomNumberGenerator.new()
	choose.seed = _colony_seed
	var home := maze.cell_at(global_position)
	_nest = _nest_spot(home, choose)
	var points := _trail_points(home, choose)
	colony = AntColony.new()
	colony.name = "Colony"
	var low := Settings.low_poly or Grass.quality == Grass.Quality.LOW
	colony.workers = low_workers if low else worker_count
	colony.soldiers = low_soldiers if low else soldier_count
	colony.low_poly = Settings.low_poly
	colony.colony_seed = _colony_seed
	colony.sound = sound
	colony.guide = _guide
	colony.ground = _ground
	colony.forbid = _forbid
	colony.climb = _climb_way
	colony.target_radius = 0.35
	colony.set_trail(points)
	colony.top_level = true
	add_child(colony)
	colony.global_transform = Transform3D.IDENTITY
	colony.overwhelmed.connect(_on_overwhelmed)
	colony.carried_home.connect(_on_carried_home)
	if not puppet:
		global_position = _nest


## Whether it has made its nest and trail (the frame after it goes in).
func ready_to_go() -> bool:
	return colony != null


# Against the wall at the end of a dead end (or the middle of any other cell), a few metres out.
func _nest_spot(cell: Vector2i, choose: RandomNumberGenerator) -> Vector3:
	var middle := nav.point(cell)
	var back := Vector2i.ZERO
	if nav.dead_end(cell):
		for step: Vector2i in Maze.STEPS:
			if not maze.blocked(cell, step):
				back = -step
	var at := middle
	if back != Vector2i.ZERO:
		var way := Vector3(back.x, 0.0, back.y)
		for far: float in [3.5, 2.5, 1.5, 0.0]:
			var spot := middle + way * far + Vector3(-way.z, 0.0, way.x) * choose.randf_range(-1.5, 1.5)
			if nav.clear_of_walls(spot, AntColony.MOUND_RADIUS + 0.4):
				at = spot
				break
	at.y = maze.ground_height(at)
	return at


# From the nest by the passages to where they forage, weaving across the halls.
func _trail_points(home: Vector2i, choose: RandomNumberGenerator) -> PackedVector3Array:
	var end := _forage_cell(home, choose)
	var cells := nav.path(home, end)
	var points := PackedVector3Array([_nest])
	for i in range(1, cells.size()):
		var at := nav.point(cells[i])
		var came := cells[i] - cells[i - 1]
		var side := Vector3(-came.y, 0.0, came.x)
		var shift := choose.randf_range(-2.2, 2.2)
		for k in 4:
			if nav.clear_of_walls(at + side * shift, 2.0):
				break
			shift *= 0.5
		at += side * shift
		at.y = maze.ground_height(at)
		points.append(at)
	if points.size() < 2:
		var ahead := _nest + Vector3(0.0, 0.0, 8.0)
		ahead.y = maze.ground_height(ahead)
		points.append(ahead)
	return points


# A cell `trail_cells` steps off by the passages; one with a carcass in it if any is in reach.
func _forage_cell(home: Vector2i, choose: RandomNumberGenerator) -> Vector2i:
	var depth := {home: 0}
	var queue: Array[Vector2i] = [home]
	var choices: Array[Vector2i] = []
	var furthest := home
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		var d: int = depth[cell]
		if d >= trail_cells.x:
			choices.append(cell)
		if d > depth[furthest]:
			furthest = cell
		if d >= trail_cells.y:
			continue
		for step: Vector2i in Maze.STEPS:
			var next := cell + step
			if not nav.allowed(next) or depth.has(next) or maze.blocked(cell, step):
				continue
			depth[next] = d + 1
			queue.append(next)
	if choices.is_empty():
		return furthest
	for carcass: Node3D in _carcasses():
		var there := maze.cell_at(carcass.global_position)
		if choices.has(there):
			return there
	return choices[choose.randi_range(0, choices.size() - 1)]


# The carcasses lying about (the flies'), not taken already.
func _carcasses() -> Array[Node3D]:
	var found: Array[Node3D] = []
	if not is_inside_tree():
		return found
	for node: Node in get_tree().get_nodes_in_group(&"fly_carrion"):
		if node is Node3D and not (node is MazeEnemy) and node.is_inside_tree() and (node as Node3D).visible and not node.has_meta(&"ant_taken"):
			found.append(node as Node3D)
	return found


func _forbid(point: Vector3) -> bool:
	if not maze.inside(maze.cell_at(point)):
		return true
	if point.y - maze.ground_height(point) > 1.0:
		# Up off the floor: along the tops at its height, and off the edge only down to
		# a target under it (or with none: calm, home); never into a wall.
		var ways := _high_ways(point)
		if ways.in_wall(point):
			return true
		if ways.level_at(point, point.y, 0.6, 0.25) >= 0:
			return false
		var after := colony.target if colony else Vector3.INF
		return after.is_finite() and after.y > point.y - 1.5
	return not nav.clear_of_walls(point, 0.45)


## How high the ground under an ant at `point` is: the top it is on, up off the floor, or the floor.
func _ground(point: Vector3) -> float:
	var floor := maze.ground_height(point)
	if point.y - floor > 1.0:
		var ways := _high_ways(point)
		var s := ways.level_at(point, point.y, 0.8, 0.0)
		if s >= 0:
			return ways.tops[s]
	return floor


## The way up to `goal` (up on a ledge, a terrace, a bridge, or on the ivy up to one)
## from about `from`, for the ants (AntColony.climb): the foot of the wall, up each
## face, onto the top. Worked out once for all of them for each surface, now and then.
func _climb_way(from: Vector3, goal: Vector3) -> PackedVector3Array:
	var ways := _high_ways(goal)
	var s := ways.under(goal)
	if s < 0:
		s = ways.near(goal)
	if s < 0:
		return PackedVector3Array()
	var now := Time.get_ticks_msec()
	if s == _climb_for and now - _climb_when < 700 and absf(_climb_from.y - from.y) < 1.0 and _climb_from.distance_to(from) < 12.0:
		return _climb_points
	_climb_for = s
	_climb_when = now
	_climb_from = from
	_climb_points = PackedVector3Array()
	var stages := ways.way_up(s, goal)
	for k in stages.size():
		var stage: Array = stages[k]
		var edge: Vector3 = stage[0]
		var out: Vector3 = stage[1]
		var top: float = stage[2]
		var base: float = stage[3]
		# (an ant already up on a step of it starts from there)
		if base < from.y - 1.0:
			continue
		if _climb_points.is_empty():
			var foot := edge + out * 1.0
			foot.y = base
			_climb_points.append(foot)
		var face := edge + out * 0.3
		_climb_points.append(Vector3(face.x, base, face.z))
		_climb_points.append(Vector3(face.x, top, face.z))
		var over := edge - out * 0.35
		_climb_points.append(Vector3(over.x, top, over.z))
	return _climb_points


var _climb_for := -1
var _climb_when := -100000
var _climb_from := Vector3.ZERO
var _climb_points := PackedVector3Array()
var _ways_zone: HighWays


func _high_ways(at: Vector3) -> HighWays:
	var zone := MazeLayout.zone_at(maze, at)
	if _ways_zone == null or _ways_zone.zone != zone:
		_ways_zone = HighWays.of(maze, zone, HighWays.layout_for(self, maze))
	return _ways_zone


# Where an ant at `from` should make for on its way to `goal`: MazeNav's
# waypoint, worked out once for each cell ants are in, for the cell the goal is
# in, and kept until the goal goes into another cell.
func _guide(from: Vector3, goal: Vector3) -> Vector3:
	var here := maze.cell_at(from)
	var there := maze.cell_at(goal)
	if here == there:
		return goal
	if there != _ways_for:
		_ways.clear()
		_ways_for = there
	var known: Variant = _ways.get(here)
	if known == null:
		var way := nav.waypoint(from, goal, MazeNav.clearance_for(0.4), 3)
		known = Vector3.INF if Vector2(way.x - goal.x, way.z - goal.z).length() < 0.1 else way
		_ways[here] = known
	return goal if not (known as Vector3).is_finite() else known


# --- Thinking ---

func _physics_process(delta: float) -> void:
	if colony == null:
		return
	if puppet:
		_follow_news(delta)
		return
	_spare(delta)
	match mode:
		Mode.CALM:
			_watch(delta)
		Mode.ALARM:
			_hunt(delta)
	chasing = mode == Mode.ALARM and quarry != null and not (quarry is MazeEnemy)
	_carry_about(delta)


# (its own senses are the ants': MazeEnemy's are not used; only who it has caught is let alone a while)
func _spare(delta: float) -> void:
	for player: Variant in _spared.keys():
		if not is_instance_valid(player):
			_spared.erase(player)
			continue
		_spared[player] -= delta
		if _spared[player] <= 0.0:
			_spared.erase(player)
	if mode == Mode.ALARM:
		_forget = memory


## Looks for anyone (or anything it could eat) treading on the trail, coming
## up to the nest or walking into an ant.
func _watch(delta: float) -> void:
	_look_in -= delta
	if _look_in > 0.0:
		return
	_look_in = look_every
	for player: Node3D in players():
		if huntable(player) and not maze.in_clearing(maze.cell_at(player.global_position)) and _trodden(player.global_position):
			_raise(player)
			return
	_prey_in -= look_every
	if _prey_in <= 0.0 and Ecology.current:
		_prey_in = 0.5
		for one: MazeEnemy in Ecology.current.creatures():
			if _could_eat(one) and _trodden(one.global_position):
				_raise(one)
				return


## Whether someone standing at `at` has trodden where the ants mind it.
func _trodden(at: Vector3) -> bool:
	if absf(at.y - _nest.y) > 3.0 and absf(at.y - maze.ground_height(at)) > 2.0:
		return false
	if Vector2(at.x - _nest.x, at.z - _nest.z).length() < nest_guard:
		return true
	var near := colony.nearest_ant(at)
	if near.x >= 0 and near.y < bump_range:
		return true
	if near.x >= 0 and near.y < trail_watch and colony.off_trail(at).x < trail_near:
		return true
	return false


func _could_eat(one: MazeEnemy) -> bool:
	return one != self and not one.dead and not one.puppet and one.process_mode != Node.PROCESS_MODE_DISABLED \
		and Ecology.diet(one) != Ecology.Diet.NONE and Ecology.bulk(one) <= 2


func _raise(who: Node3D) -> void:
	mode = Mode.ALARM
	quarry = who
	_forget = memory
	_far_off = 0.0
	_hold = 0.0
	alarms += 1
	_alarm_point = who.global_position
	colony.alarm(who.global_position)
	if not (who is MazeEnemy):
		spotted.emit(who)
	_aim_at(who)


func _hunt(delta: float) -> void:
	var after := quarry
	if after == null or not huntable(after) or (after is Node3D and maze.in_clearing(maze.cell_at(after.global_position))):
		_calm()
		return
	_aim_at(after)
	var at := after.global_position
	# (got away: none near them for a while, or too far from home, or up out of reach:
	# somewhere high with no way up to it)
	var high := at.y - maze.ground_height(at) > 2.2 and _climb_way(colony.front, at).is_empty()
	if colony.gap > near_enough or high:
		_far_off += delta
	else:
		_far_off = 0.0
	var from_home := minf(Vector2(at.x - _nest.x, at.z - _nest.z).length(), colony.off_trail(at).x)
	if _far_off > give_up_after or from_home > chase_range:
		_calm()
		return
	if after is MazeEnemy:
		var prey := after as MazeEnemy
		var need := prey_small if Ecology.bulk(prey) <= 1 else prey_big
		# (it struggles, and they lose hold and take it again: what they have held of it is slow to go)
		_hold = _hold + delta if colony.on_target >= need else maxf(_hold - delta * 0.25, 0.0)
		if trace_prey:
			print("  prey: %d on, held %.2f" % [colony.on_target, _hold])
		if _hold >= prey_hold and Ecology.current:
			var flies := Ecology.current.insects
			var before := flies.carcasses.size() if flies else 0
			Ecology.current.kill(prey, self)
			_calm()
			if flies and flies.carcasses.size() > before:
				var carcass: Node3D = flies.carcasses[flies.carcasses.size() - 1]
				if colony.carrying() == null and colony.carry(carcass):
					carcass.set_meta(&"ant_taken", true)


func _calm() -> void:
	mode = Mode.CALM
	quarry = null
	_forget = 0.0
	_hold = 0.0
	colony.calm()


## Tells the ants where `who` is.
func _aim_at(who: Node3D) -> void:
	if who is MazeEnemy:
		# (a creature: how it moves is measured, and it is on the ground)
		var step := get_physics_process_delta_time()
		colony.target_moving = (who.global_position - colony.target) / step if colony.target.is_finite() and step > 0.0 else Vector3.ZERO
		colony.target_moving.y = 0.0
		colony.target = who.global_position
		colony.target_grounded = true
		return
	colony.target = who.global_position
	var moving: Variant = who.get(&"velocity")
	colony.target_moving = moving if moving is Vector3 else Vector3.ZERO
	# (jumping or falling, or going up or down fast, tears them off: the same for
	# this machine's player and a friend's copy, whose floor is not known here)
	colony.target_grounded = absf(colony.target_moving.y) < 1.2


## Enough of them on who they are after: caught.
func _on_overwhelmed() -> void:
	if puppet or mode != Mode.ALARM or quarry is MazeEnemy:
		return
	if quarry and huntable(quarry):
		_catch(quarry)
	colony.shake_off()
	_calm()


## Anything that would set others hunting someone (the bats' alarm, a flare) sets them on them too, if they are near.
func notice(player: Node3D) -> void:
	if puppet or colony == null or mode == Mode.ALARM or not huntable(player):
		return
	var at := player.global_position
	if minf(Vector2(at.x - _nest.x, at.z - _nest.z).length(), colony.off_trail(at).x) < trail_watch:
		_raise(player)


# Now and then, calm and carrying nothing, they go for a carcass lying near the trail.
func _carry_about(delta: float) -> void:
	_carry_in -= delta
	if _carry_in > 0.0:
		return
	_carry_in = 3.0
	if mode != Mode.CALM or colony.carrying() != null:
		return
	for carcass in _carcasses():
		if colony.off_trail(carcass.global_position).x < 10.0 and maze.inside(maze.cell_at(carcass.global_position)):
			if colony.carry(carcass):
				carcass.set_meta(&"ant_taken", true)
			return


func _on_carried_home(thing: Node3D) -> void:
	# (it is down in the nest: no longer for the flies or anyone)
	thing.remove_from_group(&"fly_carrion")


## Something that hunts them has taken the ant at `index` (it goes back into the nest, to come out later).
func lose_ant(index: int) -> void:
	if colony:
		colony.lose(index)


# --- Being run by someone else ---

func yaw() -> float:
	return 0.0


func net_state() -> int:
	return mode


## How many alarms it has raised (four bits), so that a guest raises each.
func net_flag() -> int:
	return alarms & 0x0f


func net_point() -> Vector3:
	if mode == Mode.ALARM and colony and colony.target.is_finite():
		return colony.target
	return Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	var was_mode := mode
	var was_alarms := alarms & 0x0f
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode == Mode.ALARM
	alarms = flag & 0x0f
	if colony == null:
		return
	if mode == Mode.ALARM and (was_mode != Mode.ALARM or alarms != was_alarms) and point.is_finite():
		colony.alarm(point)
	elif mode == Mode.CALM and was_mode == Mode.ALARM:
		colony.calm()


func _follow_news(_delta: float) -> void:
	if not _heard:
		return
	if mode == Mode.ALARM and _heard_extra.is_finite():
		# (the player standing there, if one is: theirs is a better place to be than the news's)
		var there := nearest_player(_heard_extra)
		if there and there.global_position.distance_to(_heard_extra) < 2.5:
			_aim_at(there)
		else:
			colony.target = _heard_extra
			colony.target_moving = Vector3.ZERO
			colony.target_grounded = true
	elif mode == Mode.CALM and colony.alarm_up:
		colony.calm()
	_carry_about(get_physics_process_delta_time())


func _put(at: Vector3, _facing: float) -> void:
	global_position = at


func _puppet_changed() -> void:
	collision_layer = 0
	collision_mask = 0

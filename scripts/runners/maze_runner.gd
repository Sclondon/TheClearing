class_name MazeRunner
extends DrivenBoy
## One of the others in the maze: a boy like the players (the same boy, on the
## same controller, in a shirt of his own), driven by the computer, after the
## Gladers' Runners. Each knows his own section (ring) of the maze and runs it.
##
## What he does, in order of what comes first:
## - TAKEN. Caught, he is struck down (he goes limp), and after a moment he is
##   back in the clearing, sitting, as a caught player is; then he gets up and
##   jogs out to his section again (HOME).
## - FLEE. Anything after him (or anything hunting that comes near and that he
##   can see) and he sprints away by the passages, to cells he can get to before
##   it can, or up the nearest ivy (CLIMB) when that is nearer than the hunter.
##   Sprinting he is loud: whatever hunts and can see him within LOUD_RANGE turns
##   after him if he is nearer than what it was after. So one sprinting past
##   pulls the pack off you.
## - DRAW. He sees something hunting a player near him: he waves both arms over
##   his head ("over here!"), it takes after him, and he runs. Not often (DRAW_REST).
## - GREET and LEAD. A player comes up to him (within GREET_RANGE, in sight):
##   he stops, faces them and beckons, then runs for the gate out of his section
##   by the shortest way, looking back for them. If they fall behind he stops
##   and beckons again (WAIT); lost, he gives up. At the gate he stands aside
##   and points through it, and goes back to his running.
## - JOG. Otherwise he jogs his section's halls from one place to the next (never
##   out of it), and now and then climbs some ivy to look about.
##
## He is in the group `maze_players`, so everything that hunts the maze hunts
## him as it would a player, and `caught` comes to World, which calls `take`.
## Run on one machine (alone, or the room's maker); the others have a puppet
## (DrivenBoy.puppet) that MazeRunners keeps in step.

## A player this near, and in sight, he greets and leads.
const GREET_RANGE := 7.0
## Leading, he waits for one further behind than this; lost further than this
## (or out of sight this long), he gives up.
const LEAD_GAP := 14.0
const LOSE_GAP := 40.0
const LOSE_TIME := 8.0
## Anything hunting this near and in sight sends him off, whoever it is after.
const THREAT_RANGE := 13.0
## Sprinting, he is heard and seen this far by what hunts.
const LOUD_RANGE := 22.0
## A player hunted this near him, the hunter in his sight, and he draws it.
const DRAW_RANGE := 26.0
## How long before he will lead or draw again, seconds.
const LEAD_REST := 35.0
const DRAW_REST := 30.0
## How long he lies struck down, and sits in the clearing after.
const DOWN_TIME := 2.5
const SIT_TIME := 6.0
## Out of everyone's sight further than this, he is not posed (as the hunters' pose_range).
const POSE_RANGE := 75.0

enum Mode { JOG, FLEE, CLIMB, DRAW, GREET, LEAD, WAIT, AT_GATE, TAKEN, HOME }

## He has been caught (World puts him back; see `take`).
signal taken

var maze: Maze:
	set(value):
		maze = value
		nav = MazeNav.new(value, false) if value else null
var nav: MazeNav
## His section of the maze (1, the first ring).
var ring := 1
## The ivy he may climb (MazeFeatures.climbs from the ground, in his section).
var ivies: Array[IvyClimb] = []
var mode := Mode.JOG
## Who he is leading (or greeting, or waiting for), and what he is running from or drawing.
var follower: Node3D
var threat: Node3D
## Where he is making for.
var goal := Vector3.INF
## Where he is put when he has been caught: in the clearing, in front of one of its gates.
var home_at := Vector3.ZERO
var home_yaw := 0.0

var _rng := RandomNumberGenerator.new()
var _mode_time := 0.0
var _think_in := 0.0
var _loud_in := 0.0
var _lead_rest := 0.0
var _draw_rest := 0.0
var _climb_rest := 0.0
var _calm := 0.0
var _unseen := 0.0
var _goal_cell := Vector2i(-1, -1)
## Climbing: the ivy, how high he goes, and whether he is going up (1), resting (0) or down (-1); and why (escape or a look).
var _ivy: IvyClimb
var _ivy_high := 0.0
var _ivy_way := 1
var _ivy_escape := false
var _ivy_push := 0.0
var _ivy_room := {}
## Where he stands at the gate (worked out when he gets there).
var _aside_spot := Vector3.INF
var _aside := 0.0
var _aside_way := 1.0
## Going round something in the way: how far he turns off (radians), and steps till he looks again.
var _veer := 0.0
var _feel_in := 0
var _far := false
var _far_check := 0.0


func seed_choices(value: int) -> void:
	_rng.seed = value
	_climb_rest = _rng.randf_range(5.0, 25.0)


func _enter_tree() -> void:
	add_to_group(&"runners")


## Caught: struck down, and in a moment back in the clearing (`home_at`).
func take() -> void:
	if mode == Mode.TAKEN or puppet:
		return
	var from := threat.global_position if is_instance_valid(threat) else global_position - Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	var away := global_position - from
	away.y = 0.0
	# (posed again, if he was too far off to be: his limbs are the rig's)
	_far = false
	_rig.visible = true
	_rig.process_mode = Node.PROCESS_MODE_INHERIT
	ragdoll((away.normalized() if away.length() > 0.01 else Vector3.FORWARD) * 9.0 + Vector3.UP * 4.0)
	halt()
	gesture(GestureRig.Gesture.NONE)
	_set_mode(Mode.TAKEN)
	taken.emit()




func _physics_process(delta: float) -> void:
	if not puppet and maze:
		_think(delta)
		_drive()
	super(delta)


func _process(delta: float) -> void:
	super(delta)
	# Out of everyone's sight, he is not posed (the walls hide him).
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var camera := get_viewport().get_camera_3d()
		var far := camera != null and camera.global_position.distance_to(global_position) > POSE_RANGE and not is_limp
		if far != _far:
			_far = far
			_rig.visible = not far
			_rig.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT


func _set_mode(next: Mode) -> void:
	mode = next
	_mode_time = 0.0
	_think_in = 0.0
	if next != Mode.WAIT and next != Mode.GREET and next != Mode.AT_GATE and next != Mode.DRAW:
		gesture(GestureRig.Gesture.NONE)
		face(Vector3.INF)


# --- Deciding ----------------------------------------------------------------

func _think(delta: float) -> void:
	_mode_time += delta
	_lead_rest -= delta
	_draw_rest -= delta
	_climb_rest -= delta
	if mode == Mode.TAKEN:
		_taken_down()
		return
	_loud(delta)
	_think_in -= delta
	if _think_in > 0.0:
		return
	_think_in = 0.25
	var here := maze.cell_at(global_position)
	var after := _find_threat()
	if after and mode != Mode.FLEE and mode != Mode.CLIMB:
		threat = after
		_flee()
		return
	match mode:
		Mode.JOG:
			if maze.ring_of(here) != ring:
				_set_mode(Mode.HOME)
				return
			if _greet_someone():
				return
			if _draw_someone():
				return
			if _climb_rest <= 0.0 and _rng.randf() < 0.08:
				var ivy := _ivy_near(2)
				if ivy:
					_go_up(ivy, false)
					return
			if _goal_cell.x < 0 or here == _goal_cell or nav.distance(here, _goal_cell) < 0 or stuck_time > 2.0:
				_goal_cell = _wander_cell(here)
			goal = _middle_of(_goal_cell)
		Mode.HOME:
			if maze.ring_of(here) == ring and maze.depth_in_ring(here) > 0:
				_set_mode(Mode.JOG)
				return
			if _goal_cell.x < 0 or maze.ring_of(_goal_cell) != ring:
				_goal_cell = _cell_in_ring()
			goal = _middle_of(_goal_cell)
		Mode.FLEE:
			if after:
				threat = after
				_calm = 0.0
			else:
				_calm += 0.25
			if _calm > 3.0:
				threat = null
				_set_mode(Mode.JOG)
				return
			if is_instance_valid(threat):
				var ivy := _ivy_near(2)
				if ivy and _climb_rest <= 0.0 and _sooner_than(ivy, threat):
					_go_up(ivy, true)
					return
			if _mode_time < 0.3 or fmod(_mode_time, 1.0) < 0.25 or here == _goal_cell:
				_goal_cell = _flee_cell(here)
			goal = _middle_of(_goal_cell)
		Mode.CLIMB:
			_think_climb(after)
		Mode.DRAW:
			if not is_instance_valid(threat):
				_set_mode(Mode.JOG)
			elif _mode_time > 1.1:
				# (it has seen him now: it is after him, and he runs)
				if threat is MazeEnemy:
					(threat as MazeEnemy).notice(self)
				elif threat.has_method(&"alert"):
					threat.call(&"alert", global_position)
				_flee()
		Mode.GREET:
			if not _still_with_us(GREET_RANGE * 2.5):
				_give_up_leading()
			elif _mode_time > 1.6:
				_set_mode(Mode.LEAD)
		Mode.LEAD:
			if not _still_with_us(LOSE_GAP):
				_give_up_leading()
				return
			var gate := _gate()
			var at := maze.world(gate[0])
			if Vector2(at.x - global_position.x, at.z - global_position.z).length() < 4.0:
				_aside_spot = Vector3.INF
				_set_mode(Mode.AT_GATE)
				return
			goal = at
			if follower.global_position.distance_to(global_position) > LEAD_GAP:
				_set_mode(Mode.WAIT)
		Mode.WAIT:
			if not _still_with_us(LOSE_GAP) or _mode_time > 9.0:
				_give_up_leading()
			elif follower.global_position.distance_to(global_position) < LEAD_GAP * 0.55:
				_set_mode(Mode.LEAD)
		Mode.AT_GATE:
			var gate := _gate()
			var out: Vector2i = gate[1]
			var through := maze.cell_at(follower.global_position) if is_instance_valid(follower) else Vector2i(-99, -99)
			if _mode_time > 10.0 or through == gate[0] + out or not maze.inside(through):
				_give_up_leading()


## Each physics step: the stick and buttons for what he is doing.
func _drive() -> void:
	if is_limp or mode == Mode.TAKEN:
		halt()
		return
	match mode:
		Mode.JOG, Mode.HOME:
			_go(Pace.JOG)
		Mode.LEAD:
			_go(Pace.RUN)
		Mode.FLEE:
			_go(Pace.SPRINT)
		Mode.CLIMB:
			_drive_climb()
		Mode.DRAW:
			halt()
			face(threat.global_position if is_instance_valid(threat) else Vector3.INF)
			gesture(GestureRig.Gesture.WAVE)
		Mode.GREET, Mode.WAIT:
			halt()
			face(follower.global_position if is_instance_valid(follower) else Vector3.INF)
			gesture(GestureRig.Gesture.BECKON)
		Mode.AT_GATE:
			# Aside from the gate, pointing through it.
			var gate := _gate()
			var out: Vector2i = gate[1]
			var way := Vector3(out.x, 0.0, out.y)
			var spot := _aside_of_gate()
			if Vector2(spot.x - global_position.x, spot.z - global_position.z).length() > 0.6 and _mode_time < 4.0:
				steer(spot, Pace.WALK)
			else:
				halt()
			# (turned half to the one he brought, and half to the gate; his arm out to it)
			var slot := maze.world(gate[0]) + way * 7.0
			var to_slot := Vector3(slot.x - global_position.x, 0.0, slot.z - global_position.z).normalized()
			var to_them := Vector3.ZERO
			if is_instance_valid(follower):
				to_them = Vector3(follower.global_position.x - global_position.x, 0.0, follower.global_position.z - global_position.z).normalized()
			face(global_position + (to_slot + to_them).normalized() * 3.0 if to_them != Vector3.ZERO else slot)
			gesture(GestureRig.Gesture.POINT, to_slot)


## Towards `goal` by the passages, at `pace`. Stuck against something (a tree,
## a stone), he steps aside a moment, and jumps.
func _go(pace: Pace) -> void:
	if not goal.is_finite():
		halt()
		return
	var to := nav.waypoint(global_position, goal, MazeNav.clearance_for(0.35))
	# (by the middle of a wide hall, not along the foot of its wall)
	var way_cell := maze.cell_at(to)
	if Vector2(to.x - goal.x, to.z - goal.z).length() > 0.5 and way_cell != maze.cell_at(goal) and way_cell != maze.cell_at(global_position):
		var middle := _middle_of(way_cell)
		to = Vector3(middle.x, to.y, middle.z)
	var ahead := to - global_position
	ahead.y = 0.0
	if ahead.length() < 0.05:
		steer(to, pace)
		return
	# What the plan does not know about (a buttress, a terrace, a tree) he goes round.
	_feel_in -= 1
	if _feel_in <= 0:
		_feel_in = 3
		_veer = _veer_round(ahead)
	if stuck_time > 0.8 and _aside <= 0.0:
		_aside = 0.7
		_aside_way = 1.0 if _rng.randf() < 0.5 else -1.0
		jump()
	if _aside > 0.0:
		_aside -= get_physics_process_delta_time()
		_veer = 1.4 * _aside_way
	if _veer != 0.0:
		to = global_position + ahead.normalized().rotated(Vector3.UP, _veer) * minf(ahead.length(), 3.0)
	steer(to, pace)


## The middle of the hall at `cell`. Where halls are more than a cell wide
## (MazeStyle.hallway_diameter_cells), a cell's middle is near the foot of a
## wall, and the hall's middle is half a cell over towards its open sides.
func _middle_of(cell: Vector2i) -> Vector3:
	var at := maze.world(cell)
	var section := maze.ring_of(cell)
	if section < 1 or section > maze.styles.size() or maze.styles[section - 1].hallway_diameter_cells < 2:
		return at
	for step: Vector2i in Maze.STEPS:
		if not maze.blocked(cell, step) and maze.ring_of(cell + step) == section:
			at += Vector3(step.x, 0.0, step.y) * Maze.CELL * 0.5
	return at


## How far to turn from `ahead` (level) to keep out of something solid in the
## way before he gets where he is going: 0 if nothing is.
func _veer_round(ahead: Vector3) -> float:
	var reach := minf(2.4, ahead.length() - 0.3)
	if reach < 0.4:
		return 0.0
	var way := ahead.normalized()
	var space := get_world_3d().direct_space_state
	var chest := global_position + Vector3.UP * 0.8
	var query := PhysicsRayQueryParameters3D.create(chest, chest + way * reach, 1, [get_rid()])
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return 0.0
	# (round the side the thing slopes away to, first)
	var normal: Vector3 = hit["normal"]
	var first := -1.0 if way.cross(normal).y > 0.0 else 1.0
	for angle: float in [0.5, 1.0, 1.5]:
		for side: float in [first, -first]:
			query.to = chest + way.rotated(Vector3.UP, angle * side) * reach
			if space.intersect_ray(query).is_empty():
				return angle * side
	return 0.0


## Sprinting, he is loud: what hunts, sees him and is near, turns after him if he
## is nearer than what it was after.
func _loud(delta: float) -> void:
	_loud_in -= delta
	if _loud_in > 0.0 or not (is_sprinting and mode == Mode.FLEE):
		return
	_loud_in = 0.5
	var eye := global_position + Vector3.UP
	for node: Node in get_tree().get_nodes_in_group(&"maze_enemies"):
		var enemy := node as MazeEnemy
		if enemy == null or enemy.puppet or enemy.quarry == self or not enemy.huntable(self):
			continue
		var d := enemy.global_position.distance_to(global_position)
		if d > LOUD_RANGE or not nav.sees(eye, enemy.global_position + Vector3.UP, LOUD_RANGE):
			continue
		if enemy.quarry == null or not enemy.hunting() or enemy.quarry.global_position.distance_to(enemy.global_position) > d + 3.0:
			enemy.notice(self)


## The nearest thing hunting that is after him, or that is near and in his sight.
func _find_threat() -> Node3D:
	var best: Node3D = null
	var nearest := INF
	var eye := global_position + Vector3.UP
	for node: Node in get_tree().get_nodes_in_group(&"pursuers"):
		var hunter := node as Node3D
		if hunter == null or not hunter.is_inside_tree() or not hunter.get(&"chasing"):
			continue
		var d := hunter.global_position.distance_to(global_position)
		var after: Variant = hunter.get(&"quarry") if &"quarry" in hunter else hunter.get(&"prey")
		var mine: bool = after == self
		if not mine and (d > THREAT_RANGE or not nav.sees(eye, hunter.global_position + Vector3.UP, THREAT_RANGE)):
			continue
		if d < nearest:
			nearest = d
			best = hunter
	return best


func _flee() -> void:
	_calm = 0.0
	_set_mode(Mode.FLEE)
	_goal_cell = _flee_cell(maze.cell_at(global_position))
	goal = _middle_of(_goal_cell)


## Somewhere to run to: of the cells he can get to before `threat` can (by the
## passages, at about the same pace), the one furthest from it, not too far off.
## The clearing counts (nothing hunts in there).
func _flee_cell(here: Vector2i) -> Vector2i:
	if not is_instance_valid(threat):
		return _wander_cell(here)
	var theirs := nav.field(maze.cell_at(threat.global_position))
	var depth := {here: 0}
	var queue: Array[Vector2i] = [here]
	var best := here
	var best_score := -INF
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		var d: int = depth[cell]
		var them := theirs[maze.index(cell)]
		if them < 0:
			them = 99
		var score := them * 2.0 - d * 0.5 + (6.0 if maze.in_clearing(cell) else 0.0)
		if d > 0 and score > best_score:
			best_score = score
			best = cell
		if d >= 8:
			continue
		for step: Vector2i in Maze.STEPS:
			var next := cell + step
			if not maze.inside(next) or depth.has(next) or maze.blocked(cell, step):
				continue
			var there := theirs[maze.index(next)]
			# (not through anything it would be at first)
			if there >= 0 and there <= d + 1 and d > 0:
				continue
			depth[next] = d + 1
			queue.append(next)
	return best


## Somewhere to jog to: a cell of his section a few turns off.
func _wander_cell(here: Vector2i) -> Vector2i:
	var depth := {here: 0}
	var queue: Array[Vector2i] = [here]
	var choices: Array[Vector2i] = []
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		var d: int = depth[cell]
		if d >= 3 and maze.ring_of(cell) == ring:
			choices.append(cell)
		if d >= 9:
			continue
		for step: Vector2i in Maze.STEPS:
			var next := cell + step
			if not maze.inside(next) or depth.has(next) or maze.blocked(cell, step) or maze.ring_of(next) != ring:
				continue
			depth[next] = d + 1
			queue.append(next)
	if choices.is_empty():
		return _cell_in_ring()
	return choices[_rng.randi_range(0, choices.size() - 1)]


## Any open cell of his section, well in from its inside wall.
func _cell_in_ring() -> Vector2i:
	var cells: Array[Vector2i] = []
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		if maze.ring_of(cell) == ring and not maze.solid.has(cell) and maze.depth_in_ring(cell) > 0:
			cells.append(cell)
	return cells[_rng.randi_range(0, cells.size() - 1)] if not cells.is_empty() else maze.cell_at(global_position)


## The gate out of his section: [the cell in it, the step out].
func _gate() -> Array:
	if maze.exits.size() >= ring:
		return maze.exits[ring - 1]
	return [maze.exit, maze.exit_side]


## Where he stands at the gate, out of the way through it: to one side of it,
## short of the wall, wherever there is room.
func _aside_of_gate() -> Vector3:
	if _aside_spot.is_finite():
		return _aside_spot
	var gate := _gate()
	var out: Vector2i = gate[1]
	var way := Vector3(out.x, 0.0, out.y)
	var side := Vector3(-way.z, 0.0, way.x)
	var middle := maze.world(gate[0])
	_aside_spot = middle - way * 3.0
	for back: float in [1.0, 2.5]:
		for across: float in [2.5, -2.5, 3.5, -3.5, 1.8, -1.8]:
			var spot := middle - way * back + side * across
			if _room_at(spot):
				_aside_spot = spot
				return spot
	return _aside_spot


## Whether he would fit standing at `spot` (nothing solid there or close round it).
func _room_at(spot: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsPointQueryParameters3D.new()
	query.collision_mask = 1
	for offset: Vector3 in [Vector3.ZERO, Vector3(0.45, 0, 0), Vector3(-0.45, 0, 0), Vector3(0, 0, 0.45), Vector3(0, 0, -0.45)]:
		for high: float in [0.5, 1.2]:
			query.position = spot + offset + Vector3.UP * high
			if not space.intersect_point(query, 1).is_empty():
				return false
	return true


## The players (not runners) in the maze.
func _players() -> Array[Node3D]:
	var found: Array[Node3D] = []
	for node: Node in get_tree().get_nodes_in_group(&"maze_players"):
		if node != self and not node.is_in_group(&"runners") and node is Node3D:
			found.append(node)
	return found


func _greet_someone() -> bool:
	if _lead_rest > 0.0:
		return false
	var eye := global_position + Vector3.UP
	for player in _players():
		if player.get(&"is_limp") == true:
			continue
		if player.global_position.distance_to(global_position) < GREET_RANGE and nav.sees(eye, player.global_position + Vector3.UP, GREET_RANGE):
			follower = player
			_unseen = 0.0
			_set_mode(Mode.GREET)
			return true
	return false


## Something hunting a player near him that he can see: he draws it.
func _draw_someone() -> bool:
	if _draw_rest > 0.0:
		return false
	var eye := global_position + Vector3.UP
	var players := _players()
	for node: Node in get_tree().get_nodes_in_group(&"pursuers"):
		var hunter := node as Node3D
		if hunter == null or not hunter.get(&"chasing"):
			continue
		var after: Variant = hunter.get(&"quarry") if &"quarry" in hunter else hunter.get(&"prey")
		if not (after is Node3D) or not players.has(after):
			continue
		if (after as Node3D).global_position.distance_to(global_position) > DRAW_RANGE:
			continue
		if hunter.global_position.distance_to(global_position) < 6.0 or not nav.sees(eye, hunter.global_position + Vector3.UP, DRAW_RANGE + 10.0):
			continue
		threat = hunter
		_draw_rest = DRAW_REST
		_set_mode(Mode.DRAW)
		return true
	return false


## Whether the one he is leading is still with him: near enough, and seen lately.
func _still_with_us(gap: float) -> bool:
	if not is_instance_valid(follower) or not follower.is_inside_tree() or follower.get(&"is_limp") == true:
		return false
	if follower.global_position.distance_to(global_position) > gap:
		return false
	if follower.get(&"escaped") == true or not maze.inside(maze.cell_at(follower.global_position)):
		return false
	if nav.sees(global_position + Vector3.UP, follower.global_position + Vector3.UP, gap):
		_unseen = 0.0
	else:
		_unseen += 0.25
	return _unseen < LOSE_TIME


func _give_up_leading() -> void:
	follower = null
	_lead_rest = LEAD_REST
	_goal_cell = Vector2i(-1, -1)
	_set_mode(Mode.JOG)


# --- Climbing ----------------------------------------------------------------

## Ivy from the ground within `steps` cells of him, by the passages.
func _ivy_near(steps: int) -> IvyClimb:
	var here := maze.cell_at(global_position)
	var best: IvyClimb = null
	var nearest := INF
	for ivy in ivies:
		var cell := maze.cell_at(_ivy_foot(ivy))
		var d := nav.distance(here, cell)
		if d < 0 or d > steps or not _ivy_clear(ivy):
			continue
		var metres := _ivy_foot(ivy).distance_to(global_position)
		if metres < nearest:
			nearest = metres
			best = ivy
	return best


## Whether there is room to stand at the foot of `ivy` and take hold of it (some
## grow where another wall meets theirs, inside it). Asked once for each.
func _ivy_clear(ivy: IvyClimb) -> bool:
	if _ivy_room.has(ivy):
		return _ivy_room[ivy]
	var space := get_world_3d().direct_space_state
	var clear := true
	for point: Vector3 in [_ivy_foot(ivy) + Vector3.UP * 0.6, ivy.stand(0.0) + Vector3.UP * 0.6, ivy.stand(0.0) + Vector3.UP * 1.4]:
		var query := PhysicsPointQueryParameters3D.new()
		query.position = point
		query.collision_mask = 1
		if not space.intersect_point(query, 1).is_empty():
			clear = false
	_ivy_room[ivy] = clear
	return clear


## Where he stands to take hold of `ivy`: out from it, on the ground.
static func _ivy_foot(ivy: IvyClimb) -> Vector3:
	return ivy.stand(0.05) + ivy.global_basis.z * 0.6


## Whether he would be up `ivy` before `hunter` got to its foot.
func _sooner_than(ivy: IvyClimb, hunter: Node3D) -> bool:
	var foot := _ivy_foot(ivy)
	return foot.distance_to(global_position) + 2.0 < foot.distance_to(hunter.global_position)


func _go_up(ivy: IvyClimb, escape: bool) -> void:
	_ivy = ivy
	_ivy_escape = escape
	_ivy_way = 1
	_ivy_high = minf(ivy.top_y() - 1.1, (8.0 if escape else _rng.randf_range(4.0, 7.0)))
	_climb_rest = _rng.randf_range(40.0, 90.0)
	_set_mode(Mode.CLIMB)


func _think_climb(after: Node3D) -> void:
	if after:
		threat = after
	if state != State.LADDER:
		if _ivy_way < 0 or _mode_time > 8.0:
			# Down (or never got on it): back to running.
			_set_mode(Mode.FLEE if after else Mode.JOG)
			if after:
				_flee()
			return
		# On the way to it something got between: run instead.
		if after and not _sooner_than(_ivy, after):
			_flee()
		return
	if _ivy_way == 0:
		# Up there he waits until nothing is about (or, only looking, a few seconds).
		var calm := after == null and not _hunted_near(18.0)
		_calm = _calm + 0.25 if calm else 0.0
		if _calm > (4.0 if _ivy_escape else _rng.randf_range(2.5, 4.0)) or _mode_time > 45.0:
			_ivy_way = -1


## Whether anything is hunting within `range` of him.
func _hunted_near(reach: float) -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"pursuers"):
		if node.get(&"chasing") and (node as Node3D).global_position.distance_to(global_position) < reach:
			return true
	return false


func _drive_climb() -> void:
	if not is_instance_valid(_ivy):
		halt()
		return
	if state == State.LADDER:
		move = Vector3.ZERO
		sprint = false
		if _ivy_way > 0:
			climb = 1.0
			if global_position.y >= _ivy_high:
				_ivy_way = 0
				_calm = 0.0
				climb = 0.0
		elif _ivy_way == 0:
			climb = 0.0
		else:
			climb = -1.0
		return
	climb = 0.0
	if _ivy_way < 0:
		halt()
		return
	var foot := _ivy_foot(_ivy)
	var hold := _ivy.stand(global_position.y)
	if Vector2(hold.x - global_position.x, hold.z - global_position.z).length() > 1.0:
		goal = foot
		_go(Pace.SPRINT if _ivy_escape else Pace.JOG)
	else:
		# (into it, and it takes him; where the ground has sunk at its foot, with a jump)
		_ivy_push += get_physics_process_delta_time()
		if _ivy_push > 0.5:
			_ivy_push = 0.0
			jump()
		move = _ivy.facing() * 0.7
		sprint = false


# --- Taken -------------------------------------------------------------------

func _taken_down() -> void:
	if _mode_time > DOWN_TIME and is_limp:
		recover()
		global_position = home_at
		facing_yaw = home_yaw
		velocity = Vector3.ZERO
		_reset_visuals()
		sit()
	elif _mode_time > DOWN_TIME + SIT_TIME:
		wake()
		threat = null
		_goal_cell = Vector2i(-1, -1)
		_set_mode(Mode.HOME)

class_name MazeGibbon
extends MazeEnemy
## A gibbon of a troop that lives high in the maze. What it looks like, how it
## moves and how it sounds is Gibbon (creatures/gibbon/, a component of its
## own); this is only what it thinks, and it drives the Gibbon by moving it and
## calling on it.
##
## - THEY LIVE HIGH, on the high ways of their section (GibbonWays): along the
##   edges of the ledges on the walls, the terraces against them, and the wall
##   tops where those are low enough, round the corners, and in leaps across
##   gaps and halls and up and down a storey. They go in
##   troops (`troop()`: three to five), keeping to a stretch of ways round
##   where they were put (`home`): sitting on the ledges, hanging from them,
##   ambling along the tops upright or swinging along under the edges.
## - ON THE GROUND YOU ARE SAFE from them, but not unseen. One that sees someone
##   down in the halls gives the great call (Gibbon.great_call), and the troop
##   near it joins in, a duet; while they call (every `call_every`) everything
##   else that hunts within `alarm_range` is told where that player is, as the
##   bats do. Then they follow along the ways over them, watching, and call
##   again (no sooner than `call_rest`).
## - CLIMBERS ARE THEIR PREY: anyone on ivy, a vine, a rope, a ladder, hanging
##   from an edge, or up off the ground on a ledge, a wall top or a bridge
##   (`climbing`), within `reach` of their ways. The first to see them calls (the
##   warning), and the troop comes swinging, faster than he can run
##   (`swing_speed`). Close enough (`strike_range`), one winds up (drawn back,
##   shrieking: `Gibbon.WIND_UP`, the second warning) and swings at him feet
##   first; if its feet or free hand find him, `caught(player)`: knocked off.
##   Get down (drop to the ground: being on the ground is safe) or away from
##   the high ways before the swing, and it misses. A miss, or a catch, and it
##   gathers itself a moment (`spent_time`).
## - When they lose everyone they go back to their stretch of ways.
##
## Online, as every MazeEnemy: the host's copy thinks; a puppet follows what it
## hears (where it is, its gait, counts of its calls and lunges, what it is
## after), and calls and lunges when the host's does. Catching is the host's alone.
##
## Spawn (as MazeEnemies does any MazeEnemy): `MazeGibbon.troop(n)`, each with
## `maze` set, put in a hall cell of a section with ledges; each finds the
## nearest way up itself the first moment it is in the world.

enum Mode { ABOUT, SITTING, CALLING, WATCHING, HUNTING, LUNGE, SPENT }

## How big it is drawn (about 0.9 m standing, the boy's chest).
const SIZE := 1.15
## Out from the edge it hangs from, and in from it on the top.
const HANG_OUT := 0.04
const WALK_IN := 0.55

## Its paces: ambling upright along a top, swinging along an edge about its
## business, and after someone (the boy runs at 4.4 and sprints at 5.6); and
## through the air in a leap.
@export var walk_speed := 1.0
@export var amble_speed := 2.4
@export var swing_speed := 6.2
@export var leap_speed := 12.0
## How far from its ways someone can be and still be gone after (from his chest
## to the nearest edge).
@export var reach := 3.4
## It winds up to swing at him from this near (its hold to his chest).
@export var strike_range := 2.3
## How near its feet or free hand must pass his chest to have him.
@export var grab_reach := 0.6
## Seconds it needs after a lunge before another.
@export var spent_time := 1.1
## While calling, everything else that hunts within this is told where he is, this often.
@export var alarm_range := 40.0
@export var call_every := 1.4
## Seconds after a call before it calls again.
@export var call_rest := 22.0
## How many links of its ways round its home it keeps to, about its business.
@export var home_range := 5
## Further than this from every player it is not posed.
@export var pose_range := 80.0

var mode := Mode.ABOUT
var body: Gibbon
var ways: GibbonWays
## The face of its ways it lives by, and the one it is on now.
var home := -1
var face := -1
## Its heading, radians round Y (zero faces +Z).
var facing_yaw := 0.0
## Whether it has found its ways (false: it stays where it was put).
var placed := false

## Where on its ways it is (the edge it is at, world) and the way out from the wall there.
var _lip := Vector3.ZERO
var _out := Vector3.BACK
## The legs still to go: [point, GibbonWays.Kind, face, out].
var _legs: Array = []
var _leg_from := Vector3.ZERO
var _leg_out_from := Vector3.BACK
var _leg_t := 0.0
var _leg_time := 0.0
var _goal := -1
var _plan_in := 0.0
var _sit_left := 0.0
var _call_left := 0.0
var _call_rest := 0.0
var _alarm_in := 0.0
var _spent := 0.0
var _lunge_at := Vector3.INF
var _lunge_hit := false
var _calls := 0
var _lunges := 0
var _troop_index := 0
var _gait := Gibbon.Gait.HANG
var _gait_wait := 0.0
var _into := Vector3.ZERO
var _want_top := false
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flags := -1
var _far_check_out := 0.0


## A troop of `count`: a mix of coats (dark ones, and ringed and pale ones with white round their faces).
static func troop(count := 4) -> Array[MazeGibbon]:
	var made: Array[MazeGibbon] = []
	for k in count:
		var one := MazeGibbon.new()
		one._troop_index = k
		made.append(one)
	return made


func _init() -> void:
	sight_range = 40.0
	hear_range = 6.0
	memory = 10.0
	alert_range = 45.0
	pack = &"gibbons"
	look_every = 0.25


func _ready() -> void:
	add_to_group(&"pursuers")
	# It goes by its ways, not by physics: nothing bumps into it, and it bumps into nothing.
	collision_layer = 0
	collision_mask = 0
	body = Gibbon.new()
	body.kind = [Gibbon.Kind.RINGED, Gibbon.Kind.DARK, Gibbon.Kind.PALE, Gibbon.Kind.DARK, Gibbon.Kind.RINGED][_troop_index % 5]
	body.size = SIZE * _rng.randf_range(0.94, 1.06)
	body.seed_value = _rng.randi()
	body.force_low = Settings.low_poly or Mummy.low_poly
	body.top_level = true
	add_child(body)
	facing_yaw = global_rotation.y
	_prev_pos = global_position
	_curr_pos = global_position
	_call_rest = 0.0
	spotted.connect(_on_spotted)
	if maze and not puppet:
		_find_ways()


## The pieces its maze was built from (for its terraces), if it can find the
## MazeBuilder of its maze beside one of the nodes it is under.
func _layout() -> MazeLayout:
	var at: Node = get_parent()
	while at:
		var builder := at.get_node_or_null(^"Maze") as MazeBuilder
		if builder and builder.maze == maze:
			return builder.layout
		at = at.get_parent()
	return null


## Onto the nearest of its section's ways, and along them a little by its place in the troop.
func _find_ways() -> void:
	var section := maze.ring_of(maze.cell_at(global_position))
	ways = GibbonWays.of(maze, section, _layout())
	# (onto a stretch of ways that goes somewhere, if there is one near)
	var start := ways.nearest(global_position, Maze.CELL * 2.5, -1, 30)
	if start < 0:
		start = ways.nearest(global_position, Maze.CELL * 2.5)
	if start < 0:
		return
	placed = true
	home = start
	face = start
	if _troop_index > 0:
		var near := ways.around(start, 2)
		face = near[_troop_index % near.size()]
	_lip = ways.on_edge(face, global_position + ways.alongs[face] * (_troop_index - 1.5) * 2.0)
	_out = ways.outs[face]
	_gait = Gibbon.Gait.WALK if ways.walkable[face] else Gibbon.Gait.HANG
	_place(0.0)
	facing_yaw = atan2(ways.alongs[face].x, ways.alongs[face].z) + (PI if _troop_index % 2 == 1 else 0.0)
	_prev_pos = global_position
	_curr_pos = global_position
	_drive_body(0.0)
	body.settle()
	mode = Mode.SITTING
	_sit_left = _rng.randf_range(1.0, 6.0)


# --- Who is where ---

## Whether `player` is up off the ground: climbing (ivy, a vine, a rope, a
## ladder, hanging from an edge) or up on something.
func climbing(player: Node3D) -> bool:
	if player is Player:
		var state: int = (player as Player).state
		if state == Player.State.HANG or state == Player.State.CLIMB or state == Player.State.ROPE or state == Player.State.LADDER:
			return true
	var at := player.global_position
	return at.y - maze.ground_height(at) > 1.6


## Where on him it swings at: his chest.
func chest_of(player: Node3D) -> Vector3:
	return player.global_position + Vector3.UP * 0.85


## The face of its ways nearest `player`'s chest, if he is within `reach` of it (else -1).
func reachable(player: Node3D) -> int:
	if ways == null or home < 0:
		return -1
	return ways.nearest(chest_of(player), reach, ways.groups[home])


# --- Thinking ---

func _physics_process(delta: float) -> void:
	if puppet:
		_follow_news(delta)
		return
	if maze == null or not placed:
		return
	_sense(delta)
	_call_rest -= delta
	_gait_wait -= delta
	_plan_in -= delta
	var after := quarry if hunting() else null
	var prey := after if after and climbing(after) and reachable(after) >= 0 else null
	chasing = prey != null
	if _call_left > 0.0:
		_call_left -= delta
		_alarm_in -= delta
		if _alarm_in <= 0.0 and after:
			_alarm_in = call_every
			_raise_alarm(after)
	match mode:
		Mode.LUNGE:
			_lunging(prey if prey else after)
		Mode.SPENT:
			_spent -= delta
			if _spent <= 0.0:
				mode = Mode.HUNTING if prey else (Mode.WATCHING if after else Mode.ABOUT)
		Mode.CALLING:
			_legs.clear()
			if _call_left <= 0.0:
				mode = Mode.HUNTING if prey else (Mode.WATCHING if after else Mode.ABOUT)
		_:
			if prey:
				mode = Mode.HUNTING
				_hunt(prey)
			elif after:
				mode = Mode.WATCHING
				_watch(after)
			else:
				if mode == Mode.HUNTING or mode == Mode.WATCHING:
					mode = Mode.ABOUT
					_goal = -1
				_about(delta)
	var speed := swing_speed if mode == Mode.HUNTING else (3.5 if mode == Mode.WATCHING else amble_speed)
	if mode != Mode.LUNGE and mode != Mode.CALLING and mode != Mode.SPENT:
		_go(delta, speed)
	_place(delta)
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _on_spotted(player: Node3D) -> void:
	if puppet or not placed:
		return
	if _call_rest <= 0.0 and mode != Mode.LUNGE:
		_great_call(player)


func _great_call(_player: Node3D) -> void:
	mode = Mode.CALLING
	_calls += 1
	_call_left = Gibbon.CALL_TIME
	_call_rest = call_rest
	_alarm_in = 0.6
	body.great_call()
	face_toward(chest_of(_player))


## Told by one of its troop that `player` is about: it takes up the hunt, and
## (if he is on the ground and it has not called lately) joins the call.
func alerted(player: Node3D, from: Vector3) -> void:
	super(player, from)
	if puppet or not placed or not huntable(player):
		return
	if not climbing(player) and _call_rest <= 0.0 and mode != Mode.LUNGE and mode != Mode.CALLING:
		# (a beat behind the one that started it: a duet)
		_call_rest = call_rest
		get_tree().create_timer(_rng.randf_range(0.4, 1.1), false).timeout.connect(func() -> void:
			if is_instance_valid(self) and mode != Mode.LUNGE and quarry == player:
				_great_call(player))


## Everything else that hunts within `alarm_range` is told where `player` is.
func _raise_alarm(player: Node3D) -> void:
	if not huntable(player):
		return
	for other: Node in get_tree().get_nodes_in_group(&"maze_enemies"):
		if other == self or not (other is MazeEnemy) or other is MazeGibbon or other is Bats or (other as MazeEnemy).puppet:
			continue
		if (other as Node3D).global_position.distance_to(global_position) < alarm_range:
			(other as MazeEnemy).notice(player)
	for griever: Node in get_tree().get_nodes_in_group(&"grievers"):
		if griever.has_method(&"alert") and (griever as Node3D).global_position.distance_to(global_position) < alarm_range:
			griever.call(&"alert", player.global_position)


## After a climber: along the ways to the edge nearest him, and swinging at him from near enough.
func _hunt(prey: Node3D) -> void:
	var chest := chest_of(prey)
	var target := reachable(prey)
	if _plan_in <= 0.0 or target != _goal:
		_plan_in = 0.5
		_head_for(target, ways.on_edge(target, chest))
	elif _legs.size() <= 1 and target >= 0:
		# (on the last stretch: keep to the point on the edge nearest him)
		_aim_last(target, ways.on_edge(target, chest))
	if body.lunge_stage() != Gibbon.Lunge.NONE:
		return
	var near := _hold().distance_to(chest)
	var scale := body.size / SIZE
	# Up on the top with him, if he is up on it; else from under the edge, at him below it or on it.
	_want_top = chest.y > _lip.y + 0.35 and near < strike_range * 1.6 * scale and ways.walkable[face]
	if _want_top:
		if _gait == Gibbon.Gait.WALK and _gait_wait <= 0.0 and Vector2(chest.x - global_position.x, chest.z - global_position.z).length() <= 1.9 * scale:
			_start_lunge(prey)
	elif _gait == Gibbon.Gait.HANG and _gait_wait <= 0.0 and near <= strike_range * scale:
		_start_lunge(prey)


## Someone on the ground: follow along the ways over him, watching.
func _watch(who: Node3D) -> void:
	if _plan_in > 0.0:
		return
	_plan_in = 1.0
	var target := ways.nearest(who.global_position, 18.0, ways.groups[home])
	if target >= 0:
		var spot := ways.on_edge(target, who.global_position)
		if spot.distance_to(_lip) > 3.0:
			_head_for(target, spot)


## About its business: sitting, or off to somewhere else on its stretch of ways.
func _about(delta: float) -> void:
	if mode == Mode.SITTING:
		_sit_left -= delta
		if _sit_left <= 0.0:
			mode = Mode.ABOUT
			var near := ways.around(home, home_range)
			var pick: int = near[_rng.randi_range(0, near.size() - 1)]
			_head_for(pick, ways.on_edge(pick, ways.point(pick) + ways.alongs[pick] * _rng.randf_range(-5.0, 5.0)))
		return
	if _legs.is_empty():
		mode = Mode.SITTING
		_sit_left = _rng.randf_range(4.0, 11.0)


## Plans the way to `target` (a face), to end at `end` on its edge.
func _head_for(target: int, end: Vector3) -> void:
	if target < 0:
		return
	_goal = target
	# (from where the leg it is on now goes to: that one is finished first)
	var from := face
	var keep: Array = []
	if not _legs.is_empty():
		keep = [_legs[0]]
		from = _legs[0][2]
	var faces := ways.route(from, target)
	if faces.is_empty():
		return
	var legs: Array = keep
	for i in range(1, faces.size()):
		var link := ways.link(faces[i - 1], faces[i])
		var path: Array = link[2]
		for k in path.size():
			var leg: Array = path[k]
			var out: Vector3 = ways.outs[faces[i]]
			if k < path.size() - 1:
				out = (ways.outs[faces[i - 1]] + ways.outs[faces[i]]).normalized() if leg[1] != GibbonWays.Kind.LEAP else ways.outs[faces[i]]
			legs.append([leg[0], leg[1], faces[i], out])
	legs.append([end, GibbonWays.Kind.EDGE, target, ways.outs[target]])
	if keep.is_empty() and not legs.is_empty():
		_begin_leg(legs[0])
	_legs = legs


## Moves the end of its way along the last edge to `end`.
func _aim_last(target: int, end: Vector3) -> void:
	if _legs.is_empty():
		_legs = [[end, GibbonWays.Kind.EDGE, target, ways.outs[target]]]
		_begin_leg(_legs[0])
	elif _legs[_legs.size() - 1][2] == target:
		_legs[_legs.size() - 1][0] = end


func _begin_leg(leg: Array) -> void:
	_leg_from = _lip
	_leg_out_from = _out
	_leg_t = 0.0
	var far := _lip.distance_to(leg[0])
	_leg_time = maxf(far / leap_speed, 0.5) if leg[1] == GibbonWays.Kind.LEAP else 0.0


## Along its legs at `speed`.
func _go(delta: float, speed: float) -> void:
	if _legs.is_empty():
		_settle_gait(false)
		return
	var leg: Array = _legs[0]
	var to: Vector3 = leg[0]
	var kind: int = leg[1]
	if kind == GibbonWays.Kind.LEAP:
		_set_gait(Gibbon.Gait.FLY)
		_leg_t += delta
		var t := clampf(_leg_t / maxf(_leg_time, 0.01), 0.0, 1.0)
		var far := _leg_from.distance_to(to)
		var high := clampf(far * 0.12, 0.4, 2.0)
		_lip = _leg_from.lerp(to, t) + Vector3.UP * 4.0 * high * t * (1.0 - t)
		_out = _leg_out_from.slerp(leg[3], t) if _leg_out_from.dot(leg[3]) > -0.95 else leg[3]
		_face_along(to - _leg_from, delta, 10.0)
		if t >= 1.0:
			_lip = to
			_arrive(leg)
		return
	# Along an edge: walking on the top, ambling, where it can; else swinging under it.
	var walk := kind == GibbonWays.Kind.EDGE and ways.walkable[leg[2]] and ways.walkable[face] and (mode == Mode.ABOUT and speed <= amble_speed or _want_top)
	_set_gait(Gibbon.Gait.WALK if walk else Gibbon.Gait.HANG)
	var pace := (3.0 if _want_top else walk_speed) if walk else speed
	# (a moment to change from one to the other: no going while it hauls itself up or lets itself down)
	if _gait_wait > 0.0:
		pace = 0.0
	var step := to - _lip
	var left := step.length()
	var move := pace * delta
	if left <= move:
		_lip = to
		_out = leg[3]
		_arrive(leg)
		return
	_lip += step / left * move
	var total := maxf(_leg_from.distance_to(to), 0.01)
	_out = _leg_out_from.slerp(leg[3], clampf(1.0 - left / total, 0.0, 1.0)) if _leg_out_from.dot(leg[3]) > -0.95 else leg[3]
	_face_along(step, delta, 8.0)


func _arrive(leg: Array) -> void:
	face = leg[2]
	_legs.pop_front()
	if not _legs.is_empty():
		_begin_leg(_legs[0])
	elif _gait == Gibbon.Gait.FLY:
		_set_gait(Gibbon.Gait.HANG)


## Stopped: sitting up on a top it can walk on, or hanging.
func _settle_gait(_hunting: bool) -> void:
	if _gait == Gibbon.Gait.FLY:
		_set_gait(Gibbon.Gait.HANG)
	if body.lunge_stage() != Gibbon.Lunge.NONE:
		return
	if mode == Mode.HUNTING:
		_set_gait(Gibbon.Gait.WALK if _want_top else Gibbon.Gait.HANG)
	elif mode == Mode.WATCHING:
		_set_gait(Gibbon.Gait.HANG)
	elif mode == Mode.SITTING and ways.walkable[face] and _gait == Gibbon.Gait.HANG and not body.calling():
		_set_gait(Gibbon.Gait.WALK)


func _set_gait(next: Gibbon.Gait) -> void:
	if next != _gait:
		# (up over the edge or down off it takes a moment; into a leap or out of one, none)
		if next != Gibbon.Gait.FLY and _gait != Gibbon.Gait.FLY:
			_gait_wait = Gibbon.GAIT_TIME
		_gait = next


## Where the node is put for where it is on its ways: hanging, at the edge; walking, in on the top
## (moving in or out from the edge as it changes); leaping, along its arc.
func _place(delta: float) -> void:
	var into := _out * HANG_OUT
	if _gait == Gibbon.Gait.WALK:
		into = -_out * minf(WALK_IN, ways.depths[face] * 0.5 + 0.1)
	_into = _into.move_toward(into, delta / Gibbon.GAIT_TIME * (WALK_IN + HANG_OUT)) if delta > 0.0 else into
	var want := _lip + _into
	var was := global_position
	global_position = want
	velocity = (want - was) / maxf(delta, 0.001) if delta > 0.0 else Vector3.ZERO


## Where its hand holds the edge (world).
func _hold() -> Vector3:
	return _lip + _out * HANG_OUT


func _start_lunge(prey: Node3D) -> void:
	mode = Mode.LUNGE
	_lunges += 1
	_lunge_hit = false
	_lunge_at = chest_of(prey)
	_legs.clear()
	body.lunge(_lunge_at)
	face_toward(_lunge_at)


func _lunging(prey: Node3D) -> void:
	var stage := body.lunge_stage()
	if prey and huntable(prey) and stage == Gibbon.Lunge.WIND_UP and body.lunge_progress() < 0.75:
		# (it follows him as it winds up; for the last moment of it its swing is set)
		_lunge_at = chest_of(prey)
		body.aim_lunge(_lunge_at)
		face_toward(_lunge_at)
	if stage == Gibbon.Lunge.STRIKE and _gait == Gibbon.Gait.WALK:
		# (on a top, it leaps along it at him)
		var to := _lunge_at - _lip
		var flat := Vector3(to.x, 0.0, to.z)
		var go := minf(flat.length() - 0.5, 3.7 * get_physics_process_delta_time())
		if go > 0.0:
			var next := _lip + flat.normalized() * go
			var onto := ways.nearest(next, 1.5, ways.groups[home])
			if onto >= 0:
				face = onto
				_lip = ways.on_edge(onto, next)
	if stage == Gibbon.Lunge.STRIKE and not _lunge_hit:
		for player: Node3D in players():
			if huntable(player) and body.reaches(chest_of(player), grab_reach):
				_lunge_hit = true
				_catch(player)
				break
	if stage == Gibbon.Lunge.NONE:
		mode = Mode.SPENT
		_spent = spent_time


func face_toward(point: Vector3) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length() > 0.05:
		facing_yaw = atan2(to.x, to.z)


func _face_along(way: Vector3, delta: float, rate: float) -> void:
	if Vector2(way.x, way.z).length_squared() < 0.0001:
		return
	facing_yaw = lerp_angle(facing_yaw, atan2(way.x, way.z), 1.0 - exp(-rate * delta))


# --- Drawing ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			body.visible = not far
			body.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
	if _far:
		return
	_drive_body(delta)


func _drive_body(delta: float) -> void:
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-12.0 * delta)) if delta > 0.0 else _heard_yaw
	body.gait = _gait
	body.sitting = mode == Mode.SITTING
	body.away_from = _out if _gait != Gibbon.Gait.WALK else Vector3.ZERO
	var look := Vector3.INF
	if puppet:
		look = _heard_extra if _heard_extra.is_finite() else Vector3.INF
	elif mode == Mode.LUNGE and _lunge_at.is_finite():
		look = _lunge_at
	elif quarry and hunting():
		look = chest_of(quarry)
	body.look_at_point = look
	body.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction()) if delta > 0.0 else global_position
	body.rotation = Vector3(0.0, facing_yaw, 0.0)


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Its gait (low two bits), calls (next three), lunges (top three).
func net_flag() -> int:
	return (_gait & 0x03) | ((_calls & 0x07) << 2) | ((_lunges & 0x07) << 5)


func net_point() -> Vector3:
	if mode == Mode.LUNGE and _lunge_at.is_finite():
		return _lunge_at
	if quarry and hunting():
		return chest_of(quarry)
	return Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode == Mode.HUNTING or mode == Mode.LUNGE
	_gait = (flag & 0x03) as Gibbon.Gait
	if _heard_flags >= 0 and body:
		if ((flag >> 2) & 0x07) != ((_heard_flags >> 2) & 0x07):
			body.great_call()
		if ((flag >> 5) & 0x07) != ((_heard_flags >> 5) & 0x07):
			body.lunge(point if point.is_finite() else global_position + Vector3.DOWN)
	if body and mode == Mode.LUNGE and point.is_finite():
		body.aim_lunge(point)
	_heard_flags = flag


func _follow_news(delta: float) -> void:
	if not _heard:
		return
	_heard_at += _heard_moving * delta
	global_position = global_position.lerp(_heard_at, 1.0 - exp(-10.0 * delta))
	if global_position.distance_to(_heard_at) > 6.0:
		global_position = _heard_at
	_prev_pos = _curr_pos
	_curr_pos = global_position
	# (which way is out from the wall it is on, from its section's ways, now and then)
	_far_check_out -= delta
	if _far_check_out <= 0.0 and maze:
		_far_check_out = 0.5
		if ways == null:
			ways = GibbonWays.of(maze, maze.ring_of(maze.cell_at(global_position)), _layout())
		var near := ways.nearest(global_position, 3.0)
		if near >= 0:
			_out = ways.outs[near]


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if body:
		body.global_position = at
		body.settle()


func _puppet_changed() -> void:
	collision_layer = 0
	collision_mask = 0

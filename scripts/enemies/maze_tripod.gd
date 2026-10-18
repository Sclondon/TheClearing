class_name MazeTripod
extends MazeEnemy
## A Martian tripod (creatures/tripod/: Tripod is how it looks, walks, lights
## and burns; this is how it hunts the maze). A machine far taller than the
## walls, striding over them on three long noodly legs, its hood half lost in
## the mist. It does not chase: it patrols, and its searchlight hunts for it.
##
## - IT PATROLS round its ring in great slow strides (`walk_speed`, slower
##   than a boy's walk), never into the clearing, drifting over time towards
##   wherever people are in its ring. Its feet come down only on open ground,
##   never on anyone.
## - ITS SEARCHLIGHT SWEEPS the halls: a cone of pale light that crosses the
##   wall tops to the start of a hall and sweeps slowly down it, then moves on.
##   Anyone it lights in the open for `spot_time` (and that it can see: the
##   walls cut its light, as they do its sight) is FOUND. Out of the light, in
##   a slot, under a ledge, against the near wall, or pressed into the ivy, you
##   are not.
## - FOUND, IT SOUNDS ITS HORN (the deep "ULLA": the warning, `horn_time`), and
##   stops; its light stays on them, its hood turns to them.
## - Then, if they are near under it, ITS GRASPER REACHES DOWN (slowly: the
##   cable uncoils high over them first, then comes down at `reach_speed`),
##   and the claws closing on someone lift them away: caught. Running off, or
##   getting out of its sight, it draws back.
## - Otherwise THE HEAT RAY: the arm swings round and the emitter charges
##   (`charge_time`: it glows brighter and brighter and its hum rises), and at
##   the full its line is set: the ray comes down the hall they are in from up
##   to `burn_before` metres up it (as far as it can see the floor; never less
##   than `burn_lead`, so there is always time to see it coming), and burns
##   along the hall through where they stood and on past (`burn_speed`),
##   drifting after them sideways only slowly. If it has no such line on them
##   (the walls are in the way) it holds its charge and edges nearer for a
##   few seconds, then gives up. Step out of its line, into a side passage or a slot, under a
##   ledge, behind a buttress: the ray burns past (it stops at whatever it
##   meets first). Where it burns it leaves a scorch with steam rising off it.
## - If they get out of its sight it looks for them a while with its light
##   where they were (`search_time`), then patrols again. After an attack it
##   cools for `cool_time`.
##
## Online it is run on the host; a puppet follows its news (where it is, what
## it is doing, where its light or ray or grasper is) and sounds its horn when
## the host's does. Catching is the host's alone.

## What it is doing (`net_state`).
enum Mode { PATROL, SPOTTED, CHARGE, BURN, REACH, GRAB, COOL, SEARCH }

## Strides, m/s, patrolling and looking for someone.
@export var walk_speed := 1.5
@export var search_speed := 2.1
## How long someone must be in its light before they are found (s).
@export var spot_time := 0.45
## How long it sounds its horn before it acts, how long its ray charges.
@export var horn_time := 2.6
@export var charge_time := 2.4
## The ray: how fast it runs along the hall, how far up the hall from them it
## starts and how far past them it goes, how near it must pass to catch, and
## how fast it may drift sideways after them (m/s).
@export var burn_speed := 9.0
@export var burn_before := 20.0
@export var burn_after := 10.0
@export var burn_radius := 1.7
@export var burn_drift := 0.9
## The least run of hall it burns before it reaches them (m).
@export var burn_lead := 5.0
## The grasper: how near under it (flat, from its body) someone must be for it
## to reach rather than burn, how fast it comes down, how near catches.
@export var reach_range := 16.0
@export var reach_speed := 4.0
@export var grab_radius := 1.5
## Seconds: out of its sight this long and it has lost them; how long it looks;
## how long it rests after an attack; how long a catch lifts them.
@export var lose_time := 1.6
@export var search_time := 9.0
@export var cool_time := 5.0
@export var lift_time := 1.6
## The searchlight: how fast it sweeps down a hall, and how fast it crosses to the next.
@export var sweep_speed := 6.0
@export var cross_speed := 16.0
## Further than this from every player it is not walked or posed (it is put
## right when someone comes near again).
@export var pose_range := 450.0

var mode := Mode.PATROL
## The machine.
var look: Tripod
## Where its light is aimed, and (in a burn) where its ray is.
var beam_aim := Vector3.INF
var burn_at := Vector3.INF
var burn_from := Vector3.INF
var burn_to := Vector3.INF
var reach_at := Vector3.INF
## Horn blasts so far (sent, so a puppet sounds them too).
var horns := 0

var _mode_time := 0.0
var _time := 0.0
var _seen := {}
var _unseen := 0.0
var _sweep_start := Vector3.INF
var _sweep_end := Vector3.INF
var _sweeping := false
var _ring := 1
var _band_mid := 370.0
var _band_half := 16.0
var _round := 1.0
var _round_in := 0.0
var _speed := 0.0
var _heading := 0.0
var _far := false
var _far_check := 0.0
var _heard_horns := -1
var _heard_charge := 0.0
var _lifted: Node


func _init() -> void:
	sight_range = Tripod.BEAM_RANGE
	hear_range = 0.0
	memory = 10.0
	alert_range = 0.0
	spare_time = 6.0
	pack = &"tripods"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	_heading = rotation.y
	look = Tripod.new()
	look.name = "Machine"
	look.foot_ok = _foot_ok
	add_child(look)
	if maze:
		_find_band()


# --- Where it walks ---

## The band of its ring it keeps to (squares round the clearing's middle):
## the ring it was put in (the first, if put in the clearing).
func _find_band() -> void:
	var ring := maze.ring_of(maze.cell_at(global_position))
	_ring = clampi(ring, 1, maxi(maze.ring_sizes.size() - 1, 1))
	var inner := maze.ring_sizes[_ring - 1] * Maze.CELL * 0.5
	inner += maze.rampart(_ring) * Maze.CELL
	var outer := maze.ring_sizes[mini(_ring, maze.ring_sizes.size() - 1)] * Maze.CELL * 0.5
	_band_mid = (inner + outer) * 0.5
	_band_half = maxf((outer - inner) * 0.5 - 24.0, 3.0)


## How far out it is (squares round the middle: the larger of x and z).
static func square_out(at: Vector3) -> float:
	return maxf(absf(at.x), absf(at.z))


## Which way it would walk on patrol: round its band, the way it is going
## round, keeping to the middle of the band (wandering across it a little).
func _patrol_way() -> Vector3:
	var at := global_position
	var out := Vector3(signf(at.x), 0.0, 0.0) if absf(at.x) >= absf(at.z) else Vector3(0.0, 0.0, signf(at.z))
	var round_way := Vector3(-out.z, 0.0, out.x) * _round
	var want := _band_mid + _band_half * sin(_time * 0.04 + float(_rng.seed % 100))
	var back := clampf((want - square_out(at)) * 0.12, -1.5, 1.5)
	return (round_way + out * back).normalized()


## Every so often it picks which way round to go: towards whoever is in its ring, if anyone.
func _choose_round(delta: float) -> void:
	_round_in -= delta
	if _round_in > 0.0:
		return
	_round_in = 25.0
	var at := global_position
	var out := Vector3(signf(at.x), 0.0, 0.0) if absf(at.x) >= absf(at.z) else Vector3(0.0, 0.0, signf(at.z))
	var round_way := Vector3(-out.z, 0.0, out.x)
	var nearest: Node3D = null
	var far := 320.0
	for player: Node3D in players():
		if not huntable(player) or maze.ring_of(maze.cell_at(player.global_position)) != _ring:
			continue
		var d := player.global_position.distance_to(at)
		if d < far:
			far = d
			nearest = player
	if nearest:
		_round = 1.0 if round_way.dot(nearest.global_position - at) >= 0.0 else -1.0
	elif _rng.randf() < 0.3:
		_round = -_round


## Whether a foot may come down at `point`: in the maze (not the clearing), and not on anyone.
func _foot_ok(point: Vector3) -> bool:
	if maze == null:
		return true
	var cell := maze.cell_at(point)
	if not maze.inside(cell) or maze.in_clearing(cell):
		return false
	for player: Node3D in players():
		if is_instance_valid(player) and Vector2(player.global_position.x - point.x, player.global_position.z - point.z).length() < 5.0:
			return false
	return true


## Walks it along `way` (flat) at up to `speed`, turning slowly to face it, and slower while its legs lag.
func _stride(way: Vector3, speed: float, delta: float) -> void:
	var want := speed * (1.0 - look.strain * 0.85) if way.length() > 0.01 else 0.0
	_speed = move_toward(_speed, want, delta * 0.35)
	if way.length() > 0.01:
		_heading = lerp_angle(_heading, atan2(way.x, way.z), 1.0 - exp(-0.15 * delta))
	var facing := Vector3(sin(_heading), 0.0, cos(_heading))
	var at := global_position + (facing * 0.35 + way * 0.65).normalized() * _speed * delta if way.length() > 0.01 else global_position + facing * _speed * delta
	at.y = maze.ground_height(at)
	velocity = (at - global_position) / delta
	global_position = at
	rotation.y = _heading


# --- Its light ---

## Whether `player` could be found by its light: huntable, out of the
## clearing, not in the ivy, and nothing between its eye and them.
func exposed(player: Node3D) -> bool:
	if player == null or not huntable(player) or maze.in_clearing(maze.cell_at(player.global_position)):
		return false
	if MazeAngel.in_cover(player):
		return false
	var eye := look.eye_point()
	var chest := _chest(player)
	if eye.distance_to(chest) > Tripod.BEAM_RANGE:
		return false
	return _clear(eye, chest)


## Whether `player` is in its light now (in the cone, and exposed).
func in_beam(player: Node3D) -> bool:
	if not look.searchlight:
		return false
	var to := _chest(player) - look.eye_point()
	if look.beam_dir.angle_to(to) > deg_to_rad(Tripod.BEAM_ANGLE) * 1.1:
		return false
	return exposed(player)


func _chest(player: Node3D) -> Vector3:
	return player.global_position + Vector3.UP * 1.0


func _clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, _skip())
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _skip() -> Array[RID]:
	var skip: Array[RID] = []
	for player: Node in players():
		if player is CollisionObject3D and is_instance_valid(player):
			skip.append((player as CollisionObject3D).get_rid())
	return skip


## How far a flat ray goes from `from` along `way` before it meets a wall (at most `far`).
func _free(from: Vector3, way: Vector3, far: float) -> float:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + way * far, 1, _skip()))
	return far if hit.is_empty() else from.distance_to(hit["position"])


## The way a hall runs through `at` (the longer way, X or Z), and how far it runs each way.
func _hall_at(at: Vector3) -> Array:
	var waist := at + Vector3.UP * 1.0
	var x := _free(waist, Vector3.RIGHT, 40.0) + _free(waist, Vector3.LEFT, 40.0)
	var z := _free(waist, Vector3.BACK, 40.0) + _free(waist, Vector3.FORWARD, 40.0)
	return [Vector3.RIGHT if x >= z else Vector3.BACK, maxf(x, z)]


## Picks the next hall for the light to sweep: somewhere on the floor a way
## off round the way its hood faces, and along the hall there.
func _next_sweep() -> void:
	var body := global_position
	var space := get_world_3d().direct_space_state
	var facing := _heading + _rng.randf_range(-1.6, 1.6)
	for attempt in 12:
		var a := facing + _rng.randf_range(-0.5, 0.5)
		var d := _rng.randf_range(18.0, 62.0)
		var at := body + Vector3(sin(a), 0.0, cos(a)) * d
		var cell := maze.cell_at(at)
		if not maze.inside(cell) or maze.in_clearing(cell):
			continue
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, 150.0, at.z), Vector3(at.x, -20.0, at.z), 1, _skip()))
		if hit.is_empty() or (hit["position"] as Vector3).y > maze.ground_height(at) + 1.5:
			continue
		var floor_at: Vector3 = hit["position"]
		var hall: Array = _hall_at(floor_at)
		var along: Vector3 = hall[0]
		if _rng.randf() < 0.5:
			along = -along
		var run := minf(_free(floor_at + Vector3.UP, along, 26.0) - 2.0, 24.0)
		_sweep_start = floor_at
		_sweep_end = floor_at + along * maxf(run, 4.0)
		_sweeping = false
		return
	_sweep_start = body + Vector3(sin(_heading), 0.0, cos(_heading)) * 30.0
	_sweep_end = _sweep_start


## Moves its light on: across to the start of a hall, then slowly down it.
func _sweep(delta: float) -> void:
	if not beam_aim.is_finite():
		beam_aim = global_position + Vector3(sin(_heading), 0.0, cos(_heading)) * 30.0
	if not _sweep_start.is_finite():
		_next_sweep()
	if not _sweeping:
		beam_aim = beam_aim.move_toward(_sweep_start, cross_speed * delta)
		if beam_aim.distance_to(_sweep_start) < 0.5:
			_sweeping = true
	else:
		beam_aim = beam_aim.move_toward(_sweep_end, sweep_speed * delta)
		if beam_aim.distance_to(_sweep_end) < 0.5:
			_sweep_start = Vector3.INF


## Who its light has found (lit in the open for `spot_time`), or null.
func _found(delta: float) -> Node3D:
	var found: Node3D = null
	for player: Node3D in players():
		if in_beam(player):
			_seen[player] = float(_seen.get(player, 0.0)) + delta
			if _seen[player] >= spot_time:
				found = player
		else:
			_seen.erase(player)
	return found


# --- Thinking ---

func _physics_process(delta: float) -> void:
	_time += delta
	if puppet:
		_follow_news(delta)
		_drive_puppet(delta)
		_cull(delta)
		return
	if maze == null or look == null:
		return
	_cull(delta)
	if _far:
		return
	_mode_time += delta
	_spare(delta)
	_forget -= delta
	if quarry and not huntable(quarry):
		quarry = null
	var way := Vector3.ZERO
	var speed := 0.0
	match mode:
		Mode.PATROL:
			_choose_round(delta)
			way = _patrol_way()
			speed = walk_speed
			_sweep(delta)
			var found := _found(delta)
			if found:
				_spot(found)
		Mode.SEARCH:
			if _last_seen.is_finite():
				way = Vector3(_last_seen.x - global_position.x, 0.0, _last_seen.z - global_position.z)
				way = way.normalized() if way.length() > 12.0 else Vector3.ZERO
			speed = search_speed
			_search_light(delta)
			var found := _found(delta)
			if found:
				_spot(found)
			elif _mode_time > search_time:
				_enter(Mode.PATROL)
		Mode.SPOTTED:
			_hold_on_quarry(delta)
			if _lost():
				_enter(Mode.SEARCH)
			elif _mode_time >= horn_time:
				var under := Vector2(quarry.global_position.x - look.body_point().x, quarry.global_position.z - look.body_point().z).length()
				_enter(Mode.REACH if under < reach_range else Mode.CHARGE)
				if mode == Mode.REACH:
					reach_at = look.grasper_tip()
		Mode.CHARGE:
			_hold_on_quarry(delta)
			if _lost() or _mode_time > charge_time + 4.0:
				_enter(Mode.COOL)
			else:
				look.arm_target = _chest(quarry)
				look.charge = clampf(_mode_time / charge_time, 0.0, 1.0)
				if _mode_time >= charge_time and _set_burn():
					_enter(Mode.BURN)
				elif _mode_time >= charge_time * 0.5 and not _clear(look.emitter_tip(), _chest(quarry)):
					# (no line on them: it edges over them)
					way = Vector3(quarry.global_position.x - global_position.x, 0.0, quarry.global_position.z - global_position.z)
					way = way.normalized() if way.length() > 6.0 else Vector3.ZERO
					speed = walk_speed * 0.6
		Mode.BURN:
			_burn(delta)
		Mode.REACH:
			_reach(delta)
		Mode.GRAB:
			_grab(delta)
		Mode.COOL:
			look.firing = false
			look.charge = move_toward(look.charge, 0.0, delta)
			look.reach_target = Vector3.INF
			if _mode_time > 1.2:
				look.arm_target = Vector3.INF
			_sweep(delta)
			if _mode_time > cool_time:
				_enter(Mode.SEARCH if hunting() else Mode.PATROL)
	_stride(way, speed, delta)
	chasing = mode in [Mode.SPOTTED, Mode.CHARGE, Mode.BURN, Mode.REACH, Mode.GRAB]
	look.beam_target = beam_aim
	look.look_at_point = _chest(quarry) if quarry and mode in [Mode.SPOTTED, Mode.CHARGE, Mode.REACH] else Vector3.INF


func _enter(next: Mode) -> void:
	mode = next
	_mode_time = 0.0
	_unseen = 0.0
	if next in [Mode.PATROL, Mode.SEARCH, Mode.COOL]:
		look.firing = false
		look.reach_target = Vector3.INF
		_sweep_start = Vector3.INF
	if next == Mode.PATROL:
		look.arm_target = Vector3.INF
		look.charge = 0.0


## Its light has found `player`: it sounds its horn.
func _spot(player: Node3D) -> void:
	notice(player)
	_seen.clear()
	horns += 1
	look.horn()
	_enter(Mode.SPOTTED)


## Its light follows them (a little behind), as long as it can see them.
func _hold_on_quarry(delta: float) -> void:
	if quarry == null:
		_unseen = lose_time + 1.0
		return
	if exposed(quarry):
		_unseen = 0.0
		_forget = memory
		_last_seen = quarry.global_position
		beam_aim = beam_aim.move_toward(quarry.global_position + Vector3.UP * 0.5, 9.0 * delta) if beam_aim.is_finite() else quarry.global_position
	else:
		_unseen += delta


func _lost() -> bool:
	return quarry == null or not huntable(quarry) or _unseen > lose_time


## Looking for them: its light moves about where they were last.
func _search_light(delta: float) -> void:
	if not _last_seen.is_finite():
		_sweep(delta)
		return
	if not _sweep_start.is_finite() or (beam_aim.is_finite() and beam_aim.distance_to(_sweep_start) < 0.8):
		var a := _rng.randf_range(0.0, TAU)
		_sweep_start = _last_seen + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(2.0, 16.0)
	beam_aim = beam_aim.move_toward(_sweep_start, sweep_speed * delta) if beam_aim.is_finite() else _sweep_start


## Sets the ray's line, if it has one: through them along the floor, as much
## of it as the emitter can see; down the hall they are in if it can, coming
## from its own side, else across it; always with at least `burn_lead` of it
## before them. False if there is no such line.
func _set_burn() -> bool:
	var at := quarry.global_position
	var tip := look.emitter_tip()
	if not _clear(tip, at + Vector3.UP * 0.5):
		return false
	var hall: Array = _hall_at(at)
	var along: Vector3 = hall[0]
	var across := Vector3(along.z, 0.0, along.x)
	var to_body := look.body_point() - at
	var ways: Array[Vector3] = []
	for axis: Vector3 in [along, across]:
		var side := 1.0 if axis.dot(to_body) >= 0.0 else -1.0
		ways.append(axis * side)
		ways.append(-axis * side)
	for way: Vector3 in ways:
		var before := _seen_run(tip, at, way, burn_before)
		if before < burn_lead:
			continue
		var after := maxf(_seen_run(tip, at, -way, burn_after), 2.0)
		burn_from = at + way * before
		burn_to = at - way * after
		burn_from.y = maze.ground_height(burn_from)
		burn_to.y = maze.ground_height(burn_to)
		burn_at = burn_from
		return true
	return false


## How far along `way` from `at` the floor runs in the open and can be seen from `tip` (at most `most`).
func _seen_run(tip: Vector3, at: Vector3, way: Vector3, most: float) -> float:
	var room := _free(at + Vector3.UP * 1.0, way, most + 2.0) - 1.5
	var run := 0.0
	while run + 1.0 <= minf(room, most):
		if not _clear(tip, at + way * (run + 1.0) + Vector3.UP * 0.3):
			break
		run += 1.0
	return run


func _burn(delta: float) -> void:
	look.charge = 1.0
	look.firing = true
	var along := (burn_to - burn_from).normalized()
	var across := Vector3.UP.cross(along).normalized()
	burn_at = burn_at + along * burn_speed * delta
	# (it drifts after them sideways, but only slowly)
	if quarry and exposed(quarry):
		var off := (quarry.global_position - burn_at).dot(across)
		burn_at += across * clampf(off, -burn_drift * delta, burn_drift * delta)
	burn_at.y = maze.ground_height(burn_at)
	look.arm_target = burn_at
	beam_aim = beam_aim.move_toward(quarry.global_position if quarry else burn_at, 9.0 * delta) if beam_aim.is_finite() else burn_at
	for player: Node3D in players():
		if burned(player):
			_catch(player)
	if (burn_at - burn_from).dot(along) >= (burn_to - burn_from).length():
		_enter(Mode.COOL)


## Whether the ray is on `player` now: where it meets the world is at their
## feet (or it passes through them on the way), and nothing shields them from it.
func burned(player: Node3D) -> bool:
	if not huntable(player) or maze.in_clearing(maze.cell_at(player.global_position)):
		return false
	var hit := look.ray_hit
	if not hit.is_finite():
		return false
	var feet := player.global_position
	var tip := look.emitter_tip()
	var chest := _chest(player)
	var near := Vector2(hit.x - feet.x, hit.z - feet.z).length() < burn_radius and absf(hit.y - feet.y) < 2.5
	var through := _to_segment(chest, tip, hit) < 0.9
	if not near and not through:
		return false
	return _clear(tip, chest)


static func _to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## The grasper: high over them first, then coming down at them; drawn back if they get away.
func _reach(delta: float) -> void:
	_hold_on_quarry(delta)
	var body := look.body_point()
	var gone := _lost() or Vector2(quarry.global_position.x - body.x, quarry.global_position.z - body.z).length() > reach_range * 1.7
	if gone:
		_enter(Mode.COOL)
		return
	var chest := _chest(quarry)
	# (the first moments it uncoils high over them: the warning)
	var over := maxf(1.0 - _mode_time / 1.8, 0.0) * 22.0
	var want := chest + Vector3.UP * over
	if not reach_at.is_finite():
		reach_at = look.grasper_tip()
	reach_at = reach_at.move_toward(want, reach_speed * delta * (1.0 if over <= 0.0 else 2.0))
	look.reach_target = reach_at
	if look.grasper_tip().distance_to(chest) < grab_radius and reach_at.distance_to(chest) < grab_radius:
		_enter(Mode.GRAB)
		_lifted = MazeAngel.lift(quarry, lift_time + 0.2, body)


func _grab(_delta: float) -> void:
	if quarry and is_instance_valid(quarry):
		reach_at = _chest(quarry) + Vector3.UP * 0.4
		look.reach_target = reach_at
	if _mode_time >= lift_time:
		var who := quarry
		if _lifted and is_instance_valid(_lifted):
			_lifted.queue_free()
		_lifted = null
		_enter(Mode.COOL)
		if who and is_instance_valid(who):
			_catch(who)


## Counts down the time each caught player is let alone (MazeEnemy's senses, which it does not use, would).
func _spare(delta: float) -> void:
	for player: Variant in _spared.keys():
		if not is_instance_valid(player):
			_spared.erase(player)
			continue
		_spared[player] -= delta
		if _spared[player] <= 0.0:
			_spared.erase(player)


## Far from everyone it is neither walked nor posed (`pose_range`).
func _cull(delta: float) -> void:
	_far_check -= delta
	if _far_check > 0.0 or look == null:
		return
	_far_check = 1.0
	var near := nearest_player(global_position)
	var far := near != null and near.global_position.distance_to(global_position) > pose_range
	if far != _far:
		_far = far
		look.visible = not far
		look.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT


# --- Being run by someone else ---

func yaw() -> float:
	return _heading


func net_state() -> int:
	return mode


## Its horn blasts (low four bits, so a puppet sounds them too) and how far its ray has charged (high four).
func net_flag() -> int:
	return (horns & 0x0f) | (clampi(int(look.charge * 15.0), 0, 15) << 4) if look else horns & 0x0f


## Where its grasper reaches, or its ray burns, or else its light is aimed.
func net_point() -> Vector3:
	match mode:
		Mode.REACH, Mode.GRAB:
			return reach_at
		Mode.BURN:
			return burn_at
	return beam_aim


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode in [Mode.SPOTTED, Mode.CHARGE, Mode.BURN, Mode.REACH, Mode.GRAB]
	var blasts := flag & 0x0f
	if _heard_horns >= 0 and blasts != _heard_horns and look:
		look.horn()
	_heard_horns = blasts
	_heard_charge = ((flag >> 4) & 0x0f) / 15.0


func _follow_news(delta: float) -> void:
	if not _heard:
		return
	_heard_at += _heard_moving * delta
	global_position = global_position.lerp(_heard_at, 1.0 - exp(-4.0 * delta))
	if global_position.distance_to(_heard_at) > 20.0:
		global_position = _heard_at
	_heading = lerp_angle(_heading, _heard_yaw, 1.0 - exp(-3.0 * delta))
	rotation.y = _heading


## As a puppet: shows what it heard.
func _drive_puppet(delta: float) -> void:
	if look == null or not _heard:
		return
	var point := _heard_extra
	look.firing = mode == Mode.BURN
	look.charge = move_toward(look.charge, _heard_charge, delta * 2.0)
	look.reach_target = point if mode in [Mode.REACH, Mode.GRAB] and point.is_finite() else Vector3.INF
	look.arm_target = point if mode in [Mode.CHARGE, Mode.BURN] and point.is_finite() else (Vector3.INF if mode in [Mode.PATROL, Mode.SEARCH] else look.arm_target)
	if point.is_finite() and mode not in [Mode.REACH, Mode.GRAB, Mode.BURN]:
		beam_aim = point if not beam_aim.is_finite() else beam_aim.lerp(point, 1.0 - exp(-6.0 * delta))
	look.beam_target = beam_aim
	# (whoever plays here, if it is them its grasper has, is lifted here too)
	if mode == Mode.GRAB and point.is_finite():
		var mine := local_player()
		if mine and _lifted == null and _chest(mine).distance_to(point) < 2.5:
			_lifted = MazeAngel.lift(mine, lift_time + 0.2, global_position)
	elif _lifted and is_instance_valid(_lifted) and mode != Mode.GRAB:
		_lifted.queue_free()
		_lifted = null


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	_heading = facing
	rotation.y = facing
	velocity = Vector3.ZERO


func _puppet_changed() -> void:
	collision_layer = 0
	collision_mask = 0

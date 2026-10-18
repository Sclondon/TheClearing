class_name MazeColossus
extends MazeEnemy
## The colossus (creatures/colossus/: a gaunt, spindly giant of stone, fur and
## moss, after Shadow of the Colossus) set to crawl over a ring of the maze:
## what the maze might have been built for. This is only its thinking; how it
## looks and moves is the `Colossus` component, which this drives.
##
## - IT CRAWLS OVER THE TOP. Far too big for the halls, it goes round its ring
##   on the tops of the walls: every hand and foot comes down on a wall top
##   (`tops`), its elbows and knees bent high above, its body slung low over the
##   maze, the halls in its shadow. Dust and stones rain down where a hand or
##   foot comes down. It never puts a hand or foot outside its ring, so never
##   into the clearing.
## - IT SEES FROM ABOVE. Whoever is out in the open in front of it, within
##   `sense_range`, is seen: not whoever is in a slot or pressed to the foot of
##   a wall, under a ledge, a bridge or anything else overhead, or behind a wall
##   from where its eyes are. Standing still halves how far it sees. And it feels
##   the walls shake: anyone running hard near a hand or foot of it makes it stop
##   and peer about (LISTENING).
## - IT PRESSES WITH ONE FINGER. Someone seen in reach, and it stops, bends its
##   head down to peer between the walls, holds one long finger over them (its
##   shadow growing on the ground under it, following them slowly), and presses
##   it down, grinds, lifts, and tries again where they ran, up to
##   `presses_max` times (PRESSING). Under the fingertip as it presses is caught.
##   The finger cannot get into a slot, right up to the foot of a wall, or under
##   a ledge: get there. Lose it, and it gives up and crawls on.
## - IT LOOKS OVER THE WALL. Now and then, crawling beside the great wall round
##   the inside of its ring (the rampart round the clearing), it stops, rears up
##   and leans its hands on its top (PEERING) for `peer_time`: from the clearing,
##   a small stone head with two pale eyes over the wall.
##
## Online, the host thinks for it and the others' copies are puppets: each move
## of a hand or foot (which, and where it comes down) and each press is sent
## with its state (`net_flag`, `net_point`) and played out here as there.
## Catching is the host's.
##
## Spawn (as MazeEnemies.add does): `MazeColossus.new()`, set `maze`, place it
## and turn it (rotation.y, 0 faces +Z), add it to the tree. It crouches on the
## wall tops nearest where it is put, in that ring (the first, if put in the
## clearing).

enum Mode { CRAWLING, LISTENING, PRESSING, PEERING }

## How tall it would stand, metres.
const HEIGHT := 260.0
## How far from a wall's face its fingertip must come down (so: never in a slot), metres.
const FINGER_MARGIN := 2.4
## How near the face of a wall someone must be to be hidden from it there, metres.
const WALL_COVER := 1.3
## The order it moves its hands and feet in.
const GAIT: Array[int] = [Colossus.HAND_L, Colossus.FOOT_R, Colossus.HAND_R, Colossus.FOOT_L]

## How far off (flat, from its middle) it sees anyone in the open, metres.
@export var sense_range := 150.0
## How near a hand or foot of it (flat) someone running hard makes it stop and
## peer about, metres, and how fast is running hard (metres a second).
@export var feel_range := 45.0
@export var feel_speed := 4.6
@export var listen_time := 4.0
## How far from its middle (flat) its finger reaches, metres: nearer, and
## further, it crawls on towards them.
@export var press_reach := Vector2(25.0, 125.0)
## How many times it presses before it gives up, and how soon after it can start again, seconds.
@export var presses_max := 4
@export var press_every := 6.0
## How near the fingertip (beyond its own thickness) someone is caught, metres.
@export var catch_radius := 1.4
## A pause between moving one limb and the next, seconds.
@export var step_pause := 0.35
## How far ahead of where it stands each hand or foot goes each time, metres.
@export var stride := 22.0
## How long it looks over the great wall, how long between (at least, at most),
## and how near the wall (metres) its middle must be.
@export var peer_time := 16.0
@export var peer_every := Vector2(45.0, 110.0)
@export var peer_within := 95.0

var mode := Mode.CRAWLING
## The figure it drives.
var figure: Colossus
## The ring it crawls over.
var ring := 1
## Every point on the tops of the walls of its ring where a hand or foot may go.
var tops: Array[Vector3] = []

var _tops_at := {}
var _heading := 0.0
var _goal := Vector3.INF
var _round_way := 1.0
var _gait := 0
var _pause := 0.0
var _listen := 0.0
var _press_in := 0.0
var _press_for: Node3D
var _press_lifts := 0
var _press_stage := Colossus.Press.NONE
var _unseen := 0.0
var _caught_this_press := false
var _steps := 0
var _presses := 0
var _last_limb := 0
var _finger_body: AnimatableBody3D
var _speeds := {}
var _camera_shaken := false
var _heard_steps := -1
var _heard_presses := -1
var _rampart := 0.0
var _rampart_height := 0.0
var _peer_in := 0.0
var _peer_left := 0.0


func _init() -> void:
	sight_range = 0.0
	hear_range = 0.0
	memory = 6.0
	alert_range = 0.0
	pack = &"colossi"
	spare_time = 4.0


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = 0
	collision_mask = 0
	ring = maxi(maze.ring_of(maze.cell_at(global_position)), 1) if maze else 1
	ring = mini(ring, maze.styles.size()) if maze else ring
	_find_tops()
	_rampart_bounds()
	_round_way = 1.0 if _rng.randf() < 0.5 else -1.0
	_peer_in = _rng.randf_range(10.0, peer_every.x)
	figure = Colossus.new()
	figure.height = HEIGHT
	# (the low-poly model on phones: a third of the triangles)
	figure.low_poly = Settings.low_poly or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	figure.planted.connect(_on_planted)
	add_child(figure)
	figure.top_level = true
	_heading = rotation.y
	_stand(global_position, _heading)
	_finger_body = AnimatableBody3D.new()
	_finger_body.collision_layer = 1
	_finger_body.collision_mask = 0
	_finger_body.sync_to_physics = false
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.disabled = true
	_finger_body.add_child(shape)
	add_child(_finger_body)
	_finger_body.top_level = true


# --- Where it may put its hands and feet --------------------------------------------

## Every point on a wall top inside its ring (three along each wall between two
## of its cells), at the wall's height, and them by cell for finding them near.
func _find_tops() -> void:
	tops.clear()
	_tops_at.clear()
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		if maze.ring_of(cell) != ring or maze.solid.has(cell):
			continue
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var other := cell + step
			if not maze.inside(other) or maze.ring_of(other) != ring or maze.solid.has(other) or not maze.blocked(cell, step):
				continue
			var middle := (maze.world(cell) + maze.world(other)) * 0.5
			var along := Vector3(step.y, 0.0, step.x)
			for k: float in [-1.0, 0.0, 1.0]:
				var p := middle + along * k * Maze.CELL * 0.32
				p.y = maze.wall_height(cell, step)
				var at := maze.cell_at(p)
				if not _tops_at.has(at):
					_tops_at[at] = []
				(_tops_at[at] as Array).append(tops.size())
				tops.append(p)


## The wall tops within `within` metres (flat) of `point`.
func tops_near(point: Vector3, within: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var centre := maze.cell_at(point)
	var reach := ceili(within / Maze.CELL) + 1
	for dx in range(-reach, reach + 1):
		for dy in range(-reach, reach + 1):
			var found: Variant = _tops_at.get(centre + Vector2i(dx, dy))
			if found == null:
				continue
			for i: int in found:
				var p := tops[i]
				if Vector2(p.x - point.x, p.z - point.z).length() <= within:
					out.append(p)
	return out


## The nearest wall top to `point` (flat), or INF.
func nearest_top(point: Vector3, within := 60.0) -> Vector3:
	var best := Vector3.INF
	var best_d := INF
	for p in tops_near(point, within):
		var d := Vector2(p.x - point.x, p.z - point.z).length()
		if d < best_d:
			best_d = d
			best = p
	if not best.is_finite() and within < 2000.0:
		return nearest_top(point, within * 4.0)
	return best


## Crouches it near `at`, facing `yaw`, each hand and foot on the wall top
## nearest where it would stand.
func _stand(at: Vector3, yaw: float) -> void:
	figure.put(at, yaw)
	var basis := Basis(Vector3.UP, yaw)
	var middle := Vector3.ZERO
	var spots: Array[Vector3] = []
	for limb in 4:
		var where := figure.stance(limb)
		var spot := nearest_top(at - basis.z * figure.scale_m() + basis * Vector3(where.x, 0.0, where.y))
		spots.append(spot if spot.is_finite() else at)
		middle += spots[limb]
	figure.put(middle * 0.25, yaw)
	for limb in 4:
		figure.plant(limb, spots[limb], _limb_yaw(limb, yaw))
	_pick_goal()


## How a hand or foot is turned, for the body facing `yaw`: a little out.
static func _limb_yaw(limb: int, yaw: float) -> float:
	var out := 1.0 if limb == Colossus.HAND_L or limb == Colossus.FOOT_L else -1.0
	return yaw + out * (0.3 if limb <= Colossus.HAND_R else 0.45)


## The outer face of the rampart round the inside of its ring (as the walls go
## round) and how high it is; 0 if there is none.
func _rampart_bounds() -> void:
	var style: MazeStyle = maze.styles[ring - 1] if ring >= 1 and ring <= maze.styles.size() else null
	if style and style.border_wall_thickness_cells > 0 and not maze.gates[ring - 1].is_empty():
		var way: Array = maze.gates[ring - 1][0]
		var thick := maze.wall_thick(way[0], way[1])
		_rampart = maze.ring_sizes[ring - 1] * Maze.CELL * 0.5 + thick * 0.5 + style.border_wall_thickness_cells * Maze.CELL
		_rampart_height = style.section_border_wall_height


## Whether a point is at least `margin` from the face of every wall, by the plan,
## each wall as thick as it really is (Maze.wall_thick); near where walls meet,
## the corner between them counts.
func clear_of_walls(point: Vector3, margin: float) -> bool:
	var cell := maze.cell_at(point)
	if not maze.inside(cell) or maze.solid.has(cell):
		return false
	var middle := maze.world(cell)
	var half := Maze.CELL * 0.5
	var off := Vector2(point.x - middle.x, point.z - middle.z)
	for step: Vector2i in Maze.STEPS:
		var along := off.x * step.x + off.y * step.y
		if maze.blocked(cell, step) and along > half - maze.wall_thick(cell, step) * 0.5 - margin:
			return false
	var sx := 1 if off.x > 0.0 else -1
	var sy := 1 if off.y > 0.0 else -1
	var side := cell + Vector2i(sx, 0)
	var below := cell + Vector2i(0, sy)
	var corner := half - maze.wall_thick(cell, Vector2i(sx, 0)) * 0.5 - margin
	if absf(off.x) > corner and absf(off.y) > corner:
		if (maze.inside(side) and maze.blocked(side, Vector2i(0, sy))) or (maze.inside(below) and maze.blocked(below, Vector2i(sx, 0))):
			return false
	return true


## Where its fingertip comes down for someone at `at`: as near as can be, on the
## floor of its ring and clear of the walls (it cannot get into a slot, nor right
## up to a wall). INF if there is nowhere near.
func finger_spot(at: Vector3) -> Vector3:
	var cell := maze.cell_at(at)
	if maze.ring_of(cell) != ring:
		return Vector3.INF
	if clear_of_walls(at, FINGER_MARGIN):
		return at
	for r: float in [0.75, 1.5, 2.5, 3.5]:
		for k in 12:
			var a := TAU * k / 12.0
			var p := at + Vector3(cos(a), 0.0, sin(a)) * r
			if maze.ring_of(maze.cell_at(p)) == ring and clear_of_walls(p, FINGER_MARGIN):
				p.y = at.y
				return p
	return Vector3.INF


## The way the hall at `at` runs (so that the hand goes in edge first, along it).
func hall_along(at: Vector3) -> Vector3:
	var cell := maze.cell_at(at)
	var walls_x := maze.blocked(cell, Vector2i(1, 0)) or maze.blocked(cell, Vector2i(-1, 0))
	var walls_z := maze.blocked(cell, Vector2i(0, 1)) or maze.blocked(cell, Vector2i(0, -1))
	if walls_x and not walls_z:
		return Vector3(0, 0, 1)
	if walls_z and not walls_x:
		return Vector3(1, 0, 0)
	var off := at - maze.world(cell)
	return Vector3(0, 0, 1) if absf(off.x) > absf(off.z) else Vector3(1, 0, 0)


# --- Thinking -----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if puppet:
		_puppet(delta)
		return
	if maze == null:
		return
	_press_in -= delta
	_peer_in -= delta
	_watch(delta)
	match mode:
		Mode.CRAWLING:
			_crawl(delta)
		Mode.LISTENING:
			_listen -= delta
			if _listen <= 0.0:
				mode = Mode.CRAWLING
				figure.stoop = 0.0
		Mode.PRESSING:
			_pressing(delta)
		Mode.PEERING:
			_peer_left -= delta
			if _peer_left <= 0.0:
				_stop_peering()
	chasing = mode == Mode.PRESSING or (quarry != null and hunting())
	figure.glow = 2.6 if mode != Mode.CRAWLING or hunting() else 1.4
	var at := figure.pelvis()
	var moved := Vector3(at.x, 0.0, at.z)
	velocity = (moved - global_position) / maxf(delta, 0.001)
	global_position = moved
	_place_finger()


## Moves the next hand or foot on: towards its goal round the ring, or towards
## whoever it has seen out of reach.
func _crawl(delta: float) -> void:
	if figure.stepping() >= 0:
		return
	_pause -= delta
	if _pause > 0.0:
		return
	if not hunting() and _peer_in <= 0.0 and _start_peering():
		return
	var at := figure.pelvis()
	var goal := _goal
	if hunting() and quarry:
		goal = quarry.global_position
	elif not _goal.is_finite() or Vector2(_goal.x - at.x, _goal.z - at.z).length() < 60.0:
		_pick_goal()
		goal = _goal
	var to := goal - at
	_heading = atan2(to.x, to.z)
	figure.facing = _heading
	for turn: float in [0.0, 0.5, -0.5, 1.0, -1.0, 1.8, -1.8]:
		if _move_limb(GAIT[_gait], _heading + turn):
			_gait = (_gait + 1) % GAIT.size()
			return
	# (nowhere for this one: the next, and a new goal)
	_gait = (_gait + 1) % GAIT.size()
	_pick_goal()
	_pause = 0.8


## Moves `limb` on to the wall top nearest where it would stand about its
## body, a stride on the way `yaw`. False if there is nowhere to put it.
func _move_limb(limb: int, yaw: float) -> bool:
	var basis := Basis(Vector3.UP, yaw)
	var ahead := basis.z
	var left := basis.x
	var s := figure.scale_m()
	var middle := figure.pelvis()
	var where := figure.stance(limb)
	var want := middle + basis * Vector3(where.x, 0.0, where.y) + ahead * stride
	var side := 1.0 if limb == Colossus.HAND_L or limb == Colossus.FOOT_L else -1.0
	var from := figure.landing(limb)
	var best := Vector3.INF
	var best_d := INF
	for p in tops_near(want, 1.5 * s):
		var off := p - middle
		# (on its own side of the body; not back the way it came; clear of its other limbs)
		if off.dot(left) * side < 0.5 * s:
			continue
		if (p - from).dot(ahead) < -4.0:
			continue
		var crowded := false
		for other in 4:
			if other != limb and Vector2(p.x - figure.landing(other).x, p.z - figure.landing(other).z).length() < 0.7 * s:
				crowded = true
		if crowded:
			continue
		var d := Vector2(p.x - want.x, p.z - want.z).length()
		if d < best_d:
			best_d = d
			best = p
	if not best.is_finite():
		return false
	figure.step(limb, best, _limb_yaw(limb, yaw), maxf(from.y, best.y))
	_last_limb = limb
	_steps += 1
	_pause = step_pause
	return true


## Somewhere further round the ring to crawl to.
func _pick_goal() -> void:
	var at := figure.pelvis() if figure else global_position
	var angle := atan2(at.z, at.x) + _round_way * _rng.randf_range(0.3, 0.5)
	var round_dir := Vector3(cos(angle), 0.0, sin(angle))
	var square := maxf(absf(round_dir.x), absf(round_dir.z))
	var middle := maxf(at.x * signf(at.x), at.z * signf(at.z))
	_goal = round_dir * middle / square


## Looks for anyone in the open, and feels for anyone running near its hands and feet.
func _watch(delta: float) -> void:
	for player: Variant in _spared.keys():
		if not is_instance_valid(player):
			_spared.erase(player)
			continue
		_spared[player] -= delta
		if _spared[player] <= 0.0:
			_spared.erase(player)
	_forget -= delta
	if quarry and (not huntable(quarry) or _forget <= 0.0):
		quarry = null
	_look_in -= delta
	if _look_in > 0.0:
		return
	_look_in = 0.3
	var eye := figure.eye()
	var middle := figure.pelvis()
	var facing := Vector3(sin(figure.body_yaw()), 0.0, cos(figure.body_yaw()))
	var best: Node3D = null
	var best_d := INF
	for player: Node3D in players():
		if not huntable(player):
			continue
		var at := player.global_position
		if maze.ring_of(maze.cell_at(at)) != ring:
			continue
		var last: Vector3 = _speeds.get(player, at)
		var speed := Vector2(at.x - last.x, at.z - last.z).length() / 0.3
		_speeds[player] = at
		# The walls shake under someone running hard near a hand or foot: it stops to peer about.
		var grounded := at.y - maze.ground_height(at) < 1.0
		if mode == Mode.CRAWLING and speed > feel_speed and grounded:
			for limb in 4:
				var plant := figure.landing(limb)
				if figure.stepping() != limb and Vector2(plant.x - at.x, plant.z - at.z).length() < feel_range:
					mode = Mode.LISTENING
					_listen = listen_time
					figure.look_at_point = at
					figure.stoop = 0.5
					break
		var flat := Vector2(at.x - middle.x, at.z - middle.z)
		var range_now := sense_range * (1.6 if mode == Mode.LISTENING else 1.0) * (1.0 if speed > 0.6 else 0.5)
		if flat.length() > range_now:
			continue
		if mode != Mode.LISTENING and facing.dot(Vector3(flat.x, 0.0, flat.y).normalized()) < -0.35:
			continue
		if hidden(player, eye):
			continue
		if flat.length() < best_d:
			best_d = flat.length()
			best = player
	if best:
		notice(best)
		figure.look_at_point = best.global_position
		if mode != Mode.PRESSING and mode != Mode.PEERING and _press_in <= 0.0 and figure.stepping() < 0:
			if best_d > press_reach.x and best_d < press_reach.y and finger_spot(best.global_position).is_finite():
				_start_press(best)
	elif mode == Mode.CRAWLING:
		figure.look_at_point = Vector3.INF if not hunting() else quarry.global_position


## Whether someone is out of its sight from `eye`: in a slot or flat against a
## wall, under anything (a ledge, a bridge, a pipe), or behind a wall.
func hidden(player: Node3D, eye: Vector3) -> bool:
	var at := player.global_position
	if not clear_of_walls(at, WALL_COVER):
		return true
	if covered(at):
		return true
	var exclude: Array[RID] = [_finger_body.get_rid()]
	if player is CollisionObject3D:
		exclude.append((player as CollisionObject3D).get_rid())
	var sight := PhysicsRayQueryParameters3D.create(eye, at + Vector3.UP * 1.0, 1, exclude)
	return not get_world_3d().direct_space_state.intersect_ray(sight).is_empty()


## Whether something is over a point (a ledge, a bridge): the finger cannot get under it.
func covered(at: Vector3) -> bool:
	var chest := at + Vector3.UP * 1.0
	var above := PhysicsRayQueryParameters3D.create(chest, chest + Vector3.UP * 30.0, 1, [_finger_body.get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(above).is_empty()


func _start_press(player: Node3D) -> void:
	mode = Mode.PRESSING
	_press_for = player
	_press_lifts = 0
	_unseen = 0.0
	_caught_this_press = false
	_presses += 1
	var spot := finger_spot(player.global_position)
	figure.stoop = 1.0
	figure.look_at_point = spot
	figure.press(spot, hall_along(spot))
	_press_stage = figure.press_stage()


func _pressing(delta: float) -> void:
	if not figure.pressing():
		mode = Mode.CRAWLING
		_press_in = press_every
		_press_for = null
		figure.stoop = 0.0
		figure.look_at_point = Vector3.INF
		_pause = 1.0
		return
	var stage := figure.press_stage()
	var seen := is_instance_valid(_press_for) and huntable(_press_for) and not hidden(_press_for, figure.eye())
	_unseen = 0.0 if seen else _unseen + delta
	if stage == Colossus.Press.HOVER or stage == Colossus.Press.REACH:
		# (it follows whoever it is after while it can see them)
		if seen:
			var spot := finger_spot(_press_for.global_position)
			if spot.is_finite():
				figure.press_target = spot
				figure.look_at_point = spot
				figure.press_along = hall_along(spot)
		if _unseen > 2.5 or _press_lifts >= presses_max:
			figure.release()
	if stage == Colossus.Press.LIFT and _press_stage != Colossus.Press.LIFT:
		_press_lifts += 1
		_caught_this_press = false
		if _press_lifts >= presses_max or not seen:
			figure.release()
		else:
			# (each try counts for the copies on other machines)
			_presses += 1
	if (stage == Colossus.Press.PRESS or stage == Colossus.Press.DESCEND) and not _caught_this_press:
		for player: Node3D in players():
			if not huntable(player):
				continue
			var at := player.global_position
			if not clear_of_walls(at, WALL_COVER * 0.5) or covered(at):
				continue
			if figure.finger_hits(at + Vector3.UP * 0.5, catch_radius):
				_caught_this_press = true
				_catch(player)
	_press_stage = stage


## If it is near the rampart, away from its corners: stops, turns to it, rears
## up and leans on its top to look over into what it goes round. False if not.
func _start_peering() -> bool:
	if _rampart <= 0.0:
		return false
	var at := figure.pelvis()
	var x_side := absf(at.x) >= absf(at.z)
	var out := absf(at.x) if x_side else absf(at.z)
	var along := absf(at.z) if x_side else absf(at.x)
	if out - _rampart > peer_within or along > _rampart - 40.0:
		_peer_in = 6.0
		return false
	var inward := Vector3(-signf(at.x), 0.0, 0.0) if x_side else Vector3(0.0, 0.0, -signf(at.z))
	# (its hands a little way onto the top of the wall)
	var top := Vector3(at.x, _rampart_height, at.z) + inward * (out - _rampart + 6.0)
	mode = Mode.PEERING
	_peer_left = peer_time
	figure.lean_on = top
	figure.facing = atan2(inward.x, inward.z)
	figure.look_at_point = Vector3(0.0, 2.0, 0.0)
	return true


func _stop_peering() -> void:
	figure.lean_on = Vector3.INF
	figure.look_at_point = Vector3.INF
	mode = Mode.CRAWLING
	_peer_in = _rng.randf_range(peer_every.x, peer_every.y)
	_pause = 4.0


## A hand or foot has come down (on a wall top): whoever is on that wall top under it is crushed.
func _on_planted(limb: int, point: Vector3) -> void:
	if puppet:
		return
	for player: Node3D in players():
		if huntable(player) and absf(player.global_position.y - point.y) < 4.0 and figure.under_limb(limb, player.global_position):
			_catch(player)


## The pressing finger, where it is, to bump into (nothing when it is not down among the walls).
func _place_finger() -> void:
	var shape := _finger_body.get_child(0) as CollisionShape3D
	var capsule := figure.finger_capsule()
	shape.disabled = capsule.is_empty()
	if capsule.is_empty():
		return
	var a: Vector3 = capsule[0]
	var b: Vector3 = capsule[1]
	var radius: float = capsule[2]
	(shape.shape as CapsuleShape3D).radius = radius
	(shape.shape as CapsuleShape3D).height = maxf(a.distance_to(b) + radius * 2.0, radius * 2.0 + 0.01)
	_finger_body.global_transform = Transform3D(Colossus._along((b - a).normalized(), Vector3.RIGHT), (a + b) * 0.5)


func _process(_delta: float) -> void:
	# The ground shakes under whoever plays here.
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera:
		var shake := figure.shake_at(camera.global_position)
		if shake > 0.002:
			Colossus.rattle(camera, shake)
			_camera_shaken = true
		elif _camera_shaken:
			Colossus.rattle(camera, 0.0)
			_camera_shaken = false


# --- Being run by someone else -----------------------------------------------------

func yaw() -> float:
	return figure.body_yaw() if figure else rotation.y


func net_state() -> int:
	return mode


## Its moves (low four bits), the limb of the last (the next two), and its presses (the top two).
func net_flag() -> int:
	return (_steps & 0x0f) | ((_last_limb & 0x03) << 4) | ((_presses & 0x03) << 6)


## Where the limb in the air comes down, or what its finger is after, or where it leans.
func net_point() -> Vector3:
	if mode == Mode.PRESSING and figure.press_target.is_finite():
		return figure.press_target
	if mode == Mode.PEERING:
		return figure.lean_on
	var limb := figure.stepping()
	if limb >= 0:
		return figure.landing(limb)
	return Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode == Mode.PRESSING
	var steps := flag & 0x0f
	var limb := (flag >> 4) & 0x03
	var presses := (flag >> 6) & 0x03
	if _heard_steps >= 0 and steps != _heard_steps and point.is_finite() and mode != Mode.PRESSING:
		figure.step(limb, point, _limb_yaw(limb, facing), maxf(figure.landing(limb).y, point.y))
	if mode == Mode.PRESSING and point.is_finite():
		if _heard_presses >= 0 and presses != _heard_presses and not figure.pressing():
			figure.press(point, hall_along(point))
		figure.press_target = point
		figure.look_at_point = point
		figure.stoop = 1.0
	elif figure.pressing():
		figure.release()
		figure.stoop = 0.0
	figure.lean_on = point if mode == Mode.PEERING and point.is_finite() else Vector3.INF
	_heard_steps = steps
	_heard_presses = presses
	figure.facing = facing


func _puppet(_delta: float) -> void:
	global_position = Vector3(figure.pelvis().x, 0.0, figure.pelvis().z)
	_place_finger()


func _put(at: Vector3, facing: float) -> void:
	# (only far from where it should be: crouched there at once)
	if figure and Vector2(at.x - figure.pelvis().x, at.z - figure.pelvis().z).length() > 60.0:
		_stand(at, facing)


func _puppet_changed() -> void:
	collision_layer = 0
	collision_mask = 0

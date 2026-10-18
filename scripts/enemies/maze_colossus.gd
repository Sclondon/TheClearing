class_name MazeColossus
extends MazeEnemy
## The colossus (creatures/colossus/: a giant of weathered stone and fur, after
## Shadow of the Colossus) set to walk a ring of the maze: what the maze might
## have been built for. This is only its thinking; how it looks and moves is the
## `Colossus` component, which this drives.
##
## - IT WALKS THE RING. Far taller than the walls, it goes round its ring over
##   them, not through the passages: each foot is put down on the floor of a
##   hall, clear of the walls (`foothold`), and lifted over any wall in its way.
##   It never sets foot outside its ring, so it never comes into the clearing,
##   though from the clearing its head can be seen over the wall.
## - ITS FEET CRUSH. A foot's shadow grows on the ground where it will come
##   down, dust and stones fall from it, a rumble rises; whoever is under it
##   when it lands is caught. A foot never comes down near a wall, so the foot
##   of a wall is safe. Its legs block a hall while they stand in it.
## - IT SEES FROM ABOVE. Whoever is out in the open in front of it, within
##   `sense_range`, is seen: not whoever is in a slot or pressed to the foot of
##   a wall (`hidden`), under a ledge, a bridge or anything else overhead, or
##   behind a wall from where its eyes are. Standing still halves how far it
##   sees. And it feels the ground: anyone running hard near one of its feet
##   makes it stop and look round (LISTENING) for `listen_time`.
## - IT REACHES. Someone seen within reach (`reach_band`, as shares of its
##   height, from its middle) and it stops, bends, holds its great hand over
##   them (following them, slowly), strikes down and sweeps it along the hall:
##   whoever is under the hand then is caught. Into a slot, a side passage,
##   under a ledge or flat against a wall, and the hand cannot get them. Seen
##   out of reach, it turns and walks towards them.
## - IT LOOKS OVER THE WALL. Now and then, going along the great wall round the
##   inside of its ring (the rampart round the clearing), it stops, turns to it,
##   straightens up and leans its hands on its top (PEERING) for `peer_time`,
##   its head and the pale light of its eyes over the wall: a sight from the
##   clearing.
##
## Online, the host thinks for it and the others' copies are puppets: each step
## (which foot, and where it comes down) and each reach is sent with its state
## (`net_flag`, `net_point`) and played out here as there. Catching is the host's.
##
## Spawn (as MazeEnemies.add does): `MazeColossus.new()`, set `maze`, place it and
## turn it (rotation.y, 0 faces +Z), add it to the tree. It stands where it is put
## (on footholds as near to it as there are, in that ring).

enum Mode { WALKING, LISTENING, REACHING, PEERING }

## How tall it is, metres.
const HEIGHT := 120.0
## How far from a wall's face a foot must come down, and a hand, metres.
const FOOT_MARGIN := 1.4
const HAND_MARGIN := 3.6
## How near the face of a wall someone must be to be hidden from it there (and under its hand), metres.
const WALL_COVER := 1.3

## How far off (flat, from its middle) it sees anyone in the open, metres.
@export var sense_range := 110.0
## How near one of its feet someone running hard makes it stop and look, metres,
## and how fast is running hard (metres a second).
@export var feel_range := 40.0
@export var feel_speed := 4.6
@export var listen_time := 4.0
## Where it can reach, as shares of its height from its middle (flat): nearer
## than the first it walks back a little; further than the second, it walks closer.
@export var reach_band := Vector2(0.17, 0.4)
## How soon after one reach it can reach again, seconds.
@export var reach_every := 8.0
## How near the palm (beyond the hand's own size) someone is caught, metres.
@export var catch_radius := 2.2
## A pause between steps, seconds.
@export var step_pause := 0.25
## How long it looks over the great wall, and how long (at least, and at most)
## between, seconds; and how near the wall its middle must be to (metres).
@export var peer_time := 16.0
@export var peer_every := Vector2(45.0, 110.0)
@export var peer_within := 34.0
## How far it means to go with each step (a share of its stride).
@export var stride_share := 0.9

var mode := Mode.WALKING
## The figure it drives.
var figure: Colossus
## The ring it walks.
var ring := 1

var _heading := 0.0
var _goal := Vector3.INF
var _round_way := 1.0
var _pause := 0.0
var _listen := 0.0
var _reach_in := 0.0
var _reach_for: Node3D
var _caught_in_reach := false
var _steps := 0
var _reaches := 0
var _last_step_foot := 1
var _colliders: Array[AnimatableBody3D] = []
var _seen_at := {}
var _speeds := {}
var _camera_shaken := false
var _heard_steps := -1
var _heard_reaches := -1
var _inner := 0.0
var _outer := 0.0
## How far out the outer face of the rampart round the inside of its ring is
## (as the walls go round), and how high it is; 0 if it has none.
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
	if maze and not keep_out_of_clearing and maze.in_clearing(maze.cell_at(global_position)):
		ring = 0
	_ring_bounds()
	_round_way = 1.0 if _rng.randf() < 0.5 else -1.0
	_peer_in = _rng.randf_range(10.0, peer_every.x)
	figure = Colossus.new()
	figure.height = HEIGHT
	# (the low-poly model on phones: a quarter of the triangles)
	figure.low_poly = Settings.low_poly or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	figure.footfall.connect(_on_footfall)
	add_child(figure)
	figure.top_level = true
	_heading = rotation.y
	_stand(global_position, _heading)
	for k in 6:
		var body := AnimatableBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.sync_to_physics = false
		var shape := CollisionShape3D.new()
		shape.shape = CapsuleShape3D.new()
		body.add_child(shape)
		add_child(body)
		body.top_level = true
		_colliders.append(body)
	_place_colliders()


## How far out (as the walls go round, the larger of x and z from the middle)
## its ring runs, metres: its footholds are between.
func _ring_bounds() -> void:
	if ring <= 0:
		_inner = 0.0
		_outer = maze.clearing * Maze.CELL * 0.5
		return
	var middle := (maze.size - 1) / 2
	_inner = INF
	_outer = 0.0
	for i in maze.size:
		var cell := Vector2i(i, middle)
		if maze.ring_of(cell) == ring and not maze.solid.has(cell):
			var out := absf(maze.world(cell).x)
			_inner = minf(_inner, out)
			_outer = maxf(_outer, out)
	if _inner == INF:
		_inner = 0.0
		_outer = maze.extent() * 0.5
	var style: MazeStyle = maze.styles[ring - 1] if ring <= maze.styles.size() else null
	if style and style.border_wall_thickness_cells > 0 and not maze.gates[ring - 1].is_empty():
		var way: Array = maze.gates[ring - 1][0]
		var thick := maze.wall_thick(way[0], way[1])
		_rampart = maze.ring_sizes[ring - 1] * Maze.CELL * 0.5 + thick * 0.5 + style.border_wall_thickness_cells * Maze.CELL
		_rampart_height = style.section_border_wall_height


## Puts it standing near `at`, facing `yaw`, on the nearest footholds.
func _stand(at: Vector3, yaw: float) -> void:
	var left := Basis(Vector3.UP, yaw).x
	var apart := 0.62 * figure.scale_m()
	var spots: Array[Vector3] = []
	var yaws: Array[float] = []
	for foot in 2:
		var want := at + left * apart * (1.0 if foot == 0 else -1.0)
		var found := _nearest_foothold(want, yaw, 40.0)
		if found.is_empty():
			found = _nearest_foothold(at, yaw, 90.0)
		if found.is_empty():
			found = [want, yaw]
		spots.append(found[0])
		yaws.append(found[1])
	figure.put((spots[0] + spots[1]) * 0.5, yaw)
	for foot in 2:
		figure.plant(foot, spots[foot], yaws[foot])
	_pick_goal()


# --- Where it may stand ---------------------------------------------------------

## Whether a foot may come down with its ankle over `point`, turned `yaw`:
## every part of its print in its ring, on a floor, `FOOT_MARGIN` clear of
## every wall.
func foothold(point: Vector3, yaw: float) -> bool:
	var basis := Basis(Vector3.UP, yaw)
	var size := figure.print_size()
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(0, 0), Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		var z := -size.y if c.y < 0.0 else (size.z if c.y > 0.0 else (size.z - size.y) * 0.5)
		var p := point + basis * Vector3(c.x * size.x, 0.0, z)
		if not _floor(p, FOOT_MARGIN):
			return false
	return true


## Whether `point` is on the floor of its ring (or anywhere it may be put, for
## the dev tools), at least `margin` from the face of every wall.
func _floor(point: Vector3, margin: float) -> bool:
	var cell := maze.cell_at(point)
	if not maze.inside(cell) or maze.solid.has(cell):
		return false
	if maze.ring_of(cell) != ring and not (ring == 0 and not keep_out_of_clearing):
		return false
	if keep_out_of_clearing and maze.in_clearing(cell):
		return false
	return clear_of_walls(point, margin)


## Whether a point is at least `margin` from the face of every wall, by the plan,
## each wall as thick as it really is (Maze.wall_thick); near where walls meet,
## the corner between them counts.
func clear_of_walls(point: Vector3, margin: float) -> bool:
	var cell := maze.cell_at(point)
	if not maze.inside(cell):
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
	var thick := maze.wall_thick(cell, Vector2i(sx, 0))
	var corner := half - thick * 0.5 - margin
	if absf(off.x) > corner and absf(off.y) > corner:
		if (maze.inside(side) and maze.blocked(side, Vector2i(0, sy))) or (maze.inside(below) and maze.blocked(below, Vector2i(sx, 0))):
			return false
	return true


## The nearest foothold to `want` within `within` metres, as [point, yaw], or [].
## Turned `yaw` if it fits so, else square to the walls.
func _nearest_foothold(want: Vector3, yaw: float, within: float) -> Array:
	var yaws := _yaws_for(yaw)
	var ring_step := 2.5
	var r := 0.0
	while r <= within:
		var count := 1 if r == 0.0 else maxi(6, int(TAU * r / ring_step))
		var best: Array = []
		var best_score := INF
		for k in count:
			var a := TAU * k / count
			var p := want + Vector3(cos(a), 0.0, sin(a)) * r
			p.y = maze.ground_height(p)
			for y: float in yaws:
				if foothold(p, y):
					var score := absf(wrapf(y - yaw, -PI, PI)) * 4.0
					if score < best_score:
						best_score = score
						best = [p, y]
					break
		if not best.is_empty():
			return best
		r += ring_step
	return []


## The ways a foot may be turned, the way wanted first, then square to the walls.
static func _yaws_for(yaw: float) -> Array[float]:
	var out: Array[float] = [yaw]
	var square := snappedf(yaw, PI * 0.5)
	out.append(square)
	out.append(square + PI * 0.5)
	out.append(square - PI * 0.5)
	return out


## How high a foot must be lifted to go from `a` to `b`: the highest wall
## near the way between them (world height), or -INF for none.
func clearance(a: Vector3, b: Vector3) -> float:
	var top := -INF
	var flat := Vector2(b.x - a.x, b.z - a.z)
	var count := maxi(int(flat.length() / 2.0), 1)
	# (as wide as the foot either side of the line its ankle goes along)
	var reach := figure.print_size().x * 0.9
	for k in count + 1:
		var p := a.lerp(b, float(k) / count)
		if clear_of_walls(p, reach):
			continue
		var cell := maze.cell_at(p)
		if maze.solid.has(cell) or not maze.inside(cell):
			top = maxf(top, maze.inner_height(maxi(maze.ring_of(cell), 1)))
			continue
		for step: Vector2i in Maze.STEPS:
			if maze.blocked(cell, step):
				top = maxf(top, maze.wall_height(cell, step))
	return top


# --- Thinking ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if puppet:
		_puppet(delta)
		return
	if maze == null:
		return
	_reach_in -= delta
	_peer_in -= delta
	_watch(delta)
	match mode:
		Mode.WALKING:
			_walk(delta)
		Mode.LISTENING:
			_listen -= delta
			if _listen <= 0.0:
				mode = Mode.WALKING
		Mode.REACHING:
			_reaching()
		Mode.PEERING:
			_peer_left -= delta
			if _peer_left <= 0.0:
				_stop_peering()
	chasing = mode == Mode.REACHING or (quarry != null and hunting())
	figure.glow = 2.4 if mode != Mode.WALKING or hunting() else 1.4
	var at := figure.pelvis()
	var moved := Vector3(at.x, maze.ground_height(at), at.z)
	velocity = (moved - global_position) / maxf(delta, 0.001)
	global_position = moved
	_place_colliders()


## Steps on: towards its goal round the ring (or towards whoever it has seen, out of reach).
func _walk(delta: float) -> void:
	if figure.stepping() >= 0:
		return
	_pause -= delta
	if _pause > 0.0:
		return
	var at := figure.pelvis()
	var goal := _goal
	if not hunting() and _peer_in <= 0.0 and _start_peering():
		return
	if hunting() and quarry:
		goal = quarry.global_position
	elif not _goal.is_finite() or Vector2(_goal.x - at.x, _goal.z - at.z).length() < 40.0:
		_pick_goal()
		goal = _goal
	var to := goal - at
	_heading = atan2(to.x, to.z)
	figure.facing = _heading
	if not _step_towards(_heading):
		# (nowhere to go that way: try round about, and if all else fails a new goal)
		for turn: float in [0.5, -0.5, 1.0, -1.0, 1.6, -1.6, 2.4, -2.4]:
			if _step_towards(_heading + turn):
				return
		_pick_goal()
		_pause = 1.0


## Takes the next step (the foot behind) about `yaw`'s way. False if there is nowhere to put it.
func _step_towards(yaw: float) -> bool:
	var basis := Basis(Vector3.UP, yaw)
	var ahead := basis.z
	var left := basis.x
	var s := figure.scale_m()
	var feet: Array[Vector3] = [figure.landing(0), figure.landing(1)]
	# (the foot further behind goes; if neither, the other one from last time)
	var foot := 1 - _last_step_foot
	var behind0 := (feet[0] - figure.pelvis()).dot(ahead)
	var behind1 := (feet[1] - figure.pelvis()).dot(ahead)
	if absf(behind0 - behind1) > 4.0:
		foot = 0 if behind0 < behind1 else 1
	var stand: Vector3 = feet[1 - foot]
	var side := 1.0 if foot == 0 else -1.0
	var stride := figure.stride() * stride_share
	var want := stand + ahead * stride * 0.62 + left * side * 0.62 * s
	var best: Array = []
	var best_score := INF
	for r: float in [0.0, 3.0, 6.0, 9.0, 12.0, 15.0, 18.0]:
		var count := 1 if r == 0.0 else 10
		for k in count:
			var a := TAU * k / count
			var p := want + Vector3(cos(a), 0.0, sin(a)) * r
			p.y = maze.ground_height(p)
			var from_stand := p - stand
			var apart := Vector2(from_stand.x, from_stand.z).length()
			# (not too near the other foot, nor too far; never across in front of it; never back)
			if apart < 0.75 * s or apart > figure.stride():
				continue
			if from_stand.dot(left) * side < 0.3 * s:
				continue
			if from_stand.dot(ahead) < 0.0:
				continue
			for y: float in _yaws_for(yaw):
				if foothold(p, y):
					var score := r + absf(wrapf(y - yaw, -PI, PI)) * 6.0
					if score < best_score:
						best_score = score
						best = [p, y]
					break
		if not best.is_empty() and r >= 6.0:
			break
	if best.is_empty():
		return false
	var from := figure.landing(foot)
	figure.step(foot, best[0], best[1], clearance(from, best[0]))
	_last_step_foot = foot
	_steps += 1
	_pause = step_pause
	return true


## Somewhere further round the ring to walk to.
func _pick_goal() -> void:
	var at := figure.pelvis() if figure else global_position
	var angle := atan2(at.z, at.x) + _round_way * _rng.randf_range(0.25, 0.45)
	var depth := _rng.randf_range(_inner + 10.0, maxf(_outer - 10.0, _inner + 10.0))
	var round_dir := Vector3(cos(angle), 0.0, sin(angle))
	var square := maxf(absf(round_dir.x), absf(round_dir.z))
	_goal = round_dir * depth / square
	if ring == 0:
		_goal = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)) * _outer * 0.6


## Looks for anyone in the open, and feels for anyone running near its feet.
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
		var last: Vector3 = _speeds.get(player, at)
		var speed := Vector2(at.x - last.x, at.z - last.z).length() / 0.3
		_speeds[player] = at
		var flat := Vector2(at.x - middle.x, at.z - middle.z)
		# (nobody in the clearing: it is no part of its ring)
		if maze.in_clearing(maze.cell_at(at)) and ring != 0:
			continue
		# The ground shakes under someone running hard near a foot: it stops to look.
		var grounded := at.y - maze.ground_height(at) < 1.0
		if mode == Mode.WALKING and speed > feel_speed and grounded:
			for foot in 2:
				if figure.landing(foot).distance_to(at) < feel_range and figure.stepping() != foot:
					mode = Mode.LISTENING
					_listen = listen_time
					figure.look_at_point = at
					break
		var range_now := sense_range * (2.0 if mode == Mode.LISTENING else 1.0) * (1.0 if speed > 0.6 else 0.5)
		if flat.length() > range_now:
			continue
		var ahead := facing.dot(Vector3(flat.x, 0.0, flat.y).normalized())
		if mode != Mode.LISTENING and ahead < -0.25 and flat.length() > 25.0:
			continue
		if hidden(player, eye):
			continue
		if flat.length() < best_d:
			best_d = flat.length()
			best = player
	if best:
		notice(best)
		figure.look_at_point = best.global_position + Vector3.UP
		if mode != Mode.REACHING and _reach_in <= 0.0 and figure.stepping() < 0:
			var reach := figure.height * reach_band
			if best_d > reach.x and best_d < reach.y and hand_spot(best.global_position).is_finite():
				_start_reach(best)
	elif mode == Mode.WALKING:
		figure.look_at_point = Vector3.INF if not hunting() else quarry.global_position


## Whether someone is out of its sight from `eye`: in a slot or flat against a
## wall, under anything (a ledge, a bridge, a pipe), or behind a wall.
func hidden(player: Node3D, eye: Vector3) -> bool:
	var at := player.global_position
	if not clear_of_walls(at, WALL_COVER):
		return true
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	for body in _colliders:
		exclude.append(body.get_rid())
	if player is CollisionObject3D:
		exclude.append((player as CollisionObject3D).get_rid())
	var chest := at + Vector3.UP * 1.0
	var above := PhysicsRayQueryParameters3D.create(chest, chest + Vector3.UP * 40.0, 1, exclude)
	if not space.intersect_ray(above).is_empty():
		return true
	var sight := PhysicsRayQueryParameters3D.create(eye, chest, 1, exclude)
	return not space.intersect_ray(sight).is_empty()


## Where its hand comes down for someone at `at`: as near as it can be with the
## hand clear of the walls (it cannot get into a slot, nor right up to a wall).
## INF if there is nowhere near (they are in a slot, or out of its ring).
func hand_spot(at: Vector3) -> Vector3:
	if _floor(at, HAND_MARGIN):
		return at
	for r: float in [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]:
		for k in 12:
			var a := TAU * k / 12.0
			var p := at + Vector3(cos(a), 0.0, sin(a)) * r
			if _floor(p, HAND_MARGIN):
				p.y = at.y
				return p
	return Vector3.INF


## If it is beside the rampart, away from its corners: stops, turns to it and
## leans on its top to look over into what it goes round. False if not.
func _start_peering() -> bool:
	if _rampart <= 0.0 or ring < 1:
		return false
	var at := figure.pelvis()
	var x_side := absf(at.x) >= absf(at.z)
	var out := absf(at.x) if x_side else absf(at.z)
	var along := absf(at.z) if x_side else absf(at.x)
	if out - _rampart > peer_within or along > _rampart - 30.0:
		_peer_in = 6.0
		return false
	var inward := Vector3(-signf(at.x), 0.0, 0.0) if x_side else Vector3(0.0, 0.0, -signf(at.z))
	# (its hands a little way onto the top of the wall)
	var top := Vector3(at.x, _rampart_height, at.z) + inward * (out - _rampart + 5.0)
	mode = Mode.PEERING
	_peer_left = peer_time
	figure.lean_on = top
	figure.facing = atan2(inward.x, inward.z)
	figure.look_at_point = Vector3(0.0, 0.0, 0.0) + Vector3.UP * 2.0
	return true


func _stop_peering() -> void:
	figure.lean_on = Vector3.INF
	figure.look_at_point = Vector3.INF
	mode = Mode.WALKING
	_peer_in = _rng.randf_range(peer_every.x, peer_every.y)
	# (time to straighten up before it walks on)
	_pause = 3.0


func _start_reach(player: Node3D) -> void:
	if mode == Mode.PEERING:
		figure.lean_on = Vector3.INF
	mode = Mode.REACHING
	_reach_for = player
	_caught_in_reach = false
	_reaches += 1
	figure.reach(hand_spot(player.global_position))


func _reaching() -> void:
	if not figure.reaching():
		mode = Mode.WALKING
		_reach_in = reach_every
		_reach_for = null
		_pause = 0.8
		return
	var stage := figure.reach_stage()
	if stage == Colossus.Reach.BEND or stage == Colossus.Reach.HOVER:
		# (it follows whoever it is after as long as it can see them)
		if is_instance_valid(_reach_for) and huntable(_reach_for) and not hidden(_reach_for, figure.eye()):
			var spot := hand_spot(_reach_for.global_position)
			if spot.is_finite():
				figure.reach_target = spot
	elif (stage == Colossus.Reach.STRIKE or stage == Colossus.Reach.SWEEP) and not _caught_in_reach:
		for player: Node3D in players():
			if not huntable(player):
				continue
			var at := player.global_position
			if not clear_of_walls(at, WALL_COVER * 0.5):
				continue
			if figure.hand_hits(at + Vector3.UP * 0.5, catch_radius) and not _covered(at):
				_caught_in_reach = true
				_catch(player)


## Whether something is over someone (a ledge, a bridge): the hand cannot get under it.
func _covered(at: Vector3) -> bool:
	var exclude: Array[RID] = []
	for body in _colliders:
		exclude.append(body.get_rid())
	var chest := at + Vector3.UP * 1.0
	var above := PhysicsRayQueryParameters3D.create(chest, chest + Vector3.UP * 25.0, 1, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(above)
	return not hit.is_empty()


## A foot has come down: whoever is under it is crushed (the host's to say).
func _on_footfall(foot: int, point: Vector3) -> void:
	if puppet:
		return
	for player: Node3D in players():
		if not huntable(player):
			continue
		var at := player.global_position
		if at.y < point.y + 4.0 and figure.under_foot(foot, at, 0.3):
			_catch(player)


## Its legs, where they stand, as things to bump into.
func _place_colliders() -> void:
	var capsules := figure.leg_capsules()
	for k in mini(capsules.size(), _colliders.size()):
		var one: Array = capsules[k]
		var a: Vector3 = one[0]
		var b: Vector3 = one[1]
		var radius: float = one[2]
		var shape := _colliders[k].get_child(0) as CollisionShape3D
		var capsule := shape.shape as CapsuleShape3D
		capsule.radius = radius
		capsule.height = maxf(a.distance_to(b) + radius * 2.0, radius * 2.0 + 0.01)
		var up := (b - a).normalized()
		_colliders[k].global_transform = Transform3D(Colossus._along(up, Vector3.RIGHT), (a + b) * 0.5)


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


# --- Being run by someone else ---------------------------------------------------

func yaw() -> float:
	return figure.body_yaw() if figure else rotation.y


func net_state() -> int:
	return mode


## Its steps (low four bits), the foot of the last (the next bit), and its reaches (the top three).
func net_flag() -> int:
	return (_steps & 0x0f) | (_last_step_foot << 4) | ((_reaches & 0x07) << 5)


## Where the foot under way comes down, or what its hand is after.
func net_point() -> Vector3:
	if mode == Mode.REACHING and figure.reach_target.is_finite():
		return figure.reach_target
	if mode == Mode.PEERING:
		return figure.lean_on
	var foot := figure.stepping()
	if foot >= 0:
		return figure.landing(foot)
	return Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode == Mode.REACHING
	var steps := flag & 0x0f
	var foot := (flag >> 4) & 0x01
	var reaches := (flag >> 5) & 0x07
	if _heard_steps >= 0 and steps != _heard_steps and point.is_finite() and mode != Mode.REACHING:
		var yaw_now := facing
		var best_yaw := yaw_now
		for y: float in _yaws_for(yaw_now):
			if foothold(point, y):
				best_yaw = y
				break
		figure.step(foot, point, best_yaw, clearance(figure.landing(foot), point))
	if _heard_reaches >= 0 and reaches != _heard_reaches and point.is_finite():
		figure.reach(point)
	elif mode == Mode.REACHING and point.is_finite():
		figure.reach_target = point
	figure.lean_on = point if mode == Mode.PEERING and point.is_finite() else Vector3.INF
	_heard_steps = steps
	_heard_reaches = reaches
	figure.facing = facing


func _puppet(_delta: float) -> void:
	global_position = Vector3(figure.pelvis().x, 0.0, figure.pelvis().z)
	_place_colliders()


func _put(at: Vector3, facing: float) -> void:
	# (only far from where it should be: stood there at once)
	if figure and Vector2(at.x - figure.pelvis().x, at.z - figure.pelvis().z).length() > 40.0:
		_stand(at, facing)


func _puppet_changed() -> void:
	collision_layer = 0
	collision_mask = 0

class_name MazeGargoyle
extends MazeEnemy
## A gargoyle (creatures/gargoyle: Gargoyle), set to hunt the maze. How it
## looks and moves is the creature's; this is only its thinking.
##
## - IT WAITS AS A STATUE on a ledge over a hall: the edge of a terrace if there
##   is one beside where it is put, else the top of the wall if that is low
##   enough to be seen from the hall (`TOP_HIGHEST`), else a stone corbel jutting
##   from the wall's face 8 to 11.5 m up (`CORBEL_HIGH`; built here, of the
##   wall's own concrete, as gargoyles are set on walls); out of the ivy and
##   the hanging vines. It crouches at the very edge facing out over the hall,
##   its wings raised behind it, perfectly still. Stone, it cannot be told from
##   a carving. (Put where there is no wall to sit on, or with `seek_perch` off,
##   it crouches on the ground instead, and wakes when someone comes near.) It
##   finds its ledge itself, by rays, the first moment it is in the world (on
##   every machine alike, so a puppet has its corbel too).
## - IT STIRS when someone passes beneath it (within `DROP_RANGE` of the foot of
##   its wall, and in its sight): the ember kindles in its cracks and eyes, its
##   head grinds round to follow them with a sound of stone on stone, dust
##   trickles off it (`STIR_TIME`): the warning.
## - IT DROPS on them: off the ledge, wings spread, in a long glide down to
##   where they were going to be when it let go, steering only a little after
##   them as it falls; its shadow darkens on the ground where it will land. It
##   lands with a crash and a cloud of stone dust, and has them if they are
##   still under it (`CATCH_RADIUS`). Anyone who keeps moving, and above all
##   anyone who turns aside, is not there when it lands.
## - A MISS TURNS IT TO STONE where it landed, for `STONE_TIME` seconds: the
##   time to get away. Then it hunts.
## - IT HUNTS on foot, in heavy lurching bounds a little slower than a run, and
##   it is slow to turn (`TURN_RATE`): it goes where it faces, so a turn down a
##   side passage or round it gains ground. When it is facing them from a few
##   metres off (`LEAP_RANGE`), it crouches, raises its wings and snarls
##   (`GATHER_TIME`, its shadow already on the ground where it means to land)
##   and leaps at them in a short glide. A miss turns it to stone again.
## - LOSING THEM (`memory`), it goes back to the foot of its wall, beats up to
##   its ledge (`CLIMB_SPEED`) and turns to stone there.
##
## Online, the host's thinks; a puppet follows its news (MazeEnemy): where it
## is, what it is doing (which says how it is posed: stone or not, perched, in
## the air), its landings and snarls (counts in the flag), and the point it
## will land on (for its shadow).
##
## Spawn (as MazeEnemies does any MazeEnemy): `MazeGargoyle.new()`, `maze` set,
## put in a hall cell beside a wall, added to the scene.

## What it is doing, as sent (`net_state`).
enum Mode { PERCH, STIR, DIVE, HUNT, GATHER, LEAP, STONE, RETURN, CLIMB }

## The highest wall top it will wait on (higher, it is too far up to be seen):
## else it waits on a corbel jutting from the wall's face, this high (least,
## most), this far out.
const TOP_HIGHEST := 16.0
const CORBEL_HIGH := Vector2(8.0, 11.5)
const CORBEL_DEPTH := 1.5
## How near the foot of its ledge (along the ground) someone must pass to wake it.
const DROP_RANGE := 13.0
## On the ground, as a statue: how near someone must come.
const WAKE_RANGE := 9.0
## Seconds it stirs before it drops (the warning).
const STIR_TIME := 1.3
## The drop: how fast it glides down (m/s along the way), how much it steers
## after them as it falls (m/s), and how far ahead of them it aims (seconds of
## their going, at most).
const DIVE_SPEED := 10.0
const STEER := 1.6
const LEAD := 0.35
## The leap from the ground: how far it will leap from (least, most), how high,
## and how long its wind-up is.
const LEAP_RANGE := Vector2(3.5, 10.0)
const LEAP_SPEED := 10.0
const GATHER_TIME := 0.8
## How near the middle of where it lands they must be to be caught.
const CATCH_RADIUS := 1.5
## Seconds it stays stone after a miss.
const STONE_TIME := 3.6
## Its bounds (the boy runs at 4.4 and sprints at 5.6), how fast it can turn
## (radians a second), and how fast it beats up to its ledge.
const BOUND_SPEED := 4.0
const TURN_RATE := 1.4
const CLIMB_SPEED := 4.5
const ACCELERATION := 7.0
const RADIUS := 0.55
## The walls are square to the axes.
const FACES: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]

@export var gravity := 24.0
## Further than this from every player it is not posed or drawn.
@export var pose_range := 110.0
## Looks for a ledge to sit on (else it crouches on the ground where it is put).
@export var seek_perch := true

var mode := Mode.PERCH
## The creature.
var look: Gargoyle
## Where it waits (on its ledge, or on the ground), the way it faces there, and
## the foot of its wall (the ground under the ledge's edge, out in the hall).
var perch := Vector3.INF
var perch_out := Vector3.FORWARD
var perch_foot := Vector3.INF
## Where it means to land (a drop or a leap), INF for nowhere.
var landing := Vector3.INF

var _mode_time := 0.0
var _heading := Vector3.FORWARD
var _from := Vector3.ZERO
var _flight := 1.0
var _arc := 0.0
var _placed := false
var _on_ground_perch := false
var _slams := 0
var _snarls := 0
var _heard_slams := -1
var _heard_snarls := -1
var _check_in := 0.0
var _far := false
var _far_check := 0.0
var _stuck := 0.0
var _corbel := Vector3.INF


func _init() -> void:
	# (it sees a long way down the halls from its ledge, and hears little: it
	# is stone. It forgets soon, and goes back up.)
	sight_range = 36.0
	hear_range = 6.0
	memory = 10.0
	alert_range = 0.0
	pack = &"gargoyles"


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = 0 if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.4
	var shape := CapsuleShape3D.new()
	shape.radius = RADIUS
	shape.height = 1.6
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.8
	add_child(collider)
	look = Gargoyle.new()
	look.name = "Look"
	look.top_level = true
	look.seed_value = _rng.seed % 1000 if _rng.seed > 0 else 0
	look.low_poly = Settings.low_poly or Mummy.low_poly
	add_child(look)
	_heading = Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	look.global_position = global_position
	look.rotation.y = rotation.y
	look.perched = true
	look.settle()


# --- Thinking ---

func _physics_process(delta: float) -> void:
	_cull(delta)
	if puppet:
		if not _placed and maze:
			# (its ledge, and any corbel, are found on every machine alike)
			_placed = true
			_find_perch()
		_follow_heard(delta)
		_pose()
		return
	if maze == null:
		return
	if not _placed:
		_placed = true
		_find_perch()
		_settle_on_perch()
	_mode_time += delta
	_sense(delta)
	var before := global_position
	match mode:
		Mode.PERCH:
			velocity = Vector3.ZERO
			_watch(delta)
		Mode.STIR:
			_stir()
		Mode.DIVE, Mode.LEAP:
			_fly(delta)
		Mode.HUNT:
			_hunt(delta)
		Mode.GATHER:
			_gather(delta)
		Mode.STONE:
			velocity = Vector3.ZERO
			if _mode_time >= STONE_TIME:
				_enter(Mode.HUNT if hunting() else Mode.RETURN)
		Mode.RETURN:
			_return(delta)
		Mode.CLIMB:
			_climb(delta)
	chasing = mode in [Mode.STIR, Mode.DIVE, Mode.HUNT, Mode.GATHER, Mode.LEAP]
	if mode in [Mode.PERCH, Mode.STIR, Mode.DIVE, Mode.LEAP, Mode.CLIMB, Mode.STONE]:
		# (moved by hand there: its speed, for the others to follow)
		velocity = (global_position - before) / delta
	_pose()


func _enter(next: Mode) -> void:
	mode = next
	_mode_time = 0.0
	if next == Mode.STIR:
		_snarls += 1
		if look:
			look.snarl()


## Looks for someone passing under its ledge (or, on the ground, coming near).
func _watch(delta: float) -> void:
	_check_in -= delta
	if _check_in > 0.0:
		return
	_check_in = 0.2
	var found := _under_me()
	if found:
		notice(found)
		_enter(Mode.STIR)


## Someone to drop on: under the ledge within DROP_RANGE of its foot, below it,
## in sight. (On the ground: within WAKE_RANGE, in sight.)
func _under_me() -> Node3D:
	# (seen from the hall floor under it: whether they are in the same stretch of
	# hall, not behind a wall; bridges and vines strung across the hall high up
	# would hide them from the ledge itself)
	var eye := perch_foot + Vector3.UP * 1.5
	var best: Node3D = null
	var nearest := INF
	for player: Node3D in players():
		if not huntable(player):
			continue
		var at := player.global_position
		var d := Vector2(at.x - perch_foot.x, at.z - perch_foot.z).length()
		var reach := WAKE_RANGE if _on_ground_perch else DROP_RANGE
		if d > reach or (not _on_ground_perch and at.y > perch.y - 2.0):
			continue
		if not _clear_line(eye, at + Vector3.UP * 1.0):
			continue
		if d < nearest:
			nearest = d
			best = player
	return best


func _stir() -> void:
	velocity = Vector3.ZERO
	if quarry == null or not huntable(quarry):
		_settle_on_perch()
		return
	var at := quarry.global_position
	var d := Vector2(at.x - perch_foot.x, at.z - perch_foot.z).length()
	if d > (WAKE_RANGE if _on_ground_perch else DROP_RANGE) * 1.6:
		# (gone by: back to stone)
		_settle_on_perch()
		return
	if _mode_time < STIR_TIME:
		return
	if _on_ground_perch:
		_heading = _flat(at - global_position).normalized() if _flat(at - global_position).length() > 0.1 else _heading
		_enter(Mode.HUNT)
		return
	_launch(Mode.DIVE)


## Leaves the ground or its ledge for where it means to land: where they will
## be, a little ahead of where they are going.
func _launch(kind: Mode) -> void:
	var at := quarry.global_position
	var going := _flat(quarry.get(&"velocity") if quarry.get(&"velocity") is Vector3 else Vector3.ZERO)
	landing = Vector3(at.x, maze.ground_height(at), at.z) + going * LEAD
	landing = _clear_landing(global_position, landing)
	_from = global_position
	var span := _from.distance_to(landing)
	if kind == Mode.DIVE:
		_flight = clampf(span / DIVE_SPEED, 1.0, 3.0)
		_arc = 0.8
	else:
		_flight = clampf(span / LEAP_SPEED, 0.5, 1.05)
		_arc = 1.0 + span * 0.12
	var flat := _flat(landing - _from)
	if flat.length() > 0.1:
		_heading = flat.normalized()
	_enter(kind)


## Gliding down (or leaping) to `landing`, steering a little after them.
func _fly(delta: float) -> void:
	var t := clampf(_mode_time / _flight, 0.0, 1.0)
	if quarry and huntable(quarry):
		var at := quarry.global_position
		var want := Vector3(at.x, landing.y, at.z)
		landing = landing.move_toward(want, STEER * delta)
	# Down a curve: off the ledge and out, then a long glide, eased in at the end.
	var eased := t * t * (3.0 - 2.0 * t) if mode == Mode.LEAP else 1.0 - pow(1.0 - t, 1.6)
	var along := _from.lerp(landing, lerpf(t, eased, 0.6))
	var height := lerpf(_from.y, landing.y, (t * t) if mode == Mode.DIVE else t) + _arc * 4.0 * t * (1.0 - t)
	var next := Vector3(along.x, height, along.z)
	var flat := _flat(next - global_position)
	if flat.length() > 0.01:
		_heading = _heading.slerp(flat.normalized(), 1.0 - exp(-6.0 * delta)).normalized()
	global_position = next
	if t >= 1.0:
		_land()


func _land() -> void:
	global_position = landing
	_slams += 1
	if look:
		look.slam()
	var got := false
	for player: Node3D in players():
		if not huntable(player):
			continue
		var at := player.global_position
		if Vector2(at.x - landing.x, at.z - landing.z).length() < CATCH_RADIUS and absf(at.y - landing.y) < 1.8:
			_catch(player)
			got = true
			break
	landing = Vector3.INF
	velocity = Vector3.ZERO
	# Caught or missed, it turns to stone where it landed for a while.
	_enter(Mode.STONE)
	if got:
		_mode_time = -1.0


func _hunt(delta: float) -> void:
	if not hunting():
		_enter(Mode.RETURN)
		return
	var to := quarry.global_position - global_position
	var flat := _flat(to)
	var way_to := _way_to(goal())
	# It goes where it faces, turning slowly.
	_turn_toward(way_to if way_to.length() > 0.05 else flat, delta, TURN_RATE)
	var facing := _heading.dot(flat.normalized()) if flat.length() > 0.1 else 1.0
	var level := absf(to.y) < 1.5
	if level and flat.length() > LEAP_RANGE.x and flat.length() < LEAP_RANGE.y and facing > 0.93 and is_on_floor() \
			and _clear_line(global_position + Vector3.UP * 1.0, quarry.global_position + Vector3.UP * 1.0):
		_enter(Mode.GATHER)
		if look:
			look.gather(GATHER_TIME)
		return
	var ahead := clampf((_heading.dot(way_to.normalized()) if way_to.length() > 0.05 else 0.0), 0.0, 1.0)
	_move(delta, _heading * BOUND_SPEED * smoothstep(0.3, 0.9, ahead))


## The wind-up: it keeps turning to them, slowly, and marks where it will land.
func _gather(delta: float) -> void:
	_move(delta, Vector3.ZERO)
	if quarry == null or not huntable(quarry):
		_enter(Mode.RETURN)
		return
	var flat := _flat(quarry.global_position - global_position)
	_turn_toward(flat, delta, TURN_RATE * 0.6)
	var going := _flat(quarry.get(&"velocity") if quarry.get(&"velocity") is Vector3 else Vector3.ZERO)
	landing = _clear_landing(global_position, Vector3(quarry.global_position.x, global_position.y, quarry.global_position.z) + going * LEAD)
	if _mode_time >= GATHER_TIME:
		_launch(Mode.LEAP)


func _return(delta: float) -> void:
	if hunting():
		_enter(Mode.HUNT)
		return
	var to := _flat(perch_foot - global_position)
	if to.length() < 0.8 or _stuck > 3.0:
		_stuck = 0.0
		_from = global_position
		if _on_ground_perch:
			_settle_on_perch()
		else:
			_enter(Mode.CLIMB)
		return
	var way_to := _way_to(perch_foot)
	_turn_toward(way_to if way_to.length() > 0.05 else to, delta, TURN_RATE * 1.5)
	var before := global_position
	_move(delta, _heading * BOUND_SPEED * 0.55 * clampf(_heading.dot(way_to.normalized()), 0.0, 1.0))
	_stuck = _stuck + delta if before.distance_to(global_position) < 0.3 * delta else 0.0


## Beats its way up to its ledge: up from the foot of its wall, then in onto it.
func _climb(delta: float) -> void:
	if hunting():
		global_position.y = maxf(global_position.y - gravity * delta, maze.ground_height(global_position))
		if global_position.y <= maze.ground_height(global_position) + 0.05:
			_enter(Mode.HUNT)
		return
	var rise := perch.y - _from.y
	var time := maxf(rise / CLIMB_SPEED, 1.0) + 0.8
	var t := clampf(_mode_time / time, 0.0, 1.0)
	var up := smoothstep(0.0, 0.8, t)
	var inward := smoothstep(0.6, 1.0, t)
	var above := Vector3(_from.x, lerpf(_from.y, perch.y + 1.2, up), _from.z)
	global_position = above.lerp(perch + Vector3.UP * (1.0 - inward) * 1.2, inward)
	_heading = _heading.slerp(perch_out if inward > 0.3 else _flat(perch - _from).normalized(), 1.0 - exp(-3.0 * delta)).normalized()
	if t >= 1.0:
		_settle_on_perch()


## Puts it on its ledge (or ground spot), facing out, a statue.
func _settle_on_perch() -> void:
	global_position = perch
	_heading = perch_out
	velocity = Vector3.ZERO
	landing = Vector3.INF
	quarry = null
	_forget = 0.0
	_enter(Mode.PERCH)


func _move(delta: float, wish: Vector3) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish, ACCELERATION * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= gravity * delta
	move_and_slide()


func _turn_toward(toward: Vector3, delta: float, rate: float) -> void:
	toward.y = 0.0
	if toward.length_squared() < 0.0001:
		return
	var angle := _heading.signed_angle_to(toward.normalized(), Vector3.UP)
	_heading = _heading.rotated(Vector3.UP, clampf(angle, -rate * delta, rate * delta)).normalized()


## The way towards `to` by the passages. (Near the middle of its cell it makes
## for the next one: turning as slowly as it does, it would otherwise go back
## and forth over the middle.)
func _way_to(to: Vector3) -> Vector3:
	var way_to := _flat(nav.waypoint(global_position, to, MazeNav.clearance_for(RADIUS)) - global_position)
	if way_to.length() < 1.5:
		var here := maze.cell_at(global_position)
		var next := nav.next_cell(here, maze.cell_at(to))
		if next != here:
			way_to = _flat(maze.world(next) - global_position)
	return way_to


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## A landing short of any wall between (a ray along the way, at knee height and up).
func _clear_landing(from: Vector3, to: Vector3) -> Vector3:
	var low := Vector3(from.x, to.y + 0.8, from.z)
	var high := Vector3(to.x, to.y + 0.8, to.z)
	var query := PhysicsRayQueryParameters3D.create(low, high, 1, _skip_players())
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return to
	var back := (hit["position"] as Vector3) - _flat(high - low).normalized() * (RADIUS + 0.3)
	return Vector3(back.x, to.y, back.z)


# --- Its ledge ---

## Finds where it waits: the edge of a terrace beside it (the lowest), else the
## top of the nearest wall, facing out over the hall. With none (or
## `seek_perch` off), the ground where it is.
func _find_perch() -> void:
	var ground := maze.ground_height(global_position)
	var here := Vector3(global_position.x, ground, global_position.z)
	perch = here
	perch_foot = here
	perch_out = _heading
	_on_ground_perch = true
	if not seek_perch:
		return
	var space := get_world_3d().direct_space_state
	var skip: Array[RID] = [get_rid()]
	var best := INF
	for face in FACES:
		var low := here + Vector3.UP * 1.5
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(low, low + face * 22.0, 1, skip))
		if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.3:
			continue
		var wall_at: Vector3 = hit["position"]
		var out := -face
		# A terrace against it: the outermost step that stands high (an upper
		# terrace stands back from the lower one), under 16 m up.
		var ledge := -1.0
		var edge := 0.0
		for k in 20:
			var probe := wall_at + out * (0.4 + k * 0.5)
			var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(probe.x, ground + 18.0, probe.z), Vector3(probe.x, ground - 1.0, probe.z), 1, skip))
			if down.is_empty():
				break
			var h: float = (down["position"] as Vector3).y - ground
			if h < 3.0:
				break
			if ledge < 0.0 or absf(h - ledge) > 0.3:
				ledge = h
			edge = 0.4 + k * 0.5
		# (a terrace is a block of stone: it has a face under its edge, a metre
		# down; a bridge or a vine strung over the hall has none)
		if ledge > 0.0:
			var before := wall_at + out * (edge + 2.0)
			before.y = ground + ledge - 1.0
			var front := space.intersect_ray(PhysicsRayQueryParameters3D.create(before, before - out * (edge + 2.5), 1, skip))
			if front.is_empty() or absf(((front["position"] as Vector3) - wall_at).dot(out) - edge) > 0.9 or edge > 5.0:
				ledge = -1.0
		var spot := Vector3.INF
		var height := INF
		if ledge > 3.0 and ledge < 16.0:
			height = ledge
			spot = wall_at + out * (edge - 0.3)
			spot.y = ground + ledge
		var corbel := Vector3.INF
		if not spot.is_finite():
			# The top of the wall itself, if it is low enough to be seen from the hall.
			var inside := wall_at - out * 0.6
			var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(inside.x, ground + 80.0, inside.z), Vector3(inside.x, ground + 2.0, inside.z), 1, skip))
			if not top.is_empty() and (top["position"] as Vector3).y - ground <= TOP_HIGHEST:
				height = (top["position"] as Vector3).y - ground
				spot = wall_at - out * 0.5
				spot.y = ground + height
			else:
				# Else a corbel of stone jutting from the face, as a gargoyle's is.
				# (along the wall a little, if ivy or vines are in the way)
				var high := ground + CORBEL_HIGH.x + (CORBEL_HIGH.y - CORBEL_HIGH.x) * _hashed(face)
				var along := face.cross(Vector3.UP)
				for shift: float in [0.0, 4.0, -4.0, 8.0, -8.0]:
					var at := Vector3(here.x, high - 0.3, here.z) + along * shift
					var face_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + face * 22.0, 1, skip))
					if face_hit.is_empty() or absf((face_hit["normal"] as Vector3).dot(out)) < 0.9:
						continue
					corbel = face_hit["position"]
					height = high - ground + 3.0
					spot = corbel + out * (CORBEL_DEPTH - 0.4)
					spot.y = high
					if not _overgrown(spot):
						break
				if not spot.is_finite():
					continue
		# (lower is better: a terrace or a corbel over a wall top; and in the
		# clear, not buried in ivy or behind hanging vines)
		var score := height + wall_at.distance_to(low) * 0.3 + (40.0 if _overgrown(spot) else 0.0)
		if score < best:
			best = score
			perch = spot
			perch_out = out
			var foot := spot + out * 4.5
			perch_foot = Vector3(foot.x, ground, foot.z)
			_on_ground_perch = false
			_corbel = corbel
	if _corbel.is_finite():
		_build_corbel(_corbel, perch_out, perch.y)


## Whether ivy grows or vines hang about `spot` (where it would crouch).
func _overgrown(spot: Vector3) -> bool:
	if not is_inside_tree():
		return false
	for node: Node in get_tree().get_nodes_in_group(&"ladders"):
		var ladder := node as Node3D
		if ladder == null:
			continue
		var reach := 2.6 + float(ladder.get(&"width") if ladder.get(&"width") != null else 1.0) * 0.5
		var from := ladder.global_position.y
		var to: float = from + float(ladder.get(&"height") if ladder.get(&"height") != null else 4.0)
		if Vector2(ladder.global_position.x - spot.x, ladder.global_position.z - spot.z).length() < reach and to > spot.y - 2.0 and from < spot.y + 3.0:
			return true
	for node: Node in get_tree().get_nodes_in_group(&"ropes"):
		var rope := node as Node3D
		if rope == null:
			continue
		var top := rope.global_position.y
		var bottom: float = top - float(rope.get(&"length") if rope.get(&"length") != null else 5.0)
		if Vector2(rope.global_position.x - spot.x, rope.global_position.z - spot.z).length() < 3.2 and top > spot.y - 1.0 and bottom < spot.y + 3.0:
			return true
	return false


## A number 0..1 of its own for each way it looks (the same on every machine).
func _hashed(face: Vector3) -> float:
	return fposmod(sin(float(_rng.seed % 9973) * 12.9898 + face.x * 78.233 + face.z * 37.719) * 43758.5453, 1.0)


## A stepped corbel of the walls' own concrete, jutting from the face at `at`
## (`out` from it) with its top at `top`: something to crouch on.
func _build_corbel(at: Vector3, out: Vector3, top: float) -> void:
	var holder := Node3D.new()
	holder.name = "Corbel"
	holder.top_level = true
	add_child(holder)
	holder.global_transform = Transform3D(Basis.looking_at(-out, Vector3.UP), Vector3(at.x, top, at.z))
	# (of the same concrete as the wall it juts from: precast slabs between rings, cast within them)
	var hall := maze.cell_at(at + out * 1.0)
	var step := Vector2i(roundi(-out.x), roundi(-out.z))
	var material := Wall.material_for(Wall.Look.SLABS if maze.ring_wall(hall, step) else Wall.Look.CAST, true, Color(0.72, 0.72, 0.72))
	# (each step: width, height, depth, from the top down)
	var steps: Array[Vector3] = [Vector3(1.9, 0.45, CORBEL_DEPTH), Vector3(1.4, 0.5, CORBEL_DEPTH * 0.72), Vector3(0.95, 0.5, CORBEL_DEPTH * 0.45), Vector3(0.6, 0.45, CORBEL_DEPTH * 0.22)]
	var down := 0.0
	for size in steps:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size + Vector3(0.0, 0.0, 0.3)
		box.mesh = mesh
		box.material_override = material
		# (sunk 0.3 m into the wall)
		box.position = Vector3(0.0, -down - size.y * 0.5, size.z * 0.5 - 0.15)
		holder.add_child(box)
		down += size.y
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(1.9, 0.45, CORBEL_DEPTH)
	shape.shape = slab
	shape.position = Vector3(0.0, -0.225, CORBEL_DEPTH * 0.5)
	body.add_child(shape)
	holder.add_child(body)


# --- How it looks ---

## Gives the creature what it is doing.
func _pose() -> void:
	if look == null or _far:
		return
	look.global_position = global_position
	look.rotation.y = atan2(_heading.x, _heading.z)
	look.alive = mode not in [Mode.PERCH, Mode.STONE]
	look.perched = mode in [Mode.PERCH, Mode.STIR] and not _on_ground_perch
	look.airborne = mode in [Mode.DIVE, Mode.LEAP, Mode.CLIMB]
	look.flapping = 1.0 if mode == Mode.CLIMB else (0.6 if mode == Mode.DIVE and _mode_time < 0.35 else 0.0)
	var t := clampf(_mode_time / maxf(_flight, 0.01), 0.0, 1.0)
	look.reaching = smoothstep(0.35, 0.8, t) if mode in [Mode.DIVE, Mode.LEAP] else 0.0
	look.aim = quarry.global_position + Vector3.UP * 1.0 if quarry and mode in [Mode.STIR, Mode.HUNT, Mode.GATHER, Mode.DIVE, Mode.LEAP] else Vector3.INF
	if mode in [Mode.DIVE, Mode.LEAP, Mode.GATHER] and landing.is_finite():
		var dark := 0.35 + 0.65 * t if mode != Mode.GATHER else 0.3 * clampf(_mode_time / GATHER_TIME, 0.0, 1.0)
		look.show_shadow(landing, dark, 1.2 + 0.6 * (1.0 - t))
	else:
		look.show_shadow(Vector3.INF)


func _skip_players() -> Array[RID]:
	var skip: Array[RID] = [get_rid()]
	for player: Node in players():
		if player is CollisionObject3D and is_instance_valid(player):
			skip.append((player as CollisionObject3D).get_rid())
	return skip


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
			_pose()


# --- Being run by someone else ---

func yaw() -> float:
	return atan2(_heading.x, _heading.z)


func net_state() -> int:
	return mode


## Landings (low four bits) and snarls (high four).
func net_flag() -> int:
	return (_slams & 0xf) | ((_snarls & 0xf) << 4)


func net_point() -> Vector3:
	return landing


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode in [Mode.STIR, Mode.DIVE, Mode.HUNT, Mode.GATHER, Mode.LEAP]
	landing = point
	_heading = Vector3(sin(facing), 0.0, cos(facing))
	var slams := flag & 0xf
	var snarls := (flag >> 4) & 0xf
	if look:
		if _heard_slams >= 0 and slams != _heard_slams:
			look.slam()
		if _heard_snarls >= 0 and snarls != _heard_snarls:
			look.snarl()
	_heard_slams = slams
	_heard_snarls = snarls


func _heard_changed(_was: int, now: int, _first: bool) -> void:
	_mode_time = 0.0
	if now == Mode.GATHER and look:
		look.gather(GATHER_TIME)


## As a puppet: off the ground it is put where it is heard to be (gravity has
## no say); on the ground it bounds there as MazeEnemy follows.
func _follow_heard(delta: float) -> void:
	if not _heard:
		return
	_mode_time += delta
	if mode in [Mode.PERCH, Mode.STIR, Mode.DIVE, Mode.LEAP, Mode.CLIMB, Mode.STONE]:
		_heard_at += _heard_moving * delta
		global_position = global_position.lerp(_heard_at, 1.0 - exp(-12.0 * delta))
		velocity = Vector3.ZERO
	else:
		_follow(delta)


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	_heading = Vector3(sin(facing), 0.0, cos(facing))
	if look:
		_pose()
		look.settle()


func _puppet_changed() -> void:
	collision_layer = 0 if puppet else 4
	collision_mask = 1 if puppet else 1 | 4


## Whether nothing of the world stands between two points.
func _clear_line(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, _skip_players())
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

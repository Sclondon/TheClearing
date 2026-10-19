class_name MazeCat
extends MazeEnemy
## What the maze's big cats (MazeLynx, MazePanther) have in common: the body
## and how it gets about, not what it thinks. It is drawn and moved by BigCat
## (creatures/big_cat); each kind says what it does (`_think`).
##
## WHERE IT IS (`place`): on the ground of the halls, up on a LEDGE (a flat top
## a few metres to sixteen up, along a wall's face: the mezzanine the Avenues
## have along every wall, or a terrace), on a WALL (going up or down ivy), or in
## the AIR (dropping off a ledge). Ledges and ivy are found by rays and among
## the `ladders` (NearIndex), on every machine alike.
## - On the ground it goes by the passages (MazeNav), as the others do.
## - On a ledge it walks along it, as far as the ledge goes.
## - Up: by ivy whose top is at a ledge (it climbs as a leopard goes up a tree,
##   bounding). Down: by ivy, head first, or (in a hurry) it drops off the edge
##   into the hall, landing on all fours.
## - After someone up out of reach (a ledge, a terrace, a bridge; MazeEnemy's
##   CLIMBING, the user, 2026-10-18: "more creatures should be able to climb
##   things"): a crouch and a bound up the face (`leap_most`), clawing up the rest,
##   along the top to them; down again in a drop. Each kind says whether it goes
##   after people so (`_climbs_after`): the panther does, the shy lynx does not.
##
## WHAT IT DOES WITH ITS BODY (each kind decides when):
## - `_start_pounce(at)`: the wiggle (the last warning, BigCat.WIGGLE_TIME),
##   then a spring of a few metres. Whom its forepaws or jaws land on is caught.
## - `_start_swipe(who)`: a forepaw slashed at them; caught if it lands.
## - `_hiss()`, `_growl()`: heard and seen by everyone (sent as counts).
##
## WATCHED. `_watched(who)`, how squarely someone is looking at it (from how
## they face, and for this machine's own player, where the camera looks): cats
## would rather not be seen coming.
##
## NIGHT (`night`, from the world's DayCycle): 0 by day to 1 at night. Its eyes
## give the light back more the darker it is (at night, two points of light).
##
## Online, the host's thinks; a puppet follows its news: where it is, what it
## is doing (`net_state`), where (place) and its pounces, swipes, hisses and
## growls (counts in the flag), and the point it pounces or looks at.

## What it is doing (`net_state`). Each kind uses those it needs.
enum Mode { REST, PROWL, WATCH, SLIP, FLEE, STALK, HESITATE, CHASE, POUNCE, HISS, SWIPE, FEED, GUARD, CLIMB, DROP, HUNT, DRAG }
enum Place { GROUND, LEDGE, WALL, AIR }

## Where a player's chest is, over their feet.
const CHEST := 0.9
## How high a ledge may be (least, most) over the ground, and how far in
## from its face it is looked for.
const LEDGE_HIGH := Vector2(3.0, 16.0)
const LEDGE_IN := 0.6
## The walls are square to the axes.
const FACES: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]

@export var kind := BigCat.Kind.PANTHER
## How much bigger than its model it is drawn (the models are life size).
@export var size := 1.0
## Further than this from every player it is not posed or drawn.
@export var pose_range := 90.0
@export var gravity := 24.0
@export var acceleration := 10.0
@export var turn_rate := 7.0
## How fast it runs to the foot of a way up, and along the top, after someone up
## out of reach (its climbing up a face is MazeEnemy's `climb_speed`).
@export var climb_run := 5.0

var mode := Mode.REST
var place := Place.GROUND
var cat: BigCat
var facing_yaw := 0.0
## How dark it is, 0 by day to 1 at night.
var night := 0.0
## Its ledge, when it is on one: the way out from the wall over the hall, and its height.
var ledge_out := Vector3.FORWARD
var ledge_y := 0.0

var _mode_time := 0.0
var _point := Vector3.INF
var _radius := 0.3
var _ivy: Node3D
var _climb_up := true
var _climb_t := 0.0
var _air_from := Vector3.ZERO
var _air_to := Vector3.ZERO
var _air_time := 0.0
var _air_span := 1.0
var _air_rise := 0.5
var _after_air := Mode.PROWL
var _caught_now := false
var _running_pounce := false
var _pounces := 0
var _swipes := 0
var _hisses := 0
var _growls := 0
var _heard_flag_once := false
var _heard_place := Place.GROUND
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _day: Node
var _day_looked := false
var _placed := false
var _unwatched := 0.0


func _init() -> void:
	climbs = Climbs.LEAP
	climb_speed = 2.6
	leap_most = 7.0


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.4
	var shape := CapsuleShape3D.new()
	_radius = (0.32 if kind == BigCat.Kind.PANTHER else 0.26) * size
	shape.radius = _radius
	shape.height = maxf(0.75 * size, _radius * 2.0 + 0.05)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	cat = BigCat.new()
	cat.kind = kind
	cat.low_poly = Settings.low_poly
	cat.scale = Vector3.ONE * size
	if kind == BigCat.Kind.LYNX:
		cat.lunge_reach = Vector2(1.0, 3.0)
	add_child(cat)
	cat.top_level = true
	facing_yaw = rotation.y
	rotation = Vector3.ZERO
	_prev_pos = global_position
	_curr_pos = global_position
	_pose(0.0)
	cat.settle()


# --- Each step ---

func _physics_process(delta: float) -> void:
	if not _placed and is_inside_tree():
		_placed = true
		_settle_in()
	_night_now()
	if puppet:
		_follow_heard(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze == null:
		return
	_mode_time += delta
	_sense(delta)
	if place == Place.GROUND and (climbing_now() or _climbs_after()) and _ways_up(delta, _radius, climb_run):
		facing_yaw = aloft_yaw()
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	match place:
		Place.WALL:
			_climb(delta)
		Place.AIR:
			_fly(delta)
		_:
			if mode == Mode.POUNCE:
				_pounce_step(delta)
			elif mode == Mode.SWIPE:
				_swipe_step(delta)
			else:
				_think(delta)
	_prev_pos = _curr_pos
	_curr_pos = global_position


## Whether it goes up after whom it hunts when they are up out of reach (each kind; see above).
func _climbs_after() -> bool:
	return false


## The first moment it is in the world: each kind may put itself somewhere (on a ledge).
func _settle_in() -> void:
	pass


## What it does, each step, on the ground or a ledge (each kind).
func _think(_delta: float) -> void:
	pass


func _set_mode(next: Mode) -> void:
	if next != mode:
		mode = next
		_mode_time = 0.0


func _night_now() -> void:
	if not _day_looked:
		_day_looked = true
		var up := get_parent()
		while up:
			var found: Variant = up.get(&"day")
			if found is DayCycle:
				_day = found
				break
			up = up.get_parent()
	if _day and is_instance_valid(_day):
		night = 1.0 - clampf(float(_day.get(&"daylight")), 0.0, 1.0)


# --- Who it is after ---

## How squarely `who` looks at it: from how they face (1 straight at it), and
## for this machine's own player where the camera looks too.
func _watched(who: Node3D) -> float:
	var to := global_position - who.global_position
	to.y = 0.0
	if to.length() < 0.05:
		return 1.0
	var way := to.normalized()
	var facing: Variant = who.get(&"facing_yaw")
	var looks := -1.0
	if facing != null:
		looks = Vector3(sin(facing), 0.0, cos(facing)).dot(way)
	if who is Player and who == local_player():
		var view := get_viewport().get_camera_3d() if is_inside_tree() else null
		if view:
			var ahead := -view.global_basis.z
			var at := (global_position + Vector3.UP * 0.5 - view.global_position).normalized()
			looks = maxf(looks, ahead.dot(at) * 1.1 - 0.1)
	return looks


## How fast `who` goes (flat), and whether away from it.
static func _speed_of(who: Node3D) -> Vector3:
	var them: Variant = who.get(&"velocity")
	return Vector3(them.x, 0.0, them.z) if them is Vector3 else Vector3.ZERO


func _running_away(who: Node3D, faster_than := 3.2) -> bool:
	var them := _speed_of(who)
	var away := who.global_position - global_position
	away.y = 0.0
	return them.length() > faster_than and them.normalized().dot(away.normalized()) > 0.3


func _running_at(who: Node3D, faster_than := 2.8) -> bool:
	var them := _speed_of(who)
	var to := global_position - who.global_position
	to.y = 0.0
	return them.length() > faster_than and them.normalized().dot(to.normalized()) > 0.75


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _gap(who: Node3D) -> float:
	return _flat(who.global_position - global_position).length()


# --- On the ground ---

func _steer(wish: Vector3, speed: float, delta: float) -> void:
	wish.y = 0.0
	var want := wish.normalized() * speed if wish.length() > 0.01 else Vector3.ZERO
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(want, acceleration * delta)
	velocity.x = current.x
	velocity.z = current.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
	if current.length() > 0.3:
		facing_yaw = lerp_angle(facing_yaw, atan2(current.x, current.z), 1.0 - exp(-turn_rate * delta))


## Still, turning to face `toward` (INF: as it is).
func _hold(delta: float, toward := Vector3.INF) -> void:
	_steer(Vector3.ZERO, 0.0, delta)
	if toward.is_finite():
		var to := _flat(toward - global_position)
		if to.length() > 0.1:
			facing_yaw = lerp_angle(facing_yaw, atan2(to.x, to.z), 1.0 - exp(-5.0 * delta))


## The way to `point` by the passages, keeping off the walls.
func _way_to(point: Vector3) -> Vector3:
	return _flat(nav.waypoint(global_position, point, MazeNav.clearance_for(_radius)) - global_position)


# --- Ledges and ivy ---

## A ledge over the hall beside `near` (on the ground of a hall): the top of
## a terrace or the mezzanine along the nearest wall's face, LEDGE_HIGH up.
## {"at": a point on it (its middle line), "out": out from the wall, "y"}, or {}.
func _ledge_beside(near: Vector3, reach := 20.0) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var ground := maze.ground_height(near)
	var best := {}
	var nearest := INF
	for face: Vector3 in FACES:
		var low := Vector3(near.x, ground + 1.2, near.z)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(low, low + face * reach, 1, [get_rid()]))
		if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.3:
			continue
		var wall: Vector3 = hit["position"]
		# (a ledge stands out from the wall as a block: the ray meets its face, and its top is just in from that)
		var spot := _ledge_at(wall + face * LEDGE_IN, ground)
		if not spot.is_empty() and wall.distance_to(low) < nearest:
			nearest = wall.distance_to(low)
			spot["out"] = -face
			best = spot
	return best


## The ledge at `probe` (just out from a wall's face), if there is one: a flat
## top LEDGE_HIGH over `ground`, with open air a little further out.
func _ledge_at(probe: Vector3, ground: float) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(probe.x, ground + LEDGE_HIGH.y + 2.0, probe.z), Vector3(probe.x, ground + 0.5, probe.z), 1, [get_rid()]))
	if down.is_empty() or (down["normal"] as Vector3).y < 0.8:
		return {}
	var top: Vector3 = down["position"]
	var high := top.y - ground
	if high < LEDGE_HIGH.x or high > LEDGE_HIGH.y:
		return {}
	return {"at": top, "y": top.y}


## Ivy near `near` (within `reach`) whose top is at a ledge: [the ivy, the
## ledge at its top], nearest first; or [].
func _ivy_up(near: Vector3, reach: float) -> Array:
	var best: Array = []
	var nearest := INF
	for node: Node in NearIndex.near(get_tree(), &"ladders", near, reach):
		var ivy := node as Ladder
		if ivy == null or not is_instance_valid(ivy):
			continue
		var foot := ivy.stand(ivy.bottom_y())
		var apart := _flat(foot - near).length()
		if apart > reach or apart > nearest:
			continue
		var ground := maze.ground_height(foot)
		if absf(ivy.bottom_y() - ground) > 1.0:
			continue
		var on := _ledge_at(ivy.global_position + ivy.facing() * 0.6 + Vector3.UP * 0.0, ground)
		if on.is_empty() or absf(float(on["y"]) - ivy.top_y()) > 0.6:
			continue
		on["out"] = -ivy.facing()
		nearest = apart
		best = [ivy, on]
	return best


## Puts it on a ledge (`spot` from _ledge_beside or _ivy_up), facing along it.
func _put_on_ledge(spot: Dictionary, along_way := 1.0) -> void:
	place = Place.LEDGE
	ledge_out = (spot["out"] as Vector3).normalized()
	ledge_y = float(spot["y"])
	var at: Vector3 = spot["at"]
	global_position = Vector3(at.x, ledge_y + 0.02, at.z)
	velocity = Vector3.ZERO
	var along := ledge_out.cross(Vector3.UP) * along_way
	facing_yaw = atan2(along.x, along.z)


## Along the ledge it is on, `way` (1 or -1 along ledge_out x up) at `speed`,
## as far as the ledge goes. Whether it could.
func _ledge_walk(way: float, speed: float, delta: float) -> bool:
	var along := ledge_out.cross(Vector3.UP) * signf(way)
	var next := global_position + along * speed * delta
	var ahead := next + along * (0.6 * size)
	var space := get_world_3d().direct_space_state
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 1.5, ahead + Vector3.DOWN * 0.8, 1, [get_rid()]))
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.4, ahead + Vector3.UP * 0.4, 1, [get_rid()]))
	facing_yaw = lerp_angle(facing_yaw, atan2(along.x, along.z), 1.0 - exp(-turn_rate * delta))
	if down.is_empty() or absf((down["position"] as Vector3).y - ledge_y) > 0.35 or not wall.is_empty():
		velocity = Vector3.ZERO
		return false
	global_position = Vector3(next.x, ledge_y + 0.02, next.z)
	velocity = along * speed
	return true


## Which way along its ledge (1 or -1) brings it nearest above `point`.
func _ledge_way_to(point: Vector3) -> float:
	var along := ledge_out.cross(Vector3.UP)
	return signf(_flat(point - global_position).dot(along))


## How far along its ledge `point` is from it (signed).
func _ledge_offset(point: Vector3) -> float:
	return _flat(point - global_position).dot(ledge_out.cross(Vector3.UP))


func _start_climb(ivy: Node3D, up: bool) -> void:
	_ivy = ivy
	_climb_up = up
	place = Place.WALL
	velocity = Vector3.ZERO
	var ladder := ivy as Ladder
	var from := ladder.bottom_y() if up else ladder.top_y()
	_climb_t = 0.0
	global_position = _on_ivy(from)
	_set_mode(Mode.CLIMB)


func _on_ivy(y: float) -> Vector3:
	var ladder := _ivy as Ladder
	var at := ladder.global_position - ladder.facing() * (0.28 * size)
	return Vector3(at.x, y, at.z)


## Up or down its ivy; off it at the top onto the ledge, at the foot onto the ground.
func _climb(delta: float) -> void:
	if _ivy == null or not is_instance_valid(_ivy):
		place = Place.GROUND
		_set_mode(Mode.PROWL)
		return
	var ladder := _ivy as Ladder
	var y := global_position.y + (climb_speed if _climb_up else -climb_speed * 1.2) * delta
	velocity = Vector3(0.0, climb_speed if _climb_up else -climb_speed, 0.0)
	var into := ladder.facing()
	facing_yaw = atan2(into.x, into.z)
	if _climb_up and y >= ladder.top_y() - 0.1:
		var on := _ledge_at(ladder.global_position + into * 0.6, maze.ground_height(ladder.global_position))
		if on.is_empty():
			on = {"at": ladder.global_position + into * 0.6 + Vector3(0.0, ladder.top_y() - ladder.global_position.y, 0.0), "y": ladder.top_y()}
		on["out"] = -into
		_put_on_ledge(on, 1.0 if randf() < 0.5 else -1.0)
		_arrived(Place.LEDGE)
		return
	if not _climb_up and y <= ladder.bottom_y() + 0.05:
		place = Place.GROUND
		global_position = ladder.stand(ladder.bottom_y()) - into * 0.5
		facing_yaw = atan2(-into.x, -into.z)
		_arrived(Place.GROUND)
		return
	global_position = _on_ivy(y)


## Drops (or leaps) to `to` through the air, then does `after`.
func _drop_to(to: Vector3, after: Mode) -> void:
	_air_from = global_position
	_air_to = to
	var fall := maxf(_air_from.y - to.y, 0.0)
	_air_span = clampf(sqrt(2.0 * fall / gravity) * 1.25 + 0.15, 0.45, 1.5)
	_air_rise = 0.5 if fall > 1.0 else 1.2
	_air_time = 0.0
	_after_air = after
	place = Place.AIR
	_set_mode(Mode.DROP)
	var way := _flat(to - _air_from)
	if way.length() > 0.1:
		facing_yaw = atan2(way.x, way.z)


func _fly(delta: float) -> void:
	_air_time += delta
	var u := clampf(_air_time / _air_span, 0.0, 1.0)
	var flat := _air_from.lerp(_air_to, u)
	# (out from the edge, then falling faster and faster)
	var y := _air_from.y + _air_rise * sin(PI * minf(u * 1.4, 1.0)) * (1.0 - u) + (_air_to.y - _air_from.y) * u * u
	var before := global_position
	global_position = Vector3(flat.x, y, flat.z)
	velocity = (global_position - before) / maxf(delta, 0.001)
	if u >= 1.0:
		place = Place.GROUND
		velocity = Vector3.ZERO
		cat.settle()
		_set_mode(_after_air)
		_arrived(Place.GROUND)


## It has got where it was going (each kind may take it from there).
func _arrived(_at: Place) -> void:
	pass


## Somewhere on the ground of the hall under it (off its ledge), `out` metres
## out from under the edge, or as near `toward` as it can drop.
func _ground_below(toward: Vector3, out := 2.5) -> Vector3:
	var edge := global_position + ledge_out * out
	if toward.is_finite():
		var aim := _flat(toward - global_position)
		if aim.length() > 0.1:
			var reach := clampf(aim.dot(ledge_out), 1.5, 5.0)
			edge = global_position + ledge_out * reach + ledge_out.cross(Vector3.UP) * clampf(aim.dot(ledge_out.cross(Vector3.UP)), -3.0, 3.0)
	var space := get_world_3d().direct_space_state
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(edge.x, global_position.y - 0.3, edge.z), Vector3(edge.x, global_position.y - 40.0, edge.z), 1, [get_rid()]))
	if down.is_empty():
		return Vector3(edge.x, maze.ground_height(edge), edge.z)
	return down["position"]


# --- The pounce and the swipe ---

## Wiggles and springs at `at` (the last warning is the wiggle); from a run
## (`running`) it springs as it goes, without the wiggle.
func _start_pounce(at: Vector3, running := false) -> void:
	_set_mode(Mode.POUNCE)
	_point = at
	_caught_now = false
	_pounces += 1
	_running_pounce = running
	if not running:
		velocity.x = 0.0
		velocity.z = 0.0
	cat.pounce(at, not running)


func _pounce_step(delta: float) -> void:
	var push := cat.lunge_push()
	if _running_pounce and cat.lunge_stage() == Dog.Lunge.GATHER:
		# (from a run it keeps going as it gathers itself)
		push = Vector3(velocity.x, 0.0, velocity.z)
	velocity.x = push.x
	velocity.z = push.z
	if cat.wiggling():
		_hold(delta, _point)
		_pounce_wiggling(delta)
		if mode != Mode.POUNCE:
			return
	else:
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		if push.length() > 0.5:
			facing_yaw = lerp_angle(facing_yaw, atan2(push.x, push.z), 1.0 - exp(-14.0 * delta))
	if not _caught_now:
		for player: Node3D in players():
			if huntable(player) and (cat.pounce_hits(player.global_position + Vector3.UP * CHEST, 0.95) or cat.pounce_hits(player.global_position + Vector3.UP * 0.4, 0.8)):
				_caught_now = true
				_catch(player)
				break
	if not cat.pouncing():
		_pounce_done(_caught_now)


## Each step of the wiggle (each kind may call it off).
func _pounce_wiggling(_delta: float) -> void:
	pass


## The pounce is over (it caught someone, or not).
func _pounce_done(_caught: bool) -> void:
	_set_mode(Mode.PROWL)


## Calls off a pounce while it wiggles (it holds, crouched).
func _call_off_pounce() -> void:
	cat.settle()
	_set_mode(Mode.HESITATE)


func _start_swipe(who: Node3D) -> void:
	_set_mode(Mode.SWIPE)
	_caught_now = false
	_swipes += 1
	_point = who.global_position + Vector3.UP * 0.5
	cat.swipe(_point)


func _swipe_step(delta: float) -> void:
	var u := cat.swipe_progress()
	var to := _flat(_point - global_position)
	# (a short step into the blow)
	var lunge := 2.8 if u > BigCat.STRIKE.x - 0.15 and u < BigCat.STRIKE.y else 0.0
	_steer(to.normalized() * lunge if to.length() > 0.6 else Vector3.ZERO, lunge, delta)
	if to.length() > 0.1:
		facing_yaw = lerp_angle(facing_yaw, atan2(to.x, to.z), 1.0 - exp(-10.0 * delta))
	if not _caught_now:
		for player: Node3D in players():
			if huntable(player) and (cat.swipe_hits(player.global_position + Vector3.UP * 0.5, 0.95) or cat.swipe_hits(player.global_position + Vector3.UP * CHEST, 0.85)):
				_caught_now = true
				_catch(player)
				break
	if not cat.swiping():
		_swipe_done(_caught_now)


func _swipe_done(_caught: bool) -> void:
	_set_mode(Mode.PROWL)


func _hiss() -> void:
	_hisses += 1
	cat.hiss()


func _growl(seconds := 2.0) -> void:
	_growls += 1
	cat.growl(seconds)


# --- Out of everyone's sight ---

## Asleep, it goes on its way on the ground; up on a ledge it stays.
func roam_unseen(step: float) -> void:
	if place == Place.GROUND:
		super(step)


func ate(seconds: float) -> void:
	super(seconds)
	_set_mode(Mode.FEED)


func revive(at: Vector3, facing: float, hungry := 0.3) -> void:
	super(at, facing, hungry)
	place = Place.GROUND
	_set_mode(Mode.PROWL)


func die() -> void:
	super()
	place = Place.GROUND


# --- What it looks like ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near == null or near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			cat.visible = not far
			cat.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
			if not far:
				cat.settle()
	if _far:
		return
	_pose(delta)


func _pose(_delta: float) -> void:
	var at := _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	var on := place if not puppet else _heard_place
	if is_aloft():
		# (after someone up out of reach: up the face nose first, in a bound, or dropping)
		cat.global_transform = Transform3D((Basis(Vector3.UP, facing_yaw) * aloft_tilt()).scaled(Vector3.ONE * size), at)
		cat.climbing = aloft in [HighClimb.Aloft.CLIMB, HighClimb.Aloft.DOWN]
		cat.grounded = not (aloft in [HighClimb.Aloft.LEAP, HighClimb.Aloft.DROP])
		cat.crouching = aloft == HighClimb.Aloft.CROUCH
		cat.stalking = aloft == HighClimb.Aloft.ON
		cat.feeding = false
		cat.lashing = false
		cat.wary = false
		cat.lying = false
		cat.sitting = false
		cat.look_at_point = _point
		cat.set_eyeshine(lerpf(0.5, 3.0, smoothstep(0.35, 0.9, night)))
		return
	if on == Place.WALL:
		var into := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
		var up := mode != Mode.CLIMB or _climbing_up()
		# (its forward up the wall, or down it; its back out from the wall)
		var ahead := Vector3.UP if up else Vector3.DOWN
		var back := -into
		cat.global_transform = Transform3D(Basis(back.cross(ahead), back, ahead).scaled(Vector3.ONE * size), at + back * 0.05)
	else:
		cat.global_position = at
		cat.global_basis = Basis(Vector3.UP, facing_yaw).scaled(Vector3.ONE * size)
	cat.climbing = on == Place.WALL
	cat.grounded = on != Place.AIR and (puppet or on != Place.GROUND or is_on_floor() or mode == Mode.CLIMB)
	cat.stalking = mode in [Mode.STALK, Mode.HUNT]
	cat.crouching = mode in [Mode.HESITATE, Mode.GUARD] or (mode == Mode.WATCH and on == Place.LEDGE)
	cat.feeding = mode == Mode.FEED
	cat.lashing = mode in [Mode.HESITATE, Mode.GUARD, Mode.HISS]
	cat.wary = mode in [Mode.SLIP, Mode.FLEE]
	cat.lying = mode == Mode.REST
	cat.sitting = mode == Mode.REST or (mode == Mode.WATCH and on == Place.GROUND)
	cat.look_at_point = _point if mode in [Mode.WATCH, Mode.STALK, Mode.HESITATE, Mode.GUARD, Mode.HISS, Mode.HUNT, Mode.CHASE, Mode.SLIP] else Vector3.INF
	cat.set_eyeshine(lerpf(0.5, 3.0, smoothstep(0.35, 0.9, night)))


func _climbing_up() -> bool:
	return _climb_up if not puppet else velocity.y >= 0.0 and _heard_moving.y >= -0.05


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Pounces and swipes (two bits each, counts), hisses and growls (a bit each,
## counts), and where it is (two bits).
func net_flag() -> int:
	return (_pounces & 3) | ((_swipes & 3) << 2) | ((_hisses & 1) << 4) | ((_growls & 1) << 5) | ((place & 3) << 6)


func net_point() -> Vector3:
	return _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	var was := mode
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode in [Mode.STALK, Mode.CHASE, Mode.POUNCE, Mode.SWIPE]
	_point = point
	_heard_place = ((flag >> 6) & 3) as Place
	place = _heard_place
	facing_yaw = facing
	var pounces := flag & 3
	var swipes := (flag >> 2) & 3
	var hisses := (flag >> 4) & 1
	var growls := (flag >> 5) & 1
	if _heard_flag_once and cat:
		if pounces != (_pounces & 3) and point.is_finite():
			# (from a chase it springs as it runs, without the wiggle)
			cat.pounce(point, was != Mode.CHASE)
		if swipes != (_swipes & 3) and point.is_finite():
			cat.swipe(point)
		if hisses != (_hisses & 1):
			cat.hiss()
		if growls != (_growls & 1):
			cat.growl()
	_heard_flag_once = true
	_pounces = pounces
	_swipes = swipes
	_hisses = hisses
	_growls = growls


## As a puppet: on the ground it walks where it is heard to be (MazeEnemy);
## anywhere else it is put there (gravity has no say).
func _follow_heard(delta: float) -> void:
	if not _heard or _follow_aloft(delta):
		return
	if _heard_place == Place.GROUND and mode != Mode.DROP:
		_follow(delta)
		return
	_heard_at += _heard_moving * delta
	global_position = global_position.lerp(_heard_at, 1.0 - exp(-14.0 * delta))
	velocity = _heard_moving


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if cat:
		cat.global_position = at
		cat.settle()


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4

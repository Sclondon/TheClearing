class_name MazeSpiderMonkey
extends MazeEnemy
## A spider monkey of a troop that waits over a hall. What it looks like and
## how it moves is SpiderMonkey (creatures/spider_monkey/, a component of its
## own); this is only what it thinks, and it drives the SpiderMonkey by moving
## it and calling on it.
##
## They go in troops (`troop()`: four to seven) and AMBUSH FROM ABOVE.
## - THE VINE. A troop is put in a cell of a hall and finds the wall nearest
##   it, and the one across the hall if there is one, by rays, the first moment
##   it is in the world (on every machine alike). Along each it strings an old
##   woody vine (SpiderMonkeyVine) `VINE_HIGH` up, over a stretch of plain wall
##   clear of terraces (nothing to land on under it), its stems going down to
##   the ground at either end.
## - HANGING. Each hangs from a vine over the hall (HANG), by its tail and a
##   hand or by its tail alone upside down, swaying, still and dark against the
##   wall: hard to spot. Now and then one chitters.
## - THE WARNING. When one notices someone (MazeEnemy's senses, and a watch of
##   its own on the hall below, since from up there it sees little down the
##   passages) the troop stirs (STIR): heads turn to them, the vines rustle and
##   shake (a whinny with each), and they swing along the vines hand over hand to
##   keep over them. Walking on past, or turning back, gets away.
## - THE DROP. Someone under it (within `DROP_RANGE` along the ground of the
##   foot of its hold, out in the hall) and in its sight, one winds up (WIND:
##   lets go with its hand, swings back on its tail, shrieks; `WIND_TIME`, the
##   last warning), then flings itself off (DROP) at where they will be when it
##   lands: where they are and their going for the flight, but at most `LEAD`
##   metres of it. Someone walking or running is landed on; a sprint carries
##   them past where it aims. Landing on someone (`CATCH_RADIUS`) catches them:
##   it shrieks and the troop with it (SHRIEK).
## - THE CHASE. A miss and it scampers after them on all fours (CHASE) at
##   `CHASE_SPEED` (a little faster than he runs, slower than his sprint) for
##   `CHASE_TIME`, and springs at them (LEAP) from `LEAP_RANGE` after a bounce and
##   a shriek. Then (or if it loses them, or they get up out of its reach) it
##   goes HOME: to the foot of a stem of its vine, CLIMBs it, and swings along
##   the vine (TRAVERSE) to its hold, and hangs again.
## - Put where there is no wall to string a vine along, it goes ABOUT on the
##   ground and chases whoever it notices.
##
## Online, as every MazeEnemy: the host's copy thinks; a puppet follows what it
## hears (its mode, and counts of its drops, shrieks and rustles in the flag),
## and finds its troop's vines for itself as the host's does.

enum Mode { HANG, STIR, WIND, DROP, CHASE, LEAP, SHRIEK, HOME, CLIMB, TRAVERSE, ABOUT }

## How high its vine is strung (above the ground), and how long a stretch of
## wall it needs (least, most, metres).
const VINE_HIGH := 5.8
const STRETCH := Vector2(6.0, 18.0)
## How far off a wall (across the hall) a second vine may be.
const ACROSS_MOST := 22.0
## How near the foot of its hold (along the ground) someone must be to be dropped on.
const DROP_RANGE := 8.5
## The wind-up before the drop (seconds), and a little more for each one already going.
const WIND_TIME := 0.6
## The drop: how long it is in the air (least, most), how hard it falls (m/s²),
## how far ahead of them it aims at most (metres), and how near it must land.
const FLIGHT := Vector2(0.55, 0.85)
const DROP_GRAVITY := 16.0
const LEAD := 2.6
const CATCH_RADIUS := 0.9
## On the ground: its scamper (the boy runs at 4.4, sprints at 5.6), how long it keeps it up.
const CHASE_SPEED := 4.7
const CHASE_TIME := 4.5
const WALK_SPEED := 1.6
## Its spring at them on the ground: from how far, how long in the air, the
## bounce before it (the warning).
const LEAP_RANGE := 2.5
const LEAP_TIME := 0.42
const LEAP_READY := 0.3
## Up its vine's stem, and along the vine hand over hand.
const CLIMB_SPEED := 2.2
const SWING_SPEED := 1.9
## How far apart they keep along a vine.
const SPACING := 1.1
## Further than this from every player it is not posed.
@export var pose_range := 60.0

var mode := Mode.HANG
var body: SpiderMonkey
## Its troop (shared by all of it: the vines, who is where).
var troop_of: Troop
## Its place in its troop, and the vine it hangs from (an index into its troop's vines).
var place := 0
var vine := 0
## Where along its vine it hangs when nobody is about (0..1), and where it is now.
var hold_t := 0.5
var at_t := 0.5

var _pos := Vector3.ZERO
var _vel := Vector3.ZERO
var _yaw := 0.0
var _mode_time := 0.0
var _chitter_in := 4.0
var _rustle_in := 0.5
var _wind_for := WIND_TIME
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _flight := 0.7
var _launch := Vector3.ZERO
var _chase_left := 0.0
var _gather := 0.0
var _caught_one := false
var _climb_end := 0
var _drops := 0
var _shrieks := 0
var _rustles := 0
var _far := false
var _far_check := 0.0
var _shown := Transform3D.IDENTITY
var _shown_set := false
var _ready_done := false


## What a troop shares: where it was put, its vines (one or two: SpiderMonkeyVine,
## in the world's space), each vine's way off its wall, and who is in it.
class Troop:
	extends RefCounted
	var home := Vector3.INF
	var found := false
	var vines: Array[SpiderMonkeyVine] = []
	var outs: Array[Vector3] = []
	var grounds: Array[float] = []
	var members: Array = []


## A troop of `count` (four to seven), hanging in turn by tail and hand and by the tail alone.
static func troop(count := 5) -> Array[MazeSpiderMonkey]:
	var shared := Troop.new()
	var made: Array[MazeSpiderMonkey] = []
	for k in count:
		var one := MazeSpiderMonkey.new()
		one.troop_of = shared
		one.place = k
		shared.members.append(one)
		made.append(one)
	return made


func _init() -> void:
	sight_range = 30.0
	hear_range = 7.0
	memory = 7.0
	alert_range = 30.0
	pack = &"spider_monkeys"
	spare_time = 4.0


func _ready() -> void:
	add_to_group(&"pursuers")
	# (a solid body, host and puppet alike, that the boy bumps into; it moves
	# itself by hand and is stopped by nothing)
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 0
	var shape := CapsuleShape3D.new()
	shape.radius = 0.22
	shape.height = 0.7
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.4
	add_child(collider)
	if troop_of == null:
		troop_of = Troop.new()
		troop_of.members.append(self)
	body = SpiderMonkey.new()
	body.size = _rng.randf_range(0.95, 1.1)
	body.force_low = Settings.low_poly or Mummy.low_poly
	body.seed_value = _rng.randi()
	body.hang_style = SpiderMonkey.Hang.HAND if place % 3 != 1 else SpiderMonkey.Hang.TAIL
	add_child(body)
	body.top_level = true
	_pos = global_position
	_yaw = global_rotation.y
	_chitter_in = _rng.randf_range(2.0, 9.0)
	spotted.connect(func(_who: Node3D) -> void: _on_spotted())
	if not troop_of.home.is_finite():
		troop_of.home = global_position
	_find_vines.call_deferred()


# --- The vines ---

## Finds the troop's walls (the first of it to look does it for all) and takes its hold.
func _find_vines() -> void:
	if not is_inside_tree():
		return
	if not troop_of.found:
		troop_of.found = true
		_string_vines()
	_ready_done = true
	if troop_of.vines.is_empty():
		mode = Mode.ABOUT
		_pos = Vector3(global_position.x, maze.ground_height(global_position) if maze else global_position.y, global_position.z)
		_place_ground()
		return
	# Its hold: spread along its vine, the troop shared between the vines.
	var count := troop_of.members.size()
	var vines := troop_of.vines.size()
	vine = place % vines
	var on_this := 0
	var mine := 0
	for k in count:
		if k % vines == vine:
			if k == place:
				mine = on_this
			on_this += 1
	var line := troop_of.vines[vine]
	var spread := clampf(SPACING * 1.6 * (on_this - 1) / maxf(line.length(), 1.0), 0.0, 0.8)
	hold_t = 0.5 + (spread * (float(mine) / maxf(on_this - 1, 1) - 0.5) if on_this > 1 else 0.0)
	hold_t = clampf(hold_t + _rng.randf_range(-0.03, 0.03), 0.08, 0.92)
	at_t = hold_t
	mode = Mode.HANG
	_hang_at(at_t, 0.0)
	body.settle()


## Strings a vine along the nearest wall (and the one across the hall, if near).
func _string_vines() -> void:
	var space := get_world_3d().direct_space_state
	var home := troop_of.home
	var ground := maze.ground_height(home) if maze else home.y
	var high := ground + VINE_HIGH
	var from := Vector3(home.x, high, home.z)
	var best := INF
	var face := Vector3.ZERO
	var hit_at := Vector3.ZERO
	for way: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + way * 20.0, 1))
		if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.3:
			continue
		var d := from.distance_to(hit["position"])
		if d < best and _stretch(space, hit["position"], -way, ground).size() == 2:
			best = d
			face = way
			hit_at = hit["position"]
	if face == Vector3.ZERO:
		return
	_add_vine(space, hit_at, -face, ground)
	# And across the hall, if the far wall is near enough.
	var across := space.intersect_ray(PhysicsRayQueryParameters3D.create(hit_at - face * 0.5, hit_at - face * ACROSS_MOST, 1))
	if not across.is_empty() and absf((across["normal"] as Vector3).y) < 0.3:
		var far: Vector3 = across["position"]
		if _stretch(space, far, face, ground).size() == 2:
			_add_vine(space, far, face, ground)


## The stretch of plain wall about `at` (its face, `out` from it): its two ends,
## or nothing if it is too short. Plain: the face goes on at the same depth, at
## the vine's height and low down, and nothing stands out from it (a terrace, a
## buttress) between the vine and the ground.
func _stretch(space: PhysicsDirectSpaceState3D, at: Vector3, out: Vector3, ground: float) -> Array:
	var along := out.cross(Vector3.UP).normalized()
	var ends := []
	for sign: float in [-1.0, 1.0]:
		var reach := 0.0
		var step := 0.75
		while reach + step <= STRETCH.y * 0.5:
			var probe := at + along * sign * (reach + step)
			if not _plain_at(space, probe, out, ground):
				break
			reach += step
		ends.append(at + along * sign * reach)
	if (ends[0] as Vector3).distance_to(ends[1]) < STRETCH.x:
		return []
	return ends


func _plain_at(space: PhysicsDirectSpaceState3D, probe: Vector3, out: Vector3, ground: float) -> bool:
	for y: float in [probe.y, ground + 1.2]:
		var from := Vector3(probe.x, y, probe.z) + out * 1.5
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - out * 2.5, 1))
		if hit.is_empty() or absf(((hit["position"] as Vector3) - from).dot(-out) - 1.5) > 0.35:
			return false
	# (nothing to land on under it: straight down to the ground)
	var top := probe + out * 0.9
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(top, Vector3(top.x, ground - 1.0, top.z), 1))
	return down.is_empty() or (down["position"] as Vector3).y < ground + 1.0


func _add_vine(space: PhysicsDirectSpaceState3D, at: Vector3, out: Vector3, ground: float) -> void:
	var ends := _stretch(space, at, out, ground)
	var a: Vector3 = ends[0]
	var b: Vector3 = ends[1]
	var line := SpiderMonkeyVine.new()
	line.name = "Vine%d" % troop_of.vines.size()
	line.top_level = true
	line.seed_value = _rng.randi_range(0, 999)
	var spans := maxi(2, int(a.distance_to(b) / 4.0))
	var anchors := PackedVector3Array()
	for k in spans + 1:
		var t := float(k) / spans
		var lift := _rng.randf_range(-0.25, 0.25) if k > 0 and k < spans else 0.0
		anchors.append(a.lerp(b, t) + out * 0.12 + Vector3.UP * lift)
	line.anchors = anchors
	line.sag = 0.4
	line.ground = ground
	line.away = out
	# (the first of the troop holds it; it stays where it is put)
	add_child(line)
	line.global_transform = Transform3D.IDENTITY
	line.build()
	troop_of.vines.append(line)
	troop_of.outs.append(out)
	troop_of.grounds.append(ground)


func _line() -> SpiderMonkeyVine:
	return troop_of.vines[vine] if vine < troop_of.vines.size() else null


func _out() -> Vector3:
	return troop_of.outs[vine] if vine < troop_of.outs.size() else Vector3.BACK


## Where it is when it hangs at `t` along its vine (its origin, under the hold), facing out over the hall, turned `turn` along the vine.
func _hang_at(t: float, turn: float) -> void:
	var line := _line()
	var hold := line.point_at(t)
	_pos = hold + Vector3.DOWN * SpiderMonkey.HANG_HIGH * body.size
	var out := _out()
	_yaw = atan2(out.x, out.z) + turn


## The foot of its hold, on the ground, a little out into the hall.
func _hold_foot() -> Vector3:
	var line := _line()
	var hold := line.point_at(at_t) + _out() * 0.8
	return Vector3(hold.x, troop_of.grounds[vine], hold.z)


# --- Thinking ---

func _on_spotted() -> void:
	if mode in [Mode.HANG, Mode.TRAVERSE]:
		body.chitter()


func _physics_process(delta: float) -> void:
	if puppet:
		_follow_news(delta)
		return
	if maze == null or not _ready_done:
		return
	_mode_time += delta
	_watch_below()
	_sense(delta)
	var after: Node3D = quarry if hunting() else null
	match mode:
		Mode.HANG:
			_chitter_in -= delta
			if _chitter_in <= 0.0:
				_chitter_in = _rng.randf_range(4.0, 11.0)
				body.chitter()
			if after:
				_enter(Mode.STIR)
		Mode.STIR:
			_stir(after, delta)
		Mode.WIND:
			if after:
				body.look_at_point = after.global_position + Vector3.UP
			if _mode_time >= _wind_for:
				_fling(after)
		Mode.DROP:
			_dropping(delta)
		Mode.CHASE:
			_chase(after, delta)
		Mode.LEAP:
			_leaping(delta)
		Mode.SHRIEK:
			if _mode_time > 1.6:
				_enter(Mode.HOME)
		Mode.HOME:
			_home(after, delta)
		Mode.CLIMB:
			_climb(delta)
		Mode.TRAVERSE:
			_traverse(after, delta)
		Mode.ABOUT:
			if after:
				_chase_left = CHASE_TIME * 2.0
				_enter(Mode.CHASE)
			else:
				_walk_to(goal(), WALK_SPEED, delta)
	chasing = mode in [Mode.WIND, Mode.DROP, Mode.CHASE, Mode.LEAP]
	global_position = _pos
	velocity = _vel


func _enter(next: Mode) -> void:
	mode = next
	_mode_time = 0.0


## From up its vine it sees little down the passages (MazeEnemy's sight
## starts in the face of the wall): it watches the hall below for itself.
func _watch_below() -> void:
	if hunting() or not (mode in [Mode.HANG, Mode.STIR, Mode.TRAVERSE]) or troop_of.vines.is_empty():
		return
	if Engine.get_physics_frames() % 6 != place % 6:
		return
	var foot := _hold_foot()
	var eye := foot + Vector3.UP * 1.5
	for player: Node3D in players():
		if not huntable(player):
			continue
		var at := player.global_position
		if Vector2(at.x - foot.x, at.z - foot.z).length() < DROP_RANGE * 2.2 and absf(at.y - foot.y) < 3.0 and nav.sees(eye, at + Vector3.UP, DROP_RANGE * 2.2):
			notice(player)
			return


## Stirring: watching them, rustling, swinging along the vine to keep over them; dropping when they are under it.
func _stir(after: Node3D, delta: float) -> void:
	if after == null:
		_enter(Mode.TRAVERSE)
		return
	body.look_at_point = after.global_position + Vector3.UP
	_rustle_in -= delta
	if _rustle_in <= 0.0:
		_rustle_in = _rng.randf_range(1.4, 3.2)
		_rustles += 1
		body.rustle(_rng.randf_range(0.6, 1.0))
	# Along the vine towards where they are, keeping apart from the others on it.
	var line := _line()
	var want := line.nearest(after.global_position) + (place - troop_of.members.size() * 0.5) * SPACING * 0.5 / maxf(line.length(), 1.0)
	want = _apart_on_vine(clampf(want, 0.04, 0.96))
	_swing_toward(want, delta, SWING_SPEED * 1.3)
	if _under_me(after) and _mode_time > 0.35:
		# (one after another, not all at once: the second waits a little longer)
		var going := 0
		for other: MazeSpiderMonkey in troop_of.members:
			if is_instance_valid(other) and other != self and other.mode in [Mode.WIND, Mode.DROP]:
				going += 1
		if going < 2:
			_wind_for = WIND_TIME + 0.35 * going + _rng.randf_range(0.0, 0.15)
			_shrieks += 1
			body.shriek()
			body.wind_up(_wind_for + 0.1)
			_enter(Mode.WIND)


## Whether `who` is under its hold, out in the hall and in its sight.
func _under_me(who: Node3D) -> bool:
	var foot := _hold_foot()
	var at := who.global_position
	if Vector2(at.x - foot.x, at.z - foot.z).length() > DROP_RANGE or absf(at.y - foot.y) > 2.5:
		return false
	if (at - foot).dot(_out()) < -0.6:
		return false
	return _clear_line(body.head_position(), at + Vector3.UP * 1.0)


## Swings along its vine towards `want` (0..1) at `pace` (m/s).
func _swing_toward(want: float, delta: float, pace: float) -> void:
	var line := _line()
	var step := pace * delta / maxf(line.length(), 1.0)
	var was := at_t
	at_t = move_toward(at_t, want, step)
	var going := signf(at_t - was)
	body.hold_axis = line.axis_at(at_t)
	var before := _pos
	_hang_at(at_t, going * 0.6 * minf(absf(at_t - want) / maxf(step, 0.0001), 1.0))
	_vel = (_pos - before) / maxf(delta, 0.0001)


## Moves `want` along the vine off any other of the troop on it that is nearer than SPACING.
func _apart_on_vine(want: float) -> float:
	var line := _line()
	var gap := SPACING / maxf(line.length(), 1.0)
	for other: MazeSpiderMonkey in troop_of.members:
		if other == self or not is_instance_valid(other) or other.vine != vine or not (other.mode in [Mode.HANG, Mode.STIR, Mode.TRAVERSE, Mode.WIND]):
			continue
		if absf(other.at_t - want) < gap:
			want = other.at_t + (gap if want >= other.at_t and (place > other.place or want > other.at_t) else -gap)
	return clampf(want, 0.04, 0.96)


## Lets go, flinging itself at where `who` will be when it lands.
func _fling(who: Node3D) -> void:
	_drops += 1
	_caught_one = false
	_from = _pos
	var target := _hold_foot() + _out() * 3.0
	if who and is_instance_valid(who):
		var at := who.global_position
		var going: Variant = who.get(&"velocity")
		var run := Vector3((going as Vector3).x, 0.0, (going as Vector3).z) if going is Vector3 else Vector3.ZERO
		var flat := Vector2(at.x - _from.x, at.z - _from.z).length()
		_flight = clampf(flat / 10.0 + 0.45, FLIGHT.x, FLIGHT.y)
		var lead := run * _flight
		if lead.length() > LEAD:
			lead = lead.normalized() * LEAD
		target = at + lead
	target.y = maze.ground_height(target)
	# (never into a wall: back towards the hall under it)
	var safe := _hold_foot() + _out() * 2.0
	for k in 4:
		if nav.clear_of_walls(target, 0.3):
			break
		target = target.lerp(safe, 0.5)
		target.y = maze.ground_height(target)
	_to = target
	# The arc: off and out, falling, to land there in `_flight` seconds.
	_launch = (_to - _from - Vector3.DOWN * DROP_GRAVITY * 0.5 * _flight * _flight) / _flight
	body.airborne = true
	body.hanging = false
	var flat_way := Vector3(_to.x - _from.x, 0.0, _to.z - _from.z)
	if flat_way.length() > 0.1:
		_yaw = atan2(flat_way.x, flat_way.z)
	_enter(Mode.DROP)


func _dropping(_delta: float) -> void:
	var t := minf(_mode_time, _flight)
	_pos = _from + _launch * t + Vector3.DOWN * DROP_GRAVITY * 0.5 * t * t
	_vel = _launch + Vector3.DOWN * DROP_GRAVITY * t
	if not _caught_one and _mode_time > _flight * 0.45:
		_try_catch(1.0)
	if _mode_time >= _flight:
		_pos = _to
		body.airborne = false
		if _caught_one:
			_enter(Mode.SHRIEK)
		else:
			_chase_left = CHASE_TIME
			_gather = 0.5
			_enter(Mode.CHASE)


## Has anyone where it is now (it landing on them, or its hands on them)?
func _try_catch(reach: float) -> void:
	var centre := _pos + Vector3.UP * 0.45 * body.size
	for player: Node3D in players():
		if not huntable(player):
			continue
		var at := player.global_position
		var flat := Vector2(at.x - centre.x, at.z - centre.z).length()
		var up := centre.y - at.y
		if (flat < CATCH_RADIUS * reach and up > -0.3 and up < 1.9) or body.reaches(at + Vector3.UP * 1.1, 0.55 * reach):
			_caught_one = true
			_catch(player)
			_troop_shrieks()
			return


## The troop shrieks (they have someone).
func _troop_shrieks() -> void:
	_shrieks += 1
	body.shriek()
	for other: MazeSpiderMonkey in troop_of.members:
		if is_instance_valid(other) and other != self and not other.puppet and other.global_position.distance_to(global_position) < 30.0:
			other._shrieks += 1
			other.body.shriek()
			if other.mode in [Mode.CHASE, Mode.LEAP]:
				other._enter(Mode.HOME)


func _chase(after: Node3D, delta: float) -> void:
	_chase_left -= delta
	_gather -= delta
	if after == null or _chase_left <= 0.0:
		_enter(Mode.HOME if not troop_of.vines.is_empty() else Mode.ABOUT)
		return
	var to := after.global_position - _pos
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() < 8.0 and to.y > 2.0:
		# (up out of its reach)
		_chase_left = minf(_chase_left, 0.5)
	body.look_at_point = after.global_position + Vector3.UP
	var forward := Vector3(sin(_yaw), 0.0, cos(_yaw))
	if _gather <= 0.0 and flat.length() < LEAP_RANGE and absf(to.y) < 1.2 and forward.dot(flat.normalized()) > 0.75:
		_spring(after)
		return
	_walk_to(after.global_position, CHASE_SPEED, delta)


## A bounce and a shriek, then a spring at `who`.
func _spring(who: Node3D) -> void:
	_shrieks += 1
	_rustles += 1
	body.shriek()
	body.rustle(LEAP_READY)
	_caught_one = false
	_from = _pos
	var going: Variant = who.get(&"velocity")
	var run := Vector3((going as Vector3).x, 0.0, (going as Vector3).z) if going is Vector3 else Vector3.ZERO
	var lead := run * (LEAP_READY + LEAP_TIME * 0.6)
	if lead.length() > 1.5:
		lead = lead.normalized() * 1.5
	_to = who.global_position + lead
	_vel = Vector3.ZERO
	_enter(Mode.LEAP)


func _leaping(delta: float) -> void:
	if _mode_time < LEAP_READY:
		var to := _to - _pos
		_yaw = lerp_angle(_yaw, atan2(to.x, to.z), 1.0 - exp(-14.0 * delta))
		return
	if not body.airborne:
		_from = _pos
		var flat := Vector3(_to.x - _from.x, 0.0, _to.z - _from.z)
		var reach := clampf(flat.length() + 0.3, 0.8, LEAP_RANGE + 0.8)
		_to = _from + flat.normalized() * reach
		_to.y = maze.ground_height(_to)
		_launch = (_to - _from - Vector3.DOWN * DROP_GRAVITY * 0.5 * LEAP_TIME * LEAP_TIME) / LEAP_TIME
		body.airborne = true
	var t := minf(_mode_time - LEAP_READY, LEAP_TIME)
	var next := _from + _launch * t + Vector3.DOWN * DROP_GRAVITY * 0.5 * t * t
	if nav.clear_of_walls(Vector3(next.x, 0.0, next.z), 0.2):
		_pos = next
	_vel = _launch
	if not _caught_one:
		_try_catch(0.8)
	if t >= LEAP_TIME:
		_pos.y = maze.ground_height(_pos)
		body.airborne = false
		_gather = 0.8
		_enter(Mode.SHRIEK if _caught_one else Mode.CHASE)


## Goes by the passages to `goal_at` at `pace`, on the ground.
func _walk_to(goal_at: Vector3, pace: float, delta: float) -> void:
	var to := nav.waypoint(_pos, goal_at, MazeNav.clearance_for(0.25)) - _pos
	to.y = 0.0
	var wish := to.normalized() if to.length() > 0.05 else Vector3.ZERO
	_vel = _vel.move_toward(wish * pace, 24.0 * delta)
	_vel.y = 0.0
	_pos += _vel * delta
	_pos.y = maze.ground_height(_pos)
	if _vel.length() > 0.2:
		_yaw = lerp_angle(_yaw, atan2(_vel.x, _vel.z), 1.0 - exp(-12.0 * delta))


## Back to the nearer foot of its vine's stems, and up.
func _home(after: Node3D, delta: float) -> void:
	body.look_at_point = Vector3.INF
	if troop_of.vines.is_empty():
		_enter(Mode.ABOUT)
		return
	var line := _line()
	var feet := [line.foot(0), line.foot(1)]
	_climb_end = 0 if _pos.distance_to(feet[0]) < _pos.distance_to(feet[1]) else 1
	var foot: Vector3 = feet[_climb_end] + _out() * 0.35
	var to := foot - _pos
	to.y = 0.0
	if to.length() < 0.45:
		_pos = Vector3(foot.x, maze.ground_height(foot), foot.z)
		_vel = Vector3.ZERO
		_enter(Mode.CLIMB)
		return
	_walk_to(foot, CHASE_SPEED * 0.55, delta)
	if after and _mode_time > 1.0 and after.global_position.distance_to(_pos) < LEAP_RANGE * 2.0:
		_chase_left = CHASE_TIME * 0.5
		_enter(Mode.CHASE)


## Up the stem of its vine, on the wall, to the vine.
func _climb(delta: float) -> void:
	var line := _line()
	var top := line.point_at(0.0 if _climb_end == 0 else 1.0)
	# (its body as high as it will hang, when it takes hold of the vine)
	var aim := top.y - SpiderMonkey.HANG_HIGH * body.size * 0.58
	_pos.y = move_toward(_pos.y, aim, CLIMB_SPEED * delta)
	_vel = Vector3.UP * CLIMB_SPEED
	if _pos.y >= aim - 0.01:
		at_t = 0.0 if _climb_end == 0 else 1.0
		body.hanging = true
		_enter(Mode.TRAVERSE)


func _traverse(after: Node3D, delta: float) -> void:
	if after:
		_enter(Mode.STIR)
		return
	body.look_at_point = Vector3.INF
	_swing_toward(_apart_on_vine(hold_t), delta, SWING_SPEED)
	if absf(at_t - hold_t) < 0.002:
		_vel = Vector3.ZERO
		_enter(Mode.HANG)


func _clear_line(from: Vector3, to: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var skip: Array[RID] = []
	for player: Node in players():
		if player is CollisionObject3D and is_instance_valid(player):
			skip.append((player as CollisionObject3D).get_rid())
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1, skip)).is_empty()


# --- Drawing it ---

func _process(delta: float) -> void:
	if body == null:
		return
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
	var on_vine := mode in [Mode.HANG, Mode.STIR, Mode.WIND, Mode.TRAVERSE] and not troop_of.vines.is_empty()
	body.hanging = on_vine
	body.clinging = mode == Mode.CLIMB
	body.airborne = mode == Mode.DROP or (mode == Mode.LEAP and _mode_time >= LEAP_READY)
	if on_vine:
		body.hold_axis = _line().axis_at(at_t)
	if not (mode in [Mode.STIR, Mode.WIND, Mode.CHASE, Mode.LEAP]):
		body.look_at_point = Vector3.INF
	elif puppet:
		var near := nearest_player(global_position)
		body.look_at_point = near.global_position + Vector3.UP if near else Vector3.INF
	var want: Transform3D
	if mode == Mode.CLIMB:
		var out := _out()
		want = Transform3D(Basis(out.cross(Vector3.UP), out, Vector3.UP), _pos - out * 0.3)
	else:
		want = Transform3D(Basis(Vector3.UP, _yaw), _pos)
	if not _shown_set:
		_shown = want
		_shown_set = true
	var q := _shown.basis.get_rotation_quaternion().slerp(want.basis.get_rotation_quaternion(), 1.0 - exp(-12.0 * delta))
	_shown = Transform3D(Basis(q), want.origin)
	body.global_transform = _shown


func _place_ground() -> void:
	body.hanging = false
	body.global_transform = Transform3D(Basis(Vector3.UP, _yaw), _pos)
	body.settle()


# --- Being run by someone else ---

func yaw() -> float:
	return _yaw


func net_state() -> int:
	return mode


## Counts of its drops (three bits), shrieks (three) and rustles (two).
func net_flag() -> int:
	return (_drops & 0x07) | ((_shrieks & 0x07) << 3) | ((_rustles & 0x03) << 6)


## Where along its vine it is (x, 0..1), on the vine; else none.
func net_point() -> Vector3:
	if mode in [Mode.HANG, Mode.STIR, Mode.WIND, Mode.TRAVERSE]:
		return global_position + Vector3(at_t, 1.0, 0.0)
	return Vector3.INF


var _heard_flags := -1


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	var was := mode
	mode = state as Mode
	chasing = mode in [Mode.WIND, Mode.DROP, Mode.CHASE, Mode.LEAP]
	if point.is_finite():
		at_t = clampf(point.x - at.x, 0.0, 1.0)
	if _heard_flags >= 0 and body:
		if ((flag >> 3) & 0x07) != ((_heard_flags >> 3) & 0x07):
			body.shriek()
		if ((flag >> 6) & 0x03) != ((_heard_flags >> 6) & 0x03):
			body.rustle(0.8)
		if mode == Mode.WIND and was != Mode.WIND:
			body.wind_up(WIND_TIME + 0.2)
	_heard_flags = flag


func _follow_news(delta: float) -> void:
	if not _heard:
		return
	_heard_at += _heard_moving * delta
	var at := global_position.lerp(_heard_at, 1.0 - exp(-10.0 * delta))
	if at.distance_to(_heard_at) > 3.0:
		at = _heard_at
	global_position = at
	_pos = at
	_yaw = lerp_angle(_yaw, _heard_yaw, 1.0 - exp(-12.0 * delta))


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	_pos = at
	_yaw = facing
	_shown_set = false


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 0

class_name MazeDeinonychus
extends MazeEnemy
## A deinonychus, one of a pack of three or four hunting the maze together.
## It is drawn and moved by Deinonychus (creatures/deinonychus/deinonychus.gd);
## this is what it thinks.
##
## ABOUT. The pack goes about loosely together, its first (`pack_id`'s lowest
## `rank`) choosing where and the rest following, each stopping dead now and
## then to look about in quick jerks of the head, cocking it to listen.
##
## THE HUNT. One that sees or hears someone hoots (the pack within
## `alert_range` takes up the hunt). Then they work together:
## - THE DRAWER (whichever of them is nearest) comes on openly to about
##   `hold_range` and holds there, low and crouched, its head cocked, clicking:
##   it keeps the player's eyes on it.
## - THE OTHERS (FLANKING) go round: each makes for a cell a little way off
##   the player down one of the other passages from where they are (the one
##   they are heading for first), by the maze's ways, out of sight, at a lope
##   (slower than a run). There it waits, crouched, and hoots (a higher call:
##   the answer); you can hear them going round, and answering.
## - When the flankers are all waiting (or after `set_time`), or the player
##   breaks (runs, or comes at the drawer), the drawer hoots and they all
##   BURST: a sprint faster than the boy's (`burst_speed`), which lasts only
##   `burst_time` seconds before it is TIRED (panting, slowed to
##   `tired_speed`) for `recover_time`. So a sprinter who has a clear way gets
##   away from one; it is the one coming the other way that gets you.
## - THE POUNCE. Within `pounce_range` and facing them, on the same level, it
##   crouches with its tail flicking and hisses (WIND_UP s: the warning), and
##   leaps; if its feet come down on them (`Deinonychus.claws_hit`) it PINS
##   them (the catch), wings beating; if not, it stumbles and is tired a
##   moment. A step aside, a jump or a duck into a side way as it leaps, and it
##   misses.
## THE WAY OUT IS UP. It can jump up onto a low ledge (the foot of a wall,
## up to `reach_up` over its feet), but it cannot climb: anyone on a terrace,
## up ivy, a vine, a rope or a wall top is out of its reach. It is BAFFLED:
## it circles below, looking up, leaping at the wall and hooting, and after
## `baffle_time` it gives them up for a while.
##
## `MazeDeinonychus.pack_of(count, seed)` makes a pack (each a little
## different: its size, its tint, its voice); a pack is told apart by
## `pack_id`. As a puppet it follows the host's news like the others; its
## pounces, hoots and clicks come as counts in its flag, and are played here
## too.

enum Mode { ROAM, PAUSE, STALK, FLANK, WAIT, BURST, TIRED, WIND_UP, LEAP, PIN, MISS, BAFFLED }

## The longest way round (cells) it will take to cut someone off.
const ROUND_ABOUT := 16

@export var roam_speed := 1.6
@export var stalk_speed := 1.4
## Going round to cut someone off: a lope, slower than the boy's run (4.4).
@export var flank_speed := 4.0
## Its sprint: faster than the boy's (5.6), but it lasts only `burst_time`.
@export var burst_speed := 6.4
@export var burst_time := 2.3
@export var tired_speed := 2.2
@export var recover_time := 2.8
## Within this of them it bursts.
@export var burst_range := 14.0
## The drawer holds about this far off while the others go round.
@export var hold_range := 9.0
## The longest the drawer waits for the others before it goes.
@export var set_time := 7.0
## It pounces from this far, facing them.
@export var pounce_range := 4.2
## How near its claws must come down to someone to have them.
@export var claw_reach := 0.7
## Higher than this above its feet, it cannot reach them (a wall's footing is 1.6).
@export var reach_up := 2.3
## How long it stays under someone it cannot reach before it gives them up.
@export var baffle_time := 9.0
@export var acceleration := 18.0
@export var turn_rate := 11.0
## Further than this from every player it is not posed (the walls hide it).
@export var pose_range := 70.0
@export var gravity := 24.0
## How it looks (set before it goes in; `pack_of` sets them).
@export var size := 1.0
@export var tint := Color.WHITE
@export var voice := 1.0
## Which pack it is in (the same for all of a pack, on every machine), and its place in it.
@export var pack_id := 0
@export var rank := 0

var mode := Mode.ROAM
var facing_yaw := 0.0
var dino: Deinonychus
## How much of a burst it has left, 0..1.
var stamina := 1.0

var _radius := 0.3
var _timer := 0.0
var _point := Vector3.INF
var _ambush := Vector2i(-1, -1)
## Its part in the hunt, kept while it lasts: 0 the drawer, 1, 2... going round (-1: not hunting).
var _role := -1
var _plan_in := 0.0
var _set_left := 0.0
var _went := false
var _baffled := 0.0
var _hop_in := 0.0
var _call_in := 0.0
var _pause_in := 4.0
var _leap_to := Vector3.ZERO
var _leap_way := Vector3.ZERO
var _has_one := false
var _pinned_at := Vector3.ZERO
var _pounces := 0
var _hoots := 0
var _clicks := 0
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flags := -1


## A pack of `count`, ready to be placed: each its own size, tint and voice.
static func pack_of(count: int, seed_value := 0) -> Array[MazeDeinonychus]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tints := [Color.WHITE, Color(1.06, 0.98, 0.9), Color(0.9, 0.9, 0.93), Color(1.0, 0.93, 0.86), Color(0.95, 0.95, 0.92)]
	var made: Array[MazeDeinonychus] = []
	var id := absi(seed_value) % 1000000 + 1
	for i in count:
		var one := MazeDeinonychus.new()
		one.size = rng.randf_range(0.92, 1.06)
		one.tint = tints[(i + rng.randi_range(0, 4)) % tints.size()]
		one.voice = rng.randf_range(0.9, 1.12)
		one.pack_id = id
		one.rank = i
		made.append(one)
	return made


func _init() -> void:
	sight_range = 44.0
	hear_range = 10.0
	memory = 10.0
	alert_range = 50.0
	pack = &"deinonychus"
	look_every = 0.2


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	_radius = 0.3 * size
	shape.radius = _radius
	shape.height = 1.0 * size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	dino = Deinonychus.new()
	dino.tint = tint
	dino.voice = voice
	dino.low_poly = Settings.low_poly
	dino.scale = Vector3.ONE * size
	add_child(dino)
	dino.top_level = true
	facing_yaw = rotation.y
	_prev_pos = global_position
	_curr_pos = global_position
	dino.global_position = global_position
	dino.rotation = Vector3(0.0, facing_yaw, 0.0)
	dino.settle()
	_pause_in = _rng.randf_range(2.0, 7.0)
	spotted.connect(_on_spotted)


# --- The pack ---

## The others of its pack (on this machine, thinking), itself among them.
func pack_mates() -> Array[MazeDeinonychus]:
	var mates: Array[MazeDeinonychus] = []
	for other: Node in get_tree().get_nodes_in_group(pack):
		if other is MazeDeinonychus and (other as MazeDeinonychus).pack_id == pack_id and not (other as MazeDeinonychus).puppet:
			mates.append(other)
	return mates


## Who leads the pack about: the lowest rank of it still here.
func _leader() -> MazeDeinonychus:
	var best: MazeDeinonychus = null
	for mate in pack_mates():
		if best == null or mate.rank < best.rank:
			best = mate
	return best


## The drawer says go: all of the pack after `who` burst.
func go(who: Node3D) -> void:
	if quarry == who and mode in [Mode.STALK, Mode.FLANK, Mode.WAIT, Mode.ROAM, Mode.PAUSE]:
		_went = true
		_burst()


## Its part in the hunt for `who`: the drawer if nobody of the pack is yet,
## else the next of those going round.
func _take_role(who: Node3D) -> int:
	if not _drawer_for(who):
		return 0
	var most := 0
	for mate in pack_mates():
		if mate != self and mate.quarry == who and mate.hunting():
			most = maxi(most, mate._role)
	return most + 1


## Whether another of the pack is drawing `who`.
func _drawer_for(who: Node3D) -> bool:
	for mate in pack_mates():
		if mate != self and mate.quarry == who and mate.hunting() and mate._role == 0:
			return true
	return false


## Whether all the others after `who` are waiting where they were going (or there are none).
func _others_set(who: Node3D) -> bool:
	for mate in pack_mates():
		if mate != self and mate.quarry == who and mate.hunting() and mate.mode == Mode.FLANK and mate._ambush.x >= 0:
			return false
	return true


## Where to cut `who` off: a cell a way off them down one of the passages
## from where they are, not the one the drawer is coming down, that it can
## get to by the maze's ways without passing them (round a loop of the halls);
## the `place`th (1, 2...) of those, the one they are heading for first, or
## (-1, -1) if there is no way round (then it holds off beside the drawer).
func _plan_ambush(who: Node3D, place: int) -> Vector2i:
	var here := maze.cell_at(who.global_position)
	if not maze.inside(here):
		return Vector2i(-1, -1)
	# (the passage the drawer comes along, the last step of its way to them)
	var drawer_from := Vector2i(-99, -99)
	for mate in pack_mates():
		if mate != self and mate.quarry == who and mate._role == 0:
			var path := nav.path(maze.cell_at(mate.global_position), here)
			if path.size() >= 2:
				drawer_from = path[path.size() - 2]
	var heading := Vector3(who.get(&"velocity")) if who.get(&"velocity") != null else Vector3.ZERO
	var ways: Array = []
	for step: Vector2i in Maze.STEPS:
		var next := here + step
		if maze.blocked(here, step) or not maze.inside(next) or not nav.allowed(next) or next == drawer_from:
			continue
		# (two cells on down it, where they would be in a few seconds, or the next)
		var ends: Array[Vector2i] = []
		var beyond := next + step
		if not maze.blocked(next, step) and maze.inside(beyond) and nav.allowed(beyond):
			ends.append(beyond)
		ends.append(next)
		var toward := Vector3(step.x, 0.0, step.y).dot(Vector3(heading.x, 0.0, heading.z))
		ways.append([toward, ends])
	ways.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var mine := maze.cell_at(global_position)
	var round_about: Array[Vector2i] = []
	for way_now: Array in ways:
		for end: Vector2i in way_now[1]:
			var path := nav.path(mine, end)
			if not path.is_empty() and not path.has(here) and path.size() <= ROUND_ABOUT:
				round_about.append(end)
				break
	if round_about.is_empty():
		return Vector2i(-1, -1)
	return round_about[(place - 1) % round_about.size()]


## A flanker goes round to its ambush; everyone else makes straight for them.
func goal() -> Vector3:
	if hunting() and mode == Mode.FLANK and _ambush.x >= 0:
		return nav.point(_ambush)
	if not hunting():
		var leader := _leader()
		if leader and leader != self and leader.global_position.distance_to(global_position) > 5.0:
			return leader.global_position
	return super()


# --- Thinking ---

func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze == null:
		return
	_sense(delta)
	chasing = hunting()
	var after := quarry if chasing and quarry.get(&"is_limp") != true else null
	var grounded := is_on_floor()
	_timer -= delta
	_call_in -= delta
	var wish := Vector3.ZERO
	var speed := 0.0
	match mode:
		Mode.WIND_UP:
			if after:
				_point = after.global_position + Vector3.UP * 0.8
				_face(after.global_position - global_position, delta, 0.6)
			if dino.pounce_stage() == DeinonychusRig.Pounce.LEAP:
				_leap(after)
			_steer(Vector3.ZERO, 0.0, delta, grounded)
			return
		Mode.LEAP:
			velocity.x = _leap_way.x
			velocity.z = _leap_way.z
			if not _has_one:
				for player: Node3D in players():
					if huntable(player) and dino.claws_hit(player.global_position + Vector3.UP * 0.6, claw_reach):
						_has_one = true
						_catch(player)
						_go(Mode.PIN, DeinonychusRig.PIN_TIME)
						_pinned_at = player.global_position
						dino.pin()
						velocity.x *= 0.3
						velocity.z *= 0.3
						break
			if mode == Mode.LEAP and _timer <= 0.0 and grounded:
				_go(Mode.MISS, DeinonychusRig.LAND_TIME + 0.4)
				dino.stumble()
			_move(delta, grounded)
			return
		Mode.PIN, Mode.MISS:
			# (on top of what it caught: its feet where they were)
			var onto := Vector3(_pinned_at.x - global_position.x, 0.0, _pinned_at.z - global_position.z) if mode == Mode.PIN else Vector3.ZERO
			if onto.length() > 0.5:
				_steer(onto.normalized(), minf(onto.length() * 4.0, 4.0), delta, grounded)
				return
			if _timer <= 0.0:
				if mode == Mode.PIN:
					_go(Mode.ROAM, 0.0)
				else:
					stamina = minf(stamina, 0.15)
					_go(Mode.TIRED, recover_time * 0.5)
			_steer(Vector3.ZERO, 0.0, delta, grounded)
			return
		Mode.PAUSE:
			if after or _timer <= 0.0:
				_go(Mode.ROAM, 0.0)
				_pause_in = _rng.randf_range(4.0, 11.0)
			_steer(Vector3.ZERO, 0.0, delta, grounded)
			return
	if after == null:
		# About: following the one who leads, stopping now and then to look about.
		if mode != Mode.ROAM:
			_go(Mode.ROAM, 0.0)
			_point = Vector3.INF
		_went = false
		_role = -1
		_baffled = 0.0
		stamina = minf(1.0, stamina + delta / recover_time)
		_pause_in -= delta
		if _pause_in <= 0.0:
			_go(Mode.PAUSE, _rng.randf_range(1.5, 3.5))
			return
		wish = way(_radius)
		speed = roam_speed
		var leader := _leader()
		if leader and leader != self and leader.global_position.distance_to(global_position) > 9.0:
			speed = flank_speed * 0.7
	else:
		var to := after.global_position - global_position
		var flat := Vector3(to.x, 0.0, to.z)
		var far := flat.length()
		_point = after.global_position + Vector3.UP * 1.0
		if to.y > reach_up:
			# Out of its reach: under them, looking up, leaping at the wall, and giving up in the end.
			if mode != Mode.BAFFLED:
				_go(Mode.BAFFLED, 0.0)
				_call()
			_baffled += delta
			stamina = minf(1.0, stamina + delta / recover_time)
			if _baffled > baffle_time:
				_give_up(after)
				return
			wish = way(_radius) if far > 2.5 else Vector3(-flat.z, 0.0, flat.x) * (1.0 if rank % 2 == 0 else -1.0)
			speed = (flank_speed if far > 8.0 else stalk_speed * 1.5) if far > 2.5 else 1.0
			_hop_in -= delta
			if grounded and far < 3.5 and _hop_in <= 0.0:
				_hop_in = _rng.randf_range(1.5, 3.0)
				velocity.y = sqrt(2.0 * gravity * minf(reach_up * 0.8, 1.9))
				velocity.x = flat.normalized().x * 2.0
				velocity.z = flat.normalized().z * 2.0
			if _call_in <= 0.0:
				_call()
		else:
			if mode == Mode.BAFFLED:
				_baffled = 0.0
				_burst()
			if _role < 0 or (_role > 0 and not _drawer_for(after)):
				_role = _take_role(after)
			var place := _role
			var them := Vector3(after.get(&"velocity")) if after.get(&"velocity") != null else Vector3.ZERO
			var flat_them := Vector2(them.x, them.z)
			var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
			var seen := nav.sees(global_position + Vector3.UP, after.global_position + Vector3.UP, sight_range)
			# (a player breaking: running off, or coming at it)
			var breaking := flat_them.length() > 4.0 or (flat_them.length() > 1.5 and flat_them.normalized().dot(-Vector2(flat.x, flat.z).normalized()) > 0.6 and far < hold_range * 0.7)
			if mode in [Mode.BURST, Mode.TIRED]:
				pass
			elif place == 0:
				if mode != Mode.STALK:
					_go(Mode.STALK, 0.0)
					_set_left = set_time if pack_mates().size() > 1 else 1.5
				_set_left -= delta
				if (seen and (breaking or far < hold_range * 0.55)) or _set_left <= 0.0 or (_others_set(after) and seen and far < hold_range * 1.3 and _set_left < set_time - 2.0):
					_hoot(0.92)
					for mate in pack_mates():
						mate.go(after)
					_burst()
			else:
				if mode not in [Mode.FLANK, Mode.WAIT]:
					_go(Mode.FLANK, 0.0)
					_plan_in = 0.0
				_plan_in -= delta
				if _plan_in <= 0.0:
					_plan_in = 2.0
					_ambush = _plan_ambush(after, place)
				if _ambush.x < 0:
					# (no way round: it holds off with the drawer, and goes when it goes)
					if mode != Mode.WAIT:
						_go(Mode.WAIT, 0.0)
				elif mode == Mode.FLANK and Vector2(nav.point(_ambush).x - global_position.x, nav.point(_ambush).z - global_position.z).length() < Maze.CELL * 0.35:
					_go(Mode.WAIT, 0.0)
					_hoot(1.18)
				if seen and far < burst_range * 0.8 and mode == Mode.WAIT:
					_burst()
				elif seen and far < hold_range * 0.5:
					_burst()
			match mode:
				Mode.STALK:
					# The drawer: on to `hold_range`, then holds there in their sight, clicking.
					if far > hold_range or not seen:
						wish = way(_radius)
						speed = flank_speed if far > hold_range * 1.5 else stalk_speed
					else:
						_face(flat, delta, 0.6)
					if _call_in <= 0.0:
						_call_in = _rng.randf_range(1.2, 2.4)
						_clicks += 1
						dino.click()
				Mode.FLANK:
					wish = way(_radius)
					speed = flank_speed
				Mode.WAIT:
					if _ambush.x < 0 and (far > hold_range + 3.0 or not seen):
						wish = way(_radius)
						speed = flank_speed if far > hold_range * 1.5 else stalk_speed
					else:
						_face(flat, delta, 0.5)
				Mode.BURST, Mode.TIRED:
					if mode == Mode.BURST:
						stamina -= delta / burst_time
						if stamina <= 0.0:
							stamina = 0.0
							_go(Mode.TIRED, recover_time)
					else:
						stamina = minf(1.0, stamina + delta / recover_time)
						if _timer <= 0.0 and stamina > 0.8:
							_burst()
					wish = way(_radius)
					speed = burst_speed if mode == Mode.BURST else tired_speed
					# (closing in, straight at them if nothing is in the way)
					if far < 8.0 and nav.line_free(global_position, after.global_position, _radius):
						wish = flat
					if grounded and far < pounce_range * size and to.y > -1.5 and forward.dot(flat.normalized()) > 0.8 and mode == Mode.BURST:
						_wind_up(after)
						_steer(Vector3.ZERO, 0.0, delta, grounded)
						return
					# Up onto a low ledge after them.
					if grounded and to.y > 0.6 and far < 3.5:
						velocity.y = sqrt(2.0 * gravity * (to.y + 0.35))
	var push := _apart(_radius)
	if wish.length() > 0.01:
		wish = wish.normalized()
		if push != Vector3.ZERO:
			wish = (wish + push * 0.6).normalized()
	_steer(wish, speed, delta, grounded)


func _go(to: Mode, seconds: float) -> void:
	mode = to
	_timer = seconds


func _burst() -> void:
	if stamina < 0.3:
		_go(Mode.TIRED, recover_time * (1.0 - stamina))
	else:
		_go(Mode.BURST, 0.0)


func _call() -> void:
	_call_in = _rng.randf_range(2.0, 4.0)
	_hoot(_rng.randf_range(0.9, 1.15))


func _hoot(pitch: float) -> void:
	_hoots += 1
	dino.hoot(pitch)


func _give_up(who: Node3D) -> void:
	_spared[who] = baffle_time
	quarry = null
	_forget = 0.0
	_last_seen = Vector3.INF
	_baffled = 0.0
	_go(Mode.ROAM, 0.0)


## Crouches to spring at `who` (the wind-up: WIND_UP seconds).
func _wind_up(who: Node3D) -> void:
	_go(Mode.WIND_UP, 0.0)
	_pounces += 1
	_has_one = false
	_leap_to = who.global_position
	velocity.x = 0.0
	velocity.z = 0.0
	dino.pounce()


## The leap: at where they were at the end of the wind-up, a little past (it cannot steer once it is off).
func _leap(who: Node3D) -> void:
	if who:
		_leap_to = who.global_position
	var to := _leap_to - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	var distance := clampf(flat.length() + 0.6, 1.5, pounce_range * size + 1.2)
	var way_now := forward.slerp(flat.normalized(), 0.6).normalized() if flat.length() > 0.1 else forward
	_leap_way = way_now * distance / DeinonychusRig.LEAP_TIME
	var t := DeinonychusRig.LEAP_TIME
	velocity = Vector3(_leap_way.x, (clampf(to.y, -1.0, reach_up) + 0.5 * gravity * t * t * 0.7) / t, _leap_way.z)
	_go(Mode.LEAP, t)


func _steer(wish: Vector3, speed: float, delta: float, grounded: bool) -> void:
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, acceleration * delta)
	velocity.x = current.x
	velocity.z = current.z
	if current.length() > 0.3:
		_face(current, delta)
	_move(delta, grounded)


func _move(delta: float, grounded: bool) -> void:
	if not grounded or velocity.y > 0.0:
		velocity.y -= gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _face(toward: Vector3, delta: float, rate := 1.0) -> void:
	if Vector2(toward.x, toward.z).length_squared() < 0.0001:
		return
	facing_yaw = lerp_angle(facing_yaw, atan2(toward.x, toward.z), 1.0 - exp(-turn_rate * rate * delta))


func _on_spotted(_player: Node3D) -> void:
	if puppet or mode in [Mode.WIND_UP, Mode.LEAP, Mode.PIN]:
		return
	_hoot(1.0)
	_call_in = 1.5


## Told by its pack: it joins the hunt (and the drawer will place it).
func alerted(player: Node3D, from: Vector3) -> void:
	super(player, from)
	if mode in [Mode.ROAM, Mode.PAUSE]:
		_go(Mode.FLANK, 0.0)
		_plan_in = 0.0


# --- What it looks like ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			dino.visible = not far
			dino.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
			if not far:
				dino.settle()
	if _far:
		return
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-12.0 * delta))
	dino.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	dino.rotation = Vector3(0.0, facing_yaw, 0.0)
	dino.grounded = (is_on_floor() and mode != Mode.LEAP) or (puppet and mode != Mode.LEAP)
	dino.crouching = mode in [Mode.STALK, Mode.WAIT]
	dino.tired = mode == Mode.TIRED
	dino.cocking = mode in [Mode.STALK, Mode.PAUSE, Mode.BAFFLED]
	var point := _heard_extra if puppet else _point
	dino.look_at_point = point if mode not in [Mode.ROAM, Mode.FLANK] or not point.is_finite() or global_position.distance_to(point) < 20.0 else Vector3.INF


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Pounces (low four bits), hoots (next two), clicks (top two).
func net_flag() -> int:
	return (_pounces & 0x0f) | ((_hoots & 0x03) << 4) | ((_clicks & 0x03) << 6)


func net_point() -> Vector3:
	return _point if chasing else Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode not in [Mode.ROAM, Mode.PAUSE]
	if _heard_flags >= 0 and dino:
		if (flag & 0x0f) != (_heard_flags & 0x0f):
			dino.pounce()
		if ((flag >> 4) & 0x03) != ((_heard_flags >> 4) & 0x03):
			dino.hoot(1.0)
		if ((flag >> 6) & 0x03) != ((_heard_flags >> 6) & 0x03):
			dino.click()
	_heard_flags = flag


func _heard_changed(_was: int, now: int, first: bool) -> void:
	if dino == null or first:
		return
	if now == Mode.PIN:
		dino.pin()
	elif now == Mode.MISS:
		dino.stumble()


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if dino:
		dino.global_position = at
		dino.settle()


func _puppet_changed() -> void:
	collision_layer = 4
	collision_mask = 1 if puppet else 1 | 4

class_name MazeHarpy
extends MazeEnemy
## A harpy (creatures/harpy/: a starved woman's head and trunk on great ragged
## wings and a raptor's legs) set to hunt the maze from above. This is only its
## thinking; how it looks, moves and sounds is the `Harpy` component.
##
## - IT PERCHES high on a wall: on the ledge along the wall if there is one,
##   else on the wall top, at the edge, hunched, facing out over the hall. It
##   is put in a cell and finds the nearest wall itself (rays, four ways), the
##   first moment it is in the world. It watches the halls below (a line of
##   sight, `sight_range`), its wings mantled when it has seen someone.
## - IT SCREECHES when it sees someone out in the open: it turns to them and
##   screeches (Harpy.screech, `SCREECH_TIME`), the first warning. Then it
##   takes off, out from the wall and up over the wall tops.
## - IT CIRCLES high over them, over the walls (it flies over them: it can come
##   from anywhere), for `circle_time`, and picks its way in: a hall running
##   straight from them for at least `MIN_RUN` with open sky over it.
## - IT STOOPS: a falling cry (Harpy.cry), the second warning; it slides over
##   the far end of that hall and folds its wings back; then it dives into the
##   hall, flattens out at chest height and comes down the hall at them, talons
##   first (the legs thrown forward `TALONS_AT` before it reaches them). It
##   aims where they will be until `LOCK_TIME` before it reaches them; after
##   that its line is set: a sidestep of a metre or so, or getting low (duck,
##   slide, crawl, roll), and the talons pass by or over. If they close on
##   someone, `caught(player)`: snatched.
## - Whatever happens it climbs away, flapping hard, back up over the walls;
##   circles again (at most `swoops` dives in all), or flies back to its perch
##   and lands, talons forward, braking.
## - IT LOSES THEM under cover: anyone with something over their head (a platform,
##   a bridge), or in a slot too narrow for its wings (`SLOT`), or with no hall
##   for it to come down (straight, open to the sky, and wider than its wings,
##   `WINGS_ROOM`, all the way along), cannot be dived at; it circles on, and if they stay
##   so for `lose_time` it gives up and goes home. A dive already begun is
##   broken off if they get under cover before its line is set. It never goes
##   after anyone in the clearing.
##
## Online, the host thinks; a puppet follows its news (where it is, what it is
## doing, the point of its dive or its perch), screeching and crying when the
## host's does. Catching is the host's alone.
##
## Spawn (as MazeEnemies does any MazeEnemy): `MazeHarpy.new()`, `maze` set,
## put in a passage cell beside a high wall, added to the scene.

## What it is doing, as sent (`net_state`).
enum Mode { PERCH, SCREECH, RISE, CIRCLE, STOOP, DIVE, CLIMB, RETURN, LAND }

## How much bigger than it is modelled it is drawn (about 4.5 m across the wings).
const SIZE := 1.15
const SCREECH_TIME := 2.1
## The hall it comes down: at least this long straight from them, at most this far off.
const MIN_RUN := 13.0
const MAX_RUN := 24.0
## Narrower than this (metres between walls, either way) is a slot it cannot get into.
const SLOT := 5.0
## How wide a hall must be, wall to wall, all along its dive (its wings are about 4.5 m across).
const WINGS_ROOM := 6.5
## Above the wall tops, as it circles and comes and goes.
const OVER_WALLS := 6.0
const CIRCLE_RADIUS := 11.0
const CIRCLE_SPEED := 9.0
## Its speed sliding over the hall's end before the dive, and in the dive.
const STOOP_SPEED := 15.0
const DIVE_SPEED := 19.0
## In the dive: the legs come forward this long before it reaches them; its line is set this long before.
const TALONS_AT := 0.7
const LOCK_TIME := 0.45
## Where along them its talons pass (above their feet: the middle of its two
## feet, as the dive aims it), and how near that must come to take them.
const STRIKE_HEIGHT := 1.15
const CATCH_RADIUS := 0.4
## How tall they count as, standing and low (the boy: Player.stand_height, crouch_height).
const TALL := 1.25
const LOW := 0.72
const CLIMB_SPEED := 7.0
const FLY_SPEED := 11.0
## Seconds of each.
const RISE_OUT := 0.8
const LAND_TIME := 1.1
const FACES: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]

## How long it circles before it dives, seconds (least, most).
@export var circle_time := Vector2(3.0, 5.0)
## How many dives before it goes home.
@export var swoops := 2
## How long they may stay under cover before it gives up on them.
@export var lose_time := 6.0
## Further than this from every player it is not posed or drawn.
@export var pose_range := 120.0

var mode := Mode.PERCH
## The creature.
var look: Harpy
## Where it perches, and which way is out from its wall.
var perch := Vector3.INF
var perch_out := Vector3.BACK
## The dive: the end of the hall it comes in over (on the ground), the way down
## the hall to them, and the point it is making for (its talons at their chest).
var dive_from := Vector3.INF
var dive_along := Vector3.ZERO
var dive_at := Vector3.INF
## Whether its last dive took someone.
var snatched := false

var _mode_time := 0.0
var _placed := false
var _heading := Vector3.FORWARD
var _circle_angle := 0.0
var _circle_left := 0.0
var _altitude := 45.0
var _dives := 0
var _hidden := 0.0
var _locked := false
var _dive_high := Vector3.ZERO
var _dive_t := 0.0
var _passed := false
var _calls := 0
var _heard_calls := -1
var _far := false
var _far_check := 0.0
var _from := Vector3.ZERO
var _watch := 0.0
var _shift := Vector3.ZERO
## How near its talons came to whoever it last dived at (for tests).
var closest := INF
var closest_at := Vector3.ZERO
var _last_talons := PackedVector3Array()
## How far it can carry on past them before the hall ends.
var _overshoot := 8.0
## Where its talons are from its middle as it strikes, facing +Z.
var _strike_offset := Vector3(0.0, -0.35, 0.3)


func _init() -> void:
	sight_range = 70.0
	hear_range = 0.0
	memory = 8.0
	alert_range = 0.0
	pack = &"harpies"
	look_every = 0.25


func _ready() -> void:
	add_to_group(&"pursuers")
	# It flies: nothing bumps into it, and it bumps into nothing.
	collision_layer = 0
	collision_mask = 0
	look = Harpy.new()
	look.name = "Look"
	look.seed_value = _rng.seed
	look.top_level = true
	look.scale = Vector3.ONE * SIZE
	add_child(look)
	look.global_position = global_position
	look.rotation.y = 0.0
	# Where its talons are, from its middle, when it strikes (facing +Z): what it steers by in a dive.
	look.hold({"perched": 0.0, "mantle": 0.0, "effort": 0.3, "brake": 0.0, "stoop": 0.0, "talons": 1.0, "grip": 0.0})
	var middle := Vector3.ZERO
	var points := look.talon_points()
	for p in points:
		middle += p
	_strike_offset = middle / maxf(points.size(), 1.0) - look.global_position
	look.rotation.y = rotation.y
	look.settle()
	_heading = Vector3(sin(rotation.y), 0.0, cos(rotation.y))


# --- Thinking ---

func _physics_process(delta: float) -> void:
	_cull(delta)
	if puppet:
		_follow_news(delta)
		_drive_look(delta)
		return
	if maze == null:
		return
	if not _placed:
		_placed = true
		_go_to_perch(true)
	_mode_time += delta
	_spare(delta)
	var before := global_position
	match mode:
		Mode.PERCH:
			_perched(delta)
		Mode.SCREECH:
			_screeching(delta)
		Mode.RISE:
			_rise(delta)
		Mode.CIRCLE:
			_circle(delta)
		Mode.STOOP:
			_stoop(delta)
		Mode.DIVE:
			_dive(delta)
		Mode.CLIMB:
			_climb(delta)
		Mode.RETURN:
			_return(delta)
		Mode.LAND:
			_land(delta)
	velocity = (global_position - before) / delta
	chasing = mode in [Mode.CIRCLE, Mode.STOOP, Mode.DIVE]
	_drive_look(delta)


## Counts down the time each caught player is let alone (as MazeEnemy's senses do, which it does not use).
func _spare(delta: float) -> void:
	for player: Variant in _spared.keys():
		if not is_instance_valid(player):
			_spared.erase(player)
			continue
		_spared[player] -= delta
		if _spared[player] <= 0.0:
			_spared.erase(player)


func _enter(next: Mode) -> void:
	mode = next
	_mode_time = 0.0


## Whether it can see `player` from where it is (a line of sight, through nothing).
func _sees(player: Node3D) -> bool:
	var eye := global_position + Vector3.UP * 0.6
	var at := player.global_position + Vector3.UP * 1.2
	if eye.distance_to(at) > sight_range:
		return false
	return _clear_line(eye, at)


## Whether `player` can be dived at: out in the open, in a hall it can get down
## into, not in a slot nor under anything, not in the clearing.
func exposed(player: Node3D) -> bool:
	if not huntable(player) or maze.in_clearing(maze.cell_at(player.global_position)):
		return false
	return not _run_for(player).is_empty()


## The way in to `player`: [the far end of the hall on the ground, the way
## along it to them], or [] if there is none (under cover, in a slot).
func _run_for(player: Node3D) -> Array:
	var feet := player.global_position
	var head := feet + Vector3.UP * 1.7
	# Something over their head?
	if not _clear_line(head, head + Vector3.UP * (_altitude + 10.0)):
		return []
	# In a slot?
	var waist := feet + Vector3.UP * 1.0
	var widths: Array[float] = []
	for face in FACES:
		widths.append(_free(waist, face, 30.0))
	if minf(widths[0] + widths[1], widths[2] + widths[3]) < SLOT:
		return []
	# The longest straight hall from them that it can come down.
	var best: Array = []
	var longest := 0.0
	for k in FACES.size():
		var face := FACES[k]
		var run := minf(_free(waist + Vector3.UP * 0.2, face, MAX_RUN + 2.0), _free(feet + Vector3.UP * 5.0, face, MAX_RUN + 2.0)) - 2.0
		if run < MIN_RUN or run <= longest:
			continue
		var end := feet + face * run
		# (open sky over the end of the hall, to come down into)
		if not _clear_line(end + Vector3.UP * 3.0, end + Vector3.UP * (_altitude + 5.0)):
			continue
		# (and wide enough for its wings all the way along, low and high: no slots)
		if not _wide_all_along(feet, face, run):
			continue
		longest = run
		best = [end, -face]
	return best


## Whether the hall from `feet` along `way` for `run` metres is wider than its
## wings (`WINGS_ROOM` between the walls) all the way, at its height on the way
## in (2 m) and higher up where it comes down (8 m).
func _wide_all_along(feet: Vector3, way: Vector3, run: float) -> bool:
	var across := way.cross(Vector3.UP)
	var at := 0.0
	while at <= run:
		for high: float in [2.0, 8.0]:
			var p := feet + way * at + Vector3.UP * high
			if _free(p, across, WINGS_ROOM) + _free(p, -across, WINGS_ROOM) < WINGS_ROOM:
				return false
		at += 3.0
	return true


## How far a ray goes from `from` along `way` before it meets the world (at most `far`).
func _free(from: Vector3, way: Vector3, far: float) -> float:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + way * far, 1, _skip_players()))
	return far if hit.is_empty() else from.distance_to(hit["position"])


func _perched(delta: float) -> void:
	global_position = perch
	_watch -= delta
	if _watch > 0.0:
		return
	_watch = look_every
	var seen: Node3D = null
	var nearest := INF
	for player: Node3D in players():
		if not exposed(player) or not _sees(player):
			continue
		var d := player.global_position.distance_to(global_position)
		if d < nearest:
			nearest = d
			seen = player
	if seen:
		notice(seen)
		_calls += 1
		look.screech()
		_enter(Mode.SCREECH)


func _screeching(_delta: float) -> void:
	global_position = perch
	if _mode_time >= SCREECH_TIME:
		_take_off()


func _take_off() -> void:
	_from = global_position
	_altitude = _base_altitude(global_position)
	_enter(Mode.RISE)


## How high it flies over the maze about `at`: over its ring's walls.
func _base_altitude(at: Vector3) -> float:
	return maze.maze_wall_height(maze.ring_of(maze.cell_at(at))) + OVER_WALLS


## Never lower than whatever is under it (a higher wall it comes over): it rises over it.
func _keep_over(delta: float) -> void:
	var under := _sky_over(global_position + Vector3(_heading.x, 0.0, _heading.z) * 3.0) + 2.0
	if global_position.y < under:
		global_position.y = move_toward(global_position.y, under, CLIMB_SPEED * 3.0 * delta)


## Out from the wall, then straight up the hall to over the walls.
func _rise(delta: float) -> void:
	var out := perch_out if perch.is_finite() else Vector3.ZERO
	if _mode_time < RISE_OUT:
		var t := _mode_time / RISE_OUT
		global_position = _from + out * 3.5 * smoothstep(0.0, 1.0, t) + Vector3.UP * 2.0 * t * t
		_face(out, delta, 6.0)
		return
	global_position.y = move_toward(global_position.y, _altitude, CLIMB_SPEED * delta)
	if global_position.y >= _altitude - 0.05:
		_start_circling()


func _start_circling() -> void:
	_circle_left = _rng.randf_range(circle_time.x, circle_time.y)
	if quarry:
		var off := global_position - quarry.global_position
		_circle_angle = atan2(off.z, off.x)
		_altitude = _base_altitude(quarry.global_position)
	_shift = Vector3.ZERO
	_enter(Mode.CIRCLE)


func _circle(delta: float) -> void:
	if quarry == null or not huntable(quarry) or maze.in_clearing(maze.cell_at(quarry.global_position)):
		_go_home()
		return
	_forget = memory
	var centre := quarry.global_position + _shift
	_circle_angle += CIRCLE_SPEED / CIRCLE_RADIUS * delta
	var want := centre + Vector3(cos(_circle_angle), 0.0, sin(_circle_angle)) * CIRCLE_RADIUS
	want.y = _altitude
	# (its circle is pushed off anything higher than it flies: the clearing's great wall)
	if _sky_over(want) > _altitude - 3.0:
		var away := Vector3(centre.x - want.x, 0.0, centre.z - want.z).normalized()
		_shift += away * 12.0 * delta
	else:
		_shift = _shift.move_toward(Vector3.ZERO, 1.5 * delta)
	var to := want - global_position
	global_position += to.limit_length(FLY_SPEED * 1.6 * delta) if to.length() > 0.01 else Vector3.ZERO
	_keep_over(delta)
	_face(Vector3(-sin(_circle_angle), 0.0, cos(_circle_angle)), delta, 3.0)
	_circle_left -= delta
	var run := _run_for(quarry)
	if run.is_empty():
		_hidden += delta
		if _hidden > lose_time:
			_go_home()
		return
	_hidden = 0.0
	if _circle_left <= 0.0:
		_commit(run)


## Sets out on a dive down `run`: the second warning.
func _commit(run: Array) -> void:
	dive_from = run[0]
	dive_along = run[1]
	_dive_high = Vector3(dive_from.x, _altitude, dive_from.z)
	_locked = false
	_passed = false
	snatched = false
	_dives += 1
	_calls += 1
	closest = INF
	look.cry()
	_from = global_position
	_enter(Mode.STOOP)


## Slides over the end of the hall at its height, wings folding back.
func _stoop(delta: float) -> void:
	if quarry == null or not huntable(quarry) or _run_for(quarry).is_empty():
		_hidden += delta
		_break_off()
		return
	var to := _dive_high - global_position
	global_position += to.limit_length(STOOP_SPEED * delta)
	_face(dive_along, delta, 5.0)
	if to.length() < 0.5:
		_dive_t = 0.0
		_from = global_position
		_last_talons = PackedVector3Array()
		_overshoot = 8.0
		_enter(Mode.DIVE)


## Down into the hall and along it at them: a curve from over the hall's end
## (`_from`), past its foot, to where their chest will be (`dive_at`).
func _dive(delta: float) -> void:
	var aim_left := _time_to_target()
	if not _locked and quarry:
		if not huntable(quarry) or _run_for(quarry).is_empty():
			_break_off()
			return
		dive_at = _lead(quarry, aim_left)
		if aim_left <= LOCK_TIME:
			_locked = true
			_overshoot = clampf(_free(dive_at, dive_along, 12.0) - 2.5, 0.0, 8.0)
	var low := dive_from + Vector3.UP * 2.0
	var length := _from.distance_to(low) + low.distance_to(dive_at)
	_dive_t = minf(_dive_t + DIVE_SPEED * delta / maxf(length, 1.0), 1.15)
	var t := minf(_dive_t, 1.0)
	var at := _from * (1.0 - t) * (1.0 - t) + low * 2.0 * t * (1.0 - t) + dive_at * t * t
	if _dive_t > 1.0:
		# (past them, on along the hall, as far as it goes)
		at = dive_at + dive_along * minf((_dive_t - 1.0) * length, _overshoot)
	var moved := at - global_position
	global_position = at
	if moved.length() > 0.001:
		_face(moved, delta, 12.0)
	_strike()
	if _dive_t >= 1.15:
		_from = global_position
		_enter(Mode.CLIMB)


## Seconds until it reaches the point of its dive.
func _time_to_target() -> float:
	if not dive_at.is_finite():
		return 9.0
	var low := dive_from + Vector3.UP * 2.0
	var length := _from.distance_to(low) + low.distance_to(dive_at)
	return maxf(0.0, (1.0 - _dive_t) * length / DIVE_SPEED)


## Where its talons should meet `player`: where they will be in `seconds` (most of the way), at their chest.
func _lead(player: Node3D, seconds: float) -> Vector3:
	var moving: Variant = player.get(&"velocity")
	var v: Vector3 = moving if moving is Vector3 else Vector3.ZERO
	v.y = 0.0
	var at := player.global_position + v * minf(seconds, 1.2) * 0.8
	# (it comes down the hall: no nearer the hall's end than it can turn in)
	var along := (at - dive_from).dot(dive_along)
	if along < 6.0:
		at += dive_along * (6.0 - along)
	return at + Vector3.UP * STRIKE_HEIGHT - _strike_turned()


## Where its talons are from its middle as it strikes, facing down the hall.
func _strike_turned() -> Vector3:
	return Basis(Vector3.UP, atan2(dive_along.x, dive_along.z)) * _strike_offset


## Whether its talons take anyone as they pass.
func _strike() -> void:
	var all := _talons()
	var middle := Vector3.ZERO
	for p in all:
		middle += p
	var now := PackedVector3Array([middle / maxf(all.size(), 1.0)])
	var was := _last_talons
	_last_talons = now
	if snatched or _time_to_target() > TALONS_AT * 0.6 or _dive_t > 1.08:
		return
	# (where they went since the last frame: at this speed a frame is a third of a metre)
	var points := PackedVector3Array()
	for i in now.size():
		for k in 4:
			points.append(was[i].lerp(now[i], (k + 1) / 4.0) if was.size() == now.size() else now[i])
	for player: Node3D in players():
		if not huntable(player):
			continue
		var feet := player.global_position
		var top := LOW if is_low(player) else TALL
		for p in points:
			var d := _to_segment(p, feet + Vector3.UP * 0.25, feet + Vector3.UP * top)
			if player == quarry and d < closest:
				closest = d
				closest_at = p - feet
			if d < CATCH_RADIUS:
				snatched = true
				_catch(player)
				return


## Where its talons are: the creature's, where it is drawn; otherwise, below its middle.
func _talons() -> PackedVector3Array:
	if look and look.visible and look.is_inside_tree():
		return look.talon_points()
	return PackedVector3Array([global_position + Basis(Vector3.UP, atan2(_heading.x, _heading.z)) * _strike_offset])


## Whether `player` is down low (ducking, crawling, sliding, rolling, diving): the talons pass over.
static func is_low(player: Node3D) -> bool:
	if player.get(&"is_ducking") == true or player.get(&"is_crawling") == true or player.get(&"is_diving") == true:
		return true
	if player is Player:
		var boy := player as Player
		if boy.state == Player.State.SLIDE:
			return true
		if boy.landing == Player.Landing.ROLL and boy.landing_progress < 1.0:
			return true
	return false


static func _to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## A dive broken off (they got under cover): it pulls up and climbs.
func _break_off() -> void:
	_from = global_position
	_enter(Mode.CLIMB)


## Flapping hard, straight up out of the hall to over the walls.
func _climb(delta: float) -> void:
	_altitude = maxf(_altitude, _base_altitude(global_position))
	var forward := Vector3(_heading.x, 0.0, _heading.z)
	var slow := maxf(0.0, 1.0 - _mode_time / 0.8)
	if _free(global_position, forward, 3.0) < 2.5:
		slow = 0.0
	global_position += forward * DIVE_SPEED * 0.5 * slow * delta
	global_position.y = move_toward(global_position.y, _altitude, CLIMB_SPEED * 1.3 * delta)
	if global_position.y >= _altitude - 0.05:
		if quarry and huntable(quarry) and _dives < swoops and not snatched:
			_start_circling()
		else:
			_go_home()


func _go_home() -> void:
	quarry = null
	_forget = 0.0
	_hidden = 0.0
	_altitude = maxf(_altitude, _base_altitude(perch))
	_enter(Mode.RETURN)


## Over the walls to above its perch's hall, then down it.
func _return(delta: float) -> void:
	if not perch.is_finite():
		_go_to_perch(false)
		if not perch.is_finite():
			return
	var over := perch + perch_out * 4.0
	var high := Vector3(over.x, maxf(_altitude, global_position.y), over.z)
	var flat := Vector3(high.x - global_position.x, 0.0, high.z - global_position.z)
	if flat.length() > 0.3:
		global_position.y = move_toward(global_position.y, _altitude, CLIMB_SPEED * delta)
		global_position += flat.limit_length(FLY_SPEED * delta)
		_face(flat, delta, 3.0)
		_keep_over(delta)
		return
	# Down the hall in front of the perch.
	global_position = Vector3(over.x, move_toward(global_position.y, perch.y + 2.5, CLIMB_SPEED * 1.2 * delta), over.z)
	_face(-perch_out, delta, 3.0)
	if global_position.y <= perch.y + 2.55:
		_from = global_position
		_enter(Mode.LAND)


## In to the perch, braking, talons forward.
func _land(delta: float) -> void:
	var t := clampf(_mode_time / LAND_TIME, 0.0, 1.0)
	var e := t * t * (3.0 - 2.0 * t)
	global_position = _from.lerp(perch, e) + Vector3.UP * sin(PI * e) * 0.6
	_face(-perch_out, delta, 6.0)
	if t >= 1.0:
		global_position = perch
		_dives = 0
		_enter(Mode.PERCH)


## Finds its perch near where it is (or, at `now`, goes straight there, for the start).
func _go_to_perch(now: bool) -> void:
	var found := _find_perch(global_position)
	if found.is_empty() and maze:
		# (nothing from here: from the cells round about)
		var here: Vector2i = maze.cell_at(global_position)
		for step: Vector2i in Maze.STEPS:
			for k in [1, 2]:
				if found.is_empty() and maze.inside(here + step * k):
					found = _find_perch(maze.world(here + step * k))
	if found.is_empty():
		# (no wall near enough: it stands where it was put)
		perch = global_position + Vector3.UP * look.stand_height()
		perch_out = _heading
	else:
		perch = found[0]
		perch_out = found[1]
	if now:
		global_position = perch
		_heading = perch_out
		_enter(Mode.PERCH)


## The perch nearest `from`: on the ledge along a wall face if there is one, else
## the top of the wall, near its edge: [where it stands (its middle), out from the wall], or [].
func _find_perch(from: Vector3, reach := 40.0) -> Array:
	var space := get_world_3d().direct_space_state
	var ground := maze.ground_height(from) if maze else from.y
	var best: Array = []
	var nearest := INF
	for face in FACES:
		var low := Vector3(from.x, ground + 2.5, from.z)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(low, low + face * reach, 1, _skip_players()))
		if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.3:
			continue
		var d := low.distance_to(hit["position"])
		if d >= nearest:
			continue
		var out := -face
		var foot: Vector3 = hit["position"]
		# It watches over a hall: room out in front of the wall, wide enough, open to the sky.
		var ahead := foot + out * 6.0 + Vector3.UP * 1.0
		var across := out.cross(Vector3.UP)
		if _free(foot + out * 0.3 + Vector3.UP * 1.0, out, 12.0) < 10.0 or _free(ahead, across, 20.0) + _free(ahead, -across, 20.0) < SLOT * 2.0:
			continue
		if not _clear_line(ahead + Vector3.UP * 1.0, ahead + Vector3.UP * 120.0):
			continue
		# How high is this wall? (down onto its top from high above, at points
		# further and further into it: the highest is its top)
		var top_y := -INF
		for inset: float in [0.4, 1.0, 1.8, 3.0, 5.0]:
			var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(foot - out * inset + Vector3.UP * 300.0, foot - out * inset + Vector3.UP * (ground + 1.0), 1))
			if not down.is_empty():
				top_y = maxf(top_y, (down["position"] as Vector3).y)
		if top_y - ground < 8.0:
			continue
		# Where its face is up there (the wall may step back above a ledge).
		var high := Vector3(foot.x, top_y - 0.8, foot.z) + out * 6.0
		var upper := space.intersect_ray(PhysicsRayQueryParameters3D.create(high, high - out * 12.0, 1))
		var upper_face: Vector3 = upper["position"] if not upper.is_empty() else foot
		var set_back := (upper_face - foot).dot(-out)
		var spot := Vector3.INF
		# A ledge to perch on: a step of the wall, between its lower face and the face above
		# it; or a ledge standing out over the hall.
		var probes: Array[Vector3] = []
		if set_back > 0.7:
			probes.append(foot - out * minf(set_back * 0.5, 0.7))
		probes.append(foot + out * 0.55)
		for at: Vector3 in probes:
			var ledge := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, top_y - 1.0, at.z), Vector3(at.x, ground + 4.0, at.z), 1))
			if not ledge.is_empty() and (ledge["normal"] as Vector3).y > 0.7 and (ledge["position"] as Vector3).y > ground + 5.0:
				spot = ledge["position"]
				break
		if not spot.is_finite():
			# Else the wall top, near the edge of its face.
			spot = Vector3(upper_face.x, top_y, upper_face.z) - out * 0.7
		nearest = d
		best = [spot + Vector3.UP * Harpy.STAND_HEIGHT * SIZE, out]
	return best


## How high the world is under a point (the top of a wall, or the ground), from high above.
func _sky_over(at: Vector3) -> float:
	var from := Vector3(at.x, 400.0, at.z)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(at.x, -50.0, at.z), 1))
	return (hit["position"] as Vector3).y if not hit.is_empty() else 0.0


## The highest the world is round a circle about `at`.
func _sky_round(at: Vector3, radius: float) -> float:
	var top := _sky_over(at)
	for k in 8:
		var a := TAU * k / 8.0
		top = maxf(top, _sky_over(at + Vector3(cos(a), 0.0, sin(a)) * radius))
	return top


func _face(toward: Vector3, delta: float, rate: float) -> void:
	toward.y = 0.0
	if toward.length_squared() < 0.0001:
		return
	_heading = _heading.slerp(toward.normalized(), 1.0 - exp(-rate * delta)).normalized() if _heading.dot(toward.normalized()) > -0.999 else toward.normalized()


# --- How it looks ---

## Gives the creature what it is doing.
func _drive_look(_delta: float) -> void:
	if look == null:
		return
	look.global_position = global_position
	look.rotation.y = atan2(_heading.x, _heading.z)
	look.perched = mode in [Mode.PERCH, Mode.SCREECH]
	look.mantle = 1.0 if mode == Mode.SCREECH or (mode == Mode.PERCH and hunting()) else 0.15
	look.grip = 1.0 if look.perched or snatched else 0.0
	look.stoop = 0.0
	look.talons = 0.0
	look.brake = 0.0
	match mode:
		Mode.RISE:
			look.effort = 1.0
			look.brake = 0.5 if _mode_time < RISE_OUT else 0.25
		Mode.CIRCLE, Mode.RETURN:
			# (gliding, with a few slow beats now and then)
			look.effort = 0.35 if fmod(_mode_time, 4.0) < 1.2 else 0.0
		Mode.STOOP:
			look.effort = 0.0
			look.stoop = clampf(_mode_time / 0.5, 0.0, 1.0)
		Mode.DIVE:
			var left := _time_to_target()
			look.effort = 0.0
			look.talons = 1.0 if left < TALONS_AT or _dive_t > 1.0 else 0.0
			look.stoop = 0.0 if look.talons > 0.0 else 1.0
		Mode.CLIMB:
			look.effort = 1.0
		Mode.LAND:
			look.effort = 0.6
			look.brake = 1.0
			look.talons = 0.8
		_:
			look.effort = 0.0
	if quarry and mode in [Mode.PERCH, Mode.SCREECH, Mode.CIRCLE, Mode.STOOP, Mode.DIVE]:
		look.aim = quarry.global_position + Vector3.UP * 1.2
	else:
		look.aim = Vector3.INF
	# (on its perch, while it screeches, it turns to them)
	if mode == Mode.SCREECH and quarry:
		_face(quarry.global_position - global_position, _delta, 3.0)


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
			look.settle()


func _skip_players() -> Array[RID]:
	var skip: Array[RID] = [get_rid()]
	for player: Node in players():
		if player is CollisionObject3D and is_instance_valid(player):
			skip.append((player as CollisionObject3D).get_rid())
	return skip


## Whether a point is in the open (not inside a wall or the ground).
func maze_free(at: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = at
	query.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_point(query, 1).is_empty()


## Whether nothing of the world stands between two points.
func _clear_line(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, _skip_players())
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# --- Being run by someone else ---

func yaw() -> float:
	return atan2(_heading.x, _heading.z)


func net_state() -> int:
	return mode


## How many times it has called (screech or cry), so a puppet calls too; and whether it has snatched someone.
func net_flag() -> int:
	return (_calls & 0x7f) | (0x80 if snatched else 0)


func net_point() -> Vector3:
	return dive_at if mode == Mode.DIVE else perch


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode in [Mode.CIRCLE, Mode.STOOP, Mode.DIVE]
	_heading = Vector3(sin(facing), 0.0, cos(facing))
	snatched = flag & 0x80 != 0
	var calls := flag & 0x7f
	if _heard_calls >= 0 and calls != _heard_calls and look:
		if mode == Mode.SCREECH or mode == Mode.PERCH:
			look.screech()
		else:
			look.cry()
	_heard_calls = calls
	if mode == Mode.DIVE:
		dive_at = point
	elif point.is_finite():
		perch = point


func _follow_news(delta: float) -> void:
	if not _heard:
		return
	_heard_at += _heard_moving * delta
	global_position = global_position.lerp(_heard_at, 1.0 - exp(-10.0 * delta))
	if global_position.distance_to(_heard_at) > 6.0:
		global_position = _heard_at
	if mode == Mode.DIVE:
		# (in a dive, its time to the target as near as it can tell, for the legs)
		_dive_t = 1.0 - clampf(global_position.distance_to(dive_at) / maxf(DIVE_SPEED * 2.0, 1.0), 0.0, 1.0) if dive_at.is_finite() else 0.0


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	_heading = Vector3(sin(facing), 0.0, cos(facing))
	if look:
		_drive_look(0.0)
		look.settle()


func _puppet_changed() -> void:
	collision_layer = 0
	collision_mask = 0

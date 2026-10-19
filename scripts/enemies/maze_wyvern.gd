class_name MazeWyvern
extends MazeEnemy
## A wyvern (creatures/wyvern/: a two-legged dragon, its wings its arms, 9 m
## across) set to hold its piece of the maze from the sky. This is only its
## thinking; how it looks, moves and sounds is the `Wyvern` component. Heavier
## and worse than the pterodactyl: it has two ways to kill, and a nest to keep.
##
## - A PAIR NEST on a high wall top in the outer rings (WyvernNest: sticks,
##   branches and bones). They soar and circle over their territory (within
##   `territory` of the nest), on still wings with now and then a few deep slow
##   beats, and come back to the nest to stand on it a while.
## - TERRITORIAL. Anyone who climbs up near the nest (within NEST_GUARD of it,
##   up on the walls) is gone for at once, by both, with no letting be: a
##   scream from the nest and straight into the attack. Otherwise they hunt only
##   part of the time: keen a while (`keen_time`), then not (`idle_time`), when
##   they soar on and pay nobody any mind.
## - THEY HUNT ANYONE IN THE OPEN, as the pterodactyl does: a wall top, a ledge,
##   a rope bridge, a wide hall, the desert. Not anyone in a narrow passage
##   (less than OPEN_WIDTH across, either way: its wings will not go in), nor
##   under anything, nor in the clearing, nor where it has no way down to them.
## - THE WARNINGS. Its scream (Wyvern.shriek) and its shadow: seeing someone it
##   comes over them low, its shadow sweeping over them, and screams overhead;
##   then wheels round. Then one of two:
## - THE DIVE: the wings drawn in, the roar of the wind (Wyvern.rush), down out
##   of the sky and along a run of open air at them, the feet swinging forward
##   at the last (TALONS_AT). Its line is set LOCK_TIME before it reaches them: a
##   sidestep and its feet close on air. If they close on someone it carries
##   them off (CARRY_TIME) and they are caught.
## - OR IT LANDS in the hall (ALIGHT) and STALKS them on its wrists and feet,
##   slower than a run (STALK_SPEED), and, near enough, THE LASH: the tail drawn
##   up in a coil over its back, the barb high and rattling, a hiss
##   (Wyvern.COIL_TIME, plain to see), then whipped over and down in front of it
##   (Wyvern.STRIKE_LAND). The barb catches whoever it lands on; the wind-up is
##   time to get out of its reach. Into a narrow passage or under cover, and it
##   gives up and takes off.
## - THE OTHERS. Hungry (Ecology), keen and with nobody to go after, it dives on
##   animals out in the open (deer, hares, goats: anything smaller that walks,
##   Ecology.is_prey), carries them back to the nest and eats there.
## - Two never dive at one person at once (the other keeps wheeling).
##
## Online, the host thinks; a puppet follows its news (where it is, what it is
## doing, the point of its dive or its nest), screaming when the host's does,
## lashing when the host's does; when the host's snatches someone near the
## player on a guest's machine, that player is lifted there too. Catching is
## the host's alone.
##
## Spawn (as MazeEnemies does any MazeEnemy): `MazeWyvern.new()`, `maze` set,
## put in a passage cell (best a hall in an outer ring; two in the one cell
## make a pair on one nest), added to the scene.

## What it is doing, as sent (`net_state`).
enum Mode { ROOST, LAUNCH, SOAR, PASS, WHEEL, DIVE, CARRY, CLIMB, RETURN, LAND, ALIGHT, STALK, LASH }

## Over the highest thing round about, as it soars, and as it comes over them.
const SOAR_ABOVE := 18.0
const PASS_ABOVE := 9.0
const SOAR_RADIUS := 34.0
const SOAR_SPEED := 11.0
const PASS_SPEED := 13.0
const WHEEL_SPEED := 13.0
const DIVE_SPEED := 21.0
const CLIMB_SPEED := 5.5
const STALK_SPEED := 2.7
## Narrower than this (metres between walls, both ways round) is a place it cannot get into.
const OPEN_WIDTH := 10.0
## The run of open air it needs to come down along to them, and how far out along it the dive starts.
const APPROACH := 13.0
const DIVE_FROM := 27.0
## In the dive: the feet come forward this long before it reaches them; its line is set this long before.
const TALONS_AT := 0.8
const LOCK_TIME := 0.45
## How high its feet pass over their feet (it reaches down onto them), and how near they must come.
const STRIKE_HEIGHT := 0.8
const CATCH_RADIUS := 0.6
## The lash: how near (from its middle, flat) it winds up at someone, and how near the barb must come to them.
const LASH_RANGE := 2.1
const LASH_RADIUS := 0.8
## Where the barb lands from its middle's foot, facing +Z (when it is not drawn to say).
const BARB_LANDS := Vector3(0.3, 0.7, 1.3)
## How tall they count as, standing and low (the boy: Player.stand_height, crouch_height).
const TALL := 1.25
const LOW := 0.72
## Seconds it carries whom it has caught before they are gone.
const CARRY_TIME := 1.8
const LAND_TIME := 2.0
## Anyone up on the walls this near its nest (flat), and no further below its top than NEST_BELOW, is gone for at once.
const NEST_GUARD := 18.0
const NEST_BELOW := 6.0
## Kinds that fly, never taken as prey.
const FLIERS: Array[String] = ["MazePterodactyl", "MazeGriffinfly", "MazeLuckDragon", "MazeWyvern"]
## Ways down to them it tries (flat, unit): the four ways along the walls and the four between.
const WAYS: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1),
	Vector3(0.7071, 0, 0.7071), Vector3(-0.7071, 0, 0.7071), Vector3(0.7071, 0, -0.7071), Vector3(-0.7071, 0, -0.7071)]
const FACES: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]

## How many attacks at someone (dives and landings) before it lets them be.
@export var swoops := 3
## How long they may stay out of its reach before it gives up on them, seconds.
@export var lose_time := 5.0
## How long it lets someone be after giving up on them (or catching them), seconds.
@export var rest_time := 14.0
## How long it soars before it comes back to the nest, and how long it stays there, seconds (least, most).
@export var soar_time := Vector2(40.0, 80.0)
@export var roost_time := Vector2(15.0, 30.0)
## How long it is keen to hunt, and then not, seconds (least, most).
@export var keen_time := Vector2(35.0, 60.0)
@export var idle_time := Vector2(25.0, 50.0)
## The chance that, its quarry on the ground in a wide hall, it lands to stalk them instead of diving.
@export var land_chance := 0.45
## How long it stalks before it gives up and takes off, seconds; how many lashes at most.
@export var stalk_time := 16.0
@export var lashes := 3
## How far from the nest it keeps (flat), metres.
@export var territory := 60.0
## Further than this from every player it is not posed or drawn.
@export var pose_range := 160.0

var mode := Mode.ROOST
## The creature.
var look: Wyvern
## The middle of its nest's floor (shared with its mate), where it stands on it (its middle), and which way it faces there.
var nest_at := Vector3.INF
var roost := Vector3.INF
var roost_facing := Vector3.FORWARD
## Where it looks out from, on its nest: over the edge of the wall top the way it faces.
var lookout := Vector3.INF
## The nest (drawn by whichever of the pair found it first), and how big it is (1 its full size).
var nest: WyvernNest
var nest_size := 0.8
## The middle of the circle it soars round.
var soar_centre := Vector3.ZERO
## The dive: the way along the run of open air from them out to where it
## comes down (flat), where it starts, and the point it is making for (its feet at them).
var dive_way := Vector3.ZERO
var dive_start := Vector3.INF
var dive_at := Vector3.INF
## Where it comes down in a hall to stalk.
var land_at := Vector3.INF
## Whether its last dive took someone (or something); whether it is keen to hunt now; whether it defends its nest.
var snatched := false
var keen := true
var defending := false
## How near its feet came to whoever it last dived at (for tests), and the barb in its last lash.
var closest := INF
var closest_at := Vector3.ZERO
var lash_closest := INF

var _mode_time := 0.0
var _placed := false
var _heading := Vector3.FORWARD
var _speed := 0.0
var _altitude := 50.0
var _soar_angle := 0.0
var _soar_left := 60.0
var _roost_left := 10.0
var _keen_left := 40.0
var _drift_to := Vector3.INF
var _sky_check := 0.0
var _watch := 0.0
var _hidden := 0.0
var _dives := 0
var _lashes := 0
var _called := false
var _locked := false
var _dive_t := 0.0
var _past := 0.0
var _from := Vector3.ZERO
var _low := Vector3.ZERO
var _calls := 0
var _heard_calls := -1
var _far := false
var _far_check := 0.0
var _turn_to := 0.0
var _turn_in := 6.0
var _hit := false
var _barb_was := Vector3.INF
## Whom it lets be a while (player -> seconds).
var _let_be := {}
var _carried: Node = null
var _carrying: Node3D = null
var _last_feet := PackedVector3Array()
var _shadow_y := 0.0
var _shadow_check := 0
var _over_check := 0
var _under := -INF
var _wheel_stage := 0
var _body_shape: CollisionShape3D
## Where its feet are from its middle as it strikes, facing +Z.
var _strike_offset := Vector3(0.0, -1.1, 0.4)


func _init() -> void:
	sight_range = 80.0
	hear_range = 0.0
	memory = 8.0
	alert_range = 0.0
	pack = &"wyverns"
	look_every = 0.3


func _ready() -> void:
	add_to_group(&"pursuers")
	# Its body, when it is on the ground (in the air nothing bumps into it).
	_body_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.9
	capsule.height = 2.4
	_body_shape.shape = capsule
	add_child(_body_shape)
	collision_mask = 0
	_set_body(false)
	look = Wyvern.new()
	look.name = "Look"
	look.seed_value = _rng.seed
	look.top_level = true
	add_child(look)
	look.global_position = global_position
	look.rotation.y = 0.0
	# Where its feet are, from its middle, when it strikes (facing +Z): what it steers by in a dive.
	look.grounded = false
	look.hold({"ground": 0.0, "effort": 0.2, "brake": 0.0, "tuck": 0.0, "talons": 1.0, "grip": 0.0})
	var middle := Vector3.ZERO
	var points := look.foot_points()
	for p in points:
		middle += p
	_strike_offset = middle / maxf(points.size(), 1.0) - look.global_position
	look.rotation.y = rotation.y
	_heading = Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	soar_centre = Vector3(global_position.x, 0.0, global_position.z)
	_roost_left = _rng.randf_range(4.0, 20.0)
	_soar_left = _rng.randf_range(soar_time.x, soar_time.y)
	_keen_left = _rng.randf_range(keen_time.x, keen_time.y)


## Solid (on the ground) or not (flying).
func _set_body(solid: bool) -> void:
	var layer := (PUPPET_LAYER if puppet else 4) if solid else 0
	if layer == collision_layer and _body_shape and _body_shape.disabled != solid:
		return
	collision_layer = layer
	if _body_shape:
		_body_shape.disabled = not solid
		_body_shape.position = Vector3.ZERO


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
		_settle_on_roost()
	_mode_time += delta
	_count_down(delta)
	_moods(delta)
	var before := global_position
	match mode:
		Mode.ROOST:
			_roosting(delta)
		Mode.LAUNCH:
			_launching(delta)
		Mode.SOAR:
			_soaring(delta)
		Mode.PASS:
			_passing(delta)
		Mode.WHEEL:
			_wheeling(delta)
		Mode.DIVE:
			_diving(delta)
		Mode.CARRY:
			_carry(delta)
		Mode.CLIMB:
			_climbing(delta)
		Mode.RETURN:
			_returning(delta)
		Mode.LAND:
			_landing(delta)
		Mode.ALIGHT:
			_alighting(delta)
		Mode.STALK:
			_stalking(delta)
		Mode.LASH:
			_lashing(delta)
	velocity = (global_position - before) / delta
	chasing = mode in [Mode.PASS, Mode.WHEEL, Mode.DIVE, Mode.ALIGHT, Mode.STALK, Mode.LASH] and not (quarry is MazeEnemy)
	_set_body(_on_ground())
	_drive_look(delta)


func _on_ground() -> bool:
	return mode in [Mode.ROOST, Mode.STALK, Mode.LASH] or (mode == Mode.ALIGHT and _mode_time > LAND_TIME * 0.85)


## Counts down the time each caught player is let alone, and those it lets be.
func _count_down(delta: float) -> void:
	_eating -= delta
	for table: Dictionary in [_spared, _let_be]:
		for player: Variant in table.keys():
			if not is_instance_valid(player):
				table.erase(player)
				continue
			table[player] -= delta
			if table[player] <= 0.0:
				table.erase(player)


## Keen a while, then not.
func _moods(delta: float) -> void:
	_keen_left -= delta
	if _keen_left <= 0.0:
		keen = not keen
		_keen_left = _rng.randf_range(keen_time.x, keen_time.y) if keen else _rng.randf_range(idle_time.x, idle_time.y)


func _enter(next: Mode) -> void:
	mode = next
	_mode_time = 0.0


## Whether it may hunt `player` now (and it is not someone another of its kind is diving at).
func _may_hunt(player: Node3D) -> bool:
	if not huntable(player):
		return false
	if _let_be.has(player) and not _intruder(player):
		return false
	if _intruder(player):
		return true
	for other: Node in get_tree().get_nodes_in_group(&"wyverns"):
		if other != self and other is MazeWyvern and other.can_process() and (other as MazeWyvern).quarry == player and (other as MazeWyvern).mode in [Mode.LAUNCH, Mode.PASS, Mode.WHEEL, Mode.DIVE, Mode.CARRY, Mode.ALIGHT, Mode.STALK, Mode.LASH]:
			return false
	return true


## Whether `player` is up near its nest (on the walls round it).
func _intruder(player: Node3D) -> bool:
	if not nest_at.is_finite() or not is_instance_valid(player) or player is MazeEnemy:
		return false
	var at := player.global_position
	return Vector2(at.x - nest_at.x, at.z - nest_at.z).length() < NEST_GUARD and at.y > nest_at.y - NEST_BELOW


## Whether `player` is out in the open, where it can get at them: not under
## anything, not in a narrow passage, not in the clearing, and with a way down to them.
func exposed(player: Node3D) -> bool:
	if not huntable(player) or maze.in_clearing(maze.cell_at(player.global_position)):
		return false
	return not _ways_down(player).is_empty()


## The ways down to `player` (flat, unit: from them out along the run of open
## air it would come down), best first; [] if there are none.
func _ways_down(player: Node3D) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var feet := player.global_position
	var head := feet + Vector3.UP * 1.7
	# Something over their head?
	if not _clear_line(head, head + Vector3.UP * 60.0):
		return out
	# In a narrow passage? (both ways round, at the waist and higher up, where its wings would be)
	for high: float in [1.0, 4.0]:
		var at := feet + Vector3.UP * high
		var x := _free(at, Vector3.RIGHT, 20.0) + _free(at, Vector3.LEFT, 20.0)
		var z := _free(at, Vector3.BACK, 20.0) + _free(at, Vector3.FORWARD, 20.0)
		if minf(x, z) < OPEN_WIDTH:
			return out
	# The runs of open air leading to them, open to the sky where it comes down.
	var lengths: Array[float] = []
	for way in WAYS:
		var run := minf(_free(feet + Vector3.UP * 1.3, way, APPROACH + 2.0), _free(feet + Vector3.UP * 4.0, way, APPROACH + 2.0))
		if run < APPROACH:
			continue
		var end := feet + way * APPROACH
		if not _clear_line(end + Vector3.UP * 4.0, end + Vector3.UP * 50.0):
			continue
		var at := 0
		while at < out.size() and lengths[at] >= run:
			at += 1
		out.insert(at, way)
		lengths.insert(at, run)
	return out


## Whether it can see `player` from where it is (a line of sight, through nothing).
func _sees(player: Node3D) -> bool:
	var at := player.global_position + Vector3.UP * 1.2
	if global_position.distance_to(at) > sight_range:
		return false
	# (on its nest it looks out from over the edge of the wall top, its neck stretched out past it)
	var eye := global_position + Vector3.DOWN * 0.5
	if mode == Mode.ROOST and lookout.is_finite():
		eye = lookout
	elif _on_ground():
		eye = global_position + _heading * 1.2 + Vector3.UP * 1.2
	return _clear_line(eye, at)


## Anyone it can see out in the open (an intruder at its nest first; the
## others only while it is keen), the nearest (or null).
func _spot() -> Node3D:
	var seen: Node3D = null
	var nearest := INF
	for player: Node3D in players():
		if not _may_hunt(player):
			continue
		var d := player.global_position.distance_to(global_position)
		var guard := _intruder(player)
		if not guard and (not keen or d > sight_range):
			continue
		if guard:
			d -= 1000.0
		if d >= nearest:
			continue
		if not guard and (not _sees(player) or not exposed(player)):
			continue
		nearest = d
		seen = player
	return seen


## An animal out in the open it could take (hungry, keen and after nobody), the nearest (or null).
func _spot_prey() -> MazeEnemy:
	var world := Ecology.current
	if world == null or not keen or not world.hungry(self) or _eating > 0.0:
		return null
	var best: MazeEnemy = null
	var nearest := sight_range
	for one: MazeEnemy in world.creatures():
		if one.process_mode == Node.PROCESS_MODE_DISABLED or not world.is_prey(one, self) or FLIERS.has(Ecology.kind_of(one)):
			continue
		var d := one.global_position.distance_to(global_position)
		if d < nearest and huntable(one) and _sees(one) and exposed(one):
			nearest = d
			best = one
	return best


## Looks about: for anyone at its nest, anyone in the open, an animal to take.
func _look_about() -> bool:
	var seen := _spot()
	if seen:
		defending = _intruder(seen)
		notice(seen)
		return true
	var prey := _spot_prey()
	if prey:
		defending = false
		quarry = prey
		_forget = memory
		return true
	return false


# --- The nest ---

## The first moment it is in the world: down on its nest (or the wall top it builds one on) near where it was put.
func _settle_on_roost() -> void:
	_find_roost(global_position)
	if roost.is_finite():
		global_position = roost
		_heading = roost_facing
		look.grounded = true
		look.global_position = roost
		look.rotation.y = atan2(_heading.x, _heading.z)
		look.settle()
		_enter(Mode.ROOST)
	else:
		_altitude = _sky_round(global_position, 20.0) + SOAR_ABOVE
		global_position.y = _altitude
		look.grounded = false
		look.settle()
		_enter(Mode.SOAR)


## Its nest: its mate's, if one has already nested near; otherwise the best
## wall top near `near` (high, flat, with room round it), where it builds one.
func _find_roost(near: Vector3) -> void:
	var mate: MazeWyvern = null
	for other: Node in get_tree().get_nodes_in_group(&"wyverns"):
		if other != self and other is MazeWyvern and (other as MazeWyvern).nest_at.is_finite():
			var at: Vector3 = (other as MazeWyvern).nest_at
			if Vector2(at.x - near.x, at.z - near.z).length() < 30.0:
				mate = other as MazeWyvern
				break
	if mate:
		nest_at = mate.nest_at
		nest_size = mate.nest_size
		roost_facing = mate.roost_facing
		_stand_on_nest(-1.0)
		return
	var best := Vector3.INF
	var best_score := -INF
	var ground := maze.ground_height(near)
	for r in 11:
		var ring := r * 3.0
		var steps := 1 if r == 0 else 12
		for k in steps:
			var a := TAU * (k + 0.5 * (r % 2)) / steps
			var p := Vector3(near.x + cos(a) * ring, 0.0, near.z + sin(a) * ring)
			if maze.in_clearing(maze.cell_at(p)) or not maze.inside(maze.cell_at(p)):
				continue
			var top := _sky_over(p)
			if top - ground < 8.0:
				continue
			var flat := true
			for face in FACES:
				if absf(_sky_over(p + face * 1.6) - top) > 0.3:
					flat = false
					break
			if not flat:
				continue
			var score := top - ring * 0.3
			if score > best_score:
				best_score = score
				best = Vector3(p.x, top, p.z)
	if not best.is_finite():
		nest_at = Vector3.INF
		roost = Vector3.INF
		return
	var out := Vector3(near.x - best.x, 0.0, near.z - best.z)
	roost_facing = out.normalized() if out.length() > 1.0 else _heading
	nest_at = best
	_build_nest()
	_stand_on_nest(1.0)


## Where on the nest it stands (its side of it: `side` +1 or -1 across the way it faces).
func _stand_on_nest(side: float) -> void:
	var across := roost_facing.cross(Vector3.UP).normalized()
	var spot := nest_at + across * side * 1.1 * nest_size
	if absf(_sky_over(spot) - nest_at.y) > 0.4:
		spot = nest_at
	roost = Vector3(spot.x, nest_at.y, spot.z) + Vector3.UP * Wyvern.STAND_HEIGHT
	lookout = nest_at + roost_facing * (_edge(nest_at, roost_facing, 8.0) + 0.6) + Vector3.UP * 1.8


## The nest, on the wall top, as big as the top has room for.
func _build_nest() -> void:
	if nest or not nest_at.is_finite():
		return
	var room := 3.0
	for face in FACES:
		room = minf(room, _edge(nest_at, face, 3.0))
	nest = WyvernNest.new()
	nest.name = "Nest"
	nest.top_level = true
	add_child(nest)
	nest_size = clampf(room / WyvernNest.RADIUS, 0.5, 1.0)
	nest.scale = Vector3.ONE * nest_size
	nest.global_position = nest_at + Vector3.UP * 0.02
	nest.rotation.y = _rng.randf() * TAU


## How far it is from `at` along `way` to the edge of the wall top it is on (at most `far`).
func _edge(at: Vector3, way: Vector3, far: float) -> float:
	var d := 0.0
	while d < far:
		if absf(_sky_over(at + way * (d + 0.3)) - at.y) > 0.5:
			return d
		d += 0.3
	return far


func _roosting(delta: float) -> void:
	global_position = roost
	_roost_left -= delta
	# (now and then it turns to look about)
	_turn_in -= delta
	if _turn_in <= 0.0:
		_turn_in = _rng.randf_range(5.0, 9.0)
		_turn_to = _rng.randf_range(-1.3, 1.3)
	_face(roost_facing.rotated(Vector3.UP, _turn_to), delta, 0.7)
	if _eating > 0.0:
		return
	_watch -= delta
	if _watch <= 0.0:
		_watch = look_every
		if _look_about():
			_calls += 1
			look.shriek()
			_launch()
			return
	if _roost_left <= 0.0:
		_launch()


func _launch() -> void:
	_from = global_position
	look.launch()
	_enter(Mode.LAUNCH)


func _launching(delta: float) -> void:
	var lift := Wyvern.launch_lift(minf(_mode_time, Wyvern.LAUNCH_TIME))
	var forward := Vector3(_heading.x, 0.0, _heading.z)
	global_position = _from + forward * lift.y + Vector3.UP * lift.x
	_keep_over(delta)
	if _mode_time >= Wyvern.LAUNCH_TIME:
		_speed = SOAR_SPEED * 0.6
		_altitude = _sky_round(global_position, 20.0) + SOAR_ABOVE
		_soar_left = _rng.randf_range(soar_time.x, soar_time.y)
		if quarry and _may_hunt(quarry):
			if defending:
				_plan_dive()
			else:
				_start_pass()
		else:
			_start_soaring()
	else:
		_face(forward, delta, 1.0)


# --- Soaring over its territory ---

func _start_soaring() -> void:
	var off := Vector3(global_position.x - soar_centre.x, 0.0, global_position.z - soar_centre.z)
	_soar_angle = atan2(off.z, off.x)
	_enter(Mode.SOAR)


func _soaring(delta: float) -> void:
	_sky_check -= delta
	if _sky_check <= 0.0:
		_sky_check = 1.5
		_altitude = maxf(_sky_round(global_position, 18.0), _sky_round(soar_centre, 18.0)) + SOAR_ABOVE
		# (the middle of its circle drifts about its territory, never over the clearing)
		if not _drift_to.is_finite() or Vector2(_drift_to.x - soar_centre.x, _drift_to.z - soar_centre.z).length() < 3.0:
			var cell := nav.wander(maze.cell_at(soar_centre), _rng) if nav else maze.cell_at(soar_centre)
			_drift_to = maze.world(cell)
			if nest_at.is_finite() and Vector2(_drift_to.x - nest_at.x, _drift_to.z - nest_at.z).length() > territory:
				_drift_to = Vector3(nest_at.x, 0.0, nest_at.z)
	if _drift_to.is_finite():
		var drift := Vector3(_drift_to.x - soar_centre.x, 0.0, _drift_to.z - soar_centre.z)
		soar_centre += drift.limit_length(2.5 * delta)
	_soar_angle += SOAR_SPEED / SOAR_RADIUS * delta
	var want := soar_centre + Vector3(cos(_soar_angle), 0.0, sin(_soar_angle)) * SOAR_RADIUS
	want.y = _altitude
	if maze.in_clearing(maze.cell_at(want)):
		# (pushed back off the clearing)
		soar_centre += Vector3(soar_centre.x, 0.0, soar_centre.z).normalized() * 6.0 * delta
	_fly_to(want, SOAR_SPEED * 1.3, delta, 1.3)
	_soar_left -= delta
	_watch -= delta
	if _watch <= 0.0:
		_watch = look_every
		# (far from everyone it does not look)
		var near := nearest_player(global_position)
		if (near and near.global_position.distance_to(global_position) < sight_range) or Ecology.current:
			if _look_about():
				_start_pass()
				return
	if _soar_left <= 0.0:
		if roost.is_finite():
			_enter(Mode.RETURN)
		else:
			_soar_left = _rng.randf_range(soar_time.x, soar_time.y)


## Flies towards `want` at up to `speed`, turning (`rate`) the way it goes; never through what is under it.
func _fly_to(want: Vector3, speed: float, delta: float, rate: float) -> void:
	var to := want - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() > 0.2:
		_face(flat, delta, rate)
	_speed = move_toward(_speed, speed, 6.0 * delta)
	global_position += _heading * _speed * delta
	global_position.y = move_toward(global_position.y, want.y, maxf(CLIMB_SPEED, absf(to.y) * 0.8) * delta)
	_keep_over(delta)


## Never lower than whatever is under it and just ahead (a wall it comes over): it rises over it.
func _keep_over(delta: float) -> void:
	_over_check += 1
	if _over_check % 2 == 0 or _under == -INF:
		_under = _sky_over(global_position + _heading * 7.0) + 3.5
	if global_position.y < _under:
		global_position.y = move_toward(global_position.y, _under, CLIMB_SPEED * 4.0 * delta)


# --- The warning: over them, the scream, and round ---

func _start_pass() -> void:
	_called = false
	_hidden = 0.0
	if quarry:
		_altitude = _pass_height(quarry.global_position)
	_enter(Mode.PASS)


## How high it comes over someone at `at`: over what is round them.
func _pass_height(at: Vector3) -> float:
	return maxf(_sky_round(at, 10.0) + PASS_ABOVE, at.y + 15.0)


## Whether it should give up on its quarry (out of reach too long): it lets them be and soars on.
func _losing(delta: float) -> bool:
	if quarry == null or not huntable(quarry) or maze.in_clearing(maze.cell_at(quarry.global_position)):
		_give_up()
		return true
	if exposed(quarry):
		_hidden = 0.0
		_forget = memory
		return false
	_hidden += delta
	if _hidden > lose_time:
		_give_up()
		return true
	return false


func _give_up() -> void:
	if quarry and not (quarry is MazeEnemy):
		_let_be[quarry] = rest_time
	quarry = null
	defending = false
	_forget = 0.0
	_dives = 0
	_lashes = 0
	_altitude = _sky_round(global_position, 18.0) + SOAR_ABOVE
	_start_soaring()


func _passing(delta: float) -> void:
	_watch -= delta
	if _watch <= 0.0:
		_watch = look_every
		if _losing(look_every):
			return
	if quarry == null:
		return
	var over := quarry.global_position
	over.y = _altitude
	var flat := Vector3(over.x - global_position.x, 0.0, over.z - global_position.z)
	if not _called:
		_fly_to(over, PASS_SPEED, delta, 2.0)
		if flat.length() < 4.0 or (flat.length() < 12.0 and flat.dot(_heading) < 0.0):
			# Overhead: its shadow on them, the scream.
			_called = true
			_calls += 1
			look.shriek()
			_mode_time = 0.0
	else:
		# On past them, then round.
		_fly_to(global_position + _heading * 20.0 + Vector3.UP * (_altitude - global_position.y), PASS_SPEED, delta, 0.5)
		if _mode_time > 1.0:
			_plan_dive()


## Chooses its way down to them and how it attacks: it lands to stalk them, or
## dives from out along the way down; it wheels round to it.
func _plan_dive() -> void:
	if quarry == null:
		_give_up()
		return
	var ways := _ways_down(quarry)
	if ways.is_empty():
		_hidden += 0.5
		_enter(Mode.WHEEL)
		dive_start = Vector3.INF
		return
	# (the way that takes it least round: from the side it is already on, best)
	var best := ways[0]
	var best_score := -INF
	for way in ways:
		var start := quarry.global_position + way * DIVE_FROM
		var score := -Vector2(start.x - global_position.x, start.z - global_position.z).length() * 0.05
		if _dive_clear(quarry.global_position, way):
			score += 10.0
		if score > best_score:
			best_score = score
			best = way
	dive_way = best
	_altitude = _pass_height(quarry.global_position)
	dive_start = quarry.global_position + best * DIVE_FROM
	dive_start.y = _altitude
	_wheel_stage = 0
	land_at = Vector3.INF
	if not (quarry is MazeEnemy) and _rng.randf() < land_chance:
		land_at = _landing_spot(quarry, best)
	_enter(Mode.WHEEL)


## Where it can come down in front of `player` to stalk them (on the ground,
## out along `way`, with room for it), or INF.
func _landing_spot(player: Node3D, way: Vector3) -> Vector3:
	var feet := player.global_position
	if feet.y - maze.ground_height(feet) > 1.0:
		return Vector3.INF
	for out: float in [8.0, 6.5, 10.0]:
		var at := feet + way * out
		at.y = maze.ground_height(at)
		if absf(at.y - feet.y) > 0.8 or not _clear_line(at + Vector3.UP * 1.5, at + Vector3.UP * 40.0):
			continue
		var room := true
		for face in FACES:
			if _free(at + Vector3.UP * 1.2, face, 2.5) < 2.4:
				room = false
				break
		if room and _clear_line(at + Vector3.UP * 1.2, feet + Vector3.UP * 1.0):
			return at
	return Vector3.INF


## Whether its dive down `way` to someone at `feet` is clear of the walls all along (a few rays).
func _dive_clear(feet: Vector3, way: Vector3) -> bool:
	var start := feet + way * DIVE_FROM
	start.y = _pass_height(feet)
	var low := feet + way * 8.0 + Vector3.UP * 2.0
	var end := feet + Vector3.UP * 1.0
	var was := start
	for k in range(1, 9):
		var t := k / 8.0
		var p := start * (1.0 - t) * (1.0 - t) + low * 2.0 * t * (1.0 - t) + end * t * t
		if not _clear_line(was, p):
			return false
		was = p
	return true


## Whether another of its kind is diving at `who` now.
func _other_diving(who: Node3D) -> bool:
	for other: Node in get_tree().get_nodes_in_group(&"wyverns"):
		if other != self and other is MazeWyvern and (other as MazeWyvern).quarry == who and (other as MazeWyvern).mode in [Mode.DIVE, Mode.ALIGHT, Mode.STALK, Mode.LASH]:
			return true
	return false


func _wheeling(delta: float) -> void:
	_watch -= delta
	if _watch <= 0.0:
		_watch = look_every
		if _losing(look_every):
			return
		if not dive_start.is_finite() and quarry and exposed(quarry):
			_plan_dive()
	if quarry == null:
		return
	if not dive_start.is_finite():
		# (no way down yet: round over them; at its nest, screaming now and then)
		var round_them := quarry.global_position + Vector3(cos(_mode_time * 0.6), 0.0, sin(_mode_time * 0.6)) * 18.0
		round_them.y = _pass_height(quarry.global_position)
		_fly_to(round_them, WHEEL_SPEED, delta, 1.2)
		if defending and fmod(_mode_time, 6.0) < delta:
			_calls += 1
			look.shriek()
		return
	# (it keeps to them as they move: its start goes with them)
	var target := quarry.global_position + dive_way * DIVE_FROM
	target.y = _altitude
	dive_start = dive_start.move_toward(target, 4.0 * delta)
	# Round wide of the start first (further out along the run), then in over it heading for them.
	var outer := dive_start + dive_way * 16.0
	var lined_up := _heading.dot(-dive_way) > 0.7
	if _wheel_stage == 0:
		_fly_to(outer, WHEEL_SPEED, delta, 1.2)
		if Vector2(outer.x - global_position.x, outer.z - global_position.z).length() < 7.0 or lined_up and _mode_time > 1.0:
			_wheel_stage = 1
		return
	_fly_to(dive_start, WHEEL_SPEED, delta, 1.4)
	var flat := Vector3(dive_start.x - global_position.x, 0.0, dive_start.z - global_position.z)
	var over := flat.length() < 4.0 or flat.dot(_heading) < 0.0
	if over and lined_up and not _other_diving(quarry):
		if land_at.is_finite():
			_begin_alight()
		else:
			_begin_dive()
	elif over:
		_wheel_stage = 0
	if _mode_time > 18.0:
		_give_up()


# --- The dive ---

func _begin_dive() -> void:
	_dives += 1
	_locked = false
	snatched = false
	closest = INF
	_dive_t = 0.0
	_past = 0.0
	_from = global_position
	_last_feet = PackedVector3Array()
	dive_at = _lead(quarry, 2.0)
	_low = dive_at - _strike_turned() + dive_way * 8.0 + Vector3.UP * 1.2
	look.rush()
	_enter(Mode.DIVE)


## Down out of the sky and flattening along its run at them: a curve from where
## it began (`_from`), past a low point out along the run (`_low`), to where its
## feet will be at them (`dive_at`); then on past them, climbing.
func _diving(delta: float) -> void:
	var left := _time_to_target()
	# (where its feet really are as they swing forward, from its middle: what it steers by)
	if look and look.visible and not _far and left < TALONS_AT and _dive_t < 1.0:
		var live := Basis(Vector3.UP, atan2(-dive_way.x, -dive_way.z)).inverse() * (look.carry_point() - look.global_position)
		_strike_offset = _strike_offset.lerp(live, 0.35)
	if not _locked:
		if quarry == null or not huntable(quarry) or _ways_down(quarry).is_empty():
			_break_off()
			return
		dive_at = _lead(quarry, left)
		if left <= LOCK_TIME:
			_locked = true
	_low = dive_at - _strike_turned() + dive_way * 8.0 + Vector3.UP * 1.2
	var aim := dive_at - _strike_turned()
	var at := aim
	if _dive_t < 1.0:
		# (along the curve at its speed, however the curve is drawn out)
		_dive_t = minf(_dive_t + DIVE_SPEED * delta / maxf(_curve_speed(_dive_t), 1.0), 1.0)
		var t := _dive_t
		at = _from * (1.0 - t) * (1.0 - t) + _low * 2.0 * t * (1.0 - t) + aim * t * t
	else:
		# (past them, on and up)
		_past += DIVE_SPEED * 0.9 * delta
		at = aim - dive_way * _past + Vector3.UP * _past * 0.35
	var moved := at - global_position
	global_position = at
	if Vector3(moved.x, 0.0, moved.z).length() > 0.001:
		_face(moved, delta, 14.0)
	_strike()
	if snatched:
		_start_carry()
		return
	if _past >= 9.0 or (_past > 0.0 and _free(global_position, -dive_way, 4.0) < 3.5):
		_from = global_position
		_enter(Mode.CLIMB)


## How fast a point runs along the dive's curve at `t`, metres per unit of t.
func _curve_speed(t: float) -> float:
	var aim := dive_at - _strike_turned()
	return (2.0 * (1.0 - t) * (_low - _from) + 2.0 * t * (aim - _low)).length()


## Seconds until its feet reach the point of its dive.
func _time_to_target() -> float:
	if not dive_at.is_finite():
		return 9.0
	if puppet:
		return global_position.distance_to(dive_at) / DIVE_SPEED
	if _dive_t >= 1.0:
		return 0.0
	# (what is left of the curve, a few steps of it)
	var left := 0.0
	for k in 4:
		left += _curve_speed(lerpf(_dive_t, 1.0, (k + 0.5) / 4.0)) * (1.0 - _dive_t) / 4.0
	return left / DIVE_SPEED


## Where its feet should meet `player`: where they will be in `seconds` (most of the way), over their feet.
func _lead(player: Node3D, seconds: float) -> Vector3:
	var moving: Variant = player.get(&"velocity")
	var v: Vector3 = moving if moving is Vector3 else Vector3.ZERO
	v.y = 0.0
	var at := player.global_position + v * minf(seconds, 1.2) * 0.8
	return at + Vector3.UP * STRIKE_HEIGHT


## Where its feet are from its middle as it strikes, facing along its dive.
func _strike_turned() -> Vector3:
	return Basis(Vector3.UP, atan2(-dive_way.x, -dive_way.z)) * _strike_offset


## Whether its feet close on anyone (or its prey) as they pass.
func _strike() -> void:
	var now := PackedVector3Array([_feet()])
	var was := _last_feet
	_last_feet = now
	if snatched or _time_to_target() > TALONS_AT * 0.6 or _past > 1.5:
		return
	# (where they went since the last frame: at this speed a frame is a third of a metre)
	var points := PackedVector3Array()
	for k in 4:
		points.append(was[0].lerp(now[0], (k + 1) / 4.0) if was.size() == 1 else now[0])
	var whom: Array = players().duplicate()
	if quarry is MazeEnemy:
		whom.append(quarry)
	for player: Node3D in whom:
		if not huntable(player):
			continue
		var feet := player.global_position
		var top := LOW if is_low(player) else TALL
		for p in points:
			var d := _to_segment(p, feet + Vector3.UP * 0.25, feet + Vector3.UP * top)
			if player == quarry and d < closest:
				closest = d
				closest_at = p - feet
			if d < (CATCH_RADIUS + (0.4 if player is MazeEnemy else 0.0)):
				snatched = true
				_carrying = player
				return


## Where its feet are: the creature's, where it is drawn; otherwise, below its middle.
func _feet() -> Vector3:
	if look and look.visible and look.is_inside_tree() and not _far:
		return look.carry_point()
	return global_position + Basis(Vector3.UP, atan2(_heading.x, _heading.z)) * _strike_offset


## Whether `player` is down low (ducking, crawling, sliding, rolling, diving).
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


## A dive broken off (they got out of its reach): it pulls up and climbs.
func _break_off() -> void:
	_from = global_position
	_enter(Mode.CLIMB)


# --- Carrying off, climbing away ---

func _start_carry() -> void:
	_from = global_position
	if _carrying is Player:
		_carried = carry(_carrying as Player, self, CARRY_TIME + 0.4)
	elif _carrying is MazeEnemy:
		# (an animal: held, its own going stopped, and taken home)
		_carrying.set_physics_process(false)
	_enter(Mode.CARRY)


## Rising away with them held under it, then they are gone (caught); an
## animal it carries home to the nest.
func _carry(delta: float) -> void:
	if _carrying is MazeEnemy:
		var prey := _carrying as MazeEnemy
		if not is_instance_valid(prey) or prey.dead:
			if is_instance_valid(prey):
				prey.set_physics_process(true)
			_carrying = null
			_from = global_position
			_enter(Mode.CLIMB)
			return
		prey.global_position = _feet() + Vector3.DOWN * 0.6
		if _mode_time < 1.0:
			global_position += Vector3(_heading.x, 0.0, _heading.z) * 8.0 * delta + Vector3.UP * 4.0 * delta
			_keep_over(delta)
		elif roost.is_finite():
			_enter(Mode.RETURN)
		return
	var forward := Vector3(_heading.x, 0.0, _heading.z)
	var slow := 1.0 if _free(global_position, forward, 6.0) > 5.0 else 0.0
	global_position += forward * 8.0 * slow * delta + Vector3.UP * (3.5 + 3.0 * (1.0 - slow)) * delta
	if _mode_time >= CARRY_TIME:
		var who := _carrying
		if _carried and is_instance_valid(_carried):
			_carried.queue_free()
		_carried = null
		_carrying = null
		_dives = 0
		if who and is_instance_valid(who):
			_catch(who)
			_let_be[who] = rest_time
		defending = false
		_from = global_position
		_enter(Mode.CLIMB)


## Holds `player` (a Player, on the machine they play on) in the feet of
## `by` for `seconds`: no input, their own movement stopped, carried up under
## it. Let go of by freeing it, or when they are put somewhere else (caught).
static func carry(player: Player, by: MazeWyvern, seconds: float) -> Node:
	var held := player.get_node_or_null(^"WyvernCarried")
	if held:
		return held
	var hold := Carried.new()
	hold.name = "WyvernCarried"
	hold.by = by
	hold.length = seconds
	player.add_child(hold)
	return hold


## What holds a Player while a wyvern carries him (see `carry`).
class Carried extends Node:
	var by: MazeWyvern
	var length := 2.0
	var _time := 0.0
	var _had_input := true
	var _put := Vector3.INF

	func _ready() -> void:
		var player := get_parent() as Player
		_had_input = player.takes_input
		player.takes_input = false
		player.velocity = Vector3.ZERO
		player.set_physics_process(false)

	func _process(delta: float) -> void:
		_time += delta
		var player := get_parent() as Player
		# (put somewhere else (caught, back in the clearing): it lets go)
		if _put.is_finite() and player.global_position.distance_to(_put) > 3.0:
			queue_free()
			return
		if _time >= length or by == null or not is_instance_valid(by):
			queue_free()
			return
		var grip := by.look.carry_point() if by.look and by.look.visible else by.global_position + Vector3.DOWN
		# (held by the shoulders, hanging under its feet)
		var want := grip + Vector3.DOWN * 1.05
		var at := player.global_position.lerp(want, minf(1.0, _time * 6.0))
		player.global_position = at
		_put = at
		# (what is drawn of him goes with him: his physics, which would move it, is stopped)
		if player.has_method(&"_reset_visuals"):
			player.call(&"_reset_visuals")

	func _exit_tree() -> void:
		var player := get_parent() as Player
		if player == null:
			return
		player.set_physics_process(true)
		player.takes_input = _had_input


## Flapping hard, up out of where it dived to over the walls.
func _climbing(delta: float) -> void:
	# (still keeping an eye on them as it climbs: out of its reach too long and it gives up)
	_watch -= delta
	if quarry and _watch <= 0.0:
		_watch = look_every
		if _losing(look_every):
			return
	_sky_check -= delta
	if _mode_time <= delta or _sky_check <= 0.0:
		_sky_check = 0.5
		_altitude = _sky_round(global_position, 8.0) + PASS_ABOVE * 0.6
	var forward := Vector3(_heading.x, 0.0, _heading.z)
	var slow := maxf(0.0, 1.0 - _mode_time / 1.5)
	if _free(global_position, forward, 6.0) < 5.0:
		slow = 0.0
	global_position += forward * 9.0 * slow * delta
	var top := _altitude
	global_position.y = move_toward(global_position.y, maxf(top, global_position.y), CLIMB_SPEED * delta)
	if global_position.y >= top - 0.1:
		# (round again over them, even hidden: they may come out; it gives up if they do not)
		if quarry and _may_hunt(quarry) and _dives + _lashes < swoops:
			_start_pass()
		elif quarry:
			_give_up()
		else:
			_altitude = _sky_round(global_position, 18.0) + SOAR_ABOVE
			_start_soaring()


# --- Down in a hall: stalking, and the lash ---

func _begin_alight() -> void:
	_dives += 1
	_from = global_position
	_enter(Mode.ALIGHT)


## Down out of the sky to `land_at`, braking, onto its feet and wrists.
func _alighting(delta: float) -> void:
	if quarry == null or not huntable(quarry):
		_give_up()
		return
	var t := clampf(_mode_time / LAND_TIME, 0.0, 1.0)
	var e := t * t * (3.0 - 2.0 * t)
	var stand := land_at + Vector3.UP * Wyvern.STAND_HEIGHT
	global_position = _from.lerp(stand, e) + Vector3.UP * sin(PI * e) * 1.5
	var to := quarry.global_position - global_position
	_face(to if t > 0.6 else stand - _from, delta, 2.5)
	if t >= 1.0:
		global_position = stand
		_lashes = 0
		_hidden = 0.0
		_enter(Mode.STALK)


## On the ground after them, on its wrists and feet, slower than a run;
## near enough, the lash. Into a narrow passage or under cover, and it lets
## them be and takes off.
func _stalking(delta: float) -> void:
	if quarry == null or not huntable(quarry) or maze.in_clearing(maze.cell_at(quarry.global_position)):
		_take_off()
		return
	_watch -= delta
	if _watch <= 0.0:
		_watch = look_every
		if exposed(quarry) and absf(quarry.global_position.y - (global_position.y - Wyvern.STAND_HEIGHT)) < 2.0:
			_hidden = 0.0
		else:
			_hidden += look_every
			if _hidden > lose_time * 0.6:
				_let_be[quarry] = rest_time
				_calls += 1
				look.shriek()
				_take_off()
				return
	var to := quarry.global_position - global_position
	to.y = 0.0
	var apart := to.length()
	_face(to, delta, 2.2)
	if apart < LASH_RANGE and _heading.dot(to.normalized()) > 0.8 and _hidden <= 0.0:
		_begin_lash()
		return
	if apart > LASH_RANGE * 0.75:
		var way := nav.waypoint(global_position, quarry.global_position, MazeNav.clearance_for(1.2)) - global_position if nav else to
		way.y = 0.0
		if way.length() > 0.05:
			_face(way, delta, 2.0)
		var step := _heading * minf(STALK_SPEED * delta, maxf(apart - LASH_RANGE * 0.7, 0.0))
		if _free(global_position + Vector3.UP * 0.3, _heading, 2.2) > 2.0:
			global_position += step
	global_position.y = maze.ground_height(global_position) + Wyvern.STAND_HEIGHT
	if _mode_time > stalk_time or _lashes >= lashes:
		_let_be[quarry] = rest_time
		_take_off()


func _begin_lash() -> void:
	_lashes += 1
	_hit = false
	lash_closest = INF
	_barb_was = Vector3.INF
	look.strike()
	_enter(Mode.LASH)


## The coil (it turns slowly to them), then the lash, the barb catching whoever it lands on.
func _lashing(delta: float) -> void:
	if quarry and _mode_time < Wyvern.COIL_TIME - 0.3:
		_face(quarry.global_position - global_position, delta, 0.8)
	# (the lunge after its tail)
	if _mode_time > Wyvern.COIL_TIME and _mode_time < Wyvern.STRIKE_LAND:
		if _free(global_position + Vector3.UP * 0.3, _heading, 2.0) > 1.8:
			global_position += _heading * 3.5 * delta
	global_position.y = maze.ground_height(global_position) + Wyvern.STAND_HEIGHT
	var barb := _barb()
	if _mode_time > Wyvern.COIL_TIME + 0.05 and _mode_time < Wyvern.STRIKE_LAND + 0.12 and not _hit:
		var was := _barb_was if _barb_was.is_finite() else barb
		for player: Node3D in players():
			if not huntable(player):
				continue
			var feet := player.global_position
			var top := LOW if is_low(player) else TALL
			for k in 3:
				var d := _to_segment(was.lerp(barb, (k + 1) / 3.0), feet + Vector3.UP * 0.2, feet + Vector3.UP * top)
				if player == quarry:
					lash_closest = minf(lash_closest, d)
				if d < LASH_RADIUS:
					_hit = true
					_catch(player)
					_let_be[player] = rest_time
					break
			if _hit:
				break
	_barb_was = barb
	if _mode_time >= Wyvern.STRIKE_TIME:
		if quarry and huntable(quarry) and _lashes < lashes and _hidden <= 0.0:
			_enter(Mode.STALK)
		else:
			_take_off()


## Where the barb is: the creature's, where it is drawn; otherwise worked out from the lash.
func _barb() -> Vector3:
	if look and look.visible and look.is_inside_tree() and not _far:
		return look.barb_point()
	var landed := smoothstep(Wyvern.COIL_TIME, Wyvern.STRIKE_LAND, _mode_time)
	var high := Vector3(0.3, 2.3 - 1.6 * landed, lerpf(0.4, BARB_LANDS.z, landed))
	return global_position + Vector3.DOWN * Wyvern.STAND_HEIGHT + Basis(Vector3.UP, atan2(_heading.x, _heading.z)) * high


func _take_off() -> void:
	if quarry and _let_be.has(quarry):
		quarry = null
	_from = global_position
	look.launch()
	_enter(Mode.LAUNCH)


# --- Coming back to the nest ---

func _returning(delta: float) -> void:
	if not roost.is_finite():
		_start_soaring()
		return
	# Over the nest at its height, coming in from the way it faces out over, then down to it.
	var approach := roost - roost_facing * 15.0 + Vector3.UP * 7.0
	var high := Vector3(approach.x, maxf(_altitude, approach.y), approach.z)
	var flat := Vector3(approach.x - global_position.x, 0.0, approach.z - global_position.z)
	if _carrying is MazeEnemy and is_instance_valid(_carrying):
		_carrying.global_position = _feet() + Vector3.DOWN * 0.6
	if flat.length() > 3.0:
		_fly_to(high if flat.length() > 25.0 else approach, SOAR_SPEED, delta, 1.4)
	else:
		_fly_to(approach, SOAR_SPEED * 0.6, delta, 2.0)
		if absf(global_position.y - approach.y) < 1.0:
			_from = global_position
			_enter(Mode.LAND)
	if _carrying:
		return
	_watch -= delta
	if _watch <= 0.0:
		_watch = look_every
		if _look_about():
			_start_pass()


func _landing(delta: float) -> void:
	var t := clampf(_mode_time / LAND_TIME, 0.0, 1.0)
	var e := t * t * (3.0 - 2.0 * t)
	global_position = _from.lerp(roost, e) + Vector3.UP * sin(PI * e) * 1.2
	_face(roost_facing, delta, 3.0)
	if _carrying is MazeEnemy and is_instance_valid(_carrying):
		_carrying.global_position = _feet() + Vector3.DOWN * 0.6
	if t >= 1.0:
		global_position = roost
		_roost_left = _rng.randf_range(roost_time.x, roost_time.y)
		_soar_left = _rng.randf_range(soar_time.x, soar_time.y)
		_dives = 0
		if _carrying is MazeEnemy and is_instance_valid(_carrying):
			# (home with its kill: it lies in the nest, and it eats)
			var prey := _carrying as MazeEnemy
			prey.global_position = nest_at + Vector3.UP * 0.3
			prey.set_physics_process(true)
			if Ecology.current:
				Ecology.current.kill(prey, self)
			else:
				prey.die()
				ate(Ecology.EAT_SECONDS)
			_roost_left = maxf(_roost_left, Ecology.EAT_SECONDS + 4.0)
		_carrying = null
		snatched = false
		defending = false
		_enter(Mode.ROOST)


# --- The world under it ---

## How high the world is under a point (the top of a wall, or the ground), from high above.
func _sky_over(at: Vector3) -> float:
	var from := Vector3(at.x, 400.0, at.z)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(at.x, -50.0, at.z), 1, _skip_players()))
	return (hit["position"] as Vector3).y if not hit.is_empty() else 0.0


## The highest the world is round a circle about `at`.
func _sky_round(at: Vector3, radius: float) -> float:
	var top := _sky_over(at)
	for k in 8:
		var a := TAU * k / 8.0
		top = maxf(top, _sky_over(at + Vector3(cos(a), 0.0, sin(a)) * radius))
	return top


## How far a ray goes from `from` along `way` before it meets the world (at most `far`).
func _free(from: Vector3, way: Vector3, far: float) -> float:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + way * far, 1, _skip_players()))
	return far if hit.is_empty() else from.distance_to(hit["position"])


## Whether nothing of the world stands between two points.
func _clear_line(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, _skip_players())
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Whether a point is in the open (not inside a wall or the ground).
func maze_free(at: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = at
	query.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_point(query, 1).is_empty()


func _skip_players() -> Array[RID]:
	var skip: Array[RID] = [get_rid()]
	for player: Node in players():
		if player is CollisionObject3D and is_instance_valid(player):
			skip.append((player as CollisionObject3D).get_rid())
	return skip


func _face(toward: Vector3, delta: float, rate: float) -> void:
	toward.y = 0.0
	if toward.length_squared() < 0.0001:
		return
	var want := toward.normalized()
	# (turning at most `rate` radians a second, as a big flier banks round)
	var angle := _heading.signed_angle_to(want, Vector3.UP)
	_heading = _heading.rotated(Vector3.UP, clampf(angle, -rate * delta, rate * delta)).normalized()


# --- How it looks ---

## Gives the creature what it is doing.
func _drive_look(delta: float) -> void:
	if look == null:
		return
	look.global_position = global_position
	look.rotation.y = atan2(_heading.x, _heading.z)
	look.grounded = _on_ground() or (mode == Mode.LAND and _mode_time > LAND_TIME * 0.82)
	look.tuck = 0.0
	look.talons = 0.0
	look.brake = 0.0
	look.grip = 1.0 if snatched and mode in [Mode.DIVE, Mode.CARRY, Mode.RETURN, Mode.LAND] else 0.0
	match mode:
		Mode.ROOST, Mode.STALK, Mode.LASH:
			look.effort = 0.0
		Mode.LAUNCH:
			look.effort = 1.0
		Mode.SOAR, Mode.RETURN:
			# (soaring on still wings, with a few deep slow beats now and then)
			look.effort = 0.5 if fmod(_mode_time + float(_rng.seed % 7), 11.0) < 2.4 else 0.0
			if mode == Mode.RETURN and snatched:
				look.effort = 0.8
				look.talons = 0.6
		Mode.PASS:
			look.effort = 0.15
		Mode.WHEEL:
			look.effort = 0.3 if fmod(_mode_time, 5.0) < 1.5 else 0.0
		Mode.DIVE:
			var left := _time_to_target()
			look.effort = 0.0
			look.talons = 1.0 if left < TALONS_AT or _past > 0.0 else 0.0
			look.tuck = 0.0 if look.talons > 0.0 else 1.0
			look.brake = 0.35 if look.talons > 0.0 else 0.0
		Mode.CARRY:
			look.effort = 1.0
			look.talons = 0.7
		Mode.CLIMB:
			look.effort = 1.0
		Mode.LAND, Mode.ALIGHT:
			look.effort = 0.5
			look.brake = 1.0
			look.talons = 0.6
	if quarry and is_instance_valid(quarry) and mode in [Mode.ROOST, Mode.PASS, Mode.WHEEL, Mode.DIVE, Mode.ALIGHT, Mode.STALK, Mode.LASH]:
		look.aim = quarry.global_position + Vector3.UP * 1.0
	else:
		look.aim = Vector3.INF
	_drive_shadow()


## Its shadow on the ground (or wall top) under it, near anyone: darker and sharper the lower it is.
func _drive_shadow() -> void:
	if look == null or _far or _on_ground() or (mode == Mode.LAUNCH and _mode_time < 0.5):
		if look:
			look.show_shadow(Vector3.INF)
		return
	var near := nearest_player(global_position)
	if near == null or Vector2(near.global_position.x - global_position.x, near.global_position.z - global_position.z).length() > 70.0:
		look.show_shadow(Vector3.INF)
		return
	_shadow_check += 1
	if _shadow_check % 3 == 0:
		_shadow_y = _sky_over(global_position)
	var high := global_position.y - _shadow_y
	look.show_shadow(Vector3(global_position.x, _shadow_y, global_position.z), clampf(1.4 - high / 45.0, 0.85, 1.0), clampf(high / 80.0, 0.0, 0.35))


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


# --- Being run by someone else ---

func yaw() -> float:
	return atan2(_heading.x, _heading.z)


func net_state() -> int:
	return mode


## How many times it has screamed, so a puppet does too; and whether it has snatched someone.
func net_flag() -> int:
	return (_calls & 0x7f) | (0x80 if snatched and mode in [Mode.DIVE, Mode.CARRY] else 0)


## The point of its dive, where it comes down in a hall, or its nest.
func net_point() -> Vector3:
	if mode == Mode.DIVE:
		return dive_at
	if mode == Mode.ALIGHT:
		return land_at
	return nest_at


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	var was := mode
	mode = state as Mode
	if mode != was:
		_mode_time = 0.0
		if mode == Mode.DIVE and look:
			look.rush()
		if mode == Mode.LAUNCH and look:
			look.launch()
		if mode == Mode.LASH and look:
			look.strike()
	_heading = Vector3(sin(facing), 0.0, cos(facing))
	snatched = flag & 0x80 != 0
	var calls := flag & 0x7f
	if _heard_calls >= 0 and calls != _heard_calls and look:
		look.shriek()
	_heard_calls = calls
	if mode == Mode.DIVE:
		dive_at = point
	elif mode == Mode.ALIGHT:
		land_at = point
	elif point.is_finite():
		if not nest_at.is_finite() or nest_at.distance_to(point) > 1.0:
			nest_at = point
			_puppet_nest()
		if mode == Mode.ROOST:
			roost = at
	# (it has snatched someone: if it is the one on this machine, they are lifted here too)
	if snatched and look:
		var mine := local_player()
		if mine and mine.global_position.distance_to(look.carry_point()) < 4.0:
			carry(mine, self, CARRY_TIME + 0.4)


## A puppet's nest, where the host's is: its mate's if that has one there already.
func _puppet_nest() -> void:
	if not is_inside_tree():
		return
	for other: Node in get_tree().get_nodes_in_group(&"wyverns"):
		if other != self and other is MazeWyvern and (other as MazeWyvern).puppet and (other as MazeWyvern).nest and (other as MazeWyvern).nest_at.distance_to(nest_at) < 1.0:
			return
	if nest:
		nest.global_position = nest_at + Vector3.UP * 0.02
		return
	_build_nest()


func _follow_news(delta: float) -> void:
	if not _heard:
		return
	_mode_time += delta
	_heard_at += _heard_moving * delta
	global_position = global_position.lerp(_heard_at, 1.0 - exp(-10.0 * delta))
	if global_position.distance_to(_heard_at) > 8.0:
		global_position = _heard_at
	velocity = _heard_moving


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	_heading = Vector3(sin(facing), 0.0, cos(facing))
	if look:
		look.grounded = _on_ground()
		_drive_look(0.0)
		look.settle()


func _puppet_changed() -> void:
	collision_mask = 0
	_set_body(_on_ground() if is_inside_tree() else false)

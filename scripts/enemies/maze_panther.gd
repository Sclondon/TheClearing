class_name MazePanther
extends MazeCat
## A black panther (creatures/big_cat: BigCat, its kind PANTHER: a melanistic
## leopard), set to hunt the maze alone. How it looks and moves is the
## creature's, how it gets about MazeCat's; this is what it thinks.
##
## IT LIES UP HIGH. It rests on a ledge over a hall (the mezzanine along the
## walls, a terrace's top), and gets about on the ground of the halls and back
## up by ivy, as a leopard keeps to its trees. Its kills it drags up its ivy to
## eat on the ledge (Ecology: a big meat-eater; it takes deer, dogs, coyotes,
## lynx, baboons).
##
## IT STALKS. Seeing someone, from a ledge it follows them along it, keeping
## over them and a little behind; on the ground it comes on behind them low and
## slow, very quiet, freezing when they look round. It is strongest at night
## (`night`): it sees further, comes on faster and gives up later.
##
## THE TELLS (fair warning): its eyes give the light back (at night, two points
## of light in the dark, often above you); within `growl_range` a low rumbling
## growl; the end of its tail twitching; and before it springs, the wiggle of
## its hindquarters (BigCat.WIGGLE_TIME).
##
## FACE IT. Cats ambush from behind: while someone looks at it (faces it, or
## has it in the middle of the screen) it HESITATES, crouched, tail lashing,
## and does not spring; looked at long enough (`face_down_time`) it slinks off
## and lets them be a while. Turned to look at during its wiggle, it calls the
## pounce off. Walking away slowly is safe enough; turn your back near it and it
## creeps closer, and springs from `pounce_range`.
##
## DON'T RUN. Running from it near (`chase_range`) sets it off: it drops off
## its ledge behind you or bursts after you on the ground, faster than a sprint
## (`chase_speed`) but only for a few seconds (`chase_time`), and pounces when
## it is close enough. Further off, a sprint gets away; corners and walls lose it.
##
## Spawn: `MazePanther.new()`, `maze` set, put in a hall cell (one beside a wall
## with a ledge, to start up on it), added to the scene.

@export var prowl_speed := 1.3
@export var stalk_speed := 0.8
## Closing up on someone far ahead (a quiet trot), and the burst of a chase.
@export var close_speed := 2.6
@export var chase_speed := 8.4
@export var chase_time := 3.2
@export var chase_range := 12.0
@export var pounce_range := 4.4
@export var growl_range := 10.0
## How long it will be looked at before it gives up on someone, by day and by night.
@export var face_down_time := Vector2(4.0, 7.0)
## How long someone must look away, near it, before it springs (day, night).
@export var dare := Vector2(1.3, 0.6)
@export var lie_up := true

var _shy := 0.0
var _faced_for := 0.0
var _growl_in := 0.0
var _away := Vector3.INF
var _carried: Node3D
var _carry_ivy: Node3D
var _ledge_dir := 1.0
var _next_look := 0.0


func _init() -> void:
	kind = BigCat.Kind.PANTHER
	size = 1.0
	sight_range = 42.0
	hear_range = 8.0
	memory = 12.0
	alert_range = 0.0
	pack = &"panthers"
	acceleration = 14.0
	look_every = 0.25


func _settle_in() -> void:
	if not lie_up or puppet:
		return
	var spot := _ledge_beside(global_position)
	if not spot.is_empty():
		_put_on_ledge(spot, 1.0 if _rng.randf() < 0.5 else -1.0)
		_set_mode(Mode.REST)
		_prev_pos = global_position
		_curr_pos = global_position


func huntable(player: Node3D) -> bool:
	if not super(player):
		return false
	return not maze.in_clearing(maze.cell_at(player.global_position)) or not keep_out_of_clearing


func _think(delta: float) -> void:
	_shy -= delta
	_growl_in -= delta
	# (it sees further in the dark)
	sight_range = lerpf(32.0, 52.0, night)
	var who := quarry if hunting() and not (quarry is MazeEnemy) else null
	var prey := quarry as MazeEnemy if hunting() and quarry is MazeEnemy else null
	if who and _shy > 0.0:
		# (it has given them up for now)
		who = null
	chasing = who != null and mode in [Mode.STALK, Mode.CHASE, Mode.POUNCE, Mode.DROP]
	_point = who.global_position + Vector3.UP * CHEST if who else (prey.global_position + Vector3.UP * 0.3 if prey else Vector3.INF)
	if threat and is_instance_valid(threat) and not threat.dead and place == Place.GROUND:
		_set_mode(Mode.SLIP)
		_steer(_flat(_away_from(threat.global_position) - global_position), chase_speed * 0.8, delta)
		return
	if mode == Mode.DRAG:
		_drag(delta)
		return
	if _eating > 0.0 and mode in [Mode.FEED, Mode.GUARD]:
		_at_kill(who, delta)
		return
	if who:
		if place == Place.LEDGE:
			_stalk_from_above(who, delta)
		else:
			_stalk(who, delta)
		return
	if prey:
		if place == Place.LEDGE:
			_drop_to(_ground_below(prey.global_position), Mode.HUNT)
		else:
			_hunt(prey, delta)
		return
	_idle(delta)


# --- Nobody about ---

func _idle(delta: float) -> void:
	_faced_for = 0.0
	if place == Place.LEDGE:
		if mode != Mode.REST and mode != Mode.PROWL:
			_set_mode(Mode.REST)
		if mode == Mode.REST:
			velocity = Vector3.ZERO
			if _mode_time > 30.0 + _rng.randf() * 30.0:
				_set_mode(Mode.PROWL)
		elif not _ledge_walk(_ledge_dir, prowl_speed, delta):
			_ledge_dir = -_ledge_dir
			_set_mode(Mode.REST)
		elif _mode_time > 15.0:
			_set_mode(Mode.REST)
		return
	# On the ground it prowls, and goes back up the first ivy it comes by.
	if mode != Mode.PROWL:
		_set_mode(Mode.PROWL)
	_next_look -= delta
	if _next_look <= 0.0:
		_next_look = 5.0
		var up := _ivy_up(global_position, 30.0)
		_away = (up[0] as Ladder).stand((up[0] as Ladder).bottom_y()) if not up.is_empty() else Vector3.INF
	if _away.is_finite():
		if _flat(_away - global_position).length() < 1.8:
			var up := _ivy_up(global_position, 4.0)
			_away = Vector3.INF
			if not up.is_empty():
				_start_climb(up[0], true)
				return
		_steer(_way_to(_away), prowl_speed, delta)
		return
	_steer(way(_radius), prowl_speed, delta)


# --- Stalking someone ---

## Up on its ledge: along it, over them and a little behind, crouched when they
## look up at it; down behind them when they turn their back or run.
func _stalk_from_above(who: Node3D, delta: float) -> void:
	var gap := _gap(who)
	var looked_at := _watched(who) > 0.75
	_unwatched = 0.0 if looked_at else _unwatched + delta
	_faced_for = _faced_for + delta if looked_at and gap < 20.0 else maxf(_faced_for - delta * 0.3, 0.0)
	_maybe_growl(gap)
	if _faced_for > lerpf(face_down_time.x, face_down_time.y, night):
		_give_up(who)
		return
	if looked_at:
		_set_mode(Mode.HESITATE)
		_hold_on_ledge(who.global_position, delta)
		return
	_set_mode(Mode.STALK)
	# (keeps level with them along the ledge, a couple of metres behind the way they go)
	var behind := who.global_position - _speed_of(who).normalized() * 2.0 if _speed_of(who).length() > 0.5 else who.global_position
	var off := _ledge_offset(behind)
	if absf(off) > 0.8:
		if not _ledge_walk(signf(off), stalk_speed * 2.5 if absf(off) > 6.0 else stalk_speed * 1.5, delta):
			_hold_on_ledge(who.global_position, delta)
	else:
		_hold_on_ledge(who.global_position, delta)
	# Down on them: they run, or they have turned their back near under it.
	var under := gap < 12.0 and who.global_position.y < global_position.y - 2.0
	if under and (_running_away(who) or _unwatched > lerpf(dare.x, dare.y, night) * 2.0):
		var to := _flat(who.global_position - global_position)
		var land := who.global_position - _speed_of(who).normalized() * 2.5 if _speed_of(who).length() > 0.5 else who.global_position - to.normalized() * 2.5
		_drop_to(_ground_below(land), Mode.CHASE if _running_away(who) else Mode.STALK)


func _hold_on_ledge(at: Vector3, delta: float) -> void:
	velocity = Vector3.ZERO
	var to := _flat(at - global_position)
	if to.length() > 0.1:
		facing_yaw = lerp_angle(facing_yaw, atan2(to.x, to.z), 1.0 - exp(-4.0 * delta))


## On the ground: on behind them, low; holding when they look; after them if they run.
func _stalk(who: Node3D, delta: float) -> void:
	var gap := _gap(who)
	var looked_at := _watched(who) > 0.75
	_unwatched = 0.0 if looked_at else _unwatched + delta
	_faced_for = _faced_for + delta if looked_at and gap < 20.0 else maxf(_faced_for - delta * 0.3, 0.0)
	_maybe_growl(gap)
	if mode == Mode.CHASE:
		_chase(who, gap, delta)
		return
	if _faced_for > lerpf(face_down_time.x, face_down_time.y, night):
		_give_up(who)
		return
	if _running_away(who, 3.4) and gap < chase_range:
		_set_mode(Mode.CHASE)
		_growl(1.2)
		return
	if looked_at and gap < 22.0:
		_set_mode(Mode.HESITATE)
		_hold(delta, who.global_position)
		return
	_set_mode(Mode.STALK)
	var dare_now := lerpf(dare.x, dare.y, night)
	if gap < pounce_range and _unwatched > dare_now and is_on_floor() and nav.sees(global_position + Vector3.UP * 0.5, who.global_position + Vector3.UP * 0.5, pounce_range + 1.0):
		_start_pounce(_lead(who))
		return
	# (behind them, keeping to their back)
	var behind := who.global_position - _forward_of(who) * 1.5
	var speed := close_speed if gap > 14.0 else lerpf(stalk_speed, stalk_speed * 1.6, night)
	_steer(_way_to(behind), speed, delta)
	cat.freeze_step = false


func _chase(who: Node3D, gap: float, delta: float) -> void:
	if _mode_time > chase_time + 0.8 * night or gap > chase_range * 2.0:
		# (spent: it stands, and lets them go)
		_give_up(who, 8.0)
		return
	if gap < pounce_range * 0.75 and is_on_floor():
		_start_pounce(_lead(who, true), true)
		return
	_steer(_way_to(who.global_position), chase_speed, delta)


## Where they will be when it lands, as they are going.
func _lead(who: Node3D, running := false) -> Vector3:
	var them := _speed_of(who)
	return who.global_position + Vector3.UP * 0.4 + them * ((0.0 if running else BigCat.WIGGLE_TIME * 0.15) + Dog.GATHER_TIME * (0.4 if running else 1.0) + Dog.SPRING_TIME * 0.8)


## The way someone faces (from how they face, else how they go).
static func _forward_of(who: Node3D) -> Vector3:
	var facing: Variant = who.get(&"facing_yaw")
	if facing != null:
		return Vector3(sin(facing), 0.0, cos(facing))
	var moving := _speed_of(who)
	return moving.normalized() if moving.length() > 0.2 else Vector3.FORWARD


func _maybe_growl(gap: float) -> void:
	if gap < growl_range and _growl_in <= 0.0:
		_growl(2.0)
		_growl_in = _rng.randf_range(6.0, 9.0)


## Gives up on `who` for `seconds`, and slinks off.
func _give_up(who: Node3D, seconds := 25.0) -> void:
	_shy = seconds
	_faced_for = 0.0
	if quarry == who:
		quarry = null
		_forget = 0.0
		_last_seen = Vector3.INF
	_set_mode(Mode.PROWL if place == Place.GROUND else Mode.REST)


## Looked at as it wiggles: it calls the pounce off (it would rather not be seen).
func _pounce_wiggling(_delta: float) -> void:
	if quarry == null or quarry is MazeEnemy:
		return
	if _watched(quarry) > 0.85 and cat.wiggle_progress() < 0.8:
		_call_off_pounce()
		_faced_for = maxf(_faced_for, 1.0)


func _pounce_done(caught: bool) -> void:
	if caught:
		# (it has had them: off it goes, and up)
		_give_up(quarry if quarry else null, 30.0)
	else:
		_set_mode(Mode.HESITATE)
		_unwatched = 0.0


# --- Prey, and its kill ---

func _hunt(prey: MazeEnemy, delta: float) -> void:
	var gap := _gap(prey)
	if gap < pounce_range and is_on_floor():
		_start_pounce(prey.global_position + Vector3.UP * 0.3)
		return
	_set_mode(Mode.HUNT if gap < 12.0 else Mode.PROWL)
	_steer(_way_to(prey.global_position), stalk_speed * 1.5 if gap < 12.0 else close_speed, delta)


## Fed: it takes the carcass in its jaws and drags it up the nearest ivy, to eat on the ledge.
func ate(seconds: float) -> void:
	super(seconds)
	_carried = null
	_carry_ivy = null
	if place != Place.GROUND or Ecology.current == null or Ecology.current.insects == null:
		return
	var nearest := 3.5
	for carcass: Node3D in Ecology.current.insects.carcasses:
		if is_instance_valid(carcass) and carcass.global_position.distance_to(global_position) < nearest:
			nearest = carcass.global_position.distance_to(global_position)
			_carried = carcass
	var up := _ivy_up(global_position, 35.0)
	if _carried and not up.is_empty():
		_carry_ivy = up[0]
		_eating = 60.0
		_set_mode(Mode.DRAG)


func _drag(delta: float) -> void:
	if _carry_ivy == null or not is_instance_valid(_carry_ivy) or _carried == null or not is_instance_valid(_carried):
		_eating = EAT_SECONDS_HERE
		_set_mode(Mode.FEED)
		return
	var ladder := _carry_ivy as Ladder
	var foot := ladder.stand(ladder.bottom_y())
	if _flat(foot - global_position).length() < 1.6:
		_start_climb(_carry_ivy, true)
		_set_mode(Mode.CLIMB)
		return
	_steer(_way_to(foot), prowl_speed * 1.2, delta)
	if _mode_time > 40.0:
		_eating = EAT_SECONDS_HERE
		_set_mode(Mode.FEED)


## How long it eats a kill where it is, seconds.
const EAT_SECONDS_HERE := 12.0


func _arrived(at: Place) -> void:
	if at == Place.LEDGE:
		if _carried and is_instance_valid(_carried):
			# (it lays the kill down on the ledge and eats)
			_carried.global_position = global_position + ledge_out.cross(Vector3.UP) * 0.7 * signf(sin(facing_yaw) + 0.01)
			_carried = null
			_carry_ivy = null
			_eating = EAT_SECONDS_HERE
			_set_mode(Mode.FEED)
		else:
			_set_mode(Mode.REST)


## At its kill: eating; someone near, it guards it (a growl), and springs if they come on.
func _at_kill(who: Node3D, delta: float) -> void:
	velocity = Vector3.ZERO if place != Place.GROUND else velocity
	if who == null or _gap(who) > 9.0:
		_set_mode(Mode.FEED)
		if place == Place.GROUND:
			_hold(delta)
		return
	var gap := _gap(who)
	_set_mode(Mode.GUARD)
	_maybe_growl(gap)
	if place == Place.GROUND:
		_hold(delta, who.global_position)
		if gap < pounce_range * 0.8 and _mode_time > 1.2:
			_eating = 0.0
			_start_pounce(_lead(who))
	else:
		_hold_on_ledge(who.global_position, delta)


func _pose(delta: float) -> void:
	super(delta)
	if _carried and is_instance_valid(_carried) and cat:
		# (the kill, hanging from its jaws)
		_carried.global_position = cat.jaw_position() + Vector3.DOWN * 0.25

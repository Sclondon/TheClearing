class_name MazeLynx
extends MazeCat
## A Eurasian lynx (creatures/big_cat: BigCat, its kind LYNX), set loose in the
## maze. How it looks and moves is the creature's, how it gets about MazeCat's;
## this is what it thinks.
##
## A HUNTER OF SMALL THINGS (Ecology: a small meat-eater). It keeps to the
## ledges over the halls, lying up where its ivy comes out at the top, and to the
## halls' floors; hungry, it goes down for what is smaller than it (whatever
## the maze has of hares, rabbits, rats and birds): it stalks low, freezes, and
## pounces. Bigger meat-eaters it runs from.
##
## SHY OF PEOPLE. Seeing someone it WATCHES them: still, ears up, staring
## (crouched on its ledge, sitting in a hall). Watched back a while, or come
## within `shy_range`, it SLIPS away: along its ledge, down the halls, glancing
## back. Run at, or come within `flee_range`, and it FLEES at a gallop (off its
## ledge into the hall if it must); a little later it comes back to watch.
##
## DANGEROUS ONLY CORNERED, OR AT ITS KILL. With no way past someone (the way
## away from them leads back by them: a dead end with them in its mouth), or
## while it eats and someone comes near: it crouches over the kill or backs up,
## ears flat, and HISSES (the warning: a hiss and a spit, lips off its fangs).
## Come on within `strike_range` and it SWIPES: a forepaw raised and slashed,
## which knocks down (catches) whoever it lands on. Back off and it lets you be.
## After a swipe it bolts.
##
## Spawn (as MazeEnemies does any MazeEnemy): `MazeLynx.new()`, `maze` set, put
## in a hall cell (beside a wall with a ledge, for it to go up onto), added.

## Walking, slipping away, fleeing; stalking prey, and its pounce run.
@export var walk_speed := 1.1
@export var slip_speed := 2.2
@export var flee_speed := 7.0
@export var stalk_speed := 0.7
@export var hunt_speed := 3.0
## How near someone may come before it slips off, and before it flees.
@export var shy_range := 15.0
@export var flee_range := 7.0
## How near it lets someone come, cornered or at its kill, before it hisses, and swipes.
@export var warn_range := 6.0
@export var strike_range := 1.7
## How long it will be watched back before it slips off, seconds.
@export var stare_time := 4.0
@export var lie_up := true

var _shy := 0.0
var _away := Vector3.INF
var _watched_for := 0.0
var _hissed_at := 0.0
var _next_rest := 0.0
var _ledge_dir := 1.0


func _init() -> void:
	super()
	kind = BigCat.Kind.LYNX
	size = 1.0
	sight_range = 40.0
	hear_range = 10.0
	memory = 9.0
	alert_range = 0.0
	pack = &"lynxes"
	look_every = 0.25


func _settle_in() -> void:
	# (it starts up on a ledge over the hall it is put in, if there is one)
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
	_hissed_at -= delta
	var who := quarry if hunting() and not (quarry is MazeEnemy) else null
	var prey := quarry as MazeEnemy if hunting() and quarry is MazeEnemy else null
	chasing = mode in [Mode.HISS, Mode.SWIPE]
	_point = who.global_position + Vector3.UP * CHEST if who else (prey.global_position + Vector3.UP * 0.2 if prey else Vector3.INF)
	# Something bigger that would eat it: away.
	if threat and is_instance_valid(threat) and not threat.dead:
		_run_from(threat.global_position, delta)
		return
	# At its kill: it will not be driven off it lightly.
	if _eating > 0.0 and mode in [Mode.FEED, Mode.GUARD, Mode.HISS]:
		_at_kill(who, delta)
		return
	if who:
		_about_someone(who, delta)
		return
	if prey and place == Place.GROUND:
		_hunt(prey, delta)
		return
	if prey and place == Place.LEDGE:
		# (down off the ledge to it)
		_drop_to(_ground_below(prey.global_position), Mode.HUNT)
		return
	_idle(delta)


## Nobody about: lying up on its ledge, or going about the halls (and back up when there is ivy).
func _idle(delta: float) -> void:
	if mode in [Mode.WATCH, Mode.SLIP, Mode.FLEE, Mode.HISS, Mode.GUARD, Mode.HESITATE, Mode.HUNT, Mode.STALK]:
		_set_mode(Mode.PROWL if place == Place.GROUND else Mode.REST)
	if place == Place.LEDGE:
		if mode == Mode.REST:
			if _mode_time > 25.0 + _rng.randf() * 20.0:
				_set_mode(Mode.PROWL)
		elif not _ledge_walk(_ledge_dir, walk_speed, delta):
			# (the end of its ledge: back the other way another time)
			_ledge_dir = -_ledge_dir
			_set_mode(Mode.REST)
		elif _mode_time > 12.0:
			_set_mode(Mode.REST)
		return
	# On the ground: about the halls, and up the first ivy to a ledge it comes by.
	_set_mode(Mode.PROWL)
	_next_rest -= delta
	if _next_rest <= 0.0:
		_next_rest = 6.0
		var up := _ivy_up(global_position, 9.0)
		if not up.is_empty():
			var foot: Vector3 = (up[0] as Ladder).stand((up[0] as Ladder).bottom_y())
			if _flat(foot - global_position).length() < 2.5:
				_start_climb(up[0], true)
				return
			_away = foot
	if _away.is_finite() and _flat(_away - global_position).length() > 1.0:
		_steer(_way_to(_away), walk_speed, delta)
		if _flat(_away - global_position).length() < 2.5:
			var up := _ivy_up(global_position, 4.0)
			_away = Vector3.INF
			if not up.is_empty():
				_start_climb(up[0], true)
		return
	_steer(way(_radius), walk_speed, delta)


## Someone about: watch them, slip off, flee; hiss and swipe only when cornered.
func _about_someone(who: Node3D, delta: float) -> void:
	var gap := _gap(who)
	var looked_at := _watched(who) > 0.8
	_watched_for = _watched_for + delta if looked_at else maxf(_watched_for - delta * 0.5, 0.0)
	if place == Place.LEDGE:
		# Up on its ledge it is out of their reach: it watches, and slips off along it.
		var below := absf(who.global_position.y - global_position.y) > 2.0
		if not below and gap < flee_range:
			# (they have come up onto its ledge: off it, into the hall)
			_drop_to(_ground_below(global_position - (who.global_position - global_position)), Mode.FLEE)
			_away = Vector3.INF
			return
		if mode == Mode.SLIP:
			if not _ledge_walk(-_ledge_way_to(who.global_position), slip_speed, delta) or _mode_time > 6.0:
				_set_mode(Mode.WATCH)
				_watched_for = 0.0
			return
		_set_mode(Mode.WATCH)
		_hold_on_ledge(who.global_position, delta)
		if _watched_for > stare_time or (gap < shy_range * 0.6 and below):
			_set_mode(Mode.SLIP)
		return
	# On the ground.
	var cornered := _cornered(who)
	if gap < warn_range and cornered:
		_cornered_by(who, gap, delta)
		return
	if mode == Mode.FLEE:
		_run_from(who.global_position, delta)
		if _mode_time > 3.0 and gap > shy_range:
			_set_mode(Mode.SLIP)
		return
	if gap < flee_range or _running_at(who):
		_set_mode(Mode.FLEE)
		_shy = 12.0
		return
	if mode == Mode.SLIP or _shy > 0.0 or gap < shy_range or _watched_for > stare_time:
		if mode != Mode.SLIP:
			_set_mode(Mode.SLIP)
		var away := _away_from(who.global_position)
		_steer(_flat(away - global_position), slip_speed, delta)
		if _mode_time > 5.0 and gap > shy_range * 1.4:
			_set_mode(Mode.WATCH)
			_watched_for = 0.0
		return
	_set_mode(Mode.WATCH)
	_hold(delta, who.global_position)


## Crouched on its ledge, turned to look down at `at`.
func _hold_on_ledge(at: Vector3, delta: float) -> void:
	velocity = Vector3.ZERO
	var to := _flat(at - global_position)
	if to.length() > 0.1:
		facing_yaw = lerp_angle(facing_yaw, atan2(to.x, to.z), 1.0 - exp(-4.0 * delta))


## Whether it has no way away from `who` but past them.
func _cornered(who: Node3D) -> bool:
	var here := maze.cell_at(global_position)
	var them := maze.cell_at(who.global_position)
	var away := _away_from(who.global_position)
	var mine := _gap(who)
	# (the best way away goes no further from them than it is: past them, or nowhere)
	if _flat(away - who.global_position).length() < mine + 2.5:
		return true
	return here == them and nav.dead_end(here)


## Cornered by `who`, `gap` off: a hiss as the warning, a swipe if they come on.
func _cornered_by(who: Node3D, gap: float, delta: float, backs := true) -> void:
	if mode != Mode.HISS:
		_set_mode(Mode.HISS)
		if _hissed_at <= 0.0:
			_hiss()
			_hissed_at = 2.0
	# (backed up as far as it can go, facing them)
	var back := _flat(global_position - who.global_position).normalized()
	_steer(back if backs and gap < warn_range - 1.0 else Vector3.ZERO, 0.6, delta)
	facing_yaw = lerp_angle(facing_yaw, atan2(-back.x, -back.z), 1.0 - exp(-8.0 * delta))
	if _hissed_at <= 0.0:
		_hiss()
		_hissed_at = 2.2
	# (it has warned them: the hiss is a second old at least)
	if gap < strike_range and _mode_time > 0.9:
		_start_swipe(who)


## At its kill: eating, crouched over it; someone near and it guards it, hisses, swipes.
func _at_kill(who: Node3D, delta: float) -> void:
	var gap := _gap(who) if who else INF
	if who and gap < warn_range:
		# (it keeps its ground over the kill)
		_cornered_by(who, gap, delta, false)
		return
	_set_mode(Mode.FEED if not who or gap > warn_range + 3.0 else Mode.GUARD)
	_hold(delta, who.global_position if who else Vector3.INF)


func _swipe_done(caught: bool) -> void:
	# (whether it struck or not, it bolts)
	_set_mode(Mode.FLEE)
	_shy = 14.0
	_eating = 0.0
	if caught:
		_hissed_at = 3.0


## Off away from `danger` at a gallop.
func _run_from(danger: Vector3, delta: float) -> void:
	if place == Place.LEDGE:
		if not _ledge_walk(-_ledge_way_to(danger), flee_speed * 0.6, delta):
			_drop_to(_ground_below(global_position - (danger - global_position)), Mode.FLEE)
		return
	if mode != Mode.FLEE:
		_set_mode(Mode.FLEE)
	_steer(_flat(_away_from(danger) - global_position), flee_speed, delta)


## After prey: low and slow, freezing when it is near, and a pounce.
func _hunt(prey: MazeEnemy, delta: float) -> void:
	var gap := _gap(prey)
	if gap < 3.2 and is_on_floor():
		_start_pounce(prey.global_position + Vector3.UP * 0.2)
		return
	_set_mode(Mode.HUNT if gap < 10.0 else Mode.PROWL)
	_steer(_way_to(prey.global_position), stalk_speed if gap < 10.0 else hunt_speed, delta)


func _pounce_done(_caught: bool) -> void:
	_set_mode(Mode.PROWL)


func _arrived(at: Place) -> void:
	if at == Place.LEDGE:
		_set_mode(Mode.REST)

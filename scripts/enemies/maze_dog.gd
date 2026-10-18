class_name MazeDog
extends MazeEnemy
## A feral dog loose in the maze, one of a pack: a tracker. It is drawn and
## moved by Dog (creatures/dog/dog.gd); this is what it thinks.
##
## THE TRAIL. Every player leaves a trail of scent on the ground behind them
## (`trails`: a crumb every couple of metres they go on foot, kept for
## `scent_life` seconds). A dog that comes across a trail (a crumb within
## `scent_range` of it) puts its nose down and follows it, crumb by crumb, the
## way the player went, at a trot (`track_speed`, slower than a run), even
## with the player long out of sight. Where the trail stops (they climbed: on
## ivy, a vine, a terrace or a wall top no scent is left on the ground, and
## the next of it may be far off) it casts about, and gives up.
## THE CHASE. When it sees or hears a player (MazeEnemy's senses), it stops
## and bays, and the pack within `alert_range` takes up the hunt; then it runs
## them down at a gallop (`chase_speed`: faster than a run, slower than a
## sprint, so sprinting gets away, and when it has lost them it goes back to
## the trail, which is fresh). Someone who stands, walks or creeps near it it
## stalks instead: stiff, low and slow, snarling.
## THE BITE. Within `lunge_range` in front of it, it gathers itself and
## springs where they are going; `caught` only if its jaws close on them (a
## jump or a dodge to one side as it springs, and it misses). A miss, and it
## stands and shakes itself before it comes on.
##
## MEAT. Meat lying within `smell_meat` of it (Loot: thrown or put down; only a
## few metres off while it is after someone) it goes to and eats (EAT), even in
## the middle of a chase: a way to buy time. Held out to it (`feed`) while it is
## not springing, it stops and eats it from the hand.
## FRIENDS. Fed meat when it is hungry (Ecology), or a second piece when it is
## not, it is the `friend` of whoever gave it, and its look changes: tail up and
## wagging, ears up, hackles flat (Dog.friendly). It hunts no player then (the
## giver, nor anyone playing with them). It keeps at heel (HEEL: trotting after
## its friend, galloping to catch up, sitting when they stand a while), and
## waits below when they climb (WAIT: sat, looking up). What hunts and is near
## its friend it barks at, stiff, between them and it (WARN: a warning); what
## comes at its friend it goes for (GUARD): one smaller it can kill, it kills
## (Ecology), and one its size or bigger it springs at and harries, each bite
## staggering it a moment (`harry_seconds`: buying time; one big enough to eat
## a dog may turn on it). Left more than `far_behind` from its friend for
## `loyal_time` it goes feral again; killed, it is gone, and it is a feral dog
## when its den brings it back. Feeding several of a pack befriends several.
##
## `MazeDog.pack_of(count)` makes a pack (each a little different: which
## model, its colour, its size). Placed by MazeEnemies like the mummies.
##
## As a puppet it follows the host's news like the others; its bays (barks,
## once a friend), lunges and shakes come as counts in its flag, and are played
## here too. Whose friend it is (decided where the hunters are run) comes with
## its state (the seat, above the mode: `net_state`).

signal befriended(player: Node3D)
signal went_feral

enum Mode { ROAM, TRACK, CAST, BAY, CHASE, STALK, LUNGE, SHAKE, HEEL, WAIT, WARN, GUARD, EAT }

## How long it takes to eat a piece of meat, seconds.
const EAT_TIME := 2.6
## Modes it has only as a friend.
const FRIEND_MODES := [Mode.HEEL, Mode.WAIT, Mode.WARN, Mode.GUARD]

## How much bigger than the model it is drawn.
const SCALE := 1.35
## How far apart the crumbs of a trail are (m), and a gap in a trail that it cannot cross by scent.
const CRUMB := 2.0
const GAP := 9.0
## The highest a crumb is laid (m above the maze's floor): anyone higher is off the ground.
const GROUND := 1.6

## Every player's trail: player -> PackedVector4Array of (where, when), oldest first.
static var trails := {}
static var _laid_frame := -1
static var _clock := 0.0

@export var roam_speed := 1.5
@export var track_speed := 3.0
@export var chase_speed := 5.2
@export var stalk_speed := 1.3
@export var acceleration := 14.0
@export var turn_rate := 9.0
@export var lunge_range := 3.2
## How near a trail must pass to be picked up, and how old it may be.
@export var scent_range := 6.0
@export var scent_life := 50.0
## Further than this from every player it is not posed (the walls hide it).
@export var pose_range := 70.0
@export var gravity := 24.0
## How it looks (set before it goes in; `pack_of` sets them).
@export var variant := 0
@export var coat_tint := Color.WHITE
@export var size := SCALE
@export_group("Meat and friends")
## How far off it smells meat lying on the ground (after someone, only `smell_chasing`).
@export var smell_meat := 14.0
@export var smell_chasing := 6.0
## How near its friend it keeps, and how fast it goes to catch up.
@export var heel_range := 2.6
@export var heel_speed := 6.2
## What hunts this near its friend it barks at; what comes at them this near it goes for.
@export var watch_range := 22.0
@export var guard_range := 14.0
## How long a bite staggers what it harries, seconds.
@export var harry_seconds := 1.6
## Left further than `far_behind` from its friend for `loyal_time` seconds, it goes feral.
@export var far_behind := 40.0
@export var loyal_time := 75.0

var mode := Mode.ROAM
var facing_yaw := 0.0
var dog: Dog
## Whose friend it is (null: nobody; feral), and their seat in the room (-1: none).
var friend: Node3D
var friend_seat := -1

var _radius := 0.38
var _trail_of: Node3D
## How far along each player's trail it has gone and lost it (player -> the time of the last crumb it reached).
var _spent := {}
var _crumb_time := 0.0
var _cast_left := 0.0
var _bay_left := 0.0
var _shake_left := 0.0
var _rest_left := 0.0
var _lunge_cool := 0.0
var _bit := false
var _lunges := 0
var _bays := 0
var _shakes := 0
var _point := Vector3.INF
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flagged := false
# Meat and friends.
var _fed := 0
var _meat: Node3D
var _feeder: Node3D
var _feeder_seat := -1
var _eat_left := 0.0
var _smell_in := 0.0
var _foe: Node3D
var _watch_in := 0.0
var _bark_in := 0.0
var _alone := 0.0
var _harried := 0
var _resting := 0.0


## A pack of `count`, ready to be placed: each its own model, colour and size.
static func pack_of(count: int, seed_value := 0) -> Array[MazeDog]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tints := [Color.WHITE, Color(1.08, 0.97, 0.88), Color(0.82, 0.82, 0.84), Color(1.02, 0.92, 0.82), Color(0.92, 0.88, 0.86)]
	var made: Array[MazeDog] = []
	for i in count:
		var one := MazeDog.new()
		one.variant = (i + rng.randi_range(0, 1)) % 2
		one.coat_tint = tints[(i + rng.randi_range(0, 4)) % tints.size()]
		one.size = SCALE * rng.randf_range(0.92, 1.06)
		made.append(one)
	return made


func _init() -> void:
	sight_range = 40.0
	hear_range = 11.0
	memory = 6.0
	alert_range = 40.0
	pack = &"dogs"
	look_every = 0.2


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	_radius = 0.3 * size
	shape.radius = _radius
	shape.height = 0.8 * size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	dog = Dog.new()
	dog.variant = variant
	dog.coat_tint = coat_tint
	dog.low_poly = Settings.low_poly
	dog.sit_to_howl = false
	dog.scale = Vector3.ONE * size
	add_child(dog)
	dog.top_level = true
	facing_yaw = rotation.y
	_prev_pos = global_position
	_curr_pos = global_position
	dog.global_position = global_position
	dog.rotation = Vector3(0.0, facing_yaw, 0.0)
	dog.settle()
	spotted.connect(_on_spotted)


# --- Trails ---

## Lays the players' trails (once a physics frame, whichever dog comes first).
func _lay_trails(delta: float) -> void:
	var frame := Engine.get_physics_frames()
	if frame == _laid_frame:
		return
	_laid_frame = frame
	_clock += delta
	for player: Variant in trails.keys():
		if not is_instance_valid(player):
			trails.erase(player)
	for player: Node3D in _live_players():
		if not is_instance_valid(player) or not player.is_inside_tree():
			continue
		var trail: PackedVector4Array = trails.get(player, PackedVector4Array())
		# (old scent fades)
		var old := 0
		while old < trail.size() and _clock - trail[old].w > scent_life:
			old += 1
		if old > 0:
			trail = trail.slice(old)
		var at := player.global_position
		var on_foot: bool = player.get(&"state") == null or int(player.get(&"state")) <= 1
		if player.has_method(&"is_on_floor"):
			on_foot = on_foot and player.call(&"is_on_floor")
		var ground := maze.world(maze.cell_at(at)).y if maze else 0.0
		# (laid for whoever can be hunted at all, even by a dog that is someone's friend)
		if on_foot and at.y - ground < GROUND and super.huntable(player):
			var last := Vector3(trail[-1].x, trail[-1].y, trail[-1].z) if not trail.is_empty() else Vector3.INF
			if not last.is_finite() or last.distance_to(at) > CRUMB:
				trail.append(Vector4(at.x, at.y, at.z, _clock))
		trails[player] = trail


## The players still in the game (a list of targets may keep one freed since:
## taken as a Node3D, a freed one is an error).
func _live_players() -> Array:
	return players().filter(func(p: Variant) -> bool: return is_instance_valid(p) and p is Node3D)


## The crumb of `player`'s trail it should make for next (INF: the trail is lost).
func _next_crumb(player: Node3D) -> Vector3:
	var trail: PackedVector4Array = trails.get(player, PackedVector4Array())
	var here := global_position
	# What it has come to of the trail is behind it now, and so is all before it.
	for crumb in trail:
		if crumb.w > _crumb_time and Vector2(crumb.x - here.x, crumb.z - here.z).length() < 1.3:
			_crumb_time = crumb.w
	var found := Vector3.INF
	for crumb in trail:
		if crumb.w <= _crumb_time:
			continue
		var at := Vector3(crumb.x, crumb.y, crumb.z)
		if not found.is_finite():
			found = at
		# (it takes the trail as far along as it can see down it, close by)
		elif at.distance_to(here) < CRUMB * 2.5 and nav.line_free(here, at, _radius):
			found = at
		else:
			break
	if found.is_finite() and found.distance_to(here) > GAP:
		return Vector3.INF
	return found


## A trail it has come across: the player whose crumb is nearest it (fresher
## first). Scent it has followed to its end and given up on is no use to it:
## only what is newer than that (`_spent`).
func _pick_up_scent() -> bool:
	var here := global_position
	var best_score := INF
	for player: Node3D in _live_players():
		if not huntable(player):
			continue
		var trail: PackedVector4Array = trails.get(player, PackedVector4Array())
		for crumb in trail:
			if crumb.w <= _spent.get(player, -1.0):
				continue
			var at := Vector3(crumb.x, crumb.y, crumb.z)
			var d := at.distance_to(here)
			if d > scent_range:
				continue
			var score := d + (_clock - crumb.w) * 0.1
			if score < best_score and nav.line_free(here, at, _radius * 0.5):
				best_score = score
				_trail_of = player
				_crumb_time = crumb.w - 0.001
	return best_score < INF


# --- Thinking ---

func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze == null:
		return
	_lay_trails(delta)
	_sense(delta)
	_lunge_cool -= delta
	if friend and not _keeps_friend(delta):
		_go_feral()
	_smell_for_meat(delta)
	var grounded := is_on_floor()
	var wish := Vector3.ZERO
	var speed := 0.0
	var after := quarry if hunting() and quarry.get(&"is_limp") != true and not friend else null
	match mode:
		Mode.LUNGE:
			var push := dog.lunge_push()
			velocity.x = push.x
			velocity.z = push.z
			if not _bit and friend:
				# (at what comes at its friend)
				if is_instance_valid(_foe) and dog.bite_hits(_foe.global_position + Vector3.UP * 0.6, 0.55 + _girth(_foe) * 0.6):
					_bit = true
					_bite(_foe)
			elif not _bit:
				for player: Node3D in _live_players():
					if huntable(player) and dog.bite_hits(player.global_position + Vector3.UP * 0.75, 0.55):
						_bit = true
						_catch(player)
						break
			if dog.lunge_stage() == Dog.Lunge.NONE:
				if _bit:
					mode = Mode.WARN if friend else Mode.ROAM
					_rest_left = 2.0
				else:
					mode = Mode.SHAKE
					_shake_left = Dog.GATHER_TIME + DogRig.SHAKE_TIME
					_shakes += 1
					dog.shake()
			_move(delta, grounded)
			return
		Mode.SHAKE:
			_shake_left -= delta
			if _shake_left <= 0.0:
				mode = Mode.HEEL if friend else (Mode.CHASE if after else Mode.ROAM)
		Mode.BAY:
			_bay_left -= delta
			if _bay_left <= 0.0:
				mode = Mode.CHASE
	if mode in [Mode.SHAKE, Mode.BAY]:
		_point = after.global_position + Vector3.UP * 0.9 if after else Vector3.INF
		_steer(Vector3.ZERO, 0.0, delta, grounded)
		return
	if mode == Mode.EAT:
		_eat_step(delta, grounded)
		return
	if friend:
		_friend_step(delta, grounded)
		return
	_rest_left -= delta
	if after:
		if mode != Mode.CHASE and mode != Mode.STALK:
			mode = Mode.CHASE
		_trail_of = after
		var to := after.global_position - global_position
		var flat := Vector3(to.x, 0.0, to.z)
		var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
		var them := Vector3(after.get(&"velocity")) if after.get(&"velocity") != null else Vector3.ZERO
		var slow := Vector2(them.x, them.z).length() < 2.0
		var seen := nav.sees(global_position + Vector3.UP, after.global_position + Vector3.UP, sight_range)
		mode = Mode.STALK if slow and seen and flat.length() < 10.0 else Mode.CHASE
		if grounded and _lunge_cool <= 0.0 and flat.length() < lunge_range * size / SCALE and absf(to.y) < 1.2 and forward.dot(flat.normalized()) > 0.75:
			_lunge(after, them)
			return
		wish = way(_radius)
		speed = stalk_speed if mode == Mode.STALK else chase_speed
		# (closing in for the bite, it goes straight at them if nothing is in the way)
		if flat.length() < 8.0 and nav.line_free(global_position, after.global_position, _radius):
			wish = flat
		_point = after.global_position + Vector3.UP * 0.9
	else:
		if mode in [Mode.CHASE, Mode.STALK]:
			# Lost them: back onto their trail, which is fresh.
			mode = Mode.TRACK if _trail_of else Mode.ROAM
		_point = Vector3.INF
		if mode == Mode.TRACK and not (is_instance_valid(_trail_of) and huntable(_trail_of)):
			mode = Mode.ROAM
		if mode == Mode.TRACK:
			var crumb := _next_crumb(_trail_of)
			if crumb.is_finite():
				var to := crumb - global_position
				wish = Vector3(to.x, 0.0, to.z) if nav.line_free(global_position, crumb, _radius) else _way_to(crumb)
				speed = track_speed
			else:
				mode = Mode.CAST
				_cast_left = 4.0
		if mode == Mode.CAST:
			# The trail has stopped: it casts about, nose down, and gives up.
			_cast_left -= delta
			if is_instance_valid(_trail_of):
				_spent[_trail_of] = _crumb_time
			if _pick_up_scent() and _next_crumb(_trail_of).is_finite():
				mode = Mode.TRACK
			elif _cast_left <= 0.0:
				mode = Mode.ROAM
				_trail_of = null
			else:
				wish = Vector3(sin(_cast_left * 1.7), 0.0, cos(_cast_left * 1.3))
				speed = 0.9
		if mode == Mode.ROAM:
			if _rest_left <= 0.0 and _pick_up_scent():
				mode = Mode.TRACK
			else:
				wish = way(_radius)
				speed = roam_speed
	var push := _apart(_radius)
	if wish.length() > 0.01:
		wish = wish.normalized()
		if push != Vector3.ZERO:
			wish = (wish + push * 0.6).normalized()
	_steer(wish, speed, delta, grounded)


func _way_to(point: Vector3) -> Vector3:
	var to := nav.waypoint(global_position, point, MazeNav.clearance_for(_radius)) - global_position
	to.y = 0.0
	return to


func _steer(wish: Vector3, speed: float, delta: float, grounded: bool) -> void:
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, acceleration * delta)
	velocity.x = current.x
	velocity.z = current.z
	_move(delta, grounded)


func _move(delta: float, grounded: bool) -> void:
	if not grounded:
		velocity.y -= gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


## Springs at `who`, where they will be by the time it lands.
func _lunge(who: Node3D, them: Vector3) -> void:
	mode = Mode.LUNGE
	_bit = false
	_lunges += 1
	_lunge_cool = 1.2
	_point = who.global_position + Vector3(them.x, 0.0, them.z) * (Dog.GATHER_TIME + Dog.SPRING_TIME * 0.8)
	velocity.x = 0.0
	velocity.z = 0.0
	dog.lunge(_point)


func _on_spotted(_player: Node3D) -> void:
	if puppet or friend or mode in [Mode.LUNGE, Mode.SHAKE, Mode.EAT]:
		return
	mode = Mode.BAY
	_bay_left = 0.8
	_bays += 1
	dog.howl(0.8)


## Told by its pack: it joins the hunt without stopping to bay.
func alerted(player: Node3D, from: Vector3) -> void:
	if friend:
		return
	super(player, from)
	if mode in [Mode.ROAM, Mode.TRACK, Mode.CAST] and hunting():
		mode = Mode.CHASE


## Whether `player` can be gone after now: a friend goes after no player at all
## (its own, nor anyone they play with), only what it hunts of the others.
func huntable(player: Node3D) -> bool:
	if friend_seat >= 0 and not (player is MazeEnemy):
		return false
	return super(player)


# --- Meat and friends ---

## Whether it would take meat held out to it now: not while it springs or shakes.
func takes_food() -> bool:
	return not dead and mode != Mode.LUNGE and mode != Mode.SHAKE and not (dog and dog.busy())


## Meat held out to it by `giver` (of seat `seat`): it stops and eats it there.
## False if it will not take it now (where it is run, alone or the host).
func feed(giver: Node3D, seat: int) -> bool:
	if puppet or not takes_food():
		return false
	_start_eating(null, giver, seat)
	_eat_left = EAT_TIME
	return true


func _start_eating(meat: Node3D, giver: Node3D, seat: int) -> void:
	mode = Mode.EAT
	_meat = meat
	_feeder = giver
	_feeder_seat = seat
	_eat_left = 0.0
	quarry = null
	_forget = 0.0
	chasing = false
	if giver:
		_point = giver.global_position + Vector3.UP * 0.3


## Now and then it sniffs for meat lying near it (Loot: the group `meat`), and goes to it.
func _smell_for_meat(delta: float) -> void:
	_smell_in -= delta
	if _smell_in > 0.0 or mode in [Mode.EAT, Mode.LUNGE, Mode.SHAKE, Mode.GUARD]:
		return
	_smell_in = 0.3
	var reach := smell_chasing if hunting() and not friend else smell_meat
	var here := global_position
	var best: Node3D = null
	for node: Node in get_tree().get_nodes_in_group(&"meat"):
		var meat := node as Node3D
		var apart := meat.global_position.distance_to(here)
		if apart >= reach or absf(meat.global_position.y - here.y) > 2.0:
			continue
		# (by the passages, not through a wall)
		if apart > 3.0 and not nav.line_free(here, meat.global_position, 0.1) and nav.distance(maze.cell_at(here), maze.cell_at(meat.global_position)) > 2:
			continue
		reach = apart
		best = meat
	if best:
		_start_eating(best, null, -1)


## Going to meat lying on the ground, or eating it (there, or from a hand).
func _eat_step(delta: float, grounded: bool) -> void:
	var lying := _feeder == null and _feeder_seat < 0
	if lying and not (is_instance_valid(_meat) and _meat.is_in_group(&"meat")):
		# (someone has taken it, or something else has eaten it)
		_meat = null
		mode = Mode.HEEL if friend else Mode.ROAM
		_steer(Vector3.ZERO, 0.0, delta, grounded)
		return
	if _eat_left > 0.0:
		_eat_left -= delta
		if lying:
			_point = _meat.global_position
		_steer(Vector3.ZERO, 0.0, delta, grounded)
		if _eat_left <= 0.0:
			_eaten()
		return
	var to := _meat.global_position - global_position
	var flat := Vector3(to.x, 0.0, to.z)
	_point = _meat.global_position
	if flat.length() < 0.75 + _radius:
		_eat_left = EAT_TIME
		_steer(Vector3.ZERO, 0.0, delta, grounded)
		return
	var wish := flat if nav.line_free(global_position, _meat.global_position, _radius) else _way_to(_meat.global_position)
	_steer(wish.normalized(), track_speed if flat.length() < 5.0 else chase_speed, delta, grounded)


## It has eaten: fed, and (hungry, or fed twice) the friend of whoever gave it.
func _eaten() -> void:
	var seat := _feeder_seat
	var giver := _feeder
	if is_instance_valid(_meat):
		seat = int(_meat.get_meta(&"by", -1))
		giver = _player_of_seat(seat)
		_meat.call(&"eat")
	_meat = null
	_feeder = null
	_feeder_seat = -1
	var was_hungry := hunger >= Ecology.HUNGRY
	_fed += 1
	ate(0.5)
	_point = Vector3.INF
	if is_instance_valid(giver) and (was_hungry or _fed >= 2 or giver == friend):
		befriend(giver, seat)
	elif is_instance_valid(giver):
		# (not yet: but it lets the hand that fed it alone a while)
		_spared[giver] = 8.0
	mode = Mode.HEEL if friend else Mode.ROAM
	_rest_left = 3.0


## The player in seat `seat` (a friend's RemotePlayer by its `slot`, or this
## machine's Player, Loot.attach), or null.
func _player_of_seat(seat: int) -> Node3D:
	if seat < 0:
		return null
	for player: Node3D in _live_players():
		var slot: Variant = player.get(&"slot")
		if (slot != null and int(slot) == seat) or (slot == null and int(player.get_meta(&"seat", 0)) == seat):
			return player
	return null


## The friend of `player` (seat `seat`) from now on.
func befriend(player: Node3D, seat: int) -> void:
	var anew := friend != player
	friend = player
	friend_seat = maxi(seat, 0)
	_alone = 0.0
	_foe = null
	quarry = null
	_forget = 0.0
	chasing = false
	_trail_of = null
	add_to_group(&"dog_friends")
	_set_body()
	if mode != Mode.EAT:
		mode = Mode.HEEL
	if anew:
		befriended.emit(player)


## Feral again: nobody's friend, hunting as it did.
func _go_feral() -> void:
	friend = null
	friend_seat = -1
	_fed = 0
	_alone = 0.0
	_foe = null
	_harried = 0
	mode = Mode.ROAM
	_rest_left = 4.0
	remove_from_group(&"dog_friends")
	_set_body()
	went_feral.emit()


## Whether it is still its friend's: they are in the game, and it has not been
## left far behind too long.
func _keeps_friend(delta: float) -> bool:
	if not is_instance_valid(friend) or not friend.is_inside_tree() or friend.get(&"escaped") == true:
		return false
	if friend.global_position.distance_to(global_position) > far_behind:
		_alone += delta
	else:
		_alone = maxf(_alone - delta * 2.0, 0.0)
	return _alone < loyal_time


## As a friend: at heel, waiting below, warning, or going for what comes at them.
func _friend_step(delta: float, grounded: bool) -> void:
	var here := global_position
	var at := friend.global_position
	_watch_in -= delta
	if _watch_in <= 0.0:
		_watch_in = 0.3
		_foe = _foe_near_friend()
	var wish := Vector3.ZERO
	var speed := 0.0
	if is_instance_valid(_foe):
		var foe_at := _foe.global_position
		mode = Mode.GUARD if _comes_at_friend(_foe) and here.distance_to(at) < guard_range * 2.0 else Mode.WARN
		_point = foe_at + Vector3.UP * 0.8
		# Barking at it, all the while: the warning.
		_bark_in -= delta
		if _bark_in <= 0.0:
			_bark_in = _rng.randf_range(0.5, 0.85)
			_bays += 1
			dog.bark()
		var to := foe_at - here
		var flat := Vector3(to.x, 0.0, to.z)
		if mode == Mode.GUARD and not Stagger.on(_foe):
			var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
			if grounded and _lunge_cool <= 0.0 and flat.length() < lunge_range * size / SCALE + _girth(_foe) * 0.5 and absf(to.y) < 1.5 and forward.dot(flat.normalized()) > 0.6:
				_lunge_at(_foe)
				return
			wish = flat if flat.length() < 8.0 and nav.line_free(here, foe_at, _radius) else _way_to(foe_at)
			speed = chase_speed + 0.6
		else:
			# Between its friend and it, near its friend, facing it down.
			var out := Vector3(foe_at.x - at.x, 0.0, foe_at.z - at.z)
			var stand := at + (out.normalized() if out.length() > 0.1 else Vector3.FORWARD) * minf(2.4, out.length() * 0.5)
			var go := Vector3(stand.x - here.x, 0.0, stand.z - here.z)
			if go.length() > 0.7:
				wish = go if nav.line_free(here, stand, _radius) else _way_to(stand)
				speed = clampf(go.length() * 1.6, 1.0, heel_speed)
	else:
		_harried = 0
		var to := at - here
		var flat := Vector3(to.x, 0.0, to.z)
		var ground := maze.world(maze.cell_at(at)).y
		# (up a wall, on ivy, a vine, a ledge, or out of the maze where it cannot go: it waits below)
		var off_ground := at.y - ground > GROUND or not nav.allowed(maze.cell_at(at))
		mode = Mode.WAIT if off_ground else Mode.HEEL
		var near := 1.6 if off_ground else heel_range
		var them: Vector3 = friend.get(&"velocity") if friend.get(&"velocity") != null else Vector3.ZERO
		var their_speed := Vector2(them.x, them.z).length()
		if flat.length() > near:
			wish = flat if flat.length() < 8.0 and nav.line_free(here, at, _radius) else _way_to(at)
			speed = clampf((flat.length() - near) * 1.4 + their_speed, 1.2, heel_speed)
		_point = at + Vector3.UP * 1.3 if flat.length() < 7.0 and their_speed < 0.6 else Vector3.INF
	var push := _apart(_radius)
	if wish.length() > 0.01:
		wish = wish.normalized()
		if push != Vector3.ZERO:
			wish = (wish + push * 0.6).normalized()
	_steer(wish, speed, delta, grounded)


## What hunts and is near its friend (within `watch_range`) that it can see or
## hear: the nearest to them, or null.
func _foe_near_friend() -> Node3D:
	var at := friend.global_position
	var eye := global_position + Vector3.UP
	var best: Node3D = null
	var least := watch_range
	var all := get_tree().get_nodes_in_group(&"maze_enemies") + get_tree().get_nodes_in_group(&"grievers")
	for node: Node in all:
		var one := node as Node3D
		if one == null or one == self or not one.visible or one.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		if (one is MazeEnemy and (one as MazeEnemy).dead) or (one is MazeDog and (one as MazeDog).friend_seat >= 0):
			continue
		if not _hostile(one):
			continue
		var apart := one.global_position.distance_to(at)
		if apart < least and (eye.distance_to(one.global_position) < hear_range or nav.sees(eye, one.global_position + Vector3.UP, watch_range + 10.0)):
			least = apart
			best = one
	return best


## Whether `one` is after someone: its friend, it, or anyone.
func _hostile(one: Node3D) -> bool:
	return one.get(&"chasing") == true or one.get(&"quarry") == friend or one.get(&"prey") == friend or one.get(&"quarry") == self


## Whether `one` comes at its friend (or at it): after them, or after anyone this near them.
func _comes_at_friend(one: Node3D) -> bool:
	if one.get(&"quarry") == friend or one.get(&"prey") == friend or one.get(&"quarry") == self:
		return true
	return one.get(&"chasing") == true and one.global_position.distance_to(friend.global_position) < guard_range


## Springs at what comes at its friend.
func _lunge_at(foe: Node3D) -> void:
	var them: Vector3 = foe.get(&"velocity") if foe.get(&"velocity") != null else Vector3.ZERO
	_lunge(foe, them)
	_lunge_cool = 1.4


## Its jaws on `foe`: one smaller than it it kills (Ecology); one its size or
## bigger is staggered a moment, and one big enough to eat a dog, harried
## again and again, may turn on it.
func _bite(foe: Node3D) -> void:
	var world := Ecology.current
	if foe is MazeEnemy and world and world.is_prey(foe as MazeEnemy, self) and Ecology.bulk(foe) < Ecology.bulk(self):
		world.kill(foe as MazeEnemy, self)
		_foe = null
		return
	var push := foe.global_position - global_position
	Stagger.hit(foe, push, harry_seconds)
	_harried += 1
	if foe is MazeEnemy and world and Ecology.diet(foe) == Ecology.Diet.MEAT and Ecology.bulk(foe) > Ecology.bulk(self) and _harried >= 2 and _rng.randf() < 0.35:
		var big := foe as MazeEnemy
		big.quarry = self
		big._forget = big.memory
		big._last_seen = global_position


## About how far round `one` is past its middle, metres.
func _girth(one: Node3D) -> float:
	return clampf(Ecology.reach(one) - 0.5, 0.3, 2.5) if Ecology.takes_part(one) else 0.6


# --- What it looks like ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			dog.visible = not far
			dog.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
			if not far:
				dog.settle()
	if _far:
		return
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-10.0 * delta))
	elif mode == Mode.LUNGE:
		var way_now := dog.lunge_way()
		facing_yaw = lerp_angle(facing_yaw, atan2(way_now.x, way_now.z), 1.0 - exp(-14.0 * delta))
	elif heading.length_squared() > 0.04:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))
	elif _point.is_finite():
		var to := _point - global_position
		facing_yaw = lerp_angle(facing_yaw, atan2(to.x, to.z), 1.0 - exp(-4.0 * delta))
	dog.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	dog.rotation = Vector3(0.0, facing_yaw, 0.0)
	dog.grounded = is_on_floor() or puppet
	dog.tracking = mode == Mode.TRACK or mode == Mode.CAST
	dog.stalking = mode == Mode.STALK
	dog.snarling = mode in [Mode.STALK, Mode.LUNGE, Mode.WARN, Mode.GUARD] or (mode == Mode.CHASE and _point.is_finite() and _point.distance_to(global_position) < 9.0)
	dog.look_at_point = _point if mode != Mode.TRACK else Vector3.INF
	# A friend: glad, sitting when its friend has stood a while (or climbed); eating, head down to it.
	var slow := heading.length_squared() < 0.09
	_resting = _resting + delta if slow and mode in [Mode.HEEL, Mode.WAIT] else 0.0
	dog.friendly = friend_seat >= 0
	dog.sitting = _resting > (0.8 if mode == Mode.WAIT else 4.0)
	dog.eating = mode == Mode.EAT and slow and _point.is_finite() and _point.y < global_position.y + 0.5




# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


## What it is doing (low four bits), and whose friend it is (the seat and one, above them: 0 for nobody's).
func net_state() -> int:
	return mode | ((friend_seat + 1) << 4)


## Lunges (low four bits), bays (next three: barks, once a friend) and shakes (top bit, as it changes).
func net_flag() -> int:
	return (_lunges & 0x0f) | ((_bays & 0x07) << 4) | ((_shakes & 1) << 7)


func net_point() -> Vector3:
	return _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = (state & 0x0f) as Mode
	var was_friend := friend_seat
	friend_seat = (state >> 4) - 1
	if friend_seat != was_friend:
		_set_body()
	chasing = friend_seat < 0 and mode in [Mode.BAY, Mode.CHASE, Mode.STALK, Mode.LUNGE]
	_point = point
	var lunges := flag & 0x0f
	var bays := (flag >> 4) & 0x07
	var shakes := (flag >> 7) & 1
	if not _heard_flagged:
		_heard_flagged = true
	elif dog:
		if lunges != (_lunges & 0x0f) and point.is_finite():
			dog.lunge(point)
		if bays != (_bays & 0x07):
			if friend_seat >= 0:
				dog.bark()
			else:
				dog.howl(0.8)
		if shakes != (_shakes & 1):
			dog.shake()
	_lunges = lunges
	_bays = bays
	_shakes = shakes


func _put(at: Vector3, facing: float) -> void:
	# (where it is run, it is only put somewhere when it is brought back from the
	# dead at its den, MazeEnemy.revive: a friend killed is gone, and it is feral)
	if friend and not puppet:
		_go_feral()
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if dog:
		dog.global_position = at
		dog.settle()


func _puppet_changed() -> void:
	_set_body()
	collision_mask = 1 if puppet else 1 | 4


## Its body's layer: solid to the players (MazeEnemy), but a friend's is not in
## its friend's way (nor anyone's: it goes through them at heel in a narrow hall).
func _set_body() -> void:
	if dead:
		return
	collision_layer = 0 if friend_seat >= 0 else (PUPPET_LAYER if puppet else 4)

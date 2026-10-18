class_name MazeMushroomZombie
extends MazeEnemy
## A mushroom zombie (creatures/mushroom_zombie/, `MushroomZombie`): one of the
## boys who came before, taken over by a fungus, fruiting bodies bursting out of
## his head, shoulders and back, walked about in fits like a puppet. This is
## only its thinking; how it looks and moves is the component.
##
## - IT IS BLIND. It sees nothing (`sight_range` 0), and hunts by sound alone.
##   Walking is heard only close (`hear_walk`), going crouched not at all; a run
##   is heard `hear_run` off, a sprint `hear_sprint`, landing hard from a jump or
##   a fall `hear_land` (less through a wall: `muffled`). Walking into one is
##   felt (`touch`), however softly.
## - ITS TELL is a clicking, a dry crackle heard well before it is seen (the
##   sound carries some 30 m); louder when it has heard something.
## - IT HEARS, AND LISTENS. Hearing something it stops dead, its head snapping
##   round to the sound (LISTEN: the warning, about a second), its clicking
##   loud; the others of its horde within `alert_range` hear the clicking and
##   come to it. Then it lurches at where the sound was, faster than a walk and
##   slower than a run (`hunt_speed`), on after it for as long as it goes on
##   hearing it (`memory` past the last sound). Go quiet (stop, walk, crouch)
##   and it goes on to where it last heard you, stands there listening
##   (`search_time`), and wanders off.
## - IT LUNGES. Within `lunge_range` of what it hears, it throws itself at it,
##   arms out; its hands closing on someone catches them (`caught(player)`).
##   Step aside as it lunges (it lunges at the sound, not at you).
## - THE SPORES CALL IT. A puffball puffing near (MazeMushrooms) is heard
##   (`heard`), and it comes to see.
## - IT TAKES WHAT IT HEARS (Ecology: creatures up to `prey_size` big that it
##   hears run, or blunders into): the lunge kills them; and a while later
##   (`rise_delay`) one of its horde that was lying under the ground (a sleeper,
##   `sleeper`) rises up out of the ground where the creature fell, a new one.
##   In Ecology it is size 2 and eats nothing (Diet.NONE): nothing eats it, and
##   nothing runs from it (it is blind, and quiet but for its clicking).
##
## Online, the host thinks for it and the others' copies are puppets: each
## listen and lunge, rising, and what it listens to are sent with its state
## (`net_flag`, `net_point`) and played out here too. Catching is the host's alone.
##
## Spawn as MazeEnemies.add does; `horde_of(count, sleepers)` makes a horde.

enum Mode { DORMANT, RISING, WANDER, LISTEN, HUNT, SEARCH, GRAB }

## How much bigger than the boy it is drawn (and goes).
const SIZE := 1.06

@export var wander_speed := 0.6
@export var hunt_speed := 3.2
## How far it hears each thing, metres: a walk, a run (faster than `loud_pace`), a
## sprint (faster than `sprint_pace`), a hard landing; and how much less through walls.
@export var hear_walk := 1.6
@export var hear_run := 12.0
@export var hear_sprint := 17.0
@export var hear_land := 13.0
@export var loud_pace := 2.6
@export var sprint_pace := 5.0
@export var muffled := 0.55
## Walking into it is felt this near (bodies and all), however softly.
@export var touch := 0.95
## How near what it hears must be for it to lunge.
@export var lunge_range := 1.55
## How long it stands listening where it last heard something.
@export var search_time := 5.0
## How big a creature it takes (Ecology's sizes), how far it hears one run, and
## how long after a kill a sleeper of its horde rises there.
@export var prey_size := 2
@export var hear_creatures := 10.0
@export var rise_delay := 30.0
@export var turn_rate := 4.0
@export var gravity := 24.0
## Further than this from every player it is not posed.
@export var pose_range := 70.0

var mode := Mode.WANDER
## Its horde (they hear each other's clicking), and whether it lies under the
## ground until the horde has fed (it rises then, where the kill was).
var horde_id := 0
var sleeper := false
var facing_yaw := 0.0
var figure: MushroomZombie
## Where it last heard something (INF: nothing).
var heard_at := Vector3.INF

var _mode_time := 0.0
var _listens := 0
var _lunges := 0
var _heard_acts := false
var _radius := 0.3
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
## Each player: whether they are falling fast, and when they last came down hard.
var _falling := {}
var _landed := {}
var _clock := 0.0
## A sleeper's rising: where, and how long until.
var _rise_at := Vector3.INF
var _rise_in := -1.0
var _lunge_at: Node3D


func _init() -> void:
	sight_range = 0.0
	hear_range = 0.0
	memory = 1.2
	alert_range = 12.0
	pack = &"mushroom_zombies"
	look_every = 0.2
	spare_time = 4.0


## A horde of `count`, the last `sleepers` of them lying under the ground until it feeds.
static func horde_of(count: int, sleepers := 1, id := -1) -> Array:
	var made: Array = []
	var horde := id if id >= 0 else randi() % 100000
	for k in count:
		var one := MazeMushroomZombie.new()
		one.horde_id = horde
		one.sleeper = k >= count - sleepers
		made.append(one)
	return made


func _ready() -> void:
	add_to_group(&"pursuers")
	floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	_radius = 0.28 * SIZE
	shape.radius = _radius
	shape.height = 1.3 * SIZE
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	facing_yaw = rotation.y
	rotation.y = 0.0
	figure = MushroomZombie.new()
	figure.scale = Vector3.ONE * SIZE
	add_child(figure)
	figure.top_level = true
	figure.put(global_position, facing_yaw)
	_prev_pos = global_position
	_curr_pos = global_position
	if sleeper:
		_set_mode(Mode.DORMANT)
	else:
		_set_mode(Mode.WANDER)


func _set_mode(next: Mode) -> void:
	mode = next
	_mode_time = 0.0
	var solid := next != Mode.DORMANT
	collision_layer = (PUPPET_LAYER if puppet else 4) if solid else 0
	collision_mask = (1 if puppet else 1 | 4) if solid else 0
	if figure:
		figure.visible = next != Mode.DORMANT
		if next == Mode.DORMANT:
			figure.risen = 0.0
	chasing = next in [Mode.LISTEN, Mode.HUNT, Mode.GRAB]


func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze == null:
		return
	_clock += delta
	_mode_time += delta
	for player: Variant in _spared.keys():
		if not is_instance_valid(player):
			_spared.erase(player)
			continue
		_spared[player] -= delta
		if _spared[player] <= 0.0:
			_spared.erase(player)
	_forget -= delta
	if quarry and not huntable(quarry):
		quarry = null
	_watch_falls()
	var wish := Vector3.ZERO
	var speed := 0.0
	match mode:
		Mode.DORMANT:
			if _rise_in > 0.0:
				_rise_in -= delta
				if _rise_in <= 0.0:
					_rise_in = -1.0
					global_position = _rise_at
					_put(_rise_at, randf() * TAU)
					_set_mode(Mode.RISING)
					figure.rise()
			_prev_pos = global_position
			_curr_pos = global_position
			return
		Mode.RISING:
			if figure.risen >= 1.0:
				_set_mode(Mode.WANDER)
		Mode.WANDER:
			_listen(delta)
			if mode == Mode.WANDER:
				wish = _route()
				speed = wander_speed
		Mode.LISTEN:
			_listen(delta)
			if _mode_time > MushroomZombie.act_length(MushroomZombieRig.Act.LISTEN):
				_set_mode(Mode.HUNT)
		Mode.HUNT:
			_listen(delta)
			if _try_lunge():
				pass
			elif not hunting() and not _last_seen.is_finite():
				_set_mode(Mode.SEARCH)
			else:
				wish = _route()
				speed = hunt_speed
		Mode.SEARCH:
			_listen(delta)
			if mode == Mode.SEARCH and _mode_time > search_time:
				heard_at = Vector3.INF
				_set_mode(Mode.WANDER)
		Mode.GRAB:
			_grab()
			if not figure.busy():
				_lunge_at = null
				_set_mode(Mode.SEARCH)
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, (9.0 if speed > wander_speed * 2.0 else 4.0) * delta)
	if mode == Mode.GRAB and figure.stage() == MushroomZombieRig.Stage.REACH and _lunge_at:
		var to := _lunge_at.global_position - global_position
		current = Vector3(to.x, 0.0, to.z).normalized() * 2.4
	velocity.x = current.x
	velocity.z = current.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _route() -> Vector3:
	var to := way(_radius)
	var wish := to.normalized() if to.length() > 0.05 else Vector3.ZERO
	var push := _apart(_radius)
	if push != Vector3.ZERO:
		wish = (wish + push * 0.8).normalized()
	return wish


# --- Hearing ---

## Notes, every physics step, who is falling fast and who has just come down
## hard (a landing is too quick to be caught a few times a second).
func _watch_falls() -> void:
	for player: Node3D in players():
		if not is_instance_valid(player):
			continue
		var moving: Variant = player.get(&"velocity")
		var down := (moving as Vector3).y if moving is Vector3 else 0.0
		if down < -5.5:
			_falling[player] = true
		elif _falling.get(player, false) and down > -1.0:
			_falling[player] = false
			_landed[player] = _clock


## How far off `player` can be heard now, metres (0: not at all).
func loudness(player: Node3D) -> float:
	var moving: Variant = player.get(&"velocity")
	var pace := Vector2((moving as Vector3).x, (moving as Vector3).z).length() if moving is Vector3 else 0.0
	var far := hear_land if _clock - float(_landed.get(player, -10.0)) < 0.4 else 0.0
	if player.get(&"is_ducking") == true:
		return far
	if pace > sprint_pace:
		return maxf(far, hear_sprint)
	if pace > loud_pace:
		return maxf(far, hear_run)
	if pace > 0.4:
		return maxf(far, hear_walk)
	return far


## Listens, a few times a second, for anyone making a noise, anything running, or anyone touching it.
func _listen(delta: float) -> void:
	_look_in -= delta
	if _look_in > 0.0:
		return
	_look_in = look_every
	var ear := global_position + Vector3.UP * 1.1
	var best: Node3D = null
	var nearest := INF
	for player: Node3D in players():
		if not huntable(player):
			continue
		var apart := global_position.distance_to(player.global_position)
		var far := loudness(player)
		if far > 0.0 and apart > 3.0 and not nav.sees(ear, player.global_position + Vector3.UP, far):
			far *= muffled
		if (apart < far or apart < touch * SIZE) and apart < nearest:
			nearest = apart
			best = player
	if best:
		_hear(best, best.global_position)
		return
	# What else runs about (Ecology): it hears that too, and takes it.
	if Ecology.current and not (quarry and hunting() and not (quarry is MazeEnemy)):
		for one in MazePlants.creatures_near(get_tree(), global_position, hear_creatures, prey_size):
			var creature := one as MazeEnemy
			if Ecology.diet(creature) == Ecology.Diet.NONE or creature is MazeMushroomZombie:
				continue
			var pace := Vector2(creature.velocity.x, creature.velocity.z).length()
			var apart := creature.global_position.distance_to(global_position)
			if pace > loud_pace or apart < touch * SIZE + Ecology.reach(creature):
				_hear(creature, creature.global_position)
				return


## Heard `who` at `at`: it stops to listen (if it was not already after
## something), and its horde near hears its clicking.
func _hear(who: Node3D, at: Vector3) -> void:
	var fresh := not hunting()
	if who != quarry or _forget <= 0.0:
		spotted.emit(who)
	quarry = who
	_forget = memory
	_last_seen = at
	heard_at = at
	if mode in [Mode.WANDER, Mode.SEARCH] and fresh:
		_listens += 1
		figure.aim = at + Vector3.UP
		figure.listen()
		_set_mode(Mode.LISTEN)
		for other: Node in get_tree().get_nodes_in_group(pack):
			if other != self and other is MazeMushroomZombie and not other.puppet and (other as Node3D).global_position.distance_to(global_position) < alert_range:
				(other as MazeMushroomZombie).heard(global_position, 0.5)


## Something was heard at `at` (a puffball puffing near, one of its horde
## clicking): it listens, and comes to see.
func heard(at: Vector3, _loud := 1.0) -> void:
	if puppet or mode in [Mode.DORMANT, Mode.RISING, Mode.GRAB] or hunting():
		return
	_last_seen = at
	heard_at = at
	if mode != Mode.LISTEN:
		_listens += 1
		figure.aim = at + Vector3.UP
		figure.listen()
		_set_mode(Mode.LISTEN)


## Told by its horde: it hears the clicking, from there.
func alerted(_player: Node3D, from: Vector3) -> void:
	heard(from, 0.5)


## Near enough to what it hears, it lunges at it.
func _try_lunge() -> bool:
	if not hunting() or quarry == null:
		return false
	var to := quarry.global_position - global_position
	if Vector2(to.x, to.z).length() > lunge_range * SIZE or absf(to.y) > 1.5:
		return false
	_lunges += 1
	_lunge_at = quarry
	facing_yaw = atan2(to.x, to.z)
	figure.aim = quarry.global_position + Vector3.UP * 0.8
	figure.lunge()
	_set_mode(Mode.GRAB)
	return true


## While its hands close: whoever is in them is caught; a creature is killed.
func _grab() -> void:
	if figure.stage() != MushroomZombieRig.Stage.CLOSE or figure.held:
		return
	for player: Node3D in players():
		if huntable(player) and figure.grab_hits(player.global_position + Vector3.UP * 0.7, 0.3):
			figure.held = true
			_catch(player)
			return
	if _lunge_at is MazeEnemy and is_instance_valid(_lunge_at) and not (_lunge_at as MazeEnemy).dead and Ecology.current:
		var prey := _lunge_at as MazeEnemy
		if figure.grab_hits(prey.global_position + Vector3.UP * 0.5, Ecology.reach(prey) * 0.6):
			figure.held = true
			var at := prey.global_position
			Ecology.current.kill(prey, self)
			_wake_sleeper(at)


## One of its horde that lies under the ground rises where the kill was, in time.
func _wake_sleeper(at: Vector3) -> void:
	for other: Node in get_tree().get_nodes_in_group(pack):
		var one := other as MazeMushroomZombie
		if one and one.horde_id == horde_id and one.mode == Mode.DORMANT and one._rise_in < 0.0 and not one.puppet:
			one.rise_later(at, rise_delay)
			return


## Rises up out of the ground at `at` after `seconds` (a sleeper; anyone else
## is moved there under the ground first).
func rise_later(at: Vector3, seconds: float) -> void:
	if mode != Mode.DORMANT:
		_set_mode(Mode.DORMANT)
	_rise_at = at
	_rise_in = maxf(seconds, 0.01)


# --- Showing it ---

func _process(delta: float) -> void:
	var at := _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			figure.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
	figure.global_position = at
	if _far or mode == Mode.DORMANT:
		return
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-10.0 * delta))
		if _heard_extra.is_finite():
			figure.aim = _heard_extra
	else:
		var heading := Vector3(velocity.x, 0.0, velocity.z)
		if mode == Mode.LISTEN and heard_at.is_finite():
			heading = heard_at - global_position
			heading.y = 0.0
			facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-1.5 * delta))
		elif heading.length_squared() > 0.04 and mode != Mode.GRAB:
			facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))
	figure.rotation.y = facing_yaw
	figure.velocity = velocity
	figure.grounded = is_on_floor() or puppet
	figure.clicking = {Mode.WANDER: 0.25, Mode.LISTEN: 1.0, Mode.HUNT: 0.85, Mode.SEARCH: 0.55, Mode.GRAB: 1.0, Mode.RISING: 0.6}.get(mode, 0.3)
	figure.frenzy = 1.0 if mode in [Mode.HUNT, Mode.GRAB] else 0.0


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Its listens (low four bits), its lunges (the next three), and whether it has hold of someone (the top bit).
func net_flag() -> int:
	return (_listens & 0x0f) | ((_lunges & 0x07) << 4) | (0x80 if figure and figure.held else 0)


func net_point() -> Vector3:
	return heard_at + Vector3.UP if heard_at.is_finite() else Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	var listens := flag & 0x0f
	var lunges := (flag >> 4) & 0x07
	if not _heard_acts:
		_heard_acts = true
	else:
		if listens != _listens & 0x0f:
			if point.is_finite():
				figure.aim = point
			figure.listen()
		if lunges != _lunges & 0x07:
			if point.is_finite():
				figure.aim = point
			figure.lunge()
	_listens = listens
	_lunges = lunges
	if flag & 0x80 and not figure.held and figure.doing() == MushroomZombieRig.Act.LUNGE:
		figure.held = true


func _heard_changed(was: int, now: int, first: bool) -> void:
	var next := now as Mode
	_set_mode(next)
	if next == Mode.RISING and not first:
		figure.rise()
	elif was == Mode.DORMANT and next != Mode.DORMANT:
		figure.risen = 1.0


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if figure:
		figure.put(at, facing)


func _puppet_changed() -> void:
	if is_inside_tree():
		_set_mode(mode)

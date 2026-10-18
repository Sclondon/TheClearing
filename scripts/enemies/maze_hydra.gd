class_name MazeHydra
extends MazeEnemy
## A hydra (creatures/hydra/: the Lernaean hydra, a heavy reptile's body with
## seven serpent necks) set to bar a stretch of passage. This is only its
## thinking; how it looks and moves is the `Hydra` component, which this drives.
##
## - IT LAIRS. Put somewhere (best in a hall), it lies in a wide pool of black
##   marsh water of its own (`FishPool`), sunk to its flanks, its necks lying
##   out over the water about it, asleep. Anyone who comes within `wake_range`,
##   or runs within `loud_range` where it could see them, wakes it; so does
##   anything else that tells it someone is about (`notice`).
## - IT WATCHES. Awake, its necks rise and weave over the hall, each head
##   looking its own way, and those near anyone turn to watch them.
## - IT STRIKES, MANY HEADS AT ONCE. Anyone within reach of a head (about 8 m
##   from the necks' roots; it does not reach round corners) is struck at:
##   the head coils back with its mouth open and hisses (Hydra.wind_up, the
##   warning), and darts. Some of its heads strike where you are when they
##   dart, some where you will be if you keep on as you are going. Up to
##   `most_at_once` heads strike at a time, each a little after the last
##   (`strike_gap`), from as many sides as it can manage. A hit catches. Walk
##   past and you are caught; run straight past and a clever head may take
##   you; change pace or line as one darts (or duck under it, or get by while
##   its heads are spent) and you get through. Behind it, by the tail, is
##   furthest from the necks.
## - IT HARDLY MOVES. It turns slowly to face whoever is about, and when
##   none of its heads can reach them it creeps after them (`creep_speed`,
##   slower than a walk), never further than `leash` from its pool. When
##   nobody has come near for `rest_after` seconds it goes back to its pool
##   and lies down again.
## - ITS HEADS CAN BE CUT (`cut`, for the game to call when someone uses the
##   act button near a head): the head falls, and two grow back out of the
##   stump a few seconds later (up to nine).
##
## Online, the host thinks for it and the others' copies are puppets: each
## strike (which head, and where) and each cut is sent with its state and
## played out on the copies too. Catching is the host's alone.
##
## Spawn (as MazeEnemies.add does): `MazeHydra.new()`, set `maze`, place it
## and turn it (rotation.y, 0 faces +Z), add it to the tree. Where it is put is
## its pool.

enum Mode { RESTING, WAKING, AWAKE }

## How many heads it has to begin with.
@export_range(1, 9) var heads := 7
## Down in its pool: how near anyone wakes it, and how near someone running (faster than `loud_speed`) does.
@export var wake_range := 13.0
@export var loud_range := 24.0
@export var loud_speed := 3.0
## Up to how many heads strike at once, and the seconds between one beginning and the next.
@export var most_at_once := 3
@export var strike_gap := Vector2(0.22, 0.55)
## How much of what lies ahead of someone running its clever heads aim at (0: none), and which are clever (every second).
@export var lead := 0.75
## How slowly it creeps and turns, and how far from its pool it will go.
@export var creep_speed := 0.7
@export var turn_rate := 0.45
@export var leash := 4.0
## Seconds with nobody near before it lies down again.
@export var rest_after := 14.0
## How far its pool reaches, and how deep it lies in it.
@export var pool_radius := 6.8
@export var wade := 0.7
## How near a cut must be to a head to take it off.
@export var cut_reach := 1.8
@export var gravity := 24.0

var mode := Mode.RESTING
## Which way it faces, radians about Y (0 faces +Z).
var facing_yaw := 0.0
## The creature it drives, and the water it lies in.
var figure: Hydra
var pool: FishPool

var _home := Vector3.ZERO
var _home_yaw := 0.0
var _listen_in := 0.0
var _strike_in := 0.0
var _waking := 0.0
var _alone := 0.0
## Who each head is striking at (by slot).
var _after: Array = []
var _strikes := 0
var _last_slot := 0
var _last_aim := Vector3.INF
var _cuts := 0
var _last_cut := 0
var _heard_acts := false
var _stir_in := 0.0


func _init() -> void:
	sight_range = 30.0
	hear_range = 10.0
	memory = 8.0
	alert_range = 0.0
	pack = &"hydras"


func _ready() -> void:
	add_to_group(&"pursuers")
	floor_snap_length = 0.3
	# (its body: a long lump in the middle of the hall, which nobody can walk through)
	var shape := CapsuleShape3D.new()
	shape.radius = 1.3
	shape.height = 7.0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.rotation.x = PI * 0.5
	collider.position = Vector3(0.0, shape.radius + 0.02, -0.6)
	add_child(collider)
	collision_layer = 4
	collision_mask = 1

	_home = _middle_of_hall(global_position)
	global_position = _home
	_home_yaw = rotation.y
	facing_yaw = _home_yaw
	pool = FishPool.new()
	pool.radius = pool_radius
	pool.shape_seed = int(absf(_home.x * 7.0 + _home.z * 13.0)) % 1000
	pool.visibility_range_end = 140.0
	add_child(pool)
	pool.top_level = true
	pool.global_position = _home - Vector3.UP * 0.05

	figure = Hydra.new()
	figure.heads = heads
	figure.wade = wade
	figure.low_poly = Settings.low_poly
	figure.seed_value = _rng.randi() | 1
	add_child(figure)
	figure.struck.connect(_on_struck)
	for slot in Hydra.MAX_HEADS:
		_after.append(null)
	reset()


## Where to lie, put in the middle of a cell: in the middle of the hall. A hall
## two cells wide (as the first ring's are, its walls thick) is walled on one
## side of each of its cells, so it is moved half a cell to the other, out into
## the middle of it. Anywhere else it is left where it is put.
func _middle_of_hall(at: Vector3) -> Vector3:
	if maze == null:
		return at
	var cell := maze.cell_at(at)
	var middle := maze.world(cell)
	if Vector2(at.x - middle.x, at.z - middle.z).length() > 1.0:
		return at
	var shift := Vector3.ZERO
	for s: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		var this_way := maze.blocked(cell, s)
		var that_way := maze.blocked(cell, -s)
		if this_way and not that_way and maze.blocked(cell - s, -s):
			shift -= Vector3(s.x, 0.0, s.y) * Maze.CELL * 0.5
		elif that_way and not this_way and maze.blocked(cell + s, s):
			shift += Vector3(s.x, 0.0, s.y) * Maze.CELL * 0.5
	return at + shift


## Back in its pool, asleep.
func reset() -> void:
	global_position = _home
	velocity = Vector3.ZERO
	quarry = null
	_forget = 0.0
	_last_seen = Vector3.INF
	chasing = false
	mode = Mode.RESTING
	facing_yaw = _home_yaw
	rotation.y = facing_yaw
	figure.awake = false
	figure.watch = []
	figure.settle()


func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		rotation.y = lerp_angle(rotation.y, _heard_yaw, 1.0 - exp(-6.0 * delta))
		facing_yaw = rotation.y
		_watch_players()
		return
	if maze == null:
		return
	var wish := Vector3.ZERO
	match mode:
		Mode.RESTING:
			_listen(delta)
		Mode.WAKING:
			_sense(delta)
			_waking -= delta
			if _waking <= 0.0:
				mode = Mode.AWAKE
				_alone = 0.0
		Mode.AWAKE:
			_sense(delta)
			wish = _awake(delta)
	chasing = mode == Mode.AWAKE and hunting()
	figure.awake = mode != Mode.RESTING
	_watch_players()
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * creep_speed, 2.0 * delta)
	velocity.x = current.x
	velocity.z = current.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()
	rotation.y = facing_yaw
	_stir(delta)


## Asleep in its pool: listens, a few times a second, for anyone near or running, and wakes if it hears them.
func _listen(delta: float) -> void:
	for player: Variant in _spared.keys():
		if not is_instance_valid(player):
			_spared.erase(player)
			continue
		_spared[player] -= delta
		if _spared[player] <= 0.0:
			_spared.erase(player)
	_listen_in -= delta
	if _listen_in > 0.0:
		return
	_listen_in = look_every
	for player: Node3D in players():
		if not huntable(player):
			continue
		var far := player.global_position.distance_to(global_position)
		var moving: Variant = player.get(&"velocity")
		var pace := Vector2((moving as Vector3).x, (moving as Vector3).z).length() if moving is Vector3 else 0.0
		var loud := pace > loud_speed and far < loud_range and nav.sees(global_position + Vector3.UP * 2.0, player.global_position + Vector3.UP, loud_range)
		if far < wake_range or loud:
			notice(player)
			break
	if quarry:
		_wake()


func _wake() -> void:
	if mode != Mode.RESTING:
		return
	mode = Mode.WAKING
	_waking = 1.4
	_strike_in = 0.4


## Told (by a noise, a call) that someone is about: it wakes.
func notice(player: Node3D) -> void:
	super(player)
	if quarry and mode == Mode.RESTING:
		_wake()


## Awake: turns to face them, creeps after them if no head can reach, strikes at whoever is in reach. Says which way to creep.
func _awake(delta: float) -> Vector3:
	var near_any := false
	for player: Node3D in players():
		if huntable(player) and player.global_position.distance_to(global_position) < 30.0:
			near_any = true
			break
	_alone = 0.0 if near_any else _alone + delta
	if _alone > rest_after:
		mode = Mode.RESTING
		figure.awake = false
		return Vector3.ZERO
	_bite_check()
	_strike_in -= delta
	if _strike_in <= 0.0:
		if _try_strike():
			_strike_in = _rng.randf_range(strike_gap.x, strike_gap.y)
		else:
			_strike_in = 0.1
	_retarget()
	# Turning to face whoever it is after, and creeping after them while no head can reach.
	var wish := Vector3.ZERO
	var after := quarry if quarry and hunting() else null
	if after == null and _distance_home() > 0.5:
		var back := _home - global_position
		back.y = 0.0
		wish = back.normalized() * 0.6
		_turn_to(atan2(back.x, back.z), delta)
	elif after:
		var to := after.global_position - global_position
		to.y = 0.0
		_turn_to(atan2(to.x, to.z), delta)
		var reachable := false
		for slot in figure.head_slots():
			if figure.can_reach(slot, after.global_position + Vector3.UP):
				reachable = true
				break
		if not reachable and to.length() < 26.0:
			var step := way(1.4)
			var going := step.normalized() if step.length() > 0.05 else Vector3.ZERO
			var next := global_position + going * 0.5
			if Vector2(next.x - _home.x, next.z - _home.z).length() < leash:
				wish = going
	return wish


func _turn_to(yaw: float, delta: float) -> void:
	facing_yaw = rotate_toward(facing_yaw, yaw, turn_rate * delta)


func _distance_home() -> float:
	return Vector2(global_position.x - _home.x, global_position.z - _home.z).length()


# Where to aim at someone: their chest (lower when they duck), and for a clever head where they will be.
func _aim_at(player: Node3D, slot: int, ahead: float) -> Vector3:
	var at := player.global_position + Vector3.UP * (0.55 if player.get(&"is_ducking") == true else 1.0)
	if slot % 2 == 1 and lead > 0.0:
		var moving: Variant = player.get(&"velocity")
		if moving is Vector3:
			var flat := Vector3((moving as Vector3).x, 0.0, (moving as Vector3).z)
			at += flat * ahead * lead
	return at


# One more head strikes, if one can: at whoever has fewest at them already, the head that comes from furthest round from those.
func _try_strike() -> bool:
	var striking := 0
	for slot in figure.head_slots():
		if figure.stage(slot) in [Hydra.Stage.WIND, Hydra.Stage.DART, Hydra.Stage.HOLD]:
			striking += 1
	if striking >= most_at_once:
		return false
	var ready := figure.ready_heads()
	if ready.is_empty():
		return false
	var best_player: Node3D = null
	var best_slot := -1
	var best_score := -INF
	for player: Node3D in players():
		if not huntable(player) or player.get(&"is_limp") == true:
			continue
		var chest := player.global_position + Vector3.UP
		if chest.distance_to(global_position) > figure.reach() + 6.0:
			continue
		var on_them := 0
		var from: Array[Vector3] = []
		for slot in figure.head_slots():
			if _after[slot] == player and figure.stage(slot) in [Hydra.Stage.WIND, Hydra.Stage.DART, Hydra.Stage.HOLD]:
				on_them += 1
				from.append((chest - figure.root_of(slot)).normalized())
		for slot: int in ready:
			var aim := _aim_at(player, slot, figure.wind_up + figure.dart_time)
			if not figure.can_reach(slot, aim) or not figure.can_reach(slot, chest):
				continue
			var root := figure.root_of(slot)
			if not nav.sees(root, chest, figure.reach() + 1.0):
				continue
			var way_in := (chest - root).normalized()
			var apart := 1.0
			for other in from:
				apart = minf(apart, 1.0 - way_in.dot(other))
			var score := -on_them * 3.0 + apart * 2.0 + _rng.randf_range(0.0, 0.6)
			if score > best_score:
				best_score = score
				best_slot = slot
				best_player = player
	if best_slot < 0:
		return false
	if not hunting() or quarry != best_player:
		notice(best_player)
	_after[best_slot] = best_player
	return figure.strike(best_slot, _aim_at(best_player, best_slot, figure.wind_up + figure.dart_time))


# Winding-up heads follow whoever they are after (until their aim is fixed).
func _retarget() -> void:
	for slot in figure.head_slots():
		if figure.stage(slot) != Hydra.Stage.WIND:
			continue
		var player: Variant = _after[slot]
		if player is Node3D and is_instance_valid(player) and huntable(player):
			figure.retarget(slot, _aim_at(player, slot, figure.strikes_in(slot) + figure.dart_time))


# A darting or holding head that finds anyone catches them.
func _bite_check() -> void:
	for slot in figure.head_slots():
		if figure.stage(slot) not in [Hydra.Stage.DART, Hydra.Stage.HOLD]:
			continue
		for player: Node3D in players():
			if not huntable(player):
				continue
			var feet := player.global_position + Vector3.UP * 0.25
			var top := player.global_position + Vector3.UP * (1.0 if player.get(&"is_ducking") == true else 1.55)
			if figure.bites(slot, feet, top, 0.32):
				_catch(player)
				break


func _on_struck(slot: int, at: Vector3) -> void:
	if puppet:
		return
	_strikes += 1
	_last_slot = slot
	_last_aim = at


## Someone has used the act button (cut) with their hands at `at`: if a head is
## within `cut_reach`, it is cut off (two grow back). True if one was.
func cut(at: Vector3) -> bool:
	if puppet:
		return false
	var slot := figure.head_near(at, cut_reach)
	if slot < 0 or not figure.sever(slot):
		return false
	_cuts += 1
	_last_cut = slot
	if mode == Mode.RESTING:
		var someone := nearest_player(at)
		if someone:
			notice(someone)
	return true


# Its heads watch whoever is near (the local players on a puppet too).
func _watch_players() -> void:
	var points: Array = []
	for player: Node3D in players():
		if is_instance_valid(player) and player.is_inside_tree() and player.global_position.distance_to(global_position) < 32.0:
			points.append(player.global_position + Vector3.UP * 1.1)
	figure.watch = points


# Rings on its pool, as it creeps and as heads come down into the water.
func _stir(delta: float) -> void:
	_stir_in -= delta
	if _stir_in > 0.0 or pool == null:
		return
	_stir_in = 0.6
	if Vector2(velocity.x, velocity.z).length() > 0.15:
		pool.stir(global_position, 0.6)
		return
	for slot in figure.head_slots():
		if figure.stage(slot) == Hydra.Stage.HOLD:
			var mouth := figure.mouth_of(slot)
			if Vector2(mouth.x - _home.x, mouth.z - _home.z).length() < pool_radius and mouth.y - _home.y < 0.8:
				pool.stir(mouth, 1.0)
				return
	if mode == Mode.RESTING and _rng.randf() < 0.15:
		pool.stir(global_position + global_basis.z * 2.0, 0.3)


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


## Its mode (the low two bits), its cuts (the next two) and which head was cut last (the top four).
func net_state() -> int:
	return int(mode) | ((_cuts & 0x03) << 2) | ((_last_cut & 0x0f) << 4)


## Its strikes (the low four bits) and which head struck last (the top four).
func net_flag() -> int:
	return (_strikes & 0x0f) | ((_last_slot & 0x0f) << 4)


func net_point() -> Vector3:
	return _last_aim


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state & 0x03, flag, point)
	var strikes := flag & 0x0f
	var slot := (flag >> 4) & 0x0f
	var cuts := (state >> 2) & 0x03
	var cut_slot := (state >> 4) & 0x0f
	if _heard_acts:
		if strikes != _strikes and point.is_finite() and slot < Hydra.MAX_HEADS:
			if not figure.strike(slot, point):
				# (that head is still busy here: another strikes in its place)
				var ready := figure.ready_heads()
				if not ready.is_empty():
					figure.strike(ready[0], point)
		if cuts != _cuts and cut_slot < Hydra.MAX_HEADS:
			figure.sever(cut_slot)
	_heard_acts = true
	_strikes = strikes
	_cuts = cuts


func _heard_changed(_was: int, now: int, first: bool) -> void:
	mode = (now & 0x03) as Mode
	figure.awake = mode != Mode.RESTING
	if first:
		figure.settle()


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	rotation.y = facing
	velocity = Vector3.ZERO
	if figure:
		figure.settle()


func _puppet_changed() -> void:
	collision_mask = 1

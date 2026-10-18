class_name MazeTribesman
extends MazeEnemy
## One of a hunting party of the masked tribe: the maze's own lost boys, gone
## wild long ago (after Lord of the Flies), masked, with spears. He is drawn and
## moved by Tribesman (creatures/masked_tribe/); this is what he thinks.
##
## THE PARTY. Three to five of them (`party_of`) camp round their totem in a dead
## end (`den`; the first of them, the `chief`, plants it) and patrol out from it
## in single file at a walk, the chief leading and each of the rest keeping a
## couple of paces behind the one before him, and back to it now and then.
## THE CALL. When one sees or hears someone (MazeEnemy's senses), he plants
## himself and drums the butt of his spear on the ground, chanting: the whole
## party within `alert_range` takes up the hunt.
## THE HUNT. They run at a run (`chase_speed`, as fast as a player's run and no
## faster: a sprint gets away), and spread out to cut you off: the chief comes
## straight on, the others make for where you are going, further ahead the
## further down the file they were (`flank`).
## THE THROW. One with his spear and you in a straight line down the halls,
## between `throw_range` from him, stops, turns side on and draws back with a
## call (`wind_time`, the warning); then throws where you will be (most of the
## way), and the spear flies, falling as it goes. It catches whoever it passes
## through; ducked under it, it goes over. Out of his line by then (a corner, a
## side passage) and he holds a moment and gives it up; a wall in the way and it
## sticks in the wall. Only one of a party throws at a time. Thrown, he is
## empty-handed until he has gone and taken it up again (`pick_up`); out of his
## reach (high in a wall), he pulls another from the bundle on his back after a
## while.
## THE JAB. Within `jab_range` in front of him he drives it at you, both hands;
## its point catches.
## OUT OF REACH. Someone more than `reach_up` above the floor (up the ivy, on a
## wall top, a terrace) cannot be got at: they gather below and drum, and after
## `wait_below` seconds they give it up and go home.
##
## Escape: break their line (a corner, a turning), out-sprint them, climb high.
##
## As a puppet he follows the host's news as the others do; his calls, throws
## and jabs come as counts in his flag (and whether he has his spear), and his
## aim as its point, so a guest sees the spear thrown at the same place and fly
## the same way (a guest's spear catches nobody).

enum Mode { PATROL, CALL, CHASE, WIND, THROWN, FETCH, PICK, JAB, BELOW }

## Hunting parties: party id -> its members, first the chief.
static var parties := {}
## When one of each party last drew back to throw (seconds of the game), so that only one throws at a time.
static var _party_threw := {}

@export var patrol_speed := 1.5
## As fast as a player's run (Player.run_speed 4.4): a sprint (5.6) gets away.
@export var chase_speed := 4.3
@export var acceleration := 14.0
@export var turn_rate := 8.0
## Throws at someone between these, metres.
@export var throw_range := Vector2(4.5, 17.0)
## How fast the spear leaves his hand, m/s.
@export var spear_speed := 16.0
## How long he is drawn back before he throws: the warning.
@export var wind_time := 0.85
## How much of where his quarry is going he throws at (1: all of it).
@export var lead := 0.75
## Seconds after one of a party has thrown before the next of them draws back.
@export var party_gap := 1.1
## Jabs at someone this near in front of him.
@export var jab_range := 1.75
## Higher than this above the floor (m), someone is out of his reach.
@export var reach_up := 2.1
## How long they wait below someone out of reach before they go home.
@export var wait_below := 12.0
## How long he goes after a spear he cannot reach before he takes another.
@export var fetch_most := 9.0
## Further than this from the camera he is not posed (the walls hide him).
@export var pose_range := 70.0
@export var gravity := 24.0
## Which party he is of, and his place in its file (0: the chief, who leads).
@export var party := 0
@export var rank := 0
## The chief plants the party's totem at its den.
@export var chief := false
## Where the party camps (INF: nowhere: they wander).
var den := Vector3.INF
## His look (set before he goes in; `party_of` sets them).
@export var mask := 0
@export var point := TribeSpear.Point.STONE
@export var clay_tint := 1.0

var mode := Mode.PATROL
var facing_yaw := 0.0
var tribesman: Tribesman
var totem: Node3D

var _radius := 0.22
var _mode_time := 0.0
var _cool := 0.0
var _point := Vector3.INF
var _calls := 0
var _throws := 0
var _jabs := 0
var _struck := false
var _below := 0.0
var _home_turn := false
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flagged := false


## A hunting party of `count`, ready to be placed: the chief first, each in his
## own mask, the spears' heads mixed, camping at `den` (INF: no camp).
static func party_of(count: int, seed_value := 0, den_at := Vector3.INF) -> Array[MazeTribesman]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var id := rng.randi()
	var first := rng.randi_range(0, Tribesman.MASK_COUNT - 1)
	var made: Array[MazeTribesman] = []
	for k in count:
		var one := MazeTribesman.new()
		one.party = id
		one.rank = k
		one.chief = k == 0
		one.den = den_at
		one.mask = (first + k * 2) % Tribesman.MASK_COUNT
		one.point = TribeSpear.Point.BONE if rng.randf() < 0.4 else TribeSpear.Point.STONE
		one.clay_tint = rng.randf_range(0.88, 1.08)
		made.append(one)
	return made


func _init() -> void:
	sight_range = 38.0
	hear_range = 8.0
	memory = 9.0
	alert_range = 40.0
	pack = &"tribe"
	look_every = 0.2


func _enter_tree() -> void:
	super()
	var members: Array = parties.get(party, [])
	if not members.has(self):
		members.append(self)
		members.sort_custom(func(a: MazeTribesman, b: MazeTribesman) -> bool: return a.rank < b.rank)
	parties[party] = members


func _exit_tree() -> void:
	var members: Array = parties.get(party, [])
	members.erase(self)
	if members.is_empty():
		parties.erase(party)
	if totem and is_instance_valid(totem):
		totem.queue_free()


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	shape.radius = _radius
	shape.height = 1.3
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.65
	add_child(collider)
	tribesman = Tribesman.new()
	tribesman.mask = mask
	tribesman.point = point
	tribesman.clay_tint = clay_tint
	tribesman.low_poly = Settings.low_poly
	add_child(tribesman)
	tribesman.top_level = true
	facing_yaw = rotation.y
	_prev_pos = global_position
	_curr_pos = global_position
	tribesman.put(global_position, facing_yaw)
	spotted.connect(_on_spotted)
	# The chief plants the party's totem in its dead end.
	if chief and den.is_finite():
		_plant_totem.call_deferred()


func _plant_totem() -> void:
	if not is_inside_tree() or get_parent() == null:
		return
	var post := Tribesman.totem()
	post.name = "TribeTotem%d" % (party & 0xffff)
	var at := den
	if maze:
		var cell := maze.cell_at(den)
		at = maze.world(cell)
		# (back against the dead end's blind wall, facing out of it)
		var out := Vector2i.ZERO
		for s: Vector2i in Maze.STEPS:
			if not maze.blocked(cell, s):
				out = s
		if out != Vector2i.ZERO and nav.dead_end(cell):
			var outward := Vector3(out.x, 0.0, out.y)
			# (as far back as it goes: short of the wall, or of a terrace or anything before it)
			var back := Maze.CELL * 0.3
			var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.UP * 0.5 - outward * (back + 1.2), 1)
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				back = maxf((at + Vector3.UP * 0.5).distance_to(hit.position) - 1.2, 0.0)
			at -= outward * back
			post.rotation.y = atan2(outward.x, outward.z)
	post.position = at
	get_parent().add_child(post)
	totem = post


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
	_cool -= delta
	_mode_time += delta
	_spear_hits()
	var grounded := is_on_floor()
	var wish := Vector3.ZERO
	var speed := 0.0
	var after := quarry if hunting() and quarry.get(&"is_limp") != true else null
	chasing = after != null and mode != Mode.PATROL
	match mode:
		Mode.CALL:
			_point = after.global_position + Vector3.UP * 0.9 if after else _point
			if _mode_time >= TribesmanRig.CHANT:
				_set_mode(Mode.CHASE if after else Mode.PATROL)
			_steer(Vector3.ZERO, 0.0, delta, grounded)
			return
		Mode.WIND:
			_wind(after, delta, grounded)
			return
		Mode.THROWN:
			if _mode_time >= Tribesman.act_length(TribesmanRig.Act.THROW):
				_set_mode(Mode.FETCH)
			_steer(Vector3.ZERO, 0.0, delta, grounded)
			return
		Mode.PICK:
			if tribesman.armed() and not tribesman.busy():
				_cool = 1.5
				_set_mode(Mode.CHASE if after else Mode.PATROL)
			_steer(Vector3.ZERO, 0.0, delta, grounded)
			return
		Mode.JAB:
			if not _struck:
				for player: Node3D in _live_players():
					if huntable(player) and tribesman.jab_hits(player.global_position, _height_of(player), 0.32):
						_struck = true
						_catch(player)
						break
			if not tribesman.busy():
				_cool = 0.9
				_set_mode(Mode.CHASE if after and not _struck else Mode.PATROL)
			_steer(Vector3.ZERO, 0.0, delta, grounded)
			return
	if not tribesman.armed() and mode != Mode.FETCH:
		_set_mode(Mode.FETCH)
	if mode == Mode.FETCH:
		wish = _fetch(delta)
		speed = chase_speed * 0.8 if after else patrol_speed * 1.6
	elif after:
		if mode == Mode.PATROL:
			_set_mode(Mode.CHASE)
		var to := after.global_position - global_position
		var flat := Vector3(to.x, 0.0, to.z)
		var high := _height_above_floor(after) > reach_up
		if high:
			# Out of reach: they gather below and drum, and give it up in the end.
			if mode != Mode.BELOW:
				_set_mode(Mode.BELOW)
				_below = 0.0
			_below += delta
			_point = after.global_position + Vector3.UP * 0.6
			if _below > wait_below:
				_spared[after] = 10.0
				quarry = null
				_forget = 0.0
				_set_mode(Mode.PATROL)
			elif flat.length() > 3.5 + rank * 0.8:
				wish = way(_radius)
				speed = chase_speed * 0.7
			elif _cool <= 0.0 and not tribesman.busy():
				_cool = randf_range(3.0, 5.0)
				_calls += 1
				tribesman.chant()
		else:
			if mode == Mode.BELOW:
				_set_mode(Mode.CHASE)
			_point = after.global_position + Vector3.UP * 0.9
			var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
			if _cool <= 0.0 and flat.length() < jab_range and absf(to.y) < 1.0 and forward.dot(flat.normalized()) > 0.55:
				_jab()
				return
			if _cool <= 0.0 and _may_throw(after, flat.length()):
				_set_mode(Mode.WIND)
				_party_threw[party] = _now()
				_aim_at(after)
				tribesman.aim = _point
				tribesman.wind_up()
				_steer(Vector3.ZERO, 0.0, delta, grounded)
				return
			wish = way(_radius)
			speed = chase_speed
			# (close in, straight at them if nothing is in the way: the chief from further off, the rest fanning out first)
			if flat.length() < (7.0 if rank == 0 else 3.0) and nav.line_free(global_position, after.global_position, _radius):
				wish = flat
	else:
		if mode != Mode.PATROL:
			_set_mode(Mode.PATROL)
		_point = Vector3.INF
		wish = _patrol()
		speed = patrol_speed
		if rank > 0:
			var ahead := _ahead_of_me()
			if ahead and ahead.global_position.distance_to(global_position) > 6.0:
				speed = patrol_speed * 1.8
	var push := _apart(_radius)
	if wish.length() > 0.01:
		wish = wish.normalized()
		if push != Vector3.ZERO:
			wish = (wish + push * 0.6).normalized()
	_steer(wish, speed, delta, grounded)


func _set_mode(next: Mode) -> void:
	mode = next
	_mode_time = 0.0


## The players still in the game (a freed one in `targets` is passed over).
func _live_players() -> Array:
	return players().filter(func(p: Variant) -> bool: return is_instance_valid(p) and p is Node3D)


## How tall someone is now: ducked, a spear may go over them.
func _height_of(player: Node3D) -> float:
	if player.get(&"is_ducking") == true or player.get(&"is_crawling") == true:
		return 0.8
	return 1.3


func _height_above_floor(player: Node3D) -> float:
	return player.global_position.y - maze.world(maze.cell_at(player.global_position)).y


## Whether he may throw at `after`, `distance` off: his spear in hand, the party
## not just thrown, and a clear straight line from his hand to them.
func _may_throw(after: Node3D, distance: float) -> bool:
	if not tribesman.armed() or distance < throw_range.x or distance > throw_range.y:
		return false
	if _now() - float(_party_threw.get(party, -99.0)) < wind_time + party_gap:
		return false
	var hand := global_position + Vector3.UP * 1.1
	return nav.line_free(hand, after.global_position + Vector3.UP * 0.9, 0.15)


## Where to throw: where `after` will be by the time the spear gets there, most of the way.
func _aim_at(after: Node3D) -> void:
	var at := after.global_position + Vector3.UP * 0.85
	var running: Variant = after.get(&"velocity")
	if running is Vector3:
		var flight := at.distance_to(global_position) / spear_speed
		at += Vector3((running as Vector3).x, 0.0, (running as Vector3).z) * flight * lead
	_point = at


## Drawn back: he keeps his aim on them, and throws when the wind-up is done,
## if they are still in his line (he holds a moment for them if not, then gives
## it up).
func _wind(after: Node3D, delta: float, grounded: bool) -> void:
	_steer(Vector3.ZERO, 0.0, delta, grounded)
	if after:
		_aim_at(after)
	tribesman.aim = _point
	if _mode_time < wind_time:
		return
	var clear := after != null and nav.line_free(global_position + Vector3.UP * 1.1, after.global_position + Vector3.UP * 0.9, 0.15) and _height_above_floor(after) <= reach_up
	if clear:
		_throws += 1
		tribesman.loose(Tribesman.launch(tribesman.spear_point(), _point, spear_speed, tribesman.spear.gravity))
		_set_mode(Mode.THROWN)
	elif _mode_time > wind_time + 0.7:
		tribesman.cancel()
		_cool = 0.5
		_set_mode(Mode.CHASE if after else Mode.PATROL)


func _jab() -> void:
	_set_mode(Mode.JAB)
	_struck = false
	_jabs += 1
	tribesman.aim = _point
	tribesman.jab()


## His spear in flight: it catches whoever it passes through.
func _spear_hits() -> void:
	var spear := tribesman.spear
	if spear.held() or (not spear.flying() and spear.time > 0.0):
		return
	for player: Node3D in _live_players():
		if huntable(player) and spear.hits(player.global_position, _height_of(player), 0.3):
			_catch(player)
			break


## Going for his spear where it fell; takes it up when he is at it.
func _fetch(_delta: float) -> Vector3:
	var spear := tribesman.spear
	if spear.flying():
		return Vector3.ZERO
	var at := spear.lying_at()
	var floor_y := maze.world(maze.cell_at(at)).y
	var reachable := at.y - floor_y < 1.6 and nav.allowed(maze.cell_at(at)) and nav.distance(maze.cell_at(global_position), maze.cell_at(at)) >= 0
	if not reachable or _mode_time > fetch_most:
		# (out of his reach: another from the bundle on his back)
		tribesman.rearm()
		_cool = 1.0
		_set_mode(Mode.PATROL if not hunting() else Mode.CHASE)
		return Vector3.ZERO
	var to := at - global_position
	to.y = 0.0
	if to.length() < 0.55:
		_set_mode(Mode.PICK)
		_point = at
		tribesman.pick_up()
		return Vector3.ZERO
	_point = at
	return to if nav.line_free(global_position, at, _radius) else _way_to(at)


## Patrolling: the chief wanders from the den and back; the rest follow him in file.
func _patrol() -> Vector3:
	if rank == 0:
		return way(_radius)
	var ahead := _ahead_of_me()
	if ahead == null:
		return way(_radius)
	var to := ahead.global_position - global_position
	to.y = 0.0
	if to.length() < 2.3:
		return Vector3.ZERO
	return to if nav.line_free(global_position, ahead.global_position, _radius) else _way_to(ahead.global_position)


## The one before him in the file (the nearest of lower rank still about).
func _ahead_of_me() -> MazeTribesman:
	var best: MazeTribesman = null
	for other: MazeTribesman in parties.get(party, []):
		if is_instance_valid(other) and other != self and other.rank < rank and other.is_inside_tree():
			if best == null or other.rank > best.rank:
				best = other
	return best


## Where he makes for. Wandering, the chief goes out from the den and back to it
## by turns; hunting, the others make for where their quarry is going, the
## further ahead the further down the file they are.
func goal() -> Vector3:
	if hunting() and rank > 0:
		var at := quarry.global_position
		var running: Variant = quarry.get(&"velocity")
		if running is Vector3 and global_position.distance_to(at) > 9.0:
			var ahead := at + Vector3((running as Vector3).x, 0.0, (running as Vector3).z) * 1.1 * rank
			var cell := maze.cell_at(ahead)
			if nav.allowed(cell) and maze.inside(cell):
				return ahead
		# (near, they fan out either side of whoever it is, to close round them)
		var to := at - global_position
		var beside := Vector3(to.z, 0.0, -to.x).normalized() * (1.6 + 0.6 * rank) * (1.0 if rank % 2 == 1 else -1.0)
		if to.length() > 2.5 and nav.allowed(maze.cell_at(at + beside)) and nav.line_free(at, at + beside, _radius):
			return at + beside * clampf((to.length() - 2.5) / 4.0, 0.0, 1.0)
		return at
	if not hunting() and not _last_seen.is_finite() and rank == 0 and den.is_finite():
		var here := maze.cell_at(global_position)
		if _home_turn:
			if nav.distance(here, maze.cell_at(den)) <= 0:
				_home_turn = false
			else:
				return den
		elif _wander_goal.x >= 0 and here == _wander_goal:
			# (out to somewhere, then home again)
			_home_turn = true
			_wander_goal = Vector2i(-1, -1)
			return den
	return super()


func _way_to(point_at: Vector3) -> Vector3:
	var to := nav.waypoint(global_position, point_at, MazeNav.clearance_for(_radius)) - global_position
	to.y = 0.0
	return to


func _steer(wish: Vector3, speed: float, delta: float, grounded: bool) -> void:
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, acceleration * delta)
	velocity.x = current.x
	velocity.z = current.z
	if not grounded:
		velocity.y -= gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _on_spotted(_player: Node3D) -> void:
	if puppet or mode in [Mode.WIND, Mode.THROWN, Mode.JAB, Mode.PICK, Mode.FETCH, Mode.CALL]:
		return
	if mode == Mode.PATROL:
		_set_mode(Mode.CALL)
		_calls += 1
		tribesman.chant()


## Told by his party: he joins the hunt without stopping to call (but throws only after a moment).
func alerted(player: Node3D, from: Vector3) -> void:
	super(player, from)
	if mode == Mode.PATROL:
		_set_mode(Mode.CHASE)
		# (they answer the call before they throw: a moment for whoever was seen to get out of their line)
		_cool = maxf(_cool, 1.4 + 0.3 * rank)


# --- What he looks like ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		# Further than pose_range from the camera he is not posed (the walls hide him), as the runners are not.
		var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
		var far := camera != null and camera.global_position.distance_to(global_position) > pose_range and tribesman.spear.held()
		if far != _far:
			_far = far
			tribesman.visible = not far
			tribesman.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
	if _far:
		return
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	var facing_point := mode in [Mode.CALL, Mode.WIND, Mode.THROWN, Mode.JAB, Mode.BELOW, Mode.PICK]
	if puppet and not facing_point:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-10.0 * delta))
	elif facing_point and _point.is_finite():
		var to := _point - global_position
		if Vector2(to.x, to.z).length() > 0.2:
			facing_yaw = lerp_angle(facing_yaw, atan2(to.x, to.z), 1.0 - exp(-(12.0 if mode == Mode.WIND else 6.0) * delta))
	elif heading.length_squared() > 0.04:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))
	tribesman.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	tribesman.rotation = Vector3(0.0, facing_yaw, 0.0)
	tribesman.velocity = heading
	tribesman.grounded = is_on_floor() or puppet
	tribesman.stalking = false
	tribesman.aim = _point if mode != Mode.PATROL else Vector3.INF


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Throws (low three bits), jabs (next two), calls (next two), and whether his
## spear is in his hand (the top bit).
func net_flag() -> int:
	return (_throws & 0x07) | ((_jabs & 0x03) << 3) | ((_calls & 0x03) << 5) | ((1 if tribesman and tribesman.spear.held() else 0) << 7)


func net_point() -> Vector3:
	return _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point_at := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point_at)
	mode = state as Mode
	chasing = mode in [Mode.CALL, Mode.CHASE, Mode.WIND, Mode.JAB, Mode.BELOW]
	_point = point_at
	var throws := flag & 0x07
	var jabs := (flag >> 3) & 0x03
	var calls := (flag >> 5) & 0x03
	var armed := (flag >> 7) & 1 == 1
	if not _heard_flagged:
		_heard_flagged = true
	elif tribesman:
		if calls != (_calls & 0x03):
			tribesman.chant()
		if jabs != (_jabs & 0x03):
			tribesman.aim = _point
			tribesman.jab()
		if throws != (_throws & 0x07) and tribesman.spear.held() and point_at.is_finite():
			tribesman.aim = point_at
			if tribesman.doing() != TribesmanRig.Act.THROW:
				tribesman.wind_up()
			tribesman.loose(Tribesman.launch(tribesman.spear_point(), point_at, spear_speed, tribesman.spear.gravity))
		if armed and not tribesman.spear.held() and not tribesman.spear.flying():
			if mode == Mode.PICK and tribesman.spear.lying_at().distance_to(global_position) < 1.5:
				tribesman.pick_up()
			elif mode != Mode.PICK:
				tribesman.rearm()
	_throws = throws
	_jabs = jabs
	_calls = calls


func _heard_changed(_was: int, now: int, first: bool) -> void:
	if first or tribesman == null:
		return
	if now == Mode.WIND and tribesman.spear.held():
		tribesman.aim = _point
		tribesman.wind_up()


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if tribesman:
		tribesman.put(at, facing)


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4


## The game's clock, seconds (by physics frames: the same for every one of them).
static func _now() -> float:
	return float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second

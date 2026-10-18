class_name MazeBoar
extends MazeEnemy
## A giant boar loose in the maze. It is drawn and moved by Boar
## (creatures/boar/boar.gd); this is what it thinks.
##
## ROOTING. It goes slowly about the mud of its hall or dead end, snout down,
## ploughing, and now and then lifts its head and sniffs the air.
## ITS NOSE. It sees poorly (`sight_range` is short) but smells well: a player
## within `smell_range` is noticed, further when the wind carries their scent
## to it (they are upwind of it, `WIND`) and nearer when it does not (downwind
## of it), a little nearer still ducking or crawling, and only round a corner
## or two (by the passages). Sprinting near it it hears (`hear_running`). So
## creep past it downwind, or keep away.
## THE WIND-UP. When it notices someone it turns to them, snorts (steam from
## its nose), stamps and paws the ground twice, its hackles rise, it lowers its
## head, and squeals: about two seconds, to see and hear coming. Where they are
## out of a straight line from it (round a corner), it trots after them by the
## passages first, and winds up when it has them in a line.
## THE CHARGE. Then it charges in a straight line where they were, far faster
## than anyone runs (`charge_speed`) and barely able to turn (`charge_turn`).
## Step aside (into a side passage, a slot through a wall, up a way up) and it
## thunders past: it skids to a stop well beyond, turns, and comes again; or,
## if a wall is in its way, it slams into it and stands stunned for
## `stun_time` seconds, shaking its head, and then forgets them a while and goes
## back to rooting. Whoever is in front of its tusks as it charges is tossed
## (thrown limp through the air) and `caught`.
## Anyone up on a wall, a terrace or ivy (higher than `reach_up`) it cannot
## touch: it grunts and paws below them and loses interest.
##
## As a puppet it follows the host's news like the others; its snorts, stamps,
## squeals, slams and tosses come as counts in its flag and are played here too.

enum Mode { ROOT, SNIFF, TRAIL, WIND_UP, CHARGE, SKID, STUN, TOSS, RECOVER }

## How much bigger than the model it is drawn (the model stands a metre at the shoulder).
const SCALE := 2.7
## The way the wind blows over the maze (as the grass has it): scent goes this way.
const WIND := Vector2(1.0, 0.35)
## Seconds into the wind-up of each thing it does.
const SNORT_AT := 0.0
const STAMPS_AT: Array[float] = [0.55, 1.15]
const LOWER_AT := 1.1
const WIND_UP_TIME := 2.2

@export var root_speed := 0.8
@export var trail_speed := 2.4
@export var charge_speed := 11.0
## How fast it gets up to its charge (m/s each second), and how fast it stops skidding.
@export var charge_acceleration := 9.0
@export var skid_braking := 11.0
## How fast it can turn charging, and standing (radians a second).
@export var charge_turn := 0.04
@export var turn_rate := 1.8
## How far it charges at most, and how far past where they were before it gives up and skids.
@export var charge_length := 60.0
@export var overshoot := 7.0
## How far it smells someone downwind of it (x) and upwind of it (y), metres.
@export var smell_range := Vector2(7.0, 20.0)
## How near someone sprinting must come for it to hear them.
@export var hear_running := 11.0
## How far off it will wind up to charge someone in a line from it.
@export var charge_reach := 45.0
## Higher than this above its hooves, it cannot reach them.
@export var reach_up := 2.6
@export var stun_time := 3.5
## After it has been stunned or tossed someone, it pays no heed to anyone for this long.
@export var calm_time := 7.0
## Further than this from every player it is not posed (the walls hide it).
@export var pose_range := 80.0
@export var gravity := 24.0
@export var size := SCALE

var mode := Mode.ROOT
var facing_yaw := 0.0
var boar: Boar
## The way it is charging (flat, in the world).
var charge_way := Vector3.FORWARD

var _radius := 1.1
var _mode_time := 0.0
var _sniff_in := 6.0
var _grunt_in := 4.0
var _calm_left := 0.0
var _stamped := 0
var _lowered := false
var _squealed := false
var _charge_from := Vector3.ZERO
var _speed := 0.0
var _point := Vector3.INF
var _thrown: Array = []
var _snorts := 0
var _stamps := 0
var _slams := 0
var _tosses := 0
var _squeals := 0
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flagged := false


func _init() -> void:
	# (poor eyes; its nose is `_smell`)
	sight_range = 10.0
	hear_range = 0.0
	memory = 8.0
	alert_range = 0.0
	pack = &"boars"
	look_every = 0.2


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.4
	var shape := CapsuleShape3D.new()
	_radius = 0.42 * size
	shape.radius = _radius
	shape.height = 1.0 * size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	boar = Boar.new()
	boar.low_poly = Settings.low_poly
	boar.scale = Vector3.ONE * size
	add_child(boar)
	boar.top_level = true
	facing_yaw = rotation.y
	_prev_pos = global_position
	_curr_pos = global_position
	boar.global_position = global_position
	boar.rotation = Vector3(0.0, facing_yaw, 0.0)
	boar.settle()
	_sniff_in = _rng.randf_range(4.0, 9.0)


# --- Its nose ---

## Smells (and hears) players near it: see the class's notes.
func _smell() -> void:
	if _look_in < look_every - 0.001 or _calm_left > 0.0:
		return
	var here := maze.cell_at(global_position)
	var wind := WIND.normalized()
	for player: Node3D in players():
		if not huntable(player):
			continue
		var to := player.global_position - global_position
		var flat := Vector2(to.x, to.z)
		var d := flat.length()
		# (scent comes to it on the wind from someone upwind of it: wind blowing from them to it)
		var upwind := clampf(-wind.dot(flat / maxf(d, 0.01)) * 0.5 + 0.5, 0.0, 1.0)
		var reach := lerpf(smell_range.x, smell_range.y, upwind * upwind)
		if player.get(&"is_ducking") == true or player.get(&"is_crawling") == true:
			reach *= 0.7
		var noticed := d < reach
		if player.get(&"is_sprinting") == true and d < hear_running:
			noticed = true
		if noticed:
			var steps := nav.distance(here, maze.cell_at(player.global_position))
			if steps >= 0 and steps <= 2:
				notice(player)


# --- Thinking ---

func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze == null:
		return
	_calm_left -= delta
	_mode_time += delta
	if _calm_left > 0.0:
		quarry = null
		_forget = 0.0
	else:
		_sense(delta)
		_smell()
	var grounded := is_on_floor()
	var after := quarry if hunting() and quarry.get(&"is_limp") != true else null
	match mode:
		Mode.ROOT, Mode.SNIFF:
			_rooting(delta, grounded, after)
		Mode.TRAIL:
			_trail(delta, grounded, after)
		Mode.WIND_UP:
			_wind_up(delta, grounded, after)
		Mode.CHARGE:
			_charge(delta, grounded, after)
		Mode.SKID:
			_skid(delta, grounded)
		Mode.STUN:
			_stand(delta, grounded)
			if _mode_time > stun_time:
				_calm_left = calm_time
				_go(Mode.RECOVER)
		Mode.TOSS:
			_stand(delta, grounded, 6.0)
			if _mode_time > BoarRig.TOSS_TIME + 0.4:
				_calm_left = calm_time
				_go(Mode.RECOVER)
		Mode.RECOVER:
			_stand(delta, grounded)
			if _mode_time > 1.2:
				_go(Mode.ROOT)
	chasing = mode in [Mode.TRAIL, Mode.WIND_UP, Mode.CHARGE]


func _go(next: Mode) -> void:
	mode = next
	_mode_time = 0.0


## Rooting about, slow, now and then lifting its head to sniff; noticing
## someone, it goes after them.
func _rooting(delta: float, grounded: bool, after: Node3D) -> void:
	_point = Vector3.INF
	if after and _too_high(after):
		# Out of its reach: it stands below them, grunting and pawing, and gives up.
		_point = after.global_position
		if mode != Mode.SNIFF:
			_go(Mode.SNIFF)
		elif _mode_time > 6.0:
			_calm_left = calm_time
			_go(Mode.ROOT)
		elif fmod(_mode_time, 2.5) < delta:
			_stamps += 1
			boar.stamp()
		_stand(delta, grounded)
		_turn_to(_point - global_position, turn_rate, delta)
		return
	if after:
		_hunt(after)
		_stand(delta, grounded)
		return
	_grunt_in -= delta
	if _grunt_in <= 0.0:
		_grunt_in = _rng.randf_range(4.0, 9.0)
		boar.grunt()
	if mode == Mode.SNIFF:
		_stand(delta, grounded)
		if _mode_time > 2.6:
			_go(Mode.ROOT)
		return
	_sniff_in -= delta
	if _sniff_in <= 0.0:
		_sniff_in = _rng.randf_range(6.0, 12.0)
		_go(Mode.SNIFF)
		return
	var wish := way(_radius)
	_steer(wish.normalized() if wish.length() > 0.01 else Vector3.ZERO, root_speed, 2.0, delta, grounded)
	_turn_to(Vector3(velocity.x, 0.0, velocity.z), 1.2, delta)


## What it does about someone it has noticed: winds up at them if they are in
## a straight line from it and in reach, else goes after them by the passages.
## Up out of its reach, it stands below them.
func _hunt(after: Node3D) -> void:
	if _in_line(after):
		_start_wind_up()
	else:
		_go(Mode.TRAIL)


func _too_high(who: Node3D) -> bool:
	return who.global_position.y - global_position.y > reach_up


func _in_line(who: Node3D) -> bool:
	var to := who.global_position - global_position
	return Vector2(to.x, to.z).length() < charge_reach and nav.line_free(global_position, who.global_position, _radius * 0.8)


## Trots after them by the passages, nose up, until it has them in a line.
func _trail(delta: float, grounded: bool, after: Node3D) -> void:
	if after == null:
		_go(Mode.ROOT)
		return
	if _too_high(after):
		_go(Mode.SNIFF)
		return
	_point = after.global_position + Vector3.UP
	if _in_line(after):
		_start_wind_up()
		return
	var wish := way(_radius)
	_steer(wish.normalized() if wish.length() > 0.01 else Vector3.ZERO, trail_speed, 4.0, delta, grounded)
	_turn_to(Vector3(velocity.x, 0.0, velocity.z), turn_rate, delta)


func _start_wind_up() -> void:
	_go(Mode.WIND_UP)
	_stamped = 0
	_lowered = false
	_squealed = false
	_snorts += 1
	boar.snort()


## Turns to face them, snorts, stamps, lowers its head, squeals; then charges.
func _wind_up(delta: float, grounded: bool, after: Node3D) -> void:
	_stand(delta, grounded)
	if after:
		_point = after.global_position + Vector3.UP
	if _point.is_finite():
		_turn_to(_point - global_position, turn_rate, delta)
	if _stamped < STAMPS_AT.size() and _mode_time >= STAMPS_AT[_stamped]:
		_stamped += 1
		_stamps += 1
		boar.stamp()
	_lowered = _mode_time >= LOWER_AT
	if not _squealed and _mode_time >= WIND_UP_TIME - 0.25:
		_squealed = true
		_squeals += 1
		boar.squeal()
	if _mode_time >= WIND_UP_TIME:
		if after and _too_high(after):
			_go(Mode.SNIFF)
			return
		var aim := (after.global_position if after else _point) - global_position
		aim.y = 0.0
		charge_way = aim.normalized() if aim.length() > 0.1 else Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
		facing_yaw = atan2(charge_way.x, charge_way.z)
		_charge_from = global_position
		_speed = 0.0
		_go(Mode.CHARGE)


## Straight on, barely turning, gathering speed: goring whoever is in front of
## it, slamming into a wall, or, past them, skidding to a stop.
func _charge(delta: float, grounded: bool, after: Node3D) -> void:
	_speed = minf(_speed + charge_acceleration * delta, charge_speed)
	if after and after.global_position.distance_to(global_position) > 25.0:
		# (it can turn only a little towards them, and not at all once it is close: it is committed)
		var to := after.global_position - global_position
		to.y = 0.0
		var off := angle_difference(atan2(charge_way.x, charge_way.z), atan2(to.x, to.z))
		var yaw_now := atan2(charge_way.x, charge_way.z) + clampf(off, -charge_turn * delta, charge_turn * delta)
		charge_way = Vector3(sin(yaw_now), 0.0, cos(yaw_now))
		_point = after.global_position + Vector3.UP
	facing_yaw = atan2(charge_way.x, charge_way.z)
	_gore()
	if mode != Mode.CHARGE:
		return
	if _wall_ahead(_speed * delta):
		_slam()
		return
	var gone := global_position.distance_to(_charge_from)
	var past := after != null and (after.global_position - global_position).dot(charge_way) < -overshoot
	if gone > charge_length or past or (after == null and gone > 12.0):
		_go(Mode.SKID)
	_drive(charge_way * _speed, delta, grounded)


func _skid(delta: float, grounded: bool) -> void:
	_speed = maxf(_speed - skid_braking * delta, 0.0)
	_gore()
	if mode != Mode.SKID:
		return
	if _wall_ahead(_speed * delta):
		if _speed > 5.0:
			_slam()
			return
		_speed = 0.0
	_drive(charge_way * _speed, delta, grounded)
	if _speed <= 0.0:
		boar.grunt()
		_go(Mode.RECOVER)


## Whether a wall is just in front of its head (`more` metres more).
func _wall_ahead(more: float) -> bool:
	var from := global_position + Vector3.UP * 0.6 * size
	var reach := 1.25 * size + more + 0.3
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + charge_way * reach, 1, [get_rid()]))
	# (only something built, standing up: not a player, a vine, a plank)
	if not hit.is_empty() and hit["collider"] is StaticBody3D and absf((hit["normal"] as Vector3).y) < 0.5:
		return true
	# (and the plan's walls, for anything without a body to hit)
	return not nav.line_free(global_position, global_position + charge_way * reach, 0.0)


func _slam() -> void:
	_speed = 0.0
	velocity = Vector3.ZERO
	_slams += 1
	boar.slam()
	quarry = null
	_forget = 0.0
	_point = Vector3.INF
	_go(Mode.STUN)


## Anyone in front of its tusks as it charges is tossed, and caught.
func _gore() -> void:
	if _speed < 3.0:
		return
	var front := global_position + charge_way * 1.0 * size
	for player: Node3D in players():
		if not huntable(player) or player in _thrown:
			continue
		var at := player.global_position
		var to := at - front
		var along := to.dot(charge_way)
		var across := absf(to.dot(Vector3(charge_way.z, 0.0, -charge_way.x)))
		var up := at.y - global_position.y
		if along > -0.9 * size and along < 0.55 * size and across < 0.42 * size + 0.35 and up < reach_up and up > -1.0:
			_toss(player)
			return


func _toss(player: Node3D) -> void:
	var side := signf(player.global_position.dot(Vector3(charge_way.z, 0.0, -charge_way.x)) - global_position.dot(Vector3(charge_way.z, 0.0, -charge_way.x)))
	side = side if side != 0.0 else 1.0
	_tosses += 1
	boar.toss(-side)
	_speed = minf(_speed, 4.0)
	_go(Mode.TOSS)
	_thrown.append(player)
	if player is Player and is_instance_valid(player):
		# Thrown limp through the air, up and off to one side; caught as he lands.
		var aside := Vector3(charge_way.z, 0.0, -charge_way.x) * side
		(player as Player).ragdoll((charge_way * 0.8 + Vector3.UP * 1.1 + aside * 0.5).normalized() * 70.0)
		get_tree().create_timer(1.3).timeout.connect(_land.bind(player))
	else:
		_thrown.erase(player)
		_catch(player)


## A tossed player has come down: stood up, and caught.
func _land(player: Node3D) -> void:
	_thrown.erase(player)
	if not is_instance_valid(player):
		return
	if player is Player and (player as Player).is_limp:
		(player as Player).recover()
	_catch(player)


func _stand(delta: float, grounded: bool, braking := 10.0) -> void:
	_steer(Vector3.ZERO, 0.0, braking, delta, grounded)


func _steer(wish: Vector3, speed: float, acceleration: float, delta: float, grounded: bool) -> void:
	var push := _apart(_radius)
	if wish != Vector3.ZERO and push != Vector3.ZERO:
		wish = (wish + push * 0.5).normalized()
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, acceleration * delta)
	_drive(current, delta, grounded)


func _drive(flat: Vector3, delta: float, grounded: bool) -> void:
	velocity.x = flat.x
	velocity.z = flat.z
	if not grounded:
		velocity.y -= gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _turn_to(way_to: Vector3, rate: float, delta: float) -> void:
	if Vector2(way_to.x, way_to.z).length_squared() < 0.0004:
		return
	var want := atan2(way_to.x, way_to.z)
	facing_yaw += clampf(angle_difference(facing_yaw, want), -rate * delta, rate * delta)


# --- What it looks like ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			boar.visible = not far
			boar.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
			if not far:
				boar.settle()
	if _far:
		return
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-10.0 * delta))
	boar.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	boar.rotation = Vector3(0.0, facing_yaw, 0.0)
	boar.grounded = is_on_floor() or puppet
	boar.rooting = mode == Mode.ROOT
	boar.sniffing = mode == Mode.SNIFF or mode == Mode.TRAIL
	boar.bristling = mode in [Mode.WIND_UP, Mode.CHARGE, Mode.SKID, Mode.TOSS]
	boar.lowered = (mode == Mode.WIND_UP and _mode_time >= LOWER_AT) or mode == Mode.CHARGE
	boar.stunned = mode == Mode.STUN
	boar.look_at_point = _point if mode in [Mode.TRAIL, Mode.WIND_UP, Mode.SNIFF] else Vector3.INF


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Snorts and stamps (two bits each), slams (two), squeals and tosses (a bit each), as they change.
func net_flag() -> int:
	return (_snorts & 3) | ((_stamps & 3) << 2) | ((_slams & 3) << 4) | ((_squeals & 1) << 6) | ((_tosses & 1) << 7)


func net_point() -> Vector3:
	return _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	if state != mode:
		_mode_time = 0.0
	mode = state as Mode
	chasing = mode in [Mode.TRAIL, Mode.WIND_UP, Mode.CHARGE]
	_point = point
	var snorts := flag & 3
	var stamps := (flag >> 2) & 3
	var slams := (flag >> 4) & 3
	var squeals := (flag >> 6) & 1
	var tosses := (flag >> 7) & 1
	if not _heard_flagged:
		_heard_flagged = true
	elif boar:
		if snorts != (_snorts & 3):
			boar.snort()
		if stamps != (_stamps & 3):
			boar.stamp()
		if slams != (_slams & 3):
			boar.slam()
		if squeals != (_squeals & 1):
			boar.squeal()
		if tosses != (_tosses & 1):
			boar.toss(1.0)
	_snorts = snorts
	_stamps = stamps
	_slams = slams
	_squeals = squeals
	_tosses = tosses


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if boar:
		boar.global_position = at
		boar.settle()


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4

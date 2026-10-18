class_name MazeDimetrodon
extends MazeEnemy
## A dimetrodon basking in the open: a sprawling ambush hunter, deadly close
## and slow to chase. It is drawn and moved by Dimetrodon
## (creatures/dimetrodon/dimetrodon.gd); this is what it thinks.
##
## BASKING. It lies flat on warm open ground (the sunlit wide halls, the
## desert), turned side on to the sun so that its sail takes the light, and
## turns as the sun goes round. It is cold-blooded: its `warmth` comes from the
## hour and the weather (the World's DayCycle and Weather, as the lizard people
## have it) and from basking in the day; cold (at night, in rain) it is slow
## to rise, slow to lunge and slower still to chase, and it notices less.
## Now and then it gets up and shuffles to a better spot near its own.
## THE AMBUSH. Someone on the ground who comes within `notice_range` of it
## (less, cold) is noticed: it rises up on its legs, turns to face them and
## gapes and hisses (RISE: the warning, `rise_time`, longer cold), then, if
## they are still within `lunge_range` in front of it, LUNGES: a sudden low
## dart of a few metres, the jaws flung open and snapped shut; whoever its jaws
## reach is `caught`. Back off or run past while it rises and it misses.
## THE CHASE. After a lunge, or if they were out of reach, it scuttles after
## them a while (`chase_speed`, slower than a run, much slower cold) and
## lunges again if it comes near enough in front; it gives up soon and goes
## back to bask.
##
## THE OTHERS (Ecology): a meat-eater of middling size; hungry, it hunts the
## smaller creatures it sees (frogs, rats, rabbits...) in the same way, and runs
## from bigger meat-eaters.
##
## Online, a puppet follows the host's news; its lunges and hisses come as
## counts in its flag and are played there too.

enum Mode { BASK, SHUFFLE, RISE, LUNGE, CHASE, RECOVER, RETURN, FLEE }

## How far it notices someone on the ground (cold, warm), m.
@export var notice_range := Vector2(4.0, 8.5)
## How far in front it lunges from, m.
@export var lunge_range := 3.6
## How long it rises and gapes before it lunges (cold, warm), s.
@export var rise_time := Vector2(1.5, 0.75)
## How fast it lunges (cold, warm) and for how long.
@export var lunge_speed := Vector2(5.0, 7.5)
@export var lunge_time := 0.42
## How fast it chases (cold, warm): slower than a run.
@export var chase_speed := Vector2(1.2, 3.0)
@export var walk_speed := 0.6
## How long it chases at most, and how far before it gives up, m.
@export var chase_time := 6.0
@export var give_up_range := 14.0
@export var recover_time := 1.1
## How near the front of its jaws must come to someone to catch them, m.
@export var bite_radius := 0.75
## How far from where it basks it shuffles about.
@export var territory_range := 6.0
@export var gravity := 24.0
## For tests: its warmth, 0..1 (below 0: from the day and the weather).
@export var warmth_override := -1.0

var mode := Mode.BASK
var facing_yaw := 0.0
var dim: Dimetrodon
## How warm it is, 0 (cold) to 1 (warm).
var warmth := 1.0

var _home := Vector3.ZERO
var _mode_left := 0.0
var _chased := 0.0
var _lunge_way := Vector3.ZERO
var _lunges := 0
var _hisses := 0
var _sunned := 0.0
var _shuffle_in := 0.0
var _shuffle_to := Vector3.INF
var _bitten := {}
var _point := Vector3.INF
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _found_world := false
var _day: Node
var _weather: Node
var _sun: DirectionalLight3D
var _heard_flagged := false
## Whom it is after (a player, or prey: as `quarry`, but kept out in the desert too).
var _target: Node3D


func _init() -> void:
	sight_range = 0.0
	hear_range = 0.0
	memory = 4.0
	alert_range = 0.0
	pack = &"dimetrodons"
	look_every = 0.2
	spare_time = 4.0


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1
	floor_snap_length = 0.4
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.9
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.rotation.x = PI * 0.5
	collider.position = Vector3(0.0, 0.42, 0.05)
	add_child(collider)
	dim = Dimetrodon.new()
	dim.low_poly = Settings.low_poly
	add_child(dim)
	dim.top_level = true
	facing_yaw = rotation.y
	rotation = Vector3.ZERO
	_home = global_position
	_prev_pos = global_position
	_curr_pos = global_position
	dim.global_position = global_position
	dim.rotation = Vector3(0.0, facing_yaw, 0.0)
	dim.settle()
	_shuffle_in = _rng.randf_range(30.0, 70.0)


func _forward() -> Vector3:
	return Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))


## Its forward, for others (shots, tests).
func global_basis_forward() -> Vector3:
	return _forward()


# --- How warm it is ---

## From the hour (DayCycle.daylight) and the rain (Weather.rain), and the sun it has had basking.
func _warm_up(delta: float) -> void:
	if not _found_world:
		_found_world = true
		var node := get_parent()
		while node:
			if node.get(&"day") is Node:
				_day = node.get(&"day")
				_weather = node.get(&"weather") as Node
				break
			node = node.get_parent()
		_sun = _day.get(&"_sun") as DirectionalLight3D if is_instance_valid(_day) else null
		if _sun == null:
			var lights := get_tree().root.find_children("*", "DirectionalLight3D", true, false)
			_sun = lights[0] as DirectionalLight3D if not lights.is_empty() else null
	var light := 1.0
	var rain := 0.0
	if is_instance_valid(_day):
		light = float(_day.get(&"daylight"))
	if is_instance_valid(_weather):
		rain = float(_weather.get(&"rain"))
	if mode == Mode.BASK:
		_sunned = minf(_sunned + delta / 60.0 * light * (1.0 - rain), 1.0)
	else:
		_sunned = maxf(_sunned - delta / 240.0, 0.0)
	var w := lerpf(0.15, 0.9, light) * (1.0 - 0.45 * rain) + 0.15 * _sunned
	warmth = clampf(warmth_override if warmth_override >= 0.0 else w, 0.0, 1.0)


## The way it should face to take the sun on its sail: side on to it (the nearer of the two ways).
func _sun_yaw() -> float:
	if not is_instance_valid(_sun):
		return facing_yaw
	var towards := _sun.global_basis.z
	var across := atan2(towards.x, towards.z) + PI * 0.5
	return across if absf(angle_difference(facing_yaw, across)) < PI * 0.5 else across + PI


# --- Its senses ---

## Whether `who` can be gone after now (anywhere: in the halls or out in the desert).
func _can_hunt(who: Node3D) -> bool:
	if not is_instance_valid(who) or not who.is_inside_tree():
		return false
	if who is MazeEnemy:
		return not (who as MazeEnemy).dead and huntable(who)
	if not who in players():
		return false
	if who.get(&"escaped") == true or who.get(&"is_limp") == true:
		return false
	if _spared.has(who) and _spared[who] > 0.0:
		return false
	return absf(who.global_position.y - global_position.y) < 1.6


func _sees(at: Vector3) -> bool:
	var eye := global_position + Vector3.UP * 0.6
	if maze and maze.inside(maze.cell_at(global_position)) and maze.inside(maze.cell_at(at)):
		return nav.sees(eye, at + Vector3.UP * 0.6)
	return true


## Whoever on the ground is near enough to be noticed, the nearest (null: nobody).
func _noticed() -> Node3D:
	var reach := lerpf(notice_range.x, notice_range.y, warmth)
	var best: Node3D = null
	var nearest := reach
	for player: Node3D in players():
		if not _can_hunt(player):
			continue
		var apart := _flat(player.global_position - global_position).length()
		if apart < nearest and _sees(player.global_position):
			nearest = apart
			best = player
	return best


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# --- Thinking ---

func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze == null:
		return
	_warm_up(delta)
	_sense(delta)
	_mode_left -= delta
	var wish := Vector3.ZERO
	var speed := 0.0
	var want_yaw := INF
	var turn := lerpf(1.0, 2.6, warmth)
	if threat and is_instance_valid(threat) and not threat.dead and mode != Mode.LUNGE:
		mode = Mode.FLEE
	match mode:
		Mode.BASK, Mode.SHUFFLE, Mode.RETURN:
			_point = Vector3.INF
			var who := _noticed()
			if who == null and quarry is MazeEnemy and hunting():
				who = quarry
			if who:
				_start_rise(who)
			elif mode == Mode.RETURN:
				var to := _flat(_home - global_position)
				if to.length() < 1.2:
					mode = Mode.BASK
				else:
					wish = _toward(_home)
					speed = walk_speed * lerpf(0.6, 1.0, warmth)
			elif mode == Mode.SHUFFLE:
				if not _shuffle_to.is_finite() or _flat(_shuffle_to - global_position).length() < 0.8 or _mode_left <= 0.0:
					mode = Mode.BASK
				else:
					wish = _toward(_shuffle_to)
					speed = walk_speed * lerpf(0.6, 1.0, warmth)
			else:
				want_yaw = _sun_yaw()
				turn = 0.25
				_shuffle_in -= delta
				if _shuffle_in <= 0.0:
					_shuffle_in = _rng.randf_range(40.0, 90.0)
					var a := _rng.randf_range(0.0, TAU)
					var spot := _home + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(1.0, territory_range)
					if not maze.inside(maze.cell_at(spot)) or nav.line_free(global_position, spot, 1.2):
						_shuffle_to = spot
						mode = Mode.SHUFFLE
						_mode_left = 20.0
		Mode.RISE:
			if not _can_hunt(_target):
				mode = Mode.RETURN
			else:
				_point = _target.global_position + Vector3.UP * 0.8
				var to := _flat(_target.global_position - global_position)
				want_yaw = atan2(to.x, to.z)
				turn *= 1.5
				if _mode_left <= 0.0:
					if to.length() < lunge_range and absf(angle_difference(facing_yaw, want_yaw)) < 0.6:
						_start_lunge(to)
					else:
						mode = Mode.CHASE
						_chased = 0.0
		Mode.LUNGE:
			wish = _lunge_way
			speed = lerpf(lunge_speed.x, lunge_speed.y, warmth)
			_bite()
			if _mode_left <= 0.0:
				mode = Mode.RECOVER
				_mode_left = recover_time * lerpf(1.6, 1.0, warmth)
		Mode.RECOVER:
			_bite()
			if _mode_left <= 0.0:
				if _can_hunt(_target):
					mode = Mode.CHASE
					_chased = 0.0
				else:
					mode = Mode.RETURN
		Mode.CHASE:
			_chased += delta
			if not _can_hunt(_target) or _chased > chase_time * lerpf(0.6, 1.0, warmth) or _flat(_target.global_position - global_position).length() > give_up_range:
				quarry = null
				_target = null
				_forget = 0.0
				mode = Mode.RETURN
			else:
				_point = _target.global_position + Vector3.UP * 0.8
				var to := _flat(_target.global_position - global_position)
				wish = _toward(_target.global_position)
				speed = lerpf(chase_speed.x, chase_speed.y, warmth)
				if to.length() < lunge_range * 0.85 and absf(angle_difference(facing_yaw, atan2(to.x, to.z))) < 0.45:
					_start_lunge(to)
		Mode.FLEE:
			if threat == null or not is_instance_valid(threat) or threat.dead:
				mode = Mode.RETURN
			else:
				wish = _toward(goal())
				speed = lerpf(chase_speed.x, chase_speed.y, warmth) * 1.2
	chasing = mode in [Mode.RISE, Mode.LUNGE, Mode.CHASE] and not (_target is MazeEnemy)
	_move(wish, speed, want_yaw, turn, delta)


## Which way to go for `at`: by the passages in the maze, straight out in the open.
func _toward(at: Vector3) -> Vector3:
	if maze.inside(maze.cell_at(global_position)) and maze.inside(maze.cell_at(at)):
		return nav.waypoint(global_position, at, MazeNav.clearance_for(0.4)) - global_position
	return at - global_position


func _start_rise(who: Node3D) -> void:
	if who != _target and not (who is MazeEnemy):
		spotted.emit(who)
	_target = who
	if who is MazeEnemy:
		quarry = who
		_forget = memory
	mode = Mode.RISE
	_mode_left = lerpf(rise_time.x, rise_time.y, warmth)
	_hisses += 1
	dim.hiss()


func _start_lunge(to: Vector3) -> void:
	mode = Mode.LUNGE
	_mode_left = lunge_time
	_lunge_way = to.normalized()
	facing_yaw = atan2(to.x, to.z)
	_lunges += 1
	_bitten.clear()
	dim.lunge()


## Whoever its jaws reach in a lunge is caught.
func _bite() -> void:
	var tip := global_position + _forward() * 1.35 + Vector3.UP * 0.45
	for player: Node3D in players():
		if _bitten.has(player) or not _can_hunt(player) or player is MazeEnemy:
			continue
		var at := player.global_position
		var near := minf(tip.distance_to(at + Vector3.UP * 0.3), tip.distance_to(at + Vector3.UP * 0.9))
		if near < bite_radius:
			_bitten[player] = true
			if player is Player:
				(player as Player).ragdoll((_forward() * 0.8 + Vector3.UP * 0.3).normalized() * 25.0)
				get_tree().create_timer(1.0).timeout.connect(_bitten_down.bind(player))
			else:
				_catch(player)


func _bitten_down(player: Node3D) -> void:
	if not is_instance_valid(player):
		return
	if player is Player and (player as Player).is_limp:
		(player as Player).recover()
	_catch(player)


func _move(wish: Vector3, speed: float, want_yaw: float, turn: float, delta: float) -> void:
	wish.y = 0.0
	if want_yaw != INF:
		facing_yaw += clampf(angle_difference(facing_yaw, want_yaw), -turn * delta, turn * delta)
	elif wish.length() > 0.01 and mode != Mode.LUNGE:
		facing_yaw += clampf(angle_difference(facing_yaw, atan2(wish.x, wish.z)), -turn * delta, turn * delta)
	var target := Vector3.ZERO
	if wish.length() > 0.01:
		var forward := _forward()
		target = forward * speed * (1.0 if mode == Mode.LUNGE else smoothstep(0.1, 0.7, forward.dot(wish.normalized())))
	var rate := 30.0 if mode == Mode.LUNGE else lerpf(3.0, 8.0, warmth)
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, rate * delta)
	velocity.x = current.x
	velocity.z = current.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()
	if not maze.inside(maze.cell_at(global_position)):
		global_position.y = maze.ground_height(global_position)
	_prev_pos = _curr_pos
	_curr_pos = global_position


func goal() -> Vector3:
	if (threat and is_instance_valid(threat)) or hunting():
		return super()
	return _home


# --- What it looks like ---

func _process(delta: float) -> void:
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-10.0 * delta))
	dim.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	dim.rotation = Vector3(0.0, facing_yaw, 0.0)
	dim.basking = mode == Mode.BASK
	dim.threatening = mode == Mode.RISE
	dim.look_at_point = _point if mode in [Mode.RISE, Mode.CHASE, Mode.LUNGE, Mode.RECOVER] else Vector3.INF


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Lunges (low three bits), hisses (two).
func net_flag() -> int:
	return (_lunges & 7) | ((_hisses & 3) << 3)


func net_point() -> Vector3:
	return _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	chasing = mode in [Mode.RISE, Mode.LUNGE, Mode.CHASE]
	_point = point
	var lunges := flag & 7
	var hisses := (flag >> 3) & 3
	if not _heard_flagged:
		_heard_flagged = true
	elif dim:
		if lunges != (_lunges & 7):
			dim.lunge()
		if hisses != (_hisses & 3):
			dim.hiss()
	_lunges = lunges
	_hisses = hisses


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if dim:
		dim.global_position = at
		dim.settle()


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4

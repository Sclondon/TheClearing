class_name MazeFox
extends MazeEnemy
## A red fox, alone or one of a pair: wildlife, never a danger to anyone. It is
## drawn and moved by Fox (creatures/fox/fox.gd); this is what it thinks.
##
## CURIOUS ABOUT PEOPLE. It trots about its stretch of the maze (a pair
## loosely together), nose down now and then, and now and then stops dead to
## listen for a mouse in the grass, head cocked, and makes its high mousing
## pounce. Seeing a player it stops and looks, then FOLLOWS them at a
## distance (`keep_range`) along the halls; when they turn and look at it, it
## sits and watches them; after a while of it, or when they come nearer, it
## slips away, unhurried, and comes back later. Come close (`flee_range`), or
## run at it, and it gallops off. It never catches anyone: it does not hunt
## people (it is not in the group `pursuers`), and `caught` is never said.
##
## A THIEF. Something lying about near someone (a torch or flare not alight,
## a map, a grappling hook) it may trot up to, take in its jaws and carry off
## at a trot to drop well away from them, now and then (`steal_every`). Catch
## it up (or run at it) and it drops it as it flees; take it from its jaws and
## it lets go.
##
## A HUNTER OF SMALL THINGS (Ecology: it is size 1 and eats meat). Hungry, it
## goes after the small creatures it sees (frogs, and anything else of size 0):
## trots near, stalks the last few metres low and slow, and pounces from a few
## metres; coming down on it kills it, and it eats there. It runs from
## anything bigger that hunts.
##
## BY NIGHT (DayCycle) it barks, a run of hoarse high barks, every so often,
## and a vixen (variant 1) screams.
##
## TAME (`tame`): the foxes of the clearing (ClearingStyle "Wildlife"): they
## keep to their part of the meadow (`home`, `home_range`) and do the same.
## Put in by MazeEnemies.add_wildlife, and run (and sent to guests) like the rest.
##
## ONLINE. The host runs it; a guest's puppet follows what it hears: its mode
## (net_state), its barks and screams (net_flag, as counts), and where it
## looks or pounces (net_point); while it carries something, net_point says
## which thing (its loot number), and the guest carries the same thing.

enum Mode { ROAM, SNIFF, LISTEN, LOOK, FOLLOW, WATCH, SLIP, FLEE, STALK, POUNCE, EAT, STEAL, CARRY }

## How much bigger than the model it is drawn (the model is a big fox).
const SCALE := 0.72
## What it will carry off (LootItem.Kind: hook, torch, flare, map).
const STEALS := [0, 3, 4, 5]

@export var trot_speed := 2.0
@export var follow_speed := 2.5
@export var slip_speed := 2.2
@export var flee_speed := 6.2
@export var stalk_speed := 0.6
@export var acceleration := 10.0
@export var turn_rate := 8.0
## How far off it likes to follow a player, and how near sends it running.
@export var keep_range := 13.0
@export var flee_range := 6.0
## How far it sees people, metres.
@export var watch_range := 40.0
## From how far it pounces on what it hunts (it stalks inside `stalk_range`).
@export var pounce_from := 3.4
@export var stalk_range := 9.0
## About how often it takes something lying about, seconds.
@export var steal_every := 90.0
@export var tame := false
## Its patch, for a tame one: the middle and how far it goes from it.
@export var home := Vector3.INF
@export var home_range := 40.0
@export var pose_range := 80.0
@export var gravity := 24.0
@export var variant := 0
@export var coat_tint := Color.WHITE
@export var size := SCALE
## Which pair it is in (the same for both, on every machine).
@export var pair_id := 0

var mode := Mode.ROAM
var facing_yaw := 0.0
var fox: Fox
## The player it is watching (null: nobody).
var watched: Node3D
## What it has in its jaws, or is going to take (null: nothing).
var loot_item: Node3D

var _radius := 0.2
var _timer := 0.0
var _point := Vector3.INF
var _goal := Vector3.INF
var _flee_from := Vector3.ZERO
var _shy := 0.0
var _watched_for := 0.0
var _watch_in := 0.0
var _call_in := 20.0
var _steal_in := 30.0
var _barks := 0
var _screams := 0
var _pounces := 0
var _carry_to := Vector3.INF
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flagged := false
var _world: Node


## Foxes for one place: one, or a pair (a dog fox and a vixen), each a little different.
static func pair_of(count: int, seed_value := 0) -> Array[MazeFox]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tints := [Color.WHITE, Color(1.05, 0.97, 0.93), Color(0.95, 0.93, 0.92), Color(1.08, 0.98, 0.9)]
	var made: Array[MazeFox] = []
	var id := absi(seed_value) % 1000000 + 1
	for i in count:
		var one := MazeFox.new()
		one.variant = i % 2 if count > 1 else rng.randi_range(0, 1)
		one.coat_tint = tints[rng.randi_range(0, tints.size() - 1)]
		one.size = SCALE * rng.randf_range(0.93, 1.05) * (0.95 if one.variant == 1 else 1.0)
		one.pair_id = id
		made.append(one)
	return made


func _init() -> void:
	sight_range = 36.0
	hear_range = 8.0
	memory = 8.0
	alert_range = 0.0
	pack = &"foxes"
	look_every = 0.25


func _ready() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.4
	var shape := CapsuleShape3D.new()
	_radius = 0.26 * size
	shape.radius = _radius
	shape.height = 0.6 * size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	fox = Fox.new()
	fox.variant = variant
	fox.coat_tint = coat_tint
	fox.low_poly = Settings.low_poly
	fox.scale = Vector3.ONE * size
	add_child(fox)
	fox.top_level = true
	facing_yaw = rotation.y
	_prev_pos = global_position
	_curr_pos = global_position
	fox.global_position = global_position
	fox.rotation = Vector3(0.0, facing_yaw, 0.0)
	fox.settle()
	if not home.is_finite():
		home = global_position
	_call_in = _rng.randf_range(10.0, 40.0)
	_steal_in = _rng.randf_range(steal_every * 0.3, steal_every)
	# (the world: for the hour, and whether it is online)
	_world = get_parent().get_parent() if get_parent() else null


## It hunts no person: only the small creatures (Ecology). People it watches (see `_look_out`).
func huntable(target: Node3D) -> bool:
	if not (target is MazeEnemy):
		return false
	return super(target)


## Whether `player` is one it can watch: wild ones keep out of the clearing, tame ones to it.
func watchable(player: Node3D) -> bool:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return false
	if player.get(&"escaped") == true:
		return false
	if maze == null:
		return true
	var inside := maze.in_clearing(maze.cell_at(player.global_position))
	return inside if tame else not (inside and keep_out_of_clearing)


## The other of its pair (null: it is alone).
func mate() -> MazeFox:
	if not is_inside_tree():
		return null
	for other: Node in get_tree().get_nodes_in_group(&"foxes"):
		if other != self and other is MazeFox and (other as MazeFox).pair_id == pair_id:
			return other
	return null


## The one of a pair that chooses where they go (the first in the scene).
func leads() -> bool:
	var other := mate()
	return other == null or other.dead or get_index() < other.get_index()


func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		_carry_held()
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze == null:
		return
	_sense(delta)
	_look_out(delta)
	var grounded := is_on_floor()
	_timer -= delta
	_shy -= delta
	_steal_in -= delta
	_night_calls(delta)
	var who := watched
	var prey: MazeEnemy = quarry as MazeEnemy if hunting() and quarry is MazeEnemy else null
	var wish := Vector3.ZERO
	var speed := 0.0
	_point = who.global_position + Vector3.UP * 0.9 if who else Vector3.INF
	# Something bigger that hunts: away.
	if threat and is_instance_valid(threat) and mode not in [Mode.POUNCE, Mode.FLEE]:
		_flee(threat.global_position)
	# Run at, or come too near: off it goes (dropping anything it carries).
	if who and mode not in [Mode.FLEE, Mode.POUNCE]:
		var to_me := global_position - who.global_position
		to_me.y = 0.0
		var them := _velocity_of(who)
		var charging := them.length() > 3.0 and them.normalized().dot(to_me.normalized()) > 0.8 and to_me.length() < 14.0
		# (a thief at work is bolder)
		var near := flee_range * (0.55 if mode in [Mode.STEAL, Mode.CARRY] else 1.0)
		if to_me.length() < near or charging:
			_flee(who.global_position)
	if _eating > 0.0 and mode not in [Mode.FLEE, Mode.EAT]:
		mode = Mode.EAT
	match mode:
		Mode.POUNCE:
			var push := fox.pounce_push()
			velocity.x = push.x
			velocity.z = push.z
			if not fox.pouncing():
				mode = Mode.EAT if _eating > 0.0 else Mode.ROAM
				_timer = _rng.randf_range(1.0, 3.0)
			_move(delta, grounded)
			return
		Mode.EAT:
			if _eating <= 0.0:
				mode = Mode.ROAM
				_timer = _rng.randf_range(2.0, 5.0)
		Mode.FLEE:
			var away := goal() - global_position if threat else global_position - _flee_from
			away.y = 0.0
			wish = way(_radius) if threat else _way_toward(global_position + away.normalized() * 10.0)
			speed = flee_speed
			if _timer <= 0.0 and not threat:
				mode = Mode.SLIP
				_timer = _rng.randf_range(3.0, 6.0)
		Mode.SLIP:
			# (unhurried, away from whoever it was watching, glancing back)
			if who:
				var away := global_position - who.global_position
				away.y = 0.0
				wish = _way_toward(global_position + away.normalized() * 8.0)
			else:
				wish = _wander_way()
			speed = slip_speed
			if _timer <= 0.0:
				mode = Mode.ROAM
				_timer = _rng.randf_range(4.0, 8.0)
		Mode.LOOK:
			if _timer <= 0.0:
				mode = Mode.FOLLOW if who else Mode.ROAM
		Mode.FOLLOW:
			if who == null:
				mode = Mode.ROAM
			else:
				var to := who.global_position - global_position
				to.y = 0.0
				var gap := to.length()
				if gap > keep_range + 3.0:
					wish = _way_toward(who.global_position)
					speed = follow_speed
				elif gap < keep_range - 3.0:
					wish = _way_toward(global_position - to.normalized() * 4.0)
					speed = trot_speed * 0.7
				# (they turned and looked at it: it sits and watches them)
				if _facing(who) > 0.85 and gap < keep_range + 8.0:
					mode = Mode.WATCH
					_timer = _rng.randf_range(3.0, 7.0)
				elif _watched_for > _rng.randf_range(25.0, 60.0):
					_slip()
				else:
					_try_steal(who)
		Mode.WATCH:
			if who == null:
				mode = Mode.ROAM
			elif _steal_in <= 0.0:
				_try_steal(who)
			elif _timer <= 0.0:
				# (enough: it slips away, or goes on following)
				if _rng.randf() < 0.45:
					_slip()
				else:
					mode = Mode.FOLLOW
		Mode.STEAL:
			if not _can_take(loot_item):
				loot_item = null
				mode = Mode.FOLLOW if who else Mode.ROAM
			else:
				var to := loot_item.global_position - global_position
				to.y = 0.0
				if to.length() < 0.7:
					_take(loot_item, who)
				else:
					wish = _way_toward(loot_item.global_position)
					speed = follow_speed
		Mode.CARRY:
			if not _still_held():
				_drop()
			else:
				var to := _carry_to - global_position
				to.y = 0.0
				if to.length() < 1.5 or _timer <= 0.0:
					_drop()
					mode = Mode.SNIFF
					_timer = _rng.randf_range(2.0, 4.0)
				else:
					wish = _way_toward(_carry_to)
					speed = trot_speed * 1.1
		Mode.STALK:
			if prey == null:
				mode = Mode.ROAM
			else:
				var to := prey.global_position - global_position
				to.y = 0.0
				if to.length() < pounce_from and grounded:
					_pounce(prey.global_position)
					return
				wish = to
				speed = stalk_speed
		Mode.LISTEN:
			_point = global_position + Basis(Vector3.UP, facing_yaw) * Vector3(0.0, 0.0, 2.6)
			if _timer <= 0.0:
				if _rng.randf() < 0.6:
					_pounce(_point)
					return
				mode = Mode.ROAM
		Mode.SNIFF:
			if _timer <= 0.0:
				mode = Mode.ROAM
		Mode.ROAM:
			wish = _wander_way()
			speed = trot_speed
			if _timer <= 0.0:
				_timer = _rng.randf_range(4.0, 9.0)
				var roll := _rng.randf()
				if roll < 0.3:
					mode = Mode.SNIFF
					_timer = _rng.randf_range(1.5, 3.5)
				elif roll < 0.45:
					mode = Mode.LISTEN
					_timer = _rng.randf_range(1.2, 2.4)
			if who and _shy <= 0.0:
				mode = Mode.LOOK
				_timer = _rng.randf_range(1.0, 2.5)
	# After its prey, unless it is busy with someone, or running.
	if prey and mode in [Mode.ROAM, Mode.SNIFF, Mode.LISTEN, Mode.LOOK, Mode.FOLLOW, Mode.WATCH]:
		var to := prey.global_position - global_position
		to.y = 0.0
		if to.length() < stalk_range:
			mode = Mode.STALK
		else:
			wish = way(_radius)
			speed = trot_speed * 1.2
	if mode == Mode.STALK:
		_point = prey.global_position if prey else Vector3.INF
	var push := _apart(_radius * 2.0)
	if wish.length() > 0.01:
		wish = wish.normalized()
		if push != Vector3.ZERO:
			wish = (wish + push * 0.5).normalized()
	elif push != Vector3.ZERO:
		wish = push
		speed = maxf(speed, 0.8)
	_steer(wish, speed, delta, grounded)


## Who it is watching: the nearest player it sees (or hears, near), every so often.
func _look_out(delta: float) -> void:
	if watched and not watchable(watched):
		watched = null
	_watched_for = _watched_for + delta if watched else 0.0
	_watch_in -= delta
	if _watch_in > 0.0:
		return
	_watch_in = 0.3
	var eye := global_position + Vector3.UP * 0.5
	var best: Node3D = null
	var nearest := watch_range
	for player: Node in players():
		if not (player is Node3D) or not watchable(player):
			continue
		var at := (player as Node3D).global_position
		var apart := eye.distance_to(at)
		if apart < nearest and (apart < hear_range or nav.sees(eye, at + Vector3.UP, watch_range)):
			nearest = apart
			best = player
	# (it keeps an eye on one it has lost sight of for a moment)
	if best or (watched and eye.distance_to(watched.global_position) > watch_range * 1.2):
		watched = best
	elif watched and eye.distance_to(watched.global_position) > watch_range:
		watched = null


func _flee(from: Vector3) -> void:
	if mode == Mode.CARRY or mode == Mode.STEAL:
		_drop()
	if mode != Mode.FLEE and fox and _rng.randf() < 0.25:
		fox.bark_run(0)
		_barks += 1
	mode = Mode.FLEE
	_flee_from = from
	_timer = _rng.randf_range(1.6, 2.8)
	_shy = _rng.randf_range(6.0, 12.0)


func _slip() -> void:
	mode = Mode.SLIP
	_timer = _rng.randf_range(5.0, 9.0)
	_shy = _rng.randf_range(15.0, 35.0)
	_watched_for = 0.0


func _pounce(at: Vector3) -> void:
	mode = Mode.POUNCE
	_point = at
	_pounces += 1
	velocity.x = 0.0
	velocity.z = 0.0
	fox.pounce(at)


# --- Taking things ---

## Now and then, what lies near `who` that it could carry off.
func _try_steal(who: Node3D) -> void:
	if _steal_in > 0.0:
		return
	_steal_in = _rng.randf_range(steal_every * 0.6, steal_every * 1.4)
	var best: Node3D = null
	var nearest := 18.0
	for item: Node in get_tree().get_nodes_in_group(&"loot"):
		var thing := item as Node3D
		if not _can_take(thing):
			continue
		var apart := thing.global_position.distance_to(global_position)
		var from_them := thing.global_position.distance_to(who.global_position)
		# (not from under their feet: a few metres off them, and where they would see it go)
		if apart < nearest and from_them > 3.0 and from_them < 22.0:
			nearest = apart
			best = thing
	if best:
		loot_item = best
		mode = Mode.STEAL


func _can_take(item: Node3D) -> bool:
	if item == null or not is_instance_valid(item) or not item.is_inside_tree():
		return false
	if item.get(&"loot_state") != 0 or item.get(&"lit") == true:
		return false
	return int(item.get(&"kind")) in STEALS


## Takes `item` in its jaws, and makes off with it, away from `who`.
func _take(item: Node3D, who: Node3D) -> void:
	loot_item = item
	mode = Mode.CARRY
	_timer = _rng.randf_range(12.0, 20.0)
	var away := global_position - (who.global_position if who else global_position - global_basis.z)
	away.y = 0.0
	_carry_to = global_position + away.normalized() * _rng.randf_range(20.0, 32.0)
	if tame:
		_carry_to = home + (_carry_to - home).limit_length(home_range)


## Whether what it carries is still its to carry (somebody may have taken it from its jaws).
func _still_held() -> bool:
	return loot_item != null and is_instance_valid(loot_item) and loot_item.get(&"loot_state") == 0


## What it carries, held in its jaws.
func _carry_held() -> void:
	if fox == null:
		return
	fox.carrying = mode == Mode.CARRY and _still_held()
	if fox.carrying:
		loot_item.global_position = fox.jaw_position() + Vector3.DOWN * 0.03


## Lets go of what it carries: it lies where it falls (everyone is told where).
func _drop() -> void:
	if fox:
		fox.carrying = false
	if not _still_held():
		loot_item = null
		return
	var item := loot_item
	loot_item = null
	var at := item.global_position
	at.y = maze.ground_height(at) if maze else global_position.y
	item.call(&"lay_at", at, facing_yaw + 1.2)
	if puppet:
		return
	var loot := item.get_parent()
	var world_now: Variant = loot.get(&"world") if loot else null
	# (the autoload looked up, not named, so that this compiles in tests run with -s; 255 is Net.BROADCAST)
	var net := get_tree().root.get_node_or_null(^"Net")
	if world_now and world_now.get(&"online") == true and net and net.get(&"is_host") == true:
		var turn := item.global_basis.get_rotation_quaternion()
		net.call(&"send_json", 255, {"loot": "rest", "id": int(item.get(&"loot_id")), "at": [at.x, item.global_position.y, at.z], "turn": [turn.x, turn.y, turn.z, turn.w]})


# --- Its calls ---

## Whether it is night (or dusk) where it is.
func night() -> bool:
	var day: Variant = _world.get(&"day") if _world else null
	if day == null:
		return false
	var hour := float(day.get(&"hour"))
	return hour >= DayCycle.SUNSET - 0.5 or hour < DayCycle.DAWN


func _night_calls(delta: float) -> void:
	_call_in -= delta
	if _call_in > 0.0 or mode in [Mode.POUNCE, Mode.STALK, Mode.CARRY, Mode.FLEE]:
		return
	_call_in = _rng.randf_range(25.0, 55.0)
	if not night():
		return
	if variant == 1 and _rng.randf() < 0.4:
		fox.scream()
		_screams += 1
	else:
		fox.bark()
		_barks += 1


# --- Moving ---

func _wander_way() -> Vector3:
	var other := mate()
	if other and not leads() and not other.dead:
		# (a pair: loosely after the other, a little to one side)
		var behind := other.global_position - Basis(Vector3.UP, other.facing_yaw) * Vector3(1.5, 0.0, 3.0)
		var to := behind - global_position
		to.y = 0.0
		if to.length() < 12.0:
			return _way_toward(behind) if to.length() > 2.0 else Vector3.ZERO
	if tame:
		if not _goal.is_finite() or Vector2(_goal.x - global_position.x, _goal.z - global_position.z).length() < 2.0:
			var round_about := _rng.randf_range(0.0, TAU)
			_goal = home + Vector3(cos(round_about), 0.0, sin(round_about)) * _rng.randf_range(0.0, home_range)
		var to := _goal - global_position
		to.y = 0.0
		return to
	return way(_radius)


func _way_toward(point: Vector3) -> Vector3:
	if tame:
		var to := point - global_position
		to.y = 0.0
		if (global_position + to.normalized() * 2.0).distance_to(home) > home_range * 1.5:
			to = (home - global_position).normalized() * 0.5 + to.normalized()
		return to
	var to := nav.waypoint(global_position, point, MazeNav.clearance_for(_radius)) - global_position
	to.y = 0.0
	return to


## Out of sight it stays near home if it is tame.
func roam_unseen(step: float) -> void:
	if tame:
		return
	super(step)


func _steer(wish: Vector3, speed: float, delta: float, grounded: bool) -> void:
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, acceleration * delta)
	velocity.x = current.x
	velocity.z = current.z
	_move(delta, grounded)


func _move(delta: float, grounded: bool) -> void:
	if not grounded:
		velocity.y -= gravity * delta
	move_and_slide()
	_carry_held()
	_prev_pos = _curr_pos
	_curr_pos = global_position


static func _velocity_of(who: Node3D) -> Vector3:
	var them: Variant = who.get(&"velocity")
	return Vector3(them.x, 0.0, them.z) if them is Vector3 else Vector3.ZERO


static func _forward_of(who: Node3D) -> Vector3:
	var facing: Variant = who.get(&"facing_yaw")
	if facing != null:
		return Vector3(sin(facing), 0.0, cos(facing))
	var moving := _velocity_of(who)
	if moving.length() > 0.2:
		return moving.normalized()
	return Vector3(sin(who.global_rotation.y), 0.0, cos(who.global_rotation.y))


## How square on `who` faces it: 1 looking straight at it, -1 straight away.
func _facing(who: Node3D) -> float:
	var to := global_position - who.global_position
	to.y = 0.0
	if to.length() < 0.01:
		return 1.0
	return _forward_of(who).dot(to.normalized())


# --- What it looks like ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			fox.visible = not far
			fox.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
			if not far:
				fox.settle()
	if _far:
		return
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-10.0 * delta))
	elif mode == Mode.POUNCE:
		var way_now := fox.pounce_way()
		facing_yaw = lerp_angle(facing_yaw, atan2(way_now.x, way_now.z), 1.0 - exp(-14.0 * delta))
	elif heading.length_squared() > 0.04:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))
	elif _point.is_finite() and mode in [Mode.LOOK, Mode.WATCH, Mode.STALK, Mode.FOLLOW]:
		var to := _point - global_position
		facing_yaw = lerp_angle(facing_yaw, atan2(to.x, to.z), 1.0 - exp(-4.0 * delta))
	fox.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	fox.rotation = Vector3(0.0, facing_yaw, 0.0)
	fox.grounded = is_on_floor() or puppet
	fox.tracking = mode in [Mode.SNIFF, Mode.EAT]
	fox.stalking = mode == Mode.STALK
	fox.sitting = mode == Mode.WATCH
	fox.listening = mode == Mode.LISTEN
	fox.look_at_point = _point if mode in [Mode.LOOK, Mode.FOLLOW, Mode.WATCH, Mode.STALK, Mode.SLIP] else Vector3.INF


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Barks (low four bits) and screams (the rest), as counts.
func net_flag() -> int:
	return (_barks & 0x0f) | ((_screams & 0x0f) << 4)


## Where it looks or pounces; carrying, which thing it carries (its loot number, far under it).
func net_point() -> Vector3:
	if mode == Mode.CARRY and _still_held():
		return global_position + Vector3(0.0, -500.0 - int(loot_item.get(&"loot_id")), 0.0)
	if mode == Mode.POUNCE:
		return fox.pounce_spot()
	return _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	var was := mode
	mode = state as Mode
	var barks := flag & 0x0f
	var screams := (flag >> 4) & 0x0f
	if mode == Mode.CARRY and point.is_finite():
		var id := roundi(at.y - point.y - 500.0)
		if loot_item == null or int(loot_item.get(&"loot_id")) != id:
			loot_item = _loot_numbered(id)
		_point = Vector3.INF
	else:
		if was == Mode.CARRY:
			_drop()
		_point = point
	if not _heard_flagged:
		_heard_flagged = true
	elif fox:
		if barks != (_barks & 0x0f):
			fox.bark()
		if screams != (_screams & 0x0f):
			fox.scream()
		if mode == Mode.POUNCE and was != Mode.POUNCE and point.is_finite():
			fox.pounce(point)
	_barks = barks
	_screams = screams


func _loot_numbered(id: int) -> Node3D:
	for item: Node in get_tree().get_nodes_in_group(&"loot"):
		if int(item.get(&"loot_id")) == id:
			return item as Node3D
	return null


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if fox:
		fox.global_position = at
		fox.settle()


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4

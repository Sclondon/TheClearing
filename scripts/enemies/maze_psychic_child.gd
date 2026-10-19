class_name MazePsychicChild
extends MazeEnemy
## A psychic child loose in the maze (creatures/psychic_child: PsychicChild is
## how she looks and moves; this is what she does). She hunts nobody. She is
## not hostile, but she is dangerous, and she is the one thing in the maze that
## will stand between you and what hunts it.
##
## - SHE DRIFTS about the halls a hand's breadth off the ground, humming, slowly
##   (`drift_speed`), small things going round her in the air.
## - SHE LETS YOU NEAR if you come slowly (walking, ducking). Stay near her and
##   calm (within `watch_range`, not running) for `follow_after` seconds and she
##   takes to you, like a lost child: she follows you (`follow_gap` behind, at
##   most `follow_speed`), and goes back to drifting if you get far ahead of her
##   (`lose_follow`) for a while. Climb up onto a ledge, a terrace or a concrete
##   bridge and she floats up after you, rising slowly beside the wall with the
##   air warping round her, and drifts along the top to you; down again when you
##   get down (MazeEnemy's CLIMBING, FLOAT; the user, 2026-10-18: "the psychic
##   child (floats up with telekinesis?)").
## - SHE WATCHES OVER whoever is calm near her and whoever she follows (her
##   `wards`). Anything that comes after one of them within `protect_range` of
##   her, in her sight, she takes hold of with her mind (GUARD): she turns to it
##   and holds her arm out at it, the air round it warps, and it is lifted off
##   the ground, struggling, held (`guard_hold` seconds) and then dealt with by
##   its size (the world's own measure, Ecology): small ones are slammed down and
##   killed (Ecology.current.kill), middling ones flung far off and left stunned,
##   the biggest stopped where they are and shoved back. Whatever it was after is
##   forgotten. One at a time, `guard_rest` seconds apart.
## - IT COSTS HER. Each hold leaves her `guard_cost` more distressed, and shaken:
##   she does not calm for `shaken_time` after. Several in a row and she breaks.
## - SHE STARTLES. Distress (0..1) builds from anyone sprinting near her
##   (`hear_sprint`), running close by (`hear_run`), being touched or bumped
##   (`touch_range`), a loud thing near (an alarm, a shot, a hard landing), and
##   a hunter right on top of her that she has not dealt with; and it falls away
##   when nothing troubles her (`calm_rate`), faster (`soothe_rate`) while
##   everyone near her is crouched still or backing slowly off. Everyone can see
##   and hear it build: the air warps round her, the things round her race and
##   rise, a high ringing, her hands to her head, a nosebleed.
## - PAST `commit_at` THERE IS NO STOPPING IT (DISTRESS): for `warning_time` it
##   builds to the full, and whoever is right by her then (`lift_range`) she
##   lifts into the air and holds there, struggling; then the BURST: everything
##   within `burst_range` in her sight is flung out from her. Players are thrown
##   limp (a hard throw, not a catch, unless they were held or very near: then
##   it is a catch); creatures near her are killed (within `kill_range`) or
##   flung; loose things are scattered. Then she is DRAINED: she sits on the
##   ground hugging her knees for `drained_time`, and nothing troubles her, and
##   she watches over nobody; then she drifts again, and has forgotten whom she
##   followed.
##
## Online she is run where MazeEnemies is run (the host); a puppet shows what it
## hears: what she is doing (`net_state`), how distressed she is and a count of
## her bursts (`net_flag`), and what she holds or looks at (`net_point`). On
## every machine whoever plays there is lifted and thrown by her there, and what
## she holds is shown held; the catches, kills and throws of creatures are the
## host's alone.

## What she is doing (`net_state`).
enum Mode { DRIFT, FOLLOW, GUARD, UPSET, DISTRESS, BURST, DRAINED }
## What a hold does to what she holds, by its size.
enum Fate { SLAM, FLING, SHOVE }

## The size (Ecology's measure: 0 a hen, 4 the biggest) of each kind she takes
## hold of, for when the world has no Ecology. Kinds not here she leaves alone.
const SIZES := {
	"Apophis": 4, "Abomination": 4, "Centipede": 3, "MazeSpider": 3, "MazeFleshMound": 3, "MazeBaboon": 2,
	"MazeCoyote": 2, "MazeDog": 2, "MazeFishPerson": 2, "MazeFrog": 2, "MazeGhoul": 2, "MazeSkinwalker": 2,
	"MazeBoar": 3, "MazeElk": 3, "MazeDeer": 2, "Mummy": 2, "Alien": 2, "MazeGargoyle": 3,
}
## Flocks that a burst sends up in a panic instead.
const FLOCKS := ["Chickens", "Bats", "Crows"]

@export_group("Going about")
@export var drift_speed := 0.55
@export var follow_speed := 1.5
## How long someone must stay near her and calm before she follows them, seconds.
@export var follow_after := 5.0
## How near counts as near her, metres (and whom she watches over).
@export var watch_range := 8.0
@export var follow_gap := 2.2
## Further ahead of her than this for `lose_time` seconds, and she stops following.
@export var lose_follow := 16.0
@export var lose_time := 5.0
@export_group("Watching over")
@export var protect_range := 18.0
@export var guard_hold := 1.3
@export var guard_rest := 2.0
@export var guard_cost := 0.22
@export var shaken_time := 5.0
@export_group("Distress")
@export var commit_at := 0.6
@export var warning_time := 1.5
@export var calm_rate := 0.2
@export var soothe_rate := 0.5
@export var hear_sprint := 9.0
@export var hear_run := 4.0
@export var touch_range := 0.7
@export var startle_near := 4.5
@export_group("The burst")
@export var burst_range := 10.0
@export var lift_range := 2.4
@export var kill_range := 6.0
## Thrown players: how hard (newton-seconds, near her and at the edge of it).
@export var throw_hard := Vector2(85.0, 40.0)
@export var drained_time := 9.0
@export_group("")
## Further than this from every player she is not posed (the walls hide her).
@export var pose_range := 70.0
@export var gravity := 24.0

var mode := Mode.DRIFT
var facing_yaw := 0.0
var figure: PsychicChild
## How distressed she is, 0..1.
var distress := 0.0
## Whom she follows (null: nobody), and whom she watches over now.
var followed: Node3D
var wards: Array = []
## What she has hold of with her mind (null: nothing).
var held_thing: MazeEnemy
## How many times she has taken hold of something, killed with it, and burst (for tests and the dev panel).
var guards := 0
var kills := 0
var bursts := 0

var _radius := 0.22
var _mode_time := 0.0
var _feel_in := 0.0
var _rest := 0.0
var _shaken := 0.0
var _point := Vector3.INF
var _calm_near := {}
var _was_at := {}
var _bumped := {}
var _lost := 0.0
var _shock := 0.0
var _rate := 0.0
var _soothed := false
var _seized: Seized
var _fate := Fate.FLING
var _held_players: Array = []
var _thrown: Array = []
var _hooked := {}
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_bursts := -1
var _gripped: Node
var _gripped_by_point := false
var _held_here: Node
static var _eco_script: Script
static var _eco_looked := false


func _init() -> void:
	sight_range = 0.0
	hear_range = 0.0
	memory = 0.0
	alert_range = 0.0
	spare_time = 4.0
	pack = &"psychic_children"
	climbs = Climbs.FLOAT
	climb_speed = 1.2


func _ready() -> void:
	# (she is solid, as every creature is; she goes nowhere by bumping)
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1
	floor_snap_length = 0.4
	var shape := CapsuleShape3D.new()
	shape.radius = _radius
	shape.height = 0.95
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	figure = PsychicChild.new()
	figure.low_poly = Settings.low_poly
	add_child(figure)
	figure.top_level = true
	facing_yaw = rotation.y
	_prev_pos = global_position
	_curr_pos = global_position
	figure.put(global_position, facing_yaw)
	figure.bursting.connect(_on_bursting)


# --- The world's own life (Ecology, when the world has one) ---

## The world's Ecology now, if the game has one (looked for by name: the game
## may be without it).
static func ecology() -> Object:
	if not _eco_looked:
		_eco_looked = true
		for entry: Dictionary in ProjectSettings.get_global_class_list():
			if entry["class"] == &"Ecology":
				_eco_script = load(entry["path"])
	return _eco_script.get(&"current") if _eco_script else null


static func kind_of(one: Node) -> String:
	var script := one.get_script() as Script
	return String(script.get_global_name()) if script else ""


## How big `one` is (Ecology's measure), or -1 for what she leaves alone.
static func size_of(one: Node) -> int:
	if ecology() != null:
		var kinds: Dictionary = _eco_script.get(&"KINDS")
		if kinds.has(kind_of(one)):
			return int(kinds[kind_of(one)][0])
	return SIZES.get(kind_of(one), -1)


static func _is_dead(one: Node) -> bool:
	return one.get(&"dead") == true


# --- Thinking ---

func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		_puppet_holds()
		return
	if maze == null:
		return
	_mode_time += delta
	_rest -= delta
	_shaken -= delta
	_feel_in -= delta
	if _feel_in <= 0.0:
		_feel_in = 0.1
		_look_about(0.1)
	# (whom she follows gone up on a ledge: she floats up after them)
	if (climbing_now() or mode == Mode.FOLLOW) and _ways_up(delta, _radius, follow_speed * 1.5):
		facing_yaw = aloft_yaw()
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	var wish := Vector3.ZERO
	var speed := 0.0
	match mode:
		Mode.DRIFT, Mode.FOLLOW, Mode.UPSET:
			_feel(delta)
			if mode == Mode.DISTRESS:
				pass
			elif distress > 0.12:
				mode = Mode.UPSET
			else:
				mode = Mode.FOLLOW if followed else Mode.DRIFT
				if mode == Mode.FOLLOW:
					var to := followed.global_position - global_position
					to.y = 0.0
					if to.length() > follow_gap:
						wish = way(_radius).normalized()
						speed = minf(follow_speed, (to.length() - follow_gap) * 1.2 + 0.3)
				else:
					wish = way(_radius).normalized()
					speed = drift_speed
			# (upset or not, she still watches over them)
			if mode != Mode.DISTRESS and _rest <= 0.0:
				_watch_over()
		Mode.GUARD:
			_feel(delta)
			_guarding()
		Mode.DISTRESS:
			distress = lerpf(commit_at, 1.0, clampf(_mode_time / warning_time, 0.0, 1.0))
			_lift_near()
			if _mode_time >= warning_time:
				_burst()
		Mode.BURST:
			distress = 1.0
			if _mode_time >= PsychicChildRig.BURST:
				followed = null
				_go(Mode.DRAINED)
		Mode.DRAINED:
			distress = maxf(distress - delta * 0.5, 0.0)
			if _mode_time >= drained_time:
				distress = 0.0
				_calm_near.clear()
				_go(Mode.DRIFT)
	chasing = false
	_drive(wish * speed, delta)
	_turn(wish, delta)


func _go(next: Mode) -> void:
	mode = next
	_mode_time = 0.0


## Whom she floats up after: whom she follows (she hunts nobody).
func _climb_after() -> Node3D:
	return followed if mode == Mode.FOLLOW and is_instance_valid(followed) else null


## Up there beside whom she follows: she catches nobody; she stays by them.
func _strike_aloft(_player: Node3D) -> void:
	pass


## Where she is making for: whom she follows, or somewhere to drift to.
func goal() -> Vector3:
	if mode == Mode.FOLLOW and followed and is_instance_valid(followed):
		return followed.global_position
	return super()


func _drive(flat: Vector3, delta: float) -> void:
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(flat, 3.0 * delta)
	velocity.x = current.x
	velocity.z = current.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _turn(wish: Vector3, delta: float) -> void:
	var look := Vector3.ZERO
	if mode == Mode.GUARD and _point.is_finite():
		look = _point - global_position
	elif mode == Mode.FOLLOW and followed and wish == Vector3.ZERO:
		look = followed.global_position - global_position
	elif wish != Vector3.ZERO:
		look = wish
	if Vector2(look.x, look.z).length_squared() < 0.0004:
		return
	var rate := 6.0 if mode == Mode.GUARD else 1.6
	facing_yaw += clampf(angle_difference(facing_yaw, atan2(look.x, look.z)), -rate * delta, rate * delta)


# --- Her senses ---

## How fast someone is going (a Player says; anyone else, from where they were).
func _speed_of(player: Node3D, dt: float) -> Vector3:
	if player is CharacterBody3D:
		return (player as CharacterBody3D).velocity
	var was: Vector3 = _was_at.get(player, player.global_position)
	return (player.global_position - was) / maxf(dt, 0.001)


func _sees(at: Vector3, reach: float) -> bool:
	return nav.sees(global_position + Vector3.UP * 0.8, at, reach)


## Looks about, ten times a second: who is near her and how, whom she watches
## over, whom she takes to, and what troubles her.
func _look_about(dt: float) -> void:
	_rate = 0.0
	_soothed = true
	var near_anyone := false
	var me := global_position
	wards.clear()
	for player: Node3D in players():
		if not is_instance_valid(player) or not player.is_inside_tree() or player.get(&"escaped") == true:
			continue
		_hook(player)
		var moving := _speed_of(player, dt)
		_was_at[player] = player.global_position
		var to := player.global_position - me
		var d := Vector2(to.x, to.z).length()
		var flat_speed := Vector2(moving.x, moving.z).length()
		var sprinting: bool = player.get(&"is_sprinting") == true or flat_speed > 5.0
		var low: bool = player.get(&"is_ducking") == true or player.get(&"is_crawling") == true
		var limp: bool = player.get(&"is_limp") == true
		var seen := d < 3.0 or _sees(player.global_position + Vector3.UP, watch_range + 6.0)
		# What troubles her: someone sprinting near, running close, coming at her while she is upset.
		if not limp:
			if sprinting and d < hear_sprint and (seen or d < 5.0):
				_rate += 2.0 * (1.0 - d / hear_sprint)
			elif flat_speed > 2.8 and d < hear_run:
				_rate += 0.9 * (1.0 - d / hear_run)
			var closing := -Vector2(moving.x, moving.z).dot(Vector2(to.x, to.z).normalized()) if d > 0.01 else 0.0
			if mode == Mode.UPSET and d < watch_range * 0.6 and closing > 0.4:
				_rate += 0.25
			# Touched, or bumped into
			_bumped[player] = maxf(float(_bumped.get(player, 0.0)) - dt, 0.0)
			if d < touch_range and (closing > 1.0 or d < 0.42) and _bumped[player] <= 0.0:
				_bumped[player] = 1.2
				_shock += 0.7
		if d < watch_range:
			near_anyone = true
			# (crouched still near her, or backing slowly off, soothes her)
			var backing := Vector2(moving.x, moving.z).dot(Vector2(to.x, to.z).normalized()) > 0.3 and flat_speed < 2.8
			if not ((low and flat_speed < 0.5) or backing):
				_soothed = false
		# Whom she watches over, and whom she takes to
		var calm := flat_speed < 2.8 and not limp
		if (d < watch_range and seen and calm) or player == followed:
			wards.append(player)
		if mode in [Mode.DRIFT, Mode.FOLLOW] and d < watch_range and seen and calm:
			_calm_near[player] = float(_calm_near.get(player, 0.0)) + dt
		else:
			_calm_near[player] = maxf(float(_calm_near.get(player, 0.0)) - dt * 0.5, 0.0)
		if followed == null and mode == Mode.DRIFT and _calm_near[player] >= follow_after:
			followed = player
	if not near_anyone:
		_soothed = false
	# Whom she follows: lost if they get far ahead for long, or are gone.
	if followed:
		if not is_instance_valid(followed) or not followed.is_inside_tree() or followed.get(&"escaped") == true:
			followed = null
		elif followed.global_position.distance_to(me) > lose_follow:
			_lost += dt
			if _lost > lose_time:
				followed = null
				_lost = 0.0
		else:
			_lost = 0.0
	# A hunter right on top of her, going at a pace, startles her (if she has not got hold of it).
	for other: Node in get_tree().get_nodes_in_group(&"maze_enemies"):
		if other == self or other == held_thing or not (other is MazeEnemy) or other is MazePsychicChild:
			continue
		var enemy := other as MazeEnemy
		if enemy.puppet or _is_dead(enemy) or enemy.process_mode == Node.PROCESS_MODE_DISABLED or not enemy.chasing:
			continue
		var d := enemy.global_position.distance_to(me)
		if d < startle_near and enemy.velocity.length() > 1.5:
			_rate += 1.1 * (1.0 - d / startle_near)


## Her distress: up with what troubles her, down when nothing does (not while she is shaken).
func _feel(delta: float) -> void:
	if _rate > 0.0 or _shock > 0.0:
		distress += _rate * delta + _shock
		_shock = 0.0
	elif _shaken <= 0.0:
		distress -= (soothe_rate if _soothed else calm_rate) * delta
	distress = clampf(distress, 0.0, 1.0)
	if distress >= commit_at:
		_lose_hold(false)
		_go(Mode.DISTRESS)


## Something loud near her (an alarm calls everything about to someone).
func notice(player: Node3D) -> void:
	if puppet or mode in [Mode.DISTRESS, Mode.BURST, Mode.DRAINED]:
		return
	if player and is_instance_valid(player) and player.global_position.distance_to(global_position) < 22.0:
		_shock += 0.3


func alerted(_player: Node3D, _from: Vector3) -> void:
	pass


## Listens for a player's loud doings (a shot, a hard landing) near her.
func _hook(player: Node3D) -> void:
	if _hooked.has(player):
		return
	_hooked[player] = true
	if player.has_signal(&"shot"):
		player.connect(&"shot", func(_kick: float) -> void: _loud(player, 24.0, 0.5))
	if player.has_signal(&"landed"):
		player.connect(&"landed", func(impact: float) -> void:
			if impact > 9.0:
				_loud(player, 6.0, 0.25))


func _loud(player: Node3D, reach: float, how_much: float) -> void:
	if puppet or mode in [Mode.DISTRESS, Mode.BURST, Mode.DRAINED] or not is_instance_valid(player):
		return
	if player.global_position.distance_to(global_position) < reach:
		_shock += how_much


# --- Watching over ---

## Anything after one of her wards, near enough and in her sight: she takes hold of it.
func _watch_over() -> void:
	if wards.is_empty():
		return
	var best: MazeEnemy = null
	var nearest := INF
	for other: Node in get_tree().get_nodes_in_group(&"maze_enemies"):
		if other == self or not (other is MazeEnemy) or other is MazePsychicChild:
			continue
		var enemy := other as MazeEnemy
		if enemy.puppet or _is_dead(enemy) or enemy.process_mode == Node.PROCESS_MODE_DISABLED or size_of(enemy) < 0:
			continue
		if not (enemy.chasing or enemy.hunting()) or not (enemy.quarry in wards):
			continue
		if enemy.get_node_or_null(^"Seized"):
			continue
		var d := enemy.global_position.distance_to(global_position)
		if d > protect_range or not _sees(enemy.global_position + Vector3.UP * 0.8, protect_range):
			continue
		var gap := enemy.global_position.distance_to(enemy.quarry.global_position)
		if gap < nearest:
			nearest = gap
			best = enemy
	if best:
		_seize(best)


func _seize(enemy: MazeEnemy) -> void:
	held_thing = enemy
	guards += 1
	var size := size_of(enemy)
	_fate = Fate.SLAM if size <= 2 else (Fate.FLING if size == 3 else Fate.SHOVE)
	_seized = Seized.new()
	_seized.name = "Seized"
	_seized.lift = 1.3 if _fate == Fate.SLAM else (0.7 if _fate == Fate.FLING else 0.0)
	enemy.add_child(_seized)
	# (whatever it was after is forgotten)
	enemy.quarry = null
	enemy.chasing = false
	distress = minf(distress + guard_cost, 1.0)
	_shaken = shaken_time
	_go(Mode.GUARD)


## Holding it, then dealing with it: slammed down and killed, flung far off, or shoved back.
func _guarding() -> void:
	if mode != Mode.GUARD:
		return
	if held_thing == null or not is_instance_valid(held_thing) or _is_dead(held_thing) or _seized == null or not is_instance_valid(_seized):
		_end_guard()
		return
	_point = held_thing.global_position + Vector3.UP * 0.8
	if not _seized.thrown and _mode_time >= guard_hold:
		var away := held_thing.global_position - global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.1 else Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
		match _fate:
			Fate.SLAM:
				var world := ecology()
				_seized.throw(held_thing.global_position + away * 0.4, 0.18, 0.0, 0.0)
				_seized.landed.connect(func() -> void: _slammed(world), CONNECT_ONE_SHOT)
			Fate.FLING:
				_seized.throw(_landing(held_thing.global_position, away, 9.0), 0.75, 2.2, 3.0)
			Fate.SHOVE:
				_seized.throw(_landing(held_thing.global_position, away, 4.0), 0.4, 0.4, 2.0)
	if _seized.thrown and _mode_time >= guard_hold + 0.9:
		_end_guard()


## A small one slammed down: killed (the world's way, if it has one), else left stunned.
func _slammed(world: Object) -> void:
	if held_thing == null or not is_instance_valid(held_thing):
		return
	figure.thud(held_thing.global_position)
	if world != null and is_instance_valid(world) and held_thing.has_method(&"die"):
		kills += 1
		world.call(&"kill", held_thing, self)
	elif _seized and is_instance_valid(_seized):
		_seized.stun = 3.0


func _end_guard() -> void:
	held_thing = null
	_seized = null
	_point = Vector3.INF
	_rest = guard_rest
	if mode == Mode.GUARD:
		_go(Mode.FOLLOW if followed else Mode.DRIFT)


## Lets go of what she holds (it drops where it is), as she loses herself.
func _lose_hold(_throw: bool) -> void:
	if _seized and is_instance_valid(_seized) and not _seized.thrown:
		_seized.throw(held_thing.global_position - Vector3.UP * _seized.lift if held_thing else Vector3.ZERO, 0.3, 0.0, 1.0)
	held_thing = null
	_seized = null
	_point = Vector3.INF


## Where something flung `far` metres along `away` from `from` comes down: short of any wall.
func _landing(from: Vector3, away: Vector3, far: float) -> Vector3:
	var start := from + Vector3.UP * 1.0
	var end := start + away * far
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start, end, 1))
	if not hit.is_empty():
		end = (hit["position"] as Vector3) - away * 1.2
	if not nav.line_free(from, end, 0.3):
		var step := 0.0
		while step < far and nav.line_free(from, from + away * (step + 1.0), 0.3):
			step += 1.0
		end = from + away * maxf(step - 0.5, 0.0)
	return Vector3(end.x, from.y, end.z)


# --- The burst ---

## Whoever is right by her as it builds, she lifts into the air and holds there.
func _lift_near() -> void:
	for player: Node3D in players():
		if player in _held_players or not is_instance_valid(player) or player.get(&"escaped") == true or player.get(&"is_limp") == true:
			continue
		var to := player.global_position - global_position
		if Vector2(to.x, to.z).length() < lift_range and absf(to.y) < 1.5:
			_held_players.append(player)
			if player is Player:
				hold_up(player as Player, global_position)


func _burst() -> void:
	_go(Mode.BURST)
	bursts += 1
	figure.burst()


## The burst goes out (PsychicChild says when): everything near flung.
func _on_bursting() -> void:
	if puppet:
		return
	var middle := global_position + Vector3.UP * 0.8
	for player: Node3D in players():
		if not is_instance_valid(player) or not player.is_inside_tree() or player.get(&"escaped") == true:
			continue
		var to := player.global_position - global_position
		var d := Vector2(to.x, to.z).length()
		var held := player in _held_players
		if not held and (d > burst_range or not _clear(middle, player.global_position + Vector3.UP)):
			continue
		var catch := held or d < 1.8
		if player is Player:
			throw_off(player as Player, global_position, burst_range, throw_hard)
			if catch:
				_thrown.append(player)
				get_tree().create_timer(1.3).timeout.connect(_land.bind(player))
		elif catch:
			# (a guest is thrown on their own machine; the catch is told them a little after)
			_thrown.append(player)
			get_tree().create_timer(1.8).timeout.connect(_land.bind(player))
	_held_players.clear()
	_burst_creatures(middle)
	scatter_loot(get_tree(), global_position, burst_range)


func _burst_creatures(middle: Vector3) -> void:
	var world := ecology()
	for other: Node in get_tree().get_nodes_in_group(&"maze_enemies"):
		if other == self or not (other is MazeEnemy) or other is MazePsychicChild:
			continue
		var enemy := other as MazeEnemy
		if enemy.puppet or _is_dead(enemy) or enemy.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		var d := enemy.global_position.distance_to(global_position)
		if d > burst_range or not _clear(middle, enemy.global_position + Vector3.UP * 0.6):
			continue
		if kind_of(enemy) in FLOCKS:
			var near := nearest_player(enemy.global_position)
			if near:
				enemy.notice(near)
			continue
		var size := size_of(enemy)
		if size < 0:
			continue
		if enemy.get_node_or_null(^"Seized"):
			continue
		if size <= 3 and d < kill_range and world != null and enemy.has_method(&"die"):
			kills += 1
			world.call(&"kill", enemy, self)
			continue
		var away := enemy.global_position - global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
		var thrown := Seized.new()
		thrown.name = "Seized"
		enemy.add_child(thrown)
		enemy.quarry = null
		var far := (burst_range - d) + (3.0 if size <= 3 else 1.0)
		thrown.throw(_landing(enemy.global_position, away, far), 0.6 if size <= 3 else 0.35, 1.8 if size <= 3 else 0.3, 3.0)


func _clear(from: Vector3, to: Vector3) -> bool:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	return hit.is_empty()


## A held or very near player, come down: stood up, and caught.
func _land(player: Node3D) -> void:
	_thrown.erase(player)
	if not is_instance_valid(player):
		return
	if player is Player and (player as Player).is_limp:
		(player as Player).recover()
	_catch(player)


## Lifts `player` (the one who plays on this machine, or a runner) into the air
## by her at `from`, struggling, until the burst throws him (`throw_off`).
static func hold_up(player: Player, from: Vector3) -> Node:
	var already := player.get_node_or_null(^"PsychicHeld")
	if already:
		return already
	var held := Held.new()
	held.name = "PsychicHeld"
	held.from = from
	player.add_child(held)
	return held


## Throws `player` limp out from `from` (harder the nearer he is), and stands
## him up again a while after if nothing else has.
static func throw_off(player: Player, from: Vector3, reach: float, hard: Vector2) -> void:
	var away := player.global_position - from
	away.y = 0.0
	var d := away.length()
	away = away.normalized() if d > 0.05 else Vector3(1.0, 0.0, 0.0)
	var impulse := (away + Vector3.UP * 0.55).normalized() * lerpf(hard.x, hard.y, clampf(d / reach, 0.0, 1.0))
	var held := player.get_node_or_null(^"PsychicHeld") as Held
	if held:
		held.release(impulse * 1.15)
	else:
		player.ragdoll(impulse)
	player.get_tree().create_timer(2.2).timeout.connect(func() -> void:
		if is_instance_valid(player) and player.is_limp:
			player.recover())


## Loose things lying near `at` (in `reach` and in the open) are scattered out from it.
static func scatter_loot(tree: SceneTree, at: Vector3, reach: float) -> void:
	for node: Node in tree.get_nodes_in_group(&"loot"):
		var item := node as RigidBody3D
		if item == null or not item.has_method(&"fly") or item.get(&"loot_state") != 0:
			continue
		var out := item.global_position - at
		out.y = 0.0
		var d := out.length()
		if d > reach:
			continue
		out = out.normalized() if d > 0.05 else Vector3.RIGHT
		var push := lerpf(11.0, 4.0, d / reach)
		item.call(&"fly", out * push + Vector3.UP * push * 0.45, Vector3(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0), randf_range(-8.0, 8.0)))


# --- What she looks like ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var off := near.global_position.distance_to(global_position) if near else 0.0
		var far := near != null and off > pose_range
		if far != _far:
			_far = far
			figure.visible = not far
			figure.far = far
			if not far:
				figure.put(global_position, facing_yaw)
		figure.pose_rate = 15.0 if off > 25.0 else 0.0
	if _far:
		return
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-8.0 * delta))
		distress = move_toward(distress, (_heard_flag & 63) / 63.0, delta * 2.0)
	figure.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	figure.rotation = Vector3(0.0, facing_yaw, 0.0)
	figure.velocity = Vector3(velocity.x, 0.0, velocity.z) if not puppet else Vector3(_heard_moving.x, 0.0, _heard_moving.z)
	# (floating up or down beside a wall, the air warps round her as it does when she holds something)
	var floating := aloft in [HighClimb.Aloft.CLIMB, HighClimb.Aloft.DOWN]
	figure.distress = (distress if mode != Mode.DRAINED else 0.0) if not floating else maxf(distress, 0.15)
	figure.drained = mode == Mode.DRAINED
	figure.humming = mode in [Mode.DRIFT, Mode.FOLLOW]
	var point := _heard_extra if puppet else net_point()
	figure.reaching = mode == Mode.GUARD and point.is_finite()
	figure.reach_at = point if figure.reaching else Vector3.INF
	figure.aim = point if point.is_finite() and mode != Mode.DRAINED else Vector3.INF


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Her distress (six bits) and a count of her bursts (two).
func net_flag() -> int:
	return clampi(int(distress * 63.0), 0, 63) | ((bursts & 3) << 6)


## What she holds (GUARD), or whom she looks at: the nearest one near her.
func net_point() -> Vector3:
	if mode == Mode.GUARD:
		return _point
	if mode == Mode.DRAINED:
		return Vector3.INF
	var near := followed if followed and is_instance_valid(followed) else nearest_player(global_position)
	if near and near.global_position.distance_to(global_position) < watch_range + 4.0:
		return near.global_position + Vector3.UP * 1.1
	return Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	if state != mode:
		_mode_time = 0.0
	mode = state as Mode
	var count := (flag >> 6) & 3
	if _heard_bursts >= 0 and count != _heard_bursts and figure:
		figure.burst()
		_burst_here()
	_heard_bursts = count


## As a puppet, the burst for whoever plays here: thrown (lifted first, if right by her), and loose things scattered.
func _burst_here() -> void:
	var mine := local_player()
	if mine and mine.get(&"escaped") != true:
		var to := mine.global_position - global_position
		var held := mine.get_node_or_null(^"PsychicHeld") != null
		if held or (Vector2(to.x, to.z).length() < burst_range and _clear(global_position + Vector3.UP * 0.8, mine.global_position + Vector3.UP)):
			throw_off(mine, global_position, burst_range, throw_hard)
	scatter_loot(get_tree(), global_position, burst_range)


## As a puppet: whoever plays here is lifted while she builds to the burst
## beside them; what she holds is shown held (it follows the host's news of where).
func _puppet_holds() -> void:
	if mode == Mode.DISTRESS:
		var mine := local_player()
		if mine and not mine.is_limp and mine.get(&"escaped") != true:
			var to := mine.global_position - global_position
			if Vector2(to.x, to.z).length() < lift_range and absf(to.y) < 1.5:
				hold_up(mine, global_position)
	if mode == Mode.GUARD and _heard_extra.is_finite():
		if _gripped == null or not is_instance_valid(_gripped):
			var best: MazeEnemy = null
			var nearest := 4.0
			for other: Node in get_tree().get_nodes_in_group(&"maze_enemies"):
				if other is MazeEnemy and other != self and not (other is MazePsychicChild):
					var d := (other as Node3D).global_position.distance_to(_heard_extra - Vector3.UP * 0.8)
					if d < nearest:
						nearest = d
						best = other
			if best:
				var grip := Gripped.new()
				grip.name = "Gripped"
				best.add_child(grip)
				_gripped = grip
		if _gripped and is_instance_valid(_gripped):
			(_gripped as Gripped).at = _heard_extra - Vector3.UP * 0.8
	elif _gripped and is_instance_valid(_gripped):
		_gripped.queue_free()
		_gripped = null


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if figure:
		figure.put(at, facing)


func _puppet_changed() -> void:
	# (solid either way: the boy bumps into her)
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1


# --- Holds ---

## What holds a Player she lifts as she builds to the burst: he goes limp and is
## drawn up into the air beside her and held there, struggling (his limbs
## jerking), until the burst throws him (`release`).
class Held extends Node:
	var from := Vector3.ZERO
	var _limbs: Array = []
	var _time := 0.0
	var _kick_in := 0.0
	var _out := Vector3.RIGHT
	var _free := false

	func _ready() -> void:
		var player := get_parent() as Player
		_out = player.global_position - from
		_out.y = 0.0
		_out = _out.normalized() if _out.length() > 0.05 else Vector3.RIGHT
		player.ragdoll(Vector3.UP * 8.0)
		var rig: Node = player.get(&"_rig")
		_limbs = (rig.get(&"_limbs") as Array).duplicate() if rig else []
		for limb: Array in _limbs:
			var body := limb[1] as RigidBody3D
			body.gravity_scale = 0.0
			body.linear_damp = 3.0

	func _physics_process(delta: float) -> void:
		if _free or _limbs.size() < 2:
			return
		_time += delta
		var spine := _limbs[1][1] as RigidBody3D
		var hips := _limbs[0][1] as RigidBody3D
		if not is_instance_valid(spine):
			return
		var rise := smoothstep(0.0, 0.6, _time)
		var hold := from + _out * 1.15 + Vector3.UP * lerpf(0.9, 1.9, rise)
		spine.linear_velocity = spine.linear_velocity.lerp((hold - spine.global_position) * 6.0, 0.6)
		hips.linear_velocity = hips.linear_velocity.lerp((hold - Vector3.UP * 0.4 - hips.global_position) * 5.0, 0.5)
		# (struggling: his arms and legs jerk)
		_kick_in -= delta
		if _kick_in <= 0.0:
			_kick_in = randf_range(0.12, 0.3)
			for k in range(3, _limbs.size()):
				if randf() < 0.5:
					(_limbs[k][1] as RigidBody3D).apply_central_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(-0.6, 1.0), randf_range(-1.0, 1.0)) * 2.2)

	## Thrown: gravity again, and `impulse` through him.
	func release(impulse: Vector3) -> void:
		_free = true
		for limb: Array in _limbs:
			var body := limb[1] as RigidBody3D
			if is_instance_valid(body):
				body.gravity_scale = 1.0
				body.linear_damp = 0.0
				body.linear_velocity = impulse * 0.06
		if _limbs.size() > 1 and is_instance_valid(_limbs[1][1]):
			(_limbs[1][1] as RigidBody3D).apply_central_impulse(impulse * 0.5)
		queue_free()

	func _exit_tree() -> void:
		for limb: Array in _limbs:
			var body := limb[1] as RigidBody3D
			if is_instance_valid(body):
				body.gravity_scale = 1.0
				body.linear_damp = 0.0


## What holds a creature she has hold of with her mind (on the machine that
## runs it): its own doings stopped, it is lifted `lift` metres off the ground,
## struggling (it shakes and turns), until `throw` sends it along an arc to a
## point on the ground; there it lies stunned for `stun` seconds, and then it
## is let go (or it was killed: then it is gone with it).
class Seized extends Node:
	signal landed
	var lift := 1.2
	var stun := 0.0
	var thrown := false
	var _from := Vector3.ZERO
	var _yaw := 0.0
	var _time := 0.0
	var _fly_from := Vector3.ZERO
	var _fly_to := Vector3.ZERO
	var _fly_time := 0.5
	var _arc := 1.0
	var _flown := 0.0
	var _down := false
	var _spin := 0.0

	func _ready() -> void:
		var enemy := get_parent() as MazeEnemy
		_from = enemy.global_position
		_yaw = enemy.yaw()
		enemy.set_physics_process(false)
		enemy.velocity = Vector3.ZERO
		_spin = randf_range(-1.0, 1.0)

	## Sends it to `to` in `seconds`, `arc` metres high; it lies there `stunned` seconds after.
	func throw(to: Vector3, seconds: float, arc: float, stunned: float) -> void:
		var enemy := get_parent() as MazeEnemy
		thrown = true
		_fly_from = enemy.global_position
		_fly_to = to if to != Vector3.ZERO else Vector3(enemy.global_position.x, _from.y, enemy.global_position.z)
		_fly_time = maxf(seconds, 0.05)
		_arc = arc
		_flown = 0.0
		stun = stunned

	func _physics_process(delta: float) -> void:
		var enemy := get_parent() as MazeEnemy
		if enemy == null or enemy.get(&"dead") == true:
			queue_free()
			return
		# (it has forgotten whom it was after, and stays forgetting while she has it)
		enemy.quarry = null
		enemy.chasing = false
		_time += delta
		if not thrown:
			# Held: drawn up, shaking, turning slowly round
			var up := smoothstep(0.0, 0.4, _time) * lift
			var shake := Vector3(sin(_time * 31.0), sin(_time * 27.0 + 1.0) * 0.5, cos(_time * 35.0)) * 0.05 * minf(_time * 3.0, 1.0)
			enemy._put(_from + Vector3.UP * up + shake, _yaw + _spin * _time * 0.8 + sin(_time * 19.0) * 0.08)
			return
		if not _down:
			_flown += delta
			var t := minf(_flown / _fly_time, 1.0)
			var at := _fly_from.lerp(_fly_to, t) + Vector3.UP * sin(PI * t) * _arc
			enemy._put(at, _yaw + _spin * (_time + t * 6.0))
			if t >= 1.0:
				_down = true
				landed.emit()
			return
		stun -= delta
		if stun <= 0.0:
			queue_free()

	func _exit_tree() -> void:
		var enemy := get_parent() as MazeEnemy
		if enemy and enemy.get(&"dead") != true:
			enemy.set_physics_process(true)
			enemy.velocity = Vector3.ZERO


## As a puppet: a creature shown held where the host says it is (`at`), its
## own following stopped meanwhile.
class Gripped extends Node:
	var at := Vector3.INF

	func _ready() -> void:
		get_parent().set_physics_process(false)

	func _physics_process(delta: float) -> void:
		var enemy := get_parent() as MazeEnemy
		if enemy == null or not at.is_finite():
			return
		enemy._put(enemy.global_position.lerp(at, 1.0 - exp(-12.0 * delta)), enemy.yaw())

	func _exit_tree() -> void:
		var enemy := get_parent() as MazeEnemy
		if enemy:
			enemy.set_physics_process(true)

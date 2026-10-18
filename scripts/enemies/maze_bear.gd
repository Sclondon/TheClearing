class_name MazeBear
extends MazeEnemy
## A screaming bear loose in the maze (after the bear of the film Annihilation,
## but its own thing). It is drawn and moved by Bear (creatures/bear/bear.gd);
## this is what it thinks.
##
## ITS VOICE. It cries out with the voice of the last thing it killed: "help!",
## "help... me", "no, no, no!", sobbing; always the same cries in the same
## voice. It calls as it prowls (every `prowl_calls` seconds) and more often as
## it stalks, and its voice carries a long way through the maze (Bear's
## `voice_range`), so it is heard long before it is seen: someone calling for
## help, somewhere. Never go towards the voice. When it kills, it takes the
## voice of whom it killed (`voice`): a player's or a runner's, or an
## animal's shriek for a creature (Ecology).
## PROWLING. It goes slowly about the halls (`prowl_speed`, slower than a
## walk), head low and swinging, stopping now and then to lift its nose and
## sniff the air.
## ITS SENSES. It sees down the halls (`sight_range`), smells anyone close
## (`smell_range`, round a corner or two), and hears anyone sprinting near
## (`hear_running`).
## STALKING. Noticing someone, it comes after them by the passages, slow and
## heavy (`stalk_speed`: faster than a walk, slower than a run), calling and
## sobbing, and keeps after them for `memory` seconds out of sight.
## THE WIND-UP. With them in a straight line within `charge_reach` and in its
## reach, it stops, snaps its jaws, rears up on its hind legs and SCREAMS (its
## stolen scream), then drops onto all fours (REAR_TIME in all: the warning).
## THE CHARGE. It charges at where they were, faster than anyone can sprint
## (`charge_speed`) but only for `charge_time`, able to turn only a little
## (`charge_turn`); within reach it swipes. Then it stands blowing a moment
## (RECOVER) and stalks again.
## THE SWIPE. Close in front of it (`swipe_reach`), it huffs and raises a
## foreleg (SWIPE_WARN, then BearRig.SWIPE_HIT: the warning), then rakes it
## across; whoever the claws reach is flung down and `caught`, and it mauls
## where they fell, then goes quiet a while (`calm_time`) with their voice.
## ESCAPE. Up out of its reach (`reach_up`: a terrace, the ivy, a vine) it
## rears against the wall under you and swipes and screams, and gives up
## (BAFFLED); out of its sight it forgets you; the charge is short, so a
## sprint, a corner, a slot gets away. Step back out of a swipe's reach.
##
## As a puppet it follows the host's news like the others; its voice is in
## its state (`net_state`), and its calls, swipes and screams come as counts in
## its flag and are played here too, the same cries in the same voice.

enum Mode { PROWL, SNIFF, STALK, REAR, CHARGE, SWIPE, MAUL, RECOVER, BAFFLED }

## How much bigger than the model it is drawn (the model stands a metre at the shoulder).
const SCALE := 2.4
## The wind-up of a charge (s): the jaw pops at the start, it is up on its hind
## legs from REAR_UP, screams at SCREAM_AT, and drops at REAR_DOWN.
const REAR_TIME := 1.9
const REAR_UP := 0.15
const SCREAM_AT := 0.4
const REAR_DOWN := 1.45
## Before a swipe from a standstill: a huff and the paw drawn back (s).
const SWIPE_WARN := 0.4
## How long it mauls what it has caught (s).
const MAUL_TIME := 3.0

@export var prowl_speed := 1.2
@export var stalk_speed := 2.9
@export var charge_speed := 6.8
@export var charge_acceleration := 14.0
## How far it can turn charging (radians a second), and standing.
@export var charge_turn := 0.7
@export var turn_rate := 2.2
@export var charge_time := 1.7
## How near someone in a straight line must be for it to rear and charge.
@export var charge_reach := 13.0
## How near in front of it someone must be for it to swipe (m, from its middle).
@export var swipe_reach := 3.8
@export var smell_range := 10.0
@export var hear_running := 16.0
## Higher than this above its feet, it cannot reach them.
@export var reach_up := 3.4
## How long it rears and swipes at someone out of reach before it gives up (s).
@export var baffled_time := 6.0
## After it has caught someone or given up, it pays no heed to anyone for this long.
@export var calm_time := 9.0
## Seconds between its calls, prowling and stalking.
@export var prowl_calls := Vector2(12.0, 20.0)
@export var stalk_calls := Vector2(4.0, 7.0)
## Further than this from every player it is not posed (but its voice still carries).
@export var pose_range := 90.0
@export var gravity := 24.0
@export var size := SCALE

var mode := Mode.PROWL
var facing_yaw := 0.0
var bear: Bear
## Whose voice it has (BearVoice: 0..5 people, 6 an animal).
var voice := 0
var charge_way := Vector3.FORWARD

var _radius := 1.0
var _mode_time := 0.0
var _sniff_in := 6.0
var _call_in := 8.0
var _calm_left := 0.0
var _speed := 0.0
var _point := Vector3.INF
var _thrown: Array = []
var _popped := false
var _screamed := false
var _swung := false
var _struck := false
var _swipe_side := 1.0
var _maul_at := Vector3.INF
var _last_prey: MazeEnemy
var _was_eating := false
var _calls := 0
var _cry := 0
var _swipes := 0
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flagged := false


func _init() -> void:
	sight_range = 30.0
	hear_range = 0.0
	memory = 10.0
	alert_range = 0.0
	pack = &"bears"
	look_every = 0.2
	spare_time = 4.0


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.4
	var shape := CapsuleShape3D.new()
	_radius = 0.4 * size
	shape.radius = _radius
	shape.height = 1.0 * size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	# (someone it killed before anyone came: a voice from the round's seed)
	voice = _rng.randi_range(0, BearVoice.BEAST - 1)
	bear = Bear.new()
	bear.low_poly = Settings.low_poly
	bear.scale = Vector3.ONE * size
	bear.voice = voice
	add_child(bear)
	bear.top_level = true
	facing_yaw = rotation.y
	_prev_pos = global_position
	_curr_pos = global_position
	bear.global_position = global_position
	bear.rotation = Vector3(0.0, facing_yaw, 0.0)
	bear.settle()
	_sniff_in = _rng.randf_range(4.0, 9.0)
	_call_in = _rng.randf_range(3.0, prowl_calls.y)


# --- Its nose and ears ---

## Smells anyone close, and hears anyone sprinting near (round a corner or two).
func _nose() -> void:
	if _look_in < look_every - 0.001 or _calm_left > 0.0:
		return
	var here := maze.cell_at(global_position)
	for player: Node3D in players():
		if not huntable(player):
			continue
		var d := player.global_position.distance_to(global_position)
		var noticed: bool = d < smell_range or (player.get(&"is_sprinting") == true and d < hear_running)
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
		_mode_time += delta
		_puppet_acts()
		return
	if maze == null:
		return
	_calm_left -= delta
	_mode_time += delta
	if _calm_left > 0.0 and not (quarry is MazeEnemy):
		quarry = null
		_forget = 0.0
	else:
		if quarry is MazeEnemy:
			_last_prey = quarry
		_sense(delta)
		_nose()
	_took_prey()
	var grounded := is_on_floor()
	var after := quarry if hunting() and quarry.get(&"is_limp") != true else null
	match mode:
		Mode.PROWL, Mode.SNIFF:
			_prowl(delta, grounded, after)
		Mode.STALK:
			_stalk(delta, grounded, after)
		Mode.REAR:
			_rear(delta, grounded, after)
		Mode.CHARGE:
			_charge(delta, grounded, after)
		Mode.SWIPE:
			_swipe(delta, grounded, after)
		Mode.MAUL:
			_stand(delta, grounded)
			if _mode_time > MAUL_TIME:
				_calm_left = calm_time
				_go(Mode.PROWL)
		Mode.RECOVER:
			_stand(delta, grounded, 6.0)
			if _mode_time > 1.4:
				_go(Mode.STALK if after else Mode.PROWL)
		Mode.BAFFLED:
			_baffled(delta, grounded, after)
	chasing = mode in [Mode.STALK, Mode.REAR, Mode.CHARGE, Mode.SWIPE]
	_calling(delta)


func _go(next: Mode) -> void:
	mode = next
	_mode_time = 0.0


## Its stolen voice, now and then: seldom prowling, often stalking.
func _calling(delta: float) -> void:
	if mode in [Mode.REAR, Mode.SWIPE, Mode.MAUL, Mode.CHARGE]:
		return
	_call_in -= delta
	if _call_in > 0.0:
		return
	var stalking := mode == Mode.STALK or mode == Mode.BAFFLED
	var span := stalk_calls if stalking else prowl_calls
	_call_in = _rng.randf_range(span.x, span.y)
	var which: int = BearVoice.SOB if stalking and _rng.randf() < 0.3 else [BearVoice.CALL_HELP, BearVoice.CALL_HELP_ME, BearVoice.CALL_NO][_rng.randi() % 3]
	if bear.call_out(which, true):
		_calls += 1
		_cry = which


## Killed something (Ecology): it mauls it there, and takes its voice (an animal's).
func _took_prey() -> void:
	var eating := _eating > 0.0
	if eating and not _was_eating:
		var prey := _last_prey
		_maul_at = prey.global_position if prey and is_instance_valid(prey) else global_position + Vector3(sin(facing_yaw), 0.0, cos(facing_yaw)) * 2.0
		_take_voice(BearVoice.BEAST)
		_go(Mode.MAUL)
	_was_eating = eating


func _take_voice(speaker: int) -> void:
	voice = clampi(speaker, 0, BearVoice.SPEAKERS - 1)
	if bear:
		bear.voice = voice


## The voice of a person it has caught: one of the people's, by who they are.
static func voice_of(victim: Node) -> int:
	var seat: Variant = victim.get(&"slot")
	if seat is int:
		return absi(seat as int) % BearVoice.BEAST
	return absi(hash(String(victim.name))) % BearVoice.BEAST


## Prowling about, slow, head low; now and then it stops to sniff; noticing
## someone, it goes after them.
func _prowl(delta: float, grounded: bool, after: Node3D) -> void:
	_point = Vector3.INF
	if after:
		_go(Mode.STALK)
		_call_in = minf(_call_in, 0.6)
		_stand(delta, grounded)
		return
	if mode == Mode.SNIFF:
		_stand(delta, grounded)
		if _mode_time > 2.4:
			_go(Mode.PROWL)
		return
	_sniff_in -= delta
	if _sniff_in <= 0.0:
		_sniff_in = _rng.randf_range(7.0, 13.0)
		bear.sniff()
		_go(Mode.SNIFF)
		return
	var wish := way(_radius)
	_steer(wish.normalized() if wish.length() > 0.01 else Vector3.ZERO, prowl_speed, 2.0, delta, grounded)
	_turn_to(Vector3(velocity.x, 0.0, velocity.z), 1.4, delta)


func _too_high(who: Node3D) -> bool:
	return who.global_position.y - global_position.y > reach_up


func _flat_to(who: Node3D) -> Vector3:
	var to := who.global_position - global_position
	to.y = 0.0
	return to


func _in_line(who: Node3D, reach: float) -> bool:
	var to := _flat_to(who)
	return to.length() < reach and nav.line_free(global_position, who.global_position, _radius * 0.7)


## After them by the passages, slow and heavy, calling; it winds up when it
## has them in a line, and swipes when they are close in front of it.
func _stalk(delta: float, grounded: bool, after: Node3D) -> void:
	if after == null:
		_go(Mode.PROWL)
		return
	_point = after.global_position + Vector3.UP
	if _too_high(after):
		if _flat_to(after).length() < 9.0:
			_go(Mode.BAFFLED)
			return
	elif _flat_to(after).length() < swipe_reach and _in_line(after, swipe_reach):
		_start_swipe(after, SWIPE_WARN)
		return
	elif _in_line(after, charge_reach) and _flat_to(after).length() > swipe_reach + 1.0:
		_start_rear()
		return
	var wish := way(_radius)
	_steer(wish.normalized() if wish.length() > 0.01 else Vector3.ZERO, stalk_speed, 4.0, delta, grounded)
	var to := _flat_to(after)
	_turn_to(to if to.length() < 8.0 and nav.line_free(global_position, after.global_position, 0.0) else Vector3(velocity.x, 0.0, velocity.z), turn_rate, delta)


func _start_rear() -> void:
	_go(Mode.REAR)
	_popped = false
	_screamed = false
	bear.pop_jaw()


## The wind-up: stopped, it snaps its jaws, rears and screams, drops, then charges.
func _rear(delta: float, grounded: bool, after: Node3D) -> void:
	_stand(delta, grounded)
	if after:
		_point = after.global_position + Vector3.UP
	if _point.is_finite():
		_turn_to(_point - global_position, turn_rate, delta)
	if not _screamed and _mode_time >= SCREAM_AT:
		_screamed = true
		bear.scream()
	if _mode_time >= REAR_TIME:
		if after and _too_high(after):
			_go(Mode.BAFFLED)
			return
		var aim := (after.global_position if after else _point) - global_position
		aim.y = 0.0
		charge_way = aim.normalized() if aim.length() > 0.1 else Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
		facing_yaw = atan2(charge_way.x, charge_way.z)
		_speed = 0.0
		_go(Mode.CHARGE)


## Fast and short, turning only a little: within reach, it swipes.
func _charge(delta: float, grounded: bool, after: Node3D) -> void:
	_speed = minf(_speed + charge_acceleration * delta, charge_speed)
	if after:
		var to := _flat_to(after)
		var off := angle_difference(atan2(charge_way.x, charge_way.z), atan2(to.x, to.z))
		var yaw_now := atan2(charge_way.x, charge_way.z) + clampf(off, -charge_turn * delta, charge_turn * delta)
		charge_way = Vector3(sin(yaw_now), 0.0, cos(yaw_now))
		_point = after.global_position + Vector3.UP
		if to.length() < swipe_reach * 0.9 and to.normalized().dot(charge_way) > 0.5 and not _too_high(after):
			_start_swipe(after, 0.0)
			return
	facing_yaw = atan2(charge_way.x, charge_way.z)
	if _wall_ahead(_speed * delta) or _mode_time > charge_time:
		_go(Mode.RECOVER)
		bear.huff()
		return
	_drive(charge_way * _speed, delta, grounded)


func _start_swipe(at: Node3D, warn: float) -> void:
	# (its left, +X in its own space: the side they are on)
	var aside := Vector3(cos(facing_yaw), 0.0, -sin(facing_yaw))
	_swipe_side = 1.0 if _flat_to(at).dot(aside) >= 0.0 else -1.0
	_go(Mode.SWIPE)
	_swung = false
	_struck = false
	# (it starts later by the warning: _mode_time runs from -warn)
	_mode_time = -warn
	if warn > 0.0:
		bear.huff()


## A huff and the paw drawn back (when it was not already charging), then the
## rake across; the claws catch whoever they reach.
func _swipe(delta: float, grounded: bool, after: Node3D) -> void:
	_speed = maxf(_speed - 16.0 * delta, 0.0)
	_drive(Vector3(sin(facing_yaw), 0.0, cos(facing_yaw)) * _speed, delta, grounded)
	if after:
		_point = after.global_position + Vector3.UP
		if _mode_time < BearRig.SWIPE_HIT * 0.6:
			_turn_to(_flat_to(after), turn_rate * 1.5, delta)
	if not _swung and _mode_time >= 0.0:
		_swung = true
		_swipes += 1
		bear.swipe(_swipe_side)
	if _swung and not _struck and _mode_time >= BearRig.SWIPE_HIT:
		_struck = true
		_claws()
		if mode != Mode.SWIPE:
			return
	if _mode_time >= BearRig.SWIPE_TIME + 0.3:
		_go(Mode.RECOVER)


## Whoever the claws reach as they come through is flung down and caught.
func _claws() -> void:
	bear.global_position = global_position
	bear.rotation.y = facing_yaw
	for player: Node3D in players():
		if not huntable(player) or player in _thrown or _too_high(player):
			continue
		var chest := player.global_position + Vector3.UP * 1.0
		# (its bulk and theirs: the claws reach past both bodies)
		if bear.claws_reach(chest, (swipe_reach + 0.4) / size) and nav.line_free(global_position, player.global_position, 0.0):
			_maul(player)
			return


func _maul(player: Node3D) -> void:
	_go(Mode.MAUL)
	_maul_at = player.global_position
	_thrown.append(player)
	# (it takes their voice)
	_take_voice(voice_of(player))
	if player is Player and is_instance_valid(player):
		# Flung down and away to one side by the blow; caught as he lands.
		var ahead := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
		var aside := Vector3(ahead.z, 0.0, -ahead.x) * -_swipe_side
		(player as Player).ragdoll((ahead * 0.6 + aside * 0.8 + Vector3.UP * 0.5).normalized() * 55.0)
		get_tree().create_timer(1.2).timeout.connect(_land.bind(player))
	else:
		_thrown.erase(player)
		_catch(player)


func _land(player: Node3D) -> void:
	_thrown.erase(player)
	if not is_instance_valid(player):
		return
	if player is Player and (player as Player).is_limp:
		(player as Player).recover()
	_catch(player)


## Someone up out of its reach: it rears against the wall under them, swipes
## at the air and screams, and gives up.
func _baffled(delta: float, grounded: bool, after: Node3D) -> void:
	_stand(delta, grounded)
	if after:
		_point = after.global_position + Vector3.UP
		_turn_to(_flat_to(after), turn_rate, delta)
	if not _screamed and _mode_time > 0.5:
		_screamed = true
		bear.scream()
	if fmod(_mode_time, 2.2) < delta and _mode_time > 1.2:
		_swipes += 1
		_swipe_side = -_swipe_side
		bear.swipe(_swipe_side)
	if after and not _too_high(after) and _flat_to(after).length() < swipe_reach:
		_start_swipe(after, SWIPE_WARN)
		return
	if _mode_time > baffled_time or after == null:
		_calm_left = calm_time
		quarry = null
		_forget = 0.0
		_go(Mode.PROWL)


## Whether a wall is just in front of its head (`more` metres more).
func _wall_ahead(more: float) -> bool:
	var from := global_position + Vector3.UP * 0.7 * size
	var reach := 1.0 * size + more + 0.3
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + charge_way * reach, 1, [get_rid()]))
	if not hit.is_empty() and hit["collider"] is StaticBody3D and absf((hit["normal"] as Vector3).y) < 0.5:
		return true
	return not nav.line_free(global_position, global_position + charge_way * reach, 0.0)


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
			# (far off it is not drawn or posed, but its voice still carries: the Bear itself goes on)
			if bear.rig:
				bear.rig.visible = not far
				bear.rig.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
			if not far:
				bear.settle()
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-10.0 * delta))
	bear.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	bear.rotation = Vector3(0.0, facing_yaw, 0.0)
	if _far:
		return
	bear.grounded = is_on_floor() or puppet
	bear.sniffing = mode == Mode.SNIFF
	bear.rearing = (mode == Mode.REAR and _mode_time >= REAR_UP and _mode_time < REAR_DOWN) or (mode == Mode.BAFFLED and _mode_time > 0.3)
	bear.lowered = (mode == Mode.REAR and _mode_time >= REAR_DOWN) or mode == Mode.CHARGE
	bear.mauling = mode == Mode.MAUL and _mode_time > 0.6
	bear.look_at_point = _maul_at if mode == Mode.MAUL else _point if mode in [Mode.STALK, Mode.REAR, Mode.SWIPE, Mode.BAFFLED, Mode.CHARGE] else Vector3.INF


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


## Its mode, and its voice in the high bits.
func net_state() -> int:
	return mode | (voice << 4)


## Calls (two bits) and which cry the last was (three), swipes (two) and the side of the last (one).
func net_flag() -> int:
	return (_calls & 3) | ((_cry & 7) << 2) | ((_swipes & 3) << 5) | ((1 if _swipe_side > 0.0 else 0) << 7)


func net_point() -> Vector3:
	return _maul_at if mode == Mode.MAUL else _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	var now := (state & 15) as Mode
	if now != mode:
		_mode_time = 0.0
		_popped = false
		_screamed = false
		_swung = false
	mode = now
	var heard_voice := (state >> 4) & 15
	if heard_voice != voice:
		_take_voice(heard_voice)
	chasing = mode in [Mode.STALK, Mode.REAR, Mode.CHARGE, Mode.SWIPE]
	_point = point
	if mode == Mode.MAUL:
		_maul_at = point
	var calls := flag & 3
	var cry := (flag >> 2) & 7
	var swipes := (flag >> 5) & 3
	var side := 1.0 if (flag >> 7) & 1 else -1.0
	if not _heard_flagged:
		_heard_flagged = true
	elif bear:
		if calls != (_calls & 3):
			bear.call_out(cry)
		if swipes != (_swipes & 3):
			bear.swipe(side)
	_calls = calls
	_cry = cry
	_swipes = swipes
	_swipe_side = side


## As a puppet: what goes with each mode, played at the same moments as on the host.
func _puppet_acts() -> void:
	if bear == null:
		return
	match mode:
		Mode.REAR:
			if not _popped:
				_popped = true
				bear.pop_jaw()
			if not _screamed and _mode_time >= SCREAM_AT:
				_screamed = true
				bear.scream()
		Mode.BAFFLED:
			if not _screamed and _mode_time > 0.5:
				_screamed = true
				bear.scream()
		Mode.SWIPE:
			if not _swung:
				_swung = true
				bear.huff()


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if bear:
		bear.global_position = at
		bear.settle()


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4

class_name MazeMammoth
extends MazeEnemy
## A herd of woolly mammoths (`herd_of`: a matriarch, cows and a calf,
## MazeMammothCalf) roaming the widest halls and open plains, grazing. Each is
## drawn and moved by Mammoth (creatures/mammoth/mammoth.gd); this is what it
## thinks. The matriarch leads; the others go by what she does.
##
## GRAZING. Peaceful and slow. They graze a while about one place (the trunk
## pulling up the grass), then the matriarch walks on to another and the rest
## follow, the calf at its mother's side. They do not hunt anyone, and the
## herd is in no hurry for anything; but they are enormous, and everything
## else gets out of their way.
## ALARM. Someone (a player, or a hunter) within `alarm_range` of the herd, in
## their sight: they stop, heads up, ears out, trunks raised towards them,
## feeling the air, and the matriarch rumbles (ALERT). Back away and they
## settle again.
## THE RING. Nearer (`ring_range` of the calf or of her) and the herd closes
## round the calf, the cows facing out (RING). The matriarch comes out between
## them and the herd, spreads her ears, throws up her trunk and TRUMPETS
## (DISPLAY), then rushes at them in a MOCK charge, stamping, and pulls up short
## (`mock_stop` from them). That is the warning, and it is loud and long.
## THE CHARGE. Anyone who still comes on (within `charge_range` of the calf or
## of her), or stays in the ring's space after it, she charges in earnest
## (CHARGE): head down, tusks forward, trunk curled up, faster than anyone can
## run (`charge_speed`), and whoever she reaches is trampled (`caught`). She is
## huge and slow to turn (`charge_turn`): step aside at the last moment, climb,
## or get behind something and she thunders past; she gives up any further than
## `chase_range` from the calf, and goes back to the herd. A hunter she reaches
## she knocks flying (Stagger).
##
## In the open (put outside the maze's grid: the desert ring's plains) they go
## by sight and the ground alone, with no passages to follow.
##
## As a puppet it follows the host's news like the others; its trumpets,
## rumbles and stamps come as counts in its flag and are played here too.

enum Mode { GRAZE, MOVE, ALERT, RING, DISPLAY, MOCK, CHARGE, RECOVER, RETURN, FLEE }

## How long one has stayed away (beyond the alarm) for the herd to settle, seconds.
const CALM_TIME := 4.0

@export var walk_speed := 1.1
@export var mock_speed := 4.2
@export var charge_speed := 6.3
@export var charge_acceleration := 5.5
@export var acceleration := 1.6
## How fast it turns (rad/s): about, and charging (a big animal, slow to turn).
@export var turn_rate := 0.85
@export var charge_turn := 0.8
## How near someone must be (to the herd) to alarm it; (to the calf or her) to set off the ring and the warning; to be charged.
@export var alarm_range := 26.0
@export var ring_range := 16.0
@export var charge_range := 11.0
## The mock charge pulls up this far from them, and goes at most `mock_length` m.
@export var mock_stop := 9.0
@export var mock_length := 10.0
## Seconds of the trumpeting display (the first time; again, shorter).
@export var display_time := 2.6
## Seconds at most of a charge; and how far from the calf it gives up.
@export var charge_time := 5.0
@export var chase_range := 26.0
@export var recover_time := 3.0
## How near the front of her must come to catch them (m, at a size of 1).
@export var catch_radius := 1.7
## Higher than this above its feet it cannot reach them.
@export var reach_up := 2.4
## How far from where the herd was put it roams.
@export var roam_range := 45.0
## Further than this from every player it is not posed.
@export var pose_range := 110.0
@export var gravity := 24.0
## How big it is drawn (1: a grown cow, 2.9 m at the shoulder). Set before it enters the tree.
@export var size := 1.0

var mode := Mode.GRAZE
var facing_yaw := 0.0
var mammoth: Mammoth
## The herd: the matriarch leads (`lead`); every one knows her, and she knows them all and the calf.
var lead := false
var matriarch: MazeMammoth
var herd: Array[MazeMammoth] = []
var calf: MazeMammoth
var mother: MazeMammoth
## Whose alarm it is (a player or a hunter), and the herd's mode (the matriarch's say).
var intruder: Node3D
var herd_mode := Mode.GRAZE
var herd_goal := Vector3.INF
## Out on open ground, off the maze's grid.
var in_open := false

var _radius := 1.3
var _home := Vector3.ZERO
var _slot := 0
var _offset := Vector3.ZERO
var _mode_left := 0.0
var _mode_time := 0.0
var _point := Vector3.INF
var _graze_left := 0.0
var _away := 0.0
var _herd_time := 0.0
var _look_left := 0.0
var _warned := {}
var _mock_from := Vector3.ZERO
var _lost_line := 0.0
var _trumpets := 0
var _rumbles := 0
var _stamps := 0
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flagged := false
var _ray: PhysicsRayQueryParameters3D


## A herd of `count` (a matriarch, cows and one calf), linked, from `seed_value`.
static func herd_of(count: int, seed_value: int) -> Array[MazeMammoth]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var made: Array[MazeMammoth] = []
	var leader := MazeMammoth.new()
	leader.lead = true
	leader.size = 1.06
	made.append(leader)
	for i in maxi(count - 2, 1):
		var cow := MazeMammoth.new()
		cow.size = rng.randf_range(0.86, 0.97)
		made.append(cow)
	var young := MazeMammothCalf.new()
	made.append(young)
	for k in made.size():
		var one := made[k]
		one.matriarch = leader
		one._slot = k
	leader.herd = made.duplicate()
	leader.calf = young
	young.mother = made[1] if made.size() > 2 else leader
	for one in made:
		one.calf = young
	return made


func _init() -> void:
	sight_range = 40.0
	hear_range = 10.0
	memory = 5.0
	alert_range = 0.0
	pack = &"mammoths"
	look_every = 0.25
	spare_time = 4.0


func is_calf() -> bool:
	return false


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1
	floor_snap_length = 0.5
	var big := size * (0.42 if is_calf() else 1.0)
	_radius = 1.25 * big
	# (two upright capsules, under the chest and under the rump: it is long)
	for along: float in [0.85, -0.75]:
		var shape := CapsuleShape3D.new()
		shape.radius = 1.1 * big
		shape.height = 3.0 * big
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = Vector3(0.0, shape.height * 0.5, along * big)
		add_child(collider)
	mammoth = Mammoth.new()
	mammoth.calf = is_calf()
	mammoth.low_poly = Settings.low_poly
	mammoth.fur_shells = 0 if Settings.low_poly else 1
	mammoth.scale = Vector3.ONE * (size if not is_calf() else 1.0)
	mammoth.volume_db = -4.0 if not lead else 0.0
	add_child(mammoth)
	mammoth.top_level = true
	facing_yaw = rotation.y
	_home = global_position
	_prev_pos = global_position
	_curr_pos = global_position
	mammoth.global_position = global_position
	mammoth.rotation = Vector3(0.0, facing_yaw, 0.0)
	mammoth.settle()
	in_open = maze != null and not maze.inside(maze.cell_at(_home))
	var round_about := _rng.randf_range(0.0, TAU)
	_offset = Vector3(cos(round_about), 0.0, sin(round_about)) * _rng.randf_range(5.0, 10.0)
	_graze_left = _rng.randf_range(8.0, 20.0)


## The one the herd goes by.
func leader() -> MazeMammoth:
	return matriarch if matriarch and is_instance_valid(matriarch) and not matriarch.dead else self


## The herd's middle: where its calf is (or its leader, with no calf).
func herd_middle() -> Vector3:
	if calf and is_instance_valid(calf) and not calf.dead:
		return calf.global_position
	return leader().global_position


# --- Thinking ---

func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		rotation.y = facing_yaw
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze == null:
		return
	if in_open:
		_ecology(delta)
	else:
		_sense(delta)
	_mode_left -= delta
	_mode_time += delta
	if lead or leader() == self:
		_lead(delta)
	var boss := leader()
	var wish := Vector3.ZERO
	var speed := 0.0
	var turn := turn_rate
	var h_mode := boss.herd_mode
	var who := boss.intruder if boss.intruder and is_instance_valid(boss.intruder) else null
	if self == boss:
		match mode:
			Mode.GRAZE, Mode.MOVE, Mode.ALERT, Mode.RING:
				if h_mode == Mode.MOVE and herd_goal.is_finite():
					mode = Mode.MOVE
					if _flat(herd_goal) > 2.0:
						wish = _way_to(herd_goal)
						speed = walk_speed
				elif h_mode == Mode.ALERT and who:
					_go(Mode.ALERT)
					_point = who.global_position + Vector3.UP * 1.2
				elif h_mode == Mode.RING and who:
					_point = who.global_position + Vector3.UP * 1.2
					_go(Mode.DISPLAY)
					_mode_left = display_time * (1.0 if not _warned.has(who) else 0.55)
					_trumpet()
				else:
					_go(Mode.GRAZE)
					_point = Vector3.INF
			Mode.DISPLAY:
				# Out between them and the herd, ears spread, trunk up, trumpeting.
				if who == null or h_mode != Mode.RING:
					_go(Mode.ALERT)
				else:
					_point = who.global_position + Vector3.UP * 1.2
					var guard := herd_middle() + _flat_way(herd_middle(), who.global_position) * 2.5 * size
					if _flat(guard) > 1.5:
						wish = _way_to(guard)
						speed = walk_speed
					if _mode_left <= 0.0:
						if not _warned.has(who) or not _too_near(who):
							_warned[who] = true
							_go(Mode.MOCK)
							_mock_from = global_position
						else:
							_start_charge()
			Mode.MOCK:
				# A rush at them that pulls up short, stamping.
				if who:
					_point = who.global_position + Vector3.UP * 1.2
					wish = _flat_way(global_position, who.global_position)
					speed = mock_speed
					turn = charge_turn
				var gone := Vector2(global_position.x - _mock_from.x, global_position.z - _mock_from.z).length()
				if who == null or _flat(who.global_position) < mock_stop * size or gone > mock_length or _mode_time > 3.5:
					_go(Mode.RECOVER)
					_mode_left = 2.2
					_stamp()
			Mode.CHARGE:
				var lost := who == null or not _reachable(who)
				if not lost:
					_point = who.global_position + Vector3.UP * 1.2
					wish = _flat_way(global_position, who.global_position)
					if not _clear_line(global_position + Vector3.UP * 1.0, who.global_position + Vector3.UP * 1.0):
						_lost_line += delta
					else:
						_lost_line = 0.0
				speed = charge_speed
				turn = charge_turn
				# (past them, it thunders on and pulls up: it does not come round in a moment)
				var passed := not lost and _mode_time > 0.6 and Vector3(sin(facing_yaw), 0.0, cos(facing_yaw)).dot(_flat_way(global_position, who.global_position)) < -0.1
				if lost or passed or _lost_line > 0.6 or _mode_time > charge_time or _flat(herd_middle()) > chase_range:
					_go(Mode.RECOVER)
					_mode_left = recover_time
				else:
					_trample()
			Mode.RECOVER:
				if who:
					_point = who.global_position + Vector3.UP * 1.2
				if _mode_left <= 0.0:
					if who and h_mode == Mode.RING and _too_near(who):
						# (they came on after the warning: now in earnest, after a short trumpet)
						_go(Mode.DISPLAY)
						_mode_left = display_time * 0.5
						_trumpet()
					else:
						_go(Mode.RETURN)
			Mode.RETURN:
				var back := herd_middle() + _flat_way(herd_middle(), who.global_position if who else herd_middle() + Vector3.FORWARD) * 4.0 * size
				if _flat(back) < 3.0 or _mode_time > 12.0:
					_go(Mode.ALERT if who else Mode.GRAZE)
				else:
					wish = _way_to(back)
					speed = walk_speed * 1.6
	else:
		_follow_herd(boss, h_mode, who)
		# (closing round the calf, they bustle)
		if mode == Mode.RING:
			turn = turn_rate * 1.6
		wish = _wish
		speed = _speed
	chasing = mode in [Mode.DISPLAY, Mode.MOCK, Mode.CHARGE]
	if wish.length() > 0.01:
		wish = Vector3(wish.x, 0.0, wish.z).normalized()
		var push := _apart(_radius)
		if push != Vector3.ZERO and mode not in [Mode.CHARGE, Mode.MOCK]:
			wish = (wish + push * 0.6).normalized()
	elif mode in [Mode.GRAZE, Mode.ALERT, Mode.RING]:
		# (standing, it shifts out of the way of a herd-mate it is pressed against)
		var push := _apart(_radius)
		if push.length() > 0.2:
			wish = push.normalized()
			speed = 0.5
	_drive(wish, speed, turn, delta)


var _wish := Vector3.ZERO
var _speed := 0.0


## A cow or the calf: as the matriarch says.
func _follow_herd(boss: MazeMammoth, h_mode: Mode, who: Node3D) -> void:
	_wish = Vector3.ZERO
	_speed = 0.0
	match h_mode:
		Mode.MOVE:
			_go(Mode.MOVE)
			_point = Vector3.INF
			# (in a loose file behind her)
			var behind := -Vector3(sin(boss.facing_yaw), 0.0, cos(boss.facing_yaw))
			var spot := boss.global_position + behind * (5.0 + 4.0 * _slot) * size + Vector3(behind.z, 0.0, -behind.x) * sin(_slot * 2.3) * 2.0
			if is_calf() and mother and is_instance_valid(mother):
				spot = mother.global_position + Vector3(sin(mother.facing_yaw + 1.6), 0.0, cos(mother.facing_yaw + 1.6)) * 2.6
			if _flat(spot) > 2.0:
				_wish = _way_to(spot)
				_speed = walk_speed * clampf(_flat(spot) / 6.0, 0.6, 1.6)
		Mode.ALERT:
			_go(Mode.ALERT)
			_point = who.global_position + Vector3.UP * 1.2 if who else Vector3.INF
		Mode.RING:
			_go(Mode.RING)
			_point = who.global_position + Vector3.UP * 1.2 if who else Vector3.INF
			if not is_calf() and who:
				# (each to its place round the calf, facing out at them)
				var toward := atan2(who.global_position.x - herd_middle().x, who.global_position.z - herd_middle().z)
				var fan: float = [0.0, -0.75, 0.75, -1.5, 1.5, -2.3, 2.3][clampi(_slot, 0, 6)]
				var spot := herd_middle() + Vector3(sin(toward + fan), 0.0, cos(toward + fan)) * 4.4 * size
				if _flat(spot) > 1.2:
					_wish = _way_to(spot)
					_speed = walk_speed * 2.2
				elif _rng.randf() < 0.002:
					_trumpet()
			elif is_calf() and mother and is_instance_valid(mother):
				# (the calf presses in against its mother, away from them)
				var hide := mother.global_position + _flat_way(who.global_position if who else mother.global_position, mother.global_position) * 2.4
				if _flat(hide) > 1.0:
					_wish = _way_to(hide)
					_speed = walk_speed * 1.4
		_:
			_go(Mode.GRAZE)
			_point = Vector3.INF
			# (grazing about the place, each at its own spot near her)
			_graze_left -= get_physics_process_delta_time()
			if _graze_left <= 0.0:
				_graze_left = _rng.randf_range(10.0, 22.0)
				var round_about := _rng.randf_range(0.0, TAU)
				_offset = Vector3(cos(round_about), 0.0, sin(round_about)) * _rng.randf_range(4.0, 10.0) * size
			var spot := boss.global_position + _offset
			if is_calf() and mother and is_instance_valid(mother):
				spot = mother.global_position + _offset.normalized() * 2.8
			if _flat(spot) > 2.5:
				_wish = _way_to(spot)
				_speed = walk_speed * 0.7


## The matriarch: who is about, and what the herd does.
func _lead(delta: float) -> void:
	_herd_time += delta
	_look_left -= delta
	if _look_left <= 0.0:
		_look_left = look_every
		var found := _nearest_intruder()
		if found:
			intruder = found
			_away = 0.0
		elif intruder:
			_away += look_every
			if _away > CALM_TIME or not is_instance_valid(intruder):
				intruder = null
	if intruder and not is_instance_valid(intruder):
		intruder = null
	if intruder:
		var near := _provoking(intruder, ring_range)
		var was := herd_mode
		herd_mode = Mode.RING if near or (herd_mode == Mode.RING and _provoking(intruder, ring_range * 1.3)) else Mode.ALERT
		if was in [Mode.GRAZE, Mode.MOVE] and herd_mode != was:
			_rumble()
		return
	if herd_mode in [Mode.ALERT, Mode.RING]:
		herd_mode = Mode.GRAZE
		_graze_left = _rng.randf_range(6.0, 12.0)
	if herd_mode == Mode.GRAZE:
		_graze_left -= delta
		if _graze_left <= 0.0:
			herd_mode = Mode.MOVE
			_herd_time = 0.0
			herd_goal = _new_pasture()
	elif herd_mode == Mode.MOVE:
		if not herd_goal.is_finite() or _flat(herd_goal) < 3.0 or _herd_time > 60.0:
			herd_mode = Mode.GRAZE
			_graze_left = _rng.randf_range(20.0, 40.0)


## Somewhere new to graze, within its range.
func _new_pasture() -> Vector3:
	for attempt in 8:
		var round_about := _rng.randf_range(0.0, TAU)
		var spot := _home + Vector3(cos(round_about), 0.0, sin(round_about)) * _rng.randf_range(8.0, roam_range)
		if in_open:
			if _clear_line(global_position + Vector3.UP, spot + Vector3.UP):
				return spot
		else:
			var cell := maze.cell_at(spot)
			if nav.allowed(cell) and nav.distance(maze.cell_at(global_position), cell) >= 0:
				return nav.point(cell)
	return _home


## The nearest player (or hunter) it sees within the alarm of the herd.
func _nearest_intruder() -> Node3D:
	var middle := herd_middle()
	var best: Node3D = null
	var nearest := alarm_range
	var eye := global_position + Vector3.UP * 2.5 * size
	for player: Node3D in players():
		if not _bothered_by(player):
			continue
		var d := _flat_between(player.global_position, middle)
		if d < nearest and (d < hear_range or _sees_point(eye, player.global_position + Vector3.UP, alarm_range + 10.0)):
			nearest = d
			best = player
	if best:
		return best
	# (a hunter near the herd)
	for one: Node in get_tree().get_nodes_in_group(&"maze_enemies"):
		if not (one is MazeEnemy) or one is MazeMammoth:
			continue
		var hunter := one as MazeEnemy
		if hunter.dead or hunter.puppet or Ecology.diet(hunter) != Ecology.Diet.MEAT:
			continue
		var d := _flat_between(hunter.global_position, middle)
		if d < nearest * 0.8 and _sees_point(eye, hunter.global_position + Vector3.UP, alarm_range):
			nearest = d
			best = hunter
	if threat and is_instance_valid(threat) and not threat.dead:
		return threat
	return best


## Whether someone may alarm it: about, on the ground near enough, not down or out or just caught.
func _bothered_by(player: Node3D) -> bool:
	if not in_open:
		return huntable(player)
	if not is_instance_valid(player) or not player.is_inside_tree():
		return false
	if player.get(&"escaped") == true or player.get(&"is_limp") == true:
		return false
	return not (_spared.has(player) and _spared[player] > 0.0)


## Whether `who` is within `reach` of the calf or of her (and low enough to reach).
func _provoking(who: Node3D, reach: float) -> bool:
	if who.global_position.y - global_position.y > reach_up * size:
		return false
	return _flat_between(who.global_position, herd_middle()) < reach or _flat(who.global_position) < reach


## Whether `who` has come on too near after the warning: near the calf, or right up to her
## (her own rush does not count: she has to be come at).
func _too_near(who: Node3D) -> bool:
	if who.global_position.y - global_position.y > reach_up * size:
		return false
	return _flat_between(who.global_position, herd_middle()) < charge_range or _flat(who.global_position) < 4.5 * size


func _reachable(who: Node3D) -> bool:
	if not is_instance_valid(who):
		return false
	if who is MazeEnemy:
		return not (who as MazeEnemy).dead
	if not _bothered_by(who):
		return false
	var up := who.global_position.y - global_position.y
	return up < reach_up * size and up > -3.0


func _start_charge() -> void:
	_go(Mode.CHARGE)
	_lost_line = 0.0
	_trumpet()


## Charging: whoever is in front of her is trampled; a hunter, knocked flying.
func _trample() -> void:
	if Vector2(velocity.x, velocity.z).length() < 2.5:
		return
	var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	var front := global_position + forward * 1.9 * size
	var who := leader().intruder
	if who is MazeEnemy:
		var other := who as MazeEnemy
		if _flat_between(other.global_position, front) < catch_radius * size + Ecology.reach(other) * 0.6:
			Stagger.hit(other, forward)
			leader().intruder = null
			_go(Mode.RECOVER)
			_mode_left = recover_time
		return
	for player: Node3D in players():
		if not _bothered_by(player):
			continue
		var at := player.global_position
		if at.y - global_position.y > reach_up * size:
			continue
		var near := minf(_flat_between(at, front), _flat(at) - _radius * 0.6)
		if near < catch_radius * size:
			_catch(player)
			_go(Mode.RECOVER)
			_mode_left = recover_time
			return


func _trumpet() -> void:
	_trumpets += 1
	mammoth.trumpet()


func _rumble() -> void:
	_rumbles += 1
	mammoth.rumble()


func _stamp() -> void:
	_stamps += 1
	mammoth.stamp()


func _go(next: Mode) -> void:
	if next != mode:
		mode = next
		_mode_time = 0.0


func _flat(at: Vector3) -> float:
	return _flat_between(at, global_position)


static func _flat_between(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _flat_way(from: Vector3, to: Vector3) -> Vector3:
	var way := Vector3(to.x - from.x, 0.0, to.z - from.z)
	return way.normalized() if way.length() > 0.01 else Vector3.FORWARD


# --- Finding its way: by the passages in the maze, by sight and feel in the open ---

func _way_to(target: Vector3) -> Vector3:
	if not in_open:
		return nav.waypoint(global_position, target, MazeNav.clearance_for(_radius * 0.7)) - global_position
	var way := _flat_way(global_position, target)
	# (feeling ahead for a wall: it bears away along it)
	if not _clear_line(global_position + Vector3.UP, global_position + Vector3.UP + way * 5.0 * size):
		for turn: float in [0.6, -0.6, 1.2, -1.2, 1.9, -1.9]:
			var other := way.rotated(Vector3.UP, turn)
			if _clear_line(global_position + Vector3.UP, global_position + Vector3.UP + other * 5.0 * size):
				return other
	return way


func _clear_line(a: Vector3, b: Vector3) -> bool:
	if not in_open:
		return nav.line_free(a, b, 0.3)
	return not _hits(a, b)


func _sees_point(a: Vector3, b: Vector3, reach: float) -> bool:
	if _flat_between(a, b) > reach:
		return false
	if not in_open:
		return nav.sees(a, b, reach)
	return not _hits(a, b)


func _hits(a: Vector3, b: Vector3) -> bool:
	if not is_inside_tree():
		return false
	if _ray == null:
		_ray = PhysicsRayQueryParameters3D.new()
		_ray.collision_mask = 1
	_ray.from = a
	_ray.to = b
	return not get_world_3d().direct_space_state.intersect_ray(_ray).is_empty()


## Where it is making for (for the world's life, asleep): the herd's pasture.
func goal() -> Vector3:
	var boss := leader()
	if boss.herd_goal.is_finite():
		return boss.herd_goal
	return boss.global_position + _offset


func _drive(wish: Vector3, speed: float, turn: float, delta: float) -> void:
	var rate := charge_acceleration if mode in [Mode.CHARGE, Mode.MOCK] else acceleration * (3.0 if mode == Mode.RECOVER else 1.0)
	var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	if wish != Vector3.ZERO:
		facing_yaw += clampf(angle_difference(facing_yaw, atan2(wish.x, wish.z)), -turn * delta, turn * delta)
		forward = Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	elif _point.is_finite():
		var to := _point - global_position
		if Vector2(to.x, to.z).length() > 1.0:
			facing_yaw += clampf(angle_difference(facing_yaw, atan2(to.x, to.z)), -turn_rate * delta, turn_rate * delta)
	var along := clampf(forward.dot(wish) if wish != Vector3.ZERO else 0.0, 0.0, 1.0)
	# (it can shuffle round on the spot, but it goes the way it faces)
	var target := forward * speed * maxf(along, 0.15 if wish != Vector3.ZERO else 0.0)
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, rate * delta)
	velocity.x = current.x
	velocity.z = current.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	rotation.y = facing_yaw
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


# --- What it looks like ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		# (beyond 45 m, posed every other frame: half the work, and the mist softens it)
		if mammoth.rig:
			mammoth.rig.every = 2 if near != null and near.global_position.distance_to(global_position) > 45.0 else 1
		if far != _far:
			_far = far
			mammoth.visible = not far
			mammoth.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
			if not far:
				mammoth.settle()
	if _far:
		return
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-8.0 * delta))
	mammoth.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	mammoth.rotation = Vector3(0.0, facing_yaw, 0.0)
	mammoth.grounded = is_on_floor() or puppet
	var slow := Vector2(velocity.x, velocity.z).length() < 0.3
	mammoth.grazing = mode == Mode.GRAZE and slow
	mammoth.alert = mode in [Mode.ALERT, Mode.RING, Mode.RECOVER, Mode.DISPLAY]
	mammoth.feeling = mode in [Mode.ALERT, Mode.RING] and _point.is_finite()
	mammoth.ears_out = mode in [Mode.DISPLAY, Mode.MOCK, Mode.RECOVER] or (mode == Mode.RING and not is_calf() and _slot <= 2)
	mammoth.lowered = mode == Mode.CHARGE
	mammoth.look_at_point = _point if mode != Mode.CHARGE else Vector3.INF


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Trumpets (bits 0-1), rumbles (2-3), stamps (4-5).
func net_flag() -> int:
	return (_trumpets & 3) | ((_rumbles & 3) << 2) | ((_stamps & 3) << 4)


func net_point() -> Vector3:
	return _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	if state != mode:
		_mode_time = 0.0
	mode = state as Mode
	chasing = mode in [Mode.DISPLAY, Mode.MOCK, Mode.CHARGE]
	_point = point
	var trumpets := flag & 3
	var rumbles := (flag >> 2) & 3
	var stamps := (flag >> 4) & 3
	if not _heard_flagged:
		_heard_flagged = true
	elif mammoth:
		if trumpets != (_trumpets & 3):
			mammoth.trumpet()
		if rumbles != (_rumbles & 3):
			mammoth.rumble()
		if stamps != (_stamps & 3):
			mammoth.stamp()
	_trumpets = trumpets
	_rumbles = rumbles
	_stamps = stamps


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	rotation.y = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if mammoth:
		mammoth.global_position = at
		mammoth.settle()


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4

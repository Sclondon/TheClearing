class_name MazeWoodsman
extends MazeEnemy
## The woodsman (the user, 2026-10-18: "Lets add a woodsmen with an axe and top
## hat and lantern", after Over the Garden Wall): a tall, gaunt, weary old man in a
## long coat and a battered top hat, an axe over his shoulder and an oil lantern
## held out before him. He is drawn and moved by Woodsman (creatures/woodsman/);
## this is what he thinks. He is not a monster, and not a friend: he keeps to
## himself, and keeps the dark back.
##
## - HE WALKS the halls of his section slowly (`walk_speed`, slower than anyone
##   walks), stopping now and then to look about, and every so often (`chop_every`)
##   goes to the ivy on a wall near him (or a bare wall) and chops at it with his
##   axe, three blows (CHOP).
## - HIS LANTERN keeps the hunters back: whatever of the maze's creatures goes on
##   the ground at a size short of the biggest (Ecology's measure, under 4) cannot
##   go after anyone within `light_radius` of it (MazeEnemy.huntable asks `lit`).
##   So it is safe to walk near him: but not too near.
## - HE IS WARY OF STRANGERS. Seeing someone near (`warn_range`), he stops, turns
##   to them, holds his lantern up at them and grunts (WARN, `warn_time`): the
##   warning. Then he goes on his way, watching them, the lantern up while they are
##   near.
## - BOTHER HIM and he swings. Come within `bother_range` of him, or run at him,
##   and he comes after you (FOLLOW: `follow_speed`, slower than a run) for at
##   most `follow_most` seconds; within `swing_reach` in front of him he raises
##   the axe high over his head (SWING: `wind_time`, the warning) and brings it
##   down: whoever is still in front of him within reach is caught. Then he
##   turns away (REST) and lets you be for `calm_time`. Step back out of reach
##   while the axe is up, or run (he gives up past `give_up`).
## - HE HUNTS THE BEAST. Seeing the beast (MazeBeast) within `beast_sight`, he
##   turns on it, holds his lantern up at it and strides at it (HUNT): it cannot
##   abide his light, and goes.
##
## Online he is run where MazeEnemies is run (the host); a puppet shows what it
## hears: what he is doing (`net_state`), counts of his chops, swings and warnings
## and whether the axe has come down (`net_flag`), and what he looks at
## (`net_point`).

enum Mode { WALK, PAUSE, GO_CHOP, CHOP, WARN, FOLLOW, SWING, REST, HUNT }

## Everyone near whose light keeps the hunters back.
const GROUP := &"woodsman_lanterns"

@export var walk_speed := 1.05
@export var follow_speed := 2.7
@export var hunt_speed := 2.2
@export var acceleration := 6.0
@export var turn_rate := 3.5
## How far his lantern's light keeps the hunters back, metres.
@export var light_radius := 7.5
## Warns whoever comes this near, metres; holds the warning this long, seconds.
@export var warn_range := 11.0
@export var warn_time := 2.4
## Comes after whoever comes this near him, metres (or runs at him from within twice it).
@export var bother_range := 3.4
## Swings at whoever is this near in front of him, metres; holds the axe up this long first.
@export var swing_reach := 2.1
@export var wind_time := 0.8
## The axe catches whoever is within this of where it comes down, metres.
@export var strike_reach := 2.4
## How long he goes after someone at most, and how far off they must get for him to give up.
@export var follow_most := 8.0
@export var give_up := 12.0
## How long he lets everyone be after a swing, seconds.
@export var calm_time := 7.0
## How often he goes to chop at the ivy, seconds (the least and most between).
@export var chop_every := Vector2(18.0, 40.0)
## How far off he sees the beast, metres.
@export var beast_sight := 30.0
## Further than this from the camera he is not posed (the walls hide him).
@export var pose_range := 90.0
@export var gravity := 24.0

var mode := Mode.WALK
var facing_yaw := 0.0
var figure: Woodsman

var _radius := 0.3
var _mode_time := 0.0
var _point := Vector3.INF
var _raise := 0.0
var _chop_in := 20.0
var _chop_at := Vector3.INF
var _chop_face := Vector3.ZERO
var _calm := 0.0
var _warned := {}
var _pause_in := 12.0
var _struck := false
var _swing_at: Node3D
var _beast: Node3D
var _beast_in := 0.0
var _chops := 0
var _swings := 0
var _warns := 0
var _down := false
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flagged := false


func _init() -> void:
	sight_range = 24.0
	hear_range = 5.0
	memory = 5.0
	pack = &"woodsmen"
	look_every = 0.25


func _enter_tree() -> void:
	super()
	add_to_group(GROUP)
	if not _all.has(self):
		_all.append(self)


func _exit_tree() -> void:
	_all.erase(self)


## Every woodsman in the tree (kept, not looked up: `lit` is asked by every hunter
## for everyone it would go after, every time it looks about).
static var _all: Array[MazeWoodsman] = []


## Whether `point` is within the light of a woodsman's lantern (any, alive).
static func lit(tree: SceneTree, point: Vector3) -> bool:
	if tree == null:
		return false
	for man: MazeWoodsman in _all:
		if not is_instance_valid(man) or man.dead or not man.is_inside_tree():
			continue
		var at := man.global_position + Vector3.UP * 1.2
		if absf(point.y - at.y) < 4.5 and Vector2(point.x - at.x, point.z - at.z).length() < man.light_radius:
			return true
	return false


## The nearest woodsman to `point` within `reach` (null: none).
static func nearest(tree: SceneTree, point: Vector3, reach: float) -> MazeWoodsman:
	var best: MazeWoodsman = null
	var far := reach
	for man: MazeWoodsman in _all:
		if not is_instance_valid(man) or man.dead or not man.is_inside_tree():
			continue
		var d := man.global_position.distance_to(point)
		if d < far:
			far = d
			best = man
	return best


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	shape.radius = _radius
	shape.height = 1.9
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.95
	add_child(collider)
	figure = Woodsman.new()
	figure.low_poly = Settings.low_poly
	add_child(figure)
	figure.top_level = true
	facing_yaw = rotation.y
	_prev_pos = global_position
	_curr_pos = global_position
	figure.put(global_position, facing_yaw)
	figure.chopped.connect(func() -> void: _chops += 1)
	_chop_in = _rng.randf_range(4.0, chop_every.x)


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
	_mode_time += delta
	_calm -= delta
	for who: Variant in _warned.keys():
		_warned[who] -= delta
		if _warned[who] <= 0.0 or not is_instance_valid(who):
			_warned.erase(who)
	var grounded := is_on_floor()
	var near := _nearest_near()
	chasing = mode in [Mode.FOLLOW, Mode.SWING]
	match mode:
		Mode.SWING:
			_steer(Vector3.ZERO, 0.0, delta, grounded)
			if is_instance_valid(_swing_at):
				_point = _swing_at.global_position + Vector3.UP * 0.9
			if not _down and _mode_time >= wind_time:
				_down = true
				figure.aim = _point
				figure.strike()
			if _down and not _struck and _mode_time >= wind_time + WoodsmanRig.STRIKE * 0.8:
				_struck = true
				_strike()
			if _mode_time >= wind_time + WoodsmanRig.STRIKE + WoodsmanRig.THROUGH:
				_calm = calm_time
				_set_mode(Mode.REST)
			return
		Mode.CHOP:
			_steer(Vector3.ZERO, 0.0, delta, grounded)
			if not figure.busy() and _mode_time > 0.3:
				_chop_in = _rng.randf_range(chop_every.x, chop_every.y)
				_set_mode(Mode.WALK)
			elif near and _bothered(near):
				figure.cancel()
				_go_after(near)
			return
		Mode.WARN:
			_steer(Vector3.ZERO, 0.0, delta, grounded)
			if near:
				_point = near.global_position + Vector3.UP * 1.0
			if near and _bothered(near):
				_go_after(near)
			elif _mode_time >= warn_time:
				_set_mode(Mode.WALK)
			return
		Mode.REST:
			# (he turns away, and stands a moment before he goes on)
			_steer(Vector3.ZERO, 0.0, delta, grounded)
			_point = Vector3.INF
			if _mode_time > 1.6:
				_set_mode(Mode.WALK)
			return
		Mode.PAUSE:
			_steer(Vector3.ZERO, 0.0, delta, grounded)
			# (looking about: down the hall one way, then the other)
			var round_to := facing_yaw + sin(_mode_time * 0.7) * 1.1
			_point = global_position + Vector3(sin(round_to), 0.0, cos(round_to)) * 8.0 + Vector3.UP * 1.4
			if _mode_time > 4.0:
				_point = Vector3.INF
				_set_mode(Mode.WALK)
	# The beast, in his sight: he goes for it with his light. (Looked for as often as he looks about.)
	_beast_in -= delta
	if _beast_in <= 0.0:
		_beast_in = look_every
		_beast = _beast_seen()
	var beast := _beast if is_instance_valid(_beast) and (_beast as MazeBeast).shown() else null
	if beast and mode != Mode.HUNT and mode != Mode.FOLLOW:
		_warns += 1
		figure.grunt()
		_set_mode(Mode.HUNT)
	if mode == Mode.HUNT:
		if beast == null or _mode_time > 14.0:
			_set_mode(Mode.WALK)
		else:
			_point = beast.global_position + Vector3.UP * 2.0
			var to := beast.global_position - global_position
			to.y = 0.0
			var wish := _way_to(beast.global_position) if to.length() > 3.0 else Vector3.ZERO
			_steer(wish.normalized() if wish.length() > 0.01 else Vector3.ZERO, hunt_speed, delta, grounded)
			return
	if mode == Mode.FOLLOW:
		var after := _swing_at
		if not is_instance_valid(after) or not huntable_by_him(after) or _mode_time > follow_most or after.global_position.distance_to(global_position) > give_up:
			_calm = calm_time * 0.5
			_set_mode(Mode.WALK)
		else:
			_point = after.global_position + Vector3.UP * 1.0
			var to := after.global_position - global_position
			to.y = 0.0
			var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
			if to.length() < swing_reach and forward.dot(to.normalized()) > 0.5 and absf(after.global_position.y - global_position.y) < 1.5:
				_swing(after)
				return
			var wish := to if nav.line_free(global_position, after.global_position, _radius) else _way_to(after.global_position)
			_steer(wish.normalized() if wish.length() > 0.01 else Vector3.ZERO, follow_speed, delta, grounded)
			return
	# Walking (and going to chop).
	if near:
		if _bothered(near):
			_go_after(near)
			return
		var d := near.global_position.distance_to(global_position)
		if d < warn_range and not _warned.has(near) and _calm <= 0.0:
			_warned[near] = 25.0
			_warns += 1
			figure.grunt()
			_point = near.global_position + Vector3.UP * 1.0
			_set_mode(Mode.WARN)
			return
		_point = near.global_position + Vector3.UP * 1.0 if d < warn_range else Vector3.INF
	elif mode != Mode.PAUSE:
		_point = Vector3.INF
	if mode == Mode.PAUSE:
		return
	_chop_in -= delta
	if mode == Mode.WALK and _chop_in <= 0.0:
		if _find_chop():
			_set_mode(Mode.GO_CHOP)
		else:
			_chop_in = _rng.randf_range(chop_every.x, chop_every.y) * 0.5
	if mode == Mode.GO_CHOP:
		var to := _chop_at - global_position
		to.y = 0.0
		if to.length() < 0.35 or _mode_time > 25.0:
			if to.length() < 1.5:
				_point = _chop_at + _chop_face * 1.2 + Vector3.UP * 1.3
				figure.aim = _point
				figure.chop()
				_set_mode(Mode.CHOP)
			else:
				_set_mode(Mode.WALK)
			_steer(Vector3.ZERO, 0.0, delta, grounded)
			return
		var wish := to if nav.line_free(global_position, _chop_at, _radius) else _way_to(_chop_at)
		_steer(wish.normalized() if wish.length() > 0.01 else Vector3.ZERO, walk_speed, delta, grounded)
		return
	_pause_in -= delta
	if _pause_in <= 0.0:
		_pause_in = _rng.randf_range(14.0, 30.0)
		_set_mode(Mode.PAUSE)
		return
	var wish := way(_radius)
	var push := _apart(_radius)
	if wish.length() > 0.01:
		wish = (wish.normalized() + push * 0.5).normalized()
	_steer(wish, walk_speed, delta, grounded)


func _set_mode(next: Mode) -> void:
	mode = next
	_mode_time = 0.0


## Whether he would go after `who` (players and runners: not other creatures).
func huntable_by_him(who: Node3D) -> bool:
	return huntable(who) and not (who is MazeEnemy)


## The nearest one of the players near him that he sees or hears (MazeEnemy's
## senses: his `quarry`), or null.
func _nearest_near() -> Node3D:
	if quarry and hunting() and huntable_by_him(quarry):
		return quarry
	return null


## Whether `who` is bothering him: right up to him, or running at him.
func _bothered(who: Node3D) -> bool:
	if _calm > 0.0:
		return false
	var to := who.global_position - global_position
	if absf(to.y) > 2.0:
		return false
	to.y = 0.0
	var d := to.length()
	if d < bother_range:
		return true
	var going: Variant = who.get(&"velocity")
	if d < bother_range * 2.0 and going is Vector3:
		var flat := Vector3((going as Vector3).x, 0.0, (going as Vector3).z)
		# (coming straight at him, faster than a walk)
		return flat.length() > 3.0 and flat.normalized().dot(-to.normalized()) > 0.7
	return false


func _go_after(who: Node3D) -> void:
	_swing_at = who
	_warns += 1
	figure.grunt()
	var to := who.global_position - global_position
	to.y = 0.0
	var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	if to.length() < swing_reach and forward.dot(to.normalized()) > 0.3:
		_swing(who)
	else:
		_set_mode(Mode.FOLLOW)


func _swing(who: Node3D) -> void:
	_swing_at = who
	_point = who.global_position + Vector3.UP * 0.9
	_struck = false
	_down = false
	_swings += 1
	figure.aim = _point
	figure.swing()
	_set_mode(Mode.SWING)


## The axe comes down: whoever is in front of him within its reach is caught.
func _strike() -> void:
	var forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	for player: Node3D in players():
		if not is_instance_valid(player) or not huntable_by_him(player):
			continue
		var to := player.global_position - global_position
		if absf(to.y) > 1.8:
			continue
		to.y = 0.0
		if to.length() < strike_reach and (to.length() < 0.8 or forward.dot(to.normalized()) > 0.35):
			_catch(player)
			break


## The beast, if he sees it near (null: not).
func _beast_seen() -> Node3D:
	for node: Node in get_tree().get_nodes_in_group(MazeBeast.GROUP):
		var beast := node as MazeBeast
		if beast == null or not beast.shown() or beast.dead:
			continue
		var eye := global_position + Vector3.UP * 1.7
		if eye.distance_to(beast.global_position) < beast_sight and nav.sees(eye, beast.global_position + Vector3.UP * 1.6, beast_sight):
			return beast
	return null


## Somewhere to chop: the foot of the nearest ivy up a wall near him, or else the
## nearest wall to his side. Sets where to stand and which way the wall is.
func _find_chop() -> bool:
	var best := INF
	for node: Node in NearIndex.near(get_tree(), &"ladders", global_position, 14.0):
		var ivy := node as Ladder
		if ivy == null or not is_instance_valid(ivy):
			continue
		var foot := ivy.stand(ivy.bottom_y())
		var ground := maze.ground_height(foot)
		if absf(ivy.bottom_y() - ground) > 1.2:
			continue
		var into := ivy.facing()
		var stand := foot - into * 0.55
		stand.y = ground
		var d := stand.distance_to(global_position)
		if d < best and nav.allowed(maze.cell_at(stand)) and nav.line_free(global_position, stand, _radius):
			best = d
			_chop_at = stand
			_chop_face = into
	if best < INF:
		return true
	# (no ivy near: a bare wall, to one side of him)
	var space := get_world_3d().direct_space_state
	var eye := global_position + Vector3.UP * 1.2
	var side := Vector3(cos(facing_yaw), 0.0, -sin(facing_yaw))
	for way_now: Vector3 in [side, -side]:
		var query := PhysicsRayQueryParameters3D.create(eye, eye + way_now * 7.0, 1)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit["normal"]
		if absf(normal.y) > 0.3:
			continue
		_chop_at = Vector3((hit["position"] as Vector3).x, global_position.y, (hit["position"] as Vector3).z) + normal * 1.05
		_chop_face = -Vector3(normal.x, 0.0, normal.z).normalized()
		return true
	return false


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


# --- What he looks like ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
		var from := camera.global_position if camera else Vector3.INF
		var far := false
		if from.is_finite():
			far = from.distance_to(global_position) > pose_range
		else:
			var near := nearest_player(global_position)
			far = near == null or near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			figure.visible = not far
			figure.lantern.visible = not far
			figure.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
	if _far:
		return
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	var faces := mode in [Mode.WARN, Mode.SWING, Mode.CHOP, Mode.HUNT, Mode.FOLLOW] and _point.is_finite()
	if puppet and not faces:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-6.0 * delta))
	elif faces:
		var to := _point - global_position
		if Vector2(to.x, to.z).length() > 0.2:
			facing_yaw = lerp_angle(facing_yaw, atan2(to.x, to.z), 1.0 - exp(-(8.0 if mode == Mode.SWING else 3.0) * delta))
	elif mode == Mode.CHOP and _chop_face != Vector3.ZERO:
		facing_yaw = lerp_angle(facing_yaw, atan2(_chop_face.x, _chop_face.z), 1.0 - exp(-4.0 * delta))
	elif heading.length_squared() > 0.04:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))
	figure.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	figure.rotation = Vector3(0.0, facing_yaw, 0.0)
	figure.velocity = heading
	figure.grounded = is_on_floor() or puppet
	figure.aim = _point
	# (the lantern held up at whoever he warns, follows or watches, and at the beast)
	var up := 1.0 if mode in [Mode.WARN, Mode.HUNT, Mode.FOLLOW] else (0.55 if _point.is_finite() and mode == Mode.WALK else 0.0)
	_raise = move_toward(_raise, up, delta * 2.0)
	figure.raise = _raise


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Chops (low two bits), swings (next two), warnings (next two), and whether the
## raised axe has come down (the top bit).
func net_flag() -> int:
	return (_chops & 0x03) | ((_swings & 0x03) << 2) | ((_warns & 0x03) << 4) | ((1 if _down else 0) << 7)


func net_point() -> Vector3:
	return _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point_at := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point_at)
	mode = state as Mode
	chasing = mode in [Mode.FOLLOW, Mode.SWING]
	_point = point_at
	var swings := (flag >> 2) & 0x03
	var warns := (flag >> 4) & 0x03
	var down := (flag >> 7) & 1 == 1
	if not _heard_flagged:
		_heard_flagged = true
	elif figure:
		if warns != (_warns & 0x03):
			figure.grunt()
		if swings != (_swings & 0x03) and mode == Mode.SWING:
			figure.aim = _point
			figure.swing()
			_down = false
		if down and not _down and mode == Mode.SWING:
			figure.strike()
	_down = down
	_swings = swings
	_warns = warns


func _heard_changed(_was: int, now: int, first: bool) -> void:
	if first or figure == null:
		return
	if now == Mode.CHOP:
		figure.aim = _point
		figure.chop()
	elif now != Mode.SWING and figure.doing() == WoodsmanRig.Act.SWING and figure.stage() == WoodsmanRig.Stage.WIND:
		figure.cancel()


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if figure:
		figure.put(at, facing)


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4

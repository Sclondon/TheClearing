class_name MazeWeaver
extends MazeEnemy
## The weaver in the maze. How it looks and moves is Weaver (creatures/weaver/,
## a component of its own); this is only what it thinks.
##
## - IT DRIFTS. Slowly, hanging over the halls (its toes `hover` metres off the
##   floor), by the passages, silent but for the drone of its wings near.
## - IT WEAVES. Every `weave_every` metres it goes, in a hall, it stops (WEAVE,
##   `weave_time`: its six hands draw out threads) and leaves a STRAND across the
##   hall behind it: three pale shining threads wall to wall at chest height
##   (`thread_heights`), at most `strands` of them (the oldest goes). Seeing
##   someone it goes their way and weaves twice as often.
## - CAUGHT IN A STRAND. Walk or run into one upright and you are stuck in it
##   (input gone, the threads dragged round you, a deep twang heard far off).
##   Duck or slide under it and you pass; the act button beside one cuts it.
##   Stuck, every press of jump or act tears at it: `struggle` presses and you
##   are free (the strand snaps). A friend can cut you out.
## - IT COMES. Whoever is stuck, it hears it and comes (COME, `come_speed`,
##   keening as it comes), sinks over them and reaches down with all six hands
##   (REACH, `reach_time`: the warning, still time to tear free), and lifts them
##   away (TAKE, then `caught`). Free before its hands close, and it rises and
##   drifts on (REST).
##
## Online: the host thinks; a puppet follows (its mode, a count of strands laid
## in `net_flag`, and in `net_point` the last strand's middle, or whom it comes
## for). Every machine lays the same strands from that; being stuck, tearing free
## and cutting are done where whoever it is plays, and told to the room
## ({"folk": "weaver_stuck" / "weaver_cut"}); being lifted is shown there too
## (MazeAngel.lift). The catch is the host's.

enum Mode { DRIFT, WEAVE, COME, REACH, TAKE, REST }

@export var hover := 1.0
@export var drift_speed := 1.1
@export var come_speed := 3.2
@export var weave_every := 22.0
@export var weave_time := 2.4
@export var strands := 8
@export var thread_heights := PackedFloat32Array([0.95, 1.25, 1.55])
@export var reach_time := 1.5
@export var take_time := 1.8
@export var rest_time := 6.0
## Presses of jump or act that tear someone free.
@export var struggle := 7
## How near his hands a strand must be to cut it, metres.
@export var cut_reach := 2.0
@export var pose_range := 80.0

var mode := Mode.DRIFT
var body: Weaver
var threads: WeaverThreads
## Who it is coming for (stuck), if anyone.
var victim: Node3D

## Each strand: {"n": its serial, "a", "b": its ends at the floor, "ids": thread numbers}.
var _strands: Array = []
var _laid := 0
var _heard_laid := -1
var _went := 0.0
var _mode_time := 0.0
var _yaw := 0.0
var _world: Node
var _far := false
var _far_check := 0.0
# (this machine's player: stuck in which strand, how torn)
var _stuck_in := -1
var _held: Node
var _torn := 0
var _taken_here: Node
var _last_point := Vector3.INF


func _init() -> void:
	sight_range = 36.0
	hear_range = 8.0
	memory = 10.0
	pack = &"weavers"
	spare_time = 6.0


func _ready() -> void:
	add_to_group(&"pursuers")
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 2.6
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = hover + 1.6
	add_child(collider)
	body = Weaver.new()
	body.seed_value = _rng.randi()
	body.force_low = Settings.low_poly or Mummy.low_poly
	add_child(body)
	body.top_level = true
	threads = WeaverThreads.new()
	threads.name = "Threads"
	add_child(threads)
	_yaw = rotation.y
	rotation.y = 0.0
	var at := get_parent()
	while at:
		if at.get_script() and (at.get_script() as Script).get_global_name() == &"World":
			_world = at
			break
		at = at.get_parent()
	var net := get_node_or_null(^"/root/Net")
	if net and not net.is_connected(&"packet", _on_packet):
		net.connect(&"packet", _on_packet)
	if _world and _world.get(&"touch"):
		var touch: Object = _world.get(&"touch")
		touch.connect(&"act_pressed", _pressed)
		touch.connect(&"jump_pressed", _pressed)


# --- Thinking ---

func _physics_process(delta: float) -> void:
	_mode_time += delta
	if puppet:
		_follow(delta)
		_local(delta)
		return
	if maze == null:
		return
	_sense(delta)
	var wish := Vector3.ZERO
	var speed := drift_speed
	match mode:
		Mode.DRIFT:
			wish = _route(goal())
			_went += Vector2(velocity.x, velocity.z).length() * delta * (2.0 if hunting() else 1.0)
			if _went > weave_every and _in_hall():
				mode = Mode.WEAVE
				_mode_time = 0.0
		Mode.WEAVE:
			if _mode_time > weave_time:
				_lay(global_position, _yaw)
				_went = 0.0
				mode = Mode.DRIFT
		Mode.COME:
			if victim == null or not is_instance_valid(victim) or not _is_stuck(victim):
				_let_off()
			else:
				var to := victim.global_position - global_position
				to.y = 0.0
				if to.length() < 1.2:
					mode = Mode.REACH
					_mode_time = 0.0
				else:
					wish = _route(victim.global_position)
					speed = come_speed
		Mode.REACH:
			if victim == null or not is_instance_valid(victim) or not _is_stuck(victim):
				_let_off()
			elif _mode_time > reach_time:
				mode = Mode.TAKE
				_mode_time = 0.0
				if victim == _mine():
					_taken_here = MazeAngel.lift(victim, take_time + 0.2, body.hold_point())
		Mode.TAKE:
			if _mode_time > take_time:
				var who := victim
				_free_local()
				victim = null
				mode = Mode.REST
				_mode_time = 0.0
				if who and is_instance_valid(who):
					_catch(who)
		Mode.REST:
			wish = _route(goal())
			if _mode_time > rest_time:
				mode = Mode.DRIFT
	chasing = mode in [Mode.COME, Mode.REACH, Mode.TAKE]
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, 2.0 * delta)
	velocity = flat
	move_and_slide()
	if flat.length() > 0.2:
		_yaw = lerp_angle(_yaw, atan2(flat.x, flat.z), 1.0 - exp(-2.0 * delta))
	_local(delta)


func _route(aim: Vector3) -> Vector3:
	var to := nav.waypoint(global_position, aim, MazeNav.clearance_for(0.6)) - global_position
	to.y = 0.0
	return to.normalized() if to.length() > 0.3 else Vector3.ZERO


func _in_hall() -> bool:
	return maze.inside(maze.cell_at(global_position)) and not maze.in_clearing(maze.cell_at(global_position)) and _strands.all(func(s: Dictionary) -> bool: return (s["mid"] as Vector3).distance_to(global_position) > 10.0)


func _let_off() -> void:
	victim = null
	mode = Mode.REST
	_mode_time = 0.0


func _is_stuck(player: Node3D) -> bool:
	if player == _mine():
		return _stuck_in >= 0
	return player.has_meta(&"weaver_stuck")


func _mine() -> Node3D:
	return _world.get(&"player") if _world else local_player()


# --- Strands ---

## Lays a strand across the hall at `at`, across the way `facing` (on every machine alike).
func _lay(at: Vector3, facing: float) -> void:
	_laid += 1
	var across := Vector3(cos(facing), 0.0, -sin(facing))
	var floor_at := Vector3(at.x, maze.ground_height(at) if maze else at.y, at.z)
	var space := get_world_3d().direct_space_state
	var ends := []
	for side: float in [1.0, -1.0]:
		var from := floor_at + Vector3.UP * 1.2
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + across * side * 12.0, 1))
		var end: Vector3 = (hit["position"] as Vector3) - across * side * 0.05 if not hit.is_empty() else from + across * side * 12.0
		ends.append(Vector3(end.x, floor_at.y, end.z))
	var ids := []
	for h in thread_heights:
		ids.append(threads.add(ends[0] + Vector3.UP * h, ends[1] + Vector3.UP * h))
	_strands.append({"n": _laid, "a": ends[0], "b": ends[1], "ids": ids, "mid": floor_at})
	_last_point = floor_at
	body.twang(floor_at + Vector3.UP)
	while _strands.size() > strands:
		_drop_strand(_strands[0]["n"], false)


func _strand(n: int) -> Dictionary:
	for s: Dictionary in _strands:
		if s["n"] == n:
			return s
	return {}


## Strand `n` cut (or torn) at `at`: it snaps, and whoever was stuck in it is free.
func cut(n: int, at: Vector3, tell := true) -> void:
	var s := _strand(n)
	if s.is_empty():
		return
	for id: int in s["ids"]:
		threads.cut(id, at)
	_strands.erase(s)
	if _stuck_in == n:
		_free_local()
	if tell:
		_send({"folk": "weaver_cut", "enemy": _index(), "strand": n, "at": [at.x, at.y, at.z]})


func _drop_strand(n: int, _tell: bool) -> void:
	var s := _strand(n)
	if s.is_empty():
		return
	if _stuck_in == n:
		_free_local()
	for id: int in s["ids"]:
		threads.remove(id)
	_strands.erase(s)


# --- Whoever plays here ---

## This machine's player: stuck in a strand he walks into upright; cutting one
## beside him with the act button; tearing free.
func _local(_delta: float) -> void:
	var boy := _mine() as Player
	if boy == null or not is_instance_valid(boy):
		return
	if _stuck_in >= 0:
		if Input.is_action_just_pressed(&"jump") or Input.is_action_just_pressed(&"act"):
			_pressed()
		return
	var feet := Vector2(boy.global_position.x, boy.global_position.z)
	for s: Dictionary in _strands:
		var a := Vector2((s["a"] as Vector3).x, (s["a"] as Vector3).z)
		var b := Vector2((s["b"] as Vector3).x, (s["b"] as Vector3).z)
		var near := Geometry2D.get_closest_point_to_segment(feet, a, b).distance_to(feet)
		if Input.is_action_just_pressed(&"act") and near < cut_reach:
			cut(s["n"], boy.global_position + Vector3.UP)
			return
		var low := boy.is_ducking or boy.state == Player.State.SLIDE or boy.is_limp or (boy.landing == Player.Landing.ROLL and boy.landing_progress < 1.0)
		var level := absf(boy.global_position.y - (s["a"] as Vector3).y) < 0.8
		if near < 0.3 and not low and level and not boy.has_node(^"AngelTaken"):
			_get_stuck(boy, s["n"])
			return


func _get_stuck(boy: Player, n: int) -> void:
	_stuck_in = n
	_torn = 0
	boy.set_meta(&"weaver_stuck", true)
	var s := _strand(n)
	for id: int in s["ids"]:
		threads.drag(id, boy.global_position + Vector3.UP * 1.0)
		threads.pluck(id, 1.0)
	body.twang(boy.global_position + Vector3.UP)
	MazeGhoul.paralyse(boy, 9999.0)
	_held = boy.get_node_or_null(^"GhoulHeld")
	if puppet:
		_send({"folk": "weaver_stuck", "enemy": _index(), "strand": n})
	else:
		_come_for(boy)


func _come_for(player: Node3D) -> void:
	if mode in [Mode.TAKE]:
		return
	victim = player
	mode = Mode.COME
	_mode_time = 0.0
	body.keen()


## A press of jump or act, stuck: it tears at the strand.
func _pressed() -> void:
	if _stuck_in < 0:
		return
	_torn += 1
	var s := _strand(_stuck_in)
	for id: int in s.get("ids", []):
		threads.pluck(id, 0.6)
	if _torn >= struggle:
		var boy := _mine()
		cut(_stuck_in, boy.global_position + Vector3.UP if boy else global_position)


func _free_local() -> void:
	_stuck_in = -1
	_torn = 0
	var boy := _mine()
	if boy and is_instance_valid(boy):
		boy.remove_meta(&"weaver_stuck")
	if _held and is_instance_valid(_held):
		_held.queue_free()
	_held = null
	if _taken_here and is_instance_valid(_taken_here):
		_taken_here.queue_free()
	_taken_here = null


# --- The room ---

func _index() -> int:
	if _world == null or _world.get(&"enemies") == null:
		return -1
	return (_world.get(&"enemies") as MazeEnemies).enemies.find(self)


func _send(message: Dictionary) -> void:
	var net := get_node_or_null(^"/root/Net")
	if net and _world and _world.get(&"online") == true:
		net.call(&"send_json", 255, message)


func _on_packet(from: int, kind: int, data: PackedByteArray) -> void:
	if kind != 74 or _world == null:
		return
	var message: Variant = JSON.parse_string(data.get_string_from_utf8())
	if not (message is Dictionary) or int(message.get("enemy", -2)) != _index():
		return
	var what := str(message.get("folk", ""))
	if what != "weaver_stuck" and what != "weaver_cut":
		return
	var net := get_node_or_null(^"/root/Net")
	if net and net.get(&"is_host") == true and from != int(_world.get(&"slot")):
		net.call(&"send_json", 255, message)
	if what == "weaver_cut":
		var at: Array = message.get("at", [0, 0, 0])
		cut(int(message.get("strand", -1)), Vector3(at[0], at[1], at[2]), false)
	elif not puppet:
		var other: Node3D = (_world.get(&"remotes") as Dictionary).get(from)
		if other:
			other.set_meta(&"weaver_stuck", true)
			var s := _strand(int(message.get("strand", -1)))
			for id: int in s.get("ids", []):
				threads.drag(id, other.global_position + Vector3.UP)
			_come_for(other)


func yaw() -> float:
	return _yaw


func net_state() -> int:
	return mode


func net_flag() -> int:
	return _laid & 0x0f


func net_point() -> Vector3:
	if victim and is_instance_valid(victim):
		return victim.global_position
	return _last_point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	var was := mode
	mode = state as Mode
	_yaw = facing
	chasing = mode in [Mode.COME, Mode.REACH, Mode.TAKE]
	if _heard_laid >= 0 and (flag & 0x0f) != _heard_laid and point.is_finite() and mode != Mode.COME:
		_lay(point, facing)
	_heard_laid = flag & 0x0f
	if mode != was:
		_mode_time = 0.0
		if mode == Mode.COME:
			body.keen()
		var boy := _mine()
		if mode == Mode.TAKE and boy and _stuck_in >= 0 and point.is_finite() and point.distance_to(boy.global_position) < 2.5:
			_taken_here = MazeAngel.lift(boy, take_time + 0.2, global_position + Vector3.UP * 3.0)
		if was == Mode.TAKE:
			_free_local()


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1


# --- Drawing it ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			body.visible = not far
			body.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
		body.hum = near != null and near.global_position.distance_to(global_position) < 20.0
	if _far:
		return
	var sink := 0.0
	body.weaving = 1.0 if mode == Mode.WEAVE else 0.0
	body.reach_point = Vector3.INF
	body.reaching = 0.0
	body.holding = mode == Mode.TAKE
	var who := victim
	if puppet and mode in [Mode.COME, Mode.REACH, Mode.TAKE]:
		who = nearest_player(global_position)
	if mode == Mode.REACH and who:
		# (sinking over them, reaching down)
		sink = smoothstep(0.0, reach_time, _mode_time) * 0.9
		body.reach_point = who.global_position + Vector3.UP * 1.0
		body.reaching = smoothstep(0.0, reach_time, _mode_time)
	elif mode == Mode.TAKE:
		sink = 0.9 - smoothstep(0.0, take_time, _mode_time) * 2.5
	body.look_at_point = who.global_position + Vector3.UP if who and is_instance_valid(who) else Vector3.INF
	body.global_transform = Transform3D(Basis(Vector3.UP, _yaw), global_position + Vector3.UP * (hover - sink))


func _exit_tree() -> void:
	_free_local()

class_name MazeOctopus
extends MazeEnemy
## A giant octopus (creatures/octopus/: its look and motion, `Octopus`) lairing
## in water in the maze. This is only its thinking; it drives the Octopus.
##
## - ITS LAIR. A black pool in a hall, against one wall (`OctopusPool`), or a
##   drain (`drain`): a slot at the foot of a wall that runs through it to the
##   hall on the other side (`OctopusDrain`). It lies down in it out of sight,
##   its skin the tone of what it lies on, and it is hard to see: a pool, still,
##   and maybe something lying along the floor by it.
## - IT FEELS ABOUT. One arm or two creep out of its water along the floor and
##   up the walls near it, tips curling and uncurling, slowly (camouflaged: mud
##   on the floor, stone grey up the wall). The tells: the moving tips, rings
##   spreading on the pool, a wet slithering. When someone comes within
##   `notice_range` its feelers creep towards them, its skin roughens.
## - IT GRABS. Whoever stays within an arm's reach of its water (`reach`, about
##   six metres from the mouth, never all the way across the hall) for
##   `linger_time` is struck at: an arm rears up out of the water and coils
##   (`wind_time`, its skin blanching and dark clouds rolling over it: the
##   warning), then lashes out to where they were at the end of it. Anyone
##   still within `lash_hit` of that point is caught round the legs and body;
##   anyone who has moved on (a run carries you clear, a walk does not) is
##   missed, and the arm slaps the floor and draws back. Up a wall above
##   `reach_height` it cannot reach you.
## - IT DRAGS. A held one is dragged towards its water (`drag_speed`); dragged
##   all the way in, they are caught (`caught`). They can struggle free: every
##   press of jump (or act) is a tug, and `tugs_needed` tugs break its grip. A
##   friend (anyone) can cut an arm: the act button within `cut_reach` of one
##   cuts it through; it lets go, and the octopus inks and hides. A cut arm
##   grows back in time (Octopus.regrow_time).
## - INK. Hurt (cut, or staggered by a spear) or frightened (something bigger
##   that would eat it, near), it lets out a cloud of ink (OctopusInk: the
##   screen goes dark for anyone in it) and vanishes into its water for
##   `hide_time`.
## - ON LAND. Someone it has noticed who stays near its water, out of its
##   reach, for `out_after` seconds, it comes up after: it hauls itself out and
##   crawls after them on its arms (`crawl_speed`, slower than a walk), and
##   strikes as it does from the water, from where it is. Out of water it
##   tires: after `dry_time`, or `leash` metres from its water, or when it has
##   lost them, it goes back and sinks.
## - THROUGH THE WALL. In a drain it can pour itself through to the other
##   side (an octopus fits through any gap bigger than its beak): when someone
##   is near the other mouth, it squeezes through (`squeeze_time`) and comes out
##   there. Nothing else can go that way.
## - IT EATS (Ecology): a meat-eater (size 3) that grabs any smaller creature
##   that comes near its water, drags it in and eats it.
##
## Online, the host thinks for it and the others' copies are puppets. Its
## state says what its body is doing and what its striking arm is doing, which
## arm, and the point it is aimed at or holds; its inks and cut arms are
## counted, so a puppet inks and loses an arm when the host's does. Whoever is
## held is dragged on their own machine (as imps hold back whoever they ride);
## a guest who struggles free, or cuts an arm, tells the host
## ({"octopus": name, "free": true} or {"octopus": name, "cut": arm}).
##
## Spawn (as MazeEnemies.add does): `MazeOctopus.new()`, set `maze` (and
## `drain`), place it and add it to the tree. Its lair is found from where it
## is put (the same on every machine).

enum Mode { LURK, OUT, BACK, HIDE, SQUEEZE }
enum Act { IDLE, WIND, LASH, HOLD, RECOIL }

## Net's own numbers (Net.BROADCAST, Net.K_JSON).
const BROADCAST := 255
const K_JSON := 74

## A drain in a wall (true) or a pool (false). Set before it goes in.
@export var drain := false
@export var pool_radius := 2.8
## How far from its mouth an arm reaches to grab (it is less in a narrow hall:
## it never reaches all the way across), and how high up.
@export var grab_reach := 6.5
@export var reach_height := 3.2
## Out on the ground, how far from its body it grabs.
@export var land_reach := 5.0
## Its feelers creep towards anyone this near its water.
@export var notice_range := 11.0
## How long someone must stay in its reach before it strikes; the wind-up; the lash.
@export var linger_time := 0.45
@export var wind_time := 0.95
@export var lash_time := 0.35
## How near where it lashes someone must still be to be caught.
@export var lash_hit := 1.35
## How fast it drags; how many tugs (jump presses) break its grip; how long a
## hold may last at most (if what it holds does not come).
@export var drag_speed := 1.3
@export var tugs_needed := 4
@export var hold_most := 9.0
## How long it rests after a miss, or after someone has struggled free.
@export var miss_rest := 1.3
@export var freed_rest := 4.0
## How near an arm the act button must be pressed to cut it.
@export var cut_reach := 2.2
## On land: how long someone must stay near (but out of reach) before it comes
## out; how near its water they must be; its crawl; how far from its water it
## will go, and for how long.
@export var out_after := 3.0
@export var pursue_range := 14.0
@export var crawl_speed := 1.1
@export var leash := 15.0
@export var dry_time := 12.0
## Inked, how long it stays down.
@export var hide_time := 12.0
## How long it takes to pour itself through a drain, and to come up out of its water.
@export var squeeze_time := 2.2
@export var rise_time := 1.4
@export var gravity := 24.0
## Further than this from every player it is not posed.
@export var pose_range := 75.0

var mode := Mode.LURK
var act := Act.IDLE
## Which arm is striking (or holding), at what, and where.
var active := 0
var target: Node3D
var aim := Vector3.INF
## Its look and motion, and its lair.
var figure: Octopus
var pool: OctopusPool
var drains: OctopusDrain
## Its lair's mouths (one for a pool, two for a drain), the way out of each, and which it is at.
var mouths: Array[Vector3] = []
var outs: Array[Vector3] = []
var den := 0
## How far it reaches from its mouth here (grab_reach, or less in a narrow hall).
var reach := 6.5
## How far it has sunk (0 up on the ground, 1 down out of sight).
var sunk := 1.0
var facing_yaw := 0.0
## How many times it has inked, and lost an arm (for the network).
var inks := 0
var cuts := 0
## Whoever it holds is on this machine (being dragged here): the player.
var held_here: Node3D

var _ready_den := false
var _floor := 0.0
var _act_time := 0.0
var _rest_in := 0.0
var _mode_time := 0.0
var _linger := {}
var _near_time := 0.0
var _feelers: Array[int] = []
var _feel_goals: Array[Vector3] = []
var _feel_walls: Array[Vector3] = []
var _feel_want: Array[Vector3] = []
var _feel_in: PackedFloat32Array = PackedFloat32Array()
var _stir_in := 0.0
var _tugs := 0
var _tug_pause := 0.0
var _jumped := false
var _acted := false
var _touch_hooked := false
var _took_input := true
var _grace := 0.0
var _far := false
var _far_check := 0.0
var _heard_inks := -1
var _heard_cuts := -1
var _was_staggered := false
var _squeeze_from := Vector3.ZERO
var _world: Node
var _hooked_net := false

static var _blind: OctopusInk.Blind


func _init() -> void:
	sight_range = 18.0
	hear_range = 6.0
	memory = 8.0
	alert_range = 0.0
	pack = &"octopuses"


func _ready() -> void:
	add_to_group(&"pursuers")
	var shape := CapsuleShape3D.new()
	shape.radius = 0.95
	shape.height = 2.2
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 1.1
	add_child(collider)
	floor_snap_length = 0.4
	_floor = global_position.y
	facing_yaw = rotation.y
	rotation = Vector3.ZERO
	figure = Octopus.new()
	figure.top_level = true
	add_child(figure)
	figure.floor_y = _floor
	figure.sunk = 1.0
	figure.put(global_position, facing_yaw)
	for k in Octopus.ARMS:
		figure.rest(k)
	figure.cut_off.connect(_on_cut_off)
	_set_solid(false)
	_world = _find_world()
	_find_den.call_deferred()


func _find_world() -> Node:
	var at := get_parent()
	while at:
		if &"online" in at and &"player" in at:
			return at
		at = at.get_parent()
	return null


func _online() -> bool:
	return _world != null and bool(_world.get(&"online")) and _net() != null


## The rooms connection (the autoload Net), looked up rather than named, so
## that this compiles where there is none (a test run with -s).
func _net() -> Node:
	return get_node_or_null(^"/root/Net")


## Finds its lair from where it was put (the walls must be in the physics first).
func _find_den() -> void:
	if not is_inside_tree():
		return
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var at := Vector3(global_position.x, _floor + 0.5, global_position.z)
	# The wall faces round it, nearest first.
	var faces: Array = []
	for step: Vector2i in Maze.STEPS:
		var way := Vector3(step.x, 0.0, step.y)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + way * Maze.CELL, 1))
		if not hit.is_empty():
			faces.append([at.distance_to(hit["position"]), hit["position"], -way, step])
	faces.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	if drain and maze and not faces.is_empty():
		_drain_den(space, faces)
	if mouths.is_empty():
		_pool_den(space, faces)
	_ready_den = true
	var body := _den_body()
	global_position = Vector3(body.x, _floor - Octopus.SINK_DEPTH, body.z)
	figure.put(Vector3(body.x, _floor, body.z), facing_yaw)
	_skin_for_den()
	_choose_feelers()


## A pool against the nearest wall (if one is near), reaching no further than most of the way across the hall.
func _pool_den(space: PhysicsDirectSpaceState3D, faces: Array) -> void:
	var middle := Vector3(global_position.x, _floor, global_position.z)
	var out := Vector3.FORWARD
	if not faces.is_empty() and float(faces[0][0]) < 9.0:
		var face: Vector3 = faces[0][1]
		out = faces[0][2]
		middle = Vector3(face.x, _floor, face.z) + out * (pool_radius + 0.7)
	mouths = [middle]
	outs = [out]
	# (how far across the hall it may reach: never right across it)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(middle + Vector3.UP * 0.5, middle + Vector3.UP * 0.5 + out * 30.0, 1))
	var across := 30.0 if hit.is_empty() else middle.distance_to(hit["position"]) - 0.5
	reach = clampf(across - 2.2, 3.5, grab_reach)
	pool = OctopusPool.new()
	pool.radius = pool_radius
	pool.shape_seed = int(absf(middle.x * 7.0 + middle.z * 13.0)) % 1000
	pool.visibility_range_end = pose_range + 30.0
	add_child(pool)
	pool.top_level = true
	pool.global_position = middle
	facing_yaw = atan2(out.x, out.z)


## A drain through the nearest wall that has a passage on its other side: a
## mouth at its foot on each side.
func _drain_den(space: PhysicsDirectSpaceState3D, faces: Array) -> void:
	var cell := maze.cell_at(global_position)
	for face: Array in faces:
		var step: Vector2i = face[3]
		var beyond := cell + step
		if float(face[0]) > 10.0 or not maze.blocked(cell, step) or not maze.inside(beyond) or not nav.allowed(beyond) or maze.ring_wall(cell, step):
			continue
		var near_face: Vector3 = face[1]
		var out: Vector3 = face[2]
		# The other face: from the middle of the cell beyond, back towards this one.
		var other := maze.world(beyond)
		other = Vector3(near_face.x, _floor + 0.5, near_face.z) if absf(out.x) < 0.5 else Vector3(other.x, _floor + 0.5, near_face.z)
		if absf(out.x) < 0.5:
			other.z = maze.world(beyond).z
		else:
			other.x = maze.world(beyond).x
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(other, other + out * Maze.CELL, 1))
		if hit.is_empty():
			continue
		var far_face: Vector3 = hit["position"]
		mouths = [Vector3(near_face.x, _floor, near_face.z), Vector3(far_face.x, _floor, far_face.z)]
		outs = [out, -out]
		break
	if mouths.is_empty():
		return
	var lip := Vector3(mouths[0].x, _floor, mouths[0].z) + outs[0] * 0.6
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(lip + Vector3.UP * 0.5, lip + Vector3.UP * 0.5 + outs[0] * 30.0, 1))
	var across := 30.0 if hit.is_empty() else lip.distance_to(hit["position"])
	reach = clampf(across - 2.2, 3.5, grab_reach)
	drains = OctopusDrain.new()
	drains.mouths = [[mouths[0], outs[0]], [mouths[1], outs[1]]]
	add_child(drains)
	drains.top_level = true
	drains.global_transform = Transform3D.IDENTITY
	drains.visibility_range_end = pose_range + 30.0
	facing_yaw = atan2(outs[0].x, outs[0].z)


## Where its body lies when it is down in its lair: under its pool, or back in the wall behind the drain's mouth.
func _den_body(which := -1) -> Vector3:
	var d := den if which < 0 else which
	if drains:
		return mouths[d] - outs[d] * 1.9
	return mouths[0]


## Where it comes up out of its lair onto the ground.
func _den_out(which := -1) -> Vector3:
	var d := den if which < 0 else which
	if drains:
		return mouths[d] + outs[d] * 1.6
	return mouths[0]


func _skin_for_den() -> void:
	figure.floor_y = _floor
	figure.mouth = Vector3(mouths[den].x, _floor, mouths[den].z)
	if drains:
		figure.mouth_out = outs[den]
		figure.mouth_width = drains.width
		figure.water = Vector4(mouths[den].x, _floor, mouths[den].z, 1.4)
	else:
		figure.mouth_out = Vector3.ZERO
		figure.hole_radius = pool_radius * 0.8
		figure.water = Vector4(mouths[0].x, _floor, mouths[0].z, pool_radius)


## Its feelers: two arms (by its seed) that feel about while it lurks.
func _choose_feelers() -> void:
	var first := _rng.randi_range(0, Octopus.ARMS - 1)
	_feelers = [first, (first + 3 + _rng.randi_range(0, 2)) % Octopus.ARMS]
	_feel_goals = [_mouth_out_point(2.0), _mouth_out_point(2.5)]
	_feel_walls = [Vector3.ZERO, Vector3.ZERO]
	_feel_want = _feel_goals.duplicate()
	_feel_in = PackedFloat32Array([0.5, 2.5])


func _mouth_out_point(distance: float) -> Vector3:
	return Vector3(mouths[den].x, _floor, mouths[den].z) + outs[den] * distance


func _set_solid(solid: bool) -> void:
	collision_layer = (PUPPET_LAYER if puppet else 4) if solid else 0
	collision_mask = 1 if puppet else (1 | 4 if solid else 1)


# --- Thinking (the host) ---

func _physics_process(delta: float) -> void:
	_hook_input()
	if puppet:
		_puppet_step(delta)
		_here(delta)
		return
	if maze == null or not _ready_den:
		return
	_hook_net()
	_mode_time += delta
	_act_time += delta
	_rest_in -= delta
	_grace -= delta
	if mode != Mode.HIDE and mode != Mode.SQUEEZE:
		_sense(delta)
	# (frightened by something bigger that would eat it: ink, and away)
	if threat and mode in [Mode.LURK, Mode.OUT, Mode.BACK]:
		_ink_and_hide()
	match mode:
		Mode.LURK:
			_lurk(delta)
		Mode.OUT:
			_out(delta)
		Mode.BACK:
			_back(delta)
		Mode.HIDE:
			_hide(delta)
		Mode.SQUEEZE:
			_squeeze(delta)
	_strike(delta)
	chasing = act in [Act.WIND, Act.LASH, Act.HOLD] or mode == Mode.OUT
	_here(delta)


func _set_mode(next: Mode) -> void:
	mode = next
	_mode_time = 0.0
	_set_solid(next in [Mode.OUT, Mode.BACK] and sunk < 0.5)


## Down in its lair: feeling about, watching; out after someone who lingers near out of reach; through the drain to someone at its other mouth.
func _lurk(delta: float) -> void:
	sunk = minf(sunk + delta / rise_time, 1.0)
	_place_body(_den_body(), sunk)
	if act != Act.IDLE:
		_near_time = 0.0
		return
	var after := _after()
	if after and is_instance_valid(after):
		var from_mouth := _flat(after.global_position - mouths[den])
		var near_other := drains != null and _flat(after.global_position - mouths[1 - den]) < reach and _flat(after.global_position - mouths[1 - den]) < from_mouth
		if near_other and _rest_in <= 0.0:
			_start_squeeze()
			return
		if from_mouth < pursue_range and from_mouth > reach * 0.9:
			_near_time += delta
			if _near_time > out_after and _rest_in <= 0.0:
				_set_mode(Mode.OUT)
				_near_time = 0.0
		else:
			_near_time = maxf(_near_time - delta * 0.5, 0.0)
	else:
		_near_time = 0.0


## Up out of its water and after them across the floor, on its arms.
func _out(delta: float) -> void:
	# First it comes up (and squeezes out of a drain).
	if sunk > 0.0:
		sunk = maxf(sunk - delta / rise_time, 0.0)
		var from := _den_body()
		var to := _den_out()
		_place_body(from.lerp(to, 1.0 - sunk), sunk)
		if sunk <= 0.0:
			_set_solid(true)
		return
	var after := _after()
	var home := _flat(global_position - _den_out())
	if after == null or not is_instance_valid(after) or _mode_time > dry_time or home > leash:
		if act != Act.HOLD:
			_set_mode(Mode.BACK)
		return
	if act == Act.HOLD:
		_crawl_to(_den_out(), crawl_speed, delta)
		return
	var to := after.global_position - global_position
	if _flat(to) < land_reach * 0.6 or act != Act.IDLE:
		_crawl_to(global_position, 0.0, delta)
	else:
		_crawl_to(after.global_position, crawl_speed, delta)


## Back to its water, and down into it.
func _back(delta: float) -> void:
	var home := _den_out()
	if _flat(global_position - home) > 0.4 and sunk <= 0.0:
		_crawl_to(home, crawl_speed * 1.25, delta)
		if _after() and _mode_time > 1.5 and _flat(_after().global_position - mouths[den]) < pursue_range * 0.7 and _rest_in <= 0.0 and act == Act.IDLE:
			_set_mode(Mode.OUT)
			_mode_time = dry_time * 0.6
		return
	_set_solid(false)
	velocity = Vector3.ZERO
	sunk = minf(sunk + delta / rise_time, 1.0)
	_place_body(home.lerp(_den_body(), sunk), sunk)
	if sunk >= 1.0:
		_set_mode(Mode.LURK)
		_rest_in = miss_rest


## Inked: back into its water as fast as it can jet, and down out of sight a while.
func _hide(delta: float) -> void:
	if act != Act.IDLE:
		_let_go(false)
	var home := _den_out()
	if sunk <= 0.0 and _flat(global_position - home) > 0.4:
		_crawl_to(home, 5.5, delta)
		return
	_set_solid(false)
	velocity = Vector3.ZERO
	sunk = minf(sunk + delta / (rise_time * 0.5), 1.0)
	_place_body(home.lerp(_den_body(), sunk), sunk)
	if sunk >= 1.0 and _mode_time > hide_time:
		_set_mode(Mode.LURK)
		quarry = null
		_forget = 0.0


func _start_squeeze() -> void:
	_set_mode(Mode.SQUEEZE)
	_squeeze_from = _den_body()


## Pouring itself through the drain to its other mouth, out of sight in the wall.
func _squeeze(_delta: float) -> void:
	var f := clampf(_mode_time / squeeze_time, 0.0, 1.0)
	_place_body(_squeeze_from.lerp(_den_body(1 - den), smoothstep(0.25, 0.85, f)), 1.0)
	if f >= 1.0:
		den = 1 - den
		_skin_for_den()
		_choose_feelers()
		_set_mode(Mode.LURK)
		_rest_in = 0.6


## Its body where it lies, as far down as `down` (0..1).
func _place_body(at: Vector3, down: float) -> void:
	global_position = Vector3(at.x, _floor - down * Octopus.SINK_DEPTH, at.z)
	velocity = Vector3.ZERO


## On the ground: crawls towards `goal` by the passages at up to `speed`.
func _crawl_to(goal: Vector3, speed: float, delta: float) -> void:
	var wish := Vector3.ZERO
	if speed > 0.0 and _flat(goal - global_position) > 0.3:
		var to := nav.waypoint(global_position, goal, MazeNav.clearance_for(0.9)) - global_position
		to.y = 0.0
		wish = to.normalized() if to.length() > 0.05 else _flat_dir(goal - global_position)
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, 4.0 * delta)
	velocity.x = current.x
	velocity.z = current.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()
	if global_position.y < _floor - 0.5:
		global_position.y = _floor
	if current.length() > 0.2:
		facing_yaw = lerp_angle(facing_yaw, atan2(current.x, current.z), 1.0 - exp(-1.5 * delta))


# --- Striking ---

## Where it reaches from now (its mouth, down in its lair; its body, out on the ground) and how far.
func _reach_from() -> Array:
	if mode in [Mode.OUT, Mode.BACK] and sunk < 0.5:
		return [Vector3(global_position.x, _floor, global_position.z), land_reach]
	return [Vector3(mouths[den].x, _floor, mouths[den].z), reach]


## Who it could strike at now: players (and, hungry, the creature it is after) in reach, and in sight of where it reaches from.
func _in_reach() -> Array:
	var spot: Array = _reach_from()
	var from: Vector3 = spot[0]
	var far: float = spot[1]
	var eye := from + (outs[den] * 0.6 if drains and mode == Mode.LURK else Vector3.ZERO) + Vector3.UP * 0.5
	var found: Array = []
	var them: Array = players().duplicate()
	if _after() is MazeEnemy:
		them.append(quarry)
	for one: Node3D in them:
		if not huntable(one) or Stagger.on(self):
			continue
		var at := one.global_position
		if _flat(at - from) > far or at.y - _floor > reach_height or at.y < _floor - 1.0:
			continue
		if not nav.sees(eye, at + Vector3.UP, far + 1.0):
			continue
		found.append(one)
	return found


func _strike(delta: float) -> void:
	match act:
		Act.IDLE:
			if mode in [Mode.HIDE, Mode.SQUEEZE] or _rest_in > 0.0 or (mode == Mode.OUT and sunk > 0.0) or (mode == Mode.BACK and sunk > 0.0):
				_linger.clear()
				return
			var near := _in_reach()
			for one: Variant in _linger.keys():
				if not is_instance_valid(one) or not near.has(one):
					_linger.erase(one)
			for one: Node3D in near:
				_linger[one] = float(_linger.get(one, 0.0)) + delta
				if _linger[one] >= linger_time:
					_begin(one)
					break
		Act.WIND:
			if target == null or not is_instance_valid(target):
				_end(false)
				return
			aim = target.global_position
			if _act_time >= wind_time:
				act = Act.LASH
				_act_time = 0.0
				# (its line is set now: where they are, it lashes)
				aim = Vector3(target.global_position.x, _floor, target.global_position.z)
				_stir(aim, 1.0)
		Act.LASH:
			if _act_time >= lash_time:
				var hit := target != null and is_instance_valid(target) and huntable(target) and _flat(target.global_position - aim) < lash_hit and target.global_position.y - _floor < reach_height
				if hit:
					act = Act.HOLD
					_act_time = 0.0
					_tugs = 0
				else:
					_end(false)
		Act.HOLD:
			_hold(delta)
		Act.RECOIL:
			if _act_time > 0.6:
				act = Act.IDLE
				_act_time = 0.0


func _begin(one: Node3D) -> void:
	target = one
	active = _arm_towards(one.global_position)
	act = Act.WIND
	_act_time = 0.0
	aim = one.global_position
	_linger.clear()


## The whole arm (grown back) whose root faces most nearly towards `point`, and that is not a feeler if it can help it.
func _arm_towards(point: Vector3) -> int:
	var best := 0
	var score := -INF
	var to := _flat_dir(point - global_position)
	for k in Octopus.ARMS:
		if figure.grown(k) < 0.7:
			continue
		var root_way := (figure.global_basis * figure.rig.dirs_rest[k]).normalized()
		var s := root_way.dot(to) - (0.3 if _feelers.has(k) else 0.0)
		if s > score:
			score = s
			best = k
	return best


## Holding: drags them in (if they are dragged here), catches them at the water.
func _hold(_delta: float) -> void:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree() or (target is MazeEnemy and (target as MazeEnemy).dead):
		_end(false)
		return
	if figure.grown(active) < 0.99 and figure.since(active) < 0.1:
		_end(false)
		return
	aim = target.global_position
	var mouth := Vector3(mouths[den].x, _floor, mouths[den].z)
	if mode in [Mode.OUT, Mode.BACK]:
		mouth = Vector3(_den_out().x, _floor, _den_out().z)
	var in_reach := _flat(target.global_position - mouth)
	# Dragged all the way in: caught (and, a creature, eaten).
	if in_reach < (1.0 if drains else pool_radius * 0.45):
		var one := target
		_end(true)
		_stir(mouth, 1.0)
		if one is MazeEnemy and Ecology.current:
			Ecology.current.kill(one as MazeEnemy, self)
		else:
			_catch(one)
		_rest_in = miss_rest
		return
	if _act_time > hold_most:
		_end(false)
		return
	# A creature (or a runner) it drags itself, here where it is run; a player
	# is dragged on their own machine (`_here`).
	if not (target is RemotePlayer) and target != local_player():
		var way := _flat_dir(mouth - target.global_position)
		target.global_position += way * drag_speed * get_physics_process_delta_time()


## Stops striking (`done`: it got them, or else it missed, lost them or was made to let go).
func _end(done: bool) -> void:
	if act == Act.LASH and not done:
		_rest_in = miss_rest
	act = Act.RECOIL if not done else Act.IDLE
	_act_time = 0.0
	target = null
	aim = Vector3.INF


## Made to let go: struggled free (or cut), and rests a while.
func _let_go(freed: bool) -> void:
	_end(false)
	_rest_in = freed_rest if freed else miss_rest


## Cuts arm k (where it is nearest `at`): the end falls, it lets go, inks and hides.
func cut_arm(k: int, at := Vector3.INF) -> void:
	if k < 0 or k >= Octopus.ARMS or figure.grown(k) < 0.5:
		return
	if act != Act.IDLE and active == k:
		_let_go(true)
	active = k
	cuts += 1
	figure.cut(k, at)
	_ink_and_hide()


func _on_cut_off(_arm: int, _at: Vector3) -> void:
	pass


func _ink_and_hide() -> void:
	if mode == Mode.HIDE:
		return
	inks += 1
	figure.ink()
	if act != Act.IDLE:
		_let_go(true)
	_set_mode(Mode.HIDE)
	quarry = null
	_forget = 0.0


func _stir(at: Vector3, strength: float) -> void:
	if pool:
		pool.stir(at, strength)


# --- Here (every machine): whoever is held on this machine, the act and jump buttons, the screen in ink ---

func _hook_input() -> void:
	if _touch_hooked or not is_inside_tree():
		return
	_touch_hooked = true
	var touch := get_tree().get_first_node_in_group(&"touch_controls")
	if touch:
		touch.connect(&"jump_pressed", func() -> void: _jumped = true)
		touch.connect(&"act_pressed", func() -> void: _acted = true)


func _hook_net() -> void:
	if _hooked_net or not _online():
		return
	_hooked_net = true
	_net().connect(&"packet", _on_packet)


## The local player's buttons, and the one held here dragged.
func _here(delta: float) -> void:
	var me := local_player()
	if Input.is_action_just_pressed(&"jump"):
		_jumped = true
	if Input.is_action_just_pressed(&"act"):
		_acted = true
	var jumped := _jumped
	var acted := _acted
	_jumped = false
	_acted = false
	_tug_pause -= delta
	var holding := _held_target()
	# Whoever is held on this machine is dragged here.
	if me and holding == me and _grace <= 0.0 and figure.visible:
		if held_here != me:
			held_here = me
			_took_input = me.takes_input
			me.takes_input = false
			_tugs = 0
		_drag_here(me, delta)
		if jumped or acted:
			_tug(me)
	elif held_here:
		_free_here()
	elif me and acted and figure.visible:
		_try_cut(me)
	_blind_for(me)


## Who the striking arm holds, as this machine knows it (null: none).
func _held_target() -> Node3D:
	if act != Act.HOLD:
		return null
	if not puppet:
		return target
	# (as a puppet: the player of this machine, if they are where the host says it holds)
	var me := local_player()
	if me and aim.is_finite() and _flat(me.global_position - aim) < 1.8 and absf(me.global_position.y - aim.y) < 2.0:
		return me
	return null


func _drag_here(who: Node3D, delta: float) -> void:
	var mouth := Vector3(mouths[den].x, _floor, mouths[den].z) if not mouths.is_empty() else global_position
	if mode in [Mode.OUT, Mode.BACK] and sunk < 0.5:
		mouth = _den_out()
	var way := _flat_dir(mouth - who.global_position)
	var speed := 0.0 if _tug_pause > 0.0 else drag_speed
	var body := who as CharacterBody3D
	if body:
		body.velocity = Vector3(way.x * speed, minf(body.velocity.y, 0.0), way.z * speed)
	who.global_position += way * speed * delta
	if &"facing_yaw" in who:
		# (he faces away, clawing at the floor)
		who.set(&"facing_yaw", atan2(-way.x, -way.z))


## A tug against its grip: enough of them and he is free.
func _tug(who: Node3D) -> void:
	_tugs += 1
	_tug_pause = 0.3
	var mouth := mouths[den] if not mouths.is_empty() else global_position
	who.global_position += _flat_dir(who.global_position - mouth) * 0.3
	if _tugs >= tugs_needed:
		_free_here()
		var body := who as CharacterBody3D
		if body:
			var away := _flat_dir(who.global_position - mouth)
			body.velocity = away * 5.0 + Vector3.UP * 3.0
		_grace = 1.5
		if puppet:
			if _online():
				_net().call(&"send_json", BROADCAST, {"octopus": String(name), "free": true})
		else:
			_let_go(true)


func _free_here() -> void:
	if held_here and is_instance_valid(held_here):
		if held_here is Player:
			(held_here as Player).takes_input = _took_input
	held_here = null
	_tugs = 0


## The act button near one of its arms (out of the ground): cuts it.
func _try_cut(me: Node3D) -> void:
	var hands := me.global_position + Vector3.UP * 1.0
	var best := -1
	var nearest := cut_reach
	var where := Vector3.INF
	for k in Octopus.ARMS:
		if figure.grown(k) < 0.5:
			continue
		var on := figure.near_arm(k, hands)
		if on.x < nearest:
			var points := figure.arm_points(k)
			var at := points[clampi(int(on.y * OctopusArm.BONES), 0, OctopusArm.BONES)]
			if at.y > _floor - 0.15:
				nearest = on.x
				best = k
				where = at
	if best < 0:
		return
	if puppet:
		if _online():
			_net().call(&"send_json", BROADCAST, {"octopus": String(name), "cut": best, "at": [where.x, where.y, where.z]})
	else:
		cut_arm(best, where)


## As the host: a guest struggled free, or cut an arm.
func _on_packet(from: int, kind: int, data: PackedByteArray) -> void:
	if puppet or kind != K_JSON:
		return
	var message: Variant = JSON.parse_string(data.get_string_from_utf8())
	if not (message is Dictionary) or str(message.get("octopus", "")) != String(name):
		return
	if message.has("free") and act == Act.HOLD and target and target.get(&"slot") == from:
		_let_go(true)
		_grace = 1.5
	if message.has("cut"):
		var spot: Array = message.get("at", [])
		cut_arm(int(message["cut"]), Vector3(spot[0], spot[1], spot[2]) if spot.size() == 3 else Vector3.INF)


## The screen darkens for this machine's player in ink (one for all of them).
func _blind_for(me: Node3D) -> void:
	if me == null:
		return
	if _blind == null or not is_instance_valid(_blind):
		_blind = OctopusInk.Blind.new()
		var holder := _world if _world else get_parent()
		holder.add_child(_blind)
	_blind.watch = me
	if held_here == me:
		_blind.prompt = "JUMP! JUMP! STRUGGLE FREE"
	elif _blind.prompt != "" and _held_by_any(me) == false:
		_blind.prompt = ""


func _held_by_any(me: Node3D) -> bool:
	for one: Node in get_tree().get_nodes_in_group(pack):
		if one is MazeOctopus and (one as MazeOctopus).held_here == me:
			return true
	return false


# --- What it looks like doing ---

func _process(delta: float) -> void:
	if figure == null or not _ready_den:
		return
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			figure.visible = not far
			figure.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
	# (a spear's stagger hurts it: it inks and goes)
	var staggered := Stagger.on(self)
	if staggered and not _was_staggered and not puppet:
		_ink_and_hide()
	_was_staggered = staggered
	if _far:
		return
	figure.floor_y = _floor
	figure.global_position = Vector3(global_position.x, _floor, global_position.z)
	figure.rotation.y = facing_yaw
	figure.sunk = sunk
	figure.squeeze = lerpf(0.4, 1.0, 1.0 - sunk) if drains else 1.0
	var moving := Vector3(velocity.x, 0.0, velocity.z)
	figure.crawling = mode in [Mode.OUT, Mode.BACK, Mode.HIDE] and sunk < 0.3
	figure.velocity = moving
	_drive_arms(delta)


## Tells each arm what to do: the striking one strikes; down in its lair the
## feelers feel about (towards anyone near) and the rest stay coiled down there;
## out on the ground they crawl.
func _drive_arms(delta: float) -> void:
	var up := sunk < 0.3
	var striking := act in [Act.WIND, Act.LASH, Act.HOLD] and aim.is_finite()
	match act:
		Act.WIND:
			figure.mood = 1.0
		Act.LASH, Act.HOLD:
			figure.mood = 2.0
		_:
			figure.mood = 0.6 if up else (0.3 if _someone_near() else 0.0)
	for k in Octopus.ARMS:
		if striking and k == active:
			match act:
				Act.WIND:
					figure.wind(k, aim)
				Act.LASH:
					if figure.doing[k] != Octopus.Do.LASH:
						figure.lash(k, aim)
						_stir(aim, 0.8)
				Act.HOLD:
					figure.hold(k, _held_point())
			continue
		if mode in [Mode.HIDE, Mode.SQUEEZE] and not up:
			figure.doing[k] = Octopus.Do.TUCK
			continue
		if up:
			if figure.crawling:
				figure.doing[k] = Octopus.Do.CRAWL
			else:
				figure.rest(k)
			continue
		var f := _feelers.find(k)
		if f >= 0 and mode == Mode.LURK and sunk > 0.9:
			_feel(f, k, delta)
		else:
			figure.rest(k)
	# Rings on its pool where its arms stir it.
	_stir_in -= delta
	if _stir_in <= 0.0 and pool and not up:
		_stir_in = _rng.randf_range(0.7, 1.6)
		var k: int = _feelers[_rng.randi_range(0, _feelers.size() - 1)] if not _feelers.is_empty() else 0
		var points := figure.arm_points(k)
		for i in points.size():
			if points[i].y > _floor - 0.2:
				_stir(points[i], 0.35)
				break


## Feeler `f` (arm k): creeps about near its mouth, along the floor and now and
## then up a wall; towards anyone near, stopping short.
func _feel(f: int, k: int, delta: float) -> void:
	_feel_in[f] -= delta
	var near := _nearest_near()
	if near:
		var to := near.global_position - mouths[den]
		var stop := maxf(_flat(to) - 2.5, 1.5)
		_feel_want[f] = Vector3(mouths[den].x, _floor, mouths[den].z) + _flat_dir(to).rotated(Vector3.UP, 0.5 if f == 0 else -0.5) * minf(stop, reach * 0.8)
		_feel_walls[f] = Vector3.ZERO
	elif _feel_in[f] <= 0.0:
		_feel_in[f] = _rng.randf_range(4.0, 8.0)
		_new_feel(f)
	# (creeping: the goal slides slowly to where it wants to feel)
	_feel_goals[f] = _feel_goals[f].move_toward(_feel_want[f], 0.9 * delta)
	figure.feel(k, _feel_goals[f], _feel_walls[f])


## A new place for feeler `f`: a point on the floor out from the mouth, short
## of any wall; or, now and then, a little way up the wall.
func _new_feel(f: int) -> void:
	var space := get_world_3d().direct_space_state
	var from := Vector3(mouths[den].x, _floor + 0.4, mouths[den].z) + (outs[den] * 0.6 if drains else Vector3.ZERO)
	var spread := 1.3 if drains else PI
	var way := outs[den].rotated(Vector3.UP, _rng.randf_range(-spread, spread))
	var far := _rng.randf_range(2.5, minf(reach * 0.85, 5.5))
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + way * far, 1))
	if not hit.is_empty() and _rng.randf() < 0.6:
		var face: Vector3 = hit["position"]
		_feel_want[f] = face + Vector3.UP * _rng.randf_range(0.6, 2.0)
		_feel_walls[f] = hit["normal"]
	else:
		var go := far if hit.is_empty() else from.distance_to(hit["position"]) - 0.6
		_feel_want[f] = Vector3(from.x, _floor, from.z) + way * maxf(go, 1.5)
		_feel_walls[f] = Vector3.ZERO


func _someone_near() -> bool:
	return _nearest_near() != null


func _nearest_near() -> Node3D:
	if mouths.is_empty():
		return null
	var best: Node3D = null
	var nearest := notice_range
	for one: Node3D in players():
		if not is_instance_valid(one) or not one.is_inside_tree():
			continue
		var d := _flat(one.global_position - mouths[den])
		if d < nearest and one.get(&"escaped") != true:
			nearest = d
			best = one
	return best


## Where the holding arm wraps: round whoever it holds (as this machine sees them).
func _held_point() -> Vector3:
	var held := _held_target()
	if held and is_instance_valid(held):
		return Vector3(held.global_position.x, _floor, held.global_position.z)
	return Vector3(aim.x, _floor, aim.z)


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


## Its body (low three bits), its striking arm's act (the next three), which mouth of a drain it is at (the top bit).
func net_state() -> int:
	return int(mode) | (int(act) << 3) | (den << 6)


## Which arm strikes (low three bits), its inks (two bits), its cut arms (three bits).
func net_flag() -> int:
	return (active & 0x07) | ((inks & 0x03) << 3) | ((cuts & 0x07) << 5)


func net_point() -> Vector3:
	if act == Act.HOLD and target and is_instance_valid(target):
		return target.global_position
	return aim


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = (state & 0x07) as Mode
	act = ((state >> 3) & 0x07) as Act
	var heard_den := (state >> 6) & 0x01
	if _ready_den and heard_den != den and heard_den < mouths.size():
		den = heard_den
		_skin_for_den()
		_choose_feelers()
	active = flag & 0x07
	var heard_inks := (flag >> 3) & 0x03
	var heard_cuts := (flag >> 5) & 0x07
	if _heard_inks >= 0 and heard_inks != _heard_inks and figure:
		figure.ink()
	if _heard_cuts >= 0 and heard_cuts != _heard_cuts and figure:
		figure.cut(active)
	_heard_inks = heard_inks
	_heard_cuts = heard_cuts
	aim = point


func _puppet_step(delta: float) -> void:
	_grace -= delta
	if not _heard:
		return
	_heard_at += _heard_moving * delta
	global_position = global_position.lerp(_heard_at, 1.0 - exp(-8.0 * delta))
	if global_position.distance_to(_heard_at) > 3.0:
		global_position = _heard_at
	velocity = _heard_moving
	facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-6.0 * delta))
	sunk = clampf((_floor - global_position.y) / Octopus.SINK_DEPTH, 0.0, 1.0)
	_set_solid(mode in [Mode.OUT, Mode.BACK] and sunk < 0.5)


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	velocity = Vector3.ZERO


func _puppet_changed() -> void:
	_set_solid(mode in [Mode.OUT, Mode.BACK] and sunk < 0.5)


## It stays in its lair when nobody sees it (it does not wander off).
func roam_unseen(_step: float) -> void:
	pass


func _exit_tree() -> void:
	_free_here()


## Whoever it is after and still remembers (null: nobody, or they are gone).
func _after() -> Node3D:
	if not is_instance_valid(quarry):
		quarry = null
		return null
	return quarry if hunting() else null


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


static func _flat_dir(v: Vector3) -> Vector3:
	var flat := Vector3(v.x, 0.0, v.z)
	return flat.normalized() if flat.length() > 0.0001 else Vector3.FORWARD

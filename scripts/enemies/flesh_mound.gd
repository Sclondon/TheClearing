class_name MazeFleshMound
extends MazeEnemy
## A flesh mound let loose in the maze: the thinking half. What it looks like
## and how it moves is FleshMound (creatures/flesh_mound/, a component that
## knows nothing of the maze): people grown together, as many as `bodies`.
## This finds its way, decides what to do, says whom it has caught, and makes
## it grow.
##
## SMALL (an amalgam, 3 or 4 bodies): it shambles about the passages on its
## limbs, a little slower than a run when it hunts. Where its quarry is in a
## straight line ahead, near enough, it rears with its limbs splayed (the
## warning, FleshMound.roll_wind_up) and cartwheels at them, faster than a
## run but not a sprint, for as long as its wind lasts (`roll_time`); then
## it is spent and lurches slowly until it has its wind back. So a sprint, or
## a turn off the hall, or a climb, gets away. Rolling into someone catches
## them.
##
## BIG (5 or more): it hauls itself along at a crawl, no faster than a walk
## when it hunts (slower the bigger it is), nearly filling a hall; the hands
## at its front grab at anyone in reach in front of it, after a wind-up
## (FleshMound.wind_up: the time to get away). A closing hand catches, and so
## does walking into it.
##
## GROWING. Whom it catches it absorbs: their body is seen dragged into it (a
## copy: the player goes back to the clearing as any catch sends them) and it
## has one more body. Two that meet merge: the smaller flows into the bigger,
## which gains its bodies (up to FleshMoundLook.MOST); the smaller is then
## gone (it stays in the list of enemies, hidden and still, so that what is
## sent between machines keeps its order).
##
## Online: its number of bodies goes in its state with what it is doing; a
## puppet grows when it hears it has, drags a body in when it hears a catch,
## flows into the other when it hears it is merging, and hides when gone.
##
## `MazeFleshMound.new()`: set `maze` (and `bodies`) first, as for any MazeEnemy.

enum Mode { ABOUT, HUNTING, WINDING, ROLLING, SPENT, MERGING, GONE }

## How many bodies are in it to start with.
@export var bodies := 3
## A small one's speeds: about, hunting, rolling (the boy walks at 2, runs at 4.4, sprints at 5.6), spent.
@export var shamble_speed := 1.4
@export var hunt_shamble_speed := 3.2
@export var roll_speed := 5.1
@export var spent_speed := 1.0
## How long a roll lasts (its wind), and how long it takes to get its wind back.
@export var roll_time := 3.2
@export var spent_time := 2.8
## It rolls at someone this far off or nearer (and further than `roll_near`), in a straight line.
@export var roll_range := 22.0
@export var roll_near := 3.0
## A big one's speeds, at 5 bodies and at the most (between them by how many).
@export var crawl_speeds := Vector2(1.3, 0.9)
@export var hunt_speeds := Vector2(2.3, 1.8)
@export var acceleration := 3.0
@export var turn_rate := 1.6
## A big one grabs at someone this far ahead of its middle (no more than its
## hands reach) and this near straight ahead (the cosine); then rests.
@export var grab_range := 10.0
@export var grab_cone := 0.35
@export var grab_rest := 1.4
## Two nearer than this (between the edges of their bodies, metres) merge.
@export var merge_gap := 1.0
@export var size := 1.0
@export var gravity := 24.0
## Further than this from every player it is not drawn or posed.
@export var pose_range := 90.0

var look: FleshMound
var mode := Mode.ABOUT
var facing_yaw := 0.0
var stamina := 1.0

var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _collider: CollisionShape3D
var _grabs := 0
var _absorbs := 0
var _rest := 0.0
var _has_him := {}
var _far := false
var _far_check := 0.0
var _heard_flag_first := true
var _heard_bodies := 0
var _merge_with: MazeFleshMound
var _age := 0.0
var _rolled := 0.0


func _init() -> void:
	sight_range = 46.0
	hear_range = 10.0
	memory = 60.0
	alert_range = 0.0
	pack = &"flesh_mounds"


func _ready() -> void:
	add_to_group(&"pursuers")
	add_to_group(&"flesh_mounds")
	_puppet_changed()
	floor_snap_length = 0.4
	_collider = CollisionShape3D.new()
	_collider.shape = CapsuleShape3D.new()
	add_child(_collider)
	FleshMound.low_poly = Settings.low_poly
	look = FleshMound.new()
	look.size = size
	look.bodies = bodies
	look.top_level = true
	add_child(look)
	look.grown.connect(_on_grown)
	look.merged.connect(_on_merged)
	_fit()
	facing_yaw = global_rotation.y
	_prev_pos = global_position
	_curr_pos = global_position
	look.global_position = global_position
	look.rotation.y = facing_yaw
	look.settle()


## Its body, for finding its way and for the walls: a core it squeezes round.
func _fit() -> void:
	var capsule := _collider.shape as CapsuleShape3D
	capsule.radius = core_radius()
	capsule.height = maxf(capsule.radius * 2.0 + 0.1, 2.0 * size)
	_collider.position.y = capsule.height * 0.5


func core_radius() -> float:
	return (0.6 if small() else 0.8) * size


func small() -> bool:
	return bodies <= FleshMoundLook.SMALL


## Half its width, about (for merging): the star's reach, or the mound's.
func girth() -> float:
	return (1.1 if small() else FleshMoundLook.radii(bodies).x) * size


func gone() -> bool:
	return mode == Mode.GONE


func _physics_process(delta: float) -> void:
	_age += delta
	if mode == Mode.GONE:
		return
	if puppet:
		if mode != Mode.MERGING:
			_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze == null or look == null:
		return
	if mode == Mode.MERGING:
		velocity = Vector3.ZERO
		return
	_sense(delta)
	_rest -= delta
	_meet_others()
	if mode == Mode.MERGING:
		return
	var after := quarry if hunting() and quarry.get(&"is_limp") != true else null
	chasing = after != null
	var wish := Vector3.ZERO
	var speed := 0.0
	if small():
		var picked := _small_moves(delta, after)
		wish = picked[0]
		speed = picked[1]
	else:
		var picked := _big_moves(after)
		wish = picked[0]
		speed = picked[1]
	_catching()
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, (acceleration * (3.0 if mode == Mode.ROLLING else 1.0)) * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


## A small one: shamble, wind up, roll, be spent. Gives the way to go and how fast.
func _small_moves(delta: float, after: Node3D) -> Array:
	var to := way(core_radius())
	var dir := to.normalized() if to.length() > 0.05 else Vector3.ZERO
	match mode:
		Mode.ABOUT, Mode.HUNTING:
			stamina = minf(1.0, stamina + delta / spent_time)
			mode = Mode.HUNTING if after else Mode.ABOUT
			if after and stamina >= 0.9 and _can_roll_at(after):
				mode = Mode.WINDING
				_rolled = 0.0
				look.start_roll()
				return [Vector3.ZERO, 0.0]
			return [dir, hunt_shamble_speed if after else shamble_speed]
		Mode.WINDING:
			if look.roll_stage() == FleshMound.Roll.ROLLING:
				mode = Mode.ROLLING
			return [Vector3.ZERO, 0.0]
		Mode.ROLLING:
			stamina -= delta / roll_time
			# (it rolls on along the hall it is in: it cannot turn much at speed)
			var forward := Vector3(-sin(facing_yaw), 0.0, -cos(facing_yaw))
			var heading := forward.slerp(dir, 0.15) if dir != Vector3.ZERO else forward
			_rolled += delta
			# (spent, or it has lost them, or it has run into a wall and stopped)
			if stamina <= 0.0 or after == null or (_rolled > 0.6 and is_on_wall() and Vector3(velocity.x, 0, velocity.z).length() < roll_speed * 0.4):
				mode = Mode.SPENT
				stamina = maxf(stamina, 0.0)
				look.stop_roll()
			return [heading.normalized(), roll_speed]
		Mode.SPENT:
			stamina += delta / spent_time
			if stamina >= 0.6:
				mode = Mode.HUNTING if after else Mode.ABOUT
			return [dir, spent_speed]
	return [Vector3.ZERO, 0.0]


## Whether it can roll at `player`: in a straight line down the hall it is in, near enough, not right on top of it.
func _can_roll_at(player: Node3D) -> bool:
	var to := player.global_position - global_position
	var far := Vector2(to.x, to.z).length()
	if far > roll_range * size or far < roll_near or absf(to.y) > 1.5:
		return false
	return nav.line_free(global_position + Vector3.UP, player.global_position + Vector3.UP, core_radius() * 0.5)


## A big one: crawl, and grab at whoever is in reach.
func _big_moves(after: Node3D) -> Array:
	mode = Mode.HUNTING if after else Mode.ABOUT
	var t := clampf(float(bodies - FleshMoundLook.SMALL - 1) / float(FleshMoundLook.MOST - FleshMoundLook.SMALL - 1), 0.0, 1.0)
	var stage := look.grab_stage()
	if stage == FleshMound.Stage.NONE:
		if after and _rest <= 0.0 and _in_reach(after):
			_grabs += 1
			_has_him.clear()
			look.grab(after.global_position)
			return [Vector3.ZERO, 0.0]
		var to := way(core_radius())
		if to.length() > 0.05:
			var wish := to.normalized()
			# It keeps to the middle of a hall, as its bulk makes it.
			var sides := look.sides()
			if sides.x < INF and sides.y < INF:
				var across := Vector3(-wish.z, 0.0, wish.x)
				var right := Vector3(cos(facing_yaw), 0.0, -sin(facing_yaw))
				var off := (sides.y - sides.x) * 0.5 * (1.0 if right.dot(across) > 0.0 else -1.0)
				wish = (wish + across * clampf(off / 8.0, -0.6, 0.6)).normalized()
			return [wish, lerpf(hunt_speeds.x, hunt_speeds.y, t) if after else lerpf(crawl_speeds.x, crawl_speeds.y, t)]
	elif stage == FleshMound.Stage.STRIKE or stage == FleshMound.Stage.HOLD:
		_rest = grab_rest
	return [Vector3.ZERO, 0.0]


func _in_reach(player: Node3D) -> bool:
	var to := player.global_position - global_position
	if absf(to.y) > 3.0 * size:
		return false
	to.y = 0.0
	var forward := Vector3(-sin(facing_yaw), 0.0, -cos(facing_yaw))
	return to.length() < minf(grab_range * size, look.reach()) and forward.dot(to.normalized()) > grab_cone


## Anyone a closing hand finds, or who has walked (or been rolled) into it, is
## caught; and absorbed: their body is dragged into it.
func _catching() -> void:
	if look.merging() >= 0.0:
		return
	for player: Node3D in players():
		if not huntable(player):
			continue
		var feet := player.global_position
		if feet.distance_to(global_position) > 30.0 * size:
			continue
		var low: bool = player.get(&"is_ducking") == true or player.get(&"is_crawling") == true
		var top := feet + Vector3.UP * (0.7 if low else 1.5)
		var got := false
		if not small() and not _has_him.has(player) and look.grab_hits(feet + Vector3.UP * 0.1, top, 0.3):
			_has_him[player] = true
			got = true
		elif look.touches(feet + Vector3.UP * 0.8, 0.2):
			got = true
		if got:
			_absorbs += 1
			look.absorb(feet)
			_catch(player)


## Another of its kind met: the smaller (or, the same, the one made later)
## flows into the other.
func _meet_others() -> void:
	if _age < 3.0 or look.absorbing() >= 0.0:
		return
	for other: Node in get_tree().get_nodes_in_group(&"flesh_mounds"):
		if other == self or not (other is MazeFleshMound):
			continue
		var them := other as MazeFleshMound
		if them.gone() or them.mode == Mode.MERGING or them.puppet or them._age < 3.0:
			continue
		var apart := Vector2(them.global_position.x - global_position.x, them.global_position.z - global_position.z).length()
		if apart - girth() - them.girth() > merge_gap * size:
			continue
		var into_them := bodies < them.bodies or (bodies == them.bodies and get_index() > them.get_index())
		if into_them:
			merge_into(them)
		else:
			them.merge_into(self)
		return


## Flows into `other` (it is gone once it has, and `other` has its bodies).
func merge_into(other: MazeFleshMound) -> void:
	mode = Mode.MERGING
	_merge_with = other
	look.stop_roll()
	look.merge_into(other.look)


func _on_merged(into: FleshMound) -> void:
	mode = Mode.GONE
	collision_layer = 0
	collision_mask = 0
	look.visible = false
	look.process_mode = Node.PROCESS_MODE_DISABLED
	if not puppet and _merge_with:
		_merge_with.grow(bodies)
	elif puppet and _merge_with == null and into:
		pass


## Gains `count` bodies (a merge, or as heard).
func grow(count: int) -> void:
	look.grow(count)


func _on_grown(count: int) -> void:
	bodies = count
	_fit()
	if not small() and mode in [Mode.WINDING, Mode.ROLLING, Mode.SPENT]:
		mode = Mode.HUNTING if chasing else Mode.ABOUT


func _process(delta: float) -> void:
	if look == null or mode == Mode.GONE:
		return
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			look.visible = not far
			look.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
			if not far:
				look.settle()
	if _far:
		return
	var aim := Vector3.INF
	if puppet:
		aim = _heard_extra
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-6.0 * delta))
	else:
		var after := quarry if chasing else null
		if after:
			aim = after.global_position + Vector3.UP * 0.8
		var heading := Vector3(velocity.x, 0.0, velocity.z)
		if after and heading.length_squared() < 0.05:
			heading = after.global_position - global_position
			heading.y = 0.0
		var turning := turn_rate * (0.5 if mode == Mode.ROLLING else (2.0 if small() else 1.0))
		if look.grab_stage() == FleshMound.Stage.NONE and mode != Mode.WINDING and heading.length_squared() > 0.01:
			facing_yaw = lerp_angle(facing_yaw, atan2(-heading.x, -heading.z), 1.0 - exp(-turning * delta))
	look.aim = aim
	look.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	look.rotation = Vector3(0.0, facing_yaw, 0.0)


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


## What it is doing (low three bits) and how many bodies are in it (the rest).
func net_state() -> int:
	return int(mode) | (bodies << 3)


## How many grabs (low four bits) and catches (high four) it has made, wrapping.
func net_flag() -> int:
	return (_grabs & 0x0f) | ((_absorbs & 0x0f) << 4)


## Where the grab under way is aimed, or else whom it is after; merging, the one it flows into.
func net_point() -> Vector3:
	if mode == Mode.MERGING and _merge_with:
		return _merge_with.global_position
	if look and look.grab_stage() != FleshMound.Stage.NONE:
		return look.grab_target()
	if chasing and quarry:
		return quarry.global_position + Vector3.UP * 0.8
	return Vector3.INF


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state & 0x07, flag, point)
	var was := mode
	mode = (state & 0x07) as Mode
	chasing = mode in [Mode.HUNTING, Mode.WINDING, Mode.ROLLING]
	var count := state >> 3
	if look == null:
		bodies = count
		return
	if _heard_flag_first:
		_heard_flag_first = false
		_grabs = flag & 0x0f
		_absorbs = flag >> 4
		if count != look.bodies:
			look.bodies = count
			bodies = count
			_fit()
	else:
		# A new grab, a new catch: made here too (the catching is the host's).
		if (flag & 0x0f) != (_grabs & 0x0f):
			_grabs = flag & 0x0f
			if point.is_finite():
				look.grab(point)
		if (flag >> 4) != (_absorbs & 0x0f):
			_absorbs = flag >> 4
			var front := global_position + Vector3(-sin(facing_yaw), 0.0, -cos(facing_yaw)) * (girth() + 0.6)
			look.absorb(front)
		elif count > look.bodies and look.absorbing() < 0.0 and mode != Mode.MERGING:
			look.grow(count - look.bodies)
	# Rolling, as its host does.
	if mode == Mode.WINDING and was != Mode.WINDING:
		look.start_roll()
	elif mode in [Mode.ABOUT, Mode.HUNTING, Mode.SPENT] and look.roll_stage() != FleshMound.Roll.NONE:
		look.stop_roll()
	# Merging: it flows into whichever is at the point it was sent.
	if mode == Mode.MERGING and was != Mode.MERGING:
		var best: MazeFleshMound = null
		for other: Node in get_tree().get_nodes_in_group(&"flesh_mounds"):
			if other != self and other is MazeFleshMound and not (other as MazeFleshMound).gone() and (other as MazeFleshMound).puppet == puppet:
				if best == null or (other as Node3D).global_position.distance_to(point) < best.global_position.distance_to(point):
					best = other
		if best:
			_merge_with = best
			look.merge_into(best.look)
	if mode == Mode.GONE and was != Mode.GONE:
		_on_merged(null)


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if look:
		look.global_position = at
		look.rotation.y = facing
		look.settle()


func _puppet_changed() -> void:
	# Players pass through it (it catches them instead); the world stops it.
	collision_layer = 0 if puppet or mode == Mode.GONE else 4
	collision_mask = 0 if mode == Mode.GONE else 1

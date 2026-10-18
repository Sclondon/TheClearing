class_name Hydra
extends Node3D
## The Lernaean hydra, to look at and to move: a huge, heavy, low reptile's
## body on four short splayed legs, with a thick tail, from the front of which
## grow up to nine long serpent necks, each with its own heavy-scaled snake's
## head (lidless eyes, a flickering forked tongue, fangs that swing down only
## when it strikes). It does no thinking: whatever drives it moves this node,
## says whether it is awake and what it is watching, and tells its heads when
## to strike.
##
## WHERE IT IS. This node is on the ground under the middle of its body; it
## faces +Z. Move it and turn it as you like (it is meant to move slowly); its
## legs step by themselves from how it moves and turns, and its tail swings.
## `wade` sinks the body that far into water (its heads still rest on the
## surface), as it lies in a marsh pool.
##
## ITS NECKS move by themselves, each on its own: every neck is a chain of
## points from its root on the hump at the front of the body to its head,
## laid along a curve from the way it grows to the way its head faces, with
## the slack taken up in a weaving S; the middle of each chain lags behind
## that shape and swings after it, so the necks sway and follow through.
## - Asleep (`awake` false), the necks lie draped about it on the ground, the
##   heads resting, now and then a tongue flickering.
## - Awake, they rise and weave, each head looking its own way about it, and
##   those near one of the points in `watch` (players, say) turn to watch it,
##   the necks spread so that it looks at things from many sides at once.
## - `strike(head, at)`: that head draws back, coiling its neck up into an S
##   with its mouth opening and hissing (WIND, `wind_up` seconds: the warning;
##   `retarget(head, at)` moves where it will go until the last `lock` of it),
##   darts at `at` (DART, `dart_time`, its fangs swung down; it reaches no
##   further than `reach()` from its root), holds there with its jaws snapped
##   shut (HOLD), and draws back (RECOVER). `stage(head)` says where it is;
##   `bites(head, a, b, radius)` whether its mouth, as it went this frame, has
##   passed within `radius` of the line from `a` to `b` (a target's feet to its
##   head): ask it every frame of DART and HOLD.
## - `sever(head)`: the head is cut off and falls, and the neck writhes as a
##   stump; after `regrow_time` two heads grow out of it (as long as there is
##   room for another: up to MAX_HEADS), taking `grow_time` to grow.
##
## LOOKS. Three draws whatever it is doing (HydraLook): the body (one mesh
## from creatures/hydra/models/hydra.glb, posed in its shader), the necks
## (one mesh of a tube to each, bent along their chains in the shader) and the
## heads (one MultiMesh of the model's head, its jaws, fangs and tongue moved
## in the shader). Nothing is built after it is made: each frame it works out
## the necks' chains (POINTS points each) and hands them to the shader. Further
## than `cull_distance` from the camera it is hidden and none of that is done.
##
## SOUND. With `voice`, a long dry hiss as each head draws back to strike,
## made here from noise.
##
## Example (see example.gd):
##     var hydra := Hydra.new()
##     hydra.heads = 7
##     add_child(hydra)
##     hydra.awake = true
##     hydra.watch = [player.global_position]
##     for head in hydra.ready_heads():
##         if hydra.can_reach(head, player.global_position):
##             hydra.strike(head, player.global_position + Vector3.UP)

## A head has begun to draw back to strike (it hisses).
signal hissed(head: int)
## A head has begun to dart at `at`.
signal struck(head: int, at: Vector3)
## A head has been cut off; a head has grown (from a stump).
signal severed(head: int)
signal grew(head: int)

enum Stage { NONE, WIND, DART, HOLD, RECOVER, STUMP, GROWING }

const MODEL := "res://creatures/hydra/models/hydra.glb"
const MODEL_LO := "res://creatures/hydra/models/hydra_lo.glb"
## Up to how many heads it can have, how many points down each neck, and how many cut-off heads lie about at once.
const MAX_HEADS := HydraLook.MAX_NECKS
const POINTS := HydraLook.POINTS
const FALLEN := 3
## How thick a neck is at its root and at its head (before `head_size`), metres.
const ROOT_GIRTH := 0.36
const HEAD_GIRTH := 0.16
## From the back of the skull (where the neck goes in) to the tip of the snout, before `head_size`.
const SNOUT := 0.95
## How long a stump is.
const STUMP := 1.3

## How many heads it starts with.
@export_range(1, 9) var heads := 7
## How long each neck is, metres, and how big its heads are (1: a metre long).
@export var neck_length := 7.5
@export var head_size := 1.3
## Seconds each part of a strike takes, and how much of the wind-up its aim is fixed for.
@export var wind_up := 0.75
@export var lock := 0.4
@export var dart_time := 0.16
@export var hold_time := 0.35
@export var recover_time := 0.9
## Seconds a stump writhes before two heads grow out of it, and how long they take to grow.
@export var regrow_time := 5.0
@export var grow_time := 2.5
## How far its body is sunk into water, metres.
@export var wade := 0.0
## Use the low-detail model and fewer rings round the necks.
@export var low_poly := false
@export var voice := true
## A number that settles its choices (how its heads are set and weave; 0: any).
@export var seed_value := 0
## Further than this from the camera it is hidden (0: never).
@export var cull_distance := 130.0

## Whether it is awake: necks up, weaving and watching (false: lying about it on the ground). It changes over a moment.
var awake := false
## Points in the world (Vector3) for its heads to watch.
var watch: Array = []
## How fast it is going (world, m/s): measured from how it moves.
var velocity := Vector3.ZERO

var _body: MeshInstance3D
var _necks: MeshInstance3D
var _neck_material: ShaderMaterial
var _heads: MultiMeshInstance3D
var _voice: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _up := 0.0
var _was := Vector3.INF
var _yaw_was := 0.0
var _turn := 0.0
var _gait := 0.0
var _stepping := 0.0
var _hidden := false
var _check_in := 0.0
# Each neck (a slot, 0 to MAX_HEADS - 1). What is there: 0 nothing, 1 a neck and head.
var _there := PackedInt32Array()
var _stage: Array[Stage] = []
var _time := PackedFloat32Array()
var _grown := PackedFloat32Array()
var _root: Array[Vector3] = []
var _root_way: Array[Vector3] = []
var _home_yaw := PackedFloat32Array()
var _home_height := PackedFloat32Array()
var _seed := PackedFloat32Array()
var _head: Array[Vector3] = []
var _head_speed: Array[Vector3] = []
var _way: Array[Vector3] = []
var _aim: Array[Vector3] = []
var _from: Array[Vector3] = []
var _jaw := PackedFloat32Array()
var _fangs := PackedFloat32Array()
var _tongue := PackedFloat32Array()
var _flick_in := PackedFloat32Array()
var _flick := PackedFloat32Array()
var _watching := PackedInt32Array()
var _glance_in := PackedFloat32Array()
var _tip_was: Array[Vector3] = []
var _tip_now: Array[Vector3] = []
var _chain: Array[PackedVector3Array] = []
var _spine := PackedVector4Array()
var _sides := PackedVector4Array()
# The cut-off heads lying about: where (local), which way, how long since.
var _fallen: Array[Dictionary] = []

static var _hiss: AudioStreamWAV


func _ready() -> void:
	_rng.seed = seed_value if seed_value != 0 else hash(get_instance_id())
	var model := (load(MODEL_LO if low_poly else MODEL) as PackedScene).instantiate()
	var head_mesh: Mesh
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if part.name.begins_with("head"):
			head_mesh = part.mesh
		else:
			_body = part
	_body.get_parent().remove_child(_body)
	_body.owner = null
	model.free()
	_body.material_override = HydraLook.body_material()
	_body.custom_aabb = AABB(Vector3(-3.5, -0.5, -7.5), Vector3(7.0, 3.5, 11.0))
	add_child(_body)

	var rings := 20 if low_poly else 34
	var round := 8 if low_poly else 12
	_necks = MeshInstance3D.new()
	_necks.name = "Necks"
	_necks.mesh = HydraLook.neck_mesh(MAX_HEADS, rings, round, neck_length, _girth)
	_neck_material = HydraLook.neck_material()
	_necks.material_override = _neck_material
	var span := neck_length + 4.0
	_necks.custom_aabb = AABB(Vector3(-span, -1.0, -span), Vector3(span * 2.0, span + 2.0, span * 2.0))
	add_child(_necks)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.use_colors = true
	multimesh.mesh = head_mesh
	multimesh.instance_count = MAX_HEADS + FALLEN
	# (the heads' colours are the model's: an instance's own colour is left white)
	for k in multimesh.instance_count:
		multimesh.set_instance_color(k, Color.WHITE)
	_heads = MultiMeshInstance3D.new()
	_heads.name = "Heads"
	_heads.multimesh = multimesh
	_heads.material_override = HydraLook.head_material()
	_heads.custom_aabb = _necks.custom_aabb
	add_child(_heads)

	_spine.resize(MAX_HEADS * POINTS)
	_sides.resize(MAX_HEADS * POINTS)
	for slot in MAX_HEADS:
		_there.append(0)
		_stage.append(Stage.NONE)
		_time.append(0.0)
		_grown.append(1.0)
		_root.append(Vector3.ZERO)
		_root_way.append(Vector3.UP)
		_home_yaw.append(0.0)
		_home_height.append(2.6)
		_seed.append(_rng.randf() * 100.0)
		_head.append(Vector3.ZERO)
		_head_speed.append(Vector3.ZERO)
		_way.append(Vector3.FORWARD)
		_aim.append(Vector3.ZERO)
		_from.append(Vector3.ZERO)
		_jaw.append(0.0)
		_fangs.append(0.0)
		_tongue.append(0.0)
		_flick_in.append(_rng.randf_range(0.5, 4.0))
		_flick.append(0.0)
		_watching.append(-1)
		_glance_in.append(_rng.randf_range(0.5, 3.0))
		_tip_was.append(Vector3.ZERO)
		_tip_now.append(Vector3.ZERO)
		var chain := PackedVector3Array()
		chain.resize(POINTS)
		_chain.append(chain)
	var count := clampi(heads, 1, MAX_HEADS)
	for slot in count:
		var u := (float(slot) + 0.5) / float(count) * 2.0 - 1.0
		_place_root(slot, u, slot % 2)
		_there[slot] = 1
	if voice:
		_voice = AudioStreamPlayer3D.new()
		_voice.stream = hiss_sound()
		_voice.max_polyphony = 4
		_voice.unit_size = 10.0
		_voice.max_distance = 70.0
		_voice.position = Vector3(0.0, 3.0, 2.5)
		add_child(_voice)
	settle()


## Sets where a neck grows from, `u` (-1 its right to 1 its left) across the hump, in the back row (0) or the front (1).
func _place_root(slot: int, u: float, row: int) -> void:
	_root[slot] = Vector3(u * 0.95, 1.62 - row * 0.14 - 0.1 * u * u, 1.72 + row * 0.32 - 0.25 * u * u)
	_root_way[slot] = Vector3(u * 0.8, 1.0, 0.55 + row * 0.25).normalized()
	_home_yaw[slot] = u * 1.35 + _rng.randf_range(-0.12, 0.12)
	_home_height[slot] = 3.7 + _rng.randf_range(-0.6, 1.3)


# How thick a neck is along it (0 its root, 1 its head), before it is scaled.
func _girth(t: float) -> float:
	var thick := lerpf(ROOT_GIRTH, HEAD_GIRTH * head_size, smoothstep(0.0, 0.85, t))
	# (it swells a little behind the head, and widens into the body at the root)
	thick *= 1.0 + 0.1 * sin(clampf((t - 0.75) / 0.25, 0.0, 1.0) * PI) + 0.35 * (1.0 - smoothstep(0.0, 0.08, t))
	return thick


## Puts it straight somewhere, facing `yaw` (0 faces +Z), with its necks where they would be.
func put(at: Vector3, yaw: float) -> void:
	global_position = at
	rotation.y = yaw
	settle()


## Settles it as it is now: nothing moving, every neck where it would be.
func settle() -> void:
	_was = global_position
	_yaw_was = global_rotation.y
	velocity = Vector3.ZERO
	_up = 1.0 if awake else 0.0
	for slot in MAX_HEADS:
		if _there[slot] == 0:
			continue
		var goal := _rest_goal(slot)
		_head[slot] = goal[0]
		_way[slot] = goal[1]
		_head_speed[slot] = Vector3.ZERO
		_lay_chain(slot, 1.0, true)
	_draw_heads()
	_draw_necks()


# --- Telling it what to do ---

## The heads it has (those there, grown, whole or not).
func head_slots() -> Array[int]:
	var found: Array[int] = []
	for slot in MAX_HEADS:
		if _there[slot] == 1 and _stage[slot] != Stage.STUMP:
			found.append(slot)
	return found


## The heads that could strike now (not striking, cut or growing).
func ready_heads() -> Array[int]:
	var found: Array[int] = []
	for slot in MAX_HEADS:
		if _there[slot] == 1 and _stage[slot] == Stage.NONE:
			found.append(slot)
	return found


## How many heads it has (stumps not counted).
func head_count() -> int:
	return head_slots().size()


## How far from its root a head's mouth can reach, metres.
func reach() -> float:
	return neck_length * 0.97 + SNOUT * head_size


## Where a neck grows from (world).
func root_of(slot: int) -> Vector3:
	return to_global(_root[slot] - Vector3.UP * wade)


## Whether a head could reach `at` (world).
func can_reach(slot: int, at: Vector3) -> bool:
	return _there[slot] == 1 and root_of(slot).distance_to(at) < reach()


## Where a head's mouth is now (world), and its head (the back of its skull).
func mouth_of(slot: int) -> Vector3:
	return to_global(_head[slot] + _way[slot] * SNOUT * head_size * _head_scale(slot))


func head_of(slot: int) -> Vector3:
	return to_global(_head[slot])


func stage(slot: int) -> Stage:
	return _stage[slot]


## How far through its stage a head is, 0..1.
func progress(slot: int) -> float:
	match _stage[slot]:
		Stage.WIND:
			return clampf(_time[slot] / wind_up, 0.0, 1.0)
		Stage.DART:
			return clampf(_time[slot] / dart_time, 0.0, 1.0)
		Stage.HOLD:
			return clampf(_time[slot] / hold_time, 0.0, 1.0)
		Stage.RECOVER:
			return clampf(_time[slot] / recover_time, 0.0, 1.0)
		Stage.STUMP:
			return clampf(_time[slot] / regrow_time, 0.0, 1.0)
		Stage.GROWING:
			return _grown[slot]
	return 0.0


## Seconds until a head darts (INF when it is not winding up).
func strikes_in(slot: int) -> float:
	return wind_up - _time[slot] if _stage[slot] == Stage.WIND else INF


## Where a head will strike (world), once it is winding up.
func aim_of(slot: int) -> Vector3:
	return to_global(_aim[slot])


## A head draws back to strike at `at` (world). False if it cannot now.
func strike(slot: int, at: Vector3) -> bool:
	if slot < 0 or slot >= MAX_HEADS or _there[slot] != 1 or _stage[slot] != Stage.NONE:
		return false
	_set_stage(slot, Stage.WIND)
	_aim[slot] = _reachable(slot, to_local(at))
	hissed.emit(slot)
	if _voice and is_inside_tree() and not _hidden:
		_voice.pitch_scale = _rng.randf_range(0.82, 1.15)
		_voice.play()
	return true


## Moves where a winding-up head will strike, until the last `lock` seconds of its wind-up.
func retarget(slot: int, at: Vector3) -> void:
	if _stage[slot] == Stage.WIND and _time[slot] < wind_up - lock:
		_aim[slot] = _reachable(slot, to_local(at))


## Whether a head's mouth, as it went this frame, passed within `radius` of the line from `a` to `b` (world). Only at the end of its dart and while it holds.
func bites(slot: int, a: Vector3, b: Vector3, radius: float) -> bool:
	if _there[slot] != 1 or _stage[slot] not in [Stage.DART, Stage.HOLD]:
		return false
	# (it bites at the end of its dart, where its jaws close: flying past on the way there it is only a head going by)
	if _stage[slot] == Stage.DART and _time[slot] < dart_time * 0.55:
		return false
	var near := Geometry3D.get_closest_points_between_segments(_tip_was[slot], _tip_now[slot], a, b)
	return (near[0] as Vector3).distance_to(near[1]) < radius + 0.28 * head_size


## Cuts a head off: it falls, and its neck writhes as a stump until two grow out of it. False if there is no head there to cut.
func sever(slot: int) -> bool:
	if slot < 0 or slot >= MAX_HEADS or _there[slot] != 1 or _stage[slot] in [Stage.STUMP, Stage.GROWING]:
		return false
	var fallen := {"at": _head[slot], "way": _way[slot], "fall": 0.0, "time": 0.0, "seed": _seed[slot], "size": _head_scale(slot)}
	if _fallen.size() >= FALLEN:
		_fallen.pop_front()
	_fallen.append(fallen)
	_set_stage(slot, Stage.STUMP)
	_head_speed[slot] = Vector3.ZERO
	severed.emit(slot)
	return true


## The head nearest `at` (world) whose head or neck passes within `radius` of it, or -1.
func head_near(at: Vector3, radius: float) -> int:
	var local := to_local(at)
	var best := -1
	var far := radius
	for slot in MAX_HEADS:
		if _there[slot] != 1 or _stage[slot] in [Stage.STUMP, Stage.GROWING]:
			continue
		var chain := _chain[slot]
		for i in range(POINTS / 2, POINTS):
			var d := chain[i].distance_to(local)
			if d < far:
				far = d
				best = slot
	return best


func _set_stage(slot: int, next: Stage) -> void:
	if next == Stage.DART:
		_from[slot] = _head[slot]
		struck.emit(slot, to_global(_aim[slot]))
	_stage[slot] = next
	_time[slot] = 0.0


# A point (local) within its reach, its mouth's tip there, no lower than the ground.
func _reachable(slot: int, at: Vector3) -> Vector3:
	var root := _root[slot] - Vector3.UP * wade
	var out := at - root
	var most := reach()
	if out.length() > most:
		out = out.normalized() * most
	var p := root + out
	p.y = maxf(p.y, 0.15)
	return p


# --- Moving ---

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_check_in -= delta
	if _check_in <= 0.0:
		_check_in = 0.4
		var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
		var hide := cull_distance > 0.0 and camera != null and camera.global_position.distance_to(global_position) > cull_distance
		if hide != _hidden:
			_hidden = hide
			_body.visible = not hide
			_necks.visible = not hide
			_heads.visible = not hide
	_clock += delta
	_up = move_toward(_up, 1.0 if awake else 0.0, delta / 1.6)
	# How it moves and turns (for its legs and tail).
	if _was.is_finite():
		var moved := (global_position - _was) / delta
		velocity = velocity.lerp(moved, 1.0 - exp(-8.0 * delta))
		_turn = lerpf(_turn, angle_difference(_yaw_was, global_rotation.y) / delta, 1.0 - exp(-6.0 * delta))
	_was = global_position
	_yaw_was = global_rotation.y
	for slot in MAX_HEADS:
		if _there[slot] != 0:
			_move_head(slot, delta)
	for fallen in _fallen:
		_drop(fallen, delta)
	if _fallen.size() > 0 and _fallen[0]["time"] > 40.0:
		_fallen.pop_front()
	if _hidden:
		return
	_pose_body(delta)
	_draw_heads()
	_draw_necks()


# Where a head would be and which way it would face when it is not striking: lying down asleep, weaving awake.
func _rest_goal(slot: int) -> Array:
	var root := _root[slot] - Vector3.UP * wade
	var s := _seed[slot]
	var t := _clock
	var grown := _grown[slot] if _stage[slot] == Stage.GROWING else 1.0
	# Asleep: lying out on the ground, the head resting, stirring a little.
	var yaw := _home_yaw[slot] + 0.15 * sin(t * 0.13 + s)
	var lie := Vector3(sin(yaw), 0.0, cos(yaw)) * neck_length * 0.55 * grown
	var low := Vector3(root.x + lie.x, 0.28 * head_size + 0.03 * sin(t * 0.7 + s), root.z + lie.z)
	var low_way := Vector3(sin(yaw + 0.25 * sin(s)), -0.04, cos(yaw + 0.25 * sin(s))).normalized()
	if _up <= 0.001:
		return [low, low_way]
	# Awake: up and weaving, each head its own way, turned towards what it is watching.
	var looking := Vector3.INF
	var w := _watching[slot]
	if w >= 0 and w < watch.size() and watch[w] is Vector3:
		looking = to_local(watch[w])
	var wander := _home_yaw[slot] + 0.55 * sin(t * (0.21 + fmod(s, 0.13)) + s) + 0.25 * sin(t * 0.53 + s * 2.0)
	var toward := wander
	if looking.is_finite():
		var flat := looking - root
		var aim_yaw := atan2(flat.x, flat.z)
		toward = wander + angle_difference(wander, aim_yaw) * 0.42
	var out := neck_length * (0.4 + 0.08 * sin(t * 0.37 + s * 3.0)) * grown
	var high := (_home_height[slot] + 0.45 * sin(t * (0.43 + fmod(s, 0.2)) + s * 1.7)) * lerpf(0.5, 1.0, grown)
	var up_at := Vector3(root.x + sin(toward) * out, high, root.z + cos(toward) * out)
	# (and a little sideways sway of its own)
	up_at += Vector3(cos(toward), 0.0, -sin(toward)) * 0.5 * sin(t * (0.9 + fmod(s, 0.4)) + s * 5.0)
	var up_way: Vector3
	if looking.is_finite():
		up_way = (looking - up_at).normalized()
	else:
		up_way = Vector3(sin(toward + 0.4 * sin(t * 0.7 + s)), -0.2 + 0.18 * sin(t * 0.31 + s), cos(toward + 0.4 * sin(t * 0.7 + s))).normalized()
	var k := smoothstep(0.0, 1.0, _up)
	return [low.lerp(up_at, k), low_way.slerp(up_way, k).normalized()]


func _move_head(slot: int, delta: float) -> void:
	_time[slot] += delta
	var root := _root[slot] - Vector3.UP * wade
	var s := _seed[slot]
	var goal := Vector3.ZERO
	var goal_way := Vector3.FORWARD
	var stiff := 3.2
	var jaw := 0.0
	var fangs := 0.0
	var direct := false
	match _stage[slot]:
		Stage.NONE, Stage.GROWING:
			var rest := _rest_goal(slot)
			goal = rest[0]
			goal_way = rest[1]
			stiff = lerpf(1.6, 2.6, _up)
			if _stage[slot] == Stage.GROWING:
				_grown[slot] = minf(_grown[slot] + delta / grow_time, 1.0)
				if _grown[slot] >= 1.0:
					_set_stage(slot, Stage.NONE)
					grew.emit(slot)
		Stage.WIND:
			# Drawn back and up, its neck coiled into an S, mouth opening, trembling.
			var w := clampf(_time[slot] / wind_up, 0.0, 1.0)
			var to := _aim[slot] - root
			var flat := Vector3(to.x, 0.0, to.z).normalized() if Vector2(to.x, to.z).length() > 0.1 else Vector3.BACK
			goal = root + Vector3.UP * (1.9 + 0.4 * w) * lerpf(1.0, 1.25, head_size - 1.0) - flat * 0.7 + flat * 1.2 * (1.0 - w)
			goal += Vector3(sin(_clock * 37.0 + s), cos(_clock * 41.0 + s), 0.0) * 0.03 * w
			goal_way = (_aim[slot] - _head[slot]).normalized()
			stiff = 9.0
			jaw = 0.35 * smoothstep(0.2, 0.9, w)
			fangs = 0.25 * smoothstep(0.5, 1.0, w)
			if _time[slot] >= wind_up:
				_set_stage(slot, Stage.DART)
		Stage.DART:
			var d := clampf(_time[slot] / dart_time, 0.0, 1.0)
			var target := _aim[slot] - (_aim[slot] - _from[slot]).normalized() * SNOUT * head_size
			_head[slot] = _from[slot].lerp(target, 1.0 - pow(1.0 - d, 2.4))
			_way[slot] = (_aim[slot] - _from[slot]).normalized()
			direct = true
			jaw = 1.0
			fangs = 1.0
			if _time[slot] >= dart_time:
				_set_stage(slot, Stage.HOLD)
		Stage.HOLD:
			var h := clampf(_time[slot] / hold_time, 0.0, 1.0)
			# (jaws snapped shut on whatever it has, worrying at it)
			jaw = lerpf(1.0, 0.12, smoothstep(0.0, 0.25, h))
			fangs = 1.0
			_head[slot] += Vector3(sin(_clock * 23.0 + s), cos(_clock * 19.0), 0.0) * 0.015
			direct = true
			if _time[slot] >= hold_time:
				_set_stage(slot, Stage.RECOVER)
		Stage.RECOVER:
			var r := clampf(_time[slot] / recover_time, 0.0, 1.0)
			var rest := _rest_goal(slot)
			goal = rest[0]
			goal_way = rest[1]
			stiff = lerpf(4.0, 2.6, r)
			jaw = 0.12 * (1.0 - r)
			fangs = 1.0 - smoothstep(0.0, 0.5, r)
			if _time[slot] >= recover_time:
				_set_stage(slot, Stage.NONE)
		Stage.STUMP:
			# Writhing, short, its cut end raw.
			var wr := Vector3(sin(_clock * 3.1 + s), 0.4 + 0.5 * sin(_clock * 2.3 + s * 2.0), cos(_clock * 2.7 + s)) * 0.6
			goal = root + _root_way[slot] * STUMP + wr
			goal_way = (_root_way[slot] + wr).normalized()
			stiff = 6.0
			if _time[slot] >= regrow_time:
				_regrow(slot)
				return
	if not direct:
		# A spring, just damped: it comes to where it should be without overshooting much.
		var to := goal - _head[slot]
		_head_speed[slot] += (to * stiff * stiff - _head_speed[slot] * 2.0 * stiff * 0.85) * delta
		_head[slot] += _head_speed[slot] * delta
		_way[slot] = _way[slot].slerp(goal_way.normalized(), 1.0 - exp(-stiff * 1.4 * delta)).normalized()
	else:
		_head_speed[slot] = Vector3.ZERO
	_head[slot].y = maxf(_head[slot].y, 0.12 * head_size)
	var length := neck_length * (STUMP / neck_length if _stage[slot] == Stage.STUMP else maxf(_grown[slot], 0.08))
	var out := _head[slot] - root
	if out.length() > length * 0.98:
		_head[slot] = root + out.normalized() * length * 0.98
	_jaw[slot] = lerpf(_jaw[slot], jaw, 1.0 - exp(-(30.0 if jaw > _jaw[slot] else 14.0) * delta))
	_fangs[slot] = lerpf(_fangs[slot], fangs, 1.0 - exp(-24.0 * delta))
	# Its tongue flickers now and then (more when awake, often when watching something).
	_flick_in[slot] -= delta
	if _flick_in[slot] <= 0.0 and _stage[slot] in [Stage.NONE, Stage.RECOVER, Stage.GROWING]:
		_flick_in[slot] = _rng.randf_range(0.8, 3.5) * (1.6 - _up)
		_flick[slot] = 0.55
	_flick[slot] -= delta
	_tongue[slot] = lerpf(_tongue[slot], 1.0 if _flick[slot] > 0.0 else 0.0, 1.0 - exp(-22.0 * delta))
	# Now and then it looks at something else.
	_glance_in[slot] -= delta
	if _glance_in[slot] <= 0.0:
		_glance_in[slot] = _rng.randf_range(1.5, 5.0)
		_watching[slot] = _pick_watch(slot)
	_lay_chain(slot, delta, false)
	_tip_was[slot] = _tip_now[slot]
	_tip_now[slot] = mouth_of(slot)
	if _stage[slot] == Stage.DART and _time[slot] <= delta * 1.01:
		_tip_was[slot] = to_global(_from[slot] + _way[slot] * SNOUT * head_size)


# Which of `watch` a head looks at: the nearest it could reach, mostly; now and then none (it looks about).
func _pick_watch(slot: int) -> int:
	if watch.is_empty() or _rng.randf() < 0.25:
		return -1
	var root := root_of(slot)
	var best := -1
	var far := INF
	for i in watch.size():
		if not (watch[i] is Vector3):
			continue
		var d := root.distance_to(watch[i]) + _rng.randf_range(0.0, 6.0)
		if d < far:
			far = d
			best = i
	return best


# Two heads grow out of a stump (one, if it already has as many as it can).
func _regrow(slot: int) -> void:
	_set_stage(slot, Stage.GROWING)
	_grown[slot] = 0.08
	_head_speed[slot] = Vector3.ZERO
	var spare := -1
	for other in MAX_HEADS:
		if _there[other] == 0:
			spare = other
			break
	if spare >= 0:
		_there[spare] = 1
		var side := Vector3(_root_way[slot].z, 0.0, -_root_way[slot].x).normalized() * 0.24
		_root[spare] = _root[slot] + side
		_root[slot] -= side
		_root_way[spare] = (_root_way[slot] + side).normalized()
		_home_yaw[spare] = _home_yaw[slot] + 0.35
		_home_yaw[slot] -= 0.35
		_home_height[spare] = _home_height[slot] + _rng.randf_range(-0.4, 0.4)
		_set_stage(spare, Stage.GROWING)
		_grown[spare] = 0.08
		_head[spare] = _head[slot]
		_way[spare] = _way[slot]
		_head_speed[spare] = Vector3.ZERO
		_chain[spare] = _chain[slot].duplicate()
		_tip_now[spare] = _tip_now[slot]


func _head_scale(slot: int) -> float:
	if _there[slot] != 1 or _stage[slot] == Stage.STUMP:
		return 0.0
	return lerpf(0.45, 1.0, _grown[slot]) if _stage[slot] == Stage.GROWING else 1.0


# Lays a neck's chain from its root to its head: a curve from the way it grows to the way the head faces, the
# slack in it taken up in a weaving S, and the middle of it following that shape with a lag (`now`: at once).
func _lay_chain(slot: int, delta: float, now: bool) -> void:
	var root := _root[slot] - Vector3.UP * wade
	var head := _head[slot]
	var way := _way[slot]
	var stump := _stage[slot] == Stage.STUMP
	var length := STUMP if stump else neck_length * (_grown[slot] if _stage[slot] == Stage.GROWING else 1.0)
	var reach_out := root.distance_to(head)
	var c1 := root + _root_way[slot] * minf(length * 0.3, reach_out * 0.6 + 0.5)
	var c2 := head - way * minf(length * 0.25, reach_out * 0.5 + 0.4)
	var shape := PackedVector3Array()
	shape.resize(POINTS)
	var along := 0.0
	for i in POINTS:
		var t := float(i) / float(POINTS - 1)
		var u := 1.0 - t
		shape[i] = root * (u * u * u) + c1 * (3.0 * u * u * t) + c2 * (3.0 * u * t * t) + head * (t * t * t)
		if i > 0:
			along += shape[i].distance_to(shape[i - 1])
	var slack := maxf(length - along, 0.0)
	if slack > 0.01:
		var s := _seed[slot]
		var phase := s + _clock * 0.45
		for i in range(1, POINTS - 1):
			var t := float(i) / float(POINTS - 1)
			var going := (shape[i + 1] - shape[i - 1]).normalized()
			var side := going.cross(Vector3.UP)
			if side.length() < 0.2:
				side = going.cross(Vector3.RIGHT)
			side = side.normalized()
			var lift := side.cross(going).normalized()
			var bow := sin(PI * t) * slack * 0.32
			shape[i] += side * bow * sin(TAU * t * 0.9 + phase) + lift * bow * 0.45 * cos(TAU * t * 0.7 + phase * 1.3)
	var chain := _chain[slot]
	var striking := _stage[slot] in [Stage.DART, Stage.HOLD]
	for i in POINTS:
		if now or i == 0 or i == POINTS - 1:
			chain[i] = shape[i]
			continue
		var t := float(i) / float(POINTS - 1)
		# (stiff at the root and near the head, loose in the middle; all of it stiff as it darts)
		var stiff := 26.0 if striking else lerpf(14.0, 5.0, sin(PI * t)) + 10.0 * t * t
		chain[i] = chain[i].lerp(shape[i], 1.0 - exp(-stiff * delta))
	# (no link much longer than it should be: the middle cannot stretch away from the ends)
	var link := length / float(POINTS - 1) * 1.25
	for i in range(1, POINTS - 1):
		var back := chain[i] - chain[i - 1]
		if back.length() > link:
			chain[i] = chain[i - 1] + back.normalized() * link
	for i in POINTS:
		chain[i].y = maxf(chain[i].y, 0.1 if i > 0 else -10.0)
	_chain[slot] = chain


func _drop(fallen: Dictionary, delta: float) -> void:
	fallen["time"] += delta
	var at: Vector3 = fallen["at"]
	var lying := 0.22 * head_size * float(fallen["size"])
	if at.y > lying:
		fallen["fall"] += 14.0 * delta
		at.y = maxf(at.y - fallen["fall"] * delta, lying)
		fallen["at"] = at
	# (and after a while it sinks into the ground)
	if fallen["time"] > 30.0:
		at.y -= delta * 0.1
		fallen["at"] = at


# --- Drawing ---

func _draw_heads() -> void:
	var multimesh := _heads.multimesh
	for slot in MAX_HEADS:
		var size := _head_scale(slot) * head_size
		if size <= 0.0:
			multimesh.set_instance_transform(slot, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			continue
		var way := _way[slot]
		var up := Vector3.UP
		if absf(way.dot(up)) > 0.95:
			up = Vector3.BACK
		var basis := Basis.looking_at(way, up, true)
		# (a slow roll of the head as it weaves)
		basis = basis * Basis(Vector3.BACK, 0.12 * sin(_clock * 0.8 + _seed[slot]) * _up)
		multimesh.set_instance_transform(slot, Transform3D(basis.scaled_local(Vector3.ONE * size), _head[slot]))
		multimesh.set_instance_custom_data(slot, Color(_jaw[slot], _tongue[slot], fmod(_seed[slot], 1.0), _fangs[slot]))
	for k in FALLEN:
		var index := MAX_HEADS + k
		if k >= _fallen.size():
			multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			continue
		var fallen := _fallen[k]
		var way: Vector3 = fallen["way"]
		way.y = 0.0
		if way.length() < 0.1:
			way = Vector3.FORWARD
		var basis := Basis.looking_at(way.normalized(), Vector3.UP, true) * Basis(Vector3.BACK, 1.3)
		var size := head_size * float(fallen["size"])
		multimesh.set_instance_transform(index, Transform3D(basis.scaled_local(Vector3.ONE * size), fallen["at"]))
		multimesh.set_instance_custom_data(index, Color(0.55, 0.2, fmod(float(fallen["seed"]), 1.0), 0.6))


func _draw_necks() -> void:
	for slot in MAX_HEADS:
		var base := slot * POINTS
		if _there[slot] == 0:
			for i in POINTS:
				_spine[base + i] = Vector4(0.0, -50.0, 0.0, 0.0)
			continue
		var chain := _chain[slot]
		var thick := 1.0
		if _stage[slot] == Stage.GROWING:
			thick = lerpf(0.4, 1.0, _grown[slot])
		# The way that is its left down the neck, carried from the root without twisting.
		var side := _root_way[slot].cross(Vector3.UP)
		if side.length() < 0.1:
			side = Vector3.RIGHT
		side = (-side).normalized()
		for i in POINTS:
			var going := (chain[mini(i + 1, POINTS - 1)] - chain[maxi(i - 1, 0)])
			if going.length() > 0.001:
				going = going.normalized()
				side = (side - going * side.dot(going))
				side = side.normalized() if side.length() > 0.001 else going.cross(Vector3.UP).normalized()
			var p := chain[i]
			_spine[base + i] = Vector4(p.x, p.y, p.z, thick)
			_sides[base + i] = Vector4(side.x, side.y, side.z, 0.0)
	_neck_material.set_shader_parameter(&"spine", _spine)
	_neck_material.set_shader_parameter(&"sides", _sides)


func _pose_body(delta: float) -> void:
	var local := global_basis.inverse() * velocity
	var speed := Vector2(local.x, local.z).length()
	var stepping := clampf(maxf(speed / 0.3, absf(_turn) / 0.25), 0.0, 1.0)
	_stepping = lerpf(_stepping, stepping, 1.0 - exp(-5.0 * delta))
	_gait += (speed / 1.6 + absf(_turn) * 0.9) * delta
	var swing := Vector4.ZERO
	var lift := Vector4.ZERO
	if _stepping > 0.01:
		var turning := signf(_turn) if absf(_turn) > speed * 0.5 else 0.0
		for leg in 4:
			var left := leg % 2 == 0
			# (diagonal pairs together: left fore with right hind, right fore with left hind)
			var offset := 0.0 if (leg == 0 or leg == 3) else 0.5
			var phase := (_gait + offset) * TAU
			var forward := sin(phase) * 0.38
			# (turning on the spot, the front legs step one way and the hind legs the other)
			if turning != 0.0:
				forward = sin(phase) * 0.3 * (1.0 if leg < 2 else -1.0) * turning * (1.0 if left else -1.0)
			var value := forward * (-1.0 if left else 1.0) * _stepping
			var raise := maxf(cos(phase), 0.0) * 0.32 * _stepping
			match leg:
				0:
					swing.x = value
					lift.x = raise
				1:
					swing.y = value
					lift.y = raise
				2:
					swing.z = value
					lift.z = raise
				3:
					swing.w = value
					lift.w = raise
	var breath := 0.5 + 0.5 * sin(_clock * (0.9 + 0.5 * _up))
	# The tail: swung against the turn, and a slow wave down it (quicker as it walks).
	var bend := clampf(-_turn * 0.8, -1.2, 1.2)
	var wave := _clock * (0.6 + speed * 1.5)
	_body.set_instance_shader_parameter(&"swing", swing)
	_body.set_instance_shader_parameter(&"lift", lift)
	_body.set_instance_shader_parameter(&"tail", Vector4(bend, wave, 0.18 + 0.2 * _stepping, breath))
	_body.set_instance_shader_parameter(&"heave", Vector4(0.06, 0.0, 0.0, 0.0))
	# (the body rolls a little with its steps, and rides lower as it settles)
	var roll := sin(_gait * TAU) * 0.025 * _stepping
	_body.transform = Transform3D(Basis(Vector3.BACK, roll), Vector3(0.0, -wade + 0.04 * _stepping * absf(sin(_gait * TAU * 2.0)), 0.0))


# --- Its voice ---

## A long dry hiss, made here: noise, the low end taken out, swelling in and
## breaking off, with a rasp through it.
static func hiss_sound() -> AudioStreamWAV:
	if _hiss:
		return _hiss
	var rate := 22050
	var length := 1.1
	var count := int(rate * length)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var last := 0.0
	var low := 0.0
	for i in count:
		var t := float(i) / rate
		var noise := rng.randf_range(-1.0, 1.0)
		# (a high pass: the low end taken out of the noise, a little of it kept for breath)
		low = lerpf(low, noise, 0.25)
		var high := noise - low
		var breath := lerpf(last, noise, 0.08)
		last = breath
		var shape := smoothstep(0.0, 0.18, t) * (1.0 - smoothstep(length - 0.35, length, t))
		var rasp := 0.75 + 0.25 * sin(t * TAU * 38.0)
		var sample := (high * 0.8 + breath * 0.6) * shape * rasp * 0.55
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32000.0))
	_hiss = AudioStreamWAV.new()
	_hiss.format = AudioStreamWAV.FORMAT_16_BITS
	_hiss.mix_rate = rate
	_hiss.stereo = false
	_hiss.data = data
	return _hiss

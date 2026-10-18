class_name Colossus
extends Node3D
## A colossus, after Shadow of the Colossus: a giant a hundred metres tall, of
## dark matted fur over earth, armoured in great slabs of weathered stone grown
## over with moss and grass and hung with vines, a stone mask for a face with a
## pale light in its eyes, and runes cut into its stone that glow. It walks in
## slow, enormous strides, each foot lifted high (over a wall, if it has to)
## and set down with a thud that shakes the ground, dust rolling out from under
## it and stones and clods of earth falling from it. It can stop, bend, and
## reach down with one great hand to sweep the ground.
##
## This is only how it looks, moves and sounds. It does no thinking: a game
## says where each foot goes (`step`), which way it faces (`facing`), what it
## looks at and what it reaches for. Its body follows its feet by itself.
##
##     var giant := Colossus.new()
##     add_child(giant)
##     giant.put(spot, yaw)                            # standing, feet either side of spot
##     # when you like (it lifts the foot over anything up to `clear` metres high):
##     giant.step(Colossus.LEFT, where, foot_yaw, clear)
##     giant.footfall.connect(func(foot, point): ...)  # it has come down: crush what is under it
##     giant.facing = yaw                              # it turns its body to this (0 faces +Z)
##     giant.look_at_point = player_position           # its head turns to it (INF: looks ahead)
##     giant.reach(target)                             # bend, hover, strike, sweep, rise
##     giant.reach_target = target                     # it follows this while its hand hovers
##     if giant.hand_hits(point, 2.5): ...             # while reach_stage() is STRIKE or SWEEP
##     if giant.under_foot(Colossus.LEFT, point): ...  # inside a foot's print
##
## The model is creatures/colossus/models/colossus.glb (and colossus_lo.glb),
## built in Blender by tools/build_colossus.py: 10 units tall, scaled here to
## `height` metres. Each bone is posed in code from where its joints are
## (two-bone reaches for the legs and arms), as the baboon is.

## A foot has come down at `point` (on the ground): now is the time to crush
## whatever is under it (`under_foot`), shake the ground and so on.
signal footfall(foot: int, point: Vector3)
## A foot has been lifted, to go to `to`.
signal lifted(foot: int, to: Vector3)
## A reaching hand has struck the ground at `point`.
signal hand_down(point: Vector3)

enum Reach { NONE, BEND, HOVER, STRIKE, SWEEP, RISE }

const LEFT := 0
const RIGHT := 1

const MODEL := "res://creatures/colossus/models/colossus.glb"
const MODEL_LO := "res://creatures/colossus/models/colossus_lo.glb"
## How tall the model is in its own units.
const UNITS := 10.0
const BONES: Array[StringName] = [
	&"pelvis", &"spine", &"chest", &"neck", &"head",
	&"upper_arm_l", &"forearm_l", &"hand_l", &"fingers_l", &"thigh_l", &"shin_l", &"foot_l",
	&"upper_arm_r", &"forearm_r", &"hand_r", &"fingers_r", &"thigh_r", &"shin_r", &"foot_r",
]
enum { PELVIS, SPINE, CHEST, NECK, HEAD, ARM_L, FOREARM_L, HAND_L, FINGERS_L, THIGH_L, SHIN_L, FOOT_L,
	ARM_R, FOREARM_R, HAND_R, FINGERS_R, THIGH_R, SHIN_R, FOOT_R }
## A foot's print about the ground point under its ankle, in model units: how
## far across either side, and how far back and forward.
const PRINT_ACROSS := 0.34
const PRINT_BACK := 0.36
const PRINT_FORWARD := 0.82

## How tall it stands, metres.
@export var height := 120.0
## Use the low-poly model.
@export var low_poly := false
## Its own shadow (the low-poly model casts it, whichever is drawn).
@export var casts_shadow := true
## Further than this from the camera (metres), the low-poly model is drawn
## instead (it rides the same skeleton): the mist hides the difference. 0: never.
@export var lod_distance := 280.0
## Its footfalls (a deep thud and a rumble as a foot comes down), made in code.
@export var sound := true
@export var volume_db := 8.0
@export var sound_range := 700.0
## How long a step takes, seconds (a long step over a wall takes longer).
@export var step_time := 3.6
## How fast its body turns to `facing`, radians a second.
@export var turn_rate := 0.3
## How long its hand hovers over what it reaches for before it strikes, seconds.
@export var hover_time := 1.8
## How high over the ground its hand hovers, metres, and how far it sweeps along it.
@export var hover_height := 20.0
@export var sweep_length := 12.0
## How hard its eyes and runes glow (more when it has seen someone).
@export var glow := 1.4

## Which way its body faces, radians about Y (0 faces +Z). It turns to it slowly.
var facing := 0.0
## What it looks at (INF: ahead).
var look_at_point := Vector3.INF
## What its hand goes for while it reaches (and follows while it hovers).
var reach_target := Vector3.INF
## Where it leans its hands to haul itself up and look over (the top of a
## wall, say): its forearms on it, its chest over it, its head up, its feet off
## the ground, `lean_rise` metres higher than it stands (INF: it does not). It
## comes up into it, and down out of it, over a few seconds.
var lean_on := Vector3.INF
## How far it hauls itself up when it leans on something, metres.
@export var lean_rise := 20.0

var _yaw := 0.0
var _feet: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_yaw: Array[float] = [0.0, 0.0]
var _swing := -1
var _swing_t := 0.0
var _swing_time := 3.6
var _swing_from := Vector3.ZERO
var _swing_to := Vector3.ZERO
var _swing_yaw_from := 0.0
var _swing_yaw_to := 0.0
var _swing_lift := 6.0
var _steps := 0

var _reach := Reach.NONE
var _reach_t := 0.0
var _reach_hand := 0
var _hover := Vector3.ZERO
var _strike_from := Vector3.ZERO
var _strike_at := Vector3.ZERO
var _bent := 0.0
var _hand_now := [Vector3.ZERO, Vector3.ZERO]

var _pelvis := Vector3.ZERO
var _pelvis_ready := false
var _lean := 0.0
var _lean_smooth := 0.0
var _lean_at := Vector3.ZERO
var _look_yaw := 0.0
var _look_pitch := 0.0
var _eye := Vector3.ZERO
var _time := 0.0
var _quakes: Array = []

var _model: Node3D
var _skeleton: Skeleton3D
var _body: MeshInstance3D
var _shadow_body: MeshInstance3D
var _material: ShaderMaterial
var _far := false
var _lod_in := 0.0
var _index: PackedInt32Array
var _rest: Array[Transform3D] = []
var _rest_head: Array[Vector3] = []
var _rest_frame: Array[Transform3D] = []
var _thigh := 0.0
var _shin := 0.0
var _upper_arm := 0.0
var _forearm := 0.0
var _ankle_height := 0.0
var _blots: Array[MeshInstance3D] = []
var _hand_blot: MeshInstance3D
var _glints: Array[MeshInstance3D] = []
var _eye_side := Vector3.ZERO
var _dust: Array[CPUParticles3D] = []
var _falling: CPUParticles3D
var _shedding: CPUParticles3D
var _thuds: Array[AudioStreamPlayer3D] = []
var _rumble: AudioStreamPlayer3D
static var _thud_sound: AudioStreamWAV
static var _rumble_sound: AudioStreamWAV


func _ready() -> void:
	_model = (load(MODEL_LO if low_poly else MODEL) as PackedScene).instantiate()
	_model.top_level = true
	add_child(_model)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	_body = _model.find_children("*", "MeshInstance3D", true, false)[0]
	_material = ColossusLook.instance_material()
	_body.material_override = _material
	# (it moves far from where it was modelled: never cull it by its rest pose)
	_body.custom_aabb = AABB(Vector3(-7.0, -4.0, -7.0), Vector3(14.0, 16.0, 14.0))
	if low_poly:
		_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		# The low-poly model, on the same skeleton, casts its shadow.
		_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if casts_shadow or lod_distance > 0.0:
			var low := (load(MODEL_LO) as PackedScene).instantiate()
			var mesh := low.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			_shadow_body = MeshInstance3D.new()
			_shadow_body.mesh = mesh.mesh
			_shadow_body.skin = mesh.skin
			_shadow_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_shadow_body.visible = casts_shadow
			_shadow_body.material_override = _material
			_shadow_body.custom_aabb = _body.custom_aabb
			_skeleton.add_child(_shadow_body)
			_shadow_body.skeleton = NodePath("..")
			low.free()
	_index.resize(BONES.size())
	for b in BONES.size():
		_index[b] = _skeleton.find_bone(BONES[b])
		_rest.append(_skeleton.get_bone_global_rest(_index[b]))
		_rest_head.append(_rest[b].origin)
	# Each bone's frame as it stands: along it to the next joint, its X to the left.
	for b in BONES.size():
		var tail := _tail_rest(b)
		var frame := Transform3D(Basis.IDENTITY, _rest_head[b])
		if b in [ARM_L, FOREARM_L, HAND_L, FINGERS_L, THIGH_L, SHIN_L, ARM_R, FOREARM_R, HAND_R, FINGERS_R, THIGH_R, SHIN_R]:
			frame.basis = _along((tail - _rest_head[b]).normalized(), Vector3.RIGHT)
		_rest_frame.append(frame)
	_thigh = _rest_head[SHIN_L].distance_to(_rest_head[THIGH_L])
	_shin = _rest_head[FOOT_L].distance_to(_rest_head[SHIN_L])
	_upper_arm = _rest_head[FOREARM_L].distance_to(_rest_head[ARM_L])
	_forearm = _rest_head[HAND_L].distance_to(_rest_head[FOREARM_L])
	_ankle_height = _rest_head[FOOT_L].y
	_effects()
	if not _pelvis_ready:
		put(global_position, rotation.y)


## Where each bone (by index) runs to as it stands.
func _tail_rest(b: int) -> Vector3:
	match b:
		PELVIS: return _rest_head[SPINE]
		SPINE: return _rest_head[CHEST]
		CHEST: return _rest_head[NECK]
		NECK: return _rest_head[HEAD]
		HEAD: return _rest_head[HEAD] + Vector3(0.0, 1.0, 0.2)
		ARM_L: return _rest_head[FOREARM_L]
		FOREARM_L: return _rest_head[HAND_L]
		HAND_L: return _rest_head[FINGERS_L]
		FINGERS_L: return _rest_head[FINGERS_L] + (_rest_head[FINGERS_L] - _rest_head[HAND_L]).normalized() * 0.5
		THIGH_L: return _rest_head[SHIN_L]
		SHIN_L: return _rest_head[FOOT_L]
		ARM_R: return _rest_head[FOREARM_R]
		FOREARM_R: return _rest_head[HAND_R]
		HAND_R: return _rest_head[FINGERS_R]
		FINGERS_R: return _rest_head[FINGERS_R] + (_rest_head[FINGERS_R] - _rest_head[HAND_R]).normalized() * 0.5
		THIGH_R: return _rest_head[SHIN_R]
		SHIN_R: return _rest_head[FOOT_R]
	return _rest_head[b] + Vector3(0.0, 0.0, 1.0)


## Metres to a model unit.
func scale_m() -> float:
	return height / UNITS


# --- Feet -------------------------------------------------------------------

## Stands it at `at` (on the ground) facing `yaw`, its feet either side.
func put(at: Vector3, yaw: float, stance := 0.0) -> void:
	facing = yaw
	_yaw = yaw
	var left := Basis(Vector3.UP, yaw).x
	var apart := stance if stance > 0.0 else 0.78 * scale_m()
	_feet[LEFT] = at + left * apart
	_feet[RIGHT] = at - left * apart
	_foot_yaw[LEFT] = yaw
	_foot_yaw[RIGHT] = yaw
	_swing = -1
	_pelvis_ready = false
	if _skeleton:
		_pose(0.0)


## Puts one foot down where it is to stand, at once.
func plant(foot: int, point: Vector3, yaw: float) -> void:
	_feet[foot] = point
	_foot_yaw[foot] = yaw
	if _swing == foot:
		_swing = -1


## Lifts `foot` and carries it to `to` (a point on the ground), turned to
## `yaw`, high enough to pass over anything up to `clear` metres high on the
## way (world height), in `seconds` (step_time if 0; longer for a long step).
## `footfall` is emitted when it comes down. A step already under way with the
## other foot is finished at once.
func step(foot: int, to: Vector3, yaw: float, clear := -INF, seconds := 0.0) -> void:
	if _swing >= 0 and _swing != foot:
		_land()
	_swing = foot
	_swing_t = 0.0
	_swing_from = _feet[foot]
	_swing_to = to
	_swing_yaw_from = _foot_yaw[foot]
	_swing_yaw_to = yaw
	var length := Vector2(to.x - _swing_from.x, to.z - _swing_from.z).length()
	var ground := maxf(_swing_from.y, to.y)
	# (a step lifts the foot a little; over a wall, as high as it must, and more slowly)
	_swing_lift = maxf(0.05 * scale_m() + length * 0.12, clear - ground + 0.35 * scale_m()) if clear > -INF else 0.05 * scale_m() + length * 0.12
	_swing_time = seconds if seconds > 0.0 else step_time * (1.0 + clampf(_swing_lift / (2.5 * scale_m()), 0.0, 0.6))
	_steps += 1
	lifted.emit(foot, to)


## The foot being carried (LEFT or RIGHT), or -1.
func stepping() -> int:
	return _swing


## How far through its step the carried foot is, 0..1.
func step_progress() -> float:
	return _swing_t / _swing_time if _swing >= 0 else 0.0


## How long the step under way takes, seconds.
func step_length() -> float:
	return _swing_time if _swing >= 0 else 0.0


## Where a foot is to stand (or stands): the ground under its ankle.
func landing(foot: int) -> Vector3:
	return _swing_to if _swing == foot else _feet[foot]


func landing_yaw(foot: int) -> float:
	return _swing_yaw_to if _swing == foot else _foot_yaw[foot]


## Where a foot is now (in the air while it is carried): the point under its ankle.
func foot_point(foot: int) -> Vector3:
	if _swing != foot:
		return _feet[foot]
	var t := _swing_t / _swing_time
	# Up first and down last, so that it clears what is near where it left and
	# where it comes down; across in between.
	var across := smoothstep(0.12, 0.86, t)
	var flat := _swing_from.lerp(_swing_to, across)
	var rise := smoothstep(0.0, 0.32, t) * (1.0 - smoothstep(0.7, 1.0, t))
	return flat + Vector3.UP * _swing_lift * rise


## The yaw of a foot now.
func foot_yaw(foot: int) -> float:
	if _swing != foot:
		return _foot_yaw[foot]
	return lerp_angle(_swing_yaw_from, _swing_yaw_to, smoothstep(0.15, 0.8, _swing_t / _swing_time))


## Whether a point (its x and z) is inside the print of `foot` where it stands
## or is coming down, `margin` metres more all round.
func under_foot(foot: int, point: Vector3, margin := 0.0) -> bool:
	var at := landing(foot)
	var basis := Basis(Vector3.UP, landing_yaw(foot))
	var local := basis.inverse() * Vector3(point.x - at.x, 0.0, point.z - at.z)
	var s := scale_m()
	return absf(local.x) <= PRINT_ACROSS * s + margin and local.z >= -PRINT_BACK * s - margin and local.z <= PRINT_FORWARD * s + margin


## The corners of a foot's print where it stands or is coming down (world, on its ground).
func footprint(foot: int) -> PackedVector3Array:
	var at := landing(foot)
	var basis := Basis(Vector3.UP, landing_yaw(foot))
	var s := scale_m()
	var corners := PackedVector3Array()
	for c: Vector2 in [Vector2(-PRINT_ACROSS, -PRINT_BACK), Vector2(PRINT_ACROSS, -PRINT_BACK), Vector2(PRINT_ACROSS, PRINT_FORWARD), Vector2(-PRINT_ACROSS, PRINT_FORWARD)]:
		corners.append(at + basis * Vector3(c.x * s, 0.0, c.y * s))
	return corners


## A foot's print as offsets from the point under its ankle, facing +Z, metres:
## (across either side, back, forward).
func print_size() -> Vector3:
	var s := scale_m()
	return Vector3(PRINT_ACROSS * s, PRINT_BACK * s, PRINT_FORWARD * s)


## How far its legs reach, metres: the most a foot can be from the other (to
## stand on both), and a comfortable stride.
func stride() -> float:
	return 2.6 * scale_m()


# --- Reaching -----------------------------------------------------------------

## Bends and reaches down for `target` with the hand on its side: bends over
## (BEND), holds its hand over it (HOVER, following `reach_target`), strikes
## down (STRIKE: `hand_down`), sweeps its hand along the ground towards itself
## (SWEEP), and straightens up (RISE).
func reach(target: Vector3) -> void:
	reach_target = target
	var local := Basis(Vector3.UP, _yaw).inverse() * (target - _pelvis)
	_reach_hand = 0 if local.x >= 0.0 else 1
	_reach = Reach.BEND
	_reach_t = 0.0
	_hover = target


func reach_stage() -> Reach:
	return _reach


func reaching() -> bool:
	return _reach != Reach.NONE


## How long each stage of a reach takes, seconds.
func reach_time(stage: Reach) -> float:
	match stage:
		Reach.BEND: return 2.8
		Reach.HOVER: return hover_time
		Reach.STRIKE: return 0.55
		Reach.SWEEP: return 1.1
		Reach.RISE: return 3.0
	return 0.0


## Where the reaching hand's palm is (or the right hand's, when it is not reaching).
func hand_point() -> Vector3:
	return _hand_now[_reach_hand]


## Where the hand will come down, while it hovers (INF when it is not reaching).
func strike_point() -> Vector3:
	match _reach:
		Reach.BEND, Reach.HOVER:
			return _hover
		Reach.STRIKE, Reach.SWEEP:
			return _strike_at
	return Vector3.INF


## Whether a point is under the hand as it strikes or sweeps: within `radius`
## of its palm, and not above it.
func hand_hits(point: Vector3, radius: float) -> bool:
	if _reach != Reach.STRIKE and _reach != Reach.SWEEP:
		return false
	var palm := hand_point()
	var flat := Vector2(point.x - palm.x, point.z - palm.z).length()
	return flat < radius + 0.32 * scale_m() and point.y < palm.y + 0.15 * scale_m() and palm.y - point.y < 0.4 * scale_m()


# --- Where it is ---------------------------------------------------------------

## Its pelvis (the middle of its body), world.
func pelvis() -> Vector3:
	return _pelvis


## Between its eyes, world.
func eye() -> Vector3:
	return _eye


## The yaw its body faces now.
func body_yaw() -> float:
	return _yaw


## Each leg as capsules for whatever must bump into it: [from, to, radius], world.
func leg_capsules() -> Array:
	var out := []
	var s := scale_m()
	for side in 2:
		var thigh := _bone_world(THIGH_L if side == 0 else THIGH_R)
		var shin := _bone_world(SHIN_L if side == 0 else SHIN_R)
		var foot := _bone_world(FOOT_L if side == 0 else FOOT_R)
		out.append([thigh, shin, 0.55 * s])
		out.append([shin, foot, 0.45 * s])
		var ahead := Basis(Vector3.UP, foot_yaw(side)).z
		var ground := foot_point(side)
		out.append([ground + Vector3.UP * 0.2 * s - ahead * 0.2 * s, ground + Vector3.UP * 0.2 * s + ahead * 0.7 * s, 0.32 * s])
	return out


func _bone_world(b: int) -> Vector3:
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(_index[b]).origin


## How hard the ground shakes at `point` now from its footfalls and its hand, 0..1.
func shake_at(point: Vector3) -> float:
	var total := 0.0
	for quake: Array in _quakes:
		var age := _time - float(quake[1])
		var near := 1.0 - smoothstep(0.25 * height, 2.4 * height, (quake[0] as Vector3).distance_to(point))
		total += float(quake[2]) * near * exp(-age * 2.2) * smoothstep(0.0, 0.05, age)
	return clampf(total, 0.0, 1.0)


## Shakes a camera by `amount` (0..1) through its offsets (leaving where it is
## put to whatever moves it). Call it every frame with `shake_at`.
static func rattle(camera: Camera3D, amount: float, metres := 0.35) -> void:
	if camera == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	camera.h_offset = (sin(t * 37.0) * 0.6 + sin(t * 23.0 + 1.3) * 0.4) * amount * metres
	camera.v_offset = (sin(t * 41.0 + 0.7) * 0.6 + sin(t * 29.0 + 2.1) * 0.4) * amount * metres


# --- Each frame ---------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if lean_on.is_finite():
		_lean_at = lean_on
	_lean = move_toward(_lean, 1.0 if lean_on.is_finite() and _reach == Reach.NONE else 0.0, delta * 0.3)
	if _swing >= 0:
		_swing_t += delta
		if _swing_t >= _swing_time:
			_land()
	_reach_on(delta)
	_pose(delta)
	_show(delta)
	while not _quakes.is_empty() and _time - float(_quakes[0][1]) > 4.0:
		_quakes.pop_front()


func _land() -> void:
	var foot := _swing
	_feet[foot] = _swing_to
	_foot_yaw[foot] = _swing_yaw_to
	_swing = -1
	_quakes.append([_swing_to, _time, 1.0])
	var puff := _dust[foot]
	puff.global_position = _swing_to + Vector3.UP * 0.4
	puff.restart()
	puff.emitting = true
	if sound and _thuds.size() > foot:
		_thuds[foot].global_position = _swing_to + Vector3.UP * 2.0
		_thuds[foot].pitch_scale = randf_range(0.9, 1.05)
		_thuds[foot].play()
	footfall.emit(foot, _swing_to)


func _reach_on(delta: float) -> void:
	if _reach == Reach.NONE:
		_bent = move_toward(_bent, 0.0, delta * 0.5)
		return
	_reach_t += delta
	var target := reach_target if reach_target.is_finite() else _hover
	match _reach:
		Reach.BEND:
			_hover = _hover.lerp(target, 1.0 - exp(-1.2 * delta))
			if _reach_t >= reach_time(Reach.BEND):
				_next_stage(Reach.HOVER)
		Reach.HOVER:
			# (it follows slowly: whoever runs gets out from under it)
			_hover = _hover.lerp(target, 1.0 - exp(-0.9 * delta))
			if _reach_t >= reach_time(Reach.HOVER):
				_strike_from = _hand_now[_reach_hand]
				_strike_at = _hover
				_next_stage(Reach.STRIKE)
		Reach.STRIKE:
			if _reach_t >= reach_time(Reach.STRIKE):
				_quakes.append([_strike_at, _time, 0.7])
				var puff := _dust[_reach_hand]
				puff.global_position = _strike_at + Vector3.UP * 0.4
				puff.restart()
				puff.emitting = true
				if sound:
					_thuds[_reach_hand].global_position = _strike_at + Vector3.UP * 2.0
					_thuds[_reach_hand].pitch_scale = 1.2
					_thuds[_reach_hand].play()
				hand_down.emit(_strike_at)
				_next_stage(Reach.SWEEP)
		Reach.SWEEP:
			if _reach_t >= reach_time(Reach.SWEEP):
				_next_stage(Reach.RISE)
		Reach.RISE:
			if _reach_t >= reach_time(Reach.RISE):
				_reach = Reach.NONE
				reach_target = Vector3.INF


func _next_stage(stage: Reach) -> void:
	_reach = stage
	_reach_t = 0.0


## How far it is bent over to reach, 0..1.
func _bend_now() -> float:
	match _reach:
		Reach.BEND:
			return smoothstep(0.0, 1.0, _reach_t / reach_time(Reach.BEND))
		Reach.HOVER, Reach.STRIKE, Reach.SWEEP:
			return 1.0
		Reach.RISE:
			return 1.0 - smoothstep(0.0, 1.0, _reach_t / reach_time(Reach.RISE))
	return _bent


# --- Posing -------------------------------------------------------------------

func _pose(delta: float) -> void:
	var s := scale_m()
	var bend := _bend_now()
	_bent = bend
	# Its body turns slowly to where it faces (and towards what it reaches for).
	var want := facing
	if _reach != Reach.NONE and reach_target.is_finite():
		var to := reach_target - _pelvis
		want = lerp_angle(facing, atan2(to.x, to.z), 0.5)
	var turn := wrapf(want - _yaw, -PI, PI)
	_yaw += clampf(turn, -turn_rate * delta, turn_rate * delta) if delta > 0.0 else turn
	var yaw_basis := Basis(Vector3.UP, _yaw)
	var left := yaw_basis.x
	var ahead := yaw_basis.z

	var feet: Array[Vector3] = [foot_point(LEFT), foot_point(RIGHT)]
	var t := step_progress()
	var stride_phase := 0.0
	if _swing >= 0:
		stride_phase = sin(PI * t) * (1.0 if _swing == LEFT else -1.0)
	# Its pelvis over its feet: between them, leaning over the one it stands on.
	var ground := (Vector3(feet[0].x, landing(LEFT).y, feet[0].z) + Vector3(feet[1].x, landing(RIGHT).y, feet[1].z)) * 0.5
	if _swing >= 0:
		var stand := _feet[1 - _swing]
		ground = ground.lerp(Vector3(stand.x, ground.y, stand.z), 0.14 * sin(PI * t))
	# (bent over, its hips go back and down: a deep squat; leaning on something,
	# up to it)
	ground -= ahead * (0.3 * s * bend)
	if _lean > 0.0:
		var to_lean := _lean_at - ground
		to_lean.y = 0.0
		ground += to_lean.normalized() * minf(to_lean.length() * 0.3, 0.5 * s) * smoothstep(0.0, 1.0, _lean)
	var rest_hip := _rest_head[PELVIS].y * s
	var lean := smoothstep(0.0, 1.0, _lean)
	if delta > 0.0:
		_lean_smooth = lerpf(_lean_smooth, lean, 1.0 - exp(-2.0 * delta))
	lean = _lean_smooth if delta > 0.0 else lean
	# Its feet: lifted at the heel as they leave the ground, toes down as they come
	# back to it; up on their toes (about the toes) when it heaves itself up to lean.
	var foot_turns: Array[Basis] = []
	var ankles: Array[Vector3] = []
	for side in 2:
		var fy := foot_yaw(side)
		var lift := sin(PI * t) if _swing == side else 0.0
		var toes_down := smoothstep(0.75, 0.95, t) * 0.12 if _swing == side else 0.0
		var on_toes := lean * 0.95 if _swing != side else 0.0
		var r_foot := Basis(Vector3.UP, fy) * Basis(Vector3.RIGHT, lift * 0.35 - toes_down + on_toes)
		var toe := feet[side] + Basis(Vector3.UP, fy) * Vector3(0.0, 0.0, 0.62 * s)
		var ankle := toe + r_foot * Vector3(0.0, _ankle_height * s, -0.62 * s)
		foot_turns.append(r_foot)
		ankles.append(ankle)
	var top := rest_hip - bend * 2.3 * s - 0.04 * s * absf(stride_phase)
	# (low enough that both legs reach their feet)
	var reach_leg := (_thigh + _shin) * s * 0.985
	for side in 2:
		var hip_off := (_rest_head[THIGH_L if side == 0 else THIGH_R] - _rest_head[PELVIS]) * s
		var hip_flat := Vector3(ground.x, 0.0, ground.z) + yaw_basis * Vector3(hip_off.x, 0.0, hip_off.z)
		var ankle := ankles[side]
		var across := Vector2(hip_flat.x - ankle.x, hip_flat.z - ankle.z).length()
		var most := ankle.y + sqrt(maxf(reach_leg * reach_leg - across * across, 0.0)) - hip_off.y
		top = minf(top, most)
	# (hauled up on its arms, its feet leave the ground)
	top += lean * lean_rise
	var pelvis := Vector3(ground.x, ground.y + top, ground.z)
	if not _pelvis_ready or delta <= 0.0:
		_pelvis = pelvis
		_pelvis_ready = true
	else:
		_pelvis = _pelvis.lerp(pelvis, 1.0 - exp(-4.0 * delta))
	var base_y := ground.y
	_model.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(_pelvis.x, base_y, _pelvis.z))
	var to_skeleton := _skeleton.global_transform.affine_inverse()
	var sk := _skeleton.global_transform.basis.get_scale().x

	# The spine: leaning into its stride and over when it reaches, swaying over the foot it stands on.
	var sway := 0.0
	if _swing >= 0:
		sway = sin(PI * t) * (1.0 if _swing == RIGHT else -1.0)
	var breathe := sin(_time * 0.9) * 0.012
	var twist := 0.0
	if _reach != Reach.NONE and reach_target.is_finite():
		var to := reach_target - _pelvis
		twist = clampf(wrapf(atan2(to.x, to.z) - _yaw, -PI, PI), -0.7, 0.7) * bend
	# (leaning on something, it straightens its back and leans out over it, its head up)
	var r_pelvis := yaw_basis * Basis(Vector3.RIGHT, 0.05 + bend * 0.5 + lean * 0.12) * Basis(Vector3.BACK, sway * 0.04)
	var r_spine := r_pelvis * Basis(Vector3.RIGHT, 0.03 + bend * 0.45 + breathe + lean * 0.12) * Basis(Vector3.UP, -stride_phase * 0.05 + twist * 0.5)
	var r_chest := r_spine * Basis(Vector3.RIGHT, bend * 0.42 - breathe + lean * 0.1) * Basis(Vector3.BACK, -sway * 0.06) * Basis(Vector3.UP, -stride_phase * 0.05 + twist * 0.5)
	var j_pelvis := _pelvis
	var j_spine := j_pelvis + r_pelvis * (_rest_head[SPINE] - _rest_head[PELVIS]) * s
	var j_chest := j_spine + r_spine * (_rest_head[CHEST] - _rest_head[SPINE]) * s
	var j_neck := j_chest + r_chest * (_rest_head[NECK] - _rest_head[CHEST]) * s
	# Its head: looking at what it looks at, as far as its neck lets it.
	var look_yaw := 0.0
	var look_pitch := -bend * 0.5
	if look_at_point.is_finite():
		var local := r_chest.inverse() * (look_at_point - j_neck)
		look_yaw = clampf(atan2(local.x, local.z), -0.9, 0.9)
		look_pitch = clampf(-atan2(local.y, Vector2(local.x, local.z).length()), -0.5, 0.9)
	else:
		look_yaw = sin(_time * 0.13) * 0.25
	_look_yaw = lerp_angle(_look_yaw, look_yaw, 1.0 - exp(-0.8 * delta)) if delta > 0.0 else look_yaw
	_look_pitch = lerpf(_look_pitch, look_pitch, 1.0 - exp(-0.8 * delta)) if delta > 0.0 else look_pitch
	var r_neck := r_chest * Basis(Vector3.UP, _look_yaw * 0.4) * Basis(Vector3.RIGHT, _look_pitch * 0.4 - lean * 0.35)
	var j_head := j_neck + r_neck * (_rest_head[HEAD] - _rest_head[NECK]) * s
	var r_head := r_neck * Basis(Vector3.UP, _look_yaw * 0.6) * Basis(Vector3.RIGHT, _look_pitch * 0.6)
	_eye = j_head + r_head * Vector3(0.0, 0.6, 0.8) * s
	_eye_side = r_head.x * 0.2 * s

	var frames: Array[Transform3D] = []
	frames.resize(BONES.size())
	frames[PELVIS] = Transform3D(r_pelvis, j_pelvis)
	frames[SPINE] = Transform3D(r_spine, j_spine)
	frames[CHEST] = Transform3D(r_chest, j_chest)
	frames[NECK] = Transform3D(r_neck, j_neck)
	frames[HEAD] = Transform3D(r_head, j_head)

	# The legs: from the hips to the ankles, knees forward.
	for side in 2:
		var thigh_b := THIGH_L if side == 0 else THIGH_R
		var hip := j_pelvis + r_pelvis * (_rest_head[thigh_b] - _rest_head[PELVIS]) * s
		var fy := foot_yaw(side)
		var lift := sin(PI * t) if _swing == side else 0.0
		var r_foot := foot_turns[side]
		var ankle := ankles[side]
		var foot_ahead := Basis(Vector3.UP, fy).z
		var out_side := left * (1.0 if side == 0 else -1.0)
		var pole := (ahead + foot_ahead + out_side * 0.3 + Vector3.UP * 0.2 * lift).normalized()
		var knee := _bend(hip, ankle, _thigh * s, _shin * s, pole)
		# (where the shin ends, if the foot is out of its reach: it hangs)
		ankle = knee + (ankle - knee).normalized() * _shin * s
		var sideways := left
		frames[thigh_b] = Transform3D(_along((knee - hip).normalized(), sideways), hip)
		frames[thigh_b + 1] = Transform3D(_along((ankle - knee).normalized(), sideways), knee)
		frames[thigh_b + 2] = Transform3D(r_foot, ankle)

	# The arms: hanging heavy, swinging against the stride; the reaching one down to its hand.
	for side in 2:
		var arm_b := ARM_L if side == 0 else ARM_R
		var sign_x := 1.0 if side == 0 else -1.0
		var shoulder := j_chest + r_chest * (_rest_head[arm_b] - _rest_head[CHEST]) * s
		var arm_length := (_upper_arm + _forearm) * s
		var swing := -stride_phase * sign_x * 0.22
		var hang := (Vector3.DOWN * 0.82 + ahead * (0.3 + swing) + left * sign_x * 0.3).normalized()
		var hand := shoulder + hang * arm_length * 0.86
		var curl := 0.35
		var palm_down := 0.0
		var reaching_this := _reach != Reach.NONE and side == _reach_hand
		var palm := (_rest_head[arm_b + 3] - _rest_head[arm_b + 2]).length() * s
		# (palm down, fingers on ahead; dragged back towards itself as it sweeps)
		var palm_dir := (Vector3.DOWN * 0.85 + ahead * 0.35).normalized()
		if reaching_this:
			var aim := _reach_point()
			var w := bend
			if _reach == Reach.STRIKE or _reach == Reach.SWEEP:
				w = 1.0
			if _reach == Reach.SWEEP or _reach == Reach.RISE:
				var home := _pelvis - aim
				home.y = 0.0
				palm_dir = (Vector3.DOWN * 0.8 - home.normalized() * 0.45).normalized()
			# (the wrist goes where the palm is to be, less the hand)
			hand = hand.lerp(aim - palm_dir * palm * 0.6, w)
			curl = 0.05 if _reach in [Reach.BEND, Reach.HOVER] else (0.2 if _reach == Reach.STRIKE else 0.9)
			palm_down = w
		elif _reach != Reach.NONE:
			# (the other braces on its knee)
			var knee_b := (THIGH_L if side == 0 else THIGH_R) + 1
			hand = hand.lerp(frames[knee_b].origin + ahead * 0.4 * s + Vector3.UP * 0.5 * s, bend * 0.8)
		if lean > 0.0 and not reaching_this:
			# (its hands flat on what it leans on, either side)
			var along := (_lean_at - _pelvis)
			along.y = 0.0
			var across := along.normalized().cross(Vector3.UP)
			var rest_on := _lean_at - across * sign_x * 0.95 * s * (1.0 if across.dot(left) < 0.0 else -1.0)
			palm_dir = palm_dir.lerp((Vector3.DOWN * 0.5 + along.normalized() * 0.85).normalized(), lean)
			hand = hand.lerp(rest_on + Vector3.UP * 0.12 * s + along.normalized() * 0.4 * s - palm_dir * palm * 0.6, lean)
			palm_down = maxf(palm_down, lean)
			curl = lerpf(curl, 0.15, lean)
		var elbow_pole := (-ahead * 0.5 + left * sign_x * 0.8 + Vector3.DOWN * 0.2).normalized()
		if reaching_this:
			elbow_pole = (left * sign_x + Vector3.UP * 0.6 - ahead * 0.2).normalized()
		var elbow := _bend(shoulder, hand, _upper_arm * s, _forearm * s, elbow_pole)
		var wrist := elbow + (hand - elbow).normalized() * _forearm * s
		var fore_dir := (wrist - elbow).normalized()
		var hand_dir := fore_dir.lerp(palm_dir, palm_down).normalized()
		frames[arm_b] = Transform3D(_along((elbow - shoulder).normalized(), left), shoulder)
		frames[arm_b + 1] = Transform3D(_along(fore_dir, left), elbow)
		frames[arm_b + 2] = Transform3D(_along(hand_dir, left), wrist)
		var knuckles := wrist + hand_dir * palm
		var hand_basis := _along(hand_dir, left)
		# (curled towards the palm, which faces its front as the hand hangs)
		var finger_dir := (Basis(hand_basis.x, -curl * 1.3) * hand_dir).normalized()
		frames[arm_b + 3] = Transform3D(_along(finger_dir, left), knuckles)
		_hand_now[side] = wrist.lerp(knuckles, 0.6)

	# Each bone moved from where it stood by as much as its frame has moved.
	for b in BONES.size():
		var posed := frames[b]
		posed.basis = posed.basis.orthonormalized().scaled(Vector3.ONE * sk)
		var g := to_skeleton * posed * _rest_frame[b].affine_inverse() * _rest[b]
		var bone := _index[b]
		_skeleton.set_bone_pose_position(bone, g.origin)
		_skeleton.set_bone_pose_rotation(bone, g.basis.get_rotation_quaternion())
		_skeleton.set_bone_pose_scale(bone, g.basis.get_scale())


## Where the reaching hand is making for now.
func _reach_point() -> Vector3:
	var lift := Vector3.UP * hover_height
	match _reach:
		Reach.BEND, Reach.HOVER:
			return _hover + lift
		Reach.STRIKE:
			var k := _reach_t / reach_time(Reach.STRIKE)
			return (_hover + lift).lerp(_strike_at + Vector3.UP * 0.25 * scale_m(), k * k)
		Reach.SWEEP:
			var k := smoothstep(0.0, 1.0, _reach_t / reach_time(Reach.SWEEP))
			var home := _pelvis - _strike_at
			home.y = 0.0
			return _strike_at + Vector3.UP * 0.25 * scale_m() + home.normalized() * sweep_length * k
		Reach.RISE:
			var k := smoothstep(0.0, 1.0, _reach_t / reach_time(Reach.RISE))
			var home := _pelvis - _strike_at
			home.y = 0.0
			return _strike_at + home.normalized() * sweep_length + Vector3.UP * (0.25 * scale_m() + k * hover_height)
	return _hover


## A basis whose Y is `y`, with X as near `side` as can be.
static func _along(y: Vector3, side: Vector3) -> Basis:
	var z := side.cross(y)
	if z.length() < 0.05:
		z = Vector3.FORWARD.cross(y) if absf(y.z) < 0.9 else Vector3.UP.cross(y)
	z = z.normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, z)


## The middle joint of a limb from `a` to `target`, bones `l1` and `l2` long, bending towards `pole`.
static func _bend(a: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var to := target - a
	var d := clampf(to.length(), 0.01, (l1 + l2) * 0.999)
	var along := to.normalized()
	var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var side := pole - along * pole.dot(along)
	side = side.normalized() if side.length() > 0.001 else Vector3.UP
	return a + along * x + side * h


# --- Shadows, dust, stones and sound -------------------------------------------

func _effects() -> void:
	var s := scale_m()
	for foot in 2:
		var blot := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(PRINT_ACROSS * 2.0, PRINT_BACK + PRINT_FORWARD) * s * 1.25
		plane.center_offset = Vector3(0.0, 0.0, (PRINT_FORWARD - PRINT_BACK) * 0.5 * s)
		blot.mesh = plane
		blot.material_override = ColossusLook.shadow_material()
		blot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blot.top_level = true
		blot.visible = false
		add_child(blot)
		_blots.append(blot)
		var puff := ColossusLook.dust(1.4 * s)
		add_child(puff)
		_dust.append(puff)
	# Its eyes, as two pale points that show through the mist from far off (no
	# nearer than `glint_from`: close to, the eyes themselves are enough).
	for k in 2:
		var glint := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * 0.5 * s
		glint.mesh = quad
		glint.material_override = ColossusLook.glint_material()
		glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glint.top_level = true
		add_child(glint)
		_glints.append(glint)
	_hand_blot = MeshInstance3D.new()
	var hand_plane := PlaneMesh.new()
	hand_plane.size = Vector2(0.9, 1.1) * s
	_hand_blot.mesh = hand_plane
	_hand_blot.material_override = ColossusLook.shadow_material()
	_hand_blot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hand_blot.top_level = true
	_hand_blot.visible = false
	add_child(_hand_blot)
	_falling = ColossusLook.stones(0.06 * s)
	_falling.emission_sphere_radius = 0.4 * s
	add_child(_falling)
	_shedding = ColossusLook.stones(0.05 * s)
	_shedding.amount = 24
	_shedding.emission_sphere_radius = 1.0 * s
	add_child(_shedding)
	if sound:
		if _thud_sound == null:
			_thud_sound = thud_sound()
			_rumble_sound = rumble_sound()
		for foot in 2:
			var thud := AudioStreamPlayer3D.new()
			thud.stream = _thud_sound
			thud.volume_db = volume_db
			thud.unit_size = 0.6 * s
			thud.max_distance = sound_range
			thud.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
			add_child(thud)
			thud.top_level = true
			_thuds.append(thud)
		_rumble = AudioStreamPlayer3D.new()
		_rumble.stream = _rumble_sound
		_rumble.volume_db = -60.0
		_rumble.unit_size = 0.6 * s
		_rumble.max_distance = sound_range
		add_child(_rumble)
		_rumble.top_level = true


func _show(delta: float) -> void:
	var s := scale_m()
	for k in 2:
		_glints[k].global_position = _eye + _eye_side * (1.0 if k == 0 else -1.0)
		_glints[k].visible = glow > 0.0
		_glints[k].set_instance_shader_parameter(&"bright", glow)
	# Far off, the low-poly model is drawn instead.
	_lod_in -= delta
	if _shadow_body and lod_distance > 0.0 and _lod_in <= 0.0:
		_lod_in = 0.3
		var camera := get_viewport().get_camera_3d()
		var far := camera != null and camera.global_position.distance_to(_pelvis) > lod_distance
		if far != _far:
			_far = far
			_body.visible = not far
			_shadow_body.visible = far or casts_shadow
			if far:
				_shadow_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			else:
				_shadow_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_material.set_shader_parameter(&"glow_energy", glow)
	# A foot's shadow on the ground where it will come down, darker as it nears.
	for foot in 2:
		var blot := _blots[foot]
		if _swing == foot:
			var t := step_progress()
			var near := smoothstep(0.35, 1.0, t)
			blot.visible = near > 0.0
			blot.global_transform = Transform3D(Basis(Vector3.UP, _swing_yaw_to).scaled(Vector3.ONE * (1.5 - 0.45 * near)), _swing_to + Vector3.UP * 0.12)
			(blot.material_override as ShaderMaterial).set_shader_parameter(&"strength", near * 0.85)
		else:
			blot.visible = false
	# The hand's, while it hovers and strikes.
	var over := strike_point()
	_hand_blot.visible = over.is_finite()
	if over.is_finite():
		var dark := 0.0
		match _reach:
			Reach.BEND: dark = smoothstep(0.4, 1.0, _reach_t / reach_time(Reach.BEND)) * 0.35
			Reach.HOVER: dark = 0.35 + 0.4 * _reach_t / reach_time(Reach.HOVER)
			Reach.STRIKE: dark = 0.85
			Reach.SWEEP: dark = 0.6 * (1.0 - _reach_t / reach_time(Reach.SWEEP))
		var palm := hand_point()
		_hand_blot.global_transform = Transform3D(Basis(Vector3.UP, _yaw).scaled(Vector3.ONE * clampf(0.9 + (palm.y - over.y) / (2.0 * hover_height), 0.9, 1.6)), Vector3(palm.x, over.y + 0.12, palm.z))
		(_hand_blot.material_override as ShaderMaterial).set_shader_parameter(&"strength", dark)
	# Earth falling from a lifted foot, and from its body as it goes.
	var high := _swing >= 0 and foot_point(_swing).y - landing(_swing).y > 0.3 * s
	_falling.emitting = high
	if _swing >= 0:
		_falling.global_position = foot_point(_swing) + Vector3.UP * 0.1 * s
	_shedding.emitting = _swing >= 0 or _reach != Reach.NONE
	_shedding.global_position = _pelvis + Vector3.UP * 1.8 * s
	# A rumble that rises as a foot comes down.
	if _rumble:
		if _swing >= 0:
			var t := step_progress()
			_rumble.global_position = _swing_to + Vector3.UP * 3.0
			var loud := smoothstep(0.45, 0.98, t)
			_rumble.volume_db = lerpf(-40.0, volume_db - 2.0, loud)
			if not _rumble.playing and loud > 0.0:
				_rumble.play()
		elif _rumble.playing:
			_rumble.volume_db -= 1.5
			if _rumble.volume_db < -40.0:
				_rumble.stop()


# --- Sounds made in code ----------------------------------------------------------

## A footfall: a deep, long thud (a falling sweep of low tones), the crack and
## grind of stone and earth under it, and a rolling tail. 2.6 s.
static func thud_sound() -> AudioStreamWAV:
	var rate := 22050
	var length := int(rate * 2.6)
	var data := PackedByteArray()
	data.resize(length * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var low := 0.0
	var lower := 0.0
	var phase := 0.0
	var phase2 := 0.0
	for i in length:
		var t := float(i) / rate
		var pitch := 34.0 + 30.0 * exp(-t * 5.0)
		phase += TAU * pitch / rate
		phase2 += TAU * pitch * 1.52 / rate
		var body := (sin(phase) + 0.35 * sin(phase2)) * exp(-t * 1.6) * minf(t * 60.0, 1.0)
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.06
		lower += (low - lower) * 0.08
		var rumble := lower * 5.0 * exp(-t * 1.1)
		var crack := noise * exp(-t * 18.0) * 0.5
		var grit := (low * 2.0) * exp(-t * 3.5) * (0.6 + 0.4 * sin(t * 53.0))
		var value := clampf((body * 0.8 + rumble + crack + grit * 0.5) * 0.9, -1.0, 1.0)
		data.encode_s16(i * 2, int(value * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


## A low rumble to loop under a foot as it comes down. 3 s.
static func rumble_sound() -> AudioStreamWAV:
	var rate := 22050
	var length := int(rate * 3.0)
	var data := PackedByteArray()
	data.resize(length * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var low := 0.0
	var lower := 0.0
	for i in length:
		var t := float(i) / rate
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.03
		lower += (low - lower) * 0.05
		var value := lower * 9.0 * (0.75 + 0.25 * sin(TAU * t * 1.0 / 3.0 * 3.0))
		# (faded in and out at its ends, so that the loop does not click)
		value *= minf(minf(t, 3.0 - t) * 8.0, 1.0)
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 28000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = length
	return wav

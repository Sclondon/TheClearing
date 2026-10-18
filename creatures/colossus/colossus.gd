class_name Colossus
extends Node3D
## A colossus: a gaunt, spindly giant, its arms and legs far longer than its
## body, that crawls like a spider over whatever is under it (the tops of walls)
## on its hands and feet, its elbows and knees bent high above. Knobs of joints,
## a narrow cage of ribs, a hunched spine, a small stone mask of a head on a
## long neck with a pale light in its eyes; slabs of weathered stone grown over
## with moss and grass on its thin frame, runes cut in them that glow, tatters
## of dark fur, vines. Every hand or foot it puts down comes down with a thud
## that shakes the ground, dust rolling off and stones raining down. It hunts
## with one long finger: it holds it over what it wants, slowly presses it down,
## grinds, lifts, and tries again where they ran. And it can rear up and lean on
## the top of something high to look over it.
##
## This is only how it looks, moves and sounds. It does no thinking: a game says
## where each hand and foot goes (`step`), which way it faces (`facing`), what it
## looks at and what it presses its finger at. Its body follows its limbs.
##
##     var giant := Colossus.new()
##     add_child(giant)
##     giant.put(spot, yaw)                                  # its four limbs about spot
##     giant.plant(Colossus.HAND_L, wall_top, yaw)           # ...each put where it stands
##     giant.step(Colossus.HAND_L, other_wall_top, yaw, clear)  # lifted over anything up to clear
##     giant.planted.connect(func(limb, point): ...)         # it has come down
##     giant.facing = yaw                                    # its body turns to this (0 faces +Z)
##     giant.press(target, hall_direction)                   # the finger: reach, hover, descend, press, lift, again...
##     giant.press_target = target                           # it follows this while it hovers
##     if giant.finger_hits(point, 1.5): ...                 # while it presses
##     giant.release()                                       # done: the hand goes back to where it was
##
## The model is creatures/colossus/models/colossus.glb (and colossus_lo.glb),
## built in Blender by tools/build_colossus.py: UNITS tall, standing, scaled to
## `height` metres. Each bone is posed in code from where its joints are
## (two-bone reaches for the arms and legs), as the baboon is.

## A hand or foot has come down at `point`.
signal planted(limb: int, point: Vector3)
## A hand or foot has been lifted, to go to `to`.
signal lifted(limb: int, to: Vector3)
## The fingertip has come down to the ground (each press) at `point`.
signal pressed(point: Vector3)

## What the pressing finger is doing.
enum Press { NONE, REACH, HOVER, DESCEND, PRESS, LIFT, RETURN }

## Its limbs: what it stands on.
const HAND_L := 0
const HAND_R := 1
const FOOT_L := 2
const FOOT_R := 3

const MODEL := "res://creatures/colossus/models/colossus.glb"
const MODEL_LO := "res://creatures/colossus/models/colossus_lo.glb"
## How tall the model stands in its own units.
const UNITS := 11.0
const BONES: Array[StringName] = [
	&"pelvis", &"spine", &"chest", &"neck", &"head",
	&"upper_arm_l", &"forearm_l", &"hand_l", &"fingers_l", &"thigh_l", &"shin_l", &"foot_l",
	&"upper_arm_r", &"forearm_r", &"hand_r", &"fingers_r", &"thigh_r", &"shin_r", &"foot_r",
	&"index_l", &"index_r",
]
enum { PELVIS, SPINE, CHEST, NECK, HEAD, ARM_L, FOREARM_L, HAND_B_L, FINGERS_L, THIGH_L, SHIN_L, FOOT_B_L,
	ARM_R, FOREARM_R, HAND_B_R, FINGERS_R, THIGH_R, SHIN_R, FOOT_B_R, INDEX_L, INDEX_R }
## Where each limb stands as it crawls, about its pelvis, in model units: x to
## its left, z ahead. (Hands far out ahead and wide; feet out behind, wide.)
const STANCE: Array[Vector2] = [Vector2(2.2, 3.8), Vector2(-2.2, 3.8), Vector2(2.0, -2.2), Vector2(-2.0, -2.2)]
## How far round a hand's or foot's print reaches from where it is put, model units.
const PRINT := [0.42, 0.42, 0.35, 0.35]

## How tall it would stand, metres.
@export var height := 260.0
## Use the low-poly model.
@export var low_poly := false
## Its own shadow (the low-poly model casts it, whichever is drawn).
@export var casts_shadow := true
## Further than this from the camera (metres), the low-poly model is drawn
## instead (it rides the same skeleton): the mist hides the difference. 0: never.
@export var lod_distance := 450.0
## Its thuds (and a rumble as a hand or foot comes down), made in code.
@export var sound := true
@export var volume_db := 8.0
@export var sound_range := 1200.0
## How long it takes to move a hand or foot, seconds (a long move longer).
@export var step_time := 3.2
## How fast its body turns to `facing`, radians a second.
@export var turn_rate := 0.12
## How high over the ground the fingertip hovers before it comes down, metres;
## how long it hovers, comes down, presses (grinding), and lifts, seconds.
@export var hover_height := 52.0
@export var hover_time := 2.0
@export var descend_time := 3.0
@export var press_time := 1.6
@export var lift_time := 1.8
## How hard its eyes and runes glow (more when it has seen someone).
@export var glow := 1.4
## How far it rears up when it leans on something, metres.
@export var lean_rise := 30.0

## Which way its body faces, radians about Y (0 faces +Z). It turns to it slowly.
var facing := 0.0
## What it looks at (INF: ahead).
var look_at_point := Vector3.INF
## How low it bends its head and shoulders towards what it looks at, 0..1 (to peer down).
var stoop := 0.0
## What its finger goes for: it follows this while it hovers.
var press_target := Vector3.INF
## Where it leans its hands to rear up and look over something (the top of a
## wall), INF for not. It comes up into it, and down out of it, over seconds.
var lean_on := Vector3.INF
## The way the hall it presses into runs: its pressing hand goes in edge first, along it.
var press_along := Vector3.FORWARD

var _yaw := 0.0
var _plants: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _limb_yaw: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _swing := -1
var _swing_t := 0.0
var _swing_time := 3.2
var _swing_from := Vector3.ZERO
var _swing_to := Vector3.ZERO
var _swing_yaw_from := 0.0
var _swing_yaw_to := 0.0
var _swing_lift := 6.0

var _press := Press.NONE
var _press_t := 0.0
var _press_hand := 0

var _hover := Vector3.ZERO
var _tip := Vector3.ZERO
var _tip_from := Vector3.ZERO
var _released := false
var _presses := 0

var _pelvis := Vector3.ZERO
var _pelvis_ready := false
var _lean := 0.0
var _lean_at := Vector3.ZERO
var _stoop := 0.0
var _look_yaw := 0.0
var _look_pitch := 0.0
var _eye := Vector3.ZERO
var _eye_side := Vector3.ZERO
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
var _palm := 0.0
var _finger := 0.0
var _ankle_height := 0.0
var _blots: Array[MeshInstance3D] = []
var _tip_blot: MeshInstance3D
var _glints: Array[MeshInstance3D] = []
var _dust: Array[CPUParticles3D] = []
var _debris: Array[CPUParticles3D] = []
var _falling: CPUParticles3D
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
	# (it reaches far from where it was modelled: never cull it by its rest pose)
	var bounds := AABB(Vector3(-9.0, -6.0, -9.0), Vector3(18.0, 20.0, 18.0))
	_body.custom_aabb = bounds
	if low_poly:
		_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		# The low-poly model, on the same skeleton, casts its shadow (and is drawn far off).
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
			_shadow_body.custom_aabb = bounds
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
		var frame := Transform3D(Basis.IDENTITY, _rest_head[b])
		if b > HEAD and b != FOOT_B_L and b != FOOT_B_R:
			frame.basis = _along((_tail_rest(b) - _rest_head[b]).normalized(), Vector3.RIGHT)
		_rest_frame.append(frame)
	_thigh = _rest_head[SHIN_L].distance_to(_rest_head[THIGH_L])
	_shin = _rest_head[FOOT_B_L].distance_to(_rest_head[SHIN_L])
	_upper_arm = _rest_head[FOREARM_L].distance_to(_rest_head[ARM_L])
	_forearm = _rest_head[HAND_B_L].distance_to(_rest_head[FOREARM_L])
	_palm = _rest_head[FINGERS_L].distance_to(_rest_head[HAND_B_L])
	_finger = (_tail_rest(INDEX_L) - _rest_head[INDEX_L]).length()
	_ankle_height = _rest_head[FOOT_B_L].y
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
		HEAD: return _rest_head[HEAD] + Vector3(0.0, 0.7, 0.15)
		ARM_L, ARM_R, FOREARM_L, FOREARM_R, HAND_B_L, HAND_B_R, THIGH_L, THIGH_R, SHIN_L, SHIN_R:
			return _rest_head[b + 1]
		FINGERS_L, FINGERS_R:
			return _rest_head[b] + (_rest_head[b] - _rest_head[b - 1]).normalized() * 0.8
		INDEX_L, INDEX_R:
			var hand := HAND_B_L if b == INDEX_L else HAND_B_R
			return _rest_head[b] + (_rest_head[hand + 1] - _rest_head[hand]).normalized() * 1.1
	return _rest_head[b] + Vector3(0.0, 0.0, 1.0)


## Metres to a model unit.
func scale_m() -> float:
	return height / UNITS


## Where `limb` stands as it crawls, about its pelvis facing +Z, metres (x left, z ahead).
func stance(limb: int) -> Vector2:
	return STANCE[limb] * scale_m()


# --- Hands and feet -------------------------------------------------------------

## Crouches it at `at` facing `yaw`, each hand and foot where it stands about
## it, at `at`'s height (put each where it really stands with `plant`).
func put(at: Vector3, yaw: float) -> void:
	facing = yaw
	_yaw = yaw
	var basis := Basis(Vector3.UP, yaw)
	var pelvis_at := at - basis.z * 1.0 * scale_m()
	for limb in 4:
		var where := stance(limb)
		_plants[limb] = pelvis_at + basis * Vector3(where.x, 0.0, where.y)
		_limb_yaw[limb] = yaw
	_swing = -1
	_pelvis_ready = false
	if _skeleton:
		_pose(0.0)


## Puts a hand or foot down where it is to stand, at once.
func plant(limb: int, point: Vector3, yaw := NAN) -> void:
	_plants[limb] = point
	_limb_yaw[limb] = _yaw if is_nan(yaw) else yaw
	if _swing == limb:
		_swing = -1


## Lifts `limb` and carries it to `to`, turned `yaw`, high enough to pass over
## anything up to `clear` metres high (world height) on the way, in `seconds`
## (step_time if 0; longer for a long move). `planted` is emitted when it comes
## down. A move already under way with another limb is finished at once.
func step(limb: int, to: Vector3, yaw: float, clear := -INF, seconds := 0.0) -> void:
	if _swing >= 0 and _swing != limb:
		_land()
	_swing = limb
	_swing_t = 0.0
	_swing_from = _plants[limb]
	_swing_to = to
	_swing_yaw_from = _limb_yaw[limb]
	_swing_yaw_to = yaw
	var length := Vector2(to.x - _swing_from.x, to.z - _swing_from.z).length()
	var top := maxf(_swing_from.y, to.y)
	_swing_lift = maxf(0.3 * scale_m() + length * 0.15, (clear - top) + 0.3 * scale_m()) if clear > -INF else 0.3 * scale_m() + length * 0.15
	_swing_time = seconds if seconds > 0.0 else step_time * (1.0 + clampf(length / (4.0 * scale_m()), 0.0, 0.5))
	lifted.emit(limb, to)


## The limb in the air (HAND_L... FOOT_R), or -1.
func stepping() -> int:
	return _swing


## How far through its move the lifted limb is, 0..1.
func step_progress() -> float:
	return _swing_t / _swing_time if _swing >= 0 else 0.0


## How long the move under way takes, seconds.
func step_length() -> float:
	return _swing_time if _swing >= 0 else 0.0


## Where a limb is to stand (or stands).
func landing(limb: int) -> Vector3:
	return _swing_to if _swing == limb else _plants[limb]


func landing_yaw(limb: int) -> float:
	return _swing_yaw_to if _swing == limb else _limb_yaw[limb]


## Where a limb is now (in the air while it is carried).
func limb_point(limb: int) -> Vector3:
	if _swing != limb:
		return _plants[limb]
	var t := _swing_t / _swing_time
	# (up first and down last; across in between)
	var flat := _swing_from.lerp(_swing_to, smoothstep(0.1, 0.88, t))
	var rise := smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.72, 1.0, t))
	return flat + Vector3.UP * _swing_lift * rise


## Whether a point (its x and z) is under where a limb stands or comes down, `margin` metres more.
func under_limb(limb: int, point: Vector3, margin := 0.0) -> bool:
	var at := landing(limb)
	return Vector2(point.x - at.x, point.z - at.z).length() < PRINT[limb] * scale_m() + margin


## How far round a hand's or foot's print reaches from where it is put, metres.
func print_radius(limb: int) -> float:
	return PRINT[limb] * scale_m()


# --- The finger -------------------------------------------------------------------

## Reaches the hand on `target`'s side out over it and presses its long index
## finger down at it: REACH, HOVER (following `press_target`), DESCEND,
## PRESS (grinding: `pressed`), LIFT, and HOVER again over wherever
## `press_target` is now, and so on until `release()`, when it goes back
## (RETURN) to where it stood. `along`: the way the hall it presses into
## runs, so that its hand goes in edge first, its palm along it.
func press(target: Vector3, along := Vector3.ZERO) -> void:
	press_target = target
	_hover = target
	var local := Basis(Vector3.UP, _yaw).inverse() * (target - _pelvis)
	_press_hand = HAND_L if local.x >= 0.0 else HAND_R
	if _swing == _press_hand:
		_land()
	press_along = along.normalized() if along.length() > 0.01 else Basis(Vector3.UP, _yaw).z
	_tip_from = _rest_tip(_press_hand)
	_released = false
	_next(Press.REACH)


## Stops pressing: the hand goes back to where it stood.
func release() -> void:
	if _press == Press.NONE or _press == Press.RETURN:
		return
	_released = true
	if _press == Press.HOVER or _press == Press.REACH:
		_tip_from = _tip
		_next(Press.RETURN)


func pressing() -> bool:
	return _press != Press.NONE


func press_stage() -> Press:
	return _press


## Which hand presses (HAND_L or HAND_R).
func press_hand() -> int:
	return _press_hand


## How long each stage of a press takes, seconds.
func press_time_of(stage: Press) -> float:
	match stage:
		Press.REACH: return 2.6
		Press.HOVER: return hover_time
		Press.DESCEND: return descend_time
		Press.PRESS: return press_time
		Press.LIFT: return lift_time
		Press.RETURN: return 2.6
	return 0.0


## The tip of its index finger (of the pressing hand; else the left), world.
func fingertip() -> Vector3:
	return _tip


## Where the fingertip will come down, while it is over something (INF otherwise).
func press_point() -> Vector3:
	match _press:
		Press.REACH, Press.HOVER, Press.DESCEND, Press.PRESS:
			return Vector3(_hover.x, _hover.y, _hover.z)
	return Vector3.INF


## Whether a point is under the fingertip as it presses: within `radius` (and
## the finger's own thickness) of it, flat, and below it.
func finger_hits(point: Vector3, radius: float) -> bool:
	var down := _press == Press.PRESS or (_press == Press.DESCEND and _press_t > descend_time * 0.85)
	if not down:
		return false
	var flat := Vector2(point.x - _tip.x, point.z - _tip.z).length()
	return flat < radius + 0.06 * scale_m() and point.y < _tip.y + 1.5 and _tip.y - point.y < 3.0


## The pressing finger as a capsule [from, to, radius] (world) while it is down
## in among things, or [] when it is not.
func finger_capsule() -> Array:
	if _press != Press.DESCEND and _press != Press.PRESS and _press != Press.LIFT:
		return []
	var knuckle := _bone_world(INDEX_L if _press_hand == HAND_L else INDEX_R)
	return [knuckle, _tip, 0.06 * scale_m()]


## Where the fingertip is when the hand stands flat.
func _rest_tip(hand: int) -> Vector3:
	var ahead := Basis(Vector3.UP, _limb_yaw[hand]).z
	return _plants[hand] + ahead * (_palm * 0.5 + _finger) * scale_m() + Vector3.UP * 0.05 * scale_m()


func _next(stage: Press) -> void:
	_press = stage
	_press_t = 0.0


func _press_on(delta: float) -> void:
	if _press == Press.NONE:
		return
	_press_t += delta
	var target := press_target if press_target.is_finite() else _hover
	var over := _hover + Vector3.UP * hover_height
	var length := press_time_of(_press)
	var k := clampf(_press_t / maxf(length, 0.001), 0.0, 1.0)
	match _press:
		Press.REACH:
			_hover = _hover.lerp(target, 1.0 - exp(-1.0 * delta))
			var arc := Vector3.UP * sin(PI * k) * 0.6 * scale_m()
			_tip = _tip_from.lerp(_hover + Vector3.UP * hover_height, smoothstep(0.0, 1.0, k)) + arc
		Press.HOVER:
			# (it follows slowly: whoever runs gets out from under it)
			_hover = _hover.lerp(target, 1.0 - exp(-0.8 * delta))
			_tip = _hover + Vector3.UP * (hover_height + sin(_time * 1.3) * 1.5)
		Press.DESCEND:
			_tip = over.lerp(_hover + Vector3.UP * 0.4, smoothstep(0.0, 1.0, k))
		Press.PRESS:
			var grind := Vector3(cos(_time * 5.0), 0.0, sin(_time * 5.0)) * 0.6
			_tip = _hover + Vector3.UP * 0.25 + grind * smoothstep(0.0, 0.2, k)
		Press.LIFT:
			_tip = (_hover + Vector3.UP * 0.4).lerp(over, smoothstep(0.0, 1.0, k))
		Press.RETURN:
			_tip = _tip_from.lerp(_rest_tip(_press_hand), smoothstep(0.0, 1.0, k)) + Vector3.UP * sin(PI * k) * 0.5 * scale_m()
	if _press_t < length:
		return
	match _press:
		Press.REACH:
			_next(Press.HOVER)
		Press.HOVER:
			if _released:
				_tip_from = _tip
				_next(Press.RETURN)
			else:
				_next(Press.DESCEND)
		Press.DESCEND:
			_presses += 1
			_quakes.append([_hover, _time, 0.45])
			var puff := _dust[_press_hand]
			puff.global_position = _hover + Vector3.UP * 0.4
			puff.restart()
			puff.emitting = true
			if sound and not _thuds.is_empty():
				_thuds[_press_hand].global_position = _hover + Vector3.UP * 1.5
				_thuds[_press_hand].pitch_scale = 1.35
				_thuds[_press_hand].play()
			pressed.emit(_hover)
			_next(Press.PRESS)
		Press.PRESS:
			_next(Press.LIFT)
		Press.LIFT:
			if _released:
				_tip_from = _tip
				_next(Press.RETURN)
			else:
				_next(Press.HOVER)
		Press.RETURN:
			_press = Press.NONE
			press_target = Vector3.INF


# --- Where it is -----------------------------------------------------------------

## Its pelvis, world.
func pelvis() -> Vector3:
	return _pelvis


## Between its eyes, world.
func eye() -> Vector3:
	return _eye


## The yaw its body faces now.
func body_yaw() -> float:
	return _yaw


func _bone_world(b: int) -> Vector3:
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(_index[b]).origin


## How hard the ground shakes at `point` now from what it has put down, 0..1.
func shake_at(point: Vector3) -> float:
	var total := 0.0
	for quake: Array in _quakes:
		var age := _time - float(quake[1])
		var near := 1.0 - smoothstep(0.15 * height, 1.4 * height, (quake[0] as Vector3).distance_to(point))
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


# --- Each frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	if _swing >= 0:
		_swing_t += delta
		if _swing_t >= _swing_time:
			_land()
	if lean_on.is_finite():
		_lean_at = lean_on
	_lean = move_toward(_lean, 1.0 if lean_on.is_finite() and _press == Press.NONE else 0.0, delta * 0.25)
	_stoop = move_toward(_stoop, clampf(stoop, 0.0, 1.0), delta * 0.4)
	_press_on(delta)
	_pose(delta)
	_show(delta)
	while not _quakes.is_empty() and _time - float(_quakes[0][1]) > 4.0:
		_quakes.pop_front()


func _land() -> void:
	var limb := _swing
	_plants[limb] = _swing_to
	_limb_yaw[limb] = _swing_yaw_to
	_swing = -1
	_quakes.append([_swing_to, _time, 0.8])
	var puff := _dust[limb]
	puff.global_position = _swing_to + Vector3.UP * 0.5
	puff.restart()
	puff.emitting = true
	var rain := _debris[limb]
	rain.global_position = _swing_to - Vector3.UP * 1.0
	rain.restart()
	rain.emitting = true
	if sound and _thuds.size() > limb:
		_thuds[limb].global_position = _swing_to + Vector3.UP * 2.0
		_thuds[limb].pitch_scale = randf_range(0.85, 1.05)
		_thuds[limb].play()
	planted.emit(limb, _swing_to)


# --- Posing -----------------------------------------------------------------------

func _pose(delta: float) -> void:
	var s := scale_m()
	var turn := wrapf(facing - _yaw, -PI, PI)
	_yaw += clampf(turn, -turn_rate * delta, turn_rate * delta) if delta > 0.0 else turn
	var yaw_basis := Basis(Vector3.UP, _yaw)
	var left := yaw_basis.x
	var ahead := yaw_basis.z
	var lean := smoothstep(0.0, 1.0, _lean)
	var stooping := smoothstep(0.0, 1.0, _stoop)

	var points: Array[Vector3] = []
	for limb in 4:
		points.append(limb_point(limb))
	# Its body hangs between where its hands and feet stand (the pressing hand's
	# stand, not where it is now), low between its high elbows and knees.
	var middle := Vector3.ZERO
	for limb in 4:
		middle += _plants[limb] if limb == _press_hand and _press != Press.NONE else points[limb]
	middle *= 0.25
	var feet_y := (landing(FOOT_L).y + landing(FOOT_R).y) * 0.5
	var hands_y := (landing(HAND_L).y + landing(HAND_R).y) * 0.5
	var pelvis := middle - ahead * 1.0 * s
	pelvis.y = feet_y + 1.7 * s + lean * lean_rise
	if _swing >= 0:
		# (it sways off the limb it lifts)
		var away := pelvis - _plants[_swing]
		away.y = 0.0
		pelvis += away.normalized() * 0.12 * s * sin(PI * step_progress())
	if not _pelvis_ready or delta <= 0.0:
		_pelvis = pelvis
		_pelvis_ready = true
	else:
		_pelvis = _pelvis.lerp(pelvis, 1.0 - exp(-1.5 * delta))
	var base := Vector3(_pelvis.x, feet_y, _pelvis.z)
	_model.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * s), base)
	var to_skeleton := _skeleton.global_transform.affine_inverse()
	var sk := _skeleton.global_transform.basis.get_scale().x

	# The spine: from its pelvis out to its shoulders, as near level as its arms
	# want (lower when it peers down; up, near upright, when it rears to lean).
	var torso := (_rest_head[CHEST] - _rest_head[PELVIS]).length() * s + 0.85 * s
	var shoulders_y := hands_y + 2.0 * s - stooping * 1.5 * s
	var tilt := acos(clampf((shoulders_y - _pelvis.y) / torso, -0.6, 0.98))
	tilt = lerpf(tilt, 0.45, lean)
	var breathe := sin(_time * 0.7) * 0.015
	var sway := 0.0
	if _swing >= 0:
		sway = sin(PI * step_progress()) * (1.0 if _swing % 2 == 1 else -1.0)
	var r_pelvis := yaw_basis * Basis(Vector3.RIGHT, tilt * 0.5) * Basis(Vector3.BACK, sway * 0.05)
	var r_spine := r_pelvis * Basis(Vector3.RIGHT, tilt * 0.28 + breathe) * Basis(Vector3.UP, -sway * 0.06)
	var r_chest := r_spine * Basis(Vector3.RIGHT, tilt * 0.22 - breathe) * Basis(Vector3.BACK, -sway * 0.05)
	var j_pelvis := _pelvis
	var j_spine := j_pelvis + r_pelvis * (_rest_head[SPINE] - _rest_head[PELVIS]) * s
	var j_chest := j_spine + r_spine * (_rest_head[CHEST] - _rest_head[SPINE]) * s
	var j_neck := j_chest + r_chest * (_rest_head[NECK] - _rest_head[CHEST]) * s
	# The long neck reaches out ahead and the head looks: ahead, or down at what it peers at.
	var look_yaw := sin(_time * 0.11) * 0.3
	var look_pitch := 0.15
	if look_at_point.is_finite():
		var local := r_chest.inverse() * (look_at_point - j_neck)
		look_yaw = clampf(atan2(local.x, local.z), -1.0, 1.0)
		look_pitch = clampf(-atan2(local.y, Vector2(local.x, local.z).length()), -0.8, 1.3)
	_look_yaw = lerp_angle(_look_yaw, look_yaw, 1.0 - exp(-0.8 * delta)) if delta > 0.0 else look_yaw
	_look_pitch = lerpf(_look_pitch, look_pitch, 1.0 - exp(-0.8 * delta)) if delta > 0.0 else look_pitch
	# (the neck lifted against the pitch of its back, so the head is held out, not hung)
	var r_neck := r_chest * Basis(Vector3.RIGHT, -tilt * 0.55 + _look_pitch * 0.45) * Basis(Vector3.UP, _look_yaw * 0.5)
	var j_head := j_neck + r_neck * (_rest_head[HEAD] - _rest_head[NECK]) * s
	var r_head := r_neck * Basis(Vector3.UP, _look_yaw * 0.5) * Basis(Vector3.RIGHT, -tilt * 0.35 + _look_pitch * 0.55)
	_eye = j_head + r_head * Vector3(0.0, 0.33, 0.45) * s
	_eye_side = r_head.x * 0.11 * s

	var frames: Array[Transform3D] = []
	frames.resize(BONES.size())
	frames[PELVIS] = Transform3D(r_pelvis, j_pelvis)
	frames[SPINE] = Transform3D(r_spine, j_spine)
	frames[CHEST] = Transform3D(r_chest, j_chest)
	frames[NECK] = Transform3D(r_neck, j_neck)
	frames[HEAD] = Transform3D(r_head, j_head)

	# The legs: from its hips out to its feet, the knees bent up high and out.
	for side in 2:
		var limb := FOOT_L + side
		var thigh_b := THIGH_L if side == 0 else THIGH_R
		var out_side := left * (1.0 if side == 0 else -1.0)
		var hip := j_pelvis + r_pelvis * (_rest_head[thigh_b] - _rest_head[PELVIS]) * s
		var fy := _limb_yaw[limb] if _swing != limb else lerp_angle(_swing_yaw_from, _swing_yaw_to, step_progress())
		var lift := sin(PI * step_progress()) if _swing == limb else 0.0
		var r_foot := Basis(Vector3.UP, fy) * Basis(Vector3.RIGHT, lift * 0.4)
		var ankle := points[limb] + Vector3.UP * _ankle_height * s
		var pole := (Vector3.UP * 1.6 + out_side * 0.6 - ahead * 0.3).normalized()
		var knee := _bend(hip, ankle, _thigh * s, _shin * s, pole)
		ankle = knee + (ankle - knee).normalized() * _shin * s
		frames[thigh_b] = Transform3D(_along((knee - hip).normalized(), left), hip)
		frames[thigh_b + 1] = Transform3D(_along((ankle - knee).normalized(), left), knee)
		frames[thigh_b + 2] = Transform3D(r_foot, ankle)

	# The arms: from its shoulders out to its hands, the elbows bent up high and out.
	for side in 2:
		var limb := HAND_L + side
		var arm_b := ARM_L if side == 0 else ARM_R
		var index_b := INDEX_L if side == 0 else INDEX_R
		var sign_x := 1.0 if side == 0 else -1.0
		var out_side := left * sign_x
		var shoulder := j_chest + r_chest * (_rest_head[arm_b] - _rest_head[CHEST]) * s
		var hy := _limb_yaw[limb] if _swing != limb else lerp_angle(_swing_yaw_from, _swing_yaw_to, step_progress())
		# (planted: palm flat, fingers ahead and a little out, gripping the edge)
		var hand_dir := (Basis(Vector3.UP, hy).z + out_side * 0.25).normalized()
		var side_hint := left
		var palm := points[limb]
		var curl := 0.35
		var index_curl := 0.25
		var wrist_at := palm - hand_dir * _palm * s * 0.5 + Vector3.UP * 0.08 * s
		if _swing == limb:
			hand_dir = (hand_dir + Vector3.DOWN * 0.4 * sin(PI * step_progress())).normalized()
			curl = 0.6
		var pressing_this := _press != Press.NONE and side == _press_hand
		if pressing_this:
			# The index finger straight down at what it presses, the palm edge on
			# along the hall, the other fingers curled in.
			var from_shoulder := _tip - shoulder
			from_shoulder.y = 0.0
			var finger_dir := (Vector3.DOWN + from_shoulder.normalized() * 0.18).normalized()
			if _press == Press.REACH or _press == Press.RETURN:
				var k := smoothstep(0.0, 1.0, _press_t / press_time_of(_press))
				var w := k if _press == Press.REACH else 1.0 - k
				finger_dir = hand_dir.lerp(finger_dir, w).normalized()
			hand_dir = finger_dir
			side_hint = press_along
			wrist_at = _tip - finger_dir * (_finger + _palm) * s
			curl = 1.3
			index_curl = 0.0
		elif lean > 0.0:
			# (rearing up, its hands on what it leans on, either side)
			var along := _lean_at - _pelvis
			along.y = 0.0
			var rest_on := _lean_at + out_side * 1.3 * s
			var lean_dir := (along.normalized() + out_side * 0.2).normalized()
			wrist_at = wrist_at.lerp(rest_on - lean_dir * _palm * s * 0.5 + Vector3.UP * 0.08 * s, lean)
			hand_dir = hand_dir.slerp(lean_dir, lean)
		var pole := (Vector3.UP * 1.6 + out_side * 0.6 - ahead * 0.3).normalized()
		var elbow := _bend(shoulder, wrist_at, _upper_arm * s, _forearm * s, pole)
		var wrist := elbow + (wrist_at - elbow).normalized() * _forearm * s
		frames[arm_b] = Transform3D(_along((elbow - shoulder).normalized(), side_hint), shoulder)
		frames[arm_b + 1] = Transform3D(_along((wrist - elbow).normalized(), side_hint), elbow)
		var hand_basis := _along(hand_dir, side_hint)
		frames[arm_b + 2] = Transform3D(hand_basis, wrist)
		var knuckles := wrist + hand_dir * _palm * s
		# (fingers curled towards the palm, which faces down as the hand is put)
		var finger_dir := (Basis(hand_basis.x, curl) * hand_dir).normalized()
		frames[arm_b + 3] = Transform3D(_along(finger_dir, side_hint), knuckles)
		var index_dir := (Basis(hand_basis.x, index_curl) * hand_dir).normalized()
		var index_base := knuckles + (_rest_head[index_b] - _rest_head[arm_b + 3]).length() * s * hand_basis.x * -sign_x
		frames[index_b] = Transform3D(_along(index_dir, side_hint), index_base)
		if pressing_this or (_press == Press.NONE and side == 0):
			_tip = index_base + index_dir * _finger * s if not pressing_this else _tip

	# Each bone moved from where it stood by as much as its frame has moved.
	for b in BONES.size():
		var posed := frames[b]
		posed.basis = posed.basis.orthonormalized().scaled(Vector3.ONE * sk)
		var g := to_skeleton * posed * _rest_frame[b].affine_inverse() * _rest[b]
		var bone := _index[b]
		_skeleton.set_bone_pose_position(bone, g.origin)
		_skeleton.set_bone_pose_rotation(bone, g.basis.get_rotation_quaternion())
		_skeleton.set_bone_pose_scale(bone, g.basis.get_scale())


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
	for limb in 4:
		var blot := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE * PRINT[limb] * 2.6 * s
		blot.mesh = plane
		blot.material_override = ColossusLook.shadow_material()
		blot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blot.top_level = true
		blot.visible = false
		add_child(blot)
		_blots.append(blot)
		var puff := ColossusLook.dust(0.9 * s)
		add_child(puff)
		_dust.append(puff)
		# (stones and earth knocked off the wall top, raining into the halls)
		var rain := ColossusLook.stones(0.022 * s)
		rain.one_shot = true
		rain.explosiveness = 0.6
		rain.amount = 30
		rain.emission_sphere_radius = 0.5 * s
		rain.initial_velocity_max = 6.0
		rain.spread = 70.0
		add_child(rain)
		_debris.append(rain)
	_tip_blot = MeshInstance3D.new()
	var tip_plane := PlaneMesh.new()
	tip_plane.size = Vector2.ONE * 0.4 * s
	_tip_blot.mesh = tip_plane
	_tip_blot.material_override = ColossusLook.shadow_material()
	_tip_blot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tip_blot.top_level = true
	_tip_blot.visible = false
	add_child(_tip_blot)
	# Its eyes, as two pale points that show through the mist from far off.
	for k in 2:
		var glint := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * 0.3 * s
		glint.mesh = quad
		glint.material_override = ColossusLook.glint_material()
		glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glint.top_level = true
		add_child(glint)
		_glints.append(glint)
	_falling = ColossusLook.stones(0.018 * s)
	_falling.emission_sphere_radius = 0.3 * s
	add_child(_falling)
	if sound:
		if _thud_sound == null:
			_thud_sound = thud_sound()
			_rumble_sound = rumble_sound()
		for limb in 4:
			var thud := AudioStreamPlayer3D.new()
			thud.stream = _thud_sound
			thud.volume_db = volume_db
			thud.unit_size = 0.6 * s
			thud.max_distance = sound_range
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
	_material.set_shader_parameter(&"glow_energy", glow)
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
	# A shadow where a hand or foot will come down, darker as it nears.
	for limb in 4:
		var blot := _blots[limb]
		if _swing == limb:
			var near := smoothstep(0.35, 1.0, step_progress())
			blot.visible = near > 0.0
			blot.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (1.5 - 0.45 * near)), _swing_to + Vector3.UP * 0.15)
			(blot.material_override as ShaderMaterial).set_shader_parameter(&"strength", near * 0.8)
		else:
			blot.visible = false
	# The fingertip's, on the ground under it, growing darker and tighter as it comes down.
	var under := press_point()
	_tip_blot.visible = under.is_finite()
	if under.is_finite():
		var high := clampf((_tip.y - under.y) / maxf(hover_height, 1.0), 0.0, 1.5)
		var dark := 0.85 - 0.5 * clampf(high, 0.0, 1.0)
		if _press == Press.REACH:
			dark *= smoothstep(0.3, 1.0, _press_t / press_time_of(Press.REACH))
		_tip_blot.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (0.8 + high * 1.6)), Vector3(_tip.x, under.y + 0.12, _tip.z))
		(_tip_blot.material_override as ShaderMaterial).set_shader_parameter(&"strength", dark)
	# Earth falling from a lifted hand or foot, and from the finger as it comes down.
	var high_limb := _swing >= 0 and limb_point(_swing).y - landing(_swing).y > 0.2 * s
	var finger_down := _press == Press.DESCEND or _press == Press.PRESS
	_falling.emitting = high_limb or finger_down
	if high_limb:
		_falling.global_position = limb_point(_swing)
	elif finger_down:
		_falling.global_position = _tip + Vector3.UP * 0.3 * s
	# A rumble that rises as a hand or foot (or the finger) comes down.
	if _rumble:
		var loud := 0.0
		var at := Vector3.ZERO
		if _swing >= 0:
			loud = smoothstep(0.45, 0.98, step_progress())
			at = _swing_to
		if _press == Press.DESCEND:
			loud = smoothstep(0.2, 1.0, _press_t / descend_time)
			at = _hover
		if loud > 0.0:
			_rumble.global_position = at + Vector3.UP * 3.0
			_rumble.volume_db = lerpf(-40.0, volume_db - 2.0, loud)
			if not _rumble.playing:
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

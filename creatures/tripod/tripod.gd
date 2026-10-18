class_name Tripod
extends Node3D
## A Martian fighting-machine, after The War of the Worlds: a great hood of
## weathered bronze high on three long noodly legs, a pale eye in the dark
## under its brow, a heat ray on a jointed arm, cable tentacles hanging under
## it, red weed trailing off it. Its look, how it walks, its searchlight, its
## heat ray, its grasping tentacle and its sounds are here; what it does is for
## the game to say. It knows nothing of the game it is in.
##
## HOW TO DRIVE IT. Put it in the world and move it: its position is the point
## on the ground under its body, its rotation about Y the way its body faces
## (+Z). It walks by itself to keep up: its feet stay planted where they are
## until the body has gone on far enough, then one at a time a leg lifts
## (high, over anything in its way), swings and comes down hard (`footfall`)
## on open ground, avoiding wherever `foot_ok` says not to stand. It takes a
## step every few seconds, so it is slow: keep it under `WALK_SPEED`, and
## slower while `strain` (how far its legs have fallen behind, 0..1) is high.
## Its body sways over its feet, sinks as a leg lifts and jolts as it lands.
## `settle()` puts its feet straight down where they belong (after putting it
## somewhere new).
##
## Then say what it is doing:
## - `look_at_point`: what its hood turns to (INF: it follows its searchlight,
##   or faces ahead). It turns slowly, as something that size would.
## - `searchlight` and `beam_target`: its eye's beam, a cone of pale light in
##   the mist, aimed at a point (INF: straight ahead and down). The eye leads,
##   turning in its bezel, and the hood follows. `beam_hit` is where the light
##   falls (what it hits first), `eye_point()` and `beam_dir` where it comes
##   from and which way it goes.
## - `arm_target` (INF: folded away), `charge` (0..1: the emitter glows and its
##   hum rises) and `firing`: the heat ray, from the emitter to whatever it
##   meets first on the way to `arm_target` (`ray_hit`). Where it burns it
##   leaves a ragged black scorch with a glowing seam down it, and steam rising
##   off it after.
## - `reach_target` (INF: it hangs): the grasper (the tentacle with claws)
##   reaches down towards it, stretching as far as it must; `grasper_tip()`.
## - `horn()`: its horn, the deep distorted "ULLA" (`horned`).
##
## Signals: `footfall(at, weight)`, `horned`. Its footfalls shake the camera
## near them (`shake`). It plays its own sounds (made in code: TripodSound),
## unless `sound` is off. Run tests with `--audio-driver Dummy`.
##
## It is drawn by TripodRig (tripod_rig.gd) on the model made by
## tools/build_tripod.py, with TripodLook's materials: three draws near, three
## far (the demade model), and its beam, ray and effects.

signal footfall(at: Vector3, weight: float)
signal horned

## As fast as it comfortably strides, m/s.
const WALK_SPEED := 2.6
## How long one step takes, seconds, and how long it waits after one.
const STEP_TIME := 3.2
const STEP_REST := 0.35
## A planted foot this far (flat) from where it would rather be will step.
const STRIDE := 7.0
## How far ahead of the body it puts its feet, in seconds of its motion.
const LEAD := 2.8
## How high a lifted foot goes over whatever is under its path.
const CLEAR := 6.0
## The searchlight's half-angle (degrees) and how far it reaches.
const BEAM_ANGLE := 6.5
const BEAM_RANGE := 220.0

## Use only the demade model. Set before it enters the tree.
@export var low_poly := false
## How far off the full model gives way to the demade one (m). Set before it enters the tree.
@export var far_from := 150.0
## Plays its own sounds.
@export var sound := true
@export var volume_db := 4.0
## How far off it can be heard (m): the horn carries across the whole maze.
@export var sound_range := 900.0
## Its footfalls shake the camera within `shake_range` metres.
@export var shake := true
@export var shake_range := 90.0
@export var shake_strength := 0.35
## Dust from its feet, sparks and steam from the ray.
@export var effects := true
## The searchlight's light casts shadows (the walls cut it).
@export var beam_shadows := true
## A body round each planted foot that things bump into (on layer 1).
@export var foot_bodies := true
## What its feet stand on and its light and ray meet (physics layers).
@export_flags_3d_physics var ray_mask := 1

## Whether a point is somewhere a foot may come down (null: anywhere).
var foot_ok := Callable()
var searchlight := true
var beam_target := Vector3.INF
var look_at_point := Vector3.INF
var arm_target := Vector3.INF
var charge := 0.0
var firing := false
var reach_target := Vector3.INF
## Where its searchlight falls (INF when it is off or meets nothing).
var beam_hit := Vector3.INF
## The way its beam goes (world).
var beam_dir := Vector3.FORWARD
## Where its heat ray meets something, while it fires.
var ray_hit := Vector3.INF
## How far its legs have fallen behind its body (0..1): slow it down.
var strain := 0.0
## How fast it is going (measured from how it is moved).
var velocity := Vector3.ZERO
## Where each foot is, and whether it is down.
var feet: Array[Vector3] = []
var stepping := -1
var steps := 0
var rig: TripodRig

var _from: Array[Vector3] = []
var _to: Array[Vector3] = []
var _peak: Array[float] = []
var _t := 0.0
var _rested := 0.0
var _was_at := Vector3.INF
var _time := 0.0
var _head_yaw := 0.0
var _head_pitch := 0.0
var _yaw_speed := 0.0
var _eye_dir := Vector3.ZERO
var _aim := Vector3.INF
var _unfold := 0.0
var _drop := 0.0
var _bob := 0.0
var _bob_speed := 0.0
var _lean := Vector2.ZERO
var _sway := Vector3.ZERO
var _tentacles: Array[PackedVector3Array] = []
var _tentacles_was: Array[PackedVector3Array] = []
var _stretch := 1.0
var _settled := false
var _shake := 0.0
var _shaking: Camera3D
var _bodies: Array[AnimatableBody3D] = []
var _skip: Array[RID] = []

var _beam: MeshInstance3D
var _beam_material: ShaderMaterial
var _spot: SpotLight3D
var _ray: MeshInstance3D
var _ray_material: ShaderMaterial
var _glow_light: OmniLight3D
var _burn_light: OmniLight3D
var _dust: CPUParticles3D
var _sparks: CPUParticles3D
var _smoke: CPUParticles3D
var _steam: CPUParticles3D
var _scorch_material: ShaderMaterial
var _trails: Array[Dictionary] = []
var _burning: Dictionary = {}

var _voice: AudioStreamPlayer3D
var _stomp: AudioStreamPlayer3D
var _hiss: AudioStreamPlayer3D
var _hum: AudioStreamPlayer3D
var _roar: AudioStreamPlayer3D
var _sizzle: AudioStreamPlayer3D
var _clank: AudioStreamPlayer3D


func _ready() -> void:
	rig = TripodRig.new()
	rig.name = "Rig"
	rig.low_poly = low_poly
	rig.far_from = far_from
	add_child(rig)
	for i in TripodRig.LEGS:
		feet.append(Vector3.ZERO)
		_from.append(Vector3.ZERO)
		_to.append(Vector3.ZERO)
		_peak.append(0.0)
	for k in TripodRig.TENTACLES:
		_tentacles.append(PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]))
		_tentacles_was.append(PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]))
	if foot_bodies:
		for i in TripodRig.LEGS:
			var body := AnimatableBody3D.new()
			body.name = "Foot%d" % i
			body.top_level = true
			body.sync_to_physics = false
			body.collision_layer = 0
			body.collision_mask = 0
			var shape := CollisionShape3D.new()
			var cylinder := CylinderShape3D.new()
			cylinder.radius = 1.3
			cylinder.height = 12.0
			shape.shape = cylinder
			shape.position.y = 7.0
			body.add_child(shape)
			add_child(body)
			_bodies.append(body)
			_skip.append(body.get_rid())
	_make_light()
	_make_ray()
	if effects:
		_make_effects()
	if sound:
		_make_sounds()
	_eye_dir = global_basis * TripodRig.EYE_REST.normalized()
	settle.call_deferred()


# --- Being driven ---

## Puts its feet straight down where they belong round where it is now, the
## tentacles hanging, nothing in motion: for when it is put somewhere.
func settle() -> void:
	if not is_inside_tree():
		return
	velocity = Vector3.ZERO
	_was_at = global_position
	stepping = -1
	for i in TripodRig.LEGS:
		feet[i] = _find_spot(_home(i))
		_plant_body(i, true)
	_head_yaw = 0.0
	_settled = true
	_pose(0.0)
	for k in TripodRig.TENTACLES:
		var root := _tentacles[k][0]
		var seg := rig.segment_length[k]
		for j in 5:
			_tentacles[k][j] = root + Vector3.DOWN * seg * j
			_tentacles_was[k][j] = _tentacles[k][j]
	_pose(0.0)


## Sounds its horn: the deep, distorted, droning "ULLA".
func horn() -> void:
	if _voice:
		_voice.stream = TripodSound.horn()
		_voice.play()
	horned.emit()


## Where the great eye's lens is (world).
func eye_point() -> Vector3:
	return _world(rig.eye_lens()[0])


## Where the heat ray comes out (world).
func emitter_tip() -> Vector3:
	return _world(rig.emitter_tip()[0])


## Where the grasper's claws are (world).
func grasper_tip() -> Vector3:
	return _tentacles[TripodRig.GRASPER][4]


## Where its body is (world): the middle of the drum the hood turns on.
func body_point() -> Vector3:
	return _world(rig.bone_pose("body").origin)


## Each tentacle's five points, root first (world).
func tentacle_points(k: int) -> PackedVector3Array:
	return _tentacles[k]


func _world(skeleton_point: Vector3) -> Vector3:
	return rig.skeleton.global_transform * skeleton_point


func _local(world_point: Vector3) -> Vector3:
	return rig.skeleton.global_transform.affine_inverse() * world_point


# --- Every frame ---

func _physics_process(delta: float) -> void:
	if delta <= 0.0 or rig == null or rig.skeleton == null:
		return
	if not _settled:
		settle()
	_time += delta
	var at := global_position
	if _was_at.is_finite():
		var moved := (at - _was_at) / delta
		if moved.length() > 40.0:
			# (put somewhere: not a speed)
			settle()
		else:
			velocity = velocity.lerp(moved, 1.0 - exp(-4.0 * delta))
	_was_at = at
	_walk(delta)
	_swing_tentacles(delta)
	_pose(delta)
	_light_and_ray(delta)
	_burns(delta)


func _process(delta: float) -> void:
	_shake_camera(delta)


# --- Walking ---

## Where foot `i` would rather be, with the body standing still where it is.
func _home(i: int) -> Vector3:
	var rest := rig.feet_rest[i]
	return global_transform * Vector3(rest.x, 0.0, rest.z)


func _walk(delta: float) -> void:
	var wants: Array[Vector3] = []
	var worst := -1
	var worst_error := 0.0
	strain = 0.0
	for i in TripodRig.LEGS:
		var want := _home(i) + Vector3(velocity.x, 0.0, velocity.z) * LEAD
		wants.append(want)
		if i == stepping:
			continue
		var error := Vector2(feet[i].x - want.x, feet[i].z - want.z).length()
		strain = maxf(strain, clampf((error - STRIDE * 1.5) / 18.0, 0.0, 1.0))
		if error > worst_error:
			worst_error = error
			worst = i
	if stepping >= 0:
		_t += delta / _step_time()
		var t := minf(_t, 1.0)
		var i := stepping
		# (it keeps after where it is going a little, while still high)
		if t < 0.6:
			var better := wants[i] + Vector3(velocity.x, 0.0, velocity.z) * STEP_TIME * 0.4
			if Vector2(better.x - _to[i].x, better.z - _to[i].z).length() > 4.0:
				var spot := _find_spot(better)
				_to[i] = _to[i].lerp(spot, 0.5)
				_peak[i] = maxf(_peak[i], _clearance(_from[i], _to[i]))
		feet[i] = _swing_foot(_from[i], _to[i], _peak[i], t)
		if _hiss and t > 0.02 and t < 0.05 and not _hiss.playing:
			_hiss.global_position = feet[i] + Vector3.UP * 8.0
			_hiss.play()
		if _t >= 1.0:
			feet[i] = _to[i]
			stepping = -1
			_rested = 0.0
			steps += 1
			_plant_body(i, true)
			_landed(i)
	else:
		_rested += delta
		var still := velocity.length() < 0.3
		var due := STRIDE if not still else 3.0
		if worst >= 0 and worst_error > due and _rested > (STEP_REST if not still else 1.2):
			_start_step(worst, wants[worst] + Vector3(velocity.x, 0.0, velocity.z) * STEP_TIME * 0.5)


## Faster steps the faster it goes (a little).
func _step_time() -> float:
	return clampf(STEP_TIME - Vector2(velocity.x, velocity.z).length() * 0.25, STEP_TIME * 0.7, STEP_TIME)


func _start_step(i: int, want: Vector3) -> void:
	stepping = i
	_t = 0.0
	_from[i] = feet[i]
	_to[i] = _find_spot(want)
	_peak[i] = _clearance(_from[i], _to[i])
	_plant_body(i, false)


## How high a foot must go to clear whatever is under the way from `a` to `b`.
func _clearance(a: Vector3, b: Vector3) -> float:
	var top := maxf(a.y, b.y) + 7.0
	for k in 7:
		var at := a.lerp(b, k / 6.0)
		var hit := _down(at, false)
		if hit.is_finite():
			top = maxf(top, hit.y + CLEAR)
	return top


## A foot swinging from `a` to `b` over `peak`, `t` of the way through: it
## lifts straight up first, swings across high, and comes down heavily.
static func _swing_foot(a: Vector3, b: Vector3, peak: float, t: float) -> Vector3:
	var across := smoothstep(0.22, 0.8, t)
	var flat := a.lerp(b, across)
	var up := smoothstep(0.0, 0.32, t)
	var down := t if t < 0.7 else 1.0 - pow((t - 0.7) / 0.3, 2.0)
	var y := lerpf(a.y, b.y, across)
	var lift := minf(up, down if t > 0.7 else 1.0)
	return Vector3(flat.x, lerpf(y, peak, lift), flat.z)


## A foot has come down: the jolt, the boom, the dust, the shake.
func _landed(i: int) -> void:
	var at := feet[i]
	_bob_speed -= 2.6
	rig.kick(i, 1.0)
	footfall.emit(at, 1.0)
	if _stomp:
		_stomp.global_position = at + Vector3.UP * 2.0
		_stomp.pitch_scale = randf_range(0.9, 1.06)
		_stomp.play()
	if _dust:
		_dust.global_position = at + Vector3.UP * 0.3
		_dust.restart()
		_dust.emitting = true
	if shake:
		var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
		if camera:
			var near := 1.0 - clampf(camera.global_position.distance_to(at) / shake_range, 0.0, 1.0)
			_shake = maxf(_shake, near * near * shake_strength)


## Turns a foot's body on (planted) or off (lifted).
func _plant_body(i: int, planted: bool) -> void:
	if i >= _bodies.size():
		return
	_bodies[i].global_position = feet[i]
	_bodies[i].collision_layer = 1 if planted else 0


## Somewhere near `want` for a foot: open ground (not the top of a wall, if
## there is open ground near), flat round about, where `foot_ok` allows.
func _find_spot(want: Vector3) -> Vector3:
	var ground := global_position.y
	var best := Vector3.INF
	var best_far := INF
	var high := Vector3.INF
	for ring: float in [0.0, 3.0, 6.0, 9.0, 12.0, 15.0, 19.0]:
		var count := 1 if ring == 0.0 else 8
		for k in count:
			var a := TAU * k / count + ring * 0.37
			var at := want + Vector3(cos(a), 0.0, sin(a)) * ring
			var hit := _down(at)
			if not hit.is_finite() or not _flat_round(hit, 1.9):
				continue
			if foot_ok.is_valid() and not foot_ok.call(hit):
				continue
			if hit.y < ground + 2.5:
				if ring < best_far:
					best_far = ring
					best = hit
			elif not high.is_finite():
				high = hit
		if best.is_finite():
			break
	if best.is_finite():
		return best
	if high.is_finite():
		return high
	return Vector3(want.x, ground, want.z)


## What is under a point (from high above), or INF; `upward` only what faces up.
func _down(at: Vector3, upward := true) -> Vector3:
	if not is_inside_tree():
		return Vector3.INF
	var top := global_position.y + 160.0
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, top, at.z), Vector3(at.x, global_position.y - 40.0, at.z), ray_mask, _skip)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (upward and (hit["normal"] as Vector3).y < 0.7):
		return Vector3.INF
	return hit["position"]


func _flat_round(at: Vector3, radius: float) -> bool:
	var space := get_world_3d().direct_space_state
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var p := at + Vector3(cos(a), 0.0, sin(a)) * radius
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 3.0, ray_mask, _skip))
		if hit.is_empty() or absf((hit["position"] as Vector3).y - at.y) > 0.6:
			return false
	return true


# --- Tentacles ---

## Swings the tentacles (a few points each, on springs), and reaches with the grasper.
func _swing_tentacles(delta: float) -> void:
	var gravity := Vector3.DOWN * 7.0 * delta * delta
	var reaching := reach_target.is_finite()
	var g := TripodRig.GRASPER
	var root_g := _tentacles[g][0]
	var want_stretch := 1.0
	if reaching:
		want_stretch = clampf(root_g.distance_to(reach_target) / (rig.segment_length[g] * 4.0) * 1.02, 1.0, 3.8)
	_stretch = move_toward(_stretch, want_stretch, delta * (0.55 if want_stretch > _stretch else 0.9))
	for k in TripodRig.TENTACLES:
		var points := _tentacles[k]
		var was := _tentacles_was[k]
		var root := points[0]
		was[0] = root
		var seg := rig.segment_length[k] * (_stretch if k == g else 1.0)
		for j in range(1, 5):
			var p := points[j]
			var moved := (p - was[j]) * 0.985
			# (a slow, heavy sway of its own, out of step with the others)
			var wind := Vector3(sin(_time * 0.45 + k * 1.7 + j * 0.6), 0.0, cos(_time * 0.37 + k * 2.3 + j * 0.4)) * 0.6 * delta * delta
			was[j] = p
			points[j] = p + moved + gravity + wind
		if k == g and reaching:
			# (the claws are drawn to what it reaches for, the cable curling down after them)
			var pull := 1.0 - exp(-3.0 * delta)
			points[4] = points[4].lerp(reach_target, pull)
			points[3] = points[3].lerp(reach_target + (root - reach_target).normalized() * seg, pull * 0.5)
		for iteration in 4:
			for j in 4:
				var a := points[j]
				var b := points[j + 1]
				var span := b - a
				var length := span.length()
				if length < 0.0001:
					continue
				var fix := span * (1.0 - seg / length)
				if j == 0:
					points[j + 1] = b - fix
				else:
					points[j] = a + fix * 0.5
					points[j + 1] = b - fix * 0.5
		_tentacles[k] = points
		_tentacles_was[k] = was


# --- Posing ---

func _pose(delta: float) -> void:
	var to_local := rig.skeleton.global_transform.affine_inverse()
	# Sway: the body over its planted feet, sinking as a leg lifts, jolting as one lands.
	var centre := Vector3.ZERO
	var planted := 0
	var foot_y := 0.0
	for i in TripodRig.LEGS:
		var local_foot := to_local * feet[i]
		foot_y += local_foot.y
		if i != stepping:
			centre += Vector3(local_foot.x, 0.0, local_foot.z)
			planted += 1
	centre /= maxf(planted, 1.0)
	var lifting := sin(clampf(_t, 0.0, 1.0) * PI) if stepping >= 0 else 0.0
	var smooth := 1.0 - exp(-1.6 * delta) if delta > 0.0 else 1.0
	_sway = _sway.lerp((centre * 0.22).limit_length(3.2), smooth)
	_drop = lerpf(_drop, -1.6 * lifting, smooth)
	_bob_speed += (-_bob * 9.0 - _bob_speed * 3.2) * delta
	_bob += _bob_speed * delta
	var speed := Vector2(velocity.x, velocity.z).length()
	var lean_want := Vector2(centre.x, centre.z) * 0.012 + Vector2(0.0, speed * 0.018)
	_lean = _lean.lerp(lean_want.limit_length(0.09), smooth)
	var idle := Vector3(sin(_time * 0.41) * 0.5, sin(_time * 0.29) * 0.35, sin(_time * 0.33 + 1.0) * 0.4)
	var body_at := rig.body_rest + _sway + idle + Vector3.UP * (foot_y / 3.0 * 0.5 + _drop + _bob)
	var body_turn := Basis(Vector3.RIGHT, _lean.y) * Basis(Vector3.FORWARD, _lean.x * 0.8) * Basis(Vector3.UP, sin(_time * 0.23) * 0.03)

	# The hood turns (slowly) to what it watches, or after its light.
	var watch := look_at_point if look_at_point.is_finite() else (beam_target if searchlight and beam_target.is_finite() else Vector3.INF)
	var yaw_want := 0.0
	var pitch_want := 0.0
	if watch.is_finite():
		var local_watch := to_local * watch
		var head_local := rig.on_body(rig.head_rest, body_at, body_turn)
		var to := local_watch - head_local
		yaw_want = clampf(atan2(to.x, to.z), -2.1, 2.1)
		var flat := Vector2(to.x, to.z).length()
		pitch_want = clampf((atan2(to.y, flat) + 0.75) * 0.35, -0.18, 0.12)
	var yaw_error := angle_difference(_head_yaw, yaw_want)
	_yaw_speed = move_toward(_yaw_speed, clampf(yaw_error * 1.2, -0.5, 0.5), 0.6 * delta)
	_head_yaw += _yaw_speed * delta
	_head_pitch = lerpf(_head_pitch, pitch_want, smooth)

	# The eye looks after its beam's target.
	var head_turn := body_turn * Basis(Vector3.UP, _head_yaw) * Basis(Vector3.RIGHT, -_head_pitch)
	var lens := _world(rig.on_head(rig.eye_rest, rig.on_body(rig.head_rest, body_at, body_turn), head_turn))
	var eye_want := (beam_target - lens).normalized() if beam_target.is_finite() else global_basis * (head_turn * TripodRig.EYE_REST.normalized())
	_eye_dir = _eye_dir.slerp(eye_want, 1.0 - exp(-5.0 * delta)) if delta > 0.0 and _eye_dir.dot(eye_want) > -0.99 else eye_want

	# The heat ray's arm swings round to what it aims at.
	var unfold_want := 1.0 if arm_target.is_finite() else 0.0
	_unfold = move_toward(_unfold, unfold_want, delta * 0.7)
	if arm_target.is_finite():
		_aim = arm_target if not _aim.is_finite() else _aim.lerp(arm_target, 1.0 - exp(-4.0 * delta))
	var aim_local := to_local * _aim if _aim.is_finite() else rig.on_head(rig.wrist_rest + TripodRig.EMITTER_REST * 20.0, rig.on_body(rig.head_rest, body_at, body_turn), head_turn)
	if not arm_target.is_finite() and _unfold <= 0.0:
		_aim = Vector3.INF

	# (the tentacles hang from where the hood has taken their roots)
	var head_local := rig.on_body(rig.head_rest, body_at, body_turn)
	for k in TripodRig.TENTACLES:
		var root := _world(rig.on_head(rig.roots_rest[k], head_local, head_turn))
		_tentacles[k][0] = root
		_tentacles_was[k][0] = root
	var feet_local: Array = []
	for i in TripodRig.LEGS:
		feet_local.append(to_local * feet[i])
	var tentacles_local: Array = []
	for k in TripodRig.TENTACLES:
		var points := PackedVector3Array()
		for p in _tentacles[k]:
			points.append(to_local * p)
		tentacles_local.append(points)
	var swings: Array = []
	for i in TripodRig.LEGS:
		swings.append(clampf(_t, 0.0, 1.0) if i == stepping else 0.0)
	var eye_local := (to_local.basis * _eye_dir).normalized()
	rig.pose(body_at, body_turn, _head_yaw, _head_pitch, eye_local, aim_local, smoothstep(0.0, 1.0, _unfold), feet_local, swings, tentacles_local, delta)


# --- The searchlight and the heat ray ---

func _make_light() -> void:
	_beam = MeshInstance3D.new()
	_beam.name = "Beam"
	_beam.mesh = TripodLook.cone_mesh(24)
	_beam_material = TripodLook.beam()
	_beam.material_override = _beam_material
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.top_level = true
	_beam.extra_cull_margin = 200.0
	add_child(_beam)
	_spot = SpotLight3D.new()
	_spot.name = "Searchlight"
	_spot.light_color = Color(0.86, 0.92, 1.0)
	_spot.light_energy = 6.0
	_spot.spot_angle = BEAM_ANGLE * 1.25
	_spot.spot_angle_attenuation = 0.6
	_spot.spot_attenuation = 0.0
	_spot.spot_range = BEAM_RANGE
	_spot.shadow_enabled = beam_shadows
	_spot.shadow_bias = 0.15
	_spot.shadow_normal_bias = 2.0
	_spot.top_level = true
	add_child(_spot)
	_glow_light = OmniLight3D.new()
	_glow_light.light_color = Color(1.0, 0.6, 0.3)
	_glow_light.light_energy = 0.0
	_glow_light.omni_range = 14.0
	_glow_light.top_level = true
	add_child(_glow_light)


func _make_ray() -> void:
	_ray = MeshInstance3D.new()
	_ray.name = "HeatRay"
	_ray.mesh = TripodLook.tube_mesh(10)
	_ray_material = TripodLook.ray()
	_ray.material_override = _ray_material
	_ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ray.top_level = true
	_ray.visible = false
	_ray.extra_cull_margin = 200.0
	add_child(_ray)
	_burn_light = OmniLight3D.new()
	_burn_light.light_color = Color(1.0, 0.5, 0.2)
	_burn_light.light_energy = 0.0
	_burn_light.omni_range = 20.0
	_burn_light.top_level = true
	add_child(_burn_light)
	_scorch_material = TripodLook.scorch()


func _light_and_ray(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	# The searchlight.
	var lens := eye_point()
	if _voice:
		_voice.global_position = lens
	var lens_dir: Vector3 = (rig.skeleton.global_basis * (rig.eye_lens()[1] as Vector3)).normalized()
	beam_dir = lens_dir
	_beam.visible = searchlight
	_spot.visible = searchlight
	beam_hit = Vector3.INF
	if searchlight:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(lens, lens + beam_dir * BEAM_RANGE, ray_mask, _skip))
		var length := BEAM_RANGE
		if not hit.is_empty():
			beam_hit = hit["position"]
			length = lens.distance_to(beam_hit)
		var radius := length * tan(deg_to_rad(BEAM_ANGLE))
		var up := Vector3.UP if absf(beam_dir.y) < 0.98 else Vector3.FORWARD
		_beam.global_transform = Transform3D(Basis.looking_at(beam_dir, up).scaled_local(Vector3(radius, radius, length)), lens)
		_spot.global_transform = Transform3D(Basis.looking_at(beam_dir, up), lens + beam_dir * 0.5)
		_spot.spot_range = length + 30.0

	# The heat ray: charging, then burning.
	var tip_and_way := rig.emitter_tip()
	var tip := _world(tip_and_way[0])
	var glow := 0.12 + charge * 6.0 + (8.0 if firing else 0.0)
	(rig.materials["glow"] as ShaderMaterial).set_shader_parameter("emitter", glow)
	_glow_light.global_position = tip
	if _hum:
		_hum.global_position = tip
	_glow_light.light_energy = charge * 3.0 + (4.0 if firing else 0.0)
	_glow_light.omni_range = 8.0 + charge * 10.0
	if _hum:
		if charge > 0.01 and not firing:
			if not _hum.playing:
				_hum.play()
			_hum.pitch_scale = 0.45 + charge * 1.2
			_hum.volume_db = lerpf(volume_db - 24.0, volume_db + 2.0, charge)
		elif _hum.playing:
			_hum.stop()
	ray_hit = Vector3.INF
	if firing and arm_target.is_finite():
		var way := (arm_target - tip).normalized()
		var reach := tip.distance_to(arm_target) + 40.0
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(tip, tip + way * reach, ray_mask, _skip))
		var end := tip + way * reach
		var normal := Vector3.UP
		if not hit.is_empty():
			end = hit["position"]
			normal = hit["normal"]
			ray_hit = end
		var length := tip.distance_to(end)
		var width := 0.55 + 0.08 * sin(_time * 53.0)
		var up := Vector3.UP if absf(way.y) < 0.98 else Vector3.FORWARD
		_ray.global_transform = Transform3D(Basis.looking_at(way, up).scaled_local(Vector3(width, width, length)), tip)
		_ray_material.set_shader_parameter("length", length)
		_ray.visible = true
		_burn_light.visible = ray_hit.is_finite()
		_burn_light.global_position = end + normal * 1.5
		_burn_light.light_energy = 5.0 + 1.5 * sin(_time * 41.0)
		if ray_hit.is_finite():
			_burn_at(ray_hit, normal)
		if _roar and not _roar.playing:
			_roar.play()
		if _roar:
			_roar.global_position = tip
		if _sizzle:
			_sizzle.global_position = end
			if not _sizzle.playing and ray_hit.is_finite():
				_sizzle.play()
	else:
		_ray.visible = false
		_burn_light.visible = false
		if _roar and _roar.playing:
			_roar.stop()
		if _sizzle and _sizzle.playing:
			_sizzle.stop()
		if not _burning.is_empty():
			_burning["ended"] = _time
			_burning = {}
		if _sparks:
			_sparks.emitting = false
		if _smoke:
			_smoke.emitting = false
	# The grasper's clank as it closes on something.
	if _clank and reach_target.is_finite() and grasper_tip().distance_to(reach_target) < 1.5 and not _clank.playing:
		_clank.global_position = grasper_tip()
		_clank.play()


## The ray is burning at `at`: sparks and smoke there, and the scorch goes on.
func _burn_at(at: Vector3, normal: Vector3) -> void:
	if _sparks:
		_sparks.global_position = at + normal * 0.3
		_sparks.emitting = true
	if _smoke:
		_smoke.global_position = at + normal * 0.5
		_smoke.emitting = true
	if _burning.is_empty():
		var mesh := MeshInstance3D.new()
		mesh.name = "Scorch"
		mesh.mesh = ImmediateMesh.new()
		mesh.top_level = true
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.extra_cull_margin = 60.0
		add_child(mesh)
		_burning = {"mesh": mesh, "points": PackedVector3Array(), "normals": PackedVector3Array(), "births": PackedFloat32Array(), "ended": INF}
		_trails.append(_burning)
		# (no more than a few at once)
		while _trails.size() > 4:
			var old: Dictionary = _trails.pop_front()
			(old["mesh"] as Node).queue_free()
	var points: PackedVector3Array = _burning["points"]
	if not points.is_empty() and points[points.size() - 1].distance_to(at) < 0.8:
		return
	var normals: PackedVector3Array = _burning["normals"]
	var births: PackedFloat32Array = _burning["births"]
	points.append(at)
	normals.append(normal)
	births.append(_time)
	# (packed arrays are copied out of a dictionary: put them back)
	_burning["points"] = points
	_burning["normals"] = normals
	_burning["births"] = births
	_draw_trail(_burning)
	if _steam:
		_steam.emission_points = points
		_steam.emitting = true


## Lays a trail's scorch along its points: a strip 3 m wide over whatever it burned.
func _draw_trail(trail: Dictionary) -> void:
	var points: PackedVector3Array = trail["points"]
	var normals: PackedVector3Array = trail["normals"]
	var births: PackedFloat32Array = trail["births"]
	var mesh: ImmediateMesh = (trail["mesh"] as MeshInstance3D).mesh
	mesh.clear_surfaces()
	if points.size() < 2:
		return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _scorch_material)
	var travelled := 0.0
	var corners: Array = []
	for i in points.size():
		var along := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)])
		var side := normals[i].cross(along).normalized() * 2.2
		var lift := normals[i] * 0.07
		if i > 0:
			travelled += points[i].distance_to(points[i - 1])
		corners.append([points[i] - side + lift, points[i] + side + lift, travelled, births[i], normals[i]])
	for i in corners.size() - 1:
		var a: Array = corners[i]
		var b: Array = corners[i + 1]
		for c: Array in [[a, 0, 0.0], [a, 1, 1.0], [b, 1, 1.0], [a, 0, 0.0], [b, 1, 1.0], [b, 0, 0.0]]:
			var corner: Array = c[0]
			mesh.surface_set_normal(corner[4])
			mesh.surface_set_uv(Vector2(c[2], corner[2] * 0.25))
			mesh.surface_set_uv2(Vector2(corner[3], 0.0))
			mesh.surface_add_vertex(corner[c[1]])
	mesh.surface_end()


## The scorches cool and fade, and the steam off them stops.
func _burns(_delta: float) -> void:
	_scorch_material.set_shader_parameter("now", _time)
	var i := 0
	while i < _trails.size():
		var trail := _trails[i]
		if _time - float(trail["ended"]) > 32.0:
			(trail["mesh"] as Node).queue_free()
			_trails.remove_at(i)
			continue
		i += 1
	if _steam and _steam.emitting:
		var last: Dictionary = _trails.back() if not _trails.is_empty() else {}
		if last.is_empty() or (float(last["ended"]) < INF and _time - float(last["ended"]) > 12.0):
			_steam.emitting = false


# --- Shaking the ground ---

func _shake_camera(delta: float) -> void:
	if _shake <= 0.0005:
		if _shaking and is_instance_valid(_shaking):
			_shaking.h_offset = 0.0
			_shaking.v_offset = 0.0
		_shaking = null
		_shake = 0.0
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	_shaking = camera
	camera.h_offset = sin(_time * 61.0) * cos(_time * 23.0) * _shake * 0.6
	camera.v_offset = sin(_time * 47.0 + 1.3) * _shake
	_shake *= exp(-3.2 * delta)


# --- Effects and sounds ---

func _make_effects() -> void:
	_dust = _particles(60, Color(0.42, 0.4, 0.37, 0.55), 2.8, 3.0)
	_dust.one_shot = true
	_dust.explosiveness = 0.9
	_dust.direction = Vector3.UP
	_dust.spread = 85.0
	_dust.initial_velocity_min = 3.0
	_dust.initial_velocity_max = 9.0
	_dust.gravity = Vector3(0.0, -2.0, 0.0)
	_dust.damping_min = 2.0
	_dust.damping_max = 4.0
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_dust.emission_ring_axis = Vector3.UP
	_dust.emission_ring_radius = 2.5
	_dust.emission_ring_inner_radius = 1.0
	_dust.emission_ring_height = 0.2
	_sparks = _particles(70, Color(1.0, 0.7, 0.35, 1.0), 0.35, 0.8)
	_sparks.direction = Vector3.UP
	_sparks.spread = 70.0
	_sparks.initial_velocity_min = 6.0
	_sparks.initial_velocity_max = 15.0
	_sparks.gravity = Vector3(0.0, -18.0, 0.0)
	(_sparks.material_override as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_smoke = _particles(24, Color(0.88, 0.88, 0.9, 0.22), 4.0, 3.0)
	_smoke.direction = Vector3.UP
	_smoke.spread = 35.0
	_smoke.initial_velocity_min = 4.0
	_smoke.initial_velocity_max = 8.0
	_smoke.damping_min = 1.0
	_smoke.damping_max = 2.0
	_smoke.gravity = Vector3(0.0, 1.0, 0.0)
	_steam = _particles(90, Color(0.86, 0.88, 0.9, 0.28), 2.6, 3.6)
	_steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	_steam.emission_points = PackedVector3Array([Vector3.ZERO])
	_steam.direction = Vector3.UP
	_steam.spread = 15.0
	_steam.initial_velocity_min = 0.8
	_steam.initial_velocity_max = 2.0
	_steam.gravity = Vector3(0.0, 0.6, 0.0)
	_steam.position = Vector3.ZERO


func _particles(amount: int, colour: Color, size: float, life: float) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.amount = amount
	emitter.lifetime = life
	emitter.emitting = false
	emitter.top_level = true
	emitter.local_coords = false
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	emitter.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _soft_dot()
	material.disable_receive_shadows = true
	emitter.material_override = material
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fade := Gradient.new()
	fade.set_color(0, colour)
	fade.set_color(1, Color(colour.r, colour.g, colour.b, 0.0))
	emitter.color_ramp = fade
	emitter.scale_amount_min = 0.6
	emitter.scale_amount_max = 1.4
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 1.4))
	emitter.scale_amount_curve = grow
	add_child(emitter)
	return emitter


static var _dot: ImageTexture


static func _soft_dot() -> ImageTexture:
	if _dot:
		return _dot
	var size := 32
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x - size * 0.5 + 0.5, y - size * 0.5 + 0.5).length() / (size * 0.5)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(1.0 - d, 0.0, 1.0) ** 1.6))
	_dot = ImageTexture.create_from_image(image)
	return _dot


func _make_sounds() -> void:
	_voice = _player(80.0, 1)
	_voice.volume_db = volume_db + 6.0
	_stomp = _player(40.0, 3)
	_stomp.stream = TripodSound.footfall()
	_hiss = _player(18.0, 1)
	_hiss.stream = TripodSound.hiss()
	_hiss.volume_db = volume_db - 4.0
	_hum = _player(24.0, 1)
	_hum.stream = TripodSound.hum()
	_roar = _player(40.0, 1)
	_roar.stream = TripodSound.roar()
	_sizzle = _player(20.0, 1)
	_sizzle.stream = TripodSound.roar()
	_sizzle.pitch_scale = 1.7
	_sizzle.volume_db = volume_db - 2.0
	_clank = _player(16.0, 1)
	_clank.stream = TripodSound.clank()
	# (the horn is long in the making: made now, not the moment it is first sounded)
	TripodSound.horn.call_deferred()


func _player(unit: float, polyphony: int) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.unit_size = unit
	player.max_distance = sound_range
	player.max_polyphony = polyphony
	player.volume_db = volume_db
	player.attenuation_filter_cutoff_hz = 6000.0
	player.top_level = true
	add_child(player)
	return player

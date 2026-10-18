class_name Pterodactyl
extends Node3D
## A pterodactyl (a great Pteranodon-like pterosaur): how it looks, moves and
## sounds, and nothing of what it thinks. Whatever drives it (a game's enemy
## script, the example) moves this node and says what it is doing; it poses
## itself from that.
##
## WHAT IT IS. About 6.8 m across the wings and as tall as a man on the
## ground, built as the fossils say: a short deep body, a long neck, and a head
## longer than the body, a straight toothless beak and a blade of a crest swept
## back over the neck. The wing is a hand: a short stout upper arm, the
## forearm, a long metacarpal, and then the hugely long fourth finger in four
## phalanges out to the wingtip; at its root three small clawed fingers, and at
## the wrist the pteroid, holding up the skin in front of the arm. The main
## membrane runs from the wingtip back to the ankle, along the side of the body
## and down the leg. Furred with pycnofibres. Modelled in Blender
## (tools/build_pterodactyl.py, models/pterodactyl.glb) in the glide, at scale
## 1 (metres); posed here, bone by bone, every frame.
##
## WHERE IT IS. Its origin is its middle (the body). On the ground, put it
## `stand_height()` above the ground (times its scale): it sets its hands and
## feet on it.
##
## WHAT IT DOES. Say so each frame; each blends in and out by itself:
## - `grounded`: on all fours, as pterosaurs walked: the body pitched up, the
##   arms its front legs, standing on the three little fingers with the wing
##   finger folded up and back along the arm, the membrane furled between it and
##   the body; the hind feet flat. Move it and it walks (each hand and foot
##   steps when it is left behind, never two on one side at once), and turns
##   on the spot.
## - `launch()`: the quadrupedal launch, after Habib's work on how big
##   pterosaurs took off: it crouches, the hind legs kick, and it vaults into
##   the air on its arms, the wing finger snapping open at the top for the
##   first downstroke. `launch_lift(t)` says how far up and forward to move it
##   as it does (for whatever drives it).
## - flying: it flaps as pterosaurs are thought to have, from their wing bones
##   and the flight of large soaring birds and bats. Downstroke: the wing fully
##   spread and swept a little forward, the leading edge pressed down, the
##   outer finger bending up at the tip under the load. Upstroke: elbow and
##   wrist flex a little and the wing finger sweeps back at its knuckle, so the
##   wing is shorter and slack as it comes up and back, the tip trailing, then
##   flicking out straight at the top. Big and slow: about a beat a second.
##   `effort` (0..1): 0 the glide (wings held out, a little raised, the tips
##   trembling, the legs out to the sides holding the trailing edge), 1 beating
##   hard. `brake` (0..1) flares the wings forward and tips the body up (to
##   land, or pull up). `tuck` (0..1) folds the wings back, wrists out, the
##   finger swept back along the body, an arrow: a dive. `talons` (0..1) swings
##   the legs down and forward, the toes open, to snatch; `grip` closes them.
## - `croak()`: its harsh grating call, beak gaping, neck up; `croaked` at its top.
##   `rush()`: the roar of the wind over it as it dives.
## - `aim` (world, INF for none): what it looks at. It pitches and banks with
##   how it is moved (its climb and turn, measured from frame to frame).
## - `show_shadow(ground_point)`: its shadow drawn on the ground (one quad,
##   the shape of it from below), for a game whose light throws none so far down.
##
## `foot_points()` says where its feet are (world), for a game's catching, and
## `carry_point()` where something held in them hangs.
##
## Cost: one skinned mesh (one draw, and its shadow); about 3,000 triangles at
## a distance (the low model) and 15,000 near. Hide it, or set process_mode
## disabled, when it is far from everyone.

## The top of each wingbeat (the downstroke begins).
signal beat
## The call goes out (at the top of `croak()`).
signal croaked

const MODEL := "res://creatures/pterodactyl/models/pterodactyl.glb"
## How far up from the ground its origin (its middle) is, standing, at scale 1.
const STAND_HEIGHT := 0.86
## Across the wings, spread, at scale 1.
const SPAN := 6.8
const CALL_TIME := 1.3
const LAUNCH_TIME := 1.25
## The body's pitch standing (nose up), radians.
const STANCE_PITCH := -0.6
## Where its hands and feet stand from its middle, on the ground (left side; the
## right is the mirror), at scale 1: out, along (+ forward).
const HAND_HOME := Vector2(0.42, 0.3)
const FOOT_HOME := Vector2(0.27, -0.42)
const STRIDE := 0.5
const STEP_TIME := 0.32
## The wingbeat: 0 the top, the downstroke to DOWN.
const DOWN := 0.55

## Every pterodactyl uses the low model.
static var low_poly := false

## Make its sounds (a call, wingbeats, the rush of a dive), from where it is.
@export var sound := true
@export var volume_db := 6.0
## How far off its sounds are heard.
@export var sound_range := 110.0
## Beyond this from the camera the low model is drawn.
@export var lod_distance := 30.0
## Each its own small differences (tone, timing).
@export var seed_value := 0

## On the ground (false: flying).
var grounded := true:
	set(value):
		if value and not grounded:
			_planted.clear()
		grounded = value
var effort := 0.4
var brake := 0.0
var tuck := 0.0
var talons := 0.0
var grip := 0.0
## What it looks at (world). INF: straight ahead.
var aim := Vector3.INF
## How fast it is going: measured from how it is moved, or set it with `measure_velocity` off.
var velocity := Vector3.ZERO
var measure_velocity := true
## For pictures and tests: it does not pose itself (see `hold`).
var frozen := false

var _model: Node3D
var _body: Node3D
var _skeleton: Skeleton3D
var _meshes: Array[MeshInstance3D] = []
var _bone := {}
var _parent: PackedInt32Array = []
var _order: PackedInt32Array = []
var _rest_local: Array[Basis] = []
var _rest_global: Array[Basis] = []
var _rest_global_inv: Array[Basis] = []
var _rest_origin: Array[Vector3] = []
var _rest_global_xf: Array[Transform3D] = []
## Each bone's rest direction (to its child, or on as its parent goes).
var _rest_dir: Array[Vector3] = []
var _toe_tip := {}

var _w := {"ground": 1.0, "effort": 0.4, "brake": 0.0, "tuck": 0.0, "talons": 0.0, "grip": 0.0}
var _phase := 0.0
var _t := 0.0
var _was := Vector3.INF
var _yaw_was := 0.0
var _turn := 0.0
var _climb := 0.0
var _call := INF
var _called := true
var _launch := INF
var _gaze := Vector3(0.0, 0.0, 1.0)
var _rng := RandomNumberGenerator.new()
## Where each hand and foot stands (world), and its step if it is stepping: limb -> {at, from, to, t}.
var _planted := {}
var _shadow: MeshInstance3D
var _voice: AudioStreamPlayer3D
var _wings: AudioStreamPlayer3D
var _wind: AudioStreamPlayer3D
static var _call_wav: AudioStreamWAV
static var _beat_wav: AudioStreamWAV
static var _rush_wav: AudioStreamWAV


func _ready() -> void:
	_rng.seed = seed_value
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_model = (load(MODEL) as PackedScene).instantiate()
	_body.add_child(_model)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = PterodactylLook.material()
		mesh.set_instance_shader_parameter(&"tone", _rng.randf_range(0.9, 1.1))
		# (posed far from its rest: never culled by its rest box)
		mesh.custom_aabb = AABB(Vector3(-3.8, -2.5, -3.8), Vector3(7.6, 5.0, 7.6))
		_meshes.append(mesh)
	_set_lod()
	var count := _skeleton.get_bone_count()
	_parent.resize(count)
	for i in count:
		_bone[_skeleton.get_bone_name(i)] = i
		_parent[i] = _skeleton.get_bone_parent(i)
		_rest_local.append(_skeleton.get_bone_rest(i).basis)
		var g := _skeleton.get_bone_global_rest(i)
		_rest_global.append(g.basis.orthonormalized())
		_rest_global_inv.append(g.basis.orthonormalized().inverse())
		_rest_origin.append(g.origin)
		_rest_global_xf.append(g)
	# (parents first)
	var queue: Array[int] = []
	for i in count:
		if _parent[i] < 0:
			queue.append(i)
	while not queue.is_empty():
		var i: int = queue.pop_front()
		_order.append(i)
		for kid in _skeleton.get_bone_children(i):
			queue.append(kid)
	for i in count:
		var kids := _skeleton.get_bone_children(i)
		var dir := Vector3.ZERO
		# (the child it runs to: for the hand, the wing finger)
		var bone_name := _skeleton.get_bone_name(i)
		var to := -1
		for kid in kids:
			var kid_name := _skeleton.get_bone_name(kid)
			if kid_name.begins_with("wing1") or kid_name.begins_with("forearm") or kid_name.begins_with("hand") or kid_name.begins_with("shin") or kid_name.begins_with("foot") or kid_name.begins_with("toes") or kid_name.begins_with("wing") or kid_name.begins_with("neck") or kid_name == "head" or kid_name.begins_with("humerus"):
				to = kid
				break
		if to >= 0:
			dir = _rest_origin[to] - _rest_origin[i]
		elif _parent[i] >= 0:
			dir = _rest_origin[i] - _rest_origin[_parent[i]]
		if bone_name.begins_with("digits"):
			dir = Vector3(0.0, -0.05, 1.0)
		elif bone_name.begins_with("pteroid"):
			dir = Vector3(-0.17, 0.005, 0.15) * Vector3(1.0 if bone_name.ends_with("_l") else -1.0, 1.0, 1.0)
		elif bone_name == "head":
			dir = Vector3(0.0, -0.01, 0.26)
		elif bone_name == "jaw":
			dir = Vector3(0.0, -0.035, 0.9)
		_rest_dir.append(dir.normalized() if dir.length() > 0.0001 else Vector3.FORWARD)
	for side: String in ["_l", "_r"]:
		var i: int = _bone["toes" + side]
		_toe_tip[i] = _rest_origin[i] + _rest_dir[i] * 0.09 + Vector3.DOWN * 0.02
	if sound:
		_voice = _player(call_sound(), volume_db)
		_wings = _player(beat_sound(), volume_db - 4.0)
		_wings.max_distance = sound_range * 0.5
		_wind = _player(rush_sound(), volume_db - 2.0)
	settle()


func _player(stream: AudioStream, db: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = db
	player.unit_size = 12.0
	player.max_distance = sound_range
	add_child(player)
	return player


func _set_lod() -> void:
	for mesh in _meshes:
		var lo := String(mesh.name).ends_with("_lo")
		if low_poly:
			mesh.visible = lo
			mesh.visibility_range_begin = 0.0
			mesh.visibility_range_end = 0.0
		else:
			mesh.visible = true
			mesh.visibility_range_begin = lod_distance if lo else 0.0
			mesh.visibility_range_end = 0.0 if lo else lod_distance


## How far up from the ground its origin is when standing (world units at its scale).
func stand_height() -> float:
	return STAND_HEIGHT * global_basis.get_scale().y


## How far up and forward (metres at scale 1) to have moved it `t` seconds
## into `launch()`: nothing while it crouches, then the vault, then climbing away.
static func launch_lift(t: float) -> Vector2:
	var up := 1.5 * smoothstep(0.36, 0.78, t) + 2.4 * maxf(t - 0.78, 0.0)
	var forward := 1.2 * smoothstep(0.4, 0.8, t) + 5.0 * maxf(t - 0.7, 0.0)
	return Vector2(up, forward)


## Stands it still in what it is told now, with nothing going on.
func settle() -> void:
	_was = global_position if is_inside_tree() else Vector3.INF
	_yaw_was = global_rotation.y if is_inside_tree() else 0.0
	_turn = 0.0
	_climb = 0.0
	_w["ground"] = 1.0 if grounded else 0.0
	_w["effort"] = effort
	_w["brake"] = brake
	_w["tuck"] = tuck
	_w["talons"] = talons
	_w["grip"] = grip
	_call = INF
	_launch = INF
	_planted.clear()
	if _skeleton:
		_pose(0.0)


## For pictures and tests: poses it exactly (with `frozen` set, it then keeps
## still). `state` holds any of ground, effort, brake, tuck, talons, grip
## (0..1) and velocity; `phase` is where in the wingbeat (0 the top, the
## downstroke to 0.55); `call_t` how far through a call, `launch_t` through a
## launch, seconds (INF: none).
func hold(state: Dictionary, phase := 0.0, call_t := INF, launch_t := INF) -> void:
	for key: String in state:
		if _w.has(key):
			_w[key] = float(state[key])
	_phase = phase
	_call = call_t
	_launch = launch_t
	velocity = state.get("velocity", Vector3.ZERO)
	_planted.clear()
	if aim.is_finite():
		_gaze = (global_transform.affine_inverse() * aim).normalized()
	_pose(0.0)


## Takes off: the crouch, the kick and the vault (LAUNCH_TIME); it is flying after.
func launch() -> void:
	grounded = false
	_launch = 0.0


func launching() -> bool:
	return _launch < LAUNCH_TIME


## Its harsh call: beak gaping, neck stretched up; `croaked` at the top.
func croak() -> void:
	_call = 0.0
	_called = false
	if _voice:
		_voice.pitch_scale = _rng.randf_range(0.92, 1.06)
		_voice.play()


func croaking() -> bool:
	return _call < CALL_TIME


## The roar of the wind as it dives.
func rush() -> void:
	if _wind:
		_wind.play()


## Its shadow on the ground at `point` (INF: none), `strength` 0..1 how dark,
## `blur` 0..1 how soft (the higher it is, the softer).
func show_shadow(point: Vector3, strength := 1.0, blur := 0.0) -> void:
	if _shadow == null:
		_shadow = MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(1.0, 1.0)
		quad.orientation = PlaneMesh.FACE_Y
		_shadow.mesh = quad
		_shadow.material_override = PterodactylLook.shadow_material()
		_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shadow.top_level = true
		add_child(_shadow)
	_shadow.visible = point.is_finite() and strength > 0.01
	if _shadow.visible:
		var size := SPAN * global_basis.get_scale().x * (1.0 + blur * 0.3)
		var facing := Basis(Vector3.UP, global_rotation.y + PI)
		_shadow.global_transform = Transform3D(facing.scaled(Vector3(size, 1.0, size * 0.62)), point + Vector3.UP * 0.05)
		_shadow.set_instance_shader_parameter(&"strength", clampf(strength, 0.0, 1.0))
		_shadow.set_instance_shader_parameter(&"spread", 1.0 - _w["tuck"] * 0.8)
		_shadow.set_instance_shader_parameter(&"blur", blur)


## Where its feet are (world): the tips of its toes.
func foot_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	for i: int in _toe_tip:
		out.append(_skeleton.global_transform * (_skeleton.get_bone_global_pose(i) * (_rest_global_xf[i].affine_inverse() * _toe_tip[i])))
	return out


## Where something held in its feet hangs from (world).
func carry_point() -> Vector3:
	var p := foot_points()
	return (p[0] + p[1]) * 0.5 if p.size() == 2 else global_position


## Where its head is (world).
func head_point() -> Vector3:
	var g := _skeleton.get_bone_global_pose(_bone["head"])
	return _skeleton.global_transform * g.origin


func _process(delta: float) -> void:
	if delta <= 0.0 or frozen:
		return
	_t += delta
	var at := global_position
	if not _was.is_finite():
		_was = at
		_yaw_was = global_rotation.y
	if measure_velocity:
		velocity = velocity.lerp((at - _was) / delta, 1.0 - exp(-10.0 * delta))
	var yaw := global_rotation.y
	_turn = lerpf(_turn, wrapf(yaw - _yaw_was, -PI, PI) / delta, 1.0 - exp(-4.0 * delta))
	_was = at
	_yaw_was = yaw
	var flat := Vector2(velocity.x, velocity.z).length()
	_climb = lerpf(_climb, atan2(velocity.y, maxf(flat, 1.0)) if velocity.length() > 1.0 else 0.0, 1.0 - exp(-4.0 * delta))
	var rate := 1.0 - exp(-4.0 * delta)
	if _launch < INF:
		_launch += delta
		_w["ground"] = 1.0 - smoothstep(0.45, 0.8, _launch)
		if _launch >= LAUNCH_TIME + 0.5:
			_launch = INF
	else:
		_w["ground"] = move_toward(_w["ground"], 1.0 if grounded else 0.0, delta * 2.2)
	_w["effort"] = lerpf(_w["effort"], effort, rate)
	_w["brake"] = lerpf(_w["brake"], brake, rate)
	_w["tuck"] = lerpf(_w["tuck"], tuck, 1.0 - exp(-3.5 * delta))
	_w["talons"] = lerpf(_w["talons"], talons, 1.0 - exp(-6.0 * delta))
	_w["grip"] = lerpf(_w["grip"], grip, 1.0 - exp(-10.0 * delta))
	# The wingbeat: about a beat a second, a little quicker working hard.
	var flying: float = (1.0 - _w["ground"]) * (1.0 - _w["tuck"])
	var hz: float = lerpf(0.85, 1.35, _w["effort"]) + _w["brake"] * 0.35
	if _launch < LAUNCH_TIME:
		# (the launch: the wings opened up to the top, then the first downstroke)
		_phase = clampf((_launch - 0.62) / 0.42, 0.0, 1.0) * DOWN
	elif flying > 0.05 and (_w["effort"] > 0.05 or _w["brake"] > 0.1):
		var before := _phase
		_phase = fposmod(_phase + hz * delta, 1.0)
		if _phase < before:
			beat.emit()
			if _wings and _w["effort"] + _w["brake"] > 0.3:
				_wings.pitch_scale = _rng.randf_range(0.9, 1.08)
				_wings.play()
	elif _phase > 0.0:
		# (gliding: the wings come to rest held out)
		_phase = move_toward(_phase, 0.0 if _phase < 0.5 else 1.0, delta * 0.6)
		if _phase >= 1.0:
			_phase = 0.0
	if _call < INF:
		_call += delta
		if not _called and _call > 0.3:
			_called = true
			croaked.emit()
		if _call > CALL_TIME + 1.0:
			_call = INF
	# Where it looks.
	var want := Vector3(0.0, -0.08, 1.0)
	if aim.is_finite():
		var local := global_transform.affine_inverse() * aim - Vector3(0.0, 0.3, 0.6)
		if local.length() > 0.5:
			want = local.normalized()
			want.z = maxf(want.z, 0.2)
	_gaze = _gaze.slerp(want.normalized(), 1.0 - exp(-3.0 * delta)).normalized()
	if _w["ground"] > 0.01:
		_step_feet(delta)
	_pose(delta)


# --- Walking ---

## Where a limb's hand or foot belongs now (world): under it, a little ahead as it moves.
func _home(limb: String) -> Vector3:
	var side := 1.0 if limb.ends_with("_l") else -1.0
	var spot: Vector2 = HAND_HOME if limb.begins_with("hand") else FOOT_HOME
	var s := global_basis.get_scale().x
	var flat := Basis(Vector3.UP, global_rotation.y)
	var at := global_position + flat * (Vector3(spot.x * side, 0.0, spot.y) * s)
	at.y = global_position.y - stand_height()
	if _launch < INF:
		# (taking off, they stay where they were)
		at.y -= launch_lift(_launch).x * s
	var lead := Vector3(velocity.x, 0.0, velocity.z) * 0.22
	return at + lead.limit_length(STRIDE * s * 0.6)


func _step_feet(delta: float) -> void:
	var s := global_basis.get_scale().x
	var limbs := ["hand_l", "foot_r", "hand_r", "foot_l"]
	if _planted.is_empty() or _launch < INF:
		if _planted.is_empty():
			for limb: String in limbs:
				_planted[limb] = {"at": _home(limb), "t": -1.0, "from": Vector3.ZERO, "to": Vector3.ZERO}
		return
	var stepping := 0
	var sides := {}
	for limb: String in limbs:
		var p: Dictionary = _planted[limb]
		if p["t"] >= 0.0:
			p["t"] += delta / STEP_TIME
			var t := minf(p["t"], 1.0)
			p["at"] = (p["from"] as Vector3).lerp(p["to"], smoothstep(0.0, 1.0, t)) + Vector3.UP * sin(PI * t) * 0.14 * s
			if p["t"] >= 1.0:
				p["at"] = p["to"]
				p["t"] = -1.0
			else:
				stepping += 1
				sides[limb.right(2)] = true
	for limb: String in limbs:
		var p: Dictionary = _planted[limb]
		if p["t"] >= 0.0 or stepping >= 2 or sides.has(limb.right(2)):
			continue
		var home := _home(limb)
		if (p["at"] as Vector3).distance_to(home) > STRIDE * s * 0.5:
			p["from"] = p["at"]
			p["to"] = home
			p["t"] = 0.0
			stepping += 1
			sides[limb.right(2)] = true


# --- Poses ---

## One wing's pose in flight, as angles (radians), in the body's frame with the
## left wing out along +X, its top +Y, forward +Z (the right is the mirror).
class Wing:
	## The upper arm: up (+) and down, forward (+) and back, leading edge down (+).
	var elev := 0.0
	var sweep := 0.0
	var pitch := 0.0
	## The elbow (the forearm folding forward), the wrist (the hand folding back).
	var elbow := 0.0
	var wrist := 0.0
	## The wing finger swept back at its knuckle (+), and bent up along its length (+), most at the tip.
	var knuckle := 0.0
	var flex := 0.0
	## The pteroid turned in (+) or folded back along the forearm (-).
	var pteroid := 0.0
	var shrug := 0.0

	func _init(e := 0.0, s := 0.0, p := 0.0, el := 0.0, w := 0.0, k := 0.0, f := 0.0, pt := 0.0, sh := 0.0) -> void:
		elev = e
		sweep = s
		pitch = p
		elbow = el
		wrist = w
		knuckle = k
		flex = f
		pteroid = pt
		shrug = sh

	func mixed(other: Wing, t: float) -> Wing:
		if t <= 0.0:
			return self
		if t >= 1.0:
			return other
		return Wing.new(lerpf(elev, other.elev, t), lerpf(sweep, other.sweep, t), lerpf(pitch, other.pitch, t), lerpf(elbow, other.elbow, t),
			lerpf(wrist, other.wrist, t), lerpf(knuckle, other.knuckle, t), lerpf(flex, other.flex, t), lerpf(pteroid, other.pteroid, t), lerpf(shrug, other.shrug, t))


static func _d(degrees: float) -> float:
	return deg_to_rad(degrees)


func _flap(phase: float, strength: float, braking: float) -> Wing:
	var top := lerpf(32.0, 52.0, strength) + braking * 6.0
	var bottom := lerpf(-22.0, -40.0, strength)
	var w := Wing.new()
	if phase < DOWN:
		var u := phase / DOWN
		var e := 0.5 - 0.5 * cos(PI * u)
		var mid := sin(PI * u)
		w.elev = _d(lerpf(top, bottom, e))
		w.sweep = _d(4.0 + 8.0 * mid + braking * 20.0)
		w.pitch = _d(3.0 + 10.0 * mid * (0.5 + 0.5 * strength) - braking * 20.0)
		w.elbow = _d(4.0)
		w.wrist = _d(2.0)
		w.knuckle = _d(4.0 - 4.0 * mid)
		# (the outer finger bent up by the load, most in the middle of the stroke)
		w.flex = _d(2.0 + (8.0 + 10.0 * strength) * mid)
		w.pteroid = _d(6.0 * mid)
	else:
		var u := (phase - DOWN) / (1.0 - DOWN)
		var e := 0.5 - 0.5 * cos(PI * u)
		var mid := sin(PI * u)
		w.elev = _d(lerpf(bottom, top, e))
		w.sweep = _d(lerpf(4.0, -12.0, mid) + braking * 12.0)
		w.pitch = _d(-16.0 * mid - braking * 10.0)
		# Shortened coming up: elbow and wrist flexed, the finger swept back at the knuckle, then flicked out straight at the top.
		var fold := mid * (1.0 - smoothstep(0.75, 1.0, u))
		w.elbow = _d(4.0 + 26.0 * fold * (0.6 + 0.4 * strength))
		w.wrist = _d(2.0 + 18.0 * fold * (0.6 + 0.4 * strength))
		w.knuckle = _d(4.0 + 32.0 * fold * (0.6 + 0.4 * strength))
		# (the tip trailing down behind as it comes up, then flicking up at the top)
		w.flex = _d(-12.0 * mid + 10.0 * smoothstep(0.7, 1.0, u))
		w.pteroid = _d(-10.0 * fold)
	w.shrug = _d(3.0 * sin(TAU * phase))
	return w


func _glide() -> Wing:
	var tremble := sin(_t * 17.0 + seed_value) * 0.5 + sin(_t * 26.0) * 0.5
	return Wing.new(_d(5.0), _d(1.0), _d(2.0), _d(3.0), _d(2.0), _d(7.0), _d(5.0 + tremble * 1.5), _d(4.0))


func _tucked() -> Wing:
	return Wing.new(_d(6.0), _d(-25.0), _d(4.0), _d(30.0), _d(75.0), _d(15.0), _d(-2.0), _d(-30.0), _d(4.0))


func _flared() -> Wing:
	return Wing.new(_d(28.0), _d(24.0), _d(-30.0), _d(10.0), _d(6.0), _d(-2.0), _d(16.0), _d(14.0), _d(6.0))


## Poses every bone: the body's lean, then each part, then onto the skeleton.
func _pose(_delta: float) -> void:
	var ground: float = _w["ground"]
	var call_w := 0.0
	var shudder := 0.0
	if _call < INF:
		call_w = smoothstep(0.0, 0.25, _call) * (1.0 - smoothstep(CALL_TIME - 0.3, CALL_TIME + 0.15, _call))
		shudder = sin(_call * 41.0) * 0.5 + sin(_call * 67.0) * 0.5
	var crouch := 0.0
	if _launch < INF:
		crouch = smoothstep(0.0, 0.3, _launch) * (1.0 - smoothstep(0.34, 0.44, _launch))

	# --- The body's lean ---
	var bank := clampf(-_turn * 0.22, -0.7, 0.7) * (1.0 - ground)
	var fly_pitch: float = -_climb * 0.8 - _w["brake"] * 0.55 + _w["talons"] * -0.2
	# (diving, nose down along its path)
	fly_pitch = lerpf(fly_pitch, maxf(-_climb, 0.0) * 1.0, _w["tuck"] * 0.6)
	var stance_pitch := STANCE_PITCH + crouch * 0.25 - call_w * 0.1
	if _launch < INF:
		# (the vault throws the front up, then it levels out)
		stance_pitch -= smoothstep(0.34, 0.5, _launch) * (1.0 - smoothstep(0.55, 0.85, _launch)) * 0.35
	var pitch := lerpf(fly_pitch, stance_pitch, ground)
	# (the body bobs against the wingbeat)
	var bob: float = -sin(TAU * (_phase - 0.1)) * 0.03 * (1.0 - ground) * clampf(_w["effort"] * 2.0, 0.0, 1.0)
	_body.basis = Basis(Vector3.FORWARD, bank + shudder * 0.02 * call_w) * Basis(Vector3.RIGHT, pitch)
	_body.position = Vector3(0.0, bob - crouch * 0.32, 0.0)
	var to_skeleton := _skeleton.global_transform.affine_inverse()
	var up_m := (to_skeleton.basis * Vector3.UP).normalized()

	# --- The spine, neck and head (shared by both sides) ---
	var count := _rest_origin.size()
	var D: Array[Basis] = []
	D.resize(count)
	for i in count:
		D[i] = Basis.IDENTITY
	var hips: int = _bone["hips"]
	var spine: int = _bone["spine"]
	var chest: int = _bone["chest"]
	D[hips] = Basis.IDENTITY
	D[spine] = Basis(Vector3.RIGHT, bob * 1.5)
	D[chest] = D[spine]
	# The neck: out in front in flight; raised in an S on the ground; stretched up to call.
	var neck_up: float = lerpf(-0.04, -0.5, ground) - call_w * 0.3 + _w["tuck"] * 0.05 + crouch * 0.4
	var neck_fwd := lerpf(0.02, 0.62, ground) - call_w * 0.1 - crouch * 0.2
	D[_bone["neck1"]] = D[chest] * Basis(Vector3.RIGHT, neck_up)
	D[_bone["neck2"]] = D[_bone["neck1"]] * Basis(Vector3.RIGHT, neck_fwd)
	# The head, after its gaze (in the model's frame), no further than it can turn from the neck.
	var neck2: int = _bone["neck2"]
	var head: int = _bone["head"]
	var gaze_m := (to_skeleton.basis * (global_basis.orthonormalized() * _gaze)).normalized()
	var neck_dir := D[neck2] * _rest_dir[neck2]
	var look := gaze_m
	if look.angle_to(neck_dir) > 1.0:
		look = neck_dir.slerp(look, 1.0 / look.angle_to(neck_dir)).normalized()
	# (calling, the beak is thrown up)
	look = (look + up_m * call_w * 0.5).normalized()
	# (the neck turns a little after it)
	D[neck2] = Basis(up_m, clampf(atan2(look.x, look.z), -0.8, 0.8) * 0.3) * D[neck2]
	D[head] = _aim(_rest_dir[head], Vector3.UP, look, D[neck2] * Vector3.UP)
	var jaw := call_w * (0.55 + 0.05 * shudder)
	D[_bone["jaw"]] = D[head] * Basis(Vector3.RIGHT, jaw)
	D[_bone["tail"]] = Basis(Vector3.RIGHT, -0.15 * ground + _w["tuck"] * 0.1)

	# --- The wings and legs ---
	var flight := _glide().mixed(_flap(_phase, _w["effort"], _w["brake"]), clampf(maxf(_w["effort"] * 3.0, _w["brake"] * 3.0), 0.0, 1.0))
	if _launch < LAUNCH_TIME:
		flight = _flap(_phase, 1.0, 0.0)
	flight = flight.mixed(_tucked(), _w["tuck"])
	flight = flight.mixed(_flared(), maxf(_w["brake"], _w["talons"] * 0.8) * (1.0 - _w["tuck"]))
	var mirror := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	for side: float in [1.0, -1.0]:
		var s := "_l" if side > 0.0 else "_r"
		var w := Wing.new(flight.elev + bank * 0.5 * side, flight.sweep, flight.pitch, flight.elbow, flight.wrist, flight.knuckle, flight.flex, flight.pteroid, flight.shrug)
		# Everything for this side is worked out as for the left, in a mirrored world, and mirrored back.
		var m := Basis.IDENTITY if side > 0.0 else mirror
		var chest_m := m * D[chest] * m
		var hips_m := m * D[hips] * m
		var fly := _wing_in_flight(w, chest_m, s)
		_legs_in_flight(fly, hips_m, s, side)
		var out := fly
		if ground > 0.001:
			var stand := _standing(chest_m, hips_m, s, side, m, to_skeleton, up_m, crouch)
			out = {}
			for name: String in fly:
				out[name] = (fly[name] as Basis).slerp(stand[name], ground) if stand.has(name) else fly[name]
		for name: String in out:
			D[_bone[name + s]] = m * (out[name] as Basis) * m

	# --- Onto the skeleton ---
	for i in _order:
		var p := _parent[i]
		var q := D[i] if p < 0 else D[p].inverse() * D[i]
		var local := _rest_local[i] * (_rest_global_inv[i] * q * _rest_global[i])
		_skeleton.set_bone_pose_rotation(i, local.get_rotation_quaternion())


## A rotation (in the model's frame) that turns a bone lying along `rest_dir`
## with `rest_up` as its top to lie along `dir`, its top as near `up` as it can.
static func _aim(rest_dir: Vector3, rest_up: Vector3, dir: Vector3, up: Vector3) -> Basis:
	return _frame(dir, up) * _frame(rest_dir, rest_up).transposed()


static func _frame(dir: Vector3, up: Vector3) -> Basis:
	var x := dir.normalized()
	var y := up - x * x.dot(up)
	if y.length_squared() < 0.000001:
		y = x.cross(Vector3.RIGHT if absf(x.x) < 0.9 else Vector3.BACK)
	y = y.normalized()
	return Basis(x, y, x.cross(y))


## The wing in flight, from its angles (the left wing's, in its own mirrored world): name -> rotation.
func _wing_in_flight(w: Wing, chest: Basis, _s: String) -> Dictionary:
	var out := {}
	var shoulder := chest * Basis(Vector3.BACK, w.shrug)
	var humerus := shoulder * Basis(Vector3.UP, -w.sweep) * Basis(Vector3.BACK, w.elev) * Basis(Vector3.RIGHT, w.pitch)
	var forearm := humerus * Basis(Vector3.UP, -w.elbow)
	var hand := forearm * Basis(Vector3.UP, w.wrist)
	var wing1 := hand * Basis(Vector3.UP, w.knuckle) * Basis(Vector3.BACK, w.flex * 0.15)
	var wing2 := wing1 * Basis(Vector3.UP, w.knuckle * 0.12) * Basis(Vector3.BACK, w.flex * 0.3)
	var wing3 := wing2 * Basis(Vector3.UP, w.knuckle * 0.12) * Basis(Vector3.BACK, w.flex * 0.45)
	var wing4 := wing3 * Basis(Vector3.UP, 0.06 + w.knuckle * 0.1) * Basis(Vector3.BACK, w.flex * 0.6)
	out["shoulder"] = shoulder
	out["humerus"] = humerus
	out["forearm"] = forearm
	out["pteroid"] = forearm * Basis(Vector3.UP, w.pteroid)
	out["hand"] = hand
	out["digits"] = hand * Basis(Vector3.RIGHT, 0.5)
	out["wing1"] = wing1
	out["wing2"] = wing2
	out["wing3"] = wing3
	out["wing4"] = wing4
	return out


## The legs in flight: out to the sides holding the trailing edge, swinging a
## little with the beat; thrown down and forward to snatch.
func _legs_in_flight(out: Dictionary, hips: Basis, _s: String, _side: float) -> void:
	var swing: float = sin(TAU * (_phase + 0.15)) * 0.08 * clampf(_w["effort"] * 2.0, 0.0, 1.0)
	var thigh := hips * Basis(Vector3.BACK, swing)
	var shin := thigh
	var foot := shin * Basis(Vector3.RIGHT, -0.3)
	var toes := foot * Basis(Vector3.RIGHT, -0.5)
	var grab: float = _w["talons"]
	if grab > 0.001:
		var down := Vector3(0.12, -0.92, 0.36)
		var t_thigh := _aim(_rest_dir[_bone["thigh_l"]], Vector3.UP, hips * Vector3(0.3, -0.75, 0.45), hips * Vector3.FORWARD)
		var t_shin := _aim(_rest_dir[_bone["shin_l"]], Vector3.UP, hips * down, hips * Vector3.FORWARD)
		var t_foot := _aim(_rest_dir[_bone["foot_l"]], Vector3.UP, hips * Vector3(0.05, -0.55, 0.8), hips * Vector3.UP)
		var closed: float = _w["grip"]
		var t_toes := t_foot * Basis(Vector3.RIGHT, lerpf(0.5, -1.1, closed))
		thigh = thigh.slerp(t_thigh, grab)
		shin = shin.slerp(t_shin, grab)
		foot = foot.slerp(t_foot, grab)
		toes = toes.slerp(t_toes, grab)
	out["thigh"] = thigh
	out["shin"] = shin
	out["foot"] = foot
	out["toes"] = toes


## Standing on all fours: the arm (humerus, forearm) reaching down to the
## wrist over the hand, the metacarpal upright, the little fingers flat on the
## ground pointing out and back, the wing finger folded up and back; the legs
## reaching down to the feet. Worked out in the skeleton's frame (mirrored for
## the right: `m`), to where each hand and foot stands (`_planted`).
func _standing(chest: Basis, hips: Basis, s: String, side: float, m: Basis, to_skeleton: Transform3D, up_m: Vector3, crouch: float) -> Dictionary:
	var out := {}
	var up := m * up_m
	var fwd_world := global_basis.orthonormalized() * Vector3.BACK
	var fwd := m * (to_skeleton.basis * fwd_world)
	fwd = (fwd - up * fwd.dot(up)).normalized()
	var outward := up.cross(fwd).normalized()
	# (the left is +X: `outward` must point that way in this mirrored world)
	if outward.x < 0.0:
		outward = -outward
	var hand_at := m * (to_skeleton * _contact("hand" + s))
	var foot_at := m * (to_skeleton * _contact("foot" + s))
	var L := func(name: String) -> int: return _bone[name + "_l"]
	# The arm. (The shoulder joint, from the chest.)
	var shoulder := chest * Basis(Vector3.BACK, 0.05 + crouch * 0.1)
	var shoulder_at := _rest_origin[L.call("shoulder")] + shoulder * (_rest_origin[L.call("humerus")] - _rest_origin[L.call("shoulder")])
	var metacarpal := (_rest_origin[L.call("wing1")] - _rest_origin[L.call("hand")]).length()
	var upper := (_rest_origin[L.call("forearm")] - _rest_origin[L.call("humerus")]).length()
	var lower := (_rest_origin[L.call("hand")] - _rest_origin[L.call("forearm")]).length()
	var knuckle := hand_at + up * 0.03
	var wrist := knuckle + (up * 0.97 - fwd * 0.1 - outward * 0.15).normalized() * metacarpal
	var pole := (outward * 0.55 - fwd * 0.75 + up * 0.35).normalized()
	var joints := _two_bone(shoulder_at, wrist, upper, lower, pole)
	var elbow: Vector3 = joints[0]
	wrist = joints[1]
	out["shoulder"] = shoulder
	out["humerus"] = _aim(_rest_dir[L.call("humerus")], Vector3.UP, elbow - shoulder_at, outward + up * 0.3)
	out["forearm"] = _aim(_rest_dir[L.call("forearm")], Vector3.UP, wrist - elbow, outward - fwd * 0.3)
	out["hand"] = _aim(_rest_dir[L.call("hand")], Vector3.UP, knuckle - wrist, outward)
	out["pteroid"] = (out["forearm"] as Basis) * Basis(Vector3.UP, _d(-40.0))
	# The little fingers flat on the ground, pointing out and back (as their prints do).
	out["digits"] = _aim(_rest_dir[L.call("digits")], Vector3.UP, outward * 0.65 - fwd * 0.55 - up * 0.12, up)
	# The wing finger folded up and back along the arm, a little out from it, its tip high behind.
	var folded := (up * 0.45 - fwd * 0.86 + outward * 0.14).normalized()
	var wing1 := _aim(_rest_dir[L.call("wing1")], Vector3.UP, folded, outward + fwd * 0.2)
	var wing2 := wing1 * Basis(Vector3.UP, 0.1) * Basis(Vector3.BACK, -0.05)
	var wing3 := wing2 * Basis(Vector3.UP, 0.12) * Basis(Vector3.BACK, -0.06)
	out["wing1"] = wing1
	out["wing2"] = wing2
	out["wing3"] = wing3
	out["wing4"] = wing3 * Basis(Vector3.UP, 0.12) * Basis(Vector3.BACK, -0.1)
	# The legs, down to the feet, knees forward and out; the feet flat, pointing forward.
	var hip_at := _rest_origin[L.call("thigh")]
	var thigh_len := (_rest_origin[L.call("shin")] - _rest_origin[L.call("thigh")]).length()
	var shin_len := (_rest_origin[L.call("foot")] - _rest_origin[L.call("shin")]).length()
	var ankle := foot_at + up * 0.05 - fwd * 0.05
	var legs := _two_bone(hip_at, ankle, thigh_len, shin_len, (fwd * 0.8 + outward * 0.5 + up * 0.2).normalized())
	var knee: Vector3 = legs[0]
	ankle = legs[1]
	out["thigh"] = _aim(_rest_dir[L.call("thigh")], Vector3.UP, knee - hip_at, fwd)
	out["shin"] = _aim(_rest_dir[L.call("shin")], Vector3.UP, ankle - knee, fwd)
	var foot := _aim(_rest_dir[L.call("foot")], Vector3.UP, fwd * 0.9 - up * 0.2 + outward * 0.15, up)
	out["foot"] = foot
	out["toes"] = _aim(_rest_dir[L.call("toes")], Vector3.UP, fwd - up * 0.35 + outward * 0.1, up)
	return out


## Where a hand or foot stands (world): where it was put down, or under it if it has not been.
func _contact(limb: String) -> Vector3:
	if _planted.has(limb):
		return (_planted[limb] as Dictionary)["at"]
	return _home(limb)


## Two bones from `root` of `a` and `b` long reaching for `target`, the joint
## between them bent towards `pole`: [the joint, where the end is].
static func _two_bone(root: Vector3, target: Vector3, a: float, b: float, pole: Vector3) -> Array:
	var to := target - root
	var reach := clampf(to.length(), absf(a - b) + 0.001, a + b - 0.001)
	var dir := to.normalized() if to.length() > 0.0001 else Vector3.DOWN
	var end := root + dir * reach
	var cos_a := clampf((a * a + reach * reach - b * b) / (2.0 * a * reach), -1.0, 1.0)
	var bend := pole - dir * dir.dot(pole)
	bend = bend.normalized() if bend.length() > 0.0001 else dir.cross(Vector3.RIGHT).normalized()
	var joint := root + (dir * cos_a + bend * sqrt(1.0 - cos_a * cos_a)) * a
	return [joint, end]


# --- Sound (made in code: nothing to load) ---

## Its call: harsh and grating, a heron's croak and a stork's rattle grown huge.
## A guttural, rasping "kraaah" through a long throat (pulses doubled and
## jittered so that it breaks into a growl), falling as it goes, with a
## clatter of the beak at the start and a wheeze at the end. 1.3 s.
static func call_sound() -> AudioStreamWAV:
	if _call_wav:
		return _call_wav
	var rate := 22050
	var length := 1.3
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var samples := PackedFloat32Array()
	samples.resize(count)
	var formants: Array[Band] = [Band.new(520.0, 3.5, rate), Band.new(1050.0, 4.0, rate), Band.new(2300.0, 5.0, rate), Band.new(3300.0, 5.0, rate)]
	var gains := [1.0, 0.9, 0.5, 0.25]
	var breath := Band.new(1800.0, 0.8, rate)
	var clack := Band.new(2600.0, 3.0, rate)
	var phase := 0.0
	var pulse_gain := 1.0
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var value := 0.0
		# The clatter of the beak: a few sharp knocks.
		for knock: float in [0.0, 0.045, 0.085]:
			if t > knock and t < knock + 0.02:
				value += clack.run(rng.randf_range(-1.0, 1.0) * 4.0 * exp(-(t - knock) * 260.0))
		var voice := smoothstep(0.1, 0.17, t) * (1.0 - smoothstep(0.95, 1.22, t))
		var pitch := lerpf(210.0, 120.0, smoothstep(0.15, 1.1, t)) * (1.0 + 0.05 * sin(t * TAU * 5.0))
		var before := phase
		phase += pitch / rate * (1.0 + rng.randf_range(-0.12, 0.12))
		if floorf(phase) != floorf(before):
			# (every other pulse weak: a subharmonic, the growl in it)
			pulse_gain = rng.randf_range(0.8, 1.1) if int(floorf(phase)) % 2 == 0 else rng.randf_range(0.2, 0.55)
		var p := fposmod(phase, 1.0)
		var pulse := (pow(1.0 - p, 7.0) * 2.4 - 0.3) * pulse_gain
		var throat := 0.0
		for k in formants.size():
			throat += formants[k].run(pulse) * gains[k]
		var rasp := breath.run(rng.randf_range(-1.0, 1.0)) * (0.9 + 0.6 * smoothstep(0.8, 1.2, t))
		value += (throat * 2.8 + rasp * 1.2) * voice
		# The wheeze after it.
		value += breath.run(rng.randf_range(-1.0, 1.0)) * smoothstep(1.0, 1.15, t) * (1.0 - smoothstep(1.15, length, t)) * 0.8
		value = tanh(value * 2.2)
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_call_wav = _wav(samples, loudest, rate)
	return _call_wav


## A wingbeat: a great sheet of skin thumped down through the air, a deep
## soft whump, and the membrane snapping taut at the bottom of it.
static func beat_sound() -> AudioStreamWAV:
	if _beat_wav:
		return _beat_wav
	var rate := 22050
	var length := 0.5
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var samples := PackedFloat32Array()
	samples.resize(count)
	var thump := Band.new(95.0, 0.7, rate)
	var snap := Band.new(900.0, 1.2, rate)
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var n := rng.randf_range(-1.0, 1.0)
		var env := smoothstep(0.0, 0.08, t) * exp(-t * 7.0)
		var crack := exp(-maxf(t - 0.22, 0.0) * 90.0) * smoothstep(0.215, 0.222, t)
		var value := thump.run(n) * 6.0 * env + snap.run(n) * 1.6 * crack
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_beat_wav = _wav(samples, loudest, rate)
	return _beat_wav


## The rush of a dive: wind roaring louder and higher over folded wings, 1.8 s.
static func rush_sound() -> AudioStreamWAV:
	if _rush_wav:
		return _rush_wav
	var rate := 22050
	var length := 1.8
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var samples := PackedFloat32Array()
	samples.resize(count)
	var band := Band.new(300.0, 1.4, rate)
	var hiss := Band.new(2400.0, 0.9, rate)
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		if i % 64 == 0:
			band.set_frequency(lerpf(260.0, 1100.0, smoothstep(0.0, 1.5, t)), 1.4)
		var n := rng.randf_range(-1.0, 1.0)
		var env := smoothstep(0.0, 1.3, t) * (1.0 - smoothstep(1.45, length, t))
		var gust := 0.8 + 0.2 * sin(t * 23.0) * sin(t * 7.0)
		var value := (band.run(n) * 2.0 + hiss.run(n) * 0.5 * smoothstep(0.6, 1.4, t)) * env * gust
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	_rush_wav = _wav(samples, loudest, rate)
	return _rush_wav


static func _wav(samples: PackedFloat32Array, loudest: float, rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / maxf(loudest, 0.001), -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav


## A resonant band-pass filter (a biquad), for the sounds.
class Band:
	var _b0 := 0.0
	var _a1 := 0.0
	var _a2 := 0.0
	var _rate := 22050
	var _x1 := 0.0
	var _x2 := 0.0
	var _y1 := 0.0
	var _y2 := 0.0

	func _init(frequency: float, q: float, rate: int) -> void:
		_rate = rate
		set_frequency(frequency, q)

	func set_frequency(frequency: float, q: float) -> void:
		var w := TAU * frequency / _rate
		var alpha := sin(w) / (2.0 * q)
		var a0 := 1.0 + alpha
		_b0 = alpha / a0
		_a1 = -2.0 * cos(w) / a0
		_a2 = (1.0 - alpha) / a0

	func run(x: float) -> float:
		var y := _b0 * x - _b0 * _x2 - _a1 * _y1 - _a2 * _y2
		_x2 = _x1
		_x1 = x
		_y2 = _y1
		_y1 = y
		return y

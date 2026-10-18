class_name GiantToad
extends Node3D
## A giant toad: how it looks and how it moves, and nothing of what it thinks.
## Whatever drives it (a game's enemy script, a cutscene, the example) moves
## this node about and calls on it; it poses itself from that.
##
## WHAT IT IS. A huge warty toad, squat and wet: a broad flat head as wide as
## its body, a wide mouth whose line runs back under the eardrum, bulging gold
## eyes with horizontal pupils high on turrets of skin, a kidney-shaped gland
## behind each, warts all over its back and legs, a pale throat that pulses,
## long hind legs folded in a Z beside it, short forelegs with splayed fingers.
## Muddy olive and brown with darker blotches, a pale cream belly. The model
## is a unit long from snout to rump (creatures/frog/models/toad.glb, built in
## Blender by tools/build_frogs.py); scale this node to make it as big as you
## want (The Clearing's is 2.8 m long and stands as high as a man's chest).
## One skinned mesh (one draw) and, when it is out, the tongue (two more).
##
## HOW IT MOVES. Move the node (`global_position`) and turn it (its Y rotation;
## it faces +Z):
## - sitting, it breathes: its throat flutters all the time, as a toad's does;
##   now and then it blinks (a lid drawn up over each eye);
## - moved slowly or turned on the spot, it crawls: diagonal pairs of legs
##   stepping, as toads walk;
## - `leap(to)`: it crouches, then throws itself up and forward in a great arc
##   with its hind legs straight out behind and its forelegs tucked back, swings
##   its forelegs forward as it comes down, lands on them and folds up again.
##   Each frame, move it by `leap_push() * delta` (or put it where you like:
##   the pose goes by time);
## - `strike(at)`: the tongue. A visible wind-up first (`WINDUP_TIME`): the
##   throat swells and the body rocks back, then the mouth gapes; then the
##   tongue shoots out to `at` (and a little past it, up to `tongue_reach`),
##   sticks there a moment and is reeled back in, and it gulps. `aim(at)`
##   moves where it will go until it fires. `tongue_segment()` is where the
##   tongue is (world), `tongue_radius()` how thick its sticky tip is;
## - `croak(times)`: the throat blown up into a great bubble, so many times;
## - `look_at_point`: the head lifts and dips towards it a little.
##
## Signals for sounds or anything else: `crouched`, `leapt`, `landed`,
## `croaked`, `tongue_fired(at)`, `tongue_back`, `gulped`. With `voice` on it
## croaks out loud (a deep, buzzing croak, made here).

signal crouched
signal leapt
signal landed
signal croaked
signal tongue_fired(at: Vector3)
signal tongue_back
signal gulped

enum Leap { NONE, GATHER, FLIGHT, LAND }
enum Tongue { NONE, WINDUP, OUT, HOLD, BACK }

## Seconds it crouches before it leaps, and takes to land and fold up.
const GATHER_TIME := 0.34
const LAND_TIME := 0.45
## Seconds from `strike` to the tongue leaving its mouth.
const WINDUP_TIME := 0.9
## How fast the tongue goes out and comes back, metres a second.
const TONGUE_SPEED := 42.0
const REEL_SPEED := 16.0
## How long the tongue sticks where it hit.
const HOLD_TIME := 0.22
const MODEL := "res://creatures/frog/models/toad.glb"
const MODEL_LO := "res://creatures/frog/models/toad_lo.glb"

## The parts of each limb, as the model names its bones (with _L or _R).
const LEG := ["thigh", "shin", "tarsus", "foot"]
const ARM := ["arm", "forearm", "hand"]

## The leap, as directions of each part of the left limbs in the body's frame
## (the right ones mirrored): hind legs thrown out straight behind and a little
## down, forelegs tucked back along the flanks.
const LEAP_POSE := {
	"thigh": Vector3(0.3, -0.28, -1.0), "shin": Vector3(0.14, -0.32, -1.0), "tarsus": Vector3(0.06, -0.36, -1.0), "foot": Vector3(0.04, -0.2, -1.0),
	"arm": Vector3(0.45, -0.35, -1.0), "forearm": Vector3(0.25, -0.25, -1.0), "hand": Vector3(0.1, -0.2, -1.0),
}
## Coming down: forelegs reaching forward and down to land on.
const REACH_POSE := {
	"arm": Vector3(0.4, -0.55, 0.7), "forearm": Vector3(0.08, -0.62, 0.8), "hand": Vector3(-0.1, -0.35, 1.0),
}

## Use the low-poly model (models/toad_lo.glb).
@export var low_poly := false
## Its colour, times the model's (each toad a little different).
@export var tint := Color.WHITE
## How far the tongue can reach, metres.
@export var tongue_reach := 9.0
## Work out how fast it goes from how it is moved (off: set `velocity`).
@export var measure_velocity := true
## Croak out loud.
@export var voice := true

## What it looks towards (world). INF: straight ahead.
var look_at_point := Vector3.INF
## How fast it is going (world, m/s): measured, or set it.
var velocity := Vector3.ZERO

var _model: Node3D
var _skeleton: Skeleton3D
var _body: MeshInstance3D
var _tongue: MeshInstance3D
var _tip: MeshInstance3D
var _voice: AudioStreamPlayer3D
## Each bone: its index, how it stands in the skeleton, and the head of it and the way it points (model space).
var _bones := {}
var _rest_dir := {}

var _t := 0.0
var _was := Vector3.INF
var _yaw_was := 0.0
var _turn := 0.0
var _crawl := 0.0
var _crawling := 0.0
var _leap := Leap.NONE
var _leap_t := 0.0
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _leap_height := -1.0
var _flight := 0.7
var _rise := 0.0
var _fall := 0.0
var _tongue_stage := Tongue.NONE
var _tongue_t := 0.0
var _aim := Vector3.ZERO
var _length := 0.0
var _goal_length := 0.0
var _croaks := 0
var _croak_t := 0.0
var _blink := 0.0
var _blink_in := 2.0
var _gulp := 0.0
var _rng := RandomNumberGenerator.new()
## The tongue's base and tip (world) as last posed.
var _base_world := Vector3.ZERO
var _tip_world := Vector3.ZERO

static var _croak_stream: AudioStreamWAV


func _ready() -> void:
	_rng.randomize()
	_model = (load(MODEL_LO if low_poly else MODEL) as PackedScene).instantiate()
	add_child(_model)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = FrogLook.toad_material()
		if mesh.name.begins_with("tongue_tip"):
			_tip = mesh
		elif mesh.name.begins_with("tongue"):
			_tongue = mesh
		else:
			_body = mesh
	_body.custom_aabb = AABB(Vector3(-1.4, -0.4, -1.6), Vector3(2.8, 1.8, 3.4))
	_body.set_instance_shader_parameter(&"tint", Vector3(tint.r, tint.g, tint.b))
	_tongue.visible = false
	_tip.visible = false
	_tongue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for b in _skeleton.get_bone_count():
		var rest := _skeleton.get_bone_global_rest(b)
		_bones[_skeleton.get_bone_name(b)] = [b, rest]
		_rest_dir[_skeleton.get_bone_name(b)] = rest.basis.y.normalized()
	if voice:
		_voice = AudioStreamPlayer3D.new()
		_voice.stream = croak_sound()
		_voice.unit_size = 8.0
		_voice.max_distance = 60.0
		add_child(_voice)
	settle()


## Sits it still as it is now, with nothing going on.
func settle() -> void:
	_was = global_position
	_yaw_was = global_rotation.y
	velocity = Vector3.ZERO
	_leap = Leap.NONE
	_tongue_stage = Tongue.NONE
	_length = 0.0
	_crawling = 0.0
	_pose(0.0)


## Leaps to `to` (world), its arc `height` metres high (less than 0: as high as
## suits how far). It crouches first (GATHER_TIME), then is in the air.
func leap(to: Vector3, height := -1.0) -> void:
	_leap = Leap.GATHER
	_leap_t = 0.0
	_leap_to = to
	_leap_height = height
	crouched.emit()


func leap_stage() -> Leap:
	return _leap


## How far through its stage of the leap it is, 0..1.
func leap_progress() -> float:
	match _leap:
		Leap.GATHER:
			return _leap_t / GATHER_TIME
		Leap.FLIGHT:
			return _leap_t / _flight
		Leap.LAND:
			return _leap_t / LAND_TIME
	return 0.0


## Seconds the flight of a leap of `distance` metres takes.
func flight_time(distance: float) -> float:
	return clampf(0.5 + distance * 0.055 / maxf(scale.x / 2.8, 0.3), 0.55, 1.1)


## How fast to move it this frame for the leap it is in (world, m/s; zero but in the air).
func leap_push() -> Vector3:
	if _leap != Leap.FLIGHT:
		return Vector3.ZERO
	var flat := Vector3(_leap_to.x - _leap_from.x, 0.0, _leap_to.z - _leap_from.z) / _flight
	return Vector3(flat.x, _rise - _fall * _leap_t, flat.z)


## The way it is leaping (flat, world).
func leap_way() -> Vector3:
	var way := Vector3(_leap_to.x - _leap_from.x, 0.0, _leap_to.z - _leap_from.z)
	return way.normalized() if way.length() > 0.01 else global_basis.z


## Shoots its tongue at `at` (world), after the wind-up.
func strike(at: Vector3) -> void:
	_tongue_stage = Tongue.WINDUP
	_tongue_t = 0.0
	_aim = at
	_length = 0.0


## Where the tongue will go, until it fires.
func aim(at: Vector3) -> void:
	if _tongue_stage == Tongue.WINDUP:
		_aim = at


func tongue_stage() -> Tongue:
	return _tongue_stage


## How far through the wind-up it is, 0..1 (1 once it has fired).
func windup_progress() -> float:
	if _tongue_stage == Tongue.WINDUP:
		return _tongue_t / WINDUP_TIME
	return 0.0 if _tongue_stage == Tongue.NONE else 1.0


## Where the tongue is: its root in the mouth and its tip (world). Both the
## same when it is in.
func tongue_segment() -> PackedVector3Array:
	return PackedVector3Array([_base_world, _tip_world])


## How far the sticky tip reaches round its middle, metres.
func tongue_radius() -> float:
	return 0.08 * scale.x


## Whether the tongue (out) touches a ball of `radius` at `point`.
func tongue_hits(point: Vector3, radius: float) -> bool:
	if _tongue_stage != Tongue.OUT and _tongue_stage != Tongue.HOLD:
		return false
	var along := _tip_world - _base_world
	var t := clampf((point - _base_world).dot(along) / maxf(along.length_squared(), 0.0001), 0.0, 1.0)
	var near := (_base_world + along * t).distance_to(point)
	return near < radius + (tongue_radius() if t > 0.85 else tongue_radius() * 0.45)


## Croaks, its throat blown up into a great bubble, `times` times.
func croak(times := 2) -> void:
	_croaks = times
	_croak_t = 0.0
	croaked.emit()
	if _voice and is_inside_tree():
		_voice.pitch_scale = _rng.randf_range(0.85, 1.05)
		_voice.play()


## Whether it is in the middle of something (a leap, the tongue, a croak).
func busy() -> bool:
	return _leap != Leap.NONE or _tongue_stage != Tongue.NONE or _croaks > 0


func _process(delta: float) -> void:
	_t += delta
	if measure_velocity and delta > 0.0:
		if _was.is_finite():
			var moved := (global_position - _was) / delta
			velocity = velocity.lerp(moved, 1.0 - exp(-12.0 * delta))
		_was = global_position
		var yaw := global_rotation.y
		_turn = lerpf(_turn, angle_difference(_yaw_was, yaw) / delta, 1.0 - exp(-10.0 * delta))
		_yaw_was = yaw
	_advance(delta)
	_pose(delta)


# Time goes on for whatever it is doing.
func _advance(delta: float) -> void:
	match _leap:
		Leap.GATHER:
			_leap_t += delta
			if _leap_t >= GATHER_TIME:
				_leap = Leap.FLIGHT
				_leap_t = 0.0
				_leap_from = global_position
				var flat := Vector2(_leap_to.x - _leap_from.x, _leap_to.z - _leap_from.z).length()
				_flight = flight_time(flat)
				var high := _leap_height if _leap_height >= 0.0 else (0.5 + 0.32 * flat) * maxf(scale.x / 2.8, 0.3)
				_fall = 8.0 * high / (_flight * _flight)
				_rise = ((_leap_to.y - _leap_from.y) + _fall * _flight * _flight * 0.5) / _flight
				leapt.emit()
		Leap.FLIGHT:
			_leap_t += delta
			if _leap_t >= _flight:
				_leap = Leap.LAND
				_leap_t = 0.0
				landed.emit()
		Leap.LAND:
			_leap_t += delta
			if _leap_t >= LAND_TIME:
				_leap = Leap.NONE
	match _tongue_stage:
		Tongue.WINDUP:
			_tongue_t += delta
			if _tongue_t >= WINDUP_TIME:
				_tongue_stage = Tongue.OUT
				_tongue_t = 0.0
				_length = 0.0
				var from := _mouth_world()
				_goal_length = minf(from.distance_to(_aim) + 0.5, tongue_reach)
				tongue_fired.emit(_aim)
		Tongue.OUT:
			_length = minf(_length + TONGUE_SPEED * delta, _goal_length)
			if _length >= _goal_length:
				_tongue_stage = Tongue.HOLD
				_tongue_t = 0.0
		Tongue.HOLD:
			_tongue_t += delta
			if _tongue_t >= HOLD_TIME:
				_tongue_stage = Tongue.BACK
		Tongue.BACK:
			_length = maxf(_length - REEL_SPEED * delta, 0.0)
			if _length <= 0.0:
				_tongue_stage = Tongue.NONE
				_gulp = 0.6
				tongue_back.emit()
				gulped.emit()
	if _croaks > 0:
		_croak_t += delta
		if _croak_t >= 0.55:
			_croak_t = 0.0
			_croaks -= 1
	_gulp = maxf(_gulp - delta, 0.0)
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink = 0.28
		_blink_in = _rng.randf_range(2.5, 7.0)
	_blink = maxf(_blink - delta, 0.0)


# The mouth (world): where the tongue comes from.
func _mouth_world() -> Vector3:
	return _model.global_transform * Vector3(0.0, 0.33, 0.42) if _model else global_position


# --- Posing ---

## Poses the skeleton for now.
func _pose(_delta: float) -> void:
	if _skeleton == null:
		return
	var dirs := {}
	for part: String in LEG + ARM:
		dirs[part] = _rest_dir[part + "_L"]
	var lift := 0.0
	var pitch := 0.0
	var head := 0.0
	var jaw := 0.0
	# Breathing: the throat flutters all the time.
	var throat := 0.06 + 0.06 * sin(_t * 8.5) + 0.03 * sin(_t * 2.1)
	var speed := Vector2(velocity.x, velocity.z).length() / maxf(scale.x, 0.01)

	# Crawling, slowly, or turning on the spot: diagonal pairs of legs stepping.
	var stepping := 0.0
	if _leap == Leap.NONE:
		stepping = clampf(maxf(speed / 0.12, absf(_turn) / 0.8), 0.0, 1.0)
	_crawling = lerpf(_crawling, stepping, 0.15)
	_crawl += (speed / 0.32 + absf(_turn) * 0.6) * get_process_delta_time()
	var steps := {}
	if _crawling > 0.01:
		for side: String in ["L", "R"]:
			for limb: String in ["leg", "arm"]:
				var offset := (0.0 if (side == "L") == (limb == "leg") else 0.5)
				var phase := (_crawl + offset) * TAU
				steps[limb + side] = Vector2(sin(phase), maxf(cos(phase), 0.0)) * _crawling
		lift += 0.012 * _crawling

	# The leap.
	var hind := 0.0
	var reach := 0.0
	var tuck := 0.0
	match _leap:
		Leap.GATHER:
			var g := _leap_t / GATHER_TIME
			lift -= 0.035 * sin(minf(g * 1.3, 1.0) * PI * 0.5)
			pitch += 0.08 * smoothstep(0.0, 0.7, g)
			var push := smoothstep(0.7, 1.0, g)
			hind = push * 0.6
			lift += push * 0.06
			pitch -= push * 0.35
			throat *= 1.0 - g
		Leap.FLIGHT:
			var p := _leap_t / _flight
			hind = 1.0 - 0.7 * smoothstep(0.45, 1.0, p)
			tuck = 1.0 - smoothstep(0.3, 0.7, p)
			reach = smoothstep(0.35, 0.8, p)
			pitch += lerpf(-0.42, 0.3, smoothstep(0.0, 1.0, p))
			throat = 0.0
		Leap.LAND:
			var q := _leap_t / LAND_TIME
			hind = 0.3 * (1.0 - smoothstep(0.0, 0.6, q))
			reach = 1.0 - smoothstep(0.15, 1.0, q)
			pitch += 0.3 * (1.0 - smoothstep(0.0, 0.7, q)) - 0.06 * sin(q * PI)
			lift -= 0.04 * sin(q * PI)
			throat *= q
	for part: String in LEG:
		dirs[part] = dirs[part].lerp(LEAP_POSE[part].normalized(), hind).normalized()
	for part: String in ARM:
		dirs[part] = dirs[part].lerp(LEAP_POSE[part].normalized(), tuck).normalized()
		dirs[part] = dirs[part].lerp(REACH_POSE[part].normalized(), reach).normalized()

	# The tongue: a wind-up (throat swells, the body rocks back, the mouth gapes), out, and back.
	match _tongue_stage:
		Tongue.WINDUP:
			var w := _tongue_t / WINDUP_TIME
			throat = maxf(throat, 1.0 * smoothstep(0.0, 0.55, w))
			pitch -= 0.12 * smoothstep(0.0, 0.6, w) - 0.1 * smoothstep(0.8, 1.0, w)
			lift += 0.015 * smoothstep(0.0, 0.6, w)
			head -= 0.05 * smoothstep(0.5, 0.9, w)
			jaw = 0.55 * smoothstep(0.55, 0.95, w)
		Tongue.OUT, Tongue.HOLD:
			jaw = 0.8
			throat = 0.1
			pitch += 0.06
			head -= 0.05
		Tongue.BACK:
			jaw = 0.8 * smoothstep(0.0, 1.5, _length)
			head -= 0.05 * smoothstep(0.0, 1.5, _length)
	# A croak: the throat blown up into a great bubble.
	if _croaks > 0:
		var c := sin(clampf(_croak_t / 0.5, 0.0, 1.0) * PI)
		throat = maxf(throat, 1.35 * c)
	# Swallowing: the eyes pushed down into the head, the throat working.
	var blink := 1.0 if _blink > 0.0 else 0.0
	if _gulp > 0.0:
		blink = 1.0
		throat = maxf(throat, 0.35 * sin(_gulp / 0.6 * PI))
	_body.set_instance_shader_parameter(&"blink", blink)
	# Looking: the head lifts towards something high and dips to something low.
	if look_at_point.is_finite() and _leap == Leap.NONE:
		var local := global_transform.affine_inverse() * look_at_point
		var up := atan2(local.y - 0.4 * 1.0, maxf(Vector2(local.x, local.z).length(), 0.5))
		head -= clampf(up, -0.2, 0.25) * 0.3

	_apply(dirs, steps, lift, pitch, head, jaw, throat)


## Turns the pose into the skeleton's bones, and places the tongue.
func _apply(dirs: Dictionary, steps: Dictionary, lift: float, pitch: float, head: float, jaw: float, throat: float) -> void:
	var pivot := Vector3(0.0, 0.2, -0.15)
	var body := Transform3D(Basis.IDENTITY, Vector3(0.0, lift, 0.0)) * Transform3D(Basis.IDENTITY, pivot) * Transform3D(Basis(Vector3.RIGHT, pitch), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot)
	var moved := {}
	moved["body"] = body
	var neck: Vector3 = _bones["head"][1].origin
	var head_m := body * _about(neck, Basis(Vector3.RIGHT, head))
	moved["head"] = head_m
	var hinge: Vector3 = _bones["jaw"][1].origin
	var jaw_m := head_m * _about(hinge, Basis(Vector3.RIGHT, jaw))
	moved["jaw"] = jaw_m
	var sac: Vector3 = _bones["throat"][1].origin
	var swell := Basis.from_scale(Vector3(1.0 + 0.55 * throat, 1.0 + 1.6 * throat, 1.0 + 0.45 * throat))
	moved["throat"] = jaw_m * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.012 * throat, 0.0)) * _about(sac, swell)
	for side: String in ["L", "R"]:
		var mirror := 1.0 if side == "L" else -1.0
		for limb: Array in [LEG, ARM]:
			var key := ("leg" if limb == LEG else "arm") + side
			var step: Vector2 = steps.get(key, Vector2.ZERO)
			var head_at: Vector3 = body * (_bones[limb[0] + "_" + side][1].origin as Vector3)
			for k in limb.size():
				var name: String = limb[k] + "_" + side
				var rest: Transform3D = _bones[name][1]
				var d: Vector3 = dirs[limb[k]]
				d = Vector3(d.x * mirror, d.y, d.z)
				if step != Vector2.ZERO and k == 0:
					# (a step: the limb swung forward and back about the up axis, and lifted as it comes forward)
					d = (Basis(Vector3.UP, step.x * 0.32 * mirror) * d + Vector3(0.0, step.y * 0.35, 0.0)).normalized()
				var new_dir := body.basis * d
				var hint := Vector3.UP if limb == LEG else Vector3.RIGHT
				var turn := _along(new_dir, body.basis * hint) * _along(_rest_dir[name], hint).inverse()
				moved[name] = Transform3D(turn, head_at) * Transform3D(Basis.IDENTITY, -rest.origin)
				# (the next joint along)
				var length := _length_of(limb, k, side)
				head_at += new_dir * length
	for name: String in moved:
		var entry: Array = _bones[name]
		var g: Transform3D = moved[name] * (entry[1] as Transform3D)
		var bone: int = entry[0]
		_skeleton.set_bone_pose_position(bone, g.origin)
		_skeleton.set_bone_pose_rotation(bone, g.basis.get_rotation_quaternion())
		_skeleton.set_bone_pose_scale(bone, g.basis.get_scale())
	_place_tongue(jaw_m)


# How long a part of a limb is: to the next joint, or (the last) a nominal length.
func _length_of(limb: Array, k: int, side: String) -> float:
	if k + 1 < limb.size():
		var a: Vector3 = _bones[limb[k] + "_" + side][1].origin
		var b: Vector3 = _bones[limb[k + 1] + "_" + side][1].origin
		return a.distance_to(b)
	return 0.1


func _place_tongue(jaw_m: Transform3D) -> void:
	var base_local := jaw_m * Vector3(0.0, 0.325, 0.4)
	var to_world := _model.global_transform
	_base_world = to_world * base_local
	var out := _tongue_stage in [Tongue.OUT, Tongue.HOLD, Tongue.BACK] and _length > 0.01
	_tongue.visible = out
	_tip.visible = out
	if not out:
		_tip_world = _base_world
		return
	var aim_local := to_world.affine_inverse() * _aim
	var way := (aim_local - base_local)
	if way.length() < 0.001:
		way = Vector3.FORWARD * -1.0
	way = way.normalized()
	var unit := maxf(to_world.basis.get_scale().x, 0.0001)
	var length_local := _length / unit
	# (the mesh runs along +Z, a unit long, flat side up)
	var across := Vector3.UP.cross(way)
	if across.length() < 0.05:
		across = Vector3.RIGHT
	across = across.normalized()
	var shaft_frame := Basis(across, way.cross(across).normalized(), way)
	_tongue.transform = Transform3D(shaft_frame.scaled_local(Vector3(1.7, 1.7, maxf(length_local - 0.04, 0.001))), base_local)
	var tip_local := base_local + way * length_local
	_tip.transform = Transform3D(shaft_frame.scaled_local(Vector3.ONE * 1.5), tip_local)
	_tip_world = to_world * tip_local


# A transform that turns (or scales) by `by` about `point`.
static func _about(point: Vector3, by: Basis) -> Transform3D:
	return Transform3D(Basis.IDENTITY, point) * Transform3D(by, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -point)


## A basis whose Y is `y`, with X as near `side` as can be (as build_frogs.py's `along`).
static func _along(y: Vector3, side: Vector3) -> Basis:
	var z := side.cross(y)
	if z.length() < 0.05:
		z = Vector3.UP.cross(y) if absf(y.y) < 0.9 else Vector3.FORWARD
	z = z.normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, z)


# --- Its voice ---

## A deep croak, made here: a buzzing pulse train (a low growl through a
## throat), rising and falling, three pulses of it.
static func croak_sound() -> AudioStreamWAV:
	if _croak_stream:
		return _croak_stream
	var rate := 22050
	var long := int(rate * 1.4)
	var data := PackedByteArray()
	data.resize(long * 2)
	var chance := RandomNumberGenerator.new()
	chance.seed = 3
	var phase := 0.0
	var low := 0.0
	for i in long:
		var t := float(i) / rate
		# (three swells of it, as the throat fills and empties)
		var swell := 0.0
		for k in 3:
			var at := t - k * 0.45
			if at > 0.0 and at < 0.4:
				swell = maxf(swell, sin(at / 0.4 * PI))
		var pitch := 62.0 + 10.0 * swell
		phase += pitch / rate
		# (each pulse a short burst, buzzing through the throat)
		var pulse := pow(maxf(sin(phase * TAU), 0.0), 6.0)
		var buzz := sin(phase * TAU * 3.0) * 0.5 + sin(phase * TAU * 5.0) * 0.25 + chance.randf_range(-0.3, 0.3)
		var sample := pulse * buzz * swell
		low += (sample - low) * 0.25
		data.encode_s16(i * 2, int(clampf(low * 1.6, -1.0, 1.0) * 30000.0))
	_croak_stream = AudioStreamWAV.new()
	_croak_stream.format = AudioStreamWAV.FORMAT_16_BITS
	_croak_stream.mix_rate = rate
	_croak_stream.data = data
	return _croak_stream

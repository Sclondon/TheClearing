class_name AlienBody
extends Node3D
## A grey alien, to look at and to watch move: the body (AlienModel) and all its
## motion, and nothing else. It does not think, choose, collide or catch: the
## game moves it and tells it what to do, and it looks right doing it. It needs
## no other script, scene, model or texture (it is made in code), so it drops
## into any Godot 4 game.
##
##     var alien := AlienBody.new()
##     add_child(alien)
##     # each frame: move it (global_position, rotation.y) as the game's body goes
##     alien.look_at_point = player.global_position + Vector3.UP * 1.5
##     alien.reach(player_chest)          # raise a hand at someone...
##     if alien.reach_stage() == AlienBody.Reach.GRAB and alien.in_beam(player_chest):
##         pass                           # ...and they are in its light: caught
##     alien.shimmer(somewhere, 1.0)      # warn where it will appear,
##     alien.blink_out()                  # go, in a flash,
##     alien.blink_in(somewhere, yaw)     # and come back there
##
## WHAT IT IS. A tall thin grey, 2.3 m (scale the node for others): a huge smooth
## cranium, big black slanted eyes, a slit of a mouth, a long thin neck, arms to
## its knees and three long fingers, legs like sticks; pale grey, no clothes.
## One draw (one skinned mesh), and its shadow; the light effects below are two
## or three more draws only while they show. Faces +Z; its feet are at the
## node's origin, on a floor that is level there.
##
## HOW IT WALKS. Its speed and direction are worked out from how the node moves
## (`global_position` from frame to frame; a jump of more than `teleport`
## metres is taken as being put somewhere, and `settle()` does the same). It
## walks too smoothly: knees always a little bent, its head never rising or
## falling, its body level and still, long low steps whose feet hardly leave the
## ground and stay where they are put on it (`stride` metres to a whole cycle of
## two steps), arms hanging dead at its sides, fingers flexing slowly one after
## another. Standing, it breathes very slightly and its fingers still move.
##
## HOW IT LOOKS. `look_at_point` (world; INF for nothing) is followed by its
## head, slowly and smoothly (its neck turns with it a little); and every few
## seconds its head tips to one side, quickly, and stays: the curious, birdlike
## tilt. With nothing to look at it looks about.
##
## REACHING. `reach(at)` raises its hand (the one on that side) at `at` (the game may move
## `reach_aim` while it does): RAISE (`REACH_RAISE` seconds: the arm comes up
## straight, the wrist bends back, the three fingers spread, its head tips; the
## time to get away), GRAB (`REACH_GRAB`: its palm shines and a pale cone of
## light runs from it towards `reach_aim`; `in_beam(point)` says whether a
## point is in that light), LOWER. `reach_stage()` says which; `hand_position()`
## is the middle of the palm.
##
## BLINKING. `blink_out()`: a flash, and it is drawn up into a line of light
## that goes out (`BLINK_OUT` seconds), and then it is GONE (hidden) until
## `blink_in(at, yaw)` puts it there and draws it back out of a column of light
## (`BLINK_IN`). `shimmer(at, seconds)`: a faint column of light that wavers and
## grows at `at`, and a ring on the ground round it, for as long as asked: the
## warning of where it will come (call `stop_shimmer()` to call it off).
## `blink_stage()` says where it is in this.
##
## Nothing here makes a sound; the game may play a hum with `shimmer` and a
## soft pop with each blink.

enum Reach { NONE, RAISE, GRAB, LOWER }
enum Blink { NONE, OUT, GONE, IN }

const REACH_RAISE := 0.85
const REACH_GRAB := 0.7
const REACH_LOWER := 0.8
const BLINK_OUT := 0.45
const BLINK_IN := 0.55
## How far and how wide its light reaches from the palm (model metres).
const BEAM_LENGTH := 3.4
const BEAM_RADIUS := 0.75
## The pale light of everything it shines.
const GLOW := Color(0.8, 0.88, 1.0)

## Metres it goes in a whole cycle of its walk (two steps).
@export var stride := 1.25
## Further than this between one frame and the next, it was put there (no walking).
@export var teleport := 3.0
## Where it looks, in the world (INF: nowhere in particular).
var look_at_point := Vector3.INF
## What its reaching hand is held out at, in the world.
var reach_aim := Vector3.INF

var _skeleton: Skeleton3D
var _body: MeshInstance3D
var _material: ShaderMaterial
var _bone := {}
var _parent := PackedInt32Array()
var _offset: Array[Vector3] = []
## Each bone as it is posed this frame, in model space.
var _global: Array[Transform3D] = []

var _time := 0.0
var _last := Vector3.INF
var _velocity := Vector3.ZERO
var _phase := 0.0
var _moving := 0.0
## The head: where it turns (yaw, pitch), its tilt and the tilt it is going to,
## and when it next changes its mind.
var _turn := Vector2.ZERO
var _tilt := 0.0
var _tilt_to := 0.0
var _tilt_in := 1.0
var _idle_look := Vector2.ZERO
var _idle_in := 0.0
var _rng := RandomNumberGenerator.new()

var _reach_time := INF
## Which hand it reaches with (1 its left, -1 its right).
var _reach_side := -1.0
var _blink := Blink.NONE
var _blink_time := 0.0

var _column_here: MeshInstance3D
var _column_there: MeshInstance3D
var _ring: MeshInstance3D
var _beam: MeshInstance3D
var _here_time := INF
var _there_for := 0.0
var _there_time := INF
var _there_at := Vector3.ZERO

const COLUMN_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(0.8, 0.88, 1.0);
uniform float strength = 1.0;
// Which way the bands run along it (UV.y), how fast, and how close together.
uniform float flow = 1.0;
uniform float lines = 22.0;
// How it fades towards each end (UV.y 0 at the top, 1 at the bottom).
uniform float fade_top = 0.6;
uniform float fade_bottom = 0.05;

void fragment() {
	float v = UV.y;
	float ends = smoothstep(0.0, fade_top, v) * smoothstep(1.0, 1.0 - fade_bottom, v);
	float band = 0.55 + 0.45 * sin(v * lines * 6.2832 - TIME * 7.0 * flow + sin(UV.x * 18.85 + TIME) * 0.6);
	float face = pow(abs(dot(NORMAL, VIEW)), 1.6);
	ALBEDO = color * strength * ends * band * face;
}
"""

const RING_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(0.8, 0.88, 1.0);
uniform float strength = 1.0;

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float off = (r - 0.62 - 0.05 * sin(TIME * 5.0)) / 0.07;
	float ring = exp(-off * off);
	float pool = (1.0 - smoothstep(0.0, 0.7, r)) * 0.35;
	ALBEDO = color * strength * (ring + pool) * (1.0 - smoothstep(0.85, 1.0, r));
}
"""


func _init() -> void:
	_rng.randomize()


func _ready() -> void:
	_skeleton = AlienModel.build()
	add_child(_skeleton)
	_body = _skeleton.get_node("Body")
	_material = _body.mesh.surface_get_material(0)
	for entry: Array in AlienModel.BONES:
		var bone := _skeleton.find_bone(entry[0])
		_bone[entry[0]] = bone
		_parent.append(_skeleton.get_bone_parent(bone))
		_offset.append(_skeleton.get_bone_rest(bone).origin)
		_global.append(_skeleton.get_bone_global_rest(bone))
	_column_here = _column()
	_column_there = _column()
	_ring = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.4, 2.4)
	_ring.mesh = plane
	_ring.material_override = _glow_material(RING_SHADER)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.top_level = true
	_ring.visible = false
	add_child(_ring)
	_beam = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.06
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.cap_top = false
	cone.cap_bottom = false
	cone.radial_segments = 16
	cone.rings = 1
	_beam.mesh = cone
	var beam_look := _glow_material(COLUMN_SHADER)
	beam_look.set_shader_parameter(&"flow", -1.0)
	beam_look.set_shader_parameter(&"lines", 6.0)
	beam_look.set_shader_parameter(&"fade_top", 0.08)
	beam_look.set_shader_parameter(&"fade_bottom", 0.6)
	_beam.material_override = beam_look
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.top_level = true
	_beam.visible = false
	add_child(_beam)
	settle()


func _column() -> MeshInstance3D:
	var column := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.5
	tube.bottom_radius = 0.62
	tube.height = 3.0
	tube.cap_top = false
	tube.cap_bottom = false
	tube.radial_segments = 20
	tube.rings = 1
	column.mesh = tube
	column.material_override = _glow_material(COLUMN_SHADER)
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	column.top_level = true
	column.visible = false
	add_child(column)
	return column


func _glow_material(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"color", GLOW)
	return material


# --- What the game tells it ---

## Takes where it is now as where it has always been: no walking off from where it was.
func settle() -> void:
	_last = global_position
	_velocity = Vector3.ZERO
	_moving = 0.0


## Raises its hand at `at` (world): the hand on that side of it. Does nothing
## while it is already reaching.
func reach(at: Vector3) -> void:
	if reach_stage() != Reach.NONE:
		return
	reach_aim = at
	_reach_time = 0.0
	_reach_side = 1.0 if to_local(at).x > 0.0 else -1.0


func reach_stage() -> Reach:
	if _reach_time < REACH_RAISE:
		return Reach.RAISE
	if _reach_time < REACH_RAISE + REACH_GRAB:
		return Reach.GRAB
	if _reach_time < REACH_RAISE + REACH_GRAB + REACH_LOWER:
		return Reach.LOWER
	return Reach.NONE


## Seconds until its light comes on (while it raises its hand), else 0.
func reach_in() -> float:
	return maxf(REACH_RAISE - _reach_time, 0.0) if _reach_time < REACH_RAISE else 0.0


## Lets its hand fall at once, wherever it is in a reach.
func stop_reaching() -> void:
	if reach_stage() == Reach.RAISE or reach_stage() == Reach.GRAB:
		_reach_time = REACH_RAISE + REACH_GRAB
	_beam.visible = false


## The middle of its reaching palm, in the world.
func hand_position() -> Vector3:
	var hand: int = _bone["hand_l" if _reach_side > 0.0 else "hand_r"]
	return _skeleton.global_transform * (_global[hand] * Vector3(0.0, -0.05, 0.0))


## Whether `point` (world) is in the light from its palm (only while it shines),
## `margin` metres of it counting.
func in_beam(point: Vector3, margin := 0.3) -> bool:
	if reach_stage() != Reach.GRAB or not reach_aim.is_finite():
		return false
	var from := hand_position()
	var scale_now := global_basis.get_scale().x
	var way := (reach_aim - from).normalized()
	var along := (point - from).dot(way)
	var length := _beam_length()
	if along < 0.0 or along > length + margin:
		return false
	var off := (point - from - way * along).length()
	return off < lerpf(0.06, BEAM_RADIUS, clampf(along / length, 0.0, 1.0)) * scale_now + margin


func blink_out() -> void:
	if _blink != Blink.NONE and _blink != Blink.IN:
		return
	stop_reaching()
	_blink = Blink.OUT
	_blink_time = 0.0
	_here_time = 0.0
	_column_here.global_position = global_position + Vector3.UP * 1.5 * global_basis.get_scale().y


## Comes back, at `at` facing `yaw` (radians about Y; NAN keeps the way it faced).
func blink_in(at := Vector3.INF, yaw := NAN) -> void:
	if at.is_finite():
		global_position = at
	if not is_nan(yaw):
		rotation.y = yaw
	settle()
	_blink = Blink.IN
	_blink_time = 0.0
	_here_time = INF
	_column_here.visible = false
	_there_at = global_position
	_there_for = 0.0
	_there_time = 0.0
	_skeleton.visible = true


func blink_stage() -> Blink:
	return _blink


## A shimmer at `at` (world, on the ground) for `seconds`: where it is coming.
func shimmer(at: Vector3, seconds := 1.0) -> void:
	_there_at = at
	_there_for = seconds
	_there_time = 0.0


func stop_shimmer() -> void:
	_there_time = INF
	_column_there.visible = false
	_ring.visible = false


## Whether the warning shimmer is showing.
func shimmering() -> bool:
	return _there_time < _there_for


# --- Each frame ---

func _process(delta: float) -> void:
	_time += delta
	_measure(delta)
	_effects(delta)
	if _blink == Blink.GONE:
		return
	_pose(delta)


## How fast it is going, from where the node has got to.
func _measure(delta: float) -> void:
	var at := global_position
	if not _last.is_finite() or at.distance_to(_last) > teleport:
		_last = at
		_velocity = Vector3.ZERO
	var moved := (at - _last) / maxf(delta, 0.0001)
	moved.y = 0.0
	_last = at
	_velocity = _velocity.lerp(moved, 1.0 - exp(-10.0 * delta))
	var local := global_basis.inverse() * _velocity
	local.y = 0.0
	var speed := local.length()
	_moving = move_toward(_moving, clampf(speed / 0.5, 0.0, 1.0), delta * 3.0)
	_phase = fposmod(_phase + speed * delta / stride, 1.0)
	if speed < 0.05 and _moving < 0.02:
		# (stood still, its feet come back under it at the end of a step)
		_phase = lerpf(_phase, roundf(_phase * 2.0) * 0.5, 1.0 - exp(-4.0 * delta))


func _pose(delta: float) -> void:
	var local_vel := global_basis.inverse() * _velocity
	local_vel.y = 0.0
	var heading := local_vel.normalized() if local_vel.length() > 0.05 else Vector3.BACK
	var raise := _reach_amount()

	# Hips: no rise and fall at all, only sunk a little on bent knees as it walks.
	var sink := 0.02 + 0.035 * _moving
	var sway := sin(_phase * TAU) * 0.035 * _moving
	_pose_bone("hips", Basis(Vector3.UP, sway), _offset[0] + Vector3(0.0, -sink, 0.0))
	var breath := sin(_time * 1.3) * 0.012
	_pose_bone("spine", Basis(Vector3.RIGHT, 0.02) * Basis(Vector3.UP, -sway * 0.6))
	_pose_bone("chest", Basis(Vector3.RIGHT, 0.035 - breath - 0.1 * raise) * Basis(Vector3.UP, -sway * 0.5 - 0.18 * raise * _reach_side))
	_head(delta, raise)

	for s in [1.0, -1.0]:
		_arm(s, raise if s == _reach_side else 0.0)
	for s in [1.0, -1.0]:
		_leg(s, heading, local_vel.length())

	for i in _global.size():
		var local: Transform3D = _global[_parent[i]].affine_inverse() * _global[i] if _parent[i] >= 0 else _global[i]
		_skeleton.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())
		_skeleton.set_bone_pose_position(i, local.origin)


## Poses a bone by its turn from its parent (and, the hips, where it is).
func _pose_bone(name: String, turn: Basis, at := Vector3.INF) -> void:
	var i: int = _bone[name]
	var origin: Vector3 = at if at.is_finite() else _offset[i]
	var mine := Transform3D(turn, origin)
	_global[i] = _global[_parent[i]] * mine if _parent[i] >= 0 else mine


## Poses a bone by which way it lies in model space.
func _pose_by(name: String, basis: Basis) -> void:
	var i: int = _bone[name]
	var parent: Transform3D = _global[_parent[i]]
	_global[i] = Transform3D(basis.orthonormalized(), parent * _offset[i])


## A turn that takes `from` to `to`, and `from_side` round to `to_side` about it.
static func _aim(from: Vector3, from_side: Vector3, to: Vector3, to_side: Vector3) -> Basis:
	return _frame(to, to_side) * _frame(from, from_side).inverse()


static func _frame(along: Vector3, side: Vector3) -> Basis:
	var y := along.normalized()
	var x := (side - y * side.dot(y))
	x = x.normalized() if x.length_squared() > 0.000001 else y.cross(Vector3.FORWARD).normalized()
	return Basis(x, y, x.cross(y))


## How far its reaching arm is up, 0..1.
func _reach_amount() -> float:
	match reach_stage():
		Reach.RAISE:
			return smoothstep(0.0, REACH_RAISE * 0.85, _reach_time)
		Reach.GRAB:
			return 1.0
		Reach.LOWER:
			return 1.0 - smoothstep(0.0, REACH_LOWER, _reach_time - REACH_RAISE - REACH_GRAB)
	return 0.0


func _head(delta: float, raise: float) -> void:
	var head := _global[_bone["neck"]] * (_offset[_bone["head"]] + Vector3(0.0, 0.15, 0.0))
	var want := Vector2.ZERO
	if look_at_point.is_finite():
		var to := to_local(look_at_point) - head
		var flat := Vector2(to.x, to.z).length()
		want = Vector2(clampf(atan2(to.x, to.z), -1.3, 1.3), clampf(atan2(to.y, flat), -0.7, 0.55))
		if to.z < -0.3 and absf(to.x) < 0.3:
			want.x = 0.0
	else:
		_idle_in -= delta
		if _idle_in <= 0.0:
			_idle_in = _rng.randf_range(1.5, 4.0)
			_idle_look = Vector2(_rng.randf_range(-0.9, 0.9), _rng.randf_range(-0.25, 0.15))
		want = _idle_look
	# (slow and smooth, the turn; no hurry in it)
	_turn = _turn.lerp(want, 1.0 - exp(-2.6 * delta))
	_tilt_in -= delta
	if _tilt_in <= 0.0:
		var curious := look_at_point.is_finite()
		_tilt_in = _rng.randf_range(1.2, 3.2) if curious else _rng.randf_range(2.5, 5.0)
		var side := -signf(_tilt_to) if absf(_tilt_to) > 0.1 and _rng.randf() < 0.7 else (1.0 if _rng.randf() < 0.5 else -1.0)
		_tilt_to = side * _rng.randf_range(0.18, 0.42 if curious else 0.28) if _rng.randf() < 0.8 else 0.0
	var tilt_goal := _tilt_to + 0.3 * raise
	# (the tilt is quick: a small jerk of the head, then still)
	_tilt = lerpf(_tilt, tilt_goal, 1.0 - exp(-11.0 * delta))
	var chest_yaw := _global[_bone["chest"]].basis
	_pose_by("neck", chest_yaw * Basis(Vector3.UP, _turn.x * 0.3) * Basis(Vector3.RIGHT, 0.05 - _turn.y * 0.3))
	var level := Basis(Vector3.UP, _turn.x) * Basis(Vector3.RIGHT, -_turn.y + 0.04) * Basis(Vector3.BACK, _tilt)
	_pose_by("head", level)


func _arm(s: float, raise: float) -> void:
	var side := "l" if s > 0.0 else "r"
	var upper := "upper_arm_" + side
	var fore := "forearm_" + side
	var hand := "hand_" + side
	var walk := sin((_phase + (0.0 if s > 0.0 else 0.5)) * TAU) * 0.07 * _moving
	# Hanging: a little out from the body, elbows a little bent, the swing of a walk barely there.
	var hang := Basis(Vector3.RIGHT, -walk - 0.04) * Basis(Vector3.BACK, 0.05 * s)
	var shoulder_at := _global[_bone["chest"]] * _offset[_bone[upper]]
	var rest_dir := AlienModel.joint(fore) - AlienModel.joint(upper)
	var hand_rest := AlienModel.joint("finger_%s_1_1" % side) - AlienModel.joint(hand)
	if raise > 0.0 and reach_aim.is_finite():
		var aim := to_local(reach_aim)
		var want := (aim - shoulder_at).normalized()
		want.z = maxf(want.z, 0.35)
		want = want.normalized()
		var down := (_global[_bone["chest"]].basis * hang * rest_dir).normalized()
		var dir := down.slerp(want, raise)
		var tremble := Vector3(sin(_time * 31.0), sin(_time * 27.0 + 1.0), 0.0) * 0.006 * (1.0 if reach_stage() == Reach.GRAB else 0.0)
		dir = (dir + tremble).normalized()
		_pose_by(upper, _aim(rest_dir, Vector3.BACK, dir, Vector3.UP.lerp(Vector3.BACK, 1.0 - raise)))
		_pose_bone(fore, Basis(Vector3.RIGHT, -0.12 * (1.0 - raise) - 0.04))
		# The wrist bent back, the palm turned to what it reaches for, the fingers up.
		var forearm_basis := _global[_bone[fore]].basis
		var hanging := forearm_basis
		var fingers_up := (Vector3.UP - dir * Vector3.UP.dot(dir)).normalized()
		var palm_out := _aim(hand_rest, Vector3(-s, 0.0, 0.0), fingers_up, dir)
		var q := hanging.get_rotation_quaternion().slerp(palm_out.get_rotation_quaternion(), smoothstep(0.3, 1.0, raise))
		_pose_by(hand, Basis(q))
	else:
		_pose_bone(upper, hang)
		_pose_bone(fore, Basis(Vector3.RIGHT, -0.16 - walk * 0.5))
		_pose_bone(hand, Basis(Vector3.RIGHT, -0.05) * Basis(Vector3.BACK, 0.06 * s))
	# Fingers: slowly flexing one after another, or spread wide as it reaches.
	var spread := [-0.22, 0.3, -0.5]
	for k in 3:
		var curl := (0.22 + 0.16 * sin(_time * 0.9 + k * 1.7 + s)) * (1.0 - raise)
		var open: float = spread[k] * raise
		var bend := Basis(Vector3.RIGHT, open - (0.25 * curl if k == 2 else 0.0)) * Basis(Vector3.BACK, -s * curl * (0.3 if k == 2 else 1.0) + s * 0.12 * raise)
		_pose_bone("finger_%s_%d_1" % [side, k], bend)
		_pose_bone("finger_%s_%d_2" % [side, k], Basis(Vector3.BACK, -s * curl * 1.2 + s * 0.08 * raise))


func _leg(s: float, heading: Vector3, speed: float) -> void:
	var side := "l" if s > 0.0 else "r"
	var thigh := "thigh_" + side
	var shin := "shin_" + side
	var foot := "foot_" + side
	var hip := _global[_bone["hips"]] * _offset[_bone[thigh]]
	var rest_ankle := AlienModel.joint(foot)
	var p := fposmod(_phase + (0.0 if s > 0.0 else 0.5), 1.0)
	# A long low step: on the ground 62% of the time and slid back under it as the
	# body goes on; then carried forward just clear of the ground, smoothly.
	const STANCE := 0.62
	var reach := stride * 0.5 * _moving
	var along := 0.0
	var lift := 0.0
	if p < STANCE:
		along = reach * (0.5 - p / STANCE)
	else:
		var swing := (p - STANCE) / (1.0 - STANCE)
		var eased := swing * swing * (3.0 - 2.0 * swing)
		along = reach * (-0.5 + eased)
		lift = sin(swing * PI) * (0.05 + 0.03 * minf(speed, 1.5)) * _moving
	var ankle := rest_ankle + heading * along + Vector3(0.0, lift, 0.0)
	# Knees forward and a touch out.
	var pole := Vector3(0.12 * s, 0.0, 1.0).normalized()
	var a := (AlienModel.joint(shin) - AlienModel.joint(thigh)).length()
	var b := (rest_ankle - AlienModel.joint(shin)).length()
	var to := ankle - hip
	var d := clampf(to.length(), absf(a - b) + 0.01, a + b - 0.002)
	var u := to.normalized()
	var x := (a * a - b * b + d * d) / (2.0 * d)
	var h := sqrt(maxf(a * a - x * x, 0.0))
	var bend := (pole - u * pole.dot(u)).normalized()
	var knee := hip + u * x + bend * h
	var ankle_at := knee + (hip + u * d - knee).normalized() * b
	_pose_by(thigh, _aim(AlienModel.joint(shin) - AlienModel.joint(thigh), Vector3.BACK, knee - hip, bend))
	_pose_by(shin, _aim(rest_ankle - AlienModel.joint(shin), Vector3.BACK, ankle_at - knee, bend))
	# The foot kept flat, its toes lifting a little as it is carried.
	var toe_up := lift * 2.0
	_pose_by(foot, Basis(Vector3.UP, 0.08 * s) * Basis(Vector3.RIGHT, -toe_up))


# --- The light ---

func _effects(delta: float) -> void:
	var size := global_basis.get_scale().x
	# Blinking out and in: flash, drawn up thin, cut away in rising bands.
	if _blink == Blink.OUT or _blink == Blink.IN:
		_blink_time += delta
		var length := BLINK_OUT if _blink == Blink.OUT else BLINK_IN
		var k := clampf(_blink_time / length, 0.0, 1.0)
		var gone := k if _blink == Blink.OUT else 1.0 - k
		_skeleton.scale = Vector3(1.0 - 0.94 * gone * gone, 1.0 + 0.12 * gone, 1.0 - 0.94 * gone * gone)
		_material.set_shader_parameter(&"flash", 1.6 * smoothstep(0.0, 0.35, gone) + (0.6 * (1.0 - k) if _blink == Blink.IN else 0.0))
		_material.set_shader_parameter(&"bands", smoothstep(0.35, 1.0, gone) * 0.9)
		_material.set_shader_parameter(&"band_rise", _time * 3.0)
		if k >= 1.0:
			if _blink == Blink.OUT:
				_blink = Blink.GONE
				_skeleton.visible = false
			else:
				_blink = Blink.NONE
			_skeleton.scale = Vector3.ONE
			_material.set_shader_parameter(&"flash", 0.0)
			_material.set_shader_parameter(&"bands", 0.0)
	# Where it went from: a column that flares and dies.
	if _here_time < 0.9:
		_here_time += delta
		var f := _here_time / 0.9
		_column_here.visible = true
		_column_here.scale = Vector3(size * (1.0 - 0.6 * f), size, size * (1.0 - 0.6 * f))
		_column_here.material_override.set_shader_parameter(&"strength", 1.4 * sin(PI * minf(f * 1.6, 1.0)) * (1.0 - f))
	else:
		_column_here.visible = false
	# Where it is coming: a growing shimmer, then, as it comes, a flare.
	var there := _there_time < _there_for or _blink == Blink.IN
	if there:
		_there_time += delta
		var grow := clampf(_there_time / maxf(_there_for, 0.01), 0.0, 1.0) if _blink != Blink.IN else 1.0
		var flare := 0.0
		if _blink == Blink.IN:
			flare = 1.0 - clampf(_blink_time / BLINK_IN, 0.0, 1.0)
		_column_there.visible = true
		_ring.visible = true
		_column_there.global_position = _there_at + Vector3.UP * 1.5 * size
		_column_there.scale = Vector3(size * (0.5 + 0.4 * grow), size, size * (0.5 + 0.4 * grow))
		var waver := 0.75 + 0.25 * sin(_time * 23.0) * sin(_time * 7.0)
		_column_there.material_override.set_shader_parameter(&"strength", (0.25 + 0.55 * grow) * waver + 1.2 * flare)
		_ring.global_position = _there_at + Vector3.UP * 0.03
		_ring.scale = Vector3.ONE * size * (0.6 + 0.4 * grow)
		_ring.material_override.set_shader_parameter(&"strength", (0.35 + 0.65 * grow) * waver + flare)
	else:
		_column_there.visible = false
		_ring.visible = false
	# Reaching: the light from its palm.
	if _reach_time < INF:
		_reach_time += delta
	var shining := reach_stage() == Reach.GRAB and reach_aim.is_finite() and _blink == Blink.NONE
	_beam.visible = shining
	if shining:
		var from := hand_position()
		var way := (reach_aim - from).normalized()
		var length := _beam_length()
		var t := (_reach_time - REACH_RAISE) / REACH_GRAB
		var swell := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.85, 1.0, t))
		var basis := _frame(-way, Vector3.UP if absf(way.y) < 0.9 else Vector3.RIGHT)
		basis = Basis(basis.x * BEAM_RADIUS * size, basis.y * length, basis.z * BEAM_RADIUS * size)
		_beam.global_transform = Transform3D(basis, from + way * length * 0.5)
		_beam.material_override.set_shader_parameter(&"strength", 0.45 * swell)
		_material.set_shader_parameter(&"flash", 0.25 * swell)
	elif _blink == Blink.NONE and reach_stage() == Reach.LOWER:
		_material.set_shader_parameter(&"flash", 0.0)


## How far its light reaches just now: a little past what it reaches for, and
## never further than BEAM_LENGTH.
func _beam_length() -> float:
	var size := global_basis.get_scale().x
	if not reach_aim.is_finite():
		return BEAM_LENGTH * size
	return clampf(hand_position().distance_to(reach_aim) + 0.8 * size, 1.0 * size, BEAM_LENGTH * size)

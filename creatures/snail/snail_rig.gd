class_name SnailRig
extends Node3D
## Poses the giant snail (creatures/snail/models/snail*.glb) in code, every
## frame, from how its Snail (the parent) is moved and what it says it is
## doing. No clips.
##
## THE FOOT follows the way the head went. The Snail keeps a trail of where
## its sole's front has been (and which way was up there); each bone down the
## foot is put where the head was so far back along it, turned as the surface
## was there, so the body drapes over the edge of a wall and up it, and round
## a corner, as a snail's does. Going, it stretches out a little; still, it
## draws up. The shell rides on the middle of the foot, rocking a little with
## the waves of its crawling, and sags with its weight when it is on a wall.
##
## THE HEAD rears a little and turns to whatever it reaches for (`aim`); with
## nothing to reach for it sways slowly from side to side. Each eye stalk is a
## chain of four bones: it bends towards what the snail reaches for, and
## waves about on its own, feeling the air, when there is nothing. A touch
## (`flinch`) rolls it in to a stub, quickly, and it unrolls again slowly. The
## feelers dip and tap the ground ahead as it goes.
##
## WITHDRAWN, everything pulls in towards the mouth of the shell (the foot
## drawn up short and low, the head and stalks in), and the shell is set down.
## The breathing pore opens and shuts every few seconds (and stays shut when
## it is in).
##
## Every bone is read from the model's skeleton (tools/build_snail.py): none
## has a parent and each rests unturned, so each is posed where it should be
## in the model's space.

## How far behind its head the trail is kept, metres at scale 1 (the foot is 8 m long).
const KEEP := 12.0
## Metres between the points of the trail, at scale 1.
const STEP := 0.1
## Where the front of the sole is in the model (the Snail's origin).
const FRONT := 3.6
## How long it takes to pull in, and to come out (seconds).
const IN_TIME := 0.5
const OUT_TIME := 1.6
## Half the foot's width and its height at each foot bone (the model's), tail to neck, for `touches`.
const FOOT_WIDE: Array[float] = [0.3, 0.67, 0.92, 1.1, 1.18, 1.2, 1.21, 1.2, 1.12, 1.0]
const FOOT_HIGH: Array[float] = [0.2, 0.42, 0.62, 0.8, 1.05, 1.45, 2.0, 2.4, 1.7, 1.2]
## The shell, as a ball: its radius (the model's).
const SHELL_RADIUS := 1.75

## Use the demade, low-poly model. Set before it enters the tree.
var low_poly := false
## The materials, by name (see SnailLook.dress).
var materials := {}

var _snail: Snail
var _model: Node3D
var _skeleton: Skeleton3D
var _foot: Array[int] = []
var _foot_rest: Array[Vector3] = []
var _head := -1
var _head_rest := Vector3.ZERO
var _eyes: Array = [[], []]
var _eye_rest: Array = [[], []]
var _feelers: Array = [[], []]
var _feeler_rest: Array = [[], []]
var _shell := -1
var _shell_rest := Vector3.ZERO
var _pore := -1
var _pore_rest := Vector3.ZERO

# The trail behind the head: points and ups, newest first (a ring).
var _trail_at := PackedVector3Array()
var _trail_up := PackedVector3Array()
var _trail_first := 0
var _trail_count := 0

var _time := 0.0
var _crawled := 0.0
var _moving := 0.0
var _in := 0.0
var _eye_out: Array[float] = [1.0, 1.0]
var _eye_hold: Array[float] = [0.0, 0.0]
var _eye_bend: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _reach := 0.0
var _look := Vector2.ZERO
var _breath := 0.0
var _gulp := 9.0
var _sway_seed := 0.0
# Where things are now, in the world (for `touches` and the rest).
var _foot_world: Array[Vector3] = []
var _up_world: Array[Vector3] = []
var _head_world := Vector3.ZERO
var _shell_world := Vector3.ZERO
var _eye_world: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _skip := 0


func _ready() -> void:
	_snail = get_parent() as Snail
	_build()
	_time = randf() * 20.0
	_sway_seed = randf() * 10.0
	settle()


## Lays its body straight out behind it along its surface, with nothing in motion.
func settle() -> void:
	var count := int(KEEP / STEP) + 2
	_trail_at.resize(count)
	_trail_up.resize(count)
	var where := global_transform
	var s := where.basis.get_scale().x
	var up := where.basis.y.normalized()
	var back := -where.basis.z.normalized()
	for i in count:
		_trail_at[i] = where.origin + back * (i * STEP * s)
		_trail_up[i] = up
	_trail_first = 0
	_trail_count = count
	_pose(0.0)


## Rolls in one eye stalk (0 its left, 1 its right; -1 both).
func flinch(side := -1) -> void:
	for i in 2:
		if side < 0 or side == i:
			_eye_hold[i] = 0.5


## It gulps (drawing something in): the head dips and works.
func gulp() -> void:
	_gulp = 0.0


func eye_tip(side: int) -> Vector3:
	return _eye_world[clampi(side, 0, 1)]


func head_point() -> Vector3:
	return _head_world


func shell_point() -> Vector3:
	return _shell_world


## Whether a ball at `point` of `radius` touches its foot, head or shell.
func touches(point: Vector3, radius: float) -> bool:
	if _foot_world.size() < 2:
		return false
	var s := global_basis.get_scale().x
	var shrink := lerpf(1.0, 0.6, _in)
	if point.distance_to(_shell_world) < (SHELL_RADIUS * s + radius):
		return true
	if point.distance_to(_head_world) < (0.9 * s * shrink + radius) and _in < 0.5:
		return true
	for i in _foot_world.size() - 1:
		var a := _foot_world[i]
		var b := _foot_world[i + 1]
		var ab := b - a
		var t := clampf((point - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var near := a + ab * t
		var up := SnailRig.turned(_up_world[i], _up_world[i + 1], t)
		var to := point - near
		var high := to.dot(up)
		var high_most := lerpf(FOOT_HIGH[i], FOOT_HIGH[i + 1], t) * s * shrink
		if high < -radius or high > high_most + radius:
			continue
		var wide := lerpf(FOOT_WIDE[i], FOOT_WIDE[i + 1], t) * s * shrink
		# (narrower towards its top)
		var at_height := wide * lerpf(1.0, 0.6, clampf(high / maxf(high_most, 0.01), 0.0, 1.0))
		if (to - up * high).length() < at_height + radius:
			return true
	return false


func _process(delta: float) -> void:
	if _snail == null or _skeleton == null:
		return
	delta = minf(delta, 1.0 / 20.0)
	_record()
	# (far from the camera it is posed less often: no one can see the difference)
	var camera := get_viewport().get_camera_3d() if get_viewport() else null
	var far := camera != null and camera.global_position.distance_to(global_position) > 60.0
	_skip += 1
	if far and _skip < 3:
		return
	_pose(delta * float(_skip))
	_skip = 0


## Keeps the trail of where the front of the sole has been.
func _record() -> void:
	var where := global_transform
	var s := where.basis.get_scale().x
	var at := where.origin
	var newest := _trail_at[_trail_first]
	var gone := at.distance_to(newest)
	if gone > 30.0 * s:
		# (put somewhere far: not crawled)
		settle()
		return
	if gone < STEP * s:
		return
	var steps := mini(int(gone / (STEP * s)), _trail_at.size() - 1)
	var up := where.basis.y.normalized()
	var newest_up := _trail_up[_trail_first]
	for k in steps:
		var t := float(k + 1) / steps
		_trail_first = (_trail_first - 1 + _trail_at.size()) % _trail_at.size()
		_trail_at[_trail_first] = newest.lerp(at, t)
		_trail_up[_trail_first] = SnailRig.turned(newest_up, up, t)
	_crawled += gone / s


## Where the trail is `back` metres behind the front of the sole, and which way is up and forward there.
func _along(back: float) -> Array:
	var s := global_basis.get_scale().x
	var at := global_position
	var up := global_basis.y.normalized()
	var left := back
	var size := _trail_at.size()
	var prev := at
	var prev_up := up
	for k in size:
		var i := (_trail_first + k) % size
		var point := _trail_at[i]
		var length := prev.distance_to(point)
		if length >= left and length > 0.00001:
			var t := left / length
			var where := prev.lerp(point, t)
			var where_up := SnailRig.turned(prev_up, _trail_up[i], t)
			return [where, where_up.normalized(), (prev - point).normalized()]
		left -= length
		prev = point
		prev_up = _trail_up[i]
	# (off the end of the trail: straight on back)
	var last := (_trail_first + size - 1) % size
	var before := (_trail_first + size - 2) % size
	var way := (_trail_at[before] - _trail_at[last]).normalized()
	if way.length() < 0.5:
		way = global_basis.z.normalized()
	return [prev - way * left, prev_up, way]


## A frame on the surface: +Y up off it, +Z forward, as a pure turn.
static func _frame(up: Vector3, forward: Vector3) -> Basis:
	var f := (forward - up * forward.dot(up))
	if f.length() < 0.001:
		f = up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD)
	f = f.normalized()
	return Basis(up.cross(f).normalized(), up, f)


func _pose(delta: float) -> void:
	_time += delta
	var s := global_basis.get_scale().x
	var speed := _snail.velocity.length() / maxf(s, 0.01)
	_moving = _approach(_moving, clampf(speed / 0.6, 0.0, 1.0), 2.0, delta)
	_in = _approach(_in, 1.0 if _snail.withdrawn else 0.0, 1.0 / (IN_TIME if _snail.withdrawn else OUT_TIME), delta)
	var inn := smoothstep(0.0, 1.0, _in)
	var model_inv := _skeleton.global_transform.affine_inverse()
	var to_model := model_inv.basis.orthonormalized()
	var world_down := Vector3.DOWN

	# --- The foot, along the trail ---
	# (stretched out a little going, drawn up short still; in its shell, drawn right in under it)
	var stretch := lerpf(0.94, 1.0, _moving)
	var shell_back := FRONT - _shell_rest.z
	_foot_world.resize(_foot.size())
	_up_world.resize(_foot.size())
	var shrink := lerpf(1.0, 0.6, inn)
	for i in _foot.size():
		var rest := _foot_rest[i]
		var back := (FRONT - rest.z) * stretch
		back = lerpf(back, shell_back + (back - shell_back) * 0.3, inn)
		var on: Array = _along(back * s)
		var at: Vector3 = on[0]
		var up: Vector3 = on[1]
		var ahead: Vector3 = on[2]
		_foot_world[i] = at
		_up_world[i] = up
		var frame := to_model * _frame(up, ahead)
		_skeleton.set_bone_pose(_foot[i], Transform3D(frame * Basis.from_scale(Vector3.ONE * shrink), model_inv * at))

	# --- The shell, riding on the middle of the foot ---
	var on_shell: Array = _along(shell_back * stretch * s)
	var shell_up: Vector3 = on_shell[1]
	var shell_frame := _frame(shell_up, on_shell[2])
	# (it rocks a little with the waves of the crawl; on a wall it sags with its weight)
	var rock := sin(_crawled * 2.6) * 0.035 * _moving
	shell_frame = shell_frame * Basis(Vector3.RIGHT, rock)
	var sag := world_down - shell_up * world_down.dot(shell_up)
	var shell_at: Vector3 = on_shell[0] + shell_frame * Vector3(_shell_rest.x, _shell_rest.y - 0.55 * inn, 0.0) * s
	shell_at += sag * 0.25 * s * (1.0 - absf(shell_up.dot(Vector3.UP)))
	var shell_turn := shell_frame * Basis(Vector3.RIGHT, 0.08 * inn)
	_shell_world = shell_at
	var shell_model := to_model * shell_turn
	var shell_pose := Transform3D(shell_model, model_inv * shell_at)
	_skeleton.set_bone_pose(_shell, shell_pose)
	# The breathing pore opens and shuts.
	_breath += delta / 7.0
	var open := smoothstep(0.0, 0.15, fposmod(_breath, 1.0)) * (1.0 - smoothstep(0.35, 0.5, fposmod(_breath, 1.0)))
	open *= 1.0 - inn
	var pore_pose := Transform3D(shell_model * Basis.from_scale(Vector3.ONE * lerpf(0.25, 1.1, open)), shell_pose * (_pore_rest - _shell_rest))
	_skeleton.set_bone_pose(_pore, pore_pose)

	# --- The head ---
	var head_back := FRONT - _head_rest.z
	var on_head: Array = _along(head_back * s)
	var head_frame := _frame(on_head[1], global_basis.z.normalized().lerp(on_head[2], 0.4))
	var head_at: Vector3 = on_head[0] + head_frame * Vector3(0.0, _head_rest.y, 0.0) * s
	var aim := _snail.aim
	var want := Vector2.ZERO
	var reach := 0.0
	if aim.is_finite():
		var local := head_frame.inverse() * (aim - head_at)
		want = Vector2(clampf(atan2(local.x, local.z), -0.6, 0.6), clampf(atan2(local.y, Vector2(local.x, local.z).length()), -0.2, 0.5))
		reach = 1.0
	else:
		# (feeling about: a slow sway from side to side, the head lifting now and then)
		want = Vector2(sin(_time * 0.37 + _sway_seed) * 0.28, 0.1 + 0.1 * sin(_time * 0.23 + _sway_seed * 2.0))
	_look = _look.lerp(want, 1.0 - exp(-1.6 * delta))
	_reach = _approach(_reach, reach, 1.5, delta)
	_gulp += delta
	var gulp := sin(clampf(_gulp / 1.2, 0.0, 1.0) * PI) * (1.0 if _gulp < 1.2 else 0.0)
	var head_turn := head_frame * Basis(Vector3.UP, _look.x * (1.0 - inn)) * Basis(Vector3.RIGHT, -(_look.y * 0.7 + _reach * 0.12) * (1.0 - inn) + gulp * 0.35)
	# (in its shell, the head is pulled in to the mouth)
	var mouth := shell_at + shell_frame * (Vector3(_head_rest.x, _head_rest.y, _head_rest.z) - _shell_rest) * s * 0.35
	head_at = head_at.lerp(mouth, inn * 0.85)
	_head_world = head_at
	var head_model := to_model * head_turn
	var head_scale := lerpf(1.0, 0.35, inn)
	var head_pose := Transform3D(head_model * Basis.from_scale(Vector3.ONE * head_scale), model_inv * head_at)
	_skeleton.set_bone_pose(_head, head_pose)

	# --- The eye stalks ---
	for side in 2:
		_eye_hold[side] -= delta
		var flinched := _eye_hold[side] > 0.0
		var out_to := 0.06 if (flinched or _snail.withdrawn) else 1.0
		# (in fast at a touch; out slowly, and only once the head is out)
		var rate := 7.0 if out_to < _eye_out[side] else (0.6 if _in < 0.2 else 0.0)
		_eye_out[side] = _approach(_eye_out[side], out_to, rate, delta)
		var out := _eye_out[side]
		var rests: Array = _eye_rest[side]
		var bones: Array = _eyes[side]
		var base: Vector3 = rests[0]
		# What it bends towards: the aim, or its own feeling about.
		var tip_rest: Vector3 = rests[3]
		var rest_way := (tip_rest - base).normalized()
		var way := rest_way
		var own := _time * (0.9 + side * 0.17) + _sway_seed * (3.0 + side)
		var wave := Vector3(sin(own) * 0.35, sin(own * 0.7 + 1.0) * 0.25, cos(own * 0.55) * 0.2) * (1.0 - _reach * 0.7)
		if aim.is_finite():
			var local_aim := (head_pose.affine_inverse() * (model_inv * aim))
			var to_aim := (local_aim - base).normalized()
			way = SnailRig.turned(rest_way, to_aim, 0.55 * _reach)
		way = (way + wave).normalized()
		var bend := Quaternion(rest_way, way)
		var prev := base
		var prev_rest := base
		var turn := Quaternion.IDENTITY
		for k in 4:
			var r: Vector3 = rests[k]
			var t := float(k) / 3.0
			# (bending more towards its tip)
			turn = Quaternion.IDENTITY.slerp(bend, smoothstep(0.0, 1.0, t * 1.2))
			var at := prev + Basis(turn) * (r - prev_rest) * out if k > 0 else base
			prev = at
			prev_rest = r
			var thick := lerpf(0.55, 1.0, out) if k < 3 else lerpf(0.2, 1.0, out)
			var local := Transform3D(Basis(turn) * Basis.from_scale(Vector3.ONE * thick), at)
			var pose := head_pose * Transform3D(Basis(), -_head_rest) * local
			_skeleton.set_bone_pose(bones[k], pose)
			if k == 3:
				_eye_world[side] = _skeleton.global_transform * pose.origin

	# --- The feelers: dipping and tapping the ground ahead ---
	for side in 2:
		var rests: Array = _feeler_rest[side]
		var bones: Array = _feelers[side]
		var base: Vector3 = rests[0]
		var tip: Vector3 = rests[1]
		var tap := (0.5 + 0.5 * sin(_time * 2.3 + side * 2.1)) * (0.6 + 0.4 * _moving)
		var dip := Quaternion(Vector3.RIGHT, tap * 0.45 * (1.0 - _reach * 0.5)) * Quaternion(Vector3.UP, sin(_time * 0.8 + side) * 0.2 * (1.0 if side == 0 else -1.0))
		var out := lerpf(0.15, 1.0, 1.0 - inn) * lerpf(0.7, 1.0, minf(_eye_out[0], _eye_out[1]))
		var root := Transform3D(Basis(dip), base)
		var end := Transform3D(Basis(dip) * Basis.from_scale(Vector3.ONE * lerpf(0.4, 1.0, out)), base + Basis(dip) * (tip - base) * out)
		_skeleton.set_bone_pose(bones[0], head_pose * Transform3D(Basis(), -_head_rest) * root)
		_skeleton.set_bone_pose(bones[1], head_pose * Transform3D(Basis(), -_head_rest) * end)

	# --- The skin: the muscle waves ---
	if materials.has("skin"):
		var skin := materials["skin"] as ShaderMaterial
		skin.set_shader_parameter(&"crawl", fposmod(_crawled, 1000.0))
		skin.set_shader_parameter(&"waves", _moving * (1.0 - inn))


static func _approach(from: float, to: float, rate: float, delta: float) -> float:
	return move_toward(from, to, rate * delta)


func _build() -> void:
	var path := "res://creatures/snail/models/snail%s.glb" % ("_lo" if low_poly else "")
	_model = (load(path) as PackedScene).instantiate()
	_model.name = "Model"
	add_child(_model)
	_model.position = Vector3(0.0, 0.0, -FRONT)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	materials = SnailLook.dress(_model)
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		# (it can be bent far from where it stands: up a wall behind it)
		mesh.custom_aabb = AABB(Vector3(-12.0, -12.0, -16.0), Vector3(24.0, 24.0, 32.0))
	for i in 10:
		var bone := _skeleton.find_bone("foot_%d" % i)
		_foot.append(bone)
		_foot_rest.append(_skeleton.get_bone_rest(bone).origin)
	_head = _skeleton.find_bone("head")
	_head_rest = _skeleton.get_bone_rest(_head).origin
	_shell = _skeleton.find_bone("shell")
	_shell_rest = _skeleton.get_bone_rest(_shell).origin
	_pore = _skeleton.find_bone("pore")
	_pore_rest = _skeleton.get_bone_rest(_pore).origin
	for side in 2:
		var suffix := "_l" if side == 0 else "_r"
		for k in 4:
			var bone := _skeleton.find_bone("eye%s_%d" % [suffix, k])
			_eyes[side].append(bone)
			_eye_rest[side].append(_skeleton.get_bone_rest(bone).origin)
		for k in 2:
			var bone := _skeleton.find_bone("feel%s_%d" % [suffix, k])
			_feelers[side].append(bone)
			_feeler_rest[side].append(_skeleton.get_bone_rest(bone).origin)


## `from` turned `t` of the way to `to` (both of length 1), and of length 1. (Vector3.slerp
## is unsteady for two all but the same, or all but opposite.)
static func turned(from: Vector3, to: Vector3, t: float) -> Vector3:
	var d := from.dot(to)
	if d > 0.9995 or d < -0.98:
		return from.lerp(to, t).normalized() if d > 0.0 or t >= 1.0 else (to if t > 0.5 else from)
	return from.slerp(to, t).normalized()

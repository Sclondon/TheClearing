class_name LuckDragon
extends Node3D
## A luck dragon: how it looks, moves and sounds, and nothing of what it
## thinks. Whatever drives it (a game's script, the example) moves this node
## (where its head joins its neck) about the sky; the rest of it follows.
##
## WHAT IT IS. A dragon of good fortune that swims through the air: about 35 m
## from nose to tail and slender, round as a great eel, thickest a third of the
## way back and drawn out into a long fine tail with a plume at its end; no
## wings. Small pale scales with a pearly sheen, broad plates down its belly,
## soft white fur along its back from the head to the tail and a mane of long
## locks streaming back from the crown and cheeks. Four short legs with three
## blunt toes each. A broad gentle head, more a great hound's than a reptile's:
## a high round brow, a short broad muzzle with a soft dark nose, hanging
## flews, big dark kind eyes, long hound's ears and long barbels trailing from
## its lips. Modelled in Blender (tools/build_luck_dragon.py, models/
## luck_dragon.glb); posed here every frame.
##
## HOW IT MOVES. Its body follows its head: every part of it passes through
## where the head passed, so a head that weaves and rises and falls draws the
## body after it in long S-waves, and one that circles coils it. On top of that
## it swims: a slow wave runs down it from neck to tail (`undulate`), quicker
## the faster it goes, and it banks into its turns. Its legs paddle slowly as it
## swims (`paddle`), are drawn back along it when it goes fast, and reach down
## (`reach`) when it comes down to someone. Its ears and barbels stream back in
## the wind of its going and sway after it. `aim` turns its head to look at
## something; `mouth` opens its jaw a little; `sing()` makes its call (a deep,
## warm hum with a ring of bells in it), `called` at the top.
##
## Cost: one skinned mesh (one draw, and its shadow); the full model (about
## 32,000 triangles) near the camera, beyond `lod_distance` a low one (about
## 6,600); `low_poly` makes every one use the low one (phones). Forty bones set
## every frame. Hide it, or set process_mode disabled, when it is far from
## everyone.

## The top of its call.
signal called

const MODEL := "res://creatures/luck_dragon/models/luck_dragon.glb"
## Spine bones, and how far apart along the body they are (as built).
const SPINES := 25
const SEG := 1.3
## How long it is, nose to tail, metres.
const LENGTH := 35.4
## Where the path its head has flown is remembered, every this many metres.
const STEP := 0.4
const CALL_TIME := 2.6

## Every luck dragon uses the low model.
static var low_poly := false

## Make its sounds (its call), from where its head is.
@export var sound := true
@export var volume_db := 2.0
## How far off its call is heard.
@export var sound_range := 220.0
## Beyond this from the camera the low model is drawn.
@export var lod_distance := 70.0
## How far its body waves as it swims, metres at the tail.
@export var undulate := 0.9
## Each dragon's own small differences (its tone, its timing).
@export var seed_value := 0

## What it looks at (world). INF: straight ahead.
var aim := Vector3.INF
## Its jaw: 0 shut, 1 open (a soft, smiling open mouth).
var mouth := 0.0
## How much its legs paddle as it swims (0 held still).
var paddle := 1.0
## Its legs reaching down and forward (to land, or to be near someone).
var reach := 0.0
## How fast it is going (measured from how it is moved).
var velocity := Vector3.ZERO
## For pictures and tests: stops it posing itself; pose it with `pose_now`.
var frozen := false

var _holder: Node3D
var _model: Node3D
var _skeleton: Skeleton3D
var _meshes: Array[MeshInstance3D] = []
var _bone := {}
var _spine: Array[int] = []
## Where its head has been, newest first, every STEP metres.
var _trail := PackedVector3Array()
var _swim := 0.0
var _t := 0.0
var _was := Vector3.INF
var _gaze := Vector3.FORWARD
var _mouth := 0.0
var _call := INF
var _called := true
var _lod_in := 0.0
var _low := false
var _sway := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _voice: AudioStreamPlayer3D
static var _call_wav: AudioStreamWAV


func _ready() -> void:
	_rng.seed = seed_value
	# (the skeleton lives in the world's own space: every bone is set where it is in the world)
	_holder = Node3D.new()
	_holder.name = "Body"
	_holder.top_level = true
	add_child(_holder)
	_holder.global_transform = Transform3D.IDENTITY
	_model = (load(MODEL) as PackedScene).instantiate()
	_holder.add_child(_model)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = LuckDragonLook.material()
		mesh.set_instance_shader_parameter(&"tone", _rng.randf_range(0.97, 1.03))
		_meshes.append(mesh)
	for i in _skeleton.get_bone_count():
		_bone[_skeleton.get_bone_name(i)] = i
	for i in SPINES:
		_spine.append(_bone["spine%02d" % i])
	_set_lod(false)
	if sound:
		_voice = AudioStreamPlayer3D.new()
		_voice.stream = call_sound()
		_voice.volume_db = volume_db
		_voice.unit_size = 30.0
		_voice.max_distance = sound_range
		add_child(_voice)
	settle()


func _set_lod(low: bool) -> void:
	_low = low or low_poly
	for mesh in _meshes:
		mesh.visible = String(mesh.name).ends_with("_lo") == _low


## Lays it out straight behind its head (the way this node faces), as if it had flown straight here.
func settle() -> void:
	var back := -global_basis.z.normalized() if is_inside_tree() else Vector3.BACK
	var head := global_position if is_inside_tree() else Vector3.ZERO
	_trail = PackedVector3Array()
	for k in int(LENGTH / STEP) + 4:
		_trail.append(head + back * STEP * (k + 1))
	_was = head
	velocity = Vector3.ZERO
	_gaze = -back
	if _skeleton:
		_pose(0.0)


## Lays it along a line of points from its head back (world), as if it had
## flown along it; the node is put at the first. For pictures, and to start it
## coiled or curved.
func lay_along(points: PackedVector3Array) -> void:
	if points.size() < 2:
		return
	global_position = points[0]
	_trail = PackedVector3Array()
	var at := points[0]
	var j := 1
	var left := STEP
	# (resampled every STEP metres along the line, and on straight past its end)
	while _trail.size() < int(LENGTH / STEP) + 4:
		if j < points.size():
			var to := points[j] - at
			if to.length() >= left:
				at += to.normalized() * left
				_trail.append(at)
				left = STEP
			else:
				left -= to.length()
				at = points[j]
				j += 1
		else:
			var way := (points[points.size() - 1] - points[points.size() - 2]).normalized()
			at += way * left
			_trail.append(at)
			left = STEP
	_was = global_position
	velocity = Vector3.ZERO
	_gaze = (points[0] - points[1]).normalized()
	if _skeleton:
		_pose(0.0)


## Its call: the head lifts, the mouth opens a little, a deep warm hum with bells in it.
func sing() -> void:
	_call = 0.0
	_called = false
	if _voice:
		_voice.pitch_scale = _rng.randf_range(0.95, 1.05)
		_voice.play()


func singing() -> bool:
	return _call < CALL_TIME


## Where its head is (world): the middle of its brow.
func head_point() -> Vector3:
	return _bone_world(_bone["head"], Vector3(0.0, 0.6, 1.4))


## A point on its back (world) `back` metres behind its head, `up` over its spine: to sit on.
func back_point(back: float, up := 1.0) -> Transform3D:
	var at := _point_at(back)
	var ahead := (_point_at(maxf(back - 0.6, 0.0)) - _point_at(back + 0.6)).normalized()
	var side := Vector3.UP.cross(ahead).normalized()
	if side.length_squared() < 0.5:
		side = Vector3.RIGHT
	var up_way := ahead.cross(side).normalized()
	return Transform3D(Basis(side, up_way, ahead), at + up_way * up)


## Where along its body (world) the point `back` metres behind the head is, as posed now.
func body_point(back: float) -> Vector3:
	var f := clampf(back / SEG, 0.0, SPINES - 1.0)
	var i := int(f)
	var a := _bone_world(_spine[i], Vector3.ZERO)
	var b := _bone_world(_spine[mini(i + 1, SPINES - 1)], Vector3.ZERO)
	return a.lerp(b, f - i)


func _bone_world(i: int, offset: Vector3) -> Vector3:
	return _skeleton.global_transform * (_skeleton.get_bone_global_pose(i) * offset)


func _process(delta: float) -> void:
	if delta <= 0.0 or frozen:
		return
	_t += delta
	var head := global_position
	if not _was.is_finite():
		_was = head
	velocity = velocity.lerp((head - _was) / delta, 1.0 - exp(-6.0 * delta))
	_was = head
	_grow_trail(head)
	var speed := velocity.length()
	# (the swimming wave runs back down it, quicker the faster it goes)
	_swim += delta * (0.9 + speed * 0.35)
	_mouth = lerpf(_mouth, maxf(mouth, 0.45 if singing() else 0.0), 1.0 - exp(-4.0 * delta))
	if _call < INF:
		_call += delta
		if not _called and _call > 0.3:
			_called = true
			called.emit()
		if _call > CALL_TIME + 1.0:
			_call = INF
	_sway = _sway.lerp(-velocity * 0.03, 1.0 - exp(-2.0 * delta))
	var want := _neck_forward()
	if aim.is_finite():
		var to := (aim - head)
		if to.length() > 1.0:
			to = to.normalized()
			# (it cannot turn its head right round)
			var most := 1.2
			var angle := want.angle_to(to)
			want = want.slerp(to, minf(1.0, most / maxf(angle, 0.001))) if angle > most else to
	_gaze = _gaze.slerp(want.normalized(), 1.0 - exp(-3.0 * delta)).normalized()
	_lod_in -= delta
	if _lod_in <= 0.0:
		_lod_in = 0.3
		var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
		_set_lod(camera != null and camera.global_position.distance_to(head) > lod_distance)
	_pose(delta)


## Adds to the path its head has flown, a point every STEP metres.
func _grow_trail(head: Vector3) -> void:
	if _trail.is_empty():
		settle()
		return
	var keep := int(LENGTH / STEP) + 4
	var added := 0
	while head.distance_to(_trail[0]) >= STEP and added < 400:
		_trail.insert(0, _trail[0] + (head - _trail[0]).normalized() * STEP)
		added += 1
	if added > 0 and _trail.size() > keep:
		_trail.resize(keep)
	if added >= 400:
		# (put a long way at once: laid out straight behind it)
		var back := (_trail[0] - head).normalized() if head.distance_to(_trail[0]) > 0.01 else Vector3.BACK
		for k in _trail.size():
			_trail[k] = head + back * STEP * (k + 1)


## The point on the path its head has flown, `back` metres behind it.
func _point_at(back: float) -> Vector3:
	var head := global_position
	if _trail.is_empty():
		return head + Vector3.BACK * back
	var first := head.distance_to(_trail[0])
	if back <= first:
		return head.lerp(_trail[0], back / maxf(first, 0.0001))
	var along := (back - first) / STEP
	var j := int(along)
	if j >= _trail.size() - 1:
		var last := _trail.size() - 1
		var way := (_trail[last] - _trail[last - 1]).normalized() if last > 0 else Vector3.BACK
		return _trail[last] + way * (back - first - last * STEP)
	return _trail[j].lerp(_trail[j + 1], along - j)


func _neck_forward() -> Vector3:
	var to := global_position - _point_at(1.5)
	return to.normalized() if to.length_squared() > 0.0001 else Vector3.FORWARD


## How far it waves at a point `back` metres behind its head: [across, up].
func _wave(back: float) -> Vector2:
	var grow := smoothstep(1.5, 9.0, back) * (0.55 + 0.45 * back / LENGTH)
	var phase := TAU * back / 14.0 - _swim * 2.2
	return Vector2(sin(phase), sin(phase * 0.7 + 1.3) * 0.6) * undulate * grow


## Poses it now (for pictures, after `lay_along` and with `frozen` set).
func pose_now() -> void:
	_pose(0.0)


func _pose(_delta: float) -> void:
	var to_skeleton := _skeleton.global_transform.affine_inverse()
	var points: Array[Vector3] = []
	points.resize(SPINES + 1)
	for i in SPINES + 1:
		var back := minf(i, SPINES - 1) * SEG + (SEG if i == SPINES else 0.0)
		var at := _point_at(back)
		var ahead := (_point_at(maxf(back - 0.5, 0.0)) - _point_at(back + 0.5)).normalized()
		var side := Vector3.UP.cross(ahead)
		side = side.normalized() if side.length_squared() > 0.0001 else Vector3.RIGHT
		var up := ahead.cross(side).normalized()
		var wave := _wave(back)
		points[i] = at + side * wave.x + up * wave.y
	var speed := velocity.length()
	for i in SPINES:
		var at := points[i]
		var ahead := (points[maxi(i - 1, 0)] - points[i + 1]).normalized() if i > 0 else (global_position - points[1]).normalized()
		var flat_side := Vector3.UP.cross(ahead)
		flat_side = flat_side.normalized() if flat_side.length_squared() > 0.0001 else Vector3.RIGHT
		var up := ahead.cross(flat_side).normalized()
		# Banked into its turns: its back leans in towards where the path bends.
		var bend := Vector3.ZERO
		if i > 0:
			bend = points[i - 1] + points[i + 1] - points[i] * 2.0
		var bank := -clampf(bend.dot(flat_side) * (1.5 + speed * 0.12), -0.6, 0.6)
		var basis := Basis(flat_side, up, ahead).rotated(ahead, bank)
		var pose := to_skeleton * Transform3D(basis, at)
		_skeleton.set_bone_pose_position(_spine[i], pose.origin)
		_skeleton.set_bone_pose_rotation(_spine[i], pose.basis.get_rotation_quaternion())
	# The head: on the neck, turned to what it looks at, lifted while it calls.
	var call_w := 0.0
	if _call < INF:
		call_w = smoothstep(0.0, 0.4, _call) * (1.0 - smoothstep(CALL_TIME - 0.6, CALL_TIME + 0.3, _call))
	var look := _gaze
	look = (look + Vector3.UP * 0.35 * call_w).normalized()
	var head_side := Vector3.UP.cross(look)
	head_side = head_side.normalized() if head_side.length_squared() > 0.0001 else Vector3.RIGHT
	var head_basis := Basis(head_side, look.cross(head_side).normalized(), look)
	var head_pose := to_skeleton * Transform3D(head_basis, global_position + head_basis * Vector3(0.0, 0.05, 0.1))
	_skeleton.set_bone_pose_position(_bone["head"], head_pose.origin)
	_skeleton.set_bone_pose_rotation(_bone["head"], head_pose.basis.get_rotation_quaternion())
	_turn("jaw", Basis(Vector3.RIGHT, _mouth * 0.32))
	# Ears and barbels: streaming back in the wind of its going, swaying after it.
	var wind := clampf(speed / 14.0, 0.0, 1.0)
	var flutter := sin(_t * 2.3 + seed_value) * 0.08 + sin(_t * 3.7) * 0.05
	for side: float in [1.0, -1.0]:
		var s := "_l" if side > 0.0 else "_r"
		var swing := _sway.dot(head_side) * side * 0.5
		_turn("ear1" + s, Basis(Vector3.RIGHT, -0.15 - wind * 0.45 + flutter) * Basis(Vector3.FORWARD, side * (0.1 + swing * 0.3 - wind * 0.15)))
		_turn("ear2" + s, Basis(Vector3.RIGHT, -wind * 0.35 + flutter * 1.4))
		_turn("barbel1" + s, Basis(Vector3.UP, side * (-0.1 - wind * 0.4 + flutter * 0.8)) * Basis(Vector3.RIGHT, -wind * 0.3 + call_w * 0.2))
		_turn("barbel2" + s, Basis(Vector3.UP, side * (-wind * 0.5 + flutter * 1.5)) * Basis(Vector3.RIGHT, -wind * 0.4 + flutter))
		# Legs: paddling as it swims, drawn back when it goes fast, reaching down to land.
		for leg: String in ["fore", "hind"]:
			var phase := _swim * 1.6 + (0.0 if leg == "fore" else PI * 0.5) + (0.0 if side > 0.0 else PI)
			var swim_swing := sin(phase) * 0.35 * paddle * (1.0 - wind * 0.7)
			var tuck := (0.35 + wind * 0.7) * (1.0 - reach)
			var down := -reach * 0.5
			_turn(leg + "1" + s, Basis(Vector3.RIGHT, swim_swing + tuck + down) * Basis(Vector3.FORWARD, side * (0.15 + 0.2 * tuck)))
			_turn(leg + "2" + s, Basis(Vector3.RIGHT, -0.3 + cos(phase) * 0.3 * paddle * (1.0 - wind) + tuck * 0.6 - reach * 0.3))
	_fit_bounds(points)


## Turns a bone by `q` on its parent (every bone's rest is the identity).
func _turn(name: String, q: Basis) -> void:
	var i: int = _bone.get(name, -1)
	if i >= 0:
		_skeleton.set_bone_pose_rotation(i, q.get_rotation_quaternion())


## Its meshes' bounds round where it is now (posed far from its rest, it would be culled by that).
func _fit_bounds(points: Array[Vector3]) -> void:
	var to_mesh := _meshes[0].global_transform.affine_inverse() if not _meshes.is_empty() else Transform3D.IDENTITY
	var box := AABB(to_mesh * global_position, Vector3.ZERO)
	for p in points:
		box = box.expand(to_mesh * p)
	box = box.grow(4.0)
	for mesh in _meshes:
		mesh.custom_aabb = box


# --- Sound (made in code: nothing to load) ---

## Its call: a deep, warm hum (a voice far bigger than any animal's, but gentle,
## rising and falling once like a sigh) with a ring of soft bells over it that
## shimmer and fade. 2.6 s.
static func call_sound() -> AudioStreamWAV:
	if _call_wav:
		return _call_wav
	var rate := 22050
	var length := CALL_TIME
	var count := int(rate * length)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var phase := 0.0
	var bells: Array[float] = [523.25, 659.25, 783.99, 1046.5, 1318.5]
	var bell_at: Array[float] = [0.25, 0.45, 0.62, 0.8, 1.0]
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var env := smoothstep(0.0, 0.5, t) * (1.0 - smoothstep(1.6, length, t))
		var pitch := 82.0 + 14.0 * sin(PI * clampf(t / 2.0, 0.0, 1.0)) + 1.2 * sin(t * TAU * 4.5)
		phase += pitch / rate
		# (a rounded voice: the fundamental and a few soft harmonics, through a gentle "oo")
		var hum := sin(TAU * phase) + 0.5 * sin(TAU * phase * 2.0) + 0.22 * sin(TAU * phase * 3.0) + 0.08 * sin(TAU * phase * 5.0)
		var value := hum * env * 0.55
		for k in bells.size():
			var since := t - bell_at[k]
			if since > 0.0:
				var ring := exp(-since * 1.6) * smoothstep(0.0, 0.02, since)
				value += sin(TAU * bells[k] * since * (1.0 + 0.002 * sin(since * 30.0))) * ring * 0.18 + sin(TAU * bells[k] * 2.76 * since) * ring * 0.05
		value += rng.randf_range(-1.0, 1.0) * 0.01 * env
		samples[i] = value
		loudest = maxf(loudest, absf(value))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(clampf(samples[i] / maxf(loudest, 0.001), -1.0, 1.0) * 26000.0))
	_call_wav = AudioStreamWAV.new()
	_call_wav.format = AudioStreamWAV.FORMAT_16_BITS
	_call_wav.mix_rate = rate
	_call_wav.data = data
	return _call_wav

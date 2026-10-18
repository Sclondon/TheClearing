class_name SlimeWall
extends Node3D
## A slime wall: a great quivering block of green jelly that fills a passage
## from wall to wall, and has been eating whoever came down it for a long time.
## You can see through it, and in it hang what is left of them: skeletons
## whole and in pieces, skulls, a boot, a scrap of shirt, a coil of rope, a
## horned skull, a rusted blade, turning slowly as it goes. It leaves a wet
## trail that dries behind it.
##
## This is only how it looks and moves; what it does is for the game to say.
## Move the node (it faces +Z: its front is the way it is going), and it does
## the rest itself:
##
## - IT FITS WHERE IT IS. A few times a second it feels out to either side (rays
##   on `room_mask`) and spreads, or squeezes, to fill the space between the
##   walls, between `min_width` and `max_width`, and slides over to sit in the
##   middle of it. Squeezed narrow, it rises up taller, and quivers. With
##   `measure_room` off it keeps to `width`.
## - IT MOVES LIKE JELLY. Its speed is worked out from how it is being moved:
##   going, its front heaves in waves; starting and stopping, it sways; it
##   sags, and its foot spreads; all of it quivers. All of that is in its
##   shaders (SlimeWallLook), so nothing is built as it moves.
## - `aim`: a point it is after (INF for none). Near enough, its front swells
##   towards it.
## - `hold(node, seconds)`: draws something (someone caught) into itself and
##   holds it there, rising and turning slowly, for `seconds`; then lets it go
##   where it is, stood upright again, and emits `released`. The node is moved
##   each frame, so stop it moving itself meanwhile (a CharacterBody: set its
##   process_mode to disabled).
## - `contains(point, margin)`: whether a point is inside it (for touching).
##
## Five draws: the jelly from inside and outside, what is in it, its drips, and
## the trail. It casts no shadow. Set `visible` false (or process_mode
## disabled) when nobody is near: it does nothing then.
##
##     var slime := SlimeWall.new()
##     add_child(slime)
##     slime.global_position = somewhere
##     # each frame: move it; optionally slime.aim = target_position
##     if slime.contains(player.global_position + Vector3.UP, 0.1): ...

## It has let go of something it was holding.
signal released(node: Node3D)

## How high and how deep (front to back) it is, at its usual width (`width`).
@export var height := 6.0
@export var depth := 4.0
## Its width where nothing hems it in, and the narrowest and widest it goes.
@export var width := 12.0
@export var min_width := 1.8
@export var max_width := 26.0
## Feel for the walls and fit between them (else always `width` wide).
@export var measure_room := true
## What it feels for: the physics layers that are walls to it.
@export_flags_3d_physics var room_mask := 1
## Seconds the trail takes to dry.
@export var trail_lasts := 25.0
## Which leftovers it has in it, and how many pieces.
@export var contents_seed := 1:
	set(value):
		contents_seed = value
		if _contents:
			_contents.mesh = SlimeWallLook.contents(contents_seed, contents_count)
@export_range(0, 40) var contents_count := 20
## How murky it is: how fast it clouds over, per metre seen through.
@export var murk := 0.22
@export var jelly_color := Color(0.20, 0.27, 0.13)
@export var clear_tint := Color(0.66, 0.80, 0.52)

## A point it is after (in the world), or INF.
var aim := Vector3.INF
## How wide it is now, and how far across it has slid to sit between the walls.
var fitted_width := 12.0
var fitted_offset := 0.0
## How much room it last felt on its left and right (metres; INF where it reached no wall).
var room_left := INF
var room_right := INF
## Its speed, as worked out from how it is moved (the world's).
var velocity := Vector3.ZERO

const TRAIL_COUNT := 64
## How far it goes between one patch of trail and the next.
const TRAIL_STEP := 0.9
const DRIPS := 10
## How far it presses into a wall it is against (metres), out of sight in the wall, so no gap shows.
const PRESS := 0.6

var _body: Node3D
var _jelly: MeshInstance3D
var _contents: MeshInstance3D
var _drips: MultiMeshInstance3D
var _trail: MultiMeshInstance3D
var _back: ShaderMaterial
var _front: ShaderMaterial
var _inside: ShaderMaterial
var _drip_material: ShaderMaterial
var _trail_material: ShaderMaterial
var _target_width := 12.0
var _target_offset := 0.0
var _last_gap := 0.0
## Which sides (left, right) are against a wall, and how far it has pressed into each (0..1).
var _hem := Vector2.ZERO
var _pressed := Vector2.ZERO
var _feel_in := 0.0
var _was_at := Vector3.INF
var _sway := 0.0
var _sway_speed := 0.0
var _squish := 0.0
var _surge := 0.0
var _reach := 0.0
var _trail_next := 0
var _trail_from := Vector3.INF
var _clock := 0.0
## What it holds: each {node, time, seconds, from (world), basis, spin}.
var _held: Array[Dictionary] = []


func _ready() -> void:
	fitted_width = width
	_target_width = width
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	_back = SlimeWallLook.back_material()
	_front = SlimeWallLook.front_material()
	_back.next_pass = _front
	_back.render_priority = 0
	_front.render_priority = 1
	_jelly = MeshInstance3D.new()
	_jelly.name = "Jelly"
	_jelly.mesh = SlimeWallLook.jelly_mesh()
	_jelly.material_override = _back
	_jelly.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(_jelly)

	_inside = SlimeWallLook.contents_material()
	_contents = MeshInstance3D.new()
	_contents.name = "Contents"
	_contents.mesh = SlimeWallLook.contents(contents_seed, contents_count)
	_contents.material_override = _inside
	_contents.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(_contents)

	_drip_material = SlimeWallLook.drip_material()
	_drip_material.render_priority = 2
	var drips := MultiMesh.new()
	drips.transform_format = MultiMesh.TRANSFORM_3D
	drips.use_custom_data = true
	drips.mesh = SlimeWallLook.drip_mesh()
	drips.instance_count = DRIPS
	var rng := RandomNumberGenerator.new()
	rng.seed = contents_seed * 7 + 3
	for i in DRIPS:
		drips.set_instance_transform(i, Transform3D.IDENTITY)
		drips.set_instance_custom_data(i, Color(rng.randf_range(-1.0, 1.0), 1.0 if i % 3 != 0 else -1.0, rng.randf(), rng.randf()))
	_drips = MultiMeshInstance3D.new()
	_drips.name = "Drips"
	_drips.multimesh = drips
	_drips.material_override = _drip_material
	_drips.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(_drips)

	_trail_material = SlimeWallLook.trail_material()
	_trail_material.render_priority = -1
	var trail := MultiMesh.new()
	trail.transform_format = MultiMesh.TRANSFORM_3D
	trail.use_custom_data = true
	trail.mesh = SlimeWallLook.trail_mesh()
	trail.instance_count = TRAIL_COUNT
	for i in TRAIL_COUNT:
		trail.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0, -1000, 0)))
		trail.set_instance_custom_data(i, Color(-1000.0, rng.randf(), rng.randf(), 0.0))
	_trail = MultiMeshInstance3D.new()
	_trail.name = "Trail"
	_trail.multimesh = trail
	_trail.material_override = _trail_material
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.top_level = true
	add_child(_trail)
	_trail.global_transform = Transform3D.IDENTITY
	_trail.custom_aabb = AABB(Vector3(-1e5, -1e3, -1e5), Vector3(2e5, 2e3, 2e5))
	_apply()
	settle()


## Puts it straight as it is where it is: nothing in motion, fitted to the room now.
func settle() -> void:
	_was_at = global_position
	velocity = Vector3.ZERO
	_sway = 0.0
	_sway_speed = 0.0
	_squish = 0.0
	_surge = 0.0
	if is_inside_tree() and measure_room:
		_feel()
	fitted_width = _target_width
	fitted_offset = _target_offset
	_pressed = _hem
	_trail_from = Vector3.INF
	_apply()


## How tall it is now (squeezed thin, it rises).
func fitted_height() -> float:
	return height * clampf(pow(width / maxf(fitted_width, 0.1), 0.35), 1.0, 1.55)


## Whether `point` (in the world) is within it, or within `margin` of it.
func contains(point: Vector3, margin := 0.0) -> bool:
	var local := _body.global_transform.affine_inverse() * point
	var half := Vector3(fitted_width * 0.5, fitted_height() * 0.5, depth * 0.5)
	return absf(local.x) < half.x + margin and local.y > -margin and local.y < half.y * 2.0 + margin \
			and absf(local.z) < half.z + margin + _surge * 0.5


## Draws `node` into it and holds it there for `seconds` (see the top).
func hold(node: Node3D, seconds := 1.8) -> void:
	for held in _held:
		if held["node"] == node:
			return
	_held.append({"node": node, "time": 0.0, "seconds": seconds, "from": node.global_position,
			"basis": node.global_transform.basis, "spin": Vector3(randf_range(-1, 1), 0.25, randf_range(-1, 1)).normalized()})


## Whether it is holding `node` (or anything, given null).
func holding(node: Node3D = null) -> bool:
	if node == null:
		return not _held.is_empty()
	for held in _held:
		if held["node"] == node:
			return true
	return false


## Lets go of everything it holds at once.
func let_go() -> void:
	for held in _held.duplicate():
		_release(held)


func _physics_process(delta: float) -> void:
	if measure_room:
		_feel_in -= delta
		if _feel_in <= 0.0:
			_feel_in = 0.12
			_feel()
	else:
		_target_width = width
		_target_offset = 0.0


func _process(delta: float) -> void:
	_clock += delta
	if delta <= 0.0:
		return
	# How it is going, from how it has been moved.
	var at := global_position
	var moved := (at - _was_at) / delta if _was_at.is_finite() else Vector3.ZERO
	_was_at = at
	if moved.length() > 30.0:
		moved = Vector3.ZERO
	var before := velocity
	velocity = velocity.lerp(moved, 1.0 - exp(-6.0 * delta))
	var forward := global_transform.basis.z
	var ahead := velocity.dot(forward)
	_surge = lerpf(_surge, clampf(absf(ahead) / 1.5, 0.0, 1.0), 1.0 - exp(-2.0 * delta))
	# It sways like a jelly on a plate: a spring, pushed by changes of speed.
	var push := (velocity - before).dot(forward) / delta
	_sway_speed += (-_sway * 9.0 - _sway_speed * 1.6 - push * 0.35) * delta
	_sway = clampf(_sway + _sway_speed * delta, -1.2, 1.2)
	# It spreads and squeezes towards the room it has, not all at once.
	var was_width := fitted_width
	fitted_width = move_toward(fitted_width, _target_width, delta * (2.0 + absf(_target_width - fitted_width) * 0.8))
	fitted_offset = move_toward(fitted_offset, _target_offset, delta * (1.5 + absf(_target_offset - fitted_offset)))
	_squish = lerpf(_squish, clampf((was_width - fitted_width) / delta * 0.6, -1.0, 1.0), 1.0 - exp(-4.0 * delta))
	_body.position = Vector3(fitted_offset, 0.0, 0.0)
	_pressed = _pressed.move_toward(_hem, delta * 2.0)
	# It swells towards what it is after, near enough.
	var reach_to := Vector3(0.0, 1.0, depth)
	var want := 0.0
	if aim.is_finite():
		var local := _body.global_transform.affine_inverse() * aim
		if local.z > 0.0 and local.z < depth * 0.5 + 6.0:
			want = clampf(1.0 - (local.z - depth * 0.5) / 6.0, 0.0, 1.0) * 1.4
			reach_to = Vector3(clampf(local.x, -fitted_width * 0.4, fitted_width * 0.4), clampf(local.y, 0.5, fitted_height() - 1.0), local.z)
	_reach = lerpf(_reach, want, 1.0 - exp(-2.5 * delta))
	_hold(delta)
	_lay_trail()
	_apply(reach_to)


## Feels out to either side (front, middle, back, at two heights) for the walls.
func _feel() -> void:
	var space := get_world_3d().direct_space_state
	var basis := global_transform.basis
	var right := basis.x
	var far := max_width * 0.5 + 1.0
	var left_room := far
	var right_room := far
	for along: float in [-0.45, -0.15, 0.15, 0.45]:
		for up: float in [1.0, 3.0]:
			var from := global_position + basis.z * depth * along + Vector3.UP * up
			for side: float in [-1.0, 1.0]:
				var query := PhysicsRayQueryParameters3D.create(from, from + right * side * far, room_mask)
				var hit := space.intersect_ray(query)
				if not hit.is_empty():
					var d: float = from.distance_to(hit["position"])
					if side > 0.0:
						right_room = minf(right_room, d)
					else:
						left_room = minf(left_room, d)
	# (it presses into a wall only if the wall stands higher than it: over a low one the pressing would show)
	var tall := Vector2.ZERO
	var top := global_position + Vector3.UP * (fitted_height() - 0.4)
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		var room := left_room if k == 0 else right_room
		if room < far and not space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + right * side * (room + 0.6), room_mask)).is_empty():
			tall[k] = 1.0
	room_left = left_room if left_room < far else INF
	room_right = right_room if right_room < far else INF
	# Hemmed in on both sides it fills the gap, and remembers how wide that was.
	# Open on one side (a turning off), it keeps to the width it had, along the
	# wall it still has; open on both, to the width it had, where it is.
	var gap := left_room + right_room - 0.15
	var keep := clampf(_last_gap if _last_gap > 0.0 else width, min_width, max_width)
	_hem = Vector2.ZERO
	if left_room >= far and right_room >= far:
		_target_width = keep
		_target_offset = clampf(_target_offset, -keep * 0.25, keep * 0.25)
	elif left_room >= far or right_room >= far:
		var near := minf(left_room, right_room)
		_target_width = keep
		var side := 1.0 if right_room < left_room else -1.0
		_target_offset = side * (near - _target_width * 0.5 - 0.05)
		_hem = (Vector2(0.0, 1.0) if side > 0.0 else Vector2(1.0, 0.0)) * tall
	else:
		_target_width = clampf(gap, min_width, max_width)
		_target_offset = (right_room - left_room) * 0.5 if gap <= max_width else 0.0
		_last_gap = _target_width
		if gap <= max_width:
			_hem = tall


func _apply(reach_to := Vector3(0.0, 1.0, 4.0)) -> void:
	if _back == null:
		return
	var half := Vector3(fitted_width * 0.5, fitted_height() * 0.5, depth * 0.5)
	var round_r := minf(1.6, minf(half.x, half.z) * 0.8)
	# (what is seen is pressed into the walls it is against, and squarer there)
	var reach := visual_extents()
	var seen := Vector3((reach.x + reach.y) * 0.5, half.y, half.z)
	for material: ShaderMaterial in [_back, _front, _drip_material]:
		material.set_shader_parameter(&"half_size", seen)
		material.set_shader_parameter(&"x_mid", (reach.y - reach.x) * 0.5)
		material.set_shader_parameter(&"side_round", Vector2(lerpf(round_r, 0.15, _pressed.x), lerpf(round_r, 0.15, _pressed.y)))
		material.set_shader_parameter(&"round_r", round_r)
		material.set_shader_parameter(&"surge", _surge)
		material.set_shader_parameter(&"sway", _sway)
		material.set_shader_parameter(&"squish", _squish)
		material.set_shader_parameter(&"reach", reach_to)
		material.set_shader_parameter(&"reach_amount", _reach)
	for material: ShaderMaterial in [_back, _front]:
		material.set_shader_parameter(&"density", murk)
		material.set_shader_parameter(&"deep", jelly_color)
	_front.set_shader_parameter(&"clear_tint", clear_tint)
	_inside.set_shader_parameter(&"half_size", half)
	_inside.set_shader_parameter(&"sway", _sway)
	_inside.set_shader_parameter(&"surge", _surge)
	# (narrow, the pieces are drawn smaller; in a great one, bigger)
	_inside.set_shader_parameter(&"content_scale", clampf(fitted_width / 3.5, 0.55, 1.0) * clampf(height / 6.0, 1.0, 1.35))
	_trail_material.set_shader_parameter(&"now", _clock)
	_trail_material.set_shader_parameter(&"lasts", trail_lasts)
	# (shaders move its faces about: say how far they might go)
	var box := AABB(Vector3(-half.x - 2.0, -0.5, -half.z - 3.0), Vector3(half.x * 2.0 + 4.0, half.y * 2.0 + 3.0, half.z * 2.0 + 6.0))
	_jelly.custom_aabb = box
	_contents.custom_aabb = box
	_drips.custom_aabb = box


## Moves what it holds: drawn in and up, turning slowly; let go when its time is up.
func _hold(delta: float) -> void:
	for held in _held.duplicate():
		var node: Node3D = held["node"]
		if not is_instance_valid(node) or not node.is_inside_tree():
			_held.erase(held)
			continue
		held["time"] += delta
		var k: float = clampf(held["time"] / held["seconds"], 0.0, 1.0)
		var from: Vector3 = held["from"]
		var local := _body.global_transform.affine_inverse() * from
		var inside := Vector3(clampf(local.x, -fitted_width * 0.3, fitted_width * 0.3), 0.7 + minf(2.4, fitted_height() * 0.4) * smoothstep(0.0, 0.75, k), 0.0)
		var pulled := smoothstep(0.0, 0.45, k)
		var spot := (_body.global_transform * inside)
		node.global_position = from.lerp(spot, pulled) + Vector3(sin(_clock * 1.7) * 0.06, sin(_clock * 1.1) * 0.08, 0.0)
		var spin: Vector3 = held["spin"]
		node.global_transform.basis = Basis(spin, smoothstep(0.0, 1.0, k) * 1.5) * (held["basis"] as Basis)
		if held["time"] >= held["seconds"]:
			_release(held)


func _release(held: Dictionary) -> void:
	_held.erase(held)
	var node: Node3D = held["node"]
	if is_instance_valid(node):
		node.global_transform.basis = held["basis"]
		released.emit(node)


## Lays a patch of trail every TRAIL_STEP it goes.
func _lay_trail() -> void:
	var at := _body.global_position
	if not _trail_from.is_finite():
		_trail_from = at
		return
	var flat := Vector3(at.x - _trail_from.x, 0.0, at.z - _trail_from.z)
	if flat.length() < TRAIL_STEP:
		return
	var heading := flat.normalized()
	var middle := (_trail_from + at) * 0.5
	_trail_from = at
	var basis := Basis.looking_at(-heading, Vector3.UP)
	basis = basis.scaled(Vector3(fitted_width * 0.92, 1.0, TRAIL_STEP * 2.4))
	var i := _trail_next
	_trail_next = (_trail_next + 1) % TRAIL_COUNT
	_trail.multimesh.set_instance_transform(i, Transform3D(basis, Vector3(middle.x, global_position.y + 0.03 + i * 0.0004, middle.z)))
	var custom := _trail.multimesh.get_instance_custom_data(i)
	_trail.multimesh.set_instance_custom_data(i, Color(_clock, custom.g, custom.b, 0.0))


## How far what is seen of it reaches to its left and right from its middle
## (metres): half its width, and further into any wall it is against.
func visual_extents() -> Vector2:
	return Vector2(fitted_width * 0.5 + PRESS * _pressed.x, fitted_width * 0.5 + PRESS * _pressed.y)

class_name FollowCamera
extends Camera3D
## The game camera, in one of two modes.
##
## SIDE: a fixed-angle side view, as in Inside. It leads the player slightly
## and ignores the vertical bounce of a jump; nothing needs steering.
##
## ORBIT: a third-person camera for open areas. Drag (the upper right of the
## screen, the right mouse button, or a right stick) turns it; left alone it
## drifts round behind the way he is going, and it pulls in rather than pass
## through a wall.
##
## ORBIT with `indoors` set is the same camera under a roof (a tomb that is
## walked through): it looks for room before it settles for coming close. See `_apply_indoors`.

enum Mode { SIDE, ORBIT }

@export var target: Player
@export var mode := Mode.SIDE

@export_group("Side")
## Camera position relative to the point it is watching.
@export var offset := Vector3(0.0, 1.7, 11.0)
@export var look_height := 0.85
## How far ahead of a running player the camera looks, in metres.
@export var look_ahead := 1.3
@export var follow_speed := 5.0
@export var vertical_speed := 3.0
## While airborne the camera only moves vertically beyond this distance.
@export var vertical_dead_zone := 0.9
## How much of the player's movement towards or away from the camera is followed.
@export_range(0.0, 1.0) var depth_follow := 0.5

@export_group("Orbit")
@export var distance := 6.0
@export var orbit_fov := 55.0
## Radians turned per pixel dragged, and per second at full stick.
@export var drag_sensitivity := 0.006
@export var stick_speed := 2.4
@export var pitch_limits := Vector2(-0.25, 1.2)
## How quickly it drifts round behind him when left alone, 0 for never.
@export var settle_speed := 0.9
## Under a roof: where the view it is asked for is shut off by a roof or a
## wall, it comes down flatter behind him before it comes in closer, watches
## him lower where he is bent double, and keeps the whole of what it sees
## (not only its middle) this side of the stone.
@export var indoors := false
## What it looks straight past: things too thin to be worth coming in for (a pillar).
var looks_past: Array[RID] = []

var _focus := Vector3.ZERO
var _ahead := Vector3.ZERO
var _lane_z := 0.0
var _yaw := -PI * 0.5 + 0.6
var _pitch := 0.4
var _reach := 6.0
## Indoors: the tilt it has settled for, and how high over his feet it watches.
var _tilt := 0.4
var _watch := 0.9
var _since_look := 10.0
var _swing := false
var _touch: TouchControls


func _ready() -> void:
	# Run after the player has updated its visual position for this frame.
	process_priority = 100
	_add_stick_actions()
	Gamepad.ensure(get_tree())
	if mode == Mode.ORBIT:
		fov = orbit_fov
		_reach = distance
	if target:
		_lane_z = target.global_position.z
		target.respawned.connect(snap)
		snap()
	_find_touch.call_deferred()


func _find_touch() -> void:
	_touch = get_tree().get_first_node_in_group(&"touch_controls") as TouchControls
	if _touch:
		_touch.look_enabled = mode == Mode.ORBIT
		if not _touch.look_reset.is_connected(look_behind):
			_touch.look_reset.connect(look_behind)


## Brings an orbiting camera round behind him, the way he is facing (two quick
## taps where the camera is turned do this).
func look_behind() -> void:
	_swing = true
	_since_look = 0.0


func snap() -> void:
	_focus = target.global_position
	_ahead = Vector3.ZERO
	if indoors:
		_tilt = _pitch
		_reach = distance
	_apply()


## Turns an orbiting camera to look the way `along` goes, from behind him.
func look_along(along: Vector3) -> void:
	_yaw = atan2(-along.x, -along.z)
	_since_look = 10.0


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.ORBIT and event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		_turn(event.relative * drag_sensitivity)
	elif mode == Mode.ORBIT and Gamepad.pressed(event, &"pad_r3"):
		# (the right stick pressed in: round behind him, as two taps of a finger)
		look_behind()


func _process(delta: float) -> void:
	if target == null:
		return
	if mode == Mode.ORBIT:
		_orbit(delta)
	else:
		_follow_side(delta)
	_apply()


func _follow_side(delta: float) -> void:
	var player := target.visual_position
	var flat := Vector3(target.velocity.x, 0.0, target.velocity.z)
	_ahead = _ahead.lerp(flat / maxf(target.run_speed, 0.01) * look_ahead, 1.0 - exp(-1.6 * delta))

	var blend := 1.0 - exp(-follow_speed * delta)
	_focus.x = lerpf(_focus.x, player.x + _ahead.x, blend)
	_focus.z = lerpf(_focus.z, _lane_z + (player.z - _lane_z) * depth_follow, blend)

	var rise := player.y - _focus.y
	if target.is_on_floor():
		_focus.y = lerpf(_focus.y, player.y, 1.0 - exp(-vertical_speed * delta))
	elif absf(rise) > vertical_dead_zone:
		_focus.y = lerpf(_focus.y, player.y - signf(rise) * vertical_dead_zone, blend)


func _orbit(delta: float) -> void:
	if _touch:
		_turn(_touch.take_look() * drag_sensitivity)
	var stick := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	# (not while input is blocked: see Player.input_blocked. GameCommon: Outside has Loading.busy)
	if stick.length_squared() > 0.0 and not Player.input_blocked:
		# (pushed a little it turns slowly, to aim it; all the way, at its full speed. How fast that is, and
		# which way up and down go, are his to choose: Settings.look_speed, Settings.look_invert)
		stick *= stick.length()
		if Settings.look_invert:
			stick.y = -stick.y
		_turn(stick * stick_speed * Settings.look_speed * delta)
	_since_look += delta
	if _swing:
		var behind_him := target.facing_yaw + PI
		_yaw = lerp_angle(_yaw, behind_him, 1.0 - exp(-9.0 * delta))
		_pitch = lerpf(_pitch, 0.4, 1.0 - exp(-9.0 * delta))
		if absf(angle_difference(_yaw, behind_him)) < 0.03:
			_swing = false

	# Left alone while he is on the move, drift round behind him. (Not on a rope:
	# there he goes back and forth, and the stick means what it meant when he
	# took hold only for as long as the camera stays where it was.)
	var flat := Vector3(target.velocity.x, 0.0, target.velocity.z)
	if settle_speed > 0.0 and _since_look > 1.5 and flat.length() > 1.0 and target.state != Player.State.ROPE:
		var behind := atan2(-flat.x, -flat.z)
		_yaw = lerp_angle(_yaw, behind, 1.0 - exp(-settle_speed * delta))

	var player := target.visual_position
	_focus = _focus.lerp(player, 1.0 - exp(-10.0 * delta))


func _turn(by: Vector2) -> void:
	if by == Vector2.ZERO:
		return
	_swing = false
	_yaw -= by.x
	_pitch = clampf(_pitch + by.y, pitch_limits.x, pitch_limits.y)
	_since_look = 0.0


func _apply() -> void:
	if mode == Mode.SIDE:
		global_position = _focus + offset
		look_at(_focus + Vector3.UP * look_height)
		return
	if indoors:
		_apply_indoors()
		return
	var watch := _focus + Vector3.UP * 0.9
	var away := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
	# Come in close rather than sit behind a wall.
	var wanted := distance
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(watch, watch + away * (distance + 0.3), 1))
	if not hit.is_empty():
		wanted = maxf(watch.distance_to(hit.position) - 0.3, 0.8)
	# In at once, back out gently.
	_reach = wanted if wanted < _reach else lerpf(_reach, wanted, 1.0 - exp(-4.0 * get_process_delta_time()))
	global_position = watch + away * _reach
	look_at(watch)


# The orbiting camera under a roof. Out of doors it is enough to come in
# along the line of sight until nothing is in the way; in a passage that would
# have it against the back of his head whenever it was tilted up at the roof.
# So it first asks how far it could stand back at the tilt it was given and at
# flatter ones, takes the steepest that leaves it most of its distance (the
# flattest, if none does), eases to that, and only then comes in as far as it
# must. How far it can stand back is asked five times over, at the middle of
# what it sees and towards each corner, so that no edge of the picture is
# inside a wall.
func _apply_indoors() -> void:
	var delta := get_process_delta_time()
	var space := get_world_3d().direct_space_state
	# He is watched at chest height, or lower where the roof is on his back.
	var feet := _focus + Vector3.UP * 0.25
	var over := space.intersect_ray(_ray(feet, feet + Vector3.UP * 1.1))
	var high := 0.9 if over.is_empty() else clampf((over.position as Vector3).y - _focus.y - 0.3, 0.3, 0.9)
	_watch = high if high < _watch else lerpf(_watch, high, 1.0 - exp(-5.0 * delta))
	var watch := _focus + Vector3.UP * _watch
	var wanted := _pitch
	var most := -1.0
	for tilt: float in [_pitch, _pitch * 0.66, _pitch * 0.33, 0.04, -0.12]:
		if tilt > _pitch + 0.001:
			continue
		var room := _room_behind(space, watch, tilt)
		if room >= distance * 0.8:
			wanted = tilt
			most = room
			break
		if room > most + 0.25:
			most = room
			wanted = tilt
	_tilt = lerpf(_tilt, wanted, 1.0 - exp(-7.0 * delta))
	var free := _room_behind(space, watch, _tilt)
	# In at once, back out gently.
	_reach = free if free < _reach else lerpf(_reach, free, 1.0 - exp(-4.0 * delta))
	var away := Vector3(sin(_yaw) * cos(_tilt), sin(_tilt), cos(_yaw) * cos(_tilt))
	global_position = watch + away * _reach
	look_at(watch)


# How far back from `watch` it can stand at a tilt before any of what it sees is in stone.
func _room_behind(space: PhysicsDirectSpaceState3D, watch: Vector3, tilt: float) -> float:
	var away := Vector3(sin(_yaw) * cos(tilt), sin(tilt), cos(_yaw) * cos(tilt))
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var up := right.cross(-away).normalized()
	var free := distance
	for corner: Vector2 in [Vector2.ZERO, Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, 1.0)]:
		var aside := right * corner.x * 0.32 + up * corner.y * 0.2
		# (out to the side from where he is watched, if there is room there, and then back)
		var from := watch
		if corner != Vector2.ZERO:
			var hit_aside := space.intersect_ray(_ray(watch, watch + aside * 1.15))
			from = watch + aside if hit_aside.is_empty() else watch.lerp(hit_aside.position, 0.7)
		var hit := space.intersect_ray(_ray(from, from + away * (distance + 0.25)))
		if not hit.is_empty():
			free = minf(free, from.distance_to(hit.position) - 0.25)
	return maxf(free, 0.7)


func _ray(from: Vector3, to: Vector3) -> PhysicsRayQueryParameters3D:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = looks_past
	return query


static func _add_stick_actions() -> void:
	for entry: Array in [[&"look_left", JOY_AXIS_RIGHT_X, -1.0], [&"look_right", JOY_AXIS_RIGHT_X, 1.0],
			[&"look_up", JOY_AXIS_RIGHT_Y, -1.0], [&"look_down", JOY_AXIS_RIGHT_Y, 1.0]]:
		if InputMap.has_action(entry[0]):
			continue
		InputMap.add_action(entry[0], 0.2)
		var motion := InputEventJoypadMotion.new()
		motion.axis = entry[1]
		motion.axis_value = entry[2]
		motion.device = Gamepad.device
		InputMap.action_add_event(entry[0], motion)

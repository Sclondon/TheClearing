class_name Rat
extends Node3D
## One brown rat: how it looks and moves, and nothing of what it does in a
## game. Whatever drives it puts it where it is (`global_position`, on the
## ground) and says how it is going (`step(velocity, delta)` every frame); the
## rat turns to face the way it goes, its back bending into the turns, and goes
## from a walk to the hunched bounding scurry of a rat in a hurry with its tail
## swaying after it. Stood still it sniffs about, its whiskers twitching; it
## rears up on its haunches to sniff the air (`rear`), puts its head down to
## gnaw at something (`feeding`), and squeaks (`squeak()`).
##
##     var rat := Rat.new()
##     add_child(rat)
##     # every frame:
##     rat.global_position = where_it_is
##     rat.step(how_it_moves, delta)
##     rat.rear = 1.0          # up on its haunches (0: down on all fours)
##     rat.feeding = true      # head down, gnawing
##     rat.squeak()
##
## Drawn as one MultiMesh of one rat (RatLook; one draw, no shadow), in full
## when the camera is within `detail_range`, else the low rat (or always the
## low one with `low_poly`).

## How big it is (1: a brown rat 25 cm nose to rump).
@export var size := 1.0
## Its own number, 0 to 1 (its shade, and the time its twitches keep).
@export var own := 0.5
## Always the low rat (phones).
@export var low_poly := false
## Nearer the camera than this it is drawn in full (m).
@export var detail_range := 9.0
@export var voice := true
@export var volume_db := -6.0

## Which way it faces, radians about Y (0 faces +Z).
var facing := 0.0
## How far up on its haunches it is meant to be (0 to 1), and whether it is gnawing.
var rear := 0.0
var feeding := false
## How fast it is going now (m/s).
var going := 0.0

var _drawn: MultiMeshInstance3D
var _stride := 0.0
var _bend := 0.0
var _reared := 0.0
var _low := true
var _detail_in := 0.0
var _squeak: AudioStreamPlayer3D
var _custom := Color()


func _ready() -> void:
	_drawn = MultiMeshInstance3D.new()
	_drawn.name = "Rat"
	_drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_drawn.top_level = true
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = RatLook.mesh(true)
	many.instance_count = 1
	_drawn.multimesh = many
	many.set_instance_transform(0, Transform3D.IDENTITY)
	_drawn.custom_aabb = AABB(Vector3(-0.4, -0.1, -0.4), Vector3(0.8, 0.5, 0.8))
	add_child(_drawn)
	if voice:
		_squeak = AudioStreamPlayer3D.new()
		_squeak.unit_size = 2.5
		_squeak.max_distance = 25.0
		_squeak.volume_db = volume_db
		add_child(_squeak)
	_pose()


## It is going at `velocity` (only how it goes along the ground counts): it turns that way, and steps.
func step(velocity: Vector3, delta: float) -> void:
	var flat := Vector2(velocity.x, velocity.z)
	going = flat.length()
	var turned := 0.0
	if going > 0.05:
		var want := atan2(flat.x, flat.y)
		var before := facing
		facing = lerp_angle(facing, want, minf(delta * (8.0 + going * 2.0), 1.0))
		turned = wrapf(facing - before, -PI, PI) / maxf(delta, 0.001)
	_bend = lerpf(_bend, clampf(-turned * 0.18, -0.9, 0.9), minf(delta * 8.0, 1.0))
	_stride += RatLook.stride_rate(going, size) * delta
	_reared = move_toward(_reared, rear if going < 0.4 else 0.0, delta * 3.0)
	_detail_in -= delta
	if _detail_in <= 0.0:
		_detail_in = 0.5
		_choose_detail()
	_pose()


## A squeak or two.
func squeak() -> void:
	if _squeak:
		_squeak.stream = RatVoice.squeak()
		_squeak.pitch_scale = 0.9 + own * 0.3
		_squeak.play()


## Whether it is drawn in full now.
func detailed() -> bool:
	return not _low


func _choose_detail() -> void:
	var low := low_poly
	if not low:
		var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
		low = camera == null or camera.global_position.distance_to(global_position) > detail_range
	if low != _low:
		_low = low
		_drawn.multimesh.mesh = RatLook.mesh(low)


func _pose() -> void:
	if _drawn == null:
		return
	var basis := Basis(Vector3.UP, facing).scaled(Vector3.ONE * size)
	_drawn.global_transform = Transform3D(basis, global_position)
	var go := clampf(going / 4.0, 0.0, 0.99)
	_custom = RatLook.custom(_stride, go, _bend, _reared, RatLook.HEAD_DOWN if feeding and going < 0.3 else 0, own)
	_drawn.multimesh.set_instance_custom_data(0, _custom)

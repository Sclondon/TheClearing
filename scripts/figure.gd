class_name Figure
extends CharacterBody3D
## Anyone who is not the player: a body for a figure on the boy's rig
## (scripts/character_rig.gd), which walks or runs to wherever it is sent.
##
## Like the mummy and the hound it builds everything it needs, so in a level:
##     var man := Figure.new()
##     man.model = preload("res://models/watchman.glb")
##     man.model_low = preload("res://models/watchman_lo.glb")
##     man.size = 1.4
##     man.position = Vector3(3, 0, 0)
##     add_child(man)
##     man.go_to(Vector3(9, 0, 0))
## Set everything above the `add_child` before it: the figure is built in _ready.
## New models are made with tools/build_figure_template.py and checked with
## tools/figure_sheets.gd.

## It has got to where it was sent.
signal arrived

## The figure, on the rig's skeleton. With none, the rig falls back on the boy.
@export var model: PackedScene
## Its demade version, used when the menu asks for those. Optional.
@export var model_low: PackedScene
## How many times its modelled height it stands. Figures are modelled about as
## tall as the boy (1.25 m), whatever they are, and brought to size here.
@export var size := 1.0
@export var walk_speed := 1.4
@export var run_speed := 4.2
@export var acceleration := 8.0
@export var turn_rate := 6.0
@export var gravity := 24.0
## How near is near enough to where it was sent.
@export var arrive_distance := 0.12
## The capsule that stands for it in the world.
@export var radius := 0.26
@export var height := 1.7
## Passed on to the rig (see CharacterRig), and may be changed at any time: how
## loosely it carries itself, how far it is hunched, and how far its arms are held out.
@export_range(0.0, 1.0) var looseness := 0.7
@export var stoop := 0.0
@export_range(0.0, 1.0) var arms_reach := 0.0
@export var cel_shaded := true
@export var dusty := true

## Heading of the model, radians around Y. Zero faces +Z.
var facing_yaw := 0.0
## Where it is drawn: its position, smoothed between physics steps.
var visual_position := Vector3.ZERO
## Read by the rig. Set it to have the figure lean in and heave as it walks.
var is_pushing := false
var rig: CharacterRig

var _goal := Vector3.ZERO
var _going := false
var _hurry := false
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO


func _init() -> void:
	# As the mummy and the hounds: the world stops it, the player does not.
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.3


func _ready() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = height * 0.5
	add_child(collider)

	rig = _new_rig()
	rig.model = model_low if Settings.low_poly and model_low else model
	rig.looseness = looseness
	rig.stoop = stoop
	rig.arms_reach = arms_reach
	rig.cel_shaded = cel_shaded
	rig.dusty = dusty
	add_child(rig)
	# The rig is placed by hand each frame (see _process), not carried by the body.
	rig.top_level = true
	rig.scale = Vector3.ONE * size
	place(global_position, global_rotation.y)


## The rig that animates it. A figure with moves of its own (the brother)
## returns a rig that extends CharacterRig here.
func _new_rig() -> CharacterRig:
	return CharacterRig.new()


## Sends it to `point` (its height is ignored), at a walk or a run. It goes
## straight there: it does not find its way round things.
func go_to(point: Vector3, run := false) -> void:
	_goal = point
	_going = true
	_hurry = run


## Stops it where it is.
func stop() -> void:
	_going = false


func is_going() -> bool:
	return _going


## Turns it to look towards `point`. (While it is walking it faces the way it goes.)
func face(point: Vector3) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length_squared() > 0.0001:
		facing_yaw = atan2(to.x, to.z)


## Puts it somewhere else, standing still, facing `yaw`.
func place(at: Vector3, yaw: float) -> void:
	global_position = at
	velocity = Vector3.ZERO
	_going = false
	facing_yaw = yaw
	_prev_pos = at
	_curr_pos = at
	visual_position = at
	_show()


func _physics_process(delta: float) -> void:
	var wish := Vector3.ZERO
	if _going:
		var to := _goal - global_position
		to.y = 0.0
		var distance := to.length()
		if distance < arrive_distance:
			_going = false
			arrived.emit()
		else:
			# (slowing as it comes up to the place, so as to stop on it)
			var top := run_speed if _hurry else walk_speed
			wish = to / distance * minf(top, sqrt(2.0 * acceleration * distance))
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish, acceleration * delta)
	velocity.x = current.x
	velocity.z = current.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


func _process(delta: float) -> void:
	visual_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	if heading.length_squared() > 0.01:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))
	rig.looseness = looseness
	rig.stoop = stoop
	rig.arms_reach = arms_reach
	_show()


func _show() -> void:
	if rig:
		rig.global_position = visual_position
		rig.rotation = Vector3(0.0, facing_yaw, 0.0)

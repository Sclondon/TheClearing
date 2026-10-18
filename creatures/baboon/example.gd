extends Node3D
## Baboon, on its own: an alpha mandrill and a baboon on a flat floor, run
## through everything they do, over and over. Make a scene with a Node3D, give
## it this script, and run it (or run it as the main scene's child).
##
## Each goes round a ring: walking, galloping, then stopping to sit and look
## about, barking, the threat display, and a leap at the middle and back.
## Moving them is only setting their position and Y rotation; the rest they do.

const RING := 5.0

var alpha: Baboon
var baboon: Baboon
var _time := 0.0
var _angle := {}


func _ready() -> void:
	if get_viewport().get_camera_3d() == null:
		var camera := Camera3D.new()
		camera.position = Vector3(0.0, 6.0, 12.0)
		add_child(camera)
		camera.look_at(Vector3(0.0, 0.8, 0.0))
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.9, 0.6, 0.0)
		sun.shadow_enabled = true
		add_child(sun)
		var floor := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(30.0, 30.0)
		floor.mesh = plane
		add_child(floor)
	alpha = Baboon.new()
	alpha.kind = Baboon.Kind.ALPHA
	add_child(alpha)
	baboon = Baboon.new()
	baboon.kind = Baboon.Kind.BABOON
	baboon.seed_value = 3
	add_child(baboon)
	_angle[alpha] = 0.0
	_angle[baboon] = PI


func _process(delta: float) -> void:
	_time += delta
	# A loop of 16 seconds: walk 4, gallop 4, sit 3 (a bark in it), display 2.5, leap 2.5.
	var t := fmod(_time, 16.0)
	for one: Baboon in [alpha, baboon]:
		var speed := 0.0
		one.sitting = false
		one.look_at_point = Vector3.INF
		if t < 4.0:
			speed = 1.0 * one.size
		elif t < 8.0:
			speed = 2.6 * one.size
		elif t < 11.0:
			one.sitting = true
			if absf(t - 9.5) < delta:
				one.bark()
		elif t < 13.5:
			if absf(t - 11.0) < delta * 1.5:
				one.display(2.2)
			one.look_at_point = Vector3(0.0, 1.0, 12.0)
		elif absf(t - 13.6) < delta * 1.5:
			one.leap(0.55, 0.8)
		if one.leap_stage() == Baboon.Leap.FLIGHT:
			speed = 6.0
		_angle[one] += speed / RING * delta
		var a: float = _angle[one]
		one.position = Vector3(cos(a), 0.0, sin(a)) * RING
		one.rotation.y = atan2(-sin(a), cos(a))

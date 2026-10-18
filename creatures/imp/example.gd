extends Node3D
## Imp, on its own: three imps on a flat floor by a wall, run through
## everything they do, over and over. Make a scene with a Node3D, give it this
## script, and run it (or run it as the main scene's child).
##
## Two go round a ring: walking upright, scuttling on all fours, bounding,
## then stopping to cackle, chitter and throw a tantrum, and a leap. The third
## scurries up and down the wall, clinging: its node is turned so that its Y
## is the wall's normal. Moving them is only setting their transforms.

const RING := 2.0

var walker: Imp
var runner: Imp
var climber: Imp
var _time := 0.0
var _angle := {}


func _ready() -> void:
	if get_viewport().get_camera_3d() == null:
		var camera := Camera3D.new()
		camera.position = Vector3(0.0, 2.2, 5.0)
		add_child(camera)
		camera.look_at(Vector3(0.0, 0.5, 0.0))
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.9, 0.6, 0.0)
		sun.shadow_enabled = true
		add_child(sun)
		var floor := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(20.0, 20.0)
		floor.mesh = plane
		add_child(floor)
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6.0, 4.0, 0.4)
	wall.mesh = box
	wall.position = Vector3(0.0, 2.0, -3.2)
	add_child(wall)
	walker = Imp.new()
	walker.seed_value = 1
	add_child(walker)
	runner = Imp.new()
	runner.seed_value = 2
	add_child(runner)
	climber = Imp.new()
	climber.seed_value = 3
	climber.clinging = true
	add_child(climber)
	_angle[walker] = 0.0
	_angle[runner] = PI


func _process(delta: float) -> void:
	_time += delta
	# A loop of 14 seconds: walk 3, scuttle 3, bound 2, cackle 1.5, tantrum 2.5, leap 2.
	var t := fmod(_time, 14.0)
	for one: Imp in [walker, runner]:
		var speed := 0.0
		one.look_at_point = Vector3.INF
		if t < 3.0:
			speed = 0.35
		elif t < 6.0:
			speed = 1.1
		elif t < 8.0:
			speed = 2.4
		elif t < 9.5:
			if absf(t - 8.1) < delta * 1.5:
				one.cackle()
			if absf(t - 9.3) < delta * 1.5:
				one.chitter()
		elif t < 12.0:
			if absf(t - 9.6) < delta * 1.5:
				one.tantrum(2.2)
		elif absf(t - 12.2) < delta * 1.5:
			one.leap(0.45, 0.5)
		if one.leap_stage() == Imp.Leap.FLIGHT:
			speed = 3.5
		_angle[one] += speed / RING * delta
		var a: float = _angle[one]
		one.position = Vector3(cos(a), 0.0, sin(a)) * RING
		one.rotation.y = atan2(-sin(a), cos(a))
	# The climber: up the wall's face and down again, head first both ways.
	var up := fmod(_time, 6.0) < 3.0
	var height := 0.4 + 1.6 * (fmod(_time, 3.0) / 3.0 if up else 1.0 - fmod(_time, 3.0) / 3.0)
	var face := Vector3(0.0, height, -3.0)
	var heading := Vector3.UP if up else Vector3.DOWN
	climber.global_transform = Transform3D(Basis(Vector3.BACK.cross(heading), Vector3.BACK, heading), face)

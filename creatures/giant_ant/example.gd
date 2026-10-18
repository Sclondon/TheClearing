extends Node3D
## A whole scene for the giant ants: put it on a Node3D in an empty scene and
## play. A floor, a light, a colony whose trail bends out across it, and a
## post going round in a ring: every so often the post crosses the trail and
## the alarm goes up; they come for it, seize it and are shaken off as it
## speeds up, and calm down. Now and then a dead thing (a box) is put by the
## trail for them to haul home.

var colony: AntColony
var post: MeshInstance3D
var _time := 0.0
var _thing_in := 6.0


func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(30.0), 0.0)
	add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120.0, 120.0)
	floor.mesh = plane
	add_child(floor)
	var camera := Camera3D.new()
	camera.position = Vector3(14.0, 12.0, 22.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.0, 8.0))
	colony = AntColony.new()
	colony.colony_seed = 7
	colony.set_trail(PackedVector3Array([Vector3.ZERO, Vector3(4.0, 0.0, 10.0), Vector3(-3.0, 0.0, 20.0), Vector3(2.0, 0.0, 30.0)]))
	add_child(colony)
	post = MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = 0.35
	shape.bottom_radius = 0.35
	shape.height = 1.7
	post.mesh = shape
	add_child(post)


func _process(delta: float) -> void:
	_time += delta
	# (round a ring that crosses the trail; faster for a while after each crossing)
	var fast := 1.0 + 1.6 * float(colony.on_target > 0 and fmod(_time, 12.0) > 8.0)
	var a := _time * 0.12 * fast
	var at := Vector3(cos(a) * 9.0, 0.0, 14.0 + sin(a) * 9.0)
	var was := post.position
	post.position = at + Vector3.UP * 0.85
	var on := colony.off_trail(at)
	if on.x < 1.0 and not colony.alarm_up:
		colony.alarm(at)
	if colony.alarm_up:
		colony.target = at
		colony.target_moving = (post.position - was) / maxf(delta, 0.001)
		if colony.alarmed_count() > 0 and colony.gap > 14.0:
			colony.calm()
	_thing_in -= delta
	if _thing_in <= 0.0 and colony.carrying() == null:
		_thing_in = 30.0
		var box := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3(1.2, 0.4, 0.7)
		box.mesh = cube
		add_child(box)
		box.global_position = colony.trail_point(colony.trail_length() * 0.7, 3.0)
		colony.carry(box)

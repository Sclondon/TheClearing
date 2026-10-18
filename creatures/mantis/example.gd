extends Node3D
## A whole scene for the giant mantis: put it on a Node3D in an empty scene and
## play. A floor, a light, a mantis, and a post going round it in a ring that
## comes in close and goes out again: its head follows the post, it makes its
## threat display when the post stops in front of it, strikes when the post
## comes within its reach, and now and then walks a few steps and eats.

var mantis: GiantMantis
var post: MeshInstance3D
var _time := 0.0
var _struck_in := 0.0


func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(30.0), 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	floor.mesh = plane
	add_child(floor)
	var camera := Camera3D.new()
	camera.position = Vector3(7.0, 3.0, 8.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.6, 0.0))
	mantis = GiantMantis.new()
	add_child(mantis)
	mantis.settle()
	post = MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = 0.3
	shape.bottom_radius = 0.3
	shape.height = 1.6
	post.mesh = shape
	add_child(post)


func _process(delta: float) -> void:
	_time += delta
	_struck_in -= delta
	# (round a ring that swings in close in front of it every twenty seconds)
	var a := _time * 0.3
	var far := 5.5 - 3.2 * maxf(sin(_time * 0.31), 0.0)
	post.position = Vector3(sin(a) * far, 0.8, cos(a) * far)
	mantis.look_at_point = post.position + Vector3.UP * 0.6
	var to := post.position - mantis.position
	to.y = 0.0
	var ahead := Vector3(sin(mantis.rotation.y), 0.0, cos(mantis.rotation.y))
	mantis.display = to.length() < 6.0 and ahead.dot(to.normalized()) > 0.9 and fmod(_time, 20.0) > 14.0
	if to.length() < 3.0 and ahead.dot(to.normalized()) > 0.6 and _struck_in <= 0.0:
		mantis.strike(post.position + Vector3.UP * 0.4)
		_struck_in = 2.0
	# (it turns slowly to the post, and now and then walks a few steps, or eats)
	mantis.rotation.y = rotate_toward(mantis.rotation.y, atan2(to.x, to.z), 0.6 * delta)
	if fmod(_time, 30.0) < 3.0:
		mantis.position += ahead * 0.5 * delta
	mantis.eating = fmod(_time, 30.0) > 26.0

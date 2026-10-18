extends Node3D
## ImpSwarm, on its own: a floor, two walls, a crack at the foot of one, and a
## post going round in a ring for them to chase. Every 16 seconds they are let
## out after it, pour along the floor and up the walls, and are called home
## again. Make a scene with a Node3D, give it this script, and run it.

var swarm: ImpSwarm
var post: Node3D
var _time := 0.0


func _ready() -> void:
	if get_viewport().get_camera_3d() == null:
		var camera := Camera3D.new()
		camera.position = Vector3(0.0, 7.0, 12.0)
		add_child(camera)
		camera.look_at(Vector3(0.0, 0.5, 0.0))
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.9, 0.6, 0.0)
		add_child(sun)
	_box(Vector3(30.0, 1.0, 30.0), Vector3(0.0, -0.5, 0.0))
	_box(Vector3(20.0, 5.0, 1.0), Vector3(0.0, 2.5, -6.0))
	_box(Vector3(1.0, 5.0, 12.0), Vector3(-7.0, 2.5, 0.0))
	post = Node3D.new()
	add_child(post)
	swarm = ImpSwarm.new()
	swarm.count = 40
	swarm.position = Vector3(3.0, 0.0, -5.2)
	add_child(swarm)
	swarm.target = post


func _box(size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var drawn := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	drawn.mesh = mesh
	body.add_child(drawn)
	body.position = at
	add_child(body)


func _physics_process(delta: float) -> void:
	_time += delta
	var t := fmod(_time, 16.0)
	var a := _time * 0.5
	post.position = Vector3(cos(a) * 4.0, 0.0, sin(a) * 3.0)
	if t < delta * 1.5:
		swarm.release()
	elif absf(t - 12.0) < delta * 0.75:
		swarm.recall()

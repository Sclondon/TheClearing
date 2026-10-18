extends Node3D
## An example of the brachiosaurus (Brachiosaurus): put this script on a Node3D
## in an empty scene and run it. A brachiosaurus on a flat floor walks round a
## wide circle (the spots of its foot shadows showing where each foot will come
## down), stops to browse high up, looks down at a post at its feet, bellows,
## and walks on, over and over.

var brach: Brachiosaurus
var post: MeshInstance3D
var _time := 0.0
var _act := -1
var _speed := 0.0

const ACTS := [["walk", 10.0], ["browse", 8.0], ["look down", 6.0], ["bellow", 4.0], ["fast", 6.0]]


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.6, 0.62, 0.64)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	environment.ambient_light_energy = 0.4
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(35.0), 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	floor.mesh = plane
	add_child(floor)
	var camera := Camera3D.new()
	camera.position = Vector3(70.0, 18.0, 70.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 6.0, 0.0))
	brach = Brachiosaurus.new()
	brach.foot_shadows = true
	brach.position = Vector3(0.0, 0.0, 40.0)
	add_child(brach)
	post = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 1.6, 0.4)
	post.mesh = box
	add_child(post)


func _process(delta: float) -> void:
	_time += delta
	var total := 0.0
	for act: Array in ACTS:
		total += act[1]
	var t := fposmod(_time, total)
	var index := 0
	while t > ACTS[index][1]:
		t -= ACTS[index][1]
		index += 1
	var act: String = ACTS[index][0]
	if index != _act:
		_act = index
		var ahead := brach.global_basis.z.normalized()
		var left := brach.global_basis.x.normalized()
		brach.browse_point = brach.global_position + left * 5.0 + ahead * 9.0 + Vector3.UP * 13.5 if act == "browse" else Vector3.INF
		post.global_position = brach.global_position + ahead * 7.0 + left * 3.0 + Vector3.UP * 0.8
		brach.look_at_point = post.global_position if act == "look down" else Vector3.INF
		if act == "bellow":
			brach.bellow()
	var want: float = {"walk": 1.1, "fast": 2.3}.get(act, 0.0)
	_speed = move_toward(_speed, want, 0.5 * delta)
	var radius := 40.0
	var around := atan2(brach.position.x, brach.position.z) + _speed / radius * delta
	brach.position = Vector3(sin(around), 0.0, cos(around)) * radius
	brach.rotation.y = around + PI * 0.5

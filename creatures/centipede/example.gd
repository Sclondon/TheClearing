extends Node3D
## CentipedeBody's example: a flat floor with one wall, a light, a camera, and
## a centipede that runs round and round a loop past the wall, now and then
## stops, rears to look about, and strikes at a post. Attach this to a Node3D
## in an empty scene and run it (or, headless: --script with a SceneTree that
## adds it). Nothing here belongs to any game.

var centipede: CentipedeBody
var post: MeshInstance3D
var _time := 0.0
var _round := 0.0
var _resting := 0.0
var _struck := false


func _ready() -> void:
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80.0, 1.0, 80.0)
	floor_shape.shape = box
	floor_shape.position.y = -0.5
	floor_body.add_child(floor_shape)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	floor_mesh.mesh = plane
	floor_body.add_child(floor_mesh)
	add_child(floor_body)
	# A wall it runs along the foot of.
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(1.0, 6.0, 30.0)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	var wall_mesh := MeshInstance3D.new()
	var wall_cube := BoxMesh.new()
	wall_cube.size = wall_box.size
	wall_mesh.mesh = wall_cube
	wall.add_child(wall_mesh)
	wall.position = Vector3(-12.2, 3.0, 0.0)
	add_child(wall)
	post = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.3
	cylinder.bottom_radius = 0.3
	cylinder.height = 1.6
	post.mesh = cylinder
	post.position = Vector3(0.0, 0.8, 0.0)
	add_child(post)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.7, 0.72, 0.74)
	environment.environment.ambient_light_color = Color(0.5, 0.52, 0.55)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(environment)
	var camera := Camera3D.new()
	camera.position = Vector3(18.0, 16.0, 18.0)
	add_child(camera)
	camera.look_at(Vector3.ZERO)

	centipede = CentipedeBody.new()
	add_child(centipede)
	centipede.global_position = Vector3(10.0, 0.0, 0.0)
	centipede.lay_coil()


func _process(delta: float) -> void:
	_time += delta
	if _resting > 0.0:
		# Stopped: reared, looking about, and then the strike at the post.
		_resting -= delta
		centipede.aim = post.global_position
		if _resting < 2.5 and not _struck:
			_struck = true
			centipede.strike(post.global_position)
		if _resting <= 0.0:
			centipede.rear(0.0)
			centipede.look_about = false
			centipede.aim = Vector3.INF
		return
	# Round a loop of 10 m, past the wall, at 5 m/s.
	_round += delta * 5.0 / 10.0
	var at := Vector3(cos(_round) * 10.0, 0.0, sin(_round) * 10.0)
	var ahead := Vector3(-sin(_round), 0.0, cos(_round))
	centipede.global_transform = Transform3D(Basis.looking_at(-ahead), at)
	if fmod(_round, TAU) < delta * 0.5 and _time > 2.0:
		_resting = 5.0
		_struck = false
		centipede.rear(0.8)
		centipede.look_about = true

extends Node3D
## The tripod going through everything it does, on open ground with a wall to
## light and burn: put this on a Node3D in an empty scene and play it. It
## strides round a wide circle, its searchlight sweeping ahead of it; every
## half minute it stops, sounds its horn, charges its heat ray and burns a line
## across the ground, then reaches down with its grasper, and walks on.

var tripod: Tripod
var camera: Camera3D
var _time := 0.0
var _round := 0.0


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.65, 0.66)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.63, 0.64)
	environment.ambient_light_energy = 0.6
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.66, 0.7, 0.69)
	environment.fog_density = 0.003
	environment.glow_enabled = true
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, 25.0, 0.0)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	add_child(sun)
	# Ground and a wall, solid (it stands on them, lights and burns them)
	var ground := StaticBody3D.new()
	var plane := CollisionShape3D.new()
	plane.shape = WorldBoundaryShape3D.new()
	ground.add_child(plane)
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(800.0, 800.0)
	floor.mesh = floor_mesh
	ground.add_child(floor)
	add_child(ground)
	var wall := StaticBody3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10.0, 34.0, 80.0)
	var wall_shape := CollisionShape3D.new()
	wall_shape.shape = box
	wall.add_child(wall_shape)
	var wall_mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = box.size
	wall_mesh.mesh = cube
	wall.add_child(wall_mesh)
	wall.position = Vector3(0.0, 17.0, 0.0)
	add_child(wall)

	tripod = Tripod.new()
	tripod.position = Vector3(60.0, 0.0, 0.0)
	add_child(tripod)
	camera = Camera3D.new()
	camera.far = 1000.0
	camera.fov = 60.0
	add_child(camera)
	camera.current = true


func _physics_process(delta: float) -> void:
	_time += delta
	var cycle := fmod(_time, 30.0)
	if cycle < 18.0:
		# Striding round, its light sweeping the ground ahead
		tripod.firing = false
		tripod.charge = 0.0
		tripod.arm_target = Vector3.INF
		tripod.reach_target = Vector3.INF
		_round += delta * Tripod.WALK_SPEED * 0.8 * (1.0 - tripod.strain) / 60.0
		tripod.position = Vector3(cos(_round), 0.0, sin(_round)) * 60.0
		tripod.rotation.y = atan2(-sin(_round), cos(_round))
		var ahead := tripod.global_basis.z
		tripod.beam_target = tripod.position + ahead * 40.0 + tripod.global_basis.x * 14.0 * sin(_time * 0.5)
	elif cycle < 19.0:
		if cycle - delta < 18.0:
			tripod.horn()
	elif cycle < 22.0:
		# Charging, aimed at the foot of the wall
		var target := Vector3(6.0, 0.0, -20.0 + (cycle - 19.0) * 2.0)
		tripod.beam_target = target
		tripod.arm_target = target
		tripod.charge = (cycle - 19.0) / 3.0
	elif cycle < 25.0:
		# Burning a line along the wall
		tripod.firing = true
		tripod.arm_target = Vector3(6.0, 0.0, -14.0 + (cycle - 22.0) * 9.0)
	else:
		# Its grasper reaching down in front of it
		tripod.firing = false
		tripod.charge = 0.0
		tripod.arm_target = Vector3.INF
		tripod.reach_target = tripod.position + tripod.global_basis.z * 10.0 + Vector3.UP * 1.0
	# The camera stands on the ground a way off, looking up at it
	var at := tripod.position + Vector3(70.0, 2.0, 70.0)
	camera.global_position = at
	camera.look_at(tripod.body_point() - Vector3.UP * 15.0, Vector3.UP)

extends Node3D
## AlienBody on a flat floor, going through everything it does, over and over:
## it walks a square, stops and watches a red post that wanders about, raises
## its hand at it and shines, then shows where it is going, blinks out and
## comes back there. Put this on a Node3D in an empty scene and run it.

var alien: AlienBody
var post: MeshInstance3D
var _camera: Camera3D
var _time := 0.0


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.6, 0.62, 0.63)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.57, 0.6)
	environment.ambient_light_energy = 0.4
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	ground.mesh = plane
	add_child(ground)
	post = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 1.4
	post.mesh = capsule
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.6, 0.12, 0.1)
	post.material_override = red
	add_child(post)
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.position = Vector3(0.0, 6.0, 15.0)
	_camera.look_at(Vector3(0.0, 0.8, 0.5))
	alien = AlienBody.new()
	add_child(alien)
	_loop()


func _process(delta: float) -> void:
	_time += delta
	post.position = Vector3(sin(_time * 0.4) * 4.0, 0.7, 3.0 + cos(_time * 0.3) * 1.5)


## Each thing it does in turn, for ever.
func _loop() -> void:
	var corners := [Vector3(-3, 0, -3), Vector3(3, 0, -3), Vector3(3, 0, 2), Vector3(-3, 0, 2)]
	while is_inside_tree():
		# Walk a square (the node is moved; the body walks to match).
		alien.look_at_point = Vector3.INF
		for corner: Vector3 in corners:
			await _walk_to(corner, 1.2)
		# Stand and watch the post.
		alien.look_at_point = post.position + Vector3.UP * 0.5
		await _for(3.0, func() -> void: alien.look_at_point = post.position + Vector3.UP * 0.5)
		# Turn to it, raise a hand, shine.
		await _turn_to(post.position, 0.8)
		alien.reach(post.position)
		await _for(AlienBody.REACH_RAISE, func() -> void: alien.reach_aim = post.position)
		await _for(AlienBody.REACH_GRAB + AlienBody.REACH_LOWER, func() -> void:
			if alien.in_beam(post.position):
				post.material_override.albedo_color = Color(0.9, 0.9, 1.0)
			else:
				post.material_override.albedo_color = Color(0.6, 0.12, 0.1))
		post.material_override.albedo_color = Color(0.6, 0.12, 0.1)
		# Show where it is going, go, and come back there.
		var there := Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-3.0, 1.0))
		alien.shimmer(there, 1.2)
		await _for(1.2)
		alien.blink_out()
		await _for(AlienBody.BLINK_OUT + 0.2)
		alien.blink_in(there, atan2(post.position.x - there.x, post.position.z - there.z))
		await _for(AlienBody.BLINK_IN + 1.0)


func _walk_to(goal: Vector3, speed: float) -> void:
	while is_inside_tree():
		var to := goal - alien.global_position
		to.y = 0.0
		if to.length() < 0.1:
			return
		var delta := get_process_delta_time()
		alien.rotation.y = lerp_angle(alien.rotation.y, atan2(to.x, to.z), 1.0 - exp(-3.0 * delta))
		alien.global_position += to.normalized() * minf(speed * delta, to.length())
		await get_tree().process_frame


func _turn_to(at: Vector3, seconds: float) -> void:
	var to := at - alien.global_position
	await _for(seconds, func() -> void:
		alien.rotation.y = lerp_angle(alien.rotation.y, atan2(to.x, to.z), 1.0 - exp(-4.0 * get_process_delta_time())))


## Waits `seconds`, calling `each` every frame meanwhile.
func _for(seconds: float, each := Callable()) -> void:
	var left := seconds
	while left > 0.0 and is_inside_tree():
		if each.is_valid():
			each.call()
		await get_tree().process_frame
		left -= get_process_delta_time()

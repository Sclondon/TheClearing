extends Node3D
## A slime wall going up and down a walled passage that narrows to a gap at
## one end, and a stand-in (a capsule) walking into it every so often, to be
## held in it and let go. Attach to a Node3D in an empty scene and run it.
## Needs nothing but creatures/slime_wall/.

var slime: SlimeWall
var victim: MeshInstance3D
var _going := -1.0
var _next_victim := 3.0


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.7, 0.73, 0.72)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.77, 0.76)
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.66, 0.7, 0.69)
	environment.fog_density = 0.01
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	_block(Vector3(0, -0.5, -10), Vector3(40, 1, 80), Color(0.4, 0.4, 0.37))
	# A passage 10 m wide, narrowing to a 4 m gap at its far end.
	for side in [-1.0, 1.0]:
		_block(Vector3(side * 5.5, 2.5, 0), Vector3(1, 5, 40), Color(0.55, 0.55, 0.52))
		_block(Vector3(side * 2.5, 2.5, -27), Vector3(1, 5, 14), Color(0.55, 0.55, 0.52))
		_block(Vector3(side * 4.0, 2.5, -20.5), Vector3(3, 5, 1), Color(0.55, 0.55, 0.52))
	slime = SlimeWall.new()
	slime.height = 6.0
	add_child(slime)
	slime.global_position = Vector3(0, 0, 12)
	slime.rotation.y = PI
	slime.settle()
	slime.released.connect(func(node: Node3D) -> void: node.queue_free())
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 12, 27)
	camera.look_at(Vector3(0, 2, 2))
	camera.fov = 65.0


func _block(at: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	body.add_child(mesh)


func _process(delta: float) -> void:
	# Up and down the passage, into the gap and back, at a crawl.
	slime.global_position.z += _going * 1.3 * delta
	if slime.global_position.z < -26.0:
		_going = 1.0
		slime.rotation.y = 0.0
	elif slime.global_position.z > 14.0:
		_going = -1.0
		slime.rotation.y = PI
	# Now and then something walks into it.
	_next_victim -= delta
	if _next_victim <= 0.0 and victim == null:
		_next_victim = 9.0
		victim = MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.3
		capsule.height = 1.4
		victim.mesh = capsule
		var red := StandardMaterial3D.new()
		red.albedo_color = Color(0.7, 0.12, 0.1)
		victim.material_override = red
		add_child(victim)
		victim.global_position = slime.global_position + Vector3(randf_range(-3, 3), 0.7, _going * 8.0)
	if victim and is_instance_valid(victim) and not slime.holding(victim):
		var to := slime.global_position - victim.global_position
		to.y = 0.0
		victim.global_position += to.normalized() * 1.6 * delta
		if slime.contains(victim.global_position, 0.1):
			slime.hold(victim, 2.5)
	slime.aim = victim.global_position if victim and is_instance_valid(victim) else Vector3.INF

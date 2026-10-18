extends Node3D
## A Gargoyle going through everything it does, over and over: a statue on a
## block of stone; it wakes (the ember in its cracks, its head turning to a red
## post), drops off in a long glide onto the post (its shadow where it will
## land), lands with a crash, turns to stone for a while, bounds round in a
## ring, winds up and leaps, then beats its way back up onto the block and is a
## statue again. Put this on a Node3D in an empty scene and run it.

const BLOCK := Vector3(0.0, 6.0, -6.0)

var gargoyle: Gargoyle
var post: MeshInstance3D
var _camera: Camera3D
var _time := 0.0
var _from := Vector3.ZERO


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.64, 0.65)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.62, 0.64)
	environment.ambient_light_energy = 0.6
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.62, 0.64, 0.65)
	environment.fog_density = 0.01
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.42, 0.42, 0.4)
	stone.roughness = 0.95
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	ground.mesh = plane
	ground.material_override = stone
	add_child(ground)
	var block := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4.0, BLOCK.y, 3.0)
	block.mesh = box
	block.material_override = stone
	block.position = Vector3(BLOCK.x, BLOCK.y * 0.5, BLOCK.z - 1.0)
	add_child(block)
	post = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 1.3
	post.mesh = capsule
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.6, 0.12, 0.1)
	post.material_override = red
	add_child(post)
	gargoyle = Gargoyle.new()
	add_child(gargoyle)
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.position = Vector3(9.0, 3.5, 9.0)
	_camera.look_at(Vector3(0.0, 2.0, -1.0))
	_restart()


func _restart() -> void:
	_time = 0.0
	gargoyle.global_position = BLOCK
	gargoyle.rotation.y = 0.0
	gargoyle.perched = true
	gargoyle.alive = false
	gargoyle.airborne = false
	gargoyle.reaching = 0.0
	gargoyle.settle()


func _process(delta: float) -> void:
	_time += delta
	var t := _time
	# The post wanders about in front of the block.
	post.position = Vector3(sin(_time * 0.3) * 3.0, 0.65, 3.0 + cos(_time * 0.21) * 1.5)
	var target := post.position + Vector3.UP * 0.5
	if t < 2.0:
		return  # a statue
	if t < 3.4:
		# Waking: alive, its head grinding round to the post.
		if not gargoyle.alive:
			gargoyle.alive = true
			gargoyle.snarl()
			_from = gargoyle.global_position
		gargoyle.aim = target
		return
	if t < 5.6:
		# The drop: a long glide down onto where the post is.
		var k := (t - 3.4) / 2.2
		gargoyle.perched = false
		gargoyle.airborne = true
		gargoyle.flapping = 0.6 if k < 0.15 else 0.0
		gargoyle.reaching = smoothstep(0.35, 0.8, k)
		var land := Vector3(post.position.x, 0.0, post.position.z)
		var at := _from.lerp(land, 1.0 - pow(1.0 - k, 1.6))
		at.y = lerpf(_from.y, 0.0, k * k) + 0.8 * 4.0 * k * (1.0 - k)
		gargoyle.global_position = at
		gargoyle.rotation.y = atan2(land.x - _from.x, land.z - _from.z)
		gargoyle.show_shadow(land, 0.35 + 0.65 * k)
		return
	if t < 9.6:
		# Landed: a crash, then stone for a while.
		if gargoyle.airborne:
			gargoyle.airborne = false
			gargoyle.reaching = 0.0
			gargoyle.global_position.y = 0.0
			gargoyle.show_shadow(Vector3.INF)
			gargoyle.slam()
		gargoyle.alive = t < 6.0
		gargoyle.aim = Vector3.INF
		return
	if t < 15.0:
		# Alive again: heavy bounds round a ring.
		gargoyle.alive = true
		var angle := (t - 9.6) * 0.75
		gargoyle.global_position = Vector3(cos(angle) * 4.5, 0.0, 2.0 + sin(angle) * 4.5)
		gargoyle.rotation.y = atan2(-sin(angle), cos(angle))
		gargoyle.aim = target
		return
	if t < 15.9:
		if not gargoyle.gathering():
			gargoyle.gather(0.8)
		return
	if t < 16.8:
		# The leap.
		var k := (t - 15.9) / 0.9
		gargoyle.airborne = true
		gargoyle.reaching = 1.0
		var ahead := gargoyle.global_basis.z
		gargoyle.global_position += ahead * 7.0 * get_process_delta_time()
		gargoyle.global_position.y = 2.0 * 4.0 * k * (1.0 - k)
		return
	if t < 17.6:
		if gargoyle.airborne:
			gargoyle.airborne = false
			gargoyle.reaching = 0.0
			gargoyle.global_position.y = 0.0
			gargoyle.slam()
			_from = gargoyle.global_position
		return
	if t < 20.6:
		# Beating its way back up onto the block.
		var k := (t - 17.6) / 3.0
		gargoyle.airborne = true
		gargoyle.flapping = 1.0
		var above := Vector3(_from.x, lerpf(_from.y, BLOCK.y + 1.2, smoothstep(0.0, 0.7, k)), _from.z)
		gargoyle.global_position = above.lerp(BLOCK, smoothstep(0.6, 1.0, k))
		gargoyle.rotation.y = lerp_angle(gargoyle.rotation.y, 0.0, 0.05)
		return
	_restart()

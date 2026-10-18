extends Node3D
## The harpy on its own: put this on a Node3D in an empty scene and run it.
## A stone block to perch on and a post for a target, and the harpy going round
## everything it does, over and over: perched (wings folded, then mantled),
## screeching, taking off, circling high over the post, stooping, swooping down
## at the post talons first, climbing away, and coming back to land on its block.

const PERCH := Vector3(0.0, 4.0, 0.0)
const TARGET := Vector3(0.0, 0.0, 16.0)

var harpy: Harpy
var _t := 0.0
var _screamed := false
var _cried := false
var _from := Vector3.ZERO


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.62, 0.64)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.64, 0.66)
	env.fog_density = 0.01
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)
	sun.look_at_from_position(Vector3(4, 10, 6), Vector3.ZERO)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	var block := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.0, PERCH.y, 3.0)
	block.mesh = box
	block.position = Vector3(0.0, PERCH.y * 0.5, -0.8)
	add_child(block)
	var post := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.height = 1.3
	cylinder.top_radius = 0.2
	cylinder.bottom_radius = 0.2
	post.mesh = cylinder
	post.position = TARGET + Vector3.UP * 0.65
	add_child(post)
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(Vector3(14, 6, 6), Vector3(0, 4, 8))
	harpy = Harpy.new()
	add_child(harpy)
	harpy.global_position = PERCH + Vector3.UP * harpy.stand_height()
	harpy.settle()


func _process(delta: float) -> void:
	_t += delta
	var cycle := fmod(_t, 26.0)
	var perch := PERCH + Vector3.UP * harpy.stand_height()
	harpy.aim = TARGET + Vector3.UP
	harpy.stoop = 0.0
	harpy.talons = 0.0
	harpy.brake = 0.0
	harpy.grip = 0.0
	if cycle < 6.0:
		# Perched: folded, then mantled; screeching at the end.
		_screamed = _screamed and cycle > 1.0
		_cried = false
		harpy.perched = true
		harpy.grip = 1.0
		harpy.mantle = 0.0 if cycle < 2.5 else 1.0
		harpy.global_position = perch
		harpy.rotation.y = 0.0
		if cycle > 3.8 and not _screamed:
			_screamed = true
			harpy.screech()
	elif cycle < 9.0:
		# Up off the block, beating hard.
		var u := (cycle - 6.0) / 3.0
		harpy.perched = false
		harpy.effort = 1.0
		harpy.brake = 0.4 * (1.0 - u)
		harpy.global_position = perch + Vector3(0.0, u * 12.0, u * 4.0)
	elif cycle < 15.0:
		# Circling over the post, gliding with a few beats.
		var a := (cycle - 9.0) * 0.8
		harpy.effort = 0.3 if fmod(cycle, 3.0) < 1.0 else 0.0
		var at := TARGET + Vector3(sin(a) * 10.0, 16.0, cos(a) * 10.0 - 4.0)
		_turn_to(at - harpy.global_position)
		harpy.global_position = harpy.global_position.lerp(at, 1.0 - exp(-3.0 * delta))
		_from = harpy.global_position
	elif cycle < 18.0:
		# The stoop and the swoop: down and in at the post, talons forward at the end.
		if not _cried:
			_cried = true
			harpy.cry()
		var u := (cycle - 15.0) / 3.0
		var low := TARGET + Vector3(0.0, 1.5, -14.0)
		var end := TARGET + Vector3(0.0, 1.6, 0.0)
		var at := _from * (1.0 - u) * (1.0 - u) + low * 2.0 * u * (1.0 - u) + end * u * u
		_turn_to(at - harpy.global_position)
		harpy.global_position = at
		harpy.stoop = 1.0 if u < 0.75 else 0.0
		harpy.talons = 1.0 if u >= 0.75 else 0.0
		harpy.effort = 0.0
	elif cycle < 21.0:
		# Climbing away.
		harpy.effort = 1.0
		harpy.grip = 1.0
		harpy.global_position += Vector3(0.0, 5.0, 2.0) * delta
	else:
		# Back to the block and down on it, braking, talons forward.
		var u := clampf((cycle - 21.0) / 5.0, 0.0, 1.0)
		var e := u * u * (3.0 - 2.0 * u)
		harpy.effort = 0.5
		harpy.brake = smoothstep(0.5, 1.0, u)
		harpy.talons = smoothstep(0.6, 1.0, u)
		var at := harpy.global_position.lerp(perch + Vector3(0.0, 0.0, 0.5 * (1.0 - e)), e * 0.2 + 0.02)
		_turn_to(perch - harpy.global_position)
		harpy.global_position = at


func _turn_to(way: Vector3) -> void:
	way.y = 0.0
	if way.length() > 0.05:
		harpy.rotation.y = lerp_angle(harpy.rotation.y, atan2(way.x, way.z), 0.1)

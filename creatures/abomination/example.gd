extends Node3D
## MeatAbomination, on its own: a flat floor, an overcast light, a stand-in for
## a person (a grey capsule), and a pair of walls that close in to a gap. It
## creeps round a loop through the gap (squeezing to get through), feels for
## the stand-in, and lashes at it whenever it is in reach. Run this script's
## scene, or add it to an empty scene as the root's script.
##
## What it shows of the API: moving the node (it works out its own speed),
## `aim`, `measure_room` against the walls, `lash`, `lash_stage`, `lash_hits`
## and `touches`.

var meat: MeatAbomination
var stand_in: MeshInstance3D
var _time := 0.0
var _caught := 0.0


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.7, 0.73, 0.72)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.65, 0.66)
	environment.ambient_light_energy = 0.8
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.68, 0.71, 0.7)
	environment.fog_density = 0.006
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, 30.0, 0.0)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	add_child(sun)
	_box(Vector3(0, -0.5, 0), Vector3(120, 1, 120), Color(0.36, 0.35, 0.33))
	# Two walls with a gap 5 m wide between them, across its loop.
	_box(Vector3(-9.5, 6, 0), Vector3(14, 12, 4), Color(0.5, 0.5, 0.49))
	_box(Vector3(9.5, 6, 0), Vector3(14, 12, 4), Color(0.5, 0.5, 0.49))
	stand_in = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	stand_in.mesh = capsule
	add_child(stand_in)
	meat = MeatAbomination.new()
	add_child(meat)
	var camera := Camera3D.new()
	camera.position = Vector3(26, 18, 26)
	add_child(camera)
	camera.look_at(Vector3(0, 2, 0))


func _box(at: Vector3, size: Vector3, colour: Color) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	mesh.material_override = material
	body.add_child(mesh)
	add_child(body)


func _process(delta: float) -> void:
	_time += delta
	# Round a long loop through the gap, at a slow walk.
	var angle := _time * 0.09
	var at := Vector3(sin(angle * 2.0) * 1.2, 0.0, cos(angle) * 22.0)
	var ahead := Vector3(sin((angle + 0.01) * 2.0) * 1.2, 0.0, cos(angle + 0.01) * 22.0)
	meat.global_position = at
	meat.rotation.y = atan2(-(ahead.x - at.x), -(ahead.z - at.z))
	# The stand-in paces beside its path.
	stand_in.position = Vector3(sin(_time * 0.3) * 14.0, 0.85, cos(_time * 0.21) * 14.0)
	meat.aim = stand_in.position
	if stand_in.position.distance_to(at) < meat.lash_reach + 4.0:
		meat.lash(stand_in.position)
	var feet := stand_in.position + Vector3.DOWN * 0.85
	if meat.lash_hits(feet, feet + Vector3.UP * 1.7, 0.3) or meat.touches(stand_in.position, 0.3):
		_caught = 0.5
	_caught -= delta
	var material := StandardMaterial3D.new() if stand_in.material_override == null else stand_in.material_override as StandardMaterial3D
	material.albedo_color = Color(0.8, 0.15, 0.1) if _caught > 0.0 else Color(0.55, 0.55, 0.55)
	stand_in.material_override = material

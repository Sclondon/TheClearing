extends Node3D
## The least a level needs for the mushrooms, and what the component is tested
## with: a wall on a flat floor under a grey sky, mushrooms grown along its foot
## and up it (tufts of honey fungus, shelves of brackets, glowing bonnets) and
## three puffballs, and a post (the stand-in for someone) that walks up to each
## puffball in turn: it puffs, and its cloud of spores billows out. Every so
## often the light goes down, and the bonnets glow. Make a scene with a Node3D
## carrying this script and run it; the camera turns slowly round.

var patch: MushroomPatch
var cloud: SporeCloud
var post: MeshInstance3D
var camera: Camera3D
var sun: DirectionalLight3D
var environment: Environment
## Set to stop the camera and the post moving (a tool that places them itself).
var still := false
var _time := 0.0
var _target := 0


func _ready() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.64, 0.66)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.72, 0.75)
	environment.ambient_light_energy = 0.55
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.66, 0.68, 0.7)
	environment.fog_density = 0.02
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0.0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	floor_mesh.mesh = plane
	floor_mesh.material_override = Toon.surface(Color(0.4, 0.38, 0.34))
	add_child(floor_mesh)
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(14.0, 8.0, 1.0)
	wall.mesh = box
	wall.material_override = Toon.surface(Color(0.55, 0.55, 0.53))
	wall.position = Vector3(0.0, 4.0, -3.5)
	add_child(wall)

	patch = MushroomPatch.new()
	add_child(patch)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for k in 9:
		var foot := Vector3(-6.0 + k * 1.5 + rng.randf_range(-0.4, 0.4), 0.0, -3.0)
		match k % 3:
			0:
				patch.tuft(foot + Vector3(0.0, 0.0, rng.randf_range(0.1, 0.5)), rng, rng.randf_range(2.5, 4.5))
			1:
				patch.shelves(foot, Vector3.BACK, rng, 3.0, 2.5)
			2:
				patch.bonnets(foot + Vector3(0.0, 0.0, 0.4), rng)
	for x in [-3.0, 0.5, 3.5]:
		patch.add_puffball(Vector3(x, 0.0, 0.5 + absf(x) * 0.2), 1.8)
	patch.build()
	cloud = SporeCloud.new()
	add_child(cloud)
	patch.puffed.connect(func(at: Vector3, size: float) -> void: cloud.puff(at, size / 1.6))

	post = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 1.25
	post.mesh = capsule
	post.material_override = Toon.surface(Color(0.6, 0.15, 0.12))
	post.position = Vector3(-3.0, 0.62, 5.0)
	add_child(post)
	camera = Camera3D.new()
	camera.fov = 45.0
	add_child(camera)


## Light (1) to dark (0): the sun and the sky go down, and the bonnets glow.
func set_daylight(value: float) -> void:
	sun.light_energy = 0.8 * value
	environment.ambient_light_energy = lerpf(0.12, 0.55, value)
	environment.background_color = Color(0.62, 0.64, 0.66) * lerpf(0.15, 1.0, value)
	environment.fog_light_color = Color(0.66, 0.68, 0.7) * lerpf(0.15, 1.0, value)
	MushroomLook.set_night(1.0 - value)


func _process(delta: float) -> void:
	if still:
		return
	_time += delta
	var round_about := _time * 0.12
	camera.position = Vector3(sin(round_about) * 10.0, 3.0, cos(round_about) * 10.0 + 1.0)
	camera.look_at(Vector3(0.0, 0.8, -1.0))
	set_daylight(0.5 + 0.5 * cos(_time * 0.2))
	var goal := patch.puffballs[_target]
	post.position = post.position.move_toward(Vector3(goal.x, 0.62, goal.z + 0.9), delta * 1.2)
	if Vector2(post.position.x - goal.x, post.position.z - goal.z - 0.9).length() < 0.05:
		patch.puff(_target)
		patch.regrow(_target, 12.0)
		_target = (_target + 1) % patch.puffballs.size()

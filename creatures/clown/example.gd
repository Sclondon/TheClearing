extends Node3D
## The least a level needs for `Clown`, and what the component is tested with:
## one on a flat floor under a grey sky, going round a loop. He creeps towards
## a post (the stand-in for a player), freezes now and then as if it had turned
## to look at him, creeps on, giggles, sprints at it in his flailing stop-motion
## run, stands winded, and creeps back to where he began. Make a scene with a
## Node3D carrying this script and run it; drag nothing, it all goes by itself.
## The camera turns slowly round.
##
## Needs GameCommon's character-controller installed too (the rig is built on it).

## How big he is drawn (he is modelled about 1.5 units tall).
const SIZE := 1.55
## His creep and his sprint, world units a second.
const CREEP := 2.2
const SPRINT := 7.5

var clown: Clown
var post: MeshInstance3D
var camera: Camera3D
## Set to stop the camera moving (a test that places it itself).
var still_camera := false
## What he is doing in the loop (for a test to read).
var step := "creep"
var _time := 0.0
var _step_time := 0.0
var _home := Vector3(0.0, 0.0, -9.0)


func _ready() -> void:
	var environment := Environment.new()
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
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0.0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	floor_mesh.mesh = plane
	floor_mesh.material_override = Toon.surface(Color(0.45, 0.44, 0.42))
	add_child(floor_mesh)

	post = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	post.mesh = capsule
	post.material_override = Toon.surface(Color(0.5, 0.14, 0.11))
	post.position = Vector3(0.0, 0.8, 6.0)
	add_child(post)

	clown = Clown.new()
	clown.scale = Vector3.ONE * SIZE
	clown.balloon_height = 7.0
	add_child(clown)
	clown.put(_home, 0.0)

	camera = Camera3D.new()
	camera.fov = 45.0
	add_child(camera)


func _process(delta: float) -> void:
	_time += delta
	_step_time += delta
	if not still_camera:
		var round_about := _time * 0.12
		camera.position = Vector3(sin(round_about) * 13.0, 3.2, cos(round_about) * 13.0)
		camera.look_at(Vector3(0.0, 1.8, 0.0))
	var to := post.position - clown.global_position
	to.y = 0.0
	var going := Vector3.ZERO
	clown.aim = post.position + Vector3.UP * 0.6
	clown.frozen = false
	clown.winded = false
	match step:
		"creep":
			going = to.normalized() * CREEP
			if _step_time > 2.4:
				_go("frozen")
			elif to.length() < 7.0:
				clown.giggle()
				_go("giggle")
		"frozen":
			clown.frozen = true
			if _step_time > 2.5:
				_go("creep")
		"giggle":
			if _step_time > 0.7:
				_go("sprint")
		"sprint":
			going = to.normalized() * SPRINT
			if to.length() < 1.2:
				_go("winded")
		"winded":
			clown.winded = true
			if _step_time > 2.5:
				_go("back")
		"back":
			var home := _home - clown.global_position
			home.y = 0.0
			going = home.normalized() * CREEP
			to = home
			if home.length() < 0.3:
				_go("creep")
	if clown.frozen:
		going = Vector3.ZERO
	clown.velocity = going
	clown.global_position += going * delta
	if going.length() > 0.05:
		clown.rotation.y = lerp_angle(clown.rotation.y, atan2(going.x, going.z), 1.0 - exp(-6.0 * delta))


func _go(next: String) -> void:
	step = next
	_step_time = 0.0

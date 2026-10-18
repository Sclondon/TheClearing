extends Node3D
## The least a level needs for `Ghoul`, and what the component is tested with:
## one on a flat floor under a grey sky, going round a loop. It stands as a
## statue, wakes, shuffles across to a post (the stand-in for a player), screams
## at it, shuffles closer, grabs it (and has it, every other time), and walks
## back to where it stood. Make a scene with a Node3D carrying this script and
## run it; drag nothing, it all goes by itself. The camera turns slowly round.
##
## Needs GameCommon's character-controller installed too (the rig is built on it).

## How big it is drawn (it is modelled about 1.4 units tall).
const SIZE := 1.6
## Its shuffle, world units a second.
const SPEED := 0.9

var ghoul: Ghoul
var post: MeshInstance3D
var camera: Camera3D
## Set to stop the camera moving (a test that places it itself).
var still_camera := false
## What it is doing in the loop (for a test to read).
var step := "statue"
var _time := 0.0
var _step_time := 0.0
var _round := 0
var _home := Vector3(0.0, 0.0, -3.0)


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
	plane.size = Vector2(40.0, 40.0)
	floor_mesh.mesh = plane
	floor_mesh.material_override = Toon.surface(Color(0.45, 0.44, 0.42))
	add_child(floor_mesh)

	post = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	post.mesh = capsule
	post.material_override = Toon.surface(Color(0.6, 0.15, 0.12))
	post.position = Vector3(0.0, 0.8, 3.0)
	add_child(post)

	ghoul = Ghoul.new()
	ghoul.scale = Vector3.ONE * SIZE
	add_child(ghoul)
	ghoul.put(_home, 0.0)

	camera = Camera3D.new()
	camera.fov = 45.0
	add_child(camera)


func _process(delta: float) -> void:
	_time += delta
	_step_time += delta
	if not still_camera:
		var round_about := _time * 0.15
		camera.position = Vector3(sin(round_about) * 9.0, 2.6, cos(round_about) * 9.0)
		camera.look_at(Vector3(0.0, 1.2, 0.0))
	var to := post.position - ghoul.global_position
	to.y = 0.0
	var going := Vector3.ZERO
	ghoul.aim = post.position + Vector3.UP * 0.4
	match step:
		"statue":
			ghoul.awake = false
			ghoul.aim = Vector3.INF
			if _step_time > 2.5:
				_go("wake")
		"wake":
			ghoul.awake = true
			if _step_time > 1.0:
				_go("shuffle")
		"shuffle":
			going = to.normalized() * SPEED
			if to.length() < 3.6:
				ghoul.scream()
				_go("scream")
		"scream":
			# (it creeps on as it screams)
			going = to.normalized() * SPEED * 0.4
			if not ghoul.busy():
				_go("close")
		"close":
			# (and then rushes)
			going = to.normalized() * SPEED * 3.5
			if to.length() < 1.6:
				ghoul.grab()
				_go("grab")
		"grab":
			if ghoul.stage() == GhoulRig.Stage.REACH:
				going = to.normalized() * SPEED
			if ghoul.stage() == GhoulRig.Stage.CLOSE and not ghoul.held and ghoul.grab_hits(post.position) and _round % 2 == 0:
				ghoul.held = true
			if not ghoul.busy():
				_round += 1
				_go("back")
		"back":
			ghoul.aim = Vector3.INF
			var home := _home - ghoul.global_position
			home.y = 0.0
			going = home.normalized() * SPEED
			to = home
			if home.length() < 0.3:
				_go("statue")
	ghoul.velocity = going
	ghoul.global_position += going * delta
	if going.length() > 0.05 or (to.length() > 0.05 and step != "statue"):
		var heading := going if going.length() > 0.05 else to
		ghoul.rotation.y = lerp_angle(ghoul.rotation.y, atan2(heading.x, heading.z), 1.0 - exp(-3.0 * delta))


func _go(next: String) -> void:
	step = next
	_step_time = 0.0

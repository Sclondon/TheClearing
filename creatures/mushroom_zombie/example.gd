extends Node3D
## The least a level needs for `MushroomZombie`, and what the component is
## tested with: one on a flat floor under a grey sky going round a loop. He
## rises out of the ground, shambles in fits about the floor, stops to listen
## to a post (the stand-in for someone) that makes a noise, lurches at it,
## lunges and takes it (every other time), and shambles off again. Make a scene
## with a Node3D carrying this script and run it; the camera turns slowly round.
##
## Needs GameCommon's character-controller and mushrooms installed too.

const SPEED := 0.7
const LURCH := 2.6

var zombie: MushroomZombie
var post: MeshInstance3D
var camera: Camera3D
## Set to stop the camera and the loop (a tool that places them itself).
var still := false
var step := "rise"
var _step_time := 0.0
var _round := 0
var _time := 0.0
var _wander := Vector3(-3.0, 0.0, -2.0)


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
	capsule.radius = 0.25
	capsule.height = 1.25
	post.mesh = capsule
	post.material_override = Toon.surface(Color(0.6, 0.15, 0.12))
	post.position = Vector3(2.5, 0.62, 3.0)
	add_child(post)
	zombie = MushroomZombie.new()
	add_child(zombie)
	zombie.put(Vector3.ZERO, 0.0)
	zombie.rise()
	camera = Camera3D.new()
	camera.fov = 45.0
	add_child(camera)


func _process(delta: float) -> void:
	if still:
		return
	_time += delta
	_step_time += delta
	var round_about := _time * 0.15
	camera.position = Vector3(sin(round_about) * 7.0, 2.0, cos(round_about) * 7.0)
	camera.look_at(Vector3(0.0, 0.8, 0.0))
	var going := Vector3.ZERO
	var to := post.position - zombie.global_position
	to.y = 0.0
	match step:
		"rise":
			zombie.clicking = 0.2
			if zombie.risen >= 1.0:
				_go("shamble")
		"shamble":
			var there := _wander - zombie.global_position
			there.y = 0.0
			going = there.normalized() * SPEED
			if there.length() < 0.3:
				_wander = Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-4.0, 4.0))
			if _step_time > 6.0:
				# (the post makes a noise: he stops dead and listens)
				zombie.aim = post.position
				zombie.listen()
				_go("listen")
		"listen":
			zombie.clicking = 0.9
			if not zombie.busy():
				_go("lurch")
		"lurch":
			zombie.frenzy = 1.0
			going = to.normalized() * LURCH
			if to.length() < 1.3:
				zombie.lunge()
				_go("lunge")
		"lunge":
			if zombie.stage() == MushroomZombieRig.Stage.REACH:
				going = to.normalized() * 1.5
			if zombie.stage() == MushroomZombieRig.Stage.CLOSE and not zombie.held and _round % 2 == 0 and zombie.grab_hits(post.position):
				zombie.held = true
			if not zombie.busy():
				_round += 1
				zombie.frenzy = 0.0
				zombie.clicking = 0.25
				zombie.aim = Vector3.INF
				_go("shamble")
	zombie.velocity = going
	zombie.global_position += going * delta
	if going.length() > 0.05:
		zombie.rotation.y = lerp_angle(zombie.rotation.y, atan2(going.x, going.z), 1.0 - exp(-3.0 * delta))


func _go(next: String) -> void:
	step = next
	_step_time = 0.0

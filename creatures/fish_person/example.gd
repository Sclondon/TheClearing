extends Node3D
## The least a level needs for `FishPerson`, and what the component is tested
## with: one on a flat floor under a grey sky, lurking in its pool, going round
## a loop. It waits under the water with only its eyes out, rises, croaks,
## shambles towards a post (the stand-in for a player), lopes at it, lunges and
## grabs it (and has it, every other time), shambles back to its pool and sinks
## into it again. Make a scene with a Node3D carrying this script and run it;
## drag nothing, it all goes by itself. The camera turns slowly round.
##
## Needs GameCommon's character-controller installed too (the rig is built on it).

## How big it is drawn (it is modelled about 1.42 units tall).
const SIZE := 1.5
## Its shamble and its lope, world units a second.
const SHAMBLE := 1.2
const LOPE := 4.6

var fish: FishPerson
var pool: FishPool
var post: MeshInstance3D
var camera: Camera3D
## Set to stop the camera moving (a test that places it itself).
var still_camera := false
## What it is doing in the loop (for a test to read).
var step := "under"
var _time := 0.0
var _step_time := 0.0
var _round := 0
var _home := Vector3(0.0, 0.0, -3.5)


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
	floor_mesh.material_override = Toon.surface(Color(0.42, 0.4, 0.36))
	add_child(floor_mesh)

	pool = FishPool.new()
	add_child(pool)
	pool.position = _home

	post = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	post.mesh = capsule
	post.material_override = Toon.surface(Color(0.6, 0.15, 0.12))
	post.position = Vector3(0.0, 0.8, 4.0)
	add_child(post)

	fish = FishPerson.new()
	fish.scale = Vector3.ONE * SIZE
	add_child(fish)
	fish.pool = pool
	fish.put(_home, 0.0, true)

	camera = Camera3D.new()
	camera.fov = 45.0
	add_child(camera)


func _process(delta: float) -> void:
	_time += delta
	_step_time += delta
	if not still_camera:
		var round_about := _time * 0.15
		camera.position = Vector3(sin(round_about) * 9.0, 2.6, cos(round_about) * 9.0)
		camera.look_at(Vector3(0.0, 1.0, 0.0))
	var to := post.position - fish.global_position
	to.y = 0.0
	var going := Vector3.ZERO
	fish.aim = post.position + Vector3.UP * 0.4
	match step:
		"under":
			fish.awake = false
			fish.aim = Vector3.INF
			if _step_time > 3.0:
				fish.emerge()
				_go("rise")
		"rise":
			if not fish.moving_in_water():
				fish.awake = true
				fish.croak()
				_go("croak")
		"croak":
			if not fish.busy():
				_go("shamble")
		"shamble":
			going = to.normalized() * SHAMBLE
			if to.length() < 5.0:
				_go("lope")
		"lope":
			going = to.normalized() * LOPE
			fish.winded = minf(fish.winded + delta * 0.6, 1.0)
			if to.length() < 1.9:
				fish.grab()
				_go("grab")
		"grab":
			if fish.stage() in [FishPersonRig.Stage.WIND, FishPersonRig.Stage.LUNGE]:
				going = to.normalized() * SHAMBLE * 1.5
			if fish.stage() == FishPersonRig.Stage.CLOSE and not fish.held and fish.grab_hits(post.position) and _round % 2 == 0:
				fish.held = true
			if not fish.busy():
				_round += 1
				_go("back")
		"back":
			fish.aim = Vector3.INF
			var home := _home - fish.global_position
			home.y = 0.0
			going = home.normalized() * SHAMBLE
			to = home
			if home.length() < 0.2:
				fish.awake = false
				fish.submerge()
				_go("sink")
		"sink":
			fish.aim = Vector3.INF
			if not fish.moving_in_water():
				_go("under")
	if step != "lope":
		fish.winded = maxf(fish.winded - delta * 0.15, 0.0)
	fish.velocity = going
	fish.global_position += going * delta
	if going.length() > 0.05 or (to.length() > 0.05 and step in ["croak", "grab"]):
		var heading := going if going.length() > 0.05 else to
		fish.rotation.y = lerp_angle(fish.rotation.y, atan2(heading.x, heading.z), 1.0 - exp(-3.0 * delta))


func _go(next: String) -> void:
	step = next
	_step_time = 0.0

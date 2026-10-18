extends Node3D
## An example of the skinwalker (Skinwalker): put this script on a Node3D in an
## empty scene and run it. It goes through what it does, over and over: creeps
## on all fours as a coyote, stops, rises onto its legs, stares, calls out (its
## mimicked call), drops, bursts forward on all fours, grabs, and walks back
## upright in its jerky way.
##
## Needs GameCommon's character-controller, coyote and dog installed too.

const SIZE := 1.25

var walker: Skinwalker
var step := "creep"
var _step_time := 0.0
var _home := Vector3(0.0, 0.0, -4.0)

## (what happens, and for how long)
const STEPS := [["creep", 4.0], ["rise", 2.4], ["stare", 1.2], ["call", 1.8], ["drop", 0.8], ["windup", 0.5], ["burst", 0.9], ["grab", 0.8], ["walk back", 5.0]]


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.57, 0.6)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	environment.ambient_light_energy = 0.4
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(35.0), 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	floor.mesh = plane
	add_child(floor)
	var camera := Camera3D.new()
	camera.position = Vector3(7.0, 2.2, 3.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, 0.0))
	walker = Skinwalker.new()
	walker.scale = Vector3.ONE * SIZE
	add_child(walker)
	walker.put(_home, 0.0)


func _process(delta: float) -> void:
	_step_time += delta
	var index := 0
	for k in STEPS.size():
		if STEPS[k][0] == step:
			index = k
	if _step_time >= STEPS[index][1]:
		_step_time = 0.0
		step = STEPS[(index + 1) % STEPS.size()][0]
		match step:
			"creep":
				walker.drop()
				walker.put(_home, 0.0)
			"rise":
				walker.rise()
			"call":
				walker.call_out()
			"drop":
				walker.drop()
			"grab":
				walker.grab()
	var ahead := Vector3(0.0, 0.0, 1.0)
	var speed: float = {"creep": 1.0, "burst": 8.0, "grab": 1.0, "walk back": -1.6}.get(step, 0.0)
	if step == "walk back" and not walker.is_upright() and not walker.busy():
		walker.rise()
	walker.global_position += ahead * speed * delta
	if step == "walk back" and walker.global_position.z <= _home.z:
		walker.global_position = _home
	walker.rotation.y = PI if speed < 0.0 else 0.0
	walker.velocity = ahead * speed
	walker.crouch = 1.0 if step == "windup" else 0.0
	walker.glare = 0.2 if step == "creep" else 1.0
	walker.aim = Vector3(7.0, 1.5, 3.0)

extends Node3D
## An example of the red foxes (Fox): put this script on a Node3D in an empty
## scene and run it. A pair on a flat floor go through what they do, over and
## over: trot, listen and pounce, sit and watch, gallop, bark and scream, curl
## up. Each is moved here, by hand, as a game would move it: the Fox works out
## its own gait from how fast it goes.
##
## Needs GameCommon's godot/dog installed too (the fox is the dog on a fox's model).

var pair: Array[Fox] = []
var _time := 0.0
var _act := -1

## (what happens, and for how long)
const ACTS := [["trot", 4.0], ["listen", 2.0], ["pounce", 2.4], ["sit", 4.0], ["gallop", 3.0], ["call", 3.0], ["lie", 4.0]]


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.6, 0.62, 0.64)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	environment.ambient_light_energy = 0.4
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(35.0), 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	floor.mesh = plane
	add_child(floor)
	var camera := Camera3D.new()
	camera.position = Vector3(4.5, 1.8, 4.5)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.3, 0.0))
	for i in 2:
		var fox := Fox.new()
		fox.variant = i
		fox.scale = Vector3.ONE * 0.72 * (1.0 if i == 0 else 0.95)
		fox.position = Vector3(i * 1.2 - 0.6, 0.0, 0.0)
		add_child(fox)
		pair.append(fox)


func _process(delta: float) -> void:
	_time += delta
	var total := 0.0
	for act: Array in ACTS:
		total += act[1]
	var t := fposmod(_time, total)
	var index := 0
	while t > ACTS[index][1]:
		t -= ACTS[index][1]
		index += 1
	var act: String = ACTS[index][0]
	var started := index != _act
	_act = index
	for i in pair.size():
		var fox := pair[i]
		fox.listening = act == "listen"
		fox.sitting = act == "sit" or act == "call" and i == 0
		fox.lying = act == "lie"
		var speed := 1.6 if act == "trot" else (5.5 if act == "gallop" else 0.0)
		if speed > 0.0:
			fox.rotation.y += delta * speed / 6.0
			fox.position += fox.global_basis.z.normalized() * speed * delta
			if fox.position.length() > 8.0:
				fox.position = fox.position.normalized() * 8.0
		if act == "pounce":
			if started:
				fox.pounce(fox.global_position + fox.global_basis.z.normalized() * 2.5)
			fox.global_position += fox.pounce_push() * delta
		if act == "call" and started:
			if fox.variant == 1:
				fox.scream()
			else:
				fox.bark()

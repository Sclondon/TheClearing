extends Node3D
## An example of the coyotes (Coyote): put this script on a Node3D in an empty
## scene and run it. A pack of three on a flat floor go through what they do,
## over and over: trot, sniff, stand and stare, the yip-howl chorus, slink off,
## gallop, sit. Each is moved here, by hand, as a game would move it: the
## Coyote works out its own gait from how fast it goes.
##
## Needs GameCommon's godot/dog installed too (the coyote is the dog on a coyote's model).

var pack: Array[Coyote] = []
var _time := 0.0
var _act := -1

## (what happens, and for how long)
const ACTS := [["trot", 4.0], ["sniff", 3.0], ["stare", 3.0], ["chorus", 4.0], ["slink", 4.0], ["gallop", 3.0], ["sit", 3.0]]


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
	camera.position = Vector3(6.0, 2.4, 6.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.4, 0.0))
	for i in 3:
		var coyote := Coyote.new()
		coyote.variant = i % 2
		coyote.scale = Vector3.ONE * 0.82 * [1.0, 0.95, 1.04][i]
		coyote.position = Vector3(-1.5 + 1.5 * i, 0.0, 0.0)
		add_child(coyote)
		pack.append(coyote)


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
	var starting := index != _act
	_act = index
	for k in pack.size():
		var coyote := pack[k]
		if starting:
			coyote.tracking = act == "sniff"
			coyote.slinking = act == "slink"
			coyote.sitting = act == "sit"
			coyote.look_at_point = Vector3(6.0, 1.5, 6.0) if act in ["stare", "chorus"] else Vector3.INF
			if act == "chorus":
				coyote.chorus(k, k == 1)
		var speed: float = {"trot": 1.9, "sniff": 0.9, "slink": 1.1, "gallop": 6.0}.get(act, 0.0)
		# Round and round a circle, each on its own.
		if speed > 0.0:
			var radius := 4.0 + k * 1.3
			var around := atan2(coyote.position.x, coyote.position.z) + speed / radius * delta
			coyote.position = Vector3(sin(around), 0.0, cos(around)) * radius
			coyote.rotation.y = around + PI * 0.5

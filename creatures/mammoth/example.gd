extends Node3D
## An example of the woolly mammoth (Mammoth): put this script on a Node3D in
## an empty scene and run it. A cow and her calf go through everything they do,
## over and over: graze, walk, amble, feel the air, the display (ears out and
## the trumpet), stamp, and charge.

var cow: Mammoth
var calf: Mammoth
var _time := 0.0
var _act := -1

## (what happens, and for how long)
const ACTS := [["graze", 9.0], ["walk", 5.0], ["amble", 3.0], ["feel", 4.0], ["display", 3.5], ["stamp", 1.5], ["charge", 3.0]]


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
	plane.size = Vector2(300.0, 300.0)
	floor.mesh = plane
	add_child(floor)
	var camera := Camera3D.new()
	camera.position = Vector3(26.0, 6.0, 26.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 2.0, 0.0))
	cow = Mammoth.new()
	cow.position = Vector3(-3.0, 0.0, 0.0)
	add_child(cow)
	calf = Mammoth.new()
	calf.calf = true
	calf.position = Vector3(2.0, 0.0, 1.0)
	add_child(calf)
	cow.trumpeted.connect(func() -> void: print("trumpet"))


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
	for mammoth: Mammoth in [cow, calf]:
		if starting:
			mammoth.grazing = act == "graze"
			mammoth.feeling = act == "feel"
			mammoth.alert = act in ["feel", "display"]
			mammoth.ears_out = act == "display" and mammoth == cow
			mammoth.lowered = act == "charge" and mammoth == cow
			mammoth.look_at_point = Vector3(20.0, 2.0, 20.0) if act in ["feel", "display"] else Vector3.INF
			if act == "display":
				mammoth.trumpet()
			if act == "stamp" and mammoth == cow:
				mammoth.stamp()
		var speed: float = {"walk": 1.2, "amble": 3.2, "charge": 6.0}.get(act, 0.0) * (1.0 if mammoth == cow else 0.8)
		if speed > 0.0:
			var radius := 12.0 if mammoth == cow else 15.0
			var around := atan2(mammoth.position.x, mammoth.position.z) + speed / radius * delta
			mammoth.position = Vector3(sin(around), 0.0, cos(around)) * radius
			mammoth.rotation.y = around + PI * 0.5

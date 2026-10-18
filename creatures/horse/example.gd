extends Node3D
## An example of the horse (Horse): put this script on a Node3D in an empty
## scene and run it. A grey, a dun in a halter and a dark bay go round and
## round through everything they do: graze, walk, trot, canter, gallop, stand
## and doze, look up alert, whinny, roll and shake.

var horses: Array[Horse] = []
var _time := 0.0
var _act := -1

const ACTS := [["graze", 5.0], ["walk", 5.0], ["trot", 4.0], ["canter", 4.0], ["gallop", 4.0], ["doze", 5.0],
		["alert", 4.0], ["roll", 11.0]]


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
	plane.size = Vector2(160.0, 160.0)
	floor.mesh = plane
	add_child(floor)
	var camera := Camera3D.new()
	camera.position = Vector3(16.0, 5.0, 16.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, 0.0))
	for i in 3:
		var horse := Horse.new()
		horse.coat = i
		horse.haltered = i == 1
		horse.position = Vector3(-4.0 + 4.0 * i, 0.0, 0.0)
		add_child(horse)
		horses.append(horse)


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
	for k in horses.size():
		var horse := horses[k]
		if starting:
			horse.grazing = act == "graze"
			horse.dozing = act == "doze"
			horse.alert = act == "alert"
			horse.fleeing = act == "gallop"
			horse.look_at_point = get_viewport().get_camera_3d().global_position if act == "alert" else Vector3.INF
			if act == "alert" and k == 0:
				horse.whinny()
			if act == "roll":
				horse.roll()
		if act == "roll" and t > 9.2 and t < 9.3:
			horse.shake()
		var speed: float = {"walk": 1.4, "trot": 3.2, "canter": 6.0, "gallop": 10.0}.get(act, 0.0)
		if speed > 0.0:
			var radius := 8.0 + k * 3.0
			var around := atan2(horse.position.x, horse.position.z) + speed / radius * delta
			horse.position = Vector3(sin(around), 0.0, cos(around)) * radius
			horse.rotation.y = around + PI * 0.5

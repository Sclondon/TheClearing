extends Node3D
## An example of the dimetrodon (Dimetrodon): put this script on a Node3D in an
## empty scene and run it. A dimetrodon walks round a circle, rushes, basks,
## rises gaping and hissing, and lunges, over and over.

var dim: Dimetrodon
var _time := 0.0
var _act := -1
var _speed := 0.0

const ACTS := [["walk", 5.0], ["rush", 3.0], ["bask", 5.0], ["threat", 2.0], ["lunge", 1.5]]


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
	plane.size = Vector2(100.0, 100.0)
	floor.mesh = plane
	add_child(floor)
	var camera := Camera3D.new()
	camera.position = Vector3(9.0, 4.0, 9.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.5, 0.0))
	dim = Dimetrodon.new()
	dim.position = Vector3(0.0, 0.0, 5.0)
	add_child(dim)


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
	if index != _act:
		_act = index
		dim.basking = act == "bask"
		dim.threatening = act == "threat"
		dim.look_at_point = dim.global_position + dim.global_basis.z * 3.0 + Vector3.UP if act in ["threat", "lunge"] else Vector3.INF
		if act == "threat":
			dim.hiss()
		if act == "lunge":
			dim.lunge()
	var want: float = {"walk": 0.7, "rush": 3.0, "lunge": 6.0 if t < 0.45 else 0.0}.get(act, 0.0)
	_speed = want if act == "lunge" else move_toward(_speed, want, 4.0 * delta)
	var radius := 5.0
	var around := atan2(dim.position.x, dim.position.z) + _speed / radius * delta
	dim.position = Vector3(sin(around), 0.0, cos(around)) * radius
	dim.rotation.y = around + PI * 0.5

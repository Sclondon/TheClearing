extends Node3D
## An example of the grey wolves (Wolf): put this script on a Node3D in an empty
## scene and run it. A pack of four on a flat floor go through what they do,
## over and over: trot in file, sniff, stand and stare, howl together, play-bow,
## hunt (the head-low trot) and gallop. Each is moved here, by hand, as a game
## would move it: the Wolf works out its own gait from how fast it goes.
##
## Needs GameCommon's godot/dog installed too (the wolf is the dog on a wolf's model).

var pack: Array[Wolf] = []
var _time := 0.0
var _act := -1

## (what happens, and for how long)
const ACTS := [["trot", 5.0], ["sniff", 3.0], ["stare", 3.0], ["chorus", 6.0], ["bow", 3.0], ["hunt", 4.0], ["gallop", 3.0]]


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
	camera.position = Vector3(9.0, 3.0, 9.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.6, 0.0))
	for i in 4:
		var wolf := Wolf.new()
		wolf.variant = 1 if i == 0 else i % 2
		wolf.rank = [0, 0, 1, 2][i]
		wolf.scale = Vector3.ONE * Wolf.SCALE * [1.05, 0.97, 1.0, 0.88][i]
		add_child(wolf)
		pack.append(wolf)


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
		var wolf := pack[k]
		if starting:
			wolf.tracking = act == "sniff"
			wolf.hunting = act == "hunt"
			wolf.bowing = act == "bow" and k >= 2
			wolf.look_at_point = Vector3(9.0, 1.5, 9.0) if act == "stare" else Vector3.INF
			if act == "chorus":
				wolf.howl_now(k, k == 3)
		var speed: float = {"trot": 2.7, "sniff": 1.0, "hunt": 3.4, "gallop": 7.0}.get(act, 0.0)
		# In file round a circle, each a little behind the one before.
		if speed > 0.0:
			var radius := 6.0
			var around := _time * speed / radius - k * 2.6 / radius
			wolf.position = Vector3(sin(around), 0.0, cos(around)) * radius
			wolf.rotation.y = around + PI * 0.5

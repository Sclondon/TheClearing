extends Node3D
## An example of the deer (Deer): put this script on a Node3D in an empty scene
## and run it. A doe, a buck, a fawn and one that is wrong go through
## everything they do, over and over: graze, walk, trot, freeze and watch,
## stamp and snort, flag, stot, gallop, and the wrong one stands up.
##
## Each is moved here, by hand, as a game would move it: the Deer works out its
## own gait from how fast it goes.

var herd: Array[Deer] = []
var watched: Node3D
var _time := 0.0
var _act := -1

## (what happens, and for how long)
const ACTS := [["graze", 4.0], ["walk", 4.0], ["trot", 3.0], ["watch", 4.0], ["stamp", 1.5], ["pronk", 2.5],
		["gallop", 4.0], ["upright", 4.0]]


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
	plane.size = Vector2(120.0, 120.0)
	floor.mesh = plane
	add_child(floor)
	var camera := Camera3D.new()
	camera.position = Vector3(9.0, 3.0, 9.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.8, 0.0))
	watched = camera
	for i in 4:
		var deer := Deer.new()
		deer.variant = Deer.Variant.BUCK if i == 1 else Deer.Variant.DOE
		deer.fawn = i == 2
		deer.wrong = 1.0 if i == 3 else 0.0
		deer.scale = Vector3.ONE * (0.55 if i == 2 else 1.0)
		deer.position = Vector3(-3.0 + 2.0 * i, 0.0, 0.0)
		add_child(deer)
		herd.append(deer)


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
	for k in herd.size():
		var deer := herd[k]
		if starting:
			deer.grazing = act == "graze"
			deer.alert = act in ["watch", "stamp"]
			deer.flagging = act in ["stamp", "pronk", "gallop"]
			deer.fleeing = act == "gallop"
			deer.pronking = act == "pronk"
			deer.upright = act == "upright" and deer.wrong > 0.0
			deer.look_at_point = watched.global_position if act in ["watch", "stamp", "upright"] else Vector3.INF
			if act == "stamp" and k == 0:
				deer.stamp()
				deer.snort()
		var speed: float = {"walk": 1.1, "trot": 2.6, "pronk": 2.4, "gallop": 8.0}.get(act, 0.0)
		# Round and round a circle, each on its own.
		if speed > 0.0:
			var radius := 5.0 + k * 1.6
			var around := atan2(deer.position.x, deer.position.z) + speed / radius * delta
			deer.position = Vector3(sin(around), 0.0, cos(around)) * radius
			deer.rotation.y = around + PI * 0.5

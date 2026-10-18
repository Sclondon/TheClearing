extends Node3D
## An example of the elk (Elk): put this script on a Node3D in an empty scene
## and run it. A bull and a cow go through everything they do, over and over:
## graze, walk, trot, the bull bugles, paws, lowers his antlers and charges
## (the cow gallops), and they stand blowing, their breath steaming.
##
## Needs the deer (Deer, DeerRig, DeerLook: GameCommon's godot/deer) too.

var bull: Elk
var cow: Elk
var _time := 0.0
var _act := -1

## (what happens, and for how long)
const ACTS := [["graze", 4.0], ["walk", 4.0], ["trot", 3.0], ["bugle", 4.0], ["paw", 2.5], ["charge", 3.5], ["blow", 3.0]]


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
	plane.size = Vector2(200.0, 200.0)
	floor.mesh = plane
	add_child(floor)
	var camera := Camera3D.new()
	camera.position = Vector3(14.0, 4.0, 14.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.4, 0.0))
	bull = Elk.new()
	bull.position = Vector3(-2.5, 0.0, 0.0)
	add_child(bull)
	cow = Elk.new()
	cow.cow = true
	cow.position = Vector3(2.5, 0.0, 0.0)
	add_child(cow)
	bull.bugled.connect(func() -> void: print("bugle"))


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
	for elk: Elk in [bull, cow]:
		if starting:
			elk.grazing = act == "graze"
			elk.alert = act == "blow"
			elk.pawing = act == "paw" and elk == bull
			elk.lowered = act in ["paw", "charge"] and elk == bull
			elk.look_at_point = Vector3(10.0, 1.5, 10.0) if act in ["bugle", "blow"] else Vector3.INF
			if act == "bugle" and elk == bull:
				elk.bugle()
		var speed: float = {"walk": 1.4, "trot": 3.5, "charge": 10.0}.get(act, 0.0)
		if speed > 0.0:
			var radius := 9.0 if elk == bull else 12.0
			var around := atan2(elk.position.x, elk.position.z) + speed / radius * delta
			elk.position = Vector3(sin(around), 0.0, cos(around)) * radius
			elk.rotation.y = around + PI * 0.5

extends Node3D
## An example of the moose (Moose): put this script on a Node3D in an empty
## scene and run it. A bull, a cow and her calf go through everything they do,
## over and over: browse, walk, trot, the warning (ears back, hackles up, head
## low, licking its lips), the charge, the strike, the call, and wading.
##
## Needs the elk and the deer (Elk, Deer, DeerRig, DeerLook: GameCommon's
## godot/elk and godot/deer) too.

var bull: Moose
var cow: Moose
var calf: Moose
var _time := 0.0
var _act := -1

## (what happens, and for how long)
const ACTS := [["browse", 4.0], ["walk", 4.0], ["trot", 3.0], ["warn", 3.5], ["charge", 3.0], ["strike", 2.0], ["call", 3.0], ["wade", 4.0]]


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
	camera.position = Vector3(16.0, 4.0, 16.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.5, 0.0))
	bull = Moose.new()
	bull.position = Vector3(-3.0, 0.0, 0.0)
	add_child(bull)
	cow = Moose.new()
	cow.cow = true
	cow.position = Vector3(3.0, 0.0, 0.0)
	add_child(cow)
	calf = Moose.new()
	calf.calf = true
	calf.scale = Vector3.ONE * 0.55
	calf.position = Vector3(5.0, 0.0, 1.5)
	add_child(calf)
	bull.struck.connect(func() -> void: print("struck"))


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
	for moose: Moose in [bull, cow, calf]:
		if starting:
			moose.browsing = act == "browse"
			moose.bristling = act == "warn" and moose != calf
			moose.lowered = act == "charge" and moose != calf
			moose.wading = 0.5 * moose.scale.x if act == "wade" else 0.0
			moose.grazing = act == "wade"
			moose.look_at_point = Vector3(12.0, 1.5, 12.0) if act in ["warn", "strike", "call"] else Vector3.INF
			if act == "strike" and moose == bull:
				moose.strike()
			if act == "call" and moose != calf:
				moose.bugle()
		var speed: float = {"walk": 1.3, "trot": 4.5, "charge": 6.8}.get(act, 0.0) * moose.scale.x
		if speed > 0.0:
			var radius := 9.0 if moose == bull else (12.0 if moose == cow else 14.0)
			var around := atan2(moose.position.x, moose.position.z) + speed / radius * delta
			moose.position = Vector3(sin(around), 0.0, cos(around)) * radius
			moose.rotation.y = around + PI * 0.5

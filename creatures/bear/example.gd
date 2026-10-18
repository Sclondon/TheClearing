extends Node3D
## An example of the screaming bear (Bear): put this script on a Node3D in an
## empty scene and run it. A bear on a flat floor goes through everything it
## does, over and over: prowl, sniff, call out in its stolen voice, snap its
## jaws, rear and scream, charge, skid, swipe, maul, and sob.
##
## It is moved here, by hand, as a game would move it: the Bear works out its
## own gait from how fast it goes.

var bear: Bear
var _time := 0.0
var _act := -1
var _speed := 0.0

## (what happens, and for how long)
const ACTS := [["prowl", 5.0], ["sniff", 2.5], ["call", 2.5], ["pop", 1.0], ["rear", 3.0], ["lower", 0.6],
		["charge", 1.6], ["skid", 1.2], ["swipe", 1.4], ["maul", 3.0], ["sob", 2.5]]


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
	camera.position = Vector3(22.0, 8.0, 22.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.5, 0.0))
	bear = Bear.new()
	bear.scale = Vector3.ONE * 2.4
	bear.position = Vector3(0.0, 0.0, 30.0)
	add_child(bear)
	bear.swiped.connect(func() -> void: print("swiped"))


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
	if starting:
		bear.sniffing = act == "sniff"
		bear.rearing = act == "rear"
		bear.lowered = act in ["lower", "charge"]
		bear.mauling = act == "maul"
		match act:
			"sniff":
				bear.sniff()
			"call":
				bear.call_out()
			"pop":
				bear.pop_jaw()
			"rear":
				bear.scream()
			"swipe":
				bear.swipe(1.0)
			"sob":
				bear.call_out(BearVoice.SOB)
	var want: float = {"prowl": 1.2, "charge": 6.8}.get(act, 0.0)
	# (it gathers speed charging, and brakes hard skidding)
	var rate := 14.0 if act == "charge" else 12.0 if act == "skid" else 3.0
	_speed = move_toward(_speed, want, rate * delta)
	# Round and round a wide circle.
	var radius := 30.0
	var around := atan2(bear.position.x, bear.position.z) + _speed / radius * delta
	bear.position = Vector3(sin(around), 0.0, cos(around)) * radius
	bear.rotation.y = around + PI * 0.5

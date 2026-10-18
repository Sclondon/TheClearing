extends Node3D
## An example of the giant boar (Boar): put this script on a Node3D in an empty
## scene and run it. A boar on a flat floor goes through everything it does,
## over and over: walk, root, sniff the air, snort, stamp, wind up (hackles,
## head down, a squeal), charge, skid to a stop, slam into a wall and stand
## stunned, toss its tusks.
##
## It is moved here, by hand, as a game would move it: the Boar works out its
## own gait from how fast it goes.

var boar: Boar
var wall: MeshInstance3D
var _time := 0.0
var _act := -1
var _speed := 0.0

## (what happens, and for how long)
const ACTS := [["walk", 4.0], ["root", 5.0], ["sniff", 3.0], ["snort", 1.5], ["stamp", 2.0], ["wind up", 2.0],
		["charge", 2.5], ["skid", 1.5], ["walk", 3.0], ["charge", 2.0], ["slam", 4.0], ["toss", 2.0]]


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
	wall = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(10.0, 8.0, 2.0)
	wall.mesh = box
	add_child(wall)
	wall.visible = false
	boar = Boar.new()
	boar.scale = Vector3.ONE * 2.7
	boar.position = Vector3(0.0, 0.0, 30.0)
	add_child(boar)
	boar.tossed.connect(func() -> void: print("tossed"))


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
		boar.rooting = act == "root"
		boar.sniffing = act == "sniff"
		boar.bristling = act in ["snort", "stamp", "wind up", "charge", "skid"]
		boar.lowered = act in ["wind up", "charge"]
		boar.stunned = act == "slam"
		wall.visible = act == "slam"
		match act:
			"snort":
				boar.snort()
			"stamp":
				boar.stamp()
			"wind up":
				boar.squeal()
			"slam":
				wall.global_position = boar.global_position + boar.global_basis.z.normalized() * 4.3 + Vector3.UP * 4.0
				wall.rotation.y = boar.rotation.y
				boar.slam()
			"toss":
				boar.toss(1.0)
	var want: float = {"walk": 1.4, "root": 0.5, "charge": 11.0}.get(act, 0.0)
	# (it gathers speed charging, and brakes hard skidding)
	var rate := 9.0 if act == "charge" else 12.0 if act == "skid" else 4.0
	_speed = 0.0 if act == "slam" else move_toward(_speed, want, rate * delta)
	# Round and round a wide circle.
	var radius := 30.0
	var around := atan2(boar.position.x, boar.position.z) + _speed / radius * delta
	boar.position = Vector3(sin(around), 0.0, cos(around)) * radius
	boar.rotation.y = around + PI * 0.5

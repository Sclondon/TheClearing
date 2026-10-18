extends Node3D
## An example of the stegosaurus (Stegosaurus): put this script on a Node3D in
## an empty scene and run it. A stegosaurus on a flat floor, its calf beside
## it, goes through everything it does, over and over: walk, amble, graze,
## turn on the spot, look up and huff, warn (rumbling, tail raised), swing its
## tail one way and the other, bellow.
##
## It is moved here, by hand, as a game would move it: the Stegosaurus works
## out its own walk from how fast it goes.

var steg: Stegosaurus
var calf: Stegosaurus
var _time := 0.0
var _act := -1
var _speed := 0.0

## (what happens, and for how long)
const ACTS := [["walk", 6.0], ["amble", 4.0], ["graze", 6.0], ["turn", 4.0], ["look", 2.5], ["warn", 3.0],
		["swing left", 2.0], ["warn", 1.5], ["swing right", 2.0], ["bellow", 2.5]]


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
	camera.position = Vector3(36.0, 12.0, 36.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.5, 0.0))
	steg = Stegosaurus.new()
	steg.position = Vector3(0.0, 0.0, 30.0)
	add_child(steg)
	calf = Stegosaurus.new()
	calf.scale = Vector3.ONE * 0.38
	calf.scales = 20.0
	add_child(calf)
	steg.swept.connect(func() -> void: print("swept"))


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
		steg.grazing = act == "graze"
		steg.warning = act == "warn"
		var aside := steg.global_basis.x.normalized() * 8.0 - steg.global_basis.z.normalized() * 3.0
		steg.look_at_point = steg.global_position + aside + Vector3.UP if act in ["look", "warn", "bellow"] else Vector3.INF
		steg.threat_side = 1.0
		match act:
			"look":
				steg.huff()
			"warn":
				steg.rumble()
			"swing left":
				steg.swing(1.0)
			"swing right":
				steg.swing(-1.0)
			"bellow":
				steg.bellow()
	var want: float = {"walk": 1.0, "amble": 2.4}.get(act, 0.0)
	_speed = move_toward(_speed, want, 0.8 * delta)
	# Round and round a wide circle (turning on the spot when it is told to).
	var radius := 30.0
	var around := atan2(steg.position.x, steg.position.z) + _speed / radius * delta
	steg.position = Vector3(sin(around), 0.0, cos(around)) * radius
	steg.rotation.y = around + PI * 0.5 + (t * 0.6 if act == "turn" else 0.0)
	# The calf keeps by her shoulder.
	var beside := steg.global_transform * Vector3(-3.2, 0.0, 2.0)
	calf.position = calf.position.lerp(beside, 1.0 - exp(-1.5 * delta))
	var to := beside - calf.position
	var facing := atan2(to.x, to.z) if to.length() > 0.5 else steg.rotation.y
	calf.rotation.y = lerp_angle(calf.rotation.y, facing, 1.0 - exp(-3.0 * delta))

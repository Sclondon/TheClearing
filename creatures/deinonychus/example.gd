extends Node3D
## An example of the deinonychus (Deinonychus): put this script on a Node3D in
## an empty scene and run it. A pack of three on a flat floor go through what
## they do, over and over: walk, stop and look about (heads cocked), stalk
## low, hoot and click to each other, run, wind up and pounce, pin, and pant.
## Each is moved here, by hand, as a game would move it: the Deinonychus works
## out its own gait from how fast it goes.

var pack: Array[Deinonychus] = []
var _time := 0.0
var _act := -1

## (what happens, and for how long)
const ACTS := [["walk", 4.0], ["look", 3.0], ["stalk", 3.0], ["call", 2.5], ["run", 3.0], ["pounce", 3.0], ["tired", 3.0]]


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
	for i in 3:
		var dino := Deinonychus.new()
		dino.voice = [1.0, 0.92, 1.1][i]
		dino.position = Vector3(-2.0 + 2.0 * i, 0.0, 4.0)
		add_child(dino)
		pack.append(dino)


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
		var dino := pack[k]
		if starting:
			dino.crouching = act == "stalk"
			dino.tired = act == "tired"
			dino.cocking = act == "look"
			dino.look_at_point = Vector3(9.0, 1.5, 9.0) if act in ["look", "stalk", "call"] else Vector3.INF
			if act == "call":
				# (one hoots, the next answers higher, the last clicks)
				get_tree().create_timer(0.6 * k + 0.01).timeout.connect(_call.bind(dino, k))
			if act == "pounce":
				dino.pounce()
		if act == "pounce":
			# The leap: carried through the air by hand once the wind-up is over, then a pin.
			if dino.pounce_stage() == DeinonychusRig.Pounce.LEAP:
				dino.grounded = false
				dino.position += Vector3(sin(dino.rotation.y), 0.0, cos(dino.rotation.y)) * 9.0 * delta
			elif not dino.grounded:
				dino.grounded = true
				dino.pin()
		var speed: float = {"walk": 1.4, "stalk": 1.0, "run": 6.0}.get(act, 0.0)
		# Round and round a circle, each on its own.
		if speed > 0.0:
			var radius := 4.0 + k * 1.5
			var around := atan2(dino.position.x, dino.position.z) + speed / radius * delta
			dino.position = Vector3(sin(around), 0.0, cos(around)) * radius
			dino.rotation.y = around + PI * 0.5


func _call(dino: Deinonychus, k: int) -> void:
	if k == 2:
		dino.click()
	else:
		dino.hoot(0.95 if k == 0 else 1.15)

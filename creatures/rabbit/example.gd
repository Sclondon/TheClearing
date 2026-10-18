extends Node3D
## An example of the rabbits (Rabbit, RabbitWarren): put this script on a
## Node3D in an empty scene and run it. A warren, a rabbit, a hare and a
## jackalope go through everything they do, over and over: sit, graze, hop,
## sit up and look, wash, thump, bound (scut up), dive down a hole and come up
## again; the hare and the jackalope lie flat, box and charge.
##
## Each is moved here, by hand, as a game would move it: the Rabbit works out
## its own gait from how fast it goes.

var rabbit: Rabbit
var hare: Rabbit
var jackalope: Rabbit
var warren: RabbitWarren
var watched: Node3D
var _time := 0.0
var _act := -1

## (what happens, and for how long)
const ACTS := [["sit", 2.0], ["graze", 3.0], ["hop", 3.0], ["upright", 2.5], ["wash", 3.0], ["thump", 1.0],
		["bound", 2.5], ["down", 2.0], ["flat", 3.0], ["box", 3.0], ["charge", 2.0]]


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
	camera.position = Vector3(3.5, 1.6, 4.5)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.2, 0.0))
	watched = camera
	warren = RabbitWarren.new()
	warren.position = Vector3(-4.0, 0.0, -3.0)
	add_child(warren)
	rabbit = _make(Rabbit.Variant.RABBIT, Vector3(-1.0, 0.0, 0.0))
	hare = _make(Rabbit.Variant.HARE, Vector3(0.6, 0.0, 0.0))
	jackalope = _make(Rabbit.Variant.JACKALOPE, Vector3(2.0, 0.0, 0.0))


func _make(variant: Rabbit.Variant, at: Vector3) -> Rabbit:
	var one := Rabbit.new()
	one.variant = variant
	one.position = at
	add_child(one)
	return one


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
	for one: Rabbit in [rabbit, hare, jackalope]:
		if starting:
			one.grazing = act == "graze"
			one.upright = act == "upright"
			one.alert = act == "upright"
			one.washing = act == "wash"
			one.flagging = act == "bound"
			one.fleeing = act in ["bound", "charge"]
			one.flattened = act == "flat" and one != jackalope
			one.boxing = act == "box" and one != rabbit
			one.lowered = act == "charge" and one == jackalope
			one.look_at_point = watched.global_position if act == "upright" or (act == "flat" and one == jackalope) else Vector3.INF
			one.visible = true
			if act == "thump":
				one.thump()
			if act == "charge" and one == jackalope:
				one.grunt()
		var speed: float = {"hop": 0.6, "bound": 7.0 * one.scale.x, "charge": 9.0 if one == jackalope else 0.0}.get(act, 0.0)
		# Round and round a circle, each on its own.
		if speed > 0.0:
			var radius := 3.0 + [rabbit, hare, jackalope].find(one) * 1.2
			var around := atan2(one.position.x, one.position.z) + speed / radius * delta
			one.position = Vector3(sin(around), 0.0, cos(around)) * radius
			one.rotation.y = around + PI * 0.5
	# Down a hole and up again: the rabbit runs to the warren's first hole, along the tunnel, and out.
	if act == "down" and warren.hole_count() > 0:
		var mouth := warren.mouth(0)
		var deep := warren.deep(0)
		if t < 1.0:
			rabbit.global_position = rabbit.global_position.lerp(mouth, 1.0 - exp(-6.0 * delta))
			rabbit.flagging = true
			var to := mouth - rabbit.global_position
			rabbit.rotation.y = atan2(to.x, to.z)
		else:
			rabbit.global_position = mouth.lerp(deep, clampf((t - 1.0) / 0.4, 0.0, 1.0))
			rabbit.visible = t < 1.4

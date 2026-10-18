extends Node3D
## An example of the big cats (BigCat): put this script on a Node3D in an empty
## scene and run it. A lynx and a black panther on a flat floor go through what
## they do, over and over: walk, stalk, crouch, the wiggle and the pounce, the
## hiss, the swipe, the gallop, sit. Each is moved here, by hand, as a game
## would move it: the BigCat works out its own gait from how fast it goes.
##
## Needs GameCommon's godot/dog installed too (the cats are built on the dog).

var cats: Array[BigCat] = []
var _time := 0.0
var _act := -1

## (what happens, and for how long)
const ACTS := [["walk", 4.0], ["stalk", 4.0], ["crouch", 2.0], ["pounce", 2.5], ["hiss", 2.0], ["swipe", 1.5], ["gallop", 3.0], ["sit", 3.0]]


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
	for kind: int in [BigCat.Kind.LYNX, BigCat.Kind.PANTHER]:
		var cat := BigCat.new()
		cat.kind = kind
		cat.position = Vector3(-1.2 if kind == BigCat.Kind.LYNX else 1.2, 0.0, 0.0)
		add_child(cat)
		cats.append(cat)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(5.0, 2.0, 6.0)
	camera.look_at(Vector3(0.0, 0.4, 2.0))


func _process(delta: float) -> void:
	_time -= delta
	if _time <= 0.0:
		_act = (_act + 1) % ACTS.size()
		_time = ACTS[_act][1]
		_begin(ACTS[_act][0])
	var act: String = ACTS[_act][0]
	var speed: float = {"walk": 1.1, "stalk": 0.6, "gallop": 7.0}.get(act, 0.0)
	for cat in cats:
		if act == "pounce":
			cat.position += cat.lunge_push() * delta
		else:
			cat.position.z += speed * delta
		if cat.position.z > 12.0:
			cat.position.z = -8.0
			cat.settle()


func _begin(act: String) -> void:
	for cat in cats:
		cat.stalking = act == "stalk"
		cat.crouching = act == "crouch"
		cat.sitting = act == "sit"
		cat.look_at_point = cat.position + Vector3(0.0, 0.5, 4.0) if act in ["stalk", "crouch", "hiss"] else Vector3.INF
		match act:
			"pounce":
				cat.pounce(cat.position + Vector3(0.0, 0.5, 3.5))
			"hiss":
				cat.hiss()
			"swipe":
				cat.swipe(cat.position + Vector3(0.3, 0.5, 1.2))

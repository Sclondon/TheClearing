extends Node3D
## An example of the feral dogs (Dog): put this script on a Node3D in an empty
## scene and run it. Two dogs on a flat floor go through everything they do,
## over and over: walk, trot, nose down on a trail, stalk, bark, howl, gallop,
## spring at a post and snap, miss and shake, sit and lie down.
##
## Each dog is moved here, by hand, as a game would move it: the Dog works out
## its own gait from how fast it goes.

var dogs: Array[Dog] = []
var post: Node3D
var _time := 0.0
var _act := -1

## (what happens, and for how long)
const ACTS := [["walk", 4.0], ["trot", 3.0], ["track", 5.0], ["stalk", 4.0], ["bark", 2.0], ["howl", 3.5],
		["gallop", 3.0], ["lunge", 2.5], ["shake", 2.0], ["sit", 3.0], ["lie", 4.0]]


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
	camera.position = Vector3(7.0, 3.0, 7.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.6, 0.0))
	post = MeshInstance3D.new()
	(post as MeshInstance3D).mesh = CylinderMesh.new()
	post.scale = Vector3(0.4, 1.4, 0.4)
	add_child(post)
	post.visible = false
	for i in 2:
		var dog := Dog.new()
		dog.variant = i
		dog.scale = Vector3.ONE * (1.35 if i == 0 else 1.25)
		dog.coat_tint = Color.WHITE if i == 0 else Color(1.08, 0.97, 0.88)
		dog.position = Vector3(-1.5 + 3.0 * i, 0.0, 0.0)
		add_child(dog)
		dogs.append(dog)
		dog.snapped.connect(func() -> void: print("snap"))


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
	for k in dogs.size():
		var dog := dogs[k]
		if starting:
			dog.tracking = act == "track"
			dog.stalking = act == "stalk"
			dog.snarling = act in ["stalk", "lunge"]
			dog.sitting = act in ["sit", "lie"]
			dog.lying = act == "lie"
			match act:
				"bark":
					dog.bark()
				"howl":
					dog.howl(3.0)
				"lunge":
					post.visible = true
					post.global_position = dog.global_position + dog.global_basis.z.normalized() * 4.0 * dog.scale.x + Vector3.UP * 1.4
					if k == 0:
						dog.lunge(post.global_position)
				"shake":
					post.visible = false
					dog.shake()
		var speed: float = {"walk": 1.2, "trot": 2.6, "track": 1.4, "stalk": 0.9, "gallop": 5.5}.get(act, 0.0)
		# Round and round a circle, each dog on its own.
		if speed > 0.0:
			var radius := 4.0 + k * 1.5
			var centre := Vector3(0.0, 0.0, 0.0)
			var around := atan2(dog.position.x - centre.x, dog.position.z - centre.z) + speed / radius * delta
			dog.position = centre + Vector3(sin(around), 0.0, cos(around)) * radius
			dog.rotation.y = around + PI * 0.5
		if dog.lunge_stage() != Dog.Lunge.NONE:
			dog.global_position += dog.lunge_push() * delta
		# (it looks at the camera's side of things now and then)
		dog.look_at_point = post.global_position if post.visible else Vector3.INF

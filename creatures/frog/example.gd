extends Node3D
## An example of the frogs: put this script on a Node3D in an empty scene and
## play it. A giant toad (GiantToad) on a floor sits, croaks, leaps about and
## shoots its tongue at a post; across from it a pool of frogs (FrogSwarm)
## pours out every so often at a post that walks round the floor, clings to
## it, and is called home again.
##
## Both are moved here by hand, as a game would move them.

var toad: GiantToad
var swarm: FrogSwarm
var post: CharacterBody3D
var _clock := 0.0
var _act := -1

## (what the toad does, and for how long)
const ACTS := [["sit", 3.0], ["croak", 2.5], ["leap", 2.2], ["leap back", 2.2], ["tongue", 2.6], ["turn", 2.5]]


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
	# A floor to see and one to stand on (the frogs look for the ground with rays).
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	floor.mesh = plane
	add_child(floor)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80.0, 1.0, 80.0)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	add_child(ground)
	var camera := Camera3D.new()
	camera.position = Vector3(9.0, 6.0, 12.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.5, 2.0))

	toad = GiantToad.new()
	toad.scale = Vector3.ONE * 2.8
	toad.position = Vector3(-4.0, 0.0, 0.0)
	add_child(toad)
	toad.croaked.connect(func() -> void: print("croak"))
	toad.tongue_fired.connect(func(at: Vector3) -> void: print("tongue at ", at))

	post = CharacterBody3D.new()
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.28
	capsule.height = 1.7
	body.mesh = capsule
	body.position.y = 0.85
	post.add_child(body)
	add_child(post)

	swarm = FrogSwarm.new()
	swarm.count = 60
	swarm.position = Vector3(5.0, 0.0, -4.0)
	add_child(swarm)
	swarm.target = post
	swarm.caught.connect(func(_who: Node3D) -> void: print("caught by the frogs"))


func _process(delta: float) -> void:
	_clock += delta
	# The post walks round the floor; the frogs come out for it every 20 seconds.
	var t := _clock * 0.35
	var was := post.global_position
	post.global_position = Vector3(2.0 + cos(t) * 5.0, 0.0, 3.0 + sin(t) * 4.0)
	post.velocity = (post.global_position - was) / maxf(delta, 0.001)
	swarm.chasing = fposmod(_clock, 20.0) > 6.0
	_toad_acts(delta)


func _toad_acts(delta: float) -> void:
	var total := 0.0
	for one: Array in ACTS:
		total += one[1]
	var into := fposmod(_clock, total)
	var act := 0
	while into > ACTS[act][1]:
		into -= ACTS[act][1]
		act += 1
	if act != _act:
		_act = act
		match ACTS[act][0]:
			"croak":
				toad.croak(3)
			"leap":
				toad.leap(toad.global_position + toad.global_basis.z.normalized() * 5.0)
			"leap back":
				toad.rotation.y += PI
				toad.leap(toad.global_position + toad.global_basis.z.normalized() * 5.0)
			"tongue":
				toad.strike(post.global_position + Vector3.UP * 1.3)
	toad.global_position += toad.leap_push() * delta
	toad.global_position.y = maxf(toad.global_position.y, 0.0)
	if ACTS[act][0] == "turn":
		toad.rotation.y += delta * 0.6

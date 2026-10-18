extends Node3D
## The least a level needs for `Hydra`, and what the component is tested
## with: one on a flat floor under a grey sky, lying in a dark pool. It sleeps
## a while with its necks lying about it, wakes, and its heads rise and weave
## and watch a post (a stand-in for a player) that goes round and round past
## it; whichever heads can reach the post strike at it, one after another, and
## now and then one is cut off and two grow back. Make a scene with a Node3D
## carrying this script and run it; it all goes by itself. The camera turns
## slowly round.

var hydra: Hydra
var post: MeshInstance3D
var camera: Camera3D
## Set to stop the camera and the post moving (a test that places them itself).
var still := false
var _time := 0.0
var _next_strike := 2.0
var _cut_in := 9.0


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.64, 0.66)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.72, 0.75)
	environment.ambient_light_energy = 0.55
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.66, 0.68, 0.7)
	environment.fog_density = 0.012
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0.0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	floor_mesh.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.4, 0.38, 0.34)
	floor_mesh.material_override = ground
	add_child(floor_mesh)

	post = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	post.mesh = capsule
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.6, 0.15, 0.12)
	post.material_override = red
	post.position = Vector3(0.0, 0.8, 9.0)
	add_child(post)

	hydra = Hydra.new()
	hydra.heads = 7
	add_child(hydra)
	hydra.put(Vector3.ZERO, 0.0)

	camera = Camera3D.new()
	camera.fov = 45.0
	add_child(camera)


func _process(delta: float) -> void:
	_time += delta
	if not still:
		var round_about := _time * 0.12
		camera.position = Vector3(sin(round_about) * 20.0, 6.0, cos(round_about) * 20.0)
		camera.look_at(Vector3(0.0, 2.0, 0.0))
		# (the post goes round in front of it, in and out of its reach)
		var a := _time * 0.35
		post.position = Vector3(sin(a) * 9.0, 0.8, 3.0 + cos(a) * 6.5)
	hydra.awake = _time > 3.0
	hydra.watch = [post.position + Vector3.UP * 0.4]
	if still or not hydra.awake:
		return
	_next_strike -= delta
	if _next_strike <= 0.0:
		_next_strike = randf_range(0.35, 1.2)
		for head in hydra.ready_heads():
			if hydra.can_reach(head, post.position):
				hydra.strike(head, post.position)
				break
	for head in hydra.head_slots():
		hydra.retarget(head, post.position)
	_cut_in -= delta
	if _cut_in <= 0.0:
		_cut_in = 14.0
		var heads := hydra.head_slots()
		if not heads.is_empty():
			hydra.sever(heads[randi() % heads.size()])

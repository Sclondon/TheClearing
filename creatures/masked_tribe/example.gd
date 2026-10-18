extends Node3D
## The least a level needs for `Tribesman`, and what the component is tested
## with: a hunting party of three on a flat floor under a grey sky, by their
## totem, and a post (the stand-in for a player) some way off with a board
## behind it. Round a loop: they stand about; the first sees the post, drums
## and chants; one draws back and throws at it, and the spear sticks in the
## board; he walks over and takes it up again; another creeps up to the post
## and jabs it; they walk back. Make a scene with a Node3D carrying this script
## and run it; drag nothing. The camera turns slowly round.
##
## Needs GameCommon's character-controller installed too (the boy and his rig).

## Walking, world units a second.
const SPEED := 1.4

var men: Array[Tribesman] = []
var post: MeshInstance3D
var board: StaticBody3D
var totem: MeshInstance3D
var camera: Camera3D
## Set to stop the camera moving (a test that places it itself).
var still_camera := false
## What they are doing in the loop (for a test to read).
var step := "about"
var _time := 0.0
var _step_time := 0.0
var _homes: Array[Vector3] = [Vector3(-1.2, 0.0, -2.0), Vector3(0.4, 0.0, -2.6), Vector3(1.6, 0.0, -1.6)]


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.64, 0.66)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.72, 0.75)
	environment.ambient_light_energy = 0.55
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.66, 0.68, 0.7)
	environment.fog_density = 0.02
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0.0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)
	var ground := StaticBody3D.new()
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	floor_mesh.mesh = plane
	floor_mesh.material_override = Toon.surface(Color(0.45, 0.44, 0.42))
	ground.add_child(floor_mesh)
	var floor_shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(40.0, 0.2, 40.0)
	floor_shape.shape = slab
	floor_shape.position.y = -0.1
	ground.add_child(floor_shape)
	add_child(ground)

	post = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 1.3
	post.mesh = capsule
	post.material_override = Toon.surface(Color(0.5, 0.14, 0.11))
	post.position = Vector3(0.0, 0.65, 7.0)
	add_child(post)
	# (a board behind it for the spear to stick in)
	board = StaticBody3D.new()
	var board_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4.0, 2.4, 0.3)
	board_mesh.mesh = box
	board_mesh.material_override = Toon.surface(Color(0.5, 0.49, 0.46))
	board.add_child(board_mesh)
	var board_shape := CollisionShape3D.new()
	var board_box := BoxShape3D.new()
	board_box.size = box.size
	board_shape.shape = board_box
	board.add_child(board_shape)
	board.position = Vector3(0.0, 1.2, 9.0)
	add_child(board)

	totem = Tribesman.totem()
	totem.position = Vector3(0.2, 0.0, -4.2)
	add_child(totem)
	for k in 3:
		var man := Tribesman.new()
		man.mask = [0, 2, 3][k]
		man.point = TribeSpear.Point.BONE if k == 1 else TribeSpear.Point.STONE
		add_child(man)
		man.put(_homes[k], 0.0)
		men.append(man)

	camera = Camera3D.new()
	camera.fov = 45.0
	add_child(camera)


func _process(delta: float) -> void:
	_time += delta
	_step_time += delta
	if not still_camera:
		var round_about := _time * 0.12
		camera.position = Vector3(sin(round_about) * 10.0, 2.6, cos(round_about) * 10.0) + Vector3(0.0, 0.0, 2.0)
		camera.look_at(Vector3(0.0, 1.0, 2.0))
	var target := post.position + Vector3.UP * 0.2
	var going: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	for man in men:
		man.aim = target if step != "about" and step != "back" else Vector3.INF
		man.stalking = false
	var thrower := men[1]
	var jabber := men[0]
	match step:
		"about":
			if _step_time > 2.5:
				men[2].chant()
				_go("chant")
		"chant":
			if not men[2].busy():
				thrower.wind_up()
				_go("wind")
		"wind":
			if _step_time > 1.1:
				thrower.loose(Tribesman.launch(thrower.spear_point(), target + Vector3.UP * 0.4, 15.0, thrower.spear.gravity))
				_go("thrown")
		"thrown":
			if _step_time > 1.5:
				_go("fetch")
		"fetch":
			var to := thrower.spear.lying_at() - thrower.global_position
			to.y = 0.0
			thrower.aim = thrower.spear.lying_at()
			if to.length() > 0.7:
				going[1] = to.normalized() * SPEED * 2.0
			elif not thrower.busy():
				thrower.pick_up()
				_go("pick")
		"pick":
			if not thrower.busy():
				_go("creep")
		"creep":
			var to := post.position - jabber.global_position
			to.y = 0.0
			jabber.stalking = true
			if to.length() > 1.6:
				going[0] = to.normalized() * SPEED * 0.6
			else:
				jabber.jab()
				_go("jab")
		"jab":
			if not jabber.busy():
				_go("back")
		"back":
			var home_now := 0
			for k in 3:
				var to := _homes[k] - men[k].global_position
				to.y = 0.0
				if to.length() > 0.2:
					going[k] = to.normalized() * SPEED
				else:
					home_now += 1
			if home_now == 3:
				_go("about")
	for k in 3:
		var man := men[k]
		man.velocity = going[k]
		man.global_position += going[k] * delta
		var heading := going[k] if going[k].length() > 0.05 else (man.aim - man.global_position if man.aim.is_finite() else Vector3.ZERO)
		heading.y = 0.0
		if heading.length() > 0.05:
			man.rotation.y = lerp_angle(man.rotation.y, atan2(heading.x, heading.z), 1.0 - exp(-5.0 * delta))


func _go(next: String) -> void:
	step = next
	_step_time = 0.0

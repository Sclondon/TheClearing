extends SceneTree
## Pictures of the weaver (creatures/weaver/, scripts/enemies/maze_weaver.gd):
## first in a plain grey studio (front, side, three-quarters, back, its head, its
## hands; hovering, gliding, weaving threads between its hands, reaching down
## for the boy and holding him), then in a passage of a real round (World: the
## game's light and mist): drifting over a hall, the threads it leaves across
## it, the boy caught in one, it coming for him, reaching down, lifting him.
## Needs a real window:
##
##     godot --path . --resolution 1280x720 -s res://tools/weaver_shots.gd -- <folder> [studio|maze]

var folder := "weaver_shots"
var only := ""
var camera: Camera3D
var stage: Node3D


class Driver:
	extends Node
	var body: Node3D
	var speed := 0.0

	func _process(delta: float) -> void:
		body.global_position += body.global_basis.z * speed * delta


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		only = args[1]
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func wait(seconds: float, until := Callable()) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < seconds * 1000.0:
		await process_frame
		if until.is_valid() and until.call():
			return true
	return false


func _run() -> void:
	if only != "maze":
		await _studio()
	if only != "studio":
		await _maze()
	quit()


func _studio() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.61, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.6)
	env.ambient_light_energy = 0.85
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	stage.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, 0.7, 0.0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	floor.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.49)
	floor.material_override = mat
	stage.add_child(floor)
	var ground := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(80.0, 1.0, 80.0)
	ground_shape.shape = slab
	ground_shape.position.y = -0.5
	ground.add_child(ground_shape)
	stage.add_child(ground)
	camera = Camera3D.new()
	camera.fov = 40.0
	stage.add_child(camera)
	camera.make_current()

	var weaver := Weaver.new()
	weaver.voice = false
	weaver.seed_value = 5
	stage.add_child(weaver)
	# (it hangs off the ground)
	weaver.position = Vector3(0.0, 0.8, 0.0)
	await wait(0.6)
	var mid := weaver.global_position + Vector3.UP * 1.9
	_look_from(mid + Vector3(0.0, 0.1, 7.0), mid)
	await shot("01_front")
	_look_from(mid + Vector3(7.0, 0.1, 0.0), mid)
	await shot("02_side")
	_look_from(mid + Vector3(5.0, 1.2, 5.0), mid)
	await shot("03_three_quarter")
	_look_from(mid + Vector3(-3.5, 1.5, -6.0), mid)
	await shot("04_back")
	_look_from(mid + Vector3(1.5, -1.6, 5.5), mid + Vector3.UP * 0.3)
	await shot("05_from_below")
	var head := weaver.head_position()
	_look_from(head + Vector3(0.6, 0.0, 1.3), head)
	await shot("06_head")
	_look_from(weaver.chest_position() + Vector3(0.4, -0.4, 2.2), weaver.chest_position() + Vector3.DOWN * 0.5)
	await shot("07_hands")
	await wait(0.7)
	_look_from(weaver.chest_position() + Vector3(0.4, -0.4, 2.2), weaver.chest_position() + Vector3.DOWN * 0.5)
	await shot("08_hands_later")
	# Gliding.
	var drive := Driver.new()
	drive.body = weaver
	stage.add_child(drive)
	drive.speed = 2.5
	await wait(1.6)
	mid = weaver.global_position + Vector3.UP * 1.9
	_look_from(mid + weaver.global_basis.x * 7.0 + Vector3.UP * 0.5, mid)
	await shot("09_gliding_side")
	_look_from(mid + weaver.global_basis.z * 6.0 + weaver.global_basis.x * 2.5 + Vector3.UP * 0.3, mid)
	await shot("10_gliding_coming")
	drive.speed = 0.0
	weaver.position = Vector3(0.0, 0.8, 0.0)
	weaver.settle()
	await wait(1.0)
	# Weaving: threads drawn between its hands.
	var threads := WeaverThreads.new()
	stage.add_child(threads)
	weaver.weaving = 1.0
	await wait(1.0)
	var lines := []
	for k in 3:
		lines.append(threads.add(Vector3.ZERO, Vector3.RIGHT))
	for t in 30:
		var hands := weaver.weave_hands()
		for k in 3:
			threads.remove(lines[k])
			lines[k] = threads.add(hands[k * 2], hands[k * 2 + 1])
		await process_frame
	mid = weaver.chest_position()
	_look_from(mid + Vector3(1.0, 0.0, 3.4), mid + Vector3.DOWN * 0.4)
	await shot("11_weaving")
	weaver.weaving = 0.0
	for k in 3:
		threads.remove(lines[k])
	# A strand across, and the boy caught in it; it reaches down for him and holds him.
	var boy: Node3D = load("res://player.tscn").instantiate()
	boy.set(&"takes_input", false)
	stage.add_child(boy)
	boy.global_position = Vector3(0.0, 0.05, 1.6)
	var strand := []
	for k in 3:
		var y := 0.95 + k * 0.3
		strand.append(threads.add(Vector3(-4.0, y, 1.8), Vector3(4.0, y, 1.8)))
	await wait(0.5)
	threads.drag(strand[1], boy.global_position + Vector3(0.0, 1.1, 0.25))
	threads.pluck(strand[0], 1.0)
	_look_from(Vector3(2.2, 1.4, 5.5), Vector3(0.0, 1.2, 1.6))
	await shot("12_caught_in_the_strand")
	weaver.reach_point = boy.global_position + Vector3.UP * 0.9
	weaver.reaching = 0.6
	await wait(1.2)
	_look_from(Vector3(4.0, 2.0, 5.5), Vector3(0.0, 1.6, 0.8))
	await shot("13_reaching")
	weaver.reaching = 1.0
	await wait(0.8)
	_look_from(Vector3(-3.5, 1.5, 5.0), Vector3(0.0, 1.5, 0.8))
	await shot("14_reached")
	stage.queue_free()
	await process_frame


func _look_from(from: Vector3, at: Vector3) -> void:
	camera.position = from
	camera.look_at(at)


# --- In the maze ---

func _maze() -> void:
	pass

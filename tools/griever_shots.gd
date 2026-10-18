extends SceneTree
## Pictures of the Griever to look at, in a maze built in a bare scene with the
## game's sky, fog and sun: coming down a passage at the boy, winding up and
## striking there; walking in the clearing, and striking there; close to; and
## a run of frames of it walking (a short film, as numbered pictures). Needs a
## real window (the engine draws nothing headless):
##
##     godot --path . --resolution 1280x720 -s res://tools/griever_shots.gd -- <folder>

var folder := "shots/griever"
var scene: Node3D
var maze: Maze
var camera: Camera3D
var boy: Node3D
var griever: Griever


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	_run()


func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png" % [folder, name])


func wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await physics_frame
		left -= 1.0 / 60.0


## Waits until `test` is true (or `most` seconds).
func wait_for(test: Callable, most := 20.0) -> bool:
	var left := most
	while left > 0.0:
		if test.call():
			return true
		await physics_frame
		left -= 1.0 / 60.0
	return false


func _run() -> void:
	scene = Node3D.new()
	root.add_child(scene)
	_sky()
	maze = Maze.generate(Maze.seed_for("SHOT", 1))
	var builder := MazeBuilder.new()
	scene.add_child(builder)
	builder.build(maze)
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.far = 600.0
	scene.add_child(camera)
	camera.make_current()
	boy = load("res://player.tscn").instantiate()
	boy.takes_input = false
	scene.add_child(boy)
	await wait(0.2)

	# A long straight passage: the boy at one end, the griever at the other.
	var run := _straight()
	var a: Vector2i = run[0]
	var b: Vector2i = run[1]
	var along := Vector3(b.x - a.x, 0.0, b.y - a.y).normalized()
	boy.global_position = maze.world(a) + Vector3.UP * 0.1
	boy.rotation.y = atan2(along.x, along.z)
	griever = _spawn(b, atan2(along.x, along.z))
	griever.targets = []
	await wait(1.0)
	_camera_behind(maze.world(a), along, 4.5, 1.7)
	await shot("1_passage_far")
	# It comes on (after the boy).
	griever.targets = [boy]
	griever.alert(boy.global_position)
	await wait_for(func() -> bool: return griever.global_position.distance_to(boy.global_position) < 20.0, 40.0)
	await shot("2_passage_coming")
	await wait_for(func() -> bool: return griever.state == Griever.State.WINDUP)
	await wait(0.4)
	await shot("3_passage_windup")
	await wait_for(func() -> bool: return griever.stinger.throw > 0.9, 3.0)
	await shot("4_passage_strike")
	# From the side, low, in the passage.
	griever.targets = []
	await wait(1.5)
	var side := Vector3(-along.z, 0.0, along.x)
	camera.global_position = griever.global_position + side * 4.0 - along * 7.0 + Vector3.UP * 1.2
	camera.look_at(griever.global_position + Vector3.UP * 2.6)
	await shot("5_passage_side")
	# Close, to see the flesh.
	camera.global_position = griever.body.origin + griever.body.basis.z * -3.2 + side * 2.0 + Vector3.UP * 0.6
	camera.look_at(griever.body.origin + Vector3.UP * 0.4)
	await shot("6_close")

	# Wandering down the passage along one wall, climbing it with the legs on
	# that side: a short film, seen from ahead of it.
	griever.queue_free()
	boy.global_position = Vector3(0.0, 0.1, 0.0)
	await wait(0.1)
	griever = _spawn(a, atan2(-along.x, -along.z))
	griever.targets = [boy]
	griever.walk_to(b, 1)
	await wait(3.0)
	for i in 12:
		camera.global_position = griever.global_position + along * 12.0 - side * 3.0 + Vector3.UP * 2.0
		camera.look_at(griever.global_position + Vector3.UP * 2.4 + side * 1.5)
		await shot("film_%02d" % i)
		await wait(0.12)

	# The clearing: it walks after the boy, in the open.
	griever.queue_free()
	await wait(0.1)
	boy.global_position = Vector3(10.0, 0.1, 18.0)
	griever = _spawn(maze.cell_at(Vector3(-10.0, 0.0, -14.0)), 0.0)
	griever.global_position = Vector3(-10.0, 0.0, -14.0)
	griever.targets = [boy]
	await wait(2.5)
	var to_boy := (boy.global_position - griever.global_position).normalized()
	camera.global_position = griever.global_position + Vector3(-to_boy.z, 0, to_boy.x) * 9.0 + to_boy * 6.0 + Vector3.UP * 2.5
	camera.look_at(griever.global_position + Vector3.UP * 2.0)
	await shot("7_clearing_walk")
	await wait_for(func() -> bool: return griever.state == Griever.State.WINDUP)
	await wait(0.45)
	_camera_behind(boy.global_position, (griever.global_position - boy.global_position).normalized(), 5.0, 1.8)
	await shot("8_clearing_windup")
	await wait_for(func() -> bool: return griever.stinger.throw > 0.9, 3.0)
	await shot("9_clearing_strike")
	# From above and behind, as the game's camera might see it.
	await wait(1.2)
	griever.targets = []
	camera.global_position = griever.global_position + Vector3(6.0, 9.0, 8.0)
	camera.look_at(griever.global_position + Vector3.UP * 1.5)
	await shot("10_clearing_above")
	quit()


func _spawn(cell: Vector2i, facing: float) -> Griever:
	var g := Griever.new()
	scene.add_child(g)
	g.setup(maze, cell, facing)
	return g


## The camera behind a point, looking along `look`, low as the game's is.
func _camera_behind(at: Vector3, look: Vector3, back: float, high: float) -> void:
	camera.global_position = at - look * back + Vector3.UP * high + Vector3(-look.z, 0.0, look.x) * 0.8
	camera.look_at(at + look * 12.0 + Vector3.UP * 2.6)


## The ends of the longest straight run of open cells (outside the clearing).
func _straight() -> Array:
	var best: Array = [Vector2i.ZERO, Vector2i.ZERO]
	var best_length := 0
	for y in maze.size:
		for x in maze.size:
			var cell := Vector2i(x, y)
			if maze.in_clearing(cell):
				continue
			for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var end := cell
				while maze.inside(end + step) and not maze.blocked(end, step) and not maze.in_clearing(end + step):
					end += step
				var length := (end - cell).length()
				if length > best_length:
					best_length = int(length)
					best = [cell, end]
	return best


func _sky() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.42, 0.52, 0.62)
	sky_material.sky_horizon_color = Color(0.72, 0.72, 0.66)
	sky_material.ground_horizon_color = Color(0.45, 0.48, 0.44)
	sky_material.ground_bottom_color = Color(0.22, 0.24, 0.2)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.5, 0.55, 0.54)
	environment.fog_density = 0.0075
	environment.fog_sky_affect = 0.35
	var world := WorldEnvironment.new()
	world.environment = environment
	scene.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	scene.add_child(sun)

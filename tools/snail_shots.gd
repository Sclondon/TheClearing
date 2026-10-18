extends SceneTree
## Pictures of the giant snail (creatures/snail): close up on a plain floor
## under the game's kind of light (each view, the head and its eye stalks, the
## shell, beside the boy for scale, crawling with its trail behind it, a
## flinch, withdrawn into its shell, and over a wall: up the face, over the
## top and down), and in a passage of a real round (crawling down a hall after
## the boy, its trail across the hall, up a wall). Says how many draws a frame
## takes. Needs a real window (the engine draws nothing headless):
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/snail_shots.gd -- <folder> [studio|maze|all]

var folder := "snail_shots"
var mode := "all"
var camera: Camera3D
var stage_root: Node3D
## Whatever is moving the snail along, called every frame while a picture is
## taken too (so that it is still going when it is).
var mover := Callable()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		mode = args[1]
	DirAccess.make_dir_recursive_absolute(folder)
	# (a steady 60 a second, so that what is moved by the frame goes as far as it should)
	Engine.max_fps = 60
	_run.call_deferred()


func _run() -> void:
	if mode in ["studio", "all"]:
		await _studio()
	if mode in ["maze", "all"]:
		await _maze()
	quit()


func shot(name: String) -> void:
	for i in 2:
		if mover.is_valid():
			mover.call(root.get_process_delta_time())
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func frames(count: int) -> void:
	for i in count:
		if mover.is_valid():
			mover.call(root.get_process_delta_time())
		await process_frame


## Looks at `target` from `offset` away (in the snail's own space, if `snail` is given).
func look(target: Vector3, offset: Vector3, snail: Node3D = null, fov := 40.0) -> void:
	var from := offset
	if snail:
		from = snail.global_basis.orthonormalized() * offset
	camera.fov = fov
	camera.global_position = target + from
	camera.look_at(target, Vector3.UP)


# --- On a plain floor ---

func _studio() -> void:
	stage_root = Node3D.new()
	root.add_child(stage_root)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.64, 0.66)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.62, 0.64, 0.66)
	environment.fog_density = 0.006
	var world := WorldEnvironment.new()
	world.environment = environment
	stage_root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(35.0), 0.0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	stage_root.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400.0, 400.0)
	floor.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.42, 0.4, 0.37)
	floor.material_override = ground
	stage_root.add_child(floor)
	camera = Camera3D.new()
	stage_root.add_child(camera)
	camera.current = true
	camera.far = 600.0

	var snail := Snail.new()
	stage_root.add_child(snail)
	snail.global_transform = Transform3D(Basis(), Vector3(0.0, 0.0, 0.0))
	snail.settle()
	await frames(20)
	# (its middle is some 3.5 m behind its origin, the front of its sole)
	var middle := Vector3(0.0, 1.6, -3.4)
	look(middle, Vector3(14.0, 1.5, 0.0), snail)
	await shot("s01_left")
	look(middle, Vector3(-14.0, 1.5, 0.0), snail)
	await shot("s02_right")
	look(middle, Vector3(10.0, 4.0, 10.0), snail)
	await shot("s03_three_quarter")
	look(middle, Vector3(-9.0, 5.0, -10.0), snail)
	await shot("s04_back_quarter")
	look(middle + Vector3(0.0, 0.0, 1.0), Vector3(0.0, 2.5, 13.0), snail)
	await shot("s05_front")
	look(Vector3(0.0, 1.6, -0.6), Vector3(3.2, 0.6, 3.4), snail)
	await shot("s06_head")
	look(Vector3(0.0, 1.7, -0.6), Vector3(-1.2, 0.3, 4.2), snail)
	await shot("s07_eyes")
	look(Vector3(0.0, 2.6, -3.5), Vector3(-5.0, 1.0, 3.0), snail)
	await shot("s08_shell_mouth")
	look(Vector3(0.0, 0.1, -3.4), Vector3(9.0, 12.0, 0.5), snail)
	await shot("s09_top")

	# Beside the boy, for scale
	var ground_body := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	ground_shape.shape = WorldBoundaryShape3D.new()
	ground_body.add_child(ground_shape)
	stage_root.add_child(ground_body)
	var boy: Node3D = load("res://player.tscn").instantiate()
	boy.set(&"takes_input", false)
	stage_root.add_child(boy)
	Looks.apply(boy.get_node("Rig") as CharacterRig, Looks.decode("", 0))
	boy.global_position = Vector3(2.4, 0.05, 2.2)
	boy.rotation.y = PI * 0.85
	await frames(20)
	look(Vector3(0.0, 1.6, -1.5), Vector3(11.0, 1.2, 7.0))
	await shot("s10_beside_the_boy")
	snail.aim = boy.global_position + Vector3.UP * 1.4
	await frames(90)
	look(Vector3(0.6, 1.6, 0.0), Vector3(5.0, 0.8, 6.0))
	await shot("s11_reaching_for_the_boy")
	snail.flinch(1)
	await frames(10)
	await shot("s12_flinch")
	boy.queue_free()
	snail.aim = Vector3.INF

	# Crawling, its trail behind it
	mover = func(step: float) -> void:
		snail.global_position += snail.global_basis.z.normalized() * 1.1 * step
	await frames(400)
	look(snail.global_position + Vector3(0.0, 1.5, -4.0), Vector3(10.0, 5.0, -8.0), snail)
	await shot("s13_crawling_trail")
	look(snail.global_position + Vector3(0.0, 0.5, -2.0), Vector3(5.0, 1.0, 1.5), snail)
	await shot("s14_crawling_foot")
	# A slow turn
	mover = func(step: float) -> void:
		snail.rotate_y(0.25 * step)
		snail.global_position += snail.global_basis.z.normalized() * 1.1 * step
	await frames(300)
	look(snail.global_position + Vector3(0.0, 1.0, -4.0), Vector3(0.0, 16.0, -6.0), snail)
	await shot("s15_turning_from_above")
	mover = Callable()
	# Withdrawn
	snail.withdrawn = true
	await frames(60)
	look(snail.global_position + Vector3(0.0, 1.4, -3.5), Vector3(9.0, 3.0, 6.0), snail)
	await shot("s16_withdrawn")
	snail.withdrawn = false
	await frames(40)
	await shot("s17_coming_out")
	await frames(80)
	await shot("s18_out_again")

	# Over a wall: up its face, over the top and down the far side
	var wall := StaticBody3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(16.0, 7.0, 3.0)
	var wall_mesh := MeshInstance3D.new()
	wall_mesh.mesh = box
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.55, 0.55, 0.53)
	wall_mesh.material_override = concrete
	wall.add_child(wall_mesh)
	stage_root.add_child(wall)
	var start := snail.global_position
	var heading := snail.global_basis.z.normalized()
	heading.y = 0.0
	heading = heading.normalized()
	wall.global_position = start + heading * 9.0 + Vector3.UP * 3.5
	wall.global_basis = Basis(Vector3.UP, atan2(heading.x, heading.z))
	var travelled := [0.0]
	mover = func(step: float) -> void:
		travelled[0] += 1.2 * step
		snail.global_transform = _over_wall(start, heading, 7.5, 7.0, 3.0, travelled[0])
	await frames(int(10.0 / 1.2 * 60.0))
	look(snail.global_position + Vector3.UP * 1.0, Basis(Vector3.UP, atan2(heading.x, heading.z)) * Vector3(12.0, -1.5, -6.0))
	await shot("s19_up_the_wall")
	await frames(int(4.5 / 1.2 * 60.0))
	look(snail.global_position, Basis(Vector3.UP, atan2(heading.x, heading.z)) * Vector3(13.0, 2.0, -4.0))
	await shot("s20_up_the_wall_side")
	await frames(int(4.0 / 1.2 * 60.0))
	look(snail.global_position + Vector3.UP * 1.0, Basis(Vector3.UP, atan2(heading.x, heading.z)) * Vector3(12.0, 4.0, 2.0))
	await shot("s21_over_the_top")
	await frames(int(6.0 / 1.2 * 60.0))
	look(snail.global_position, Basis(Vector3.UP, atan2(heading.x, heading.z)) * Vector3(12.0, 0.0, 8.0))
	await shot("s22_down_the_far_side")
	mover = Callable()
	stage_root.queue_free()
	await frames(4)


## Where the front of a snail's sole is (and which way it faces) `along` metres
## from `start`, crawling straight at a wall `to_wall` away, `high` and `thick`:
## up its face, over the top and down the far side.
static func _over_wall(start: Vector3, heading: Vector3, to_wall: float, high: float, thick: float, along: float) -> Transform3D:
	var up := Vector3.UP
	var face := -heading
	var legs := [to_wall, high, thick, high]
	var left := along
	if left < legs[0]:
		return Transform3D(RigFrame.of(up, heading), start + heading * left)
	left -= legs[0]
	var foot := start + heading * to_wall
	if left < legs[1]:
		return Transform3D(RigFrame.of(face, up), foot + up * left)
	left -= legs[1]
	if left < legs[2]:
		return Transform3D(RigFrame.of(up, heading), foot + up * high + heading * left)
	left -= legs[2]
	if left < legs[3]:
		return Transform3D(RigFrame.of(heading, -up), foot + up * (high - left) + heading * thick)
	left -= legs[3]
	return Transform3D(RigFrame.of(up, heading), foot + heading * (thick + left))


class RigFrame:
	static func of(up: Vector3, forward: Vector3) -> Basis:
		return SnailRig._frame(up, forward)


# --- In the maze ---

func _maze() -> void:
	var world: Node3D = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	var maze: Maze = world.maze
	var boy: Node3D = world.player
	boy.set(&"takes_input", false)
	# Everything else that hunts is put away, for clear pictures.
	for node: Node in world.get_children():
		if node is MazeEnemies or node is Griever:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			(node as Node3D).visible = false
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.far = 400.0
	# A long straight hall to put it in
	var nav := MazeNav.new(maze)
	var best := Vector2i.ZERO
	var best_run := 0
	var best_step := Vector2i(1, 0)
	for cell: Vector2i in nav.lairs(3):
		for step: Vector2i in Maze.STEPS:
			var run := 0
			var at := cell
			while run < 6 and not maze.blocked(at, step) and maze.inside(at + step) and not maze.in_clearing(at + step):
				at += step
				run += 1
			if run > best_run and maze.blocked(at, step):
				best_run = run
				best = cell
				best_step = step
	var way := Vector3(best_step.x, 0.0, best_step.y)
	var side := Vector3(-way.z, 0.0, way.x)
	var up := Vector3.UP
	var start := maze.world(best)
	var snail := MazeSnail.new()
	snail.maze = maze
	snail.position = start + way * 2.0
	snail.rotation.y = atan2(way.x, way.z)
	world.add_child(snail)
	boy.global_position = start + way * 30.0 + side * 1.5
	await frames(30)
	# It notices him and comes down the hall after him, leaving its trail
	snail.notice(boy)
	await frames(60 * 14)
	var head: Vector3 = snail.global_position
	look(head + up * 1.5, way * 9.0 + side * 6.0 + up * 3.0)
	await shot("m01_after_him")
	look(head - way * 4.0 + up * 1.5, -way * 12.0 + side * 5.0 + up * 6.0)
	await shot("m02_its_trail")
	var over := boy.global_position + up * 1.6 - way * 1.0 + side * 0.5
	look(head + up * 1.5, over - head - up * 1.5)
	await shot("m03_from_the_boy")
	# Up out of its reach on a wall top: it climbs after him
	# (a wall between two passages of the ring, near it, with a top to stand on)
	var here := maze.cell_at(snail.global_position)
	var across := Vector2i(1, 0)
	var best_far := INF
	for cell: Vector2i in nav.lairs(2):
		for s: Vector2i in Maze.STEPS:
			var on_top := maze.world(cell) + Vector3(s.x, 0.0, s.y) * (Maze.CELL * 0.5)
			var far := on_top.distance_to(snail.global_position)
			if far < best_far and maze.blocked(cell, s) and maze.inside(cell + s) and not maze.ring_wall(cell, s) and not maze.blocked(cell, -s) and _top_at(world, on_top, maze.wall_height(cell, s)):
				best_far = far
				here = cell
				across = s
	var out := Vector3(across.x, 0.0, across.y)
	var top := maze.world(here) + out * (Maze.CELL * 0.5) + up * (maze.wall_height(here, across) + 0.3)
	boy.global_position = top
	# (it is put near the foot of the wall, as if it had followed him there)
	snail._put(maze.world(here) - out * 4.0, 0.0)
	snail.up = Vector3.UP
	snail.ahead = out
	snail.notice(boy)
	way = Vector3(-out.z, 0.0, out.x)
	await frames(60 * 16)
	head = snail.global_position
	look(head + up * 1.0, -out * 7.0 - way * 6.0 - up * 2.0)
	await shot("m04_up_the_wall")
	look(head - up * 1.5, -out * 6.0 + way * 7.0 - up * (head.y - 1.6))
	await shot("m05_from_below")
	await frames(60 * 14)
	head = snail.global_position
	look(head, -out * 8.0 - way * 6.0 + up * 3.0)
	await shot("m06_higher")
	print("snail on the wall: %.1f m up, climbing %s, mode %s" % [snail.global_position.y, snail.climbing, MazeSnail.Mode.keys()[snail.mode]])


## Whether there is a wall top `high` up at `point` (its x and z) to stand on.
static func _top_at(world: Node3D, point: Vector3, high: float) -> bool:
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, high + 20.0, point.z), Vector3(point.x, 0.5, point.z))
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and absf((hit.position as Vector3).y - high) < 0.6

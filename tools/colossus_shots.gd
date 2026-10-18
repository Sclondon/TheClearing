extends SceneTree
## Pictures of the colossus (creatures/colossus/, and MazeColossus, its hunter
## in the maze). Needs a real window (the engine draws nothing headless):
##
##     godot --path . --resolution 1280x720 --audio-driver Dummy -s res://tools/colossus_shots.gd -- <folder> [model|maze|all]
##
## model: on a bare floor in the maze's light, between two walls as high as the
## first ring's: the whole of it from the front, three quarters, the side and
## behind; its face; a stride over a wall (frames through it); a reach (frames
## through it). maze: in a real round: from the boy's height in a hall as it
## strides over (the money shot), a foot coming down in the hall, the hand
## reaching into a hall, from the middle of the clearing as it hauls itself up
## to look over the great wall, the same from over the maze, and how many draws
## it costs. clearing: only those last two.

var folder := "colossus_shots"
var what := "all"
var camera: Camera3D
var giant: Colossus
var stage: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		what = args[1]
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws, %d primitives)" % [folder, name,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])


func wait(seconds: float, until := Callable()) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		if until.is_valid() and until.call():
			return true
	return false


func look(from: Vector3, at: Vector3, fov := 50.0) -> void:
	camera.global_position = from
	camera.fov = fov
	camera.look_at(at)


func _run() -> void:
	if what in ["model", "all"]:
		await _model()
	if what in ["maze", "all", "clearing"]:
		await _round()
	if what in ["maze", "all"]:
		await _maze()
	if what in ["maze", "all", "clearing"]:
		await _from_the_clearing()
	quit()


# --- On its own ---

func _box(at: Vector3, size: Vector3, colour: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	mesh.material_override = material
	body.add_child(mesh)
	stage.add_child(body)
	return body


func _model() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	MazeLight.put(stage)
	# (the mist thinned, to see the whole of it)
	for child in stage.get_children():
		if child is WorldEnvironment:
			(child as WorldEnvironment).environment.fog_density = 0.0012
	_box(Vector3(0, -0.5, 0), Vector3(1200, 1, 1200), Color(0.33, 0.31, 0.28))
	# Two walls as the first ring's: 34 m high, 12 m thick, a hall of 16 m between.
	_box(Vector3(-14, 17, 0), Vector3(12, 34, 400), Color(0.52, 0.52, 0.5))
	_box(Vector3(14, 17, 60), Vector3(12, 34, 280), Color(0.52, 0.52, 0.5))
	camera = Camera3D.new()
	camera.far = 3000.0
	stage.add_child(camera)
	camera.make_current()
	var boy: Node3D = load("res://player.tscn").instantiate()
	boy.takes_input = false
	stage.add_child(boy)
	boy.global_position = Vector3(3.0, 0.05, 30.0)
	boy.rotation.y = PI
	giant = Colossus.new()
	giant.sound = false
	stage.add_child(giant)
	giant.put(Vector3(0, 0, 0), 0.0)
	await wait(1.0)
	var middle := Vector3(0, 50, 0)
	look(Vector3(0, 40, 190), middle, 45)
	await shot("m1_front")
	look(Vector3(140, 50, 130), middle, 45)
	await shot("m2_three_quarter")
	look(Vector3(190, 45, 0), middle, 45)
	await shot("m3_side")
	look(Vector3(-110, 70, -150), middle, 45)
	await shot("m4_behind")
	look(giant.eye() + Vector3(18, -4, 40), giant.eye() + Vector3(0, -6, 0), 40)
	await shot("m5_face")
	look(Vector3(3.5, 1.6, 34), Vector3(0, 40, 0), 70)
	await shot("m6_up_from_the_boy")
	# A stride over the wall on its right.
	var to := Vector3(-28, 0, 22)
	giant.facing = -0.6
	giant.step(Colossus.RIGHT, to, -0.6, 34.0)
	var marks := [0.2, 0.45, 0.7, 0.9]
	for k in marks.size():
		await wait(30.0, func() -> bool: return giant.step_progress() >= marks[k] or giant.stepping() < 0)
		look(Vector3(120, 40, 140), Vector3(-10, 40, 10), 50)
		await shot("w%d_stride_%d" % [k + 1, int(marks[k] * 100)])
	await wait(4.0)
	# A reach, at the boy.
	giant.facing = 0.3
	await wait(2.0)
	giant.reach(boy.global_position)
	for stage_name: String in ["HOVER", "STRIKE", "SWEEP"]:
		await wait(15.0, func() -> bool: return Colossus.Reach.keys()[giant.reach_stage()] == stage_name)
		if stage_name == "STRIKE":
			await wait(0.4)
		look(Vector3(110, 30, 110), Vector3(0, 30, 15), 50)
		await shot("r_%s" % stage_name.to_lower())
	stage.queue_free()
	await wait(0.2)


# --- In the maze ---

var world: Node3D
var maze: Maze
var boy: Player
var hunter: MazeColossus


## A cell in the first ring with a long straight run of hall on from it (`run`
## cells open each way along), and that way; the deepest such run first.
func _long_hall(run: int, near_clearing := false) -> Array:
	var nav := MazeNav.new(maze)
	for c: Vector2i in nav.lairs(1):
		if maze.ring_of(c) != 1:
			continue
		if near_clearing and maze.depth_in_ring(c) != maze.styles[0].border_wall_thickness_cells:
			continue
		for step: Vector2i in Maze.STEPS:
			var ok := true
			for k in range(-run, run):
				if maze.blocked(c + step * k, step) or maze.ring_of(c + step * (k + 1)) != 1:
					ok = false
					break
			if ok:
				return [c, step]
	return []


func _spawn_at(at: Vector3, yaw: float) -> MazeColossus:
	if hunter:
		hunter.queue_free()
		await process_frame
	hunter = MazeColossus.new()
	hunter.maze = maze
	hunter.seed_choices(3)
	hunter.position = at
	hunter.rotation.y = yaw
	world.add_child(hunter)
	await process_frame
	return hunter


## A round of the game, with nothing hunting in it, and a camera of our own.
func _round() -> void:
	world = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 2), 0, [{"slot": 0, "look": "p11"}], false)
	maze = world.maze
	boy = world.player
	boy.takes_input = false
	for child in world.get_children():
		if child is MazeEnemy or child is Griever or child is MazeEnemies:
			child.queue_free()
	camera = Camera3D.new()
	camera.far = 3000.0
	world.add_child(camera)
	camera.make_current()
	await wait(0.5)


func _maze() -> void:
	# The money shot: from the boy's height in a long hall, it striding over towards him.
	var found := _long_hall(4)
	if found.is_empty():
		print("no long hall")
		return
	var cell: Vector2i = found[0]
	var step: Vector2i = found[1]
	var along := Vector3(step.x, 0, step.y)
	# (the middle of the hall: between this cell and its neighbour across, if the hall is two wide)
	var across := Vector3(step.y, 0, step.x)
	var middle := maze.world(cell)
	for side: float in [1.0, -1.0]:
		var other := cell + Vector2i(int(across.x * side), int(across.z * side))
		if not maze.blocked(cell, Vector2i(int(across.x * side), int(across.z * side))) and maze.ring_of(other) == 1:
			middle = (maze.world(cell) + maze.world(other)) * 0.5
			break
	world.put_player(middle + Vector3.UP * 0.05, atan2(along.x, along.z))
	await wait(0.5)
	var giant := await _spawn_at(middle + along * 110.0, atan2(-along.x, -along.z))
	giant.sense_range = 0.0
	giant._goal = middle - along * 300.0
	# (step by step until it is near, a foot in the air)
	for k in 14:
		await wait(14.0, func() -> bool: return giant.figure.stepping() >= 0 and giant.figure.step_progress() > 0.45)
		var d := Vector2(giant.figure.pelvis().x - middle.x, giant.figure.pelvis().z - middle.z).length()
		if d < 60.0:
			break
		await wait(14.0, func() -> bool: return giant.figure.stepping() < 0)
	look(middle - along * 6.0 + across * 2.5 + Vector3.UP * 1.5, giant.figure.pelvis() + Vector3.UP * 25.0, 72.0)
	await shot("a1_money_striding")
	look(middle - along * 9.0 - across * 3.0 + Vector3.UP * 1.2, giant.figure.eye() * 0.5 + giant.figure.pelvis() * 0.5, 80.0)
	await shot("a1b_money_wide")
	# A foot coming down in the hall: its shadow, and the dust when it lands.
	await wait(12.0, func() -> bool: return giant.figure.stepping() >= 0 and giant.figure.step_progress() < 0.3)
	var foot := giant.figure.stepping()
	var landing := giant.figure.landing(foot)
	await wait(12.0, func() -> bool: return giant.figure.step_progress() > 0.84)
	var to_land := landing - middle
	to_land.y = 0.0
	look(landing - to_land.normalized() * 30.0 + across * 4.0 + Vector3.UP * 1.6, landing + Vector3.UP * 12.0, 70.0)
	await shot("b1_foot_coming_down")
	await wait(4.0, func() -> bool: return giant.figure.stepping() < 0)
	await wait(0.6)
	await shot("b2_foot_down_dust")

	# The hand reaching into the hall for him.
	giant.queue_free()
	hunter = null
	await wait(0.3)
	world.put_player(middle + Vector3.UP * 0.05, atan2(along.x, along.z))
	var reacher := await _spawn_at(middle + along * 38.0, atan2(-along.x, -along.z))
	reacher.sense_range = 120.0
	boy.add_to_group(&"maze_players")
	await wait(10.0, func() -> bool: return reacher.figure.reach_stage() == Colossus.Reach.HOVER)
	await wait(0.8)
	look(middle - along * 22.0 + across * 3.0 + Vector3.UP * 1.6, middle + Vector3.UP * 18.0, 75.0)
	await shot("c1_hand_hovering")
	look(middle + across * 6.0 - along * 4.0 + Vector3.UP * 1.4, reacher.figure.hand_point(), 80.0)
	await shot("c2_hand_overhead")
	await wait(10.0, func() -> bool: return reacher.figure.reach_stage() == Colossus.Reach.SWEEP)
	print("  the hand came down %.1f m from him, %.1f m up" % [Vector2(reacher.figure.hand_point().x - boy.global_position.x, reacher.figure.hand_point().z - boy.global_position.z).length(), reacher.figure.hand_point().y])
	look(middle - along * 26.0 + across * 2.0 + Vector3.UP * 2.0, reacher.figure.hand_point() + Vector3.UP * 4.0, 70.0)
	await shot("c3_hand_down")
	boy.remove_from_group(&"maze_players")
	reacher.queue_free()
	hunter = null


func _from_the_clearing() -> void:
	# From the clearing: over its great wall (in the first hall beyond it, near the middle of a side).
	var wall_cell := Vector2i(-1, -1)
	var best := INF
	for c: Vector2i in MazeNav.new(maze).lairs(1):
		if maze.ring_of(c) == 1 and maze.depth_in_ring(c) == maze.styles[0].border_wall_thickness_cells:
			var at := maze.world(c)
			var across_side := minf(absf(at.x), absf(at.z))
			if across_side > 30.0 and across_side < best:
				best = across_side
				wall_cell = c
	if wall_cell.x >= 0:
		var spot := maze.world(wall_cell)
		var giant2 := await _spawn_at(spot, 0.0)
		giant2.sense_range = 0.0
		var out := spot.normalized()
		out.y = 0.0
		var square := Vector3(signf(out.x), 0, 0) if absf(out.x) > absf(out.z) else Vector3(0, 0, signf(out.z))
		# (it leans on the top of the great wall and looks over)
		giant2._pause = 1e9
		print("  peering: %s" % giant2._start_peering())
		await wait(9.0)
		var inner_face := maze.clearing * Maze.CELL * 0.5
		# (from the middle of the clearing, and from nearer its wall, at his eyes' height)
		var standing := Vector3(spot.x, 0.0, spot.z) - square * (spot.dot(square) - 0.0)
		world.put_player(standing + Vector3.UP * (maze.ground_height(standing) + 0.1), atan2(square.x, square.z))
		await wait(1.0)
		var eyes := standing - square * 5.0 + Vector3(square.z, 0, square.x) * 2.0
		eyes.y = maze.ground_height(eyes) + 1.6
		look(eyes, Vector3(spot.x, 80.0, spot.z), 40.0)
		await shot("d1_from_the_clearing")
		# And from above the maze, the whole of it among the walls.
		look(spot - square * 160.0 + Vector3.UP * 95.0 + Vector3(square.z, 0, square.x) * 120.0, giant2.figure.pelvis() + Vector3.UP * 10.0, 50.0)
		await shot("e1_over_the_maze")
	print("done")

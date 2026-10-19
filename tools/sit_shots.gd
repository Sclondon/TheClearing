extends SceneTree
## Pictures of the boy sat on the ground, side on and at ground level, to see
## his seat on it and not sunk into it: on the flat floor of a hall, on the
## clearing's hills, and down in the tall grass's hollow; and a runner sat
## beside him in the hall. Prints, for each, how high his hips and his lowest
## bones are over the ground under him. Needs a real window:
##
##     godot --path . --resolution 1280x720 --audio-driver Dummy -s res://tools/sit_shots.gd -- <folder>

var main: Node
var folder := "sit_shots"
var world
var maze: Maze
var eye: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await physics_frame
		left -= 1.0 / 60.0


func shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png" % [folder, name])


func ground_under(at: Vector3) -> float:
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, at + Vector3.DOWN * 3.0, 1))
	return (hit.position as Vector3).y if not hit.is_empty() else NAN


## How he sits: his body's height over the ground, and his hips' and lowest bone's.
func report(name: String, boy: Player) -> void:
	var rig: CharacterRig = boy.get_node(^"Rig")
	var skeleton: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0]
	var ground := ground_under(boy.global_position)
	var low := INF
	var low_name := ""
	for i in skeleton.get_bone_count():
		var y := (skeleton.global_transform * skeleton.get_bone_global_pose(i)).origin.y
		if y < low:
			low = y
			low_name = skeleton.get_bone_name(i)
	var hips := (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(&"hips"))).origin.y
	print("  at ", boy.global_position, " ground ", ground)
	print("%s: body %.3f over the ground, hips %.3f, lowest bone %s %.3f (sit %.2f, floor %s)" % [name, boy.global_position.y - ground, hips - ground, low_name, low - ground, boy.sit_progress, boy.is_on_floor()])


## The camera side on to `boy`, at the height of his seat.
func side_on(boy: Player, near := 1.9) -> void:
	var at := boy.global_position
	var yaw: float = boy.facing_yaw
	var side := Vector3(cos(yaw), 0.0, -sin(yaw))
	eye.global_position = at + side * near + Vector3.UP * 0.22
	eye.look_at(at + Vector3.UP * 0.3)
	eye.make_current()


func sit_at(at: Vector3, yaw: float) -> void:
	world.put_player(at, yaw)
	await wait(0.6)
	for i in 120:
		world.player.sit()
		if world.player.rest != Player.Rest.UP:
			break
		await physics_frame
	await wait(3.0)


## Shot twice: as it is, and with the grass on the ground out of the way.
func shots(name: String) -> void:
	await shot(name)
	var fields := get_nodes_in_group(Grass.FIELDS)
	for field: Node3D in fields:
		field.visible = false
	await shot(name + "_bare")
	for field: Node3D in fields:
		field.visible = true


func _run() -> void:
	await wait(0.5)
	main._begin([{"slot": 0, "look": "p1"}], 0, false, Maze.seed_for("SITS", 1))
	world = main.world
	maze = world.maze
	eye = Camera3D.new()
	eye.fov = 50.0
	world.add_child(eye)
	for enemy in world.enemies.enemies:
		enemy.queue_free()
	world.enemies.enemies.clear()
	world.griever.process_mode = Node.PROCESS_MODE_DISABLED
	world.griever.visible = false
	var boy: Player = world.player
	boy.sleep_after = 0.0
	await wait(0.5)

	# 1. On the flat floor of a hall in the first ring, a runner sat beside him.
	var gate_step: Vector2i = maze.gates[0][0][1]
	var hall: Vector3 = maze.world(maze.gates[0][0][0] + gate_step * 3)
	var along := atan2(float(gate_step.x), float(gate_step.y)) + PI * 0.5
	await sit_at(hall, along)
	report("hall", boy)
	side_on(boy)
	await shots("1_hall")
	if world.runners.runners.size() > 0:
		var runner: MazeRunner = world.runners.runners[0]
		runner.halt()
		runner.global_position = hall + Vector3(cos(along), 0.0, -sin(along)) * 2.5 + Vector3.UP * 0.05
		runner.velocity = Vector3.ZERO
		runner.facing_yaw = along
		runner._reset_visuals()
		runner._lead_rest = 1000.0
		runner._draw_rest = 1000.0
		runner._climb_rest = 1000.0
		runner._set_mode(MazeRunner.Mode.TAKEN)
		await wait(0.5)
		report("runner_standing", runner)
		runner.sit()
		for i in 180:
			runner._far_check = 0.0
			await physics_frame
		report("runner", runner)
		side_on(runner, 2.4)
		await shots("2_runner")

	# 2. On the side of a hill in the clearing.
	var look: ClearingStyle = maze.clearing_style
	var best := Vector3.ZERO
	var best_slope := -1.0
	var half: float = Maze.CLEARING * Maze.CELL * 0.5 - 12.0
	for i in 400:
		var p := Vector2(randf_range(-half, half), randf_range(-half, half))
		if p.length() < 8.0 or look.tall_grass_at(p) > 0.0:
			continue
		var h := look.height_at(p.x, p.y, maze.maze_seed)
		var slope := absf(look.height_at(p.x + 1.0, p.y, maze.maze_seed) - h)
		if h > 0.2 and slope > best_slope:
			best_slope = slope
			best = Vector3(p.x, h + 0.3, p.y)
	print("hill spot ", best, " slope ", best_slope)
	await sit_at(best, 0.0)
	report("hill", boy)
	side_on(boy)
	await shots("3_hill")
	await sit_at(best, PI * 0.5)
	report("hill_across", boy)
	side_on(boy)
	await shots("4_hill_across")

	# 3. In the clearing at its middle, where he wakes at the start of a round.
	await sit_at(Vector3(1.5, 0.3, 1.5), 0.0)
	report("middle", boy)
	side_on(boy)
	await shots("5_middle")

	# 4. Down in the tall grass's hollow.
	var meadow := look.tall_grass_middle()
	if meadow.is_finite():
		await sit_at(Vector3(meadow.x, look.height_at(meadow.x, meadow.y, maze.maze_seed) + 0.3, meadow.y), 0.0)
		report("tall_grass", boy)
		side_on(boy, 1.5)
		await shots("6_tall_grass")
	quit()

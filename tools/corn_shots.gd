extends SceneTree
## Pictures of the corn (Corn, MazeStyle "Plants"): the boy deep in a field at his
## own height, the field from above, and him walking through it seen from the side
## (the stalks parting round him and springing back behind). Prints what it costs:
## laying it down, filling it near the camera, and the frame with it and without.
## Needs a real window:
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/corn_shots.gd -- <folder> [seed]

var main: Node
var folder := "shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run(int(args[1]) if args.size() > 1 else Maze.seed_for("CORN", 1))


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png" % [folder, name])


func wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= 1.0 / 60.0


## Milliseconds a frame, over `frames` frames.
func frame_ms(frames := 90) -> float:
	await process_frame
	var started := Time.get_ticks_usec()
	for f in frames:
		await process_frame
	return (Time.get_ticks_usec() - started) / 1000.0 / frames


func _run(seed_value: int) -> void:
	await wait(1.0)
	main._begin([{"slot": 0, "look": "p11"}], 0, false, seed_value)
	var world = main.world
	var maze: Maze = world.maze
	var builder: MazeBuilder = world.get_node("Maze")
	var corn: Corn = builder.corn
	await wait(1.5)
	var started := Time.get_ticks_usec()
	var again := Corn.plant_maze(maze, builder.features.footprints)
	print("laying the maze's corn down: %.1f ms, %d patches" % [(Time.get_ticks_usec() - started) / 1000.0, again.counts().x])
	again.free()
	# The deepest patch in a room: the middle of a field with no open side.
	var deep := Rect2()
	for patch: Dictionary in corn._patches:
		var rect: Rect2 = patch.rect
		if patch.open == 0 and maze.in_room(maze.cell_at(Vector3(rect.get_center().x, 0.0, rect.get_center().y))):
			deep = rect
			break
	if not deep.has_area():
		deep = corn._patches[0].rect
	var middle := Vector3(deep.get_center().x, 0.0, deep.get_center().y)
	var room: Dictionary = maze.rooms[maze.room_cells.get(maze.cell_at(middle), 0)]
	var field_middle := maze.room_middle(room) if maze.in_room(maze.cell_at(middle)) else middle
	# (stood a few metres off the room's middle: its column or pine is there)
	var stand := field_middle + Vector3(5.0, 0.0, 3.0)
	started = Time.get_ticks_usec()
	corn.fill_near(stand, 60.0)
	print("filling round him: %.1f ms; %s (patches, squares, stalks)" % [(Time.get_ticks_usec() - started) / 1000.0, corn.counts()])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	world.player.global_position = stand + Vector3.UP * 0.3
	world.camera._yaw = 0.6
	world.camera._pitch = 0.12
	world.camera.snap()
	await wait(2.5)
	await shot("in_field")
	var with_corn: float = await frame_ms()
	var primitives := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	corn.visible = false
	var without: float = await frame_ms()
	var primitives_without := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	corn.visible = true
	print("frame in the field: %.2f ms with corn, %.2f without; triangles %d against %d" % [with_corn, without, primitives, primitives_without])
	print("seen from at most %.1f m deep in it (out of it: %.1f)" % [Corn.sight_reach(stand + Vector3.UP, 44.0), Corn.sight_reach(maze.world(maze.cell_at(Vector3.ZERO)) + Vector3.UP, 44.0)])
	# Walking through it: as he is seen playing (the game's camera behind him), then
	# from close above to one side as he stops (the stalks parted round him), a
	# moment later (springing back) and once they have settled.
	world.player.global_position = stand - Vector3(6.0, 0.0, 0.0) + Vector3.UP * 0.3
	world.camera._yaw = atan2(-1.0, 0.0)
	world.camera._pitch = 0.4
	world.camera.snap()
	await wait(1.0)
	await shot("walk_0_before")
	Input.action_press(&"move_up")
	await wait(1.0)
	print("springs: %d, rustling: %d" % [Corn._springs.size(), Corn._all.reduce(func(n: int, c: Corn) -> int: return n + c._voices.size(), 0)])
	await shot("walk_1_game_camera")
	await wait(0.6)
	Input.action_release(&"move_up")
	var close := Camera3D.new()
	world.add_child(close)
	close.fov = 55.0
	var at: Vector3 = world.player.global_position
	close.global_position = at + Vector3(-2.5, 3.6, 2.6)
	close.look_at(at + Vector3(0.6, 0.6, 0.0))
	close.make_current()
	await shot("walk_2_parted")
	print("springs: %d, the most bent %.2f m" % [Corn._springs.size(), Corn._springs.values().reduce(func(most: float, s: Array) -> float: return maxf(most, Vector2(s[3], s[4]).length()), 0.0)])
	await wait(0.45)
	await shot("walk_3_springing_back")
	await wait(2.5)
	await shot("walk_4_settled")
	print("springs left: %d" % Corn._springs.size())
	# A cornfield on the plains past the square sections (Wilds), if there is one.
	var wilds: Wilds = builder.wilds
	if wilds and wilds.corn:
		var field: Array = wilds.lands.cornfields()[0]
		var rect: Rect2 = field[0]
		var spot := Vector3(rect.get_center().x, 0.0, rect.get_center().y)
		spot.y = wilds.lands.ground_at(Vector2(spot.x, spot.z)) + 0.5
		print("plains cornfields: %s" % [wilds.lands.cornfields()])
		world.player.global_position = spot
		wilds.fill_near(spot, 120.0)
		wilds.corn.fill_near(spot, 60.0)
		world.camera.make_current()
		world.camera._yaw = 2.2
		world.camera._pitch = 0.3
		world.camera.snap()
		await wait(2.5)
		await shot("plains_field")
		world.player.global_position = Vector3(rect.position.x - 6.0, spot.y + 1.0, rect.get_center().y)
		world.camera._yaw = -PI * 0.5
		world.camera._pitch = 0.25
		world.camera.snap()
		await wait(2.5)
		await shot("plains_field_edge")
	# From above, over the field: with the mist, and without.
	var above := Camera3D.new()
	world.add_child(above)
	above.fov = 40.0
	above.far = 4000.0
	above.global_position = field_middle + Vector3(9.0, 17.0, 13.0)
	above.look_at(field_middle)
	above.make_current()
	corn.fill_near(above.global_position, 90.0)
	await wait(1.5)
	await shot("above_mist")
	for node in root.find_children("*", "WorldEnvironment", true, false):
		(node as WorldEnvironment).environment.fog_enabled = false
		(node as WorldEnvironment).environment.volumetric_fog_enabled = false
	above.global_position = field_middle + Vector3(0.0, 36.0, 0.5)
	above.fov = 70.0
	above.look_at(field_middle)
	corn.fill_near(field_middle, 120.0)
	await wait(1.0)
	await shot("above_plan")
	quit()

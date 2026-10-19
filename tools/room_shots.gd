extends SceneTree
## Pictures of the rooms in the maze (MazeStyle "Rooms"): the plan of the square
## sections with its rooms, the boy standing in each kind of room (a column, a
## pine, a pond) looking across it, and a room of each section from above. Needs a real window:
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/room_shots.gd -- <folder> [seed]

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
	_run(int(args[1]) if args.size() > 1 else Maze.seed_for("ROOM", 1))


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


func _run(seed_value: int) -> void:
	await wait(1.0)
	main._begin([{"slot": 0, "look": "p11"}], 0, false, seed_value)
	var world = main.world
	var maze: Maze = world.maze
	await wait(1.5)
	print("%d rooms: %s" % [maze.rooms.size(), maze.rooms.map(func(room: Dictionary) -> String: return "ring %d %s %s" % [room.ring, room.rect, Maze.Room.keys()[room.fill]])])
	# The first room of each kind in each section.
	var seen := {}
	for room: Dictionary in maze.rooms:
		if seen.has([room.fill, room.ring]):
			continue
		seen[[room.fill, room.ring]] = true
		var middle := maze.room_middle(room)
		var rect: Rect2i = room.rect
		# (stood near a corner of it, looking across at the middle)
		var corner := maze.world(rect.position) + Vector3(2.0, 0.0, 2.0)
		world.player.global_position = corner + Vector3.UP * 0.5
		world.camera._yaw = atan2(corner.x - middle.x, corner.z - middle.z)
		world.camera.snap()
		await wait(2.0)
		await shot("room_%s_ring%d" % [String(Maze.Room.keys()[room.fill]).to_lower(), room.ring])
	# The plan of the square sections: walls dark, rooms tinted by what is in them.
	_plan_image(maze).save_png("%s/plan.png" % folder)
	print("saved %s/plan.png" % folder)
	# From above, without the mist: over a room of each section, high enough to see
	# it and the halls round it.
	for node in root.find_children("*", "WorldEnvironment", true, false):
		(node as WorldEnvironment).environment.fog_enabled = false
		(node as WorldEnvironment).environment.volumetric_fog_enabled = false
	var above := Camera3D.new()
	world.add_child(above)
	above.fov = 35.0
	above.far = 4000.0
	above.make_current()
	var done := {}
	for room: Dictionary in maze.rooms:
		if done.has(room.ring):
			continue
		done[room.ring] = true
		var middle := maze.room_middle(room)
		above.position = middle + Vector3.UP * (maze.maze_wall_height(room.ring) * 1.5 + 90.0)
		above.look_at(middle, Vector3.FORWARD)
		await wait(0.8)
		await shot("above_ring%d_%s" % [room.ring, String(Maze.Room.keys()[room.fill]).to_lower()])
	quit()


## The plan, a pixel group a cell: open floor pale, walls dark, solid stone black,
## rooms tinted (a column grey-blue, a pine green, a pond blue), the clearing olive.
func _plan_image(maze: Maze) -> Image:
	var scale := 6
	var image := Image.create(maze.size * scale + 1, maze.size * scale + 1, false, Image.FORMAT_RGB8)
	image.fill(Color(0.1, 0.1, 0.1))
	var tints := {Maze.Room.COLUMN: Color(0.55, 0.62, 0.8), Maze.Room.TREE: Color(0.45, 0.75, 0.4), Maze.Room.POND: Color(0.35, 0.55, 0.95)}
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		if maze.solid.has(cell):
			continue
		var colour := Color(0.85, 0.83, 0.78)
		if maze.in_clearing(cell):
			colour = Color(0.55, 0.6, 0.4)
		elif maze.in_room(cell):
			colour = tints[maze.rooms[maze.room_cells[cell]].fill]
		var x := cell.x * scale
		var y := cell.y * scale
		image.fill_rect(Rect2i(x + 1, y + 1, scale - 1, scale - 1), colour)
		# (open to the east or south: the gap filled)
		if cell.x < maze.size - 1 and not maze.blocked(cell, Vector2i(1, 0)):
			image.fill_rect(Rect2i(x + scale, y + 1, 1, scale - 1), colour)
		if cell.y < maze.size - 1 and not maze.blocked(cell, Vector2i(0, 1)):
			image.fill_rect(Rect2i(x + 1, y + scale, scale - 1, 1), colour)
	for corner: Vector2i in maze.columns:
		image.fill_rect(Rect2i(corner.x * scale - 1, corner.y * scale - 1, 3, 3), Color(0.15, 0.15, 0.3))
	return image

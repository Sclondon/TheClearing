extends SceneTree
## Pictures of the walls' edges, corners and tops (how rounded and worn they are:
## MazeStyle.wall_edge_rounding, border_wall_edge_rounding, wall_weathering): close
## to a pier's corner, up a corner, a long hall, along a wall's top, a great
## wall's corner, and the clearing's wall from inside it.
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/wall_edge_shots.gd -- <folder>

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else "user://wall_edge_shots"
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 30:
		await physics_frame
	var world = main.world
	var layout = world.get_node("Maze").layout
	var maze = world.maze
	world.player.visible = false
	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.far = 3000.0
	world.add_child(camera)
	camera.make_current()
	# (the boy's camera and anything else following him left alone: this one is current)
	var walls: Array = layout.pieces(MazePiece.Kind.WALL)
	var piers: Array = layout.pieces(MazePiece.Kind.PIER)
	var in_ring := func(piece: MazePiece, ring: int) -> bool:
		return maze.ring_of(maze.cell_at(piece.position)) == ring
	# A maze pier on the ground in the first ring, seen close at its corner.
	var pier: MazePiece = null
	for p: MazePiece in piers:
		if not p.great and not p.ledge and p.position.y < 0.5 and in_ring.call(p, 1):
			pier = p
			break
	if pier:
		var h := pier.box_size() * 0.5
		var corner := pier.position + Vector3(h.x, 0.0, h.z)
		camera.position = corner + Vector3(2.6, 1.7, 3.4)
		camera.look_at(corner + Vector3(0.0, 2.2, 0.0))
		await _shot(folder + "/corner.png")
		camera.position = corner + Vector3(1.1, 0.4, 1.6)
		camera.look_at(corner + Vector3(0.0, pier.box_size().y * 0.7, 0.0))
		await _shot(folder + "/corner_up.png")
	# The longest maze wall in the first ring: a hall along it, and along its top.
	var longest: MazePiece = null
	var best := 0.0
	for w: MazePiece in walls:
		var s := w.box_size()
		if not w.great and in_ring.call(w, 1) and maxf(s.x, s.z) > best:
			best = maxf(s.x, s.z)
			longest = w
	if longest:
		var s := longest.box_size()
		var along := Vector3.RIGHT if s.x > s.z else Vector3.BACK
		var out := Vector3.BACK if s.x > s.z else Vector3.RIGHT
		var half := maxf(s.x, s.z) * 0.5
		var face := minf(s.x, s.z) * 0.5
		var start := longest.position - along * half * 0.8 + out * (face + 4.5)
		camera.position = start + Vector3.UP * 1.7
		camera.look_at(start + along * 30.0 - out * 1.5 + Vector3.UP * 5.0)
		await _shot(folder + "/hall.png")
		var top := longest.position + Vector3.UP * s.y - along * half * 0.6
		camera.position = top + out * (face + 1.5) + Vector3.UP * 1.6
		camera.look_at(top + along * 14.0 - out * 0.3)
		await _shot(folder + "/top.png")
		camera.position = longest.position + out * (face + 9.0) + Vector3.UP * 1.7
		camera.look_at(longest.position + out * face + Vector3.UP * s.y)
		await _shot(folder + "/top_from_below.png")
	# A great pier's corner, between the first and second rings.
	for p: MazePiece in piers:
		if p.great and p.position.y < 0.5:
			var h := p.box_size() * 0.5
			var corner := p.position + Vector3(h.x, 0.0, h.z)
			camera.position = corner + Vector3(6.0, 1.7, 8.0)
			camera.look_at(corner + Vector3(0.0, 9.0, 0.0))
			await _shot(folder + "/great_corner.png")
			break
	# The clearing's wall, from inside the clearing, at his eye height.
	var look: ClearingStyle = maze.clearing_style
	if look.entrance_spots.size() > 0:
		var gate: Vector2 = look.entrance_spots[0][0]
		var inward: Vector2 = look.entrance_spots[0][1]
		var from := gate + inward * 45.0 + inward.orthogonal() * 30.0
		camera.position = Vector3(from.x, maze.ground_height(Vector3(from.x, 0.0, from.y)) + 1.7, from.y)
		camera.look_at(Vector3(gate.x, 12.0, gate.y) + Vector3(inward.orthogonal().x, 0.0, inward.orthogonal().y) * 12.0)
		await _shot(folder + "/clearing.png")
	quit()


func _shot(path: String) -> void:
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

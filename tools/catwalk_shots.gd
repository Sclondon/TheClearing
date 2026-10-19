extends SceneTree
## The metal catwalks (Catwalks; MazeStyle "Climbing": catwalks), in a round of only the
## third section (the Narrows, where there are many) or (`galleries`) the second (where
## there are few, over three levels of ledge): how many there are, and pictures from
## the floor looking up at them, from one looking along it, and from above. `climb`
## (headless) puts the boy at the foot of a ladder up to one, climbs it, and walks along
## the catwalk at the top.
##
##     godot --path . --resolution 1280x720 --audio-driver Dummy -s res://tools/catwalk_shots.gd -- <folder> [galleries]
##     godot --headless --path . --audio-driver Dummy -s res://tools/catwalk_shots.gd -- <folder> climb

var main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var styles: Array[MazeStyle] = [MazeStyle.galleries() if args.has("galleries") else MazeStyle.narrows()]
	MazeStyle.chosen = styles
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else "user://catwalk_shots"
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 5:
		await process_frame
	main._begin([{"slot": 0, "look": "p1"}], 0, false, Maze.seed_for("WALK", 1))
	for i in 30:
		await physics_frame
	var world = main.world
	var layout: MazeLayout = world.get_node("Maze").layout
	var walks := layout.pieces(MazePiece.Kind.CATWALK)
	var ladders := layout.pieces(MazePiece.Kind.LADDER)
	var along := walks.filter(func(piece: MazePiece) -> bool: return piece.catwalk & (Catwalks.Side.WALL_LEFT | Catwalks.Side.WALL_RIGHT))
	var hung := walks.filter(func(piece: MazePiece) -> bool: return piece.catwalk & Catwalks.Side.HUNG)
	var catwalks: Catwalks = world.get_node("Maze").features.catwalks
	print("catwalks %d (%d along walls, %d across halls, %d hung), ladders %d, deck %.0f m in all; at %.1f m" % [walks.size(), along.size(),
		walks.size() - along.size(), hung.size(), ladders.size(), walks.reduce(func(sum: float, piece: MazePiece) -> float: return sum + piece.position.distance_to(piece.bridge_end()), 0.0),
		walks[0].position.y if not walks.is_empty() else -1.0])
	if catwalks:
		print("  their body: %d shapes; drawn in %d MultiMeshes; %d Ladders" % [catwalks.body.get_child_count() if catwalks.body else 0,
			catwalks.find_children("*", "MultiMeshInstance3D", false, false).size(), catwalks.ladders.size()])
	if walks.is_empty():
		quit(1)
		return
	if args.has("climb"):
		await _climb(world, catwalks)
		return
	# A ladder up to a catwalk along a wall with one across the hall from it: the busiest place.
	var best: MazePiece = null
	var best_count := -1
	for ladder: MazePiece in ladders:
		var count := 0
		for walk: MazePiece in walks:
			if Vector2(walk.position.x - ladder.position.x, walk.position.z - ladder.position.z).length() < 20.0:
				count += 1
		if count > best_count:
			best_count = count
			best = ladder
	var top := best.position + Vector3.UP * best.length
	var out := best.basis.z.normalized()
	print("looking at the ladder at %s (%.1f m), %d catwalks near" % [best.position, best.length, best_count])
	world.player.visible = false
	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.far = 600.0
	world.add_child(camera)
	camera.make_current()
	# From the floor near the ladder's foot, looking up past it at the catwalks.
	var floor_at := Vector3(best.position.x, 1.6, best.position.z) + out * 3.0
	camera.global_position = floor_at
	camera.look_at(top - out * 2.0 + Vector3.UP * 2.0)
	await _shot("%s/1_up_from_the_floor.png" % folder)
	# Straight up from under the catwalk nearest, through its grating.
	var nearest: MazePiece = walks[0]
	for walk: MazePiece in walks:
		if walk.position.distance_to(top) + walk.bridge_end().distance_to(top) < nearest.position.distance_to(top) + nearest.bridge_end().distance_to(top):
			nearest = walk
	var middle := (nearest.position + nearest.bridge_end()) * 0.5
	var run := (nearest.bridge_end() - nearest.position).normalized()
	camera.global_position = Vector3(middle.x, 1.6, middle.z) - run * 5.0
	camera.look_at(middle + run * 2.0)
	await _shot("%s/2_under_the_grating.png" % folder)
	# On the catwalk, looking along it.
	camera.global_position = nearest.position + Vector3.UP * 1.6 + run * 0.5
	camera.look_at(nearest.bridge_end() + Vector3.UP * 1.0)
	await _shot("%s/3_along_from_on_it.png" % folder)
	camera.global_position = nearest.bridge_end() + Vector3.UP * 1.6 - run * 0.5
	camera.look_at(nearest.position + Vector3.UP * 1.0)
	await _shot("%s/4_back_along_it.png" % folder)
	# From above the walls, looking down on the ways they make.
	camera.global_position = middle + Vector3(18.0, 40.0, 18.0)
	camera.look_at(middle)
	await _shot("%s/5_from_above.png" % folder)
	camera.global_position = middle + Vector3(0.0, 90.0, 40.0)
	camera.look_at(middle)
	await _shot("%s/6_from_high_above.png" % folder)
	# The ladder close to.
	camera.global_position = top + out * 3.5 + Vector3.DOWN * 1.5 + out.cross(Vector3.UP) * 1.5
	camera.look_at(top + Vector3.DOWN * 0.5)
	await _shot("%s/7_ladder_top.png" % folder)
	quit()


## The boy at the foot of the ladder up to the busiest catwalk: up it, off the top onto
## the catwalk, and along it.
func _climb(world: Node, catwalks: Catwalks) -> void:
	var player = world.player
	var ladder: Ladder = null
	for each: Ladder in catwalks.ladders:
		if ladder == null or each.height > ladder.height:
			ladder = each
	var maze: Maze = world.maze
	var cell := maze.cell_at(ladder.global_position)
	for step: Vector2i in Maze.STEPS:
		if maze.blocked(cell, step):
			print("  wall %s: face at %s, thick %.2f, wall piece boxes:" % [step, maze.world(cell) + Vector3(step.x, 0, step.y) * (Maze.CELL * 0.5 - maze.wall_thick(cell, step) * 0.5), maze.wall_thick(cell, step)])
	for piece in world.get_node("Maze").layout.pieces(MazePiece.Kind.WALL) + world.get_node("Maze").layout.pieces(MazePiece.Kind.PIER):
		if piece.box_has(ladder.global_position + Vector3.UP * 0.5, 1.5):
			print("    ", piece.name, " ", piece.position, " ", piece.box_size(), " style ", piece.style)
	player.global_position = ladder.stand(ladder.bottom_y() + 0.05) + ladder.global_basis.z * 0.6
	player.velocity = Vector3.ZERO
	RopeBridge.bodies_now(self)
	for i in 10:
		await physics_frame
	var held := false
	var up_to := 0.0
	for i in 2400:
		if i % 120 == 0:
			print("  %d: at %s, ladder %s, state %d, distance %.2f" % [i, player.global_position, ladder.global_position, player.state, (player.global_position as Vector3).distance_to(ladder.stand(player.global_position.y))])
			var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
			for way: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.5, player.global_position + Vector3.UP * 0.5 + way * 3.0))
				if hit:
					print("    %s: %s %s at %s" % [way, hit.collider, hit.collider.get_parent(), hit.position])
		if player.state == player.State.LADDER:
			held = true
			_let_go()
			Input.action_press(&"move_up")
		else:
			# (to in front of it, then into it)
			var to: Vector3 = ladder.stand(player.global_position.y) - player.global_position
			to.y = 0.0
			_steer(world, (to.normalized() if to.length() > 0.25 else ladder.facing()))
		await physics_frame
		up_to = maxf(up_to, player.global_position.y)
		if held and player.state == player.State.FREE and player.is_on_floor() and player.global_position.y > ladder.top_y() - 0.3:
			break
	_let_go()
	for i in 20:
		await physics_frame
	var on_top: bool = player.is_on_floor() and player.global_position.y > ladder.top_y() - 0.3
	print("%s: takes hold of the ladder (%.1f m) and climbs onto the catwalk (at %.2f m, top %.2f, highest %.2f, state %d)" % [
		"PASS" if held and on_top else "FAIL", ladder.height, player.global_position.y, ladder.top_y(), up_to, player.state])
	# Along the catwalk: the run he is on, to its far end (or 8 m), walking.
	var at: Vector3 = player.global_position
	var best: Array = []
	for run: Array in catwalks.runs:
		var a: Vector3 = run[0]
		var b: Vector3 = run[1]
		var span := b - a
		var t := clampf((at - a).dot(span) / span.length_squared(), 0.0, 1.0)
		if (a + span * t).distance_to(at) < 1.5 and (best.is_empty() or span.length() > (best[1] - best[0]).length()):
			best = run
	var went := 0.0
	var lowest := at.y
	if not best.is_empty():
		var a: Vector3 = best[0]
		var b: Vector3 = best[1]
		var to: Vector3 = b if at.distance_to(b) > at.distance_to(a) else a
		var way := Vector3(to.x - at.x, 0.0, to.z - at.z).normalized()
		var goal := minf(Vector2(to.x - at.x, to.z - at.z).length() - 1.0, 8.0)
		for i in 600:
			# (along the run's middle line)
			var ahead: float = (player.global_position - at).dot(way) + 1.0
			var off: Vector3 = Vector3(at.x, 0.0, at.z) + way * ahead
			var line_point := a + (b - a) * clampf((off - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			var steer := Vector3(line_point.x - player.global_position.x, 0.0, line_point.z - player.global_position.z)
			_steer(world, (steer + way).normalized())
			await physics_frame
			lowest = minf(lowest, player.global_position.y)
			went = (player.global_position as Vector3 - at).dot(way)
			if went > goal:
				break
		_let_go()
		print("%s: walks along the catwalk (%.1f m of %.1f, lowest %.2f against %.2f)" % ["PASS" if went > goal - 0.5 and lowest > at.y - 0.3 else "FAIL",
			went, goal, lowest, at.y])
	else:
		print("FAIL: not on a catwalk at the top")
	quit()


func _steer(world: Node, towards: Vector3) -> void:
	var basis: Basis = world.camera.global_transform.basis
	var forward := -basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := basis.x
	right.y = 0.0
	right = right.normalized()
	var stick := Vector2(towards.dot(right), towards.dot(forward))
	for pair: Array in [[&"move_right", stick.x], [&"move_left", -stick.x], [&"move_up", stick.y], [&"move_down", -stick.y]]:
		if float(pair[1]) > 0.05:
			Input.action_press(pair[0], clampf(pair[1], 0.0, 1.0))
		else:
			Input.action_release(pair[0])


func _let_go() -> void:
	for action: StringName in [&"move_right", &"move_left", &"move_up", &"move_down", &"jump"]:
		Input.action_release(action)


func _shot(path: String) -> void:
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

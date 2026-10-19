extends SceneTree
## In a real round: rays down just in front of the clearing's wall, inside and
## out, to see whether a ledge stands there (what they hit, and how high).
##
##     godot --headless --path . --audio-driver Dummy -s res://tools/ledge_ray_probe.gd

var main: Node


func _initialize() -> void:
	var styles := MazeStyle.square_defaults() + MazeStyle.round_defaults()
	styles[0].mezzanines = [MezzanineLevel.made(10.0, 1.0)]
	MazeStyle.chosen = styles
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 60:
		await physics_frame
	var maze: Maze = main.world.maze
	print("first ring's ledge %.1f m, %.1f deep; rampart %d" % [maze.styles[0].level_height(0), maze.styles[0].level_depth(0), maze.rampart(1)])
	var space: PhysicsDirectSpaceState3D = main.world.get_world_3d().direct_space_state
	var shown := 0
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		for step: Vector2i in Maze.STEPS:
			if shown >= 6 or not maze.has_ledge(cell, step):
				continue
			var near := maze.in_clearing(cell) or maze.solid.has(cell + step)
			if not near:
				continue
			var s := Vector3(step.x, 0.0, step.y)
			var face := maze.world(cell) + s * (Maze.CELL * 0.5 - maze.wall_thick(cell, step) * 0.5)
			for back in [0.5, 2.0, 6.0]:
				var at: Vector3 = face - s * back
				var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 60.0, at + Vector3.DOWN * 1.0)
				var hit := space.intersect_ray(query)
				print("%s cell %s step %s, %.1f m out: %s" % ["clearing" if maze.in_clearing(cell) else "ring 1", cell, step, back, ("hit at %.2f m" % hit.position.y) if hit else "nothing"])
			shown += 1
	quit()

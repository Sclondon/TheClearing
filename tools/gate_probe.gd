extends SceneTree
## Whether the clearing's doors (ClearingGates) are open by day and shut by night:
## at a few hours, how shut they are, and whether a line out through each gate's
## way, at chest height, hits a door or a wall.
##
##     godot --headless --audio-driver Dummy --path . -s res://tools/gate_probe.gd

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 30:
		await physics_frame
	var world = main.world
	var gates = world.gates
	var maze = world.maze
	print("doors: %d, hour %.1f, day %s, closing %s, shut %.2f" % [gates._doors.size(), world.day.hour, world.day.is_day(), gates.closing, gates.shut])
	for hour: float in [world.day.hour, 12.0, 20.0, 7.0]:
		world.day.set_hour(hour)
		for i in 60 * 16:
			await physics_frame
		var space = world.get_world_3d().direct_space_state
		var blocked := []
		for spot: Array in maze.clearing_style.entrance_spots:
			var face: Vector2 = spot[0]
			var inward: Vector2 = spot[1]
			var from := Vector3(face.x, 1.5, face.y) + Vector3(inward.x, 0.0, inward.y) * 3.0
			var to := Vector3(face.x, 1.5, face.y) - Vector3(inward.x, 0.0, inward.y) * 120.0
			var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1, [world.player.get_rid()]))
			blocked.append("%s at %.0f m" % [hit["collider"].get_class() + "/" + str(hit["collider"].name), from.distance_to(hit["position"])] if hit else "clear")
		print("hour %.1f (day %s): closing %s, shut %.2f; out through the gates: %s" % [world.day.hour, world.day.is_day(), gates.closing, gates.shut, ", ".join(blocked)])
	quit()

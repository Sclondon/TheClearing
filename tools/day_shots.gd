extends SceneTree
## Pictures of the day going round (DayCycle) and the clearing's gates shutting
## (ClearingGates): from in front of a gate, looking at it, at midday, at dusk
## with the doors closing, and at night with them shut; and over the clearing at
## midday and at night. Prints whether the gate is shut at night.
##
##     godot --path . --resolution 1280x720 -s res://tools/day_shots.gd -- <folder>

var main: Node


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else "user://day_shots"
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 30:
		await physics_frame
	var world = main.world
	world.player.visible = false
	var camera := Camera3D.new()
	camera.fov = 65.0
	world.add_child(camera)
	camera.make_current()
	# (the clear entrance, with nothing in the way)
	var clear: int = maxi(world.maze.clearing_style.entrances.find(ClearingStyle.Entrance.CLEAR), 0)
	var spot: Transform3D = world.gate_spot(clear)
	var out := spot.basis.z
	camera.position = spot.origin - out * 40.0 + Vector3.UP * 3.0
	camera.look_at(spot.origin + out * 10.0 + Vector3.UP * 14.0)
	for shot: Array in [[12.0, "noon"], [18.5, "evening"], [19.1, "sunset_closing"], [22.0, "night"], [5.9, "before_dawn"]]:
		world.day.set_hour(shot[0])
		world.gates.set_shut(not world.day.is_day())
		if shot[1] == "sunset_closing":
			world.gates.set_shut(false)
			world.gates.close(true)
			for i in 300:
				await physics_frame
		await _shot("%s/%s.png" % [folder, shot[1]])
		if shot[1] == "night":
			# (straight through the gateway: the doors are in the way)
			var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
			var from := spot.origin + Vector3.UP * 2.0
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + out * 30.0, 0xFFFFFFFF, [world.player.get_rid()]))
			print("night: gate shut %.2f, a ray through the gateway stops after %.1f m" % [world.gates.shut, from.distance_to(hit["position"]) if hit else -1.0])
	quit()


func _shot(path: String) -> void:
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

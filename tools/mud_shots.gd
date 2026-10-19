extends SceneTree
## Footprints in the maze's mud and splashes in its puddles (MudSteps): the boy
## walked along a muddy hall of the first section, and pictures of the prints he
## leaves; then stood in a puddle, his footfalls sent as walking sends them, and
## pictures of the splashes.
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/mud_shots.gd -- <folder>

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
	_run()


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


## A run along +x in the first section, from a cell's middle into the next, with
## nothing across it, that is `want` ("mud" or "puddle") somewhere along it: its
## start, and where on it.
func _find(world: Node3D, steps: MudSteps, want: String) -> Array:
	var maze: Maze = world.maze
	var best := []
	var most := 0.0
	for x in maze.size - 1:
		for y in maze.size:
			var cell := Vector2i(x, y)
			if maze.ring_of(cell) != 1 or maze.blocked(cell, Vector2i(1, 0)) or maze.ring_of(cell + Vector2i(1, 0)) != 1:
				continue
			var from := maze.world(cell)
			for k in 15:
				var at := from + Vector3(Maze.CELL * k / 14.0, 0.0, 0.0)
				var g := steps.ground_at(at)
				var score := g.x if want == "mud" and g.y < 0.0 else (g.y if want == "puddle" else 0.0)
				if g.z > 0.9 and score > most and _clear(world, from, at + Vector3(2.5, 0.0, 0.0)):
					most = score
					best = [from, at]
	print("%s: best %.2f" % [want, most])
	return best


# Whether nothing stands between `a` and `b`, a metre up (a ray through the world's bodies).
func _clear(world: Node3D, a: Vector3, b: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(a + Vector3.UP, b + Vector3.UP)
	query.exclude = [world.player.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _run() -> void:
	await wait(1.0)
	main._begin([{"slot": 0, "look": "p11"}], 0, false, Maze.seed_for("MUD", 1))
	await wait(1.5)
	var world = main.world
	var steps: MudSteps = world.get_node("MudSteps")
	# (out of the way of the pictures: the corn and the plants)
	var builder: MazeBuilder = world.get_node("Maze")
	for hide: Node3D in [builder.corn, builder.undergrowth]:
		if hide:
			hide.visible = false
	var mud := _find(world, steps, "mud")
	var puddle := _find(world, steps, "puddle")
	var close := Camera3D.new()
	close.fov = 50.0
	world.add_child(close)
	if not mud.is_empty():
		var from: Vector3 = mud[0]
		var spot: Vector3 = mud[1]
		world.player.global_position = from + Vector3.UP * 0.3
		world.player.velocity = Vector3.ZERO
		world.camera._yaw = atan2(-1.0, 0.0)
		world.camera._pitch = 0.35
		world.camera.snap()
		await wait(0.8)
		Input.action_press(&"move_up", 0.5)
		await wait((spot.x - from.x + 3.0) / 2.2)
		Input.action_release(&"move_up")
		print("walked from %s to %s (mud at %s); prints made: %d" % [from, world.player.global_position, spot, steps._next_print])
		await shot("mud_1_game_camera")
		await wait(0.6)
		close.global_position = spot + Vector3(-1.6, 2.4, 1.8)
		close.look_at(spot + Vector3(0.4, 0.0, 0.0))
		close.make_current()
		world.player.visible = false
		await shot("mud_2_prints_close")
	if not puddle.is_empty():
		# (stood in the puddle, his own footfalls sent as he would make them walking)
		var spot: Vector3 = puddle[1]
		var before := steps._next_drop
		world.player.global_position = spot + Vector3.UP * 0.05
		world.player.velocity = Vector3.ZERO
		world.player.visible = true
		var rig: Node = world.player.find_children("*", "CharacterRig", true, false)[0]
		close.global_position = spot + Vector3(1.4, 0.8, 1.9)
		close.look_at(spot + Vector3(0.0, 0.25, 0.0))
		close.make_current()
		await wait(0.5)
		for i in 6:
			if i % 2 == 0:
				rig.footfall.emit(spot + Vector3(0.1 * i, 0.0, 0.0), (i / 2) % 2, 0.9)
			await wait(0.08)
			await shot("puddle_%d" % i)
		print("drops thrown: %d" % ((steps._next_drop - before + MudSteps.DROPS) % MudSteps.DROPS))
	quit()

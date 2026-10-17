extends SceneTree
## Pictures of the ways up: a terrace with its ivy from the hall, the boy on the
## ivy, a vine, a rope bridge from one end, and the maze from a wall top. Needs a
## real window:
##
##     godot --path . --resolution 720x1280 -s res://tools/climb_shots.gd -- <folder>

var main: Node
var folder := "climb_shots"


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
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png" % [folder, name])


func wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= 1.0 / 60.0


## Puts him at `at` and the camera behind him looking the way `towards`.
func stand(at: Vector3, towards: Vector3, pitch := 0.16) -> void:
	var world = main.world
	# (letting go of whatever he holds first, or he goes back to it)
	if world.player.state == world.player.State.LADDER:
		world.player._leave_ladder()
	elif world.player.state == world.player.State.ROPE:
		world.player._leave_rope()
	world.player.global_position = at
	world.player.velocity = Vector3.ZERO
	world.camera._yaw = atan2(-towards.x, -towards.z)
	world.camera._pitch = pitch
	world.camera.snap()


func _run() -> void:
	await wait(0.5)
	main._begin([{"slot": 0, "look": "p1"}], 0, false, Maze.seed_for("CLMB", 1))
	await wait(1.0)
	var features = main.world.get_node("Maze").features
	# A terrace and its ivy, from the hall in front of it.
	var ivy: IvyClimb = null
	for climb: IvyClimb in features.climbs:
		if climb.bottom_y() < 0.1:
			ivy = climb
			break
	stand(ivy.stand(0.05) + ivy.global_basis.z * 7.0, ivy.facing(), 0.3)
	await wait(1.5)
	await shot("1_terrace")
	# On the ivy, halfway up.
	stand(ivy.stand(0.05) + ivy.global_basis.z * 0.5, ivy.facing(), 0.1)
	Input.action_press(&"move_up")
	await wait(3.5)
	Input.action_release(&"move_up")
	await shot("2_on_ivy")
	# A vine, from the terrace it hangs off.
	var vine: Vine = features.vines[0]
	var end: Vector3 = vine.point_at(vine.length)
	stand(end + Vector3.DOWN * MazeFeatures.VINE_CLEAR + Vector3(4.0, 0.0, 4.0).normalized() * 0.1 - (vine.global_position - end).normalized() * 0.0 + Vector3(0, 0.1, 0), Vector3.FORWARD, 0.0)
	await wait(1.0)
	await shot("3_vine")
	# A bridge, from one end.
	var bridge: RopeBridge = features.bridges[0]
	var span: Vector3 = (bridge.to - bridge.from).normalized()
	stand(bridge.from - span * 0.8 + Vector3.UP * 0.1, span, 0.15)
	await wait(1.5)
	await shot("4_bridge")
	# From the top of a wall.
	var top: IvyClimb = null
	for climb: IvyClimb in features.climbs:
		if climb.top_y() > MazeBuilder.WALL_HEIGHT - 1.0:
			top = climb
			break
	if top:
		stand(top.stand(top.top_y()) + top.facing() * 1.2 + Vector3.UP * 0.2, -top.facing().rotated(Vector3.UP, 0.4), 0.35)
		await wait(1.5)
		await shot("5_wall_top")
	quit()

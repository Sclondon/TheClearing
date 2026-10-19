extends SceneTree
## The boy hanging under a strung vine (Player._hold_strand): caught falling past
## it, then going hand over hand along it; pictures from the side and from below.
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/strand_hang_shots.gd -- <folder>

var main: Node
var folder := "shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	MazeStyle.chosen = MazeStyle.defaults()
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


func _run() -> void:
	await wait(0.2)
	main.start_solo()
	await wait(1.0)
	var world = main.world
	var player = world.player
	world.dev = null
	var strand: VineStrand = null
	for each: VineStrand in world.maze_features().strands:
		if absf(each.from.y - each.to.y) < 1.0 and each.span() > 7.0 and (strand == null or each.span() > strand.span()):
			strand = each
	var middle := strand.point_at_distance(strand.span() * 0.5)
	var across := strand.line().cross(Vector3.UP)
	player.global_position = middle + across * 0.35 + Vector3.UP * 0.6 - Vector3.UP * player.hang_height
	player.velocity = Vector3.ZERO
	await wait(1.2)
	print("state %d, strand %s" % [player.state, player._strand != null])
	var look := Camera3D.new()
	look.fov = 45.0
	world.add_child(look)
	var at: Vector3 = player.global_position
	look.global_position = at + strand.line() * 3.5 + Vector3.UP * 0.6
	look.look_at(at + Vector3.UP * 1.0)
	look.make_current()
	await shot("1_hanging_side")
	look.global_position = at + player._ledge_direction * 3.0 + Vector3.UP * 0.3
	look.look_at(at + Vector3.UP * 1.1)
	await shot("2_hanging_front")
	var left: Vector3 = player._ledge_left()
	var action := &"move_right" if world.camera.global_transform.basis.x.dot(left) > 0.0 else &"move_left"
	Input.action_press(action)
	for i in 3:
		await wait(0.3)
		at = player.global_position
		look.global_position = at + player._ledge_direction * 3.0 + Vector3.UP * 0.3
		look.look_at(at + Vector3.UP * 1.1)
		await shot("%d_hand_over_hand" % (i + 3))
	Input.action_release(action)
	quit()

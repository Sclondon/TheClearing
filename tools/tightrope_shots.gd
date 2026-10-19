extends SceneTree
## The boy's tightrope balance (CharacterRig, Player.tightrope): walked slowly
## across the clearing with the tightrope held on, as a VineStrand holds it on
## while he is on it, and pictures from the side, from in front and from behind:
## arms out and see-sawing, one foot before the other, hips swaying, eyes down.
## (On flat ground, so that what is looked at is the pose, not the vine.)
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/tightrope_shots.gd -- <folder> [off]
## ("off" for the same walk without it, to compare)

var main: Node
var folder := "shots"
var on := true


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	on = not args.has("off")
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


# A while, the tightrope kept on (and his sway off its line made to wander) all the while.
func wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= 1.0 / 60.0
		if on and main.world and main.world.player:
			main.world.player.tightrope = 0.2
			main.world.player.tightrope_aside = sin(Time.get_ticks_msec() / 700.0) * 0.12


func _run() -> void:
	await wait(1.0)
	main._begin([{"slot": 0, "look": "p11"}], 0, false, Maze.seed_for("TIGHTROPE", 1))
	await wait(1.5)
	var world = main.world
	var way := Vector3(1.0, 0.0, 0.0)
	world.player.global_position = Vector3(-4.0, 0.3, 2.0)
	world.player.velocity = Vector3.ZERO
	world.camera._yaw = atan2(-1.0, 0.0)
	world.camera._pitch = 0.3
	world.camera.snap()
	await wait(1.2)
	print("standing: rig %.2f, teeter %.2f" % [world.player._rig._tight, world.player._rig._teeter])
	var look := Camera3D.new()
	look.fov = 40.0
	world.add_child(look)
	var at: Vector3 = world.player.global_position
	look.global_position = at + way * 3.2 + Vector3.UP * 1.0
	look.look_at(at + Vector3.UP * 0.8)
	look.make_current()
	await shot("0_standing_in_front")
	world.camera.make_current()
	Input.action_press(&"move_up", 0.3)
	var right := way.cross(Vector3.UP)
	for i in 4:
		await wait(0.35)
		at = world.player.global_position
		look.global_position = at + right * 3.4 + Vector3.UP * 0.7
		look.look_at(at + Vector3.UP * 0.75)
		look.make_current()
		print("walking %d: rig %.2f, teeter %.2f" % [i, world.player._rig._tight, world.player._rig._teeter])
		await shot("%d_side" % (i + 1))
		world.camera.make_current()
	at = world.player.global_position
	look.global_position = at - way * 3.0 + Vector3.UP * 1.3
	look.look_at(at + Vector3.UP * 0.8)
	look.make_current()
	await shot("5_behind")
	Input.action_release(&"move_up")
	quit()

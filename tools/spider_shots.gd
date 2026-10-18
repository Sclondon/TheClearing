extends SceneTree
## Pictures of the giant spider (MazeSpider) in a real round (World: the game's
## light and mist), as the boy meets it: waiting high on a wall over the
## passage, seen from the ground; dropping on its thread; coming at him;
## rearing; biting; and climbing back up. Says how many draws a frame takes
## with it and without. Needs a real window:
##
##     godot --path . --resolution 1280x720 -s res://tools/spider_shots.gd -- <folder>
##
## (The round's own hunters are kept busy elsewhere: their only target is a
## stand-in in the clearing, where nothing hunts.)

var folder := "shots/spider"
var world
var maze: Maze
var nav: MazeNav
var boy
var spider: MazeSpider
var camera: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func wait(seconds: float, until := Callable()) -> bool:
	var left := seconds
	while left > 0.0:
		await physics_frame
		left -= 1.0 / 60.0
		if until.is_valid() and until.call():
			return true
	return false


func draws() -> int:
	await process_frame
	await RenderingServer.frame_post_draw
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


## The camera at `from`, looking at `at`.
func view(from: Vector3, at: Vector3) -> void:
	camera.global_position = from
	camera.look_at(at)


func _run() -> void:
	world = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SPIDER", 1), 0, [{"slot": 0, "look": "p11"}], false)
	maze = world.maze
	nav = MazeNav.new(maze)
	boy = world.player
	boy.takes_input = false
	var elsewhere := Node3D.new()
	world.add_child(elsewhere)
	elsewhere.position = Vector3.ZERO
	world.enemies.set_targets([elsewhere])
	world.griever.targets = [elsewhere]
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.far = 900.0
	world.add_child(camera)
	camera.make_current()

	# A passage out in the ring: the spider goes up the nearest wall there.
	var lairs := nav.lairs(4)
	var cell: Vector2i = lairs[lairs.size() / 2]
	boy.global_position = maze.world(cell) + Vector3(40.0, 0.1, 0.0)
	await wait(0.5)
	view(maze.world(cell) + Vector3(0.0, 2.0, 12.0), maze.world(cell) + Vector3.UP * 2.0)
	var bare := await draws()
	spider = MazeSpider.new()
	spider.maze = maze
	spider.position = maze.world(cell) + Vector3.UP * 0.05
	spider.targets = [boy]
	world.add_child(spider)
	await wait(0.4)
	var face := spider.wall
	var side := Vector3(-face.z, 0.0, face.x)
	# (along the wall the way that is open furthest)
	var eye := spider.wall_foot + Vector3.UP * 1.5
	var space := spider.get_world_3d().direct_space_state
	var open := [0.0, 0.0]
	for k in 2:
		var dir := side * (1.0 if k == 0 else -1.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + dir * 60.0, 1))
		open[k] = 60.0 if hit.is_empty() else eye.distance_to(hit["position"])
	if open[1] > open[0]:
		side = -side
	var room: float = minf(maxf(open[0], open[1]) - 3.0, 30.0)
	# The boy away down the passage, looking along it; nothing has seen him yet.
	boy.global_position = spider.wall_foot + face * 3.0 + side * room + Vector3.UP * 0.1
	await wait(1.5)
	print("draws without the spider %d, with it %d" % [bare, await draws()])

	# 1: high on the wall, from the ground some way off.
	var foot := spider.wall_foot
	view(foot + face * 9.0 + side * 16.0 + Vector3.UP * 1.6, spider.global_position + Vector3.DOWN * 1.0)
	await shot("1_waiting_far")
	# 2: from right under it, looking up.
	view(foot + face * 5.0 + side * 3.0 + Vector3.UP * 1.5, spider.look.body.origin)
	await shot("2_waiting_under")
	# 3: close, level with it, from the side.
	view(spider.look.body.origin + face * 4.5 + side * 3.5, spider.look.body.origin)
	await shot("3_waiting_close")

	# He walks in under it: it drops.
	spider.targets = [boy]
	boy.global_position = foot + face * 4.0 + side * minf(6.0, room) + Vector3.UP * 0.1
	await wait(4.0, func() -> bool: return spider.mode == MazeSpider.Mode.DROP and spider._mode_time > 0.6)
	view(boy.global_position + Vector3.UP * 1.7 - side * 3.0 + face * 3.0, spider.look.body.origin + Vector3.UP * 0.5)
	await shot("4_dropping")
	await wait(3.0, func() -> bool: return spider.mode == MazeSpider.Mode.HUNT and spider._mode_time > 0.4)
	view(boy.global_position + Vector3.UP * 1.6 + (boy.global_position - spider.global_position).normalized() * 3.5, spider.look.body.origin)
	await shot("5_landed")
	# It comes at him: seen from behind him, as the game's camera would.
	await wait(6.0, func() -> bool: return spider.look.stage() == GiantSpider.Stage.REAR and spider.look.stage_left() < 0.3)
	var away: Vector3 = boy.global_position - spider.global_position
	away.y = 0.0
	away = away.normalized()
	view(boy.global_position + away * 4.0 + Vector3.UP * 2.2 + Vector3(-away.z, 0.0, away.x) * 1.2, spider.look.body.origin + Vector3.UP * 0.6)
	await shot("6_rearing")
	view(spider.global_position + Vector3(-away.z, 0.0, away.x) * 6.0 + Vector3.UP * 1.5, spider.look.body.origin + Vector3.UP * 0.5)
	await shot("7_rearing_side")
	await wait(2.0, func() -> bool: return spider.look.stage() == GiantSpider.Stage.STRIKE and spider.look.stage_left() < 0.1)
	view(spider.look.body.origin + Vector3(-away.z, 0.0, away.x) * 7.0 - away * 1.0 + Vector3.UP * 1.5, spider.look.body.origin)
	await shot("8_bite_side")
	# He is gone: it climbs back up.
	boy.global_position = Vector3(0.0, 0.1, 0.0)
	spider.pose_range = 2000.0
	spider.targets = [boy]
	await wait(40.0, func() -> bool: return spider.mode == MazeSpider.Mode.CLIMB and spider.global_position.y > 5.0)
	var up_at: Vector3 = spider.look.body.origin
	view(Vector3(up_at.x, spider.wall_foot.y + 1.6, up_at.z) + spider.wall * 11.0, up_at)
	await shot("9_climbing")
	quit()

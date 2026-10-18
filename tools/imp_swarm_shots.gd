extends SceneTree
## Pictures of the imp swarm (creatures/imp_swarm/, scripts/enemies/maze_imp_swarm.gd)
## in a passage of a real round (World: the game's light and mist): the crack
## asleep, the tide pouring out and down the hall at him, running up and
## along the wall, all over him; close on a few; and the draws a frame takes.
## Needs a real window (landscape: every picture is framed for 1280x720):
##
##     godot --path . --resolution 1280x720 -s res://tools/imp_swarm_shots.gd -- <folder>

var folder := "imp_swarm_shots"
var world
var maze
var nav
var boy
var cam: Camera3D


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
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < seconds * 1000.0:
		await process_frame
		if until.is_valid() and until.call():
			return true
	return false


func _run() -> void:
	world = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	maze = world.maze
	nav = MazeNav.new(maze)
	boy = world.player
	boy.takes_input = false
	for child in world.get_children():
		if child is MazeEnemies or child is Griever:
			child.queue_free()
	await wait(0.5)
	var found := _straight_run(4)
	var cell: Vector2i = found[0]
	var way: Vector2i = found[1]
	var along := Vector3(way.x, 0, way.y)
	boy.remove_from_group(&"maze_players")
	_stand(maze.world(cell) - along * 30.0, along)
	await wait(0.6)
	var bare := await _draws()

	var swarm := MazeImpSwarm.new()
	swarm.maze = maze
	swarm.position = maze.world(cell + way * 2)
	world.add_child(swarm)
	await wait(0.5)
	var nest: Vector3 = swarm._nest
	var out: Vector3 = swarm.out_of_wall
	var side := Vector3.UP.cross(out)
	cam = Camera3D.new()
	cam.fov = 55.0
	world.add_child(cam)
	cam.make_current()
	cam.position = nest + out * 3.0 + side * 2.0 + Vector3.UP * 1.6
	cam.look_at(nest)
	await shot("50_crack_asleep")
	print("draws with a sleeping swarm: +%d" % ((await _draws()) - bare))

	# He comes down the hall; they pour out at him.
	boy.add_to_group(&"maze_players")
	var spot: Vector3 = maze.world(cell)
	var toward: Vector3 = Vector3(spot.x - nest.x, 0.0, spot.z - nest.z).normalized()
	var lat := Vector3.UP.cross(toward)
	spot = _middle_of_hall(spot, lat)
	_stand(spot, -toward)
	swarm.wake_on(boy)
	swarm.swarm.catch_count = 1000
	await wait(2.2)
	cam.position = nest + toward * 4.0 + lat * 2.5 + Vector3.UP * 1.4
	cam.look_at(nest + Vector3.UP * 0.2)
	await shot("51_pouring_out")
	await wait(0.5)
	cam.position = spot - toward * 1.0 + lat * 1.0 + Vector3.UP * 1.5
	cam.look_at(nest + toward * 10.0)
	await shot("52_tide_coming")
	world.camera.make_current()
	await shot("53_tide_game_camera")
	print("draws with the swarm out: %d (+%d), %d out" % [await _draws(), (await _draws()) - bare, swarm.swarm.out])
	# Along the wall, side on.
	cam.make_current()
	var front_now: Vector3 = swarm.swarm.front()
	cam.position = front_now + lat * 5.0 - toward * 2.0 + Vector3.UP * 2.5
	cam.look_at(front_now + Vector3.UP * 0.8)
	var on_wall := func() -> bool:
		var n := 0
		for k in swarm.swarm.count:
			if swarm.swarm.imp_state(k) == ImpSwarm.WALL:
				n += 1
		return n >= 4
	await wait(3.0, on_wall)
	await shot("54_up_the_wall")
	# All over him.
	swarm.swarm.catch_count = 1000
	await wait(4.0, func() -> bool: return swarm.swarm.on_him >= 8)
	var chest: Vector3 = boy.global_position + Vector3.UP * 0.7
	cam.position = chest + lat * 2.0 - toward * 1.0 + Vector3.UP * 0.6
	cam.look_at(chest)
	await shot("55_on_him")
	world.camera.make_current()
	await shot("56_on_him_game_camera")
	# Close, low, a few of them coming.
	cam.make_current()
	swarm.swarm.shake_off()
	_stand(spot + toward * 4.0, -toward)
	await wait(0.9)
	cam.position = boy.global_position + lat * 1.0 - toward * 0.5 + Vector3.UP * 0.5
	cam.look_at(boy.global_position - toward * 5.0)
	await shot("57_close_coming")
	# Along the wall: him a way along the crack's own wall, them coming along it and up it.
	swarm.swarm.recall()
	await wait(6.0, func() -> bool: return swarm.mode == MazeImpSwarm.Mode.ASLEEP)
	swarm.swarm._rest = 0.0
	var along_wall := side
	var there: Vector3 = nest + along_wall * 12.0 + out * 1.2
	if not maze.inside(maze.cell_at(there)) or not nav.allowed(maze.cell_at(there)):
		along_wall = -side
		there = nest + along_wall * 12.0 + out * 1.2
	_stand(there, -along_wall)
	swarm.wake_on(boy)
	swarm.swarm.catch_count = 1000
	var midway: Vector3 = nest.lerp(there, 0.5)
	cam.make_current()
	cam.position = midway + out * 8.0 + Vector3.UP * 1.6
	cam.look_at(midway + Vector3.UP * 1.0)
	for k in 3:
		await wait(1.0 if k == 0 else 0.35)
		await shot("58_along_the_wall_%d" % k)
	quit()


func _straight_run(run: int) -> Array:
	for c: Vector2i in nav.lairs(2):
		for step: Vector2i in Maze.STEPS:
			var ok := true
			for k in run:
				if maze.blocked(c + step * k, step) or not nav.allowed(c + step * (k + 1)):
					ok = false
					break
			if ok:
				return [c, step]
	return [nav.lairs(2)[0], Vector2i(1, 0)]


func _stand(at: Vector3, facing: Vector3) -> void:
	boy.global_position = Vector3(at.x, maze.ground_height(at) + 0.1, at.z)
	boy.velocity = Vector3.ZERO
	boy.rotation.y = atan2(facing.x, facing.z)
	world.camera._yaw = atan2(-facing.x, -facing.z)
	world.camera.snap()


func _draws() -> int:
	await process_frame
	await RenderingServer.frame_post_draw
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


## The middle of the hall across `across` from `at` (halfway between the walls either side).
func _middle_of_hall(at: Vector3, across: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var from := at + Vector3.UP * 1.0
	var a := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + across * 30.0, 1))
	var b := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from - across * 30.0, 1))
	if a.is_empty() or b.is_empty():
		return at
	var middle: Vector3 = ((a["position"] as Vector3) + (b["position"] as Vector3)) * 0.5
	return Vector3(middle.x, at.y, middle.z)

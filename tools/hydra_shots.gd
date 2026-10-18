extends SceneTree
## Pictures of the hydra (creatures/hydra/, and MazeHydra in scripts/enemies/).
## First on the component's own floor (creatures/hydra/example.gd): asleep with
## its necks lying about it, awake and weaving from the front, the side, three
## quarters and behind, a head close to, and a strike caught partway through
## (coiled back, darting, holding), a head cut off and the stump, two heads
## growing back. Then in a passage of a real round (World): lying in its pool
## across the hall, awake over the boy, striking at him from several sides.
## Says how many draws a frame takes. Needs a real window (the engine draws
## nothing headless):
##
##     godot --audio-driver Dummy --path . --resolution 1280x720 -s res://tools/hydra_shots.gd -- <folder> [model|maze|sound|low]
##
## (sound only writes the hiss to <folder>/hiss.wav; low takes the model
## pictures of the low-detail model.)

var folder := "hydra_shots"
var only := ""
var example: Node3D
var hydra: Hydra
var camera: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		only = args[1]
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func wait(seconds: float, until := Callable()) -> bool:
	# (by the clock: frames come faster than sixty a second here)
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		if until.is_valid() and until.call():
			return true
	return false


## Looks at the hydra from `direction` (in its own frame: +Z its front), `distance` off, at `height`.
func look(direction: Vector3, distance: float, height: float, fov := 40.0) -> void:
	var at := hydra.global_position + Vector3.UP * height + hydra.global_basis.z * 1.5
	camera.fov = fov
	camera.global_position = at + (hydra.global_basis.orthonormalized() * direction.normalized()) * distance
	camera.look_at(at)


func look_at_point(at: Vector3, from: Vector3, fov := 35.0) -> void:
	camera.fov = fov
	camera.global_position = from
	camera.look_at(at)


func _run() -> void:
	if only == "sound":
		Hydra.hiss_sound().save_to_wav("%s/hiss.wav" % folder)
		print("saved %s/hiss.wav" % folder)
		quit()
		return
	if only != "maze":
		await _model()
	if only != "model" and only != "low":
		await _maze()
	quit()


func _model() -> void:
	example = (load("res://creatures/hydra/example.gd") as GDScript).new()
	root.add_child(example)
	await process_frame
	example.still = true
	hydra = example.hydra
	if only == "low":
		hydra.queue_free()
		hydra = Hydra.new()
		hydra.low_poly = true
		example.add_child(hydra)
		example.hydra = hydra
	camera = example.camera
	camera.make_current()
	example.post.position = Vector3(2.0, 0.8, 11.0)
	example.set_process(false)
	hydra.awake = false
	hydra.settle()
	await wait(1.0)
	look(Vector3(0.7, 0.5, 1), 17.0, 1.0)
	await shot("m01_asleep")
	hydra.awake = true
	hydra.watch = [example.post.position + Vector3.UP * 0.5]
	await wait(3.0)
	look(Vector3(0, 0.15, 1), 19.0, 3.0)
	await shot("m02_front")
	look(Vector3(1, 0.12, 0), 19.0, 3.0)
	await shot("m03_side")
	look(Vector3(0.8, 0.25, 1), 19.0, 3.0)
	await shot("m04_quarter")
	await wait(1.3)
	await shot("m05_quarter_later")
	look(Vector3(-0.7, 0.3, -1), 19.0, 2.5)
	await shot("m06_back")
	# A head close to
	var slot: int = hydra.head_slots()[hydra.head_slots().size() / 2]
	var head := hydra.head_of(slot)
	var mouth := hydra.mouth_of(slot)
	var out := (mouth - head).normalized()
	var side := out.cross(Vector3.UP).normalized()
	look_at_point(head.lerp(mouth, 0.5), head.lerp(mouth, 0.5) + side * 3.2 + out * 2.0 + Vector3.UP * 0.6, 30.0)
	await shot("m07_head")
	# A strike: coiled back, darting, holding
	var target: Vector3 = example.post.position + Vector3.UP * 0.3
	hydra.strike(slot, target)
	await wait(hydra.wind_up * 0.8)
	look(Vector3(1, 0.15, 0.4), 17.0, 2.5)
	await shot("m08_coiled_back")
	await wait(hydra.wind_up * 0.2 + hydra.dart_time * 0.6)
	await shot("m09_darting")
	await wait(hydra.dart_time * 0.4 + 0.05)
	await shot("m10_holding")
	var head_now := hydra.head_of(slot)
	var mouth_now := hydra.mouth_of(slot)
	var out_now := (mouth_now - head_now).normalized()
	look_at_point(mouth_now, mouth_now + out_now.cross(Vector3.UP).normalized() * 3.0 + out_now * 1.5 + Vector3.UP * 0.4, 30.0)
	await shot("m11_fangs")
	await wait(1.5)
	# Several at once
	var count := 0
	for k in hydra.ready_heads():
		if count < 3 and hydra.strike(k, target + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))):
			count += 1
			await wait(0.12)
	await wait(hydra.wind_up * 0.7)
	look(Vector3(0.5, 0.2, 1), 19.0, 2.5)
	await shot("m12_three_coiling")
	await wait(2.0)
	# A head cut off, the stump, and two growing back
	hydra.sever(hydra.head_slots()[0])
	await wait(0.8)
	look(Vector3(0.6, 0.35, 1), 16.0, 2.0)
	await shot("m13_cut")
	await wait(hydra.regrow_time - 0.8 + hydra.grow_time * 0.5)
	await shot("m14_growing_back")
	await wait(hydra.grow_time * 0.6 + 0.5)
	await shot("m15_grown")
	print("heads now: %d" % hydra.head_count())
	example.queue_free()
	await wait(0.2)


## A stand-in the hydra goes after in the maze pictures (where the boy stands: he is not caught).
class Bait extends Node3D:
	var velocity := Vector3.ZERO
	var is_ducking := false


func _maze() -> void:
	var world: Node3D = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	var maze: Maze = world.maze
	var nav := MazeNav.new(maze)
	var boy: Node3D = world.player
	boy.takes_input = false
	# (the round's own enemies are taken away: only the hydra is wanted here)
	for child in world.get_children():
		if child is MazeEnemies or child is Griever:
			child.queue_free()
	await wait(0.5)
	# A hall running straight for a few cells either way
	var lair := nav.lairs(3)[0]
	var out := Vector2i(0, 1)
	var found := false
	for cell: Vector2i in nav.lairs(3):
		for step: Vector2i in Maze.STEPS:
			if not maze.blocked(cell, step) and not maze.blocked(cell + step, step) and not maze.blocked(cell, -step) and not maze.blocked(cell - step, -step) and nav.allowed(cell + step * 2) and nav.allowed(cell - step * 2):
				lair = cell
				out = step
				found = true
				break
		if found:
			break
	var along := Vector3(out.x, 0, out.y)
	var across := Vector3(out.y, 0, -out.x)
	var keeper := MazeHydra.new()
	keeper.maze = maze
	keeper.position = maze.world(lair) + Vector3.UP * 0.05
	keeper.rotation.y = atan2(along.x, along.z)
	var bait := Bait.new()
	world.add_child(bait)
	keeper.targets = [bait]
	world.add_child(keeper)
	hydra = keeper.figure
	await wait(0.3)
	var home := keeper._home
	boy.remove_from_group(&"maze_players")
	boy.global_position = home + along * 22.0 + across * 2.0 + Vector3.UP * 0.1
	boy.rotation.y = atan2(-along.x, -along.z)
	bait.global_position = boy.global_position + Vector3.UP * 30.0
	# (a camera of our own, behind the boy, looking down the hall at it)
	var behind := Camera3D.new()
	world.add_child(behind)
	behind.fov = 50.0
	behind.global_position = boy.global_position + along * 5.0 + Vector3.UP * 3.0
	behind.look_at(home + Vector3.UP * 1.5)
	behind.make_current()
	await wait(1.5)
	await shot("z1_asleep_in_its_pool")
	var with_it := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	keeper.visible = false
	keeper.pool.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var bare := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	keeper.visible = true
	keeper.pool.visible = true
	print("draws: %d with the hydra in sight in its pool, %d with it hidden (+%d)" % [with_it, bare, with_it - bare])
	# He comes nearer: it wakes, and its heads rise and watch him
	boy.global_position = home + along * 13.0 + across * 2.5 + Vector3.UP * 0.1
	bait.global_position = boy.global_position
	behind.global_position = boy.global_position + along * 4.5 + Vector3.UP * 2.6
	behind.look_at(home + Vector3.UP * 3.0)
	keeper.notice(bait)
	await wait(3.5)
	await shot("z2_awake_watching_him")
	var side := Camera3D.new()
	world.add_child(side)
	side.fov = 55.0
	side.global_position = home + along * 9.0 - across * 6.5 + Vector3.UP * 2.2
	side.look_at(home + along * 3.0 + Vector3.UP * 2.6)
	side.make_current()
	await wait(0.2)
	await shot("z3_awake_side")
	# He runs past it: the heads coil back and strike from all sides
	boy.global_position = home + along * 5.5 + across * 4.0 + Vector3.UP * 0.1
	bait.global_position = boy.global_position
	side.global_position = home + along * 13.0 - across * 3.0 + Vector3.UP * 3.0
	side.look_at(home + along * 4.0 + across * 2.0 + Vector3.UP * 2.0)
	await wait(5.0, func() -> bool: return _count(hydra, Hydra.Stage.WIND) >= 2)
	await shot("z4_coiling_to_strike")
	await wait(3.0, func() -> bool: return _count(hydra, Hydra.Stage.DART) >= 1)
	await wait(0.04)
	await shot("z5_strike")
	var standing := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	keeper.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var without := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	keeper.visible = true
	print("draws: %d with the hydra awake in sight, %d with it hidden (+%d)" % [standing, without, standing - without])
	await wait(1.2)
	behind.make_current()
	behind.global_position = boy.global_position + along * 4.0 - across * 1.0 + Vector3.UP * 1.8
	behind.look_at(home + along * 2.0 + Vector3.UP * 2.6)
	await wait(5.0, func() -> bool: return _count(hydra, Hydra.Stage.WIND) >= 2)
	await shot("z6_from_behind_him")
	await wait(3.0, func() -> bool: return _count(hydra, Hydra.Stage.HOLD) >= 1)
	await shot("z7_strike_from_behind_him")
	side.queue_free()
	behind.queue_free()
	world.camera.make_current()


func _count(of: Hydra, which: Hydra.Stage) -> int:
	var n := 0
	for slot in of.head_slots():
		if of.stage(slot) == which:
			n += 1
	return n

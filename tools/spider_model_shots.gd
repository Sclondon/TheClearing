extends SceneTree
## Pictures of the giant spider's model and its moves, on the component's own
## example stage (creatures/giant_spider/example.gd): close up from the front,
## the side and three-quarters, from above, then frames through each move
## (walking, climbing, waiting head down, the drop, landing, rearing, the
## strike). Needs a real window:
##
##     godot --path . --resolution 720x1280 -s res://tools/spider_model_shots.gd -- <folder>

var folder := "shots/spider_model"
var example
var camera: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	_run()


func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await physics_frame
		left -= 1.0 / 60.0


func wait_for(test: Callable, most := 30.0) -> void:
	var left := most
	while left > 0.0 and not test.call():
		await physics_frame
		left -= 1.0 / 60.0


## The camera `distance` from the spider's body, along `from` (in its own space: -Z is in front of it).
func look(from: Vector3, distance: float, at_offset := Vector3.ZERO) -> void:
	var spider: GiantSpider = example.spider
	var body := spider.body
	var target := body.origin + at_offset
	camera.global_position = target + (body.basis.orthonormalized() * from.normalized()) * distance
	camera.look_at(target, Vector3.UP if absf((camera.global_position - target).normalized().y) < 0.95 else Vector3.FORWARD)


func _run() -> void:
	example = load("res://creatures/giant_spider/example.gd").new()
	root.add_child(example)
	example.orbit = false

	await wait(2.6)
	camera = example.camera
	# Standing (in a stop between dashes).
	await wait_for(func() -> bool: return fmod(example.phase_time, 1.6) > 1.25)
	example.paused = true
	await wait(0.6)
	look(Vector3(0.0, 0.35, -1.0), 6.0)
	await shot("01_front")
	look(Vector3(-1.0, 0.3, 0.0), 7.0)
	await shot("02_side")
	look(Vector3(-0.8, 0.45, -0.9), 6.5)
	await shot("03_three_quarter")
	look(Vector3(0.0, 0.12, -1.0), 2.2, Vector3(0.0, -0.05, -0.4))
	await shot("04_face")
	look(Vector3(0.6, 1.0, 0.6), 7.0)
	await shot("05_above")
	look(Vector3(0.7, 0.25, 1.0), 6.0)
	await shot("06_back")
	example.paused = false
	example.spider.process_mode = Node.PROCESS_MODE_INHERIT
	# Walking: a run of frames from the side.
	await wait_for(func() -> bool: return fmod(example.phase_time, 1.6) < 0.2)
	await wait(0.3)
	for i in 4:
		look(Vector3(-1.0, 0.25, 0.0), 8.0)
		await shot("10_walk_%d" % i)
		await wait(0.05)
	# Climbing.
	await wait_for(func() -> bool: return example.phase == example.Phase.CLIMB and example.spider.global_position.y > 3.0)
	camera.global_position = example.spider.body.origin + Vector3(6.0, -1.0, 8.0)
	camera.look_at(example.spider.body.origin)
	await shot("20_climb")
	await wait_for(func() -> bool: return example.phase == example.Phase.PERCH and example.phase_time > 1.0)
	camera.global_position = example.spider.body.origin + Vector3(-4.0, -5.0, 7.0)
	camera.look_at(example.spider.body.origin)
	await shot("21_perch_below")
	camera.global_position = example.spider.body.origin + Vector3(5.0, 0.5, 4.0)
	camera.look_at(example.spider.body.origin)
	await shot("22_perch_side")
	await wait_for(func() -> bool: return example.phase == example.Phase.DROP and example.phase_time > 0.55)
	camera.global_position = example.spider.body.origin + Vector3(8.0, 1.0, 5.0)
	camera.look_at(example.spider.body.origin + Vector3.UP * 1.5)
	await shot("23_drop")
	await wait_for(func() -> bool: return example.phase == example.Phase.LAND and example.phase_time > 0.25)
	camera.global_position = example.spider.body.origin + Vector3(6.0, 2.5, 6.0)
	camera.look_at(example.spider.body.origin + Vector3.UP * 1.0)
	await shot("24_landed")
	# The strike, from the side and from in front, low (as the boy would see it).
	await wait_for(func() -> bool: return example.spider.stage() == GiantSpider.Stage.REAR and example.spider.stage_left() < 0.25)
	example.paused = true
	example.spider.process_mode = Node.PROCESS_MODE_DISABLED
	camera.global_position = Vector3(6.5, 1.6, -3.5)
	camera.look_at(example.spider.body.origin + Vector3.UP * 0.6)
	await shot("30_rear_side")
	camera.global_position = example.POST + Vector3(0.6, 1.4, 1.8)
	camera.look_at(example.spider.body.origin + Vector3.UP * 0.6)
	await shot("31_rear_front")
	example.paused = false
	example.spider.process_mode = Node.PROCESS_MODE_INHERIT
	await wait_for(func() -> bool: return example.spider.stage() == GiantSpider.Stage.STRIKE and example.spider.stage_left() < 0.1)
	example.paused = true
	example.spider.process_mode = Node.PROCESS_MODE_DISABLED
	camera.global_position = Vector3(6.5, 1.6, -2.0)
	camera.look_at(example.spider.body.origin)
	await shot("32_strike_side")
	example.paused = false
	example.spider.process_mode = Node.PROCESS_MODE_INHERIT
	quit()

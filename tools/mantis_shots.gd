extends SceneTree
## Pictures of the giant mantis (creatures/mantis): close up on a plain floor
## under the game's kind of light (each view, the head and its eyes, its head
## turned after a point, the strike frame by frame, the threat display, a
## walking strip, eating), and in a real round (MazeMantis: among its plants by
## a hall wall, from the boy coming down the hall; its head on him; the strike
## at him; the display). Says how many draws a frame takes. Needs a real window:
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/mantis_shots.gd -- <folder> [studio|maze|all]

var folder := "mantis_shots"
var mode := "all"
var camera: Camera3D
var stage_root: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		folder = args[0]
	if args.size() > 1:
		mode = args[1]
	DirAccess.make_dir_recursive_absolute(folder)
	_run.call_deferred()


func _run() -> void:
	if mode in ["studio", "all"]:
		await _studio()
	if mode in ["maze", "all"]:
		await _maze()
	quit()


func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	if camera:
		print("  camera at %s looking %s" % [camera.global_position, -camera.global_basis.z])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func frames(count: int) -> void:
	for i in count:
		await process_frame


func until(test: Callable, most := 900) -> void:
	for i in most:
		if test.call():
			return
		await process_frame


func look(target: Vector3, from: Vector3, fov := 40.0) -> void:
	camera.fov = fov
	camera.global_position = target + from
	camera.look_at(target, Vector3.UP)


func studio_stage() -> void:
	stage_root = Node3D.new()
	root.add_child(stage_root)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.64, 0.66)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	stage_root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(35.0), 0.0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	stage_root.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	floor.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.36, 0.34, 0.31)
	floor.material_override = ground
	stage_root.add_child(floor)
	camera = Camera3D.new()
	stage_root.add_child(camera)
	camera.current = true


func _studio() -> void:
	studio_stage()
	var mantis := GiantMantis.new()
	mantis.sound = false
	mantis.sway = 0.0
	stage_root.add_child(mantis)
	await frames(10)
	var middle := Vector3(0.0, 1.5, 0.0)
	look(middle, Vector3(7.5, 0.6, 0.3))
	await shot("t01_side")
	look(middle, Vector3(5.2, 1.6, 5.6))
	await shot("t02_three_quarter")
	look(middle + Vector3(0.0, 0.4, 0.0), Vector3(0.4, 0.4, 7.5))
	await shot("t03_front")
	look(middle, Vector3(-5.0, 3.0, -5.5))
	await shot("t04_back_quarter")
	look(Vector3(0.0, 2.75, 0.85), Vector3(0.5, 0.15, 1.6))
	await shot("t05_head")
	look(Vector3(0.0, 2.75, 0.85), Vector3(-1.1, 0.25, 1.2))
	await shot("t06_head_other_side")
	look(Vector3(0.0, 2.3, 1.2), Vector3(1.4, -0.2, 1.6))
	await shot("t07_forelegs_in_prayer")
	look(Vector3(0.0, 1.0, -0.3), Vector3(0.2, 7.0, 0.01))
	await shot("t08_from_above")
	# Its head follows a point round
	mantis.look_at_point = Vector3(4.0, 1.4, 3.0)
	await frames(60)
	look(Vector3(0.0, 2.4, 0.5), Vector3(4.0, 0.2, 4.0))
	await shot("t09_looking_at_you")
	mantis.look_at_point = Vector3(-4.0, 1.0, 1.0)
	await frames(60)
	look(Vector3(0.0, 2.4, 0.5), Vector3(4.0, 0.2, 4.0))
	await shot("t10_looking_away_left")
	mantis.look_at_point = Vector3.INF
	# The strike, frame by frame
	var chest := Vector3(0.0, 1.3, 3.2)
	var marker := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.12
	ball.height = 0.24
	marker.mesh = ball
	stage_root.add_child(marker)
	marker.global_position = chest
	mantis.strike(chest)
	var k := 0
	var seen := {}
	for i in 60:
		await process_frame
		var stage := mantis.strike_stage()
		if not seen.has(stage) or stage == GiantMantis.Strike.SHOOT:
			seen[stage] = true
			look(Vector3(0.0, 1.8, 1.6), Vector3(6.0, 0.6, 1.0))
			await shot("t11_strike_%d_%s" % [k, GiantMantis.Strike.keys()[stage]])
			k += 1
		if stage == GiantMantis.Strike.NONE and i > 5:
			break
	marker.queue_free()
	# The threat display
	mantis.display = true
	await frames(80)
	look(middle + Vector3(0.0, 0.4, 0.0), Vector3(0.5, 0.6, 7.0))
	await shot("t12_display_front")
	look(middle + Vector3(0.0, 0.4, 0.0), Vector3(5.5, 1.2, 4.5))
	await shot("t13_display_quarter")
	mantis.display = false
	await frames(80)
	# Walking: a strip
	mantis.sway = 1.0
	var walker := func(step: float) -> void:
		mantis.global_position += Vector3(0.0, 0.0, 0.7) * step
	for i in 90:
		walker.call(1.0 / 60.0)
		await process_frame
	for n in 4:
		for i in 9:
			walker.call(1.0 / 60.0)
			await process_frame
		look(mantis.global_position + Vector3(0.0, 1.3, 0.0), Vector3(7.0, 0.5, 0.0))
		await shot("t14_walk_%d" % n)
	# Eating
	mantis.eating = true
	await frames(60)
	look(mantis.global_position + Vector3(0.0, 2.3, 0.8), Vector3(2.2, 0.3, 2.4))
	await shot("t15_eating")
	mantis.eating = false
	# The low model
	var low := GiantMantis.new()
	low.low_poly = true
	low.sound = false
	stage_root.add_child(low)
	low.global_position = Vector3(5.0, 0.0, 0.0)
	await frames(10)
	look(low.global_position + Vector3(0.0, 1.5, 0.0), Vector3(5.2, 1.6, 5.6))
	await shot("t16_low_model")
	stage_root.queue_free()
	await frames(2)


## Looks at `target` from the first of `offsets` with nothing solid between (by a ray), or as far out along the first as is clear.
func look_clear(_nav: MazeNav, target: Vector3, offsets: Array, fov := 45.0) -> void:
	var space := camera.get_world_3d().direct_space_state
	for offset: Vector3 in offsets:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(target, target + offset * 1.1, 1))
		if hit.is_empty():
			look(target, offset, fov)
			return
	var first: Vector3 = offsets[0]
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(target, target + first, 1))
	var clear: float = target.distance_to(hit["position"]) - 0.6 if not hit.is_empty() else first.length()
	look(target, first.normalized() * maxf(clear, 1.0), fov)


## Looks at `target` from about `far` off and `high` up, from the way nearest
## `prefer` that has nothing solid between (rays), trying nearer if need be.
func view(target: Vector3, prefer: Vector3, far: float, high: float, fov := 45.0) -> void:
	var space := camera.get_world_3d().direct_space_state
	var start := atan2(prefer.x, prefer.z)
	for distance: float in [far, far * 0.75, far * 0.5, far * 0.35]:
		for k in 36:
			var a := start + (TAU * ceili(k / 2.0) / 36.0) * (1.0 if k % 2 == 0 else -1.0)
			var from := target + Vector3(sin(a) * distance, high, cos(a) * distance)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, target, 1))
			var back := space.intersect_ray(PhysicsRayQueryParameters3D.create(target, from, 1))
			if hit.is_empty() and back.is_empty():
				look(target, from - target, fov)
				return
	look(target, prefer.normalized() * far + Vector3.UP * high, fov)


func _maze() -> void:
	var world: Node3D = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	var maze: Maze = world.maze
	var boy: Node3D = world.player
	boy.set(&"takes_input", false)
	for node: Node in world.get_children():
		if node is MazeEnemies or node is Griever:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			(node as Node3D).visible = false
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.far = 400.0
	var nav := MazeNav.new(maze)
	# A long straight hall
	var best := Vector2i.ZERO
	var best_run := 0
	var best_step := Vector2i(1, 0)
	for cell: Vector2i in nav.lairs(3):
		for step: Vector2i in Maze.STEPS:
			var run := 0
			var at := cell
			while run < 8 and not maze.blocked(at, step) and maze.inside(at + step) and not maze.in_clearing(at + step):
				at += step
				run += 1
			if run > best_run:
				best_run = run
				best = cell
				best_step = step
	var way := Vector3(best_step.x, 0.0, best_step.y)
	var holder := MazeEnemies.new()
	holder.maze = maze
	world.add_child(holder)
	var one := MazeMantis.new()
	one.sound = false
	holder.add(one, best + best_step * 2, 0.0, 77)
	var far_end := maze.world(best + best_step * 5)
	boy.global_position = far_end + Vector3.UP * 0.1
	await frames(40)
	var at := one.global_position
	var out := Vector3(sin(one.facing_yaw), 0.0, cos(one.facing_yaw))
	# (down the hall: the way, from in front of it, that is open furthest, by rays)
	var space := world.get_world_3d().direct_space_state
	var from_front := at + out * 3.0 + Vector3.UP * 1.6
	var along_wall := out.cross(Vector3.UP)
	var down := 0.0
	for k in 24:
		var a := TAU * k / 24.0
		var dir := Vector3(sin(a), 0.0, cos(a))
		if dir.dot(out) < -0.2:
			continue
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from_front, from_front + dir * 30.0, 1))
		var free := 30.0 if hit.is_empty() else from_front.distance_to(hit["position"])
		if free > down:
			down = free
			along_wall = dir
	down = clampf(down - 2.0, 4.0, 18.0)
	print("  mantis at %s facing %s, open way %s for %.1f m" % [at, out, along_wall, down])
	var eye_of := func(where: Vector3) -> Vector3: return where + Vector3.UP * 2.0 + (where - at).normalized() * 2.0
	boy.global_position = at + out * 3.0 + along_wall * down
	await frames(60)
	var eye: Vector3 = eye_of.call(boy.global_position)
	look_clear(nav, at + Vector3.UP * 1.8, [eye - at - Vector3.UP * 1.8], 50.0)
	await shot("m01_from_down_the_hall")
	boy.global_position = at + out * 3.0 + along_wall * minf(down, 8.0)
	await frames(60)
	eye = eye_of.call(boy.global_position)
	look_clear(nav, at + Vector3.UP * 1.8, [eye - at - Vector3.UP * 1.8], 45.0)
	await shot("m02_closer_its_head_on_him")
	# (the camera from here on is out along that open way from in front of it, which the rays found clear)
	var from_open := func(far: float, high: float) -> Vector3: return at + out * 6.5 + along_wall * far + Vector3.UP * high - at
	view(at + Vector3.UP * 1.5, out + along_wall, 6.5, 0.2)
	await shot("m03_among_its_plants")
	# He faces it from near: the display
	boy.global_position = at + out * 6.0 + along_wall * 1.0
	var facing := at - boy.global_position
	boy.set(&"facing_yaw", atan2(facing.x, facing.z))
	await until(func() -> bool: return one.mode == MazeMantis.Mode.DISPLAY, 300)
	await frames(50)
	view(at + Vector3.UP * 2.0, out, 7.5, -0.3)
	await shot("m04_display")
	# He comes into reach: the strike
	await until(func() -> bool: return one.mode != MazeMantis.Mode.DISPLAY, 400)
	boy.global_position = at + out * 2.6
	await until(func() -> bool: return one.mantis.strike_stage() == GiantMantis.Strike.CLAMP, 200)
	view(at + out * 1.3 + Vector3.UP * 1.6, along_wall, 6.5, 0.0)
	await shot("m05_strike")
	await frames(30)
	world.queue_free()
	await frames(2)

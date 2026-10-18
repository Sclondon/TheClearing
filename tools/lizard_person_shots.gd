extends SceneTree
## Pictures of the lizard people (creatures/lizard_person/,
## scripts/enemies/maze_lizard_person.gd): first in a plain grey studio with a
## wall, close, as it stands, walks, crawls and scuttles, waits head down on
## the wall, hisses, lunges and leaps, its face (tongue out, membrane drawn);
## then in a hall of a real round (World: the game's light and mist), a band of
## them on the walls over the boy, one stalking along a wall beside him, one
## leaping down, one on the ground, and the draws a frame takes. Needs a real
## window:
##
##     godot --path . --resolution 1280x720 -s res://tools/lizard_person_shots.gd -- <folder> [studio|maze]

var folder := "lizard_shots"
var only := ""
var camera: Camera3D
var stage: Node3D


## Moves a lizard along its surface at `speed` (m/s) the way it faces, every frame.
class Driver:
	extends Node
	var body: LizardPerson
	var speed := 0.0

	func _process(delta: float) -> void:
		body.global_position += body.heading.normalized() * speed * delta


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
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < seconds * 1000.0:
		await process_frame
		if until.is_valid() and until.call():
			return true
	return false


func view(from: Vector3, at: Vector3) -> void:
	camera.global_position = from
	camera.look_at(at)


func _run() -> void:
	if only != "maze":
		await _studio()
	if only != "studio":
		await _maze()
	quit()


# --- The studio ---

func _studio() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.6, 0.62, 0.64)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.72, 0.75)
	environment.ambient_light_energy = 0.5
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.95, 0.6, 0.0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	stage.add_child(sun)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.46, 0.45, 0.43)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	floor_mesh.mesh = plane
	floor_mesh.material_override = grey
	stage.add_child(floor_mesh)
	# A wall, its face towards -X at x = 6.
	var wall := MeshInstance3D.new()
	var block := BoxMesh.new()
	block.size = Vector3(2.0, 12.0, 30.0)
	wall.mesh = block
	wall.material_override = grey
	wall.position = Vector3(7.0, 6.0, 0.0)
	stage.add_child(wall)
	camera = Camera3D.new()
	camera.fov = 40.0
	stage.add_child(camera)
	camera.make_current()

	var lizard := LizardPerson.new()
	lizard.sound = false
	stage.add_child(lizard)
	var driver := Driver.new()
	driver.body = lizard
	stage.add_child(driver)
	var head := func() -> Vector3: return lizard.head_point()

	# Standing, still.
	lizard.global_position = Vector3.ZERO
	lizard.heading = Vector3.BACK
	lizard.settle()
	await wait(0.6)
	view(Vector3(2.2, 1.4, 3.6), Vector3(0.0, 0.95, 0.0))
	await shot("01_stand_quarter")
	view(Vector3(4.2, 1.1, 0.0), Vector3(0.0, 0.9, 0.0))
	await shot("02_stand_side")
	view(Vector3(0.0, 1.55, 1.3), head.call())
	lizard.aim = camera.global_position
	await wait(0.4)
	await shot("03_face_front")
	view(lizard.head_point() + Vector3(0.6, 0.05, 0.35), lizard.head_point())
	await shot("04_face_side")
	lizard.aim = Vector3.INF
	# Walking upright.
	driver.speed = 1.1
	await wait(1.2)
	view(lizard.global_position + Vector3(3.5, 1.2, 1.0), lizard.global_position + Vector3(0.0, 0.9, 0.3))
	await shot("05_walk")
	# Crawling, then scuttling flat out (the camera keeps up).
	driver.speed = 2.0
	await wait(1.0)
	view(lizard.global_position + Vector3(3.2, 1.6, 1.4), lizard.global_position + Vector3(0.0, 0.3, 0.4))
	await shot("06_crawl")
	driver.speed = 5.0
	lizard.global_position = Vector3(0.0, 0.0, -6.0)
	await wait(0.8)
	var at := lizard.global_position
	view(at + Vector3(3.0, 2.4, 2.0), at + Vector3(0.0, 0.2, 0.6))
	await shot("07_scuttle")
	view(at + Vector3(0.3, 4.5, 0.6), at + Vector3(0.0, 0.0, 0.2))
	await shot("08_scuttle_top")
	driver.speed = 0.0

	# On the wall: running up it, then waiting head down.
	lizard.surface = Vector3.LEFT
	lizard.heading = Vector3.UP
	lizard.global_position = Vector3(5.98, 2.0, 0.0)
	lizard.settle()
	driver.speed = 3.0
	await wait(0.8)
	view(lizard.global_position + Vector3(-4.0, 0.0, 2.5), lizard.global_position + Vector3(0.0, 0.5, 0.0))
	await shot("09_wall_climb")
	driver.speed = 0.0
	lizard.global_position = Vector3(5.98, 4.5, 0.0)
	lizard.heading = Vector3.DOWN
	lizard.settle()
	await wait(0.6)
	view(Vector3(1.5, 1.5, 3.0), lizard.global_position + Vector3(0.0, -0.4, 0.0))
	await shot("10_wall_waiting_below")
	view(lizard.global_position + Vector3(-2.2, 0.3, 2.6), lizard.global_position + Vector3(0.0, -0.3, 0.0))
	await shot("11_wall_waiting_close")
	lizard.aim = Vector3(2.0, 1.0, 1.0)
	lizard.hiss(5.0)
	await wait(0.5)
	view(lizard.global_position + Vector3(-2.6, -0.6, 2.4), lizard.global_position + Vector3(0.0, -0.5, 0.0))
	await shot("12_wall_hiss")
	driver.speed = 2.6
	lizard.hiss(0.0)
	lizard._hiss_left = 0.0
	lizard.heading = Vector3.FORWARD
	lizard.aim = Vector3.INF
	await wait(0.8)
	view(lizard.global_position + Vector3(-3.6, -0.4, 0.6), lizard.global_position + Vector3(0.0, 0.0, 0.0))
	await shot("13_wall_along")
	driver.speed = 0.0

	# On the ground: the hiss, the lunge, in the air, cold.
	lizard.surface = Vector3.UP
	lizard.heading = Vector3.BACK
	lizard.global_position = Vector3(0.0, 0.0, 0.0)
	lizard.settle()
	lizard.aim = Vector3(0.0, 1.0, 3.0)
	lizard.hiss(5.0)
	await wait(0.6)
	view(Vector3(1.8, 1.2, 3.0), Vector3(0.0, 0.7, 0.2))
	await shot("14_hiss_front")
	view(lizard.head_point() + Vector3(0.35, 0.05, 0.45), lizard.head_point() + Vector3(0.0, -0.05, 0.0))
	await shot("15_hiss_face")
	lizard._hiss_left = 0.0
	lizard.lunge()
	await wait(LizardPerson.GATHER_TIME + LizardPerson.REACH_TIME * 0.6)
	view(Vector3(3.0, 1.0, 1.5), Vector3(0.0, 0.5, 0.6))
	await shot("16_lunge")
	await wait(1.0)
	lizard.airborne = true
	lizard.global_position = Vector3(0.0, 1.2, 0.0)
	await wait(0.6)
	view(Vector3(3.0, 1.8, 2.0), Vector3(0.0, 1.4, 0.2))
	await shot("17_airborne")
	lizard.airborne = false
	lizard.global_position = Vector3.ZERO
	lizard.crouch = true
	lizard.warmth = 0.0
	lizard.aim = Vector3.INF
	await wait(1.5)
	view(Vector3(2.4, 1.3, 2.4), Vector3(0.0, 0.25, 0.0))
	await shot("18_cold")
	lizard.warmth = 1.0
	lizard.crouch = false
	# The face, its tongue out and its membranes drawn.
	view(Vector3(0.0, 1.6, 1.0), Vector3(0.0, 1.5, 0.3))
	lizard.aim = camera.global_position
	await wait(0.5)
	lizard._flick = LizardPerson.FLICK_TIME * 0.45
	lizard._blink = LizardPerson.BLINK_TIME * 0.5
	lizard._flick_in = 9.0
	lizard._blink_in = 9.0
	lizard.process_mode = Node.PROCESS_MODE_DISABLED
	lizard._pose(0.0)
	view(lizard.head_point() + Vector3(0.3, 0.12, 0.5), lizard.head_point() + Vector3(0.0, 0.0, 0.08))
	await shot("19_tongue")
	# The low-detail model (phones), standing beside it.
	var low := LizardPerson.new()
	low.sound = false
	low.low_poly = true
	stage.add_child(low)
	low.global_position = Vector3(1.2, 0.0, 0.0)
	low.heading = Vector3.BACK
	low.settle()
	lizard.process_mode = Node.PROCESS_MODE_INHERIT
	await wait(0.5)
	view(Vector3(0.6, 1.3, 4.5), Vector3(0.6, 0.9, 0.0))
	await shot("20_full_and_low")
	stage.queue_free()
	await process_frame


# --- In the maze ---

func _maze() -> void:
	var world = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("LIZARD", 1), 0, [{"slot": 0, "look": "p11"}], false)
	var maze: Maze = world.maze
	var nav := MazeNav.new(maze)
	var boy = world.player
	boy.takes_input = false
	# (the round's own hunters are kept busy elsewhere: their only target is a
	# stand-in in the clearing, where nothing hunts)
	var elsewhere := Node3D.new()
	world.add_child(elsewhere)
	world.enemies.set_targets([elsewhere])
	world.griever.targets = [elsewhere]
	world.day.set_hour(11.0)
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.far = 900.0
	world.add_child(camera)
	camera.make_current()
	# A straight hall out in the ring.
	var hall := _hall(maze, nav)
	var cell: Vector2i = hall[0]
	var along: Vector3 = hall[1]
	var across := Vector3(along.z, 0.0, along.x)
	boy.global_position = maze.world(cell) + along * 40.0 + Vector3(0.0, 0.1, 0.0)
	await wait(0.5)
	safe_view(maze.world(cell) - along * 14.0 + Vector3.UP * 1.6, maze.world(cell) + Vector3.UP * 3.0)
	var bare := await _draws()
	# A band of three, on the walls each side of the hall.
	var band := MazeLizardPerson.band(3)
	for k in band.size():
		var one: MazeLizardPerson = band[k]
		one.maze = maze
		one.seed_choices(k + 3)
		one.targets = [elsewhere]
		one.pose_range = 2000.0
		one.position = maze.world(cell) + along * (k - 1) * 3.5 + across * (2.5 if k % 2 == 0 else -2.5) + Vector3.UP * 0.05
		world.add_child(one)
	await wait(1.0)
	print("draws without the band %d, with it %d" % [bare, await _draws()])
	# (and the same frame, the band hidden and shown again: what they cost themselves)
	for one: MazeLizardPerson in band:
		one.look.visible = false
	var hidden := await _draws()
	for one: MazeLizardPerson in band:
		one.look.visible = true
	print("the band hidden %d, shown %d (three of them)" % [hidden, await _draws()])
	var near: MazeLizardPerson = band[1]
	# 1: down the hall as he comes, three on the walls over it.
	safe_view(maze.world(cell) - along * 15.0 + Vector3.UP * 1.6 + across * 0.8, maze.world(cell) + Vector3.UP * 4.0)
	await shot("m1_hall")
	# 2: from under one, looking up its wall.
	var face := near.wall
	var side := Vector3.UP.cross(face).normalized()
	var runs := Vector2(_face_run(near.global_position, face, side), _face_run(near.global_position, face, -side))
	var way := side if runs.x >= runs.y else -side
	var foot := near.global_position
	foot.y = maze.ground_height(foot)
	safe_view(foot + face * 2.4 - way * 1.6 + Vector3.UP * 1.4, near.global_position + Vector3.DOWN * 0.5)
	await shot("m2_under")
	# 3: close, from the side, level with it.
	safe_view(near.global_position + face * 2.6 - way * 2.4 + Vector3.DOWN * 0.3, near.global_position + Vector3.DOWN * 0.4)
	await shot("m3_close")
	# 4: he comes along the hall beside its wall: it stalks along the face towards him (seen from behind him).
	var reach := minf(maxf(runs.x, runs.y) - 1.0, 14.0)
	boy.global_position = foot + face * 3.0 + way * reach
	boy.global_position.y = maze.ground_height(boy.global_position) + 0.1
	for one: MazeLizardPerson in band:
		one.targets = [boy]
	near.notice(boy)
	await wait(2.5, func() -> bool: return near.mode == MazeLizardPerson.Mode.CRAWL and not near._stopped and near._mode_time > 1.0)
	var b: Vector3 = boy.global_position
	safe_view(b + way * 3.5 + face * 1.2 + Vector3.UP * 2.0, near.global_position + Vector3.DOWN * 0.3)
	await shot("m4_stalking")
	# 5: it is level with him: the warning, then the leap.
	await wait(6.0, func() -> bool: return near.mode == MazeLizardPerson.Mode.HISS and near._mode_time > 0.35)
	if near.mode == MazeLizardPerson.Mode.HISS:
		safe_view(boy.global_position + Vector3.UP * 1.6 + (boy.global_position - near.global_position).normalized() * 2.5 + along * 1.0, near.global_position)
		await shot("m5_hiss")
	await wait(3.0, func() -> bool: return near.mode == MazeLizardPerson.Mode.POUNCE and near._mode_time > near._leap_time * 0.4)
	if near.mode == MazeLizardPerson.Mode.POUNCE:
		safe_view(near.global_position + across * 4.0 * signf(across.dot(boy.global_position - near.global_position) + 0.01) + along * 3.0 + Vector3.UP * 0.5, near.global_position)
		await shot("m6_leap")
	# 7: on the ground after him (he sprints; seen from ahead of him).
	boy.global_position = near.global_position + way * 6.0
	boy.global_position.y = maze.ground_height(boy.global_position) + 0.1
	near._spared.clear()
	near.wall = Vector3.ZERO
	near._enter(MazeLizardPerson.Mode.HUNT)
	near._mode_time = 1.0
	near.notice(boy)
	await wait(0.7)
	safe_view(boy.global_position + way * 3.0 + Vector3.UP * 1.4 + across * 0.8, near.global_position + Vector3.UP * 0.4)
	await shot("m7_ground")
	# 8: night: cold and dark on the wall.
	boy.global_position = Vector3(0.0, 0.1, 0.0)
	for one: MazeLizardPerson in band:
		one.quarry = null
		one._forget = 0.0
		one._last_seen = Vector3.INF
	world.day.set_hour(23.0)
	await wait(10.0, func() -> bool: return near.mode == MazeLizardPerson.Mode.CLING and near.wall != Vector3.ZERO)
	near._warm_in = 0.0
	await wait(1.5)
	boy.global_position = near.wall_foot + near.wall * 4.0 + way * 9.0
	boy.global_position.y = maze.ground_height(boy.global_position) + 0.1
	await wait(0.5)
	safe_view(near.global_position + near.wall * 2.4 - way * 2.0 - Vector3.UP * 0.6, near.global_position + Vector3.DOWN * 0.4)
	await shot("m8_night")


func _draws() -> int:
	await process_frame
	await RenderingServer.frame_post_draw
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)


## A cell in a straight hall well out in the ring, and the way along it.
func _hall(maze: Maze, nav: MazeNav) -> Array:
	var lairs := nav.lairs(4)
	for k in lairs.size():
		var cell: Vector2i = lairs[(lairs.size() / 2 + k) % lairs.size()]
		for s: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var across := Vector2i(s.y, s.x)
			var straight := true
			for t: int in [-1, 0, 1]:
				var c: Vector2i = cell + s * t
				if maze.blocked(c, across) == false or maze.blocked(c, -across) == false:
					straight = false
			if straight and not maze.blocked(cell, s) and not maze.blocked(cell, -s) and not maze.blocked(cell + s, s) and not maze.blocked(cell - s, -s):
				return [cell, Vector3(s.x, 0.0, s.y)]
	return [lairs[lairs.size() / 2], Vector3(1, 0, 0)]


## The camera at `from` looking at `at`, brought in short of any wall between.
func safe_view(from: Vector3, at: Vector3) -> void:
	var space := camera.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, from, 1))
	if not hit.is_empty():
		from = (hit["position"] as Vector3) + (at - from).normalized() * 0.4
	view(from, at)


## How far the face of a wall (its `normal`) goes on from `from` along `dir`, at that height.
func _face_run(from: Vector3, normal: Vector3, dir: Vector3) -> float:
	var space := camera.get_world_3d().direct_space_state
	var d := 0.0
	while d < 30.0:
		var at := from + dir * (d + 0.5)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + normal * 0.6, at - normal * 0.6, 1))
		if hit.is_empty():
			break
		d += 0.5
	return d

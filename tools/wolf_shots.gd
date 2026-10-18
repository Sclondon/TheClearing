extends SceneTree
## Pictures of the grey wolves (creatures/wolf): close up on a plain floor under
## the game's kind of light (each view, the head, the two models, a wolf beside
## the feral dog, the coyote and the boy, rank in its tail, the hunting trot,
## sniffing, the howl standing and sitting, a play-bow, the snarl), strips of
## frames from the side through a stride of the trot (with the prints it leaves,
## to see each hind foot come down in its forefoot's) and of the gallop, and in a
## hall of a real round (a pack trotting in file, the chorus at the den, the hunt
## coming down the hall). Says how many draws a frame takes. Needs a real window:
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/wolf_shots.gd -- <folder> [studio|strips|maze|all]

const SIZE := Wolf.SCALE

var folder := "wolf_shots"
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
	Engine.max_fps = 60
	# (the howls made at once, so that every picture of one is in the middle of it)
	for key: String in WolfVoice.KEYS:
		WolfVoice.make_now(key)
	_run.call_deferred()


func _run() -> void:
	if mode in ["studio", "all"]:
		await _studio()
	if mode in ["strips", "all"]:
		await _strips()
	if mode in ["maze", "all"]:
		await _maze()
	quit()


var mover := Callable()


func shot(name: String) -> void:
	for i in 2:
		if mover.is_valid():
			mover.call(root.get_process_delta_time())
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func frames(count: int) -> void:
	for i in count:
		await process_frame


func look(target: Vector3, offset: Vector3, animal: Node3D = null, fov := 40.0) -> void:
	var from := offset
	if animal:
		from = Basis(Vector3.UP, animal.rotation.y) * offset
	camera.fov = fov
	camera.global_position = target + from
	camera.look_at(target, Vector3.UP)


func _stage() -> void:
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
	sun.shadow_enabled = true
	stage_root.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	floor.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.5, 0.5, 0.5)
	floor.material_override = ground
	stage_root.add_child(floor)
	# (something to stand on, for the boy)
	var solid := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	shape.shape = box
	shape.position.y = -0.5
	solid.add_child(shape)
	stage_root.add_child(solid)
	camera = Camera3D.new()
	stage_root.add_child(camera)
	camera.current = true


func _wolf(variant := 0, rank := 1) -> Wolf:
	var wolf := Wolf.new()
	wolf.sound = false
	wolf.variant = variant
	wolf.rank = rank
	wolf.scale = Vector3.ONE * SIZE
	stage_root.add_child(wolf)
	return wolf


# --- On a plain floor ---

func _studio() -> void:
	_stage()
	var wolf := _wolf(0, 0)
	await frames(20)
	var middle := Vector3(0.0, 0.6, 0.1)
	var head := Vector3(0.0, 0.92, 0.55)
	look(middle, Vector3(0.0, 0.3, 2.8), wolf)
	await shot("w01_front")
	look(middle, Vector3(3.4, 0.25, 0.0), wolf)
	await shot("w02_side")
	look(middle, Vector3(2.3, 0.6, 2.2), wolf)
	await shot("w03_three_quarter")
	look(middle, Vector3(-2.2, 1.0, -2.2), wolf)
	await shot("w04_back_quarter")
	look(head, Vector3(0.62, 0.1, 0.75), wolf)
	await shot("w05_head")
	look(head, Vector3(0.05, 0.05, 1.0), wolf)
	await shot("w06_head_front")
	look(head, Vector3(1.0, 0.05, 0.0), wolf)
	await shot("w07_head_side")
	wolf.snarling = true
	wolf.stalking = true
	await frames(40)
	look(head + Vector3(0.0, -0.12, 0.0), Vector3(0.6, 0.0, 0.75), wolf)
	await shot("w08_snarl")
	wolf.snarling = false
	wolf.stalking = false

	var male := _wolf(1, 0)
	male.position = Vector3(1.3, 0.0, -0.6)
	male.rotation.y = -0.4
	await frames(20)
	look(Vector3(0.65, 0.6, 0.0), Vector3(0.9, 0.6, 4.2))
	await shot("w09_pair")
	male.queue_free()

	# Beside the feral dog, the coyote and the boy, for size and kind.
	var dog := Dog.new()
	dog.scale = Vector3.ONE * 1.35
	dog.position = Vector3(-1.4, 0.0, 0.0)
	stage_root.add_child(dog)
	var coyote := Coyote.new()
	coyote.sound = false
	coyote.scale = Vector3.ONE * 0.82
	coyote.position = Vector3(1.3, 0.0, 0.0)
	stage_root.add_child(coyote)
	var boy: Node3D = load("res://player.tscn").instantiate()
	boy.set(&"takes_input", false)
	stage_root.add_child(boy)
	boy.global_position = Vector3(2.6, 0.05, 0.4)
	boy.rotation.y = -PI * 0.5
	await frames(40)
	look(Vector3(0.6, 0.6, 0.0), Vector3(0.6, 0.7, 6.0))
	await shot("w10_beside_dog_coyote_boy")
	dog.queue_free()
	coyote.queue_free()
	boy.queue_free()

	# Rank in the tail: the breeding pair watching (tail up), a low one (tail down, ears back)
	var low := _wolf(0, 2)
	low.position = Vector3(0.0, 0.0, -2.1)
	wolf.look_at_point = Vector3(0.0, 1.2, 8.0)
	low.look_at_point = Vector3(0.0, 1.2, 8.0)
	await frames(60)
	look(Vector3(0.0, 0.6, -1.0), Vector3(5.8, 0.5, 0.0))
	await shot("w11_rank_tails")
	low.queue_free()
	wolf.look_at_point = Vector3.INF

	wolf.hunting = true
	await _moving(wolf, 3.2, 2.0, "w12_hunting_trot")
	look(wolf.global_position + Vector3(0.0, 0.6, 0.0), Vector3(2.4, 0.5, 2.2), wolf)
	await shot("w13_hunting_quarter")
	wolf.hunting = false
	wolf.tracking = true
	await _moving(wolf, 1.0, 1.6, "w14_sniffing")
	wolf.tracking = false
	await _moving(wolf, 0.0, 1.2, "")
	wolf.howl_now(0, false)
	await frames(70)
	look(wolf.global_position + Vector3(0.0, 0.8, 0.3), Vector3(2.2, 0.3, 1.6), wolf)
	await shot("w15_howl")
	look(wolf.global_position + Vector3(0.0, 1.0, 0.5), Vector3(0.9, 0.05, 0.6), wolf)
	await shot("w16_howl_head")
	await frames(260)
	wolf.howl_now(1, true)
	await frames(80)
	look(wolf.global_position + Vector3(0.0, 0.7, 0.2), Vector3(2.2, 0.3, 1.6), wolf)
	await shot("w17_howl_sitting")
	wolf.hush()
	await frames(60)
	wolf.bowing = true
	await frames(50)
	look(wolf.global_position + Vector3(0.0, 0.45, 0.1), Vector3(2.6, 0.35, 1.4), wolf)
	await shot("w18_play_bow")
	wolf.bowing = false
	await frames(40)
	wolf.lying = true
	await frames(150)
	look(wolf.global_position + Vector3(0.0, 0.3, 0.0), Vector3(2.4, 0.9, 1.6), wolf)
	await shot("w19_lying")
	stage_root.queue_free()
	await frames(4)


func _moving(animal: Node3D, speed: float, seconds: float, name: String) -> void:
	var left := seconds
	while left > 0.0:
		var step := root.get_process_delta_time()
		left -= step
		animal.global_position += animal.global_basis.z.normalized() * speed * step
		if animal.global_position.length() > 30.0:
			animal.global_position = Vector3.ZERO
			(animal as Dog).settle()
		look(animal.global_position + Vector3(0.0, 0.6, 0.0) + animal.global_basis.z * 0.1, Vector3(3.4, 0.3, 0.2), animal)
		await process_frame
	if name != "":
		await shot(name)


# --- Strips of frames from the side ---

## Moves it at `speed` for a while, then takes `count` frames `every` frames
## apart from the side, the camera going with it, and lays them in a row. With
## `prints`, a dark mark is left on the floor where each foot is put down.
func _strip(animal: Wolf, speed: float, count: int, every: int, name: String, prints := false) -> void:
	await _moving(animal, speed, 2.0, "")
	var marks: Array[Node3D] = []
	var down := [false, false, false, false]
	var pictures: Array[Image] = []
	var feet := _feet(animal)
	for k in count:
		for f in every:
			var step := root.get_process_delta_time()
			animal.global_position += animal.global_basis.z.normalized() * speed * step
			look(animal.global_position + Vector3(0.0, 0.5, 0.0), Vector3(4.2, 0.9, 0.0), animal, 32.0)
			await process_frame
			if prints:
				for i in feet.size():
					var at := feet[i].global_position
					var planted := at.y < 0.06
					if planted and not down[i]:
						var mark := MeshInstance3D.new()
						var disc := CylinderMesh.new()
						disc.top_radius = 0.035 if i < 2 else 0.028
						disc.bottom_radius = disc.top_radius
						disc.height = 0.004
						mark.mesh = disc
						var ink := StandardMaterial3D.new()
						ink.albedo_color = Color(0.1, 0.1, 0.1) if i < 2 else Color(0.85, 0.85, 0.85)
						mark.material_override = ink
						stage_root.add_child(mark)
						mark.global_position = Vector3(at.x, 0.003, at.z)
						marks.append(mark)
					down[i] = planted
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var w := image.get_width()
		var h := image.get_height()
		pictures.append(image.get_region(Rect2i(w / 2 - h * 3 / 8, h / 8, h * 3 / 4, h * 3 / 4)))
	var tile := pictures[0].get_width()
	var across := mini(count, 4)
	var rows := ceili(float(count) / across)
	var sheet := Image.create(tile * across, tile * rows, false, pictures[0].get_format())
	for k in pictures.size():
		sheet.blit_rect(pictures[k], Rect2i(Vector2i.ZERO, Vector2i(tile, tile)), Vector2i((k % across) * tile, (k / across) * tile))
	sheet.save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png" % [folder, name])
	if prints:
		# From above: the line of prints (forefeet dark, hind pale)
		camera.fov = 40.0
		camera.global_position = animal.global_position - animal.global_basis.z.normalized() * 1.6 + Vector3.UP * 4.0
		camera.look_at(animal.global_position - animal.global_basis.z.normalized() * 1.6, animal.global_basis.z.normalized())
		await shot(name + "_prints")
	for mark in marks:
		mark.queue_free()


## The wolf's paws (the bones' places, by the skeleton).
func _feet(animal: Wolf) -> Array[Node3D]:
	var made: Array[Node3D] = []
	var skeleton: Skeleton3D = animal.rig.find_children("*", "Skeleton3D", true, false)[0]
	for suffix in DogRig.SUFFIXES:
		var marker := BoneAttachment3D.new()
		marker.bone_name = "paw" + suffix
		skeleton.add_child(marker)
		made.append(marker)
	return made


func _strips() -> void:
	_stage()
	var wolf := _wolf(0, 1)
	await frames(10)
	await _strip(wolf, 2.7, 8, 3, "t01_trot_strip", true)
	await _strip(wolf, 3.4, 8, 3, "t02_hunting_trot_strip", true)
	await _strip(wolf, 7.5, 8, 2, "t03_gallop_strip")
	await _strip(wolf, 1.2, 8, 5, "t04_walk_strip")
	stage_root.queue_free()
	await frames(4)


# --- In the maze ---

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
	var side := Vector3(-way.z, 0.0, way.x)
	var up := Vector3.UP
	var start := nav.point(best)
	var far_end := start + way * minf(best_run * Maze.CELL - 4.0, 30.0)
	var pack: Array[Wolf] = []
	for i in 5:
		var one := Wolf.new()
		one.sound = false
		one.variant = [1, 0, 0, 1, 0][i]
		one.rank = [0, 0, 1, 1, 2][i]
		one.scale = Vector3.ONE * SIZE * [1.04, 0.97, 1.0, 1.0, 0.92][i]
		one.coat_tint = [Color(0.95, 0.95, 0.96), Color.WHITE, Color(1.03, 1.0, 0.96), Color(0.9, 0.9, 0.92), Color(1.05, 1.03, 1.0)][i]
		world.add_child(one)
		pack.append(one)
	# In file down the hall towards him, at the trot
	for i in pack.size():
		pack[i].global_position = far_end - way * (i * 2.6) + side * sin(i * 1.7) * 0.25
		pack[i].rotation.y = atan2(-way.x, -way.z)
	boy.global_position = start
	boy.rotation.y = atan2(way.x, way.z)
	mover = func(step: float) -> void:
		for one in pack:
			one.global_position -= way * 2.7 * step
	for i in 90:
		mover.call(root.get_process_delta_time())
		await process_frame
	var eye := start + up * 1.2 + way * 1.2
	camera.fov = 50.0
	camera.global_position = eye
	camera.look_at(pack[0].global_position + up * 0.6, up)
	await shot("m01_in_file_down_the_hall")
	camera.fov = 24.0
	await shot("m02_in_file_zoom")
	camera.fov = 50.0
	camera.global_position = pack[2].global_position + side * 4.0 + up * 1.4 - way * 1.0
	camera.look_at(pack[2].global_position + up * 0.5, up)
	await shot("m03_in_file_from_the_side")
	mover = Callable()
	# The chorus at the den: a dead end near
	var den := Vector2i(-1, -1)
	for cell in nav.lairs(3):
		if nav.dead_end(cell):
			den = cell
			break
	var den_at := maze.world(den) if den.x >= 0 else far_end
	den_at.y = maze.ground_height(den_at)
	var out := Vector3.FORWARD
	for s: Vector2i in Maze.STEPS:
		if den.x >= 0 and not maze.blocked(den, s):
			out = Vector3(s.x, 0.0, s.y)
	var across := Vector3(-out.z, 0.0, out.x)
	for i in pack.size():
		var one := pack[i]
		one.global_position = den_at + across * [0.0, 1.4, -1.5, 2.6, -2.8][i] + out * [0.0, 0.8, -0.6, -1.4, 0.4][i]
		one.rotation.y = atan2(out.x, out.z) + [0.2, -0.4, 0.6, -0.3, 0.9][i]
		one.settle()
	await frames(20)
	for i in pack.size():
		pack[i].howl_now(i % Wolf.HOWLS, i == 2 or i == 4)
	await frames(90)
	camera.fov = 48.0
	camera.global_position = den_at + out * 9.0 + up * 1.3 + across * 1.0
	camera.look_at(den_at + up * 0.8, up)
	await shot("m04_chorus_at_the_den")
	camera.fov = 26.0
	await shot("m05_chorus_zoom")
	for one in pack:
		one.hush()
	await frames(40)
	# The hunt: coming down the hall at the boy, heads low, spread across it
	for i in pack.size():
		pack[i].hunting = true
		pack[i].look_at_point = boy.global_position + up
		pack[i].global_position = far_end - way * (i * 1.4) + side * [0.0, 1.0, -1.0, 1.8, -1.8][i]
		pack[i].rotation.y = atan2(-way.x, -way.z)
		pack[i].settle()
	mover = func(step: float) -> void:
		for one in pack:
			one.global_position -= way * 3.3 * step
	for i in 70:
		mover.call(root.get_process_delta_time())
		await process_frame
	camera.fov = 50.0
	camera.global_position = eye
	camera.look_at(pack[0].global_position + up * 0.5, up)
	await shot("m06_the_hunt")
	mover = Callable()
	# Closing in on him, low, snarling
	for i in pack.size():
		pack[i].hunting = false
		pack[i].stalking = true
		pack[i].snarling = true
	await frames(40)
	camera.fov = 40.0
	await shot("m07_closing_in")


## The middle of the hall across `side` from `at` (between the walls either side of it).
func _hall_middle(world: Node3D, at: Vector3, side: Vector3) -> Vector3:
	var space := world.get_world_3d().direct_space_state
	var from := at + Vector3.UP * 1.0
	var ends: Array[Vector3] = []
	for way: Vector3 in [side, -side]:
		var query := PhysicsRayQueryParameters3D.create(from, from + way * 30.0)
		var hit := space.intersect_ray(query)
		ends.append(hit["position"] if hit else from + way * 8.0)
	var middle := ends[0].lerp(ends[1], 0.5)
	return Vector3(middle.x, at.y, middle.z)

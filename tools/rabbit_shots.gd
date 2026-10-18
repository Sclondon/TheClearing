extends SceneTree
## Pictures of the rabbits, hares and jackalopes (creatures/rabbit): close up
## on a plain floor under the game's kind of light (each kind from each side,
## the head, every pose and move), frame strips of a hop and a bound from the
## side with time stepped by hand, the warrens, and in a real round (a warren
## in a hall and one in the clearing with its rabbits grazing, watching and
## bolting down their holes; a hare in its form and away; the jackalope).
## Says how many draws a frame takes. Needs a real window (the engine draws
## nothing headless):
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/rabbit_shots.gd -- <folder> [studio|strips|warrens|maze|all]

const STEP := 1.0 / 60.0

var folder := "rabbit_shots"
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
	if mode in ["strips", "all"]:
		await _strips()
	if mode in ["warrens", "all"]:
		await _warrens()
	if mode in ["maze", "all"]:
		await _maze()
	quit()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png  (%d draws)" % [folder, name, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


func frames(count: int) -> void:
	for i in count:
		await process_frame


## Looks at `target` from `offset` away (in the animal's own space, if `who` is given).
func look(target: Vector3, offset: Vector3, who: Node3D = null, fov := 40.0) -> void:
	var from := offset
	if who:
		from = Basis(Vector3.UP, who.rotation.y) * offset
	camera.fov = fov
	camera.global_position = target + from
	camera.look_at(target, Vector3.UP)


func _floor_stage() -> void:
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
	plane.size = Vector2(400.0, 400.0)
	floor.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.5, 0.5, 0.5)
	floor.material_override = ground
	stage_root.add_child(floor)
	camera = Camera3D.new()
	camera.near = 0.02
	stage_root.add_child(camera)
	camera.current = true


func _make(variant: Rabbit.Variant, at := Vector3.ZERO, yaw := 0.0) -> Rabbit:
	var one := Rabbit.new()
	one.variant = variant
	one.sound = false
	one.position = at
	one.rotation.y = yaw
	stage_root.add_child(one)
	return one


## Drives `who` by hand: `seconds` of going straight ahead at `speed`, its rig stepped at 60 a second.
func drive(who: Rabbit, speed: float, seconds: float) -> void:
	who.measure_velocity = false
	who.rig.process_mode = Node.PROCESS_MODE_DISABLED
	var forward := who.global_basis.z.normalized()
	who.velocity = forward * speed
	for i in int(round(seconds / STEP)):
		who.global_position += forward * speed * STEP
		who.rig._process(STEP)


## Steps `who`'s rig by hand, standing.
func hold(who: Rabbit, seconds: float) -> void:
	who.measure_velocity = false
	who.velocity = Vector3.ZERO
	who.rig.process_mode = Node.PROCESS_MODE_DISABLED
	for i in int(round(seconds / STEP)):
		who.rig._process(STEP)


func _studio() -> void:
	_floor_stage()
	var names := ["rabbit", "hare", "jackalope"]
	for v in 3:
		var one := _make(v)
		await frames(10)
		hold(one, 0.5)
		var s := one.rig._size
		var middle := Vector3(0.0, 0.13 * s, 0.0)
		look(middle, Vector3(1.25, 0.18, 0.0) * s, one, 34.0)
		await shot("s%d1_%s_side" % [v, names[v]])
		look(middle, Vector3(0.85, 0.35, 0.95) * s, one, 34.0)
		await shot("s%d2_%s_three_quarter" % [v, names[v]])
		look(middle, Vector3(-0.8, 0.4, -0.9) * s, one, 34.0)
		await shot("s%d3_%s_back_quarter" % [v, names[v]])
		var head := one.nose_position().lerp(one.global_position + Vector3(0.0, 0.17 * s, 0.1 * s), 0.6)
		look(head, Vector3(0.22, 0.05, 0.3) * s, one, 34.0)
		await shot("s%d4_%s_head" % [v, names[v]])
		one.queue_free()
		await frames(2)
	# Every pose, the rabbit and the hare side by side
	var pair: Array[Rabbit] = [_make(Rabbit.Variant.RABBIT, Vector3(-0.35, 0.0, 0.0)), _make(Rabbit.Variant.HARE, Vector3(0.35, 0.0, 0.0))]
	await frames(10)
	var poses := ["graze", "alert", "upright", "washing", "flattened", "thump", "flag", "boxing", "lowered"]
	for k in poses.size():
		var pose: String = poses[k]
		for one in pair:
			one.grazing = pose == "graze"
			one.alert = pose in ["alert", "upright"]
			one.upright = pose == "upright"
			one.washing = pose == "washing"
			one.flattened = pose == "flattened"
			one.flagging = pose == "flag"
			one.boxing = pose == "boxing"
			one.lowered = pose == "lowered"
			one.look_at_point = camera.global_position if pose in ["alert", "upright"] else Vector3.INF
			if pose == "thump":
				one.thump()
			hold(one, 0.12 if pose == "thump" else (0.9 if pose != "washing" else 0.75))
		var from := Vector3(1.1, 0.25, 1.3) if pose != "flag" else Vector3(-1.0, 0.35, -1.4)
		look(Vector3(0.0, 0.14, 0.0), from, null, 36.0)
		await shot("p%02d_%s" % [k, pose])
	for one in pair:
		one.queue_free()
	stage_root.queue_free()
	await frames(4)


## Frame strips, from the side: a hop and a bound for the rabbit, a bound for the hare, time stepped by hand.
func _strips() -> void:
	_floor_stage()
	var rabbit := _make(Rabbit.Variant.RABBIT, Vector3.ZERO, PI * 0.5)
	await frames(10)
	await _strip(rabbit, 0.6, "t01_rabbit_hop_strip")
	rabbit.flagging = true
	rabbit.fleeing = true
	await _strip(rabbit, 7.0, "t02_rabbit_bound_strip")
	rabbit.queue_free()
	var hare := _make(Rabbit.Variant.HARE, Vector3.ZERO, PI * 0.5)
	await frames(10)
	hare.fleeing = true
	await _strip(hare, 13.0, "t03_hare_bound_strip")
	hare.queue_free()
	stage_root.queue_free()
	await frames(4)


## Eight pictures through one stride, side on, put together in a grid of 4 by 2.
func _strip(who: Rabbit, speed: float, name: String) -> void:
	who.global_position = Vector3.ZERO
	who.settle()
	await frames(2)
	drive(who, speed, 2.0)
	var size := who.rig._size
	var stride: float = RabbitRig._keyed(RabbitRig.STRIDE, speed / size) * size
	var seconds := stride / speed
	var sheet := Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	for k in 8:
		drive(who, speed, seconds / 8.0)
		look(who.global_position + Vector3(0.0, 0.12 * size, 0.0), Vector3(0.0, 0.05 * size, 1.15 * size), null, 34.0)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.resize(640, 360, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(image, Rect2i(160, 0, 320, 360), Vector2i((k % 4) * 320, (k / 4) * 360))
	sheet.save_png("%s/%s.png" % [folder, name])
	print("saved %s/%s.png" % [folder, name])
	who.rig.process_mode = Node.PROCESS_MODE_INHERIT
	who.measure_velocity = true


func _warrens() -> void:
	_floor_stage()
	var mound := RabbitWarren.new()
	stage_root.add_child(mound)
	var bank := RabbitWarren.new()
	bank.kind = RabbitWarren.Kind.BANK
	bank.position = Vector3(8.0, 0.0, 0.0)
	stage_root.add_child(bank)
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6.0, 4.0, 0.5)
	wall.mesh = box
	wall.position = Vector3(8.0, 2.0, -0.25)
	stage_root.add_child(wall)
	await frames(6)
	# A rabbit sat at a mouth, one going in, one grazing on the top
	var sat := _make(Rabbit.Variant.RABBIT)
	var hole := mound.mouth(0)
	sat.global_position = hole - mound.way_in(0) * 0.35
	sat.rotation.y = atan2(-mound.way_in(0).x, -mound.way_in(0).z)
	sat.upright = true
	var going := _make(Rabbit.Variant.RABBIT)
	going.global_position = mound.mouth(1) - mound.way_in(1) * 0.05
	going.rotation.y = atan2(mound.way_in(1).x, mound.way_in(1).z)
	going.flagging = true
	var top := _make(Rabbit.Variant.RABBIT, Vector3(0.3, 0.46, 0.2), 1.0)
	top.grazing = true
	await frames(60)
	look(Vector3(0.0, 0.25, 0.0), Vector3(2.2, 1.6, 5.4), null, 40.0)
	await shot("w01_mound")
	look(hole, -mound.way_in(0) * 1.4 + Vector3(0.3, 0.45, 0.0), null, 40.0)
	await shot("w02_mound_hole")
	look(bank.global_position + Vector3(0.0, 0.3, 0.6), Vector3(1.5, 1.2, 4.2), null, 40.0)
	await shot("w03_bank")
	look(bank.mouth(1), Vector3(0.4, 0.35, 1.2), null, 40.0)
	await shot("w04_bank_hole")
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
	var enemies: MazeEnemies = world.get(&"enemies")
	for one in enemies.enemies:
		one.process_mode = Node.PROCESS_MODE_DISABLED
		one.visible = false
	for node: Node in world.get_children():
		if node is Griever:
			node.process_mode = Node.PROCESS_MODE_DISABLED
			(node as Node3D).visible = false
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.near = 0.03
	camera.far = 600.0
	var up := Vector3.UP
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	# A colony in the clearing's meadow, grazing round its warren
	var spot: Array = MazeRabbit.clearing_spots(maze, 1, rng)[0]
	var at: Vector3 = spot[0]
	var warren := MazeRabbit.add_colony(enemies, at, spot[1], RabbitWarren.Kind.MOUND, 5, 7, true)
	var toward := Vector3(-at.x, 0.0, -at.z).normalized()
	var stand := at + toward * 30.0
	stand.y = maze.ground_height(stand)
	boy.global_position = stand + up * 0.2
	await frames(300)
	var eye := boy.global_position + up * 1.1
	look(at + up * 0.3, eye - at - up * 0.3, null, 26.0)
	await shot("m01_clearing_warren_from_the_boy")
	look(at + up * 0.25, toward * 6.5 + up * 0.9 + toward.cross(up) * 2.0, null, 40.0)
	await shot("m02_clearing_warren_grazing")
	stand = at + toward * 11.0
	stand.y = maze.ground_height(stand)
	boy.global_position = stand + up * 0.2
	await frames(90)
	look(at + up * 0.3, toward * 5.0 + up * 0.7 - toward.cross(up) * 2.5, null, 40.0)
	await shot("m03_sat_up_watching_him")
	stand = at + toward * 4.5
	stand.y = maze.ground_height(stand)
	boy.global_position = stand + up * 0.2
	await frames(16)
	look(at + up * 0.25, toward * 7.0 + up * 1.4 + toward.cross(up) * 3.0, null, 44.0)
	await shot("m04_thump_and_bolt")
	await frames(14)
	await shot("m05_bolting_for_the_holes")
	await frames(70)
	await shot("m06_gone_down")
	for child in enemies.get_children():
		if child is MazeRabbit or child is RabbitWarren:
			if child is MazeEnemy:
				enemies.enemies.erase(child)
			child.queue_free()
	await frames(2)
	# A bank in a hall
	var nav := MazeNav.new(maze)
	var hall := Vector2i.ZERO
	for cell: Vector2i in nav.lairs(4):
		if not nav.dead_end(cell) and maze.ring_of(cell) == 1:
			hall = cell
			break
	var bank_at: Array = MazeRabbit.bank_in_hall(maze, hall, rng)
	var bank := MazeRabbit.add_colony(enemies, bank_at[0], bank_at[1], RabbitWarren.Kind.BANK, 4, 9)
	var out := Vector3(sin(bank_at[1]), 0.0, cos(bank_at[1]))
	boy.global_position = bank.global_position + out * 18.0 + up * 0.2
	await frames(240)
	eye = boy.global_position + up * 1.1
	look(bank.global_position + up * 0.4, eye - bank.global_position - up * 0.4, null, 30.0)
	await shot("m07_hall_bank_from_the_boy")
	look(bank.global_position + up * 0.3 + out * 1.0, out * 5.0 + up * 1.2 + out.cross(up) * 2.0, null, 42.0)
	await shot("m08_hall_bank_close")
	for child in enemies.get_children():
		if child is MazeRabbit or child is RabbitWarren:
			if child is MazeEnemy:
				enemies.enemies.erase(child)
			child.queue_free()
	await frames(2)
	# A hare in the meadow: in its form, frozen flat, and away
	var meadow := at + toward.cross(up) * 40.0
	meadow.y = maze.ground_height(meadow)
	var hare: MazeHare = MazeHare.add_hares(enemies, meadow, false, 5, true)[0]
	stand = meadow + toward * 40.0
	stand.y = maze.ground_height(stand)
	boy.global_position = stand + up * 0.2
	await frames(120)
	look(meadow + up * 0.3, toward * 5.0 + up * 1.0 + toward.cross(up) * 2.0, null, 40.0)
	await shot("m09_hare_in_its_form")
	stand = meadow + toward * 15.0
	stand.y = maze.ground_height(stand)
	boy.global_position = stand + up * 0.2
	await frames(90)
	eye = boy.global_position + up * 1.1
	look(hare.global_position + up * 0.2, (eye - hare.global_position).normalized() * 6.0 + up * 0.3, null, 40.0)
	await shot("m10_hare_frozen_flat")
	stand = hare.global_position + toward * 3.5
	stand.y = maze.ground_height(stand)
	boy.global_position = stand + up * 0.2
	await frames(40)
	look(hare.global_position + up * 0.3, toward.cross(up) * 9.0 + up * 1.5 + toward * 3.0, null, 44.0)
	await shot("m11_hare_away")
	await frames(30)
	look(hare.global_position + up * 0.3, toward.cross(up) * 12.0 + up * 2.0 + toward * 6.0, null, 44.0)
	await shot("m12_hare_jinking")
	for child in enemies.get_children():
		if child is MazeHare:
			if child is MazeEnemy:
				enemies.enemies.erase(child)
			child.queue_free()
	await frames(2)
	# A pair boxing
	var pair: Array[MazeHare] = MazeHare.add_hares(enemies, meadow, true, 8, true)
	boy.global_position = meadow + toward * 40.0 + up * 0.2
	await frames(30)
	pair[0]._box_in = 0.0
	await frames(150)
	var mid: Vector3 = (pair[0].global_position + pair[1].global_position) * 0.5
	var across: Vector3 = (pair[1].global_position - pair[0].global_position).normalized().cross(up)
	look(mid + up * 0.35, across * 3.0 + up * 0.4, null, 40.0)
	await shot("m13_march_hares_boxing")
	for child in enemies.get_children():
		if child is MazeHare:
			if child is MazeEnemy:
				enemies.enemies.erase(child)
			child.queue_free()
	await frames(2)
	# The jackalope, staring
	var jack := MazeJackalope.new()
	jack.keep_out_of_clearing = false
	var jcell := maze.cell_at(meadow)
	enemies.add(jack, jcell, 0.0, 5, meadow - maze.world(jcell) + up * 0.2)
	stand = meadow + toward * 9.0
	stand.y = maze.ground_height(stand)
	boy.global_position = stand + up * 0.2
	await frames(150)
	eye = boy.global_position + up * 1.15
	look(jack.global_position + up * 0.35, (eye - jack.global_position).normalized() * 3.5 + up * 0.1, null, 38.0)
	await shot("m14_jackalope_staring")
	look(jack.global_position + up * 0.3, (eye - jack.global_position).normalized().cross(up) * 3.0 + up * 0.4, null, 40.0)
	await shot("m15_jackalope_side")
	stand = jack.global_position + toward * 2.4
	stand.y = maze.ground_height(stand)
	boy.global_position = stand + up * 0.2
	await frames(28)
	look(jack.global_position + up * 0.3, toward.cross(up) * 3.5 + up * 0.8, null, 44.0)
	await shot("m16_jackalope_lowers_its_antlers")
	await frames(30)
	look(boy.global_position + up * 0.5, toward.cross(up) * 5.0 + up * 1.2, null, 46.0)
	await shot("m17_butted_down")
	world.queue_free()
	await frames(4)

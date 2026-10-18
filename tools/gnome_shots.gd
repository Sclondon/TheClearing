extends SceneTree
## Pictures of the gnomes (creatures/gnome/, scripts/enemies/maze_gnome.gd):
## first in a plain grey studio (front, side, three-quarters, the face close,
## its still poses, and each thing it does: walking, creeping, scurrying, the
## snatch, carrying, hauling a rope, the giggle, the squeal); then in a passage
## of a real round (World: the game's light and mist): a band at its hollow,
## frozen when looked at, closer when looked back at, one behind him with its
## hands up, one running home with what it took, two with a rope across the
## hall. Needs a real window:
##
##     godot --path . --resolution 1280x720 -s res://tools/gnome_shots.gd -- <folder> [studio|maze]
##
## (landscape: every picture is framed for 1280x720)

var folder := "gnome_shots"
var only := ""
var camera: Camera3D
var stage: Node3D


## Moves a gnome along at `speed` (m/s) the way it faces, every frame.
class Driver:
	extends Node
	var body: Node3D
	var speed := 0.0

	func _process(delta: float) -> void:
		body.global_position += body.global_basis.z * speed * delta


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
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.61, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.6)
	env.ambient_light_energy = 0.85
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	stage.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.0, 0.7, 0.0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	floor.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.49)
	floor.material_override = mat
	stage.add_child(floor)
	camera = Camera3D.new()
	camera.fov = 35.0
	stage.add_child(camera)
	camera.make_current()

	var gnome := Gnome.new()
	gnome.voice = false
	gnome.seed_value = 3
	stage.add_child(gnome)
	await wait(0.5)
	var mid := gnome.global_position + Vector3.UP * 0.3
	_look_from(mid + Vector3(0.0, 0.05, 2.0), mid)
	await shot("01_front")
	_look_from(mid + Vector3(2.1, 0.05, 0.0), mid)
	await shot("02_side")
	_look_from(mid + Vector3(1.4, 0.4, 1.4), mid)
	await shot("03_three_quarter")
	_look_from(mid + Vector3(-1.2, 0.5, -1.6), mid)
	await shot("04_back")
	gnome.look_at_point = Vector3(0.3, 0.5, 2.0)
	await wait(0.6)
	var face := gnome.head_position()
	_look_from(face + Vector3(0.0, 0.02, 0.7), face)
	await shot("05_face_front")
	_look_from(face + Vector3(0.5, 0.05, 0.5), face)
	await shot("06_face_three_quarter")
	_look_from(face + Vector3(0.15, -0.25, 0.6), face)
	await shot("07_face_below")
	gnome.look_at_point = Vector3.INF
	# Its still poses, side by side: clasped, hush, peering, pointing.
	var row: Array[Gnome] = []
	for k in 4:
		var one := Gnome.new()
		one.voice = false
		one.seed_value = 20 + k
		one.still = k as Gnome.Still
		one.position = Vector3((k - 1.5) * 0.55, 0.0, -1.0)
		stage.add_child(one)
		row.append(one)
	gnome.visible = false
	await wait(1.2)
	_look_from(Vector3(0.0, 0.55, 1.6), Vector3(0.0, 0.3, -1.0))
	await shot("08_still_poses")
	for one in row:
		one.queue_free()
	gnome.visible = true

	# Going: walking, creeping on tiptoe, scurrying.
	var drive := Driver.new()
	drive.body = gnome
	stage.add_child(drive)
	drive.speed = 0.5
	await wait(1.0)
	for k in 2:
		_side_of(gnome, 2.0)
		await shot("10_walk_%d" % k)
		await wait(0.2)
	gnome.creeping = true
	drive.speed = 0.9
	await wait(1.0)
	for k in 2:
		_side_of(gnome, 2.0)
		await shot("11_creep_%d" % k)
		await wait(0.17)
	_three_quarter(gnome, 2.0)
	await shot("12_creep_coming")
	gnome.creeping = false
	drive.speed = 4.6
	await wait(0.8)
	for k in 3:
		_side_of(gnome, 2.2)
		await shot("13_scurry_%d" % k)
		await wait(0.03)
	drive.speed = 0.0
	await wait(0.8)
	gnome.snatch()
	await wait(Gnome.SNATCH_TIME * 0.5)
	_side_of(gnome, 2.0)
	await shot("14_snatch")
	await wait(0.4)
	gnome.carrying = true
	drive.speed = 4.2
	await wait(0.7)
	_three_quarter(gnome, 2.3)
	await shot("15_carrying_run")
	drive.speed = 0.0
	gnome.carrying = false
	gnome.hauling = true
	await wait(0.7)
	_side_of(gnome, 2.0)
	await shot("16_hauling")
	gnome.hauling = false
	await wait(0.5)
	gnome.giggle()
	await wait(0.35)
	_three_quarter(gnome, 1.6)
	await shot("17_giggle")
	await wait(0.8)
	gnome.squeal()
	await wait(0.3)
	_three_quarter(gnome, 1.8)
	await shot("18_squeal")
	await wait(0.6)
	gnome.tumbling = true
	gnome.rotation.x = -1.2
	await wait(0.4)
	_side_of(gnome, 2.0)
	await shot("19_tumbling")
	stage.queue_free()
	await process_frame


func _look_from(from: Vector3, at: Vector3) -> void:
	camera.position = from
	camera.look_at(at)


func _side_of(body: Node3D, far: float) -> void:
	var at := body.global_position + Vector3.UP * 0.3
	_look_from(at + body.global_basis.x * far + Vector3.UP * 0.1, at)


func _three_quarter(body: Node3D, far: float) -> void:
	var at := body.global_position + Vector3.UP * 0.3
	_look_from(at + (body.global_basis.z + body.global_basis.x * 0.8).normalized() * far + Vector3.UP * 0.35, at)


# --- In the maze ---

var world
var maze
var nav
var boy
var want_yaw := INF


## Holds him to the way he is made to face (he would turn back to the way he was going).
class Facing:
	extends Node
	var boy: Node3D
	var yaw := INF

	func _physics_process(_delta: float) -> void:
		if boy and yaw != INF:
			boy.set(&"facing_yaw", yaw)


func _maze() -> void:
	world = load("res://scripts/world.gd").new()
	world.name = "World"
	root.add_child(world)
	world.setup(Maze.seed_for("SHOT", 1), 0, [{"slot": 0, "look": "p11"}], false)
	maze = world.maze
	nav = MazeNav.new(maze)
	boy = world.player
	boy.takes_input = false
	# (only these gnomes: the round's own hunters are put away)
	for one in world.enemies.enemies:
		one.queue_free()
	world.enemies.enemies.clear()
	world.griever.queue_free()
	if world.runners:
		for one in world.runners.get_children():
			one.queue_free()
	var facing := Facing.new()
	facing.boy = boy
	facing.process_physics_priority = 100
	world.add_child(facing)
	await wait(0.5)
	var home := Vector2i(-1, -1)
	var out := Vector2i.ZERO
	for cell: Vector2i in nav.lairs(3):
		if not nav.dead_end(cell):
			continue
		for s: Vector2i in Maze.STEPS:
			if not maze.blocked(cell, s) and not maze.blocked(cell + s, s):
				home = cell
				out = s
		if home.x >= 0:
			break
	var back := -Vector3(out.x, 0.0, out.y)
	var band := MazeGnome.band_of(5)
	for k in band.size():
		world.enemies.add(band[k], home, 0.0, 300 + k * 7, back * 3.0 + Vector3(back.z, 0.0, back.x) * (k - 2.0) * 0.7)
	await wait(1.0)
	var hollow: GnomeHollow = band[0].band.hollow
	var mouth: Vector3 = hollow.mouth()
	var hall: Vector3 = hollow.global_basis.z
	var side := Vector3(hall.z, 0.0, -hall.x)
	var loot = world.loot
	for kind in [LootItem.Kind.FLARE, LootItem.Kind.MAP]:
		var item: Node3D = loot._place(kind, boy.global_position + Vector3.UP * 3.0, 0.0, 800000 + loot._next)
		loot._next += 1
		loot.grant(item.get(&"loot_id"), world.slot)
	# He comes down the hall towards their door, looking at them: statues.
	_stand(mouth + hall * 8.0, -hall, facing)
	await wait(0.6)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.fov = 50.0
	world.camera.make_current()
	await shot("30_band_at_home_game_camera")
	cam.make_current()
	cam.position = mouth + hall * 1.8 + Vector3.UP * 0.7
	cam.look_at(mouth + Vector3.UP * 0.3)
	print("hollow at %s visible %s in tree %s; cam %s" % [hollow.global_position, hollow.is_visible_in_tree(), hollow.is_inside_tree(), cam.global_position])
	await shot("31_hollow_close")
	cam.position = band[1].global_position + hall * 1.3 + side * 0.4 + Vector3.UP * 0.55
	cam.look_at(band[1].global_position + Vector3.UP * 0.4)
	await shot("32_statue_close")
	# He turns his back: they creep after him.
	for one: MazeGnome in band:
		one.notice(boy)
	_stand(mouth + hall * 8.0, hall, facing)
	await wait(1.3)
	world.camera.make_current()
	world.camera._yaw = atan2(-hall.x, -hall.z) + 0.3
	world.camera.snap()
	await shot("33_creeping_behind_him_game_camera")
	cam.make_current()
	cam.position = boy.global_position - hall * 1.0 + side * 2.4 + Vector3.UP * 0.9
	cam.look_at(boy.global_position - hall * 1.2 + Vector3.UP * 0.3)
	await shot("34_creeping_side")
	# One right behind him, its hands up for his pockets.
	await wait(4.0, func() -> bool: return band.any(func(one: MazeGnome) -> bool: return one.mode == MazeGnome.Mode.SNATCH))
	await wait(0.15)
	cam.position = boy.global_position - hall * 1.6 + side * 1.4 + Vector3.UP * 0.8
	cam.look_at(boy.global_position - hall * 0.4 + Vector3.UP * 0.5)
	await shot("35_snatch")
	await wait(1.5, func() -> bool: return band.any(func(one: MazeGnome) -> bool: return one.carrying >= 0))
	var thief: MazeGnome = null
	for one: MazeGnome in band:
		if one.carrying >= 0:
			thief = one
	if thief:
		await wait(0.5)
		cam.position = thief.global_position + (mouth - thief.global_position).normalized() * 2.2 + side * 0.8 + Vector3.UP * 0.6
		cam.look_at(thief.global_position + Vector3.UP * 0.35)
		await shot("36_running_home_with_it")
		world.camera.make_current()
		_stand(boy.global_position, -hall, facing)
		await wait(0.2)
		await shot("37_running_home_game_camera")
	# Later, the rope: two pull it taut across the hall as he comes running.
	await wait(4.0)
	for one: MazeGnome in band:
		if one.mode != MazeGnome.Mode.HIDE:
			one.mode = MazeGnome.Mode.HOME
			one.quarry = null
	var ends: Array = band[0]._wall_to_wall(mouth + hall * 5.0, side)
	var pair: Array = band.filter(func(one: MazeGnome) -> bool: return one.mode == MazeGnome.Mode.HOME).slice(0, 2)
	for k in 2:
		pair[k].mode = MazeGnome.Mode.ROPE_RUN
		pair[k]._mode_time = 0.0
		pair[k]._rope_end = ends[k]
		pair[k].rope_time = 30.0
	_stand(mouth + hall * 11.0, -hall, facing)
	await wait(5.0, func() -> bool: return pair[0].mode == MazeGnome.Mode.ROPE and pair[1].mode == MazeGnome.Mode.ROPE)
	await wait(0.5)
	world.camera.make_current()
	await shot("38_rope_game_camera")
	cam.make_current()
	cam.position = mouth + hall * 8.5 + side * 1.0 + Vector3.UP * 0.7
	cam.look_at(mouth + hall * 5.0 + Vector3.UP * 0.2)
	await shot("39_rope_across_the_hall")
	cam.position = pair[0].global_position + hall * 1.2 + side * 0.4 + Vector3.UP * 0.5
	cam.look_at(pair[0].global_position + Vector3.UP * 0.3)
	await shot("40_hauling_close")
	# He trips on it.
	boy.global_position = mouth + hall * 5.3 + Vector3.UP * 0.05
	await wait(0.1)
	boy.velocity = -hall * 4.6
	for one: MazeGnome in pair:
		one._trip_local()
	await wait(0.35)
	cam.position = boy.global_position + side * 2.6 + Vector3.UP * 1.0
	cam.look_at(boy.global_position + Vector3.UP * 0.3)
	await shot("41_tripped")
	quit()


func _stand(at: Vector3, way: Vector3, facing: Facing) -> void:
	boy.global_position = Vector3(at.x, maze.ground_height(at) + 0.1, at.z)
	boy.velocity = Vector3.ZERO
	facing.yaw = atan2(way.x, way.z)
	boy.facing_yaw = facing.yaw
	world.camera._yaw = atan2(-way.x, -way.z)
	world.camera.snap()

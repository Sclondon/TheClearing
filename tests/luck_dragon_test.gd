extends SceneTree
## The luck dragon (scripts/enemies/maze_luck_dragon.gd, creatures/luck_dragon/),
## headless, in a bare scene: a maze from MazeBuilder, a stand-in player that the
## test moves by hand (a CharacterBody3D with no shape), and for the ride the
## real boy (player.tscn). In turn: it starts high and soars round the maze over
## the walls, never over the clearing; a hall is not open, a place with room
## round it is; someone standing still in the open is visited: it spirals down,
## circles them low and brings its head down in front of them, and sings; it
## never goes through stone, head or body; while it is down, a hunter near
## lets them alone and backs away; someone who walks off is let go; someone who
## walks up to its neck climbs on, is carried over the walls and set down
## further out, and it goes back to the sky; the boy himself is sat on its neck,
## carried, and set down on his feet, his own again; a puppet follows the host's
## news; MazeEnemies' packing carries it; it is one draw (and its shadow).
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/luck_dragon_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze
var nav
var walker: CharacterBody3D
var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func until(seconds: float, done: Callable) -> bool:
	for i in int(seconds * 60.0):
		await physics_frame
		if done.call():
			return true
	return false


func _initialize() -> void:
	stage = Node3D.new()
	stage.name = "Stage"
	root.add_child(stage)
	maze = Maze.generate(Maze.seed_for("TEST", 1))
	var builder := MazeBuilder.new()
	builder.name = "Maze"
	stage.add_child(builder)
	builder.build(maze)
	nav = MazeNav.new(maze)
	var body := GDScript.new()
	body.source_code = "extends CharacterBody3D\nvar is_ducking := false\n"
	body.reload()
	walker = CharacterBody3D.new()
	walker.set_script(body)
	walker.name = "Walker"
	walker.collision_layer = 0
	walker.collision_mask = 0
	stage.add_child(walker)
	walker.add_to_group(&"maze_players")
	_run.call_deferred()


func put(at: Vector3) -> void:
	walker.global_position = at
	walker.velocity = Vector3.ZERO


## Whether a point is inside stone.
func in_stone(at: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = at
	query.collision_mask = 1
	return not stage.get_world_3d().direct_space_state.intersect_point(query, 1).is_empty()


## A place in the open: on a wall top, or out in the clearing's meadow.
func open_spot(dragon: MazeLuckDragon) -> Vector3:
	var space := stage.get_world_3d().direct_space_state
	# (out across the clearing, between the middle and the walls, on the ground)
	for k in 48:
		var a := TAU * k / 48.0
		for r: float in [240.0, 200.0, 160.0, 120.0]:
			var at := Vector3(cos(a) * r, 0.0, sin(a) * r)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 150.0, at + Vector3.DOWN * 20.0, 1))
			if hit.is_empty():
				continue
			at = hit["position"]
			if dragon.open_at(at):
				return at
	return Vector3.INF


func _run() -> void:
	await frames(10)
	put(Vector3(0, 0.05, 0))
	var dragon := MazeLuckDragon.new()
	dragon.name = "Dragon"
	dragon.maze = maze
	dragon.seed_choices(5)
	dragon.targets = [walker]
	var start: Vector3 = maze.world(nav.lairs(4)[0])
	dragon.position = start + Vector3.UP * 0.05
	stage.add_child(dragon)
	await frames(3)
	var top: float = maze.maze_wall_height(1)
	check("it starts high over the walls", dragon.global_position.y > top + 20.0, "(%.0f m up)" % dragon.global_position.y)
	# It soars: it goes round, high, never over the clearing.
	var lowest := INF
	var over_clearing := 0
	var moved := 0.0
	var was: Vector3 = dragon.global_position
	var through := [0]
	for i in 60 * 20:
		await physics_frame
		moved += dragon.global_position.distance_to(was)
		was = dragon.global_position
		lowest = minf(lowest, dragon.global_position.y - dragon._sky_over(dragon.global_position))
		if maze.in_clearing(maze.cell_at(dragon.global_position)):
			over_clearing += 1
		if i % 10 == 0:
			for d: float in [0.0, 8.0, 17.0, 26.0, 34.0]:
				if in_stone(dragon.look.body_point(d)):
					through[0] += 1
	check("it soars on round the maze", moved > 200.0 and dragon.mode == MazeLuckDragon.Mode.SOAR, "(%.0f m in 20 s)" % moved)
	check("soaring, it keeps high over everything under it", lowest > 15.0, "(at least %.1f m over it)" % lowest)
	check("it keeps out of the sky over the clearing", over_clearing == 0, "(%d frames over it)" % over_clearing)

	# Open, or not.
	var hall: Vector3 = maze.world(nav.lairs(3)[nav.lairs(3).size() / 3])
	check("down in a hall is not out in the open", not dragon.open_at(hall))
	var spot := open_spot(dragon)
	check("out in the meadow, away from the trees, is", spot.is_finite(), "(%s)" % spot)
	if not spot.is_finite():
		print("FAILED (%d)" % failures)
		quit(1)
		return

	# Visited: someone standing still in the open, near it.
	dragon.global_position = spot + Vector3(60.0, 70.0, 0.0)
	dragon.look.settle()
	dragon._visit_rest = 0.0
	put(spot)
	var came := await until(still_time_for(dragon) + 4.0, func() -> bool: return dragon.mode == MazeLuckDragon.Mode.DESCEND)
	check("standing still in the open, it comes down to them", came)
	# (a hunter near, after them, to see that it calms it)
	var hunter := MazeGhoul.new()
	hunter.maze = maze
	hunter.targets = [walker]
	stage.add_child(hunter)
	hunter.global_position = spot + Vector3(14.0, 0.0, 8.0)
	hunter.quarry = walker
	var circled := await until(40.0, func() -> bool: return dragon.mode == MazeLuckDragon.Mode.CIRCLE)
	var low: float = dragon.global_position.y - spot.y
	check("it spirals down and circles them low", circled and low < MazeLuckDragon.CIRCLE_HEIGHT + 1.0 and Vector2(dragon.global_position.x - spot.x, dragon.global_position.z - spot.z).length() < MazeLuckDragon.CIRCLE_RADIUS + 3.0, "(%.1f m over their feet)" % low)
	check("while it is down, a hunter near lets them alone and backs away from it", not hunter.huntable(walker) and hunter.quarry == null and hunter.threat == dragon)
	hunter.queue_free()
	var greeted := await until(30.0, func() -> bool: return dragon.mode == MazeLuckDragon.Mode.GREET and dragon._path_at < 0.0)
	var head: Vector3 = dragon.global_position
	var apart := Vector2(head.x - spot.x, head.z - spot.z).length()
	check("its head comes down in front of them at their height", greeted and apart < MazeLuckDragon.GREET_NEAR + 1.0 and absf(head.y - spot.y - MazeLuckDragon.GREET_HEIGHT) < 1.0, "(%.1f m off, %.1f m up)" % [apart, head.y - spot.y])
	await frames(20)
	check("and sings", dragon.look.singing())
	var neck: Vector3 = dragon.look.back_point(MazeLuckDragon.SADDLE, 0.0).origin
	check("its neck is laid low before them, to climb on", neck.y - spot.y < 2.5, "(%.1f m up)" % (neck.y - spot.y))
	check("it has found somewhere further out to set them down", dragon.drop_at.is_finite(), "(%s)" % dragon.drop_at)
	check("it went through no stone getting there", through[0] == 0, "(%d points)" % through[0])

	# Walking off, they are let go.
	put(spot + Vector3(20.0, 0.0, 0.0))
	var went := await until(3.0, func() -> bool: return dragon.mode == MazeLuckDragon.Mode.LEAVE)
	check("someone who walks off is let go, and it rises", went)
	var back := await until(20.0, func() -> bool: return dragon.mode == MazeLuckDragon.Mode.SOAR)
	check("and it goes back up to the sky", back and dragon.global_position.y > spot.y + 30.0)
	var again := await until(still_time_for(dragon) + 3.0, func() -> bool: return dragon.mode != MazeLuckDragon.Mode.SOAR)
	check("it does not come straight down again", not again)

	# A second visit, and the ride.
	dragon._visit_rest = 0.0
	dragon.global_position = spot + Vector3(-50.0, 60.0, 30.0)
	dragon.look.settle()
	put(spot)
	await until(60.0, func() -> bool: return dragon.mode == MazeLuckDragon.Mode.GREET and dragon._path_at < 0.0)
	if not dragon.drop_at.is_finite():
		check("a second visit, with somewhere to go", false)
	var from_out: float = maxf(absf(spot.x), absf(spot.z))
	var seat: Vector3 = dragon.look.back_point(MazeLuckDragon.SADDLE, 0.0).origin
	put(Vector3(seat.x, spot.y, seat.z) + Vector3(0.8, 0.0, 0.0))
	var on := await until(2.0, func() -> bool: return dragon.mode == MazeLuckDragon.Mode.MOUNT)
	check("walking up to its neck, they climb on", on and dragon.rider == walker)
	var path_through := [0]
	var highest := [-INF]
	var rode := await until(80.0, func() -> bool:
		# (the stand-in is carried by hand: sat where one sits)
		put(dragon.look.back_point(MazeLuckDragon.SADDLE, MazeLuckDragon.SADDLE_UP).origin)
		highest[0] = maxf(highest[0], walker.global_position.y)
		if in_stone(walker.global_position + Vector3.UP * 0.5) or in_stone(dragon.global_position):
			path_through[0] += 1
		for d: float in [10.0, 20.0, 30.0]:
			if in_stone(dragon.look.body_point(d)):
				path_through[0] += 1
		return dragon.mode == MazeLuckDragon.Mode.ALIGHT)
	check("it carries them up over the walls", rode and highest[0] > maze.maze_wall_height(1) + 5.0, "(%.0f m at the highest)" % highest[0])
	check("and down a hall, through no stone, rider and all", path_through[0] == 0, "(%d points)" % path_through[0])
	var drop: Vector3 = dragon.drop_at
	var out_now: float = maxf(absf(drop.x), absf(drop.z))
	check("it sets them down further out", out_now > from_out + 20.0 and walker.global_position.distance_to(drop) < MazeLuckDragon.SADDLE + 3.5, "(%.0f m further out, %.1f m from where it meant)" % [out_now - from_out, walker.global_position.distance_to(drop)])
	put(drop)
	var home := await until(25.0, func() -> bool: return dragon.mode == MazeLuckDragon.Mode.SOAR)
	check("then it goes back to the sky", home and dragon.rider == null)

	# The boy himself: sat on its neck, carried, set down on his feet.
	var boy: Player = load("res://player.tscn").instantiate()
	boy.name = "Boy"
	boy.takes_input = false
	stage.add_child(boy)
	boy.global_position = spot + Vector3.UP * 0.1
	walker.remove_from_group(&"maze_players")
	dragon.targets = [boy]
	dragon._visit_rest = 0.0
	dragon.global_position = spot + Vector3(40.0, 60.0, -40.0)
	dragon.look.settle()
	await until(70.0, func() -> bool: return dragon.mode == MazeLuckDragon.Mode.GREET and dragon._path_at < 0.0)
	seat = dragon.look.back_point(MazeLuckDragon.SADDLE, 0.0).origin
	boy.global_position = Vector3(seat.x, spot.y + 0.1, seat.z) + Vector3(0.6, 0.0, 0.0)
	var mounted := await until(3.0, func() -> bool: return dragon.mode == MazeLuckDragon.Mode.MOUNT)
	await until(3.0, func() -> bool: return dragon.mode == MazeLuckDragon.Mode.RIDE)
	await frames(90)
	var on_neck: float = boy.global_position.distance_to(dragon.look.back_point(MazeLuckDragon.SADDLE, MazeLuckDragon.SADDLE_UP).origin)
	check("the boy sits on its neck and is carried", mounted and boy.process_mode == Node.PROCESS_MODE_DISABLED and on_neck < 0.5, "(%.2f m from its neck, sat %.2f)" % [on_neck, boy.sit_progress])
	await until(80.0, func() -> bool: return dragon.mode == MazeLuckDragon.Mode.ALIGHT)
	await frames(10)
	var landed: float = boy.global_position.distance_to(dragon.drop_at)
	check("and is set down on the ground, his own again", boy.process_mode == Node.PROCESS_MODE_INHERIT and landed < 0.5, "(%.2f m from where it meant)" % landed)
	await frames(60)
	check("standing on it", boy.is_on_floor() and absf(boy.global_position.y - dragon.drop_at.y) < 0.4)

	# A puppet follows the host's news.
	var copy := MazeLuckDragon.new()
	copy.name = "DragonCopy"
	copy.maze = maze
	copy.puppet = true
	copy.position = dragon.global_position
	stage.add_child(copy)
	await frames(3)
	var behind := 0.0
	var agreed := 0
	for i in 60 * 8:
		if i % 6 == 0:
			copy.from_bytes(dragon.state_bytes())
		await physics_frame
		if i > 30:
			behind = maxf(behind, copy.global_position.distance_to(dragon.global_position))
			if copy.mode == dragon.mode:
				agreed += 1
	check("a puppet follows", behind < 4.0 and agreed > 400, "(at worst %.2f m behind)" % behind)
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, dragon.state_bytes().size() == MazeEnemy.STATE_SIZE)
	dragon.rider_seat = 2
	dragon._songs = 5
	copy.from_bytes(dragon.state_bytes())
	check("the news says whose seat rides it, and when it sings", copy.rider_seat == 2 and copy._heard_songs == 5)
	dragon.rider_seat = -1

	var set_a := MazeEnemies.new()
	stage.add_child(set_a)
	set_a.maze = maze
	var a := set_a.add(MazeLuckDragon.new(), nav.lairs(4)[0], 0.0, 77)
	var set_b := MazeEnemies.new()
	stage.add_child(set_b)
	set_b.maze = maze
	set_b.puppet = true
	var b := set_b.add(MazeLuckDragon.new(), nav.lairs(4)[0], 0.0, 77)
	await frames(3)
	set_b.unpack(set_a.pack())
	await frames(2)
	check("MazeEnemies packs and unpacks a luck dragon", b.puppet and b.global_position.distance_to(a.global_position) < 1.0)
	var meshes := dragon.look.find_children("*", "MeshInstance3D", true, false)
	var shown := meshes.filter(func(m: MeshInstance3D) -> bool: return m.visible)
	check("it is one skinned mesh at a time (a full one near, a low one far)", meshes.size() == 2 and shown.size() == 1)
	check("it takes no part in the world's hunting", not Ecology.takes_part(dragon))

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)


func still_time_for(dragon: MazeLuckDragon) -> float:
	return dragon.still_time + 1.0

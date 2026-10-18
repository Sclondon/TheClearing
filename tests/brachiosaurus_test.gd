extends SceneTree
## The brachiosaurus (scripts/enemies/maze_brachiosaurus.gd on
## creatures/brachiosaurus), headless, on the plan of a whole maze (the desert
## and the round sections: no walls built, it is moved by hand over its
## ground). In turn: its places are out in the desert's quarters and the wide
## round halls; left alone it walks on from place to place in its own quarter
## and stands to browse; a lifted foot says where it will come down, and its
## shadow spot darkens there; someone standing where a foot comes down is
## crushed and caught; someone under its belly between its legs, or beside it,
## is not; the ground shakes for this machine's player near it; a puppet
## follows the host with its feet in step; its sounds are made.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/brachiosaurus_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze: Maze
var failures := 0
var caught_by: Array = []


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func wait(seconds: float, until := Callable()) -> bool:
	for i in int(seconds * 60.0):
		await physics_frame
		if until.is_valid() and until.call():
			return true
	return not until.is_valid()


func _initialize() -> void:
	stage = Node3D.new()
	stage.name = "Stage"
	root.add_child(stage)
	maze = Maze.generate(Maze.seed_for("TEST", 1), 7)
	_run.call_deferred()


func brach_at(at: Vector3, yaw := 0.0, one: MazeBrachiosaurus = null) -> MazeBrachiosaurus:
	var brach := one if one else MazeBrachiosaurus.new()
	brach.maze = maze
	brach.position = at
	brach.rotation.y = yaw
	stage.add_child(brach)
	brach.caught.connect(func(player: Node3D) -> void: caught_by.append([player, brach]))
	return brach


func clear() -> void:
	for child in stage.get_children():
		child.queue_free()
	caught_by.clear()
	await frames(2)


## A stand-in for someone standing still at `at`.
func someone_at(at: Vector3) -> Node3D:
	var body := Node3D.new()
	stage.add_child(body)
	body.global_position = at
	return body


func _run() -> void:
	await frames(5)
	check("the maze has a desert and round sections", maze.round_rings != null and not maze.round_rings.rings.is_empty())
	# --- Its places ---
	var spots := MazeBrachiosaurus.spots(maze, 6, 11)
	var outer := maze.round_rings
	var in_desert := 0
	var in_round := 0
	for at in spots:
		var p := Vector2(at.x, at.z)
		if p.length() < outer.inner_radius and maxf(absf(p.x), absf(p.y)) > outer.square_half + 20.0:
			in_desert += 1
		elif p.length() > outer.inner_radius:
			in_round += 1
	check("its places: out in the desert and in the round sections, none in the square maze", spots.size() == 6 and in_desert >= 3 and in_desert + in_round == 6, "(%d in the desert, %d round)" % [in_desert, in_round])

	# --- Alone, it roams its quarter and browses ---
	var start := spots[0]
	var brach := brach_at(start, 0.3)
	brach.stay_time = Vector2(3.0, 4.0)
	brach.targets = [someone_at(start + Vector3(300.0, 0.0, 0.0))]
	var quarter := DesertStyle.quarter_at(start.x, start.z)
	var furthest := 0.0
	var browsed := false
	var left_quarter := false
	for i in 90 * 60:
		await physics_frame
		furthest = maxf(furthest, brach.global_position.distance_to(start))
		browsed = browsed or brach.mode in [MazeBrachiosaurus.Mode.BROWSE, MazeBrachiosaurus.Mode.GAZE]
		if DesertStyle.quarter_at(brach.global_position.x, brach.global_position.z) != quarter:
			left_quarter = true
	check("alone, it walks on from place to place", furthest > 25.0, "(at most %.0f m from where it began in 90 s)" % furthest)
	check("and stands at each, browsing or gazing", browsed)
	check("it keeps to its own quarter of the desert", not left_quarter)
	var ground := maze.ground_height(brach.global_position)
	check("it stands on the dunes", absf(brach.global_position.y - ground) < 0.05, "(%.2f over the ground)" % (brach.global_position.y - ground))
	await clear()

	# --- Its feet: where a lifted foot will come down; someone there is crushed ---
	brach = brach_at(start, 0.0)
	brach.stay_time = Vector2(0.0, 0.0)
	brach.goal_point = start + Vector3(sin(0.0), 0.0, cos(0.0)) * 200.0
	brach.mode = MazeBrachiosaurus.Mode.ROAM
	var victim := someone_at(start + Vector3(60.0, 0.0, 0.0))
	brach.targets = [victim]
	var lifted := -1
	var spot_shown := false
	for i in 30 * 60:
		await physics_frame
		if brach.velocity.length() < 0.8:
			continue
		for k in 4:
			var land := brach.brach.landing(k)
			if land.w > 0.05 and land.w < 0.35:
				lifted = k
		if lifted >= 0:
			break
	check("walking, a lifted foot says where it will come down", lifted >= 0)
	var land := brach.brach.landing(maxi(lifted, 0))
	victim.global_position = Vector3(land.x, maze.ground_height(Vector3(land.x, 0.0, land.z)), land.z)
	for i in 40:
		await physics_frame
		var shadows := brach.brach.get_node_or_null(^"FootShadows") as MultiMeshInstance3D
		if shadows and shadows.multimesh.get_instance_color(maxi(lifted, 0)).a > 0.3:
			spot_shown = true
	check("a dark spot shows on the ground where it will come down", spot_shown)
	var crushed := await wait(3.0, func() -> bool: return not caught_by.is_empty())
	check("someone standing there when it comes down is crushed and caught", crushed and caught_by[0][0] == victim)
	await clear()

	# --- Under its belly, between its legs, or beside it: not hurt ---
	brach = brach_at(start, 0.0)
	brach.mode = MazeBrachiosaurus.Mode.ROAM
	brach.goal_point = start + Vector3(0.0, 0.0, 200.0)
	var beside := someone_at(start + Vector3(4.5, 0.0, 0.0))
	var under := someone_at(start + Vector3(0.0, 0.0, 0.2))
	brach.targets = [beside, under]
	var steps := [0]
	brach.brach.footfall.connect(func(_at: Vector3, _w: float) -> void: steps[0] += 1)
	for i in 12 * 60:
		await physics_frame
		# (each keeps with it: one beside it, one under its middle)
		var forward := Vector3(sin(brach.facing_yaw), 0.0, cos(brach.facing_yaw))
		var left := Vector3(forward.z, 0.0, -forward.x)
		beside.global_position = brach.global_position + left * 4.5
		under.global_position = brach.global_position + forward * 0.2
	check("someone beside it, or under its belly between its legs, as it walks, is not hurt", steps[0] >= 8 and caught_by.is_empty(), "(%d footfalls, %d caught)" % [steps[0], caught_by.size()])
	await clear()

	# --- The ground shakes for this machine's player near it ---
	var boy: Node3D = load("res://player.tscn").instantiate()
	boy.set(&"takes_input", false)
	stage.add_child(boy)
	boy.add_to_group(&"maze_players")
	boy.global_position = start + Vector3(0.0, 0.5, 15.0)
	brach = brach_at(start, 0.0)
	MazeBrachiosaurus._shake = 0.0
	brach._shake_for(start + Vector3(0.0, 0.0, 3.0), 1.0)
	var near_shake := MazeBrachiosaurus._shake
	MazeBrachiosaurus._shake = 0.0
	brach._shake_for(start + Vector3(0.0, 0.0, -60.0), 1.0)
	check("a footfall shakes the camera of a player near it, not of one far off", near_shake > 0.03 and MazeBrachiosaurus._shake == 0.0, "(%.3f near)" % near_shake)
	MazeBrachiosaurus._shake = 0.0
	await clear()

	# --- A puppet follows the host, its feet in step ---
	var host := brach_at(start, 0.0)
	host.mode = MazeBrachiosaurus.Mode.ROAM
	host.goal_point = start + Vector3(0.0, 0.0, 200.0)
	host.targets = [someone_at(start + Vector3(80.0, 0.0, 0.0))]
	var copy := MazeBrachiosaurus.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = start
	stage.add_child(copy)
	copy.caught.connect(func(player: Node3D) -> void: caught_by.append([player, copy]))
	var off := 0.0
	var out_of_step := 0.0
	for i in 600:
		await physics_frame
		if i % 6 == 0:
			copy.from_bytes(host.state_bytes())
		if i > 120:
			off = maxf(off, copy.global_position.distance_to(host.global_position))
			out_of_step = maxf(out_of_step, absf(angle_difference(copy.brach.rig._phase * TAU, host.brach.rig._phase * TAU)) / TAU)
	check("the puppet keeps up with the host", off < 1.5, "(at most %.2f m off)" % off)
	check("its feet keep in step with the host's", out_of_step < 0.08, "(at most %.2f of a stride out)" % out_of_step)
	await clear()

	check("its sounds are made", Brachiosaurus.bellow_sound().data.size() > 1000 and Brachiosaurus.rumble_sound().data.size() > 1000 and Brachiosaurus.thud_sound().data.size() > 1000 and Brachiosaurus.crunch_sound().data.size() > 1000)
	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)

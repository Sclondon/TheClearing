extends SceneTree
## Vines hanging from vines strung across the halls (MazeFeatures._strand_vines,
## VineStrand.hang): a picture of a strung vine with vines hanging from it, and a check
## that their tops go where it goes: walked on (it dips), then cut (each with its half).
## With the game's own section styles.
##
##     godot --path . --resolution 1280x720 --audio-driver Dummy -s res://tools/strand_vines_shots.gd -- <folder>

var main: Node
var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _initialize() -> void:
	MazeStyle.chosen = MazeStyle.defaults()
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else "user://strand_vines_shots"
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 30:
		await physics_frame
	var world = main.world
	var player = world.player
	var features: MazeFeatures = world.maze_features()
	var hung := 0
	var strand: VineStrand = null
	for each: VineStrand in features.strands:
		hung += each._hung.size()
		# (about level, with the most hanging from it)
		if absf(each.from.y - each.to.y) < 1.0 and (strand == null or each._hung.size() > strand._hung.size()):
			strand = each
	var pieces: Array = world.get_node("Maze").layout.pieces(MazePiece.Kind.VINE).filter(func(piece: MazePiece) -> bool: return piece.held == Vine.Held.STRAND)
	check("vines hang from strung vines", hung > 0 and hung == pieces.size(), "(%d hung of %d laid out, on %d strung vines)" % [hung, pieces.size(), features.strands.size()])
	if strand == null or strand._hung.is_empty():
		quit(1)
		return
	var vine: Vine = strand._hung[0][0]
	var place: float = strand._hung[0][1]
	var gap := func() -> float: return vine.global_position.distance_to(strand._point_on(place) + Vector3.DOWN * VineStrand.HUNG_UNDER)
	check("its top is on the strung vine", gap.call() < 0.02, "(%.3f m off, %d hang from it)" % [gap.call(), strand._hung.size()])
	# The picture: from the floor beside it, looking up at it.
	player.visible = false
	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.far = 600.0
	world.add_child(camera)
	camera.make_current()
	var middle := (strand.from + strand.to) * 0.5
	var across := (strand.to - strand.from).normalized().cross(Vector3.UP)
	camera.global_position = Vector3(middle.x, maxf(vine.bottom_y() - 2.0, 1.6), middle.z) + across * 7.0
	camera.look_at(Vector3(middle.x, (middle.y + vine.bottom_y()) * 0.5, middle.z))
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png("%s/1_vines_from_a_strung_vine.png" % folder)
	print("saved %s/1_vines_from_a_strung_vine.png" % folder)
	player.visible = true
	# Walked on: he stands on it over the vine, it dips, the vine's top with it.
	var before := vine.global_position.y
	world.dev = null
	player.state = player.State.FREE
	player.global_position = strand._point_on(place) + Vector3.UP * 0.4
	player.velocity = Vector3.ZERO
	RopeBridge.bodies_now(self)
	for i in 90:
		await physics_frame
	check("walked on, it dips and the vine's top with it", vine.global_position.y < before - 0.05 and gap.call() < 0.02,
		"(top %.2f -> %.2f, %.3f m off it)" % [before, vine.global_position.y, gap.call()])
	# Cut on the far side of it from the vine: the vine goes with its half.
	player.global_position = middle + across * 3.0
	for i in 5:
		await physics_frame
	var from_start: bool = place < (RopeBridge.POINTS - 1) * 0.5
	var cut_at: Vector3 = strand._point_on(place + (2.0 if from_start else -2.0))
	var halves: Array[Vine] = strand.cut(cut_at)
	var half: Vine = null
	for each in halves:
		if (each.global_position.distance_to(strand.from) < 0.1) == from_start:
			half = each
	for i in 120:
		await physics_frame
	if half and is_instance_valid(vine):
		var down: float = half._carried[0][1] if not half._carried.is_empty() else -1.0
		check("cut, it goes with its half as that swings down", not half._carried.is_empty() and vine.global_position.distance_to(half.point_at(down)) < 0.02 \
			and vine.global_position.distance_to(half.global_position) < down + 0.2,
			"(%.1f m down the half, %.3f m off it, %d halves)" % [down, vine.global_position.distance_to(half.point_at(down)), halves.size()])
	else:
		check("cut, it goes with its half", false, "(half %s, vine %s)" % [half, is_instance_valid(vine)])
	print("STRAND VINES %s" % ("PASSED" if failures == 0 else "FAILED (%d)" % failures))
	quit(failures)

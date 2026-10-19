extends SceneTree
## Pictures of a hall of the first section with its vines, ivy and cables as the
## user's concept slice has them (2026-10-18): ivy up to the ledges, brackets high
## over them, and the vines hung on what is there (MazeStyle "Vines": strung across
## between the ledges, hanging straight down, strung or swept across from brackets,
## vents, junction boxes and bare wall), cables slanting across and down from a ledge.
## In a real round, the first section set as the user has it (120 m walls 13 m
## thick, a ledge 10 m up; pass a second argument for another ledge height).
## Looks along the hall from the floor and from a ledge, and across it.
##
##     godot --path . --resolution 1280x720 --audio-driver Dummy -s res://tools/zone1_vines_shots.gd -- <folder> [ledge m]
## (or, for the second argument, a mode: anchors, leaves (close up), wallvines (vines out of the walls),
## hung (vines hung on the props: vents, outlets, culverts, junction boxes), zone2, levels (zone2 with three levels
## of ledge each its own height and depth: 6 m up and 4 m deep, 12 m over it 2.5 m deep, 18 m over that 1 m deep),
## corners, border, clearing)

var main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var styles := MazeStyle.square_defaults() + MazeStyle.round_defaults()
	var first: MazeStyle = styles[0]
	first.maze_wall_height = 120.0
	first.maze_wall_diameter = 13.0
	first.section_border_wall_height = 175.0
	first.mezzanines = [MezzanineLevel.made(float(args[1]) if args.size() > 1 and args[1].is_valid_float() else 10.0, 1.0)]
	# (the second as the user has it: walls 100 m high and 10 m thick, three levels of ledge from 5 m up, 20 m apart)
	var second: MazeStyle = styles[1]
	second.section_width_cells = 10
	second.maze_wall_diameter = 10.0
	second.maze_wall_height = 100.0
	second.section_border_wall_height = 100.0
	second.mezzanines = [MezzanineLevel.made(5.0, 4.0), MezzanineLevel.made(20.0, 3.4, 0.55), MezzanineLevel.made(20.0, 2.8, 0.55)]
	if args.size() > 1 and args[1] == "levels":
		second.mezzanines = [MezzanineLevel.made(6.0, 4.0), MezzanineLevel.made(12.0, 2.5, 0.7), MezzanineLevel.made(18.0, 1.0, 0.7)]
	MazeStyle.chosen = styles
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else "user://zone1_vines_shots"
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 30:
		await physics_frame
	var world = main.world
	world.player.visible = false
	if args.size() > 1 and args[1] == "anchors":
		await _anchors(world, folder)
		quit()
		return
	if args.size() > 1 and args[1] == "leaves":
		await _leaves(world, folder)
		quit()
		return
	if args.size() > 1 and args[1] == "hung":
		await _hung(world, folder)
		quit()
		return
	if args.size() > 1 and args[1] == "wallvines":
		await _wall_vines(world, folder)
		quit()
		return
	if args.size() > 1 and args[1] == "corners":
		await _corners(world, folder)
		quit()
		return
	if args.size() > 1 and args[1] == "clearing":
		await _clearing_wall(world, folder)
		quit()
		return
	if args.size() > 1 and args[1] == "border":
		await _border(world, folder)
		quit()
		return
	if args.size() > 1 and args[1] in ["zone2", "levels"]:
		await _zone2(world, folder)
		quit()
		return
	var maze: Maze = world.maze
	var style: MazeStyle = maze.styles[0]
	var ledge := style.level_height(0)
	var layout: MazeLayout = world.get_node("Maze").layout
	# The brackets of the first section, and what is near each: pick the hall with the most of the concept in it.
	var brackets: Array = []
	for piece in layout.pieces(MazePiece.Kind.PIER):
		var size := piece.box_size()
		if is_equal_approx(maxf(size.x, size.z), MazeFeatures.BRACKET.x) and maze.ring_of(maze.cell_at(piece.position)) == 1:
			brackets.append(piece)
	print("brackets in the first section: ", brackets.size())
	var near_things := func(at: Vector3) -> int:
		var count := 0
		for kind: MazePiece.Kind in [MazePiece.Kind.STRAND, MazePiece.Kind.WIRE, MazePiece.Kind.VINE]:
			for piece in layout.pieces(kind):
				if Vector2(piece.position.x - at.x, piece.position.z - at.z).length() < 14.0:
					count += 1
		for piece in layout.pieces(MazePiece.Kind.PROP):
			if piece.prop == MazeProps.Prop.JUNCTION_BOX and Vector2(piece.position.x - at.x, piece.position.z - at.z).length() < 14.0:
				count += 2
		return count
	var best: MazePiece = null
	var best_count := -1
	for piece: MazePiece in brackets:
		var count: int = near_things.call(piece.position)
		if count > best_count:
			best_count = count
			best = piece
	if best == null:
		print("no brackets")
		quit(1)
		return
	print("hall at ", best.position, " with ", best_count, " things near")
	var size := best.box_size()
	# (along the wall, and out of it into the hall)
	var along := Vector3(1, 0, 0) if size.x > size.z else Vector3(0, 0, 1)
	var cell := maze.cell_at(best.position)
	# (out of the wall it is on: the face of the cell's wall nearest it)
	var out := Vector3.UP.cross(along)
	for way: Vector3 in [out, -out]:
		var into := Vector2i(roundi(-way.x), roundi(-way.z))
		var face := maze.world(cell) - way * (Maze.CELL * 0.5 - maze.wall_thick(cell, into) * 0.5)
		if maze.blocked(cell, into) and absf((best.position - face).dot(way)) < 2.0:
			out = way
	# (the hall's middle across: half way to the far wall)
	var wall_at := best.position - out * best.box_size().dot(out.abs()) * 0.5
	var step := Vector2i(roundi(out.x), roundi(out.z))
	var far := cell
	for k in 3:
		if maze.blocked(far, step):
			break
		far += step
	var far_face := maze.world(far) + out * (Maze.CELL * 0.5 - maze.wall_thick(far, step) * 0.5)
	var width := (far_face - wall_at).dot(out)
	var hall := Vector3(wall_at.x, 0.0, wall_at.z) + out * width * 0.5
	print("hall %.1f m across over the ledges" % width)
	world.player.global_position = hall + Vector3.UP * 0.2
	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.far = 600.0
	world.add_child(camera)
	camera.make_current()
	var high := best.position.y
	# Across the hall, looking along it as the concept slice is drawn: from the floor, and from up at the ledges.
	camera.global_position = hall - along * 26.0 + Vector3.UP * 1.7
	camera.look_at(hall + Vector3.UP * (high * 0.55))
	await _shot("%s/1_along_from_the_floor.png" % folder)
	camera.global_position = hall - along * 30.0 + Vector3.UP * (ledge + 2.0)
	camera.look_at(hall + Vector3.UP * (ledge + 2.0))
	await _shot("%s/2_along_level_with_the_ledges.png" % folder)
	# From the floor under the bracket's wall, looking up and across.
	camera.global_position = hall - out * width * 0.3 + along * 6.0 + Vector3.UP * 1.7
	camera.look_at(hall + out * width * 0.4 + Vector3.UP * (ledge + 4.0))
	await _shot("%s/3_up_from_the_floor.png" % folder)
	# From the ledge under the bracket, looking across the hall and back along it.
	# (on the side of the vine hanging from the bracket, clear of its ivy)
	var vine_side := 1.0
	for piece in layout.pieces(MazePiece.Kind.VINE):
		if piece.position.distance_to(best.position) < 3.0:
			vine_side = signf((piece.position - best.position).dot(along))
	var on_ledge := wall_at + out * style.level_depth(0) * 0.5 + along * 9.0 * vine_side
	on_ledge.y = ledge + 1.6
	camera.global_position = on_ledge
	camera.look_at(best.position + out * 5.0 + Vector3.DOWN * 4.0)
	await _shot("%s/4_from_the_ledge.png" % folder)
	# From the far ledge, looking back at the bracket's wall.
	var far_ledge := wall_at + out * (width - style.level_depth(0) * 0.5) - along * 8.0
	far_ledge.y = ledge + 1.6
	camera.global_position = far_ledge
	camera.look_at(best.position + Vector3.DOWN * 3.0)
	await _shot("%s/5_from_the_far_ledge.png" % folder)
	quit()


## The second section (the user's concept of it: three levels of ledge stepping
## back, arched concrete bridges between them, vines hanging and swept down): a
## hall with the most in it, looked along from the floor, from each level, and
## from a bridge.
func _zone2(world: Node, folder: String) -> void:
	var maze: Maze = world.maze
	var style: MazeStyle = maze.styles[1]
	var layout: MazeLayout = world.get_node("Maze").layout
	# (the bridges' decks: as thick as MazeFeatures makes them, longer across than wide)
	var decks: Array = []
	for piece in layout.pieces(MazePiece.Kind.PIER):
		var size := piece.box_size()
		if piece.arch > 0.0 and maxf(size.x, size.z) > style.concrete_bridge_width + 1.0 and maze.ring_of(maze.cell_at(piece.position)) == 2:
			decks.append(piece)
	print("concrete bridges in the second section: ", decks.size())
	var best: MazePiece = null
	var best_count := -1
	for deck: MazePiece in decks:
		var count := 0
		for other: MazePiece in decks:
			if other != deck and Vector2(other.position.x - deck.position.x, other.position.z - deck.position.z).length() < 10.0:
				count += 4
		for kind: MazePiece.Kind in [MazePiece.Kind.STRAND, MazePiece.Kind.VINE]:
			for piece in layout.pieces(kind):
				if Vector2(piece.position.x - deck.position.x, piece.position.z - deck.position.z).length() < 16.0:
					count += 1
		if count > best_count:
			best_count = count
			best = deck
	if best == null:
		print("no concrete bridges")
		return
	var size := best.box_size()
	var across := Vector3(1, 0, 0) if size.x > size.z else Vector3(0, 0, 1)
	var along := Vector3.UP.cross(across)
	var hall := Vector3(best.position.x, 0.0, best.position.z)
	var top := best.position.y + best.box_size().y
	print("bridge at %s, %.1f m up, %.1f m long, %d things near" % [best.position, top, maxf(size.x, size.z), best_count])
	var camera := Camera3D.new()
	camera.fov = 66.0
	camera.far = 600.0
	world.add_child(camera)
	camera.make_current()
	var levels: Array[float] = []
	for level in style.mezzanine_count():
		levels.append(style.level_height(level))
	for way: float in [1.0, -1.0]:
		var tag := "a" if way > 0.0 else "b"
		# Looking along the hall from the floor, as the concept slice is drawn, and up from under the bridge.
		camera.global_position = hall - along * way * 34.0 + Vector3.UP * 1.7
		camera.look_at(hall + Vector3.UP * levels[-1] * 0.6)
		await _shot("%s/z2_%s1_along_from_the_floor.png" % [folder, tag])
		camera.global_position = hall - along * way * 40.0 + Vector3.UP * (levels[1] + 2.0)
		camera.look_at(hall + Vector3.UP * (levels[1] + 2.0))
		await _shot("%s/z2_%s2_along_from_the_middle.png" % [folder, tag])
		# From the bridge, looking along the hall.
		camera.global_position = hall + Vector3.UP * (top + 1.6)
		camera.look_at(hall + along * way * 20.0 + Vector3.UP * (top - 4.0))
		await _shot("%s/z2_%s3_from_the_bridge.png" % [folder, tag])
	# From a ledge at the bridge's level, a little along, looking at the bridge.
	camera.global_position = hall - across * (maxf(size.x, size.z) * 0.5 - 1.0) + along * 9.0 + Vector3.UP * (top + 1.6)
	camera.look_at(hall + Vector3.UP * (top - 3.0))
	await _shot("%s/z2_4_from_the_ledge.png" % folder)


## The ledges going round the end of a wall (the user: "the mezzanine should go
## around corners not just end"), and vents and outlets on a ledge's front (the
## user: "sewer parts should stick out of the mezzanine rather than get clipped"),
## in the second section, whose ledges are deepest.
func _corners(world: Node, folder: String) -> void:
	var maze: Maze = world.maze
	var style: MazeStyle = maze.styles[1]
	var layout: MazeLayout = world.get_node("Maze").layout
	var camera := Camera3D.new()
	camera.fov = 66.0
	world.add_child(camera)
	camera.make_current()
	var shots := 0
	for piece in layout.pieces(MazePiece.Kind.PIER):
		var size := piece.box_size()
		if shots >= 2 or not piece.ledge or maze.ring_of(maze.cell_at(piece.position)) != 2 or piece.position.y > 0.1:
			continue
		# (across a wall's end: as long as the wall is thick, as deep as the ledge)
		if is_equal_approx(maxf(size.x, size.z), style.maze_wall_diameter) and is_equal_approx(minf(size.x, size.z), style.level_depth(0)):
			var thin := Vector3(1, 0, 0) if size.x < size.z else Vector3(0, 0, 1)
			# (out from the end face: away from the wall, which is the side with stone)
			var way := 1.0 if not _solid(layout, piece.position + thin * (size.dot(thin) * 0.5 + 1.0) + Vector3.UP * 2.0) else -1.0
			var across := Vector3.UP.cross(thin)
			camera.global_position = piece.position + thin * way * 12.0 + across * 9.0 + Vector3.UP * (style.level_height(0) + 6.0)
			camera.look_at(piece.position + Vector3.UP * style.level_height(0) * 0.7)
			await _shot("%s/corner_%d.png" % [folder, shots])
			shots += 1
	print("corner shots: ", shots)
	shots = 0
	for piece in layout.pieces(MazePiece.Kind.PROP):
		if shots >= 2 or not (piece.prop in [MazeProps.Prop.VENT, MazeProps.Prop.ROUND_VENT, MazeProps.Prop.OUTLET]) or maze.ring_of(maze.cell_at(piece.position)) != 2:
			continue
		var out := piece.transform.basis.orthonormalized().z
		camera.global_position = piece.position + out * 4.5 + out.cross(Vector3.UP) * 2.5 + Vector3.UP * 0.5
		camera.look_at(piece.position)
		await _shot("%s/sewer_on_ledge_%d.png" % [folder, shots])
		shots += 1
	print("sewer shots: ", shots)


## Close up where vines are held (the user: "the vines need to have a root or leaves
## at their connection points"): the tops of vines hanging from a ledge's edge and
## from under a bracket, and the ends of strung vines.
func _anchors(world: Node, folder: String) -> void:
	var features: MazeFeatures = world.maze_features()
	var camera := Camera3D.new()
	camera.fov = 60.0
	world.add_child(camera)
	camera.make_current()
	var spots: Array = []
	var held := 0
	var over := 0
	for vine: Vine in features.vines:
		if world.maze.ring_of(world.maze.cell_at(vine.global_position)) != 1:
			continue
		if vine.hold != Vector3.ZERO and held < 2:
			spots.append([vine.global_position, vine.hold, "vine_on_ledge_edge"])
			held += 1
		elif vine.hold == Vector3.ZERO and over < 1:
			spots.append([vine.global_position, Vector3.UP, "vine_under_bracket"])
			over += 1
	for strand: VineStrand in features.strands.slice(0, 2):
		var out := Vector3(strand.to.x - strand.from.x, 0.0, strand.to.z - strand.from.z).normalized()
		spots.append([strand.from, -out, "strand_end"])
	for k in spots.size():
		var at: Vector3 = spots[k][0]
		var hold: Vector3 = spots[k][1]
		var away := -hold if absf(hold.y) < 0.5 else Vector3(1, 0, 0)
		camera.global_position = at + away * 2.2 + away.cross(Vector3.UP) * 1.2 + Vector3.DOWN * 0.8
		camera.look_at(at)
		await _shot("%s/anchor_%d_%s.png" % [folder, k, spots[k][2]])


## Close up the leaves (the user, 2026-10-18: "lets make a real leaf shape and try to
## make sure they arent just floating"): along a vine's stem; where vines are held,
## each way they are (Vine.Held), from above and from the side; a patch of ivy on a
## wall, face on and from along the wall (how near the wall its leaves lie); and
## the ends of strung vines.
func _leaves(world: Node, folder: String) -> void:
	var maze: Maze = world.maze
	var features: MazeFeatures = world.maze_features()
	var camera := Camera3D.new()
	camera.fov = 50.0
	camera.near = 0.02
	world.add_child(camera)
	camera.make_current()
	var in_first := func(at: Vector3) -> bool: return maze.ring_of(maze.cell_at(at)) == 1
	# Along a vine's stem, half way down.
	for vine: Vine in features.vines:
		if in_first.call(vine.global_position) and vine.length > 4.0:
			var p := vine.point_at(vine.length * 0.5)
			var side := Vector3.UP.cross(vine.hold if vine.hold.length_squared() > 0.01 else Vector3.BACK).normalized()
			camera.global_position = p + side * 2.4 + Vector3.UP * 0.3
			camera.look_at(p)
			await _shot("%s/leaves_1_stem.png" % folder)
			break
	# Where vines are held, each way.
	var names := {Vine.Held.OVER: "over", Vine.Held.LIP: "lip", Vine.Held.FACE: "face", Vine.Held.GROUND: "ground"}
	for how: int in names:
		for vine: Vine in features.vines:
			if vine.held != how or not in_first.call(vine.global_position):
				continue
			var at := vine.global_position
			var into := vine.hold if vine.hold.length_squared() > 0.01 else Vector3.BACK
			var side := Vector3.UP.cross(into).normalized()
			camera.global_position = at - into * 1.1 + side * 0.7 + Vector3.UP * 0.8
			camera.look_at(at + into * 0.15)
			await _shot("%s/leaves_2_held_%s_above.png" % [folder, names[how]])
			# (from under it, if it is under what holds it)
			camera.global_position = at + side * 1.4 - into * 0.2 + Vector3.UP * (-0.6 if how == Vine.Held.OVER else 0.15)
			camera.look_at(at + into * 0.1)
			await _shot("%s/leaves_3_held_%s_side.png" % [folder, names[how]])
			break
	# A patch of ivy on a wall: face on, and from along the wall.
	for ivy: IvyClimb in features.climbs:
		if not in_first.call(ivy.global_position) or ivy.width < 2.5 or ivy.height < 4.0:
			continue
		var basis := ivy.global_transform.basis.orthonormalized()
		# (on a wall, not a curtain hung from a ledge's edge: stone just behind it)
		var layout: MazeLayout = world.get_node("Maze").layout
		if not _solid(layout, ivy.global_position - basis.z * 0.3 + Vector3.UP * 2.0) or _solid(layout, ivy.global_position + basis.z * 1.0 + Vector3.UP * 2.0):
			continue
		if not ivy.grown:
			ivy._grow()
		var middle := ivy.global_position + Vector3.UP * minf(ivy.height * 0.4, 3.0)
		camera.global_position = middle + basis.z * 1.6
		camera.look_at(middle)
		await _shot("%s/leaves_4_ivy_face_on.png" % folder)
		camera.global_position = middle + basis.x * (ivy.width * 0.5 + 0.8) + basis.z * 0.3 + Vector3.UP * 0.2
		camera.look_at(middle + basis.z * 0.05)
		await _shot("%s/leaves_5_ivy_along_the_wall.png" % folder)
		break
	# The ends of strung vines, each way they are held.
	var shot_ends := {}
	for strand: VineStrand in features.strands:
		if not in_first.call(strand.from):
			continue
		for end: Array in [[strand.from, strand.to, strand.from_held], [strand.to, strand.from, strand.to_held]]:
			var how: int = end[2]
			if shot_ends.has(how):
				continue
			shot_ends[how] = true
			var at: Vector3 = end[0]
			var out := Vector3(end[1].x - at.x, 0.0, end[1].z - at.z).normalized()
			var side := Vector3.UP.cross(out).normalized()
			camera.global_position = at + out * 1.3 + side * 0.8 + Vector3.UP * 0.7
			camera.look_at(at)
			await _shot("%s/leaves_6_strand_end_%s.png" % [folder, names[how]])


## The vines grown straight out of the walls (the user, 2026-10-18: "Vines should be
## able to connect directly to the wall and hang a random amount down across the hall"):
## in the first section, one hanging, one swept across to the far wall and one swept
## down to the floor, each from across or along the hall and close up where it
## comes out of the wall.
func _wall_vines(world: Node, folder: String) -> void:
	var maze: Maze = world.maze
	var features: MazeFeatures = world.maze_features()
	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.far = 600.0
	world.add_child(camera)
	camera.make_current()
	var in_first := func(at: Vector3) -> bool: return maze.ring_of(maze.cell_at(at)) == 1
	var hanging := 0
	for vine: Vine in features.vines:
		if vine.held == Vine.Held.FACE and is_equal_approx(vine.reach, MazeFeatures.WALL_GROWN_OUT) and in_first.call(vine.global_position):
			hanging += 1
	var swept := 0
	var grounded := 0
	for strand: VineStrand in features.strands:
		if strand.from_held == Vine.Held.FACE and in_first.call(strand.from):
			if strand.to_held == Vine.Held.GROUND:
				grounded += 1
			else:
				swept += 1
	print("vines out of the walls in the first section: %d hanging, %d swept across, %d swept to the floor" % [hanging, swept, grounded])
	var shots := 0
	for vine: Vine in features.vines:
		if shots >= 2 or vine.held != Vine.Held.FACE or not is_equal_approx(vine.reach, MazeFeatures.WALL_GROWN_OUT) or not in_first.call(vine.global_position):
			continue
		var at := vine.global_position
		var out := -vine.hold
		var along := Vector3.UP.cross(out)
		# (across the hall from it, as far as there is room, and a little along)
		var layout: MazeLayout = world.get_node("Maze").layout
		var eye := at + Vector3.DOWN * minf(vine.length * 0.5, 2.0)
		var room := _room_out(layout, eye, out, 9.0)
		if room < 3.0:
			continue
		camera.global_position = eye + out * room * 0.85 + along * _room_out(layout, eye, along, 3.0) * 0.8
		camera.look_at(at + Vector3.DOWN * vine.length * 0.5)
		await _shot("%s/wall_vine_hanging_%d.png" % [folder, shots])
		camera.global_position = at + out * 1.3 + along * 0.8 + Vector3.UP * 0.3
		camera.look_at(at + vine.hold * 0.2)
		await _shot("%s/wall_vine_hanging_%d_close.png" % [folder, shots])
		shots += 1
	for grounded_end: bool in [false, true]:
		shots = 0
		var tag := "floor" if grounded_end else "far_wall"
		for strand: VineStrand in features.strands:
			if shots >= 2 or strand.from_held != Vine.Held.FACE or (strand.to_held == Vine.Held.GROUND) != grounded_end or not in_first.call(strand.from):
				continue
			var out := Vector3(strand.to.x - strand.from.x, 0.0, strand.to.z - strand.from.z).normalized()
			var along := Vector3.UP.cross(out)
			var middle := (strand.from + strand.to) * 0.5
			# (from along the hall, low, so that it is seen across it against the far wall)
			var layout: MazeLayout = world.get_node("Maze").layout
			var eye := Vector3(middle.x, maxf(middle.y - 2.0, 1.7), middle.z)
			camera.global_position = eye + along * _room_out(layout, eye, along, 13.0) * 0.85
			camera.look_at(middle)
			await _shot("%s/wall_vine_swept_%s_%d.png" % [folder, tag, shots])
			camera.global_position = strand.from + out * 1.3 + along * 0.8 + Vector3.DOWN * 0.3
			camera.look_at(strand.from)
			await _shot("%s/wall_vine_swept_%s_%d_close.png" % [folder, tag, shots])
			if grounded_end:
				camera.global_position = strand.to - out * 1.2 + along * 1.0 + Vector3.UP * 0.9
				camera.look_at(strand.to)
				await _shot("%s/wall_vine_swept_%s_%d_root.png" % [folder, tag, shots])
			shots += 1


## The vines hung on the props (the user, 2026-10-18: "the vines are hung on whats
## there"): in the first two sections, for each kind of prop a vine hangs from or is
## strung from, one of them, from across the hall a little way off and close up.
func _hung(world: Node, folder: String) -> void:
	var maze: Maze = world.maze
	var layout: MazeLayout = world.get_node("Maze").layout
	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.far = 600.0
	world.add_child(camera)
	camera.make_current()
	var names := {MazeProps.Prop.VENT: "vent", MazeProps.Prop.ROUND_VENT: "round_vent", MazeProps.Prop.OUTLET: "outlet",
		MazeProps.Prop.CULVERT: "culvert", MazeProps.Prop.JUNCTION_BOX: "junction_box"}
	var tally := {}
	for piece in layout.pieces(MazePiece.Kind.PROP):
		if not names.has(piece.prop) or maze.ring_of(maze.cell_at(piece.position)) > 2:
			continue
		var big := piece.basis.get_scale().x
		# (a vine hanging from it, or strung from it: its top or end within reach of the prop)
		var hung: MazePiece = null
		for kind: MazePiece.Kind in [MazePiece.Kind.VINE, MazePiece.Kind.STRAND]:
			for vine in layout.pieces(kind):
				if hung == null and vine.position.distance_to(piece.position) < 1.6 * big + 0.3:
					hung = vine
		if hung == null:
			continue
		var tag := "%s_%s" % [names[piece.prop], "hanging" if hung.kind == MazePiece.Kind.VINE else "strung"]
		tally[tag] = tally.get(tag, 0) + 1
		if tally[tag] > 1:
			continue
		var out := piece.basis.orthonormalized().z
		out = Vector3(out.x, 0.0, out.z).normalized()
		var along := Vector3.UP.cross(out)
		var eye := Vector3(piece.position.x, maxf(piece.position.y - 1.0, 1.7), piece.position.z)
		var look := piece.position + (Vector3.DOWN * 2.0 if hung.kind == MazePiece.Kind.VINE else out * 4.0)
		camera.global_position = eye + out * _room_out(layout, eye, out, 9.0) * 0.8 + along * _room_out(layout, eye, along, 4.0) * 0.7
		camera.look_at(look)
		await _shot("%s/hung_%s.png" % [folder, tag])
		camera.global_position = piece.position + out * 2.2 + along * 1.0 + Vector3.UP * 0.4
		camera.look_at(piece.position)
		await _shot("%s/hung_%s_close.png" % [folder, tag])
	print("vines hung on props in the first two sections: ", tally)


## The ledges along the great walls between sections (the user: "the border walls
## should have mezzanines on them"): from a hall of each of the first two
## sections, looking along the wall round it.
func _border(world: Node, folder: String) -> void:
	var maze: Maze = world.maze
	var camera := Camera3D.new()
	camera.fov = 66.0
	camera.far = 600.0
	world.add_child(camera)
	camera.make_current()
	for ring in [1, 2]:
		var found := false
		for i in maze.size * maze.size:
			var cell := Vector2i(i % maze.size, i / maze.size)
			if found or maze.ring_of(cell) != ring:
				continue
			for step: Vector2i in Maze.STEPS:
				if found or not maze.ring_wall(cell, step) or not maze.has_ledge(cell, step):
					continue
				var side := Vector2i(-step.y, step.x)
				# (a run of three cells along it, open along the wall)
				if maze.blocked(cell, side) or maze.blocked(cell, -side) or not maze.has_ledge(cell + side, step) or not maze.has_ledge(cell - side, step):
					continue
				found = true
				var s := Vector3(step.x, 0.0, step.y)
				var along := Vector3(side.x, 0.0, side.y)
				var high: float = maze.styles[ring - 1].level_height(0)
				camera.global_position = maze.world(cell) - s * 3.0 - along * Maze.CELL * 1.2 + Vector3.UP * (high + 4.0)
				camera.look_at(maze.world(cell) + s * Maze.CELL * 0.4 + along * Maze.CELL + Vector3.UP * high * 0.6)
				await _shot("%s/border_ring%d.png" % [folder, ring])
		if not found:
			print("no border ledge in ring ", ring)


## The ledges along the clearing's wall (the user: "the clearing wall still doesnt
## have a mezzanine"): from inside the clearing, and from the first section's hall
## along the rampart's face; and how many ledges overlap another (their tops flicker).
func _clearing_wall(world: Node, folder: String) -> void:
	var maze: Maze = world.maze
	var layout: MazeLayout = world.get_node("Maze").layout
	var ledges: Array = layout.pieces(MazePiece.Kind.PIER).filter(func(piece: MazePiece) -> bool: return piece.ledge)
	var overlaps := 0
	for a in ledges.size():
		for b in range(a + 1, ledges.size()):
			var p: MazePiece = ledges[a]
			var q: MazePiece = ledges[b]
			var gap: Vector3 = (p.position - q.position).abs() - (p.box_size() + q.box_size()) * 0.5
			if gap.x < -0.05 and gap.z < -0.05 and absf(p.position.y - q.position.y) < 0.05:
				overlaps += 1
	print("ledges %d, overlapping pairs %d" % [ledges.size(), overlaps])
	var camera := Camera3D.new()
	camera.fov = 66.0
	camera.far = 600.0
	world.add_child(camera)
	camera.make_current()
	var high: float = maze.styles[0].level_height(0)
	# (inside: from near the clearing's south edge, looking along its wall)
	var edge := maze.ring_sizes[0] * Maze.CELL * 0.5
	var lean := maze.wall_thick(Vector2i.ZERO, Vector2i(0, 1)) * 0.5
	camera.global_position = Vector3(-edge * 0.6, high + 4.0, edge - lean - 14.0)
	camera.look_at(Vector3(edge * 0.2, high * 0.6, edge - lean))
	await _shot("%s/clearing_inside.png" % folder)
	# (outside: a ring 1 cell whose wall towards the clearing is the rampart's face)
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		if maze.ring_of(cell) != 1 or maze.solid.has(cell):
			continue
		for step: Vector2i in Maze.STEPS:
			var side := Vector2i(-step.y, step.x)
			if not maze.solid.has(cell + step) or maze.blocked(cell, side) or maze.blocked(cell, -side):
				continue
			var s := Vector3(step.x, 0.0, step.y)
			var along := Vector3(side.x, 0.0, side.y)
			camera.global_position = maze.world(cell) - s * 2.0 - along * Maze.CELL * 1.2 + Vector3.UP * (high + 4.0)
			camera.look_at(maze.world(cell) + s * Maze.CELL * 0.4 + along * Maze.CELL + Vector3.UP * high * 0.6)
			await _shot("%s/clearing_outside.png" % folder)
			return
	print("no ring 1 hall along the rampart")


func _solid(layout: MazeLayout, p: Vector3) -> bool:
	for kind: MazePiece.Kind in [MazePiece.Kind.WALL, MazePiece.Kind.PIER]:
		for piece in layout.pieces(kind):
			if piece.box_has(p):
				return true
	return false


func _shot(path: String) -> void:
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)


## How far from `from` the `way` way is clear of stone, up to `most` metres.
func _room_out(layout: MazeLayout, from: Vector3, way: Vector3, most: float) -> float:
	var far := 0.0
	while far < most:
		if _solid(layout, from + way * (far + 0.3)):
			break
		far += 0.3
	return far

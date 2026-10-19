extends SceneTree
## The maze's props (MazeProps), headless, by the game's own rules: vents,
## culverts, outlets, drains and manholes in the square sections, and in the
## Avenues heaps of boxes and barrels, cables strung across the halls (some by
## the vines, some snapped, some with a lamp) and more camps; laid out from the
## seed (the same twice, another seed otherwise), as each section's settings say
## (none where they are 0, more where they are more); on the walls' faces and
## clear of the stone; drawn in a few MultiMeshes, lost past the mist, nothing
## processing; the boxes and barrels solid, and the camps and loot off them.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/props_test.gd

var main: Node
var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func _initialize() -> void:
	# (the game's own rules, not the maze editor's)
	MazeStyle.chosen = MazeStyle.defaults()
	_run()


## The props of a maze laid out for `seed_value` (and `styles`, if given), as
## [layout, maze].
func laid_out(seed_value: int, styles: Array[MazeStyle] = []) -> Array:
	var maze := Maze.generate(seed_value, 7, styles)
	var layout := MazeLayout.new()
	root.add_child(layout)
	layout.lay_out(maze)
	return [layout, maze]


## Each prop and cable piece as a line, for comparing layouts.
func listing(layout: MazeLayout) -> PackedStringArray:
	var lines := PackedStringArray()
	for piece in layout.pieces(MazePiece.Kind.PROP):
		lines.append("%d %s" % [piece.prop, piece.transform])
	for piece in layout.pieces(MazePiece.Kind.WIRE):
		lines.append("w %s %s %.2f %s %s" % [piece.position, piece.bridge_end(), piece.sag, piece.tails, piece.lamp])
	return lines


## How many props of each kind in ring `ring`, and cables there.
func tally(layout: MazeLayout, maze: Maze, ring: int) -> Dictionary:
	var counts := {"cables": 0, "snapped": 0, "lamps": 0, "drips": 0}
	for piece in layout.pieces(MazePiece.Kind.PROP):
		if maze.ring_of(maze.cell_at(piece.position)) == ring:
			counts[piece.prop] = counts.get(piece.prop, 0) + 1
			if piece.drips:
				counts["drips"] += 1
	for piece in layout.pieces(MazePiece.Kind.WIRE):
		if maze.ring_of(maze.cell_at((piece.position + piece.bridge_end()) * 0.5)) == ring:
			counts["cables"] += 1
			if piece.tails != Vector2.ZERO:
				counts["snapped"] += 1
			if piece.lamp:
				counts["lamps"] += 1
	return counts


func _run() -> void:
	var P := MazeProps.Prop
	var made := laid_out(4242)
	var layout: MazeLayout = made[0]
	var maze: Maze = made[1]
	var avenues := tally(layout, maze, 1)
	print("  Avenues: ", avenues)
	for kind: int in [P.VENT, P.ROUND_VENT, P.CULVERT, P.OUTLET, P.STAIN, P.PUDDLE, P.DRAIN, P.MANHOLE, P.CRATE, P.BARREL]:
		check("the Avenues have %s" % P.keys()[kind], avenues.get(kind, 0) > 0, "(%d)" % avenues.get(kind, 0))
	check("an outlet's rust stain under each", avenues.get(P.STAIN, 0) == avenues.get(P.OUTLET, 0))
	check("some outlets drip, not all", avenues["drips"] > 0 and avenues["drips"] < avenues.get(P.OUTLET, 0), "(%d of %d)" % [avenues["drips"], avenues.get(P.OUTLET, 0)])
	check("cables strung in the Avenues, some snapped, some with lamps", avenues["cables"] > 10 and avenues["snapped"] > 0 and avenues["lamps"] > 0, "(%d, %d snapped, %d lamps)" % [avenues["cables"], avenues["snapped"], avenues["lamps"]])
	var galleries := tally(layout, maze, 2)
	print("  Galleries: ", galleries)
	check("the Galleries have vents and drains too", galleries.get(P.VENT, 0) + galleries.get(P.ROUND_VENT, 0) > 0 and galleries.get(P.DRAIN, 0) > 0)
	check("but no heaps or cables (only the Avenues' rules have them)", galleries.get(P.CRATE, 0) + galleries.get(P.BARREL, 0) == 0 and galleries["cables"] == 0)
	check("Avenues' rules: three camps left", MazeStyle.avenues().abandoned_camps == 3)

	# Cables by the vines: near the strung vines' ends.
	var by_vines := 0
	for strand in layout.pieces(MazePiece.Kind.STRAND):
		for wire in layout.pieces(MazePiece.Kind.WIRE):
			if wire.position.distance_to(strand.position) < 6.0 and wire.bridge_end().distance_to(strand.bridge_end()) < 6.0:
				by_vines += 1
				break
	check("cables strung in among the vines across halls", by_vines > 0, "(%d of %d vines)" % [by_vines, layout.pieces(MazePiece.Kind.STRAND).size()])

	# --- From the seed ---
	var again := laid_out(4242)
	check("the same seed lays out the same props", listing(layout) == listing(again[0]), "(%d)" % listing(layout).size())
	var other := laid_out(777)
	check("another seed lays out others", listing(layout) != listing(other[0]))
	(again[0] as Node).free()
	(other[0] as Node).free()

	# --- As the settings say ---
	# (made fresh: MazeStyle.defaults() is the chosen ones themselves)
	var bare: Array[MazeStyle] = MazeStyle.square_defaults() + MazeStyle.round_defaults()
	for setting: StringName in [&"wall_vent_share", &"culvert_share", &"outlet_share", &"drain_share", &"manhole_share", &"clutter_share", &"cable_share", &"wall_cable_share"]:
		bare[0].set(setting, 0.0)
	var none := laid_out(4242, bare)
	var none_count := tally(none[0], none[1], 1)
	var in_ring := 0
	for value in none_count.values():
		in_ring += int(value)
	check("none in a section whose settings are 0", in_ring == 0, "(%s)" % none_count)
	var more: Array[MazeStyle] = MazeStyle.square_defaults() + MazeStyle.round_defaults()
	more[0].clutter_share = 0.2
	more[0].cable_share = 0.4
	more[0].wall_vent_share = 0.15
	var lots := laid_out(4242, more)
	var lots_count := tally(lots[0], lots[1], 1)
	check("more where the shares are more", lots_count.get(P.CRATE, 0) + lots_count.get(P.BARREL, 0) > avenues.get(P.CRATE, 0) + avenues.get(P.BARREL, 0)
		and lots_count["cables"] > avenues["cables"] and lots_count.get(P.VENT, 0) + lots_count.get(P.ROUND_VENT, 0) > avenues.get(P.VENT, 0) + avenues.get(P.ROUND_VENT, 0),
		"(heaps %d > %d things, cables %d > %d)" % [lots_count.get(P.CRATE, 0) + lots_count.get(P.BARREL, 0), avenues.get(P.CRATE, 0) + avenues.get(P.BARREL, 0), lots_count["cables"], avenues["cables"]])
	(none[0] as Node).free()
	(lots[0] as Node).free()

	# --- Where they are ---
	var probe := MazeProps.new()
	probe._hash_boxes(layout)
	var on_walls := 0
	var off_walls := 0
	var in_stone := 0
	for piece in layout.pieces(MazePiece.Kind.PROP):
		var out := piece.transform.basis.orthonormalized().z
		if piece.prop in [P.VENT, P.ROUND_VENT, P.CULVERT, P.OUTLET]:
			var lift := Vector3.UP * (0.3 if piece.prop == P.CULVERT else 0.0)
			if probe._solid(piece.position + lift - out * 0.15) and not probe._solid(piece.position + lift + out * 0.3):
				on_walls += 1
			else:
				off_walls += 1
		elif piece.prop in [P.CRATE, P.BARREL]:
			if probe._solid(piece.position + Vector3.UP * 0.3):
				in_stone += 1
	probe.free()
	check("vents, culverts and outlets are on the walls' faces", off_walls == 0 and on_walls > 0, "(%d on, %d off)" % [on_walls, off_walls])
	check("no box or barrel in the stone", in_stone == 0, "(%d)" % in_stone)
	var near_ivy := 0
	for piece in layout.pieces(MazePiece.Kind.PROP):
		if piece.prop in [P.CRATE, P.BARREL]:
			for ivy in layout.pieces(MazePiece.Kind.IVY):
				if Vector2(ivy.position.x - piece.position.x, ivy.position.z - piece.position.z).length() < ivy.width * 0.5 + 0.5 and ivy.position.y < 1.0:
					near_ivy += 1
	check("no heap in front of ivy from the ground", near_ivy == 0, "(%d)" % near_ivy)

	# --- Made ---
	var built := MazeProps.new()
	built.realize(layout)
	root.add_child(built)
	var solid_wanted := 0
	for piece in layout.pieces(MazePiece.Kind.PROP):
		if piece.prop in [P.CRATE, P.BARREL]:
			solid_wanted += 1
	check("a shape for every box and barrel, in one body", built.solid_shapes == solid_wanted and built.body.get_child_count() == solid_wanted, "(%d)" % built.solid_shapes)
	var drawn := built.find_children("*", "GeometryInstance3D", true, false)
	var far_ok := true
	var processing := 0
	for shown: GeometryInstance3D in drawn:
		if shown.visibility_range_end <= 0.0 or shown.visibility_range_end > MazeProps.WIRE_FAR:
			far_ok = false
	for node: Node in built.find_children("*", "", true, false) + [built]:
		if node.is_processing() or node.is_physics_processing():
			processing += 1
	var pieces := layout.pieces(MazePiece.Kind.PROP).size() + layout.pieces(MazePiece.Kind.WIRE).size()
	var squares := {}
	for piece in layout.pieces(MazePiece.Kind.PROP) + layout.pieces(MazePiece.Kind.WIRE):
		squares[MazeProps._square(piece.position)] = true
	# (each kind of prop, the lamps, the cables and the drips: at most one each a square)
	var most := squares.size() * (MazeProps.Prop.size() + 3)
	check("drawn in few draws: one a kind a square", drawn.size() <= most and drawn.size() < pieces / 3, "(%d for %d pieces in %d squares)" % [drawn.size(), pieces, squares.size()])
	check("all lost past the mist (110 to 160 m)", far_ok)
	check("nothing of them processes", processing == 0, "(%d)" % processing)
	built.queue_free()
	layout.queue_free()

	# --- In a round: solid, and the camps and what lies about kept off them ---
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	for i in 5:
		await physics_frame
	main.start_solo()
	for i in 30:
		await physics_frame
	var world = main.world
	var props: MazeProps = world.get_node("Maze").props
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var bumped := 0
	var tried := 0
	for shape: CollisionShape3D in props.body.get_children():
		if tried >= 12:
			break
		var middle := shape.global_position
		var from := middle + Vector3(2.0, 0.0, 0.0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, middle))
		tried += 1
		if not hit.is_empty() and hit["collider"] == props.body:
			bumped += 1
	check("boxes and barrels are solid", tried > 0 and bumped >= tried - 2, "(%d of %d hit)" % [bumped, tried])
	var loot = world.loot
	var played: Maze = world.maze
	var ring_camps := 0
	var on_heaps := 0
	for camp in loot.camps:
		if played.ring_of(played.cell_at(camp.position)) == 1:
			ring_camps += 1
		if props.near_heap(camp.position, 3.0):
			on_heaps += 1
	for id: int in loot.items:
		if props.near_heap(loot.items[id].global_position, 0.2):
			on_heaps += 1
	check("three camps left in the Avenues", ring_camps == 3, "(%d)" % ring_camps)
	check("no camp or loot on a heap", on_heaps == 0, "(%d)" % on_heaps)

	print("props_test: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures else 0)

extends SceneTree
## Pictures of the maze's props (MazeProps) in the first ring, by the game's own
## rules (or the maze editor's, with `editor`): cables strung across a hall from
## under them (one with a lamp, one snapped, one by a vine), a heap of boxes and
## barrels, a vent, an outlet with its stain and puddle, a culvert, a drain and a
## manhole, and a camp.
##
##     godot --path . --audio-driver Dummy --resolution 1280x720 -s res://tools/props_shots.gd -- <folder> [editor]

var main: Node
var camera: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.has("editor"):
		MazeStyle.chosen = MazeStyle.defaults()
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var folder: String = args[0] if args.size() > 0 else "user://props_shots"
	DirAccess.make_dir_recursive_absolute(folder)
	for i in 5:
		await process_frame
	main.start_solo()
	for i in 30:
		await physics_frame
	var world = main.world
	var maze: Maze = world.maze
	var layout: MazeLayout = world.get_node("Maze").layout
	world.dev.to_ring(1)
	for i in 30:
		await physics_frame
	world.player.visible = false
	camera = Camera3D.new()
	camera.fov = 70.0
	world.add_child(camera)
	camera.make_current()
	var in_ring := func(p: Vector3) -> bool: return maze.ring_of(maze.cell_at(p)) == 1
	var wires := layout.pieces(MazePiece.Kind.WIRE).filter(func(w: MazePiece) -> bool: return in_ring.call(w.position))
	var props := layout.pieces(MazePiece.Kind.PROP).filter(func(p: MazePiece) -> bool: return in_ring.call(p.position))
	print("ring 1: %d props, %d cables" % [props.size(), wires.size()])
	# Cables across the hall, seen from under them.
	var lit := wires.filter(func(w: MazePiece) -> bool: return w.lamp)
	var snapped := wires.filter(func(w: MazePiece) -> bool: return w.tails.x > 0.0 and w.position.distance_to(w.bridge_end()) > 8.0)
	var across := wires.filter(func(w: MazePiece) -> bool: return w.tails == Vector2.ZERO and not w.lamp and w.position.distance_to(w.bridge_end()) > 8.0)
	for group: Array in [["lamp", lit], ["snapped", snapped], ["cable", across]]:
		var list: Array = group[1]
		for n in mini(2, list.size()):
			var piece: MazePiece = list[(n * 5) % list.size()]
			var a := piece.position
			var b := piece.bridge_end()
			var middle := (a + b) * 0.5
			var side := (b - a).normalized().cross(Vector3.UP).normalized()
			camera.position = Vector3(middle.x, 1.7, middle.z) + side * 9.0
			camera.look_at(middle - Vector3.UP * 2.0)
			await _shot("%s/%s%d.png" % [folder, group[0], n])
	# The vines strung across with cables by them.
	var strands := layout.pieces(MazePiece.Kind.STRAND)
	var shots := 0
	for strand in strands:
		if shots >= 2:
			break
		for wire in wires:
			if wire.position.distance_to(strand.position) < 6.0 and wire.bridge_end().distance_to(strand.bridge_end()) < 6.0:
				var a := strand.position
				var b := strand.bridge_end()
				var middle := (a + b) * 0.5
				var side := (b - a).normalized().cross(Vector3.UP).normalized()
				camera.position = Vector3(middle.x, 1.7, middle.z) + side * 12.0
				camera.look_at(middle - Vector3.UP * 3.0)
				await _shot("%s/vine%d.png" % [folder, shots])
				shots += 1
				break
	# Things on the walls and floor, at his eye height.
	var P := MazeProps.Prop
	for wanted: Array in [[P.CRATE, "heap", 6.0, 0.6], [P.BARREL, "barrels", 5.0, 0.5], [P.VENT, "vent", 7.0, 0.0], [P.ROUND_VENT, "round_vent", 7.0, 0.0],
			[P.OUTLET, "outlet", 5.0, -1.0], [P.CULVERT, "culvert", 6.0, 0.4], [P.DRAIN, "drain", 3.5, -0.2], [P.MANHOLE, "manhole", 3.5, -0.3]]:
		var of_kind := props.filter(func(p: MazePiece) -> bool: return p.prop == wanted[0])
		for n in mini(2, of_kind.size()):
			var piece: MazePiece = of_kind[(n * 7) % of_kind.size()]
			var out := piece.transform.basis.orthonormalized().z
			out.y = 0.0
			out = out.normalized()
			var side := out.cross(Vector3.UP)
			var foot := Vector3(piece.position.x, maze.ground_height(piece.position), piece.position.z)
			var back: float = wanted[2]
			if piece.prop == P.DRAIN or piece.prop == P.MANHOLE:
				camera.position = foot + out * back + side * 1.5 + Vector3.UP * 1.6
				camera.look_at(foot)
			else:
				camera.position = foot + out * back + side * back * 0.5 + Vector3.UP * 1.6
				camera.look_at(piece.position + Vector3.UP * float(wanted[3]))
			await _shot("%s/%s%d.png" % [folder, wanted[1], n])
	# A camp in the ring.
	var camps: Array = world.loot.camps.filter(func(c: Node3D) -> bool: return in_ring.call(c.position))
	for n in mini(2, camps.size()):
		var camp: Node3D = camps[n]
		# (from whichever side is open)
		var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
		var eye := camp.position + Vector3.UP * 2.2
		camera.position = camp.position + Vector3(6.0, 2.2, 5.0)
		for k in 8:
			var a := k * TAU / 8.0
			var try := eye + Vector3(cos(a), 0.0, sin(a)) * 8.0
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, try + Vector3(cos(a), 0.0, sin(a)))).is_empty():
				camera.position = try
				break
		camera.look_at(camp.position + Vector3.UP * 0.5)
		await _shot("%s/camp%d.png" % [folder, n])
	# Down a hall, from his eye height: what it all looks like together.
	for n in 3:
		var piece: MazePiece = across[(n * 11) % across.size()] if not across.is_empty() else props[n]
		var a := piece.position
		var b := piece.bridge_end() if piece.kind == MazePiece.Kind.WIRE else a + Vector3.RIGHT
		var side := (b - a).normalized().cross(Vector3.UP).normalized()
		var middle := (a + b) * 0.5
		camera.position = Vector3(middle.x, 1.6, middle.z) + side * 30.0
		camera.look_at(Vector3(middle.x, 6.0, middle.z))
		await _shot("%s/hall%d.png" % [folder, n])
	quit()


func _shot(path: String) -> void:
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

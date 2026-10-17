extends SceneTree
## Builds a maze and saves it as a scene to look round in the editor (the game
## builds its mazes as it runs, from the room's seed, so there is nothing to see
## in main.tscn): the walls, terraces, ivy, vines, bridges, trees and grass, the
## sky and light, and three figures in the clearing for scale. Nothing in it runs:
## the scripts are left off, so it is only what was built.
##
##     godot --headless --path . -s res://tools/bake_preview.gd -- [seed] [rings]
##
## Then open res://preview/maze_preview.scn. (It is not used by the game, and is
## left out of the export.)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if args.size() > 0 else Maze.seed_for("LOOK", 1)
	var rings := int(args[1]) if args.size() > 1 else 1
	_bake(seed_value, rings)


func _bake(seed_value: int, rings: int) -> void:
	var preview := Node3D.new()
	preview.name = "MazePreview"
	root.add_child(preview)
	# The sky, mist and sun, as a round has them.
	# (loaded, not named: World uses the autoload Net, which a -s script is compiled before)
	var light: Node3D = load("res://scripts/world.gd").new()
	light.name = "Light"
	preview.add_child(light)
	light._sky()
	var builder := MazeBuilder.new()
	builder.name = "Maze"
	preview.add_child(builder)
	builder.build(Maze.generate(seed_value, rings))
	# Figures for scale, by the middle of the clearing.
	for seat in 3:
		var figure := Figure.new()
		figure.name = "Boy%d" % seat
		preview.add_child(figure)
		figure.place(Vector3(seat * 1.4 - 1.4, 0.0, 2.0), PI)
	# Let everything that builds itself when it comes into the tree do so, then dress them.
	for i in 3:
		await process_frame
	await physics_frame
	for seat in 3:
		var figure: Figure = preview.get_node("Boy%d" % seat)
		Looks.apply(figure.rig, Looks.decode("p%d" % (seat + 3), seat))
	for i in 3:
		await process_frame
	# The vignette is drawn over the screen: it has no place in a scene to look at.
	for layer in preview.find_children("*", "CanvasLayer", true, false):
		layer.get_parent().remove_child(layer)
	_own(preview, preview)
	var scene := PackedScene.new()
	var error := scene.pack(preview)
	if error != OK:
		push_error("could not pack the maze: %d" % error)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://preview")
	error = ResourceSaver.save(scene, "res://preview/maze_preview.scn", ResourceSaver.FLAG_COMPRESS)
	print("saved res://preview/maze_preview.scn (seed %d, %d ring(s)): %s" % [seed_value, rings, "ok" if error == OK else "error %d" % error])
	quit(0 if error == OK else 1)


## Makes every node under `node` belong to the scene, and takes off its script.
func _own(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.set_script(null)
		child.owner = owner_node
		_own(child, owner_node)

extends SceneTree
## The arcade's preview film: a few seconds of the title over the maze, then four
## friends leaving the clearing and running the passages to the light. The boy is
## steered along the way out as a thumb would steer him; the others follow his
## track a little behind. Record it with Movie Maker:
##
##     godot --path . --fixed-fps 30 --write-movie out.avi -s res://tools/attract.gd
##
## (Movie Maker takes the window size from the project: drop an override.cfg with
## [display] window/size/viewport_width=960 and viewport_height=540 in first.)

const TITLE_SECONDS := 3.5
const PLAY_SECONDS := 21.0
const FOLLOW_DELAY := [0.0, 0.7, 1.4, 2.1]

var main: Node
var track: Array = []  # [time, position, velocity, yaw]
var clock := 0.0


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	_run()


func _run() -> void:
	for i in int(TITLE_SECONDS * 30):
		await process_frame
	main._begin([
		{"slot": 0, "look": "p11"}, {"slot": 1, "look": "p27"}, {"slot": 2, "look": "p36"}, {"slot": 3, "look": "p48"},
	], 0, false, Maze.seed_for("FILM", 3))
	var world = main.world
	var maze = world.maze
	var path: Array = maze.path_out(maze.cell_at(Vector3.ZERO))
	var step := 0
	var player = world.player
	while clock < PLAY_SECONDS:
		await process_frame
		clock += 1.0 / 30.0
		# Steer for the next cell on the way out, as a stick would.
		while step < path.size() - 1 and Vector2(player.global_position.x, player.global_position.z).distance_to(
				Vector2(maze.world(path[step]).x, maze.world(path[step]).z)) < 1.2:
			step += 1
		var goal: Vector3 = maze.world(path[step]) if step < path.size() - 1 else maze.world(maze.exit + maze.exit_side * 3)
		var to: Vector3 = goal - player.global_position
		to.y = 0.0
		var basis: Basis = world.camera.global_transform.basis
		var forward := -basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var right := basis.x
		right.y = 0.0
		right = right.normalized()
		var stick := Vector2(to.normalized().dot(right), to.normalized().dot(forward))
		_press(&"move_right", stick.x)
		_press(&"move_left", -stick.x)
		_press(&"move_up", stick.y)
		_press(&"move_down", -stick.y)
		track.append([clock, player.global_position, player.velocity, player.facing_yaw])
		for seat in world.remotes:
			var then: float = clock - FOLLOW_DELAY[seat]
			var at: Array = track[0]
			for entry: Array in track:
				if entry[0] <= then:
					at = entry
			world.remotes[seat].hear(at[1] + Vector3(0.35 * (seat - 2), 0.0, 0.0), at[2], at[3], true)
	quit()


func _press(action: StringName, strength: float) -> void:
	if strength > 0.05:
		Input.action_press(action, clampf(strength, 0.0, 1.0))
	else:
		Input.action_release(action)

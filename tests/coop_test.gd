extends SceneTree
## Two players in one room, end to end, against a rooms server (tools/dev_relay.mjs).
## Run one copy as the host and one as the guest, sharing a file for the room code
## (tools/coop_test.sh does all of this):
##
##     node tools/dev_relay.mjs <scareathon-v3/server> 3111
##     godot --headless --path . -s res://tests/coop_test.gd -- host  <code file> --server=http://127.0.0.1:3111
##     godot --headless --path . -s res://tests/coop_test.gd -- guest <code file> --server=http://127.0.0.1:3111
##
## The host makes the room and starts it once the guest is in. Both check they have
## the same maze and see each other move; each walks out past the exit; both see
## everyone out; the host calls the next maze and both build the same new one.

const TIME_LIMIT := 120.0

var main: Node
var net: Node
var role := "host"
var code_file := ""
var failures := 0
var clock := 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0]
	code_file = args[1]
	main = load("res://main.tscn").instantiate()
	main.testing = true
	root.add_child(main)
	net = root.get_node("Net")
	if role == "host":
		_host()
	else:
		_guest()


func check(what: String, ok: bool, detail := "") -> void:
	print("%s %s: %s %s" % ["PASS" if ok else "FAIL", role, what, detail])
	if not ok:
		failures += 1


func finish() -> void:
	print("COOP %s %s" % [role.to_upper(), "PASSED" if failures == 0 else "FAILED (%d)" % failures])
	quit(failures)


func until(what: String, ready: Callable, limit := 30.0) -> bool:
	var waited := 0.0
	while not ready.call():
		await physics_frame
		waited += 1.0 / 60.0
		clock += 1.0 / 60.0
		if waited > limit or clock > TIME_LIMIT:
			check(what, false, "(timed out)")
			return false
	check(what, true)
	return true


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		clock += 1.0 / 60.0


func _host() -> void:
	await process_frame
	main.make_room()
	if not await until("room made", func() -> bool: return net.code != ""):
		return finish()
	var file := FileAccess.open(code_file, FileAccess.WRITE)
	file.store_string(net.code)
	file.close()
	if not await until("guest joined", func() -> bool: return net.players.size() == 2, 60.0):
		return finish()
	net.start_game()
	await _play()
	await frames(30)
	main.next_round()
	await frames(10)
	print("MAZE %s %d" % [role, main.world.maze.maze_seed])
	# (stay a moment, so the guest hears about the next maze before the host goes)
	await frames(240)
	finish()


func _guest() -> void:
	await process_frame
	var code := ""
	while code == "" and clock < 30.0:
		await frames(15)
		if FileAccess.file_exists(code_file):
			code = FileAccess.get_file_as_string(code_file).strip_edges()
	main._code_typed = code
	main.show_join()
	main._code_typed = code
	main._join_typed()
	if not await until("joined the room", func() -> bool: return net.slot == 1):
		return finish()
	await _play()
	if await until("the next maze", func() -> bool: return main.round_number == 2 and main.world != null):
		print("MAZE %s %d" % [role, main.world.maze.maze_seed])
	finish()


func _play() -> void:
	if not await until("the game started", func() -> bool: return main.screen == "play" and main.world != null):
		return
	var world = main.world
	check("same maze", world.maze.maze_seed == Maze.seed_for(net.code, 1), "(seed %d)" % world.maze.maze_seed)
	check("one other player", world.remotes.size() == 1)
	var other = world.remotes.values()[0]
	var started_at: Vector3 = other.global_position
	# Walk towards the middle of the clearing for a while, and see the other one do so too.
	Input.action_press(&"move_up")
	await frames(90)
	Input.action_release(&"move_up")
	await until("the other player moved", func() -> bool: return other.global_position.distance_to(started_at) > 0.5, 10.0)
	# What hunts the maze: run by the host, followed by the guest.
	var griever = world.griever
	check("the Griever is the host's", griever.puppet == (role == "guest"))
	var griever_from: Vector3 = griever.global_position
	await until("the Griever goes about", func() -> bool: return griever.global_position.distance_to(griever_from) > 1.0, 15.0)
	# Out past the exit (the host first).
	if role == "guest":
		await until("the host got out", func() -> bool: return world.out.has(0), 20.0)
	var past: Vector3 = world.maze.world(world.maze.exit + world.maze.exit_side * 2)
	world.player.global_position = past + Vector3.UP * 0.2
	await until("got out", func() -> bool: return world.out.has(world.slot), 5.0)
	await until("everyone out", func() -> bool: return world.all_out(), 20.0)

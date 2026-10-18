extends SceneTree
## The lonely horse (scripts/enemies/maze_horse.gd on creatures/horse), headless,
## in a bare scene: a maze from MazeBuilder and the boy in it. In turn:
## - every coat and the halter build, and the rig poses every gait and move;
## - it watches him; run at it and it snorts and canters off;
## - come slowly and stand, and touch it (the act button's `workable`): it
##   nickers, and three touches apart and it trusts him and follows;
## - a hunter after someone near it and it bolts at a gallop;
## - a puppet follows its host's trust and calls; the sounds are made.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/horse_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

var stage: Node3D
var maze
var nav
var boy
var failures := 0


func check(what: String, ok: bool, detail := "") -> void:
	print("%s: %s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		failures += 1


func wait(seconds: float, until := Callable()) -> bool:
	for i in int(seconds * 60.0):
		await physics_frame
		if until.is_valid() and until.call():
			return true
	return not until.is_valid()


func _initialize() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	maze = Maze.generate(Maze.seed_for("TEST", 1))
	var builder := MazeBuilder.new()
	builder.name = "Maze"
	stage.add_child(builder)
	builder.build(maze)
	nav = MazeNav.new(maze)
	boy = load("res://player.tscn").instantiate()
	boy.takes_input = false
	stage.add_child(boy)
	boy.add_to_group(&"maze_players")
	_run.call_deferred()


func put_boy(at: Vector3) -> void:
	boy.global_position = at + Vector3.UP * 0.1
	boy.velocity = Vector3.ZERO


func _run() -> void:
	await wait(0.2)
	# --- The look and the moves ---
	var shown: Array = []
	for c in 3:
		var h := Horse.new()
		h.coat = c
		h.haltered = c == 1
		h.sound = false
		h.position = Vector3(c * 3.0, 0.0, -400.0)
		stage.add_child(h)
		shown.append(h)
	await wait(0.2)
	var one: Horse = shown[0]
	check("a horse is built on its model", one.rig != null and one.rig.materials.has("coat") and one.rig.materials.has("mane"))
	one.measure_velocity = false
	for speed: float in [1.4, 3.2, 6.0, 10.0]:
		one.velocity = Vector3(0.0, 0.0, speed)
		var falls := [0]
		var count := func(_leg: int) -> void: falls[0] += 1
		one.rig.footfall.connect(count)
		await wait(1.5)
		one.rig.footfall.disconnect(count)
		check("its hooves come down at %.1f m/s" % speed, falls[0] >= 3, "(%d)" % falls[0])
	one.velocity = Vector3.ZERO
	one.grazing = true
	await wait(2.5)
	check("grazing, its muzzle is down near the ground", one.nose_position().y < one.global_position.y + 0.5, "(%.2f)" % (one.nose_position().y - one.global_position.y))
	one.grazing = false
	one.roll()
	await wait(3.0)
	check("rolling, it is down on the ground", one.rolling() and one.rig._body.global_position.y < one.global_position.y + 0.8, "(%.2f)" % (one.rig._body.global_position.y - one.global_position.y))
	one.whinny()
	one.shake()
	one.nicker()
	check("the sounds are made", Horse.whinny_sound().get_length() > 1.0 and Horse._sound("nicker").get_length() > 0.3)
	for h: Node in shown:
		h.queue_free()

	# --- Wary, then trusting ---
	var cell: Vector2i = nav.lairs(4)[0]
	var at: Vector3 = nav.point(cell)
	var horse := MazeHorse.new()
	horse.maze = maze
	horse.position = at + Vector3.UP * 0.05
	stage.add_child(horse)
	put_boy(at + Vector3(4.0, 0.0, 0.0))
	await wait(2.0, func() -> bool: return horse.mode == MazeHorse.Mode.WATCH)
	check("it watches him", horse.mode == MazeHorse.Mode.WATCH, "(%s)" % MazeHorse.Mode.keys()[horse.mode])
	# (running at it)
	boy.velocity = (horse.global_position - boy.global_position).normalized() * 5.0
	boy.set_physics_process(false)
	var fled := await wait(2.0, func() -> bool: return horse.mode == MazeHorse.Mode.FLEE)
	check("run at, it snorts and canters off", fled)
	boy.set_physics_process(true)
	await wait(4.0, func() -> bool: return horse.mode != MazeHorse.Mode.FLEE)
	# (slowly: he stands by it a while, then touches it three times)
	horse._ease = 1.0
	horse.mode = MazeHorse.Mode.WATCH
	put_boy(horse.global_position + Vector3(1.6, 0.0, 0.0))
	for k in 3:
		horse._touched(boy)
		await wait(1.8)
	check("touched three times apart, it trusts him", horse.trust >= 1.0 and horse.friend == boy, "(%.2f)" % horse.trust)
	put_boy(horse.global_position + Vector3(10.0, 0.0, 0.0))
	await wait(3.0, func() -> bool: return horse.mode == MazeHorse.Mode.FOLLOW)
	check("it follows him", horse.mode == MazeHorse.Mode.FOLLOW, "(%s)" % MazeHorse.Mode.keys()[horse.mode])
	var handle := horse.get_node("Touch")
	check("a hand can reach it (workable)", handle.is_in_group(&"workable") and handle.has_method(&"work"))

	# --- A hunter near ---
	var dog := MazeDog.new()
	dog.maze = maze
	dog.position = horse.global_position + Vector3(5.0, 0.05, 0.0)
	dog.ready.connect(func() -> void: dog.set_physics_process(false); dog.set_process(false))
	stage.add_child(dog)
	dog.chasing = true
	var bolted := await wait(2.0, func() -> bool: return horse.mode == MazeHorse.Mode.FLEE)
	check("a hunter near, it bolts", bolted)
	await wait(1.5)
	check("galloping away", Vector2(horse.velocity.x, horse.velocity.z).length() > 6.0, "(%.1f)" % Vector2(horse.velocity.x, horse.velocity.z).length())
	dog.queue_free()

	# --- A puppet ---
	var copy := MazeHorse.new()
	copy.maze = maze
	copy.puppet = true
	copy.position = at
	stage.add_child(copy)
	await wait(0.2)
	copy.from_bytes(horse.state_bytes())
	await wait(0.3)
	check("a puppet follows its host's trust and mode", is_equal_approx(copy.trust, 1.0) and copy.mode == horse.mode, "(%.2f %s)" % [copy.trust, copy.mode])
	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(1 if failures else 0)

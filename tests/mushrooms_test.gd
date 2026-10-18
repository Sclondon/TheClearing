extends SceneTree
## The mushrooms (MazeMushrooms, driving creatures/mushrooms/), headless, in a
## bare maze from MazeBuilder: a patch grows tufts, shelves (on its cell's
## walls), bonnets and puffballs, and the same in every copy of the game;
## walking past a puffball a couple of metres off leaves it be, treading by it
## or running near it puffs it; spent, it swells back in time; a puppet copy
## puffs the same puffball when the host's does; and a patch costs a handful
## of draws (a MultiMesh a kind).
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/mushrooms_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

class Dummy extends Node3D:
	var facing_yaw := 0.0
	var velocity := Vector3.ZERO


var stage: Node3D
var maze: Maze
var nav: MazeNav
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
	stage.name = "Stage"
	root.add_child(stage)
	maze = Maze.generate(Maze.seed_for("TEST", 1))
	var builder := MazeBuilder.new()
	builder.name = "Maze"
	stage.add_child(builder)
	builder.build(maze)
	nav = MazeNav.new(maze)
	_run.call_deferred()


func patch_at(cell: Vector2i, puppet := false) -> MazeMushrooms:
	var made := MazeMushrooms.new()
	made.maze = maze
	made.puppet = puppet
	made.position = maze.world(cell) + Vector3.UP * 0.05
	stage.add_child(made)
	return made


func _run() -> void:
	var cell: Vector2i = nav.lairs(4)[3]
	var patch := patch_at(cell)
	var grown: MushroomPatch = patch.patch
	var walls := Maze.STEPS.filter(func(s: Vector2i) -> bool: return maze.blocked(cell, s)).size()
	check("a patch grows tufts, bonnets and puffballs", grown.count(MushroomPatch.Kind.HONEY) > 10 and grown.count(MushroomPatch.Kind.STALK) > 0 and grown.puffballs.size() >= 2,
			"(%d honey fungi, %d bonnets, %d puffballs)" % [grown.count(MushroomPatch.Kind.HONEY), grown.count(MushroomPatch.Kind.STALK), grown.puffballs.size()])
	check("and shelves up its cell's walls", walls == 0 or grown.count(MushroomPatch.Kind.BRACKET) > 0, "(%d walls, %d shelves)" % [walls, grown.count(MushroomPatch.Kind.BRACKET)])
	check("each kind is one MultiMesh", grown.find_children("*", "MultiMeshInstance3D", false, false).size() <= 4)
	var twin := patch_at(cell, true)
	twin.from_bytes(patch.state_bytes())
	check("every copy grows the same", twin.patch.puffballs == grown.puffballs and twin.patch.count(MushroomPatch.Kind.HONEY) == grown.count(MushroomPatch.Kind.HONEY))

	var ball := grown.puffballs[0]
	var who := Dummy.new()
	stage.add_child(who)
	who.add_to_group(&"maze_players")
	who.global_position = ball + Vector3(2.2, 0.0, 0.0)
	who.velocity = Vector3(0.0, 0.0, 1.6)
	await wait(1.0)
	check("walking past a puffball 2 m off leaves it be", grown.ripe(0) and patch.puffs == 0)
	who.velocity = Vector3(0.0, 0.0, 4.4)
	var puffed := await wait(1.0, func() -> bool: return patch.puffs > 0)
	check("running past it that near puffs it", puffed and not grown.ripe(0) and patch.cloud.active())
	who.velocity = Vector3.ZERO
	who.global_position = ball + Vector3(30.0, 0.0, 0.0)
	# The copy hears of it
	for i in 3:
		twin.from_bytes(patch.state_bytes())
		await physics_frame
	check("a puppet copy puffs the same puffball when the host's does", not twin.patch.ripe(0) and twin.cloud.active())
	# Treading by another
	var other := grown.puffballs[1]
	who.global_position = other + Vector3(0.7, 0.0, 0.0)
	who.velocity = Vector3(0.0, 0.0, 0.6)
	var trodden := await wait(1.0, func() -> bool: return not grown.ripe(1))
	check("treading close by another puffs it too", trodden)
	who.global_position = ball + Vector3(30.0, 0.0, 0.0)
	patch.regrow_time = 0.5
	patch._regrow_in[0] = 0.5
	var swelled := await wait(12.0, func() -> bool: return grown.ripe(0))
	check("spent, a puffball swells back in time", swelled)
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, patch.state_bytes().size() == MazeEnemy.STATE_SIZE)

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)

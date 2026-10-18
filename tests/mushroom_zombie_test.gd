extends SceneTree
## The mushroom zombies (MazeMushroomZombie, driving creatures/mushroom_zombie/),
## and the mushrooms (MazeMushrooms, creatures/mushrooms/), headless, in a bare
## maze from MazeBuilder:
##
## - a zombie is blind: someone standing in front of it, walking past a few
##   metres off, or creeping past crouched close by is not noticed; someone
##   running, or landing hard, some way off is heard: it stops and listens (the
##   warning), then lurches after them (faster than a walk, slower than a run);
##   go quiet and it goes on to where it heard them, stands listening, and
##   wanders off; near what it hears it lunges, and catches whoever is still
##   there, but not whoever stepped aside; walking into one is felt;
## - its horde near hears its clicking and comes;
## - a puffball puffing near calls it; the puff slows a Player in the cloud and
##   blurs his sight;
## - it takes a creature it hears running (Ecology), and a sleeper of its horde
##   rises out of the ground there in time;
## - a puppet copy listens and lunges as the host's does.
##
##     godot --headless --audio-driver Dummy --path . -s res://tests/mushroom_zombie_test.gd
##
## Ends with PASSED or FAILED (and exits 0 or 1).

## A stand-in for a player.
class Dummy extends Node3D:
	var facing_yaw := 0.0
	var velocity := Vector3.ZERO
	var is_ducking := false


var stage: Node3D
var maze: Maze
var nav: MazeNav
var failures := 0
var caught: Array = []
var hall := Vector2i.ZERO
var along := Vector3.FORWARD


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
	Ecology.put(stage, 9)
	_run.call_deferred()


## A cell with a straight passage of `run` cells on from it.
func find_hall(run: int) -> void:
	for cell: Vector2i in nav.lairs(3):
		for step: Vector2i in Maze.STEPS:
			var ok := true
			for k in run:
				if maze.blocked(cell + step * k, step) or not nav.allowed(cell + step * (k + 1)):
					ok = false
			if ok:
				hall = cell
				along = Vector3(step.x, 0.0, step.y)
				return


func zombie(at: Vector3, puppet := false, sleeper := false, horde := 1) -> MazeMushroomZombie:
	var z := MazeMushroomZombie.new()
	z.maze = maze
	z.puppet = puppet
	z.sleeper = sleeper
	z.horde_id = horde
	z.position = at + Vector3.UP * 0.05
	z.rotation.y = atan2(along.x, along.z)
	stage.add_child(z)
	if not puppet:
		z.caught.connect(func(who: Node3D) -> void: caught.append(who))
	return z


func dummy(at: Vector3) -> Dummy:
	var d := Dummy.new()
	stage.add_child(d)
	d.global_position = at
	d.add_to_group(&"maze_players")
	return d


func clear() -> void:
	for child in stage.get_children():
		if (child is MazeEnemy and not (child as MazeEnemy).dead) or child is Dummy or child is CharacterBody3D and not (child is MazeEnemy):
			child.free()
	caught.clear()


## Moves `who` from `from` towards `to` at `speed` (its velocity set so), a physics frame at a time.
func move(who: Node3D, from: Vector3, to: Vector3, speed: float, until := Callable()) -> void:
	who.global_position = from
	var steps := maxi(int(from.distance_to(to) / speed * 60.0), 1)
	for i in steps:
		who.global_position = from.lerp(to, float(i + 1) / steps)
		who.set(&"velocity", (to - from).normalized() * speed)
		await physics_frame
		if until.is_valid() and until.call():
			break
	who.set(&"velocity", Vector3.ZERO)


func _run() -> void:
	find_hall(3)
	var home: Vector3 = maze.world(hall)
	var side := Vector3(along.z, 0.0, -along.x)
	print("hall %s along %s" % [hall, along])

	# Blind: someone standing in front of it is not noticed; nor walking past; nor creeping past close
	var z := zombie(home)
	z.wander_speed = 0.0
	var who := dummy(home + along * 5.0)
	await wait(2.0)
	check("it does not see someone standing in front of it", z.mode == MazeMushroomZombie.Mode.WANDER, "(%s)" % MazeMushroomZombie.Mode.keys()[z.mode])
	await move(who, home + along * 6.0 + side * 3.0, home - along * 6.0 + side * 3.0, 1.6)
	check("nor hear someone walking past 3 m off", z.mode == MazeMushroomZombie.Mode.WANDER and caught.is_empty())
	who.is_ducking = true
	await move(who, home + along * 6.0 + side * 1.2, home - along * 6.0 + side * 1.2, 1.3)
	who.is_ducking = false
	check("nor someone creeping past crouched 1.2 m off", z.mode == MazeMushroomZombie.Mode.WANDER and caught.is_empty(), "(%s)" % MazeMushroomZombie.Mode.keys()[z.mode])

	# Running some way off is heard: it listens, then lurches after them
	who.global_position = home + along * 11.0
	await move(who, home + along * 11.0, home + along * 9.0, 4.4)
	check("someone running 10 m off is heard: it stops and listens", z.mode == MazeMushroomZombie.Mode.LISTEN and z.figure.doing() == MushroomZombieRig.Act.LISTEN, "(%s)" % MazeMushroomZombie.Mode.keys()[z.mode])
	var hunted := await wait(2.0, func() -> bool: return z.mode == MazeMushroomZombie.Mode.HUNT)
	var start := z.global_position
	await wait(1.0)
	var pace := z.global_position.distance_to(start)
	check("then it lurches at where it heard them, faster than a walk and slower than a run", hunted and pace > 1.8 and pace < 4.4, "(%.2f m in 1 s)" % pace)
	# Gone quiet (they slip off, walking), it goes on to where it heard them, listens there, and wanders off
	who.global_position = home + along * 9.0 + side * 30.0
	var searched := await wait(8.0, func() -> bool: return z.mode == MazeMushroomZombie.Mode.SEARCH)
	check("gone quiet, it goes on to where it heard them and stands there listening", searched and z.global_position.distance_to(home + along * 9.0) < 3.5, "(%.2f m from it)" % z.global_position.distance_to(home + along * 9.0))
	var wandered := await wait(z.search_time + 1.0, func() -> bool: return z.mode == MazeMushroomZombie.Mode.WANDER)
	check("and then wanders off", wandered and caught.is_empty())
	clear()

	# Near what it hears it lunges: whoever stays is caught; whoever steps aside is not
	z = zombie(home)
	z.wander_speed = 0.0
	who = dummy(home + along * 6.0)
	await move(who, home + along * 6.0, home + along * 2.2, 4.4)
	var lunged := await wait(4.0, func() -> bool: return z.mode == MazeMushroomZombie.Mode.GRAB)
	var got := await wait(2.0, func() -> bool: return caught.has(who))
	check("someone who runs up to it and stops is lunged at and caught", lunged and got)
	await wait(3.0)
	clear()
	z = zombie(home)
	z.wander_speed = 0.0
	who = dummy(home + along * 6.0)
	await move(who, home + along * 6.0, home + along * 2.2, 4.4)
	await wait(4.0, func() -> bool: return z.figure.stage() == MushroomZombieRig.Stage.REACH)
	var at := who.global_position
	await move(who, at, at + side * 2.6, 3.0)
	await wait(2.0)
	check("but someone who steps aside as it lunges is not", z.mode != MazeMushroomZombie.Mode.DORMANT and not caught.has(who), "(%s)" % MazeMushroomZombie.Mode.keys()[z.mode])
	clear()

	# A hard landing is heard; walking into it is felt
	z = zombie(home)
	z.wander_speed = 0.0
	who = dummy(home + along * 9.0)
	for i in 10:
		who.velocity = Vector3(0.0, -8.0, 0.0)
		await physics_frame
	who.velocity = Vector3.ZERO
	var landed := await wait(1.0, func() -> bool: return z.mode == MazeMushroomZombie.Mode.LISTEN)
	check("landing hard 9 m off is heard", landed)
	clear()
	z = zombie(home)
	z.wander_speed = 0.0
	who = dummy(home + along * 3.0)
	await wait(0.5)
	await move(who, home + along * 3.0, home + along * 0.7, 0.8)
	var felt := await wait(1.0, func() -> bool: return z.mode != MazeMushroomZombie.Mode.WANDER)
	check("walking into it, however softly, is felt", felt, "(%s)" % MazeMushroomZombie.Mode.keys()[z.mode])
	clear()

	# Its horde hears its clicking
	z = zombie(home)
	z.wander_speed = 0.0
	var other := zombie(home - along * 8.0)
	other.wander_speed = 0.0
	who = dummy(home + along * 12.0)
	await move(who, home + along * 12.0, home + along * 10.0, 4.4)
	var came := await wait(1.0, func() -> bool: return other.mode == MazeMushroomZombie.Mode.LISTEN)
	check("its horde near hears its clicking and listens", came and other.heard_at.distance_to(z.global_position) < 2.0)
	clear()

	# A puffball puffing near calls it; the cloud slows a Player and blurs his sight
	z = zombie(home - along * 10.0)
	z.wander_speed = 0.0
	var patch := MazeMushrooms.new()
	patch.maze = maze
	patch.position = home
	stage.add_child(patch)
	var boy = load("res://player.tscn").instantiate()
	stage.add_child(boy)
	boy.takes_input = false
	boy.add_to_group(&"maze_players")
	var walk_was: float = boy.walk_speed
	var ball: Vector3 = patch.patch.puffballs[0]
	boy.global_position = ball + Vector3(0.6, 0.2, 0.0)
	var puffed := await wait(1.0, func() -> bool: return patch.puffs > 0)
	check("treading next to a puffball puffs it", puffed and not patch.patch.ripe(0))
	await wait(0.4)
	check("and a zombie 10 m off hears it", z.mode == MazeMushroomZombie.Mode.LISTEN and z.heard_at.distance_to(ball) < 1.0, "(%s)" % MazeMushroomZombie.Mode.keys()[z.mode])
	await wait(0.6)
	var veil := SporeVeil.of(self)
	check("breathing its spores, a Player is slowed", boy.walk_speed < walk_was * 0.9, "(walk %.2f, was %.2f)" % [boy.walk_speed, walk_was])
	check("and his sight blurs", veil.amount > 0.2, "(veil %.2f)" % veil.amount)
	boy.global_position = ball + Vector3(25.0, 0.2, 0.0)
	await wait(SporeCloud.LIFETIME)
	check("out of it, he has his speed back", is_equal_approx(boy.walk_speed, walk_was), "(walk %.2f)" % boy.walk_speed)
	boy.free()
	clear()


	# It takes a creature it hears running, and a sleeper of its horde rises there
	z = zombie(home, false, false, 7)
	z.wander_speed = 0.0
	var sleeper := zombie(home - along * 20.0, false, true, 7)
	sleeper.rise_delay = 1.0
	z.rise_delay = 1.0
	await wait(0.3)
	check("a sleeper lies hidden under the ground", sleeper.mode == MazeMushroomZombie.Mode.DORMANT and not sleeper.figure.visible and sleeper.collision_layer == 0)
	var deer := MazeDeer.new()
	deer.maze = maze
	deer.position = home + along * 6.0 + Vector3.UP * 0.05
	stage.add_child(deer)
	for i in 600:
		# (it runs about near it, round and round)
		var round_about := i / 60.0 * 2.0
		deer.global_position = home + Vector3(cos(round_about), 0.0, sin(round_about)) * (1.2 if i > 240 else 4.0) + Vector3.UP * 0.05
		deer.velocity = Vector3(-sin(round_about), 0.0, cos(round_about)) * 4.0
		await physics_frame
		if deer.dead:
			break
	check("it takes a creature it hears running about it", deer.dead, "(%s)" % MazeMushroomZombie.Mode.keys()[z.mode])
	var rose := await wait(6.0, func() -> bool: return sleeper.mode in [MazeMushroomZombie.Mode.RISING, MazeMushroomZombie.Mode.WANDER])
	check("and a sleeper of its horde rises out of the ground there", rose and sleeper.global_position.distance_to(z.global_position) < 4.0 and sleeper.figure.visible, "(%s, %.1f m off)" % [MazeMushroomZombie.Mode.keys()[sleeper.mode], sleeper.global_position.distance_to(z.global_position)])
	clear()

	# A puppet copy listens and lunges as the host's does
	z = zombie(home)
	z.wander_speed = 0.0
	var copy := zombie(home, true)
	who = dummy(home + along * 6.0)
	var listened := false
	var copy_lunged := false
	for i in 300:
		if i < 60:
			who.global_position = (home + along * 6.0).lerp(home + along * 2.0, i / 60.0)
			who.velocity = -along * 4.4
		else:
			who.velocity = Vector3.ZERO
		if i % 6 == 0:
			copy.from_bytes(z.state_bytes())
		await physics_frame
		listened = listened or copy.figure.doing() == MushroomZombieRig.Act.LISTEN
		copy_lunged = copy_lunged or copy.figure.doing() == MushroomZombieRig.Act.LUNGE
	check("a puppet copy listens when the host's does", listened)
	check("and lunges when it does", copy_lunged)
	check("its news is %d bytes" % MazeEnemy.STATE_SIZE, z.state_bytes().size() == MazeEnemy.STATE_SIZE)
	clear()

	print("PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)

class_name MazeEnemies
extends Node3D
## Everything that hunts in one maze: puts them in it, and keeps them in step
## between machines.
##
## `populate(maze, seed)` puts Apophis and packs of mummies in the passages, out
## of the clearing and well away from it, and `add_hunters(style, seed)` the
## rest of what a ring's MazeStyle asks for (ghouls, centipedes, spiders,
## abominations, flesh mounds and amalgams, slime walls, bats, baboons, dogs, aliens, beetles, fish people, angels, giant toads, frog swarms, harpies, boars, chickens, gargoyles, deer, elk, imps and imp swarms, a colossus, coyotes and skinwalkers, tripods: each kind's own
## script is in scripts/enemies/, its look and motion in creatures/). The same maze and seed always give the
## same ones in the same places in the same order, so every machine in a room
## can build the same set without it being sent; then one machine (the host)
## runs them and the rest are puppets (`set_puppet(true)`), fed with what
## `pack()` makes on the host through `unpack()`.
##
## `caught(player, enemy)` is passed on from each of them (only where they are
## not puppets). Players are found in the group `maze_players` unless
## `set_targets` gives them.

signal caught(player: Node3D, enemy: MazeEnemy)

## Every one of them, in the order they were made (the order `pack` sends them in).
var enemies: Array[MazeEnemy] = []
var maze: Maze
var puppet := false

## How mummies go about: kinds of pack, each a list of Mummy.Kind.
const PACKS := [
	[Mummy.Kind.SHAMBLER, Mummy.Kind.SHAMBLER, Mummy.Kind.BRUTE],
	[Mummy.Kind.SHAMBLER, Mummy.Kind.CRAWLER],
	[Mummy.Kind.PRIEST, Mummy.Kind.CHILD, Mummy.Kind.SHAMBLER],
	[Mummy.Kind.ROYAL, Mummy.Kind.SHAMBLER],
	[Mummy.Kind.CRAWLER, Mummy.Kind.CHILD],
]


## Puts them in `plan`: `snakes` Apophises and `packs` packs of mummies, chosen
## and placed by `seed_value`. Keeps clear of the clearing by `away` steps.
func populate(plan: Maze, seed_value: int, packs := 3, snakes := 1, away := 5) -> void:
	maze = plan
	var nav := MazeNav.new(plan)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var lairs := nav.lairs(away)
	if lairs.is_empty():
		lairs = nav.lairs(1)
	var taken: Array[Vector2i] = []
	for i in snakes:
		var ends: Array[Vector2i] = []
		for cell in lairs:
			if nav.dead_end(cell):
				ends.append(cell)
		var from := _far_from(taken, ends if not ends.is_empty() else lairs, rng)
		# He lies with his tail in the dead end and his head some way out of it.
		var cells := _walk_out(from, 3)
		var head: Vector2i = cells.back()
		var facing := cells[cells.size() - 1] - cells[cells.size() - 2] if cells.size() > 1 else Vector2i(0, 1)
		var snake := Apophis.new()
		add(snake, head, atan2(float(facing.x), float(facing.y)), rng.randi())
		taken.append(head)
		taken.append(from)
	for p in packs:
		var kinds: Array = PACKS[(p + rng.randi_range(0, PACKS.size() - 1)) % PACKS.size()]
		var middle := _far_from(taken, lairs, rng)
		taken.append(middle)
		var near: Array[Vector2i] = [middle]
		var steps := nav.field(middle)
		for cell in lairs:
			var d := steps[plan.index(cell)]
			if d > 0 and d <= 2:
				near.append(cell)
		for k in kinds.size():
			var mummy := Mummy.new()
			mummy.kind = kinds[k]
			var cell: Vector2i = near[k % near.size()]
			# (two in one cell stand well apart)
			var round_about := rng.randf_range(0.0, TAU)
			var spot := Vector3(cos(round_about), 0.0, sin(round_about)) * 2.0 * (k / near.size()) if k >= near.size() else Vector3.ZERO
			add(mummy, cell, rng.randf_range(-PI, PI), rng.randi(), spot)


## Puts in the rest of what hunts a ring, as many of each as `style` says
## (MazeStyle, "What hunts it"), each kind where it waits best, as far by the
## passages from the others as can be. Call it after `populate` (the snake and
## the mummies) with the same maze; the same seed gives the same ones.
##
## - Ghouls stand in dead ends, facing out. Centipedes lie in dead ends too.
## - Slime walls fill straight halls, set across them.
## - Flesh mounds and striders wait in halls, as abominations do; amalgams and
##   pairs in any passage.
## - Spiders, abominations and bat colonies wait in any passage well out of the
##   clearing (a spider climbs the nearest high wall; bats roost on one).
## - Fish people lie each in a pool of its own in a hall (as slime walls do),
##   away from the rest.
## - Baboon troops, dogs and aliens go about in packs, put round one cell.
## - Beetle swarms wait in cracks at the foot of a wall, in a dead end and a
##   hall in turn.
## - Angels hang over the middle of a straight hall (where they see furthest).
## - Giant toads squat in dead ends, facing out; a frog swarm's muddy pool is
##   at the end of a dead end too.
## - Harpies are put in hallways and perch on the nearest high wall over one.
## - A boar roots in a dead end or a straight hall, facing out.
## - Chicken flocks forage in straight halls, where people must pass them.
## - Gargoyles are put in halls (a straight run of passage, walls both sides):
##   each crouches on a ledge over it, a terrace's edge or the wall's top.
## - Murders of crows are put in halls and sit along the wall tops over them.
## - A herd of deer stands bunched in one straight hall; a bull elk holds
##   another, facing along it.
## - Gangs of imps are put round one cell and each climbs the nearest wall to
##   perch; an imp swarm's crack is at the foot of a wall in a straight hall.
## - A colossus crouches over the ring on its wall tops, far from the rest, facing round it.
## - Coyotes go about in packs, put round one cell; a skinwalker is put in with
##   a pack (as one of them).
## - A tripod stands over any passage (it walks round the ring over the walls).
func add_hunters(style: MazeStyle, seed_value: int, away := 5) -> void:
	var nav := MazeNav.new(maze)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var lairs := nav.lairs(away)
	if lairs.is_empty():
		lairs = nav.lairs(1)
	var ends: Array[Vector2i] = []
	var halls: Array[Vector2i] = []
	for cell in lairs:
		if nav.dead_end(cell):
			ends.append(cell)
		elif _straight(cell) != Vector2i.ZERO:
			halls.append(cell)
	var taken: Array[Vector2i] = []
	for enemy in enemies:
		taken.append(maze.cell_at(enemy.global_position))
	for i in style.ghouls:
		var cell := _far_from(taken, ends if not ends.is_empty() else lairs, rng)
		taken.append(cell)
		add(MazeGhoul.new(), cell, _facing_out(cell), rng.randi())
	for i in style.centipedes:
		var cell := _far_from(taken, ends if not ends.is_empty() else lairs, rng)
		taken.append(cell)
		add(Centipede.new(), cell, _facing_out(cell), rng.randi())
	for i in style.slime_walls:
		var cell := _far_from(taken, halls if not halls.is_empty() else lairs, rng)
		taken.append(cell)
		var along := _straight(cell)
		if along == Vector2i.ZERO:
			along = Vector2i(0, 1)
		add(MazeSlimeWall.new(), cell, atan2(float(along.x), float(along.y)), rng.randi())
	for i in style.fish_people:
		var cell := _far_from(taken, halls if not halls.is_empty() else lairs, rng)
		taken.append(cell)
		var along := _straight(cell)
		add(MazeFishPerson.new(), cell, atan2(float(along.x), float(along.y)) if along != Vector2i.ZERO else rng.randf_range(-PI, PI), rng.randi())
	for i in style.spiders:
		var cell := _far_from(taken, lairs, rng)
		taken.append(cell)
		add(MazeSpider.new(), cell, rng.randf_range(-PI, PI), rng.randi())
	for i in style.abominations:
		var cell := _far_from(taken, halls if not halls.is_empty() else lairs, rng)
		taken.append(cell)
		add(Abomination.new(), cell, rng.randf_range(-PI, PI), rng.randi())
	for i in style.flesh_mounds:
		var cell := _far_from(taken, halls if not halls.is_empty() else lairs, rng)
		taken.append(cell)
		var mound := MazeFleshMound.new()
		mound.bodies = rng.randi_range(7, 8)
		add(mound, cell, rng.randf_range(-PI, PI), rng.randi())
	for i in style.amalgams:
		var cell := _far_from(taken, lairs, rng)
		taken.append(cell)
		var amalgam := MazeFleshMound.new()
		amalgam.bodies = rng.randi_range(3, 4)
		add(amalgam, cell, rng.randf_range(-PI, PI), rng.randi())
	for i in style.pairs:
		var cell := _far_from(taken, lairs, rng)
		taken.append(cell)
		var pair := MazeFleshMound.new()
		pair.bodies = 2
		add(pair, cell, rng.randf_range(-PI, PI), rng.randi())
	for i in style.striders:
		var cell := _far_from(taken, halls if not halls.is_empty() else lairs, rng)
		taken.append(cell)
		var strider := MazeFleshMound.new()
		strider.bodies = rng.randi_range(5, 6)
		add(strider, cell, rng.randf_range(-PI, PI), rng.randi())
	for i in style.bat_colonies:
		var cell := _far_from(taken, lairs, rng)
		taken.append(cell)
		add(Bats.new(), cell, 0.0, rng.randi())
	for i in style.baboon_troops:
		var troop: Array = MazeBaboon.troop(rng.randi_range(4, 5))
		_add_pack(troop, _far_from(taken, lairs, rng), nav, rng, taken)
	for i in style.dog_packs:
		# (a pack's den is a dead end: they go out from it on the scent)
		var den := _far_from(taken, ends if not ends.is_empty() else lairs, rng)
		_add_pack(MazeDog.pack_of(rng.randi_range(3, 4), rng.randi()), den, nav, rng, taken)
	for i in style.deer_herds:
		# (a herd stands in a straight hall, where it can be seen from far off, facing along it)
		var patch := _far_from(taken, halls if not halls.is_empty() else lairs, rng)
		var herd: Array = MazeDeer.herd_of(rng.randi_range(4, 5), rng.randi())
		_add_herd(herd, patch, rng, taken)
	for i in style.elk:
		# (a bull holds a straight stretch: room to charge down)
		var ground := _far_from(taken, halls if not halls.is_empty() else lairs, rng)
		taken.append(ground)
		var along := _straight(ground)
		if along == Vector2i.ZERO:
			along = Vector2i(0, 1)
		add(MazeElk.new(), ground, atan2(float(along.x), float(along.y)) + (PI if rng.randf() < 0.5 else 0.0), rng.randi())
	for i in style.alien_packs:
		var aliens: Array = []
		for a in rng.randi_range(2, 3):
			aliens.append(Alien.new())
		_add_pack(aliens, _far_from(taken, lairs, rng), nav, rng, taken)
	for i in style.beetle_swarms:
		# (in turn a dead end and a hall: their cracks open in the wall nearest)
		var places: Array[Vector2i] = ends if i % 2 == 0 and not ends.is_empty() else (halls if not halls.is_empty() else lairs)
		var cell := _far_from(taken, places, rng)
		taken.append(cell)
		add(Beetles.new(), cell, 0.0, rng.randi())
	for i in style.angels:
		var cell := _far_from(taken, halls if not halls.is_empty() else lairs, rng)
		taken.append(cell)
		var along := _straight(cell)
		if along == Vector2i.ZERO:
			along = Vector2i(0, 1)
		add(MazeAngel.new(), cell, atan2(float(along.x), float(along.y)), rng.randi())
	for i in style.frogs:
		# (a giant toad squats in a dead end, facing out)
		var cell := _far_from(taken, ends if not ends.is_empty() else lairs, rng)
		taken.append(cell)
		add(MazeFrog.new(), cell, _facing_out(cell), rng.randi())
	for i in style.frog_swarms:
		# (a muddy pool of frogs at the end of a dead end)
		var cell := _far_from(taken, ends if not ends.is_empty() else lairs, rng)
		taken.append(cell)
		add(MazeFrogSwarm.new(), cell, _facing_out(cell), rng.randi())
	for i in style.harpies:
		var cell := _far_from(taken, halls if not halls.is_empty() else lairs, rng)
		taken.append(cell)
		add(MazeHarpy.new(), cell, rng.randf_range(-PI, PI), rng.randi())
	for i in style.boars:
		# (it roots in the mud of a dead end, or of a straight hall it can charge down)
		var cell := _far_from(taken, ends + halls if not (ends + halls).is_empty() else lairs, rng)
		taken.append(cell)
		add(MazeBoar.new(), cell, _facing_out(cell), rng.randi())
	for i in style.chicken_flocks:
		# (a flock forages in a hall, not a dead end, where people must pass it)
		var cell := _far_from(taken, halls if not halls.is_empty() else lairs, rng)
		taken.append(cell)
		add(Chickens.new(), cell, 0.0, rng.randi())
	for i in style.gargoyles:
		var cell := _far_from(taken, halls if not halls.is_empty() else lairs, rng)
		taken.append(cell)
		add(MazeGargoyle.new(), cell, rng.randf_range(-PI, PI), rng.randi())
	for i in style.crow_murders:
		# (a murder sits on the wall tops over a hall, where people pass under it)
		var cell := _far_from(taken, halls if not halls.is_empty() else lairs, rng)
		taken.append(cell)
		add(Crows.new(), cell, 0.0, rng.randi())
	for i in style.imp_gangs:
		# (each finds the nearest wall to where it is put and climbs it)
		var gang: Array = MazeImp.gang(rng.randi_range(3, 4))
		var middle := _far_from(taken, lairs, rng)
		taken.append(middle)
		for k in gang.size():
			var round_about := rng.randf_range(0.0, TAU)
			add(gang[k], middle, rng.randf_range(-PI, PI), rng.randi(), Vector3(cos(round_about), 0.0, sin(round_about)) * 1.5)
	for i in style.imp_swarms:
		# (their crack is at the foot of a wall in a hall: they come down it at you)
		var cell := _far_from(taken, halls if not halls.is_empty() else lairs, rng)
		taken.append(cell)
		add(MazeImpSwarm.new(), cell, 0.0, rng.randi())
	for i in style.colossi:
		var cell := _far_from(taken, lairs, rng)
		taken.append(cell)
		# (facing on round the ring, one way or the other)
		var out := maze.world(cell)
		var round_yaw := atan2(-out.z, out.x) if rng.randf() < 0.5 else atan2(out.z, -out.x)
		add(MazeColossus.new(), cell, round_yaw, rng.randi())
	# Coyote packs go about together; a skinwalker hides in one (one more pack for any without one).
	for i in maxi(style.coyote_packs, style.skinwalkers):
		var pack_now := MazeCoyote.pack_of(rng.randi_range(3, 5), rng.randi())
		var middle := _far_from(taken, lairs, rng)
		_add_pack(pack_now, middle, nav, rng, taken)
		if i < style.skinwalkers:
			var walker := MazeSkinwalker.new()
			walker.pack_id = pack_now[0].pack_id
			add(walker, middle, rng.randf_range(-PI, PI), rng.randi(), Vector3(2.0, 0.0, -2.0))
	for i in style.tripods:
		var cell := _far_from(taken, lairs, rng)
		taken.append(cell)
		add(MazeTripod.new(), cell, rng.randf_range(-PI, PI), rng.randi())


## Puts in the wildlife of the clearing that is run with what hunts (so that
## guests see it where the host does): as many tame coyote packs as `clearing`
## (ClearingStyle, "Wildlife") says, out in the meadow on the diagonals, each
## keeping to its own patch.
func add_wildlife(clearing: ClearingStyle, seed_value: int) -> void:
	if clearing == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in clearing.coyote_packs:
		var round_about := PI * 0.25 + PI * 0.5 * ((i + rng.randi_range(0, 3)) % 4) + rng.randf_range(-0.25, 0.25)
		var home := Vector3(cos(round_about), 0.0, sin(round_about)) * rng.randf_range(130.0, 190.0)
		home.y = maze.ground_height(home)
		var pack_now := MazeCoyote.pack_of(rng.randi_range(2, 4), rng.randi())
		for k in pack_now.size():
			var one := pack_now[k]
			one.tame = true
			one.keep_out_of_clearing = false
			one.home = home
			var spot := home + Vector3(rng.randf_range(-4.0, 4.0), 0.0, rng.randf_range(-4.0, 4.0))
			var cell := maze.cell_at(spot)
			add(one, cell, rng.randf_range(-PI, PI), rng.randi(), spot - maze.world(cell) + Vector3.UP * (maze.ground_height(spot) + 0.3))


## Puts a pack round `middle`: one to a cell within two steps of it, and two
## to a cell (well apart) when there are more of them than cells.
func _add_pack(pack_of: Array, middle: Vector2i, nav: MazeNav, rng: RandomNumberGenerator, taken: Array[Vector2i]) -> void:
	taken.append(middle)
	var near: Array[Vector2i] = [middle]
	var steps := nav.field(middle)
	for cell in nav.lairs(1):
		var d := steps[maze.index(cell)]
		if d > 0 and d <= 2:
			near.append(cell)
	for k in pack_of.size():
		var cell: Vector2i = near[k % near.size()]
		var round_about := rng.randf_range(0.0, TAU)
		var spot := Vector3(cos(round_about), 0.0, sin(round_about)) * 2.5 if k >= near.size() else Vector3.ZERO
		add(pack_of[k], cell, rng.randf_range(-PI, PI), rng.randi(), spot)


## Puts a herd of deer in one cell, loosely bunched, all facing roughly the same way.
func _add_herd(herd: Array, cell: Vector2i, rng: RandomNumberGenerator, taken: Array[Vector2i]) -> void:
	taken.append(cell)
	var along := _straight(cell)
	var yaw := atan2(float(along.x), float(along.y)) if along != Vector2i.ZERO else rng.randf_range(-PI, PI)
	for k in herd.size():
		var round_about := TAU * k / herd.size() + rng.randf_range(-0.4, 0.4)
		var spot := Vector3(cos(round_about), 0.0, sin(round_about)) * rng.randf_range(1.2, 3.2) if k > 0 else Vector3.ZERO
		add(herd[k], cell, yaw + rng.randf_range(-0.8, 0.8), rng.randi(), spot)


## The way out of a dead end (as a yaw), or any way for another cell.
func _facing_out(cell: Vector2i) -> float:
	for s: Vector2i in Maze.STEPS:
		if not maze.blocked(cell, s):
			return atan2(float(s.x), float(s.y))
	return 0.0


## The step a hall runs along through `cell`, if it goes straight through it
## (open both ways along one line and shut both ways across it), else zero.
func _straight(cell: Vector2i) -> Vector2i:
	for s: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		var across := Vector2i(s.y, s.x)
		if not maze.blocked(cell, s) and not maze.blocked(cell, -s) and maze.blocked(cell, across) and maze.blocked(cell, -across):
			return s
	return Vector2i.ZERO


## Puts one in, at `cell` facing `yaw`, `offset` from the middle of the cell.
func add(enemy: MazeEnemy, cell: Vector2i, yaw: float, choices_seed := 0, offset := Vector3.ZERO) -> MazeEnemy:
	enemy.name = "Enemy%d" % enemies.size()
	enemy.maze = maze
	enemy.puppet = puppet
	enemy.seed_choices(choices_seed)
	enemy.position = maze.world(cell) + offset + Vector3.UP * 0.05
	enemy.rotation.y = yaw
	enemies.append(enemy)
	add_child(enemy)
	enemy.caught.connect(_on_caught.bind(enemy))
	return enemy


## Run here (false) or by another machine (true).
func set_puppet(value: bool) -> void:
	puppet = value
	for enemy in enemies:
		enemy.puppet = value


## Who they may go after (empty: the group `maze_players`).
func set_targets(players: Array) -> void:
	for enemy in enemies:
		enemy.targets = players


## All their states, for the host to send: a count, then MazeEnemy.STATE_SIZE bytes each.
func pack() -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(1 + enemies.size() * MazeEnemy.STATE_SIZE)
	data[0] = enemies.size()
	for i in enemies.size():
		var one := enemies[i].state_bytes()
		for b in one.size():
			data[1 + i * MazeEnemy.STATE_SIZE + b] = one[b]
	return data


## Hears what `pack` made (from `offset` in `data`).
func unpack(data: PackedByteArray, offset := 0) -> void:
	if data.size() <= offset:
		return
	var count := mini(data[offset], enemies.size())
	for i in count:
		enemies[i].from_bytes(data, offset + 1 + i * MazeEnemy.STATE_SIZE)


func _on_caught(player: Node3D, enemy: MazeEnemy) -> void:
	caught.emit(player, enemy)
	# (crows near rise and wheel over the place)
	for other in enemies:
		if other is Crows and is_instance_valid(other):
			(other as Crows).saw_catch(player.global_position)


# A cell from `cells` as far by the passages as can be from all of `taken` (and from the clearing), with some chance in it.
func _far_from(taken: Array[Vector2i], cells: Array[Vector2i], rng: RandomNumberGenerator) -> Vector2i:
	var nav := MazeNav.new(maze)
	var best := cells[rng.randi_range(0, cells.size() - 1)]
	var score := -1.0
	var fields: Array[PackedInt32Array] = []
	for cell in taken:
		fields.append(nav.field(cell))
	for cell in cells:
		var nearest := 9999.0
		for steps in fields:
			var d := steps[maze.index(cell)]
			if d >= 0:
				nearest = minf(nearest, d)
		var value := nearest + rng.randf_range(0.0, 3.0)
		if value > score:
			score = value
			best = cell
	return best


# From a cell, `count` steps on along the passage (keeping straight where it can).
func _walk_out(from: Vector2i, count: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [from]
	var came := {from: true}
	var step := Vector2i.ZERO
	for i in count:
		var at: Vector2i = cells.back()
		var pick := Vector2i.ZERO
		for s: Vector2i in Maze.STEPS:
			if maze.blocked(at, s) or came.has(at + s) or maze.in_clearing(at + s) or not maze.inside(at + s):
				continue
			if pick == Vector2i.ZERO or s == step:
				pick = s
		if pick == Vector2i.ZERO:
			break
		step = pick
		cells.append(at + pick)
		came[at + pick] = true
	return cells

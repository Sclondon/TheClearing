class_name MazeEnemies
extends Node3D
## Everything that hunts in one maze: puts them in it, and keeps them in step
## between machines.
##
## `populate(maze, seed)` puts Apophis and packs of mummies in the passages, out
## of the clearing and well away from it, and `add_hunters(style, seed)` the
## rest of what a ring's MazeStyle asks for (ghouls, centipedes, spiders,
## abominations, slime walls, bats, baboons, dogs, aliens, a colossus: each kind's own
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
## - Spiders, abominations and bat colonies wait in any passage well out of the
##   clearing (a spider climbs the nearest high wall; bats roost on one).
## - Baboon troops, dogs and aliens go about in packs, put round one cell.
## - A colossus crouches over the ring on its wall tops, far from the rest, facing round it.
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
	for i in style.spiders:
		var cell := _far_from(taken, lairs, rng)
		taken.append(cell)
		add(MazeSpider.new(), cell, rng.randf_range(-PI, PI), rng.randi())
	for i in style.abominations:
		var cell := _far_from(taken, halls if not halls.is_empty() else lairs, rng)
		taken.append(cell)
		add(Abomination.new(), cell, rng.randf_range(-PI, PI), rng.randi())
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
	for i in style.alien_packs:
		var aliens: Array = []
		for a in rng.randi_range(2, 3):
			aliens.append(Alien.new())
		_add_pack(aliens, _far_from(taken, lairs, rng), nav, rng, taken)
	for i in style.colossi:
		var cell := _far_from(taken, lairs, rng)
		taken.append(cell)
		# (facing on round the ring, one way or the other)
		var out := maze.world(cell)
		var round_yaw := atan2(-out.z, out.x) if rng.randf() < 0.5 else atan2(out.z, -out.x)
		add(MazeColossus.new(), cell, round_yaw, rng.randi())


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

class_name MazeRunners
extends Node3D
## The others in the maze (MazeRunner): puts them in, and keeps them in step
## between machines.
##
## `populate(maze, seed, features)` puts in as many as each built ring's
## MazeStyle says ("Who else is in it": `runners`), each in his own section, in
## a hall away from the clearing and from one another. The same maze and seed
## always give the same ones in the same places, so every machine in a room
## builds the same set; then one machine (the host) runs them and the rest are
## puppets (`set_puppet(true)`), fed with what `pack()` makes there through
## `unpack()`.
##
## Every runner is the same boy as the players, in a shirt of his own (SHIRTS),
## muted and greyer than the players' four so that he reads as one of the others.

## The cut of their trousers (BodyShape.CUTS): plain tapered legs.
const RUNNER_CUT := "slim"
## Their shirts, in turn: a grey, a brown, an off-white, a dark taupe. None of
## them near Inside's red, the faded blue, the mustard or the dull green.
const SHIRTS: Array[Color] = [
	Color(0.46, 0.45, 0.42), Color(0.35, 0.26, 0.19), Color(0.62, 0.6, 0.55), Color(0.25, 0.23, 0.22),
]

## Every one of them, in the order they were made (the order `pack` sends them in).
var runners: Array[MazeRunner] = []
var maze: Maze
var puppet := false
var _ivies: Array[IvyClimb] = []


## Puts them in `plan`, as many in each built ring as its style says, placed by
## `seed_value`; `climbs` is the maze's ivy (MazeFeatures.climbs), some of which
## they climb. `away` keeps them clear of these cells (where the hunters start).
func populate(plan: Maze, seed_value: int, climbs: Array[IvyClimb] = [], away: Array[Vector2i] = []) -> void:
	maze = plan
	_ivies = climbs
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var taken: Array[Vector2i] = away.duplicate()
	for ring in range(1, plan.rings + 1):
		var cells: Array[Vector2i] = []
		for i in plan.size * plan.size:
			var cell := Vector2i(i % plan.size, i / plan.size)
			if plan.ring_of(cell) != ring or plan.solid.has(cell) or plan.entrances.has(cell) or plan.depth_in_ring(cell) < 1:
				continue
			# (in a hall, not shut in: two ways out at least)
			var open := 0
			for step: Vector2i in Maze.STEPS:
				if not plan.blocked(cell, step):
					open += 1
			if open >= 2:
				cells.append(cell)
		if cells.is_empty():
			continue
		for k in plan.styles[ring - 1].runners:
			var best := cells[rng.randi_range(0, cells.size() - 1)]
			var apart := -1
			for tries in 24:
				var cell := cells[rng.randi_range(0, cells.size() - 1)]
				var nearest := 1000
				for other in taken:
					nearest = mini(nearest, absi(cell.x - other.x) + absi(cell.y - other.y))
				if nearest > apart:
					apart = nearest
					best = cell
			taken.append(best)
			add(ring, plan.world(best), rng.randf_range(-PI, PI), rng.randi())


## Puts one in, in section `ring`, at `at` facing `yaw`.
func add(ring: int, at: Vector3, yaw: float, choices_seed := 0) -> MazeRunner:
	var runner := DrivenBoy.make(MazeRunner) as MazeRunner
	runner.name = "Runner%d" % runners.size()
	runner.maze = maze
	runner.ring = clampi(ring, 1, maze.rings)
	runner.puppet = puppet
	runner.seed_choices(choices_seed)
	for ivy in _ivies:
		if ivy.bottom_y() < 0.3 and maze.ring_of(maze.cell_at(MazeRunner._ivy_foot(ivy))) == runner.ring:
			runner.ivies.append(ivy)
	var home := _home(runners.size())
	runner.home_at = home.origin
	runner.home_yaw = home.basis.get_euler().y
	runner.position = at + Vector3.UP * 0.05
	runner.facing_yaw = yaw
	runner.rotation.y = 0.0
	if not puppet:
		runner.add_to_group(&"maze_players")
	runner.add_to_group(&"bridge_weights")
	add_child(runner)
	var look: Dictionary = Looks.decode("", 0)
	look["colours"]["shirt"] = SHIRTS[runners.size() % SHIRTS.size()]
	# (plain tapered legs, not the players' shaped ones: the user found those lumpy on them)
	look["cut"] = RUNNER_CUT
	Looks.apply(runner.get_node(^"Rig") as CharacterRig, look)
	(runner.get_node(^"Rig") as CharacterRig).cap_hand = false
	runner.sprint_speed = 6.0
	Grass.push(runner)
	runners.append(runner)
	return runner


## Where runner `index` is put when caught: in the clearing in front of one of
## its gates, facing it.
func _home(index: int) -> Transform3D:
	var gates: Array = maze.gates[0]
	var way: Array = gates[index % gates.size()]
	var step: Vector2i = way[1]
	var out := Vector3(step.x, 0.0, step.y)
	var side := Vector3(-out.z, 0.0, out.x)
	var at := maze.world(way[0]) - out * 6.0 + side * (2.0 + index / gates.size() * 1.5)
	at.y = maze.ground_height(at) + 0.05
	return Transform3D(Basis(Vector3.UP, atan2(out.x, out.z)), at)


## Run here (false) or by another machine (true).
func set_puppet(value: bool) -> void:
	puppet = value
	for runner in runners:
		runner.puppet = value
		if value:
			runner.remove_from_group(&"maze_players")
		else:
			runner.add_to_group(&"maze_players")


## All their states, for the host to send: a count, then DrivenBoy.STATE_SIZE bytes each.
func pack() -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(1 + runners.size() * DrivenBoy.STATE_SIZE)
	data[0] = runners.size()
	for i in runners.size():
		var one := runners[i].state_bytes()
		for b in one.size():
			data[1 + i * DrivenBoy.STATE_SIZE + b] = one[b]
	return data


## Hears what `pack` made (from `offset` in `data`).
func unpack(data: PackedByteArray, offset := 0) -> void:
	if data.size() <= offset:
		return
	var count := mini(data[offset], runners.size())
	for i in count:
		runners[i].from_bytes(data, offset + 1 + i * DrivenBoy.STATE_SIZE)

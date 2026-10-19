class_name MazeDirector
extends Node
## Keeps the maze about the players inhabited, in waves (the user, 2026-10-19: "the
## maze feels way too empty usually"; "the director should subtly direct monsters
## in the area to fit the waves"; "some roam toward you").
##
## The round's hunters are all put in the maze at the start (MazeEnemies), and
## most are far from anyone and asleep (World._sleep_far). This, run where they
## are run (alone, or the host), each TICK:
## - Keeps a wave going, for the room as one: QUIET (a spell to breathe: few
##   about, and those going off), BUILD (more and more about), PEAK (the most, and
##   coming), then QUIET again. If many are after the players already, the peak is
##   cut short.
## - Tops up each player's surroundings to what the wave wants (`_wanted`), from
##   the sleepers of their own section: one of a kind that goes about (ROAMERS,
##   with the rest of its pack nearby) is put down somewhere BRING_STEPS cells off
##   by the passages, out of everyone's sight, ahead of where the player is going
##   if it can be. Its home is there from then on (MazeNav.home).
## - Steers some of those already about (MazeEnemy.directed, which goal() follows
##   before wandering): toward the player's part of the maze while the wave builds
##   and peaks, away while it is quiet. Only a share of them, and never straight
##   at the player: to cells near them, so that they cross the player's way.

## How often it looks about, seconds.
const TICK := 1.0
## Near a player: awake hunters within this, metres, count as about them.
const NEAR := 80.0
## How far off by the passages a hunter is put down, in cells (14 m each).
const BRING_STEPS := Vector2i(3, 7)
## How far off by the passages those about are sent while it is quiet, in cells.
const LEAVE_STEPS := Vector2i(8, 12)
## Hunters about each player each phase wants: [at the start of it, at the end].
const WANTED := {
	Phase.QUIET: Vector2(1.0, 2.0),
	Phase.BUILD: Vector2(2.0, 5.0),
	Phase.PEAK: Vector2(6.0, 6.0),
}
## How long each phase lasts, seconds: fewest and most.
const LASTS := {
	Phase.QUIET: Vector2(35.0, 60.0),
	Phase.BUILD: Vector2(40.0, 70.0),
	Phase.PEAK: Vector2(20.0, 40.0),
}
## Of those about, the share steered each tick toward the player (building,
## peaking) or away (quiet); and the share of those put down that come looking.
const STEER := {Phase.QUIET: 0.15, Phase.BUILD: 0.12, Phase.PEAK: 0.3}
const COME_LOOKING := 0.4
## How long a steer holds, seconds, if it is not reached first.
const STEER_FOR := 25.0
## Chasing a player, this many or more cut a peak short (and hold off a build).
const TOO_MANY := 4
## Kinds that go about, and so may be brought nearer: not those that belong
## where they are (a spider on its wall, a fish person in its pool, an angel over
## its hall, a colossus on the wall tops, the plants).
const ROAMERS: Array[StringName] = [
	&"Mummy", &"Alien", &"Abomination", &"MazeFleshMound", &"MazeBaboon", &"MazeBear",
	&"MazeBeast", &"MazeBoar", &"MazeCat", &"MazeClown", &"MazeDeinonychus", &"MazeDimetrodon",
	&"MazeDog", &"MazeGnome", &"MazeImp", &"MazeLizardPerson", &"MazeMushroomZombie",
	&"MazeRat", &"MazeSkinwalker", &"MazeTribesman", &"MazeWolf", &"MazeWoodsman",
	&"MazePsychicChild", &"MazeHydra", &"MazeStegosaurus",
]

enum Phase { QUIET, BUILD, PEAK }

var world: Node
var phase := Phase.QUIET
## How far through the phase it is, 0 to 1; and how long the phase is, seconds.
var through := 0.0
var _length := 40.0
var _in := 0.0
var _rng := RandomNumberGenerator.new()
var _nav: MazeNav
## How many were brought nearer and steered, all told (for tests and the dev panel).
var brought := 0
var steered := 0
var last: MazeEnemy
## Why it brought nobody, how often (for tools/director_probe.gd).
var missed := {}


static func put(in_world: Node, seed_value: int) -> MazeDirector:
	var made := MazeDirector.new()
	made.name = "Director"
	made.world = in_world
	made._rng.seed = hash("director/%d" % seed_value)
	made._length = made._rng.randf_range(LASTS[Phase.QUIET].x, LASTS[Phase.QUIET].y)
	in_world.add_child(made)
	return made


func _process(delta: float) -> void:
	through += delta / _length
	if through >= 1.0:
		_next_phase()
	_in -= delta
	if _in > 0.0:
		return
	_in = TICK
	if world == null or world.maze == null or world.enemies == null:
		return
	if _nav == null:
		_nav = MazeNav.new(world.maze)
	var started := Time.get_ticks_usec()
	var players := _players()
	var chasing := 0
	for player: Node3D in players:
		var about := _about(player)
		for one: MazeEnemy in about:
			if one.chasing and one.quarry == player:
				chasing += 1
		if about.size() < roundi(_wanted()) and chasing < TOO_MANY:
			_bring(player, players)
		_steer(player, about)
	if phase == Phase.PEAK and chasing >= TOO_MANY + 2:
		_next_phase()
	worst_tick_ms = maxf(worst_tick_ms, (Time.get_ticks_usec() - started) / 1000.0)


## The longest a look about has taken, milliseconds (for tools/director_probe.gd).
var worst_tick_ms := 0.0


func _next_phase() -> void:
	phase = {Phase.QUIET: Phase.BUILD, Phase.BUILD: Phase.PEAK, Phase.PEAK: Phase.QUIET}[phase]
	through = 0.0
	_length = _rng.randf_range(LASTS[phase].x, LASTS[phase].y)


## How many hunters the wave wants about each player now.
func _wanted() -> float:
	var span: Vector2 = WANTED[phase]
	return lerpf(span.x, span.y, clampf(through, 0.0, 1.0))


## The hunters awake and alive about `player`, run here.
func _about(player: Node3D) -> Array:
	var about := []
	for one: MazeEnemy in world.enemies.enemies:
		if is_instance_valid(one) and not one.dead and not one.puppet and one.can_process() and one.global_position.distance_to(player.global_position) < NEAR:
			about.append(one)
	return about


## Brings a sleeper of `player`'s section (and its pack) to somewhere a few cells
## off from them by the passages, out of everyone's sight.
func _bring(player: Node3D, players: Array) -> void:
	var maze: Maze = world.maze
	var here := maze.cell_at(player.global_position)
	var ring := maze.ring_of(here)
	if ring < 1 or ring > maze.rings:
		missed["not in a section"] = missed.get("not in a section", 0) + 1
		return
	var spot := _spot_near(player, players)
	if spot.x < 0:
		missed["no spot"] = missed.get("no spot", 0) + 1
		return
	var who: MazeEnemy = null
	for one: MazeEnemy in world.enemies.enemies:
		if is_instance_valid(one) and not one.dead and not one.puppet and not one.can_process() \
				and Ecology.kind_of(one) in ROAMERS and maxi(maze.ring_of(maze.cell_at(one.global_position)), 1) == ring:
			who = one
			break
	if who == null:
		missed["no sleeper"] = missed.get("no sleeper", 0) + 1
		return
	# (its pack: those of its kind asleep near it come too)
	var pack := [who]
	var kind := Ecology.kind_of(who)
	for one: MazeEnemy in world.enemies.enemies:
		if one != who and is_instance_valid(one) and not one.dead and not one.puppet and not one.can_process() \
				and Ecology.kind_of(one) == kind and one.global_position.distance_to(who.global_position) < 12.0:
			pack.append(one)
	var middle := maze.world(spot)
	var facing := atan2(player.global_position.x - middle.x, player.global_position.z - middle.z)
	var looking := _rng.randf() < COME_LOOKING
	for k in pack.size():
		var one: MazeEnemy = pack[k]
		var round_about := _rng.randf_range(0.0, TAU)
		var at := middle + (Vector3(cos(round_about), 0.0, sin(round_about)) * _rng.randf_range(1.0, 2.5) if k > 0 else Vector3.ZERO)
		at.y = maze.ground_height(at) + 0.05
		one._put(at, facing + _rng.randf_range(-0.6, 0.6))
		if one.nav:
			one.nav.home = spot
		if looking:
			one.direct(_near_cell(here), STEER_FOR)
	brought += pack.size()
	last = who


## A cell `steps` off from `player` by the passages (BRING_STEPS unless given), in their section, out of
## the clearing, and out of every player's sight; ahead of where they are going if
## it can be. (-1, -1): none.
func _spot_near(player: Node3D, players: Array, steps_off := BRING_STEPS) -> Vector2i:
	var maze: Maze = world.maze
	var here := maze.cell_at(player.global_position)
	var ring := maze.ring_of(here)
	var steps := _nav.field(here)
	var going := Vector3.ZERO
	if player is CharacterBody3D:
		going = (player as CharacterBody3D).velocity
		going.y = 0.0
	var best := Vector2i(-1, -1)
	var best_score := -INF
	# (a look at a few dozen cells at random, not the whole maze)
	for attempt in 60:
		var cell := Vector2i(_rng.randi_range(maxi(here.x - steps_off.y, 0), mini(here.x + steps_off.y, maze.size - 1)),
				_rng.randi_range(maxi(here.y - steps_off.y, 0), mini(here.y + steps_off.y, maze.size - 1)))
		var d := steps[maze.index(cell)]
		if d < steps_off.x or d > steps_off.y or maze.ring_of(cell) != ring or maze.in_clearing(cell):
			continue
		var point := maze.world(cell) + Vector3.UP * 1.2
		var seen := false
		for eye: Node3D in players:
			if _nav.sees(eye.global_position + Vector3.UP * 1.5, point, 160.0):
				seen = true
				break
		if seen:
			continue
		var ahead := (point - player.global_position).normalized().dot(going.normalized()) if going.length() > 0.5 else 0.0
		var score := ahead + _rng.randf() * 0.5
		if score > best_score:
			best_score = score
			best = cell
	return best


## A cell next to or by `here` (where a player is), in the passages, for a hunter to
## come by: near them, not at them.
func _near_cell(here: Vector2i) -> Vector2i:
	var maze: Maze = world.maze
	var options: Array[Vector2i] = []
	for step: Vector2i in Maze.STEPS:
		var next := here + step
		if _nav.allowed(next) and not maze.blocked(here, step):
			options.append(next)
	if options.is_empty():
		return here
	return options[_rng.randi_range(0, options.size() - 1)]


## Steers a share of those about `player` that are going about their own business:
## toward them while the wave builds and peaks, off into the maze while it is quiet.
func _steer(player: Node3D, about: Array) -> void:
	var here: Vector2i = world.maze.cell_at(player.global_position)
	for one: MazeEnemy in about:
		if one.hunting() or one.is_directed() or _rng.randf() > STEER[phase]:
			continue
		if phase == Phase.QUIET:
			# (off into the maze, further than the players are, to come back another time)
			var off := _spot_near(player, [], LEAVE_STEPS)
			if off.x >= 0:
				one.direct(off, STEER_FOR)
		else:
			one.direct(_near_cell(here), STEER_FOR)
		steered += 1


## The people playing: the boy here and the others in the room (not the runners,
## who are in maze_players too, nor the hunters they draw).
func _players() -> Array:
	var people := []
	if is_instance_valid(world.player):
		people.append(world.player)
	for seat in world.remotes:
		if is_instance_valid(world.remotes[seat]):
			people.append(world.remotes[seat])
	return people

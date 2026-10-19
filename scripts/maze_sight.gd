class_name MazeSight
extends RefCounted
## What the camera can see of the square maze, from its plan: the halls are deep
## slots between walls far higher than anyone, so from any spot in them most of
## the maze is out of sight (the user, 2026-10-19: "since most of the hallways you
## cant see too much we can probaly save a lot by culling").
##
## RAYS rays are walked out from the camera across the grid, cell to cell, each
## stopped by the first wall it meets (Maze.blocked); the cells they reach, and
## every cell next to those, are in sight. Worked out again only once the camera
## has gone MOVED metres. Anywhere the plan does not say (the camera up over the
## walls, the round sections, the desert, no maze), everything is in sight.
##
##     if MazeSight.hidden(maze, global_position): ...   # nobody here sees it

const RAYS := 120
## How far a ray goes, metres (the mist hides what is further).
const REACH := 200.0
## How far the camera goes before what it sees is worked out again, metres.
const MOVED := 3.0
## Within this of the camera, everything is in sight, metres.
const NEAR := 25.0
## Over this high above the ground anything may be seen over the walls, metres.
const HIGH := 6.0

static var _maze: Maze
static var _from := Vector3.INF
static var _frame := -1
## Cell index -> true, for those in sight; empty: everything is in sight.
static var _seen := {}
static var _all := true
static var _eye := Vector3.ZERO
## Counted up each time what is in sight is worked out again.
static var version := 0


## Whether `point` (on the ground in `maze`) is out of the camera's sight.
static func hidden(maze: Maze, point: Vector3) -> bool:
	if maze == null:
		return false
	_look(maze)
	if _all:
		return false
	if point.distance_squared_to(_eye) < NEAR * NEAR:
		return false
	if point.y > maze.ground_height(point) + HIGH:
		return false
	var cell := maze.cell_at(point)
	if not maze.inside(cell) or maze.ring_of(cell) < 1:
		return false
	return not _seen.has(maze.index(cell))


## Works out what is in sight, if the camera has moved far enough (once a frame at most).
static func _look(maze: Maze) -> void:
	var frame := Engine.get_process_frames()
	if frame == _frame and maze == _maze:
		return
	_frame = frame
	var tree := Engine.get_main_loop() as SceneTree
	var camera := tree.root.get_camera_3d() if tree else null
	if camera == null:
		_all = true
		return
	var eye := camera.global_position
	_eye = eye
	if maze == _maze and eye.distance_squared_to(_from) < MOVED * MOVED:
		return
	_maze = maze
	_from = eye
	version += 1
	_seen.clear()
	_all = true
	var cell := maze.cell_at(eye)
	if maze.round_rings != null and maxf(absf(eye.x), absf(eye.z)) > maze.extent() * 0.5:
		return
	if not maze.inside(cell):
		return
	var ring := maze.ring_of(cell)
	if ring > maze.styles.size():
		return
	# (up over the walls round it, it sees over them)
	var low := maze.maze_wall_height(ring) if ring >= 1 else maze.inner_height(1)
	if eye.y > maze.ground_height(eye) + low - 2.0:
		return
	_all = false
	var size := maze.size
	var middle := (size - 1) * 0.5
	# (in cells, each cell k from k - 0.5 to k + 0.5)
	var start := Vector2(eye.x / Maze.CELL + middle + 0.5, eye.z / Maze.CELL + middle + 0.5)
	var reach := REACH / Maze.CELL
	var east := maze.east
	var south := maze.south
	var reached := {}
	for r in RAYS:
		var angle := TAU * r / RAYS
		var way := Vector2(cos(angle), sin(angle))
		var at := Vector2i(floori(start.x), floori(start.y))
		var step := Vector2i(1 if way.x > 0.0 else -1, 1 if way.y > 0.0 else -1)
		var delta := Vector2(absf(1.0 / way.x) if way.x != 0.0 else INF, absf(1.0 / way.y) if way.y != 0.0 else INF)
		var next := Vector2(((at.x + 1 - start.x) if step.x > 0 else (start.x - at.x)) * delta.x,
				((at.y + 1 - start.y) if step.y > 0 else (start.y - at.y)) * delta.y)
		reached[at.x + at.y * size] = true
		while true:
			var across_x := next.x < next.y
			var t := next.x if across_x else next.y
			if t > reach:
				break
			var to := at + (Vector2i(step.x, 0) if across_x else Vector2i(0, step.y))
			if to.x < 0 or to.y < 0 or to.x >= size or to.y >= size:
				break
			# (the wall between: east of the westerly cell, south of the northerly)
			var wall: int
			if across_x:
				wall = east[mini(at.x, to.x) + at.y * size]
			else:
				wall = south[at.x + mini(at.y, to.y) * size]
			if wall == 1:
				break
			at = to
			reached[at.x + at.y * size] = true
			if across_x:
				next.x += delta.x
			else:
				next.y += delta.y
	# (and every cell next to one in sight: what stands in a doorway, or comes round a corner)
	for index: int in reached:
		var x := index % size
		var y := index / size
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if x + dx >= 0 and y + dy >= 0 and x + dx < size and y + dy < size:
					_seen[x + dx + (y + dy) * size] = true


## How many cells are in sight now (-1: all), for probes.
static func seen_count() -> int:
	return -1 if _all else _seen.size()


## Works out what is in sight now (if the camera has moved far enough); then
## `version`, `everything()` and `seen()` say what.
static func look(maze: Maze) -> void:
	if maze:
		_look(maze)


## Whether everything is in sight (the plan says nothing where the camera is).
static func everything() -> bool:
	return _all


## The cells in sight (Maze.index -> true), when not everything is.
static func seen() -> Dictionary:
	return _seen


## Where the camera was when it was last asked.
static func eye() -> Vector3:
	return _eye

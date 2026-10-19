@tool
class_name Ponds
extends Node3D
## Standing water in the maze's halls: ponds lying in a hall, from a puddle to
## water he wades in to his waist, a few deep enough to swim, and stretches of
## hall flooded from wall to wall; and the flooded way in to the clearing's
## marsh gate (ClearingStyle.Entrance.MARSH), which goes on through the gate's
## slot in the wall and spills into the hall beyond.
##
## `lay_out` chooses them from the maze's seed, as each section's MazeStyle says
## ("Water"), and puts them down as pond pieces (MazePiece.Kind.POND) of a
## MazeLayout, so that they can be moved and resized by hand; `read` gives them
## back as the maze's plan has them (Maze.ponds), which lowers the ground under
## them (Maze.ground_height, `ground_of`) for everything that stands on it.
## `realize` builds them:
## - the ground under each, a mesh of points a metre apart in the ground's own
##   material, with a heightmap of the same to walk on (MazeBuilder cuts the
##   flat ground away over them: `holes`, `cut`);
## - one sheet of water (a Pool, so that he wades, swims, splashes and leaves
##   rings) over each area of ponds that touch at the same level;
## - stone under the foot of any wall standing in the water (the walls stand
##   on the ground's level, and the water's floor is lower);
## - schools of fish (FishSchool) in some.
## Far from the camera, the water and the fish do nothing (`_process` wakes
## those near, twice a second); the fish are not drawn past FishSchool.SEEN.

## The ground under the water: a point every this many metres. (Ponds lie on
## whole metres, so that it fits.)
const STEP := 1.0
## How wide the bank of a pond is at most, metres (narrower in a small one).
const BANK := 2.2
## How high a hall pond's water stands, under the level of the ground.
const LEVEL := -0.05
## The water and the fish within this many metres of the camera are woken.
const WAKE := 70.0
const FISH_WAKE := 48.0
## How deep the stone goes under the foot of a wall standing in the water.
const SKIRT := 2.2

## Every area of water made (Pool), and every school of fish.
var pools: Array[Pool] = []
var schools: Array[FishSchool] = []
## What stands on the ground under the water: the heightmaps and skirts.
var floors: StaticBody3D
## How many ponds were built.
var count := 0

var _maze: Maze
var _check := 0.0
var _wall_looks := {}

static var _noise: FastNoiseLite


# --- The plan ---

## The ponds laid out in `layout` (its pond pieces), as Maze.ponds has them:
## each {rect (x, z), level, depth, round, fish, seed}.
static func read(layout: MazeLayout) -> Array:
	var found: Array = []
	for piece in layout.pieces(MazePiece.Kind.POND):
		var size := piece.size * piece.scale.abs()
		var at := piece.position
		found.append({
			"rect": Rect2(at.x - size.x * 0.5, at.z - size.z * 0.5, size.x, size.z),
			"level": at.y,
			"depth": size.y,
			"round": piece.length,
			"fish": int(piece.width),
			"seed": absi(hash(Vector2i(roundi(at.x), roundi(at.z)))) % 997,
		})
	return found


## [square of Maze.CELL metres, from the origin] -> the ponds over it.
static func index(list: Array) -> Dictionary:
	var cells := {}
	for pond: Dictionary in list:
		var rect: Rect2 = pond.rect
		for j in range(floori(rect.position.y / Maze.CELL), floori(rect.end.y / Maze.CELL) + 1):
			for i in range(floori(rect.position.x / Maze.CELL), floori(rect.end.x / Maze.CELL) + 1):
				var key := Vector2i(i, j)
				if not cells.has(key):
					cells[key] = []
				cells[key].append(pond)
	return cells


## How high the ground is under `pond` at `point` (x, z): level with the ground
## round it at its edge, going down over its bank (raggedly, but for the flooded
## way through the marsh gate, which is square) to its floor. INF off it.
static func ground_of(pond: Dictionary, point: Vector2) -> float:
	var rect: Rect2 = pond.rect
	if point.x < rect.position.x or point.y < rect.position.y or point.x > rect.end.x or point.y > rect.end.y:
		return INF
	var half := rect.size * 0.5
	var round: float = minf(pond.round, minf(half.x, half.y))
	var q := (point - rect.get_center()).abs() - (half - Vector2(round, round))
	# (how far in from its edge, its corners rounded)
	var inside := -(Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - round)
	if inside <= 0.0:
		return 0.0
	var bank := minf(BANK, minf(half.x, half.y) * 0.6)
	var rim := smoothstep(0.0, 0.5, inside)
	var depth: float = pond.depth
	if round > 0.0:
		var noise := _noise_of()
		var shift: float = pond.seed * 31.7
		var n := noise.get_noise_2d(point.x + shift, point.y - shift) * 0.5 + 0.5
		var m := noise.get_noise_2d(point.x * 0.45 - shift, point.y * 0.45 + 70.0) * 0.5 + 0.5
		inside += (n - 0.5) * bank * 1.1
		depth *= 0.82 + 0.36 * m
	var sunk := smoothstep(0.0, bank, inside) * rim
	return lerpf(0.0, pond.level - depth, sunk)


static func _noise_of() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.seed = 4242
		_noise.frequency = 0.22
		_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	return _noise


## Where the flat ground is cut away for the ponds of `plan` (x, z).
static func holes(plan: Maze) -> Array[Rect2]:
	var found: Array[Rect2] = []
	for pond: Dictionary in plan.ponds:
		found.append(pond.rect)
	return found


## `parts` (rects) with `cut_out` taken out of them: what is left, as rects.
static func cut(parts: Array[Rect2], cut_out: Array[Rect2]) -> Array[Rect2]:
	var left := parts.duplicate()
	for hole in cut_out:
		var next: Array[Rect2] = []
		for part: Rect2 in left:
			var over := part.intersection(hole)
			if not over.has_area():
				next.append(part)
				continue
			# (the strips above and below the hole, the whole width, then left and right of it)
			if over.position.y > part.position.y:
				next.append(Rect2(part.position, Vector2(part.size.x, over.position.y - part.position.y)))
			if over.end.y < part.end.y:
				next.append(Rect2(Vector2(part.position.x, over.end.y), Vector2(part.size.x, part.end.y - over.end.y)))
			if over.position.x > part.position.x:
				next.append(Rect2(Vector2(part.position.x, over.position.y), Vector2(over.position.x - part.position.x, over.size.y)))
			if over.end.x < part.end.x:
				next.append(Rect2(Vector2(over.end.x, over.position.y), Vector2(part.end.x - over.end.x, over.size.y)))
		left = next
	return left


## The flat ground over `parts` (rects at level 0), in `material`: one mesh.
static func flat(parts: Array[Rect2], material: Material) -> MeshInstance3D:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	for part in parts:
		var a := Vector3(part.position.x, 0.0, part.position.y)
		var b := Vector3(part.end.x, 0.0, part.position.y)
		var c := Vector3(part.end.x, 0.0, part.end.y)
		var d := Vector3(part.position.x, 0.0, part.end.y)
		for corner: Vector3 in [a, b, c, a, c, d]:
			points.append(corner)
			normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shown := MeshInstance3D.new()
	shown.name = "Flat"
	shown.mesh = mesh
	shown.material_override = material
	return shown


## In the editor, what a pond piece `size` across shows: a sheet of grey water
## with a box as deep as it is under it.
static func sheet(size: Vector3) -> Node3D:
	var shown := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	shown.mesh = box
	shown.position.y = -size.y * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.32, 0.34, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shown.material_override = material
	return shown


# --- Laying them out ---

## Lays out the standing water of `maze` as pond pieces of `layout`, after its
## walls and ways up are laid out (it keeps clear of what stands on the ground):
## the flooded way through the marsh gate, then each section's, as its style says.
## Only in the sections in `zones` (ring -> true), if any are given (the marsh
## gate's is the first section's), each with numbers of its own.
static func lay_out(layout: MazeLayout, maze: Maze, zones: Dictionary = {}) -> void:
	var rngs := {}
	var blocks := _footprints(layout)
	var taken := {}
	if zones.is_empty() or zones.has(1):
		var was := layout.laying_zone
		layout.laying_zone = 1
		_flood_gate(layout, maze, blocks, taken)
		layout.laying_zone = was
	for i in maze.size * maze.size:
		var cell := Vector2i(i % maze.size, i / maze.size)
		var ring := maze.ring_of(cell)
		if ring < 1 or ring > maze.rings or ring > maze.styles.size() or maze.entrances.has(cell) or maze.solid.has(cell) or taken.has(cell):
			continue
		if not zones.is_empty() and not zones.has(ring):
			continue
		if not rngs.has(ring):
			rngs[ring] = RandomNumberGenerator.new()
			(rngs[ring] as RandomNumberGenerator).seed = hash("ponds/%d/%d" % [maze.maze_seed, ring])
		var rng: RandomNumberGenerator = rngs[ring]
		var style: MazeStyle = maze.styles[ring - 1]
		if style.round_section or rng.randf() >= style.pond_share:
			continue
		var flooded := rng.randf() < style.flooded_hall_share
		var cells := _stretch(maze, cell, style.hallway_diameter_cells, rng.randi_range(2, style.flooded_hall_length) if flooded else 1, taken, rng)
		if cells.is_empty():
			continue
		var rect := _hall_rect(maze, cells)
		if cells.size() <= style.hallway_diameter_cells:
			flooded = false
		if not flooded:
			# (a pond lying in the hall, not the whole of it)
			var size := rect.size * Vector2(rng.randf_range(0.45, 0.85), rng.randf_range(0.45, 0.85))
			rect = Rect2(rect.position + (rect.size - size) * Vector2(rng.randf(), rng.randf()), size)
		rect = _clear_of(rect, blocks, 0.6)
		rect = _whole(rect)
		if rect.size.x < 3.0 or rect.size.y < 3.0:
			continue
		for each in cells:
			taken[each] = true
		var depth := rng.randf_range(style.pond_depth_range.x, style.pond_depth_range.y)
		if rng.randf() < style.swim_pond_share and minf(rect.size.x, rect.size.y) >= 6.0:
			depth = style.swim_pond_depth * rng.randf_range(0.9, 1.1)
		var fish := style.fish_per_school if depth >= FishSchool.SHALLOWEST and rng.randf() < style.fish_share else 0
		var round := 3.0 if flooded else minf(rect.size.x, rect.size.y) * 0.45
		_put(layout, rect, LEVEL, depth, round, fish)


static func _put(layout: MazeLayout, rect: Rect2, level: float, depth: float, round: float, fish: int) -> void:
	var middle := rect.get_center()
	layout.add_piece(MazePiece.Kind.POND, Transform3D(Basis.IDENTITY, Vector3(middle.x, level, middle.y)),
		{"size": Vector3(rect.size.x, depth, rect.size.y), "length": round, "width": float(fish)})


## The cells of a pond from `cell`: across its hall (as wide as `across` cells),
## and `long` rows along it, all open to each other and free (none if the cell
## is not in a hall open both ways along it, for a long one).
static func _stretch(maze: Maze, cell: Vector2i, across: int, long: int, taken: Dictionary, rng: RandomNumberGenerator) -> Array[Vector2i]:
	# (along: a way that is open from the cell, the way the hall runs)
	var ways: Array[Vector2i] = []
	for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		if not maze.blocked(cell, step) or not maze.blocked(cell, -step):
			ways.append(step)
	if ways.is_empty():
		ways.append(Vector2i(1, 0))
	var along: Vector2i = ways[rng.randi() % ways.size()]
	var side := Vector2i(along.y, along.x)
	var free := func(c: Vector2i) -> bool:
		return maze.inside(c) and maze.ring_of(c) == maze.ring_of(cell) and not maze.entrances.has(c) and not maze.solid.has(c) and not taken.has(c)
	# Across the hall.
	var row: Array[Vector2i] = [cell]
	for way: Vector2i in [side, -side]:
		var at := cell
		while row.size() < across and not maze.blocked(at, way) and free.call(at + way):
			at += way
			row.append(at)
	# And along it, a row at a time, while the whole row is open on.
	var cells: Array[Vector2i] = row.duplicate()
	var rows := 1
	var last := row
	while rows < long:
		var next: Array[Vector2i] = []
		for c in last:
			if maze.blocked(c, along) or not free.call(c + along):
				next.clear()
				break
			next.append(c + along)
		if next.is_empty():
			break
		# (the row open across, as the first is)
		for k in range(1, next.size()):
			if maze.blocked(next[k - 1], next[k] - next[k - 1]):
				next.clear()
				break
		if next.is_empty():
			break
		cells.append_array(next)
		last = next
		rows += 1
	return cells


## The floor of the hall over `cells`: their squares, less the walls round them.
static func _hall_rect(maze: Maze, cells: Array[Vector2i]) -> Rect2:
	var rect := Rect2()
	for i in cells.size():
		var cell := cells[i]
		var middle := maze.world(cell)
		var low := Vector2(middle.x, middle.z) - Vector2.ONE * Maze.CELL * 0.5
		var high := Vector2(middle.x, middle.z) + Vector2.ONE * Maze.CELL * 0.5
		for step: Vector2i in Maze.STEPS:
			if maze.blocked(cell, step):
				var thick := maze.wall_thick(cell, step) * 0.5
				if step.x > 0: high.x -= thick
				elif step.x < 0: low.x += thick
				elif step.y > 0: high.y -= thick
				else: low.y += thick
		var square := Rect2(low, high - low)
		rect = square if i == 0 else rect.merge(square)
	return rect


## Where whatever stands on the ground stands (walls, piers, ledges, terraces,
## buttresses), as rects (x, z), in squares of Maze.CELL: [square] -> rects.
static func _footprints(layout: MazeLayout) -> Dictionary:
	var squares := {}
	for kind: MazePiece.Kind in [MazePiece.Kind.WALL, MazePiece.Kind.PIER, MazePiece.Kind.TERRACE]:
		for piece in layout.pieces(kind):
			if piece.position.y > 0.5:
				continue
			var rect := _footprint(piece)
			for j in range(floori(rect.position.y / Maze.CELL), floori(rect.end.y / Maze.CELL) + 1):
				for i in range(floori(rect.position.x / Maze.CELL), floori(rect.end.x / Maze.CELL) + 1):
					var key := Vector2i(i, j)
					if not squares.has(key):
						squares[key] = []
					squares[key].append(rect)
	return squares


static func _footprint(piece: MazePiece) -> Rect2:
	var where := piece.box_transform()
	var half := piece.box_size() * 0.5
	var rect := Rect2()
	var first := true
	for corner: Vector3 in [Vector3(-half.x, 0, -half.z), Vector3(half.x, 0, -half.z), Vector3(-half.x, 0, half.z), Vector3(half.x, 0, half.z)]:
		var p := where * corner
		rect = Rect2(Vector2(p.x, p.z), Vector2.ZERO) if first else rect.expand(Vector2(p.x, p.z))
		first = false
	return rect


static func _near(blocks: Dictionary, rect: Rect2) -> Array:
	var found := {}
	for j in range(floori(rect.position.y / Maze.CELL), floori(rect.end.y / Maze.CELL) + 1):
		for i in range(floori(rect.position.x / Maze.CELL), floori(rect.end.x / Maze.CELL) + 1):
			for footprint: Rect2 in blocks.get(Vector2i(i, j), []):
				found[footprint] = true
	return found.keys()


## Whether something stands on the ground at `point` (x, z).
static func _stands(blocks: Dictionary, point: Vector2) -> bool:
	for footprint: Rect2 in blocks.get(Vector2i(floori(point.x / Maze.CELL), floori(point.y / Maze.CELL)), []):
		if footprint.has_point(point):
			return true
	return false


## `rect`, cut back (from whichever side leaves the most of it) to keep `room`
## metres clear of everything standing on the ground.
static func _clear_of(rect: Rect2, blocks: Dictionary, room: float) -> Rect2:
	for footprint: Rect2 in _near(blocks, rect.grow(room)):
		var f := footprint.grow(room)
		if not f.intersects(rect) or not rect.has_area():
			continue
		var options: Array[Rect2] = []
		if f.end.x < rect.end.x:
			options.append(Rect2(Vector2(f.end.x, rect.position.y), Vector2(rect.end.x - f.end.x, rect.size.y)))
		if f.position.x > rect.position.x:
			options.append(Rect2(rect.position, Vector2(f.position.x - rect.position.x, rect.size.y)))
		if f.end.y < rect.end.y:
			options.append(Rect2(Vector2(rect.position.x, f.end.y), Vector2(rect.size.x, rect.end.y - f.end.y)))
		if f.position.y > rect.position.y:
			options.append(Rect2(rect.position, Vector2(rect.size.x, f.position.y - rect.position.y)))
		var best := Rect2()
		for option in options:
			if option.get_area() > best.get_area():
				best = option
		rect = best
	return rect


## `rect` shrunk to whole metres.
static func _whole(rect: Rect2) -> Rect2:
	var low := rect.position.ceil()
	var high := rect.end.floor()
	return Rect2(low, (high - low).max(Vector2.ZERO))


## The flooded way in to the marsh gate goes on through the gate's slot in the
## wall (as deep as ClearingStyle.marsh_flood_depth, at the marsh's level) and
## spills into the hall beyond, a pond of its own there across the hall.
static func _flood_gate(layout: MazeLayout, maze: Maze, blocks: Dictionary, taken: Dictionary) -> void:
	var look := maze.clearing_style
	if look == null or look.marsh_flood_depth <= 0.0:
		return
	var way := look.entrance(ClearingStyle.Entrance.MARSH)
	if way.is_empty():
		return
	var gate: Vector2 = way[0]
	var out: Vector2 = -(way[1] as Vector2)
	var side := out.orthogonal()
	# (how wide the slot is: felt for from its middle, a little way in)
	var inside := gate + out * 3.0
	var half := 0.25
	while half < 8.0 and not _stands(blocks, inside + side * half) and not _stands(blocks, inside - side * half):
		half += 0.25
	# (and how far it runs through the wall, to where neither side is walled)
	var mouth := 3.0
	while mouth < 200.0 and (_stands(blocks, gate + out * mouth + side * (half + 1.0)) or _stands(blocks, gate + out * mouth - side * (half + 1.0))):
		mouth += 0.5
	# (from where the marsh's own water ends, at the wall)
	var marsh := look.marsh_rect()
	var start := 0.0
	while start < 20.0 and marsh.has_point(gate + out * start):
		start += 0.25
	var slot := Rect2(gate + out * start, Vector2.ZERO)
	for point: Vector2 in [gate + out * start + side * (half + 2.5), gate + out * start - side * (half + 2.5), gate + out * (mouth + 7.0) + side * (half + 2.5), gate + out * (mouth + 7.0) - side * (half + 2.5)]:
		slot = slot.expand(point)
	slot = _whole(slot.grow(0.49))
	_put(layout, slot, ClearingStyle.MARSH_LEVEL, look.marsh_flood_depth, 0.0, 0)
	# The hall beyond: across it, and a cell either way along it.
	var cell := maze.cell_at(Vector3((gate + out * (mouth + 3.0)).x, 0.0, (gate + out * (mouth + 3.0)).y))
	if not maze.inside(cell) or maze.ring_of(cell) < 1 or maze.ring_of(cell) > maze.styles.size():
		return
	var style: MazeStyle = maze.styles[maze.ring_of(cell) - 1]
	var along := Vector2i(roundi(side.x), roundi(side.y))
	var cells: Array[Vector2i] = [cell]
	for way_along: Vector2i in [along, -along]:
		if not maze.blocked(cell, way_along) and maze.ring_of(cell + way_along) == maze.ring_of(cell) and not maze.solid.has(cell + way_along):
			cells.append(cell + way_along)
	# (across the hall, as wide as it is)
	var deep := Vector2i(roundi(out.x), roundi(out.y))
	var row := cells.duplicate()
	for k in range(1, style.hallway_diameter_cells):
		var next: Array[Vector2i] = []
		for c: Vector2i in row:
			if not maze.blocked(c, deep) and maze.ring_of(c + deep) == maze.ring_of(cell):
				next.append(c + deep)
		cells.append_array(next)
		row = next
	var rect := _whole(_clear_of(_hall_rect(maze, cells), blocks, 0.6))
	for each in cells:
		taken[each] = true
	if rect.size.x >= 3.0 and rect.size.y >= 3.0:
		_put(layout, rect, ClearingStyle.MARSH_LEVEL, look.marsh_flood_depth, 3.0, style.fish_per_school)


# --- Building them ---

## Builds the ponds of `plan` (Maze.ponds), laid out as `pieces` (for the walls
## standing in their water), their ground in `material`. In the maze editor's
## preview (`preview`), plain sheets for the water and no fish.
func realize(plan: Maze, pieces: MazeLayout, material: Material, preview := false) -> void:
	_maze = plan
	count = plan.ponds.size()
	floors = StaticBody3D.new()
	floors.name = "Floors"
	for pond: Dictionary in plan.ponds:
		_floor(pond, material)
	_skirts(pieces)
	add_child(floors)
	if count == 0:
		return
	for area: Array in _areas(plan.ponds):
		_water(area, preview)
	if preview:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("fish/%d" % plan.maze_seed)
	for k in plan.ponds.size():
		var pond: Dictionary = plan.ponds[k]
		if pond.fish <= 0:
			continue
		var rect: Rect2 = pond.rect
		var level: float = pond.level
		var depth := func(p: Vector2) -> float: return level - _maze.ground_height(Vector3(p.x, 0.0, p.y))
		var pool := _pool_over(rect.get_center(), level)
		var school := FishSchool.put(self, rect.grow(-0.5), level, depth, pond.fish, rng.randi(), pool)
		if school:
			schools.append(school)


# The ground under one pond: a mesh of points STEP apart over its rect (as
# Maze.ground_height has it: where ponds meet, the lower), and a heightmap.
func _floor(pond: Dictionary, material: Material) -> void:
	var rect: Rect2 = pond.rect
	var across := maxi(roundi(rect.size.x / STEP) + 1, 2)
	var down := maxi(roundi(rect.size.y / STEP) + 1, 2)
	var heights := PackedFloat32Array()
	heights.resize(across * down)
	var points := PackedVector3Array()
	points.resize(across * down)
	for j in down:
		for i in across:
			var at := rect.position + Vector2(i, j) * STEP
			var y := minf(_maze.ground_height(Vector3(at.x, 0.0, at.y)), 0.0)
			heights[i + j * across] = y
			points[i + j * across] = Vector3(at.x, y, at.y)
	var normals := PackedVector3Array()
	normals.resize(across * down)
	for j in down:
		for i in across:
			var dx := heights[mini(i + 1, across - 1) + j * across] - heights[maxi(i - 1, 0) + j * across]
			var dz := heights[i + mini(j + 1, down - 1) * across] - heights[i + maxi(j - 1, 0) * across]
			normals[i + j * across] = Vector3(-dx, 2.0 * STEP, -dz).normalized()
	var order := PackedInt32Array()
	order.resize((across - 1) * (down - 1) * 6)
	var k := 0
	for j in down - 1:
		for i in across - 1:
			var a := i + j * across
			order[k] = a
			order[k + 1] = a + 1
			order[k + 2] = a + across
			order[k + 3] = a + 1
			order[k + 4] = a + across + 1
			order[k + 5] = a + across
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = order
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shown := MeshInstance3D.new()
	shown.name = "Floor"
	shown.mesh = mesh
	shown.material_override = material
	shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shown)
	# (in heightmap units, a point every metre: STEP is 1)
	var shape := HeightMapShape3D.new()
	shape.map_width = across
	shape.map_depth = down
	shape.map_data = heights
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(rect.position.x + (across - 1) * STEP * 0.5, 0.0, rect.position.y + (down - 1) * STEP * 0.5)
	floors.add_child(collider)


# Stone under the foot of every wall standing in water (the flooded gate's slot,
# and the clearing's wall along the flooded way in to it), down past the floor.
func _skirts(pieces: MazeLayout) -> void:
	var wet: Array[Rect2] = []
	for pond: Dictionary in _maze.ponds:
		wet.append(pond.rect)
	var flood := _maze.clearing_style.marsh_flood_rect() if _maze.clearing_style else Rect2()
	if flood.has_area():
		wet.append(flood)
	if wet.is_empty():
		return
	var tools := {}
	for kind: MazePiece.Kind in [MazePiece.Kind.WALL, MazePiece.Kind.PIER, MazePiece.Kind.TERRACE]:
		for piece in pieces.pieces(kind):
			if piece.position.y > 0.5:
				continue
			var foot := _footprint(piece)
			for area in wet:
				var under := foot.intersection(area)
				if not under.has_area():
					continue
				var look := MazeBuilder.surface_of(piece)
				if not tools.has(look):
					var tool := SurfaceTool.new()
					tool.begin(Mesh.PRIMITIVE_TRIANGLES)
					tools[look] = tool
				var middle := Vector3(under.get_center().x, -SKIRT * 0.5, under.get_center().y)
				var size := Vector3(under.size.x, SKIRT, under.size.y)
				MazeBuilder.box(tools[look], middle, size)
				var shape := BoxShape3D.new()
				shape.size = size
				var collider := CollisionShape3D.new()
				collider.shape = shape
				collider.position = middle
				floors.add_child(collider)
	for look: Wall.Look in tools:
		if not _wall_looks.has(look):
			_wall_looks[look] = Wall.material_for(look, true)
		var shown := MeshInstance3D.new()
		shown.name = "Skirt"
		shown.mesh = (tools[look] as SurfaceTool).commit()
		shown.material_override = _wall_looks[look]
		shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shown)


## The ponds in areas of water: those that touch or overlap at the same level
## are one sheet of water. As lists of ponds.
static func _areas(list: Array) -> Array:
	var group := range(list.size())
	var find := func(i: int) -> int:
		while group[i] != i:
			i = group[i]
		return i
	for a in list.size():
		for b in range(a + 1, list.size()):
			if absf(list[a].level - list[b].level) < 0.001 and (list[a].rect as Rect2).grow(0.01).intersects(list[b].rect):
				group[find.call(a)] = find.call(b)
	var areas := {}
	for i in list.size():
		var root: int = find.call(i)
		if not areas.has(root):
			areas[root] = []
		areas[root].append(list[i])
	return areas.values()


# One sheet of water over an area of ponds: still, murky and grey, showing the
# overcast sky.
func _water(area: Array, preview: bool) -> void:
	var rect: Rect2 = area[0].rect
	var deepest := 0.0
	for pond: Dictionary in area:
		rect = rect.merge(pond.rect)
		deepest = maxf(deepest, pond.depth - pond.level)
	var level: float = area[0].level
	if preview:
		var sheet := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = rect.size
		sheet.mesh = plane
		sheet.position = Vector3(rect.get_center().x, level, rect.get_center().y)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.2, 0.24, 0.24, 0.8)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.1
		sheet.material_override = material
		add_child(sheet)
		return
	var pool := Still.new()
	pool.name = "Water"
	pool.size = Vector3(rect.size.x, deepest + 1.0, rect.size.y)
	pool.position = Vector3(rect.get_center().x, level, rect.get_center().y)
	pool.look = {
		"shallow": Color(0.19, 0.21, 0.19),
		"deep": Color(0.04, 0.05, 0.048),
		"foam": Color(0.3, 0.31, 0.27),
		"sky": Color(0.64, 0.67, 0.68),
		"depth_range": 1.1,
		"alpha_shallow": 0.5,
		"mirror": 0.6,
		"caustics": 0.0,
		"swell_height": 0.004,
		"lines": 0.22,
		"glint": 0.0,
		"foam_width": 0.07,
		"foam_ragged": 0.8,
		"foam_drift": 0.1,
		"sides": false,
	}
	pool.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(pool)
	pools.append(pool)


func _pool_over(point: Vector2, level: float) -> Pool:
	# (by where each stands in this node, which may not be in the world yet)
	for pool in pools:
		var local := Vector2(point.x - pool.position.x, point.y - pool.position.z)
		if absf(pool.position.y - level) < 0.001 and absf(local.x) <= pool.size.x * 0.5 and absf(local.y) <= pool.size.z * 0.5:
			return pool
	return null


# --- Waking what is near ---

func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.5
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null or Engine.is_editor_hint():
		return
	var eye := camera.global_position
	var flat := Vector2(eye.x, eye.z)
	for pool in pools:
		var size := Vector2(pool.size.x, pool.size.z)
		var rect := Rect2(Vector2(pool.position.x, pool.position.z) - size * 0.5, size)
		var near := _apart(rect, flat) < WAKE
		var awake := pool.process_mode != Node.PROCESS_MODE_DISABLED
		if near != awake:
			pool.process_mode = Node.PROCESS_MODE_INHERIT if near else Node.PROCESS_MODE_DISABLED
		if near:
			(pool as Still).watch_who_is_about()
	for school: Node in get_tree().get_nodes_in_group(FishSchool.GROUP):
		var fish := school as FishSchool
		var near := _apart(fish.area, flat) < FISH_WAKE
		if near != fish.is_processing():
			fish.set_process(near)


static func _apart(rect: Rect2, point: Vector2) -> float:
	var nearest := point.clamp(rect.position, rect.end)
	return nearest.distance_to(point)


## A Pool that does not look through the whole of the world for what to watch
## when it is made (there are many): Ponds has it watch whoever is about while
## it is awake.
class Still extends Pool:
	func _ready() -> void:
		add_to_group(&"water")
		water = Water.new()
		water.size = size
		water.banded = Settings.world_banded
		for setting: String in look:
			water.set(setting, look[setting])
		add_child(water)

	func watch_who_is_about() -> void:
		if water == null:
			return
		for body: Node in get_tree().get_nodes_in_group(&"bridge_weights"):
			if body is Player and not water.watches(body):
				water.watch(body, Player.UNDER_DEPTH, 1.0)
		for thing: Node in get_tree().get_nodes_in_group(&"throwable"):
			if thing is RigidBody3D and not water.watches(thing):
				water.watch(thing, 0.2, 0.35)

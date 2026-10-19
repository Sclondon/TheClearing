class_name Wilds
extends Node3D
## Builds what is in the desert ring's forest, swamp and plains quarters
## (WildLands says where everything is) near the camera only: the quarters are
## far too big to build all at once (some sixty hectares each).
##
## Each square of WildLands.SQUARE metres is built in two layers as the camera
## comes near enough (nearest first, a little each frame, see FILL_BUDGET), and
## let go again once it is well past: its ground (the swamp's hummocks and the
## plains' hills, a mesh and a heightmap to walk on) and its things (pines,
## snags, logs, rocks, plants, bulrushes, lily pads and mist, each kind one
## MultiMesh in the square, seen only out to where the mist has it; trunks,
## logs and rocks with shapes to bump into, all put in their body before it
## goes into the world). Over all of it, built at once but filled near the
## camera by themselves: the swamp's water (a Pool over each swamp quarter) and
## its sedges and reeds, and the plains' grass (GameCommon's Grass).
##
## Add it, then `realize(lands, ground_material)`. It must stay at the origin.

## How long a frame may spend building squares, microseconds (at least one is
## built a frame while any are wanted).
const FILL_BUDGET := 2500
## How near the camera each layer of a square of each biome is built, metres
## ([ground, things]; 0 for none): past this the mist has them.
const REACH := {
	DesertStyle.Biome.FOREST: [0.0, 230.0],
	DesertStyle.Biome.SWAMP: [320.0, 200.0],
	DesertStyle.Biome.PLAINS: [400.0, 260.0],
}
## A layer is let go once the camera is this much further than its reach.
const SLACK := 80.0
## Past this the pines are drawn plainer, with no shadow.
const TREE_NEAR := 55.0
## How far off the plants, bulrushes, lily pads and logs are seen.
const PLANTS_FAR := 90.0
const RUSHES_FAR := 80.0
const PADS_FAR := 60.0
const LOGS_FAR := 150.0
const ROCK_VARIANTS := 4
## How the camera must move before the squares wanted are worked out again.
const REPLAN_STEP := 6.0

enum Layer { GROUND, THINGS }

var lands: WildLands
var ground_material: Material
## The swamps' water (one Pool over each), and the grass fields.
var pools: Array[Pool] = []
var fields: Array[Grass] = []

var _squares := {}
var _built := {}
var _queue: Array = []
var _looked_from := Vector3.INF
var _pine: PineTree
var _plain_pine: PineTree

static var _meshes := {}
static var _hulls := {}
static var _rock_material: ShaderMaterial
static var _mossy_material: ShaderMaterial
static var _wood_material: StandardMaterial3D
static var _mist_material: ShaderMaterial
static var _rush_material: ShaderMaterial
static var _pad_material: StandardMaterial3D


func realize(wild: WildLands, material: Material) -> void:
	lands = wild
	ground_material = material
	for square in lands.squares():
		_squares[square] = lands.biomes_in(square)
	var has := {}
	for side in WildLands.SIDES:
		has[lands.look.biome_of(side)] = true
	if has.has(DesertStyle.Biome.FOREST):
		_pine = PineTree.new()
		_pine.height = lands.look.forest_tree_height
		_pine.trunk_radius = 0.26
		_pine.crown_base = 0.32
		_pine.spread = 0.36
		_pine.droop = 0.5
		_pine.needles_inner = Color(0.08, 0.16, 0.12)
		_pine.needles_outer = Color(0.17, 0.28, 0.2)
		_pine.tips = Color(0.27, 0.36, 0.25)
		_pine.bark = Color(0.24, 0.19, 0.15)
		_pine.seed = lands.seed_value % 1000 + 17
		_plain_pine = _pine.simple()
		for v in 2:
			_pine.mesh(v)
			_plain_pine.mesh(v)
	for side in WildLands.SIDES:
		var biome := lands.look.biome_of(side)
		var rect := _quarter_rect(Vector2(side))
		if biome == DesertStyle.Biome.SWAMP:
			_swamp_water(lands.pools[side])
			_swamp_grass(rect)
		elif biome == DesertStyle.Biome.PLAINS:
			_plains_grass(rect)
	_cornfields()


## The rectangle (x, z) round the quarter on side `side`.
func _quarter_rect(side: Vector2) -> Rect2:
	var plan := lands.plan
	var across := Vector2(-side.y, side.x) * plan.inner_radius * sqrt(0.5)
	return Rect2(side * plan.square_half - across, Vector2.ZERO).expand(side * plan.square_half + across).expand(side * plan.inner_radius + across).expand(side * plan.inner_radius - across)


func _swamp_water(rect: Rect2) -> void:
	var level := lands.water_level()
	var water := Pool.new()
	water.name = "SwampWater"
	water.size = Vector3(rect.size.x, level + 1.0, rect.size.y)
	water.position = Vector3(rect.get_center().x, level, rect.get_center().y)
	# (grey and murky as the clearing's marsh, a scum of duckweed on it)
	water.look = {
		"shallow": Color(0.16, 0.19, 0.14),
		"deep": Color(0.04, 0.05, 0.04),
		"foam": Color(0.16, 0.2, 0.1),
		"sky": Color(0.6, 0.63, 0.63),
		"depth_range": 0.7,
		"alpha_shallow": 0.65,
		"mirror": 0.55,
		"caustics": 0.0,
		"swell_height": 0.004,
		"lines": 0.15,
		"glint": 0.0,
		"foam_width": 0.1,
		"foam_ragged": 0.8,
		"foam_drift": 0.22,
		"sides": false,
	}
	add_child(water)
	pools.append(water)


func _swamp_grass(rect: Rect2) -> void:
	var look := lands.look
	var height := func(p: Vector2) -> float: return lands.ground_at(p) + MazeBuilder.HILL_LIFT
	fields.append(Grass.field(self, rect, 0.9, {
		"mask": lands.sedge_at,
		"height": height,
		"ground": Color(0.1, 0.12, 0.07),
		"blade_height": look.swamp_sedge_height,
		"blade_width": 0.024,
		"lean": 0.22,
		"body": Color(0.1, 0.13, 0.065),
		"tip": Color(0.27, 0.28, 0.15),
		"dry": Color(0.33, 0.3, 0.17),
		"dryness": 0.6,
		"translucency": 0.08,
		"flowers": 0.0,
		"seed": lands.seed_value % 1000 + 41,
	}))
	if look.swamp_reeds <= 0.0:
		return
	fields.append(Grass.field(self, rect, 0.8, {
		"mask": lands.reed_at,
		"height": height,
		"ground": Color(0.1, 0.12, 0.07),
		"blade_height": look.swamp_sedge_height * 1.8,
		"blade_width": 0.03,
		"lean": 0.12,
		"body": Color(0.12, 0.15, 0.08),
		"tip": Color(0.31, 0.3, 0.17),
		"dry": Color(0.38, 0.34, 0.2),
		"dryness": 0.45,
		"translucency": 0.1,
		"flowers": 0.0,
		"push_bend": 1.0,
		"seed": lands.seed_value % 1000 + 42,
	}))


func _plains_grass(rect: Rect2) -> void:
	var look := lands.look
	if look.plains_grass_density <= 0.0:
		return
	fields.append(Grass.field(self, rect, look.plains_grass_density, {
		"mask": lands.plains_grass_at,
		"height": func(p: Vector2) -> float: return lands.ground_at(p) + MazeBuilder.HILL_LIFT,
		"ground": Color(0.2, 0.22, 0.13),
		"blade_height": look.plains_grass_height,
		"lean": 0.3,
		"body": Color(0.17, 0.21, 0.1),
		"tip": Color(0.36, 0.37, 0.22),
		"dry": Color(0.42, 0.39, 0.25),
		"dryness": 0.6,
		"translucency": 0.08,
		"flowers": 0.0,
		"seed": lands.seed_value % 1000 + 43,
	}))


## The plains' cornfields (WildLands.cornfields, Corn): ragged all round, on the
## hills, round the rocks. Filled near the camera by themselves.
var corn: Corn


func _cornfields() -> void:
	var found := lands.cornfields()
	if found.is_empty():
		return
	corn = Corn.new()
	corn.name = "Corn"
	corn.seed = lands.seed_value % 1000 + 44
	var ground := func(p: Vector2) -> float: return lands.ground_at(p) + MazeBuilder.HILL_LIFT
	var clear := func(p: Vector2) -> float: return 0.0 if lands.under_rock(p) or lands.margin_at(p) < WildLands.WALL_MARGIN + 1.0 else 1.0
	for field: Array in found:
		corn.add_patch(field[0], Corn.OPEN_ALL, field[1], ground, [], clear)
	add_child(corn)
	corn.build()


# --- Near the camera ------------------------------------------------------------

## Builds every layer wanted within `radius` metres of `point` now (as the camera
## coming near does, a few a frame): where he is put down.
func fill_near(point: Vector3, radius: float) -> void:
	_plan(point)
	for job: Array in _queue.duplicate():
		if job[1] <= radius:
			_fill(job[0])
	_looked_from = Vector3.INF


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var eye := camera.global_position
	if eye.distance_squared_to(_looked_from) > REPLAN_STEP * REPLAN_STEP:
		_looked_from = eye
		_plan(eye)
	var started := Time.get_ticks_usec()
	while not _queue.is_empty():
		var job: Array = _queue.pop_back()
		if _built.has(job[0]):
			continue
		_fill(job[0])
		if Time.get_ticks_usec() - started > FILL_BUDGET:
			break


## Which layers of which squares are wanted for the camera at `eye`: those not
## built yet go in the queue (the nearest last, to be taken first), and those
## well out of reach are let go.
func _plan(eye: Vector3) -> void:
	var at := Vector2(eye.x, eye.z)
	var furthest := 0.0
	for biome: int in REACH:
		furthest = maxf(furthest, maxf(REACH[biome][0], REACH[biome][1]))
	var middle := Vector2i((at / WildLands.SQUARE).floor())
	var reach := ceili(furthest / WildLands.SQUARE) + 1
	var wanted: Array = []
	for j in range(middle.y - reach, middle.y + reach + 1):
		for i in range(middle.x - reach, middle.x + reach + 1):
			var square := Vector2i(i, j)
			if not _squares.has(square):
				continue
			var d := _distance(square, at)
			if d > furthest:
				continue
			for layer in 2:
				if d <= _reach(square, layer) and not _built.has(Vector3i(i, j, layer)):
					wanted.append([Vector3i(i, j, layer), d])
	wanted.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	_queue = wanted
	for key: Vector3i in _built.keys():
		var square := Vector2i(key.x, key.y)
		if _distance(square, at) > _reach(square, key.z) + SLACK:
			var node: Node = _built[key]
			if is_instance_valid(node):
				node.queue_free()
			_built.erase(key)


## How near the camera a square's layer is built (the furthest of its biomes').
func _reach(square: Vector2i, layer: int) -> float:
	var most := 0.0
	for biome: int in _squares[square]:
		most = maxf(most, REACH[biome][layer])
	return most


static func _distance(square: Vector2i, at: Vector2) -> float:
	var rect := Rect2(Vector2(square) * WildLands.SQUARE, Vector2.ONE * WildLands.SQUARE)
	return at.distance_to(Vector2(clampf(at.x, rect.position.x, rect.end.x), clampf(at.y, rect.position.y, rect.end.y)))


func _fill(key: Vector3i) -> void:
	var square := Vector2i(key.x, key.y)
	var node := _ground(square) if key.z == Layer.GROUND else _things(square)
	node.name = "%s_%d_%d" % ["Ground" if key.z == Layer.GROUND else "Things", key.x, key.y]
	add_child(node)
	_built[key] = node


## How many layers are built now.
func built_count() -> int:
	return _built.size()


# --- A square's ground ------------------------------------------------------------

## The ground over a square: a mesh of its grid (WildLands.grid), drawn in the
## ground's own material, only where it stands up off the level ground (which
## is the rest), and a heightmap of the same to walk on.
func _ground(square: Vector2i) -> Node3D:
	var made := Node3D.new()
	var heights := lands.grid(square)
	var step := lands.step_of(square)
	var across := roundi(WildLands.SQUARE / step) + 1
	var origin := Vector2(square) * WildLands.SQUARE
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	points.resize(across * across)
	normals.resize(across * across)
	var raised := false
	for j in across:
		for i in across:
			var at := i + j * across
			var h := heights[at]
			raised = raised or h > 0.001
			points[at] = Vector3(origin.x + i * step, h + MazeBuilder.HILL_LIFT, origin.y + j * step)
			var dx := heights[mini(i + 1, across - 1) + j * across] - heights[maxi(i - 1, 0) + j * across]
			var dz := heights[i + mini(j + 1, across - 1) * across] - heights[i + maxi(j - 1, 0) * across]
			normals[at] = Vector3(-dx, 2.0 * step, -dz).normalized()
	if not raised:
		return made
	var order := PackedInt32Array()
	for j in across - 1:
		for i in across - 1:
			var a := i + j * across
			if heights[a] <= 0.001 and heights[a + 1] <= 0.001 and heights[a + across] <= 0.001 and heights[a + across + 1] <= 0.001:
				continue
			# (split from (1, 0) to (0, 1), as the heightmap is)
			order.append_array([a, a + 1, a + across, a + 1, a + across + 1, a + across])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = order
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shown := MeshInstance3D.new()
	shown.mesh = mesh
	shown.material_override = ground_material
	# (too low to throw shadows worth the drawing, and it would shade itself in stripes)
	shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	made.add_child(shown)
	var body := StaticBody3D.new()
	var shape := HeightMapShape3D.new()
	shape.map_width = across
	shape.map_depth = across
	var data := PackedFloat32Array()
	data.resize(heights.size())
	for i in heights.size():
		data[i] = heights[i] / step
	shape.map_data = data
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.scale = Vector3.ONE * step
	collider.position = Vector3(origin.x + WildLands.SQUARE * 0.5, 0.0, origin.y + WildLands.SQUARE * 0.5)
	body.add_child(collider)
	made.add_child(body)
	return made


# --- A square's things --------------------------------------------------------------

func _things(square: Vector2i) -> Node3D:
	var made := Node3D.new()
	var c := lands.contents(square)
	var body := StaticBody3D.new()
	body.name = "Body"
	var far := _reach(square, Layer.THINGS) - 10.0
	# Pines: whole near, plainer and with no shadow further off.
	if not c.trees.is_empty():
		var by_variant := {}
		for tree: Array in c.trees:
			if not by_variant.has(tree[1]):
				by_variant[tree[1]] = []
			by_variant[tree[1]].append(tree[0])
			var foot: Vector3 = (tree[0] as Transform3D).origin
			_cylinder(body, Transform3D(Basis.IDENTITY, foot + Vector3.UP * 4.0), tree[2], 8.0)
		for variant: int in by_variant:
			var near := _multi(made, _pine.mesh(variant), _pine._material(), by_variant[variant], [], 0.0, TREE_NEAR, true)
			near.visibility_range_end_margin = 10.0
			var plain := _multi(made, _plain_pine.mesh(variant), _plain_pine._material(), by_variant[variant], [], TREE_NEAR, far, false)
			plain.visibility_range_begin_margin = 10.0
	# Dead trees.
	if not c.snags.is_empty():
		var by_variant := {}
		for snag: Array in c.snags:
			if not by_variant.has(snag[1]):
				by_variant[snag[1]] = []
			by_variant[snag[1]].append(snag[0])
			var at: Transform3D = snag[0]
			var tall := minf(at.basis.y.length(), 8.0)
			_cylinder(body, Transform3D(Basis.IDENTITY, at.origin + Vector3.UP * tall * 0.5), snag[2], tall)
		for variant: int in by_variant:
			_multi(made, snag_mesh(variant), wood_material(), by_variant[variant], [], 0.0, far, true)
	# Fallen logs.
	if not c.logs.is_empty():
		var placed := []
		for log: Array in c.logs:
			var at: Transform3D = log[0]
			placed.append(at)
			var along := at.basis.x.normalized()
			# (a cylinder stands up its y: turned to lie along the log)
			var side := along.cross(Vector3.UP).normalized()
			_cylinder(body, Transform3D(Basis(side, along, side.cross(along)), at.origin), log[2], log[1])
		_multi(made, log_mesh(), wood_material(), placed, [], 0.0, LOGS_FAR, true)
	# Rocks.
	if not c.rocks.is_empty():
		var by_kind := {}
		for rock: Array in c.rocks:
			var key := [rock[1], rock[3]]
			if not by_kind.has(key):
				by_kind[key] = []
			by_kind[key].append(rock[0])
			var at: Transform3D = rock[0]
			var hull := ConvexPolygonShape3D.new()
			var points := PackedVector3Array()
			for p in rock_hull(rock[1]):
				points.append(at.basis * p)
			hull.points = points
			var collider := CollisionShape3D.new()
			collider.shape = hull
			collider.position = at.origin
			body.add_child(collider)
		for key: Array in by_kind:
			_multi(made, rock_mesh(key[0]), rock_material(key[1]), by_kind[key], [], 0.0, far + 10.0, true)
	# Plants.
	for kind: int in c.plants:
		_multi(made, Undergrowth.mesh(kind), Undergrowth.shared_material(kind), c.plants[kind], [], 0.0, PLANTS_FAR, kind == Undergrowth.Kind.BUSH)
	# Bulrushes and lily pads.
	for kind: int in c.rushes:
		_multi(made, rush_mesh(kind), rush_material(), c.rushes[kind], [], 0.0, RUSHES_FAR, false)
	if not c.pads.is_empty():
		var placed := []
		var colours := []
		for pad: Array in c.pads:
			placed.append(pad[0])
			colours.append(pad[1])
		_multi(made, pad_mesh(), pad_material(), placed, colours, 0.0, PADS_FAR, false)
	# Mist.
	if not c.mist.is_empty():
		var mist := _multi(made, mist_mesh(), mist_material(), c.mist, [], 0.0, far, false)
		mist.extra_cull_margin = 40.0
	if body.get_child_count() > 0:
		made.add_child(body)
	else:
		body.free()
	return made


static func _cylinder(body: StaticBody3D, where: Transform3D, radius: float, tall: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = maxf(radius, 0.05)
	shape.height = tall
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.transform = where
	body.add_child(collider)


## A MultiMesh of `mesh` at each of `placed` under `parent`, seen from `begin`
## to `end` metres off (0: from the camera, or as far as there is).
static func _multi(parent: Node3D, mesh: Mesh, material: Material, placed: Array, colours: Array, begin: float, end: float, shadow: bool) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = not colours.is_empty()
	multi.mesh = mesh
	multi.instance_count = placed.size()
	for i in placed.size():
		multi.set_instance_transform(i, placed[i])
		if multi.use_colors:
			multi.set_instance_color(i, colours[i])
	var shown := MultiMeshInstance3D.new()
	shown.multimesh = multi
	shown.material_override = material
	shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shown.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	shown.visibility_range_begin = begin
	shown.visibility_range_end = end
	shown.visibility_range_end_margin = 12.0
	parent.add_child(shown)
	return shown


# --- Meshes and materials (made once) --------------------------------------------------

## A dead tree 1 m tall (scaled to its height), its trunk 3 cm round at its
## foot: grey and bare, a few broken branches reaching up, stained dark where
## the water stands round it. Variant 2 is a stump broken off short (scaled
## round by itself), with a ragged top and no branches.
static func snag_mesh(variant: int) -> ArrayMesh:
	var key := "snag%d" % variant
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 501 + variant
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stump := variant == 2
	const SIDES := 7
	const RINGS := 6
	var radius := func(t: float) -> float:
		return 0.03 * (1.0 - (0.3 if stump else 0.62) * t) * (1.0 + 0.6 * pow(1.0 - t, 6.0))
	var colour := func(t: float) -> Color:
		var grey := Color(0.29, 0.28, 0.25).lerp(Color(0.42, 0.4, 0.36), t)
		return grey.lerp(Color(0.11, 0.1, 0.08), 1.0 - smoothstep(0.02, 0.08 if not stump else 0.3, t))
	var lean := Vector3(rng.randf_range(-1, 1), 0.0, rng.randf_range(-1, 1)) * 0.04
	var top := 0.72 if variant == 0 else 1.0
	for r in RINGS:
		var t0 := float(r) / RINGS * top
		var t1 := float(r + 1) / RINGS * top
		for s in SIDES:
			var a0 := TAU * s / SIDES
			var a1 := TAU * (s + 1) / SIDES
			var corners := []
			for c: Array in [[t0, a0], [t0, a1], [t1, a0], [t1, a1]]:
				var t: float = c[0]
				var a: float = c[1]
				var y := t
				# (a stump's top broken off raggedly)
				if r == RINGS - 1 and t == t1:
					y -= rng.randf_range(0.0, 0.25 if stump else 0.05)
				corners.append([Vector3(cos(a) * radius.call(t), y, sin(a) * radius.call(t)) + lean * t * t, Vector3(cos(a), 0.15, sin(a)).normalized(), colour.call(t)])
			for k: int in [0, 1, 2, 1, 3, 2]:
				tool.set_color(corners[k][2])
				tool.set_normal(corners[k][1])
				tool.add_vertex(corners[k][0])
	if not stump:
		for b in rng.randi_range(4, 6):
			var t := rng.randf_range(0.35, 0.9) * top
			var turn := rng.randf() * TAU
			var up := rng.randf_range(0.5, 1.0)
			var length := rng.randf_range(0.12, 0.3) * (1.1 - t)
			var foot := Vector3(0.0, t, 0.0) + lean * t * t
			var way := Vector3(cos(turn), up, sin(turn)).normalized()
			var tip := foot + way * length
			var r0: float = radius.call(t) * 0.45
			var side := way.cross(Vector3.UP).normalized()
			var other := way.cross(side).normalized()
			for s in 4:
				var a0 := TAU * s / 4.0
				var a1 := TAU * (s + 1) / 4.0
				var p0 := foot + (side * cos(a0) + other * sin(a0)) * r0
				var p1 := foot + (side * cos(a1) + other * sin(a1)) * r0
				var n := (side * cos((a0 + a1) * 0.5) + other * sin((a0 + a1) * 0.5)).normalized()
				for p: Vector3 in [p0, p1, tip]:
					tool.set_color(colour.call(t))
					tool.set_normal(n)
					tool.add_vertex(p)
	var mesh := tool.commit()
	_meshes[key] = mesh
	return mesh


## A fallen log 1 m long along x and 1 m round (scaled to size): rough bark,
## moss along its top, its broken ends paler.
static func log_mesh() -> ArrayMesh:
	if _meshes.has("log"):
		return _meshes["log"]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SIDES := 9
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var bumps: Array[float] = []
	for s in SIDES:
		bumps.append(rng.randf_range(0.88, 1.08))
	var ring := func(x: float, s: int) -> Vector3:
		var a := TAU * s / SIDES
		var r := bumps[s % SIDES] * (1.0 - 0.12 * (x + 0.5))
		return Vector3(x, sin(a) * r, cos(a) * r)
	var bark := func(n: Vector3) -> Color:
		return Color(0.16, 0.12, 0.085).lerp(Color(0.13, 0.17, 0.07), smoothstep(0.35, 0.8, n.y))
	for s in SIDES:
		var a: Vector3 = ring.call(-0.5, s)
		var b: Vector3 = ring.call(-0.5, s + 1)
		var c: Vector3 = ring.call(0.5, s)
		var d: Vector3 = ring.call(0.5, s + 1)
		var na := Vector3(0.0, a.y, a.z).normalized()
		var nb := Vector3(0.0, b.y, b.z).normalized()
		for p: Array in [[a, na], [c, na], [b, nb], [b, nb], [c, na], [d, nb]]:
			tool.set_color(bark.call(p[1]))
			tool.set_normal(p[1])
			tool.add_vertex(p[0])
		# (the ends: paler broken wood)
		for end: float in [-0.5, 0.5]:
			var e0: Vector3 = ring.call(end, s)
			var e1: Vector3 = ring.call(end, s + 1)
			var out := Vector3(signf(end), 0.0, 0.0)
			for p: Vector3 in ([Vector3(end, 0, 0), e0, e1] if end > 0.0 else [Vector3(end, 0, 0), e1, e0]):
				tool.set_color(Color(0.27, 0.22, 0.15))
				tool.set_normal(out)
				tool.add_vertex(p)
	var mesh := tool.commit()
	_meshes["log"] = mesh
	return mesh


## A rock about 1 m round (scaled to size): a lumpy, faceted ball, flattened
## underneath, grey in a few tones.
static func rock_mesh(variant: int) -> ArrayMesh:
	var key := "rock%d" % variant
	if _meshes.has(key):
		return _meshes[key]
	var noise := _rock_noise(variant)
	var sphere := _icosphere(2)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + variant
	var faces: PackedInt32Array = sphere[1]
	var points: PackedVector3Array = sphere[0]
	for f in range(0, faces.size(), 3):
		var tri := []
		for k in 3:
			tri.append(_rock_point(points[faces[f + k]], noise))
		var normal: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
		if normal.dot(tri[0] + tri[1] + tri[2]) < 0.0:
			normal = -normal
			tri = [tri[0], tri[2], tri[1]]
		var tone := rng.randf_range(0.85, 1.1)
		var colour := Color(0.34, 0.335, 0.31) * tone
		colour.a = 1.0
		# (Godot's fronts are wound clockwise)
		for k: int in [0, 2, 1]:
			var p: Vector3 = tri[k]
			var low := clampf(p.length(), 0.6, 1.3)
			tool.set_color(colour * (0.75 + 0.25 * low))
			tool.set_normal(normal)
			tool.add_vertex(p)
	var mesh := tool.commit()
	_meshes[key] = mesh
	return mesh


## The points of a rough rock's hull (to bump into), as rock_mesh's shape.
static func rock_hull(variant: int) -> PackedVector3Array:
	if _hulls.has(variant):
		return _hulls[variant]
	var noise := _rock_noise(variant)
	var points := PackedVector3Array()
	for p: Vector3 in _icosphere(1)[0]:
		points.append(_rock_point(p, noise))
	_hulls[variant] = points
	return points


static func _rock_noise(variant: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = 4000 + variant
	noise.frequency = 1.1
	noise.fractal_octaves = 2
	return noise


static func _rock_point(direction: Vector3, noise: FastNoiseLite) -> Vector3:
	var d := direction.normalized()
	var r := 1.0 + 0.3 * noise.get_noise_3dv(d * 1.3) + 0.08 * noise.get_noise_3dv(d * 4.0 + Vector3(7, 3, 1))
	var p := d * r
	# (flattened underneath, where it sits in the ground)
	if p.y < -0.3:
		p.y = -0.3 + (p.y + 0.3) * 0.25
	return p


## The points and faces (by threes) of a ball of triangles, `level` times split.
static func _icosphere(level: int) -> Array:
	var t := (1.0 + sqrt(5.0)) * 0.5
	var points := PackedVector3Array([Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)])
	for i in points.size():
		points[i] = points[i].normalized()
	var faces := PackedInt32Array([0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8,
		3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1])
	for l in level:
		var halves := {}
		var split := PackedInt32Array()
		var middle := func(a: int, b: int) -> int:
			var key := Vector2i(mini(a, b), maxi(a, b))
			if not halves.has(key):
				points.append(((points[a] + points[b]) * 0.5).normalized())
				halves[key] = points.size() - 1
			return halves[key]
		for f in range(0, faces.size(), 3):
			var a := faces[f]
			var b := faces[f + 1]
			var c := faces[f + 2]
			var ab: int = middle.call(a, b)
			var bc: int = middle.call(b, c)
			var ca: int = middle.call(c, a)
			split.append_array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca])
		faces = split
	return [points, faces]


## The marsh's bulrush of `kind` (Marsh.Bulrush) and its lily pad.
static func rush_mesh(kind: int) -> ArrayMesh:
	var key := "rush%d" % kind
	if not _meshes.has(key):
		_meshes[key] = Marsh._bulrush_mesh(kind)
	return _meshes[key]


static func pad_mesh() -> ArrayMesh:
	if not _meshes.has("pad"):
		_meshes["pad"] = Marsh._pad_mesh()
	return _meshes["pad"]


static func mist_mesh() -> QuadMesh:
	if not _meshes.has("mist"):
		_meshes["mist"] = QuadMesh.new()
	return _meshes["mist"]


static func wood_material() -> StandardMaterial3D:
	if _wood_material == null:
		_wood_material = StandardMaterial3D.new()
		_wood_material.vertex_color_use_as_albedo = true
		_wood_material.roughness = 1.0
		_wood_material.metallic_specular = 0.0
	return _wood_material


static func pad_material() -> StandardMaterial3D:
	if _pad_material == null:
		_pad_material = StandardMaterial3D.new()
		_pad_material.vertex_color_use_as_albedo = true
		_pad_material.roughness = 1.0
		_pad_material.metallic_specular = 0.0
		_pad_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _pad_material


static func rush_material() -> ShaderMaterial:
	if _rush_material == null:
		var shader := Shader.new()
		shader.code = Marsh.BULRUSH_SHADER
		_rush_material = ShaderMaterial.new()
		_rush_material.shader = shader
		_rush_material.set_shader_parameter(&"height", Marsh.BULRUSH_HEIGHT)
	return _rush_material


## The rocks' material: their colours, the grain of weathered stone laid over
## them from three ways, and (`mossy`) moss over their tops.
static func rock_material(mossy: bool) -> ShaderMaterial:
	var made := _mossy_material if mossy else _rock_material
	if made == null:
		var shader := Shader.new()
		shader.code = ROCK_SHADER
		made = ShaderMaterial.new()
		made.shader = shader
		made.set_shader_parameter(&"grain", load("res://textures/concrete_weathered.png"))
		made.set_shader_parameter(&"mossy", 0.85 if mossy else 0.12)
		if mossy:
			_mossy_material = made
		else:
			_rock_material = made
	return made


static func mist_material() -> ShaderMaterial:
	if _mist_material == null:
		var shader := Shader.new()
		shader.code = MIST_SHADER
		_mist_material = ShaderMaterial.new()
		_mist_material.shader = shader
		_mist_material.set_shader_parameter(&"noise_map", load("res://textures/mud_noise.png"))
	return _mist_material


const ROCK_SHADER := """
shader_type spatial;
render_mode specular_disabled;

uniform sampler2D grain : source_color, filter_linear_mipmap, repeat_enable;
uniform float grain_size = 2.5;
uniform vec3 moss_colour : source_color = vec3(0.12, 0.15, 0.07);
uniform vec3 lichen : source_color = vec3(0.45, 0.44, 0.36);
uniform float mossy = 0.0;
uniform float banded = 1.0;
uniform float wrap = 0.2;

varying vec3 place;
varying vec3 facing;

void vertex() {
	place = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	facing = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w = pow(abs(facing), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 seen = texture(grain, place.zy / grain_size).rgb * w.x + texture(grain, place.xz / grain_size).rgb * w.y + texture(grain, place.xy / grain_size).rgb * w.z;
	float g = dot(seen, vec3(0.333));
	vec3 colour = COLOR.rgb * (0.5 + 0.9 * g);
	// (lichen in pale blotches; moss over the tops)
	float blotch = smoothstep(0.55, 0.7, texture(grain, place.xz / 9.0 + place.y * 0.05).r);
	colour = mix(colour, lichen * (0.8 + 0.4 * g), blotch * 0.35);
	float top = smoothstep(0.3, 0.75, facing.y + (g - 0.5) * 0.8);
	colour = mix(colour, moss_colour * (0.7 + 0.6 * g), top * mossy);
	ALBEDO = colour;
	ROUGHNESS = 1.0;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float towards = dot(NORMAL, LIGHT);
	float hard = cut((towards + wrap) / (1.0 + wrap) * smoothstep(0.15, 0.6, reach), 0.04) * reach;
	float soft = clamp(towards, 0.0, 1.0) * reach;
	DIFFUSE_LIGHT += mix(soft, hard, banded) * LIGHT_COLOR / PI;
}
"""

## Mist lying low: a card always turned to the camera about its upright,
## standing on its foot, soft at its edges and in wisps that drift, the colour of
## the mist, thinning away as the camera comes into it.
const MIST_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.7, 0.73, 0.72);
uniform float strength = 0.5;
uniform sampler2D noise_map : filter_linear, repeat_enable;

varying vec3 world;
varying vec2 seed_at;

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	float wide = length(MODEL_MATRIX[0].xyz);
	float high = length(MODEL_MATRIX[1].xyz);
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z) + vec3(0.0001, 0.0, 0.0));
	world = centre + right * VERTEX.x * wide + vec3(0.0, (VERTEX.y + 0.5) * high, 0.0);
	seed_at = centre.xz;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

float soft(vec2 p) {
	return texture(noise_map, p / 256.0).r;
}

void fragment() {
	float up = 1.0 - UV.y;
	float across = smoothstep(0.0, 0.4, UV.x) * smoothstep(1.0, 0.6, UV.x);
	float shape = smoothstep(0.0, 0.2, up) * (1.0 - smoothstep(0.25, 1.0, up));
	vec2 p = vec2(UV.x * 7.0, up * 2.0) + seed_at * 0.37 + vec2(TIME * 0.06, 0.0);
	float wisps = soft(p) * 0.6 + soft(p * 2.3 + 17.0) * 0.4;
	wisps = smoothstep(0.25, 0.75, wisps);
	float near = smoothstep(4.0, 22.0, distance(CAMERA_POSITION_WORLD, world));
	ALBEDO = tint;
	ALPHA = strength * across * shape * wisps * near;
}
"""

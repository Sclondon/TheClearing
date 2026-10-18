class_name Marsh
extends Node3D
## The marsh in front of the clearing's flooded entrance
## (ClearingStyle.Entrance.MARSH): a wide, ragged bog of shallow pools and
## channels of standing water between hummocks and tussocks of wet ground, mud
## at the water's edge, and a few deep dark pools. Sedges grow all over it, up
## out of the water as well as on the hummocks, thinning out only where the
## water is deep; reeds and bulrushes stand in clumps along the edges of the
## pools, and lily pads lie on the open water.
##
## How it lies is all ClearingStyle's (marsh_* settings: height_at, marsh_wet_at,
## marsh_depth_at), from the maze's seed. Here it is only built:
## - its ground, finer than the hills' (the hummocks are smaller than a step of
##   theirs, so the hills' coarse ground is sunk out of sight under it), with a
##   heightmap of the same to walk on;
## - one sheet of still water over the whole of it, at one level
##   (ClearingStyle.MARSH_LEVEL), that the ground stands up through: the shape of
##   the pools is the ground's. It is a Pool, so he wades in it (slower the
##   deeper), splashes going in and leaves rings, and swims in the deep pools;
## - the sedges and reeds, as GameCommon's Grass, so they bend round whoever
##   pushes through them as the clearing's grass does;
## - the bulrushes and lily pads, a MultiMesh of each in squares (BLOCK metres)
##   seen only near (NEAR metres); the bulrushes bend away from whoever pushes
##   through them too (the Grass pushers).
##
## Add it, then `realize(maze)`. It must stay at the origin, unturned.

## The marsh's ground: a point every this many metres.
const STEP := 1.0
## The bulrushes and lily pads are drawn in squares this many metres across, and
## only within NEAR (bulrushes) and NEAR * 0.7 (lily pads) metres of the camera.
const BLOCK := 30.0
const NEAR := 80.0
## How tall a bulrush is (before it is scaled), metres.
const BULRUSH_HEIGHT := 1.9

const GROUND_SHADER := """
shader_type spatial;

// The clearing's grass colour, as MazeStone's ground has it, where the marsh
// meets the field.
uniform vec3 grass : source_color = vec3(0.13, 0.2, 0.09);
// The tussocks' ground, browner; the black mud at the water's edge; the silt
// under the water.
uniform vec3 tussock : source_color = vec3(0.17, 0.18, 0.085);
uniform vec3 mud : source_color = vec3(0.075, 0.068, 0.052);
uniform vec3 silt : source_color = vec3(0.1, 0.095, 0.07);
uniform float level = -0.25;
uniform sampler2D noise_map : filter_linear, repeat_enable;
uniform float banded = 1.0;
uniform float wrap = 0.2;

varying vec3 place;
varying float wet;

float patches(vec2 p) {
	vec2 whole = floor(p);
	vec2 part = fract(p);
	part = part * part * (3.0 - 2.0 * part);
	return textureLod(noise_map, (whole + part + 0.5) / 256.0, 0.0).r;
}

void vertex() {
	place = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wet = COLOR.r;
}

void fragment() {
	vec2 at = place.xz;
	float above = place.y - level;
	vec3 field = grass * (0.85 + 0.3 * patches(at * 0.35));
	vec3 col = mix(field, tussock, 0.65) * (0.8 + 0.4 * patches(at * 1.7 + 4.0));
	// (mud a hand or two up from the water, raggedly)
	float margin = 1.0 - smoothstep(0.03, 0.17, above + (patches(at * 2.3) - 0.5) * 0.08);
	col = mix(col, mud * (0.75 + 0.5 * patches(at * 3.1 + 2.0)), margin);
	col = mix(col, silt * (0.8 + 0.4 * patches(at * 0.9)), smoothstep(0.0, -0.25, above));
	float marsh = smoothstep(0.0, 0.45, wet);
	ALBEDO = mix(field, col, marsh);
	ROUGHNESS = mix(1.0, 0.75, margin * marsh);
	SPECULAR = 0.0;
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
	// (the sheen of the wet mud)
	float gloss = 1.0 - ROUGHNESS;
	if (gloss > 0.01) {
		float shine = pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), mix(6.0, 48.0, gloss * gloss));
		SPECULAR_LIGHT += shine * gloss * reach * LIGHT_COLOR * 0.1;
	}
}
"""

const BULRUSH_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 stalk : source_color = vec3(0.17, 0.21, 0.1);
uniform vec3 stalk_top : source_color = vec3(0.36, 0.36, 0.2);
uniform vec3 head : source_color = vec3(0.2, 0.12, 0.07);
uniform float height = 1.9;
uniform vec2 wind_dir = vec2(1.0, 0.35);
uniform float wind = 0.45;
uniform vec4 pushers[8];
uniform int pusher_count = 0;
uniform float banded = 1.0;
uniform float wrap = 0.2;

varying float v_t;
varying float v_head;
varying float v_rnd;

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float t = clamp(VERTEX.y / height, 0.0, 1.0);
	float rnd = fract(sin(dot(root.xz, vec2(12.9898, 78.233))) * 43758.5453);
	vec2 wd = normalize(wind_dir);
	// (a slow nod in the wind, each its own)
	vec2 bend = wd * wind * (0.12 + 0.1 * sin(TIME * (1.1 + rnd * 0.7) + rnd * 6.28 + dot(root.xz, wd) * 0.3));
	for (int i = 0; i < 8; i++) {
		if (i >= pusher_count) {
			break;
		}
		vec4 p = pushers[i];
		vec2 away = root.xz - p.xz;
		float dist = length(away);
		float close = (1.0 - smoothstep(p.w * 0.4, p.w * 1.3, dist)) * (1.0 - smoothstep(1.2, 2.5, abs(p.y - root.y)));
		bend += away / max(dist, 0.001) * close * 1.1;
	}
	float angle = min(length(bend), 1.3) * t;
	vec2 dir = length(bend) > 0.0001 ? normalize(bend) : wd;
	// (over, along an arc: the higher, the further)
	float up = VERTEX.y;
	vec3 shift = vec3(dir.x * up * sin(angle), -up * (1.0 - cos(angle)), dir.y * up * sin(angle));
	mat3 basis = mat3(MODEL_MATRIX);
	float scale2 = max(dot(basis[0], basis[0]), 0.0001);
	VERTEX += (transpose(basis) * shift) / scale2;
	v_t = t;
	v_head = COLOR.a;
	v_rnd = rnd;
}

void fragment() {
	vec3 col = mix(stalk, stalk_top, smoothstep(0.2, 1.0, v_t)) * (0.85 + 0.3 * v_rnd);
	col = mix(col, head * (0.85 + 0.3 * v_rnd), v_head);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
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

var maze: Maze
## The square (x, z) it covers (ClearingStyle.marsh_rect).
var area: Rect2
## The water over it.
var water: Pool
## Its ground, and the sedges and reeds (Grass) over it.
var ground: MeshInstance3D
var sedges: Grass
var reeds: Grass
## How many bulrushes and lily pads there are.
var bulrush_count := 0
var lily_pad_count := 0

var _heights := PackedFloat32Array()
var _wets := PackedFloat32Array()
var _across := 0
var _down := 0
var _clumps: FastNoiseLite
var _bulrush_material: ShaderMaterial
var _pushing := false


## Builds the marsh for `plan`'s flooded entrance (nothing if it has none).
func realize(plan: Maze) -> void:
	maze = plan
	var look := maze.clearing_style
	area = look.marsh_rect()
	if not area.has_area():
		return
	_clumps = FastNoiseLite.new()
	_clumps.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_clumps.seed = maze.maze_seed + 31
	_clumps.frequency = 1.0 / 9.0
	_clumps.fractal_type = FastNoiseLite.FRACTAL_NONE
	_ground()
	_water()
	_grass()
	_bulrushes_and_pads()


## How high the marsh's ground is at `point` (x, z), as its mesh has it (a point
## every STEP metres, straight between them).
func ground_at(point: Vector2) -> float:
	return _grid_at(_heights, point)


## How far into the marsh `point` is (ClearingStyle.marsh_wet_at), as its mesh
## has it.
func wet_at(point: Vector2) -> float:
	return _grid_at(_wets, point)


func _grid_at(values: PackedFloat32Array, point: Vector2) -> float:
	var f := (point - area.position) / STEP
	var i := clampi(floori(f.x), 0, _across - 2)
	var j := clampi(floori(f.y), 0, _down - 2)
	var u := clampf(f.x - i, 0.0, 1.0)
	var v := clampf(f.y - j, 0.0, 1.0)
	var at := i + j * _across
	# (over the same two triangles as the mesh: split from corner to corner
	# across the square, from (1, 0) to (0, 1))
	var a := values[at + 1]
	var c := values[at + _across]
	if u + v <= 1.0:
		var o := values[at]
		return o + (a - o) * u + (c - o) * v
	var d := values[at + _across + 1]
	return d + (c - d) * (1.0 - u) + (a - d) * (1.0 - v)


## How deep the water is over the ground at `point`, metres (less than 0 where
## the ground stands up out of it).
func depth_at(point: Vector2) -> float:
	return ClearingStyle.MARSH_LEVEL - ground_at(point)


## The chance of a tuft of sedge at `point`: all over the marsh, thick on the
## hummocks, thinner standing up out of the water (so that it is seen), and
## thinning out to none where the water is deeper than the marsh grass depth.
func sedge_at(point: Vector2) -> float:
	var look := maze.clearing_style
	var wet := wet_at(point)
	if wet <= 0.02:
		return 0.0
	var deep := look.marsh_grass_depth
	var depth := depth_at(point)
	var thick := lerpf(0.8, 0.4, smoothstep(-0.06, 0.06, depth)) * (1.0 - smoothstep(deep * 0.5, deep, depth))
	return smoothstep(0.02, 0.35, wet) * thick


## The chance of a tuft of reeds at `point`: in clumps, along the edges of the
## pools (just in and just out of the water), none in the lane in from the gate.
func reed_at(point: Vector2) -> float:
	var look := maze.clearing_style
	if look.marsh_reeds <= 0.0 or wet_at(point) < 0.3:
		return 0.0
	var depth := depth_at(point)
	var edge := smoothstep(-0.12, 0.0, depth) * (1.0 - smoothstep(0.25, 0.42, depth))
	var start := 0.75 - look.marsh_reeds * 0.45
	var clump := smoothstep(start, start + 0.1, _clumps.get_noise_2d(point.x, point.y) * 0.5 + 0.5)
	return edge * clump * (1.0 - look.marsh_lane_at(point))


# The ground: a mesh of points STEP apart, its wetness (marsh_wet_at) in the red
# of their colour, and a heightmap of the same to walk on.
func _ground() -> void:
	var look := maze.clearing_style
	_across = ceili(area.size.x / STEP) + 1
	_down = ceili(area.size.y / STEP) + 1
	_heights.resize(_across * _down)
	_wets.resize(_across * _down)
	var points := PackedVector3Array()
	var colours := PackedColorArray()
	points.resize(_across * _down)
	colours.resize(_across * _down)
	for j in _down:
		for i in _across:
			var at := area.position + Vector2(i, j) * STEP
			var y := maze.ground_height(Vector3(at.x, 0.0, at.y))
			_heights[i + j * _across] = y
			points[i + j * _across] = Vector3(at.x, y + MazeBuilder.HILL_LIFT + 0.004, at.y)
			_wets[i + j * _across] = look.marsh_wet_at(at, maze.maze_seed)
			colours[i + j * _across] = Color(_wets[i + j * _across], 0.0, 0.0)
	var normals := PackedVector3Array()
	normals.resize(_across * _down)
	for j in _down:
		for i in _across:
			var dx := _heights[mini(i + 1, _across - 1) + j * _across] - _heights[maxi(i - 1, 0) + j * _across]
			var dz := _heights[i + mini(j + 1, _down - 1) * _across] - _heights[i + maxi(j - 1, 0) * _across]
			normals[i + j * _across] = Vector3(-dx, 2.0 * STEP, -dz).normalized()
	var order := PackedInt32Array()
	order.resize((_across - 1) * (_down - 1) * 6)
	var k := 0
	for j in _down - 1:
		for i in _across - 1:
			var a := i + j * _across
			order[k] = a
			order[k + 1] = a + 1
			order[k + 2] = a + _across
			order[k + 3] = a + 1
			order[k + 4] = a + _across + 1
			order[k + 5] = a + _across
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = order
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shader := Shader.new()
	shader.code = GROUND_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"level", ClearingStyle.MARSH_LEVEL)
	material.set_shader_parameter(&"noise_map", load("res://textures/mud_noise.png"))
	ground = MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = mesh
	ground.material_override = material
	add_child(ground)
	# (to walk on: the same heights, in heightmap units, the shape scaled up by STEP)
	var body := StaticBody3D.new()
	body.name = "Footing"
	var shape := HeightMapShape3D.new()
	shape.map_width = _across
	shape.map_depth = _down
	var data := PackedFloat32Array()
	data.resize(_heights.size())
	for i in _heights.size():
		data[i] = _heights[i] / STEP
	shape.map_data = data
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.scale = Vector3.ONE * STEP
	collider.position = Vector3(area.position.x + (_across - 1) * STEP * 0.5, 0.0, area.position.y + (_down - 1) * STEP * 0.5)
	body.add_child(collider)
	add_child(body)


# One sheet of still, murky water over the whole of it.
func _water() -> void:
	var look := maze.clearing_style
	water = Pool.new()
	water.name = "Water"
	water.size = Vector3(area.size.x, look.marsh_pool_depth + 1.0, area.size.y)
	water.position = Vector3(area.get_center().x, ClearingStyle.MARSH_LEVEL, area.get_center().y)
	# (grey and murky as the rest of the place, a scum of duckweed lying on it
	# in patches, and the scum gathered round whatever stands up out of it)
	water.look = {
		"shallow": Color(0.17, 0.2, 0.15),
		"deep": Color(0.035, 0.045, 0.035),
		"foam": Color(0.17, 0.21, 0.1),
		"sky": Color(0.6, 0.63, 0.63),
		"depth_range": 0.9,
		"alpha_shallow": 0.6,
		"mirror": 0.55,
		"caustics": 0.0,
		"swell_height": 0.006,
		"lines": 0.18,
		"glint": 0.0,
		"foam_width": 0.16,
		"foam_ragged": 0.8,
		"foam_drift": 0.22,
		"sides": false,
	}
	add_child(water)


# The sedges all over it, and the reeds in clumps along the pools.
func _grass() -> void:
	var look := maze.clearing_style
	var height := func(p: Vector2) -> float: return ground_at(p) + MazeBuilder.HILL_LIFT
	sedges = Grass.field(self, area, 0.95, {
		"mask": sedge_at,
		"height": height,
		"ground": Color(0.11, 0.14, 0.07),
		"blade_height": look.marsh_grass_height,
		"blade_width": 0.024,
		"lean": 0.22,
		"body": Color(0.13, 0.18, 0.075),
		"tip": Color(0.38, 0.37, 0.19),
		"dry": Color(0.44, 0.39, 0.21),
		"dryness": 0.6,
		"translucency": 0.08,
		"flowers": 0.0,
		"seed": maze.maze_seed % 1000 + 2,
	})
	if look.marsh_reeds <= 0.0:
		return
	reeds = Grass.field(self, area, 0.8, {
		"mask": reed_at,
		"height": height,
		"ground": Color(0.11, 0.14, 0.07),
		"blade_height": look.marsh_grass_height * 1.8,
		"blade_width": 0.03,
		"lean": 0.12,
		"body": Color(0.15, 0.2, 0.09),
		"tip": Color(0.42, 0.4, 0.22),
		"dry": Color(0.48, 0.42, 0.24),
		"dryness": 0.45,
		"translucency": 0.1,
		"flowers": 0.0,
		"push_bend": 1.0,
		"seed": maze.maze_seed % 1000 + 3,
	})


# The bulrushes, in among the reeds, and the lily pads, on the open water,
# each a MultiMesh in each square of BLOCK metres.
func _bulrushes_and_pads() -> void:
	var look := maze.clearing_style
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("marsh/%d" % maze.maze_seed)
	# [square] -> transforms
	var rushes := {}
	var pads := {}
	var pad_colours := {}
	const SPACING := 0.8
	var steps := Vector2i((area.size / SPACING).ceil())
	for j in steps.y:
		for i in steps.x:
			var p := area.position + (Vector2(i, j) + Vector2(rng.randf(), rng.randf())) * SPACING
			var square := Vector2i((p / BLOCK).floor())
			var reedy := reed_at(p)
			if reedy > 0.0 and rng.randf() < reedy * look.marsh_reeds * 0.7:
				var y := ground_at(p)
				var lean := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * 0.08
				var basis := Basis(Vector3.UP, rng.randf() * TAU)
				basis = Basis(lean.cross(Vector3.UP).normalized() if lean.length() > 0.001 else Vector3.RIGHT, lean.length()) * basis
				basis = basis.scaled(Vector3.ONE * rng.randf_range(0.75, 1.15))
				if not rushes.has(square):
					rushes[square] = []
				rushes[square].append(Transform3D(basis, Vector3(p.x, y - 0.05, p.y)))
				continue
			if look.marsh_lily_pads <= 0.0:
				continue
			var depth := depth_at(p)
			if depth < 0.28 or look.marsh_lane_at(p) > 0.05:
				continue
			var gather := _clumps.get_noise_2d(p.x * 1.7 + 300.0, p.y * 1.7 - 120.0) * 0.5 + 0.5
			var start := 0.78 - look.marsh_lily_pads * 0.3
			if rng.randf() < smoothstep(start, start + 0.12, gather) * 0.75:
				var size := rng.randf_range(0.16, 0.36)
				var at := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size, 1.0, size)), Vector3(p.x, ClearingStyle.MARSH_LEVEL + 0.012, p.y))
				if not pads.has(square):
					pads[square] = []
					pad_colours[square] = []
				pads[square].append(at)
				# (most dark green, some yellowed or browned at the edge of the year)
				var tone := rng.randf()
				pad_colours[square].append(Color(0.16, 0.25, 0.09) if tone < 0.7 else (Color(0.34, 0.33, 0.13) if tone < 0.9 else Color(0.26, 0.16, 0.08)))
	if not rushes.is_empty():
		var shader := Shader.new()
		shader.code = BULRUSH_SHADER
		_bulrush_material = ShaderMaterial.new()
		_bulrush_material.shader = shader
		_bulrush_material.set_shader_parameter(&"height", BULRUSH_HEIGHT)
		var mesh := _bulrush_mesh()
		for square: Vector2i in rushes:
			var placed: Array = rushes[square]
			bulrush_count += placed.size()
			add_child(_multi(mesh, _bulrush_material, placed, [], NEAR))
	if not pads.is_empty():
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 1.0
		material.metallic_specular = 0.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mesh := _pad_mesh()
		for square: Vector2i in pads:
			lily_pad_count += pads[square].size()
			add_child(_multi(mesh, material, pads[square], pad_colours[square], NEAR * 0.7))


func _multi(mesh: Mesh, material: Material, placed: Array, colours: Array, near: float) -> MultiMeshInstance3D:
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
	shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shown.extra_cull_margin = 1.5
	shown.visibility_range_end = near
	shown.visibility_range_end_margin = 8.0
	shown.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return shown


# A bulrush: a stalk of two crossed blades, a brown head two thirds of the way
# up (alpha 1 in its colour) and a thin spike above it.
static func _bulrush_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := BULRUSH_HEIGHT
	for turn: float in [0.0, PI * 0.5]:
		var across := Vector3(cos(turn), 0.0, sin(turn)) * 0.012
		var normal := Vector3(-sin(turn), 0.25, cos(turn)).normalized()
		_quad(tool, Vector3.ZERO - across, Vector3.ZERO + across, Vector3(0, h, 0) + across * 0.3, Vector3(0, h, 0) - across * 0.3, normal, 0.0)
	# (the head: a six sided stick of brown, capped)
	var low := h * 0.66
	var high := h * 0.84
	for s in 6:
		var a := TAU * s / 6.0
		var b := TAU * (s + 1) / 6.0
		var pa := Vector3(cos(a), 0.0, sin(a)) * 0.042
		var pb := Vector3(cos(b), 0.0, sin(b)) * 0.042
		var normal := Vector3(cos((a + b) * 0.5), 0.0, sin((a + b) * 0.5))
		_quad(tool, pa + Vector3(0, low, 0), pb + Vector3(0, low, 0), pb * 0.8 + Vector3(0, high, 0), pa * 0.8 + Vector3(0, high, 0), normal, 1.0)
		for tri: Array in [[Vector3(0, high + 0.02, 0), pb * 0.8 + Vector3(0, high, 0), pa * 0.8 + Vector3(0, high, 0)], [Vector3(0, low - 0.015, 0), pa + Vector3(0, low, 0), pb + Vector3(0, low, 0)]]:
			for v: Vector3 in tri:
				tool.set_color(Color(1, 1, 1, 1.0))
				tool.set_normal(normal)
				tool.add_vertex(v)
	return tool.commit()


static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, head: float) -> void:
	for v: Vector3 in [a, b, c, a, c, d]:
		tool.set_color(Color(1, 1, 1, head))
		tool.set_normal(normal)
		tool.add_vertex(v)


# A lily pad, a metre across before it is scaled: a disc with a notch cut into
# it to its middle, its rim a little turned up.
static func _pad_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SIDES := 14
	for s in SIDES - 1:
		var a := TAU * (s + 0.5) / SIDES
		var b := TAU * (s + 1.5) / SIDES
		for v: Vector3 in [Vector3.ZERO, Vector3(cos(b), 0.02, sin(b)), Vector3(cos(a), 0.02, sin(a))]:
			tool.set_normal(Vector3.UP)
			tool.add_vertex(v)
	return tool.commit()


func _process(_delta: float) -> void:
	if _bulrush_material == null:
		return
	# (the bulrushes bend away from the grass pushers near the camera, while it
	# is near enough to see them)
	var camera := get_viewport().get_camera_3d()
	var near := camera != null and area.grow(NEAR).has_point(Vector2(camera.global_position.x, camera.global_position.z))
	if not near:
		if _pushing:
			_bulrush_material.set_shader_parameter(&"pusher_count", 0)
			_pushing = false
		return
	var eye := camera.global_position
	var found: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(Grass.PUSHERS):
		if node is Node3D and node.is_inside_tree() and area.grow(3.0).has_point(Vector2(node.global_position.x, node.global_position.z)):
			found.append(node)
	if found.size() > Grass.MAX_PUSHERS:
		found.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_squared_to(eye) < b.global_position.distance_squared_to(eye))
	var packed := PackedVector4Array()
	packed.resize(Grass.MAX_PUSHERS)
	var n := mini(found.size(), Grass.MAX_PUSHERS)
	for i in n:
		var at := found[i].global_position
		packed[i] = Vector4(at.x, at.y, at.z, found[i].get_meta(&"grass_radius", 0.7))
	_bulrush_material.set_shader_parameter(&"pushers", packed)
	_bulrush_material.set_shader_parameter(&"pusher_count", n)
	_pushing = n > 0

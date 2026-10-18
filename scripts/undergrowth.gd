class_name Undergrowth
extends Node3D
## The low plants: ferns, bushes, cushions of moss and tufts of coarse grass, made
## in code (no textures), dull and damp to sit in the grey picture. Each kind is
## drawn as one MultiMesh for every square of SQUARE metres, so that squares off
## the screen are not drawn, and fades out past FAR (the mist has them by then).
##
##     var plants := Undergrowth.new()
##     plants.add(Undergrowth.Kind.FERN, Transform3D(...))     # as many as wanted
##     add_child(plants); plants.build()
##
## Where they go is MazeBuilder's to say (from the maze's styles), so every copy
## of the game in a room has the same.

enum Kind { FERN, BUSH, MOSS, TUFT }

const SQUARE := 40.0
const FAR := 110.0

static var _meshes := {}
static var _material: StandardMaterial3D

## [kind, square] -> [Transform3D]
var _placed := {}
var count := 0


## Puts one of `kind` at `where` (its foot; scale it to size it).
func add(kind: Kind, where: Transform3D) -> void:
	var key := [kind, Vector2i(floori(where.origin.x / SQUARE), floori(where.origin.z / SQUARE))]
	if not _placed.has(key):
		_placed[key] = []
	(_placed[key] as Array).append(where)
	count += 1


## Makes what has been added.
func build() -> void:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material.roughness = 1.0
		_material.metallic_specular = 0.0
	for key: Array in _placed:
		var placed: Array = _placed[key]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh(key[0])
		multi.instance_count = placed.size()
		for i in placed.size():
			multi.set_instance_transform(i, placed[i])
		var shown := MultiMeshInstance3D.new()
		shown.multimesh = multi
		shown.material_override = _material
		shown.visibility_range_end = FAR
		shown.visibility_range_end_margin = 15.0
		shown.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		# (only the bushes are big enough for their shadows to be seen)
		if key[0] != Kind.BUSH:
			shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shown)


## The mesh of a kind (made once).
static func mesh(kind: Kind) -> ArrayMesh:
	if not _meshes.has(kind):
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + kind
		match kind:
			Kind.FERN: _meshes[kind] = _fern(rng)
			Kind.BUSH: _meshes[kind] = _bush(rng)
			Kind.MOSS: _meshes[kind] = _moss(rng)
			Kind.TUFT: _meshes[kind] = _tuft(rng)
	return _meshes[kind]


## A fern about a metre high: fronds arching out from the middle, each a stem with
## leaflets either side that shorten towards its tip.
static func _fern(rng: RandomNumberGenerator) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fronds := 11
	for f in fronds:
		var turn := f * TAU / fronds + rng.randf_range(-0.2, 0.2)
		var out := Vector3(sin(turn), 0.0, cos(turn))
		var side := out.cross(Vector3.UP).normalized()
		var long := rng.randf_range(0.8, 1.25)
		var rise := rng.randf_range(0.7, 1.1)
		var steps := 10
		var last := Vector3.ZERO
		for s in steps:
			var t := (s + 1) / float(steps)
			# (up and out, then over and down at the tip)
			var at := out * long * t + Vector3.UP * long * rise * (t * (1.3 - t))
			var dark := Color(0.13, 0.2, 0.09).lerp(Color(0.24, 0.32, 0.14), t)
			var reach := 0.22 * (1.0 - t * 0.8) * long
			var droop := Vector3.DOWN * reach * 0.35
			for way in [-1.0, 1.0]:
				var tip: Vector3 = at + side * way * reach + droop + out * reach * 0.3
				_tri(tool, last, at, tip, dark)
			last = at
	return tool.commit()


## A bush about two metres across: leafy clumps over a few lumps, dark and dense.
static func _bush(rng: RandomNumberGenerator) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lumps: Array[Vector3] = []
	for l in 5:
		lumps.append(Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.5, 1.1), rng.randf_range(-0.6, 0.6)))
	for i in 420:
		var lump := lumps[rng.randi() % lumps.size()]
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1), rng.randf_range(-1, 1)).normalized()
		var at := lump + dir * rng.randf_range(0.35, 0.7) * Vector3(1.0, 0.8, 1.0)
		at.y = maxf(at.y, 0.05)
		var size := rng.randf_range(0.18, 0.3)
		var a := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized() * size
		var b := dir.cross(a).normalized() * size * 0.6
		var shade := Color(0.11, 0.17, 0.08).lerp(Color(0.22, 0.29, 0.13), clampf(at.y / 1.3, 0.0, 1.0) * rng.randf_range(0.6, 1.0))
		_tri(tool, at - a, at + b, at + a, shade)
		_tri(tool, at - a, at + a, at - b, shade)
	return tool.commit()


## A low cushion of moss, a metre or so across, lumpy and yellow-green.
static func _moss(rng: RandomNumberGenerator) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 4
	var around := 12
	var points: Array = []
	for r in rings + 1:
		var row: Array[Vector3] = []
		var t := r / float(rings)
		for k in around:
			var a := k * TAU / around
			var bump := rng.randf_range(0.8, 1.15)
			var radius := 0.55 * sin(t * PI * 0.5) * bump
			var high := 0.22 * cos(t * PI * 0.5) * rng.randf_range(0.7, 1.2)
			row.append(Vector3(cos(a) * radius, high - 0.02, sin(a) * radius * 0.8))
		points.append(row)
	for r in rings:
		var shade := Color(0.2, 0.25, 0.09).lerp(Color(0.13, 0.17, 0.07), r / float(rings))
		for k in around:
			var k2 := (k + 1) % around
			_tri(tool, points[r][k], points[r + 1][k], points[r + 1][k2], shade)
			_tri(tool, points[r][k], points[r + 1][k2], points[r][k2], shade)
	return tool.commit()


## A tuft of coarse grass, knee high: tapered blades leaning out.
static func _tuft(rng: RandomNumberGenerator) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in 14:
		var turn := rng.randf() * TAU
		var lean := Vector3(sin(turn), 0.0, cos(turn)) * rng.randf_range(0.1, 0.4)
		var high := rng.randf_range(0.45, 0.8)
		var side := Vector3(cos(turn), 0.0, -sin(turn)) * 0.025
		var root := lean * 0.15
		var tip := root + lean + Vector3.UP * high
		var bend := root + lean * 0.4 + Vector3.UP * high * 0.55
		var base := Color(0.15, 0.2, 0.09)
		var top := Color(0.3, 0.33, 0.17)
		_tri(tool, root - side, root + side, bend + side * 0.6, base)
		_tri(tool, root - side, bend + side * 0.6, bend - side * 0.6, base)
		_tri(tool, bend - side * 0.6, bend + side * 0.6, tip, top)
	return tool.commit()


static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	# (leaves lit as if they faced up, more or less: soft, not flat black underneath)
	normal = (normal * signf(normal.y + 0.001) + Vector3.UP).normalized()
	for p in [a, b, c]:
		tool.set_color(colour)
		tool.set_normal(normal)
		tool.add_vertex(p)

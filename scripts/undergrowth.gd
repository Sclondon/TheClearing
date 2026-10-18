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

enum Kind { FERN, BUSH, MOSS, TUFT, GRASS }

const SQUARE := 40.0
const FAR := 110.0

static var _meshes := {}
static var _material: ShaderMaterial
static var _fern_material: ShaderMaterial
static var _bush_material: ShaderMaterial

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
	shared_material()
	set_process(true)
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
		shown.material_override = _fern_material if key[0] == Kind.FERN else (_bush_material if key[0] == Kind.BUSH else _material)
		shown.visibility_range_end = FAR
		shown.visibility_range_end_margin = 15.0
		shown.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		# (only the bushes are big enough for their shadows to be seen)
		if key[0] != Kind.BUSH:
			shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shown)


## The material plants of `kind` are drawn with (shared by every patch, here
## and in the desert ring's quarters: Wilds): the fern shader for ferns, the
## plant shader (sway, and pushed aside) for the rest.
static func shared_material(kind := Kind.BUSH) -> ShaderMaterial:
	if _material == null:
		_material = _shaded(PLANT)
		_fern_material = _shaded(FERN)
		_bush_material = _shaded(BUSH)
	if kind == Kind.FERN:
		return _fern_material
	return _bush_material if kind == Kind.BUSH else _material


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
			Kind.GRASS: _meshes[kind] = _short_grass(rng)
	return _meshes[kind]


## A fern about a metre high: fronds arching out from the middle and over. Each
## frond is a card folded along its stem (its two halves drooping a little), on
## which the fern shader draws the stem and its leaflets (FERN: see there what
## the card's UV, UV2 and colour carry).
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
		var reach := 0.24 * long
		var steps := 10
		# (up and out, then over and down at the tip: its stem, and how far along it each point is)
		var stem: Array[Vector3] = [Vector3.ZERO]
		var along: Array[float] = [0.0]
		for s in steps:
			var t := (s + 1) / float(steps)
			var at := out * long * t + Vector3.UP * long * rise * (t * (1.3 - t))
			along.append(along.back() + at.distance_to(stem.back()))
			stem.append(at)
		var length: float = along.back()
		var colour := Color(0.15, 0.22, 0.1).lerp(Color(0.21, 0.29, 0.13), rng.randf())
		colour.a = reach * 0.5
		var droop := Vector3.DOWN * reach * 0.3
		for s in steps:
			var rows: Array = []
			for k in [s, s + 1]:
				var at: Vector3 = stem[k]
				rows.append([at - side * reach + droop, at, at + side * reach + droop])
			for half in 2:
				var corners := [[rows[0][half], -1.0 + half, along[s]], [rows[0][half + 1], half * 1.0, along[s]],
					[rows[1][half + 1], half * 1.0, along[s + 1]], [rows[1][half], -1.0 + half, along[s + 1]]]
				for c: int in [0, 1, 2, 0, 2, 3]:
					tool.set_color(colour)
					tool.set_normal((Vector3.UP + out * 0.3).normalized())
					tool.set_uv(Vector2(corners[c][2], corners[c][1]))
					tool.set_uv2(Vector2(1.0, length))
					tool.add_vertex(corners[c][0])
	return tool.commit()


## A bush about two metres across and a metre and a half high, rooted on the
## ground: a few twiggy stems up from its foot into a dome of leafy lumps, each
## a shell of small cards on which the bush shader draws sprays of leaves (BUSH:
## see there what the cards' UV, UV2 and colour carry), the gaps between them
## cut out. Darker inside and low down, paler at its top; lit as one rounded
## mass (each card's normal is the way out from the middle of its lump), so that
## it reads as a shrub and not as the cards it is made of. (Before, it was
## flat-shaded diamonds hung round its lumps: "the bush just looks like
## floating squares", the user, 2026-10-18.)
static func _bush(rng: RandomNumberGenerator) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# (the lumps of its dome, low ones round its skirt down to the ground)
	var lumps: Array[Vector4] = [Vector4(0.0, 0.62, 0.0, 0.62)]
	for l in 5:
		var turn := l * TAU / 5.0 + rng.randf_range(-0.4, 0.4)
		var out := rng.randf_range(0.35, 0.6)
		lumps.append(Vector4(cos(turn) * out, rng.randf_range(0.38, 0.62), sin(turn) * out, rng.randf_range(0.4, 0.55)))
	lumps.append(Vector4(rng.randf_range(-0.2, 0.2), 0.95, rng.randf_range(-0.2, 0.2), 0.42))
	# Its stems: from the root up and out into each lump, thin and dark.
	var bark := Color(0.09, 0.08, 0.06)
	for lump in lumps:
		var top := Vector3(lump.x, lump.y, lump.z) * 0.9
		var root := Vector3(lump.x, 0.0, lump.z) * 0.15
		var side := (top - root).cross(Vector3.UP).normalized()
		if side.length() < 0.5:
			side = Vector3.RIGHT
		for flat: Vector3 in [side, (top - root).cross(side).normalized()]:
			var bottom := flat * 0.025
			var upper := flat * 0.012
			_card(tool, [root - bottom, root + bottom, top + upper, top - upper], [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)], -1.0, 0.0, bark, Vector3.UP)
	# Its leaves: cards over each lump's outside (more on the bigger), turned
	# every way, and a few deeper in, darker, so that it is not hollow.
	for lump in lumps:
		var middle := Vector3(lump.x, lump.y, lump.z)
		var cards := int(lump.w * lump.w * 260.0)
		for c in cards:
			var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.55, 1), rng.randf_range(-1, 1)).normalized()
			var deep := rng.randf_range(0.6, 1.05) if rng.randf() < 0.8 else rng.randf_range(0.25, 0.6)
			var at := middle + dir * lump.w * deep * Vector3(1.0, 0.85, 1.0)
			if at.y < 0.04:
				at.y = rng.randf_range(0.04, 0.12)
			# (facing out, more or less, and rolled at random)
			var facing := (dir + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.3, 0.5), rng.randf_range(-0.5, 0.5))).normalized()
			var a := facing.cross(Vector3.UP if absf(facing.y) < 0.95 else Vector3.RIGHT).normalized()
			var b := facing.cross(a).normalized()
			var roll := rng.randf() * TAU
			var size := rng.randf_range(0.2, 0.3)
			var u := (a * cos(roll) + b * sin(roll)) * size
			var v := (b * cos(roll) - a * sin(roll)) * size
			# (darker in its depths and low down, paler towards the top and outside)
			var light := clampf(deep * 0.55 + at.y / 1.4 * 0.45, 0.0, 1.0)
			var shade := Color(0.08, 0.12, 0.06).lerp(Color(0.2, 0.27, 0.12), light * rng.randf_range(0.75, 1.0))
			var normal := (dir + Vector3.UP * 0.35).normalized()
			_card(tool, [at - u - v, at + u - v, at + u + v, at - u + v], [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)], rng.randf(), light, shade, normal)
	return tool.commit()


# A quad of `corners` (UV `uvs`), UV2 (`which`, `light`), all of it lit with `normal`.
static func _card(tool: SurfaceTool, corners: Array, uvs: Array, which: float, light: float, colour: Color, normal: Vector3) -> void:
	for k: int in [0, 1, 2, 0, 2, 3]:
		tool.set_color(colour)
		tool.set_normal(normal)
		tool.set_uv(uvs[k])
		tool.set_uv2(Vector2(which, light))
		tool.add_vertex(corners[k])


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


## A clump of short grass, ankle high, about half a metre across: many fine
## blades, the clumps set close in runs along the foot of a wall.
static func _short_grass(rng: RandomNumberGenerator) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in 34:
		var turn := rng.randf() * TAU
		var root := Vector3(cos(turn), 0.0, sin(turn)) * rng.randf_range(0.0, 0.38)
		var lean := Vector3(cos(turn), 0.0, sin(turn)) * rng.randf_range(0.02, 0.1)
		var high := rng.randf_range(0.18, 0.42)
		var side := Vector3(-sin(turn + 1.3), 0.0, cos(turn + 1.3)) * 0.022
		# (paler than the moss it grows by, so that it reads against it)
		var colour := Color(0.24, 0.28, 0.13).lerp(Color(0.38, 0.4, 0.22), rng.randf())
		_tri(tool, root - side, root + side, root + lean + Vector3.UP * high, colour)
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


## The low plants' shader (tufts, moss and short grass; the bushes have their own, BUSH): their own colours, a little sway
## in the wind, more towards their tops, and pushed aside and down where anyone
## (Grass.PUSHERS, the nearest MAX_PUSHERS to the camera) goes through them, as
## the grass is. The bending is all in the vertex shader: nothing to work out per plant.
const PLANT := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec4 pushers[8];
uniform int pusher_count = 0;
uniform float sway = 0.03;

#include "res://scripts/plant_push.gdshaderinc"

void vertex() {
	VERTEX += bent(MODEL_MATRIX, VERTEX, max(VERTEX.y, 0.0), sway, TIME);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
"""

## Bushes: on each card of a bush (UV 0..1 over it; UV2: a number at random for
## the card, or less than 0 for a stem, drawn solid, and how far out and up in
## the bush it is, 0..1) a spray of leaves, each a pointed oval with a darker
## midrib and a shade of its own; all cut out of the card (alpha scissor). Far
## off, where a leaf would be too small to see, the spray's outline filled in
## instead, so that it neither shimmers nor thins away. Sways, and is pushed
## aside, as the other plants are.
const BUSH := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec4 pushers[8];
uniform int pusher_count = 0;
uniform float sway = 0.03;

#include "res://scripts/plant_push.gdshaderinc"

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	VERTEX += bent(MODEL_MATRIX, VERTEX, max(VERTEX.y, 0.0), sway, TIME);
}

void fragment() {
	float which = UV2.x;
	vec3 colour = COLOR.rgb;
	float cover = 1.0;
	if (which >= 0.0) {
		vec2 q = UV * 2.0 - 1.0;
		float px = fwidth(q.x) + fwidth(q.y);
		float leaves = 0.0;
		float rib = 0.0;
		float shade = 1.0;
		// (six leaves from about the middle, fanned out every way)
		for (int k = 0; k < 6; k++) {
			float r = hash(which * 97.0 + float(k) * 7.31);
			float turn = float(k) * 1.047 + which * 6.283 + (r - 0.5) * 0.7;
			vec2 along = vec2(cos(turn), sin(turn));
			vec2 from = q - along * (0.08 + 0.12 * r);
			float x = dot(from, along);
			float y = dot(from, vec2(-along.y, along.x));
			float length_ = 0.62 + 0.3 * r;
			float t = clamp(x / length_, 0.0, 1.0);
			float wide = 0.24 * pow(sin(3.14159 * t), 0.8) * (0.8 + 0.3 * r);
			float inside = step(0.0, x) * step(x, length_) * (1.0 - smoothstep(wide - px, wide + px, abs(y)));
			if (inside > leaves) {
				shade = 0.85 + 0.3 * r;
				rib = (1.0 - smoothstep(0.0, 0.015 + px, abs(y))) * step(t, 0.85);
			}
			leaves = max(leaves, inside);
		}
		// Far off: the spray's outline filled in.
		float coarse = clamp(px * 6.0 - 0.6, 0.0, 1.0);
		cover = mix(leaves, step(length(q), 0.85), coarse);
		colour *= mix(shade, 1.0, coarse);
		colour = mix(colour, colour * 0.7, rib * (1.0 - coarse));
	}
	ALPHA = cover;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	// (lit as the mass it is part of, the same from both sides of a card)
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
"""

## Ferns: each frond a folded card along its arch (UV: metres along it, and -1..1
## across; UV2: 1, and its length; the colour's alpha, half its widest reach in
## metres, halved), and on it the frond drawn as the pines' needles are: a stem
## up its middle, leaflets either side slanting towards its tip, each with notched
## edges, longest a third of the way along and shortening to the tip; all cut out
## of the card (alpha scissor). Darker at the stem, paler at the leaflets' tips,
## each a shade of its own. Far off, where a leaflet would be too small to see,
## the frond's outline filled in instead, so it neither shimmers nor thins away.
## Sways, and is pushed aside, as the other plants are.
const FERN := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;

// Metres between leaflets along a frond, and between the notches along a leaflet.
const float PINNA = 0.065;
const float NOTCH = 0.014;

uniform vec4 pushers[8];
uniform int pusher_count = 0;
uniform float sway = 0.05;

varying float half_width;

#include "res://scripts/plant_push.gdshaderinc"

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

// How far the leaflets reach, 0..1 of the widest, `s` of the way along the frond:
// short at its foot, longest a third of the way up, to a point at its tip.
float outline(float s) {
	return pow(max(sin(PI * (0.06 + 0.94 * clamp(s, 0.0, 1.0))), 0.0), 0.75) * (1.0 - 0.25 * s);
}

void vertex() {
	half_width = COLOR.a * 2.0;
	float s = UV.x / max(UV2.y, 0.01);
	// (the frond bends more out towards its tip; a vertex's own height says little on a frond that arches over)
	VERTEX += bent(MODEL_MATRIX, VERTEX, s * UV2.y * 0.7, sway, TIME);
}

void fragment() {
	float x = UV.x;
	float s = x / max(UV2.y, 0.01);
	float hw = max(half_width, 0.04);
	float out_m = abs(UV.y) * hw;
	float side = UV.y < 0.0 ? 1.0 : 0.0;
	float reach = outline(s) * hw;

	// The leaflet this is on: they leave the stem slanted towards the tip, the two
	// sides staggered. (`across` is metres from its middle; `into` how far out along it.)
	float u = x - out_m * 0.7 + side * PINNA * 0.5;
	float index = floor(u / PINNA) + side * 211.0;
	float r = hash(index);
	float across = (fract(u / PINNA) - 0.5) * PINNA;
	float into = clamp(out_m / max(reach, 0.01), 0.0, 1.0);
	// (broad at the stem, narrowing to a rounded tip; its edge notched)
	float notches = 0.78 + 0.22 * abs(sin(out_m / NOTCH * PI + r * 3.0));
	float wide = PINNA * 0.3 * (1.0 - into * into * 0.75) * notches;
	float px = fwidth(x / PINNA);
	float leaflet = (1.0 - smoothstep(wide - 0.002, wide + 0.002 + fwidth(across), abs(across))) * step(out_m, reach * mix(0.85, 1.0, r));
	float stem = (1.0 - smoothstep(0.004, 0.004 + fwidth(out_m), out_m)) * step(s, 0.98);
	float near_cover = max(leaflet, stem);
	// Far off: the outline filled in.
	float coarse = clamp(px * 1.4 - 0.5, 0.0, 1.0);
	float cover = mix(near_cover, step(out_m, reach * 0.85), coarse);
	ALPHA = clamp(cover, 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = 0.5;

	vec3 colour = COLOR.rgb;
	colour *= mix(0.7, 1.25, into) * (0.88 + 0.24 * r);
	colour = mix(colour, vec3(0.1, 0.11, 0.05), stem * (1.0 - coarse) * 0.7);
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	// (lit the same from both sides)
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
"""


static func _shaded(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var made := ShaderMaterial.new()
	made.shader = shader
	return made


## Who is going through the plants: the nearest Grass.MAX_PUSHERS of the grass's
## pushers to the camera, to both shaders, once a frame (they are shared by every
## patch of plants).
static var _pushed_frame := -1


func _process(_delta: float) -> void:
	var frame := Engine.get_process_frames()
	if frame == _pushed_frame or _material == null:
		return
	_pushed_frame = frame
	var camera := get_viewport().get_camera_3d()
	var found: Array = get_tree().get_nodes_in_group(Grass.PUSHERS).filter(func(n: Node) -> bool: return n is Node3D and n.is_inside_tree())
	if camera and found.size() > Grass.MAX_PUSHERS:
		var eye := camera.global_position
		found.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_squared_to(eye) < b.global_position.distance_squared_to(eye))
	var packed := PackedVector4Array()
	packed.resize(Grass.MAX_PUSHERS)
	var n := mini(found.size(), Grass.MAX_PUSHERS)
	for i in n:
		var at: Vector3 = (found[i] as Node3D).global_position
		packed[i] = Vector4(at.x, at.y, at.z, (found[i] as Node).get_meta(&"grass_radius", 0.7))
	for made: ShaderMaterial in [_material, _fern_material, _bush_material]:
		made.set_shader_parameter(&"pushers", packed)
		made.set_shader_parameter(&"pusher_count", n)

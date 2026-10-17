class_name GrieverLook
## What a Griever (scripts/enemies/griever.gd) is made of, to look at: the lump
## of flesh, and the three shapes every metal part is drawn from.
##
## The flesh is one mesh: a lumpy, sagging ball, worked out here once, that its
## shader makes breathe, sag between the legs, slop about when it starts and
## stops, and shine wet. Veins and raw patches are worked out from where on the
## lump a point is; nothing is a picture.
##
## The metal (legs, pistons, hinges, the tail, the stinger, quills) is three
## MultiMeshes, one for each shape (a tapered six-sided bar, a hinge drum and a
## spike), each one draw call however many parts there are. Their instance
## colours are the tone of each part.
##
## Both are lit the way the figures are (scripts/toon.gd): hard bands of light,
## a stepped highlight, so that the creature sits in the game's look.

## Body space: forward is -Z, up is +Y, the middle of the lump at the origin.
const RADII := Vector3(1.55, 1.1, 2.15)

const FLESH_SHADER := """
shader_type spatial;
render_mode cull_back;

uniform vec3 flesh : source_color = vec3(0.42, 0.33, 0.35);
uniform vec3 raw : source_color = vec3(0.45, 0.12, 0.15);
uniform vec3 pale : source_color = vec3(0.62, 0.56, 0.47);
uniform vec3 vein : source_color = vec3(0.2, 0.1, 0.22);
uniform vec3 through : source_color = vec3(0.8, 0.22, 0.2);
// Set each frame by the Griever: how far the lump has slopped (body space,
// metres), how far it has bounced down, the breath (-1..1) and the heartbeat (0..1).
uniform vec3 jiggle = vec3(0.0);
uniform float bounce = 0.0;
uniform float breath = 0.0;
uniform float pulse = 0.0;
uniform float sag = 0.22;
uniform float wrap = 0.3;
uniform float bump = 0.16;

varying vec3 obj;
varying float hang;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void vertex() {
	obj = VERTEX;
	hang = COLOR.r;
	float top = clamp(VERTEX.y * 0.55 + 0.5, 0.0, 1.0);
	vec3 v = VERTEX;
	// Breathing, and a throb that the parts slung low feel least.
	v += NORMAL * (breath * 0.045 + pulse * 0.03 * (1.0 - hang * 0.6));
	// The lump slops after the frame it hangs on: the top most.
	v += jiggle * (0.2 + 0.8 * top);
	// It sags between the legs, and bounces as it is carried.
	v.y -= hang * (sag + bounce);
	// Slow ripples across it, livelier when it has been shaken.
	float ripple = sin(TIME * 5.3 + dot(VERTEX, vec3(2.3, 3.1, 1.7))) + sin(TIME * 3.7 - dot(VERTEX, vec3(-1.9, 2.2, 2.9)));
	v += NORMAL * ripple * (0.008 + length(jiggle) * 0.08);
	VERTEX = v;
}

void fragment() {
	vec3 p = obj;
	float pixel = max(length(fwidth(p)), 0.0002);
	// Mottled grey meat, raw red where it is stretched, lumps of pale fat,
	// darker underneath where it hangs.
	float mottle = noise3(p * 1.4) * 0.65 + noise3(p * 3.7 + 7.0) * 0.35;
	vec3 colour = mix(flesh, raw, smoothstep(0.58, 0.8, mottle) * 0.85);
	colour = mix(colour, pale, smoothstep(0.62, 0.8, noise3(p * 2.1 + 13.0)) * 0.4);
	colour *= mix(0.55, 1.0, smoothstep(-0.9, 0.2, p.y));
	// Veins: dark lines along the middle of a field of noise (thick ones), and
	// finer ones in patches, filling and emptying with the heartbeat.
	float a = abs(noise3(p * 1.5 + vec3(3.1, 0.0, 1.7)) - 0.5);
	float b = abs(noise3(p * 3.4 + vec3(9.0, 4.0, 2.0)) - 0.5);
	float width = (0.012 + 0.016 * noise3(p * 0.7 + 5.0)) + pulse * 0.008;
	float big = 1.0 - smoothstep(width - pixel, width + pixel, a);
	float small = (1.0 - smoothstep(0.014 - pixel, 0.014 + pixel, b)) * smoothstep(0.45, 0.6, noise3(p * 0.9 + 21.0));
	float veins = max(big, small * 0.8) * clamp(0.05 / pixel, 0.0, 1.0);
	colour = mix(colour, vein, veins * 0.7);
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// A little red light of its own in the veins, as if it were lit through.
	EMISSION = through * veins * (0.03 + pulse * 0.1);
	// Wet, uneven skin: the surface is bumped by noise, so the light breaks
	// up into many small glints rather than one smooth spot.
	float e = 0.06;
	vec3 q = p * 3.3;
	float n0 = noise3(q);
	vec3 slope = vec3(noise3(q + vec3(e, 0, 0)) - n0, noise3(q + vec3(0, e, 0)) - n0, noise3(q + vec3(0, 0, e)) - n0) / e;
	vec3 tilt = (VIEW_MATRIX * MODEL_MATRIX * vec4(slope, 0.0)).xyz;
	NORMAL = normalize(NORMAL - tilt * bump);
	// Slime: the bright sky caught on it in broken streaks, shadow or not.
	vec3 sky_up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float sky = cut(dot(reflect(-VIEW, NORMAL), sky_up), 0.5) * cut(noise3(p * 5.0 + 3.0), 0.35);
	float side_on = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION += vec3(0.72, 0.78, 0.8) * sky * (0.15 + 0.25 * side_on);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float amount = facing * smoothstep(0.15, 0.6, reach);
	float lit = cut(amount, 0.04);
	float core = cut(amount, 0.7);
	DIFFUSE_LIGHT += (lit * 0.88 + core * 0.12) * LIGHT_COLOR / PI;
	// Light comes through the jelly: the shadow side glows red, most where it
	// is seen with the light behind it.
	float behind = clamp(dot(VIEW, -LIGHT) * 0.5 + 0.5, 0.0, 1.0);
	DIFFUSE_LIGHT += (1.0 - lit) * through * (0.14 + 0.35 * behind * behind) * LIGHT_COLOR / PI;
	// Wet: hard bright glints, and a broader faint sheen.
	vec3 half_way = normalize(LIGHT + VIEW);
	float shine = max(dot(NORMAL, half_way), 0.0);
	float glint = cut(pow(shine, 24.0), 0.5);
	float sheen = cut(pow(shine, 8.0), 0.6);
	SPECULAR_LIGHT += (glint * 1.0 + sheen * 0.1) * lit * reach * LIGHT_COLOR;
	// A slick rim.
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	SPECULAR_LIGHT += cut(graze, 0.8) * lit * 0.15 * LIGHT_COLOR * pale;
}
"""

const METAL_SHADER := """
shader_type spatial;
render_mode cull_back;

uniform float wrap = 0.15;
uniform float gloss = 18.0;
uniform float shine = 0.9;

varying vec3 tint;

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void vertex() {
	tint = COLOR.rgb;
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// A bright edge side-on, as worn metal has.
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = tint * cut(graze, 0.82) * 0.25;
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = cut(facing * smoothstep(0.15, 0.6, reach), 0.04);
	DIFFUSE_LIGHT += lit * LIGHT_COLOR / PI;
	float caught = pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), gloss);
	float stepped = cut(caught, 0.3) * 0.4 + cut(caught, 0.65) * 0.6;
	SPECULAR_LIGHT += stepped * shine * lit * LIGHT_COLOR * mix(vec3(1.0), ALBEDO * 2.0, 0.35);
}
"""

static var _flesh_shader: Shader
static var _metal_shader: Shader
static var _metal: ShaderMaterial
static var _flesh_mesh: ArrayMesh
static var _bar: ArrayMesh
static var _drum: ArrayMesh
static var _spike: ArrayMesh


## A material for one Griever's flesh (each has its own: it is shaken by its own steps).
static func flesh_material() -> ShaderMaterial:
	if _flesh_shader == null:
		_flesh_shader = Shader.new()
		_flesh_shader.code = FLESH_SHADER
	var material := ShaderMaterial.new()
	material.shader = _flesh_shader
	return material


## The metal, shared by every Griever: the tone of each part is its instance colour.
static func metal_material() -> ShaderMaterial:
	if _metal == null:
		_metal_shader = Shader.new()
		_metal_shader.code = METAL_SHADER
		_metal = ShaderMaterial.new()
		_metal.shader = _metal_shader
	return _metal


## Where on the lump a direction from its middle comes out (body space), lumps and all.
static func surface(direction: Vector3) -> Vector3:
	var d := direction.normalized()
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 1313
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 1.0
	var r := 1.0
	# Lumps and folds, fixed: the same creature every time.
	r += 0.07 * sin(d.x * 5.0 + 1.3) * sin(d.z * 4.0 + 0.4)
	r += 0.05 * sin(d.y * 7.0 + d.x * 3.0)
	for bulge: Vector4 in BULGES:
		var at := Vector3(bulge.x, bulge.y, bulge.z).normalized()
		r += bulge.w * exp(-(1.0 - d.dot(at)) * 9.0)
	# Soft swellings, and creases between them (a ridged noise turned inwards).
	var q := d * 2.2
	r += 0.07 * _noise.get_noise_3d(q.x, q.y, q.z)
	q = d * 5.5 + Vector3(11.0, 3.0, 7.0)
	r -= 0.045 * pow(1.0 - absf(_noise.get_noise_3d(q.x, q.y, q.z)), 6.0)
	q = d * 11.0 + Vector3(-4.0, 9.0, 2.0)
	r += 0.012 * _noise.get_noise_3d(q.x, q.y, q.z)
	var p := d * RADII * r
	# Heavier below: it hangs.
	if p.y < 0.0:
		p.y *= 1.12
	return p


static var _noise: FastNoiseLite


## Swellings (direction, how much: less than 0 is a fold in).
const BULGES: Array[Vector4] = [
	Vector4(0.5, 0.7, -0.3, 0.14), Vector4(-0.6, 0.6, 0.2, 0.12), Vector4(0.1, 0.5, 0.8, 0.18),
	Vector4(-0.2, 0.8, -0.6, 0.1), Vector4(0.8, -0.2, 0.4, 0.1), Vector4(-0.8, -0.1, -0.5, 0.12),
	Vector4(0.0, 0.3, -1.0, 0.08), Vector4(0.3, 1.0, 0.1, -0.06), Vector4(-0.4, 0.2, 0.9, -0.05),
]


## The flesh: an icosphere bent into the lump. Vertex colour red is how far it
## hangs (the underside, away from where the legs hold it up), given `hips`.
static func flesh_mesh(hips: Array) -> ArrayMesh:
	if _flesh_mesh != null:
		return _flesh_mesh
	var verts: Array[Vector3] = []
	var faces: Array[Vector3i] = []
	var t := (1.0 + sqrt(5.0)) / 2.0
	for v: Vector3 in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		verts.append(v.normalized())
	for f: Vector3i in [Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10), Vector3i(0, 10, 11),
			Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2), Vector3i(10, 7, 6), Vector3i(7, 1, 8),
			Vector3i(3, 9, 4), Vector3i(3, 4, 2), Vector3i(3, 2, 6), Vector3i(3, 6, 8), Vector3i(3, 8, 9),
			Vector3i(4, 9, 5), Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7), Vector3i(9, 8, 1)]:
		faces.append(f)
	for level in 4:
		var middles := {}
		var next: Array[Vector3i] = []
		for f: Vector3i in faces:
			var a := _middle(verts, middles, f.x, f.y)
			var b := _middle(verts, middles, f.y, f.z)
			var c := _middle(verts, middles, f.z, f.x)
			next.append_array([Vector3i(f.x, a, c), Vector3i(f.y, b, a), Vector3i(f.z, c, b), Vector3i(a, b, c)])
		faces = next
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v: Vector3 in verts:
		var p := surface(v)
		# Hangs: below the middle, and the further from a hip the more.
		var near := 9.0
		for hip: Vector3 in hips:
			near = minf(near, p.distance_to(hip))
		var hang := smoothstep(0.1, -0.7, v.y) * smoothstep(0.3, 1.1, near)
		tool.set_color(Color(hang, 0.0, 0.0))
		tool.add_vertex(p)
	for f: Vector3i in faces:
		# (clockwise seen from outside)
		tool.add_index(f.x)
		tool.add_index(f.z)
		tool.add_index(f.y)
	tool.generate_normals()
	_flesh_mesh = tool.commit()
	return _flesh_mesh


static func _middle(verts: Array[Vector3], middles: Dictionary, a: int, b: int) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if middles.has(key):
		return middles[key]
	verts.append(((verts[a] + verts[b]) * 0.5).normalized())
	middles[key] = verts.size() - 1
	return verts.size() - 1


## A six-sided bar along +Y from 0 to 1, radius 1 at the bottom and 0.72 at the
## top, flat-faced. Placed by GrieverLook.between.
static func bar() -> ArrayMesh:
	if _bar == null:
		_bar = _prism(6, 1.0, 0.72, Vector3.UP, 0.0)
	return _bar


## A hinge drum: an eight-sided cylinder along X, radius 1, from -0.5 to 0.5.
static func drum() -> ArrayMesh:
	if _drum == null:
		_drum = _prism(8, 1.0, 1.0, Vector3.RIGHT, -0.5)
	return _drum


## A spike: a six-sided cone along +Y from 0 to 1, radius 1 at its base.
static func spike() -> ArrayMesh:
	if _spike == null:
		_spike = _prism(6, 1.0, 0.0, Vector3.UP, 0.0)
	return _spike


static func _prism(sides: int, bottom: float, top: float, axis: Vector3, start: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var u := Vector3.RIGHT if axis == Vector3.UP else Vector3.UP
	var w := axis.cross(u)
	var ring := func(i: int, radius: float) -> Vector3:
		var angle := TAU * (i + 0.5) / sides
		return (u * cos(angle) + w * sin(angle)) * radius
	var lo := axis * start
	var hi := axis * (start + 1.0)
	for i in sides:
		var a0: Vector3 = lo + ring.call(i, bottom)
		var a1: Vector3 = lo + ring.call(i + 1, bottom)
		var b0: Vector3 = hi + ring.call(i, top)
		var b1: Vector3 = hi + ring.call(i + 1, top)
		var normal := (a1 - a0).cross(b0 - a0).normalized()
		if normal.dot(ring.call(i, 1.0) + ring.call(i + 1, 1.0)) < 0.0:
			normal = -normal
		_quad(tool, a0, a1, b1, b0, normal)
		if bottom > 0.0:
			_tri(tool, lo, a1, a0, -axis)
		if top > 0.0:
			_tri(tool, hi, b0, b1, axis)
	return tool.commit()


## A triangle, wound to face `normal`.
static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	tool.set_normal(normal)
	if (b - a).cross(c - a).dot(normal) > 0.0:
		# (Godot's front faces are clockwise)
		for p: Vector3 in [a, c, b]:
			tool.add_vertex(p)
	else:
		for p: Vector3 in [a, b, c]:
			tool.add_vertex(p)


static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	_tri(tool, a, b, c, normal)
	_tri(tool, a, c, d, normal)


## A MultiMesh of `count` parts of `mesh`, with colours, all hidden to start.
static func parts(mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = count
	multi.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = metal_material()
	node.top_level = true
	return node


## The transform that stretches a bar or spike from `a` to `b`, `thick` across.
## `side` is a hint for which way its faces turn.
static func between(a: Vector3, b: Vector3, thick: float, side := Vector3.UP) -> Transform3D:
	var along := b - a
	if along.length_squared() < 0.000001:
		along = Vector3.UP * 0.001
	var x := along.cross(side)
	if x.length_squared() < 0.000001:
		x = along.cross(Vector3.RIGHT)
		if x.length_squared() < 0.000001:
			x = along.cross(Vector3.FORWARD)
	x = x.normalized()
	var z := x.cross(along.normalized())
	return Transform3D(Basis(x * thick, along, z * thick), a)


## A hinge drum at `at`, turning about `axis`, `radius` round and `wide` across.
static func hinge(at: Vector3, axis: Vector3, radius: float, wide: float) -> Transform3D:
	var x := axis.normalized()
	var y := x.cross(Vector3.UP)
	if y.length_squared() < 0.0001:
		y = x.cross(Vector3.FORWARD)
	y = y.normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x * wide, y * radius, z * radius), at)

class_name CentipedeParts
## What a CentipedeBody is made of, to look at: the shapes and the one shader
## they all share. Everything is made here in code, once, and shared by every
## centipede.
##
## - `plate()`: one length of its body, after a Scolopendra's. On top a domed,
##   squarish plate of armour (the tergite), wider than it is long, with a
##   raised rim round its sides and back edge and two grooves down its length;
##   its sides tucked in under the rim; a flatter plate underneath (the
##   sternite); and in front a narrower collar of pale soft skin, which lies
##   under the plate in front and shows when the body bends.
## - `head()`: a flattened shield, rounded in front, a groove down the middle.
## - `bar()`: a round, tapering, slightly swollen length, from which every
##   joint of a leg, each bead of a feeler and the poison claws are drawn.
## - `spike()`: a cone, for the claw at the end of each leg and the fangs.
##
## The shader is cel shading like the figures' (two flat tones with a hard
## edge) with the gloss of chitin over it: a sharp stepped highlight, and the
## overcast sky caught on its back in broken streaks. Colours come in as
## uniforms; a point's vertex colour (plates, head) or instance colour (bars,
## spikes) only says how much of each it takes:
##
## - plates and head: red, shell (else the pale underside); green, the rim;
##   blue, the soft skin between the plates.
## - bars and spikes: red, shell-coloured (else leg-coloured); green, how much
##   it darkens towards its end; blue, black; alpha, the head's tone.
## - the head's tone (its own deeper, redder shell) comes from the instance
##   colour's alpha on the plates (the first length or two have it; their
##   instance colour is otherwise white) and is all of the head.

const SHADER := """
shader_type spatial;
render_mode cull_back;

uniform vec3 shell : source_color = vec3(0.12, 0.055, 0.04);
uniform vec3 head_shell : source_color = vec3(0.3, 0.11, 0.05);
uniform vec3 rim : source_color = vec3(0.4, 0.2, 0.1);
uniform vec3 under : source_color = vec3(0.46, 0.34, 0.2);
uniform vec3 membrane : source_color = vec3(0.56, 0.46, 0.38);
uniform vec3 leg : source_color = vec3(0.6, 0.42, 0.22);
uniform vec3 tip : source_color = vec3(0.04, 0.025, 0.02);
// 0: the plates, 1: the head, 2: bars and spikes. (The plates' and bars' instance colour alpha is the head's tone.)
uniform int mode = 0;
uniform float wrap = 0.2;
uniform float gloss = 90.0;
uniform float shine = 0.7;
uniform float sky = 0.2;

varying vec3 mixes;
varying float tone;
varying vec3 obj;

float cut(float value, float e) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(e - pixel, e + pixel, value);
}

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

void vertex() {
	mixes = COLOR.rgb;
	obj = VERTEX;
	tone = mode == 1 ? 1.0 : COLOR.a;
}

void fragment() {
	vec3 top = mix(shell, head_shell, tone);
	vec3 colour;
	float glossy;
	if (mode < 2) {
		colour = mix(under, top, mixes.r);
		colour = mix(colour, rim, mixes.g);
		colour = mix(colour, membrane, mixes.b);
		// (UV.x: the grooves, darker)
		colour *= 1.0 - 0.55 * UV.x;
		// (pits and scratches in the armour)
		colour *= 0.88 + 0.24 * noise3(obj * 14.0);
		glossy = mixes.r * (1.0 - mixes.b);
	} else {
		colour = mix(leg, top, mixes.r);
		colour = mix(colour, tip, mixes.g * smoothstep(0.45, 1.0, UV.y));
		colour = mix(colour, tip, mixes.b);
		glossy = 0.35 + 0.65 * max(mixes.r, mixes.b);
	}
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// The overcast sky caught on it in broken streaks, shadow or not: it is glossy.
	vec3 sky_up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float caught = cut(dot(reflect(-VIEW, NORMAL), sky_up), 0.55);
	float broken = cut(noise3(obj * 4.0 + 5.0), 0.5);
	float side_on = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = vec3(0.7, 0.74, 0.76) * caught * broken * sky * glossy * (0.05 + 0.45 * side_on * side_on);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = cut(facing * smoothstep(0.15, 0.6, reach), 0.04);
	DIFFUSE_LIGHT += lit * mix(reach, 1.0, 0.5) * LIGHT_COLOR / PI;
	// A sharp stepped highlight, a little of its own colour in it.
	float caught = pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), gloss);
	float stepped = cut(caught, 0.6) * 0.25 + cut(caught, 0.9) * 0.55;
	SPECULAR_LIGHT += stepped * shine * lit * reach * LIGHT_COLOR * mix(vec3(1.0), ALBEDO * 4.0, 0.3);
	// (a thin rim on the outline, in its own colour)
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	SPECULAR_LIGHT += cut(graze, 0.92) * lit * 0.3 * LIGHT_COLOR * (ALBEDO + vec3(0.04)) / PI;
}
"""

## How far forward of the middle of a length its collar of soft skin reaches,
## and how far back its plate laps over the next (as shares of its length).
const COLLAR := 0.3
const LAP := 0.06

static var _shader: Shader
static var _bar: ArrayMesh
static var _spike: ArrayMesh
static var _plate: ArrayMesh
static var _head: ArrayMesh


## A material in these colours (keys as the shader's uniforms) for the plates
## (`mode` 0), the head (1), or the bars and spikes (2).
static func material(colours: Dictionary, mode: int) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var made := ShaderMaterial.new()
	made.shader = _shader
	for key: String in colours:
		made.set_shader_parameter(key, colours[key])
	made.set_shader_parameter(&"mode", mode)
	if mode == 2:
		made.set_shader_parameter(&"shine", 0.45)
		made.set_shader_parameter(&"gloss", 60.0)
	return made


## One length of its body: a metre wide (x from -0.5 to 0.5), forward along +Z,
## its plate from z = -0.5 - LAP (the back edge, lapping over the next) to 0.5,
## and its collar of soft skin on to 0.5 + COLLAR. Scaled where it is drawn.
static func plate() -> ArrayMesh:
	if _plate == null:
		var rings: Array = []
		# The plate, back edge to front: (z, half width, height of the dome, depth below, soft skin?)
		for k in 11:
			var t := k / 10.0
			var z := lerpf(-0.5 - LAP, 0.5, t)
			# (t: 0 at the back edge, 1 at the front)
			var back_lip := smoothstep(0.0, 0.08, t)
			var w := lerpf(0.5, 0.45, smoothstep(0.35, 1.0, t)) * lerpf(0.93, 1.0, back_lip)
			var h := lerpf(0.21, 0.17, smoothstep(0.3, 1.0, t)) * lerpf(0.75, 1.0, back_lip)
			rings.append([z, w, h, 0.16, 0.0, 1.0 - back_lip])
		for k in 4:
			var t := (k + 1) / 4.0
			rings.append([0.5 + COLLAR * t, lerpf(0.4, 0.34, t), lerpf(0.11, 0.08, t), 0.13, 1.0, 0.0])
		_plate = _loft(rings, 22, true)
	return _plate


## Its head: a flattened shield, a metre wide and a metre long (z from -0.5 at
## its neck to 0.5 at its front), rounded in front, a little narrower behind.
static func head() -> ArrayMesh:
	if _head == null:
		var rings: Array = []
		for k in 15:
			var t := k / 14.0
			# (t: 0 at the neck, 1 at the front)
			var z := lerpf(-0.5, 0.5, t)
			var front := 1.0 - t
			var round_front := sqrt(clampf(front / 0.32, 0.0, 1.0))
			var w := 0.5 * lerpf(0.5, 1.0, round_front) * lerpf(0.86, 1.0, smoothstep(0.0, 0.35, t))
			var h := 0.11 * lerpf(0.55, 1.0, round_front)
			rings.append([z, w, h, 0.085 * lerpf(0.6, 1.0, round_front), 0.0, 0.0])
		_head = _loft(rings, 28, false)
	return _head


## A round bar along +Y from 0 to 1, swollen a little just above its bottom
## and tapering to 0.55 at the top: a joint of a leg. Placed by `between`.
static func bar() -> ArrayMesh:
	if _bar == null:
		_bar = _turned([[0.0, 0.8], [0.08, 1.0], [0.4, 0.92], [1.0, 0.55]], 6, true)
	return _bar


## A cone along +Y from 0 (radius 1) to a point at 1, a little swollen at its base.
static func spike() -> ArrayMesh:
	if _spike == null:
		_spike = _turned([[0.0, 0.9], [0.15, 1.0], [0.6, 0.5], [1.0, 0.0]], 6, false)
	return _spike


## The transform that stretches a bar or spike from `a` to `b`, `thick` across, its faces turned by `side`.
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


# A closed tube along +Z through `rings` ([z, half width, dome height, depth
# below, soft skin 0..1, back lip 0..1] each), its cross-section the body's: a
# domed top over a flatter underside, its sides tucked in under the edge of the
# dome. With `armoured`, the dome has a raised rim and two grooves down it.
static func _loft(rings: Array, around: int, armoured: bool) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[PackedVector3Array] = []
	var tints: Array[PackedColorArray] = []
	var grooves: Array[PackedFloat32Array] = []
	for ring: Array in rings:
		var z: float = ring[0]
		var w: float = ring[1]
		var h: float = ring[2]
		var d: float = ring[3]
		var skin: float = ring[4]
		var lip: float = ring[5]
		var at := PackedVector3Array()
		var tint := PackedColorArray()
		var dark := PackedFloat32Array()
		for i in around:
			var angle := TAU * i / around
			var c := cos(angle)
			var s := sin(angle)
			# (squarer than a circle across, and the sides tucked in below the edge of the dome)
			var across := signf(c) * pow(absf(c), 0.6)
			var x := across * w * (1.0 if s >= 0.0 else lerpf(1.0, 0.85, smoothstep(0.0, 0.35, -s)))
			var y := 0.0
			var shell := 0.0
			var edge := 0.0
			var in_groove := 0.0
			if s >= 0.0:
				var out := absf(x) / maxf(w, 0.001)
				y = h * pow(maxf(1.0 - pow(out, 2.6), 0.0), 0.5)
				shell = smoothstep(0.02, 0.15, s) * (1.0 - skin)
				if armoured and skin < 0.5:
					# The rim, raised round the sides and along the back edge; the grooves down the middle.
					var side_rim := exp(-pow((out - 0.9) / 0.06, 2.0))
					y += h * 0.13 * side_rim + h * 0.1 * lip
					var groove := exp(-pow((absf(x) - 0.13) / 0.025, 2.0))
					y -= h * 0.2 * groove
					in_groove = groove * shell
					edge = clampf(side_rim * 0.8 + lip * 0.9, 0.0, 1.0) * shell
				elif not armoured:
					y -= h * 0.12 * exp(-pow(x / 0.035, 2.0))
					in_groove = exp(-pow(x / 0.03, 2.0)) * 0.8
					edge = exp(-pow((out - 0.94) / 0.05, 2.0)) * 0.6
			else:
				y = -d * pow(absf(s), 0.45)
			at.append(Vector3(x, y, z))
			tint.append(Color(shell, edge, skin))
			dark.append(in_groove)
		points.append(at)
		tints.append(tint)
		grooves.append(dark)
	for r in rings.size() - 1:
		for i in around:
			var j := (i + 1) % around
			_vert_tri(tool, [points[r][i], points[r + 1][j], points[r][j]], [tints[r][i], tints[r + 1][j], tints[r][j]], [grooves[r][i], grooves[r + 1][j], grooves[r][j]])
			_vert_tri(tool, [points[r][i], points[r + 1][i], points[r + 1][j]], [tints[r][i], tints[r + 1][i], tints[r + 1][j]], [grooves[r][i], grooves[r + 1][i], grooves[r + 1][j]])
	# The ends, closed.
	var last := rings.size() - 1
	for end: int in [0, last]:
		var middle := Vector3(0.0, 0.0, points[end][0].z)
		for i in around:
			var j := (i + 1) % around
			var tri := [middle, points[end][i], points[end][j]] if end == 0 else [middle, points[end][j], points[end][i]]
			_vert_tri(tool, tri, [tints[end][i], tints[end][j], tints[end][i]], [0.0, 0.0, 0.0])
	tool.generate_normals()
	return tool.commit()


# A shape turned round +Y through `rings` ([y, radius] each), smooth-shaded,
# UV.y how far along; closed at the bottom (and at the top with `capped`).
static func _turned(rings: Array, sides: int, capped: bool) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rings.size() - 1:
		var y0: float = rings[r][0]
		var y1: float = rings[r + 1][0]
		var w0: float = rings[r][1]
		var w1: float = rings[r + 1][1]
		var slope := (w0 - w1) / maxf(y1 - y0, 0.01)
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var d0 := Vector3(cos(a0), 0.0, sin(a0))
			var d1 := Vector3(cos(a1), 0.0, sin(a1))
			var p := [d0 * w0 + Vector3.UP * y0, d1 * w0 + Vector3.UP * y0, d1 * w1 + Vector3.UP * y1, d0 * w1 + Vector3.UP * y1]
			var n0 := (d0 + Vector3.UP * slope * 0.5).normalized()
			var n1 := (d1 + Vector3.UP * slope * 0.5).normalized()
			var n := [n0, n1, n1, n0]
			for k: int in [0, 1, 2, 0, 2, 3]:
				tool.set_normal(n[k])
				tool.set_color(Color(1, 1, 1))
				tool.set_uv(Vector2(0.0, (p[k] as Vector3).y))
				tool.add_vertex(p[k])
	var ends := [0, rings.size() - 1] if capped else [0]
	for e: int in ends:
		var y: float = rings[e][0]
		var w: float = rings[e][1]
		if w <= 0.0:
			continue
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var middle := Vector3.UP * y
			var p0 := Vector3(cos(a0) * w, y, sin(a0) * w)
			var p1 := Vector3(cos(a1) * w, y, sin(a1) * w)
			_tri(tool, middle, p0, p1, Vector3.UP if e > 0 else Vector3.DOWN)
	return tool.commit()


static func _vert_tri(tool: SurfaceTool, corners: Array, colours: Array, dark: Array) -> void:
	# (Godot's front faces are clockwise seen from outside: the loft runs so that these are)
	for k: int in [0, 1, 2]:
		tool.set_color(colours[k])
		tool.set_uv(Vector2(dark[k], 0.0))
		tool.add_vertex(corners[k])


## A triangle, wound to face `normal`.
static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	tool.set_normal(normal)
	tool.set_color(Color(1, 1, 1))
	var order := [a, c, b] if (b - a).cross(c - a).dot(normal) > 0.0 else [a, b, c]
	for p: Vector3 in order:
		tool.set_uv(Vector2(0.0, p.y))
		tool.add_vertex(p)

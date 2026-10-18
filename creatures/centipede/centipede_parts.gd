class_name CentipedeParts
## What a CentipedeBody is made of, to look at: the shapes (an armoured plate
## for each length of its body, its head, and one jointed bar that every leg,
## feeler and claw is drawn from) and the one shader they all share.
##
## Everything is made here in code, once, and shared by every centipede. The
## shader is cel shading like the figures' (two flat tones with a hard edge) with
## the gloss of wet chitin over it: hard stepped highlights, and the bright sky
## caught on its back in streaks, so that it shines darkly even in mist.
##
## Colours come in as uniforms (`shell`, `edge`, `under`, `leg`, `tip`); a
## point's vertex or instance colour only says how much of each it takes: red
## how much shell (else underside or leg), green the pale band at the back edge
## of a plate, blue the black of a claw's or feeler's tip.

const SHADER := """
shader_type spatial;
render_mode cull_back;

uniform vec3 shell : source_color = vec3(0.075, 0.06, 0.05);
uniform vec3 edge : source_color = vec3(0.3, 0.2, 0.12);
uniform vec3 under : source_color = vec3(0.42, 0.34, 0.22);
uniform vec3 leg : source_color = vec3(0.5, 0.4, 0.24);
uniform vec3 tip : source_color = vec3(0.04, 0.03, 0.025);
// 1 for the plates and head (vertex colours), 0 for the bars (instance colours).
uniform float plates = 1.0;
uniform float wrap = 0.2;
uniform float gloss = 90.0;
uniform float shine = 0.7;
uniform float sky = 0.3;

varying vec3 mixes;
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
}

void fragment() {
	vec3 low = plates > 0.5 ? under : leg;
	vec3 colour = mix(low, shell, mixes.r);
	if (plates > 0.5) {
		colour = mix(colour, edge, mixes.g);
	} else {
		// (a bar's green says how much it darkens towards its end: a claw at the end of a leg)
		colour = mix(colour, tip, mixes.g * smoothstep(0.5, 0.95, UV.y));
	}
	colour = mix(colour, tip, mixes.b);
	// (a little unevenness in the plates: pits and scratches)
	if (plates > 0.5) {
		colour *= 0.86 + 0.28 * noise3(obj * 9.0);
	}
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// The overcast sky caught on its back in broken streaks, shadow or not: it is glossy.
	vec3 sky_up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float caught = cut(dot(reflect(-VIEW, NORMAL), sky_up), 0.55);
	float broken = cut(noise3(obj * 3.0 + 5.0), 0.5);
	float side_on = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float glossy = plates > 0.5 ? mixes.r : 0.15 + mixes.b * 0.5;
	EMISSION = vec3(0.7, 0.74, 0.76) * caught * broken * sky * glossy * (0.05 + 0.45 * side_on * side_on);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = cut(facing * smoothstep(0.15, 0.6, reach), 0.04);
	DIFFUSE_LIGHT += lit * mix(reach, 1.0, 0.5) * LIGHT_COLOR / PI;
	float caught = pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), gloss);
	float stepped = cut(caught, 0.4) * 0.25 + cut(caught, 0.8) * 0.5;
	// (the shine of the light on it takes a little of its own colour)
	SPECULAR_LIGHT += stepped * shine * lit * reach * LIGHT_COLOR * mix(vec3(1.0), ALBEDO * 4.0, 0.3);
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	// (a thin rim on the outline, in its own colour)
	SPECULAR_LIGHT += cut(graze, 0.92) * lit * 0.3 * LIGHT_COLOR * (ALBEDO + vec3(0.04)) / PI;
}
"""

static var _shader: Shader
static var _bar: ArrayMesh
static var _plate: ArrayMesh
static var _head: ArrayMesh


## A material for the plates and head (`plates` true) or the bars, in these colours.
static func material(colours: Dictionary, plates: bool) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var made := ShaderMaterial.new()
	made.shader = _shader
	for key: String in colours:
		made.set_shader_parameter(key, colours[key])
	made.set_shader_parameter(&"plates", 1.0 if plates else 0.0)
	if not plates:
		made.set_shader_parameter(&"shine", 0.18)
		made.set_shader_parameter(&"gloss", 24.0)
	return made


## One length of its body, a metre long, a metre wide and half a metre high,
## forward along +Z: a domed plate of armour over a flatter underside, wider at
## the back and lapping over the next, with a lip and a pale band at its back
## edge and a keel down the middle of its back. Scaled where it is drawn.
static func plate() -> ArrayMesh:
	if _plate == null:
		_plate = _loft(9, 18, func(z: float) -> Vector2:
			# z: 0 at its front, 1 at its back. Half width and half height there.
			var swell := sin(PI * clampf(z * 1.15, 0.0, 1.0))
			var w := lerpf(0.36, 0.5, smoothstep(0.0, 0.75, z)) * lerpf(0.86, 1.0, swell)
			var h := lerpf(0.13, 0.2, smoothstep(0.0, 0.7, z)) * lerpf(0.8, 1.0, swell)
			if z > 0.92:
				h *= lerpf(1.0, 0.6, (z - 0.92) / 0.08)
				w *= lerpf(1.0, 0.85, (z - 0.92) / 0.08)
			return Vector2(w, h), 0.62, 1.4, true)
	return _plate


## Its head: flat and broad, rounded in front, the plate of it a little domed.
static func head() -> ArrayMesh:
	if _head == null:
		_head = _loft(10, 20, func(z: float) -> Vector2:
			# z: 0 at its snout, 1 at its neck.
			var front := sqrt(clampf(z / 0.22, 0.0, 1.0))
			var w := lerpf(0.22, 0.52, front) * lerpf(1.0, 0.86, smoothstep(0.65, 1.0, z))
			var h := lerpf(0.07, 0.21, front) * lerpf(1.0, 0.8, smoothstep(0.75, 1.0, z))
			return Vector2(w, h), 0.5, 1.0, false)
	return _head


## A six-sided bar along +Y from 0 to 1, radius 1 at the bottom and 0.6 at the top. Placed by `between`.
static func bar() -> ArrayMesh:
	if _bar == null:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		# (round, smooth-shaded, a little swollen in the middle as a leg's segment is, and capped)
		var sides := 8
		var rings := [[0.0, 0.85], [0.15, 1.0], [0.7, 0.85], [1.0, 0.6]]
		for r in rings.size() - 1:
			var y0: float = rings[r][0]
			var y1: float = rings[r + 1][0]
			var w0: float = rings[r][1]
			var w1: float = rings[r + 1][1]
			var slope := (w0 - w1) / maxf(y1 - y0, 0.01) * 0.15
			for i in sides:
				var a0 := TAU * i / sides
				var a1 := TAU * (i + 1) / sides
				var d0 := Vector3(cos(a0), 0.0, sin(a0))
				var d1 := Vector3(cos(a1), 0.0, sin(a1))
				var p := [d0 * w0 + Vector3.UP * y0, d1 * w0 + Vector3.UP * y0, d1 * w1 + Vector3.UP * y1, d0 * w1 + Vector3.UP * y1]
				var n := [(d0 + Vector3.UP * slope).normalized(), (d1 + Vector3.UP * slope).normalized(), (d1 + Vector3.UP * slope).normalized(), (d0 + Vector3.UP * slope).normalized()]
				for k: int in [0, 1, 2, 0, 2, 3]:
					tool.set_normal(n[k])
					tool.set_color(Color(1, 1, 1))
					tool.set_uv(Vector2(0.0, (p[k] as Vector3).y))
					tool.add_vertex(p[k])
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			_tri(tool, Vector3.UP, Vector3(cos(a0) * 0.6, 1.0, sin(a0) * 0.6), Vector3(cos(a1) * 0.6, 1.0, sin(a1) * 0.6), Vector3.UP)
			_tri(tool, Vector3.ZERO, Vector3(cos(a0) * 0.85, 0.0, sin(a0) * 0.85), Vector3(cos(a1) * 0.85, 0.0, sin(a1) * 0.85), Vector3.DOWN)
		_bar = tool.commit()
	return _bar


## The transform that stretches a bar from `a` to `b`, `thick` across, its flat faces turned by `side`.
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


# A closed tube along +Z (z from -0.5 at the back to 0.5 at the front), its
# cross-section a squarish ellipse whose half width and height `shape` gives
# at each `z` from 0 (front) to 1 (back); the underside is flattened by
# `belly`, and the shape runs `long` times a metre (so that one plate laps over
# the next). With `banded`, the back of each plate has a pale edge and a keel.
static func _loft(rings: int, around: int, shape: Callable, belly: float, long: float, banded: bool) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[PackedVector3Array] = []
	var tints: Array[PackedColorArray] = []
	for r in rings + 1:
		var z := float(r) / rings
		var size: Vector2 = shape.call(z)
		var ring := PackedVector3Array()
		var tint := PackedColorArray()
		for i in around:
			var angle := TAU * i / around
			var c := cos(angle)
			var s := sin(angle)
			# (a superellipse: squarer than a circle)
			var x := signf(c) * pow(absf(c), 0.75) * size.x
			var y := signf(s) * pow(absf(s), 0.75 if s < 0.0 else 1.05) * size.y
			if y < 0.0:
				y *= belly
			elif banded:
				# The keel down the middle of its back.
				y += size.y * 0.2 * exp(-pow(x / (size.x * 0.1), 2.0))
			ring.append(Vector3(x, y, (0.5 - z) * long))
			var shell := smoothstep(-0.75, -0.3, s)
			var band := smoothstep(0.84, 0.92, z) * shell if banded else 0.0
			tint.append(Color(shell, band, 0.0))
		points.append(ring)
		tints.append(tint)
	for r in rings:
		for i in around:
			var j := (i + 1) % around
			var a := points[r][i]
			var b := points[r][j]
			var c := points[r + 1][j]
			var d := points[r + 1][i]
			_vert_tri(tool, [a, b, c], [tints[r][i], tints[r][j], tints[r + 1][j]])
			_vert_tri(tool, [a, c, d], [tints[r][i], tints[r + 1][j], tints[r + 1][i]])
	# The ends, closed.
	for end: int in [0, rings]:
		var middle := Vector3(0.0, 0.0, points[end][0].z)
		for i in around:
			var j := (i + 1) % around
			var tri := [middle, points[end][j], points[end][i]] if end == 0 else [middle, points[end][i], points[end][j]]
			_vert_tri(tool, tri, [Color(0.6, 0.0, 0.0), tints[end][j], tints[end][i]])
	tool.generate_normals()
	return tool.commit()


static func _vert_tri(tool: SurfaceTool, corners: Array, colours: Array) -> void:
	# (Godot's front faces are clockwise seen from outside: the loft runs so that these are)
	for k: int in [0, 1, 2]:
		tool.set_color(colours[k])
		tool.add_vertex(corners[k])


## A triangle, wound to face `normal`.
static func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	tool.set_normal(normal)
	tool.set_color(Color(1, 1, 1))
	var order := [a, c, b] if (b - a).cross(c - a).dot(normal) > 0.0 else [a, b, c]
	for p: Vector3 in order:
		# (UV.y: how far along the bar)
		tool.set_uv(Vector2(0.0, p.y))
		tool.add_vertex(p)

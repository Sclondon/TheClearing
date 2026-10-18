class_name HydraLook
## How the hydra (creatures/hydra, `Hydra`) is shaded and bent: three
## materials, one for each of its three draws.
##
## All three are cel shaded as the rest of the cast is (two flat tones with a
## one-pixel edge, shadows only dimming, a rim of light at grazing angles),
## with a dull, oily sheen (a hard little highlight that slides over the scales
## as it moves), and all are covered in scales painted here: heavy keeled
## scales in rows down the necks, smaller ones over the body, big plates on
## the crowns of the heads. Undersides (of necks, heads, body) are a dirty
## pale grey, the backs a dark grey-olive. Everything near colourless, as the
## game is lit.
##
## THE BODY (a mesh from creatures/hydra/models/hydra.glb, "body") is posed in
## its vertex shader from four instance uniforms: `swing` (each leg's swing
## forward, radians), `lift` (each foot's lift, metres), `tail` (x: how far its
## tip is bent to the side, y and z: a wave down it, its phase and size; w:
## breath, 0..1) and `heave` (x: how far its back rises with each breath).
## The model says what a point is (see build_hydra.py): UV (limb, how far down
## it), UV2 (how far down the tail, how high a scute).
##
## THE NECKS are one tube to each neck (made by `Hydra`), bent along their
## spines in the vertex shader: `spine` is, for each of up to `Hydra.MAX_HEADS`
## necks, `Hydra.POINTS` points down it from its root (xyz) and how thick it
## is there (w, 0 for a neck that is not there); `sides` the way that is its
## left at each of them. UV2 is (how far along, which neck); UV is (how far
## round, how far along in metres) for its scales. The far end is capped dark
## red: the stump, where a head has been cut off.
##
## THE HEADS are one MultiMesh of the model's "head": INSTANCE_CUSTOM is (how
## far the jaw is open, 0..1; how far the tongue is out, 0..1; a seed; how far
## its fangs are swung down, 0..1). The model says what a point is: UV.x the
## part (0 scales, 1 eye, 2 mouth, 3 fang, 4 tongue), UV.y 1 on the lower
## jaw; UV2 where on the eye, or how far along the tongue.

## Up to how many necks one neck material bends, and how many points down each.
const MAX_NECKS := 9
const POINTS := 10

const COMMON := """
uniform float wrap = 0.35;
uniform float flatness = 0.65;
uniform float rim_gain = 0.32;
uniform float rim_width = 0.22;
uniform float gloss = 70.0;
uniform float shine = 0.12;
uniform vec3 back_colour : source_color = vec3(0.13, 0.14, 0.12);
uniform vec3 flank_colour : source_color = vec3(0.25, 0.25, 0.22);
uniform vec3 belly_colour : source_color = vec3(0.5, 0.48, 0.41);

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

// How light a point is among scales in staggered rows (a grid of them: x round, y along): each scale a rounded
// plate, lighter at its middle with a faint keel down it, dark in the seams between, each a little different.
float scale_shade(vec2 at) {
	vec2 g = at;
	float row = floor(g.y);
	g.x += 0.5 * mod(row, 2.0);
	vec2 cell = floor(g);
	vec2 f = fract(g) - 0.5;
	// (a little longer than wide, its free end rounder)
	float d = length(f * vec2(1.0, 1.15) + vec2(0.0, 0.06));
	float shade = mix(1.04, 0.8, smoothstep(0.2, 0.5, d));
	shade *= 1.0 - 0.32 * smoothstep(0.5, 0.66, d);
	shade += 0.05 * (1.0 - smoothstep(0.0, 0.1, abs(f.x))) * (1.0 - smoothstep(0.1, 0.45, d));
	return shade * (0.93 + 0.12 * hash2(cell + vec2(row * 7.0, 3.0)));
}

// A colour among scales at `at`, faded out far off (where they would only shimmer).
vec3 scaled(vec3 colour, vec2 at) {
	float pixel = length(fwidth(at));
	float near = 1.0 - smoothstep(0.3, 0.75, pixel);
	return colour * mix(1.0, scale_shade(at), near);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float turned = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = cut(turned, 0.04) * mix(0.55, 1.0, smoothstep(0.15, 0.6, reach));
	lit *= mix(0.78, 1.0, smoothstep(0.1, 0.85, turned));
	float strength = LIGHT_IS_DIRECTIONAL ? mix(reach, 1.0, flatness) : reach;
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float wet = 1.0 - ROUGHNESS;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = cut(graze, 1.0 - rim_width) * lit;
	SPECULAR_LIGHT += rim * rim_gain * (0.5 + 0.5 * wet) * ALBEDO * 1.3 * strength * LIGHT_COLOR / PI;
	float h = max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0);
	float spot = cut(pow(h, gloss), 0.5) + 0.08 * cut(pow(h, gloss * 0.2), 0.6);
	SPECULAR_LIGHT += spot * wet * shine * strength * LIGHT_COLOR * smoothstep(0.0, 0.3, reach + 0.2);
}
"""

const BODY_SHADER := """
shader_type spatial;
render_mode cull_back;

instance uniform vec4 swing = vec4(0.0);
instance uniform vec4 lift = vec4(0.0);
instance uniform vec4 tail = vec4(0.0);
instance uniform vec4 heave = vec4(0.0);
uniform float scale_size = 0.09;

varying vec3 rest;
varying vec3 rest_normal;

#COMMON

// Where each leg joins the body (build_hydra.py's FORE and HIND), left fore, right fore, left hind, right hind.
const vec3 HIPS[4] = vec3[4](vec3(0.85, 0.8, 1.15), vec3(-0.85, 0.8, 1.15), vec3(0.8, 0.78, -1.25), vec3(-0.8, 0.78, -1.25));

// (one leg's share of a vec4: legs 1 to 4)
float pick(vec4 v, int limb) {
	return limb == 1 ? v.x : (limb == 2 ? v.y : (limb == 3 ? v.z : v.w));
}

vec3 turned_y(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(v.x * c + v.z * s, v.y, -v.x * s + v.z * c);
}

void vertex() {
	rest = VERTEX;
	rest_normal = NORMAL;
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	int limb = int(round(UV.x));
	if (limb > 0) {
		vec3 hip = HIPS[limb - 1];
		float w = UV.y;
		float a = pick(swing, limb) * smoothstep(0.0, 0.3, w);
		p = hip + turned_y(p - hip, a);
		n = turned_y(n, a);
		// (the foot is lifted, the knee and elbow less)
		p.y += pick(lift, limb) * smoothstep(0.1, 0.9, w);
	}
	float t = UV2.x;
	if (t > 0.0) {
		p.x += tail.x * t * t + sin(tail.y - t * 4.5) * tail.z * t;
	}
	// Breathing: the flanks swell and the back rises a little.
	float torso = (1.0 - t) * step(float(limb), 0.5);
	p.x *= 1.0 + 0.035 * tail.w * torso;
	p.y += heave.x * tail.w * torso * smoothstep(0.4, 1.4, p.y);
	VERTEX = p;
	NORMAL = n;
}

void fragment() {
	vec3 colour = COLOR.rgb;
	// Scales over all of it, seen from above, the side and the front, blended by which way a point faces (the
	// belly in broad plates across it).
	vec3 w = pow(abs(rest_normal), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec2 top = rest_normal.y < -0.4 ? vec2(rest.x * 0.45, rest.z * 1.4) : vec2(rest.x, rest.z);
	float pixel = length(fwidth(rest.xz)) / scale_size;
	float near = 1.0 - smoothstep(0.3, 0.75, pixel);
	float shade = scale_shade(top / scale_size) * w.y + scale_shade(vec2(rest.z, rest.y) / scale_size) * w.x + scale_shade(vec2(rest.x, rest.y) / scale_size) * w.z;
	colour *= mix(1.0, shade, near);
	ALBEDO = colour;
	ROUGHNESS = 1.0 - 0.3;
	SPECULAR = 0.0;
}
"""

const NECK_SHADER := """
shader_type spatial;
render_mode cull_back;

uniform vec4 spine[90];
uniform vec4 sides[90];
// How many scales round a neck, and how long each is down it (metres).
uniform float scales_round = 16.0;
uniform float scale_length = 0.16;
uniform vec3 stump_colour : source_color = vec3(0.16, 0.035, 0.03);

varying float down;
varying float stump;
varying vec2 round_along;
varying float girth;

#COMMON

void vertex() {
	float along = clamp(UV2.x, 0.0, 1.0) * 9.0;
	int i = int(min(floor(along), 8.0));
	float f = along - float(i);
	int base = int(round(UV2.y)) * 10;
	vec3 p0 = spine[base + max(i - 1, 0)].xyz;
	vec3 p1 = spine[base + i].xyz;
	vec3 p2 = spine[base + i + 1].xyz;
	vec3 p3 = spine[base + min(i + 2, 9)].xyz;
	vec3 a = 2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3;
	vec3 b = -p0 + 3.0 * p1 - 3.0 * p2 + p3;
	vec3 centre = 0.5 * (2.0 * p1 + (p2 - p0) * f + a * f * f + b * f * f * f);
	vec3 going = 0.5 * ((p2 - p0) + 2.0 * a * f + 3.0 * b * f * f);
	vec3 way = length(going) > 0.0001 ? normalize(going) : vec3(0.0, 1.0, 0.0);
	vec3 side = mix(sides[base + i].xyz, sides[base + i + 1].xyz, f);
	side = side - way * dot(side, way);
	side = length(side) > 0.001 ? normalize(side) : normalize(cross(way, vec3(0.3, 0.9, 0.2)));
	vec3 up = cross(way, side);
	float thick = mix(spine[base + i].w, spine[base + i + 1].w, f);
	girth = thick;
	VERTEX = centre + (side * VERTEX.x + up * VERTEX.y) * thick + way * VERTEX.z * thick;
	NORMAL = normalize(side * NORMAL.x + up * NORMAL.y + way * NORMAL.z);
	down = -(MODEL_MATRIX * vec4(NORMAL, 0.0)).y;
	stump = step(1.5, UV.x);
	round_along = UV;
}

void fragment() {
	if (girth <= 0.001) {
		discard;
	}
	vec3 colour = mix(flank_colour, back_colour, smoothstep(-0.1, -0.7, down));
	colour = mix(colour, belly_colour, smoothstep(0.25, 0.7, down));
	// (the belly: broad plates across the neck instead of scales)
	vec2 at = vec2(round_along.x * scales_round, round_along.y / scale_length);
	if (down > 0.55) {
		at = vec2(round_along.x * 3.0, round_along.y / (scale_length * 1.3));
	}
	colour = scaled(colour, at);
	// (darker blotches down the back, staggered)
	float blot = sin(round_along.y * 2.3 + sin(round_along.x * 6.283) * 1.4);
	colour *= 1.0 - 0.28 * smoothstep(0.55, 0.75, blot) * smoothstep(0.2, -0.4, down);
	if (stump > 0.5) {
		colour = stump_colour * (0.75 + 0.5 * hash2(floor(round_along * 40.0)));
	}
	ALBEDO = colour;
	ROUGHNESS = stump > 0.5 ? 0.1 : 1.0 - 0.35;
	SPECULAR = 0.0;
}
"""

const HEAD_SHADER := """
shader_type spatial;
render_mode cull_back;

uniform vec3 hinge = vec3(0.0, -0.045, 0.13);
uniform vec3 fang_root = vec3(0.0, -0.053, 0.84);
uniform float gape = 1.15;
uniform float tongue_reach = 0.5;
uniform vec3 iris : source_color = vec3(0.62, 0.58, 0.4);
uniform vec3 iris_dark : source_color = vec3(0.25, 0.23, 0.14);
uniform float scale_size = 0.05;

varying flat float part;
varying vec3 rest;
varying vec2 eye_at;
varying float down;
varying float seed;

#COMMON

vec3 turned_x(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(v.x, v.y * c - v.z * s, v.y * s + v.z * c);
}

void vertex() {
	part = UV.x;
	rest = VERTEX;
	eye_at = UV2;
	seed = INSTANCE_CUSTOM.z;
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	int kind = int(round(UV.x));
	float jaw = INSTANCE_CUSTOM.x * gape;
	if (kind == 4) {
		// The tongue: pushed out through the notch at the front of the snout, flickering, forked.
		float out_by = INSTANCE_CUSTOM.y;
		p.z += out_by * tongue_reach;
		float flick = sin(TIME * 47.0 + seed * 20.0 - UV2.x * 7.0);
		p.y += flick * 0.035 * out_by * UV2.x + out_by * 0.012;
		p.x += cos(TIME * 31.0 + seed * 9.0) * 0.008 * out_by * UV2.x;
		// (it rides on the floor of the mouth when the jaw drops)
		p = hinge + turned_x(p - hinge, jaw * 0.85);
	} else if (kind == 3) {
		// A fang: swung down off the roof of the mouth as the jaw opens.
		float swing = -INSTANCE_CUSTOM.w * 1.45;
		vec3 root = vec3(p.x, fang_root.y, fang_root.z);
		p = root + turned_x(p - root, swing);
		n = turned_x(n, swing);
	} else if (UV.y > 0.5) {
		p = hinge + turned_x(p - hinge, jaw);
		n = turned_x(n, jaw);
	}
	VERTEX = p;
	NORMAL = n;
	down = -(MODEL_MATRIX * vec4(n, 0.0)).y;
}

// A lidless snake's eye: a dull pale iris, flecked, with a dark ring and a slit of a pupil, glassy.
vec3 eye_colour(vec2 at) {
	float r = length(at);
	vec3 c = mix(iris_dark, iris, smoothstep(1.0, 0.3, r));
	c *= 0.8 + 0.3 * hash2(floor(at * 13.0));
	float pupil = length(at / vec2(0.14, 0.78));
	float pp = max(fwidth(pupil), 0.002);
	c = mix(vec3(0.01), c, smoothstep(1.0 - pp, 1.0 + pp, pupil));
	c = mix(c, vec3(0.03, 0.03, 0.02), smoothstep(0.85, 0.98, r));
	return c;
}

void fragment() {
	int kind = int(round(part));
	vec3 colour = COLOR.rgb;
	float wet = 0.35;
	if (kind == 0) {
		// Heavy plates on the crown, smaller scales on the sides, broad plates under the chin.
		vec2 at = vec2(rest.x, rest.z) / (scale_size * 1.8);
		if (down < -0.6) {
			at = vec2(rest.x * 0.7, rest.z) / (scale_size * 2.6);
		} else if (down > 0.5) {
			at = vec2(rest.x * 0.4, rest.z) / (scale_size * 1.6);
		} else {
			at = vec2(rest.z, rest.y) / scale_size;
		}
		colour = scaled(colour, at);
		// (each head a little different)
		colour *= 0.9 + 0.2 * fract(seed * 7.13);
	} else if (kind == 1) {
		colour = eye_colour(eye_at);
		wet = 1.0;
	} else if (kind == 2) {
		wet = 0.85;
	} else if (kind == 3) {
		wet = 0.9;
	} else {
		wet = 0.9;
	}
	ALBEDO = colour;
	ROUGHNESS = 1.0 - wet;
	SPECULAR = 0.0;
}
"""

static var _body: ShaderMaterial
static var _head: ShaderMaterial
static var _neck_shader: Shader


## The body's material (one for every hydra: what differs between them is its instance uniforms).
static func body_material() -> ShaderMaterial:
	if _body == null:
		var shader := Shader.new()
		shader.code = BODY_SHADER.replace("#COMMON", COMMON)
		_body = ShaderMaterial.new()
		_body.shader = shader
	return _body


## The heads' material (one for every hydra: what differs is each head's INSTANCE_CUSTOM).
static func head_material() -> ShaderMaterial:
	if _head == null:
		var shader := Shader.new()
		shader.code = HEAD_SHADER.replace("#COMMON", COMMON)
		_head = ShaderMaterial.new()
		_head.shader = shader
	return _head


## A new material for one hydra's necks (each needs its own: their spines are in it).
static func neck_material() -> ShaderMaterial:
	if _neck_shader == null:
		_neck_shader = Shader.new()
		_neck_shader.code = NECK_SHADER.replace("#COMMON", COMMON)
	var material := ShaderMaterial.new()
	material.shader = _neck_shader
	return material


## The tubes of `count` necks (up to MAX_NECKS), each `rings` rings of `round`
## points from its root to its end, thick as `girth(along)` says (along 0..1)
## and `length` metres long (for its scales), with a cap over its far end.
static func neck_mesh(count: int, rings: int, round: int, length: float, girth: Callable) -> ArrayMesh:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var index := PackedInt32Array()
	for neck in count:
		var start := points.size()
		for r in rings:
			var t := float(r) / float(rings - 1)
			var thick: float = girth.call(t)
			# (how the girth changes along it tilts the normals)
			var slope: float = (girth.call(minf(t + 0.02, 1.0)) - girth.call(maxf(t - 0.02, 0.0))) / (0.04 * length)
			for k in round + 1:
				var a := TAU * float(k) / float(round)
				var out := Vector3(cos(a), sin(a), 0.0)
				points.append(out * thick)
				normals.append((out - Vector3(0.0, 0.0, slope)).normalized())
				uv.append(Vector2(float(k) / float(round), t * length))
				uv2.append(Vector2(t, float(neck)))
		for r in rings - 1:
			for k in round:
				var a := start + r * (round + 1) + k
				var b := a + round + 1
				index.append_array([a, b, a + 1, a + 1, b, b + 1])
		# The cap over the far end (the stump, when its head is cut off): a dome a little out past the last ring.
		var end_thick: float = girth.call(1.0)

		var middle := points.size()
		points.append(Vector3(0.0, 0.0, end_thick * 0.45))
		normals.append(Vector3(0.0, 0.0, 1.0))
		uv.append(Vector2(2.0, length))
		uv2.append(Vector2(1.0, float(neck)))
		var rim := points.size()
		for k in round + 1:
			var a := TAU * float(k) / float(round)
			points.append(Vector3(cos(a), sin(a), 0.15).normalized() * end_thick * 0.97)
			normals.append(Vector3(cos(a) * 0.4, sin(a) * 0.4, 1.0).normalized())
			uv.append(Vector2(2.0 + float(k) / float(round), length))
			uv2.append(Vector2(1.0, float(neck)))
		for k in round:
			index.append_array([rim + k, rim + k + 1, middle])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

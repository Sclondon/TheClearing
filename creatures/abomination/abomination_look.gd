class_name AbominationLook
## What a MeatAbomination (abomination.gd) is made of, to look at. Nothing here
## moves by itself: the creature sets the shader's uniforms each frame and the
## shader does all the heaving.
##
## THE BODY is one mesh, worked out here once and shared by every abomination:
## a great sagging mound of meat, wider than it is high, its belly spread flat
## on the ground like a slug's, and sunk into it the things it has taken in. A
## ridge of vertebrae breaks out along its back; a ribcage lies half out of one
## flank; arms and a leg of the people it has swallowed hang out of it; skulls
## sit in it; a cluster of eyes stares from its front, over a mouth that is a
## long slit lined with teeth; slime hangs off its overhang in strings.
##
## Every vertex says what it is with its attributes (so one material and one
## draw does the lot):
##   COLOR.rgb  the tint: meat is multiplied by it (the mouth's inside is dark),
##              anything else (bone, skin, eyes, slime) is that colour
##   COLOR.a    a random phase (for each string of slime)
##   UV.x       how much it hangs (sags as the body bounces)
##   UV.y       0 for meat, 1 for anything else
##   UV2.x      the mouth: up to 1 for the upper lip, down to -1 for the lower
##   UV2.y      the tip of a string of slime (it stretches and lets go)
##
## THE TENDRILS are a MultiMesh of one tapered stalk (`stalk`), drawn with the
## same shader in "strands" mode; instance colour is the tint, its alpha 0 for
## meat and 1 for bone. THE TRAIL is a MultiMesh of flat patches of slime on
## the ground (`trail_material`).
##
## Lit as the Griever is: hard bands of light, light coming through the meat
## red on its shadow side, hard wet glints, the sky caught in the slime.

## Body space: forward is -Z, up +Y, the origin on the ground under its middle.
## Half its width, height and length as it is built (before `size`), and how
## high its middle is.
const RADII := Vector3(5.0, 4.0, 5.6)
const MIDDLE := 1.5
## How far below its middle it reaches (to the ground and under, where it is pressed flat).
const BELOW := 1.9

const SHADER := """
shader_type spatial;
render_mode cull_back;

uniform vec3 flesh : source_color = vec3(0.3, 0.13, 0.12);
uniform vec3 raw : source_color = vec3(0.46, 0.07, 0.08);
uniform vec3 dark : source_color = vec3(0.16, 0.06, 0.07);
uniform vec3 fat : source_color = vec3(0.55, 0.45, 0.3);
uniform vec3 grime : source_color = vec3(0.11, 0.07, 0.05);
uniform vec3 vein : source_color = vec3(0.12, 0.04, 0.1);
uniform vec3 through : source_color = vec3(0.7, 0.12, 0.1);
uniform vec3 slime : source_color = vec3(0.7, 0.74, 0.68);
// Set each frame by the creature.
// How far it has crept (metres, as built): the waves that run along it.
uniform float crawl = 0.0;
// How strong those waves are (more when it is going).
uniform float surge = 0.3;
uniform float breath = 0.0;
uniform float pulse = 0.0;
// How far it has slopped (body space, metres) and bounced.
uniform vec3 jiggle = vec3(0.0);
uniform float bounce = 0.0;
// Rearing up at the front (0..1), the mouth open (0..1), how hard it is turning
// (bends it, -1..1), and the lunge forward of a lash (metres).
uniform float rear = 0.0;
uniform float maw = 0.0;
uniform float bend = 0.0;
uniform float lunge = 0.0;
// Half its length as built, for where along it a point is.
uniform float length_half = 5.6;
uniform float wrap = 0.35;
uniform float bump = 0.1;
// The tendrils: no heaving, and what they are made of comes from their instance colour.
uniform bool strands = false;

varying vec3 obj;
varying float meat;
varying vec3 tint;
varying float glow;
// From fragment to light: where the surface is wet enough to glint (a fine
// broken mask), and the way it faces before it was bumped.
varying float wet;
varying vec3 form;

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
	tint = COLOR.rgb;
	glow = 0.0;
	if (strands) {
		obj = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz * 0.8;
		meat = 1.0 - COLOR.a;
	} else {
		obj = VERTEX;
		meat = 1.0 - UV.y;
		// (on anything but meat, UV.x is how much it shines of itself: eyes, slime)
		glow = UV.y * UV.x;
		vec3 v = VERTEX;
		// Where along it this is: -1 at the tail, 1 at the front; and how high (0 on the ground).
		float along = clamp(-v.z / length_half, -1.4, 1.4);
		float up = clamp(v.y / 5.0, 0.0, 1.0);
		float ground = smoothstep(0.0, 0.8, v.y);
		// Waves of squeezing that run from its tail to its front as it creeps:
		// where one is, it is drawn in and pushed on.
		float band = pow(0.5 + 0.5 * sin(6.2832 * (crawl / 3.2 - along * 0.9)), 3.0);
		v.x -= v.x * band * 0.11 * surge;
		v.y -= (v.y - 0.0) * band * 0.08 * surge * ground;
		v.z -= band * 0.35 * surge * ground;
		// Breathing, and a throb.
		v += NORMAL * (breath * 0.09 + pulse * 0.05) * ground * meat;
		// It slops after itself as it starts, stops and turns: the top most.
		v += jiggle * up;
		// The flanks hang, and bounce.
		v.y -= UV.x * (1.0 - UV.y) * bounce;
		// Bent round a turn: the front and tail swing out.
		v.x += bend * along * along * 1.6 * ground;
		// Rearing: the front comes up and back, the tail stays put.
		float front = smoothstep(-0.2, 1.0, along);
		v.y += rear * front * (1.0 + up * 1.8) * ground;
		v.z += rear * front * 1.1 * ground;
		v.z -= lunge * front * ground;
		// The mouth: the upper lip up, the lower one down.
		v.y += UV2.x * maw * (UV2.x > 0.0 ? 1.1 : 0.55);
		v.z -= abs(UV2.x) * maw * 0.3;
		// Strings of slime stretch and let go.
		float drip = fract(TIME * 0.22 + COLOR.a * 7.0);
		v.y = max(v.y - UV2.y * (drip * drip * 0.9), mix(v.y, 0.03, UV2.y));
		// Slow ripples, livelier when it has been shaken.
		float ripple = sin(TIME * 4.1 + dot(VERTEX, vec3(1.3, 1.9, 1.1))) + sin(TIME * 2.9 - dot(VERTEX, vec3(-1.1, 1.4, 1.7)));
		v += NORMAL * ripple * (0.02 + length(jiggle) * 0.05) * ground * meat;
		VERTEX = v;
	}
}

void fragment() {
	vec3 p = obj;
	float pixel = max(length(fwidth(p)), 0.0002);
	vec3 colour;
	if (meat > 0.5) {
		// Mottled dark meat, raw red where it is stretched, lumps of yellow fat,
		// darker underneath.
		float mottle = noise3(p * 1.1) * 0.6 + noise3(p * 3.3 + 7.0) * 0.4;
		colour = mix(dark, flesh, smoothstep(0.25, 0.55, mottle));
		colour = mix(colour, raw, smoothstep(0.58, 0.8, mottle) * 0.85);
		float lumps = noise3(p * 2.4 + 13.0) * 0.6 + noise3(p * 6.0 + 3.0) * 0.4;
		colour = mix(colour, fat, smoothstep(0.72, 0.8, lumps) * 0.5);
		if (!strands) {
			// Underneath: fat gone grey-yellow and grime from the floor it drags over,
			// darkening into the ground.
			float low = 1.0 - smoothstep(0.0, 2.6, p.y);
			float grot = noise3(p * 1.7 + 31.0);
			vec3 under = mix(grime, fat * 0.45, smoothstep(0.55, 0.7, grot));
			colour = mix(colour, under, low * 0.75);
			colour *= mix(0.45, 1.0, smoothstep(0.0, 1.6, p.y));
		}
		// Veins along the middle of a field of noise, filling with the heartbeat.
		float a = abs(noise3(p * 0.8 + vec3(3.1, 0.0, 1.7)) - 0.5);
		float b = abs(noise3(p * 2.1 + vec3(9.0, 4.0, 2.0)) - 0.5);
		float width = (0.014 + 0.02 * noise3(p * 0.5 + 5.0)) + pulse * 0.01;
		float big = 1.0 - smoothstep(width - pixel, width + pixel, a);
		float small = (1.0 - smoothstep(0.018 - pixel, 0.018 + pixel, b)) * smoothstep(0.45, 0.6, noise3(p * 0.6 + 21.0));
		float veins = max(big, small * 0.8) * clamp(0.08 / pixel, 0.0, 1.0);
		colour = mix(colour, vein, veins * 0.75);
		colour *= tint;
		EMISSION = through * veins * (0.03 + pulse * 0.12) * tint;
	} else {
		// Bone, skin, eyes, slime: their own colour, a little stained.
		float stain = noise3(p * 6.0);
		colour = tint * mix(0.82, 1.05, stain);
		EMISSION = tint * glow * 0.35;
	}
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// Uneven skin: bumped by noise (for the bands of light; the glints keep
	// mostly to the form, see light()).
	form = NORMAL;
	float e = 0.06;
	vec3 q = p * (meat > 0.5 ? 6.5 : 5.0);
	float n0 = noise3(q);
	vec3 slope = vec3(noise3(q + vec3(e, 0, 0)) - n0, noise3(q + vec3(0, e, 0)) - n0, noise3(q + vec3(0, 0, e)) - n0) / e;
	vec3 tilt = (VIEW_MATRIX * (strands ? vec4(slope, 0.0) : MODEL_MATRIX * vec4(slope, 0.0))).xyz;
	NORMAL = normalize(NORMAL - tilt * bump * (meat > 0.5 ? 1.0 : 0.3));
	// Wet in specks and runs, not all over: a fine noise, cut.
	wet = cut(noise3(p * 11.0 + 5.0) * 0.6 + noise3(p * 3.0) * 0.4, 0.5);
	// A thin film of slime over its upper surface: a faint pale wash that is
	// strongest seen side-on, so its form shows through it.
	vec3 sky_up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float side_on = 1.0 - clamp(dot(form, VIEW), 0.0, 1.0);
	float upper = smoothstep(0.1, 0.8, dot(form, sky_up));
	EMISSION += slime * upper * (0.015 + 0.09 * side_on * side_on * side_on);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float amount = facing * smoothstep(0.15, 0.6, reach);
	float lit = cut(amount, 0.04);
	float core = cut(amount, 0.7);
	DIFFUSE_LIGHT += (lit * 0.85 + core * 0.15) * LIGHT_COLOR / PI;
	// Light comes through the meat: its shadow side glows red.
	float behind = clamp(dot(VIEW, -LIGHT) * 0.5 + 0.5, 0.0, 1.0);
	DIFFUSE_LIGHT += (1.0 - lit) * through * meat * (0.12 + 0.3 * behind * behind) * LIGHT_COLOR / PI;
	// Wet: small hard glints where the form turns to the light, broken up by
	// where it is wet, and a soft see-through sheen round them.
	vec3 half_way = normalize(LIGHT + VIEW);
	vec3 n = normalize(mix(form, NORMAL, 0.35));
	float shine = max(dot(n, half_way), 0.0);
	float glint = cut(pow(shine, 90.0), 0.5) * wet;
	float sheen = pow(shine, 24.0);
	SPECULAR_LIGHT += (glint * 0.9 + sheen * 0.12) * lit * reach * LIGHT_COLOR;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	SPECULAR_LIGHT += cut(graze, 0.82) * lit * 0.14 * LIGHT_COLOR * fat;
}
"""

const TRAIL_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 film : source_color = vec3(0.14, 0.06, 0.05);
uniform vec3 sky : source_color = vec3(0.7, 0.75, 0.75);

varying float fade;
varying vec3 world;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	fade = COLOR.a;
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// A patch of slime: thickest in the middle of its path, ragged at the edges,
	// thinning to nothing as it dries.
	vec2 c = UV * 2.0 - 1.0;
	float edge = 1.0 - smoothstep(0.55, 1.0, abs(c.x) + noise2(world.xz * 0.9) * 0.35);
	float ends = 1.0 - smoothstep(0.6, 1.0, abs(c.y));
	float body = edge * ends;
	float thin = noise2(world.xz * 2.3 + 4.0);
	float a = body * fade * mix(0.25, 0.6, thin);
	// Mostly it shows as a sheen: the sky on a wet floor, most where it is seen side-on.
	float glance = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float streak = smoothstep(0.58, 0.64, noise2(world.xz * 1.6 + 9.0));
	ALBEDO = film;
	EMISSION = sky * (glance * 0.35 + streak * 0.12) * fade;
	ROUGHNESS = 0.15;
	SPECULAR = 0.8;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

static var _shader: Shader
static var _trail_shader: Shader
static var _body: ArrayMesh
static var _stalk: ArrayMesh
static var _strand_material: ShaderMaterial
static var _trail_material: ShaderMaterial
static var _noise: FastNoiseLite


## A material for one abomination's body (each its own: its uniforms are its own).
static func body_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _the_shader()
	material.set_shader_parameter(&"length_half", RADII.z)
	return material


## The tendrils' material, shared.
static func strand_material() -> ShaderMaterial:
	if _strand_material == null:
		_strand_material = ShaderMaterial.new()
		_strand_material.shader = _the_shader()
		_strand_material.set_shader_parameter(&"strands", true)
	return _strand_material


static func trail_material() -> ShaderMaterial:
	if _trail_material == null:
		_trail_shader = Shader.new()
		_trail_shader.code = TRAIL_SHADER
		_trail_material = ShaderMaterial.new()
		_trail_material.shader = _trail_shader
	return _trail_material


static func _the_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	return _shader


# --- The body ---

## Swellings and folds over the mound (direction, how much).
const BULGES: Array[Vector4] = [
	Vector4(0.35, 0.85, 0.2, 0.18), Vector4(-0.45, 0.75, -0.25, 0.16), Vector4(0.0, 0.7, 0.75, 0.2),
	Vector4(-0.75, 0.25, 0.35, 0.12), Vector4(0.85, 0.15, -0.3, 0.11), Vector4(0.25, 0.45, -0.8, 0.13),
	Vector4(-0.3, 0.5, -0.85, 0.1), Vector4(0.6, 0.6, 0.6, 0.12), Vector4(-0.65, 0.55, 0.65, 0.1),
	Vector4(0.0, 1.0, 0.0, -0.08), Vector4(0.95, 0.3, 0.3, -0.06), Vector4(-0.9, 0.35, -0.45, -0.05),
]
## The mouth, a slit across the front: its middle (a direction from the body's
## middle), how wide it runs across, and how high its opening is.
const MOUTH := Vector3(0.0, 0.1, -1.0)
const MOUTH_WIDE := 0.5
const MOUTH_HIGH := 0.07


## Where on the mound a direction from its middle comes out (body space), before
## its belly is spread on the ground, and how far it is in the mouth (0..1).
static func _lump(direction: Vector3) -> Vector3:
	var d := direction.normalized()
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 4747
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 1.0
	var r := 1.0
	r += 0.06 * sin(d.x * 4.0 + 1.1) * sin(d.z * 3.5 + 0.7)
	for bulge: Vector4 in BULGES:
		var at := Vector3(bulge.x, bulge.y, bulge.z).normalized()
		r += bulge.w * exp(-(1.0 - d.dot(at)) * 7.0)
	var q := d * 2.0
	r += 0.09 * _noise.get_noise_3d(q.x, q.y, q.z)
	# Creases between the lumps it is made of: a ridged noise turned inwards.
	q = d * 4.4 + Vector3(11.0, 3.0, 7.0)
	r -= 0.05 * pow(1.0 - absf(_noise.get_noise_3d(q.x, q.y, q.z)), 6.0)
	q = d * 9.0 + Vector3(-4.0, 9.0, 2.0)
	r += 0.018 * _noise.get_noise_3d(q.x, q.y, q.z)
	# The mouth is a deep groove.
	r -= 0.22 * _in_mouth(d)
	# (a mound: high over its middle, and only a little way under it to the ground)
	var radii := RADII if d.y > 0.0 else Vector3(RADII.x, BELOW, RADII.z)
	return d * radii * r + Vector3.UP * MIDDLE


## How far a direction is into the mouth's slit (1 in it, 0 clear of it).
static func _in_mouth(d: Vector3) -> float:
	if d.z > -0.5:
		return 0.0
	var across := absf(d.x) / MOUTH_WIDE
	var high := absf(d.y - MOUTH.y - 0.06 * d.x * d.x * 4.0) / MOUTH_HIGH
	return clampf(1.0 - high, 0.0, 1.0) * clampf((1.0 - across) * 4.0, 0.0, 1.0)


## The mound spread on the ground: below a little way up it is pressed flat and
## pushed out, as a slug's foot is.
static func _on_ground(p: Vector3) -> Vector3:
	var t := p.y
	var floor_y := 0.04
	var soft := 0.45
	var y := 0.5 * (t + floor_y + sqrt((t - floor_y) * (t - floor_y) + soft * soft)) - soft * 0.5
	y = maxf(y, 0.0)
	var pressed := clampf((1.2 - t) / 2.5, 0.0, 1.0)
	return Vector3(p.x * (1.0 + 0.12 * pressed), y, p.z * (1.0 + 0.08 * pressed))


## A point on the body's surface in a direction from its middle (body space).
static func surface(direction: Vector3) -> Vector3:
	return _on_ground(_lump(direction))


## The way the surface faces there (from nearby points).
static func surface_normal(direction: Vector3) -> Vector3:
	var d := direction.normalized()
	var a := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var b := d.cross(a)
	var e := 0.02
	var p := surface(d)
	var n := (surface(d + a * e) - p).cross(surface(d + b * e) - p).normalized()
	return n if n.dot(p - Vector3.UP * MIDDLE) > 0.0 else -n


## How far into the body (at rest, before `size` and squeezing) a point is: less
## than 1 inside. Its belly counts down to the ground.
static func inside(point: Vector3) -> float:
	var p := point - Vector3.UP * MIDDLE
	# (below its middle it comes straight down to its foot on the ground)
	if p.y < 0.0:
		p.y *= RADII.y / (MIDDLE + 0.3)
	var r := RADII * Vector3(1.12, 1.1, 1.05)
	return Vector3(p.x / r.x, p.y / r.y, p.z / r.z).length()


## The body: built once.
static func body() -> ArrayMesh:
	if _body != null:
		return _body
	var b := _Builder.new()
	_mound(b)
	_mouth(b)
	_spine(b)
	_ribs(b)
	_eyes(b)
	_victims(b)
	_bones(b)
	_drips(b)
	_body = b.commit()
	return _body


## Gathers vertices and what each is (see the top), and makes a mesh of them.
class _Builder:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()
	## What the next vertices are: tint, phase, hang, solid, mouth, drip.
	var tint := Color.WHITE
	var phase := 0.0
	var hang := 0.0
	var solid := 0.0
	var mouth := 0.0
	var drip := 0.0

	func add(at: Vector3, normal: Vector3) -> int:
		verts.append(at)
		normals.append(normal.normalized())
		colours.append(Color(tint.r, tint.g, tint.b, phase))
		uvs.append(Vector2(hang, solid))
		uv2s.append(Vector2(mouth, drip))
		return verts.size() - 1

	## A triangle, wound so that it faces the way of its vertices' normals.
	func tri(a: int, b: int, c: int) -> void:
		var n := (verts[b] - verts[a]).cross(verts[c] - verts[a])
		if n.dot(normals[a] + normals[b] + normals[c]) > 0.0:
			indices.append_array([a, c, b])
		else:
			indices.append_array([a, b, c])

	func commit() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colours
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh

	## A tube through `points`, `radii` round at each, `sides` sided, capped at the end.
	func tube(points: PackedVector3Array, radii: PackedFloat32Array, sides := 7) -> void:
		var rings: Array[PackedInt32Array] = []
		# (each ring turned as little as can be from the last, so the tube does not twist flat)
		var u := Vector3.ZERO
		for i in points.size():
			var along := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
			u = u - along * u.dot(along)
			if u.length() < 0.01:
				u = along.cross(Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT)
			u = u.normalized()
			var w := along.cross(u).normalized()
			var ring := PackedInt32Array()
			for k in sides:
				var angle := TAU * k / sides
				var out := u * cos(angle) + w * sin(angle)
				ring.append(add(points[i] + out * radii[i], out))
			rings.append(ring)
		for i in rings.size() - 1:
			for k in sides:
				var k2 := (k + 1) % sides
				tri(rings[i][k], rings[i][k2], rings[i + 1][k2])
				tri(rings[i][k], rings[i + 1][k2], rings[i + 1][k])
		var last := points[points.size() - 1]
		var tip := add(last + (last - points[points.size() - 2]).normalized() * radii[radii.size() - 1] * 0.8, last - points[points.size() - 2])
		for k in sides:
			tri(rings[rings.size() - 1][k], rings[rings.size() - 1][(k + 1) % sides], tip)

	## A ball (or squashed ball) at `at`, turned by `basis` (its columns the radii's axes).
	## `colour_of` (optional) gives each vertex's tint from its direction in the ball's own space.
	func ball(at: Vector3, basis: Basis, segments := 12, stacks := 8, colour_of := Callable()) -> void:
		var first := verts.size()
		for i in stacks + 1:
			var v := PI * i / stacks
			for j in segments + 1:
				var u := TAU * j / segments
				var local := Vector3(sin(v) * cos(u), cos(v), sin(v) * sin(u))
				if colour_of.is_valid():
					tint = colour_of.call(local)
				var normal := (basis.inverse().transposed() * local).normalized()
				add(at + basis * local, normal)
		for i in stacks:
			for j in segments:
				var a := first + i * (segments + 1) + j
				var c := a + segments + 1
				tri(a, c, a + 1)
				tri(a + 1, c, c + 1)

	## A cone from a disc at `base`, `radius` round, to a point at `tip`.
	func cone(base: Vector3, tip: Vector3, radius: float, sides := 6) -> void:
		var along := (tip - base).normalized()
		var u := along.cross(Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT).normalized()
		var w := along.cross(u)
		var ring := PackedInt32Array()
		for k in sides:
			var angle := TAU * k / sides
			var out := u * cos(angle) + w * sin(angle)
			ring.append(add(base + out * radius, out + along * 0.3))
		var point := add(tip, along)
		for k in sides:
			tri(ring[k], ring[(k + 1) % sides], point)


const MEAT := Color(1.0, 1.0, 1.0)
const BONE := Color(0.8, 0.75, 0.62)
const OLD_BONE := Color(0.62, 0.56, 0.44)
const SKIN := Color(0.56, 0.52, 0.47)
const SLIME := Color(0.5, 0.42, 0.28)
const GULLET := Color(0.22, 0.05, 0.07)


static func _solid(b: _Builder, colour: Color) -> void:
	b.tint = colour
	b.solid = 1.0
	b.hang = 0.0
	b.mouth = 0.0
	b.drip = 0.0


## The mound: an icosphere pushed out into the lumps, its belly flat on the ground.
static func _mound(b: _Builder) -> void:
	var dirs: Array[Vector3] = []
	var faces: Array[Vector3i] = []
	var t := (1.0 + sqrt(5.0)) / 2.0
	for v: Vector3 in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		dirs.append(v.normalized())
	for f: Vector3i in [Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10), Vector3i(0, 10, 11),
			Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2), Vector3i(10, 7, 6), Vector3i(7, 1, 8),
			Vector3i(3, 9, 4), Vector3i(3, 4, 2), Vector3i(3, 2, 6), Vector3i(3, 6, 8), Vector3i(3, 8, 9),
			Vector3i(4, 9, 5), Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7), Vector3i(9, 8, 1)]:
		faces.append(f)
	for level in 5:
		var middles := {}
		var next: Array[Vector3i] = []
		for f: Vector3i in faces:
			var a := _middle(dirs, middles, f.x, f.y)
			var c := _middle(dirs, middles, f.y, f.z)
			var e := _middle(dirs, middles, f.z, f.x)
			next.append_array([Vector3i(f.x, a, e), Vector3i(f.y, c, a), Vector3i(f.z, e, c), Vector3i(a, c, e)])
		faces = next
	var points := PackedVector3Array()
	for d: Vector3 in dirs:
		points.append(surface(d))
	# Smooth normals from the faces.
	var sums := PackedVector3Array()
	sums.resize(points.size())
	for f: Vector3i in faces:
		var n := (points[f.y] - points[f.x]).cross(points[f.z] - points[f.x])
		sums[f.x] += n
		sums[f.y] += n
		sums[f.z] += n
	var first := b.verts.size()
	for i in points.size():
		var d := dirs[i]
		var mouth := _in_mouth(d)
		var normal := sums[i]
		if normal.dot(points[i] - Vector3.UP * MIDDLE) < 0.0:
			normal = -normal
		b.solid = 0.0
		b.drip = 0.0
		b.phase = 0.0
		# Its flanks hang (the overhang over its foot).
		b.hang = smoothstep(0.55, 0.0, absf(d.y + 0.05)) * 0.8
		# Inside the mouth is dark; round it the lips go up and down with it.
		var lip := exp(-pow((d.y - MOUTH.y) / 0.32, 2.0)) * clampf((1.0 - absf(d.x) / (MOUTH_WIDE + 0.15)) * 3.0, 0.0, 1.0) * smoothstep(-0.4, -0.75, d.z)
		b.mouth = lip * (1.0 if d.y > MOUTH.y else -1.0) * (1.0 - mouth)
		var dark := clampf(mouth * 1.6, 0.0, 1.0)
		b.tint = MEAT.lerp(GULLET, dark)
		b.add(points[i], normal)
	for f: Vector3i in faces:
		b.tri(first + f.x, first + f.y, first + f.z)


static func _middle(dirs: Array[Vector3], middles: Dictionary, a: int, b: int) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if middles.has(key):
		return middles[key]
	dirs.append(((dirs[a] + dirs[b]) * 0.5).normalized())
	middles[key] = dirs.size() - 1
	return dirs.size() - 1


## The way into it: teeth along both lips of the slit, of every size, pointing
## in and down (or up), and a few that have come loose and point out.
static func _mouth(b: _Builder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for lip: float in [1.0, -1.0]:
		var count := 17
		for i in count:
			var x := lerpf(-MOUTH_WIDE * 0.92, MOUTH_WIDE * 0.92, (i + rng.randf_range(-0.3, 0.3)) / (count - 1))
			var y := MOUTH.y + 0.06 * x * x * 4.0 + lip * MOUTH_HIGH * 0.95
			var d := Vector3(x, y, -1.0).normalized()
			var root := surface(d)
			var inward := (Vector3(0.0, MIDDLE, 0.0) - root).normalized()
			var long := rng.randf_range(0.25, 0.7) * (1.0 - absf(x) / MOUTH_WIDE * 0.5)
			var point := (Vector3.DOWN * lip * 0.9 + inward * 0.25 + Vector3(rng.randf_range(-0.2, 0.2), 0, 0)).normalized()
			_solid(b, BONE.lerp(OLD_BONE, rng.randf()))
			b.mouth = lip
			b.cone(root - point * 0.1, root + point * long, long * rng.randf_range(0.18, 0.28), 5)


## A ridge of great vertebrae breaking out along its back, and its tail end.
static func _spine(b: _Builder) -> void:
	for i in 9:
		var s := lerpf(-0.75, 0.62, i / 8.0)
		var d := Vector3(0.08 * sin(i * 1.3), 1.0, s * 1.6).normalized()
		var at := surface(d)
		var n := surface_normal(d)
		var big := lerpf(0.42, 0.26, absf(s - 0.1))
		_solid(b, BONE.lerp(OLD_BONE, 0.3 + 0.2 * sin(i * 2.1)))
		# The body of the bone, half sunk, and its spine sticking up and back.
		var basis := Basis(Vector3.RIGHT * big * 1.3, n * big * 0.8, Vector3.BACK * big * 0.9)
		b.ball(at + n * big * 0.05, basis, 10, 6)
		b.cone(at + n * big * 0.3, at + n * big * 2.6 + Vector3.BACK * big * 1.2, big * 0.38, 5)
		# Side spurs.
		for side: float in [-1.0, 1.0]:
			b.cone(at + n * big * 0.2, at + n * big * 0.3 + Vector3.RIGHT * side * big * 2.0, big * 0.22, 4)


## A ribcage lying half out of its left flank: bowed ribs that come out of the
## meat and go back into it.
static func _ribs(b: _Builder) -> void:
	for i in 6:
		var z := lerpf(-0.45, 0.35, i / 5.0)
		var points := PackedVector3Array()
		var radii := PackedFloat32Array()
		for k in 9:
			var s := k / 8.0
			var up := lerpf(-0.15, 0.75, s)
			var d := Vector3(-1.0, up, z + 0.12 * s).normalized()
			var at := surface(d)
			var n := surface_normal(d)
			# (proud of the meat in the middle, sunk at both ends)
			points.append(at + n * (sin(s * PI) * 0.38 - 0.12))
			radii.append(0.12 * (1.0 - 0.3 * s))
		# (smoothed, so the lumps of the meat under it do not kink it)
		for _round in 3:
			var smooth := points.duplicate()
			for k in range(1, points.size() - 1):
				smooth[k] = (points[k - 1] + points[k] * 2.0 + points[k + 1]) * 0.25
			points = smooth
		_solid(b, BONE.lerp(OLD_BONE, 0.2 + 0.15 * (i % 3)))
		b.tube(points, radii, 6)


## Eyes it has taken: a cluster at its front over the mouth, every size, each
## looking a different way, and a few more about it.
static func _eyes(b: _Builder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var spots: Array[Vector4] = [
		Vector4(-0.2, 0.36, -1.0, 0.5), Vector4(0.22, 0.42, -1.0, 0.36), Vector4(0.03, 0.6, -1.0, 0.26),
		Vector4(-0.46, 0.5, -0.9, 0.2), Vector4(0.44, 0.28, -0.95, 0.18), Vector4(0.02, 0.3, -1.0, 0.14),
		Vector4(0.34, 0.66, -0.85, 0.15), Vector4(-0.32, 0.74, -0.8, 0.13), Vector4(0.75, 0.45, -0.6, 0.22),
		Vector4(-0.8, 0.3, 0.2, 0.18), Vector4(0.5, 0.85, 0.2, 0.2), Vector4(0.12, 0.85, -0.75, 0.11),
		Vector4(-0.62, 0.62, -0.62, 0.1), Vector4(0.58, 0.12, -0.8, 0.1),
	]
	for spot: Vector4 in spots:
		var d := Vector3(spot.x, spot.y, spot.z).normalized()
		var at := surface(d)
		var n := surface_normal(d)
		var size := spot.w
		var looks := (n + Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.25, 0.2), rng.randf_range(-0.2, 0.2))).normalized()
		# The ball: white, bloodshot to its edges, a yellow iris and a big black pupil.
		var axis_z := looks
		var axis_x := axis_z.cross(Vector3.UP).normalized()
		var axis_y := axis_x.cross(axis_z)
		var basis := Basis(axis_x * size, axis_y * size, axis_z * size)
		_solid(b, Color.WHITE)
		# (wet eyes shine a little of themselves, so they read in the gloom)
		b.hang = 0.7
		var iris := Color(0.85, 0.6, 0.12).lerp(Color(0.62, 0.22, 0.12), rng.randf())
		b.ball(at + n * size * 0.15, basis, 14, 10, func(local: Vector3) -> Color:
			var front := local.z
			if front > 0.95:
				return Color(0.03, 0.02, 0.02)
			if front > 0.7:
				return iris.lerp(Color(0.05, 0.03, 0.02), smoothstep(0.85, 0.95, front) * 0.6)
			return Color(0.86, 0.8, 0.66).lerp(Color(0.72, 0.36, 0.32), smoothstep(0.3, -0.6, front)))
		# A swollen cushion of raw meat that it sits in, as a lid.
		var u := n.cross(Vector3.UP).normalized()
		var w := n.cross(u)
		b.solid = 0.0
		b.hang = 0.0
		b.tint = Color(1.15, 0.7, 0.7)
		b.ball(at - n * size * 0.05, Basis(u * size * 1.3, w * size * 1.3, n * size * 0.55), 14, 8)


## The people it has taken: arms hanging out of it, one still reaching; a leg
## from its back; skulls sunk in its sides. Grey, dead, the size of a man.
static func _victims(b: _Builder) -> void:
	_arm(b, Vector3(0.8, 0.05, -0.55), Vector3(0.2, -1.0, -0.4), 0.0)
	_arm(b, Vector3(-0.75, 0.3, -0.62), Vector3(-0.4, -0.6, -0.7), 0.6)
	_arm(b, Vector3(0.95, 0.4, 0.25), Vector3(0.4, -0.9, 0.1), 0.2)
	_arm(b, Vector3(-0.35, 0.92, 0.1), Vector3(-0.2, 0.9, 0.3), 1.0)
	_arm(b, Vector3(0.3, 0.1, 0.95), Vector3(0.0, -0.8, 0.6), 0.4)
	_leg(b, Vector3(0.25, 0.85, 0.45), Vector3(0.3, 0.7, 0.65))
	_leg(b, Vector3(-0.85, -0.05, 0.5), Vector3(-0.7, -0.6, 0.3))
	_skull(b, Vector3(0.9, 0.15, -0.3), 0.0)
	_skull(b, Vector3(-0.6, 0.65, -0.45), 0.8)
	_skull(b, Vector3(0.55, 0.55, 0.65), 2.0)


## An arm out of the body at `d`, hanging towards `goes`; `curl` how far its fingers close.
static func _arm(b: _Builder, d: Vector3, goes: Vector3, curl: float) -> void:
	var at := surface(d.normalized())
	var n := surface_normal(d.normalized())
	var shoulder := at - n * 0.25
	var way := (n * 0.6 + goes.normalized()).normalized()
	var elbow := shoulder + way * 0.62
	var bent := (goes.normalized() + Vector3.DOWN * 0.6).normalized()
	var wrist := elbow + bent * 0.55
	_solid(b, SKIN.lerp(Color(0.48, 0.47, 0.44), curl * 0.5))
	b.tube(PackedVector3Array([shoulder, elbow, wrist]), PackedFloat32Array([0.11, 0.085, 0.06]), 7)
	var hand := wrist + bent * 0.1
	var palm := Basis(bent.cross(Vector3.UP).normalized() * 0.07, bent * 0.09, bent.cross(Vector3.UP).cross(bent).normalized() * 0.03)
	b.ball(hand, palm, 8, 5)
	var across := bent.cross(Vector3.UP).normalized()
	if across.length() < 0.1:
		across = Vector3.RIGHT
	var palm_side := across.cross(bent).normalized()
	for f in 4:
		var root := hand + bent * 0.07 + across * (f - 1.5) * 0.032
		var knuckle := root + bent * 0.06
		var tip := knuckle + (bent * (1.0 - curl) + palm_side * curl).normalized() * 0.07
		b.tube(PackedVector3Array([root, knuckle, tip]), PackedFloat32Array([0.016, 0.014, 0.011]), 5)
	var thumb_root := hand + across * 0.07
	b.tube(PackedVector3Array([thumb_root, thumb_root + (across + bent).normalized() * 0.06]), PackedFloat32Array([0.018, 0.013]), 5)


static func _leg(b: _Builder, d: Vector3, goes: Vector3) -> void:
	var at := surface(d.normalized())
	var n := surface_normal(d.normalized())
	var hip := at - n * 0.3
	var way := (n * 0.5 + goes.normalized()).normalized()
	var knee := hip + way * 0.8
	var down := (goes.normalized() * 0.4 + Vector3.DOWN).normalized()
	var ankle := knee + down * 0.75
	_solid(b, SKIN)
	b.tube(PackedVector3Array([hip, knee, ankle]), PackedFloat32Array([0.15, 0.1, 0.065]), 7)
	var toe := ankle + (way * Vector3(1, 0, 1)).normalized() * 0.22 + Vector3.DOWN * 0.05
	b.tube(PackedVector3Array([ankle, toe]), PackedFloat32Array([0.06, 0.045]), 6)


## A human skull, half sunk at `d`, turned `twist` about the way out.
static func _skull(b: _Builder, d: Vector3, twist: float) -> void:
	var dir := d.normalized()
	var at := surface(dir)
	var n := surface_normal(dir)
	var face := n.rotated(Vector3.UP, twist * 0.4)
	var x := face.cross(Vector3.UP).normalized()
	var y := x.cross(face).normalized().rotated(face, twist * 0.3)
	x = y.cross(face).normalized()
	var basis := Basis(x * 0.11, y * 0.13, face * 0.14)
	_solid(b, BONE)
	# The cranium, its sockets and nose dark.
	b.ball(at + n * 0.02, basis, 12, 9, func(local: Vector3) -> Color:
		var eye_l := Vector3(-0.38, -0.05, 0.92).normalized()
		var eye_r := Vector3(0.38, -0.05, 0.92).normalized()
		if local.y < 0.0 and local.z > 0.7 and (local.dot(eye_l) > 0.95 or local.dot(eye_r) > 0.95):
			return Color(0.08, 0.05, 0.04)
		if local.dot(Vector3(0.0, -0.45, 0.89).normalized()) > 0.975:
			return Color(0.12, 0.08, 0.06)
		return BONE.lerp(OLD_BONE, smoothstep(0.0, -1.0, local.y)))
	# The jaw, hanging open, with teeth.
	var chin := at + n * 0.08 - y * 0.2 + face * 0.08
	b.tube(PackedVector3Array([at - x * 0.09 - y * 0.08 + face * 0.02, chin, at + x * 0.09 - y * 0.08 + face * 0.02]), PackedFloat32Array([0.025, 0.035, 0.025]), 5)


## Great bones of other things it has eaten, broken off and sticking out.
static func _bones(b: _Builder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var spots: Array[Vector3] = [Vector3(0.7, 0.6, -0.4), Vector3(-0.9, 0.5, 0.4), Vector3(0.55, 0.85, 0.1),
		Vector3(-0.5, 0.25, 0.85), Vector3(0.9, -0.05, 0.6), Vector3(-0.6, 0.85, -0.2)]
	for spot: Vector3 in spots:
		var d := spot.normalized()
		var at := surface(d)
		var n := surface_normal(d)
		var way := (n + Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.0, 0.6), rng.randf_range(-0.5, 0.5))).normalized()
		var long := rng.randf_range(0.8, 1.6)
		var thick := rng.randf_range(0.09, 0.14)
		_solid(b, BONE.lerp(OLD_BONE, rng.randf()))
		var end := at + way * long
		b.tube(PackedVector3Array([at - way * 0.3, at + way * long * 0.5, end]), PackedFloat32Array([thick, thick * 0.8, thick * 0.9]), 6)
		# Broken off sharp.
		b.cone(end, end + way * 0.28 + Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1)), thick * 0.9, 6)


## Strings of slime hanging off its overhang, each stretching and letting go in
## its own time (the shader), and a beard of them off its lower lip.
static func _drips(b: _Builder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 7:
		var angle := rng.randf_range(0.0, TAU)
		var d := Vector3(cos(angle), rng.randf_range(-0.12, 0.0), sin(angle)).normalized()
		_drip(b, surface(d) + Vector3(cos(angle), 0.0, sin(angle)) * 0.1, rng.randf_range(0.2, 0.5), rng.randf_range(0.025, 0.04), rng.randf(), 0.0)
	for i in 10:
		var x := lerpf(-MOUTH_WIDE * 0.8, MOUTH_WIDE * 0.8, (i + rng.randf()) / 10.0)
		var d := Vector3(x, MOUTH.y - MOUTH_HIGH * 1.4, -1.0).normalized()
		_drip(b, surface(d), rng.randf_range(0.3, 0.9), rng.randf_range(0.02, 0.04), rng.randf(), -1.0)
	# Strings across the mouth, from lip to lip: they stretch as it opens.
	for i in 9:
		var x := lerpf(-MOUTH_WIDE * 0.75, MOUTH_WIDE * 0.75, (i + rng.randf_range(-0.3, 0.3)) / 8.0)
		var bend := 0.06 * x * x * 4.0
		var top := surface(Vector3(x, MOUTH.y + bend + MOUTH_HIGH * 1.2, -1.0).normalized())
		var bottom := surface(Vector3(x + rng.randf_range(-0.06, 0.06), MOUTH.y + bend - MOUTH_HIGH * 1.2, -1.0).normalized())
		_solid(b, SLIME)
		b.hang = 0.4
		var points := PackedVector3Array()
		var radii := PackedFloat32Array()
		var first := b.verts.size()
		var thick := rng.randf_range(0.02, 0.045)
		for k in 6:
			var s := k / 5.0
			# (sagging in the middle)
			points.append(top.lerp(bottom, s) + Vector3.FORWARD * 0.12 + Vector3.DOWN * sin(s * PI) * 0.05)
			radii.append(thick * (1.0 - 0.5 * sin(s * PI)))
		b.tube(points, radii, 5)
		for v in range(first, b.verts.size()):
			var s := clampf((top.y - b.verts[v].y) / maxf(top.y - bottom.y, 0.01), 0.0, 1.0)
			b.uv2s[v] = Vector2(lerpf(1.0, -1.0, s), 0.0)


## One string of slime from `top` (in the body) down `long`; it goes with the lower lip if `mouth` is -1.
static func _drip(b: _Builder, top: Vector3, long: float, thick: float, when: float, mouth: float) -> void:
	_solid(b, SLIME)
	b.hang = 0.4
	b.phase = when
	b.mouth = mouth
	var points := PackedVector3Array()
	var radii := PackedFloat32Array()
	var first := b.verts.size()
	for k in 5:
		var s := k / 4.0
		points.append(top + Vector3.DOWN * long * s + Vector3.UP * 0.15 * (1.0 - s))
		# (a bead at the end)
		radii.append(thick * (1.0 - 0.6 * s) if k < 4 else thick * 0.9)
	b.tube(points, radii, 5)
	# The lower part of the string stretches.
	for v in range(first, b.verts.size()):
		var s := clampf((top.y - b.verts[v].y) / long, 0.0, 1.0)
		b.uv2s[v] = Vector2(mouth, s * s)
	b.phase = 0.0


# --- The tendrils ---

## A stalk of a tendril: a smooth ten-sided tube along +Y from 0 to 1, radius 1
## at the bottom and 0.8 at the top, with a little dome over its top. Placed by
## `between` (successive ones overlap a little so the joins do not show).
static func stalk() -> ArrayMesh:
	if _stalk != null:
		return _stalk
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 10
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var n0 := Vector3(cos(a0), 0.1, sin(a0)).normalized()
		var n1 := Vector3(cos(a1), 0.1, sin(a1)).normalized()
		var p00 := Vector3(cos(a0), 0.0, sin(a0))
		var p01 := Vector3(cos(a1), 0.0, sin(a1))
		var p10 := Vector3(cos(a0) * 0.8, 1.0, sin(a0) * 0.8)
		var p11 := Vector3(cos(a1) * 0.8, 1.0, sin(a1) * 0.8)
		for corner: Array in [[p00, n0], [p01, n1], [p11, n1], [p00, n0], [p11, n1], [p10, n0]]:
			tool.set_normal(corner[1])
			tool.add_vertex(corner[0])
		# The dome.
		var top := Vector3(0.0, 1.25, 0.0)
		for corner: Array in [[p10, n0], [p11, n1], [top, Vector3.UP]]:
			tool.set_normal(corner[1])
			tool.add_vertex(corner[0])
	_stalk = tool.commit()
	return _stalk


## The transform that stretches a stalk from `a` to `b`, `thick` round.
static func between(a: Vector3, b: Vector3, thick: float) -> Transform3D:
	var along := b - a
	if along.length_squared() < 0.000001:
		along = Vector3.UP * 0.001
	var side := Vector3.UP if absf(along.normalized().y) < 0.95 else Vector3.RIGHT
	var x := along.cross(side).normalized()
	var z := x.cross(along.normalized())
	return Transform3D(Basis(x * thick, along, z * thick), a)


## A MultiMesh of `count` stalks with colours (and custom data), all hidden to start.
static func strands(count: int) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = stalk()
	multi.instance_count = count
	multi.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = strand_material()
	node.top_level = true
	return node


## The trail: `count` flat patches (a 1 by 1 quad in XZ, its UV over it), all hidden.
static func trail(count: int) -> MultiMeshInstance3D:
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = quad
	multi.instance_count = count
	multi.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = trail_material()
	node.top_level = true
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

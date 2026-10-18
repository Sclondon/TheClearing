class_name FleshMoundLook
## What a FleshMound (flesh_mound.gd) is made of, to look at, for any number
## of bodies in it.
##
## THE CORE is one mesh, worked out here once and shared, as it is at its
## biggest (scaled down for fewer bodies): a sagging mound of grown-together
## flesh, its belly spread on the ground. No mouth, no eyes, no teeth, and
## hardly any blood: one stretched pallid skin flowing over it, gathered in
## puckered scar-dark seams where bodies were knitted together, folded,
## stretch-marked, veined, swollen with boils of pus and weeping in patches.
## Its shader does all its heaving; `heave` works out the same for the points
## its people grow out of.
##
## THE PEOPLE IN IT (`people(bodies)`): the boy (the character controller's,
## mask face and all) once for each body in it, and as it gets bigger, men's
## arms, long gaunt arms and legs (FleshParts), all one skinned mesh. Each
## copy's `data` says what each of its limbs does (`Role`). It grows through
## four forms (`form`): a PAIR (2), two boys grown together back to back, one
## on all fours under the other, face up, on all eight limbs like a crab; an
## AMALGAM (3 or 4), the boys joined at the hips in a star, a wheel of limbs;
## a STRIDER (5 or 6), the boys joined at the hips in a ring, bent over
## outwards, walking on all their legs; and a MOUND (7 and up), the boys lying
## half sunk in it with their mask faces up, or rising out of it to the waist,
## and the men's limbs growing out of it between them.
##
## Vertex attributes of the core: COLOR.r how much a body lies just under it
## (the skin tight and pale), COLOR.g how much it hangs (bounces), COLOR.b a
## boil (raised, yellow-cream); the trail is a smear of fluid that dries.

## The fewest bodies and the most: a mound grows no bigger than MOST (phones).
const FEWEST := 2
const MOST := 10
## The most bodies in each form before the next: a pair, an amalgam (a star of
## boys, cartwheeling; it and a pair are `small`, and rush), a strider; then a
## mound.
const PAIR := 2
const SMALL := 4
const STRIDER := 6

enum Form { PAIR, AMALGAM, STRIDER, MOUND }

## Core space: forward -Z, up +Y, the origin on the ground under its middle.
## Half its width, height and length at its biggest, and how high its middle is.
const RADII := Vector3(4.1, 2.9, 4.7)
const MIDDLE := 1.25
const BELOW := 1.6

## What each limb does (FleshMound says how).
enum Role { GRAB, CRAWL, REACH, LIMP, KICK, DANGLE, TUCKED, WHEEL }


## Which form one with `bodies` in it takes.
static func form(bodies: int) -> Form:
	if bodies <= PAIR:
		return Form.PAIR
	if bodies <= SMALL:
		return Form.AMALGAM
	return Form.STRIDER if bodies <= STRIDER else Form.MOUND

const SHADER := """
shader_type spatial;
render_mode cull_back;
%s
// Set each frame by the creature (see FleshMound._shade).
uniform float crawl = 0.0;
uniform float surge = 0.3;
uniform float breath = 0.0;
uniform float pulse = 0.0;
uniform vec3 jiggle = vec3(0.0);
uniform float bounce = 0.0;
uniform float rear = 0.0;
uniform float bend = 0.0;
uniform float lunge = 0.0;
uniform float length_half = 4.7;

varying float tight;
varying float boil_in;

void vertex() {
	obj = VERTEX;
	tight = COLOR.r;
	boil_in = COLOR.b;
	vec3 v = VERTEX;
	float along = clamp(-v.z / length_half, -1.4, 1.4);
	float up = clamp(v.y / 5.0, 0.0, 1.0);
	float ground = smoothstep(0.0, 0.8, v.y);
	// Waves of squeezing run from its tail to its front as it creeps.
	float band = pow(0.5 + 0.5 * sin(6.2832 * (crawl / 3.2 - along * 0.9)), 3.0);
	v.x -= v.x * band * 0.11 * surge;
	v.y -= v.y * band * 0.08 * surge * ground;
	v.z -= band * 0.35 * surge * ground;
	v += NORMAL * (breath * 0.1 + pulse * 0.04 + boil_in * pulse * 0.03) * ground;
	v += jiggle * up;
	v.y -= COLOR.g * bounce;
	v.x += bend * along * along * 1.6 * ground;
	float front = smoothstep(-0.2, 1.0, along);
	v.y += rear * front * (1.0 + up * 1.8) * ground;
	v.z += rear * front * 1.1 * ground;
	v.z -= lunge * front * ground;
	float ripple = sin(TIME * 3.1 + dot(VERTEX, vec3(1.3, 1.9, 1.1))) + sin(TIME * 2.3 - dot(VERTEX, vec3(-1.1, 1.4, 1.7)));
	v += NORMAL * ripple * (0.02 + length(jiggle) * 0.05) * ground;
	VERTEX = v;
}

void fragment() {
	vec3 p = obj;
	float pixel = max(length(fwidth(p)), 0.0002);
	vec3 c = skin_colour(p * 0.9, fract(noise3(p * 0.2) * 2.3), pixel);
	// Seams where bodies were knitted together: ridged, puckered creases,
	// with folds gathered across them.
	float ridge = 1.0 - abs(noise3(p * 0.55 + vec3(4.0, 1.0, 7.0)) * 2.0 - 1.0);
	float seam = smoothstep(0.86, 0.95, ridge);
	float gather = 0.5 + 0.5 * sin(dot(p, vec3(7.0, 5.0, -6.0)) + noise3(p * 3.0) * 4.0);
	c = mix(c, c * mix(0.68, 0.9, gather), seam * 0.85);
	float fold = smoothstep(0.7, 0.86, ridge) * (1.0 - seam);
	c *= 1.0 - fold * 0.18;
	// Stretch marks: pale silvery streaks where it was pulled tight.
	float stretch = 0.5 + 0.5 * sin(p.y * 22.0 + noise3(p * 1.5) * 9.0);
	float marks = smoothstep(0.88, 0.97, stretch) * smoothstep(0.45, 0.7, noise3(p * 0.7 + 9.0));
	c = mix(c, c * 1.18, marks * 0.6);
	// Tight over the bodies just under it: paler, the veins showing more.
	c = mix(c, c * 1.1 + vec3(0.02, 0.02, 0.03), tight * 0.6);
	// Boils (raised in the mesh, and smaller ones), and weeping patches.
	vec2 pox = pustules(p * 2.6, 0.08);
	float boil = max(boil_in, pox.x);
	c = mix(c, pus * (0.85 + 0.15 * noise3(p * 18.0)), boil);
	c = mix(c, mix(c, weep, 0.55), pox.y);
	// Underneath: darker, grimed from the floor it drags over.
	c *= mix(0.5, 1.0, smoothstep(0.0, 1.4, p.y));
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	form = NORMAL;
	float e = 0.06;
	vec3 q = p * 6.0;
	float n0 = noise3(q);
	vec3 slope = vec3(noise3(q + vec3(e, 0, 0)) - n0, noise3(q + vec3(0, e, 0)) - n0, noise3(q + vec3(0, 0, e)) - n0) / e;
	// (the seams and folds dent it)
	vec3 r = p * 0.55 + vec3(4.0, 1.0, 7.0);
	float r0 = noise3(r);
	vec3 rslope = vec3(noise3(r + vec3(e, 0, 0)) - r0, noise3(r + vec3(0, e, 0)) - r0, noise3(r + vec3(0, 0, e)) - r0) / e;
	slope += rslope * sign(r0 - 0.5) * (seam + fold) * 3.0;
	vec3 tilt = (VIEW_MATRIX * MODEL_MATRIX * vec4(slope, 0.0)).xyz;
	NORMAL = normalize(NORMAL - tilt * bump * (0.5 + boil * 0.6));
	wet = max(boil * 0.9, pox.y);
}
%s
"""

const TRAIL_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 film : source_color = vec3(0.24, 0.2, 0.1);
uniform vec3 sky : source_color = vec3(0.7, 0.72, 0.68);

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
	// A smear of fluid and pus: thickest in the middle, streaked along the way it went.
	vec2 c = UV * 2.0 - 1.0;
	float edge = 1.0 - smoothstep(0.5, 1.0, abs(c.x) + noise2(world.xz * 0.9) * 0.4);
	float ends = 1.0 - smoothstep(0.6, 1.0, abs(c.y));
	float a = edge * ends * fade * mix(0.2, 0.6, noise2(world.xz * 2.1 + 4.0));
	float glance = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = film;
	EMISSION = sky * glance * 0.3 * fade;
	ROUGHNESS = 0.2;
	SPECULAR = 0.7;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

static var _shader: Shader
static var _core: ArrayMesh
static var _core_lo: ArrayMesh
static var _trail_material: ShaderMaterial
static var _noise: FastNoiseLite
static var _people := {}


## A material for one mound's core (its own: its uniforms are its own).
static func core_material() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER % [FleshParts.COMMON, FleshParts.LIGHT]
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter(&"length_half", RADII.z)
	return material


static func trail_material() -> ShaderMaterial:
	if _trail_material == null:
		var shader := Shader.new()
		shader.code = TRAIL_SHADER
		_trail_material = ShaderMaterial.new()
		_trail_material.shader = shader
	return _trail_material


## Half its width, height and length with `bodies` in it (a mound; the
## others' core is a lump where their boys are joined).
static func radii(bodies: int) -> Vector3:
	match form(bodies):
		Form.PAIR:
			return Vector3(0.15, 0.1, 0.24)
		Form.AMALGAM:
			return Vector3(0.3, 0.3, 0.3)
		Form.STRIDER:
			return Vector3(0.26, 0.2, 0.26)
	var t := clampf(float(bodies - SMALL - 1) / float(MOST - SMALL - 1), 0.0, 1.0)
	return Vector3(1.3, 0.9, 1.5).lerp(Vector3(2.6, 1.6, 2.9), t)


## How big each boy in it is against the player's boy.
static func boy_size(bodies: int) -> float:
	match form(bodies):
		Form.PAIR:
			return 1.2
		Form.AMALGAM:
			return 1.3
		Form.STRIDER:
			return 1.45
	return lerpf(1.8, 2.3, clampf(float(bodies - SMALL - 1) / float(MOST - SMALL - 1), 0.0, 1.0))


## Where a point of the core (as built) is moved to by the heaving, as the
## shader moves it (leaving out what is along the surface's normal), with the
## same uniforms (`u`: crawl, surge, jiggle, bounce, rear, bend, lunge).
static func heave(v: Vector3, u: Dictionary, hang := 0.0) -> Vector3:
	var along := clampf(-v.z / RADII.z, -1.4, 1.4)
	var up := clampf(v.y / 5.0, 0.0, 1.0)
	var ground := smoothstep(0.0, 0.8, v.y)
	var band := pow(0.5 + 0.5 * sin(TAU * (u.crawl / 3.2 - along * 0.9)), 3.0)
	var surge: float = u.surge
	var out := v
	out.x -= v.x * band * 0.11 * surge
	out.y -= v.y * band * 0.08 * surge * ground
	out.z -= band * 0.35 * surge * ground
	out += (u.jiggle as Vector3) * up
	out.y -= hang * u.bounce
	out.x += u.bend * along * along * 1.6 * ground
	var front := smoothstep(-0.2, 1.0, along)
	out.y += u.rear * front * (1.0 + up * 1.8) * ground
	out.z += u.rear * front * 1.1 * ground
	out.z -= u.lunge * front * ground
	return out


# --- The core ---

## Swellings over the mound (direction, how much): where bodies lie under the skin.
const BULGES: Array[Vector4] = [
	Vector4(0.35, 0.85, 0.2, 0.16), Vector4(-0.45, 0.75, -0.25, 0.15), Vector4(0.0, 0.7, 0.75, 0.18),
	Vector4(-0.75, 0.25, 0.35, 0.12), Vector4(0.85, 0.15, -0.3, 0.1), Vector4(0.25, 0.45, -0.8, 0.12),
	Vector4(-0.3, 0.5, -0.85, 0.1), Vector4(0.6, 0.6, 0.6, 0.12), Vector4(-0.65, 0.55, 0.65, 0.1),
	Vector4(0.0, 1.0, 0.0, -0.06), Vector4(0.95, 0.3, 0.3, -0.05), Vector4(-0.9, 0.35, -0.45, -0.05),
	Vector4(0.0, 0.3, -1.0, 0.08),
]
## Boils on it: (direction, size).
static var _boils: Array[Vector4] = []


static func _get_noise() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 1818
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 1.0
		var rng := RandomNumberGenerator.new()
		rng.seed = 33
		for i in 26:
			var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.1, 1), rng.randf_range(-1, 1)).normalized()
			_boils.append(Vector4(d.x, d.y, d.z, rng.randf_range(0.025, 0.06)))
	return _noise


## Bodies lying just under its skin, pressing it out: (direction, kind, the
## way along them as an angle). Kinds: 0 a back (the spine a groove down it,
## the shoulder blades), 1 buttocks, 2 a shoulder and the arm from it, 3 a
## limb (a knee or an elbow in it).
static var _forms: Array[Vector4] = []


static func _make_forms() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	for i in 34:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.05, 1), rng.randf_range(-1, 1)).normalized()
		_forms.append(Vector4(d.x, d.y, d.z, float(i % 4) + rng.randf_range(0.0, 0.99)))


## How far bodies under the skin push it out in a direction (as a share of its
## radius), and how tight it is over them (0..1).
static func _bodies_under(d: Vector3) -> Vector2:
	if _forms.is_empty():
		_make_forms()
	var push := 0.0
	var tight := 0.0
	for form: Vector4 in _forms:
		var n := Vector3(form.x, form.y, form.z)
		var w := d.dot(n)
		if w < 0.85:
			continue
		var kind := int(form.w)
		var turn := fposmod(form.w, 1.0) * TAU
		var t := n.cross(Vector3.UP if absf(n.y) < 0.95 else Vector3.RIGHT).normalized().rotated(n, turn)
		var b := n.cross(t)
		var u := d.dot(t)
		var v := d.dot(b)
		var here := 0.0
		match kind:
			0:
				here = 0.05 * exp(-(u * u / 0.04 + v * v / 0.0056))
				here -= 0.016 * exp(-v * v / 0.0003) * exp(-u * u / 0.03)
				here += 0.018 * (exp(-((u - 0.12) * (u - 0.12) + (v - 0.045) * (v - 0.045)) / 0.0012) + exp(-((u - 0.12) * (u - 0.12) + (v + 0.045) * (v + 0.045)) / 0.0012))
			1:
				here = 0.04 * (exp(-(u * u + (v - 0.045) * (v - 0.045)) / 0.0018) + exp(-(u * u + (v + 0.045) * (v + 0.045)) / 0.0018))
				here += 0.02 * exp(-((u + 0.09) * (u + 0.09) / 0.006 + v * v / 0.004))
			2:
				here = 0.04 * exp(-(u * u + v * v) / 0.0022)
				here += 0.024 * exp(-((u - 0.13) * (u - 0.13) / 0.012 + v * v / 0.0007))
			_:
				here = 0.026 * exp(-(u * u / 0.03 + v * v / 0.0008))
				here += 0.016 * exp(-(u * u + v * v) / 0.0009)
		push = maxf(push, here)
		tight = maxf(tight, clampf(here / 0.035, 0.0, 1.0))
	return Vector2(push, tight)


static func _swell(d: Vector3) -> float:
	var most := 0.0
	for bulge: Vector4 in BULGES:
		if bulge.w > 0.0:
			var at := Vector3(bulge.x, bulge.y, bulge.z).normalized()
			most = maxf(most, exp(-(1.0 - d.dot(at)) * 7.0) * bulge.w / 0.16)
	return clampf(most, 0.0, 1.0)


## How much of a boil a direction is in (0..1).
static func _boil(d: Vector3) -> float:
	_get_noise()
	var most := 0.0
	for boil: Vector4 in _boils:
		var at := Vector3(boil.x, boil.y, boil.z)
		var off := (d - at).length() / boil.w
		most = maxf(most, clampf(1.0 - off * off, 0.0, 1.0))
	return most


static func _lump(direction: Vector3) -> Vector3:
	var d := direction.normalized()
	var noise := _get_noise()
	var r := 1.0
	r += 0.05 * sin(d.x * 4.0 + 1.1) * sin(d.z * 3.5 + 0.7)
	for bulge: Vector4 in BULGES:
		var at := Vector3(bulge.x, bulge.y, bulge.z).normalized()
		r += bulge.w * exp(-(1.0 - d.dot(at)) * 7.0)
	var q := d * 2.0
	r += 0.08 * noise.get_noise_3d(q.x, q.y, q.z)
	# Folds where the bodies it is made of were pressed together.
	q = d * 4.0 + Vector3(11.0, 3.0, 7.0)
	r -= 0.05 * pow(1.0 - absf(noise.get_noise_3d(q.x, q.y, q.z)), 6.0)
	q = d * 9.0 + Vector3(-4.0, 9.0, 2.0)
	r += 0.012 * noise.get_noise_3d(q.x, q.y, q.z)
	# Boils, raised.
	r += 0.035 * sqrt(_boil(d))
	# Bodies just under the skin.
	r += _bodies_under(d).x
	var size := RADII if d.y > 0.0 else Vector3(RADII.x, BELOW, RADII.z)
	return d * size * r + Vector3.UP * MIDDLE


static func _on_ground(p: Vector3) -> Vector3:
	var t := p.y
	var floor_y := 0.04
	var soft := 0.45
	var y := 0.5 * (t + floor_y + sqrt((t - floor_y) * (t - floor_y) + soft * soft)) - soft * 0.5
	y = maxf(y, 0.0)
	var pressed := clampf((1.2 - t) / 2.5, 0.0, 1.0)
	return Vector3(p.x * (1.0 + 0.12 * pressed), y, p.z * (1.0 + 0.08 * pressed))


## A point on the core's surface in a direction from its middle (as built).
static func surface(direction: Vector3) -> Vector3:
	return _on_ground(_lump(direction))


static func surface_normal(direction: Vector3) -> Vector3:
	var d := direction.normalized()
	var a := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var b := d.cross(a)
	var e := 0.02
	var p := surface(d)
	var n := (surface(d + a * e) - p).cross(surface(d + b * e) - p).normalized()
	return n if n.dot(p - Vector3.UP * MIDDLE) > 0.0 else -n


## How far into the core (as built) a point is: less than 1 inside.
static func inside(point: Vector3) -> float:
	var p := point - Vector3.UP * MIDDLE
	if p.y < 0.0:
		p.y *= RADII.y / (MIDDLE + 0.3)
	var r := RADII * Vector3(1.12, 1.1, 1.05)
	return Vector3(p.x / r.x, p.y / r.y, p.z / r.z).length()


## The core: an icosphere pushed out into its lumps and boils, its belly on the ground (built once).
static func core(low := false) -> ArrayMesh:
	if low and _core_lo != null:
		return _core_lo
	if not low and _core != null:
		return _core
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
	for level in (4 if low else 5):
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
	var sums := PackedVector3Array()
	sums.resize(points.size())
	for f: Vector3i in faces:
		var n := (points[f.y] - points[f.x]).cross(points[f.z] - points[f.x])
		sums[f.x] += n
		sums[f.y] += n
		sums[f.z] += n
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	for i in points.size():
		var n := sums[i].normalized()
		if n.dot(points[i] - Vector3.UP * MIDDLE) < 0.0:
			n = -n
		normals.append(n)
		var d := dirs[i]
		colours.append(Color(maxf(_swell(d) * 0.4, _bodies_under(d).y), smoothstep(0.55, 0.0, absf(d.y + 0.05)) * 0.8, smoothstep(0.1, 0.5, _boil(d)), 0.0))
	var indices := PackedInt32Array()
	for f: Vector3i in faces:
		var n := (points[f.y] - points[f.x]).cross(points[f.z] - points[f.x])
		if n.dot(normals[f.x] + normals[f.y] + normals[f.z]) > 0.0:
			indices.append_array([f.x, f.z, f.y])
		else:
			indices.append_array([f.x, f.y, f.z])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if low:
		_core_lo = mesh
	else:
		_core = mesh
	return mesh


static func _middle(dirs: Array[Vector3], middles: Dictionary, a: int, b: int) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if middles.has(key):
		return middles[key]
	dirs.append(((dirs[a] + dirs[b]) * 0.5).normalized())
	middles[key] = dirs.size() - 1
	return dirs.size() - 1


# --- The people in it ---

## The boy's hips at rest (his model's origin is at his feet).
const HIPS := Vector3(0.0, 0.62, 0.0)


## The people in one with `bodies` in it (built once for each number, and
## each of full and low detail), in the skeleton's space with `size` 1: a
## FleshParts.Build whose copies carry, in `data`:
##   "boy": whether it is a boy (else a man's limb grown out of the core),
##   "roles": the Role of each of its chains, by name,
##   "anchor": the point of the core (as built) its root grows from, so that
##       it heaves with it, and "offset": its root from there (the skeleton's
##       space): a mound's; "spoke": its angle about the hub: an amalgam's or a
##       strider's; "top": whether it is the one on top: a pair's,
##   "out": the way out of the core there, "phase": a seed for its own motions.
static func people(bodies: int, low := false) -> FleshParts.Build:
	bodies = clampi(bodies, FEWEST, MOST)
	var key := "%d%s" % [bodies, "lo" if low else ""]
	if _people.has(key):
		return _people[key]
	var build := FleshParts.Build.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	match form(bodies):
		Form.PAIR:
			_pair(build, low, rng)
		Form.AMALGAM:
			_star(build, bodies, low, rng)
		Form.STRIDER:
			_ring(build, bodies, low, rng)
		_:
			_mound(build, bodies, low, rng)
	build.make()
	_people[key] = build
	return build


## How high the hub of a small one is at rest, at size 1.
const HUB := 1.0
## How high a pair's backs are, and a strider's hips, at rest (for a boy of size 1).
const PAIR_HIGH := 0.5
const RING_HIGH := 0.56
## How far apart a pair's hips are (for a boy of size 1): his hips to his shoulders.
const PAIR_LONG := 0.4


## A pair: two boys grown together back to back along their length, the one
## under on all fours, his head to the front (-Z), the one on top lying face
## up, his head to the back, so that each one's shoulders are on the other's
## hips. All eight limbs reach down to the ground.
static func _pair(build: FleshParts.Build, low: bool, rng: RandomNumberGenerator) -> void:
	var s := boy_size(PAIR)
	for top: bool in [false, true]:
		var along := Vector3.BACK if top else Vector3.FORWARD
		var basis := FleshParts.frame(along, Vector3.UP if top else Vector3.DOWN)
		var hips := Vector3(0.0, (PAIR_HIGH + (0.07 if top else -0.07)) * s, 0.0) - along * PAIR_LONG * 0.5 * s
		var place := Transform3D(basis * s, hips - (basis * s) * HIPS)
		var copy := build.add("boy", place, 0.15, 0.5, rng.randf(), low)
		copy.data = {"boy": true, "top": top, "along": along, "phase": rng.randf() * TAU,
			"roles": {"arm_l": Role.CRAWL, "arm_r": Role.CRAWL, "leg_l": Role.CRAWL, "leg_r": Role.CRAWL}}


## A strider: the boys joined at their hips in a ring about a hub held up on
## their legs, each bent over outwards (his front out and down), facing out
## all round.
static func _ring(build: FleshParts.Build, bodies: int, low: bool, rng: RandomNumberGenerator) -> void:
	var s := boy_size(bodies)
	for k in bodies:
		var spoke := TAU * (k + 0.5) / bodies
		var out := Vector3(-sin(spoke), 0.0, -cos(spoke))
		var basis := FleshParts.frame(out * 0.65 + Vector3.UP * 0.75, out + Vector3.DOWN * 0.8)
		var hips := Vector3.UP * RING_HIGH * s + out * 0.1 * s
		var place := Transform3D(basis * s, hips - (basis * s) * HIPS)
		var copy := build.add("boy", place, 0.12, 0.45, rng.randf(), low)
		copy.data = {"boy": true, "spoke": spoke, "out": out, "phase": rng.randf() * TAU,
			"roles": {"arm_l": Role.GRAB, "arm_r": Role.GRAB, "leg_l": Role.CRAWL, "leg_r": Role.CRAWL}}


## A small one: the boys joined at their hips in a wheel (in the plane of Y and
## Z, rolling along -Z), their heads out, facing either way in turn.
static func _star(build: FleshParts.Build, bodies: int, low: bool, rng: RandomNumberGenerator) -> void:
	var s := boy_size(bodies)
	for k in bodies:
		var spoke := TAU * k / bodies
		var out := Vector3(0.0, cos(spoke), -sin(spoke))
		var front := Vector3.RIGHT if k % 2 == 0 else Vector3.LEFT
		var basis := FleshParts.frame(out, front)
		var hips := Vector3.UP * HUB + out * 0.1 * s
		var place := Transform3D(basis * s, hips - (basis * s) * HIPS)
		var copy := build.add("boy", place, 0.1, 0.5, rng.randf(), low)
		copy.data = {"boy": true, "spoke": spoke, "out": out, "front": front, "phase": rng.randf() * TAU,
			"roles": {"arm_l": Role.WHEEL, "arm_r": Role.WHEEL, "leg_l": Role.WHEEL, "leg_r": Role.WHEEL}}


## Directions on the dome for the boys, the first at its front (so that even a
## small mound has someone to grab with), then over its top and round.
const SLOTS: Array[Vector3] = [Vector3(0.0, 0.5, -1.0), Vector3(0.1, 1.0, 0.1), Vector3(-0.85, 0.5, 0.1),
	Vector3(0.85, 0.5, -0.1), Vector3(-0.1, 0.6, 0.95), Vector3(0.55, 0.75, 0.6), Vector3(-0.55, 0.8, -0.5),
	Vector3(0.6, 0.45, -0.75), Vector3(-0.6, 0.45, -0.75), Vector3(-0.5, 0.75, 0.6)]
## Between them, for the bodies sunk with only their backs or faces and ribs out.
const BETWEEN: Array[Vector3] = [Vector3(0.45, 0.85, -0.3), Vector3(-0.4, 0.9, 0.25), Vector3(0.75, 0.6, 0.3),
	Vector3(-0.8, 0.55, -0.35), Vector3(0.1, 0.65, 0.8), Vector3(-0.25, 0.7, -0.75)]


## A mound: the core, and packed into it its boys (lying face up, lying face
## down with their backs out, or rising from it to the waist), men's bodies
## sunk in it to their ribs between them, and men's limbs growing out of it.
static func _mound(build: FleshParts.Build, bodies: int, low: bool, rng: RandomNumberGenerator) -> void:
	var k_n := radii(bodies) / RADII
	var s := boy_size(bodies)
	# (the boys' bodies in the bigger ones are the low-detail boy: there are many)
	var boy_low := low or bodies > 6
	for k in bodies:
		var d := (SLOTS[k % SLOTS.size()] + Vector3(rng.randf_range(-0.08, 0.08), 0.0, rng.randf_range(-0.08, 0.08))).normalized()
		var at := surface(d)
		var normal := surface_normal(d)
		var pose := 0 if d.z < -0.6 else 1 + (k % 3)
		var roles := {}
		var basis: Basis
		var hips: Vector3
		var up_slope := (Vector3.UP - normal * normal.y).normalized() if absf(normal.y) < 0.95 else Vector3.FORWARD
		var along := up_slope.rotated(normal, rng.randf_range(-1.0, 1.0))
		var meat := 0.2
		match pose:
			0, 3:
				# Rising out of it to the waist, leaning out, his arms free.
				var lean := (normal * 0.8 + Vector3.UP * 0.35).normalized()
				var facing := Vector3(d.x, 0.0, d.z).normalized() if Vector2(d.x, d.z).length() > 0.1 else Vector3.FORWARD
				basis = FleshParts.frame(lean, facing)
				hips = -normal * 0.16 * s
				var arm_role := Role.GRAB if pose == 0 else (Role.CRAWL if d.y < 0.55 else Role.REACH)
				roles = {"arm_l": arm_role, "arm_r": arm_role, "leg_l": Role.TUCKED, "leg_r": Role.TUCKED}
				meat = 0.22
			1:
				# Face up, sunk to his front: his mask, chest and knees out of it.
				basis = FleshParts.frame(along, normal)
				hips = -normal * 0.08 * s - along * 0.1 * s
				roles = {"arm_l": Role.REACH if k % 2 == 0 else Role.LIMP, "arm_r": Role.LIMP if k % 2 == 0 else Role.REACH,
					"leg_l": Role.KICK, "leg_r": Role.DANGLE}
				meat = 0.0
			_:
				# Face down, sunk to his back: his back, shoulders and buttocks out, a leg kicking.
				basis = FleshParts.frame(along, -normal)
				hips = -normal * 0.07 * s - along * 0.1 * s
				roles = {"arm_l": Role.CRAWL if d.y < 0.6 else Role.LIMP, "arm_r": Role.TUCKED,
					"leg_l": Role.TUCKED, "leg_r": Role.KICK}
				meat = 0.0
		var root := at * k_n + hips
		var place := Transform3D(basis * s, root - (basis * s) * HIPS)
		var copy := build.add("boy", place, meat, 0.35, rng.randf(), boy_low)
		copy.data = {"boy": true, "anchor": at, "offset": hips, "out": normal, "phase": rng.randf() * TAU, "roles": roles, "slot": d}
	# Men sunk in it between the boys, to their ribs: backs and faces pressing out.
	for i in mini(bodies / 2, BETWEEN.size()):
		var d := BETWEEN[i].normalized()
		var at := surface(d)
		var normal := surface_normal(d)
		var along := (Vector3.UP - normal * normal.y).normalized().rotated(normal, rng.randf_range(-1.5, 1.5)) if absf(normal.y) < 0.95 else Vector3.FORWARD.rotated(Vector3.UP, rng.randf_range(-PI, PI))
		var face_up := i % 2 == 1
		var scale := s * 1.15
		var basis := FleshParts.frame(along, normal if face_up else -normal) * scale
		var offset := -normal * 0.05 * scale
		var copy := build.add("torso", Transform3D(basis, at * k_n + offset), -10.0, 0.3, rng.randf(), low or bodies > 6)
		copy.data = {"boy": false, "anchor": at, "offset": offset, "out": normal, "phase": rng.randf() * TAU, "roles": {}}
	# Men's limbs growing out between them: long gaunt grabbers at the front,
	# arms hauling on the flanks, legs out of its back.
	var long_arms := 2 if bodies < 7 else (3 if bodies < 9 else 4)
	var arms := 2 + bodies / 4
	var legs := bodies / 3
	var limbs: Array = []
	var front_spots: Array[Vector3] = [Vector3(0.32, 0.45, -1.0), Vector3(-0.32, 0.42, -1.0), Vector3(0.62, 0.3, -0.85), Vector3(-0.62, 0.32, -0.85)]
	for i in long_arms:
		limbs.append(["long_r" if front_spots[i].x > 0.0 else "long_l", Role.GRAB, front_spots[i], Vector3(signf(front_spots[i].x) * 0.2, 0.0, -0.5), 0.12, 2.2])
	var flank_spots: Array[Vector3] = [Vector3(-0.9, 0.3, -0.45), Vector3(0.9, 0.3, -0.4), Vector3(-0.97, 0.3, 0.25), Vector3(0.96, 0.3, 0.3), Vector3(-0.8, 0.35, 0.7)]
	for i in arms:
		var spot := flank_spots[i % flank_spots.size()]
		limbs.append(["arm_r" if spot.x > 0.0 else "arm_l", Role.CRAWL, spot, Vector3(signf(spot.x) * 0.4, -0.2, -0.2), 0.05, 2.1])
	var back_spots: Array[Vector3] = [Vector3(0.4, 0.7, 0.8), Vector3(-0.45, 0.55, 0.85), Vector3(0.75, 0.35, 0.65)]
	for i in legs:
		var spot := back_spots[i % back_spots.size()]
		limbs.append(["leg_r" if spot.x > 0.0 else "leg_l", Role.KICK if i % 2 == 0 else Role.DANGLE, spot, Vector3(signf(spot.x) * 0.3, 0.2, 0.3), 0.1, 2.1])
	for entry: Array in limbs:
		var d := (entry[2] as Vector3).normalized()
		var at := surface(d)
		var out := (surface_normal(d) + (entry[3] as Vector3)).normalized()
		var scale: float = entry[5]
		var sink: float = entry[4]
		var palm := Vector3.DOWN if absf(out.y) < 0.9 else Vector3.FORWARD
		var basis := FleshParts.frame(out, palm) * scale
		var offset := -out * sink * scale
		var copy := build.add(entry[0], Transform3D(basis, at * k_n + offset), sink + 0.06, 0.3, rng.randf(), low or bodies > 6)
		var chain := "arm" if copy.chains.has("arm") else "leg"
		copy.data = {"boy": false, "anchor": at, "offset": offset, "out": out, "phase": rng.randf() * TAU, "roles": {chain: entry[1]}}


## The trail: `count` flat patches, all hidden to start.
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


static var _bridge: ArrayMesh


## A bridge of stretched skin: a tube along +Y from 0 to 1, as thick as 1 at its
## ends and pulled thinner in the middle, lumpy, drawn with the people's skin
## (FleshParts.material): folded along its length, a few boils.
static func bridge() -> ArrayMesh:
	if _bridge != null:
		return _bridge
	var noise := _get_noise()
	var sides := 16
	var rings := 14
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var custom := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	for i in rings + 1:
		var y := float(i) / rings
		var thick := lerpf(1.0, 0.55, sin(y * PI))
		for k in sides + 1:
			var a := TAU * k / sides
			var lump := 1.0 + 0.14 * noise.get_noise_3d(cos(a) * 2.0, y * 7.0, sin(a) * 2.0)
			var p := Vector3(cos(a) * thick * lump, y, sin(a) * thick * lump)
			verts.append(p)
			normals.append(Vector3(cos(a), 0.0, sin(a)))
			# (its marks as on a body some 2 m long and 1 round)
			custom.append_array([p.x * 0.6, y * 2.4, p.z * 0.6, 0.0])
			# (folded all along, as a join is)
			uvs.append(Vector2(0.0, 0.1))
			uv2s.append(Vector2(0.3, 0.6))
			colours.append(Color(0, 0, 0, 0))
	for i in rings:
		for k in sides:
			var a := i * (sides + 1) + k
			var b := a + sides + 1
			indices.append_array([a, a + 1, b, a + 1, b + 1, b])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	arrays[Mesh.ARRAY_INDEX] = indices
	_bridge = ArrayMesh.new()
	_bridge.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return _bridge

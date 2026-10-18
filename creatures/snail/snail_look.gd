class_name SnailLook
## What the giant snail (Snail, creatures/snail/snail.gd) is drawn with: one
## material for its skin, one for its shell (the model's two surfaces), and
## one for the slime it leaves, so that it is a few draws however long its
## trail.
##
## - SKIN: wet grey-brown skin, lit in hard bands (cel shading), grooved all
##   over into small raised tubercles in long slanting rows, as a snail's is,
##   each of them catching a hard glint of the sky (it glistens). The model's
##   vertex colours say where it is creased (red: dark), how far down the
##   foot's fringe a point is (green: where the muscle waves show, dark bands
##   running forward along it as it crawls: `crawl`, the distance it has gone,
##   and `waves`, how strongly), where the skin is paler (blue: the mantle's
##   collar, the sole, under the head), and the eyes and the dark of the mouth
##   and the breathing pore (alpha).
## - SHELL: dull horn-brown with dark spiral bands broken into flecks, fine
##   growth lines across the whorls and darker checks where its growing
##   rested, a chalky worn apex and a pale lip; dark inside the mouth and down
##   the sutures (vertex colours). A soft sheen, a little wet.
## - SLIME: a film on whatever it crawled over (each patch a quad of a
##   MultiMesh, laid flat on the surface): clear, dark where it is thick, a
##   hard silvery sheen at a glance, drying to a dull silver streak at its
##   edges as it ages. Its age is worked out in the shader from when each patch
##   was laid (`now`), so that nothing is updated while it lies there.
##
## Nothing uses a texture or the screen; the slime is the only thing drawn
## see-through.

const SKIN_SHADER := """
shader_type spatial;

uniform vec3 skin : source_color = vec3(0.25, 0.24, 0.225);
uniform vec3 groove : source_color = vec3(0.11, 0.105, 0.1);
uniform vec3 pale : source_color = vec3(0.42, 0.405, 0.38);
uniform vec3 back : source_color = vec3(0.17, 0.165, 0.155);
uniform vec3 sky : source_color = vec3(0.82, 0.85, 0.88);
// The banded light.
uniform float wrap = 0.3;
uniform float flatness = 0.6;
// Tubercles: how many to a metre (along, around), how deep the grooves between them look.
uniform vec2 tubercles = vec2(9.0, 12.0);
uniform float slant = 0.6;
uniform float groove_dark = 0.32;
// How far it has crawled (m) and how strongly the muscle waves show (0..1).
uniform float crawl = 0.0;
uniform float waves = 0.0;
// Waves on the foot: how many to a metre of it.
uniform float wave_count = 1.3;
uniform float glint = 0.28;
uniform float rim_gain = 0.35;
uniform float rim_width = 0.3;

varying float fringe;
varying float flag;
varying float cell_edge;
varying float cell_dome;
varying float topside;
varying float pale_skin;

vec2 hash22(vec2 p) {
	vec3 a = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	a += dot(a, a.yzx + 33.33);
	return fract((a.xx + a.yz) * a.zy);
}

// Distance to the nearest cell's middle and to the edge between cells (a Voronoi pattern).
vec2 cells(vec2 p) {
	vec2 g = floor(p);
	vec2 f = fract(p);
	float first = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 r = o + hash22(g + o) * 0.8 + 0.1 - f;
			float d = dot(r, r);
			if (d < first) {
				second = first;
				first = d;
			} else if (d < second) {
				second = d;
			}
		}
	}
	return vec2(sqrt(first), sqrt(second) - sqrt(first));
}

void vertex() {
	fringe = COLOR.g;
	flag = COLOR.a;
	topside = NORMAL.y;
	pale_skin = COLOR.b;
	// The muscle waves: the fringe rises and falls a little in bands running forward.
	float band = sin(6.2831853 * (UV.x * wave_count - crawl * wave_count * 1.6));
	VERTEX += NORMAL * band * 0.025 * waves * fringe;
}

void fragment() {
	// (long slanting rows of tubercles, as on a snail's side)
	vec2 at = vec2(UV.x * tubercles.x + UV.y * tubercles.x * slant, UV.y * tubercles.y);
	vec2 c = cells(at);
	float pixel = fwidth(c.y) + 0.0001;
	cell_edge = 1.0 - smoothstep(0.0, 0.2 + pixel * 1.5, c.y);
	cell_dome = 1.0 - smoothstep(0.0, 0.6, c.x);
	// (the grooves fade out where they are too fine to see)
	float fine = clamp(0.35 / max(fwidth(at.x), 0.0001) - 0.5, 0.0, 1.0);
	cell_edge *= fine;
	cell_dome *= fine;
	vec3 base = mix(skin, pale, COLOR.b);
	// (darker along the back and the head's top, paler down the sides)
	base = mix(base, back, smoothstep(0.4, 0.95, topside) * (1.0 - COLOR.b));
	base *= mix(0.55, 1.0, COLOR.r);
	// Each tubercle a little dome, paler on top, the grooves between them dark.
	base *= mix(1.0, mix(0.88, 1.08, cell_dome), fine);
	base = mix(base, groove, cell_edge * groove_dark * (1.0 - COLOR.b * 0.5));
	// The muscle waves on the fringe: dark bands running forward.
	float band = 0.5 + 0.5 * sin(6.2831853 * (UV.x * wave_count - crawl * wave_count * 1.6));
	base *= 1.0 - fringe * waves * 0.35 * smoothstep(0.4, 0.9, band);
	if (flag > 0.97) {
		// An eye: black and glassy.
		base = vec3(0.025, 0.025, 0.03);
	} else if (flag > 0.4) {
		// The mouth, the breathing pore: dark.
		base = vec3(0.05, 0.045, 0.045);
	}
	ALBEDO = base;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = cut(facing * smoothstep(0.15, 0.6, reach) - cell_edge * 0.08, 0.05);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	// Wet: each tubercle catches a small hard glint, and the outline a cold rim.
	vec3 half_way = normalize(LIGHT + VIEW);
	float spec = pow(clamp(dot(NORMAL, half_way), 0.0, 1.0), 40.0);
	float shine = cut(spec * (0.15 + 0.85 * cell_dome * cell_dome) * (1.0 - cell_edge), 0.5) * glint * (1.0 - pale_skin * 0.8);
	if (flag > 0.97) {
		shine = cut(pow(clamp(dot(NORMAL, half_way), 0.0, 1.0), 60.0), 0.5) * 1.4;
	}
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(1.0 - rim_width, 1.0, graze) * mix(0.4, 1.0, lit);
	SPECULAR_LIGHT += (shine * sky + rim * rim_gain * sky * 0.5) * strength * LIGHT_COLOR / PI;
}
"""

const SHELL_SHADER := """
shader_type spatial;

uniform vec3 horn : source_color = vec3(0.34, 0.3, 0.24);
uniform vec3 band_dark : source_color = vec3(0.15, 0.125, 0.1);
uniform vec3 chalk : source_color = vec3(0.5, 0.49, 0.46);
uniform vec3 lip : source_color = vec3(0.55, 0.52, 0.47);
uniform vec3 inside : source_color = vec3(0.16, 0.12, 0.11);
uniform vec3 sky : source_color = vec3(0.82, 0.85, 0.88);
uniform float wrap = 0.25;
uniform float flatness = 0.6;
// Growth lines across a whorl, to a turn (at the mouth; fewer up the spire).
uniform float lines = 140.0;
uniform float sheen = 0.07;
uniform float rim_gain = 0.3;

varying float line_shade;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), hash(i + 1.0), f);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i.x + i.y * 57.0);
	float b = hash(i.x + 1.0 + i.y * 57.0);
	float c = hash(i.x + (i.y + 1.0) * 57.0);
	float d = hash(i.x + 1.0 + (i.y + 1.0) * 57.0);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	// UV: x, turns from the mouth (0) up to the apex (about -4.6); y, round the tube (0..1).
	float turns = UV.x;
	float around = UV.y;
	// Growth lines: fine ridges across the whorl, closer up the spire, and a few darker checks.
	float count = lines * exp(turns * 0.35);
	float ridge = 0.5 + 0.5 * sin(6.2831853 * turns * count + noise(turns * 30.0) * 3.0);
	float fine = clamp(0.5 / max(fwidth(turns * count), 0.0001) - 0.5, 0.0, 1.0);
	line_shade = (ridge - 0.5) * fine;
	float check = smoothstep(0.62, 0.9, noise(turns * 5.0 + 3.0));
	// Spiral bands round the whorl, broken into flecks along the growth lines.
	float b1 = smoothstep(0.035, 0.0, abs(around - 0.08)) ;
	float b2 = smoothstep(0.05, 0.0, abs(around - 0.2));
	float b3 = smoothstep(0.03, 0.0, abs(around - 0.33));
	float b4 = smoothstep(0.06, 0.0, abs(around - 0.92));
	float bands = max(max(b1, b2 * 0.85), max(b3 * 0.7, b4 * 0.8));
	float fleck = smoothstep(0.35, 0.65, noise2(vec2(turns * 38.0, around * 6.0)));
	vec3 colour = horn * (0.92 + 0.16 * noise2(vec2(turns * 9.0, around * 4.0)));
	colour = mix(colour, band_dark, bands * mix(0.25, 0.75, fleck));
	colour *= 1.0 - check * 0.25;
	colour *= 1.0 + line_shade * 0.05;
	// A worn, chalky apex.
	colour = mix(colour, chalk, smoothstep(-3.2, -4.4, turns) * 0.85);
	// The lip, the inside, the sutures.
	colour = mix(colour, lip, COLOR.b);
	colour *= mix(0.45, 1.0, COLOR.r);
	colour = mix(colour, inside, step(0.5, COLOR.a));
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = cut(facing * smoothstep(0.15, 0.6, reach), 0.05);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	vec3 half_way = normalize(LIGHT + VIEW);
	float spec = cut(pow(clamp(dot(NORMAL, half_way), 0.0, 1.0), 90.0), 0.6) * sheen * lit;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(0.75, 1.0, graze) * lit * rim_gain;
	SPECULAR_LIGHT += (spec * sky + rim * ALBEDO) * strength * LIGHT_COLOR / PI;
}
"""

const SLIME_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 film : source_color = vec3(0.07, 0.075, 0.08);
uniform vec3 silver : source_color = vec3(0.62, 0.64, 0.66);
uniform vec3 sky : source_color = vec3(0.85, 0.88, 0.92);
// Seconds since the trail began (the patches' ages are worked out from it).
uniform float now = 0.0;

varying float age;
varying float life;
varying float seed;
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
	// (each patch's custom data: when it was laid, how long it lasts, its own seed)
	age = now - INSTANCE_CUSTOM.r;
	life = max(INSTANCE_CUSTOM.g, 0.01);
	seed = INSTANCE_CUSTOM.b;
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (age < 0.0 || age > life) {
		// (not laid yet, or long gone)
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	float t = clamp(age / life, 0.0, 1.0);
	vec2 c = UV * 2.0 - 1.0;
	vec2 at = world.xz + world.y * 0.37;
	// A broad smear, thickest down the middle, its edges wavering; streaked along the way it went.
	float wobble = noise2(at * 0.8 + seed * 13.0) * 0.35 + noise2(at * 3.1) * 0.12;
	float edge = 1.0 - smoothstep(0.62, 1.0, abs(c.x) + wobble);
	float ends = 1.0 - smoothstep(0.55, 1.0, abs(c.y));
	float thick = (1.0 - smoothstep(0.0, 0.85, abs(c.x) + wobble * 0.6)) * mix(0.6, 1.0, noise2(at * vec2(4.0, 0.6)));
	// (it dries from its edges: a silver rim, and the film thins as it ages)
	float dry = smoothstep(0.3, 1.0, t);
	float rim = smoothstep(0.35, 0.0, abs(edge - 0.45)) * 0.6;
	float fade = 1.0 - smoothstep(0.75, 1.0, t);
	float glance = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	// Glints off the wet film, and the odd bubble.
	float bubble = smoothstep(0.92, 0.97, noise2(at * 9.0 + seed));
	ALBEDO = mix(film, silver, rim * dry + bubble * 0.4);
	EMISSION = sky * (glance * 0.55 + bubble * 0.12) * (1.0 - dry * 0.6) * fade;
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	ALPHA = clamp(edge * ends * mix(0.75, 0.35, dry) * (0.55 + thick * 0.45) * fade, 0.0, 1.0);
}
"""

static var _skin_shader: Shader
static var _shell_shader: Shader
static var _slime_material: ShaderMaterial


## Gives every surface of `model` its material, by the name the model gives it
## (skin, shell), and says which is which: {"skin": .., "shell": ..}. Each snail
## has its own skin (its waves are its own); the shell's is shared.
static func dress(model: Node) -> Dictionary:
	if _skin_shader == null:
		_skin_shader = _shader(SKIN_SHADER)
		_shell_shader = _shader(SHELL_SHADER)
	var made := {}
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var material := ShaderMaterial.new()
			material.shader = _shell_shader if String(original.resource_name) == "shell" else _skin_shader
			made[String(original.resource_name)] = material
			part.set_surface_override_material(surface, material)
	return made


## The slime's material (one for every snail: `now` is the same clock for all, Snail.clock()).
static func slime_material() -> ShaderMaterial:
	if _slime_material == null:
		_slime_material = ShaderMaterial.new()
		_slime_material.shader = _shader(SLIME_SHADER)
	return _slime_material


static func _shader(code: String) -> Shader:
	var shader := Shader.new()
	shader.code = code
	return shader

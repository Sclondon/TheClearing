// The ophan's wheels (one MultiMesh of three): pale gold, "like the gleaming of
// beryl", worn darker in their grooves and round the bezels, catching the sun
// and, most of all, the core burning inside them. The world round it is grey
// mist, so the metal's reflection is made up here: dim below, pale above, and
// the core as a hot point in it.
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform vec3 gold : source_color = vec3(0.92, 0.74, 0.42);
uniform vec3 core_position = vec3(0.0);
uniform vec3 core_color : source_color = vec3(1.0, 0.86, 0.6);
uniform float core_strength = 1.0;
uniform float core_reach = 6.0;

varying vec3 world_pos;
varying vec3 local;
varying float part;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local = VERTEX;
	part = UV2.x;
}

void fragment() {
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	// Tarnish: darker in patches, and where the rim turns in (its inner face, the grooves).
	float tarnish = noise(local * 22.0) * 0.6 + noise(local * 70.0) * 0.4;
	float radial = length(local.xz);
	float inner = smoothstep(0.99, 0.955, radial) * 0.5;
	vec3 metal = gold * (0.75 + 0.35 * tarnish) * (1.0 - 0.35 * inner);
	if (part > 0.5 && part < 1.5) {
		metal *= 1.08;
	}
	// Fine engraved lines running round the outside band.
	float lines = smoothstep(0.35, 0.0, abs(fract(local.y * 140.0) - 0.5)) * step(0.995, radial) * step(abs(local.y), 0.05);
	metal *= 1.0 - 0.18 * lines;
	ALBEDO = metal * 0.5;
	METALLIC = 0.0;
	ROUGHNESS = 0.38;
	SPECULAR = 0.9;

	vec3 bounce = reflect(-view_world, n_world);
	vec3 sky = mix(vec3(0.42, 0.36, 0.26), vec3(1.0, 0.97, 0.9), smoothstep(-0.5, 0.6, bounce.y));
	float edge = pow(1.0 - clamp(dot(n_world, view_world), 0.0, 1.0), 3.0);
	vec3 shine = metal * sky * (0.55 + 0.45 * edge);
	// The core: lighting the metal, and seen in it.
	vec3 to_core = core_position - world_pos;
	float dist = length(to_core);
	to_core /= max(dist, 0.001);
	float falloff = core_strength / (1.0 + dist * dist / (core_reach * core_reach) * 3.0);
	float facing = clamp(dot(n_world, to_core), 0.0, 1.0);
	float glint = pow(clamp(dot(bounce, to_core), 0.0, 1.0), 40.0);
	EMISSION = shine * 0.75 + metal * core_color * falloff * (0.25 + facing * 0.9) + core_color * glint * falloff * 1.2;
}

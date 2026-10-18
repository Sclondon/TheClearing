// The ophan's eyes (Ophan draws them all as one MultiMesh): a wet white with
// veins towards the back, a coloured iris of fibres with a darker limbal ring
// and a paler ring round the pupil, a black pupil, and the clear dome of the
// cornea that shows the burning core in it as a hard bright point. Nothing is
// a texture: it is all worked out from where a point lies on the ball, whose
// front is +Z (the model's rings of vertices run round it).
//
// Each eye's INSTANCE_CUSTOM: r how wide its pupil is (0 a pinprick, 1 wide),
// g which iris (0..1 over IRISES), b how bloodshot.
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

// The core's light: where it is (world), its colour and how strong.
uniform vec3 core_position = vec3(0.0);
uniform vec3 core_color : source_color = vec3(1.0, 0.86, 0.6);
uniform float core_strength = 1.0;
// How far the core's light reaches (metres, scaled with the ophan).
uniform float core_reach = 6.0;

varying vec3 ball;
varying vec4 custom;
varying vec3 world_pos;

const vec3 IRISES[6] = vec3[6](
	vec3(0.32, 0.46, 0.55),   // grey-blue
	vec3(0.42, 0.33, 0.16),   // hazel
	vec3(0.55, 0.42, 0.18),   // amber
	vec3(0.25, 0.36, 0.3),    // green
	vec3(0.26, 0.17, 0.11),   // brown
	vec3(0.6, 0.62, 0.62)     // pale, almost white
);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	ball = VERTEX;
	custom = INSTANCE_CUSTOM;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 d = normalize(ball);
	float theta = acos(clamp(d.z, -1.0, 1.0));
	float phi = atan(d.y, d.x);
	float iris_edge = 0.5;
	float pupil = mix(0.07, 0.3, custom.r);
	int which = int(clamp(custom.g, 0.0, 0.999) * 6.0);
	vec3 iris_color = IRISES[which];

	// The white: ivory, pinker and darker towards the back, with veins.
	vec3 white = vec3(0.9, 0.87, 0.82);
	white = mix(white, vec3(0.78, 0.55, 0.5), smoothstep(0.9, 1.9, theta));
	float vein_lines = 0.0;
	for (int k = 0; k < 3; k++) {
		float f = float(k);
		float v = abs(sin(phi * (3.0 + f * 2.0) + f * 1.7 + sin(theta * (5.0 + f * 3.0) + phi * 2.0) * 1.3));
		vein_lines = max(vein_lines, 1.0 - smoothstep(0.0, 0.05 + 0.03 * f, v));
	}
	float veins = vein_lines * smoothstep(0.75, 1.5, theta) * (0.35 + 0.65 * custom.b);
	white = mix(white, vec3(0.62, 0.12, 0.1), veins * 0.75);

	// The iris: fibres running out from the pupil, crypts, a paler ring round the pupil, a dark ring at its edge.
	float r = theta / iris_edge;
	float fibres = noise(vec2(phi * 26.0, r * 3.0)) * 0.6 + noise(vec2(phi * 70.0, r * 9.0)) * 0.4;
	vec3 iris = iris_color * (0.55 + 0.9 * fibres);
	float collar = smoothstep(pupil / iris_edge, pupil / iris_edge + 0.12, r) * (1.0 - smoothstep(pupil / iris_edge + 0.14, pupil / iris_edge + 0.32, r));
	iris = mix(iris, vec3(0.82, 0.66, 0.32), collar * 0.55);
	iris *= 1.0 - 0.55 * smoothstep(0.78, 1.0, r);
	float crypt = smoothstep(0.62, 0.75, noise(vec2(phi * 9.0, r * 4.0 + 3.0))) * smoothstep(0.35, 0.6, r) * (1.0 - smoothstep(0.85, 0.95, r));
	iris *= 1.0 - 0.45 * crypt;

	float in_iris = 1.0 - smoothstep(iris_edge - 0.015, iris_edge + 0.015, theta);
	float in_pupil = 1.0 - smoothstep(pupil - 0.012, pupil + 0.012, theta);
	vec3 color = mix(white, iris, in_iris);
	color = mix(color, vec3(0.01), in_pupil);
	// (its edges, behind the lids, in shadow)
	color *= 1.0 - 0.45 * smoothstep(1.0, 1.7, theta);
	ALBEDO = color;
	ROUGHNESS = 0.12;
	SPECULAR = 0.6;

	// The core's light on it, and the core itself seen in the wet of it.
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 to_core = core_position - world_pos;
	float dist = length(to_core);
	to_core /= max(dist, 0.001);
	float falloff = core_strength / (1.0 + dist * dist / (core_reach * core_reach) * 4.0);
	float facing = clamp(dot(n_world, to_core) * 0.6 + 0.4, 0.0, 1.0);
	EMISSION = color * core_color * facing * falloff * 0.55;
	vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 bounce = reflect(-view_world, n_world);
	float glint = smoothstep(0.985, 0.996, dot(bounce, to_core));
	EMISSION += core_color * glint * 2.5 * (0.4 + 0.6 * core_strength) * (1.0 - smoothstep(0.55, 0.7, theta));
}

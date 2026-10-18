// The lids round each of the ophan's eyes (one MultiMesh), and their lashes.
// The model says what each vertex is (UV2.x: 1 the upper lid, 2 the lower, 3 an
// upper lash, 4 a lower) and how far round the eye's X axis it turns as the eye
// shuts (UV2.y, radians), so a blink is a sheet of skin drawn down over it, its
// margin furthest and its far edge not at all. UV.x is how far a point is from
// the margin.
//
// Each eye's INSTANCE_CUSTOM: r how shut (0 open, 1 shut), g how wide it
// stares (the lids drawn back off the eye), b how much they quiver.
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

uniform vec3 skin : source_color = vec3(0.8, 0.66, 0.56);
uniform vec3 margin_color : source_color = vec3(0.68, 0.36, 0.33);
uniform vec3 lash : source_color = vec3(0.08, 0.06, 0.05);
uniform vec3 core_position = vec3(0.0);
uniform vec3 core_color : source_color = vec3(1.0, 0.86, 0.6);
uniform float core_strength = 1.0;
uniform float core_reach = 6.0;

varying float kind;
varying float from_margin;
varying vec3 world_pos;

void vertex() {
	kind = UV2.x;
	from_margin = UV.x;
	float upper = (kind < 1.5 || (kind > 2.5 && kind < 3.5)) ? 1.0 : -1.0;
	float shut = INSTANCE_CUSTOM.r;
	float wide = INSTANCE_CUSTOM.g;
	float quiver = INSTANCE_CUSTOM.b * sin(TIME * 31.0 + float(INSTANCE_ID) * 1.7) * 0.03;
	float angle = UV2.y * (shut - wide * 0.22 + quiver) * upper;
	float c = cos(angle);
	float s = sin(angle);
	VERTEX = vec3(VERTEX.x, VERTEX.y * c - VERTEX.z * s, VERTEX.y * s + VERTEX.z * c);
	NORMAL = vec3(NORMAL.x, NORMAL.y * c - NORMAL.z * s, NORMAL.y * s + NORMAL.z * c);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 color = mix(margin_color, skin, smoothstep(0.0, 0.05, from_margin));
	// (a crease shadow above the upper lid, and the skin darker far back)
	color *= 1.0 - 0.18 * smoothstep(0.24, 0.3, from_margin) * (1.0 - smoothstep(0.32, 0.4, from_margin));
	color *= 1.0 - 0.3 * smoothstep(0.55, 1.0, from_margin);
	if (kind > 2.5) {
		color = lash;
	}
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = color;
	ROUGHNESS = from_margin < 0.04 ? 0.25 : 0.7;
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 to_core = core_position - world_pos;
	float dist = length(to_core);
	float falloff = core_strength / (1.0 + dist * dist / (core_reach * core_reach) * 4.0);
	float facing = clamp(dot(n_world, to_core / max(dist, 0.001)) * 0.6 + 0.4, 0.0, 1.0);
	EMISSION = color * core_color * facing * falloff * 0.5;
	// (thin skin: the light comes through it a little, warm)
	EMISSION += vec3(0.5, 0.12, 0.06) * falloff * 0.12 * (1.0 - facing);
}

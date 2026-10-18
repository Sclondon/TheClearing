// The seraph's wings (one MultiMesh of six). The model is one wing laid open in
// its own plane (arm along +X from the shoulder, feathers hanging -Y, outer face
// +Z); this folds it at the elbow and the wrist, as a bird does, from UV2.x
// (which bone carries a point: 0 the arm, 1 the forearm, 2 the hand, blended
// between at the joints), cups it round so the tips come forward, and stirs the
// long feathers. The feathers are ivory, barbed and shafted, the coverts warmer;
// the core's light falls on whatever faces it and shines through the rest, so a
// wing folded in front of the core glows gold at its thin edges.
//
// Each wing's INSTANCE_CUSTOM: r how folded (0 open, 1 shut), g how cupped,
// b a phase for its stirring, a how much it stirs.
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

uniform vec3 feather : source_color = vec3(0.93, 0.9, 0.82);
uniform vec3 covert : source_color = vec3(0.95, 0.85, 0.62);
uniform vec3 shaft_color : source_color = vec3(0.98, 0.9, 0.7);
uniform vec2 elbow = vec2(0.3, 0.035);
uniform vec2 wrist = vec2(0.58, 0.0);
uniform vec3 core_position = vec3(0.0);
uniform vec3 core_color : source_color = vec3(1.0, 0.86, 0.6);
uniform float core_strength = 1.0;
uniform float core_reach = 6.0;

varying vec2 blade;
varying float tier;
varying vec3 world_pos;

vec2 turn(vec2 p, vec2 pivot, float a) {
	vec2 q = p - pivot;
	float c = cos(a);
	float s = sin(a);
	return pivot + vec2(q.x * c - q.y * s, q.x * s + q.y * c);
}

void vertex() {
	blade = UV;
	tier = UV2.y * 10.0;
	float chain = UV2.x;
	float fold = INSTANCE_CUSTOM.r;
	float cup = INSTANCE_CUSTOM.g;
	float a_elbow = -fold * 0.8;
	float a_wrist = -fold * 1.7;
	vec2 p = VERTEX.xy;
	vec2 fore = turn(p, elbow, a_elbow);
	vec2 hand = turn(turn(p, wrist, a_wrist), elbow, a_elbow);
	vec2 q;
	float angle;
	if (chain <= 1.0) {
		q = mix(p, fore, chain);
		angle = a_elbow * chain;
	} else {
		q = mix(fore, hand, chain - 1.0);
		angle = a_elbow + a_wrist * (chain - 1.0);
	}
	float z = VERTEX.z + fold * max(chain - 1.0, 0.0) * 0.012;
	// Stirring: a slow ripple out along the long feathers.
	float stir = INSTANCE_CUSTOM.a * sin(TIME * 2.3 + q.x * 7.0 + q.y * 4.0 + INSTANCE_CUSTOM.b) * 0.012 * smoothstep(0.1, 0.9, length(q));
	// Cupped: the further out, the further forward.
	float out_r = length(q);
	z += cup * out_r * out_r * 0.45 + stir;
	vec2 slope = cup * q * 0.9;
	float c = cos(angle);
	float s = sin(angle);
	vec3 n = vec3(NORMAL.x * c - NORMAL.y * s, NORMAL.x * s + NORMAL.y * c, NORMAL.z);
	n.xy -= slope * n.z;
	NORMAL = normalize(n);
	VERTEX = vec3(q, z);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float across = blade.x;
	float along = blade.y;
	vec3 color = tier > 1.5 ? mix(feather, covert, smoothstep(1.5, 4.0, tier)) : feather;
	// Barbs: fine lines slanting out from the shaft towards the tip.
	float barbs = 0.5 + 0.5 * sin((along * 1.0 - abs(across) * 0.35) * 160.0);
	color *= 0.9 + 0.1 * barbs;
	// The shaft, and the quill's root greyer.
	float shaft = 1.0 - smoothstep(0.03, 0.08, abs(across));
	color = mix(color, shaft_color, shaft * 0.7);
	color *= mix(0.72, 1.0, smoothstep(0.0, 0.3, along));
	// The vanes' edges a little darker, which marks one feather off from the next.
	color *= 1.0 - 0.18 * smoothstep(0.8, 1.0, abs(across));
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = color;
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 to_core = core_position - world_pos;
	float dist = length(to_core);
	to_core /= max(dist, 0.001);
	float falloff = core_strength / (1.0 + dist * dist / (core_reach * core_reach) * 5.0);
	float facing = dot(n_world, to_core);
	float lit = clamp(facing * 0.7 + 0.3, 0.0, 1.0);
	// (light through the feather, from behind: warmer, and strongest at its thin edges and tip)
	float through = clamp(-facing, 0.0, 1.0) * (0.35 + 0.65 * smoothstep(0.5, 1.0, abs(across)) + 0.3 * smoothstep(0.6, 1.0, along));
	EMISSION = color * core_color * falloff * (lit * 0.7 + through * 0.6);
}

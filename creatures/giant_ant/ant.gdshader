// A giant ant of a colony (AntLook, AntColony): dark, glossy chitin lit in
// hard bands, drawn some thirty at a time as one MultiMesh, workers, soldiers
// and what the workers carry in one mesh. Each point says, in its texture
// coordinates (not colours: the web's renderer gives a MultiMesh without
// colours of its own no settled colour to its points):
//   UV.x   how far along its part it is (a leg: 0 at the hip, 1 at the foot;
//          a feeler: socket to tip; a jaw: hinge to point; the gaster: waist to tip)
//   UV.y   which part: 0 head and thorax, 1-3 left legs (fore to hind), 4-6
//          right legs, 7 and 8 the feelers, 9 and 10 the jaws, 11 the gaster,
//          12 the eyes, 13 a load
//   UV2.y  which it belongs to: 0 the worker, 1 the soldier, 2 the load
// and each ant, in its custom data:
//   x  how far through a stride (its fraction), and in its whole part how
//      hard it is striding, in eighths (0: its legs are still)
//   y  which kind it is (0 worker, 1 soldier), and a half more if it carries a load
//   z  how alarmed it is (0..1): feelers up and quick, jaws apart, gaster raised
//   w  how hard it is biting (0..1): the jaws snap open and shut
shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform vec3 chitin : source_color = vec3(0.05, 0.042, 0.036);
uniform vec3 gaster_tone : source_color = vec3(0.042, 0.036, 0.032);
uniform vec3 limb : source_color = vec3(0.1, 0.08, 0.066);
uniform vec3 eye : source_color = vec3(0.012, 0.012, 0.014);
uniform vec3 meat : source_color = vec3(0.36, 0.25, 0.23);
// The overcast sky mirrored in the chitin, and its one hard highlight.
uniform vec3 sky : source_color = vec3(0.62, 0.65, 0.68);
uniform float sky_shine = 0.13;
uniform float gloss = 12.0;
// How far a foot swings fore and aft and how high it lifts at a full stride, metres.
uniform float reach = 0.13;
uniform float lift = 0.07;

varying float shiny;
varying flat int part;
varying float along;

void vertex() {
	part = int(UV.y + 0.5);
	along = UV.x;
	float kind = floor(INSTANCE_CUSTOM.y + 0.01);
	bool loaded = fract(INSTANCE_CUSTOM.y) > 0.25;
	bool shown = abs(UV2.y - kind) < 0.5 || (UV2.y > 1.5 && loaded && kind < 0.5);
	if (!shown) {
		VERTEX = vec3(0.0);
	} else {
		float phase = fract(INSTANCE_CUSTOM.x);
		float stride = floor(INSTANCE_CUSTOM.x) / 8.0;
		float alarm = INSTANCE_CUSTOM.z;
		float bite = INSTANCE_CUSTOM.w;
		vec3 home = MODEL_MATRIX[3].xyz;
		float seed = fract(sin(dot(home.xz, vec2(12.9898, 78.233))) * 43758.5453);
		float w = UV.x;
		// The head, and what is on it, comes up when it is alarmed and dips as it bites.
		float on_head = smoothstep(0.3, 0.42, VERTEX.z) * (part == 0 || part >= 7 && part <= 10 || part == 12 || part == 13 ? 1.0 : 0.0);
		float nod = alarm * 0.045 - bite * 0.03 * (0.5 + 0.5 * sin(TIME * 23.0 + seed * 6.0));
		if (part >= 1 && part <= 6) {
			// Tripod gait: fore and hind on one side step with the middle leg of the other.
			int k = (part - 1) % 3;
			bool left = part <= 3;
			float group = ((k == 1) != left) ? 0.0 : 0.5;
			float turn = (phase + group) * TAU;
			// (the fore legs reach further forward, the hind push further back)
			float swing = sin(turn) * reach * stride * w;
			VERTEX.z += swing;
			VERTEX.y += max(cos(turn), 0.0) * lift * stride * w;
			// (alarmed, it stands up taller on its legs, the body lifted off them)
			VERTEX.y -= alarm * 0.04 * w;
		} else if (part == 7 || part == 8) {
			float s = part == 7 ? 1.0 : -1.0;
			float quick = mix(2.4, 11.0, alarm);
			float wave = sin(TIME * quick + seed * 9.0 + s * 1.7);
			float other = cos(TIME * quick * 0.73 + seed * 4.0 + s);
			float tip = w * w;
			// (foraging, it taps the ground ahead; alarmed, they go up and forward and flicker)
			VERTEX.y += tip * (0.05 * wave + alarm * 0.07 - (1.0 - alarm) * 0.04);
			VERTEX.x += s * tip * 0.05 * other;
			VERTEX.z += tip * alarm * 0.06;
		} else if (part == 9 || part == 10) {
			float s = part == 9 ? 1.0 : -1.0;
			float snap = bite * (0.5 + 0.5 * sin(TIME * 23.0 + seed * 6.0));
			float gape = max(alarm * 0.45, snap);
			VERTEX.x += s * gape * 0.07 * w;
			VERTEX.z -= gape * 0.015 * w;
		} else if (part == 11) {
			// (alarmed, the gaster is raised; walking, it rocks a little)
			VERTEX.y += alarm * 0.1 * w * w + stride * 0.012 * sin(phase * TAU * 2.0) * w;
			VERTEX.z += alarm * 0.03 * w * w;
		}
		VERTEX.y += on_head * nod;
	}
	shiny = (part == 0 || part == 11) ? 1.0 : (part == 12 ? 1.4 : (part == 9 || part == 10 ? 0.6 : 0.12));
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void fragment() {
	vec3 colour = chitin;
	if (part == 11) {
		// (the gaster's plates: each paler at its back rim, where a fringe of hairs lies)
		float band = smoothstep(0.82, 0.97, fract(along * 4.3));
		colour = mix(gaster_tone, gaster_tone * 2.4, band * 0.6);
	} else if (part >= 1 && part <= 8) {
		colour = mix(limb, limb * 0.6, along);
	} else if (part == 9 || part == 10) {
		colour = mix(limb * 1.2, eye, along);
	} else if (part == 12) {
		colour = eye;
	} else if (part == 13) {
		colour = meat;
	}
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// The overcast sky mirrored along the top of the chitin in a hard-edged band.
	vec3 mirrored = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz;
	float band = cut(mirrored.y, 0.55);
	float rim = cut(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 0.7);
	EMISSION = shiny * sky * (band * sky_shine + rim * 0.05);
}

void light() {
	float near = clamp(ATTENUATION, 0.0, 1.0);
	float amount = dot(NORMAL, LIGHT) * smoothstep(0.1, 0.5, near);
	float lit = cut(amount, 0.02);
	float strength = mix(near, 1.0, 0.5);
	DIFFUSE_LIGHT += (0.35 + 0.65 * lit) * strength * LIGHT_COLOR / PI;
	float shine = cut(pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), gloss), 0.5);
	SPECULAR_LIGHT += shine * lit * shiny * 0.09 * strength * LIGHT_COLOR;
}

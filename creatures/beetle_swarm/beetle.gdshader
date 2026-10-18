// A beetle of a swarm (BeetleLook, BeetleSwarm): glossy black with an oily
// sheen, drawn a few hundred at a time as one MultiMesh, both kinds in one
// mesh. Each point says, in its texture coordinates (not colours: the web's
// renderer gives a MultiMesh without colours of its own no settled colour to
// its points):
//   UV.x   how far down a leg it is (0 at the hip and on the body, 1 at the foot)
//   UV.y   which three legs it steps with (0 or 0.5)
//   UV2.x  how much it shines (shell and margin most, legs not at all)
//   UV2.y  which kind of beetle it belongs to (0 the ground beetle, 1 the dor beetle)
// and each beetle, in its custom data:
//   x  how far through a stride it is, in whole strides (standing still, its legs stop)
//   y  which kind it is (the other kind's points are all put at its middle, and not seen)
//   z  where its sheen starts on the round of an oil film's colours
shader_type spatial;
render_mode cull_disabled, shadows_disabled;

uniform vec3 shell : source_color = vec3(0.022, 0.022, 0.028);
// The oil film: how strong, and how far round its colours it goes from square on to aslant.
uniform float sheen = 1.0;
uniform float film_spread = 1.25;
// The sky seen in the shell (an overcast sky: a broad pale band along the top of it).
uniform vec3 sky : source_color = vec3(0.62, 0.65, 0.68);
uniform float sky_shine = 0.4;
uniform float gloss = 60.0;
// How far a foot swings fore and aft and how high it lifts, in lengths of the beetle.
uniform float reach = 0.11;
uniform float lift = 0.05;

varying float shiny;
varying float hue;

void vertex() {
	if (abs(UV2.y - INSTANCE_CUSTOM.y) > 0.5) {
		VERTEX = vec3(0.0);
	} else {
		float turn = (INSTANCE_CUSTOM.x + UV.y) * TAU;
		VERTEX.z += sin(turn) * reach * UV.x;
		VERTEX.y += max(cos(turn), 0.0) * lift * UV.x;
	}
	shiny = UV2.x;
	hue = INSTANCE_CUSTOM.z;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

// The colours of a film of oil on water, round and round: violet, blue, green, bronze, magenta.
vec3 film(float t) {
	vec3 rainbow = 0.5 + 0.5 * cos(TAU * (vec3(t) + vec3(0.0, 0.33, 0.67)));
	return mix(rainbow, vec3(0.42, 0.3, 0.62), 0.3);
}

void fragment() {
	ALBEDO = shell;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// What the shell mirrors: the overcast sky above, in a hard-edged band (as
	// the figures are lit), tinted at its edge by the film; and the film itself
	// round the rim, where the shell is seen aslant. Both are there in shade too.
	vec3 mirrored = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 oil = film(graze * film_spread + hue);
	float band = cut(mirrored.y, 0.55);
	float edge = cut(mirrored.y, 0.3) - band;
	float rim = cut(graze, 0.62);
	EMISSION = shiny * (sky * band * sky_shine * mix(vec3(1.0), oil, 0.25) + oil * edge * sky_shine * sheen * 0.8 + oil * rim * sheen * 0.16);
}

void light() {
	float near = clamp(ATTENUATION, 0.0, 1.0);
	float amount = dot(NORMAL, LIGHT) * smoothstep(0.1, 0.5, near);
	float lit = cut(amount, 0.02);
	float strength = mix(near, 1.0, 0.5);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	// One hard-edged light on the shell, in the film's colours.
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 oil = mix(vec3(1.0), film(graze * film_spread + hue + 0.15), 0.5);
	float shine = cut(pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), gloss), 0.5);
	SPECULAR_LIGHT += shine * lit * shiny * 1.4 * oil * strength * LIGHT_COLOR;
}

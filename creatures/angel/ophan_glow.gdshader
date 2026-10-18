// Everything of the ophan that is light rather than stuff, all added onto what
// is behind it: which one is `kind`.
//   (0 is the core, which is solid: ophan_core.gdshader)
//   1 the flame round it: tongues of pale fire licking up off a shell;
//   2 the halo: a soft glow facing the camera, with a faint bow of colours in
//     it ("as the bow that is in the cloud in the day of rain");
//   3 the gaze: a cone of pale light from the core to what it looks at,
//     bands running down it (UV.y 0 at the core);
//   4 the pool: a ring of light on the ground round what it looks at;
//   5 a mote: a soft point (particles; their colour's alpha is how bright).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform int kind = 1;
uniform vec3 color : source_color = vec3(1.0, 0.86, 0.6);
uniform float strength = 1.0;
// How far off it fades into the mist (metres): it is not fogged, as a light seen through mist is not.
uniform float mist = 90.0;

varying vec3 local;
varying float seen_from;

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

float fbm(vec3 p) {
	return noise(p) * 0.55 + noise(p * 2.1) * 0.3 + noise(p * 4.3) * 0.15;
}

vec3 spectrum(float t) {
	return clamp(vec3(abs(t * 6.0 - 3.0) - 1.0, 2.0 - abs(t * 6.0 - 2.0), 2.0 - abs(t * 6.0 - 4.0)), 0.0, 1.0);
}

void vertex() {
	local = VERTEX;
	if (kind == 2) {
		// (turned to face the camera, keeping its size, and brought a little towards it so walls cut it less)
		vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float size = length(MODEL_MATRIX[0].xyz);
		vec3 toward = normalize(CAMERA_POSITION_WORLD - centre);
		vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), toward));
		vec3 up = cross(toward, right);
		vec3 world = centre + toward * size * 0.35 + (right * VERTEX.x + up * VERTEX.y) * size;
		POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	}
	if (kind == 5) {
		// (a particle: a quad facing the camera)
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
	}
	vec3 at = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	seen_from = length(CAMERA_POSITION_WORLD - at);
	if (kind != 2) {
		// (writing POSITION for the halo means writing it for everything)
		POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	}
}

void fragment() {
	float face = abs(dot(NORMAL, VIEW));
	vec3 light = vec3(0.0);
	float t = TIME;
	if (kind == 1) {
		vec3 d = normalize(local);
		float flicker = fbm(vec3(d.x * 3.0, d.y * 2.0 - t * 1.6, d.z * 3.0) * 2.0);
		float tongues = smoothstep(0.45, 0.85, flicker + (d.y * 0.25));
		float rim = pow(1.0 - face, 1.4);
		light = color * tongues * (0.25 + rim * 0.9);
	} else if (kind == 2) {
		float r = length(UV - vec2(0.5)) * 2.0;
		float glow = exp(-r * r * 9.0) * 0.5 + exp(-r * 3.6) * 0.16;
		float bow = exp(-pow((r - 0.8) / 0.07, 2.0));
		vec3 bands = spectrum(clamp((r - 0.72) / 0.16, 0.0, 1.0)) * bow * 0.035;
		float a = atan(UV.y - 0.5, UV.x - 0.5);
		float rays = pow(0.5 + 0.5 * sin(a * 9.0 + t * 0.15) * sin(a * 5.0 - t * 0.1), 3.0) * exp(-r * 2.4) * 0.25;
		light = color * (glow + rays) + bands;
		light *= 1.0 - smoothstep(0.85, 1.0, r);
	} else if (kind == 3) {
		float v = UV.y;
		float ends = smoothstep(0.05, 0.45, v) * (1.0 - smoothstep(0.86, 1.0, v));
		float band = 0.6 + 0.4 * sin(v * 40.0 - t * 6.0 + UV.x * 12.566);
		light = color * ends * band * pow(face, 1.6) * 1.3;
	} else if (kind == 4) {
		float r = length(UV - vec2(0.5)) * 2.0;
		float ring = exp(-pow((r - 0.62 - 0.04 * sin(t * 3.0)) / 0.08, 2.0));
		float pool = (1.0 - smoothstep(0.0, 0.75, r)) * 0.5;
		light = color * (ring + pool) * (1.0 - smoothstep(0.85, 1.0, r));
	} else {
		float r = length(UV - vec2(0.5)) * 2.0;
		light = COLOR.rgb * exp(-r * r * 5.0) * COLOR.a;
	}
	ALBEDO = light * strength * exp(-seen_from / mist);
}

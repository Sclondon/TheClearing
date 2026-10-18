// The ophan's heart: a solid ball of white-gold fire. Unlit and opaque, so it
// is the brightest thing about (bright enough to bloom), boiling slowly: white
// in the middle, through gold, to a deep amber at its rim, with darker cells
// welling and sinking over it, "as the colour of amber, as the appearance of
// fire round about within it".
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.84, 0.56);
uniform float strength = 1.0;

varying vec3 local;

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
	local = VERTEX;
}

void fragment() {
	float t = TIME;
	float face = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 p = normalize(local) * 3.0;
	float cells = noise(p * 1.6 + vec3(0.0, -t * 0.35, t * 0.12)) * 0.6 + noise(p * 4.0 + vec3(t * 0.2, -t * 0.6, 0.0)) * 0.4;
	vec3 amber = color * vec3(1.0, 0.62, 0.3);
	vec3 hot = mix(amber, color, smoothstep(0.0, 0.45, face));
	hot = mix(hot, vec3(1.0, 0.98, 0.93), smoothstep(0.45, 0.95, face));
	hot *= 0.82 + 0.35 * cells;
	ALBEDO = hot * strength;
}

class_name GnomeLook
## How a Gnome (creatures/gnome/gnome.gd) is shaded: one material for every
## gnome, put over its model (creatures/gnome/models/, built in Blender by
## tools/build_gnome.py).
##
## The model carries its colours as vertex colours: leathery grey-brown skin,
## a matted grey beard, a faded hat, a worn coat, dark boots. Its first UV says
## what part a point is on (x: 0 skin, 0.25 coat, 0.5 hat, 0.75 beard and brows,
## 1 the eyes) and how wet it is (y: the eyes shine, the nose's tip a little);
## its second UV is where the point was on the standing body, so the wrinkles,
## the weave of the coat and the strands of the beard stay put on it as it moves.
##
## Shading is cel shading in two tones with a hard edge and a thin cold rim at
## grazing angles, as the rest of the cast. Each gnome's hat and coat are its
## own faded colour (`hat_tint`, `coat_tint`, from `hat_colour` and
## `coat_colour`), and its skin a little lighter or darker (`tone`).

const SHADER := """
shader_type spatial;
render_mode cull_back;

uniform float wrap = 0.5;
uniform float flatness = 0.6;
uniform float rim_gain = 0.45;
uniform float rim_width = 0.24;
uniform vec3 rim_colour : source_color = vec3(0.75, 0.8, 0.85);
uniform float gloss = 70.0;
instance uniform float tone = 1.0;
instance uniform vec3 hat_tint = vec3(0.15, 0.09, 0.075);
instance uniform vec3 coat_tint = vec3(0.11, 0.105, 0.085);

varying float part;
varying float wet;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	part = UV.x;
	wet = UV.y;
}

void fragment() {
	vec3 colour = COLOR.rgb;
	float skin = 1.0 - smoothstep(0.08, 0.15, part);
	float coat = smoothstep(0.15, 0.2, part) * (1.0 - smoothstep(0.3, 0.35, part));
	float hat = smoothstep(0.4, 0.45, part) * (1.0 - smoothstep(0.55, 0.6, part));
	float beard = smoothstep(0.65, 0.7, part) * (1.0 - smoothstep(0.85, 0.9, part));
	// The hat and the coat in its own faded colours (the model's own shading kept).
	colour = mix(colour, colour / vec3(0.15, 0.09, 0.075) * hat_tint, hat);
	colour = mix(colour, colour / vec3(0.11, 0.105, 0.085) * coat_tint, coat);
	// Skin: deep wrinkles and blotches, the old leather of it.
	float blotch = noise(UV2 * 30.0) * 0.6 + noise(UV2 * 90.0) * 0.4;
	float wrinkle = smoothstep(0.42, 0.5, abs(noise(UV2 * vec2(80.0, 105.0) + noise(UV2 * 25.0) * 3.0) - 0.5) * 2.0);
	float fine = smoothstep(0.45, 0.5, abs(noise(UV2 * vec2(190.0, 260.0)) - 0.5) * 2.0);
	float shade = 1.0 + (blotch - 0.5) * 0.16 * skin - (wrinkle * 0.13 + fine * 0.05) * skin;
	// The coat's coarse weave, worn and stained.
	float weave = noise(UV2 * vec2(260.0, 260.0)) * 0.5 + noise(UV2 * 18.0) * 0.5;
	shade *= 1.0 + (weave - 0.5) * 0.25 * coat + (noise(UV2 * 7.0) - 0.5) * 0.3 * hat;
	// The beard in strands, matted.
	float strand = noise(vec2(UV2.x * 110.0, UV2.y * 9.0));
	shade *= 1.0 + (strand - 0.5) * 0.12 * beard;
	ALBEDO = colour * shade * mix(1.0, tone, skin);
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
	float lit = cut(facing, 0.05) * mix(0.5, 1.0, smoothstep(0.15, 0.6, reach));
	lit *= mix(0.7, 1.0, smoothstep(0.1, 0.85, facing));
	float strength = LIGHT_IS_DIRECTIONAL ? mix(reach, 1.0, flatness) : reach;
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = cut(graze, 1.0 - rim_width) * mix(0.35, 1.0, lit);
	SPECULAR_LIGHT += rim * rim_gain * mix(ALBEDO, ALBEDO * rim_colour * 2.0, 0.5) * strength * LIGHT_COLOR / PI;
	// A hard little glint in its eyes.
	float shine = cut(pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), gloss), 0.4);
	SPECULAR_LIGHT += shine * smoothstep(0.4, 0.8, wet) * strength * LIGHT_COLOR * 0.9;
}
"""

## Faded hats: old madder gone to brick and rust, lichen grey-green, peat brown, ash.
const HATS := [Color(0.4, 0.33, 0.3), Color(0.38, 0.34, 0.31), Color(0.35, 0.36, 0.33), Color(0.31, 0.3, 0.29),
	Color(0.42, 0.34, 0.31), Color(0.36, 0.35, 0.34)]
## Worn coats: moss, earth, slate, sacking.
const COATS := [Color(0.35, 0.36, 0.31), Color(0.38, 0.34, 0.3), Color(0.32, 0.33, 0.34), Color(0.42, 0.39, 0.33),
	Color(0.3, 0.3, 0.28)]

static var _material: ShaderMaterial


static func material() -> ShaderMaterial:
	if _material == null:
		var shader := Shader.new()
		shader.code = SHADER
		_material = ShaderMaterial.new()
		_material.shader = shader
	return _material


static func hat_colour(pick: int) -> Color:
	return (HATS[absi(pick) % HATS.size()] as Color).srgb_to_linear()


static func coat_colour(pick: int) -> Color:
	return (COATS[absi(pick) % COATS.size()] as Color).srgb_to_linear()

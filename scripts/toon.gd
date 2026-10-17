class_name Toon
## Cel shading, after the usual recipe for the Breath of the Wild look:
##
## - Each light splits a surface into two flat tones, with an optional brighter
##   core. Shadow and distance are folded into the same cut as the angle to the
##   light, so a cast shadow has the same hard edge as the terminator.
## - Edges are softened by exactly one pixel (from screen-space derivatives), so
##   they stay crisp at any distance without crawling.
## - A rim of light at grazing angles, and an optional stepped highlight, both
##   only on the side the light reaches.
##
## Figures get the full treatment; the world gets a gentler version (see
## `surface`), so the two sit together.

const SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(1.0);
// How far past side-on the lit tone wraps, 0..1.
uniform float wrap = 0.0;
// Where the brighter core starts (as a share of full light), and what it adds.
// It is kept slight: any more and cloth looks polished.
uniform float core_cut = 0.72;
uniform float core_gain = 0.0;
// 1: light inside its reach is flat, like a spotlight on a cut-out.
// 0: it still fades with distance.
uniform float flatness = 0.65;
uniform float rim_gain = 0.0;
uniform float rim_width = 0.14;
uniform float highlight = 0.0;
uniform float gloss = 24.0;
// A fine stripe woven into the cloth: how much darker it is (0: none), and how
// far apart the stripes are and how wide, in metres. They run along lines of
// the first texture coordinate, which the model gives as a distance round him.
uniform float stripe = 0.0;
uniform float stripe_gap = 0.017;
uniform float stripe_width = 0.0022;

void fragment() {
	float off = abs(fract(UV.x / stripe_gap) - 0.5) * stripe_gap;
	float pixel = max(fwidth(UV.x), 0.00001);
	// (too far off to be told apart, they fade into the cloth rather than shimmer)
	float line = (1.0 - smoothstep(stripe_width * 0.5 - pixel, stripe_width * 0.5 + pixel, off)) * clamp(stripe_gap * 0.25 / pixel, 0.0, 1.0);
	ALBEDO = albedo * (1.0 - stripe * line);
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
	// One number for "how lit", so shadows and falloff cut as cleanly as the terminator.
	float amount = facing * smoothstep(0.15, 0.6, reach);
	float lit = cut(amount, 0.04);
	float core = cut(amount, core_cut);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += (lit * (1.0 - core_gain) + core * core_gain) * strength * LIGHT_COLOR / PI;

	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = cut(graze, 1.0 - rim_width) * lit;
	float shine = cut(pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), gloss), 0.5) * lit;
	// The rim is a brighter shade of the surface itself, so dark hair gets a dark rim.
	SPECULAR_LIGHT += (rim * rim_gain * albedo + shine * highlight) * strength * LIGHT_COLOR / PI;
}
"""

## Hair is shaded the same way, and then as hair: each lock is made of strands
## that differ a little in tone, it is darker at the root than at the tip, and
## the light catches it in a broken band lying across the way it grows, rather
## than in a round spot. It needs to know which way each lock lies: the models
## give that as texture coordinates running (along the lock, round it), from
## which the importer works out tangents.
const HAIR_SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(1.0);
uniform float wrap = 0.15;
uniform float core_cut = 0.6;
uniform float core_gain = 0.0;
uniform float flatness = 0.65;
uniform float rim_gain = 0.0;
uniform float rim_width = 0.2;
// How many strands show round a lock, and how far their tones differ.
uniform float strands = 7.0;
uniform float streak = 0.16;
// How much darker the roots are, and how much lighter the tips.
uniform float root_shade = 0.18;
uniform float tip_bleach = 0.05;
// The band of light across the hair: its colour, strength, tightness, and how
// ragged the strands make its edge. It is kept faint: his hair is dry and dusty.
uniform vec3 sheen : source_color = vec3(0.8, 0.72, 0.62);
uniform float sheen_gain = 0.05;
uniform float sheen_gloss = 40.0;
uniform float sheen_ragged = 0.5;

varying vec3 lie;
varying float strand;

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	strand = hash(floor(UV.y * strands));
	float tone = 1.0 + (strand - 0.6) * streak;
	tone *= mix(1.0 - root_shade, 1.0 + tip_bleach, smoothstep(0.0, 0.9, UV.x));
	ALBEDO = albedo * tone;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	lie = TANGENT;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float amount = facing * smoothstep(0.15, 0.6, reach);
	float lit = cut(amount, 0.04);
	float core = cut(amount, core_cut);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += (lit * (1.0 - core_gain) + core * core_gain) * strength * LIGHT_COLOR / PI;

	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = cut(graze, 1.0 - rim_width) * lit;
	// Each strand is tipped a little differently, which is what breaks the band up.
	vec3 along = normalize(normalize(lie) + NORMAL * (strand - 0.5) * sheen_ragged);
	float across = dot(along, normalize(LIGHT + VIEW));
	float band = cut(pow(sqrt(max(1.0 - across * across, 0.0)), sheen_gloss), 0.5) * lit;
	SPECULAR_LIGHT += (rim * rim_gain * ALBEDO + band * sheen_gain * mix(ALBEDO, sheen, 0.5)) * strength * LIGHT_COLOR / PI;
}
"""

## Hair that is waved rather than curled: finger waves, a marcel wave, long
## hair brushed out. Where the curls above are ringlets in the model, each a
## little tube with its own small broken light, this is one smooth surface and
## the wave is all in the shading. The strands swing from side to side in long
## soft S-curves on their way from root to tip; the hair rises and falls with
## them, so that light and shadow cut across it in ridges; and each ridge
## carries a broad band of light, lying along the strands and following their
## swing. A material named `hairwavy` is given this, in the colour of `hair`.
const WAVY_HAIR_SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(1.0);
uniform float wrap = 0.15;
uniform float core_cut = 0.6;
uniform float core_gain = 0.0;
uniform float flatness = 0.65;
uniform float rim_gain = 0.0;
uniform float rim_width = 0.2;
// How many strands show round the head, and how far their tones differ.
uniform float strands = 5.0;
uniform float streak = 0.13;
uniform float root_shade = 0.14;
uniform float tip_bleach = 0.06;
// The wave: how many there are from root to tip, how far the strands swing to
// either side (as a share of the way round a lock), and how steep the ridges
// are (how far they tip the surface towards and away from the light).
uniform float waves = 2.6;
uniform float sway = 0.07;
uniform float ridge = 0.4;
// How much lighter the crest of each wave is than the hollow behind it.
uniform float crest_light = 0.08;
// The band of light on each crest: its colour, strength and breadth. It is
// broad and soft where a curl has a small ragged one.
uniform vec3 sheen : source_color = vec3(0.86, 0.78, 0.66);
uniform float sheen_gain = 0.16;
uniform float sheen_gloss = 9.0;

varying vec3 lie;
varying float strand;
varying float lifted;

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void fragment() {
	// The waves run right round the head nearly in step, as hair set in waves does.
	float turn = (UV.x * waves + 0.07 * sin(UV.y * 2.1)) * TAU;
	float swing = sin(turn);
	strand = hash(floor((UV.y + swing * sway) * strands));
	lifted = cos(turn);
	float tone = 1.0 + (strand - 0.6) * streak;
	tone *= mix(1.0 - root_shade, 1.0 + tip_bleach, smoothstep(0.0, 0.9, UV.x));
	// (the crest is a clean band of lighter hair, as the shadows are clean)
	tone *= 1.0 + crest_light * (cut(lifted, 0.25) - 0.5);
	ALBEDO = albedo * tone;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// The strands turn with the swing, and the surface tips with the ridge.
	lie = normalize(TANGENT + BINORMAL * swing * sway * 9.0);
	NORMAL = normalize(NORMAL + TANGENT * sin(turn) * ridge);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float amount = facing * smoothstep(0.15, 0.6, reach);
	float lit = cut(amount, 0.04);
	float core = cut(amount, core_cut);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += (lit * (1.0 - core_gain) + core * core_gain) * strength * LIGHT_COLOR / PI;

	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = cut(graze, 1.0 - rim_width) * lit;
	vec3 along = normalize(normalize(lie) + NORMAL * (strand - 0.5) * 0.12);
	float across = dot(along, normalize(LIGHT + VIEW));
	// (only the crests catch it: one broad band to each wave)
	float band = cut(pow(sqrt(max(1.0 - across * across, 0.0)), sheen_gloss) * smoothstep(-0.2, 0.6, lifted), 0.5) * lit;
	SPECULAR_LIGHT += (rim * rim_gain * ALBEDO + band * sheen_gain * mix(ALBEDO, sheen, 0.5)) * strength * LIGHT_COLOR / PI;
}
"""

## Gold: lit as `surface` is, and then it shines. A flat face of it catches the
## sun all at once, so the highlight is cut into steps rather than a spot, and
## it keeps a glow of its own in shadow.
const GOLD_SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(0.96, 0.7, 0.2);
uniform float banded = 0.0;
uniform float wrap = 0.15;
// How broad the shine is (less is broader), how bright, and how much it glows unlit.
uniform float gloss = 5.0;
uniform float shine = 0.8;
uniform float glow = 0.22;

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	// A bright edge where it is seen side-on, as polished metal has.
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = albedo * (glow + 0.3 * mix(smoothstep(0.55, 0.95, graze), cut(graze, 0.78), banded));
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float towards = dot(NORMAL, LIGHT);
	float hard = cut((towards + wrap) / (1.0 + wrap) * smoothstep(0.15, 0.6, reach), 0.04) * reach;
	float soft = clamp(towards, 0.0, 1.0) * reach;
	float lit = mix(soft, hard, banded);
	DIFFUSE_LIGHT += lit * LIGHT_COLOR / PI;
	float caught = pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), gloss);
	float stepped = cut(caught, 0.3) * 0.45 + cut(caught, 0.62) * 0.55;
	SPECULAR_LIGHT += mix(caught, stepped, banded) * shine * step(0.0, towards) * reach * LIGHT_COLOR / PI * vec3(1.0, 0.86, 0.5);
}
"""

static var _shader: Shader
static var _hair_shader: Shader
static var _wavy_shader: Shader
static var _gold_shader: Shader


## Reshades every mesh under `model` as a figure. Its own materials are left
## untouched. `colours` gives other colours for any of them, by material name.
## A material named `hair` is shaded as hair, and one named `hairwavy` as waved
## hair of the same colour; one named `shirt` is pinstriped; and the three an
## eye is made of (`eyewhite`, `iris`, `pupil`) have a glint of light on them.
static func apply(model: Node, colours := {}) -> void:
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var named := original.resource_name
			var colour: Color = colours.get("hair" if named == "hairwavy" else named, original.albedo_color)
			var material := _hair(colour, named == "hairwavy") if named == "hair" or named == "hairwavy" else _material(colour)
			if named == "shirt":
				material.set_shader_parameter(&"stripe", 0.13)
			elif named == "eyewhite" or named == "iris" or named == "pupil":
				# (an eye is wet: it is never quite in shadow, and it has one small bright light on it)
				material.set_shader_parameter(&"wrap", 0.6)
				material.set_shader_parameter(&"highlight", 0.5)
				material.set_shader_parameter(&"gloss", 90.0)
			part.set_surface_override_material(surface, material)


## The colours a model was made in, by material name.
static func colours_of(model: Node) -> Dictionary:
	var found := {}
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original:
				found[original.resource_name] = original.albedo_color
	return found


## A material for the world: the same hard edge between light and shadow, but
## it keeps its fall-off with distance and has no rim, so walls and floors read
## as lit space rather than as cut-outs. Falls back to smooth shading when the
## menu's world shading is off.
static func surface(color: Color) -> Material:
	if not Settings.world_banded:
		var smooth := StandardMaterial3D.new()
		smooth.albedo_color = color
		smooth.roughness = 1.0
		smooth.metallic_specular = 0.0
		return smooth
	var banded := _material(color)
	banded.set_shader_parameter(&"flatness", 0.0)
	banded.set_shader_parameter(&"core_gain", 0.0)
	banded.set_shader_parameter(&"rim_gain", 0.0)
	banded.set_shader_parameter(&"wrap", 0.15)
	return banded


## A material for gold: lit as `surface` is, and shining. (GameCommon: in
## Outside this is `Sandstone.gold`, which Toon.gold calls; the shader is moved
## here so that nothing of Outside's stone is needed.)
static func gold(color := Color(0.96, 0.7, 0.2)) -> ShaderMaterial:
	if _gold_shader == null:
		_gold_shader = Shader.new()
		_gold_shader.code = GOLD_SHADER
	var material := ShaderMaterial.new()
	material.shader = _gold_shader
	material.set_shader_parameter(&"albedo", color)
	material.set_shader_parameter(&"banded", 1.0 if Settings.world_banded else 0.0)
	return material


static func _material(color: Color) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter(&"albedo", color)
	return material


static func _hair(color: Color, wavy := false) -> ShaderMaterial:
	if _hair_shader == null:
		_hair_shader = Shader.new()
		_hair_shader.code = HAIR_SHADER
		_wavy_shader = Shader.new()
		_wavy_shader.code = WAVY_HAIR_SHADER
	var material := ShaderMaterial.new()
	material.shader = _wavy_shader if wavy else _hair_shader
	material.set_shader_parameter(&"albedo", color)
	return material

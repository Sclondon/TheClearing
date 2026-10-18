class_name DeinonychusLook
## What a deinonychus (Deinonychus, creatures/deinonychus/deinonychus.gd) is
## drawn with: three materials, one for each of the model's three surfaces,
## so that it is a handful of draws.
##
## - COAT: its contour feathers, lit in hard bands (cel shading): rows of small
##   rounded feathers laid like tiles along the lie of them (the texture
##   coordinates are metres along it and across it, see
##   tools/build_deinonychus.py), each a little different in tone, a thin
##   shadow under the edge of each row; and drawn again a couple of times stood
##   off the skin ("shells") at its outline only, so that the outline is a soft
##   ragged fringe of feather tips, not a smooth curve. Its vertex colours say
##   where it is creased (red), where its markings are dark (green: the mask
##   through its eye, the saddle, the bars across its tail) or pale (blue: the
##   throat and belly), and how long its feathers are (alpha): where that is
##   nothing (the snout, round the eyes, the lower shins) it is bare, grey,
##   finely scaled skin.
## - FEATHERS: the vanes of its wings, the fan of its tail and the loose tufts
##   of its coat, seen from either side: the colour of each from the vertex
##   colours, a pale shaft down its middle, the fine lines of its barbs, dark
##   bars across it (as strongly as its vertex colour's alpha says), the edges
##   darker and the tip a little paler.
## - PARTS: eyes, claws, the scales of its feet and hands, the mouth and teeth,
##   each in its own colour from the vertex colours, wet ones with a hard glint;
##   an eye (alpha 1) has a round black pupil in a pale gold iris.
##
## Nothing uses a texture, transparency or the screen, so it costs the same in
## a web build as on a desktop.

const COAT_SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(0.25, 0.235, 0.22);
uniform vec3 pale : source_color = vec3(0.56, 0.54, 0.50);
uniform vec3 dark : source_color = vec3(0.09, 0.085, 0.08);
uniform vec3 skin : source_color = vec3(0.24, 0.23, 0.22);
uniform float wrap = 0.3;
uniform float flatness = 0.6;
// Rows of feathers: how many to a metre along the lie of them and across it.
uniform vec2 rows = vec2(60.0, 48.0);
uniform float feather_tone = 0.16;
uniform float edge_shade = 0.16;
uniform float barbs = 0.22;
uniform float crease = 0.6;
uniform float pale_gain = 0.85;
uniform float dark_gain = 0.85;
uniform float rim_gain = 0.35;
uniform float rim_width = 0.3;
// Which layer this is: 0 the skin, up to 1 for the tips of the longest feathers.
uniform float shell = 0.0;
uniform float plume_length = 0.03;
uniform float comb = 1.1;
uniform float droop = 0.35;

varying float plumage;
varying float grain;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x), mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	plumage = clamp(COLOR.a, 0.0, 1.0);
	if (shell > 0.0) {
		vec3 down = (vec4(0.0, -1.0, 0.0, 0.0) * MODEL_MATRIX).xyz;
		// (the feathers lie back along the texture's first coordinate: to the tail, down the legs)
		VERTEX += (NORMAL + (TANGENT * comb + down * droop) * shell) * plume_length * shell * smoothstep(0.25, 0.7, plumage) * mix(0.5, 1.0, COLOR.r);
	}
}

void fragment() {
	// The rows of feathers, each row offset half a feather from the last.
	vec2 at = vec2(UV.x * rows.x, UV.y * rows.y);
	float row = floor(at.x);
	at.y += 0.5 * mod(row, 2.0);
	vec2 cell = floor(at);
	vec2 f = fract(at);
	// (the rounded edge of the feather of the row before, lying over this one's root)
	float edge = 0.42 * (1.0 - pow(abs(f.y * 2.0 - 1.0), 2.0));
	bool over = f.x < edge;
	vec2 own = over ? cell - vec2(1.0, 0.0) : cell;
	float past = f.x - edge;
	float detail = clamp(0.5 / max(fwidth(at.x), 0.0001) - 0.5, 0.0, 1.0);
	float tone = 1.0 + (hash(own) - 0.5) * feather_tone;
	float shade = over ? 1.0 : 1.0 - edge_shade * (1.0 - smoothstep(0.0, 0.45, past));
	// (the barbs: fine streaks along the lie of the feathers, clumping)
	grain = noise(vec2(UV.y * 320.0, UV.x * 18.0)) * 0.7 + noise(vec2(UV.y * 90.0, UV.x * 9.0)) * 0.3;
	float streaks = 1.0 + (grain - 0.5) * barbs * 2.0;
	tone *= mix(1.0, shade, detail) * streaks;
	float feathered = smoothstep(0.15, 0.45, plumage);
	if (shell > 0.0) {
		// Only at the outline, and only the tips of the feathers: a ragged fringe.
		float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
		if (facing > 0.8 - shell * 0.35 + (hash(own) - 0.5) * 0.3 || feathered < 0.5) {
			discard;
		}
		// (finer than the rows: wisps of barbs)
		vec2 wisp = vec2(UV.x * rows.x * 1.5, UV.y * rows.y * 3.0);
		float tuft = hash(floor(wisp)) * 0.6 + grain * 0.4;
		float across = abs(fract(wisp.y) * 2.0 - 1.0);
		if (tuft < shell * 0.75 || across > 1.0 - shell * 0.55) {
			discard;
		}
	}
	vec3 base = mix(albedo, pale, clamp(COLOR.b, 0.0, 1.0) * pale_gain);
	base = mix(base, dark, clamp(COLOR.g, 0.0, 1.0) * dark_gain);
	base *= tone;
	// Bare skin: grey, in fine scales.
	vec2 scale_at = UV * vec2(240.0, 200.0);
	float scales = noise(scale_at) * 0.6 + noise(scale_at * 2.3) * 0.4;
	vec3 bare = mix(skin, base, 0.25) * (0.86 + 0.24 * scales) * mix(0.75, 1.0, clamp(COLOR.r, 0.0, 1.0));
	vec3 colour = mix(bare, base, feathered);
	colour *= mix(1.0 - crease, 1.0, clamp(COLOR.r, 0.0, 1.0));
	// (the tips of the shells catch the light a little: paler)
	colour = mix(colour, colour * 1.25, shell * 0.5);
	ALBEDO = colour;
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
	float lit = cut(facing * smoothstep(0.15, 0.6, reach) + (grain - 0.5) * 0.05, 0.04);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(1.0 - rim_width, 1.0, graze + (grain - 0.5) * 0.3) * lit * plumage;
	SPECULAR_LIGHT += rim * rim_gain * ALBEDO * strength * LIGHT_COLOR / PI;
}
"""

const FEATHERS_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 tip_colour : source_color = vec3(0.55, 0.53, 0.49);
uniform float wrap = 0.4;
uniform float flatness = 0.6;
// Bars across a barred feather: how many along it, and how dark.
uniform float bars = 6.5;
uniform float bar_dark = 0.5;
uniform vec3 tint : source_color = vec3(1.0);

varying vec4 painted;

void vertex() {
	painted = COLOR;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void fragment() {
	float along = UV.x;
	float across = abs(UV.y - 0.5) * 2.0;
	vec3 colour = painted.rgb * tint;
	// (dark bars across it, a little ragged where the barbs part)
	float barbs = sin((along * 70.0 + across * 22.0) * 3.14159);
	float band = sin((along * bars + across * 0.18) * 6.28318);
	float barred = cut(band + barbs * 0.08, 0.25) * painted.a;
	colour *= 1.0 - bar_dark * barred;
	// The shaft, pale; the barbs, fine lines; the edges darker, the tip paler.
	float shaft = 1.0 - smoothstep(0.03, 0.09, across);
	colour = mix(colour, tip_colour * 0.85, shaft * (1.0 - along) * 0.6);
	colour *= 0.94 + 0.06 * barbs;
	colour *= mix(1.0, 0.72, smoothstep(0.7, 1.0, across));
	colour = mix(colour, tip_colour, smoothstep(0.82, 1.0, along) * 0.25);
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = cut(facing * smoothstep(0.15, 0.6, reach), 0.04);
	DIFFUSE_LIGHT += lit * mix(reach, 1.0, flatness) * LIGHT_COLOR / PI;
	// (light coming through a vane from behind it, a little)
	float through = clamp(-dot(NORMAL, LIGHT), 0.0, 1.0) * 0.18;
	DIFFUSE_LIGHT += through * reach * LIGHT_COLOR / PI;
}
"""

const PARTS_SHADER := """
shader_type spatial;

uniform float wrap = 0.35;
uniform float flatness = 0.6;
// How brightly its eyes give back the light (the parts whose wetness is 1).
uniform float eyeshine = 0.4;
uniform vec3 shine : source_color = vec3(0.85, 0.7, 0.35);

varying float wet;

void vertex() {
	wet = COLOR.a;
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (wet > 0.97) {
		// An eye: where on its front this is (the second texture coordinates), 0 at
		// the middle of the pupil, 1 at its rim. A bird's eye: a big round black
		// pupil in a pale gold iris, a dark ring round it.
		float r = length(UV2 - vec2(0.5)) / 0.4;
		float pixel = max(fwidth(r), 0.002);
		float pupil = 1.0 - smoothstep(0.42 - pixel, 0.42 + pixel, r);
		float rim = smoothstep(0.86 - pixel, 0.94 + pixel, r);
		vec3 iris = COLOR.rgb * mix(1.15, 0.7, smoothstep(0.4, 0.9, r));
		ALBEDO = mix(mix(iris, vec3(0.01), pupil), vec3(0.04, 0.035, 0.03), rim);
		float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
		EMISSION = shine * eyeshine * (0.2 + 0.8 * facing * facing) * (1.0 - rim) * mix(0.55, 0.2, pupil);
	}
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = cut(facing * smoothstep(0.15, 0.6, reach), 0.05);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	// A wet or glossy surface (an eye, a claw) has one small hard glint on it.
	vec3 half_way = normalize(LIGHT + VIEW);
	float glint = cut(pow(clamp(dot(NORMAL, half_way), 0.0, 1.0), mix(8.0, 120.0, wet)), 0.6) * wet * lit;
	SPECULAR_LIGHT += glint * strength * LIGHT_COLOR * 0.7;
}
"""

static var _coat_shader: Shader
static var _shell_shader: Shader
static var _feathers_shader: Shader
static var _parts_shader: Shader


## Gives every surface of `model` its material, by the name the model gives it
## (coat, feathers, parts), and says which is which: {"coat": the skin layer
## of the coat (its shells hang off it as `next_pass`), "feathers", "parts"}.
## `tint` multiplies the colours of its plumage (one a little browner or
## greyer than the next); `shells` is how many layers of feather tips stand
## off its outline.
static func dress(model: Node, tint := Color.WHITE, shells := 2, eyeshine := 0.4) -> Dictionary:
	if _coat_shader == null:
		_coat_shader = _shader(COAT_SHADER)
		# (the shells take no shadow: at the grazing angles of the outline it only speckles them)
		_shell_shader = _shader(COAT_SHADER.replace("shader_type spatial;", "shader_type spatial;
render_mode shadows_disabled;"))
		_feathers_shader = _shader(FEATHERS_SHADER)
		_parts_shader = _shader(PARTS_SHADER)
	var made := {}
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var material: ShaderMaterial
			match String(original.resource_name):
				"coat":
					material = _coat(original.albedo_color * tint, tint, shells)
				"feathers":
					material = ShaderMaterial.new()
					material.shader = _feathers_shader
					material.set_shader_parameter(&"tint", tint)
				_:
					material = ShaderMaterial.new()
					material.shader = _parts_shader
					material.set_shader_parameter(&"eyeshine", eyeshine)
			made[String(original.resource_name)] = material
			part.set_surface_override_material(surface, material)
	return made


static func _coat(colour: Color, tint: Color, shells: int) -> ShaderMaterial:
	var skin := _layer(colour, tint, 0.0)
	var under := skin
	for i in shells:
		var layer := _layer(colour, tint, float(i + 1) / shells)
		under.next_pass = layer
		under = layer
	return skin


static func _layer(colour: Color, tint: Color, shell: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _shell_shader if shell > 0.0 else _coat_shader
	material.set_shader_parameter(&"albedo", colour)
	material.set_shader_parameter(&"pale", Color(0.56, 0.54, 0.50) * tint)
	material.set_shader_parameter(&"shell", shell)
	return material


static func _shader(code: String) -> Shader:
	var shader := Shader.new()
	shader.code = code
	return shader

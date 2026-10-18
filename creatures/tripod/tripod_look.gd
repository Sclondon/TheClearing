class_name TripodLook
## What the tripod (Tripod, creatures/tripod/tripod.gd) is drawn with: one
## material for each of the model's three surfaces, and the light it throws.
##
## - METAL: weathered alien plate, bronze on the hood and dark steel below,
##   lit in hard bands like everything else in the mist, with a hard metal
##   glint that slides over it. Laid in great plates (the model's UVs are in
##   metres): dark seams, rows of rivets, each plate a little different in
##   tone. Verdigris where the rain has run and lain, rust streaks running down,
##   grime in every crease (the model's baked occlusion), edges rubbed bright.
##   Vertex colours: red the tone (dark steel to bronze), green how open to the
##   sky, blue edge wear.
## - GLOW: its lenses, unlit and bright enough to bloom: red in the vertex
##   colour is the great eye (`eye`), green the heat ray's lens (`emitter`).
## - WEED: the red weed of Mars hanging off it in wet strands.
## - The searchlight's BEAM (a cone in the mist), the HEAT RAY, and the SCORCH
##   it leaves on the ground, each a material of its own.
##
## Nothing uses a texture or the screen, so it costs the same in a web build.

const METAL_SHADER := """
shader_type spatial;
render_mode cull_back;

uniform vec3 bronze : source_color = vec3(0.36, 0.25, 0.13);
uniform vec3 steel : source_color = vec3(0.19, 0.19, 0.19);
uniform vec3 machine : source_color = vec3(0.06, 0.055, 0.052);
uniform vec3 verdigris : source_color = vec3(0.22, 0.30, 0.26);
uniform vec3 rust : source_color = vec3(0.26, 0.12, 0.06);
uniform vec3 worn : source_color = vec3(0.5, 0.43, 0.32);
uniform float plate_size = 3.4;
uniform float seam_width = 0.035;
uniform float rivet_step = 0.55;
uniform float patina = 0.2;
uniform float streaks = 0.5;
// The banded light, and the glint.
uniform float wrap = 0.3;
uniform float flatness = 0.55;
uniform float glint_gain = 0.16;
uniform float glint_gloss = 90.0;
uniform vec3 rim_colour : source_color = vec3(0.62, 0.66, 0.66);
uniform float rim_gain = 0.12;

varying vec3 world_pos;
varying float metal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 3.7) * 0.3 + noise(p * 4.3 + 7.1) * 0.15;
}

float line(float d, float width) {
	float pixel = max(fwidth(d), 0.0005);
	return 1.0 - smoothstep(width - pixel, width + pixel, d);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float tone = COLOR.r;
	float open = COLOR.g;
	float wear = COLOR.b;
	vec3 base = tone > 0.5 ? mix(steel, bronze, (tone - 0.5) * 2.0) : mix(machine, steel, tone * 2.0);
	// Plates, laid like brickwork, each its own tone.
	vec2 p = UV / plate_size;
	p.x += floor(p.y) * 0.5;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 edge = min(f, 1.0 - f) * plate_size;
	float seam = line(min(edge.x, edge.y), seam_width);
	float plate_tone = 0.84 + 0.32 * hash(cell);
	// Rivets along the seams.
	vec2 along = UV / rivet_step;
	float rivet = 0.0;
	if (edge.y < 0.22) {
		rivet = line(length(vec2((fract(along.x) - 0.5) * rivet_step, edge.y - 0.14)), 0.055);
	} else if (edge.x < 0.22) {
		rivet = line(length(vec2(edge.x - 0.14, (fract(along.y) - 0.5) * rivet_step)), 0.055);
	}
	vec3 colour = base * plate_tone;
	// Weather: verdigris where water lies (open to the sky), rust running down in streaks.
	float green = smoothstep(0.35, 0.8, fbm(world_pos.xz * 0.09 + world_pos.y * 0.04)) * smoothstep(0.35, 0.9, open) * patina;
	colour = mix(colour, verdigris * (0.8 + 0.4 * noise(UV * 2.0)), green * step(0.45, tone));
	float streak = smoothstep(0.55, 0.9, noise(vec2(world_pos.x * 1.7 + world_pos.z * 1.3, world_pos.y * 0.08))) * streaks;
	colour = mix(colour, rust, streak * (0.4 + 0.6 * seam) * 0.6);
	// Grime in the creases, seams dark, rivet heads and worn edges bright.
	colour *= mix(0.3, 1.0, open);
	colour *= 1.0 - seam * 0.45;
	colour = mix(colour, worn, clamp(wear * 0.35 + rivet * 0.35, 0.0, 1.0) * (0.5 + 0.5 * open));
	ALBEDO = colour;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	metal = (1.0 - seam) * (0.35 + 0.65 * open) * (0.55 + 0.45 * tone) + wear * 0.6;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = rim_colour * pow(graze, 3.0) * rim_gain * (0.4 + 0.6 * open);
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = cut(facing * smoothstep(0.15, 0.6, reach), 0.06);
	DIFFUSE_LIGHT += lit * mix(reach, 1.0, flatness) * LIGHT_COLOR / PI;
	vec3 half_way = normalize(LIGHT + VIEW);
	float glint = cut(pow(clamp(dot(NORMAL, half_way), 0.0, 1.0), glint_gloss), 0.5);
	SPECULAR_LIGHT += glint * lit * metal * glint_gain * LIGHT_COLOR;
}
"""

const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec3 eye_colour : source_color = vec3(0.86, 0.93, 1.0);
uniform float eye = 2.4;
uniform vec3 ray_colour : source_color = vec3(1.0, 0.62, 0.3);
uniform float emitter = 0.1;
uniform vec3 dark : source_color = vec3(0.04, 0.045, 0.05);

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 light = eye_colour * COLOR.r * eye * (0.55 + 0.45 * facing)
		+ ray_colour * COLOR.g * emitter * (0.6 + 0.4 * facing);
	// (a dull glass when it is not lit)
	ALBEDO = max(light, dark + vec3(0.06) * pow(facing, 8.0));
}
"""

const WEED_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 deep : source_color = vec3(0.17, 0.02, 0.015);
uniform vec3 bright : source_color = vec3(0.42, 0.06, 0.035);
uniform float wrap = 0.5;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	float strand = hash(floor(COLOR.r * 97.0));
	float vein = 0.5 + 0.5 * sin(UV.y * 9.0 + strand * 6.0);
	ALBEDO = mix(deep, bright, strand * 0.6 + vein * 0.3) * mix(0.55, 1.0, COLOR.g);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float pixel = max(fwidth(facing), 0.0005);
	float lit = smoothstep(0.1 - pixel, 0.1 + pixel, facing * clamp(ATTENUATION, 0.0, 1.0));
	DIFFUSE_LIGHT += mix(0.35, 1.0, lit) * LIGHT_COLOR / PI;
	// (wet: a little light comes through a strand from behind)
	DIFFUSE_LIGHT += clamp(-dot(NORMAL, LIGHT), 0.0, 1.0) * 0.25 * LIGHT_COLOR * vec3(1.0, 0.3, 0.2) / PI;
}
"""

## The searchlight's cone in the mist: brightest at its axis, fading along its
## length and wherever the eye is near it, with motes drifting in it.
const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 colour : source_color = vec3(0.85, 0.92, 1.0);
uniform float power = 0.4;
uniform float fog = 0.0045;
varying float along;
varying vec3 world_pos;

float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }

void vertex() {
	along = -VERTEX.z;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float axis = pow(clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 1.6);
	float fade = (1.0 - along * 0.55) * smoothstep(0.0, 0.04, along);
	float distance = length(VERTEX);
	float near = smoothstep(1.5, 14.0, distance);
	float mist = exp(-distance * fog);
	vec3 drift = floor(world_pos * 1.3 + vec3(0.0, TIME * 0.6, 0.0));
	float motes = step(0.985, hash(drift)) * 0.6;
	ALBEDO = colour * power * axis * fade * near * mist * (1.0 + motes);
}
"""

## The heat ray: a white-hot core in a sheath of orange, flickering and
## crawling along its length.
const RAY_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 core : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 sheath : source_color = vec3(1.0, 0.45, 0.12);
uniform float power = 1.0;
uniform float length = 50.0;
varying float along;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void vertex() {
	along = -VERTEX.z;
}

void fragment() {
	float axis = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float crawl = 0.75 + 0.25 * sin(along * length * 0.9 - TIME * 40.0) * sin(along * length * 0.37 + TIME * 23.0);
	float flicker = 0.85 + 0.15 * hash(floor(TIME * 30.0));
	vec3 c = mix(sheath, core, pow(axis, 6.0)) * pow(axis, 1.5);
	ALBEDO = c * power * crawl * flicker * 2.2;
}
"""

## Where the ray has burned: a ragged black char with a glowing seam down it
## that cools (`now` against when each part was burned, in the second UVs).
const SCORCH_SHADER := """
shader_type spatial;
render_mode cull_disabled, depth_draw_never, shadows_disabled;

uniform float now = 0.0;
uniform float cool = 6.0;
uniform float fade = 30.0;
uniform vec3 char_colour : source_color = vec3(0.025, 0.022, 0.02);
uniform vec3 ember : source_color = vec3(1.0, 0.35, 0.08);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float age = max(now - UV2.x, 0.0);
	float across = abs(UV.x - 0.5) * 2.0;
	float ragged = noise(vec2(UV.y * 1.3, UV.x * 3.0)) * 0.45 + noise(vec2(UV.y * 5.0, UV.x * 8.0)) * 0.2;
	float burnt = 1.0 - smoothstep(0.45, 0.95, across + ragged - 0.2);
	float heat = exp(-age / cool) * (1.0 - smoothstep(0.0, 0.35, across + ragged * 0.4));
	ALBEDO = char_colour;
	EMISSION = ember * heat * 3.0 + ember * 0.4 * heat * heat;
	ALPHA = burnt * (1.0 - smoothstep(fade * 0.6, fade, age)) * 0.92;
}
"""

## A puff or spark: a soft round dot, coloured by the particles.
const DOT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform bool additive = false;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float soft = 1.0 - smoothstep(0.2, 1.0, d);
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * soft;
}
"""

static var _shaders := {}


static func _shader(code: String) -> Shader:
	if not _shaders.has(code):
		var shader := Shader.new()
		shader.code = code
		_shaders[code] = shader
	return _shaders[code]


## Puts its materials on every mesh of the model, by surface name (metal,
## glow, weed); returns them by name.
static func dress(model: Node) -> Dictionary:
	var metal := ShaderMaterial.new()
	metal.shader = _shader(METAL_SHADER)
	var glow := ShaderMaterial.new()
	glow.shader = _shader(GLOW_SHADER)
	var weed := ShaderMaterial.new()
	weed.shader = _shader(WEED_SHADER)
	var by_name := {"metal": metal, "glow": glow, "weed": weed}
	for mesh_instance: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_instance.mesh
		for s in mesh.get_surface_count():
			var original := mesh.surface_get_material(s)
			var label := original.resource_name if original else "metal"
			mesh_instance.set_surface_override_material(s, by_name.get(label, metal))
	return by_name


static func beam() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _shader(BEAM_SHADER)
	return material


static func ray() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _shader(RAY_SHADER)
	return material


static func scorch() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _shader(SCORCH_SHADER)
	material.render_priority = 1
	return material


static func dot() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _shader(DOT_SHADER)
	return material


## A cone `segments` round, open at both ends, from the origin out along -Z to
## length 1 and radius 1 there (scale it).
static func cone_mesh(segments := 20) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for k in segments + 1:
		var a := TAU * k / segments
		var round_about := Vector3(cos(a), sin(a), 0.0)
		verts.append(Vector3.ZERO + round_about * 0.02)
		verts.append(Vector3(0.0, 0.0, -1.0) + round_about)
		var n := (round_about + Vector3(0.0, 0.0, -0.1)).normalized()
		normals.append(n)
		normals.append(n)
	for k in segments:
		var i := k * 2
		indices.append_array([i, i + 1, i + 2, i + 2, i + 1, i + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A tube of radius 1 from the origin out along -Z to length 1 (scale it).
static func tube_mesh(segments := 10) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for k in segments + 1:
		var a := TAU * k / segments
		var round_about := Vector3(cos(a), sin(a), 0.0)
		verts.append(round_about)
		verts.append(round_about + Vector3(0.0, 0.0, -1.0))
		normals.append(round_about)
		normals.append(round_about)
	for k in segments:
		var i := k * 2
		indices.append_array([i, i + 1, i + 2, i + 2, i + 1, i + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

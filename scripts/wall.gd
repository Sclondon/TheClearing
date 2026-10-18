@tool
class_name Wall
extends StaticBody3D
## A wall: one solid box, `width` along X, `height` up and `depth` along Z, that
## stands on its origin (the middle of its base), and can be bumped into. Change
## any of it in the Inspector and it is redrawn at once.
##
## It is drawn with a texture (with its relief and roughness) laid on each face
## at its true size, one tile every `tile_size` metres, so a bigger wall shows more
## concrete, not stretched concrete. So that a big wall does not look like the same
## square over and over, the texture is broken up (`break_up`): a slow noise across
## the wall chooses which shifted copy of it shows where, blended where they meet
## (shifted only, never turned, so formboard lines and ribs keep their way), and a
## broad, slow change of tone is laid over it all (`variation`).
##
## The looks are photographed concrete from Poly Haven (CC0; textures/polyhaven/,
## see its CREDITS.md), concretes made by tools/make_wall_textures.gd, and the old
## stone blocks; or Custom, to keep textures of your own. Wall.material_for gives
## the same surface to anything else (the maze's walls are drawn with it).

# (numbered, so that a wall saved with a look keeps it as more are added)
enum Look {
	CAST = 7, SLABS = 8, GROOVED = 9, ROUGH = 10, RIBBED = 11,
	CONCRETE = 6, CONCRETE_PANELS = 0, BOARD_MARKED = 1, WEATHERED = 2, MONOLITH = 3, STONE_BLOCKS = 4,
	CUSTOM = 5,
}
## Each look's maps (a path with %s for diff, nor_gl and rough; or the name of a
## made texture and its _normal) and how many metres one tile of them covers.
const LOOKS := {
	Look.CAST: ["polyhaven/concrete_wall_007/concrete_wall_007_%s_2k.jpg", 2.16],
	Look.SLABS: ["polyhaven/concrete_slab_wall_02/concrete_slab_wall_02_%s_2k.jpg", 2.1],
	Look.GROOVED: ["polyhaven/concrete/concrete_%s_2k.jpg", 4.0],
	Look.ROUGH: ["polyhaven/rough_concrete/rough_concrete_%s_2k.jpg", 1.23],
	Look.RIBBED: ["polyhaven/ribbed_concrete_wall/ribbed_concrete_wall_%s_2k.jpg", 2.0],
	Look.CONCRETE: ["concrete", 6.0],
	Look.CONCRETE_PANELS: ["concrete_panels", 9.6],
	Look.BOARD_MARKED: ["concrete_boards", 7.0],
	Look.WEATHERED: ["concrete_weathered", 10.0],
	Look.MONOLITH: ["concrete_monolith", 12.0],
	Look.STONE_BLOCKS: ["stone_blocks", 8.0],
}

## The surface: in the box's own space, so the texture stays put on the wall
## wherever it stands. (With `world_space` on, in the world's instead, so that the
## many boxes of the maze's walls meet without seams.)
const SHADER := """
shader_type spatial;

uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_normal = true;
uniform bool has_rough = false;
uniform bool world_space = false;
uniform float roughness = 0.9;
uniform float tile_size = 2.0;
uniform float relief = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float break_up = 1.0;
uniform float variation = 0.15;
uniform float weathering = 0.35;

varying vec3 at;
varying vec3 facing;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 s = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), s.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), s.x), s.y);
}

void vertex() {
	at = world_space ? (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz : VERTEX;
	facing = world_space ? mat3(MODEL_MATRIX) * NORMAL : NORMAL;
}

void fragment() {
	vec3 n = normalize(facing);
	// The face's own across and up: up the wall on its sides, and away on its top and bottom.
	vec3 v_axis = abs(n.y) > 0.5 ? vec3(0.0, 0.0, -1.0) : vec3(0.0, 1.0, 0.0);
	vec3 u_axis = normalize(cross(v_axis, n));
	vec2 metres = vec2(dot(at, u_axis), -dot(at, v_axis));
	vec2 uv = metres / tile_size;
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);

	// Which shifted copy shows here (Inigo Quilez's way of hiding repeats): a slow
	// noise picks between neighbouring offsets, and the two are blended where it turns.
	float k = noise(uv * 0.21) * 7.0 + noise(uv * 0.53) * 1.0;
	float i = floor(k);
	float f = fract(k);
	vec2 off_a = sin(vec2(3.0, 7.0) * i) * break_up;
	vec2 off_b = sin(vec2(3.0, 7.0) * (i + 1.0)) * break_up;
	vec4 a = textureGrad(albedo_map, uv + off_a, dx, dy);
	vec4 b = textureGrad(albedo_map, uv + off_b, dx, dy);
	float w = smoothstep(0.2, 0.8, f - 0.1 * dot(a.rgb - b.rgb, vec3(1.0))) * step(0.001, break_up);
	vec3 colour = mix(a.rgb, b.rgb, w);

	// A broad, slow change of tone across the whole wall, in metres, not tiles.
	float broad = noise(metres / 17.0) * 0.65 + noise(metres / 6.5 + 31.0) * 0.35;
	colour *= 1.0 + (broad - 0.5) * 2.0 * variation;
	// Weathering, as rain stains concrete: streaks that start at a ledge (every so
	// many metres down, at a place of their own), darkest where they start and
	// fading and narrowing as they run down; ragged and streaky at their edges, in
	// a brownish grime that darkens the concrete's own grain rather than laying a
	// shade over it; and now and then a pale one, where lime has washed out.
	float down = metres.y / 11.0 + noise(vec2(metres.x / 4.0, 2.0)) * 0.8;
	float band = floor(down);
	float along = fract(down);
	// Each stain is many thin drips: lines a few centimetres wide and metres long...
	float drips = noise(vec2(metres.x / 0.05, metres.y / 5.0)) * 0.65 + noise(vec2(metres.x / 0.018, metres.y / 1.6) + 5.0) * 0.35;
	float streaky = smoothstep(0.3, 0.8, drips);
	// ...gathered where the water ran off the ledge (each band its own places,
	// a metre or two across), the patch narrowing as it runs down,
	float zone = noise(vec2(metres.x / 1.6, band * 13.7)) * 0.75 + noise(vec2(metres.x / 0.5, band * 3.1)) * 0.25;
	float gathered = smoothstep(0.42 + 0.22 * along, 0.66 + 0.22 * along, zone);
	// ...coming on softly under the ledge, and fading as it goes.
	float fall = smoothstep(0.0, 0.08, along) * pow(1.0 - along, 1.3);
	float stain = gathered * streaky * fall;
	float lime_zone = noise(vec2(metres.x / 0.9, band * 5.3 + 40.0));
	float lime = smoothstep(0.78, 0.86, lime_zone) * streaky * fall * step(0.55, noise(vec2(band, 9.0)));
	float grain = dot(colour, vec3(0.33));
	vec3 grime = colour * vec3(0.5, 0.48, 0.43) * (0.85 + 0.3 * grain);
	colour = mix(colour, grime, clamp(stain * weathering * 2.2, 0.0, 1.0));
	colour = mix(colour, colour * vec3(1.22, 1.22, 1.2) + vec3(0.04), lime * weathering * 0.6);
	ALBEDO = colour * tint.rgb;

	if (has_rough) {
		ROUGHNESS = mix(textureGrad(rough_map, uv + off_a, dx, dy).r, textureGrad(rough_map, uv + off_b, dx, dy).r, w);
	} else {
		ROUGHNESS = roughness;
	}
	SPECULAR = 0.3;

	vec3 bent = n;
	if (has_normal) {
		vec3 t = mix(textureGrad(normal_map, uv + off_a, dx, dy).rgb, textureGrad(normal_map, uv + off_b, dx, dy).rgb, w) * 2.0 - 1.0;
		t.xy *= relief;
		// (an OpenGL normal map: red across, green up the picture)
		bent = normalize(u_axis * t.x + v_axis * t.y + n * t.z);
	}
	NORMAL = normalize((VIEW_MATRIX * (world_space ? vec4(bent, 0.0) : MODEL_MATRIX * vec4(bent, 0.0))).xyz);
}
"""

@export_range(0.1, 200.0, 0.1, "or_greater", "suffix:m") var width := 14.0:
	set(value):
		width = value
		_build()
@export_range(0.1, 200.0, 0.1, "or_greater", "suffix:m") var height := 34.0:
	set(value):
		height = value
		_build()
@export_range(0.1, 50.0, 0.1, "or_greater", "suffix:m") var depth := 3.2:
	set(value):
		depth = value
		_build()
## Its surface, chosen from LOOKS (which sets the textures and a fitting tile
## size), or Custom to keep textures of your own.
@export var look := Look.CAST:
	set(value):
		look = value
		if look != Look.CUSTOM and LOOKS.has(look):
			var maps := maps_for(look)
			texture = maps[0]
			normal_map = maps[1]
			roughness_map = maps[2]
			tile_size = LOOKS[look][1]
		_build()
@export var texture: Texture2D:
	set(value):
		texture = value
		_build()
## Its relief: a normal map (OpenGL, green up), laid on as the texture is, and how strong.
@export var normal_map: Texture2D:
	set(value):
		normal_map = value
		_build()
@export_range(0.0, 4.0, 0.05) var relief := 1.0:
	set(value):
		relief = value
		_build()
## Where it is rough and where smoother; without one, `roughness` all over.
@export var roughness_map: Texture2D:
	set(value):
		roughness_map = value
		_build()
@export_range(0.0, 1.0, 0.01) var roughness := 0.9:
	set(value):
		roughness = value
		_build()
## How many metres one tile of the texture covers.
@export_range(0.25, 50.0, 0.01, "or_greater", "suffix:m") var tile_size := 2.16:
	set(value):
		tile_size = value
		_build()
## How much the texture is broken up so that its repeats do not show (0: not at all).
@export_range(0.0, 1.0, 0.01) var break_up := 1.0:
	set(value):
		break_up = value
		_build()
## How much its tone wanders across the wall, broadly and slowly.
@export_range(0.0, 0.5, 0.01) var variation := 0.22:
	set(value):
		variation = value
		_build()
## How much rain has stained it: grimy streaks running down from ledges, and a few pale ones.
@export_range(0.0, 1.0, 0.01) var weathering := 0.35:
	set(value):
		weathering = value
		_build()
## Multiplied over the texture.
@export var tint := Color.WHITE:
	set(value):
		tint = value
		_build()

static var _shader: Shader

var _mesh: MeshInstance3D
var _shape: CollisionShape3D


func _ready() -> void:
	_build()


## A look's [colour, normal, roughness] textures (null where it has none).
static func maps_for(chosen: Look) -> Array:
	var path: String = LOOKS[chosen][0]
	if "%s" in path:
		return [load("res://textures/" + path % "diff"), load("res://textures/" + path % "nor_gl"), load("res://textures/" + path % "rough")]
	var rough := "res://textures/%s_rough.png" % path
	return [load("res://textures/%s.png" % path), load("res://textures/%s_normal.png" % path), load(rough) if ResourceLoader.exists(rough) else null]


## The surface of a look, as a material for anything (`world_space`: laid on in the
## world's space, so that many boxes meet without seams).
static func material_for(chosen: Look, world_space := false, tint := Color.WHITE) -> ShaderMaterial:
	var maps := maps_for(chosen)
	var material := ShaderMaterial.new()
	material.shader = shader()
	_apply(material, maps[0], maps[1], maps[2], 0.9, LOOKS[chosen][1], 1.0, tint, 1.0, 0.22, 0.35)
	material.set_shader_parameter(&"world_space", world_space)
	return material


## The wall's shader, made once.
static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	return _shader


static func _apply(material: ShaderMaterial, colour: Texture2D, bump: Texture2D, rough: Texture2D, rough_value: float, tile: float, strength: float, shade: Color, broken: float, wander: float, rain := 0.35) -> void:
	material.set_shader_parameter(&"weathering", rain)
	material.set_shader_parameter(&"albedo_map", colour)
	material.set_shader_parameter(&"normal_map", bump)
	material.set_shader_parameter(&"has_normal", bump != null)
	material.set_shader_parameter(&"rough_map", rough)
	material.set_shader_parameter(&"has_rough", rough != null)
	material.set_shader_parameter(&"roughness", rough_value)
	material.set_shader_parameter(&"tile_size", tile)
	material.set_shader_parameter(&"relief", strength)
	material.set_shader_parameter(&"tint", shade)
	material.set_shader_parameter(&"break_up", broken)
	material.set_shader_parameter(&"variation", wander)


func _build() -> void:
	_fill_missing()
	if not is_inside_tree():
		return
	# (its own mesh and shape, found again if the script was reloaded in the editor, never made twice)
	if _mesh == null or not is_instance_valid(_mesh):
		_mesh = _own_child("Mesh", MeshInstance3D) as MeshInstance3D
	if _shape == null or not is_instance_valid(_shape):
		_shape = _own_child("Shape", CollisionShape3D) as CollisionShape3D
	var size := Vector3(width, height, depth)
	var box := BoxMesh.new()
	box.size = size
	_mesh.mesh = box
	_mesh.position = Vector3(0.0, height * 0.5, 0.0)
	var material := _mesh.material_override as ShaderMaterial
	if material == null:
		material = ShaderMaterial.new()
		material.shader = shader()
		_mesh.material_override = material
	_apply(material, texture, normal_map, roughness_map, roughness, tile_size, relief, tint, break_up, variation, weathering)
	var shape := BoxShape3D.new()
	shape.size = size
	_shape.shape = shape
	_shape.position = _mesh.position


## Gives any setting that is empty its default. (When the editor reloads this
## script after it has changed, a wall already in an open scene can come back with
## settings it did not have before left empty.)
func _fill_missing() -> void:
	var defaults := {
		"width": 14.0, "height": 34.0, "depth": 3.2, "look": Look.CAST, "relief": 1.0, "roughness": 0.9,
		"tile_size": 2.16, "break_up": 1.0, "variation": 0.22, "weathering": 0.35, "tint": Color.WHITE,
	}
	for key: String in defaults:
		if get(key) == null:
			set(key, defaults[key])
	if look != Look.CUSTOM and LOOKS.has(look) and texture == null:
		var maps := maps_for(look)
		texture = maps[0]
		if normal_map == null:
			normal_map = maps[1]
		if roughness_map == null:
			roughness_map = maps[2]


## The internal child called `called` of class `kind`, made if there is none (and
## any others of that name, left over, taken away).
func _own_child(called: String, kind: Variant) -> Node:
	var found: Node = null
	for child in get_children(true):
		if String(child.name).begins_with(called) and is_instance_of(child, kind):
			if found == null:
				found = child
			else:
				child.queue_free()
	if found == null:
		found = kind.new()
		found.name = called
		add_child(found, false, Node.INTERNAL_MODE_BACK)
	return found

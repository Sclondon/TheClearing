class_name MudSteps
extends Node3D
## Footprints in the mud of the maze's floor, and splashes in its puddles (the
## user, 2026-10-18: "you should leave footsteps in teh mud in the maze, and the
## puddles should splash").
##
## The mud and the puddles are drawn by the ground's shader (MazeStone.ground),
## not made of anything: where it is mud and where a puddle stands is worked out
## here the same way, from the same noise picture, map of the walls' feet and
## wetness (which the weather changes), so that a print lands where mud is drawn
## and a splash where water is.
##
## Every figure on a CharacterRig (the group "figures": the boy, the others in
## the room, the runners) is listened to (`footfall`): a foot coming down in mud
## leaves a print, dark and wet, deeper the wetter the mud, that fades after a
## while; one coming down in a puddle throws up a crown of muddy drops and a
## ring, with a splash to hear.
##
##     MudSteps.put(world, maze, builder.ground_material)

## How many prints are kept at once (the oldest go first), and how long one lasts, seconds.
const PRINTS := 240
const PRINT_LIFE := 90.0
## A print's size, metres (across, heel to toe).
const PRINT_SIZE := Vector2(0.13, 0.29)
## How many drops and rings can be in the air at once; how long a ring lasts, seconds.
const DROPS := 96
const RINGS := 12
const RING_LIFE := 0.7
## How often the figures are looked through for new ones, seconds.
const LOOK_EVERY := 1.0

var maze: Maze
var ground: ShaderMaterial

var _noise: Image
var _feet: Image
var _feet_half := 0.0
var _prints: MultiMeshInstance3D
var _print_material: ShaderMaterial
var _next_print := 0
var _drops: MultiMeshInstance3D
var _drop_at := PackedVector3Array()
var _drop_going := PackedVector3Array()
var _drop_age := PackedFloat32Array()
var _next_drop := 0
var _drops_live := false
var _rings: MultiMeshInstance3D
var _ring_material: ShaderMaterial
var _next_ring := 0
var _clock := 0.0
var _look_in := 0.0
var _heard := {}
var _splash_sound: AudioStream
var _sounds: Array[AudioStreamPlayer3D] = []
var _next_sound := 0


static func put(world: Node, plan: Maze, ground_material: ShaderMaterial) -> MudSteps:
	var made := MudSteps.new()
	made.name = "MudSteps"
	made.maze = plan
	made.ground = ground_material
	world.add_child(made)
	return made


func _ready() -> void:
	top_level = true
	if ground:
		var noise := ground.get_shader_parameter(&"noise_map") as Texture2D
		if noise:
			_noise = noise.get_image()
			if _noise and _noise.is_compressed():
				_noise.decompress()
		var feet := ground.get_shader_parameter(&"feet") as Texture2D
		if feet:
			_feet = feet.get_image()
			_feet_half = float(ground.get_shader_parameter(&"feet_half"))
	_make_prints()
	_make_drops()
	_make_rings()
	_splash_sound = OctopusSound.splash()
	for i in 3:
		var player := AudioStreamPlayer3D.new()
		player.stream = _splash_sound
		player.unit_size = 3.0
		player.max_distance = 30.0
		player.volume_db = -14.0
		add_child(player)
		_sounds.append(player)


# --- What the ground is, where ---

# The shader's `patches`: smooth noise, eased between whole metres of `p`.
func _patches(p: Vector2) -> float:
	var whole := p.floor()
	var part := p - whole
	part = part * part * (Vector2(3.0, 3.0) - 2.0 * part)
	return _texel_r(_noise, whole + part, true)


# A picture read smoothly at `texel` (in pixels, a pixel's middle at whole numbers), red or green.
func _texel_r(image: Image, texel: Vector2, wrap: bool, green := false) -> float:
	var w := image.get_width()
	var h := image.get_height()
	var x0 := floori(texel.x)
	var y0 := floori(texel.y)
	var fx := texel.x - x0
	var fy := texel.y - y0
	var v := [0.0, 0.0, 0.0, 0.0]
	for k in 4:
		var x := x0 + (k & 1)
		var y := y0 + (k >> 1)
		if wrap:
			x = posmod(x, w)
			y = posmod(y, h)
		else:
			x = clampi(x, 0, w - 1)
			y = clampi(y, 0, h - 1)
		var c := image.get_pixel(x, y)
		v[k] = c.g if green else c.r
	return lerpf(lerpf(v[0], v[1], fx), lerpf(v[2], v[3], fx), fy)


## What the ground is at `at`: x how soaked (0 dry, over 0.5 mud), y how deep
## a puddle stands there (more than 0: in one), z whether it is the maze's dirt at
## all (1) and not the clearing's grass, the desert or the foot of a wall.
func ground_at(at: Vector3) -> Vector3:
	if _noise == null or ground == null:
		return Vector3.ZERO
	var p := Vector2(at.x, at.z)
	var out := maxf(absf(p.x), absf(p.y))
	var clearing_half := float(ground.get_shader_parameter(&"clearing_half"))
	var maze_half := float(ground.get_shader_parameter(&"maze_half"))
	var in_maze := smoothstep(clearing_half - 0.6, clearing_half + 0.6, out) * (1.0 - smoothstep(maze_half - 0.2, maze_half + 0.4, out))
	var near_wall := Vector2.ZERO
	if _feet and _feet_half > 0.0:
		var uv := p / (2.0 * _feet_half) + Vector2(0.5, 0.5)
		var texel := uv * Vector2(_feet.get_width(), _feet.get_height()) - Vector2(0.5, 0.5)
		near_wall = Vector2(_texel_r(_feet, texel, false), _texel_r(_feet, texel, false, true))
	var by_wall := smoothstep(0.35, 0.75, near_wall.x + (_patches(p * 0.8) - 0.5) * 0.45)
	var wetness := float(ground.get_shader_parameter(&"wetness"))
	var lie := _patches(p / 11.0 + Vector2(3.1, 3.1)) * 0.5 + _patches(p / 3.7 - Vector2(7.7, 7.7)) * 0.32 + _patches(p * 0.85 + Vector2(1.3, 1.3)) * 0.18
	var splash := near_wall.y * (0.75 + 0.5 * _patches(p * 0.6 + Vector2(4.0, 4.0)))
	var soaked := clampf(wetness + (_patches(p / 23.0 + Vector2(9.0, 9.0)) - 0.5) * 0.9 + splash * 0.4 - (lie - 0.5) * 1.4 - 0.15, 0.0, 1.0)
	var hollow := lie * 0.45 + _patches(p / 2.9 + Vector2(11.0, 11.0)) * 0.38 + _patches(p / 1.1 - Vector2(3.0, 3.0)) * 0.17
	var brim := 0.2 + wetness * 0.12 + splash * 0.05 + (_patches(p / 37.0 + Vector2(2.0, 2.0)) - 0.5) * 0.1
	return Vector3(soaked, brim - hollow, in_maze * (1.0 - by_wall))


# --- Who walks on it ---

func _process(delta: float) -> void:
	_clock += delta
	_look_in -= delta
	if _look_in <= 0.0:
		_look_in = LOOK_EVERY
		for figure: Node in get_tree().get_nodes_in_group(&"figures"):
			if not _heard.has(figure) and figure.has_signal(&"footfall"):
				_heard[figure] = true
				figure.connect(&"footfall", _on_footfall.bind(figure))
	if _print_material:
		_print_material.set_shader_parameter(&"now", _clock)
	if _ring_material:
		_ring_material.set_shader_parameter(&"now", _clock)
	if _drops_live:
		_move_drops(delta)


func _on_footfall(at: Vector3, foot: int, weight: float, figure: Node3D) -> void:
	if not is_instance_valid(figure) or not figure.is_visible_in_tree():
		return
	var here := ground_at(at)
	if here.z < 0.5:
		return
	var floor_y := maze.ground_height(at) if maze else at.y
	if absf(at.y - floor_y) > 0.35:
		# (on a ledge, a log or a bridge, not the ground)
		return
	var facing := figure.global_basis.z
	var yaw := atan2(facing.x, facing.z) + (0.16 if foot == 0 else -0.16)
	if here.y > 0.0:
		splash(Vector3(at.x, floor_y, at.z), clampf(weight, 0.25, 2.0))
	elif here.x > 0.42:
		footprint(Vector3(at.x, floor_y, at.z), yaw, smoothstep(0.42, 0.85, here.x) * clampf(0.6 + weight * 0.5, 0.6, 1.3), foot == 0)


## A print at `at` on the ground, its toe toward `yaw`; `strength` 0 to 1 how
## dark and wet (how soft the mud).
func footprint(at: Vector3, yaw: float, strength: float, left: bool) -> void:
	var i := _next_print
	_next_print = (_next_print + 1) % PRINTS
	var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(PRINT_SIZE.x * (-1.0 if left else 1.0), 1.0, PRINT_SIZE.y))
	_prints.multimesh.set_instance_transform(i, Transform3D(basis, at + Vector3.UP * 0.012))
	_prints.multimesh.set_instance_custom_data(i, Color(_clock, clampf(strength, 0.0, 1.0), randf(), 0.0))


## A foot (or a body) coming down in a puddle at `at`: a crown of drops, a ring, a splash.
func splash(at: Vector3, power := 1.0) -> void:
	var count := clampi(roundi(10.0 + 10.0 * power), 8, 28)
	for k in count:
		var i := _next_drop
		_next_drop = (_next_drop + 1) % DROPS
		var round := randf() * TAU
		var out := Vector3(cos(round), 0.0, sin(round))
		var lob := randf()
		_drop_at[i] = at + out * randf_range(0.04, 0.14) + Vector3.UP * 0.02
		_drop_going[i] = out * lerpf(0.5, 1.6, lob) * sqrt(power) + Vector3.UP * lerpf(3.8, 1.8, lob) * sqrt(power) * randf_range(0.75, 1.1)
		_drop_age[i] = 0.0
	_drops_live = true
	var r := _next_ring
	_next_ring = (_next_ring + 1) % RINGS
	_rings.multimesh.set_instance_transform(r, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (0.6 + 0.4 * power)), at + Vector3.UP * 0.015))
	_rings.multimesh.set_instance_custom_data(r, Color(_clock, 0.0, 0.0, 0.0))
	var player := _sounds[_next_sound]
	_next_sound = (_next_sound + 1) % _sounds.size()
	player.global_position = at
	player.pitch_scale = randf_range(1.5, 2.1) / sqrt(maxf(power, 0.5))
	player.volume_db = -16.0 + 5.0 * minf(power, 1.5)
	player.play()


func _move_drops(delta: float) -> void:
	var any := false
	for i in DROPS:
		if _drop_age[i] < 0.0:
			continue
		_drop_age[i] += delta
		_drop_going[i] += Vector3.DOWN * 9.8 * delta
		_drop_at[i] += _drop_going[i] * delta
		if _drop_age[i] > 1.2 or (_drop_going[i].y < 0.0 and _drop_age[i] > 0.15 and maze and _drop_at[i].y < maze.ground_height(_drop_at[i])):
			_drop_age[i] = -1.0
			_drops.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
			continue
		any = true
		var size := 0.05 * (1.0 - _drop_age[i] * 0.4)
		_drops.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(size, size * 1.3, size)), _drop_at[i]))
	_drops_live = any


# --- How they are drawn ---

# (black, part see-through, unlit and unfogged: it darkens the mud under it
# by as much whatever the light and the weather, as wet trodden mud is darker)
const PRINT_SHADER := """
shader_type spatial;
render_mode blend_mix, unshaded, fog_disabled, depth_draw_never, cull_disabled, shadows_disabled;
uniform float now = 0.0;
uniform float life = 90.0;
varying vec4 custom;
void vertex() {
	custom = INSTANCE_CUSTOM;
}
// A boot's sole, toe at +y: the ball and the heel, joined by the arch.
float sole(vec2 p) {
	float ball = length((p - vec2(0.03, 0.2)) / vec2(0.44, 0.3));
	float heel = length((p - vec2(-0.02, -0.3)) / vec2(0.36, 0.2));
	float arch = length((p - vec2(0.06, -0.05)) / vec2(0.3, 0.32));
	return min(min(ball, heel), arch);
}
void fragment() {
	vec2 p = UV - 0.5;
	float d = sole(p);
	float inside = 1.0 - smoothstep(0.8, 1.0, d);
	// (the tread: a few bars across the sole, a little darker)
	float tread = 0.85 + 0.15 * step(0.5, fract(p.y * 9.0 + custom.b));
	float age = now - custom.r;
	float fade = 1.0 - smoothstep(life * 0.6, life, age);
	float dark = inside * custom.g * fade * 0.55 * tread;
	ALBEDO = vec3(0.0);
	ALPHA = dark;
}
"""

const RING_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, unshaded;
uniform float now = 0.0;
uniform float life = 0.7;
varying vec4 custom;
void vertex() {
	custom = INSTANCE_CUSTOM;
	float age = clamp((now - custom.r) / life, 0.0, 1.0);
	VERTEX.xz *= 0.15 + age * 0.85;
}
void fragment() {
	float age = clamp((now - custom.r) / life, 0.0, 1.0);
	float r = length(UV - 0.5) * 2.0;
	float ring = smoothstep(0.75, 0.9, r) * (1.0 - smoothstep(0.9, 1.0, r));
	ALBEDO = vec3(0.75, 0.77, 0.75);
	ALPHA = ring * (1.0 - age) * 0.75 * step(age, 0.999);
}
"""


func _make_prints() -> void:
	var shader := Shader.new()
	shader.code = PRINT_SHADER
	_print_material = ShaderMaterial.new()
	_print_material.shader = shader
	_print_material.set_shader_parameter(&"life", PRINT_LIFE)
	var card := PlaneMesh.new()
	card.size = Vector2.ONE
	card.material = _print_material
	_prints = MultiMeshInstance3D.new()
	_prints.name = "Prints"
	_prints.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_prints.multimesh = _hidden(card, PRINTS, true)
	add_child(_prints)


func _make_drops() -> void:
	var drop := SphereMesh.new()
	drop.radius = 1.0
	drop.height = 2.0
	drop.radial_segments = 6
	drop.rings = 3
	var wet := StandardMaterial3D.new()
	wet.albedo_color = Color(0.62, 0.62, 0.58)
	wet.emission_enabled = true
	wet.emission = Color(0.25, 0.26, 0.25)
	wet.metallic_specular = 0.9
	wet.roughness = 0.15
	drop.material = wet
	_drops = MultiMeshInstance3D.new()
	_drops.name = "Drops"
	_drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_drops.multimesh = _hidden(drop, DROPS, false)
	add_child(_drops)
	_drop_at.resize(DROPS)
	_drop_going.resize(DROPS)
	_drop_age.resize(DROPS)
	_drop_age.fill(-1.0)


func _make_rings() -> void:
	var shader := Shader.new()
	shader.code = RING_SHADER
	_ring_material = ShaderMaterial.new()
	_ring_material.shader = shader
	_ring_material.set_shader_parameter(&"life", RING_LIFE)
	var card := PlaneMesh.new()
	card.size = Vector2.ONE * 0.9
	card.material = _ring_material
	_rings = MultiMeshInstance3D.new()
	_rings.name = "Rings"
	_rings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rings.multimesh = _hidden(card, RINGS, true)
	add_child(_rings)


# A MultiMesh of `count` of `mesh`, all shrunk to nothing until used.
func _hidden(mesh: Mesh, count: int, custom: bool) -> MultiMesh:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = custom
	multi.mesh = mesh
	multi.instance_count = count
	for i in count:
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
		if custom:
			multi.set_instance_custom_data(i, Color(-1000.0, 0.0, 0.0, 0.0))
	return multi

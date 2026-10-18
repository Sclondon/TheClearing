class_name Weather
extends Node3D
## The weather over the maze: spells of the usual overcast, of heavy cloud, and
## of rain, one after another, each a few minutes long, changing over slowly.
## Clouds drift over high above the walls (a layer of them, drawn in the
## shader), thicker and darker as it clouds over; rain falls round the camera;
## and the day is darker with it (DayCycle.gloom) and the ground wetter.
##
## The spells come from the room's seed and how long the round has gone, so it
## rains for everyone in a room at once.

enum Kind { OVERCAST, CLOUDY, RAIN }

## How long a spell lasts, seconds (from, to), and how long one takes to turn
## into the next.
const SPELL := Vector2(100.0, 240.0)
const CHANGE_SECONDS := 25.0
## Each kind's [how clouded over, how hard it rains], and how likely it is.
const LOOKS := {Kind.OVERCAST: [0.35, 0.0], Kind.CLOUDY: [0.85, 0.0], Kind.RAIN: [1.0, 1.0]}
const CHANCES := {Kind.OVERCAST: 0.45, Kind.CLOUDY: 0.3, Kind.RAIN: 0.25}
## How high the clouds are, and how far they reach each way.
const CLOUD_HEIGHT := 420.0
const CLOUD_REACH := 5000.0
## How many raindrops are falling round the camera at most, and over how wide
## and high a box.
const DROPS := 2600
const RAIN_BOX := Vector3(46.0, 26.0, 46.0)

## Seconds since the round began.
var seconds := 0.0
## How clouded over it is (0 to 1), and how hard it is raining.
var clouds := 0.35
var rain := 0.0
## For DevTools: a kind to have instead of the spells (-1: the spells).
var forced := -1

var day: DayCycle
var ground: ShaderMaterial
# [start second, kind] for each spell.
var _spells: Array = []
var _cloud_material: ShaderMaterial
var _rain: GPUParticles3D


## Puts the weather under `world`, for a round of `seed_value`.
static func put(world: Node3D, seed_value: int, day_cycle: DayCycle, ground_material: ShaderMaterial) -> Weather:
	var weather := Weather.new()
	weather.name = "Weather"
	weather.day = day_cycle
	weather.ground = ground_material
	weather._plan(seed_value)
	world.add_child(weather)
	return weather


func _plan(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("weather/%d" % seed_value)
	var at := 0.0
	# (the first is always the usual overcast, so a round does not begin in rain)
	var kind := Kind.OVERCAST
	while at < 4.0 * 3600.0:
		_spells.append([at, kind])
		at += rng.randf_range(SPELL.x, SPELL.y)
		var pick := rng.randf()
		for each: Kind in CHANCES:
			pick -= CHANCES[each]
			if pick <= 0.0:
				kind = each
				break


## The kind of weather `at` seconds into the round.
func kind_at(at: float) -> Kind:
	var found: Kind = Kind.OVERCAST
	for spell: Array in _spells:
		if spell[0] > at:
			break
		found = spell[1]
	return found


func _ready() -> void:
	_cloud_layer()
	_rain_fall()


func _process(delta: float) -> void:
	seconds += delta
	var kind: Kind = forced if forced >= 0 else kind_at(seconds)
	var look: Array = LOOKS[kind]
	clouds = move_toward(clouds, look[0], delta / CHANGE_SECONDS)
	# (the rain comes once it has clouded over, and stops before it clears)
	rain = move_toward(rain, look[1] if clouds > 0.8 else 0.0, delta / (CHANGE_SECONDS * 0.6))
	var light := day.daylight if day else 1.0
	if day:
		day.gloom = clampf((clouds - 0.35) / 0.65, 0.0, 1.0) * 0.45 + rain * 0.55
	if ground:
		ground.set_shader_parameter(&"wetness", 0.45 + rain * 0.5)
	_cloud_material.set_shader_parameter(&"cover", clouds)
	_cloud_material.set_shader_parameter(&"light", lerpf(0.12, 1.0, light) * (1.0 - rain * 0.45))
	var camera := get_viewport().get_camera_3d()
	if camera:
		_rain.global_position = camera.global_position + Vector3.UP * RAIN_BOX.y * 0.45
	# (not there at all unless it is raining: idle, it still costs a lot to draw)
	var raining := rain > 0.02
	_rain.emitting = raining
	_rain.visible = raining
	_rain.process_mode = Node.PROCESS_MODE_INHERIT if raining else Node.PROCESS_MODE_DISABLED
	_rain.amount_ratio = rain


func _cloud_layer() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * CLOUD_REACH * 2.0
	var shader := Shader.new()
	shader.code = CLOUD_SHADER
	_cloud_material = ShaderMaterial.new()
	_cloud_material.shader = shader
	var layer := MeshInstance3D.new()
	layer.name = "Clouds"
	layer.mesh = plane
	layer.material_override = _cloud_material
	layer.position.y = CLOUD_HEIGHT
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(layer)


func _rain_fall() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = DROPS
	_rain.lifetime = RAIN_BOX.y / 22.0
	_rain.preprocess = _rain.lifetime
	_rain.local_coords = false
	_rain.visibility_aabb = AABB(-RAIN_BOX, RAIN_BOX * 2.0)
	_rain.emitting = false
	_rain.visible = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(RAIN_BOX.x * 0.5, 0.5, RAIN_BOX.z * 0.5)
	process.direction = Vector3(0.15, -1.0, 0.05)
	process.spread = 2.0
	process.initial_velocity_min = 20.0
	process.initial_velocity_max = 24.0
	process.gravity = Vector3.ZERO
	_rain.process_material = process
	var streak := QuadMesh.new()
	streak.size = Vector2(0.025, 0.75)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.albedo_color = Color(0.72, 0.76, 0.78, 0.35)
	# (turned to face the camera about the upright, as they fall nearly straight down)
	look.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	look.billboard_keep_scale = true
	look.cull_mode = BaseMaterial3D.CULL_DISABLED
	streak.material = look
	_rain.draw_pass_1 = streak
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rain)


const CLOUD_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// How clouded over (0 a few thin wisps, 1 all of it), and how lit (night 0.1).
uniform float cover = 0.35;
uniform float light = 1.0;
uniform vec2 wind = vec2(4.0, 1.5);
uniform float scale = 0.0022;

varying vec3 place;

void vertex() {
	place = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float weight = 0.5;
	for (int i = 0; i < 5; i++) {
		sum += noise(p) * weight;
		p = p * 2.03 + vec2(1.7, 9.2);
		weight *= 0.5;
	}
	return sum;
}

void fragment() {
	vec2 at = (place.xz + wind * TIME) * scale;
	float n = fbm(at) + fbm(at * 2.7 - TIME * 0.004) * 0.35;
	// (more of the sky is cloud as it clouds over; heavy cloud is darker underneath)
	float edge = mix(0.78, 0.25, cover);
	float thick = smoothstep(edge, edge + 0.22, n);
	float under = mix(0.82, 0.42, cover * thick);
	// (thinning out far off, where the sky's own haze takes over)
	float far = 1.0 - smoothstep(1200.0, 4500.0, length(place.xz - CAMERA_POSITION_WORLD.xz));
	ALBEDO = vec3(0.78, 0.8, 0.8) * under * light;
	ALPHA = thick * mix(0.55, 0.95, cover) * far;
}
"""

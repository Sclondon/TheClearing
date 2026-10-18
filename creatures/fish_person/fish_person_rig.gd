class_name FishPersonRig
extends CharacterRig
## How a fish person (creatures/fish_person/models/fish_person.glb) moves: the
## whole figure is posed here, over CharacterRig (see `_pose_extra`); nothing
## of the boy's walk is kept. Its body (`FishPerson`, fish_person.gd) is this
## node's parent and says how fast it is going (`velocity`), how awake it is
## (`awake`), how far down in the water it is (`sunk`), how hard it is
## breathing (`winded`) and what it is looking at (`aim`); and it starts the
## two things it does, `act(Act.CROAK)` and `act(Act.GRAB)`.
##
## - LURKING (awake 0) it squats on its heels, knees wide, its hands down
##   between its feet and its head up, as still as a stone but for its
##   breathing; `sunk` lowers it all into the ground (the water) until only
##   the crown of its head, its eyes and its fin show.
## - ABOUT (awake 1) it stands stooped, a hump of a back and its head thrust
##   forward, swaying, its webbed hands hanging loose before its knees. Its
##   head turns in sudden jerks and holds, as a fish's eye does, or tracks what
##   it is after. Walking it shambles: flat feet slapped down, toes flopping as
##   they lift, a lurch forward onto each step and one leg dragging, the head
##   nodding with every step. Driven fast it lopes: bent right over, long
##   bounding strides, its arms swinging low and clawing, its mouth open.
## - IT BREATHES: its mouth gulps and its gills flare out between gulps, slowly
##   while it stands, fast when it is winded, a steady pumping as it lopes.
## - THE CROAK: it draws itself up, throat and chest swelling, mouth shut and
##   gills clamped (SWELL); then thrusts its head up and out and gapes as wide
##   as it can, gills flared and quivering, arms flung out low behind it with
##   the fingers spread, juddering with each pulse of the croak (CROAKING);
##   and sinks back (SUBSIDE).
## - THE GRAB: it gathers itself, hands drawn back and mouth opening (WIND);
##   throws itself forward with both arms out straight and fingers spread,
##   mouth gaping (LUNGE); the hands clamp shut (CLOSE: the moment it takes
##   hold, if anything is there); holding someone (`held`) it drags them to its
##   mouth, biting at the air by them (HOLD), else it is left clawing at
##   nothing; then it lets go and straightens (LET_GO).
##
## Its joints are the boy's (the same bone names), and three of its own that
## only it has: `jaw` and, each side, `gill0`..`gill2`.

enum Act { NONE, CROAK, GRAB }
enum Stage { NONE, SWELL, CROAKING, SUBSIDE, WIND, LUNGE, CLOSE, HOLD, LET_GO }

## Seconds each part of a croak and of a grab takes.
const SWELL := 0.45
const CROAKING := 1.25
const SUBSIDE := 0.5
const WIND := 0.3
const LUNGE := 0.22
const CLOSE := 0.16
const HOLD := 1.0
const LET_GO := 0.55
## One whole cycle of its shamble (two steps), in model units of ground, and
## the share of it each foot is off the ground; and the cycle of its lope.
const STRIDE := 0.7
const LOPE_STRIDE := 1.9
const SWING := 0.42
## The pulses of its croak, a second.
const CROAK_PULSES := 7.0

## How awake it is, 0 (lurking in a squat) to 1 (up and about). The body sets this.
var awake := 0.0
## How far down in the water it is, 0 (not at all) to 1 (to its eyes).
var sunk := 0.0
## How hard it is breathing, 0..1 (after a lope).
var winded := 0.0
## What it is after, in the world; INF for nothing.
var aim := Vector3.INF
## In a grab: whether it has hold of someone.
var held := false

var _doing := Act.NONE
var _doing_time := INF
var _wake := 0.0
var _cycle := 0.0
var _stride := STRIDE
var _trod := false
var _posed := false
var _was_at := Vector3.INF
var _yaw_was := 0.0
var _foot_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_to: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _foot_moving: Array[bool] = [false, false]
var _foot_swing: Array[float] = [-1.0, -1.0]
var _foot_began: Array[float] = [0.0, 0.0]
var _foot_lift: Array[float] = [0.0, 0.0]
var _foot_toes: Array[float] = [0.0, 0.0]
var _foot_turn: Array[float] = [0.0, 0.0]
var _was_swinging: Array[bool] = [false, false]
var _hand_at: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _hand_speed: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
## Which way its head is turned (to the side, down), and where it means to turn it.
var _gaze := Vector2.ZERO
var _glance := Vector2.ZERO
var _glance_in := 1.5
## Springs: (where, how fast).
var _rocking := Vector2.ZERO
var _nodding := Vector2.ZERO
var _lurch := Vector2.ZERO
## Its breath, round and round (0..1), and its croak's judder.
var _breathing := 0.0
var _judder := Vector3.ZERO
## Its own bones: the jaw, and the gill flaps (left 0..2, right 0..2), with
## each one's rest and the line it hinges on.
var _jaw_bone := -1
var _jaw_rest := Transform3D.IDENTITY
var _gill_bones: Array[int] = []
var _gill_rests: Array[Transform3D] = []
var _gill_axes: Array[Vector3] = []
var _gape := 0.0
var _flare := 0.0
## How far the figure is let down into the ground, model units.
var _drop := 0.0
## Spatters thrown up where its feet slap down.
var _splash: Dust

## The colours of its skin besides its back and sides (the model's "skin"):
## its belly, its fins and webs, its teeth and claws, and the dark of its hollows.
const BELLY := Color(0.37, 0.39, 0.31)
const FIN := Color(0.17, 0.22, 0.19)
const TOOTH := Color(0.8, 0.77, 0.62)
const CLAW := Color(0.1, 0.09, 0.08)
## The dark of its mouth and gills (nearly black, a little red in it), and its eyes (glassy, a sickly yellow).
const MAW := Color(0.1, 0.018, 0.022)
const EYE := Color(0.46, 0.4, 0.2)
const SHADE := Color(0.05, 0.075, 0.065)
## How soft the edge of the dark in its hollows is, in the model's cavity value (0..1).
const SHADE_SOFTNESS := 0.06
## How big its scales are (model units) and how dark their rims.
const SCALE_SIZE := 0.0085
const SCALE_DARK := 0.42
## How wet it looks: the strength of the light caught on it.
const WET := 0.3

const SKIN_SHADER := """
shader_type spatial;

uniform vec3 albedo : source_color = vec3(0.27, 0.33, 0.28);
uniform vec3 belly : source_color = vec3(0.6, 0.6, 0.48);
uniform vec3 fin : source_color = vec3(0.17, 0.22, 0.19);
uniform vec3 tooth : source_color = vec3(0.8, 0.77, 0.62);
uniform vec3 claw : source_color = vec3(0.1, 0.09, 0.08);
uniform vec3 maw : source_color = vec3(0.1, 0.018, 0.022);
uniform vec3 eye : source_color = vec3(0.46, 0.4, 0.2);
uniform vec3 shade : source_color = vec3(0.05, 0.075, 0.065);
uniform float softness = 0.06;
uniform float scale_size = 0.0115;
uniform float scale_dark = 0.42;
uniform float wet = 0.55;
uniform float gloss = 70.0;
uniform float wrap = 0.0;
uniform float flatness = 0.65;
uniform float rim_gain = 0.32;
uniform float rim_width = 0.16;

// Where each point was as modelled (so that its scales stay put as it moves),
// which way it faced, and its paint (the model's vertex colour: r how far it
// lies in a hollow, g how pale it is, b what it is).
varying vec3 rest;
varying vec3 rest_normal;
// How much of a scale's rim a point is on (fragment to light: it breaks the sheen).
varying float rim_here;
// Which scale it is (0..1): only some catch the light, so the gleam on it glitters.
varying float tone_here;
// How much of an eye a point is (its gleam is bright).
varying float glassy;

void vertex() {
	rest = vec3(UV.x, UV2.x, 1.0 - UV.y);
	rest_normal = NORMAL;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float bumps(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash(i.xy + i.z * 17.0), hash(i.xy + vec2(1.0, 0.0) + i.z * 17.0), f.x);
	float b = mix(hash(i.xy + vec2(0.0, 1.0) + i.z * 17.0), hash(i.xy + vec2(1.0, 1.0) + i.z * 17.0), f.x);
	float c = mix(hash(i.xy + (i.z + 1.0) * 17.0), hash(i.xy + vec2(1.0, 0.0) + (i.z + 1.0) * 17.0), f.x);
	float d = mix(hash(i.xy + vec2(0.0, 1.0) + (i.z + 1.0) * 17.0), hash(i.xy + vec2(1.0, 1.0) + (i.z + 1.0) * 17.0), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

// Scales laid in rows like roof tiles, each row overlapping the one below it
// by its free lower edge: (how far into the rim of the scale showing at p a
// point is, 0 in its middle to 1 at its edge; a number for which scale it is).
vec2 scales(vec2 p) {
	float r0 = floor(p.y);
	for (int up = 1; up >= 0; up--) {
		float row = r0 + float(up);
		float shift = mod(row, 2.0) * 0.5;
		float column = floor(p.x - shift + 0.5) + shift;
		for (int k = -1; k <= 1; k++) {
			vec2 centre = vec2(column + float(k), row);
			vec2 d = p - centre;
			d.y *= 1.2;
			float far = length(d);
			if (far < 0.74 && (up == 0 || d.y < 0.0)) {
				return vec2(far / 0.74, hash(centre));
			}
		}
	}
	return vec2(0.0, 0.5);
}

void fragment() {
	vec4 paint = COLOR;
	float pale = smoothstep(0.42, 0.58, paint.g + (bumps(rest * 90.0) - 0.5) * 0.12);
	float scaled = 1.0 - smoothstep(0.15, 0.25, paint.b);
	float finned = smoothstep(0.55, 0.6, paint.b) * (1.0 - smoothstep(0.8, 0.85, paint.b));
	float hard = smoothstep(0.85, 0.9, paint.b);
	vec3 colour = mix(albedo, belly, pale);
	// (dark mottling over its back and sides)
	float mottle = smoothstep(0.58, 0.68, bumps(rest * 34.0) * 0.7 + bumps(rest * 9.0) * 0.3);
	colour *= 1.0 - 0.14 * mottle * (1.0 - pale);
	colour = mix(colour, fin * (0.85 + 0.3 * bumps(rest * 60.0)), finned);
	// (what is hard is told apart by its g: a claw or pupil, the dark of its mouth, an eye, a tooth)
	vec3 solid = mix(claw, maw, smoothstep(0.15, 0.2, paint.g));
	solid = mix(solid, eye, smoothstep(0.45, 0.5, paint.g));
	solid = mix(solid, tooth, smoothstep(0.8, 0.85, paint.g));
	colour = mix(colour, solid, hard);
	glassy = hard * smoothstep(0.45, 0.5, paint.g) * (1.0 - smoothstep(0.8, 0.85, paint.g));
	// Its scales, laid over it three ways and blended by which way it faces,
	// fading out where they are too small to see.
	vec3 at = rest / scale_size;
	float pixel = length(fwidth(at));
	float near = 1.0 - smoothstep(0.22, 0.45, pixel);
	float rim = 0.0;
	float tone = 0.5;
	if (near * scaled > 0.01) {
		vec3 w = pow(abs(normalize(rest_normal)), vec3(4.0));
		w /= w.x + w.y + w.z;
		vec2 sx = scales(vec2(at.z * sign(rest_normal.x), at.y));
		vec2 sz = scales(vec2(at.x * sign(rest_normal.z), at.y));
		vec2 sy = scales(vec2(at.x, at.z));
		rim = sx.x * w.x + sz.x * w.z + sy.x * w.y;
		tone = sx.y * w.x + sz.y * w.z + sy.y * w.y;
	}
	float edge = smoothstep(0.62, 0.95, rim) * near * scaled * (1.0 - 0.55 * pale);
	colour *= 1.0 - scale_dark * edge;
	// (each scale a shade apart, and lighter just inside its rim)
	colour *= 1.0 + ((tone - 0.5) * 0.14 + smoothstep(0.3, 0.6, rim) * (1.0 - edge) * 0.06) * near * scaled;
	rim_here = edge;
	tone_here = mix(0.5, tone, near * scaled);
	float sunk = smoothstep(0.5 - softness - fwidth(paint.r), 0.5 + softness + fwidth(paint.r), paint.r);
	ALBEDO = mix(colour, shade, sunk);
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
	float amount = facing * smoothstep(0.15, 0.6, reach);
	float lit = cut(amount, 0.04);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	// Wet: a hard bright gleam where the light glances off it (broken up by
	// the rims of its scales), and a sheen along its edges.
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = cut(graze, 1.0 - rim_width) * lit;
	float glint = pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), gloss);
	float shine = cut(glint, 0.5) * lit * (1.0 - 0.75 * rim_here) * smoothstep(0.2, 0.55, tone_here);
	// (its eyes are wetter still: a small hard spot of light that is there from any side)
	float spot = cut(pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), 40.0), 0.5) * glassy;
	shine = max(shine, spot * 2.5);
	SPECULAR_LIGHT += (rim * rim_gain * ALBEDO + shine * wet * vec3(0.85, 0.92, 0.88)) * strength * LIGHT_COLOR / PI;
}
"""

static var _skin_shader: Shader


## Shades it as CharacterRig does (Toon), but its skin with its own shader
## (`skin_material`): paler on its belly, scaled, mottled, wet.
func restyle() -> void:
	super()
	if not cel_shaded:
		return
	for part: MeshInstance3D in _figure.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var original := part.mesh.surface_get_material(surface) as StandardMaterial3D
			if original and original.resource_name == "skin":
				part.set_surface_override_material(surface, skin_material(original.albedo_color))


static func skin_material(colour: Color) -> ShaderMaterial:
	if _skin_shader == null:
		_skin_shader = Shader.new()
		_skin_shader.code = SKIN_SHADER
	var material := ShaderMaterial.new()
	material.shader = _skin_shader
	material.set_shader_parameter(&"albedo", colour)
	material.set_shader_parameter(&"belly", BELLY)
	material.set_shader_parameter(&"fin", FIN)
	material.set_shader_parameter(&"tooth", TOOTH)
	material.set_shader_parameter(&"claw", CLAW)
	material.set_shader_parameter(&"maw", MAW)
	material.set_shader_parameter(&"eye", EYE)
	material.set_shader_parameter(&"shade", SHADE)
	material.set_shader_parameter(&"softness", SHADE_SOFTNESS)
	material.set_shader_parameter(&"scale_size", SCALE_SIZE)
	material.set_shader_parameter(&"scale_dark", SCALE_DARK)
	material.set_shader_parameter(&"wet", WET)
	return material


func _build() -> void:
	dusty = false
	super()
	_jaw_bone = _skeleton.find_bone(&"jaw")
	if _jaw_bone >= 0:
		_jaw_rest = _skeleton.get_bone_rest(_jaw_bone)
	for suffix: String in ["_l", "_r"]:
		for k in 3:
			var bone := _skeleton.find_bone("gill%d%s" % [k, suffix])
			if bone < 0:
				continue
			_gill_bones.append(bone)
			_gill_rests.append(_skeleton.get_bone_rest(bone))
			# (each flap hinges along its front edge, which runs down and a little forward)
			var line := Vector3(0.0, -0.95, 0.31 - 0.02 * k).normalized()
			_gill_axes.append(line * (1.0 if suffix == "_l" else -1.0))
	# (the boy's footfalls are not its own: its flat feet slap down and splash)
	_splash = Dust.new()
	add_child(_splash)
	var disc := _splash.multimesh.mesh as QuadMesh if _splash.multimesh else null
	if disc and disc.material is ShaderMaterial:
		(disc.material as ShaderMaterial).set_shader_parameter(&"tint", Color(0.36, 0.37, 0.34))
	_breathing = randf()
	settle()


## Stands it still as it is, nothing in motion: for when it is put somewhere.
func settle() -> void:
	_doing = Act.NONE
	_doing_time = INF
	_cycle = 0.0
	_wake = awake
	_posed = false
	_was_at = Vector3.INF
	_yaw_was = rotation.y
	_rocking = Vector2.ZERO
	_nodding = Vector2.ZERO
	_lurch = Vector2.ZERO
	for i in 2:
		_foot_at[i] = _standing(i)
		_foot_moving[i] = false
		_foot_swing[i] = -1.0


## Begins a croak or a grab (anything it was doing is cut short).
func act(what: Act) -> void:
	_doing = what
	_doing_time = 0.0 if what != Act.NONE else INF
	held = false


func act_length(what: Act) -> float:
	match what:
		Act.CROAK:
			return SWELL + CROAKING + SUBSIDE
		Act.GRAB:
			return WIND + LUNGE + CLOSE + HOLD + LET_GO
	return 0.0


## How far into what it is doing it is, seconds (INF: doing nothing).
func act_time() -> float:
	return _doing_time


func stage() -> Stage:
	var t := _doing_time if _doing != Act.NONE else 0.0
	match _doing:
		Act.CROAK:
			if t < SWELL:
				return Stage.SWELL
			if t < SWELL + CROAKING:
				return Stage.CROAKING
			if t < SWELL + CROAKING + SUBSIDE:
				return Stage.SUBSIDE
		Act.GRAB:
			if t < WIND:
				return Stage.WIND
			if t < WIND + LUNGE:
				return Stage.LUNGE
			if t < WIND + LUNGE + CLOSE:
				return Stage.CLOSE
			if t < WIND + LUNGE + CLOSE + HOLD:
				return Stage.HOLD
			if t < WIND + LUNGE + CLOSE + HOLD + LET_GO:
				return Stage.LET_GO
	return Stage.NONE


## How far the figure is let down into the ground now (model units).
func drop() -> float:
	return _drop


## Where a foot stands when it is going nowhere: wide, toes turned out.
func _standing(i: int) -> Vector3:
	var side := 1.0 if i == 0 else -1.0
	return Vector3((_hip_width + 0.03) * side, 0.0, 0.015 if i == 0 else -0.02)


static func _sprung(spring: Vector2, to: float, stiffness: float, damping: float, delta: float) -> Vector2:
	spring.y += ((to - spring.x) * stiffness - spring.y * damping) * delta
	spring.x += spring.y * delta
	return spring


func _pose_extra(delta: float) -> void:
	var turned := angle_difference(_yaw_was, rotation.y)
	_yaw_was = rotation.y
	_wake = _approach(_wake, awake, 2.5, delta)
	if _doing != Act.NONE:
		_doing_time += delta
		if _doing_time >= act_length(_doing):
			_doing = Act.NONE
			_doing_time = INF
	var t := _doing_time if _doing != Act.NONE else 0.0
	var going := _gone(delta)
	var speed := going.length()
	var go := clampf(speed / 0.3, 0.0, 1.0) * (1.0 - _air)

	# How far into each of the things it does, 0..1, rising and falling.
	var swell := 0.0
	var croak := 0.0
	var wind := 0.0
	var lunge := 0.0
	var closed := 0.0
	var clinging := 0.0
	if _doing == Act.CROAK:
		swell = smoothstep(0.0, SWELL, t) * (1.0 - smoothstep(SWELL, SWELL + 0.15, t))
		croak = smoothstep(SWELL - 0.05, SWELL + 0.12, t) * (1.0 - smoothstep(SWELL + CROAKING - 0.1, act_length(Act.CROAK), t))
	elif _doing == Act.GRAB:
		var out := 1.0 - smoothstep(WIND + LUNGE + CLOSE + HOLD, act_length(Act.GRAB), t)
		wind = smoothstep(0.0, WIND * 0.8, t) * (1.0 - smoothstep(WIND, WIND + LUNGE * 0.6, t))
		lunge = smoothstep(WIND * 0.7, WIND + LUNGE * 0.7, t) * out
		closed = smoothstep(WIND + LUNGE * 0.8, WIND + LUNGE + CLOSE, t) * out
		clinging = closed * (1.0 if held else 0.0)
	# (lurking, it squats; and it is down there in the water)
	var squat := clampf(maxf(1.0 - _wake, sunk), 0.0, 1.0) * (1.0 - maxf(croak, lunge))

	# Loping, its strides lengthen and lift and it bends right over.
	var lope := smoothstep(1.2, 2.4, speed)
	_stride = lerpf(STRIDE, LOPE_STRIDE, lope)
	_tread(going, turned, go * (1.0 - squat), delta)
	_shape_steps(go, lope, delta)

	# Its breath: a gulp of the mouth, then the gills flare as it shuts.
	var rate := lerpf(0.32, 1.25, maxf(winded, lope * 0.8)) * (0.6 if sunk > 0.5 else 1.0)
	_breathing = fposmod(_breathing + rate * delta, 1.0)
	var gulp := smoothstep(0.0, 0.25, _breathing) * (1.0 - smoothstep(0.3, 0.5, _breathing))
	var pump := smoothstep(0.38, 0.55, _breathing) * (1.0 - smoothstep(0.75, 0.98, _breathing))

	# --- The body ---
	var swing_side := sin(_cycle * TAU)
	var idle := (1.0 - go) * _wake * (1.0 - squat)
	var sway := sin(_time * 1.85) * 0.05 * idle + sin(_time * 0.7 + 1.0) * 0.025 * idle
	_rocking = _sprung(_rocking, go * swing_side * (0.14 - 0.06 * lope) + sway, 60.0, 6.0, delta)
	_nodding = _sprung(_nodding, go * (0.05 + 0.06 * absf(swing_side)) * (1.0 - lope), 50.0, 5.0, delta)
	# (a lurch forward onto each step, heavier on its left, as if the other leg dragged)
	for i in 2:
		var swinging := _foot_swing[i] >= 0.0
		if _was_swinging[i] and not swinging and go > 0.2:
			_lurch.y += (0.9 if i == 0 else 0.45) * (1.0 - lope * 0.6)
			if _splash and sunk < 0.1:
				_splash.puff(to_global(_foot_at[i] + Vector3(0.0, 0.01, 0.08)), Vector3.ZERO, 0.11 * global_basis.get_scale().y * (1.0 + lope), 2, 0.6)
		_was_swinging[i] = swinging
	_lurch = _sprung(_lurch, 0.0, 70.0, 9.0, delta)
	# Croaking it judders with each pulse.
	var pulse := maxf(sin(t * TAU * CROAK_PULSES), 0.0) * croak if _doing == Act.CROAK else 0.0
	_judder = _judder.lerp(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * croak, 1.0 - exp(-30.0 * delta))

	var hunch := lerpf(0.55, 0.62, _wake) + 0.85 * lope + 0.25 * squat - 0.55 * swell - 0.35 * croak + 0.35 * wind + 0.5 * lunge - 0.15 * closed + 0.08 * pump * idle
	var bend := 0.07 + 0.16 * lope + 0.4 * squat + 0.05 * wind - 0.02 * swell
	var height := _hip_height - bend - (0.018 + 0.02 * lope) * absf(swing_side) * go + 0.03 * swell
	_hips.position = Vector3(_rocking.x * 0.14 + _judder.x * 0.004 * croak, height, -0.04 * squat + 0.12 * lunge - 0.05 * wind + 0.03 * clinging + 0.02 * _lurch.x)
	_hips.rotation = Vector3(hunch * 0.28 + _nodding.x * 0.6 + _lurch.x * 0.12, 0.0, -_rocking.x * 0.5)
	_spine.rotation = Vector3(hunch * 0.3 + _lurch.x * 0.1 + _judder.y * 0.03 * croak, _rocking.x * 0.35, _rocking.x * 0.3)
	_chest.rotation = Vector3(hunch * 0.42 - 0.1 * pulse + _judder.x * 0.04 * croak, -_rocking.x * 0.25, _rocking.x * 0.25 + _judder.z * 0.03 * croak)

	# Its head: up and out to look ahead whatever its back is doing; jerking
	# about from one thing to the next, or on what it is after; thrust up to croak.
	_watch_about(delta)
	var level := -(hunch * 1.0 + _nodding.x * 0.6 + _lurch.x * 0.22)
	var look := _gaze * (1.0 - croak)
	var thrust := -0.5 * croak + 0.35 * swell + 0.1 * pulse
	var nod := _nodding.x * 0.8 + _lurch.x * 0.15 + 0.08 * lope
	_neck.rotation = Vector3(level * 0.35 + thrust * 0.5 + look.y * 0.4 + nod * 0.4 - 0.1 * squat, look.x * 0.45, -_rocking.x * 0.5 + _judder.z * 0.05 * croak)
	_head.rotation = Vector3(level * 0.65 + 0.1 + thrust * 0.5 + look.y * 0.6 + nod * 0.5 - 0.15 * squat + 0.1 * clinging * sin(_time * 8.0), look.x * 0.55, -_rocking.x * 0.4 + _judder.x * 0.06 * croak)

	_stand_legs(0.18 + 0.55 * squat + 0.08 * lope)
	_arms(go, lope, squat, swell, croak, pulse, wind, lunge, closed, clinging, delta)

	# The jaw and the gills.
	var gape := 0.07 + 0.2 * gulp * _wake + 0.06 * gulp
	gape = lerpf(gape, 0.38 + 0.08 * sin(_time * 9.0), lope)
	gape = lerpf(gape, 0.03, swell)
	gape = lerpf(gape, 0.95 + 0.12 * pulse - 0.06 * sin(t * 37.0), croak)
	gape = lerpf(gape, 0.45, wind)
	gape = lerpf(gape, 1.0, lunge * (1.0 - closed))
	gape = lerpf(gape, 0.25 + 0.45 * absf(sin(_time * 7.0)), clinging)
	gape *= 1.0 - 0.5 * squat * sunk
	_gape = _approach(_gape, gape, 18.0, delta)
	var flare := 0.12 + 0.55 * pump
	flare = lerpf(flare, 0.55 + 0.3 * sin(_time * 15.0), lope)
	flare = lerpf(flare, 0.0, swell)
	flare = lerpf(flare, 0.95 + 0.12 * sin(_time * 41.0), croak)
	flare = lerpf(flare, 0.7, lunge)
	_flare = _approach(_flare, flare, 14.0, delta)
	_pose_own_bones()

	# Down in the water: the whole of it let down until only its eyes are out.
	var eyes := to_local(_head.global_transform * Vector3(0.0, 0.1, 0.09)).y
	var under := smoothstep(0.0, 1.0, sunk)
	_drop = maxf(eyes - 0.012, 0.0) * under
	position.y = -_drop
	_posed = true


## Poses the jaw and the gill flaps, which CharacterRig knows nothing of.
func _pose_own_bones() -> void:
	if _jaw_bone >= 0:
		_skeleton.set_bone_pose(_jaw_bone, Transform3D(Basis(Vector3.RIGHT, _gape), _jaw_rest.origin))
	for k in _gill_bones.size():
		# (the back flaps lift furthest)
		var angle := _flare * (0.55 + 0.15 * (k % 3))
		_skeleton.set_bone_pose(_gill_bones[k], Transform3D(Basis(_gill_axes[k], angle), _gill_rests[k].origin))


## Shapes the steps `_tread` takes into a shamble: the foot lifted low and
## flopping, slapped down flat; a lope lifts it high.
func _shape_steps(go: float, lope: float, _delta: float) -> void:
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		_foot_turn[i] = side * 0.3
		if _foot_swing[i] >= 0.0:
			var s := _foot_swing[i]
			# (its right leg drags: lifted less, the toes trailing)
			var drag := 0.0 if i == 0 else 1.0
			_foot_lift[i] = sin(PI * s) * lerpf(0.05 - 0.025 * drag, 0.14, lope)
			# The webbed toes flop down as the foot lifts, and come up flat to slap down.
			_foot_toes[i] = (0.35 + 0.25 * drag) * sin(PI * minf(s * 1.3, 1.0)) - 0.15 * smoothstep(0.75, 0.95, s)
		else:
			_foot_lift[i] = 0.0
			_foot_toes[i] = 0.0
	for i in 2:
		_foot_at[i] = _foot_at[i].lerp(_standing(i), _air)
		_foot_lift[i] = lerpf(_foot_lift[i], 0.05, _air)


func _arms(go: float, lope: float, squat: float, swell: float, croak: float, pulse: float, wind: float, lunge: float, closed: float, clinging: float, delta: float) -> void:
	var mark := Vector3(0.0, 0.9, 1.5)
	if aim.is_finite():
		mark = to_local(aim)
	var near := clampf(1.0 - (Vector2(mark.x, mark.z).length() - 0.9) / 2.0, 0.0, 1.0) * arms_reach * _wake
	var reach_line := _upper_arm + _forearm
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var shoulder := to_local(_shoulders[i].global_position)
		var phase := _cycle * TAU + (0.0 if i == 0 else PI)
		# Hanging loose before its knees, swinging a little as it shambles.
		var hanging := shoulder + Vector3(side * 0.035, -reach_line + 0.05, 0.08 + sin(phase) * 0.07 * go)
		# Loping: swung low, forward and back, clawing at the ground ahead.
		var loping := shoulder + Vector3(side * 0.09, -reach_line * 0.78, 0.1 + sin(phase) * 0.3)
		var goal := hanging.lerp(loping, lope)
		# After someone close: held out, fingers working.
		var out := shoulder + Vector3(side * 0.12, -0.3 + 0.05 * side * sin(_time * 1.3), 0.45)
		goal = goal.lerp(out, near * (1.0 - lope))
		# Squatting: down between its knees, the hands on the ground before its feet.
		var down := Vector3(side * 0.1, 0.02, 0.2)
		goal = goal.lerp(down, squat)
		# Croaking: flung out low behind it, quivering.
		var flung := shoulder + Vector3(side * 0.42, -0.36, -0.12) + _judder * 0.02 + Vector3(0.0, 0.02 * pulse, 0.0)
		goal = goal.lerp(shoulder + Vector3(side * 0.2, -0.45, -0.02), swell).lerp(flung, croak)
		# The grab: drawn back, then thrown forward at it, then clamped together.
		var low := clampf(mark.y - shoulder.y, -0.55, 0.05)
		var drawn := shoulder + Vector3(side * 0.2, -0.16, -0.1)
		var thrown := shoulder + Vector3(side * 0.16, low * 0.6, reach_line * 0.92)
		var clamped := shoulder + Vector3(side * 0.07, low * 0.6, reach_line * 0.8)
		if clinging > 0.0:
			clamped = clamped.lerp(shoulder + Vector3(side * 0.1, low * 0.5, 0.36), clinging * smoothstep(0.0, 0.4, _doing_time - WIND - LUNGE - CLOSE))
		goal = goal.lerp(drawn, wind).lerp(thrown, lunge * (1.0 - closed)).lerp(clamped, closed)
		var stiff := 22.0 + 160.0 * maxf(maxf(lunge, croak), maxf(wind, squat))
		_hand_follow(i, goal, stiff, 5.0 + 12.0 * maxf(lunge, croak), delta)
		var pole := Vector3(side * 0.7, -0.4, -0.7).lerp(Vector3(side * 0.9, -0.1, -0.3), lope).lerp(Vector3(side, 0.3, -0.5), squat).lerp(Vector3(side * 0.8, -0.6, 0.2), croak).lerp(Vector3(side * 0.9, 0.1, -0.3), lunge)
		_hinge_arm(i, to_global(_hand_at[i]), (global_basis * pole).normalized())
		# The hands: loose and half curled; splayed wide to croak and to grab, then clamped.
		var curl := lerpf(0.45, 0.3, _wake) + 0.15 * lope + 0.2 * squat
		curl = lerpf(curl, -0.15, maxf(croak, lunge * (1.0 - closed)))
		curl = lerpf(curl, 1.25, closed)
		var splay := 1.0 + 0.25 * lope + 0.45 * maxf(croak, lunge * (1.0 - closed)) - 0.3 * closed
		var wrist := 0.15 + 0.2 * lope - 0.5 * croak + 0.3 * lunge - 0.6 * squat + 0.05 * sin(_time * 2.0 + i)
		_set_hand(i, curl, splay, wrist)


## Turns `_gaze` towards `aim` if it has one, or now and then, in a jerk, somewhere else.
func _watch_about(delta: float) -> void:
	var height := _hip_height + 0.55
	if aim.is_finite() and _wake > 0.5:
		var to := to_local(aim) - Vector3(0.0, height, 0.0)
		_glance = Vector2(clampf(atan2(to.x, to.z), -1.1, 1.1), clampf(-atan2(to.y, Vector2(to.x, to.z).length()), -0.6, 0.6))
		_glance_in = 0.6
	else:
		_glance_in -= delta
		if _glance_in <= 0.0:
			_glance_in = randf_range(1.2, 4.0)
			_glance = Vector2(randf_range(-0.75, 0.75), randf_range(-0.15, 0.2)) * lerpf(0.4, 1.0, _wake)
	# (quick to turn, and then still: a fish's way of looking)
	_gaze = _gaze.lerp(_glance, 1.0 - exp(-9.0 * delta))


# --- Shared with the ghoul's rig (creatures/ghoul/ghoul_rig.gd) ---

## Steps with each leg in turn: a whole cycle is `_stride` long and each foot
## is off the ground for SWING of it.
func _tread(going: Vector3, turned: float, go: float, delta: float) -> void:
	var speed := going.length()
	_cycle = fposmod(_cycle + speed / _stride * delta, 1.0)
	var walking := (go > 0.15 or speed > 0.08) and speed > 0.02
	var ahead := going / maxf(speed, 0.0001)
	if walking and not _trod:
		_cycle = 0.0 if _foot_at[0].dot(ahead) <= _foot_at[1].dot(ahead) else 0.5
	_trod = walking
	var tether := _stride * (1.0 - SWING) * 0.5 + 0.18
	var width := _hip_width + 0.03
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		_foot_at[i] = (_foot_at[i] - going * delta).rotated(Vector3.UP, -turned)
		var home := Vector3(side * width, 0.0, 0.0)
		if _foot_at[i].distance_to(home) > tether:
			_foot_at[i] = home + (_foot_at[i] - home).normalized() * tether
		var p := fposmod(_cycle - 0.5 * i, 1.0)
		var stepping := walking and p < SWING and (_foot_moving[i] or p < SWING * 0.8)
		if stepping and not _foot_moving[i]:
			_foot_began[i] = p
			_foot_from[i] = _foot_at[i]
			_foot_to[i] = home + ahead * _stride * (1.0 - SWING) * 0.5
		_foot_moving[i] = stepping
		var s := (p - _foot_began[i]) / maxf(SWING - _foot_began[i], 0.0001)
		_foot_swing[i] = s if stepping else -1.0
		if stepping:
			_foot_at[i] = _foot_from[i].lerp(_foot_to[i] + ahead * (SWING - p) * _stride, s * s * (3.0 - 2.0 * s))
	if not walking:
		for i in 2:
			var home := _standing(i)
			var off := _foot_at[i].distance_to(home)
			_foot_at[i] = _foot_at[i].lerp(home, 1.0 - exp(-(4.0 if off > 0.04 else 0.0) * delta)) if _posed else home
			_foot_swing[i] = -1.0
			_foot_moving[i] = false


## Puts each leg to its foot; the knees `spread` apart from the way the feet point.
func _stand_legs(spread: float) -> void:
	var to_hips := _hips.transform.affine_inverse()
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var toes := _foot_toes[i]
		var target := Vector3(_foot_at[i].x, _foot_lift[i], _foot_at[i].z) + _ankle_offset(toes)
		var foot := Basis(Vector3.UP, _foot_turn[i]) * Basis(Vector3.RIGHT, toes)
		_toes[i].rotation.x = lerpf(-maxf(toes, 0.0) * 0.4, 0.3, smoothstep(0.0, 0.03, _foot_lift[i]))
		_solve_leg(i, side, to_hips * target, (to_hips.basis * foot).orthonormalized(), _foot_turn[i] * 0.8 + side * spread)


## How fast it is really going in its own space, from where it was a frame ago.
func _gone(delta: float) -> Vector3:
	var here := global_position
	var moved := here - _was_at if _was_at.is_finite() else Vector3.ZERO
	_was_at = here
	moved.y = 0.0
	if moved.length() > 0.5 * global_basis.get_scale().y:
		moved = Vector3.ZERO
	return global_basis.inverse() * moved / maxf(delta, 0.0001)


## Turns an arm to put its wrist at `point` (world), the elbow towards `pole`.
func _hinge_arm(i: int, point: Vector3, pole: Vector3) -> void:
	var shoulder := _shoulders[i]
	var from := shoulder.global_position
	var to := point - from
	var size := global_basis.get_scale().y
	var upper_length := _upper_arm * size
	var fore_length := _forearm * size
	var reach := clampf(to.length(), 0.1 * size, upper_length + fore_length - 0.005 * size)
	var direction := to.normalized() if to.length_squared() > 0.000001 else Vector3.DOWN
	var hinge := direction.cross(pole)
	hinge = hinge.normalized() if hinge.length_squared() > 0.0001 else global_basis.x.normalized()
	var angle := acos(clampf((upper_length * upper_length + reach * reach - fore_length * fore_length) / (2.0 * upper_length * reach), -1.0, 1.0))
	var upper_direction := direction.rotated(hinge, angle)
	var fore_direction := (from + direction * reach - (from + upper_direction * upper_length)).normalized()
	var parent := (shoulder.get_parent() as Node3D).global_basis.orthonormalized()
	shoulder.basis = parent.inverse() * Basis(hinge, -upper_direction, hinge.cross(-upper_direction))
	var upper := shoulder.global_basis.orthonormalized()
	_elbows[i].basis = upper.inverse() * Basis(hinge, -fore_direction, hinge.cross(-fore_direction))


func _hand_follow(i: int, goal: Vector3, stiffness: float, damping: float, delta: float) -> void:
	_hand_speed[i] += ((goal - _hand_at[i]) * stiffness - _hand_speed[i] * damping) * delta
	_hand_at[i] += _hand_speed[i] * delta
	if not _posed:
		_hand_at[i] = goal
		_hand_speed[i] = Vector3.ZERO


func _set_hand(i: int, curl: float, splay: float, wrist: float) -> void:
	_hands[i].rotation = Vector3(wrist, 0.0, 0.0)
	_curl[i] = curl
	_splay[i] = splay
	_pose_fingers(i, 1.0 if i == 0 else -1.0)

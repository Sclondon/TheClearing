class_name AlienModel
## The grey's body, made in code: a Skeleton3D and one skinned mesh on it, so a
## whole alien is one draw (and its shadow). AlienBody (alien_body.gd) poses it.
##
## He is 2.3 m tall and thin as a rail: a huge smooth cranium on a long thin
## neck, a small pointed chin, great black almond eyes slanting up and round the
## sides of the face, a slit of a mouth; a narrow chest, a waist thinner still,
## arms that hang to his knees and end in three long fingers with round pads,
## legs like sticks. No clothes, nothing on him: pale grey skin all over.
##
## Every part is a tube lofted along its bone (or, the head, a sphere pulled into
## shape), skinned to that bone and blended into the next across each joint, so
## he bends smoothly. The colours are vertex colours: skin, the eyes (whose
## alpha is 0, which the shader reads as wet and shiny), the mouth.
##
## Model space: his feet on the ground at the origin, facing +Z, his left at +X.
## Every bone's rest is a plain offset from its parent (no rotation), so a
## bone's pose rotation is also its turn from standing as modelled.

## Every bone: name, parent, and where its joint is in model space as modelled.
## (Parents come before their children.)
const BONES := [
	["hips", "", Vector3(0.0, 1.1, 0.0)],
	["spine", "hips", Vector3(0.0, 1.22, -0.01)],
	["chest", "spine", Vector3(0.0, 1.46, -0.02)],
	["neck", "chest", Vector3(0.0, 1.69, -0.035)],
	["head", "neck", Vector3(0.0, 1.9, -0.02)],
	["upper_arm_l", "chest", Vector3(0.165, 1.655, -0.035)],
	["forearm_l", "upper_arm_l", Vector3(0.215, 1.3, -0.03)],
	["hand_l", "forearm_l", Vector3(0.245, 0.95, -0.01)],
	["finger_l_0_1", "hand_l", Vector3(0.255, 0.86, 0.022)],
	["finger_l_0_2", "finger_l_0_1", Vector3(0.262, 0.745, 0.04)],
	["finger_l_1_1", "hand_l", Vector3(0.262, 0.86, -0.012)],
	["finger_l_1_2", "finger_l_1_1", Vector3(0.276, 0.74, -0.022)],
	["finger_l_2_1", "hand_l", Vector3(0.232, 0.895, 0.04)],
	["finger_l_2_2", "finger_l_2_1", Vector3(0.236, 0.815, 0.078)],
	["upper_arm_r", "chest", Vector3(-0.165, 1.655, -0.035)],
	["forearm_r", "upper_arm_r", Vector3(-0.215, 1.3, -0.03)],
	["hand_r", "forearm_r", Vector3(-0.245, 0.95, -0.01)],
	["finger_r_0_1", "hand_r", Vector3(-0.255, 0.86, 0.022)],
	["finger_r_0_2", "finger_r_0_1", Vector3(-0.262, 0.745, 0.04)],
	["finger_r_1_1", "hand_r", Vector3(-0.262, 0.86, -0.012)],
	["finger_r_1_2", "finger_r_1_1", Vector3(-0.276, 0.74, -0.022)],
	["finger_r_2_1", "hand_r", Vector3(-0.232, 0.895, 0.04)],
	["finger_r_2_2", "finger_r_2_1", Vector3(-0.236, 0.815, 0.078)],
	["thigh_l", "hips", Vector3(0.088, 1.06, 0.0)],
	["shin_l", "thigh_l", Vector3(0.098, 0.57, 0.012)],
	["foot_l", "shin_l", Vector3(0.1, 0.075, -0.012)],
	["thigh_r", "hips", Vector3(-0.088, 1.06, 0.0)],
	["shin_r", "thigh_r", Vector3(-0.098, 0.57, 0.012)],
	["foot_r", "shin_r", Vector3(-0.1, 0.075, -0.012)],
]
## Where each fingertip ends (model space), finger by finger as in BONES.
const TIPS := {
	"finger_l_0_2": Vector3(0.266, 0.655, 0.056),
	"finger_l_1_2": Vector3(0.286, 0.65, -0.03),
	"finger_l_2_2": Vector3(0.238, 0.74, 0.1),
}
## The cranium: its middle (model space) and its half sizes (side, up, front, back).
const SKULL := Vector3(0.0, 2.075, -0.02)
const SKULL_SIZE := Vector4(0.168, 0.205, 0.185, 0.215)
## How far down the face goes below the middle of the skull, to the chin.
const JAW := 0.215

const SKIN := Color(0.6, 0.61, 0.62, 1.0)
const EYE := Color(0.02, 0.022, 0.03, 0.0)
const MOUTH := Color(0.36, 0.35, 0.36, 1.0)

const SHADER := """
shader_type spatial;
render_mode cull_back;

// The skin and eyes are the vertex colours; COLOR.a 0 marks what shines (the eyes).
uniform float wrap = 0.25;
uniform float flatness = 0.7;
uniform float rim_gain = 0.35;
uniform float rim_width = 0.22;
uniform float highlight = 1.4;
uniform float gloss = 60.0;
// Blinking out and in: a white flash, and the body cut away in bands that run up it.
uniform vec3 flash_color : source_color = vec3(0.86, 0.92, 1.0);
uniform float flash = 0.0;
uniform float bands = 0.0;
uniform float band_rise = 0.0;

varying float shiny;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (bands > 0.0) {
		float line = fract(world.y * 9.0 - band_rise);
		if (line < bands) {
			discard;
		}
	}
	shiny = 1.0 - COLOR.a;
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	EMISSION = flash_color * flash;
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
	// (a third, darker band where the light only grazes: it gives the skull its roundness)
	float core = cut(amount, 0.42);
	float strength = mix(reach, 1.0, flatness);
	DIFFUSE_LIGHT += lit * mix(0.72, 1.0, core) * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = cut(graze, 1.0 - rim_width);
	float shine = cut(pow(max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0), gloss), 0.5);
	// The eyes catch the light whether the side they are on is lit or not: they are wet.
	SPECULAR_LIGHT += (rim * rim_gain * lit * ALBEDO * (1.0 - shiny) + shine * highlight * shiny + rim * 0.12 * shiny) * strength * LIGHT_COLOR / PI;
}
"""

var _st: SurfaceTool
var _index := {}
var _count := 0


## Makes a Skeleton3D with the bones and a MeshInstance3D child skinned to it.
## The mesh's material is a ShaderMaterial of SHADER (the body's flash and
## bands are its uniforms).
static func build() -> Skeleton3D:
	var maker := AlienModel.new()
	return maker._build()


func _build() -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton"
	for entry: Array in BONES:
		var bone := skeleton.add_bone(entry[0])
		_index[entry[0]] = bone
		var parent: int = _index.get(entry[1], -1)
		if parent >= 0:
			skeleton.set_bone_parent(bone, parent)
		var offset: Vector3 = entry[2] - (BONES[parent][2] if parent >= 0 else Vector3.ZERO)
		skeleton.set_bone_rest(bone, Transform3D(Basis.IDENTITY, offset))
	skeleton.reset_bone_poses()

	_st = SurfaceTool.new()
	_st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_torso()
	_neck()
	_head()
	for side in ["l", "r"]:
		_arm(side)
		_leg(side)
	_st.generate_normals()
	var mesh := _st.commit()
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	material.shader = shader
	mesh.surface_set_material(0, material)

	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = mesh
	skeleton.add_child(body)
	body.skeleton = NodePath("..")
	body.skin = skeleton.create_skin_from_rest_transforms()
	return skeleton


static func joint(bone: String) -> Vector3:
	for entry: Array in BONES:
		if entry[0] == bone:
			return entry[2]
	return TIPS.get(bone, Vector3.ZERO)


# --- Building ---

## One vertex: where, colour, and the two bones it follows (with how much of the second).
func _vertex(at: Vector3, color: Color, bone_a: String, bone_b := "", blend := 0.0) -> int:
	_st.set_color(color)
	var a: int = _index[bone_a]
	var b: int = _index[bone_b] if bone_b != "" else a
	blend = clampf(blend, 0.0, 1.0)
	if a == b or blend <= 0.0:
		_st.set_bones(PackedInt32Array([a, 0, 0, 0]))
		_st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
	elif blend >= 1.0:
		_st.set_bones(PackedInt32Array([b, 0, 0, 0]))
		_st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
	else:
		_st.set_bones(PackedInt32Array([a, b, 0, 0]))
		_st.set_weights(PackedFloat32Array([1.0 - blend, blend, 0.0, 0.0]))
	_st.add_vertex(at)
	_count += 1
	return _count - 1


## Joins rings of vertices (each `around` long, in order) into a skin of quads.
func _join(first: int, rings: int, around: int) -> void:
	for r in rings - 1:
		for i in around:
			var a := first + r * around + i
			var b := first + r * around + (i + 1) % around
			var c := a + around
			var d := b + around
			_st.add_index(a)
			_st.add_index(b)
			_st.add_index(c)
			_st.add_index(b)
			_st.add_index(d)
			_st.add_index(c)


## A tube from `a` to `b`. `rings` is a list of [t, width, depth] along it (t 0
## at `a`, 1 at `b`, may go a little past either; a size of 0 closes it to a
## point); `side` is the way its width lies. `weights(t)` gives [bone, bone, blend].
func _tube(a: Vector3, b: Vector3, rings: Array, side: Vector3, weights: Callable, around := 10, color := SKIN) -> void:
	var along := (b - a).normalized()
	var x := (side - along * side.dot(along)).normalized()
	var z := x.cross(along)
	rings = _capped(rings, a.distance_to(b))
	var first := _count
	for ring: Array in rings:
		var t: float = ring[0]
		var centre := a.lerp(b, t)
		var w: Array = weights.call(t)
		for i in around:
			var angle := TAU * i / around
			var at := centre + x * cos(angle) * float(ring[1]) + z * sin(angle) * float(ring[2])
			_vertex(at, color, w[0], w[1], w[2])
	_join(first, rings.size(), around)


## A tube's rings with each end that closes to a point (a ring of size 0)
## rounded off instead: a quarter circle of rings from the ring next to it.
static func _capped(rings: Array, length: float) -> Array:
	var out := rings.duplicate()
	for end in [0, 1]:
		var tip: Array = out[0] if end == 0 else out[out.size() - 1]
		if float(tip[1]) > 0.0:
			continue
		var next: Array = out[1] if end == 0 else out[out.size() - 2]
		var bulge := maxf(float(next[1]), float(next[2]))
		var cap := []
		for k in range(4, 0, -1):
			var angle := PI * 0.5 * k / 4.0
			var t := float(next[0]) + (-1.0 if end == 0 else 1.0) * bulge * 0.9 * sin(angle) / length
			cap.append([t, float(next[1]) * cos(angle), float(next[2]) * cos(angle)])
		if end == 0:
			out.remove_at(0)
			out = cap + out
		else:
			out.remove_at(out.size() - 1)
			cap.reverse()
			out = out + cap
	return out


## Weights for a tube from bone `a` into bone `b`: all `a` until `from`, then
## blended across to half and half at the joint (t 1), and on into `b`.
static func _across(a: String, b: String, from := 0.75, to := 1.25) -> Callable:
	return func(t: float) -> Array:
		return [a, b, smoothstep(from, to, t)]


## An ellipsoid of one colour on one bone: middle, half sizes along `basis`'s axes.
## `almond` (0..1) draws it to points at the ends of its long (X) axis.
func _blob(centre: Vector3, size: Vector3, basis: Basis, color: Color, bone: String, rows := 8, around := 12, almond := 0.0) -> void:
	var first := _count
	for r in rows + 1:
		var lat := PI * r / rows - PI * 0.5
		for i in around:
			var lon := TAU * i / around
			var d := Vector3(cos(lat) * cos(lon) * size.x, sin(lat) * size.y, cos(lat) * sin(lon) * size.z)
			if almond > 0.0:
				var along := cos(lat) * cos(lon)
				d.y *= 1.0 - almond * absf(along)
			_vertex(centre + basis * d, color, bone)
	_join(first, rows + 1, around)


func _torso() -> void:
	# (height, half width, half depth, how far forward), from the crotch to the neck
	var rings := [
		[0.965, 0.0, 0.0, 0.0], [0.975, 0.04, 0.035, 0.0], [1.0, 0.098, 0.07, 0.0], [1.06, 0.124, 0.084, -0.005],
		[1.13, 0.104, 0.074, 0.0], [1.2, 0.082, 0.062, 0.004], [1.27, 0.08, 0.06, 0.002], [1.34, 0.094, 0.068, -0.006],
		[1.43, 0.118, 0.082, -0.016], [1.52, 0.132, 0.086, -0.022], [1.6, 0.14, 0.08, -0.028], [1.655, 0.128, 0.066, -0.034],
		[1.69, 0.075, 0.05, -0.036], [1.715, 0.034, 0.034, -0.036],
	]
	var around := 16
	var first := _count
	for ring: Array in rings:
		var y: float = ring[0]
		var w := _spine_weights(y)
		for i in around:
			var angle := TAU * i / around
			var front := sin(angle)
			# (a flatter belly and a rounder back, and the shoulders swept back)
			var depth: float = ring[2] * (0.92 if front > 0.0 else 1.05)
			var at := Vector3(cos(angle) * ring[1], y, ring[3] + front * depth)
			_vertex(at, SKIN, w[0], w[1], w[2])
	_join(first, rings.size(), around)
	# Shoulders: round knobs where the arms meet the chest.
	for s: float in [1.0, -1.0]:
		var side := "l" if s > 0.0 else "r"
		_blob(Vector3(0.152 * s, 1.632, -0.035), Vector3(0.034, 0.03, 0.033), Basis.IDENTITY, SKIN, "upper_arm_" + side, 6, 10)
	# A faint keel of a breastbone and ribs is too much detail for the light; a
	# shallow pelvis bowl under the belly is enough.


func _spine_weights(y: float) -> Array:
	if y < 1.16:
		return ["hips", "spine", smoothstep(1.08, 1.24, y)]
	if y < 1.4:
		return ["spine", "chest", smoothstep(1.3, 1.5, y)]
	return ["chest", "neck", smoothstep(1.64, 1.73, y)]


func _neck() -> void:
	var a := joint("neck") + Vector3(0.0, -0.03, 0.0)
	var b := Vector3(0.0, 1.97, -0.015)
	var rings := [[0.0, 0.05, 0.042], [0.15, 0.034, 0.032], [0.45, 0.028, 0.028], [0.75, 0.03, 0.03], [1.0, 0.045, 0.04], [1.08, 0.0, 0.0]]
	_tube(a, b, rings, Vector3.RIGHT, func(t: float) -> Array:
		if t < 0.1:
			return ["chest", "neck", 0.5 + t * 5.0]
		return ["neck", "head", smoothstep(0.55, 0.85, t)], 10)


## The head: a sphere drawn out into the shape (`_skull_point`), with sockets
## pressed in where the eyes sit, and the eyes and mouth set into it.
func _head() -> void:
	var rows := 22
	var around := 28
	var first := _count
	for r in rows + 1:
		var lat := PI * r / rows - PI * 0.5
		for i in around:
			var lon := TAU * i / around
			var d := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
			_vertex(_skull_point(d), SKIN, "head")
	_join(first, rows + 1, around)
	for s: float in [1.0, -1.0]:
		var eye := _eye_place(s)
		_blob(eye.origin, Vector3(0.066, 0.032, 0.018), eye.basis, EYE, "head", 8, 18, 0.6)
	# The mouth: a short dark slit, and the faintest two nostrils above it.
	var mouth_dir := Vector3(0.0, -0.66, 0.75).normalized()
	var mouth := _skull_point(mouth_dir)
	_blob(mouth - mouth_dir * 0.004, Vector3(0.017, 0.0022, 0.006), _facing(mouth_dir), MOUTH, "head", 4, 10)
	for s: float in [1.0, -1.0]:
		var nose_dir := Vector3(0.013 * s / 0.18, -0.4, 0.92).normalized()
		var nose := _skull_point(nose_dir)
		_blob(nose - nose_dir * 0.002, Vector3(0.0035, 0.0022, 0.003), _facing(nose_dir), MOUTH, "head", 3, 6)


## A point on the head, for a direction from the middle of the skull.
func _skull_point(d: Vector3) -> Vector3:
	var at := _skull_point_plain(d)
	# The sockets: shallow hollows round each eye.
	for s: float in [1.0, -1.0]:
		var into := _eye_dir(s)
		var near := d.dot(into)
		if near > 0.88:
			at -= _skull_normal_guess(d) * 0.012 * smoothstep(0.88, 0.97, near)
	return at


func _skull_normal_guess(d: Vector3) -> Vector3:
	return Vector3(d.x / SKULL_SIZE.x, d.y / SKULL_SIZE.y, d.z / SKULL_SIZE.z).normalized()


## Which way from the middle of the skull each eye lies.
static func _eye_dir(s: float) -> Vector3:
	return Vector3(0.5 * s, -0.2, 0.84).normalized()


## Where an eye sits and how it lies: its long axis slanting up towards the
## side of the head, its face turned out a little from straight ahead.
func _eye_place(s: float) -> Transform3D:
	var d := _eye_dir(s)
	var surface := _skull_point_plain(d)
	var out := _skull_normal_guess(d).lerp(Vector3.FORWARD * -1.0, 0.25).normalized()
	var basis := _facing(out)
	# (slant: the outer corner higher)
	basis = basis * Basis(Vector3.BACK, 0.5 * s)
	return Transform3D(basis, surface - out * 0.008)


## `_skull_point` without the sockets (where the sockets are measured from).
func _skull_point_plain(d: Vector3) -> Vector3:
	var down := maxf(-d.y, 0.0)
	var up := maxf(d.y, 0.0)
	var front := SKULL_SIZE.z if d.z > 0.0 else SKULL_SIZE.w
	# Below the middle the face narrows to a small chin, and the back of the head
	# curves in to the neck sooner than the face does.
	var narrow := 1.0 - 0.74 * pow(down, 1.5)
	var x := d.x * SKULL_SIZE.x * narrow
	var z := d.z * front * (1.0 - (0.5 * pow(down, 1.4) if d.z > 0.0 else 0.88 * pow(down, 1.1)))
	var y := d.y * (SKULL_SIZE.y if d.y > 0.0 else JAW)
	# The crown swells a little forward over the brow; the chin juts a little.
	z += 0.02 * up * up + 0.035 * pow(down, 1.6)
	return SKULL + Vector3(x, y, z)


## A basis whose Z axis is `out` (and X level).
static func _facing(out: Vector3) -> Basis:
	var z := out.normalized()
	var x := Vector3.UP.cross(z).normalized()
	if x.length_squared() < 0.01:
		x = Vector3.RIGHT
	var y := z.cross(x)
	return Basis(x, y, z)


func _arm(side: String) -> void:
	var s := 1.0 if side == "l" else -1.0
	var shoulder := joint("upper_arm_" + side)
	var elbow := joint("forearm_" + side)
	var wrist := joint("hand_" + side)
	_tube(shoulder, elbow, [[-0.08, 0.0, 0.0], [-0.04, 0.03, 0.03], [0.1, 0.036, 0.034], [0.45, 0.031, 0.029], [0.85, 0.025, 0.024], [1.0, 0.025, 0.024], [1.08, 0.0, 0.0]],
		Vector3.RIGHT, _across("upper_arm_" + side, "forearm_" + side, 0.82, 1.18))
	_tube(elbow, wrist, [[-0.06, 0.0, 0.0], [-0.02, 0.023, 0.023], [0.25, 0.024, 0.022], [0.7, 0.019, 0.017], [0.97, 0.016, 0.014], [1.06, 0.0, 0.0]],
		Vector3.RIGHT, _across("forearm_" + side, "hand_" + side, 0.85, 1.12))
	# The palm, long and narrow, flat across the way the fingers fan.
	var knuckles := wrist + Vector3(0.012 * s, -0.1, 0.008)
	_tube(wrist + Vector3(0.0, 0.01, 0.0), knuckles, [[0.0, 0.0, 0.0], [0.1, 0.016, 0.026], [0.55, 0.017, 0.036], [0.92, 0.014, 0.033], [1.0, 0.0, 0.0]],
		Vector3.RIGHT, func(t: float) -> Array: return ["forearm_" + side, "hand_" + side, smoothstep(-0.2, 0.25, t)], 10)
	# Three long fingers, each two joints, ending in a round pad.
	for k in 3:
		var base := "finger_%s_%d_1" % [side, k]
		var mid := "finger_%s_%d_2" % [side, k]
		var a := joint(base)
		var b := joint(mid)
		var tip: Vector3 = TIPS["finger_l_%d_2" % k] * Vector3(s, 1.0, 1.0)
		var thick := 0.0105 if k < 2 else 0.0115
		_tube(a, b, [[-0.08, 0.0, 0.0], [-0.04, thick, thick], [0.5, thick * 0.9, thick * 0.9], [1.0, thick * 0.82, thick * 0.82], [1.08, 0.0, 0.0]],
			Vector3.RIGHT, _across(base, mid, 0.85, 1.15), 7)
		_tube(b, tip, [[-0.08, 0.0, 0.0], [-0.03, thick * 0.8, thick * 0.8], [0.6, thick * 0.7, thick * 0.7], [0.9, thick * 1.25, thick * 1.15], [1.0, thick * 1.05, thick * 0.95], [1.06, 0.0, 0.0]],
			Vector3.RIGHT, func(_t: float) -> Array: return [mid, "", 0.0], 7)


func _leg(side: String) -> void:
	var hip := joint("thigh_" + side)
	var knee := joint("shin_" + side)
	var ankle := joint("foot_" + side)
	_tube(hip + Vector3(-0.01 * (1.0 if side == "l" else -1.0), -0.02, 0.0), knee, [[-0.02, 0.0, 0.0], [0.0, 0.046, 0.05], [0.25, 0.045, 0.046], [0.7, 0.035, 0.034], [0.95, 0.031, 0.031], [1.0, 0.032, 0.031], [1.07, 0.0, 0.0]],
		Vector3.RIGHT, func(t: float) -> Array:
			if t < 0.15:
				return ["hips", "thigh_" + side, 0.55 + t * 3.0]
			return ["thigh_" + side, "shin_" + side, smoothstep(0.85, 1.15, t)])
	_tube(knee, ankle, [[-0.05, 0.0, 0.0], [-0.02, 0.03, 0.03], [0.25, 0.031, 0.03], [0.6, 0.024, 0.022], [0.92, 0.018, 0.017], [1.0, 0.019, 0.018], [1.06, 0.0, 0.0]],
		Vector3.RIGHT, _across("shin_" + side, "foot_" + side, 0.88, 1.12))
	# A long narrow foot, heel to toes, flat on the ground.
	var heel := Vector3(ankle.x, 0.03, ankle.z - 0.055)
	var toes := Vector3(ankle.x * 1.04, 0.022, ankle.z + 0.175)
	_tube(heel, toes, [[0.0, 0.0, 0.0], [0.04, 0.022, 0.024], [0.3, 0.028, 0.03], [0.7, 0.032, 0.02], [0.95, 0.026, 0.015], [1.0, 0.0, 0.0]],
		Vector3.RIGHT, func(_t: float) -> Array: return ["foot_" + side, "", 0.0], 10)

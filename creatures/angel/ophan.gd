class_name Ophan
extends Node3D
## A "biblically accurate" angel, to look at and to watch move: the ophan of
## Ezekiel 1 and 10 with the seraph of Isaiah 6 at its heart. It does not think,
## move about, collide or catch: the game moves the node, says what it looks at
## and how hard (`gaze`), and it looks right doing it. Godot 4, works in GL
## Compatibility (phones, web).
##
##     var angel := Ophan.new()
##     add_child(angel)
##     angel.global_position = somewhere + Vector3.UP * 6.0   # the node is its heart
##     angel.look_at_point = player_chest     # every eye turns to it (INF: they wander)
##     angel.gaze = 0.6                       # its wind-up, 0..1 (see below)
##     angel.blaze()                          # the moment it takes someone
##
## WHAT IT IS. "Their rings were high and dreadful, and their rings were full of
## eyes round about." Three great wheels of pale gold, one within another
## (RING_SIZES: 7.2 m across the outer one at `scale` 1), turning slowly each on
## its own axis while the three tumble about each other; SEATS eyes set in bezels
## round the outside of each rim, real eyes (a wet white with veins, an iris of
## fibres, a pupil, lids with lashes) that blink out of step and look about, each
## its own way, until there is something to look at: then they all turn to it,
## one after another round the rings. At the heart a ball of white-gold fire
## burning in a shell of pale flame, half hidden behind six wings ("with twain he
## covered his face, and with twain he covered his feet, and with twain he did
## fly"), which breathe open and shut; a halo round it with a faint bow of colours
## in it; motes drifting up. It is the one warm, bright thing in a grey world: its
## light (an OmniLight3D) falls on what is round it. It is silent but for a choir
## (made in code) that is all but nothing until it gazes.
##
## GAZE. `gaze` 0..1 is how near it is to taking whatever it looks at; the game
## raises and lowers it. As it rises the eyes stop blinking, stare wide, pupils
## shrinking to points; the wheels slow and, by 0.6, stand still; the wings
## before its face part and the core burns brighter; a cone of pale light runs
## from it to `look_at_point` and pools on the ground there (`gaze_ground`, or
## a metre under the point), a spot light falls on whoever is there, and the
## choir swells and rises in pitch; past 0.75 the lids quiver. `blaze()` is the
## end of it: a flood of light down the cone for BLAZE seconds.
##
## COST. Eight draws (the wheels, the eyes, their lids and the wings are each one
## MultiMesh; the core, its flame, its halo and the motes one each), two more
## while it gazes; the wheels and wings cast shadows. Its own parts are on
## `own_layer`, which its lights leave out (it lights itself in its shaders).
## About 90 thousand triangles, most of them eyes and wheels.
##
## Its parts are modelled in Blender by tools/build_ophan.py
## (models/ophan.glb); the shaders are beside this script. It must sit at
## res://creatures/angel/.

## The wheels' sizes (radius of the middle of each rim, metres at scale 1).
const RING_SIZES := [3.6, 3.12, 2.66]
## Eyes round each wheel, their radius and how far out they sit (the wheel's
## middle radius 1), as tools/build_ophan.py made them.
const SEATS := 16
const EYE := 0.08
const EYE_OUT := 1.012
## The wing's elbow and wrist, as tools/build_ophan.py made it (for the shader).
const ELBOW := Vector2(0.3, 0.035)
const WRIST := Vector2(0.58, 0.0)
## How far round from straight out of its seat an eye can look (radians).
const MAX_TURN := 0.95
## How long a blaze lasts.
const BLAZE := 1.8
const MODEL := "res://creatures/angel/models/ophan.glb"
const DIR := "res://creatures/angel/"

## Where every eye looks, in the world (INF: they look about, each its own way).
var look_at_point := Vector3.INF
## Where its gaze pools on the ground (INF: a metre under `look_at_point`).
var gaze_ground := Vector3.INF
## How near it is to taking what it looks at, 0..1 (see GAZE above).
var gaze := 0.0:
	set(value):
		gaze = clampf(value, 0.0, 1.0)

## How fast the wheels turn and the wings breathe (1 as made).
@export var pace := 1.0
## Its choir, made in code.
@export var sound := true
@export var volume_db := 2.0
@export var sound_range := 70.0
## Its light on the world: how far (metres at scale 1) and how strong.
@export var light_range := 26.0
@export var light_energy := 14.0
## The colour of its fire.
@export var fire := Color(1.0, 0.84, 0.56)
## The render layer (1..20) its own parts are drawn on, which its lights leave out.
@export_range(1, 20) var own_layer := 11
## Seeds which eye has which iris, and their blinking.
@export var eye_seed := 1

var _rings: MultiMeshInstance3D
var _eyes: MultiMeshInstance3D
var _lids: MultiMeshInstance3D
var _wings: MultiMeshInstance3D
var _core: MeshInstance3D
var _flame: MeshInstance3D
var _halo: MeshInstance3D
var _beam: MeshInstance3D
var _pool: MeshInstance3D
var _motes: CPUParticles3D
var _light: OmniLight3D
var _spot: SpotLight3D
var _voice: AudioStreamPlayer3D
var _materials: Array[ShaderMaterial] = []
var _glow := {}

var _time := 0.0
## The wheels' own turning, and their tumbling about each other (slowed by the gaze).
var _spin := [0.0, 1.3, 2.6]
var _tumble := 0.0
var _breath := 0.0
var _still := 0.0
var _part := 0.0
var _blaze := INF
var _rng := RandomNumberGenerator.new()
## Per eye: where it looks (in this node's space), where it wanders to (in its seat's frame),
## when it next darts, when it blinks, how far into a blink it is, its iris, size and how late it turns.
var _look: Array[Vector3] = []
var _wander: Array[Vector2] = []
var _dart_in: PackedFloat32Array = []
var _blink_in: PackedFloat32Array = []
var _blinking: PackedFloat32Array = []
var _iris: PackedFloat32Array = []
var _eye_size: PackedFloat32Array = []
var _late: PackedFloat32Array = []
var _droop: PackedFloat32Array = []
var _noticed := 0.0
var _had_point := false

static var _choir: AudioStreamWAV
static var _parts := {}


func _ready() -> void:
	_rng.seed = eye_seed
	var parts := _load_parts()
	var layer := 1 << (own_layer - 1)
	_rings = _multi(parts.get("Ring"), _material("ophan_ring.gdshader"), RING_SIZES.size(), false, true)
	_eyes = _multi(parts.get("Eyeball"), _material("ophan_eye.gdshader"), SEATS * RING_SIZES.size(), true, false)
	_lids = _multi(parts.get("Lids"), _material("ophan_lids.gdshader"), SEATS * RING_SIZES.size(), true, false)
	var wing_look := _material("ophan_wing.gdshader")
	wing_look.set_shader_parameter(&"elbow", ELBOW)
	wing_look.set_shader_parameter(&"wrist", WRIST)
	_wings = _multi(parts.get("Wing"), wing_look, 6, true, true)

	var ball := SphereMesh.new()
	ball.radius = 0.68
	ball.height = 1.36
	ball.radial_segments = 24
	ball.rings = 12
	_core = _glowing(ball, 0, 1.0)
	var shell := SphereMesh.new()
	shell.radius = 1.0
	shell.height = 2.0
	shell.radial_segments = 20
	shell.rings = 10
	_flame = _glowing(shell, 1, 1.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	_halo = _glowing(quad, 2, 0.9)
	_halo.scale = Vector3.ONE * 4.6
	var cone := CylinderMesh.new()
	cone.top_radius = 0.1
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 16
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	_beam = _glowing(cone, 3, 0.0)
	_beam.top_level = true
	_beam.visible = false
	var plane := PlaneMesh.new()
	plane.size = Vector2(3.0, 3.0)
	_pool = _glowing(plane, 4, 0.0)
	_pool.top_level = true
	_pool.visible = false

	_motes = CPUParticles3D.new()
	var mote := QuadMesh.new()
	mote.size = Vector2(0.09, 0.09)
	_motes.mesh = mote
	_motes.material_override = _glow_material(5)
	_motes.amount = 36
	_motes.lifetime = 6.0
	_motes.preprocess = 6.0
	_motes.local_coords = false
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_motes.emission_sphere_radius = 2.6
	_motes.direction = Vector3.UP
	_motes.spread = 40.0
	_motes.gravity = Vector3(0.0, 0.12, 0.0)
	_motes.initial_velocity_min = 0.05
	_motes.initial_velocity_max = 0.25
	_motes.scale_amount_min = 0.5
	_motes.scale_amount_max = 1.6
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.9, 0.7, 0.0))
	fade.set_color(1, Color(1.0, 0.9, 0.7, 0.0))
	fade.add_point(0.25, Color(1.0, 0.92, 0.75, 0.9))
	fade.add_point(0.7, Color(1.0, 0.85, 0.6, 0.5))
	_motes.color_ramp = fade
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_motes.layers = layer
	add_child(_motes)

	_light = OmniLight3D.new()
	_light.light_color = fire
	_light.omni_range = light_range
	_light.omni_attenuation = 1.0
	_light.light_energy = light_energy
	_light.light_cull_mask = 0xFFFFF & ~layer
	_light.shadow_enabled = false
	add_child(_light)
	_spot = SpotLight3D.new()
	_spot.light_color = fire.lerp(Color.WHITE, 0.5)
	_spot.spot_angle = 9.0
	_spot.light_energy = 0.0
	_spot.light_cull_mask = 0xFFFFF & ~layer
	_spot.top_level = true
	_spot.visible = false
	add_child(_spot)

	if sound:
		_voice = AudioStreamPlayer3D.new()
		_voice.stream = choir_sound()
		_voice.volume_db = -80.0
		_voice.unit_size = 10.0
		_voice.max_distance = sound_range
		_voice.attenuation_filter_cutoff_hz = 3000.0
		add_child(_voice)
		_voice.play(randf() * 3.0)

	var count := SEATS * RING_SIZES.size()
	for i in count:
		_look.append(Vector3.ZERO)
		_wander.append(Vector2.ZERO)
	_dart_in.resize(count)
	_blink_in.resize(count)
	_blinking.resize(count)
	_iris.resize(count)
	_eye_size.resize(count)
	_late.resize(count)
	_droop.resize(count)
	for i in count:
		_dart_in[i] = _rng.randf_range(0.0, 2.0)
		_blink_in[i] = _rng.randf_range(0.3, 6.0)
		_blinking[i] = INF
		_iris[i] = (float(_rng.randi_range(0, 5)) + 0.5) / 6.0
		_eye_size[i] = _rng.randf_range(0.88, 1.12)
		# (the eyes turn one after another round the wheels, outer wheel first)
		_late[i] = float(i % SEATS) / SEATS * 0.55 + float(i / SEATS) * 0.12 + _rng.randf_range(0.0, 0.08)
		_droop[i] = _rng.randf_range(0.0, 0.35) if _rng.randf() < 0.4 else 0.0
	_pose(0.0)
	_pose_eyes(0.0, true)


# --- What the game tells it -------------------------------------------------

## The moment it takes someone: a flood of light down its gaze for BLAZE seconds.
func blaze() -> void:
	_blaze = 0.0


func blazing() -> bool:
	return _blaze < BLAZE


## The share of its eyes that look within `within` radians of `point` (world).
func eyes_on(point: Vector3, within := 0.2) -> float:
	var target := to_local(point)
	var on := 0
	for i in _look.size():
		var at := _eye_at(i).origin
		if _look[i].angle_to(target - at) < within:
			on += 1
	return float(on) / maxf(_look.size(), 1)


## How fast the wheels are turning now, against how fast they turn left alone (1).
func turning() -> float:
	return 1.0 - _still


## How far the wings before its face have parted, 0..1.
func parted() -> float:
	return _part


## How shut eye `i` is now (0 open, 1 shut).
func eye_shut(i: int) -> float:
	return _shut(i)


## Where eye `i` is (world).
func eye_position(i: int) -> Vector3:
	return global_transform * _eye_at(i).origin


func eye_count() -> int:
	return _look.size()


# --- Each frame -------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	_blaze += delta
	var still_to := smoothstep(0.12, 0.6, gaze)
	_still = move_toward(_still, still_to, delta * (2.5 if still_to > _still else 0.5))
	_part = lerpf(_part, smoothstep(0.3, 0.85, gaze), 1.0 - exp(-3.0 * delta))
	var turn := (1.0 - _still) * pace
	_spin[0] += delta * 0.16 * turn
	_spin[1] -= delta * 0.12 * turn
	_spin[2] += delta * 0.09 * turn
	_tumble += delta * turn
	_breath += delta * pace * (1.0 - 0.6 * _still)
	if look_at_point.is_finite() and not _had_point:
		_noticed = 0.0
	_had_point = look_at_point.is_finite()
	_noticed += delta
	_pose(delta)
	_pose_eyes(delta)
	_shine(delta)


## The wheels and the wings.
func _pose(_delta: float) -> void:
	for k in RING_SIZES.size():
		_rings.multimesh.set_instance_transform(k, Transform3D(_ring_basis(k), Vector3.ZERO))
	var br := sin(_breath * TAU / 6.5)
	var br2 := sin(_breath * TAU / 6.5 + 1.1)
	var flap := sin(_breath * TAU / 4.2)
	var wings := _wings.multimesh
	for s: int in [0, 1]:
		var m := 1.0 if s == 0 else -1.0
		var mirror := Vector3(m, 1.0, 1.0)
		# (one of each crossing pair lies a little before the other)
		var before := Vector3(0.0, 0.0, 0.06 * float(s))
		# The pair to fly with: spread up and out behind the heart, beating slowly.
		_set_wing(wings, s, Vector3(0.55, 0.38, -0.5) * mirror, Vector3(1.0, 0.62 + 0.28 * flap, -0.3) * mirror,
			Vector3(0.0, -1.0, -0.15), Vector3(0.0, 0.0, 1.0), 2.05, 0.14 - 0.1 * flap, 0.25, 0.6 + float(s), 1.0)
		# The pair before its face: a curtain across the top of the heart from
		# either side, crossing in the middle; drawn up and apart as it gazes.
		var arm := Vector3(-0.85, 0.06 + 0.03 * br, 0.45).lerp(Vector3(0.75, 0.8, -0.1), _part) * mirror
		var hang := Vector3(0.0, -1.0, 0.15).lerp(Vector3(0.25, -1.0, 0.3), _part) * mirror
		_set_wing(wings, 2 + s, Vector3(0.62, 0.92, 0.18) * mirror + before, arm, hang, Vector3(0.4 * m, 0.3, 1.0),
			1.8, 0.18 + 0.08 * (1.0 - br) + 0.1 * _part, lerpf(-0.35, 0.25, _part), 2.0 + float(s), 0.5)
		# The pair before its feet, across the bottom of it.
		_set_wing(wings, 4 + s, Vector3(0.62, -0.4, 0.18) * mirror + before, Vector3(-0.85, -0.12, 0.45 + 0.04 * br2) * mirror,
			Vector3(0.0, -1.0, 0.1), Vector3(0.4 * m, -0.2, 1.0), 1.7, 0.22 + 0.08 * (1.0 - br2), -0.3, 4.0 + float(s), 0.4)


func _set_wing(wings: MultiMesh, i: int, shoulder: Vector3, arm: Vector3, hang: Vector3, face: Vector3, size: float, fold: float, cup: float, phase: float, stir: float) -> void:
	var x := arm.normalized()
	var y := -(hang - x * hang.dot(x)).normalized()
	var z := x.cross(y)
	# (the outer face of the wing towards `face`, mirroring the model where it must)
	if z.dot(face) < 0.0:
		z = -z
	wings.set_instance_transform(i, Transform3D(Basis(x, y, z) * Basis.from_scale(Vector3.ONE * size), shoulder))
	wings.set_instance_custom_data(i, Color(clampf(fold, 0.0, 1.0), cup, phase, stir))


## Wheel `k`'s turn (and size): each turning on its own axis, the three tumbling.
func _ring_basis(k: int) -> Basis:
	var t := _tumble
	var tumble: Basis
	match k:
		0:
			tumble = Basis(Vector3.UP, 0.05 * t) * Basis(Vector3.RIGHT, PI * 0.5)
		1:
			tumble = Basis(Vector3.UP, 0.05 * t + PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5 + 0.35 * sin(t * 0.07)) * Basis(Vector3.FORWARD, 0.25)
		_:
			tumble = Basis(Vector3.RIGHT, 0.3 + 0.3 * sin(t * 0.05)) * Basis(Vector3.FORWARD, 0.2 * sin(t * 0.031 + 1.0))
	return tumble * Basis(Vector3.UP, _spin[k]) * Basis.from_scale(Vector3.ONE * RING_SIZES[k])


## Eye `i` in its seat, before it looks anywhere: where it is (this node's
## space) and its frame (z straight out of the seat, y along the wheel's axis).
func _eye_at(i: int) -> Transform3D:
	var k := i / SEATS
	var a := TAU * float(i % SEATS) / SEATS
	var ring := _ring_basis(k)
	var out := Vector3(cos(a), 0.0, sin(a))
	var at := ring * (out * EYE_OUT)
	var n := (ring * out).normalized()
	var up := ring.y.normalized()
	return Transform3D(Basis(up.cross(n).normalized(), up, n), at)


func _shut(i: int) -> float:
	var t := _blinking[i]
	var blink := 0.0
	if t < 0.07:
		blink = t / 0.07
	elif t < 0.1:
		blink = 1.0
	elif t < 0.26:
		blink = 1.0 - smoothstep(0.1, 0.26, t)
	return maxf(blink, _droop[i] * (1.0 - smoothstep(0.0, 0.3, gaze)) * (0.4 if look_at_point.is_finite() else 1.0))


func _pose_eyes(delta: float, snap := false) -> void:
	var target := to_local(look_at_point) if look_at_point.is_finite() else Vector3.INF
	var staring := smoothstep(0.25, 0.45, gaze)
	var eyes := _eyes.multimesh
	var lids := _lids.multimesh
	for i in _look.size():
		var k := i / SEATS
		var seat := _eye_at(i)
		var n := seat.basis.z
		var want := Vector3.ZERO
		if target.is_finite() and _noticed >= _late[i]:
			want = (target - seat.origin).normalized()
		else:
			_dart_in[i] -= delta
			if _dart_in[i] <= 0.0:
				_dart_in[i] = _rng.randf_range(0.4, 3.0)
				_wander[i] = Vector2(_rng.randf_range(-0.7, 0.7), _rng.randf_range(-0.45, 0.45))
			want = (seat.basis.x * _wander[i].x + seat.basis.y * _wander[i].y + n).normalized()
		var off := n.angle_to(want)
		if off > MAX_TURN:
			want = n.slerp(want, MAX_TURN / off)
		if snap or _look[i] == Vector3.ZERO:
			_look[i] = want
		else:
			# (quick darts, as eyes move)
			_look[i] = _look[i].slerp(want, 1.0 - exp(-16.0 * delta)).normalized()
		var size: float = EYE * RING_SIZES[k] * _eye_size[i]
		eyes.set_instance_transform(i, Transform3D(Basis.looking_at(_look[i], seat.basis.y, true) * Basis.from_scale(Vector3.ONE * size), seat.origin))
		eyes.set_instance_custom_data(i, Color(lerpf(0.5 + 0.25 * sin(_time * 0.7 + i), 0.04, staring), _iris[i], 0.3 + 0.7 * gaze, 0.0))
		lids.set_instance_transform(i, Transform3D(seat.basis * Basis.from_scale(Vector3.ONE * size), seat.origin))
		# Blinking, each in its own time; none while it stares.
		_blinking[i] += delta
		_blink_in[i] -= delta
		if _blink_in[i] <= 0.0:
			if staring < 0.5:
				_blinking[i] = 0.0
			# (now and then twice running)
			_blink_in[i] = 0.35 if _rng.randf() < 0.12 else _rng.randf_range(1.5, 7.0)
		lids.set_instance_custom_data(i, Color(_shut(i) * (1.0 - staring), staring, smoothstep(0.72, 0.95, gaze), 0.0))


## The fire, the light and the gaze.
func _shine(delta: float) -> void:
	var blaze_now := 0.0
	if _blaze < BLAZE:
		var b := _blaze / BLAZE
		blaze_now = smoothstep(0.0, 0.12, b) * (1.0 - smoothstep(0.45, 1.0, b))
	var flicker := 0.92 + 0.05 * sin(_time * 7.3) + 0.03 * sin(_time * 17.1 + 1.0)
	var burn := (1.0 + 0.9 * gaze + 1.5 * blaze_now) * flicker
	var size := global_basis.get_scale().x
	var centre := global_position
	for material in _materials:
		material.set_shader_parameter(&"core_position", centre)
		material.set_shader_parameter(&"core_strength", burn)
		material.set_shader_parameter(&"core_reach", 4.5 * size)
		material.set_shader_parameter(&"core_color", fire)
	_set_glow(0, 1.1 * burn)
	_set_glow(1, 0.85 * burn)
	_set_glow(2, 0.75 + 0.35 * gaze + 0.8 * blaze_now)
	_halo.scale = Vector3.ONE * (4.6 + 1.2 * blaze_now)
	_light.light_energy = light_energy * burn
	_light.omni_range = light_range * size
	var strength := pow(smoothstep(0.25, 1.0, gaze), 1.4) + blaze_now * 1.5
	var showing := strength > 0.01 and look_at_point.is_finite()
	_beam.visible = showing
	_pool.visible = showing
	_spot.visible = showing
	if showing:
		var to := look_at_point
		var ground := gaze_ground if gaze_ground.is_finite() else to - Vector3.UP * 1.0
		var from := centre
		var length := from.distance_to(to) + 1.2
		var way := (to - from).normalized()
		var side := way.cross(Vector3.UP if absf(way.y) < 0.95 else Vector3.RIGHT).normalized()
		var wide := 0.55 + 0.45 * blaze_now
		# (the cone's narrow top at the core, opening to its full width past the point)
		var basis := Basis(side * wide, -way * length, way.cross(side) * wide)
		_beam.global_transform = Transform3D(basis, from + way * length * 0.5)
		_set_glow(3, strength)
		_pool.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * (1.0 + 0.4 * blaze_now)), ground + Vector3.UP * 0.04)
		_set_glow(4, strength * 0.9)
		_spot.global_position = from
		if from.distance_to(to) > 0.1:
			_spot.look_at(to, Vector3.UP if absf(way.y) < 0.95 else Vector3.RIGHT)
		_spot.spot_range = length + 6.0
		_spot.light_energy = 7.0 * strength
	if _voice:
		var loud := 0.02 + 0.98 * smoothstep(0.0, 0.9, gaze) + blaze_now
		_voice.volume_db = volume_db + linear_to_db(clampf(loud, 0.0001, 1.5))
		_voice.pitch_scale = lerpf(_voice.pitch_scale, 0.9 + 0.22 * gaze + 0.1 * blaze_now, 1.0 - exp(-4.0 * delta))


func _set_glow(kind: int, strength: float) -> void:
	(_glow[kind] as ShaderMaterial).set_shader_parameter(&"strength", strength)


# --- Making it --------------------------------------------------------------

func _load_parts() -> Dictionary:
	if not _parts.is_empty():
		return _parts
	var scene := load(MODEL) as PackedScene
	if scene == null:
		push_error("Ophan: no model at %s (build it with creatures/angel/tools/build_ophan.py)" % MODEL)
		return {}
	var root := scene.instantiate()
	for piece: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		_parts[String(piece.name)] = piece.mesh
	root.free()
	return _parts


func _material(file: String) -> ShaderMaterial:
	var made := ShaderMaterial.new()
	made.shader = load(DIR + file)
	_materials.append(made)
	return made


func _multi(mesh: Mesh, material: ShaderMaterial, count: int, custom: bool, shadows: bool) -> MultiMeshInstance3D:
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = custom
	many.use_colors = false
	many.mesh = mesh
	many.instance_count = count
	var drawn := MultiMeshInstance3D.new()
	drawn.multimesh = many
	drawn.material_override = material
	drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	drawn.layers = 1 << (own_layer - 1)
	var reach := 4.2
	drawn.custom_aabb = AABB(-Vector3.ONE * reach, Vector3.ONE * reach * 2.0)
	add_child(drawn)
	return drawn


func _glow_material(kind: int) -> ShaderMaterial:
	var made := ShaderMaterial.new()
	# (the core is solid fire, its own shader; the rest is light added on)
	made.shader = load(DIR + ("ophan_core.gdshader" if kind == 0 else "ophan_glow.gdshader"))
	if kind != 0:
		made.set_shader_parameter(&"kind", kind)
	made.set_shader_parameter(&"color", fire)
	_glow[kind] = made
	return made


func _glowing(mesh: Mesh, kind: int, strength: float) -> MeshInstance3D:
	var drawn := MeshInstance3D.new()
	drawn.mesh = mesh
	drawn.material_override = _glow_material(kind)
	(_glow[kind] as ShaderMaterial).set_shader_parameter(&"strength", strength)
	drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	drawn.layers = 1 << (own_layer - 1)
	add_child(drawn)
	return drawn


## The choir, made once and shared: a loop of voices holding one chord, an
## open fifth over a low A with a semitone rubbing at its top (A, E, A, B flat,
## E), each voice a train of glottal pulses with its own slow vibrato, sung on
## an open "oh" (formant filters on the sum) with breath through it, and a
## shimmer above; each voice swelling and fading on its own slow breath. Its
## ends are crossfaded so it loops without a seam. The game raises its pitch and
## loudness with the gaze, which turns it from a hush to a rising chord.
static func choir_sound() -> AudioStreamWAV:
	if _choir:
		return _choir
	var rate := 12000
	var length := 3.2
	var fade := 0.5
	var count := int(rate * (length + fade))
	var loop := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var notes := [110.0, 164.81, 220.0, 233.08, 329.63]
	var gains := [0.9, 0.7, 0.75, 0.45, 0.4]
	# (vibratos and swells that go a whole number of times round the loop)
	var vibrato := [4.6875, 5.0, 5.3125, 4.375, 5.625]
	var swell := [0.3125, 0.625, 0.3125, 0.9375, 0.625]
	var phases := PackedFloat32Array()
	phases.resize(notes.size())
	var formants: Array[ChoirBand] = [ChoirBand.new(520.0, 5.0, rate), ChoirBand.new(880.0, 6.0, rate), ChoirBand.new(2600.0, 8.0, rate), ChoirBand.new(3400.0, 9.0, rate)]
	var formant_gain := [1.0, 0.7, 0.3, 0.18]
	var breath := ChoirBand.new(1800.0, 1.5, rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var loudest := 0.0
	for i in count:
		var t := float(i) / rate
		var pulses := 0.0
		for v in notes.size():
			var f: float = notes[v] * (1.0 + 0.006 * sin(TAU * vibrato[v] * t + v * 1.3))
			phases[v] = fposmod(phases[v] + f / rate, 1.0)
			var p := phases[v]
			var q := 1.0 - p
			var q2 := q * q
			var pulse := q * q2 * q2 * 2.0 - 0.33
			var level: float = gains[v] * (0.65 + 0.35 * sin(TAU * swell[v] * t + v * 2.1))
			pulses += pulse * level
		var voiced := 0.0
		for k in formants.size():
			voiced += formants[k].run(pulses) * formant_gain[k]
		var air := breath.run(rng.randf_range(-1.0, 1.0)) * 0.25
		samples[i] = voiced + air
		loudest = maxf(loudest, absf(samples[i]))
	# The end crossfaded into the start.
	var tail := count - loop
	for i in tail:
		var w := float(i) / tail
		samples[i] = samples[i] * w + samples[loop + i] * (1.0 - w)
	var data := PackedByteArray()
	data.resize(loop * 2)
	for i in loop:
		data.encode_s16(i * 2, int(clampf(samples[i] / maxf(loudest, 0.001) * 0.9, -1.0, 1.0) * 30000.0))
	_choir = AudioStreamWAV.new()
	_choir.format = AudioStreamWAV.FORMAT_16_BITS
	_choir.mix_rate = rate
	_choir.data = data
	_choir.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_choir.loop_begin = 0
	_choir.loop_end = loop
	return _choir


## A resonant band-pass filter (a biquad), for the choir.
class ChoirBand:
	var _b0 := 0.0
	var _a1 := 0.0
	var _a2 := 0.0
	var _x1 := 0.0
	var _x2 := 0.0
	var _y1 := 0.0
	var _y2 := 0.0

	func _init(frequency: float, q: float, rate: int) -> void:
		var w := TAU * frequency / rate
		var alpha := sin(w) / (2.0 * q)
		var a0 := 1.0 + alpha
		_b0 = alpha / a0
		_a1 = -2.0 * cos(w) / a0
		_a2 = (1.0 - alpha) / a0

	func run(x: float) -> float:
		var y := _b0 * x - _b0 * _x2 - _a1 * _y1 - _a2 * _y2
		_x2 = _x1
		_x1 = x
		_y2 = _y1
		_y1 = y
		return y

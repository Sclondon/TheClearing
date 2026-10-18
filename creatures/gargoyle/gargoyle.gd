class_name Gargoyle
extends Node3D
## A gargoyle: a carved-stone grotesque that is alive. Hunched and heavily
## muscled, the head thrust low between a hump of shoulders, horned, with a
## snarling beast's face (a scowling brow over deep eyes, a wrinkled muzzle,
## fangs, tusks jutting up from an underslung jaw, pointed ears), long clawed
## arms, crouched taloned legs, a barbed tail, a ridge of spikes down its back,
## and two great bat wings that are hands as a bat's are: an arm, a clawed
## thumb at the wrist and four long fingers with the skin stretched between.
## Weathered cast stone all over (GargoyleLook): rain-stained, mossy, chipped
## and cracked; alive, an ember glows faintly in the cracks and in its eyes.
##
## This is only how it looks, moves and sounds. It does no thinking: a game
## moves it and says what it is doing; it poses itself from that.
##
##     var gargoyle := Gargoyle.new()
##     add_child(gargoyle)
##     gargoyle.perched = true                  # crouched on a ledge, wings raised behind
##     gargoyle.settle()                        # (a statue: `alive` is false)
##     # each frame, whatever drives it:
##     gargoyle.global_position = where         # on the ground (or the ledge) under it
##     gargoyle.rotation.y = heading            # 0 faces +Z
##     gargoyle.alive = true                    # stone (false) or alive: it wakes and sets over a moment
##     gargoyle.airborne = true                 # in the air: wings out...
##     gargoyle.flapping = 1.0                  # ...beating (0: gliding)
##     gargoyle.reaching = 1.0                  # claws thrust out at what it falls on
##     gargoyle.aim = player.global_position + Vector3.UP   # what it looks at (INF: nothing)
##     # when you like:
##     gargoyle.gather(0.7)                     # the wind-up for a pounce: crouched, wings up, snarling
##     gargoyle.slam()                          # it hits the ground: a crash and a cloud of stone dust
##     gargoyle.snarl()                         # a grinding growl, jaw wide
##
## HOW IT MOVES. It works out its own speed and turning from how it is moved.
## Slow, it lurches on all fours, knuckles and talons; faster it goes in heavy
## bounds, hands down together and then both feet, the body heaving between,
## its wings half open for balance. Still, it crouches on all fours, or with
## `perched` squats on its ledge, hands gripping the edge between its feet,
## wings raised and folded behind, peering down. In the air it holds its body
## level, its wings beating as a bat's do (`flapping`: the downstroke with the
## wing fully stretched and swept forward, the upstroke with elbow and wrist
## bent and the fingers drawn together) or spread to glide; legs trailing, or
## with `reaching` thrust forward, claws open. When it turns to stone
## (`alive` false) it slows and stops dead in whatever pose it is in, the glow
## goes out of its cracks, and nothing more is done for it each frame.
##
## The model is creatures/gargoyle/models/gargoyle.glb (and gargoyle_lo.glb),
## built in Blender by tools/build_gargoyle.py, which also writes where its
## bones stand (gargoyle_rest.gd).

## It came down hard (a `slam()`): for whatever shakes the camera.
signal slammed

const MODEL := "res://creatures/gargoyle/models/gargoyle.glb"
const MODEL_LO := "res://creatures/gargoyle/models/gargoyle_lo.glb"
## Seconds it takes to wake, and to set back into stone.
const WAKE_TIME := 0.7
const SET_TIME := 0.55

## Use the low-poly model (or set `low_poly_all` for every gargoyle).
@export var low_poly := false
static var low_poly_all := false
## Its sounds (made in code), how loud and how far off they are heard (metres).
@export var sound := true
@export var volume_db := 2.0
@export var sound_range := 55.0
## Stone dust shed as it moves and thrown up when it lands.
@export var dust := true
## How big it is drawn (1: about 1.9 m tall crouched, 5.2 m from wingtip to wingtip).
@export var size := 1.0
## Each one's own stone, a little lighter or darker.
@export var seed_value := 0

## Stone (false) or alive (true).
var alive := false
## Squatting on a ledge (its origin on the ledge, near the front edge).
var perched := false
## In the air (wings out).
var airborne := false
## In the air: 0 gliding, 1 beating its wings hard.
var flapping := 0.0
## 0..1: arms and legs thrust forward, claws open (a pounce).
var reaching := 0.0
## What it looks at (world), or INF.
var aim := Vector3.INF
## How hard it works (0..1), for the glow in its cracks and the grinding; it
## works this out from its own motion, and this is added.
var strain := 0.0

var _model: Node3D
var _skeleton: Skeleton3D
var _body: MeshInstance3D
var _index := {}
var _bone_rest := {}
var _to_skeleton := Transform3D.IDENTITY
var _posed := false

var _life := 0.0
var _clock := 0.0
var _t := 0.0
var _was := Vector3.INF
var _yaw_was := 0.0
var _speed := 0.0
var _turn := 0.0
var _phase := 0.0
var _beat := 0.0
var _moving := 0.0
var _gallop := 0.0
var _perch := 0.0
var _air := 0.0
var _reach := 0.0
var _flap := 0.0
var _gather_left := 0.0
var _gather_len := 0.7
var _gathered := 0.0
var _slam := INF
var _snarl := INF
var _gaze := Vector2.ZERO
var _work := 0.0
var _contacts := [false, false, false, false]
var _rng := RandomNumberGenerator.new()

var _grind: AudioStreamPlayer3D
var _voice: AudioStreamPlayer3D
var _knock: AudioStreamPlayer3D
var _wings_sound: AudioStreamPlayer3D
var _shed: CPUParticles3D
var _burst: CPUParticles3D
var _shadow: MeshInstance3D
var _pebbles: CPUParticles3D
var _crumble_left := 0.0
var _tick_in := 0.0

static var _sounds := {}


func _ready() -> void:
	_rng.seed = seed_value
	_model = (load(MODEL_LO if low_poly or low_poly_all else MODEL) as PackedScene).instantiate()
	_model.scale = Vector3.ONE * size
	add_child(_model)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0]
	_body = _model.find_children("*", "MeshInstance3D", true, false)[0]
	_body.material_override = GargoyleLook.material()
	_body.set_instance_shader_parameter(&"tone", _rng.randf_range(0.9, 1.08))
	_body.custom_aabb = AABB(Vector3(-2.8, -0.6, -2.4), Vector3(5.6, 3.4, 4.8))
	_to_skeleton = _skeleton.global_transform.affine_inverse() * _model.global_transform
	for name: String in GargoyleRest.BONES:
		var i := _skeleton.find_bone(name)
		_index[name] = i
		_bone_rest[name] = _skeleton.get_bone_global_rest(i)
	if sound:
		_grind = _player(grind_sound(), -6.0)
		_voice = _player(snarl_sound(), 0.0)
		_knock = _player(crash_sound(), 0.0)
		_knock.max_polyphony = 4
		_wings_sound = _player(whoosh_sound(), -4.0)
		_wings_sound.max_polyphony = 2
	if dust:
		_make_dust()
	settle()


func _player(stream: AudioStream, gain: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db + gain
	p.unit_size = 7.0
	p.max_distance = sound_range
	p.position = Vector3(0.0, 1.0, 0.2) * size
	add_child(p)
	return p


## Puts it still as it is told it is (perched or not, alive or stone), with nothing going on.
func settle() -> void:
	_was = global_position
	_yaw_was = global_rotation.y
	_speed = 0.0
	_turn = 0.0
	_moving = 0.0
	_gallop = 0.0
	_perch = 1.0 if perched else 0.0
	_air = 1.0 if airborne else 0.0
	_reach = reaching
	_flap = flapping
	_life = 1.0 if alive else 0.0
	_gather_left = 0.0
	_gathered = 0.0
	_slam = INF
	_snarl = INF
	_posed = false
	_pose(0.0)
	_shade()


## The wind-up for a pounce: it sinks into a crouch, raises its wings high and
## snarls with a grinding of stone, over `seconds`.
func gather(seconds := 0.7) -> void:
	_gather_len = maxf(seconds, 0.1)
	_gather_left = _gather_len
	if _voice:
		_voice.pitch_scale = 0.9
		_voice.play()


func gathering() -> bool:
	return _gather_left > 0.0


## It has come down hard: it lands in a crouch, hands slammed down, with a crash
## and a cloud of stone dust.
func slam() -> void:
	_slam = 0.0
	if _knock:
		_knock.volume_db = volume_db + 3.0
		_knock.pitch_scale = _rng.randf_range(0.85, 1.0)
		_knock.play()
	if _burst:
		_burst.restart()
		_burst.emitting = true
	slammed.emit()


## Grit and pebbles shaken off from under it for `seconds` (falling the whole
## way to the ground below a ledge, ticking as they land), with the grinding of
## stone: the warning, for someone below who is not looking up.
func crumble(seconds := 1.3) -> void:
	_crumble_left = seconds
	if _pebbles:
		_pebbles.emitting = true
	if _shed:
		_shed.emitting = true


## A grinding growl, its jaw wide and head thrust out.
func snarl() -> void:
	_snarl = 0.0
	if _voice:
		_voice.pitch_scale = _rng.randf_range(0.95, 1.08)
		_voice.play()


## How alive it is now, 0 (stone) to 1.
func life() -> float:
	return _life


## A shadow on the ground at `point` (world), as dark as `strength` (0..1), and
## `radius` across: where it will land. INF for none.
func show_shadow(point: Vector3, strength := 1.0, radius := 1.4) -> void:
	if _shadow == null:
		_shadow = MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(2.0, 2.0)
		quad.orientation = PlaneMesh.FACE_Y
		_shadow.mesh = quad
		_shadow.material_override = _shadow_material()
		_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shadow.top_level = true
		add_child(_shadow)
	_shadow.visible = point.is_finite() and strength > 0.01
	if _shadow.visible:
		_shadow.global_transform = Transform3D(Basis.from_scale(Vector3.ONE * radius), point + Vector3.UP * 0.04)
		_shadow.set_instance_shader_parameter(&"strength", clampf(strength, 0.0, 1.0))


# --- Each frame ---

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_life = move_toward(_life, 1.0 if alive else 0.0, delta / (WAKE_TIME if alive else SET_TIME))
	# Setting into stone it slows, and stops dead; then nothing more is done for it.
	var pace := smoothstep(0.0, 0.7, _life)
	_gather_left = maxf(_gather_left - delta, 0.0)
	_crumbling(delta)
	_slam += delta
	_snarl += delta
	if _life <= 0.0 and _posed:
		_was = global_position
		_yaw_was = global_rotation.y
		_shade()
		_quiet()
		return
	var dt := delta * pace
	_t += dt
	var at := global_position
	if not _was.is_finite():
		_was = at
	var moved := Vector3(at.x - _was.x, 0.0, at.z - _was.z)
	_was = at
	var forward := global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.BACK
	var speed := moved.length() / delta / size
	_speed = lerpf(_speed, speed, 1.0 - exp(-8.0 * delta))
	var yaw := global_rotation.y
	_turn = lerpf(_turn, angle_difference(_yaw_was, yaw) / delta, 1.0 - exp(-6.0 * delta))
	_yaw_was = yaw
	var stepping := maxf(_speed, absf(_turn) * 0.5)
	_moving = move_toward(_moving, 1.0 if stepping > 0.15 else 0.0, dt * 3.0)
	_gallop = move_toward(_gallop, smoothstep(1.4, 3.0, _speed), dt * 2.0)
	var cycle := lerpf(1.1, 2.6, _gallop)
	if not airborne:
		_phase = fposmod(_phase + maxf(moved.dot(forward) / size, stepping * delta * 0.6) / cycle * pace, 1.0)
	_perch = move_toward(_perch, 1.0 if perched and not airborne else 0.0, dt * 2.5)
	_air = move_toward(_air, 1.0 if airborne else 0.0, dt * 4.0)
	_reach = move_toward(_reach, reaching, dt * 5.0)
	_flap = move_toward(_flap, flapping if airborne else 0.0, dt * 3.0)
	var beat_was := _beat
	_beat = fposmod(_beat + dt * lerpf(0.0, 1.9, _flap) * (1.0 if airborne else 0.0), 1.0)
	if _wings_sound and _flap > 0.3 and beat_was < 0.05 and _beat >= 0.05:
		_wings_sound.pitch_scale = _rng.randf_range(0.9, 1.05)
		_wings_sound.play()
	_gathered = move_toward(_gathered, 1.0 if _gather_left > 0.0 else 0.0, dt / maxf(_gather_len * 0.6, 0.1) if _gather_left > 0.0 else dt * 3.0)
	_work = clampf(_speed / 3.5 + absf(_turn) * 0.3 + _gathered + _flap * 0.6 + strain, 0.0, 1.0)
	_pose(dt)
	_shade()
	_noise(delta)


func _shade() -> void:
	if _body:
		_body.set_instance_shader_parameter(&"life", _life)
		_body.set_instance_shader_parameter(&"strain", _work * _life)


## Sound and dust as it goes: stone grinding as it moves (most as it wakes and
## sets), knocks of stone on stone as its hands and feet come down.
func _noise(delta: float) -> void:
	var setting := 1.0 - absf(_life * 2.0 - 1.0)
	if _grind:
		var want := clampf((_work * 0.8 + setting * 1.2) * smoothstep(0.0, 0.3, _life + setting), 0.0, 1.0)
		if want > 0.03 and not _grind.playing:
			_grind.play(_rng.randf_range(0.0, 1.0))
		_grind.volume_db = volume_db - 4.0 + linear_to_db(maxf(want, 0.001))
		_grind.pitch_scale = 0.8 + 0.35 * _work
		if want <= 0.03 and _grind.playing:
			_grind.stop()
	if _shed:
		_shed.emitting = (_work > 0.25 and not airborne) or (setting > 0.2) or _crumble_left > 0.0


func _crumbling(delta: float) -> void:
	if _crumble_left <= 0.0:
		return
	_crumble_left -= delta
	if _crumble_left <= 0.0:
		if _pebbles:
			_pebbles.emitting = false
		return
	# (the grinding, loud while it lasts; pebbles ticking on the ground below)
	if _grind:
		if not _grind.playing:
			_grind.play()
		_grind.volume_db = volume_db + 2.0
	_tick_in -= delta
	if _tick_in <= 0.0 and _knock:
		_tick_in = _rng.randf_range(0.08, 0.3)
		_knock.volume_db = volume_db - 9.0
		_knock.pitch_scale = _rng.randf_range(2.2, 3.2)
		_knock.play()


func _quiet() -> void:
	if _grind and _grind.playing:
		_grind.stop()
	if _shed:
		_shed.emitting = false


# --- Posing ---

## One whole pose, in the model's own space (metres at size 1, facing +Z).
class Pose:
	## The middle of the haunches and of the chest.
	var pelvis := Vector3(0.0, 0.8, -0.27)
	var chest := Vector3(0.0, 1.03, 0.2)
	## Extra bend through the back (+: hunched), and roll of the whole body (+: left side down).
	var arch := 0.0
	var roll := 0.0
	## The wrists (left, right) and the balls of the feet (left, right).
	var hands: Array[Vector3] = [Vector3(0.44, 0.2, 0.5), Vector3(-0.44, 0.2, 0.5)]
	var feet: Array[Vector3] = [Vector3(0.3, 0.0, -0.02), Vector3(-0.3, 0.0, -0.02)]
	## Which way the hands point from the wrist (left; the right is its mirror).
	var hand_dir := Vector3(0.0, -0.9, 0.35)
	## How far the heels are raised from where they are modelled (radians), and the toes curled.
	var heel := 0.0
	var toes := 0.0
	var fingers := 0.0
	## Where the elbows and knees point (out to the side).
	var elbows_out := 0.5
	var knees_out := 0.35
	var head_pitch := 0.0
	var neck_pitch := 0.0
	var jaw := 0.12
	var tail_lift := 0.0
	var tail_curl := 0.0
	## Each wing: lift, sweep, twist, elbow, wrist, close, bend, cup, tips, raise (see `_wing`).
	var wing_l := PackedFloat32Array(FOLDED)
	var wing_r := PackedFloat32Array(FOLDED)

	func copy() -> Pose:
		return blend(self, 0.0)

	func blend(other: Pose, w: float) -> Pose:
		var p := Pose.new()
		p.pelvis = pelvis.lerp(other.pelvis, w)
		p.chest = chest.lerp(other.chest, w)
		p.arch = lerpf(arch, other.arch, w)
		p.roll = lerpf(roll, other.roll, w)
		for i in 2:
			p.hands[i] = hands[i].lerp(other.hands[i], w)
			p.feet[i] = feet[i].lerp(other.feet[i], w)
		p.hand_dir = hand_dir.lerp(other.hand_dir, w)
		p.heel = lerpf(heel, other.heel, w)
		p.toes = lerpf(toes, other.toes, w)
		p.fingers = lerpf(fingers, other.fingers, w)
		p.elbows_out = lerpf(elbows_out, other.elbows_out, w)
		p.knees_out = lerpf(knees_out, other.knees_out, w)
		p.head_pitch = lerpf(head_pitch, other.head_pitch, w)
		p.neck_pitch = lerpf(neck_pitch, other.neck_pitch, w)
		p.jaw = lerpf(jaw, other.jaw, w)
		p.tail_lift = lerpf(tail_lift, other.tail_lift, w)
		p.tail_curl = lerpf(tail_curl, other.tail_curl, w)
		p.wing_l = Gargoyle.wing_mix(wing_l, other.wing_l, w)
		p.wing_r = Gargoyle.wing_mix(wing_r, other.wing_r, w)
		return p


## Wings: lift, sweep, twist, elbow, wrist, close, bend, cup, tips, raise.
## Folded up behind its shoulders like a cloak, the wrists standing above them.
const FOLDED := [-1.45, 0.3, 0.0, 2.8, -1.2, 1.0, 0.0, 0.0, 0.0, -1.0]
## Held out still, spread (gliding).
const SPREAD := [0.12, 0.0, 0.0, 0.0, 0.0, 0.0, -0.04, 0.12, 0.0, 0.0]
## Half open and raised, for balance as it bounds.
const HALF := [-0.35, -0.35, 0.0, 1.3, -0.1, 0.55, 0.0, 0.1, 0.0, 0.1]
## Raised high and half open over its back (the wind-up for a pounce).
const RAISED := [1.0, -0.4, 0.0, 0.9, 0.0, 0.35, 0.1, 0.1, 0.0, 0.0]


static func wing_mix(a: PackedFloat32Array, b: PackedFloat32Array, w: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(a.size())
	for i in a.size():
		out[i] = lerpf(a[i], b[i], w)
	return out


## A wingbeat, after slow-motion film of bats (as BatBody's shader has it):
## `beat` 0..1 round and round (0 the top), `strength` how hard.
static func wing_beat(beat: float, strength: float) -> PackedFloat32Array:
	var a := TAU * beat
	var drawn := strength * pow(maxf(-sin(a), 0.0), 1.3)
	var p := PackedFloat32Array(SPREAD)
	p[0] = strength * (0.95 * cos(a) + 0.1) + (1.0 - strength) * 0.12
	p[1] = strength * 0.22 * sin(a)
	p[2] = -strength * 0.28 * sin(a)
	p[3] = 0.75 * drawn
	p[4] = 0.95 * drawn
	p[5] = 0.6 * drawn
	p[6] = strength * 0.42 * sin(a + 0.45) - (1.0 - strength) * 0.04
	p[7] = 0.12 + 0.15 * strength * maxf(sin(a), 0.0)
	return p


## Crouched on all fours, still or going (a lurch slow, heavy bounds fast).
func _going() -> Pose:
	var p := Pose.new()
	var g := _gallop
	var m := _moving
	# (walk: diagonal pairs; bound: hands together, then feet together)
	var offsets := [lerpf(0.0, 0.0, g), lerpf(0.5, 0.07, g), lerpf(0.25, 0.5, g), lerpf(0.75, 0.57, g)]
	var duty := lerpf(0.62, 0.36, g)
	var cycle := lerpf(1.1, 2.6, g)
	var reach := cycle * duty
	var lift := lerpf(0.1, 0.2, g)
	var homes := [p.hands[0] + Vector3(0, -0.2, 0.02), p.hands[1] + Vector3(0, -0.2, 0.02), p.feet[0], p.feet[1]]
	var down: Array[float] = []
	for i in 4:
		var s := fposmod(_phase - offsets[i], 1.0)
		var at: Vector3 = homes[i]
		if s < duty:
			at.z += reach * (0.5 - s / duty) * m
			down.append(1.0)
		else:
			var k := (s - duty) / (1.0 - duty)
			at.z += reach * (-0.5 + k * k * (3.0 - 2.0 * k)) * m
			at.y += lift * sin(PI * k) * m
			down.append(0.0)
		if i < 2:
			p.hands[i] = at + Vector3(0, 0.2, -0.02)
		else:
			p.feet[i - 2] = at
	_knocks(down)
	# The body heaves: the chest thrown up as the hands push off, the haunches as the feet do.
	var heave_c := sin(TAU * (_phase - 0.12)) * lerpf(0.02, 0.07, g) * m
	var heave_p := sin(TAU * (_phase - 0.62)) * lerpf(0.02, 0.06, g) * m
	p.chest += Vector3(0.0, heave_c, 0.04 * g * m)
	p.pelvis += Vector3(0.0, heave_p, -0.02 * g * m)
	p.arch = 0.15 * sin(TAU * (_phase - 0.4)) * g * m
	p.roll = sin(TAU * _phase) * 0.06 * (1.0 - g) * m - clampf(_turn * _speed * 0.02, -0.2, 0.2)
	p.head_pitch = -0.15 + 0.08 * sin(TAU * 2.0 * _phase) * m
	p.jaw = 0.12 + 0.15 * g * m
	p.heel = 0.15 * g * m
	p.fingers = 0.2
	p.tail_lift = 0.12 * g * m
	# Wings folded slow, half open and lifting with each bound fast.
	var half := PackedFloat32Array(HALF)
	half[0] += 0.45 * sin(TAU * (_phase - 0.3))
	p.wing_l = wing_mix(PackedFloat32Array(FOLDED), half, g * m)
	p.wing_r = PackedFloat32Array(p.wing_l)
	# Breath.
	var breath := sin(_t * 1.6)
	p.chest.y += breath * 0.006
	return p


## Squatting on its ledge: knees up, hands gripping the edge between its feet,
## wings raised behind, peering down.
func _perched() -> Pose:
	var p := Pose.new()
	var breath := sin(_t * 1.3)
	p.pelvis = Vector3(0.0, 0.5, -0.3)
	p.chest = Vector3(0.0, 0.93 + breath * 0.006, 0.0)
	p.arch = 0.25
	p.feet = [Vector3(0.27, 0.0, 0.06), Vector3(-0.27, 0.0, 0.06)]
	p.heel = -0.35
	p.toes = 0.6
	p.hands = [Vector3(0.18, 0.22, 0.22), Vector3(-0.18, 0.22, 0.22)]
	p.hand_dir = Vector3(0.0, -0.75, 0.6)
	p.fingers = 0.9
	p.elbows_out = 0.9
	p.knees_out = 0.55
	p.head_pitch = 0.35
	p.neck_pitch = 0.1
	p.jaw = 0.1
	p.tail_lift = 0.2
	p.tail_curl = 1.0
	return p


## The wind-up for a pounce: sunk low, haunches up, wings raised, jaw open.
func _gathering() -> Pose:
	var p := Pose.new()
	var shiver := sin(_t * 31.0) * 0.006
	p.pelvis = Vector3(0.0, 0.68, -0.34)
	p.chest = Vector3(shiver, 0.8, 0.16)
	p.arch = 0.2
	p.hands = [Vector3(0.5, 0.2, 0.4), Vector3(-0.5, 0.2, 0.4)]
	p.feet = [Vector3(0.32, 0.0, -0.08), Vector3(-0.32, 0.0, -0.08)]
	p.heel = 0.25
	p.elbows_out = 0.9
	p.head_pitch = -0.05
	p.jaw = 0.55
	p.tail_lift = 0.5
	p.wing_l = PackedFloat32Array(RAISED)
	p.wing_r = PackedFloat32Array(RAISED)
	return p


## In the air: level, legs trailing (or thrust forward, reaching), wings beating or spread.
func _flying() -> Pose:
	var p := Pose.new()
	var r := _reach
	var bob := sin(TAU * (_beat + 0.6)) * 0.04 * _flap
	p.pelvis = Vector3(0.0, 0.95 + bob, -0.38)
	p.chest = Vector3(0.0, 1.08 + bob * 0.5, 0.12)
	p.arch = -0.1 + 0.25 * r
	p.hands = [Vector3(0.36, 0.72, 0.42).lerp(Vector3(0.42, 0.95, 0.85), r), Vector3(-0.36, 0.72, 0.42).lerp(Vector3(-0.42, 0.95, 0.85), r)]
	p.hand_dir = Vector3(0.0, -0.8, 0.5).lerp(Vector3(0.0, -0.1, 1.0), r)
	p.fingers = lerpf(0.6, -0.2, r)
	p.feet = [Vector3(0.24, 0.55, -0.75).lerp(Vector3(0.3, 0.38, 0.32), r), Vector3(-0.24, 0.55, -0.75).lerp(Vector3(-0.3, 0.38, 0.32), r)]
	p.heel = lerpf(1.1, 0.3, r)
	p.toes = lerpf(0.5, -0.3, r)
	p.knees_out = 0.45
	p.head_pitch = -0.35 + 0.2 * r
	p.jaw = 0.15 + 0.5 * r
	p.tail_lift = 0.35
	var wings := wing_mix(PackedFloat32Array(SPREAD), wing_beat(_beat, 1.0), _flap)
	# (reaching, the wings drawn up and back a little, braking)
	var braking := PackedFloat32Array(wings)
	braking[0] += 0.35
	braking[1] -= 0.25
	braking[7] += 0.2
	wings = wing_mix(wings, braking, r * (1.0 - _flap))
	p.wing_l = wings
	p.wing_r = PackedFloat32Array(wings)
	# Banked into turns.
	p.roll = clampf(-_turn * 0.25, -0.5, 0.5)
	return p


## Landed hard: slammed down low on its hands, head down, wings flung half open.
func _landed() -> Pose:
	var p := Pose.new()
	p.pelvis = Vector3(0.0, 0.6, -0.3)
	p.chest = Vector3(0.0, 0.72, 0.22)
	p.arch = 0.3
	p.hands = [Vector3(0.56, 0.2, 0.55), Vector3(-0.56, 0.2, 0.55)]
	p.feet = [Vector3(0.34, 0.0, -0.05), Vector3(-0.34, 0.0, -0.05)]
	p.elbows_out = 1.0
	p.head_pitch = 0.2
	p.jaw = 0.4
	p.tail_lift = 0.1
	p.wing_l = PackedFloat32Array(HALF)
	p.wing_r = PackedFloat32Array(HALF)
	return p


func _pose(dt: float) -> void:
	var p := _going()
	if _perch > 0.0:
		p = p.blend(_perched(), smoothstep(0.0, 1.0, _perch))
	if _gathered > 0.0:
		p = p.blend(_gathering(), smoothstep(0.0, 1.0, _gathered))
	if _air > 0.0:
		p = p.blend(_flying(), smoothstep(0.0, 1.0, _air))
	if _slam < 1.2:
		var hit := 1.0 - smoothstep(0.08, 1.2, _slam)
		hit *= smoothstep(0.0, 0.06, _slam) if _slam < 0.06 else 1.0
		p = p.blend(_landed(), hit * (1.0 - _air))
	if _snarl < 1.3:
		var s := sin(PI * clampf(_snarl / 1.3, 0.0, 1.0))
		p.jaw = maxf(p.jaw, 0.65 * s)
		p.head_pitch -= 0.25 * s
		p.neck_pitch -= 0.15 * s
		p.chest.y += 0.03 * s
		var flare := PackedFloat32Array(RAISED)
		p.wing_l = wing_mix(p.wing_l, flare, 0.35 * s * (1.0 - _air))
		p.wing_r = wing_mix(p.wing_r, flare, 0.35 * s * (1.0 - _air))
	_look(dt)
	_apply(p)
	_posed = true


## Where its eyes are: turned (gaze.x round, gaze.y up) towards `aim`, within what its neck allows.
func _look(dt: float) -> void:
	var want := Vector2.ZERO
	if aim.is_finite():
		var local := (global_transform.affine_inverse() * aim) / size - Vector3(0.0, 1.35, 0.6)
		want = Vector2(clampf(atan2(local.x, maxf(local.z, 0.05)), -1.1, 1.1), clampf(atan2(local.y, Vector2(local.x, local.z).length()), -0.9, 0.7))
	elif _perch > 0.5:
		want = Vector2(sin(_t * 0.23) * 0.5, -0.2)
	if dt <= 0.0 or not _posed:
		_gaze = want
	else:
		# (it turns its head slowly: stone grinding on stone)
		_gaze = _gaze.lerp(want, 1.0 - exp(-2.5 * dt))


# --- The skeleton ---

## A transform turning about `point` by `basis`.
static func _about(point: Vector3, basis: Basis) -> Transform3D:
	return Transform3D(basis, point - basis * point)


## A frame at `a` with Y along a to b and Z as near `n` as can be.
static func _frame(a: Vector3, b: Vector3, n: Vector3) -> Transform3D:
	var y := (b - a).normalized()
	var z := n - y * n.dot(y)
	if z.length_squared() < 0.000001:
		z = Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.UP
		z = z - y * z.dot(y)
	z = z.normalized()
	return Transform3D(Basis(y.cross(z), y, z), a)


## The middle joint of a limb from `a` to `target`, bones `l1` and `l2` long, bending towards `pole`.
static func _bend(a: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Vector3:
	var to := target - a
	var d := clampf(to.length(), absf(l1 - l2) + 0.01, (l1 + l2) * 0.999)
	var along := to.normalized()
	var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var side := pole - along * pole.dot(along)
	side = side.normalized() if side.length() > 0.001 else Vector3.UP
	return a + along * x + side * h


static func _head(bone: String) -> Vector3:
	return GargoyleRest.HEADS[bone]


static func _tail(bone: String) -> Vector3:
	return GargoyleRest.TAILS[bone]


func _apply(p: Pose) -> void:
	var d := {}
	# The trunk: turned from how it was modelled so that its spine runs from pelvis to chest.
	var p0 := _head("hips")
	var c0 := _head("chest") + (_tail("chest") - _head("chest")) * 0.0
	var spine0 := (_head("neck") - p0).normalized()
	var spine1 := (p.chest - p.pelvis).normalized()
	var up_rest := Basis(Vector3.RIGHT, spine0, Vector3.RIGHT.cross(spine0))
	var up_now := Basis(Vector3.RIGHT, spine1, Vector3.RIGHT.cross(spine1))
	var turn := Basis(Vector3.BACK, p.roll) * up_now * up_rest.inverse()
	var root := Transform3D(turn, p.pelvis - turn * p0)
	d["hips"] = root
	d["belly"] = root * _about(_head("belly"), Basis(Vector3.RIGHT, p.arch * 0.5))
	d["chest"] = d["belly"] * _about(c0, Basis(Vector3.RIGHT, p.arch * 0.5))
	var chest: Transform3D = d["chest"]
	d["neck"] = chest * _about(_head("neck"), Basis(Vector3.UP, _gaze.x * 0.4) * Basis(Vector3.RIGHT, p.neck_pitch - _gaze.y * 0.35))
	d["head"] = d["neck"] * _about(_head("head"), Basis(Vector3.UP, _gaze.x * 0.6) * Basis(Vector3.RIGHT, p.head_pitch - _gaze.y * 0.65))
	d["jaw"] = d["head"] * _about(_head("jaw"), Basis(Vector3.RIGHT, p.jaw - 0.12))
	# The tail: lifted from the root, curling, swaying.
	var tail := root
	for k in 8:
		var at: Vector3 = GargoyleRest.TAIL[k]
		var sway := sin(_t * 1.3 - k * 0.7) * 0.05 * (0.4 + _moving) + clampf(_turn, -2.0, 2.0) * 0.04
		var lift := (p.tail_lift * 0.45 if k < 2 else p.tail_lift * 0.1) - (0.12 * _air if k > 3 else 0.0)
		tail = tail * _about(at, Basis(Vector3.UP, sway + p.tail_curl * 0.22) * Basis(Vector3.RIGHT, lift))
		d["tail_%d" % (k + 1)] = tail
	# Limbs, each side.
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var s := "_l" if i == 0 else "_r"
		_arm(d, s, side, p, chest)
		_leg(d, s, side, p, root)
	# Wings.
	_wing(d, "_l", p.wing_l, chest, false)
	_wing(d, "_r", p.wing_r, chest, true)
	# Onto the skeleton (whose space may differ from the model's).
	var to_skel := _to_skeleton
	var from_skel := _to_skeleton.affine_inverse()
	for name: String in d:
		var g: Transform3D = to_skel * (d[name] as Transform3D) * from_skel * (_bone_rest[name] as Transform3D)
		var bone: int = _index[name]
		_skeleton.set_bone_pose_position(bone, g.origin)
		_skeleton.set_bone_pose_rotation(bone, g.basis.get_rotation_quaternion())
		_skeleton.set_bone_pose_scale(bone, g.basis.get_scale())


func _mirror(v: Vector3, side: float) -> Vector3:
	return Vector3(v.x * side, v.y, v.z)


func _arm(d: Dictionary, s: String, side: float, p: Pose, chest: Transform3D) -> void:
	var s0 := _head("upperarm" + s)
	var e0 := _head("forearm" + s)
	var w0 := _head("hand" + s)
	var k0 := _head("fingers" + s)
	var n0 := ((e0 - s0).cross(w0 - e0)).normalized()
	var shoulder := chest * s0
	var target: Vector3 = p.hands[0 if side > 0 else 1]
	var pole := chest.basis * Vector3(side * p.elbows_out, -0.2, -1.0)
	var upper := s0.distance_to(e0)
	var fore := e0.distance_to(w0)
	var elbow := _bend(shoulder, target, upper, fore, pole)
	var wrist := elbow + (target - elbow).normalized() * fore
	var n := ((elbow - shoulder).cross(wrist - elbow)).normalized()
	if n.dot(chest.basis * n0) < 0.0:
		n = -n
	d["upperarm" + s] = _frame(shoulder, elbow, n) * _frame(s0, e0, n0).affine_inverse()
	d["forearm" + s] = _frame(elbow, wrist, n) * _frame(e0, w0, n0).affine_inverse()
	var hand_dir := _mirror(p.hand_dir, side).normalized()
	var hand := _frame(wrist, wrist + hand_dir, n) * _frame(w0, k0, n0).affine_inverse()
	d["hand" + s] = hand
	# (the fingers curl about the knuckles, across the hand)
	var across := (hand.basis * (k0 - w0).normalized()).cross(hand.basis * n0).normalized()
	var knuckle := hand * k0
	d["fingers" + s] = _about(knuckle, Basis(across, p.fingers)) * hand


func _leg(d: Dictionary, s: String, side: float, p: Pose, root: Transform3D) -> void:
	var h0 := _head("thigh" + s)
	var k0 := _head("shin" + s)
	var a0 := _head("foot" + s)
	var b0 := _head("toes" + s)
	var t0 := _tail("toes" + s)
	var n0 := ((k0 - h0).cross(a0 - k0)).normalized()
	var hip := root * h0
	var ball: Vector3 = p.feet[0 if side > 0 else 1]
	var hock := ball + Basis(Vector3.RIGHT, p.heel) * (a0 - b0)
	var pole := root.basis * Vector3(side * p.knees_out, 0.1, 1.0)
	var thigh := h0.distance_to(k0)
	var shin := k0.distance_to(a0)
	var knee := _bend(hip, hock, thigh, shin, pole)
	var ankle := knee + (hock - knee).normalized() * shin
	ball = ankle + (ball - hock)
	var n := ((knee - hip).cross(ankle - knee)).normalized()
	if n.dot(root.basis * n0) < 0.0:
		n = -n
	d["thigh" + s] = _frame(hip, knee, n) * _frame(h0, k0, n0).affine_inverse()
	d["shin" + s] = _frame(knee, ankle, n) * _frame(k0, a0, n0).affine_inverse()
	d["foot" + s] = _frame(ankle, ball, n) * _frame(a0, b0, n0).affine_inverse()
	# (the toes flat ahead on the ground, or curled)
	var ahead := Basis(Vector3.RIGHT, p.toes) * (t0 - b0)
	d["toes" + s] = _frame(ball, ball + ahead, n) * _frame(b0, t0, n0).affine_inverse()


## A wing (left, or mirrored to the right) as a bat's hand, from its ten numbers:
## lift (raised about the body's length), sweep (forward), twist (leading edge
## up), elbow, wrist (bent in the plane of the wing), close (the fingers drawn
## in, folded back along the forearm), bend (the fingers bent up at the
## knuckles), cup (the hand cupped down at the wrist), tips (the outer bones
## folded back) and raise (the whole wing swung up over the back).
func _wing(d: Dictionary, s: String, w: PackedFloat32Array, chest: Transform3D, right: bool) -> void:
	var root := _head("wing_arm_l")
	var elbow := _head("wing_fore_l")
	var wrist := _head("wing_hand_l")
	var shoulder := _about(root, Basis(Vector3.RIGHT, w[9]) * Basis(Vector3.BACK, w[0]) * Basis(Vector3.UP, -w[1]) * Basis(Vector3.RIGHT, -w[2]))
	var fore := shoulder * _about(elbow, Basis(Vector3.UP, -w[3]))
	var hand := fore * _about(wrist, Basis(Vector3.UP, w[4]) * Basis(Vector3.BACK, -w[7]))
	var chain := {"wing_arm": shoulder, "wing_fore": fore, "wing_hand": hand}
	var fold_to := _angle(elbow - wrist) + 0.12
	for k: int in [2, 3, 4, 5]:
		var knuckle := _head("wing_d%db_l" % k)
		var tip := _tail("wing_d%db_l" % k)
		var fan: float = fold_to + (k - 5) * 0.06 - _angle(knuckle - wrist)
		var meta := hand * _about(wrist, Basis(Vector3.UP, fan * w[5]))
		var along := (tip - knuckle).normalized()
		var across := along.cross(Vector3.UP).normalized()
		var bend: float = w[6] * (0.6 + 0.2 * (k - 2)) - w[7] * 0.5
		var phal := meta * _about(knuckle, Basis(Vector3.UP, w[8] * (0.5 + 0.25 * (k - 2))) * Basis(across, bend))
		chain["wing_d%da" % k] = meta
		chain["wing_d%db" % k] = phal
	var mirror := Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)), Vector3.ZERO)
	for name: String in chain:
		var t: Transform3D = chain[name]
		if right:
			t = mirror * t * mirror
		d[name + s] = chest * t


## The angle of a direction in the plane of the wing (as Basis(UP, angle) turns +X to it).
static func _angle(v: Vector3) -> float:
	return atan2(-v.z, v.x)


## Notes when a hand or foot comes down (stone knocking on stone), while bounding on the ground.
func _knocks(down: Array[float]) -> void:
	for i in 4:
		var now := down[i] > 0.5
		if now and not _contacts[i] and _moving > 0.5 and _air < 0.1 and _knock and _life > 0.5:
			if not _knock.playing or _rng.randf() < 0.5:
				_knock.volume_db = volume_db - 14.0 + 6.0 * _gallop
				_knock.pitch_scale = _rng.randf_range(1.3, 1.7)
				_knock.play()
		_contacts[i] = now


# --- Dust ---

func _make_dust() -> void:
	var puff := _dust_material()
	_shed = CPUParticles3D.new()
	_shed.amount = 28
	_shed.lifetime = 1.8
	_shed.emitting = false
	_shed.local_coords = false
	_shed.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_shed.emission_box_extents = Vector3(0.45, 0.4, 0.5) * size
	_shed.position = Vector3(0.0, 0.95, 0.0) * size
	_shed.direction = Vector3.DOWN
	_shed.spread = 40.0
	_shed.initial_velocity_min = 0.1
	_shed.initial_velocity_max = 0.5
	_shed.gravity = Vector3(0.0, -1.6, 0.0)
	_shed.damping_min = 0.4
	_shed.damping_max = 1.0
	_shed.scale_amount_min = 0.05 * size
	_shed.scale_amount_max = 0.16 * size
	_shed.scale_amount_curve = _rise_curve()
	_shed.color = Color(0.62, 0.6, 0.55, 0.55)
	_shed.color_ramp = _fade()
	_shed.mesh = _puff_mesh(puff)
	_shed.material_override = puff
	add_child(_shed)
	_burst = CPUParticles3D.new()
	_burst.amount = 70
	_burst.lifetime = 2.2
	_burst.one_shot = true
	_burst.explosiveness = 0.92
	_burst.emitting = false
	_burst.local_coords = false
	_burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_burst.emission_ring_axis = Vector3.UP
	_burst.emission_ring_radius = 0.8 * size
	_burst.emission_ring_inner_radius = 0.2 * size
	_burst.emission_ring_height = 0.2
	_burst.position = Vector3(0.0, 0.15, 0.1) * size
	_burst.direction = Vector3(0.0, 0.25, 1.0)
	_burst.spread = 180.0
	_burst.flatness = 0.75
	_burst.initial_velocity_min = 1.5
	_burst.initial_velocity_max = 4.5
	_burst.gravity = Vector3(0.0, 0.25, 0.0)
	_burst.damping_min = 2.5
	_burst.damping_max = 4.0
	_burst.scale_amount_min = 0.25 * size
	_burst.scale_amount_max = 0.7 * size
	_burst.scale_amount_curve = _rise_curve()
	_burst.color = Color(0.6, 0.58, 0.53, 0.6)
	_burst.color_ramp = _fade()
	_burst.mesh = _puff_mesh(puff)
	_burst.material_override = puff
	add_child(_burst)
	# Pebbles: small chips of its stone, tumbling down from under it.
	_pebbles = CPUParticles3D.new()
	_pebbles.amount = 24
	_pebbles.lifetime = 2.2
	_pebbles.emitting = false
	_pebbles.local_coords = false
	_pebbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_pebbles.emission_box_extents = Vector3(0.5, 0.05, 0.15) * size
	_pebbles.position = Vector3(0.0, 0.05, 0.35) * size
	_pebbles.direction = Vector3(0.0, -0.3, 1.0)
	_pebbles.spread = 35.0
	_pebbles.initial_velocity_min = 0.4
	_pebbles.initial_velocity_max = 1.4
	_pebbles.gravity = Vector3(0.0, -9.8, 0.0)
	_pebbles.angular_velocity_min = -400.0
	_pebbles.angular_velocity_max = 400.0
	_pebbles.particle_flag_rotate_y = true
	_pebbles.scale_amount_min = 0.5
	_pebbles.scale_amount_max = 1.3
	var chip := BoxMesh.new()
	chip.size = Vector3(0.07, 0.05, 0.06) * size
	var chip_stone := StandardMaterial3D.new()
	chip_stone.albedo_color = Color(0.5, 0.49, 0.45)
	chip_stone.roughness = 1.0
	chip.material = chip_stone
	_pebbles.mesh = chip
	add_child(_pebbles)


static var _puff: StandardMaterial3D
static var _shadow_mat: ShaderMaterial


static func _dust_material() -> StandardMaterial3D:
	if _puff == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 0.0)
		texture.width = 64
		texture.height = 64
		_puff = StandardMaterial3D.new()
		_puff.albedo_texture = texture
		_puff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_puff.vertex_color_use_as_albedo = true
		_puff.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_puff.billboard_keep_scale = true
		_puff.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_puff.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _puff


static func _puff_mesh(material: Material) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = material
	return quad


static func _fade() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.12, Color(1, 1, 1, 1.0))
	g.add_point(0.6, Color(1, 1, 1, 0.55))
	return g


static func _rise_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.4))
	c.add_point(Vector2(1.0, 1.0))
	return c


static func _shadow_material() -> ShaderMaterial:
	if _shadow_mat == null:
		var shader := Shader.new()
		shader.code = """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
instance uniform float strength = 1.0;
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	ALBEDO = vec3(0.02, 0.02, 0.025);
	ALPHA = (1.0 - smoothstep(0.35, 1.0, r)) * 0.75 * strength;
}
"""
		_shadow_mat = ShaderMaterial.new()
		_shadow_mat.shader = shader
	return _shadow_mat


# --- Sound (made in code, once, and shared) ---

## Stone grinding on stone, a loop: a low rasping rumble, gritty, with the
## crackle of grains breaking in it.
static func grind_sound() -> AudioStreamWAV:
	if _sounds.has("grind"):
		return _sounds["grind"]
	var rate := 22050
	var length := 1.6
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var data := PackedFloat32Array()
	data.resize(count)
	var rasp := Band.new(170.0, 3.0, rate)
	var grit := Band.new(1300.0, 1.5, rate)
	var low := 0.0
	var crackle := 0.0
	for i in count:
		var t := float(i) / rate
		var n := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, n, 0.04)
		# (the rasp comes and goes, unevenly)
		var bite := 0.55 + 0.45 * sin(t * TAU * 2.5 + sin(t * TAU * 0.6) * 2.0) * sin(t * TAU * 1.25 + 1.0)
		if rng.randf() < 0.004:
			crackle = rng.randf_range(0.4, 1.0)
		crackle *= 0.985
		var v := low * 2.5 + rasp.run(n) * 1.6 * bite + grit.run(n) * (0.25 + crackle * 0.9) * bite
		data[i] = v
	return _store("grind", _loop_fade(data, int(rate * 0.12)), rate, true)


## It hits the ground: a deep thump, a burst of rubble, gravel trickling after.
static func crash_sound() -> AudioStreamWAV:
	if _sounds.has("crash"):
		return _sounds["crash"]
	var rate := 22050
	var length := 1.3
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var data := PackedFloat32Array()
	data.resize(count)
	var rubble := Band.new(600.0, 0.8, rate)
	var phase := 0.0
	var click := 0.0
	var low := 0.0
	for i in count:
		var t := float(i) / rate
		var pitch := 38.0 + 70.0 * exp(-t * 12.0)
		phase += pitch / rate
		var thump := sin(TAU * phase) * exp(-t * 7.0) * 1.4
		var n := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, n, 0.15)
		var burst := rubble.run(n) * exp(-t * 9.0) * 1.8 + low * exp(-t * 5.0) * 0.8
		# (gravel: clicks, thick at first and thinning)
		if rng.randf() < 0.02 * exp(-t * 2.5):
			click = rng.randf_range(0.3, 0.9) * (1.0 if rng.randf() < 0.5 else -1.0)
		click *= 0.86
		data[i] = thump + burst + click * 0.6 * smoothstep(0.03, 0.12, t)
	return _store("crash", data, rate, false)


## The beat of a great stone wing: a heavy swell of air.
static func whoosh_sound() -> AudioStreamWAV:
	if _sounds.has("whoosh"):
		return _sounds["whoosh"]
	var rate := 22050
	var length := 0.55
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var data := PackedFloat32Array()
	data.resize(count)
	var air := Band.new(420.0, 0.9, rate)
	var low := 0.0
	for i in count:
		var t := float(i) / length / rate
		var envelope := pow(sin(PI * t), 1.5) * (1.0 - t * 0.4)
		air.set_frequency(300.0 + 500.0 * sin(PI * t), 0.9)
		var n := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, n, 0.05)
		data[i] = (air.run(n) * 1.4 + low * 2.0) * envelope
	return _store("whoosh", data, rate, false)


## A growl through a throat of stone: a low, jittering voice over grinding grit,
## swelling and dying.
static func snarl_sound() -> AudioStreamWAV:
	if _sounds.has("snarl"):
		return _sounds["snarl"]
	var rate := 22050
	var length := 1.4
	var count := int(rate * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var data := PackedFloat32Array()
	data.resize(count)
	var throat: Array[Band] = [Band.new(320.0, 3.0, rate), Band.new(780.0, 4.0, rate), Band.new(2300.0, 5.0, rate)]
	var gains := [1.0, 0.6, 0.25]
	var grit := Band.new(1600.0, 1.2, rate)
	var phase := 0.0
	var wander := 0.0
	for i in count:
		var t := float(i) / rate
		var envelope := smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.9, length, t)) * (0.8 + 0.2 * sin(t * TAU * 3.0))
		wander = clampf(wander + rng.randf_range(-1.0, 1.0) * 0.1, -1.0, 1.0)
		var pitch := (58.0 + 18.0 * smoothstep(0.0, 0.5, t) - 14.0 * smoothstep(0.7, length, t)) * (1.0 + 0.12 * wander)
		phase += pitch / rate * (1.0 + rng.randf_range(-0.08, 0.08))
		var p := fposmod(phase, 1.0)
		var pulse := pow(1.0 - p, 6.0) * 2.0 - 0.3
		var voice := 0.0
		for k in throat.size():
			voice += throat[k].run(pulse) * gains[k]
		var n := rng.randf_range(-1.0, 1.0)
		data[i] = tanh((voice * 2.0 + grit.run(n) * 0.5 * (0.5 + 0.5 * (1.0 - p))) * 2.0) * envelope
	return _store("snarl", data, rate, false)


static func _loop_fade(data: PackedFloat32Array, overlap: int) -> PackedFloat32Array:
	# (the end faded into the start, so that the loop does not click)
	var n := data.size() - overlap
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = data[i]
	for i in overlap:
		var w := float(i) / overlap
		out[i] = data[i] * w + data[n + i] * (1.0 - w)
	return out


static func _store(key: String, samples: PackedFloat32Array, rate: int, looped: bool) -> AudioStreamWAV:
	var loudest := 0.001
	for v in samples:
		loudest = maxf(loudest, absf(v))
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] / loudest, -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = bytes
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	_sounds[key] = wav
	return wav


## A resonant band-pass filter (a biquad), for the sounds.
class Band:
	var _b0 := 0.0
	var _a1 := 0.0
	var _a2 := 0.0
	var _rate := 22050
	var _x1 := 0.0
	var _x2 := 0.0
	var _y1 := 0.0
	var _y2 := 0.0

	func _init(frequency: float, q: float, rate: int) -> void:
		_rate = rate
		set_frequency(frequency, q)

	func set_frequency(frequency: float, q: float) -> void:
		var w := TAU * frequency / _rate
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

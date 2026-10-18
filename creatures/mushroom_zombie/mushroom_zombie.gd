class_name MushroomZombie
extends Node3D
## A mushroom zombie: one of the boys, taken over by a fungus. His shirt and
## skin gone the grey of something left in a cellar, blotched, his hair matted;
## a mass of fruiting bodies has burst out of the top of his head (caps crowded
## out of a knot of it over his crown, shelves out of one temple and the back of
## his skull), clumps out of both shoulders, shelves down his spine; and pale
## mycelium spreads over him from where it broke through, in patches and
## threads, mats of it over his neck, chest and one side of his face. He does
## not walk: he is walked, in fits, like a puppet, and he clicks (the fungus,
## crackling through him).
##
## This is only how he looks, moves and sounds. He does no thinking: a game
## drives him (see MushroomZombieRig for the motion).
##
##     var zombie := MushroomZombie.new()
##     add_child(zombie)
##     # each frame, from your own body:
##     zombie.global_position = body_position
##     zombie.rotation.y = facing_yaw            # 0 faces +Z
##     zombie.velocity = body_velocity           # his feet go with this (fast, he lurches)
##     zombie.clicking = 0.3                     # how loud he clicks, 0..1 (more when he hunts)
##     zombie.frenzy = 0.0                       # how wildly he is worked, 0..1
##     zombie.aim = sound_position               # what he listens to and lunges at (INF: nothing)
##     # when you like:
##     zombie.listen()                           # he stops dead and turns his head to `aim`
##     zombie.lunge()                            # `closing` fires as his hands clamp: test grab_hits(point) while stage() is CLOSE
##     zombie.held = true                        # he has them: he clings
##     zombie.risen = 0.0                        # under the ground; `rise()` brings him up (RISE_TIME)
##
## He is one mesh of one material (models/mushroom_zombie.glb, made by
## tools/build_mushroom_zombie.py from the boy and the mushrooms' growths), so
## he costs one draw and its shadow. Needs GameCommon's character-controller
## (MushroomZombieRig extends CharacterRig; he has the boy's bones) and
## mushrooms (MushroomLook shades him; his growths glow faintly at night).

## His hands have begun to close in a lunge.
signal closing
## He is up out of the ground.
signal stood

const MODEL := "res://creatures/mushroom_zombie/models/mushroom_zombie.glb"
const MODEL_LO := "res://creatures/mushroom_zombie/models/mushroom_zombie_lo.glb"
## How long rising out of the ground takes, seconds.
const RISE_TIME := 3.2
## Past this he is not drawn at all (the mist has him), metres.
const FAR := 62.0

@export var low_poly := false
## His clicking, made in code.
@export var sound := true
@export var volume_db := -10.0
@export var sound_range := 34.0

var velocity := Vector3.ZERO
var grounded := true
var aim := Vector3.INF
var clicking := 0.3
var frenzy := 0.0
## 0 under the ground, 1 standing.
var risen := 1.0
var held := false:
	set(value):
		held = value
		if _rig:
			_rig.held = value

## For the rig, which reads its body as it would a Player's.
var is_pushing := false
var walk_speed: float:
	get:
		return 0.7
var run_speed: float:
	get:
		return 2.4

var _rig: MushroomZombieRig
var _voice: AudioStreamPlayer3D
var _closing := true
var _rising := 0.0
static var _clicks: AudioStreamWAV


func _ready() -> void:
	_rig = MushroomZombieRig.new()
	_rig.model = load(MODEL_LO if low_poly or Settings.low_poly else MODEL)
	_rig.looseness = 0.15
	add_child(_rig)
	for part: MeshInstance3D in _rig.find_children("*", "MeshInstance3D", true, false):
		part.visibility_range_end = FAR
		part.visibility_range_end_margin = 6.0
		part.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if sound:
		_voice = AudioStreamPlayer3D.new()
		_voice.stream = clicks_sound()
		_voice.volume_db = volume_db
		_voice.unit_size = 4.0
		_voice.max_distance = sound_range
		_voice.position = Vector3(0.0, 1.0, 0.0)
		add_child(_voice)
		_voice.play(randf() * 3.0)


func is_on_floor() -> bool:
	return grounded


func _process(delta: float) -> void:
	if _rising > 0.0:
		_rising = maxf(_rising - delta, 0.0)
		risen = 1.0 - _rising / RISE_TIME
		if _rising <= 0.0:
			stood.emit()
	_rig.aim = aim
	_rig.risen = risen
	_rig.frenzy = frenzy
	if not _closing and _rig._doing == MushroomZombieRig.Act.LUNGE and _rig.act_time() >= MushroomZombieRig.REACH:
		_closing = true
		closing.emit()
	if _voice:
		_voice.volume_db = volume_db + linear_to_db(0.08 + 0.92 * clampf(clicking, 0.0, 1.0)) if visible else -80.0
		_voice.pitch_scale = 1.0 + 0.25 * frenzy


## He stops dead and turns his head to `aim`, listening.
func listen() -> void:
	_rig.act(MushroomZombieRig.Act.LISTEN)


## He throws himself at `aim`, arms out, and claws shut: `closing` as they close.
func lunge() -> void:
	_rig.act(MushroomZombieRig.Act.LUNGE)
	_closing = false
	held = false


## Up out of the ground, over RISE_TIME (`stood` when he is up).
func rise() -> void:
	risen = 0.0
	_rising = RISE_TIME


func doing() -> MushroomZombieRig.Act:
	return _rig._doing if _rig else MushroomZombieRig.Act.NONE


func stage() -> MushroomZombieRig.Stage:
	return _rig.stage() if _rig else MushroomZombieRig.Stage.NONE


func busy() -> bool:
	return doing() != MushroomZombieRig.Act.NONE


static func act_length(what: MushroomZombieRig.Act) -> float:
	match what:
		MushroomZombieRig.Act.LISTEN:
			return MushroomZombieRig.TURN + MushroomZombieRig.LISTENING
		MushroomZombieRig.Act.LUNGE:
			return MushroomZombieRig.REACH + MushroomZombieRig.CLOSE + MushroomZombieRig.HOLD + MushroomZombieRig.RECOVER
	return 0.0


## Whether a point (world) is in his hands as they close: in front of him, out
## to the end of his lunge, within his height; `radius` more all round.
func grab_hits(point: Vector3, radius := 0.25, always := false) -> bool:
	if not always and stage() != MushroomZombieRig.Stage.CLOSE:
		return false
	var size := global_basis.get_scale().y
	var at := global_transform.affine_inverse() * point
	var r := radius / size
	return at.z > -0.1 - r and at.z < 0.95 + r and absf(at.x) < 0.45 + r and at.y > -r and at.y < 1.4 + r


## Where his head is in the world.
func head() -> Vector3:
	return _rig._head.global_position if _rig else global_position + Vector3.UP


## Puts him straight somewhere, standing as he is.
func put(at: Vector3, yaw: float) -> void:
	global_position = at
	rotation.y = yaw
	velocity = Vector3.ZERO
	if _rig:
		_rig.settle()


## His clicking, made once and shared, a loop of three seconds: dry clicks and
## crackles, like knuckles and gristle, or seed heads in a fire: sometimes one
## alone, sometimes a run of them fast, rattling, each a tiny burst of noise
## through a hollow, throaty ring.
static func clicks_sound() -> AudioStreamWAV:
	if _clicks:
		return _clicks
	var rate := 22050
	var count := rate * 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	var samples := PackedFloat32Array()
	samples.resize(count)
	var i := int(rate * 0.05)
	while i < count - rate / 10:
		# (a click, or a run of them)
		var run := 1 if rng.randf() < 0.55 else rng.randi_range(3, 9)
		var gap := rng.randf_range(0.012, 0.035)
		var pitch := rng.randf_range(1400.0, 3200.0)
		var loud := rng.randf_range(0.4, 1.0)
		for k in run:
			var at := i + int(k * gap * rate)
			var length := int(rate * 0.012)
			var hollow := rng.randf_range(380.0, 700.0)
			for j in length:
				if at + j >= count:
					break
				var t := float(j) / rate
				var burst := rng.randf_range(-1.0, 1.0) * exp(-t * 900.0)
				var ring := sin(TAU * pitch * t) * exp(-t * 500.0) * 0.6 + sin(TAU * hollow * t) * exp(-t * 220.0) * 0.5
				samples[at + j] += (burst * 0.5 + ring) * loud * (1.0 - 0.15 * k / maxf(run, 1.0))
		i += int(rate * (run * gap + rng.randf_range(0.08, 0.55)))
	var loudest := 0.001
	for value in samples:
		loudest = maxf(loudest, absf(value))
	var data := PackedByteArray()
	data.resize(count * 2)
	for k in count:
		data.encode_s16(k * 2, int(clampf(samples[k] / loudest, -1.0, 1.0) * 24000.0))
	_clicks = AudioStreamWAV.new()
	_clicks.format = AudioStreamWAV.FORMAT_16_BITS
	_clicks.mix_rate = rate
	_clicks.data = data
	_clicks.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_clicks.loop_end = count
	return _clicks

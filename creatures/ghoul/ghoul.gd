class_name Ghoul
extends Node3D
## A ghoul: a mummy with nothing left on, after the ReDeads of Zelda. Grey,
## starved, hunched, arms to its knees and a smooth mask of a face with round
## holes for eyes and a mouth hanging open. It stands like a statue until it is
## woken; then it shuffles, screams (a shriek that is meant to root whoever
## hears it to the spot) and grabs, hugging them to it.
##
## This is only how it looks, moves and sounds. It does no thinking: a game
## drives it. Put it where the creature is each frame and say how fast it is
## going, and call `scream()` and `grab()`; it tells you when the shriek goes
## out (`shrieked`) and whether a grab closes on a point (`grab_hits`).
##
##     var ghoul := Ghoul.new()
##     ghoul.scale = Vector3.ONE * 1.6       # modelled about 1.4 m tall
##     add_child(ghoul)
##     # each frame:
##     ghoul.global_position = body_position
##     ghoul.rotation.y = facing_yaw          # 0 faces +Z
##     ghoul.velocity = body_velocity         # world units a second
##     ghoul.awake = true                     # false: a statue
##     ghoul.aim = player_position + Vector3.UP # what it looks at and reaches for (INF: nothing)
##     ghoul.reaching = 1.0                    # how far its arms come up for `aim` when it is near
##     # when you like:
##     ghoul.scream()                         # `shrieked` is emitted at the top of it
##     ghoul.grab()                           # test `grab_hits(point)` while `stage()` is CLOSE
##     ghoul.held = true                      # it has them: it clings instead of hugging the air
##
## It is posed by GhoulRig (ghoul_rig.gd), which extends CharacterRig: it needs
## GameCommon's character-controller (CharacterRig, Player, Toon, Dust,
## Settings). The model is creatures/ghoul/models/ghoul.glb (and ghoul_lo.glb),
## made by creatures/ghoul/tools/build_ghoul.py in Blender.

## The shriek has gone out (the top of a scream): whoever is to be held by it is held now.
signal shrieked
## The arms of a grab have begun to close: test `grab_hits` from now until `stage()` is no longer CLOSE.
signal closing

const MODEL := "res://creatures/ghoul/models/ghoul.glb"
const MODEL_LO := "res://creatures/ghoul/models/ghoul_lo.glb"

## Use the low-poly model.
@export var low_poly := false
## Its shriek, made in code, from where it stands.
@export var sound := true
## How loud the shriek is, and how far off it is heard (world units).
@export var volume_db := 4.0
@export var sound_range := 60.0

## How fast it is going, world units a second. Its feet go with this.
var velocity := Vector3.ZERO
## Whether it is on the ground (off it, its legs hang).
var grounded := true
## A statue (false) or about (true). It wakes and falls still over a moment.
var awake := false
## What it looks at and reaches for, in the world (INF: nothing).
var aim := Vector3.INF
## How far its arms come up for `aim` when it is near to it, 0..1.
var reaching := 1.0
## In a grab: whether it has hold of someone.
var held := false:
	set(value):
		held = value
		if _rig:
			_rig.held = value

## For the rig, which reads its body as it would a Player's.
var is_pushing := false
var walk_speed: float:
	get:
		return 0.55 * global_basis.get_scale().y
var run_speed: float:
	get:
		return walk_speed * 3.0

var _rig: GhoulRig
var _voice: AudioStreamPlayer3D
var _shrieked := true
var _closing := true
static var _shriek: AudioStreamWAV


func _ready() -> void:
	_rig = GhoulRig.new()
	_rig.model = load(MODEL_LO if low_poly or Settings.low_poly else MODEL)
	_rig.looseness = 0.2
	add_child(_rig)
	if sound:
		_voice = AudioStreamPlayer3D.new()
		_voice.stream = shriek_sound()
		_voice.volume_db = volume_db
		_voice.unit_size = 8.0
		_voice.max_distance = sound_range
		_voice.position = Vector3(0.0, 1.3, 0.1)
		add_child(_voice)


func is_on_floor() -> bool:
	return grounded


func _process(_delta: float) -> void:
	_rig.awake = 1.0 if awake else 0.0
	_rig.aim = aim
	_rig.arms_reach = reaching
	var t := _rig.act_time()
	if not _shrieked and _rig._doing == GhoulRig.Act.SCREAM and t >= GhoulRig.SCREAM_RISE:
		_shrieked = true
		shrieked.emit()
	if not _closing and _rig._doing == GhoulRig.Act.GRAB and t >= GhoulRig.REACH:
		_closing = true
		closing.emit()


## Throws its head back and shrieks. `shrieked` is emitted when the sound goes
## out (SCREAM_RISE seconds on); the whole takes `act_length(GhoulRig.Act.SCREAM)`.
func scream() -> void:
	_rig.act(GhoulRig.Act.SCREAM)
	_shrieked = false
	if _voice:
		_voice.play()


## Throws its arms wide and hugs them closed in front of it. `closing` is
## emitted as they close (REACH seconds on); then, while `stage()` is CLOSE,
## `grab_hits` says whether a point is within them.
func grab() -> void:
	_rig.act(GhoulRig.Act.GRAB)
	_closing = false
	held = false


## What it is doing: GhoulRig.Act.NONE, SCREAM or GRAB.
func doing() -> GhoulRig.Act:
	return _rig._doing if _rig else GhoulRig.Act.NONE


## Where it is in what it is doing.
func stage() -> GhoulRig.Stage:
	return _rig.stage() if _rig else GhoulRig.Stage.NONE


func busy() -> bool:
	return doing() != GhoulRig.Act.NONE


## How long a scream or a grab takes, seconds.
static func act_length(what: GhoulRig.Act) -> float:
	match what:
		GhoulRig.Act.SCREAM:
			return GhoulRig.SCREAM_RISE + GhoulRig.SCREAMING + GhoulRig.SCREAM_FALL
		GhoulRig.Act.GRAB:
			return GhoulRig.REACH + GhoulRig.CLOSE + GhoulRig.HOLD + GhoulRig.LET_GO
	return 0.0


## Whether a point (in the world) is taken by its arms as they close: in front
## of it, within the reach of its arms and the height of its body, `radius`
## (world units) more all round. Only while `stage()` is CLOSE (or `always`).
func grab_hits(point: Vector3, radius := 0.25, always := false) -> bool:
	if not always and stage() != GhoulRig.Stage.CLOSE:
		return false
	var size := global_basis.get_scale().y
	var at := global_transform.affine_inverse() * point
	var r := radius / size
	return at.z > -0.05 - r and at.z < 0.85 + r and absf(at.x) < 0.42 + r and at.y > -r and at.y < 1.45 + r


## Where its mouth is in the world, for anything that should see it scream.
func mouth() -> Vector3:
	return to_global(Vector3(0.0, 1.28, 0.08))


## Puts it straight somewhere, standing still as it is.
func put(at: Vector3, yaw: float) -> void:
	global_position = at
	rotation.y = yaw
	velocity = Vector3.ZERO
	if _rig:
		_rig.awake = 1.0 if awake else 0.0
		_rig.settle()


## The shriek: a high, wavering scream over a rasp, rising and dying away. Made
## once and shared.
static func shriek_sound() -> AudioStreamWAV:
	if _shriek:
		return _shriek
	var rate := 22050
	var length := 1.35
	var count := int(rate * length)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var phase := 0.0
	var phase2 := 0.0
	var rasp := 0.0
	for i in count:
		var t := float(i) / rate
		var swell := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.8, length, t))
		# (it climbs, wavers, and sags at the end)
		var pitch := 820.0 + 380.0 * smoothstep(0.0, 0.25, t) - 260.0 * smoothstep(0.7, length, t) + 45.0 * sin(t * TAU * 7.0) + 20.0 * sin(t * TAU * 13.0)
		phase += TAU * pitch / rate
		phase2 += TAU * pitch * 1.503 / rate
		rasp = lerpf(rasp, rng.randf_range(-1.0, 1.0), 0.35)
		var voice := sin(phase) * 0.45 + sin(phase * 2.0) * 0.18 + sin(phase2) * 0.2 + signf(sin(phase * 0.5)) * 0.07
		var value := (voice * (0.75 + 0.25 * sin(t * TAU * 23.0)) + rasp * 0.35) * swell * 0.8
		data.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32000.0))
	_shriek = AudioStreamWAV.new()
	_shriek.format = AudioStreamWAV.FORMAT_16_BITS
	_shriek.mix_rate = rate
	_shriek.data = data
	return _shriek

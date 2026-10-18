class_name Flytrap
extends Node3D
## A giant Venus flytrap: a rosette at the foot of a wall, one great trap held
## out on its leaf over the ground (its two halves open in a V like a sprung
## man-trap, dull red inside, three trigger hairs standing up on each, long
## pale teeth round their rims and a band of glistening nectar inside them),
## four more leaves with small traps round it, and a tall stalk of white flowers.
##
## This is only how it looks, moves and sounds. It does no thinking: a game
## says when it is touched and when it shuts, and asks what is inside it.
##
##     var trap := Flytrap.new()
##     add_child(trap)                   # the rosette at its origin, the trap out along +Z
##     trap.twitch()                     # a hair is brushed: it shivers (the warning)
##     trap.snap()                       # it shuts: `snapped` fires the moment it is shut
##     trap.inside(point)                # whether a point (world) is between its halves
##     trap.reopen(8.0)                  # opens again, slowly, over 8 s
##     trap.full = true                  # shut on something: it bulges and goes dull
##
## Real flytraps shut when a hair is touched twice; this one shivers at the
## first touch, and the game shuts it if anything is still in it a moment later.

## It has shut (the halves have met).
signal snapped

## The parts of it, as modelled (tools/build_plants.py).
const LENGTH := 2.2
const WIDTH := 1.0
const HINGE := Vector3(0.0, 0.3, 0.0)
## How far each half is turned up from lying flat: open, shut (the rims meet), and squeezed on something.
const OPEN := 0.38
const SHUT := 1.64
const SQUEEZED := 1.72
## How long the snap takes, seconds.
const SNAP_TIME := 0.16
## How long a shiver at a touch lasts.
const TWITCH_TIME := 0.5

## Use the low-poly model.
@export var low_poly := false
## Its sounds, made in code: a dry creak when touched, a wet clap when it shuts.
@export var sound := true
@export var volume_db := -2.0
## Past this it is not drawn (the mist has it).
@export var far := 95.0

## How far it is shut, 0 (open) to 1, eased (read it; set it with snap/reopen).
var shut := 0.0
## Shut on something: squeezed tighter, bulging a little, gone dull as it digests.
var full := false
## The halves, each turned about its hinge.
var lobe_left: Node3D
var lobe_right: Node3D

var _material: ShaderMaterial
var _goal := 0.0
var _time := 0.0
var _twitch := 0.0
var _snapping := false
var _snap_from := 0.0
var _snap_time := 0.0
var _reopen_rate := 0.15
var _dull := 0.0
var _voice: AudioStreamPlayer3D
static var _creak: AudioStreamWAV
static var _clap: AudioStreamWAV


func _ready() -> void:
	var path := PlantLook.FLYTRAP_LO if low_poly or Settings.low_poly else PlantLook.FLYTRAP
	_material = PlantLook.material()
	var base := PlantLook.part(path, "flytrap_base", _material, far)
	add_child(base)
	# (the hinge is out along +Z from the rosette: the trap's middle is at z 0 in its own model)
	var trap := Node3D.new()
	trap.name = "Trap"
	trap.position = Vector3(0.0, 0.0, 1.95)
	base.position = Vector3(0.0, 0.0, 1.95)
	add_child(trap)
	for side in [1.0, -1.0]:
		var pivot := Node3D.new()
		pivot.position = HINGE
		trap.add_child(pivot)
		var half := PlantLook.part(path, "flytrap_lobe_l" if side > 0.0 else "flytrap_lobe_r", _material, far)
		pivot.add_child(half)
		if side > 0.0:
			lobe_left = pivot
		else:
			lobe_right = pivot
	if sound:
		_voice = AudioStreamPlayer3D.new()
		_voice.volume_db = volume_db
		_voice.unit_size = 6.0
		_voice.max_distance = 40.0
		_voice.position = Vector3(0.0, 0.6, 1.95)
		add_child(_voice)
	_pose(0.0)


func _process(delta: float) -> void:
	_time += delta
	if _snapping:
		_snap_time += delta
		var t := clampf(_snap_time / SNAP_TIME, 0.0, 1.0)
		shut = lerpf(_snap_from, 1.0, t * t)
		if t >= 1.0:
			_snapping = false
			snapped.emit()
	elif shut > _goal:
		shut = maxf(shut - _reopen_rate * delta, _goal)
	_twitch = maxf(_twitch - delta / TWITCH_TIME, 0.0)
	_dull = move_toward(_dull, 1.0 if full else 0.0, delta * 0.2)
	_pose(delta)


## Poses the halves: how far shut, a shiver at a touch, a slow breath while open,
## and a judder as they meet.
func _pose(_delta: float) -> void:
	if lobe_left == null:
		return
	var shiver := sin(_time * 70.0) * 0.05 * _twitch + 0.12 * sin(PI * (1.0 - _twitch)) * _twitch
	var breath := sin(_time * 0.9) * 0.012 * (1.0 - shut)
	var closed := SQUEEZED if full else SHUT
	# (shutting, it goes quickly at the end and the rims judder as the teeth mesh)
	var angle := lerpf(OPEN, closed, ease(shut, 0.6)) + shiver + breath
	if shut > 0.97:
		angle += sin(_time * 40.0) * 0.01 * clampf(1.0 - _snap_time / 0.4, 0.0, 1.0)
	lobe_left.rotation.z = angle
	lobe_right.rotation.z = -angle
	# (full, it bulges round what it holds)
	var swell := 1.0 + 0.08 * _dull
	lobe_left.scale = Vector3(swell, swell, 1.0)
	lobe_right.scale = Vector3(swell, swell, 1.0)
	_material.set_shader_parameter(&"dull", _dull)


## A trigger hair is brushed: it shivers, halfway towards shutting and back.
func twitch() -> void:
	if shut > 0.05 or _snapping:
		return
	_twitch = 1.0
	_play(creak_sound(), 1.0 + randf_range(-0.08, 0.08))


## Shuts, fast. `snapped` fires as the halves meet (SNAP_TIME on).
func snap() -> void:
	if _snapping or shut >= 0.99:
		return
	_snapping = true
	_snap_from = shut
	_snap_time = 0.0
	_goal = 1.0
	_twitch = 0.0
	_play(clap_sound(), 1.0 + randf_range(-0.06, 0.06))


## Opens again over `seconds` (and lets go of what it held).
func reopen(seconds := 8.0) -> void:
	_snapping = false
	_goal = 0.0
	_reopen_rate = 1.0 / maxf(seconds, 0.1)
	full = false


## Shut (or as good as), now.
func is_shut() -> bool:
	return shut > 0.9


## Open enough to take something.
func is_open() -> bool:
	return shut < 0.15 and not _snapping


func is_snapping() -> bool:
	return _snapping


## Straight to open or shut, nothing in motion (for a puppet that was not watching).
func set_shut(value: bool) -> void:
	_snapping = false
	shut = 1.0 if value else 0.0
	_goal = shut
	_pose(0.0)


## Where the middle of its trap is in the world.
func mouth() -> Vector3:
	return to_global(Vector3(0.0, HINGE.y + 0.25, 1.95))


## Whether a point (world) is between its open halves: over the inside of the
## trap, along its length, below the tips of its teeth; `radius` more all round.
func inside(point: Vector3, radius := 0.0) -> bool:
	var size := global_basis.get_scale().x
	var at := global_transform.affine_inverse() * point - Vector3(0.0, 0.0, 1.95)
	var r := radius / size
	var reach := WIDTH * cos(OPEN) * 0.95 + r
	return absf(at.z) < LENGTH * 0.5 * 0.92 + r and absf(at.x) < reach * (1.0 - 0.35 * pow(absf(at.z) / (LENGTH * 0.5), 2.0)) and at.y > -0.3 - r and at.y < 1.5 + r


func _play(stream: AudioStreamWAV, pitch: float) -> void:
	if _voice == null or not _voice.is_inside_tree():
		return
	_voice.stream = stream
	_voice.pitch_scale = pitch
	_voice.play()


## The creak of a touch: a dry, leathery rasp, quick, rising.
static func creak_sound() -> AudioStreamWAV:
	if _creak:
		return _creak
	var rate := 22050
	var count := int(rate * 0.42)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	var low := 0.0
	for i in count:
		var t := float(i) / rate
		var envelope := smoothstep(0.0, 0.03, t) * (1.0 - smoothstep(0.2, 0.42, t))
		# (a stick-slip creak: clicks at a rising rate, each a little burst of noise)
		phase += (40.0 + 120.0 * t) / rate
		var click := pow(1.0 - fposmod(phase, 1.0), 12.0)
		low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.3)
		samples[i] = (click * low * 2.5 + low * 0.15) * envelope
	_creak = PlantLook.wav(samples)
	return _creak


## The clap of it shutting: a hollow, wet slap, and the teeth rattling together.
static func clap_sound() -> AudioStreamWAV:
	if _clap:
		return _clap
	var rate := 22050
	var count := int(rate * 0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var samples := PackedFloat32Array()
	samples.resize(count)
	var low := 0.0
	var lower := 0.0
	for i in count:
		var t := float(i) / rate
		var noise := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.25)
		lower = lerpf(lower, low, 0.12)
		# The slap: a thump with a wet hiss in it, gone in a tenth of a second
		var slap := (sin(TAU * 95.0 * t) * 0.8 + lower * 3.0 + low * 0.8) * exp(-t * 26.0)
		# The teeth: a short dry rattle just after
		var rattle := 0.0
		if t > 0.03 and t < 0.25:
			rattle = low * (0.5 + 0.5 * sin(TAU * 31.0 * t)) * exp(-(t - 0.03) * 14.0) * 0.7
		samples[i] = tanh((slap + rattle) * 1.4)
	_clap = PlantLook.wav(samples)
	return _clap

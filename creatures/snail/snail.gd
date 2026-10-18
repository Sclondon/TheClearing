class_name Snail
extends Node3D
## A giant land snail, after the garden snail and the Roman snail: a real
## snail's shape made as big as a car. A long, wet, grey-brown foot rippling
## with the muscle waves a snail moves by, grooved all over into small raised
## tubercles that glisten; two long eye stalks with an eye at each tip and two
## short feelers under them; a coiled, right-handed shell nearly 4 m across,
## horn-brown with dark spiral bands, growth lines and a pale lip, the mantle's
## collar in its mouth with the breathing pore in it, opening and shutting. It
## leaves a broad trail of slime that lies a long time. Its look, its moves and
## its sounds are here; what it does is for the game to say. It knows nothing
## of the game it is in.
##
## HOW TO DRIVE IT. Put it on a surface and move it: its position is the front
## of its sole, under its head, and its basis says which way is up off the
## surface (+Y) and which way it is going (+Z), so it can crawl up a wall, over
## the top and down the other side: turn its up as the surface turns. Its body
## follows behind along the way its head went, draping over every edge, as a
## snail's does. It is as big as `scale` makes it (1: the foot 8 m long).
##
## Then say what it is doing:
## - `aim`: what its eye stalks reach for (INF for nothing: they wave about,
##   feeling the air, and its feelers tap the ground ahead).
## - `withdrawn`: in its shell (everything pulled in, the shell set down on the
##   ground); false, it comes out again, its stalks unrolling last.
## - `flinch(side)`: one eye stalk (0 its left, 1 its right, -1 both) rolls in
##   at a touch, and slowly out again.
## - `draw_in(node, seconds)`: something under its head is drawn down into the
##   slime under it over `seconds` (`drawn` as it goes under).
##
## Ask it:
## - `touches(point, radius)`: whether a ball there touches it (foot, head or shell).
## - `slime_at(point)`: how fresh the slime is there, 0 (none) to 1.
## - `eye_tip(side)`, `head_point()`, `shell_point()`.
##
## It plays its own sounds (made here in code, no files: the wet slither of
## its crawling, a squelch as it pulls in), unless `sound` is off.
##
## It is drawn by SnailRig (snail_rig.gd) on the model made by
## tools/build_snail.py with SnailLook's materials (snail_look.gd), and its
## trail by SnailSlime (snail_slime.gd): about four draws, and the same with
## `low_poly` (fewer triangles).

## It has gone into its shell, or come out.
signal withdrew
signal came_out
## Something it was drawing in has gone under.
signal drawn(node: Node3D)

## The demade, low-poly model. Set before it enters the tree.
@export var low_poly := false
## Leaves a trail of slime.
@export var trailing := true
## Seconds a patch of slime lies before it is gone.
@export var slime_life := 120.0
## Works out `velocity` from how it is moved (else the game sets it).
@export var measure_velocity := true
@export_group("Sound")
@export var sound := true
@export var volume_db := -4.0
@export var sound_range := 45.0

## How fast it is going, in the world.
var velocity := Vector3.ZERO
## What its eye stalks reach for, in the world (INF: nothing).
var aim := Vector3.INF
## In its shell.
var withdrawn := false:
	set(value):
		if value == withdrawn:
			return
		withdrawn = value
		if value:
			_squelch()
			withdrew.emit()
		else:
			came_out.emit()
var rig: SnailRig
var slime: SnailSlime

var _was_at := Vector3.INF
var _slither: AudioStreamPlayer3D
var _voice: AudioStreamPlayer3D
## What it is drawing in: [node, from, seconds so far, seconds in all].
var _drawing: Array = []

static var _slither_sound: AudioStreamWAV
static var _squelch_sound: AudioStreamWAV
static var _epoch := -1.0


func _ready() -> void:
	rig = SnailRig.new()
	rig.name = "Rig"
	rig.low_poly = low_poly
	add_child(rig)
	slime = SnailSlime.new()
	slime.name = "Slime"
	slime.life = slime_life
	add_child(slime)
	if sound:
		_slither = _player(2)
		_slither.stream = slither_sound()
		_slither.volume_db = -60.0
		_voice = _player(1)


## Seconds since the first snail began (every trail's clock).
static func clock() -> float:
	var now := Time.get_ticks_msec() / 1000.0
	if _epoch < 0.0:
		_epoch = now
	return now - _epoch


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var at := global_position
	if measure_velocity:
		if _was_at.is_finite():
			var moved := (at - _was_at) / delta
			if moved.length() > 40.0:
				# (put somewhere: not a speed)
				settle()
			else:
				velocity = velocity.lerp(moved, 1.0 - exp(-10.0 * delta))
		_was_at = at
	if trailing and visible and not withdrawn:
		slime.lay(global_transform, size() * 2.6)
	_draw_on(delta)
	if _slither:
		var speed := velocity.length() / size()
		var level := clampf(speed / 0.8, 0.0, 1.0) * (0.0 if withdrawn else 1.0)
		var want := linear_to_db(maxf(level, 0.0005)) + volume_db
		_slither.volume_db = move_toward(_slither.volume_db, want, 40.0 * delta)
		_slither.pitch_scale = lerpf(0.8, 1.1, level)
		if level > 0.02 and not _slither.playing:
			_slither.play(randf() * 2.0)
		elif level <= 0.02 and _slither.playing and _slither.volume_db < -50.0:
			_slither.stop()


## How big it is (its scale).
func size() -> float:
	return global_basis.get_scale().x


## Stands it as it is, with nothing in motion, its body laid straight out
## behind it along the surface: for when it is put somewhere.
func settle() -> void:
	velocity = Vector3.ZERO
	_was_at = global_position
	if rig:
		rig.settle()
	if slime:
		slime.cut()


## One eye stalk (0 its left, 1 its right; -1 both) rolls in, and slowly out again.
func flinch(side := -1) -> void:
	if rig:
		rig.flinch(side)


## Draws `node` down into the slime under its head over `seconds` (`drawn` as it goes under).
func draw_in(node: Node3D, seconds := 1.5) -> void:
	for one: Array in _drawing:
		if one[0] == node:
			return
	_drawing.append([node, node.global_position, 0.0, maxf(seconds, 0.1)])
	_squelch()
	if rig:
		rig.gulp()


## Whether it is drawing `node` in.
func drawing(node: Node3D) -> bool:
	for one: Array in _drawing:
		if one[0] == node:
			return true
	return false


## Lets go of whatever it is drawing in.
func let_go() -> void:
	_drawing.clear()


func _draw_on(delta: float) -> void:
	if _drawing.is_empty():
		return
	var up := global_basis.y.normalized()
	var ahead := global_basis.z.normalized()
	# (under the front of its head, and down into the slime)
	var under := global_position - ahead * 1.2 * size()
	for i in range(_drawing.size() - 1, -1, -1):
		var one: Array = _drawing[i]
		var node := one[0] as Node3D
		if not is_instance_valid(node):
			_drawing.remove_at(i)
			continue
		one[2] += delta
		var t: float = clampf(one[2] / one[3], 0.0, 1.0)
		var pull := smoothstep(0.0, 0.7, t)
		var sink := smoothstep(0.35, 1.0, t)
		node.global_position = (one[1] as Vector3).lerp(under, pull) - up * sink * 1.9
		# (it tips over backwards as it goes under)
		var tip := Basis(ahead.cross(up).normalized(), -sink * 1.1) if ahead.cross(up).length() > 0.1 else Basis()
		node.global_basis = tip * Basis(up, atan2(-ahead.x, -ahead.z) if absf(up.y) > 0.7 else 0.0)
		if t >= 1.0:
			_drawing.remove_at(i)
			drawn.emit(node)


## Whether a ball at `point` of `radius` touches it: its foot, its head or its shell.
func touches(point: Vector3, radius := 0.3) -> bool:
	return rig != null and rig.touches(point, radius)


## How fresh its slime is at `point`, 0 (none) to 1.
func slime_at(point: Vector3) -> float:
	return slime.fresh_at(point) if slime else 0.0


func eye_tip(side: int) -> Vector3:
	return rig.eye_tip(side) if rig else global_position


func head_point() -> Vector3:
	return rig.head_point() if rig else global_position


func shell_point() -> Vector3:
	return rig.shell_point() if rig else global_position


# --- Sound ---

func _player(polyphony: int) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.unit_size = 8.0
	player.max_distance = sound_range
	player.volume_db = volume_db
	player.max_polyphony = polyphony
	add_child(player)
	return player


func _squelch() -> void:
	if _voice == null or not is_inside_tree():
		return
	_voice.stream = squelch_sound()
	_voice.volume_db = volume_db + 2.0
	_voice.pitch_scale = randf_range(0.85, 1.05)
	_voice.play()


## Its crawling: a soft, wet, sticky slither, a loop of two seconds.
static func slither_sound() -> AudioStreamWAV:
	if _slither_sound:
		return _slither_sound
	var rate := 22050
	var count := rate * 2
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var samples := PackedFloat32Array()
	samples.resize(count)
	var low := 0.0
	var high := 0.0
	var pops := 0.0
	for i in count:
		var t := float(i) / rate
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.06
		high += (noise - high) * 0.5
		# (the slow surge of the waves along the foot, and small sticky pops as it lets go of the ground)
		var surge := 0.55 + 0.45 * sin(TAU * t * 1.5) * sin(TAU * t * 0.5)
		if rng.randf() < 0.0016:
			pops = 1.0
		pops *= 0.993
		var pop := pops * sin(TAU * t * (380.0 + 200.0 * pops)) * 0.6
		samples[i] = (low * 1.6 + (high - low) * 0.12) * surge + pop
	# (the loop's ends meet)
	var fade := rate / 20
	for i in fade:
		var k := float(i) / fade
		samples[i] = samples[i] * k + samples[count - fade + i] * (1.0 - k)
	samples = samples.slice(0, count - fade)
	_slither_sound = _wave(samples, rate)
	_slither_sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_slither_sound.loop_end = samples.size()
	return _slither_sound


## Pulling in, or drawing something in: a thick wet squelch, sucked down.
static func squelch_sound() -> AudioStreamWAV:
	if _squelch_sound:
		return _squelch_sound
	var rate := 22050
	var count := int(rate * 0.7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var samples := PackedFloat32Array()
	samples.resize(count)
	var low := 0.0
	var phase := 0.0
	for i in count:
		var t := float(i) / rate
		var level := minf(t / 0.03, 1.0) * pow(maxf(1.0 - t / 0.7, 0.0), 1.5)
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.12
		# (a falling, gurgling tone under the wet noise)
		phase += (160.0 - 90.0 * t + 40.0 * sin(t * 50.0)) / rate
		samples[i] = (low * 1.2 + sin(TAU * phase) * 0.5) * level
	_squelch_sound = _wave(samples, rate)
	return _squelch_sound


static func _wave(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var loudest := 0.001
	for value in samples:
		loudest = maxf(loudest, absf(value))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] / loudest, -1.0, 1.0) * 26000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream

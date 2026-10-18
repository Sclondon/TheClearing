class_name MushroomPatch
extends Node3D
## Mushrooms, a lot of them for very little: tufts of honey fungus at the foot
## of a wall and on the ground, bracket fungi in shelves up a wall, tall pale
## bonnets that glow in the dark, and giant puffballs that puff spores when
## trodden near. Each kind is one MultiMesh (one draw, and its shadow), drawn
## only near (`far`).
##
##     var patch := MushroomPatch.new()
##     add_child(patch)
##     patch.tuft(at, rng)                         # a tuft of honey fungus on the ground there (world)
##     patch.shelves(at, wall_normal, rng)         # brackets in tiers up a wall, from a point at its foot
##     patch.bonnets(at, rng)                      # a cluster of tall glowing bonnets
##     var ball := patch.add_puffball(at, 1.6)     # a puffball (its index), 1.6 times modelled size
##     patch.build()                               # makes what has been added
##     patch.puff(ball)                            # it squashes and its spores come out (`puffed` fires)
##     patch.regrow(ball)                          # slowly swells back up
##     MushroomLook.set_night(0.8)                 # how much every patch glows
##
## A puff's spores are a `SporeCloud` (spore_cloud.gd): put one where `puffed` says.
## Positions are in the world; the patch itself can be anywhere.

## A puffball has puffed: where its pore is (world) and how big it is.
signal puffed(at: Vector3, size: float)

enum Kind { HONEY, BRACKET, STALK, PUFFBALL }
const NAMES := ["honey", "bracket", "stalk", "puffball"]

## Past this they are not drawn.
@export var far := 75.0
@export var low_poly := false
## Its sounds: the soft cough of a puffball.
@export var sound := true
@export var volume_db := -6.0

## Where each puffball is (world), how big, how squashed now (1 spent), and how fast it is swelling back.
var puffballs: Array[Vector3] = []
var puffball_sizes: Array[float] = []
var spent: Array[float] = []

var _placed := {}
var _multis := {}
var _swelling: Array[float] = []
var _voice: AudioStreamPlayer3D
static var _cough: AudioStreamWAV


func _ready() -> void:
	if sound:
		_voice = AudioStreamPlayer3D.new()
		_voice.volume_db = volume_db
		_voice.unit_size = 5.0
		_voice.max_distance = 30.0
		add_child(_voice)


## Puts one of `kind` there (a transform in the world: its foot, its up, its size).
func add(kind: Kind, where: Transform3D) -> int:
	if not _placed.has(kind):
		_placed[kind] = []
	(_placed[kind] as Array).append(where)
	return (_placed[kind] as Array).size() - 1


## A tuft of honey fungus on the ground at `at` (world): a dozen or so, the
## middle ones tallest, leaning out; `size` times as big as real ones.
func tuft(at: Vector3, rng: RandomNumberGenerator, size := 3.0, count := 0) -> void:
	var many := count if count > 0 else rng.randi_range(7, 14)
	for k in many:
		var round_about := rng.randf() * TAU
		var out := sqrt(rng.randf()) * 0.16 * size
		var lean := out / (0.16 * size) * 0.55
		var spot := at + Vector3(cos(round_about), 0.0, sin(round_about)) * out
		var basis := Basis(Vector3(-sin(round_about), 0.0, cos(round_about)), lean) * Basis(Vector3.UP, rng.randf() * TAU)
		var grown := size * rng.randf_range(0.6, 1.25) * (1.0 - 0.35 * out / (0.16 * size))
		add(Kind.HONEY, Transform3D(basis.scaled(Vector3.ONE * grown), spot))


## Bracket fungi in tiers up a wall from `foot` (a point on its face at the
## ground, world), the wall facing `normal`; `height` how far up they go.
func shelves(foot: Vector3, normal: Vector3, rng: RandomNumberGenerator, height := 2.5, size := 2.0) -> void:
	normal = Vector3(normal.x, 0.0, normal.z).normalized()
	var along := normal.cross(Vector3.UP)
	var tiers := rng.randi_range(3, 7)
	var y := rng.randf_range(0.15, 0.6)
	for k in tiers:
		y += rng.randf_range(0.12, 0.5) * height / 2.5
		if y > height:
			break
		var spot := foot + Vector3.UP * y + along * rng.randf_range(-0.5, 0.5) * size * 0.4
		# (modelled growing out along +z from its back at z 0: turned so that it grows out of the wall)
		var basis := Basis(Vector3.UP.cross(normal), Vector3.UP, normal)
		var grown := size * rng.randf_range(0.5, 1.4) * (1.0 - 0.4 * y / height)
		add(Kind.BRACKET, Transform3D(basis.rotated(normal, rng.randf_range(-0.2, 0.2)).scaled(Vector3.ONE * grown), spot))


## A cluster of tall pale bonnets at `at` (world), the kind that glows.
func bonnets(at: Vector3, rng: RandomNumberGenerator, size := 2.5) -> void:
	for k in rng.randi_range(4, 9):
		var round_about := rng.randf() * TAU
		var spot := at + Vector3(cos(round_about), 0.0, sin(round_about)) * rng.randf_range(0.0, 0.18) * size
		var basis := Basis(Vector3(-sin(round_about), 0.0, cos(round_about)), rng.randf_range(0.0, 0.3)) * Basis(Vector3.UP, rng.randf() * TAU)
		add(Kind.STALK, Transform3D(basis.scaled(Vector3.ONE * size * rng.randf_range(0.6, 1.4)), spot))


## A puffball on the ground at `at` (world), `size` times as big as modelled
## (modelled 0.3 across); its index, for `puff`.
func add_puffball(at: Vector3, size := 1.6) -> int:
	puffballs.append(at)
	puffball_sizes.append(size)
	spent.append(0.0)
	_swelling.append(0.0)
	return add(Kind.PUFFBALL, Transform3D(Basis(Vector3.UP, float(puffballs.size()) * 2.1).scaled(Vector3.ONE * size), at))


## Makes what has been added, each kind one MultiMesh.
func build() -> void:
	for kind: Kind in _placed:
		var placed: Array = _placed[kind]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		# (and colours, all white: without them a MultiMesh loses the vertex colours in GL Compatibility)
		multi.use_colors = true
		multi.mesh = MushroomLook.mesh(NAMES[kind], low_poly)
		multi.instance_count = placed.size()
		for i in placed.size():
			var where: Transform3D = placed[i]
			multi.set_instance_transform(i, Transform3D(where.basis, to_local(where.origin)) if is_inside_tree() else where)
			# (custom: how squashed, how much it sways, its own phase)
			multi.set_instance_custom_data(i, Color(0.0, 0.3 if kind == Kind.STALK else 0.1, randf(), 0.0))
			multi.set_instance_color(i, Color.WHITE)
		var shown := MultiMeshInstance3D.new()
		shown.name = NAMES[kind].capitalize()
		shown.multimesh = multi
		shown.material_override = MushroomLook.shared()
		shown.visibility_range_end = far
		shown.visibility_range_end_margin = 10.0
		shown.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		# (only the shelves and the puffballs are big enough for their shadows to be seen)
		if kind == Kind.HONEY or kind == Kind.STALK:
			shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shown)
		_multis[kind] = multi
	set_process(not puffballs.is_empty())


func _process(delta: float) -> void:
	var multi: MultiMesh = _multis.get(Kind.PUFFBALL)
	if multi == null:
		return
	for i in puffballs.size():
		var before := spent[i]
		if _swelling[i] > 0.0:
			spent[i] = maxf(spent[i] - delta * _swelling[i], 0.0)
			if spent[i] <= 0.0:
				_swelling[i] = 0.0
		if spent[i] != before:
			var custom := multi.get_instance_custom_data(i)
			custom.r = spent[i] * 0.85
			multi.set_instance_custom_data(i, custom)


## Squashes puffball `index` flat as its spores come out (`puffed`). Spent, it
## stays flat until `regrow`.
func puff(index: int) -> void:
	if index < 0 or index >= puffballs.size() or spent[index] > 0.5:
		return
	spent[index] = 1.0
	_swelling[index] = 0.0
	var multi: MultiMesh = _multis.get(Kind.PUFFBALL)
	if multi:
		var custom := multi.get_instance_custom_data(index)
		custom.r = 0.85
		multi.set_instance_custom_data(index, custom)
	if _voice and _voice.is_inside_tree():
		_voice.global_position = puffballs[index]
		_voice.stream = cough_sound()
		_voice.pitch_scale = randf_range(0.85, 1.15)
		_voice.play()
	puffed.emit(pore(index), puffball_sizes[index])


## Swells puffball `index` back up over `seconds`.
func regrow(index: int, seconds := 20.0) -> void:
	if index >= 0 and index < puffballs.size():
		_swelling[index] = 1.0 / maxf(seconds, 0.1)


## Whether puffball `index` is ripe (swollen, and not yet puffed).
func ripe(index: int) -> bool:
	return index >= 0 and index < puffballs.size() and spent[index] <= 0.0


## Where puffball `index`'s pore is (world).
func pore(index: int) -> Vector3:
	return puffballs[index] + Vector3.UP * 0.27 * puffball_sizes[index]


## How many of each kind (for a test).
func count(kind: Kind) -> int:
	return (_placed.get(kind, []) as Array).size()


## The soft cough of a puffball: a breathy puff, low, with a dry rattle in it.
static func cough_sound() -> AudioStreamWAV:
	if _cough:
		return _cough
	var rate := 22050
	var count_samples := int(rate * 0.7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var samples := PackedFloat32Array()
	samples.resize(count_samples)
	var low := 0.0
	var lower := 0.0
	for i in count_samples:
		var t := float(i) / rate
		var noise := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.2)
		lower = lerpf(lower, low, 0.15)
		var breath := (low * 0.6 + lower * 1.6) * smoothstep(0.0, 0.02, t) * exp(-t * 6.0)
		var thump := sin(TAU * 70.0 * t) * exp(-t * 30.0) * 0.6
		samples[i] = breath + thump
	var loudest := 0.001
	for value in samples:
		loudest = maxf(loudest, absf(value))
	var data := PackedByteArray()
	data.resize(count_samples * 2)
	for i in count_samples:
		data.encode_s16(i * 2, int(clampf(samples[i] / loudest, -1.0, 1.0) * 26000.0))
	_cough = AudioStreamWAV.new()
	_cough.format = AudioStreamWAV.FORMAT_16_BITS
	_cough.mix_rate = rate
	_cough.data = data
	return _cough

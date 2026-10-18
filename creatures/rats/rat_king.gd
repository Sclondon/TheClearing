class_name RatKing
extends Node3D
## A rat king: eight to fourteen rats whose tails are fused and tangled together
## in a matted knot at the middle, a writhing, squealing wheel of bodies, each
## rat facing out and pulling its own way, the rest dragged backwards and
## sideways, some heaved up over the knot and some on their backs with their
## legs going. It drags itself along slowly and unevenly, which way being
## whichever rats are pulling hardest at the moment. How it looks and moves,
## and nothing of what it means: whoever drives it says which way it would go
## (`wish`, and how hard, `urge`), and moves it by its `drift` (or lets it move
## itself, `moves_itself`).
##
##     var king := RatKing.new()
##     king.count = 11
##     add_child(king)
##     king.wish = (where_to - king.global_position).normalized()   # (level)
##     king.urge = 1.0                     # 0: it only writhes where it is
##     king.squeal()                        # all of them rear and shriek at once
##     king.frenzy()                        # a lunge of teeth all round (a catch)
##
## - PULLING. Each rat pulls in its own fits (a few a second, at its own
##   rate): pulling, it strains outward (its tail stretching out of the knot)
##   with its legs scrabbling; between fits it is dragged, its feet sliding and
##   backpedalling, bent round, now and then rearing to squeak. Rats facing the
##   way it would go pull more often and harder (more so the higher `urge`), so
##   it gets there, but each lurch is the sum of whoever is pulling just then:
##   it goes in jerks, wanders off the line, and turns slowly about itself.
##   `drift` is the velocity that comes to (no faster than 1.6 times `speed`).
## - THE KNOT. A matted lump of tails and filth at the middle (RatLook.knot), the
##   rats' own tails curling into it (the shader winds them round), jerked about
##   by the pulling.
## - SQUEALING. `squeal()`: every rat rears and screams (RatVoice.shriek) for
##   `squeal_time`, the wheel thrashing. Writhing, it squeaks and chitters
##   (RatVoice.writhing, quietly, in a loop). `frenzy()`: every rat lunges out
##   snapping for a moment.
##
## The cost is flat: one MultiMesh for the rats (the full rat, one draw) and
## the knot (one more), the rats posed here in one loop and in the shader.

## How many rats.
@export_range(3, 16) var count := 11
## How big each rat is (1: an ordinary brown rat, 25 cm nose to rump).
@export var rat_size := 1.1
## How fast it drags itself, at most, pulling all one way (m/s).
@export var speed := 0.9
## How often a rat pulls, fits a second (each its own, about this).
@export var pull_rate := 1.1
@export var squeal_time := 1.6
@export var king_seed := 0
## It moves itself by its `drift` (with nothing in its way); off: whoever drives it does.
@export var moves_itself := true
@export var voice := true
@export var volume_db := 0.0

## Which way it would go (level, a unit long, or zero), and how hard (0 to 1).
var wish := Vector3.ZERO
var urge := 0.0
## The velocity its pulling comes to now.
var drift := Vector3.ZERO
## How fast it turns about itself now (radians a second), from its rats pulling aslant.
var spin := 0.0

var _time := 0.0
var _squeal := 0.0
var _frenzy := 0.0

var _rng := RandomNumberGenerator.new()
var _drawn: MultiMeshInstance3D
var _knot: MeshInstance3D
var _buffer := PackedFloat32Array()
var _cry: AudioStreamPlayer3D
var _writhe: AudioStreamPlayer3D

# Each rat: which way it faces out (radians), how far its rump is from the middle, how high and how tipped it
# lies (over the knot or on its back), its fit of pulling, how far out it is straining, and its pose.
var _turn := PackedFloat32Array()
var _rump := PackedFloat32Array()
var _high := PackedFloat32Array()
var _pitch := PackedFloat32Array()
var _roll := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _rate := PackedFloat32Array()
var _pull := PackedFloat32Array()
var _out := PackedFloat32Array()
var _stride := PackedFloat32Array()
var _bend := PackedFloat32Array()
var _rear := PackedFloat32Array()
var _cry_in := PackedFloat32Array()
var _own := PackedFloat32Array()
var _big := PackedFloat32Array()
var _top := PackedByteArray()


func _ready() -> void:
	_rng.seed = king_seed * 7919 + 101
	for list: PackedFloat32Array in [_turn, _rump, _high, _pitch, _roll, _phase, _rate, _pull, _out, _stride, _bend, _rear, _cry_in, _own, _big]:
		list.resize(count)
	_top.resize(count)
	# (about two in three round the knot on the ground, the rest heaved up over it, one or two on their backs)
	var over := maxi(count / 4, 1)
	var start := _rng.randf() * TAU
	for i in count:
		var on_top := i >= count - over
		_turn[i] = start + TAU * i / (count - over) + _rng.randf_range(-0.3, 0.3) if not on_top else _rng.randf() * TAU
		_rump[i] = _rng.randf_range(0.06, 0.085) if not on_top else _rng.randf_range(0.03, 0.06)
		_high[i] = _rng.randf_range(0.008, 0.02) if not on_top else _rng.randf_range(0.05, 0.09)
		_top[i] = 1 if on_top else 0
		_pitch[i] = _rng.randf_range(0.04, 0.16) if not on_top else _rng.randf_range(-0.5, 0.25)
		_roll[i] = _rng.randf_range(-0.15, 0.15) if not on_top else (PI + _rng.randf_range(-0.4, 0.4) if i % 2 == 0 else _rng.randf_range(0.9, 1.6) * (1.0 if _rng.randf() < 0.5 else -1.0))
		_phase[i] = _rng.randf() * TAU
		_rate[i] = pull_rate * _rng.randf_range(0.6, 1.5)
		_stride[i] = _rng.randf() * 8.0
		_cry_in[i] = _rng.randf_range(0.5, 4.0)
		_own[i] = _rng.randf()
		_big[i] = rat_size * _rng.randf_range(0.88, 1.08)
	_drawn = MultiMeshInstance3D.new()
	_drawn.name = "Rats"
	_drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.use_custom_data = true
	many.mesh = RatLook.mesh(false)
	many.instance_count = count
	_drawn.multimesh = many
	_drawn.custom_aabb = AABB(Vector3(-0.8, -0.2, -0.8), Vector3(1.6, 0.8, 1.6))
	add_child(_drawn)
	_buffer.resize(count * 16)
	_knot = MeshInstance3D.new()
	_knot.name = "Knot"
	_knot.mesh = RatLook.knot()
	_knot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_knot.scale = Vector3.ONE * rat_size * 1.35
	add_child(_knot)
	if voice:
		_writhe = AudioStreamPlayer3D.new()
		_writhe.unit_size = 3.0
		_writhe.max_distance = 22.0
		_writhe.volume_db = volume_db - 8.0
		add_child(_writhe)
		_cry = AudioStreamPlayer3D.new()
		_cry.unit_size = 14.0
		_cry.max_distance = 90.0
		_cry.volume_db = volume_db + 2.0
		add_child(_cry)
	_pose(0.0)


## Every rat rears and shrieks at once, the wheel thrashing, for `squeal_time`.
func squeal() -> void:
	_squeal = squeal_time
	if _cry:
		_cry.stream = RatVoice.shriek()
		_cry.play()


## Whether it is squealing now.
func squealing() -> bool:
	return _squeal > 0.0


## Every rat lunges out snapping for a moment.
func frenzy() -> void:
	_frenzy = 0.8


## How far its rats reach from the middle of it, about (their noses), metres.
func reach() -> float:
	return (0.085 + RatLook.LENGTH + 0.03) * rat_size


## The rats' places (their middles), for tests and pictures.
func rat_position(i: int) -> Vector3:
	return global_transform * Vector3(_buffer[i * 16 + 3], _buffer[i * 16 + 7], _buffer[i * 16 + 11])


## How hard rat `i` is pulling now (0 to 1).
func pulling(i: int) -> float:
	return _pull[i]


func _process(delta: float) -> void:
	_time += delta
	_squeal -= delta
	_frenzy -= delta
	if _writhe and not _writhe.playing and is_inside_tree():
		_writhe.stream = RatVoice.writhing()
		_writhe.play(_rng.randf() * 2.0)
	_pose(delta)
	if moves_itself:
		global_position += drift * delta
		rotation.y += spin * delta


# Each rat's fit of pulling, its pose, and what it all comes to.
func _pose(delta: float) -> void:
	var level := Vector3(wish.x, 0.0, wish.z)
	level = level.normalized() if level.length() > 0.01 else Vector3.ZERO
	var yaw := global_rotation.y
	var sum := Vector3.ZERO
	var turning := 0.0
	var wild := 1.0 + (1.5 if _squeal > 0.0 else 0.0) + (2.0 if _frenzy > 0.0 else 0.0)
	var strength := 0.0
	for i in count:
		var turn := _turn[i] + sin(_time * 0.7 + _own[i] * 20.0) * 0.12
		var out_local := Vector3(sin(turn), 0.0, cos(turn))
		var out_world := out_local.rotated(Vector3.UP, yaw)
		# (those facing the way it would go pull oftener and harder)
		var facing := out_world.dot(level) if level != Vector3.ZERO else 0.0
		var keen := clampf(0.55 + facing * 0.6 * urge, 0.15, 1.2)
		_phase[i] += delta * TAU * _rate[i] * (0.6 + 0.7 * urge) * (0.7 + keen * 0.5) * wild
		if _phase[i] > TAU:
			_phase[i] -= TAU
			_rate[i] = pull_rate * _rng.randf_range(0.55, 1.6)
		var fit := maxf(sin(_phase[i]), 0.0)
		var pull := fit * keen
		if _top[i] == 1:
			# (heaved up over the knot, they cannot pull: they squirm)
			pull *= 0.2
		_pull[i] = pull
		sum += out_world * pull
		turning += pull * sin(_own[i] * 31.0) * 0.6
		strength += pull
		var lunge := 0.04 if _frenzy > 0.0 else 0.0
		_out[i] = lerpf(_out[i], 0.05 * pull + lunge, minf(delta * 10.0, 1.0))
		# (pulling, the legs scrabble forward; dragged, they slide back)
		var going := 0.85 + 0.15 * pull if pull > 0.15 else 0.25
		var dragged := drift.length() * -out_world.dot(drift.normalized()) if drift.length() > 0.01 else 0.0
		var steps := (7.0 + 5.0 * pull) * (1.0 if pull > 0.15 else -0.5 if dragged > 0.1 else 0.3)
		if _roll[i] > 1.2 or _roll[i] < -1.2:
			# (on its back: its legs never stop)
			steps = 9.0
			going = 1.0
		_stride[i] += delta * steps * wild
		var twist := sin(_time * (1.3 + _own[i] * 2.0) + _own[i] * 40.0) * 0.55 + (sin(_time * 9.0 + i) * 0.3 if pull > 0.3 else 0.0)
		_bend[i] = twist
		# (now and then one rears to squeak; squealing, all of them do)
		_cry_in[i] -= delta
		var rear := 0.0
		var mouth := false
		if _squeal > 0.0:
			rear = 0.45 + 0.25 * sin(_time * 5.0 + i)
			mouth = true
		elif _cry_in[i] < 0.0:
			rear = 0.35 * smoothstep(-0.9, -0.6, _cry_in[i]) * (1.0 - smoothstep(-0.3, 0.0, _cry_in[i]))
			mouth = true
			if _cry_in[i] < -0.9:
				_cry_in[i] = _rng.randf_range(1.5, 5.0)
		if _frenzy > 0.0:
			mouth = true
			rear = 0.15
		_rear[i] = lerpf(_rear[i], rear if _top[i] == 0 else rear * 0.3, minf(delta * 8.0, 1.0))
		# The rat: facing out, its rump that far from the middle, its tail into the knot.
		var big := _big[i]
		var shake := sin(_time * 23.0 + i * 3.0) * 0.012 * pull
		var basis := Basis(Vector3.UP, turn + shake) * Basis(Vector3.RIGHT, _pitch[i] + sin(_time * 2.0 + i) * 0.05) * Basis(Vector3.BACK, _roll[i] + sin(_time * 3.1 + i * 2.0) * 0.15)
		basis = basis.scaled(Vector3.ONE * big)
		var middle := out_local * (_rump[i] * rat_size + _out[i] + 0.105 * big) + Vector3.UP * _high[i] * rat_size
		if absf(_roll[i]) > 1.2:
			# (on its back, it lies on its back: lifted by its own height)
			middle += Vector3.UP * 0.07 * big
		var at := i * 16
		_buffer[at] = basis.x.x
		_buffer[at + 1] = basis.y.x
		_buffer[at + 2] = basis.z.x
		_buffer[at + 3] = middle.x
		_buffer[at + 4] = basis.x.y
		_buffer[at + 5] = basis.y.y
		_buffer[at + 6] = basis.z.y
		_buffer[at + 7] = middle.y
		_buffer[at + 8] = basis.x.z
		_buffer[at + 9] = basis.y.z
		_buffer[at + 10] = basis.z.z
		_buffer[at + 11] = middle.z
		var flags := RatLook.TAIL_KNOTTED | (RatLook.MOUTH_OPEN if mouth else 0)
		RatLook.write_custom(_buffer, at, _stride[i], going * (1.0 if absf(steps) > 0.5 else 0.0), _bend[i], _rear[i], flags, _own[i])
	_drawn.multimesh.buffer = _buffer
	# What the pulling comes to: a lurch the way of whoever is pulling, and a slow turn about itself.
	var lurch := sum / maxf(count * 0.15, 1.0) * speed
	drift = drift.lerp(lurch.limit_length(speed * 1.6), minf(delta * 6.0, 1.0))
	spin = lerpf(spin, turning / count * 1.6, minf(delta * 3.0, 1.0))
	# (the knot jerked about by it)
	_knot.position = Vector3(drift.x, 0.0, drift.z) * 0.03 + Vector3(sin(_time * 7.0), 0.0, cos(_time * 5.3)) * 0.004 * strength
	_knot.rotation = Vector3(sin(_time * 3.0) * 0.08, _time * 0.2 + sin(_time * 1.7) * 0.3, cos(_time * 2.6) * 0.08)

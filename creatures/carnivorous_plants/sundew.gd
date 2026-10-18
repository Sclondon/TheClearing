class_name Sundew
extends Node3D
## A giant sundew: a rosette of long strap leaves arching up and lying out over
## the ground for two metres round, every one thick with red tentacles, each
## tipped with a drop of glue that catches the light, and a hooked stalk of
## small pale flowers. What walks over its leaves sticks; it bends its tentacles
## over it and curls its leaves in.
##
## This is only how it looks, moves and sounds. It does no thinking: a game says
## what it holds and asks where it is sticky.
##
##     var dew := Sundew.new()
##     add_child(dew)
##     dew.sticky(point)            # 0..1: how thickly its leaves lie under a point (world)
##     dew.hold(point)              # bends over something there (world), slowly
##     dew.let_go()                 # and slowly lets it be
##
## The glue makes a faint wet sound as anything pulls free of it (`unstick`).

## How far its leaves reach, metres (as modelled).
const REACH := 2.0
## How long it takes to bend right over what it holds, and to let it go, seconds.
const GRIP_TIME := 1.6
const LET_GO_TIME := 3.0

@export var low_poly := false
@export var sound := true
@export var volume_db := -8.0
@export var far := 80.0

## How far it is bent over what it holds, 0..1 (eased).
var grip := 0.0
## What it holds, in the world (INF: nothing).
var held := Vector3.INF

var _material: ShaderMaterial
var _shown: MeshInstance3D
var _voice: AudioStreamPlayer3D
static var _tear: AudioStreamWAV


func _ready() -> void:
	_material = PlantLook.material()
	_material.set_shader_parameter(&"grip_reach", 1.9)
	_material.set_shader_parameter(&"glint", 1.8)
	_material.set_shader_parameter(&"gloss", 80.0)
	_shown = PlantLook.part(PlantLook.SUNDEW_LO if low_poly or Settings.low_poly else PlantLook.SUNDEW, "sundew", _material, far)
	add_child(_shown)
	if sound:
		_voice = AudioStreamPlayer3D.new()
		_voice.volume_db = volume_db
		_voice.unit_size = 4.0
		_voice.max_distance = 24.0
		_voice.position = Vector3(0.0, 0.3, 0.0)
		add_child(_voice)


func _process(delta: float) -> void:
	var holding := held.is_finite()
	grip = move_toward(grip, 1.0 if holding else 0.0, delta / (GRIP_TIME if holding else LET_GO_TIME))
	if holding:
		_material.set_shader_parameter(&"grip_point", to_local(held))
	_material.set_shader_parameter(&"grip", grip)


## How thickly its leaves lie under `point` (world), 0 (none) to 1: thick within
## most of its reach, thinning to nothing at the tips and over the middle.
func sticky(point: Vector3) -> float:
	var at := to_local(point)
	if at.y > 0.9 or at.y < -0.6:
		return 0.0
	var out := Vector2(at.x, at.z).length() / global_basis.get_scale().x
	return smoothstep(0.2, 0.45, out) * (1.0 - smoothstep(REACH * 0.8, REACH * 1.05, out))


## Bends over what is at `point` (world).
func hold(point: Vector3) -> void:
	held = point


## Lets go of whatever it held, slowly.
func let_go() -> void:
	if held.is_finite():
		unstick()
	held = Vector3.INF


## The wet, tearing sound of something pulling free of the glue.
func unstick() -> void:
	if _voice and _voice.is_inside_tree():
		_voice.stream = tear_sound()
		_voice.pitch_scale = randf_range(0.85, 1.15)
		_voice.play()


static func tear_sound() -> AudioStreamWAV:
	if _tear:
		return _tear
	var rate := 22050
	var count := int(rate * 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var samples := PackedFloat32Array()
	samples.resize(count)
	var low := 0.0
	var pop_at := 0
	var pop_pitch := 700.0
	for i in count:
		var t := float(i) / rate
		low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.45)
		var value := low * 0.12 * (1.0 - t / 0.5)
		# (strands of glue parting: little wet pops, further and further apart)
		if i >= pop_at + int(rate * 0.012) and rng.randf() < 0.004 / (1.0 + t * 4.0):
			pop_at = i
			pop_pitch = rng.randf_range(500.0, 1100.0)
		var since := float(i - pop_at) / rate
		value += sin(TAU * pop_pitch * since * (1.0 - since * 20.0)) * exp(-since * 160.0) * 0.7
		samples[i] = value * smoothstep(0.0, 0.02, t)
	_tear = PlantLook.wav(samples)
	return _tear

class_name Wolf
extends Dog
## A grey wolf (Canis lupus): big and long-legged, a chest narrow as a keel,
## big feet, a thick grizzled grey coat with a pale cream mask and a dark
## saddle, a broad head in a ruff, shortish ears with rounded tips, amber eyes,
## a straight bushy tail hanging to its hocks. Its look, every move and its
## voice are here; what it does is for the game to say. It knows nothing of the
## game it is in.
##
## It is the dog (Dog, creatures/dog: needs GameCommon's godot/dog) on a
## wolf's model, so it is driven the same way: move it (its position and its
## rotation about Y: it faces +Z) and it walks, trots or gallops to match. Its
## trot is a wolf's: the long, tireless trot on one line, each hind foot coming
## down in the print its forefoot has just left. Everything the dog does it
## does too (`tracking` is sniffing, `stalking`, `snarling`, `look_at_point`,
## `sitting`, `lying`, `lunge`, `bite_hits`, `shake`), and more:
## - `rank`: 0 one of the breeding pair (tail and ears carried high, more so
##   when it is watching something), 1 a grown wolf of the pack, 2 a young or
##   low one (tail and ears lower, held a little back).
## - `hunting`: on the move after something: the head carried low, level with
##   the back or under it, ears forward, the tail straight out behind.
## - `bowing`: a play-bow, down on its forearms with its rump up and its tail
##   up and wagging.
## - `howl_now(which, sitting)`: a howl, the head up and the muzzle rounded,
##   about four or five seconds (`which`: one of HOWLS; several wolves each
##   howling their own at once is a pack's chorus); `rally()` a short one.
## - `woof()`: the soft, deep alarm bark; `growl()`: a low growl.
##
## Its voice is made in code (nothing to load), a little at a time the first
## time each sound is wanted (so making it never holds up a frame), and played
## from where it is unless `sound` is off; `howl_started`, `woofed` and
## `growled` say when.
##
## It is drawn by WolfRig (wolf_rig.gd, which extends the dog's DogRig) on one
## of two models (`variant`: 0 greyer and slighter, a she-wolf; 1 darker and
## heavier, a big male with a notch out of one ear; made by
## tools/build_wolf.py), with WolfLook's materials. The models are small: draw
## it at about SCALE.

signal howl_started(which: int)
signal woofed
signal growled

## How much bigger than its model a grey wolf is drawn (about 0.95 m at the withers).
const SCALE := 1.4
## How many howls there are (`howl_now`), and short rallying howls (`rally`).
const HOWLS := 5
const RALLIES := 2

## One of the breeding pair (0), a grown wolf (1), a young or low one (2).
@export_range(0, 2) var rank := 1
## Plays its voice (made in code) from where it is.
@export var sound := true
@export var volume_db := -9.0
## How far off a howl is heard (world units): a chorus carries a long way.
@export var sound_range := 320.0

## On the hunt: head low, ears forward, tail out.
var hunting := false
## A play-bow.
var bowing := false

var _voice: AudioStreamPlayer3D
var _near_voice: AudioStreamPlayer3D
## A howl waiting for its sound to be made: [which, sitting, short], or [].
var _pending: Array = []
var _sounding := -1
var _sounding_time := 0.0
var _sounding_length := 0.0


func _ready() -> void:
	rig = WolfRig.new()
	rig.name = "Rig"
	rig.variant = variant
	rig.low_poly = low_poly
	rig.fur_shells = fur_shells
	rig.coat_tint = coat_tint
	rig.mange = 0.0
	rig.eyeshine = eyeshine
	add_child(rig)
	if sound:
		_voice = AudioStreamPlayer3D.new()
		_voice.volume_db = volume_db
		_voice.unit_size = 14.0
		_voice.max_distance = sound_range
		_voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		_voice.position = Vector3(0.0, 0.75, 0.4)
		add_child(_voice)
		_near_voice = AudioStreamPlayer3D.new()
		_near_voice.volume_db = volume_db - 2.0
		_near_voice.unit_size = 4.0
		_near_voice.max_distance = 45.0
		_near_voice.position = Vector3(0.0, 0.7, 0.4)
		add_child(_near_voice)


func _process(delta: float) -> void:
	super(delta)
	WolfVoice.bake_some()
	if not _pending.is_empty():
		var key: String = _pending[0]
		if WolfVoice.ready(key):
			_start(key, _pending[1])
			_pending.clear()
	if _sounding >= 0:
		_sounding_time += delta
		if _sounding_time > _sounding_length:
			_sounding = -1


## Howls (`which`: 0 .. HOWLS - 1, -1 any), sitting to it or standing.
func howl_now(which := -1, sitting := false) -> void:
	if which < 0:
		which = randi() % HOWLS
	_ask("howl%d" % (which % HOWLS), sitting)


## A short rallying howl (the start of a hunt).
func rally(which := -1) -> void:
	if which < 0:
		which = randi() % RALLIES
	_ask("rally%d" % (which % RALLIES), false)


func _ask(key: String, sitting: bool) -> void:
	if WolfVoice.ready(key):
		_start(key, sitting)
	else:
		WolfVoice.want(key)
		_pending = [key, sitting]


func _start(key: String, sitting: bool) -> void:
	var length := WolfVoice.length(key)
	sit_to_howl = sitting
	howl(length * 0.96)
	_sounding = WolfVoice.KEYS.find(key)
	_sounding_time = 0.0
	_sounding_length = length
	howl_started.emit(_sounding)
	if _voice:
		_voice.stream = WolfVoice.stream(key)
		_voice.pitch_scale = _pitch()
		_voice.play()


## Whether it is howling, or about to.
func in_howl() -> bool:
	return howling() or not _pending.is_empty()


## How open its mouth is in the howl it is giving now, 0..1 (WolfRig shapes its muzzle by it).
func voice_open() -> float:
	if _sounding < 0:
		return 0.0
	return WolfVoice.openness(WolfVoice.KEYS[_sounding], _sounding_time)


## Stops a howl (and its sound).
func hush() -> void:
	_pending.clear()
	_sounding = -1
	_howl_left = 0.0
	if _voice:
		_voice.stop()


## The soft, deep alarm bark.
func woof() -> void:
	bark()
	woofed.emit()
	_near("woof")


## A low growl (the snarl is `snarling`).
func growl() -> void:
	growled.emit()
	_near("growl")


func _near(key: String) -> void:
	if _near_voice == null:
		return
	if not WolfVoice.ready(key):
		WolfVoice.want(key)
		return
	_near_voice.stream = WolfVoice.stream(key)
	_near_voice.pitch_scale = _pitch() * randf_range(0.95, 1.05)
	_near_voice.play()


## Its own voice: the big male lower, the young higher.
func _pitch() -> float:
	return [0.95, 1.0, 1.08][rank] * (0.93 if variant == 1 else 1.03)

class_name CoyoteRig
extends DogRig
## Poses a coyote (creatures/coyote/models/coyote_*.glb) in code, every frame:
## the dog's rig (DogRig: the walk, the trot on diagonal pairs, the rotary
## gallop with the back gathering and stretching, nose-down tracking, the
## stalk, the howl, the lunge, the shake, sitting and lying), on a coyote's
## model, with a coyote's carriage:
## - THE TAIL is carried low, hanging behind its hocks, and stays below its
##   back even at a gallop (streaming out level then, not up); hunting or
##   stalking it comes up to level; slinking off it is tucked down between its
##   legs.
## - SLINKING (Coyote.slinking): low and stiff like the stalk, but the head held
##   low and turned back over its shoulder now and then, the ears laid flat
##   back and the tail tucked.
## - A YIP (Coyote.yip) is the dog's bark, the head tossed up with it.

## The coyote (the parent), as a Coyote.
var _coyote: Coyote
## How far into a slink it is, 0..1.
var _slink := 0.0
var _glance := 0.0
var _glance_in := 2.0
var _glancing := 0.0
var _toss := 0.0


func _ready() -> void:
	_coyote = get_parent() as Coyote
	super()


func _model_path() -> String:
	return "res://creatures/coyote/models/coyote_%s%s.glb" % ["b" if variant == 1 else "a", "_lo" if low_poly else ""]


func _dress(model: Node) -> Dictionary:
	return CoyoteLook.dress(model, coat_tint, 0 if low_poly else fur_shells, eyeshine)


func _process(delta: float) -> void:
	if _dog == null or _coyote == null:
		super(delta)
		return
	var step := minf(delta, 1.0 / 30.0)
	_slink = _approach(_slink, 1.0 if _coyote.slinking else 0.0, 4.0, step)
	_toss = maxf(_toss - step * 5.0, 0.0)
	# (slinking is a stalk, as far as the legs and back go)
	var was := _dog.stalking
	if _slink > 0.5:
		_dog.stalking = true
	super(delta)
	_dog.stalking = was
	if _head == null:
		return
	# (slinking off it does not bristle: it is not after anything)
	if materials.has("crest"):
		(materials["crest"] as ShaderMaterial).set_shader_parameter(&"bristle", _bristle * (1.0 - _slink))
	# Slinking it glances back over its shoulder now and then.
	_glance_in -= step
	if _glance_in <= 0.0:
		_glance_in = randf_range(1.2, 3.0)
		_glance = (1.0 if randf() < 0.5 else -1.0) if _slink > 0.5 and randf() < 0.6 else 0.0
	_glancing = _approach(_glancing, _glance, 3.0, step)
	var back := _glancing * _slink
	_neck.rotation.y += back * 0.45
	_head.rotation.y += back * 0.5
	_head.rotation.x += 0.25 * _slink - 0.45 * _toss
	_neck.rotation.x += -0.2 * _toss
	for i in _joints.size():
		var joint := _joints[i]
		if joint == _neck or joint == _neck_1 or joint == _head:
			_skeleton.set_bone_pose(_bones[i], joint.transform)


## A yip: the dog's bark, with the head tossed up.
func yip() -> void:
	bark()
	_toss = 1.0


## The tail, carried low: hanging behind its hocks at rest and walking, up to
## level on a trail or stalking and streaming out level at a gallop, tucked
## between its legs slinking; flung about in a shake.
func _carry_tail(delta: float, gallop: float, sit: float, lie: float, flung: float, shook: float) -> void:
	_wag = _approach(_wag, 0.25 * _track, 4.0, delta)
	_wag_phase += delta * TAU * lerpf(1.6, 3.0, _wag)
	var carried := -0.05 + 0.3 * _track + 0.4 * _stalk * (1.0 - _slink) + 0.95 * gallop + 0.12 * _alert * (1.0 - _stalk) - 0.2 * _howl + 0.3 * flung
	carried = lerpf(carried, -0.62, _slink)
	carried = lerpf(carried, 0.3, sit)
	carried = lerpf(carried, 0.05, lie)
	for i in _tail.size():
		var link := _tail[i]
		var swing := sin(_wag_phase - i * 0.8) * _wag * (0.3 if i == 0 else 0.2) + lie * _side * 0.3
		if shook > 0.0:
			swing += sin(TAU * SHAKE_RATE * _shaken - 2.0 - i * 0.5) * 0.5 * shook
		var curl := carried - _pelvis.rotation.x * 0.8 - _body.rotation.x * 0.5 * (1.0 - sit) if i == 0 else -gallop * 0.05 - 0.12 * _slink
		link.aim = Basis(Vector3.UP, swing) * Basis(Vector3.RIGHT, curl) * link.rest
		link.limit = lerpf(lerpf(0.6, 0.18, gallop), 0.14, maxf(_stalk, _slink))
	_twitch_timer -= delta
	if _twitch_timer <= 0.0:
		_twitch_timer = randf_range(2.0, 5.0)
		if _sit < 0.1 and _alert < 0.5 and randf() < 0.5:
			var which := randi() % 2
			_flick(which, Vector3(0.7 if which == 0 else -0.7, 0.3, 0.0))


## The ears: as the dog's, and laid flat back slinking.
func _carry_ears(delta: float, gallop: float) -> void:
	super(delta, gallop)
	if _slink <= 0.0:
		return
	for side in 2:
		var root: Link = _ears[side][0]
		var out := 1.0 if side == 0 else -1.0
		root.aim = (Basis(Vector3.RIGHT, -0.9 * _slink) * Basis(BEHIND, out * 0.35 * _slink)) * root.aim

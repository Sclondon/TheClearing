class_name Dog
extends Node3D
## A feral dog: a half-starved mastiff-lurcher, lean and long-legged, ribs
## showing, scarred, one ear cut short, its coat dark grey-brown, matted and
## bare in patches. Its look and every move are here; what it does is for the
## game to say. It knows nothing of the game it is in.
##
## HOW TO DRIVE IT. Put it in the world and move it (its position and its
## rotation about Y: it faces +Z). It works out how fast it is going from how
## it is moved (or set `measure_velocity` false and set `velocity`), and walks,
## trots or gallops to match, its paws planted on the ground at its feet. Set
## `grounded` false while it is falling. Scale it to make it bigger: it
## strides as a bigger dog would.
##
## Then say what it is doing:
## - `look_at_point`: what it watches (INF for nothing): its head turns to it.
## - `tracking`: nose down on a trail, casting from side to side.
## - `stalking`: stiff, low and slow, head level with its back, hackles up.
## - `snarling`: lips drawn back off its teeth, ears back.
## - `friendly`: tame, glad: its tail carried up and wagging hard, ears up,
##   hackles flat, mouth open and soft (snarling or stalking still win over it).
## - `eating`: head down to what it eats on the ground, jaws working.
## - `sitting`, `lying` (it dozes off when it has lain a while).
## - `bark()`, `howl(seconds)` (it sits to howl unless `sit_to_howl` is off).
## - `lunge(at)`: it gathers itself (GATHER), springs at `at` (SPRING), snaps
##   its jaws (BITE) and lands (LAND). While it does, move it each frame by
##   `lunge_push()` (a velocity in the world), and ask `bite_hits(point)`
##   whether its jaws are on something there. `lunge_stage()` says which part
##   it is in, `busy()` whether it is lunging or shaking.
## - `shake()`: a shake from head to tail, like a wet dog's (after a miss).
##
## Signals say when it barks, howls, springs, snaps and shakes: there is no
## sound in it, and those are where a game would play its own.
##
## It is drawn by DogRig (dog_rig.gd) on one of two models (`variant`, made
## by tools/build_dog.py), with DogLook's materials (dog_look.gd): a few draws
## each, and fewer with `low_poly` (no fur shells).

signal barked
signal howled
## It has sprung, at `at`.
signal lunged(at: Vector3)
## Its jaws have shut at the end of a lunge.
signal snapped
signal shook

enum Lunge { NONE, GATHER, SPRING, BITE, LAND }

## Seconds each part of a lunge takes.
const GATHER_TIME := 0.26
const SPRING_TIME := 0.34
const BITE_TIME := 0.16
const LAND_TIME := 0.34

## Which of the two dogs: they differ in which ear is cut and in their scars. Set before it enters the tree.
@export_enum("A", "B") var variant := 0
## The demade, low-poly model, without fur. Set before it enters the tree.
@export var low_poly := false
## Layers of fur stood off its coat (each is one more draw of it). Set before it enters the tree.
@export_range(0, 4) var fur_shells := 2
## Multiplies the colours of its coat: one dog a little redder or darker than the next.
@export var coat_tint := Color.WHITE
## How much of its coat is bare with mange, 0..1.
@export_range(0.0, 1.0) var mange := 0.2
## How brightly its eyes give back the light.
@export_range(0.0, 2.0) var eyeshine := 0.5
## Works out `velocity` from how it is moved (else the game sets it).
@export var measure_velocity := true
## How far it springs at least and at most (m, at a scale of 1).
@export var lunge_reach := Vector2(1.0, 2.6)

## How fast it is going, in the world.
var velocity := Vector3.ZERO
## Whether its paws are on the ground.
var grounded := true
## What it watches, in the world (INF: nothing).
var look_at_point := Vector3.INF
var tracking := false
var stalking := false
var snarling := false
var friendly := false
var eating := false
var sitting := false
var lying := false
## Sits down to howl.
var sit_to_howl := true
var rig: DogRig

var _lunge_time := INF
var _lunge_way := Vector3.FORWARD
var _lunge_span := 0.0
var _howl_left := 0.0
var _was_at := Vector3.INF


func _ready() -> void:
	rig = DogRig.new()
	rig.name = "Rig"
	rig.variant = variant
	rig.low_poly = low_poly
	rig.fur_shells = fur_shells
	rig.coat_tint = coat_tint
	rig.mange = mange
	rig.eyeshine = eyeshine
	add_child(rig)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if measure_velocity:
		var at := global_position
		if _was_at.is_finite():
			var moved := (at - _was_at) / delta
			if moved.length() > 40.0:
				# (put somewhere: not a speed)
				settle()
			else:
				velocity = velocity.lerp(moved, 1.0 - exp(-14.0 * delta))
		_was_at = at
	if _lunge_time < INF:
		var was := lunge_stage()
		_lunge_time += delta
		var now := lunge_stage()
		if now != was:
			if now == Lunge.SPRING:
				lunged.emit(global_position + _lunge_way * _lunge_span)
			elif now == Lunge.BITE:
				snapped.emit()
		if now == Lunge.NONE:
			_lunge_time = INF
	if _howl_left > 0.0:
		_howl_left -= delta


## Stands it still where it is, with nothing in motion: for when it is put somewhere.
func settle() -> void:
	velocity = Vector3.ZERO
	_was_at = global_position
	_lunge_time = INF
	if rig:
		rig.settle()


func bark() -> void:
	if rig:
		rig.bark()
	barked.emit()


## Howls for `seconds` (sitting to it, unless `sit_to_howl` is off).
func howl(seconds := 2.4) -> void:
	_howl_left = seconds
	howled.emit()


func howling() -> bool:
	return _howl_left > 0.0


## Springs at `at` (in the world): it gathers itself, then goes as far as
## brings its jaws to it, within `lunge_reach`. Not while it is lunging already.
func lunge(at: Vector3) -> void:
	if _lunge_time < INF:
		return
	var to := at - global_position
	to.y = 0.0
	var scale_now := global_basis.get_scale().x
	_lunge_way = to.normalized() if to.length() > 0.01 else global_basis.z.normalized()
	# (its jaws are some way ahead of its middle)
	_lunge_span = clampf(to.length() - 0.55 * scale_now, lunge_reach.x * scale_now, lunge_reach.y * scale_now)
	_lunge_time = 0.0
	_howl_left = 0.0


func lunge_stage() -> Lunge:
	if _lunge_time == INF:
		return Lunge.NONE
	var t := _lunge_time
	if t < GATHER_TIME:
		return Lunge.GATHER
	t -= GATHER_TIME
	if t < SPRING_TIME:
		return Lunge.SPRING
	t -= SPRING_TIME
	if t < BITE_TIME:
		return Lunge.BITE
	t -= BITE_TIME
	return Lunge.LAND if t < LAND_TIME else Lunge.NONE


## How far through the part of the lunge it is in, 0..1.
func lunge_progress() -> float:
	match lunge_stage():
		Lunge.GATHER:
			return _lunge_time / GATHER_TIME
		Lunge.SPRING:
			return (_lunge_time - GATHER_TIME) / SPRING_TIME
		Lunge.BITE:
			return (_lunge_time - GATHER_TIME - SPRING_TIME) / BITE_TIME
		Lunge.LAND:
			return (_lunge_time - GATHER_TIME - SPRING_TIME - BITE_TIME) / LAND_TIME
	return 0.0


## The way it should be moving through the world just now while it lunges:
## nothing while it gathers itself, its whole spring through the air, a little
## more as it snaps, and slowing as it lands.
func lunge_push() -> Vector3:
	match lunge_stage():
		Lunge.SPRING:
			return _lunge_way * _lunge_span * 0.88 / SPRING_TIME
		Lunge.BITE:
			return _lunge_way * _lunge_span * 0.12 / BITE_TIME
		Lunge.LAND:
			return _lunge_way * (1.0 - lunge_progress()) * 1.5 * global_basis.get_scale().x
	return Vector3.ZERO


## The way it is springing (flat, in the world).
func lunge_way() -> Vector3:
	return _lunge_way


## Whether its jaws are closing on `point` (in the world) now: as it snaps,
## within `radius` (m, at a scale of 1) of the tip of its jaws.
func bite_hits(point: Vector3, radius := 0.45) -> bool:
	var stage := lunge_stage()
	if stage != Lunge.BITE and not (stage == Lunge.SPRING and lunge_progress() > 0.75):
		return false
	return jaw_position().distance_to(point) < radius * global_basis.get_scale().x


## Where the tip of its jaws is, in the world.
func jaw_position() -> Vector3:
	return rig.jaw_tip() if rig else global_position


func shake() -> void:
	if rig:
		rig.shake()
	shook.emit()


## Lunging or shaking: too taken up to do anything else.
func busy() -> bool:
	return _lunge_time < INF or (rig != null and rig.shaking())

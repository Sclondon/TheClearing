class_name Stagger
extends Node
## A hunter knocked back on its heels for a moment (a thrown spear, a blow of a
## stick, a bat or a sword, a shot: Loot): shoved back the way the blow came,
## rocking, its thinking stopped, and catching nobody, for `seconds`; then it goes
## on as it was, and for GUARD seconds after it is not to be staggered again by a
## blow (so that a hunter cannot be held down by beating it). Only where the
## hunters are run (alone, or the room's maker); a guest asks the host (Loot).
##
## Or felled (a shot, Stagger.fell): knocked over for good. It topples the way the
## shot went, lies a moment, sinks into the ground and is gone for the rest of the
## round: out of the groups that hunt, and not processed at all. Every copy fells
## its own (the host says which, Loot).
##
##     Stagger.hit(enemy, push_direction)            # 3 s, shoved 2.6 m
##     Stagger.hit(enemy, push_direction, 1.2, 0.8)   # a stick's blow
##     Stagger.fell(enemy, push_direction)

## How long it is stood off, seconds, and how far it is shoved, metres.
const SECONDS := 3.0
const SHOVE := 2.6
## After a stagger, seconds before a blow can stagger it again.
const GUARD := 1.6
## Felled: how long it takes to go over, how long it lies, and how long it takes to sink away, seconds.
const FALLS := 0.55
const LIES := 3.0
const SINKS := 2.2

var _enemy: Node3D
var _push := Vector3.ZERO
var _shove := SHOVE
var _time := 0.0
var _seconds := SECONDS
var _was_processing := true
var _turn := 0.0
var _felled := false
var _pivot := Vector3.ZERO
var _held: Array = []


## Staggers `enemy` (a MazeEnemy, the Griever, anything that hunts) away along
## `push` (level), for `seconds`, shoved `shove` metres or so. Hitting one
## already staggered starts it again (the longer of the two).
static func hit(enemy: Node3D, push: Vector3, seconds := SECONDS, shove := SHOVE) -> Stagger:
	if not is_instance_valid(enemy) or felled(enemy):
		return null
	var already := enemy.get_node_or_null(^"Stagger") as Stagger
	if already:
		already._seconds = maxf(already._seconds - already._time, seconds)
		already._time = 0.0
		already._shove = shove
		if Vector2(push.x, push.z).length() > 0.01:
			already._push = Vector3(push.x, 0.0, push.z).normalized()
		return already
	var stagger := Stagger.new()
	stagger.name = "Stagger"
	stagger._enemy = enemy
	stagger._push = Vector3(push.x, 0.0, push.z).normalized() if Vector2(push.x, push.z).length() > 0.01 else Vector3.ZERO
	stagger._seconds = seconds
	stagger._shove = shove
	enemy.add_child(stagger)
	return stagger


## Fells `enemy` for good, toppling away along `push`.
static func fell(enemy: Node3D, push: Vector3) -> void:
	if not is_instance_valid(enemy) or felled(enemy):
		return
	var stagger := enemy.get_node_or_null(^"Stagger") as Stagger
	if stagger == null:
		stagger = hit(enemy, push, 1.0e6, 0.0)
	if stagger == null:
		return
	enemy.set_meta(&"felled", true)
	stagger._felled = true
	stagger._time = 0.0
	stagger._seconds = 1.0e6
	stagger._shove = 0.0
	if Vector2(push.x, push.z).length() > 0.01:
		stagger._push = Vector3(push.x, 0.0, push.z).normalized()
	stagger._spare()
	stagger._hold_still()
	_leave_groups(enemy)


## Whether `enemy` is staggered now (or going down).
static func on(enemy: Node) -> bool:
	return is_instance_valid(enemy) and enemy.get_node_or_null(^"Stagger") != null


## Whether `enemy` has been felled.
static func felled(enemy: Node) -> bool:
	return is_instance_valid(enemy) and enemy.has_meta(&"felled")


## Whether a blow can stagger `enemy` now: not staggered already, nor just come out of it.
static func open_to_blows(enemy: Node) -> bool:
	if not is_instance_valid(enemy) or on(enemy) or felled(enemy):
		return false
	var ended: int = enemy.get_meta(&"stagger_ended", -100000)
	return Time.get_ticks_msec() - ended > int(GUARD * 1000.0)


## Out of every group that hunts or is aimed at (it is nothing to anyone now).
static func _leave_groups(enemy: Node) -> void:
	for group: StringName in enemy.get_groups():
		if group == &"maze_enemies" or group == &"pursuers" or group == &"grievers" or group == enemy.get(&"pack"):
			enemy.remove_from_group(group)


func _ready() -> void:
	# (only felled does it do anything every frame drawn: see _hold_still)
	set_process(false)
	_was_processing = _enemy.is_physics_processing()
	_enemy.set_physics_process(false)
	_spare()


## It lets everyone alone while it is staggered (MazeEnemy: as if each had just been caught).
func _spare() -> void:
	var spared: Variant = _enemy.get(&"_spared")
	if spared is Dictionary and _enemy.has_method(&"players"):
		for player: Variant in _enemy.call(&"players"):
			if is_instance_valid(player):
				(spared as Dictionary)[player] = maxf(float((spared as Dictionary).get(player, 0.0)), minf(_seconds, 60.0) - _time + 0.3)
	if &"quarry" in _enemy:
		_enemy.set(&"quarry", null)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_enemy):
		queue_free()
		return
	_time += delta
	# Shoved back hard at first, the shove dying away; rocking as it stands.
	var shove := _push * _shove * 3.2 * exp(-_time * 3.2)
	var body := _enemy as CharacterBody3D
	if body and shove.length() > 0.01:
		body.velocity = shove
		body.move_and_slide()
	elif shove.length() > 0.01:
		_enemy.global_position += shove * delta
	if _felled:
		if _time > FALLS + LIES + SINKS:
			_enemy.visible = false
			_enemy.set_deferred(&"process_mode", Node.PROCESS_MODE_DISABLED)
			queue_free()
		return
	_turn = sin(_time * 9.0) * 0.12 * exp(-_time * 1.2)
	_enemy.rotation.z = _turn
	if _time >= _seconds:
		_enemy.rotation.z = 0.0
		_enemy.set_physics_process(_was_processing)
		_enemy.set_meta(&"stagger_ended", Time.get_ticks_msec())
		queue_free()


## Felled: what is seen of it is taken as it stands now (the body, and every
## figure of it placed on its own, `top_level`), to be turned over from here on,
## whatever its own scripts would do with it.
func _hold_still() -> void:
	_pivot = _enemy.global_position
	_held.clear()
	_held.append([_enemy, _enemy.global_transform])
	for node: Node in _enemy.find_children("*", "Node3D", true, false):
		var part := node as Node3D
		if part.top_level:
			_held.append([part, part.global_transform])
	# (after everything else has placed itself this frame)
	process_priority = 1000
	set_process(true)


## Felled: over it goes, away from the shot, and a little along; it lies; it sinks
## into the ground. (The hiding is done in _physics_process.)
func _process(_delta: float) -> void:
	if not _felled or not is_instance_valid(_enemy):
		return
	var over := smoothstep(0.0, FALLS, _time)
	var axis := Vector3.UP.cross(_push).normalized() if _push.length() > 0.01 else Vector3.RIGHT
	var turn := Basis(axis, over * 1.45 + sin(clampf((_time - FALLS) * 9.0, 0.0, PI)) * 0.07 * over)
	var sunk := 1.6 * smoothstep(FALLS + LIES, FALLS + LIES + SINKS, _time)
	var moved := _push * 0.7 * over + Vector3.DOWN * sunk
	var around := Transform3D(turn, _pivot + moved) * Transform3D(Basis.IDENTITY, -_pivot)
	for entry: Array in _held:
		var part := entry[0] as Node3D
		if is_instance_valid(part):
			part.global_transform = around * (entry[1] as Transform3D)

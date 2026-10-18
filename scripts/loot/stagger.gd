class_name Stagger
extends Node
## A hunter knocked back on its heels for a moment (a thrown spear, LootItem):
## shoved back the way the blow came, rocking, its thinking stopped, and catching
## nobody, for `seconds`; then it goes on as it was. It is never hurt: nothing
## that hunts the maze can be (DESIGN.md, pillar 2). Only where the hunters are
## run (alone, or the room's maker); a guest asks the host (Loot).
##
##     Stagger.hit(enemy, push_direction)

## How long it is stood off, seconds, and how far it is shoved, metres.
const SECONDS := 3.0
const SHOVE := 2.6

var _enemy: Node3D
var _push := Vector3.ZERO
var _time := 0.0
var _seconds := SECONDS
var _was_processing := true
var _turn := 0.0


## Staggers `enemy` (a MazeEnemy, the Griever, anything that hunts) away along
## `push` (level). Hitting one already staggered starts it again.
static func hit(enemy: Node3D, push: Vector3, seconds := SECONDS) -> Stagger:
	if not is_instance_valid(enemy):
		return null
	var already := enemy.get_node_or_null(^"Stagger") as Stagger
	if already:
		already._time = 0.0
		return already
	var stagger := Stagger.new()
	stagger.name = "Stagger"
	stagger._enemy = enemy
	stagger._push = Vector3(push.x, 0.0, push.z).normalized() if Vector2(push.x, push.z).length() > 0.01 else Vector3.ZERO
	stagger._seconds = seconds
	enemy.add_child(stagger)
	return stagger


## Whether `enemy` is staggered now.
static func on(enemy: Node) -> bool:
	return is_instance_valid(enemy) and enemy.get_node_or_null(^"Stagger") != null


func _ready() -> void:
	_was_processing = _enemy.is_physics_processing()
	_enemy.set_physics_process(false)
	_spare()


## It lets everyone alone while it is staggered (MazeEnemy: as if each had just been caught).
func _spare() -> void:
	var spared: Variant = _enemy.get(&"_spared")
	if spared is Dictionary and _enemy.has_method(&"players"):
		for player: Variant in _enemy.call(&"players"):
			if is_instance_valid(player):
				(spared as Dictionary)[player] = maxf(float((spared as Dictionary).get(player, 0.0)), _seconds - _time + 0.3)
	if &"quarry" in _enemy:
		_enemy.set(&"quarry", null)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_enemy):
		queue_free()
		return
	_time += delta
	# Shoved back hard at first, the shove dying away; rocking as it stands.
	var shove := _push * SHOVE * 3.2 * exp(-_time * 3.2)
	var body := _enemy as CharacterBody3D
	if body and shove.length() > 0.01:
		body.velocity = shove
		body.move_and_slide()
	elif shove.length() > 0.01:
		_enemy.global_position += shove * delta
	_turn = sin(_time * 9.0) * 0.12 * exp(-_time * 1.2)
	_enemy.rotation.z = _turn
	if _time >= _seconds:
		_enemy.rotation.z = 0.0
		_enemy.set_physics_process(_was_processing)
		queue_free()

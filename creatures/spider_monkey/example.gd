extends Node3D
## SpiderMonkey, on its own: three spider monkeys by a wall with a vine strung
## along it, run through everything they do, over and over. Make a scene with
## a Node3D, give it this script, and run it (or run it as the main scene's
## child).
##
## One goes round a ring on the floor: walking on all fours, bounding, then
## stopping to chitter and make its threat display. One swings along the vine
## hand over hand, one way and back. The third hangs by its tail alone; now and
## then it rustles the vine, winds up and flings itself down to the floor, and
## (put back) hangs again. Moving them is only setting their transforms.

const RING := 2.5
const VINE_HIGH := 2.6

var monkeys: Array[SpiderMonkey] = []
var vine: SpiderMonkeyVine
var _time := 0.0
var _angle := 0.0
var _swing_t := 0.3
var _swing_way := 1.0
var _drop_from := Vector3.ZERO


func _ready() -> void:
	if get_viewport().get_camera_3d() == null:
		var camera := Camera3D.new()
		camera.position = Vector3(0.0, 2.2, 7.0)
		add_child(camera)
		camera.look_at(Vector3(0.0, 1.2, 0.0))
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.9, 0.6, 0.0)
		sun.shadow_enabled = true
		add_child(sun)
		var floor := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(20.0, 20.0)
		floor.mesh = plane
		add_child(floor)
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(10.0, 4.0, 0.4)
	wall.mesh = box
	wall.position = Vector3(0.0, 2.0, -2.2)
	add_child(wall)
	vine = SpiderMonkeyVine.new()
	vine.anchors = PackedVector3Array([Vector3(-4.5, VINE_HIGH, -1.9), Vector3(-1.5, VINE_HIGH - 0.1, -1.9), Vector3(1.5, VINE_HIGH, -1.9), Vector3(4.5, VINE_HIGH - 0.1, -1.9)])
	vine.ground = 0.0
	vine.away = Vector3.BACK
	add_child(vine)
	vine.build()
	for k in 3:
		var one := SpiderMonkey.new()
		one.seed_value = k * 7 + 1
		one.hang_style = SpiderMonkey.Hang.TAIL if k == 2 else SpiderMonkey.Hang.HAND
		one.voice = false
		add_child(one)
		monkeys.append(one)
	_hang(monkeys[1], _swing_t)
	_hang(monkeys[2], 0.75)
	monkeys[2].settle()
	_drop_from = monkeys[2].position


## Hangs `one` from the vine at `t` along it, facing out from the wall.
func _hang(one: SpiderMonkey, t: float) -> void:
	one.hanging = true
	one.hold_axis = vine.axis_at(t)
	one.position = vine.point_at(t) + Vector3.DOWN * SpiderMonkey.HANG_HIGH * one.size
	one.rotation = Vector3.ZERO


func _process(delta: float) -> void:
	_time += delta
	# The walker: a loop of 12 seconds: walk 4, bound 4, stop to chitter and display 4.
	var walker := monkeys[0]
	var t := fmod(_time, 12.0)
	var speed := 0.0
	if t < 4.0:
		speed = 0.8
	elif t < 8.0:
		speed = 3.4
	elif absf(t - 8.5) < delta:
		walker.chitter()
	elif absf(t - 9.5) < delta:
		walker.display(2.0)
	_angle += speed / RING * delta
	walker.position = Vector3(cos(_angle), 0.0, sin(_angle) + 0.8) * RING
	walker.rotation.y = atan2(-sin(_angle), cos(_angle))
	# The swinger: along the vine and back.
	var swinger := monkeys[1]
	_swing_t += _swing_way * 1.4 * delta / vine.length()
	if _swing_t > 0.6 or _swing_t < 0.1:
		_swing_way = -_swing_way
	_hang(swinger, _swing_t)
	# The dropper: a loop of 8 seconds: hang 4, rustle 1.5, wind up 0.6, drop 0.7, on the floor.
	var dropper := monkeys[2]
	var d := fmod(_time, 8.0)
	if d < 4.0:
		if not dropper.hanging:
			_hang(dropper, 0.75)
			dropper.airborne = false
			dropper.settle()
	elif d < 5.5:
		if absf(d - 4.0) < delta * 1.5:
			dropper.rustle(1.4)
	elif d < 6.1:
		if absf(d - 5.5) < delta * 1.5:
			dropper.wind_up(0.6)
			dropper.shriek()
	elif d < 6.8:
		var k := (d - 6.1) / 0.7
		dropper.hanging = false
		dropper.airborne = true
		dropper.position = _drop_from + Vector3(0.0, -_drop_from.y * k * k, 2.6 * k)
	else:
		dropper.airborne = false
		dropper.position.y = 0.0

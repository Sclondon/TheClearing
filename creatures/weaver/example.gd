extends Node3D
## Weaver, on its own: hanging over a floor, drifting round a ring, stopping to
## weave threads between its hands (strung out as WeaverThreads), and on. Put it
## on a Node3D in an empty scene and run it.

var weaver: Weaver
var threads: WeaverThreads
var _lines := []
var _time := 0.0


func _ready() -> void:
	if get_viewport().get_camera_3d() == null:
		var camera := Camera3D.new()
		camera.position = Vector3(0.0, 3.0, 10.0)
		add_child(camera)
		camera.look_at(Vector3(0.0, 2.0, 0.0))
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.9, 0.6, 0.0)
		add_child(sun)
	weaver = Weaver.new()
	add_child(weaver)
	threads = WeaverThreads.new()
	add_child(threads)


func _process(delta: float) -> void:
	_time += delta
	var t := fmod(_time, 10.0)
	var weaving := t > 6.0
	weaver.weaving = 1.0 if weaving else 0.0
	if not weaving:
		var a := _time * 0.25
		weaver.position = Vector3(cos(a) * 3.0, 0.8, sin(a) * 3.0)
		weaver.rotation.y = atan2(-sin(a), cos(a))
	for id: int in _lines:
		threads.remove(id)
	_lines.clear()
	if weaving:
		var hands := weaver.weave_hands()
		for k in 3:
			_lines.append(threads.add(hands[k * 2], hands[k * 2 + 1]))

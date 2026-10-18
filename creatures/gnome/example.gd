extends Node3D
## Gnome, on its own: three gnomes on a floor, run through what they do, over
## and over (walk, creep, scurry, freeze, snatch, carry, haul, giggle, squeal),
## and a hollow by a wall. Put it on a Node3D in an empty scene and run it.

var gnomes: Array[Gnome] = []
var _time := 0.0


func _ready() -> void:
	if get_viewport().get_camera_3d() == null:
		var camera := Camera3D.new()
		camera.position = Vector3(0.0, 1.4, 4.0)
		add_child(camera)
		camera.look_at(Vector3(0.0, 0.3, 0.0))
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.9, 0.6, 0.0)
		add_child(sun)
	var hollow := GnomeHollow.new()
	hollow.position = Vector3(0.0, 0.0, -2.0)
	add_child(hollow)
	for k in 3:
		var one := Gnome.new()
		one.seed_value = k
		one.still = k as Gnome.Still
		add_child(one)
		gnomes.append(one)


func _process(delta: float) -> void:
	_time += delta
	var t := fmod(_time, 12.0)
	for k in gnomes.size():
		var one := gnomes[k]
		var a := _time * (0.2 if t < 3.0 else (0.5 if t < 6.0 else 1.4)) + k * TAU / 3.0
		one.creeping = t >= 3.0 and t < 6.0
		one.frozen = t >= 9.0 and t < 10.5
		one.carrying = t >= 6.0 and t < 9.0 and k == 0
		if not one.frozen:
			one.position = Vector3(cos(a), 0.0, sin(a)) * 1.2
			one.rotation.y = atan2(-sin(a), cos(a))
		if absf(t - 10.6) < delta * 1.5:
			if k == 0:
				one.giggle()
			else:
				one.snatch()

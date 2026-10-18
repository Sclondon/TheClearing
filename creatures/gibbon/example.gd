extends Node3D
## Gibbon, on its own: two gibbons and a bar across a floor, run through
## everything they do, over and over. Make a scene with a Node3D, give it this
## script, and run it (or run it as the main scene's child).
##
## One swings along the bar, hand over hand, slowly and then flying, hangs
## still and gives the great call, and lunges at a point under the bar. The
## other walks upright along the floor below, sits, and calls back. Moving them
## is only setting their position and Y rotation (and their gait); the rest
## they do.

const BAR := 2.2
const LONG := 5.0

var swinger: Gibbon
var walker: Gibbon
var _time := 0.0


func _ready() -> void:
	if get_viewport().get_camera_3d() == null:
		var camera := Camera3D.new()
		camera.position = Vector3(0.0, 1.6, 7.5)
		add_child(camera)
		camera.look_at(Vector3(0.0, 1.0, 0.0))
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.9, 0.6, 0.0)
		sun.shadow_enabled = true
		add_child(sun)
		var floor := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(30.0, 30.0)
		floor.mesh = plane
		add_child(floor)
	var bar := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.025
	rod.bottom_radius = 0.025
	rod.height = LONG * 2.0 + 2.0
	bar.mesh = rod
	bar.rotation.z = PI * 0.5
	bar.position = Vector3(0.0, BAR + 0.02, 0.0)
	add_child(bar)
	swinger = Gibbon.new()
	swinger.kind = Gibbon.Kind.RINGED
	swinger.gait = Gibbon.Gait.HANG
	add_child(swinger)
	walker = Gibbon.new()
	walker.kind = Gibbon.Kind.PALE
	walker.seed_value = 3
	add_child(walker)
	swinger.position = Vector3(-LONG, BAR, 0.0)
	swinger.rotation.y = PI * 0.5
	swinger.settle()
	walker.position = Vector3(-LONG, 0.0, 1.5)
	walker.rotation.y = PI * 0.5
	walker.settle()


func _process(delta: float) -> void:
	_time += delta
	# A loop of 16 seconds: swing slowly 3, fast 2, hang and call 5, lunge 2, back 4.
	var t := fmod(_time, 16.0)
	var x := swinger.position.x
	if t < 3.0:
		x += 2.2 * delta
	elif t < 5.0:
		x += 5.5 * delta
	elif t < 10.0:
		if absf(t - 5.5) < delta:
			swinger.great_call()
	elif t < 12.0:
		if absf(t - 10.2) < delta:
			swinger.lunge(swinger.global_position + Vector3(0.6, -1.3, 0.8))
	else:
		x -= 4.0 * delta
	swinger.rotation.y = PI * 0.5 if t < 12.0 else -PI * 0.5
	swinger.position.x = clampf(x, -LONG, LONG)
	# The walker: along the floor, then sat, calling back.
	walker.sitting = t >= 6.0 and t < 12.0
	if t < 6.0:
		walker.position.x = -LONG + t * 1.2
		walker.rotation.y = PI * 0.5
	elif t >= 12.0:
		walker.position.x = -LONG + 7.2 - (t - 12.0) * 1.8
		walker.rotation.y = -PI * 0.5
	if absf(t - 6.6) < delta:
		walker.great_call()

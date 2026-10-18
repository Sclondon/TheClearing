extends Node3D
## An example of the giant snail (Snail): put this script on a Node3D in an
## empty scene and run it. A snail crawls round a wide circle on a flat floor,
## leaving its slime, and goes through everything it does, over and over: it
## reaches for a ball on a pole, flinches an eye stalk, pulls into its shell
## and comes out, and crawls up a wall, over the top and down the far side.
##
## It is moved here, by hand, as a game would move it: put on the surface,
## its basis saying which way is up off it and which way it goes.

var snail: Snail
var ball: MeshInstance3D
var _time := 0.0
var _act := -1
var _around := 0.0
var _over := 0.0

## (what happens, and for how long)
const ACTS := [["crawl", 6.0], ["reach", 5.0], ["flinch", 3.0], ["withdraw", 4.0], ["crawl", 4.0], ["over", 30.0]]
## The wall it goes over: how far out from the middle, how high and how thick.
const WALL := Vector3(30.0, 6.0, 3.0)


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.6, 0.62, 0.64)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	environment.ambient_light_energy = 0.45
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(35.0), 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	floor.mesh = plane
	add_child(floor)
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(12.0, WALL.y, WALL.z)
	wall.mesh = box
	wall.position = Vector3(WALL.x + WALL.z * 0.5, WALL.y * 0.5, 0.0)
	add_child(wall)
	var camera := Camera3D.new()
	camera.position = Vector3(26.0, 14.0, 30.0)
	add_child(camera)
	camera.look_at(Vector3(14.0, 1.5, 0.0))
	ball = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	ball.mesh = sphere
	add_child(ball)
	snail = Snail.new()
	add_child(snail)
	_place(Vector3(0.0, 0.0, 20.0), Vector3.UP, Vector3(1.0, 0.0, 0.0))
	snail.settle()


func _place(at: Vector3, up: Vector3, ahead: Vector3) -> void:
	snail.global_transform = Transform3D(SnailRig._frame(up, ahead), at)


func _process(delta: float) -> void:
	_time += delta
	var total := 0.0
	for act: Array in ACTS:
		total += act[1]
	var t := fposmod(_time, total)
	var index := 0
	while t > ACTS[index][1]:
		t -= ACTS[index][1]
		index += 1
	var act: String = ACTS[index][0]
	var starting := index != _act
	_act = index
	if starting:
		snail.withdrawn = act == "withdraw"
		if act == "flinch":
			snail.flinch(0)
		if act == "over":
			_over = 0.0
	ball.visible = act in ["reach", "flinch"]
	var front := snail.global_position + snail.global_basis.z.normalized() * 3.0 + Vector3.UP * 2.0
	ball.global_position = front + Vector3(sin(_time) * 1.5, 0.0, 0.0)
	snail.aim = ball.global_position if ball.visible else Vector3.INF
	if act == "withdraw":
		return
	if act == "over":
		# Out along the floor to the wall, up its face, over the top, down the far side; then back to the circle.
		_over += 1.0 * delta
		var legs := [WALL.x - 20.0, WALL.y, WALL.z, WALL.y]
		var left := _over
		var x := 20.0
		if left < legs[0]:
			_place(Vector3(x + left, 0.0, 0.0), Vector3.UP, Vector3.RIGHT)
		elif left < legs[0] + legs[1]:
			_place(Vector3(WALL.x, left - legs[0], 0.0), Vector3.LEFT, Vector3.UP)
		elif left < legs[0] + legs[1] + legs[2]:
			_place(Vector3(WALL.x + left - legs[0] - legs[1], WALL.y, 0.0), Vector3.UP, Vector3.RIGHT)
		elif left < legs[0] + legs[1] + legs[2] + legs[3]:
			_place(Vector3(WALL.x + WALL.z, WALL.y - (left - legs[0] - legs[1] - legs[2]), 0.0), Vector3.RIGHT, Vector3.DOWN)
		else:
			_place(Vector3(WALL.x + WALL.z + 0.5, 0.0, 0.0), Vector3.UP, Vector3.RIGHT)
		return
	# Round and round a wide circle.
	var radius := 20.0
	_around += 1.0 / radius * delta * (0.4 if act == "reach" else 1.0)
	_place(Vector3(cos(_around), 0.0, sin(_around)) * radius, Vector3.UP, Vector3(-sin(_around), 0.0, cos(_around)))

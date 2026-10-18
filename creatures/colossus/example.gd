extends Node3D
## Colossus, on its own: a giant on a flat floor between two walls, run through
## everything it does, over and over. Make a scene with a Node3D, give it this
## script, and run it (or run it as the main scene's child).
##
## It walks round a great circle, stepping over the walls where its way crosses
## them (each foot's shadow growing where it will come down); every lap it stops
## and reaches for a post in the middle, and then leans on the top of the wall
## and looks over it. Thinking for it (where each foot goes) is here: the
## component only moves.

const CIRCLE := 120.0
const WALL_HEIGHT := 34.0

var giant: Colossus
var post: MeshInstance3D
var _angle := 0.0
var _foot := Colossus.LEFT
var _laps := 0.0
var _doing := "walk"
var _time := 0.0
## The walls: [middle, size] (boxes standing on the floor).
var _walls: Array = [[Vector3(0, 0, -40), Vector3(400, WALL_HEIGHT, 12)], [Vector3(60, 0, 50), Vector3(12, WALL_HEIGHT, 160)]]


func _ready() -> void:
	if get_viewport().get_camera_3d() == null:
		var camera := Camera3D.new()
		camera.far = 3000.0
		camera.position = Vector3(0.0, 60.0, 330.0)
		add_child(camera)
		camera.look_at(Vector3(0.0, 50.0, 0.0))
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.9, 0.6, 0.0)
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 600.0
		add_child(sun)
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(1000.0, 1000.0)
		ground.mesh = plane
		add_child(ground)
	for wall: Array in _walls:
		var box := MeshInstance3D.new()
		box.mesh = BoxMesh.new()
		(box.mesh as BoxMesh).size = wall[1]
		box.position = (wall[0] as Vector3) + Vector3.UP * (wall[1] as Vector3).y * 0.5
		add_child(box)
	post = MeshInstance3D.new()
	post.mesh = CylinderMesh.new()
	(post.mesh as CylinderMesh).height = 3.0
	(post.mesh as CylinderMesh).top_radius = 0.6
	(post.mesh as CylinderMesh).bottom_radius = 0.6
	post.position = Vector3(0, 1.5, 0)
	add_child(post)
	giant = Colossus.new()
	add_child(giant)
	giant.put(_on_circle(0.0), _tangent(0.0))


func _on_circle(angle: float) -> Vector3:
	return Vector3(cos(angle), 0.0, sin(angle)) * CIRCLE


## Facing on round the circle (anticlockwise seen from above).
func _tangent(angle: float) -> float:
	return atan2(-sin(angle), cos(angle)) + PI


## How high the walls are anywhere near the line from `a` to `b` (-INF: none).
func _clear(a: Vector3, b: Vector3) -> float:
	var top := -INF
	for k in 21:
		var p := a.lerp(b, k / 20.0)
		for wall: Array in _walls:
			var middle: Vector3 = wall[0]
			var size: Vector3 = wall[1]
			if absf(p.x - middle.x) < size.x * 0.5 + 6.0 and absf(p.z - middle.z) < size.z * 0.5 + 6.0:
				top = maxf(top, size.y)
	return top


func _process(delta: float) -> void:
	_time += delta
	match _doing:
		"walk":
			if giant.stepping() >= 0:
				return
			# Each step: the foot behind goes on round the circle, beside the other.
			_angle += giant.stride() * 0.45 / CIRCLE
			_laps += giant.stride() * 0.45 / (TAU * CIRCLE)
			var yaw := _tangent(_angle)
			giant.facing = yaw
			var side := Basis(Vector3.UP, yaw).x * (1.0 if _foot == Colossus.LEFT else -1.0) * 0.6 * giant.scale_m()
			var to := _on_circle(_angle) + side
			giant.step(_foot, to, yaw, _clear(giant.landing(_foot), to))
			_foot = 1 - _foot
			if _laps > 0.5:
				_laps = 0.0
				_doing = "reach"
				giant.look_at_point = post.position
		"reach":
			if giant.stepping() >= 0:
				return
			if not giant.reaching():
				giant.reach(post.global_position)
				_doing = "reaching"
		"reaching":
			if not giant.reaching():
				_doing = "walk"
				# (on the top of the nearest wall, a little way onto it, if one is near)
				var at := giant.pelvis()
				for wall: Array in _walls:
					var middle: Vector3 = wall[0]
					var half: Vector3 = (wall[1] as Vector3) * 0.5
					var top := Vector3(clampf(at.x, middle.x - half.x, middle.x + half.x), WALL_HEIGHT, clampf(at.z, middle.z - half.z, middle.z + half.z))
					var to := Vector3(top.x - at.x, 0.0, top.z - at.z)
					if to.length() < 40.0:
						giant.lean_on = top + to.normalized() * 4.0
						giant.facing = atan2(to.x, to.z)
						_doing = "lean"
						_time = 0.0
						break
		"lean":
			if _time > 12.0:
				giant.lean_on = Vector3.INF
				giant.look_at_point = Vector3.INF
				_doing = "walk"

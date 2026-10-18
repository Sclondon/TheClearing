extends Node3D
## Colossus, on its own: a giant crawling over rows of walls, run through
## everything it does, over and over. Make a scene with a Node3D, give it this
## script, and run it (or run it as the main scene's child).
##
## It crawls on over the walls, each hand and foot put down on a wall top (the
## shadow of each growing where it will land); every so often it stops and
## presses its finger down three times at a post between two walls, then
## rears up and leans on the end wall to look over it. Thinking for it (where
## each hand and foot goes) is here: the component only moves.

const WALL_HEIGHT := 34.0
const WALL_THICK := 12.0
## Walls run along x, one every PITCH metres along z.
const PITCH := 28.0
const ROWS := 14

var giant: Colossus
var post: MeshInstance3D
var _gait := 0
var _heading := 0.0
var _moves := 0
var _doing := "crawl"
var _time := 0.0
const GAIT: Array[int] = [Colossus.HAND_L, Colossus.FOOT_R, Colossus.HAND_R, Colossus.FOOT_L]


func _ready() -> void:
	if get_viewport().get_camera_3d() == null:
		var camera := Camera3D.new()
		camera.far = 4000.0
		camera.position = Vector3(420.0, 220.0, 120.0)
		add_child(camera)
		camera.look_at(Vector3(0.0, 40.0, 170.0))
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.9, 0.6, 0.0)
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 800.0
		add_child(sun)
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(1200.0, 1200.0)
		ground.mesh = plane
		add_child(ground)
	for k in ROWS:
		var wall := MeshInstance3D.new()
		wall.mesh = BoxMesh.new()
		(wall.mesh as BoxMesh).size = Vector3(300.0, WALL_HEIGHT, WALL_THICK)
		wall.position = Vector3(0.0, WALL_HEIGHT * 0.5, k * PITCH)
		add_child(wall)
	post = MeshInstance3D.new()
	post.mesh = CylinderMesh.new()
	(post.mesh as CylinderMesh).height = 3.0
	(post.mesh as CylinderMesh).top_radius = 0.6
	(post.mesh as CylinderMesh).bottom_radius = 0.6
	add_child(post)
	giant = Colossus.new()
	add_child(giant)
	giant.put(Vector3(0.0, WALL_HEIGHT, PITCH * 3.0), 0.0)
	for limb in 4:
		giant.plant(limb, _top_near(giant.landing(limb)), 0.0)


## The nearest point on a wall top to `point`.
func _top_near(point: Vector3) -> Vector3:
	var row := clampi(roundi(point.z / PITCH), 0, ROWS - 1)
	return Vector3(clampf(point.x, -140.0, 140.0), WALL_HEIGHT, row * PITCH)


func _process(delta: float) -> void:
	_time += delta
	match _doing:
		"crawl":
			if giant.stepping() >= 0:
				return
			# (back the other way at the ends of the rows)
			var at := giant.pelvis()
			if at.z > PITCH * (ROWS - 4) and _heading == 0.0:
				_heading = PI
			elif at.z < PITCH * 3.0 and _heading == PI:
				_heading = 0.0
			giant.facing = _heading
			var limb := GAIT[_gait]
			_gait = (_gait + 1) % GAIT.size()
			var basis := Basis(Vector3.UP, _heading)
			var where := giant.stance(limb)
			var want := at + basis * Vector3(where.x, 0.0, where.y) + basis.z * 22.0
			giant.step(limb, _top_near(want), _heading, WALL_HEIGHT)
			_moves += 1
			if _moves % 24 == 0:
				_doing = "press"
		"press":
			if giant.stepping() >= 0:
				return
			# (a post in the hall ahead of it, between two walls)
			var ahead := giant.pelvis() + Basis(Vector3.UP, _heading).z * 70.0
			var row := floorf(ahead.z / PITCH)
			post.position = Vector3(ahead.x, 1.5, (row + 0.5) * PITCH)
			giant.look_at_point = post.position
			giant.stoop = 1.0
			giant.press(post.position - Vector3.UP * 1.5, Vector3.RIGHT)
			_doing = "pressing"
			_time = 0.0
		"pressing":
			# (three presses, then it lets go)
			if _time > 3.0 * (giant.descend_time + giant.press_time + giant.lift_time + giant.hover_time) + 3.0:
				giant.release()
			if not giant.pressing():
				giant.stoop = 0.0
				giant.look_at_point = Vector3.INF
				var at := giant.pelvis()
				var row := clampi(roundi(at.z / PITCH) + (2 if _heading == 0.0 else -2), 0, ROWS - 1)
				giant.lean_on = Vector3(at.x, WALL_HEIGHT, row * PITCH)
				_doing = "lean"
				_time = 0.0
		"lean":
			if _time > 12.0:
				giant.lean_on = Vector3.INF
				_doing = "crawl"

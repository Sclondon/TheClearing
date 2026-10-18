extends Node3D
## GiantSpider example: a floor, a wall, a post, and a spider that goes through
## everything it can do, over and over: it walks round in a ring (in bursts,
## with stops), crosses to the wall and climbs it, turns head down and waits,
## drops on its thread, lands, and rears and strikes at the post.
##
## Run it as a scene's root script (or `add_child(load(".../example.gd").new())`).
## Everything is built in code; the spider is driven only through its plain
## inputs (moving the node, `heading`, `surface`, `hanging`, `anchor`, `aim`,
## `rear()`), as a game would drive it.

enum Phase { WALK, TO_WALL, CLIMB, PERCH, DROP, LAND, STRIKE }

## The wall's face (z), how high it waits on it, and the post it strikes at.
const WALL_Z := -11.0
const PERCH_HIGH := 8.0
const POST := Vector3(0.0, 0.0, -1.5)

var spider: GiantSpider
var camera: Camera3D
var phase := Phase.WALK
var phase_time := 0.0
## Stops everything where it is (for pictures).
var paused := false
## Turns the camera round by itself.
var orbit := true

var _angle := 0.0
var _from := Vector3.ZERO
var _land := Vector3.ZERO


func _ready() -> void:
	_build_world()
	spider = GiantSpider.new()
	add_child(spider)
	spider.global_position = Vector3(6.0, 0.0, 0.0)
	spider.heading = Vector3.BACK
	spider.settle()
	camera = Camera3D.new()
	camera.fov = 55.0
	add_child(camera)
	camera.make_current()
	_enter(Phase.WALK)


func _enter(next: Phase) -> void:
	phase = next
	phase_time = 0.0
	_from = spider.global_position


func _physics_process(delta: float) -> void:
	if paused:
		return
	phase_time += delta
	var at := spider.global_position
	match phase:
		Phase.WALK:
			# Round a ring, in bursts: a dash, a stop.
			var dash := fmod(phase_time, 1.6) < 1.0
			var speed := 5.0 if dash else 0.0
			_angle += speed / 6.0 * delta
			var next := Vector3(cos(_angle) * 6.0, 0.0, sin(_angle) * 6.0)
			spider.heading = Vector3(-sin(_angle), 0.0, cos(_angle))
			spider.global_position = next
			if phase_time > 6.4:
				_enter(Phase.TO_WALL)
		Phase.TO_WALL:
			var goal := Vector3(0.0, 0.0, WALL_Z + 1.4)
			var to := goal - at
			spider.heading = to.normalized() if to.length() > 0.1 else Vector3.FORWARD
			spider.global_position = at.move_toward(goal, 3.0 * delta)
			if to.length() < 0.05:
				_enter(Phase.CLIMB)
		Phase.CLIMB:
			# Onto the face, and up it.
			spider.surface = Vector3.BACK
			spider.heading = Vector3.UP
			var on_wall := Vector3(0.0, maxf(at.y, 0.6), WALL_Z)
			if at.z < WALL_Z + 0.05:
				on_wall.y = at.y + 2.4 * delta
			spider.global_position = at.move_toward(on_wall, 3.0 * delta) if at.z > WALL_Z + 0.05 else on_wall
			if at.y >= PERCH_HIGH:
				_enter(Phase.PERCH)
		Phase.PERCH:
			spider.heading = Vector3.DOWN
			if phase_time > 2.5:
				# (fixed to the wall where the tip of its back body is)
				var tail := spider.spinnerets()
				spider.anchor = Vector3(tail.x, tail.y, WALL_Z + 0.05)
				spider.hanging = true
				_land = Vector3(0.0, 0.0, WALL_Z + 2.2)
				_enter(Phase.DROP)
		Phase.DROP:
			# Out off the wall, then down the thread, slowing at the end.
			var t := clampf(phase_time / 1.3, 0.0, 1.0)
			var out := smoothstep(0.0, 0.35, t)
			var down := t * t * (3.0 - 2.0 * t)
			spider.global_position = Vector3(0.0, lerpf(PERCH_HIGH, 1.0, down), lerpf(WALL_Z + 0.3, _land.z, out))
			if t >= 1.0:
				spider.hanging = false
				spider.surface = Vector3.UP
				spider.heading = Vector3.BACK
				spider.global_position = _land
				_enter(Phase.LAND)
		Phase.LAND:
			if phase_time > 1.0:
				spider.anchor = Vector3.INF
			var goal := POST + Vector3(0.0, 0.0, -3.6)
			spider.heading = (POST - at).normalized()
			spider.global_position = at.move_toward(goal, 4.0 * delta)
			if phase_time > 2.0 and at.distance_to(goal) < 0.1:
				spider.aim = POST + Vector3.UP
				spider.rear()
				_enter(Phase.STRIKE)
		Phase.STRIKE:
			if spider.stage() == GiantSpider.Stage.STRIKE:
				spider.global_position = at + spider.heading * 9.0 * delta
			if spider.stage() == GiantSpider.Stage.NONE:
				spider.aim = Vector3.INF
				spider.anchor = Vector3.INF
				_angle = atan2(at.z, at.x)
				spider.global_position = Vector3(cos(_angle) * 6.0, 0.0, sin(_angle) * 6.0)
				_enter(Phase.WALK)
	if orbit:
		var round_about := Time.get_ticks_msec() * 0.0001
		camera.global_position = Vector3(cos(round_about) * 16.0, 7.0, sin(round_about) * 16.0)
		camera.look_at(spider.body.origin)


func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.64, 0.63)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.58)
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.62, 0.64, 0.63)
	environment.fog_density = 0.012
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.shadow_normal_bias = 2.0
	add_child(sun)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.34, 0.34, 0.33)
	_box(Vector3(0.0, -0.5, 0.0), Vector3(60.0, 1.0, 60.0), grey)
	_box(Vector3(0.0, 10.0, WALL_Z - 1.0), Vector3(40.0, 20.0, 2.0), grey)
	_box(POST + Vector3.UP * 1.0, Vector3(0.4, 2.0, 0.4), grey)


func _box(at: Vector3, extent: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = extent
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = extent
	mesh.material_override = material
	body.add_child(mesh)
	add_child(body)

extends Node3D
## The griffinfly on its own: put this on a Node3D in an empty scene and run it.
## A grey yard with a wall and a post for a target, and the griffinfly going
## round everything it does, over and over: darting and hovering over the yard,
## gliding on still wings, coming to hang in front of the post, the wind-up (its
## legs thrown forward into a basket, its jaws open, its wings loud), the strike
## through where the post is and on past, pulling up and away, and resting on
## the wall, head up, wings out flat.

const POST := Vector3(0.0, 0.0, 6.0)
const WALL := Vector3(0.0, 0.0, -6.0)

var fly: Griffinfly
var _t := 0.0
var _from := Vector3.ZERO
var _goal := Vector3.ZERO
var _snapped := false


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.62, 0.64)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.52, 0.56)
	env.environment.fog_enabled = true
	env.environment.fog_light_color = Color(0.62, 0.64, 0.66)
	env.environment.fog_density = 0.01
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)
	sun.look_at_from_position(Vector3(4, 10, 6), Vector3.ZERO)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	add_child(ground)
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(12.0, 8.0, 1.0)
	wall.mesh = box
	wall.position = WALL + Vector3(0.0, 4.0, -0.5)
	add_child(wall)
	var post := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.height = 1.6
	cylinder.top_radius = 0.2
	cylinder.bottom_radius = 0.2
	post.mesh = cylinder
	post.position = POST + Vector3.UP * 0.8
	add_child(post)
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(Vector3(9, 3.5, 10), Vector3(0, 2, 0))
	fly = Griffinfly.new()
	add_child(fly)
	fly.global_position = Vector3(0.0, 3.0, 0.0)
	_goal = fly.global_position
	fly.settle()


func _process(delta: float) -> void:
	_t += delta
	var cycle := fmod(_t, 24.0)
	fly.basket = 0.0
	fly.jaws = 0.0
	fly.rattle = 0.0
	fly.perched = false
	fly.aim = Vector3.INF
	if cycle < 8.0:
		# Over the yard: a dart, a hover, a dart; a glide now and then.
		var leg := fmod(cycle, 2.0)
		if leg < 0.05:
			_from = fly.global_position
			_goal = Vector3(randf_range(-6.0, 6.0), randf_range(2.0, 5.0), randf_range(-3.0, 4.0))
		var u := clampf(leg / 0.7, 0.0, 1.0)
		fly.effort = 0.0 if cycle > 4.0 and cycle < 6.0 and u < 1.0 else 1.0
		_turn_to(_goal - _from, delta, 14.0)
		fly.global_position = _from.lerp(_goal, u * u * (3.0 - 2.0 * u))
	elif cycle < 11.0:
		# In to hang in front of the post, at the height of a chest.
		fly.effort = 1.0
		var hold := POST + Vector3(0.0, 1.6, -6.0)
		fly.global_position = fly.global_position.lerp(hold, 1.0 - exp(-3.0 * delta))
		fly.aim = POST + Vector3.UP * 1.3
		fly.rattle = 0.4
		_turn_to(POST - fly.global_position, delta, 6.0)
	elif cycle < 12.0:
		# The wind-up: still, the basket out, jaws open, wings loud.
		fly.effort = 1.0
		fly.basket = 1.0
		fly.jaws = 1.0
		fly.rattle = 1.0
		fly.aim = POST + Vector3.UP * 1.3
		_from = fly.global_position
		_snapped = false
	elif cycle < 13.2:
		# The strike: straight through where the post is, and on.
		var u := (cycle - 12.0) / 1.2
		fly.effort = 1.0
		fly.basket = 1.0
		fly.rattle = 1.0
		fly.global_position = _from + Vector3(0.0, -0.3 * u, 14.0 * u)
		if not _snapped and fly.global_position.z > POST.z - 0.3:
			_snapped = true
			fly.snap()
	elif cycle < 15.0:
		# Up and away, and round.
		fly.effort = 1.0
		fly.global_position += Vector3(0.0, 3.0, 2.0 * (15.0 - cycle)) * delta
		fly.rotation.y += 2.4 * delta
	elif cycle < 17.0:
		# Back over the yard to the wall.
		fly.effort = 1.0
		var on_wall := WALL + Vector3(1.0, 3.0, 0.05 * fly.wingspan + 0.02)
		fly.global_position = fly.global_position.lerp(on_wall + Vector3.BACK * 1.5, 1.0 - exp(-2.5 * delta))
		_turn_to(on_wall - fly.global_position, delta, 5.0)
	else:
		# Resting on the wall, head up.
		fly.perched = true
		fly.surface = Vector3.BACK
		var on_wall := WALL + Vector3(1.0, 3.0, 0.05 * fly.wingspan + 0.02)
		fly.global_position = fly.global_position.lerp(on_wall, 1.0 - exp(-6.0 * delta))


func _turn_to(way: Vector3, delta: float, rate: float) -> void:
	way.y = 0.0
	if way.length() > 0.05:
		fly.rotation.y = lerp_angle(fly.rotation.y, atan2(way.x, way.z), 1.0 - exp(-rate * delta))

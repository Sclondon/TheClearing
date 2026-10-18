extends Node3D
## The least a level needs for `PsychicChild`, and what the component is tested
## with: one on a flat floor under a grey sky, going round a loop. She drifts
## across to a post (the stand-in for a player) and watches it; takes hold of a
## block (the stand-in for something after it) with her mind, lifts it and
## slams it down; is frightened (it builds for two seconds); bursts, flinging
## the block away; sits drained; and calms and drifts back. Make a scene with a
## Node3D carrying this script and run it; drag nothing, it all goes by itself.
## The camera turns slowly round.
##
## Needs GameCommon's character-controller installed too (the rig is built on it).

## Her drift, world units a second.
const SPEED := 0.55

var child: PsychicChild
var post: MeshInstance3D
var block: MeshInstance3D
var camera: Camera3D
## Set to stop the camera moving (a test that places it itself).
var still_camera := false
## What she is doing in the loop (for a test to read).
var step := "drift"
var _time := 0.0
var _step_time := 0.0
var _home := Vector3(0.0, 0.0, -3.0)
var _block_home := Vector3(2.5, 0.4, 2.5)
var _block_speed := Vector3.ZERO


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.62, 0.64, 0.66)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.72, 0.75)
	environment.ambient_light_energy = 0.55
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.66, 0.68, 0.7)
	environment.fog_density = 0.02
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0.0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	floor_mesh.mesh = plane
	floor_mesh.material_override = Toon.surface(Color(0.45, 0.44, 0.42))
	add_child(floor_mesh)

	post = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	post.mesh = capsule
	post.material_override = Toon.surface(Color(0.6, 0.15, 0.12))
	post.position = Vector3(0.0, 0.8, 0.5)
	add_child(post)
	block = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 0.8, 0.8)
	block.mesh = box
	block.material_override = Toon.surface(Color(0.25, 0.24, 0.23))
	block.position = _block_home
	add_child(block)

	child = PsychicChild.new()
	add_child(child)
	child.put(_home, 0.0)
	camera = Camera3D.new()
	camera.fov = 45.0
	add_child(camera)
	camera.current = true


func _go(next: String) -> void:
	step = next
	_step_time = 0.0


func _process(delta: float) -> void:
	_time += delta
	_step_time += delta
	var to_post := post.global_position - child.global_position
	to_post.y = 0.0
	child.velocity = Vector3.ZERO
	match step:
		"drift":
			child.aim = post.global_position + Vector3.UP * 0.5
			if to_post.length() > 2.0:
				child.velocity = to_post.normalized() * SPEED
				child.global_position += child.velocity * delta
				child.rotation.y = atan2(to_post.x, to_post.z)
			elif _step_time > 3.0:
				_go("reach")
		"reach":
			# Her arm out at the block: it rises, shaking, and is slammed down.
			child.reaching = true
			child.reach_at = block.global_position
			child.aim = block.global_position
			var lift := smoothstep(0.0, 0.5, _step_time) * 1.2
			block.position = _block_home + Vector3.UP * lift + Vector3(sin(_time * 30.0), 0.0, cos(_time * 27.0)) * 0.03
			if _step_time > 1.6:
				block.position = _block_home
				child.thud(Vector3(_block_home.x, 0.0, _block_home.z))
				child.reaching = false
				_go("calm")
		"calm":
			child.aim = post.global_position + Vector3.UP * 0.5
			if _step_time > 2.0:
				_go("frightened")
		"frightened":
			child.distress = clampf(_step_time / 2.0, 0.0, 1.0)
			if _step_time > 2.2:
				child.burst()
				_block_speed = (block.position - child.global_position).normalized() * 6.0 + Vector3.UP * 3.0
				_go("burst")
		"burst":
			_block_speed += Vector3.DOWN * 14.0 * delta
			block.position += _block_speed * delta
			if block.position.y < 0.4:
				block.position.y = 0.4
				_block_speed = Vector3.ZERO
			if _step_time > 1.0:
				child.distress = 0.0
				child.drained = true
				_go("drained")
		"drained":
			child.aim = Vector3.INF
			if _step_time > 5.0:
				child.drained = false
				block.position = _block_home
				_go("back")
		"back":
			var home := _home - child.global_position
			home.y = 0.0
			if home.length() > 0.2 and _step_time > 1.5:
				child.velocity = home.normalized() * SPEED
				child.global_position += child.velocity * delta
				child.rotation.y = atan2(home.x, home.z)
			elif _step_time > 1.5:
				_go("drift")
	if not still_camera:
		var round_about := _time * 0.12
		camera.global_position = Vector3(sin(round_about) * 7.0, 2.2, cos(round_about) * 7.0)
		camera.look_at(Vector3(0.0, 0.6, 0.5), Vector3.UP)

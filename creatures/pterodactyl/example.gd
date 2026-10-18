extends Node3D
## The pterodactyl on its own: put this on a Node3D in an empty scene and run it.
## A stone block to roost on and a post for a target, and the pterodactyl going
## round everything it does, over and over: standing on its block (turning to
## look about), croaking, launching, soaring round high over the post (its
## shadow on the ground), diving at the post, snatching (feet forward), climbing
## away on heavy beats, and coming back to land on its block.

const ROOST := Vector3(0.0, 6.0, 0.0)
const TARGET := Vector3(0.0, 0.0, 22.0)

var ptero: Pterodactyl
var _t := 0.0
var _stage := 0
var _from := Vector3.ZERO
var _angle := 0.0


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.62, 0.64)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.56, 0.6)
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.64, 0.66)
	env.fog_density = 0.008
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)
	sun.look_at_from_position(Vector3(4, 10, 6), Vector3.ZERO)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	var block := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4.0, ROOST.y, 4.0)
	block.mesh = box
	block.position = Vector3(0.0, ROOST.y * 0.5, 0.0)
	add_child(block)
	var post := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.height = 1.3
	cylinder.top_radius = 0.2
	cylinder.bottom_radius = 0.2
	post.mesh = cylinder
	post.position = TARGET + Vector3.UP * 0.65
	add_child(post)
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(Vector3(26, 9, 4), Vector3(0, 6, 12))
	ptero = Pterodactyl.new()
	add_child(ptero)
	ptero.global_position = ROOST + Vector3.UP * ptero.stand_height()
	ptero.rotation.y = 0.0
	ptero.grounded = true
	ptero.settle()


func _process(delta: float) -> void:
	_t += delta
	var stand := ROOST + Vector3.UP * ptero.stand_height()
	match _stage:
		0:
			# Standing, turning to look about, then the croak.
			ptero.rotation.y = sin(_t * 0.4) * 0.6
			ptero.aim = TARGET + Vector3.UP
			if _t > 5.0:
				ptero.croak()
				_next()
		1:
			if _t > 1.2:
				ptero.rotation.y = 0.0
				ptero.launch()
				_from = ptero.global_position
				_next()
		2:
			var lift := Pterodactyl.launch_lift(minf(_t, Pterodactyl.LAUNCH_TIME))
			ptero.global_position = _from + Vector3(0.0, lift.x, lift.y)
			if _t > Pterodactyl.LAUNCH_TIME:
				_from = ptero.global_position
				_angle = -PI * 0.5
				_next()
		3:
			# Soaring round over the post, a few slow beats now and then.
			_angle += delta * 0.45
			var want := TARGET + Vector3(cos(_angle) * 20.0, 22.0, sin(_angle) * 20.0)
			ptero.global_position = ptero.global_position.move_toward(want, delta * 12.0)
			ptero.rotation.y = atan2(-sin(_angle), cos(_angle))
			ptero.effort = 0.5 if fmod(_t, 7.0) < 2.0 else 0.0
			ptero.show_shadow(Vector3(ptero.global_position.x, 0.0, ptero.global_position.z), 0.9, 0.3)
			if _t > 16.0:
				ptero.croak()
				ptero.rush()
				_from = ptero.global_position
				_next()
		4:
			# The dive: wings tucked, down at the post, the feet forward at the last.
			var t := minf(_t / 2.2, 1.0)
			var low := TARGET + Vector3.UP * 1.8
			ptero.global_position = _from.lerp(low, t * t)
			var to := low - _from
			ptero.rotation.y = atan2(to.x, to.z)
			ptero.effort = 0.0
			ptero.tuck = 1.0 if t < 0.7 else 0.0
			ptero.talons = 1.0 if t >= 0.7 else 0.0
			ptero.grip = 1.0 if t >= 0.97 else 0.0
			ptero.show_shadow(Vector3(ptero.global_position.x, 0.0, ptero.global_position.z), 1.0, 0.0)
			if t >= 1.0:
				_next()
		5:
			# Climbing away, flapping hard, round and back to the block.
			ptero.tuck = 0.0
			ptero.talons = 0.4
			ptero.effort = 1.0
			var high := stand + Vector3(0.0, 4.0, 18.0)
			ptero.global_position = ptero.global_position.move_toward(high, delta * 8.0)
			ptero.rotation.y = lerp_angle(ptero.rotation.y, PI, delta * 1.5)
			ptero.show_shadow(Vector3(ptero.global_position.x, 0.0, ptero.global_position.z), 0.9, 0.2)
			if ptero.global_position.distance_to(high) < 0.5:
				_from = ptero.global_position
				_next()
		6:
			# In to land, braking, onto all fours.
			ptero.talons = 0.6
			ptero.brake = 1.0
			ptero.effort = 0.5
			var t := minf(_t / 1.8, 1.0)
			ptero.global_position = _from.lerp(stand, t * t * (3.0 - 2.0 * t))
			ptero.rotation.y = PI
			ptero.show_shadow(Vector3.INF)
			if t > 0.85:
				ptero.grounded = true
			if t >= 1.0:
				ptero.brake = 0.0
				ptero.talons = 0.0
				ptero.grip = 0.0
				ptero.effort = 0.0
				_stage = -1
				_next()


func _next() -> void:
	_stage += 1
	_t = 0.0

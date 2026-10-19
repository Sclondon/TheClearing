extends Node3D
## The wyvern on its own: put this on a Node3D in an empty scene and run it.
## A stone block with its nest on it and a post for a target, and the wyvern
## going round everything it does, over and over: standing on its nest
## (turning to look about), screaming, launching, soaring round high over the
## post (its shadow on the ground), diving at the post, snatching (feet
## forward), climbing away, coming down by the post, walking up to it on its
## wrists and feet, the tail lash (the coil, then the whip over and down), and
## taking off again back to its nest.

const ROOST := Vector3(0.0, 6.0, 0.0)
const TARGET := Vector3(0.0, 0.0, 24.0)

var wyvern: Wyvern
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
	plane.size = Vector2(140, 140)
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	var block := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6.0, ROOST.y, 6.0)
	block.mesh = box
	block.position = Vector3(0.0, ROOST.y * 0.5, 0.0)
	add_child(block)
	var nest := WyvernNest.new()
	add_child(nest)
	nest.position = ROOST
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
	camera.look_at_from_position(Vector3(30, 10, 4), Vector3(0, 5, 13))
	wyvern = Wyvern.new()
	add_child(wyvern)
	wyvern.global_position = ROOST + Vector3.UP * wyvern.stand_height()
	wyvern.grounded = true
	wyvern.settle()


func _process(delta: float) -> void:
	_t += delta
	var stand := ROOST + Vector3.UP * wyvern.stand_height()
	var by_post := TARGET + Vector3(0.0, wyvern.stand_height(), -9.0)
	match _stage:
		0:
			# On its nest, turning to look about, then the scream.
			wyvern.rotation.y = sin(_t * 0.4) * 0.6
			wyvern.aim = TARGET + Vector3.UP
			if _t > 5.0:
				wyvern.shriek()
				_next()
		1:
			if _t > 1.4:
				wyvern.rotation.y = 0.0
				wyvern.launch()
				_from = wyvern.global_position
				_next()
		2:
			var lift := Wyvern.launch_lift(minf(_t, Wyvern.LAUNCH_TIME))
			wyvern.global_position = _from + Vector3(0.0, lift.x, lift.y)
			if _t > Wyvern.LAUNCH_TIME:
				_angle = -PI * 0.5
				_next()
		3:
			# Soaring round over the post, a few slow beats now and then.
			_angle += delta * 0.4
			var want := TARGET + Vector3(cos(_angle) * 24.0, 24.0, sin(_angle) * 24.0)
			wyvern.global_position = wyvern.global_position.move_toward(want, delta * 12.0)
			wyvern.rotation.y = atan2(-sin(_angle), cos(_angle))
			wyvern.effort = 0.5 if fmod(_t, 7.0) < 2.0 else 0.0
			wyvern.show_shadow(Vector3(wyvern.global_position.x, 0.0, wyvern.global_position.z), 0.9, 0.3)
			if _t > 16.0:
				wyvern.shriek()
				wyvern.rush()
				_from = wyvern.global_position
				_next()
		4:
			# The dive: wings drawn in, down at the post, the feet forward at the last.
			var t := minf(_t / 2.4, 1.0)
			var low := TARGET + Vector3.UP * 2.2
			wyvern.global_position = _from.lerp(low, t * t)
			var to := low - _from
			wyvern.rotation.y = atan2(to.x, to.z)
			wyvern.effort = 0.0
			wyvern.tuck = 1.0 if t < 0.7 else 0.0
			wyvern.talons = 1.0 if t >= 0.7 else 0.0
			wyvern.grip = 1.0 if t >= 0.97 else 0.0
			wyvern.show_shadow(Vector3(wyvern.global_position.x, 0.0, wyvern.global_position.z), 1.0, 0.0)
			if t >= 1.0:
				_next()
		5:
			# Climbing away, flapping hard, then round to come down by the post.
			wyvern.tuck = 0.0
			wyvern.talons = 0.4
			wyvern.grip = 0.0
			wyvern.effort = 1.0
			var high := by_post + Vector3(0.0, 8.0, -14.0)
			wyvern.global_position = wyvern.global_position.move_toward(high, delta * 9.0)
			wyvern.rotation.y = lerp_angle(wyvern.rotation.y, 0.0, delta * 1.5)
			wyvern.show_shadow(Vector3(wyvern.global_position.x, 0.0, wyvern.global_position.z), 0.9, 0.2)
			if wyvern.global_position.distance_to(high) < 0.5:
				_from = wyvern.global_position
				_next()
		6:
			# Down by the post, braking, onto its feet and wrists.
			wyvern.talons = 0.6
			wyvern.brake = 1.0
			wyvern.effort = 0.5
			var t := minf(_t / 2.0, 1.0)
			wyvern.global_position = _from.lerp(by_post, t * t * (3.0 - 2.0 * t))
			wyvern.rotation.y = 0.0
			wyvern.show_shadow(Vector3.INF)
			if t > 0.85:
				wyvern.grounded = true
			if t >= 1.0:
				wyvern.brake = 0.0
				wyvern.talons = 0.0
				wyvern.effort = 0.0
				_next()
		7:
			# Walking up to the post, then the lash.
			wyvern.aim = TARGET + Vector3.UP
			var near := TARGET + Vector3(0.0, wyvern.stand_height(), -2.0)
			wyvern.global_position = wyvern.global_position.move_toward(near, delta * 2.7)
			if wyvern.global_position.distance_to(near) < 0.05:
				wyvern.strike()
				_next()
		8:
			if _t > Wyvern.STRIKE_TIME + 1.0:
				wyvern.rotation.y = PI
				wyvern.launch()
				_from = wyvern.global_position
				_next()
		9:
			var lift := Wyvern.launch_lift(minf(_t, Wyvern.LAUNCH_TIME))
			wyvern.global_position = _from + Vector3(0.0, lift.x, -lift.y)
			if _t > Wyvern.LAUNCH_TIME:
				_from = wyvern.global_position
				_next()
		10:
			# Home to its nest.
			wyvern.effort = 0.6
			wyvern.brake = 0.6
			var t := minf(_t / 4.0, 1.0)
			wyvern.global_position = _from.lerp(stand, t * t * (3.0 - 2.0 * t)) + Vector3.UP * sin(PI * t) * 6.0
			if t > 0.85:
				wyvern.grounded = true
			if t >= 1.0:
				wyvern.brake = 0.0
				wyvern.effort = 0.0
				_stage = -1
				_next()


func _next() -> void:
	_stage += 1
	_t = 0.0

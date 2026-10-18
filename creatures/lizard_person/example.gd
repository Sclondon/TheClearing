extends Node3D
## The least a level needs for `LizardPerson`, and what the component is tested
## with: one on a floor before a high wall, under a grey sky, going round a
## loop. It stands, stooped, and looks about; walks; drops to all fours and
## scuttles to the wall; runs straight up it and turns head down, waiting; then
## hisses (the warning), leaps down at the post (the stand-in for a player),
## lunges at it, and walks back. Make a scene with a Node3D carrying this script
## and run it; it all goes by itself. The camera turns slowly round.

## How fast it scuttles on the ground and on the wall, and walks, m/s.
const SCUTTLE := 4.5
const CLIMB := 3.0
const WALK := 1.1
## How high up the wall it waits.
const HIGH := 4.0

var lizard: LizardPerson
var post: MeshInstance3D
var camera: Camera3D
## Set to stop the camera moving (a test that places it itself).
var still_camera := false
## What it is doing in the loop (for a test to read).
var step := "stand"
var _time := 0.0
var _step_time := 0.0
var _home := Vector3(-3.0, 0.0, 2.0)
var _wall_x := 4.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO


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
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.45, 0.44, 0.42)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	floor_mesh.mesh = plane
	floor_mesh.material_override = grey
	add_child(floor_mesh)
	# The wall it climbs, its face towards -X.
	var wall := MeshInstance3D.new()
	var block := BoxMesh.new()
	block.size = Vector3(2.0, 10.0, 16.0)
	wall.mesh = block
	wall.material_override = grey
	wall.position = Vector3(_wall_x + 1.0, 5.0, 0.0)
	add_child(wall)

	post = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	post.mesh = capsule
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.6, 0.15, 0.12)
	post.material_override = red
	post.position = Vector3(1.0, 0.8, -2.5)
	add_child(post)

	lizard = LizardPerson.new()
	add_child(lizard)
	lizard.global_position = _home
	lizard.heading = Vector3.BACK
	lizard.settle()

	camera = Camera3D.new()
	camera.fov = 50.0
	add_child(camera)


func _process(delta: float) -> void:
	_time += delta
	_step_time += delta
	if not still_camera:
		var round_about := _time * 0.12
		camera.position = Vector3(sin(round_about) * 10.0, 3.0, cos(round_about) * 10.0)
		camera.look_at(Vector3(1.0, 1.5, 0.0))
	var at := lizard.global_position
	var foot := Vector3(_wall_x - 0.9, 0.0, 0.5)
	match step:
		"stand":
			lizard.aim = Vector3.INF
			if _step_time > 2.5:
				_go("walk")
		"walk":
			_ground_to(Vector3(-1.0, 0.0, 0.5), WALK, delta)
			if _step_time > 2.0:
				_go("scuttle")
		"scuttle":
			if _ground_to(foot, SCUTTLE, delta):
				_from = lizard.global_position
				_go("onto")
		"onto":
			# Up onto the face: it rolls over to it by itself.
			var t := smoothstep(0.0, 0.4, _step_time)
			lizard.surface = Vector3.LEFT
			lizard.heading = Vector3.UP
			lizard.global_position = _from.lerp(Vector3(_wall_x - 0.02, 0.9, 0.5), t)
			if t >= 1.0:
				_go("climb")
		"climb":
			lizard.global_position = at.move_toward(Vector3(_wall_x - 0.02, HIGH, 0.5), CLIMB * delta)
			if lizard.global_position.y >= HIGH - 0.01:
				_go("turn")
		"turn":
			# Head down, and waits.
			lizard.heading = Vector3.UP.rotated(Vector3.LEFT, PI * smoothstep(0.0, 0.6, _step_time))
			if _step_time > 0.6:
				lizard.heading = Vector3.DOWN
			lizard.aim = post.position + Vector3.UP * 0.4
			if _step_time > 3.0:
				lizard.hiss(0.9)
				_go("hiss")
		"hiss":
			if not lizard.hissing():
				_from = lizard.global_position
				_to = post.position + (lizard.global_position - post.position).normalized() * 1.2
				_to.y = 0.0
				_go("leap")
		"leap":
			# Off the wall in an arc, landing short of the post.
			var t := clampf(_step_time / 0.7, 0.0, 1.0)
			lizard.airborne = true
			lizard.surface = Vector3.UP
			var flat := _to - _from
			flat.y = 0.0
			lizard.heading = flat.normalized()
			var p := _from.lerp(_to, t)
			p.y = lerpf(_from.y, _to.y, t) + sin(PI * t) * 0.8
			lizard.global_position = p
			if t >= 1.0:
				lizard.airborne = false
				lizard.lunge()
				_go("lunge")
		"lunge":
			if lizard.lunge_stage() == LizardPerson.Stage.REACH:
				_ground_to(post.position, 6.0, delta, 0.8)
			if lizard.lunge_stage() == LizardPerson.Stage.NONE and _step_time > 0.3:
				_go("back")
		"back":
			lizard.aim = Vector3.INF
			if _ground_to(_home, WALK, delta):
				_go("stand")


## Goes along the ground towards `point` at `speed`, facing it; true once within `near`.
func _ground_to(point: Vector3, speed: float, delta: float, near := 0.1) -> bool:
	lizard.surface = Vector3.UP
	var to := point - lizard.global_position
	to.y = 0.0
	if to.length() <= near:
		return true
	lizard.heading = lizard.heading.slerp(to.normalized(), 1.0 - exp(-8.0 * delta)).normalized()
	lizard.global_position += to.normalized() * minf(speed * delta, to.length() - near * 0.5)
	lizard.global_position.y = 0.0
	return false


func _go(next: String) -> void:
	step = next
	_step_time = 0.0

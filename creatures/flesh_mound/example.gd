extends Node3D
## FleshMound, on its own: a flat floor, an overcast light, a stand-in for a
## person (a grey capsule), a mound of seven bodies and an amalgam of three.
## The mound creeps round a loop, feeling for the stand-in and grabbing at it
## when it is in reach; the amalgam shambles after it and cartwheels at it
## along the straight. Whoever catches it absorbs a body (and grows), and when
## the two meet the smaller flows into the bigger. Run this script's scene, or
## add it to an empty scene as the root's script.
##
## What it shows of the API: moving the nodes (they work out their own speed),
## `aim`, `grab` / `grab_hits`, `start_roll` / `stop_roll`, `touches`,
## `absorb`, `merge_into` / `merged` / `grow`.

var mound: FleshMound
var amalgam: FleshMound
var stand_in: MeshInstance3D
var _time := 0.0
var _caught := 0.0
var _merged := false


func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.7, 0.73, 0.72)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.65, 0.66)
	environment.ambient_light_energy = 0.8
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, 30.0, 0.0)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	ground.mesh = BoxMesh.new()
	(ground.mesh as BoxMesh).size = Vector3(120, 1, 120)
	ground.position.y = -0.5
	add_child(ground)
	stand_in = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	stand_in.mesh = capsule
	add_child(stand_in)
	mound = FleshMound.new()
	mound.bodies = 7
	mound.measure_room = false
	add_child(mound)
	amalgam = FleshMound.new()
	amalgam.bodies = 3
	add_child(amalgam)
	amalgam.global_position = Vector3(12, 0, 12)
	amalgam.merged.connect(func(into: FleshMound) -> void: into.grow(amalgam.bodies))
	var camera := Camera3D.new()
	camera.position = Vector3(26, 16, 26)
	add_child(camera)
	camera.look_at(Vector3(0, 1, 0))


func _process(delta: float) -> void:
	_time += delta
	# The stand-in paces about the middle.
	stand_in.position = Vector3(sin(_time * 0.3) * 12.0, 0.85, cos(_time * 0.21) * 12.0)
	var feet := stand_in.position + Vector3.DOWN * 0.85
	# The mound: round a long loop at a crawl, grabbing at the stand-in when near.
	var angle := _time * 0.06
	var at := Vector3(sin(angle) * 14.0, 0.0, cos(angle) * 14.0)
	var ahead := Vector3(sin(angle + 0.01) * 14.0, 0.0, cos(angle + 0.01) * 14.0)
	mound.global_position = at
	mound.rotation.y = atan2(-(ahead.x - at.x), -(ahead.z - at.z))
	mound.aim = stand_in.position
	if feet.distance_to(at) < mound.reach():
		mound.grab(feet)
	# The amalgam: after the stand-in; rolling when it is far, shambling when near.
	if not _merged:
		var to := feet - amalgam.global_position
		to.y = 0.0
		var rolling := amalgam.roll_stage() == FleshMound.Roll.ROLLING
		if to.length() > 8.0 and amalgam.roll_stage() == FleshMound.Roll.NONE:
			amalgam.start_roll()
		elif to.length() < 3.0 and rolling:
			amalgam.stop_roll()
		var speed := 5.0 if rolling else (0.0 if amalgam.roll_stage() == FleshMound.Roll.WIND_UP else 1.5)
		amalgam.global_position += to.normalized() * speed * delta
		amalgam.rotation.y = atan2(-to.x, -to.z)
		# Meeting the mound, it flows into it.
		if amalgam.global_position.distance_to(mound.global_position) < 5.0 and amalgam.merging() < 0.0:
			amalgam.merge_into(mound)
			_merged = true
	# Caught: absorbed (a body dragged in; it grows), and the stand-in goes red a moment.
	_caught -= delta
	if _caught <= 0.0:
		for one: FleshMound in [mound, amalgam]:
			if one.visible and (one.grab_hits(feet, feet + Vector3.UP * 1.7, 0.3) or one.touches(stand_in.position, 0.3)):
				one.absorb(feet)
				_caught = 3.0
				break
	var material := StandardMaterial3D.new() if stand_in.material_override == null else stand_in.material_override as StandardMaterial3D
	material.albedo_color = Color(0.8, 0.15, 0.1) if _caught > 2.0 else Color(0.55, 0.55, 0.55)
	stand_in.material_override = material

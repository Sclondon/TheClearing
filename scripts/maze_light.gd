@tool
class_name MazeLight
## The light of the maze, after Inside: an overcast day, nearly without colour, so
## that the only strong colour is the shirts. A pale sky and a mist that thickens
## with distance and low down, until the far walls are flat grey shapes; soft light
## from above with soft shadows; a little glow round bright things. The game's
## World puts it up, and so does a MazeLayout open in the editor, so that a maze
## laid out by hand is seen as it will be played.


## Puts the sky, mist and sun under `parent`; `internal` keeps them out of a scene being saved.
static func put(parent: Node, internal := false) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.5, 0.56, 0.58)
	sky_material.sky_horizon_color = Color(0.74, 0.77, 0.76)
	sky_material.ground_horizon_color = Color(0.6, 0.63, 0.62)
	sky_material.ground_bottom_color = Color(0.3, 0.32, 0.31)
	sky_material.sun_angle_max = 0.0
	sky_material.sun_curve = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 1.3
	# The mist: thickening with distance, and a little more low down. (Light in the
	# editor, which looks across the whole maze from high over it.)
	var editing := Engine.is_editor_hint()
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.66, 0.7, 0.69)
	environment.fog_density = 0.0012 if editing else 0.0045
	environment.fog_sky_affect = 0.6
	environment.fog_aerial_perspective = 0.4
	environment.fog_height = 6.0
	environment.fog_height_density = 0.0 if editing else 0.004
	# Glow round the bright (the light past the exit, the sky between the walls).
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	environment.glow_bloom = 0.08
	environment.glow_hdr_threshold = 0.9
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# Most of the colour taken out.
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.72
	environment.adjustment_contrast = 1.1
	environment.adjustment_brightness = 1.0
	var world := WorldEnvironment.new()
	world.environment = environment
	parent.add_child(world, false, Node.INTERNAL_MODE_BACK if internal else Node.INTERNAL_MODE_DISABLED)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	# (high and soft: an overcast sun, its shadows short and blurred)
	sun.rotation_degrees = Vector3(-68.0, 25.0, 0.0)
	sun.light_color = Color(0.92, 0.94, 0.95)
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	sun.shadow_blur = 2.5
	sun.shadow_opacity = 0.75
	sun.directional_shadow_max_distance = 140.0
	parent.add_child(sun, false, Node.INTERNAL_MODE_BACK if internal else Node.INTERNAL_MODE_DISABLED)

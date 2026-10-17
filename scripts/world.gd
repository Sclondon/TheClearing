class_name World
extends Node3D
## One maze and everyone in it: the sky and light, the maze (MazeBuilder), this
## player (Outside's boy, scripts/player.gd) with his camera and touch controls,
## and a RemotePlayer for each of the others.
##
## Online, every game sends where its own player is a dozen times a second.
## A guest can only talk to the host, so the host passes each guest's news on
## to everyone (packets carry the seat they are about, not only who sent them).
## Nothing else needs sending to set up a maze: every copy builds the same one
## from the room's code and the round (Maze.seed_for).

signal escaped(slot: int, seconds: float)

const K_STATE := 83  # S
const SEND_EVERY := 1.0 / 12.0

## This player's seat (0 when playing alone).
var slot := 0
var online := false
var maze: Maze
var player: Player
var camera: FollowCamera
var touch: TouchControls
## slot -> RemotePlayer
var remotes := {}
## Seconds since the round began.
var clock := 0.0
## Seats that have got out, and how long each took.
var out := {}

var _send_in := 0.0


## Builds the maze for `seed_value` and puts everyone in the clearing.
## `players` is [{slot, look}] for everyone, this player included.
func setup(seed_value: int, my_slot: int, players: Array, is_online: bool) -> void:
	slot = my_slot
	online = is_online
	_sky()
	maze = Maze.generate(seed_value)
	var builder := MazeBuilder.new()
	builder.name = "Maze"
	add_child(builder)
	builder.build(maze)

	for entry: Dictionary in players:
		var seat := int(entry["slot"])
		var look: Dictionary = Looks.decode(str(entry.get("look", "")), seat)
		if seat == slot:
			player = load("res://player.tscn").instantiate()
			player.name = "Player"
			player.add_to_group(&"bridge_weights")
			add_child(player)
			player.global_position = spawn(seat)
			player.rotation.y = spawn_yaw(seat)
			Looks.apply(player.get_node("Rig") as CharacterRig, look)
		else:
			var other := RemotePlayer.new()
			other.name = "Remote%d" % seat
			other.slot = seat
			other.add_to_group(&"bridge_weights")
			add_child(other)
			other.place(spawn(seat), spawn_yaw(seat))
			Looks.apply(other.rig, look)
			remotes[seat] = other

	camera = FollowCamera.new()
	camera.target = player
	camera.mode = FollowCamera.Mode.ORBIT
	camera.indoors = true
	camera.distance = 5.0
	# (low, and looking a little above him, so that the walls tower)
	camera.look_height = 1.8
	camera.orbit_fov = 62.0
	camera._pitch = 0.16
	add_child(camera)
	camera.make_current()
	camera.snap()

	var hud := CanvasLayer.new()
	hud.layer = 0
	add_child(hud)
	touch = TouchControls.new()
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(touch)

	if online:
		Net.packet.connect(_on_packet)
		Net.left.connect(_on_left)


## Where a seat starts: round the middle of the clearing, facing out.
func spawn(seat: int) -> Vector3:
	var angle := seat * TAU / 4.0 + PI * 0.25
	return Vector3(sin(angle), 0.0, cos(angle)) * 2.2 + Vector3.UP * 0.05


func spawn_yaw(seat: int) -> float:
	return seat * TAU / 4.0 + PI * 0.25


## The light, after Inside: an overcast day, nearly without colour, so that the
## only strong colour is the shirts. A pale sky and a mist that thickens with
## distance and low down, until the far walls are flat grey shapes; soft light
## from above with soft shadows; a little glow round bright things, and the
## edges of the picture darkened (see _vignette).
func _sky() -> void:
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
	# The mist: thick with distance, and thicker still low down.
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.66, 0.7, 0.69)
	environment.fog_density = 0.009
	environment.fog_sky_affect = 0.6
	environment.fog_aerial_perspective = 0.4
	environment.fog_height = 6.0
	environment.fog_height_density = 0.01
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
	add_child(world)
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
	add_child(sun)
	_vignette()


## The edges of the picture darkened, as through a lens, and a faint grain over
## it all. Under the controls.
func _vignette() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Vignette"
	layer.layer = -1
	add_child(layer)
	var cover := ColorRect.new()
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float strength = 0.55;
uniform float grain = 0.035;
void fragment() {
	vec2 from_middle = (UV - 0.5) * vec2(1.0, 1.15);
	float dark = smoothstep(0.32, 0.85, length(from_middle)) * strength;
	float noise = fract(sin(dot(FRAGCOORD.xy + fract(TIME) * 61.0, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	// Dark towards the edges, and each pixel a touch lighter or darker at random.
	float speck = noise * grain;
	float cover = clamp(dark + abs(speck), 0.0, 1.0);
	vec3 tint = vec3(0.03, 0.035, 0.035) * dark + vec3(speck > 0.0 ? abs(speck) : 0.0);
	COLOR = vec4(tint / max(cover, 0.001), cover);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	cover.material = material
	layer.add_child(cover)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	clock += delta
	if not out.has(slot) and maze.escaped(player.global_position):
		_got_out(slot, clock)
		if online:
			Net.send_json(Net.BROADCAST, {"out": slot, "time": clock})
	if online:
		_send_in -= delta
		if _send_in <= 0.0:
			_send_in = SEND_EVERY
			Net.send(Net.BROADCAST, K_STATE, _state(slot, player.global_position, player.velocity, player.facing_yaw, player.is_on_floor()))


func _got_out(seat: int, seconds: float) -> void:
	if out.has(seat):
		return
	out[seat] = seconds
	if remotes.has(seat):
		remotes[seat].escaped = true
	escaped.emit(seat, seconds)


## Whether everyone in the maze has got out.
func all_out() -> bool:
	if not out.has(slot):
		return false
	for seat: int in remotes:
		if not out.has(seat):
			return false
	return true


static func _state(seat: int, at: Vector3, moving: Vector3, yaw: float, grounded: bool) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(30)
	data[0] = seat
	data.encode_float(1, at.x)
	data.encode_float(5, at.y)
	data.encode_float(9, at.z)
	data.encode_float(13, moving.x)
	data.encode_float(17, moving.y)
	data.encode_float(21, moving.z)
	data.encode_float(25, yaw)
	data[29] = 1 if grounded else 0
	return data


func _on_packet(from: int, kind: int, data: PackedByteArray) -> void:
	if kind == K_STATE and data.size() >= 30:
		var seat := data[0]
		# (a guest speaks only for itself)
		if Net.is_host and from != slot:
			seat = from
			data[0] = from
			Net.send(Net.BROADCAST, K_STATE, data)
		if seat == slot or not remotes.has(seat):
			return
		remotes[seat].hear(
			Vector3(data.decode_float(1), data.decode_float(5), data.decode_float(9)),
			Vector3(data.decode_float(13), data.decode_float(17), data.decode_float(21)),
			data.decode_float(25), data[29] == 1)
	elif kind == Net.K_JSON:
		var message: Variant = JSON.parse_string(data.get_string_from_utf8())
		if not (message is Dictionary):
			return
		if message.has("out"):
			var seat := int(message["out"])
			if Net.is_host and from != slot:
				seat = from
				message["out"] = from
				Net.send_json(Net.BROADCAST, message)
			_got_out(seat, float(message.get("time", 0.0)))


func _on_left(seat: int) -> void:
	if remotes.has(seat):
		remotes[seat].queue_free()
		remotes.erase(seat)

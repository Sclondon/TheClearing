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
		var look: Dictionary = Looks.decode(str(entry.get("look", "")))
		if seat == slot:
			player = load("res://player.tscn").instantiate()
			player.name = "Player"
			add_child(player)
			player.global_position = spawn(seat)
			player.rotation.y = spawn_yaw(seat)
			CharacterLook.apply(player.get_node("Rig") as CharacterRig, look)
		else:
			var other := RemotePlayer.new()
			other.name = "Remote%d" % seat
			other.slot = seat
			add_child(other)
			other.place(spawn(seat), spawn_yaw(seat))
			CharacterLook.apply(other.rig, look)
			remotes[seat] = other

	camera = FollowCamera.new()
	camera.target = player
	camera.mode = FollowCamera.Mode.ORBIT
	camera.indoors = true
	camera.distance = 5.0
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


func _sky() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.42, 0.52, 0.62)
	sky_material.sky_horizon_color = Color(0.72, 0.72, 0.66)
	sky_material.ground_horizon_color = Color(0.5, 0.52, 0.46)
	sky_material.ground_bottom_color = Color(0.22, 0.24, 0.2)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# A haze that hides how far the passages go.
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.62, 0.66, 0.64)
	environment.fog_density = 0.022
	environment.fog_sky_affect = 0.35
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)


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

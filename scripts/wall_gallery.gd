@tool
extends Node3D
## The wall gallery (scenes/wall_gallery.tscn): a room to look at every way a Wall
## can be built and surfaced, side by side, each with its name. The walls and
## their labels are ordinary nodes in the scene (made by tools/make_wall_gallery.gd,
## and free to change by hand); this puts the game's light and mist round them and
## a floor under them, and when the scene is played, the boy, to walk about among
## them with the game's camera and controls.

## Where the boy starts, and which way he faces.
@export var start := Vector3(0.0, 0.1, 30.0)
@export var start_yaw := PI
## In the editor, whether it is lit as in the game.
@export var game_light := true
## How thick the mist is here (the game's is thick, for a 100 m clearing; a gallery wants to see across).
@export_range(0.0, 0.02, 0.0005) var mist := 0.002

var _shown: Array[Node] = []


func _ready() -> void:
	var editing := Engine.is_editor_hint()
	if not editing or game_light:
		var before := get_child_count(true)
		MazeLight.put(self, true)
		for i in range(before, get_child_count(true)):
			var added := get_child(i, true)
			if added is WorldEnvironment:
				(added as WorldEnvironment).environment.fog_density = mist
				(added as WorldEnvironment).environment.fog_height_density = 0.0
			_shown.append(get_child(i, true))
	_floor()
	if not editing:
		_boy()


func _floor() -> void:
	var body := StaticBody3D.new()
	body.name = "Floor"
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	var plane := PlaneMesh.new()
	plane.size = Vector2(600.0, 600.0)
	var look := MeshInstance3D.new()
	look.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.25, 0.26, 0.24)
	ground.roughness = 1.0
	look.material_override = ground
	body.add_child(look)
	add_child(body, false, Node.INTERNAL_MODE_BACK)


## The boy, his camera and touch controls, as a round has them.
func _boy() -> void:
	var player: Player = load("res://player.tscn").instantiate()
	player.name = "Player"
	add_child(player)
	player.global_position = start
	player.rotation.y = start_yaw
	Looks.apply(player.get_node("Rig") as CharacterRig, Looks.decode("p1", 0))
	player.auto_sprint = false
	var camera := FollowCamera.new()
	camera.target = player
	camera.mode = FollowCamera.Mode.ORBIT
	camera.distance = 6.0
	camera.look_height = 1.8
	add_child(camera)
	camera.make_current()
	camera.snap()
	var hud := CanvasLayer.new()
	add_child(hud)
	var touch := TouchControls.new()
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(touch)

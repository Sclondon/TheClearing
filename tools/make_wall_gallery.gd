extends SceneTree
## Makes scenes/wall_gallery.tscn: the room of walls (see scripts/wall_gallery.gd).
## Its first row is every look of Wall in the Basic style (a plain box); behind it,
## a row for each decorated style, in a few looks. Each wall has its name on a sign
## in front of it. Run it again after adding a look or a style; changes made by
## hand to the scene are lost when it is.
##
##     godot --headless --path . -s res://tools/make_wall_gallery.gd

const WIDE := 10.0
const HIGH := 18.0
const DEEP := 3.0
## Between walls in a row, and between rows.
const GAP := 6.0
const ROW := 32.0
## The looks the decorated rows are shown in.
const DECORATED_LOOKS := [Wall.Look.CAST, Wall.Look.SLABS, Wall.Look.RIBBED]


func _initialize() -> void:
	var room := Node3D.new()
	room.name = "WallGallery"
	room.set_script(load("res://scripts/wall_gallery.gd"))
	var rows: Array = []
	# Every look, plain.
	var looks: Array = []
	for name: String in Wall.Look.keys():
		if name != "CUSTOM":
			looks.append([Wall.Style.BASIC, Wall.Look[name]])
	rows.append(looks)
	# Each decorated style, in a few looks.
	for style_name: String in Wall.Style.keys():
		if style_name == "BASIC":
			continue
		var row: Array = []
		for look: int in DECORATED_LOOKS:
			row.append([Wall.Style[style_name], look])
		rows.append(row)
	for r in rows.size():
		var row: Array = rows[r]
		var group := Node3D.new()
		group.name = "Basic" if r == 0 else String(Wall.Style.keys()[row[0][0]]).capitalize().replace(" ", "")
		room.add_child(group)
		group.owner = room
		var span := row.size() * WIDE + (row.size() - 1) * GAP
		for i in row.size():
			var style: int = row[i][0]
			var look: int = row[i][1]
			var title := "%s / %s" % [String(Wall.Style.keys()[style]).capitalize(), _look_name(look)]
			var wall := Wall.new()
			wall.name = title.replace(" / ", "_").replace(" ", "")
			var x := -span * 0.5 + WIDE * 0.5 + i * (WIDE + GAP)
			wall.position = Vector3(x, 0.0, -r * ROW)
			wall.width = WIDE
			wall.height = HIGH
			wall.depth = DEEP
			wall.style = style
			wall.look = look
			group.add_child(wall)
			wall.owner = room
			var sign := Label3D.new()
			sign.name = wall.name + "_Sign"
			sign.text = title
			sign.font_size = 96
			sign.pixel_size = 0.01
			sign.outline_size = 18
			sign.modulate = Color(0.95, 0.93, 0.85)
			sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			sign.position = Vector3(x, 1.0, -r * ROW + DEEP * 0.5 + 3.4)
			group.add_child(sign)
			sign.owner = room
	var scene := PackedScene.new()
	var error := scene.pack(room)
	if error == OK:
		DirAccess.make_dir_recursive_absolute("res://scenes")
		error = ResourceSaver.save(scene, "res://scenes/wall_gallery.tscn")
	print("saved res://scenes/wall_gallery.tscn: ", "ok" if error == OK else str(error))
	room.free()
	quit(0 if error == OK else 1)


static func _look_name(look: int) -> String:
	for name: String in Wall.Look.keys():
		if Wall.Look[name] == look:
			return name.capitalize()
	return str(look)

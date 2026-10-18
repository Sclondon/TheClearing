extends SceneTree
## Makes textures/stone_blocks.png, the stone the Wall scene is textured with by
## default: courses of big grey blocks, each its own tone, with dark joints and a
## little weathering. It tiles seamlessly both ways. One tile is 4 courses of
## 2 blocks (with the courses staggered), 512 pixels square.
##
##     godot --headless --path . -s res://tools/make_stone_texture.gd

const SIZE := 512
const COURSES := 4
const BLOCKS := 2
const JOINT := 5
const STONE := Color(0.55, 0.56, 0.53)
const MORTAR := Color(0.24, 0.25, 0.23)


func _initialize() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	var fine := FastNoiseLite.new()
	fine.seed = 11
	fine.frequency = 0.15
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var course_height := SIZE / COURSES
	var block_width := SIZE / BLOCKS
	# Each block's own tone, by [course, block].
	var tones := {}
	for course in COURSES:
		for block in BLOCKS + 1:
			tones[Vector2i(course, block)] = rng.randf_range(0.86, 1.1)
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var course := y / course_height
			# (every other course is set half a block along)
			var shifted := (x + (block_width / 2 if course % 2 == 1 else 0)) % SIZE
			var block := shifted / block_width
			var in_x := shifted % block_width
			var in_y := y % course_height
			var edge := mini(mini(in_x, block_width - 1 - in_x), mini(in_y, course_height - 1 - in_y))
			# Noise sampled on a torus, so that the texture tiles.
			var angle := Vector2(float(x) / SIZE, float(y) / SIZE) * TAU
			var r := SIZE / TAU
			var n := noise.get_noise_3d(cos(angle.x) * r, sin(angle.x) * r, cos(angle.y) * r + sin(angle.y) * r * 0.5)
			var speck := fine.get_noise_3d(cos(angle.x) * r * 3.0, sin(angle.x) * r * 3.0, cos(angle.y) * r * 3.0 + sin(angle.y) * r * 1.5)
			var colour: Color
			if edge < JOINT:
				colour = MORTAR * (0.9 + 0.2 * n)
			else:
				var tone: float = tones[Vector2i(course, block % BLOCKS)]
				# (the edges of each block a little darker and rounded off, the middle worn)
				var bevel := clampf(float(edge - JOINT) / 10.0, 0.0, 1.0)
				colour = STONE * tone * (0.82 + 0.18 * bevel) * (0.92 + 0.16 * n + 0.06 * speck)
			image.set_pixel(x, y, Color(colour.r, colour.g, colour.b))
	DirAccess.make_dir_recursive_absolute("res://textures")
	var error := image.save_png("res://textures/stone_blocks.png")
	print("saved res://textures/stone_blocks.png: ", "ok" if error == OK else str(error))
	quit()

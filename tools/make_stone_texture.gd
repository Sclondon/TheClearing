extends SceneTree
## Makes the stone the Wall scene is textured with by default, as three images
## that tile seamlessly both ways:
##   textures/stone_blocks.png         the colour
##   textures/stone_blocks_normal.png  a normal map, so joints and chips catch the light
##   textures/stone_blocks_height.png  the height everything is worked out from
##
## A tile is meant to cover several metres of wall (Wall.tile_size): four courses
## of big blocks, set out unevenly, every course's joints in their own places. The
## blocks' edges are worn and chipped and round down into deep joints of gritty
## mortar; their faces are pitted and grained, with a few fine cracks and stains,
## each block in its own tone. 2048 pixels square.
##
##     godot --headless --path . -s res://tools/make_stone_texture.gd

const SIZE := 2048
const COURSES := 4
## How many blocks in a course, at most and at least, and how narrow one may be (as a share of the tile).
const BLOCKS := Vector2i(2, 3)
const NARROWEST := 0.22
## Half the width of a joint, in pixels (it varies by up to `JOINT_WOBBLE` along it).
const JOINT := 15.0
const JOINT_WOBBLE := 7.0
## How far in from a joint a block's edge rounds over, and how deep chips go.
const ROUND := 46.0
const CHIPS := 16.0
const STONE := Color(0.56, 0.57, 0.54)
const MORTAR := Color(0.33, 0.32, 0.29)
## How strong the normal map's relief is.
const RELIEF := 11.0


func _initialize() -> void:
	var started := Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5

	# Noises, as seamless images (so the texture tiles): broad wobble of the
	# joints, chips at the edges, the faces' grain and pits, stains, cracks, grit.
	var wobble := _noise(11, 0.004, 3)
	var chips := _noise(12, 0.03, 4)
	var grain := _noise(13, 0.06, 5)
	var pits := _noise(14, 0.12, 2)
	var stains := _noise(15, 0.0025, 4)
	var crack := _noise(16, 0.008, 5, FastNoiseLite.TYPE_CELLULAR)
	var grit := _noise(17, 0.35, 1)

	# Where the courses run, each with the places of its vertical joints.
	var course_height := float(SIZE) / COURSES
	var joints := []
	var tones := []
	for c in COURSES:
		var count := rng.randi_range(BLOCKS.x, BLOCKS.y)
		var cuts := []
		var start := rng.randf() * SIZE
		var left := 1.0
		for b in count:
			cuts.append(fposmod(start, SIZE))
			var share := left / (count - b) if b == count - 1 else clampf(rng.randf_range(NARROWEST, left - NARROWEST * (count - b - 1)), NARROWEST, left)
			start += share * SIZE
			left -= share
		joints.append(cuts)
		var row_tones := []
		for b in count:
			row_tones.append([rng.randf_range(0.84, 1.1), rng.randf_range(-0.03, 0.03)])
		tones.append(row_tones)

	var height := PackedFloat32Array()
	height.resize(SIZE * SIZE)
	var colour := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		var course := int(y / course_height)
		var cuts: Array = joints[course]
		for x in SIZE:
			var w := wobble.get_pixel(x, y).r - 0.5
			# How far from the nearest joint, horizontal or vertical (wrapping round the tile).
			var in_y := fposmod(y + w * 30.0, course_height)
			var to_row := minf(in_y, course_height - in_y)
			var to_cut := 1e9
			# (which block: the one after the joint most recently passed, going right)
			var block := 0
			var since := 1e9
			for b in cuts.size():
				var d := fposmod(x - float(cuts[b]) + w * 26.0, SIZE)
				to_cut = minf(to_cut, minf(d, SIZE - d))
				if d < since:
					since = d
					block = b
			var edge := minf(to_row, to_cut)
			var half_joint := JOINT + (wobble.get_pixel((x * 3) % SIZE, (y * 3) % SIZE).r - 0.5) * 2.0 * JOINT_WOBBLE
			# Chipped edges: the edge wears away further where the chip noise is high.
			var chip := chips.get_pixel(x, y).r
			var worn := edge - half_joint - maxf(chip - 0.45, 0.0) * 2.0 * CHIPS
			var h: float
			var c: Color
			var g := grain.get_pixel(x, y).r
			var p := pits.get_pixel(x, y).r
			if worn <= 0.0:
				# Mortar: sunk deep, gritty, darker the deeper into the joint.
				var depth := clampf(-worn / half_joint, 0.0, 1.0)
				h = 0.12 - depth * 0.06 + (grit.get_pixel(x, y).r - 0.5) * 0.05
				c = MORTAR * (0.75 + 0.35 * grit.get_pixel(x, y).r) * (1.0 - depth * 0.35)
			else:
				# The block: rounding over at its edge, its face pitted and grained.
				var over := clampf(worn / ROUND, 0.0, 1.0)
				over = sqrt(over * (2.0 - over))
				# (each face a little uneven too, as split stone is)
				var swell := stains.get_pixel((x * 2 + 300) % SIZE, (y * 2 + 700) % SIZE).r
				h = 0.24 + 0.58 * over + (swell - 0.5) * 0.14 + (g - 0.5) * 0.03 - maxf(0.6 - p, 0.0) * 0.2
				var tone: Array = tones[course][block % (tones[course] as Array).size()]
				var hue: float = tone[1]
				c = Color(STONE.r + hue, STONE.g, STONE.b - hue) * float(tone[0])
				c *= 0.95 + (g - 0.5) * 0.1
				# (broad worn patches, paler, and darker hollows)
				c *= 0.92 + (swell - 0.5) * 0.22
				# Darker towards its edge, as worn stone goes; pits hold dirt.
				c *= 0.72 + 0.28 * over
				c *= 1.0 - maxf(0.6 - p, 0.0) * 0.6
				# A few fine cracks across the faces.
				var k := crack.get_pixel(x, y).r
				if k < 0.035 and stains.get_pixel((x + 512) % SIZE, y).r > 0.5:
					c *= 0.55
					h -= 0.08
			# Broad stains run over everything.
			var s := stains.get_pixel(x, y).r
			c *= 0.82 + 0.3 * s
			height[x + y * SIZE] = clampf(h, 0.0, 1.0)
			colour.set_pixel(x, y, Color(clampf(c.r, 0, 1), clampf(c.g, 0, 1), clampf(c.b, 0, 1)))
		if y % 256 == 0:
			print("row %d of %d" % [y, SIZE])

	# The normal map, from the height (wrapping round, so it tiles), and the height itself.
	var normal := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var heights := Image.create(SIZE, SIZE, false, Image.FORMAT_L8)
	for y in SIZE:
		for x in SIZE:
			var left := height[posmod(x - 1, SIZE) + y * SIZE]
			var right := height[posmod(x + 1, SIZE) + y * SIZE]
			var up := height[x + posmod(y - 1, SIZE) * SIZE]
			var down := height[x + posmod(y + 1, SIZE) * SIZE]
			var n := Vector3((left - right) * RELIEF, (up - down) * RELIEF, 1.0).normalized()
			# (OpenGL-style: green is up the image)
			normal.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
			var hv := height[x + y * SIZE]
			heights.set_pixel(x, y, Color(hv, hv, hv))
	DirAccess.make_dir_recursive_absolute("res://textures")
	colour.save_png("res://textures/stone_blocks.png")
	normal.save_png("res://textures/stone_blocks_normal.png")
	heights.save_png("res://textures/stone_blocks_height.png")
	print("saved the stone textures in %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	quit()


## A noise as a seamless image the size of the tile, 0..1 in its red.
func _noise(seed_value: int, frequency: float, octaves: int, kind := FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = kind
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	if kind == FastNoiseLite.TYPE_CELLULAR:
		noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var image := noise.get_seamless_image(SIZE, SIZE)
	image.convert(Image.FORMAT_RGB8)
	return image

extends SceneTree
## Makes the brutalist concrete looks of the Wall scene (see Wall.LOOKS), each as
## a colour and a normal map that tile seamlessly both ways, 2048 pixels square,
## in textures/:
##   concrete_panels    smooth cast concrete in big formwork panels: fine raised
##                      seams where the formwork leaked, rows of tie holes, rain streaks
##   concrete_boards    board-marked: cast against planks, each board's grain and
##                      edge printed in it, every board a little proud or sunk
##   concrete_weathered stained and streaked, cracked, with spalled patches where
##                      the gravel in it shows
##   concrete_monolith  plain slabs between deep vertical recesses
## Grey, a little cool, and blotchy in big patches, as cast concrete is. (The
## stone blocks are tools/make_stone_texture.gd's.)
##
##     godot --headless --path . -s res://tools/make_wall_textures.gd [-- <look>]

const SIZE := 2048
const CONCRETE := Color(0.45, 0.46, 0.47)

var _blotch: Image
var _pores: Image
var _grain: Image
var _streaks: Image
var _cracks: Image
var _patches: Image
var _gravel: Image


func _initialize() -> void:
	var started := Time.get_ticks_msec()
	_blotch = _noise(21, 0.0017, 5)
	_pores = _noise(22, 0.5, 1)
	_grain = _noise(23, 0.05, 4)
	# Streaks run down: a noise stretched 32 times down the tile (still tiling), long and few.
	_streaks = _noise(24, 0.035, 3, SIZE, SIZE / 32)
	_cracks = _noise(25, 0.006, 4, SIZE, SIZE, FastNoiseLite.TYPE_CELLULAR)
	_patches = _noise(26, 0.006, 3)
	_gravel = _noise(27, 0.09, 2, SIZE, SIZE, FastNoiseLite.TYPE_CELLULAR)
	var only := OS.get_cmdline_user_args()
	for look: String in ["concrete_panels", "concrete_boards", "concrete_weathered", "concrete_monolith"]:
		if only.is_empty() or only.has(look):
			_make(look)
	print("made the wall textures in %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	quit()


func _make(look: String) -> void:
	var height := PackedFloat32Array()
	height.resize(SIZE * SIZE)
	var colour := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var relief := 6.0
	for y in SIZE:
		for x in SIZE:
			var result: Array
			match look:
				"concrete_panels":
					result = _panels(x, y)
				"concrete_boards":
					result = _boards(x, y)
				"concrete_weathered":
					result = _weathered(x, y)
				_:
					result = _monolith(x, y)
			height[x + y * SIZE] = clampf(result[0], 0.0, 1.0)
			var c: Color = result[1]
			colour.set_pixel(x, y, Color(clampf(c.r, 0, 1), clampf(c.g, 0, 1), clampf(c.b, 0, 1)))
	if look == "concrete_boards":
		relief = 9.0
	elif look == "concrete_monolith":
		relief = 10.0
	_save(look, colour, height, relief)


## What all of them start from: cast concrete, blotchy in big patches, with fine
## pores and a little grain, a little cool. [height, colour]
func _cast(x: int, y: int) -> Array:
	var b := _blotch.get_pixel(x, y).r
	var p := _pores.get_pixel(x, y).r
	var g := _grain.get_pixel(x, y).r
	var tone := 0.9 + (b - 0.5) * 0.18 + (g - 0.5) * 0.05
	var c := Color(CONCRETE.r * tone, CONCRETE.g * tone, CONCRETE.b * tone * 1.02)
	var h := 0.6 + (g - 0.5) * 0.04
	# Pores: tiny dark pits.
	if p < 0.18:
		c *= 0.72
		h -= 0.06
	return [h, c]


## Rain streaks running down from above, darker where they gather. 0..1 (how much).
func _rain(x: int, y: int, strength: float) -> float:
	var s := _streaks.get_pixel(x, y / 32).r
	var reach := _blotch.get_pixel((x * 3) % SIZE, (y + 900) % SIZE).r
	# (soft at their edges, and fading in and out down their length)
	return smoothstep(0.6, 0.8, s) * clampf(reach * 1.6 - 0.4, 0.0, 1.0) * strength * 0.7


func _panels(x: int, y: int) -> Array:
	var cast := _cast(x, y)
	var h: float = cast[0]
	var c: Color = cast[1]
	# Formwork panels: 3 across, 4 down a tile, every other row offset half a panel.
	var panel := Vector2(SIZE / 3.0, SIZE / 4.0)
	var row := int(y / panel.y)
	var px := fposmod(x + (panel.x * 0.5 if row % 2 == 1 else 0.0), panel.x)
	var py := fposmod(float(y), panel.y)
	var seam := minf(minf(px, panel.x - px), minf(py, panel.y - py))
	# Each panel cast a shade apart.
	var panel_tone := 0.94 + 0.12 * _patches.get_pixel(int(x / panel.x) * 97 % SIZE, row * 151 % SIZE).r
	c *= panel_tone
	if seam < 3.0:
		# A thin raised fin where the forms met and the cement bled out, darker.
		h += 0.16 * (1.0 - seam / 3.0)
		c *= 0.68
	elif seam < 10.0:
		c *= 0.88 + 0.12 * (seam - 3.0) / 7.0
	# Tie holes: two rows of three in each panel, round, dark and sunk.
	var hole := Vector2(fposmod(px, panel.x / 3.0) - panel.x / 6.0, fposmod(py, panel.y / 2.0) - panel.y / 4.0)
	var r := hole.length()
	if r < 17.0:
		h -= 0.35 * (1.0 - r / 17.0) + 0.1
		c *= 0.3 + 0.45 * (r / 17.0)
	elif r < 26.0:
		# (with a ring of grey round each where the cone was)
		c *= 0.86 + 0.14 * (r - 17.0) / 9.0
	c *= 1.0 - _rain(x, y, 0.4)
	return [h, c]


func _boards(x: int, y: int) -> Array:
	var cast := _cast(x, y)
	var h: float = cast[0]
	var c: Color = cast[1]
	# Boards across the wall, 40 to a tile (some 20 cm each on a tile of 8 m), each its own width.
	var boards := 32
	var board_height := float(SIZE) / boards
	var board := int(y / board_height)
	var in_board := fposmod(float(y), board_height)
	var proud := (_patches.get_pixel(board * 37 % SIZE, board * 113 % SIZE).r - 0.5) * 0.12
	# The grain of the wood, printed in: long and wavy along the board.
	var along := _grain.get_pixel(x / 16 + board * 61 % (SIZE / 16), (y * 2 + board * 89) % SIZE).r
	var wood := sin((y + along * 60.0) * 0.9) * 0.5 + 0.5
	h += proud + (wood - 0.5) * 0.08
	c *= 0.95 + proud * 1.3 + (wood - 0.5) * 0.12
	# Where boards met: a fine line, and a lip where the next was set a little out.
	var edge := minf(in_board, board_height - in_board)
	if edge < 2.0:
		h -= 0.1
		c *= 0.78
	# Board ends here and there, staggered.
	var end := fposmod(x + board * 523.0, 700.0 + (board % 3) * 170.0)
	if end < 2.0:
		h -= 0.08
		c *= 0.68
	c *= 1.0 - _rain(x, y, 0.45)
	return [h, c]


func _weathered(x: int, y: int) -> Array:
	var cast := _cast(x, y)
	var h: float = cast[0]
	var c: Color = cast[1]
	# Heavy staining, darker and a little green-brown.
	var rain := _rain(x, y, 0.8)
	var damp := _patches.get_pixel(x, y).r
	c *= 1.0 - rain * 0.9
	c = c.lerp(Color(0.25, 0.27, 0.23), clampf((damp - 0.55) * 1.6, 0.0, 0.5))
	# Spalls: the skin gone, and the gravel in the concrete showing, rough.
	var spall := _patches.get_pixel((x + 1024) % SIZE, (y + 333) % SIZE).r
	if spall > 0.74:
		var into := clampf((spall - 0.74) * 12.0, 0.0, 1.0)
		var stone := _gravel.get_pixel(x, y).r
		h -= 0.2 * into
		h += (stone - 0.5) * 0.12 * into
		c = c.lerp(Color(0.5, 0.5, 0.48) * (0.7 + 0.5 * stone), into * 0.8)
	# Cracks wandering across it.
	var k := _cracks.get_pixel(x, y).r
	if k < 0.03:
		h -= 0.18
		c *= 0.45
	return [h, c]


func _monolith(x: int, y: int) -> Array:
	var cast := _cast(x, y)
	var h: float = cast[0]
	var c: Color = cast[1]
	# Two slabs across a tile with a deep recess between, and a fine lift line every quarter down.
	var slab := SIZE / 2.0
	var sx := fposmod(float(x) + slab * 0.25, slab)
	var to_recess := minf(sx, slab - sx)
	var recess := 22.0
	if to_recess < recess:
		var deep := 1.0 - smoothstep(recess - 6.0, recess, to_recess)
		h -= 0.45 * deep
		c *= 1.0 - 0.45 * deep
	var lift := fposmod(float(y), SIZE / 4.0)
	if minf(lift, SIZE / 4.0 - lift) < 1.5:
		h -= 0.04
		c *= 0.88
	# Streaks below each lift line and down the recesses.
	c *= 1.0 - _rain(x, y, 0.55)
	return [h, c]


## Saves the colour and a normal map worked out from the height (wrapping, so it tiles).
func _save(look: String, colour: Image, height: PackedFloat32Array, relief: float) -> void:
	var normal := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var left := height[posmod(x - 1, SIZE) + y * SIZE]
			var right := height[posmod(x + 1, SIZE) + y * SIZE]
			var up := height[x + posmod(y - 1, SIZE) * SIZE]
			var down := height[x + posmod(y + 1, SIZE) * SIZE]
			var n := Vector3((left - right) * relief, (up - down) * relief, 1.0).normalized()
			normal.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	DirAccess.make_dir_recursive_absolute("res://textures")
	colour.save_png("res://textures/%s.png" % look)
	normal.save_png("res://textures/%s_normal.png" % look)
	print("saved res://textures/%s.png and its normal map" % look)


## A noise as a seamless image (`width` by `tall`), 0..1 in its red.
func _noise(seed_value: int, frequency: float, octaves: int, width := SIZE, tall := SIZE, kind := FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = kind
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	if kind == FastNoiseLite.TYPE_CELLULAR:
		noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var image := noise.get_seamless_image(width, tall)
	image.convert(Image.FORMAT_RGB8)
	return image

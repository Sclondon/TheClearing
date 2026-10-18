extends SceneTree
## Makes textures/mud.png, the close detail of the maze's dirt floor (see
## MazeStone's ground shader), 512 pixels square, tiling both ways, about two
## and a half metres of ground across:
##   r  how high the ground stands: low clods, fine grit, pebbles pressed into it
##      (each a dome, sunk a little at its rim), dried-mud cracks cut down
##   g  pebbles: 0 where there is none, else how light that pebble is
##   b  cracks: 1 on one, falling to 0 a few millimetres off
##   a  the tone of the grit, from grain to grain
## The shader lays it over the ground twice, at two sizes and turned two ways,
## so that it does not repeat, and does everything broad (wet and dry, mud,
## puddles, moss) itself, from smooth noise read out of textures/mud_noise.png:
## 256 pixels square of numbers at random, which drawn smoothly between pixels is
## the same noise as working it out from a hash, at a quarter of the cost.
##
##     godot --headless --path . -s res://tools/make_mud_texture.gd

const SIZE := 512
const PEBBLES := 1000


func _initialize() -> void:
	var started := Time.get_ticks_msec()
	var clods := _noise(31, 0.011, 4)
	var lumps := _noise(32, 0.05, 3)
	var grit := _noise(33, 0.45, 1)
	var tone := _noise(34, 0.12, 2)
	var cracks := _cracks(37, 9)

	var height := PackedFloat32Array()
	height.resize(SIZE * SIZE)
	var pebble := PackedFloat32Array()
	pebble.resize(SIZE * SIZE)
	var crack := PackedFloat32Array()
	crack.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			var i := x + y * SIZE
			var split := cracks[x + y * SIZE]
			crack[i] = split
			height[i] = clods.get_pixel(x, y).r * 0.5 + lumps.get_pixel(x, y).r * 0.22 + grit.get_pixel(x, y).r * 0.1 - split * 0.18

	# Pebbles, small ones many and big ones few, each an oval dome pressed into the
	# ground (its rim a little sunk), wrapping round the edges of the tile.
	var rng := RandomNumberGenerator.new()
	rng.seed = 36
	for p in PEBBLES:
		var r := 1.3 * pow(2.0, rng.randf() * rng.randf() * rng.randf() * 3.4)
		var long := r * rng.randf_range(1.0, 1.7)
		var turn := rng.randf() * TAU
		var cx := rng.randf() * SIZE
		var cy := rng.randf() * SIZE
		var light := rng.randf_range(0.25, 1.0)
		# (no pebble is a true oval: its edge wanders)
		var bumps := Vector4(rng.randf_range(0.08, 0.2), rng.randf() * TAU, rng.randf_range(0.04, 0.12), rng.randf() * TAU)
		var stands := rng.randf_range(0.5, 1.0)
		var reach := ceili(long + 2.0)
		var c := cos(turn)
		var s := sin(turn)
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var u := (dx * c + dy * s) / long
				var v := (-dx * s + dy * c) / r
				var angle := atan2(v, u)
				var edge := 1.0 + bumps.x * sin(3.0 * angle + bumps.y) + bumps.z * sin(5.0 * angle + bumps.w)
				var d := (u * u + v * v) / (edge * edge)
				if d > 1.6:
					continue
				var i := posmod(int(cx) + dx, SIZE) + posmod(int(cy) + dy, SIZE) * SIZE
				if d < 1.0:
					var dome := sqrt(1.0 - d) * stands * minf(r, 4.0) * 0.12
					height[i] = maxf(height[i], 0.42 + dome)
					pebble[i] = maxf(pebble[i], light * smoothstep(1.0, 0.75, d))
				else:
					# (the dirt pressed down round it)
					height[i] -= 0.04 * (1.6 - d) / 0.6

	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var i := x + y * SIZE
			image.set_pixel(x, y, Color(clampf(height[i], 0.0, 1.0), pebble[i], crack[i], 0.25 + tone.get_pixel(x, y).r * 0.75))
	var error := image.save_png("res://textures/mud.png")
	var noise := Image.create_empty(256, 256, false, Image.FORMAT_L8)
	var chance := RandomNumberGenerator.new()
	chance.seed = 38
	for y in 256:
		for x in 256:
			var value := chance.randf()
			noise.set_pixel(x, y, Color(value, value, value))
	if error == OK:
		error = noise.save_png("res://textures/mud_noise.png")
	print("textures/mud.png ", "saved" if error == OK else str(error), " in %d ms" % (Time.get_ticks_msec() - started))
	quit(0 if error == OK else 1)


## Dried-mud cracks: a net of cells `across` to the tile, its lines wavering, as
## how near each pixel is to one (1 on it), wrapping round the edges.
func _cracks(seed_value: int, across: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var points: Array[Vector2] = []
	for i in across * across:
		points.append(Vector2(rng.randf(), rng.randf()))
	var waver := _noise(seed_value + 1, 0.02, 2)
	var waver2 := _noise(seed_value + 2, 0.02, 2)
	var cell := float(SIZE) / across
	var near := PackedFloat32Array()
	near.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x + (waver.get_pixel(x, y).r - 0.5) * 18.0, y + (waver2.get_pixel(x, y).r - 0.5) * 18.0) / cell
			var whole := p.floor()
			var first := Vector2.ZERO
			var second := Vector2.ZERO
			var d1 := 99.0
			var d2 := 99.0
			for j in range(-1, 2):
				for i in range(-1, 2):
					var c := whole + Vector2(i, j)
					var k := posmod(int(c.x), across) + posmod(int(c.y), across) * across
					var at := c + points[k]
					var d := at.distance_squared_to(p)
					if d < d1:
						d2 = d1
						second = first
						d1 = d
						first = at
					elif d < d2:
						d2 = d
						second = at
			# (how far from the line halfway between the two nearest, in pixels)
			var gap := absf((p - (first + second) * 0.5).dot((second - first).normalized())) * cell
			near[x + y * SIZE] = 1.0 - smoothstep(0.4, 2.2, gap)
	return near


func _noise(seed_value: int, frequency: float, octaves: int) -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	var image := noise.get_seamless_image(SIZE, SIZE)
	image.convert(Image.FORMAT_L8)
	return image

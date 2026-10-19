@tool
class_name Catwalks
extends Node3D
## Metal catwalks over the mezzanines (MazeStyle "Climbing": catwalks; the user,
## 2026-10-18: "we need to add a metal cat walk option that will add pathways above
## the mezzanines, rarely in zone 2 and then lots in zone 3"): grated steel walkways
## gone to rust, along the walls on brackets and across the halls (the long ones hung
## from a beam under the wall tops), railed, joined into ways over the maze, with
## steel ladders up to them. MazeFeatures lays them out as pieces (MazePiece.Kind.CATWALK,
## one straight run each, and Kind.LADDER); they are made here from a layout's pieces.
##
## Cheap to draw and to bump into. Every bar of steel (rails, posts, stringers,
## brackets, hangers, the ladders' stiles) is one box in one MultiMesh, the decks are
## another (the grating is a shader cutting holes in a plain slab, solid far off) and
## the ladders' rungs a third (stripes cut in a thin slab), a set of the three for each
## square of SQUARE metres. And it is one body for them all: a box shape for each
## run's deck and each stretch of railing, so no more bodies however many there are (a
## solo round once made more than Jolt's limit). The ladders are the boy's own Ladders
## (CatwalkLadder, drawn here, nothing of its own).
##
## Where a run's end meets another's side, or a ladder comes up beside it, its railing
## is left open there (worked out here from the pieces, so a run moved by hand is too).

## What is along a run's sides and at its ends (MazePiece.catwalk), "left" and "right"
## looking from its start (the piece's origin) to its end (its End).
enum Side {
	RAIL_LEFT = 1, ## A railing along its left side.
	RAIL_RIGHT = 2, ## A railing along its right side.
	WALL_LEFT = 4, ## A wall along its left side: it stands on brackets from it.
	WALL_RIGHT = 8, ## A wall along its right.
	SHUT_START = 16, ## A railing across its start (it ends in the air there, no ladder).
	SHUT_END = 32, ## A railing across its end.
	WALL_START = 64, ## A wall at its start: struts from it under the deck.
	WALL_END = 128, ## A wall at its end.
	HUNG = 256, ## Hung from a beam `length` over its deck, on rods at its sides.
}

## How thick the deck's grating is, and the stringers along its sides (wide, deep), metres.
const DECK_THICK := 0.05
const STRINGER := Vector2(0.07, 0.22)
## How high the top rail is over the deck, the middle rail, the toe plate; how thick a bar of railing is.
const RAIL_HIGH := 1.05
const MID_RAIL := 0.55
const TOE := 0.12
const BAR := 0.045
## How far apart a railing's posts are at most, a run's brackets from a wall, and its hangers, metres.
const POST_EVERY := 1.8
const BRACKET_EVERY := 2.4
const HANGER_EVERY := 3.6
## How far out from a run's side a ladder stands (its rungs' middle), metres.
const LADDER_OUT := 0.15
## How wide a ladder is between its stiles, and how far its stiles reach over the top, metres.
const LADDER_WIDE := 0.5
const LADDER_OVER := 1.0
## How wide a gap a ladder needs in the railing it comes up through, metres.
const LADDER_GAP := 0.9
## The squares the drawn steel is gathered in, metres; how far off it is drawn.
const SQUARE := 48.0
const SEEN := 260.0

## What it is made of: iron gone dark, and rust, muted to sit in the grey.
const IRON := Color(0.11, 0.105, 0.1)
const RUST := Color(0.25, 0.15, 0.1)

## Each run as made: [start, end, how wide] (for tests and tools), and each ladder.
var runs: Array = []
var ladders: Array[Ladder] = []
## The one body of them all (null with none, or drawn only).
var body: StaticBody3D

static var _unit: BoxMesh
static var _shader: Shader
static var _materials := {}

## square -> [steel bars, decks, rung slabs] (Transform3Ds of a unit box).
var _squares := {}


## Makes the catwalks of the pieces `walks` (Kind.CATWALK) and `climbs` (Kind.LADDER),
## where they are in the layout's space (as the other features are): drawn, and
## (`solid`) a body and Ladders.
func build(walks: Array[MazePiece], climbs: Array[MazePiece], solid := true) -> void:
	var made: Array = walks.map(func(piece: MazePiece) -> Dictionary: return run_of(piece))
	var ups: Array = climbs.map(func(piece: MazePiece) -> Dictionary: return ladder_of(piece))
	_make(made, ups, solid)


## A catwalk piece as a run: its ends, width, sides and beam (in the layout's space, or `world`).
static func run_of(piece: MazePiece, world := false) -> Dictionary:
	var a := piece.global_position if world else piece.position
	var b := piece.bridge_end()
	if world and piece.get_parent() is Node3D:
		b = (piece.get_parent() as Node3D).to_global(b)
	return {"a": a, "b": b, "wide": piece.width, "flags": piece.catwalk, "beam": piece.length}


## A ladder piece: where it stands (its +Z the side it is climbed from) and how high it goes.
static func ladder_of(piece: MazePiece, world := false) -> Dictionary:
	var at := piece.global_transform if world else piece.transform
	return {"at": Transform3D(at.basis.orthonormalized(), at.origin), "high": piece.length}


## For the maze editor: a piece drawn as it will be, in the world (not solid).
static func shown(piece: MazePiece) -> Node3D:
	var made := Catwalks.new()
	if piece.kind == MazePiece.Kind.CATWALK:
		made._make([run_of(piece, true)], [], false)
	else:
		made._make([], [ladder_of(piece, true)], false)
	return made


func _make(walks: Array, ups: Array, solid: bool) -> void:
	if solid:
		body = StaticBody3D.new()
		body.name = "CatwalkBody"
		body.top_level = true
	for walk: Dictionary in walks:
		_run(walk, walks, ups)
		runs.append([walk.a, walk.b, walk.wide])
	for up: Dictionary in ups:
		_ladder(up, solid)
	# (its shapes all in before it goes into the world, as the walls')
	if body:
		if body.get_child_count() > 0:
			add_child(body)
			body.global_transform = Transform3D.IDENTITY
		else:
			body.free()
			body = null
	for key: Vector2i in _squares:
		var sets: Array = _squares[key]
		for k in 3:
			if not (sets[k] as Array).is_empty():
				_draw(sets[k], [&"steel", &"deck", &"rungs"][k])
	_squares.clear()


# --- A run ---

func _run(walk: Dictionary, walks: Array, ups: Array) -> void:
	var a: Vector3 = walk.a
	var b: Vector3 = walk.b
	var flags: int = walk.flags
	var wide: float = walk.wide
	var span := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var long := span.length()
	if long < 0.2:
		return
	var along := span / long
	var right := along.cross(Vector3.UP)
	var high := a.y
	var key := _square_of((a + b) * 0.5)
	var at := func(t: float, out: float, y: float) -> Vector3: return a + along * t + right * out + Vector3.UP * (y - high)
	# The deck (grated), and the stringers along its sides, flush with its top; bearers under it.
	_box(key, 1, at.call(long * 0.5, 0.0, high - DECK_THICK * 0.5), right, along, Vector3(wide - STRINGER.x * 2.0 + 0.01, DECK_THICK, long))
	for s: float in [-1.0, 1.0]:
		_box(key, 0, at.call(long * 0.5, s * (wide - STRINGER.x) * 0.5, high - STRINGER.y * 0.5), right, along, Vector3(STRINGER.x, STRINGER.y, long))
	var bearers := maxi(ceili(long / 1.2), 1)
	for k in bearers + 1:
		var t := clampf(long * k / bearers, 0.05, long - 0.05)
		_box(key, 0, at.call(t, 0.0, high - DECK_THICK - 0.03), right, along, Vector3(wide - 0.02, 0.06, 0.06))
	if body:
		_shape(at.call(long * 0.5, 0.0, high - 0.06), right, along, Vector3(wide, 0.12, long))
	# The railings along its sides, open where something joins them.
	for s: int in [-1, 1]:
		if not flags & (Side.RAIL_LEFT if s < 0 else Side.RAIL_RIGHT):
			continue
		var out := s * (wide * 0.5 - BAR * 0.5)
		for stretch: Vector2 in _railed(walk, s, walks, ups, long, along, right):
			_railing(key, at.call(stretch.x, out, high), at.call(stretch.y, out, high))
	# Railings across its ends, where it ends in the air.
	for end: int in [0, 1]:
		if not flags & (Side.SHUT_START if end == 0 else Side.SHUT_END):
			continue
		var t := BAR * 0.5 if end == 0 else long - BAR * 0.5
		_railing(key, at.call(t, -wide * 0.5, high), at.call(t, wide * 0.5, high))
	# Brackets from a wall along its side: an arm under the deck and a strut up to its
	# far edge from lower down the wall, every BRACKET_EVERY.
	for s: int in [-1, 1]:
		if not flags & (Side.WALL_LEFT if s < 0 else Side.WALL_RIGHT):
			continue
		var count := maxi(ceili((long - 1.2) / BRACKET_EVERY), 1)
		for k in count + 1:
			var t := lerpf(0.6, long - 0.6, float(k) / count) if long > 1.2 else long * 0.5
			var under := high - STRINGER.y - 0.04
			var wall: Vector3 = at.call(t, s * wide * 0.5, under)
			var edge: Vector3 = at.call(t, -s * (wide * 0.5 - 0.05), under)
			_bar(key, wall, edge, 0.07)
			_bar(key, at.call(t, s * wide * 0.5, under - wide * 0.9), edge, 0.06)
			_box(key, 0, at.call(t, s * (wide * 0.5 - 0.01), under - wide * 0.45), right, along, Vector3(0.02, wide * 0.9 + 0.15, 0.16))
	# Struts from a wall at its ends, under each stringer.
	for end: int in [0, 1]:
		if not flags & (Side.WALL_START if end == 0 else Side.WALL_END):
			continue
		var t0 := 0.0 if end == 0 else long
		var t1 := minf(1.3, long * 0.4) * (1.0 if end == 0 else -1.0)
		for s: float in [-1.0, 1.0]:
			var out := s * (wide - STRINGER.x) * 0.5
			_bar(key, at.call(t0, out, high - 1.5), at.call(t0 + t1, out, high - STRINGER.y), 0.06)
		_box(key, 0, at.call(t0 + (0.03 if end == 0 else -0.03), 0.0, high - STRINGER.y * 0.5), right, along, Vector3(wide, STRINGER.y, 0.06))
	# Hung from a beam overhead: rods up from a bar under it at each side, to a bar under the beam.
	if flags & Side.HUNG and float(walk.beam) > 1.0:
		var top := high + float(walk.beam)
		_box(key, 0, at.call(long * 0.5, 0.0, top + 0.15), right, along, Vector3(0.18, 0.3, long + 0.8))
		var count := maxi(ceili(long / HANGER_EVERY), 2)
		for k in range(1, count):
			var t := long * k / count
			var under := high - STRINGER.y - 0.03
			_box(key, 0, at.call(t, 0.0, under), right, along, Vector3(wide + 0.14, 0.06, 0.07))
			_box(key, 0, at.call(t, 0.0, top - 0.03), right, along, Vector3(wide + 0.14, 0.06, 0.07))
			for s: float in [-1.0, 1.0]:
				_bar(key, at.call(t, s * (wide * 0.5 + 0.05), under), at.call(t, s * (wide * 0.5 + 0.05), top), 0.028)


## The stretches along side `s` (-1 left, 1 right) of `walk` that are railed: all of
## it but where another run's end meets that side or a ladder comes up beside it.
func _railed(walk: Dictionary, s: int, walks: Array, ups: Array, long: float, along: Vector3, right: Vector3) -> Array[Vector2]:
	var a: Vector3 = walk.a
	var edge: float = walk.wide * 0.5
	var open: Array[Vector2] = []
	for other: Dictionary in walks:
		if other == walk:
			continue
		for end: Vector3 in [other.a, other.b]:
			var off := end - a
			if absf(off.y) > 0.3 or absf(off.dot(right) * s - edge) > 0.2:
				continue
			var t := off.dot(along)
			if t > -0.2 and t < long + 0.2:
				open.append(Vector2(t - float(other.wide) * 0.5, t + float(other.wide) * 0.5))
	for up: Dictionary in ups:
		var where: Transform3D = up.at
		var off := where.origin - a
		if absf(off.y + float(up.high)) > 0.3 or where.basis.z.dot(right) * s < 0.9 or absf(off.dot(right) * s - edge - LADDER_OUT) > 0.25:
			continue
		var t := off.dot(along)
		open.append(Vector2(t - LADDER_GAP * 0.5, t + LADDER_GAP * 0.5))
	open.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var stretches: Array[Vector2] = []
	var from := 0.0
	for gap in open:
		if minf(gap.x, long) - from > 0.3:
			stretches.append(Vector2(from, minf(gap.x, long)))
		from = maxf(from, gap.y)
	if long - from > 0.3:
		stretches.append(Vector2(from, long))
	return stretches


## A stretch of railing from `p` to `q` on the deck: posts at its ends and every
## POST_EVERY, a top rail, a middle rail and a toe plate; and its shape, to keep
## anyone from walking off.
func _railing(key: Vector2i, p: Vector3, q: Vector3) -> void:
	var long := p.distance_to(q)
	var along := (q - p) / maxf(long, 0.001)
	var side := along.cross(Vector3.UP)
	var posts := maxi(ceili(long / POST_EVERY), 1)
	for k in posts + 1:
		var at := p.lerp(q, float(k) / posts)
		_box(key, 0, at + Vector3.UP * RAIL_HIGH * 0.5, side, along, Vector3(BAR, RAIL_HIGH, BAR))
	var middle := (p + q) * 0.5
	_box(key, 0, middle + Vector3.UP * RAIL_HIGH, side, along, Vector3(BAR * 1.2, BAR, long))
	_box(key, 0, middle + Vector3.UP * MID_RAIL, side, along, Vector3(BAR * 0.8, BAR * 0.8, long))
	_box(key, 0, middle + Vector3.UP * TOE * 0.5, side, along, Vector3(0.012, TOE, long))
	if body:
		_shape(middle + Vector3.UP * (RAIL_HIGH + 0.05) * 0.5, side, along, Vector3(0.06, RAIL_HIGH + 0.05, long))


# --- Ladders ---

## A steel ladder: its stiles up past the top as handholds, its rungs a slab of stripes;
## and (`solid`) a CatwalkLadder to climb.
func _ladder(up: Dictionary, solid: bool) -> void:
	var where: Transform3D = up.at
	var high: float = up.high
	if high < 0.5:
		return
	var foot := where.origin
	var x := where.basis.x.normalized()
	var z := where.basis.z.normalized()
	var key := _square_of(foot)
	for s: float in [-1.0, 1.0]:
		_box(key, 0, foot + x * s * LADDER_WIDE * 0.5 + Vector3.UP * (high + LADDER_OVER) * 0.5, x, z, Vector3(0.06, high + LADDER_OVER, 0.06))
	# (a stay back to the catwalk at the top)
	for s: float in [-1.0, 1.0]:
		_bar(key, foot + x * s * LADDER_WIDE * 0.5 + Vector3.UP * (high - 0.35), foot + x * s * LADDER_WIDE * 0.5 - z * (LADDER_OUT + 0.05) + Vector3.UP * (high - STRINGER.y), 0.045)
	_box(key, 2, foot + Vector3.UP * high * 0.5, x, z, Vector3(LADDER_WIDE - 0.04, high, 0.035))
	if solid:
		var climb := CatwalkLadder.new()
		climb.height = high
		climb.transform = where
		add_child(climb)
		ladders.append(climb)


## A ladder up to a catwalk: the boy's Ladder, drawn by Catwalks.
class CatwalkLadder extends Ladder:
	func _ready() -> void:
		add_to_group(&"ladders")


# --- Drawing ---

func _square_of(at: Vector3) -> Vector2i:
	var key := Vector2i(floori(at.x / SQUARE), floori(at.z / SQUARE))
	if not _squares.has(key):
		_squares[key] = [[], [], []]
	return key


## A box `size` (across, high, along) round `middle`, `across` and `along` its ways, in set `k` of square `key`.
func _box(key: Vector2i, k: int, middle: Vector3, across: Vector3, along: Vector3, size: Vector3) -> void:
	var x := across.normalized()
	var z := along.normalized()
	var y := z.cross(x)
	(_squares[key][k] as Array).append(Transform3D(Basis(x * size.x, y * size.y, z * size.z), middle))


## A bar of steel from `p` to `q`, `thick` square.
func _bar(key: Vector2i, p: Vector3, q: Vector3, thick: float) -> void:
	var z := q - p
	var long := z.length()
	if long < 0.01:
		return
	z /= long
	var x := Vector3.UP.cross(z) if absf(z.y) < 0.95 else Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x)
	(_squares[key][0] as Array).append(Transform3D(Basis(x * thick, y * thick, z * long), (p + q) * 0.5))


func _shape(middle: Vector3, across: Vector3, _along: Vector3, size: Vector3) -> void:
	var box := BoxShape3D.new()
	box.size = size
	var shape := CollisionShape3D.new()
	shape.shape = box
	# (turned as a right-handed basis, its z along `along` one way or the other: the box is the same)
	var x := across.normalized()
	shape.transform = Transform3D(Basis(x, Vector3.UP, x.cross(Vector3.UP)), middle)
	body.add_child(shape)


func _draw(boxes: Array, look: StringName) -> void:
	if _unit == null:
		_unit = BoxMesh.new()
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.mesh = _unit
	many.instance_count = boxes.size()
	for k in boxes.size():
		many.set_instance_transform(k, boxes[k])
	var shown := MultiMeshInstance3D.new()
	shown.multimesh = many
	shown.material_override = material(look)
	shown.top_level = true
	shown.visibility_range_end = SEEN
	add_child(shown)
	shown.global_transform = Transform3D.IDENTITY


const SHADER := """
shader_type spatial;
// 0: plain steel; 1: a deck of grating (holes through its top and bottom); 2: a ladder's rungs.
uniform int look = 0;
uniform vec3 iron : source_color;
uniform vec3 rust : source_color;
// The grating's pitch across and along a deck, and how thick its bars are, metres.
uniform vec2 pitch = vec2(0.05, 0.11);
uniform vec2 bars = vec2(0.012, 0.016);
uniform float rung_gap = 0.3;
uniform float rung_thick = 0.04;

varying vec3 world;
varying vec3 spot;
varying vec3 facing;
varying vec3 sized;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	sized = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	spot = VERTEX * sized;
	facing = NORMAL;
}

void fragment() {
	if (look == 1 && abs(facing.y) > 0.5) {
		// (holes in a grid in the deck's own frame; solid where they are too small to see)
		vec2 at = spot.xz;
		vec2 pixel = fwidth(at);
		vec2 off = abs(fract(at / pitch) - 0.5) * pitch;
		vec2 open = (pitch - bars) * 0.5;
		if (pixel.x < pitch.x * 0.45 && pixel.y < pitch.y * 0.45 && off.x < open.x && off.y < open.y) {
			discard;
		}
	}
	if (look == 2) {
		float y = spot.y + sized.y * 0.5;
		float off = abs(fract(y / rung_gap + 0.5) - 0.5) * rung_gap;
		if (off > rung_thick * 0.5 || y < rung_gap * 0.5) {
			discard;
		}
	}
	// Rust in patches, run down in streaks from where water sits.
	float patch = noise(world.xz * 0.9 + world.y * 0.6) * 0.6 + noise(world.xz * 4.0 - world.y * 2.0) * 0.4;
	float streak = noise(vec2((world.x + world.z) * 6.0, world.y * 0.4));
	float rusty = clamp(smoothstep(0.35, 0.85, patch) + streak * 0.25, 0.0, 1.0);
	ALBEDO = mix(iron, rust, rusty) * mix(0.85, 1.05, noise(world.xz * 13.0 + world.y * 7.0));
	ROUGHNESS = mix(0.7, 0.95, rusty);
	METALLIC = mix(0.3, 0.05, rusty);
	SPECULAR = 0.3;
}
"""


## The material of a look: "steel", "deck" (grated) or "rungs".
static func material(look: StringName) -> ShaderMaterial:
	if not _materials.has(look):
		if _shader == null:
			_shader = Shader.new()
			_shader.code = SHADER
		var made := ShaderMaterial.new()
		made.shader = _shader
		made.set_shader_parameter(&"look", {&"steel": 0, &"deck": 1, &"rungs": 2}[look])
		made.set_shader_parameter(&"iron", IRON)
		made.set_shader_parameter(&"rust", RUST)
		made.set_shader_parameter(&"rung_gap", Ladder.RUNG)
		_materials[look] = made
	return _materials[look]

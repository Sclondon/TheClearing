class_name Rope
extends Node3D
## A rope hanging from where this node is placed, and it is a real one: a chain
## of points held a fixed distance apart, that swings, and hangs straight only
## when it is left alone. The player catches it by jumping into it, swings it
## with the stick, climbs it, and leaps off with jump, taking its swing with him.
##
## Whoever is on it says where (`load_at`, a distance down from the top). He is
## far heavier than the rope, so while he is on it the rope goes where he does:
## he is a weight on the end of a line `load_at` long, a pendulum, the rope
## above him drawn straight by it and the rest trailing after. A shorter line
## swings quicker, and climbing while it swings speeds him up as it should.

## How many pieces it is made of.
const PIECES := 16

@export var length := 5.0
## How quickly a swing dies away, per second.
@export var drag := 0.22
## How quickly the rope's own swinging dies away when nobody is on it.
@export var slack_drag := 1.1
## How hard it is pulled down, m/s². (Less than he falls at: a swing wants time.)
@export var gravity := 24.0
## How thick it is drawn.
@export var thickness := 0.025

## How far down from the top someone is hanging, or negative for nobody.
var load_at := -1.0: set = _set_load

var _points := PackedVector3Array()
var _before := PackedVector3Array()
var _links: Array[MeshInstance3D] = []
var _knot: MeshInstance3D
## Where whoever is on it has hold of it, and where that was a moment ago.
var _rider := Vector3.ZERO
var _rider_before := Vector3.ZERO
## How much of the rope below his hands he has hold of too (between his knees
## and feet): that much goes with him, in line with the rope above, and only
## what is below it trails.
var held_below := 0.0
## A change of length that leaves his speed alone (see `take_in`).
var _taken_in := false


func _ready() -> void:
	add_to_group(&"ropes")
	var hemp := StandardMaterial3D.new()
	hemp.albedo_color = Color(0.45, 0.38, 0.26)
	hemp.roughness = 1.0
	hemp.metallic_specular = 0.0
	var piece := length / PIECES
	if _points.is_empty():
		for i in PIECES + 1:
			_points.append(global_position + Vector3.DOWN * piece * i)
		_before = _points.duplicate()
	for i in PIECES:
		var link := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = thickness
		mesh.bottom_radius = thickness
		mesh.height = piece * 1.04
		mesh.radial_segments = 6
		mesh.rings = 1
		link.mesh = mesh
		link.material_override = hemp
		link.top_level = true
		add_child(link)
		_links.append(link)
	# A knot at the end, so the bottom reads
	_knot = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = thickness * 2.0
	ball.height = thickness * 4.0
	ball.radial_segments = 8
	ball.rings = 4
	_knot.mesh = ball
	_knot.material_override = hemp
	_knot.top_level = true
	add_child(_knot)
	_draw()


## Lays the rope out along a line from its top (where this node is) to `end`,
## at rest, instead of hanging straight down: for one that has just been thrown.
## Call it once it is in the tree.
func lay_to(end: Vector3) -> void:
	_points.clear()
	for i in PIECES + 1:
		_points.append(global_position.lerp(end, float(i) / PIECES))
	_before = _points.duplicate()
	if not _links.is_empty():
		_draw()


func _set_load(value: float) -> void:
	var was := load_at
	load_at = value
	if value < 0.0 or _points.is_empty():
		return
	if was < 0.0:
		# Someone has taken hold: the rope there is his to move now.
		_rider = point_at(value)
		_rider_before = _rider - _whole_velocity(value) / Engine.physics_ticks_per_second
	elif not is_equal_approx(was, value) and not _taken_in:
		# Climbing: what he had of swing he keeps, about the top of the rope, so
		# on a shorter line he goes round the faster (and on a longer, slower).
		var out := _rider - global_position
		if out.length() > 0.05:
			var along := out.normalized()
			var moved := _rider - _rider_before
			var across := moved - along * moved.dot(along)
			_rider_before = _rider - along * moved.dot(along) - across * clampf(was / maxf(value, 0.05), 0.8, 1.25)
	_taken_in = false


## Shortens (or lengthens) the line to whoever is on it without the quickening
## that climbing gives: for hauling him in on it.
func take_in(distance: float) -> void:
	_taken_in = true
	load_at = distance


func _physics_process(delta: float) -> void:
	var piece := length / PIECES
	var fall := Vector3.DOWN * gravity * delta * delta
	var top := global_position
	var loaded := load_at >= 0.0
	var keep := exp(-(drag if loaded else slack_drag) * delta)
	for i in range(1, PIECES + 1):
		var at := _points[i]
		_points[i] = at + (at - _before[i]) * keep + fall
		_before[i] = at
	# Which piece he is on, and how far along it.
	var on := 0
	var part := 0.0
	var taut := false
	# The last point of it that he holds, which what trails below hangs from.
	var grip := -1
	if loaded:
		var was := _rider
		_rider = was + (was - _rider_before) * keep + fall
		_rider_before = was
		var out := _rider - top
		# (the line stops him going further from the top than it is long, and nothing else)
		taut = out.length() >= load_at
		if taut:
			_rider = top + out.normalized() * load_at
		on = clampi(int(load_at / piece), 0, PIECES - 1)
		part = load_at / piece - on
		if taut:
			# Above him it is pulled straight, and so is what he holds below.
			var line := (_rider - top).normalized()
			for i in range(1, PIECES + 1):
				if i <= on:
					_points[i] = top + line * i * piece
				elif i * piece - load_at <= held_below:
					_points[i] = _rider + line * (i * piece - load_at)
					grip = i
	# Each piece is pulled back to its length. Where he has hold of it, it goes
	# with him: he does not give.
	for pass_ in 12:
		_points[0] = top
		for i in PIECES:
			if loaded and i == on and grip < 0:
				_points[i] = _held(_points[i], part * piece, i == 0)
				_points[i + 1] = _held(_points[i + 1], (1.0 - part) * piece, false)
				continue
			if loaded and taut and (i < on or i < grip):
				continue
			var a := _points[i]
			var b := _points[i + 1]
			var apart := b - a
			var stretch := apart.length() - piece
			if absf(stretch) < 0.00001:
				continue
			var along := apart.normalized()
			# (the top is fixed, and so is the end of a piece he holds)
			var light_a := 0.0 if i == 0 or (loaded and (i == grip or (grip < 0 and i == on + 1))) else 1.0
			var light_b := 0.0 if loaded and i + 1 == on else 1.0
			if light_a + light_b <= 0.0:
				continue
			_points[i] = a + along * stretch * light_a / (light_a + light_b)
			_points[i + 1] = b - along * stretch * light_b / (light_a + light_b)
	_draw()


## A point of the rope `away` along it from where he holds it, kept that far from him.
func _held(point: Vector3, away: float, fixed: bool) -> Vector3:
	if fixed:
		return global_position
	var apart := point - _rider
	if apart.length() < 0.0001:
		return _rider + Vector3.DOWN * away
	return _rider + apart.normalized() * away


func _draw() -> void:
	for i in PIECES:
		var a := _points[i]
		var b := _points[i + 1]
		var along := (b - a).normalized() if a.distance_squared_to(b) > 0.0000001 else Vector3.DOWN
		var across := along.cross(Vector3.RIGHT)
		across = across.normalized() if across.length_squared() > 0.001 else Vector3.BACK
		_links[i].global_transform = Transform3D(Basis(across.cross(along), -along, across), (a + b) * 0.5)
	_knot.global_position = _points[PIECES]


func top_y() -> float:
	return global_position.y


func bottom_y() -> float:
	return _points[PIECES].y if not _points.is_empty() else global_position.y - length


## Where the rope is, `distance` down it from the top.
func point_at(distance: float) -> Vector3:
	var along := clampf(distance / length, 0.0, 1.0) * PIECES
	var i := mini(int(along), PIECES - 1)
	return _points[i].lerp(_points[i + 1], along - i)


## How fast that part of it is moving.
func velocity_at(distance: float) -> Vector3:
	if load_at >= 0.0 and absf(distance - load_at) < length / PIECES:
		return (_rider - _rider_before) * Engine.physics_ticks_per_second
	return _whole_velocity(distance)


func _whole_velocity(distance: float) -> Vector3:
	var i := clampi(int(round(distance / length * PIECES)), 1, PIECES)
	return (_points[i] - _before[i]) * Engine.physics_ticks_per_second


## How far down the rope the part of it nearest `point` is.
func nearest(point: Vector3) -> float:
	var best := 0.0
	var least := INF
	for i in PIECES:
		var a := _points[i]
		var b := _points[i + 1]
		var along := b - a
		var part := clampf((point - a).dot(along) / maxf(along.length_squared(), 0.000001), 0.0, 1.0)
		var apart := (a + along * part).distance_squared_to(point)
		if apart < least:
			least = apart
			best = (i + part) * length / PIECES
	return best


## How far `point` is from the rope.
func distance_to(point: Vector3) -> float:
	return point_at(nearest(point)).distance_to(point)


## How far round from hanging straight down the rope is where `distance` down
## it is, in radians.
func angle_at(distance: float) -> float:
	var out := point_at(distance) - global_position
	return out.angle_to(Vector3.DOWN) if out.length_squared() > 0.0001 else 0.0


## Shoves the rope at `distance` down it, and less so the rope either side: a
## change of speed, m/s. Whoever is on it there is shoved with it.
func push(distance: float, shove: Vector3) -> void:
	var middle := distance / length * PIECES
	for i in range(1, PIECES + 1):
		var share := clampf(1.0 - absf(i - middle) / 3.0, 0.0, 1.0)
		_before[i] -= shove * share / Engine.physics_ticks_per_second
	if load_at >= 0.0:
		var share := clampf(1.0 - absf(load_at - distance) / length * PIECES / 3.0, 0.0, 1.0)
		_rider_before -= shove * share / Engine.physics_ticks_per_second

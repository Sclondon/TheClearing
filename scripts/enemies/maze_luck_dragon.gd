class_name MazeLuckDragon
extends MazeEnemy
## The luck dragon (creatures/luck_dragon/: a long, slender, pearly-scaled and
## white-furred dragon with a gentle hound's head, that swims through the air)
## in the sky over the maze. It hunts nobody: it is something wonderful to see.
## This is only its thinking; how it looks, moves and sounds is `LuckDragon`.
##
## - IT SOARS high over the outer rings and the desert (never over the
##   clearing), round and round the maze in long, weaving loops, rising and
##   falling, far above the walls. One in the whole maze.
## - IT COMES DOWN to someone who stands still out in the open (a wall top, the
##   clearing's meadow, the desert: nothing higher than them for `OPEN_RADIUS`
##   round them and open sky over them) for `still_time` seconds while it is
##   within `NOTICE_RANGE`: it turns, spirals down over them and circles them
##   low, then brings its head down in front of them at their height, its neck
##   laid low on the ground before them and its body coiled round about, and
##   looks at them, and sings (LuckDragon.sing). If they walk off, it lets them go.
## - IT LETS THEM RIDE: walk up to its neck (within `MOUNT_REACH` of where one
##   would sit) and they climb on and sit; it rises, carries them over the walls
##   and sets them down somewhere further out (a straight hall it can glide
##   down into, `RIDE_FARTHEST` at most; never back towards the clearing), and
##   goes back up to the sky. If there is nowhere it can set them down, it only
##   looks at them, and goes.
## - Then it does not come down again for `VISIT_REST` seconds.
## - IT CALMS what hunts: while it is down, anything hunting within
##   `CALM_RANGE` of it backs away from it (MazeEnemy.threat) and lets alone
##   whoever is near it.
##
## Online, the host thinks; a puppet follows its news (where its head is, what
## it is doing, the place it is visiting or going to), singing when the host's
## does; whoever rides it is carried on their own machine (the news says whose
## seat), and the rest see them through their own news.
##
## Spawn (as MazeEnemies does any MazeEnemy): `MazeLuckDragon.new()`, `maze`
## set, put anywhere (it rises to the sky and finds its way round).

## What it is doing, as sent (`net_state`).
enum Mode { SOAR, DESCEND, CIRCLE, GREET, MOUNT, RIDE, ALIGHT, LEAVE }

## Its speed soaring, coming down and circling, and carrying someone (metres a second).
const SOAR_SPEED := 13.0
const CIRCLE_SPEED := 8.0
const RIDE_SPEED := 10.0
## How high over the ground it soars, metres.
const SOAR_HEIGHT := 78.0
## How high over the walls under it, at the least.
const SOAR_OVER := 30.0
## How far off (across the ground) it notices someone standing still.
const NOTICE_RANGE := 170.0
## How much room someone needs round them to be visited: nothing higher than
## their feet (and a little) this far round them.
const OPEN_RADIUS := 16.0
const OPEN_RISE := 2.0
## The circle it makes round them: how wide and how high over their feet.
const CIRCLE_RADIUS := 11.5
const CIRCLE_HEIGHT := 4.5
## How many times round before it brings its head down.
const CIRCLE_LAPS := 1.2
## Its head in front of them as it looks at them: how far, how high over their feet.
const GREET_NEAR := 3.6
const GREET_HEIGHT := 1.5
## How long it stays looking at them.
const GREET_TIME := 11.0
## How far behind its head one sits on it; how near that they must come to climb on.
const SADDLE := 3.6
const SADDLE_UP := 1.0
const MOUNT_REACH := 2.4
## How far it carries someone, at most and least, metres across the ground.
const RIDE_FARTHEST := 200.0
const RIDE_NEAREST := 45.0
## How far it calms what hunts, and how long it lets alone whoever is near it.
const CALM_RANGE := 40.0
const CALM_SPARE := 2.5
## Seconds between visits.
const VISIT_REST := 90.0

## How long someone must stand still to be visited.
@export var still_time := 4.0
## Further than this from every player it is not posed or drawn.
@export var pose_range := 260.0

var mode := Mode.SOAR
## The creature.
var look: LuckDragon
## Whom it is visiting, and where they stood when it came.
var guest: Node3D
var visit_at := Vector3.INF
## Who rides it (null: nobody), and the seat of whoever does (-1: nobody), as the news says.
var rider: Node3D
var rider_seat := -1
## Where it will set its rider down (on the ground), and the way it comes in.
var drop_at := Vector3.INF
var drop_way := Vector3.ZERO
## How many it has carried (for tests).
var carried := 0
var visits := 0

var _mode_time := 0.0
var _heading := Vector3.FORWARD
var _loop := 1.0
var _visit_rest := 20.0
var _still := {}
var _watch := 0.0
var _calm_in := 0.0
var _circle_angle := 0.0
var _circled := 0.0
var _spiral := false
var _floor := 0.0
var _floor_in := 0.0
var _walls_top := -1.0
var _approach_y := 0.0
var _path := PackedVector3Array()
var _path_at := 0.0
var _songs := 0
var _heard_songs := -1
var _far := false
var _far_check := 0.0
var _carrying: Player
var _carry_from := Transform3D.IDENTITY
var _carry_t := 0.0
var _sat := false
var _seated := false
var _settled_at := 0.0


func _init() -> void:
	sight_range = NOTICE_RANGE
	hear_range = 0.0
	memory = 0.0
	alert_range = 0.0
	pack = &"luck_dragons"
	look_every = 0.5


func _ready() -> void:
	# It flies: nothing bumps into it, and it bumps into nothing.
	collision_layer = 0
	collision_mask = 0
	look = LuckDragon.new()
	look.name = "Look"
	look.seed_value = _rng.seed
	add_child(look)
	_heading = Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	_loop = 1.0 if _rng.randf() < 0.5 else -1.0
	if not puppet:
		# (it starts high, over where it was put)
		global_position.y = maxf(global_position.y, maxf(_ground(global_position) + SOAR_HEIGHT, maxf(_sky_round(global_position, 30.0), walls_top()) + SOAR_OVER))
		# (on its way round the maze)
		var round_way := Vector3(-global_position.z, 0.0, global_position.x) * _loop
		if round_way.length() > 1.0:
			_heading = round_way.normalized()
			look.rotation.y = atan2(_heading.x, _heading.z) - rotation.y
	look.settle()


# --- Thinking ---

func _physics_process(delta: float) -> void:
	_cull(delta)
	if puppet:
		_follow_news(delta)
		_drive_look(delta)
		_carry(delta)
		return
	if maze == null:
		return
	_mode_time += delta
	_visit_rest -= delta
	var before := global_position
	match mode:
		Mode.SOAR:
			_soar(delta)
		Mode.DESCEND:
			_descend(delta)
		Mode.CIRCLE:
			_circle(delta)
		Mode.GREET:
			_greet(delta)
		Mode.MOUNT:
			_mount(delta)
		Mode.RIDE:
			_ride(delta)
		Mode.ALIGHT:
			_alight(delta)
		Mode.LEAVE:
			_leave(delta)
	velocity = (global_position - before) / delta
	_calm(delta)
	_drive_look(delta)
	_carry(delta)


func _enter(next: Mode) -> void:
	mode = next
	_mode_time = 0.0


## Turns its heading towards `target` (at most `turn` radians a second) and flies on along it at `speed`.
func _steer(target: Vector3, speed: float, turn: float, delta: float) -> void:
	var want := target - global_position
	if want.length() < 0.01:
		return
	want = want.normalized()
	var angle := _heading.angle_to(want)
	if angle > 0.0001:
		var axis := _heading.cross(want)
		if axis.length_squared() < 0.000001:
			axis = Vector3.UP
		_heading = _heading.rotated(axis.normalized(), minf(angle, turn * delta)).normalized()
	global_position += _heading * speed * delta


## Flies on along `_path` (a line of points) at `speed`; true once at its end.
func _follow_path(speed: float, delta: float) -> bool:
	if _path.size() < 2:
		return true
	_path_at += speed * delta
	var left := _path_at
	for i in _path.size() - 1:
		var piece := _path[i].distance_to(_path[i + 1])
		if left <= piece:
			var at := _path[i].lerp(_path[i + 1], left / maxf(piece, 0.0001))
			var moved := at - global_position
			if moved.length() > 0.0001:
				_heading = moved.normalized()
			global_position = at
			return false
		left -= piece
	global_position = _path[_path.size() - 1]
	return true


func _set_path(points: Array) -> void:
	# (straight from point to point with every corner rounded off: a curve that
	# keeps between the straight lines, so that where they are clear it is too)
	_path = PackedVector3Array()
	var pts: Array = [global_position] + points
	_path.append(pts[0])
	for i in range(1, pts.size() - 1):
		var a: Vector3 = pts[i - 1]
		var corner: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var r := minf(10.0, minf(a.distance_to(corner), corner.distance_to(b)) * 0.45)
		var enter := corner + (a - corner).normalized() * r
		var leave := corner + (b - corner).normalized() * r
		_path.append(enter)
		var steps := maxi(2, int(r / 1.0))
		for k in range(1, steps):
			var t := float(k) / steps
			_path.append(enter.lerp(corner, t).lerp(corner.lerp(leave, t), t))
		_path.append(leave)
	_path.append(pts[pts.size() - 1])
	_path_at = 0.0


# --- Soaring ---

## The band of sky it keeps to, as how far out from the middle (the further of
## across and along, so it keeps clear of the square clearing): [nearest, furthest].
func _band() -> Vector2:
	var inner := Maze.ring_extent(0, maze.styles, maze.clearing_style) * 0.5 + 60.0
	if maze.styles.size() >= 2 and maze.rings >= 2:
		inner = Maze.ring_extent(1, maze.styles, maze.clearing_style) * 0.5 + 20.0
	var outer := maze.extent() * 0.5 + 60.0
	if maze.round_rings:
		outer = lerpf(maze.extent() * 0.5, maze.round_rings.inner_radius, 0.75)
	return Vector2(inner + 20.0, maxf(outer, inner + 60.0))


func _soar(delta: float) -> void:
	var band := _band()
	var flat := Vector2(global_position.x, global_position.z)
	var angle := atan2(flat.y, flat.x)
	# A point a little further round the maze, weaving in and out across the band.
	var ahead := angle + _loop * 0.16
	var middle := (band.x + band.y) * 0.5
	var wobble := sin(ahead * 3.0 + _rng.seed % 7) * 0.35 + sin(ahead * 7.0 + 1.3) * 0.15
	var out := middle + (band.y - band.x) * 0.5 * wobble
	var way := Vector2(cos(ahead), sin(ahead))
	# (out as far across or along as `out`: round the square, not a circle)
	var square := out / maxf(maxf(absf(way.x), absf(way.y)), 0.5)
	var target := Vector3(way.x * square, 0.0, way.y * square)
	# (well over the ground, and over the walls under it and round about)
	_floor_in -= delta
	if _floor_in <= 0.0:
		_floor_in = 0.5
		_floor = _sky_round(global_position + _heading * 25.0, 30.0)
	target.y = maxf(_ground(target) + SOAR_HEIGHT, maxf(_floor, walls_top()) + SOAR_OVER) + 12.0 * sin(ahead * 5.0 + 0.7)
	_steer(target, SOAR_SPEED, 0.22, delta)
	_look_for_guests(delta)


## Every so often: is anyone near standing still out in the open?
func _look_for_guests(delta: float) -> void:
	_watch -= delta
	if _watch > 0.0:
		return
	_watch = look_every
	for player: Node3D in players():
		if not _visitable(player):
			_still.erase(player)
			continue
		var at := player.global_position
		var was: Array = _still.get(player, [at, 0.0])
		if (was[0] as Vector3).distance_to(at) < 0.5:
			was[1] = float(was[1]) + look_every
		else:
			was = [at, 0.0]
		_still[player] = was
		if _visit_rest > 0.0 or float(was[1]) < still_time:
			continue
		if Vector2(at.x - global_position.x, at.z - global_position.z).length() > NOTICE_RANGE:
			continue
		if not open_at(at):
			continue
		_visit(player)
		return


## Whom it might visit: a player (not a runner) in the maze, not caught or out.
func _visitable(player: Node3D) -> bool:
	if not is_instance_valid(player) or not player.is_inside_tree() or player.is_in_group(&"runners"):
		return false
	if player is MazeEnemy or player.get(&"escaped") == true or player.get(&"is_limp") == true:
		return false
	if _spared.has(player) and _spared[player] > 0.0:
		return false
	return not maze.escaped(player.global_position)


## Whether someone standing at `feet` is out in the open: nothing higher than
## them (but a little) for OPEN_RADIUS round them, and open sky over them.
func open_at(feet: Vector3) -> bool:
	var head := feet + Vector3.UP * 1.8
	if not _clear_line(head, head + Vector3.UP * 80.0):
		return false
	for ring: float in [OPEN_RADIUS * 0.45, OPEN_RADIUS]:
		for k in 8:
			var a := TAU * k / 8.0 + ring * 0.1
			var at := feet + Vector3(cos(a), 0.0, sin(a)) * ring
			var top := _ray_down(at + Vector3.UP * 60.0, feet.y - 30.0)
			if top > feet.y + OPEN_RISE:
				return false
	return true


func _visit(player: Node3D) -> void:
	guest = player
	visit_at = player.global_position
	visits += 1
	var off := global_position - visit_at
	_circle_angle = atan2(off.z, off.x)
	_spiral = false
	# (high enough on its way in to clear everything between)
	_approach_y = visit_at.y + CIRCLE_HEIGHT + 25.0
	var steps := int(global_position.distance_to(visit_at) / 2.5) + 1
	for k in steps:
		var at := global_position.lerp(visit_at, float(k) / steps)
		if Vector2(at.x - visit_at.x, at.z - visit_at.z).length() > OPEN_RADIUS:
			_approach_y = maxf(_approach_y, _sky_over(at) + 15.0)
	_circled = 0.0
	_enter(Mode.DESCEND)


## Whether its guest is still where it came to them, out in the open.
func _guest_here() -> bool:
	if guest == null or not _visitable(guest):
		return false
	return Vector2(guest.global_position.x - visit_at.x, guest.global_position.z - visit_at.z).length() < 9.0


## Over them, then down round them in a spiral.
func _descend(delta: float) -> void:
	if not _guest_here():
		_go()
		return
	var flat := Vector2(global_position.x - visit_at.x, global_position.z - visit_at.z)
	var low := visit_at.y + CIRCLE_HEIGHT
	if flat.length() > CIRCLE_RADIUS + 10.0 and not _spiral:
		# (in over them, high, then down)
		var over := visit_at + Vector3(flat.normalized().x, 0.0, flat.normalized().y) * CIRCLE_RADIUS
		over.y = maxf(_approach_y, _sky_over(global_position + _heading * 15.0) + 12.0)
		_steer(over, SOAR_SPEED, 0.5, delta)
		_circle_angle = atan2(global_position.z - visit_at.z, global_position.x - visit_at.x)
		return
	_circle_angle += _loop * CIRCLE_SPEED / CIRCLE_RADIUS * delta
	_spiral = true
	var height := move_toward(global_position.y, low, 5.5 * delta)
	var want := visit_at + Vector3(cos(_circle_angle + _loop * 0.3), 0.0, sin(_circle_angle + _loop * 0.3)) * CIRCLE_RADIUS
	want.y = height
	_steer(want, CIRCLE_SPEED * 1.3, 1.4, delta)
	global_position.y = height
	if absf(global_position.y - low) < 0.2:
		_circled = 0.0
		_enter(Mode.CIRCLE)


## Round them, low.
func _circle(delta: float) -> void:
	if not _guest_here():
		_go()
		return
	_circle_angle += _loop * CIRCLE_SPEED / CIRCLE_RADIUS * delta
	_circled += CIRCLE_SPEED / CIRCLE_RADIUS * delta / TAU
	var want := visit_at + Vector3(cos(_circle_angle + _loop * 0.3), 0.0, sin(_circle_angle + _loop * 0.3)) * CIRCLE_RADIUS
	want.y = visit_at.y + CIRCLE_HEIGHT
	_steer(want, CIRCLE_SPEED, 1.4, delta)
	if _circled >= CIRCLE_LAPS:
		# Its head down to them: in low over the ground, and up to their height in front of them.
		var from := Vector3(global_position.x - visit_at.x, 0.0, global_position.z - visit_at.z).normalized()
		var side := Vector3.UP.cross(from) * _loop
		var low := visit_at + (from * 0.6 + side * 0.8).normalized() * 9.0 + Vector3.UP * 1.3
		var near := visit_at + from * GREET_NEAR + Vector3.UP * GREET_HEIGHT
		_set_path([low, near])
		_find_drop()
		_enter(Mode.GREET)


## Its head before them, looking at them; sings once; lets them climb on.
func _greet(delta: float) -> void:
	if _path_at >= 0.0:
		if _follow_path(CIRCLE_SPEED * 0.7, delta):
			_path_at = -1.0
			_songs += 1
			look.sing()
			_mode_time = 0.0
		return
	# (a gentle bob as it hangs there)
	global_position.y += sin(_mode_time * 1.3) * 0.08 * delta
	if not _guest_here() or _mode_time > GREET_TIME:
		_go()
		return
	if drop_at.is_finite():
		var seat := look.back_point(SADDLE, SADDLE_UP).origin
		for player: Node3D in players():
			if not _visitable(player):
				continue
			var off := player.global_position - seat
			if Vector2(off.x, off.z).length() < MOUNT_REACH and absf(off.y + SADDLE_UP) < 2.5:
				_take_rider(player)
				return


func _take_rider(player: Node3D) -> void:
	rider = player
	rider_seat = _seat_of(player)
	carried += 1
	_enter(Mode.MOUNT)


## The rider climbs on.
func _mount(_delta: float) -> void:
	if not is_instance_valid(rider):
		_drop_rider()
		_go()
		return
	if _mode_time > 1.8:
		_plan_ride()
		_enter(Mode.RIDE)


## Up from where it is, over the walls to over the far end of the hall it
## will glide down, and down it (all worked out by `_find_drop`).
func _plan_ride() -> void:
	var forward := Vector3(_heading.x, 0.0, _heading.z)
	forward = forward.normalized() if forward.length() > 0.1 else Vector3.FORWARD
	var start := global_position
	var high := maxf(_ride_height(start, drop_at), walls_top() + 15.0)
	var climb := start + forward * 14.0 + Vector3.UP * 8.0
	var up := start + forward * 30.0
	up.y = high
	var above := drop_at - drop_way * 30.0
	above.y = drop_at.y + _glide_height(drop_at)
	# (out ahead and up if that way is clear, else straight up)
	var across_way := Vector3.UP.cross(forward)
	for off: Vector3 in [Vector3.ZERO, across_way * 1.5, -across_way * 1.5]:
		if not _clear_line(start + off, climb + off) or not _clear_line(climb + off, up + off):
			climb = start + Vector3.UP * 10.0
			up = Vector3(start.x, high, start.z)
			break
	var points: Array = [climb, up]
	# (a wide turn rather than a hairpin, if it must go back the way it came)
	var onward := Vector3(above.x - up.x, 0.0, above.z - up.z)
	if onward.length() > 1.0 and onward.normalized().dot(forward) < -0.2:
		var across := Vector3.UP.cross(forward)
		across *= signf(across.dot(onward)) if absf(across.dot(onward)) > 0.01 else 1.0
		points.append(up + forward * 22.0 + across * 22.0)
	if Vector2(above.x - up.x, above.z - up.z).length() > 40.0:
		var mid := up.lerp(above, 0.5)
		mid.y = high
		points.append(mid)
	var top := above
	top.y = maxf(high, above.y)
	points.append(top)
	points.append(above)
	points.append(drop_at - drop_way * 7.0 + Vector3.UP * 1.3)
	points.append(drop_at + drop_way * SADDLE + Vector3.UP * 1.3)
	_set_path(points)


## How high it carries someone between two places: over everything on the way.
func _ride_height(from: Vector3, to: Vector3) -> float:
	var top := maxf(from.y, to.y)
	var steps := int(from.distance_to(to) / 8.0) + 1
	for k in steps + 1:
		top = maxf(top, _sky_over(from.lerp(to, float(k) / steps)))
	return top + 14.0


## How high over the ground at the hall's end it starts its glide down.
func _glide_height(at: Vector3) -> float:
	return maxf(30.0, _sky_round(at, 20.0) - at.y + 10.0)


func _ride(delta: float) -> void:
	if not is_instance_valid(rider):
		_drop_rider()
		_go()
		return
	if _follow_path(RIDE_SPEED, delta):
		_enter(Mode.ALIGHT)


## Down: its rider gets off onto the ground.
func _alight(_delta: float) -> void:
	if _mode_time > 1.2:
		_drop_rider()
		_go()


## Lets its rider down (they are put on the ground where it meant to set them, on their own machine).
func _drop_rider() -> void:
	rider = null
	rider_seat = -1


## Back up to the sky; and it will not come down again for a while.
func _go() -> void:
	_drop_rider()
	guest = null
	visit_at = Vector3.INF
	_visit_rest = VISIT_REST
	_still.clear()
	# (straight up out of wherever it is, over the walls, before it goes on)
	var up := global_position + Vector3.UP * maxf(30.0, walls_top() + 15.0 - global_position.y)
	var on := _heading.slide(Vector3.UP)
	on = on.normalized() if on.length() > 0.1 else Vector3.FORWARD
	_set_path([up, up + Vector3.UP * 20.0 + on * 30.0])
	_enter(Mode.LEAVE)


## The top of the highest wall round the clearing (not the clearing's own): it soars over them all.
func walls_top() -> float:
	if _walls_top < 0.0:
		_walls_top = MazeBuilder.WALL_HEIGHT
		for style in maze.styles:
			if style:
				for key: StringName in [&"maze_wall_height", &"section_border_wall_height"]:
					var value: Variant = style.get(key)
					if value is float:
						_walls_top = maxf(_walls_top, value)
		if maze.desert_style:
			for key: StringName in [&"diagonal_wall_height", &"far_wall_height"]:
				var value: Variant = maze.desert_style.get(key)
				if value is float:
					_walls_top = maxf(_walls_top, value)
	return _walls_top


func _leave(delta: float) -> void:
	if _follow_path(SOAR_SPEED * 0.8, delta):
		_enter(Mode.SOAR)


# --- Where to set them down ---

## Somewhere further out to set its guest down: the far end of a straight hall
## (three cells open in a line) it can glide down into from over the walls, or
## out across the desert. Sets `drop_at` (on the ground) and `drop_way` (the way
## it comes in), or leaves `drop_at` INF if there is nowhere.
func _find_drop() -> void:
	drop_at = Vector3.INF
	drop_way = Vector3.ZERO
	if guest == null:
		return
	var from := guest.global_position
	var out_now := _outwards(from)
	var best := -INF
	var here := maze.cell_at(from)
	var options: Array = []
	if maze.inside(here):
		var reach := int(RIDE_FARTHEST / Maze.CELL) + 1
		for dx in range(-reach, reach + 1):
			for dz in range(-reach, reach + 1):
				var cell := here + Vector2i(dx, dz)
				if not maze.inside(cell) or maze.in_clearing(cell):
					continue
				for step: Vector2i in Maze.STEPS:
					# (comes in along `step`: the two cells before it open in a line to it)
					var back := -step
					if maze.blocked(cell, back) or maze.blocked(cell + back, back) or not maze.inside(cell + back * 2):
						continue
					options.append([nav.point(cell), Vector3(step.x, 0.0, step.y)])
	else:
		# (out in the desert: open ground further out)
		var out := Vector3(from.x, 0.0, from.z).normalized()
		for far: float in [70.0, 100.0, 130.0]:
			for turn: float in [0.0, 0.4, -0.4]:
				var way := out.rotated(Vector3.UP, turn)
				options.append([from + way * far, way])
	for option: Array in options:
		var at: Vector3 = option[0]
		var way: Vector3 = option[1]
		var apart := Vector2(at.x - from.x, at.z - from.z).length()
		if apart < RIDE_NEAREST or apart > RIDE_FARTHEST:
			continue
		var gain := _outwards(at) - out_now
		if gain < 25.0:
			continue
		# (further out is better, and not too far to fly)
		var score := gain - apart * 0.3 + _rng.randf() * 6.0
		if score <= best:
			continue
		at.y = _ray_down(at + Vector3.UP * 3.0 + Vector3.UP * 120.0, -50.0)
		if not at.is_finite() or at.y < -40.0 or absf(at.y - maze.ground_height(at)) > 3.0:
			continue
		if not _glide_clear(at, way):
			continue
		best = score
		drop_at = at
		drop_way = way


## How far out from the middle a point is (the further of across and along).
func _outwards(at: Vector3) -> float:
	return maxf(absf(at.x), absf(at.z))


## Whether it can glide down into a hall to `at` coming in along `way`: open sky
## over the end it comes in over and where it stops, and nothing in the way of
## its body down the line of its glide.
func _glide_clear(at: Vector3, way: Vector3) -> bool:
	var stop := at + way * SADDLE + Vector3.UP * 1.3
	var low := at - way * 7.0 + Vector3.UP * 1.3
	var above := at - way * 30.0
	above.y = at.y + _glide_height(at)
	if not _clear_line(stop + Vector3.UP * 1.0, stop + Vector3.UP * 150.0) or not _clear_line(above + Vector3.UP, above + Vector3.UP * 150.0):
		return false
	var across := Vector3.UP.cross(way)
	for off: Vector3 in [Vector3.ZERO, across * 1.4, -across * 1.4, Vector3.UP * 1.2]:
		if not _clear_line(above + off, low + off) or not _clear_line(low + off, stop + off):
			return false
	return true


# --- Calming what hunts ---

## While it is down: what hunts near it backs away, and lets alone those near it.
func _calm(delta: float) -> void:
	if mode == Mode.SOAR or mode == Mode.LEAVE:
		return
	_calm_in -= delta
	if _calm_in > 0.0:
		return
	_calm_in = 0.25
	var middle := global_position
	var near: Array = []
	for player: Node3D in players():
		if is_instance_valid(player) and player.global_position.distance_to(middle) < CALM_RANGE:
			near.append(player)
	for other: Node in get_tree().get_nodes_in_group(&"maze_enemies"):
		var hunter := other as MazeEnemy
		if hunter == null or hunter == self or hunter.dead or hunter.puppet or hunter is MazeLuckDragon:
			continue
		if hunter.global_position.distance_to(middle) > CALM_RANGE + 20.0:
			continue
		for player: Node3D in near:
			hunter._spared[player] = maxf(float(hunter._spared.get(player, 0.0)), CALM_SPARE)
			if hunter.quarry == player:
				hunter.quarry = null
		if hunter.global_position.distance_to(middle) < CALM_RANGE:
			hunter.threat = self


# --- Its rider, on this machine ---

## The seat of a player (-1 if it has none): a friend's copy says; this machine's own is the round's.
func _seat_of(player: Node3D) -> int:
	if player is RemotePlayer:
		return (player as RemotePlayer).slot
	var up := get_parent()
	while up:
		if &"slot" in up and &"player" in up:
			return int(up.get(&"slot"))
		up = up.get_parent()
	return 0


## Carries this machine's own player while they ride it (on the host for the
## host's player, on a guest for theirs): sat on its neck, held still there,
## then set down on the ground where it lands.
func _carry(delta: float) -> void:
	var mine := local_player()
	var riding := mine != null and rider_seat >= 0 and rider_seat == _seat_of(mine) and mode in [Mode.MOUNT, Mode.RIDE, Mode.ALIGHT]
	if not puppet and riding and rider != mine:
		riding = false
	if riding and _carrying == null:
		_carrying = mine
		_carry_t = 0.0
		_sat = false
		_seated = false
		# (he sits down first, if his hands are free: sitting he loses nothing he holds)
		if mine.carried == null:
			mine.sit()
		_carry_from = mine.global_transform
	if _carrying == null:
		return
	if not is_instance_valid(_carrying):
		_carrying = null
		return
	_carry_t += delta
	var seat := look.back_point(SADDLE, SADDLE_UP)
	if riding and mode != Mode.ALIGHT:
		if not _seated:
			# (sitting down, then up onto its neck)
			if _carrying.sit_progress >= 1.0 or _carry_t > 1.2 or _carrying.carried != null:
				_seated = true
				_carry_t = 0.0
				_carrying.process_mode = Node.PROCESS_MODE_DISABLED
				_carry_from = _carrying.global_transform
			return
		var t := smoothstep(0.0, 0.6, _carry_t)
		_carrying.global_position = _carry_from.origin.lerp(seat.origin, t) + Vector3.UP * sin(PI * t) * 0.6
		_carrying.facing_yaw = atan2(seat.basis.z.x, seat.basis.z.z)
		_carrying.rotation.y = _carrying.facing_yaw
		# (what is seen of him is moved by his own _process, which is stopped: moved here instead, sat as he is, leaning with its neck)
		_carrying._reset_visuals()
		var figure := _carrying.get_node_or_null(^"Rig") as Node3D
		if figure:
			figure.global_basis = Basis(Vector3.UP, _carrying.facing_yaw).slerp(seat.basis.orthonormalized(), t)
		_carrying.velocity = velocity
		return
	# Set down: off its neck onto the ground beside it, and his own again.
	if _seated:
		var ground := drop_at if drop_at.is_finite() else _carrying.global_position
		if not ground.is_finite() or ground.distance_to(_carrying.global_position) > 12.0:
			ground = _carrying.global_position
			ground.y = _ray_down(ground + Vector3.UP * 2.0, ground.y - 60.0)
		_carrying.global_position = ground + Vector3.UP * 0.05
		_carrying.velocity = Vector3.ZERO
		_carrying.process_mode = Node.PROCESS_MODE_INHERIT
		_carrying._reset_visuals()
		if _carrying.is_inside_tree() and _carrying.get_viewport().get_camera_3d() is FollowCamera:
			(_carrying.get_viewport().get_camera_3d() as FollowCamera).snap()
	_carrying = null
	_seated = false


# --- How it looks ---

func _drive_look(_delta: float) -> void:
	if look == null:
		return
	look.paddle = 1.0 if mode in [Mode.SOAR, Mode.LEAVE, Mode.RIDE] else 0.6
	look.reach = 1.0 if mode in [Mode.GREET, Mode.MOUNT, Mode.ALIGHT] else 0.0
	look.mouth = 0.25 if mode == Mode.GREET else 0.0
	if guest and is_instance_valid(guest) and mode in [Mode.DESCEND, Mode.CIRCLE, Mode.GREET]:
		look.aim = guest.global_position + Vector3.UP * 1.4
	elif mode == Mode.GREET and visit_at.is_finite():
		look.aim = visit_at + Vector3.UP * 1.4
	else:
		look.aim = Vector3.INF


## Out of everyone's way, it is not posed or drawn.
func _cull(delta: float) -> void:
	_far_check -= delta
	if _far_check > 0.0 or look == null:
		return
	_far_check = 0.5
	var near := nearest_player(global_position)
	var far := near == null or near.global_position.distance_to(global_position) > pose_range
	if far != _far:
		_far = far
		look.visible = not far
		look.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT


func _skip_players() -> Array[RID]:
	var skip: Array[RID] = [get_rid()]
	for player: Node in players():
		if player is CollisionObject3D and is_instance_valid(player):
			skip.append((player as CollisionObject3D).get_rid())
	return skip


## Whether nothing of the world stands between two points.
func _clear_line(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, _skip_players())
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## How high the world is under `from` (a ray straight down to `lowest`); -INF if nothing.
func _ray_down(from: Vector3, lowest: float) -> float:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(from.x, lowest, from.z), 1, _skip_players()))
	return (hit["position"] as Vector3).y if not hit.is_empty() else -INF


## How high the world is under a point (the top of a wall, or the ground), from high above.
func _sky_over(at: Vector3) -> float:
	return maxf(_ray_down(Vector3(at.x, 400.0, at.z), -50.0), _ground(at))


func _sky_round(at: Vector3, radius: float) -> float:
	var top := _sky_over(at)
	for k in 8:
		var a := TAU * k / 8.0
		top = maxf(top, _sky_over(at + Vector3(cos(a), 0.0, sin(a)) * radius))
	return top


func _ground(at: Vector3) -> float:
	return maze.ground_height(at) if maze else 0.0


# --- Being run by someone else ---

func yaw() -> float:
	return atan2(_heading.x, _heading.z)


func net_state() -> int:
	return mode


## Whose seat rides it (low three bits, the seat and one; 0 nobody), and how many times it has sung.
func net_flag() -> int:
	return ((rider_seat + 1) & 0x7) | ((_songs & 0x1f) << 3)


## Where it is visiting, or where it is taking its rider.
func net_point() -> Vector3:
	if mode in [Mode.MOUNT, Mode.RIDE, Mode.ALIGHT] and drop_at.is_finite():
		return drop_at
	return visit_at


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	mode = state as Mode
	_heading = Vector3(sin(facing), 0.0, cos(facing))
	rider_seat = (flag & 0x7) - 1
	var songs := (flag >> 3) & 0x1f
	if _heard_songs >= 0 and songs != _heard_songs and look:
		look.sing()
	_heard_songs = songs
	if mode in [Mode.MOUNT, Mode.RIDE, Mode.ALIGHT]:
		drop_at = point
	else:
		visit_at = point


func _follow_news(delta: float) -> void:
	if not _heard:
		return
	_heard_at += _heard_moving * delta
	global_position = global_position.lerp(_heard_at, 1.0 - exp(-8.0 * delta))
	if global_position.distance_to(_heard_at) > 12.0:
		global_position = _heard_at


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	_heading = Vector3(sin(facing), 0.0, cos(facing))
	if look:
		look.rotation.y = facing - rotation.y
		look.settle()


func _puppet_changed() -> void:
	collision_layer = 0
	collision_mask = 0

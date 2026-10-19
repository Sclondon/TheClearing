class_name HighClimb
extends RefCounted
## How one hunter that can climb (MazeEnemy.climbs) goes up after someone who has got
## up out of its reach on the floor: onto a ledge, a terrace or a concrete bridge (the
## surfaces of HighWays). The user, 2026-10-18: "more creatures should be able to climb
## things". Made for a hunter the first time it is asked (`MazeEnemy._ways_up`), so
## those that never climb carry nothing.
##
## - IDLE: a few times a second, while it hunts a player (not a creature: the world's
##   own hunting stays on the floor), it looks whether they are up (HighWays.UP over
##   the floor, on a surface or by one: on the ivy up to it). Up for half a second, it
##   plans the way up (HighWays.way_up, at the place nearest them) and goes.
## - GO: on the floor by the passages (MazeNav) to the foot of the way up, planned
##   again now and then as they move.
## - PATH: up it, move by move: WALK (to the face, over a lip, along a lower ledge to
##   the next step), CLIMB (up a face, at `climb_speed`: clinging, or, floating, in the
##   air), CROUCH and LEAP (a bound up in an arc as high as `leap_most`; higher than
##   that, the rest clawed up), and down again the same way: CLIMB down, or FALL (it
##   drops off the edge in an arc, landing on the floor).
## - ON: up there, along the surfaces at its height to them; near enough, it catches
##   them (`MazeEnemy._strike_aloft`). If they go higher it goes on up from there; if
##   they get down, or it loses them, or cannot get along to them, it comes down.
##
## All of it is placed, not moved by physics (the ledges' bodies are only for the
## players): `aloft` says what it is doing, for its pose and for the network (one byte
## of MazeEnemy.state_bytes), and `facing` which way it faces.

enum Aloft { NONE, CLIMB, DOWN, CROUCH, LEAP, ON, DROP }
enum Phase { IDLE, GO, PATH, ON }
enum Move { WALK, CLIMB, CROUCH, LEAP, FALL }

## How long it crouches before it leaps, s.
const CROUCH_TIME := 0.32
## How far out from the face its foot is when it leaps, m.
const RUN_UP := 1.4
## How long it holds up there for someone it cannot get along to, s.
const WAIT_UP := 7.0

var who: MazeEnemy
var phase := Phase.IDLE
var aloft := Aloft.NONE
## Which way it faces, radians about Y (0 faces +Z).
var facing := 0.0
## The way out from the face it is on (or last was).
var out := Vector3.FORWARD

var _ways: HighWays
var _layout: MazeLayout
var _layout_looked := false
var _check_in := 0.0
var _high_for := 0.0
var _replan_in := 0.0
var _moves: Array = []
var _move := 0
var _from := Vector3.ZERO
var _t := 0.0
var _span := 1.0
var _down := false
var _top := 0.0
var _stuck := 0.0
var _wait := 0.0
var _target := -1


func _init(hunter: MazeEnemy) -> void:
	who = hunter


func busy() -> bool:
	return phase != Phase.IDLE


## Each step of its thinking (its own is not run while this gives true).
func step(delta: float, radius: float, speed: float) -> bool:
	var q := _quarry()
	match phase:
		Phase.IDLE:
			_check_in -= delta
			if _check_in > 0.0:
				return false
			_check_in = 0.25
			var up := _surface_of(q) if q else -1
			_high_for = _high_for + 0.25 if up >= 0 else 0.0
			if _high_for < 0.5:
				return false
			_target = up
			phase = Phase.GO
			_replan_in = 0.0
			return _go(q, delta, radius, speed)
		Phase.GO:
			return _go(q, delta, radius, speed)
		Phase.PATH:
			_path(delta, radius, speed)
			return true
		Phase.ON:
			_on(q, delta, radius, speed)
			return true
	return false


## Who it is after, if it is a player it still knows of.
func _quarry() -> Node3D:
	if who.hunting() and who.quarry and not (who.quarry is MazeEnemy) and is_instance_valid(who.quarry):
		return who.quarry
	return null


func ways_at(p: Vector3) -> HighWays:
	if not _layout_looked:
		_layout_looked = true
		_layout = HighWays.layout_for(who, who.maze)
	var zone := MazeLayout.zone_at(who.maze, p)
	if _ways == null or _ways.zone != zone or _ways.maze != who.maze:
		_ways = HighWays.of(who.maze, zone, _layout)
	return _ways


## The surface `q` is up on, or up by (on the ivy to it), or -1 if they are on the floor.
func _surface_of(q: Node3D) -> int:
	var at := q.global_position
	if at.y - who.maze.ground_height(at) < HighWays.UP:
		return -1
	var ways := ways_at(at)
	var s := ways.under(at)
	return s if s >= 0 else ways.near(at)


# --- On the floor, to the foot of the way up ---

func _go(q: Node3D, delta: float, radius: float, speed: float) -> bool:
	_replan_in -= delta
	if _replan_in <= 0.0:
		_replan_in = 0.6
		_target = _surface_of(q) if q else -1
		if _target < 0:
			_stop()
			return false
		_plan_up(_ways.way_up(_target, q.global_position), radius, who.global_position.y)
		if _moves.is_empty():
			_stop()
			return false
	var foot: Vector3 = _moves[0][1]
	var here := who.global_position
	var flat := Vector3(foot.x - here.x, 0.0, foot.z - here.z)
	if flat.length() < 0.35 + speed * delta:
		phase = Phase.PATH
		_start_move(1)
		return true
	var wish := flat
	if flat.length() > 3.0 or not who.nav.line_free(here, foot, 0.05):
		wish = who.nav.waypoint(here, foot, MazeNav.clearance_for(radius)) - here
		wish.y = 0.0
	var want := wish.normalized() * speed
	who.velocity.x = want.x
	who.velocity.z = want.z
	who.velocity.y = 0.0 if who.is_on_floor() else who.velocity.y - 24.0 * delta
	who.move_and_slide()
	if want.length() > 0.1:
		facing = lerp_angle(facing, atan2(want.x, want.z), 1.0 - exp(-10.0 * delta))
	aloft = Aloft.NONE
	return true


## Back to its own ways, on the floor.
func _stop() -> void:
	phase = Phase.IDLE
	aloft = Aloft.NONE
	_high_for = 0.0
	_check_in = 0.5
	_moves.clear()
	who.velocity = Vector3.ZERO


# --- The moves up and down ---

## The moves up `stages` (HighWays.way_up), from the foot: [kind, to, out] each, the
## first only where it starts.
func _plan_up(stages: Array, radius: float, from_y: float, from_stage := 0) -> void:
	_moves.clear()
	_down = false
	if stages.is_empty():
		return
	var climbs := who.climbs
	# (clinging to the face; floating, clear of it)
	var cling := radius * 0.6 + 0.05 if climbs != MazeEnemy.Climbs.FLOAT else radius + 0.4
	for k in range(from_stage, stages.size()):
		var stage: Array = stages[k]
		var edge: Vector3 = stage[0]
		var way: Vector3 = stage[1]
		var top: float = stage[2]
		var base: float = stage[3]
		var rise := top - base
		var inside := edge - way * minf(radius + 0.1, 0.45)
		inside.y = top
		var leaps := climbs == MazeEnemy.Climbs.LEAP
		var at_face := edge + way * cling
		if k == from_stage:
			# (where it starts from: out on the floor, or on the surface under)
			var foot := edge + way * ((RUN_UP + radius) if leaps else (radius + 0.35))
			foot.y = from_y if k == 0 else base
			_moves.append([Move.WALK, foot, way])
		if leaps:
			_moves.append([Move.CROUCH, _last(), way])
			if rise <= who.leap_most + 0.01:
				_moves.append([Move.LEAP, inside, way])
				continue
			_moves.append([Move.LEAP, Vector3(at_face.x, base + who.leap_most, at_face.z), way])
		else:
			_moves.append([Move.WALK, Vector3(at_face.x, base, at_face.z), way])
		_moves.append([Move.CLIMB, Vector3(at_face.x, top, at_face.z), way])
		_moves.append([Move.WALK, inside, way])


## The moves down from where it is on surface `s` to the floor: along to the nearest
## front, then down it (climbed, stage by stage) or off it (a drop, in one).
func _plan_down(s: int, radius: float) -> void:
	_moves.clear()
	_down = true
	var here := who.global_position
	_moves.append([Move.WALK, here, out])
	if s < 0:
		return
	var stages := _ways.way_up(s, here)
	if stages.is_empty():
		return
	var cling := radius * 0.6 + 0.05
	if who.climbs == MazeEnemy.Climbs.LEAP:
		var last: Array = stages[stages.size() - 1]
		var edge: Vector3 = last[0]
		var way: Vector3 = last[1]
		var lip := edge - way * 0.1
		lip.y = last[2]
		_moves.append([Move.WALK, lip, way])
		var land := edge + way * (2.4 + radius)
		land.y = who.maze.ground_height(land)
		_moves.append([Move.FALL, land, way])
		return
	for k in range(stages.size() - 1, -1, -1):
		var stage: Array = stages[k]
		var edge: Vector3 = stage[0]
		var way: Vector3 = stage[1]
		var inside := edge - way * minf(radius + 0.1, 0.45)
		inside.y = stage[2]
		var at_face := edge + way * cling
		_moves.append([Move.WALK, inside, way])
		_moves.append([Move.WALK, Vector3(at_face.x, stage[2], at_face.z), way])
		_moves.append([Move.CLIMB, Vector3(at_face.x, stage[3], at_face.z), way])
	var foot: Vector3 = _last() + (stages[0][1] as Vector3) * (radius + 0.35)
	_moves.append([Move.WALK, foot, stages[0][1]])


func _last() -> Vector3:
	return _moves[_moves.size() - 1][1]


func _start_move(index: int) -> void:
	_move = index
	_from = who.global_position
	_t = 0.0
	if _move >= _moves.size():
		return
	var move: Array = _moves[_move]
	out = move[2]
	var to: Vector3 = move[1]
	match move[0]:
		Move.CROUCH:
			_span = CROUCH_TIME
		Move.LEAP:
			_span = clampf(0.4 + absf(to.y - _from.y) * 0.045, 0.45, 1.0)
		Move.FALL:
			_span = clampf(sqrt(2.0 * maxf(_from.y - to.y, 0.5) / 24.0) * 1.15 + 0.2, 0.45, 1.6)
		_:
			_span = 0.0


func _path(delta: float, radius: float, speed: float) -> void:
	if _move >= _moves.size():
		_arrive(radius)
		return
	var move: Array = _moves[_move]
	var kind: int = move[0]
	var to: Vector3 = move[1]
	var before := who.global_position
	match kind:
		Move.WALK, Move.CLIMB:
			var pace := speed * 0.7
			if kind == Move.CLIMB:
				pace = who.climb_speed * (1.5 if _down else 1.0)
			var next := before.move_toward(to, pace * delta)
			who.global_position = next
			if kind == Move.CLIMB:
				aloft = Aloft.DOWN if _down else Aloft.CLIMB
				facing = atan2(-out.x, -out.z)
			else:
				var high := next.y - who.maze.ground_height(next) > 0.6
				aloft = Aloft.ON if high else Aloft.CLIMB
				var flat := Vector3(to.x - before.x, 0.0, to.z - before.z)
				if flat.length() > 0.05:
					facing = lerp_angle(facing, atan2(flat.x, flat.z), 1.0 - exp(-12.0 * delta))
			if next.distance_to(to) < 0.01:
				_start_move(_move + 1)
		Move.CROUCH:
			_t += delta
			aloft = Aloft.CROUCH
			facing = lerp_angle(facing, atan2(-out.x, -out.z), 1.0 - exp(-14.0 * delta))
			if _t >= _span:
				_start_move(_move + 1)
		Move.LEAP, Move.FALL:
			_t += delta
			var u := clampf(_t / _span, 0.0, 1.0)
			var flat := _from.lerp(to, smoothstep(0.0, 1.0, u) if kind == Move.LEAP else u)
			var y: float
			if kind == Move.LEAP:
				# (up fast and slowing, a little over the lip, and down onto it)
				y = _from.y + (to.y - _from.y) * sin(u * PI * 0.5) + 0.7 * sin(u * PI)
				aloft = Aloft.LEAP
				facing = atan2(-out.x, -out.z)
			else:
				# (out from the edge, then falling faster and faster)
				y = _from.y + 0.5 * sin(PI * minf(u * 1.4, 1.0)) * (1.0 - u) + (to.y - _from.y) * u * u
				aloft = Aloft.DROP
				facing = atan2(out.x, out.z)
			who.global_position = Vector3(flat.x, y, flat.z)
			if u >= 1.0:
				_start_move(_move + 1)
	who.velocity = (who.global_position - before) / maxf(delta, 0.001)
	# (on the face, someone on it within reach is caught there)
	_strike_near(radius, 0.9)


## At the end of its moves: up on its surface, or down on the floor.
func _arrive(radius: float) -> void:
	who.velocity = Vector3.ZERO
	if _down:
		_stop()
		var ground := who.maze.ground_height(who.global_position)
		who.global_position.y = ground + 0.05
		return
	phase = Phase.ON
	aloft = Aloft.ON
	_stuck = 0.0
	_wait = 0.0
	var ways := ways_at(who.global_position)
	var s := ways.level_at(who.global_position, who.global_position.y, 0.6, -0.3)
	_top = ways.tops[s] if s >= 0 else who.global_position.y
	_strike_near(radius)


# --- Up there ---

func _on(q: Node3D, delta: float, radius: float, speed: float) -> void:
	aloft = Aloft.ON
	var here := who.global_position
	var ways := ways_at(here)
	var mine := ways.level_at(here, _top, 0.6, -0.3)
	if q == null:
		_come_down(mine, radius)
		return
	var at := q.global_position
	if at.y - who.maze.ground_height(at) < HighWays.UP * 0.7:
		_come_down(mine, radius)
		return
	var theirs := ways.under(at)
	var to := Vector3(at.x - here.x, 0.0, at.z - here.z)
	if theirs >= 0 and absf(ways.tops[theirs] - _top) < 0.6:
		_wait = 0.0
		if _strike_near(radius):
			return
		if not _walk(to, speed, delta, radius):
			_stuck += delta
			if _stuck > 1.2:
				_come_down(mine, radius)
		else:
			_stuck = maxf(_stuck - delta, 0.0)
		return
	if theirs >= 0 and ways.tops[theirs] > _top + 0.6:
		# (they have gone higher: on up from here, if the way up to them starts on this level)
		var stages := ways.way_up(theirs, at)
		for k in stages.size():
			var foot: Vector3 = stages[k][0]
			# (only a short way along: further, round corners, it goes down and up again)
			if absf(float(stages[k][3]) - _top) < 0.6 and ways.level_at(foot + (stages[k][1] as Vector3) * 0.3, _top, 0.6) >= 0 \
					and Vector2(foot.x - here.x, foot.z - here.z).length() < 10.0:
				_plan_up(stages, radius, _top, k)
				# (along this level to the foot of it first)
				phase = Phase.PATH
				_start_move(0)
				return
		_come_down(mine, radius)
		return
	if theirs >= 0:
		# (lower: down, and up again to them from the floor if they stay up)
		_come_down(mine, radius)
		return
	# Up, on nothing it knows (the ivy, a vine, a rope bridge): it waits, facing them, and catches them if they come near.
	if to.length() > 0.1:
		facing = lerp_angle(facing, atan2(to.x, to.z), 1.0 - exp(-6.0 * delta))
	who.velocity = Vector3.ZERO
	if _strike_near(radius):
		return
	_wait += delta
	if _wait > WAIT_UP:
		_come_down(mine, radius)


## A step along the surfaces at its height, `to` the way it wants (flat): straight, or
## along x or z alone if that is all it can. Whether it moved.
func _walk(to: Vector3, speed: float, delta: float, radius: float) -> bool:
	if to.length() < 0.05:
		who.velocity = Vector3.ZERO
		return true
	var ways := _ways
	var here := who.global_position
	var step := to.normalized() * minf(speed * 0.85 * delta, to.length())
	var inset := minf(radius, 0.4)
	for tried: Vector3 in [step, Vector3(step.x, 0.0, 0.0), Vector3(0.0, 0.0, step.z)]:
		if tried.length() < 0.0005:
			continue
		var next := here + tried
		var s := ways.level_at(next, _top, 0.4, inset)
		if s < 0 or ways.in_wall(next + tried.normalized() * radius * 0.5 + Vector3.UP * 0.3):
			continue
		_top = ways.tops[s]
		who.global_position = Vector3(next.x, _top + 0.02, next.z)
		who.velocity = tried / maxf(delta, 0.001)
		facing = lerp_angle(facing, atan2(tried.x, tried.z), 1.0 - exp(-10.0 * delta))
		return true
	who.velocity = Vector3.ZERO
	return false


func _come_down(s: int, radius: float) -> void:
	_plan_down(s, radius)
	phase = Phase.PATH
	_start_move(0)


## Catches its quarry if they are within reach of it (MazeEnemy._strike_aloft). Whether it did.
func _strike_near(radius: float, reach_up := 1.7) -> bool:
	var q := _quarry()
	if q == null:
		return false
	var d := q.global_position - who.global_position
	if Vector2(d.x, d.z).length() < radius + 0.85 and absf(d.y) < reach_up and who.huntable(q):
		who._strike_aloft(q)
		return true
	return false


## For a body the boy's rig poses (CharacterRig reads it as it would a Player: the
## tribe, the clown, the mushroom zombies), climbing a wall's face hand over hand as he
## climbs a ladder: `on` or not, at `at` (its feet), `out` the way out from the face,
## `big` its scale. Sets on `body` what the rig reads: `state` (Player.State LADDER or
## FREE), `ladder_travel`, and where its hands and feet hold (rungs a hand apart, each
## taking every other one, up the bare face).
static func hold_wall(body: Object, on: bool, at: Vector3, out: Vector3, big := 1.0) -> void:
	body.set(&"state", Player.State.LADDER if on else Player.State.FREE)
	body.set(&"hand_reach", 1.0 if on else 0.0)
	if not on:
		return
	body.set(&"ladder_travel", at.y / big)
	var right := Vector3(-out.z, 0.0, out.x)
	var hands := PackedVector3Array()
	var feet := PackedVector3Array()
	for i in 2:
		var across := right * (-0.15 if i == 0 else 0.15) * big
		var wall := at - out * 0.2 * big + across
		hands.append(Vector3(wall.x, _rung(at.y + 1.12 * big, i == 1, big), wall.z))
		feet.append(Vector3(wall.x, _rung(at.y + 0.12 * big, i == 0, big), wall.z) + out * 0.05 * big)
	body.set(&"hand_points", hands)
	body.set(&"foot_points", feet)


## The hold at or under `y` (every other one by `odd`), 0.3 m apart (as Ladder.RUNG).
static func _rung(y: float, odd: bool, big: float) -> float:
	var gap := 0.3 * big
	var shift := gap if odd else 0.0
	return floorf((y - shift) / (gap * 2.0)) * gap * 2.0 + shift


## Put straight down on the floor (asleep, killed, brought back): off the surface it is
## on, out from its front.
func land_now(radius := 0.4) -> void:
	if phase == Phase.IDLE:
		return
	var here := who.global_position
	if here.y - who.maze.ground_height(here) > 0.6 and _ways:
		var s := _ways.level_at(here, here.y, 1.0, -0.4)
		var front := _ways.nearest_front(s, here) if s >= 0 else []
		if not front.is_empty():
			var stages := _ways.way_up(s, here)
			var low: Array = stages[0] if not stages.is_empty() else [front[0], front[1]]
			here = (low[0] as Vector3) + (low[1] as Vector3) * (radius + 0.6)
	here.y = who.maze.ground_height(here) + 0.05
	who.global_position = here
	_stop()

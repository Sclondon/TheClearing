class_name Wildlife
extends Node3D
## The animals that live in the clearing and the maze and hunt nobody: herds of
## white-tailed deer (a buck, does, spotted fawns) and of elk (a bull, cows,
## calves), drawn by Deer and Elk (creatures/deer, creatures/elk), the same
## animals as the herd that watches (MazeDeer) and the bull that charges
## (MazeElk), with nothing wrong about them.
##
## WHAT THEY DO. A herd grazes about its patch, heads down, wandering a step
## at a time, one or other lifting its head to look about, ears and tails
## flicking. A player in sight and near (`watch_range`): heads come up, one
## always watching, the rest going back to grazing between looks. Nearer
## (`flee_range`), or running at them: they take off, deer stotting a few
## bounds with their white tails up and then galloping, elk trotting and then
## galloping, well away from the player, and settle to graze where they stop.
## A bull elk bugles now and then. They never catch anyone; they are not in
## the group `pursuers`, nor among MazeEnemies, and nothing here is sent over
## the network.
##
## IN STEP. Where the herds go, who is in them and every choice they make
## comes from the round's seed, and what frightens them is where the players
## are, which every machine in a room knows: so each machine runs its own copy
## and they agree closely enough. Herds far from every player are not drawn
## (`pose_range`), but still go about their business.
##
## WHERE. `populate(maze, seed)`: in the clearing as many herds as its
## ClearingStyle says ("Wildlife": out in the meadow on the diagonals, away
## from the middle where everyone wakes and from the ways to the gates), and in
## each ring as many as its MazeStyle says ("Wildlife"), in its halls.

enum Kind { DEER, ELK }
enum Mode { GRAZE, WATCH, FLEE, SETTLE }

const STEP := 1.0 / 60.0
## How near a player brings their heads up, and how near sends them off (m), deer and elk.
const WATCH_RANGE := Vector2(34.0, 40.0)
const FLEE_RANGE := Vector2(13.0, 17.0)
## How near a player running at them sends them off.
const RUSH_RANGE := 24.0
## Further than this from every player a herd is not drawn.
const POSE_RANGE := 90.0
## How far they run (m).
const FLIGHT := Vector2(45.0, 70.0)
## The clearing's open ground: how far from the middle the meadow herds stand,
## and nearest the middle they may run to.
const MEADOW := Vector2(120.0, 200.0)
const KEEP_FROM_MIDDLE := 70.0

var maze: Maze
var herds: Array[Herd] = []
## Who frightens them (empty: the group `maze_players`).
var targets: Array = []

var _nav: MazeNav
var _pose_check := 0.0


class Animal:
	var node: Deer
	var at := Vector3.ZERO
	var yaw := 0.0
	var velocity := Vector3.ZERO
	## Where it keeps in the herd, from the herd's middle.
	var offset := Vector3.ZERO
	var size := 1.0
	var young := false
	var goal := Vector3.INF
	var goal_in := 0.0
	var head_up := 0.0


class Herd:
	var kind := Kind.DEER
	var animals: Array[Animal] = []
	var home := Vector3.ZERO
	var clearing := false
	var mode := Mode.GRAZE
	var timer := 0.0
	var flee_to := Vector3.INF
	var fled := 0.0
	var threat := Vector3.INF
	var rng := RandomNumberGenerator.new()
	var posed := true
	var bugle_in := 60.0

	func middle() -> Vector3:
		var sum := Vector3.ZERO
		for one in animals:
			sum += one.at
		return sum / maxf(animals.size(), 1.0)


## Puts in every herd the clearing's style and the rings' styles ask for, from `seed_value`.
func populate(plan: Maze, seed_value: int) -> void:
	maze = plan
	_nav = MazeNav.new(plan)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var look := plan.clearing_style
	var corners := [0, 1, 2, 3]
	for k in look.deer_herds + look.elk_herds:
		var kind := Kind.DEER if k < look.deer_herds else Kind.ELK
		add_herd(kind, _meadow_spot(rng, corners), true, rng.randi())
	var lairs := _nav.lairs(3)
	for ring in mini(plan.styles.size(), plan.rings):
		var style: MazeStyle = plan.styles[ring]
		var halls: Array[Vector2i] = []
		for cell in lairs:
			if plan.ring_of(cell) == ring + 1 and not _nav.dead_end(cell):
				halls.append(cell)
		if halls.is_empty():
			continue
		for k in style.wild_deer_herds + style.wild_elk_herds:
			var kind := Kind.DEER if k < style.wild_deer_herds else Kind.ELK
			var cell: Vector2i = halls[rng.randi_range(0, halls.size() - 1)]
			add_herd(kind, plan.world(cell), false, rng.randi())


## Somewhere out in the clearing's meadow for a herd: towards one of its
## corners (not the middle of a side, where the gates are), clear of the marsh.
func _meadow_spot(rng: RandomNumberGenerator, corners: Array) -> Vector3:
	var look := maze.clearing_style
	var corner: int = corners.pop_at(rng.randi_range(0, corners.size() - 1)) if not corners.is_empty() else rng.randi_range(0, 3)
	var spot := Vector3.ZERO
	for attempt in 12:
		var angle := PI * 0.25 + PI * 0.5 * corner + rng.randf_range(-0.3, 0.3)
		spot = Vector3(sin(angle), 0.0, cos(angle)) * rng.randf_range(MEADOW.x, MEADOW.y)
		if look.marsh_wet_at(Vector2(spot.x, spot.z), maze.maze_seed) <= 0.0:
			break
	spot = _in_bounds(spot)
	spot.y = maze.ground_height(spot)
	return spot


## Puts in a herd of `kind` round `at`, in the clearing or in the maze; its
## make-up and its every choice from `seed_value`.
func add_herd(kind: Kind, at: Vector3, in_clearing: bool, seed_value: int) -> Herd:
	var herd := Herd.new()
	herd.kind = kind
	herd.clearing = in_clearing
	herd.home = at
	herd.rng.seed = seed_value
	herd.bugle_in = herd.rng.randf_range(20.0, 70.0)
	var count := herd.rng.randi_range(4, 6) if kind == Kind.DEER else herd.rng.randi_range(4, 7)
	var young := herd.rng.randi_range(1, 2)
	var tints := [Color.WHITE, Color(1.05, 1.0, 0.95), Color(0.93, 0.93, 0.93), Color(0.98, 0.95, 0.9), Color(1.05, 0.98, 0.92)]
	for i in count:
		var one := Animal.new()
		var lead := i == 0 and herd.rng.randf() < 0.6
		one.young = i >= count - young
		var node: Deer
		if kind == Kind.DEER:
			node = Deer.new()
			node.variant = Deer.Variant.BUCK if lead else Deer.Variant.DOE
			node.fawn = one.young
			one.size = 0.55 if one.young else herd.rng.randf_range(0.92, 1.04) * (1.05 if lead else 1.0)
		else:
			var elk := Elk.new()
			elk.cow = not lead
			node = elk
			one.size = 0.62 if one.young else herd.rng.randf_range(0.94, 1.04)
		node.name = "%s%d_%d" % ["Deer" if kind == Kind.DEER else "Elk", herds.size(), i]
		node.coat_tint = tints[(i + herd.rng.randi_range(0, 4)) % tints.size()]
		node.low_poly = Settings.low_poly
		node.fur_shells = 0 if Settings.low_poly else 1
		node.measure_velocity = false
		node.scale = Vector3.ONE * one.size
		var round_about := TAU * i / count + herd.rng.randf_range(-0.5, 0.5)
		one.offset = Vector3(cos(round_about), 0.0, sin(round_about)) * (herd.rng.randf_range(1.5, 4.5) if i > 0 else 0.0) * (1.4 if kind == Kind.ELK else 1.0)
		one.at = _placed(herd, at + one.offset)
		one.yaw = herd.rng.randf_range(-PI, PI)
		one.goal_in = herd.rng.randf_range(0.0, 4.0)
		one.node = node
		add_child(node)
		node.global_position = one.at
		node.rotation.y = one.yaw
		node.settle()
		if in_clearing:
			Grass.push(node, 0.55 * one.size * (1.5 if kind == Kind.ELK else 1.0))
		herd.animals.append(one)
	herds.append(herd)
	return herd


# --- Going about ---

func _physics_process(_delta: float) -> void:
	if maze == null:
		return
	var players := _players()
	_pose_check -= STEP
	var check := _pose_check <= 0.0
	if check:
		_pose_check = 0.5
	for herd in herds:
		_think(herd, players)
		for one in herd.animals:
			_move(herd, one)
		if check:
			_pose(herd, players)
		if herd.posed:
			for one in herd.animals:
				_show(herd, one)


func _players() -> Array:
	var found := targets if not targets.is_empty() else (get_tree().get_nodes_in_group(&"maze_players") if is_inside_tree() else [])
	return found.filter(func(p: Variant) -> bool: return is_instance_valid(p) and (p as Node).is_inside_tree() and p.get(&"escaped") != true)


func _think(herd: Herd, players: Array) -> void:
	var middle := herd.middle()
	var deer := herd.kind == Kind.DEER
	var near: Node3D = null
	var far := INF
	for player: Node3D in players:
		var d := Vector2(player.global_position.x - middle.x, player.global_position.z - middle.z).length()
		if d < far and (herd.clearing or _nav.sees(middle + Vector3.UP, player.global_position + Vector3.UP, WATCH_RANGE.y + 10.0)):
			far = d
			near = player
	var watch := WATCH_RANGE.x if deer else WATCH_RANGE.y
	var flee := FLEE_RANGE.x if deer else FLEE_RANGE.y
	herd.timer -= STEP
	match herd.mode:
		Mode.GRAZE, Mode.WATCH, Mode.SETTLE:
			if near and (far < flee or _rushing(near, middle) and far < RUSH_RANGE):
				_take_flight(herd, near.global_position)
			elif herd.mode == Mode.SETTLE:
				if herd.timer <= 0.0:
					herd.mode = Mode.GRAZE
			elif near and far < watch:
				herd.mode = Mode.WATCH
				herd.threat = near.global_position
			else:
				herd.mode = Mode.GRAZE
		Mode.FLEE:
			herd.fled += STEP
			if Vector2(herd.flee_to.x - middle.x, herd.flee_to.z - middle.z).length() < 4.0 or herd.fled > 14.0:
				herd.mode = Mode.SETTLE
				herd.timer = herd.rng.randf_range(3.0, 5.0)
				herd.home = herd.flee_to
	# A bull elk bugles now and then, from far off.
	if not deer and herd.animals[0].node is Elk and not (herd.animals[0].node as Elk).cow:
		herd.bugle_in -= STEP
		if herd.bugle_in <= 0.0:
			herd.bugle_in = herd.rng.randf_range(45.0, 110.0)
			if herd.mode != Mode.FLEE and herd.posed:
				(herd.animals[0].node as Elk).bugle()


func _rushing(player: Node3D, middle: Vector3) -> bool:
	var them: Variant = player.get(&"velocity")
	if them == null:
		return false
	var moving := Vector2((them as Vector3).x, (them as Vector3).z)
	var to := Vector2(middle.x - player.global_position.x, middle.z - player.global_position.z)
	return moving.length() > 3.6 and moving.normalized().dot(to.normalized()) > 0.6


## They take off away from `from`.
func _take_flight(herd: Herd, from: Vector3) -> void:
	herd.mode = Mode.FLEE
	herd.fled = 0.0
	herd.threat = from
	var middle := herd.middle()
	if herd.clearing:
		var away := Vector3(middle.x - from.x, 0.0, middle.z - from.z)
		away = away.normalized() if away.length() > 0.1 else Vector3(sin(herd.rng.randf() * TAU), 0.0, 1.0).normalized()
		away = away.rotated(Vector3.UP, herd.rng.randf_range(-0.35, 0.35))
		var to := middle + away * herd.rng.randf_range(FLIGHT.x, FLIGHT.y)
		# (never towards the middle, where everyone wakes)
		var flat := Vector2(to.x, to.z)
		if flat.length() < KEEP_FROM_MIDDLE:
			flat = flat.normalized() * KEEP_FROM_MIDDLE if flat.length() > 0.1 else Vector2(KEEP_FROM_MIDDLE, 0.0)
		herd.flee_to = _in_bounds(Vector3(flat.x, 0.0, flat.y))
	else:
		var mine := _nav.field(maze.cell_at(middle))
		var theirs := _nav.field(maze.cell_at(from))
		var best := middle
		var score := -INF
		for i in mine.size():
			if mine[i] < 2 or mine[i] > 5:
				continue
			var value := (theirs[i] if theirs[i] >= 0 else 99) - mine[i] * 0.3 + herd.rng.randf_range(0.0, 0.4)
			if value > score:
				score = value
				best = maze.world(Vector2i(i % maze.size, i / maze.size))
		herd.flee_to = best
	herd.flee_to.y = maze.ground_height(herd.flee_to)
	if herd.kind == Kind.DEER:
		var lead := herd.animals[0].node
		lead.snort()


func _move(herd: Herd, one: Animal) -> void:
	var deer := herd.kind == Kind.DEER
	var want := Vector3.ZERO
	var speed := 0.0
	match herd.mode:
		Mode.GRAZE, Mode.WATCH, Mode.SETTLE:
			one.goal_in -= STEP
			if one.goal_in <= 0.0:
				one.goal_in = herd.rng.randf_range(3.0, 9.0)
				if herd.rng.randf() < 0.55 and herd.mode == Mode.GRAZE:
					var reach := 9.0 if deer else 13.0
					var round_about := herd.rng.randf_range(0.0, TAU)
					var goal := herd.home + one.offset + Vector3(cos(round_about), 0.0, sin(round_about)) * herd.rng.randf_range(0.0, reach * 0.5)
					one.goal = goal if herd.clearing or _nav.line_free(one.at, goal, 0.4) else Vector3.INF
				else:
					one.goal = Vector3.INF
				one.head_up = herd.rng.randf_range(1.5, 4.0) if herd.rng.randf() < 0.3 else 0.0
			if one.goal.is_finite() and herd.mode == Mode.GRAZE:
				want = one.goal - one.at
				speed = 0.65 if deer else 0.95
				if Vector2(want.x, want.z).length() < 0.4:
					one.goal = Vector3.INF
		Mode.FLEE:
			var goal := herd.flee_to + one.offset * 1.3
			want = goal - one.at if herd.clearing else _nav.waypoint(one.at, goal, MazeNav.clearance_for(0.4)) - one.at
			var early := herd.fled < (0.9 if deer else 0.7)
			speed = (2.8 if early else 8.5) if deer else (4.2 if early else 7.6)
			speed *= lerpf(0.85, 1.0, one.size)
	# (a little apart from the others)
	for other in herd.animals:
		if other == one:
			continue
		var out := one.at - other.at
		out.y = 0.0
		var room := 0.9 * (one.size + other.size) * (1.4 if not deer else 1.0)
		if out.length() < room and out.length() > 0.001:
			want += out.normalized() * (room - out.length()) * 2.0
			speed = maxf(speed, 0.5)
	want.y = 0.0
	var aim := want.normalized() * speed if want.length() > 0.05 else Vector3.ZERO
	one.velocity = one.velocity.move_toward(aim, (10.0 if deer else 7.0) * STEP)
	if one.velocity.length() > 0.05:
		one.at = _placed(herd, one.at + one.velocity * STEP)
		if one.velocity.length() > 0.25:
			one.yaw = lerp_angle(one.yaw, atan2(one.velocity.x, one.velocity.z), 1.0 - exp(-(5.0 if herd.mode == Mode.FLEE else 2.5) * STEP))
	elif herd.mode == Mode.WATCH and herd.threat.is_finite():
		# (the body turns only when the head can turn no further)
		var to := herd.threat - one.at
		var want_yaw := atan2(to.x, to.z)
		if absf(angle_difference(one.yaw, want_yaw)) > 1.4:
			one.yaw = lerp_angle(one.yaw, want_yaw, 1.0 - exp(-0.8 * STEP))
	one.head_up = maxf(one.head_up - STEP, 0.0)


## A point on the ground where it may stand: the clearing's ground in its
## bounds, or the maze's floor clear of its walls.
func _placed(herd: Herd, point: Vector3) -> Vector3:
	if herd.clearing:
		point = _in_bounds(point)
	elif not _nav.clear_of_walls(point, 0.45):
		# (pressed against a wall: eased back towards the middle of its cell)
		point = maze.world(maze.cell_at(point)).lerp(point, 0.9)
	point.y = maze.ground_height(point)
	return point


## Kept inside the clearing's open ground.
func _in_bounds(point: Vector3) -> Vector3:
	var edge := maze.clearing * Maze.CELL * 0.5 - 30.0
	return Vector3(clampf(point.x, -edge, edge), point.y, clampf(point.z, -edge, edge))


## Draws a herd only when someone is near enough to see it.
func _pose(herd: Herd, players: Array) -> void:
	var middle := herd.middle()
	var seen := players.is_empty()
	for player: Node3D in players:
		if player.global_position.distance_to(middle) < POSE_RANGE:
			seen = true
	if seen == herd.posed:
		return
	herd.posed = seen
	for one in herd.animals:
		one.node.visible = seen
		one.node.process_mode = Node.PROCESS_MODE_INHERIT if seen else Node.PROCESS_MODE_DISABLED
		if seen:
			one.node.global_position = one.at
			one.node.settle()


func _show(herd: Herd, one: Animal) -> void:
	var node := one.node
	node.global_position = one.at
	node.rotation = Vector3(0.0, one.yaw, 0.0)
	node.velocity = one.velocity
	var still := one.velocity.length() < 0.3
	var watching := herd.mode in [Mode.WATCH, Mode.SETTLE]
	# (watching, the first of them never looks away; the rest go back to grazing between looks)
	var looking := watching and (one == herd.animals[0] or one.head_up > 0.0 or herd.mode == Mode.SETTLE or fposmod(Time.get_ticks_msec() * 0.001 + one.offset.x * 3.0, 7.0) < 3.5)
	node.grazing = herd.mode == Mode.GRAZE and still and one.head_up <= 0.0 or watching and not looking
	node.alert = looking and still
	node.look_at_point = herd.threat + Vector3.UP * 1.0 if looking and herd.threat.is_finite() else Vector3.INF
	var fleeing := herd.mode == Mode.FLEE
	node.flagging = fleeing and herd.kind == Kind.DEER
	node.fleeing = fleeing and one.velocity.length() > 5.0
	node.pronking = fleeing and herd.kind == Kind.DEER and herd.fled < 0.9 and not one.young


## The herds' animals, for tests and tools.
func animals() -> Array[Deer]:
	var all: Array[Deer] = []
	for herd in herds:
		for one in herd.animals:
			all.append(one.node)
	return all

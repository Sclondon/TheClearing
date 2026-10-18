class_name MazeWolf
extends MazeEnemy
## A grey wolf, one of a pack of four to six: an endurance hunter. It is drawn
## and moved by Wolf (creatures/wolf/wolf.gd); this is what it thinks.
##
## THE PACK. A breeding pair (the first two: rank 0, tails high) and their
## grown and young ones. The pack has a den (`den`: where its leader was put, a
## dead end) and a territory round it (`territory_steps` by the passages). The
## leader chooses where they go; the rest come after it in file, each on the
## heels of the one before, at the trot (`patrol_speed`), stopping now and then
## to sniff. By day they mostly lie up at the den (dozing, sitting, a young one
## play-bowing to another and romping off), and go out on patrol now and then;
## by night they patrol (DayCycle, when the world has one).
##
## THE HOWL. At dusk the pack goes home to the den and howls together, each its
## own howl (Wolf: glides of a nearly pure tone, made in code), a chorus that
## carries far through the maze; through the night they howl again now and
## then, going back to the den for it. A pack that hears another's chorus (within
## `answer_range`) answers it from where it is. And starting a hunt, the leader
## and its mate give a short rallying howl: the warning that they are coming.
##
## THE HUNT is endurance, not speed. Seeing someone, a wolf stops and stares (a
## soft woof), the pack is told (`alert_range`), the rally goes up, and they
## come on at a trot (`hunt_speed`: slower than a run) and keep coming: they
## remember where you are for a long while (`memory`), and when they fall far
## behind they lope (`catch_up_speed`) until they are close again. The breeding
## pair come straight on; the others spread out down the side passages round
## you, to be where you are going (they cover the ways out of where you are).
## They close in (CLOSE: low and stiff, hackles up, snarling, a growl: the
## warning, at least `close_time`) only if you slow down or stop, if you are in a
## dead end or cornered, if the chase has worn on long enough (`wear_time`), or
## you are alone with one right by you; then the nearest that has a straight run
## at you bursts at you at a gallop (`rush_speed`, faster than a sprint, but only
## for `rush_time`) and springs and grabs (the dog's lunge: `caught` only if its
## jaws close on you). A miss, and the pack falls back to the trot a while.
## FAIR: run (not stop) and they cannot close; sprint and a burst cannot reach
## you; get up high (`reach_up`: ivy, a terrace, a vine) and they pace under you
## and in the end give up; put fire between you (`fears_fire`: a torch, a
## campfire) and they hold off at the edge of its light; reach the clearing and
## they will not follow. Two or more together (`group_range`) they will not close
## on: they hang back, waiting for a straggler, and turn to anyone alone.
##
## THE OTHERS (Ecology): a big pack meat-eater, it hunts what is smaller than it
## and the big plant-eaters (deer, elk, boar) together: one that goes after prey
## brings the pack (`alert_range`), at a lope; what it catches it kills. It runs
## from anything bigger that would eat it.
##
## `MazeWolf.pack_of(count, seed)` makes a pack (each a little different: which
## model, its colour, its size, its rank); the pack is told apart by `pack_id`.
## As a puppet it follows the host's news; its lunges and howls come as counts
## in its flag, and its woofs and growls with its changes of mode.

enum Mode { ROAM, REST, SNIFF, STARE, HOWL, PLAY, HUNT, CLOSE, RUSH, LUNGE, HOLD, FLEE }

## How much bigger than its model it is drawn.
const SCALE := Wolf.SCALE
## The last pack chorus heard, for others to answer: [pack_id, where, when (msec)].
static var last_chorus: Array = []

@export var patrol_speed := 2.7
## Hunting: a trot, a little slower than a run; a lope to catch up when far behind.
@export var hunt_speed := 3.4
@export var catch_up_speed := 5.4
## The burst at the end of a hunt: faster than a sprint, for only so long.
@export var rush_speed := 7.4
@export var rush_time := 1.6
@export var flee_speed := 6.5
@export var acceleration := 11.0
@export var turn_rate := 7.0
## How far its territory reaches from its den, steps by the passages.
@export var territory_steps := 9
## How near one must be for it to close in, to burst, and to spring.
@export var close_range := 12.0
@export var burst_range := 7.0
@export var lunge_range := 2.6
## Closing in lasts at least this long before any of them bursts (the warning).
@export var close_time := 1.5
## Hunted this long without getting away, the quarry is worn out: they close in on them running.
@export var wear_time := 50.0
## Anyone else this near the quarry: they are together, and are not closed on.
@export var group_range := 9.0
## Higher than this over it, someone is out of its reach.
@export var reach_up := 1.9
## How far off another pack's chorus is answered.
@export var answer_range := 400.0
@export var pose_range := 80.0
@export var gravity := 24.0
## How it looks (set before it goes in; `pack_of` sets them).
@export var variant := 0
@export var coat_tint := Color.WHITE
@export var size := SCALE
@export_range(0, 2) var rank := 1
## Which pack it is in (the same for all of a pack, on every machine).
@export var pack_id := 0
## Its pack's den (INF: where it is put).
@export var den := Vector3.INF

var mode := Mode.ROAM
var facing_yaw := 0.0
var wolf: Wolf

var _radius := 0.3
var _timer := 0.0
var _point := Vector3.INF
var _goal := Vector3.INF
var _mates: Array[MazeWolf] = []
var _mates_in := 0.0
var _day: Node
var _day_looked := false
var _was_dusk := false
var _chorus_in := 60.0
var _sung := false
var _answer_at := INF
var _heard_chorus := 0
var _rest_pose := 0
var _patrol_in := 0.0
var _patrol_left := 60.0
var _flank := Vector3.INF
var _flank_in := 0.0
var _hunt_time := 0.0
var _slow_time := 0.0
var _close_left := 0.0
var _cool := 0.0
var _rush_left := 0.0
var _hold_left := 0.0
var _hold_at := Vector3.INF
var _home_left := 0.0
var _was_after: Node3D
var _bit := false
var _lunges := 0
var _howls := 0
var _rallies := 0
var _prev_pos := Vector3.ZERO
var _curr_pos := Vector3.ZERO
var _far := false
var _far_check := 0.0
var _heard_flagged := false


## A pack of `count` (4 to 6 in the maze), ready to be placed: the breeding pair
## first (a big male, his mate), then grown ones, then young ones.
static func pack_of(count: int, seed_value := 0) -> Array[MazeWolf]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tints := [Color(0.94, 0.94, 0.95), Color.WHITE, Color(1.04, 1.01, 0.96), Color(0.86, 0.86, 0.88), Color(1.06, 1.04, 1.0), Color(0.98, 0.97, 0.97)]
	var made: Array[MazeWolf] = []
	var id := absi(seed_value) % 1000000 + 1
	for i in count:
		var one := MazeWolf.new()
		one.rank = 0 if i < 2 else (1 if i < 4 else 2)
		one.variant = 1 if i == 0 else (0 if i == 1 else rng.randi_range(0, 1))
		one.coat_tint = tints[(i + rng.randi_range(0, 5)) % tints.size()] if i > 0 else tints[0]
		var grown: float = [1.06, 0.97][i] if i < 2 else (rng.randf_range(0.93, 1.02) if i < 4 else rng.randf_range(0.84, 0.9))
		one.size = SCALE * grown
		one.pack_id = id
		made.append(one)
	return made


func _init() -> void:
	sight_range = 46.0
	hear_range = 12.0
	memory = 40.0
	alert_range = 70.0
	pack = &"wolves"
	look_every = 0.25
	fears_fire = true


func _ready() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4
	floor_snap_length = 0.4
	var shape := CapsuleShape3D.new()
	_radius = 0.24 * size
	shape.radius = _radius
	shape.height = 0.75 * size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	add_child(collider)
	wolf = Wolf.new()
	wolf.variant = variant
	wolf.rank = rank
	wolf.coat_tint = coat_tint
	wolf.low_poly = Settings.low_poly
	wolf.scale = Vector3.ONE * size
	wolf.lunge_reach = Vector2(1.0, 2.4)
	add_child(wolf)
	wolf.top_level = true
	facing_yaw = rotation.y
	_prev_pos = global_position
	_curr_pos = global_position
	wolf.global_position = global_position
	wolf.rotation = Vector3(0.0, facing_yaw, 0.0)
	wolf.settle()
	if not den.is_finite():
		den = global_position
	_rest_pose = _rng.randi_range(0, 2)
	_chorus_in = _rng.randf_range(40.0, 90.0)
	_patrol_in = _rng.randf_range(20.0, 50.0)
	_patrol_left = _rng.randf_range(30.0, 90.0)
	spotted.connect(_on_spotted)
	add_to_group(&"pursuers")


# --- The pack ---

## The others of its pack (not itself), in the order they were put in.
func pack_mates() -> Array[MazeWolf]:
	if not is_inside_tree():
		return []
	if _mates_in > 0.0 and _mates.all(func(m: MazeWolf) -> bool: return is_instance_valid(m)):
		return _mates
	_mates_in = 2.0
	_mates.clear()
	for other: Node in get_tree().get_nodes_in_group(&"wolves"):
		if other != self and other is MazeWolf and (other as MazeWolf).pack_id == pack_id:
			_mates.append(other)
	_mates.sort_custom(func(a: Node, b: Node) -> bool: return a.get_index() < b.get_index())
	return _mates


## Its leader: the first of the pack in the scene (who chooses where they go), alive.
func leader() -> MazeWolf:
	var first: MazeWolf = self
	for mate in pack_mates():
		if not mate.dead and mate.get_index() < first.get_index():
			first = mate
	return first


## The one it follows in file: the one put in just before it (or the leader).
func _ahead_of_me() -> MazeWolf:
	var before: MazeWolf = null
	for mate in pack_mates():
		if mate.dead or mate.get_index() > get_index():
			continue
		if before == null or mate.get_index() > before.get_index():
			before = mate
	return before


func _pack_busy() -> bool:
	for one: MazeWolf in [self] + pack_mates():
		if one.mode in [Mode.HUNT, Mode.CLOSE, Mode.RUSH, Mode.LUNGE, Mode.STARE]:
			return true
	return false


# --- Day and night ---

## 0 by day, 1 at dusk, 2 at night; -1 when there is no day cycle.
func _time_of_day() -> int:
	if not _day_looked:
		_day_looked = true
		var at: Node = get_parent()
		while at:
			var found: Variant = at.get(&"day")
			if found is Node:
				_day = found
				break
			at = at.get_parent()
	if _day == null or not is_instance_valid(_day):
		return -1
	var hour := float(_day.get(&"hour"))
	if hour >= DayCycle.SUNSET - 0.8 and hour < DayCycle.SUNSET + 1.2:
		return 1
	if hour >= DayCycle.SUNSET + 1.2 or hour < DayCycle.DAWN:
		return 2
	return 0


# --- Who it is after ---

func _too_high(who: Node3D) -> bool:
	var ground := maze.ground_height(who.global_position) if maze else global_position.y
	return who.global_position.y - maxf(ground, global_position.y) > reach_up


## How many others are with `who` (other players near them).
func _company(who: Node3D) -> int:
	var with := 0
	for player: Node3D in players():
		if player != who and is_instance_valid(player) and player.is_inside_tree() and not player.get(&"escaped") == true \
				and player.global_position.distance_to(who.global_position) < group_range:
			with += 1
	return with


func _on_spotted(player: Node3D) -> void:
	if puppet or dead:
		return
	if mode in [Mode.ROAM, Mode.REST, Mode.SNIFF, Mode.HOWL, Mode.PLAY]:
		_stare(player)


## Told by its pack that `player` is about.
func alerted(player: Node3D, from: Vector3) -> void:
	var was := hunting()
	super(player, from)
	if not was and hunting() and mode in [Mode.ROAM, Mode.REST, Mode.SNIFF, Mode.HOWL, Mode.PLAY]:
		_stare(player)
		_timer = _rng.randf_range(0.5, 1.2)


func _stare(player: Node3D) -> void:
	mode = Mode.STARE
	_timer = _rng.randf_range(1.0, 1.6)
	_point = player.global_position + Vector3.UP
	wolf.hush()
	wolf.woof()
	if _hunt_time <= 0.0:
		_hunt_time = 0.01


## Where it is making for, out of sight too (roam_unseen): its pack's way about its territory.
func goal() -> Vector3:
	if (threat and is_instance_valid(threat) and not threat.dead) or _eating > 0.0 or hunting():
		return super()
	var lead := leader()
	if lead != self:
		return lead.global_position
	if not _goal.is_finite():
		_pick_patrol()
	return _goal


func _pick_patrol() -> void:
	var home := maze.cell_at(den)
	if _home_left > 0.0 or not nav.allowed(home):
		_goal = den if nav.allowed(home) else global_position
		return
	_goal = nav.point(nav.wander(home, _rng, 2, territory_steps))


# --- Each step ---

func _physics_process(delta: float) -> void:
	if puppet:
		_follow(delta)
		_prev_pos = _curr_pos
		_curr_pos = global_position
		return
	if maze == null or dead:
		return
	WolfVoice.bake_some()
	var after_before := quarry if hunting() else null
	_sense(delta)
	var grounded := is_on_floor()
	_timer -= delta
	_mates_in -= delta
	_cool -= delta
	_home_left -= delta
	_chorus_in -= delta
	var lead := leader()
	# (the pack keeps to one quarry: the leader's)
	if not hunting() and lead != self and lead.hunting() and not lead.quarry is MazeEnemy:
		alerted(lead.quarry, lead.global_position)
	# Lost them to fire, or to a height: it holds off where they are, a while.
	if after_before and not (after_before is MazeEnemy) and is_instance_valid(after_before) and not hunting() \
			and mode in [Mode.HUNT, Mode.CLOSE, Mode.STARE] and FireWard.near(get_tree(), after_before.global_position):
		_hold(after_before)
	var who := quarry if hunting() else null
	# (after an animal, the pack goes at once: no stare, no rally)
	if who is MazeEnemy and mode in [Mode.ROAM, Mode.REST, Mode.SNIFF, Mode.HOWL, Mode.PLAY, Mode.STARE]:
		mode = Mode.HUNT
		wolf.hush()
	if who and not (who is MazeEnemy) and _too_high(who) and mode not in [Mode.HOLD, Mode.FLEE]:
		_hold(who)
	if threat and is_instance_valid(threat) and not threat.dead and mode not in [Mode.RUSH, Mode.LUNGE]:
		mode = Mode.FLEE
	elif mode == Mode.FLEE:
		mode = Mode.ROAM
	_reckon_hunt(who, delta)
	chasing = mode in [Mode.HUNT, Mode.CLOSE, Mode.RUSH, Mode.LUNGE]
	var wish := Vector3.ZERO
	var speed := 0.0
	if who and mode not in [Mode.HOLD]:
		_point = who.global_position + Vector3.UP * 0.9
	elif mode not in [Mode.HOLD, Mode.STARE]:
		_point = Vector3.INF
	match mode:
		Mode.LUNGE:
			var push := wolf.lunge_push()
			velocity.x = push.x
			velocity.z = push.z
			if not _bit:
				for player: Node3D in players():
					if huntable(player) and wolf.bite_hits(player.global_position + Vector3.UP * 0.7, 0.65):
						_bit = true
						_catch(player)
						_home_left = 60.0
						for mate in pack_mates():
							mate._home_left = 60.0
						break
			if wolf.lunge_stage() == Dog.Lunge.NONE:
				_after_burst()
			_move(delta, grounded)
			return
		Mode.RUSH:
			_rush_left -= delta
			if who == null or _rush_left <= 0.0:
				_after_burst()
			else:
				var to := who.global_position - global_position
				to.y = 0.0
				wish = to if nav.line_free(global_position, who.global_position, _radius * 0.8) else way(_radius)
				speed = rush_speed
				if to.length() < lunge_range and grounded:
					_spring(who)
					return
		Mode.FLEE:
			wish = way(_radius)
			speed = flee_speed
		Mode.STARE:
			if _timer <= 0.0:
				if who:
					mode = Mode.HUNT
					# (the start of a hunt: the leader and its mate rally)
					if rank == 0 and not (who is MazeEnemy):
						_rally()
				else:
					mode = Mode.ROAM
		Mode.HOLD:
			_hold_left -= delta
			var to := _hold_at - global_position
			to.y = 0.0
			var off := to.length()
			# (pacing at the edge of the firelight, or under where they climbed)
			var keep := 9.0 if _hold_at.y < global_position.y + reach_up else 1.5
			if off > keep + 2.0:
				wish = _way_toward(_hold_at)
				speed = hunt_speed
			elif off < keep - 1.0:
				wish = -to
				speed = 1.6
			else:
				wish = to.cross(Vector3.UP).normalized() * (1.0 if get_index() % 2 == 0 else -1.0)
				speed = 1.2
			_point = _hold_at + Vector3.UP * 0.5
			if _timer <= 0.0:
				_timer = _rng.randf_range(2.5, 5.0)
				wolf.growl()
			if _hold_left <= 0.0:
				_give_up()
		Mode.HUNT, Mode.CLOSE:
			if who == null:
				mode = Mode.ROAM
			else:
				var hunted := _hunt(who, delta, grounded)
				if hunted.is_empty():
					return
				wish = hunted[0]
				speed = hunted[1]
		Mode.HOWL:
			if _timer <= 0.0 and not wolf.in_howl():
				mode = Mode.REST if _time_of_day() == 0 else Mode.ROAM
				_timer = _rng.randf_range(3.0, 8.0)
		Mode.PLAY:
			var to := _goal - global_position
			to.y = 0.0
			wish = to if to.length() > 0.8 else Vector3.ZERO
			speed = 4.2
			if _timer <= 0.0 or to.length() <= 0.8:
				mode = Mode.REST
				_goal = Vector3.INF
				_timer = _rng.randf_range(6.0, 14.0)
		Mode.REST:
			var to := den - global_position
			to.y = 0.0
			if to.length() > 6.0 + get_index() % 3 * 1.5:
				wish = _way_toward(den)
				speed = patrol_speed
			_rest_time(delta)
		Mode.SNIFF:
			if _timer <= 0.0:
				mode = Mode.ROAM
				_timer = _rng.randf_range(5.0, 12.0)
		Mode.ROAM:
			var roamed := _roam(delta)
			wish = roamed[0]
			speed = roamed[1]
	_steer_and_move(wish, speed, delta, grounded)


func _steer_and_move(wish: Vector3, speed: float, delta: float, grounded: bool) -> void:
	var push := _apart(_radius * 1.8)
	if wish.length() > 0.01:
		wish = wish.normalized()
		if push != Vector3.ZERO:
			wish = (wish + push * 0.6).normalized()
	elif push != Vector3.ZERO and mode not in [Mode.HOWL, Mode.REST]:
		wish = push
		speed = maxf(speed, 1.0)
	var current := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * speed, acceleration * delta)
	velocity.x = current.x
	velocity.z = current.z
	_move(delta, grounded)


## How the hunt stands: how long it has gone on, and how long the quarry has been slow.
func _reckon_hunt(who: Node3D, delta: float) -> void:
	if who == null:
		_hunt_time = 0.0
		_slow_time = 0.0
		return
	_hunt_time += delta
	if _velocity_of(who).length() < 1.6:
		_slow_time += delta
	else:
		_slow_time = maxf(_slow_time - delta * 2.0, 0.0)


## The hunt (HUNT and CLOSE): [the way to go, how fast], or [] when it has sprung.
func _hunt(who: Node3D, delta: float, grounded: bool) -> Array:
	var to := who.global_position - global_position
	to.y = 0.0
	var gap := to.length()
	# After an animal: the whole pack at a lope, straight for it.
	if who is MazeEnemy:
		mode = Mode.HUNT
		return [way(_radius), catch_up_speed]
	var together := _company(who) > 0
	if together:
		_find_straggler(who)
	var pressing := not together and _cool <= 0.0 and gap < close_range and (
			_slow_time > 0.6 or _cornered(who) or _hunt_time > wear_time or (gap < 4.5 and _company(who) == 0 and _velocity_of(who).length() < 3.0))
	if mode == Mode.HUNT and pressing:
		_close_in()
	elif mode == Mode.CLOSE and not pressing and _close_left < close_time - 0.6:
		# (they ran: back to the trot)
		mode = Mode.HUNT
	if mode == Mode.CLOSE:
		_close_left -= delta
		# Low and stiff, round them, a few metres off; the one with a straight run bursts.
		var slot := Basis(Vector3.UP, (get_index() % 5 - 2) * 0.8) * (-to.normalized() if gap > 0.1 else Vector3.FORWARD)
		var spot := who.global_position + slot * 4.5
		var at := _way_toward(spot)
		var near := (spot - global_position).length()
		var keep_up := _velocity_of(who).length()
		if _close_left <= 0.0 and gap < burst_range and grounded and nav.line_free(global_position, who.global_position, _radius * 0.8) and _burster(who) == self:
			mode = Mode.RUSH
			_rush_left = rush_time
			return [to, rush_speed]
		return [at if near > 0.6 else Vector3.ZERO, maxf(keep_up * 1.05, 1.4 if near > 0.6 else 0.0)]
	# The trot: the pair straight on, the others for where they are going.
	var target := who.global_position
	if rank > 0 and gap > 6.0 and gap < 45.0:
		_flank_in -= delta
		if _flank_in <= 0.0 or not _flank.is_finite():
			_flank_in = 1.5
			_flank = _flank_point(who)
		if _flank.is_finite() and global_position.distance_to(_flank) > 3.0:
			target = _flank
	var speed := hunt_speed
	if gap > 26.0:
		speed = catch_up_speed
	if together and gap < 15.0:
		# (wary of more than one: hang back, watching)
		return [-to if gap < 12.0 else Vector3.ZERO, 1.5]
	return [_way_toward(target), speed]


## Whether `who` is cornered: in a dead end, or with wolves at every way out of where they are.
func _cornered(who: Node3D) -> bool:
	var cell := maze.cell_at(who.global_position)
	if nav.dead_end(cell):
		return true
	var ways := 0
	var held := 0
	for step: Vector2i in Maze.STEPS:
		if maze.blocked(cell, step) or not nav.allowed(cell + step):
			continue
		ways += 1
		var out := nav.point(cell + step)
		for one: MazeWolf in [self] + pack_mates():
			if not one.dead and one.global_position.distance_to(out) < Maze.CELL * 0.6:
				held += 1
				break
	return ways > 0 and held >= ways


## A way out of where `who` is, for a flanker to make for: the one ahead of
## them, or (each flanker its own) another side of them.
func _flank_point(who: Node3D) -> Vector3:
	var cell := maze.cell_at(who.global_position)
	var moving := _velocity_of(who)
	var ways: Array[Vector2i] = []
	for step: Vector2i in Maze.STEPS:
		if not maze.blocked(cell, step) and nav.allowed(cell + step):
			ways.append(step)
	if ways.is_empty():
		return Vector3.INF
	# (the way they are going first, then the rest, but not the way we came)
	var from := (global_position - who.global_position).normalized()
	ways.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := Vector3(a.x, 0.0, a.y).dot(moving) - Vector3(a.x, 0.0, a.y).dot(from) * 2.0
		var db := Vector3(b.x, 0.0, b.y).dot(moving) - Vector3(b.x, 0.0, b.y).dot(from) * 2.0
		return da > db)
	var pick: Vector2i = ways[(get_index() + rank) % mini(ways.size(), 2)]
	var beyond := cell + pick
	if not maze.blocked(beyond, pick) and nav.allowed(beyond + pick):
		beyond += pick
	return nav.point(beyond)


## Among its pack closing in: the one to burst (the nearest with a straight run).
func _burster(who: Node3D) -> MazeWolf:
	var best: MazeWolf = null
	var nearest := INF
	for one: MazeWolf in [self] + pack_mates():
		if one.dead or one.mode != Mode.CLOSE or one._close_left > 0.0:
			continue
		var d := one.global_position.distance_to(who.global_position)
		if d < nearest:
			nearest = d
			best = one
	return best


## Someone alone is easier: anyone hunted with company, it turns to another it sees alone.
func _find_straggler(who: Node3D) -> void:
	if leader() != self or _timer > 0.0:
		return
	_timer = 1.0
	var eye := global_position + Vector3.UP
	for player: Node3D in players():
		if player == who or not huntable(player) or _company(player) > 0:
			continue
		if nav.sees(eye, player.global_position + Vector3.UP, sight_range) or eye.distance_to(player.global_position) < hear_range * 2.0:
			notice(player)
			for mate in pack_mates():
				mate.quarry = player
				mate._forget = memory
			return


func _close_in() -> void:
	# (the whole pack closes together, and growls: the warning)
	for one: MazeWolf in [self] + pack_mates():
		if one.mode == Mode.HUNT and one.quarry == quarry:
			one.mode = Mode.CLOSE
			one._close_left = close_time + one._rng.randf_range(0.0, 0.6)
			if one == self or one.rank == 0:
				one.wolf.growl()


func _spring(who: Node3D) -> void:
	mode = Mode.LUNGE
	_bit = false
	_lunges += 1
	var them := _velocity_of(who)
	_point = who.global_position + Vector3(them.x, 0.0, them.z) * (Dog.GATHER_TIME + Dog.SPRING_TIME * 0.8)
	velocity.x = 0.0
	velocity.z = 0.0
	wolf.lunge(_point)


## Hit or miss, the pack falls back to the trot, and does not close again for a while.
func _after_burst() -> void:
	for one: MazeWolf in [self] + pack_mates():
		one._cool = maxf(one._cool, 6.0)
		if one.mode in [Mode.CLOSE, Mode.RUSH] or one == self:
			one.mode = Mode.HUNT if one.hunting() else Mode.ROAM
	if wolf.lunge_stage() == Dog.Lunge.NONE and not _bit:
		wolf.shake()


func _hold(who: Node3D) -> void:
	mode = Mode.HOLD
	_hold_at = who.global_position
	_hold_left = _rng.randf_range(10.0, 16.0)
	_timer = _rng.randf_range(0.3, 1.5)
	_last_seen = Vector3.INF
	# (up out of reach: it lets them alone while it waits, and after)
	if _too_high(who):
		_spared[who] = _hold_left + 12.0
		quarry = null
		_forget = 0.0


func _give_up() -> void:
	mode = Mode.ROAM
	_hold_at = Vector3.INF
	_home_left = 40.0
	_goal = Vector3.INF


func _rally() -> void:
	_rallies += 1
	wolf.rally(get_index() % Wolf.RALLIES)


# --- Not hunting ---

func _roam(delta: float) -> Array:
	var lead := leader()
	var tod := _time_of_day()
	if lead == self:
		_pack_life(tod)
		if mode != Mode.ROAM:
			return [Vector3.ZERO, 0.0]
		if not _goal.is_finite() or Vector2(_goal.x - global_position.x, _goal.z - global_position.z).length() < 2.5:
			_goal = Vector3.INF
			_pick_patrol()
			# (at a crossing it stops and sniffs now and then)
			if _rng.randf() < 0.3:
				_sniff()
				return [Vector3.ZERO, 0.0]
		return [_way_toward(_goal), patrol_speed]
	# In file: on the heels of the one before.
	if lead.mode == Mode.REST and mode == Mode.ROAM:
		mode = Mode.REST
		_timer = _rng.randf_range(2.0, 6.0)
	var ahead := _ahead_of_me()
	if ahead == null:
		return [Vector3.ZERO, 0.0]
	var spot := ahead.global_position - Basis(Vector3.UP, ahead.facing_yaw) * Vector3(0.0, 0.0, 2.4)
	var to := spot - global_position
	to.y = 0.0
	if ahead.mode == Mode.SNIFF and to.length() < 3.0 and mode == Mode.ROAM and _rng.randf() < delta * 2.0:
		_sniff()
	if to.length() < 0.8:
		return [Vector3.ZERO, 0.0]
	return [_way_toward(spot), patrol_speed * (1.25 if to.length() > 5.0 else 1.0)]


## The leader's day: out on patrol by night, and by day (or with no day at all)
## by turns out on patrol and lying up at the den; home to the den at dusk for
## the chorus, and a chorus now and then through the night; another pack's
## chorus heard, answered from where it is.
func _pack_life(tod: int) -> void:
	var dusk := tod == 1
	if dusk and not _was_dusk:
		_sung = false
	_was_dusk = dusk
	var home := global_position.distance_to(den) < 8.0
	if (dusk and not _sung) or (tod == 2 and _chorus_in <= 0.0):
		_goal = den
		if home:
			_sung = true
			_chorus()
		return
	if not last_chorus.is_empty() and int(last_chorus[0]) != pack_id and int(last_chorus[2]) != _heard_chorus:
		_heard_chorus = int(last_chorus[2])
		if (last_chorus[1] as Vector3).distance_to(global_position) < answer_range:
			_answer_at = Time.get_ticks_msec() + _rng.randf_range(3000.0, 7000.0)
	if Time.get_ticks_msec() > _answer_at:
		_answer_at = INF
		_chorus(false)
		return
	if tod == 0 or tod == -1:
		_patrol_left -= get_physics_process_delta_time()
		if _patrol_left <= 0.0:
			_goal = den
			if home:
				_rest_all()


## The whole pack lies up at the den a while.
func _rest_all() -> void:
	_patrol_in = _rng.randf_range(35.0, 75.0)
	_goal = Vector3.INF
	for one: MazeWolf in [self] + pack_mates():
		if one.mode in [Mode.ROAM, Mode.SNIFF]:
			one.mode = Mode.REST
			one._timer = one._rng.randf_range(4.0, 12.0)


## Lying up at the den: dozing, sitting; a young one play-bows to another and romps off.
func _rest_time(delta: float) -> void:
	var lead := leader()
	if lead == self:
		_patrol_in -= delta
		var tod := _time_of_day()
		if _patrol_in <= 0.0 or tod == 2 or (tod == 1 and not _sung):
			_patrol_left = _rng.randf_range(50.0, 110.0)
			_goal = Vector3.INF
			for one: MazeWolf in [self] + pack_mates():
				if one.mode in [Mode.REST, Mode.PLAY]:
					one.mode = Mode.ROAM
			return
	elif lead.mode not in [Mode.REST, Mode.HOWL, Mode.PLAY]:
		mode = Mode.ROAM
		return
	if rank == 2 and _timer <= 0.0:
		_timer = _rng.randf_range(10.0, 25.0)
		if _rng.randf() < 0.6:
			mode = Mode.PLAY
			var round_about := _rng.randf_range(0.0, TAU)
			_goal = den + Vector3(cos(round_about), 0.0, sin(round_about)) * 5.0
			_bow_then_romp()


func _bow_then_romp() -> void:
	# (a play-bow first, standing where it is, then the romp)
	wolf.bowing = true
	_timer = 5.0
	var goal_was := _goal
	_goal = global_position
	get_tree().create_timer(1.4, false).timeout.connect(func() -> void:
		if is_instance_valid(wolf):
			wolf.bowing = false
		if mode == Mode.PLAY:
			_goal = goal_was)


func _sniff() -> void:
	mode = Mode.SNIFF
	_timer = _rng.randf_range(1.5, 3.0)


## The pack howls together (from the den, or `answering` from where it is).
func _chorus(at_den := true) -> void:
	_chorus_in = _rng.randf_range(70.0, 140.0)
	last_chorus = [pack_id, global_position, Time.get_ticks_msec()]
	_heard_chorus = int(last_chorus[2])
	var ring: Array = [self] + pack_mates()
	for k in ring.size():
		var one := ring[k] as MazeWolf
		if one.dead or one.mode not in [Mode.ROAM, Mode.REST, Mode.SNIFF, Mode.PLAY]:
			continue
		one._chorus_in = _chorus_in
		one._howl_after(_rng.randf_range(0.0, 0.6) + 0.9 * k)
	if not at_den:
		_goal = Vector3.INF


func _howl_after(seconds: float) -> void:
	mode = Mode.HOWL
	_timer = seconds + 2.0
	velocity.x = 0.0
	velocity.z = 0.0
	get_tree().create_timer(seconds, false).timeout.connect(func() -> void:
		if is_instance_valid(self) and mode == Mode.HOWL:
			_howls += 1
			_howl_now())


func _howl_now() -> void:
	wolf.bowing = false
	wolf.howl_now((get_index() + _howls) % Wolf.HOWLS, rank == 2 or (get_index() + _howls) % 3 == 0)


# --- Moving ---

func _way_toward(point: Vector3) -> Vector3:
	var to := nav.waypoint(global_position, point, MazeNav.clearance_for(_radius)) - global_position
	to.y = 0.0
	return to


func _move(delta: float, grounded: bool) -> void:
	if not grounded:
		velocity.y -= gravity * delta
	move_and_slide()
	_prev_pos = _curr_pos
	_curr_pos = global_position


static func _velocity_of(who: Node3D) -> Vector3:
	var them: Variant = who.get(&"velocity")
	return Vector3(them.x, 0.0, them.z) if them is Vector3 else Vector3.ZERO


# --- What it looks like ---

func _process(delta: float) -> void:
	_far_check -= delta
	if _far_check <= 0.0:
		_far_check = 0.5
		var near := nearest_player(global_position)
		var far := near != null and near.global_position.distance_to(global_position) > pose_range
		if far != _far:
			_far = far
			# (far off it is not drawn or posed, but its voice still carries)
			wolf.visible = not far
			if wolf.rig:
				wolf.rig.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
			if not far:
				wolf.settle()
	var heading := Vector3(velocity.x, 0.0, velocity.z)
	if puppet:
		facing_yaw = lerp_angle(facing_yaw, _heard_yaw, 1.0 - exp(-10.0 * delta))
	elif mode == Mode.LUNGE:
		var way_now := wolf.lunge_way()
		facing_yaw = lerp_angle(facing_yaw, atan2(way_now.x, way_now.z), 1.0 - exp(-14.0 * delta))
	elif heading.length_squared() > 0.09:
		facing_yaw = lerp_angle(facing_yaw, atan2(heading.x, heading.z), 1.0 - exp(-turn_rate * delta))
	elif _point.is_finite():
		var to := _point - global_position
		facing_yaw = lerp_angle(facing_yaw, atan2(to.x, to.z), 1.0 - exp(-4.0 * delta))
	wolf.global_position = _prev_pos.lerp(_curr_pos, Engine.get_physics_interpolation_fraction())
	wolf.rotation = Vector3(0.0, facing_yaw, 0.0)
	if _far:
		return
	wolf.grounded = is_on_floor() or puppet
	wolf.tracking = mode == Mode.SNIFF
	wolf.hunting = mode in [Mode.HUNT, Mode.FLEE] and heading.length() > 1.0
	wolf.stalking = mode in [Mode.CLOSE, Mode.HOLD]
	wolf.snarling = mode in [Mode.CLOSE, Mode.RUSH, Mode.LUNGE, Mode.HOLD]
	wolf.sitting = mode == Mode.REST and _rest_pose == 1 and heading.length() < 0.3
	wolf.lying = mode == Mode.REST and _rest_pose != 1 and heading.length() < 0.3
	if mode != Mode.PLAY:
		wolf.bowing = false
	var near_quarry := _point.is_finite() and _point.distance_to(global_position) < 25.0
	wolf.look_at_point = _point if mode in [Mode.STARE, Mode.CLOSE, Mode.HOLD] or (mode == Mode.HUNT and near_quarry) else Vector3.INF


# --- Being run by someone else ---

func yaw() -> float:
	return facing_yaw


func net_state() -> int:
	return mode


## Lunges (bits 0-2), howls (3-5) and rallies (6-7), as counts.
func net_flag() -> int:
	return (_lunges & 0x07) | ((_howls & 0x07) << 3) | ((_rallies & 0x03) << 6)


func net_point() -> Vector3:
	return _point


func hear(at: Vector3, moving: Vector3, facing: float, state: int, flag := 0, point := Vector3.ZERO) -> void:
	super(at, moving, facing, state, flag, point)
	var was := mode
	mode = state as Mode
	chasing = mode in [Mode.HUNT, Mode.CLOSE, Mode.RUSH, Mode.LUNGE]
	_point = point
	var lunges := flag & 0x07
	var howls := (flag >> 3) & 0x07
	var rallies := (flag >> 6) & 0x03
	if not _heard_flagged:
		_heard_flagged = true
	elif wolf:
		if lunges != (_lunges & 0x07) and point.is_finite():
			wolf.lunge(point)
		if howls != (_howls & 0x07):
			_howls = howls
			_howl_now()
		if rallies != (_rallies & 0x03):
			wolf.rally(get_index() % Wolf.RALLIES)
		if mode == Mode.STARE and was != Mode.STARE:
			wolf.woof()
		if mode == Mode.CLOSE and was != Mode.CLOSE and rank == 0:
			wolf.growl()
		if mode in [Mode.HUNT, Mode.FLEE] and was == Mode.HOWL:
			wolf.hush()
	if mode == Mode.PLAY and was != Mode.PLAY and wolf:
		wolf.bowing = true
		get_tree().create_timer(1.4, false).timeout.connect(func() -> void:
			if is_instance_valid(wolf):
				wolf.bowing = false)
	_lunges = lunges
	_howls = howls
	_rallies = rallies


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	facing_yaw = facing
	_prev_pos = at
	_curr_pos = at
	velocity = Vector3.ZERO
	if wolf:
		wolf.global_position = at
		wolf.settle()


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1 if puppet else 1 | 4

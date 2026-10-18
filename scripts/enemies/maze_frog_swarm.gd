class_name MazeFrogSwarm
extends MazeEnemy
## A swarm of frogs in the maze: dozens of small frogs in a muddy pool in a
## dead end. Someone comes near (heard within `hear_range`, or seen down the
## passages within `sight_range`) and they pour out at them in hopping waves,
## croaking in chorus; those that reach them leap on and cling.
##
## How they look and move is FrogSwarm (creatures/frog/frog_swarm.gd, which
## knows nothing of the maze); this node is the pool, and what they think:
## - Clinging frogs weigh on whoever they are on: the more of them, the
##   slower they go (`slow_most` at as many as catch them), on the machine
##   that plays them.
## - FrogSwarm.catch_count on someone for FrogSwarm.catch_time and they are
##   `caught`. Running hard or jumping shakes them off a few at a time.
## - Getting away: outrun them (they come a little slower than a run), or get
##   up onto something (a terrace, a bridge, the ivy: they cannot hop that
##   high). They give up when they get no nearer, when the one they are after
##   is caught, escapes or goes into the clearing, and hop home; and rest
##   (`rest_time`) before they come out again.
##
## As a puppet (online, not the host) it follows the host's news: whether they
## are out, and who they are after (the nearest player to the point it is
## sent); its frogs then go after them on this machine, but catch nobody.

enum Mode { DORMANT, HUNT, HOME }

## How many frogs.
@export var frog_count := 70
## How much slower someone goes with as many frogs on them as catch them (0..1).
@export var slow_most := 0.6
## Seconds after they go home before they come out again.
@export var rest_time := 6.0

var swarm: FrogSwarm
var mode := Mode.DORMANT

var _rest := 0.0
var _after: Node3D

## How much each player is weighed down, by each swarm: player -> {swarm: share}.
static var _burdens := {}


func _init() -> void:
	sight_range = 22.0
	hear_range = 11.0
	memory = 8.0
	pack = &"frog_swarms"
	look_every = 0.25


func _ready() -> void:
	add_to_group(&"pursuers")
	# Nothing bumps into it: it is a pool, and frogs.
	collision_layer = 0
	collision_mask = 0
	swarm = FrogSwarm.new()
	swarm.name = "Swarm"
	swarm.count = frog_count
	swarm.can_catch = not puppet
	add_child(swarm)
	swarm.caught.connect(_on_caught)
	swarm.went_home.connect(func() -> void: _rest = rest_time)


func _exit_tree() -> void:
	if _after and is_instance_valid(_after):
		_weigh(_after, self, 0.0)


func _physics_process(delta: float) -> void:
	_rest -= delta
	if puppet:
		_follow_news()
	elif maze:
		_sense(delta)
		var after := quarry if hunting() else null
		if swarm.chasing:
			var target := swarm.target
			if target == null or not huntable(target) or (keep_out_of_clearing and maze.in_clearing(maze.cell_at(target.global_position))):
				swarm.recall()
		elif swarm.home() and after and _rest <= 0.0 and not (keep_out_of_clearing and maze.in_clearing(maze.cell_at(after.global_position))):
			swarm.target = after
			swarm.chasing = true
	mode = Mode.HUNT if swarm.chasing else (Mode.DORMANT if swarm.home() else Mode.HOME)
	chasing = mode == Mode.HUNT
	# Those on someone weigh them down (only the player this machine plays).
	var on := swarm.target if mode == Mode.HUNT else null
	if _after and _after != on and is_instance_valid(_after):
		_weigh(_after, self, 0.0)
	_after = on
	if on and on is Player:
		_weigh(on, self, swarm.burden() * slow_most)


func _on_caught(who: Node3D) -> void:
	if not puppet and who and huntable(who):
		_catch(who)


## Slows `player` by the most any swarm on them asks (`share` of their speed
## taken away), and gives them their speed back when none does.
static func _weigh(player: Node3D, by: Node, share: float) -> void:
	if not is_instance_valid(player):
		return
	var of: Dictionary = _burdens.get(player, {})
	if share > 0.0:
		of[by] = share
	else:
		of.erase(by)
	var most := 0.0
	for one: Variant in of.keys():
		if is_instance_valid(one):
			most = maxf(most, of[one])
	if not player.has_meta(&"frog_speeds"):
		if most <= 0.0:
			_burdens.erase(player)
			return
		player.set_meta(&"frog_speeds", [player.get(&"walk_speed"), player.get(&"run_speed"), player.get(&"sprint_speed"), player.get(&"crouch_speed")])
	var base: Array = player.get_meta(&"frog_speeds")
	var keep := 1.0 - most
	player.set(&"walk_speed", base[0] * keep)
	player.set(&"run_speed", base[1] * keep)
	player.set(&"sprint_speed", base[2] * keep)
	player.set(&"crouch_speed", base[3] * keep)
	if most <= 0.0:
		player.remove_meta(&"frog_speeds")
		_burdens.erase(player)
	else:
		_burdens[player] = of


# --- Being run by someone else ---

func net_state() -> int:
	return mode


func net_flag() -> int:
	return mini(swarm.on_target, 255) if swarm else 0


func net_point() -> Vector3:
	return swarm.target.global_position if swarm and swarm.chasing and swarm.target and is_instance_valid(swarm.target) else Vector3.INF


func _follow_news() -> void:
	if not _heard or swarm == null:
		return
	if _heard_state == Mode.HUNT and _heard_extra.is_finite():
		var who := nearest_player(_heard_extra)
		if who:
			swarm.target = who
			swarm.chasing = true
	elif swarm.chasing:
		swarm.recall()


func _put(_at: Vector3, _facing: float) -> void:
	pass


func _puppet_changed() -> void:
	collision_layer = 0
	collision_mask = 0
	if swarm:
		swarm.can_catch = not puppet

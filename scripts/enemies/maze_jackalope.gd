class_name MazeJackalope
extends MazeHare
## The jackalope: a hare with antlers, out of the stories told in the American
## West, real here. One or two in the whole maze. It is drawn by Rabbit as a
## JACKALOPE (a hare's body, greyer, small polished antlers, eyes that give
## back too much light) and thinks as a hare does (MazeHare), but for this:
##
## IT WATCHES. Where a hare would press itself flat and hide, the jackalope
## sits up and stares at whoever has come, its head turning to follow them and
## nothing else of it moving; its nose does not twitch. It lets them come.
## IT TURNS ON THEM. Come within `charge_range` of it (round a corner, up to it
## while it stares), or corner it as it runs, and it grunts, lowers its antlers
## and charges: whoever it reaches is butted off their feet (Player.ragdoll,
## as the boar tosses, but lighter) and gets up a moment later. It does not
## catch anyone: being butted costs a fall, not the way back to the clearing.
## Then it is away, flat out, jinking, as a hare is. Rushed at from further
## off, or with something that would eat it coming, it simply bolts.
##
## Every machine knocks down its own player when the charge (sent as its state)
## reaches them, so a guest is butted where they stand on their own screen.

## How near someone may come before it turns on them (m).
@export var charge_range := 3.4
## How fast it charges (m/s), how long it grunts first and charges at most (s).
@export var charge_speed := 9.5
@export var grunt_time := 0.55
@export var charge_time := 1.1
## How hard a butt knocks someone down (newton-seconds), and how long they lie.
@export var butt_force := 34.0
@export var down_time := 1.5
## Seconds after a charge before it will charge again.
@export var rest_after := 8.0

var _target: Node3D
var _butted := {}
var _rest_left := 0.0
var _cornered := 0.0


func _init() -> void:
	super()
	pack = &"jackalopes"
	wary_range = 26.0
	flush_range = charge_range
	rush_range = 10.0


func variant() -> Rabbit.Variant:
	return Rabbit.Variant.JACKALOPE


func _physics_process(delta: float) -> void:
	_rest_left -= delta
	if not puppet and mode == Mode.BOLT and _danger and not (_danger is MazeEnemy) and _rest_left <= 0.0:
		# (cornered: running, and they are still on it)
		_cornered = _cornered + delta if _danger_far < charge_range * 1.3 and _fled > 2.0 else 0.0
		if _cornered > 0.5:
			_turn_on(_danger)
	super(delta)


## Someone is about: it sits up and stares at them.
func _noticed() -> void:
	mode = Mode.FREEZE
	_calm_for = 0.0


## Too near, rushed, or something that would eat it coming: too near and it
## turns on them; otherwise it bolts.
func _flushed() -> void:
	if _danger and not (_danger is MazeEnemy) and _danger_far < charge_range * size + 0.2 and _rest_left <= 0.0 and huntable(_danger):
		_turn_on(_danger)
	else:
		_bolt()


func _flushed_by(who: Node3D) -> bool:
	if who is MazeEnemy:
		return true
	var to := who.global_position - global_position
	if Vector2(to.x, to.z).length() < charge_range * size:
		return true
	# (watching, it holds its ground as they come; only someone running at it from further off puts it up)
	var them: Variant = who.get(&"velocity")
	var moving: Vector3 = them if them is Vector3 else Vector3.ZERO
	var running := Vector2(moving.x, moving.z).length() > 4.6
	var at_it := Vector2(moving.x, moving.z).normalized().dot(Vector2(-to.x, -to.z).normalized()) > 0.6
	return running and at_it and Vector2(to.x, to.z).length() < rush_range


## It grunts and lowers its antlers at `who`; a moment later it charges.
func _turn_on(who: Node3D) -> void:
	_target = who
	_butted.clear()
	_cornered = 0.0
	mode = Mode.GRUNT
	_mode_left = grunt_time
	_grunts += 1
	if rabbit:
		rabbit.grunt()


func _charging(_delta: float) -> Vector3:
	if _target == null or not is_instance_valid(_target) or not huntable(_target):
		_after_charge()
		return Vector3.ZERO
	var to := _target.global_position - global_position
	to.y = 0.0
	_point = _target.global_position + Vector3.UP * 0.6
	if mode == Mode.GRUNT:
		if _mode_left <= 0.0:
			mode = Mode.CHARGE
			_mode_left = charge_time
		return Vector3.ZERO
	# (the charge: straight at them; reached, or past them, or long enough, and it is away)
	if not _butted.is_empty() or _mode_left <= 0.0 or (to.length() < 0.5):
		_after_charge()
		return Vector3.ZERO
	return to.normalized() * charge_speed


func _after_charge() -> void:
	_rest_left = rest_after
	_target = null
	_bolt()


## The charge reaching this machine's own player knocks them down (here, a
## guest's own screen, or the host's); the host's run of it ends there too.
func _butting(_delta: float) -> void:
	if mode != Mode.CHARGE:
		return
	var me := local_player()
	if me == null or _butted.has(me) or me.is_limp or me.get(&"escaped") == true:
		return
	var to := me.global_position - global_position
	if absf(to.y) > 1.0 or Vector2(to.x, to.z).length() > 0.55 + _radius:
		return
	_butted[me] = true
	var way := Vector3(to.x, 0.0, to.z).normalized() if Vector2(to.x, to.z).length() > 0.01 else Vector3(sin(facing_yaw), 0.0, cos(facing_yaw))
	me.ragdoll((way * 0.85 + Vector3.UP * 0.55).normalized() * butt_force)
	get_tree().create_timer(down_time).timeout.connect(func() -> void:
		if is_instance_valid(me) and me.is_limp:
			me.recover())


func _dress(heading: Vector3) -> void:
	super(heading)
	rabbit.flattened = false
	# (it stares, sat up, instead of hiding)
	rabbit.upright = mode in [Mode.FREEZE, Mode.SETTLE]
	rabbit.alert = mode in [Mode.FREEZE, Mode.SETTLE, Mode.GRUNT]
	rabbit.lowered = mode in [Mode.GRUNT, Mode.CHARGE]
	rabbit.fleeing = mode in [Mode.BOLT, Mode.CHARGE]
	rabbit.look_at_point = _point if mode in [Mode.FREEZE, Mode.SETTLE, Mode.GRUNT, Mode.CHARGE] else Vector3.INF

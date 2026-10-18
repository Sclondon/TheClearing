class_name Apophis
extends MazeEnemy
## Apophis (Apep), the great serpent, from Outside (its scripts/apophis.gd),
## made big enough for the maze and set to hunt its passages.
##
## - HE IS ONE BODY. This node is his head, and what the world stops. Behind it
##   is kept the path the head has taken, and the body is laid along that path:
##   every part of him passes where the head passed, round the same corners,
##   with a side-to-side wave laid over it that stands still on the ground as he
##   slides through it (less of it where the passage is narrow). What he looks
##   like is a model (models/enemies/apophis.glb, made by Outside's
##   tools/build_apophis.py): his head, and one length of his body, which is
##   laid end to end into one tube and bent along `POINTS` places on that path
##   by its shader. Nothing is built each frame but those places. Three draws:
##   body, head, and the knives stuck in him.
## - AT REST he lies stretched along a passage, his head on the ground, until
##   he notices someone (MazeEnemy's senses: a long sight down the passages).
##   Then he rears (`wake_time`) and comes.
## - THE CHASE. His speed is a little more than a run on the straight, less in
##   a turn, so a sprint keeps ahead of him and a stumble does not. He goes by
##   the passages (MazeNav), cutting the corners as close as the walls let him,
##   and straight at whoever he is after once he can see them.
##   When he has lost them for `memory` seconds he goes to where they were last,
##   then prowls the passages slowly, and after `rest_after` seconds of that
##   with nobody about he lies down where he is.
## - THE STRIKE. Only his head catches. Within `strike_distance` he stops,
##   rears back with his mouth open for `strike_warning` seconds, and throws his
##   head at where they are; `caught(player)` is emitted only if it finds them.
##   A step to one side in that moment and he misses. His body pushes this
##   machine's player aside but does not hurt them.
##
## Cut from Outside's: resting coiled or down a hole (and the coil, the hole,
## going home, `loose`), fear of fire and sunbeams, battering doors, waiting
## under ledges and climbing them, swimming, following the boy's trail (the
## maze's plan does that now), the level editor's `from_item`, and the target
## being only the boy. Sizes are Outside's times `thickness / 0.5`.

enum State { DORMANT, WAKING, HUNT, STRIKE, PROWL }

## How many places along him the body is bent through.
const POINTS := 80
## The ball his head is to the world (Outside's, before he is made bigger).
const RADIUS := 0.24
## How long the side-to-side wave is (Outside's).
const WAVE := 3.4
const MODEL := preload("res://models/enemies/apophis.glb")

const BODY_SHADER := """
shader_type spatial;
render_mode cull_back;

const int POINTS = 80;
uniform vec3 spine[POINTS];
uniform vec3 lift[POINTS];
void vertex() {
	// The mesh is a straight tube: x and y are across him, UV2.x is how far along. It is bent here.
	float at = clamp(UV2.x, 0.0, 1.0) * float(POINTS - 1);
	int i = int(min(floor(at), float(POINTS - 2)));
	float f = at - float(i);
	vec3 p0 = spine[max(i - 1, 0)];
	vec3 p1 = spine[i];
	vec3 p2 = spine[i + 1];
	vec3 p3 = spine[min(i + 2, POINTS - 1)];
	vec3 a = 2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3;
	vec3 b = -p0 + 3.0 * p1 - 3.0 * p2 + p3;
	vec3 centre = 0.5 * (2.0 * p1 + (p2 - p0) * f + a * f * f + b * f * f * f);
	vec3 going = 0.5 * ((p2 - p0) + 2.0 * a * f + 3.0 * b * f * f);
	vec3 along = length(going) > 0.0001 ? normalize(going) : vec3(0.0, 0.0, 1.0);
	vec3 up = normalize(mix(lift[i], lift[i + 1], f));
	vec3 side = cross(up, along);
	side = length(side) > 0.01 ? normalize(side) : normalize(cross(vec3(0.3, 0.2, 0.9), along));
	up = cross(along, side);
	VERTEX = centre + side * VERTEX.x + up * VERTEX.y;
	NORMAL = normalize(side * NORMAL.x + up * NORMAL.y);
}

// The web's renderer (gl_compatibility) takes ALBEDO and EMISSION as colours for the screen and makes them into
// light itself; the others take them as light. A colour that comes point by point (COLOR) is not made
// ready by either, so here it is light (see `srgb_to_linear` where the mesh is made) and worked in as light, and
// for the web's renderer is made a colour for the screen again at the last, that both show the same thing.
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
vec3 shown(vec3 light) {
	return mix(light * 12.92, 1.055 * pow(max(light, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), light));
}
#else
vec3 shown(vec3 light) {
	return light;
}
#endif

void fragment() {
	// (his colours are the model's materials, a face at a time)
	ALBEDO = shown(COLOR.rgb);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""

const HEAD_SHADER := """
shader_type spatial;
render_mode cull_disabled;

// How far his jaw is dropped (radians), how far his tongue is out (0..1), and where they hinge.
uniform float gape = 0.0;
uniform float tongue = 0.0;
uniform float flick = 0.0;
uniform vec2 hinge = vec2(0.0, 0.08);
uniform float root = 0.4;
uniform float roof = 0.0;
uniform float glow = 1.0;

void vertex() {
	// UV2.x says which part a point is of: 0 his skull, 1 his jaw, 2 his tongue. UV2.y, how far it goes with the jaw.
	vec3 p = VERTEX;
	if (UV2.x > 2.5) {
		// (a fang: it is drawn out of the roof of his mouth as his jaw drops)
		p.y = roof + (p.y - roof) * clamp(gape * 2.2, 0.1, 1.0);
	} else if (UV2.x > 0.5) {
		if (UV2.x > 1.5) {
			float out_by = p.z - root;
			p.z = root + out_by * tongue;
			p.y += sin(flick + out_by * 14.0) * 0.07 * out_by * tongue;
		}
		float turn = gape * UV2.y;
		float c = cos(turn);
		float s = sin(turn);
		vec2 from = vec2(p.y - hinge.x, p.z - hinge.y);
		p.y = hinge.x + from.x * c - from.y * s;
		p.z = hinge.y + from.x * s + from.y * c;
		NORMAL = vec3(NORMAL.x, NORMAL.y * c - NORMAL.z * s, NORMAL.y * s + NORMAL.z * c);
	}
	VERTEX = p;
}

#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
vec3 shown(vec3 light) {
	return mix(light * 12.92, 1.055 * pow(max(light, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), light));
}
#else
vec3 shown(vec3 light) {
	return light;
}
#endif

void fragment() {
	// UV.x is how much a part shines by itself: his eyes.
	ALBEDO = shown(COLOR.rgb * (1.0 - UV.x));
	EMISSION = shown(COLOR.rgb * UV.x * (UV.x > 0.5 ? glow : 1.0));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""

## Lit as the figures are (see `Toon`): two flat tones with a hard edge, and a rim of light.
const LIGHT := """
float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + 0.12) / 1.12;
	float amount = facing * smoothstep(0.15, 0.6, reach);
	float lit = cut(amount, 0.04);
	float strength = mix(reach, 1.0, 0.45);
	DIFFUSE_LIGHT += lit * strength * LIGHT_COLOR / PI;
	float graze = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	SPECULAR_LIGHT += cut(graze, 0.8) * lit * 0.22 * ALBEDO * strength * LIGHT_COLOR / PI;
}
"""

## How long he is, metres, and how thick at the middle (Outside's is 18 and 0.5).
@export_range(12.0, 80.0) var length := 46.0
@export var thickness := 1.8
## His speed, m/s: the boy runs at 4.4 and sprints at 5.6. He goes a little
## faster than this on the straight and a good deal slower in a turn.
@export var speed := 4.1
## How fast he goes while he prowls with nobody to go after, as a share of `speed`.
@export var prowl_pace := 0.45
## How fast he can turn, radians a second.
@export var turn_rate := 2.4
## Seconds between noticing someone and coming on.
@export var wake_time := 1.4
## How near his head must be to strike, how long he rears first, how near the
## player his head must pass to have them, and how far he can throw it (m).
@export var strike_distance := 5.5
@export var strike_warning := 0.6
@export var catch_distance := 1.0
@export var lunge_reach := 7.0
## How far his body swings from side to side as he goes (Outside's, times his size).
@export var wave := 0.22
## How many knives are stuck in him: the tomb paintings show him cut and speared.
@export_range(0, 6) var knives := 3
## Whether he hisses.
@export var voice := true
## Seconds of prowling with nobody about before he lies down where he is (0: never).
@export var rest_after := 40.0
## Lying still where he is put, until he notices someone (else he prowls from the start).
@export var start_resting := true

## What he is doing.
var state := State.DORMANT
## Where his head is drawn, the way it looks.
var head_at := Vector3.ZERO
var head_way := Vector3.BACK
## The middle of his body at each of `POINTS` places from head to tail, and how thick he is there.
var spine := PackedVector3Array()
var girth := PackedFloat32Array()

## How much bigger than Outside's he is.
var _k := 1.0
var _step := 0.15
var _radius := 0.24
var _spawn := Transform3D.IDENTITY
var _time := 0.0
var _clock := 0.0
var _yaw := 0.0
var _prev := Vector3.ZERO
var _travel := 0.0
var _idle := 0.0
# The path his head has taken, newest first: where, which way is up off the
# surface there, the height of the ground, and how much room there is to swing.
var _path_at := PackedVector3Array()
var _path_up := PackedVector3Array()
var _path_floor := PackedFloat32Array()
var _path_room := PackedFloat32Array()
var _up_now := Vector3.UP
var _floor_now := 0.0
var _room_now := 1.0
var _lift := PackedVector3Array()
var _detour := Vector3.ZERO
var _detour_time := 0.0
var _flip := 1.0
var _stuck_at := Vector3.ZERO
var _stuck_time := 0.0
# The strike.
var _aim := Vector3.ZERO
var _strike_from := Vector3.ZERO
var _lunge := Vector3.ZERO
var _tip := Vector3.ZERO
var _has_him := false
var _strike_rest := 0.0
# How he holds himself: how high his head is reared, how far it sways, how wide his jaw is (Outside's sizes).
var _rear := 0.0
var _rear_to := 0.0
var _headroom := 3.0
var _roof_rest := 0.0
var _gape := 0.0
var _gape_to := 0.0
var _tongue := 0.0
var _head_long := 1.0
var _gaze := Vector3.INF
var _body: MeshInstance3D
var _skull: MeshInstance3D
var _blades: MultiMeshInstance3D
var _body_material: ShaderMaterial
var _head_material: ShaderMaterial
var _hiss: AudioStreamPlayer3D
var _scrape: AudioStreamPlayer3D
var _loud := 0.0
var _spit := 0.0
var _own_rid: Array[RID] = []

static var _body_shader: Shader
static var _head_shader: Shader
static var _hiss_stream: AudioStreamWAV
static var _scrape_stream: AudioStreamWAV


func _init() -> void:
	sight_range = 70.0
	hear_range = 9.0
	memory = 10.0
	pack = &"serpents"


func _ready() -> void:
	_k = thickness / 0.5
	_step = clampf(0.15 * _k, 0.15, 0.4)
	_radius = RADIUS * _k
	# Players pass through his head; the world stops it.
	collision_layer = PUPPET_LAYER if puppet else 4
	collision_mask = 1
	floor_snap_length = 0.3 * _k
	floor_max_angle = deg_to_rad(50.0)
	var ball := SphereShape3D.new()
	ball.radius = _radius
	var collider := CollisionShape3D.new()
	collider.shape = ball
	collider.position.y = _radius
	add_child(collider)
	_own_rid = [get_rid()]
	spine.resize(POINTS)
	_lift.resize(POINTS)
	girth.resize(POINTS)
	for i in POINTS:
		girth[i] = girth_at(i / float(POINTS - 1))
	_build()
	_spawn = global_transform
	reset()


## How thick he is (half of it) at `along`, 0 at his head and 1 at the tip of his tail.
func girth_at(along: float) -> float:
	var neck := lerpf(0.78, 1.0, smoothstep(0.0, 0.1, along))
	var tail := pow(1.0 - smoothstep(0.5, 1.0, along), 0.8)
	return thickness * 0.5 * neck * lerpf(0.06, 1.0, tail)


## Back where he was put, lying along the passage, as at the start.
func reset() -> void:
	global_transform = _spawn
	_yaw = _spawn.basis.get_euler().y
	velocity = Vector3.ZERO
	quarry = null
	_forget = 0.0
	_last_seen = Vector3.INF
	_rear = 0.0
	_rear_to = 0.0
	_gape = 0.0
	_lunge = Vector3.ZERO
	_gaze = Vector3.INF
	_idle = 0.0
	_lay_along_passage()
	_prev = global_position
	_set_state(State.DORMANT if start_resting else State.PROWL)
	chasing = false
	_draw(0.0)


func is_awake() -> bool:
	return state != State.DORMANT


## Wakes him (as noticing someone does).
func wake() -> void:
	if state == State.DORMANT:
		_set_state(State.WAKING)
		_strike_rest = 0.6


func _set_state(to: State) -> void:
	if to != state:
		_time = 0.0
	state = to
	if to == State.DORMANT or to == State.PROWL:
		chasing = false
		if is_in_group(&"pursuers"):
			remove_from_group(&"pursuers")
	elif not is_in_group(&"pursuers"):
		add_to_group(&"pursuers")


func _forward() -> Vector3:
	return Vector3(sin(_yaw), 0.0, cos(_yaw))


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = _own_rid
	return get_world_3d().direct_space_state.intersect_ray(query)


# --- What he does ---

func _physics_process(delta: float) -> void:
	_clock += delta
	_time += delta
	var before := global_position
	_up_now = Vector3.UP
	_floor_now = global_position.y
	if puppet:
		_puppet(delta)
	elif maze:
		_think(delta)
	if state == State.DORMANT:
		_push_aside()
		return
	# How high he can rear here.
	_roof_rest -= delta
	if _roof_rest <= 0.0:
		_roof_rest = 0.25
		var roof := _ray(global_position + Vector3.UP * 0.3 * _k, global_position + Vector3.UP * 3.2 * _k)
		_headroom = 3.0 if roof.is_empty() else maxf(((roof["position"] as Vector3).y - global_position.y) / _k - 0.8, 0.0)
	_travel += Vector2(before.x - global_position.x, before.z - global_position.z).length()
	_remember(before)
	_push_aside()


func _think(delta: float) -> void:
	_strike_rest -= delta
	_sense(delta)
	match state:
		State.DORMANT:
			velocity = Vector3.ZERO
			if quarry:
				wake()
		State.WAKING:
			_waking(delta)
		State.HUNT, State.PROWL:
			_hunt(delta)
		State.STRIKE:
			_strike(delta)


func _waking(delta: float) -> void:
	velocity = Vector3.ZERO
	_rear_to = 1.1
	_gape_to = 0.7
	if quarry:
		_face(quarry.global_position, delta * 0.6)
		_gaze = quarry.global_position
	_spit = maxf(_spit, 0.6 if _time < 0.1 else 0.0)
	if _time >= wake_time:
		_set_state(State.HUNT)
		_stuck_at = global_position


func _hunt(delta: float) -> void:
	var after := quarry if hunting() else null
	if after == null:
		# Nobody: he prowls, slowly, low; and lies down if it goes on long enough.
		_set_state(State.PROWL)
		_rear_to = 0.12
		_gape_to = 0.0
		_gaze = Vector3.INF
		_idle += delta
		if rest_after > 0.0 and _idle > rest_after and not _last_seen.is_finite():
			_idle = 0.0
			_set_state(State.DORMANT)
			velocity = Vector3.ZERO
			_rear_to = 0.0
			return
		# (quicker on to where they were last seen)
		_go(delta, 0.8 if _last_seen.is_finite() else prowl_pace)
		return
	_idle = 0.0
	_set_state(State.HUNT)
	chasing = true
	var here := global_position
	var to := after.global_position - here
	var away := Vector2(to.x, to.z).length()
	# The strike: near, in sight, more or less in front.
	if _strike_rest <= 0.0 and away < strike_distance and absf(to.y) < 1.3 * _k and is_on_floor() \
			and nav.sees(here + Vector3.UP, after.global_position + Vector3.UP) \
			and (away < 0.9 * _k or _forward().dot(Vector3(to.x, 0.0, to.z).normalized()) > 0.55):
		_set_state(State.STRIKE)
		_has_him = false
		_spit = 1.0
		return
	# How he carries himself: head up off the ground, jaw wider the nearer he is.
	_rear_to = lerpf(0.5, 0.25, clampf((away - 4.0 * _k) / (6.0 * _k), 0.0, 1.0))
	_gape_to = lerpf(0.62, 0.08, clampf((away - 4.0 * _k) / (6.0 * _k), 0.0, 1.0))
	_gaze = Vector3.INF
	_go(delta, 1.0)


# Turns his body towards a place.
func _face(at: Vector3, by: float) -> void:
	var to := at - global_position
	if Vector2(to.x, to.z).length() > 0.05:
		_yaw = rotate_toward(_yaw, atan2(to.x, to.z), by * turn_rate)


# Goes on his way through the passages: turns, goes forward, and slides round what is in the way.
func _go(delta: float, pace: float) -> void:
	var here := global_position
	var flat := way(_radius * 1.6)
	var wish := flat.normalized() if flat.length() > 0.05 else _forward()
	_detour_time -= delta
	if _detour_time > 0.0:
		wish = (wish * 0.45 + _detour).normalized()
	var want := atan2(wish.x, wish.z)
	var off := absf(angle_difference(_yaw, want))
	# A little faster on the straight, slower in a turn; and right up to a place he pivots, so as not to go round and round it.
	var near := flat.length() < 1.2 * _k and off > 0.8
	_yaw = rotate_toward(_yaw, want, turn_rate * (1.0 + (off if near else minf(off, 0.6))) * delta)
	var forward := _forward()
	var factor := lerpf(1.12, 0.6, clampf(off / 0.9, 0.0, 1.0))
	if near:
		factor = 0.25
	if flat.length() < 0.1:
		factor = 0.0
	if is_on_floor():
		var hit := KinematicCollision3D.new()
		if test_move(global_transform, forward * 0.3 * _k, hit) and hit.get_normal().y < 0.6:
			if _detour_time <= 0.0:
				var normal := hit.get_normal()
				_detour = Vector3(-normal.z, 0.0, normal.x)
				if absf(_detour.dot(wish)) > 0.15:
					_detour *= signf(_detour.dot(wish))
				_detour *= _flip
			_detour_time = 0.7
	var going := forward * speed * pace * factor
	velocity.x = going.x
	velocity.z = going.z
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	# Getting nowhere: the other way round.
	_stuck_time += delta
	if _stuck_time >= 1.0:
		if _stuck_at.distance_to(global_position) < 0.35 and flat.length() > 0.9:
			_flip = -_flip
			_detour_time = 0.0
		_stuck_time = 0.0
		_stuck_at = global_position


# He stops, rears back with his mouth open, and throws his head at where they are.
func _strike(delta: float) -> void:
	_stand(delta)
	var hold := 0.2
	var fling := 0.16
	var from := global_position + Vector3.UP * (girth[0] * 0.62 + _rear * _k)
	var after := quarry if hunting() else null
	if _time < strike_warning:
		# He follows them round as he rears, but not to the last: then he is committed.
		_rear_to = 1.3
		_gape_to = 1.0
		if after and _time < strike_warning - hold:
			_face(after.global_position, delta * 2.5)
			var low: bool = after.get(&"is_ducking") == true or after.get(&"is_crawling") == true
			_aim = after.global_position + Vector3.UP * (0.45 if low else 0.75)
			_gaze = _aim
		_strike_from = from
		_tip = from
		return
	var reach := _aim - _strike_from
	reach = reach.normalized() * minf(reach.length() + 0.35 * _k, lunge_reach) - head_way_of(reach) * _head_long * 0.52
	var since := _time - strike_warning
	if since < fling:
		var by := since / fling
		_lunge = reach * by
		_gape_to = 1.0
		# (his mouth, a little in front of where his head is drawn from)
		var tip := _strike_from + _lunge + head_way_of(reach) * _head_long * 0.47
		if not _has_him and not puppet:
			var found := _struck(_tip, tip)
			if found:
				_has_him = true
				_catch(found)
		_tip = tip
	elif since < fling + 0.3:
		_lunge = reach
		_gape_to = 0.0
		_gape = minf(_gape, 0.15)
	elif since < fling + 1.0:
		_lunge = reach * (1.0 - smoothstep(0.0, 1.0, (since - fling - 0.3) / 0.7))
		_rear_to = 0.3
	else:
		_lunge = Vector3.ZERO
		_strike_rest = 0.35
		_gaze = Vector3.INF
		if not puppet:
			_set_state(State.HUNT)
			_stuck_time = 0.0
			_stuck_at = global_position


## The player his mouth passes through, going from `a` to `b`, if any.
func _struck(a: Vector3, b: Vector3) -> Node3D:
	for player: Node3D in players():
		if not huntable(player):
			continue
		var feet := player.global_position
		if feet.distance_to(b) > lunge_reach + 3.0:
			continue
		var low: bool = player.get(&"is_ducking") == true or player.get(&"is_crawling") == true
		var top := feet + Vector3.UP * (0.65 if low else 1.15)
		var nearest := Geometry3D.get_closest_points_between_segments(a, b, feet + Vector3.UP * 0.1, top)
		if nearest[0].distance_to(nearest[1]) < catch_distance + 0.2:
			return player
	return null


func head_way_of(reach: Vector3) -> Vector3:
	return reach.normalized() if reach.length() > 0.01 else _forward()


# Stands where he is (falling, if there is nothing under him).
func _stand(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= 24.0 * delta
	move_and_slide()


# --- Being run by someone else ---

func yaw() -> float:
	return _yaw


func net_state() -> int:
	return state


func net_point() -> Vector3:
	if state == State.STRIKE:
		return _aim
	return _gaze


func _puppet(delta: float) -> void:
	if not _heard:
		return
	match state:
		State.DORMANT:
			velocity = Vector3.ZERO
			_rear_to = 0.0
			_gape_to = 0.0
			return
		State.STRIKE:
			_strike(delta)
			return
		State.WAKING:
			_rear_to = 1.1
			_gape_to = 0.7
		State.PROWL:
			_rear_to = 0.12
			_gape_to = 0.0
		State.HUNT:
			var near := nearest_player(global_position)
			var away := near.global_position.distance_to(global_position) if near else 100.0
			_rear_to = lerpf(0.5, 0.25, clampf((away - 4.0 * _k) / (6.0 * _k), 0.0, 1.0))
			_gape_to = lerpf(0.62, 0.08, clampf((away - 4.0 * _k) / (6.0 * _k), 0.0, 1.0))
	_gaze = _heard_extra
	_yaw = lerp_angle(_yaw, _heard_yaw, 1.0 - exp(-10.0 * delta))
	_follow(delta)


func _heard_changed(_was: int, now: int, first: bool) -> void:
	var to := now as State
	if to == State.STRIKE:
		_aim = _heard_extra if _heard_extra.is_finite() else global_position + _forward() * strike_distance
		_has_him = false
		_spit = 1.0
	elif to == State.WAKING:
		_spit = 0.6
	_set_state(to)
	if first:
		_time = 0.0


func _put(at: Vector3, facing: float) -> void:
	global_position = at
	_yaw = facing
	_prev = at
	velocity = Vector3.ZERO
	_lay_along_passage()


# --- His body ---

# Keeps the place his head has just left, on the path his body lies along.
func _remember(at: Vector3) -> void:
	_prev = at
	if at.distance_to(_path_at[0]) < _step:
		return
	var room := _room_now
	# How much room there is to either side of him here, for his body to swing in.
	var side := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var low := at + Vector3.UP * 0.3 * _k
	room = 1.0
	var swing := maxf(wave * _k, 0.01)
	for way_out: float in [1.0, -1.0]:
		var hit := _ray(low, low + side * way_out * (thickness * 0.55 + swing + 0.3))
		if not hit.is_empty():
			room = minf(room, clampf((low.distance_to(hit["position"]) - thickness * 0.55) / swing, 0.0, 1.0))
	_path_at.insert(0, at)
	_path_up.insert(0, _up_now)
	_path_floor.insert(0, _floor_now)
	_path_room.insert(0, room)
	_room_now = 1.0
	var most := int(length / _step) + 24
	if _path_at.size() > most:
		_path_at.resize(most)
		_path_up.resize(most)
		_path_floor.resize(most)
		_path_room.resize(most)


# Lays him as he lies at rest: stretched back from where his head is along the
# passage behind him, round its turns, as far as he is long (the tail curled up
# in a dead end if the passage stops short).
func _lay_along_passage() -> void:
	_path_at.clear()
	_path_up.clear()
	_path_floor.clear()
	_path_room.clear()
	var head := global_position
	var points: Array[Vector3] = [head]
	if maze:
		var cell := maze.cell_at(head)
		var behind := -_forward()
		# (first the cell behind him, if that way is open; then on from there, keeping straight when it can)
		var step := Vector2i(signi(roundi(signf(behind.x))), 0) if absf(behind.x) > absf(behind.z) else Vector2i(0, signi(roundi(signf(behind.z))))
		var came := {cell: true}
		var left := length
		while left > 0.0:
			var options: Array[Vector2i] = []
			for s: Vector2i in [step, Vector2i(step.y, -step.x), Vector2i(-step.y, step.x)]:
				if s != Vector2i.ZERO and not maze.blocked(cell, s) and nav.allowed(cell + s) and not came.has(cell + s):
					options.append(s)
			if options.is_empty():
				break
			step = options[0]
			cell += step
			came[cell] = true
			var point := maze.world(cell)
			point.y = head.y
			left -= points.back().distance_to(point)
			points.append(point)
	# Along those points, a place every step; the rest, past a dead end, wound tight.
	var at := head
	var k := 1
	var count := int(length / _step) + 8
	var tail_turn := 0.0
	for i in count:
		_path_at.append(at)
		_path_up.append(Vector3.UP)
		_path_floor.append(head.y)
		_path_room.append(0.6)
		if k < points.size():
			var to := points[k] - at
			if to.length() <= _step:
				at = points[k]
				k += 1
			else:
				at += to.normalized() * _step
		else:
			# (round and round in the last cell)
			tail_turn += _step / (thickness * 1.6)
			var middle: Vector3 = points.back()
			at = middle + Vector3(cos(tail_turn), 0.0, sin(tail_turn)) * thickness * 1.6
	_travel = 0.0
	_up_now = Vector3.UP


# His body is in the way of this machine's player: they are put out of it.
func _push_aside() -> void:
	if state == State.STRIKE:
		return
	var boy := local_player()
	if boy == null or boy.is_limp:
		return
	var feet := boy.global_position
	if absf(feet.x - global_position.x) > length or absf(feet.z - global_position.z) > length:
		return
	for i in range(3, POINTS, 2):
		var at := spine[i]
		if at.y < feet.y - girth[i] - 0.4 or at.y > feet.y + 1.0 + girth[i]:
			continue
		var out := Vector3(feet.x - at.x, 0.0, feet.z - at.z)
		var near := girth[i] + 0.25
		var away := out.length()
		if away < near and away > 0.001:
			boy.move_and_collide(out / away * (near - away))
			return


func _process(delta: float) -> void:
	_draw(delta)
	_voice(delta)


# Lays his body along its path and tells the shader where it is; and puts his head on the end of it.
func _draw(delta: float) -> void:
	_rear = lerpf(_rear, minf(_rear_to, _headroom), 1.0 - exp(-5.0 * delta))
	_gape = lerpf(_gape, _gape_to, 1.0 - exp(-9.0 * delta))
	var resting := state == State.DORMANT
	var head := _prev.lerp(global_position, Engine.get_physics_interpolation_fraction())
	if resting:
		head = global_position
	var spacing := length / float(POINTS - 1)
	var count := _path_at.size()
	var a := head
	var a_up := _up_now
	var a_floor := _floor_now
	var a_room := 0.0
	var j := 0
	var b := _path_at[0]
	var part := a.distance_to(b)
	var walked := 0.0
	var low := Vector3.INF
	var high := -Vector3.INF
	var wavelength := TAU / (WAVE * _k)
	var swing_by := wave * _k
	for i in POINTS:
		var along := i * spacing
		while along > walked + part and j < count - 1:
			walked += part
			a = b
			a_up = _path_up[j]
			a_floor = _path_floor[j]
			a_room = _path_room[j]
			j += 1
			b = _path_at[j]
			part = a.distance_to(b)
		var share := clampf((along - walked) / maxf(part, 0.0001), 0.0, 1.0)
		var at := a.lerp(b, share)
		var up := a_up.lerp(_path_up[j], share).normalized()
		var radius := girth[i]
		var run := (a - b) / part if part > 0.0001 else Vector3.FORWARD
		var side := up.cross(run)
		# The wave: it stands still on the ground, and he slides through it.
		var swing := swing_by * smoothstep(0.3 * _k, 2.6 * _k, along) * lerpf(a_room, _path_room[j], share) * sin(wavelength * (_travel - along))
		if side.length_squared() > 0.001:
			at += side.normalized() * swing
		at += up * radius * 0.62
		var ground := maxf(a_floor, _path_floor[j])
		at.y = maxf(at.y, ground + radius * 0.62)
		spine[i] = at
		_lift[i] = up
	# His head reared: the first of him comes up off the ground in a curve, sways, and is thrown out in a strike.
	var reach := (1.4 + 1.3 * _rear) * _k + _lunge.length() * 0.8
	var forward := _forward()
	var across := Vector3(forward.z, 0.0, -forward.x)
	var sway := sin(_clock * 1.9) * 0.3 * _k * clampf(_rear, 0.0, 1.0) * (0.3 + 0.7 * _path_room[0]) if state != State.STRIKE else 0.0
	for i in POINTS:
		var along := i * spacing
		if along >= reach:
			break
		var share := 1.0 - along / reach
		var eased := share * share * (3.0 - 2.0 * share)
		spine[i] += Vector3.UP * _rear * _k * eased - forward * 0.42 * _rear * _k * sin(PI * share) + across * sway * eased + _lunge * eased * eased
	for i in POINTS:
		low = low.min(spine[i])
		high = high.max(spine[i])
	_body_material.set_shader_parameter(&"spine", spine)
	_body_material.set_shader_parameter(&"lift", _lift)
	_body.custom_aabb = AABB(low, high - low).grow(thickness + 0.3)
	# His head: it looks the way his neck runs, or at whoever it is after when it is reared.
	head_at = spine[0]
	var way_to := (spine[0] - spine[2])
	way_to = way_to.normalized() if way_to.length() > 0.001 else forward
	if not resting and _lunge == Vector3.ZERO:
		way_to = (way_to + forward * 0.8 + across * 0.12 * sin(wavelength * _travel)).normalized()
	if _gaze.is_finite() and _rear > 0.3 and (state == State.STRIKE or state == State.WAKING):
		var to := _gaze - head_at
		if to.length() > 0.2:
			way_to = way_to.lerp(to.normalized(), clampf(_rear * 1.6, 0.0, 1.0)).normalized()
	if _lunge.length() > 0.2:
		way_to = way_to.lerp(_lunge.normalized(), 0.9).normalized()
	head_way = head_way.lerp(way_to, 1.0 - exp(-14.0 * delta)).normalized() if delta > 0.0 else way_to
	var x := Vector3.UP.cross(head_way)
	x = x.normalized() if x.length() > 0.01 else across
	_skull.global_transform = Transform3D(Basis(x, head_way.cross(x), head_way).scaled_local(Vector3.ONE * _k), head_at - head_way * 0.06 * _k)
	# His tongue flicks when his mouth is nearly shut.
	_tongue = maxf(0.0, sin(_clock * 4.2) * 2.0 - 1.0) * (1.0 if fmod(_clock, 3.0) < 1.5 else 0.0) if _gape < 0.3 and not resting else 0.0
	_head_material.set_shader_parameter(&"gape", _gape * 0.95)
	_head_material.set_shader_parameter(&"tongue", _tongue)
	_head_material.set_shader_parameter(&"flick", _clock * 31.0)
	_head_material.set_shader_parameter(&"glow", 0.5 if resting else 1.5 + 0.4 * sin(_clock * 5.0))
	if _blades:
		var many := _blades.multimesh
		for n in many.instance_count:
			var i := int((0.2 + 0.5 * n / maxf(many.instance_count - 1, 1.0)) * (POINTS - 1))
			var run := (spine[i - 1] - spine[i + 1]).normalized()
			var up := _lift[i]
			var side := up.cross(run).normalized() if absf(up.dot(run)) < 0.95 else Vector3.RIGHT
			up = run.cross(side)
			var tip := Basis(side, up, run) * Basis.from_euler(Vector3(0.5 - 0.35 * n, 0.0, 0.55 * (1.0 if n % 2 == 0 else -1.0)))
			many.set_instance_transform(n, Transform3D(tip, spine[i] + up * girth[i] * 0.55))


# --- What he is made of ---

func _build() -> void:
	if _body_shader == null:
		_body_shader = Shader.new()
		_body_shader.code = BODY_SHADER + LIGHT
		_head_shader = Shader.new()
		_head_shader.code = HEAD_SHADER + LIGHT
	# The model (Outside's tools/build_apophis.py): his head, one length of his body, and a knife. It is read, and put away.
	var model := MODEL.instantiate()
	var parts := {}
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for part_name: String in ["head", "body", "knife"]:
			if String(part.name).contains(part_name):
				parts[part_name] = part
	_body_material = ShaderMaterial.new()
	_body_material.shader = _body_shader
	_body = MeshInstance3D.new()
	_body.mesh = _body_mesh((parts["body"] as MeshInstance3D).mesh)
	_body.material_override = _body_material
	_body.top_level = true
	add_child(_body)
	_body.global_transform = Transform3D.IDENTITY
	_head_material = ShaderMaterial.new()
	_head_material.shader = _head_shader
	_skull = MeshInstance3D.new()
	_skull.mesh = _head_mesh(parts["head"])
	_skull.material_override = _head_material
	_skull.top_level = true
	_skull.extra_cull_margin = 1.0 * _k
	add_child(_skull)
	if knives > 0:
		var many := MultiMesh.new()
		many.transform_format = MultiMesh.TRANSFORM_3D
		many.mesh = _knife_mesh((parts["knife"] as MeshInstance3D).mesh)
		many.instance_count = knives
		_blades = MultiMeshInstance3D.new()
		_blades.multimesh = many
		_blades.top_level = true
		_blades.custom_aabb = AABB(Vector3.ONE * -4000.0, Vector3.ONE * 8000.0)
		add_child(_blades)
		_blades.global_transform = Transform3D.IDENTITY
	model.free()
	if voice:
		_sounds()
		_hiss = _player(_hiss_stream)
		_scrape = _player(_scrape_stream)


# A mesh of the model's, all its surfaces as one: each point's place, the way it faces, the colour of its
# material (so that the whole is one thing to draw), the name of that material, and the corners of its triangles.
func _read(mesh: Mesh) -> Dictionary:
	var places := PackedVector3Array()
	var normals := PackedVector3Array()
	var tints := PackedColorArray()
	var labels := PackedStringArray()
	var corners := PackedInt32Array()
	var hung: Array[PackedInt32Array] = []
	var weights: Array[PackedFloat32Array] = []
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var material := mesh.surface_get_material(surface) as BaseMaterial3D
		var first := places.size()
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		places.append_array(points)
		normals.append_array(arrays[Mesh.ARRAY_NORMAL])
		for n in points.size():
			tints.append(material.albedo_color.srgb_to_linear() if material else Color.WHITE)
			labels.append(material.resource_name if material else "")
		for corner: int in (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array):
			corners.append(first + corner)
		if arrays[Mesh.ARRAY_BONES] != null:
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var shares: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var each := bones.size() / points.size()
			for n in points.size():
				hung.append(bones.slice(n * each, (n + 1) * each))
				weights.append(shares.slice(n * each, (n + 1) * each))
	return {"places": places, "normals": normals, "tints": tints, "labels": labels, "corners": corners, "hung": hung, "weights": weights}


# His body: the model's one length of it laid end to end for as long as he is, thinned at his neck and down his
# tail (`girth_at`), as a straight tube for the shader to bend: x and y across him, and UV2.x how far along.
func _body_mesh(source: Mesh) -> ArrayMesh:
	var one := _read(source)
	var from: PackedVector3Array = one["places"]
	var period := 0.0
	var half := 0.0
	for at in from:
		period = maxf(period, -at.z)
		half = maxf(half, absf(at.x) / 1.08)
	# (the length of body in the model is for a snake half a metre thick: it is laid at his size)
	period *= _k
	var places := PackedVector3Array()
	var normals := PackedVector3Array()
	var tints := PackedColorArray()
	var along := PackedVector2Array()
	var corners := PackedInt32Array()
	for copy in ceili(length / period):
		var first := places.size()
		for n in from.size():
			var share := minf(copy * period - from[n].z * _k, length) / length
			var size := girth_at(share) / half
			var faces: Vector3 = one["normals"][n]
			# (the model runs back from his head along -Z and the shader's tube forward along its own length: it is turned about, not mirrored)
			places.append(Vector3(-from[n].x * size, from[n].y * size, 0.0))
			normals.append(Vector3(-faces.x, faces.y, 0.0).normalized())
			tints.append(one["tints"][n])
			along.append(Vector2(share, 0.0))
		for corner: int in one["corners"]:
			corners.append(first + corner)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = places
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = tints
	arrays[Mesh.ARRAY_TEX_UV2] = along
	arrays[Mesh.ARRAY_INDEX] = corners
	var made := ArrayMesh.new()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return made


# His head: the model's, as one thing to draw. The model hangs it from bones (`jaw`, `tongue`, `fangs`); here
# each point is told which of them it goes with and how much (UV2), and the shader works them. What is of the
# materials `eye` and `pupil` shines by itself, and the inside of his mouth a little (UV.x). It is made at
# Outside's size, and scaled up where it is drawn.
func _head_mesh(part: MeshInstance3D) -> ArrayMesh:
	var one := _read(part.mesh)
	var skeleton := part.get_node_or_null(part.skeleton) as Skeleton3D
	var bone_of := PackedStringArray()
	for bind in part.skin.get_bind_count():
		var bind_name := String(part.skin.get_bind_name(bind))
		bone_of.append(bind_name if bind_name != "" else skeleton.get_bone_name(part.skin.get_bind_bone(bind)))
	var hinge := skeleton.get_bone_global_rest(skeleton.find_bone("jaw")).origin
	_head_material.set_shader_parameter(&"hinge", Vector2(hinge.y, hinge.z))
	_head_material.set_shader_parameter(&"root", skeleton.get_bone_global_rest(skeleton.find_bone("tongue")).origin.z)
	_head_material.set_shader_parameter(&"roof", skeleton.get_bone_global_rest(skeleton.find_bone("fangs")).origin.y)
	var places: PackedVector3Array = one["places"]
	var shines := PackedVector2Array()
	var goes := PackedVector2Array()
	_head_long = 0.0
	for n in places.size():
		var with := {"jaw": 0.0, "tongue": 0.0, "fangs": 0.0}
		for m in (one["hung"][n] as PackedInt32Array).size():
			var bone := bone_of[one["hung"][n][m]]
			if with.has(bone):
				with[bone] += one["weights"][n][m]
		if with["fangs"] > 0.5:
			goes.append(Vector2(3.0, 0.0))
		elif with["tongue"] > 0.5:
			goes.append(Vector2(2.0, 0.8))
		elif with["jaw"] > 0.01:
			goes.append(Vector2(1.0, with["jaw"]))
		else:
			goes.append(Vector2.ZERO)
			_head_long = maxf(_head_long, places[n].z * _k)
		var label: String = one["labels"][n]
		shines.append(Vector2(1.0 if label == "eye" or label == "pupil" else 0.3 if label == "mouth" else 0.0, 0.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = places
	arrays[Mesh.ARRAY_NORMAL] = one["normals"]
	arrays[Mesh.ARRAY_COLOR] = one["tints"]
	arrays[Mesh.ARRAY_TEX_UV] = shines
	arrays[Mesh.ARRAY_TEX_UV2] = goes
	arrays[Mesh.ARRAY_INDEX] = one["corners"]
	var made := ArrayMesh.new()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return made


# A knife, stuck in him point first: the model's, as one thing to draw.
func _knife_mesh(source: Mesh) -> ArrayMesh:
	var one := _read(source)
	var places: PackedVector3Array = one["places"]
	for n in places.size():
		places[n] *= _k
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = places
	arrays[Mesh.ARRAY_NORMAL] = one["normals"]
	var tints: PackedColorArray = one["tints"]
	# (the web's renderer takes a point's colour as a colour for the screen, the others as light: see `shown` in the shaders)
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		for n in tints.size():
			tints[n] = tints[n].linear_to_srgb()
	arrays[Mesh.ARRAY_COLOR] = tints
	arrays[Mesh.ARRAY_INDEX] = one["corners"]
	var made := ArrayMesh.new()
	made.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var metal := StandardMaterial3D.new()
	metal.vertex_color_use_as_albedo = true
	metal.roughness = 0.6
	made.surface_set_material(0, metal)
	return made


## How many triangles he is, and how many things are drawn for him.
func cost() -> Dictionary:
	var triangles := 0
	var draws := 0
	for part: GeometryInstance3D in [_body, _skull, _blades]:
		if part == null:
			continue
		draws += 1
		var mesh: Mesh = (part as MultiMeshInstance3D).multimesh.mesh if part is MultiMeshInstance3D else (part as MeshInstance3D).mesh
		var count: int = mesh.surface_get_array_index_len(0) / 3 if mesh.surface_get_array_index_len(0) > 0 else mesh.surface_get_array_len(0) / 3
		triangles += count * ((part as MultiMeshInstance3D).multimesh.instance_count if part is MultiMeshInstance3D else 1)
	return {"triangles": triangles, "draws": draws}


# --- His voice: a long dry hiss, and the scrape of his scales, both made here from noise ---

func _player(stream: AudioStream) -> AudioStreamPlayer3D:
	var sound := AudioStreamPlayer3D.new()
	sound.stream = stream
	# (how loud he is says how near he is to this machine's player, wherever the camera is)
	sound.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	sound.volume_db = -60.0
	sound.position.y = 0.4
	add_child(sound)
	return sound


func _voice(delta: float) -> void:
	if _hiss == null:
		return
	var boy := local_player()
	if state == State.DORMANT or boy == null:
		_loud = move_toward(_loud, 0.0, delta * 2.0)
	else:
		# Louder as he nears: nothing at fifty metres, all of it at four.
		var away := head_at.distance_to(boy.global_position)
		_loud = move_toward(_loud, pow(1.0 - clampf((away - 4.0) / 46.0, 0.0, 1.0), 2.2), delta * 1.5)
	_spit = move_toward(_spit, 0.0, delta * 1.4)
	if _loud <= 0.001 and _spit <= 0.001:
		if _hiss.playing:
			_hiss.stop()
			_scrape.stop()
		return
	if not _hiss.playing:
		_hiss.play()
		_scrape.play()
	var breath := 0.75 + 0.25 * sin(_clock * 1.3)
	var hiss := _loud * (0.35 + 0.65 * _gape) * breath + _spit * 0.9
	_hiss.volume_db = linear_to_db(clampf(hiss, 0.0001, 1.2))
	# (he is bigger than Outside's: a little lower)
	_hiss.pitch_scale = (0.9 + 0.25 * _gape + 0.3 * _spit) * 0.85
	var slide := clampf(Vector2(velocity.x, velocity.z).length() / maxf(speed, 0.1), 0.0, 1.2)
	_scrape.volume_db = linear_to_db(clampf(_loud * slide * 0.8, 0.0001, 1.0))
	_scrape.pitch_scale = (0.8 + 0.3 * slide) * 0.8


static func _sounds() -> void:
	if _hiss_stream:
		return
	var rate := 22050
	var chance := RandomNumberGenerator.new()
	chance.seed = 39
	# The hiss: the top of the noise, with the breath in it rising and falling.
	var samples := PackedFloat32Array()
	samples.resize(rate * 2)
	var last := 0.0
	var smooth := 0.0
	for n in samples.size():
		var noise := chance.randf_range(-1.0, 1.0)
		var sharp := noise - last
		last = noise
		smooth = lerpf(smooth, sharp, 0.55)
		samples[n] = (sharp * 0.5 + smooth * 0.5) * 0.42 * (0.8 + 0.2 * sin(TAU * n / float(samples.size()) * 3.0))
	_hiss_stream = _wave(samples, rate, true)
	# The scrape: lower, and in rasps, as each length of him takes hold of the ground and lets go.
	samples = PackedFloat32Array()
	samples.resize(int(rate * 1.6))
	var low := 0.0
	for n in samples.size():
		var noise := chance.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.18)
		var along := float(n) / samples.size()
		var rasp := pow(absf(sin(PI * along * 5.0)), 2.5) * (0.6 + 0.4 * sin(TAU * along * 2.0 + 1.0))
		var grit := 0.5 + 0.5 * signf(sin(TAU * along * 5.0 * 37.0 + sin(along * 90.0)))
		samples[n] = (low * 1.3 + (noise - low) * 0.25) * rasp * (0.55 + 0.45 * grit) * 0.6
	_scrape_stream = _wave(samples, rate, true)


static func _wave(samples: PackedFloat32Array, rate: int, loops: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for n in samples.size():
		data.encode_s16(n * 2, int(clampf(samples[n], -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	if loops:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = samples.size()
	stream.data = data
	return stream


func _puppet_changed() -> void:
	collision_layer = PUPPET_LAYER if puppet else 4

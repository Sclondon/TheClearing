class_name Camper
extends DrivenBoy
## A runner resting at a camp between runs (an occupied Campsite): the same boy
## as the players and the MazeRunners, in a runner's muted shirt, sat on the
## ground round the fire (or asleep by it). Come up to the camp and he looks up
## and points you to what is worth taking lying near it (anything of Loot's
## within reach of the camp), or beckons you in to the fire if there is nothing.
## No voice: gestures only, as the runners.
##
## Nothing hunts in the clearing, where the camps with people at them are, so
## he is not among the `maze_players`. Each copy of the game sits its own (they
## are placed from the seed, and what he points at is for whoever comes near on
## that copy), so nothing of him is sent.

## A player this near he notices; how long he points; how long before he will again.
const NOTICE := 7.0
const POINT_FOR := 3.5
const REST := 18.0
## Further than this from the camera he is not posed.
const POSE_RANGE := 75.0

## His camp, and where he sits at it (facing the fire).
var camp: Campsite
var seat := Transform3D.IDENTITY
## Asleep by the fire, not sitting up.
var sleeper := false

var _settle := 0.4
var _look_in := 0.0
var _pointing := 0.0
var _rest := 0.0
var _far := false


func _ready() -> void:
	super()
	add_to_group(&"campers")
	global_position = seat.origin + Vector3.UP * 0.05
	facing_yaw = seat.basis.get_euler().y
	rotation.y = 0.0


## (whatever is giving chase somewhere in the maze, it is no business of his at the fire)
func _is_hunted(_delta: float) -> bool:
	return false


func _physics_process(delta: float) -> void:
	super(delta)
	if _settle > 0.0:
		_settle -= delta
		if _settle <= 0.0:
			facing_yaw = seat.basis.get_euler().y
			if sleeper:
				sleep()
			else:
				sit()
		return
	if sleeper:
		return
	_rest -= delta
	if _pointing > 0.0:
		_pointing -= delta
		if _pointing <= 0.0:
			gesture(GestureRig.Gesture.NONE)
		return
	_look_in -= delta
	if _look_in > 0.0 or _rest > 0.0:
		return
	_look_in = 0.5
	var someone := _player_near()
	if someone == null:
		return
	var thing := _loot_near()
	if thing.is_finite():
		gesture(GestureRig.Gesture.POINT, Vector3(thing.x - global_position.x, 0.0, thing.z - global_position.z).normalized())
	else:
		gesture(GestureRig.Gesture.BECKON)
	_pointing = POINT_FOR
	_rest = REST


## The player on this copy, if near enough to notice.
func _player_near() -> Node3D:
	for player: Node in get_tree().get_nodes_in_group(&"maze_players"):
		if player is Player and not (player is DrivenBoy) and (player as Node3D).global_position.distance_to(global_position) < NOTICE:
			return player
	return null


## The nearest thing of Loot's lying within reach of the camp (not finite: none).
func _loot_near() -> Vector3:
	var best := Vector3.INF
	var least := 22.0
	var from := camp.global_position if camp else global_position
	for item: Node in get_tree().get_nodes_in_group(&"loot"):
		var body := item as Node3D
		if body == null or not body.visible or item.get(&"loot_state") != LootItem.State.LYING:
			continue
		var d := body.global_position.distance_to(from)
		if d < least:
			least = d
			best = body.global_position
	return best


func _process(delta: float) -> void:
	super(delta)
	var camera := get_viewport().get_camera_3d()
	var far := camera != null and camera.global_position.distance_to(global_position) > POSE_RANGE
	if far != _far:
		_far = far
		_rig.visible = not far
		_rig.process_mode = Node.PROCESS_MODE_DISABLED if far else Node.PROCESS_MODE_INHERIT
		# (sat down and far off, his body need not be stepped either: he goes nowhere)
		if _settle <= 0.0:
			set_physics_process(not far)

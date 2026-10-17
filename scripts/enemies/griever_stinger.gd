class_name GrieverStinger
extends RefCounted
## A Griever's tail: a chain of metal vertebrae from the back of the lump,
## curled up and over it like a scorpion's, with a stinger at the end.
##
## At rest it is posed joint by joint (each one bent a little further over),
## and sways, the sway running down it from the root to the tip. Winding up, it
## coils tighter and draws back, shivering (the warning). Striking, it is
## thrown at a point by FABRIK and the two poses are blended, so it uncoils
## straight at whoever it is aimed at, and then curls back.

const COUNT := 12
## Each vertebra's length, root to tip.
const LENGTHS: Array[float] = [0.75, 0.72, 0.68, 0.64, 0.6, 0.56, 0.52, 0.48, 0.45, 0.42, 0.4, 0.38]
## Where it leaves the body (body space, forward -Z).
const ROOT := Vector3(0.0, 0.7, 1.55)
## How long the barb at the end is.
const STING := 0.85

## The joints in the world, root first (COUNT + 1 of them), and the stinger's point.
var joints := PackedVector3Array()
var tip := Vector3.ZERO
## 0: at rest. 1: fully wound up.
var wind := 0.0
## 0: posed. 1: thrown all the way at `aim`.
var throw := 0.0
var aim := Vector3.ZERO

var _time := randf() * 10.0


func _init() -> void:
	joints.resize(COUNT + 1)


static func reach() -> float:
	var total := STING
	for l: float in LENGTHS:
		total += l
	return total


## Poses it for this frame on a body at `body`.
func update(delta: float, body: Transform3D) -> void:
	_time += delta
	var rest := _curled(body)
	if throw <= 0.001:
		joints = rest
	else:
		var thrown := _reach_for(rest, aim)
		for i in joints.size():
			joints[i] = rest[i].lerp(thrown[i], throw)
	var last := joints[COUNT] - joints[COUNT - 1]
	tip = joints[COUNT] + last.normalized() * STING


## The curled pose: each joint bends a little further forward over the back,
## swaying side to side and nodding, the sway lagging down the chain.
func _curled(body: Transform3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(COUNT + 1)
	var at := ROOT
	out[0] = body * at
	# Up and back out of the lump to start with.
	var pitch := deg_to_rad(-40.0) - wind * 0.35
	var bend := deg_to_rad(16.0) + wind * deg_to_rad(3.0)
	var shiver := wind * wind * 0.06 * sin(_time * 55.0)
	var side := 0.0
	for i in COUNT:
		var lag := float(i) * 0.45
		side += sin(_time * 1.1 - lag) * 0.07 * (1.0 - wind * 0.7) + shiver * (i % 2 * 2 - 1)
		var nod := sin(_time * 1.7 - lag) * 0.035 * (1.0 - wind)
		pitch += bend + nod
		# (pitch 0 is straight up; less leans back (+Z), more tips forward over the body (-Z))
		var dir := Vector3(sin(side), cos(pitch), -sin(pitch)).normalized()
		at += dir * LENGTHS[i]
		out[i + 1] = body * at
	return out


## FABRIK from the root at `chain[0]` to `target`, starting from `chain`.
func _reach_for(chain: PackedVector3Array, target: Vector3) -> PackedVector3Array:
	var p := chain.duplicate()
	var root := p[0]
	# The tip of the barb, not the last joint, is what has to arrive.
	var lengths: Array[float] = LENGTHS.duplicate()
	lengths[COUNT - 1] += STING
	var total := 0.0
	for l: float in lengths:
		total += l
	if root.distance_to(target) >= total:
		var dir := (target - root).normalized()
		for i in range(1, p.size()):
			p[i] = p[i - 1] + dir * lengths[i - 1]
	else:
		for pass_number in 8:
			p[COUNT] = target
			for i in range(COUNT - 1, -1, -1):
				p[i] = p[i + 1] + (p[i] - p[i + 1]).normalized() * lengths[i]
			p[0] = root
			for i in range(1, p.size()):
				p[i] = p[i - 1] + (p[i] - p[i - 1]).normalized() * lengths[i - 1]
			if p[COUNT].distance_to(target) < 0.05:
				break
	# (the last joint stands short of the target by the barb's length)
	var last_dir := (p[COUNT] - p[COUNT - 1]).normalized()
	p[COUNT] = p[COUNT - 1] + last_dir * LENGTHS[COUNT - 1]
	return p

class_name BlueJays
extends CorvidFlock
## A family of blue jays: a CorvidFlock (creatures/crow/, which this needs) of
## kind BLUE_JAY, set up as jays go about. Vivid blue above with black bars and
## white tips on the wings and tail, white below, a black necklace and bridle,
## and a crest they raise and lower. Restless: they flit from branch to branch
## and tree to tree in short bounding flights (a burst of beats, wings shut a
## moment, again), drop to the ground to hop about with both feet and hammer at
## seeds, and fly back up. They call "jay! jay!" (bobbing on their perch, crest
## up), give a squeaky "queedle", and now and then (as real jays do) mimic a
## hawk's scream. `scold(point)` and they gather on the branches nearest it,
## crests up, screaming at it.
##
## Give it perches among branches (`set_perches`), and `home` and `roam` on the
## ground below them; see CorvidFlock for the rest. The model is
## creatures/blue_jay/models/blue_jay.glb (and _lo), built with the crow's by
## creatures/crow/tools/build_corvids.py.


func _init() -> void:
	kind = CorvidBody.Kind.BLUE_JAY
	count = 5
	size = 1.0
	restless = 0.09
	ground_share = 0.35
	flight_speed = 6.5
	walk_speed = 0.5
	circle_radius = 6.0
	circle_height = 7.0
	call_every = 9.0
	far_detail = 16.0
	view_range = 90.0

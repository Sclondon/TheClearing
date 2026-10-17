class_name Looks
## How each player is turned out, so that friends can tell each other apart in
## the maze. A look is one of Outside's made-up people (CharacterLook.random),
## known by its seed. The seed is what goes round the room, as a short word the
## server takes for a "hero" (lower-case letters and digits): "p" and the number.


## A new look, as its word.
static func pick() -> String:
	return "p%d" % randi_range(1, 999999)


## The look a word stands for. Anything else is the boy as he was made.
static func decode(word: String) -> Dictionary:
	if not word.begins_with("p") or not word.substr(1).is_valid_int():
		return {}
	var look := CharacterLook.random(int(word.substr(1)))
	# Everyone is the boy's size: the controller's moves are made for him.
	look.erase("size")
	look.erase("build")
	return look

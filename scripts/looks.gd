class_name Looks
## How each player is turned out. Everyone is the boy as Inside has him: no face,
## short hair and no cap, a plain shirt, dark trousers and boots. What tells
## friends apart in the maze is the colour of the shirt, which goes by seat (the
## first is Inside's red), and their skin and hair, which go by a seed each player
## picks (NEW LOOK picks another). The seed is what goes round the room, as a
## short word the server takes for a "hero" (lower-case letters and digits): "p"
## and the number.

## Shirts, by seat: red (deep, as it is the one strong colour in the picture),
## a faded blue, mustard, a dull green.
const SHIRTS: Array[Color] = [
	Color(0.7, 0.07, 0.05), Color(0.27, 0.38, 0.52), Color(0.66, 0.52, 0.2), Color(0.3, 0.42, 0.27),
]
const TROUSERS := Color(0.17, 0.17, 0.19)
const BOOTS := Color(0.17, 0.13, 0.1)
## The head everyone has (one of HeadShape.SHAPES).
const HEAD := "inside"
## And the cut of his trousers and his boots (BodyShape.CUTS and BOOTS).
const CUT := "slim"
const BOOT := "angular"


## A new look, as its word.
static func pick() -> String:
	return "p%d" % randi_range(1, 999999)


## The look a word stands for, on a seat. Anything but "p<n>" is the boy's own
## skin and hair.
static func decode(word: String, seat := 0) -> Dictionary:
	var colours := {
		"shirt": SHIRTS[posmod(seat, SHIRTS.size())], "overalls": TROUSERS, "boots": BOOTS, "socks": TROUSERS,
	}
	if word.begins_with("p") and word.substr(1).is_valid_int():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(int(word.substr(1)))
		var skin := rng.randi() % CharacterLook.SKINS.size()
		colours["skin"] = CharacterLook.SKINS[skin]
		# (dark hair mostly, as his is; fair only with fair skin)
		var hairs := 4 if skin < 4 else 3
		colours["hair"] = CharacterLook.HAIR_COLOURS[rng.randi() % hairs]
	return {"face": "base", "head": HEAD, "cut": CUT, "boots": BOOT, "hair": "crop", "cap": false, "outfit": "trousers", "colours": colours}


## Dresses a figure on the boy's rig in a look from `decode`. It is the trousers
## outfit without its braces, which CharacterLook has no outfit for, and the
## head is one of HeadShape's (the look's "head").
static func apply(rig: CharacterRig, look: Dictionary) -> void:
	var whole := CharacterLook.dressed(look)
	whole["parts"]["over"] = "none"
	whole["parts"]["head"] = HeadShape.option(look.get("head", HEAD))
	whole["parts"]["body"] = BodyShape.option(look.get("cut", CUT))
	HeadShape.add_to(rig)
	BodyShape.add_to(rig)
	BodyShape.boots(rig, look.get("boots", BOOT))
	rig.look = whole
	if rig.is_node_ready():
		rig.restyle()

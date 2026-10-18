class_name Looks
## How each player is turned out. Everyone is the same boy, as Inside has him: no
## face, short hair and no cap, a plain shirt, dark trousers and boots, with his
## own skin and hair. Only the colour of the shirt, which goes by seat (the first
## is Inside's red), tells friends apart in the maze. The look still goes round
## the room as a word (the server takes it for a "hero"), but it is always "boy".

## Shirts, by seat: red (deep, as it is the one strong colour in the picture),
## a faded blue, mustard, a dull green.
const SHIRTS: Array[Color] = [
	Color(0.7, 0.07, 0.05), Color(0.27, 0.38, 0.52), Color(0.66, 0.52, 0.2), Color(0.3, 0.42, 0.27),
]
const TROUSERS := Color(0.17, 0.17, 0.19)
const BOOTS := Color(0.17, 0.13, 0.1)
## The head everyone has (one of HeadShape.SHAPES).
const HEAD := "inside_round"
## The locks over the close crop (one of HairShape.STYLES), or "none": the close
## crop alone, short and plain. (The locks read as dreads in the game.)
const LOCKS := "none"
## The cut of his hair (one of CharacterLook.HAIRS): a pudding basin, low over the brow.
const HAIR := "bowl"
## And the cut of his trousers and his boots (BodyShape.CUTS and BOOTS).
const CUT := "shaped_slim"
const BOOT := "angular"


## The look, as its word.
static func pick() -> String:
	return "boy"


## The look on a seat. (Every word is the same boy: the word is kept only so older
## rooms' words still read.)
static func decode(_word: String, seat := 0) -> Dictionary:
	var colours := {
		"shirt": SHIRTS[posmod(seat, SHIRTS.size())], "overalls": TROUSERS, "boots": BOOTS, "socks": TROUSERS,
	}
	return {"face": "base", "head": HEAD, "locks": LOCKS, "cut": CUT, "boots": BOOT, "hair": HAIR, "cap": false, "outfit": "trousers", "colours": colours}


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
	HairShape.add_to(rig)
	whole["parts"]["locks"] = look.get("locks", LOCKS)
	BodyShape.boots(rig, look.get("boots", BOOT))
	rig.look = whole
	if rig.is_node_ready():
		rig.restyle()

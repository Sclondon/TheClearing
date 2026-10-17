class_name CharacterLook
## How a figure built like the boy may be turned out: every face, cut of hair,
## set of clothes and colour there is a choice of, in one place, and a way to
## make someone up at random.
##
## A look is a Dictionary, and is what CharacterRig.look takes:
##   "face"    one of FACES, by name          "hair"   one of HAIRS, by name
##   "outfit"  one of OUTFITS, by name        "cap"    whether a cap is worn
##   "colours" material name -> Color (what is not named is as the model was made)
##   "parts"   slot -> option: which objects of the model show. This is worked
##             out from the four above (see `parts_for`), not chosen directly.
##   "size", "build", "sex"  how tall and how broad, as factors of the boy, and
##             which this is: used by whoever stands the figure up (see `apply`)
##
## The objects themselves are built by tools/build_boy.py ("Other turn-outs"
## there lists them): each is a mesh named `boy_<slot>__<option>`, and
## CharacterRig.restyle shows the one named for its slot. Add an option there
## and name it here.

enum Sex { ANY, MALE, FEMALE }

## Faces: [name, label]. The name is the option of the slot `face`; `base` is
## the plain face he was made with. `sculpt` is a face modelled into the head
## (brow, sockets, nose, cheeks, lips and chin as form), with eyes that have
## whites and turn to what he looks at; the others are features set on an egg.
const FACES := [["base", "Plain"], ["sculpt", "Sculpted"], ["full", "Eyes, nose and mouth"], ["dots", "Dot eyes and nose"], ["light", "Nose and brows"]]
## What else of the model a face shows, where it is more than its own option of
## the slot `face`: the sculpted face is a head of its own.
const FACE_PARTS := {"sculpt": {"head": "sculpt"}}

## Cuts of hair. "hair" is the option of the slot `hair` (what shows with or
## without a cap), "bare" that of the slot `hairtop` without a cap and "capped"
## with one: a cap hides the top of every cut, and the boy's own curls then show
## a forelock under its peak instead.
##
## "wavy" says which of the two hair shaders a cut has: the curly one
## (Toon.HAIR_SHADER) or the waved one (Toon.WAVY_HAIR_SHADER). It is the model
## that decides it, by the material it gives the cut (`hair` or `hairwavy`, in
## CUTS in tools/build_boy.py): this only records what is built. "grown", where
## it is given, says that only the grown wear it (true), or only children
## (false), when somebody is made up at random; anyone may be given any of them.
const HAIRS := [
	{"name": "mullet", "label": "Mullet", "hair": "base", "bare": "crown", "capped": "base", "sex": Sex.MALE},
	{"name": "long", "label": "Long curls", "hair": "long", "bare": "crown", "capped": "base", "sex": Sex.ANY},
	{"name": "crop", "label": "Cropped", "hair": "crop", "bare": "crop", "capped": "none", "sex": Sex.MALE},
	{"name": "bowl", "label": "Pudding basin", "hair": "bowl", "bare": "bowl", "capped": "none", "sex": Sex.MALE, "grown": false},
	{"name": "parting", "label": "Side parting", "hair": "parting", "bare": "parting", "capped": "none", "sex": Sex.MALE},
	{"name": "slick", "label": "Combed back", "hair": "slick", "bare": "slick", "capped": "none", "sex": Sex.MALE, "grown": true},
	{"name": "curtains", "label": "Centre parting", "hair": "curtains", "bare": "curtains", "capped": "none", "sex": Sex.MALE, "wavy": true},
	{"name": "quiff", "label": "Pompadour", "hair": "quiff", "bare": "quiff", "capped": "none", "sex": Sex.MALE, "wavy": true},
	{"name": "curls", "label": "Big curls", "hair": "curls", "bare": "curls", "capped": "none", "sex": Sex.ANY},
	{"name": "bob", "label": "Bob", "hair": "bob", "bare": "bob", "capped": "none", "sex": Sex.FEMALE},
	{"name": "waved", "label": "Waved bob", "hair": "waved", "bare": "waved", "capped": "none", "sex": Sex.FEMALE, "wavy": true},
	{"name": "plaits", "label": "Plaits", "hair": "plaits", "bare": "plaits", "capped": "none", "sex": Sex.FEMALE},
	{"name": "ponytail", "label": "Ponytail", "hair": "ponytail", "bare": "ponytail", "capped": "none", "sex": Sex.FEMALE},
	{"name": "bun", "label": "Low knot", "hair": "bun", "bare": "bun", "capped": "none", "sex": Sex.FEMALE, "grown": true},
	{"name": "gibson", "label": "Pompadour and knot", "hair": "gibson", "bare": "gibson", "capped": "none", "sex": Sex.FEMALE, "wavy": true, "grown": true},
	{"name": "waves", "label": "Long waves and a bow", "hair": "waves", "bare": "waves", "capped": "none", "sex": Sex.FEMALE, "wavy": true, "grown": false},
]

## Clothes. "parts" names an option for each slot of clothing; "garments" is
## what of it can be coloured, as [label, material]; "same" lists materials that
## take the colour of another (a dress is bodice and skirt in one cloth); "wear"
## is what it is given when it is first put on, where that is not as the model
## was made; "grown" is whether a man or woman would wear it, or only a child.
const OUTFITS := [
	{"name": "overalls", "label": "Overalls", "sex": Sex.MALE, "grown": false,
		"parts": {"body": "base", "over": "base", "patch": "base", "skirt": "none"},
		"garments": [["Shirt", "shirt"], ["Overalls", "overalls"], ["Patch", "patch"], ["Socks", "socks"], ["Boots", "boots"], ["Cap", "cap"]]},
	{"name": "breeches", "label": "Breeches and braces", "sex": Sex.MALE, "grown": false,
		"parts": {"body": "base", "over": "braces", "patch": "none", "skirt": "none"},
		"garments": [["Shirt", "shirt"], ["Breeches", "overalls"], ["Braces", "braces"], ["Socks", "socks"], ["Boots", "boots"], ["Cap", "cap"]]},
	{"name": "waistcoat", "label": "Breeches and waistcoat", "sex": Sex.MALE, "grown": false,
		"parts": {"body": "base", "over": "waistcoat", "patch": "none", "skirt": "none"},
		"garments": [["Shirt", "shirt"], ["Breeches", "overalls"], ["Waistcoat", "waistcoat"], ["Socks", "socks"], ["Boots", "boots"], ["Cap", "cap"]]},
	{"name": "trousers", "label": "Trousers and braces", "sex": Sex.MALE, "grown": true,
		"parts": {"body": "long", "over": "braceslong", "patch": "none", "skirt": "none"},
		"garments": [["Shirt", "shirt"], ["Trousers", "overalls"], ["Braces", "braces"], ["Boots", "boots"], ["Cap", "cap"]]},
	{"name": "trousers_waistcoat", "label": "Trousers and waistcoat", "sex": Sex.MALE, "grown": true,
		"parts": {"body": "long", "over": "waistcoatlong", "patch": "none", "skirt": "none"},
		"garments": [["Shirt", "shirt"], ["Trousers", "overalls"], ["Waistcoat", "waistcoat"], ["Boots", "boots"], ["Cap", "cap"]]},
	{"name": "suit", "label": "Jacket and trousers", "sex": Sex.MALE, "grown": true,
		"parts": {"body": "suit", "over": "none", "patch": "none", "skirt": "none"},
		"garments": [["Jacket", "jacket"], ["Shirt", "shirt"], ["Trousers", "overalls"], ["Boots", "boots"], ["Cap", "cap"]]},
	{"name": "dress", "label": "Dress", "sex": Sex.FEMALE, "grown": true,
		"parts": {"body": "dress", "over": "none", "patch": "none", "skirt": "dress"},
		"same": {"shirt": "overalls"}, "wear": {"overalls": Color(0.42, 0.52, 0.56)},
		"garments": [["Dress", "overalls"], ["Collar", "apron"], ["Stockings", "socks"], ["Boots", "boots"], ["Cap", "cap"]]},
	{"name": "pinafore", "label": "Dress and pinafore", "sex": Sex.FEMALE, "grown": false,
		"parts": {"body": "dress", "over": "pinafore", "patch": "none", "skirt": "dress"},
		"same": {"shirt": "overalls"}, "wear": {"overalls": Color(0.50, 0.36, 0.34)},
		"garments": [["Dress", "overalls"], ["Pinafore", "apron"], ["Stockings", "socks"], ["Boots", "boots"], ["Cap", "cap"]]},
	{"name": "skirt", "label": "Skirt and blouse", "sex": Sex.FEMALE, "grown": true,
		"parts": {"body": "dress", "over": "none", "patch": "none", "skirt": "dress"},
		"wear": {"shirt": Color(0.92, 0.89, 0.80), "overalls": Color(0.36, 0.31, 0.30)},
		"garments": [["Blouse", "shirt"], ["Skirt", "overalls"], ["Collar", "apron"], ["Stockings", "socks"], ["Boots", "boots"], ["Cap", "cap"]]},
]

## Skin, fair to dark. The third is the one the boy was made with.
const SKINS: Array[Color] = [
	Color(0.95, 0.82, 0.72), Color(0.89, 0.74, 0.62), Color(0.82, 0.66, 0.55), Color(0.76, 0.58, 0.43),
	Color(0.66, 0.47, 0.34), Color(0.53, 0.36, 0.26), Color(0.40, 0.27, 0.20), Color(0.29, 0.19, 0.15),
]
## Hair. The first is the one the boy was made with.
const HAIR_COLOURS: Array[Color] = [
	Color(0.23, 0.165, 0.12), Color(0.075, 0.065, 0.06), Color(0.15, 0.10, 0.075), Color(0.36, 0.21, 0.12), Color(0.50, 0.22, 0.12),
	Color(0.71, 0.38, 0.17), Color(0.62, 0.48, 0.30), Color(0.82, 0.69, 0.44), Color(0.56, 0.55, 0.53), Color(0.86, 0.85, 0.81),
]
## Eyes (the ring of colour in each, on the sculpted face). The first is the one the boy was made with.
const EYE_COLOURS: Array[Color] = [
	Color(0.36, 0.25, 0.16), Color(0.20, 0.14, 0.10), Color(0.45, 0.36, 0.20), Color(0.36, 0.44, 0.30), Color(0.38, 0.50, 0.60), Color(0.46, 0.50, 0.52),
]
## Cloth, as it was then: nothing bright, and most of it washed out.
const SHIRTS: Array[Color] = [
	Color(0.90, 0.85, 0.72), Color(0.93, 0.92, 0.87), Color(0.74, 0.80, 0.84), Color(0.80, 0.78, 0.72), Color(0.84, 0.74, 0.70), Color(0.78, 0.72, 0.56),
]
const CLOTHS: Array[Color] = [
	Color(0.47, 0.55, 0.65), Color(0.36, 0.42, 0.52), Color(0.40, 0.33, 0.26), Color(0.33, 0.33, 0.35), Color(0.30, 0.36, 0.30),
	Color(0.52, 0.47, 0.38), Color(0.23, 0.26, 0.33), Color(0.38, 0.27, 0.23),
]
const DRESSES: Array[Color] = [
	Color(0.42, 0.52, 0.56), Color(0.50, 0.36, 0.34), Color(0.46, 0.52, 0.42), Color(0.62, 0.55, 0.40), Color(0.40, 0.34, 0.40),
	Color(0.26, 0.30, 0.40), Color(0.62, 0.60, 0.56), Color(0.58, 0.44, 0.42),
]
const LEATHERS: Array[Color] = [Color(0.25, 0.15, 0.09), Color(0.17, 0.11, 0.075), Color(0.10, 0.09, 0.09), Color(0.36, 0.23, 0.13)]
const STOCKINGS: Array[Color] = [Color(0.60, 0.56, 0.50), Color(0.20, 0.19, 0.19), Color(0.86, 0.84, 0.78), Color(0.42, 0.36, 0.30)]


## The entry of FACES, HAIRS or OUTFITS called `name` (the first, if there is none).
static func hair(name: String) -> Dictionary:
	return _named(HAIRS, name)


static func outfit(name: String) -> Dictionary:
	return _named(OUTFITS, name)


static func _named(list: Array, name: String) -> Dictionary:
	for entry: Dictionary in list:
		if entry["name"] == name:
			return entry
	return list[0]


## Which option of each slot of the model shows, for a face, a cut of hair,
## clothes, and a cap on or off. For the boy as he was made this names `base`
## for everything, which is what is shown when nothing is named at all.
static func parts_for(hair_name: String, capped: bool, face: String, outfit_name: String) -> Dictionary:
	var cut := hair(hair_name)
	var parts: Dictionary = outfit(outfit_name)["parts"].duplicate()
	parts["face"] = face
	parts["head"] = "base"
	parts.merge(FACE_PARTS.get(face, {}), true)
	parts["hair"] = cut["hair"]
	parts["hairtop"] = cut["capped"] if capped else cut["bare"]
	return parts


## The colours that follow from others: lips from the skin, and whatever an
## outfit makes of one cloth. Changes and returns `colours`.
static func matched(colours: Dictionary, outfit_name: String) -> Dictionary:
	if colours.has("skin"):
		var skin: Color = colours["skin"]
		colours["mouth"] = Color(skin.r * 0.74, skin.g * 0.54, skin.b * 0.56)
	var same: Dictionary = outfit(outfit_name).get("same", {})
	for material: String in same:
		if colours.has(same[material]):
			colours[material] = colours[same[material]]
		else:
			colours.erase(material)
	return colours


## A look with everything in it that follows from its choices ("parts", and the
## matched colours), ready to be a rig's `look`. A copy: `look` is left alone.
static func dressed(look: Dictionary) -> Dictionary:
	var whole := look.duplicate(true)
	var worn: String = whole.get("outfit", "overalls")
	var colours: Dictionary = whole.get("colours", {})
	var wear: Dictionary = outfit(worn).get("wear", {})
	for material: String in wear:
		if not colours.has(material):
			colours[material] = wear[material]
	whole["colours"] = matched(colours, worn)
	whole["cap"] = whole.get("cap", true)
	whole["parts"] = parts_for(whole.get("hair", "mullet"), whole["cap"], whole.get("face", "base"), worn)
	return whole


## Turns a figure out as `look` says. The figure must be the boy's model (a rig
## with no `model` of its own): nothing else has these parts. Its size is not
## changed here: scale the rig by "size" (and "build" across) for that.
static func apply(rig: CharacterRig, look: Dictionary) -> void:
	rig.look = dressed(look)
	if rig.is_node_ready():
		rig.restyle()


## Somebody made up: a look that hangs together (clothes of one palette, hair
## that goes with them, a cap on some), with a "size" (1 is the boy; children
## run from 0.86, grown men and women to 1.45) and a "build" (how broad for
## that height). The same `seed` gives the same person; -1 is anyone. `face`
## fixes the kind of face, where everyone in a place should have the same.
static func random(seed := -1, sex := Sex.ANY, face := "") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed < 0:
		rng.randomize()
	else:
		rng.seed = hash(seed)
	if sex == Sex.ANY:
		sex = Sex.MALE if rng.randf() < 0.5 else Sex.FEMALE
	# How old: a child, half grown, or grown
	var age := rng.randf()
	var grown := age > 0.55
	var size := rng.randf_range(0.86, 1.08) if age < 0.35 else rng.randf_range(1.1, 1.26) if not grown else rng.randf_range(1.3, 1.45)
	if sex == Sex.FEMALE and grown:
		size -= 0.05

	var outfits: Array = OUTFITS.filter(func(entry: Dictionary) -> bool: return entry["sex"] == sex and (entry["grown"] or not grown))
	var worn: Dictionary = outfits[rng.randi() % outfits.size()]
	var cuts: Array = HAIRS.filter(func(entry: Dictionary) -> bool: return (entry["sex"] == sex or entry["sex"] == Sex.ANY) and entry.get("grown", grown) == grown)
	var cut: Dictionary = cuts[rng.randi() % cuts.size()]

	# Skin and hair: fair hair goes with fair skin, and grey with age
	var skin := rng.randi() % SKINS.size()
	var hairs: Array[Color] = HAIR_COLOURS.slice(0, 8) if skin < 4 else HAIR_COLOURS.slice(0, 4)
	var hair_colour: Color = hairs[rng.randi() % hairs.size()]
	if grown and rng.randf() < 0.18:
		hair_colour = HAIR_COLOURS[8 + rng.randi() % 2]
	var colours := {"skin": SKINS[skin], "hair": hair_colour}

	# Clothes: one cloth for what is below the waist, a paler thing above it,
	# and anything over that (a waistcoat, a jacket, a cap) in a second cloth
	# that is often the first again.
	var cloth: Color = CLOTHS[rng.randi() % CLOTHS.size()]
	var second: Color = cloth.darkened(0.12) if rng.randf() < 0.4 else CLOTHS[2 + rng.randi() % 4]
	colours["shirt"] = SHIRTS[rng.randi() % SHIRTS.size()]
	colours["overalls"] = cloth
	colours["waistcoat"] = second
	colours["jacket"] = second if rng.randf() < 0.5 else cloth
	colours["cap"] = second if rng.randf() < 0.6 else cloth.lightened(0.08)
	colours["patch"] = cloth.lerp(Color(0.55, 0.45, 0.34), 0.7)
	colours["braces"] = LEATHERS[rng.randi() % LEATHERS.size()].lightened(0.25)
	colours["boots"] = LEATHERS[rng.randi() % LEATHERS.size()]
	colours["socks"] = STOCKINGS[rng.randi() % STOCKINGS.size()]
	if sex == Sex.FEMALE:
		colours["overalls"] = DRESSES[rng.randi() % DRESSES.size()]
		colours["socks"] = STOCKINGS[rng.randi() % 3]
		# (a girl's cap is an oddity: let it be her skirt's colour, or a brother's)
		colours["cap"] = second
	var capped := rng.randf() < (0.5 if sex == Sex.MALE else 0.08)
	# (nearly everyone has the sculpted face; a few have one of the simpler ones)
	var faces := ["sculpt", "sculpt", "sculpt", "sculpt", "sculpt", "sculpt", "full", "dots"]
	var someone := {
		"face": face if face != "" else faces[rng.randi() % faces.size()],
		"hair": cut["name"],
		"outfit": worn["name"],
		"cap": capped,
		"colours": colours,
		"sex": sex,
		"size": size,
		# (a child is as the boy is; the grown are narrower for their height, or their heads would be vast)
		"build": rng.randf_range(0.94, 1.04) if not grown else rng.randf_range(0.86, 0.96),
	}
	# Eyes: light ones go with fair skin. (Chosen last, so that a seed gives
	# the same person as it did before there were eyes to colour.)
	var eyes: Array[Color] = EYE_COLOURS if skin < 4 else EYE_COLOURS.slice(0, 3)
	colours["iris"] = eyes[rng.randi() % eyes.size()]
	return dressed(someone)

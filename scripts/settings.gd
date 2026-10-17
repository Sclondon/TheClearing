class_name Settings
## Choices made in the menu. They last across level changes, not across runs.

## Use the demade, low-poly models for every figure.
static var low_poly := false
## Shade the world in hard bands of light, like the figures, rather than smoothly.
static var world_banded := false

## How the boy is turned out. Each of these is one of the lists in CharacterLook
## (scripts/character_look.gd), by name; setting any of them works out `parts`
## again, and a rig shows the change at its next `restyle()`.
## Whether he wears his cap.
static var cap := true:
	set(value):
		cap = value
		dress()
## How his hair is cut: "mullet" (short at the sides, a little long behind),
## "long" (long curls), or any other of CharacterLook.HAIRS.
static var hair := "mullet":
	set(value):
		hair = value
		dress()
## His face: "base" (plain, as he was made) or another of CharacterLook.FACES.
static var face := "base":
	set(value):
		face = value
		dress()
## What he wears: "overalls" or another of CharacterLook.OUTFITS.
static var outfit := "overalls":
	set(value):
		outfit = value
		dress()
## The colours of his clothes, skin and hair, by the name of the material
## (`shirt`, `overalls`, `cap`, `skin`...: see MATERIALS in tools/build_boy.py).
## What is not here is as he was made.
static var colours := {}
## Which object of his model shows for each slot (see CharacterRig.restyle).
## Worked out from the choices above: do not set it directly.
static var parts := {}


## What he wears that is not part of his model (see Worn, scripts/worn.gd): a
## helmet, by name (one of Worn.HELMETS; "" is none), which takes the place of
## his cap while it is on, and whether he has the backpack on his back.
## `Worn.dress_boy(rig)` puts them on him.
static var helmet := ""
static var backpack := false

## A gamepad's right stick: how fast it turns the camera (1 is as it was made; 0.4 to 2), and whether pushing it
## away looks down rather than up.
static var look_speed := 1.0
static var look_invert := false


## Works out `parts` from what has been chosen.
static func dress() -> void:
	parts = CharacterLook.parts_for(hair, cap, face, outfit)


## Dresses him as a look says (see CharacterLook).
static func wear(look: Dictionary) -> void:
	var whole := CharacterLook.dressed(look)
	colours = whole["colours"]
	face = whole.get("face", "base")
	outfit = whole.get("outfit", "overalls")
	hair = whole.get("hair", "mullet")
	cap = whole["cap"]


## Him as he was made.
static func undress() -> void:
	wear({})

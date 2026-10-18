# Flesh mound

People grown together, for Godot 4.7 (works in GL Compatibility, so on the web
and phones). One creature in many sizes: `bodies` says how many are in it,
and that says its form (`form()`, `FleshMoundLook.Form`): a pair, an amalgam,
a strider, a ball or a mound.

- **A pair, 2 bodies.** Two boys grown together back to back along their
  length, the one under on all fours, the one on top lying face up, his head
  hanging off its back end, his arms and legs waving in the air like an
  upturned beetle's. It scuttles on the four limbs under it, splayed like a
  crab's. It rushes: `start_roll()` crouches it (the warning), then it
  scuttles flat out, the limbs on top thrown forward, until `stop_roll()`.
- **An amalgam, 3 or 4 bodies.** Boys fused at the hips in a star, a
  wheel of arms and legs about as high as two of them, their blank mask faces
  lolling. It shambles on whichever limbs are under it, lurching, hands and
  feet planting and pushing. It cartwheels: it rears with its limbs splayed
  (the warning), then tips onto them and rolls like a wheel, hands and feet
  slapping down in turn.
- **A strider, 5 or 6 bodies.** The boys joined at the hips in a ring held up
  on their legs, each bent over outwards, heads hanging, arms groping at the
  floor: it walks on ten or twelve legs and faces every way, the ring turning
  slowly as it goes. It grabs (`grab(target)`): the ring tips and lunges at
  the target and the boys facing it throw their arms at it.
- **A ball, 7 or 8 bodies.** The boys grown together into a sphere as high as
  two men, heads, shoulders and arms out all round it. It rolls wherever it
  goes, turning on its own axle by how fast it moves, the arms that come
  round under it slapping down on the ground.
- **A mound, 9 or 10 bodies.** A heaving mound of grown-together flesh, bigger the
  more are in it (at 10 about 6 m across and 4 high, its limbs reaching
  further). The boys lie sunk in it face up (their mask faces out) or face down
  (their backs out), or rise from it to the waist; men lie sunk in it to their ribs;
  men's arms, long gaunt arms and legs grow out of it between them. It hauls
  itself along on the hands at its flanks (on the walls, where they are near),
  gropes ahead with the hands at its front, and grabs with them. The arms on
  its top reach and open and close, others hang limp, legs kick weakly.
- **Growing.** `absorb(point)` drags a body in from there (seen dragged in
  backwards, arms reaching out of it) and it gains one; `merge_into(other)`
  reaches for another, stretches a bridge of skin to it and
  pours itself along it into the other, which then `grow`s by its bodies. Past a form's most
  bodies it is the next form: 2 a pair, 3 and 4 an amalgam, 5 and 6 a strider, 7 and 8 a ball, 9 up a mound.

No mouth, no teeth, hardly any blood: one pallid, waxy, matte skin (greys and ashen
yellows, bruise purples in patches) flowing
from body to body and over the mass between them, gathered in folds and webbed
where a body is knitted into it, bodies pressing it out from underneath (backs,
buttocks, shoulders, limbs),
folded, stretch-marked, veined, swollen with boils of pus and weeping in
patches. Cel shaded in hard bands. This is the look and the motion only: your
game moves it and decides what catching means.

Made for Warren (scripts/enemies/flesh_mound.gd is its hunter there).

## Files

- `flesh_mound.gd` (`FleshMound`, a Node3D): the creature.
- `flesh_mound_look.gd` (`FleshMoundLook`): the core's mesh and shader (made in
  code), the trail, and how the people in it are laid out for each number of
  bodies.
- `flesh_parts.gd` (`FleshParts`): the people it is made of and the means to
  put copies of them together into one skinned mesh and pose them (IK arms and
  legs, hands that close, claw and spread, a spine and a head), and their skin.
- `models/parts.glb`, `parts_lo.glb`: men's arms, long gaunt arms, legs and a
  wasted torso, every finger in three joints, made in Blender by
  `tools/build_parts.py` (`blender --background --python creatures/flesh_mound/tools/build_parts.py [-- <preview folder>]`).
- `example.gd`: a mound and an amalgam on a flat floor after a stand-in.

**Needs `godot/character-controller`** for the boy (`models/boy.glb` and
`boy_lo.glb`; only his bare body is used: the long-sleeved body, hands and
feet, and the blank head).

## Use

```gdscript
var mound := FleshMound.new()
mound.bodies = 3                                   # small: an amalgam
add_child(mound)
# Then each frame:
mound.global_position = mover.global_position      # on the ground
mound.rotation.y = heading                         # it faces -Z (and rolls along -Z)
mound.aim = prey.global_position                   # or Vector3.INF
if mound.small():
	mound.start_roll()                             # rear (roll_wind_up s), then roll
	# ... move it fast while roll_stage() == ROLLING; stop_roll() when done
elif prey_in_reach:                                # within mound.reach() ahead
	mound.grab(prey.global_position)               # wind-up, strike, hold, recover
if mound.grab_hits(feet, head, 0.3) or mound.touches(chest, 0.2):
	mound.absorb(feet)                             # it drags a body in and grows
```

- **Speed.** It works out its own speed from how it moves (a small one turns
  its wheel by it, rolling without slipping). If it moves in jumps, set `moving`.
- **Rolling (rushing).** `start_roll()`, `stop_roll()`, `roll_stage()` (NONE, WIND_UP,
  ROLLING): an amalgam cartwheels, a pair rushes. An amalgam's hub rides on whichever limbs are under it.
- **Grabbing.** `grab(target)`, `grab_stage()`, `strikes_in()`, `grab_target()`,
  `reach()`, `grab_hits(a, b, r)`, `hands()`. Striders and mounds only.
- **Squeezing.** A mound, with `measure_room` on, casts rays to either side
  against `room_mask` five times a second and squeezes narrower, taller and
  longer in a narrow space; `sides()` says how far the walls are.
- **Growing.** `absorb(point)`, `absorbing()`, `merge_into(other)`,
  `merging()`, the `merged(into)` signal (then call `into.grow(its bodies)`),
  `grow(count)`, the `grown(bodies)` signal. Up to FleshMoundLook.MOST (10).
- **Settling.** Call `settle()` after putting it somewhere in a jump.

## Cost

Three draws: the core (one mesh, its heaving in the shader), all the people in
it (one skinned mesh on one skeleton), the trail; and shadows. The people are
posed each frame (about 0.3 ms for an amalgam, 0.9 ms for nine bodies on a
desktop; limbs that only hang are posed a quarter as often). The boys in mounds
of 7 or more are the low-detail boy. Set `FleshMound.low_poly` before making
one for the low-detail parts throughout. Changing the number of bodies builds
the people again, from a cache: the first time for each number takes a moment
(about 0.2 s), so each one builds the next size up as soon as it is made, and
`FleshMound.prepare([counts])` builds any beforehand. Hide one, or disable its
processing, when nobody is near.

## Try it

Put it in a game (with the character controller first, for the boy):

```
sh kit.sh install godot/character-controller <game>
sh kit.sh install godot/flesh-mound <game>
```

then `example.gd` on a Node3D: a mound and an amalgam after a stand-in on a flat floor, grabbing, rolling,
absorbing it, and the amalgam flowing into the mound when they meet. Global class names: `FleshMound`,
`FleshMoundLook`, `FleshParts`.

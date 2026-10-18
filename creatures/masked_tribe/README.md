# The masked tribe

A hunting party of lost boys gone wild, after Lord of the Flies: boys like the players (the very same body, the boy
of the character controller), who went feral in the maze long ago. Bare to the waist, their skin daubed grey with clay
and striped with ash; breeches cut off at the knee with a fringe of torn rags knotted over them (what is left of their
shirts); bare, muddy feet; each face hidden entirely behind a big crude carved mask, tied on over a matted mass of
hair and dead grass: a long face of grey wood with horns of stick, a bleached beast's skull with antlers of stick, a
round bark face in a crown of sharpened sticks, a white clay oval under a fan of black feathers with strings of teeth
at its chin, a tusked beast's face hung with strips of bark. Every eye of them is a hole into the dark. Each carries
a sharpened stick of a spear with a knapped stone or a bone point, bound with cord, a rag tied by its butt. They are
a fictional tribe of the maze's own boys, not any people that ever was.

They stand hunched and patrol in single file, drum the butts of their spears on the ground and chant when they find
someone, draw back and throw (side on, the spear over the shoulder along the aim, the other arm straight out at you,
with a yell), and jab close up with both hands on the shaft. The spear flies on its own, falling as it goes, and
sticks quivering in whatever it meets. A totem marks where a party camps: a pole of dead wood in a cairn of stones, a
great beast's skull on top, hung with bones and teeth, sharpened sticks round its foot.

It is only the look, the motion and the sound. It does no thinking: your game moves them and tells them when to act.
Made for Warren, 2026-10-18 (its `MazeTribesman` is the thinking that drives them there).

## Needs

GameCommon's `godot/character-controller` (the rig, `TribesmanRig`, extends `CharacterRig`, and the boy is dressed
with its `Looks`, `HeadShape`, `BodyShape`, `HairShape`, `CharacterLook`; also `Toon`, `Dust`, `Settings`, `Player`).
Global class names: `Tribesman`, `TribesmanRig`, `TribeSpear`.

## Use

```gdscript
var man := Tribesman.new()
man.mask = 2                            # 0..4
man.point = TribeSpear.Point.BONE       # or STONE
add_child(man)
man.put(spawn_point, spawn_yaw)

# every frame, from your own body (a CharacterBody3D, a path follower...):
man.global_position = body_position
man.rotation.y = facing_yaw             # 0 faces +Z
man.velocity = body_velocity            # the boy's walk, run and sprint go with this
man.stalking = false                    # true: he creeps, crouched (the boy's sneak)
man.aim = target + Vector3.UP           # what he looks at, throws at and jabs at (INF: nothing)

man.chant()                             # drums and chants; `called` at the first blow
man.wind_up()                           # drawn back on `aim`, held until...
man.loose(Tribesman.launch(man.spear_point(), target, 16.0, man.spear.gravity))   # `released`
man.jab()                               # `thrusting`; test jab_hits(feet, height, radius) in THRUST and HOLD
man.pick_up()                           # stoops and takes his spear up from where it lies near him
man.rearm()                             # or it is back in his hand at once
```

- `doing()` (`TribesmanRig.Act`: NONE, CHANT, THROW, JAB), `stage()` (`TribesmanRig.Stage`: CHANT, WIND, LOOSE,
  FOLLOW, GATHER, THRUST, HOLD, RECOVER), `busy()`, `armed()`, `cancel()`, `Tribesman.act_length(act)`, `eyes()`.
- `man.spear` is his `TribeSpear` (top level): `held()`, `flying()`, `tip()`, `lying_at()`, `landed(at, stuck)`,
  and `hits(feet, height, radius)`: whether its last stretch of flight went through an upright body (one ducked
  under it is missed). `TribeSpear.passes(a, b, feet, height, radius)` is the test itself. It sticks in anything on
  `collision_mask` (the world, layer 1).
- `Tribesman.launch(from, to, speed, gravity)`: the flat, quick throw that comes down on `to`.
- `Tribesman.totem()`: the totem, a MeshInstance3D with its foot at its origin.
- Exports: `mask`, `point`, `low_poly` (or `Settings.low_poly`), `sound`, `volume_db`, `sound_range`, `clay_tint`.

## How it moves

The boy's own walk, run, sprint, sneak, panting and stoop are kept (CharacterRig), hunched a little more; over them:
the spear carried upright with its butt by his foot when he stands, low at his side at the balance, point forward
and up, when he goes (level and forward at a run). The call: the spear held upright and lifted slowly, then driven
down on each of four blows, his knees giving and his head going back, his free fist pumping up beside it. The throw:
turned side on, leaning back, the spear drawn back over his shoulder and tipped up along the aim, the shaft
trembling, the other arm straight out at you; then whipped over and through, and a follow through bent forward, the
hand open. The jab: both hands on the shaft, drawn back low at the hip and crouched, then driven straight out at
you in a lunge, held, and drawn back. His head follows `aim` and nothing else.

## Sound

Made in code (nothing to load). `Tribesman.chant_sound()`: spear butts thudding on hard ground, four blows, and a
hoarse boy's voice barking with each, "hu! hu! hu!", the last a long rising "haa-ah", a second voice a little behind
and off pitch. 1.75 s. `Tribesman.yell_sound()`: the throw's "hyah!", rising and breaking off. 0.5 s.

## Models

`tools/build_tribe.py` builds them in Blender 4.3 (no character tools needed: they are hung on the boy's joints,
not skinned to him):

    blender --background --python creatures/masked_tribe/tools/build_tribe.py [-- <folder for preview renders>]

- `models/masks.glb`: the five masks (`mask0`..`mask4`, in the space of the boy's head joint) and the fringe of
  rags (`rags`, in the space of his hips joint). About 3,000 to 5,000 triangles a mask; `masks_lo.glb` 600 to 950.
- `models/spears.glb`: `spear_stone` and `spear_bone`, the grip at the origin, the point down -Z (680 triangles;
  `_lo` 190).
- `models/totem.glb`: 9,000 triangles (`_lo` 1,800).

Everything is one material whose tones are the vertex colours (`Tribesman.carved()`: the figures' cel shading reading
them), so each mask, spear, the rags and the totem are one surface each. A tribesman in sight costs what a runner
does (the boy) and three draws more (mask, rags, spear), six with their shadows; posing him costs about 0.18 ms a
frame (the boy's rig alone: 0.15 ms).

## Try it

`example.gd` on a Node3D: a party of three by their totem on a flat floor, and a post with a board behind it. They
stand about; one drums and chants; one draws back and throws at the post, and the spear sticks in the board; he
walks over and takes it up again; another creeps up and jabs the post; they walk back.

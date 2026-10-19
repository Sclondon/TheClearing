# The woodsman

After the woodsman of *Over the Garden Wall*: a tall, gaunt, weary old man in a long coat and a battered top hat,
a felling axe over his shoulder and an oil lantern held out before him. A long grey beard, hollow cheeks, a long
thin nose, small pale eyes deep under the brim; the coat open in front and ragged at the hem, its collar turned up,
a rope round his waist. The lantern (a hurricane lamp of dark tin) is the one warm thing in the grey: its glass
glows, and its one light lights the ground and the walls round him, but not him (he is drawn on a render layer of
his own that its light leaves out), so he stands dark against what he lights, as he does in the story.

He walks slowly and stooped, holds his lantern up at whoever is there, chops at what is in front of him (three
blows, the axe drawn back high over his shoulder and brought down across), and raises the axe high over his head
and brings it straight down.

It is only the look, the motion and the sound. He does no thinking: your game moves him. Made for Warren,
2026-10-18 (the user: "Lets add a woodsmen with an axe and top hat and lantern"; its `MazeWoodsman` is his thinking).

## Needs

GameCommon's `godot/character-controller` (the rig, `WoodsmanRig`, extends `CharacterRig`; he is dressed with its
`Looks`, and uses `Toon` and `Settings`). Global class names: `Woodsman`, `WoodsmanRig`, `OilLantern`.

## Use

```gdscript
var man := Woodsman.new()
add_child(man)
man.put(spawn_point, spawn_yaw)
# each frame:
man.global_position = body_position
man.rotation.y = facing_yaw            # 0 faces +Z
man.velocity = body_velocity           # the boy's walk goes with this
man.aim = something + Vector3.UP       # what he looks at (INF: nothing)
man.raise = 1.0                        # the lantern held up at `aim` (0: at his waist)
# when you like:
man.chop()                             # three chops at `aim`; `chopped` as each bites
man.swing()                            # the axe up over his head, held (the warning) until...
man.strike()                           # ...it comes down; `struck`, and blade() is where it is
man.grunt()                            # his warning, "hmm-mm"
```

- `doing()`, `stage()` (`WoodsmanRig.Act`: NONE, CHOP, SWING; `Stage`: DRAW, STROKE, BACK, WIND, STRIKE,
  THROUGH), `busy()`, `raised()`, `cancel()`, `blade()`, `eyes()`.
- He is drawn `SIZE` (1.62) times as tall as the boy and `BUILD` (0.86) as broad for it; he scales himself.
- `lantern` is his `OilLantern` (top level): `glow` (0..1, eased), `light_range`, `light_energy`, `flame`,
  `lights` (off, or `Settings.low_poly`: no light, the glass and a soft halo only), `leaves_out` (render layers
  its light leaves out), `light_point()`. It hangs from `hold` as a pendulum and creaks when it swings hard.
- Exports: `low_poly` (or `Settings.low_poly`), `sound`, `volume_db`, `sound_range`, `lights`.

## Sound

Made in code, nothing to load: `Woodsman.chop_sound()` (the axe biting: a knock, a thud, the crack of stems and a
patter of leaves), `step_sound()` (an old boot in the mud, on the rig's footfalls), `grunt_sound()` (a deep, hoarse
"hmm-mm" and a breath out), `swish_sound()` (the axe coming down), and `OilLantern.creak_sound()` (the tin bail
squeaking in its ears).

## Models

`tools/build_woodsman.py` builds `models/woodsman.glb` and `woodsman_lo.glb` in Blender 4.3 (hung on the boy's
joints, not skinned: no character tools needed):

    blender --background --python creatures/woodsman/tools/build_woodsman.py [-- <folder for preview renders>]

`head` (head joint space; the boy's own head, hair and face are hidden), `coat` (hips), `collar` (chest), `axe`
(in his right fist), `lantern` and `lantern_glass`. One material of vertex colours (the figures' cel shading reads
them) but for the glass: about 7,700 triangles (`_lo` 1,800). In sight he costs what a runner does (the boy) and
five draws more, and the lantern three (frame, glass, halo) and its light.

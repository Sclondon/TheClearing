# The beast

After the Beast of *Over the Garden Wall*: a tall shadow in the dark, black as a silhouette, great branching
antlers like dead boughs, two pale burning eyes, and a lantern of its own glowing faintly and coldly in its fist.
A shroud of dark over its shoulders, long ragged skirts trailing on the ground; a long head between a stag's skull
and a mask of bark. More than twice the boy's height, the antlers over that.

It stands very still, its head turning slowly and tipped to one side; it holds its lantern up and out at whoever
it looks at, swaying it slowly from side to side, and hums (`lure`); and it draws its long arms up and out and
flings them forward, its hands closing (`reach`).

It is only the look, the motion and the sound. It does no thinking: your game moves it. Made for Warren,
2026-10-18 (the user: "a the Beast inspired character from Over the Garden Wall"; its `MazeBeast` is its thinking).

## Needs

GameCommon's `godot/character-controller` (the rig, `BeastRig`, extends `CharacterRig`) and `godot/woodsman` (its
lantern is an `OilLantern`; its hung parts use `Woodsman.carved()`). Global class names: `Beast`, `BeastRig`.

## Use

```gdscript
var beast := Beast.new()
add_child(beast)
beast.put(spawn_point, spawn_yaw)
# each frame:
beast.global_position = body_position
beast.rotation.y = facing_yaw
beast.velocity = body_velocity
beast.aim = someone + Vector3.UP        # what it looks at (INF: nothing)
beast.lure = 1.0                        # its lantern up, bright and swaying, and its hum (0: faint, low)
beast.burn = 1.0                        # how brightly its eyes burn
# when you like:
beast.reach()                           # the warning (BeastRig.WIND), then `grabbing` as its hands close
```

- `reaching()`, `cancel()`, `hand()`, `eyes()`. It is drawn `SIZE` (2.35) times as tall as the boy, black, on a
  render layer of its own (13) that its lantern's light leaves out.
- Exports: `low_poly` (or `Settings.low_poly`), `sound`, `volume_db`, `sound_range`, `lights`.

## Sound

Made in code: `Beast.hum_sound()`, a slow, low tune of its own in a minor key, hummed with the mouth shut by a voice
far too deep, a ghost of it an octave over, sliding from note to note, with an echo as if from down a long hall
(about 9 s, looping; it swells in as `lure` rises past a half and dies away); `reach_sound()`, the groan of bending
wood and a long breath drawn in.

## Models

`tools/build_beast.py` builds `models/beast.glb` and `beast_lo.glb` in Blender 4.3 with the woodsman's builder:

    blender --background --python creatures/beast/tools/build_beast.py [-- <folder for preview renders>]

`head` (with the antlers; head joint space), `eyes` (its own unshaded material, with a soft glow round each so that
they are seen from far down a dark hall), `cape` (chest) and `shroud` (hips). About 6,000 triangles (`_lo` 1,000).

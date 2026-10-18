# Woolly mammoth

A woolly mammoth: a grown cow (2.9 m at the shoulder; scale it for a bigger or smaller one) or a calf (`calf`: its
own model, a ball of fuzz on short legs, no tusks). True to the frozen ones and the cave paintings: the high domed
head (its highest point), a notch behind it, the hump over the shoulders and the back sloping steeply down to low
hindquarters and a short tufted tail; small furred ears; the long heavy ringed trunk with its two fingers; the great
spiralling tusks; column legs on round feet; and the coat, a dense wool under long coarse brown-grey hair that hangs
in a skirt from the flanks and sways as it goes. No thinking.

## Using it

```gdscript
var mammoth := Mammoth.new()      # mammoth.calf = true for a calf
add_child(mammoth)
# each frame: move it (position, rotation.y; it faces +Z) and it walks or ambles to match
mammoth.grazing = true            # head down, the trunk pulling up grass and putting it in its mouth, chewing
mammoth.look_at_point = point     # what it watches (its head turns a little: its neck is short)
mammoth.feeling = true            # the trunk raised and reaching out to look_at_point, sniffing
mammoth.alert = true              # head up, ears out
mammoth.ears_out = true           # ears spread wide (a display)
mammoth.lowered = true            # head down, tusks forward, trunk curled up out of the way: charge with it on
mammoth.trumpet()                 # the trunk thrown up in an S, and the blare (TRUMPET_TIME); trumpeting()
mammoth.rumble()                  # a deep rolling rumble (the herd's alarm)
mammoth.stamp()                   # a forefoot raised and brought down hard, a thud
mammoth.tusk_tips()               # where the tusks' tips are; trunk_tip(), head_position()
mammoth.rig.every = 2             # far off: posed only every other frame (half the work)
```

- **The gait** is an elephant's: a lateral walk at every speed (hind foot, then the fore foot on that side, then the
  other side), the legs nearly straight, the foot curling back as it lifts; faster it ambles. The body rolls over the
  planted feet and the head nods with the stride.
- **The trunk** is eight bones posed in code (`MammothRig`): hanging and swinging at ease, the grazing cycle (reach
  to the ground, curl round the grass, curl up to the mouth), feeling the air, trumpeting, tucked for a charge.
- **The hair** is cards (`MammothLook`, "hair"): each a strip of a few coarse strands, ragged at the end (cut out in
  the shader, no transparency), swinging in the air, with the pace, and lagging behind as the body moves and stops.
  The wool under it is the coat, with a shell. No textures.
- **Sounds** are made in code (`Mammoth.trumpet_sound()`, `rumble_sound()`, `thud_sound()`).
- **Signals**: `trumpeted`, `rumbled`, `stamped`.
- **Exports**: `calf`, `low_poly`, `fur_shells`, `coat_tint`, `measure_velocity`, `sound`, `volume_db`.
- **Cost**: 4 draws with one shell (coat, its shell, hair, parts); the cow is 36k triangles (the hair cards about 12k
  of them), 2.8k low; the calf 34k, 2.6k low.

## Files

- `mammoth.gd` (`Mammoth`): what a game drives.
- `mammoth_rig.gd` (`MammothRig`): the posing, gait and trunk.
- `mammoth_look.gd` (`MammothLook`): the materials.
- `models/mammoth.glb`, `mammoth_calf.glb` and their `_lo` versions: built by `tools/build_mammoth.py` (Blender 4.3,
  with the character controller's `tools/build_character.py`).
- `example.gd`: put it on a Node3D in an empty scene. A cow and her calf go through every move.

Needs nothing else.

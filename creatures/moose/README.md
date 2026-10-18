# Moose

A moose, a bull or a cow (`cow`), or a calf (`calf`: the cow's model, red-brown; scale it to about half). The biggest
deer there is, all legs: taller at the shoulder than a man (the bull 2 m), a short deep body on long pale-stockinged
legs, a high hump over the shoulders with a crest of coarse hair along it (the hackles), a short thick neck and a long
heavy head hung low, the broad muzzle overhanging the lower lip with the nostrils slits in the sides of it, the bell (a
flap of hide and hair) swinging under the throat, and on a bull the great palmate antlers (a short beam, a brow palm of
three points forward, the broad cupped main palm ringed with points). Nearly black, greyer over the hump; a cow's
face lighter. It is an Elk (`godot/elk`), and so a Deer (`godot/deer`), on the same rig, with its own moves on top.
No thinking.

## Using it

```gdscript
var moose := Moose.new()      # moose.cow = true for a cow; moose.calf = true (and scale 0.55) for a calf
add_child(moose)
# each frame: move it (position, rotation.y; it faces +Z) and it walks or breaks into its long fast trot to match
moose.browsing = true         # head up and out into the branches, the lips working
moose.bristling = true        # the warning: ears pinned back, hackles up, head low, staring at look_at_point, licking its lips
moose.lowered = true          # head down, antlers forward: charge with it on (moose.fleeing lays the ears back too)
moose.strike()                # rears and brings its forehooves down (STRIKE_TIME; `struck` as they land, at hooves_position())
moose.bugle()                 # its call: a bull's deep croaking grunt, a cow's long moan
moose.lick()                  # the tongue over the lips (it does this by itself while bristling)
moose.wading = 0.5            # stands that deep in water: its legs go down through the ground into it
# and everything an Elk and a Deer do: grazing, alert, look_at_point, pawing, stamp(), snort(), heavy...
```

- **The warning** is what tells you it will charge: the ears go flat, the hackles stand up along the hump and neck
  (bone `hackles`, moved up), the head drops and it stares out from under its brows, and it licks its lips (bone
  `tongue`) every couple of seconds.
- **The bell** swings as the head moves (bone `bell`, a weight on a spring, always hanging down).
- **The strike**: it rears up on its hind legs (the deer rig's `upright`, led by hand so that it comes down fast) and
  drives its forehooves down; `struck` is emitted as they land.
- **Sounds** are made in code (`Moose.call_sound()`, `Moose.moan_sound()`, and the deer's snort and stamp).
- **Signals**: `struck`, `licked` (and the Elk's and Deer's).
- **Exports**: `calf`, and the Elk's (`cow`) and Deer's.
- **Cost**: about 7 draws with one fur shell (coat, hair, parts, steam); the bull is 49k triangles, 5.5k low; the cow
  42k, 4.3k low.

## Files

- `moose.gd` (`Moose`): what a game drives.
- `models/moose_bull.glb`, `moose_cow.glb` and their `_lo` versions: built by `tools/build_moose.py` (Blender 4.3),
  which uses the deer's builder (`creatures/deer/tools/build_deer.py`) for most of its shapes.
- `example.gd`: put it on a Node3D in an empty scene. A bull, a cow and her calf go through every move.

Needs `godot/elk` and `godot/deer` (Deer, DeerRig, DeerLook, Elk).

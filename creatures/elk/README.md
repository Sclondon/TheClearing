# Elk

A bull elk in the rut, or a cow (`cow`; scaled down, a calf). The bull is taller at the shoulder than a boy: a pale tan
body, a dark chocolate neck, head and legs, a long shaggy mane hanging under his neck, a buff rump, and a six-point
rack (brow and bez tines over his face, the royal longest, a fork at the top) sweeping back over his shoulders. His
breath steams. He is a Deer (`godot/deer`), on the same rig, with his own moves on top. No thinking.

## Using it

```gdscript
var elk := Elk.new()          # elk.cow = true for a cow
add_child(elk)
# each frame: move him (position, rotation.y; he faces +Z) and he walks, trots or gallops to match
elk.bugle()                   # neck out, nose up, mouth open: the scream (3.3 s); bugling(), bugle_progress()
elk.pawing = true             # a forefoot scraping back, again and again
elk.lowered = true            # head down, nose to the chest, antlers forward: charge with it on
elk.brow_position()           # the front of his antlers, for what a charge hits
# and everything a Deer does: grazing, alert, look_at_point, stamp(), snort()...
```

- **The bugle** is made in code (`Elk.bugle_sound()`, nothing to load): a groan dragged up out of the chest breaks
  into a high, thin, rising whistle with the groan still going under it (two voices at once, as a real bull's), holds
  it screaming and wavering, falls away, and ends in four hard grunts. Steam pours from his mouth while he bugles.
- **Steam**: a puff at each breath out (CPUParticles3D, one draw), quicker the harder he breathes (`heavy`, set by the
  rig after running or pawing).
- **Signals**: `bugled` (and the Deer's).
- **Exports**: `cow`, and the Deer's.
- **Cost**: about 7 draws with one fur shell (coat, mane, parts, steam); the bull is 54k triangles (the mane's locks
  are most of it), 5.5k low; the cow 32k, 3.7k low.

## Files

- `elk.gd` (`Elk`): what a game drives.
- `models/elk_bull.glb`, `elk_cow.glb` and their `_lo` versions: built by the deer's
  `creatures/deer/tools/build_deer.py`.
- `example.gd`: put it on a Node3D in an empty scene. A bull and a cow go through every move.

Needs `godot/deer` (Deer, DeerRig, DeerLook).

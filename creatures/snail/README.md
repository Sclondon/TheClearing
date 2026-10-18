# Giant snail

A land snail as big as a car, after the garden snail and the Roman snail: a real snail's shape and anatomy made
huge. The foot is 8 m long and flat-soled, with a skirt a little proud all round it, tapering to a pointed, keeled
tail; wet grey-brown skin grooved into small raised tubercles in long slanting rows, each catching a glint, so that
it glistens; the muscle waves a snail moves by run forward along the fringe as it crawls. The head carries two long
eye stalks with an eye at each tip and two short feelers over the mouth. On its back a right-handed (dextral) coiled
shell nearly 4 m across and 3.4 m high, after Raup's coiling (each whorl twice as wide as the one inside it):
horn-brown, dark spiral bands broken into flecks, fine growth lines and darker growth checks, a chalky worn apex, a
pale lip; in its mouth the mantle's thick collar, with the breathing pore on its right that opens and shuts.
Toon-shaded (hard light bands). Everything it does is procedural, on its own skeleton: no clips. Made for Warren
(its giant snail). The component has no thinking; it makes its own sounds, in code.

## Using it

```gdscript
var snail := Snail.new()
add_child(snail)
# each frame: put it on a surface. Its origin is the front of its sole, under its head; +Y is up off the
# surface, +Z the way it goes. It crawls up a wall if you turn its up to the wall's face: its body follows
# behind along the way its head went, draping over every edge.
snail.global_transform = Transform3D(SnailRig._frame(surface_up, heading), point_on_surface)
snail.aim = target            # its eye stalks reach for it (INF: they feel about, the feelers tap the ground)
snail.withdrawn = true        # into its shell (the shell set down); false: out again, the stalks unrolling last
snail.flinch(0)               # its left eye stalk rolls in at a touch (1 its right, -1 both), and slowly out again
snail.draw_in(node, 1.5)      # something under its head is drawn down into the slime; `drawn(node)` as it goes under
if snail.touches(point, 0.3): ...        # its foot, head or shell
var fresh := snail.slime_at(feet)        # 0 (no slime) .. 1 (just laid)
```

- **The trail**: patches of slime laid flat on whatever it crawls over (floor, walls, tops) as wide as its foot, each
  lying `slime_life` seconds (120) and drying from the edges to a silver streak. One draw for the lot (a
  MultiMesh, `SnailSlime`); each patch's age is worked out in the shader, so nothing is updated while it lies.
  `slime_at(point)` is for whatever a game does to anyone in it.
- **Signals**: `withdrew`, `came_out`, `drawn(node)`.
- **Sounds**, made in code when first needed (`sound`): the wet slither of its crawling (louder the faster it goes),
  a squelch as it pulls in or draws something in. Run tests with `--audio-driver Dummy`.
- **Exports**: `low_poly`, `trailing`, `slime_life`, `measure_velocity`, `sound`, `volume_db`, `sound_range`.
- **Cost**: 2 draws (skin, shell) and their shadows, and 1 for its trail. The model is about 27k triangles, or 3.5k
  low (`low_poly`); 25 bones, posed in a few hundred operations a frame (every third frame beyond 60 m of the camera).

## Files

- `snail.gd` (`Snail`): what a game drives; its sounds, its trail, drawing things in.
- `snail_rig.gd` (`SnailRig`): poses the skeleton every frame: the foot along the trail of where its head went, the
  shell riding on it (rocking, sagging on a wall), the head, the eye stalks (chains of four bones) and feelers,
  pulling in, the breathing pore. `SnailRig._frame(up, forward)` makes a surface frame.
- `snail_look.gd` (`SnailLook`): three shaders: the wet tubercled skin with its muscle waves, the banded shell,
  the slime.
- `snail_slime.gd` (`SnailSlime`): the trail.
- `models/snail.glb` and `snail_lo.glb`: built by `tools/build_snail.py` in Blender 4.3 (needs nothing else). Run it
  from the game's root: `blender --background --python creatures/snail/tools/build_snail.py [-- <folder for pictures>]`
- `example.gd`: put it on a Node3D in an empty scene. A snail crawls a circle, reaches, flinches, pulls in, and goes
  over a wall.

Needs nothing else at run time (no textures, no other components).

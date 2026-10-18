# Blue jays (Godot 4.7)

A family of blue jays: `BlueJays` (`creatures/blue_jay/blue_jays.gd`), a `CorvidFlock` of kind `BLUE_JAY` set up as
jays go about. **Needs `godot/crow`** (the flock, the mesh loader, the shader, the voice, and the Blender script
`creatures/crow/tools/build_corvids.py` that builds the jay's models here: `models/blue_jay.glb` and
`blue_jay_lo.glb`). Made 2026-10-18 for Warren, where families of them live in the pines at the edge of the
woods (`scripts/wildlife/birds.gd` there) and are one of the very few colour accents in its misty, near-colourless
clearing.

## The bird

About 0.28 m from bill to tail, the corvids' anatomy (see `godot/crow`) in a jay's proportions: a round head with a
crest of long feathers (raised and lowered: `crest`), a short straight black bill with nasal bristles, a long
square-ended tail, short rounded wings. Vivid blue above (the crest and crown paler, the back grey-blue), the wings
and tail barred black, white tips to the secondaries, tertials and outer tail feathers and a white bar on the
greater coverts, the primaries blue on the outer vane and dark on the inner; white face and throat, grey-white
below; a black necklace round the neck, high at the nape and low across the upper breast, and a black bridle through
the eye; black legs. About 12900 triangles (low: about 3900).

## What they do

Everything a `CorvidFlock` does, tuned for jays: restless, they flit from branch to branch and tree to tree in short
bounding flights (a burst of quick beats, wings shut a moment, again), drop to the ground (`ground_share`, round
`home` within `roam`) to hop about with both feet and peck, and fly back up. On a perch they look about with the
crest half up, and call: "jay! jay!" (bobbing down and up on each call, crest raised, bill wide), a squeaky "queedle",
and now and then a red-tailed hawk's scream (as real jays mimic hawks), the head up and the crest down.
`scold(point)`: they come to the perches nearest it and scold it, crests up, bobbing, tails flicking, screaming;
`scold(Vector3.INF)` and they calm down. `startle(from)` sends those on the ground up into the branches.

## Putting it in a game

```gdscript
var jays := BlueJays.new()
jays.count = 5
jays.flock_seed = 3
jays.home = ground_in_front_of_the_trees
add_child(jays)
jays.set_perches(branch_tips, out_along_the_branches, false)
jays.settle()
jays.add_child(CorvidVoice.new(jays))
jays.scold(someone_under_the_tree)   # or Vector3.INF
```

`example.gd` is the smallest level: five jays in three post-trees, flitting and hopping, and every 20 seconds
scolding a point under the middle one. Give them perches out at the ends of branches, where a bird sits clear of
the needles (Warren works them out from its pines: `Perches.in_pines`).

## Limits

As `godot/crow`. Class: `BlueJays`.

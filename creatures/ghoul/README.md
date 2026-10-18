# Ghoul

A mummy with nothing left on, after the ReDeads of Zelda: raw, dried red-brown flesh over a starved, hunched
frame, arms down to its knees, long bony fingers, and a skull under skin for a face, made into a mask: a heavy
brow over deep dark eye holes, cheekbones over hollow cheeks, a long slack jaw with the mouth open low in it. It
stands like a statue until it is woken; then it shuffles, screams (a ragged shriek meant to root whoever hears it
to the spot) and grabs, hugging them to it.

It is only the look, the motion and the shriek. It does no thinking: your game moves it and tells it when to act.
Made for The Clearing (its `MazeGhoul` is the thinking that drives it there).

## Needs

GameCommon's `godot/character-controller` (the ghoul's rig, `GhoulRig`, extends `CharacterRig`, and uses its
`Toon`, `Dust` and `Settings`). Global class names: `Ghoul`, `GhoulRig`.

## Use

```gdscript
var ghoul := Ghoul.new()
ghoul.scale = Vector3.ONE * 1.6        # modelled about 1.4 units tall
add_child(ghoul)
ghoul.put(spawn_point, spawn_yaw)

# every frame, from your own body (a CharacterBody3D, a path follower...):
ghoul.global_position = body_position
ghoul.rotation.y = facing_yaw           # 0 faces +Z
ghoul.velocity = body_velocity          # its feet step to this (fast, they rush)
ghoul.awake = true                      # false: a statue
ghoul.aim = target + Vector3.UP         # looks at it, and reaches for it when near (INF: nothing)

ghoul.scream()                          # `shrieked` fires at the top of it: hold your player there
ghoul.grab()                            # `closing` fires as the arms close; test grab_hits(point) while stage() is CLOSE
ghoul.held = true                       # it has them: it clings instead of hugging the air
```

- `doing()` (`GhoulRig.Act.NONE`, `SCREAM`, `GRAB`), `stage()` (`GhoulRig.Stage`: SCREAM_RISE, SCREAMING,
  SCREAM_FALL, REACH, CLOSE, HOLD, LET_GO), `busy()`, `Ghoul.act_length(act)`.
- `grab_hits(point, radius := 0.25)`: whether a point is inside its closing arms (in front of it, within arm's
  reach and its height). `mouth()`: where the shriek comes from, for a line-of-sight test.
- Exports: `low_poly` (or `Settings.low_poly`), `sound`, `volume_db`, `sound_range`. Also `reaching` (0..1, how
  far its arms come up for `aim`) and `grounded`.

## How it moves

Asleep it is a statue that does not breathe; now and then its head jerks aside and slowly comes back. Awake it
shuffles on stiff legs, feet scraping, rocking from side to side with its arms swinging like weights; driven
faster it rushes, its steps long and lifted. The scream: a gasp, then the head thrown back, the chest out, the
arms up and back beside its head with the hands clawed, convulsing. The grab throws both arms wide as it leans
in, then brings them round into a ring in front of its chest, as low as what it aims at.

## Sound

`Ghoul.shriek_sound()` makes the shriek in code (nothing to load): a choked gasp, then a strained, cracking,
breathy voice (jittered glottal pulses through the resonances of an "aah", a second voice beating against it,
pushed into distortion), its pitch straining, wavering and breaking, ending in a rattle of slow clicks. 1.75 s.

## Model

`tools/build_ghoul.py` builds `models/ghoul.glb` and `ghoul_lo.glb` in Blender 4.3 on the mummy's and the boy's
bone names (so any rig for them can move it):

    blender --background --python creatures/ghoul/tools/build_ghoul.py [-- <folder for preview renders>]

The trunk, neck and arms are one fused surface (sloping shoulders, collarbones, ribs, tendons). How far each point
lies in a hollow is baked into the model as its vertex colour (`cavity`), and `GhoulRig` shades its skin with
Toon's shader plus one soft step to `GhoulRig.SHADE` over it, so the dark in its hollows has clean curved edges.
Two materials (skin, and the dark in the holes), so two surfaces; about 35k triangles (`ghoul_lo`: 7k). In The
Clearing one in sight costs about 5 draw calls, shadows included. (The build exports the colour attribute by
asking the glTF exporter for it: see `_Export` in the script.)

## Try it

`example.gd` on a Node3D: one on a flat floor going round a loop (statue, wake, shuffle up to a post, scream,
rush, grab it, walk back).

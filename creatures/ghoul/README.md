# Ghoul

A mummy with nothing left on, after the ReDeads of Zelda: grey, starved and hunched, arms down to its knees, a
smooth mask of a face with round holes for eyes and a mouth hanging open. It stands like a statue until it is
woken; then it shuffles, screams (a shriek meant to root whoever hears it to the spot) and grabs, hugging them to it.

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
ghoul.velocity = body_velocity          # its feet step to this
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
shuffles on stiff legs, feet scraping, rocking from side to side with its arms swinging like weights. The scream
throws its head right back, arches its back and spreads its arms, shuddering. The grab throws both arms wide as it
leans in, then brings them round into a ring in front of its chest.

## Model

`tools/build_ghoul.py` builds `models/ghoul.glb` and `ghoul_lo.glb` in Blender 4.3 on the mummy's and the boy's
bone names (so any rig for them can move it):

    blender --background --python creatures/ghoul/tools/build_ghoul.py [-- <folder for preview renders>]

Four flat colours (skin, darker skin for the fingers, the dark in the holes, the rag), so four surfaces; about
29k triangles (`ghoul_lo`: 5k). In The Clearing one in sight costs 13 draw calls, shadows included. Its shriek is made in code (`Ghoul.shriek_sound()`), nothing to load.

## Try it

`example.gd` on a Node3D: one on a flat floor going round a loop (statue, wake, shuffle up to a post, scream,
grab it, walk back).

# Skinwalker

A creature of horror stories: something wearing a coyote's skin. On all fours it passes for a coyote if you do not
look closely (too big, its joints bending the wrong ways, its eyes shining too much). Then it rises onto long, gaunt,
too-human legs: a starved figure far too tall and thin, its skin a mottled ash grey-brown, filthy on its hands,
feet, shins and forearms, every rib and joint sharp. The whole coyote hide is worn as a hooded cloak, matted, dark and
dirty, its edges ragged: over the head, round the face, over the shoulders and down the back; the coyote's head is a
dried, shrunken mask on top of its own, the snout pulled down over the brow (the dry teeth showing under it, the eye
holes empty), and under it a gaunt human face with small deep-set
eyes that shine and a lipless slit of a mouth; long thin arms with fingers far too long; the coyote's empty legs and
tail hanging off it, swinging. It moves wrongly: a crawl on hands and the balls of its feet with its knees splayed, a
rise that goes hips first until it stands bent double, a jerky held-and-snatched walk upright, and bursts on all
fours far too fast.

It is only the look, the motion and the sounds. It does no thinking: your game moves it and says when it rises,
calls, drops and grabs. Made for Warren (its `MazeSkinwalker`, hidden among coyote packs).

## Needs

GameCommon's `godot/character-controller` (its rig, `SkinwalkerRig`, extends `CharacterRig`, and uses `Toon` and
`Settings`), and `godot/coyote` (the hide is furred with `CoyoteLook`), which needs `godot/dog`. Global class names:
`Skinwalker`, `SkinwalkerRig`.

## Use

```gdscript
var walker := Skinwalker.new()
walker.scale = Vector3.ONE * 1.25        # modelled about 1.7 units tall standing
add_child(walker)
walker.put(spawn_point, spawn_yaw)
# each frame:
walker.global_position = body_position
walker.rotation.y = facing_yaw           # 0 faces +Z
walker.velocity = body_velocity          # (its limbs go by how it is moved)
walker.aim = player_head                 # what it watches (INF: nothing)
walker.crouch = 1.0                      # flat down for a burst: the wind-up
walker.glare = 1.0                       # how brightly its eyes shine (dim, hiding)
# when you like:
walker.rise()                            # up onto its legs (SkinwalkerRig.RISE_TIME, 1.9 s); `risen` when up
walker.drop()                            # back on all fours
walker.call_out()                        # its mimicked call, the head tipped right over; `called`
walker.grab()                            # both arms flung forward; grab_hits(point)
```

- `is_upright()`, `how_upright()` (0..1), `rising()`, `busy()`, `mouth()` (where its face is).
- Exports: `low_poly` (or `Settings.low_poly`), `sound`, `volume_db`, `sound_range`.

## Sound

Made in code, nothing to load, and nobody's real voice: `Skinwalker.call_sound(0..2)` is a coyote's yip that turns
into a sagging human "aah"; a breathy "hey?" in a child's pitch; a "hel-lo" whose second half sags and draws out far
too long. Each is a glottal buzz through the resonances of the vowels, with a second voice a little off against the
first, a slow flutter, and an echo. `rise_sound()`: joints cracking and a long wet breath drawn in.

## Model

`tools/build_skinwalker.py` builds `models/skinwalker.glb` and `skinwalker_lo.glb` in Blender 4.3 from the ghoul's
build (`creatures/ghoul/tools/build_ghoul.py`: its frame, bones and weights, on the boy's bone names), drawn out
(legs 1.36 times as long, longer arms, fingers half as long again) and made pale, with the coyote's hide built over
it (mask, cloak, empty legs and tail, on bones of their own, `pelt_*`). Rebuilding needs the ghoul's build script
and the character controller's `tools/build_character.py`:

    blender --background --python creatures/skinwalker/tools/build_skinwalker.py [-- <folder for preview renders>]

Four materials (skin, hollow, eyes, pelt); about 49k triangles (`_lo`: 9k); about 17 draw calls with fur shells and
shadows.

## Try it

`example.gd` on a Node3D: it creeps, rises, stares, calls, drops, bursts, grabs and walks back.
